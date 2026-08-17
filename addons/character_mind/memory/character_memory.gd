extends Node
class_name CharacterMemory

@export var max_entries: int = 20
@export var entries_per_prompt: int = 3

var entries: Array[Dictionary] = []
var turn_count: int = 0

signal memory_updated

func add_entry(text: String, importance: int = 1) -> void:
	turn_count += 1
	entries.append({"text": text, "turn": turn_count, "importance": importance})
	if entries.size() > max_entries:
		entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a["importance"] < b["importance"]
		)
		entries.pop_front()
	memory_updated.emit()

## 현재 메시지와 관련도가 높은 기억 항목을 상위 entries_per_prompt 개수만큼 반환
func get_relevant_summary(current_message: String) -> String:
	if entries.is_empty():
		return ""
	var scored: Array[Dictionary] = []
	for e in entries:
		var score := float(e["importance"])
		for word in current_message.split(" "):
			if word.length() > 1 and e["text"].to_lower().contains(word.to_lower()):
				score += 2.0
		score += float(e["turn"]) / float(max(turn_count, 1))
		scored.append({"text": e["text"], "score": score})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["score"] > b["score"]
	)
	var picked: Array[String] = []
	for i in range(min(entries_per_prompt, scored.size())):
		picked.append(scored[i]["text"])
	return "\n- ".join(picked)
