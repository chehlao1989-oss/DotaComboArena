extends RefCounted

const ACTIONS = ["a1", "a2", "a3", "a4", "a5", "a6", "i1", "i2", "i3", "i4", "i5", "i6", "tp"]
const LABELS = ["Способность 1", "Способность 2", "Способность 3", "Способность 4", "Способность 5", "Ультимейт", "Предмет 1", "Предмет 2", "Предмет 3", "Предмет 4", "Предмет 5", "Предмет 6", "Телепорт"]
const STANDARD = [KEY_Q, KEY_W, KEY_E, KEY_D, KEY_F, KEY_R, KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B, KEY_N, KEY_T]
const AUTHOR = [KEY_Q, KEY_W, KEY_E, KEY_D, KEY_F, KEY_R, KEY_1, 0, KEY_CAPSLOCK, KEY_SPACE, 0, KEY_2, KEY_T]
const RESERVED = [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_TAB, KEY_ALT, KEY_CTRL, KEY_SHIFT, KEY_META, KEY_F4, KEY_PRINT, KEY_PAUSE]

static func preset(author: bool = false) -> Dictionary:
	var result = {}
	for i in ACTIONS.size():
		result[ACTIONS[i]] = int(AUTHOR[i] if author else STANDARD[i])
	return result

static func title(action: String) -> String:
	var i = ACTIONS.find(action)
	return LABELS[i] if i >= 0 else action

static func key_name(code: int) -> String:
	if code == 0:
		return "—"
	if code == KEY_CAPSLOCK:
		return "Caps Lock"
	if code == KEY_SPACE:
		return "Space"
	return OS.get_keycode_string(code)

static func action_for(code: int, map: Dictionary) -> String:
	for action in ACTIONS:
		if int(map.get(action, 0)) == code and code != 0:
			return action
	return ""

static func errors(map: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var seen = {}
	for action in ACTIONS:
		var code = int(map.get(action, 0))
		if code == 0:
			if action.begins_with("a") or action == "tp":
				result.append("Назначьте: " + title(action))
			continue
		if code < 0 or code > KEY_UNKNOWN or code in RESERVED:
			result.append("Недоступная клавиша: " + key_name(code))
		if seen.has(code):
			result.append("%s: %s и %s" % [key_name(code), title(seen[code]), title(action)])
		seen[code] = action
	return result
