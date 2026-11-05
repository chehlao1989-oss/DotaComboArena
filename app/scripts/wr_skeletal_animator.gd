extends RefCounted

# All visible poses are offline renders of the exported Valve skeleton.
# Inputs are scored by ArenaSession; this bounded controller is cosmetic only.
var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/wr_skeletal.json"))
var textures = {}
var state = "idle"
var age = 0.0
var clock = 0.0
var last_input = -10.0
var pending = false
var want_rapid = false
var released = false
var release_events: Array = []
var total_releases = 0
var victory_left = 0.0
var recoil = 0.0
var enabled = true:
	set(value):
		enabled = value
		pending = false
		want_rapid = false
		start("idle")
		release_events.clear()

func _init():
	for key in data.clips:
		textures[key] = load("res://assets/arena/wr_native/" + key + ".png")

func start(next: String):
	state = next
	age = 0
	released = false

func receive(event: Dictionary):
	if event.type == "complete" and event.get("success", false):
		victory_left = 0.7
	if event.type != "cast":
		return
	if not enabled:
		emit_release("attack", 0)
		return
	var fast = clock - last_input < 0.60
	last_input = clock
	if state == "idle":
		start("attack")
	elif state == "rapid_idle":
		start("rapid")
	else:
		pending = true # Saturating latch, never an unbounded queue.
		want_rapid = want_rapid or fast

func frame() -> int:
	return mini(int(age * 30.0 * (1.5 if state == "attack" else 1.0)), int(data.clips[state].frames) - 1) if enabled else 0

func emit_release(clip: String, index: int):
	release_events.append(data.clips[clip].points[index].duplicate())
	total_releases += 1

func advance(dt: float):
	clock += dt
	victory_left = maxf(0, victory_left - dt)
	if not enabled:
		return
	# Substeps preserve a single release even when a display frame skips it.
	var remaining = dt
	while remaining > 0.000001:
		var step = minf(remaining, 1.0 / 120.0)
		remaining -= step
		age += step
		var clip = data.clips[state]
		var rate = 1.5 if state == "attack" else 1.0
		if int(clip.release) >= 0 and not released and age * 30 * rate >= int(clip.release):
			emit_release(state, maxi(0, int(clip.release) - 1))
			released = true
		if age * 30 * rate < int(clip.frames):
			continue
		match state:
			"idle": age = fmod(age, float(clip.frames) / 30.0)
			"attack":
				if pending:
					pending = false
					start("to_rapid" if want_rapid else "attack")
				else:
					want_rapid = false
					start("idle")
			"to_rapid": start("rapid")
			"rapid":
				if pending:
					pending = false
					start("rapid")
				else: start("rapid_idle")
			"rapid_idle":
				if clock - last_input > 0.45: start("from_rapid")
				else: age = 0
			"from_rapid":
				want_rapid = false
				if pending:
					pending = false
					start("attack")
				else: start("idle")

func actor_rect(foot: Vector2, height: float) -> Rect2:
	var pixels = height / float(data.body_height_px) * float(data.cell)
	var uv = Vector2(data.pivot_uv[0], data.pivot_uv[1])
	return Rect2(foot - uv * pixels, Vector2.ONE * pixels)

func emitter_position(foot: Vector2, height: float) -> Vector2:
	var p = data.clips[state].points[frame()].emitter_uv
	var rect = actor_rect(foot, height)
	return rect.position + Vector2(p[0], p[1]) * rect.size

func source_rect() -> Rect2:
	var i = frame()
	return Rect2(Vector2(i % 8, i / 8) * 512, Vector2(512, 512))

func texture() -> Texture2D:
	return textures[state] if enabled else textures.idle

func update_mesh():
	pass # Compatibility with the existing motion toggle; no mesh deformation.
