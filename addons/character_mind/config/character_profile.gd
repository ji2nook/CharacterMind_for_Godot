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

@export_group("관계 초기값")
@export var initial_affection: int = 0
@export var initial_trust: int = 0


# --- 시스템 프롬프트 ---
func build_persona_prompt() -> String:
	var lines: Array[String] = []
	lines.append("당신은 '%s'라는 이름의 캐릭터입니다.\n" % character_name)
	if age > 0:
		lines.append("나이: %d세\n" % age)
	if occupation != "":
		lines.append("직업: %s\n" % occupation)
	if personality != "":
		lines.append("성격: %s\n" % personality)
	if speech_style != "":
		lines.append("말투의 특징: %s\n" % speech_style)
	if backstory != "":
		lines.append("배경 스토리: %s\n" % backstory)
	lines.append("항상 위 설정에 맞는 성격과 말투를 유지하며 대화하세요.")
	return "\n".join(lines)
