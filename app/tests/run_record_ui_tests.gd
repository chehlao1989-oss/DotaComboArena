extends SceneTree
const Session = preload("res://scripts/arena_session.gd")
const Catalog = preload("res://scripts/hero_catalog.gd")
const Records = preload("res://scripts/record_book.gd")
const Bindings = preload("res://scripts/bindings.gd")
var checks = 0
var failures = 0
var app
func _initialize():
	call_deferred("run")
func expect(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func all_text(node: Node) -> String:
	var result = node.text + "\n" if node is Label else ""
	for child in node.get_children():
		result += all_text(child)
	return result
func collect_pickers(node: Node, result: Array):
	if node is OptionButton:
		result.append(node)
	for child in node.get_children():
		collect_pickers(child,result)
func fixture(clean: int):
	var s = Session.new()
	s.start(Catalog.new(),Bindings.preset(true),180,1.8,42)
	s.clean = clean
	s.completed = clean+2
	s.elapsed = 180
	s.best_streak = 5
	s.finish(true)
	return s.report()
func run():
	app = load("res://scripts/main.gd").new()
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.apply_preset(true)
	app.save_settings()
	var r = fixture(100)
	app.render_arena_report(r)
	expect(all_text(app).contains("Первый рекорд на Windranger"),"first PB announcement visible")
	var ctx = Records.context("windrunner",180,1.8,4)
	expect(Records.best(app.store.current(),ctx).score==10000,"controller saves PB with full report")
	app.render_arena_report(fixture(110))
	expect(all_text(app).contains("Вы побили свой рекорд на Windranger"),"improved PB announcement visible")
	app.render_arena_report(fixture(90))
	expect(not all_text(app).contains("побили свой рекорд") and all_text(app).contains("До нового рекорда"),"weaker run shows next target")
	var partial = fixture(200)
	partial.completed_session = false
	partial.elapsed = 100
	app.render_arena_report(partial)
	expect(all_text(app).contains("НЕПОЛНАЯ ПОПЫТКА") and Records.best(app.store.current(),ctx).score==11000,"partial run cannot replace PB through UI")
	app.go_home()
	var pickers: Array = []
	collect_pickers(app,pickers)
	# Profile picker, hero picker, time picker, pace picker.
	var duration = pickers[-2]
	duration.select(0)
	duration.item_selected.emit(0)
	expect(app.arena_options.seconds==60 and all_text(app).contains("Установи первый рекорд"),"changing duration updates record category immediately")
	duration.select(1)
	duration.item_selected.emit(1)
	expect(all_text(app).contains("Твой рекорд: 11000"),"returning to category restores goal")
	app.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	app.size = Vector2(1100,700)
	app.start_arena()
	var arena = app.get_child(0)
	arena.set_process(false)
	for i in 6:
		await process_frame
	var baseline = arena.world.get_global_rect()
	expect(arena.personal_best.score==11000,"live arena receives correct previous PB")
	arena.session.clean = 111
	arena.update_interface()
	for i in 6:
		await process_frame
	expect(arena.status_points.text=="11100" and arena.status_goal.text.contains("Выше рекорда"),"live score and target respond to progress")
	expect(arena.world.get_global_rect().is_equal_approx(baseline),"score and PB target do not shift arena at minimum window size")
	app.go_home()
	app.store.recovery_needed = true
	app.render_arena_report(fixture(150))
	expect(Records.best(app.store.current(),ctx).score==11000,"save failure rolls back record mutation")
	expect(all_text(app).contains("Рекорд не сохранён") and not all_text(app).contains("побили свой рекорд"),"failed save does not claim persisted PB")
	app.store.recovery_needed = false
	app.render_ladder()
	expect(all_text(app).contains("Windranger") and all_text(app).contains("Локальный ладдер") and all_text(app).contains("11000"),"ladder renders actual saved PB")
	print("RECORD_UI_TESTS checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
