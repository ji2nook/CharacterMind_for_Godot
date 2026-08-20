extends Node
class_name CharacterGuardrail

@export var blocked_categories: Dictionary = {
	"정치": ["정치키워드1", "정치키워드1"],
	"혐오발언": ["혐오키워드1", "혐오키워드2"],
	"선정성": ["선정적키워드1", "선정적키워드2"],
}
@export var fallback_lines: Array[String] = [
	"어... 무슨 얘기인지 모르겠어요.",
	"다른 이야기를 해 볼까요?"
]

## 현재 활성 캐릭터의 fallback 대사 — switch_character() 시 CharacterChat이 교체
var _active_fallbacks: Array[String] = []
var _lower_cache: Dictionary = {}

signal blocked(category: String, text: String)

func _ready() -> void:
	_active_fallbacks = fallback_lines
	for category in blocked_categories.keys():
		var lower_list: Array[String] = []
		for keyword in blocked_categories[category]:
			lower_list.append(str(keyword).to_lower())
		_lower_cache[category] = lower_list

func _pick_fallback() -> String:
	var pool := _active_fallbacks if not _active_fallbacks.is_empty() else fallback_lines
	if pool.is_empty():
		return "..."
	return pool[randi() % pool.size()]

## 입/출력 공통 필터
func check(text: String) -> String:
	return check_output(text)

## 플레이어 입력 필터
func check_input(player_text: String) -> String:
	var lower_text := player_text.to_lower()
	for category in _lower_cache.keys():
		for keyword: String in _lower_cache[category]:
			if lower_text.contains(keyword):
				blocked.emit(category, player_text)
				return _pick_fallback()
	return player_text

## AI 출력 필터
func check_output(text: String) -> String:
	var lower_text := text.to_lower()
	for category in _lower_cache.keys():
		for keyword: String in _lower_cache[category]:
			if lower_text.contains(keyword):
				blocked.emit(category, text)
				return _pick_fallback()
	return text
