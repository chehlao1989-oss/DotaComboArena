extends SceneTree
var output = ""
var app
var a
func _initialize():
	call_deferred("run")
func capture(name: String):
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	print("LAYOUT_CAPTURE ",name," world=",a.world.get_global_rect()," hud=",a.world.get_parent().get_parent().get_parent().get_child(-1).get_global_rect())
	root.get_texture().get_image().save_png(output.path_join(name))
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-root="):
			output = arg.trim_prefix("--capture-root=")
	DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1100,700)
	app = load("res://scripts/main.gd").new()
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.apply_preset(true)
	app.save_settings()
	app.start_arena(180,1.8,42)
	a = app.get_child(0)
	a.set_process(false)
	a.session.advance(3.01)
	a.session.advance(0.36)
	a.session.sequence_length = 5
	a.session.current_sequence = a.session.generator.next_sequence(5)
	a.update_interface()
	await capture("before-upgrade.png")
	a.session.elapsed = 60
	a.session.phase = "resolution"
	a.session.phase_left = 0.01
	a.session.advance(0.02)
	a.update_interface()
	await capture("upgrade.png")
	a.session.advance(2.51)
	a.update_interface()
	await capture("after-upgrade.png")
	quit()
