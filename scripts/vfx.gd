extends Control
## Native, resolution-independent combat presentation. All positions are in
## this overlay's 1600 × 1000 logical canvas coordinates. Public animation
## methods may be awaited. They never mutate combat state or a real hand card.

signal contact(kind: String, center: Vector2)

const GOLD := Color("f2ce86")
const ARCANE := Color("9bc5ff")
const ICE := Color("8fe6ff")
const FIRE := Color("ff9b59")
const ENERGY := Color("7bf0c8")
const HURT := Color("ff9b8b")
const MAX_PARTICLES := 240
const MAX_EMITTERS := 12
const MAX_EFFECTS := 40
const MAX_FLOAT_LABELS := 22

var reduced := false
var fast := false
var audio_enabled := true
var _effects: Array[Dictionary] = []
var _emitters: Array[Dictionary] = []
var _labels: Array[Control] = []
var _owned_cards: Array[Control] = []
var _audio_pool: Array[AudioStreamPlayer] = []
var _audio_cache: Dictionary = {}
var _last_sound: Dictionary = {}
var _audio_cursor := 0
var _particle_count := 0
var _glow_texture: Texture2D
var _additive: CanvasItemMaterial
var _aim_active := false
var _aim_from := Vector2.ZERO
var _aim_to := Vector2.ZERO
var _aim_valid := true
var _clock := 0.0
var _generation := 0
var _attack_direction := Vector2.UP
var _actor_motions: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 80
	clip_contents = false
	_additive = CanvasItemMaterial.new()
	_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = _additive
	_glow_texture = _make_glow_texture()
	for i in range(7):
		var player := AudioStreamPlayer.new()
		player.volume_db = -7.0
		add_child(player)
		_audio_pool.append(player)
	# The first grab must not stall while its cue is being synthesized.
	for cue in ["grab", "release", "land", "flip", "hit", "draw"]:
		_audio_cache[cue] = _synthesize(cue)
	set_process(false)


func _process(delta: float) -> void:
	_clock += delta
	var had_canvas_effects := not _effects.is_empty()
	for i in range(_effects.size() - 1, -1, -1):
		_effects[i]["age"] = float(_effects[i]["age"]) + delta
		if float(_effects[i]["age"]) >= float(_effects[i]["life"]):
			_effects.remove_at(i)
	for i in range(_emitters.size() - 1, -1, -1):
		_emitters[i]["left"] = float(_emitters[i]["left"]) - delta
		if float(_emitters[i]["left"]) <= 0.0:
			_particle_count -= int(_emitters[i]["count"])
			var emitter: GPUParticles2D = _emitters[i]["node"]
			if is_instance_valid(emitter):
				emitter.queue_free()
			_emitters.remove_at(i)
	if had_canvas_effects or _aim_active:
		queue_redraw()
	if _effects.is_empty() and _emitters.is_empty() and not _aim_active:
		set_process(false)

func _exit_tree() -> void:
	for player in _audio_pool:
		if is_instance_valid(player):
			player.stop()
			player.stream=null
	_audio_cache.clear()


func _time(seconds: float) -> float:
	return maxf(0.018, seconds * (0.28 if fast else 1.0))


func _wait(seconds: float) -> void:
	await get_tree().create_timer(_time(seconds)).timeout


func _finish_tween(tween: Tween, generation: int) -> bool:
	# Awaiting Tween.finished directly can deadlock when cleanup kills its node.
	while generation == _generation and tween.is_valid() and tween.is_running():
		await get_tree().process_frame
	return generation == _generation


func _add_effect(kind: String, data: Dictionary, life: float) -> void:
	if _effects.size() >= MAX_EFFECTS:
		_effects.pop_front()
	data["kind"] = kind
	data["age"] = 0.0
	data["life"] = _time(life)
	_effects.append(data)
	set_process(true)
	queue_redraw()


func _make_glow_texture() -> Texture2D:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in range(32):
		for x in range(32):
			var distance := Vector2(x - 15.5, y - 15.5).length() / 15.5
			var alpha := pow(maxf(0.0, 1.0 - distance), 2.7)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)


func burst(pos: Vector2, color: Color, count: int = 14, power: float = 1.0) -> void:
	if reduced or count <= 0 or _particle_count >= MAX_PARTICLES:
		return
	if _emitters.size() >= MAX_EMITTERS:
		return
	count = mini(count, MAX_PARTICLES - _particle_count)
	if fast:
		count = maxi(3, count / 3)
	var emitter := GPUParticles2D.new()
	emitter.emitting = false
	emitter.one_shot = true
	emitter.amount = count
	emitter.lifetime = _time(0.29 + minf(power, 2.0) * 0.12)
	emitter.explosiveness = 1.0
	emitter.randomness = 0.38
	emitter.local_coords = false
	emitter.fixed_fps = 60
	emitter.texture = _glow_texture
	emitter.material = _additive
	emitter.position = pos
	emitter.visibility_rect = Rect2(-500, -500, 1000, 1000)
	var process_mat := ParticleProcessMaterial.new()
	process_mat.particle_flag_disable_z = true
	process_mat.direction = Vector3(0.0, -1.0, 0.0)
	process_mat.spread = 180.0
	process_mat.gravity = Vector3(0.0, 65.0 * power, 0.0)
	process_mat.initial_velocity_min = 70.0 * power
	process_mat.initial_velocity_max = 245.0 * power
	process_mat.damping_min = 60.0
	process_mat.damping_max = 120.0
	process_mat.scale_min = 0.2
	process_mat.scale_max = 0.43 * minf(power, 1.5)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(color.r, color.g, color.b, 0.95))
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	gradient.add_point(0.2, color.lightened(0.25))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process_mat.color_ramp = ramp
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.75))
	curve.add_point(Vector2(0.18, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var scale_texture := CurveTexture.new()
	scale_texture.curve = curve
	process_mat.scale_curve = scale_texture
	emitter.process_material = process_mat
	add_child(emitter)
	_particle_count += count
	_emitters.append({"node": emitter, "left": emitter.lifetime + 0.12, "count": count})
	emitter.restart()
	set_process(true)


func ring(pos: Vector2, color: Color, radius: float = 75.0) -> void:
	_add_effect("ring", {"pos": pos, "color": color, "radius": radius}, 0.2 if reduced else 0.48)


func float_text(text: String, pos: Vector2, color: Color = GOLD) -> void:
	while _labels.size() >= MAX_FLOAT_LABELS:
		var oldest: Control = _labels.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(380, 70)
	label.position = pos - label.size * 0.5
	label.pivot_offset = label.size * 0.5
	label.add_theme_font_size_override("font_size", 35 if text.length() <= 5 else 23)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.01, 0.015, 0.035, 0.95))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.025, 0.045, 0.9))
	label.add_theme_constant_override("outline_size", 7)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.z_index = 10
	add_child(label)
	_labels.append(label)
	var tween := label.create_tween()
	if reduced:
		tween.tween_interval(_time(0.45))
		tween.tween_property(label, "modulate:a", 0.0, _time(0.15))
	else:
		label.scale = Vector2.ONE * 0.64
		tween.set_parallel(true)
		tween.tween_property(label, "scale", Vector2.ONE * 1.13, _time(0.14)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "position:y", label.position.y - 62.0, _time(0.92)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "scale", Vector2.ONE, _time(0.17)).set_delay(_time(0.14))
		tween.tween_property(label, "modulate:a", 0.0, _time(0.28)).set_delay(_time(0.60))
		tween.set_parallel(false)
	tween.tween_callback(func() -> void:
		_labels.erase(label)
		if is_instance_valid(label):
			label.queue_free()
	)


func slash(from: Vector2, to: Vector2, color: Color = GOLD) -> void:
	_attack_direction = (to - from).normalized()
	if reduced:
		return
	_add_effect("streak", {"from": from, "to": to, "color": color}, 0.20)
	sound("slash")


func projectile(from: Vector2, to: Vector2, style: String = "arcane", duration: float = 0.3) -> void:
	var color := _style_color(style)
	var generation := _generation
	_attack_direction = (to - from).normalized()
	if reduced:
		await _wait(0.035)
		return
	spell_seal(from,color,42.0)
	if style in ["physical", "slash", "attack", "sword"]:
		_add_effect("streak", {"from": from, "to": to, "color": color}, duration)
		sound("slash")
		await _wait(duration)
		return
	_add_effect("charge", {"pos": from, "color": color, "radius": 19.0}, 0.11)
	await _wait(0.035)
	if generation != _generation:
		return
	sound("fire" if style == "fire" else "cast")
	var bend := (from + to) * 0.5 + Vector2(0, -minf(90.0, from.distance_to(to) * 0.16))
	_add_effect("projectile", {"from": from, "to": to, "bend": bend, "color": color, "style": style}, duration)
	await _wait(duration)
	# Arrival has deliberately no sound/burst. The matching impact() owns the
	# contact frame, so trajectory, damage display and the hit transient align.


func grab_card(node: Control) -> void:
	if not is_instance_valid(node):
		return
	sound("grab")
	if not reduced:
		_add_effect("card_glint", {"card": weakref(node), "color": GOLD}, 0.23)


func drag_feedback(node: Control, velocity: Vector2) -> void:
	## Optional, called on pointer movement. Never tween a grabbed card here.
	if reduced or not is_instance_valid(node) or velocity.length() < 480.0:
		return
	var now := Time.get_ticks_msec()
	if now - int(node.get_meta("vfx_drag_tick", -1000)) < 85:
		return
	node.set_meta("vfx_drag_tick", now)
	var center := node.get_global_transform() * (node.size * 0.5)
	var direction := velocity.normalized()
	_add_effect("air", {"from": center - direction * 24.0, "to": center - direction * 65.0, "color": GOLD}, 0.13)


func card_flight(card_node: Control, to: Vector2, style: String = "cast") -> void:
	if not is_instance_valid(card_node):
		return
	var generation := _generation
	if not card_node in _owned_cards:
		_owned_cards.append(card_node)
	card_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var start := card_node.get_global_transform() * (card_node.size * 0.5)
	var original_scale := card_node.scale
	var original_rotation := card_node.rotation
	card_node.pivot_offset = card_node.size * 0.5
	_card_pose(card_node, start, original_scale, original_rotation, 1.0)
	var tween := card_node.create_tween()
	if reduced:
		tween.tween_property(card_node, "modulate:a", 0.0, _time(0.07))
	elif style in ["draw", "deal"]:
		var draw_bend := (start + to) * 0.5 + Vector2(0, -62)
		_card_pose(card_node, start, original_scale * 0.7, original_rotation, 0.2)
		sound("draw")
		tween.tween_method(func(p: float) -> void:
			var sc := lerpf(0.70, 1.0, p) + sin(p * PI) * 0.075
			_card_pose(card_node, _bezier(start, draw_bend, to, p), original_scale * sc, lerpf(original_rotation, 0.0, p), minf(1.0, p * 5.0))
		, 0.0, 1.0, _time(0.30)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	elif style == "enemy":
		# A revealed enemy card recedes while the character performs its attack.
		var end_scale := original_scale * 0.42
		tween.tween_callback(func() -> void: sound("release"))
		var bend := (start + to) * 0.5 + Vector2(0, -34)
		tween.tween_method(func(p: float) -> void:
			_card_pose(card_node, _bezier(start, bend, to, p), original_scale.lerp(end_scale, p), lerpf(original_rotation, -0.08, p), 1.0 - smoothstep(0.3, 1.0, p))
		, 0.0, 1.0, _time(0.23)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		var installing := style in ["install", "rule"]
		var anticipation := start - (to - start).normalized() * 8.0
		var target_scale := original_scale * (0.64 if installing else 0.84)
		var bend := (anticipation + to) * 0.5 + Vector2(0, -28)
		# 60 ms pickup compression; the release sound starts with acceleration.
		tween.tween_method(func(p: float) -> void:
			_card_pose(card_node, start.lerp(anticipation, p), original_scale * lerpf(1.0, 1.055, p), lerpf(original_rotation, 0.0, p), 1.0)
		, 0.0, 1.0, _time(0.06)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func() -> void: sound("release"))
		tween.tween_method(func(p: float) -> void:
			_card_pose(card_node, _bezier(anticipation, bend, to, p), (original_scale * 1.055).lerp(target_scale, p), original_rotation * (1.0 - p) * 0.3, 1.0)
		, 0.0, 1.0, _time(0.19)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_callback(func() -> void:
			if generation == _generation:
				_landing_now(to, "install" if installing else "cast")
		)
		# Squash, overshoot, settle: all transforms still honor the exact center.
		tween.tween_method(func(p: float) -> void:
			var wave := sin(p * PI * 2.1) * exp(-p * 4.5)
			var squash := Vector2(1.0 + 0.095 * wave, 1.0 - 0.115 * wave)
			_card_pose(card_node, to + Vector2(0, -sin(p * PI) * 3.0), target_scale * squash, 0.0, 1.0)
		, 0.0, 1.0, _time(0.19))
		tween.tween_property(card_node, "modulate:a", 0.0, _time(0.075))
	await _finish_tween(tween, generation)
	if is_instance_valid(card_node):
		_owned_cards.erase(card_node)
		card_node.queue_free()


func _landing_now(center: Vector2, style: String = "cast") -> void:
	var color := GOLD if style in ["cast", "install", "enemy"] else _style_color(style)
	sound("install" if style == "install" else "land")
	contact.emit("landing", center)
	if reduced:
		return
	_add_effect("landing", {"pos": center, "color": color, "radius": 75.0}, 0.31)
	_add_effect("impact_sparks", {"pos": center, "color": color, "direction": Vector2.DOWN, "amount": 6, "spread": 2.8}, 0.24)
	burst(center, color, 7, 0.38)
	spell_seal(center,color,105.0 if style=="install" else 82.0)

func spell_seal(center: Vector2, color: Color, radius: float = 84.0) -> void:
	if reduced:return
	_add_effect("sigil",{"pos":center,"color":color,"radius":radius},0.72)

func rule_thread(from: Vector2, to: Vector2, color: Color) -> void:
	if reduced:return
	_add_effect("weave",{"from":from,"to":to,"color":color},0.65)


func landing(center: Vector2, style: String = "cast") -> void:
	_landing_now(center, style)
	await _wait(0.08 if reduced else 0.14)


func settle_card(card_node: Control, center: Vector2, style: String = "cast") -> void:
	## Non-owning landing API, useful when a displayed card must remain on screen.
	if not is_instance_valid(card_node):
		return
	var original_scale := card_node.scale
	var generation := _generation
	_landing_now(center, style)
	if reduced:
		_card_pose(card_node, center, original_scale, 0.0, 1.0)
		return
	var tween := card_node.create_tween()
	tween.tween_method(func(p: float) -> void:
		var wave := sin(p * PI * 2.0) * exp(-p * 4.0)
		_card_pose(card_node, center, original_scale * Vector2(1.0 + 0.08 * wave, 1.0 - 0.10 * wave), 0.0, 1.0)
	, 0.0, 1.0, _time(0.20))
	await _finish_tween(tween, generation)


func enemy_reveal(card_node: Control, from_center: Vector2, show_center: Vector2, display_scale_factor: float = 1.08) -> void:
	## Takes ownership of a visual clone for cleanup, but preserves it on return.
	## CardView.set_face_down(bool) switches art exactly at the narrow flip frame.
	if not is_instance_valid(card_node):
		return
	var generation := _generation
	if not card_node in _owned_cards:
		_owned_cards.append(card_node)
	card_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var original_scale := card_node.scale
	var display_scale := Vector2.ONE * maxf(0.5, display_scale_factor)
	var original_rotation := card_node.rotation
	card_node.pivot_offset = card_node.size * 0.5
	var back: Control
	if card_node.has_method("set_face_down"):
		card_node.call("set_face_down", true)
	else:
		back = _fallback_card_back(card_node)
	_card_pose(card_node, from_center, original_scale, original_rotation, 1.0)
	if reduced:
		if card_node.has_method("set_face_down"):
			card_node.call("set_face_down", false)
		if is_instance_valid(back):
			back.queue_free()
		_card_pose(card_node, show_center, display_scale, 0.0, 1.0)
		await _wait(0.18)
		return
	sound("grab")
	var lifted := from_center + Vector2(0, 39)
	var bend := (lifted + show_center) * 0.5 + Vector2(36, -35)
	var tween := card_node.create_tween()
	tween.tween_method(func(p: float) -> void:
		_card_pose(card_node, from_center.lerp(lifted, p), original_scale * lerpf(1.0, 1.12, p), lerpf(original_rotation, 0.0, p), 1.0)
	, 0.0, 1.0, _time(0.12)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: sound("release"))
	tween.tween_method(func(p: float) -> void:
		_card_pose(card_node, _bezier(lifted, bend, show_center, p), (original_scale * 1.12).lerp(display_scale, p), 0.0, 1.0)
	, 0.0, 1.0, _time(0.23)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(p: float) -> void:
		_card_pose(card_node, show_center, display_scale * Vector2(lerpf(1.0, 0.025, p), 1.0 + sin(p * PI) * 0.025), 0.0, 1.0)
	, 0.0, 1.0, _time(0.10)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		if generation != _generation or not is_instance_valid(card_node):
			return
		if card_node.has_method("set_face_down"):
			card_node.call("set_face_down", false)
		if is_instance_valid(back):
			back.queue_free()
		sound("flip")
	)
	tween.tween_method(func(p: float) -> void:
		_card_pose(card_node, show_center, display_scale * Vector2(lerpf(0.025, 1.0, p), 1.0), 0.0, 1.0)
	, 0.0, 1.0, _time(0.16)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(_time(0.23))
	await _finish_tween(tween, generation)


func _fallback_card_back(card_node: Control) -> Control:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = card_node.size
	panel.z_index = 5
	var style := StyleBoxFlat.new()
	style.bg_color = Color("14253a")
	style.border_color = GOLD.darkened(0.35)
	style.set_border_width_all(3)
	style.set_corner_radius_all(9)
	panel.add_theme_stylebox_override("panel", style)
	var emblem := Label.new()
	emblem.text = "◇\n织律\n◇"
	emblem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emblem.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	emblem.size = card_node.size
	emblem.add_theme_font_size_override("font_size", 26)
	emblem.add_theme_color_override("font_color", GOLD)
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(emblem)
	card_node.add_child(panel)
	return panel


func actor_strike(actor: Control, target_center: Vector2, style: String = "physical") -> void:
	## Character anticipation/recoil overlaps the projectile, not the hit reaction.
	if not is_instance_valid(actor):
		return
	var generation := _generation
	var original_center := actor.get_global_transform() * (actor.size * 0.5)
	var original_scale := actor.scale
	var original_rotation := actor.rotation
	var direction := (target_center - original_center).normalized()
	var reach := 33.0 if style in ["physical", "attack", "slash"] else 14.0
	var prep := original_center - direction * 8.0
	var apex := original_center + direction * reach
	var motion := {"node": weakref(actor), "center": original_center, "scale": original_scale, "rotation": original_rotation, "tweens": []}
	_actor_motions.append(motion)
	if not reduced:
		var tween := actor.create_tween()
		motion["tweens"].append(tween)
		tween.tween_method(func(p: float) -> void:
			_card_pose(actor, original_center.lerp(prep, p), original_scale * lerpf(1.0, 0.98, p), original_rotation, 1.0)
		, 0.0, 1.0, _time(0.09)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_method(func(p: float) -> void:
			_card_pose(actor, prep.lerp(apex, p), original_scale * lerpf(0.98, 1.025, p), original_rotation, 1.0)
		, 0.0, 1.0, _time(0.085)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		await _finish_tween(tween, generation)
		if generation != _generation or not is_instance_valid(actor):
			return
		var recovery := actor.create_tween()
		motion["tweens"].append(recovery)
		recovery.tween_method(func(p: float) -> void:
			_card_pose(actor, apex.lerp(original_center, p), original_scale * lerpf(1.025, 1.0, p), original_rotation, 1.0)
		, 0.0, 1.0, _time(0.23)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await projectile(original_center + direction * (reach + 32.0), target_center, style, 0.22)
	_actor_motions.erase(motion)
	if is_instance_valid(actor):
		_card_pose(actor, original_center, original_scale, original_rotation, 1.0)


func _card_pose(node: Control, center: Vector2, card_scale: Vector2, angle: float, alpha: float) -> void:
	if not is_instance_valid(node):
		return
	node.scale = card_scale
	node.rotation = angle
	node.modulate.a = alpha
	node.global_position += center - node.get_global_transform() * (node.size * 0.5)


func card_hover(node: Control, active: bool = true) -> void:
	## Optional hook: keeps the CardView's own lift/rotation tween untouched.
	if not active or not is_instance_valid(node):
		return
	sound("hover")
	if not reduced:
		_add_effect("card_glint", {"card": weakref(node), "color": GOLD}, 0.38)


func card_press(node: Control) -> void:
	## Optional hook: a traveling edge highlight, separate from selection state.
	if not is_instance_valid(node):
		return
	sound("select")
	var jewel := node.get_global_transform() * Vector2(15, 18)
	if not reduced:
		_add_effect("card_glint", {"card": weakref(node), "color": ICE}, 0.48)
		burst(jewel, ICE, 8, 0.35)
	ring(jewel, ICE, 25)


func impact(target_node: Control, amount: Variant, kind: String = "damage") -> void:
	if not is_instance_valid(target_node):
		return
	var generation := _generation
	var center := target_node.get_global_transform() * (target_node.size * 0.5)
	var color := _style_color(kind)
	contact.emit(kind, center)
	match kind:
		"block", "shield", "armor", "defense":
			_add_effect("shield", {"pos": center, "color": ICE, "radius": minf(target_node.size.x, target_node.size.y) * 0.50 + 12.0}, 0.42 if not reduced else 0.12)
			burst(center, ICE, 9, 0.52)
			pulse(target_node, ICE)
			sound("block")
			float_text(("格挡 " if kind == "block" else "护甲 +") + str(amount), center + Vector2(0, -20), ICE)
		"energy", "heal", "healing":
			ring(center, ENERGY, 46.0)
			burst(center + Vector2(0, 15), ENERGY, 11, 0.52)
			pulse(target_node, ENERGY)
			sound("energy")
			float_text("+" + str(amount), center + Vector2(0, -25), ENERGY)
		"break", "destroy":
			sound("break")
			_add_effect("impact_sparks", {"pos": center, "color": FIRE, "direction": _attack_direction, "amount": 10, "spread": 2.3}, 0.31)
			_add_effect("shards", {"pos": center, "color": GOLD}, 0.44)
			ring(center, FIRE, 80.0)
			burst(center, FIRE, 23, 1.10)
			float_text("击碎", center, GOLD)
			shake(target_node, 9.0)
		_:
			# One contact flash and one sound, with directional motion. A short
			# local hit-stop keeps the target rigid before its recovery recoil.
			sound("hit")
			if not reduced and absf(float(amount))>=8.0:
				_add_effect("shockwave",{"pos":center,"color":color,"radius":102.0},0.38)
			_add_effect("flash", {"pos": center, "color": color, "radius": 38.0}, 0.09)
			if not reduced:
				_add_effect("impact_sparks", {"pos": center, "color": GOLD, "direction": _attack_direction, "amount": 7, "spread": 1.75}, 0.23)
				burst(center, color, 10, 0.62)
			pulse(target_node, Color(1.0, 0.79, 0.73))
			await _wait(0.036)
			if generation != _generation:
				return
			if is_instance_valid(target_node):
				shake(target_node, 5.0 if absf(float(amount)) < 10.0 else 8.0)
			float_text("−" + str(amount), center + Vector2(0, -20), HURT)
	await _wait(0.05 if reduced else 0.13)


func banner(title: String, subtitle: String = "", style: String = "turn") -> void:
	var generation := _generation
	var color := GOLD if style in ["victory", "boss", "reward"] else ARCANE
	if style == "defeat":
		color = HURT
	var panel := Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = Vector2(800, 160)
	panel.position = Vector2((size.x - 800) * 0.5, size.y * 0.37 - 80)
	panel.pivot_offset = panel.size * 0.5
	panel.z_index = 20
	var backing := Panel.new()
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.035, 0.065, 0.12, 0.92)
	box.border_color = Color(color.r, color.g, color.b, 0.62)
	box.border_width_top = 1
	box.border_width_bottom = 1
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
	box.shadow_size = 24
	backing.add_theme_stylebox_override("panel", box)
	panel.add_child(backing)
	var heading := Label.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.position = Vector2(30, 22)
	heading.size = Vector2(740, 70)
	heading.add_theme_font_size_override("font_size", 44)
	heading.add_theme_color_override("font_color", color)
	panel.add_child(heading)
	var caption := Label.new()
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.text = subtitle
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.position = Vector2(30, 100)
	caption.size = Vector2(740, 40)
	caption.add_theme_font_size_override("font_size", 19)
	caption.add_theme_color_override("font_color", Color("d4dce6"))
	panel.add_child(caption)
	add_child(panel)
	_labels.append(panel)
	panel.modulate.a = 0.0
	var tween := panel.create_tween()
	if reduced:
		tween.tween_property(panel, "modulate:a", 1.0, _time(0.10))
	else:
		panel.scale = Vector2(0.88, 0.95)
		tween.set_parallel(true)
		tween.tween_property(panel, "modulate:a", 1.0, _time(0.18))
		tween.tween_property(panel, "scale", Vector2.ONE, _time(0.42)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.set_parallel(false)
	tween.tween_interval(_time(0.58 if style == "turn" else 1.0))
	tween.tween_property(panel, "modulate:a", 0.0, _time(0.22))
	sound(style if style in ["victory", "defeat"] else "turn")
	if not reduced:
		burst(Vector2(size.x * 0.5 - 360, size.y * 0.37), color, 20, 0.6)
		burst(Vector2(size.x * 0.5 + 360, size.y * 0.37), color, 20, 0.6)
	await _wait(1.04 if style == "turn" else 1.5)
	if is_instance_valid(panel):
		_labels.erase(panel)
		panel.queue_free()
	if generation != _generation:
		return


func pulse(node: Control, color: Color = GOLD) -> void:
	if not is_instance_valid(node):
		return
	var old_tween: Variant = node.get_meta("vfx_pulse") if node.has_meta("vfx_pulse") else null
	if old_tween is Tween and old_tween.is_valid():
		old_tween.kill()
	var base: Color = node.get_meta("vfx_base_tint", node.self_modulate)
	node.set_meta("vfx_base_tint", base)
	var tween := node.create_tween()
	node.set_meta("vfx_pulse", tween)
	node.self_modulate = base.lerp(color, 0.60)
	tween.tween_property(node, "self_modulate", base, _time(0.22 if reduced else 0.40)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func shake(node: Control, power: float = 7.0) -> void:
	if reduced or not is_instance_valid(node):
		return
	var old_tween: Variant = node.get_meta("vfx_shake") if node.has_meta("vfx_shake") else null
	if old_tween is Tween and old_tween.is_valid():
		old_tween.kill()
		if node.has_meta("vfx_base_position"):
			node.position = node.get_meta("vfx_base_position")
	var base := node.position
	node.set_meta("vfx_base_position", base)
	var tween := node.create_tween()
	node.set_meta("vfx_shake", tween)
	tween.tween_method(func(t: float) -> void:
		if is_instance_valid(node):
			var envelope := pow(1.0 - t, 2.0)
			node.position = base + Vector2(sin(t * 48.0), sin(t * 33.0 + 0.7) * 0.52) * power * envelope
	, 0.0, 1.0, _time(0.32))
	tween.tween_callback(func() -> void:
		if is_instance_valid(node):
			node.position = base
			node.remove_meta("vfx_base_position")
	)


func aim(from: Vector2, to: Vector2, valid: bool) -> void:
	_aim_active = true
	_aim_from = from
	_aim_to = to
	_aim_valid = valid
	set_process(not reduced or not _effects.is_empty() or not _emitters.is_empty())
	queue_redraw()


func clear_aim() -> void:
	_aim_active = false
	queue_redraw()
	if _effects.is_empty() and _emitters.is_empty():
		set_process(false)


func cleanup() -> void:
	_generation += 1
	for motion in _actor_motions:
		for tween in motion["tweens"]:
			if tween.is_valid():
				tween.kill()
		var actor: Variant = motion["node"].get_ref()
		if is_instance_valid(actor):
			_card_pose(actor, motion["center"], motion["scale"], motion["rotation"], 1.0)
	_actor_motions.clear()
	clear_aim()
	_effects.clear()
	for entry in _emitters:
		var emitter: GPUParticles2D = entry["node"]
		if is_instance_valid(emitter):
			emitter.queue_free()
	_emitters.clear()
	_particle_count = 0
	for label in _labels:
		if is_instance_valid(label):
			label.queue_free()
	_labels.clear()
	for card in _owned_cards:
		if is_instance_valid(card):
			card.queue_free()
	_owned_cards.clear()
	for player in _audio_pool:
		player.stop()
		player.stream = null
	set_process(false)
	queue_redraw()


func _style_color(style: String) -> Color:
	match style:
		"fire", "burn", "break", "destroy": return FIRE
		"ice", "block", "shield", "armor", "defense": return ICE
		"energy", "heal", "healing": return ENERGY
		"physical", "slash", "attack", "sword", "install", "rule", "gold": return GOLD
		"damage", "hit", "hurt": return HURT
	return ARCANE


func _bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var inv := 1.0 - t
	return inv * inv * a + 2.0 * inv * t * b + t * t * c


func _alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))


func _glow(pos: Vector2, radius: float, color: Color, alpha: float = 1.0) -> void:
	if _glow_texture != null:
		draw_texture_rect(_glow_texture, Rect2(pos - Vector2.ONE * radius, Vector2.ONE * radius * 2), false, _alpha(color, alpha))


func _draw() -> void:
	for fx in _effects:
		var p := clampf(float(fx["age"]) / float(fx["life"]), 0.0, 1.0)
		var color: Color = fx.get("color", GOLD)
		var fade := pow(1.0 - p, 1.5)
		match fx["kind"]:
			"sigil":
				var pos: Vector2=fx["pos"]
				var r: float=float(fx["radius"])*(0.65+0.35*(1.0-pow(1.0-p,3.0)))
				draw_set_transform(pos,0,Vector2(1,0.56))
				draw_arc(Vector2.ZERO,r,0,TAU,64,_alpha(color,fade*0.66),1.5,true)
				draw_arc(Vector2.ZERO,r*0.83,p*0.8,TAU*0.82+p*0.8,56,_alpha(color,fade*0.48),1.2,true)
				for i in range(12):
					var a=TAU*i/12.0-p*0.5
					var d=Vector2.from_angle(a)
					draw_line(d*r*0.9,d*r*0.97,_alpha(color.lightened(0.4),fade),1.8,true)
				for i in range(3):
					var tri=PackedVector2Array()
					for k in range(4):tri.append(Vector2.from_angle(k*TAU/3.0+i*TAU/9.0+p*0.16)*r*0.66)
					draw_polyline(tri,_alpha(color,fade*0.23),1.1,true)
				draw_set_transform(Vector2.ZERO)
			"weave":
				var a: Vector2=fx["from"]
				var b: Vector2=fx["to"]
				var bend=(a+b)*0.5+Vector2(0,-80)
				var previous=a
				for i in range(1,41):
					var point=_bezier(a,bend,b,i/40.0)
					draw_line(previous,point,_alpha(color,fade*0.13),1,true)
					previous=point
				for i in range(7):
					var t=clampf(p*1.9-i*0.065,0,1)
					var point=_bezier(a,bend,b,t)
					_glow(point,10,color,fade*0.6)
					draw_circle(point,2,_alpha(color.lightened(0.5),fade))
			"shockwave":
				var r: float=float(fx["radius"])*(0.15+0.85*sqrt(p))
				var pos: Vector2=fx["pos"]
				draw_arc(pos,r,-PI,PI,64,_alpha(color.lightened(0.3),fade*0.7),1.5+fade*2,true)
				draw_arc(pos,r*0.81,-PI,PI,56,_alpha(color,fade*0.23),5*fade+1,true)
				for i in range(9):
					var d=Vector2.from_angle(i*TAU/9.0+0.24)
					draw_line(pos+d*r*0.65,pos+d*r,_alpha(color,fade*0.5),1.6,true)
			"air":
				var a: Vector2 = fx["from"]
				var b: Vector2 = fx["to"]
				draw_line(a.lerp(b, p * 0.6), b, _alpha(color, fade * 0.22), 1.1, true)
			"charge":
				var pos: Vector2 = fx["pos"]
				var radius := float(fx["radius"]) * (1.15 - p * 0.6)
				draw_arc(pos, radius, p * 2.0, p * 2.0 + TAU * 0.72, 24, _alpha(color, fade * 0.7), 1.4, true)
				_glow(pos, 22, color, fade * 0.55)
			"landing":
				var pos: Vector2 = fx["pos"]
				var radius := float(fx["radius"]) * (0.5 + (1.0 - pow(1.0 - p, 3.0)) * 0.65)
				draw_set_transform(pos, 0.0, Vector2(1.0, 0.37))
				draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, _alpha(color, fade * 0.7), 1.6, true)
				draw_arc(Vector2.ZERO, radius * 0.75, 0.0, TAU, 30, _alpha(color, fade * 0.16), 4.0, true)
				draw_set_transform(Vector2.ZERO)
			"impact_sparks":
				var pos: Vector2 = fx["pos"]
				var axis: Vector2 = fx.get("direction", Vector2.DOWN)
				var count: int = fx.get("amount", 7)
				var spread: float = fx.get("spread", 1.75)
				for i in range(count):
					var a := axis.angle() + (float(i) / maxf(count - 1, 1) - 0.5) * spread
					var direction := Vector2.from_angle(a)
					var distance := (24.0 + (i * 19) % 49) * (1.0 - pow(1.0 - p, 2.5))
					var head := pos + direction * distance
					var tail := head - direction * (4.0 + fade * (7.0 + i % 4))
					draw_line(tail, head, _alpha(color.lightened(0.35), fade * 0.85), 1.4 if i % 2 else 2.1, true)
			"streak":
				var from: Vector2 = fx["from"]
				var to: Vector2 = fx["to"]
				var progress := p * p * (3.0 - 2.0 * p)
				var head := from.lerp(to, progress)
				var tail := from.lerp(to, maxf(0.0, progress - 0.27))
				var direction := (to - from).normalized()
				var normal := direction.orthogonal()
				var width := 5.0 + sin(p * PI) * 5.0
				var points := PackedVector2Array([tail, head - direction * 25 + normal * width, head + direction * 7, head - direction * 25 - normal * width])
				draw_colored_polygon(points, _alpha(color, 0.42))
				draw_line(tail, head, color.lightened(0.58), 2.0, true)
				_glow(head, 21, color, 0.75)
			"ring":
				var pos: Vector2 = fx["pos"]
				var radius := float(fx["radius"]) * (0.18 + 0.82 * (1.0 - pow(1.0 - p, 3.0)))
				draw_arc(pos, radius, 0, TAU, 40, _alpha(color, fade * 0.18), 4.0 * fade + 1.0, true)
				draw_arc(pos, radius, 0, TAU, 40, _alpha(color.lightened(0.35), fade * 0.75), 1.5, true)
				if not reduced:
					draw_arc(pos, radius * 0.72, p * 2.0, p * 2.0 + TAU * 0.7, 28, _alpha(color, fade * 0.24), 1.0, true)
			"flash":
				_glow(fx["pos"], float(fx["radius"]) * (0.8 + p), color, fade)
				draw_circle(fx["pos"], 6.0 * fade, _alpha(Color.WHITE, fade))
			"shield":
				var pos: Vector2 = fx["pos"]
				var radius := float(fx["radius"]) * (0.88 + minf(1.0, p * 7.0) * 0.12)
				var points := PackedVector2Array()
				for i in range(7):
					points.append(pos + Vector2.from_angle(-PI * 0.5 + TAU * i / 6.0) * radius)
				draw_polyline(points, _alpha(color, fade * 0.22), 5.0, true)
				draw_polyline(points, _alpha(color.lightened(0.55), fade * 0.85), 2.0, true)
				for i in range(6):
					draw_line(pos.lerp(points[i], 0.64), points[i], _alpha(color, fade * 0.55), 1.2, true)
				_glow(pos, 28, color, fade * 0.28)
			"slash":
				var from: Vector2 = fx["from"]
				var to: Vector2 = fx["to"]
				var direction := (to - from).normalized()
				var normal := direction.orthogonal()
				var center := from.lerp(to, minf(1.0, p * 2.5))
				var tail := from.lerp(to, clampf(p * 2.0 - 0.55, 0.0, 1.0))
				var width := sin(p * PI) * 18.0 + 1.0
				var points := PackedVector2Array([tail, center - direction * 45 + normal * width, center + direction * 20, center - direction * 45 - normal * width * 0.4])
				draw_colored_polygon(points, _alpha(color, fade * 0.68))
				draw_line(tail, center, _alpha(color.lightened(0.75), fade), 3.0, true)
				if p < 0.65:
					_glow(center, 52, color, fade)
				var cut_a := to + Vector2(-57, 62)
				var cut_b := to + Vector2(57, -62)
				if p > 0.28:
					draw_line(cut_a, cut_a.lerp(cut_b, minf(1.0, (p - 0.28) * 4.0)), _alpha(color, fade * 0.40), 12 * fade + 1, true)
					draw_line(cut_a, cut_a.lerp(cut_b, minf(1.0, (p - 0.28) * 4.0)), _alpha(Color.WHITE, fade), 2.0, true)
			"projectile":
				_draw_projectile(fx, p, color)
			"card_glint":
				var card: Variant = fx["card"].get_ref()
				if not is_instance_valid(card):
					continue
				var transform: Transform2D = card.get_global_transform()
				var width: float = card.size.x
				var height: float = card.size.y
				var corners := PackedVector2Array([Vector2.ZERO, Vector2(width, 0), Vector2(width, height), Vector2(0, height), Vector2.ZERO])
				for i in range(4):
					var a: Vector2 = transform * corners[i]
					var b: Vector2 = transform * corners[i + 1]
					draw_line(a, a.lerp(b, 0.14), _alpha(color, fade * 0.68), 2.0, true)
					draw_line(b.lerp(a, 0.14), b, _alpha(color, fade * 0.68), 2.0, true)
					var sweep := fmod(p * 1.7 + i * 0.25, 1.0)
					_glow(a.lerp(b, sweep), 21, color, fade * 0.70)
			"shards":
				if reduced:
					continue
				var origin: Vector2 = fx["pos"]
				for i in range(12):
					var angle := float(i) * 2.39996
					var velocity := Vector2.from_angle(angle) * (75.0 + float(i % 4) * 29)
					var pos := origin + velocity * p + Vector2(0, 80 * p * p)
					var length := (5 + i % 5) * (1.0 - p * 0.5)
					var direction := Vector2.from_angle(angle + p * 5)
					var shard := PackedVector2Array([pos + direction * length, pos + direction.orthogonal() * length * 0.4, pos - direction * length * 0.5])
					draw_colored_polygon(shard, _alpha(color, fade))
	if _aim_active:
		_draw_aim()


func _draw_projectile(fx: Dictionary, p: float, color: Color) -> void:
	var from: Vector2 = fx["from"]
	var to: Vector2 = fx["to"]
	var bend: Vector2 = fx["bend"]
	var style: String = fx["style"]
	var head := _bezier(from, bend, to, p)
	for i in range(10):
		var step := float(i) / 10.0
		var t0 := maxf(0.0, p - 0.30 + 0.30 * step)
		var t1 := maxf(0.0, p - 0.30 + 0.30 * (step + 1.0 / 10.0))
		var a := _bezier(from, bend, to, t0)
		var b := _bezier(from, bend, to, t1)
		var width := 2.0 + 7.0 * step
		draw_line(a, b, _alpha(color, step * 0.20), width * 1.5, true)
		draw_line(a, b, _alpha(color.lightened(0.25), step * 0.77), width * 0.48, true)
		if style == "fire" and i % 3 == 0:
			var flutter := Vector2(sin(p * 35.0 + i * 7.0), cos(p * 29.0 + i)) * (1.0 - step) * 22.0
			_glow(a + flutter, 5.0 + step * 6, FIRE, step * 0.6)
	_glow(head, 32.0 if style == "fire" else 23.0, color, 0.95)
	draw_circle(head, 5.0 if style == "fire" else 3.5, _alpha(color.lightened(0.75), 0.95))
	if style in ["arcane", "energy"]:
		for i in range(3):
			var orbit := head + Vector2.from_angle(p * TAU * 3 + TAU * i / 3.0) * 13.0
			draw_circle(orbit, 2.2, _alpha(color, 0.75))


func _draw_aim() -> void:
	var color := GOLD if _aim_valid else Color("e28584")
	var bend := (_aim_from + _aim_to) * 0.5 + Vector2(0, -70)
	var previous := _aim_from
	for i in range(1, 41):
		var p := float(i) / 40.0
		var point := _bezier(_aim_from, bend, _aim_to, p)
		draw_line(previous, point, _alpha(color, 0.15), 9.0, true)
		if reduced or (i + int(_clock * 18)) % 5 < 3:
			draw_line(previous, point, _alpha(color, 0.65), 2.0, true)
		previous = point
	var direction := (_aim_to - _bezier(_aim_from, bend, _aim_to, 0.94)).normalized()
	var normal := direction.orthogonal()
	var arrow := PackedVector2Array([_aim_to, _aim_to - direction * 18 + normal * 9, _aim_to - direction * 13, _aim_to - direction * 18 - normal * 9])
	draw_colored_polygon(arrow, _alpha(color, 0.92))
	var radius := 25.0 if reduced else 25.0 + sin(_clock * 5) * 2
	for i in range(4):
		var angle := PI * 0.5 * i + (0.0 if reduced else _clock * 0.5)
		draw_arc(_aim_to, radius, angle + 0.13, angle + PI * 0.5 - 0.13, 10, _alpha(color, 0.65), 1.5, true)


func sound(kind: String, index: int = 0) -> void:
	if not audio_enabled or _audio_pool.is_empty():
		return
	var now := Time.get_ticks_msec()
	var throttle := 55 if kind in ["hover", "draw", "trigger"] else 23
	if now - int(_last_sound.get(kind, -1000)) < throttle:
		return
	_last_sound[kind] = now
	if not _audio_cache.has(kind):
		_audio_cache[kind] = _synthesize(kind)
	var player := _audio_pool[_audio_cursor % _audio_pool.size()]
	_audio_cursor += 1
	player.stop()
	player.stream = _audio_cache[kind]
	player.pitch_scale = pow(2.0, (index % 5) / 24.0)
	player.volume_db = -15.0 if kind == "hover" else -12.0 if kind.begins_with("prop_") else -4.5 if kind in ["land", "hit", "break"] else -7.0
	player.play()


func _synthesize(kind: String) -> AudioStreamWAV:
	## Original, low-amplitude short tonal cues. No copyrighted sound samples.
	var rate := 22050
	var duration := 0.16
	if kind in ["victory", "defeat"]:
		duration = 0.62
	elif kind in ["fire", "cast", "break", "turn", "release"]:
		duration = 0.28
	elif kind in ["hover", "click", "draw", "grab", "flip"]:
		duration = 0.07
	elif kind == "land":
		duration = 0.19
	elif kind.begins_with("prop_"):
		duration = 0.32
	var samples := int(duration * rate)
	var pcm := PackedByteArray()
	pcm.resize(samples * 2)
	var noise_seed := 73217
	var phase := 0.0
	var noise_low := 0.0
	for i in range(samples):
		var t := float(i) / float(rate)
		var p := t / duration
		var envelope := minf(1.0, t / 0.008) * pow(1.0 - p, 2.0)
		noise_seed = (noise_seed * 1103515245 + 12345) & 0x7fffffff
		var noise := float(noise_seed % 65536) / 32768.0 - 1.0
		noise_low = lerpf(noise_low, noise, 0.12)
		var noise_band := noise - noise_low
		var frequency := 580.0
		var sample := 0.0
		match kind:
			"prop_crystal", "prop_glass":
				frequency = 1046.5 if kind=="prop_crystal" else 783.99
				sample = sin(TAU*frequency*t)*exp(-p*3)*0.38+sin(TAU*frequency*2.76*t)*exp(-p*8)*0.18
			"prop_stone", "prop_wood":
				frequency = 180.0 if kind=="prop_stone" else 260.0
				sample = sin(TAU*frequency*t)*exp(-p*10)*0.60+noise_low*exp(-p*16)*0.25
			"prop_water":
				frequency = 480+900*exp(-p*8)
				phase+=TAU*frequency/rate
				sample = sin(phase)*exp(-p*4)*0.35+noise_low*0.17*sin(PI*p)
			"prop_fire":
				sample = noise_low*0.62+noise_band*exp(-p*10)*0.16+sin(TAU*120*t)*0.12
			"grab", "flip", "draw":
				# Short paper/leather rasp, with a subdued wooden body.
				var click_env := exp(-p * (9.0 if kind == "grab" else 5.0))
				frequency = 360.0 if kind == "grab" else 570.0
				sample = noise_band * 0.25 * click_env + sin(TAU * frequency * t) * 0.20
				envelope = minf(1.0, t / 0.002) * pow(1.0 - p, 1.7)
			"release":
				# A band-limited air sweep follows the acceleration, not selection.
				frequency = lerpf(530.0, 190.0, p)
				phase += TAU * frequency / rate
				sample = noise_low * 0.60 + noise_band * 0.12 + sin(phase) * 0.13
				envelope = pow(sin(p * PI), 1.2) * (1.0 - p * 0.35)
			"land":
				frequency = lerpf(128.0, 65.0, minf(1.0, p * 3.0))
				phase += TAU * frequency / rate
				sample = sin(phase) * 0.65 + noise_band * exp(-p * 20.0) * 0.33 + sin(TAU * 390.0 * t) * exp(-p * 9.0) * 0.14
				envelope = minf(1.0, t / 0.002) * pow(1.0 - p, 2.0)
			"hit", "damage", "slash", "break":
				frequency = lerpf(160.0, 55.0, p)
				phase += TAU * frequency / rate
				sample = sin(phase) * 0.56 + noise_band * exp(-p * 12) * (0.34 if kind == "hit" else 0.27)
				envelope = minf(1.0, t / 0.0025) * pow(1.0 - p, 2.1)
			"block", "shield", "install":
				frequency = 580.0 if kind == "install" else 820.0
				sample = sin(TAU * frequency * t) * 0.36 + sin(TAU * frequency * 1.50 * t) * 0.18 + sin(TAU * frequency * 2.02 * t) * 0.09
			"energy", "trigger", "select":
				frequency = lerpf(380.0, 950.0, p)
				phase += TAU * frequency / rate
				sample = sin(phase) * 0.44 + sin(phase * 2.0) * 0.1
			"fire", "cast":
				frequency = lerpf(240.0, 680.0, p)
				phase += TAU * frequency / rate
				sample = sin(phase) * 0.32 + noise * 0.13 * sin(PI * p)
			"victory":
				var step := mini(3, int(p * 4.0))
				frequency = [523.25, 659.25, 783.99, 1046.5][step]
				phase += TAU * frequency / rate
				sample = sin(phase) * 0.36 + sin(phase * 2) * 0.06
				envelope = minf(1.0, t / 0.018) * (0.65 + 0.35 * cos(p * PI))
			"defeat":
				frequency = lerpf(310.0, 110.0, p)
				phase += TAU * frequency / rate
				sample = sin(phase) * 0.40
			"turn":
				sample = sin(TAU * 440.0 * t) * 0.24 + sin(TAU * 660.0 * t) * 0.21
			_:
				frequency = 900.0 if kind == "hover" else 630.0
				sample = sin(TAU * frequency * t) * 0.29
		pcm.encode_s16(i * 2, int(clampf(sample * envelope * 0.24, -0.9, 0.9) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = pcm
	return stream
