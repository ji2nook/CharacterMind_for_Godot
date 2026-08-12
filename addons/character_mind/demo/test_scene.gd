extends Node

# --- UI 노드 참조 ---
@onready var npc_chat = $NPCChat
@onready var input_box = $UI/Layout/InputRow/InputBox
@onready var send_button = $UI/Layout/InputRow/SendButton
@onready var chat_log = $UI/Layout/ChatLog

# --- 스레드 안전 토큰 버퍼 ---
## 워커 스레드에서 수신된 토큰을 메인 스레드가 처리하기 전까지 임시 보관
var _pending_tokens: Array[String] = []
var _mutex: Mutex = Mutex.new()

func _ready() -> void:
	send_button.pressed.connect(_on_send_pressed)
	input_box.text_submitted.connect(func(_t): _on_send_pressed())
	npc_chat.response_token.connect(_on_response_token)
	npc_chat.response_received.connect(_on_response_received)

## 매 프레임마다 버퍼에 쌓인 토큰을 메인 스레드에서 안전하게 채팅 로그에 출력
func _process(_delta: float) -> void:
	if _pending_tokens.is_empty():
		return
	_mutex.lock()
	var tokens := _pending_tokens.duplicate()
	_pending_tokens.clear()
	_mutex.unlock()
	for token in tokens:
		chat_log.append_text(token)
	_scroll_to_bottom()

## 입력창의 텍스트를 채팅 로그에 표시하고 NPC에게 메시지 전달
func _on_send_pressed() -> void:
	var msg: String = input_box.text.strip_edges()
	if msg == "":
		return
	chat_log.append_text("\n[b]나:[/b] %s\n[b]NPC:[/b] " % msg)
	input_box.text = ""
	npc_chat.send_message(msg)
	_scroll_to_bottom()

## 워커 스레드에서 호출되므로 뮤텍스로 보호한 뒤 버퍼에 추가
func _on_response_token(token: String) -> void:
	_mutex.lock()
	_pending_tokens.append(token)
	_mutex.unlock()

## 응답 완료 시 줄바꿈을 버퍼에 추가해 다음 발화와 구분
func _on_response_received(_text: String) -> void:
	_mutex.lock()
	_pending_tokens.append("\n")
	_mutex.unlock()

## 스크롤바를 최하단으로 이동해 최신 메시지가 보이게 함
func _scroll_to_bottom() -> void:
	var scrollbar: VScrollBar = chat_log.get_v_scroll_bar()
	scrollbar.value = scrollbar.max_value
