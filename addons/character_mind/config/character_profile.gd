extends Resource
class_name CharacterProfile

# --- 캐릭터 기본 프로필 설정---
@export_group("기본 정보")
@export var character_name: String = "캐릭터 이름"
@export var age: int = 20
@export var gender: String = ""
@export var occupation: String = ""
@export var location: String = ""

@export_group("외형")
@export_multiline var appearance: String = ""

@export_group("성격")
@export_multiline var personality: String = ""
@export var personality_traits: Array[String] = []
@export_multiline var speech_style: String = ""

@export_group("배경 설정")
@export_multiline var backstory: String = ""
@export var likes: Array[String] = []
@export var dislikes: Array[String] = []

## 해당 캐릭터만 알고 있는 개인 지식 (직업/신분 특화 정보 등)
@export var lore: CharacterLore

@export_group("관계 초기값")
@export var initial_affection: int = 0
@export var initial_trust: int = 0
@export var decay_interval: int = 10

@export_group("예시 대화")
## 캐릭터 말투를 학습시킬 대화 예시 — 짝수 인덱스: 유저 발화, 홀수 인덱스: 캐릭터 응답
@export var example_dialogues: Array[String] = []
## 가드레일 차단 시 이 캐릭터가 말할 대체 대사 — 비워두면 CharacterAIConfig의 기본 fallback을 사용한다
@export var guardrail_fallbacks: Array[String] = []

@export_group("커스텀 프롬프트")
## 위 설정 외에 추가로 주입할 프롬프트 — 특수한 행동 규칙이나 말투 세부 조정에 사용한다
@export_multiline var custom_prompt: String = ""

## 프로필 설정 전체를 시스템 프롬프트용 문자열로 변환한다
func build_persona_prompt() -> String:
	var lines: Array[String] = []
	lines.append("[%s의 설정]" % character_name)
	if age > 0:
		lines.append("나이: %d세" % age)
	if occupation != "":
		lines.append("직업: %s" % occupation)
	if personality != "":
		lines.append("성격: %s" % personality)
	if speech_style != "":
		lines.append("말투: %s" % speech_style)
	if backstory != "":
		lines.append("배경: %s" % backstory)
	lines.append("항상 위 설정에 맞는 성격과 말투를 유지해.")
	if example_dialogues.size() >= 2:
		lines.append("\n[대화 예시]")
		var i := 0
		while i + 1 < example_dialogues.size():
			lines.append("유저: %s" % example_dialogues[i])
			lines.append("%s: %s" % [character_name, example_dialogues[i + 1]])
			i += 2
	return "\n".join(lines)
