extends SceneTree
const Animator = preload("res://scripts/hero_animator.gd")
const HERO_TEXTURE = preload("res://assets/arena/windranger-rig.png")
var checks=0
var failures=0
func _initialize():
	call_deferred("run")
func expect(ok: bool, label: String):
	checks+=1
	if not ok:
		failures+=1
		push_error(label)
func run():
	var a=Animator.new(HERO_TEXTURE)
	var foot=Vector2(0.65,1)
	var fixed=a.pose(foot)
	var hair=a.pose(Vector2(0.2,0.23))
	a.advance(0.4)
	expect(a.pose(Vector2(0.2,0.23)).distance_to(hair)>0.001,"idle hair moves")
	expect(a.pose(foot).distance_to(fixed)<0.00001,"boots anchored")
	var neutral=a.string_points(Vector2.ZERO,200)
	var face=a.pose(Vector2(0.43,0.24))
	a.receive({"type":"cast","action":"i1"})
	a.advance(0.08)
	expect(a.draw_amount>0.5,"item key also draws bow")
	expect(a.pose(Vector2(0.43,0.24)).distance_to(face)<0.006,"arm pull does not deform face")
	expect(a.string_points(Vector2.ZERO,200)[1].distance_to(a.pose(Vector2(0.412,0.286))*200)<0.001,"drawing string stays attached to fingers")
	expect(a.string_points(Vector2.ZERO,200)[1].distance_to(neutral[1])>10,"string visibly pulls")
	var before=a.draw_amount
	a.receive({"type":"cast","action":"a1"})
	expect(is_equal_approx(a.draw_amount,before),"retrigger does not snap pose")
	a.advance(0.06)
	expect(a.recoil_velocity<0,"release gives body recoil")
	for i in 180:
		a.advance(1.0/60)
	expect(absf(a.draw_amount)<0.001 and absf(a.recoil)<0.001,"springs settle")
	var finite=true
	for i in 600:
		if i%6==0:
			a.receive({"type":"cast","action":"a2"})
		a.advance(1.0/60)
		finite=finite and is_finite(a.draw_amount) and absf(a.draw_amount)<2 and absf(a.recoil)<2
	expect(finite,"rapid 10 presses/sec stable")
	a.advance(2)
	expect(is_finite(a.draw_amount),"slow frame substeps stay stable")
	a.enabled=false
	var neutral_pose=a.pose(Vector2(0.2,0.23))
	a.advance(0.4)
	expect(a.pose(Vector2(0.2,0.23))==neutral_pose,"motion toggle")
	expect(a.bow_position(Vector2.ZERO,200).is_finite(),"arrow origin valid")
	expect(a.mesh.get_surface_count()==1,"mesh does not accumulate surfaces")
	print("ANIMATION_TESTS checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
