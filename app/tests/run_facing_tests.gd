extends SceneTree
const World = preload("res://scripts/arena_world.gd")
const Catalog = preload("res://scripts/hero_catalog.gd")
var checks = 0
var failures = 0
func _initialize():
	call_deferred("run")
func expect(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run():
	for hero in Catalog.HEROES:
		var c = Catalog.new("res://data/"+hero+".json")
		var world = World.new()
		world.configure(c.data)
		world.size = Vector2(900,520)
		if hero == "windranger":
			expect(world.hero_foot().is_equal_approx(Vector2(261,400.4)), "Windranger position preserved")
			expect(world.target_foot().x > world.hero_foot().x, "WR target stays to bow side")
		else:
			var facing = Vector2(-1,0.65).normalized()
			var target_dir = (world.target_foot()-world.hero_foot()).normalized()
			expect(target_dir.dot(facing)>0.95, hero+" target is in front of render")
			var render = c.data.render
			expect(render.emitter_uvs.size()==int(render.frames), hero+" one muzzle anchor per animation frame")
			var valid = true
			var left_hand = true
			for frame in int(render.frames):
				world.clock = (frame+0.01)/float(render.fps)
				var uv = render.emitter_uvs[frame]
				valid = valid and float(uv[0])>0 and float(uv[0])<1 and float(uv[1])>0 and float(uv[1])<1
				valid = valid and world.actor_rect().grow(1).has_point(world.emitter_position())
				if hero=="lina":
					left_hand = left_hand and float(uv[0])<0.4 and float(uv[1])>0.32 and float(uv[1])<0.6
			expect(valid,hero+" all muzzle positions are finite and inside sprite")
			if hero=="lina":
				expect(left_hand,"Lina projectile starts at front flaming palm")
		world.clock = 0
		world.receive({"type":"cast","action":"a1","duration":0.1})
		world.advance(0.08)
		expect(not world.effects[0].has("origin_uv"),hero+" muzzle captured at release rather than input")
		world.advance(0.04)
		var origin = Vector2(world.effects[0].origin_uv)
		expect((origin*world.size).is_equal_approx(world.emitter_position()),hero+" launch aligned with current hand or bow")
		world.advance(0.05)
		expect(Vector2(world.effects[0].origin_uv)==origin,hero+" launched shot does not follow hand backwards")
		world.advance(0.17)
		expect(world.target_hit>0,hero+" cosmetic impact still occurs")
		world.advance(0.4)
		expect(world.effects.is_empty(),hero+" shot effects expire")
		world.free()
	print("FACING_TESTS checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
