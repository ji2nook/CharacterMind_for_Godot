extends Node
class_name CharacterSaveManager

@export var emotion: CharacterEmotion
@export var mood: CharacterMood
@export var memory: CharacterMemory
@export var save_path: String = "user://character_save.json"
## 0이면 비활성화 — N 턴마다 자동 저장 (안전장치)
@export var auto_save_interval: int = 5

var _turns_since_save: int = 0

func _exit_tree() -> void:
	save_state()

func save_state() -> void:
	var data := {
		"affection": emotion.affection if emotion else 0,
		"trust": emotion.trust if emotion else 0,
		"mood": mood.current_label if mood else "NEUTRAL",
		"memory_entries": memory.entries if memory else [],
		"turn_count": memory.turn_count if memory else 0,
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		push_error("CharacterSaveManager: 저장 파일을 열 수 없음 — %s" % save_path)
		return
	file.store_string(JSON.stringify(data))
	file.close()
	_turns_since_save = 0

func load_state() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if not file:
		push_error("CharacterSaveManager: 저장 파일을 읽을 수 없음 — %s" % save_path)
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if not data is Dictionary:
		push_error("CharacterSaveManager: 저장 데이터 파싱 실패")
		return
	if emotion:
		emotion.affection = data.get("affection", 0)
		emotion.trust = data.get("trust", 0)
	if mood:
		mood.current_label = data.get("mood", "NEUTRAL")
	if memory:
		var raw: Array = data.get("memory_entries", [])
		var typed: Array[Dictionary] = []
		for e in raw:
			if e is Dictionary:
				if not e.has("embedding"):
					e["embedding"] = []
				typed.append(e)
		memory.entries = typed
		memory.turn_count = data.get("turn_count", 0)

## CharacterChat이 응답 완료 후 호출 — auto_save_interval 주기마다 자동 저장
func on_turn_complete() -> void:
	if auto_save_interval <= 0:
		return
	_turns_since_save += 1
	if _turns_since_save >= auto_save_interval:
		save_state()
