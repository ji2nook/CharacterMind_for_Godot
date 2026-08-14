extends Node
class_name CharacterChat

# --- 시그널 ---
## 가드레일을 통과한 전체 응답이 준비됐을 때 발생 (단어 단위 표시용)
signal response_token(text: String)
## 응답이 완전히 끝났을 때 최종 텍스트와 함께 발생
signal response_received(text: String)
## 가드레일이 작동하여 응답이 차단됐을 때 fallback 텍스트와 함께 발생
signal guardrail_blocked(fallback: String)

# --- 외부 설정 ---
## 캐릭터 행동을 정의하는 설정 리소스
@export var config: CharacterAIConfig
## 캐릭터의 부적절한 발언을 방지하는 가드레일 노드
@export var guardrail: CharacterGuardrail
## 추론을 실행할 NobodyWho 모델 노드
@export var model_node: NobodyWhoModel

# --- 내부 상태 ---
var _chat: NobodyWhoChat
## 다음 send_message() 호출 전에 대화 기록을 초기화해야 하는지 여부
var _needs_reset := false

func _ready() -> void:
	_setup_chat()

## NobodyWhoChat 인스턴스를 새로 생성하고 시그널을 연결 — 대화 기록이 완전히 초기화됨
func _setup_chat() -> void:
	if _chat:
		_chat.response_updated.disconnect(_on_response_updated)
		_chat.response_finished.disconnect(_on_response_finished)
		remove_child(_chat)
		_chat.free()
	_chat = NobodyWhoChat.new()
	add_child(_chat)
	_chat.model_node = model_node
	_chat.system_prompt = config.build_safe_system_prompt()
	_chat.response_updated.connect(_on_response_updated)
	_chat.response_finished.connect(_on_response_finished)

## 플레이어 메시지를 NobodyWho 채팅에 전달
func send_message(player_text: String) -> void:
	var system_text := config.build_safe_system_prompt()
	if _needs_reset:
		_needs_reset = false
		_setup_chat()
		_chat.system_prompt = system_text
		# 새 NobodyWhoChat이 model_node 연결을 마칠 수 있도록 한 프레임 뒤에 say() 호출
		call_deferred("_do_say", player_text)
		return
	_chat.system_prompt = system_text
	_chat.say(player_text)

func _do_say(player_text: String) -> void:
	_chat.say(player_text)

func _on_response_updated(_token: String) -> void:
	pass

## 응답 완료 시 전체 텍스트를 검열하고 통과한 경우에만 emit
func _on_response_finished(full_text: String) -> void:
	var clean_text := _strip_thinking(full_text)
	if guardrail and guardrail.check(clean_text) != clean_text:
		_needs_reset = true
		var fallback := _pick_fallback()
		guardrail_blocked.emit(fallback)
		response_received.emit(fallback)
		return
	if clean_text != "":
		response_token.emit(clean_text)
	response_received.emit(clean_text)

## 전체 응답 텍스트에서 <think>...</think> 블록을 제거하고 반환
func _strip_thinking(text: String) -> String:
	const THINK_CLOSE_LEN: int = 8  # len("</think>")
	var end_idx := text.find("</think>")
	if end_idx == -1:
		return text.strip_edges()
	return text.substr(end_idx + THINK_CLOSE_LEN).strip_edges()

func _pick_fallback() -> String:
	if guardrail and not guardrail.fallback_lines.is_empty():
		return guardrail.fallback_lines[randi() % guardrail.fallback_lines.size()]
	return "..."
