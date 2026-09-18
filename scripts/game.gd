extends RefCounted

signal changed
signal message(text)
signal unlocked(name)

const Database = preload("res://scripts/database.gd")
const EnemyCards = preload("res://scripts/enemy_cards.gd")
var db = Database.new()
var s: Dictionary
var presenter: Callable
var chooser: Callable
var last_error = ""
var action_busy = false
var stop_requested = false
var pending_visuals: Array = []
var save_path = "user://weaver-save.json"

func _init(snapshot_data = null):
	s = snapshot_data.duplicate(true) if snapshot_data is Dictionary else {"screen":"title", "run":null, "battle":null, "meta":{"unlocks":["balanced"],"objectTypes":[],"wins":0,"best":0,"routes":[]}, "settings":{"fast":false,"sound":true,"effects":true,"motion":true}}
	_migrate_enemy_decks()

func snapshot() -> Dictionary:
	return s.duplicate(true)

func restore(data: Dictionary):
	s = data.duplicate(true)
	_migrate_enemy_decks()
	action_busy = false
	pending_visuals.clear()
	changed.emit()

func save_game() -> bool:
	if action_busy or (s.run and s.run.get("practice", false)): return false
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if not file: return false
	file.store_string(JSON.stringify(s))
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(save_path): return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not parsed is Dictionary or not parsed.has("screen") or not parsed.has("meta"): return false
	restore(parsed)
	return true

func fail(text: String):
	last_error = text
	message.emit(text)
	return false

func commit():
	if not action_busy:
		check_unlocks()
		save_game()
	changed.emit()

func _run_action(method: String, args: Array = []):
	if action_busy: return fail("请等待当前操作完成")
	action_busy = true
	last_error = ""
	var result = await callv(method, args)
	await cue("resolve")
	action_busy = false
	commit()
	return result

func cue(type: String, data: Dictionary = {}):
	if type == "resolve":
		while not pending_visuals.is_empty():
			var visual_event = pending_visuals.pop_front()
			if presenter.is_valid(): await presenter.call(visual_event)
	var event_data = data.duplicate(true)
	event_data.type = type
	if presenter.is_valid(): await presenter.call(event_data)

func visual(type: String, data: Dictionary):
	var event_data = data.duplicate(true)
	event_data.type = type
	# Capture values now: later queued hits must not jump directly to the final HP.
	if s.get("battle"):
		if type=="energy": event_data.new_value = s.battle.energy
		if type in ["hit","shield","heal"]:
			var target_id = str(data.get("target",""))
			var unit = {"hp":s.run.hp,"block":s.battle.block} if target_id=="self" else db.by_id(s.battle.enemies,target_id)
			if unit.is_empty(): unit = db.by_id(s.battle.objects,target_id)
			if not unit.is_empty():
				event_data.hp_after = unit.hp
				event_data.block_after = unit.get("block",0)
				if type=="shield": event_data.new_value = unit.get("block",0)
				if type=="heal": event_data.new_value = unit.hp
	pending_visuals.append(event_data)

func log_line(text: String, kind: String = "info"):
	var b = s.battle
	if b:
		b.log.push_front({"text":text,"kind":kind,"n":b.sequence})
		b.sequence += 1
		if b.log.size() > 90: b.log.resize(90)

func random_value() -> float:
	s.run.rng = (int(s.run.rng) * 1664525 + 1013904223) & 0xffffffff
	return float(s.run.rng) / 4294967296.0

func pick(list: Array):
	return list[floori(random_value() * list.size())] if not list.is_empty() else null

func shuffle(list: Array) -> Array:
	for i in range(list.size() - 1, 0, -1):
		var j = floori(random_value() * (i + 1))
		var item = list[i]
		list[i] = list[j]
		list[j] = item
	return list

func uid(prefix: String = "c") -> String:
	s.run.uid += 1
	return prefix + str(int(s.run.uid))

func card(id: String, up: bool = false) -> Dictionary:
	return {"id":id,"up":up,"uid":uid()}

func info(c: Dictionary) -> Dictionary: return db.info(c)
func has(id: String) -> bool: return s.run != null and id in s.run.relics
func find_uid(list: Array, id: String) -> Dictionary:
	for item in list:
		if item.uid == id: return item
	return {}
func find_bind(bid: String) -> Dictionary:
	if not s.battle: return {}
	for binding in s.battle.slots:
		if binding and binding.bid == bid: return binding
	return {}

func choice(title: String, cards: Array, minimum: int = 1, maximum: int = 1) -> Array:
	if cards.is_empty() or maximum <= 0: return []
	maximum = mini(maximum, cards.size())
	minimum = mini(minimum, maximum)
	if chooser.is_valid():
		await cue("resolve")
		var chosen = await chooser.call({"title":title,"cards":cards.duplicate(true),"min":minimum,"max":maximum})
		if chosen is Array:
			var valid: Array = []
			for id in chosen:
				if not find_uid(cards, str(id)).is_empty() and id not in valid and valid.size() < maximum: valid.append(id)
			return valid
		return []
	var result: Array = []
	for c in cards.slice(0, maximum): result.append(c.uid)
	return result

func new_run(loadout: String = "balanced", practice: bool = false, seed_value: int = -1):
	if not db.loadouts.has(loadout): loadout = "balanced"
	if not practice and loadout not in s.meta.unlocks: return fail("这个起始方案尚未解锁")
	if seed_value < 0: seed_value = int(Time.get_unix_time_from_system() * 1000)
	s.run = {"uid":0,"rng":seed_value & 0xffffffff,"seed":seed_value & 0xffffffff,"hp":80,"maxHp":80,"gold":60,"chapter":0,"step":0,"slots":2,"deck":[],"relics":[],"spentRelics":[],"shopDeletes":0,"history":[],"pairFirst":{},"node":null,"next":null,"healingObjects":[0,0,0],"loadout":loadout,"route":"standard","routeNext":{},"practice":practice,"started":Time.get_unix_time_from_system(),"stats":{"damage":0,"manual":0,"rules":0,"discard":0,"search":0,"objects":[],"armorTurns":[]}}
	var r = s.run
	for id in db.loadouts[loadout].ids: r.deck.append(card(id))
	s.battle = null
	pending_visuals.clear()
	if practice:
		r.slots = 3
		r.deck = []
		for id in ["C01","C02","C06","C14","C03","C04","C24","C11","C19","C25"]: r.deck.append(card(id, id == "C25"))
		r.node = {"id":"practice","type":"battle","label":"规则练习","enemyIndexes":[0],"objectDefs":["O01"],"branch":0}
		start_battle()
		s.battle.enemies[0].hp = 65
		s.battle.enemies[0].maxHp = 65
		s.battle.hand.append_array(s.battle.draw)
		s.battle.draw = []
		log_line("练习中起手展示全部 10 张牌，便于尝试安装与连锁。", "gold")
	else:
		s.screen = "map"
		prepare_next()
	commit()
	return true

func choose_route(route: String):
	var r = s.run
	if not r or s.screen != "map" or r.chapter != 1 or r.step != 0 or (route != "standard" and route not in s.meta.routes): return
	r.routeNext[r.get("route", "standard")] = r.next
	r.route = route
	r.next = r.routeNext.get(route)
	prepare_next()
	commit()

func prepare_next():
	var r = s.run
	if r.next != null: return
	var depth = int(r.step) + 1
	var types: Array
	match depth:
		2: types = ["event","shop"]
		4: types = ["shop" if r.pairFirst.get("2") == "event" else "event"]
		6: types = ["treasure","camp"]
		7: types = ["camp" if r.pairFirst.get("6") == "treasure" else "treasure"]
		3: types = ["battle","elite"]
		8: types = ["boss"]
		_: types = ["battle","battle"]
	r.next = []
	for i in types.size():
		var type = types[i]
		var ch = db.chapters[int(r.chapter)]
		var indexes: Array = []
		if type == "battle":
			var normals = [3,3,4] if r.chapter == 1 and r.route == "furnace" else ([4,5,5] if r.chapter == 1 and r.route == "mirror" else ch.normal)
			indexes.append(pick(normals))
			if r.step > 0 and random_value() < 0.25: indexes.append(pick(ch.normal.filter(func(x): return x != indexes[0])))
		if type == "elite": indexes = [ch.elite]
		if type == "boss": indexes = [ch.boss]
		var names = PackedStringArray()
		for ix in indexes: names.append(db.enemies[int(ix)].name)
		r.next.append({"id":uid("n"),"type":type,"branch":i,"depth":depth,"enemyIndexes":indexes,"label":" · ".join(names),"environment":pick(["防护","伤害","调度"]),"claimed":false,"objectClaimed":false})

func enter_node(id: String): return await _run_action("_enter_node", [id])
func _enter_node(id: String):
	if s.screen != "map": return false
	var r = s.run
	var chosen = db.by_id(r.next, id)
	if chosen.is_empty(): return false
	await cue("travel")
	r.node = chosen.duplicate(true)
	if int(chosen.depth) in [2,6]: r.pairFirst[str(int(chosen.depth))] = chosen.type
	r.next = null
	if chosen.type in ["battle","elite","boss"]: start_battle()
	else: start_service()
	return true

func start_battle():
	var r = s.run
	var list = r.node.enemyIndexes
	var b = {"turn":1,"phase":"player","energy":3,"block":0,"strength":0,"burn":0,"vulnerable":0,"draw":[],"hand":[],"discard":[],"exhaust":[],"resolving":[],"slots":[],"queue":[],"paused":false,"log":[],"sequence":0,"drawn":0,"manual":0,"subsidy":true,"bonus":0,"borrowBonus":0,"discount":false,"echo":false,"gate":false,"relicTurn":{},"enemyCursor":0,"responses":0,"chainLast":0,"enemies":[],"objects":[]}
	b.slots.resize(int(r.slots))
	for i in list.size():
		var d = db.enemies[int(list[i])]
		var scale = 0.65 if list.size() > 1 else 1.0
		b.enemies.append({"id":"enemy"+str(i),"def":d.id,"name":d.name,"hp":ceili(d.hp*scale),"maxHp":ceili(d.hp*scale),"block":0,"strength":0,"burn":0,"vulnerable":0,"art":d.art,"step":i,"scale":scale,"intent":null,"harvest":null})
	var pool = db.objects.slice(0,8).filter(func(o): return not (r.node.type == "boss" and o.id in ["O02","O06"]) and not (o.id == "O06" and r.healingObjects[int(r.chapter)] >= 1) and not (o.id == "O02" and r.chapter == 0 and r.step < 2) and not (o.id == "O07" and r.chapter < 2 and r.node.type == "battle"))
	if r.chapter == 0 and r.step == 0: pool = pool.filter(func(x): return x.id in ["O01","O03","O04"])
	var count = 1 if r.chapter == 0 and r.step == 0 else (1 if random_value() < 0.5 else 2)
	var defs = r.node.get("objectDefs", []).duplicate()
	if defs.is_empty():
		for i in count:
			var favored = ["O04","O05","O08"] if r.chapter == 1 and r.route == "furnace" else (["O01","O03"] if r.chapter == 1 and r.route == "mirror" else [])
			var weighted = pool.duplicate()
			weighted.append_array(pool.filter(func(x): return x.id in favored))
			weighted.append_array(pool.filter(func(x): return x.id in favored))
			var o = pick(weighted)
			defs.append(o.id)
			pool = pool.filter(func(x): return x.id != o.id and not (o.id in ["O02","O03"] and x.id in ["O02","O03"]))
	for i in defs.size():
		var id = defs[i]
		var d = db.by_id(db.objects, id)
		if id == "O06": r.healingObjects[int(r.chapter)] += 1
		b.objects.append({"id":"object"+str(i),"def":id,"name":d.name,"hp":d.hp[int(r.chapter)],"maxHp":d.hp[int(r.chapter)],"block":0,"charges":d.charges,"dead":false,"art":d.art})
	b.draw = shuffle(r.deck.duplicate(true))
	s.battle = b
	s.screen = "battle"
	if has("R01"): b.energy += 1
	draw_cards(5 + (1 if has("R02") else 0))
	for enemy in b.enemies: init_enemy_deck(enemy)
	prepare_intents()
	log_line("第 1 回合 · 选择直接出牌，或将手牌安装为规则。", "gold")

func offers(rarities: Array) -> Array:
	var out: Array = []
	for rarity in rarities:
		var ids = out.map(func(c): return c.id)
		var pool = db.cards.values().filter(func(c): return c.rarity == rarity and c.id not in ids)
		out.append(card(pick(pool).id))
	return out

func relic_options(count: int) -> Array:
	var ids = db.relics.filter(func(x): return x.id not in s.run.relics).map(func(x): return x.id)
	return shuffle(ids).slice(0,count)

func start_service():
	var r = s.run
	var n = r.node
	s.battle = null
	s.screen = "service"
	n.objectDef = pick(db.objects.slice(8)).id
	n.objectOffers = offers(["common","common","uncommon"])
	n.eventType = pick(["exchange","altar","artisan","window"])
	n.eventOffers = offers(["common","common","uncommon"])
	n.objectClaimed = false
	n.serviceDone = false
	if n.type == "shop":
		n.goods = []
		for c in offers(["common","uncommon","rare"]): n.goods.append({"card":c,"price":{"common":35,"uncommon":60,"rare":90}[info(c).rarity],"sold":false})
		var available_relics = db.relics.filter(func(x): return x.id not in r.relics)
		n.relic = pick(available_relics).id if not available_relics.is_empty() else ""
		n.relicSold = n.relic.is_empty()
		n.deleteUsed = false
		n.upgradeUsed = false
	if n.type == "treasure":
		n.baseGold = [35,45,55][int(r.chapter)]
		r.gold += n.baseGold
		n.relicOptions = relic_options(2)

func finish_node():
	if action_busy: return fail("请等待当前操作完成")
	_finish_node()
	commit()

func _finish_node():
	var r = s.run
	var n = r.node
	if not n: return
	r.history.append({"type":n.type,"chapter":r.chapter,"depth":r.step+1,"hp":r.hp,"id":n.id})
	r.step += 1
	r.node = null
	s.battle = null
	if r.step >= 8:
		r.chapter += 1
		r.step = 0
		r.pairFirst = {}
	if r.chapter >= 3:
		finish_run(true)
		return
	s.screen = "map"
	r.next = null
	prepare_next()

func target_kind(c: Dictionary, mode: String = "block") -> String:
	if c.id == "C28": return "object" if mode == "repair" else "block"
	if c.id in ["C02","C14"]: return "block"
	if c.id == "C17": return "enemy"
	if info(c).type == "attack": return "none" if c.id == "C09" else "attack"
	return "none"

func next_alive_enemy() -> Dictionary:
	if not s.battle: return {}
	var alive = s.battle.enemies.filter(func(e): return e.hp > 0)
	alive.sort_custom(func(a,b): return a.hp < b.hp)
	return alive[0] if not alive.is_empty() else {}

func target(id: String) -> Dictionary:
	if id == "self": return {"id":"self","kind":"player"}
	if not s.battle: return {}
	for e in s.battle.enemies:
		if e.id == id and e.hp > 0: return e
	for o in s.battle.objects:
		if o.id == id and not o.dead and o.hp > 0: return o
	return {}

func valid_target(c: Dictionary, id: String, mode: String = "block") -> bool:
	var kind = target_kind(c,mode)
	if kind == "none": return true
	if target(id).is_empty(): return false
	if kind == "block": return id == "self" or id.begins_with("object")
	if kind == "object": return id.begins_with("object")
	if kind == "enemy": return id.begins_with("enemy")
	return id.begins_with("enemy") or id.begins_with("object")

func normal_cost(c: Dictionary) -> int:
	return maxi(0, int(info(c).cost) - (1 if s.battle and info(c).type == "attack" and s.battle.discount else 0))

func event(trigger: String, source: String = ""):
	var b = s.battle
	if not b or b.get("won",false) or s.screen != "battle": return
	for binding in b.slots:
		if binding and binding.enabled and binding.trigger == trigger and binding.bid != source:
			b.queue.append({"bid":binding.bid,"source":source,"target":binding.target,"mode":binding.mode})

func draw_cards(count: int, source: String = ""):
	var b = s.battle
	var drawn: Array = []
	for i in count:
		if b.hand.size() >= 12: break
		if b.draw.is_empty():
			if b.discard.is_empty(): break
			b.draw = shuffle(b.discard)
			b.discard = []
		var c = b.draw.pop_front()
		b.hand.append(c)
		drawn.append(c.duplicate(true))
		b.drawn += 1
		if b.drawn > 5: event("T03", source)
	if not drawn.is_empty(): visual("draw", {"cards":drawn})

func receive_card(c: Dictionary, source: String = "", is_draw: bool = false) -> bool:
	var b = s.battle
	if b.hand.size() >= 12: return false
	b.hand.append(c)
	visual("draw", {"cards":[c]})
	if is_draw:
		b.drawn += 1
		if b.drawn > 5: event("T03", source)
	return true

func gain_energy(amount: int, source: String = ""):
	if amount <= 0: return
	s.battle.energy += amount
	visual("energy", {"amount":amount})
	event("T06", source)

func gain_block(id: String, amount: int, source: String = ""):
	var b = s.battle
	if id == "self":
		b.block += amount
		visual("shield", {"target":id,"amount":amount})
		event("T05", source)
		return
	var t = target(id)
	if not t.is_empty() and id.begins_with("object"):
		if has("R04") and not b.relicTurn.get("R04", false):
			amount += 3
			b.relicTurn.R04 = true
		t.block += amount
		visual("shield", {"target":id,"amount":amount})

func discard_cards(ids: Array, source: String = "") -> int:
	var b = s.battle
	var count = 0
	for id in ids:
		var c = find_uid(b.hand, id)
		if c.is_empty(): continue
		b.hand.erase(c)
		b.discard.append(c)
		count += 1
		s.run.stats.discard += 1
		event("T04", source)
		if has("R03") and not b.relicTurn.get("R03",false):
			b.relicTurn.R03 = true
			gain_energy(1, source)
	return count

func damage_player(amount: int, ignore_block: bool = false):
	var b = s.battle
	var r = s.run
	var absorbed = 0
	if not ignore_block:
		absorbed = mini(b.block, amount)
		b.block -= absorbed
		amount -= absorbed
	var dealt = mini(r.hp,amount)
	r.hp = maxi(0,r.hp-amount)
	if r.hp == 0 and has("R10") and "R10" not in r.spentRelics:
		r.spentRelics.append("R10")
		r.hp = 1
		log_line("琥珀核碎裂，保留了最后 1 点生命。", "gold")
	visual("hit", {"target":"self","amount":dealt,"blocked":absorbed,"dead":r.hp <= 0,"kind":"burn" if ignore_block else "attack"})
	if amount > 0: log_line("你受到 %d 点伤害。" % amount,"hurt")

func hit(id: String, raw: int, options: Dictionary = {}) -> int:
	var b = s.battle
	var t = target(id)
	if t.is_empty(): return 0
	var owner = options.get("owner","player")
	var actor = options.get("actor",{})
	var source = options.get("source", "")
	var kind = options.get("kind", "attack")
	var amount = raw
	if kind == "attack":
		amount += int(b.strength if owner == "player" else actor.get("strength",0)) + int(options.get("bonus",0))
		var vulnerable = b.vulnerable if id == "self" else t.get("vulnerable",0)
		amount = floori(amount * (1.5 if vulnerable > 0 else 1.0))
	amount = maxi(0,amount)
	if id == "self":
		damage_player(amount)
		return amount
	var absorbed = mini(t.get("block",0),amount)
	t.block -= absorbed
	var dealt = mini(t.hp,amount-absorbed)
	t.hp = maxi(0,t.hp-amount+absorbed)
	visual("hit", {"target":id,"amount":dealt,"blocked":absorbed,"dead":t.hp <= 0,"kind":kind})
	if owner == "player" and kind == "attack" and dealt > 0:
		event("T07",source)
		s.run.stats.damage += dealt
	if str(t.get("def", "")).begins_with("O"):
		if dealt > 0 and t.def == "O05" and t.charges > 0:
			t.charges -= 1
			var layers = [2,3,4][int(s.run.chapter)]
			if owner == "player":
				var enemy = next_alive_enemy()
				if not enemy.is_empty(): enemy.burn += layers
			else: b.burn += layers
		if t.hp == 0 and not t.dead:
			t.dead = true
			break_object(t, {"owner":owner,"actor":actor,"source":source})
	return dealt

func break_object(o: Dictionary, options: Dictionary):
	var b = s.battle
	var r = s.run
	var ch = int(r.chapter)
	var charges = o.charges
	var owner = options.owner
	var actor = options.actor
	var source = options.source
	o.charges = 0
	visual("break", {"target":o.id})
	log_line(o.name + (" 被你击碎。" if owner == "player" else " 被敌人击碎。"), "object")
	if owner == "player":
		event("T08",source)
		if o.def not in r.stats.objects: r.stats.objects.append(o.def)
		if has("R05") and not b.relicTurn.get("R05",false):
			b.relicTurn.R05 = true
			b.bonus += 4
	if charges == 0 and o.def != "O05": return
	var enemy = next_alive_enemy()
	match o.def:
		"O01":
			if owner == "player": gain_block("self",[5,8,11][ch],source)
			elif actor.get("hp",0) > 0:
				actor.block += [5,8,11][ch]
				visual("shield",{"target":actor.id,"amount":[5,8,11][ch]})
		"O02":
			if owner == "player": gain_energy(2,source)
			elif actor.get("hp",0) > 0: actor.strength += 2
		"O03":
			if owner == "player": draw_cards(2,source)
			elif actor.get("hp",0) > 0:
				actor.strength += 1
				actor.block += [4,6,8][ch]
				visual("shield",{"target":actor.id,"amount":[4,6,8][ch]})
		"O04":
			if owner == "player":
				if not enemy.is_empty(): hit(enemy.id,[7,11,15][ch],{"owner":owner,"source":source,"kind":"environment"})
			else: damage_player([7,11,15][ch])
		"O06":
			if owner == "player":
				var healed = mini(r.maxHp-r.hp,[3,4,5][ch])
				r.hp += healed
				visual("heal",{"target":"self","amount":healed})
			elif actor.get("hp",0)>0:
				var healed = mini(actor.maxHp-actor.hp,[5,7,9][ch])
				actor.hp += healed
				visual("heal",{"target":actor.id,"amount":healed})
		"O07":
			if owner == "player":
				if not enemy.is_empty(): enemy.vulnerable += 2
			else: b.vulnerable += 2
		"O08":
			damage_player([8,12,16][ch])
			for e in b.enemies:
				if e.hp > 0: hit(e.id,[8,12,16][ch],{"owner":owner,"actor":actor,"source":source,"kind":"environment"})
			for x in b.objects:
				if not x.dead: hit(x.id,[4,6,8][ch],{"owner":owner,"actor":actor,"source":source,"kind":"environment"})

func check_end() -> bool:
	var b = s.battle
	if not b or b.get("won",false): return s.screen != "battle"
	if s.run.hp <= 0:
		finish_run(false)
		return true
	if b.enemies.all(func(e): return e.hp <= 0):
		win_battle()
		return true
	return false

func win_battle():
	var r = s.run
	var b = s.battle
	if b.get("won",false): return
	b.won = true
	b.queue = []
	b.paused = false
	if r.practice:
		s.screen = "practiceWin"
		return
	var ch = int(r.chapter)
	var type = r.node.type
	var gold = [50,60,70][ch] if type == "boss" else [18,22,26][ch] + ([12,16,20][ch] if type == "elite" else 0)
	r.gold += gold
	if type == "boss" and ch == 2:
		finish_run(true)
		return
	if type == "boss":
		r.hp = mini(r.maxHp,r.hp+20)
		if ch == 0: r.slots = 3
		if ch == 1 and "furnace" not in s.meta.routes: s.meta.routes.append("furnace")
	var rarities = ["uncommon","rare","rare"] if type == "boss" else ((["uncommon","rare","rare"] if ch == 2 else ["common","uncommon","rare"]) if type == "elite" else [["common","common","uncommon"],["common","uncommon","uncommon"],["common","uncommon","rare"]][ch])
	s.reward = {"gold":gold,"cards":offers(rarities),"boss":type == "boss","claimed":false}
	s.screen = "reward"

func claim_reward(id: String = ""):
	if action_busy or s.screen != "reward" or s.reward.claimed: return false
	var c = find_uid(s.reward.cards,id)
	if not id.is_empty() and c.is_empty(): return false
	s.reward.claimed = true
	if not c.is_empty(): s.run.deck.append(c)
	_finish_node()
	commit()
	return true

func finish_run(won: bool):
	s.screen = "victory" if won else "defeat"
	if won and not s.run.practice and not s.run.get("finished",false): s.meta.wins += 1
	s.run.finished = true
	s.run.ended = Time.get_unix_time_from_system()
	if s.battle:
		s.battle.queue = []
		s.battle.paused = false

func check_unlocks():
	var r = s.run
	var m = s.meta
	if not r or r.practice: return
	m.best = maxi(m.get("best",0),int(r.chapter)*8+int(r.step))
	if r.stats.armorTurns.size() >= 3: add_unlock("defense")
	if r.stats.discard >= 8: add_unlock("discard")
	if r.stats.search >= 4: add_unlock("search")
	for x in r.stats.objects:
		if x not in m.objectTypes: m.objectTypes.append(x)
	if m.objectTypes.size() >= 5 and "mirror" not in m.routes: m.routes.append("mirror")

func add_unlock(id: String):
	if id not in s.meta.unlocks:
		s.meta.unlocks.append(id)
		unlocked.emit(db.loadouts[id].name)

func effect(c: Dictionary, target_id: String, source: String = "", mode: String = "block", bonus: int = 0):
	var b = s.battle
	var r = s.run
	var up = c.get("up",false)
	var t = target(target_id)
	var opts = {"source":source,"bonus":bonus}
	match c.id:
		"C01": hit(target_id,9 if up else 6,opts)
		"C02": gain_block(target_id,8 if up else 5,source)
		"C03":
			draw_cards(2 if up else 1,source)
			discard_cards(await choice("选择 1 张牌弃置",b.hand,1,1),source)
		"C04": draw_cards(3 if up else 2,source)
		"C05": hit(target_id,18 if up else 14,opts)
		"C06":
			hit(target_id,10 if up else 8,opts)
			t = target(target_id)
			if not t.is_empty() and target_id.begins_with("enemy"): t.burn += 3 if up else 2
		"C07":
			hit(target_id,5 if up else 4,opts)
			if not target(target_id).is_empty(): hit(target_id,5 if up else 4,opts)
		"C08":
			if not t.is_empty(): t.block = 0
			hit(target_id,14 if up else 10,opts)
		"C09":
			for enemy in b.enemies:
				if enemy.hp > 0: hit(enemy.id,10 if up else 7,opts)
		"C10":
			var is_object = str(t.get("def", "")).begins_with("O")
			hit(target_id,(8 if up else 6)+(6 if is_object else 0),opts)
			if is_object and t.get("dead",false):
				for enemy in b.enemies:
					if enemy.hp > 0: hit(enemy.id,7 if up else 5,{"source":source,"kind":"environment"})
		"C11": hit(target_id,6 if up else 4,opts)
		"C12":
			hit(target_id,5 if up else 3,opts)
			b.bonus += 5 if up else 4
		"C13": hit(target_id,32 if up else 24,opts)
		"C14": gain_block(target_id,11 if up else 8,source)
		"C15":
			gain_block("self",16 if up else 12,source)
			b.strength += 1
		"C16":
			gain_block("self",8 if up else 5,source)
			draw_cards(1,source)
		"C17":
			gain_block("self",10 if up else 8,source)
			hit(target_id,8 if up else 6,opts)
		"C18":
			gain_block("self",9 if up else 6,source)
			b.discount = true
		"C19": draw_cards(3 if up else 2,source)
		"C20":
			var look = b.draw.slice(0,5 if up else 4)
			var ids = await choice("筛选：选择最多 2 张加入手牌",look,0,mini(2,12-b.hand.size()))
			for looked in look:
				if looked not in b.draw: continue
				b.draw.erase(looked)
				if looked.uid in ids and b.hand.size() < 12: receive_card(looked,source,true)
				else: b.discard.append(looked)
			if not ids.is_empty(): r.stats.search += 1
		"C21":
			var pool = b.draw.filter(func(x): return info(x).type != "skill")
			var ids = await choice("索引：选择攻击或防御牌",pool,1 if b.hand.size()<12 else 0,1 if b.hand.size()<12 else 0)
			if not ids.is_empty() and b.hand.size()<12:
				var selected = find_uid(b.draw,ids[0])
				b.draw.erase(selected)
				receive_card(selected,source,true)
			draw_cards(1,source)
			if not ids.is_empty(): r.stats.search += 1
		"C22":
			var ids = await choice("回收：从弃牌堆取回手牌",b.discard,mini(1,mini(b.discard.size(),12-b.hand.size())),mini(2 if up else 1,12-b.hand.size()))
			for id in ids:
				var selected = find_uid(b.discard,id)
				if not selected.is_empty() and b.hand.size()<12:
					b.discard.erase(selected)
					receive_card(selected)
		"C23":
			var ids = await choice("巡回：选择要弃置的手牌",b.hand,0,3 if up else 2)
			var count = discard_cards(ids,source)
			draw_cards(count+1,source)
		"C24": gain_energy(3 if up else 2,source)
		"C25": gain_energy((3 if up else 2) if b.manual>=3 else 1,source)
		"C26":
			gain_energy(1,source)
			draw_cards(1,source)
			b.borrowBonus = maxi(b.borrowBonus,5 if up else 3)
		"C27":
			b.block -= 3 if up else 4
			gain_energy(1,source)
		"C28":
			if mode == "repair":
				if not t.is_empty():
					var healed = mini(t.maxHp-t.hp,8 if up else 6)
					t.hp += healed
					visual("heal",{"target":target_id,"amount":healed})
			else: gain_block(target_id,8 if up else 6,source)
			draw_cards(1,source)
		"C29": b.echo = true
		"C30": b.gate = true

func prerequisites(c: Dictionary) -> bool:
	return c.id != "C27" or s.battle.block >= (3 if c.get("up",false) else 4)

func play(id: String, target_id: String = "self", mode: String = "block", from_slot: bool = false):
	return await _run_action("_play",[id,target_id,mode,from_slot])

func _play(id: String, target_id: String, mode: String, from_slot: bool):
	var b = s.battle
	if s.screen != "battle" or not b or b.phase != "player" or b.paused: return fail("现在不能手动出牌")
	var binding = find_bind(id) if from_slot else {}
	var c = binding.get("card",{}) if from_slot else find_uid(b.hand,id)
	if c.is_empty(): return fail("这张牌不在可用位置")
	if not valid_target(c,target_id,mode): return fail("请选择合法目标")
	if not prerequisites(c): return fail("护甲不足，无法变现")
	var cost = normal_cost(c)
	if b.energy < cost: return fail("能量不足")
	await cue("cast",{"card":c,"target":target_id,"from_slot":from_slot,"slot":b.slots.find(binding) if not binding.is_empty() else -1,"mode":mode})
	b.energy -= cost
	if not binding.is_empty():
		b.slots[b.slots.find(binding)] = null
		b.queue = b.queue.filter(func(q): return q.bid != binding.bid)
	else: b.hand.erase(c)
	b.resolving.append(c)
	var definition = info(c)
	var bonus = b.bonus+b.borrowBonus if definition.type == "attack" else 0
	var echo = b.echo and definition.type != "skill"
	var gate = b.gate
	if definition.type == "attack":
		b.bonus = 0
		b.borrowBonus = 0
		b.discount = false
	if echo: b.echo = false
	log_line("打出 %s · %d 能量" % [definition.name,cost],"play")
	await effect(c,target_id,"manual",mode,bonus)
	await cue("resolve")
	# Keep the card in resolving until both executions have completed.
	if echo and s.run.hp > 0 and b.enemies.any(func(e): return e.hp > 0):
		await cue("rule",{"card":c,"target":target_id,"slot":-1})
		await effect(c,target_id,"manual",mode,bonus)
		await cue("resolve")
	b.resolving.erase(c)
	if definition.exhaust: b.exhaust.append(c)
	else: b.discard.append(c)
	b.manual += 1
	s.run.stats.manual += 1
	if check_end(): return true
	event("T01" if definition.type == "attack" else "T02","manual")
	if gate: draw_cards(1,"manual")
	if has("R07") and b.manual == 3: gain_energy(1,"relic")
	await process_queue()
	return true

func install(id: String, slot: int, trigger: String, target_id: String = "self", mode: String = "block"):
	return await _run_action("_install",[id,slot,trigger,target_id,mode])

func _install(id: String, slot: int, trigger: String, target_id: String, mode: String):
	var b = s.battle
	if s.screen != "battle" or not b or b.phase != "player" or b.paused: return fail("现在不能安装")
	if slot < 0 or slot >= b.slots.size() or b.slots[slot] != null: return fail("这个规则槽不可用")
	var c = find_uid(b.hand,id)
	var condition = db.by_id(db.triggers,trigger)
	if c.is_empty() or condition.is_empty(): return fail("请选择手牌与触发条件")
	if not valid_target(c,target_id,mode): return fail("安装目标无效")
	var cost = maxi(1,int(info(c).cost))
	if b.energy < cost: return fail("安装需要 %d 能量" % cost)
	await cue("install",{"card":c,"slot":slot})
	b.energy -= cost
	b.hand.erase(c)
	b.slots[slot] = {"bid":uid("bind"),"card":c,"trigger":trigger,"target":target_id,"mode":mode,"enabled":true,"reserve":0,"fires":0,"last":"等待触发"}
	log_line("安装 " + info(c).name + " → " + condition.name,"rule")
	if has("R06") and not b.relicTurn.get("R06",false):
		b.relicTurn.R06 = true
		draw_cards(1)
	await cue("resolve")
	await process_queue()
	return true

func remove_rule(bid: String):
	if action_busy: return fail("请等待当前操作完成")
	var b = s.battle
	if not b: return false
	var binding = find_bind(bid)
	if binding.is_empty(): return false
	if b.paused:
		b.queue = []
		b.paused = false
	b.discard.append(binding.card)
	b.slots[b.slots.find(binding)] = null
	b.queue = b.queue.filter(func(q): return q.bid != bid)
	log_line("放弃安装：" + info(binding.card).name + " 进入弃牌堆")
	if b.phase == "enemy" and s.screen == "battle": await _run_action("enemy_phase")
	else: commit()
	return true

func toggle_rule(bid: String):
	if action_busy: return fail("请等待当前操作完成")
	var binding = find_bind(bid)
	if binding.is_empty(): return false
	binding.enabled = not binding.enabled
	if not binding.enabled: s.battle.queue = s.battle.queue.filter(func(q): return q.bid != bid)
	commit()
	return true

func configure_rule(bid: String, values: Dictionary):
	if action_busy: return fail("请等待当前操作完成")
	var binding = find_bind(bid)
	if binding.is_empty(): return false
	if values.has("target") and valid_target(binding.card,values.target,binding.mode): binding.target = values.target
	if values.has("reserve"): binding.reserve = clampi(int(values.reserve),0,9)
	commit()
	return true

func bind_target(binding: Dictionary) -> String:
	if valid_target(binding.card,binding.target,binding.mode): return binding.target
	var kind = target_kind(binding.card,binding.mode)
	if kind in ["none","block"]: return "self"
	if kind == "object": return ""
	return next_alive_enemy().get("id","")

func process_queue(limit: int = 200):
	var b = s.battle
	if not b or s.screen != "battle": return
	var count = 0
	b.paused = false
	stop_requested = false
	while not b.queue.is_empty() and s.screen == "battle":
		if count >= limit or stop_requested:
			b.paused = true
			log_line("连锁已暂停，仍有 %d 个响应等待。" % b.queue.size(),"gold")
			break
		var queued = b.queue.pop_front()
		var binding = find_bind(queued.bid)
		if binding.is_empty() or not binding.enabled: continue
		var request_binding = binding.duplicate()
		request_binding.target = queued.get("target",binding.target)
		request_binding.mode = queued.get("mode",binding.mode)
		var target_id = bind_target(request_binding)
		if target_id.is_empty() or not prerequisites(binding.card):
			binding.last = "跳过：目标或前置条件不足"
			continue
		var c = binding.card
		var cost = maxi(0,maxi(1,int(info(c).cost))-(1 if b.subsidy else 0))
		if b.energy-cost < binding.reserve:
			binding.last = "跳过：能量不足或需要保留"
			continue
		b.energy -= cost
		b.subsidy = false
		binding.fires += 1
		binding.last = "已响应 · 消耗 %d" % cost
		count += 1
		b.responses += 1
		s.run.stats.rules += 1
		if binding.trigger == "T05":
			var key = "%d-%d-%d" % [s.run.chapter,s.run.step,b.turn]
			if key not in s.run.stats.armorTurns: s.run.stats.armorTurns.append(key)
		log_line(db.by_id(db.triggers,binding.trigger).name+" → "+info(c).name+" · %d 能量" % cost,"rule")
		var bonus = b.bonus+b.borrowBonus if info(c).type == "attack" else 0
		if info(c).type == "attack":
			b.bonus = 0
			b.borrowBonus = 0
		await cue("rule",{"card":c,"target":target_id,"slot":b.slots.find(binding),"chain":count})
		await effect(c,target_id,binding.bid,request_binding.mode,bonus)
		await cue("resolve")
		if info(c).exhaust:
			var index = b.slots.find(binding)
			if index >= 0: b.slots[index] = null
			b.exhaust.append(c)
			b.queue = b.queue.filter(func(x): return x.bid != binding.bid)
		if check_end(): break
		if count % 8 == 0: changed.emit()
	b.chainLast = count

func resume_chain(): return await _run_action("_resume_chain")
func _resume_chain():
	var b = s.battle
	if not b or not b.paused: return false
	await process_queue()
	if s.screen == "battle" and not b.paused and b.phase == "enemy": await enemy_phase()
	return true

func stop_chain():
	if not s.battle: return
	if action_busy:
		stop_requested = true
		return
	await _run_action("_stop_chain")

func _stop_chain():
	var b = s.battle
	b.queue = []
	b.paused = false
	stop_requested = true
	log_line("已停止待执行的连锁。")
	if b.phase == "enemy" and s.screen == "battle": await enemy_phase()

func _migrate_enemy_decks():
	# Old saves are accepted; each legacy creature receives a deterministic real deck.
	if not s.get("battle") or not s.get("run"): return
	for enemy in s.battle.get("enemies",[]):
		if not enemy.has("deck_version"):
			init_enemy_deck(enemy, false)
		elif not enemy.get("resolving",[]).is_empty():
			# Defensive recovery for snapshots taken while a card animation was active.
			for c in enemy.resolving:
				if enemy.get("pending_applied",false): enemy.discard.append(c)
				else: enemy.hand.push_front(c)
			if not enemy.get("pending_applied",false):
				enemy.energy += int(enemy.get("pending_paid",0))
				enemy.actions_played = maxi(0,int(enemy.get("actions_played",0))-1)
			enemy.resolving = []
			enemy.pending_paid = 0
			enemy.pending_applied = false
			enemy.pending_target = ""
	s.battle.enemy_cards_version = 1

func enemy_card_info(c: Dictionary, enemy: Dictionary = {}) -> Dictionary:
	var d = c.get("definition",{}).duplicate(true)
	if d.is_empty(): return {"id":c.get("id","unknown"),"name":"未知行动","text":"","cost":0,"type":"skill","tags":[],"art":3,"rarity":"common","kind":"none"}
	# Boss rage strengthens the cards they actually hold, rather than generating free attacks.
	if str(enemy.get("def","")).begins_with("B") and enemy.get("hp",1)<=float(enemy.get("maxHp",1))*0.5:
		if d.damage>0: d.damage += 1
		if d.block>0: d.block += 2
		d.text = EnemyCards.describe(d)
		d.name += " · 觉醒"
	return d

func enemy_shuffle(enemy: Dictionary, list: Array) -> Array:
	for index in range(list.size()-1,0,-1):
		enemy.deck_rng = (int(enemy.deck_rng)*1664525+1013904223)&0xffffffff
		var other = int(enemy.deck_rng) % (index+1)
		var c = list[index]
		list[index] = list[other]
		list[other] = c
	return list

func init_enemy_deck(enemy: Dictionary, animate: bool = true):
	var seed_value = int(s.run.get("seed",1)) + int(s.run.get("chapter",0))*7919 + int(s.run.get("step",0))*104729
	for character in (str(enemy.def)+str(enemy.id)).to_utf8_buffer(): seed_value = (seed_value*31+int(character))&0xffffffff
	enemy.deck_rng = seed_value
	enemy.deck_version = 1
	enemy.deck = []
	enemy.draw = []
	enemy.hand = []
	enemy.discard = []
	enemy.resolving = []
	enemy.energy = 3
	enemy.max_energy = 3
	enemy.actions_played = 0
	enemy.turn_active = false
	enemy.planned = []
	enemy.pending_paid = 0
	enemy.pending_applied = false
	enemy.pending_target = ""
	var definitions = EnemyCards.build(db.by_id(db.enemies,enemy.def),float(enemy.get("scale",1.0)))
	for index in definitions.size():
		var d = definitions[index]
		enemy.deck.append({"id":d.id,"uid":"%s_card_%d" % [enemy.id,index],"up":false,"definition":d})
	enemy.draw = enemy_shuffle(enemy,enemy.deck.duplicate(true))
	enemy_draw_cards(enemy,3,animate)

func enemy_draw_cards(enemy: Dictionary, count: int, animate: bool = true) -> Array:
	var drawn: Array = []
	for i in count:
		if enemy.hand.size()>=7: break
		if enemy.draw.is_empty():
			if enemy.discard.is_empty(): break
			enemy.draw = enemy_shuffle(enemy,enemy.discard)
			enemy.discard = []
		var c = enemy.draw.pop_front()
		enemy.hand.append(c)
		drawn.append(c.duplicate(true))
	if animate and not drawn.is_empty():
		visual("enemy_draw",{"enemy_id":enemy.id,"enemy":enemy,"cards":drawn,"hand":enemy.hand,"draw_count":enemy.draw.size(),"discard_count":enemy.discard.size()})
	return drawn

func enemy_legal_target(enemy: Dictionary, c: Dictionary, target_id: String) -> bool:
	var d = enemy_card_info(c,enemy)
	if enemy.hp<=0 or d.cost>enemy.energy: return false
	if d.kind=="counter" and enemy.block<=0: return false
	if d.kind=="combo" and enemy.actions_played<=0: return false
	if d.kind=="heal" and enemy.hp>=enemy.maxHp: return false
	if d.kind in ["object_attack","object_guard"]:
		var object = target(target_id)
		return target_id.begins_with("object") and not object.is_empty() and object.get("charges",0)>0
	if d.type=="attack": return target_id=="self" and s.run.hp>0
	return target_id==enemy.id

func enemy_candidates(enemy: Dictionary) -> Array:
	var choices: Array = []
	for c in enemy.hand:
		var d = enemy_card_info(c,enemy)
		if d.kind in ["object_attack","object_guard"]:
			for object in s.battle.objects:
				if enemy_legal_target(enemy,c,object.id): choices.append({"card":c,"target":object.id})
		else:
			var target_id = "self" if d.type=="attack" else enemy.id
			if enemy_legal_target(enemy,c,target_id): choices.append({"card":c,"target":target_id})
	return choices

func enemy_action_score(enemy: Dictionary, choice: Dictionary) -> float:
	var d = enemy_card_info(choice.card,enemy)
	var low_hp = float(enemy.hp)/maxf(1,float(enemy.maxHp))
	var remaining = int(enemy.energy)-int(d.cost)
	var score = 1.0
	if d.type=="attack" and d.kind!="object_attack":
		var damage = int(d.damage+enemy.strength)*int(d.hits)
		var actual = maxi(0,damage-int(s.battle.block))
		score = 5.0+damage*0.55+actual*0.45+int(d.burn)*2.0
		if actual>=s.run.hp: score += 100
		# Leave room for affordable follow-ups; a two-cost attack remains only one real card.
		if d.cost==1: score += 1.0
		if d.kind=="combo": score += 3.0
	elif d.kind=="guard":
		score = (8.0 if enemy.block==0 else 1.0)+d.block*0.35+(1.0-low_hp)*7.0
		if enemy.hand.any(func(card): return enemy_card_info(card,enemy).kind=="counter") and enemy.block==0 and remaining>=2: score += 12
		if low_hp>0.8 and enemy.block>=d.block: score -= 7
	elif d.kind=="heal": score = 7.0+mini(d.heal,enemy.maxHp-enemy.hp)*0.9+(1.0-low_hp)*10.0
	elif d.kind=="strength": score = 11.0 if enemy.actions_played==0 and remaining>=1 else 2.0
	elif d.kind=="draw": score = 12.0 if enemy.hand.size()<=2 and remaining>=1 and not (enemy.draw.is_empty() and enemy.discard.is_empty()) else -2.0
	elif d.kind=="object_attack":
		var object = target(choice.target)
		var damage = int(d.damage+enemy.strength)
		var breaks = damage>=object.hp+object.block
		score = 11.0 if breaks else -2.0
		match object.def:
			"O02": score += 6 if breaks else 0
			"O03": score += 5 if breaks else 0
			"O04": score += 8 if breaks else 0
			"O05": score += 11 if damage>object.block else -4
			"O06": score += 7 if low_hp<0.65 and breaks else -10
			"O07": score += 4 if breaks and remaining>=1 else -3
			"O08":
				var explosion = [8,12,16][int(s.run.chapter)]
				if enemy.hp+enemy.block<=explosion and s.run.hp+s.battle.block>explosion: return -1000
				score += 12 if s.run.hp+s.battle.block<=explosion else -2
		if str(enemy.def) in ["E01","N05","B02"]: score += 3
	elif d.kind=="object_guard":
		var object = target(choice.target)
		var can_harvest = enemy.hand.any(func(card):
			var attack = enemy_card_info(card,enemy)
			return attack.kind=="object_attack" and attack.cost<=remaining and attack.damage+enemy.strength>=object.hp+object.block+d.block)
		score = 3.0 if object.block<d.block else -5.0
		if object.def=="O05" and object.charges>0: score += 8
		if can_harvest: score += 9
	return score

func enemy_choose_action(enemy: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_score = -999.0
	for candidate in enemy_candidates(enemy):
		var score = enemy_action_score(enemy,candidate)
		if score>best_score:
			best_score = score
			best = candidate
	# Passing is legitimate when only harmful object plays / pointless draw remain.
	return best if best_score>=0 else {}

func prepare_intents():
	if not s.battle: return
	for enemy in s.battle.enemies:
		if enemy.hp<=0: continue
		if not enemy.has("deck_version"): init_enemy_deck(enemy)
		var selected = enemy_choose_action(enemy)
		enemy.planned = [selected.card.uid] if not selected.is_empty() else []
		enemy.intent = {"kind":"cards","hand_count":enemy.hand.size(),"energy":enemy.energy,"max_cards":3}

func intent_text(enemy: Dictionary) -> String:
	if not enemy.has("deck_version"): return "正在整理牌组"
	if enemy.get("turn_active",false): return "出牌 %d / 3 · 能量 %d" % [enemy.actions_played,enemy.energy]
	return "手牌 %d · 下回合 %d 能量" % [enemy.hand.size(),enemy.max_energy]

func end_turn(): return await _run_action("_end_turn")
func _end_turn():
	var b = s.battle
	if s.screen != "battle" or not b or b.phase != "player" or b.paused: return false
	b.discard.append_array(b.hand)
	b.hand = []
	if b.burn>0:
		damage_player(b.burn,true)
		b.burn -= 1
	if b.vulnerable>0: b.vulnerable -= 1
	await cue("resolve")
	if check_end(): return true
	b.phase = "enemy"
	b.enemyCursor = 0
	for enemy in b.enemies: enemy.block = 0
	changed.emit()
	await cue("turn",{"phase":"enemy"})
	await enemy_phase()
	return true

func resolve_enemy_card(enemy: Dictionary, c: Dictionary, target_id: String):
	var d = enemy_card_info(c,enemy)
	if d.kind in ["object_attack","object_guard"] and target(target_id).is_empty():
		log_line(enemy.name+" 的 "+d.name+" 目标已失效。")
		return
	if d.block>0:
		var recipient = target(target_id) if d.kind=="object_guard" else enemy
		if not recipient.is_empty():
			recipient.block += d.block
			visual("shield",{"target":recipient.id,"amount":d.block})
	if d.strength>0: enemy.strength += d.strength
	if d.heal>0:
		var healed = mini(d.heal,enemy.maxHp-enemy.hp)
		enemy.hp += healed
		visual("heal",{"target":enemy.id,"amount":healed})
	if d.damage>0:
		for hit_index in int(d.hits):
			if enemy.hp<=0 or s.run.hp<=0: break
			if target_id!="self" and target(target_id).is_empty(): break
			hit(target_id,d.damage,{"owner":"enemy","actor":enemy,"kind":"attack"})
	if d.burn>0 and s.run.hp>0: s.battle.burn += d.burn
	if d.draw>0 and enemy.hp>0: enemy_draw_cards(enemy,int(d.draw))

func enemy_phase():
	var b = s.battle
	while b.enemyCursor<b.enemies.size() and s.screen=="battle":
		var enemy = b.enemies[int(b.enemyCursor)]
		if enemy.hp<=0:
			b.enemyCursor += 1
			continue
		if not enemy.has("deck_version"): init_enemy_deck(enemy)
		if not enemy.turn_active:
			enemy.turn_active = true
			enemy.energy = enemy.max_energy
			enemy.actions_played = 0
			enemy_draw_cards(enemy,maxi(2,5-enemy.hand.size()))
			await cue("resolve")
		while enemy.actions_played<3 and enemy.energy>0 and enemy.hp>0 and s.run.hp>0 and s.screen=="battle":
			var action = enemy_choose_action(enemy)
			if action.is_empty(): break
			var c = action.card
			var d = enemy_card_info(c,enemy)
			var index = enemy.hand.find(c)
			if index<0 or not enemy_legal_target(enemy,c,action.target): break
			enemy.hand.remove_at(index)
			enemy.resolving.append(c)
			enemy.energy -= int(d.cost)
			enemy.actions_played += 1
			enemy.pending_paid = int(d.cost)
			enemy.pending_applied = false
			enemy.pending_target = action.target
			enemy.planned = [c.uid]
			await cue("enemy_cast",{"enemy":enemy,"enemy_id":enemy.id,"card":c,"definition":d,"target":action.target,"hand_index":index,"hand_after":enemy.hand,"draw_count":enemy.draw.size(),"discard_count":enemy.discard.size()})
			resolve_enemy_card(enemy,c,action.target)
			enemy.pending_applied = true
			log_line("%s 打出 %s · %d 能量" % [enemy.name,d.name,d.cost],"enemy")
			await cue("resolve")
			enemy.resolving.erase(c)
			enemy.discard.append(c)
			enemy.pending_paid = 0
			enemy.pending_applied = false
			enemy.pending_target = ""
			await cue("enemy_discard",{"enemy_id":enemy.id,"enemy":enemy,"cards":[c],"reason":"played","hand":enemy.hand,"draw_count":enemy.draw.size(),"discard_count":enemy.discard.size()})
			if check_end(): return
			await process_queue()
			if b.paused: return
			enemy.planned = []
		if enemy.hp>0 and enemy.burn>0:
			var dealt = mini(enemy.hp,enemy.burn)
			enemy.hp = maxi(0,enemy.hp-enemy.burn)
			enemy.burn -= 1
			visual("hit",{"target":enemy.id,"amount":dealt,"blocked":0,"dead":enemy.hp<=0,"kind":"burn"})
		if enemy.vulnerable>0: enemy.vulnerable -= 1
		enemy.turn_active = false
		enemy.step += 1
		enemy.planned = []
		b.enemyCursor += 1
		await cue("resolve")
		if check_end(): return
		await process_queue()
		if b.paused: return
	if s.screen!="battle": return
	b.turn += 1
	b.phase = "player"
	b.block = 0
	b.energy = 3
	b.drawn = 0
	b.manual = 0
	b.subsidy = true
	b.bonus = 0
	b.borrowBonus = 0
	b.discount = false
	b.echo = false
	b.gate = false
	b.relicTurn = {}
	draw_cards(5)
	prepare_intents()
	log_line("第 %d 回合 · 抽牌与能量已刷新。" % b.turn,"gold")
	await cue("turn",{"phase":"player"})
	await process_queue()

func capabilities() -> Dictionary:
	var out: Dictionary = {}
	if not s.run: return out
	for c in s.run.deck:
		for tag in info(c).tags:
			if not out.has(tag): out[tag] = []
			out[tag].append(info(c).name)
	var scheduling: Array = []
	for name in out.get("draw",[]) + out.get("search",[]):
		if name not in scheduling: scheduling.append(name)
	if not scheduling.is_empty(): out.scheduling = scheduling
	return out

func _scene_option(id: String, label: String, cost: int, reward: String, need: String = "") -> Dictionary:
	var cap = capabilities()
	return {"id":id,"label":label,"cost":cost,"reward":reward,"need":need,"available":need.is_empty() or cap.has(need),"source":"、".join(PackedStringArray(cap.get(need,[])))}

func object_options() -> Array:
	var r = s.run
	if not r or not r.node or not r.node.has("objectDef"): return []
	var n = r.node
	var cap = capabilities()
	var options: Array = []
	match n.objectDef:
		"O09": options = [_scene_option("open","请商人开启",12,"获得 18 金币"),_scene_option("melt","用火焰熔开封蜡",4,"获得 18 金币","fire")]
		"O10": options = [_scene_option("repair","整理修具，修补旅装",7 if cap.has("repair") else 12,"恢复 8 生命"),_scene_option("remove","借工具整理卡组",20 if cap.has("repair") else 25,"删除 1 张牌")]
		"O11": options = [_scene_option("drink","饮用清水",0,"恢复 5 生命"),_scene_option("protect","保护容器，完整取水",8,"恢复 10 生命","block"),_scene_option("sell","将井水换成补给",0,"获得 6 金币")]
		"O12": options = [_scene_option("gold","取走旧钱币",0,"获得 12 金币"),_scene_option("card","翻阅封存典籍",0,"三选一获得一张牌","scheduling"),_scene_option("scout","查看遗迹图纸",0,"获得本章路线情报")]
	for option in options:
		if has("R08") and not n.get("probeUsed",false) and option.cost>0: option.cost = maxi(0,option.cost-5)
	return options

func interact_object(id: String): return await _run_action("_interact_object",[id])
func _interact_object(id: String):
	var r = s.run
	var n = r.node
	if s.screen != "service" or n.objectClaimed: return false
	var option = db.by_id(object_options(),id)
	if option.is_empty() or not option.available: return fail("缺少对应卡组能力")
	if r.gold < option.cost: return fail("金币不足")
	var selected: Array = []
	if id == "remove":
		selected = await choice("选择删除一张牌",r.deck,1,1)
		if selected.is_empty(): return false
	if id == "card":
		selected = await choice("从书柜中选择一张牌",n.objectOffers,1,1)
		if selected.is_empty(): return false
	if n.objectClaimed: return false
	n.objectClaimed = true
	r.gold -= option.cost
	if option.cost>0: n.probeUsed = true
	match id:
		"open", "melt": r.gold += 18
		"repair": r.hp = mini(r.maxHp,r.hp+8)
		"remove": r.deck = r.deck.filter(func(c): return c.uid != selected[0])
		"drink": r.hp = mini(r.maxHp,r.hp+5)
		"protect": r.hp = mini(r.maxHp,r.hp+10)
		"sell": r.gold += 6
		"gold": r.gold += 12
		"card": r.deck.append(find_uid(n.objectOffers,selected[0]))
		"scout":
			n.scouted = true
			r.intel = "路线情报：第 3 站可挑战精英，第 8 站为领主。第 2、4 站为商店与事件，第 6、7 站为宝藏与营地。"
	if n.objectDef not in r.stats.objects: r.stats.objects.append(n.objectDef)
	return true

func shop_action(type: String, index: int = 0): return await _run_action("_shop_action",[type,index])
func _shop_action(type: String, index: int):
	var r = s.run
	var n = r.node
	if s.screen != "service" or n.type != "shop": return false
	if type == "buy":
		if index < 0 or index >= n.goods.size(): return fail("找不到商品")
		var goods = n.goods[index]
		if goods.sold or r.gold < goods.price: return fail("无法购买这张牌")
		r.gold -= goods.price
		r.deck.append(goods.card)
		goods.sold = true
	elif type == "relic":
		if n.relicSold or r.gold < 95: return fail("金币不足或商品已售出")
		r.gold -= 95
		r.relics.append(n.relic)
		n.relicSold = true
	elif type in ["delete","upgrade"]:
		var price = 40+int(r.shopDeletes)*10 if type == "delete" else 50
		if r.gold < price or n["deleteUsed" if type == "delete" else "upgradeUsed"]: return fail("这项服务不可用")
		var pool = r.deck.filter(func(c): return not c.up) if type == "upgrade" else r.deck
		if pool.is_empty(): return fail("没有可选择的牌")
		var ids = await choice("选择删除的牌" if type == "delete" else "选择升级的牌",pool,1,1)
		if ids.is_empty(): return false
		r.gold -= price
		if type == "delete":
			r.deck = r.deck.filter(func(c): return c.uid != ids[0])
			r.shopDeletes += 1
			n.deleteUsed = true
		else:
			find_uid(r.deck,ids[0]).up = true
			n.upgradeUsed = true
	else: return false
	return true

func camp_action(type: String): return await _run_action("_camp_action",[type])
func _camp_action(type: String):
	var r = s.run
	var n = r.node
	if s.screen != "service" or n.type != "camp" or n.serviceDone: return false
	if type == "rest": r.hp = mini(r.maxHp,r.hp+24)
	elif type in ["upgrade","delete"]:
		var pool = r.deck.filter(func(c): return not c.up) if type == "upgrade" else r.deck
		if pool.is_empty(): return fail("没有可选择的牌")
		var ids = await choice("选择升级的牌" if type == "upgrade" else "选择删除的牌",pool,1,1)
		if ids.is_empty(): return false
		if type == "upgrade": find_uid(r.deck,ids[0]).up = true
		else: r.deck = r.deck.filter(func(c): return c.uid != ids[0])
		if has("R09"): r.hp = mini(r.maxHp,r.hp+6)
	else: return false
	n.serviceDone = true
	return true

func claim_relic(id: String):
	if action_busy: return false
	var r = s.run
	var n = r.node
	if s.screen != "service" or n.type != "treasure" or n.serviceDone or id not in n.relicOptions: return false
	r.relics.append(id)
	n.serviceDone = true
	commit()
	return true

func event_action(type: String): return await _run_action("_event_action",[type])
func _event_action(type: String):
	var r = s.run
	var n = r.node
	if s.screen != "service" or n.type != "event" or n.serviceDone: return false
	if type == "leave":
		n.serviceDone = true
		return true
	match n.eventType:
		"exchange":
			var take = await choice("选择想获得的牌",n.eventOffers,1,1)
			if take.is_empty(): return false
			var give = await choice("选择交出的牌",r.deck,1,1)
			if give.is_empty(): return false
			r.deck = r.deck.filter(func(c): return c.uid != give[0])
			r.deck.append(find_uid(n.eventOffers,take[0]))
		"altar":
			if r.hp <= 6: return fail("生命不足")
			var ids = await choice("祭台：选择升级的牌",r.deck.filter(func(c): return not c.up),1,1)
			if ids.is_empty(): return false
			r.hp -= 6
			find_uid(r.deck,ids[0]).up = true
		"artisan":
			if r.gold < 20: return fail("需要 20 金币")
			var ids = await choice("工匠：选择删除的牌",r.deck,1,1)
			if ids.is_empty(): return false
			r.gold -= 20
			r.deck = r.deck.filter(func(c): return c.uid != ids[0])
		"window":
			if type == "gold": r.gold += 10
			else:
				n.scouted = true
				r.intel = "路线情报：第 3 站可挑战精英，第 8 站为领主。先访问商人可在战斗前调整构筑，宝藏与营地的先后顺序由你决定。"
	n.serviceDone = true
	return true
