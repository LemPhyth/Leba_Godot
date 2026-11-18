extends SceneTree
## Actual Main training / InputMap T. One-shot uses independent original probe.
## Six shots, timer, held/repeated input and wall assertions are STATIC SOURCE
## contract tests, not unperformed original/natural-keyboard acceptance.
const MainScene = preload("res://scenes/main.tscn")
const SaveStore = preload("res://scripts/services/save_store.gd")
const Actor = preload("res://scripts/combat/combatant.gd")
const ORACLE := "res://artifacts/leba_act02_20261115/status_v2_probe.json"
var app: Node
var checks: Array[Dictionary] = []
var traces: Array[Dictionary] = []
var evidence := {}
var formal_exists := false
var formal_hash := ""

func _initialize() -> void:call_deferred("_run")

func _check(label: String, passed: bool, detail: Variant = "", basis := "static_source_contract") -> void:
	checks.append({"name":label,"passed":passed,"basis":basis,"detail":detail})
	print(("PASS " if passed else "FAIL ")+label+" "+str(detail))

func _fresh(enemy_x := 550.0) -> Node2D:
	seed(20261115) # deterministic Godot stream only; no Flash PRNG equivalence.
	app.action_lab = false
	app.session.profile = app.saves.default_profile()
	app.session.select_character("crt_0")
	app.session.select_difficulty("expert")
	app._on_intent("select_training_character","crt_0")
	var b: Node2D = app.battle
	b.set_physics_process(false)
	b.manual_clock = true
	b.step({})
	b.player.position = Vector2(132.4,314.9)
	b.player.set_facing(1)
	var e: Node2D = b.enemies[0]
	e.position = Vector2(enemy_x,361)
	e.hp = 2000.0
	e.definition.max_hp = 2000.0
	e.vertical_speed = 0.0
	e.gravity_acceleration = 0.0
	e.airborne = false
	e.set_action("idle")
	return b

func _key(b: Node2D, code: Key = KEY_T, echo := false) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	e.echo = echo
	b._unhandled_input(e)
	b.step(b.take_commands())
	e.pressed = false
	e.echo = false
	b._unhandled_input(e)

func _ready_t(b: Node2D) -> bool:
	_key(b)
	for i in range(15):
		if int(b.sniper.root)==6:return true
		b.step({})
	return false

func _sample(b: Node2D, tick: int) -> Dictionary:
	var e: Node2D = b.enemies[0]
	var status: Dictionary = b.enemy_status.get(e.identifier,{})
	return {"t":tick,"actor":b.player.parent_frame,"player_source":b.player.source_frame,
		"px":b.player.position.x,"py":b.player.position.y,"ex":e.position.x,"ey":e.position.y,
		# Original STATE.enemy is4030.속(3898), not its independent walk sprite.
		"ehp":e.hp,"enemy":e.parent_frame,"enemy_child_source":e.source_frame,"outer":2 if e.airborne else 1,
		"g":e.vertical_speed,"gacc":e.gravity_acceleration,"sniper_root":b.sniper.root,
		"sniper":b.sniper.reticle if int(b.sniper.root)==6 else "undefined",
		"sniper_marker":status.get("sniper_hit",{}).get("frame",1),"stun":status.get("stun",{}).get("frame",1),
		"local":[b.sniper.local.x,b.sniper.local.y],"ammo":b.sniper.ammo,"timer":b.sniper.timer,
		"mp":b.player.mp,"cubes":b.session.profile.progress.clear_cubes,
		"cooldown":b.player.cooldowns.get("skill_t",0)}

func _load_oracle() -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(ORACLE))
	if not value is Dictionary:
		_check("independent status v2 JSON parses",false,ORACLE,"original_controlled_probe")
		return {}
	var valid: bool = value.get("integrity",{}).get("ok",false) and int(value.get("finish",{}).get("failures",-1))==0
	_check("independent status v2 completed declared cases",valid,value.get("integrity",{}),"original_controlled_probe")
	evidence = {"path":ORACLE,"sha256":FileAccess.get_sha256(ORACLE),"original_log":value.get("log"),"log_sha256":value.get("sha256"),"limits":value.get("limits",[])}
	return value if valid else {}

func _one_shot(source: Dictionary) -> void:
	var rows := {}
	for row: Dictionary in source.records:
		if row.record_type=="STATE" and row.get("tag")=="tick" and row.get("case")=="T_one_original_shot":rows[int(row.t)] = row
	var missing: Array = []
	for tick in range(410,451):
		if not rows.has(tick):missing.append(tick)
	_check("original one-shot oracle covers410..450",missing.is_empty(),missing,"original_controlled_probe")
	if not missing.is_empty():return
	var b := _fresh(250.0)
	var samples: Array = []
	var differences := {"source":[],"position":[],"hp":[],"physics":[],"status":[]}
	var fields := {"source":["actor","sniper_root","sniper"],"position":["px","py","ex","ey"],"hp":["ehp"],"physics":["g","gacc","outer"],"status":["enemy","sniper_marker","stun"]}
	for tick in range(410,451):
		if tick==420:_key(b)
		elif tick==435:
			# Same explicit intervention as source fixture: aim at live source body
			# center once. Source directly sought shot2; here real key event fires it.
			var target: Rect2 = b.enemies[0].hurt_rect()
			var m: Array = b.database.assets.source_geometry.sniper.root_matrix
			var transform := Transform2D(Vector2(m[0],m[1]),Vector2(m[2],m[3]),Vector2(m[4],m[5]))
			var local: Vector2 = transform.affine_inverse()*(target.position+target.size/2)
			b.sniper.local = Vector2(Actor.twips(local.x),Actor.twips(local.y))
			_key(b)
		elif tick>410:b.step({})
		var actual := _sample(b,tick)
		samples.append(actual)
		var expected: Dictionary = rows[tick]
		for category: String in fields:
			for field: String in fields[category]:
				var got: Variant = actual[field]
				var want: Variant = expected[field]
				var equal: bool = got==want if want is String else (got is int or got is float) and absf(float(got)-float(want))<0.0001
				if not equal:differences[category].append({"source_tick":tick,"raw_line":expected.raw_line,"field":field,"expected":want,"actual":got})
		if tick==420:_check("actual T input consumes15MP2cubes and starts800 ticks",absf(b.player.mp-115.05)<0.0001 and int(b.session.profile.progress.clear_cubes)==198 and int(b.player.cooldowns.get("skill_t",0))==800,actual)
	for category: String in differences:
		var diff: Array = differences[category]
		_check("T original one-shot per-tick "+category,diff.is_empty(),{"count":diff.size(),"first":diff[0] if not diff.is_empty() else null},"original_controlled_probe")
	_check("T one-shot original total80 and persistent hit marker returns1",b.enemies[0].hp==1920.0 and not b.enemy_status.get(b.enemies[0].identifier,{}).has("sniper_hit"),_sample(b,450),"original_controlled_probe")
	traces.append({"case":"original_one_shot","samples":samples,"differences":differences,
		"fixture":"Same baseline as status v2:250/361 enemy HP2000,132.4/314.9 player; aim at current normal body center once at435. Actual T inputs420/435 replace original direct parent20/reticle2 seeks; MP/CD/cubes excluded from source comparison.",
		"phase":"Original observer_before_remaining_callbacks vs completed Battle.step; exact tick comparison, no shifts/source-state injection."})

func _six_shots_and_input() -> void:
	var b := _fresh()
	_check("T actual Main enters independent root6",_ready_t(b),_sample(b,0))
	Input.action_press("skill_t")
	for i in range(20):b.step(b.take_commands())
	_check("held T without key event does not fire",int(b.sniper.ammo)==1 and int(b.sniper.reticle)==1)
	# Original6783 tests Key.isDown84 on every keyDown, not just T keycode.
	_key(b,KEY_F2)
	Input.action_release("skill_t")
	_check("other keyDown while T held fires original listener",int(b.sniper.ammo)==2 and int(b.sniper.reticle)==2)
	_key(b,KEY_T,true)
	_check("busy T repeat does not reset shot or increment ammo",int(b.sniper.ammo)==2 and int(b.sniper.reticle)==3)
	for i in range(20):
		if int(b.sniper.reticle)==1 or int(b.sniper.root)!=6:break
		b.step({})
	var shots: Array = [_sample(b,1)]
	for shot in range(2,7):
		_key(b,KEY_T,true)
		_check("T repeated-key shot%d enters2 and increments ammo" % shot,int(b.sniper.root)==6 and int(b.sniper.reticle)==2 and int(b.sniper.ammo)==shot+1,_sample(b,shot))
		shots.append(_sample(b,shot))
		if shot<6:
			for i in range(14):b.step({})
			_check("T shot%d returns ready1" % shot,int(b.sniper.reticle)==1 and int(b.sniper.root)==6)
	_check("sixth shot does not exit at ammo7 creation",int(b.sniper.root)==6 and int(b.sniper.ammo)==7)
	for i in range(11):b.step({})
	_check("source13 creates completion observer before its callback",int(b.sniper.root)==6 and int(b.sniper.reticle)==13)
	b.step({})
	_check("source13 observer firstcallback14 exits default ammo7",int(b.sniper.root)==7)
	for i in range(4):b.step({})
	_check("T root11 returns player control",int(b.sniper.root)==11 and b.player.state=="idle")
	for i in range(2):b.step({})
	_check("T root12 blank naturally returns1",int(b.sniper.root)==1)
	_check("reticle shots do not pay extra MP or cubes",int(b.session.profile.progress.clear_cubes)==198 and b.player.mp>115 and b.player.mp<130)
	traces.append({"case":"six_shots_input_static_source","shots":shots,"events":b.journal.duplicate(true),"basis":"6783 keyDown/6789f13 completion listener. Firstcallback14 is matching host-stage inference, not a new original six-shot probe."})

func _timer_and_wall() -> void:
	var b := _fresh()
	_check("timer fixture enters original T root6",_ready_t(b))
	_check("T child timer starts at1",int(b.sniper.timer)==1)
	for i in range(263):b.step({})
	_check("T timer264 still holds root6",int(b.sniper.root)==6 and int(b.sniper.timer)==264)
	b.step({})
	_check("T timer265 exits root7 without firing",int(b.sniper.root)==7 and int(b.sniper.ammo)==1)
	var old: WeakRef = weakref(b)
	b = _fresh()
	_check("scene reentry starts fresh T root/ammo/timer",int(b.sniper.root)==1 and int(b.sniper.ammo)==1 and int(b.sniper.timer)==0)
	# Queue-free is deferred, so absence from Main's active tree is the contract.
	_check("scene exit detaches old T encounter",old.get_ref()==null or old.get_ref().get_parent()==null)
	_key(b)
	for i in range(7):b.step({})
	_check("T root5 before display-list creation",int(b.sniper.root)==5)
	b.step({"left":true})
	_check("new root6 does not execute child enterFrame on creation",int(b.sniper.root)==6 and b.sniper.local==Vector2(24,46.1))
	b.step({"left":true})
	_check("ready aim moves20 local units next tick",b.sniper.local==Vector2(4,46.1),b.sniper.local)
	var cases := [
		{"name":"left","input":Vector2(-400,46.1),"expect":Vector2(-380,46.1)},
		{"name":"right","input":Vector2(440,46.1),"expect":Vector2(420,46.1)},
		{"name":"top","input":Vector2(24,-300),"expect":Vector2(24,-280)},
		{"name":"bottom","input":Vector2(24,350),"expect":Vector2(24,330)}]
	for item: Dictionary in cases:
		# Controlled coordinates crossing one7112 hole edge. This checks original
		# mixed-coordinate branch corrections, not a generic screen clamp.
		b.sniper.local = item.input
		b.step({})
		_check("source wall "+str(item.name)+" corrects20 local units",b.sniper.local==item.expect,{"initial":item.input,"expected":item.expect,"actual":b.sniper.local})
	traces.append({"case":"timer_and_wall_static_source","wall_cases":cases,"basis":"6812f265 and6780 original four ordered shape tests; border equality and parent/child same-tick order remain untested in original."})

func _run() -> void:
	formal_exists = FileAccess.file_exists("user://profile.json")
	if formal_exists:formal_hash = FileAccess.get_sha256("user://profile.json")
	app = MainScene.instantiate()
	root.add_child(app)
	_check("T suite uses actual Main isolated test startup",app.startup_ok and app.test_mode,"","Godot_headless_integration")
	if not app.startup_ok:
		_finish()
		return
	app.saves = SaveStore.new("user://act02_t/run_%d_%d/profile.json" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()])
	var source := _load_oracle()
	if not source.is_empty():_one_shot(source)
	_six_shots_and_input()
	_timer_and_wall()
	Input.action_release("skill_t")
	_check("T fixtures preserve formal save existence and hash",FileAccess.file_exists("user://profile.json")==formal_exists and (not formal_exists or FileAccess.get_sha256("user://profile.json")==formal_hash),"","Godot_headless_integration")
	app._dispose_battle()
	var drained: bool = await app.audio.stop_and_drain(1.0)
	_check("T Dummy audio releases playback references",drained and app.audio.snapshot().pending_playbacks==0,"","Godot_headless_integration")
	app.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	var failures := checks.filter(func(row:Dictionary)->bool:return not row.passed).size()
	var output := OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if output.is_empty():output = "res://artifacts/leba_act02_20261115/t_regression"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var file := FileAccess.open(output.path_join("act02_t_tests.json"),FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify({"suite":"act02_t","checks":checks,"failures":failures,"evidence":evidence,"traces":traces,
			"scope":"Actual Main/InputMap headless Dummy; one controlled original-shot oracle separated from static6shots/timer/key/wall contracts. Not OS/native Flash/natural six-shot or border acceptance."},"\t")+"\n")
		file.close()
	print("ACT02_T_TESTS_RESULT "+JSON.stringify({"checks":checks.size(),"failures":failures}))
	quit(0 if failures==0 else 1)
