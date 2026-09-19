extends Control
const Game = preload("res://scripts/game.gd")
const Card = preload("res://scripts/card_view.gd")
const Unit = preload("res://scripts/unit_view.gd")
const BoardProp = preload("res://scripts/prop_view.gd")
const Effects = preload("res://scripts/vfx.gd")
const Screens = preload("res://scripts/screens.gd")
const Ambience = preload("res://scripts/ambience.gd")
const FantasySkin = preload("res://scripts/material_skin.gd")
var ambience:Control
var ignore_left_release=false
var inspect_box:Panel
var inspect_name:Label
var inspect_text:Label
var inspect_kind:Label
var game
var fx
var screens
var font:Font
var serif:Font
var spells:Texture2D
var portraits:Texture2D
var scene_root:Control
var battle_root:Control
var hand_root:Control
var enemy_hand_root:Control
var enemy_hand_views:Dictionary={}
var focused_enemy_id=""
var enemy_name_label:Label
var enemy_energy_label:Label
var enemy_deck_button:Button
var enemy_discard_button:Button
var outgoing_uid=""
var drag_insert_index=-1
var hand_layout_signature=""
var enemy_layout_signature=""
var presentation_generation=0
var active_enemy_ghost:Control
var showcase_pointer=Vector2.INF
var header:Control
var modal_root:Control
var cards:Dictionary={}
var units:Dictionary={}
var object_nodes:Dictionary={}
var slot_nodes:Array=[]
var intent_nodes:Dictionary={}
var energy_label:Label
var hint_label:Label
var turn_label:Label
var end_button:Button
var cast_button:Button
var mode_button:Button
var phase_label:Label
var chain_label:Label
var last_log:Label
var log_button:Button
var header_hp:Label
var header_gold:Label
var deck_button:Button
var discard_button:Button
var exhaust_button:Button
var busy=false
var at_title=true
var selected_uid=""
var selected_binding=""
var selected_mode="block"
var hovered_uid=""
var dragged_uid=""
var drag_offset=Vector2.ZERO
var built_key=""
var refreshed=false
var practice_backup:Dictionary={}
var current_modal:Control
var choice_waiting=false
var chain_count=0
var showcase=false
var audio_on=true
signal choice_finished(ids)
var GOLD=Color("d9bd89")
var PALE=Color("f0e3c7")
var MUTED=Color("abbfc8")
var CYAN=Color("a4e9ec")

func _ready()->void:
 Engine.max_fps=120
 font=load("res://assets/NotoSansCJKsc-Regular.otf")
 serif=load("res://assets/NotoSerifCJKsc-Regular.otf")
 var native_theme=Theme.new();native_theme.default_font=font;native_theme.default_font_size=20;FantasySkin.apply_native_controls(native_theme);theme=native_theme
 spells=load("res://assets/spells-atlas.webp")
 portraits=load("res://assets/characters-atlas.webp")
 ambience=Ambience.new();ambience.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(ambience)
 scene_root=_layer();header=_layer();modal_root=_layer();modal_root.z_index=100
 fx=Effects.new();add_child(fx);fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);fx.z_index=90
 screens=Screens.new();game=Game.new();game.presenter=_present;game.chooser=_choose
 game.changed.connect(_request_refresh)
 if game.has_signal("message"):game.message.connect(_toast)
 if "--qa" in OS.get_cmdline_user_args():game.save_path="user://qa-session.json"
 else:game.load_game()
 showcase="--showcase" in OS.get_cmdline_user_args()
 _refresh()
 if showcase:call_deferred("_showcase")
 if "--verify-build" in OS.get_cmdline_user_args() and "--qa" in OS.get_cmdline_user_args():call_deferred("_verify_build")

func _layer()->Control:
 var c=Control.new();c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);c.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(c);return c

func _style(bg:Color,border:Color,radius:int=8,width:int=1)->StyleBoxFlat:
 var s=StyleBoxFlat.new();s.bg_color=bg;s.border_color=Color(border,0.65);s.set_border_width_all(width);s.set_corner_radius_all(mini(radius,4));s.content_margin_left=12;s.content_margin_right=12;s.content_margin_top=8;s.content_margin_bottom=8;s.shadow_color=Color(0,0,0,0.22);s.shadow_size=8;return s

func _panel(parent:Node,pos:Vector2,sz:Vector2,_alpha:float=0.82,_border:Color=Color("6a614b"))->Panel:
 var p=Panel.new();p.position=pos;p.size=sz;p.add_theme_stylebox_override("panel",FantasySkin.panel(minf(sz.x,sz.y)<150));p.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(p);return p

func _label(parent:Node,text:String,pos:Vector2,sz:Vector2,fs:int=20,color:Color=PALE,align:HorizontalAlignment=HORIZONTAL_ALIGNMENT_LEFT,headline:bool=false)->Label:
 var l=Label.new();l.text=text;l.position=pos;l.size=sz;l.add_theme_font_override("font",serif if headline else font);l.add_theme_font_size_override("font_size",fs);l.add_theme_color_override("font_color",color);l.horizontal_alignment=align;l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;l.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(l);return l

func _button(parent:Node,text:String,pos:Vector2,sz:Vector2,callback:Callable,primary:bool=false)->Button:
 var b=Button.new();b.position=pos;b.size=sz;b.text=text;b.add_theme_font_override("font",font);b.add_theme_font_size_override("font_size",17);b.add_theme_color_override("font_color",Color("17232b") if primary else PALE)
 FantasySkin.apply_button(b,primary);b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 b.pressed.connect(func():fx.sound("click");callback.call());parent.add_child(b);return b

func _icon_button(parent:Control,icon:String,tip:String,pos:Vector2,sz:Vector2,callback:Callable,count:String="")->Button:
 var button=_button(parent,"",pos,sz,callback)
 button.tooltip_text=tip
 var has_count=not count.is_empty()
 FantasySkin.icon(button,icon,Rect2(14 if has_count else (sz.x-24)/2,(sz.y-24)/2,24,24))
 if has_count:button.set_meta("count",_label(button,count,Vector2(46,0),Vector2(sz.x-56,sz.y),19,PALE,HORIZONTAL_ALIGNMENT_CENTER))
 return button

func _set_icon_count(button:Button,value:String)->void:
 if button.has_meta("count"):button.get_meta("count").text=value

func _show_log()->void:
 if game.s.get("battle")==null:return
 _info("战斗记录","\n\n".join(game.s.battle.log.slice(0,18).map(func(entry):return str(entry.text))))

func _request_refresh()->void:
 if not refreshed:refreshed=true;call_deferred("_deferred_refresh")
func _deferred_refresh()->void:
 refreshed=false;_refresh()

func _refresh()->void:
 if not game:return
 fx.fast=bool(game.s.settings.get("fast",false));fx.reduced=not bool(game.s.settings.get("motion",true));fx.audio_enabled=bool(game.s.settings.get("sound",true))
 var kind="title" if at_title else str(game.s.screen)
 ambience.reduced=fx.reduced;ambience.set_mode(kind)
 var r=game.s.get("run",{})
 var node_id=str(r.get("node",{}).get("id","")) if r is Dictionary and r.get("node") is Dictionary else ""
 var key=kind+":"+node_id
 if key!=built_key:
  for child in scene_root.get_children():child.queue_free()
  scene_root= _replace_layer(scene_root)
  presentation_generation+=1;enemy_hand_views.clear();focused_enemy_id="";outgoing_uid="";enemy_layout_signature="";hand_layout_signature="";cards.clear();units.clear();object_nodes.clear();slot_nodes.clear();intent_nodes.clear();fx.clear_aim();selected_uid="";selected_binding="";dragged_uid="";hovered_uid=""
  built_key=key
  if kind=="battle":_build_battle()
  else:screens.build(kind,scene_root,game,_screen_action,font,serif,Card,spells,portraits)
  scene_root.modulate.a=0.0;create_tween().tween_property(scene_root,"modulate:a",1.0,0.32)
  if kind=="reward" or kind=="victory" or kind=="practiceWin":fx.banner("胜利" if kind!="victory" else "断环已碎","新的规则，由你书写","victory")
 elif kind!="battle":
  for child in scene_root.get_children():child.queue_free()
  scene_root=_replace_layer(scene_root)
  screens.build(kind,scene_root,game,_screen_action,font,serif,Card,spells,portraits)
 if kind=="battle":_update_battle()
 _update_header()

func _replace_layer(old:Control)->Control:
 var index=old.get_index();remove_child(old);old.queue_free();var c=Control.new();c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);c.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(c);move_child(c,index);return c

func _update_header()->void:
 for c in header.get_children():c.queue_free()
 _label(header,"织律者",Vector2(56,26),Vector2(180,52),25,GOLD,HORIZONTAL_ALIGNMENT_LEFT,true)
 header_hp=null;header_gold=null
 if not at_title and not game.s.get("run",{}).is_empty() and game.s.screen!="battle":
  var r=game.s.run
  _label(header,"规则练习" if r.get("practice",false) else "第 %s 章 · %s"%[int(r.chapter)+1,game.db.chapters[mini(int(r.chapter),2)].name],Vector2(475,30),Vector2(340,45),20,PALE,HORIZONTAL_ALIGNMENT_CENTER)
  FantasySkin.icon(header,"heart",Rect2(835,39,22,22))
  header_hp=_label(header,str(int(r.hp)),Vector2(868,30),Vector2(150,45),18,Color("efb6af"))
  FantasySkin.icon(header,"coins",Rect2(1020,38,24,24))
  header_gold=_label(header,str(r.gold),Vector2(1056,30),Vector2(75,45),18,GOLD)
 _icon_button(header,"circle-help","玩法与快捷键",Vector2(1220,34),Vector2(63,41),_help)
 _icon_button(header,"layers","卡组",Vector2(1302,34),Vector2(63,41),func():_deck())
 _icon_button(header,"settings","设置",Vector2(1384,34),Vector2(63,41),_settings)
 _icon_button(header,"house","返回主菜单",Vector2(1466,34),Vector2(63,41),_home)
 _set_header_busy()

func _set_header_busy()->void:
 for child in header.get_children():
  if child is Button:child.disabled=busy

func _build_battle()->void:
 battle_root=Control.new();battle_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);battle_root.mouse_filter=Control.MOUSE_FILTER_IGNORE;scene_root.add_child(battle_root)
 var b=game.s.battle
 for i in range(b.slots.size()):
  var p=_panel(battle_root,Vector2(70,190+i*139),Vector2(247,116),0.82,Color("839792"));p.mouse_filter=Control.MOUSE_FILTER_STOP
  p.tooltip_text="律令槽 · 拖入手牌以安装规则"
  p.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
  p.mouse_entered.connect(func():p.modulate=Color(1.15,1.13,1.05))
  p.mouse_exited.connect(func():p.modulate=Color.WHITE)
  p.gui_input.connect(_slot_input.bind(i));slot_nodes.append(p)
 log_button=_icon_button(battle_root,"scroll-text","战斗记录",Vector2(1492,118),Vector2(60,47),_show_log)
 inspect_box=_panel(battle_root,Vector2(1358,147),Vector2(200,341),0.97,GOLD);inspect_box.visible=false;inspect_box.z_index=25
 inspect_kind=_label(inspect_box,"",Vector2(16,16),Vector2(168,29),13,CYAN)
 inspect_name=_label(inspect_box,"",Vector2(16,53),Vector2(168,45),24,GOLD,HORIZONTAL_ALIGNMENT_LEFT,true)
 inspect_text=_label(inspect_box,"",Vector2(16,110),Vector2(168,210),17,PALE);inspect_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;inspect_text.vertical_alignment=VERTICAL_ALIGNMENT_TOP
 phase_label=_label(battle_root,"",Vector2(465,92),Vector2(670,25),20,GOLD,HORIZONTAL_ALIGNMENT_CENTER,true)
 chain_label=_label(battle_root,"",Vector2(949,424),Vector2(194,45),26,CYAN,HORIZONTAL_ALIGNMENT_CENTER,true)
 turn_label=_label(battle_root,"",Vector2(1370,622),Vector2(170,33),20,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
 end_button=_button(battle_root,"结束回合",Vector2(1355,665),Vector2(198,79),func():_perform(func():await game.end_turn()),true)
 _icon_button(battle_root,"fast-forward","切换快速结算",Vector2(1490,760),Vector2(62,44),_toggle_fast)
 deck_button=_icon_button(battle_root,"layers","抽牌堆",Vector2(75,788),Vector2(121,55),func():_zone("draw"),"0")
 discard_button=_icon_button(battle_root,"archive-restore","弃牌堆 · 牌库耗尽后洗回",Vector2(75,851),Vector2(121,55),func():_zone("discard"),"0")
 exhaust_button=_icon_button(battle_root,"flame","消耗区 · 本场战斗不再抽到",Vector2(75,914),Vector2(121,55),func():_zone("exhaust"),"0")
 var energy=TextureRect.new();energy.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;energy.texture=FantasySkin.texture("orb");energy.position=Vector2(108,682);energy.size=Vector2(88,88);energy.mouse_filter=Control.MOUSE_FILTER_IGNORE;battle_root.add_child(energy)
 energy_label=_label(energy,"3",Vector2(0,9),Vector2(88,67),36,Color("e8ffff"),HORIZONTAL_ALIGNMENT_CENTER,true)
 energy.mouse_filter=Control.MOUSE_FILTER_PASS;energy.tooltip_text="可用能量"
 cast_button=_button(battle_root,"施放",Vector2(1085,675),Vector2(213,47),_cast_selected,true);cast_button.visible=false
 mode_button=_button(battle_root,"护甲 / 修复",Vector2(1085,726),Vector2(213,38),_toggle_mode);mode_button.visible=false
 hand_root=Control.new();hand_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hand_root.mouse_filter=Control.MOUSE_FILTER_IGNORE;hand_root.z_index=15;battle_root.add_child(hand_root)
 hint_label=_label(battle_root,"",Vector2(325,967),Vector2(990,30),15,MUTED,HORIZONTAL_ALIGNMENT_CENTER);hint_label.z_index=40
 _build_enemy_hand()

func _unit_state(hero:bool=false)->Dictionary:
 var b=game.s.battle;var r=game.s.run
 return {"name":"织律者","hp":r.hp,"maxHp":r.maxHp,"block":b.block,"strength":b.strength,"burn":b.burn,"vulnerable":b.vulnerable,"art":0} if hero else {}

func _update_battle()->void:
 if not is_instance_valid(battle_root) or game.s.screen!="battle":return
 var b=game.s.battle
 energy_label.text=str(int(b.energy));turn_label.text="第 %d 回合"%b.turn
 phase_label.text=""
 end_button.disabled=busy or b.phase!="player" or b.paused
 end_button.text="连锁暂停" if b.paused else "敌方行动" if b.phase!="player" else "结束回合"
 _set_icon_count(deck_button,str(b.draw.size()));_set_icon_count(discard_button,str(b.discard.size()));_set_icon_count(exhaust_button,str(b.exhaust.size()))
 if not units.has("self"):
  var hero=Unit.new();hero.setup(_unit_state(true),"self",portraits,font,true);hero.position=Vector2(645,288);hero.scale=Vector2.ONE*0.70;hero.pressed.connect(_target_clicked);battle_root.add_child(hero);units["self"]=hero
 else:units.self.update_data(_unit_state(true))
 units.self.reduced=fx.reduced
 var alive=b.enemies.filter(func(e):return e.hp>0)
 for i in range(alive.size()):
  var e=alive[i];var p=Vector2(645,10) if alive.size()==1 else Vector2(490+i*310,10)
  if not units.has(e.id):
   var u=Unit.new();u.setup(e,e.id,portraits,font);u.position=p;u.pressed.connect(_target_clicked);battle_root.add_child(u);units[e.id]=u
   var intent=Control.new();intent.position=p+Vector2(45,-39);intent.size=Vector2(216,36);intent.mouse_filter=Control.MOUSE_FILTER_PASS;battle_root.add_child(intent)
   var il=_label(intent,"",Vector2(0,0),Vector2(216,36),15,Color("f3c59d"),HORIZONTAL_ALIGNMENT_CENTER);intent_nodes[e.id]=intent
  else:units[e.id].update_data(e)
  units[e.id].reduced=fx.reduced
  units[e.id].scale=Vector2.ONE*0.65
  units[e.id].position=p
  intent_nodes[e.id].tooltip_text=game.intent_text(e)
  intent_nodes[e.id].get_child(0).text=""
 for id in units.keys():
  if id!="self" and not alive.any(func(e):return e.id==id):
   units[id].queue_free();units.erase(id)
   if intent_nodes.has(id):intent_nodes[id].queue_free();intent_nodes.erase(id)
 for i in range(b.objects.size()):
  var o=b.objects[i];var pos=Vector2(1000,392) if b.objects.size()==1 else Vector2(410+i*590,392)
  if not object_nodes.has(o.id):
   var prop=BoardProp.new();prop.setup(o,font);prop.gui_input.connect(_object_input.bind(o.id));battle_root.add_child(prop);object_nodes[o.id]=prop
  var node=object_nodes[o.id]
  node.position=pos
  node.reduced=fx.reduced;node.update_data(o)
  node.tooltip_text="%s · 敌我共用\n%s\n耐久 %d · 护甲 %d · 充能 %d\n空手点击可互动，不消耗资源；出牌才能造成伤害。"%[o.name,game.db.object_text(o,int(game.s.run.chapter)),o.hp,o.block,o.charges]
 for i in range(slot_nodes.size()):
  var node:Panel=slot_nodes[i]
  for c in node.get_children():c.queue_free()
  var binding=b.slots[i]
  if binding==null:
   FantasySkin.icon(node,"sparkles",Rect2(103,38,40,40),0.3)
   node.add_theme_stylebox_override("panel",FantasySkin.panel(true,Color(0.69,0.70,0.67)))
   node.tooltip_text="律令槽 · 拖入手牌以安装规则"
  else:
   node.add_theme_stylebox_override("panel",FantasySkin.panel(true))
   var art=TextureRect.new();art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.texture=_atlas(spells,int(game.db.info(binding.card).art),4,2);art.position=Vector2(9,10);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.size=Vector2(48,56);art.mouse_filter=Control.MOUSE_FILTER_IGNORE;node.add_child(art)
   var tr=game.db.triggers.filter(func(t):return t.id==binding.trigger)[0]
   _label(node,str(tr.name),Vector2(67,8),Vector2(167,24),13,CYAN)
   _label(node,str(game.db.info(binding.card).name),Vector2(67,32),Vector2(170,29),20,PALE)
   FantasySkin.icon(node,"zap",Rect2(70,81,15,15));FantasySkin.icon(node,"repeat-2",Rect2(137,81,15,15))
   _label(node,str(maxi(1,int(game.db.info(binding.card).cost))),Vector2(89,75),Vector2(39,25),13,MUTED)
   _label(node,str(binding.fires),Vector2(157,75),Vector2(57,25),13,MUTED)
   node.modulate=Color.WHITE if binding.enabled else Color(0.6,0.6,0.6)
   node.tooltip_text="%s\n每次响应消耗 %d 能量 · 已响应 %d 次\n点击管理规则"%[tr.text,maxi(1,int(game.db.info(binding.card).cost)),binding.fires]
 _sync_hand()
 _sync_enemy_hand()
 var selected=_selected_card()
 for id in units:
  units[id].highlighted=not selected.is_empty() and not busy and game.valid_target(selected,id,selected_mode) and game.target_kind(selected,selected_mode)!="none";units[id].queue_redraw()
 for id in object_nodes:
  var valid=not selected.is_empty() and not busy and game.valid_target(selected,id,selected_mode) and game.target_kind(selected,selected_mode)!="none"
  object_nodes[id].highlighted=valid;object_nodes[id].queue_redraw()
 cast_button.visible=not selected.is_empty() and game.target_kind(selected,selected_mode)=="none" and not busy
 if cast_button.visible:cast_button.text="施放 · %s"%game.db.info(selected).name
 mode_button.visible=not selected.is_empty() and selected.id=="C28" and not busy
 hint_label.text=""
 if b.paused:call_deferred("_chain_pause")

func _sync_hand()->void:
 var state=game.s.battle;var ids=state.hand.map(func(c):return str(c.uid));var arrival=0
 for id in cards.keys():
  if not id in ids:cards[id].queue_free();cards.erase(id)
 for c in state.hand:
  if not cards.has(c.uid):
   var view=Card.new();view.setup(c,game.db.info(c),spells,font);view.position=Vector2(78,755);view.scale=Vector2(0.35,0.35);view.modulate.a=0.0
   view.set_meta("deal_delay",arrival*0.055);arrival+=1
   view.pressed.connect(_card_pressed);view.hover_changed.connect(_card_hover);view.drag_started.connect(_drag_start);view.dragged.connect(_drag_move);view.released.connect(_card_release)
   hand_root.add_child(view);cards[c.uid]=view
   var deal=view.create_tween();deal.tween_interval(float(view.get_meta("deal_delay")))
   deal.tween_callback(func():if is_instance_valid(view):fx.sound("draw"))
   deal.tween_property(view,"modulate:a",1.0,0.15)
  cards[c.uid].interactive=not busy and state.phase=="player" and not state.paused
  cards[c.uid].set_available(game.normal_cost(c)<=state.energy)
  cards[c.uid].set_selected(selected_uid==c.uid)
 _layout_hand()

func _layout_hand()->void:
 if game.s.get("battle")==null:return
 var order:Array=[]
 for c in game.s.battle.hand:
  if str(c.uid)!=outgoing_uid and str(c.uid)!=dragged_uid:order.append(str(c.uid))
 if not dragged_uid.is_empty() and drag_insert_index>=0:order.insert(clampi(drag_insert_index,0,order.size()),"@gap")
 var focus=hovered_uid if not hovered_uid.is_empty() else selected_uid
 if not dragged_uid.is_empty():focus=""
 var n=order.size();var spread=minf(151,955.0/maxi(n-1,1));var f=order.find(focus)
 for i in range(n):
  var id=str(order[i]);if not cards.has(id):continue
  var c=cards[id];var offset=float(i)-(n-1)/2.0;var normalized=offset/maxf(1,(n-1)/2.0)
  var push=0.0
  if f>=0 and i!=f:push=signf(i-f)*40.0*exp(-absf(i-f)*0.27)
  c.index=i;c.z_index=i+(40 if c.hover or c.selected else 0)
  var delay=float(c.get_meta("deal_delay",0.0))
  if c.has_meta("deal_delay"):c.remove_meta("deal_delay")
  c.move_to(Vector2(800+offset*spread-85+push,699+normalized*normalized*12),deg_to_rad(normalized*8.0),not fx.reduced,delay)

func _hover_hand()->void:
 if busy or not dragged_uid.is_empty() or is_instance_valid(current_modal):return
 var pointer=_pointer();var next="";var best=INF
 if pointer.y>=638 and pointer.y<=998:
  for c in game.s.battle.hand:
   var id=str(c.uid)
   if not cards.has(id) or id==outgoing_uid:continue
   var v=cards[id];var center=v.base_position.x+85
   if absf(pointer.x-center)<100 and absf(pointer.x-center)<best:
    next=id;best=absf(pointer.x-center)
 var changed_focus=next!=hovered_uid
 var previous=hovered_uid;hovered_uid=next
 var repair_hover=false
 for id in cards:
  var desired=id==next
  if cards[id].hover!=desired:cards[id].hover=desired;cards[id].queue_redraw();repair_hover=true
 if not changed_focus and not repair_hover:return
 if changed_focus and not previous.is_empty() and cards.has(previous):fx.card_hover(cards[previous],false)
 if changed_focus and not next.is_empty() and cards.has(next):fx.card_hover(cards[next],true)
 if is_instance_valid(inspect_box):
  inspect_box.visible=not next.is_empty() and cards.has(next)
  if inspect_box.visible:
   var d=cards[next].definition
   inspect_name.text=str(d.name);inspect_kind.text="%s  /  %d 能量"%[{"attack":"攻击","defense":"防御","skill":"技巧"}.get(d.get("type"),"技巧"),d.get("cost",0)]
   inspect_text.text=str(d.get("text",""))+("\n\n消耗" if d.get("exhaust",false) else "")
 _layout_hand()

func _drag_gap(point:Vector2)->int:
 if point.y<668 or point.x<230 or point.x>1370:return -1
 var count=game.s.battle.hand.size()-1
 var spacing=minf(151,955.0/maxi(count,1))
 return clampi(int(round((point.x-800)/spacing+count/2.0)),0,count)

func _build_enemy_hand()->void:
 enemy_hand_root=Control.new();enemy_hand_root.mouse_filter=Control.MOUSE_FILTER_IGNORE;enemy_hand_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);enemy_hand_root.z_index=9;battle_root.add_child(enemy_hand_root)
 enemy_name_label=_label(battle_root,"",Vector2(393,103),Vector2(268,26),16,GOLD)
 FantasySkin.icon(battle_root,"zap",Rect2(1109,106,19,19))
 enemy_energy_label=_label(battle_root,"",Vector2(1136,97),Vector2(55,36),17,Color("e5b79c"))
 enemy_energy_label.tooltip_text="对手行动能量";enemy_energy_label.mouse_filter=Control.MOUSE_FILTER_PASS
 enemy_deck_button=_icon_button(battle_root,"layers","对手牌组",Vector2(1100,148),Vector2(88,40),func():_enemy_zone("deck"),"0")
 enemy_discard_button=_icon_button(battle_root,"archive-restore","对手弃牌堆",Vector2(1100,199),Vector2(88,40),func():_enemy_zone("discard"),"0")

func _enemy_focus()->Dictionary:
 if not game.s.get("battle"):return {}
 for enemy in game.s.battle.enemies:
  if enemy.id==focused_enemy_id and enemy.hp>0:return enemy
 for enemy in game.s.battle.enemies:
  if enemy.hp>0:focused_enemy_id=str(enemy.id);return enemy
 return {}

func _enemy_center(index:int,count:int)->Vector2:
 var offset=float(index)-(count-1)/2.0
 return Vector2(800+offset*46,51+pow(offset/maxf(1,(count-1)/2.0),2)*5)

func _enemy_definition(card:Dictionary,enemy:Dictionary)->Dictionary:
 var definition=game.enemy_card_info(card,enemy).duplicate(true);definition.enemy=true;return definition

func _sync_enemy_hand(snapshot:Dictionary={},new_cards:Array=[])->void:
 if not is_instance_valid(enemy_hand_root):return
 var enemy=_enemy_focus() if snapshot.is_empty() else snapshot
 if enemy.is_empty():return
 if focused_enemy_id!=str(enemy.id):
  for node in enemy_hand_views.values():node.queue_free()
  enemy_hand_views.clear();focused_enemy_id=str(enemy.id);enemy_layout_signature=""
 var hand:Array=enemy.get("hand",[]);var ids=hand.map(func(c):return str(c.uid))
 var draw_ids=new_cards.map(func(c):return str(c.uid))
 enemy_name_label.text=""
 if intent_nodes.has(str(enemy.id)):intent_nodes[str(enemy.id)].tooltip_text=game.intent_text(enemy)
 enemy_energy_label.text=str(int(enemy.get("energy",3)))
 _set_icon_count(enemy_deck_button,str(enemy.get("draw",[]).size()))
 _set_icon_count(enemy_discard_button,str(enemy.get("discard",[]).size()))
 enemy_deck_button.tooltip_text="%s · 牌库 %d / 共 %d\n点击查看整套牌组，不公开隐藏手牌"%[enemy.name,enemy.get("draw",[]).size(),enemy.get("deck",[]).size()]
 enemy_deck_button.disabled=busy;enemy_discard_button.disabled=busy
 for id in enemy_hand_views.keys():
  if not id in ids:enemy_hand_views[id].queue_free();enemy_hand_views.erase(id)
 var signature=str(enemy.id)+":"+",".join(ids)
 if signature==enemy_layout_signature and draw_ids.is_empty():return
 enemy_layout_signature=signature
 var deal_order=0
 for i in range(hand.size()):
  var card=hand[i];var id=str(card.uid);var center=_enemy_center(i,hand.size());var fresh=not enemy_hand_views.has(id)
  if fresh:
   var view=Card.new();view.interactive=false;view.setup(card,_enemy_definition(card,enemy),spells,font);view.set_face_down(true);view.pivot_offset=view.size/2;view.mouse_filter=Control.MOUSE_FILTER_IGNORE
   view.scale=Vector2.ONE*0.27;view.position=center-view.size/2;enemy_hand_root.add_child(view);enemy_hand_views[id]=view
  var view=enemy_hand_views[id];view.z_index=i
  var angle=deg_to_rad((float(i)-(hand.size()-1)/2.0)*3.4)
  if view.has_meta("hand_tween"):
   var old=view.get_meta("hand_tween")
   if old is Tween and old.is_valid():old.kill()
  if id in draw_ids:
   view.position=enemy_deck_button.get_global_rect().get_center()-view.size/2;view.rotation=-0.23;view.modulate.a=0.1
   var delay=deal_order*0.075;deal_order+=1
   var tween=view.create_tween().set_parallel(true);view.set_meta("hand_tween",tween)
   tween.tween_property(view,"position",center-view.size/2,0.38).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
   tween.tween_property(view,"rotation",angle,0.34).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
   tween.tween_property(view,"modulate:a",1.0,0.15).set_delay(delay)
   tween.tween_callback(func():fx.sound("draw")).set_delay(delay+0.05)
  elif fresh:
   view.rotation=angle
  else:
   var tween=view.create_tween().set_parallel(true);view.set_meta("hand_tween",tween)
   tween.tween_property(view,"position",center-view.size/2,0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
   tween.tween_property(view,"rotation",angle,0.2)

func _enemy_zone(zone:String)->void:
 if busy:return
 var enemy=_enemy_focus()
 if enemy.is_empty():return
 var list:Array=enemy.get(zone,[]).duplicate(true)
 var title="%s · %s"%[enemy.name,"整套牌组（不公开抽牌顺序）" if zone=="deck" else "已打出的牌"]
 var p=_modal(title);var scroll=ScrollContainer.new();scroll.position=Vector2(28,91);scroll.size=Vector2(1080,646);p.add_child(scroll)
 var grid=GridContainer.new();grid.columns=5;grid.add_theme_constant_override("h_separation",30);grid.add_theme_constant_override("v_separation",22);scroll.add_child(grid)
 list.sort_custom(func(a,b):return str(a.id)<str(b.id))
 for card in list:
  var view=Card.new();view.interactive=false;view.setup(card,_enemy_definition(card,enemy),spells,font);grid.add_child(view)
 if list.is_empty():_label(p,"尚未有卡牌进入弃牌堆。",Vector2(50,220),Vector2(1020,70),24,MUTED,HORIZONTAL_ALIGNMENT_CENTER)

func _effect_style(definition:Dictionary)->String:
 if "fire" in definition.get("tags",[]) or int(definition.get("art",-1))==2:return "fire"
 if definition.get("type")=="attack":return "physical"
 if definition.get("type")=="defense":return "ice"
 if "energy" in definition.get("tags",[]):return "energy"
 return "arcane"

func _player_ghost(card:Dictionary)->Control:
 var ghost=Card.new();ghost.interactive=false;ghost.setup(card,game.db.info(card),spells,font);fx.add_child(ghost);ghost.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var id=str(card.uid)
 if cards.has(id):
  var original=cards[id];ghost.pivot_offset=original.pivot_offset;ghost.global_position=original.global_position;ghost.rotation=original.rotation;ghost.scale=original.scale;original.visible=false
 else:ghost.position=Vector2(100,290);ghost.scale=Vector2.ONE*0.85
 outgoing_uid=id;_layout_hand();return ghost

func _set_visual_values(event:Dictionary)->void:
 var id=str(event.get("target","self"))
 if units.has(id):
  var state=units[id].unit.duplicate(true)
  if event.has("hp_after"):state.hp=event.hp_after
  if event.has("block_after"):state.block=event.block_after
  if event.type=="shield":state.block=event.get("new_value",int(state.get("block",0))+int(event.get("amount",0)))
  units[id].update_data(state)
 if object_nodes.has(id):
  var node=object_nodes[id];var state:Dictionary=node.get_meta("visual_state",{}).duplicate(true)
  if event.has("hp_after"):state.hp=event.hp_after
  if event.has("block_after"):state.block=event.block_after
  if event.type=="shield":state.block=event.get("new_value",state.get("block",0))
  node.update_data(state)
 if id=="self" and event.has("hp_after") and is_instance_valid(header_hp):header_hp.text=str(int(event.hp_after))


func _atlas(texture:Texture2D,index:int,cols:int,rows:int)->AtlasTexture:
 var a=AtlasTexture.new();a.atlas=texture;var tile=texture.get_size()/Vector2(cols,rows);a.region=Rect2(Vector2(index%cols,index/cols)*tile,tile);return a

func _selected_card()->Dictionary:
 if game.s.get("battle")==null:return {}
 if not selected_binding.is_empty():
  for bind in game.s.battle.slots:
   if bind!=null and bind.bid==selected_binding:return bind.card
 for c in game.s.battle.hand:
  if str(c.uid)==selected_uid:return c
 return {}

func _card_pressed(uid:String)->void:
 if busy or is_instance_valid(current_modal):return
 ignore_left_release=false
 selected_uid=uid;selected_binding="";selected_mode="block"
 if cards.has(uid):fx.grab_card(cards[uid])
 _update_battle()

func _card_hover(_uid:String,_on:bool)->void:
 if not busy:_hover_hand()

func _drag_start(uid:String)->void:
 if busy or is_instance_valid(current_modal):return
 dragged_uid=uid;hovered_uid="";var c=cards.get(uid)
 if not c:return
 c.begin_drag(_pointer());c.z_index=85
 drag_insert_index=_drag_gap(_pointer());_layout_hand()

func _drag_move(uid:String,point:Vector2)->void:
 if dragged_uid==uid and cards.has(uid):
  cards[uid].follow_pointer(point,0.0)
  var gap=_drag_gap(point)
  if gap!=drag_insert_index:drag_insert_index=gap;_layout_hand()

func _card_release(_uid:String,_point:Vector2)->void:
 if ignore_left_release:ignore_left_release=false;return
 if not dragged_uid.is_empty():_end_drag()

func _end_drag()->void:
 if busy or is_instance_valid(current_modal) or not game.s.get("battle") or game.s.battle.phase!="player":_cancel_selection();return
 var uid=dragged_uid;dragged_uid=""
 if not cards.has(uid):return
 cards[uid].end_drag()
 var point=_pointer();var insertion=drag_insert_index;drag_insert_index=-1
 for i in range(slot_nodes.size()):
  if slot_nodes[i].get_global_rect().has_point(point) and game.s.battle.slots[i]==null:
   _layout_hand();_install_dialog(i);return
 var target=_target_at(point);var c=_selected_card()
 if not target.is_empty() and game.valid_target(c,target,selected_mode):_target_clicked(target)
 elif not c.is_empty() and game.target_kind(c,selected_mode)=="none" and Rect2(350,205,982,446).has_point(point):_cast_selected()
 elif insertion>=0:
  var state=game.s.battle;state.hand.erase(c);state.hand.insert(clampi(insertion,0,state.hand.size()),c)
  selected_uid="";hovered_uid="";cards[uid].set_selected(false);cards[uid].hover=false
  _layout_hand();fx.sound("click");game.commit()
 else:
  selected_uid="";hovered_uid="";cards[uid].set_selected(false);cards[uid].hover=false
  _layout_hand();fx.sound("click")

func _target_at(point:Vector2)->String:
 for id in units:
  if units[id].get_global_rect().has_point(point):return id
 for id in object_nodes:
  if object_nodes[id].contains_global(point):return id
 return ""

func _input(event:InputEvent)->void:
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
  _cancel_or_close();get_viewport().set_input_as_handled();return
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_F11:
   var mode=DisplayServer.window_get_mode();DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN);get_viewport().set_input_as_handled();return
  if event.keycode==KEY_ESCAPE:
   _cancel_or_close();get_viewport().set_input_as_handled();return
  if is_instance_valid(current_modal) or not dragged_uid.is_empty():return
  if not at_title and game.s.screen=="battle" and not busy:
   if event.keycode>=KEY_1 and event.keycode<=KEY_9:
    var i=event.keycode-KEY_1
    if i<game.s.battle.hand.size():_card_pressed(str(game.s.battle.hand[i].uid))
   if event.keycode==KEY_SPACE:_perform(func():await game.end_turn())
   if event.keycode==KEY_ENTER:_cast_selected()
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
  if ignore_left_release:ignore_left_release=false;get_viewport().set_input_as_handled();return
  if not dragged_uid.is_empty():_end_drag()

func _cancel_selection()->void:
 ignore_left_release=true
 for card in cards.values():
  if is_instance_valid(card):card.force_release();card.set_selected(false);card.hover=false
 dragged_uid="";selected_uid="";selected_binding="";hovered_uid="";drag_insert_index=-1
 if is_instance_valid(fx):fx.clear_aim()
 if game and not at_title and game.s.screen=="battle":_update_battle()

func _cancel_or_close()->void:
 if is_instance_valid(current_modal):
  if current_modal.get_meta("closable",true):
   if choice_waiting:choice_finished.emit([])
   _close_modal();_cancel_selection()
  return
 if not busy:_cancel_selection()

func _notification(what:int)->void:
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT and game and not busy:_cancel_selection()

func _pointer()->Vector2:
 return showcase_pointer if showcase and showcase_pointer.is_finite() else get_global_mouse_position()

func _process(delta:float)->void:
 if not game or at_title or game.s.screen!="battle":return
 if not dragged_uid.is_empty() and cards.has(dragged_uid):cards[dragged_uid].follow_pointer(_pointer(),delta)
 else:_hover_hand()
 var c=_selected_card()
 if not busy and not c.is_empty() and game.target_kind(c,selected_mode)!="none" and not is_instance_valid(current_modal):
  var from=Vector2(800,790)
  if cards.has(selected_uid):from=cards[selected_uid].get_global_transform()*Vector2(85,30)
  elif not selected_binding.is_empty():
   for i in range(game.s.battle.slots.size()):
    var b=game.s.battle.slots[i]
    if b!=null and b.bid==selected_binding:from=slot_nodes[i].global_position+slot_nodes[i].size/2
  var target=_target_at(_pointer())
  fx.aim(from,_pointer(),not target.is_empty() and game.valid_target(c,target,selected_mode))
 else:fx.clear_aim()

func _target_clicked(id:String)->void:
 if busy or is_instance_valid(current_modal):return
 var c=_selected_card()
 if c.is_empty():
  if id!="self":focused_enemy_id=id;enemy_layout_signature="";_sync_enemy_hand()
  return
 if not game.valid_target(c,id,selected_mode):_toast("这张牌不能指定此目标");return
 var uid=selected_binding if not selected_binding.is_empty() else selected_uid;var from_slot=not selected_binding.is_empty();var mode=selected_mode
 _perform(func():await game.play(uid,id,mode,from_slot))

func _cast_selected()->void:
 var c=_selected_card()
 if busy or c.is_empty() or game.target_kind(c,selected_mode)!="none":return
 var uid=selected_binding if not selected_binding.is_empty() else selected_uid;var from_slot=not selected_binding.is_empty();var mode=selected_mode
 _perform(func():await game.play(uid,"self",mode,from_slot))

func _toggle_mode()->void:
 selected_mode="repair" if selected_mode=="block" else "block";_update_battle()
func _toggle_fast()->void:
 game.s.settings.fast=not game.s.settings.fast;fx.fast=game.s.settings.fast;_toast("快速结算已开启" if fx.fast else "恢复完整动画节奏");game.save_game()

func _slot_input(event:InputEvent,index:int)->void:
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and not busy:
  if game.s.battle.slots[index]==null:_install_dialog(index)
  else:_rule_dialog(index)
func _object_input(event:InputEvent,id:String)->void:
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and not busy and not is_instance_valid(current_modal):
  if not _selected_card().is_empty():_target_clicked(id)
  elif object_nodes.has(id) and object_nodes[id].poke():
   fx.sound(object_nodes[id].sound_cue(),object_nodes[id].reaction_count)

func _perform(action:Callable)->void:
 if busy:return
 busy=true;_set_header_busy();fx.clear_aim();chain_count=0
 if is_instance_valid(inspect_box):inspect_box.visible=false
 if game.s.screen=="battle":_update_battle()
 await action.call()
 busy=false;selected_uid="";selected_binding="";dragged_uid="";hovered_uid="";outgoing_uid=""
 game.save_game();_refresh()

func _anchor(id:String)->Vector2:
 if units.has(id):return units[id].get_global_transform()*(units[id].size*Vector2(0.5,0.35))
 if object_nodes.has(id):return object_nodes[id].target_center()
 if id=="energy":return Vector2(152,726)
 return Vector2(800,435)

func _present(e:Dictionary)->void:
 if not is_inside_tree():return
 var kind=str(e.get("type",""))
 fx.fast=bool(game.s.settings.get("fast",false)) or chain_count>8;fx.reduced=not bool(game.s.settings.get("motion",true))
 if kind=="cast":
  chain_count=0;fx.clear_aim();var card=e.card;var ghost=_player_ghost(card);var definition=game.db.info(card)
  var stage=_anchor(str(e.target))+Vector2(0,75) if definition.type=="attack" else Vector2(800,431)
  await fx.card_flight(ghost,stage,"cast")
  if card.id=="C09":
   for enemy in game.s.battle.enemies:
    if enemy.hp>0:fx.projectile(stage,_anchor(enemy.id),"physical",0.23)
   await get_tree().create_timer(0.24 if not fx.fast else 0.08).timeout
  else:await fx.projectile(stage,_anchor(str(e.target)),_effect_style(definition),0.23 if not fx.fast else 0.09)
 elif kind=="install":
  var ghost=_player_ghost(e.card);var center=slot_nodes[int(e.slot)].global_position+Vector2(124,52)
  await fx.card_flight(ghost,center,"install")
  fx.pulse(slot_nodes[int(e.slot)],GOLD)
 elif kind=="rule":
  chain_count+=1;chain_label.text="%d 连锁"%chain_count if chain_count>1 else "规则响应"
  var index=int(e.get("slot",0));var from=Vector2(189,290+maxi(0,index)*115)
  if index>=0 and index<slot_nodes.size():fx.pulse(slot_nodes[index],CYAN)
  fx.sound("rule",chain_count)
  fx.rule_thread(from,_anchor(str(e.target)),CYAN)
  await fx.projectile(from,_anchor(str(e.target)),_effect_style(game.db.info(e.card)),0.08 if chain_count>8 or fx.fast else 0.22)
 elif kind=="enemy_draw":
  if game.s.screen!="battle":return
  if game.s.battle.phase=="player" and not focused_enemy_id.is_empty() and focused_enemy_id!=str(e.enemy_id):return
  _sync_enemy_hand(e.enemy,e.cards)
  if not e.cards.is_empty():await get_tree().create_timer(0.22 if fx.fast else 0.38+mini(e.cards.size(),4)*0.065).timeout
 elif kind=="enemy_cast":
  if not units.has(str(e.enemy.id)):return
  var card=e.card;var definition=e.definition.duplicate(true);definition.enemy=true
  var from=_enemy_center(int(e.hand_index),e.hand_after.size()+1)
  var scale_from=Vector2.ONE*0.315;var angle=0.0
  if enemy_hand_views.has(str(card.uid)):
   var original=enemy_hand_views[str(card.uid)];from=original.get_global_transform()*(original.size/2);scale_from=original.scale;angle=original.rotation
  var ghost=Card.new();ghost.interactive=false;ghost.setup(card,definition,spells,font);ghost.set_face_down(true);ghost.pivot_offset=ghost.size/2;ghost.scale=scale_from;ghost.rotation=angle;fx.add_child(ghost);ghost.position=from-ghost.size/2
  active_enemy_ghost=ghost;focused_enemy_id=str(e.enemy.id);_sync_enemy_hand(e.enemy)
  var center=Vector2(995,352)
  await fx.enemy_reveal(ghost,from,center)
  var target=str(e.target);var style=_effect_style(definition)
  if definition.type=="attack":await fx.actor_strike(units[str(e.enemy.id)],_anchor(target),style)
  else:
   await fx.projectile(center,_anchor(target),style,0.27 if not fx.fast else 0.09)
   if int(definition.get("strength",0))>0:fx.float_text("力量 +%d"%definition.strength,_anchor(str(e.enemy.id)),GOLD)
 elif kind=="enemy_discard":
  if is_instance_valid(active_enemy_ghost):await fx.card_flight(active_enemy_ghost,enemy_discard_button.get_global_rect().get_center(),"enemy")
  active_enemy_ghost=null
  _sync_enemy_hand(e.enemy)
  fx.pulse(enemy_discard_button,GOLD)
  await get_tree().create_timer(0.035 if fx.fast else 0.1).timeout
 elif kind in ["hit","damage","burn"]:
  _set_visual_values(e)
  var target=str(e.get("target","self"));var amount=int(e.get("amount",0));var blocked=int(e.get("blocked",0));var point=_anchor(target)
  var node=units.get(target,object_nodes.get(target))
  if blocked>0 and amount>0:fx.float_text("格挡 %d"%blocked,point+Vector2(0,34),CYAN)
  if is_instance_valid(node):
   await fx.impact(node,amount if amount>0 else blocked,"damage" if amount>0 else "block")
   if e.get("dead",false) and units.has(target):
    fx.burst(point,GOLD,20,0.75)
    var death=node.create_tween().set_parallel(true);death.tween_property(node,"modulate:a",0.0,0.22);death.tween_property(node,"scale",Vector2.ONE*0.88,0.22);await death.finished
 elif kind in ["shield","energy","heal"]:
  _set_visual_values(e)
  var target=str(e.get("target","energy" if kind=="energy" else "self"));var amount=int(e.get("amount",0))
  if kind=="energy":
   energy_label.text=str(int(e.get("new_value",game.s.battle.energy)));fx.float_text("+%d 能量"%amount,_anchor("energy"),CYAN);fx.ring(_anchor("energy"),CYAN,64);fx.sound("energy");fx.pulse(energy_label,CYAN)
  else:
   var node=units.get(target,object_nodes.get(target))
   if is_instance_valid(node):await fx.impact(node,amount,kind)
 elif kind=="break":
  if object_nodes.has(str(e.target)):await fx.impact(object_nodes[str(e.target)],0,"break")
 elif kind=="turn":
  _refresh();chain_count=0
  if is_instance_valid(chain_label):chain_label.text=""
  await fx.banner("你的回合" if e.phase=="player" else "对手出牌","抽牌完成 · 写下新的规则" if e.phase=="player" else "观察手牌、费用与出牌顺序","turn")
 elif kind=="draw":pass
 elif kind=="travel":
  await create_tween().tween_property(scene_root,"modulate:a",0.0,0.15).finished
 elif kind=="resolve":
  outgoing_uid="";_refresh()


func _modal(title:String,small:bool=false,closable:bool=true)->Control:
 _close_modal()
 var shade=ColorRect.new();shade.color=Color(0.015,0.023,0.035,0.83);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_STOP;modal_root.add_child(shade);current_modal=shade
 shade.set_meta("closable",closable)
 var p=_panel(shade,Vector2(300,155) if small else Vector2(230,113),Vector2(1000,665) if small else Vector2(1140,785),0.99,GOLD);p.mouse_filter=Control.MOUSE_FILTER_STOP
 _label(p,title,Vector2(30,16),Vector2(p.size.x-105,50),27,GOLD,HORIZONTAL_ALIGNMENT_LEFT,true)
 if closable:_button(p,"×",Vector2(p.size.x-70,20),Vector2(42,42),func():
  if choice_waiting:choice_finished.emit([])
  _close_modal())
 p.pivot_offset=p.size/2;p.scale=Vector2.ONE if fx.reduced else Vector2(.95,.95);p.modulate.a=0.0
 var tw=create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT);tw.tween_property(p,"scale",Vector2.ONE,.2);tw.tween_property(p,"modulate:a",1.0,.2)
 return p
func _close_modal()->void:
 if is_instance_valid(current_modal):current_modal.queue_free();current_modal=null
func _info(title:String,text:String)->void:
 var p=_modal(title,true)
 var l=_label(p,text,Vector2(35,94),Vector2(920,494),20,PALE);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.vertical_alignment=VERTICAL_ALIGNMENT_TOP

func _choose(data:Dictionary)->Array:
 choice_waiting=true
 var mandatory=game.s.screen=="battle" and int(data.get("min",0))>0
 var p=_modal(str(data.title),false,not mandatory);var chosen:Array=[]
 _label(p,"选择 %s–%s 张卡牌"%[data.min,data.max],Vector2(30,67),Vector2(950,35),17,MUTED)
 var scroll=ScrollContainer.new();scroll.position=Vector2(27,116);scroll.size=Vector2(1085,571);p.add_child(scroll)
 var grid=GridContainer.new();grid.columns=5;grid.add_theme_constant_override("h_separation",32);grid.add_theme_constant_override("v_separation",24);scroll.add_child(grid)
 var confirm=_button(p,"确认选择",Vector2(833,719),Vector2(240,46),func():choice_finished.emit(chosen.duplicate()),true);confirm.disabled=int(data.min)>0
 for c in data.cards:
  var v=Card.new();v.drag_enabled=false;v.setup(c,game.db.info(c),spells,font);grid.add_child(v)
  v.pressed.connect(func(uid):
   if uid in chosen:chosen.erase(uid)
   elif chosen.size()<int(data.max):chosen.append(uid)
   elif int(data.max)==1:chosen.clear();chosen.append(uid)
   for other in grid.get_children():other.set_selected(str(other.card.uid) in chosen)
   confirm.disabled=chosen.size()<int(data.min))
 var result=await choice_finished
 choice_waiting=false;_close_modal();return result

func _deck()->void:
 if not game.s.get("run") is Dictionary:_catalog();return
 _show_cards("完整卡组 · %s 张"%game.s.run.deck.size(),game.s.run.deck.duplicate(true))
func _zone(zone:String)->void:
 _show_cards({"draw":"抽牌堆 · 不公开顺序","discard":"弃牌堆","exhaust":"消耗区"}[zone],game.s.battle[zone].duplicate(true))
func _show_cards(title:String,list:Array)->void:
 var p=_modal(title)
 var scroll=ScrollContainer.new();scroll.position=Vector2(28,91);scroll.size=Vector2(1080,646);p.add_child(scroll)
 var grid=GridContainer.new();grid.columns=5;grid.add_theme_constant_override("h_separation",30);grid.add_theme_constant_override("v_separation",22);scroll.add_child(grid)
 list.sort_custom(func(a,b):return str(a.id)<str(b.id))
 for c in list:
  var v=Card.new();v.setup(c,game.db.info(c),spells,font);v.interactive=false;v.mouse_filter=Control.MOUSE_FILTER_IGNORE;grid.add_child(v)
func _catalog()->void:
 var list:Array=[]
 for id in game.db.cards:list.append({"id":id,"uid":id,"up":false})
 _show_cards("卡牌图鉴",list)

func _install_dialog(index:int)->void:
 var c=_selected_card()
 if c.is_empty() or not selected_binding.is_empty():_toast("选中或拖入一张手牌，再为它选择触发条件。") ;return
 var p=_modal("编织规则 · %s"%game.db.info(c).name)
 var selected_trigger=["T01"];var target_ids:Array=[]
 var fee=maxi(1,int(game.db.info(c).cost))
 _label(p,"安装支付 %s 能量，占用这张卡；每次响应再支付 %s 能量。"%[fee,fee],Vector2(30,76),Vector2(1070,40),17,MUTED)
 var buttons:Array=[]
 for i in range(game.db.triggers.size()):
  var tr=game.db.triggers[i]
  var b=_button(p,str(tr.name)+"\n"+str(tr.text),Vector2(30+(i%2)*540,136+(i/2)*103),Vector2(513,87),func():
   selected_trigger[0]=tr.id
   for x in buttons:x.modulate=Color.WHITE
   buttons[i].modulate=Color("a4e4e9"))
  b.add_theme_font_size_override("font_size",15);buttons.append(b)
 var option=OptionButton.new();option.position=Vector2(176,566);option.size=Vector2(366,44);option.add_theme_font_override("font",font);option.add_theme_font_size_override("font_size",19);p.add_child(option)
 _label(p,"执行目标",Vector2(32,566),Vector2(138,44),19,GOLD)
 var options=[{"id":"self","name":"自己"}]+game.s.battle.enemies+game.s.battle.objects
 for target in options:
  if game.valid_target(c,target.id,selected_mode):target_ids.append(target.id);option.add_item(str(target.name))
 if game.target_kind(c,selected_mode)=="none":option.clear();target_ids=["self"];option.add_item("无需目标")
 _label(p,"本回合第一次成功响应 −1 能量。消耗牌响应一次后移出战斗。",Vector2(32,635),Vector2(1064,48),16,MUTED)
 var confirm=_button(p,"确认安装 · %s 能量"%fee,Vector2(748,708),Vector2(336,53),func():
  var target=str(target_ids[option.selected]) if not target_ids.is_empty() else "self";var uid=str(c.uid);var trigger=str(selected_trigger[0]);var mode=selected_mode
  _close_modal();_perform(func():await game.install(uid,index,trigger,target,mode)),true)
 confirm.disabled=game.s.battle.energy<fee or target_ids.is_empty()

func _rule_dialog(index:int)->void:
 var b=game.s.battle.slots[index]
 if b==null:return
 var p=_modal("规则管理 · %s"%game.db.info(b.card).name,true)
 _label(p,str(game.db.info(b.card).text),Vector2(34,99),Vector2(921,90),22,PALE).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var options=OptionButton.new();options.position=Vector2(207,224);options.size=Vector2(510,45);options.add_theme_font_override("font",font);options.add_theme_font_size_override("font_size",19);p.add_child(options)
 var ids:Array=[]
 for target in [{"id":"self","name":"自己"}]+game.s.battle.enemies+game.s.battle.objects:
  if game.valid_target(b.card,target.id,b.mode):ids.append(target.id);options.add_item(str(target.name));if target.id==b.target:options.select(ids.size()-1)
 _label(p,"响应目标",Vector2(34,224),Vector2(160,44),20,GOLD)
 _label(p,"最低保留能量",Vector2(34,302),Vector2(220,44),20,GOLD)
 var reserve=SpinBox.new();reserve.position=Vector2(266,302);reserve.size=Vector2(180,45);reserve.min_value=0;reserve.max_value=9;reserve.value=b.reserve;p.add_child(reserve)
 _button(p,"保存配置",Vector2(718,302),Vector2(230,45),func():game.configure_rule(b.bid,{"target":ids[options.selected] if not ids.is_empty() else "self","reserve":int(reserve.value)});_close_modal();_refresh(),true)
 _button(p,"关闭规则" if b.enabled else "启用规则",Vector2(35,435),Vector2(280,54),func():game.toggle_rule(b.bid);_close_modal();_refresh())
 _button(p,"拆出并手动打出",Vector2(343,435),Vector2(280,54),func():selected_binding=b.bid;selected_uid="";selected_mode=b.mode;_close_modal();_refresh()).disabled=game.s.battle.phase!="player" or game.s.battle.paused
 _button(p,"移入弃牌堆",Vector2(650,435),Vector2(298,54),func():game.remove_rule(b.bid);_close_modal();_refresh()).disabled=game.s.battle.phase!="player"
 _label(p,"攻击目标消失后改打生命最低的敌人；修复目标消失则跳过响应。",Vector2(34,538),Vector2(920,70),17,MUTED).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func _chain_pause()->void:
 if is_instance_valid(current_modal) or game.s.screen!="battle" or not game.s.battle.paused:return
 var p=_modal("连锁暂歇",true,false)
 _label(p,"已连续执行一批规则响应。\n合法循环仍可以继续；你也可以停止这次连锁，重新安排下一步。",Vector2(45,125),Vector2(900,215),25,PALE).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 _button(p,"继续连锁",Vector2(160,438),Vector2(300,67),func():_close_modal();_perform(func():await game.resume_chain()),true)
 _button(p,"停止本次连锁",Vector2(526,438),Vector2(300,67),func():_close_modal();_perform(func():await game.stop_chain()))

func _settings()->void:
 if busy:return
 var p=_modal("游戏设置",true)
 _button(p,"完整动效：%s"%("开" if game.s.settings.get("motion",true) else "关"),Vector2(70,131),Vector2(855,65),func():game.s.settings.motion=not game.s.settings.get("motion",true);_close_modal();_refresh();_settings())
 _button(p,"快速结算：%s"%("开" if game.s.settings.fast else "关"),Vector2(70,222),Vector2(855,65),func():game.s.settings.fast=not game.s.settings.fast;_close_modal();_refresh();_settings())
 _button(p,"音效：%s"%("开" if game.s.settings.sound else "关"),Vector2(70,313),Vector2(855,65),func():game.s.settings.sound=not game.s.settings.sound;_close_modal();_refresh();_settings())
 _button(p,"卡牌图鉴",Vector2(70,414),Vector2(855,58),_catalog)
 _label(p,"F11 全屏 · 数字键选牌 · 空格结束回合 · Esc 取消选择\n原生离线客户端，进度会自动保存。",Vector2(70,519),Vector2(855,88),18,MUTED,HORIZONTAL_ALIGNMENT_CENTER)
 game.save_game()
func _help()->void:
 _info("写下第一条规则","① 直接出牌\n点击手牌再点击目标，或把牌拖到敌人、自己或物件上。无目标牌可以按「施放」，或拖到战场中间。\n\n② 组装规则\n选中手牌后点击左侧空规则槽，或直接拖入空槽；选择触发条件与目标，支付安装费用。它会占用这张实体牌。\n\n③ 连锁与代价\n规则触发时支付响应能量；每回合第一次成功响应减免 1。建议把攻击安装到「施术之后」，通过防御、过牌发动攻击。\n\n④ 观察对手\n敌人有独立牌组、手牌和费用，逐张亮牌后发动效果。点击敌人切换查看它的牌组和弃牌；上方卡背是它当前的真实手牌。\n\n⑤ 争夺战场\n敌人通过卡牌利用物件。攻击可破坏，护甲可以保护；预计行动会根据场面调整。")
func _home()->void:
 if busy:_toast("请等当前效果结算完成");return
 if not practice_backup.is_empty():game.restore(practice_backup);practice_backup={}
 at_title=true;built_key="";_close_modal();_refresh()
func _toast(text:String)->void:
 if text.is_empty():return
 var p=_panel(self,Vector2(425,103),Vector2(750,56),0.96,GOLD);p.z_index=150
 _label(p,text,Vector2(14,3),Vector2(722,50),17,PALE,HORIZONTAL_ALIGNMENT_CENTER)
 var t=create_tween();t.tween_interval(2.8);t.tween_property(p,"modulate:a",0.0,0.3);t.tween_callback(p.queue_free)

func _screen_action(action:String,args:Array=[])->void:
 if busy:return
 fx.sound("click")
 match action:
  "new":
   if game.s.get("run",{}) is Dictionary and not game.s.run.is_empty() and not game.s.run.get("finished",false) and not game.s.run.get("practice",false):
    var p=_modal("开启新的旅程？",true);_label(p,"当前冒险会被替换，已解锁的起始卡组会保留。",Vector2(40,170),Vector2(916,100),24,PALE,HORIZONTAL_ALIGNMENT_CENTER);_button(p,"确认启程",Vector2(325,391),Vector2(350,65),func():_close_modal();at_title=false;game.new_run(str(args[0]) if not args.is_empty() else "balanced",false);_refresh(),true)
   else:at_title=false;game.new_run(str(args[0]) if not args.is_empty() else "balanced",false);_refresh()
  "continue":at_title=false;built_key="";_refresh()
  "practice":
   busy=true;practice_backup=game.snapshot();at_title=false;game.new_run("balanced",true,1001);_refresh()
   await game.cue("resolve")
   await fx.banner("规则练习","拖拽组装 · 观察对手出牌","turn")
   busy=false;_refresh()
  "enter":_perform(func():await game.enter_node(str(args[0])))
  "route":game.choose_route(str(args[0]));_refresh()
  "reward":_perform(func():await game.claim_reward(str(args[0])))
  "skip_reward":_perform(func():await game.claim_reward(""))
  "buy":_perform(func():await game.shop_action("buy",int(args[0])))
  "shop_relic":_perform(func():await game.shop_action("relic"))
  "shop_delete":_perform(func():await game.shop_action("delete"))
  "shop_upgrade":_perform(func():await game.shop_action("upgrade"))
  "camp":_perform(func():await game.camp_action(str(args[0])))
  "relic":_perform(func():await game.claim_relic(str(args[0])))
  "event":_perform(func():await game.event_action(str(args[0])))
  "scene_object":_perform(func():await game.interact_object(str(args[0])))
  "leave_node":
   var n=game.s.run.node
   if n.type in ["camp","treasure"] and not n.get("serviceDone",false):
    var p=_modal("还有一份选择留在这里",true);_label(p,"你还没有使用营地行动或领取遗物。确定现在离开？",Vector2(40,170),Vector2(916,120),23,PALE,HORIZONTAL_ALIGNMENT_CENTER);_button(p,"继续留在这里",Vector2(144,389),Vector2(310,62),_close_modal,true);_button(p,"确认离开",Vector2(545,389),Vector2(310,62),func():_close_modal();_perform(func():await game.finish_node()))
   else:_perform(func():await game.finish_node())
  "home":_home()
  "deck":_deck()
  "loadout":pass

func _show_move(point:Vector2,duration:float)->void:
 var t=create_tween();t.tween_property(self,"showcase_pointer",point,duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
 await t.finished

func _show_uid(id:String)->String:
 for c in game.s.battle.hand:
  if c.id==id:return str(c.uid)
 return ""

func _show_drag(uid:String,point:Vector2,duration:float=0.65)->void:
 if not cards.has(uid):return
 showcase_pointer=cards[uid].get_global_transform()*Vector2(85,65)
 _card_pressed(uid);_drag_start(uid)
 await _show_move(point,duration)
 await get_tree().create_timer(0.16).timeout
 _end_drag()
 while busy:await get_tree().process_frame

func _showcase()->void:
 await get_tree().create_timer(0.6).timeout
 await _screen_action("practice",[])
 showcase_pointer=Vector2(500,500)
 await get_tree().create_timer(0.8).timeout
 for id in ["C02","C06","C14"]:
  var uid=_show_uid(id)
  if cards.has(uid):await _show_move(cards[uid].base_position+Vector2(85,70),0.33)
 await get_tree().create_timer(0.35).timeout
 var uid=_show_uid("C01")
 # Use the same drag and release handlers as manual play, including invalid-drop return.
 await _show_drag(uid,Vector2(570,520),0.65)
 showcase_pointer=Vector2(530,520)
 await get_tree().create_timer(0.55).timeout
 await _show_drag(uid,slot_nodes[0].global_position+slot_nodes[0].size/2,0.8)
 await get_tree().create_timer(0.45).timeout
 _close_modal()
 await _perform(func():await game.install(uid,0,"T02","enemy0"))
 for id in ["C24","C02","C06"]:
  if game.s.screen!="battle":break
  uid=_show_uid(id)
  if uid.is_empty():continue
  var target=object_nodes["object0"].global_position+object_nodes["object0"].size/2 if id=="C06" else units["self"].global_position+units["self"].size/2 if id=="C02" else Vector2(950,490)
  await _show_drag(uid,target,0.55)
  await get_tree().create_timer(0.25).timeout
 showcase_pointer=Vector2(1450,550)
 if game.s.screen=="battle":await _perform(func():await game.end_turn())
 await get_tree().create_timer(1.5).timeout
 print("SHOWCASE_COMPLETE fps=",Engine.get_frames_per_second())

func _verify_build()->void:
 # Explicit isolated-save QA mode also works inside the exported executable.
 showcase=true;showcase_pointer=Vector2(1590,985)
 var folder=OS.get_executable_path().get_base_dir()+"/verification"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--verify-output="):folder=arg.trim_prefix("--verify-output=")
 DirAccess.make_dir_recursive_absolute(folder)
 await _verify_capture(folder,"title")
 await _screen_action("practice",[])
 await _verify_capture(folder,"battle")
 var prop=object_nodes.get("object0")
 if not is_instance_valid(prop) or prop.sprite==null:
  push_error("BUILD_VERIFY_FAILED: physical object asset missing");get_tree().quit(3);return
 var before=game.snapshot()
 var tap=InputEventMouseButton.new();tap.button_index=MOUSE_BUTTON_LEFT;tap.pressed=true
 _object_input(tap,"object0")
 if prop.reaction_count!=1 or game.snapshot()!=before:
  push_error("BUILD_VERIFY_FAILED: object reaction changed combat state");get_tree().quit(4);return
 await _verify_capture(folder,"prop-click")
 var attack=_show_uid("C01")
 await _perform(func():await game.play(attack,"object0","block",false))
 if not prop.dead or int(game.s.battle.block)!=5:
  push_error("BUILD_VERIFY_FAILED: object break lost its combat reward");get_tree().quit(5);return
 await _verify_capture(folder,"prop-destroyed")
 await _perform(func():await game.end_turn())
 if game.s.screen!="battle" or int(game.s.battle.turn)!=2:
  push_error("BUILD_VERIFY_FAILED: enemy turn did not return to player");get_tree().quit(2);return
 await _verify_capture(folder,"enemy-turn")
 _home();game.new_run("balanced",false,101);at_title=false;_refresh()
 await _verify_capture(folder,"map")
 print("BUILD_VERIFY_OK: title, practice, physical object click, object break reward, enemy turn, route map; fps=",Engine.get_frames_per_second())
 fx.cleanup()
 await get_tree().create_timer(0.25).timeout
 get_tree().quit(0)

func _verify_capture(folder:String,label:String)->void:
 await get_tree().create_timer(0.6).timeout
 await RenderingServer.frame_post_draw
 var result=get_viewport().get_texture().get_image().save_png(folder+"/"+label+".png")
 if result!=OK:push_error("BUILD_CAPTURE_FAILED: "+label)
