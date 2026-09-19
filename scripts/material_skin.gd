extends RefCounted
## Shared art-backed skin. Master illustrations remain unmodified on disk.
## Small cached runtime textures keep nine-slice borders proportional to controls.
static var _textures: Dictionary = {}
static var _icon_material: ShaderMaterial

static func icon(parent: Control, id: String, rect: Rect2, opacity: float = 1.0) -> TextureRect:
	if not _icon_material:
		var shader=Shader.new()
		shader.code="shader_type canvas_item; varying vec4 icon_tint; void vertex(){icon_tint=COLOR;} void fragment(){COLOR=vec4(vec3(0.96,0.83,0.61),texture(TEXTURE,UV).a)*icon_tint;}"
		_icon_material=ShaderMaterial.new();_icon_material.shader=shader
	var view=TextureRect.new()
	view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.texture=load("res://assets/icons/"+id+".svg")
	view.material=_icon_material
	view.position=rect.position;view.size=rect.size
	view.modulate.a=opacity
	view.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(view)
	return view

static func texture(id: String, resolution: Vector2i = Vector2i.ZERO) -> Texture2D:
	var key = id + str(resolution)
	if _textures.has(key): return _textures[key]
	var source: Texture2D = load("res://assets/ui/" + id + ".png")
	if resolution != Vector2i.ZERO:
		var pixels = source.get_image()
		pixels.resize(resolution.x, resolution.y, Image.INTERPOLATE_LANCZOS)
		source = ImageTexture.create_from_image(pixels)
	_textures[key] = source
	return source

static func panel(compact: bool = false, tint: Color = Color.WHITE, frame_only: bool = false) -> StyleBoxTexture:
	var s = StyleBoxTexture.new()
	s.texture = texture("panel-stone", Vector2i(160,160) if compact else Vector2i(256,256))
	s.set_texture_margin_all(20 if compact else 32)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	s.modulate_color = tint
	s.draw_center = not frame_only
	return s

static func button(primary: bool = false, state: String = "normal", tall: bool = false) -> StyleBoxTexture:
	var s = StyleBoxTexture.new()
	s.texture = texture("button-stone", Vector2i(336,112) if tall else Vector2i(216,72))
	s.texture_margin_left = 40 if tall else 26
	s.texture_margin_right = s.texture_margin_left
	s.texture_margin_top = 19 if tall else 12
	s.texture_margin_bottom = s.texture_margin_top
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	s.modulate_color = Color(1.14,1.12,1.03) if primary else Color(0.89,0.96,0.98)
	match state:
		"hover": s.modulate_color = Color(1.32,1.29,1.12) if primary else Color(1.09,1.2,1.24)
		"pressed": s.modulate_color = Color(0.66,0.68,0.69)
		"disabled": s.modulate_color = Color(0.43,0.45,0.48)
		"focus": s.modulate_color = Color(1.3,1.22,1.05); s.draw_center = false
	return s

static func apply_button(control: BaseButton, primary: bool = false) -> void:
	for state in ["normal","hover","pressed","disabled","focus"]:
		control.add_theme_stylebox_override(state, button(primary,state,control.size.y>=65))
	control.add_theme_color_override("font_color",Color("f7e5bb"))
	control.add_theme_color_override("font_hover_color",Color("fff4d7"))
	control.add_theme_color_override("font_pressed_color",Color("e9dabd"))
	control.add_theme_color_override("font_disabled_color",Color("a29885"))
	control.add_theme_color_override("font_shadow_color",Color(0,0,0,0.9))
	control.add_theme_constant_override("shadow_offset_y",2)
	control.add_theme_color_override("font_outline_color",Color("261a13"))
	control.add_theme_constant_override("outline_size",2)

static func apply_native_controls(t: Theme) -> void:
	for kind in ["OptionButton","MenuButton"]:
		for state in ["normal","hover","pressed","disabled","focus"]:
			t.set_stylebox(state,kind,button(false,state))
	t.set_stylebox("panel","PopupMenu",panel())
	t.set_stylebox("panel","TooltipPanel",panel(true))
	t.set_font_size("font_size","TooltipLabel",15)
	t.set_color("font_color","TooltipLabel",Color("f7e5bb"))
	t.set_color("font_color","PopupMenu",Color("f7e5bb"))
	t.set_stylebox("normal","LineEdit",panel(true))
	t.set_stylebox("focus","LineEdit",panel(true,Color(1.2,1.2,1.1),true))
