extends RefCounted

var cards: Dictionary
var triggers: Array
var relics: Array
var loadouts: Dictionary
var chapters: Array
var enemies: Array
var objects: Array
var node_labels: Dictionary
var boss_phases: Dictionary
var rules_help: Array
var type_names: Dictionary
var rarity_names: Dictionary

func _init():
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://assets/game-data.json"))
	assert(parsed is Dictionary, "无法读取游戏数据")
	cards = parsed.CARDS
	triggers = parsed.TRIGGERS
	relics = parsed.RELICS
	loadouts = parsed.LOADOUTS
	chapters = parsed.CHAPTERS
	enemies = parsed.ENEMIES
	objects = parsed.OBJECTS
	node_labels = parsed.NODE_LABELS
	boss_phases = parsed.BOSS_PHASES
	rules_help = parsed.get("RULES_HELP", [])
	type_names = parsed.get("TYPE_NAMES", {"attack":"攻击","defense":"防御","skill":"技巧"})
	rarity_names = parsed.get("RARITY_NAMES", {"common":"普通","uncommon":"精良","rare":"稀有"})

func info(c: Dictionary) -> Dictionary:
	var d = cards[c.id].duplicate(true)
	if c.get("up", false):
		d.name += "+"
		d.text = d.plus
		if c.id in ["C21", "C29", "C30"]:
			d.cost = maxi(0, int(d.cost) - 1)
	return d

func by_id(list: Array, id: String) -> Dictionary:
	for item in list:
		if item.id == id: return item
	return {}

func object_text(o: Dictionary, chapter: int) -> String:
	var text = str(by_id(objects, o.get("def", o.get("id", ""))).get("player", ""))
	var values = {"b":[5,8,11], "e":[4,6,8], "d":[7,11,15], "f":[2,3,4], "h":[3,4,5], "eh":[5,7,9], "x":[8,12,16], "y":[4,6,8]}
	for key in values:
		text = text.replace("{" + key + "}", str(values[key][clampi(chapter, 0, 2)]))
	return text
