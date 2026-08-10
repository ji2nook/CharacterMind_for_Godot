extends Node
class_name CharacterChat

signal response_token(text: String)
signal response_received(text: String)

@export var config: CharacterAIConfig
@export var model_node: NobodyWhoModel

var _chat: NobodyWhoChat
var _last_response := ""

func _ready():
	_chat = NobodyWhoChat.new()
	add_child(_chat)
	_chat.model_node = model_node
	_chat.system_prompt = config.system_prompt

	_chat.response_updated.connect(_on_response_updated)
	_chat.response_finished.connect(_on_response_finished)

func send_message(player_text: String):
	_last_response = ""
	_chat.say(player_text)

func _on_response_updated(token: String):
	_last_response += token
	response_token.emit(token)

func _on_response_finished(full_text: String):
	response_received.emit(full_text)
