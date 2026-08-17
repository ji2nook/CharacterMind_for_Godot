extends Node
class_name CharacterPerception

var time_of_day: String = "낮"
var player_location: String = ""
var recent_events: Array[String] = []

@export var max_recent_events: int = 3

func update_time(new_time: String) -> void:
	time_of_day = new_time

func update_location(location_name: String) -> void:
	player_location = location_name

func add_event(event_text: String) -> void:
	recent_events.push_front(event_text)
	if recent_events.size() > max_recent_events:
		recent_events.pop_back()

func build_context_line() -> String:
	var parts: Array[String] = []
	parts.append("현재 시간대: " + time_of_day)
	if player_location != "":
		parts.append("플레이어 위치: " + player_location)
	if recent_events.size() > 0:
		parts.append("진행 중인 이벤트: " + ", ".join(recent_events))
	return "현재 상황: " + ", ".join(parts)
