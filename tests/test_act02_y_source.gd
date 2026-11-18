extends SceneTree
## Independent complete original-Y trace comparison. Actual Main, one Battle.
## Reproduce ONLY the declared source fixture interventions at40/50/390/400/
## 450/520. No Y/marker/bullet result, clock or position is copied from rows.
## Actual InputMap/gates remain covered separately by test_act02_y.gd.
const MainScene = preload("res://scenes/main.tscn")
const SaveStore = preload("res://scripts/services/save_store.gd")
const ORACLE := "res://artifacts/leba_act02_20261115/y_full_probe.json"
const EPSILON := 0.0001
const BOUNDS_EPSILON := 0.0501 # AVM getBounds is in twips; only diagnostic bounds.
const MAX_DIFF_ROWS := 250
var app: Node
var battle: Node2D
var source: Dictionary = {}
var by_tick: Dictionary = {}
var checks: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var differences: Dictionary = {}
var serial_to_runtime: Dictionary = {}
var runtime_to_serial: Dictionary = {}
var bullet_birth_by_slot: Dictionary = {}
var compared := {"STATE":0,"UNIT":0,"HELPER":0,"BULLET":0}
var formal_exists := false
var formal_hash := ""
var evidence: Dictionary = {}

func _initialize() -> void:call_deferred("_run")

func _check(label: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"name":label,"passed":passed,"detail":detail})
	print(("PASS " if passed else "FAIL ")+label+" "+str(detail))

func _different(category: String, tick: int, expected: Dictionary, field: String, want: Variant, got: Variant) -> void:
	if not differences.has(category):differences[category]={"count":0,"rows":[]}
	differences[category].count += 1
	if differences[category].rows.size()<MAX_DIFF_ROWS:
		differences[category].rows.append({"t":tick,"raw_line":expected.get("raw_line"),"object":expected.get("source_id",expected.get("unit_id",expected.get("host_label","STATE"))),"field":field,"expected":want,"actual":got})

func _equal(a: Variant,b: Variant,epsilon := EPSILON) -> bool:
	if (a is int or a is float) and (b is int or b is float):return absf(float(a)-float(b))<=epsilon
	return typeof(a)==typeof(b) and a==b

func _fields(category: String, tick: int, actual: Dictionary, expected: Dictionary, names: Array, epsilon := EPSILON) -> void:
	for key: String in names:
		if not _equal(expected.get(key),actual.get(key),epsilon):_different(category,tick,expected,key,expected.get(key),actual.get(key))

func _identity(category: String, tick: int, expected: Dictionary, runtime_id: String, birth_identity := "") -> void:
	var original_id := category+":"+(str(int(expected.serial)) if birth_identity.is_empty() else birth_identity)
	var actual_id := category+":"+runtime_id
	if serial_to_runtime.has(original_id):
		if serial_to_runtime[original_id]!=actual_id:_different(category+"_lifetime",tick,expected,"same source serial must retain runtime instance",serial_to_runtime[original_id],actual_id)
	else:serial_to_runtime[original_id]=actual_id
	if runtime_to_serial.has(actual_id):
		if runtime_to_serial[actual_id]!=original_id:_different(category+"_lifetime",tick,expected,"new source serial must replace runtime instance",original_id,runtime_to_serial[actual_id])
	else:runtime_to_serial[actual_id]=original_id

func _load_source() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ORACLE))
	if not parsed is Dictionary:
		_check("full original Y oracle parses",false)
		return false
	source=parsed
	var valid: bool = source.integrity.ok and int(source.finish.failures)==0
	_check("independent original Y fixture completed17 checks",valid and source.checks.size()==17,source.finish)
	for row: Dictionary in source.records:
		var tick := int(row.get("t",-1))
		if tick<31 or tick>700:continue
		if not by_tick.has(tick):by_tick[tick]={"STATE":[],"UNIT":[],"HELPER":[],"BULLET":[]}
		if by_tick[tick].has(row.record_type):by_tick[tick][row.record_type].append(row)
	var missing: Array = []
	for tick in range(31,701):
		if not by_tick.has(tick) or by_tick[tick].STATE.size()!=1:missing.append(tick)
	_check("original exact31..700 STATE coverage",missing.is_empty(),missing)
	evidence={"oracle":ORACLE,"oracle_sha256":FileAccess.get_sha256(ORACLE),"log":source.log,"log_sha256":source.sha256,
		"evidence_class":source.evidence_class,"limits":source.limits,"source_phase":"observer_before_remaining_callbacks",
		"runtime_phase":"after complete Battle.step, then declared late fixture seeks",
		"phase_policy":"No best-fit shift. bk/normal/marker and lifecycle differences remain exact and separately visible. Empty source1140 frame3 has no geometry: AVM empty getBounds sentinel is not a world rectangle.",
		"bullet_identity_policy":"Probe serial is path-based and aliases same-name replacements: yroot NaN serial11 resets toframe1 at86/100/106. Source1474 naturally advances1..11 then stops without rewind; each observed frame1 is a new attach generation at that host/depth. Enforce runtime identity within each observed birth generation and replacement between generations. Preserve raw serial; do not treat it as unique physical identity.",
		"bounds_policy":"Only getBounds comparison permits one0.05px twip; HP, XY, gravity and source clocks use0.0001float32 tolerance.",
		"input_policy":"Both original and this source comparison use declared direct parent24/25 entries. MP/cube/readiness and untouched slot pages are recorded but not asserted equal. Real KEY_Y gates live in test_act02_y.gd."}
	return valid and missing.is_empty()

func _start_training() -> void:
	app.action_lab=false
	app.session.profile=app.saves.default_profile()
	app.session.select_character("crt_0")
	app.session.select_difficulty("expert")
	app._on_intent("select_training_character","crt_0")
	battle=app.battle
	battle.manual_clock=true
	battle.set_physics_process(false)
	# Runtime setup corresponds to original root41 construction at source31.
	# Source32..39 are real updates: never set the already-followed129.7 manually.
	_check("source comparator starts one actual Main training Battle",app.screen=="battle" and battle.is_training() and not app.action_lab and battle.enemies.size()==1 and not battle.ended)

func _seed(enemy_x: float) -> void:
	battle.player.set_action("idle")
	battle.player.position=Vector2(132.4,314.9)
	battle.player.set_facing(1)
	battle.player.consume_entry_frame()
	var enemy: Node2D=battle.enemies[0]
	enemy.position=Vector2(enemy_x,361)
	enemy.hp=2000.0
	enemy.definition.max_hp=2000.0
	enemy.vertical_speed=0.0
	enemy.gravity_acceleration=0.0
	enemy.airborne=false
	enemy.set_action("idle")
	enemy.consume_entry_frame()
	enemy.update_air_visual(int(battle.session.run.source_ticks))
	# No clear/rebuild of4491, projectiles, helpers, Y cooldown or markers.

func _fixture(tick: int) -> void:
	if tick==40:_seed(250.0)
	elif tick==390:_seed(450.0)
	elif tick in [50,400,520]:
		_check("source declared parent entry has idle precondition t"+str(tick),battle.player.parent_frame==1,{"actor":battle.player.parent_frame,"state":battle.player.state})
		if tick==520:_check("source focus prerequisite phase2",battle._y_find().phase==2)
		battle.player.set_action("y_focus" if tick==520 else "skill_y")
		# Placement happens after actor's completed advance this tick. Source1
		# exists now; next tick advances to2 (no extra held entry-frame replay).
		battle.player.consume_entry_frame()
	elif tick==450:
		battle.player.position.x=430.0
		battle.player.set_action("move")
		battle.player.consume_entry_frame()
		# A single parent2 seek, not a held-right input or repeated position write.

func _host_label(y: Dictionary,host: Node) -> String:
	if host==y.visual:return "yroot"
	for part: Dictionary in y.parts:
		if host==part.host:return "unit"+str(int(part.source_id))
	return "unknown_live_host"

func _snapshot(tick: int) -> Dictionary:
	var y: Dictionary=battle._y_find()
	var enemy: Node2D=battle.enemies[0]
	var marker_frame: Variant="undefined"
	# The render flag suppresses empty3889/8; it does not remove the source
	# child. Its existing runtime clock stays alive until outer air pose2 clears
	# _air_hit_started. Read that clock and clamp at source8 STOP, never use the
	# current oracle row or stale visible PNG frame7 as the timeline value.
	if enemy.airborne and int(enemy._air_hit_started)>=0 and int(enemy.air_visual.source_frame)==1:
		# Source3889/8 queues stop(); a same-tick old-bullet goto2 can receive
		# that queued stop at its new frame2. Read the real actor stop state,
		# independently observed at original196..200; do not advance its clock.
		marker_frame=2 if enemy.air_marker_stopped else mini(8,int(battle.session.run.source_ticks)-int(enemy._air_hit_started)+1)
	var state := {"t":tick,"runtime_tick":battle.session.run.source_ticks,"actor":battle.player.parent_frame,
		"action":battle.player.source_frame if battle.player.state in ["skill_y","y_focus"] else "undefined",
		"px":battle.player.position.x,"py":battle.player.position.y,"mp":battle.player.mp,"cubes":battle.session.profile.progress.clear_cubes,"slot":battle._y_slot_frame,
		"yroot":y.phase,"yx":y.visual.position.x,"yy":y.visual.position.y,"ysx":y.visual.scale.x*100.0,
		"normal":y.normal_frame if y.phase==2 else "undefined","timer":y.phase_age if y.phase==2 else "undefined",
		"focus_timer":y.phase_age if y.phase==3 else "undefined","exit":"undefined","bk":1 if y.bk else 0,
		"ex":enemy.position.x,"ey":enemy.position.y,"ehp":enemy.hp,"outer":2 if enemy.airborne else 1,
		# Source e.속 is the inner action/proxy timeline. The separate visible
		# air pose is e.공중; its1/2 pose must not replace this source field.
		"enemy":enemy.parent_frame,
		"g":enemy.vertical_speed,"gacc":enemy.gravity_acceleration,
		"marker":marker_frame,"marker_clock_start":enemy._air_hit_started,"marker_stopped":enemy.air_marker_stopped,
		"marker_render_visible":enemy.air_hit_visual.visible,"marker_render_frame":enemy.air_hit_visual.source_frame}
	for effect: Dictionary in y.effects:
		if effect.get("exit",false):state.exit=effect.frame
	var units := {}
	var helpers := {}
	var bullets := {}
	for part: Dictionary in y.parts:
		var point: Vector2=battle.to_local(part.host.global_position)
		var id := str(int(part.source_id))
		units[id]={"source_id":part.source_id,"group":y.group,"frame":part.frame,"total":part.count,"i":part.i_label,
			"x":part.host.position.x,"y":part.host.position.y,"root_x":point.x,"root_y":point.y,"identity":str(part.host.get_instance_id())}
		for helper: Dictionary in part.helpers.values():
			var key := id+":"+str(int(helper.depth)-16384)
			var row: Dictionary=helper.row
			var m: Array=row.matrix
			var h := {"unit_id":part.source_id,"unit_frame":part.frame,"depth":int(helper.depth)-16384,"frame":helper.frame,
				"x":m[4],"y":m[5],"sx":m[0]*100.0,"sy":m[3]*100.0,"empty":int(helper.frame)==3,
				"identity":str(part.host.get_instance_id())+":"+str(helper.depth)+":"+str(helper.born),"born":helper.born,"playing":helper.playing}
			if not h.empty:
				var r: Array=row.rect
				var bounds: Rect2=battle.global_transform.affine_inverse()*part.host.global_transform*Rect2(r[0],r[1],r[2],r[3])
				h.merge({"xmin":bounds.position.x,"xmax":bounds.end.x,"ymin":bounds.position.y,"ymax":bounds.end.y})
			helpers[key]=h
	for bullet: Dictionary in battle.projectiles:
		if not bullet.has("host") or not is_instance_valid(bullet.host):continue
		var label := _host_label(y,bullet.host)
		var point: Vector2=battle.to_local(bullet.visual.global_position)
		var key := label+":0"
		# Per-host ASdepth0 is the real shared projectile dictionary contract.
		# Do not synthesize missing source11 containers or source542 helper clocks.
		bullets[key]={"host_label":label,"depth":0 if str(bullet.host_depth_key).ends_with(":0") else -999,
			"frame":bullet.visual.source_frame,"x":bullet.visual.position.x,"y":bullet.visual.position.y,"sx":bullet.visual.scale.x*100.0,
			"root_x":point.x,"root_y":point.y,"identity":str(bullet.visual.get_instance_id()),"host_identity":str(bullet.host.get_instance_id()),
			# Source11 removes542 entirely, so its hita property is undefined even
			# though the inert parent remains attached at the same dynamic depth.
			"hita":"undefined" if int(bullet.visual.source_frame)>=11 or int(bullet.born)==int(battle.session.run.source_ticks) else (1 if bullet.spent else 0),
			"age":bullet.age,"born":bullet.born,"target_ids":bullet.targets.keys()}
	var marker: Dictionary=battle._markers.get(enemy.identifier,{})
	var marker_fields := {}
	for field: String in ["age","source","generation","processed_tick"]:
		if marker.has(field):marker_fields[field]=marker[field]
	return {"state":state,"units":units,"helpers":helpers,"bullets":bullets,
		"marker_runtime":marker_fields,
		"observer_count":battle._y_marker_observers().size()}

func _compare_objects(tick: int,actual: Dictionary,kind: String,key_name: String) -> void:
	var seen := {}
	for expected: Dictionary in by_tick[tick][kind]:
		compared[kind]+=1
		var key: String
		if kind=="UNIT":key=str(int(expected.source_id))
		elif kind=="HELPER":key=str(int(expected.unit_id))+":"+str(int(expected.depth))
		else:key=str(expected.host_label)+":"+str(int(expected.depth))
		if kind=="BULLET" and int(expected.frame)==1:
			# ySerial stores String(path); same-name attachMovie can reuse that
			# reference alias. This is the actual observed restart, not a runtime-
			# chosen alignment or a permission to replace an advancing instance.
			bullet_birth_by_slot[key]=tick
		seen[key]=true
		if not actual[key_name].has(key):
			_different(kind+"_presence",tick,expected,key+" present",true,false)
			continue
		var got: Dictionary=actual[key_name][key]
		if kind=="BULLET":
			if not bullet_birth_by_slot.has(key):_different("BULLET_lifetime",tick,expected,"observed birth before instance",true,false)
			else:_identity(kind,tick,expected,got.identity,key+":birth"+str(bullet_birth_by_slot[key]))
		else:_identity(kind,tick,expected,got.identity)
		if kind=="UNIT":
			_fields("unit_clock",tick,got,expected,["group","frame","total","i"])
			_fields("unit_position",tick,got,expected,["x","y","root_x","root_y"])
		elif kind=="HELPER":
			_fields("helper_clock",tick,got,expected,["frame","unit_frame","depth"])
			_fields("helper_transform",tick,got,expected,["x","y","sx","sy"])
			if int(expected.frame)!=3 and not got.empty:_fields("helper_bounds",tick,got,expected,["xmin","xmax","ymin","ymax"],BOUNDS_EPSILON)
		else:
			_fields("bullet_clock_and_hit",tick,got,expected,["frame","hita","depth"])
			_fields("bullet_wrong_host_transform",tick,got,expected,["host_label","x","y","sx","root_x","root_y"])
	for key: String in actual[key_name]:
		if not seen.has(key):_different(kind+"_presence",tick,by_tick[tick].STATE[0],key+" absent",false,true)

func _compare(tick: int,actual: Dictionary) -> void:
	var expected: Dictionary=by_tick[tick].STATE[0]
	compared.STATE+=1
	_fields("actor",tick,actual.state,expected,["actor","action","px","py"])
	_fields("Y_clock",tick,actual.state,expected,["yroot","normal","timer","focus_timer"])
	_fields("Y_position",tick,actual.state,expected,["yx","yy","ysx"])
	_fields("Y_queued_flag",tick,actual.state,expected,["bk"])
	if int(expected.yroot)==4:_fields("exit_clock",tick,actual.state,expected,["exit"])
	_fields("enemy_position",tick,actual.state,expected,["ex","ey"])
	_fields("actual_HP",tick,actual.state,expected,["ehp"])
	_fields("actual_gravity",tick,actual.state,expected,["g","gacc","outer","enemy"])
	_fields("actual_marker_visual",tick,actual.state,expected,["marker"])
	_compare_objects(tick,actual,"UNIT","units")
	_compare_objects(tick,actual,"HELPER","helpers")
	_compare_objects(tick,actual,"BULLET","bullets")

func _run_trace() -> void:
	_start_training()
	var root_before: Node=battle._y_find().visual
	for tick in range(31,701):
		if tick>31:battle.step({})
		_fixture(tick)
		if tick<40:continue
		var actual := _snapshot(tick)
		samples.append(actual)
		_compare(tick,actual)
		if battle.ended:
			_check("source reproduction remains active through700",false,{"source_tick":tick,"outcome":battle.session.run})
			break
	_check("two original cases kept same4491 root and same Battle",is_instance_valid(root_before) and root_before==battle._y_find().visual and battle==app.battle)
	_check("full trace compared661STATE and original object rows",int(compared.STATE)==661 and int(compared.UNIT)==1996 and int(compared.HELPER)==163 and int(compared.BULLET)==1367,compared)
	for category: String in ["actor","Y_clock","Y_position","Y_queued_flag","exit_clock","enemy_position","actual_HP","actual_gravity","actual_marker_visual",
		"UNIT_presence","UNIT_lifetime","unit_clock","unit_position","HELPER_presence","HELPER_lifetime","helper_clock","helper_transform","helper_bounds",
		"BULLET_presence","BULLET_lifetime","bullet_clock_and_hit","bullet_wrong_host_transform"]:
		var result: Dictionary=differences.get(category,{"count":0,"rows":[]})
		_check("full original per-tick "+category,int(result.count)==0,{"count":result.count,"first":result.rows[0] if not result.rows.is_empty() else null})

func _run() -> void:
	formal_exists=FileAccess.file_exists("user://profile.json")
	if formal_exists:formal_hash=FileAccess.get_sha256("user://profile.json")
	app=MainScene.instantiate()
	root.add_child(app)
	app.set_process(false)
	_check("Y source suite actual Main isolated normal startup",app.startup_ok and app.test_mode and not app.action_lab)
	if not app.startup_ok:_finish();return
	app.saves=SaveStore.new("user://act02_y_source/run_%d_%d/profile.json" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()])
	if _load_source():_run_trace()
	_check("Y source fixture preserves formal user save",FileAccess.file_exists("user://profile.json")==formal_exists and (not formal_exists or FileAccess.get_sha256("user://profile.json")==formal_hash))
	app._dispose_battle()
	var drained: bool=await app.audio.stop_and_drain(1.0)
	_check("Y source Dummy audio drains references",drained and app.audio.snapshot().pending_playbacks==0)
	app.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	var failures: int=checks.filter(func(row:Dictionary)->bool:return not row.passed).size()
	var output := OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if output.is_empty():output="res://artifacts/leba_act02_20261115/y_source_regression"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var file := FileAccess.open(output.path_join("act02_y_source_tests.json"),FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify({"suite":"act02_y_source","checks":checks,"failures":failures,"evidence":evidence,"compared":compared,"samples":samples,"differences":differences,
			"fixture":"One actual Main training Battle. Source31 construction;40/390 baselines;50/400 parent24;450 playerX430+parent2 once;520 parent25. No recorded result is written back.",
			"limits":["This suite deliberately reproduces controlled parent entries; natural KEY_Y gates use separate59-case suite.","No native Adobe Flash or physical OS input.","Source STATE is before remaining callbacks; mismatches are retained, not globally shifted.","Runtime has no independent projectile542 helper trace or source dynamic movieclip-name property; those fields are not synthesized or claimed validated.","Helper bounds are geometry diagnostics, not a substitute for observed actual HP/gravity.","Per-category first250 differences retained with full counts; all runtime samples saved.","No GPU pixel comparison in headless test."]},"\t")+"\n")
		file.close()
	print("ACT02_Y_SOURCE_TESTS_RESULT "+JSON.stringify({"checks":checks.size(),"failures":failures,"compared":compared}))
	quit(0 if failures==0 else 1)
