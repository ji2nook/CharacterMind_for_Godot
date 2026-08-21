extends Node
class_name CharacterMemory

## 기억 항목의 최대 개수 — 초과 시 importance가 낮은 항목부터 자동 제거된다
var max_entries: int = 20
## 한 번의 프롬프트에 주입할 최대 기억 수
var entries_per_prompt: int = 3
## 기억 임베딩을 생성할 NobodyWhoEncoder 노드 — 없으면 키워드 검색으로 대체된다
@export var embedding_node: Node

## 저장된 기억 항목 배열 — 각 항목은 {text, turn, importance, embedding} 딕셔너리
var entries: Array[Dictionary] = []
## 누적 턴 수 — 키워드 검색 시 최신성 가중치 계산에 사용된다
var turn_count: int = 0

## 기억 항목이 추가되거나 제거됐을 때 발생
signal memory_updated

## 대화 중 기억할 내용을 추가한다
## importance가 높을수록 메모리가 꽉 찼을 때 늦게 제거된다 (기본값 1)
func add_entry(text: String, importance: int = 1) -> void:
	turn_count += 1
	# 새 항목 추가 전에 공간을 먼저 확보 — 이후 entry는 항상 entries에 존재함을 보장
	if entries.size() >= max_entries:
		entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a["importance"] < b["importance"]
		)
		entries.pop_front()
	var entry := {"text": text, "turn": turn_count, "importance": importance, "embedding": []}
	entries.append(entry)
	memory_updated.emit()

	if embedding_node:
		embedding_node.encoding_finished.connect(
			func(emb: PackedFloat32Array): entry["embedding"] = Array(emb),
			CONNECT_ONE_SHOT
		)
		embedding_node.encode(text)

## 현재 메시지와 관련도가 높은 기억을 최대 entries_per_prompt개 반환한다
## query_embedding이 있으면 코사인 유사도, 없으면 키워드 검색을 사용한다
func get_relevant_summary(current_message: String, query_embedding: Array = []) -> String:
	if entries.is_empty():
		return ""
	if query_embedding.is_empty() or not embedding_node:
		return _keyword_search(current_message)
	return _embedding_search(query_embedding)

## 임베딩이 기록된 항목이 하나라도 있는지 확인한다
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
