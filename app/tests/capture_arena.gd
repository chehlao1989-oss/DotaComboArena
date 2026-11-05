extends SceneTree

var output = ""
var app
var arena
var height = 800

func _initialize():
	call_deferred("run")

func capture(name: String):
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	print("CAPTURE ", name, " result=", root.get_texture().get_image().save_png(output.path_join(name)))

func events():
	for event in arena.session.events:
		arena.world.receive(event)
	arena.session.events.clear()
	arena.update_interface()

func advance(seconds: float):
	for i in ceili(seconds * 100):
		arena.session.advance(0.01)
		arena.world.advance(0.01)
		events()

func cast_expected():
	var code = int(arena.session.mapping[arena.session.expected()])
	arena.session.press_batch([code])
	arena.session.release(code)
	events()

func open_arena():
	app.start_arena(180, 1.8, 42)
	arena = app.get_child(0)
	arena.set_process(false)
	arena.audio.enabled = false
	advance(3.4)

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-root="):
			output = arg.trim_prefix("--capture-root=")
		if arg.begins_with("--preview-height="):
			height = int(arg.trim_prefix("--preview-height="))
	if output.is_empty():
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, height)
	app = load("res://scripts/main.gd").new()
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.apply_preset(true)
	app.save_settings()
	await capture("arena-menu.png")
	open_arena()
	await capture("arena-ready.png")
	while arena.session.combos < 30:
		if arena.session.phase == "active":
			cast_expected()
		advance(0.11)
	while arena.session.phase != "active":
		advance(0.01)
	await capture("arena-adaptive.png")
	while not arena.session.expected().begins_with("i") or arena.session.phase != "active":
		if arena.session.phase == "active":
			cast_expected()
		advance(0.11)
	await capture("arena-item.png")
	cast_expected()
	advance(0.11)
	await capture("arena-effect.png")
	arena.session.pause()
	arena.update_interface()
	await capture("arena-paused.png")
	arena.stop()
	await capture("arena-report.png")
	quit()
