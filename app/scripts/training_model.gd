extends RefCounted

var phase = "idle"
var previous_phase = ""
var countdown_left = 0.0
var gate_left = 0.0
var window_left = 0.0
var elapsed = 0.0
var duration = 30.0
var steps: Array = []
var step_index = 0
var completed = 0
var clean = 0
var wrong = 0
var early = 0
var missed = 0
var ambiguous = 0
var dirty = false
var reactions: Array = []
var message = ""
var message_good = false
var held = {}

func start(actions: Array, seconds: float = 30.0):
	steps = actions.duplicate()
	duration = seconds
	elapsed = 0.0
	step_index = 0
	completed = 0
	clean = 0
	wrong = 0
	early = 0
	missed = 0
	ambiguous = 0
	reactions.clear()
	held.clear()
	dirty = false
	message = ""
	phase = "countdown"
	countdown_left = 3.0
	previous_phase = "active"
	window_left = 1.8

func expected() -> String:
	return str(steps[step_index % steps.size()]) if not steps.is_empty() else ""

func advance(dt: float):
	if phase == "paused" or phase == "finished" or phase == "idle":
		return
	if phase == "countdown":
		countdown_left -= dt
		if countdown_left <= 0:
			phase = previous_phase
		return
	elapsed += dt
	if elapsed >= duration:
		phase = "finished"
		return
	if phase == "gate":
		gate_left -= dt
		if gate_left <= 0:
			phase = "active"
			window_left = 1.8
		return
	window_left -= dt
	if window_left <= 0:
		missed += 1
		completed += 1
		message = "Окно пропущено. Следующая попытка."
		message_good = false
		step_index = int(step_index / 4.0 + 1) * 4
		next_gate()

func next_gate():
	dirty = false
	gate_left = 0.38
	phase = "gate"

func press_batch(codes: Array, mapping: Dictionary):
	var fresh: Array = []
	for code in codes:
		if not held.has(code):
			fresh.append(code)
			held[code] = true
	if fresh.is_empty():
		return
	if phase != "active" and phase != "gate":
		return
	if fresh.size() > 1 or held.size() > 1:
		ambiguous += 1
		wrong += 1
		dirty = true
		message = "Несколько клавиш: отпустите их и нажмите одну."
		message_good = false
		return
	if phase == "gate":
		early += 1
		dirty = true
		message = "Рано: дождитесь сигнала готовности."
		message_good = false
		return
	var action = preload("res://scripts/bindings.gd").action_for(int(fresh[0]), mapping)
	if action != expected():
		wrong += 1
		dirty = true
		message = "Нужен %s; нажат %s" % [preload("res://scripts/bindings.gd").key_name(int(mapping[expected()])), preload("res://scripts/bindings.gd").key_name(int(fresh[0]))]
		message_good = false
		return
	completed += 1
	if not dirty:
		clean += 1
		reactions.append(maxf(0, (1.8 - window_left) * 1000.0))
	message = "Верно — " + preload("res://scripts/bindings.gd").title(action)
	message_good = true
	step_index += 1
	next_gate()

func release(code: int):
	held.erase(code)

func pause():
	if phase in ["active", "gate", "countdown"]:
		if phase != "countdown":
			previous_phase = phase
		phase = "paused"
		held.clear()

func resume():
	if phase == "paused":
		phase = "countdown"
		countdown_left = 3.0
		held.clear()

func report() -> Dictionary:
	var sorted = reactions.duplicate()
	sorted.sort()
	var median = 0.0
	if not sorted.is_empty():
		var middle = int(sorted.size() / 2.0)
		median = sorted[middle] if sorted.size() % 2 else (sorted[middle - 1] + sorted[middle]) / 2.0
	return {"completed": completed, "clean": clean, "wrong": wrong, "early": early, "missed": missed, "ambiguous": ambiguous, "elapsed": minf(duration, elapsed), "median_ms": median, "samples": reactions.size()}
