extends Node

@onready var npc_chat = $NPCChat
@onready var input_box = $InputBox
@onready var response_label = $ResponseLabel
@onready var send_button = $SendButton

func _ready():
	send_button.pressed.connect(_on_send_pressed)
	npc_chat.response_token.connect(_on_response_token)
	npc_chat.response_received.connect(_on_response_received)

func _on_send_pressed():
	response_label.text = "생각 중..."
	npc_chat.send_message(input_box.text)

func _on_response_token(token: String):
	if response_label.text == "생각 중...":
		response_label.text = ""
	response_label.text += token

func _on_response_received(_text: String):
	pass
