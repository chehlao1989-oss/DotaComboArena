extends RefCounted

const Bindings = preload("res://scripts/bindings.gd")
const Records = preload("res://scripts/record_book.gd")
var directory: String
var data: Dictionary = {}
var recovery_needed = false
var last_error = ""

func _init(base: String = "user://"):
	directory = base
	DirAccess.make_dir_recursive_absolute(directory)

func file_path(suffix: String = "") -> String:
	return directory.path_join("profiles.json" + suffix)

func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("schema", 0) != 1:
		return false
	if not value.get("profiles") is Array or value.profiles.is_empty() or value.profiles.size() > 100:
		return false
	var ids = {}
	for profile in value.profiles:
		if not profile is Dictionary:
			return false
		if not profile.get("id") is String or profile.id.is_empty() or ids.has(profile.id):
			return false
		ids[profile.id] = true
		if not profile.get("name") is String or profile.name.strip_edges().is_empty():
			return false
		if not profile.get("setup_done") is bool or not profile.get("bindings") is Dictionary:
			return false
		if not profile.get("sessions") is Array or profile.sessions.size() > 50:
			return false
		if profile.has("records") and not Records.valid_book(profile.records):
			return false
		for session in profile.sessions:
			if not session is Dictionary:
				return false
			for field in ["completed", "clean", "wrong", "early", "missed", "ambiguous", "elapsed", "median_ms", "samples"]:
				if not (session.get(field) is int or session.get(field) is float):
					return false
		for action in Bindings.ACTIONS:
			var key = profile.bindings.get(action)
			if not (key is float or key is int) or float(key) != floor(float(key)):
				return false
		if profile.setup_done and not Bindings.errors(profile.bindings).is_empty():
			return false
	return value.get("selected", "") in ids

func read_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var parser = JSON.new()
	return parser.data if parser.parse(f.get_as_text()) == OK else null

func load_data() -> String:
	if not FileAccess.file_exists(file_path()):
		data = {"schema": 1, "selected": "", "profiles": []}
		add_profile("Игрок 1")
		return "new" if save() else "error"
	var value = read_file(file_path())
	if valid(value):
		data = value
		return "ok"
	recovery_needed = true
	return "recovery"

func add_profile(name: String) -> Dictionary:
	var id = str(Time.get_unix_time_from_system()) + "-" + str(randi())
	var profile = {"id": id, "name": name.strip_edges().left(28), "setup_done": false, "bindings": Bindings.preset(), "sessions": []}
	data.profiles.append(profile)
	data.selected = id
	return profile

func current() -> Dictionary:
	for p in data.get("profiles", []):
		if p.id == data.get("selected"):
			return p
	return {}

func save() -> bool:
	last_error = ""
	if recovery_needed:
		last_error = "Сначала выберите восстановление данных."
		return false
	if not valid(data):
		last_error = "Профиль не прошёл проверку формата."
		return false
	var temp = file_path(".tmp")
	var f = FileAccess.open(temp, FileAccess.WRITE)
	if f == null:
		last_error = "Не удалось записать настройки: " + error_string(FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.flush()
	var write_error = f.get_error()
	f.close()
	if write_error != OK or not valid(read_file(temp)):
		last_error = "Не удалось проверить записанные настройки."
		return false
	if FileAccess.file_exists(file_path()) and valid(read_file(file_path())):
		if DirAccess.copy_absolute(file_path(), file_path(".bak")) != OK:
			last_error = "Не удалось создать резервную копию."
			return false
	var result = DirAccess.rename_absolute(temp, file_path())
	if result != OK:
		last_error = "Не удалось заменить файл настроек: " + error_string(result)
		return false
	return true

func recover(use_backup: bool) -> bool:
	var backup = read_file(file_path(".bak")) if use_backup else null
	if use_backup and not valid(backup):
		last_error = "Резервная копия отсутствует или повреждена."
		return false
	var archive = file_path(".damaged-" + str(Time.get_ticks_usec()))
	if FileAccess.file_exists(file_path()) and DirAccess.copy_absolute(file_path(), archive) != OK:
		last_error = "Не удалось сохранить повреждённый исходник."
		return false
	data = backup if use_backup else {"schema": 1, "selected": "", "profiles": []}
	if not use_backup:
		add_profile("Игрок 1")
	recovery_needed = false
	if not save():
		recovery_needed = true
		return false
	return true
