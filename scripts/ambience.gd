extends Control
## Lightweight, bounded atmospheric layer. No physics or game rules live here.
var mode := "title"
var reduced := false
var clock := 0.0
var drift := Vector2.ZERO
var background: TextureRect
var title_art: Texture2D
var board_art: Texture2D
var arena_art: Texture2D
var vignette: ColorRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_art = load("res://assets/board.png")
	arena_art = load("res://assets/moonlit-arena.webp")
	title_art = load("res://assets/key-art.png") if ResourceLoader.exists("res://assets/key-art.png") else load("res://assets/moonlit-arena.webp")
	background = TextureRect.new()
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.show_behind_parent = true
	add_child(background)
	vignette=ColorRect.new()
	vignette.mouse_filter=Control.MOUSE_FILTER_IGNORE
	vignette.position=Vector2.ZERO;vignette.size=Vector2(1600,1000)
	var matte=ShaderMaterial.new();matte.shader=load("res://shaders/battle-vignette.gdshader")
	vignette.material=matte;add_child(vignette)
	set_mode(mode)

func set_mode(value: String) -> void:
	mode = value
	if not background: return
	background.texture = title_art if mode == "title" else board_art
	background.modulate = Color.WHITE if mode == "title" else Color(0.96,0.93,0.86)
	vignette.visible=mode=="battle"
	queue_redraw()

func _process(delta: float) -> void:
	if not reduced: clock += minf(delta,0.05)
	var target = Vector2.ZERO if reduced else (get_global_mouse_position()-Vector2(800,500))*0.008
	drift = drift.lerp(target,1.0-exp(-delta*3.0))
	background.position = Vector2(-14,-10)+drift
	background.size = Vector2(1628,1020)
	queue_redraw()

func _rune(center: Vector2, radius: float, squash: float, alpha: float, angle: float) -> void:
	draw_set_transform(center,0,Vector2(1,squash))
	var gold = Color(0.78,0.66,0.43,alpha)
	draw_arc(Vector2.ZERO,radius,0,TAU,160,gold,1.0,true)
	draw_arc(Vector2.ZERO,radius-7,0,TAU,160,Color(gold,alpha*0.35),1.0,true)
	draw_arc(Vector2.ZERO,radius-27,angle,angle+TAU*0.72,100,Color(0.45,0.77,0.85,alpha*0.7),1.0,true)
	for i in range(48):
		var a = TAU*i/48.0+angle
		var d = Vector2.from_angle(a)
		draw_line(d*(radius-14),d*(radius-(22 if i%4==0 else 17)),gold,1,true)
	for i in range(6):
		var a = TAU*i/6.0-angle*0.5
		var p = Vector2.from_angle(a)*(radius-40)
		var points = PackedVector2Array([p+Vector2(0,-7),p+Vector2(4,0),p+Vector2(0,7),p+Vector2(-4,0),p+Vector2(0,-7)])
		draw_polyline(points,gold,1,true)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if mode == "title":
		# Soft matte protects menu contrast without boxing in the illustration.
		for i in range(80):
			var x = i*15.0
			draw_rect(Rect2(x,0,15,1000),Color(0.017,0.029,0.047,0.78*pow(1.0-float(i)/80.0,1.8)))
		for i in range(24):
			draw_rect(Rect2(0,760+i*10,1600,10),Color(0.02,0.03,0.05,float(i)/24.0*0.52))
		_rune(Vector2(1200,450),324,1,0.13,clock*0.012)
	else:
		draw_rect(Rect2(0,0,1600,1000),Color(0.018,0.03,0.05,0.10))
		if mode == "battle":
			_rune(Vector2(819,470),317,0.51,0.12,clock*0.008)
	for i in range(42):
		var seed_x = fmod(float(i)*397.31,1600.0)
		var seed_y = fmod(float(i)*181.13-clock*(5.0+i%5)+10000.0,1000.0)
		var p = Vector2(seed_x+sin(clock*0.14+i)*17.0,seed_y)
		var a = (0.2+0.16*sin(clock*0.5+i))* (1.0 if mode=="title" else 0.55)
		draw_circle(p,1.0+float(i%3)*0.35,Color(0.86,0.77,0.55,a))
		if i%7==0:
			draw_line(p-Vector2(3,0),p+Vector2(3,0),Color(0.95,0.87,0.63,a*0.5),1,true)
	# Hairline perimeter and cut gemstone corners, shared across every screen.
	draw_rect(Rect2(18,18,1564,964),Color(0.80,0.70,0.49,0.26),false,1)
	for p in [Vector2(18,18),Vector2(1582,18),Vector2(18,982),Vector2(1582,982)]:
		draw_circle(p,2,Color("c6b081"))
