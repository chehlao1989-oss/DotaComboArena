extends SceneTree
const Session = preload("res://scripts/arena_session.gd")
const Catalog = preload("res://scripts/hero_catalog.gd")
const Bindings = preload("res://scripts/bindings.gd")
const Records = preload("res://scripts/record_book.gd")
var output = ""
var app
func _initialize():
	call_deferred("run")
func capture(name: String):
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	print("RECORD_CAPTURE ",name," code=",root.get_texture().get_image().save_png(output.path_join(name)))
func fixture(clean: int, hero: String = "windranger") -> Dictionary:
	var s = Session.new()
	s.start(Catalog.new("res://data/"+hero+".json"),Bindings.preset(true),180,1.8,42)
	s.clean = clean
	s.completed = clean+4
	s.wrong = 2
	s.early = 1
	s.missed = 1
	s.combos = 35
	s.successful_combos = 31
	s.best_streak = 11
	s.elapsed = 180
	s.ability_presses = int(clean*0.8)
	s.item_presses = clean-s.ability_presses
	s.speed = 1.2
	s.max_speed = 1.25
	s.reactions = [270,290,320,330,350]
	s.finish(true)
	var result = s.report()
	result.timestamp = "2026-11-02T18:30:00"
	return result
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-root="):
			output = arg.trim_prefix("--capture-root=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,800)
	app = load("res://scripts/main.gd").new()
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.apply_preset(true)
	app.save_settings()
	app.store.current().name = "Ты"
	var my_id = app.store.current().id
	Records.apply(app.store.current(),fixture(100))
	Records.apply(app.store.current(),fixture(90,"lina"))
	Records.apply(app.store.current(),fixture(85,"dark_seer"))
	for entry in [["Алекс",140],["Никита",120]]:
		var profile = app.store.add_profile(entry[0])
		profile.bindings = Bindings.preset(true)
		profile.setup_done = true
		Records.apply(profile,fixture(entry[1]))
	app.store.data.selected = my_id
	app.store.save()
	app.go_home()
	await capture("menu-record.png")
	app.render_ladder()
	await capture("ladder-before.png")
	app.start_arena()
	var arena = app.get_child(0)
	arena.set_process(false)
	arena.session.advance(3.01)
	arena.session.advance(0.36)
	arena.session.clean = 105
	arena.session.completed = 105
	arena.session.elapsed = 150
	arena.update_interface()
	await capture("live-goal.png")
	app.render_arena_report(fixture(130))
	await capture("new-record.png")
	app.render_ladder()
	await capture("ladder-after.png")
	app.render_arena_report(fixture(120))
	await capture("below-record.png")
	var partial = fixture(80)
	partial.completed_session = false
	partial.elapsed = 100
	app.render_arena_report(partial)
	await capture("partial-run.png")
	quit()
