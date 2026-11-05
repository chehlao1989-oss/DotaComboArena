extends Control

const Records = preload("res://scripts/record_book.gd")
const Bindings = preload("res://scripts/bindings.gd")
const Store = preload("res://scripts/profile_store.gd")
const Training = preload("res://scripts/training_model.gd")
const HotkeySlot = preload("res://scripts/hotkey_slot.gd")
const ArenaScreen = preload("res://scripts/arena_screen.gd")
const HeroCatalog = preload("res://scripts/hero_catalog.gd")
const BODY_FONT = preload("res://assets/fonts/noto-sans-regular.tres")
const MEDIUM_FONT = preload("res://assets/fonts/noto-sans-semibold.tres")
const TITLE_FONT = preload("res://assets/fonts/CormorantSC-SemiBold.ttf")
const BG = Color("12181b")
const PANEL = Color("20282b")
const GOLD = Color("c8ac76")
const GREEN = Color("a6d592")
const MUTED = Color("8d9b9c")
const WHITE = Color("dbe0dc")
const RED = Color("f19d91")
var store
var model
var page = ""
var body: VBoxContainer
var footer: HBoxContainer
var status_label: Label
var name_edit: LineEdit
var draft = {}
var capture_action = ""
var selected_action = ""
var testing = false
var slot_buttons = {}
var play_key: Label
var play_title: Label
var play_info: Label
var play_feedback: Label
var play_progress: ProgressBar
var chain_label: Label
var pause_button: Button
var pending_presses: Array = []
var pending_releases: Array = []
var last_tick = 0
var report_saved = false
var screenshot_path = ""
var selected_hero = "windranger"
var arena_options = {"seconds":180.0, "window":1.8, "seed":-1}

func _ready():
	setup_theme()
	var data_dir = "user://"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hero=") and arg.trim_prefix("--hero=") in HeroCatalog.HEROES:
			selected_hero = arg.trim_prefix("--hero=")
		if arg.begins_with("--data-dir="):
			data_dir = arg.trim_prefix("--data-dir=")
		if arg.begins_with("--capture="):
			screenshot_path = arg.trim_prefix("--capture=")
	store = Store.new(data_dir)
	var loaded = store.load_data()
	if loaded == "recovery":
		render_recovery()
	elif loaded == "error":
		render_recovery()
	else:
		go_home()
	if "--start-arena" in OS.get_cmdline_user_args() and store.current().get("setup_done", false):
		start_arena()
	elif "--show-records" in OS.get_cmdline_user_args() and store.current().get("setup_done", false):
		render_ladder()
	last_tick = Time.get_ticks_usec()
	get_window().focus_exited.connect(on_focus_lost)
	if "--smoke" in OS.get_cmdline_user_args():
		await get_tree().create_timer(1.0).timeout
		print("SMOKE_OK page=", page, " profiles=", store.data.get("profiles", []).size())
		get_tree().quit()
	if not screenshot_path.is_empty():
		await get_tree().create_timer(6.0 if page == "arena" else 1.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(screenshot_path)

func box(color: Color, border: Color = Color("3c4648"), radius: int = 2) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.shadow_color = Color(0, 0, 0, 0.18)
	s.shadow_size = 3
	s.shadow_offset = Vector2(0, 2)
	return s

func setup_theme():
	var t = Theme.new()
	t.default_font = BODY_FONT
	t.default_font_size = 17
	t.set_font("font", "Button", MEDIUM_FONT)
	t.set_font("font", "OptionButton", MEDIUM_FONT)
	t.set_color("font_color", "Label", WHITE)
	t.set_color("font_color", "Button", WHITE)
	t.set_color("font_hover_color", "Button", WHITE)
	t.set_color("font_disabled_color", "Button", Color("5e6b73"))
	t.set_stylebox("normal", "Button", box(PANEL))
	t.set_stylebox("hover", "Button", box(Color("323e40"), Color("89958e")))
	t.set_stylebox("pressed", "Button", box(Color("354136"), GREEN))
	t.set_stylebox("disabled", "Button", box(Color("141b21")))
	t.set_stylebox("normal", "LineEdit", box(Color("0c1319")))
	t.set_stylebox("focus", "LineEdit", box(Color("0c1319"), GOLD))
	t.set_color("font_color", "LineEdit", WHITE)
	t.set_color("font_placeholder_color", "LineEdit", Color("687678"))
	t.set_stylebox("normal", "OptionButton", box(Color("171e21")))
	t.set_stylebox("hover", "OptionButton", box(Color("2d383a"), GOLD))
	t.set_stylebox("panel", "PopupMenu", box(PANEL))
	t.set_color("font_color", "PopupMenu", WHITE)
	t.set_stylebox("panel", "PanelContainer", box(PANEL))
	t.set_stylebox("background", "ProgressBar", box(Color("26313b")))
	t.set_stylebox("fill", "ProgressBar", box(Color("6b9e73"), GREEN))
	t.set_constant("separation", "VBoxContainer", 16)
	t.set_constant("separation", "HBoxContainer", 12)
	t.set_constant("h_separation", "GridContainer", 8)
	t.set_constant("v_separation", "GridContainer", 8)
	theme = t

func label(text: String, size: int = 17, color: Color = WHITE) -> Label:
	var node = Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	if size >= 24 and text.length() > 3:
		node.add_theme_font_override("font", TITLE_FONT)
	return node

func paragraph(text: String, color: Color = MUTED) -> Label:
	var node = label(text, 16, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node

func button(text: String, action: Callable, accent: bool = false) -> Button:
	var b = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = 45
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(action)
	if accent:
		b.add_theme_stylebox_override("normal", box(Color("3a4937"), Color("80936c")))
	return b

func row(parent: Node) -> HBoxContainer:
	var r = HBoxContainer.new()
	parent.add_child(r)
	return r

func card(parent: Node) -> VBoxContainer:
	var panel = PanelContainer.new()
	parent.add_child(panel)
	var v = VBoxContainer.new()
	panel.add_child(v)
	return v

func shell(title_text: String, subtitle: String):
	for child in get_children():
		remove_child(child)
		child.queue_free()
	slot_buttons.clear()
	var background = ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var atmosphere = TextureRect.new()
	var gradient = Gradient.new()
	gradient.colors = PackedColorArray([Color("2a3539"), Color("131a1d"), Color("0e1417")])
	gradient.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	var texture = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.1, 0)
	texture.fill_to = Vector2(0.9, 1)
	atmosphere.texture = texture
	atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(atmosphere)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var outer = VBoxContainer.new()
	margin.add_child(outer)
	var heading = row(outer)
	var emblem = label("◈", 37, Color("b96551"))
	heading.add_child(emblem)
	var titles = VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(titles)
	titles.add_theme_constant_override("separation", 3)
	titles.add_child(label("DOTA COMBO ARENA", 25, Color("c8cfc8")))
	titles.add_child(label("Т Р Е Н И Р О В О Ч Н Ы Й   П О Л И Г О Н", 11, MUTED))
	heading.add_child(button("Выход", func(): get_tree().quit()))
	outer.add_child(HSeparator.new())
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	body.add_child(label(title_text, 31))
	body.add_child(paragraph(subtitle))
	footer = HBoxContainer.new()
	outer.add_child(footer)

func go_home():
	capture_action = ""
	testing = false
	selected_action = ""
	pending_presses.clear()
	pending_releases.clear()
	if not store.current().get("setup_done", false):
		open_settings()
	else:
		render_menu()

func profile_bar():
	var r = row(body)
	r.add_child(label("Игрок", 16, MUTED))
	var picker = OptionButton.new()
	picker.custom_minimum_size = Vector2(210, 44)
	picker.focus_mode = Control.FOCUS_NONE
	for i in store.data.profiles.size():
		var p = store.data.profiles[i]
		picker.add_item(p.name)
		if p.id == store.data.selected:
			picker.select(i)
	picker.item_selected.connect(func(i):
		store.data.selected = store.data.profiles[i].id
		if not store.save():
			set_status(store.last_error)
		go_home())
	r.add_child(picker)
	var input = LineEdit.new()
	input.placeholder_text = "Имя нового игрока"
	input.max_length = 28
	input.custom_minimum_size.x = 240
	r.add_child(input)
	r.add_child(button("+ Новый игрок", func(): create_player(input.text)))

func create_player(player_name: String):
	player_name = player_name.strip_edges()
	if player_name.is_empty():
		set_status("Введите имя нового игрока.")
		return
	for p in store.data.profiles:
		if p.name.to_lower() == player_name.to_lower():
			set_status("Такое имя уже есть. Выберите профиль или введите другое.")
			return
	if store.data.profiles.size() >= 100:
		set_status("Достигнут предел: 100 профилей.")
		return
	var before = store.data.duplicate(true)
	store.add_profile(player_name)
	if not store.save():
		store.data = before
		set_status(store.last_error)
		return
	open_settings()

func render_menu():
	page = "menu"
	shell("Готов к разминке?", "Выбери героя: случайные последовательности способностей и предметов.")
	profile_bar()
	add_arena_menu()
	var p = card(body)
	p.add_child(label("Твой профиль: " + store.current().name, 24))
	p.add_child(paragraph("Способности: " + keys_for(Bindings.ACTIONS.slice(0, 6), store.current().bindings)))
	p.add_child(paragraph("Предметы: " + keys_for(Bindings.ACTIONS.slice(6, 12), store.current().bindings) + "    •    TP: " + Bindings.key_name(int(store.current().bindings.tp))))
	var actions = row(p)
	actions.add_child(button("Проверка клавиатуры · 30 сек", start_training))
	actions.add_child(button("Настройки → Управление", open_settings))
	var hint = card(body)
	hint.add_child(label("Что проверяем", 21, GOLD))
	hint.add_child(paragraph("Нажимай показанную кнопку после сигнала. Между действиями есть короткая пауза готовности. Удержания не засчитываются повторно. Esc — пауза, Alt+Tab — автоматическая пауза."))
	var sessions = store.current().get("sessions", [])
	if not sessions.is_empty():
		var last = sessions[-1]
		hint.add_child(paragraph("Последняя проверка: %d шагов • %d чисто • %d неверных нажатий" % [last.completed, last.clean, last.wrong]))
	status_label = paragraph("Все данные хранятся локально. Каждый игрок использует свои бинды и результаты.")
	body.add_child(status_label)

func add_arena_menu():
	var hero_card = card(body)
	var top = row(hero_card)
	var portrait = TextureRect.new()
	var hero_data = HeroCatalog.new("res://data/" + selected_hero + ".json").data
	portrait.texture = load("res://assets/arena/" + str(hero_data.get("portrait", "portrait.png")))
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(150, 92)
	top.add_child(portrait)
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 5)
	top.add_child(info)
	var hero_picker = OptionButton.new()
	hero_picker.focus_mode = Control.FOCUS_NONE
	for hero in HeroCatalog.HEROES:
		var entry = HeroCatalog.new("res://data/" + hero + ".json")
		hero_picker.add_item(str(entry.data.name))
		hero_picker.set_item_metadata(hero_picker.item_count - 1, hero)
		if hero == selected_hero:
			hero_picker.select(hero_picker.item_count - 1)
	hero_picker.item_selected.connect(func(index):
		selected_hero = str(hero_picker.get_item_metadata(index))
		render_menu())
	info.add_child(hero_picker)
	info.add_child(paragraph("Нажимай подсвеченные клавиши по порядку. Примерно 80% — способности, 20% — предметы."))
	info.add_child(paragraph("Без боевых заданий. Последовательности и темп постепенно усложняются по точности."))
	var record_hint = paragraph(personal_record_hint(), GOLD)
	var options = row(hero_card)
	options.add_child(label("Время", 14, MUTED))
	var duration = OptionButton.new()
	duration.focus_mode = Control.FOCUS_NONE
	for seconds in [60, 180, 300]:
		duration.add_item(str(seconds / 60) + " мин")
		duration.set_item_metadata(duration.item_count - 1, seconds)
		if float(seconds) == float(arena_options.seconds):
			duration.select(duration.item_count - 1)
	options.add_child(duration)
	duration.item_selected.connect(func(_index):
		arena_options.seconds = float(duration.get_selected_metadata())
		record_hint.text = personal_record_hint())
	options.add_child(label("Темп", 14, MUTED))
	var pace = OptionButton.new()
	pace.focus_mode = Control.FOCUS_NONE
	var pace_names = ["Спокойный", "Обычный", "Быстрый"]
	var windows = [2.6, 1.8, 1.2]
	for i in 3:
		pace.add_item(pace_names[i])
		pace.set_item_metadata(i, windows[i])
		if is_equal_approx(float(windows[i]), float(arena_options.window)):
			pace.select(i)
	options.add_child(pace)
	pace.item_selected.connect(func(_index):
		arena_options.window = float(pace.get_selected_metadata())
		record_hint.text = personal_record_hint())
	hero_card.add_child(paragraph("От 2 до 5 клавиш. Только активные способности героя и включённые предметы. В режимах от 3 минут улучшения появляются после 60 и 120 секунд, дополнительные клавиши — по герою."))
	hero_card.add_child(record_hint)
	var actions = row(hero_card)
	actions.add_child(button("НАЧАТЬ РАЗМИНКУ", func():
		start_arena(float(duration.get_selected_metadata()), float(pace.get_selected_metadata())), true))
	actions.add_child(button("Настроить управление", open_settings))
	actions.add_child(button("РЕКОРДЫ И ЛАДДЕР", render_ladder))

func start_arena(seconds: float = 180.0, window: float = 1.8, seed_value: int = -1):
	var arena = ArenaScreen.new()
	if not arena.configure(store.current(), seconds, window, seed_value, selected_hero):
		arena.free()
		set_status("Нет доступных способностей. Проверь назначения клавиш.")
		return
	arena_options = {"seconds":seconds, "window":window, "seed":seed_value}
	page = "arena"
	for child in get_children():
		remove_child(child)
		child.queue_free()
	pending_presses.clear()
	pending_releases.clear()
	arena.finished.connect(render_arena_report)
	add_child(arena)
	arena.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func render_arena_report(result: Dictionary):
	page = "arena_report"
	result["timestamp"] = Time.get_datetime_string_from_system()
	var before = store.data.duplicate(true)
	var record_verdict = Records.apply(store.current(), result)
	store.current().sessions.append(result.duplicate(true))
	if store.current().sessions.size() > 50:
		store.current().sessions.pop_front()
	var saved = store.save()
	if not saved:
		store.data = before
	shell("Разминка завершена", str(result.get("hero_name", "Windranger")) + " · " + str(roundi(float(result.elapsed))) + " секунд активного времени. Паузы и отсчёт не учитываются.")
	var record_card = card(body)
	var hero_name = str(result.get("hero_name", "герое"))
	var score = Records.points(result)
	if saved and record_verdict.new_record:
		record_card.add_child(label(("Первый рекорд на " if record_verdict.first else "Вы побили свой рекорд на ") + hero_name + "!", 25, GOLD))
		record_card.add_child(label(str(score) + " ОЧКОВ", 32, GREEN))
		if not record_verdict.first:
			var delta = score - int(record_verdict.previous.score)
			record_card.add_child(paragraph("Предыдущий: %d · +%d очков" % [record_verdict.previous.score, delta] if delta > 0 else "При равных очках улучшены точность, серия или реакция."))
	elif record_verdict.eligible:
		record_card.add_child(label(str(score) + " ОЧКОВ", 28, GREEN))
		if saved and not record_verdict.previous.is_empty():
			record_card.add_child(paragraph("Рекорд: %d · До нового рекорда: %d очков" % [record_verdict.previous.score, maxi(0, int(record_verdict.previous.score) - score + 1)]))
		elif not saved:
			record_card.add_child(paragraph("Рекорд не сохранён: " + store.last_error, RED))
	else:
		record_card.add_child(label(str(score) + " ОЧКОВ · НЕПОЛНАЯ ПОПЫТКА", 23, GOLD))
		record_card.add_child(paragraph("Заверши разминку по таймеру, чтобы результат попал в рекорды и ладдер."))
	var summary = card(body)
	var accuracy = "—" if int(result.completed) == 0 else str(roundi(100.0 * float(result.clean) / float(result.completed))) + "%"
	summary.add_child(label("Точность " + accuracy, 32, GREEN))
	summary.add_child(label("Чистых последовательностей: %d из %d   ·   Лучшая серия: %d" % [result.successful_combos, result.combos, result.best_streak], 21))
	summary.add_child(paragraph("Шагов: %d   ·   Ошибок: %d   ·   Ранних: %d   ·   Пропусков: %d" % [result.completed, result.wrong, result.early, result.missed]))
	summary.add_child(paragraph("Темп: ×%.2f   ·   Максимум: ×%.2f   ·   Способности: %d   ·   Предметы: %d" % [result.speed, result.max_speed, result.ability_presses, result.item_presses]))
	if not result.get("upgrades", []).is_empty():
		summary.add_child(paragraph("Получены улучшения: " + ", ".join(PackedStringArray(result.upgrades))))
	if result.samples:
		summary.add_child(paragraph("Медиана реакции: %d мс" % roundi(float(result.median_ms)) + ("   ·   p90: %d мс" % roundi(float(result.p90_ms)) if result.samples >= 20 else "")))
	if result.unfinished_combo:
		summary.add_child(paragraph("Последняя последовательность не закончена и не засчитана как провал."))
	if not result.scenario_results.is_empty():
		var detail = card(body)
		detail.add_child(label("Длина последовательностей", 21, GOLD))
		for exercise in result.scenario_results.values():
			detail.add_child(paragraph("%s — %d / %d без ошибок" % [exercise.title, exercise.success, exercise.attempts]))
	if not result.mistakes.is_empty():
		var errors_card = card(body)
		errors_card.add_child(label("Что путалось", 21, GOLD))
		var ordered = result.mistakes.keys()
		ordered.sort_custom(func(a, b): return int(result.mistakes[a]) > int(result.mistakes[b]))
		for i in mini(3, ordered.size()):
			errors_card.add_child(paragraph(str(ordered[i]) + " — " + str(result.mistakes[ordered[i]]) + " раз"))
	var controls = row(footer)
	controls.add_child(button("ЕЩЁ ОДНА РАЗМИНКА", func(): start_arena(arena_options.seconds, arena_options.window, arena_options.seed), true))
	controls.add_child(button("В меню", go_home))
	controls.add_child(button("Рекорды и ладдер", render_ladder))
	controls.add_child(button("Управление", open_settings))
	status_label = paragraph("Результат сохранён в профиле «" + store.current().name + "»." if saved else "Не удалось сохранить: " + store.last_error)
	body.add_child(status_label)

func record_context(hero: String = "") -> Dictionary:
	var selected = selected_hero if hero.is_empty() else hero
	var catalog = HeroCatalog.new("res://data/" + selected + ".json")
	var items = catalog.action_pool(store.current().bindings).items.size()
	return Records.context(str(catalog.data.hero_id), float(arena_options.seconds), float(arena_options.window), items)

func pace_name(window: float) -> String:
	return "Спокойный" if window > 2.0 else ("Быстрый" if window < 1.5 else "Обычный")

func personal_record_hint() -> String:
	var ctx = record_context()
	var best = Records.best(store.current(), ctx)
	var category = "%d мин · %s · предметных слотов: %d" % [int(ctx.duration) / 60, pace_name(float(ctx.initial_window)), ctx.item_count]
	if best.is_empty():
		return category + " · Установи первый рекорд: заверши разминку!"
	return "%s · Твой рекорд: %d очков · Цель: %d" % [category, best.score, int(best.score) + 1]

func ladder_picker(parent: Node, labels: Array, values: Array, chosen: Variant, callback: Callable):
	var picker = OptionButton.new()
	picker.focus_mode = Control.FOCUS_NONE
	for i in labels.size():
		picker.add_item(str(labels[i]))
		picker.set_item_metadata(i, values[i])
		if values[i] == chosen:
			picker.select(i)
	picker.item_selected.connect(func(_index): callback.call(picker.get_selected_metadata()))
	parent.add_child(picker)

func render_ladder():
	page = "ladder"
	shell("Рекорды и ладдер", "Личный прогресс и соревнование профилей на этом компьютере.")
	var controls = row(body)
	var names: Array = []
	for hero in HeroCatalog.HEROES:
		names.append(HeroCatalog.new("res://data/" + hero + ".json").data.name)
	ladder_picker(controls, names, HeroCatalog.HEROES, selected_hero, func(hero):
		selected_hero = str(hero)
		render_ladder())
	ladder_picker(controls, ["1 мин","3 мин","5 мин"], [60.0,180.0,300.0], arena_options.seconds, func(seconds):
		arena_options.seconds = float(seconds)
		render_ladder())
	ladder_picker(controls, ["Спокойный","Обычный","Быстрый"], [2.6,1.8,1.2], arena_options.window, func(window):
		arena_options.window = float(window)
		render_ladder())
	var ctx = record_context()
	body.add_child(paragraph("Сравниваются одинаковые герой, длительность, начальный темп и число включённых предметных слотов (%d)." % ctx.item_count))
	var mine = card(body)
	mine.add_child(label("Твои рекорды · " + str(store.current().name), 23, GOLD))
	var personal = GridContainer.new()
	personal.columns = 4
	personal.add_theme_constant_override("h_separation", 28)
	mine.add_child(personal)
	for heading in ["Герой","Очки","Точность","Дата"]:
		personal.add_child(label(heading,13,MUTED))
	for hero in HeroCatalog.HEROES:
		var hero_data = HeroCatalog.new("res://data/" + hero + ".json").data
		var best = Records.best(store.current(), record_context(hero))
		personal.add_child(label(str(hero_data.name),17, GREEN if hero == selected_hero else WHITE))
		personal.add_child(label("—" if best.is_empty() else str(int(best.score)),17,GREEN))
		personal.add_child(label("—" if best.is_empty() else "%d%%" % roundi(float(best.accuracy)),17))
		personal.add_child(label("—" if best.is_empty() else str(best.timestamp).left(10),15,MUTED))
	var top = card(body)
	var chosen_name = HeroCatalog.new("res://data/" + selected_hero + ".json").data.name
	top.add_child(label("Локальный ладдер · " + str(chosen_name),23,GOLD))
	var ranking = Records.ranking(store.data.profiles, ctx)
	if ranking.is_empty():
		top.add_child(paragraph("Пока нет рекордов в этой категории. Заверши первую разминку и открой таблицу!"))
	else:
		var table = GridContainer.new()
		table.columns = 5
		table.add_theme_constant_override("h_separation",28)
		top.add_child(table)
		for heading in ["Место","Игрок","Очки","Точность","Серия"]:
			table.add_child(label(heading,13,MUTED))
		var my_place = 0
		for i in ranking.size():
			var entry = ranking[i]
			if entry.id == store.current().id:
				my_place = i + 1
			if i >= 10:
				continue
			var color = GOLD if entry.id == store.current().id else WHITE
			for value in [str(i+1),str(entry.name),str(int(entry.record.score)),"%d%%" % roundi(float(entry.record.accuracy)),str(int(entry.record.best_streak))]:
				table.add_child(label(value,17,color))
		if my_place > 0:
			top.add_child(paragraph("Твоё место: %d из %d" % [my_place,ranking.size()],GREEN))
	body.add_child(paragraph("За чистое нажатие +100 очков. Ошибка −25, раннее нажатие −15, пропуск −50. При равных очках выше точность, затем серия и реакция. В рекорды входят только полные разминки."))
	var actions = row(footer)
	actions.add_child(button("ПОБИТЬ РЕКОРД",func(): start_arena(arena_options.seconds,arena_options.window),true))
	actions.add_child(button("В меню",go_home))

func keys_for(actions: Array, mapping: Dictionary) -> String:
	var names: PackedStringArray = []
	for a in actions:
		names.append(Bindings.key_name(int(mapping.get(a, 0))))
	return "  ·  ".join(names)

func open_settings():
	draft = store.current().bindings.duplicate(true)
	name_edit = null
	capture_action = ""
	selected_action = ""
	testing = false
	render_settings()

func render_settings():
	page = "settings"
	var old_name = store.current().name
	if is_instance_valid(name_edit) and name_edit.is_inside_tree():
		old_name = name_edit.text
	shell("Управление", "Настрой привычные клавиши. Выбери слот и нажми нужную кнопку.")
	profile_bar()
	name_edit = LineEdit.new()
	name_edit.text = old_name
	name_edit.max_length = 28
	name_edit.custom_minimum_size = Vector2(180, 42)
	var preset_row = row(body)
	preset_row.add_child(button("Стандарт Dota 2", func(): apply_preset(false)))
	preset_row.add_child(button("Бинды автора", func(): apply_preset(true)))
	preset_row.add_child(button("Проверить клавиши" if not testing else "Закончить проверку", toggle_testing))
	var preset_spacer = Control.new()
	preset_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_row.add_child(preset_spacer)
	preset_row.add_child(label("Имя профиля", 13, MUTED))
	preset_row.add_child(name_edit)
	var settings = card(body)
	var settings_heading = row(settings)
	settings_heading.add_child(label("С П О С О Б Н О С Т И   И   П Р Е Д М Е Т Ы", 14, WHITE))
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_heading.add_child(spacer)
	settings_heading.add_child(label("ОБЩИЕ НАЗНАЧЕНИЯ", 12, MUTED))
	settings.add_child(HSeparator.new())
	var layout = row(settings)
	var badge = PanelContainer.new()
	badge.custom_minimum_size = Vector2(78, 190)
	badge.add_theme_stylebox_override("panel", box(Color("141b1e"), Color("495051")))
	layout.add_child(badge)
	var badge_text = label("◈\n\nГЕРОЙ", 15, GOLD)
	badge_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(badge_text)
	var ability_column = VBoxContainer.new()
	ability_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(ability_column)
	ability_column.add_child(label("С П О С О Б Н О С Т И", 12, MUTED))
	var ability_row = row(ability_column)
	for i in 6:
		add_slot(ability_row, Bindings.ACTIONS[i], "СЛОТ " + str(i + 1) if i < 5 else "УЛЬТИМЕЙТ", Vector2(86, 124))
	ability_column.add_child(label("Основные и дополнительные слоты героя", 12, MUTED))
	var item_column = VBoxContainer.new()
	layout.add_child(item_column)
	item_column.add_child(label("П Р Е Д М Е Т Ы", 12, MUTED))
	var grid = GridContainer.new()
	grid.columns = 3
	item_column.add_child(grid)
	for i in 6:
		add_slot(grid, "i" + str(i + 1), "СЛОТ " + str(i + 1), Vector2(86, 78))
	var tp_column = VBoxContainer.new()
	layout.add_child(tp_column)
	tp_column.add_child(label("TP", 12, MUTED))
	add_slot(tp_column, "tp", "ТЕЛЕПОРТ", Vector2(90, 124))
	var edit_row = row(settings)
	edit_row.add_child(button("Очистить слот", clear_selected))
	edit_row.add_child(button("Вкл / выкл предмет", toggle_item))
	edit_row.add_child(label("Esc — отменить назначение", 13, MUTED))
	status_label = paragraph("Неназначенные предметы не участвуют в тренировке.")
	settings.add_child(status_label)
	var bottom = footer
	bottom.add_child(button("СОХРАНИТЬ И ПРОДОЛЖИТЬ", save_settings, true))
	bottom.add_child(button("Отменить изменения", cancel_settings))
	refresh_slots()

func add_slot(parent: Node, action: String, caption: String, minimum: Vector2):
	var b = HotkeySlot.new()
	b.pressed.connect(func():
		selected_action = action
		capture_action = action
		testing = false
		set_status("Нажмите клавишу: " + Bindings.title(action) + ". Esc — отмена.", true)
		refresh_slots())
	b.custom_minimum_size = minimum
	parent.add_child(b)
	b.set_meta("caption", caption)
	slot_buttons[action] = b

func refresh_slots(highlight: String = ""):
	for action in slot_buttons:
		var b = slot_buttons[action]
		b.show_binding(Bindings.key_name(int(draft.get(action, 0))), b.get_meta("caption"), action == selected_action, action == capture_action, action == highlight, int(draft.get(action, 0)) == 0)

func set_status(text: String, good: bool = false):
	if is_instance_valid(status_label):
		status_label.text = text
		status_label.add_theme_color_override("font_color", GREEN if good else RED)

func apply_preset(author: bool):
	capture_action = ""
	draft = Bindings.preset(author)
	refresh_slots()
	set_status("Пресет применён к черновику. Сохрани, чтобы использовать его в тренировке.", true)

func clear_selected():
	if selected_action.is_empty():
		set_status("Сначала выбери слот.")
		return
	capture_action = ""
	draft[selected_action] = 0
	refresh_slots()
	set_status("Назначение очищено. Перед сохранением назначь обязательные способности и TP.")

func toggle_item():
	if not selected_action.begins_with("i"):
		set_status("Выбери один из шести предметных слотов.")
		return
	capture_action = ""
	draft[selected_action] = 0 if int(draft[selected_action]) else Bindings.preset()[selected_action]
	refresh_slots()
	set_status("Предметный слот изменён. При необходимости назначь другую клавишу.", true)

func toggle_testing():
	testing = not testing
	capture_action = ""
	render_settings()
	set_status("Нажимай клавиши: соответствующий слот загорится. Esc завершит проверку." if testing else "Проверка завершена.", true)

func cancel_settings():
	capture_action = ""
	testing = false
	if store.current().setup_done:
		render_menu()
	else:
		draft = store.current().bindings.duplicate(true)
		render_settings()
		set_status("Изменения отменены. Перед первой тренировкой нужно подтвердить управление.", true)

func save_settings():
	capture_action = ""
	var problems = Bindings.errors(draft)
	if not problems.is_empty():
		set_status("Не сохранено: " + problems[0])
		refresh_slots()
		return
	var new_name = name_edit.text.strip_edges()
	if new_name.is_empty():
		set_status("Введите имя игрока.")
		return
	for p in store.data.profiles:
		if p.id != store.data.selected and p.name.to_lower() == new_name.to_lower():
			set_status("Имя уже занято другим игроком.")
			return
	var before = store.data.duplicate(true)
	var current = store.current()
	current.name = new_name
	current.bindings = draft.duplicate(true)
	current.setup_done = true
	if not store.save():
		store.data = before
		set_status(store.last_error)
		return
	testing = false
	render_menu()

func start_training():
	var map = store.current().bindings
	var actions: Array = ["a1", "a2", "a3", "a6", "a4", "a5", "a1", "tp"]
	for a in Bindings.ACTIONS.slice(6, 12):
		if int(map[a]) != 0:
			actions.append(a)
	model = Training.new()
	model.start(actions)
	report_saved = false
	page = "play"
	shell("Проверка последовательности", "Это проверка клавиатуры: слоты здесь условные, без механик конкретного героя. Нажимай после сигнала, не удерживай кнопку.")
	var top = row(body)
	play_info = label("", 18, MUTED)
	play_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(play_info)
	pause_button = button("Пауза · Esc", toggle_pause)
	top.add_child(pause_button)
	top.add_child(button("Завершить", finish_training))
	var stage = card(body)
	play_title = label("", 22, MUTED)
	play_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage.add_child(play_title)
	play_key = label("", 82, GOLD)
	play_key.custom_minimum_size.y = 140
	play_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage.add_child(play_key)
	play_progress = ProgressBar.new()
	play_progress.custom_minimum_size.y = 12
	play_progress.show_percentage = false
	stage.add_child(play_progress)
	chain_label = label("", 17, MUTED)
	chain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage.add_child(chain_label)
	play_feedback = label("", 18, GREEN)
	play_feedback.custom_minimum_size.y = 32
	play_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage.add_child(play_feedback)
	body.add_child(paragraph("Esc — пауза / продолжение. При потере фокуса таймер остановится. Space используется только как назначенная боевая клавиша."))
	pending_presses.clear()
	pending_releases.clear()
	last_tick = Time.get_ticks_usec()
	update_play()

func toggle_pause():
	pending_presses.clear()
	pending_releases.clear()
	if model.phase == "paused":
		model.resume()
	else:
		model.pause()
	last_tick = Time.get_ticks_usec()
	update_play()

func on_focus_lost():
	if page == "play":
		model.pause()
		pending_presses.clear()
		pending_releases.clear()
		update_play()
	elif page == "settings" and not capture_action.is_empty():
		capture_action = ""
		refresh_slots()
		set_status("Назначение отменено при потере фокуса.")

func finish_training():
	model.phase = "finished"
	render_report()

func update_play():
	var mapping = store.current().bindings
	var accuracy = "—" if model.completed == 0 else str(roundi(100.0 * model.clean / model.completed)) + "%"
	play_info.text = "%s  •  осталось %d сек  •  чистая точность %s" % [store.current().name, ceili(model.duration - model.elapsed), accuracy]
	pause_button.text = "Продолжить · Esc" if model.phase == "paused" else "Пауза · Esc"
	play_key.add_theme_color_override("font_color", GOLD)
	if model.phase == "countdown":
		play_title.text = "Приготовься"
		play_key.text = str(maxi(1, ceili(model.countdown_left)))
	elif model.phase == "paused":
		play_title.text = "Таймер остановлен"
		play_key.text = "ПАУЗА"
	elif model.phase == "gate":
		play_title.text = "Подготовка следующего действия"
		play_key.text = "· · ·"
	else:
		play_title.text = Bindings.title(model.expected()) + " — нажми сейчас"
		play_key.text = Bindings.key_name(int(mapping[model.expected()]))
		play_key.add_theme_color_override("font_color", GREEN)
	play_progress.value = clampf(model.window_left / 1.8 * 100.0, 0, 100) if model.phase == "active" else 0
	var upcoming: PackedStringArray = []
	for i in 5:
		var a = model.steps[(model.step_index + i) % model.steps.size()]
		upcoming.append(Bindings.key_name(int(mapping[a])))
	chain_label.text = "Далее:  " + "  →  ".join(upcoming)
	play_feedback.text = model.message
	play_feedback.add_theme_color_override("font_color", GREEN if model.message_good else RED)

func render_report():
	page = "report"
	var result = model.report()
	if not report_saved:
		result["timestamp"] = Time.get_datetime_string_from_system()
		store.current().sessions.append(result.duplicate(true))
		if store.current().sessions.size() > 50:
			store.current().sessions.pop_front()
		report_saved = store.save()
	shell("Проверка завершена", "Результат относится к техническому упражнению. Скорость фиксированная; обучение героям и адаптация появятся в следующих этапах.")
	var p = card(body)
	var accuracy = "—" if result.completed == 0 else str(roundi(100.0 * result.clean / result.completed)) + "%"
	p.add_child(label("Чистая точность: " + accuracy, 30, GREEN))
	p.add_child(label("Завершено шагов: %d   •   Чисто: %d" % [result.completed, result.clean], 21))
	p.add_child(paragraph("Неверных нажатий: %d    Ранних: %d    Пропущено: %d    Одновременных: %d" % [result.wrong, result.early, result.missed, result.ambiguous]))
	p.add_child(paragraph("Медиана реакции: %d мс (%d чистых ответов)" % [roundi(result.median_ms), result.samples] if result.samples else "Медиана реакции: недостаточно данных"))
	p.add_child(paragraph("Текущий незавершённый шаг не включён в точность. Время паузы и отсчёта не включено во время упражнения."))
	var r = row(body)
	r.add_child(button("Повторить проверку", start_training, true))
	r.add_child(button("В меню", go_home))
	r.add_child(button("Изменить бинды", open_settings))
	status_label = paragraph("Результат сохранён в профиле «" + store.current().name + "»." if report_saved else "Не удалось сохранить: " + store.last_error)
	body.add_child(status_label)

func render_recovery():
	page = "recovery"
	shell("Восстановление настроек", "Файл профилей не удалось прочитать. Повреждённый исходник будет сохранён отдельно; автоматического сброса нет.")
	body.add_child(paragraph("Каталог данных: " + ProjectSettings.globalize_path(store.directory)))
	var buttons = row(body)
	var restore = button("Восстановить резервную копию", func(): recover_data(true), true)
	restore.disabled = not store.valid(store.read_file(store.file_path(".bak")))
	buttons.add_child(restore)
	buttons.add_child(button("Создать новый профиль", func(): recover_data(false)))
	status_label = paragraph(store.last_error if not store.last_error.is_empty() else "Выбери способ восстановления или закрой приложение.")
	body.add_child(status_label)

func recover_data(backup: bool):
	if store.recover(backup):
		go_home()
	else:
		set_status(store.last_error)

func _input(event: InputEvent):
	if not event is InputEventKey:
		return
	var code = int(event.physical_keycode if event.physical_keycode else event.keycode)
	if page == "play":
		get_viewport().set_input_as_handled()
		if not event.pressed:
			pending_releases.append(code)
		elif not event.echo:
			if code == KEY_ESCAPE:
				toggle_pause()
			elif code not in Bindings.RESERVED and not event.alt_pressed and not event.ctrl_pressed and not event.meta_pressed:
				pending_presses.append(code)
		return
	if page != "settings" or event.echo or not event.pressed:
		return
	if not capture_action.is_empty():
		get_viewport().set_input_as_handled()
		if code == KEY_ESCAPE:
			capture_action = ""
			set_status("Назначение отменено.", true)
		elif code in Bindings.RESERVED or event.alt_pressed or event.ctrl_pressed or event.meta_pressed or event.shift_pressed:
			set_status("Выбери одиночную клавишу без модификаторов. Esc — отмена.")
		else:
			draft[capture_action] = code
			capture_action = ""
			var conflicts = Bindings.errors(draft)
			set_status("Назначение изменено. Сохрани управление." if conflicts.is_empty() else conflicts[0], conflicts.is_empty())
		refresh_slots()
	elif testing:
		get_viewport().set_input_as_handled()
		if code == KEY_ESCAPE:
			testing = false
			render_settings()
		else:
			var action = Bindings.action_for(code, draft)
			refresh_slots(action)
			set_status(Bindings.key_name(code) + " — " + (Bindings.title(action) if not action.is_empty() else "не назначена"), not action.is_empty())

func _process(_delta: float):
	var now = Time.get_ticks_usec()
	var dt = maxf(0, float(now - last_tick) / 1000000.0)
	last_tick = now
	if page != "play":
		return
	model.advance(dt)
	if not pending_presses.is_empty():
		model.press_batch(pending_presses, store.current().bindings)
	for code in pending_releases:
		model.release(code)
	pending_presses.clear()
	pending_releases.clear()
	if model.phase == "finished":
		render_report()
	else:
		update_play()
