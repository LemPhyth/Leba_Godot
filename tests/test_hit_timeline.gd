extends SceneTree
## Controlled-source comparison, not physical keyboard/native Flash validation.
## Source logs: artifacts/leiba02_20261112/{action_probe,hit_probe}.json.
## Fixtures explicitly set positions/seek enemy frames; actual collision and damage
## use Battle.step. The scheduling model is checked against observed sample order.
## Run headless --audio-driver Dummy --script tests/test_hit_timeline.gd -- --test-mode --action-lab
const MainScene = preload("res://scenes/main.tscn")
const SaveStore = preload("res://scripts/services/save_store.gd")
var app: Node
var checks: Array[Dictionary] = []
var traces: Array[Dictionary] = []
var original_exists := false
var original_hash := ""

func _initialize() -> void:
	call_deferred("_run")

func _check(label: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"name":label,"passed":passed,"detail":detail})
	print(("PASS " if passed else "FAIL ")+label+" "+str(detail))

func _fresh(stage_id := "root_2", difficulty := "expert", character := "crt_0") -> Node2D:
	app.session.profile = app.saves.default_profile()
	app.session.profile.selection.difficulty_id = difficulty
	app.session.select_character(character)
	app.enter_battle(stage_id)
	app.battle.manual_clock = true
	return app.battle

func _events(battle: Node2D, kind: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for event: Dictionary in battle.journal:
		if str(event.event) == kind:
			found.append(event)
	return found

func _sample(battle: Node2D) -> Dictionary:
	return {"tick":app.session.run.source_ticks,"hurt":battle.player.source_frame if battle.player.state == "hit" else 0,"hp":battle.player.hp,"enemy_frame":battle.enemies[0].source_frame,"state":battle.player.state}

func _record(label: String, battle: Node2D, samples: Array[Dictionary]) -> void:
	traces.append({"name":label,"fixture":true,"samples":samples,"journal":battle.journal.duplicate(true)})

func _isolate_player(battle: Node2D) -> void:
	battle.player.position.x = 40.0
	for enemy: Node2D in battle.enemies:
		enemy.position.x = 550.0

func _run() -> void:
	original_exists = FileAccess.file_exists("user://profile.json")
	if original_exists:
		original_hash = FileAccess.get_sha256("user://profile.json")
	app = MainScene.instantiate()
	root.add_child(app)
	_check("real main loads source hurt assets and data",app.startup_ok,app.database.issues)
	if app.startup_ok:
		app.test_mode = true
		app.saves = SaveStore.new("user://leiba02_hit_timeline/run_%d_%d/profile.json" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()])
		for difficulty: String in ["expert","master","king"]:
			_test_real_4030_contact(difficulty)
			_test_real_7176_contact(difficulty)
		_test_hurt_reentry_and_cancel()
		_test_dead_root_observers()
		_test_difficulty_hp()
		_test_hurt_components()
		_check("formal profile is unchanged",FileAccess.file_exists("user://profile.json") == original_exists and (not original_exists or FileAccess.get_sha256("user://profile.json") == original_hash))
		_check("action-lab fixture never saves even its isolated profile",not FileAccess.file_exists(app.saves.path))
		app._dispose_battle()
		var drained: bool = await app.audio.stop_and_drain(1.0)
		_check("Dummy audio releases tracked native playback",drained and app.audio.snapshot().pending_playbacks == 0)
	app.queue_free()
	await process_frame
	_finish()

func _test_real_4030_contact(difficulty: String) -> void:
	var battle := _fresh("root_2",difficulty)
	var enemy: Node2D = battle.enemies[0]
	battle.player.position.x = 390.0
	enemy.position.x = 400.0
	enemy.set_action("attack")
	enemy.seek_action_frame(25) # Pre-window fixture; contact itself uses the real source box.
	var samples: Array[Dictionary] = []
	for tick in range(3):
		battle.player.position.x = 390.0 # Same controlled overlap placement as source probe.
		battle.step({})
		samples.append(_sample(battle))
	var expected_hp := 89.0 if difficulty == "expert" else 90.0
	_check("4030 contact first creates hurt1 without immediate damage: "+difficulty,samples[0].hurt == 1 and samples[0].hp == 100.0 and samples[0].enemy_frame == 26,samples[0])
	_check("4030 next tick hurt2 receives observed source damage: "+difficulty,samples[1].hurt == 2 and samples[1].hp == expected_hp and samples[1].enemy_frame == 27,samples[1])
	_check("same-parent repeat contact advances hurt3 without resetting: "+difficulty,samples[2].hurt == 3 and samples[2].hp == expected_hp and samples[2].enemy_frame == 28,samples[2])
	var contacts := _events(battle,"player_hurt_contact")
	_check("all three real source contact frames remain observable: "+difficulty,contacts.map(func(e:Dictionary)->int:return int(e.frame)) == [26,27,28],contacts)
	var damages := _events(battle,"damage").map(func(e:Dictionary)->float:return float(e.amount))
	_check("Expert early HUD and root observer remain separate: "+difficulty,damages == ([1.0,10.0] if difficulty == "expert" else [10.0]),damages)
	battle.player.position.x = 40.0
	for tick in range(11):
		battle.step({})
		samples.append(_sample(battle))
	var hurt_frames := samples.map(func(s:Dictionary)->int:return int(s.hurt))
	_check("4030 hit child advances1..13 then returns on14th sample: "+difficulty,hurt_frames == [1,2,3,4,5,6,7,8,9,10,11,12,13,0] and battle.player.hp == expected_hp,hurt_frames)
	_record("source_collision_4030_"+difficulty,battle,samples)

func _test_real_7176_contact(difficulty: String) -> void:
	var battle := _fresh("root_6",difficulty)
	var enemy: Node2D = battle.enemies[0]
	battle.player.position.x = 300.0
	enemy.position.x = 400.0
	enemy.set_action("ranged")
	enemy.seek_action_frame(67)
	var samples: Array[Dictionary] = []
	for tick in range(6):
		battle.player.position.x = 300.0
		battle.step({})
		samples.append(_sample(battle))
	_check("7176 new-child seek2 receives3.5 at late root poll: "+difficulty,samples[0].hurt == 2 and samples[0].hp == 96.5 and samples[0].enemy_frame == 68,samples[0])
	_check("7176 existing-child seek2 advances3 before next poll: "+difficulty,samples[1].hurt == 3 and samples[1].hp == 96.5 and samples[1].enemy_frame == 69,samples[1])
	var contacts := _events(battle,"player_hurt_contact")
	_check("7176 actual two-frame overlap is not a per-window claim: "+difficulty,contacts.map(func(e:Dictionary)->int:return int(e.frame)) == [68,69],contacts)
	var damages := _events(battle,"damage")
	_check("7176 late hurt2 does not receive earlier Expert HUD poll: "+difficulty,damages.size() == 1 and damages[0].amount == 3.5 and battle.player.hp == 96.5,damages)
	_record("source_collision_7176_"+difficulty,battle,samples)

func _test_hurt_reentry_and_cancel() -> void:
	var battle := _fresh()
	_isolate_player(battle)
	battle.player.request_hurt()
	_check("new hurt request displays source1 before the next tick",battle.player.source_frame == 1 and battle.player.hp == 100.0 and battle.player.hurt_visual.source_frame == 1)
	battle.step({})
	var serial: int = battle.player.action_serial
	battle.player.request_hurt()
	_check("same-parent goto preserves child cursor and action identity",battle.player.source_frame == 2 and battle.player.action_serial == serial and battle.player.hp == 89.0)
	battle.step({})
	_check("same-parent goto cannot rerun hurt2 on following tick",battle.player.source_frame == 3 and battle.player.hp == 89.0)
	battle.player.request_hurt(2)
	_check("existing-child explicit seek2 scheduling model leaves source3",battle.player.source_frame == 3 and battle.player.hp == 89.0)
	battle.player.seek_action_frame(2)
	battle.step({})
	_check("controlled explicit seek2 before tick advances past damage observer",battle.player.source_frame == 3 and battle.player.hp == 89.0)
	battle = _fresh()
	_isolate_player(battle)
	battle.player.request_hurt()
	battle.step({"skill":true})
	_check("D cancellation before hurt2 removes the pending hurt state",battle.player.state == "skill" and battle.player.hp == 100.0 and not battle.player.hurt_visual.visible)
	for tick in range(22):
		battle.step({})
	_check("cancelled hurt leaves no delayed damage callback",battle.player.hp == 100.0 and _events(battle,"damage").filter(func(e:Dictionary)->bool:return e.target == "player").is_empty())
	battle = _fresh()
	_isolate_player(battle)
	battle.player.request_hurt()
	battle.set_paused(true)
	battle.step({})
	_check("pause freezes actual hurt cursor before damage frame",battle.player.source_frame == 1 and battle.player.hp == 100.0)
	battle.set_paused(false)
	battle.step({})
	_check("resume continues hurt2 once with authoritative observers",battle.player.source_frame == 2 and battle.player.hp == 89.0)

func _test_dead_root_observers() -> void:
	var battle := _fresh("root_4")
	_isolate_player(battle)
	var samples: Array[Dictionary] = []
	battle.player.request_hurt()
	samples.append(_sample(battle))
	battle.step({})
	samples.append(_sample(battle))
	_check("root4 controlled hurt2 includes Expert1 plus four root2 observers",battle.player.hp == 91.0 and _events(battle,"damage").map(func(e:Dictionary)->float:return float(e.amount)) == [1.0,2.0,2.0,2.0,2.0])
	for tick in range(12):
		battle.step({})
	battle.deal_damage(battle.player,battle.enemies[0],200.0,"fixture: source probe sets one internal enemy HP0")
	for tick in range(3):
		battle.step({})
	_check("one enemy internal death settles without removing root observer",app.session.run.enemies_remaining == 3 and battle.stage.player_hurt_observers == [2.0,2.0,2.0,2.0])
	battle.player.request_hurt()
	battle.step({})
	samples.append(_sample(battle))
	_check("root4 after internal death still loses9 at next hurt2",battle.player.hp == 82.0,samples.back())
	_record("root4_dead_internal_clip_keeps_observer",battle,samples)

func _test_difficulty_hp() -> void:
	# Static original source6968 frame1 facts, separate from controlled contact timing.
	for stage_id: String in ["root_2","root_4","root_6"]:
		for difficulty: String in ["expert","master","king"]:
			var multiplier: float = {"expert":1.0,"master":1.5,"king":2.0}[difficulty]
			var source_hp := 400.0 if stage_id == "root_6" else 200.0
			var battle := _fresh(stage_id,difficulty)
			var actual: Array = battle.enemies.map(func(e:Node2D)->float:return e.hp)
			_check("source6968 applies difficulty to HP and maxHP once: %s/%s" % [stage_id,difficulty],battle.enemies.all(func(e:Node2D)->bool:return e.hp == source_hp*multiplier and e.definition.max_hp == source_hp*multiplier),actual)
			battle = _fresh(stage_id,difficulty)
			_check("stage reentry cannot multiply shared enemy definition again: %s/%s" % [stage_id,difficulty],battle.enemies[0].hp == source_hp*multiplier and app.database.enemy_definition(str(battle.stage.enemy_type)).max_hp == source_hp)

func _test_hurt_components() -> void:
	for character: String in ["crt_0","crt_1"]:
		var battle := _fresh("root_2","expert",character)
		_isolate_player(battle)
		var actor: Node2D = battle.player
		var source_offset := Vector2(17.2,35.15) if character == "crt_0" else Vector2(14.7,35.15)
		_check("hurt body and orange glow are independently imported: "+character,is_instance_valid(actor.hurt_visual) and actor.hurt_visual != actor.visual and int(actor.hurt_visual.definition.source_sprite_id) == 4689)
		for facing in [-1,1]:
			actor.set_facing(facing)
			_check("hurt source registration mirrors with actor once: %s/%d" % [character,facing],actor.hurt_visual.position.is_equal_approx(source_offset*actor.visual.scale) and actor.hurt_visual.scale.is_equal_approx(actor.visual.scale),{"offset":actor.hurt_visual.position,"scale":actor.hurt_visual.scale})
		var sounds: Array[Dictionary] = []
		actor.action_event.connect(func(a:Node2D,e:Dictionary):
			if e.kind == "sound":
				sounds.append({"id":e.sound,"frame":a.source_frame,"body":a.visual.source_frame,"fx":a.hurt_visual.source_frame}))
		actor.request_hurt()
		_check("hurt frame1 exposes FX1 without early frame2 sound: "+character,actor.hurt_visual.visible and actor.hurt_visual.source_frame == 1 and sounds.is_empty())
		battle.step({})
		_check("hurt2 sound callback sees matching body and glow source2: "+character,sounds == [{"id":"player_hit_fx","frame":2,"body":2,"fx":2}],sounds)
		for tick in range(6):
			battle.step({})
		var r: Array = actor.hurt_visual.frame.region
		var region := Rect2i(int(r[0]),int(r[1]),int(r[2]),int(r[3]))
		var image: Image = actor.hurt_visual.texture.get_image().get_region(region)
		_check("imported FX8 is genuinely transparent instead of a stuck glow: "+character,actor.hurt_visual.source_frame == 8 and not image.get_used_rect().has_area(),image.get_used_rect())
		for tick in range(6):
			battle.step({})
		_check("hurt completion hides child FX and does not repeat its sound: "+character,actor.state == "idle" and not actor.hurt_visual.visible and sounds.size() == 1)

func _finish() -> void:
	var failures := 0
	for check: Dictionary in checks:
		if not check.passed:
			failures += 1
	var report := {"suite":"leiba02_hit_timeline","checks":checks,"failures":failures,"traces":traces,"godot":Engine.get_version_info(),"evidence":"Original controlled Ruffle clip/position fixtures with real hitTest; not natural keyboard or native Flash. Same-child explicit seek advancement is the scheduling model fitted to these samples.","unverified":["Native Flash scheduling","Physical keyboard play","Arbitrary overlap and multi-attacker dispatch equivalence outside these controlled cases"]}
	var report_dir := OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if report_dir.is_empty():
		report_dir = "res://artifacts/leiba02_20261112"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_dir))
	var file := FileAccess.open(report_dir.path_join("hit_timeline_tests.json"),FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report,"\t")+"\n")
		file.close()
	print("HIT_TIMELINE_TESTS_RESULT "+JSON.stringify({"checks":checks.size(),"failures":failures}))
	quit(0 if failures == 0 else 1)
