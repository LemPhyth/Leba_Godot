extends SceneTree
## Original status_v2 is a read-only oracle, never runtime data.
## Actual H/Q key dispatch; root1474 uses a labelled fixed real-Actor emitter.
const MainScene = preload("res://scenes/main.tscn")
const SaveStore = preload("res://scripts/services/save_store.gd")
const SOURCE := "res://artifacts/leba_act02_20261115/status_v2_probe.json"
var app: Node
var checks: Array[Dictionary] = []
var traces: Array[Dictionary] = []
var source: Dictionary = {}
var formal_exists := false
var formal_hash := ""

func _initialize() -> void:call_deferred("_run")

func _check(name_: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"name":name_,"passed":passed,"detail":detail})
	print(("PASS " if passed else "FAIL ")+name_+" "+str(detail))

func _press(battle: Node2D, code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	battle._unhandled_input(event)
	battle.step(battle.take_commands())

func _fresh() -> Node2D:
	app.action_lab = false
	app.session.profile = app.saves.default_profile()
	app.session.select_difficulty("expert")
	app._on_intent("select_training_character","crt_0")
	var battle: Node2D = app.battle
	battle.set_physics_process(false)
	battle.manual_clock = true
	battle.step({}) # Complete4112 initialization before actual skill gates.
	return battle

func _seed(battle: Node2D, enemy_x: float) -> void:
	battle.player.position = Vector2(132.4,314.9)
	battle.player.set_facing(1)
	var enemy: Node2D = battle.enemies[0]
	enemy.position = Vector2(enemy_x,361)
	enemy.hp = 2000 # Original fixture's numeric resolution, never training balance.
	enemy.definition.max_hp = 2000
	enemy.vertical_speed = 0
	enemy.gravity_acceleration = 0
	enemy.airborne = false
	enemy.set_action("idle")

func _spawn_original_root_bullet_fixture(battle: Node2D, at: Vector2) -> void:
	# Original probe explicitly attaches1474 at the world root with scale1.
	# Use the real shared Combatant as a stationary emitter; never move the
	# actual player, replace collision logic, force a hit or feed recorded poses.
	var emitter: Node2D = battle._make_actor("OriginalRoot1474Fixture","player",app.database.characters.crt_0,at,Vector2.ONE)
	emitter.visible = false
	battle._spawn_projectile(emitter,{"projectile":"projectile","gravity":-5.0})
	_check("fixed root1474 fixture uses real sharedActor and unscaled projectile",emitter.get_script() == battle.player.get_script() and emitter.position == at and battle.projectiles[-1].scale == Vector2.ONE and battle.player.position == Vector2(132.4,314.9))

func _sample(battle: Node2D, tick: int) -> Dictionary:
	var enemy: Node2D = battle.enemies[0]
	var status: Dictionary = battle.enemy_status.get(enemy.identifier,{})
	var result := {"t":tick,"actor":battle.player.parent_frame,"action":battle.player.source_frame,"px":battle.player.position.x,"py":battle.player.position.y,"ehp":enemy.hp,"ex":enemy.position.x,"ey":enemy.position.y,"g":enemy.vertical_speed,"gacc":enemy.gravity_acceleration,"outer":2 if enemy.airborne else 1,"enemy":enemy.source_frame if enemy.frozen else enemy.parent_frame,"frozen":enemy.frozen,"ice":enemy.freeze_frame if enemy.frozen else 0,"inner":enemy.freeze_hit_frame if enemy.frozen else 0,"air_marker":enemy.air_hit_visual.source_frame if enemy.air_hit_visual.visible else 0,"skull":int(status.get("silver",{}).get("frame",1)),"silver_present":status.has("silver"),"silver_timer":battle.ammo_frames.silver}
	if not battle.projectiles.is_empty():
		var bullet: Dictionary = battle.projectiles[0]
		result.bullet = {"frame":bullet.visual.source_frame,"x":bullet.visual.position.x,"y":bullet.visual.position.y,"hita":1 if bullet.targets.has(enemy.identifier) else 0}
	return result

func _states(first: int, last: int) -> Dictionary:
	var result := {}
	for row: Dictionary in source.records:
		if row.record_type == "STATE" and row.get("tag","") == "tick":result[int(row.t)] = row
	var missing: Array[int] = []
	for tick in range(first,last+1):
		if not result.has(tick):missing.append(tick)
	_check("independent status_v2 has complete source ticks%d..%d" % [first,last],missing.is_empty(),missing)
	return result

func _compare(actual: Dictionary, expected: Dictionary, fields: Array) -> Array:
	var differences: Array = []
	for key: String in fields:
		var wanted: Variant = expected[key]
		if not wanted is float and not wanted is int:continue
		if not actual.has(key) or absf(float(actual[key])-float(wanted)) > 0.0001:
			differences.append({"field":key,"actual":actual.get(key),"expected":wanted,"source_tick":int(expected.t),"raw_line":int(expected.raw_line)})
	return differences

func _compare_status(actual: Dictionary, expected: Dictionary, differences: Dictionary) -> void:
	differences.enemy_hp.append_array(_compare(actual,expected,["ehp"]))
	differences.enemy_position.append_array(_compare(actual,expected,["ex","ey"]))
	differences.enemy_state.append_array(_compare(actual,expected,["g","gacc","outer","enemy"]))
	differences.status_clocks.append_array(_compare(actual,expected,["ice","inner","skull","air_marker"]))
	for pair: Array in [["frozen","ice"],["silver_present","silver"]]:
		var present: bool = expected[pair[1]] is float or expected[pair[1]] is int
		if bool(actual[pair[0]]) != present:differences.status_clocks.append({"field":pair[0],"actual":actual[pair[0]],"expected":present,"source_tick":int(expected.t),"raw_line":int(expected.raw_line)})
	if expected.air_marker is String and expected.air_marker == "undefined" and int(actual.air_marker) != 0:
		differences.status_clocks.append({"field":"removed_air_marker_still_visible","actual":actual.air_marker,"expected":"absent","source_tick":int(expected.t),"raw_line":int(expected.raw_line)})

func _compare_bullet(battle: Node2D, tick: int, actual: Dictionary, differences: Dictionary) -> void:
	var row: Dictionary = {}
	for candidate: Dictionary in source.records:
		if candidate.record_type == "BULLET" and int(candidate.t) == tick:row = candidate
	if row.is_empty() or int(row.frame) >= 11:return # Original inert11 -> Godot release.
	if not actual.has("bullet"):
		differences.projectile.append({"field":"bullet_exists","actual":false,"expected":true,"source_tick":tick,"raw_line":row.raw_line})
		return
	row["t"] = tick
	differences.projectile.append_array(_compare(actual.bullet,row,["frame","x","y","hita"]))
	if int(actual.bullet.hita) > 0 and not battle.enemies[0].frozen and bool(actual.silver_present):
		actual["silver_collision_confirmed"] = true

func _report(case_id: String, differences: Dictionary, samples: Array, extra: Dictionary = {}) -> void:
	for kind: String in differences:
		_check("original controlled "+case_id+" per-tick "+kind,differences[kind].is_empty(),{"difference_count":differences[kind].size(),"first_difference":differences[kind][0] if not differences[kind].is_empty() else null})
	var row := {"case":case_id,"samples":samples,"differences":differences}
	row.merge(extra)
	traces.append(row)

func _test_h_and_frozen_bullet() -> void:
	var battle := _fresh()
	battle.enemies[0].position = Vector2(550,1000)
	_press(battle,KEY_H)
	for tick in range(14):battle.step({})
	_check("H source-case starts from a real completed3-round load",battle.grenades.h.stock == 3 and battle.player.state == "idle")
	_seed(battle,340)
	var enemy: Node2D = battle.enemies[0]
	var expected := _states(40,245)
	var samples: Array[Dictionary] = []
	var differences := {"player":[],"enemy_hp":[],"enemy_position":[],"enemy_state":[],"status_clocks":[],"projectile":[]}
	for tick in range(40,246):
		if tick > 40:
			if tick == 60:_press(battle,KEY_H)
			else:battle.step({})
		if tick == 110:
			_check("H naturally reached frozen state before original HP-only reset",enemy.frozen and enemy.freeze_frame == 39 and is_equal_approx(enemy.hp,1955.0))
			enemy.hp = 2000 # Same original v2 intervention; no ice clock reset.
		if tick == 120:_spawn_original_root_bullet_fixture(battle,Vector2(154.05,319.05))
		var actual := _sample(battle,tick)
		samples.append(actual)
		if not expected.has(tick):continue
		var fields: Array = ["actor","action","px","py"]
		if tick == 60:fields.erase("action") # Original direct parent19 preload1 vs legal H5.
		differences.player.append_array(_compare(actual,expected[tick],fields))
		_compare_status(actual,expected[tick],differences)
		_compare_bullet(battle,tick,actual,differences)
	_report("H_natural94_then_root1474_frozen_hit",differences,samples,{"fixture":"Real H load then explicit source40 seed340/361/HP2000, actual H at60. At110 only HP reset2000 as original. At120 real sharedActor emitter at original root1474 coordinates154.05/319.05 with scale1. Source initial parent19 preload1 excluded only at60; no later expected state is fed into runtime."})
	_check("H and frozen projectile finish with1995HP no air marker or silver observer",is_equal_approx(enemy.hp,1995) and not enemy.frozen and not enemy.airborne and not battle.enemy_status.get(enemy.identifier,{}).has("silver") and battle._markers.is_empty())
	_check("actual H contact consumed exactly one loaded round",battle.grenades.h.stock == 2)

func _test_q_silver_bullet() -> void:
	var battle := _fresh()
	_seed(battle,250)
	var enemy: Node2D = battle.enemies[0]
	var expected := _states(320,409)
	var samples: Array[Dictionary] = []
	var differences := {"player":[],"enemy_hp":[],"enemy_position":[],"enemy_state":[],"status_clocks":[],"projectile":[]}
	for tick in range(320,410):
		if tick > 320:
			if tick == 330:_press(battle,KEY_Q)
			elif tick == 340:_press(battle,KEY_DOWN)
			else:battle.step({})
		if tick == 355:
			_check("original silver projectile fixture follows actual Q choice and live timer",int(battle.ammo_frames.silver) >= 9 and int(battle.ammo_frames.silver) <= 355 and battle.ammo_frames.fire == 1)
			_spawn_original_root_bullet_fixture(battle,Vector2(102.15,319.05))
		var actual := _sample(battle,tick)
		samples.append(actual)
		if not expected.has(tick):continue
		differences.player.append_array(_compare(actual,expected[tick],["actor","action","px","py"]))
		_compare_status(actual,expected[tick],differences)
		# At direct choice340 the observer sees timer1 before the queued
		# original22 action starts2. Next tick341.. is the common semantic phase.
		if tick != 340:differences.status_clocks.append_array(_compare(actual,expected[tick],["silver_timer"]))
		_compare_bullet(battle,tick,actual,differences)
	_report("Q_silver_root1474",differences,samples,{"fixture":"Actual Q and Down at330/340; original controlled source instead directly sought parent18/child22. Actual original-root1474 fixture emitter at102.15/319.05 scale1 at355. Only timer340 pre-callback snapshot excluded; later timers, HP, marker, physical and3991-lifetime rows all compared."})
	_check("silver actual projectile settles5plus13 then10 and expires only its3991 observer",is_equal_approx(enemy.hp,1972.0) and not battle.enemy_status.get(enemy.identifier,{}).has("silver") and int(battle.ammo_frames.silver) > 9 and battle._markers.is_empty())

func _test_isolated_frozen_projectile() -> void:
	# Separate Godot component fixture from the continuous original H path.
	# One known source120 seed isolates projectile scheduling if H itself fails.
	var battle := _fresh()
	_seed(battle,282)
	var enemy: Node2D = battle.enemies[0]
	enemy.position.y = 360.15
	battle._freeze_target(enemy)
	enemy.freeze_frame = 49
	enemy.freeze_hit_frame = 1
	enemy.refresh_freeze()
	var expected := _states(120,130)
	var samples: Array[Dictionary] = []
	var differences := {"enemy_hp":[],"enemy_position":[],"enemy_state":[],"status_clocks":[],"projectile":[]}
	_spawn_original_root_bullet_fixture(battle,Vector2(154.05,319.05))
	for tick in range(120,131):
		if tick > 120:battle.step({})
		var actual := _sample(battle,tick)
		samples.append(actual)
		if not expected.has(tick):continue
		_compare_status(actual,expected[tick],differences)
		_compare_bullet(battle,tick,actual,differences)
	_report("isolated_original120_frozen_projectile_seed",differences,samples,{"fixture":"Godot component isolation uses real freeze API plus one initial outer49/inner1 seed corresponding to independently observed original120. The original v2 reached this state naturally from H; this independent Godot seed is not mislabelled as natural H or original keyboard evidence. No subsequent trajectory or damage is injected."})

func _run() -> void:
	formal_exists = FileAccess.file_exists("user://profile.json")
	if formal_exists:formal_hash = FileAccess.get_sha256("user://profile.json")
	source = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	_check("status_v2 original source has DONE and all22 coverage checks",bool(source.integrity.ok) and source.finish.failures == 0 and source.checks.size() == 22)
	app = MainScene.instantiate()
	root.add_child(app)
	app.set_process(false)
	_check("status suite starts actual isolated Main and source database",app.startup_ok and app.test_mode and app.action_lab)
	if not app.startup_ok:
		_finish()
		return
	app.saves = SaveStore.new("user://act02_status/run_%d_%d/profile.json" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()])
	_test_h_and_frozen_bullet()
	_test_isolated_frozen_projectile()
	_test_q_silver_bullet()
	_check("status tests preserve formal profile bytes and existence",FileAccess.file_exists("user://profile.json") == formal_exists and (not formal_exists or FileAccess.get_sha256("user://profile.json") == formal_hash))
	app._dispose_battle()
	var drained: bool = await app.audio.stop_and_drain(1.0)
	_check("status Dummy audio drains before releasing actual tree",drained and app.audio.snapshot().pending_playbacks == 0)
	app.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	var failures := checks.filter(func(row:Dictionary)->bool:return not row.passed).size()
	var output := OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if output.is_empty():output = "res://artifacts/leba_act02_20261115/status"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var file := FileAccess.open(output.path_join("act02_status_tests.json"),FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"suite":"act02_status","checks":checks,"failures":failures,"traces":traces,"source":{"path":SOURCE,"json_sha256":FileAccess.get_sha256(SOURCE),"log":source.get("log"),"log_sha256":source.get("sha256")},"scope":"Actual H/Q key-event path and shared runtime projectile collisions, headless Dummy. Compared independent original controlled H94, continued H freeze+HP-only reset and original-root1474 fixture, Q silver clock/status28 chain. Fixed realActor emitters match probe root scale/position; not natural player muzzle or OS input/native Flash. Other H branches/multi-target/status combinations and T remain outside this suite."},"\t")+"\n")
		file.close()
	print("ACT02_STATUS_TESTS_RESULT "+JSON.stringify({"checks":checks.size(),"failures":failures}))
	quit(0 if failures == 0 else 1)
