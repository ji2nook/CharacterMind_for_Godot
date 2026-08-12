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
## </think> 이후 실제 답변 구간에 진입했는지 여부
var _showing_answer := false
## 실제 답변의 첫 토큰이 이미 emit됐는지 여부 (공백 스킵용)
var _answer_shown := false

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

	var close_idx := _last_response.find("</think>")
	if close_idx == -1:
		return

	# </think> 태그를 발견한 시점에 이후 텍스트를 즉시 emit
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
