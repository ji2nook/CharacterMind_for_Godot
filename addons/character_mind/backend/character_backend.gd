extends Node
class_name CharacterBackend

## LLM 추론 백엔드의 공통 인터페이스 — LocalBackend / CloudBackend가 이를 상속한다.

## 모델의 응답이 완전히 완료됐을 때 발생
signal response_finished(text: String)
## 재시도 불가능한 오류 발생 시 사용자에게 보여줄 메시지와 함께 발생
signal request_failed(message: String)

## 현재 적용 중인 시스템 프롬프트 — say() 호출 전에 갱신한다
var system_prompt: String = ""

## 메시지를 전송하고 응답을 요청한다
func say(_message: String) -> void:
	pass

## 대화 기록을 초기화한다 (캐릭터 전환 등)
func reset() -> void:
	pass
