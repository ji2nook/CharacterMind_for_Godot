extends Node
class_name CharacterChat

# --- 시그널 ---
## 응답 토큰이 스트리밍될 때마다 발생
signal response_token(text: String)
## 응답이 완전히 끝났을 때 최종 텍스트와 함께 발생
signal response_received(text: String)

# --- 외부 설정 ---
## 캐릭터 행동을 정의하는 설정 리소스
@export var config: CharacterAIConfig
## 추론을 실행할 NobodyWho 모델 노드
@export var model_node: NobodyWhoModel

# --- 내부 상태 ---
var _chat: NobodyWhoChat
var _last_response := ""
## </think> 이후 실제 답변 구간에 진입했는지 여부 (또는 <think> 없음이 확정된 경우 포함)
var _showing_answer := false
## 실제 답변의 첫 토큰이 이미 emit됐는지 여부 (공백 스킵용)
var _answer_shown := false
## 이 응답에 <think> 블록이 있는지 없는지 확정됐는지 여부
var _think_determined := false

func _ready():
	_chat = NobodyWhoChat.new()
	add_child(_chat)
	_chat.model_node = model_node
	_chat.system_prompt = config.system_prompt
	_chat.response_updated.connect(_on_response_updated)
	_chat.response_finished.connect(_on_response_finished)

## 플레이어 메시지를 NobodyWho 채팅에 전달하고 내부 상태를 초기화
func send_message(player_text: String):
	_last_response = ""
	_showing_answer = false
	_answer_shown = false
	_think_determined = false
	_chat.say(player_text)

## 스트리밍 토큰을 누적하며 <think> 블록이 끝난 후부터 외부로 emit
func _on_response_updated(token: String):
	_last_response += token

	if _showing_answer:
		if not _answer_shown and token.strip_edges() != "":
			_answer_shown = true
		if _answer_shown or token.strip_edges() != "":
			response_token.emit(token)
		return

	# <think> 블록 존재 여부가 아직 확정되지 않은 경우: 판단 시도
	if not _think_determined:
		var stripped := _last_response.strip_edges()
		# <think>(7자) 길이 이상 쌓여야 시작 여부를 확정할 수 있음
		if stripped.length() < 7:
			return
		_think_determined = true
		if not stripped.begins_with("<think>"):
			# <think> 없는 모델 — 버퍼링된 내용 전체를 즉시 flush하고 passthrough로 전환
			_showing_answer = true
			var flush := _last_response.lstrip("\n\r")
			if flush != "":
				_answer_shown = true
				response_token.emit(flush)
			return

	# <think> 블록이 있는 경우: </think> 탐색
	var close_idx := _last_response.find("</think>")
	if close_idx == -1:
		return

	_showing_answer = true
	var remainder := _last_response.substr(close_idx + "</think>".length()).lstrip("\n\r")
	if remainder != "":
		_answer_shown = true
		response_token.emit(remainder)

## 전체 응답 텍스트에서 <think>...</think> 블록을 제거하고 반환
func _strip_thinking(text: String) -> String:
	var end_idx := text.find("</think>")
	if end_idx == -1:
		return text.strip_edges()
	return text.substr(end_idx + "</think>".length()).strip_edges()

## 응답 완료 시 스트리밍 중 미노출된 텍스트를 보완하고 최종 시그널 발생
func _on_response_finished(full_text: String):
	var processed_text := _strip_thinking(full_text)
	if not _answer_shown and processed_text != "":
		response_token.emit(processed_text)
	response_received.emit(processed_text)
