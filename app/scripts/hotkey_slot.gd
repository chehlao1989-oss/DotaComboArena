extends Button

const KEY_FONT = preload("res://assets/fonts/noto-sans-semibold.tres")
const CAPTION_FONT = preload("res://assets/fonts/noto-sans-regular.tres")
var key_label: Label
var caption_label: Label
var chosen = false
var listening = false
var lit = false
var off = false

func _init():
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	key_label = Label.new()
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_label.add_theme_font_override("font", KEY_FONT)
	key_label.add_theme_constant_override("line_spacing", -4)
	key_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	key_label.offset_left = 5
	key_label.offset_right = -5
	key_label.offset_top = 5
	key_label.offset_bottom = -31
	add_child(key_label)
	caption_label = Label.new()
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption_label.add_theme_font_override("font", CAPTION_FONT)
	caption_label.add_theme_font_size_override("font_size", 11)
	caption_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption_label.offset_top = -26
	caption_label.offset_bottom = -7
	add_child(caption_label)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)

func skin(background: Color, border: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = background
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(1)
	s.shadow_color = Color(0, 0, 0, 0.3)
	s.shadow_size = 3
	s.shadow_offset = Vector2(0, 2)
	s.set_content_margin_all(0)
	return s

func show_binding(key_text: String, caption: String, is_chosen: bool, is_listening: bool, is_lit: bool, is_off: bool):
	chosen = is_chosen
	listening = is_listening
	lit = is_lit
	off = is_off
	var tall = custom_minimum_size.y > 100
	var key_size = 38 if tall else 29
	key_label.text = key_text
	if key_text == "Caps Lock":
		key_label.text = "CAPS\nLOCK"
		key_size = 17 if not tall else 25
	elif key_text == "Space":
		key_label.text = "SPACE"
		key_size = 21 if not tall else 25
	elif key_text.length() > 5:
		key_size = 17
	if listening:
		key_label.text = "···"
	caption_label.text = "НАЖМИ КЛАВИШУ" if listening else ("ВЫКЛЮЧЕН" if off else caption)
	caption_label.add_theme_font_size_override("font_size", 9 if listening else 11)
	key_label.add_theme_font_size_override("font_size", key_size)
	key_label.add_theme_color_override("font_color", Color("667075") if off else Color("e2e5df"))
	caption_label.add_theme_color_override("font_color", Color("677074") if off else Color("9ca6a5"))
	var border = Color("465052")
	var fill = Color("111719")
	if chosen:
		border = Color("b9a376")
	if listening or lit:
		border = Color("a9ce92")
		fill = Color("25362b")
		key_label.add_theme_color_override("font_color", Color("d2efbb"))
	if off:
		fill = Color("121718")
	add_theme_stylebox_override("normal", skin(fill, border))
	add_theme_stylebox_override("hover", skin(fill.lightened(0.07), Color("c2b48e")))
	add_theme_stylebox_override("pressed", skin(Color("2a3631"), Color("d0c298")))
	queue_redraw()

func _draw():
	var tint = Color(1, 1, 1, 0.035 if not off else 0.012)
	draw_rect(Rect2(2, 2, size.x - 4, size.y * 0.45), tint)
	draw_line(Vector2(9, size.y - 29), Vector2(size.x - 9, size.y - 29), Color("313b3c"), 1)
	if chosen or lit or listening:
		var accent = Color("a9ce92") if lit or listening else Color("b9a376")
		draw_line(Vector2(1, 1), Vector2(size.x - 1, 1), accent, 2)
		draw_circle(Vector2(size.x - 8, 8), 2, accent)
