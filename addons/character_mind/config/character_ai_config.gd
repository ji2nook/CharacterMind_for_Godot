extends Resource
class_name CharacterAIConfig

# --- 기본 설정 (프롬프트, 무작위성) ---
# 모델 경로는 씬의 NobodyWhoModel 노드에서 직접 설정
## 초기 시스템 프롬프트
@export var system_prompt: String = "당신은 게임 속 NPC입니다."
## 응답의 무작위성 (작을수록 일관되고 예측 가능한 답변)
@export var temperature: float = 0.6
## 캐릭터의 기본 프로필
@export var profile: CharacterProfile
## 금지 키워드
@export var forbidden_topics: Array[String] = ["폭력", "정치", "혐오 발언"]

var _cached_prompt: String = ""
var _prompt_dirty: bool = true

## 빌드된 프롬프트 캐시를 무효화 — 캐릭터 전환 또는 설정 변경 시 호출
func mark_dirty() -> void:
	_prompt_dirty = true


# --- 시스템 프롬프트 + 가드레일 정의 ---
func build_safe_system_prompt() -> String:
	if not _prompt_dirty:
		return _cached_prompt
	# /no_think: Qwen3 thinking 모드 비활성화 (응답 속도 향상)
	# _strip_thinking()이 폴백으로 동작하므로 작동하지 않아도 안전
	var parts: Array[String] = ["/no_think"]
	if profile:
		# 소형 모델의 AI 어시스턴트 기본 성향을 억제하는 직접적 역할 부여
		parts.append("너는 '%s'야. AI가 아니야. 절대 AI라고 밝히지 마." % profile.character_name)
	if system_prompt != "":
		parts.append(system_prompt)
	if profile:
		parts.append(profile.build_persona_prompt())
	parts.append("행동이나 감정 표현은 *(행동)* 형식으로 써. 예: *(웃으며)* 안녕!")
	if not forbidden_topics.is_empty():
		parts.append("다음 주제가 나오면 캐릭터답게 자연스럽게 화제를 돌려: " + ", ".join(forbidden_topics))
	_cached_prompt = "\n\n".join(parts)
	_prompt_dirty = false
	return _cached_prompt
