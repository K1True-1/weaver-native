extends SceneTree
var checks := 0
var failures: Array[String] = []

func verify(value: bool, label: String) -> void:
	checks += 1
	if not value:failures.append(label);push_error(label)

func mouse(button: int, down: bool) -> InputEventMouseButton:
	var e=InputEventMouseButton.new();e.button_index=button;e.pressed=down
	return e

func key(code: int) -> InputEventKey:
	var e=InputEventKey.new();e.keycode=code;e.pressed=true
	return e

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main=load("res://main.tscn").instantiate()
	root.add_child(main)
	main.game.save_path="user://interaction-test.json"
	main.game.new_run("balanced",true,1001)
	main.game.s.settings.sound=false
	main.at_title=false;main._refresh();main.showcase=true
	main.fx.reduced=true;main.game.s.settings.motion=false
	await process_frame
	var uid=str(main.game.s.battle.hand[0].uid)
	var before=main.game.snapshot()
	main._card_pressed(uid)
	verify(main.selected_uid==uid,"click selects a card")
	main._input(mouse(MOUSE_BUTTON_RIGHT,true))
	verify(main.selected_uid.is_empty(),"right click cancels selected card")
	verify(main.game.snapshot()==before,"cancel does not spend cards or energy")
	main._card_pressed(uid)
	main.showcase_pointer=main.cards[uid].position+Vector2(80,70)
	main._drag_start(uid)
	verify(main.cards[uid].drag_active,"drag is active")
	main.showcase_pointer=main._anchor("enemy0")
	main._input(mouse(MOUSE_BUTTON_RIGHT,true))
	main._input(mouse(MOUSE_BUTTON_LEFT,false))
	verify(main.dragged_uid.is_empty() and not main.cards[uid].drag_active,"cancel clears drag and later mouse release")
	verify(main.game.snapshot()==before,"release after cancel never casts")
	main._card_pressed(uid);main._drag_start(uid)
	main._input(key(KEY_SPACE));main._input(key(KEY_2));main._input(key(KEY_ENTER))
	verify(int(main.game.s.battle.turn)==1 and main.selected_uid==uid and not main.busy,"battle shortcuts are ignored while dragging")
	main._input(key(KEY_ESCAPE))
	verify(main.selected_uid.is_empty() and main.dragged_uid.is_empty(),"Escape cancels drag")
	main._card_pressed(uid);main._drag_start(uid)
	main._notification(Control.NOTIFICATION_APPLICATION_FOCUS_OUT)
	verify(main.selected_uid.is_empty() and not main.cards[uid]._down,"focus loss releases pointer capture")
	var skill=main._show_uid("C24")
	main._card_pressed(skill);main._drag_start(skill);main.showcase_pointer=Vector2(1200,50);main._end_drag()
	verify(main.game.snapshot()==before,"top navigation is not a valid targetless cast zone")
	main._card_pressed(uid);main._install_dialog(0)
	verify(is_instance_valid(main.current_modal),"install dialog opens")
	main._input(mouse(MOUSE_BUTTON_RIGHT,true))
	verify(not is_instance_valid(main.current_modal) and main.selected_uid.is_empty(),"right click cancels an unconfirmed install")
	verify(main.game.snapshot()==before,"unconfirmed install has no resource cost")
	main._modal("mandatory",true,false)
	main._input(key(KEY_ESCAPE))
	verify(is_instance_valid(main.current_modal),"mandatory choice cannot be bypassed")
	main._close_modal()
	main._card_pressed(uid);main._info("test","modal shield")
	main._target_clicked("enemy0")
	verify(not main.busy and main.game.snapshot()==before,"modal prevents target interactions")
	main._close_modal();main._cancel_selection()
	var card=load("res://scripts/card_view.gd").new()
	card.drag_enabled=false;card.setup({"uid":"choice"},{"text":"choice"},null,ThemeDB.fallback_font)
	root.add_child(card);card._down=true;card._press_point=Vector2(-1000,-1000)
	card._gui_input(InputEventMouseMotion.new())
	verify(not card.drag_active,"choice-only cards cannot drag")
	card.queue_free();main.queue_free();await process_frame
	# AudioServer releases stopped playback on its next mixing block.
	await create_timer(0.15).timeout
	print("INTERACTION TESTS: ",checks-failures.size()," passed, ",failures.size()," failed")
	quit(0 if failures.is_empty() else 1)
