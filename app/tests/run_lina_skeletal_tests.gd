extends SceneTree
const Animator = preload("res://scripts/lina_skeletal_animator.gd")
const World = preload("res://scripts/arena_world.gd")
const Catalog = preload("res://scripts/hero_catalog.gd")
const Bindings = preload("res://scripts/bindings.gd")
var checks = 0
var failures = 0
var arena
func _initialize(): call_deferred("run")
func expect(ok: bool, label: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func step(dt: float):
	arena.last_tick = Time.get_ticks_usec() - int(dt * 1000000)
	arena._process(dt)
func run():
	var a = Animator.new()
	var rect = a.actor_rect(Vector2(500,300),220)
	a.receive({"type":"cast"})
	expect(a.state == "attack_left", "first attack uses left source hand")
	a.advance(0.25)
	expect(a.total_releases == 0,"no early fireball")
	var before = a.age
	a.receive({"type":"cast"})
	expect(a.age == before and a.pending,"repeat keeps the current source pose")
	a.advance(0.18)
	expect(a.total_releases == 1,"left-hand release at source frame 21")
	var released = a.release_events[0]
	expect(released.hand == "left" and released.emitter_uv == a.data.clips.attack_left.points[21].emitter_uv,"release uses actual left palm attachment")
	a.advance(0.4)
	expect(a.state == "attack_right","next attack alternates hands")
	a.advance(0.2)
	expect(a.total_releases == 2 and a.release_events[1].hand == "right","right source hand release")
	var fixed_rect = true
	for i in 1200:
		if i % 12 == 0: a.receive({"type":"cast"})
		a.advance(1.0 / 120)
		fixed_rect = fixed_rect and a.actor_rect(Vector2(500,300),220) == rect
	expect(fixed_rect,"fixed camera/pivot/size throughout the burst")
	expect(a.total_releases >= 20 and a.total_releases < 30,"10 keys/s coalesced into readable complete attacks")
	a.advance(2)
	expect(a.state == "idle" and not a.pending,"bounded recovery after burst")
	var world = World.new()
	world.configure(Catalog.new("res://data/lina.json").data)
	world.size = Vector2(900,520)
	world.receive({"type":"cast"})
	world.advance(0.42)
	expect(world.effects.size() == 1,"one fireball per real release")
	var origin = Vector2(world.effects[0].origin_uv)
	expect(origin.x < world.hero_foot().x / world.size.x,"active palm points toward left-side target")
	world.advance(0.1)
	expect(Vector2(world.effects[0].origin_uv) == origin,"launched fireball does not follow recovering hand")
	world.hero_animation.enabled = false
	world.receive({"type":"cast"})
	expect(world.effects.size() == 2 and world.hero_animation.frame() == 0,"static mode keeps input feedback")
	world.free()
	arena = load("res://scripts/arena_screen.gd").new()
	expect(arena.configure({"name":"Lina QA","bindings":Bindings.preset(true),"records":{}},180,2.6,42,"lina"),"Lina arena configures")
	root.add_child(arena)
	arena.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arena.set_process(false)
	step(3.01)
	step(0.36)
	var key = InputEventKey.new()
	key.physical_keycode = int(arena.session.mapping[arena.session.expected()])
	key.pressed = true
	var clean_before = arena.session.clean
	arena._input(key)
	step(0.001)
	key.pressed = false
	arena._input(key)
	expect(arena.session.clean == clean_before + 1 and arena.world.hero_animation.total_releases == 0,"correct physical key scores before animation release")
	step(0.15)
	arena.toggle_pause()
	var frozen = arena.world.hero_animation.age
	for i in 60: step(1.0 / 60)
	expect(arena.world.hero_animation.age == frozen,"pause freezes native pose")
	arena.toggle_pause()
	for i in 270: step(1.0 / 60)
	expect(arena.world.hero_animation.state == "idle","resume and recovery complete")
	arena.queue_free()
	await process_frame
	print("LINA_SKELETAL_TESTS checks=",checks," failures=",failures," burst_releases=",a.total_releases)
	quit(0 if failures == 0 else 1)
