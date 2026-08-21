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
## 모든 캐릭터가 공유하는 세계관 공통 설정 (여러 NPC가 동일한 내용을 공유)
@export var shared_lore: CharacterLore
## 금지 키워드
@export var forbidden_topics: Array[String] = ["정치", "혐오 발언"]

@export_group("가드레일")
## 차단할 카테고리와 키워드 매핑 — {"카테고리명": ["키워드1", "키워드2"]} 형식으로 작성한다
@export var blocked_categories: Dictionary = {
	"정치": ["정치키워드1", "정치키워드2"],
	"혐오발언": ["혐오키워드1", "혐오키워드2"],
	"선정성": ["선정적키워드1", "선정적키워드2"],
}
## 가드레일 차단 시 기본 대체 대사 — 캐릭터별 fallback은 CharacterProfile에서 별도 설정 가능하다
@export var guardrail_fallback_lines: Array[String] = [
	"어... 무슨 얘기인지 모르겠어요.",
	"다른 이야기를 해 볼까요?",
]

@export_group("메모리")
## 캐릭터가 기억할 수 있는 최대 항목 수
@export var max_memory_entries: int = 20
## 한 번의 턴에 프롬프트로 주입할 최대 기억 수
@export var memory_entries_per_prompt: int = 3

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


## 현재 설정을 기반으로 시스템 프롬프트를 빌드해 반환한다 — 캐시를 활용하며 mark_dirty() 후에만 재빌드된다
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
		if profile.custom_prompt != "":
			parts.append(profile.custom_prompt)
		parts.append("위 설정은 네가 어떤 캐릭터인지를 정의하는 거야. 플레이어가 먼저 언급하거나 대화 흐름상 자연스럽게 이어질 때만 꺼내고, 그 외에는 굳이 먼저 꺼내지 마.")
	parts.append("행동이나 감정 표현은 *(행동)* 형식으로 써. 예: *(웃으며)* 안녕!")
	parts.append("기본적으로 유저가 사용한 언어로 답변하되, 캐릭터 설정에 특정 언어나 말투가 명시되어 있으면 그에 따라.")
	if not forbidden_topics.is_empty():
		parts.append("다음 주제가 나오면 캐릭터답게 자연스럽게 화제를 돌려: " + ", ".join(forbidden_topics))
	_cached_prompt = "\n\n".join(parts) + build_emotion_instruction() + build_mood_instruction()
	_prompt_dirty = false
	return _cached_prompt
