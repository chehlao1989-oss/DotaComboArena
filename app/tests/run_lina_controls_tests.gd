extends SceneTree
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
func toggle(node: Node, title: String, on: bool) -> bool:
	if node is CheckButton and node.text == title:
		node.button_pressed = on
		return true
	for child in node.get_children():
		if toggle(child,title,on): return true
	return false
func run():
	arena = load("res://scripts/arena_screen.gd").new()
	var bindings = load("res://scripts/bindings.gd").preset(true)
	expect(arena.configure({"name":"Lina QA","bindings":bindings,"records":{}},180,2.6,42,"lina"),"arena configures")
	root.add_child(arena)
	arena.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arena.set_process(false)
	step(3.01)
	step(0.36)
	arena.world.receive({"type":"cast"})
	step(0.1)
	arena.toggle_pause()
	var frozen = arena.world.hero_animation.age
	var world_clock = arena.world.clock
	for i in 120: step(1.0 / 60)
	expect(arena.world.hero_animation.age == frozen and arena.world.clock == world_clock,"pause freezes pose and projectiles")
	arena.toggle_pause()
	for i in 240: step(1.0 / 60)
	expect(arena.world.clock > world_clock and arena.world.hero_animation.state == "idle","resume countdown completes and motion returns to idle")
	expect(toggle(arena,"Движение героя",false) and not arena.world.hero_animation.enabled,"actual motion toggle disables animation")
	arena.world.receive({"type":"cast"})
	expect(not arena.world.effects.is_empty(),"static mode still emits projectile")
	expect(toggle(arena,"Движение героя",true) and arena.world.hero_animation.enabled,"actual motion toggle reenables animation")
	expect(toggle(arena,"Эффекты",false) and not arena.world.particles_enabled,"effects setting wired")
	expect(toggle(arena,"Звук",false) and not arena.audio.enabled,"sound off wired")
	arena.audio.play("cast")
	expect(not arena.audio.player.playing,"disabled audio stays silent")
	toggle(arena,"Звук",true)
	arena.audio.play("cast")
	expect(arena.audio.player.playing,"enabled audio plays")
	arena.audio.player.stop()
	arena.queue_free()
	await process_frame
	print("LINA_CONTROLS_TESTS checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
