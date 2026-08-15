extends Node
class_name CharacterMood

signal mood_changed(label: String, intensity: int)

const LABELS := ["NEUTRAL", "JOY", "ANGER", "SADNESS", "SURPRISE", "AFFECTION", "DISTRUST"]
var current_label: String = "NEUTRAL"
var current_intensity: int = 1  # 1=약함, 2=보통, 3=강함

## AI 응답에서 [MOOD LABEL] 또는 [MOOD LABEL #] 태그를 추출하고 현재 감정을 갱신한 뒤 태그 제거
## intensity는 선택값 — 모델이 생략하면 1로 처리
func extract_and_apply(raw_text: String) -> String:
	var regex := RegEx.new()
	# 대소문자, 콜론, 공백 차이 허용
	regex.compile("(?i)\\[MOOD:?\\s*([A-Z]+)(?:[\\s,]+([1-3]))?\\]")
	var result := regex.search(raw_text)
	if result:
		var label := result.get_string(1).to_upper()
		var intensity_str := result.get_string(2)
		if label in LABELS:
			current_label = label
			current_intensity = int(intensity_str) if intensity_str != "" else 1
			mood_changed.emit(current_label, current_intensity)
		return raw_text.replace(result.get_string(0), "").strip_edges()
	return raw_text

func get_mood_prompt_line() -> String:
	return "현재 캐릭터의 감정: %s" % current_label
