extends Control

signal finished(report: Dictionary)
const Records = preload("res://scripts/record_book.gd")
const Catalog = preload("res://scripts/hero_catalog.gd")
const Session = preload("res://scripts/arena_session.gd")
const World = preload("res://scripts/arena_world.gd")
const ArenaAudio = preload("res://scripts/arena_audio.gd")
const Bindings = preload("res://scripts/bindings.gd")
const FONT = preload("res://assets/fonts/noto-sans-regular.tres")
const BOLD = preload("res://assets/fonts/noto-sans-semibold.tres")
const TITLE = preload("res://assets/fonts/CormorantSC-SemiBold.ttf")
const PORTRAIT = preload("res://assets/arena/portrait.png")
var catalog
var session
var world
var audio
var player_name = ""
var personal_best: Dictionary = {}
var status_points: Label
var status_record: Label
var status_goal: Label
var status_time: Label
var status_score: Label
var status_streak: Label
var current_key: Label
var current_title: Label
var current_hint: Label
var feedback: Label
var scenario_title: Label
var scenario_tag: Label
var step_list: VBoxContainer
var pause_button: Button
var progress: ProgressBar
var step_nodes: Array = []
var hud_frames = {}
var hud_key_labels = {}
var held_events: Array = []
var release_events: Array = []
var physical_keys = {}
var ambiguous_input = false
var last_tick = 0
var displayed_scenario = ""
var displayed_phase = ""
var displayed_step = -1
var result_sent = false
var upgrade_label: Label
var shown_upgrades = ""

func configure(profile: Dictionary, seconds: float, response: float, seed_value: int = -1, hero: String = "windranger") -> bool:
	catalog = Catalog.new("res://data/" + hero + ".json")
	session = Session.new()
	player_name = profile.name
	var ready = session.start(catalog, profile.bindings, seconds, response, seed_value)
	if ready:
		personal_best = Records.best(profile, Records.context(str(catalog.data.hero_id), seconds, response, session.initial_item_count))
	return ready

func style(fill: Color, border: Color = Color("414a47")) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(1)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s

func text(value: String, size: int = 16, color: Color = Color("dce2d9"), title: bool = false) -> Label:
	var l = Label.new()
	l.text = value
	l.add_theme_font_override("font", TITLE if title else FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func wrapped(value: String, size: int = 14) -> Label:
	var l = text(value, size, Color("a4b0a7"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

# Reserve text space independently of the current message. Labels otherwise
# propagate a new minimum size up through the arena's HBox/VBox containers.
func rail_text(parent: Node, height: float, font_size: int, color: Color, lines: int = 1) -> Label:
	var slot = Control.new()
	slot.custom_minimum_size.y = height
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(slot)
	var label = text("", font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = lines
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	slot.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return label

func row(parent: Node, gap: int = 10) -> HBoxContainer:
	var r = HBoxContainer.new()
	r.add_theme_constant_override("separation", gap)
	parent.add_child(r)
	return r

func panel(parent: Node, fill: Color = Color("1b2324")) -> VBoxContainer:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(fill))
	parent.add_child(p)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	return v

func btn(value: String, callback: Callable) -> Button:
	var b = Button.new()
	b.text = value
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(callback)
	b.custom_minimum_size.y = 38
	return b

func icon(action: String) -> Texture2D:
	var info = catalog.data.actions.get(action, catalog.data.get("passive_slots", {}).get(action, {}))
	return null if info.is_empty() else load("res://assets/arena/" + str(info.icon))

func _ready():
	build()
	audio = ArenaAudio.new(self)
	get_window().focus_exited.connect(focus_lost)
	last_tick = Time.get_ticks_usec()
	update_interface()

func build():
	var bg = ColorRect.new()
	bg.color = Color("101617")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var outer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	margin.add_child(outer)
	var header = row(outer, 18)
	var titles = VBoxContainer.new()
	titles.add_theme_constant_override("separation", 2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titles.add_child(text("АРЕНА КОМБО", 23, Color("d7c59e"), true))
	titles.add_child(text(str(catalog.data.name).to_upper() + "   /   " + player_name, 12, Color("94a394")))
	status_time = text("03:00", 27, Color("e6deca"))
	header.add_child(status_time)
	status_score = text("Точность —", 16, Color("a7b8a4"))
	header.add_child(status_score)
	var sound = CheckButton.new()
	sound.text = "Звук"
	sound.button_pressed = true
	sound.focus_mode = Control.FOCUS_NONE
	sound.toggled.connect(func(on):
		if audio != null:
			audio.enabled = on)
	header.add_child(sound)
	var fx_button = CheckButton.new()
	fx_button.text = "Эффекты"
	fx_button.button_pressed = true
	fx_button.focus_mode = Control.FOCUS_NONE
	fx_button.toggled.connect(func(on): world.particles_enabled = on)
	header.add_child(fx_button)
	pause_button = btn("Пауза · Esc", toggle_pause)
	header.add_child(pause_button)
	header.add_child(btn("Завершить", stop))
	var middle = row(outer, 10)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scene_column = VBoxContainer.new()
	scene_column.add_theme_constant_override("separation", 0)
	scene_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(scene_column)
	world = World.new()
	world.configure(catalog.data)
	world.size_flags_vertical = Control.SIZE_EXPAND_FILL
	world.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scene_column.add_child(world)
	var prompt = panel(scene_column, Color("192321"))
	var prompt_row = row(prompt, 16)
	current_key = text("3", 39, Color("b6d59a"))
	current_key.add_theme_font_override("font", BOLD)
	# Reserve the largest line height so switching to long key names cannot resize the arena.
	current_key.custom_minimum_size = Vector2(88, maxf(52, ceilf(BOLD.get_height(39))))
	current_key.clip_text = true
	current_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	current_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_row.add_child(current_key)
	var prompt_titles = VBoxContainer.new()
	prompt_titles.add_theme_constant_override("separation", 0)
	prompt_titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_row.add_child(prompt_titles)
	current_title = text("Приготовься", 20)
	current_title.clip_text = true
	prompt_titles.add_child(current_title)
	current_hint = text("", 13, Color("9fab9b"))
	current_hint.clip_text = true
	prompt_titles.add_child(current_hint)
	progress = ProgressBar.new()
	progress.show_percentage = false
	progress.custom_minimum_size.y = 5
	var background = style(Color("151b19"), Color("151b19"))
	background.set_content_margin_all(0)
	progress.add_theme_stylebox_override("background", background)
	var fill = style(Color("91b76e"), Color("91b76e"))
	fill.content_margin_top = 0
	fill.content_margin_bottom = 0
	progress.add_theme_stylebox_override("fill", fill)
	prompt.add_child(progress)
	var rail_panel = PanelContainer.new()
	rail_panel.custom_minimum_size.x = 256
	rail_panel.add_theme_stylebox_override("panel", style(Color("1a2222")))
	middle.add_child(rail_panel)
	var rail = VBoxContainer.new()
	rail.add_theme_constant_override("separation", 6)
	rail_panel.add_child(rail)
	scenario_tag = rail_text(rail, 16, 11, Color("9cab96"))
	scenario_title = rail_text(rail, 27, 18, Color("ded8c4"))
	scenario_title.add_theme_font_override("font", TITLE)
	rail.add_child(HSeparator.new())
	var steps_view = ScrollContainer.new()
	steps_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	steps_view.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	steps_view.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	rail.add_child(steps_view)
	step_list = VBoxContainer.new()
	step_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step_list.add_theme_constant_override("separation", 5)
	steps_view.add_child(step_list)
	upgrade_label = rail_text(rail, 48, 12, Color("96cde5"), 3)
	feedback = rail_text(rail, 36, 13, Color("b5d599"), 2)
	rail.add_child(text("ЦЕЛЬ АВТО   ·   АВТОУСКОРЕНИЕ", 10, Color("81917f")))
	var motion = CheckButton.new()
	motion.text = "Движение героя"
	motion.button_pressed = true
	motion.focus_mode = Control.FOCUS_NONE
	motion.add_theme_font_size_override("font_size", 13)
	motion.custom_minimum_size.y = 32
	motion.toggled.connect(func(on):
		world.hero_animation.enabled = on
		world.hero_animation.update_mesh()
		world.queue_redraw())
	rail.add_child(motion)
	build_hud(outer)

func build_hud(parent: Node):
	var hud = row(parent, 12)
	var portrait_column = panel(hud)
	portrait_column.custom_minimum_size.x = 140
	var portrait = TextureRect.new()
	portrait.texture = load("res://assets/arena/" + str(catalog.data.get("portrait", "portrait.png")))
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(140, 65)
	portrait_column.add_child(portrait)
	portrait_column.add_child(text(str(catalog.data.name).to_upper(), 12, Color("d7c79e")))
	var abilities = row(hud, 6)
	for action in Bindings.ACTIONS.slice(0, 6):
		build_hud_slot(abilities, action, false)
	var inventory = GridContainer.new()
	inventory.columns = 3
	inventory.add_theme_constant_override("h_separation", 5)
	inventory.add_theme_constant_override("v_separation", 5)
	hud.add_child(inventory)
	for action in Bindings.ACTIONS.slice(6, 12):
		build_hud_slot(inventory, action, true)
	build_hud_slot(hud, "tp", false)
	var space = Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.add_child(space)
	var score = panel(hud)
	score.custom_minimum_size.x = 125
	score.add_theme_constant_override("separation", 3)
	score.add_child(text("ОЧКИ", 10, Color("9aa892")))
	status_points = text("0", 28, Color("b7d591"))
	status_points.custom_minimum_size.y = 36
	status_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.add_child(status_points)
	status_record = text("", 11, Color("a1b39b"))
	score.add_child(status_record)
	status_goal = text("", 11, Color("d7c59e"))
	score.add_child(status_goal)
	status_streak = text("Серия: 0", 11, Color("a1b39b"))
	score.add_child(status_streak)
	for node in [status_points,status_record,status_goal,status_streak]:
		node.clip_text = true
		node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func build_hud_slot(parent: Node, action: String, small: bool):
	var frame = PanelContainer.new()
	frame.custom_minimum_size = Vector2(62 if small else 65, 58 if small else 121)
	frame.add_theme_stylebox_override("panel", style(Color("101718"), Color("3d4944")))
	parent.add_child(frame)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	frame.add_child(v)
	var active = catalog.action_available(action, session.upgrades) and int(session.mapping.get(action, 0)) != 0
	var texture = icon(action)
	if texture != null:
		frame.modulate = Color.WHITE if active else Color(0.45, 0.45, 0.45)
		var image = TextureRect.new()
		image.texture = texture
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = Vector2(34, 25 if small else 57)
		image.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(image)
	else:
		var empty = text("—", 18 if small else 27, Color("4a5754"))
		empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(empty)
	var key = text(Bindings.key_name(int(session.mapping.get(action, 0))), 12 if small else 18, Color("ddd9c7") if active else Color("596762"))
	if key.text.length() > 3:
		key.add_theme_font_size_override("font_size", 10 if small else 12)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(key)
	hud_key_labels[action] = key
	frame.tooltip_text = catalog.action_name(action) + (" · требуется улучшение" if catalog.data.actions.has(action) and not active else "")
	hud_frames[action] = frame

func rebuild_steps():
	for child in step_list.get_children():
		step_list.remove_child(child)
		child.queue_free()
	step_nodes.clear()
	var scenario = session.scenario()
	scenario_tag.text = "СЛУЧАЙНАЯ ЦЕПОЧКА"
	scenario_title.text = scenario.title
	for action in scenario.steps:
		var p = PanelContainer.new()
		p.custom_minimum_size.y = 34
		var base_style = style(Color("141c1b"), Color("3c4843"))
		base_style.content_margin_top = 5
		base_style.content_margin_bottom = 5
		p.add_theme_stylebox_override("panel", base_style)
		step_list.add_child(p)
		var r = row(p, 8)
		var key = text(Bindings.key_name(int(session.mapping[action])), 20, Color("e1dfcf"))
		key.custom_minimum_size.x = 34
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if key.text.length() > 3:
			key.add_theme_font_size_override("font_size", 12)
		r.add_child(key)
		var tex = TextureRect.new()
		tex.texture = icon(action)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.custom_minimum_size = Vector2(24, 24)
		r.add_child(tex)
		var name_label = text(catalog.data.actions[action].short, 14)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.tooltip_text = catalog.action_name(action)
		r.add_child(name_label)
		step_nodes.append(p)

func update_interface():
	var time_left = maxi(0, ceili(session.duration - session.elapsed))
	status_time.text = "%02d:%02d" % [time_left / 60, time_left % 60]
	status_score.text = "Точность —" if session.completed == 0 else "Точность %d%%" % roundi(100.0 * session.clean / session.completed)
	status_streak.text = "Серия: " + str(session.streak)
	var points = Records.points_values(session.clean, session.wrong, session.early, session.missed)
	status_points.text = str(points)
	if personal_best.is_empty():
		status_record.text = "Рекорда пока нет"
		status_goal.text = "Заверши разминку"
	else:
		var best_points = int(personal_best.score)
		status_record.text = "Рекорд: " + str(best_points)
		status_goal.text = "Выше рекорда!" if points > best_points else "Цель: " + str(best_points + 1)
	scenario_tag.text = "ТЕМП ×%.2f  ·  %d КЛАВИШ" % [session.speed, session.scenario().steps.size()]
	pause_button.text = "Продолжить" if session.phase == "paused" else "Пауза · Esc"
	var upgrade_key = str(session.upgrades)
	upgrade_label.text = session.upgrade_notice if not session.upgrade_notice.is_empty() else ("Улучшение со второй минуты" if session.duration >= 180 else "Базовые способности")
	upgrade_label.tooltip_text = upgrade_label.text
	if shown_upgrades != upgrade_key:
		shown_upgrades = upgrade_key
		for a in hud_frames:
			var active = catalog.action_available(a, session.upgrades) and int(session.mapping.get(a, 0)) != 0
			hud_frames[a].modulate = Color.WHITE if active else Color(0.45, 0.45, 0.45)
			hud_key_labels[a].add_theme_color_override("font_color", Color("ddd9c7") if active else Color("596762"))
			hud_frames[a].tooltip_text = catalog.action_name(a) + (" · требуется улучшение" if catalog.data.actions.has(a) and not active else "")
	var scenario = session.scenario()
	if displayed_scenario != str(scenario.id):
		displayed_scenario = str(scenario.id)
		rebuild_steps()
	var action = session.expected()
	var key_name = Bindings.key_name(int(session.mapping.get(action, 0)))
	current_key.add_theme_font_size_override("font_size", 39 if key_name.length() <= 3 else 23)
	current_key.add_theme_color_override("font_color", Color("b6d59a"))
	progress.value = 0
	match session.phase:
		"countdown":
			current_key.text = str(maxi(1, ceili(session.phase_left)))
			current_title.text = "Приготовься"
			current_hint.text = "Клавиши — из твоего профиля. Цель выбрана автоматически."
		"briefing":
			current_key.text = "···"
			current_title.text = "Получено улучшение" if session.upgrade_granted else str(scenario.title)
			current_hint.text = session.upgrade_notice if session.upgrade_granted else "Следующая цепочка…"
		"active":
			current_key.text = key_name
			current_title.text = "Нажми " + key_name
			current_hint.text = catalog.action_name(action) + "  ·  нажми сейчас"
			progress.value = clampf(session.phase_left / session.response_window * 100.0, 0, 100)
		"casting":
			current_key.text = key_name
			current_key.add_theme_color_override("font_color", Color("bdad83"))
			current_title.text = "Верно"
			current_hint.text = "Следующая клавиша…"
			var total = session.TRANSITION
			progress.value = 100 - session.phase_left / total * 100
		"resolution":
			current_key.text = "+" if session.feedback_good else "!"
			current_title.text = session.feedback
			current_hint.text = "Следующая последовательность — через мгновение."
		"paused":
			current_key.text = "II"
			current_title.text = "Пауза"
			current_hint.text = "Esc или «Продолжить». Таймер и эффекты остановлены."
	feedback.text = session.feedback
	feedback.tooltip_text = feedback.text
	current_hint.tooltip_text = current_hint.text
	feedback.add_theme_color_override("font_color", Color("b5d599") if session.feedback_good else Color("e4a192"))
	if displayed_phase != session.phase or displayed_step != session.step_index:
		displayed_phase = session.phase
		displayed_step = session.step_index
		for i in step_nodes.size():
			var border = Color("3c4843")
			var fill = Color("141c1b")
			if i < session.step_index:
				border = Color("617f54")
				fill = Color("263226")
			elif i == session.step_index and session.phase in ["active", "casting"]:
				border = Color("bfad7d")
				fill = Color("30372a")
			var step_style = style(fill, border)
			step_style.content_margin_top = 5
			step_style.content_margin_bottom = 5
			step_nodes[i].add_theme_stylebox_override("panel", step_style)
		for a in hud_frames:
			var selected = a == action and session.phase in ["active", "casting"]
			hud_frames[a].add_theme_stylebox_override("panel", style(Color("293729") if selected else Color("101718"), Color("a2c87c") if selected else Color("3d4944")))

func toggle_pause():
	if session.phase == "paused":
		session.resume()
	else:
		session.pause()
		audio.player.stop()
	held_events.clear()
	release_events.clear()
	physical_keys.clear()
	ambiguous_input = false
	last_tick = Time.get_ticks_usec()
	update_interface()

func focus_lost():
	session.pause()
	audio.player.stop()
	held_events.clear()
	release_events.clear()
	physical_keys.clear()
	ambiguous_input = false
	update_interface()

func stop():
	session.finish()
	emit_result()

func emit_result():
	if result_sent:
		return
	result_sent = true
	finished.emit(session.report())

func _input(event: InputEvent):
	if not event is InputEventKey:
		return
	get_viewport().set_input_as_handled()
	var code = int(event.physical_keycode if event.physical_keycode else event.keycode)
	if not event.pressed:
		physical_keys.erase(code)
		session.release(code)
		release_events.append(code)
	elif not event.echo:
		if code == KEY_ESCAPE:
			toggle_pause()
		elif code not in Bindings.RESERVED and not event.alt_pressed and not event.ctrl_pressed and not event.meta_pressed:
			physical_keys[code] = true
			ambiguous_input = ambiguous_input or physical_keys.size() > 1
			held_events.append(code)

func _process(_delta: float):
	if result_sent:
		return
	var now = Time.get_ticks_usec()
	var dt = maxf(0, float(now - last_tick) / 1000000.0)
	last_tick = now
	var animate = not session.phase in ["countdown", "paused", "finished"]
	# A press received before a ready signal is displayed cannot become a
	# valid future step merely because a cast finishes during this frame.
	if not held_events.is_empty() and session.phase != "active":
		session.press_batch(held_events, ambiguous_input)
		held_events.clear()
	session.advance(dt)
	if animate and session.phase != "finished":
		world.advance(dt)
	if not held_events.is_empty():
		session.press_batch(held_events, ambiguous_input)
	for code in release_events:
		session.release(code)
	session.held = physical_keys.duplicate()
	held_events.clear()
	release_events.clear()
	ambiguous_input = false
	for event in session.events:
		world.receive(event)
		if event.type == "cast":
			audio.play("cast")
		elif event.type == "complete" and event.success:
			audio.play("success")
		elif event.type == "error":
			audio.play("error")
	session.events.clear()
	if session.phase == "finished":
		emit_result()
	else:
		update_interface()
