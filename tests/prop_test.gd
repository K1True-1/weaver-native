extends SceneTree
var checks:=0
var failures:Array[String]=[]

func verify(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)

func click()->InputEventMouseButton:
	var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	return event

func _initialize()->void:call_deferred("run")

func run()->void:
	var main=load("res://main.tscn").instantiate();root.add_child(main)
	main.game.save_path="user://prop-test.json"
	main.game.new_run("balanced",true,1001)
	main.game.s.settings.sound=false;main.game.s.settings.motion=false
	main.at_title=false;main._refresh();main.showcase=true;main.showcase_pointer=Vector2(1590,985)
	await process_frame
	var before=main.game.snapshot()
	var prop=main.object_nodes.object0
	main._object_input(click(),"object0")
	verify(prop.reaction_count==1,"empty-handed click activates physical object reaction")
	verify(not is_instance_valid(main.current_modal),"cosmetic click never opens an intrusive dialog")
	verify(main.game.snapshot()==before,"click changes no HP, energy, inventory, rewards or game RNG")
	for i in range(100):main._object_input(click(),"object0")
	verify(prop.reaction_count==1,"rapid click spam is bounded by cooldown")
	for i in range(5):prop._process(0.05)
	main._object_input(click(),"object0")
	verify(prop.reaction_count==2,"object can be tapped again after cooldown")
	verify(not prop is Panel and prop.get_child_count()==0,"object has no panel, nameplate or rectangular label children")
	verify(main._target_at(prop.target_center())=="object0","real sprite is still a valid aiming target")
	verify(not prop.contains_global(prop.global_position+Vector2(1,1)),"transparent corner is not an invisible clickable rectangle")
	var count=prop.reaction_count
	main._info("test","modal shield");main._object_input(click(),"object0")
	verify(prop.reaction_count==count,"modal blocks background object interactions")
	main._close_modal();main.busy=true;main._object_input(click(),"object0")
	verify(prop.reaction_count==count,"enemy resolution blocks accidental object interactions")
	main.busy=false
	var phase=prop.clock;prop._process(0.05)
	verify(is_equal_approx(prop.clock,phase),"reduced motion freezes idle magic")
	for definition in main.game.db.objects.slice(0,8):
		var view=load("res://scripts/prop_view.gd").new()
		var data={"id":"test","def":definition.id,"hp":6,"maxHp":6,"block":0,"dead":false}
		view.setup(data,main.font);root.add_child(view)
		verify(view.sprite!=null and view.alpha_mask!=null,"distinct transparent art loaded: "+definition.id)
		verify(view.health_text()=="6","current durability only: "+definition.id)
		verify(view._has_point(view.sprite_rect.get_center()),"opaque sprite center receives clicks: "+definition.id)
		verify(not view._has_point(Vector2.ZERO),"transparent outer padding ignores clicks: "+definition.id)
		verify(view.poke(),"click response is available: "+definition.id)
		data.hp=0;data.dead=true;view.update_data(data)
		verify(view.dead and not view.poke() and not view._has_point(view.sprite_rect.get_center()),"destroyed object cannot reactivate: "+definition.id)
		view.queue_free()
	# Selected-card click uses the same targeting flow as before, with real cost and reward.
	var energy=int(main.game.s.battle.energy)
	var attack=main._show_uid("C01")
	main._card_pressed(attack);main._object_input(click(),"object0")
	var deadline=Time.get_ticks_msec()+5000
	while main.busy and Time.get_ticks_msec()<deadline:await process_frame
	verify(not main.busy,"targeted card action finishes")
	verify(main.game.s.battle.objects[0].dead and prop.dead,"real attack shatters the object and updates its scene representation")
	verify(int(main.game.s.battle.energy)==energy-1,"real attack spends its ordinary energy cost")
	verify(int(main.game.s.battle.block)==5,"crystal break retains the real five-armor reward")
	verify(prop.reaction_count==count,"targeted attack is not interpreted as a cosmetic tap")
	var sound_hashes={}
	for cue in ["prop_crystal","prop_glass","prop_stone","prop_wood","prop_water","prop_fire"]:
		var stream:AudioStreamWAV=main.fx._synthesize(cue)
		verify(stream.data.size()>1000,"material sound has real audio samples: "+cue)
		sound_hashes[hash(stream.data)]=true
	verify(sound_hashes.size()==6,"six material sounds have different waveforms")
	main.fx.cleanup();main.queue_free();await process_frame
	print("PROP TESTS: ",checks-failures.size()," passed, ",failures.size()," failed")
	quit(0 if failures.is_empty() else 1)
