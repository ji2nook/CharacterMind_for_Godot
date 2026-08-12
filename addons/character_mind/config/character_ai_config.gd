extends Resource
class_name CharacterAIConfig

# --- 기본 설정 (모델, 프롬프트, 무작위성) ---
## GGUF 모델 파일 경로
@export_file("*.gguf") var model_path: String = "res://models/Qwen3-0.6B-Q8_0.gguf"
## 캐릭터 기본 성격과 역할을 정의하는 시스템 프롬프트
@export var system_prompt: String = "당신은 게임 속 NPC입니다."
## 응답의 무작위성 (작을수록 일관되고 예측 가능한 답변)
@export var temperature: float = 0.8
