extends RefCounted

var rng = RandomNumberGenerator.new()
var abilities: Array = []
var items: Array = []
var item_bag: Array = []
var item_credit = 0.0
var last_action = ""
var last_sequence: Array = []
var number = 0

func configure(pool: Dictionary, seed_value: int = -1):
	abilities = pool.abilities.duplicate()
	items = pool.items.duplicate()
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value

func next_item() -> String:
	if item_bag.is_empty():
		item_bag = items.duplicate()
		for i in range(item_bag.size() - 1, 0, -1):
			var j = rng.randi_range(0, i)
			var swap = item_bag[i]
			item_bag[i] = item_bag[j]
			item_bag[j] = swap
	return str(item_bag.pop_back())

func next_sequence(length: int, required_action: String = "") -> Dictionary:
	length = clampi(length, 2, 5)
	item_credit += length * 0.2 if not items.is_empty() else 0.0
	var has_item = item_credit >= 0.999999
	if has_item:
		item_credit -= 1.0
	var item_position = rng.randi_range(1, length - 1) if has_item else -1
	var item = next_item() if has_item else ""
	var steps: Array = []
	for attempt in 12:
		steps.clear()
		var previous = last_action
		for i in length:
			var action = item
			if i != item_position:
				var choices = abilities.filter(func(a): return a != previous)
				if choices.is_empty():
					choices = abilities
				action = str(choices[rng.randi_range(0, choices.size() - 1)])
			steps.append(action)
			previous = action
		if steps != last_sequence or abilities.size() < 2:
			break
	if not required_action.is_empty() and required_action in abilities and not required_action in steps:
		steps[0] = required_action
	last_sequence = steps.duplicate()
	last_action = str(steps.back())
	number += 1
	return {"id":"sequence_%d" % number, "title":"Последовательность %d" % number, "steps":steps}
