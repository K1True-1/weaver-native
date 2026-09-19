extends SceneTree
var main

func _initialize()->void:call_deferred("run")

func capture(label:String,wait:float=0.2)->void:
	await create_timer(wait).timeout;await RenderingServer.frame_post_draw
	var folder=ProjectSettings.globalize_path("res://artifacts")
	assert(root.get_texture().get_image().save_png(folder+"/"+label+".png")==OK)
	print("PROP SCREENSHOT ",label)

func tap(id:String)->void:
	var point:Vector2=main.object_nodes[id].target_center()
	var count:int=main.object_nodes[id].reaction_count
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point
	root.push_input(motion,true)
	var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=point;event.global_position=point
	root.push_input(event,true)
	event=event.duplicate();event.pressed=false;root.push_input(event,true)
	assert(main.object_nodes[id].reaction_count==count+1,"native viewport input must activate the physical sprite")

func run()->void:
	root.size=Vector2i(1600,1000)
	main=load("res://main.tscn").instantiate();root.add_child(main)
	main.game.save_path="user://prop-capture.json";main.showcase=true;main.showcase_pointer=Vector2(1590,985)
	await main._screen_action("practice",[])
	main.game.s.settings.sound=false;main.fx.audio_enabled=false
	await capture("battle-props",1.5)
	tap("object0");await capture("prop-crystal-click",0.12)
	var objects=[]
	for i in range(2):
		var d=main.game.db.objects[4+i]
		objects.append({"id":"object"+str(i),"def":d.id,"name":d.name,"hp":d.hp[0],"maxHp":d.hp[0],"block":0,"charges":d.charges,"dead":false,"art":d.art})
	for prop in main.object_nodes.values():prop.queue_free()
	main.object_nodes.clear();main.game.s.battle.objects=objects;main._refresh()
	await capture("prop-fire-water",1.0)
	tap("object0");tap("object1");await capture("prop-fire-water-click",0.18)
	main._set_visual_values({"type":"damage","target":"object0","hp_after":0})
	await capture("prop-rubble",0.7)
	main.fx.cleanup();main.queue_free();await process_frame;quit(0)
