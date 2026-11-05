extends SceneTree
var app
func _initialize():
	call_deferred("run")
func settle():
	for i in 8:
		await process_frame
func sample(arena, tag):
	print("LAYOUT ",tag," world=",arena.world.get_global_rect()," arena=",arena.get_global_rect()," minimum=",arena.get_combined_minimum_size()," hint_min=",arena.current_hint.get_combined_minimum_size()," rail_min=",arena.step_list.get_parent().get_combined_minimum_size())
func run():
	app=load("res://scripts/main.gd").new()
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	app.apply_preset(true)
	app.save_settings()
	for height in [800,720,700]:
		root.size=Vector2i(1280,height)
		app.size=Vector2(1280,height)
		await settle()
		for hero in ["windranger","razor","lina","phantom_assassin","dark_seer"]:
			app.selected_hero=hero
			app.start_arena(180,1.8,42)
			var a=app.get_child(0)
			a.set_process(false)
			a.session.advance(3.01)
			a.session.advance(0.36)
			a.session.sequence_length=5
			a.session.current_sequence=a.session.generator.next_sequence(5)
			a.update_interface()
			await settle()
			sample(a,"%s %d before" % [hero,height])
			a.session.elapsed=60
			a.session.phase="resolution"
			a.session.phase_left=0.01
			a.session.advance(0.02)
			a.update_interface()
			for frame in 6:
				await process_frame
				sample(a,"%s %d upgrade f%d" % [hero,height,frame])
			await settle()
			sample(a,"%s %d upgrade" % [hero,height])
			a.session.advance(2.51)
			a.update_interface()
			await settle()
			sample(a,"%s %d active" % [hero,height])
	quit()
