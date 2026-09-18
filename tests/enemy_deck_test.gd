extends SceneTree
const Game = preload("res://scripts/game.gd")
const EnemyCards = preload("res://scripts/enemy_cards.gd")
var failures = 0
var passes = 0
var records: Array = []

func _initialize(): call_deferred("run_tests")
func expect(condition: bool, text: String):
	if condition: passes += 1
	else:
		failures += 1
		push_error(text)

func fresh(index: int = 0, seed_value: int = 42):
	var game = Game.new()
	game.save_path="user://enemy-deck-test.json"
	game.new_run("balanced",true,seed_value)
	game.s.run.node.enemyIndexes=[index]
	game.start_battle()
	game.pending_visuals.clear()
	return game

func conserves(enemy: Dictionary) -> bool:
	var actual: Array = []
	for zone in ["draw","hand","discard","resolving"]:
		for c in enemy[zone]: actual.append(c.uid)
	var expected = enemy.deck.map(func(c):return c.uid)
	actual.sort()
	expected.sort()
	var unique: Dictionary={}
	for id in actual: unique[id]=true
	return actual==expected and actual.size()==unique.size()

func replace_deck(enemy: Dictionary, definitions: Array):
	enemy.deck=[]
	for i in definitions.size():
		var d=definitions[i]
		enemy.deck.append({"id":d.id,"uid":enemy.id+"_test_"+str(i),"up":false,"definition":d})
	enemy.hand=enemy.deck.duplicate(true)
	enemy.draw=[]
	enemy.discard=[]
	enemy.resolving=[]
	enemy.turn_active=false
	enemy.energy=3
	enemy.actions_played=0

func attack(key: String, damage: int, cost: int=1, hits: int=1):
	return EnemyCards.make_card(key,key,cost,"attack",0,{"damage":damage,"hits":hits})

func test_all_enemies():
	for index in 15:
		var game=fresh(index)
		var e=game.s.battle.enemies[0]
		expect(e.deck.size()>=8 and e.deck.size()<=10,"敌人 %d 拥有真实 8–10 张牌组" % index)
		expect(e.hand.size()==3 and e.draw.size()==e.deck.size()-3 and conserves(e),"敵人 %d 起手和牌区守恒" % index)
		var captures: Array=[]
		game.presenter=func(cue):
			if cue.type=="enemy_cast":
				captures.append(cue)
				expect(e.resolving.size()==1 and e.resolving[0].uid==cue.card.uid,"展演时卡在 resolving")
				expect(not e.hand.any(func(c):return c.uid==cue.card.uid),"已出牌已离开真实手牌")
				expect(conserves(e),"展演牌区守恒")
				expect(cue.definition.has_all(["name","text","cost","type","tags","art","rarity"]),"对手卡标准信息完整")
		for round_index in 5:
			game.s.run.hp=500
			game.s.run.maxHp=500
			await game.end_turn()
			expect(conserves(e),"敌人 %d 第 %d 回合牌区守恒" % [index,round_index])
			expect(e.actions_played<=3 and e.energy>=0,"每轮费用与最多 3 张出牌约束")
			expect(e.resolving.is_empty(),"稳定边界无悬空结算牌")
		expect(captures.size()>0,"15 种敌人都通过真实卡行动")

func test_no_phantom_and_order():
	var game=fresh()
	var e=game.s.battle.enemies[0]
	replace_deck(e,[])
	e.intent={"kind":"attack","damage":99,"hits":3}
	await game.end_turn()
	expect(game.s.run.hp==80 and e.actions_played==0,"无卡即无攻击，旧意图无法凭空执行")
	var counter=EnemyCards.make_card("counter","反击",2,"counter",0,{"damage":9})
	var guard=EnemyCards.make_card("guard","防御",1,"guard",1,{"block":5})
	replace_deck(e,[counter,guard])
	var played: Array=[]
	game.presenter=func(cue):
		if cue.type=="enemy_cast": played.append(cue.card.id)
	await game.end_turn()
	expect(played==["guard","counter"],"AI 先支付护甲牌，再满足反击前置")
	expect(e.energy==0 and game.s.run.hp==71 and e.discard.size()==2,"顺序出牌消耗 3 能量且伤害匹配")
	var combo=EnemyCards.make_card("combo","连击",1,"combo",0,{"damage":20})
	replace_deck(e,[combo])
	await game.end_turn()
	expect(e.actions_played==0,"无先手牌不能使用连击")
	replace_deck(e,[attack("expensive",50,4)])
	await game.end_turn()
	expect(e.actions_played==0 and e.hand.size()==1,"费用不足不能出牌或透支")

func test_object_cards():
	var game=fresh()
	var e=game.s.battle.enemies[0]
	var shatter=EnemyCards.make_card("shatter","夺取晶簇",2,"object_attack",2,{"damage":20})
	replace_deck(e,[shatter,attack("jab",3)])
	game.s.battle.objects[0].def="O02"
	game.s.battle.objects[0].hp=4
	game.s.battle.objects[0].block=0
	var played: Array=[]
	game.presenter=func(cue):
		if cue.type=="enemy_cast": played.append({"id":cue.card.id,"target":cue.target})
	await game.end_turn()
	expect(played.size()==2 and played[0].id=="shatter" and played[0].target=="object0","物件收益驱动先打真实夺取卡")
	expect(e.strength==2 and e.energy==0 and game.s.run.hp==75,"物件攻击支付能量，收益用于后续实体攻击")
	expect(conserves(e),"摧毁物件时敌牌守恒")
	replace_deck(e,[shatter])
	var hp=game.s.run.hp
	await game.end_turn()
	expect(e.actions_played==0 and game.s.run.hp==hp and e.hand.size()==1,"物件失效时不出非法牌、不生成回退攻击")
	var changed=fresh()
	var ce=changed.s.battle.enemies[0]
	replace_deck(ce,[shatter])
	changed.s.battle.objects[0].hp=1
	changed.presenter=func(cue):
		if cue.type=="enemy_cast":
			changed.s.battle.objects[0].dead=true
			changed.s.battle.objects[0].hp=0
	await changed.end_turn()
	expect(changed.s.run.hp==80 and ce.discard.size()==1 and ce.energy==1,"展演中目标失效仅消耗所出卡，绝不凭空转攻击")
	changed.presenter=Callable()

func test_death_and_snapshots():
	var game=fresh()
	var e=game.s.battle.enemies[0]
	replace_deck(e,[attack("killer",100),attack("spare",10),attack("spare2",10)])
	var played: Array=[]
	game.presenter=func(cue):
		if cue.type=="enemy_cast":played.append(cue.card.uid)
	await game.end_turn()
	expect(game.s.screen=="defeat" and played.size()==1,"玩家死亡后其余手牌不继续出")
	expect(e.hand.size()==2 and e.discard.size()==1 and conserves(e),"致命牌进弃牌，未出牌仍在手中")
	var allies=fresh()
	allies.s.run.node.enemyIndexes=[0,1]
	allies.start_battle()
	allies.pending_visuals.clear()
	var dead=allies.s.battle.enemies[0]
	var live=allies.s.battle.enemies[1]
	dead.hp=0
	replace_deck(dead,[attack("dead_attack",99)])
	replace_deck(live,[attack("live_attack",2)])
	var actors: Array=[]
	allies.presenter=func(cue):
		if cue.type=="enemy_cast":actors.append(cue.enemy_id)
	await allies.end_turn()
	expect(actors==[live.id] and dead.hand.size()==1,"阵亡敌人跳过所有手牌，其他敌人仍正常出牌")
	# Separate save/replay scenario preserves hand order, deck RNG and all resource state.
	var stable=fresh(6,123)
	stable.s.run.hp=500
	stable.s.run.maxHp=500
	await stable.end_turn()
	var restored=Game.new(JSON.parse_string(JSON.stringify(stable.snapshot())))
	var left: Array=[]
	var right: Array=[]
	stable.presenter=func(cue):
		if cue.type=="enemy_cast":left.append([cue.card.uid,cue.target])
	restored.presenter=func(cue):
		if cue.type=="enemy_cast":right.append([cue.card.uid,cue.target])
	await stable.end_turn()
	await restored.end_turn()
	expect(left==right and stable.s.run.hp==restored.s.run.hp,"存档恢复后抽牌和选牌顺序确定性相同")
	expect(conserves(restored.s.battle.enemies[0]),"恢复后敌人实体牌守恒")
	var legacy=fresh().snapshot()
	for key in ["deck_version","deck","draw","hand","discard","resolving"]:legacy.battle.enemies[0].erase(key)
	var migrated=Game.new(legacy)
	expect(migrated.s.battle.enemies[0].deck.size()==8 and conserves(migrated.s.battle.enemies[0]),"旧存档自动创建真实牌区而不崩溃")
	await migrated.end_turn()
	expect(migrated.s.battle.turn==2,"迁移旧存档仍可继续战斗")

func test_sequential_visual_values():
	var game=fresh()
	var e=game.s.battle.enemies[0]
	replace_deck(e,[attack("multi",3,2,3)])
	var hits: Array=[]
	game.presenter=func(cue):
		if cue.type=="hit": hits.append(cue)
	await game.end_turn()
	expect(hits.size()==3 and hits[0].hp_after==77 and hits[1].hp_after==74 and hits[2].hp_after==71,"多段攻击逐段提供 HP 快照")
	expect(hits.all(func(cue):return cue.has("block_after")),"命中动画含护甲快照")

func run_tests():
	await test_all_enemies()
	await test_no_phantom_and_order()
	await test_object_cards()
	await test_death_and_snapshots()
	await test_sequential_visual_values()
	print("ENEMY DECK TESTS: %d passed, %d failed" % [passes,failures])
	quit(1 if failures else 0)
