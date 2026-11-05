extends SceneTree
var output = ""
var app
func _initialize():
	call_deferred("run")
func capture(name: String):
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	print("CAPTURE ",name," code=",root.get_texture().get_image().save_png(output.path_join(name)))
func sync(arena):
	for event in arena.session.events:
		arena.world.receive(event)
	arena.session.events.clear()
	arena.update_interface()
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-root="):
			output = arg.trim_prefix("--capture-root=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	app = load("res://scripts/main.gd").new()
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.apply_preset(true)
	app.save_settings()
	for hero in load("res://scripts/hero_catalog.gd").HEROES:
		app.selected_hero = hero
		app.start_arena(180,1.8,42)
		var arena = app.get_child(0)
		arena.set_process(false)
		arena.audio.enabled = false
		arena.session.advance(3.01)
		arena.session.advance(0.36)
		sync(arena)
		arena.world.advance(0.5)
		await capture(hero + "-base.png")
		arena.session.sequence_length = 5
		arena.session.elapsed = 60
		arena.session.phase = "resolution"
		arena.session.phase_left = 0.01
		arena.session.advance(0.02)
		sync(arena)
		await capture(hero + "-upgrade.png")
		arena.session.advance(2.51)
		sync(arena)
		var code = int(arena.session.mapping[arena.session.expected()])
		arena.session.press_batch([code])
		arena.session.release(code)
		sync(arena)
		arena.world.advance(0.15)
		await capture(hero + "-cast.png")
		arena.world.advance(0.10)
		await capture(hero + "-flight.png")
	app.go_home()
	await capture("hero-menu.png")
	quit()
