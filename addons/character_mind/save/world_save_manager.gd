extends Node
class_name WorldSaveManager

## 캐릭터 간 공유 상태(이벤트 완료 여부, 캐릭터 간 관계 플래그 등)를 저장한다.
## 각 캐릭터 개별 상태는 CharacterSaveManager가 담당하며, 이 클래스는 그것과 독립적으로 동작한다.
##
## 사용 예:
##   world_save.set_flag("festival_complete", true)
##   world_save.set_flag("alice_knows_bob_betrayed", true)
##   if world_save.get_flag("festival_complete", false):
##       ...

## 세계 공유 상태 저장 파일 경로
@export var save_path: String = "user://world_state.json"

var _data: Dictionary = {}

func _exit_tree() -> void:
	save()

func save() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		push_error("WorldSaveManager: 저장 파일을 열 수 없음 — %s" % save_path)
		return
	file.store_string(JSON.stringify(_data))
	file.close()

func load() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if not file:
		push_error("WorldSaveManager: 저장 파일을 읽을 수 없음 — %s" % save_path)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_error("WorldSaveManager: 저장 데이터 파싱 실패")
		return
	_data = parsed

## 키에 값을 기록한다. value는 JSON으로 직렬화 가능한 타입이어야 한다.
func set_flag(key: String, value: Variant) -> void:
	_data[key] = value

## 키에 저장된 값을 반환한다. 없으면 default를 반환한다.
func get_flag(key: String, default: Variant = null) -> Variant:
	return _data.get(key, default)

func has_flag(key: String) -> bool:
	return _data.has(key)

func erase_flag(key: String) -> void:
	_data.erase(key)
