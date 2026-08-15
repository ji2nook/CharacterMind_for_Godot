extends Node
class_name CharacterEmotion

signal emotion_changed(affection: int, trust: int)
signal stage_changed(stage: String)

enum RelationshipStage { HOSTILE, COLD, NEUTRAL, WARM, FRIENDLY }

const MIN_VALUE := -100
const MAX_VALUE := 100

## 자연 감쇠 주기: N 턴마다 affection을 0 방향으로 1 감소 (0 = 비활성화)
@export var decay_interval: int = 10

var affection: int = 0
var trust: int = 0
var _current_stage: RelationshipStage = RelationshipStage.NEUTRAL
var _turn_counter: int = 0

func _ready() -> void:
	_current_stage = get_relationship_stage()

## 초기 수치로 상태를 완전히 리셋 — 캐릭터 전환 시 호출
func reset_to(new_affection: int, new_trust: int) -> void:
	affection = clamp(new_affection, MIN_VALUE, MAX_VALUE)
	trust = clamp(new_trust, MIN_VALUE, MAX_VALUE)
	_current_stage = get_relationship_stage()
	_turn_counter = 0
	emotion_changed.emit(affection, trust)

## AI의 응답에서 감정 태그를 추출하고 수치에 반영한 뒤 제거
## 수익 체감: WARM(30+) 이상에서 LLM이 +2를 내려도 +1로 코드 단에서 제한
func extract_and_apply(raw_text: String) -> String:
	var regex := RegEx.new()
	regex.compile("\\[EMOTION affection=([+-]?\\d+) trust=([+-]?\\d+)\\]")
	var result := regex.search(raw_text)
	if result:
		var affection_delta := int(result.get_string(1))
		var trust_delta := int(result.get_string(2))
		if affection >= 30 and affection_delta > 1:
			affection_delta = 1
		affection = clamp(affection + affection_delta, MIN_VALUE, MAX_VALUE)
		trust = clamp(trust + trust_delta, MIN_VALUE, MAX_VALUE)
		emotion_changed.emit(affection, trust)
		_check_stage_change()
		return raw_text.replace(result.get_string(0), "").strip_edges()
	return raw_text

## 대화 한 턴이 완료될 때 호출 — decay_interval마다 affection을 0 방향으로 자연 감쇠
## affection이 MAX_VALUE(100)에 도달한 경우 감쇠를 보호 (Stardew Valley 방식)
func tick() -> void:
	_turn_counter += 1
	if decay_interval <= 0 or _turn_counter < decay_interval:
		return
	_turn_counter = 0
	if affection == MAX_VALUE:
		return
	if affection > 0:
		affection -= 1
	elif affection < 0:
		affection += 1
	emotion_changed.emit(affection, trust)
	_check_stage_change()

func get_relationship_stage() -> RelationshipStage:
	if affection >= 70:
		return RelationshipStage.FRIENDLY
	elif affection >= 30:
		return RelationshipStage.WARM
	elif affection >= -10:
		return RelationshipStage.NEUTRAL
	elif affection >= -30:
		return RelationshipStage.COLD
	return RelationshipStage.HOSTILE

func get_stage_name() -> String:
	match get_relationship_stage():
		RelationshipStage.FRIENDLY: return "FRIENDLY"
		RelationshipStage.WARM:     return "WARM"
		RelationshipStage.NEUTRAL:  return "NEUTRAL"
		RelationshipStage.COLD:     return "COLD"
		_:                          return "HOSTILE"

## 현재 관계 단계를 자연어로 반환해 시스템 프롬프트에 주입
func get_dynamic_prompt_context() -> String:
	return "현재 상태: " + get_mood_description()

func get_mood_description() -> String:
	match get_relationship_stage():
		RelationshipStage.FRIENDLY: return "캐릭터는 플레이어를 매우 친밀하게 여깁니다."
		RelationshipStage.WARM:     return "캐릭터는 플레이어에게 호감을 갖고 있습니다."
		RelationshipStage.NEUTRAL:  return "캐릭터는 플레이어에게 중립적입니다."
		RelationshipStage.COLD:     return "캐릭터는 플레이어를 경계하고 있습니다."
		_:                          return "캐릭터는 플레이어에게 적대적입니다."

func _check_stage_change() -> void:
	var new_stage := get_relationship_stage()
	if new_stage != _current_stage:
		_current_stage = new_stage
		stage_changed.emit(get_stage_name())
