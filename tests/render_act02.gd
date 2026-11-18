extends SceneTree
## Real GL viewport inspection. Controlled input, Dummy audio, not OS-keyboard acceptance.
const MainScene = preload("res://scenes/main.tscn")
var OUT = "res://artifacts/leba_act02_20261115/phase_b_render"
var app: Node
var files: Array[String] = []
var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _capture(label: String) -> void:
	if app.screen == "battle":app.ui.update_hud(app.battle.snapshot(),false)
	await process_frame
	RenderingServer.force_draw(false)
	var bitmap := root.get_texture().get_image()
	var path: String = OUT+"/"+label+".png"
	if bitmap == null or bitmap.is_empty() or bitmap.save_png(path) != OK:
		failed = true
		push_error("ACT02 viewport capture failed: "+label)
	else:files.append(path)

func _run() -> void:
	if not OS.get_environment("LEBA_TEST_ARTIFACT_DIR").is_empty():OUT = OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(550,400)
	app = MainScene.instantiate()
	root.add_child(app)
	if not app.startup_ok:
		quit(1)
		return
	await _capture("title_entry")
	app.ui.get_button("Training").pressed.emit()
	app.ui.get_button("Character_crt_0").pressed.emit()
	app.battle.manual_clock = true
	app.battle.step({})
	await _capture("training_initial")
	app.battle.step({"jump":true})
	for i in range(15):app.battle.step({"held_attack":true})
	await _capture("training_air_x")
	app.battle.restore_training()
	app.battle.step({})
	await _capture("restore_during_action")
	app._on_intent("training_storage",null)
	await _capture("storage")
	app._on_intent("training_storage_close",null)
	app._on_intent("game_menu",null)
	app._on_intent("menu_page",6)
	await _capture("source_settings")
	app._on_intent("resume",null)
	app._start_training()
	app.battle.manual_clock = true
	app.battle.step({})
	app.battle.step({"skill_r":true})
	for i in range(29):app.battle.step({})
	await _capture("source_r_floor")
	app._start_training()
	app.battle.manual_clock = true
	app.battle.step({})
	app.battle.step({"skill_t":true})
	for i in range(12):app.battle.step({})
	await _capture("source_t_aim")
	app._start_training()
	app.battle.manual_clock = true
	for i in range(533):app.battle.step({})
	app.battle.step({"skill_y":true})
	for i in range(45):app.battle.step({})
	await _capture("source_y_normal")
	app.session.select_mode("story")
	for stage_id: String in ["root_2","root_4","root_6"]:
		app.enter_battle(stage_id)
		app.battle.manual_clock = true
		app.battle.step({})
		await _capture(stage_id+"_common_hud")
	app.session.select_character("crt_1")
	app.enter_battle("root_2")
	app.battle.manual_clock = true
	app.battle.step({})
	await _capture("crt1_root2_regression")
	app._dispose_battle()
	await app.audio.stop_and_drain()
	app.queue_free()
	await process_frame
	var file := FileAccess.open(OUT+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"files":files,"failed":failed,"scope":"Real GL frames, controlled menu/button/action input, Dummy audio"},"\t"))
	file.close()
	print("ACT02_RENDER ",JSON.stringify({"images":files.size(),"failed":failed}))
	quit(1 if failed else 0)
