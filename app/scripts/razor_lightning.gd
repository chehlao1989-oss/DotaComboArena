extends Node2D

# Source's rope texture has black RGB around the beam and opaque alpha.
# Additive compositing preserves that native texture without a black rectangle.
var beam = preload("res://assets/arena/razor_native/beam.png")
func _init():
	var shader = Shader.new()
	shader.code = "shader_type canvas_item; render_mode blend_add, unshaded;"
	var mat = ShaderMaterial.new()
	mat.shader = shader
	material = mat
	z_index = 1

func _draw():
	var world = get_parent()
	if world == null or world.hero_id != "razor": return
	for fx in world.effects:
		var age = float(fx.age)
		var origin = Vector2(fx.origin_uv) * world.size
		var end = world.impact_position()
		if age < 0.14:
			# Beam stays attached to the genuine moving whip tip while live.
			if world.hero_animation.enabled: origin = world.emitter_position()
			var fade = 1.0 - age / 0.14
			var delta = end - origin
			var side = delta.normalized().orthogonal()
			var points = PackedVector2Array()
			for i in 10:
				var t = i / 9.0
				var wobble = sin(i * 2.71 + floor(age * 120) * 1.93) * sin(t * PI) * (7 if world.particles_enabled else 2)
				points.append(origin.lerp(end,t) + side * wobble)
			if world.particles_enabled:
				var polygon = PackedVector2Array()
				var uvs = PackedVector2Array()
				var colors = PackedColorArray()
				for sign_value in [-1,1]:
					for j in 10:
						var i = j if sign_value == -1 else 9 - j
						polygon.append(points[i] + side * 13 * sign_value)
						uvs.append(Vector2(0 if sign_value == -1 else 1,i / 9.0))
						colors.append(Color(0.45,0.72,1,fade * 0.85))
				draw_polygon(polygon,colors,uvs,beam)
			draw_polyline(points,Color(0.4,0.7,1,fade * 0.6),3.5,true)
			draw_polyline(points,Color(0.8,0.94,1,fade),1.1,true)
			if world.particles_enabled:
				draw_circle(origin,5,Color(0.4,0.7,1,fade * 0.4))
				draw_circle(end,9,Color(0.35,0.65,1,fade * 0.5))
		elif world.particles_enabled:
			var t = clampf((age - 0.14) / 0.14,0,1)
			for i in 7:
				var dir = Vector2.from_angle(i * TAU / 7)
				var p = end + dir * (3 + 15 * t)
				draw_line(p,p + dir * 4,Color(0.45,0.8,1,1-t),1.2,true)
