extends SceneTree
## Real scene/Node regression carried forward from ticket01 and calibrated for LEIBA-02.
## Source superseded: mode-before-character, X total5, D total75, absent MP recovery,
## unconditional enemy pursuit, immediate player damage/per-window hit claiming,
## and root4 as a terminal stage. Coverage remains below.
## Only explicitly labelled boundary fixtures alter HP/MP.
## Run: Godot --headless --path godot --script res://tests/test_gameplay.gd -- --test-mode
const MainScene = preload("res://scenes/main.tscn")
const SaveStore = preload("res://scripts/services/save_store.gd")
const SourceClock = preload("res://scripts/core/source_clock.gd")
var app: Node
var checks: Array[Dictionary] = []
var scenarios: Array[Dictionary] = []
var test_root := ""
var original_hash := ""
var original_exists := false
var input_observations: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(name_: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"name":name_,"passed":passed,"detail":detail})
	print(("PASS " if passed else "FAIL ") + name_ + " " + str(detail))

func _click(name_: String) -> bool:
	var button: BaseButton = app.ui.get_button(name_) as BaseButton
	if button == null and is_instance_valid(app.ui.source_menu):
		button = app.ui.source_menu.buttons.get(name_) as BaseButton
	if button == null or button.disabled:
		_check("button usable: " + name_,false)
		return false
	button.pressed.emit()
	return true

func _enter_from_intro() -> void:
	_click("EnterBattle")
	# Source opening dialogue is a normal UI gate, not a fixture bypass of combat.
	if app.screen == "dialogue":
		_click("DialogueSkip")

func _continue_from_result() -> void:
	_click("Continue")
	if app.screen == "dialogue":
		_click("DialogueSkip")

func _record(label: String, fixture := false) -> void:
	if is_instance_valid(app.battle):
		scenarios.append({"name":label,"fixture":fixture,"snapshot":app.battle.snapshot().duplicate(true),"journal":app.battle.journal.duplicate(true)})

func _fresh(stage_id := "root_2") -> Node2D:
	app.enter_battle(stage_id)
	app.battle.manual_clock = true
	return app.battle

func _events(battle: Node2D, kind: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for item: Dictionary in battle.journal:
		if str(item.event) == kind:
			found.append(item)
	return found

func _queued_action(battle: Node2D, action: String) -> bool:
	return battle._presses.has(action) or battle._key_events.any(func(e:Dictionary)->bool:return bool(e.get(action,false)))

func _damage_sum(battle: Node2D, target: String) -> float:
	var total := 0.0
	for item: Dictionary in _events(battle,"damage"):
		if str(item.target) == target:
			total += float(item.amount)
	return total

func _run() -> void:
	test_root = "user://gameplay_tests/run_%d_%d" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	original_exists = FileAccess.file_exists("user://profile.json")
	if original_exists:
		original_hash = FileAccess.get_sha256("user://profile.json")
	_test_clock()
	app = MainScene.instantiate()
	root.add_child(app)
	_check("main scene boots with imported runtime resources",app.startup_ok,{"screen":app.screen,"issues":app.database.issues})
	if not app.startup_ok:
		_finish()
		return
	# _ready has only read its startup path. All subsequent test mutations use a unique path.
	app.test_mode = true
	app.saves = SaveStore.new(test_root + "/profile.json")
	app.session.profile = app.saves.default_profile()
	app.show_title()
	await _test_input_events()
	app.show_title()
	_test_menu()
	await _test_movement_pause_hud()
	_test_projectile()
	_test_projectile_multiple_targets()
	_test_enemy_attack()
	_test_skill()
	_test_negative_fixtures()
	_test_death_fixture()
	_test_natural_campaign()
	_test_reentry_and_persistence()
	_check("formal profile remains untouched",FileAccess.file_exists("user://profile.json") == original_exists and (not original_exists or FileAccess.get_sha256("user://profile.json") == original_hash))
	app._dispose_battle()
	# Verify native playbacks have actually retired before quitting the test host.
	var drained: bool = await app.audio.stop_and_drain(1.0)
	var stopped_audio: Dictionary = app.audio.snapshot()
	_check("audio shutdown releases every tracked native playback",drained and stopped_audio.pending_playbacks == 0 and not stopped_audio.draining,stopped_audio)
	app.queue_free()
	await process_frame
	_finish()

func _test_clock() -> void:
	for fps in [30,60,144]:
		var clock := SourceClock.new()
		var total := 0
		for frame in range(fps):
			total += clock.consume(1.0/float(fps))
		_check("one second at %d FPS gives 25 source ticks" % fps,total == 25 and clock.ticks == 25,{"ticks":total,"remainder":clock.accumulator})
	var clock := SourceClock.new()
	_check("invalid clock deltas cannot advance source time",clock.consume(-1) == 0 and clock.consume(NAN) == 0 and clock.consume(INF) == 0 and clock.ticks == 0)
	clock.consume(0.02)
	clock.reset()
	_check("pause clock reset discards partial tick",clock.consume(0.02) == 0)

func _send_key(kind: String, code: Key, pressed: bool, echo := false, physical_override := 0) -> void:
	var event := InputEventKey.new()
	event.pressed = pressed
	event.echo = echo
	if kind != "physical_only":
		event.keycode = code
	if kind != "keycode_only":
		event.physical_keycode = physical_override if physical_override != 0 else code
	if pressed and code >= KEY_A and code <= KEY_Z:
		event.unicode = int(code)
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	input_observations.append({"kind":kind,"keycode":event.keycode,"physical_keycode":event.physical_keycode,"pressed":pressed,"echo":echo,
		"matches_skill":event.is_action("skill"),"matches_attack":event.is_action("attack"),"matches_pause":event.is_action("pause"),
		"axis":Input.get_axis("move_left","move_right"),"screen":app.screen})

func _input_battle() -> Node2D:
	var battle := _fresh()
	# Exercise _physics_process's real Input.get_axis and _presses path with exact deltas.
	# Disable only engine scheduling; no test passes command dictionaries to step here.
	battle.set_physics_process(false)
	battle.manual_clock = false
	return battle

func _test_input_events() -> void:
	for kind: String in ["keycode_only","physical_only"]:
		var battle := _input_battle()
		await process_frame
		var pause_button: BaseButton = app.ui.get_button("Pause")
		pause_button.grab_focus()
		_send_key(kind,KEY_D,true)
		await process_frame
		_check("%s D reaches battle unhandled-input queue despite focused HUD" % kind,_queued_action(battle,"skill"),{"queue":battle._key_events.duplicate(true),"focus":str(root.gui_get_focus_owner())})
		battle._physics_process(0.04)
		_check("%s D new press starts exactly one skill plus one source MP tick" % kind,is_equal_approx(battle.player.mp,95.05) and _events(battle,"skill_started").size() == 1)
		_send_key(kind,KEY_D,false)
		await process_frame
		battle._physics_process(0.04)
		_check("%s D release does not enqueue another use" % kind,not _queued_action(battle,"skill") and _events(battle,"skill_started").size() == 1 and is_equal_approx(battle.player.mp,95.10))
		_record("input_skill_"+kind)

		battle = _input_battle()
		await process_frame
		_send_key(kind,KEY_D,true,true)
		await process_frame
		battle._physics_process(0.04)
		# Source keyDown listeners do not filter host repeat events; cooldown gates reuse.
		_check("%s D repeat is a source keyDown event subject to normal startup gates" % kind,is_equal_approx(battle.player.mp,95.05) and _events(battle,"skill_started").size() == 1 and battle.player.state == "skill")
		_send_key(kind,KEY_D,false)

		battle = _input_battle()
		await process_frame
		_send_key(kind,KEY_X,true)
		await process_frame
		battle._physics_process(0.04)
		_check("%s X new press enters normal attack through actual input" % kind,battle.player.state == "basic" and _events(battle,"basic_started").size() == 1)
		_send_key(kind,KEY_X,false)
		for tick in range(24):
			battle._physics_process(0.04)
		_check("%s X release does not auto-repeat attacks" % kind,_events(battle,"basic_started").size() == 1 and _events(battle,"projectile_spawn").size() == 1)

		battle = _input_battle()
		await process_frame
		var start: Vector2 = battle.player.position
		_send_key(kind,KEY_RIGHT,true)
		await process_frame
		for tick in range(10):
			battle._physics_process(0.04)
		_check("%s held right drives ten ticks from one key press" % kind,is_equal_approx(battle.player.position.x,start.x+60) and battle.player.facing == 1,{"actual_x":battle.player.position.x,"axis":Input.get_axis("move_left","move_right")})
		_send_key(kind,KEY_RIGHT,false)
		await process_frame
		battle._physics_process(0.04)
		_check("%s right release stops displacement and enters source parent3" % kind,is_equal_approx(battle.player.position.x,start.x+60) and battle.player.parent_frame == 3 and is_zero_approx(Input.get_axis("move_left","move_right")))
		battle._physics_process(0.04)
		_check("%s movement recovery returns parent1 on its following control tick" % kind,battle.player.state == "idle" and battle.player.parent_frame == 1 and is_equal_approx(battle.player.position.x,start.x+60))
		_send_key(kind,KEY_LEFT,true)
		await process_frame
		battle._physics_process(0.04)
		_check("%s left press reverses direction through input map" % kind,is_equal_approx(battle.player.position.x,start.x+54) and battle.player.facing == -1)
		_send_key(kind,KEY_LEFT,false)
		await process_frame
		battle._physics_process(0.04)
		_record("input_held_movement_"+kind)

		_send_key(kind,KEY_ESCAPE,true)
		await process_frame
		_check("%s Escape reaches Main and pauses" % kind,app.screen == "pause" and battle.paused)
		_send_key(kind,KEY_ESCAPE,true,true)
		await process_frame
		_check("%s Escape echo cannot toggle resume" % kind,app.screen == "pause" and battle.paused)
		_send_key(kind,KEY_ESCAPE,false)
		await process_frame
		_check("%s Escape release cannot toggle resume" % kind,app.screen == "pause" and battle.paused)
		_send_key(kind,KEY_ESCAPE,true)
		await process_frame
		_check("%s second Escape press resumes" % kind,app.screen == "battle" and not battle.paused)
		_send_key(kind,KEY_ESCAPE,false)
		await process_frame

	# Reproduce the exact mismatched native event observed through Sky in the real window.
	var legacy_action := "test_legacy_physical_only_escape"
	InputMap.add_action(legacy_action)
	var legacy_binding := InputEventKey.new()
	legacy_binding.physical_keycode = KEY_ESCAPE
	InputMap.action_add_event(legacy_action,legacy_binding)
	var observed_event := InputEventKey.new()
	observed_event.keycode = KEY_ESCAPE
	observed_event.physical_keycode = 4194313
	observed_event.pressed = true
	_check("physical-only mapping reproduces Sky Escape mismatch",not observed_event.is_action(legacy_action) and observed_event.is_action("pause"),{"logical":observed_event.keycode,"physical":observed_event.physical_keycode,"legacy_matches":observed_event.is_action(legacy_action),"current_matches":observed_event.is_action("pause")})
	InputMap.erase_action(legacy_action)
	var battle := _input_battle()
	await process_frame
	_send_key("mismatched_physical",KEY_ESCAPE,true,false,4194313)
	await process_frame
	_check("Sky Escape logical4194305 physical4194313 still pauses",app.screen == "pause" and battle.paused)
	_send_key("mismatched_physical",KEY_ESCAPE,false,false,4194313)
	await process_frame
	_send_key("mismatched_physical",KEY_ESCAPE,true,false,4194313)
	await process_frame
	_check("Sky Escape second distinct press resumes",app.screen == "battle" and not battle.paused)
	_send_key("mismatched_physical",KEY_ESCAPE,false,false,4194313)
	await process_frame
	_send_key("both",KEY_D,true)
	await process_frame
	battle._physics_process(0.04)
	_check("logical plus physical mapping does not double-charge one D event",is_equal_approx(battle.player.mp,95.05) and _events(battle,"skill_started").size() == 1)
	_send_key("both",KEY_D,false)
	await process_frame
	_record("input_mismatched_native_event")

func _test_menu() -> void:
	_check("initial screen is title",app.screen == "title")
	_click("Start")
	_check("source title opens character selection before difficulty",app.screen == "characters")
	var second_character: Button = app.ui.get_button("Character_crt_1")
	_check("source-backed second character is selectable",not second_character.disabled)
	var third_character: Button = app.ui.get_button("Character_crt_2")
	_check("source-backed third character is selectable",not third_character.disabled)
	var all_disabled := true
	var fourth_character: Button = app.ui.get_button("Character_crt_3")
	_check("source-backed fourth character is selectable",not fourth_character.disabled)
	var fifth_character: Button = app.ui.get_button("Character_crt_4")
	_check("source-backed fifth character is selectable",not fifth_character.disabled)
	for index in [5]:
		var button: Button = app.ui.get_button("Character_crt_%d" % index)
		all_disabled = all_disabled and button.disabled and not button.tooltip_text.is_empty()
	_check("remaining unimplemented character entrance is explained",all_disabled)
	app._on_intent("select_character","crt_5")
	_check("disabled character cannot change authoritative selection",app.session.profile.selection.character_id == "crt_0")
	_click("Character_crt_0")
	_check("character selection opens original difficulty step",app.screen == "difficulty")
	for id: String in ["expert","master","king"]:
		var button: Button = app.ui.get_button("Difficulty_"+id)
		_check("default source difficulty is available: "+id,not button.disabled)
	app._on_intent("select_mode","tower")
	_check("guard still rejects unimplemented mode intent",app.screen == "difficulty" and app.session.profile.selection.mode_id == "story")
	_click("Difficulty_expert")
	_check("difficulty selection reaches root2 intro",app.screen == "intro" and app.selected_stage == "root_2" and app.session.profile.selection.difficulty_id == "expert")
	_enter_from_intro()
	app.battle.manual_clock = true
	var initial: Dictionary = app.battle.snapshot()
	_check("intro enters a live encounter with selected character",app.screen == "battle" and app.session.run.character_id == "crt_0" and initial.hp == 100 and initial.mp == 100 and initial.remaining == 1,initial)
	# Saved Node2D Vector2 values use float32, unlike the former JSON double array.
	var spawn: Array = app.battle.stage.enemy_positions[0]
	_check("root2 source placement is retained before first gravity-floor settlement",Vector2(spawn[0],spawn[1]).is_equal_approx(Vector2(411.2,363.7)) and app.battle.player.position.is_equal_approx(Vector2(129.35,312.9)) and app.battle.enemies[0].position.is_equal_approx(Vector2(411.2,360.15)),{"authored_spawn":spawn,"player":app.battle.player.position,"enemy":app.battle.enemies[0].position})

func _test_movement_pause_hud() -> void:
	var battle: Node2D = app.battle
	var start: Vector2 = battle.player.position
	for tick in range(10):
		battle.step({"axis":1})
	_check("held right moves 6 stage units per source tick",is_equal_approx(battle.player.position.x,start.x+60) and battle.player.facing == 1)
	battle.step({"axis":-1})
	_check("turning left updates facing and visual transform",is_equal_approx(battle.player.position.x,start.x+54) and battle.player.facing == -1 and battle.player.visual.scale.x < 0)
	battle.step({"axis":0})
	_check("releasing movement first enters source parent3",battle.player.parent_frame == 3)
	battle.step({})
	_check("movement recovery control then returns idle parent1",battle.player.state == "idle" and battle.player.parent_frame == 1)
	# The original HUD menu now overlays live combat. Engineering pause remains
	# the actual Esc input route; retain the existing paused-state assertions.
	_send_key("physical_only",KEY_ESCAPE,true)
	await process_frame
	_send_key("physical_only",KEY_ESCAPE,false)
	await process_frame
	var paused_tick: int = app.session.run.source_ticks
	var paused_x: float = battle.player.position.x
	battle.step({"axis":1,"skill":true})
	_check("paused encounter ignores actions and movement",app.screen == "pause" and app.session.run.source_ticks == paused_tick and battle.player.position.x == paused_x and battle.player.mp == 100)
	_click("Resume")
	_check("resume restores battle HUD",app.screen == "battle" and not battle.paused)
	app._process(0.0)
	_check("source HUD fills and state read authoritative HP MP and enemy count",is_equal_approx(app.ui.source_hud.hp_fill.scale.x,battle.player.hp/battle.player.definition.max_hp) and is_equal_approx(app.ui.source_hud.mp_fill.scale.x,battle.player.mp/battle.player.definition.max_mp) and app.ui.source_hud.state.remaining == app.session.run.enemies_remaining)
	_record("movement_pause_hud")

func _test_projectile() -> void:
	var battle := _fresh()
	var start_x: float = battle.player.position.x
	battle.step({"attack":true})
	var saw_spawn := false
	var lifetime_ticks := 0
	var spawn_frame := -1
	for tick in range(30):
		if not battle.projectiles.is_empty():
			saw_spawn = true
			lifetime_ticks += 1
		for item: Dictionary in _events(battle,"projectile_spawn"):
			spawn_frame = int(item.source_frame)
		# New source10 input is a legitimate combo, not a rejected restart.
		# Restrict this first-shot regression to repeated presses before that window.
		battle.step({"axis":1,"attack":tick < 6})
	_check("X emits projectile only at source animation frame8",saw_spawn and spawn_frame == 8 and _events(battle,"projectile_spawn").size() == 1,{"events":_events(battle,"projectile_spawn")})
	_check("projectile lives ten source ticks then is removed",lifetime_ticks == 10 and battle.projectiles.is_empty(),{"observed_ticks":lifetime_ticks})
	_check("crt0 projectile settles source5 plus common10 once",_damage_sum(battle,"enemy_0") == 15 and battle.enemies[0].hp == 185,{"enemy_hp":battle.enemies[0].hp,"damage":_events(battle,"damage")})
	_check("repeated attack input does not restart active basic action",_events(battle,"basic_started").size() == 1)
	_check("movement resumes only after basic action ends",battle.player.position.x > start_x)
	_record("normal_projectile")

func _test_projectile_multiple_targets() -> void:
	# Root4's original layout supplies two targets ahead of the player; no layout fixture.
	var battle := _fresh("root_4")
	# Original default passper55 makes penetration conditional. This recorded
	# Godot seed gives55/99 then83/68: both normal-hit pairs pass the strict<55
	# stop checks. It is a controlled pass case, not Flash PRNG equivalence.
	seed(265)
	battle.step({"attack":true})
	for tick in range(25):
		battle.step({})
	_check("source penetration pass seed permits one original-layout bullet to hit two targets independently",_damage_sum(battle,"enemy_0") == 15 and _damage_sum(battle,"enemy_1") == 15 and _events(battle,"projectile_spawn").size() == 1,{"seed":265,"damage":_events(battle,"damage")})
	_check("bullet does not hit targets behind its firing direction",_damage_sum(battle,"enemy_2") == 0 and _damage_sum(battle,"enemy_3") == 0)
	_record("projectile_per_target_markers")

func _test_enemy_attack() -> void:
	var battle := _fresh()
	for tick in range(29):
		battle.step({"axis":1})
	var hit_frame := -1
	var first_contact: Dictionary = {}
	for tick in range(70):
		var before_hp: float = battle.player.hp
		var before_x: float = battle.player.position.x
		battle.step({})
		if first_contact.is_empty() and not _events(battle,"player_hurt_contact").is_empty():
			first_contact = {"hp":battle.player.hp,"hurt_frame":battle.player.source_frame,"enemy_frame":battle.enemies[0].source_frame,"x":battle.player.position.x,"push":battle.player.position.x-before_x}
		if battle.player.hp < before_hp:
			hit_frame = battle.enemies[0].last_processed_frame
			break
	_check("enemy proximity AI starts attack and hits in frames26..28",hit_frame >= 26 and hit_frame <= 28,{"observed_enemy_source_frame":hit_frame})
	_check("real first contact pushes10 and creates hurt1 without immediate damage",first_contact.hp == 100.0 and first_contact.hurt_frame == 1 and first_contact.enemy_frame == 26 and is_equal_approx(float(first_contact.push),-10.0),first_contact)
	_check("next contact pushes10 while hurt2 polls Expert1 and root10",battle.player.hp == 89 and battle.player.state == "hit" and battle.player.source_frame == 2 and is_equal_approx(battle.player.position.x,float(first_contact.x)-10.0),battle.snapshot())
	var hit_x: float = battle.player.position.x
	battle.step({"axis":1})
	_check("hurt input stays locked after two pushes move player outside third box",is_equal_approx(battle.player.position.x,hit_x) and _events(battle,"player_hurt_contact").map(func(e:Dictionary)->int:return int(e.frame)) == [26,27])
	for tick in range(13):
		battle.step({})
	_check("same-parent contacts do not replay hurt2 observer damage",battle.player.hp == 89 and _damage_sum(battle,"player") == 11 and _events(battle,"player_hurt_contact").map(func(e:Dictionary)->int:return int(e.frame)) == [26,27])
	_check("player completes hit animation and returns idle",battle.player.state == "idle")
	app._process(0.0)
	_check("source HUD immediately reflects real enemy damage",is_equal_approx(app.ui.source_hud.hp_fill.scale.x,89.0/battle.player.definition.max_hp) and app.ui.source_hud.state.hp == 89.0)
	_record("enemy_attack_and_player_recovery")

func _test_skill() -> void:
	var battle := _fresh()
	battle.step({"skill":true})
	_check("D charges 5MP with natural0.05 recovery and starts source sequence",is_equal_approx(battle.player.mp,95.05) and battle.player.state == "skill" and battle.player.skill_cooldown == 125)
	var hit_frames: Array[int] = []
	var damage_before := 0.0
	for tick in range(21):
		battle.step({})
		var damage_after := _damage_sum(battle,"enemy_0")
		if damage_after != damage_before:
			hit_frames.append(battle.player.last_processed_frame)
			damage_before = damage_after
	var window_ok := not hit_frames.is_empty()
	for frame in hit_frames:
		window_ok = window_ok and frame >= 9 and frame <= 20
	_check("D delayed damage follows hit window8..18 within two source ticks",window_ok,{"observed_damage_source_frames":hit_frames})
	_check("D settles source5+70 then common10 per target",battle.enemies[0].hp == 115 and damage_before == 85,{"damage":damage_before,"remaining_hp":battle.enemies[0].hp,"basis":"AS2 plus Ruffle D200→125→115; native Flash unverified"})
	_check("D ends and returns to idle at its source end",battle.player.state == "idle")
	battle.step({"skill":true})
	_check("cooldown rejects repeated D while natural MP recovery continues",is_equal_approx(battle.player.mp,96.15) and _events(battle,"skill_rejected").back().reason == "cooldown")
	for tick in range(102):
		battle.step({})
	_check("D cooldown remains locked after124 subsequent source ticks",battle.player.skill_cooldown == 1,{"cooldown":battle.player.skill_cooldown})
	battle.step({"skill":true})
	_check("D becomes usable after125 source ticks with MP capped between uses",is_equal_approx(battle.player.mp,95.05) and battle.player.skill_cooldown == 125,{"mp":battle.player.mp,"cooldown":battle.player.skill_cooldown})
	app._process(0.0)
	var hud: Node2D = app.ui.source_hud
	var d_mask: Polygon2D = hud.skill_masks.d
	_check("source HUD follows live damage mana and cooldown mask",is_equal_approx(hud.hp_fill.scale.x,battle.player.hp/battle.player.definition.max_hp) and is_equal_approx(hud.mp_fill.scale.x,battle.player.mp/battle.player.definition.max_mp) and hud.state.cooldowns.skill == battle.player.skill_cooldown and d_mask.visible and d_mask.polygon.size() >= 3,{"hud_mp_ratio":hud.mp_fill.scale.x,"actor_mp":battle.player.mp,"slot":hud.state.skill_slots.d,"mask_visible":d_mask.visible})
	_record("skill_window_and_cooldown")

func _test_negative_fixtures() -> void:
	var battle := _fresh()
	battle.player.mp = 4 # Explicit insufficient-resource boundary fixture.
	battle.step({"skill":true})
	_check("fixture insufficient MP rejects D with feedback while recovering",is_equal_approx(battle.player.mp,4.05) and battle.player.state != "skill" and _events(battle,"skill_rejected").back().reason == "mp" and app.ui._toast.text.contains("MP"))
	_record("insufficient_mp_fixture",true)
	battle = _fresh()
	# Use the public damage chain to create a death boundary, not a campaign victory.
	battle.deal_damage(battle.enemies[0],battle.player,100,"test fixture: lethal player damage")
	battle.step({})
	_check("fixture player death reaches defeat result once",app.screen == "result" and app.session.run.outcome == "defeat" and _events(battle,"finished").size() == 1)
	_record("player_death_fixture",true)
	_click("failure_retry")
	app.battle.manual_clock = true
	_check("defeat retry resets HP MP enemies and time",app.screen == "battle" and app.battle.player.hp == 100 and app.battle.player.mp == 100 and app.session.run.enemies_remaining == 1 and app.session.run.source_ticks == 0)

func _test_death_fixture() -> void:
	var battle := _fresh()
	var before_gold: int = app.session.profile.progress.gold
	var enemy: Node2D = battle.enemies[0]
	battle.deal_damage(battle.player,enemy,200,"test fixture: lethal enemy damage")
	_check("fixture HP0 starts death without immediate kill settlement",enemy.hp == 0 and enemy.state == "dead" and app.session.run.enemies_remaining == 1)
	battle.step({})
	battle.step({})
	_check("death remains unsettled before source frame3",app.session.run.enemies_remaining == 1)
	battle.step({})
	_check("death source frame3 settles enemy and victory",app.session.run.enemies_remaining == 0 and app.session.profile.progress.gold == before_gold+100 and app.screen == "result")
	var reward_gold: int = app.session.profile.progress.gold
	for tick in range(30):
		battle.step({})
	battle._on_action_event(enemy,{"kind":"death_settled"})
	_check("death duplicate callbacks cannot reward or count twice",app.session.profile.progress.gold == reward_gold and app.session.run.enemies_remaining == 0 and _events(battle,"enemy_settled").size() == 1 and not app.session.settle_enemy(enemy.identifier,100))
	_record("enemy_death_fixture",true)

func _autoplay(battle: Node2D, budget: int) -> Dictionary:
	# Legal player commands only: travel edge to edge, face the field, fire D and X.
	# No injected HP, enemy positions, damage, pause, victory or cooldown changes.
	var travel_direction := -1
	var phase := "travel"
	var steps := 0
	for tick in range(budget):
		if battle.ended:
			break
		var command: Dictionary = {}
		var actor: Node2D = battle.player
		var target_x: float = float(battle.stage.bounds[0]) + 6.0 if travel_direction < 0 else float(battle.stage.bounds[1]) - 6.0
		if phase == "travel":
			command.axis = travel_direction
			if absf(actor.position.x-target_x) <= 7.0:
				phase = "face"
		elif phase == "face":
			command.axis = -travel_direction
			if actor.state in ["idle","move"]:
				phase = "fire"
		elif phase == "fire":
			if actor.skill_cooldown == 0 and actor.mp >= 5:
				command.skill = true
				if actor.state in ["idle","move","basic","hit"]:
					phase = "recover"
			elif actor.state in ["idle","move"]:
				command.attack = true
		elif phase == "recover" and actor.state in ["idle","move"]:
			travel_direction *= -1
			phase = "travel"
		battle.step(command)
		steps += 1
	return {"ticks":steps,"outcome":app.session.run.outcome,"snapshot":battle.snapshot()}

func _test_natural_campaign() -> void:
	# Reset progress from labelled boundary fixtures; this campaign earns all rewards by input.
	app.session.profile = app.saves.default_profile()
	app.show_title()
	_click("Start")
	_click("Character_crt_0")
	_click("Difficulty_expert")
	_enter_from_intro()
	app.battle.manual_clock = true
	var first: Dictionary = _autoplay(app.battle,2500)
	_check("legal input strategy wins first original encounter",first.outcome == "victory",first)
	_record("natural_campaign_root2")
	if first.outcome != "victory":
		return
	_check("first real win records original100 gold and clear",app.session.profile.progress.gold == 100 and app.session.profile.progress.clears.get("root_2",0) == 1)
	_continue_from_result()
	_check("first result continues through root4 intro",app.screen == "intro" and app.selected_stage == "root_4")
	_enter_from_intro()
	app.battle.manual_clock = true
	var battle: Node2D = app.battle
	_check("second encounter initializes four enemies and fresh actor state",battle.enemies.size() == 4 and app.session.run.enemies_remaining == 4 and battle.player.hp == 100 and battle.player.mp == 100 and battle.projectiles.is_empty())
	var positions: Array[float] = [494.9,411.45,168.5,50.4]
	var positions_ok: bool = battle.player.position.is_equal_approx(Vector2(273.35,314.9))
	for index in range(4):
		positions_ok = positions_ok and is_equal_approx(float(battle.stage.enemy_positions[index][1]),363.7) and battle.enemies[index].position.is_equal_approx(Vector2(positions[index],360.15))
	_check("root4 source placements survive transition with initial gravity settlement",positions_ok)
	var second: Dictionary = _autoplay(battle,4000)
	_check("legal input strategy wins four-enemy encounter",second.outcome == "victory",second)
	_record("natural_campaign_root4")
	if second.outcome == "victory":
		_check("two real wins persist500 total gold and both clears",app.session.profile.progress.gold == 500 and app.session.profile.progress.clears.get("root_2",0) == 1 and app.session.profile.progress.clears.get("root_4",0) == 1)
		_check("new source-backed root6 continuation is available",not (app.ui.get_button("Continue") as Button).disabled and app.database.stages.root_4.next_stage == "root_6")

func _test_reentry_and_persistence() -> void:
	if app.screen != "result":
		app._on_intent("leave",null)
	else:
		_click("Menu")
	_check("result or battle exit reaches reusable character menu",app.screen == "characters" and not is_instance_valid(app.battle) and app.session.run.is_empty())
	var saved: Dictionary = SaveStore.new(app.saves.path).load_profile()
	_check("fresh SaveStore reloads authoritative campaign progress",saved.ok and saved.profile == app.session.profile,{"status":saved.status,"actual":saved.profile,"expected":app.session.profile,"cube_types":[typeof(saved.profile.progress.clear_cubes),typeof(app.session.profile.progress.clear_cubes)],"ring_types":[typeof(saved.profile.equipment.rings.crt_0),typeof(app.session.profile.equipment.rings.crt_0)],"owned_types":[typeof(saved.profile.inventory.haring),typeof(app.session.profile.inventory.haring)]})
	_click("Character_crt_0")
	_click("Difficulty_expert")
	_enter_from_intro()
	app.battle.manual_clock = true
	var old: Node2D = app.battle
	old.step({"attack":true})
	for tick in range(7):
		old.step({})
	_check("cleanup test actually has an active projectile",old.projectiles.size() == 1)
	app._on_intent("leave",null)
	_check("leaving detaches encounter and clears run",old.get_parent() == null and old.paused and app.session.run.is_empty())
	_click("Character_crt_0")
	_click("Difficulty_expert")
	_enter_from_intro()
	app.battle.manual_clock = true
	_check("reentry has fresh actor projectile timer and event state",app.battle != old and app.battle.projectiles.is_empty() and app.battle.player.hp == 100 and app.battle.player.mp == 100 and app.battle.player.skill_cooldown == 0 and app.session.run.source_ticks == 0 and app.session.run.enemies_remaining == 1 and app.battle.journal.size() == 1)
	_record("reentry_clean_state")

func _finish() -> void:
	var failures := 0
	for check: Dictionary in checks:
		if not check.passed:
			failures += 1
	var report := {"suite":"ticket01_gameplay_calibrated_for_leiba02","checks":checks,"failures":failures,"scenarios":scenarios,"test_save_root":test_root,"input_observations":input_observations,
		"scope":"Actual Godot main scene, Nodes, UI Button signals, Input.parse_input_event through actual Main/Battle input handlers and physics input consumption, imported resources, manual 25Hz source ticks and real save IO. Boundary fixtures explicitly labelled. Natural campaign uses legal movement/X/D only.",
		"source_corrections":["Character before difficulty replaces ticket01 mode-first assumption","crt0 common source marker contributes10 to X and D","D source damage settles as75 then10; no longer final75","MP recovers0.05/source tick","Enemy approach is contact-gated","root4 now continues to root6","Source keyDown includes host repeats; held X alone creates no event","Enemy source contact pushes10 while player hit input is locked","Controlled real-contact Ruffle probe:4030 first hurt1 keeps100HP; hurt2 has root10 plus Expert HUD1; repeated same-parent contacts do not reset child"],
		"unverified":["Native Flash runtime comparison (separate Ruffle source probe exists)","Physical keyboard and rendered UI appearance (separate interactive QA)","Physical speaker output","Exact Flash hitTest equivalence and same-tick event dispatch"]}
	var report_dir := OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if report_dir.is_empty():
		report_dir = "res://artifacts/leiba02_20261112"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_dir))
	var file := FileAccess.open(report_dir.path_join("gameplay_tests.json"),FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report,"\t")+"\n")
		file.close()
	print("GAMEPLAY_TESTS_RESULT " + JSON.stringify({"checks":checks.size(),"failures":failures}))
	quit(0 if failures == 0 else 1)
