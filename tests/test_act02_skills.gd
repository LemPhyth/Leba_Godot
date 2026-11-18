extends SceneTree
## ACT02 B: independent A/W, inventory/Q clocks, R world timer and C4 chain.
## Actual Main/Battle/InputMap, headless Dummy; no OS input/Flash claim.
## Reference JSON is an oracle only. It never supplies runtime state or results.
const MainScene = preload("res://scenes/main.tscn")
const SaveStore = preload("res://scripts/services/save_store.gd")
const EVIDENCE_DIR := "res://artifacts/leba_act02_20261115/"
var app: Node
var checks: Array[Dictionary] = []
var traces: Array[Dictionary] = []
var evidence: Dictionary = {}
var formal_exists := false
var formal_hash := ""

func _initialize() -> void:call_deferred("_run")

func _check(name: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"name":name,"passed":passed,"detail":detail})
	print(("PASS " if passed else "FAIL ")+name+" "+str(detail))

func _near(a: float, b: float) -> bool:return absf(a-b) <= 0.0001

func _load_evidence(name: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(EVIDENCE_DIR+name+".json"))
	if not parsed is Dictionary:
		_check("independent original evidence exists: "+name,false)
		return {}
	var data: Dictionary = parsed
	_check("independent original evidence has DONE and integrity: "+name,bool(data.integrity.ok) and int(data.finish.failures) == 0)
	evidence[name] = {"json_sha256":FileAccess.get_sha256(EVIDENCE_DIR+name+".json"),"original_log":data.log,"log_sha256":data.get("log_sha256",data.get("sha256","")),"evidence_class":data.evidence_class}
	return data

func _fresh() -> Node2D:
	app.action_lab = false
	app.session.profile = app.saves.default_profile()
	app.session.select_difficulty("expert")
	app._on_intent("select_training_character","crt_0")
	var battle: Node2D = app.battle
	battle.set_physics_process(false)
	battle.manual_clock = true
	battle.step({}) # Complete the original4112 initialization before gate fixtures.
	return battle

func _isolated() -> Node2D:
	var battle := _fresh()
	# Explicit no-contact fixture for inventory/choice clocks, not original AI.
	battle.enemies[0].position = Vector2(550,1000)
	return battle

func _press(battle: Node2D, key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	battle._unhandled_input(event)
	battle.step(battle.take_commands())

func _events(battle: Node2D, kind: String) -> Array:
	return battle.journal.filter(func(row:Dictionary)->bool:return row.event == kind)

func _wait_cooldown(battle: Node2D, key: String) -> bool:
	for tick in range(900):
		if int(battle.player.cooldowns.get(key,0)) == 0:return true
		battle.step({})
	_check("bounded wait reaches cooldown readiness: "+key,false,battle.snapshot())
	return false

func _wait_ammo_clear(battle: Node2D, kind: String) -> bool:
	for tick in range(360):
		if int(battle.ammo_frames[kind]) == 1:return true
		battle.step({})
	_check("bounded wait reaches original355-frame timer end: "+kind,false,battle.snapshot())
	return false

func _run() -> void:
	formal_exists = FileAccess.file_exists("user://profile.json")
	if formal_exists:formal_hash = FileAccess.get_sha256("user://profile.json")
	app = MainScene.instantiate()
	root.add_child(app)
	_check("skill suite uses actual Main isolated test startup",app.startup_ok and app.test_mode and app.action_lab)
	if not app.startup_ok:
		_finish()
		return
	app.saves = SaveStore.new("user://act02_skills/run_%d_%d/profile.json" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()])
	var summon_source := _load_evidence("summons_probe")
	var defaults_source := _load_evidence("defaults_probe")
	var persistent_source := _load_evidence("persistent_probe")
	_test_summon_input_gates()
	if not summon_source.is_empty():
		_test_summon_case(summon_source,"A_contact",40,60,105,250.0,KEY_A)
		_test_summon_case(summon_source,"A_timeout",210,240,403,550.0,KEY_A)
		_test_summon_case(summon_source,"W_contact",470,490,532,187.0,KEY_W)
	_test_summon_lifetime()
	if not defaults_source.is_empty():_test_grenade_inventories(defaults_source)
	_test_grenade_early_branches()
	_test_q_choice_and_timeout()
	if not persistent_source.is_empty():
		_test_q_independent_timers(persistent_source)
		_test_r_source_timeline(persistent_source)
		_test_c4_source_timeline(persistent_source)
	_test_r_c4_input_gates()
	_test_c4_thaw_source_branch()
	_check("skill fixtures leave formal profile existence and hash unchanged",FileAccess.file_exists("user://profile.json") == formal_exists and (not formal_exists or FileAccess.get_sha256("user://profile.json") == formal_hash))
	app._dispose_battle()
	var drained: bool = await app.audio.stop_and_drain(1.0)
	_check("skill Dummy audio releases native playback references",drained and app.audio.snapshot().pending_playbacks == 0)
	app.queue_free()
	await process_frame
	_finish()

func _test_summon_input_gates() -> void:
	# AS2 skillbar4064/4083: cost7, A shares66-frame Z slot; W270-frame slot.
	for spec: Array in [[KEY_A,"skill_a",21,"skill_z",65],[KEY_W,"skill_w",1,"skill_w",269]]:
		var battle := _isolated()
		_press(battle,spec[0])
		_check("actual InputMap enters source113 default "+str(spec[1]),battle.player.state == spec[1] and battle.player.parent_frame == 113 and battle.player.source_frame == spec[2] and _near(battle.player.mp,123.05) and battle.player.cooldowns[spec[3]] == spec[4] and battle.summons.is_empty(),battle.snapshot())
		battle = _isolated()
		battle.player.mp = 6.9 # Explicit resource boundary, before one regen tick.
		_press(battle,spec[0])
		_check("MP below7 rejects without creating summon: "+str(spec[1]),battle.player.state == "idle" and _near(battle.player.mp,6.95) and battle.summons.is_empty() and int(battle.player.cooldowns.get(spec[3],0)) == 0)
		battle = _isolated()
		battle.player.set_action("jump")
		_press(battle,spec[0])
		_check("source B-state gate rejects summon from jump: "+str(spec[1]),battle.player.state == "jump" and battle.player.mp == 130 and battle.summons.is_empty())
	var shared := _isolated()
	_press(shared,KEY_A)
	for tick in range(9):shared.step({})
	var count: int = shared.summons.size()
	_press(shared,KEY_Z)
	_check("A consumes shared Z slot but does not consume W slot",shared.player.state == "idle" and int(shared.player.cooldowns.skill_z) > 0 and int(shared.player.cooldowns.get("skill_w",0)) == 0 and shared.summons.size() == count)

func _sample(battle: Node2D, source_tick: int) -> Dictionary:
	var enemy: Node2D = battle.enemies[0]
	var result := {"t":source_tick,"actor":battle.player.parent_frame,"action":battle.player.source_frame,"px":battle.player.position.x,"py":battle.player.position.y,"ehp":enemy.hp,"ex":enemy.position.x,"ey":enemy.position.y,"g":enemy.vertical_speed,"gacc":enemy.gravity_acceleration,"outer":2 if enemy.airborne else 1,"summon_count":battle.summons.size()}
	if not battle.summons.is_empty():
		var item: Dictionary = battle.summons[0]
		result["object"] = {"frame":int(item.frame),"wait":int(item.child) if item.kind == "runner" else int(item.wait)+1,"x":item.visual.position.x,"y":item.visual.position.y,"asdepth":int(item.depth),"sx":item.visual.scale.x*100.0,"sy":item.visual.scale.y*100.0}
	return result

func _differences(actual: Dictionary, expected: Dictionary, fields: Array) -> Array:
	var result: Array = []
	for key: String in fields:
		var wanted: Variant = expected[key]
		if not wanted is int and not wanted is float:continue
		if not actual.has(key) or not _near(float(actual[key]),float(wanted)):
			result.append({"field":key,"actual":actual.get(key),"expected":wanted,"source_tick":int(expected.t),"raw_line":int(expected.raw_line)})
	return result

func _test_summon_case(source: Dictionary, case_id: String, seed_tick: int, entry_tick: int, end_tick: int, enemy_x: float, key: Key) -> void:
	# Match the independently recorded fixture seed: training4030 HP2000 only
	# for numeric resolution, original source matrices and real training AI.
	# Original probe bypassed key/MP/CD with parent113 seek. Here the normal
	# InputMap starts A/W, then world objects are compared on identical ticks.
	var battle := _fresh()
	var enemy: Node2D = battle.enemies[0]
	battle.player.position = Vector2(132.4,314.9)
	battle.player.set_facing(1)
	enemy.position = Vector2(enemy_x,361)
	enemy.hp = 2000
	enemy.definition.max_hp = 2000
	enemy.vertical_speed = 0
	enemy.gravity_acceleration = 0
	enemy.airborne = false
	enemy.set_action("idle")
	var state_by_tick := {}
	var object_by_tick := {}
	for row: Dictionary in source.records:
		if row.get("case","") != case_id or row.get("tag","") != "tick":continue
		if row.record_type == "STATE":state_by_tick[int(row.t)] = row
		if row.record_type == "OBJECT":object_by_tick[int(row.t)] = row
	var missing_ticks: Array[int] = []
	for tick in range(seed_tick,end_tick+1):
		if not state_by_tick.has(tick):missing_ticks.append(tick)
	_check("original controlled "+case_id+" oracle contains every compared source tick",missing_ticks.is_empty(),missing_ticks)
	# The original second case is in the SAME root and retains i=1001 from its
	# earlier A. Each Godot case deliberately starts fresh, so carry this explicit
	# seed alongside HP/positions instead of expecting a fresh root's1000 to equal
	# that prior-history1001. Repeated real A depth progression is tested below.
	if state_by_tick.has(seed_tick):battle._next_root_depth = int(state_by_tick[seed_tick].root_i)
	var samples: Array[Dictionary] = []
	var differences := {"player":[],"object":[],"enemy_position":[],"enemy_hp":[],"enemy_physics":[]}
	for tick in range(seed_tick,end_tick+1):
		if tick > seed_tick:
			if tick == entry_tick:_press(battle,key)
			else:battle.step({})
		# Same explicit timeout pin/release as the original controlled fixture;
		# expected positions remain the independent log, never fed into runtime.
		if case_id == "A_timeout" and tick < 391:enemy.position.x = 550.0
		if case_id == "A_timeout" and tick == 391:
			_check("A timeout reaches original child148 before target relocation",battle.summons.size() == 1 and int(battle.summons[0].child) == 148 and int(battle.summons[0].frame) == 1)
			if not battle.summons.is_empty():enemy.position.x = battle.summons[0].visual.position.x+75.0
		var sample := _sample(battle,tick)
		samples.append(sample)
		if state_by_tick.has(tick):
			var expected: Dictionary = state_by_tick[tick]
			var player_fields := ["actor","action","px","py"]
			# Immediate parent113 fixture trace sees pre-load1; normal A input
			# uses the consumed load flag and displays21. From next tick22 agrees.
			if tick == entry_tick and key == KEY_A:player_fields.erase("action")
			differences.player.append_array(_differences(sample,expected,player_fields))
			differences.enemy_position.append_array(_differences(sample,expected,["ex","ey"]))
			differences.enemy_hp.append_array(_differences(sample,expected,["ehp"]))
			differences.enemy_physics.append_array(_differences(sample,expected,["g","gacc","outer"]))
		if object_by_tick.has(tick):
			if sample.has("object"):differences.object.append_array(_differences(sample.object,object_by_tick[tick],["frame","wait","x","y","asdepth","sx","sy"]))
			else:differences.object.append({"source_tick":tick,"field":"object","actual":null,"expected":"original object exists","raw_line":object_by_tick[tick].raw_line})
	for category: String in differences:
		_check("original controlled "+case_id+" per-tick "+category,differences[category].is_empty(),{"difference_count":differences[category].size(),"first_difference":differences[category][0] if not differences[category].is_empty() else null})
	_check("original controlled "+case_id+" has one world object at unscaled player root",battle.summons.size() == 1 and battle.summons[0].visual.get_parent() == battle and battle.summons[0].visual.scale == Vector2.ONE and battle.player.get_instance_id() != battle.summons[0].visual.get_instance_id())
	traces.append({"kind":"original_controlled_summon_same_seed_actual_normal_skill_input","case":case_id,"seed_enemy_hp":2000,"entry":entry_tick,"phase_boundary":"A initial action1 pre-load observation excluded only at entry; subsequent source22..30 and all world rows compared. Original probe was not keyboard input.","samples":samples,"differences":differences,"events":battle.journal.duplicate(true)})

func _test_summon_lifetime() -> void:
	var battle := _isolated()
	_press(battle,KEY_W)
	for tick in range(4):battle.step({})
	_check("W source5 creates separate root negative-depth mine",battle.summons.size() == 1 and battle.summons[0].kind == "mine" and battle.summons[0].depth == -16300 and battle.summons[0].frame == 1)
	if battle.summons.is_empty():return
	var first: Node2D = battle.summons[0].visual
	battle.player.request_hurt()
	for tick in range(10):battle.step({})
	_check("world mine continues independently through player hurt",battle.summons.size() == 1 and battle.summons[0].visual == first and battle.summons[0].frame == 11)
	_wait_cooldown(battle,"skill_w")
	_press(battle,KEY_W)
	for tick in range(4):battle.step({})
	_check("repeated W replaces same original depth rather than accumulating mines",battle.summons.size() == 1 and battle.summons[0].depth == -16300 and battle.summons[0].visual != first and first.is_queued_for_deletion())
	var prior: Node2D = battle
	app._dispose_battle()
	_check("scene exit detaches battle owning all derived objects",prior.get_parent() == null and prior.is_queued_for_deletion())
	battle = _isolated()
	_press(battle,KEY_A)
	for tick in range(4):battle.step({})
	_wait_cooldown(battle,"skill_z")
	_press(battle,KEY_A)
	for tick in range(4):battle.step({})
	_check("repeated normal A inputs increment root i and retain both independent objects",battle.summons.size() == 2 and battle.summons[0].depth == 1000 and battle.summons[1].depth == 1001 and battle.summons[0].visual != battle.summons[1].visual)
	# Explicit source display-depth fixture:731 reuses1000;728 uses15000.
	# A later-created replacement must stay below a surviving higher depth.
	var upper: Node2D = battle.summons[1].visual
	battle._spawn_fire_blast(battle.player.position,1000)
	var replacement: Node2D = battle.summons.back().visual
	_check("source depth1000 replacement remains below surviving1001 despite later creation",upper.z_index == replacement.z_index and upper.get_index() > replacement.get_index())
	battle._start_source_feedback("glass")
	battle._spawn_summon("runner")
	var glass: Node2D = battle.source_feedback.glass.visual
	var newer_runner: Node2D = battle.summons.back().visual
	_check("source glass15000 remains above later A1002 at clamped equal Godot z",glass.z_index == newer_runner.z_index and glass.get_index() > newer_runner.get_index())

func _test_grenade_inventories(source: Dictionary) -> void:
	# F dynamic defaults_probe: source13 activates HUD but stock0;14 stock5;
	# source15 returns. G/H share separately verified6014/6016 and HUD4/3.
	_check("original defaults probe confirms F stock5 independently",int(source.f_original_load_stock) == 5)
	for spec: Array in [["f",KEY_F,5,114,123,147,216],["g",KEY_G,4,115,185,210,269],["h",KEY_H,3,116,5,43,323]]:
		var kind: String = spec[0]
		var battle := _isolated()
		battle.player.mp = 4.95
		_press(battle,spec[1])
		_check(kind+" checks MP5 before this tick regeneration without creating stock",battle.player.state == "idle" and battle.grenades[kind].stock == 0 and _near(battle.player.mp,5.0))
		_press(battle,spec[1])
		_check(kind+" exact MP5 permits load on subsequent real key event",battle.player.state == "load_"+kind and _near(battle.player.mp,0.05))
		battle = _isolated()
		var samples: Array[Dictionary] = []
		_press(battle,spec[1])
		_check("actual "+kind+" input loads with MP5 and correct source parent",battle.player.parent_frame == spec[3] and battle.player.source_frame == 1 and _near(battle.player.mp,125.05) and battle.grenades[kind].stock == 0)
		for frame in range(2,14):battle.step({})
		_check(kind+" source13 activates HUD before deferred inventory",battle.player.source_frame == 13 and battle.grenades[kind].active and battle.grenades[kind].stock == 0 and int(battle.player.cooldowns.get("load_"+kind,0)) == 0)
		battle.step({})
		_check(kind+" source14 applies exact original stock",battle.player.source_frame == 14 and battle.grenades[kind].stock == spec[2] and battle.grenades[kind].icon_frame == 1)
		battle.step({})
		_check(kind+" source15 ends load without starting reload cooldown",battle.player.state == "idle" and battle.grenades[kind].stock == spec[2] and int(battle.player.cooldowns.get("load_"+kind,0)) == 0)
		for shot in range(int(spec[2])):
			var mp_before: float = battle.player.mp
			_press(battle,spec[1])
			_check(kind+" throw%d consumes inventory once and no MP" % (shot+1),battle.player.parent_frame == 19 and battle.player.source_frame == spec[4] and battle.grenades[kind].stock == int(spec[2])-shot-1 and battle.grenades[kind].icon_frame == 2 and _near(battle.player.mp,minf(130,mp_before+0.05)))
			for elapsed in range(1,81):
				var expected_frame: int = int(spec[4])+elapsed
				# Retry the actual key after source terminal; icon cooldown must
				# reject it while inventory remains, without charging loadMP.
				if elapsed == int(spec[5])-int(spec[4])+1 and shot < int(spec[2])-1:_press(battle,spec[1])
				else:battle.step({})
				var row := {"shot":shot+1,"elapsed":elapsed,"actor":battle.player.parent_frame,"action":battle.player.source_frame,"stock":battle.grenades[kind].stock,"icon":battle.grenades[kind].icon_frame,"cd":int(battle.player.cooldowns.get("load_"+kind,0))}
				samples.append(row)
				if elapsed == int(spec[5])-int(spec[4])-1:_check(kind+" throw%d keeps final visible pre-control frame" % (shot+1),battle.player.parent_frame == 19 and battle.player.source_frame == expected_frame,row)
				if elapsed == int(spec[5])-int(spec[4]):_check(kind+" throw%d returns on original source control frame" % (shot+1),battle.player.state == "idle",row)
				if elapsed == 1 and shot == int(spec[2])-1:_check(kind+" only depleted stock starts original reload slot",int(battle.player.cooldowns.get("load_"+kind,0)) == spec[6] and not battle.grenades[kind].active,row)
				if elapsed == 79:_check(kind+" throw%d icon reaches81 before ready" % (shot+1),battle.grenades[kind].icon_frame == 81,row)
				if elapsed == 80:_check(kind+" throw%d icon loops to1 after80 source ticks" % (shot+1),battle.grenades[kind].icon_frame == 1 and battle.grenades[kind].stock == int(spec[2])-shot-1,row)
		var mp_before: float = battle.player.mp
		_press(battle,spec[1])
		_check(kind+" depleted reload gate rejects before slot ready",battle.player.state == "idle" and battle.grenades[kind].stock == 0 and _near(battle.player.mp,minf(130,mp_before+0.05)))
		_wait_cooldown(battle,"load_"+kind)
		_press(battle,spec[1])
		_check(kind+" naturally ready slot permits another real load",battle.player.state == "load_"+kind and battle.player.source_frame == 1 and _near(battle.player.mp,125.05))
		traces.append({"kind":"grenade_inventory_actual_key_input_static_GH_dynamic_F_boundary","grenade":kind,"samples":samples})
	var mixed := _isolated()
	_press(mixed,KEY_F)
	for tick in range(14):mixed.step({})
	_press(mixed,KEY_G)
	for tick in range(14):mixed.step({})
	_press(mixed,KEY_F)
	for tick in range(24):mixed.step({})
	var f_icon: int = mixed.grenades.f.icon_frame
	_press(mixed,KEY_G)
	_check("F and G inventory listeners retain independent81-frame icons",mixed.player.state == "throw_g" and mixed.grenades.g.stock == 3 and mixed.grenades.f.stock == 4 and mixed.grenades.g.icon_frame == 2 and mixed.grenades.f.icon_frame == f_icon+1)

func _test_grenade_early_branches() -> void:
	# Independent4744 frame scripts: three early-contact choices per type. Seed
	# an original4030 at an explicit source-space position only immediately before
	# the selected helper's Load, avoiding earlier contact. New clips receive Load
	# on9/11/13 (F/G equivalent); EnterFrame first runs10/12/14. This is original
	# display-list/host evidence, dynamically closed by status_v2 H13->94 next tick.
	# These are geometry fixtures,
	# not claims about natural enemy movement, frozen/lightning or total damage.
	var specs := [["f",KEY_F,5,123,[127,129,131],[148,159,170],[158,169,180]],
		["g",KEY_G,4,185,[189,191,193],[211,222,233],[221,232,243]],
		["h",KEY_H,3,5,[9,11,13],[44,69,94],[68,93,118]]]
	for spec: Array in specs:
		var kind: String = spec[0]
		for branch in range(3):
			var battle := _isolated()
			_press(battle,spec[1])
			for tick in range(14):battle.step({})
			_press(battle,spec[1])
			var trigger: int = spec[4][branch]
			var destination: int = spec[5][branch]
			var terminal: int = spec[6][branch]
			for tick in range(trigger-int(spec[3])-1):battle.step({})
			var enemy: Node2D = battle.enemies[0]
			enemy.position = Vector2([185.0,215.0,245.0][branch],360.15)
			enemy.set_facing(-1)
			battle.step({})
			_check("original "+kind+" helper%d Load does not run EnterFrame collision" % trigger,battle.player.state == "throw_"+kind and battle.player.source_frame == trigger and _events(battle,"grenade_early_contact").is_empty(),{"source_frame":battle.player.source_frame})
			battle.step({})
			var events: Array = _events(battle,"grenade_early_contact")
			_check("original "+kind+" first EnterFrame%d reaches source%d" % [trigger+1,destination],battle.player.state == "throw_"+kind and battle.player.source_frame == destination and events.size() == 1 and int(events[0].from) == trigger+1 and int(events[0].to) == destination,{"source_frame":battle.player.source_frame,"events":events,"enemy_position":[enemy.position.x,enemy.position.y]})
			# Stop further geometry contacts, not the player's independent action.
			enemy.position = Vector2(550,1000)
			enemy.airborne = false
			enemy.vertical_speed = 0
			enemy.gravity_acceleration = 0
			var samples: Array[int] = [battle.player.source_frame]
			for tick in range(terminal-destination):
				battle.step({})
				samples.append(battle.player.source_frame)
			_check("original "+kind+" branch%d ends on%d without a second inventory charge" % [destination,terminal],battle.player.state == "idle" and battle.grenades[kind].stock == int(spec[2])-1 and _events(battle,"grenade_thrown").size() == 1,{"frames":samples,"stock":battle.grenades[kind].stock})
			traces.append({"kind":"original4744_geometry_branch_fixture_Load_then_EnterFrame","grenade":kind,"helper_load_frame":trigger,"first_enterframe":trigger+1,"destination":destination,"terminal":terminal,"frames":samples,"seed_enemy_position":[[185.0,215.0,245.0][branch],360.15],"events":events})

func _wait_q_hold(battle: Node2D) -> bool:
	for tick in range(12):
		if battle.player.state == "skill_q" and battle.player.source_frame == 12:return true
		battle.step({})
	return false

func _test_q_choice_and_timeout() -> void:
	var poor := _isolated()
	poor.player.mp = 7.9
	_press(poor,KEY_Q)
	_check("Q MP below8 does not start choice or either ammo clock",poor.player.state == "idle" and _near(poor.player.mp,7.95) and poor.ammo_frames == {"fire":1,"silver":1})
	for key: Key in [KEY_UP,KEY_DOWN]:
		var battle := _isolated()
		_press(battle,KEY_Q)
		_check("Q real key enters source18 and costs8: "+str(key),battle.player.parent_frame == 18 and battle.player.source_frame == 1 and _near(battle.player.mp,122.05))
		var reached := _wait_q_hold(battle)
		_check("Q skips control9 to genuine held12: "+str(key),reached)
		for tick in range(15):battle.step({})
		_check("Q held parent preserves independently advancing body19: "+str(key),battle.player.source_frame == 12 and battle.player.body_frame == 19)
		_press(battle,key)
		var ammo := "fire" if key == KEY_UP else "silver"
		_check("Q chooses source13 or22 and starts only selected timer: "+ammo,battle.player.source_frame == (13 if key == KEY_UP else 22) and battle.ammo_frames[ammo] == 2 and battle.ammo_frames["silver" if ammo == "fire" else "fire"] == 1,battle.snapshot())
	var contested := _isolated()
	_press(contested,KEY_Q)
	_wait_q_hold(contested)
	# Both held in one keyDown: source13 removes4718's old depth2 head;
	# the queued Down record belonging to that removed instance cannot run.
	# Source XML + Ruffle dispatch inference, not a dynamic OS-keyboard claim.
	Input.action_press("aim_up")
	_press(contested,KEY_DOWN)
	Input.action_release("aim_up")
	_check("Q Up choice removes old Down listener in a shared keyDown event",contested.player.source_frame == 13 and contested.ammo_frames == {"fire":2,"silver":1},contested.snapshot())
	var auto := _isolated()
	_press(auto,KEY_Q)
	_check("Q timeout fixture reaches source12",_wait_q_hold(auto))
	for child in range(2,101):auto.step({})
	_check("Q independent4717 has not timed out before source101",auto.player.state == "skill_q" and auto.player.source_frame == 12)
	auto.step({})
	_check("Q independent4717 source101 automatically selects fire13",auto.player.state == "skill_q" and auto.player.source_frame == 13 and auto.ammo_frames.fire == 2,auto.snapshot())

func _test_q_independent_timers(source: Dictionary) -> void:
	# Original persistent_probe: original timer2->8 inactive,9..355 active,
	# then1 clears; complete355-frame child, not accelerated seeked timer.
	_check("original Q timer oracle preserves observed347 active ticks",int(source.q_fire_timer.observed_active_tick_span) == 347 and int(source.q_silver_timer.observed_active_tick_span) == 347)
	var battle := _isolated()
	_press(battle,KEY_Q)
	if not _wait_q_hold(battle):
		_check("Q timer actual input reaches hold",false)
		return
	_press(battle,KEY_UP)
	var samples: Array[Dictionary] = []
	var first_diff: Variant = null
	for elapsed in range(355):
		if elapsed > 0:battle.step({})
		var expected: int = elapsed+2 if elapsed < 354 else 1
		var actual: int = battle.ammo_frames.fire
		var row := {"elapsed":elapsed,"frame":actual,"expected":expected}
		samples.append(row)
		if actual != expected and first_diff == null:first_diff = row
	_check("Q fire clock runs full original2..355 then1 while player has returned",first_diff == null and battle.player.state == "idle",first_diff)
	traces.append({"kind":"original_dynamic_Q355_timer_semantics_after_actual_UP_input","samples":samples})
	battle = _isolated()
	_press(battle,KEY_Q)
	_wait_q_hold(battle)
	_press(battle,KEY_UP)
	# Natural Q cooldown, no reset/cooldown fixture, enables the other selection
	# before the first355-frame timer expires. This validates independent clocks;
	# actual zak/eun-driven projectile effects need their separate implementation.
	_wait_cooldown(battle,"skill_q")
	_press(battle,KEY_Q)
	_wait_q_hold(battle)
	_press(battle,KEY_DOWN)
	for tick in range(7):battle.step({})
	_check("Q naturally reselects silver while fire timer remains active",int(battle.ammo_frames.fire) >= 9 and int(battle.ammo_frames.fire) <= 355 and int(battle.ammo_frames.silver) == 9,battle.ammo_frames.duplicate())
	_wait_ammo_clear(battle,"fire")
	_check("Q expiring fire leaves independent silver clock running",int(battle.ammo_frames.silver) > 9 and int(battle.ammo_frames.silver) <= 355)
	_wait_ammo_clear(battle,"silver")
	_check("Q both independent timers eventually clear",battle.ammo_frames == {"fire":1,"silver":1})

func _persistent_seed(enemy_x: float) -> Node2D:
	var battle := _fresh()
	battle.player.position = Vector2(132.4,314.9)
	battle.player.set_facing(1)
	var enemy: Node2D = battle.enemies[0]
	enemy.position = Vector2(enemy_x,361)
	enemy.hp = 2000 # Original probe's explicit numeric-resolution fixture.
	enemy.definition.max_hp = 2000
	enemy.vertical_speed = 0
	enemy.gravity_acceleration = 0
	enemy.airborne = false
	enemy.set_action("idle")
	return battle

func _original_states(source: Dictionary, case_id: String, first: int, last: int) -> Dictionary:
	var rows := {}
	for row: Dictionary in source.records:
		if row.record_type == "STATE" and row.get("tag","") == "tick" and row.get("case","") == case_id:
			rows[int(row.t)] = row
	var missing: Array[int] = []
	for tick in range(first,last+1):
		if not rows.has(tick):missing.append(tick)
	_check("original controlled "+case_id+" has complete compared ticks",missing.is_empty(),missing)
	return rows

func _report_source_differences(case_id: String, differences: Dictionary, samples: Array, extra: Dictionary = {}) -> void:
	for category: String in differences:
		_check("original controlled "+case_id+" per-tick "+category,differences[category].is_empty(),{"difference_count":differences[category].size(),"first_difference":differences[category][0] if not differences[category].is_empty() else null})
	var record := {"kind":"original_controlled_persistent_same_seed_actual_normal_skill_input","case":case_id,"seed_enemy_hp":2000,"samples":samples,"differences":differences}
	record.merge(extra)
	traces.append(record)

func _test_r_source_timeline(source: Dictionary) -> void:
	# The original probe directly seeks parent23 at130; here a real R event.
	# Its earlier Q clocks are not seeded: they do not affect these no-contact
	# fields. Their independent full clocks are already tested above.
	var states := _original_states(source,"R_with_independent_Q_timers",130,354)
	var battle := _persistent_seed(520)
	var samples: Array[Dictionary] = []
	var differences := {"player_root":[],"world_parent_child":[],"enemy":[]}
	var floor_instance := 0
	var retained := true
	var empty_birth := false
	for tick in range(130,355):
		if tick == 130:_press(battle,KEY_R)
		else:battle.step({})
		var actual := _sample(battle,tick)
		actual.root_x = battle.position.x
		actual.root_y = battle.position.y
		# An absent Godot derived object corresponds to the original empty
		# stopped1513 frame1. No absent child is invented or compared as present.
		actual.floor = 1
		for item: Dictionary in battle.summons:
			if item.kind != "fire_floor":continue
			actual.floor = int(item.frame)
			actual.floor_x = item.visual.position.x
			actual.floor_y = item.visual.position.y
			actual.floor_depth = int(item.depth)
			if int(item.frame) >= 2:actual.r1503 = item.visual.source_frame
			if floor_instance == 0:floor_instance = item.visual.get_instance_id()
			retained = retained and floor_instance == item.visual.get_instance_id()
			if tick == 154:empty_birth = not item.visual.visible
		samples.append(actual)
		if not states.has(tick):continue
		var expected: Dictionary = states[tick]
		differences.player_root.append_array(_differences(actual,expected,["actor","action","px","py","root_x","root_y"]))
		var world_fields: Array = ["floor","r1503"]
		if expected.floor is float and float(expected.floor) >= 2:world_fields.append_array(["floor_x","floor_y","floor_depth"])
		differences.world_parent_child.append_array(_differences(actual,expected,world_fields))
		differences.enemy.append_array(_differences(actual,expected,["ex","ey","ehp","g","gacc","outer"]))
	_report_source_differences("R_with_independent_Q_timers",differences,samples,{"phase_boundary":"R actual key replaces original direct parent23 seek. Earlier Q flags omitted only because this far-target sample has no contact. Removed Godot floor maps to original empty stopped1513 frame1;1502 is baked source display-list imagery, not separately claimed as a runtime child clock."})
	_check("R source1513 birth frame1 has no1503 image yet",empty_birth)
	_check("R holds same world instance across six observed29-tick wraps then releases",floor_instance != 0 and retained and battle.summons.is_empty() and battle.player.state == "idle")

func _test_c4_source_timeline(source: Dictionary) -> void:
	# Original355 seed and360/380/400/420 parent seeks. Actual E events use
	# the real count==3 branch and pay its own cost. Original MP/CD bypassed
	# by the probe is deliberately not compared with legal-input MP/CD.
	var states := _original_states(source,"C4_attach_detonate",355,459)
	var battle := _persistent_seed(175)
	var enemy: Node2D = battle.enemies[0]
	var samples: Array[Dictionary] = []
	var differences := {"actor_counter_container":[],"enemy_hp":[],"enemy_position":[],"enemy_physics":[],"attached_helpers":[]}
	var bombs_by_tick := {}
	for row: Dictionary in source.records:
		if row.record_type != "C4" or row.get("tag","") != "tick":continue
		var tick: int = row.t
		if not bombs_by_tick.has(tick):bombs_by_tick[tick] = []
		bombs_by_tick[tick].append(row)
	for tick in range(355,460):
		if tick > 355:
			if tick in [360,380,400,420]:_press(battle,KEY_E)
			else:battle.step({})
		var actual := _sample(battle,tick)
		actual.c4 = battle.c4_count
		var entry: Dictionary = battle.c4_targets.get(enemy.identifier,{})
		actual.c4container = int(entry.get("count",0))+1
		actual.charges = entry.get("charges",[]).duplicate(true)
		actual.air_marker_visible = enemy.air_hit_visual.visible
		actual.air_marker_frame = enemy.air_hit_visual.source_frame if enemy.air_hit_visual.visible else 0
		samples.append(actual)
		if not states.has(tick):continue
		var expected: Dictionary = states[tick]
		var actor_fields: Array = ["actor","action","px","py","c4","c4container"]
		# Original direct parent21 trace observes pre-load1; legal default E
		# processes load->3 on entry. Next tick4 and every later field compare.
		if tick in [360,380,400]:actor_fields.erase("action")
		differences.actor_counter_container.append_array(_differences(actual,expected,actor_fields))
		differences.enemy_hp.append_array(_differences(actual,expected,["ehp"]))
		differences.enemy_position.append_array(_differences(actual,expected,["ex","ey"]))
		differences.enemy_physics.append_array(_differences(actual,expected,["g","gacc","outer"]))
		if expected.marker is float and int(expected.marker) in range(1,8):
			if not actual.air_marker_visible or int(actual.air_marker_frame) != int(expected.marker):differences.attached_helpers.append({"field":"visible_air_marker","source_tick":tick,"actual":actual.air_marker_frame,"expected":expected.marker,"raw_line":expected.raw_line})
		if bombs_by_tick.has(tick):
			var rows: Array = bombs_by_tick[tick]
			if actual.charges.size() != rows.size():
				differences.attached_helpers.append({"field":"attached_count","source_tick":tick,"actual":actual.charges.size(),"expected":rows.size(),"raw_line":rows[0].raw_line})
			else:
				for i in range(rows.size()):
					var charge: Dictionary = actual.charges[i]
					var wanted: Dictionary = rows[i]
					#1140 helper stops empty at3; explosion art has a separate
					#9-frame clock. Compare helper creation/active2, not art age
					#as though it were the removed hit shape's source frame.
					if wanted.hit is float and int(wanted.hit) in [1,2] and int(charge.explosion) != int(wanted.hit):differences.attached_helpers.append({"field":"explosion_helper_birth_or_active","source_tick":tick,"charge":i,"actual":charge.explosion,"expected":wanted.hit,"raw_line":wanted.raw_line})
					if wanted.flash is float and int(charge.blink) != int(wanted.flash):differences.attached_helpers.append({"field":"flash","source_tick":tick,"charge":i,"actual":charge.blink,"expected":wanted.flash,"raw_line":wanted.raw_line})
	_report_source_differences("C4_attach_detonate",differences,samples,{"phase_boundary":"Original first parent21 preload1 excluded only at360/380/400; normal E starts3, subsequent4..13 all compared. Actual detonation selects from count3 and pays7MP/1cube, unlike original direct parent22 probe. All source HP/position/physics ticks retained."})
	_check("C4 three actual attachments and detonation consume one cube and clean all logical/view parts",_events(battle,"c4_attached").size() == 3 and int(battle.session.profile.progress.clear_cubes) == 199 and battle.c4_targets.is_empty() and battle._c4_views.is_empty() and battle.c4_count == 0 and battle.player.state == "idle",{"attached":_events(battle,"c4_attached"),"clear_cubes":battle.session.profile.progress.clear_cubes})

func _test_r_c4_input_gates() -> void:
	# Static original4074/4076 gates; these are not new dynamic Flash samples.
	for spec: Array in [[KEY_R,11.95,200,"R MP below12"],[KEY_R,130.0,0,"R missing cube"],[KEY_E,6.95,200,"E placement still needs MP7"]]:
		var battle := _isolated()
		battle.player.mp = spec[1]
		battle.session.profile.progress.clear_cubes = spec[2]
		_press(battle,spec[0])
		_check("source gate rejects "+str(spec[3]),battle.player.state == "idle" and battle.summons.is_empty() and battle.c4_count == 0 and battle.session.profile.progress.clear_cubes == spec[2])
	var battle := _isolated()
	_press(battle,KEY_R)
	_check("R legal key spends12MP and1cube and starts660-frame source slot",battle.player.state == "skill_r" and battle.player.source_frame == 1 and _near(battle.player.mp,118.05) and battle.session.profile.progress.clear_cubes == 199 and battle.player.cooldowns.skill_r == 659)
	battle = _isolated()
	for placement in range(3):
		_press(battle,KEY_E)
		for tick in range(10):battle.step({})
	_check("three E misses still advance root count without inventory refund or MP spend",battle.c4_count == 3 and battle.c4_targets.is_empty() and _near(battle.player.mp,130) and battle.session.profile.progress.clear_cubes == 200 and battle.player.state == "idle")
	battle.session.profile.progress.clear_cubes = 0
	_press(battle,KEY_E)
	_check("count3 detonation requires cube and failure preserves all three misses",battle.c4_count == 3 and battle.player.state == "idle" and _near(battle.player.mp,130))
	battle.session.profile.progress.clear_cubes = 1
	_press(battle,KEY_E)
	_check("count3 empty detonation is legal and pays7MP and1cube",battle.player.state == "detonate" and _near(battle.player.mp,123.05) and battle.session.profile.progress.clear_cubes == 0 and battle.player.cooldowns.skill_e == 359)

func _finish() -> void:
	var failures := checks.filter(func(row:Dictionary)->bool:return not row.passed).size()
	var output := OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if output.is_empty():output = EVIDENCE_DIR+"stage_b"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var file := FileAccess.open(output.path_join("act02_skills_tests.json"),FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"suite":"act02_skills","checks":checks,"failures":failures,"evidence":evidence,"traces":traces,"scope":"Actual InputMap key-event dispatch/Main/Battle with isolated save, headless Dummy. Original independent controlled probes for A/W world timelines, F inventory, Q timers, R far-target world clock and three same-target C4 attachments/detonation; other gates and grenade geometry branches from original AS2/XML. Artificial seeds/no-contact positions explicitly labelled. Not OS input/native Flash/full default skill or Q bullet effect completion; R contact damage and multi-target C4 need separate coverage."},"\t")+"\n")
		file.close()
	print("ACT02_SKILLS_TESTS_RESULT "+JSON.stringify({"checks":checks.size(),"failures":failures}))
	quit(0 if failures == 0 else 1)


func _test_c4_thaw_source_branch() -> void:
	# Static3916 frozen-inner5 then normal-return records, actual E placement.
	# Not a dynamically matched frozen-C4 original sample or a total-damage claim.
	var battle := _fresh()
	var enemy: Node2D = battle.enemies[0]
	enemy.position = Vector2(175.8,360.15)
	enemy.hp = 2000.0
	enemy.definition.max_hp = 2000.0
	for i in range(3):
		_press(battle,KEY_E)
		for tick in range(15):battle.step({})
	_check("C4 thaw fixture places three real charges before explicit freeze",battle.c4_targets.has(enemy.identifier) and battle.c4_targets[enemy.identifier].count == 3 and battle.c4_count == 3)
	battle._freeze_target(enemy)
	_press(battle,KEY_E)
	for tick in range(13):battle.step({})
	_check("source3916 frozen contact removes freeze and resumes normal/air branch",not enemy.frozen and battle.player.state == "detonate" and battle.c4_targets[enemy.identifier].exploding and not is_instance_valid(enemy.frozen_visual),{"source_frame":battle.player.source_frame,"air":enemy.airborne,"gacc":enemy.gravity_acceleration,"hp":enemy.hp})
