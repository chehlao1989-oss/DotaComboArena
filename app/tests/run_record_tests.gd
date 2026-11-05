extends SceneTree
const Records = preload("res://scripts/record_book.gd")
const Store = preload("res://scripts/profile_store.gd")
const Session = preload("res://scripts/arena_session.gd")
const Catalog = preload("res://scripts/hero_catalog.gd")
const Bindings = preload("res://scripts/bindings.gd")
var checks = 0
var failures = 0
func _initialize():
	call_deferred("run")
func expect(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func result(clean: int = 100) -> Dictionary:
	return {"mode":"arena_random","rules":1,"hero_id":"windrunner","hero_name":"Windranger","duration":180,"initial_window":1.8,"item_count":4,"completed_session":true,"elapsed":180,"completed":120,"clean":clean,"wrong":2,"early":1,"missed":2,"ambiguous":0,"samples":clean,"median_ms":320,"best_streak":8,"timestamp":"2026-11-02T18:00:00"}
func run():
	expect(Records.points_values(10,2,1,1)==885,"score rewards clean keys and penalizes errors")
	expect(Records.points_values(0,20,20,20)==0,"score never negative")
	var ctx = Records.context("windrunner",180,1.8,4)
	var r = result()
	expect(Records.eligible(r),"complete supported run qualifies")
	var incomplete = r.duplicate(true)
	incomplete.completed_session = false
	expect(not Records.eligible(incomplete),"manual finish excluded")
	incomplete = r.duplicate(true)
	incomplete.elapsed = 179.9
	expect(not Records.eligible(incomplete),"short elapsed cannot qualify")
	incomplete = r.duplicate(true)
	incomplete.mode = "arena"
	expect(not Records.eligible(incomplete),"old scenarios not mixed with current rules")
	incomplete = r.duplicate(true)
	incomplete.erase("rules")
	expect(not Records.eligible(incomplete),"legacy history without category metadata not promoted")
	var player = {"id":"a","name":"Игрок","sessions":[]}
	var verdict = Records.apply(player,r)
	expect(verdict.first and verdict.new_record and Records.best(player,ctx).score==9835,"first PB created")
	expect(Records.valid_book(player.records),"PB book valid")
	verdict = Records.apply(player,result(90))
	expect(not verdict.new_record and Records.best(player,ctx).clean==100,"weaker run cannot replace PB")
	expect(not Records.apply(player,r).new_record,"identical run not a new PB")
	var better_run = result(105)
	verdict = Records.apply(player,better_run)
	expect(verdict.new_record and verdict.previous.clean==100,"improved score replaces PB with previous value")
	var tie = better_run.duplicate(true)
	tie.completed = 110
	expect(Records.apply(player,tie).new_record,"higher accuracy breaks score tie")
	tie.best_streak = 9
	expect(Records.apply(player,tie).new_record,"higher streak breaks accuracy tie")
	tie.median_ms = 280
	expect(Records.apply(player,tie).new_record,"faster clean reaction breaks final tie")
	tie.samples = 0
	tie.median_ms = 0
	expect(not Records.apply(player,tie).new_record,"missing reaction samples not faster than measured reaction")
	for changed in [Records.context("lina",180,1.8,4),Records.context("windrunner",60,1.8,4),Records.context("windrunner",180,1.2,4),Records.context("windrunner",180,1.8,6)]:
		expect(Records.best(player,changed).is_empty(),"different hero/time/pace/items isolated")
	var second = {"id":"b","name":"Другой игрок","sessions":[]}
	expect(Records.best(second,ctx).is_empty(),"profiles independent")
	Records.apply(second,result(110))
	var ranking = Records.ranking([player,second],ctx)
	expect(ranking.size()==2 and ranking[0].id=="b","local ranking sorts by best result")
	var clone = player.duplicate(true)
	clone.id = "c"
	expect(Records.ranking([clone,player],ctx)[0].id=="a","ties have stable order")
	var decoded = JSON.parse_string(JSON.stringify(player.records))
	expect(Records.valid_book(decoded),"JSON round trip valid including numeric category fields")
	var restored = player.duplicate(true)
	restored.records = decoded
	var same_run = Records.best(restored,ctx)
	same_run.mode = "arena_random"
	same_run.completed_session = true
	same_run.elapsed = 180
	expect(not Records.apply(restored,same_run).new_record,"restart precision cannot produce a fake tied PB")
	var broken = player.records.duplicate(true)
	broken.values()[0].score += 1
	expect(not Records.valid_book(broken),"inconsistent cached score rejected")
	var location = "user://record-tests-"+str(Time.get_ticks_usec())
	var store = Store.new(location)
	expect(store.load_data()=="new","legacy-style profile created")
	store.current().setup_done = true
	store.current().bindings = Bindings.preset(true)
	Records.apply(store.current(),r)
	for i in 51:
		store.current().sessions.append(r.duplicate(true))
		if store.current().sessions.size()>50:
			store.current().sessions.pop_front()
	expect(store.save(),"PB and capped history saved atomically")
	var reopened = Store.new(location)
	expect(reopened.load_data()=="ok","saved records reload")
	expect(reopened.current().sessions.size()==50 and Records.best(reopened.current(),ctx).score==9835,"PB survives history truncation and restart")
	var old = reopened.data.duplicate(true)
	old.profiles[0].erase("records")
	expect(reopened.valid(old),"old profiles with no record book remain valid")
	var session = Session.new()
	session.start(Catalog.new(),Bindings.preset(true),180,1.8,42)
	session.advance(3.01)
	session.advance(0.36)
	var code = int(session.mapping[session.expected()])
	session.press_batch([code])
	session.release(code)
	session.finish()
	expect(not Records.eligible(session.report()),"actual manual stop not eligible")
	session = Session.new()
	session.start(Catalog.new(),Bindings.preset(true),180,1.8,42)
	session.advance(3.01)
	session.advance(0.36)
	code = int(session.mapping[session.expected()])
	session.press_batch([code])
	session.release(code)
	session.elapsed = 179.99
	session.advance(0.02)
	expect(Records.eligible(session.report()),"actual timed completion qualifies")
	session.finish()
	expect(session.report().completed_session,"repeat finish preserves natural completion")
	print("RECORD_TESTS checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
