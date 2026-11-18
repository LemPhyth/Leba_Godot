extends RefCounted
## LEIBA-02 source-backed ring transactions. State belongs to the caller.
## Sources: buttons3205/3206 (buy/sell),2539..2542 (equip),2308 (unequip).
## Source owned flag and actor equipment slots are independent, deliberately.
const BUY_PRICE := 3000
const SELL_PRICE := 600
const RING_ID := 1
const SUPPORTED_CHARACTERS := ["crt_0", "crt_1", "crt_2", "crt_3"]

func equipment_family(character_id: String) -> String:
	# Original3835 crt>=3 reads the weaponmaster jewelry fields;2542/2308 and
	# save slot38 describe one shared family. Keep the four persisted slots.
	return "crt_3" if character_id=="crt_4" else character_id

func normalize(profile: Dictionary) -> void:
	if profile.get("settings") is Dictionary:
		for key: String in ["auto_save","auto_quality"]:
			if not profile.settings.has(key):profile.settings[key] = false
	# Additive defaults for ticket01 schema1. Do not replace malformed/unknown data.
	if profile.get("progress") is Dictionary and not profile.progress.has("clear_cubes"):
		# Original3841 new-profile default. Training does not refill this field.
		profile.progress["clear_cubes"] = 200
	if profile.get("selection") is Dictionary and not profile.selection.has("difficulty_id"):
		profile.selection["difficulty_id"] = "expert"
	if not profile.has("inventory"):
		profile["inventory"] = {}
	if profile.inventory is Dictionary and not profile.inventory.has("haring"):
		profile.inventory["haring"] = 0
	if not profile.get("equipment") is Dictionary:
		return
	if not profile.equipment.has("rings"):
		profile.equipment["rings"] = {}
	if profile.equipment.rings is Dictionary:
		for index in range(6):
			var identifier := "crt_%d" % index
			if not profile.equipment.rings.has(identifier):
				profile.equipment.rings[identifier] = 0

func transact(profile: Dictionary, operation: String, character_id: String) -> Dictionary:
	character_id=equipment_family(character_id)
	var problem := _validate(profile)
	if not problem.is_empty():
		return _result(false,problem)
	if operation in ["equip","unequip"] and character_id not in SUPPORTED_CHARACTERS:
		return _result(false,"该角色的戒指装备规则尚未接入。")
	var rings: Dictionary = profile.equipment.rings
	match operation:
		"buy":
			# Button3205 rejects an equipped copy even when the owned flag is zero.
			for id: String in SUPPORTED_CHARACTERS:
				if int(rings[id]) == RING_ID:
					return _result(false,"已有角色装备这枚戒指。")
			if int(profile.inventory.haring) != 0:
				return _result(false,"已经持有这枚戒指。")
			if int(profile.progress.gold) < BUY_PRICE:
				return _result(false,"金币不足，需要 3000 G。")
			profile.progress.gold -= BUY_PRICE
			profile.inventory.haring = 1
			return _result(true,"购买成功：HP +10 戒指。")
		"equip":
			# The inventory item only opens the actor selector when owned==1.
			if int(profile.inventory.haring) != 1:
				return _result(false,"尚未持有这枚戒指。")
			if int(rings[character_id]) not in [0,RING_ID]:
				return _result(false,"该槽位已有本轮尚未接入的装备，未覆盖。")
			rings[character_id] = RING_ID
			return _result(true,"已装备；下一场初始 HP / 上限增加 10。")
		"unequip":
			if int(rings[character_id]) != RING_ID:
				return _result(false,"当前角色未装备这枚戒指。")
			# Source2308 has four independent if statements, not an else-if chain.
			for id: String in SUPPORTED_CHARACTERS:
				if int(rings[id]) == RING_ID:
					rings[id] = 0
			profile.inventory.haring = 1
			return _result(true,"已卸下这枚戒指的角色装备记录。")
		"sell":
			# Source3206 checks owned only. It does not clear actor ring slots.
			# This odd source behaviour is documented, not silently repaired.
			if int(profile.inventory.haring) != 1:
				return _result(false,"没有可出售的这枚戒指。")
			if float(profile.progress.gold) > 9007199254740991.0 - SELL_PRICE:
				return _result(false,"金币超过本工程存档可安全表示的范围，未修改。")
			profile.inventory.haring = 0
			profile.progress.gold += SELL_PRICE
			return _result(true,"出售成功，获得 600 G。")
		_:
			return _result(false,"未知的装备操作：" + operation)

func max_hp_bonus(profile: Dictionary, character_id: String) -> float:
	character_id=equipment_family(character_id)
	if character_id not in SUPPORTED_CHARACTERS:
		return 0.0
	var equipment: Variant = profile.get("equipment",{})
	if not equipment is Dictionary or not equipment.get("rings",{}) is Dictionary:
		return 0.0
	var item: Variant = equipment.get("rings",{}).get(character_id,0)
	return 10.0 if _nonnegative_integer(item) and int(item) == RING_ID else 0.0

func _validate(profile: Dictionary) -> String:
	if not profile.get("progress") is Dictionary or not _nonnegative_integer(profile.progress.get("gold")):
		return "金币数据无效，未修改进度。"
	if not profile.get("inventory") is Dictionary or not _nonnegative_integer(profile.inventory.get("haring")):
		return "戒指库存数据无效，未修改进度。"
	if int(profile.inventory.haring) not in [0,1]:
		return "戒指库存标记必须为 0 或 1。"
	if not profile.get("equipment") is Dictionary or not profile.equipment.get("rings") is Dictionary:
		return "戒指装备数据无效，未修改进度。"
	for id: String in SUPPORTED_CHARACTERS:
		if not _nonnegative_integer(profile.equipment.rings.get(id)):
			return "角色装备槽无效：" + id
	return ""

func _nonnegative_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and float(value) == floor(float(value)) and float(value) <= 9007199254740991.0

func _result(ok: bool, message: String) -> Dictionary:
	return {"ok":ok,"message":message}
