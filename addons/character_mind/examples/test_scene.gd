extends Node

# --- UI 노드 참조 : 첫 페이지 ---
@onready var select_screen: Control = $UI/SelectScreen
@onready var dialogue_screen: Control = $UI/DialogueScreen
@onready var alice_button: Button = $UI/SelectScreen/SelectLayout/AliceButton
@onready var bob_button: Button = $UI/SelectScreen/SelectLayout/BobButton
@onready var exit_button: Button = $UI/DialogueScreen/Layout/ExitButton

@export var alice_profile: CharacterProfile
@export var bob_profile: CharacterProfile

var current_profile: CharacterProfile

# --- UI 노드 참조 : 대화 페이지 ---
@onready var npc_chat = $NPCChat
@onready var input_box = $UI/DialogueScreen/Layout/InputRow/InputBox
@onready var send_button = $UI/DialogueScreen/Layout/InputRow/SendButton
@onready var chat_log = $UI/DialogueScreen/Layout/ChatLog
@onready var status_label = $UI/DialogueScreen/Layout/StatusLabel

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
var _action_regex: RegEx

func _ready() -> void:
	_action_regex = RegEx.new()
	_action_regex.compile("\\*\\(([^)]+)\\)\\*")
	_scrollbar = chat_log.get_v_scroll_bar()
	set_process(false)
	send_button.pressed.connect(_on_send_pressed)
	input_box.text_submitted.connect(func(_t): _on_send_pressed())
	npc_chat.response_token.connect(_on_response_token)
	npc_chat.response_received.connect(_on_response_received)
	npc_chat.guardrail_blocked.connect(_on_guardrail_blocked)
	npc_chat.emotion.emotion_changed.connect(_on_emotion_changed)
	npc_chat.emotion.stage_changed.connect(_on_stage_changed)
	npc_chat.mood.mood_changed.connect(_on_mood_changed)
	npc_chat.action.action_triggered.connect(_on_action_triggered)
	
	# 캐릭터 선택 화면이 먼저 보이도록 초기화
	select_screen.visible = true
	dialogue_screen.visible = false
	
	alice_button.pressed.connect(func(): _start_conversation(alice_profile))
	bob_button.pressed.connect(func(): _start_conversation(bob_profile))
	exit_button.pressed.connect(_end_conversation)

func _start_conversation(profile: CharacterProfile) -> void:
	if profile == null:
		return
	current_profile = profile
	npc_chat.switch_character(profile)
	_chat_log_content = ""
	chat_log.clear()
	_pending_tokens.clear()
	_token_read_idx = 0
	_token_timer = 0.0
	_is_thinking = false
	_thinking_timer = 0.0
	_thinking_dot_count = 1
	select_screen.visible = false
	dialogue_screen.visible = true

func _end_conversation() -> void:
	current_profile = null
	dialogue_screen.visible = false
	select_screen.visible = true

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
		if not _is_thinking:
			set_process(false)
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

## *(행동)* 구문을 기울임·회색 BBCode로 변환하고 기호*()*는 제거
func _format_with_actions(text: String) -> String:
	return _action_regex.sub(text, "[i][color=#aaaaaa]$1[/color][/i]", true)

## 입력창의 텍스트를 채팅 로그에 표시하고 NPC에게 메시지 전달
func _on_send_pressed() -> void:
	var msg: String = input_box.text.strip_edges()
	if msg == "":
		return
	var entry := "\n[b]나:[/b] %s\n[b]%s:[/b] " % [_format_with_actions(msg), current_profile.character_name]
	_chat_log_content += entry
	chat_log.append_text(entry)
	_is_thinking = true
	_thinking_timer = 0.0
	_thinking_dot_count = 1
	set_process(true)
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

## 응답 텍스트를 일반 구간과 *(행동)* 구간으로 분리해 토큰 큐에 추가
## 행동 구간은 BBCode로 감싸 기울임·회색으로 표시
func _on_response_token(token: String) -> void:
	_stop_thinking()
	_mutex.lock()
	for t in _tokenize_response(token):
		_pending_tokens.append(t)
	_mutex.unlock()

func _tokenize_response(text: String) -> Array[String]:
	var result: Array[String] = []
	var last_end := 0
	for m in _action_regex.search_all(text):
		if m.get_start() > last_end:
			_split_words(text.substr(last_end, m.get_start() - last_end), result)
		result.append("[i][color=#aaaaaa]%s[/color][/i]" % m.get_string(1))
		last_end = m.get_end()
	if last_end < text.length():
		_split_words(text.substr(last_end), result)
	return result

func _split_words(text: String, out: Array[String]) -> void:
	var words := text.split(" ")
	for i in range(words.size()):
		var word: String = words[i]
		if i < words.size() - 1:
			word += " "
		if word != "":
			out.append(word)

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

func _on_emotion_changed(affection: int, trust: int) -> void:
	status_label.text = "호감도: %d / 신뢰도: %d | 단계: %s | 감정: %s(%d)" % [
		affection, trust,
		npc_chat.emotion.get_stage_name(),
		npc_chat.mood.current_label, npc_chat.mood.current_intensity,
	]

func _on_mood_changed(label: String, intensity: int) -> void:
	status_label.text = "호감도: %d / 신뢰도: %d | 단계: %s | 감정: %s(%d)" % [
		npc_chat.emotion.affection, npc_chat.emotion.trust,
		npc_chat.emotion.get_stage_name(),
		label, intensity,
	]

func _on_stage_changed(stage: String) -> void:
	var entry := "\n[color=#ffdd88][i]— 관계 단계 변화: %s —[/i][/color]\n" % stage
	_chat_log_content += entry
	chat_log.append_text(entry)

func _on_action_triggered(action_name: String) -> void:
	print("액션 발동: ", action_name)
