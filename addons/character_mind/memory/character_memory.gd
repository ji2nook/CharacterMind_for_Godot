extends Node
class_name CharacterMemory

var max_entries: int = 20
var entries_per_prompt: int = 3
@export var embedding_node: Node

var entries: Array[Dictionary] = []
var turn_count: int = 0

signal memory_updated

func add_entry(text: String, importance: int = 1) -> void:
	turn_count += 1
	var entry := {"text": text, "turn": turn_count, "importance": importance, "embedding": []}
	entries.append(entry)
	if entries.size() > max_entries:
		entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a["importance"] < b["importance"]
		)
		entries.pop_front()
	memory_updated.emit()
	
	if embedding_node:
		embedding_node.encoding_finished.connect(
			func(emb: PackedFloat32Array): entry["embedding"] = Array(emb),
			CONNECT_ONE_SHOT
		)
		embedding_node.encode(text)

## 현재 메시지와 관련도가 높은 기억 항목을 상위 entries_per_prompt 개수만큼 반환
func get_relevant_summary(current_message: String, query_embedding: Array = []) -> String:
	if entries.is_empty():
		return ""
	if query_embedding.is_empty() or not embedding_node:
		return _keyword_search(current_message)
	return _embedding_search(query_embedding)

func has_embeddings() -> bool:
	for e in entries:
		if not e.get("embedding", []).is_empty():
			return true
	return false

func _embedding_search(query_embedding: Array) -> String:
	var scored: Array[Dictionary] = []
	var q := PackedFloat32Array(query_embedding)
	for e in entries:
		var emb: Array = e.get("embedding", [])
		if emb.is_empty():
			continue
		var score: float = embedding_node.cosine_similarity(q, PackedFloat32Array(emb))
		scored.append({"text": e["text"], "score": score})
	if scored.is_empty():
		return ""
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["score"] > b["score"]
	)
	var picked: Array[String] = []
	for i in range(min(entries_per_prompt, scored.size())):
		picked.append(scored[i]["text"])
	return "\n- ".join(picked)

func _keyword_search(current_message: String) -> String:
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
