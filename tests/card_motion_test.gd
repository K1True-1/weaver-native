extends SceneTree
const CardView = preload("res://scripts/card_view.gd")
var failures: Array[String] = []
var checks: int = 0

func verify(condition: bool, text: String) -> void:
 checks+=1
 if not condition:
  failures.append(text)
  push_error(text)

func step_card(card: Control, seconds: float, dt: float=1.0/120.0) -> void:
 var remaining=seconds
 while remaining>0.00001:
  var step=minf(dt,remaining)
  card._process(step)
  remaining-=step

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var parent=Control.new()
 parent.position=Vector2(63,47)
 parent.scale=Vector2(0.91,0.91)
 parent.rotation=0.11
 root.add_child(parent)
 var card=CardView.new()
 # setup before entering the tree is explicitly supported.
 card.setup({"id":"C01","uid":"motion-test"},{"name":"短剑","cost":1.0,"type":"attack","text":"造成 6 点伤害。"},null,ThemeDB.fallback_font)
 parent.add_child(card)
 card.move_to(Vector2(60,90),0.14,false)
 card.move_to(Vector2(640,590),-0.09,true,0.0)
 var max_x=-INF
 for i in range(240):
  card._process(1.0/120.0)
  max_x=maxf(max_x,card.position.x)
  if not card.position.is_finite(): break
 verify(card.position.is_finite(),"spring position stays finite")
 verify(max_x>640.1 and max_x<680.0,"return has a small bounded overshoot")
 verify(card.position.distance_to(Vector2(640,590))<0.001,"spring settles exactly to the destination")
 verify(absf(card.rotation+0.09)<0.0001,"rotation settles exactly")
 verify(not card._spring_active,"settled cards stop animation processing")

 card.move_to(Vector2(80,210),0.06,true,0.0)
 step_card(card,0.06)
 var before_position=card.position
 var before_velocity=card._position_velocity
 card.move_to(Vector2(450,370),-0.02,true,0.0)
 verify(card.position.is_equal_approx(before_position),"retargeting does not teleport")
 verify(card._position_velocity.is_equal_approx(before_velocity),"retargeting preserves spring momentum")
 step_card(card,1.5,1.0/30.0)
 verify(card.position.distance_to(Vector2(450,370))<0.001,"30 fps spring converges")

 card.move_to(Vector2(100,150),0.12,false)
 card.scale=Vector2.ONE*1.075
 var grabbed=Vector2(31,79)
 var initial=card.get_global_transform()*grabbed
 card._remember_press(initial)
 # Simulates a selected card already lifting after mouse-down, before the
 # drag threshold is passed. The original point must still be grabbed.
 card.position+=Vector2(0,-17)
 card.begin_drag(initial+Vector2(16,-5))
 verify((card.get_global_transform()*grabbed).distance_to(initial+Vector2(16,-5))<0.002,"first clicked point survives a pre-drag selection lift")
 var worst_error=0.0
 var maximum_tilt=0.0
 for i in range(250):
  var pointer=Vector2(720+sin(i*0.7)*680,420+cos(i*0.57)*360)
  card.follow_pointer(pointer,1.0/120.0 if i%2==0 else 1.0/30.0)
  worst_error=maxf(worst_error,(card.get_global_transform()*grabbed).distance_to(pointer))
  card._process(1.0/60.0)
  worst_error=maxf(worst_error,(card.get_global_transform()*grabbed).distance_to(pointer))
  maximum_tilt=maxf(maximum_tilt,absf(card.rotation))
 verify(worst_error<0.003,"rapid dragging keeps the grabbed pixel under the pointer: %.6f px" % worst_error)
 verify(maximum_tilt<0.2,"drag tilt is bounded under abrupt reversals")
 verify(card.position.is_finite() and card.scale.is_finite(),"rapid pointer reversals never produce invalid transforms")
 var last_position=card.position
 card.end_drag()
 verify(card.position.is_equal_approx(last_position),"release starts from the actual dragged position")
 step_card(card,1.8,1.0/60.0)
 verify(card.position.distance_to(Vector2(100,150))<0.001,"released card springs back to its saved hand slot")
 verify(not card.drag_active and not card._spring_active,"released card comes to rest without ongoing jitter")

 card.move_to(Vector2(320,340),0.0,true,0.18)
 var delayed=card.position
 step_card(card,0.12)
 verify(card.position.is_equal_approx(delayed),"per-card stagger preserves initial position until delay ends")
 step_card(card,1.5)
 verify(card.position.distance_to(Vector2(320,340))<0.001,"delayed spring completes normally")

 var enemy=CardView.new()
 enemy.interactive=false
 enemy.setup({"id":"enemy","uid":"enemy-visual"},{"cost":2.0,"name":"Enemy","text":"","type":"attack"},null,ThemeDB.fallback_font)
 parent.add_child(enemy)
 enemy.set_face_down(true)
 enemy.scale=Vector2(0.13,0.81)
 enemy.rotation=0.41
 enemy.position=Vector2(860,60)
 step_card(enemy,2.0)
 verify(enemy.face_down,"VFX face-down setter updates the back")
 verify(enemy.scale.is_equal_approx(Vector2(0.13,0.81)) and is_equal_approx(enemy.rotation,0.41),"unlaid-out enemy cards never fight VFX flip transforms")
 verify(enemy.position.is_equal_approx(Vector2(860,60)),"unlaid-out enemy card position stays owned by VFX")
 for dt in [1.0/240.0,1.0/60.0,1.0/20.0,0.35,1.5]:
  var state=CardView._spring(780.0,-900.0,20.0,18.5,0.72,dt)
  verify(state.is_finite(),"analytical spring is finite for delta %.4f" % dt)
 parent.queue_free()
 if failures.is_empty():
  print("PASS: %d card-motion assertions; drag-grab max error %.6f px" % [checks,worst_error])
  quit(0)
 else:
  print("FAIL: %d / %d assertions" % [failures.size(),checks])
  quit(1)
