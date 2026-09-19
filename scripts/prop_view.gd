extends Control
## Grounded board objects. Cosmetic reactions never touch the game RNG or state.
static var _art_cache:Dictionary={}
const ACCENTS={"O01":"baafff","O02":"7defbf","O03":"90d7e7","O04":"a4dfff","O05":"ffb16c","O06":"77dbe2","O07":"c3a2df","O08":"d9a46b"}
const SOUNDS={"O01":"prop_crystal","O02":"prop_crystal","O03":"prop_stone","O04":"prop_glass","O05":"prop_fire","O06":"prop_water","O07":"prop_stone","O08":"prop_wood"}
var object_data:Dictionary={}
var sprite:Texture2D
var alpha_mask:BitMap
var sprite_rect:=Rect2()
var font:Font
var hovered:=false
var highlighted:=false
var reduced:=false
var clock:=0.0
var reaction_age:=10.0
var reaction_count:=0
var cooldown:=0.0
var death_age:=10.0
var dead:=false
var accent:=Color.WHITE

func setup(data:Dictionary,f:Font)->void:
	font=f;size=Vector2(190,218)
	mouse_filter=Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	var definition=str(data.get("def","O01"))
	accent=Color(ACCENTS.get(definition,"baafff"))
	var path="res://assets/props/"+definition.to_lower()+".png"
	if not _art_cache.has(path) and ResourceLoader.exists(path):
		var source:Texture2D=load(path)
		var pixels=source.get_image()
		pixels.resize(384,384,Image.INTERPOLATE_LANCZOS)
		var used=pixels.get_used_rect()
		if used.has_area():pixels=pixels.get_region(used)
		var mask=BitMap.new();mask.create_from_image_alpha(pixels,0.08)
		_art_cache[path]={"sprite":ImageTexture.create_from_image(pixels),"mask":mask}
	if _art_cache.has(path):
		sprite=_art_cache[path].sprite;alpha_mask=_art_cache[path].mask
		var fit=minf(178.0/sprite.get_width(),178.0/sprite.get_height())
		var dimensions=sprite.get_size()*fit
		sprite_rect=Rect2(Vector2(95-dimensions.x/2,184-dimensions.y),dimensions)
	mouse_entered.connect(func():hovered=true;queue_redraw())
	mouse_exited.connect(func():hovered=false;queue_redraw())
	update_data(data)

func update_data(data:Dictionary)->void:
	var was_dead=dead
	object_data=data.duplicate(true)
	set_meta("visual_state",object_data.duplicate(true))
	dead=bool(data.get("dead",false)) or int(data.get("hp",1))<=0
	if dead and not was_dead:death_age=1.0 if reduced else 0.0
	queue_redraw()

func health_text()->String:
	return str(maxi(0,int(object_data.get("hp",0))))

func sound_cue()->String:
	return SOUNDS.get(str(object_data.get("def","")),"prop_stone")

func poke()->bool:
	if dead or cooldown>0:return false
	reaction_count+=1;reaction_age=0.0;cooldown=0.18
	queue_redraw()
	return true

func _process(delta:float)->void:
	var dt=minf(delta,0.05)
	cooldown=maxf(0,cooldown-dt)
	var active=reaction_age<1.4 or death_age<1.0
	reaction_age=minf(10,reaction_age+dt);death_age=minf(10,death_age+dt)
	if not reduced:clock+=dt
	if not reduced or active:queue_redraw()

func contains_global(point:Vector2)->bool:
	return _has_point(get_global_transform().affine_inverse()*point)

func _has_point(point:Vector2)->bool:
	if dead or not alpha_mask or not sprite_rect.has_point(point):return false
	var pixel=Vector2i((point-sprite_rect.position)/sprite_rect.size*Vector2(alpha_mask.get_size()))
	return alpha_mask.get_bitv(pixel)

func target_center()->Vector2:
	return get_global_transform()*sprite_rect.get_center()

func _ellipse(center:Vector2,radius:float,squash:float,color:Color,filled:bool=true)->void:
	draw_set_transform(center,0,Vector2(1,squash))
	if filled:draw_circle(Vector2.ZERO,radius,color)
	else:draw_arc(Vector2.ZERO,radius,0,TAU,64,color,1.4,true)
	draw_set_transform(Vector2.ZERO)

func _draw()->void:
	if not font:return
	var ground=Vector2(95,184)
	for i in range(6,0,-1):_ellipse(ground+Vector2(0,3),45+i*4,0.28,Color(0,0,0,0.045))
	if dead:
		_draw_rubble(ground)
		if sprite and death_age<0.45:
			draw_texture_rect(sprite,sprite_rect,false,Color(0.65,0.65,0.65,(1-death_age/0.45)*0.65))
		return
	var light=1.0 if hovered or highlighted else 0.0
	var kick=maxf(0,1-reaction_age/0.85)
	var glow=0.16*light+0.30*kick
	if glow>0:
		for i in range(4,0,-1):_ellipse(ground,40+i*7,0.32,Color(accent,glow*0.14))
	if highlighted:_ellipse(ground,65,0.30,Color(accent,0.70),false)
	if sprite:
		var angle=0.0 if reduced else sin(reaction_age*30)*0.025*kick
		var squash=Vector2.ONE if reduced else Vector2(1+sin(reaction_age*25)*0.018*kick,1-sin(reaction_age*25)*0.014*kick)
		draw_set_transform(ground,angle,squash)
		var local_rect=Rect2(sprite_rect.position-ground,sprite_rect.size)
		if light>0:draw_texture_rect(sprite,local_rect.grow(1.4),false,Color(accent,0.40))
		draw_texture_rect(sprite,local_rect,false,Color.WHITE*(1.0+light*0.12+kick*0.12))
		draw_set_transform(Vector2.ZERO)
	_draw_magic(kick)
	# No card frame, nameplate or durability bar: a small current-value readout only.
	var hp=health_text()
	draw_string_outline(font,Vector2(145,205),hp,HORIZONTAL_ALIGNMENT_CENTER,34,20,4,Color("101b20"))
	draw_string(font,Vector2(145,205),hp,HORIZONTAL_ALIGNMENT_CENTER,34,20,Color("f2d2b8"))
	if int(object_data.get("block",0))>0:
		var block=str(int(object_data.block))
		draw_string_outline(font,Vector2(12,205),block,HORIZONTAL_ALIGNMENT_CENTER,34,18,4,Color("101b20"))
		draw_string(font,Vector2(12,205),block,HORIZONTAL_ALIGNMENT_CENTER,34,18,Color("9de4fa"))

func _draw_magic(kick:float)->void:
	if reduced:
		if kick>0:_ellipse(Vector2(95,181),48,0.3,Color(accent,0.3*kick),false)
		return
	var definition=str(object_data.get("def",""))
	var center=sprite_rect.get_center()
	if definition=="O06":
		# Two restrained ellipses over the bowl's water, expanding after a tap.
		for i in range(2):
			var age=fmod(reaction_age+i*0.3,1.15) if kick>0 else fmod(clock*0.35+i*0.4,1.0)
			_ellipse(center+Vector2(0,-9),15+age*37,0.30,Color(accent,(0.12+kick*0.55)*(1-age/1.15)),false)
	elif definition=="O04" and kick>0:
		var line=PackedVector2Array()
		for i in range(7):line.append(center+Vector2(sin(i*2.3+reaction_age*38)*12,(i-3)*9))
		draw_polyline(line,Color(accent,kick*0.9),1.8,true)
	elif definition in ["O03","O07"] and kick>0:
		for i in range(3):
			var rise=reaction_age*32+i*17
			draw_arc(center+Vector2(0,15-rise),12+i*4,0.2,PI-0.2,20,Color(accent,kick*0.45),1.3,true)
	var particles=14 if kick>0 else 3 if definition in ["O01","O02","O05","O06"] else 0
	for i in range(particles):
		var age=reaction_age if kick>0 else fmod(clock*0.6+i*0.43,1.4)
		var direction=Vector2(sin(i*2.399+reaction_count)*36,-24-fmod(i*17.0,39.0))
		var origin=center+Vector2(0,-15 if definition=="O05" else 5)
		var point=origin+direction*age+Vector2(0,-age*age*8)
		var alpha=maxf(0,1-age/1.4)*(0.70 if kick>0 else 0.28)
		draw_circle(point,1.4+fmod(i*0.7,1.3),Color(accent,alpha))
	if definition=="O08" and kick>0:
		# A lid/fuse tap, not an explosion: cosmetics must not imply free combat damage.
		_ellipse(Vector2(95,187),50+reaction_age*20,0.22,Color("b29272",kick*0.3),false)

func _draw_rubble(ground:Vector2)->void:
	var t=1.0 if reduced else clampf(death_age/0.6,0,1)
	for i in range(9):
		var angle=i*2.399
		var radius=17+fmod(i*13.0,44.0)
		var center=ground+Vector2(cos(angle)*radius,sin(angle)*radius*0.27)*t
		var height=5+fmod(i*11.0,8.0)
		var shard=PackedVector2Array([center+Vector2(-10,2),center+Vector2(-3,-height),center+Vector2(10,-2),center+Vector2(6,6)])
		_ellipse(center+Vector2(0,3),12,0.3,Color(0,0,0,0.32))
		if sprite:
			var uv=Vector2(0.32+sin(i*2.1)*0.10,0.55+cos(i*1.7)*0.12)
			var uvs=PackedVector2Array([uv,uv+Vector2(0.04,-0.15),uv+Vector2(0.20,-0.02),uv+Vector2(0.16,0.07)])
			draw_polygon(shard,PackedColorArray([Color(0.55,0.56,0.54,0.9)]),uvs,sprite)
			draw_line(shard[1],shard[2],Color(accent,0.23),0.8,true)
