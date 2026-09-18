extends SceneTree
const Game = preload("res://scripts/game.gd")
var failures = 0
var passes = 0
var presented: Array = []

func _initialize(): call_deferred("run_tests")
func expect(condition: bool, text: String):
	if condition: passes += 1
	else:
		failures += 1
		push_error(text)

func fresh(seed_value: int = 42):
	var game = Game.new()
	game.save_path = "user://engine-test-save.json"
	game.new_run("balanced",true,seed_value)
	game.pending_visuals.clear()
	game.presenter = func(event): presented.append(event.duplicate(true))
	return game

func setup_cards(game, specs: Array, energy: int = 20):
	var b = game.s.battle
	b.hand = []
	b.draw = []
	b.discard = []
	b.exhaust = []
	b.resolving = []
	b.slots = [null,null,null]
	b.queue = []
	b.energy = energy
	game.s.run.deck = []
	for spec in specs:
		var c = game.card(spec[0],spec[1] if spec.size()>1 else false)
		game.s.run.deck.append(c.duplicate(true))
		b.hand.append(c)
	game.pending_visuals.clear()

func conserves(game) -> bool:
	var b = game.s.battle
	var ids: Array = []
	for zone in ["hand","draw","discard","exhaust","resolving"]:
		for c in b[zone]: ids.append(c.uid)
	for binding in b.slots:
		if binding: ids.append(binding.card.uid)
	var expected = game.s.run.deck.map(func(c): return c.uid)
	ids.sort()
	expected.sort()
	return ids == expected

func choose_last(options: Dictionary) -> Array:
	if options.cards.is_empty(): return []
	return [options.cards.back().uid]

func test_all_cards():
	for id in Game.new().db.cards.keys():
		for up in [false,true]:
			var game = fresh()
			setup_cards(game,[[id,up],["C01"],["C02"],["C01"],["C14"],["C11"]])
			var b = game.s.battle
			var c = b.hand[0]
			b.block = 10
			b.manual = 3
			b.draw = b.hand.slice(2,5)
			b.discard = b.hand.slice(5)
			b.hand = b.hand.slice(0,2)
			game.chooser = choose_last
			var kind = game.target_kind(c)
			var target = "enemy0" if kind in ["enemy","attack"] else "self"
			await game.play(c.uid,target)
			expect(game.last_error.is_empty(),"执行 %s up=%s" % [id,up])
			expect(conserves(game),"实体牌守恒 %s up=%s" % [id,up])

func test_rules():
	var game = fresh()
	setup_cards(game,[["C02"],["C01"],["C04"],["C11"]],3)
	var b = game.s.battle
	var guard = b.hand[0]
	var strike = b.hand[1]
	await game.install(guard.uid,0,"T01","self")
	expect(b.energy==2 and b.block==0,"安装支付费用但不执行")
	expect(conserves(game),"安装保留实体牌")
	await game.play(strike.uid,"enemy0")
	expect(b.energy==1 and b.block==5 and b.slots[0].fires==1,"第一次响应免 1 费")
	expect(not b.subsidy and conserves(game),"减免消费且实体牌守恒")
	await game.install(b.hand[0].uid,1,"T01")
	expect(b.energy==0,"0 费卡安装仍需 1 能量")
	await game.play(b.hand[0].uid,"enemy0")
	expect(b.slots[1] != null and b.slots[1].fires==0,"能量不足跳过响应")
	b.energy = 3
	game.event("T01","manual")
	await game.process_queue()
	expect(b.slots[1]==null and b.exhaust.any(func(c): return c.id=="C04"),"消耗卡响应一次后移入消耗堆")
	expect(conserves(game),"消耗响应实体牌守恒")
	await game.remove_rule(b.slots[0].bid)
	expect(b.slots[0]==null and b.discard.any(func(c): return c.id=="C02"),"拆除规则进入弃牌堆")

func test_loop():
	var game = fresh()
	setup_cards(game,[["C25",true],["C06"],["C02"],["C02"]],5)
	var b = game.s.battle
	b.enemies[0].hp = 999999
	b.enemies[0].maxHp = 999999
	await game.install(b.hand[0].uid,0,"T05")
	await game.install(b.hand[0].uid,1,"T05","enemy0")
	await game.install(b.hand[0].uid,2,"T06")
	b.manual = 3
	b.subsidy = false
	await game.play(b.hand[0].uid)
	expect(b.paused and b.responses==200,"合法跨规则无限链 200 次软暂停")
	expect(b.slots[0].fires==67 and b.slots[1].fires==67 and b.slots[2].fires==66,"FIFO 分配保持第三槽不饥饿")
	expect(b.block==335 and b.enemies[0].hp==999999-67*8,"循环数值正确")
	expect(conserves(game),"循环不复制/丢失实体牌")
	await game.resume_chain()
	expect(b.responses==400 and b.paused,"软暂停可继续，不是硬上限")
	await game.stop_chain()
	expect(not b.paused and b.queue.is_empty(),"可主动停止待执行连锁")
	var self_game = fresh()
	setup_cards(self_game,[["C02"],["C02"]],4)
	await self_game.install(self_game.s.battle.hand[0].uid,0,"T05")
	await self_game.play(self_game.s.battle.hand[0].uid)
	expect(self_game.s.battle.responses==1 and self_game.s.battle.queue.is_empty(),"直接自触发被排除")

func test_objects_and_turns():
	var game = fresh()
	setup_cards(game,[["C01"],["C02"],["C28"]],9)
	var b = game.s.battle
	b.objects[0].hp = 5
	b.objects[0].maxHp = 5
	await game.play(b.hand[1].uid,"object0")
	expect(b.objects[0].block==5 and b.block==0,"可给物件加护甲")
	await game.end_turn()
	expect(b.objects[0].block==5 and b.block==0 and b.energy==3,"物件护甲跨回合保留、玩家回合重置")
	game.hit("object0",5)
	expect(not b.objects[0].dead,"护甲完整吸收伤害不触发击碎")
	game.hit("object0",5)
	expect(b.objects[0].dead and b.block==5 and "O01" in game.s.run.stats.objects,"水晶护甲击碎收益")
	var last_hp = b.block
	game.hit("object0",5)
	expect(b.block==last_hp,"物件不会重复给收益")
	var enemy_game = fresh()
	var eb = enemy_game.s.battle
	eb.objects[0].hp = 1
	eb.enemies[0].intent = {"kind":"objectAttack","target":"object0","damage":6,"fallback":3}
	await enemy_game.end_turn()
	expect(eb.objects[0].dead and eb.enemies[0].block==5,"敌人可摧毁物件并获益")
	var fallback_game = fresh()
	var fb = fallback_game.s.battle
	fb.enemies[0].intent = {"kind":"objectAttack","target":"object0","damage":40,"fallback":3}
	# Legacy intent is metadata only. No held card means no attack can appear.
	fb.enemies[0].hand=[]
	fb.enemies[0].draw=[]
	fb.enemies[0].discard=[]
	fb.objects[0].dead = true
	fb.objects[0].hp = 0
	await fallback_game.end_turn()
	expect(fallback_game.s.run.hp==80,"无真实卡牌时不再凭空执行旧意图回退攻击")
	var bomb_game = fresh()
	var bb = bomb_game.s.battle
	bb.objects[0].def = "O08"
	bb.objects[0].hp = 1
	bb.enemies[0].hp = 1
	bomb_game.s.run.hp = 1
	bomb_game.hit("object0",1)
	bomb_game.check_end()
	expect(bomb_game.s.screen=="defeat","同时死亡按失败，环境连爆先结算")

func test_services_and_save():
	var game = fresh()
	var r = game.s.run
	r.practice = false
	r.node = {"id":"shoptest","type":"shop"}
	game.start_service()
	r.gold = 500
	game.chooser = choose_last
	var before = r.deck.size()
	await game.shop_action("buy",0)
	expect(r.deck.size()==before+1 and r.gold==465,"商店购牌费用")
	await game.shop_action("buy",0)
	expect(r.deck.size()==before+1 and r.gold==465,"已售商品不可重复购买")
	await game.shop_action("delete")
	expect(r.deck.size()==before and r.gold==425 and r.shopDeletes==1,"删牌经济与次数")
	var saved = game.snapshot()
	var restored = Game.new(JSON.parse_string(JSON.stringify(saved)))
	expect(restored.s.run.gold==425 and restored.s.run.deck.size()==before,"JSON 存档往返")
	game.save_game()
	var loaded = Game.new()
	loaded.save_path = game.save_path
	expect(loaded.load_game() and loaded.s.run.gold==425,"磁盘原生存档可恢复")
	r.node = {"id":"camp","type":"camp"}
	game.start_service()
	r.hp = 20
	await game.camp_action("rest")
	await game.camp_action("rest")
	expect(r.hp==44,"营地三选一只能领取一次")
	r.node = {"id":"event","type":"event"}
	game.start_service()
	r.node.objectDef = "O09"
	# The whole owned deck, rather than current hand, supplies scene capabilities.
	r.deck.append(game.card("C06"))
	var gold = r.gold
	await game.interact_object("melt")
	await game.interact_object("open")
	expect(r.gold==gold+14 and r.node.objectClaimed,"全卡组能力开启物件，场景库存共享一次")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))

func test_progression():
	var game = Game.new()
	game.save_path = "user://engine-test-save.json"
	game.new_run("balanced",false,9876)
	var combats = 0
	var services = {"shop":0,"camp":0,"event":0,"treasure":0}
	var claimed = 0
	for step in 24:
		expect(game.s.screen=="map","第 %d 节点从地图进入" % step)
		var next = game.s.run.next[0]
		await game.enter_node(next.id)
		if game.s.screen == "battle":
			combats += 1
			for enemy in game.s.battle.enemies: enemy.hp = 0
			game.check_end()
			if game.s.screen=="reward":
				game.claim_reward(game.s.reward.cards[0].uid)
				claimed += 1
		else:
			services[game.s.run.node.type] += 1
			game.finish_node()
	expect(game.s.screen=="victory" and combats==12,"24 节点 / 12 战斗 / 最终胜利")
	expect(game.s.run.gold==573,"无额外收益标准全程 573 金币")
	expect(game.s.run.deck.size()==21 and claimed==11,"11 次有效卡牌奖励，最终无空奖励")
	expect(services=={"shop":3,"camp":3,"event":3,"treasure":3},"每章商店、营地、事件、宝藏各一次")
	expect(game.s.run.slots==3 and "furnace" in game.s.meta.routes,"领主开启第三槽与支线路线")
	game.new_run("balanced",false,11)
	expect(game.s.run.hp==80 and game.s.run.gold==60 and game.s.run.deck.size()==10,"新局重置资源卡组，保留横向解锁")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))

func test_triggers_and_restore():
	var game = fresh()
	setup_cards(game,[["C02"],["C11"],["C03"],["C01"],["C02"]],20)
	var b = game.s.battle
	await game.install(b.hand[0].uid,0,"T07")
	var knife = b.hand[0]
	b.enemies[0].block = 99
	await game.play(knife.uid,"enemy0")
	expect(b.slots[0].fires==0,"攻击被完全吸收时不触发命中")
	b.enemies[0].block = 0
	game.hit("enemy0",1,{"kind":"environment"})
	await game.process_queue()
	expect(b.slots[0].fires==0,"环境伤害不触发牌攻击命中")
	game.hit("enemy0",1)
	await game.process_queue()
	expect(b.slots[0].fires==1,"真实牌攻击扣血触发命中")
	await game.remove_rule(b.slots[0].bid)
	await game.install(b.hand[2].uid,0,"T04")
	await game.end_turn()
	expect(b.slots[0].fires==0,"回合结束弃牌不触发主动弃牌")
	await game.remove_rule(b.slots[0].bid)
	b.hand.append_array(b.draw)
	b.draw=[]
	var guard = b.hand.filter(func(c): return c.id=="C02")[0]
	await game.install(guard.uid,0,"T03")
	b.draw = b.hand
	b.hand = []
	b.drawn = 4
	game.draw_cards(2)
	await game.process_queue()
	expect(b.slots[0].fires==1,"第 6 张实际抽牌开始触发")
	var loop = fresh()
	setup_cards(loop,[["C25",true],["C06"],["C02"],["C02"]],5)
	loop.s.battle.enemies[0].hp=999999
	loop.s.battle.enemies[0].maxHp=999999
	await loop.install(loop.s.battle.hand[0].uid,0,"T05")
	await loop.install(loop.s.battle.hand[0].uid,1,"T05","enemy0")
	await loop.install(loop.s.battle.hand[0].uid,2,"T06")
	loop.s.battle.manual=3
	loop.s.battle.subsidy=false
	await loop.play(loop.s.battle.hand[0].uid)
	var restored = Game.new(JSON.parse_string(JSON.stringify(loop.snapshot())))
	await restored.resume_chain()
	expect(restored.s.battle.responses==400 and conserves(restored),"暂停循环可从 JSON 存档恢复继续，实体牌守恒")
	var same_a = Game.new()
	var same_b = Game.new()
	same_a.save_path = "user://engine-seed-test-save.json"
	same_b.save_path = same_a.save_path
	same_a.new_run("balanced",false,12345)
	same_b.new_run("balanced",false,12345)
	expect(same_a.s.run.next==same_b.s.run.next,"固定种子路线可复现")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(same_a.save_path))

func run_tests():
	await test_all_cards()
	await test_rules()
	await test_loop()
	await test_objects_and_turns()
	await test_services_and_save()
	await test_progression()
	await test_triggers_and_restore()
	expect(presented.any(func(e): return e.type=="cast"),"原生施放 cue")
	expect(presented.any(func(e): return e.type=="hit"),"原生命中 cue")
	expect(presented.any(func(e): return e.type=="draw"),"原生抽牌 cue")
	expect(presented.any(func(e): return e.type=="rule"),"原生规则响应 cue")
	print("ENGINE TESTS: %d passed, %d failed" % [passes,failures])
	quit(1 if failures else 0)
