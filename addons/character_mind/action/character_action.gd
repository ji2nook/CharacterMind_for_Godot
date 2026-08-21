extends Node
class_name CharacterAction

## 이 캐릭터가 호출할 수 있는 액션 정의 목록 (인스펙터에서 캐릭터별로 설정)
@export var actions: Array[CharacterActionDef] = []

## action_id와 파싱된 파라미터 딕셔너리를 함께 전달
signal action_triggered(action_id: String, params: Dictionary)

var _regex: RegEx
var _instruction_cache: String = ""
var _instruction_dirty: bool = true

func _ready() -> void:
	_regex = RegEx.new()
	# [ACTION action_id] 또는 [ACTION action_id key=val key2=val2] 형식을 모두 허용
	_regex.compile("\\[ACTION (\\w+)(?:\\s+([^\\]]*?))?\\]")

## AI 응답에서 [ACTION ...] 태그를 모두 찾아 순서대로 시그널로 발신하고 태그 제거
func extract_and_apply(raw_text: String) -> String:
	var results := _regex.search_all(raw_text)
	if results.is_empty():
		return raw_text
	var cleaned := raw_text
	for result in results:
		var action_id := result.get_string(1)
		var action_def := _find_action(action_id)
		if action_def and action_def.enabled:
			action_triggered.emit(action_id, _parse_params(result.get_string(2)))
		cleaned = cleaned.replace(result.get_string(0), "")
	return cleaned.strip_edges()

## 런타임에 특정 액션의 활성 상태를 변경 (예: 퀘스트 수주 후 비활성화)
func set_action_enabled(action_id: String, enabled: bool) -> void:
	var action_def := _find_action(action_id)
	if action_def:
		action_def.enabled = enabled
		_instruction_dirty = true

## 활성화된 액션 목록을 시스템 프롬프트에 추가할 지시문으로 반환한다 — 활성 액션이 없으면 빈 문자열
func build_action_instruction() -> String:
	if not _instruction_dirty:
		return _instruction_cache
	var usable: Array[CharacterActionDef] = actions.filter(
		func(a: CharacterActionDef) -> bool: return a.enabled and a.action_id != ""
	)
	if usable.is_empty():
		_instruction_cache = ""
		_instruction_dirty = false
		return _instruction_cache
	var lines: Array[String] = [
		"\n\n액션이 필요하다고 판단될 때만 답변 마지막 줄에 태그를 표시해 (불필요하면 생략):"
	]
	for action_def in usable:
		var hint: String
		if action_def.parameters.is_empty():
			hint = "[ACTION %s]" % action_def.action_id
		else:
			var param_hint := " ".join(
				action_def.parameters.map(func(p: String) -> String: return "%s=값" % p)
			)
			hint = "[ACTION %s %s]" % [action_def.action_id, param_hint]
		lines.append("- %s: %s → %s" % [action_def.action_id, action_def.description, hint])
	_instruction_cache = "\n".join(lines)
	_instruction_dirty = false
	return _instruction_cache

func _find_action(action_id: String) -> CharacterActionDef:
	for action_def in actions:
		if action_def.action_id == action_id:
			return action_def
	return null

func _parse_params(params_str: String) -> Dictionary:
	var params: Dictionary = {}
	if params_str == "":
		return params
	for pair in params_str.strip_edges().split(" "):
		var kv := pair.split("=")
		if kv.size() == 2 and kv[0] != "" and kv[1] != "":
			params[kv[0]] = kv[1]
	return params
