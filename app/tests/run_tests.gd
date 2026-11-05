extends SceneTree

const Bindings = preload("res://scripts/bindings.gd")
const Store = preload("res://scripts/profile_store.gd")
const Training = preload("res://scripts/training_model.gd")
var failures: Array[String] = []
var checks = 0
var base = ""

func expect(condition: bool, message: String):
	checks += 1
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func _initialize():
	call_deferred("run")

func run():
	base = "user://tests-" + str(Time.get_ticks_usec())
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-root="):
			base = arg.trim_prefix("--test-root=").path_join(str(Time.get_ticks_usec()))
	test_bindings()
	test_profiles()
	test_training()
	await test_controller()
	print("TEST_RESULT checks=", checks, " failures=", failures.size())
	for f in failures:
		print("FAIL: ", f)
	quit(0 if failures.is_empty() else 1)

func test_bindings():
	var standard = Bindings.preset()
	expect(Bindings.errors(standard).is_empty(), "default map valid")
	expect(standard.i1 == KEY_Z and standard.i6 == KEY_N and standard.tp == KEY_T, "default item grid and TP")
	var author = Bindings.preset(true)
	expect(author.i2 == 0 and author.i5 == 0 and author.i4 == KEY_SPACE, "author positions preserved")
	expect(Bindings.errors(author).is_empty(), "author valid with disabled items")
	standard.a1 = KEY_J
	expect(Bindings.action_for(KEY_J, standard) == "a1", "remapped new key")
	expect(Bindings.action_for(KEY_Q, standard).is_empty(), "old key no longer bound")
	standard.a2 = KEY_J
	expect(not Bindings.errors(standard).is_empty(), "duplicate rejected")
	standard = Bindings.preset()
	standard.a1 = KEY_ESCAPE
	expect(not Bindings.errors(standard).is_empty(), "reserved rejected")
	standard.a1 = 0
	expect(not Bindings.errors(standard).is_empty(), "missing mandatory rejected")

func test_profiles():
	var s = Store.new(base.path_join("profiles"))
	expect(s.load_data() == "new", "first run creates data")
	expect(not s.current().setup_done, "first run needs setup")
	var first_id = s.current().id
	s.current().bindings = Bindings.preset(true)
	s.current().setup_done = true
	expect(s.save(), "save author profile")
	s.add_profile("Второй игрок")
	var second_id = s.current().id
	expect(not s.current().setup_done and s.current().bindings.i1 == KEY_Z, "new player standard independent")
	s.current().bindings.a1 = KEY_J
	s.current().setup_done = true
	expect(s.save(), "save second player")
	var reopened = Store.new(s.directory)
	expect(reopened.load_data() == "ok", "restart loads valid file")
	expect(reopened.data.selected == second_id and reopened.current().bindings.a1 == KEY_J, "last selected and custom key restored")
	reopened.data.selected = first_id
	expect(reopened.current().bindings.i4 == KEY_SPACE, "first player untouched")
	expect(reopened.save(), "profile switch saved")
	var invalid = reopened.data.duplicate(true)
	invalid.profiles[0].sessions = "broken"
	expect(not reopened.valid(invalid), "malformed statistics detected")
	var damaged = FileAccess.open(s.file_path(), FileAccess.WRITE)
	damaged.store_string("{broken-json")
	damaged.close()
	var recovery = Store.new(s.directory)
	expect(recovery.load_data() == "recovery", "corrupt primary offers recovery")
	expect(not recovery.save(), "corrupt primary not silently overwritten")
	expect(recovery.recover(true), "backup restored explicitly")
	expect(recovery.valid(recovery.data), "restored data valid")
	var archives = DirAccess.get_files_at(s.directory)
	var found = false
	for file in archives:
		if file.contains(".damaged-"):
			found = true
	expect(found, "damaged original archived")
	var incomplete = Store.new(base.path_join("incomplete"))
	incomplete.load_data()
	var again = Store.new(incomplete.directory)
	expect(again.load_data() == "ok" and not again.current().setup_done, "interrupted setup stays unfinished")
	var only_bad = Store.new(base.path_join("without-backup"))
	only_bad.load_data()
	var badfile = FileAccess.open(only_bad.file_path(), FileAccess.WRITE)
	badfile.store_string("[]")
	badfile.close()
	var no_backup = Store.new(only_bad.directory)
	expect(no_backup.load_data() == "recovery", "bad data without backup handled")
	expect(not no_backup.recover(true), "missing backup not invented")
	expect(no_backup.recover(false), "explicit fresh profile possible")

func new_model():
	var m = Training.new()
	m.start(["a1", "a2", "a3", "a6"])
	m.advance(3.01)
	return m

func test_training():
	var map = Bindings.preset()
	var m = new_model()
	m.advance(0.25)
	m.press_batch([KEY_Q], map)
	expect(m.clean == 1 and m.expected() == "a2", "correct step advances")
	m.press_batch([KEY_Q], map)
	expect(m.completed == 1 and m.early == 0, "hold ignored before release")
	m.release(KEY_Q)
	m.press_batch([KEY_W], map)
	expect(m.early == 1 and m.completed == 1, "early key not queued")
	m.release(KEY_W)
	m.advance(0.4)
	m.press_batch([KEY_E], map)
	expect(m.wrong == 1 and m.expected() == "a2", "wrong key keeps current step")
	m.release(KEY_E)
	m.press_batch([KEY_W], map)
	expect(m.completed == 2 and m.clean == 1, "corrected step not clean")
	m.release(KEY_W)
	m.advance(0.4)
	var remaining = m.window_left
	var elapsed_before = m.elapsed
	m.pause()
	m.advance(500)
	expect(m.phase == "paused" and m.window_left == remaining and m.elapsed == elapsed_before, "pause freezes all timers")
	m.resume()
	m.advance(2)
	expect(m.phase == "countdown" and m.elapsed == elapsed_before, "resume countdown does not consume session")
	m.advance(1.1)
	expect(m.phase == "active" and m.window_left == remaining, "resume restores exact remaining window")
	m.advance(2)
	expect(m.missed == 1 and m.phase == "gate", "deadline creates one miss")
	var simultaneous = new_model()
	simultaneous.press_batch([KEY_Q, KEY_W], map)
	expect(simultaneous.completed == 0 and simultaneous.ambiguous == 1, "same frame chord never clears steps")
	simultaneous.release(KEY_Q)
	simultaneous.release(KEY_W)
	simultaneous.press_batch([KEY_Q], map)
	expect(simultaneous.completed == 1 and simultaneous.clean == 0, "one fresh key recovers dirty step")
	var overlap = new_model()
	overlap.press_batch([KEY_Q], map)
	overlap.advance(0.4)
	overlap.press_batch([KEY_W], map)
	expect(overlap.completed == 1 and overlap.ambiguous == 1, "overlapping held keys rejected")
	var layout = new_model()
	map.a1 = KEY_J
	layout.press_batch([KEY_Q], map)
	expect(layout.completed == 0, "training does not hardcode Q")
	layout.release(KEY_Q)
	layout.press_batch([KEY_J], map)
	expect(layout.completed == 1, "training uses new key")
	for fps in [30, 60, 144]:
		var timed = new_model()
		for i in fps * 31:
			timed.advance(1.0 / fps)
		expect(timed.phase == "finished", "session ends at FPS " + str(fps))
	var report = m.report()
	expect(report.clean == 1 and report.completed == 3 and report.missed == 1 and report.samples == 1, "report counters")
	expect(abs(report.median_ms - 250) < 1, "reaction excludes gate and countdown")

func key_event(code: int, logical: int = 0, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var e = InputEventKey.new()
	e.physical_keycode = code
	e.keycode = logical if logical else code
	e.pressed = pressed
	e.echo = echo
	return e

func test_controller():
	var app = load("res://scripts/main.gd").new()
	root.add_child(app)
	await process_frame
	expect(app.page == "settings", "controller routes unfinished profile to settings")
	app.apply_preset(true)
	app.save_settings()
	expect(app.page == "menu", "saving setup reaches menu")
	var author_name = app.store.current().name
	app.create_player("Новый тестовый игрок")
	expect(app.page == "settings" and app.name_edit.text == "Новый тестовый игрок", "new profile does not inherit old name")
	expect(app.draft.i1 == KEY_Z, "new profile shows standard preset")
	app.selected_action = "a1"
	app.capture_action = "a1"
	app._input(key_event(KEY_J))
	expect(app.draft.a1 == KEY_J and app.capture_action.is_empty(), "controller captures new binding")
	app.capture_action = "a2"
	app._input(key_event(KEY_ESCAPE))
	expect(app.draft.a2 == KEY_W and app.capture_action.is_empty(), "escape cancels capture")
	app.save_settings()
	app.start_training()
	app.model.advance(3.01)
	app._input(key_event(KEY_J, 0x419))
	expect(app.pending_presses == [KEY_J], "physical key used even with Cyrillic logical key")
	await process_frame
	expect(app.model.completed == 1, "input dispatch reaches model")
	app._input(key_event(KEY_J, 0, true, true))
	expect(app.pending_presses.is_empty(), "echo ignored at controller")
	app.on_focus_lost()
	expect(app.model.phase == "paused", "focus loss pauses controller")
	app.finish_training()
	expect(app.page == "report" and app.report_saved, "partial report saved")
	expect(app.store.data.profiles[0].name == author_name, "other player name untouched")
	app.go_home()
	app.open_settings()
	app.draft.a1 = KEY_P
	app.cancel_settings()
	expect(app.store.current().bindings.a1 == KEY_J, "cancel discards draft")
	app.queue_free()
	await process_frame
