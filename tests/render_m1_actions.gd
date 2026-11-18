extends SceneTree
## Actual GPU viewport fixtures; not a manual keyboard or Flash acceptance test.
const MainScene = preload("res://scenes/main.tscn")
const OUT := "res://artifacts/leba_act01_20261114/render"
var app: Node
var files: Array[String] = []
var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _capture(label: String) -> void:
	app.ui.update_hud(app.battle.snapshot(),true)
	await process_frame
	RenderingServer.force_draw(false)
	var bitmap := root.get_texture().get_image()
	var path := OUT+"/"+label+".png"
	if bitmap == null or bitmap.is_empty() or bitmap.save_png(path) != OK:
		failed = true
		push_error("M1 viewport capture failed: "+label)
	else:files.append(path)

func _fresh() -> Node2D:
	app.open_action_lab("crt_0","root_2")
	app.battle.manual_clock = true
	return app.battle

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(550,400)
	app = MainScene.instantiate()
	root.add_child(app)
	if not app.startup_ok or not app.action_lab:
		quit(1)
		return
	var battle := _fresh()
	await _capture("idle")
	battle.step({"jump":true})
	await _capture("jump_01")
	for i in range(2,36):
		battle.step({"held_attack":true})
		if i in [8,15,17,20,29,31,35]:await _capture("jump_%02d" % i)
	battle = _fresh()
	battle.step({"down":true})
	await _capture("down_01")
	for i in range(2,13):
		battle.step({})
		if i in [6,10,12]:await _capture("down_%02d" % i)
	battle = _fresh()
	battle.step({"skill_z":true})
	for i in range(2,15):
		battle.advance_real_time(0.04)
		battle.step({})
		if i in [3,7,14]:await _capture("z_%02d" % i)
	battle = _fresh()
	battle.step({"right":true})
	battle.player.mp = 2.0 # Explicit fallback-entry render fixture.
	battle.step({"skill_z":true})
	for i in range(2,23):
		battle.step({})
		if i in [7,14,22]:await _capture("move_z_%02d" % i)
	app.open_action_lab("crt_1","root_4")
	app.battle.manual_clock = true
	await _capture("crt1_four_enemies")
	app.open_action_lab("crt_0","root_6")
	app.battle.manual_clock = true
	await _capture("boss_stage")
	app._dispose_battle()
	await app.audio.stop_and_drain()
	app.queue_free()
	await process_frame
	var file := FileAccess.open(OUT+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"files":files,"failed":failed,"scope":"Godot GL GPU frames with controlled action input; Dummy audio; no host-keyboard or original-Flash acceptance"},"\t"))
	file.close()
	print("RENDER_M1 ",JSON.stringify({"images":files.size(),"failed":failed}))
	quit(1 if failed else 0)
