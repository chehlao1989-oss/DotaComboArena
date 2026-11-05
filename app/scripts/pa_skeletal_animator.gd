extends RefCounted

# Genuine Phantom Assassin attacks, 63-bone rig; cosmetic scheduling only.
# Cosmetic scheduling only: ArenaSession still scores the input immediately.
var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pa_skeletal.json"))
var textures = {}
var state = "idle"
var age = 0.0
var clock = 0.0
var last_input = -10.0
var pending = false
var rapid_requested = false
var rate = 1.0
var released = false
var contact_hold_left = 0.0
var next_swing = "a"
var total_releases = 0
var release_events: Array = []
var victory_left = 0.0
var recoil = 0.0
var enabled = true:
	set(value):
		enabled = value
		pending = false
		rapid_requested = false
		last_input = -10.0
		state = "idle"
		age = 0
		rate = 1
		contact_hold_left = 0
		release_events.clear()

func _init():
	for key in data.clips:
		textures[key] = load("res://assets/arena/pa_native/" + key + ".png")

func begin_attack(fast: bool):
	state = "attack_" + next_swing
	next_swing = "b" if next_swing == "a" else "a"
	age = 0
	rate = 2.8 if fast else 1.8
	released = false
	contact_hold_left = 0

func receive(event: Dictionary):
	if event.type == "complete" and event.get("success", false): victory_left = 0.7
	if event.type != "cast": return
	if not enabled:
		var point = data.clips.idle.points[0].duplicate()
		release_events.append(point)
		total_releases += 1
		return
	var fast = clock - last_input < 0.60
	last_input = clock
	if state == "idle": begin_attack(fast)
	else:
		pending = true # One latch, no growing list of attacks.
		rapid_requested = rapid_requested or fast

func frame() -> int:
	if contact_hold_left > 0: return int(data.clips[state].release)
	return mini(int(age * 30.0 * rate), int(data.clips[state].frames) - 1) if enabled else 0

func advance(dt: float):
	clock += dt
	victory_left = maxf(0,victory_left-dt)
	if not enabled: return
	var remaining = dt
	while remaining > 0.000001:
		var step = minf(remaining,1.0 / 120)
		remaining -= step
		if contact_hold_left > 0:
			contact_hold_left = maxf(0,contact_hold_left - step)
			continue
		age += step
		var clip = data.clips[state]
		if int(clip.release) >= 0 and not released and age * 30 * rate >= int(clip.release):
			release_events.append(clip.points[int(clip.release)].duplicate())
			total_releases += 1
			released = true
			age = float(clip.release) / (30 * rate)
			contact_hold_left = 1.0 / 30
		if age * 30 * rate < int(clip.frames): continue
		if state == "idle": age = fmod(age,float(clip.frames) / 30)
		elif pending:
			pending = false
			begin_attack(rapid_requested)
			rapid_requested = false
		else:
			state = "idle"
			age = 0
			rate = 1

func actor_rect(foot: Vector2, height: float) -> Rect2:
	var side = height / float(data.body_height_px) * float(data.cell)
	return Rect2(foot - Vector2(data.pivot_uv[0],data.pivot_uv[1]) * side,Vector2.ONE * side)

func emitter_position(foot: Vector2, height: float) -> Vector2:
	var p = data.clips[state].points[frame()].emitter_uv
	var rect = actor_rect(foot,height)
	return rect.position + Vector2(p[0],p[1]) * rect.size

func source_rect() -> Rect2:
	var i = frame()
	return Rect2(Vector2(i % 8,i / 8) * 512,Vector2(512,512))

func texture() -> Texture2D:
	return textures[state]

func update_mesh(): pass
