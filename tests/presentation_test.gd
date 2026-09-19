extends SceneTree
var checks:=0
var failures:Array[String]=[]

func verify(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)

func _initialize()->void:call_deferred("run")

func run()->void:
	var main=load("res://main.tscn").instantiate();root.add_child(main)
	main.game.save_path="user://presentation-test.json"
	main.game.new_run("balanced",true,1001)
	main.game.s.settings.sound=false;main.game.s.settings.motion=false
	main.at_title=false;main._refresh();main.showcase=true;main.showcase_pointer=Vector2(1590,985)
	await process_frame
	for slot in main.slot_nodes:
		verify(not slot.get_children().any(func(n):return n is Label),"empty slots have no instruction labels")
		verify(not slot.tooltip_text.is_empty(),"empty slot explanation remains available on hover")
	for button in [main.deck_button,main.discard_button,main.exhaust_button]:
		verify(button.text.is_empty() and button.has_meta("count"),"pile is an icon and numeric count")
		verify(not button.tooltip_text.is_empty(),"pile has discoverable tooltip")
	verify(main.hint_label.text.is_empty(),"no permanent tutorial banner")
	verify(main.energy_label.get_parent().size.x<=96,"energy orb remains a secondary element")
	verify(main.units.self.figure!=null and main.units.enemy0.figure!=null,"both duel characters load original cutout figures")
	var hero_rect:Rect2=main.units.self.get_global_rect()
	var enemy_rect:Rect2=main.units.enemy0.get_global_rect()
	verify(is_equal_approx(hero_rect.get_center().x,enemy_rect.get_center().x),"single enemy and hero share the central vertical axis")
	verify(enemy_rect.end.y<hero_rect.position.y,"opponent is above the player without overlapping hit areas")
	verify(main.units.self.health_text()==str(int(main.game.s.run.hp)),"hero jewel shows current HP only")
	verify(main.units.enemy0.health_text()==str(int(main.game.s.battle.enemies[0].hp)),"enemy jewel shows current HP only")
	verify(not is_instance_valid(main.header_hp),"battle does not duplicate hero HP in the top bar")
	verify(main.units.self.tooltip_text.begins_with("织律者"),"character identity is still available on hover")
	var phase=float(main.units.self.clock);await create_timer(0.06).timeout
	verify(is_equal_approx(main.units.self.clock,phase),"reduced motion freezes character idle")
	main.log_button.pressed.emit()
	verify(is_instance_valid(main.current_modal),"log icon opens the real combat log")
	main._close_modal()
	var enemy=main.game.s.battle.enemies[0].duplicate(true);enemy.id="enemy1";main.game.s.battle.enemies.append(enemy)
	var object=main.game.s.battle.objects[0].duplicate(true);object.id="object1";main.game.s.battle.objects.append(object)
	main._refresh();await process_frame
	verify(main.units.enemy0.get_global_rect().end.y<main.units.self.get_global_rect().position.y and main.units.enemy1.get_global_rect().end.y<main.units.self.get_global_rect().position.y,"both opponents remain on the upper side")
	verify(not main.units.enemy0.get_global_rect().intersects(main.units.enemy1.get_global_rect()),"opponent hit regions do not overlap")
	verify(not main.object_nodes.object0.get_global_rect().intersects(main.object_nodes.object1.get_global_rect()),"two object panels never overlap")
	for obj in main.object_nodes.values():
		for actor in main.units.values():verify(not obj.get_global_rect().intersects(actor.get_global_rect()),"object and actor hit regions remain separate")
	for obj in main.object_nodes.values():
		var point=obj.global_position+obj.size*0.5
		verify(main._target_at(point) in main.object_nodes,"object is directly targetable in crowded battle")
	main.fx.cleanup();main.queue_free();await process_frame
	print("PRESENTATION TESTS: ",checks-failures.size()," passed, ",failures.size()," failed")
	quit(0 if failures.is_empty() else 1)
