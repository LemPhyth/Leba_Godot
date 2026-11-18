extends SceneTree
## Real GL Main/Battle render; Q is triggered through its bound key. Source
## timeline comparisons are controlled fixtures, not natural OS/Flash gameplay.
const MainScene = preload("res://scenes/main.tscn")
var app: Node
var output := ""
var images: Array[Dictionary] = []
var failures: Array[String] = []
var author_hashes: Dictionary = {}
var formal_exists := false
var formal_hash := ""

func _initialize() -> void:call_deferred("_run")

func _authors() -> Dictionary:
	var result := {}
	for folder: String in ["res://content/actions/crt1","res://content/components/crt1"]:
		for file: String in DirAccess.get_files_at(folder):
			var path := folder.path_join(file)
			result[path] = FileAccess.get_sha256(path)
	return result

func _check(okay: bool, message: String) -> bool:
	if not okay:failures.append(message);push_error(message)
	return okay

func _key(battle: Node2D, key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	battle._unhandled_input(event)
	battle.step(battle.take_commands())
	event.pressed = false
	battle._unhandled_input(event)

func _fresh(facing: int) -> Node2D:
	app.session.profile = app.saves.default_profile()
	app._on_intent("select_training_character","crt_1")
	var battle: Node2D = app.battle
	battle.manual_clock = true
	battle.set_physics_process(false)
	battle.step({})
	battle.step({})
	# Declared direction fixture; no action Resource/layout/coordinate is edited.
	battle.player.set_facing(facing)
	return battle

func _to_buff(battle: Node2D, target: int, cap := 420) -> bool:
	for tick in range(cap):
		if int(battle.crt1.buff_frame) == target:return true
		battle.step({})
	return _check(false,"Q did not reach source frame %d"%target)

func _matrix(value: Transform2D) -> Array:
	return [value.x.x,value.x.y,value.y.x,value.y.y,value.origin.x,value.origin.y]

func _metadata(battle: Node2D) -> Dictionary:
	var components := []
	for key: String in battle._crt1_views:
		if not key.begins_with("buff_"):continue
		var view: Node2D = battle._crt1_views[key]
		var animation: Dictionary = view.definition.duplicate(true)
		animation.erase("texture_resource")
		components.append({"key":key,"visible":view.visible,"source_frame":view.source_frame,"matrix":_matrix(view.transform),"global_matrix":_matrix(view.global_transform),"modulate_alpha":view.modulate.a,"animation":animation,"texture_sha256":FileAccess.get_sha256(str(animation.get("texture","")))})
	var source_frame := int(battle.crt1.buff_frame)
	var reference := ProjectSettings.globalize_path("res://../res/sprites/DefineSprite_4592/%d.png"%source_frame)
	return {"stage":app.session.run.stage_id,"source_tick":app.session.run.source_ticks,"player_state":battle.player.state,"player_source_frame":battle.player.source_frame,"player_position":[battle.player.position.x,battle.player.position.y],"player_visual_scale":[battle.player.visual_scale.x,battle.player.visual_scale.y],"facing":battle.player.facing,"buff_source_frame":source_frame,"source_reference":reference,"source_reference_sha256":FileAccess.get_sha256(reference) if FileAccess.file_exists(reference) else "","components":components,"source_contract":{"parent_source_id":4592,"parent_placement":[1.654419,0,0,1.8181763,2.75,-126.3],"sustained_sources":[4580,4589,4591],"sustained_range":[9,400],"source401_icon_in_edges":true,"original_image_limit":"Original exported nested frame is a static display-list reference; child animation clocks are compared through source metadata, not a pixel oracle."}}

func _capture(battle: Node2D, name: String) -> void:
	app.ui.update_hud(battle.snapshot(),false)
	await process_frame
	RenderingServer.force_draw(false)
	var bitmap := root.get_texture().get_image()
	var path := output.path_join(name+".png")
	if not _check(bitmap != null and not bitmap.is_empty(),"GL framebuffer unavailable: "+name):return
	if not _check(bitmap.save_png(path) == OK,"PNG write failed: "+path):return
	var row := _metadata(battle)
	if not _check(row.has("buff_source_frame"),"Render metadata incomplete: "+name):return
	row.path = path
	row.sha256 = FileAccess.get_sha256(path)
	row.dimensions = [bitmap.get_width(),bitmap.get_height()]
	images.append(row)

func _sequence(facing: int) -> void:
	var label := "right" if facing == 1 else "left"
	var battle := _fresh(facing)
	_key(battle,KEY_Q)
	for tick in range(10):
		if battle.player.state == "skill_q" and battle.player.source_frame == 4:break
		battle.step({})
	if not _check(battle.player.state == "skill_q" and battle.player.source_frame == 4,"Q cast source4 missing "+label):return
	await _capture(battle,label+"_cast04")
	for frame in [2,8,9,21,401]:
		if not _to_buff(battle,frame):return
		await _capture(battle,label+"_buff%03d"%frame)
	if not _to_buff(battle,1,9):return
	_check(battle._crt1_views.values().all(func(view: Node2D)->bool:return not view.visible),"Q residue after source407 "+label)
	await _capture(battle,label+"_cleared")

func _run() -> void:
	output = OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if output.is_empty():output = "res://artifacts/leba_act04_20261117/crt1/render_%d_%d"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	author_hashes = _authors()
	formal_exists = FileAccess.file_exists("user://profile.json")
	if formal_exists:formal_hash = FileAccess.get_sha256("user://profile.json")
	OS.set_environment("LEBA_TEST_MODE","1")
	OS.set_environment("LEBA_SILENT_TEST","1")
	OS.set_environment("LEBA_TEST_PROFILE","user://act04_crt1_render/%d_%d/profile.json"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()])
	root.size = Vector2i(550,400)
	app = MainScene.instantiate()
	root.add_child(app)
	app.set_process(false)
	if _check(app.startup_ok and app.test_mode and app.saves.path != "user://profile.json","Isolated Main startup failed"):
		await _sequence(1)
		await _sequence(-1)
	if is_instance_valid(app.battle):app._dispose_battle()
	await app.audio.stop_and_drain()
	app.queue_free()
	await process_frame
	_check(_authors() == author_hashes,"Formal author Resources changed")
	_check(FileAccess.file_exists("user://profile.json") == formal_exists and (not formal_exists or FileAccess.get_sha256("user://profile.json") == formal_hash),"Formal user profile changed")
	_check(images.size() == 14,"Expected14 Q phase screenshots")
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"images":images,"failures":failures,"author_hashes":author_hashes,"formal_profile_unchanged":FileAccess.file_exists("user://profile.json") == formal_exists and (not formal_exists or FileAccess.get_sha256("user://profile.json") == formal_hash),"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"scope":"Actual GL Main/Battle framebuffer, Dummy and master mute. Bound Q InputEventKey, manual25Hz source steps and controlled facing. No OS-keyboard/Adobe Flash/audible acceptance claim. Original PNGs are read-only static references; source XML placement metadata is independently recorded."},"\t")+"\n")
	file.close()
	print("ACT04_CRT1_RENDER ",JSON.stringify({"images":images.size(),"failures":failures.size(),"output":output}))
	quit(0 if failures.is_empty() else 1)

