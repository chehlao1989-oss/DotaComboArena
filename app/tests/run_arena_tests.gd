extends SceneTree
const Catalog = preload("res://scripts/hero_catalog.gd")
const Session = preload("res://scripts/arena_session.gd")
const Generator = preload("res://scripts/sequence_generator.gd")
const Bindings = preload("res://scripts/bindings.gd")
var checks = 0
var failures = 0
func _initialize():
	call_deferred("run")
func expect(ok: bool, label: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func make():
	var s = Session.new()
	expect(s.start(Catalog.new(), Bindings.preset(true), 180, 1.8, 42), "start")
	s.advance(3.01)
	s.advance(0.36)
	return s
func cast(s):
	var code = int(s.mapping[s.expected()])
	s.press_batch([code])
	s.release(code)
func run():
	var c = Catalog.new()
	expect(c.error.is_empty(), "catalog")
	var pool = c.action_pool(Bindings.preset(true))
	expect(pool.abilities == ["a1", "a2", "a3", "a6"], "active abilities only")
	expect(pool.items.size() == 4 and not "i2" in pool.items and not "i5" in pool.items, "disabled items excluded")
	var g = Generator.new()
	g.configure(pool, 123)
	var h = Generator.new()
	h.configure(pool, 123)
	var total = 0
	var items = 0
	var seen = {}
	var last = ""
	var previous = []
	var valid = true
	var deterministic = true
	var no_repeat = true
	for i in 1000:
		var length = 2 + i % 4
		var seq = g.next_sequence(length)
		deterministic = deterministic and seq == h.next_sequence(length)
		valid = valid and seq.steps.size() == length
		no_repeat = no_repeat and seq.steps != previous
		for a in seq.steps:
			valid = valid and (a in pool.abilities or a in pool.items)
			no_repeat = no_repeat and a != last
			last = a
			total += 1
			if a in pool.items:
				items += 1
				seen[a] = true
		previous = seq.steps.duplicate()
	expect(valid, "1000 valid sequences")
	expect(deterministic, "reproducible seed")
	expect(no_repeat, "no repeated adjacent keys or chains")
	expect(absf(float(items) / total - 0.2) < 0.001, "20 percent items")
	expect(seen.size() == 4, "all enabled slots reached")
	g = Generator.new()
	g.configure({"abilities":pool.abilities,"items":[]}, 1)
	var only_abilities = true
	for i in 40:
		for a in g.next_sequence(5).steps:
			only_abilities = only_abilities and a in pool.abilities
	expect(only_abilities, "all items disabled still works")
	var s = make()
	expect(s.phase == "active", "countdown opens window")
	s.advance(0.2)
	cast(s)
	expect(s.completed == 1 and s.clean == 1, "correct key")
	cast(s)
	expect(s.early == 1 and s.completed == 1, "early press not queued")
	s.advance(0.11)
	expect(s.step_index == 1 and s.phase == "active", "short transition")
	cast(s)
	s.advance(0.11)
	expect(s.combos == 1 and s.successful_combos == 0, "early press invalidates clean sequence")
	s.advance(0.26)
	expect(s.scenario().id == "sequence_2", "new chain")
	s = make()
	s.press_batch([KEY_T])
	s.release(KEY_T)
	cast(s)
	expect(s.wrong == 1 and s.clean == 0 and s.mistakes.size() == 1, "wrong key recorded")
	s = make()
	s.press_batch([KEY_Q,KEY_W])
	expect(s.ambiguous == 1 and s.completed == 0, "chord rejected")
	s = make()
	var code = int(s.mapping[s.expected()])
	s.press_batch([code])
	s.press_batch([code])
	expect(s.completed == 1 and s.early == 0, "held key not repeated")
	s = make()
	s.advance(1.81)
	expect(s.missed == 1 and s.combos == 1, "timeout")
	s = make()
	var before = s.phase_left
	var elapsed = s.elapsed
	s.pause()
	s.advance(20)
	expect(s.elapsed == elapsed, "pause freezes")
	s.resume()
	s.advance(3.01)
	expect(s.phase == "active" and is_equal_approx(s.phase_left,before), "resume restores window")
	s = make()
	for i in 20:
		s.register_step(true,false)
	expect(is_equal_approx(s.speed,1.05) and s.sequence_length == 3, "clean block speeds and lengthens")
	for i in 40:
		s.register_step(true,false)
	expect(s.sequence_length == 5, "max length five")
	for i in 3:
		s.register_step(false,true)
	expect(is_equal_approx(s.speed,1.05), "three failures ease speed")
	for i in 1000:
		s.register_step(false,true)
	expect(is_equal_approx(s.speed,0.6) and s.sequence_length == 2, "lower bounds")
	for i in 2000:
		s.register_step(true,false)
	expect(is_equal_approx(s.speed,2.0) and s.response_window >= 0.45, "upper bounds")
	s = make()
	for i in 20:
		s.register_step(i != 0,false)
	expect(is_equal_approx(s.speed,1.05), "95 percent accelerates")
	s = make()
	for i in 20:
		s.register_step(i % 5 != 0,false)
	expect(is_equal_approx(s.speed,1.0), "80 percent holds")
	s = make()
	while s.combos < 10:
		if s.phase == "active":
			cast(s)
		s.advance(0.11)
	expect(s.successful_combos == 10 and s.clean == s.completed, "ten chains end to end")
	s.finish()
	var r = s.report()
	expect(r.mode == "arena_random" and r.scenario_results.size() <= 4 and r.item_presses > 0, "compact random report")
	print("RANDOM_TESTS checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
