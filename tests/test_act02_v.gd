extends SceneTree
## Actual Main -> training -> InputMap V event, with independent original V oracle.
## Original probe entered parent98 directly: it did NOT test input/MP/cooldown.
## Here those gates execute normally; source comparison excludes MP/CD, then
## independently checks the confirmed5MP/218-page(slot217 remaining) contract.
## No source row is copied into runtime after the explicit baseline seed.
## Run only in Root's coordinated window, headless + Dummy + --test-mode.
const MainScene = preload("res://scenes/main.tscn")
const SaveStore = preload("res://scripts/services/save_store.gd")
const ORACLE_PATH := "res://artifacts/leba_act02_20261115/v_probe.json"
const GODOT_SEED := 20261115
const EPSILON := 0.0001 # float32 storage tolerance, smaller than one0.05px twip.
var app: Node
var checks: Array[Dictionary] = []
var traces: Array[Dictionary] = []
var evidence: Dictionary = {}
var formal_exists := false
var formal_hash := ""

func _initialize() -> void:call_deferred("_run")

func _check(label: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"name":label,"passed":passed,"detail":detail})
	print(("PASS " if passed else "FAIL ")+label+" "+str(detail))

func _number(value: Variant) -> bool:return value is int or value is float

func _near(a: float, b: float) -> bool:return absf(a-b)<=EPSILON

func _load_source() -> Dictionary:
	if not FileAccess.file_exists(ORACLE_PATH):
		_check("original V oracle exists",false,ORACLE_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ORACLE_PATH))
	if not parsed is Dictionary:
		_check("original V oracle JSON parses",false)
		return {}
	var source: Dictionary = parsed
	var complete: bool = source.get("integrity",{}).get("ok",false) and int(source.get("finish",{}).get("failures",-1))==0
	_check("independent V raw probe completed its declared cases",complete,source.get("integrity",{}))
	evidence = {"path":ORACLE_PATH,"json_sha256":FileAccess.get_sha256(ORACLE_PATH),
		"original_log":source.get("log"),"log_sha256":source.get("sha256"),
		"evidence_class":source.get("evidence_class"),"limits":source.get("limits",[]),
		"derived_swf_sha256":source.get("launch",{}).get("movie_sha256")}
	# v1's raw first651 means depth137, including an early non651 visual. Never
	# accept that field as an event oracle; parser keeps it and adds XML resolution.
	var first: Dictionary = source.get("verified_first651",{})
	_check("first actual651 is XML-verified source26, not raw depth137 presence",int(first.get("t",-1))==59 and int(first.get("action",-1))==26 and int(first.get("verified_source_id",-1))==651,first)
	return source if complete else {}

func _fresh() -> Node2D:
	seed(GODOT_SEED) # deterministic Godot replay, not a claim of matching Flash PRNG.
	app.action_lab = false
	app.session.profile = app.saves.default_profile()
	app.session.select_character("crt_0")
	app.session.select_difficulty("expert")
	app._on_intent("select_training_character","crt_0")
	var battle: Node2D = app.battle
	battle.set_physics_process(false)
	battle.manual_clock = true
	battle.step({}) # original4112 initialization before fixture baseline.
	return battle

func _seed_case(battle: Node2D, enemy_x: float) -> void:
	# Same intervention as original fixture: HP2000 instead of training1e22,
	# player132.4/314.9 right, enemy_y361, ground/idle/g0/gacc0.
	# Fresh Battle supplies clean zab/pren; tests never manufacture capture results.
	battle.player.position = Vector2(132.4,314.9)
	battle.player.set_facing(1)
	var enemy: Node2D = battle.enemies[0]
	enemy.position = Vector2(enemy_x,361)
	enemy.hp = 2000.0
	enemy.definition.max_hp = 2000.0
	enemy.vertical_speed = 0.0
	enemy.gravity_acceleration = 0.0
	enemy.airborne = false
	enemy.set_action("idle")

func _press_v(battle: Node2D) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_V
	event.physical_keycode = KEY_V
	event.pressed = true
	battle._unhandled_input(event) # real registered InputMap and shared dispatch.
	battle.step(battle.take_commands())
	event.pressed = false
	battle._unhandled_input(event)

func _zab_number(battle: Node2D, identifier: Variant) -> Variant:
	if not identifier is String:return null
	if str(identifier).is_empty():return 0
	for index in range(battle.enemies.size()):
		if battle.enemies[index].identifier==identifier:return index+1
	return -1 # invalid target id is a visible mismatch, not silently no capture.

func _sample(battle: Node2D, source_tick: int) -> Dictionary:
	var enemy: Node2D = battle.enemies[0]
	var snap: Dictionary = battle.snapshot()
	var v: Dictionary = snap.get("v",{})
	var result := {"t":source_tick,"actor":battle.player.parent_frame,
		"action":battle.player.source_frame if battle.player.state=="skill_v" else "undefined",
		"px":battle.player.position.x,"py":battle.player.position.y,
		"player_sx":battle.player.visual_scale.x*100.0,
		"child_x":battle.player.action_child_x if battle.player.state=="skill_v" else "undefined",
		"zab_raw":battle.get("zab"),"zab":_zab_number(battle,battle.get("zab")),"pren":battle.get("pren"),
		"ex":enemy.position.x,"ey":enemy.position.y,"ehp":enemy.hp,
		"outer":2 if enemy.airborne else 1,"g":enemy.vertical_speed,"gacc":enemy.gravity_acceleration,
		"mp":battle.player.mp,"cooldown":battle.player.cooldowns.get("skill_v",0),
		"anchor_active":v.get("anchor_active",null),"v_diagnostic":v.duplicate(true)}
	# These must be values recorded by the REAL V execution branch. Do not rebuild
	# them here from asset metadata merely to agree with the source oracle.
	var child: Variant = v.get("child",null)
	if child is Array and child.size()==2:
		result["child_x"] = child[0]
		result["child_y"] = child[1]
	var anchor: Variant = v.get("anchor_local",null)
	if anchor is Array and anchor.size()==2:
		result["anchor_x"] = anchor[0]
		result["anchor_y"] = anchor[1]
	var formula: Variant = v.get("formula",null)
	if formula is Array and formula.size()==2:
		result["formula_x"] = formula[0]
		result["formula_y"] = formula[1]
	return result

func _differences(actual: Dictionary, expected: Dictionary, fields: Array) -> Array:
	var diffs: Array = []
	for field: String in fields:
		var want: Variant = expected.get(field)
		var got: Variant = actual.get(field)
		var equal: bool = _number(want) and _number(got) and _near(float(want),float(got))
		if want is bool:equal = got is bool and got==want
		if want is String:equal = got is String and got==want
		if not equal:
			diffs.append({"source_tick":expected.t,"raw_line":expected.raw_line,"field":field,"expected":want,"actual":got})
	return diffs

func _test_case(source: Dictionary, case_id: String, seed_tick: int, input_tick: int, last_tick: int, enemy_x: float) -> void:
	var oracle := {}
	for row: Dictionary in source.records:
		if row.record_type=="STATE" and row.get("tag")=="tick" and row.get("case")==case_id:
			oracle[int(row.t)] = row
	var missing: Array[int] = []
	for tick in range(seed_tick,last_tick+1):
		if not oracle.has(tick):missing.append(tick)
	_check(case_id+" oracle covers every compared tick",missing.is_empty(),missing)
	if not missing.is_empty():return
	var battle := _fresh()
	_check(case_id+" starts actual Main training",app.screen=="battle" and battle.is_training() and battle.player.definition.source_crt==0 and battle.enemies.size()==1)
	_seed_case(battle,enemy_x)
	var differences := {"source":[],"position":[],"hp":[],"physics":[],"capture_state":[],"anchor":[]}
	var samples: Array[Dictionary] = []
	var input_result := {}
	var anchor_rows := 0
	for tick in range(seed_tick,last_tick+1):
		if tick>seed_tick:
			if tick==input_tick:_press_v(battle)
			else:battle.step({})
		var actual := _sample(battle,tick)
		var expected: Dictionary = oracle[tick]
		samples.append(actual)
		if tick==input_tick:input_result = actual.duplicate(true)
		differences.source.append_array(_differences(actual,expected,["actor","action","px","py"]))
		differences.position.append_array(_differences(actual,expected,["ex","ey"]))
		differences.hp.append_array(_differences(actual,expected,["ehp"]))
		differences.physics.append_array(_differences(actual,expected,["g","gacc","outer"]))
		differences.capture_state.append_array(_differences(actual,expected,["zab","pren"]))
		if expected.anchor_active and int(expected.action)>=16:
			anchor_rows += 1
			differences.anchor.append_array(_differences(actual,expected,["anchor_active","child_x","child_y","anchor_x","anchor_y","formula_x","formula_y"]))
		elif expected.anchor_active and int(expected.action)==15:
			# Probe anchor_active means the5652 exists, while snapshot.v reports
			# whether its enterFrame assignment ran. Source15 creates the node;
			# its first callback is16. Keep all actual position/zab/pren fields
			# above exact, and check this distinct diagnostic meaning explicitly.
			if actual.anchor_active!=false:
				differences.anchor.append({"source_tick":tick,"raw_line":expected.raw_line,"field":"new_anchor_has_not_run_callback","expected":false,"actual":actual.anchor_active})
			differences.anchor.append_array(_differences(actual,expected,["child_x","child_y"]))
		elif actual.anchor_active==true:
			differences.anchor.append({"source_tick":tick,"raw_line":expected.raw_line,"field":"anchor_active","expected":false,"actual":true})
	for category: String in differences:
		_check(case_id+" original per-tick "+category,differences[category].is_empty(),{"count":differences[category].size(),"first":differences[category][0] if not differences[category].is_empty() else null})
	_check(case_id+" actual V input pays5MP and begins217 remaining ticks",not input_result.is_empty() and input_result.actor==98 and input_result.action==1 and _near(float(input_result.mp),125.05) and int(input_result.cooldown)==217,input_result)
	if case_id=="capture_success_attempt":
		_check("successful V compared actual runtime anchor samples",anchor_rows>0 and differences.anchor.is_empty(),{"oracle_anchor_rows":anchor_rows})
		_check("V source has post-return damage tail",oracle[104].actor==1 and oracle[104].ehp==1815 and oracle[105].ehp==1805,{"source104":oracle[104],"source105":oracle[105]})
	else:
		_check("empty V never creates active capture anchor",anchor_rows==0 and samples.all(func(r:Dictionary)->bool:return r.zab==0 and r.pren==0 and r.anchor_active!=true))
	_check(case_id+" original action naturally clears capture and returns",battle.player.state=="idle" and battle.get("zab")=="" and battle.get("pren")==0,battle.snapshot())
	traces.append({"case":case_id,"godot_seed":GODOT_SEED,"fixture":{"enemy_x":enemy_x,"enemy_y":361,"enemy_hp":2000,"player":[132.4,314.9],"facing":1,"seed_tick":seed_tick,"input_tick":input_tick},
		"source_phase":"observer_before_remaining_callbacks","godot_phase":"after complete Battle.step",
		"phase_policy":"No post-hoc tick shifting or source-value injection. Probe anchor_active means5652 exists; runtime diagnostic means callback ran: source15 must have no assignment, source16..67 compare recorded real anchor/formula. Actor/HP/physics/positions/zab/pren remain exact on every tick.",
		"input_difference":"Original direct parent98 seek bypassed input/MP/CD. Actual InputMap V is used here; MP/CD assertions use separately confirmed source gates.",
		"samples":samples,"differences":differences,"events":battle.journal.duplicate(true)})

func _run() -> void:
	formal_exists = FileAccess.file_exists("user://profile.json")
	if formal_exists:formal_hash = FileAccess.get_sha256("user://profile.json")
	app = MainScene.instantiate()
	root.add_child(app)
	_check("V suite uses actual Main isolated test startup",app.startup_ok and app.test_mode)
	if not app.startup_ok:
		_finish()
		return
	app.saves = SaveStore.new("user://act02_v/run_%d_%d/profile.json" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()])
	var source := _load_source()
	if not source.is_empty():
		_test_case(source,"capture_success_attempt",40,42,145,185.0)
		_test_case(source,"empty_attempt",150,160,240,550.0)
	_check("V fixtures preserve formal save existence and hash",FileAccess.file_exists("user://profile.json")==formal_exists and (not formal_exists or FileAccess.get_sha256("user://profile.json")==formal_hash))
	app._dispose_battle()
	var drained: bool = await app.audio.stop_and_drain(1.0)
	_check("V Dummy audio releases playback references",drained and app.audio.snapshot().pending_playbacks==0)
	app.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	var failures := checks.filter(func(row:Dictionary)->bool:return not row.passed).size()
	var output := OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if output.is_empty():output = "res://artifacts/leba_act02_20261115/v_regression"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var file := FileAccess.open(output.path_join("act02_v_tests.json"),FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify({"suite":"act02_v","checks":checks,"failures":failures,"evidence":evidence,"traces":traces,
			"scope":"Actual Main training and InputMap key dispatch, headless Dummy, against independent controlled original V success/empty traces. Explicit HP/position seed, deterministic Godot RNG only. Not OS keyboard/native Flash/multi-target/armor/frozen/reverse/interrupt acceptance."},"\t")+"\n")
		file.close()
	print("ACT02_V_TESTS_RESULT "+JSON.stringify({"checks":checks.size(),"failures":failures}))
	quit(0 if failures==0 else 1)
