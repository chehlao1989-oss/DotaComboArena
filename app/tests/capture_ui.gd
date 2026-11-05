extends SceneTree

var output = ""
var app
var preview_height = 800

func _initialize():
	call_deferred("run")

func capture(file_name: String):
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var result = root.get_texture().get_image().save_png(output.path_join(file_name))
	print("CAPTURE ", file_name, " result=", result)

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-root="):
			output = arg.trim_prefix("--capture-root=")
		if arg.begins_with("--preview-height="):
			preview_height = int(arg.trim_prefix("--preview-height="))
	if output.is_empty():
		push_error("--capture-root is required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, preview_height)
	app = load("res://scripts/main.gd").new()
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await capture("settings-standard.png")
	app.apply_preset(true)
	app.set_status("Выбери слот, чтобы изменить назначение.", true)
	await capture("settings-author.png")
	app.selected_action = "a3"
	app.capture_action = "a3"
	app.refresh_slots()
	app.set_status("Нажмите клавишу: Способность 3. Esc — отмена.", true)
	await capture("settings-capture.png")
	app.capture_action = ""
	app.save_settings()
	await capture("menu.png")
	app.start_training()
	app.model.advance(3.01)
	await capture("keyboard-check.png")
	app.model.pause()
	await capture("paused.png")
	app.finish_training()
	await capture("report.png")
	quit()
