extends SceneTree
const Animator = preload("res://scripts/ds_skeletal_animator.gd")
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
	a.advance(.1)
	expect(a.total_releases == 0,"no impact before hand strike")
	var before = a.age
	a.receive({"type":"cast"})
	expect(a.age == before and a.pending,"retrigger preserves current skeletal motion")
	a.advance(.21)
	expect(a.total_releases == 1 and a.release_events[0].emitter_uv == a.data.clips.attack_a.points[18].emitter_uv,"contact at genuine hand pose")
	a.advance(.6)
	expect(a.state == "attack_b","ordinary source attacks alternate")
	var fixed_rect = true
	var rect = a.actor_rect(Vector2(500,400),220)
	for i in 1200:
		if i % 12 == 0: a.receive({"type":"cast"})
		a.advance(1.0 / 120)
		fixed_rect = fixed_rect and a.actor_rect(Vector2(500,400),220) == rect
	expect(fixed_rect,"fixed native camera/scale throughout rapid burst")
	expect(a.total_releases >= 17 and a.total_releases < 24,"10 keys/s bounded by full readable cycles")
	a.advance(2)
	expect(a.state == "idle" and not a.pending,"no long queue after input stops")
	var contact_visible = true
	var display = Animator.new()
	for i in 300:
		if i % 3 == 0: display.receive({"type":"cast"})
		var count = display.total_releases
		display.advance(1.0 / 30)
		if display.total_releases > count: contact_visible = contact_visible and display.frame() == int(display.data.clips[display.state].release)
	expect(contact_visible,"30fps rapid playback always displays the genuine contact pose")
	var world = World.new()
	world.configure(Catalog.new("res://data/dark_seer.json").data)
	world.size = Vector2(900,520)
	var contact = world.impact_position()
	var target = world.target_foot()
	var valid = true
	for clip in ["attack_a","attack_b"]:
		var p = a.data.clips[clip].points[int(a.data.clips[clip].release)]
		var r = world.hero_animation.actor_rect(world.hero_foot(),234)
		var hand = r.position + Vector2(p.emitter_uv[0],p.emitter_uv[1]) * r.size
		valid = valid and hand.distance_to(contact) < 26
	expect(valid,"both native hands reach fixed target chest")
	world.receive({"type":"cast"})
	world.advance(.31)
	expect(world.effects.size() == 1 and world.effects[0].hit_time == 0.0,"melee contact instead of a flying orb")
	world.advance(.01)
	expect(world.target_hit > 0,"instant melee impact after contact")
	world.advance(.4)
	expect(world.effects.is_empty() and world.target_foot() == target,"target stays fixed after recovery")
	world.hero_animation.enabled = false
	world.receive({"type":"cast"})
	expect(world.effects.size() == 1 and world.hero_animation.frame() == 0,"static mode still provides feedback")
	world.free()
	arena = load("res://scripts/arena_screen.gd").new()
	expect(arena.configure({"name":"DS QA","bindings":Bindings.preset(true),"records":{}},180,2.6,42,"dark_seer"),"DS arena configures")
	root.add_child(arena)
	arena.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arena.set_process(false)
	step(3.01)
	step(.36)
	var key = InputEventKey.new()
	key.physical_keycode = int(arena.session.mapping[arena.session.expected()])
	key.pressed = true
	var clean = arena.session.clean
	arena._input(key)
	step(.001)
	key.pressed = false
	arena._input(key)
	expect(arena.session.clean == clean + 1 and arena.world.hero_animation.total_releases == 0,"key scores before cosmetic hand contact")
	step(.08)
	arena.toggle_pause()
	var frozen = arena.world.hero_animation.age
	for i in 60: step(1.0 / 60)
	expect(arena.world.hero_animation.age == frozen,"pause freezes skeletal pose")
	arena.toggle_pause()
	for i in 270: step(1.0 / 60)
	expect(arena.world.hero_animation.state == "idle","resume/recovery settle")
	arena.queue_free()
	await process_frame
	print("DS_SKELETAL_TESTS checks=",checks," failures=",failures," burst_releases=",a.total_releases)
	quit(0 if failures == 0 else 1)
