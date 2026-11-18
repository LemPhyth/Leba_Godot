extends SceneTree
## GL framebuffer checks of real Main/Battle. Controlled input and declared
## contact fixtures; these images do not claim natural Flash comparison.
const MainScene = preload("res://scenes/main.tscn")
var app: Node
var out := "res://artifacts/leba_act03_20261116/render"
var files: Array[String] = []
var failed := false

func _initialize() -> void:call_deferred("_run")

func _capture(name: String) -> void:
	if app.screen == "battle":app.ui.update_hud(app.battle.snapshot(),false)
	await process_frame
	RenderingServer.force_draw(false)
	var bitmap := root.get_texture().get_image()
	var path := out+"/"+name+".png"
	if bitmap == null or bitmap.is_empty() or bitmap.save_png(path) != OK:failed = true
	else:files.append(path)

func _fresh() -> Node2D:
	app._start_training("crt_1")
	var battle: Node2D = app.battle
	battle.manual_clock = true
	battle.set_physics_process(false)
	for i in range(450):battle.step({})
	return battle

func _key(battle: Node2D, code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	battle._unhandled_input(event)
	battle.step(battle.take_commands())
	event.pressed = false
	battle._unhandled_input(event)

func _run() -> void:
	if not OS.get_environment("LEBA_TEST_ARTIFACT_DIR").is_empty():out = OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	root.size = Vector2i(550,400)
	app = MainScene.instantiate()
	root.add_child(app)
	if not app.startup_ok:quit(1);return
	await _capture("title")
	app.ui.get_button("Training").pressed.emit()
	await _capture("training_characters")
	var battle := _fresh()
	await _capture("crt1_training")
	_key(battle,KEY_C)
	for i in range(17):battle.step({"held_attack":true})
	await _capture("crt1_air_x")
	battle = _fresh()
	_key(battle,KEY_W)
	for i in range(12):battle.step({"held_w":true,"right":true,"axis":1.0})
	await _capture("crt1_w_ammo")
	battle = _fresh()
	_key(battle,KEY_Q)
	for i in range(25):battle.step({})
	await _capture("crt1_q_buff")
	battle = _fresh()
	_key(battle,KEY_T)
	for i in range(14):battle.step({})
	await _capture("crt1_t_cutin")
	for i in range(22):battle.step({})
	await _capture("crt1_t_ground")
	for i in range(145):battle.step({})
	await _capture("crt1_t_air")
	battle = _fresh()
	# One contact-position fixture for the actual F projectile/shot marker visual.
	battle.enemies[0].position = Vector2(260,battle.enemies[0].ground_y)
	battle.enemies[0].hp = 2000
	_key(battle,KEY_F)
	for i in range(20):
		battle.step({})
		if not battle._crt1_shots.is_empty():break
	if battle._crt1_shots.is_empty():failed = true;push_error("Actual F projectile did not create a shot marker in the declared contact fixture")
	await _capture("crt1_head_shot_marker")
	app.session.select_mode("story")
	app.enter_battle("root_9")
	battle = app.battle
	battle.manual_clock = true
	battle.set_physics_process(false)
	battle.step({})
	await _capture("root9_crt1")
	app._next_stage("root_7")
	await _capture("root7_intermission")
	app._on_intent("intermission_storage",null)
	await _capture("crt1_warehouse3")
	app._on_intent("intermission_storage_close",null)
	app._next_stage("root_10")
	await _capture("root10_intermission")
	app._dispose_battle()
	await app.audio.stop_and_drain()
	app.queue_free()
	await process_frame
	var file := FileAccess.open(out+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"files":files,"failed":failed,"scope":"Real GL framebuffer; Main/Battle controlled input. Menus7/10 selected directly for visual layout only; full legal-input progression is test_act03_flow. No Adobe Flash/ear comparison."},"\t"))
	file.close()
	print("ACT03_RENDER ",JSON.stringify({"images":files.size(),"failed":failed}))
	quit(1 if failed else 0)
