extends Node2D

func _init():
 z_index = 1

func _draw():
 var world = get_parent()
 if world == null or world.hero_id != "dark_seer": return
 for fx in world.effects:
  # Contact stays at the actual knuckle, inside the fixed target chest.
  var t = clampf(float(fx.age) / .24,0,1)
  var p = Vector2(fx.origin_uv) * world.size
  if t < .4: draw_circle(p,3,Color(1,.92,1,1-t/.4))
  if not world.particles_enabled: continue
  draw_arc(p,3 + t * 12,0,TAU,24,Color(.88,.70,1,(1-t)*.5),1,true)
  for i in 7:
   var dir = Vector2.from_angle(i * TAU / 7 + .25)
   var start = p + dir * (2 + t * 17)
   draw_line(start,start + dir * (4 - t * 2),Color(.85,.72,.92,1-t),1.2,true)
