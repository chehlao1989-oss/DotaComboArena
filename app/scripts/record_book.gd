extends RefCounted

const HEROES = ["windrunner", "razor", "lina", "phantom_assassin", "dark_seer"]
const RULES = 1

static func points_values(clean: int, wrong: int, early: int, missed: int) -> int:
	return maxi(0, clean * 100 - wrong * 25 - early * 15 - missed * 50)

static func points(result: Dictionary) -> int:
	return points_values(int(result.get("clean", 0)), int(result.get("wrong", 0)), int(result.get("early", 0)), int(result.get("missed", 0)))

static func context(hero: String, seconds: float, window: float, items: int) -> Dictionary:
	return {"hero_id":hero, "duration":roundi(seconds), "initial_window":window, "item_count":items, "rules":RULES}

static func key(ctx: Dictionary) -> String:
	return "%s|%d|%d|%d|v%d" % [ctx.hero_id, roundi(float(ctx.duration)), roundi(float(ctx.initial_window) * 1000), int(ctx.item_count), int(ctx.rules)]

static func valid_context(ctx: Dictionary) -> bool:
	if not ctx.get("hero_id", "") in HEROES:
		return false
	# JSON loads numbers as floats; validate integrality before comparing IDs.
	for field in ["rules", "duration", "item_count"]:
		var value = ctx.get(field)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floor(float(value)):
			return false
	if int(ctx.rules) != RULES or not int(ctx.duration) in [60,180,300] or int(ctx.item_count) < 0 or int(ctx.item_count) > 6:
		return false
	var window = ctx.get("initial_window")
	return (window is int or window is float) and is_finite(float(window)) and roundi(float(window) * 1000) in [1200,1800,2600]

static func eligible(result: Dictionary) -> bool:
	return result.get("mode") == "arena_random" and result.get("completed_session", false) == true and valid_context(result) and float(result.get("elapsed", 0)) + 0.001 >= float(result.get("duration", 1)) and int(result.get("completed", 0)) > 0

static func best(profile: Dictionary, ctx: Dictionary) -> Dictionary:
	return profile.get("records", {}).get(key(ctx), {}).duplicate(true)

static func better(a: Dictionary, b: Dictionary) -> bool:
	if b.is_empty():
		return true
	if int(a.score) != int(b.score):
		return int(a.score) > int(b.score)
	# Compare exact fractions so JSON's display precision cannot invent a PB.
	var accuracy_a = int(a.clean) * int(b.completed)
	var accuracy_b = int(b.clean) * int(a.completed)
	if accuracy_a != accuracy_b:
		return accuracy_a > accuracy_b
	if int(a.best_streak) != int(b.best_streak):
		return int(a.best_streak) > int(b.best_streak)
	var reaction_a = float(a.median_ms) if int(a.samples) > 0 else INF
	var reaction_b = float(b.median_ms) if int(b.samples) > 0 else INF
	return reaction_a + 0.001 < reaction_b

static func apply(profile: Dictionary, result: Dictionary) -> Dictionary:
	var verdict = {"eligible":eligible(result), "new_record":false, "first":false, "previous":{}, "current":{}}
	if not verdict.eligible:
		return verdict
	var record = context(str(result.hero_id), float(result.duration), float(result.initial_window), int(result.item_count))
	for field in ["hero_name","clean","completed","wrong","early","missed","median_ms","samples","best_streak","timestamp"]:
		record[field] = result.get(field, "" if field in ["hero_name","timestamp"] else 0)
	record["score"] = points(result)
	record["accuracy"] = 100.0 * float(record.clean) / maxi(1, int(record.completed))
	verdict.previous = best(profile, record)
	verdict.current = record
	verdict.first = verdict.previous.is_empty()
	verdict.new_record = better(record, verdict.previous)
	if verdict.new_record:
		if not profile.has("records"):
			profile.records = {}
		profile.records[key(record)] = record.duplicate(true)
	return verdict

static func ranking(profiles: Array, ctx: Dictionary) -> Array:
	var rows: Array = []
	for profile in profiles:
		var record = best(profile, ctx)
		if not record.is_empty():
			rows.append({"id":profile.id, "name":profile.name, "record":record})
	rows.sort_custom(func(a,b):
		if better(a.record,b.record):
			return true
		if better(b.record,a.record):
			return false
		return str(a.id) < str(b.id))
	return rows

static func valid_book(book: Variant) -> bool:
	if not book is Dictionary or book.size() > 2048:
		return false
	for id in book:
		var record = book[id]
		if not record is Dictionary or not valid_context(record) or str(id) != key(record):
			return false
		if not record.get("hero_name") is String or not record.get("timestamp") is String:
			return false
		for field in ["score","accuracy","best_streak","clean","completed","wrong","early","missed","median_ms","samples"]:
			var value = record.get(field)
			if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0:
				return false
		if int(record.completed) <= 0 or int(record.clean) > int(record.completed) or not is_equal_approx(float(record.accuracy), 100.0 * float(record.clean) / float(record.completed)) or int(record.score) != points(record):
			return false
	return true
