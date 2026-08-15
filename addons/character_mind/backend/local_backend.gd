extends CharacterBackend
class_name LocalBackend

## NobodyWho(llama.cpp) 기반 로컬 추론 백엔드

## 추론을 실행할 NobodyWhoModel 노드
@export var model_node: NobodyWhoModel

var _chat: NobodyWhoChat

func _ready() -> void:
	_setup_chat()

func say(message: String) -> void:
	_chat.system_prompt = system_prompt
	_chat.say(message)

## 대화 기록을 초기화하고 NobodyWhoChat을 새로 생성한다
func reset() -> void:
	_setup_chat()

func _setup_chat() -> void:
	if _chat:
		_chat.response_finished.disconnect(_on_finished)
		remove_child(_chat)
		_chat.free()
	_chat = NobodyWhoChat.new()
	add_child(_chat)
	_chat.model_node = model_node
	_chat.system_prompt = system_prompt
	_chat.response_finished.connect(_on_finished)

func _on_finished(text: String) -> void:
	response_finished.emit(text)
