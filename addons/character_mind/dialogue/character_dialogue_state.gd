extends Node
class_name CharacterDialogueState

enum State { IDLE, LISTENING, THINKING, SPEAKING, ENDED }

## 현재 대화 상태 — CharacterChat이 턴마다 갱신한다
var current_state: State = State.IDLE

## 상태가 바뀔 때 새 상태와 함께 발생
signal state_changed(new_state: State)

## 플레이어 입력을 받아 처리 중 상태로 전환한다
func start_turn() -> void:
	current_state = State.THINKING
	state_changed.emit(current_state)

## NPC 응답이 완료돼 다음 입력을 기다리는 상태로 전환한다
func finish_turn() -> void:
	current_state = State.LISTENING
	state_changed.emit(current_state)

## 진행 중인 턴을 취소하고 입력 대기 상태로 복귀한다
func interrupt() -> void:
	if current_state == State.SPEAKING or current_state == State.THINKING:
		current_state = State.LISTENING
		state_changed.emit(current_state)

## 대화를 종료 상태로 전환한다
func end_conversation() -> void:
	current_state = State.ENDED
	state_changed.emit(current_state)

## NPC가 응답을 처리 중이면 true를 반환한다 — send_message() 중복 호출 방지에 사용한다
func is_busy() -> bool:
	return current_state == State.THINKING or current_state == State.SPEAKING
