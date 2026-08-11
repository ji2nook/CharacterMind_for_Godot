extends Node
class_name CharacterChat

signal response_token(text: String)
signal response_received(text: String)

@export var config: CharacterAIConfig
@export var model_node: NobodyWhoModel

var _chat: NobodyWhoChat
var _last_response := ""
var _showing_answer := false
var _answer_shown := false

func _ready():
	_chat = NobodyWhoChat.new()
	add_child(_chat)
	_chat.model_node = model_node
	_chat.system_prompt = config.system_prompt
	_chat.response_updated.connect(_on_response_updated)
	_chat.response_finished.connect(_on_response_finished)

func send_message(player_text: String):
	_last_response = ""
	_showing_answer = false
	_answer_shown = false
	_chat.say(player_text)

func _on_response_updated(token: String):
	_last_response += token

	if _showing_answer:
		if not _answer_shown and token.strip_edges() != "":
			_answer_shown = true
		if _answer_shown or token.strip_edges() != "":
			response_token.emit(token)
		return

	var close_idx := _last_response.find("</think>")
	if close_idx == -1:
		return

	_showing_answer = true
	var remainder := _last_response.substr(close_idx + "</think>".length()).lstrip("\n\r")
	if remainder != "":
		_answer_shown = true
		response_token.emit(remainder)

func _strip_thinking(text: String) -> String:
	var end_idx := text.find("</think>")
	if end_idx == -1:
		return text.strip_edges()
	return text.substr(end_idx + "</think>".length()).strip_edges()

func _on_response_finished(full_text: String):
	var processed_text := _strip_thinking(full_text)
	if not _answer_shown and processed_text != "":
		response_token.emit(processed_text)
	response_received.emit(processed_text)
