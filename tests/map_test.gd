extends SceneTree
const Game = preload("res://scripts/game.gd")
const RouteMap = preload("res://scripts/route_map.gd")
var checks := 0
var failures: Array[String] = []
var last_selection: Dictionary = {}

func verify(value: bool, label: String) -> void:
	checks+=1
	if not value:failures.append(label);push_error(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game=Game.new()
	game.save_path="user://map-test.json"
	game.new_run("balanced",false,12345)
	for chapter in range(3):
		for step in range(8):
			game.s.run.chapter=chapter;game.s.run.step=step
			game.s.run.next=null
			game.s.run.pairFirst={"2":"event","6":"camp"}
			game.prepare_next()
			var before=game.snapshot()
			var chart=RouteMap.new();root.add_child(chart)
			chart.setup(game.s.run,ThemeDB.fallback_font,false)
			chart.node_selected.connect(func(node):last_selection=node)
			verify(chart.rows.size()==8,"each chapter shows 8 stages")
			verify(chart.node_buttons.size()==game.s.run.next.size(),"only real next nodes are selectable")
			verify(game.snapshot()==before,"map construction never consumes RNG or mutates the run")
			for node in game.s.run.next:
				chart.node_buttons[str(node.id)].pressed.emit()
				verify(str(last_selection.id)==str(node.id),"node click uses its actual engine id")
				verify(chart.selected_id==str(node.id),"node selection updates visual state")
			chart.select_node("not-a-real-node")
			verify(chart.selected_id==str(game.s.run.next.back().id),"unknown or future node id is rejected")
			chart._process(1)
			verify(chart.clock==0,"reduced motion stops map pulse")
			verify(game.snapshot()==before,"selection previews never enter or modify a node")
			chart.queue_free();await process_frame
	verify(RouteMap.preview_types(4,{"pairFirst":{"2":"event"}})==["shop"],"event precedes complementary shop")
	verify(RouteMap.preview_types(4,{"pairFirst":{"2":"shop"}})==["event"],"shop precedes complementary event")
	verify(RouteMap.preview_types(7,{"pairFirst":{"6":"camp"}})==["treasure"],"camp precedes complementary treasure")
	verify(RouteMap.preview_types(7,{"pairFirst":{"6":"treasure"}})==["camp"],"treasure precedes complementary camp")
	game.s.run.chapter=0;game.s.run.step=0;game.s.run.next=null;game.prepare_next()
	var id=str(game.s.run.next[1].id)
	await game.enter_node(id)
	game.finish_node()
	verify(int(game.s.run.history.back().branch)==1,"chosen branch persists for the completed route")
	print("MAP TESTS: ",checks-failures.size()," passed, ",failures.size()," failed")
	quit(0 if failures.is_empty() else 1)
