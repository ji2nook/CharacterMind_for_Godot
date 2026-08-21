extends Node
class_name CharacterSaveManager

@export var emotion: CharacterEmotion
@export var mood: CharacterMood
@export var memory: CharacterMemory
## 세이브 파일이 저장될 디렉터리 (끝에 / 포함)
@export var save_dir: String = "user://"
## 0이면 비활성화 — N 턴마다 자동 저장 (안전장치)
@export var auto_save_interval: int = 5

var _turns_since_save: int = 0
var _current_character: String = ""

func _exit_tree() -> void:
	save_state()

## 현재 활성 캐릭터 이름을 설정 — CharacterChat.switch_character() 에서 호출
func set_character(character_name: String) -> void:
	_current_character = character_name

func _get_path() -> String:
	var safe_name := _current_character.to_lower().replace(" ", "_")
	return save_dir + "save_%s.json" % safe_name

func save_state() -> void:
	if _current_character == "":
		return
	var data := {
		"affection": emotion.affection if emotion else 0,
		"trust": emotion.trust if emotion else 0,
		"has_met": emotion._has_met if emotion else false,
		"mood": mood.current_label if mood else "NEUTRAL",
		"memory_entries": memory.entries if memory else [],
		"turn_count": memory.turn_count if memory else 0,
	}
	var file := FileAccess.open(_get_path(), FileAccess.WRITE)
	if not file:
		push_error("CharacterSaveManager: 저장 파일을 열 수 없음 — %s" % _get_path())
		return
	file.store_string(JSON.stringify(data))
	file.close()
	_turns_since_save = 0

func load_state() -> void:
	if _current_character == "":
		return
	var path := _get_path()
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("CharacterSaveManager: 저장 파일을 읽을 수 없음 — %s" % path)
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if not data is Dictionary:
		push_error("CharacterSaveManager: 저장 데이터 파싱 실패")
		return
	if emotion:
		emotion.affection = data.get("affection", 0)
		emotion.trust = data.get("trust", 0)
		emotion._has_met = data.get("has_met", false)
		emotion.emotion_changed.emit(emotion.affection, emotion.trust)
	if mood:
		mood.current_label = data.get("mood", "NEUTRAL")
		mood.mood_changed.emit(mood.current_label, mood.current_intensity)
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
