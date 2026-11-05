extends SceneTree
const Catalog = preload("res://scripts/hero_catalog.gd")
const Session = preload("res://scripts/arena_session.gd")
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
func run():
	var expected = {"windranger":["a1","a2","a3","a6"],"razor":["a1","a2","a6"],"lina":["a1","a2","a6"],"phantom_assassin":["a1","a2","a3"],"dark_seer":["a1","a2","a3","a6"]}
	for hero in Catalog.HEROES:
		var c = Catalog.new("res://data/" + hero + ".json")
		expect(c.error.is_empty(), hero + " valid catalog")
		var s = Session.new()
		expect(s.start(c, Bindings.preset(true), 180, 1.8, 1), hero + " starts")
		expect(s.generator.abilities == expected[hero], hero + " correct base active slots")
		s.elapsed = 59.99
		s.apply_due_upgrades()
		expect(s.upgrades.is_empty(), hero + " no early upgrade")
		s.elapsed = 60
		s.apply_due_upgrades()
		expect(s.upgrades.size() == 1, hero + " first upgrade at 60")
		var extra = hero in ["windranger","lina","phantom_assassin"]
		expect(("a4" in s.generator.abilities) == extra, hero + " extra slot only if active")
		if extra:
			var seq = s.generator.next_sequence(3, s.unlocked_action)
			expect("a4" in seq.steps, hero + " first upgraded chain practices new key")
		s.apply_due_upgrades()
		expect(s.upgrades.size() == 1, hero + " upgrade not repeated")
		s.elapsed = 120
		s.apply_due_upgrades()
		expect(s.upgrades.size() == 2 and s.upgrade_history.size() == 2, hero + " second upgrade at 120")
		expect(not "a5" in s.generator.abilities, hero + " no invented F")
		s.finish()
		expect(s.report().hero_name == c.data.name and s.report().upgrades.size() == 2, hero + " report tracks hero upgrades")
		var short_session = Session.new()
		short_session.start(c, Bindings.preset(), 60)
		short_session.elapsed = 60
		short_session.apply_due_upgrades()
		expect(short_session.upgrades.is_empty(), hero + " one minute remains basic")
		var longer = Session.new()
		longer.start(c, Bindings.preset(), 300)
		longer.elapsed = 60
		longer.apply_due_upgrades()
		expect(longer.upgrades.size() == 1, hero + " longer session supports upgrades")
	var wr = Catalog.new()
	var s = Session.new()
	s.start(wr, Bindings.preset(true), 180, 1.8, 42)
	s.advance(3.01)
	s.advance(0.36)
	var chain = s.scenario().duplicate(true)
	s.elapsed = 59.99
	s.advance(0.02)
	expect(s.upgrades.is_empty() and s.scenario() == chain, "minute boundary does not interrupt chain")
	while s.phase == "active" or s.phase == "casting":
		if s.phase == "active":
			var code = int(s.mapping[s.expected()])
			s.press_batch([code])
			s.release(code)
		s.advance(0.11)
	s.advance(0.26)
	expect(s.phase == "briefing" and s.phase_left > 2.0 and "a4" in s.scenario().steps, "upgrade announced with grace period between chains")
	var before = s.elapsed
	s.pause()
	s.advance(120)
	expect(s.elapsed == before and s.upgrades.size() == 1, "pause cannot trigger second upgrade")
	var remap = Bindings.preset(true)
	remap.a4 = KEY_G
	s = Session.new()
	s.start(wr, remap, 180, 1.8, 42)
	s.elapsed = 60
	s.apply_due_upgrades()
	expect(s.upgrade_notice.contains("G"), "upgrade uses rebound physical key")
	print("HERO_TESTS checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
