extends Node

@onready var npc_chat = $NPCChat
@onready var input_box = $UI/Layout/InputRow/InputBox
@onready var send_button = $UI/Layout/InputRow/SendButton
@onready var chat_log = $UI/Layout/ChatLog

var _pending_tokens: Array[String] = []
var _mutex: Mutex = Mutex.new()

func _ready() -> void:
	send_button.pressed.connect(_on_send_pressed)
	input_box.text_submitted.connect(func(_t): _on_send_pressed())
	npc_chat.response_token.connect(_on_response_token)
	npc_chat.response_received.connect(_on_response_received)

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

func _on_send_pressed() -> void:
	var msg: String = input_box.text.strip_edges()
	if msg == "":
		return
	chat_log.append_text("\n[b]나:[/b] %s\n[b]NPC:[/b] " % msg)
	input_box.text = ""
	npc_chat.send_message(msg)
	_scroll_to_bottom()

func _on_response_token(token: String) -> void:
	_mutex.lock()
	_pending_tokens.append(token)
	_mutex.unlock()

func _on_response_received(_text: String) -> void:
	_mutex.lock()
	_pending_tokens.append("\n")
	_mutex.unlock()

func _scroll_to_bottom() -> void:
	var scrollbar: VScrollBar = chat_log.get_v_scroll_bar()
	scrollbar.value = scrollbar.max_value
