extends SceneTree
const Animator = preload("res://scripts/wr_skeletal_animator.gd")
const Session = preload("res://scripts/arena_session.gd")
const Catalog = preload("res://scripts/hero_catalog.gd")
const Bindings = preload("res://scripts/bindings.gd")
var checks = 0
var failures = 0
func _initialize(): call_deferred("run")
func expect(ok: bool, label: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func run():
	var a = Animator.new()
	a.receive({"type":"cast"})
	a.advance(0.2)
	expect(a.total_releases == 0, "no projectile before release")
	var old_age = a.age
	a.receive({"type":"cast"})
	expect(a.age == old_age and a.pending, "retrigger preserves current motion")
	a.advance(0.08)
	expect(a.total_releases == 1, "projectile at real frame 12")
	a.advance(0.3)
	expect(a.total_releases == 1, "release exactly once")
	var max_pending = 0
	for i in 1200:
		if i % 12 == 0: a.receive({"type":"cast"})
		a.advance(1.0 / 120)
		max_pending = maxi(max_pending, int(a.pending))
	expect(a.total_releases > 30 and a.total_releases < 45, "10 keys/s bounded to readable 3.75 attacks/s")
	expect(max_pending == 1, "saturating pending latch")
	a.advance(2)
	expect(a.state == "idle" and not a.pending, "no long attack queue after input stops")
	var count = a.total_releases
	a.enabled = false
	a.receive({"type":"cast"})
	expect(a.total_releases == count + 1 and a.frame() == 0, "motion disabled still responds with one projectile")
	a.advance(1)
	expect(a.state == "idle" and a.frame() == 0, "static pose has no queued motion")
	a.enabled = true
	a.receive({"type":"cast"})
	a.advance(0.1)
	old_age = a.age
	# ArenaScreen pause suspends World.advance; no separate wall-clock timer.
	expect(a.age == old_age, "paused controller does not advance itself")
	var s = Session.new()
	s.start(Catalog.new("res://data/windranger.json"), Bindings.preset(true), 180, 1.2, 42)
	s.advance(3.01)
	s.advance(0.36)
	var successes = 0
	for i in 2400:
		if s.phase == "active":
			var code = int(s.mapping[s.expected()])
			var before = s.clean
			s.press_batch([code])
			s.release(code)
			expect(s.clean == before + 1, "correct key immediately scores independently of animation")
			successes += 1
		s.advance(1.0 / 120)
	expect(successes > 50, "maximum ready-signal cadence exercised across multiple chains")
	print("WR_SKELETAL_TESTS checks=",checks," failures=",failures," visual_releases=",count," scored_inputs=",successes)
	quit(0 if failures == 0 else 1)
