extends RefCounted

const Bindings = preload("res://scripts/bindings.gd")
var catalog
var mapping = {}
var upgrades: Array = []
var upgrade_notice = ""
var upgrade_history: Array = []
var unlocked_action = ""
var upgrade_granted = false
const Generator = preload("res://scripts/sequence_generator.gd")
const TRANSITION = 0.10
var generator = Generator.new()
var current_sequence: Dictionary = {}
var sequence_length = 2
var base_window = 1.8
var speed = 1.0
var max_speed = 1.0
var block_steps = 0
var block_clean = 0
var block_misses = 0
var bad_run = 0
var ability_presses = 0
var item_presses = 0
var initial_item_count = 0
var completed_session = false
var scenario_index = 0
var step_index = 0
var phase = "idle"
var initial_countdown = true
var resume_phase = "briefing"
var phase_left = 0.0
var elapsed = 0.0
var duration = 180.0
var response_window = 1.8
var reaction_clock = 0.0
var completed = 0
var clean = 0
var wrong = 0
var early = 0
var missed = 0
var ambiguous = 0
var combos = 0
var successful_combos = 0
var streak = 0
var best_streak = 0
var dirty_step = false
var dirty_combo = false
var round_in_progress = false
var reactions: Array = []
var held = {}
var events: Array = []
var feedback = ""
var feedback_good = true
var casting_action = ""
var scenario_results = {}
var mistakes = {}

func start(hero_catalog, profile_map: Dictionary, seconds: float = 180.0, window: float = 1.8, seed_value: int = -1) -> bool:
	catalog = hero_catalog
	mapping = profile_map.duplicate(true)
	var pool = catalog.action_pool(mapping)
	if pool.abilities.is_empty():
		return false
	generator.configure(pool, seed_value)
	initial_item_count = pool.items.size()
	current_sequence = generator.next_sequence(sequence_length)
	base_window = window
	duration = seconds
	response_window = window
	phase = "countdown"
	phase_left = 3.0
	resume_phase = "briefing"
	events.append({"type":"round", "scenario":scenario().id})
	return true

func scenario() -> Dictionary:
	return current_sequence

func expected() -> String:
	var steps = scenario().get("steps", [])
	return str(steps[step_index]) if step_index < steps.size() else ""

func enter_briefing():
	phase = "briefing"
	phase_left = 0.35
	step_index = 0
	dirty_step = false
	dirty_combo = false
	round_in_progress = false
	casting_action = ""
	feedback = "Следуй подсветке: по одной клавише за раз."
	feedback_good = true
	events.append({"type":"round", "scenario":scenario().id})

func open_window():
	phase = "active"
	phase_left = response_window
	reaction_clock = 0.0
	dirty_step = false
	round_in_progress = true
	events.append({"type":"ready", "action":expected()})

func advance(dt: float):
	if dt <= 0 or phase in ["idle", "paused", "finished"]:
		return
	if phase == "countdown":
		phase_left -= dt
		if phase_left <= 0:
			if initial_countdown:
				initial_countdown = false
				enter_briefing()
			else:
				phase = resume_phase
				phase_left = saved_phase_left
		return
	var used = minf(dt, duration - elapsed)
	elapsed += used
	if elapsed >= duration:
		finish(true)
		return
	phase_left -= used
	if phase == "active":
		reaction_clock += used
	if phase_left > 0:
		return
	match phase:
		"briefing":
			open_window()
		"active":
			completed += 1
			missed += 1
			dirty_combo = true
			feedback = "Не успел. Следующая последовательность."
			register_step(false, true)
			feedback_good = false
			end_round(false)
		"casting":
			events.append({"type":"resolve", "action":casting_action})
			step_index += 1
			if step_index >= scenario().steps.size():
				end_round(not dirty_combo)
			else:
				open_window()
		"resolution":
			scenario_index += 1
			apply_due_upgrades()
			current_sequence = generator.next_sequence(sequence_length, unlocked_action)
			unlocked_action = ""
			enter_briefing()
			if upgrade_granted:
				phase_left = 2.5
				feedback = upgrade_notice

func press_batch(codes: Array, force_ambiguous: bool = false):
	var fresh: Array = []
	for code in codes:
		if not held.has(code):
			fresh.append(code)
			held[code] = true
	if fresh.is_empty() or phase in ["idle", "paused", "finished", "countdown", "briefing", "resolution"]:
		return
	if force_ambiguous or fresh.size() > 1 or held.size() > 1:
		wrong += 1
		ambiguous += 1
		dirty_step = true
		dirty_combo = true
		feedback = "Отпусти кнопки и нажми одну."
		feedback_good = false
		return
	if phase == "casting":
		early += 1
		dirty_combo = true
		feedback = "Дождись следующей подсветки."
		feedback_good = false
		return
	var code = int(fresh[0])
	var action = Bindings.action_for(code, mapping)
	if action != expected():
		wrong += 1
		dirty_step = true
		dirty_combo = true
		var pair = Bindings.key_name(code) + " вместо " + Bindings.key_name(int(mapping[expected()]))
		mistakes[pair] = int(mistakes.get(pair, 0)) + 1
		feedback = "Нужен %s — %s" % [Bindings.key_name(int(mapping[expected()])), catalog.action_name(expected())]
		feedback_good = false
		events.append({"type":"error"})
		return
	completed += 1
	if not dirty_step:
		clean += 1
		reactions.append(reaction_clock * 1000.0)
	casting_action = action
	phase = "casting"
	phase_left = TRANSITION
	register_step(not dirty_step, false)
	if action.begins_with("a"):
		ability_presses += 1
	else:
		item_presses += 1
	feedback = catalog.action_name(action)
	feedback_good = true
	events.append({"type":"cast", "action":action, "duration":phase_left})

func end_round(success: bool):
	combos += 1
	round_in_progress = false
	var id = str(scenario().steps.size())
	if not scenario_results.has(id):
		scenario_results[id] = {"title":"%s клавиш" % id, "attempts":0, "success":0}
	scenario_results[id].attempts += 1
	if success:
		successful_combos += 1
		scenario_results[id].success += 1
		streak += 1
		best_streak = maxi(best_streak, streak)
		feedback = "Чистая последовательность!"
		feedback_good = true
	else:
		streak = 0
		if feedback_good:
			feedback = "Последовательность завершена."
			feedback_good = false
	phase = "resolution"
	phase_left = 0.25
	events.append({"type":"complete", "success":success})

func apply_due_upgrades():
	upgrade_granted = false
	if duration < 180.0:
		return
	var order = catalog.data.get("upgrade_order", ["scepter", "shard"])
	for index in order.size():
		var kind = str(order[index])
		if elapsed < 60.0 * (index + 1) or kind in upgrades:
			continue
		upgrades.append(kind)
		upgrade_granted = true
		var pool = catalog.action_pool(mapping, upgrades)
		var added: Array = []
		for action in pool.abilities:
			if not action in generator.abilities:
				added.append(action)
		generator.abilities = pool.abilities.duplicate()
		upgrade_notice = "Получен Aghanim’s " + ("Scepter" if kind == "scepter" else "Shard")
		if not added.is_empty():
			unlocked_action = str(added[0])
			upgrade_notice += " · новая клавиша " + Bindings.key_name(int(mapping[unlocked_action]))
		else:
			upgrade_notice += " · без новой активной кнопки"
		upgrade_history.append({"upgrade":kind, "elapsed":elapsed, "actions":added})
		events.append({"type":"upgrade", "text":upgrade_notice})

func register_step(good: bool, timeout: bool):
	block_steps += 1
	block_clean += 1 if good else 0
	block_misses += 1 if timeout else 0
	bad_run = 0 if good else bad_run + 1
	if bad_run >= 3:
		speed = maxf(0.6, speed - 0.1)
		bad_run = 0
	if block_steps >= 20:
		var accuracy = float(block_clean) / block_steps
		if accuracy >= 0.95 and block_misses == 0:
			speed = minf(2.0, speed + 0.05)
			sequence_length = mini(5, sequence_length + 1)
		elif accuracy < 0.8:
			speed = maxf(0.6, speed - 0.1)
			sequence_length = maxi(2, sequence_length - 1)
		block_steps = 0
		block_clean = 0
		block_misses = 0
	max_speed = maxf(max_speed, speed)
	response_window = maxf(0.45, base_window / speed)

func release(code: int):
	held.erase(code)

var saved_phase_left = 0.0
func pause():
	if phase in ["idle", "paused", "finished"]:
		return
	if phase != "countdown":
		resume_phase = phase
		saved_phase_left = phase_left
	phase = "paused"
	held.clear()

func resume():
	if phase != "paused":
		return
	phase = "countdown"
	phase_left = 3.0
	held.clear()

func finish(natural: bool = false):
	if phase == "finished":
		return
	completed_session = natural
	phase = "finished"
	events.append({"type":"finish"})
	held.clear()

func report() -> Dictionary:
	var samples = reactions.duplicate()
	samples.sort()
	var median = 0.0
	var p90 = 0.0
	if not samples.is_empty():
		var center = int(samples.size() / 2.0)
		median = samples[center] if samples.size() % 2 else (samples[center - 1] + samples[center]) / 2.0
		p90 = samples[mini(samples.size() - 1, ceili(samples.size() * 0.9) - 1)]
	return {"mode":"arena_random", "rules":1, "duration":duration, "initial_window":base_window, "item_count":initial_item_count, "completed_session":completed_session, "hero_name":catalog.data.name, "upgrades":upgrades.duplicate(), "upgrade_history":upgrade_history.duplicate(true), "speed":speed, "max_speed":max_speed, "sequence_length":sequence_length, "ability_presses":ability_presses, "item_presses":item_presses, "hero_id":catalog.data.hero_id, "completed":completed, "clean":clean, "wrong":wrong, "early":early, "missed":missed, "ambiguous":ambiguous, "elapsed":minf(elapsed, duration), "median_ms":median, "p90_ms":p90, "samples":samples.size(), "combos":combos, "successful_combos":successful_combos, "best_streak":best_streak, "unfinished_combo":round_in_progress, "response_window":response_window, "scenario_results":scenario_results.duplicate(true), "mistakes":mistakes.duplicate(true)}
