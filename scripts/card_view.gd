extends Control
const FantasySkin = preload("res://scripts/material_skin.gd")
signal pressed(uid)
signal hover_changed(uid, active)
signal drag_started(uid)
signal dragged(uid, point)
signal released(uid, point)

var card: Dictionary = {}
var definition: Dictionary = {}
var art_texture: Texture2D
var card_font: Font
var interactive := true
var drag_enabled := true
var selected := false
var available := true
var hover := false
var drag_active := false
var face_down := false:
 set(value):
  face_down=value
  queue_redraw()
var base_position := Vector2.ZERO
var base_rotation := 0.0
var index := 0
var shine := 0.0
var card_size := Vector2(170,258)
var gold := Color("c6a877")
var rarity := Color("c6a877")

# Layout is opt-in. A fresh CardView is safe for VFX to flip, scale and fly.
# Spring velocities survive target changes; there are no layout Tweens.
var _layout_active := false
var _spring_active := false
var _arriving := true
var _destination := Vector2.ZERO
var _destination_angle := 0.0
var _destination_scale := Vector2.ONE
var _position_velocity := Vector2.ZERO
var _rotation_velocity := 0.0
var _scale_velocity := Vector2.ZERO
var _delay_remaining := 0.0
var _down := false
var _press_point := Vector2.ZERO
var _press_grab := Vector2.ZERO
var _press_grab_available := false
var _grab_local := Vector2.ZERO
var _pointer := Vector2.ZERO
var _pointer_velocity := Vector2.ZERO
var _art_region := Rect2()
var _cached_text_lines: Array[String] = []
var _layout_text := ""
var _layout_font: Font
var _layout_width := -1.0
var _text_layout_ready := false
var _text_layout_generation := 0

func setup(c: Dictionary, d: Dictionary, tex: Texture2D, font: Font) -> void:
 card=c.duplicate(true)
 definition=d.duplicate(true)
 art_texture=tex
 card_font=font
 size=card_size
 custom_minimum_size=card_size
 pivot_offset=Vector2(card_size.x/2,card_size.y-15)
 var art_index=int(d.get("art",0))
 if tex:
  var tile=tex.get_size()/Vector2(4,2)
  _art_region=Rect2(Vector2(art_index%4,floori(art_index/4.0))*tile,tile)
 rarity={"common":Color("bc9e71"),"uncommon":Color("7db8ca"),"rare":Color("c1a1de")}.get(d.get("rarity","common"),gold)
 mouse_filter=Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
 _update_text_layout()
 queue_redraw()

func _ready() -> void:
 mouse_entered.connect(_on_enter)
 mouse_exited.connect(_on_exit)
 set_process(_spring_active or drag_active or shine>0.0)

func _wake() -> void:
 set_process(true)

func _on_enter() -> void:
 if not interactive: return
 hover=true
 shine=0.7
 _wake()
 if _layout_active and not drag_active: move_to(base_position,base_rotation,true,0.0)
 hover_changed.emit(str(card.get("uid","")),true)
 queue_redraw()

func _on_exit() -> void:
 hover=false
 if not drag_active:
  if _layout_active: move_to(base_position,base_rotation,true,0.0)
  hover_changed.emit(str(card.get("uid","")),false)
 queue_redraw()

func move_to(point: Vector2, angle: float, animated: bool=true, delay: float=-1.0) -> void:
 base_position=point
 base_rotation=angle
 _layout_active=true
 if drag_active: return
 var raised=hover or selected
 var destination=point-Vector2(0,86 if raised else 0)
 var target_angle=0.0 if raised else angle
 var target_scale=Vector2.ONE*(1.16 if raised else 1.0)
 var same=_spring_active and destination.is_equal_approx(_destination) and is_equal_approx(target_angle,_destination_angle) and target_scale.is_equal_approx(_destination_scale)
 _destination=destination
 _destination_angle=target_angle
 _destination_scale=target_scale
 if not animated:
  position=destination
  rotation=target_angle
  scale=target_scale
  _position_velocity=Vector2.ZERO
  _rotation_velocity=0.0
  _scale_velocity=Vector2.ZERO
  _delay_remaining=0.0
  _spring_active=false
  _arriving=false
  queue_redraw()
  return
 if same: return
 _delay_remaining=maxf(0.0,delay) if delay>=0.0 else minf(index*0.035,0.245) if _arriving else 0.0
 _arriving=false
 _spring_active=true
 _wake()

# Exact solution of an underdamped harmonic oscillator. Unlike Euler or a
# visual ease curve, this stays finite at variable frame rates and carries
# momentum when a target changes halfway through a return animation.
static func _spring(value: float, velocity: float, target: float, omega: float, damping: float, delta: float) -> Vector2:
 if delta<=0.0: return Vector2(value,velocity)
 var displacement=value-target
 var decay=exp(-damping*omega*delta)
 var frequency=omega*sqrt(maxf(0.0001,1.0-damping*damping))
 var phase=frequency*delta
 var coefficient=(velocity+damping*omega*displacement)/frequency
 var wave=displacement*cos(phase)+coefficient*sin(phase)
 var next_value=target+decay*wave
 var next_velocity=decay*(-damping*omega*wave+frequency*(-displacement*sin(phase)+coefficient*cos(phase)))
 return Vector2(next_value,next_velocity)

func _process(delta: float) -> void:
 var dt=maxf(0.0,delta)
 if shine>0.0:
  shine=maxf(0.0,shine-dt*1.9)
  queue_redraw()
 if drag_active:
  _pointer_velocity*=exp(-dt*7.0)
  var tilt=clampf(_pointer_velocity.x*0.000047,-0.115,0.115)
  var angular=_spring(rotation,_rotation_velocity,tilt,20.0,0.78,dt)
  rotation=angular.x
  _rotation_velocity=angular.y
  var sx=_spring(scale.x,_scale_velocity.x,1.09,25.0,0.76,dt)
  var sy=_spring(scale.y,_scale_velocity.y,1.09,25.0,0.76,dt)
  scale=Vector2(sx.x,sy.x)
  _scale_velocity=Vector2(sx.y,sy.y)
  _pin_grab()
  queue_redraw()
  return
 if _spring_active:
  if _delay_remaining>0.0:
   var wait_time=minf(dt,_delay_remaining)
   _delay_remaining-=wait_time
   dt-=wait_time
  if dt>0.0:
   var px=_spring(position.x,_position_velocity.x,_destination.x,18.5,0.72,dt)
   var py=_spring(position.y,_position_velocity.y,_destination.y,18.5,0.72,dt)
   position=Vector2(px.x,py.x)
   _position_velocity=Vector2(px.y,py.y)
   var angle=_spring(rotation,_rotation_velocity,_destination_angle,22.0,0.73,dt)
   rotation=angle.x
   _rotation_velocity=angle.y
   var sx=_spring(scale.x,_scale_velocity.x,_destination_scale.x,25.0,0.74,dt)
   var sy=_spring(scale.y,_scale_velocity.y,_destination_scale.y,25.0,0.74,dt)
   scale=Vector2(sx.x,sy.x)
   _scale_velocity=Vector2(sx.y,sy.y)
   if position.distance_to(_destination)<0.035 and _position_velocity.length()<0.08 and absf(rotation-_destination_angle)<0.0003 and absf(_rotation_velocity)<0.002 and scale.distance_to(_destination_scale)<0.0004 and _scale_velocity.length()<0.002:
    position=_destination
    rotation=_destination_angle
    scale=_destination_scale
    _position_velocity=Vector2.ZERO
    _rotation_velocity=0.0
    _scale_velocity=Vector2.ZERO
    _spring_active=false
   queue_redraw()
 if not _spring_active and shine<=0.0: set_process(false)

func _remember_press(pointer: Vector2) -> void:
 _press_point=pointer
 _press_grab=get_global_transform().affine_inverse()*pointer
 _press_grab_available=true

func begin_drag(pointer: Vector2) -> void:
 if drag_active:
  follow_pointer(pointer,0.0)
  return
 _grab_local=_press_grab if _press_grab_available else get_global_transform().affine_inverse()*pointer
 _pointer=pointer
 _pointer_velocity=Vector2.ZERO
 _position_velocity=Vector2.ZERO
 _delay_remaining=0.0
 _spring_active=false
 drag_active=true
 _pin_grab()
 _wake()
 queue_redraw()

func follow_pointer(pointer: Vector2, delta: float=0.0) -> void:
 if not drag_active: return
 var dt=delta if delta>0.0 else get_process_delta_time()
 dt=clampf(dt,1.0/240.0,0.1)
 var displacement=pointer-_pointer
 if displacement.length_squared()>0.0001:
  var raw_velocity=(displacement/dt).limit_length(4200.0)
  _pointer_velocity=_pointer_velocity.lerp(raw_velocity,1.0-exp(-dt*32.0))
 _pointer=pointer
 # Translation is solved immediately. Only angle/scale carry inertia.
 _pin_grab()
 queue_redraw()

func _pin_grab() -> void:
 var actual_grab=get_global_transform()*_grab_local
 global_position+=_pointer-actual_grab

func end_drag() -> void:
 if not drag_active: return
 drag_active=false
 _down=false
 _press_grab_available=false
 _pointer_velocity=Vector2.ZERO
 if _layout_active: move_to(base_position,base_rotation,true,0.0)
 else:
  _spring_active=false
  set_process(shine>0.0)
 queue_redraw()

func set_selected(value: bool) -> void:
 if selected==value: return
 selected=value
 if _layout_active and not drag_active: move_to(base_position,base_rotation,true,0.0)
 queue_redraw()

func set_available(value: bool) -> void:
 if available==value: return
 available=value
 queue_redraw()

func set_face_down(value: bool) -> void:
 face_down=value

func _gui_input(event: InputEvent) -> void:
 if not interactive: return
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if event.pressed:
   _down=true
   _remember_press(get_global_mouse_position())
   pressed.emit(str(card.get("uid","")))
  else:
   _down=false
   released.emit(str(card.get("uid","")),get_global_mouse_position())
   if drag_active: end_drag()
   _press_grab_available=false
  accept_event()
 elif event is InputEventMouseMotion and _down and drag_enabled:
  var point=get_global_mouse_position()
  if not drag_active and point.distance_to(_press_point)>8.0:
   begin_drag(point)
   drag_started.emit(str(card.get("uid","")))
  if drag_active:
   follow_pointer(point,get_process_delta_time())
   dragged.emit(str(card.get("uid","")),point)
  accept_event()

func force_release() -> void:
 _down=false
 _press_grab_available=false
 if drag_active: end_drag()

func _box(rect: Rect2, color: Color, border: Color, width: int, radius: int) -> void:
 var style=StyleBoxFlat.new()
 style.bg_color=color
 style.border_color=border
 style.set_border_width_all(width)
 style.set_corner_radius_all(radius)
 draw_style_box(style,rect)

func _text(text: String, point: Vector2, font_size: int, color: Color, align: HorizontalAlignment=HORIZONTAL_ALIGNMENT_LEFT, width: float=-1) -> void:
 if card_font: draw_string(card_font,point,text,align,width,font_size,color)

func _update_text_layout() -> void:
 var content=str(definition.get("text",""))
 var width=card_size.x-32.0
 if _text_layout_ready and content==_layout_text and card_font==_layout_font and is_equal_approx(width,_layout_width): return
 _layout_text=content
 _layout_font=card_font
 _layout_width=width
 _text_layout_ready=true
 _text_layout_generation+=1
 _cached_text_lines=_wrap(content,width,14) if card_font else []

func _wrap(text: String,width: float,font_size: int) -> Array[String]:
 var lines:Array[String]=[]
 var line=""
 for ch in text:
  if ch=="\n":
   lines.append(line);line="";continue
  if card_font.get_string_size(line+ch,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>width and not line.is_empty():
   lines.append(line);line=""
  line+=ch
 if not line.is_empty(): lines.append(line)
 return lines

func _draw() -> void:
 if card.is_empty(): return
 var w=card_size.x
 var h=card_size.y
 var lift=1.0 if drag_active else clampf((scale.y-1.0)*10.0,0.0,1.0)
 var shadow_shift=Vector2(clampf(-_pointer_velocity.x*0.0015,-5.0,5.0),0.0) if drag_active else Vector2.ZERO
 for layer in range(3,0,-1):
  var grow=float(layer)*1.8
  _box(Rect2(Vector2(3-grow,7+lift*10.0-grow)+shadow_shift,Vector2(w+grow*2.0,h+grow*2.0)),Color(0,0,0,0.055+0.024*(4-layer)),Color.TRANSPARENT,0,13)
 if face_down:
  _draw_back()
  return
 if not card_font: return
 _update_text_layout()
 var enemy=bool(definition.get("enemy",false))
 var frame_color=Color("d6a073") if enemy else rarity
 if selected or hover:
  var glow=Color("a6e9ef") if selected else frame_color
  for j in range(4,0,-1):
   var col=glow;col.a=0.035*(5-j)
   _box(Rect2(-j*2,-j*2,w+j*4,h+j*4),Color.TRANSPARENT,col,2,12)
 draw_texture_rect(FantasySkin.texture("parchment"),Rect2(0,0,w,h),false,Color(1,0.90,0.83) if enemy else Color.WHITE)
 draw_style_box(FantasySkin.button(false,"normal"),Rect2(24,9,w-40,32))
 if art_texture:
  draw_texture_rect_region(art_texture,Rect2(14,43,w-28,92),_art_region)
  draw_rect(Rect2(14,115,w-28,20),Color(0.04,0.04,0.04,0.64))
  draw_rect(Rect2(14,43,w-28,92),Color("806037"),false,1.3)
 draw_line(Vector2(19,140),Vector2(w-19,140),Color("927044"),1.2,true)
 draw_texture_rect(FantasySkin.texture("orb"),Rect2(-8,-7,47,47),false,Color(1,0.55,0.35) if enemy else Color.WHITE if available else Color(0.6,0.6,0.6))
 _text(str(int(definition.get("cost",0))),Vector2(-2,25),24,Color("f3f1dc"),HORIZONTAL_ALIGNMENT_CENTER,34)
 var title=str(definition.get("name",""))
 _text(title,Vector2(31,31),17,Color("b3e9be") if card.get("up",false) else Color("fff1d2"),HORIZONTAL_ALIGNMENT_CENTER,w-47)
 var types={"attack":"攻击","defense":"防御","skill":"技巧"}
 _text(("敌方 · " if enemy else "")+types.get(definition.get("type","skill"),"技巧"),Vector2(20,131),11,Color("f1e3c7"))
 var lines=_cached_text_lines
 for i in range(mini(lines.size(),5)):
  _text(lines[i],Vector2(18,159+i*17),14,Color("35271a"))
 if definition.get("exhaust",false):draw_texture_rect(load("res://assets/icons/flame.svg"),Rect2(w/2-8,h-35,16,16),false)
 draw_circle(Vector2(w/2,h-9),3,frame_color)
 if hover or selected:
  for n in range(3):
   draw_line(Vector2(10+n*3,43),Vector2(w-12,43+n*2),Color(1,0.9,0.65,0.04+shine*0.08),1,true)
 if not available: draw_rect(Rect2(14,43,w-28,92),Color(0,0,0,0.28))

func _draw_back() -> void:
 var w=card_size.x
 var h=card_size.y
 draw_style_box(FantasySkin.panel(false),Rect2(0,0,w,h))
 var center=card_size*0.5
 # Fine geometric engraving remains legible while the card flips edge-on.
 for i in range(1,8):
  var y=20.0+i*27.0
  draw_line(Vector2(16,y),Vector2(w*0.5,y-20.0),Color(0.38,0.57,0.62,0.16),1.0,true)
  draw_line(Vector2(w*0.5,y-20.0),Vector2(w-16,y),Color(0.38,0.57,0.62,0.16),1.0,true)
  draw_line(Vector2(16,y),Vector2(w*0.5,y+20.0),Color(0.38,0.57,0.62,0.16),1.0,true)
  draw_line(Vector2(w*0.5,y+20.0),Vector2(w-16,y),Color(0.38,0.57,0.62,0.16),1.0,true)
 draw_circle(center,51,Color("112838"))
 draw_arc(center,50,0,TAU,80,Color("d2b781"),1.8,true)
 draw_arc(center,44,0,TAU,72,Color("597c88"),1.0,true)
 draw_arc(center,30,0,TAU,64,Color("a6c9cb"),1.0,true)
 for i in range(8):
  var angle=-PI*0.5+i*TAU/8.0
  var direction=Vector2(cos(angle),sin(angle))
  draw_line(center+direction*46,center+direction*55,Color("d2b781"),1.4,true)
 var diamond=PackedVector2Array([center+Vector2(0,-38),center+Vector2(22,0),center+Vector2(0,38),center+Vector2(-22,0)])
 draw_colored_polygon(diamond,Color("264858"))
 draw_polyline(PackedVector2Array([diamond[0],diamond[1],diamond[2],diamond[3],diamond[0]]),Color("dfc694"),1.8,true)
 var core=PackedVector2Array([center+Vector2(0,-18),center+Vector2(10,0),center+Vector2(0,18),center+Vector2(-10,0)])
 draw_colored_polygon(core,Color("acd9d8"))
 draw_line(center+Vector2(0,-20),center+Vector2(0,20),Color("f2dfaa"),1.4,true)
 for point in [Vector2(15,17),Vector2(w-15,17),Vector2(15,h-17),Vector2(w-15,h-17)]:
  draw_colored_polygon(PackedVector2Array([point+Vector2(0,-5),point+Vector2(4,0),point+Vector2(0,5),point+Vector2(-4,0)]),Color("d6bc86"))
