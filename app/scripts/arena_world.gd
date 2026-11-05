extends Control

const BACKGROUND = preload("res://assets/arena/courtyard.png")
const HERO = preload("res://assets/arena/windranger-rig.png")
const DUMMY = preload("res://assets/arena/dummy.png")
const FONT = preload("res://assets/fonts/noto-sans-semibold.tres")
const HeroAnimator = preload("res://scripts/hero_animator.gd")
const SkeletalAnimator = preload("res://scripts/wr_skeletal_animator.gd")
var hero_animation = SkeletalAnimator.new()
const LinaAnimator = preload("res://scripts/lina_skeletal_animator.gd")
const RazorAnimator = preload("res://scripts/razor_skeletal_animator.gd")
const RazorLightning = preload("res://scripts/razor_lightning.gd")
const PAAnimator = preload("res://scripts/pa_skeletal_animator.gd")
const PAMeleeEffect = preload("res://scripts/pa_melee_effect.gd")
const DSAnimator = preload("res://scripts/ds_skeletal_animator.gd")
const DSMeleeEffect = preload("res://scripts/ds_melee_effect.gd")
var ds_melee_effect
var pa_melee_effect
var razor_lightning
var lina_fire: Texture2D
var projectile_texture: Texture2D
var hero_id = "windrunner"
var hero_render: Dictionary = {}
var hero_atlas: Texture2D
var hero_accent = Color("b9ed79")
var upgrade_flash = 0.0
var effects: Array = []
var clock = 0.0
var target_hp = 1.0
var target_hit = 0.0
var scenario_id = ""
var feedback_flash = 0.0
var particles_enabled = true

func configure(data: Dictionary):
	hero_id = str(data.hero_id)
	if hero_id == "windrunner":
		hero_animation = SkeletalAnimator.new()
		projectile_texture = load("res://assets/arena/wr_native/projectile.png")
	elif hero_id == "lina":
		hero_animation = LinaAnimator.new()
		lina_fire = load("res://assets/arena/lina_native/fire.png")
	elif hero_id == "razor":
		hero_animation = RazorAnimator.new()
		razor_lightning = RazorLightning.new()
		add_child(razor_lightning)
	elif hero_id == "phantom_assassin":
		hero_animation = PAAnimator.new()
		pa_melee_effect = PAMeleeEffect.new()
		add_child(pa_melee_effect)
	elif hero_id == "dark_seer":
		hero_animation = DSAnimator.new()
		ds_melee_effect = DSMeleeEffect.new()
		add_child(ds_melee_effect)
	else:
		hero_animation = HeroAnimator.new(HERO)
		hero_animation.render_mesh = false
	hero_render = data.get("render", {})
	if not hero_render.is_empty():
		hero_atlas = load("res://assets/arena/" + str(hero_render.atlas))
	var accents = {"razor":"87cfff", "lina":"ffac5a", "phantom_assassin":"8fe4d7", "dark_seer":"d9a4ff"}
	hero_accent = Color(accents.get(hero_id, "b9ed79"))

func _init():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(600, 340)
	clip_contents = true

func reset_round(id: String):
	scenario_id = id
	target_hp = 1.0
	feedback_flash = 0
	queue_redraw()

func receive(event: Dictionary):
	hero_animation.receive(event)
	match event.type:
		"round":
			reset_round(str(event.scenario))
		"cast":
			if hero_id not in ["windrunner", "lina", "razor", "phantom_assassin", "dark_seer"]:
				effects.append({"action":"shot", "age":-0.11, "life":0.50, "hit":false})
		"upgrade":
			upgrade_flash = 2.0
		"error":
			feedback_flash = 0.22
	collect_releases()
	queue_redraw()

func collect_releases():
	if hero_id not in ["windrunner", "lina", "razor", "phantom_assassin", "dark_seer"] or size.x <= 0 or size.y <= 0:
		return
	var rect = hero_animation.actor_rect(hero_foot(), size.y * 0.45)
	for release in hero_animation.release_events:
		var uv = release.arrow_center_uv if hero_id == "windrunner" else release.emitter_uv
		var fx = {"action":"shot", "age":0.0, "life":0.50, "hit":false, "origin_uv":(rect.position + Vector2(uv[0], uv[1]) * rect.size) / size}
		if hero_id == "razor":
			fx.life = 0.28
			fx.hit_time = 0.0
		if hero_id in ["phantom_assassin", "dark_seer"]:
			fx.life = 0.24
			fx.hit_time = 0.0
		effects.append(fx)
	hero_animation.release_events.clear()
	if razor_lightning != null: razor_lightning.queue_redraw()
	if pa_melee_effect != null: pa_melee_effect.queue_redraw()
	if ds_melee_effect != null: ds_melee_effect.queue_redraw()

func advance(dt: float):
	hero_animation.advance(dt)
	clock += dt
	target_hit = maxf(0, target_hit - dt)
	feedback_flash = maxf(0, feedback_flash - dt)
	upgrade_flash = maxf(0, upgrade_flash - dt)
	for fx in effects:
		fx.age += dt
		if fx.age >= 0 and not fx.has("origin_uv") and size.x > 0 and size.y > 0:
			fx.origin_uv = emitter_position() / size
		if fx.age >= float(fx.get("hit_time",0.22)) and not fx.hit:
			fx.hit = true
			target_hit = 0.22
			target_hp = maxf(0.15, target_hp - 0.08)
	effects = effects.filter(func(f): return f.age < f.life)
	# A newly released arrow is first displayed at its exact nocked position;
	# it starts travelling on the following frame, without a muzzle gap.
	collect_releases()
	queue_redraw()

# The official animated renders face the near-left side of the arena.
# Keep those animations intact and put their target in that facing direction.
# Windranger retains her original right-facing composition.
func hero_foot() -> Vector2:
	if hero_id in ["phantom_assassin", "dark_seer"]: return size * Vector2(.66,.80)
	return size * (Vector2(0.29, 0.77) if hero_id == "windrunner" else Vector2(0.66, 0.56))

func target_foot() -> Vector2:
	if hero_id in ["phantom_assassin", "dark_seer"]: return impact_position() + Vector2(0,target_height() * .53)
	return size * (Vector2(0.61, 0.52) if hero_id == "windrunner" else Vector2(0.30, 0.86))

func anchor_foot() -> Vector2:
	if hero_id in ["phantom_assassin", "dark_seer"]: return size * Vector2(.20,.45)
	return size * (Vector2(0.80, 0.36) if hero_id == "windrunner" else Vector2(0.13, 0.65))

func actor_frame() -> int:
	return int(clock * float(hero_render.get("fps", 15))) % maxi(1, int(hero_render.get("frames", 1))) if hero_animation.enabled else 0

func actor_rect() -> Rect2:
	var height = size.y * 0.45
	var recoil_shift = hero_animation.recoil * 8 if hero_animation.enabled else 0.0
	return Rect2(hero_foot() - Vector2(height * 0.5 - recoil_shift, height), Vector2(height, height))

func emitter_position() -> Vector2:
	if hero_id in ["windrunner", "lina", "razor", "phantom_assassin", "dark_seer"]:
		return hero_animation.emitter_position(hero_foot(), size.y * 0.45)
	var points = hero_render.get("emitter_uvs", [])
	var uv = Vector2(0.25, 0.5)
	if not points.is_empty():
		var point = points[mini(actor_frame(), points.size() - 1)]
		uv = Vector2(float(point[0]), float(point[1]))
	var rect = actor_rect()
	return rect.position + rect.size * uv

func target_height() -> float:
	return size.y * (.45 if hero_id in ["phantom_assassin", "dark_seer"] else .32)

func impact_position() -> Vector2:
	if hero_id in ["phantom_assassin", "dark_seer"]:
		var rect = hero_animation.actor_rect(hero_foot(),size.y * .45)
		var uv = hero_animation.data.contact_uv
		return rect.position + Vector2(uv[0],uv[1]) * rect.size
	return target_foot() - Vector2(0, size.y * 0.32 * 0.53)

func draw_hero():
	if hero_id in ["windrunner", "lina", "razor", "phantom_assassin", "dark_seer"]:
		var rect = hero_animation.actor_rect(hero_foot(), size.y * 0.45)
		draw_texture_rect_region(hero_animation.texture(), rect, hero_animation.source_rect())
	elif hero_atlas != null:
		var frame = actor_frame()
		var cell = int(hero_render.cell)
		var columns = int(hero_render.columns)
		var source = Rect2(Vector2(frame % columns, frame / columns) * cell, Vector2(cell, cell))
		draw_texture_rect_region(hero_atlas, actor_rect(), source)

func ellipse(center: Vector2, radius: float, flatten: float, color: Color, width: float = 2):
	draw_set_transform(center, 0, Vector2(1, flatten))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, color, width, true)
	draw_set_transform(Vector2.ZERO)

func shadow(center: Vector2, radius: float):
	draw_set_transform(center, 0, Vector2(1, 0.34))
	draw_circle(Vector2.ZERO, radius, Color(0.02, 0.025, 0.015, 0.45))
	draw_set_transform(Vector2.ZERO)

func text_at(text: String, position: Vector2, font_size: int, color: Color):
	draw_string(FONT, position + Vector2(1, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.75))
	draw_string(FONT, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func healthbar(foot: Vector2, height: float, hp: float, label_text: String, selected: bool):
	var p = foot - Vector2(38, height + 21)
	draw_rect(Rect2(p, Vector2(76, 7)), Color("151716"))
	draw_rect(Rect2(p + Vector2(1, 1), Vector2(74 * hp, 5)), Color("ce624a") if selected else Color("95724d"))
	text_at(label_text, p - Vector2(0, 6), 12, Color("f0d8a1") if selected else Color("c7cac0"))

func draw_actor(texture: Texture2D, foot: Vector2, height: float, tint: Color, recoil: float = 0.0):
	var w = height * texture.get_width() / float(texture.get_height())
	var shift = Vector2(sin(clock * 50) * recoil, 0)
	var rect = Rect2(foot - Vector2(w * 0.5, height) + shift, Vector2(w, height))
	draw_texture_rect(texture, rect, false, tint)

func projectile_point(start: Vector2, end: Vector2, progress: float) -> Vector2:
	var t = clampf(progress, 0, 1)
	return start.lerp(end, t) + Vector2(0, -sin(t * PI) * 14)

func arrow(start: Vector2, end: Vector2, progress: float):
	if projectile_texture == null:
		return
	var scale_value = size.y * 0.45 / float(hero_animation.data.body_height_px)
	var dir = (end - start).normalized()
	var center = start.lerp(end - dir * float(hero_animation.data.arrow_length_px) * scale_value * 0.5, clampf(progress, 0, 1))
	var rotation = dir.angle() - float(hero_animation.data.arrow_angle)
	var native_center = Vector2(hero_animation.data.projectile_pivot_px[0], hero_animation.data.projectile_pivot_px[1])
	draw_set_transform(center, rotation, Vector2.ONE * scale_value)
	draw_texture(projectile_texture, -native_center)
	draw_set_transform(Vector2.ZERO)

func draw_fire(center: Vector2, diameter: float, index: int, opacity: float = 1.0):
	if lina_fire == null: return
	var cell = 256
	var source = Rect2(Vector2(index % 8,index / 8) * cell,Vector2(cell,cell))
	draw_texture_rect_region(lina_fire,Rect2(center - Vector2.ONE * diameter * 0.5,Vector2.ONE * diameter),source,Color(1.0,0.98,0.92,clampf(opacity,0,1)))

func lina_projectile(start: Vector2, end: Vector2, progress: float, age: float):
	var p = start.lerp(end,progress)
	var direction = (end - start).normalized()
	if particles_enabled:
		for i in range(3,0,-1):
			var behind = p - direction * i * 9
			draw_fire(behind, 55 - i * 5, (int(age * 55) + i * 3) % 12,0.5 - i * 0.09)
		draw_circle(p,18,Color(1,0.25,0.02,0.10))
	draw_fire(p,64,int(age * 45) % 12)
	draw_circle(p,3,Color(1,0.91,0.55,0.9))

func dagger(start: Vector2, end: Vector2, progress: float):
	var p = projectile_point(start, end, progress)
	var dir = (end - start).normalized()
	var side = dir.orthogonal()
	draw_colored_polygon(PackedVector2Array([p + dir * 9,p - dir * 9 + side * 3,p - dir * 5,p - dir * 9 - side * 3]), Color("c5e0e5"))
	draw_line(p - dir * 15, p - dir * 7, Color("34494e"), 2.5, true)
	draw_line(p - dir * 9 - side * 4,p - dir * 9 + side * 4,Color("8eb5b8"),1.3,true)

func _draw():
	if size.x < 1 or size.y < 1:
		return
	draw_texture_rect(BACKGROUND, Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.025, 0.025, 0.15))
	var hero = hero_foot()
	var target = target_foot()
	var anchor = anchor_foot()
	var hero_height = size.y * 0.45
	var dummy_height = target_height()
	var anchor_height = size.y * 0.27
	var bow = emitter_position()
	var impact = impact_position()
	shadow(anchor, 23)
	shadow(target, 28)
	shadow(hero, 31)
	ellipse(target, 38, 0.40, Color("e8bf78"), 2)
	ellipse(target, 44 + sin(clock * 2) * 2, 0.40, Color(0.9, 0.65, 0.28, 0.22), 1)
	ellipse(hero, 37, 0.40, Color("8cce72"), 2)
	var actors = [{"kind":"hero", "foot":hero}, {"kind":"anchor", "foot":anchor}, {"kind":"target", "foot":target}]
	actors.sort_custom(func(a,b): return a.foot.y < b.foot.y)
	if hero_id in ["phantom_assassin", "dark_seer"]:
		actors = actors.filter(func(a): return a.kind != "hero")
		actors.append({"kind":"hero","foot":hero})
	for actor in actors:
		match actor.kind:
			"hero":
				draw_hero()
			"anchor":
				draw_actor(DUMMY, anchor, anchor_height, Color("aab5aa"))
			"target":
				draw_actor(DUMMY, target, dummy_height, Color.WHITE if target_hit <= 0 else Color("ffe0ac"), 2 if target_hit > 0 else 0)
	if hero_id == "lina" and particles_enabled:
		var charge_value = hero_animation.charge()
		if charge_value > 0:
			draw_fire(emitter_position(), 40 + 30 * charge_value, int(clock * 35) % 12, charge_value)
	if hero_animation.victory_left > 0 and particles_enabled:
		var t = 1.0 - hero_animation.victory_left / 0.7
		ellipse(hero, 37 + t * 40, 0.40, Color(0.65, 0.95, 0.48, (1.0 - t) * 0.7), 2)
	healthbar(target, dummy_height, target_hp, "ЦЕЛЬ", true)
	healthbar(anchor, anchor_height, 1.0, "МАНЕКЕН", false)
	if upgrade_flash > 0 and particles_enabled:
		var fade = minf(upgrade_flash, 1.0)
		ellipse(hero, 47 + (2.0 - upgrade_flash) * 14, 0.4, Color(0.4, 0.8, 1, fade * 0.7), 2)
	for fx in effects:
		var age = float(fx.age)
		if age < 0:
			continue
		if hero_id in ["razor", "phantom_assassin", "dark_seer"]:
			continue # Dedicated contact layers; no flying orb/dagger.
		var origin = Vector2(fx.get("origin_uv", bow / size)) * size
		var flight = clampf(age / 0.22, 0, 1)
		if age < 0.22:
			if hero_id == "windrunner":
				arrow(origin, impact, flight)
			elif hero_id == "lina":
				lina_projectile(origin, impact, flight, age)
			elif hero_id in ["phantom_assassin", "dark_seer"]:
				dagger(origin, impact, flight)
			else:
				var orb = origin.lerp(impact, flight)
				draw_circle(orb, 11, Color(hero_accent, 0.10))
				draw_circle(orb, 5, Color(hero_accent, 0.75))
				draw_circle(orb, 2, Color("fff2cd"))
				if hero_id == "razor":
					var lightning = PackedVector2Array()
					for i in 9:
						lightning.append(origin.lerp(orb, i / 8.0) + Vector2(0, sin(clock * 60 + i * 2.7) * 4))
					draw_polyline(lightning, Color(hero_accent, 0.6), 1.5, true)
			if particles_enabled and not hero_id in ["windrunner", "phantom_assassin", "lina"]:
				var pos = origin.lerp(impact, flight)
				var dir = (impact - bow).normalized()
				for i in 5:
					var tail = pos - dir * (i * 9 + 8)
					draw_circle(tail + Vector2(0, sin(clock * 30 + i) * 2), 1.6 - i * 0.2, Color(hero_accent, 0.6 - i * 0.1))
		elif particles_enabled:
			if hero_id == "lina":
				draw_fire(impact, 90, mini(15, int((age - 0.22) * 50)), 1.0 - (age - 0.22) / 0.28)
			var burst = (age - 0.22) / 0.28
			var physical = hero_id in ["windrunner", "phantom_assassin"]
			var count = 5 if physical else 10
			for i in count:
				var dir = Vector2.from_angle(i * TAU / count)
				var start = impact + dir * (3 + burst * (12 if physical else 24))
				var tint = Color("c6b69c") if physical else hero_accent
				draw_line(start, start + dir * (3 if physical else 7), Color(tint, 1.0 - burst), 1.2 if physical else 1.5, true)
	if feedback_flash > 0:
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color(0.92, 0.4, 0.3, feedback_flash), false, 2)
	text_at("ТРЕНИРОВОЧНАЯ АРЕНА", Vector2(18, 25), 11, Color("c1cab7"))
	text_at("Цель выбирается автоматически", Vector2(18, 43), 12, Color("bcc7b4"))
