extends SceneTree
## Actual Main -> normal training -> real InputMap KEY_Y dispatch.
## Headless/Dummy injection is NOT physical OS keyboard or native Flash testing.
## Independent persistent_probe only covers the first original normal samples.
## Loop/timer/input requirements elsewhere are source-derived Godot regressions,
## not a claim that the original walking/focus/expiry paths were dynamically run.
const MainScene = preload("res://scenes/main.tscn")
const SaveStore = preload("res://scripts/services/save_store.gd")
const ORACLE_PATH := "res://artifacts/leba_act02_20261115/persistent_probe.json"
const EPSILON := 0.0001
const NORMAL_COUNTS := {4423:99,4433:46,4436:42,4459:34}
const WALK_COUNTS := {4461:13,4462:13,4463:13,4464:13}
const FOCUS_COUNTS := {4482:6,4483:20,4484:26,4485:5}
var app: Node
var checks: Array[Dictionary] = []
var traces: Array[Dictionary] = []
var source: Dictionary = {}
var evidence: Dictionary = {}
var formal_exists := false
var formal_hash := ""

func _initialize() -> void:call_deferred("_run")

func _check(label: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"name":label,"passed":passed,"detail":detail})
	print(("PASS " if passed else "FAIL ")+label+" "+str(detail))

func _near(a: float,b: float) -> bool:return absf(a-b)<=EPSILON

func _fresh() -> Node2D:
	app.action_lab = false
	app.session.profile = app.saves.default_profile()
	app.session.select_character("crt_0")
	app.session.select_difficulty("expert")
	app._on_intent("select_training_character","crt_0")
	var battle: Node2D = app.battle
	battle.set_physics_process(false)
	battle.manual_clock = true
	# Declared no-contact fixture: only park the enemy high above the playfield.
	# It isolates Y clock/input from hostile RNG without rewriting any Y field,
	# cooldown, timeline, marker result or runtime-produced projectile.
	battle.enemies[0].position = Vector2(520,-1000)
	battle.step({})
	_check("Y fresh actual Main training, no action-lab",app.screen=="battle" and not app.action_lab and battle.is_training() and battle.player.definition.source_crt==0 and not battle.ended)
	return battle

func _step(battle: Node2D, commands: Dictionary = {}) -> void:
	battle.step(commands)

func _press_y(battle: Node2D, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_Y
	event.physical_keycode = KEY_Y
	event.pressed = true
	event.echo = echo
	battle._unhandled_input(event)
	battle.step(battle.take_commands())
	event.pressed = false
	event.echo = false
	battle._unhandled_input(event)

func _y(battle: Node2D) -> Dictionary:return battle._y_find()

func _part(y: Dictionary,id: int) -> Dictionary:
	for part: Dictionary in y.get("parts",[]):
		if int(part.source_id)==id:return part
	return {}

func _host_source(y: Dictionary, host: Node) -> int:
	if host==y.visual:return 4491
	for part: Dictionary in y.parts:
		if part.host==host:return int(part.source_id)
	return -1

func _sample(battle: Node2D) -> Dictionary:
	var y := _y(battle)
	var units: Array[Dictionary] = []
	for part: Dictionary in y.get("parts",[]):
		var origin: Vector2 = battle.to_local(part.host.global_position)
		var helpers: Array[Dictionary] = []
		for helper: Dictionary in part.helpers.values():
			helpers.append({"frame":helper.frame,"born":helper.born,"depth":helper.depth,"playing":helper.playing})
		units.append({"source_id":part.source_id,"frame":part.frame,"count":part.count,"host_id":part.host.get_instance_id(),"x":origin.x,"y":origin.y,"i":part.i_label,"helpers":helpers})
	var bullets: Array[Dictionary] = []
	for bullet: Dictionary in battle.projectiles:
		if not bullet.has("host") or not is_instance_valid(bullet.host):continue
		var origin: Vector2 = battle.to_local(bullet.host.global_position)
		bullets.append({"host_source":_host_source(y,bullet.host),"host_id":bullet.host.get_instance_id(),"replace_key":bullet.host_depth_key,
			"visual_id":bullet.visual.get_instance_id(),"source_frame":bullet.visual.source_frame,"age":bullet.age,
			"local":[bullet.visual.position.x,bullet.visual.position.y],"scale":[bullet.visual.scale.x,bullet.visual.scale.y],"root":[origin.x,origin.y]})
	return {"tick":battle.session.run.source_ticks,"actor":battle.player.parent_frame,"action":battle.player.source_frame,
		"phase":y.phase,"age":y.phase_age,"normal_frame":y.normal_frame,"group":y.group,"bk":y.bk,
		"yx":y.visual.position.x,"yy":y.visual.position.y,"facing":y.facing,"slot":battle._y_slot_frame,"slot_playing":battle._y_slot_playing,
		"mp":battle.player.mp,"cubes":battle.session.profile.progress.clear_cubes,"units":units,"bullets":bullets}

func _wait_slot(battle: Node2D, target: int) -> bool:
	for n in range(600):
		if int(battle._y_slot_frame)>=target:return true
		if battle.ended:break
		_step(battle)
	_check("Y slot naturally reaches"+str(target),false,_sample(battle))
	return false

func _wait_phase(battle: Node2D, phase: int, cap := 80) -> bool:
	for n in range(cap):
		if int(_y(battle).phase)==phase:return true
		if battle.ended:break
		_step(battle)
	_check("Y reaches phase"+str(phase),false,_sample(battle))
	return false

func _wait_age(battle: Node2D, phase: int, age: int, cap := 320) -> bool:
	for n in range(cap):
		var y := _y(battle)
		if int(y.phase)==phase and int(y.phase_age)>=age:return true
		if int(y.phase)!=phase or battle.ended:break
		_step(battle)
	_check("Y phase/age target %d/%d" % [phase,age],false,_sample(battle))
	return false

func _activate(battle: Node2D) -> bool:
	if not _wait_slot(battle,533):return false
	var mp: float = battle.player.mp
	var cubes: int = int(battle.session.profile.progress.clear_cubes)
	_press_y(battle)
	_check("real KEY_Y enters actor24/source1 and pays30MP/5cubes",battle.player.parent_frame==24 and battle.player.source_frame==1 and _near(battle.player.mp,mp-30.0+0.05) and int(battle.session.profile.progress.clear_cubes)==cubes-5,_sample(battle))
	_check("accepted Y freezes original slot2",battle._y_slot_frame==2 and not battle._y_slot_playing and battle.player.cooldowns.skill_y==531)
	return _wait_phase(battle,2)

func _load_source() -> void:
	if not FileAccess.file_exists(ORACLE_PATH):
		_check("independent Y original probe exists",false,ORACLE_PATH)
		return
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(ORACLE_PATH))
	if not value is Dictionary:
		_check("independent Y oracle parses",false)
		return
	source = value
	_check("independent persistent probe completed declared fixture",source.integrity.get("ok",false) and int(source.finish.get("failures",-1))==0,source.finish)
	evidence = {"oracle":ORACLE_PATH,"json_sha256":FileAccess.get_sha256(ORACLE_PATH),"log":source.log,"sha256":source.sha256,
		"evidence_class":source.evidence_class,"limits":source.limits,
		"comparison":"Original t714..721 normal units; alignment is source4812/25 construction, not post-hoc best-fit shifting. MP/input were bypassed by original fixture and are NOT compared."}

func _compare_original_initial(battle: Node2D) -> void:
	if source.is_empty():return
	var differences: Array[Dictionary] = []
	var samples: Array[Dictionary] = []
	var rows_compared := 0
	var first_bullet_checked := false
	for original_tick in range(714,722):
		var sample := _sample(battle)
		samples.append(sample)
		for expected: Dictionary in source.records:
			if int(expected.get("t",-1))!=original_tick or expected.get("tag","")!="tick":continue
			if expected.record_type=="STATE":
				rows_compared += 1
				if int(sample.phase)!=int(expected.yroot) or int(sample.age)!=int(expected.ytimer) or not _near(sample.yx,expected.yx) or not _near(sample.yy,expected.yy):
					differences.append({"t":original_tick,"line":expected.raw_line,"field":"root/timer","expected":[expected.yroot,expected.ytimer,expected.yx,expected.yy],"actual":[sample.phase,sample.age,sample.yx,sample.yy]})
			elif expected.record_type=="Y_UNIT":
				rows_compared += 1
				var actual := _part(_y(battle),int(expected.source_id))
				var point := Vector2.INF if actual.is_empty() else battle.to_local(actual.host.global_position)
				if actual.is_empty() or int(actual.frame)!=int(expected.frame) or not _near(point.x,float(expected.root_x)) or not _near(point.y,float(expected.root_y)):
					differences.append({"t":original_tick,"line":expected.raw_line,"source_id":expected.source_id,"field":"child frame/host origin","expected":[expected.frame,expected.root_x,expected.root_y],"actual":[] if actual.is_empty() else [actual.frame,point.x,point.y]})
			elif expected.record_type=="Y_BULLET" and original_tick==719:
				var matches: Array = sample.bullets.filter(func(r:Dictionary)->bool:return int(r.host_source)==4436)
				first_bullet_checked = true
				var good: bool = matches.size()==1
				if good:
					var actual: Dictionary = matches[0]
					good = actual.local==[0.0,0.0] and actual.scale==[1.0,1.0] and int(actual.source_frame)==int(expected.frame) and _near(actual.root[0],expected.root_x) and _near(actual.root[1],expected.root_y) and str(actual.replace_key).ends_with(":0")
				if not good:differences.append({"t":original_tick,"line":expected.raw_line,"field":"first original wrong-host bullet","expected":expected,"actual":matches})
		if original_tick<721:_step(battle)
	_check("first8 normal source ticks compare40 original root/unit rows",rows_compared==40 and differences.is_empty(),{"compared":rows_compared,"first_difference":differences[0] if not differences.is_empty() else null,"differences":differences.size()})
	_check("first original4436 bullet host/local0/depth0 compared",first_bullet_checked and differences.filter(func(d:Dictionary)->bool:return d.field=="first original wrong-host bullet").is_empty())
	traces.append({"case":"original_initial_normal8","kind":"controlled_original_comparison","samples":samples,"differences":differences})

func _loop_error(y: Dictionary, counts: Dictionary) -> Array:
	var result: Array = []
	if y.parts.size()!=counts.size():return ["part count"]
	for part: Dictionary in y.parts:
		var id := int(part.source_id)
		if not counts.has(id):result.append({"unexpected_source":id});continue
		# Source natural loop oracle; birth belongs to actual runtime instance.
		var age: int = int(y.phase_age) if str(y.group) in ["normal","focus"] else -1
		if age>0 and int(part.frame)!=(age-1)%int(counts[id])+1:result.append({"id":id,"frame":part.frame,"age":age})
	return result

func _test_ready_gates_and_normal() -> void:
	var battle := _fresh()
	_check("4491 exists before activation and starts hidden phase1",not _y(battle).is_empty() and _y(battle).phase==1 and _y(battle).parts.is_empty())
	var cubes: int = battle.session.profile.progress.clear_cubes
	_press_y(battle)
	_check("early real Y rejected before533 without charge",battle.player.parent_frame==1 and _y(battle).phase==1 and battle.session.profile.progress.clear_cubes==cubes and _near(battle.player.mp,130.0))
	if not _wait_slot(battle,531):return
	_press_y(battle)
	_check("source532 still rejects Y",battle._y_slot_frame==532 and battle.player.parent_frame==1 and not battle.skill_slots().y.ready,_sample(battle))
	_press_y(battle)
	_check("next source533 event accepts actual Y",battle.player.parent_frame==24 and battle.player.source_frame==1 and battle._y_slot_frame==2 and not battle._y_slot_playing and _near(battle.player.mp,100.05) and battle.session.profile.progress.clear_cubes==cubes-5,_sample(battle))
	if not _wait_phase(battle,2):return
	_check("actor24/source25 constructs four normal source1 instances",battle.player.parent_frame==24 and battle.player.source_frame==25 and _y(battle).phase_age==1 and _y(battle).parts.size()==4 and _y(battle).parts.all(func(p:Dictionary)->bool:return p.frame==1),_sample(battle))
	_compare_original_initial(battle)
	var loop_differences: Array = []
	var timer_samples: Array[Dictionary] = []
	var helper_samples: Array[Dictionary] = []
	var root_replacement_before := 0
	var root_replacement_after := 0
	var slot_was_frozen := true
	for guard in range(320):
		if int(_y(battle).phase)!=2 or int(_y(battle).phase_age)>=292 or battle.ended:break
		var y := _y(battle)
		loop_differences.append_array(_loop_error(y,NORMAL_COUNTS))
		slot_was_frozen = slot_was_frozen and battle._y_slot_frame==2 and not battle._y_slot_playing
		var age := int(y.phase_age)
		if age in [13,16]:
			var root_bullets: Array = battle.projectiles.filter(func(p:Dictionary)->bool:return p.get("host")==y.visual)
			_check("Y root ASdepth0 has exactly one dynamic projectile atage"+str(age),root_bullets.size()==1)
			if root_bullets.size()==1:
				if age==13:root_replacement_before=root_bullets[0].visual.get_instance_id()
				else:root_replacement_after=root_bullets[0].visual.get_instance_id()
		if age in [160,161,186,187,211,212,236,237,261,262,291]:
			timer_samples.append({"age":age,"visible":y.timer_visual.visible,"image_frame":y.timer_visual.source_frame})
			var expected_frame := 1
			for f: int in [161,187,212,237,262]:
				if age>=f:expected_frame=f
			_check("4480 source-derived timer visual at"+str(age),y.timer_visual.visible==(age>=161) and (age<161 or int(y.timer_visual.source_frame)==expected_frame))
		if age in [27,28,29,39,40]:
			var unit := _part(y,4433)
			var callbacks: Array = battle._y_marker_observers().filter(func(o:Dictionary)->bool:return o.source.ends_with("4433"))
			var frames: Array = unit.helpers.values().map(func(h:Dictionary)->int:return h.frame)
			helper_samples.append({"age":age,"helper_frames":frames,"observer_count":callbacks.size()})
			if age==27:_check("new4433 helper has Load but no same-tick observer",frames==[1] and callbacks.is_empty())
			if age in [29,39]:_check("empty1140 still owns global35 observer age"+str(age),frames==[3] and callbacks.size()==1 and callbacks[0].amount==35.0)
			if age==40:_check("source40 removes4433 helper and observer",frames.is_empty() and callbacks.is_empty())
		_step(battle)
	_check("four normal loops retain independent natural counts",loop_differences.is_empty(),loop_differences.slice(0,4))
	_check("active normal292-boundary keeps Yslot2 stopped",slot_was_frozen)
	_check("two different units replace shared root ASdepth0",root_replacement_before>0 and root_replacement_after>0 and root_replacement_before!=root_replacement_after)
	# Full original probe365/366: phase4 placement precedes its queued controls.
	# Natural input here already stopped slot2; first snapshot retains that state.
	_check("normal timer292 phase4 retains old stopped slot2 and bk until queued controls",_y(battle).phase==4 and _y(battle).phase_age==1 and battle._y_slot_frame==2 and not battle._y_slot_playing and _y(battle).bk,_sample(battle))
	for n in range(8):
		_step(battle)
		if n==0:_check("normal phase4 next tick runs controls then advances slot3",_y(battle).phase==4 and _y(battle).phase_age==2 and battle._y_slot_frame==3 and battle._y_slot_playing and not _y(battle).bk,_sample(battle))
	_check("exit4490 source9 returns phase1 while cooldown continues",_y(battle).phase==1 and _y(battle).parts.is_empty() and battle._y_slot_frame==10 and not battle.skill_slots().y.ready,_sample(battle))
	traces.append({"case":"normal_source_derived_regression","timer_samples":timer_samples,"helper_lifecycle":helper_samples,"loop_differences":loop_differences,"final":_sample(battle),"events":battle.journal.duplicate(true)})

func _test_focus_and_teardown() -> void:
	var battle := _fresh()
	if not _activate(battle) or not _wait_age(battle,2,18):return
	var mp: float = battle.player.mp
	var cubes: int = battle.session.profile.progress.clear_cubes
	_press_y(battle,true)
	_check("active4465 repeat KEY_Y enters actor25 for zero cost despite CD",battle.player.parent_frame==25 and _near(battle.player.mp,mp+0.05) and battle.session.profile.progress.clear_cubes==cubes and not battle._y_slot_playing,_sample(battle))
	var old_group: Node = _y(battle).group_node
	var old_hosts: Array = _y(battle).parts.map(func(p:Dictionary)->Node:return p.host)
	var live_local_before := 0
	for guard in range(80):
		if int(_y(battle).phase)!=2 or battle.player.source_frame>=33 or battle.ended:break
		live_local_before = battle.projectiles.filter(func(p:Dictionary)->bool:return old_hosts.has(p.get("host"))).size()
		_step(battle)
	# Full original552 keeps bk1 at phase3 construction;553 executes its clear.
	_check("actor25/source33 enters focused group before queued bk clear",battle.player.parent_frame==25 and battle.player.source_frame==33 and _y(battle).phase==3 and _y(battle).bk,_sample(battle))
	_check("normal group teardown removes its live hosted projectile callbacks",live_local_before>0 and old_group.is_queued_for_deletion() and battle.projectiles.all(func(p:Dictionary)->bool:return not old_hosts.has(p.get("host"))),{"local_projectiles_before_transition":live_local_before})
	var differences: Array = []
	var hold_ok := true
	var replacements := {}
	for guard in range(100):
		if int(_y(battle).phase)!=3 or battle.ended:break
		var y := _y(battle)
		differences.append_array(_loop_error(y,FOCUS_COUNTS))
		if int(y.phase_age)==2:_check("focus phase3 next tick clears bk with actor source34",not y.bk and battle.player.parent_frame==25 and battle.player.source_frame==34,_sample(battle))
		if int(y.phase_age)>=6:hold_ok = hold_ok and battle.player.parent_frame==25 and battle.player.source_frame==38
		if int(y.phase_age) in [4,9]:
			var host: Node = _part(y,4485).host
			var bullets: Array = battle.projectiles.filter(func(p:Dictionary)->bool:return p.get("host")==host)
			if bullets.size()==1:replacements[int(y.phase_age)] = bullets[0].visual.get_instance_id()
		_step(battle)
	_check("four focus loops retain independent6/20/26/5 counts",differences.is_empty(),differences.slice(0,4))
	_check("actor25 holds38 throughout focus waiting",hold_ok)
	_check("focus4485 replaces its own ASdepth0 before old10-frame lifetime",replacements.has(4) and replacements.has(9) and replacements[4]!=replacements[9],replacements)
	_check("focus timer81 phase4 keeps slot2 stopped until queued controls",_y(battle).phase==4 and _y(battle).phase_age==1 and not battle._y_slot_playing and battle._y_slot_frame==2)
	_step(battle)
	_check("focus phase4 next tick starts cooldown and advances slot3",_y(battle).phase==4 and _y(battle).phase_age==2 and battle._y_slot_playing and battle._y_slot_frame==3 and not _y(battle).bk,_sample(battle))
	_check("focus38 returns only after observing rootphase4",battle.player.parent_frame==1 and battle.player.state=="idle",_sample(battle))
	traces.append({"case":"focus_source_derived_regression","loop_differences":differences,"hold_ok":hold_ok,"final":_sample(battle),"events":battle.journal.duplicate(true),"phase_evidence":"Initial persistent probe lacked queued transition coverage. New y_full_probe552/553 and632/633 explicitly show deferred bk/slot controls and next-tick hold return; full per-tick comparison lives in test_act02_y_source.gd."})

func _test_walk_and_timer_flip() -> void:
	var battle := _fresh()
	if not _activate(battle) or not _wait_age(battle,2,18):return
	var previous_ids: Array = []
	var previous_frames: Array = []
	var stable_instances := true
	var independent_frames := true
	var correct_walk_parts := true
	var walk_samples := 0
	var samples: Array[Dictionary] = []
	# Held movement snapshots feed the existing shared ground input; no Y/root
	# position, state, detector or source frame is set by this fixture.
	for n in range(80):
		_step(battle,{"right":true,"axis":1.0})
		var y := _y(battle)
		if y.group!="walk":continue
		walk_samples += 1
		correct_walk_parts = correct_walk_parts and y.parts.size()==4 and y.parts.all(func(p:Dictionary)->bool:return WALK_COUNTS.has(int(p.source_id)) and int(p.count)==WALK_COUNTS[int(p.source_id)])
		var ids: Array = y.parts.map(func(p:Dictionary)->int:return p.host.get_instance_id())
		var frames: Array = y.parts.map(func(p:Dictionary)->int:return p.frame)
		if not previous_ids.is_empty():
			stable_instances = stable_instances and ids==previous_ids
			for i in range(frames.size()):independent_frames = independent_frames and frames[i]==previous_frames[i]%13+1
		previous_ids=ids
		previous_frames=frames
		samples.append(_sample(battle))
	# The detector may regain contact before the80-step fixture ends, so the
	# final pose need not still walk. Validate each actual walking sample instead.
	_check("held movement actually enters four13-frame walk children",walk_samples>=26 and correct_walk_parts,{"walk_samples":walk_samples,"all_sample_parts_match":correct_walk_parts})
	_check("repeated4465 goto2 preserves walking child instances and clocks",stable_instances and independent_frames,{"samples":walk_samples})
	# With source callbacks no longer requesting2, source3 naturally wraps to1.
	for n in range(3):_step(battle)
	_check("walking release reconstructs normal child group",_y(battle).group=="normal" and _y(battle).parts.all(func(p:Dictionary)->bool:return NORMAL_COUNTS.has(int(p.source_id))),_sample(battle))
	_step(battle,{"left":true,"axis":-1.0})
	var y := _y(battle)
	_check("root facing follows moving actor and timer retains own source flip",int(y.facing)==-1 and y.visual.scale.x<0 and y.timer_visual.scale.x==-1 and y.timer_visual.position==Vector2(-127.9,0),{"root_scale":y.visual.scale,"timer_scale":y.timer_visual.scale,"timer_position":y.timer_visual.position})
	traces.append({"case":"walking_engine_fixture_not_original_dynamic_oracle","samples":samples,"unknown":"Repeated goto2 source queue/reuse phase remains unverified against moving original footage/probe; assertions are current source-derived instance contract."})

func _test_reentry_and_conditions() -> void:
	var battle := _fresh()
	if not _wait_slot(battle,533):return
	battle.player.mp = 20.0 # explicit insufficient-resource fixture
	_press_y(battle)
	_check("ready Y rejects insufficientMP without consuming cubes",battle.player.parent_frame==1 and battle._y_slot_frame==533 and battle.session.profile.progress.clear_cubes==200)
	battle.player.mp = 130.0
	battle.session.profile.progress.clear_cubes = 4
	_press_y(battle)
	_check("ready Y rejects four cubes without consumingMP",battle.player.parent_frame==1 and battle._y_slot_frame==533 and _near(battle.player.mp,130.0))
	battle.session.profile.progress.clear_cubes = 200
	if not _activate(battle) or not _wait_age(battle,2,6):return
	var old_root: Node = _y(battle).visual
	var old_battle: Node = battle
	var new_battle := _fresh()
	_check("return/reenter constructs independent4491 and source initial gate",old_battle.is_queued_for_deletion() and new_battle!=old_battle and _y(new_battle).visual!=old_root and _y(new_battle).phase==1 and _y(new_battle).parts.is_empty() and new_battle.projectiles.is_empty() and new_battle._y_slot_frame<533)

func _run() -> void:
	formal_exists = FileAccess.file_exists("user://profile.json")
	if formal_exists:formal_hash=FileAccess.get_sha256("user://profile.json")
	app = MainScene.instantiate()
	root.add_child(app)
	app.set_process(false)
	_check("Y suite starts actual Main isolated normal title",app.startup_ok and app.test_mode and not app.action_lab and app.screen=="title")
	if not app.startup_ok:_finish();return
	app.saves = SaveStore.new("user://act02_y/run_%d_%d/profile.json" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()])
	_load_source()
	_test_ready_gates_and_normal()
	_test_focus_and_teardown()
	_test_walk_and_timer_flip()
	_test_reentry_and_conditions()
	_check("Y suite preserves formal profile existence/hash",FileAccess.file_exists("user://profile.json")==formal_exists and (not formal_exists or FileAccess.get_sha256("user://profile.json")==formal_hash))
	app._dispose_battle()
	var drained: bool = await app.audio.stop_and_drain(1.0)
	_check("Y Dummy audio drains playback references",drained and app.audio.snapshot().pending_playbacks==0)
	app.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	var failures: int = checks.filter(func(r:Dictionary)->bool:return not r.passed).size()
	var output := OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if output.is_empty():output="res://artifacts/leba_act02_20261115/y_regression"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var file := FileAccess.open(output.path_join("act02_y_tests.json"),FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify({"suite":"act02_y","checks":checks,"failures":failures,"evidence":evidence,"traces":traces,
			"scope":"Actual Main normal training and injected InputMap KEY_Y, headless Dummy. Enemy parked at520/-1000 to isolate source clocks. First8normal ticks compared to independent original fixture; all later loop/focus/walk/timeout assertions are source-derived Godot regressions, not native Flash or full original dynamic validation.",
			"not_tested":["physical OS keyboard","native Adobe Flash","original dynamic walking/focus/timeout comparison","Y global bonus damage against source HP trace","armor/equipment variants","GPU pixels"]},"\t")+"\n")
		file.close()
	print("ACT02_Y_TESTS_RESULT "+JSON.stringify({"checks":checks.size(),"failures":failures}))
	quit(0 if failures==0 else 1)
