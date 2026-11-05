extends RefCounted

# A small textured mesh animates the existing artwork. All offsets are local
# fractions of hero height; the boots remain anchored to the arena floor.
const COLS = 28
const ROWS = 48
var mesh = ArrayMesh.new()
var uv = PackedVector2Array()
var indices = PackedInt32Array()
var aspect = 1.0
var clock = 0.0
var shot_age = 10.0
var shot_kind = ""
var flurry_left = 0.0
var flurry_tick = 0.0
var wind = 0.0
var wind_left = 0.0
var item_left = 0.0
var victory_left = 0.0
var enabled = true
var render_mesh = true
var draw_amount = 0.0
var draw_velocity = 0.0
var recoil = 0.0
var recoil_velocity = 0.0
var release_left = 0.0
var string_age = 10.0

func _init(texture: Texture2D):
	aspect = texture.get_width() / float(texture.get_height())
	for y in ROWS + 1:
		for x in COLS + 1:
			uv.append(Vector2(float(x) / COLS, float(y) / ROWS))
	for y in ROWS:
		for x in COLS:
			var a = y * (COLS + 1) + x
			indices.append_array(PackedInt32Array([a, a + 1, a + COLS + 2, a, a + COLS + 2, a + COLS + 1]))
	update_mesh()

func receive(event: Dictionary):
	if event.type == "cast":
		shot_kind = "shot"
		shot_age = 0.0
		# A fresh input adds energy rather than snapping the pose to frame zero.
		draw_velocity += 3.0 * (1.0 - minf(draw_amount, 1.0))
		if release_left <= 0:
			release_left = 0.11
	elif event.type == "complete" and event.success:
		victory_left = 0.7
	update_mesh()

func advance(dt: float):
	clock += dt
	shot_age += dt
	string_age += dt
	victory_left = maxf(0, victory_left - dt)
	# Substeps keep the damped body/bow springs stable after a slow frame.
	var remaining = minf(dt, 0.25)
	while remaining > 0.000001:
		var step = minf(remaining, 1.0 / 120.0)
		remaining -= step
		var target = 1.0 if release_left > 0 else 0.0
		if release_left > 0:
			release_left -= step
			if release_left <= 0:
				string_age = 0.0
				recoil_velocity -= 4.0
		var acceleration = (target - draw_amount) * 460.0 - draw_velocity * 27.0
		draw_velocity += acceleration * step
		draw_amount += draw_velocity * step
		recoil_velocity += (-recoil * 190.0 - recoil_velocity * 15.0) * step
		recoil += recoil_velocity * step
	update_mesh()

func shot_strength() -> float:
	if not enabled:
		return 0.0
	return clampf(draw_amount, 0, 1.1)

func pose(point: Vector2) -> Vector2:
	var p = Vector2((point.x - 0.5) * aspect, point.y - 1.0)
	if not enabled:
		return p
	var u = point.x
	var v = point.y
	var upper = 1.0 - smoothstep(0.52, 0.98, v)
	var chest = exp(-pow((v - 0.40) / 0.22, 2))
	var hair = (1.0 - smoothstep(0.30, 0.48, u)) * (1.0 - smoothstep(0.4, 0.53, v))
	var cloak = (1.0 - smoothstep(0.2, 0.43, u)) * exp(-pow((v - 0.59) / 0.18, 2))
	var shot = shot_strength()
	var wave = sin(clock * 3.6 - v * 12.0)
	p.x += upper * (sin(clock * 1.7) * 0.003 + recoil * 0.045)
	p.y -= chest * sin(clock * 2.5) * 0.004
	p.x += (hair * 0.009 + cloak * 0.018) * wave
	p.y += (hair + cloak) * sin(clock * 4.0 - u * 9.0) * 0.006
	# Pulling hand and forearm bend about a stable elbow. The bow-holding
	# hand stays planted while the limbs flex around its grip.
	var hand = exp(-pow((u - 0.40) / 0.11, 2) - pow((v - 0.29) / 0.065, 2))
	var forearm = exp(-pow((u - 0.31) / 0.13, 2) - pow((v - 0.30) / 0.06, 2))
	# Keep face vertices outside the arm weights. A coarse, broad mask would
	# drag the cheek with the hand when returning to the relaxed pose.
	var arm_band = smoothstep(0.263, 0.281, v) * (1.0 - smoothstep(0.318, 0.345, v))
	hand *= arm_band
	forearm *= arm_band
	p.x += (hand * 0.075 + forearm * 0.020) * (1.0 - shot) - hand * shot * 0.012
	var bow_mask = smoothstep(0.52, 0.68, u)
	var tips = pow(clampf(absf(v - 0.28) / 0.32, 0, 1), 1.4)
	var bow_region = 1.0 - smoothstep(0.60, 0.65, v)
	p.x -= bow_mask * bow_region * tips * shot * 0.045
	if victory_left > 0:
		p.y -= upper * sin(victory_left / 0.7 * PI) * 0.009
	return p

func update_mesh():
	if not render_mesh:
		return
	var vertices = PackedVector3Array()
	for point in uv:
		var p = pose(point)
		vertices.append(Vector3(p.x, p.y, 0))
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

func bow_position(foot: Vector2, height: float) -> Vector2:
	return foot + pose(Vector2(0.79, 0.285)) * height

func string_points(foot: Vector2, height: float) -> PackedVector2Array:
	var top = foot + pose(Vector2(0.581, 0.008)) * height
	var bottom = foot + pose(Vector2(0.643, 0.609)) * height
	var hand = foot + pose(Vector2(0.412, 0.286)) * height
	var middle = top.lerp(bottom, 0.47)
	# While drawing, the string follows the actual fingertip. On release it
	# snaps to the bow's rest line independently of the recovering arm.
	var pull = (1.0 if release_left > 0 else exp(-string_age * 65.0)) if enabled else 0.0
	var vibration = sin(string_age * 105.0) * exp(-string_age * 13.0) * height * 0.014 if enabled else 0.0
	middle = middle.lerp(hand, pull)
	middle.x += vibration
	return PackedVector2Array([top, middle, bottom])
