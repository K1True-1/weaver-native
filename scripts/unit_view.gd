extends Control
signal pressed(target_id)
const FantasySkin = preload("res://scripts/material_skin.gd")
var target_id := ""
var unit: Dictionary = {}
var font: Font
var portrait_texture: Texture2D
var figure: Texture2D
var is_hero := false
var highlighted := false
var hovered := false
var reduced := false
var hp_display := 1.0
var _frame_size := Vector2(310,351)
var _hp_tween: Tween
var _hp_target := -1.0
var clock := 0.0
var GOLD=Color("d2b783")

func setup(data: Dictionary, id: String, tex: Texture2D, f: Font, hero: bool=false) -> void:
 target_id=id;unit=data.duplicate(true);portrait_texture=tex;font=f;is_hero=hero
 size=Vector2(310,400);pivot_offset=Vector2(155,275)
 mouse_filter=Control.MOUSE_FILTER_STOP;mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 var figures={0:"weaver-figure",1:"grayblade-figure"}
 var art=int(unit.get("art",0))
 if figures.has(art) and ResourceLoader.exists("res://assets/ui/"+figures[art]+".png"):
  figure=load("res://assets/ui/"+figures[art]+".png")
 hp_display=float(unit.get("hp",1))/maxf(1,float(unit.get("maxHp",1)));_hp_target=hp_display
 mouse_entered.connect(func():hovered=true;queue_redraw())
 mouse_exited.connect(func():hovered=false;queue_redraw())
 _update_tooltip()
 queue_redraw()

func _update_tooltip() -> void:
 tooltip_text="%s\n生命 %d / %d · 护甲 %d"%[unit.get("name",""),unit.get("hp",0),unit.get("maxHp",0),unit.get("block",0)]
 if not is_hero:tooltip_text+="\n点击切换查看该对手的牌组"

func update_data(data: Dictionary) -> void:
 unit=data.duplicate(true);_update_tooltip()
 var next=float(unit.get("hp",1))/maxf(1,float(unit.get("maxHp",1)))
 if is_equal_approx(next,_hp_target):queue_redraw();return
 _hp_target=next
 if _hp_tween and _hp_tween.is_valid():_hp_tween.kill()
 _hp_tween=create_tween()
 _hp_tween.tween_property(self,"hp_display",next,0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 queue_redraw()

func _process(delta: float) -> void:
 if not reduced:
  clock+=minf(delta,0.05)
  queue_redraw()
 elif _hp_tween and _hp_tween.is_running():queue_redraw()

func _gui_input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
  pressed.emit(target_id);accept_event()

func _pedestal() -> void:
 var center=Vector2(155,345)
 var accent=Color("7adbed") if is_hero else Color("d6aa62")
 if highlighted:accent=Color("b4fff2")
 # Fixed contact shadow and elliptical rune bed ground the moving figure.
 draw_set_transform(center+Vector2(0,8),0,Vector2(1,0.25))
 for i in range(6,0,-1):draw_circle(Vector2.ZERO,111+i*5,Color(0,0,0,0.055))
 draw_set_transform(center,0,Vector2(1,0.27))
 for i in range(8,0,-1):draw_circle(Vector2.ZERO,104+i*4,Color(accent,0.007+(0.009 if highlighted else 0.0)))
 draw_circle(Vector2.ZERO,116,Color(0.02,0.04,0.045,0.60))
 draw_arc(Vector2.ZERO,121,0,TAU,96,Color(accent,0.78 if hovered or highlighted else 0.38),2.5,true)
 draw_arc(Vector2.ZERO,113,0,TAU,96,Color(accent,0.28),1.1,true)
 draw_arc(Vector2.ZERO,92,-clock*0.15,TAU*0.78-clock*0.15,72,Color(accent,0.45),1.4,true)
 for i in range(24):
  var direction=Vector2.from_angle(i*TAU/24.0+clock*0.045)
  draw_line(direction*98,direction*(110 if i%3==0 else 105),Color(accent,0.50),2,true)
 draw_set_transform(Vector2.ZERO)
 if not reduced:
  for i in range(7):
   var p=center+Vector2(sin(clock*0.4+i*2.7)*109,-fmod(clock*10+i*29,98))
   draw_circle(p,1.2,Color(accent,0.2+0.25*sin(clock+i)))

func _draw() -> void:
 if not font:return
 _pedestal()
 var breath=0.0 if reduced else sin(clock*1.9)*0.0045
 var sway=0.0 if reduced else sin(clock*0.74)*1.4
 draw_set_transform(Vector2(sway,-breath*349),0,Vector2(1,1+breath))
 if figure:
  draw_texture_rect(figure,Rect2(31,-15,248,372),false,Color(1.07,1.05,1.02) if hovered else Color.WHITE)
 else:
  var art=int(unit.get("art",0));var tile=portrait_texture.get_size()/Vector2(3,2)
  var rect=Rect2(39,50,232,275)
  draw_texture_rect_region(portrait_texture,rect,Rect2(Vector2(art%3,floori(art/3.0))*tile,tile))
  draw_style_box(FantasySkin.panel(false,Color.WHITE,true),rect.grow(8))
 draw_set_transform(Vector2.ZERO)
 # Compact current-health jewel, attached to the figure rather than a nameplate.
 var hp_rect=Rect2(222,303,76,76)
 draw_texture_rect(FantasySkin.texture("health-gem"),hp_rect,false)
 draw_string_outline(font,Vector2(228,354),health_text(),HORIZONTAL_ALIGNMENT_CENTER,64,32,4,Color("311517"))
 draw_string(font,Vector2(228,354),health_text(),HORIZONTAL_ALIGNMENT_CENTER,64,32,Color("fff0dd"))
 if int(unit.get("block",0))>0:
  draw_texture_rect(FantasySkin.texture("orb"),Rect2(11,316,59,59),false)
  draw_string(font,Vector2(15,354),str(int(unit.block)),HORIZONTAL_ALIGNMENT_CENTER,51,26,Color("e3faff"))
 var stats=[]
 if int(unit.get("burn",0))>0:stats.append("燃烧 %d"%unit.burn)
 if int(unit.get("strength",0))>0:stats.append("力量 +%d"%unit.strength)
 if int(unit.get("vulnerable",0))>0:stats.append("易伤 %d"%unit.vulnerable)
 if not stats.is_empty():draw_string(font,Vector2(20,397)," · ".join(stats),HORIZONTAL_ALIGNMENT_CENTER,270,16,Color("edc891"))

func health_text()->String:
 return str(int(unit.get("hp",0)))
