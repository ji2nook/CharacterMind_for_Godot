extends Resource
class_name CharacterActionDef

## 게임 코드에서 액션을 식별하는 ID (영문, 언더스코어만 사용)
@export var action_id: String = ""
## LLM이 이 액션을 언제 사용해야 하는지 설명 — 구체적일수록 정확도가 높아짐
@export_multiline var description: String = ""
## 액션이 받는 파라미터 이름 목록 (예: ["item", "quantity"]) — 없으면 빈 배열
@export var parameters: Array[String] = []
## false로 설정하면 이 액션이 프롬프트에서 제외되고 발동되지 않음 (조건부 잠금)
@export var enabled: bool = true
