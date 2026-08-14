extends Resource
class_name CharacterAIConfig

# --- 기본 설정 (모델, 프롬프트, 무작위성) ---
## GGUF 모델 파일 경로
@export_file("*.gguf") var model_path: String = "res://models/Qwen3-0.6B-Q8_0.gguf"
## 초기 시스템 프롬프트
@export var system_prompt: String = "당신은 게임 속 NPC입니다."
## 응답의 무작위성 (작을수록 일관되고 예측 가능한 답변)
@export var temperature: float = 0.8
## 캐릭터의 기본 프로필
@export var profile: CharacterProfile
## 금지 키워드
@export var forbidden_topics: Array[String] = ["폭력", "정치", "혐오 발언"]


# --- 시스템 프롬프트 + 가드레일 정의 ---
func build_safe_system_prompt() -> String:
	var base_prompt := system_prompt
	if profile:
		base_prompt = system_prompt + "\n\n" + profile.build_persona_prompt()
	var safety_notice := "\n\n다음 주제에 대해서는 절대 답변하지 않고 자연스럽게 화제를 돌려야 합니다: "
	safety_notice += ", ".join(forbidden_topics)
	return base_prompt + safety_notice
