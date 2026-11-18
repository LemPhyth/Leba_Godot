extends SceneTree
## Common action-engine fixtures and actual imported crt0/crt1 combat regression.
## Synthetic short actions test scheduling contracts; they are not claimed as source content.
## Run headless with --audio-driver Dummy --script tests/test_actions.gd -- --test-mode --action-lab.
## No physical audio/UI validation is implied.
const MainScene = preload("res://scenes/main.tscn")
const Actor = preload("res://scripts/combat/combatant.gd")
const SaveStore = preload("res://scripts/services/save_store.gd")
var app: Node
var checks: Array[Dictionary] = []
var traces: Array[Dictionary] = []
var action_events: Array[Dictionary] = []
var action_completions: Array[String] = []
var original_exists := false
var original_hash := ""
var test_root := ""

func _initialize() -> void:
	call_deferred("_run")

func _check(label: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"name":label,"passed":passed,"detail":detail})
	print(("PASS " if passed else "FAIL ")+label+" "+str(detail))

func _capture(actor: Node2D, event: Dictionary) -> void:
	action_events.append({"frame":actor.source_frame,"visual_frame":actor.visual.source_frame,"state":actor.state,"kind":str(event.kind),"id":str(event.get("id",event.get("sound","")))})
	if str(event.kind) == "fixture_interrupt":
		actor.receive_damage(1.0)

func _completed(_actor: Node2D, state: String) -> void:
	action_completions.append(state)

func _fixture_actor(action: Dictionary) -> Node2D:
	action_events.clear()
	action_completions.clear()
	var data: Dictionary = app.database.characters.crt_0.duplicate(true)
	data.actions["fixture"] = action
	var actor: Node2D = Actor.new()
	root.add_child(actor)
	actor.configure("fixture","player",data,app.database.assets)
	actor.action_event.connect(_capture)
	actor.action_finished.connect(_completed)
	actor.set_action("fixture")
	return actor

func _fresh(character := "crt_0", stage_id := "root_2") -> Node2D:
	app.session.select_character(character)
	app.enter_battle(stage_id)
	app.battle.manual_clock = true
	return app.battle

func _events(battle: Node2D, kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Dictionary in battle.journal:
		if str(item.event) == kind:
			result.append(item)
	return result

func _trace(label: String, battle: Node2D, fixture := false) -> void:
	traces.append({"name":label,"fixture":fixture,"snapshot":battle.snapshot().duplicate(true),"journal":battle.journal.duplicate(true)})

func _run() -> void:
	original_exists = FileAccess.file_exists("user://profile.json")
	if original_exists:
		original_hash = FileAccess.get_sha256("user://profile.json")
	test_root = "user://leiba02_actions/run_%d_%d" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	app = MainScene.instantiate()
	root.add_child(app)
	_check("actual main and imported source animations load",app.startup_ok,app.database.issues)
	if not app.startup_ok:
		_finish()
		return
	_check("command-line action lab starts real battle with fresh progress before test fixtures",app.action_lab and app.screen == "battle" and app.session.profile.progress.gold == 0 and app.session.run.character_id == "crt_0")
	app.test_mode = true
	app.saves = SaveStore.new(test_root+"/profile.json")
	app.session.profile = app.saves.default_profile()
	_test_source_sequence()
	_test_simultaneous_events()
	_test_loop_hold_and_completion()
	_test_interruptions()
	_test_combos()
	_test_skill_ownership_and_clocks()
	await _test_s_input()
	await _test_key_event_queue()
	await _test_held_skill_events()
	_test_delayed_marker()
	_test_air_visual_components()
	_test_stage_observer_scope()
	_test_shared_marker_rehits()
	_test_airborne_death()
	_test_enemy_timer_lifecycle()
	await _test_action_lab()
	_check("formal profile remains untouched",FileAccess.file_exists("user://profile.json") == original_exists and (not original_exists or FileAccess.get_sha256("user://profile.json") == original_hash))
	app._dispose_battle()
	var drained: bool = await app.audio.stop_and_drain(1.0)
	_check("dummy audio closes native playback handles",drained and app.audio.snapshot().pending_playbacks == 0)
	app.queue_free()
	await process_frame
	_finish()

func _test_source_sequence() -> void:
	var actor := _fixture_actor({"animation":"player_basic","sequence":[1,2,4,6],"events":[{"frame":4,"kind":"fixture_event","id":"source4"}]})
	var frames: Array[int] = []
	var terminal := {"frame":0}
	actor.action_finished.connect(func(a:Node2D,_state:String):terminal.frame = a.last_processed_frame)
	for tick in range(4):
		actor.advance_tick()
		# The terminal control frame synchronously changes action; sample it in finished.
		frames.append(int(terminal.frame) if actor.state == "idle" else actor.last_processed_frame)
	_check("fixture sparse source sequence preserves explicit skipped frames",frames == [1,2,4,6],frames)
	_check("fixture source4 event fires on third tick exactly once",action_events.size() == 1 and action_events[0].frame == 4 and action_events[0].id == "source4",action_events.duplicate(true))
	_check("finite action completes once then starts idle at its first frame",action_completions == ["fixture"] and actor.state == "idle" and actor.action_age == 0 and actor.source_frame == 1)
	var serial: int = actor.action_serial
	_check("unknown action leaves current state and clock intact",not actor.set_action("missing_action") and actor.action_serial == serial and actor.state == "idle")
	actor.free()
	# Controlled Ruffle fixture t60..76: frame4 redirects to6 in the same tick.
	# The returned parent is sampled on the17th inclusive call; this is not keyboard evidence.
	actor = Actor.new()
	root.add_child(actor)
	actor.configure("source_crt0","player",app.database.characters.crt_0,app.database.assets)
	actor.set_action("basic")
	terminal = {"frame":0}
	actor.action_finished.connect(func(a:Node2D,_state:String):terminal.frame = a.last_processed_frame)
	var fired: Array[Dictionary] = []
	var current_tick := {"value":0}
	actor.action_event.connect(func(a:Node2D,e:Dictionary):
		if e.kind == "projectile":
			fired.append({"tick":current_tick.value,"event_frame":e.frame,"actor_frame":a.source_frame,"visual_frame":a.visual.source_frame}))
	var poses: Array[int] = []
	frames.clear()
	for tick in range(17):
		current_tick.value = tick+1
		actor.advance_tick()
		frames.append(int(terminal.frame) if actor.state == "idle" else actor.last_processed_frame)
		poses.append(actor.visual.source_frame)
	_check("crt0 X returns on17th call matching controlled Ruffle fixture",frames == [1,2,3,6,7,8,9,10,11,12,13,14,15,16,17,18,19] and actor.state == "idle",frames)
	_check("X source8 event and visual align on6th call per controlled fixture",fired == [{"tick":6,"event_frame":8,"actor_frame":8,"visual_frame":8}],fired)
	_check("processed source pose matches controlled trace except terminal parent jump",poses == [1,2,3,6,7,8,9,10,11,12,13,14,15,16,17,18,1],poses)
	actor.free()

func _test_simultaneous_events() -> void:
	var actor := _fixture_actor({"animation":"player_basic","sequence":[1,2,3],"events":[
		{"frame":2,"kind":"sound","id":"sound_a"},{"frame":2,"kind":"sound","id":"sound_b"},{"frame":2,"kind":"projectile","id":"bullet"}]})
	actor.advance_tick()
	_check("events do not fire one source tick early",action_events.is_empty())
	actor.advance_tick()
	_check("same source frame preserves both same-kind events and projectile",action_events.size() == 3 and action_events.map(func(e:Dictionary)->String:return e.id) == ["sound_a","sound_b","bullet"],action_events.duplicate(true))
	_check("all same-frame callbacks see their own source pose and leave it visible",action_events.all(func(e:Dictionary)->bool:return e.visual_frame == e.frame) and actor.visual.source_frame == 2 and actor.source_frame == 2)
	actor.advance_tick()
	_check("same-frame events do not duplicate after action completion",action_events.size() == 3)
	actor.free()

func _test_loop_hold_and_completion() -> void:
	var actor := _fixture_actor({"animation":"player_basic","sequence":[1,2,3],"loop":true,"events":[{"frame":2,"kind":"sound","id":"footstep"}]})
	for tick in range(8):
		actor.advance_tick()
	_check("looping action emits footstep once per loop instead of only first loop",action_events.size() == 3 and action_completions.is_empty() and actor.state == "fixture",action_events.duplicate(true))
	actor.free()
	actor = _fixture_actor({"animation":"player_basic","sequence":[1,2],"hold":true,"events":[{"frame":2,"kind":"fixture_event","id":"settle"}]})
	for tick in range(8):
		actor.advance_tick()
	_check("hold remains on final source frame without repeated one-shot event",actor.state == "fixture" and actor.source_frame == 2 and action_events.size() == 1 and action_completions.is_empty())
	actor.free()
	actor = _fixture_actor({"animation":"player_basic","sequence":[1,2],"next_action":"move"})
	actor.advance_tick()
	actor.advance_tick()
	_check("declared action successor is honored at its first frame",actor.state == "move" and actor.action_age == 0 and actor.source_frame == 1 and action_completions == ["fixture"])
	actor.free()
	actor = _fixture_actor({"animation":"player_basic","sequence":[1]})
	actor.action_finished.connect(func(a:Node2D,_state:String):a.set_action("basic2"))
	actor.advance_tick()
	_check("completion callback successor is not overwritten by old idle fallback",actor.state == "basic2" and actor.action_age == 0 and actor.source_frame == 1)
	actor.free()

func _test_interruptions() -> void:
	var actor := _fixture_actor({"animation":"player_basic","sequence":[1,2,3],"events":[
		{"frame":2,"kind":"fixture_interrupt","id":"hit"},{"frame":2,"kind":"sound","id":"stale_sound"}]})
	actor.advance_tick()
	actor.advance_tick()
	_check("synchronous hit cannot skip new action frame1 using old action cursor",actor.state == "hit" and actor.action_age == 0 and actor.source_frame == 1 and actor.hp == 99.0,action_events.duplicate(true))
	_check("synchronous action change stops remaining old-frame events",action_events.size() == 1 and action_completions.is_empty())
	actor.advance_tick()
	# Entry1 was already displayed during the synchronous callback above. The
	# controlled late-child placement model consumes that entry in that same tick.
	_check("callback-created hit advances to2 after its already displayed entry1",actor.state == "hit" and actor.source_frame == 2 and actor.last_processed_frame == 2 and actor.action_age == 1)
	actor.advance_tick()
	_check("new hit action continues3 without repeating its displayed first frame",actor.state == "hit" and actor.source_frame == 3 and actor.last_processed_frame == 3 and actor.action_age == 2)
	actor.set_action("basic")
	actor.advance_tick()
	var age: int = actor.action_age
	_check("marker damage preserves inner action when reaction is explicitly absent",actor.receive_damage(3.5,false) and actor.state == "basic" and actor.action_age == age and is_equal_approx(actor.hp,95.5))
	_check("lethal damage enters dead and cannot be cancelled into another action",actor.receive_damage(200.0) and actor.hp == 0.0 and actor.state == "dead" and not actor.set_action("idle"))
	_check("dead actor cannot receive another damage settlement",not actor.receive_damage(1.0))
	actor.free()

func _test_combos() -> void:
	var battle := _fresh()
	battle.step({"attack":true})
	while battle.player.source_frame < 10:
		battle.step({"attack":true})
	_check("early new X presses cannot restart or skip first sourced combo window",battle.player.state == "basic" and _events(battle,"basic_started").size() == 1 and _events(battle,"combo_started").is_empty())
	var states := ["basic2","basic3","basic4","basic5","basic6"]
	var window_starts := [10,5,5,18,5]
	for index in range(states.size()):
		for safety in range(40):
			if battle.player.source_frame == int(window_starts[index]):
				break
			battle.step({})
		battle.step({"attack":true})
		_check("new X at source window enters "+states[index],battle.player.state == states[index],{"frame":battle.player.source_frame,"state":battle.player.state})
	for tick in range(25):
		battle.step({})
	var emitted: Array = _events(battle,"projectile_spawn").map(func(e:Dictionary)->int:return int(e.source_frame))
	_check("six X stages emit their distinct sourced projectile frames",emitted == [8,3,3,16,3,6],emitted)
	_check("sixth stage ends in idle without automatic restart",battle.player.state == "idle" and _events(battle,"basic_started").size() == 1 and _events(battle,"combo_started").size() == 5)
	_trace("crt0_six_distinct_X_presses",battle)
	battle = _fresh()
	battle.step({"attack":true})
	for tick in range(25):
		battle.step({})
	_check("one X press naturally ends first stage without auto-combo",battle.player.state == "idle" and _events(battle,"projectile_spawn").size() == 1 and _events(battle,"combo_started").is_empty())

func _test_skill_ownership_and_clocks() -> void:
	var battle := _fresh()
	battle.step({"skill":true})
	_check("crt0 D uses5MP then source recovery and has125-tick cooldown",is_equal_approx(battle.player.mp,95.05) and battle.player.skill_cooldown == 125)
	for tick in range(21):
		battle.step({})
	var before_mp: float = battle.player.mp
	battle.step({"skill_s":true})
	_check("crt0 S owns separate79-tick cooldown and3MP cost",battle.player.state == "skill_s" and battle.player.cooldowns.skill_s == 79 and battle.player.cooldowns.skill == 103 and is_equal_approx(battle.player.mp,before_mp-3.0+0.05))
	for tick in range(78):
		battle.step({})
	_check("S remains locked before its79th subsequent source tick",battle.player.cooldowns.skill_s == 1 and battle.player.cooldowns.skill == 25)
	before_mp = battle.player.mp
	battle.step({"skill_s":true})
	_check("S independently becomes reusable on its79th subsequent tick",battle.player.cooldowns.skill_s == 79 and battle.player.cooldowns.skill == 24 and is_equal_approx(battle.player.mp,before_mp-3.0+0.05))
	_trace("independent_D_S_cooldowns",battle)
	battle = _fresh()
	battle.deal_damage(battle.enemies[0],battle.player,1.0,"fixture: hit-state input boundary")
	battle.step({"skill_s":true})
	_check("crt0 S cannot cancel source hit state or spend MP",battle.player.state == "hit" and battle.player.mp == 100.0 and not battle.player.cooldowns.has("skill_s"))
	battle.step({"skill":true})
	_check("crt0 D is separately allowed to cancel hit",battle.player.state == "skill" and is_equal_approx(battle.player.mp,95.05))
	_trace("hit_cancel_boundary_fixture",battle,true)
	battle = _fresh("crt_1")
	battle.step({"skill":true})
	_check("ACT03 crt1 D uses its own source46 animation and3MP rather than crt0 D",battle.player.state == "skill" and battle.player.parent_frame == 46 and battle.player.definition.actions.skill.animation == "crt1_skill_d" and is_equal_approx(battle.player.mp,97.05))
	battle = _fresh("crt_1")
	battle.step({"skill_s":true})
	_check("crt1 selection drives distinct S animation cost and clock",battle.player.state == "skill_s" and battle.player.definition.actions.skill_s.animation == "crt1_skill_s" and is_equal_approx(battle.player.mp,97.05) and battle.player.cooldowns.skill_s == 79)
	for tick in range(16):
		battle.step({})
	_check("crt1 S plays source1..17 and returns idle",battle.player.state == "idle" and _events(battle,"projectile_spawn").size() == 1 and _events(battle,"projectile_spawn")[0].source_frame == 7)
	_trace("crt1_S_default_source_frames",battle)
	battle = _fresh("crt_1")
	battle.player.mp = 2.0 # Explicit insufficient-resource fixture, not gameplay start balance.
	battle.step({"skill_s":true})
	_check("insufficient S MP rejects action without charging and still naturally recovers",battle.player.state == "idle" and is_equal_approx(battle.player.mp,2.05) and _events(battle,"skill_rejected").back().reason == "mp")
	battle.player.mp = 99.95 # Explicit maximum-boundary fixture.
	for tick in range(3):
		battle.step({})
	_check("source MP recovery caps at actual actor maximum",battle.player.mp == 100.0)

func _test_s_input() -> void:
	var battle := _fresh("crt_1")
	battle.set_physics_process(false)
	battle.manual_clock = false
	await process_frame
	var press := InputEventKey.new()
	press.keycode = KEY_S
	press.physical_keycode = KEY_S
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	await process_frame
	_check("actual S key event reaches common skill_s queue",battle._key_events.any(func(e:Dictionary)->bool:return bool(e.get("skill_s",false))))
	battle._physics_process(0.04)
	_check("one logical and physical S press starts only one skill",_events(battle,"skill_started").size() == 1 and is_equal_approx(battle.player.mp,97.05))
	press = InputEventKey.new()
	press.keycode = KEY_S
	press.physical_keycode = KEY_S
	press.pressed = false
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	await process_frame
	battle._physics_process(0.04)
	_check("S release does not enqueue a second use",_events(battle,"skill_started").size() == 1 and battle._key_events.is_empty())

func _key(code: Key, pressed: bool, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _test_key_event_queue() -> void:
	var battle := _fresh()
	battle.set_physics_process(false)
	battle.manual_clock = false
	await process_frame
	_key(KEY_X,true)
	await process_frame
	battle._physics_process(0.04)
	for tick in range(25):
		battle._physics_process(0.04)
	_check("held X without another keyDown cannot auto-repeat or combo",battle.player.state == "idle" and _events(battle,"basic_started").size() == 1 and _events(battle,"combo_started").is_empty())
	_key(KEY_P,true) # Q is now a real skill; P has no action binding.
	await process_frame
	_check("other keyDown while X held records original Key.isDown88 semantics",battle._key_events.size() == 1 and battle._key_events[0].attack)
	battle._physics_process(0.04)
	_check("other keyDown while X held starts next legal first action",battle.player.state == "basic" and _events(battle,"basic_started").size() == 2)
	_key(KEY_P,false)
	while battle.player.source_frame < 10:
		battle._physics_process(0.04)
	_key(KEY_X,true,true)
	await process_frame
	_check("host X repeat is preserved as a keyDown event",battle._key_events.size() == 1 and battle._key_events[0].attack)
	battle._physics_process(0.04)
	_check("host X repeat inside source10 window can trigger one combo",battle.player.state == "basic2" and _events(battle,"combo_started").size() == 1)
	_key(KEY_X,false)
	await process_frame
	_check("key release itself does not generate an action event",battle._key_events.is_empty())
	_trace("X_held_vs_other_keyDown_vs_host_repeat",battle)
	battle = _fresh()
	var x: float = battle.player.position.x
	battle.step({"axis":1,"key_events":[{},{}]})
	_check("multiple queued key events do not multiply movement in one source tick",is_equal_approx(battle.player.position.x,x+6.0) and app.session.run.source_ticks == 1)
	battle.step({"key_events":[{"skill":true},{"skill":true}]})
	_check("ordered double D events spend once and reject second via cooldown",_events(battle,"skill_started").size() == 1 and _events(battle,"skill_rejected").back().reason == "cooldown" and is_equal_approx(battle.player.mp,95.05))
	battle.set_physics_process(false)
	_key(KEY_X,true)
	await process_frame
	_check("pause cleanup fixture actually has a pending key event",not battle._key_events.is_empty())
	battle.set_paused(true)
	_check("pause clears all input queues to prevent deferred post-resume attacks",battle._key_events.is_empty() and battle._presses.is_empty())
	_key(KEY_X,false)
	battle.set_paused(false)
	await process_frame

func _test_held_skill_events() -> void:
	for example: Array in [[KEY_S,"skill_s",79],[KEY_D,"skill",125]]:
		var battle := _fresh()
		battle.set_physics_process(false)
		battle.manual_clock = false
		await process_frame
		_key(example[0],true)
		await process_frame
		battle._physics_process(0.04)
		for tick in range(int(example[2])):
			battle._physics_process(0.04)
		_check("held skill without keyDown cannot reuse itself after cooldown: "+str(example[1]),_events(battle,"skill_started").size() == 1 and battle.player.cooldowns[example[1]] == 0)
		_key(KEY_P,true) # Preserve unrelated-keyDown coverage as skills expand.
		await process_frame
		_check("other keyDown sees held source skill condition: "+str(example[1]),battle._key_events.size() == 1 and bool(battle._key_events[0].get(example[1],false)))
		battle._physics_process(0.04)
		_check("other keyDown restarts held skill only after normal gates: "+str(example[1]),_events(battle,"skill_started").size() == 2 and battle.player.state == example[1] and battle.player.cooldowns[example[1]] == example[2])
		_key(KEY_P,false)
		_key(example[0],false)
		await process_frame
		_trace("held_skill_keyDown_"+str(example[1]),battle)

func _test_delayed_marker() -> void:
	var battle := _fresh()
	battle.enemies[0].set_action("attack") # Explicit inner-action fixture: no attack is injected into player.
	battle.step({"attack":true})
	for tick in range(30):
		if not _events(battle,"marker_started").is_empty():
			break
		battle.step({})
	_check("source projectile contact starts marker before applying damage",battle.enemies[0].hp == 200.0 and _events(battle,"marker_started").size() == 1)
	battle.step({})
	_check("first marker tick applies5 while airborne outer clip cancels ground attack",battle.enemies[0].hp == 195.0 and battle.enemies[0].airborne and battle.enemies[0].state == "idle" and battle.enemies[0].action_age == 0)
	battle.step({})
	_check("next marker tick applies shared10 without advancing ground animation",battle.enemies[0].hp == 185.0 and battle.enemies[0].airborne and battle.enemies[0].source_frame == 1)
	var source_air := Rect2(-41.21760495,-177.572184095,104.77960371,172.400006745)
	_check("airborne hurt region follows independently extracted source offset",battle.enemies[0].hurt_rect().is_equal_approx(battle.enemies[0].transform_rect(source_air)))
	for tick in range(30):
		if not battle.enemies[0].airborne:
			break
		battle.step({})
	_check("landing restores idle instead of resuming stale ground attack",not battle.enemies[0].airborne and battle.enemies[0].state == "idle" and battle.player.hp == 100.0)
	_trace("source_delayed_marker_inner_action_fixture",battle,true)

func _test_air_visual_components() -> void:
	# Independent source3889 flash and source4028/7175 body, not a baked hit sprite.
	var examples := [
		{"stage":"root_2","sprite":4028,"offset":Vector2(-10.9,-32.05)},
		{"stage":"root_6","sprite":7175,"offset":Vector2(-16.5,-22.95)}]
	for example: Dictionary in examples:
		var battle := _fresh("crt_0",str(example.stage))
		var enemy: Node2D = battle.enemies[0]
		var label := str(example.sprite)
		_check("air body and hit marker are independent imported components: "+label,is_instance_valid(enemy.air_visual) and is_instance_valid(enemy.air_hit_visual) and enemy.air_visual != enemy.air_hit_visual and int(enemy.air_visual.definition.source_sprite_id) == int(example.sprite) and int(enemy.air_hit_visual.definition.source_sprite_id) == 3889)
		for facing in [-1,1]:
			enemy.set_facing(facing)
			var expected_scale: Vector2 = enemy.visual_scale*Vector2(-facing,1)
			var expected_offset: Vector2 = example.offset*expected_scale
			var expected_marker_scale: Vector2 = Vector2(0.70036316,0.8067169)*expected_scale
			_check("air registration and marker matrix survive source-facing flip %s/%d" % [label,facing],enemy.air_visual.scale.is_equal_approx(expected_scale) and enemy.air_hit_visual.position.is_equal_approx(expected_offset) and enemy.air_hit_visual.scale.is_equal_approx(expected_marker_scale),{"offset":enemy.air_hit_visual.position,"scale":enemy.air_hit_visual.scale})
		var initial_pivot: Array = enemy.air_visual.definition.frames[0].pivot
		_check("both air poses retain one registration pivot: "+label,enemy.air_visual.definition.frames[1].pivot == initial_pivot)
		enemy.airborne = true # Explicit component-state fixture, separate from battle gravity tests.
		enemy.vertical_speed = -12.0
		enemy.play_air_hit(10)
		enemy.update_air_visual(10)
		_check("air rise replaces ground rendering and starts flash source1: "+label,not enemy.visual.visible and enemy.air_visual.visible and enemy.air_visual.source_frame == 1 and enemy.air_hit_visual.visible and enemy.air_hit_visual.source_frame == 1)
		enemy.update_air_visual(16)
		_check("independent flash reaches source7 at six ticks after birth: "+label,enemy.air_hit_visual.visible and enemy.air_hit_visual.source_frame == 7)
		enemy.update_air_visual(17)
		_check("flash ends instead of sticking on its last visible source frame: "+label,not enemy.air_hit_visual.visible)
		enemy.play_air_hit(20)
		enemy.vertical_speed = 1.0
		enemy.update_air_visual(20)
		_check("fall pose2 removes flash child even on a fresh hit: "+label,enemy.air_visual.source_frame == 2 and not enemy.air_hit_visual.visible)
		enemy.vertical_speed = -5.0
		enemy.update_air_visual(21)
		_check("removed flash cannot reappear without a new hit event: "+label,not enemy.air_hit_visual.visible)
		enemy.airborne = false
		enemy.update_air_visual(22)
		_check("landing switches to ground component and clears air effects: "+label,enemy.visual.visible and not enemy.air_visual.visible and not enemy.air_hit_visual.visible)

func _test_stage_observer_scope() -> void:
	# Explicit event fixtures isolate observer ownership; actual source rectangles and
	# controlled Ruffle timing are covered separately by test_hit_timeline.gd.
	# Supersedes the old incorrect immediate damage/per-window-claim assertions.
	var source_values := {"root_2":[10.0],"root_4":[2.0,2.0,2.0,2.0],"root_6":[3.5]}
	var source_total := {"root_2":11.0,"root_4":9.0,"root_6":3.5}
	for stage_id: String in source_values:
		var battle := _fresh("crt_0",stage_id)
		_check("stage observer values retain source instance scope: "+stage_id,battle.stage.player_hurt_observers == source_values[stage_id],battle.stage.player_hurt_observers)
		var enemy: Node2D = battle.enemies[0]
		enemy.position = battle.player.position # Explicit guaranteed-overlap fixture.
		battle._on_action_event(enemy,{"kind":"enemy_hit","rect":[-100,-200,200,400],"damage":999.0,"hit_group":"fixture_first"})
		_check("collision callback itself cannot directly spend player HP: "+stage_id,battle.player.hp == 100.0 and battle.player.state == "hit")
		battle.player.position.x = 40.0
		for other: Node2D in battle.enemies:
			other.position.x = 550.0
		if stage_id == "root_6":
			# The boss callback creates child2 after the early HUD poll. Complete the
			# same-tick root poll explicitly; stepping first would already reach3.
			battle._observe_player_hurt()
		else:
			battle.step({})
		_check("hurt2 damage uses scoped observers and Expert timing: "+stage_id,is_equal_approx(battle.player.hp,100.0-float(source_total[stage_id])),battle.player.hp)
		if stage_id == "root_4":
			for index in range(1,4):
				battle.deal_damage(battle.player,battle.enemies[index],200.0,"fixture: internal death leaves outer observer present")
			for tick in range(13):
				battle.step({})
			enemy.position = battle.player.position
			battle._on_action_event(enemy,{"kind":"enemy_hit","rect":[-100,-200,200,400],"damage":999.0,"hit_group":"fixture_after_other_deaths"})
			enemy.position.x = 550.0
			battle.step({})
			_check("root4 internally dead clips still contribute observers plus Expert HUD",app.session.run.enemies_remaining == 1 and is_equal_approx(battle.player.hp,82.0),{"hp":battle.player.hp,"remaining":app.session.run.enemies_remaining})
		_trace("stage_observer_scope_fixture_"+stage_id,battle,true)

func _test_shared_marker_rehits() -> void:
	var battle := _fresh()
	var enemy: Node2D = battle.enemies[0]
	# Explicit two-source simultaneous-contact fixture. No claim that this synthetic
	# contact order reproduces every Flash dispatch order; it guards a single marker.
	battle._start_marker(battle.player,enemy,-5.0,"fixture_contact_a")
	battle._start_marker(battle.player,enemy,-12.0,"fixture_contact_b")
	_check("same-target contacts keep exactly one shared damage marker",battle._markers.size() == 1 and battle._markers.has(enemy.identifier) and battle._markers[enemy.identifier].age == 0)
	_check("each simultaneous contact reapplies gravity and accumulates source0.1",is_equal_approx(enemy.vertical_speed,-12.0) and is_equal_approx(enemy.gravity_acceleration,0.2))
	battle.step({})
	_check("same-tick contacts do not create parallel base5 damage timers",enemy.hp == 195.0 and _events(battle,"damage").size() == 1)
	var original_generation: int = battle._markers[enemy.identifier].generation
	# ACT02 summons_probe original A ticks96..98 / W524..526: a normal-body
	# re-contact while this same air marker is already on2 reapplies gravity,
	# but gotoAndPlay2 does not create a second base5 observer phase. The former
	# age0/reset assertion was only a synthetic scheduling contract, contradicted
	# by those controlled samples. This direct-contact fixture isolates that phase;
	# it does not claim the A/W helper ordering or total85/95 was exercised here.
	battle._start_marker(battle.player,enemy,-5.0,"fixture_rehit_before_common_callback")
	_check("rehit on processed marker2 preserves its phase and reapplies physical assignments",battle._markers.size() == 1 and battle._markers[enemy.identifier].age == 1 and battle._markers[enemy.identifier].generation == original_generation and is_equal_approx(enemy.vertical_speed,-5.0) and is_equal_approx(enemy.gravity_acceleration,0.3))
	battle.step({})
	_check("same marker2 rehit settles only the existing common10 observer phase",enemy.hp == 185.0 and battle._markers.is_empty() and _events(battle,"damage").size() == 2)
	battle.step({})
	_check("same marker2 rehit leaves no parallel or delayed duplicate damage",enemy.hp == 185.0 and battle._markers.is_empty() and _events(battle,"damage").size() == 2)
	_trace("shared_marker_rehit_order_fixture",battle,true)
	battle = _fresh("crt_0","root_4")
	battle._start_marker(battle.player,battle.enemies[0],-5.0,"fixture_enemy0")
	battle._start_marker(battle.player,battle.enemies[1],-5.0,"fixture_enemy1")
	_check("different targets retain separate shared markers",battle._markers.size() == 2 and battle._markers.has("enemy_0") and battle._markers.has("enemy_1"))
	battle.step({})
	battle.step({})
	_check("per-target markers settle independently without damaging other targets",battle.enemies[0].hp == 185.0 and battle.enemies[1].hp == 185.0 and battle.enemies[2].hp == 200.0 and battle.enemies[3].hp == 200.0 and battle._markers.is_empty())

func _test_airborne_death() -> void:
	var battle := _fresh()
	var enemy: Node2D = battle.enemies[0]
	var original_gold: int = app.session.profile.progress.gold
	battle._start_marker(battle.player,enemy,-5.0,"fixture: airborne lethal boundary")
	enemy.position.y = enemy.ground_y-30.0 # Explicit height fixture separates death from landing.
	battle.deal_damage(battle.player,enemy,200.0,"fixture: lethal during airborne clip")
	_check("airborne HP0 defers ground death animation and settlement",enemy.hp == 0.0 and enemy.airborne and enemy.pending_death and enemy.state != "dead" and app.session.run.enemies_remaining == 1 and app.session.profile.progress.gold == original_gold)
	var before_y: float = enemy.position.y
	battle.step({})
	_check("airborne HP0 continues source gravity instead of freezing forever",enemy.position.y < before_y and enemy.pending_death and enemy.airborne)
	_check("airborne HP0 rejects duplicate lethal damage",not battle.deal_damage(battle.player,enemy,1.0,"fixture: duplicate lethal") and _events(battle,"damage").size() == 1)
	var premature_settlement := false
	for tick in range(60):
		if not enemy.airborne:
			break
		premature_settlement = premature_settlement or app.session.run.enemies_remaining != 1
		battle.step({})
	_check("landing creates exactly one ground death entry and keeps reward pending",not enemy.airborne and not enemy.pending_death and enemy.state == "dead" and enemy.source_frame == 1 and not premature_settlement and app.session.run.enemies_remaining == 1 and app.session.profile.progress.gold == original_gold)
	battle.step({})
	_check("landed death source2 still does not settle early",enemy.source_frame == 2 and app.session.run.enemies_remaining == 1)
	battle.step({})
	_check("landed death source3 settles enemy and original reward once",app.session.run.enemies_remaining == 0 and app.session.profile.progress.gold == original_gold+100 and _events(battle,"enemy_settled").size() == 1 and battle.ended)
	battle._on_action_event(enemy,{"kind":"death_settled"})
	_check("duplicate landed death callback cannot settle or reward twice",app.session.profile.progress.gold == original_gold+100 and _events(battle,"enemy_settled").size() == 1)
	_trace("airborne_pending_death_fixture",battle,true)

func _test_enemy_timer_lifecycle() -> void:
	var battle := _fresh("crt_0","root_6")
	# Explicit off-field player fixture isolates source7178 from attack contact.
	battle.player.position = Vector2(-1000,-1000)
	var enemy: Node2D = battle.enemies[0]
	for tick in range(199):
		battle.step({})
	_check("source7178 remains running through tick199",battle._enemy_timers[enemy.identifier].elapsed == 199 and battle._enemy_timers[enemy.identifier].running and _events(battle,"enemy_evade").is_empty())
	battle.step({})
	_check("source7178 tick200 stops timer and enters ground evade frame1",battle._enemy_timers[enemy.identifier].elapsed == 200 and not battle._enemy_timers[enemy.identifier].running and enemy.state == "evade" and enemy.source_frame == 1 and _events(battle,"enemy_evade").size() == 1)
	battle.step({})
	_check("evade source2 event alone restarts stopped timer at zero",enemy.source_frame == 2 and battle._enemy_timers[enemy.identifier].elapsed == 0 and battle._enemy_timers[enemy.identifier].running)
	battle.step({})
	_check("restarted timer advances from one on following source tick",battle._enemy_timers[enemy.identifier].elapsed == 1)
	_trace("ground_timer_200_evade_restart_fixture",battle,true)
	battle = _fresh("crt_0","root_6")
	battle.player.position = Vector2(-1000,-1000)
	enemy = battle.enemies[0]
	for tick in range(199):
		battle.step({})
	battle._start_marker(battle.player,enemy,-12.0,"fixture: airborne when timer expires")
	battle.step({})
	_check("airborne timer expiry stops without forcing a ground evade clip",enemy.airborne and enemy.state != "evade" and battle._enemy_timers[enemy.identifier].elapsed == 200 and not battle._enemy_timers[enemy.identifier].running and _events(battle,"enemy_evade").is_empty())
	for tick in range(260):
		battle.step({})
	_check("landing does not silently restart the stopped source timer",not enemy.airborne and battle._enemy_timers[enemy.identifier].elapsed == 200 and not battle._enemy_timers[enemy.identifier].running and _events(battle,"enemy_evade").is_empty())
	enemy.set_action("evade") # Explicit event fixture, not an invented timer auto-restart.
	battle.step({})
	_check("manual evade entry frame1 still leaves timer stopped",enemy.source_frame == 1 and not battle._enemy_timers[enemy.identifier].running)
	battle.step({})
	_check("actual evade source2 event can restart after airborne expiry",enemy.source_frame == 2 and battle._enemy_timers[enemy.identifier].running and battle._enemy_timers[enemy.identifier].elapsed == 0)
	_trace("airborne_timer_expiry_fixture",battle,true)

func _test_action_lab() -> void:
	_check("test host used real command-line action-lab entry",app.action_lab)
	if not app.action_lab:
		return
	# Original3841 initializes a new profile to80%; the lab keeps that preference.
	_check("action lab is silent through Master bus without changing saved volume",AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")) and is_equal_approx(float(app.session.profile.settings.volume),0.8))
	app.open_action_lab("crt_0")
	var first: Node2D = app.battle
	first.set_physics_process(false)
	first.manual_clock = false
	_key(KEY_F5,true)
	await process_frame
	_key(KEY_F5,false)
	_check("lab F5 toggles genuine battle source-clock stepping",first.manual_clock and app.screen == "battle")
	_key(KEY_X,true)
	await process_frame
	_key(KEY_F6,true)
	await process_frame
	_key(KEY_F6,false)
	_key(KEY_X,false)
	_check("lab F6 consumes real queued input and displays first action frame on first tick",app.session.run.source_ticks == 1 and first.player.state == "basic" and first.player.source_frame == 1 and first.player.last_processed_frame == 1 and first.player.visual.source_frame == 1)
	# Freeze only the test's replacement at tree entry, before setup/rendering
	# can consume host time. F2 still runs the production creation/input path;
	# no source ticks or cooldowns are reset to manufacture an initial snapshot.
	var replacement_clock := {"caught":false,"instance_id":0}
	app.world.child_entered_tree.connect(func(child: Node) -> void:
		if child.name != "Encounter":return
		child.set_physics_process(false)
		child.manual_clock = true
		replacement_clock.caught = true
		replacement_clock.instance_id = child.get_instance_id()
	,CONNECT_ONE_SHOT)
	_key(KEY_F2,true)
	await process_frame
	_key(KEY_F2,false)
	# Godot enables script physics callbacks during ready, after tree entry.
	# manual_clock already protected source time throughout that interval;
	# disable the callback now as in the original deterministic host fixture.
	app.battle.set_physics_process(false)
	var replacement_state := {"callback":replacement_clock.duplicate(),"instance_id":app.battle.get_instance_id(),"source_ticks":app.session.run.source_ticks,"cooldowns":app.battle.player.cooldowns.duplicate(),"manual_clock":app.battle.manual_clock,"physics_processing":app.battle.is_physics_processing()}
	_check("lab F2 replacement source clock is frozen at tree entry",replacement_clock.caught and replacement_clock.instance_id == app.battle.get_instance_id() and app.battle.manual_clock and not app.battle.is_physics_processing(),replacement_state)
	_check("lab F2 replaces encounter using real crt1 data and clean timers",app.session.run.character_id == "crt_1" and app.battle.player.definition.source_crt == 1 and app.session.run.source_ticks == 0 and app.battle.player.cooldowns.is_empty() and (not is_instance_valid(first) or first.get_parent() == null),replacement_state)
	app.session.profile.progress.gold = 123 # Explicit lab-persistence isolation fixture.
	app.save_progress()
	_check("lab save request never creates even isolated profile file",not FileAccess.file_exists(app.saves.path))

func _finish() -> void:
	var failures := 0
	for check: Dictionary in checks:
		if not check.passed:
			failures += 1
	var report := {"suite":"leiba02_actions","godot":Engine.get_version_info(),"checks":checks,"failures":failures,"traces":traces,"test_save_root":test_root,
		"scope":"Headless Godot actual actors, imported animations, 25Hz battle input, synthetic explicitly labelled action scheduling fixtures, Dummy audio events only.",
		"unverified":["Physical audio and visual animation quality","Native Flash event dispatch","Physical keyboard repeats and full original cancellation rules","Exact Flash lethal-hit same-tick scheduling and shared-marker rehit ordering","Arbitrary hurt dispatch outside the separately controlled Ruffle contact cases"]}
	var report_dir := OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if report_dir.is_empty():
		report_dir = "res://artifacts/leiba02_20261112"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_dir))
	var file := FileAccess.open(report_dir.path_join("actions_tests.json"),FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report,"\t")+"\n")
		file.close()
	print("ACTIONS_TESTS_RESULT "+JSON.stringify({"checks":checks.size(),"failures":failures}))
	quit(0 if failures == 0 else 1)
