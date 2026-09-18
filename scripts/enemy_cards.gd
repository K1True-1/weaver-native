extends RefCounted
# Each enemy owns these concrete card definitions; combat instances carry unique UIDs.
# Numbers derive from the old creature's strengths, but actions are now paid card plays.

static func make_card(key: String, name: String, cost: int, kind: String, art: int, values: Dictionary = {}) -> Dictionary:
	var d = {"id":key,"key":key,"name":name,"cost":cost,"kind":kind,"type":"attack" if kind in ["attack","object_attack","counter","combo"] else ("defense" if kind in ["guard","object_guard","heal"] else "skill"),"art":art,"rarity":"common","tags":[],"text":"","damage":0,"hits":1,"block":0,"burn":0,"strength":0,"heal":0,"draw":0}
	d.merge(values,true)
	if d.type == "attack": d.tags.append("attack")
	if d.block>0: d.tags.append("block")
	if d.burn>0: d.tags.append("fire")
	if d.strength>0: d.tags.append("energy")
	if d.draw>0: d.tags.append("draw")
	if kind in ["object_attack","object_guard"]: d.tags.append("object")
	d.text = describe(d)
	return d

static func describe(d: Dictionary) -> String:
	var parts: Array = []
	match d.kind:
		"counter": parts.append("需要自身有护甲。")
		"combo": parts.append("需要本回合已打出其他牌。")
		"object_attack": parts.append("只能以存活物件为目标。")
		"object_guard": parts.append("保护一件尚有充能的物件。")
	if d.damage>0:
		parts.append("造成 %d 点伤害%s。" % [d.damage,"，共 %d 次" % d.hits if d.hits>1 else ""])
	if d.block>0: parts.append("获得 %d 护甲。" % d.block if d.kind != "object_guard" else "给予物件 %d 护甲。" % d.block)
	if d.burn>0: parts.append("施加 %d 层燃烧。" % d.burn)
	if d.strength>0: parts.append("本场力量 +%d。" % d.strength)
	if d.heal>0: parts.append("恢复 %d 生命。" % d.heal)
	if d.draw>0: parts.append("抽 %d 张牌。" % d.draw)
	return "".join(parts)

static func build(definition: Dictionary, scale: float = 1.0) -> Array:
	var peak = 1
	var guard = 0
	var hits = 1
	var fire = 0
	for action in definition.actions:
		peak = maxi(peak,int(action.get("damage",0))*int(action.get("hits",1)))
		guard = maxi(guard,int(action.get("block",0)))
		hits = maxi(hits,int(action.get("hits",1)))
		fire = maxi(fire,int(action.get("burn",0)))
	peak = maxi(4,roundi(peak*scale))
	guard = maxi(3,roundi(maxi(guard,4)*scale))
	var id = str(definition.id)
	var jab_damage = maxi(2,roundi(peak*0.28))
	var heavy_damage = maxi(4,roundi(peak*0.72))
	var shell = maxi(3,roundi(guard*0.75))
	var prefix = "EC_"+id+"_"
	var jab_names = {"N01":"灰刃突刺","N02":"甲足钩击","N03":"烬火弹","N04":"双刃试探","N05":"重蹄撞击","N06":"镜蚀刃","N07":"骑士直刺","N08":"熔核拳","N09":"碎律弹","E01":"监工鞭挞","E02":"执令斩","E03":"灼热撕咬","B01":"石门重拳","B02":"镜光裁切","B03":"王刃试锋"}
	var jab = make_card(prefix+"jab",jab_names.get(id,"突击"),1,"attack",2 if fire>0 else 0,{"damage":jab_damage})
	var heavy = make_card(prefix+"heavy","破阵重击",2,"attack",0,{"damage":heavy_damage})
	var armor = make_card(prefix+"guard","稳固防线",1,"guard",1,{"block":shell})
	var shatter_power = maxi(6,roundi(peak*0.9))
	if id in ["N04","N05","N07","N09","E01","E02","B02","B03"]: shatter_power += 4
	var shatter = make_card(prefix+"shatter","夺取战场",2,"object_attack",2,{"damage":shatter_power})
	var scout = make_card(prefix+"scout","重整手牌",1,"draw",3,{"draw":2})
	var signature: Dictionary
	var utility = scout
	match id:
		"N01": signature = make_card(prefix+"combo","乘隙连斩",1,"combo",5,{"damage":maxi(3,jab_damage+1)})
		"N02": signature = make_card(prefix+"counter","砾壳反撞",2,"counter",1,{"damage":heavy_damage+2})
		"N03":
			signature = make_card(prefix+"fire","余烬咒",1,"attack",2,{"damage":maxi(2,jab_damage-1),"burn":2})
			utility = make_card(prefix+"protect","护炉符",1,"object_guard",1,{"block":4})
		"N04":
			signature = make_card(prefix+"twins","双刃交击",2,"combo",5,{"damage":maxi(2,roundi(peak*0.4)),"hits":2})
			utility = make_card(prefix+"protect","护匣阵",1,"object_guard",1,{"block":5})
		"N05":
			signature = make_card(prefix+"shell","载具装甲",1,"guard",1,{"block":guard})
			utility = make_card(prefix+"mend","修整甲壳",1,"heal",6,{"heal":6})
		"N06": signature = make_card(prefix+"power","蚀镜蓄势",1,"strength",4,{"strength":1})
		"N07": signature = make_card(prefix+"flurry","三段骑袭",2,"attack",5,{"damage":maxi(2,roundi(peak*0.23)),"hits":3})
		"N08":
			signature = make_card(prefix+"fire","熔核冲撞",2,"attack",2,{"damage":maxi(4,heavy_damage-2),"burn":2})
			utility = make_card(prefix+"protect","熔炉壁障",1,"object_guard",1,{"block":8})
		"N09": signature = make_card(prefix+"power","编织增幅",1,"strength",4,{"strength":1})
		"E01":
			signature = make_card(prefix+"break","碎晶鞭",1,"object_attack",2,{"damage":maxi(8,shatter_power-2)})
			utility = make_card(prefix+"counter","监工反击",1,"counter",0,{"damage":jab_damage+2})
		"E02":
			signature = make_card(prefix+"power","双面敕令",1,"strength",4,{"strength":1})
			utility = make_card(prefix+"protect","封存律印",1,"object_guard",7,{"block":8})
		"E03":
			signature = make_card(prefix+"flurry","熔牙三连",2,"attack",5,{"damage":maxi(3,roundi(peak*0.24)),"hits":3})
			utility = make_card(prefix+"mend","炉心修复",1,"heal",6,{"heal":10})
		"B01": signature = make_card(prefix+"counter","石门回震",2,"counter",1,{"damage":heavy_damage+3})
		"B02": signature = make_card(prefix+"power","镜庭增幅",1,"strength",4,{"strength":1})
		"B03": signature = make_card(prefix+"flurry","断环裁决",2,"attack",5,{"damage":maxi(4,roundi(peak*0.25)),"hits":3})
		_: signature = heavy.duplicate(true)
	var deck = [jab,jab.duplicate(true),heavy,armor,armor.duplicate(true),signature,shatter,utility]
	if id.begins_with("E"): deck.append(signature.duplicate(true))
	if id.begins_with("B"):
		deck.append(signature.duplicate(true))
		deck.append(make_card(prefix+"royal","领主威仪",1,"guard",7,{"block":maxi(4,shell),"draw":1}))
	return deck
