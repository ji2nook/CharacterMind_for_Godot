extends Node
class_name CharacterDialogueState

enum State { IDLE, LISTENING, THINKING, SPEAKING, ENDED }

var current_state: State = State.IDLE

signal state_changed(new_state: State)

func start_turn() -> void:
	current_state = State.THINKING
	state_changed.emit(current_state)

func finish_turn() -> void:
	current_state = State.LISTENING
	state_changed.emit(current_state)

func interrupt() -> void:
	if current_state == State.SPEAKING or current_state == State.THINKING:
		current_state = State.LISTENING
		state_changed.emit(current_state)

func end_conversation() -> void:
	current_state = State.ENDED
	state_changed.emit(current_state)

func is_busy() -> bool:
	return current_state == State.THINKING or current_state == State.SPEAKING
