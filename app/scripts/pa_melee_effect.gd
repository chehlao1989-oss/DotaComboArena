extends Node2D

var trail = preload("res://assets/arena/pa_native/blade-trail.png")
func _init():
	var shader = Shader.new()
	shader.code = "shader_type canvas_item; render_mode blend_add, unshaded;"
	var mat = ShaderMaterial.new()
	mat.shader = shader
	material = mat
	z_index = 1

func _draw():
	var world = get_parent()
	if world == null or world.hero_id != "phantom_assassin": return
	var anim = world.hero_animation
	if world.particles_enabled and anim.enabled and anim.state != "idle":
		var index = anim.frame()
		var clip = anim.data.clips[anim.state]
		if index >= 6 and index <= 12:
			var rect = anim.actor_rect(world.hero_foot(),world.size.y * 0.45)
			for i in range(maxi(1,index - 2),index + 1):
				var a = clip.points[i - 1]
				var b = clip.points[i]
				var tip_a = rect.position + Vector2(a.blade_tip_uv[0],a.blade_tip_uv[1]) * rect.size
				var tip_b = rect.position + Vector2(b.blade_tip_uv[0],b.blade_tip_uv[1]) * rect.size
				var grip_a = rect.position + Vector2(a.blade_grip_uv[0],a.blade_grip_uv[1]) * rect.size
				var grip_b = rect.position + Vector2(b.blade_grip_uv[0],b.blade_grip_uv[1]) * rect.size
				# Only a brief ghost of the actual blade trajectory, never a projectile.
				var alpha = 0.10 + 0.04 * (i - maxi(1,index - 2))
				var grip = (grip_a + grip_b) * .5
				if absf((tip_a - grip).cross(tip_b - grip)) < .05: continue
				var points = PackedVector2Array([grip,tip_a,tip_b])
				var colors = PackedColorArray([Color(1,.98,.7,0),Color(1,.98,.7,alpha),Color(1,.98,.7,alpha)])
				draw_polygon(points,colors,PackedVector2Array([Vector2(0,.5),Vector2(1,0),Vector2(1,1)]),trail)
	for fx in world.effects:
		var t = clampf(float(fx.age) / 0.24,0,1)
		var p = world.impact_position()
		if t < .4: draw_circle(p,3,Color(.9,.98,1,1-t/.4))
		if not world.particles_enabled: continue
		for i in 6:
			var dir = Vector2.from_angle(i * TAU / 6 + .4)
			var start = p + dir * (2 + t * 14)
			draw_line(start,start + dir * (4 - t * 2),Color(.65,.86,.8,1-t),1.1,true)
