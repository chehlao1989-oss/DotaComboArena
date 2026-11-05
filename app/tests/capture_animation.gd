extends SceneTree
var output = ""
var world
func _initialize():
	call_deferred("run")
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-root="):
			output = arg.trim_prefix("--capture-root=")
	if output.is_empty():
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(900, 520)
	world = load("res://scripts/arena_world.gd").new()
	root.add_child(world)
	world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var render_times = []
	for frame in 210:
		if frame in [20, 50, 80, 100, 110, 120, 130, 140, 150]:
			world.receive({"type":"cast", "action":"a1", "duration":0.1})
		var begin = Time.get_ticks_usec()
		world.advance(1.0 / 30.0)
		render_times.append(Time.get_ticks_usec() - begin)
		await process_frame
		await RenderingServer.frame_post_draw
		var code = root.get_texture().get_image().save_png(output.path_join("frame_%04d.png" % frame))
		if code != OK:
			quit(1)
			return
	render_times.sort()
	print("ANIMATION_CAPTURE frames=210 mesh_update_median_us=", render_times[105], " p95_us=", render_times[199])
	quit()
