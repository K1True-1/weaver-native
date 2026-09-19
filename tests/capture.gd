extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(label: String) -> void:
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var folder = ProjectSettings.globalize_path("res://artifacts")
	DirAccess.make_dir_recursive_absolute(folder)
	var result = root.get_texture().get_image().save_png(folder + "/" + label + ".png")
	assert(result == OK)
	print("SCREENSHOT ", label, " fps=", Engine.get_frames_per_second())

func run() -> void:
	root.size = Vector2i(1600,1000)
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.showcase=true;main.showcase_pointer=Vector2(1590,985)
	main.game.save_path = "user://visual-test-only.json"
	main.fx.audio_enabled=false
	root.warp_mouse(Vector2(1580,985))
	await capture("title")
	await main._screen_action("practice", [])
	await capture("battle")
	var hover_uid=str(main.game.s.battle.hand[3].uid)
	main.showcase_pointer=main.cards[hover_uid].base_position+Vector2(85,100)
	await capture("card-detail")
	main.showcase_pointer=Vector2(1590,985)
	var enemy=main.game.s.battle.enemies[0].duplicate(true)
	enemy.id="enemy1";enemy.name="灰刃护卫"
	main.game.s.battle.enemies.append(enemy)
	var object=main.game.s.battle.objects[0].duplicate(true)
	object.id="object1"
	main.game.s.battle.objects.append(object)
	main._refresh()
	await capture("battle-crowded")
	main._home()
	main.game.new_run("balanced", false, 101)
	main.at_title=false
	main._refresh()
	await capture("map")
	main.game.s.run.step=3
	main.game.s.run.history=[{"type":"battle","chapter":0,"depth":1,"branch":1},{"type":"event","chapter":0,"depth":2,"branch":0},{"type":"elite","chapter":0,"depth":3,"branch":1}]
	main.game.s.run.pairFirst={"2":"event"};main.game.s.run.next=null;main.game.prepare_next();main._refresh()
	await capture("map-progress")
	await main.game.enter_node(str(main.game.s.run.next[0].id))
	main._refresh()
	await capture("shop")
	main.queue_free()
	await process_frame
	quit(0)
