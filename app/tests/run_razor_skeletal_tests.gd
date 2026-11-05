extends SceneTree
const Animator = preload("res://scripts/razor_skeletal_animator.gd")
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
	a.receive({"type":"cast"})
	a.advance(0.2)
	expect(a.total_releases == 0,"no lightning before attack contact")
	var before = a.age
	a.receive({"type":"cast"})
	expect(a.age == before and a.pending,"new input preserves real whip swing")
	a.advance(0.11)
	expect(a.total_releases == 1,"one release at source frame 9")
	var release = a.release_events[0]
	expect(release.emitter_uv == a.data.clips.attack.points[9].emitter_uv,"release uses source whip_7 endpoint")
	a.advance(0.2)
	expect(a.total_releases == 1,"no duplicate pulse within one attack")
	var rect = a.actor_rect(Vector2(500,300),220)
	var fixed_rect = true
	for i in 1200:
		if i % 12 == 0: a.receive({"type":"cast"})
		a.advance(1.0 / 120)
		fixed_rect = fixed_rect and a.actor_rect(Vector2(500,300),220) == rect
	expect(fixed_rect,"fixed camera and scale through entire rapid burst")
	expect(a.total_releases > 20 and a.total_releases < 30,"10 keys/s coalesced into bounded complete attacks")
	a.advance(2)
	expect(a.state == "idle" and not a.pending,"no long queue after release of keys")
	var points_valid = true
	for clip in a.data.clips.values():
		for p in clip.points:
			points_valid = points_valid and p.whip_uvs.size() == 7 and p.whip_uvs[-1] == p.emitter_uv
	expect(points_valid,"seven genuine skeletal whip positions per frame")
	var world = World.new()
	world.configure(Catalog.new("res://data/razor.json").data)
	world.size = Vector2(900,520)
	world.receive({"type":"cast"})
	world.advance(0.31)
	expect(world.effects.size() == 1 and world.effects[0].age == 0,"pulse first appears exactly at weapon endpoint")
	var uv = a.data.clips.attack.points[9].emitter_uv
	var r = world.hero_animation.actor_rect(world.hero_foot(),234)
	var expected = (r.position + Vector2(uv[0],uv[1]) * r.size) / world.size
	expect(Vector2(world.effects[0].origin_uv).is_equal_approx(expected),"pulse origin matches exported source attachment")
	world.advance(0.01)
	expect(world.target_hit > 0,"electric contact hits immediately without old orb flight")
	world.advance(0.4)
	expect(world.effects.is_empty(),"electrical pulse expires")
	world.hero_animation.enabled = false
	world.receive({"type":"cast"})
	expect(world.effects.size() == 1 and world.hero_animation.frame() == 0,"static mode retains immediate feedback")
	world.free()
	arena = load("res://scripts/arena_screen.gd").new()
	expect(arena.configure({"name":"Razor QA","bindings":Bindings.preset(true),"records":{}},180,2.6,42,"razor"),"Razor arena configures")
	root.add_child(arena)
	arena.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arena.set_process(false)
	step(3.01)
	step(0.36)
	var key = InputEventKey.new()
	key.physical_keycode = int(arena.session.mapping[arena.session.expected()])
	key.pressed = true
	var score = arena.session.clean
	arena._input(key)
	step(0.001)
	key.pressed = false
	arena._input(key)
	expect(arena.session.clean == score + 1 and arena.world.hero_animation.total_releases == 0,"physical input scores before cosmetic swing completes")
	step(0.1)
	arena.toggle_pause()
	var frozen = arena.world.hero_animation.age
	for i in 60: step(1.0 / 60)
	expect(arena.world.hero_animation.age == frozen,"pause freezes genuine skeleton")
	arena.toggle_pause()
	for i in 270: step(1.0 / 60)
	expect(arena.world.hero_animation.state == "idle","resume completes swing and recovery")
	arena.queue_free()
	await process_frame
	print("RAZOR_SKELETAL_TESTS checks=",checks," failures=",failures," burst_releases=",a.total_releases)
	quit(0 if failures == 0 else 1)
