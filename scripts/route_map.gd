extends Control
## A presentation of the engine's real next nodes, completed history and previews.
## Drawing this chart never consumes gameplay RNG or changes saved state.
signal node_selected(node: Dictionary)
const FantasySkin = preload("res://scripts/material_skin.gd")
const ICONS = {"battle":"swords","elite":"skull","boss":"crown","shop":"store","event":"landmark","camp":"flame","treasure":"gift","service":"landmark","reststop":"flame"}
const NAMES = {"battle":"遭遇","elite":"精英","boss":"领主","shop":"商人","event":"遗迹","camp":"营地","treasure":"宝藏","service":"互补驿站","reststop":"互补休整"}
var run: Dictionary
var font: Font
var reduced := false
var selected_id := ""
var rows: Array = []
var node_buttons: Dictionary = {}
var clock := 0.0

func setup(state: Dictionary, f: Font, motion: bool) -> void:
	run=state; font=f; reduced=not motion
	mouse_filter=Control.MOUSE_FILTER_PASS
	size=Vector2(748,836)
	var next: Array=run.get("next",[])
	selected_id=str(next[0].id) if not next.is_empty() else ""
	for depth in range(1,9):
		var row: Array=[]
		var types: Array=preview_types(depth,run)
		var actual: Array=[]
		var history: Array=run.get("history",[]).filter(func(n):return int(n.chapter)==int(run.chapter) and int(n.depth)==depth)
		if depth==int(run.step)+1:
			actual=next
			types=actual.map(func(n):return str(n.type))
		for i in range(types.size()):
			var done: bool=not history.is_empty() and int(history[0].get("branch",0))==i
			var typ: String=str(history[0].type) if done else str(types[i])
			var entry={"point":point_for(depth,i,types.size()),"type":typ,"depth":depth,"done":done,"active":depth==int(run.step)+1,"node":actual[i] if i<actual.size() else {}}
			row.append(entry)
			_add_node(entry)
		rows.append(row)
	queue_redraw()

static func preview_types(depth: int, state: Dictionary) -> Array:
	match depth:
		2:return ["event","shop"]
		3:return ["battle","elite"]
		4:return ["shop" if state.pairFirst["2"]=="event" else "event"] if state.get("pairFirst",{}).has("2") else ["service"]
		6:return ["treasure","camp"]
		7:return ["camp" if state.pairFirst["6"]=="treasure" else "treasure"] if state.get("pairFirst",{}).has("6") else ["reststop"]
		8:return ["boss"]
		_:return ["battle","battle"]

static func point_for(depth: int, branch: int, count: int) -> Vector2:
	var offsets=[0,0,-24,17,0,-19,14,0,0]
	return Vector2(374+(0 if count==1 else (-118 if branch==0 else 118))+offsets[depth],738-(depth-1)*90)

func _add_node(entry: Dictionary) -> void:
	var button=Button.new()
	button.position=entry.point-Vector2(35,35);button.size=Vector2(70,70)
	for state in ["normal","hover","pressed","disabled","focus"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	button.icon=load("res://assets/icons/"+ICONS[entry.type]+".svg")
	button.expand_icon=true;button.add_theme_constant_override("icon_max_width",36)
	button.alignment=HORIZONTAL_ALIGNMENT_CENTER
	button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND if entry.active else Control.CURSOR_HELP
	button.tooltip_text=NAMES[entry.type]+(" · 点击选择" if entry.active else " · 已走过" if entry.done else " · 后续预览，尚不可进入")
	if entry.type=="service":button.tooltip_text="互补驿站：第 2 站选遗迹，这里就是商店；反之亦然。"
	if entry.type=="reststop":button.tooltip_text="互补休整：第 6 站选宝藏，这里就是营地；反之亦然。"
	button.modulate.a=1.0 if entry.active or entry.done else 0.56
	button.focus_mode=Control.FOCUS_ALL if entry.active else Control.FOCUS_NONE
	if entry.active:
		button.pressed.connect(func():select_node(str(entry.node.id)))
		node_buttons[str(entry.node.id)]=button
	button.mouse_entered.connect(queue_redraw);button.mouse_exited.connect(queue_redraw)
	add_child(button)

func select_node(id: String) -> void:
	for node: Dictionary in run.get("next",[]):
		if str(node.id)==id:
			selected_id=id;queue_redraw();node_selected.emit(node);return

func _process(delta: float) -> void:
	if reduced:return
	clock+=minf(delta,0.05)
	queue_redraw()

func _path(from: Vector2, to: Vector2, completed: bool, bright: bool) -> void:
	var direction=(to-from).normalized()
	var a=from+direction*34
	var b=to-direction*34
	var color=Color("826130") if completed else Color(0.34,0.26,0.17,0.78 if bright else 0.3)
	var points=PackedVector2Array()
	for i in range(25):
		var t=float(i)/24.0
		var p=a.lerp(b,t)+Vector2(sin(t*PI)*14.0*(1.0 if to.x>=from.x else -1.0),0)
		points.append(p)
	if completed:
		draw_polyline(points,Color(0.36,0.22,0.1,0.20),5,true)
		draw_polyline(points,color,2.3,true)
	else:
		for i in range(0,23,3):draw_line(points[i],points[i+2],color,2,true)

func _draw() -> void:
	draw_texture_rect(FantasySkin.texture("map"),Rect2(Vector2.ZERO,size),false)
	for i in range(rows.size()-1):
		for a: Dictionary in rows[i]:
			for b: Dictionary in rows[i+1]:
				# Two branches reconverge at service stops, matching the engine.
				_path(a.point,b.point,a.done and b.done,a.done and b.active)
	for row: Array in rows:
		for e: Dictionary in row:
			var p: Vector2=e.point
			if e.active:
				var selected: bool=str(e.node.id)==selected_id
				for radius in range(40,34,-1):draw_circle(p,radius,Color(0.78,0.49,0.11,0.035))
				draw_circle(p,31,Color(1,0.91,0.65,0.84))
				draw_arc(p,33.0+(0.0 if reduced else sin(clock*2.5)*1.2),0,TAU,72,Color("9b6a25"),3.0 if selected else 1.5,true)
				if selected:draw_arc(p,38,0,TAU,72,Color(0.48,0.29,0.1,0.75),1,true)
			elif e.done:
				draw_circle(p,30,Color(0.81,0.67,0.39,0.8))
				draw_arc(p,33,0,TAU,64,Color("694c29"),2,true)
			else:draw_circle(p,29,Color(0.88,0.78,0.6,0.48))
		var point: Vector2=row[0].point
		draw_string(font,Vector2(89,point.y+6),"%02d"%int(row[0].depth),HORIZONTAL_ALIGNMENT_CENTER,35,14,Color(0.40,0.30,0.19,0.62))
	draw_string(font,Vector2(241,37),"命 运 的 歧 路",HORIZONTAL_ALIGNMENT_CENTER,266,22,Color("634728"))
