extends Control
signal pressed(target_id)
var target_id := ""
var unit:Dictionary={}
var font:Font
var portrait_texture:Texture2D
var is_hero := false
var highlighted := false
var hovered := false
var hp_display := 1.0
var _frame_size := Vector2(188,228)
var _hp_tween:Tween
var _hp_target:float=-1.0
var GOLD=Color("d2b783")

func setup(data:Dictionary,id:String,tex:Texture2D,f:Font,hero:bool=false)->void:
 target_id=id;unit=data.duplicate(true);portrait_texture=tex;font=f;is_hero=hero
 size=Vector2(188,243) if not hero else Vector2(164,201)
 _frame_size=Vector2(188,185) if not hero else Vector2(164,146)
 pivot_offset=_frame_size/2
 mouse_filter=Control.MOUSE_FILTER_STOP
 hp_display=float(unit.get("hp",1))/maxf(1,float(unit.get("maxHp",1)));_hp_target=hp_display
 mouse_entered.connect(func():hovered=true;queue_redraw())
 mouse_exited.connect(func():hovered=false;queue_redraw())
 queue_redraw()

func update_data(data:Dictionary)->void:
 unit=data.duplicate(true)
 var next=float(unit.get("hp",1))/maxf(1,float(unit.get("maxHp",1)))
 if is_equal_approx(next,_hp_target):queue_redraw();return
 _hp_target=next
 if _hp_tween and _hp_tween.is_valid():_hp_tween.kill()
 _hp_tween=create_tween()
 _hp_tween.tween_property(self,"hp_display",next,0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 queue_redraw()

func _process(_delta:float)->void:
 if _hp_tween and _hp_tween.is_running():queue_redraw()

func _gui_input(event:InputEvent)->void:
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
  pressed.emit(target_id);accept_event()

func _box(rect:Rect2,color:Color,border:Color,width:int=1,radius:int=8)->void:
 var style=StyleBoxFlat.new();style.bg_color=color;style.border_color=border;style.set_border_width_all(width);style.set_corner_radius_all(radius);draw_style_box(style,rect)

func _draw()->void:
 if not font:return
 var w=_frame_size.x;var h=_frame_size.y
 if highlighted:
  for j in range(5,0,-1):_box(Rect2(-j*2,-j*2,w+j*4,h+j*4),Color.TRANSPARENT,Color(0.54,0.93,0.92,0.13),2,20)
 _box(Rect2(0,7,w,h),Color(0,0,0,0.65),Color.TRANSPARENT,0,18)
 _box(Rect2(0,0,w,h),Color("102333"),GOLD if not highlighted else Color("a4eeeb"),3,16)
 if portrait_texture:
  var art=int(unit.get("art",0));var tile=portrait_texture.get_size()/Vector2(3,2)
  var region=Rect2(Vector2(art%3,art/3)*tile,tile)
  draw_texture_rect_region(portrait_texture,Rect2(7,7,w-14,h-14),region)
  for i in range(9):draw_rect(Rect2(7,h-73+i*7,w-14,7),Color(0.035,0.07,0.1,0.05+i*0.08))
 _box(Rect2(10,h-36,w-20,28),Color("112030"),Color("685d47"),1,4)
 draw_string(font,Vector2(11,h-15),str(unit.get("name","织律者")),HORIZONTAL_ALIGNMENT_CENTER,w-22,17,Color("eddec3"))
 _box(Rect2(16,h+9,w-32,12),Color("3c2430"),Color("a88765"),1,5)
 _box(Rect2(18,h+11,(w-36)*clampf(hp_display,0,1),8),Color("cf6b73"),Color.TRANSPARENT,0,3)
 draw_string(font,Vector2(15,h+44),"%d / %d"%[unit.get("hp",0),unit.get("maxHp",0)],HORIZONTAL_ALIGNMENT_CENTER,w-30,21,Color("f4d6cf"))
 if int(unit.get("block",0))>0:
  var p=Vector2(4,h-6);draw_circle(p,22,Color("173d58"));draw_arc(p,22,0,TAU,32,Color("a1ddeb"),2,true)
  draw_string(font,p+Vector2(-20,8),str(int(unit.block)),HORIZONTAL_ALIGNMENT_CENTER,40,21,Color("d0f1f8"))
 var stats=[]
 if int(unit.get("burn",0))>0:stats.append("燃烧 %d"%unit.burn)
 if int(unit.get("strength",0))>0:stats.append("力量 +%d"%unit.strength)
 if int(unit.get("vulnerable",0))>0:stats.append("易伤 %d"%unit.vulnerable)
 if not stats.is_empty():
  draw_string(font,Vector2(-25,h+63)," · ".join(stats),HORIZONTAL_ALIGNMENT_CENTER,w+50,13,Color("e4bc93"))
 if hovered:draw_rect(Rect2(7,7,w-14,h-14),Color(1,0.85,0.61,0.035))
