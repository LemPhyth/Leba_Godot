extends SceneTree
## M1 integration tests. Source facts, controlled source samples, and engineering
## consistency fixtures are labelled separately. No physical keyboard claim.
## C/air X/Down/Z source expectations are added only after independent evidence.
## --headless --audio-driver Dummy --script tests/test_m1_actions.gd -- --test-mode --action-lab
const MainScene = preload("res://scenes/main.tscn")
const SaveStore = preload("res://scripts/services/save_store.gd")
var app: Node
var checks: Array[Dictionary] = []
var traces: Array[Dictionary] = []
var profile_exists := false
var profile_hash := ""

func _initialize() -> void:
	call_deferred("_run")

func _check(label: String, passed: bool, details: Variant = "") -> void:
	checks.append({"name":label,"passed":passed,"details":details})
	print(("PASS " if passed else "FAIL ")+label+" "+str(details))

func _fresh(character := "crt_0", stage_id := "root_2", difficulty := "expert") -> Node2D:
	app.session.profile = app.saves.default_profile()
	app.session.select_character(character)
	app.session.profile.selection.difficulty_id = difficulty
	app.enter_battle(stage_id)
	app.battle.manual_clock = true
	app.battle.set_physics_process(false)
	return app.battle

func _key(code: Key, pressed: bool, echo := false, mode := "both") -> void:
	var event := InputEventKey.new()
	if mode != "physical":event.keycode = code
	if mode != "logical":event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _events(battle: Node2D, kind: String) -> Array:
	return battle.journal.filter(func(e:Dictionary)->bool:return e.event == kind)

func _run() -> void:
	profile_exists = FileAccess.file_exists("user://profile.json")
	if profile_exists:
		profile_hash = FileAccess.get_sha256("user://profile.json")
	app = MainScene.instantiate()
	root.add_child(app)
	_check("M1 suite loads the actual shared Main/Battle",app.startup_ok and app.action_lab,app.database.issues)
	if not app.startup_ok:
		_finish()
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--lab-stage="):_check("action-lab CLI selects real requested stage",app.session.run.stage_id == argument.get_slice("=",1))
		if argument.begins_with("--lab-difficulty="):_check("action-lab CLI selects real requested difficulty",app.session.run.difficulty_id == argument.get_slice("=",1))
	app.saves = SaveStore.new("user://m1_actions/run_%d_%d/profile.json" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()])
	await _test_jump_down_source()
	await _test_z_source_and_entries()
	_test_bar_competition()
	await _test_z_timer_lifecycle()
	await _test_z_cooldown_input()
	await _test_air_input_and_cleanup()
	await _test_z_host_rates()
	await _test_z_multi_target_markers()
	_test_active_helper_state()
	_test_controlled_held_air()
	await _test_controlled_ground_and_lab()
	await _test_lab_window_lifecycle()
	if not OS.get_cmdline_user_args().has("--m1-new-only"):
		_test_character_contact_matrix()
		await _test_delta_input_consistency()
		await _test_focus_pause_and_reentry()
	_check("M1 fixtures leave formal profile existence and hash unchanged",FileAccess.file_exists("user://profile.json") == profile_exists and (not profile_exists or FileAccess.get_sha256("user://profile.json") == profile_hash))
	_check("M1 action lab cannot save isolated progress either",not FileAccess.file_exists(app.saves.path))
	app._dispose_battle()
	var drained: bool = await app.audio.stop_and_drain(1.0)
	_check("M1 Dummy audio retires native playback handles",drained and app.audio.snapshot().pending_playbacks == 0)
	app.queue_free()
	await process_frame
	_finish()

func _isolated() -> Node2D:
	var battle := _fresh()
	for enemy: Node2D in battle.enemies:
		enemy.position = Vector2(-1000,-1000)
	return battle

func _sample_m1(battle: Node2D) -> Dictionary:
	var actor: Node2D = battle.player
	var box: Rect2 = actor.hurt_rect()
	return {"tick":app.session.run.source_ticks,"state":actor.state,"parent":actor.parent_frame,"child":actor.source_frame,"body":actor.body_frame,"air":actor.air_action_frame,"x":actor.position.x,"y":actor.position.y,"cx":actor.action_child_x,"body_width":box.size.x,"body_x":box.position.x,"overlay_visible":is_instance_valid(actor.jump_visual) and actor.jump_visual.visible,"mp":actor.mp,"ms":battle.real_time_ms}

func _press_tick(battle: Node2D, code: Key, mode := "both") -> void:
	_key(code,true,false,mode)
	await process_frame
	battle.step(battle.take_commands())
	_key(code,false,false,mode)
	await process_frame

func _test_jump_down_source() -> void:
	# Independent controlled_basics.json: C t80..114, Down260..271/290..301.
	# Direct source goto confirms subsequent timeline; actual Godot input is tested
	# separately here. This is not original natural keyboard evidence.
	for mode: String in ["logical","physical"]:
		var battle := _isolated()
		var at: Vector2 = battle.player.position
		await _press_tick(battle,KEY_C,mode)
		var samples: Array[Dictionary] = [_sample_m1(battle)]
		for tick in range(34):
			battle.step({})
			samples.append(_sample_m1(battle))
		_check("C real input enters parent95 then returns on35th sample: "+mode,samples[0].parent == 95 and samples[0].child == 1 and samples[33].child == 34 and samples[34].parent == 1 and samples[34].state == "idle",samples)
		var body_ok := true
		var phases_ok := true
		for i in range(34):
			var frame := i+1
			body_ok = body_ok and samples[i].body == mini(frame,26)
			phases_ok = phases_ok and (is_zero_approx(float(samples[i].body_width)) if frame >= 7 and frame <= 25 else absf(float(samples[i].body_width)-41.9) <= 0.05)
		_check("C independent body runs1..26 then holds26: "+mode,body_ok)
		_check("C source body7..25 is absent and26 restores real bounds: "+mode,phases_ok)
		_check("C no-input trajectory keeps root fixed and removes overlay on return: "+mode,samples.all(func(s:Dictionary)->bool:return is_equal_approx(float(s.x),at.x) and is_equal_approx(float(s.y),at.y)) and not battle.player.jump_visual.visible and battle.player.mp == 100.0)
		traces.append({"kind":"controlled_source_C_plus_actual_Godot_input","mode":mode,"samples":samples})
		await _press_tick(battle,KEY_C,mode)
		for tick in range(34):battle.step({})
		_check("repeated C cannot accumulate root drift or leave a jump child: "+mode,battle.player.position.is_equal_approx(at) and battle.player.state == "idle" and not battle.player.jump_visual.visible)
	for facing in [1,-1]:
		var battle := _isolated()
		# Exact fractional source positions also catch float32-vs-twips drift.
		var origin := 129.35 if facing == 1 else 76.35
		battle.player.position.x = origin
		battle.player.set_facing(facing)
		await _press_tick(battle,KEY_DOWN)
		var samples: Array[Dictionary] = [_sample_m1(battle)]
		for tick in range(11):
			battle.step({})
			samples.append(_sample_m1(battle))
		var dx_ok: bool = is_equal_approx(float(samples[0].x),origin)
		for i in range(1,11):dx_ok = dx_ok and is_equal_approx(float(samples[i].x),origin-5.0*facing*i)
		_check("Down source2..11 moves5 opposite facing: "+str(facing),dx_ok,samples)
		_check("Down source12 adds3 and returns with total53: "+str(facing),samples[11].parent == 1 and samples[11].state == "idle" and is_equal_approx(float(samples[11].x),origin-53.0*facing))
		traces.append({"kind":"controlled_source_Down_plus_actual_Godot_input","facing":facing,"samples":samples})

func _test_z_source_and_entries() -> void:
	# Bar/movement competition follows original XML depth + Ruffle queue/remove
	# analysis. It is explicitly a source-derived model, not native keyboard proof.
	for entry: String in ["idle","move","hit"]:
		var battle := _isolated()
		if entry != "idle":battle.player.set_action(entry)
		await _press_tick(battle,KEY_Z)
		_check("Z source bar ready wins permitted entry: "+entry,battle.player.state == "skill_z" and battle.player.parent_frame == 5 and is_equal_approx(battle.player.mp,97.05) and battle.player.cooldowns.skill_z == 65 and _events(battle,"z_started").back().entry == "skill_bar",battle.snapshot())
	var battle := _isolated()
	var origin: float = battle.player.position.x
	await _press_tick(battle,KEY_Z)
	var samples: Array[Dictionary] = [_sample_m1(battle)]
	for tick in range(13):
		battle.step({})
		samples.append(_sample_m1(battle))
	_check("Z5 source child1..13 then parent1 on14th sample",samples[0].child == 1 and samples[12].child == 13 and samples[13].parent == 1,samples)
	_check("Z5 source return transfers9.9 root units",is_equal_approx(battle.player.position.x-origin,9.9),{"start":origin,"end":battle.player.position.x})
	_check("Z5 removes hurt body but preserves gravity body while active",samples.slice(0,13).all(func(s:Dictionary)->bool:return is_zero_approx(float(s.body_width))) and battle.player.gravity_rect().has_area())
	_check("Z5 actual frames7/8 create two ms jobs despite no target contact",_events(battle,"z_interval_created").size() == 2 and _events(battle,"z_contact").is_empty() and battle.real_time_ms == 0.0 and battle._z_interval_active and battle._z_timeouts.size() == 2)
	traces.append({"kind":"controlled_source_Z5_plus_actual_Godot_input","samples":samples,"journal":battle.journal.duplicate(true)})
	for gate: String in ["mp","cooldown"]:
		battle = _isolated()
		battle.step({}) # Complete real4112 initialization before injecting gates.
		battle.player.position.x = 250.0
		battle.player.set_action("move")
		if gate == "mp":battle.player.mp = 2.0 # Explicit insufficient-resource fixture.
		else:battle.player.cooldowns.skill_z = 65 # Explicit source-bar-unavailable fixture.
		await _press_tick(battle,KEY_Z)
		_check("unavailable Z bar preserves movement Z6 listener: "+gate,battle.player.state == "move_z" and battle.player.parent_frame == 6 and _events(battle,"z_started").back().entry == "movement" and _events(battle,"skill_rejected").back().reason == gate,battle.snapshot())
		var positions: Array[float] = [battle.player.position.x]
		var move_samples: Array[Dictionary] = [_sample_m1(battle)]
		for tick in range(21):
			battle.step({})
			positions.append(battle.player.position.x)
			move_samples.append(_sample_m1(battle))
		var expected: Array[float] = []
		var x := 250.0
		for frame in range(1,23):
			if frame >= 7:x += 20.0 if frame <= 10 else (10.0 if frame <= 14 else (6.0 if frame <= 18 else 4.0))
			expected.append(x)
		_check("Z6 controlled source trajectory totals160 and returns on22nd sample: "+gate,positions == expected and battle.player.parent_frame == 1,{"actual":positions,"expected":expected})
		_check("Z6 fallback cannot create normal Z ms drag tasks: "+gate,not battle._z_interval_active and battle._z_timeouts.is_empty() and _events(battle,"z_interval_created").is_empty())
		traces.append({"kind":"controlled_source_Z6_relative_motion","gate":gate,"samples":move_samples,"journal":battle.journal.duplicate(true)})

func _test_z_timer_lifecycle() -> void:
	# Original instrumented Z:10ms request,500ms timeout; each callback adds3x
	# to gacc>0 targets without HP damage. Deterministic scheduler precision is a
	# Godot contract, not a claim Ruffle getTimer observes exactly500ms.
	var battle := _isolated()
	var enemy: Node2D = battle.enemies[0]
	await _press_tick(battle,KEY_Z)
	for tick in range(6):battle.step({}) # Actual source7 starts first interval.
	_check("Z source ticks themselves do not advance millisecond clock",battle._z_interval_active and battle.real_time_ms == 0.0 and battle.player.source_frame == 7)
	enemy.position.x = 300.0
	enemy.gravity_acceleration = 0.1 # Isolate timer qualification from source gravity.
	var hp: float = enemy.hp
	battle.advance_real_time(0.009)
	_check("10ms drag cannot fire at9ms",enemy.position.x == 300.0 and _events(battle,"z_interval_tick").is_empty())
	battle.advance_real_time(0.001)
	_check("one timer callback moves3 without direct damage",enemy.position.x == 303.0 and enemy.hp == hp and _events(battle,"z_interval_tick").size() == 1)
	battle.advance_real_time(0.030)
	battle.step({}) # Source8 replaces active interval; first timeout still exists.
	var new_id: int = battle._z_interval_id
	_check("source8 replaces interval while retaining earlier timeout",new_id == 2 and battle._z_timeouts.size() == 2 and battle._z_timeouts[0].due == 500.0 and battle._z_timeouts[1].due == 540.0)
	battle.player.request_hurt() # Explicit original forced-hurt fixture semantics.
	var before: float = enemy.position.x
	battle.advance_real_time(0.010)
	_check("source forced hurt does not stop already-created drag",battle.player.state == "hit" and enemy.position.x == before+3.0 and battle._z_interval_active)
	battle.set_paused(true)
	var paused_ms: float = battle.real_time_ms
	before = enemy.position.x
	battle.advance_real_time(1.0)
	_check("Godot pause adaptation freezes ms jobs and target movement",battle.real_time_ms == paused_ms and enemy.position.x == before)
	battle.set_paused(false)
	battle.advance_real_time(0.450) # Now500ms: old timeout clears currently active ID2.
	var cleared := _events(battle,"z_interval_cleared")
	_check("old timeout clears current interval rather than its own former ID",not battle._z_interval_active and cleared.size() == 1 and cleared[0].origin_timeout == 1 and cleared[0].cleared_current_id == 2 and cleared[0].ms == 500.0,cleared)
	before = enemy.position.x
	battle.advance_real_time(0.1)
	_check("later timeout drains without resurrecting drag",battle._z_timeouts.is_empty() and enemy.position.x == before and enemy.hp == hp)
	traces.append({"kind":"source_timer_rules_with_deterministic_Godot_scheduler","journal":battle.journal.duplicate(true)})
	battle = _isolated()
	await _press_tick(battle,KEY_Z)
	for tick in range(7):battle.step({})
	_check("exit cleanup fixture actually owns active interval/timeouts",battle._z_interval_active and battle._z_timeouts.size() == 2)
	app._dispose_battle()
	_check("Godot scene disposal clears interval and all timeout jobs",battle.get_parent() == null and not battle._z_interval_active and battle._z_timeouts.is_empty())

func _test_bar_competition() -> void:
	# Original XML depths and matched Ruffle FIFO/remove semantics, not copied
	# runtime priorities. Each dictionary represents one simultaneous keyDown.
	var battle := _isolated()
	battle.player.set_action("move")
	battle.step({"key_events":[{"skill_z":true,"skill_s":true,"skill":true,"attack":true,"jump":true,"down":true}]})
	_check("source ready Z bar removes old actor before S/D/X/C/Down callbacks",battle.player.state == "skill_z" and is_equal_approx(battle.player.mp,97.05) and _events(battle,"skill_started").size() == 1 and _events(battle,"basic_started").is_empty())
	battle = _isolated()
	battle.step({}) # Initial4112 reset must precede this unavailable-Z fixture.
	battle.player.cooldowns.skill_z = 65 # Explicit unavailable-Z fixture.
	battle.step({"key_events":[{"skill_z":true,"skill_s":true,"skill":true,"attack":true}]})
	_check("failed Z listener leaves later S eligible before D and actor X",battle.player.state == "skill_s" and is_equal_approx(battle.player.mp,97.05) and _events(battle,"skill_started").size() == 1 and _events(battle,"skill_started")[0].action == "skill_s")
	battle = _isolated()
	battle.player.set_action("move")
	battle.player.mp = 2.0 # Source bar declines without removing actor listener.
	battle.step({"key_events":[{"skill_z":true,"attack":true}]})
	_check("failed Z bar reaches actor X before movement Z fallback",battle.player.state == "basic" and is_equal_approx(battle.player.mp,2.05) and _events(battle,"z_started").is_empty() and _events(battle,"basic_started").size() == 1)

func _test_z_cooldown_input() -> void:
	# Source4064 input node absent on2..66:65 source ticks; heldZ itself is not
	# a fresh KeyDown. Exact original endpoint event ordering remains host-scoped.
	var battle := _isolated()
	_key(KEY_Z,true)
	await process_frame
	battle.step(battle.take_commands())
	for tick in range(64):battle.step(battle.take_commands())
	_check("Z source bar remains locked through64 subsequent ticks",battle.player.cooldowns.skill_z == 1 and _events(battle,"z_started").size() == 1)
	battle.step(battle.take_commands())
	_check("held Z cannot reuse itself when source cooldown reaches zero",battle.player.cooldowns.skill_z == 0 and battle.player.state == "idle" and _events(battle,"z_started").size() == 1)
	_key(KEY_Q,true)
	await process_frame
	battle.step(battle.take_commands())
	_check("other keyDown sees held Z after65tick gate and charges once",battle.player.state == "skill_z" and battle.player.cooldowns.skill_z == 65 and is_equal_approx(battle.player.mp,97.05) and _events(battle,"z_started").size() == 2)
	_key(KEY_Q,false)
	_key(KEY_Z,false)
	await process_frame

func _test_air_input_and_cleanup() -> void:
	# Static original5628 enterFrame polls heldX, unlike ground keyDown. This
	# integration check deliberately does not invent an unobserved emission tick.
	var battle := _fresh()
	battle.player.position.x = 200.0
	battle.enemies[0].position.x = 320.0 # Explicit diagonal projectile collision fixture.
	await _press_tick(battle,KEY_C)
	_key(KEY_X,true)
	await process_frame
	var samples: Array[Dictionary] = []
	for tick in range(28):
		battle.step(battle.take_commands())
		samples.append(_sample_m1(battle))
	_key(KEY_X,false)
	await process_frame
	var shots := _events(battle,"projectile_spawn")
	_check("one held X event during C does not start a ground basic action",_events(battle,"basic_started").is_empty() and _events(battle,"jump_started").size() == 1)
	_check("air polling can emit diagonal shots without repeated keyDown",not shots.is_empty() and shots.all(func(e:Dictionary)->bool:return e.key == "projectile_diagonal" and e.source_frame >= 15 and e.source_frame < 30),shots)
	_check("diagonal projectile really enters shared marker/damage chain",_events(battle,"marker_started").any(func(e:Dictionary)->bool:return e.source == "projectile_diagonal") and battle.enemies[0].hp < battle.enemies[0].definition.max_hp,{"markers":_events(battle,"marker_started"),"damage":_events(battle,"damage")})
	for tick in range(18):battle.step({})
	_check("landing removes air overlay and finite diagonal projectiles",battle.player.state == "idle" and not battle.player.jump_visual.visible and battle.projectiles.is_empty())
	traces.append({"kind":"static_air_polling_integration_not_dynamic_original_timing","samples":samples,"journal":battle.journal.duplicate(true)})
	battle = _isolated()
	await _press_tick(battle,KEY_C)
	for tick in range(18):battle.step({"held_attack":true})
	_check("air interruption fixture has real diagonal projectile instances",not battle.projectiles.is_empty())
	var old: Node2D = battle
	app._dispose_battle()
	_check("air scene exit detaches all projectile and action ownership",old.get_parent() == null and old.paused and old._key_events.is_empty())
	battle = _isolated()
	battle.step({})
	_check("air reentry has no old projectiles markers or child state",battle.projectiles.is_empty() and battle._markers.is_empty() and battle.player.parent_frame == 1 and battle.player.air_action_frame == 1 and not battle.player.jump_visual.visible)

func _test_z_host_rates() -> void:
	# Same2s elapsed duration and identical first input; ms callbacks are compared
	# independently of source-tick sampling. Exact Ruffle jitter is not an oracle.
	var reference: Array = []
	for fps in [30,60,144]:
		var battle := _isolated()
		battle.manual_clock = false
		_key(KEY_Z,true)
		await process_frame
		for frame in range(fps*2):battle._physics_process(1.0/float(fps))
		_key(KEY_Z,false)
		await process_frame
		var timer_events: Array = battle.journal.filter(func(e:Dictionary)->bool:return str(e.event).begins_with("z_interval")).duplicate(true)
		for event: Dictionary in timer_events:
			event.ms = snappedf(float(event.ms),0.000001) # Numeric float noise only, not source tick rounding.
		_check("Z real-time scheduler drains independently after2s: %dHz" % fps,is_equal_approx(battle.real_time_ms,2000.0) and app.session.run.source_ticks == 50 and not battle._z_interval_active and battle._z_timeouts.is_empty())
		var created := _events(battle,"z_interval_created")
		_check("source7/8 create jobs at separate source boundaries: %dHz" % fps,created.size() == 2 and is_equal_approx(created[1].ms-created[0].ms,40.0),created)
		if fps == 30:reference = timer_events
		else:_check("Z callback/timeout event times agree across host delta: 30vs%dHz" % fps,reference == timer_events,{"reference":reference,"actual":timer_events} if reference != timer_events else "")
		traces.append({"kind":"Godot_ms_scheduler_delta_consistency","fps":fps,"events":timer_events})

func _test_z_multi_target_markers() -> void:
	# Original Z timer probe: two helper contacts assign gacc .1/.2 while one new
	# air layer naturally runs marker1->2->3 and damage5+10. Multi-target extension
	# is a source-backed scope fixture, not a dynamic original four-enemy sample.
	var battle := _fresh("crt_0","root_4")
	battle.player.position.x = 200.0
	for index in range(4):
		battle.enemies[index].position.x = [235.0,240.0,245.0,500.0][index]
	await _press_tick(battle,KEY_Z)
	var samples: Array[Dictionary] = []
	for tick in range(8):
		battle.step({})
		samples.append({"tick":app.session.run.source_ticks,"hp":battle.enemies.map(func(e:Node2D)->float:return e.hp),"gacc":battle.enemies.map(func(e:Node2D)->float:return e.gravity_acceleration),"markers":battle._markers.size()})
	var contacts := _events(battle,"z_contact")
	var markers := _events(battle,"marker_started")
	_check("Z multi-target fixture actually contacts each of three independent actors twice",contacts.size() == 6 and ["enemy_0","enemy_1","enemy_2"].all(func(id:String)->bool:return contacts.filter(func(e:Dictionary)->bool:return e.target == id).size() == 2),contacts)
	_check("two Z contacts do not duplicate natural air marker on each target",markers.size() == 3 and battle._markers.is_empty() and ["enemy_0","enemy_1","enemy_2"].all(func(id:String)->bool:return markers.filter(func(e:Dictionary)->bool:return e.target == id).size() == 1),markers)
	_check("each new target receives5 then common10 while untouched fourth stays intact",battle.enemies.slice(0,3).all(func(e:Node2D)->bool:return e.hp == 185.0 and is_equal_approx(e.gravity_acceleration,0.2)) and battle.enemies[3].hp == 200.0 and battle.enemies[3].gravity_acceleration == 0.0,samples)
	var damage: Array = _events(battle,"damage").filter(func(e:Dictionary)->bool:return e.target != "player")
	_check("multi-target damage values remain per-target temporal5 then10",["enemy_0","enemy_1","enemy_2"].all(func(id:String)->bool:return damage.filter(func(e:Dictionary)->bool:return e.target == id).map(func(e:Dictionary)->float:return e.amount) == [5.0,10.0]),damage)
	traces.append({"kind":"source_scope_multi_target_Z_fixture","samples":samples,"journal":battle.journal.duplicate(true)})
	battle = _fresh()
	battle.player.position.x = 200.0
	var enemy: Node2D = battle.enemies[0]
	enemy.position = Vector2(240,330)
	enemy.airborne = true # Explicit falling/no-marker fixture; Z turns pose2 back to1.
	enemy.gravity_acceleration = 0.1
	enemy.vertical_speed = -1.0
	await _press_tick(battle,KEY_Z)
	for tick in range(8):battle.step({})
	_check("existing-air Z still reapplies both physical assignments",_events(battle,"z_contact").size() == 2 and is_equal_approx(enemy.gravity_acceleration,0.3),{"contacts":_events(battle,"z_contact"),"gacc":enemy.gravity_acceleration})
	# Root enemy g<=1 selects air pose1 and recreates3889 after pose2 removed
	# it. ACT02 Y147/148 independently observes this natural1->2->3 chain.
	# The old static assertion wrongly kept that nonexistent child absent forever.
	var changes: Array = _events(battle,"damage").filter(func(row:Dictionary)->bool:return row.target == enemy.identifier)
	_check("falling-air Z creates one natural pose1 marker rather than direct skill damage",_events(battle,"marker_started").size() == 1 and battle._markers.is_empty() and enemy.hp == 185.0 and changes.map(func(row:Dictionary)->float:return row.amount) == [5.0,10.0],changes)
	traces.append({"kind":"source_derived_falling_air_Z_recreates_pose1_marker_fixture","journal":battle.journal.duplicate(true)})

func _test_active_helper_state() -> void:
	# Static original helper checks CURRENT parent/action at marker frame2. These
	# deliberately ordered public-action fixtures are not natural original inputs.
	var battle := _fresh()
	battle.step({"skill":true})
	for tick in range(17):
		if not _events(battle,"marker_started").is_empty():break
		battle.step({})
	_check("D interruption fixture first creates a genuine contact marker",_events(battle,"marker_started").size() == 1 and battle.enemies[0].hp == 200.0 and battle.player.source_frame >= 8 and battle.player.source_frame <= 18,{"frame":battle.player.source_frame,"markers":_events(battle,"marker_started")})
	battle.player.request_hurt()
	battle.step({})
	battle.step({})
	_check("leaving D before marker2 removes70 helper but retains5 and10",battle.enemies[0].hp == 185.0 and _events(battle,"damage").filter(func(e:Dictionary)->bool:return e.target == "enemy_0").map(func(e:Dictionary)->float:return e.amount) == [5.0,10.0],battle.journal)
	traces.append({"kind":"static_current_helper_after_D_interrupt","journal":battle.journal.duplicate(true)})
	battle = _isolated()
	var enemy: Node2D = battle.enemies[0]
	battle._start_marker(battle.player,enemy,-3.0,"fixture: earlier diagonal contact")
	battle.player.set_action("skill")
	battle.player.seek_action_frame(8)
	battle.step({})
	battle.step({})
	_check("entering active D before earlier marker2 supplies live70 helper",enemy.hp == 115.0 and _events(battle,"damage").filter(func(e:Dictionary)->bool:return e.target == "enemy_0").map(func(e:Dictionary)->float:return e.amount) == [75.0,10.0],battle.journal)
	traces.append({"kind":"static_live_D_helper_on_earlier_marker_fixture","journal":battle.journal.duplicate(true)})

func _test_controlled_held_air() -> void:
	# held_native.json: original clip polling really called the temporary Key
	# function1548 times; flags restored. This is controlled polling, not OS keys.
	for example: Array in [[1,false],[1,true],[-1,true]]:
		var facing: int = example[0]
		var reverse: bool = example[1]
		var battle := _isolated()
		battle.player.position.x = 250.0
		battle.player.set_facing(facing)
		var samples: Array[Dictionary] = []
		for frame in range(1,36):
			battle.step({"jump":frame == 1,"held_attack":true,"left":reverse and facing == 1 and frame >= 22,"right":reverse and facing == -1 and frame >= 22})
			samples.append(_sample_m1(battle))
		var label := "face%d/reverse%s" % [facing,reverse]
		var sequence: Array = samples.slice(14,29).map(func(s:Dictionary)->int:return int(s.air))
		_check("controlled original heldX sub sequence15..29: "+label,sequence == [1,2,3,4,5,2,3,4,5,2,3,4,5,2,3],sequence)
		var shots := _events(battle,"projectile_spawn")
		_check("controlled heldX emits exactly at17/21/25/29 on sub3: "+label,shots.map(func(e:Dictionary)->int:return int(e.source_frame)) == [17,21,25,29] and shots.all(func(e:Dictionary)->bool:return e.sub_frame == 3),shots)
		var shot_y := [-0.15,14.8,44.8,89.8]
		var y_ok: bool = shots.size() == 4
		for index in range(mini(shots.size(),4)):y_ok = y_ok and absf(float(shots[index].parent_y)-shot_y[index]) <= 0.05
		_check("controlled diagonal shots preserve original parentY registration: "+label,y_ok)
		var expected_x := 250.0
		var x_ok := true
		for index in range(35):
			var frame := index+1
			if frame >= 17 and frame <= 29:expected_x -= (12.0 if reverse and frame >= 22 else 3.0)*facing
			if frame == 35 and reverse:expected_x -= 6.0*facing
			x_ok = x_ok and is_equal_approx(float(samples[index].x),expected_x)
		_check("controlled recoil reverse-input and same-tick landing trajectory: "+label,x_ok,samples)
		_check("landing enters movement immediately only when direction is held: "+label,battle.player.parent_frame == (2 if reverse else 1) and battle.player.facing == (-facing if reverse else facing))
		traces.append({"kind":"original_controlled_held_native_comparison","name":label,"samples":samples,"shots":shots})

func _test_controlled_ground_and_lab() -> void:
	var battle := _isolated()
	battle.player.position.x = 250.0
	_key(KEY_RIGHT,true)
	await process_frame
	for tick in range(10):battle.step(battle.take_commands())
	_check("original controlled right10ticks gives60 displacement",battle.player.position.x == 310.0 and battle.player.facing == 1)
	_key(KEY_LEFT,true)
	await process_frame
	for tick in range(10):battle.step(battle.take_commands())
	_check("original simultaneous arrows net0 but finish facing left",battle.player.position.x == 310.0 and battle.player.facing == -1)
	_key(KEY_RIGHT,false)
	await process_frame
	for tick in range(10):battle.step(battle.take_commands())
	_check("original controlled left10ticks gives minus60",battle.player.position.x == 250.0 and battle.player.facing == -1)
	_key(KEY_LEFT,false)
	await process_frame
	for position in [-20.0,570.0]:
		battle.player.position.x = position
		battle.step({"axis":-1 if position < 0 else 1})
		_check("source pren0 root boundary uses0..550 at player edge "+str(position),battle.player.position.x == (0.0 if position < 0 else 550.0) and battle.stage.bounds == [0.0,550.0])
	app.open_action_lab("crt_1","root_2")
	app.battle.set_physics_process(false)
	_key(KEY_F7,true)
	_key(KEY_F7,false)
	await process_frame
	battle = app.battle
	battle.set_physics_process(false)
	battle.manual_clock = true
	_check("lab F7 reuses current character in root4 multi-enemy scene",app.session.run.character_id == "crt_1" and app.session.run.stage_id == "root_4" and battle.enemies.size() == 4)
	_key(KEY_F9,true)
	_key(KEY_F9,false)
	await process_frame
	battle = app.battle
	battle.set_physics_process(false)
	battle.manual_clock = true
	_check("lab F9 restarts same stage at next source difficulty",app.session.run.stage_id == "root_4" and app.session.run.difficulty_id == "master" and battle.enemies.all(func(e:Node2D)->bool:return e.hp == 300.0))
	battle.step({"attack":true})
	var output_path := "user://m1_actions/trace_%d.json" % Time.get_ticks_usec()
	var code: Error = battle.export_trace(output_path)
	var exported: Variant = JSON.parse_string(FileAccess.get_file_as_string(output_path)) if code == OK else null
	_check("lab exports bounded real source/input/ms records",code == OK and exported is Dictionary and exported.source_fps == 25 and exported.frames.size() >= 1 and exported.frames.back().input.attack and exported.limits.frames == 5000 and exported.limits.events == 30000)
	_key(KEY_F8,true)
	_key(KEY_F8,false)
	await process_frame
	var export_message: String = app.ui._toast.text
	_check("lab F8 reports export basename without a HUD-covering absolute path",export_message.begins_with("轨迹已导出：trace_") and export_message.ends_with(".json") and not export_message.contains("/") and not export_message.contains("\\"),export_message)

func _test_lab_window_lifecycle() -> void:
	# Application event-handler fixtures for defects found by actual OS-window
	# checks. Direct _input calls deliberately do NOT request native shutdown.
	app.open_action_lab("crt_1","root_4")
	var battle: Node2D = app.battle
	battle.set_physics_process(false)
	battle.manual_clock = true
	battle.step({"attack":true})
	var original_id := battle.get_instance_id()
	var original_ticks: int = app.session.run.source_ticks
	for modifier: String in ["alt_pressed","ctrl_pressed","meta_pressed"]:
		var event := InputEventKey.new()
		event.keycode = KEY_F4
		event.physical_keycode = KEY_F4
		event.pressed = true
		event.set(modifier,true)
		app._input(event)
		_check("modified F4 never resets the live lab encounter: "+modifier,app.battle.get_instance_id() == original_id and app.session.run.source_ticks == original_ticks and app.screen == "battle")
	# Represent the drain interval without calling _shutdown or quit. Closing
	# must reject both diagnostic hotkeys and a late UI retry intent.
	app.screen = "closing"
	battle.set_paused(true)
	var old_stage: String = app.lab_stage
	var old_difficulty: String = app.session.profile.selection.difficulty_id
	var old_toast: String = app.ui._toast.text
	for key: Key in [KEY_F1,KEY_F2,KEY_F4,KEY_F5,KEY_F6,KEY_F7,KEY_F8,KEY_F9]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = true
		app._input(event)
	app._on_intent("retry",null)
	_check("closing rejects lab F keys and late retry without rebuilding or stepping",app.screen == "closing" and app.battle.get_instance_id() == original_id and app.session.run.source_ticks == original_ticks and battle.manual_clock and battle.paused and app.lab_stage == old_stage and app.session.profile.selection.difficulty_id == old_difficulty and app.ui._toast.text == old_toast)
	app.screen = "battle"
	app.session.select_difficulty("king")
	app.open_action_lab("crt_1","root_4")
	battle = app.battle
	battle.set_physics_process(false)
	battle.manual_clock = true
	var profile_before: Dictionary = app.session.profile.duplicate(true)
	battle.deal_damage(battle.enemies[0],battle.player,999.0,"fixture: lab retry after real defeat chain",false)
	battle.step({})
	# ACT02 replaced the engineering result button with original6917 failure UI.
	var retry: BaseButton = app.ui.source_menu.buttons.get("failure_retry") as BaseButton
	_check("lab retry fixture reaches actual defeat result and retry button",app.screen == "result" and battle.ended and app.session.run.outcome == "defeat" and is_instance_valid(retry))
	if not is_instance_valid(retry):return
	original_id = battle.get_instance_id()
	retry.pressed.emit()
	battle = app.battle
	battle.set_physics_process(false)
	battle.manual_clock = true
	_check("lab defeat retry retains character stage and difficulty through real setup",app.screen == "battle" and battle.get_instance_id() != original_id and app.session.run.character_id == "crt_1" and app.session.run.stage_id == "root_4" and app.session.run.difficulty_id == "king" and battle.enemies.size() == 4)
	_check("lab defeat retry restores debug overlay and authored lab controls hint",battle.debug_draw and is_instance_valid(app.ui._lab_hint) and app.ui.root.is_ancestor_of(app.ui._lab_hint) and app.ui._lab_hint.is_visible_in_tree() and app.ui._lab_hint.text.contains("F7") and app.ui._lab_hint.text.contains("不保存进度"))
	_check("lab defeat retry creates clean state without persisting profile",app.session.run.source_ticks == 0 and battle.player.hp == battle.player.definition.max_hp and battle.projectiles.is_empty() and battle._markers.is_empty() and app.session.profile == profile_before and not FileAccess.file_exists(app.saves.path))
	await process_frame

func _test_character_contact_matrix() -> void:
	# Source-backed shared root observers + per-character compatibility fixture.
	# Original controlled contact logs cover crt0, so crt1 is NOT called a separate
	# dynamically observed source case. Both characters must use the same runtime.
	for character: String in ["crt_0","crt_1"]:
		for stage_id: String in ["root_2","root_4","root_6"]:
			for difficulty: String in ["expert","master","king"]:
				var battle := _fresh(character,stage_id,difficulty)
				var boss := stage_id == "root_6"
				var enemy: Node2D = battle.enemies[0]
				for other: Node2D in battle.enemies:
					other.position.x = 550.0
				enemy.position.x = 400.0
				battle.player.position.x = 300.0 if boss else 390.0
				enemy.set_action("ranged" if boss else "attack")
				enemy.seek_action_frame(67 if boss else 25)
				battle.step({})
				var first := {"hp":battle.player.hp,"hurt":battle.player.source_frame,"enemy":enemy.source_frame}
				battle.player.position.x = 300.0 if boss else 390.0
				battle.step({})
				var source_damage := 3.5 if boss else (8.0 if stage_id == "root_4" else 10.0)
				if not boss and difficulty == "expert":
					source_damage += 1.0
				var label := "%s/%s/%s" % [character,stage_id,difficulty]
				_check("shared source contact entry and subsequent damage: "+label,first.hurt == (2 if boss else 1) and first.hp == (96.5 if boss else 100.0) and battle.player.source_frame == (3 if boss else 2) and battle.player.hp == 100.0-source_damage,{"first":first,"after":battle.snapshot()})
				var contacts := _events(battle,"player_hurt_contact")
				_check("two character states retain each distinct contact: "+label,contacts.size() == 2 and contacts[0].hurt_frame == (2 if boss else 1) and contacts[1].hurt_frame == (3 if boss else 2),contacts)
				traces.append({"kind":"compatibility_source_observers","name":label,"journal":battle.journal.duplicate(true)})

func _input_schedule() -> Dictionary:
	# Changes are scheduled before the same source tick at every host delta.
	# This checks clock/queue consistency, not host wall-time or physical repeats.
	return {
		1:[[KEY_RIGHT,true]],6:[[KEY_X,true]],7:[[KEY_X,false]],
		15:[[KEY_X,true]],16:[[KEY_X,false]],23:[[KEY_RIGHT,false]],
		30:[[KEY_D,true]],31:[[KEY_D,false]],55:[[KEY_LEFT,true]],
		60:[[KEY_S,true]],61:[[KEY_S,false]],80:[[KEY_LEFT,false]],
		90:[[KEY_X,true]],91:[[KEY_X,false]],115:[[KEY_RIGHT,true]],
		125:[[KEY_RIGHT,false]]}

func _drive_delta(character: String, fps: int) -> Array[Dictionary]:
	var battle := _fresh(character)
	battle.manual_clock = false
	# Off-field enemy fixture isolates input/action timing from encounter completion.
	# Real actual Main input routing, Battle._physics_process and action events run.
	battle.enemies[0].position = Vector2(-1000,-1000)
	var schedule := _input_schedule()
	var last_scheduled := 0
	var samples: Array[Dictionary] = []
	for host_frame in range(fps*7):
		var next_tick: int = app.session.run.source_ticks+1
		if next_tick > 150:
			break
		if next_tick != last_scheduled:
			for key_event: Array in schedule.get(next_tick,[]):
				_key(key_event[0],bool(key_event[1]))
			last_scheduled = next_tick
			if schedule.has(next_tick):
				await process_frame
		var before: int = app.session.run.source_ticks
		battle._physics_process(1.0/float(fps))
		if app.session.run.source_ticks != before:
			var current_events: Array = battle.journal.filter(func(e:Dictionary)->bool:return e.tick == app.session.run.source_ticks).duplicate(true)
			for event: Dictionary in current_events:
				if event.has("ms"):event.ms = snappedf(float(event.ms),0.000001)
			samples.append({"tick":app.session.run.source_ticks,"state":battle.player.state,"parent":battle.player.parent_frame,"frame":battle.player.source_frame,"body":battle.player.body_frame,"x":battle.player.position.x,"y":battle.player.position.y,"facing":battle.player.facing,"hp":battle.player.hp,"mp":battle.player.mp,"cooldowns":battle.player.cooldowns.duplicate(true),"projectiles":battle.projectiles.size(),"events":current_events})
	for code: Key in [KEY_RIGHT,KEY_LEFT,KEY_X,KEY_S,KEY_D]:
		_key(code,false)
	await process_frame
	_check("host delta consumes exactly150 source ticks: %s/%dHz" % [character,fps],samples.size() == 150 and app.session.run.source_ticks == 150)
	_check("schedule reaches actual actions through input: %s/%dHz" % [character,fps],not _events(battle,"basic_started").is_empty() and _events(battle,"skill_started").any(func(e:Dictionary)->bool:return e.action == "skill_s"))
	if character == "crt_1":
		_check("ACT03 crt1 input compatibility reaches source46 D: %dHz" % fps,battle.player.definition.actions.skill.animation == "crt1_skill_d" and _events(battle,"skill_started").any(func(e:Dictionary)->bool:return e.action == "skill"))
	traces.append({"kind":"simulated_delta_input","character":character,"fps":fps,"samples":samples})
	return samples

func _test_delta_input_consistency() -> void:
	for character: String in ["crt_0","crt_1"]:
		var reference: Array[Dictionary] = []
		for fps in [30,60,144]:
			var samples: Array[Dictionary] = await _drive_delta(character,fps)
			if fps == 30:
				reference = samples
			else:
				var difference: Variant = null
				for index in range(mini(reference.size(),samples.size())):
					if reference[index] != samples[index]:
						difference = {"tick":index+1,"at_30Hz":reference[index],"actual":samples[index]}
						break
				_check("same source-scheduled input yields identical complete trace: %s/30vs%dHz" % [character,fps],reference == samples,difference)

func _test_focus_pause_and_reentry() -> void:
	# Engineering lifecycle fixture: invokes actual focus notification rather than
	# claiming a native OS focus event or real keyboard observation.
	var battle := _fresh()
	battle.manual_clock = false
	battle._physics_process(0.02)
	_key(KEY_X,true)
	await process_frame
	_check("focus fixture queues an actual unconsumed keyboard event",not battle._key_events.is_empty())
	app.test_mode = false
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	app.test_mode = true
	_check("focus loss reaches real pause and clears queued actions",app.screen == "pause" and battle.paused and battle._key_events.is_empty() and battle._presses.is_empty())
	_key(KEY_X,false)
	await process_frame
	battle._physics_process(0.5)
	_check("focus pause cannot advance source or replay old input",app.session.run.source_ticks == 0 and battle.player.state == "idle")
	app._on_intent("resume",null)
	battle._physics_process(0.02)
	_check("resume discards pre-pause fractional source time",app.screen == "battle" and app.session.run.source_ticks == 0 and battle.player.state == "idle")
	battle._physics_process(0.02)
	_check("resume first full tick has no stale attack",app.session.run.source_ticks == 1 and _events(battle,"basic_started").is_empty())
	_key(KEY_X,true)
	await process_frame
	_check("reentry fixture also has a pending input",not battle._key_events.is_empty())
	app._on_intent("leave",null)
	_key(KEY_X,false)
	await process_frame
	_check("leaving clears old pending input and detaches encounter",not is_instance_valid(battle) or (battle.get_parent() == null and battle._key_events.is_empty()))
	battle = _fresh()
	battle.step({})
	_check("new encounter cannot inherit old action or partial tick",app.session.run.source_ticks == 1 and battle.player.state == "idle" and battle.projectiles.is_empty() and battle._markers.is_empty() and _events(battle,"basic_started").is_empty())

func _finish() -> void:
	var failures := checks.filter(func(c:Dictionary)->bool:return not c.passed).size()
	var report_dir := OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if report_dir.is_empty():
		report_dir = "res://artifacts/leba_act01_20261114"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_dir))
	var file := FileAccess.open(report_dir.path_join("m1_actions_tests.json"),FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"suite":"leba_act01_m1_actions","checks":checks,"failures":failures,"traces":traces,"scope":"Headless Dummy; real Main/Battle. C/Down/Z curves compare controlled original traces. Air X17/21/25/29, recoil and landing compare verified original-clip held polling with temporary readonly flag change; not natural OS input. Z competition follows source scheduling analysis. Input/delta/cleanup fixtures are explicitly labelled; ms float noise normalized only to1e-6ms. No physical keyboard claim.","unverified":["Original natural keyboard C/air X/Down/Z","Native Flash","Physical keyboard and OS focus"]},"\t")+"\n")
		file.close()
	print("M1_ACTIONS_TESTS_RESULT "+JSON.stringify({"checks":checks.size(),"failures":failures}))
	quit(0 if failures == 0 else 1)
