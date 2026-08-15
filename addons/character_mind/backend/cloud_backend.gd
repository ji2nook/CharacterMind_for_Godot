extends CharacterBackend
class_name CloudBackend

## OpenRouter(OpenAI 호환) API 기반 클라우드 추론 백엔드
##
## API 키 우선순위:
##   1) 프로젝트 루트의 api_keys.cfg 파일 (.gitignore 처리됨) — 키만 한 줄 적으면 됨
##   2) 환경 변수 OPENROUTER_API_KEY
##   3) 아래 @export api_key (Inspector 직접 입력 — 커밋하지 말 것)

const _ENDPOINT: String = "https://openrouter.ai/api/v1/chat/completions"
const _KEY_FILE: String = "res://api_keys.cfg"
const _MAX_RETRIES: int = 3

## 최후 수단 — Inspector에 직접 입력 시 커밋 전 반드시 비울 것
@export var api_key: String = ""
## 사용할 모델 ID
@export var model: String = "openai/gpt-oss-20b:free"
## 최대 응답 토큰 수
@export var max_tokens: int = 400

var _http: HTTPRequest
## 성공 확정된 대화만 보관 — 재시도 중에는 추가하지 않는다
var _history: Array[Dictionary] = []
var _last_user_message: String = ""
var _retry_count: int = 0

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

func say(message: String) -> void:
	_last_user_message = message
	_retry_count = 0
	_send_request()

## 대화 기록을 초기화한다
func reset() -> void:
	_history.clear()

func _send_request() -> void:
	var messages: Array = [{"role": "system", "content": system_prompt}]
	messages.append_array(_history)
	messages.append({"role": "user", "content": _last_user_message})

	var body := JSON.stringify({
		"model": model,
		"messages": messages,
		"max_tokens": max_tokens,
	})

	var headers := PackedStringArray([
		"Authorization: Bearer " + _resolve_api_key(),
		"Content-Type: application/json",
	])

	_http.request(_ENDPOINT, headers, HTTPClient.METHOD_POST, body)

func _on_request_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if response_code == 200:
		var json := JSON.new()
		if json.parse(body.get_string_from_utf8()) != OK:
			push_error("CloudBackend: JSON 파싱 실패")
			request_failed.emit("응답을 해석하지 못했어요. 다시 말을 걸어주세요.")
			return
		var data: Dictionary = json.get_data()
		var reply: String = data["choices"][0]["message"]["content"]
		_history.append({"role": "user", "content": _last_user_message})
		_history.append({"role": "assistant", "content": reply})
		response_finished.emit(reply)
		return

	if response_code == 429:
		if _retry_count < _MAX_RETRIES:
			_retry_count += 1
			var wait_sec: int = _parse_retry_after(body)
			await get_tree().create_timer(float(wait_sec)).timeout
			_send_request()
		else:
			request_failed.emit("서버가 너무 바빠요. 잠시 후 다시 말을 걸어주세요.")
		return

	push_error("CloudBackend: HTTP %d — %s" % [response_code, body.get_string_from_utf8()])
	request_failed.emit("오류가 발생했어요 (HTTP %d). 잠시 후 다시 시도해주세요." % response_code)

## 429 응답 본문에서 retry_after_seconds 값을 파싱한다
func _parse_retry_after(body: PackedByteArray) -> int:
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return 22
	var data: Dictionary = json.get_data()
	return data.get("error", {}).get("metadata", {}).get("retry_after_seconds", 22)

## api_keys.cfg → 환경 변수 → @export 순서로 키를 탐색한다
func _resolve_api_key() -> String:
	if FileAccess.file_exists(_KEY_FILE):
		var file := FileAccess.open(_KEY_FILE, FileAccess.READ)
		if file:
			var key := file.get_as_text().strip_edges()
			file.close()
			if key != "" and not key.begins_with("여기에"):
				return key

	var env_key := OS.get_environment("OPENROUTER_API_KEY")
	if env_key != "":
		return env_key

	return api_key
