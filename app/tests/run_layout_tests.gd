extends SceneTree
var app
var checks = 0
var failures = 0
var capture_root = ""
func _initialize():
	call_deferred("run")
func expect(ok: bool, label: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func settle():
	for i in 6:
		await process_frame
func hud(a):
	return a.world.get_parent().get_parent().get_parent().get_child(-1)
func verify(a, baseline: Rect2, bounds: Vector2, tag: String):
	# Sample every layout frame, not just the final settled rectangle.
	var stable = true
	var contained = true
	for i in 6:
		await process_frame
		stable = stable and a.world.get_global_rect().is_equal_approx(baseline)
		var rect = hud(a).get_global_rect()
		contained = contained and rect.end.y <= bounds.y + 1 and rect.end.x <= bounds.x + 1
	expect(stable, tag + " stable arena on every frame")
	expect(contained, tag + " HUD remains inside viewport")
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-root="):
			capture_root = arg.trim_prefix("--capture-root=")
	app = load("res://scripts/main.gd").new()
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	app.apply_preset(true)
	app.save_settings()
	for bounds in [Vector2(1100,700),Vector2(1280,720),Vector2(1280,800),Vector2(1920,1080)]:
		app.size = bounds
		for hero in load("res://scripts/hero_catalog.gd").HEROES:
			app.selected_hero = hero
			app.start_arena(180,1.8,42)
			var a = app.get_child(0)
			a.set_process(false)
			a.session.advance(3.01)
			a.session.advance(0.36)
			a.session.sequence_length = 5
			a.session.current_sequence = a.session.generator.next_sequence(5)
			a.update_interface()
			await settle()
			var baseline = a.world.get_global_rect()
			var tag = "%s %s" % [hero,bounds]
			for second in [60,120]:
				a.session.elapsed = second
				a.session.phase = "resolution"
				a.session.phase_left = 0.01
				a.session.advance(0.02)
				a.update_interface()
				await verify(a,baseline,bounds,tag+" upgrade "+str(second))
				a.session.advance(2.51)
				a.update_interface()
				await verify(a,baseline,bounds,tag+" active "+str(second))
			a.session.current_sequence = {"id":"long-key", "title":"Последовательность 1000", "steps":["i3","i4"]}
			a.session.step_index = 0
			a.session.phase = "active"
			a.update_interface()
			await verify(a,baseline,bounds,tag+" Caps Lock and shorter chain")
			a.session.step_index = 1
			a.session.feedback = "Не успел. Следующая последовательность."
			a.update_interface()
			await verify(a,baseline,bounds,tag+" Space and feedback")
			if not capture_root.is_empty() and hero == "windranger" and bounds == Vector2(1100,700):
				root.size = Vector2i(1100,700)
				DirAccess.make_dir_recursive_absolute(capture_root)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(capture_root.path_join("layout-1100x700.png"))
	print("LAYOUT_TESTS checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
