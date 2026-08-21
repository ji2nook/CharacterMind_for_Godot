extends Node
class_name CharacterPerception

## 현재 시간대 — 게임 세계의 낮/밤 주기에 따라 갱신한다 (예: "낮", "밤", "새벽")
var time_of_day: String = "낮"
## 플레이어의 현재 위치 이름 — 씬 전환 등 위치 변경 시 update_location()으로 갱신한다
var player_location: String = ""
## 최근 발생한 게임 이벤트 목록 — add_event()로 추가하며 오래된 순으로 자동 제거된다
var recent_events: Array[String] = []

## 보관할 최대 이벤트 수
@export var max_recent_events: int = 3

## 게임 내 시간대를 갱신한다
func update_time(new_time: String) -> void:
	time_of_day = new_time

## 플레이어 위치를 갱신한다
func update_location(location_name: String) -> void:
	player_location = location_name

## 게임 이벤트를 기록한다 — 목록이 max_recent_events를 초과하면 가장 오래된 항목을 제거한다
func add_event(event_text: String) -> void:
	recent_events.push_front(event_text)
	if recent_events.size() > max_recent_events:
		recent_events.pop_back()

## 현재 인식 상태를 프롬프트 주입용 문자열로 반환한다
func build_context_line() -> String:
	var parts: Array[String] = []
	parts.append("현재 시간대: " + time_of_day)
	if player_location != "":
		parts.append("플레이어 위치: " + player_location)
	if recent_events.size() > 0:
		parts.append("진행 중인 이벤트: " + ", ".join(recent_events))
	return "현재 상황: " + ", ".join(parts)
