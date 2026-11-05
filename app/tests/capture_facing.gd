extends SceneTree
var output = ""
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
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(900,520)
	var catalog_script = load("res://scripts/hero_catalog.gd")
	var world_script = load("res://scripts/arena_world.gd")
	var number = 0
	for hero in catalog_script.HEROES:
		var c = catalog_script.new("res://data/"+hero+".json")
		var world = world_script.new()
		world.configure(c.data)
		root.add_child(world)
		world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var label = Label.new()
		label.text = c.data.name
		label.add_theme_font_override("font",load("res://assets/fonts/radiance-semibold.otf"))
		label.add_theme_font_size_override("font_size",22)
		label.position = Vector2(18,480)
		root.add_child(label)
		for frame in 45:
			if frame in [6,19,32]:
				world.receive({"type":"cast","action":"a1","duration":0.1})
			world.advance(1.0/30.0)
			await process_frame
			await RenderingServer.frame_post_draw
			var result = root.get_texture().get_image().save_png(output.path_join("frame_%04d.png" % number))
			if result != OK:
				quit(1)
				return
			number += 1
		root.remove_child(world)
		world.free()
		root.remove_child(label)
		label.free()
	print("FACING_CAPTURE frames=",number)
	quit()
