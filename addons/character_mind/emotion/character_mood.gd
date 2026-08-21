extends Node
class_name CharacterMood

signal mood_changed(label: String, intensity: int)

## LLM이 사용할 수 있는 감정 레이블 목록 — 이 외의 레이블은 extract_and_apply()에서 무시된다
const LABELS := ["NEUTRAL", "JOY", "ANGER", "SADNESS", "SURPRISE", "AFFECTION", "DISTRUST"]
## 현재 감정 레이블
var current_label: String = "NEUTRAL"
## 현재 감정 강도 (1=약함, 2=보통, 3=강함)
var current_intensity: int = 1
var _regex: RegEx

func _ready() -> void:
	_regex = RegEx.new()
	# 대소문자, 콜론, 공백 차이 허용
	_regex.compile("(?i)\\[MOOD:?\\s*([A-Z]+)(?:[\\s,]+([1-3]))?\\]")

## AI 응답에서 [MOOD LABEL] 또는 [MOOD LABEL #] 태그를 추출하고 현재 감정을 갱신한 뒤 태그 제거
## intensity는 선택값 — 모델이 생략하면 1로 처리
func extract_and_apply(raw_text: String) -> String:
	var result := _regex.search(raw_text)
	if result:
		var label := result.get_string(1).to_upper()
		var intensity_str := result.get_string(2)
		if label in LABELS:
			current_label = label
			current_intensity = int(intensity_str) if intensity_str != "" else 1
			mood_changed.emit(current_label, current_intensity)
		return raw_text.replace(result.get_string(0), "").strip_edges()
	return raw_text

## 현재 감정을 프롬프트 주입용 한 줄 문자열로 반환한다
func get_mood_prompt_line() -> String:
	return "현재 캐릭터의 감정: %s" % current_label
