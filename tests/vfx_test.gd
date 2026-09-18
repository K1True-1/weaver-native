extends SceneTree

const VFX = preload("res://scripts/vfx.gd")

class RevealCard extends Control:
	var face_down := false
	var changes: Array[bool] = []
	func set_face_down(value: bool) -> void:
		face_down = value
		changes.append(value)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1600, 1000)
	var scene := Control.new()
	scene.size = Vector2(1600, 1000)
	root.add_child(scene)
	var target := Panel.new()
	target.position = Vector2(800, 300)
	target.size = Vector2(150, 190)
	scene.add_child(target)
	var fx = VFX.new()
	scene.add_child(fx)
	await process_frame
	fx.audio_enabled = false
	fx.fast = true
	var contact_kinds: Array[String] = []
	fx.contact.connect(func(kind: String, center: Vector2) -> void:
		contact_kinds.append(kind)
		if kind == "landing" and not fx._owned_cards.is_empty():
			var card: Control = fx._owned_cards.back()
			var card_center: Vector2 = card.get_global_transform() * (card.size * 0.5)
			assert(card_center.distance_to(center) < 0.1, "Landing cue and visual contact share one exact frame")
	)
	fx.aim(Vector2(500, 850), Vector2(880, 390), true)
	fx.ring(Vector2(880, 390), Color.CYAN)
	fx.float_text("+8", Vector2(880, 330))
	fx.pulse(target)
	fx.shake(target)
	fx.card_hover(target)
	fx.card_press(target)
	fx.grab_card(target)
	fx.drag_feedback(target, Vector2(800, 150))
	await fx.projectile(Vector2(500, 850), Vector2(880, 390), "fire")
	await fx.impact(target, 12)
	await fx.impact(target, 3, "block")
	assert(fx._labels.back().text == "格挡 3", "Blocked damage is distinct from gaining armor")
	await fx.impact(target, 8, "shield")
	assert(fx._labels.back().text == "护甲 +8", "Shield gain retains the positive value")
	await fx.impact(target, 2, "energy")
	await fx.impact(target, 0, "break")
	for style in ["cast", "install", "draw"]:
		var card := Panel.new()
		card.position = Vector2(500, 750)
		card.size = Vector2(150, 220)
		fx.add_child(card)
		card.pivot_offset = Vector2(75, 205)
		fx._card_pose(card, Vector2(640, 400), Vector2(0.42, 0.42), 0.21, 1.0)
		var visual_center: Vector2 = card.get_global_transform() * (card.size * 0.5)
		assert(visual_center.distance_to(Vector2(640, 400)) < 0.001, "Card pose honors target center with bottom pivot, rotation and scale")
		await fx.card_flight(card, Vector2(900, 300), style)
	assert("landing" in contact_kinds)
	var revealed := RevealCard.new()
	revealed.size = Vector2(170, 258)
	revealed.scale = Vector2.ONE * 0.315
	revealed.rotation = 0.14
	fx.add_child(revealed)
	await fx.enemy_reveal(revealed, Vector2(800, 50), Vector2(800, 450))
	assert(is_instance_valid(revealed) and not revealed.is_queued_for_deletion(), "Reveal keeps card for subsequent display/retirement")
	assert(revealed.changes == [true, false], "Card flips face at the narrow transform frame")
	assert(revealed.scale.distance_to(Vector2.ONE * 1.08) < 0.001, "Small enemy hand card expands to readable display scale")
	assert((revealed.get_global_transform() * (revealed.size * 0.5)).distance_to(Vector2(800, 450)) < 0.01)
	await fx.card_flight(revealed, Vector2(1100, 300), "enemy")
	var actor_start := target.position
	await fx.actor_strike(target, Vector2(400, 750), "physical")
	assert(target.position.distance_to(actor_start) < 0.01, "Actor returns after anticipation and attack")
	fx.actor_strike(target, Vector2(400, 750), "fire")
	await create_timer(0.02).timeout
	fx.cleanup()
	await create_timer(0.12).timeout
	assert(target.position.distance_to(actor_start) < 0.01, "Cleanup restores interrupted actor transform")
	var interrupted := Panel.new()
	interrupted.size = Vector2(170, 258)
	fx.add_child(interrupted)
	fx.card_flight(interrupted, Vector2(800, 300))
	await create_timer(0.02).timeout
	fx.cleanup()
	await create_timer(0.04).timeout
	assert(not is_instance_valid(interrupted), "Cleanup retires an in-flight clone without an awaiting deadlock")
	await fx.banner("原生动效验证", "飞行 · 护盾 · 粒子 · 界面转场", "victory")
	fx.fast = false
	for i in range(30):
		fx.burst(Vector2(500, 300), Color.GOLD, 50)
	assert(fx._particle_count <= 240, "Particle limit must remain bounded")
	assert(fx._emitters.size() <= 12, "Emitter limit must remain bounded")
	fx.cleanup()
	assert(fx._particle_count == 0)
	assert(fx._effects.is_empty())
	assert(fx._owned_cards.is_empty())
	assert(not fx.is_processing(), "Clean overlay must not idle-process")
	fx.reduced = true
	var reduced_reveal := RevealCard.new()
	reduced_reveal.size = Vector2(170, 258)
	reduced_reveal.scale = Vector2.ONE * 0.315
	fx.add_child(reduced_reveal)
	await fx.enemy_reveal(reduced_reveal, Vector2(800, 50), Vector2(800, 450), 1.12)
	assert(reduced_reveal.scale.distance_to(Vector2.ONE * 1.12) < 0.001, "Reduced reveal uses the requested readable display scale")
	assert((reduced_reveal.get_global_transform() * (reduced_reveal.size * 0.5)).distance_to(Vector2(800, 450)) < 0.001)
	fx.cleanup()
	fx.burst(Vector2(0, 0), Color.WHITE, 500)
	assert(fx._particle_count == 0, "Reduced mode suppresses particle emission")
	fx.aim(Vector2.ZERO, Vector2(800, 400), true)
	assert(not fx.is_processing(), "Static reduced aim must not idle-process")
	fx.clear_aim()
	fx.audio_enabled = true
	for cue in ["hover", "draw", "grab", "flip", "release", "land", "click", "hit", "block", "cast", "fire", "energy", "install", "trigger", "turn", "victory", "defeat"]:
		fx.sound(cue)
	await create_timer(0.15).timeout
	fx.cleanup()
	await create_timer(0.10).timeout
	print("VFX PASS: exact-frame landing, enemy flip/reveal, actor anticipation/recovery, interrupted animation cleanup, sound generation, bounded particles, reduced mode")
	quit(0)
