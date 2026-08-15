extends Node
class_name CharacterAction

## 이 캐릭터가 호출할 수 있는 액션 이름 목록 (인스펙터에서 캐릭터별로 다르게 설정)
@export var available_actions: Array[String] = []

signal action_triggered(action_name: String)

## AI 응답에서 [ACTION ###] 태그를 찾아 시그널로 발신하고 태그 제거
func extract_and_apply(raw_text: String) -> String:
	var regex := RegEx.new()
	regex.compile("\\[ACTION ([a-zA-Z_]+)\\]")
	var result := regex.search(raw_text)
	if result:
		var action_name := result.get_string(1)
		if action_name in available_actions and action_name != "none":
			action_triggered.emit(action_name)
		return raw_text.replace(result.get_string(0), "").strip_edges()
	return raw_text

func build_action_instruction() -> String:
	var usable := available_actions.filter(func(a: String) -> bool: return a != "none")
	if usable.is_empty():
		return ""
	return "\n\n대화 중 다음 행동이 필요하다고 판단되면 답변 마지막 줄에 [ACTION 행동이름] 형식으로 표시해야 해 (필요하지 않으면 표시하지 않음). 사용 가능한 행동: " + ", ".join(usable)
