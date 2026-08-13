extends Node

# --- UI 노드 참조 ---
@onready var npc_chat = $NPCChat
@onready var input_box = $UI/Layout/InputRow/InputBox
@onready var send_button = $UI/Layout/InputRow/SendButton
@onready var chat_log = $UI/Layout/ChatLog

# --- 단어 단위 스트리밍 ---
## 가드레일을 통과한 단어들을 순서대로 보관하는 큐
var _pending_tokens: Array[String] = []
var _token_read_idx: int = 0
var _mutex: Mutex = Mutex.new()
var _token_timer: float = 0.0

## 단어 표시 간격 (초) — 낮출수록 빠름, 높일수록 느림
const TOKEN_INTERVAL: float = 0.04

## 채팅 로그 내용을 직접 추적 — "생각 중..." 제거 시 clear() 후 재구성에 사용
var _chat_log_content: String = ""

# --- 생각 중 애니메이션 ---
var _is_thinking: bool = false
var _thinking_timer: float = 0.0
var _thinking_dot_count: int = 1
const THINKING_INTERVAL: float = 0.4

var _scrollbar: VScrollBar

func _ready() -> void:
	_scrollbar = chat_log.get_v_scroll_bar()
	send_button.pressed.connect(_on_send_pressed)
	input_box.text_submitted.connect(func(_t): _on_send_pressed())
	npc_chat.response_token.connect(_on_response_token)
	npc_chat.response_received.connect(_on_response_received)
	npc_chat.guardrail_blocked.connect(_on_guardrail_blocked)

func _process(delta: float) -> void:
	if _is_thinking:
		_thinking_timer += delta
		if _thinking_timer >= THINKING_INTERVAL:
			_thinking_timer = 0.0
			_thinking_dot_count = (_thinking_dot_count % 3) + 1
			chat_log.clear()
			chat_log.append_text(_chat_log_content)
			chat_log.append_text("[i]생각 중%s[/i]" % ".".repeat(_thinking_dot_count))
			_scroll_to_bottom()

	if _token_read_idx >= _pending_tokens.size():
		return
	_token_timer += delta
	if _token_timer < TOKEN_INTERVAL:
		return
	_token_timer = 0.0
	_mutex.lock()
	if _token_read_idx >= _pending_tokens.size():
		_mutex.unlock()
		return
	var token: String = _pending_tokens[_token_read_idx]
	_token_read_idx += 1
	if _token_read_idx >= _pending_tokens.size():
		_pending_tokens.clear()
		_token_read_idx = 0
	_mutex.unlock()
	_chat_log_content += token
	chat_log.append_text(token)
	_scroll_to_bottom()

## 입력창의 텍스트를 채팅 로그에 표시하고 NPC에게 메시지 전달
func _on_send_pressed() -> void:
	var msg: String = input_box.text.strip_edges()
	if msg == "":
		return
	var entry := "\n[b]나:[/b] %s\n[b]NPC:[/b] " % msg
	_chat_log_content += entry
	chat_log.append_text(entry)
	_is_thinking = true
	_thinking_timer = 0.0
	_thinking_dot_count = 1
	chat_log.append_text("[i]생각 중.[/i]")
	input_box.text = ""
	npc_chat.send_message(msg)
	_scroll_to_bottom()

## "생각 중..." 애니메이션을 중단하고 채팅 로그를 응답 직전 상태로 복원
func _stop_thinking() -> void:
	_is_thinking = false
	chat_log.clear()
	chat_log.append_text(_chat_log_content)
	_scroll_to_bottom()

## 가드레일을 통과한 전체 응답을 공백 기준으로 단어 단위로 쪼개 큐에 추가
func _on_response_token(token: String) -> void:
	_stop_thinking()
	_mutex.lock()
	var parts := token.split(" ")
	for i in range(parts.size()):
		var word: String = parts[i]
		if i < parts.size() - 1:
			word += " "  # 단어 사이 공백 복원
		if word != "":
			_pending_tokens.append(word)
	_mutex.unlock()

## 가드레일 차단 시 fallback을 큐에 추가
func _on_guardrail_blocked(fallback: String) -> void:
	_stop_thinking()
	_mutex.lock()
	_pending_tokens.append(fallback)
	_mutex.unlock()

## 응답 완료 시 줄바꿈을 큐에 추가해 다음 발화와 구분
func _on_response_received(_text: String) -> void:
	_mutex.lock()
	_pending_tokens.append("\n")
	_mutex.unlock()

## 스크롤바를 최하단으로 이동해 최신 메시지가 보이게 함
func _scroll_to_bottom() -> void:
	_scrollbar.value = _scrollbar.max_value
