extends SceneTree
## Source1474/1473/731/3833 predicates, with explicit Godot RNG fixtures.
## No claim that a Godot seed reproduces Flash's PRNG or combined damage total.
const MainScene = preload("res://scenes/main.tscn")
const SaveStore = preload("res://scripts/services/save_store.gd")
var app: Node
var checks: Array[Dictionary] = []
var traces: Array[Dictionary] = []
var formal_exists := false
var formal_hash := ""

func _initialize() -> void:call_deferred("_run")

func _check(label: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"name":label,"passed":passed,"detail":detail})
	print(("PASS " if passed else "FAIL ")+label+" "+str(detail))

func _fresh() -> Node2D:
	app.action_lab = false
	app.session.profile = app.saves.default_profile()
	app.session.select_difficulty("expert")
	app._on_intent("select_training_character","crt_0")
	var battle: Node2D = app.battle
	battle.set_physics_process(false)
	battle.manual_clock = true
	battle.step({})
	battle.enemies[0].position = Vector2(550,1000) # Explicit no-contact clock seed.
	return battle

func _press(battle: Node2D, code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	battle._unhandled_input(event)
	battle.step(battle.take_commands())

func _choose(battle: Node2D, direction: Key) -> bool:
	for tick in range(330):
		if int(battle.player.cooldowns.get("skill_q",0)) == 0:break
		battle.step({})
	_press(battle,KEY_Q)
	for tick in range(20):
		if battle.player.state == "skill_q" and battle.player.source_frame == 12:break
		battle.step({})
	if battle.player.state != "skill_q" or battle.player.source_frame != 12:
		_check("actual Q reaches original held12 before ammo selection",false,battle.snapshot())
		return false
	_press(battle,direction)
	var kind := "fire" if direction == KEY_UP else "silver"
	_check("actual Q direction starts only selected independent timer: "+kind,battle.ammo_frames[kind] == 2)
	for tick in range(40):
		if battle.player.state == "idle" and int(battle.ammo_frames[kind]) >= 9:return true
		battle.step({})
	_check("Q selection naturally returns with active ammo: "+kind,false,battle.snapshot())
	return false

func _shoot_x(battle: Node2D) -> Dictionary:
	_press(battle,KEY_X)
	for tick in range(25):
		if not battle.projectiles.is_empty():return battle.projectiles[0]
		battle.step({})
	_check("actual X creates original projectile",false,battle.snapshot())
	return {}

func _test_real_choices_and_visuals() -> void:
	for mode: String in ["default","fire","silver","both"]:
		var battle := _fresh()
		if mode in ["fire","both"] and not _choose(battle,KEY_UP):continue
		if mode in ["silver","both"] and not _choose(battle,KEY_DOWN):continue
		if mode == "both":
			_check("natural second Q keeps original fire and silver clocks concurrently active",int(battle.ammo_frames.fire) >= 9 and int(battle.ammo_frames.fire) <= 355 and int(battle.ammo_frames.silver) >= 9 and int(battle.ammo_frames.silver) <= 355,battle.ammo_frames.duplicate())
		var bullet := _shoot_x(battle)
		if bullet.is_empty():continue
		var expected_key := "projectile_silver" if mode in ["silver","both"] else ("projectile_fire" if mode == "fire" else "projectile")
		_check("actual Q-to-X source selector/texture at birth: "+mode,bullet.visual_key == expected_key and bullet.visual.texture.resource_path == app.database.assets.animations[expected_key].texture and bullet.visual.source_frame == 1 and bullet.key == "projectile",{"visual_key":bullet.visual_key,"texture":bullet.visual.texture.resource_path,"ammo":battle.ammo_frames.duplicate()})
		if mode == "default":continue
		# Actual X projectile then meets a real target. This explicit placement is
		# not a natural-AI trajectory or a claim about a full combination's damage.
		var enemy: Node2D = battle.enemies[0]
		enemy.position = Vector2(250,360.15)
		enemy.hp = 2000
		enemy.definition.max_hp = 2000
		enemy.airborne = false
		enemy.set_action("idle")
		seed(7311474)
		for tick in range(4):
			battle.step({})
			if bullet.targets.has(enemy.identifier):break
		var fire: Array = battle.summons.filter(func(item:Dictionary)->bool:return item.kind == "ammo_fire")
		var silver: bool = battle.enemy_status.get(enemy.identifier,{}).has("silver")
		_check("real "+mode+" X collision preserves independent fire and silver effects",bullet.targets.has(enemy.identifier) and (fire.size() == 1 and bullet.firec == 1 if mode in ["fire","both"] else fire.is_empty()) and (silver if mode in ["silver","both"] else not silver),{"targets":bullet.targets.duplicate(),"fire_count":fire.size(),"silver":silver,"draws":bullet.penetration_draws.duplicate()})
		traces.append({"kind":"actual_Q_direction_natural_timer_then_X_with_explicit_target_position","mode":mode,"visual_key":bullet.visual_key,"ammo":battle.ammo_frames.duplicate(),"seed":7311474,"draws":bullet.penetration_draws.duplicate(),"fire_routes":fire.map(func(item:Dictionary)->String:return str(item.route)),"silver":silver})

func _route_seed(want_a: bool) -> Dictionary:
	# Resolve a concrete deterministic fixture seed, record it, then reset that
	# same seed before invoking the real implementation. Not Flash equivalence.
	for candidate in range(1,128):
		seed(candidate)
		var draw := randf()
		if (draw < 0.3) == want_a:return {"seed":candidate,"draw":draw}
	return {}

func _test_fire_routes_and_cleanup() -> void:
	for route: String in ["a","b"]:
		var fixture := _route_seed(route == "a")
		_check("deterministic Godot seed covers original731 route "+route,not fixture.is_empty(),fixture)
		if fixture.is_empty():continue
		var battle := _fresh()
		seed(int(fixture.seed))
		battle._spawn_fire_blast(Vector2(132.4,344.9),1000)
		var item: Dictionary = battle.summons[0]
		_check("original731 repeated predicate reaches only3 or27 route: "+route,item.route == route and item.key == "ammo_fire_blast_"+route,fixture)
		var first := 3 if route == "a" else 27
		var terminal := 10 if route == "a" else 34
		var samples: Array[int] = []
		var mismatch: Variant = null
		for tick in range(32):
			battle.step({})
			var frame: int = item.visual.source_frame
			samples.append(frame)
			var expected: int = mini(terminal,first+tick)
			if mismatch == null and (frame != expected or int(item.frame) != expected):mismatch = {"tick_after_birth":tick+1,"expected":expected,"visual":frame,"logical":item.frame}
		_check("731 route "+route+" uses source frames then holds terminal without atlas overflow",mismatch == null and samples[-1] == terminal and battle.summons.size() == 1,mismatch)
		_check("held731 cannot invent further collision windows against distant enemy",battle.journal.filter(func(row:Dictionary)->bool:return row.event == "damage").is_empty())
		traces.append({"kind":"static731_predicate_and_stop_with_actual_world_object","route":route,"seed":fixture.seed,"draw":fixture.draw,"frames":samples})
		var visual: Node2D = item.visual
		app._dispose_battle()
		await process_frame
		_check("scene exit releases held731 world object: "+route,not is_instance_valid(battle) and not is_instance_valid(visual))

func _penetration_seeds() -> Dictionary:
	var found := {}
	for candidate in range(1,20001):
		seed(candidate)
		var draws: Array[int] = []
		for index in range(4):draws.append(randi_range(1,100))
		if not found.has("first_stops") and draws[0] < 55:found.first_stops = {"seed":candidate,"draws":draws}
		if not found.has("second_stops") and draws[0] >= 55 and draws[1] < 55:found.second_stops = {"seed":candidate,"draws":draws}
		if not found.has("boundary55_continues") and draws[0] == 55 and draws[1] >= 55:found.boundary55_continues = {"seed":candidate,"draws":draws}
		if found.size() == 3:break
	return found

func _test_penetration_component() -> void:
	var fixtures := _penetration_seeds()
	_check("explicit Godot seeds cover first test second test and exact55 boundary",fixtures.size() == 3,fixtures)
	if fixtures.size() != 3:return
	for projectile: String in ["projectile","projectile_strong"]:
		for frozen: bool in [false,true]:
			for label: String in ["first_stops","second_stops","boundary55_continues"]:
				if frozen and label == "second_stops":continue # Frozen has only one draw per target.
				var fixture: Dictionary = fixtures[label]
				var battle := _fresh()
				var target: Node2D = battle.enemies[0]
				target.position = Vector2(250,360.15)
				var second: Node2D = battle._make_actor("AmmoSecondTarget","enemy",target.definition,Vector2(250,360.15),target.visual_scale)
				battle.enemies.append(second)
				for actor: Node2D in [target,second]:
					actor.hp = 2000
					actor.definition.max_hp = 2000
					if frozen:battle._freeze_target(actor)
				var box: Rect2 = target.hurt_rect()
				_check("same-box fixture intersects both real source target bodies: "+projectile+label+str(frozen),box.intersects(second.hurt_rect()))
				battle._spawn_projectile(battle.player,{"projectile":projectile})
				var bullet: Dictionary = battle.projectiles[-1]
				var per_target := 1 if frozen else 2
				var expected_draws: Array[int] = []
				var expected_targets: Array[String] = []
				var expected_empty := false
				for actor: Node2D in [target,second]:
					if expected_empty:break
					expected_targets.append(actor.identifier)
					for i in range(per_target):
						var value: int = fixture.draws[expected_draws.size()]
						expected_draws.append(value)
						if value < 55:expected_empty = true
				seed(int(fixture.seed))
				battle._projectile_contacts(bullet,box) # Explicit same-box component dispatch.
				var tag := projectile+" "+("frozen " if frozen else "normal ")+label
				_check("original55 strict predicate and independent draw count: "+tag,bullet.penetration_draws == expected_draws and bullet.targets.keys() == expected_targets and bool(bullet.head_empty) == expected_empty and bullet.visual.visible == not expected_empty,{"seed":fixture.seed,"expected_draws":expected_draws,"actual_draws":bullet.penetration_draws.duplicate(),"targets":bullet.targets.keys(),"head_empty":bullet.head_empty})
				battle._projectile_contacts(bullet,box)
				_check("empty head or per-target hita prevents repeat/new target processing: "+tag,bullet.penetration_draws == expected_draws and bullet.targets.keys() == expected_targets)
				traces.append({"kind":"static1474_1473_same_box_real_components_rng_fixture","projectile":projectile,"frozen":frozen,"case":label,"seed":fixture.seed,"expected_draws":expected_draws,"actual_draws":bullet.penetration_draws.duplicate(),"targets":bullet.targets.keys(),"head_empty":bullet.head_empty})

func _run() -> void:
	formal_exists = FileAccess.file_exists("user://profile.json")
	if formal_exists:formal_hash = FileAccess.get_sha256("user://profile.json")
	app = MainScene.instantiate()
	root.add_child(app)
	app.set_process(false)
	_check("ammo suite uses actual Main isolated test startup",app.startup_ok and app.test_mode and app.action_lab)
	if not app.startup_ok:
		_finish()
		return
	app.saves = SaveStore.new("user://act02_ammo/run_%d_%d/profile.json" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()])
	_test_real_choices_and_visuals()
	await _test_fire_routes_and_cleanup()
	_test_penetration_component()
	_check("ammo fixtures never alter formal profile existence or bytes",FileAccess.file_exists("user://profile.json") == formal_exists and (not formal_exists or FileAccess.get_sha256("user://profile.json") == formal_hash))
	app._dispose_battle()
	var drained: bool = await app.audio.stop_and_drain(1.0)
	_check("ammo Dummy playback drains before tree shutdown",drained and app.audio.snapshot().pending_playbacks == 0)
	app.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	var failures := checks.filter(func(row:Dictionary)->bool:return not row.passed).size()
	var output := OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if output.is_empty():output = "res://artifacts/leba_act02_20261115/ammo"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var file := FileAccess.open(output.path_join("act02_ammo_tests.json"),FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"suite":"act02_ammo","checks":checks,"failures":failures,"traces":traces,"scope":"Actual Q/arrow/X input with naturally advancing ammo clocks and source-derived selector priority.731 world route/stop/exit and1474/1473 same-box real-component penetration use explicit recorded Godot RNG seeds and original static predicates; no Flash PRNG equivalence, OS/GPU/native Flash or unverified combined damage total claim."},"\t")+"\n")
		file.close()
	print("ACT02_AMMO_TESTS_RESULT "+JSON.stringify({"checks":checks.size(),"failures":failures}))
	quit(0 if failures == 0 else 1)
