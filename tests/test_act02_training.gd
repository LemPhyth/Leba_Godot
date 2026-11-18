extends SceneTree
## LEBA-ACT-02: training integration and shared M1 review regressions.
## Source-derived expectations and engineering fixtures are labelled separately.
## --headless --audio-driver Dummy --script tests/test_act02_training.gd -- --test-mode --action-lab
const MainScene = preload("res://scenes/main.tscn")
const SaveStore = preload("res://scripts/services/save_store.gd")
var app: Node
var checks: Array[Dictionary] = []
var traces: Array[Dictionary] = []
var formal_exists := false
var formal_hash := ""

func _initialize() -> void:
	call_deferred("_run")

func _check(label: String, passed: bool, details: Variant = "") -> void:
	checks.append({"name":label,"passed":passed,"details":details})
	print(("PASS " if passed else "FAIL ")+label+" "+str(details))

func _fresh(stage_id := "root_2") -> Node2D:
	app.session.profile = app.saves.default_profile()
	app.session.select_character("crt_0")
	app.session.select_difficulty("expert")
	app.open_action_lab("crt_0",stage_id)
	app.battle.set_physics_process(false)
	app.battle.manual_clock = true
	return app.battle

func _run() -> void:
	formal_exists = FileAccess.file_exists("user://profile.json")
	if formal_exists:formal_hash = FileAccess.get_sha256("user://profile.json")
	app = MainScene.instantiate()
	root.add_child(app)
	_check("ACT02 suite uses actual Main with isolated diagnostic startup",app.startup_ok and app.test_mode and app.action_lab)
	if not app.startup_ok:
		_finish()
		return
	app.saves = SaveStore.new("user://act02_training/run_%d_%d/profile.json" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()])
	_test_fractional_z_drag()
	_test_manual_death_tail()
	_check("ACT02 diagnostic fixtures never write isolated progress",not FileAccess.file_exists(app.saves.path))
	_test_training_entry_and_geometry()
	_test_training_enemy_rules()
	_test_training_restore_timeline()
	_test_training_storage_and_reentry()
	_test_training_death_boundaries()
	_check("ACT02 leaves formal profile existence and hash unchanged",FileAccess.file_exists("user://profile.json") == formal_exists and (not formal_exists or FileAccess.get_sha256("user://profile.json") == formal_hash))
	app._dispose_battle()
	var drained: bool = await app.audio.stop_and_drain(1.0)
	_check("ACT02 Dummy audio releases native playback references",drained and app.audio.snapshot().pending_playbacks == 0)
	app.queue_free()
	await process_frame
	_finish()

func _test_fractional_z_drag() -> void:
	# AS2 Flying moves the matrix by3 source pixels. These three original-stage
	# decimal coordinates are exact integer twips; sixteen +/-3 additions retain
	# their fractional part in the source double->twips conversion. No physics
	# ticks run during this timer-only fixture, so source gravity/clamps cannot
	# hide precision drift. In particular494.9 must first become497.9/491.9.
	for start: float in [494.9,132.4,50.4]:
		for direction: int in [-1,1]:
			var battle := _fresh()
			var enemy: Node2D = battle.enemies[0]
			enemy.position.x = 550.0
			battle.player.set_facing(direction)
			battle.step({"skill_z":true})
			for tick in range(6):battle.step({})
			enemy.position.x = start
			enemy.gravity_acceleration = 0.1 # Explicit timer qualification fixture.
			var hp: float = enemy.hp
			var samples: Array[Dictionary] = []
			var first_difference: Variant = null
			for callback in range(1,17):
				battle.advance_real_time(0.010)
				var expected: float = start+3.0*direction*callback
				var sample := {"callback":callback,"actual":enemy.position.x,"expected":expected,"ms":battle.real_time_ms}
				samples.append(sample)
				if absf(enemy.position.x-expected) > 0.0001 and first_difference == null:first_difference = sample
			_check("source fractional Z drag retains twips over16callbacks: %.2f/%d" % [start,direction],first_difference == null and enemy.hp == hp and battle.real_time_ms == 160.0,{"first_difference":first_difference,"samples":samples})
			traces.append({"kind":"source_integer_twips_with_Godot_timer_fixture","start":start,"direction":direction,"samples":samples})

func _death_tail(manual: bool) -> Dictionary:
	var battle := _fresh()
	var enemy: Node2D = battle.enemies[0]
	var sounds: Array[int] = []
	enemy.action_event.connect(func(_actor: Node2D,event: Dictionary) -> void:
		if event.kind == "sound" and event.get("sound","") == "death":sounds.append(int(event.frame)))
	battle.deal_damage(battle.player,enemy,200.0,"fixture: terminal actor tail after real death settlement",false)
	for tick in range(3):battle.step({})
	_check("death-tail fixture reaches real source3 settlement: "+str(manual),battle.ended and enemy.source_frame == 3 and app.session.run.enemies_remaining == 0 and app.session.profile.progress.gold == 100)
	var source_tick: int = app.session.run.source_ticks
	var frames: Array[int] = []
	for tick in range(12):
		if manual:
			var event := InputEventKey.new()
			event.keycode = KEY_F6
			event.physical_keycode = KEY_F6
			event.pressed = true
			app._input(event) # Real diagnostic dispatch; no OS shutdown event.
		else:
			battle.manual_clock = false
			battle._physics_process(0.04)
		frames.append(enemy.source_frame)
	var result := {"manual":manual,"frames":frames,"sounds":sounds,"source_tick_before":source_tick,"source_tick_after":app.session.run.source_ticks,"gold":app.session.profile.progress.gold,"settlements":battle.journal.filter(func(e:Dictionary)->bool:return e.event == "enemy_settled").size()}
	traces.append({"kind":"actual_F6_vs_continuous_ended_actor_fixture","result":result})
	return result

func _test_manual_death_tail() -> void:
	# Source3897 is15frames, settles on3 and emits sound3896 on13. The adapter
	# must continue that existing actor tail without rerunning combat/rewards.
	var continuous := _death_tail(false)
	var manual := _death_tail(true)
	var expected: Array[int] = []
	for frame in range(4,16):expected.append(frame)
	_check("normal ended processing advances source death4..15 and sound13",continuous.frames == expected and continuous.sounds == [13],continuous)
	_check("F6 ended processing matches actual death tail and sound13",manual.frames == expected and manual.sounds == [13] and manual.frames == continuous.frames,manual)
	_check("death tails cannot replay settlement or advance combat ticks",continuous.gold == 100 and manual.gold == 100 and continuous.settlements == 1 and manual.settlements == 1 and continuous.source_tick_before == continuous.source_tick_after and manual.source_tick_before == manual.source_tick_after)

func _click(id: String) -> bool:
	var button := app.ui.get_button(id) as BaseButton
	if button == null or button.disabled:
		_check("training UI button usable: "+id,false)
		return false
	button.pressed.emit()
	return true

func _click_source(id: String) -> bool:
	# Integration/flow02 separately covers native mouse hit/release dispatch.
	# This existing suite keeps its synchronous actual-button intention path.
	if not is_instance_valid(app.ui.source_menu) or not app.ui.source_menu.buttons.has(id):
		_check("source training UI button exists: "+id,false)
		return false
	var button: BaseButton = app.ui.source_menu.buttons[id]
	if button.disabled:
		_check("source training UI button usable: "+id,false)
		return false
	button.pressed.emit()
	return true

func _training(profile: Dictionary = {}, difficulty := "expert") -> Node2D:
	# Exercise the visible formal3016 path, not the diagnostic lab entry.
	app.action_lab = false
	app.session.profile = app.saves.default_profile() if profile.is_empty() else profile
	app.session.select_difficulty(difficulty)
	app.show_title()
	_click("Training")
	_click("Character_crt_0")
	app.battle.set_physics_process(false)
	app.battle.manual_clock = true
	app._process(0.0)
	return app.battle

func _events(battle: Node2D, kind: String) -> Array:
	return battle.journal.filter(func(e:Dictionary)->bool:return e.event == kind)

func _test_training_entry_and_geometry() -> void:
	var battle := _training()
	_check("visible formal training button selects crt0 root41 without action lab",not app.action_lab and app.screen == "battle" and app.session.run.stage_id == "root_41" and app.session.run.character_id == "crt_0" and app.session.run.mode_id == "training" and battle.is_training())
	_check("source root41 initializes player130 and finite enemy1e22",battle.player.hp == 130.0 and battle.player.definition.max_hp == 130.0 and battle.player.mp == 130.0 and battle.player.definition.max_mp == 130.0 and battle.enemies[0].hp == 1e22 and battle.enemies[0].definition.max_hp == 1e22)
	_check("source default clear cubes200 are profile resources",app.session.profile.progress.clear_cubes == 200 and battle.snapshot().clear_cubes == 200)
	_check("source root41 preserves player and enemy registration coordinates",battle.player.position.distance_to(Vector2(132.4,314.9)) < 0.0001 and battle.enemies[0].position.distance_to(Vector2(412.1,361.0)) < 0.0001 and battle.player.visual_scale.distance_to(Vector2(0.6369171,0.65245056)) < 0.000001 and battle.enemies[0].visual_scale.distance_to(Vector2(0.52941895,0.51246643)) < 0.000001)
	var ground := battle.authored_stage.get_node("SourceGround") as Sprite2D
	var source_ground: Dictionary = app.database.assets.textures.training_ground
	# Enemy placement361 is not the settled floor: later original summons_probe
	# seeds361 then observes360.15 on the following tick. Its motion is compared
	# separately by test_act02_skills; don't bind source geometry to a runtime cap.
	_check("training uses independent source map and ground at original stage positions",battle.authored_stage.get_node("Map").texture.resource_path == app.database.assets.textures.training_map.path and ground.texture.resource_path == source_ground.path and (ground.position+Vector2(source_ground.pivot[0],source_ground.pivot[1])).distance_to(Vector2(305.85,360.15)) < 0.0001 and float(battle.stage.enemy_positions[0][1]) == 361.0)
	var hud: Node2D = app.ui.source_hud
	_check("source depth ownership orders enemy HUD ground player and HP",battle.enemies[0].z_index == 111 and hud.get_parent() == battle and hud.z_index == 567 and ground.z_index == 781 and battle.player.z_index == 801 and hud.z_index+hud.hp_fill.get_parent().z_index == 791)
	_check("training HUD exposes real source buttons and live resources",app.ui.get_button("TrainingRestore") is TextureButton and app.ui.get_button("TrainingStorage") is TextureButton and hud.hp_fill.scale.x == 1.0 and hud.mp_fill.scale.x == 1.0 and hud.state.training and hud.state.clear_cubes == 200)
	_check("training loads original gate BGM",app.audio.snapshot().music_id == "training" and str(app.database.assets.audio.music.training).contains("gate"))
	battle.player.hp = 65.0 # Explicit display-ratio fixture, not an enemy damage claim.
	battle.player.mp = 32.5
	app._process(0.0)
	_check("source HUD fill scales are dynamic actor ratios",is_equal_approx(hud.hp_fill.scale.x,0.5) and is_equal_approx(hud.mp_fill.scale.x,0.25) and hud.state.hp == 65.0 and hud.state.mp == 32.5)

func _test_training_enemy_rules() -> void:
	for difficulty: String in ["expert","master","king"]:
		var battle := _training({},difficulty)
		battle.player.request_hurt() # Isolate the original placed observer from attack initiation.
		battle.step({})
		_check("training observer2 has no ordinary difficulty multiplier or Expert1: "+difficulty,battle.player.source_frame == 2 and battle.player.hp == 128.0 and battle.enemies[0].hp == 1e22 and _events(battle,"damage").filter(func(e:Dictionary)->bool:return e.target == "player").size() == 1,battle.snapshot())
	for offset: float in [-150.0,-100.0,100.0,150.0]:
		var battle := _training()
		var enemy: Node2D = battle.enemies[0]
		enemy.position.x = 300.0
		battle.player.position.x = 300.0+offset
		enemy.set_facing(1 if offset > 0 else -1) # Isolate distance threshold after facing the target.
		var overlap: bool = battle._definition_rect(enemy,"move_rect").intersects(battle.player.gravity_rect())
		battle.step({})
		var expected := 300.0+(signf(offset)*2.0 if absf(offset) > 100.0 else 0.0)
		_check("training movement requires strict beyond100 with move-body overlap: "+str(offset),overlap and absf(enemy.position.x-expected) < 0.0001 and enemy.state != "attack",{"overlap":overlap,"expected":expected,"x":enemy.position.x})
	var battle := _training()
	var enemy: Node2D = battle.enemies[0]
	enemy.position.x = 300.0
	battle.player.position = Vector2(450,-1000) # Explicit no-overlap geometry fixture.
	battle.step({})
	_check("training does not approach using distance alone",enemy.position.x == 300.0)
	battle = _training()
	enemy = battle.enemies[0]
	enemy.position.x = 300.0
	battle.player.position.x = 250.0
	for tick in range(160):battle.step({})
	_check("training close actor cannot inherit ordinary autonomous attacks",battle.player.hp == 130.0 and enemy.state != "attack" and _events(battle,"player_hurt_contact").is_empty())
	battle.player.position.x = 235.0
	battle.step({"skill":true})
	var saw_airborne := false
	for tick in range(21):
		battle.step({})
		saw_airborne = saw_airborne or enemy.airborne
	_check("real D uses shared contact marker and airborne chain against1e22 target",not _events(battle,"marker_started").is_empty() and _events(battle,"damage").any(func(e:Dictionary)->bool:return e.target == "enemy_0" and e.amount == 75.0) and enemy.hp == 1e22 and saw_airborne and battle.player.state == "idle",battle.journal)
	traces.append({"kind":"training_instance_static_source_fixtures_and_actual_D","snapshot":battle.snapshot(),"journal":battle.journal.duplicate(true)})

func _test_training_restore_timeline() -> void:
	# defaults_probe.json: controlled button8495 effects, original frame progression.
	# t645 immediately200/bar7 ->t646130/bar1/Y1 ->t647Y2 initialized.
	var battle := _training()
	battle.step({})
	battle.player.hp = 12.0
	battle.player.mp = 4.0
	battle.player.cooldowns.skill = 80 # Independent unavailable-CD boundary fixture.
	var at: Vector2 = battle.player.position
	var actor_id: int = battle.player.get_instance_id()
	_click("TrainingRestore")
	app._process(0.0)
	_check("8495 immediately assigns200 with empty bar7 without max or actor reset",battle.player.hp == 200.0 and battle.player.mp == 200.0 and battle.player.definition.max_hp == 130.0 and battle.player.definition.max_mp == 130.0 and battle.skill_bar_frame == 7 and battle.player.get_instance_id() == actor_id and battle.player.position == at and app.ui.source_hud.skill_masks.values().all(func(mask:Polygon2D)->bool:return not mask.visible))
	battle.step({})
	_check("first following source tick caps resources and rebuilds bar1 ordinary slots",battle.player.hp == 130.0 and battle.player.mp == 130.0 and battle.skill_bar_frame == 1 and battle.bar_initialization_pending and battle.skill_slots().d.frame == 1 and battle.skill_slots().y.frame == 1 and not battle.skill_slots().y.ready,battle.snapshot())
	battle.step({})
	_check("idle next tick initializes Y2 rather than making every skill ready",not battle.bar_initialization_pending and battle.skill_slots().y.frame == 2 and not battle.skill_slots().y.ready and battle.skill_slots().d.ready,battle.snapshot())
	# A separate original root-owned grenade icon persists across skillbar rebuild.
	battle.grenades.f = {"stock":4,"icon_frame":37,"active":true} # Source t645 fixture.
	_click("TrainingRestore")
	battle.step({})
	var first_icon: int = battle.grenades.f.icon_frame
	battle.step({})
	_check("skillbar restore preserves grenade stock and independent icon clock",battle.grenades.f.stock == 4 and first_icon == 38 and battle.grenades.f.icon_frame == 39,battle.grenades.f)
	battle = _training()
	battle.enemies[0].position.x = 550.0
	battle.step({}) # Complete initial4112 before legal D input.
	battle.step({"skill":true})
	for tick in range(4):battle.step({})
	_check("D restore fixture reaches actual source5 through input",battle.player.state == "skill" and battle.player.source_frame == 5)
	_click("TrainingRestore")
	var observed: Array[Dictionary] = []
	for tick in range(17):
		battle.step({})
		observed.append({"parent":battle.player.parent_frame,"child":battle.player.source_frame,"y":battle.skill_slots().y.frame,"pending":battle.bar_initialization_pending,"hp":battle.player.hp,"mp":battle.player.mp})
	var expected_y: Array[int] = []
	for frame in range(1,18):expected_y.append(frame)
	_check("original D reset Y advances1..17 while4112 waits for basic state",observed.map(func(row:Dictionary)->int:return int(row.y)) == expected_y and observed[0].parent == 13 and observed[0].child == 6 and observed[16].parent == 1 and observed.all(func(row:Dictionary)->bool:return row.pending and row.hp == 130.0 and row.mp == 130.0),observed)
	battle.step({})
	_check("after D return next source tick4112 reinitializes Y2",battle.player.state == "idle" and not battle.bar_initialization_pending and battle.skill_slots().y.frame == 2,battle.snapshot())
	traces.append({"kind":"controlled_original_reset_D_674_to692","samples":observed,"after":battle.snapshot()})
	battle = _training()
	battle.enemies[0].position.x = 550.0
	battle.step({"skill_z":true})
	for tick in range(6):battle.step({})
	var interval_id: int = battle._z_interval_id
	var timeouts: Array = battle._z_timeouts.duplicate(true)
	var source_frame: int = battle.player.source_frame
	_click("TrainingRestore")
	_click("TrainingRestore")
	_check("repeated8495 is not full reset and retains active Z millisecond tasks",battle.player.source_frame == source_frame and battle.player.state == "skill_z" and battle._z_interval_active and battle._z_interval_id == interval_id and battle._z_timeouts == timeouts and battle.skill_bar_frame == 7)

func _test_training_storage_and_reentry() -> void:
	var profile: Dictionary = app.saves.default_profile()
	app.progression.normalize(profile)
	profile.progress.clear_cubes = 77 # Persisted-resource fixture, no training grant.
	profile.progress.gold = 13
	profile.progress.clears = {"root_2":4}
	profile.inventory.haring = 1 # Explicit owned-item fixture, not a free-item product rule.
	var battle := _training(profile)
	battle.player.hp = 91.0
	battle.player.mp = 67.0
	battle.step({"jump":true})
	var source_frame: int = battle.player.source_frame
	var actor_id: int = battle.player.get_instance_id()
	var encounter_id := battle.get_instance_id()
	_click("TrainingStorage")
	_check("source training warehouse preserves actors without imposing engineering pause",app.screen == "training_storage" and not battle.paused and battle.get_instance_id() == encounter_id and battle.player.get_instance_id() == actor_id)
	battle.step({"attack":true})
	battle.advance_real_time(1.0)
	_check("source warehouse continues action and independent real-time clock",battle.player.source_frame == source_frame+1 and battle.real_time_ms == 1000.0)
	var continued_frame: int = battle.player.source_frame
	_click_source("warehouse_rings")
	_click_source("ring_owned")
	_click_source("ring_equip_crt0")
	_check("warehouse equipment changes profile only until new source load",app.session.profile.equipment.rings.crt_0 == 1 and battle.player.definition.max_hp == 130.0 and battle.player.hp == 91.0 and app.screen == "training_storage")
	_click_source("warehouse_close")
	_check("warehouse close preserves same encounter and continuing action",app.screen == "battle" and not battle.paused and battle.get_instance_id() == encounter_id and battle.player.get_instance_id() == actor_id and battle.player.source_frame == continued_frame)
	var loaded: Dictionary = app.saves.load_profile()
	_check("equipment save preserves cubes gold clears and excludes run HP/CD",loaded.status == "loaded" and loaded.profile.equipment.rings.crt_0 == 1 and loaded.profile.progress.clear_cubes == 77 and loaded.profile.progress.gold == 13 and loaded.profile.progress.clears.root_2 == 4 and not loaded.profile.has("run") and not loaded.profile.has("hp") and not loaded.profile.has("cooldowns"),loaded)
	battle = _training(app.session.profile)
	_check("reenter training applies ring once and does not refill persisted cubes",battle.player.hp == 140.0 and battle.player.definition.max_hp == 140.0 and battle.player.mp == 130.0 and battle.snapshot().clear_cubes == 77)
	_click("TrainingRestore")
	battle.step({})
	_check("restore clamps to equipped max140 without applying equipment again",battle.player.hp == 140.0 and battle.player.definition.max_hp == 140.0 and battle.player.mp == 130.0)
	_click("TrainingStorage")
	_click_source("warehouse_rings")
	_click_source("ring_unequip_crt_0")
	_click_source("warehouse_close")
	_check("warehouse unequip also waits for next scene load",app.session.profile.equipment.rings.crt_0 == 0 and battle.player.definition.max_hp == 140.0)
	_click("Pause")
	for tick in range(6):app.ui.source_menu._process(0.04)
	_click_source("dropdown_actions")
	_click_source("menu_return")
	_check("source training return reaches title detaches encounter and clears run",app.screen == "title" and not is_instance_valid(app.battle) and app.session.run.is_empty() and battle.get_parent() == null and battle.paused and battle._key_events.is_empty() and not battle._z_interval_active)
	battle = _training(app.session.profile)
	_check("formal reentry resets transient state but preserves progress",battle.player.hp == 130.0 and battle.player.mp == 130.0 and battle.projectiles.is_empty() and battle._markers.is_empty() and battle._z_timeouts.is_empty() and app.session.run.source_ticks == 0 and app.session.profile.progress.clear_cubes == 77 and app.session.profile.progress.gold == 13 and app.session.profile.progress.clears.root_2 == 4)
	app._on_intent("adventure",null)
	app.enter_battle("root_2")
	battle = app.battle
	battle.set_physics_process(false)
	battle.manual_clock = true
	_check("ordinary root2 does not inherit training stats background or buttons",not battle.is_training() and app.session.run.mode_id == "story" and battle.player.hp == 100.0 and battle.enemies[0].hp == 200.0 and battle._background.resource_path == app.database.assets.textures.forest.path and not (app.ui.get_button("TrainingRestore") != null) and not (app.ui.get_button("TrainingStorage") != null) and not battle.restore_training())

func _test_training_death_boundaries() -> void:
	# Synthetic lethal damage is explicit: ordinary damage cannot practically
	# deplete1e22. It checks original death cleanup without inventing train victory.
	var battle := _training()
	var before: Dictionary = app.session.profile.progress.duplicate(true)
	var enemy: Node2D = battle.enemies[0]
	var enemy_id := enemy.get_instance_id()
	battle.deal_damage(battle.player,enemy,1e22,"fixture: training enemy lethal boundary",false)
	for tick in range(20):battle.step({})
	_check("training enemy death never rewards wins advances or respawns",enemy.hp == 0.0 and enemy.get_instance_id() == enemy_id and app.screen == "battle" and not battle.ended and app.session.run.outcome == "running" and app.session.profile.progress == before and _events(battle,"training_enemy_dead").size() == 1 and _events(battle,"finished").is_empty(),battle.snapshot())
	battle = _training()
	battle.enemies[0].position.x = 550.0
	battle.step({"skill_z":true})
	for tick in range(6):battle.step({})
	_check("training lethal-player fixture owns active Z work",battle._z_interval_active and not battle._z_timeouts.is_empty())
	battle.deal_damage(battle.enemies[0],battle.player,999.0,"fixture: source6917 training defeat boundary",false)
	battle.step({})
	_check("training permits player defeat with original parent29 and clears owned work",app.screen == "result" and app.session.run.outcome == "defeat" and battle.player.state == "dead" and battle.player.parent_frame == 29 and not battle._z_interval_active and battle._z_timeouts.is_empty() and battle.projectiles.is_empty() and battle._markers.is_empty() and battle._key_events.is_empty())
	for tick in range(35):battle.step({})
	_check("training player death reaches original30 frame hold without duplicate result",battle.player.source_frame == 30 and _events(battle,"finished").size() == 1 and app.session.profile.progress.clears.is_empty() and app.session.profile.progress.gold == 0)
	_click_source("failure_retry")
	battle = app.battle
	battle.set_physics_process(false)
	battle.manual_clock = true
	_check("formal training defeat retry recreates original initialization",app.screen == "battle" and app.session.run.stage_id == "root_41" and battle.player.hp == 130.0 and battle.player.mp == 130.0 and battle.enemies[0].hp == 1e22 and app.session.run.source_ticks == 0 and battle._z_timeouts.is_empty() and not battle.ended)

func _finish() -> void:
	var failures := checks.filter(func(c:Dictionary)->bool:return not c.passed).size()
	var report_dir := OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if report_dir.is_empty():report_dir = "res://artifacts/leba_act02_20261115"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_dir))
	var file := FileAccess.open(report_dir.path_join("act02_training_tests.json"),FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"suite":"leba_act02_training","checks":checks,"failures":failures,"traces":traces,"scope":"Headless Dummy actual Main/Battle and visible formal Training/restore/storage/retry button signals. Source root41 instance facts and controlled defaults_probe restore timeline are independent expectations. Twips, death, equipment and boundary conditions use labelled fixtures; not OS keyboard/GPU/native Flash. B default skill completion and native auto-save/settings UI are not claimed."},"\t")+"\n")
		file.close()
	print("ACT02_TRAINING_TESTS_RESULT "+JSON.stringify({"checks":checks.size(),"failures":failures}))
	quit(0 if failures == 0 else 1)
