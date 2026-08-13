extends Node
class_name CharacterGuardrail

@export var blocked_keywords: Array[String] = ["욕설1", "욕설2"]
@export var fallback_lines: Array[String] = [
	"어... 무슨 얘기인지 모르겠어요.",
	"다른 이야기를 해 볼까요?"
]

var _lower_keywords: Array[String] = []

func _ready() -> void:
	for keyword in blocked_keywords:
		_lower_keywords.append(keyword.to_lower())

func check(text: String) -> String:
	var lower_text := text.to_lower()
	for keyword in _lower_keywords:
		if lower_text.contains(keyword):
			return fallback_lines[randi() % fallback_lines.size()]
	return text
