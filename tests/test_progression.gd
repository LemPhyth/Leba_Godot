extends SceneTree
## Money and item flags below are explicit fixtures; no free gold is granted by runtime.
const Progression = preload("res://scripts/core/progression.gd")
const SaveStore = preload("res://scripts/services/save_store.gd")
var checks: Array[Dictionary] = []
var progression := Progression.new()

func _initialize() -> void:
	call_deferred("_run")

func _check(label: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"name":label,"passed":passed,"detail":detail})
	print(("PASS " if passed else "FAIL ") + label + (" " + str(detail) if str(detail) != "" else ""))

func _unchanged_failure(profile: Dictionary, operation: String, actor := "crt_0") -> void:
	var before := profile.duplicate(true)
	var result: Dictionary = progression.transact(profile,operation,actor)
	_check("rejected %s leaves entire profile unchanged: %s" % [operation,result.message],not result.ok and profile == before)

func _fresh(gold := 0) -> Dictionary:
	var data: Dictionary = SaveStore.new().default_profile()
	data.progress.gold = gold
	progression.normalize(data)
	return data

func _run() -> void:
	var data: Dictionary = SaveStore.new().default_profile()
	data.progress.gold = 123
	data.extra = {"preserve":"user data"}
	data.equipment.unknown = {"item":42}
	progression.normalize(data)
	_check("old schema1 gets additive difficulty and inventory defaults",data.selection.difficulty_id == "expert" and data.inventory.haring == 0 and data.equipment.rings.size() == 6)
	_check("normalization preserves gold and unknown fields",data.progress.gold == 123 and data.extra.preserve == "user data" and data.equipment.unknown.item == 42)
	data.selection.difficulty_id = "master"
	var normalized := data.duplicate(true)
	progression.normalize(data)
	_check("normalization is idempotent and preserves selected difficulty",data == normalized)
	data = _fresh(2999)
	_unchanged_failure(data,"buy")
	_unchanged_failure(data,"equip")
	_unchanged_failure(data,"unequip")
	_unchanged_failure(data,"sell")
	_unchanged_failure(data,"invented_operation")
	data = _fresh(3000)
	_check("source buy3205 spends3000 and sets owned flag",progression.transact(data,"buy","crt_0").ok and data.progress.gold == 0 and data.inventory.haring == 1)
	_unchanged_failure(data,"buy")
	# ACT06 verifies CRT4's shared CRT3 family in the normal storage flow.
	_unchanged_failure(data,"equip","crt_5")
	_check("source equip2539 preserves owned flag",progression.transact(data,"equip","crt_0").ok and data.inventory.haring == 1 and data.equipment.rings.crt_0 == 1)
	_check("source root2 load_9 adds10 only to equipped actor",progression.max_hp_bonus(data,"crt_0") == 10.0 and progression.max_hp_bonus(data,"crt_1") == 0.0)
	_check("source second actor can share the owned flag",progression.transact(data,"equip","crt_1").ok and data.equipment.rings.crt_0 == 1 and data.equipment.rings.crt_1 == 1)
	_check("source2308 clears all matching source slots",progression.transact(data,"unequip","crt_0").ok and data.equipment.rings.crt_0 == 0 and data.equipment.rings.crt_1 == 0 and data.inventory.haring == 1)
	_check("unequipped actor has no health bonus",progression.max_hp_bonus(data,"crt_0") == 0.0)
	_check("source3206 sells owned item for600",progression.transact(data,"sell","crt_0").ok and data.inventory.haring == 0 and data.progress.gold == 600)
	_unchanged_failure(data,"sell")
	# This is a source-behaviour fixture, not a newly invented inventory repair.
	data = _fresh(3000)
	progression.transact(data,"buy","crt_0")
	progression.transact(data,"equip","crt_0")
	_check("source sell does not silently clear equipped source slots",progression.transact(data,"sell","crt_0").ok and data.inventory.haring == 0 and data.equipment.rings.crt_0 == 1 and progression.max_hp_bonus(data,"crt_0") == 10.0)
	data.progress.gold = 3000
	_unchanged_failure(data,"buy")
	_check("source unequip restores owned flag after sale",progression.transact(data,"unequip","crt_0").ok and data.inventory.haring == 1 and data.equipment.rings.crt_0 == 0)
	data.equipment.rings.crt_0 = 7
	_unchanged_failure(data,"equip")
	_check("unimplemented ring id is not granted this ring bonus",progression.max_hp_bonus(data,"crt_0") == 0.0)
	data = _fresh()
	data.inventory.haring = "invalid"
	_unchanged_failure(data,"buy")
	data = _fresh()
	data.progress.gold = -1
	_unchanged_failure(data,"buy")
	data = _fresh(3000)
	progression.transact(data,"buy","crt_1")
	progression.transact(data,"equip","crt_1")
	data.selection.difficulty_id = "king"
	var test_path := "user://leiba02_progression_tests/run_%d_%d/profile.json" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	var store := SaveStore.new(test_path)
	_check("extended state saves through existing SaveStore",store.save_profile(data) == OK,store.last_message)
	var loaded: Dictionary = SaveStore.new(test_path).load_profile()
	_check("cross-instance load preserves difficulty inventory and actor slot",loaded.ok and loaded.profile.selection.get("difficulty_id") == "king" and loaded.profile.get("inventory",{}).get("haring") == 1 and loaded.profile.equipment.get("rings",{}).get("crt_1") == 1,loaded.message)
	_check("loaded equipment drives the same health bonus",progression.max_hp_bonus(loaded.profile,"crt_1") == 10.0)
	var failures := checks.filter(func(item:Dictionary)->bool:return not item.passed).size()
	var report_dir := OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if report_dir.is_empty():
		report_dir = "res://artifacts"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_dir))
	var file := FileAccess.open(report_dir.path_join("progression_tests.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"suite":"leiba02_progression","checks":checks,"failures":failures,"save_test_path":test_path,"scope":"Actual progression service and SaveStore IO; explicit gold/item fixtures. Source inventory edge semantics statically verified; original runtime shop comparison not performed by this suite."},"\t"))
	file.close()
	print("Progression: %d passed / %d failed" % [checks.size()-failures,failures])
	quit(0 if failures == 0 else 1)
