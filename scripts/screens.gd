extends RefCounted
const FantasySkin = preload("res://scripts/material_skin.gd")
const RouteMap = preload("res://scripts/route_map.gd")

const INK := Color("0b1321")
const PANEL := Color("131e30")
const GOLD := Color("cbb685")
const PALE := Color("f0e8d7")
const CYAN := Color("83dce6")
const MUTED := Color("99aabb")
const BORDER := Color("465067")
const RED := Color("d77678")

var selected_loadout: String = "balanced"
var _loadout_buttons: Array[Button] = []
var _host: Control
var _game: Variant
var _action: Callable
var _font: Font
var _serif: Font
var _card_script: Script
var _spells: Texture2D
var _portraits: Texture2D

func build(kind: String, host: Control, game: RefCounted, on_action: Callable, font: Font, serif: Font, card_script: Script, spell_texture: Texture2D, portraits: Texture2D) -> void:
	_host = host
	_loadout_buttons.clear()
	_game = game
	_action = on_action
	_font = font
	_serif = serif
	_card_script = card_script
	_spells = spell_texture
	_portraits = portraits
	match kind:
		"title": _title()
		"map": _map()
		"service": _service()
		"reward": _reward()
		_: _result(kind)

func _style(bg: Color = PANEL, border: Color = BORDER, width: int = 1, radius: int = 7) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(mini(radius,4))
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 5)
	return style

func _panel(parent: Control, rect: Rect2, _accent: Color = BORDER) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", FantasySkin.panel(minf(rect.size.x,rect.size.y)<150))
	parent.add_child(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	return panel

func _label(parent: Control, text: String, rect: Rect2, font_size: int = 22, color: Color = PALE, centered: bool = false, ornamental: bool = false) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.text = text
	label.add_theme_font_override("font", _serif if ornamental else _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _line(parent: Control, x: float, y: float, width: float, color: Color = GOLD) -> void:
	var line := ColorRect.new()
	line.position = Vector2(x, y)
	line.size = Vector2(width, 1)
	line.color = Color(color, 0.4)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)

func _button(parent: Control, text: String, rect: Rect2, action: String, args: Array = [], primary: bool = false, disabled: bool = false) -> Button:
	var button := Button.new()
	button.position = rect.position
	button.size = rect.size
	button.text = text
	button.disabled = disabled
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", PALE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("637387"))
	FantasySkin.apply_button(button,primary)
	parent.add_child(button)
	var original_position := button.position
	button.mouse_entered.connect(func():
		if not button.disabled:
			if button.has_meta("hover_tween"):
				var old: Tween = button.get_meta("hover_tween")
				if old and old.is_valid(): old.kill()
			var tween := button.create_tween()
			tween.tween_property(button, "position", original_position + Vector2(0, -3), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			button.set_meta("hover_tween", tween)
	)
	button.mouse_exited.connect(func():
		if button.has_meta("hover_tween"):
			var old: Tween = button.get_meta("hover_tween")
			if old and old.is_valid(): old.kill()
		var tween := button.create_tween()
		tween.tween_property(button, "position", original_position, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		button.set_meta("hover_tween", tween)
	)
	button.pressed.connect(func():
		if action == "loadout" and not args.is_empty(): _set_loadout(str(args[0]))
		_action.call(action, [selected_loadout] if action == "new" else args)
	)
	return button

func _set_loadout(id: String) -> void:
	selected_loadout = id
	for button: Button in _loadout_buttons:
		if not is_instance_valid(button): continue
		var selected: bool = str(button.get_meta("loadout_id", "")) == id
		FantasySkin.apply_button(button,selected)
		var name_label: Label = button.get_meta("name_label")
		name_label.text = str(button.get_meta("loadout_name"))
		name_label.add_theme_color_override("font_color", GOLD if selected else PALE)

func _reveal(control: Control, delay: float = 0.0, travel: float = 18.0) -> void:
	if not _game.s.settings.get("motion",true):return
	var destination := control.position
	control.position.y += travel
	control.modulate.a = 0.0
	var tween := control.create_tween().set_parallel(true)
	tween.tween_property(control, "modulate:a", 1.0, 0.38).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "position", destination, 0.48).set_delay(delay).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

func _atlas(parent: Control, texture: Texture2D, rect: Rect2, index: int, columns: int, rows: int) -> TextureRect:
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	var cell := Vector2(float(texture.get_width()) / columns, float(texture.get_height()) / rows)
	atlas.region = Rect2(Vector2(index % columns, floori(float(index) / columns)) * cell, cell)
	image.texture = atlas
	image.position = rect.position
	image.size = rect.size
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func _lookup(table: Variant, id: String) -> Dictionary:
	if table is Dictionary:
		return table.get(id, {})
	for item: Dictionary in table:
		if item.get("id", "") == id:
			return item
	return {}

func _card(parent: Control, card: Dictionary, position: Vector2, card_scale: float = 1.0, action: String = "") -> Control:
	var view: Variant = _card_script.new()
	view.interactive = not action.is_empty()
	parent.add_child(view)
	view.setup(card, _game.db.info(card), _spells, _font)
	view.scale = Vector2.ONE * card_scale
	# CardView uses a lower-edge pivot for the battle hand. Compensate so the
	# position argument always denotes the visible upper-left corner here.
	view.position = position + view.pivot_offset * (card_scale - 1.0)
	view.mouse_filter = Control.MOUSE_FILTER_STOP if view.interactive else Control.MOUSE_FILTER_IGNORE
	if not action.is_empty():
		view.pressed.connect(func(uid): _action.call(action, [uid]))
		var rest_position: Vector2 = view.position
		view.mouse_entered.connect(func():
			if view.has_meta("screen_hover"):
				var old: Tween = view.get_meta("screen_hover")
				if old and old.is_valid(): old.kill()
			var tween: Tween = view.create_tween().set_parallel(true)
			tween.tween_property(view, "position", rest_position - Vector2(0, 12), 0.19).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(view, "scale", Vector2.ONE * card_scale * 1.045, 0.19).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			view.set_meta("screen_hover", tween)
		)
		view.mouse_exited.connect(func():
			if view.has_meta("screen_hover"):
				var old: Tween = view.get_meta("screen_hover")
				if old and old.is_valid(): old.kill()
			var tween: Tween = view.create_tween().set_parallel(true)
			tween.tween_property(view, "position", rest_position, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(view, "scale", Vector2.ONE * card_scale, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			view.set_meta("screen_hover", tween)
		)
	return view

func _title() -> void:
	var meta: Dictionary = _game.s.get("meta", {})
	var run: Variant = _game.s.get("run")
	var unlocks: Array = meta.get("unlocks", ["balanced"])
	if not selected_loadout in unlocks: selected_loadout = "balanced"
	var copy := Control.new()
	copy.position = Vector2(106, 137)
	copy.size = Vector2(690, 800)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host.add_child(copy)
	_label(copy, "A R C A N E   D E C K B U I L D E R", Rect2(4, 0, 690, 35), 15, GOLD)
	_label(copy, "织 律 者", Rect2(-5, 35, 700, 151), 108, PALE, false, true)
	_label(copy, "THE WEAVER", Rect2(6, 184, 650, 30), 19, GOLD)
	_line(copy, 7, 241, 76, GOLD)
	_label(copy, "规 则 之 外", Rect2(104, 217, 435, 48), 28, GOLD, false, true)
	_label(copy, "将手中的卡牌，写成世界的规则。", Rect2(6, 281, 665, 49), 24, PALE)
	_label(copy, "起 始 誓 约", Rect2(6, 414, 430, 28), 15, GOLD)
	var index: int = 0
	var lock_text: Dictionary = {"defense":"护甲共鸣：在 3 个不同回合触发", "discard":"主动弃牌：一局累计 8 次", "search":"筛选或索引：一局使用 4 次"}
	for id: String in _game.db.loadouts:
		var item: Dictionary = _game.db.loadouts[id]
		var unlocked: bool = id in unlocks
		var button := _button(copy, "", Rect2(6 + (index % 2) * 333, 453 + floori(index / 2.0) * 95, 316, 81), "loadout", [id], false, not unlocked)
		FantasySkin.apply_button(button,id==selected_loadout)
		var name_label := _label(button, item.name, Rect2(30, 21, 256, 35), 21, GOLD if id == selected_loadout else PALE, true)
		if not unlocked:FantasySkin.icon(button,"lock-keyhole",Rect2(271,30,19,19),0.65)
		button.set_meta("loadout_id", id)
		button.set_meta("loadout_name", str(item.name))
		button.set_meta("name_label", name_label)
		_loadout_buttons.append(button)
		button.tooltip_text="攻守兼备，自由构筑" if id=="balanced" else item.text if unlocked else lock_text.get(id, "继续探索以解锁")
		index += 1
	var can_continue: bool = run is Dictionary and not run.is_empty() and not run.get("finished", false) and not run.get("practice", false)
	_button(copy, "开 启 冒 险     →", Rect2(6, 669, 316, 65), "new", [selected_loadout], true)
	_button(copy, "规 则 练 习", Rect2(339, 669, 316, 65), "practice")
	if can_continue:
		_button(copy, "继续上次旅程  →", Rect2(6, 748, 316, 43), "continue").add_theme_font_size_override("font_size",17)
	_reveal(copy, 0.05)
	_label(_host, "v0.5.0", Rect2(108, 942, 645, 30), 12, MUTED)

func _map() -> void:
	var run: Dictionary = _game.s.run
	var chapter: int = int(run.chapter)
	var chapter_data: Dictionary = _game.db.chapters[chapter]
	var board := _panel(_host, Rect2(52, 130, 346, 785))
	_label(board, "CHAPTER  %02d / 03" % (chapter + 1), Rect2(27, 20, 292, 30), 15, GOLD)
	_label(board, chapter_data.name, Rect2(27, 62, 292, 60), 34, PALE, false, true)
	_label(board, chapter_data.subtitle, Rect2(29, 131, 288, 59), 17, MUTED)
	_line(board, 28, 209, 288)
	_label(board, "%02d / 08" % (int(run.step)+1), Rect2(29, 225, 289, 32), 17, GOLD)
	var detail := Control.new()
	detail.position=Vector2(0,273);detail.size=Vector2(346,398);board.add_child(detail)
	var chart := RouteMap.new()
	chart.position=Vector2(423,111)
	_host.add_child(chart)
	chart.setup(run,_font,_game.s.settings.get("motion",true))
	chart.node_selected.connect(func(node):
		_map_detail(detail,node)
	)
	var next: Array=run.get("next",[])
	if not next.is_empty():_map_detail(detail,next[0])
	board.tooltip_text="金色节点可前往；实线为已走过的路线；淡色为后续预览。"
	_reveal(board)
	_reveal(chart,0.08,12)
	_hero_sidebar(run)
	var routes: Array=_game.s.meta.get("routes",[])
	if chapter==1 and int(run.step)==0 and not routes.is_empty():
		var all_routes: Array=["standard"]+routes
		for i in range(all_routes.size()):
			var id: String=all_routes[i]
			_button(_host,{"standard":"镜庭旧路","furnace":"锻炉支路","mirror":"镜湖支路"}.get(id,id),Rect2(439+i*238,951,222,36),"route",[id],run.get("route","standard")==id).add_theme_font_size_override("font_size",16)

func _map_detail(parent: Control, node: Dictionary) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
	var typ: String=node.type
	var names={"shop":"灯下的旅行商人","event":"仍有回声的遗迹","camp":"旅人的篝火","treasure":"被遗忘的赠礼"}
	var description={"battle":"赢得金币与三选一卡牌。每次遭遇都会出现可争夺的场景物件。","elite":"危险的精英守卫。战胜它，获得更丰厚的金币与稀有牌。","boss":"此章的终末守卫。打破它的律令，前往下一章。","shop":"购买法术和遗物，升级或删除卡牌。","event":"与旧日回响相遇，选择你的际遇。","camp":"恢复生命，免费升级或删除一张牌。","treasure":"拾取金币，再挑选一件遗物。"}
	if typ in ["battle","elite","boss"]:
		var indexes: Array=node.get("enemyIndexes",[])
		var art: int=int(_game.db.enemies[int(indexes[0])].art) if not indexes.is_empty() else 1
		var preview=_atlas(parent,_portraits,Rect2(29,0,287,152),art,3,2)
		var region: Rect2=preview.texture.region
		region.size.y*=0.64
		preview.texture.region=region
	else:_atlas(parent,_spells,Rect2(29,0,287,152),{"shop":4,"event":3,"camp":2,"treasure":6}.get(typ,4),4,2)
	var label: String=str(node.get("label",""))
	if label.is_empty():label=names.get(typ,"前行")
	_label(parent,label,Rect2(29,167,288,54),25,PALE,false,true)
	_label(parent,description.get(typ,""),Rect2(29,228,288,72),17,MUTED)
	_button(parent,"踏 入 此 地   →",Rect2(28,325,290,60),"enter",[node.id],true)

func _hero_sidebar(run: Dictionary) -> void:
	var side := _panel(_host, Rect2(1200, 130, 346, 785), GOLD)
	_atlas(side, _portraits, Rect2(24, 24, 298, 245), 0, 3, 2)
	_label(side, "织律者", Rect2(22, 280, 302, 43), 32, PALE, true, true)
	var hp: float = float(run.get("hp", 0))
	var max_hp: float = float(run.get("maxHp", 80))
	_label(side, str(int(hp)), Rect2(25, 329, 295, 36), 23, PALE, true)
	var bar := ProgressBar.new()
	bar.position = Vector2(26, 375)
	bar.size = Vector2(294, 10)
	bar.max_value = max_hp
	bar.value = hp
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_bg=_style(Color("342625"),Color("9b7a44"),1,4)
	var bar_fill=_style(Color("b45768"),Color("d4848b"),1,4)
	for s in [bar_bg,bar_fill]:
		s.set_content_margin_all(0)
	bar.add_theme_stylebox_override("background",bar_bg)
	bar.add_theme_stylebox_override("fill",bar_fill)
	bar.size=Vector2(294,10)
	side.add_child(bar)
	var deck=_button(side, str(run.get("deck", []).size()), Rect2(93, 414, 160, 54), "deck")
	FantasySkin.icon(deck,"layers",Rect2(21,15,24,24));deck.tooltip_text="查看卡组"
	_label(side, "随行遗物", Rect2(24, 491, 299, 31), 19, GOLD)
	var relics: Array = run.get("relics", [])
	if not relics.is_empty():
		for i: int in range(mini(relics.size(), 4)):
			var relic: Dictionary = _lookup(_game.db.relics, str(relics[i]))
			_label(side, "◇  " + str(relic.get("name", relics[i])), Rect2(25, 535 + i * 48, 294, 40), 19, PALE).tooltip_text = str(relic.get("text", ""))
		if relics.size() > 4:
			_label(side, "另有 %d 件遗物" % (relics.size() - 4), Rect2(25, 735, 290, 26), 16, MUTED)
	_reveal(side, 0.12)

func _service() -> void:
	var run: Dictionary = _game.s.run
	var node: Dictionary = run.node
	var typ: String = node.type
	var main := _panel(_host, Rect2(52, 132, 1083, 780))
	_label(main, "第 %d 章   /   第 %d 站" % [int(run.chapter) + 1, int(run.step) + 1], Rect2(31, 21, 1010, 32), 17, GOLD)
	_label(main, str(_game.db.node_labels.get(typ, "旅途")), Rect2(31, 63, 1010, 68), 48, PALE, false, true)
	var introduction: Dictionary = {"shop":"珍藏的法术与遗物，静候新的主人。", "camp":"火焰尚暖。将下一场胜利，藏进这片刻安宁。", "treasure":"尘封的礼物，仍记得被打开的那一天。", "event":"战斗之外，世界也会回应你的选择。"}
	_label(main, introduction.get(typ, ""), Rect2(34, 140, 1009, 40), 21, MUTED)
	match typ:
		"shop": _shop(main, run, node)
		"camp": _camp(main, node)
		"treasure": _treasure(main, node)
		"event": _event(main, run, node)
	_button(main, "继续旅程    →", Rect2(753, 688, 287, 58), "leave_node", [], true)
	_reveal(main)
	_scene_object(run, node)

func _shop(main: Control, run: Dictionary, node: Dictionary) -> void:
	var goods: Array = node.get("goods", [])
	for i: int in range(goods.size()):
		var good: Dictionary = goods[i]
		var x: float = 92 + i * 333
		var view := _card(main, good.card, Vector2(x, 212), 0.94)
		var sold: bool = good.get("sold", false)
		if sold: view.modulate = Color(0.52, 0.58, 0.66, 0.66)
		_button(main, "已购入" if sold else "%d 金币 · 购买" % int(good.price), Rect2(x - 20, 470, 205, 46), "buy", [i], false, sold or int(run.gold) < int(good.price))
		_reveal(view, 0.12 + i * 0.08)
	var relic: Dictionary = _lookup(_game.db.relics, str(node.get("relic", "")))
	var delete_price: int = 40 + int(run.get("shopDeletes", 0)) * 10
	var services: Array = [
		[relic.get("name", "行旅遗物"), relic.get("text", "旅途中的额外助力"), "已购入" if node.get("relicSold", false) else "95 金币 · 遗物", "shop_relic", node.get("relicSold", false) or int(run.gold) < 95],
		["整理卡组", "删除一张牌，让关键牌更早入手。", "已使用" if node.get("deleteUsed", false) else "%d 金币 · 删牌" % delete_price, "shop_delete", node.get("deleteUsed", false) or int(run.gold) < delete_price],
		["铭刻升级", "升级一张牌，强化效果持续至本局结束。", "已使用" if node.get("upgradeUsed", false) else "50 金币 · 升级", "shop_upgrade", node.get("upgradeUsed", false) or int(run.gold) < 50]
	]
	for i: int in range(services.size()):
		var service: Array = services[i]
		var box := _panel(main, Rect2(34 + i * 342, 541, 326, 127))
		_label(box, service[0], Rect2(16, 6, 294, 31), 22, GOLD)
		_label(box, service[1], Rect2(17, 39, 292, 32), 15, MUTED)
		_button(box, service[2], Rect2(15, 79, 296, 37), service[3], [], false, bool(service[4])).add_theme_font_size_override("font_size", 18)

func _tile(parent: Control, rect: Rect2, title: String, detail: String, symbol: String, action: String, args: Array, disabled: bool = false) -> Button:
	var tile := _button(parent, "", rect, action, args, false, disabled)
	_label(tile, symbol, Rect2(24, 20, rect.size.x - 48, 77), 53, GOLD if not disabled else MUTED, true, true)
	_label(tile, title, Rect2(22, 112, rect.size.x - 44, 55), 29, PALE, true, true)
	_line(tile, 29, 181, rect.size.x - 58)
	_label(tile, detail, Rect2(25, 199, rect.size.x - 50, 89), 20, MUTED, true)
	_label(tile, "已完成" if disabled else "作出选择", Rect2(25, rect.size.y - 53, rect.size.x - 50, 34), 19, CYAN if not disabled else MUTED, true)
	return tile

func _camp(main: Control, node: Dictionary) -> void:
	var done: bool = node.get("serviceDone", false)
	var options: Array = [["rest", "围火休憩", "恢复 24 点生命", "♡"], ["upgrade", "研习铭文", "免费升级一张牌", "✦"], ["delete", "放下旧物", "免费删除一张牌", "◇"]]
	for i: int in range(options.size()):
		var option: Array = options[i]
		var tile := _tile(main, Rect2(35 + i * 343, 230, 324, 352), option[1], option[2], option[3], "camp", [option[0]], done)
		_reveal(tile, 0.12 + i * 0.1)
	_label(main, "营地行动已完成" if done else "本次停留，可以选择一项营地行动。", Rect2(36, 601, 1001, 39), 20, GOLD if done else MUTED, true)

func _treasure(main: Control, node: Dictionary) -> void:
	var done: bool = node.get("serviceDone", false)
	_label(main, "已获得 %d 金币" % int(node.get("baseGold", 0)), Rect2(35, 205, 1007, 45), 26, GOLD, true)
	var options: Array = node.get("relicOptions", [])
	for i: int in range(options.size()):
		var id: String = str(options[i])
		var relic: Dictionary = _lookup(_game.db.relics, id)
		var tile := _tile(main, Rect2(87 + i * 486, 280, 438, 327), relic.get("name", "遗物"), relic.get("text", ""), "✧", "relic", [id], done)
		_reveal(tile, 0.11 + i * 0.12)
	_label(main, "遗物已经收入行囊。" if done else "再从两件遗物中，挑选一件伴你前行。", Rect2(36, 625, 1008, 34), 20, MUTED, true)

func _event(main: Control, run: Dictionary, node: Dictionary) -> void:
	var events: Dictionary = {
		"exchange":["旧书的交易", "守书人的指尖掠过泛黄书页。\n「交出一段旧知，我便给你另一种可能。」", "交出一张牌，换取三张候选牌中的一张。", "交换卡牌", 3],
		"altar":["未熄的祭台", "灰烬之下，铭文依旧明亮。\n一滴鲜血足以唤醒沉睡的力量。", "支付 6 点生命，升级一张牌。", "献祭生命 · 升级", 7],
		"artisan":["游历的工匠", "工匠收起最后一件工具。\n「有时，让旅途轻一些，比添一把剑更重要。」", "支付 20 金币，删除一张牌。", "20 金币 · 删牌", 6],
		"window":["瞭望之窗", "高窗映出蜿蜒的旧路。\n窗台上，旅人留下了钱币和一页地图。", "拿走 10 金币，或阅读路线情报。", "获得 10 金币", 4]
	}
	var typ: String = node.get("eventType", "exchange")
	var entry: Array = events.get(typ, events.exchange)
	var done: bool = node.get("serviceDone", false)
	var art_frame := _panel(main, Rect2(36, 222, 316, 314), GOLD)
	_atlas(art_frame, _spells, Rect2(7, 7, 302, 300), int(entry[4]), 4, 2)
	_label(main, entry[0], Rect2(389, 220, 647, 64), 34, GOLD, false, true)
	_label(main, entry[1], Rect2(391, 305, 630, 126), 24, PALE)
	_label(main, entry[2], Rect2(391, 453, 622, 64), 20, MUTED)
	var unaffordable: bool = (typ == "artisan" and int(run.gold) < 20) or (typ == "altar" and int(run.hp) <= 6)
	_button(main, entry[3], Rect2(37, 571, 383, 61), "event", ["gold" if typ == "window" else "accept"], true, done or unaffordable)
	if typ == "window":
		_button(main, "阅读路线情报", Rect2(441, 571, 310, 61), "event", ["scout"], false, done)
		_button(main, "离开", Rect2(772, 571, 266, 61), "event", ["leave"], false, done)
	else:
		_button(main, "不作交换", Rect2(445, 571, 297, 61), "event", ["leave"], false, done)
	if done:
		_label(main, "这段际遇，已成为旅途的一部分。", Rect2(40, 639, 996, 37), 19, GOLD)

func _scene_object(run: Dictionary, node: Dictionary) -> void:
	var definition: Dictionary = _lookup(_game.db.objects, str(node.get("objectDef", "")))
	if definition.is_empty(): return
	var side := _panel(_host, Rect2(1160, 132, 387, 780), GOLD)
	_atlas(side, _spells, Rect2(24, 24, 339, 185), int(definition.get("art", 3)), 4, 2)
	_label(side, str(definition.name), Rect2(21, 265, 345, 46), 31, GOLD, false, true)
	_label(side, str(definition.get("text", "")), Rect2(24, 323, 338, 70), 19, MUTED)
	_line(side, 23, 406, 341)
	if node.get("objectClaimed", false):
		_label(side, "物件资源已取走", Rect2(22, 441, 343, 54), 26, CYAN, true)
		_label(side, "你与这片遗迹的交集，\n已写入旅途。", Rect2(23, 514, 341, 82), 20, MUTED, true)
	else:
		var options: Array = _game.object_options()
		var y: float = 427.0
		var height: float = 88.0 if options.size() <= 3 else 69.0
		for item: Dictionary in options:
			var available: bool = bool(item.get("available", true))
			var price: int = int(item.get("cost", 0))
			var button := _button(side, "", Rect2(20, y, 347, height), "scene_object", [item.id], false, not available or int(run.gold) < price)
			_label(button, str(item.get("label", "互动")), Rect2(25, 8, 297, 29), 19, PALE)
			_label(button, str(item.get("reward", "")) + (" · %d 金币" % price if price else " · 免费"), Rect2(25, 35, 297, 27), 15, GOLD if available else MUTED)
			if height > 70.0 and not str(item.get("need", "")).is_empty():
				var needs: Dictionary = {"fire":"火焰", "block":"防护", "draw":"抽牌", "scheduling":"抽牌或检索"}
				_label(button, "卡组提供：" + str(item.get("source", "")) if available else "需要卡组能力：" + str(needs.get(item.need, item.need)), Rect2(25, 60, 297, 20), 12, CYAN if available else MUTED)
			y += height + 9
	side.tooltip_text="物件互动取决于卡组能力，不消耗卡牌；各选项共享一份资源。"
	if node.get("scouted", false):
		side.tooltip_text = "路线情报：第 3 站可选精英，第 8 站为领主；第 2、4 站各有商店或事件，第 6、7 站各有宝藏或营地。"
	_reveal(side, 0.15)

func _reward() -> void:
	var reward: Dictionary = _game.s.get("reward", {})
	var run: Dictionary = _game.s.run
	_label(_host, "VICTORY", Rect2(130, 143, 1340, 42), 23, GOLD, true)
	_label(_host, "将新的可能，收入牌组", Rect2(135, 195, 1330, 79), 51, PALE, true, true)
	var extra: String = ""
	if reward.get("boss", false):
		extra = "  ·  恢复 20 生命" + ("  ·  解锁第 3 个规则槽" if int(run.chapter) == 0 else "")
	_label(_host, "已获得 %d 金币%s" % [int(reward.get("gold", 0)), extra], Rect2(130, 296, 1340, 41), 24, GOLD, true)
	_label(_host, "选择一张牌，或保持当前构筑。", Rect2(135, 350, 1330, 34), 20, MUTED, true)
	var cards: Array = reward.get("cards", [])
	var gap: float = 300.0
	var start_x: float = (1600.0 - (maxi(cards.size() - 1, 0) * gap + 221.0)) / 2.0
	for i: int in range(cards.size()):
		var card: Dictionary = cards[i]
		var view := _card(_host, card, Vector2(start_x + i * gap, 430), 1.3, "reward")
		_reveal(view, 0.15 + i * 0.12, 36)
	_button(_host, "跳过选牌，继续旅程", Rect2(618, 842, 364, 60), "skip_reward")

func _result(kind: String) -> void:
	var run: Dictionary = _game.s.get("run", {})
	if run.is_empty():
		_title()
		return
	var practice: bool = run.get("practice", false)
	var won: bool = kind in ["victory", "practiceWin", "practice_win"]
	var ending := _panel(_host, Rect2(250, 172, 1100, 676), GOLD if won else BORDER)
	_label(ending, "THE LAW IS YOURS" if won else "ANOTHER POSSIBILITY AWAITS", Rect2(60, 38, 980, 37), 19, GOLD, true)
	_label(ending, ("第一条规则，由你写下" if practice else "断环已碎，规则新生") if won else "旅途暂歇", Rect2(55, 105, 990, 87), 49, PALE, true, true)
	_label(ending, "连锁的终点，是下一种构筑的起点。" if won else "失去的只是这次冒险。已解锁的起始卡组会保留。", Rect2(67, 217, 966, 59), 22, MUTED, true)
	_line(ending, 83, 310, 934)
	var stats: Dictionary = run.get("stats", {})
	var entries: Array = [["手动出牌", stats.get("manual", 0)], ["规则响应", stats.get("rules", 0)], ["攻击伤害", stats.get("damage", 0)], ["抵达节点", "练习" if practice else str(mini(24, int(run.get("chapter", 0)) * 8 + int(run.get("step", 0)) + 1))]]
	for i: int in range(entries.size()):
		_label(ending, str(entries[i][1]), Rect2(75 + i * 239, 343, 231, 89), 51, GOLD if won else MUTED, true, true)
		_label(ending, entries[i][0], Rect2(75 + i * 239, 447, 231, 35), 20, MUTED, true)
	_button(ending, "返回启程之地", Rect2(370, 551, 360, 65), "home", [], true)
	_reveal(ending, 0.05, 26)
