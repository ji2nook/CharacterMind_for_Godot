extends Node
class_name CharacterChat

# --- 시그널 ---
## 가드레일을 통과한 전체 응답이 준비됐을 때 발생 (단어 단위 표시용)
signal response_token(text: String)
## 응답이 완전히 끝났을 때 최종 텍스트와 함께 발생
signal response_received(text: String)
## 가드레일이 작동하여 응답이 차단됐을 때 fallback 텍스트와 함께 발생
signal guardrail_blocked(fallback: String)
## 백엔드 오류로 응답을 받지 못했을 때 사용자에게 보여줄 메시지와 함께 발생
signal request_failed(message: String)

# --- 외부 설정 ---
## 캐릭터 행동을 정의하는 설정 리소스
@export var config: CharacterAIConfig
## 캐릭터의 부적절한 발언을 방지하는 가드레일 노드
@export var guardrail: CharacterGuardrail
## 추론 백엔드 (LocalBackend 또는 CloudBackend)
@export var backend: CharacterBackend
## 캐릭터의 플레이어에 대한 감정 노드
@export var emotion: CharacterEmotion
## 캐릭터의 현재 감정 상태 노드
@export var mood: CharacterMood
## 캐릭터 액션 노드
@export var action: CharacterAction
## 게임 세계의 현재 상태(시간대, 위치, 최근 이벤트)를 제공하는 인식 노드
@export var perception: CharacterPerception
## 대화 중 중요 정보를 저장하고 관련도 기반으로 검색하는 기억 노드
@export var memory: CharacterMemory


# --- 내부 상태 ---
## 다음 send_message() 호출 전에 대화 기록을 초기화해야 하는지 여부
var _needs_reset := false
var _emoji_regex: RegEx

func _ready() -> void:
	_emoji_regex = RegEx.new()
	_emoji_regex.compile("[\\x{1F000}-\\x{1FAFF}\\x{2600}-\\x{27BF}\\x{FE00}-\\x{FEFF}]")
	backend.system_prompt = _build_system_prompt()
	backend.response_finished.connect(_on_response_finished)
	backend.request_failed.connect(request_failed.emit)


## 대화 상대를 다른 캐릭터로 전환
func switch_character(new_profile: CharacterProfile) -> void:
	config.profile = new_profile
	config.mark_dirty()
	_needs_reset = true
	if emotion and new_profile:
		emotion.reset_to(new_profile.initial_affection, new_profile.initial_trust)
	if mood:
		mood.current_label = "NEUTRAL"
		mood.current_intensity = 1
		mood.mood_changed.emit(mood.current_label, mood.current_intensity)

## 플레이어 메시지를 백엔드에 전달
func send_message(player_text: String) -> void:
	if guardrail:
		var checked := guardrail.check(player_text)
		if checked != player_text:
			guardrail_blocked.emit(checked)
			response_received.emit(checked)
			return

	var system_text := _build_system_prompt()
	if system_text != backend.system_prompt:
		backend.system_prompt = system_text

	# 동적 상태(감정/무드/인식)는 시스템 프롬프트 대신 유저 메시지 앞에 주입
	# → 시스템 프롬프트가 턴마다 바뀌지 않아 로컬 KV 캐시가 보존됨
	var context_parts: Array[String] = []
	if emotion:
		context_parts.append(emotion.get_dynamic_prompt_context())
	if mood:
		context_parts.append(mood.get_mood_prompt_line())
	if perception:
		context_parts.append(perception.build_context_line())
	if memory:
		var summary := memory.get_relevant_summary(player_text)
		if summary != "":
			context_parts.append("관련 기억:\n- " + summary)
	if config.shared_lore:
		var shared := config.shared_lore.get_relevant_lore(player_text)
		if shared != "":
			context_parts.append("세계관 공통 설정:\n- " + shared)
	if config.profile and config.profile.lore:
		var personal: String = config.profile.lore.get_relevant_lore(player_text)
		if personal != "":
			context_parts.append("이 캐릭터가 아는 정보:\n- " + personal)

	var message := player_text
	if not context_parts.is_empty():
		message = "\n".join(context_parts) + "\n" + player_text

	if _needs_reset:
		_needs_reset = false
		backend.reset()
		# LocalBackend는 reset() 후 한 프레임이 필요하므로 deferred 호출
		call_deferred("_do_say", message, player_text)
		return

	backend.say(message, player_text)

func _do_say(message: String, raw_message: String) -> void:
	backend.say(message, raw_message)

## 앞 30자 패턴이 5회 이상 반복되면 반복 루프로 판단한다
func _is_repetition_loop(text: String) -> bool:
	if text.length() < 100:
		return false
	var sample := text.substr(0, 30)
	return text.count(sample) >= 5

## config + action 조합으로 시스템 프롬프트를 빌드한다
func _build_system_prompt() -> String:
	var prompt := config.build_safe_system_prompt()
	if action:
		prompt += action.build_action_instruction()
	return prompt

## 응답 완료 시 전체 텍스트를 검열하고 통과한 경우에만 emit
func _on_response_finished(full_text: String) -> void:
	if _is_repetition_loop(full_text):
		_needs_reset = true
		request_failed.emit("응답 생성 중 오류가 발생했습니다. 다시 시도해주세요.")
		return

	var processed_text := _strip_emoji(_strip_thinking(full_text))

	var has_emotion := emotion != null
	if has_emotion:
		processed_text = emotion.extract_and_apply(processed_text)
	if mood:
		processed_text = mood.extract_and_apply(processed_text)
	if action:
		processed_text = action.extract_and_apply(processed_text)
	if has_emotion:
		emotion.tick()

	if guardrail:
		var result := guardrail.check(processed_text)
		if result != processed_text:
			_needs_reset = true
			guardrail_blocked.emit(result)
			response_received.emit(result)
			return

	if processed_text != "":
		response_token.emit(processed_text)
	response_received.emit(processed_text)

func _strip_emoji(text: String) -> String:
	return _emoji_regex.sub(text, "", true)

## 전체 응답 텍스트에서 <think>...</think> 블록을 제거하고 반환
func _strip_thinking(text: String) -> String:
	const THINK_CLOSE_LEN: int = 8  # len("</think>")
	var end_idx := text.find("</think>")
	if end_idx == -1:
		return text.strip_edges()
	return text.substr(end_idx + THINK_CLOSE_LEN).strip_edges()
