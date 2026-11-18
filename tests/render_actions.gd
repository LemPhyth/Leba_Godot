extends SceneTree
## GPU render fixtures, not manual keyboard acceptance or original gameplay proof.
## Run without --headless, with --audio-driver Dummy -- --action-lab --test-mode.
const MainScene = preload("res://scenes/main.tscn")
var app: Node
var files: Array[String] = []
var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _capture(name: String) -> void:
	app.ui.update_hud(app.battle.snapshot(),true)
	await process_frame
	RenderingServer.force_draw(false)
	var bitmap := root.get_texture().get_image()
	var path := "res://artifacts/leiba02_20261112/render/%s.png" % name
	if bitmap == null or bitmap.is_empty() or bitmap.save_png(path) != OK:
		push_error("Unable to capture actual GPU fixture: "+name)
		failed = true
	else:
		files.append(path)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/leiba02_20261112/render"))
	root.size = Vector2i(550,400)
	app = MainScene.instantiate()
	root.add_child(app)
	if not app.startup_ok or not app.action_lab:
		quit(1)
		return
	for character: String in ["crt_0","crt_1"]:
		app.open_action_lab(character)
		app.battle.manual_clock = true
		await _capture(character+"_idle")
		app.battle.player.request_hurt()
		await _capture(character+"_hurt1")
		app.battle.player.advance_tick()
		await _capture(character+"_hurt2")
		app.battle.player.set_facing(-1)
		await _capture(character+"_hurt2_left")
		for i in range(6):
			app.battle.player.advance_tick()
		await _capture(character+"_fx8")
	app.enter_battle("root_6")
	app.battle.manual_clock = true
	app.battle.toggle_debug()
	app.battle._start_marker(app.battle.player,app.battle.enemies[0],-5.0,"GPU fixture")
	await _capture("boss_air_rising")
	app.battle.enemies[0].vertical_speed = 2.0
	app.battle.enemies[0].update_air_visual(1)
	await _capture("boss_air_falling")
	app._dispose_battle()
	await app.audio.stop_and_drain()
	app.queue_free()
	await process_frame
	var report := FileAccess.open("res://artifacts/leiba02_20261112/render/report.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"files":files,"failed":failed,"scope":"Actual Godot GL viewport rendering with controlled actor states; no physical keyboard or speaker test"},"\t"))
	report.close()
	print("RENDER_ACTIONS ",JSON.stringify({"files":files.size(),"failed":failed}))
	quit(1 if failed else 0)
