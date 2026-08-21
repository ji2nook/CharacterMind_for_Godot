extends Resource
class_name CharacterLore

## 배경 지식 조각 목록 — 각 항목은 한 사실을 담은 짧은 문장으로 작성한다
## 대화 내용과 관련 있는 항목만 골라 프롬프트에 주입되므로 항목을 세분화할수록 정확도가 높아진다
@export var entries: Array[String] = []

## 현재 대화와 관련도가 높은 로어 조각 상위 top_k개를 반환
func get_relevant_lore(current_message: String, top_k: int = 2) -> String:
	if entries.is_empty():
		return ""
	var scored: Array = []
	for lore_text in entries:
		var score := 0.0
		for word in current_message.split(" "):
			if word.length() > 1 and lore_text.to_lower().contains(word.to_lower()):
				score += 1.0
		if score > 0:
			scored.append({"text": lore_text, "score": score})
	if scored.is_empty():
		return ""
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] > b["score"])
	var picked: Array[String] = []
	for i in range(min(top_k, scored.size())):
		picked.append(scored[i]["text"])
	return "\n- ".join(picked)
