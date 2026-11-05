extends RefCounted

const Bindings = preload("res://scripts/bindings.gd")

const HEROES = ["windranger", "razor", "lina", "phantom_assassin", "dark_seer"]
var data: Dictionary = {}
var error = ""

func _init(path: String = "res://data/windranger.json"):
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		error = "Не удалось прочитать карточку героя."
		return
	data = parser.data
	error = validate(data)

func validate(value: Dictionary) -> String:
	if value.get("schema") != 2 or not value.get("actions") is Dictionary:
		return "Некорректный формат карточки героя."
	for field in ["hero_id", "name"]:
		if not value.get(field) is String or value[field].is_empty():
			return "Не задан герой."
	for action in value.actions:
		if not action in Bindings.ACTIONS or not value.actions[action] is Dictionary:
			return "Некорректный слот действия."
		for field in ["name", "short", "icon"]:
			if not value.actions[action].get(field) is String or value.actions[action][field].is_empty():
				return "Не заполнено описание действия."
		var image_path = str(value.actions[action].icon)
		if image_path.get_file() != image_path or not ResourceLoader.exists("res://assets/arena/" + image_path):
			return "Иконка действия не найдена."
	return ""

func action_pool(mapping: Dictionary, upgrades: Array = []) -> Dictionary:
	var result = {"abilities":[], "items":[]}
	if not error.is_empty():
		return result
	for action in data.actions:
		if action_available(action, upgrades) and int(mapping.get(action, 0)) != 0:
			if str(action).begins_with("a"):
				result.abilities.append(action)
			elif str(action).begins_with("i"):
				result.items.append(action)
	return result

func action_name(action: String) -> String:
	return str(data.actions.get(action, {}).get("name", action))

func action_available(action: String, upgrades: Array = []) -> bool:
	if not data.actions.has(action):
		return false
	var required = str(data.actions[action].get("unlock", ""))
	return required.is_empty() or required in upgrades
