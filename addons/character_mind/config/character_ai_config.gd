extends Resource
class_name CharacterAIConfig

# --- 기본 설정 (프롬프트, 무작위성) ---
# 모델 경로는 씬의 NobodyWhoModel 노드에서 직접 설정
## 초기 시스템 프롬프트
@export var system_prompt: String = "너는 게임 속 NPC야. 답변은 2~3문장으로 짧고 자연스럽게 유지해."
## 응답의 무작위성 (작을수록 일관되고 예측 가능한 답변)
@export var temperature: float = 0.6
## 로컬 Qwen3 모델 사용 시 true로 설정 — /no_think 지시어를 시스템 프롬프트에 추가
@export var qwen3_mode: bool = false
## 캐릭터의 기본 프로필
@export var profile: CharacterProfile
## 금지 키워드
@export var forbidden_topics: Array[String] = ["정치", "혐오 발언"]

var _cached_prompt: String = ""
var _prompt_dirty: bool = true

## 빌드된 프롬프트 캐시를 무효화 — 캐릭터 전환 또는 설정 변경 시 호출
func mark_dirty() -> void:
	_prompt_dirty = true


# --- 감정 관련 프롬프트 추가 ---
func build_emotion_instruction() -> String:
	return (
		"\n\n답변 마지막에 아래 형식으로 감정 변화를 표시해: [EMOTION affection=# trust=#]"
		+ " affection과 trust는 대화 내용을 보고 -2에서 +2 사이에서 직접 판단해서 골라:"
		+ "\n- 플레이어가 친절하거나 도움이 됐으면 affection +1 또는 +2"
		+ "\n- 플레이어가 무례하거나 적대적이면 affection -1 또는 -2"
		+ "\n- 신뢰할 행동을 했으면 trust +1, 거짓말하거나 배신했으면 trust -1"
		+ "\n- 특별한 변화가 없으면 0"
	)

func build_mood_instruction() -> String:
	return (
		"\n대화 분위기에 맞는 감정을 하나 골라 표시해: [MOOD ###] / ###에는 다음 감정 중 하나를 선택해서 기재해."
		+ "\n- 기쁘거나 즐거우면 JOY, 화나면 ANGER, 슬프면 SADNESS"
		+ "\n- 놀라면 SURPRISE, 애정을 느끼면 AFFECTION, 의심스러우면 DISTRUST"
		+ "\n- 특별한 감정이 없으면 NEUTRAL"
	)


# --- 시스템 프롬프트 + 가드레일 정의 ---
func build_safe_system_prompt() -> String:
	if not _prompt_dirty:
		return _cached_prompt
	var parts: Array[String] = []
	# 로컬 Qwen3 모델 사용 시 thinking 모드 비활성화 — 클라우드 모델에는 불필요
	if qwen3_mode:
		parts.append("/no_think")
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
	_cached_prompt = "\n\n".join(parts) + build_emotion_instruction() + build_mood_instruction()
	_prompt_dirty = false
	return _cached_prompt
