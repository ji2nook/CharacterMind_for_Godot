extends Resource
class_name CharacterAIConfig

@export_file("*.gguf") var model_path: String = "res://models/Qwen3-0.6B-Q8_0.gguf"
@export var system_prompt: String = "당신은 게임 속 NPC입니다."
@export var temperature: float = 0.8
