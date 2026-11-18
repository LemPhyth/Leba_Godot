extends Node
const Database = preload("res://scripts/core/content_db.gd")
const Session = preload("res://scripts/core/game_session.gd")
const Save = preload("res://scripts/services/save_store.gd")
const Audio = preload("res://scripts/services/audio_director.gd")
const Battle = preload("res://scripts/combat/battle.gd")
const Interface = preload("res://scripts/ui/game_ui.gd")
const Progression = preload("res://scripts/core/progression.gd")
const Clock = preload("res://scripts/core/source_clock.gd")
@export var content_registry: Resource
var database := Database.new()
var session := Session.new()
var saves: RefCounted
var audio: Node
var ui: CanvasLayer
var battle: Node2D
var screen := "boot"
var selected_stage := "root_2"
var save_message := ""
var test_mode := false
var startup_ok := false
var progression := Progression.new()
var dialogue_id := ""
var dialogue_index := 0
var flow_clock := Clock.new()
var transition_ticks := 0
var action_lab := false
var lab_stage := "root_2"
var storage_page := 2
var ring_popup := false
var menu_page := 2
var _autosave_clock := Clock.new()
var _autosave_ticks := 0
var _last_saved_profile := ""
var _native_trace_directory := ""
var _native_trace_index := 0
var start_stage_override := ""
var start_character_override := ""
var world: Node2D
var intermission_id := ""
var flow_events: Array[Dictionary] = []
var _focus_paused_overlay := false

func _ready() -> void:
	get_tree().auto_accept_quit = false
	test_mode = "--test-mode" in OS.get_cmdline_user_args() or OS.get_environment("LEBA_TEST_MODE") == "1"
	action_lab = "--action-lab" in OS.get_cmdline_user_args()
	if action_lab or "--mute-audio" in OS.get_cmdline_user_args() or OS.get_environment("LEBA_SILENT_TEST") == "1":
		# Diagnostic flag never alters the user's saved volume preference.
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"),true)
	saves = Save.new("user://ticket01_ui_test/profile.json" if test_mode else "user://profile.json")
	if test_mode and OS.get_environment("LEBA_TEST_PROFILE").begins_with("user://"):
		saves = Save.new(OS.get_environment("LEBA_TEST_PROFILE"))
	if test_mode:
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--test-profile=user://"):
				saves = Save.new(argument.trim_prefix("--test-profile="))
			if argument.begins_with("--trace-directory=res://artifacts/"):
				_native_trace_directory = argument.trim_prefix("--trace-directory=")
	_bind_inputs()
	var assets_ok := database.load_all(content_registry)
	world = get_node_or_null("World")
	if world == null:
		world = Node2D.new()
		world.name = "World"
		add_child(world)
	ui = get_node_or_null("Interface")
	if ui == null:
		ui = load("res://scenes/ui/game_ui.tscn").instantiate()
		add_child(ui)
	ui.configure(database.assets)
	ui.intent.connect(_on_intent)
	if not assets_ok:
		screen = "error"
		ui.show_error(database.issues)
		push_error("启动失败：" + "; ".join(database.issues))
		return
	audio = Audio.new()
	add_child(audio)
	audio.error_reported.connect(_audio_error)
	if not audio.configure(database.assets.audio):
		screen = "error"
		ui.show_error([audio.last_error])
		return
	var loaded: Dictionary = saves.load_profile()
	session.profile = loaded.profile
	if action_lab:
		session.profile = saves.default_profile()
	progression.normalize(session.profile)
	save_message = loaded.message
	if not database.characters.has(str(session.profile.selection.character_id)) or not database.characters[session.profile.selection.character_id].enabled:
		session.select_character("crt_0")
	if not database.modes.has(str(session.profile.selection.mode_id)) or not database.modes[session.profile.selection.mode_id].enabled:
		session.select_mode("story")
	var difficulty: String = str(session.profile.selection.difficulty_id)
	if not database.difficulties.has(difficulty) or not database.difficulties[difficulty].enabled:
		session.select_difficulty("expert")
	audio.set_volume(float(session.profile.settings.volume))
	startup_ok = true
	if not start_stage_override.is_empty():
		if database.characters.has(start_character_override):session.select_character(start_character_override)
		if database.stages.has(start_stage_override):enter_battle(start_stage_override)
		else:show_title()
		return
	if action_lab:
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--lab-stage=") and database.stages.has(argument.get_slice("=",1)):
				lab_stage = argument.get_slice("=",1)
			if argument.begins_with("--lab-difficulty=") and database.difficulties.has(argument.get_slice("=",1)):
				var id := argument.get_slice("=",1)
				if database.difficulties[id].enabled:session.select_difficulty(id)
		open_action_lab("crt_0")
		return
	if "--training" in OS.get_cmdline_user_args():
		_start_training()
		return
	show_title()
	if "--debug-battle" in OS.get_cmdline_user_args():
		enter_battle("root_2")
		battle.toggle_debug()

func _bind_inputs() -> void:
	var keys := {"move_left":KEY_LEFT,"move_right":KEY_RIGHT,"attack":KEY_X,"skill":KEY_D,"skill_s":KEY_S,"jump":KEY_C,"down":KEY_DOWN,"skill_z":KEY_Z,"pause":KEY_ESCAPE,"debug_overlay":KEY_F3,"continue_flow":KEY_SPACE}
	keys.merge({"skill_a":KEY_A,"skill_w":KEY_W,"load_f":KEY_F,"load_g":KEY_G,"load_h":KEY_H,"skill_q":KEY_Q,"skill_t":KEY_T,"skill_e":KEY_E,"skill_r":KEY_R,"skill_y":KEY_Y,"skill_v":KEY_V,"aim_up":KEY_UP})
	for id: String in keys:
		if not InputMap.has_action(id):
			InputMap.add_action(id)
			var event := InputEventKey.new()
			event.physical_keycode = keys[id]
			InputMap.action_add_event(id,event)
			# Virtual/accessibility keyboards can provide a logical key with a different scan code.
			var logical := InputEventKey.new()
			logical.keycode = keys[id]
			InputMap.action_add_event(id,logical)

func show_title() -> void:
	_dispose_battle()
	session.abandon()
	screen = "title"
	audio.play_music("title")
	ui.show_title(session.profile,save_message)

func show_modes() -> void:
	show_difficulty()

func show_difficulty() -> void:
	screen = "difficulty"
	ui.show_difficulty(database.difficulties,session.profile)

func _show_difficulty() -> void:
	show_difficulty()

func _show_modes() -> void:
	show_difficulty()

func show_characters() -> void:
	_dispose_battle()
	screen = "characters"
	audio.play_music("title")
	ui.show_characters(database.characters,str(session.profile.selection.character_id))

func _show_shop(message := "") -> void:
	screen = "shop"
	ui.show_shop(session.profile,str(session.profile.selection.character_id),message)

func _shop_action(operation: String) -> void:
	var result: Dictionary = progression.transact(session.profile,operation,str(session.profile.selection.character_id))
	if result.ok:
		save_progress()
	if screen == "training_storage":
		ui.show_training_storage(session.profile,str(session.profile.selection.character_id))
	else:_show_shop(str(result.message))

func show_intro(stage_id: String) -> void:
	if not database.stages.has(stage_id):
		ui.toast("场景尚未接入："+stage_id)
		return
	_dispose_battle()
	selected_stage = stage_id
	screen = "intro"
	ui.show_intro(database.stages[stage_id])

func enter_battle(stage_id: String) -> void:
	if not database.stages.has(stage_id):
		return
	_dispose_battle()
	selected_stage = stage_id
	battle = Battle.new()
	battle.name = "Encounter"
	world.add_child(battle)
	battle.setup(database,session,audio,stage_id)
	battle.trace_enabled = action_lab or "--trace-actions" in OS.get_cmdline_user_args()
	battle.finished.connect(_on_finished)
	battle.feedback.connect(ui.toast)
	battle.persistence_requested.connect(save_progress)
	screen = "battle"
	ui.show_hud(database.stages[stage_id],battle)

func _start_training(character_id := "crt_0") -> void:
	session.select_mode("training")
	session.select_character(character_id)
	enter_battle("root_41")

func _dispose_battle() -> void:
	_focus_paused_overlay = false
	if is_instance_valid(battle):
		_export_native_trace()
		battle.set_paused(true)
		battle.get_parent().remove_child(battle)
		battle.queue_free()
		battle = null
	if is_instance_valid(audio):
		audio.stop_all()

func _export_native_trace() -> void:
	if _native_trace_directory.is_empty() or not is_instance_valid(battle):return
	var path := _native_trace_directory.path_join("battle_%02d.json" % _native_trace_index)
	var code: Error = battle.export_trace(path)
	if code != OK:push_error("窗口验收轨迹导出失败："+path)
	_native_trace_index += 1

func save_progress() -> void:
	if action_lab:
		return
	var code: Error = saves.save_profile(session.profile)
	if code == OK:_last_saved_profile = JSON.stringify(session.profile)
	save_message = "进度已保存" if code == OK else "保存失败：" + saves.last_message
	if code != OK and is_instance_valid(ui):
		ui.toast(save_message)

func open_action_lab(character_id: String, stage_id := "") -> void:
	# Reuse the real actors/input/combat clock, isolate only persistent progress.
	session.select_character(character_id)
	if not stage_id.is_empty() and database.stages.has(stage_id):lab_stage = stage_id
	enter_battle(lab_stage)
	battle.toggle_debug()
	ui.show_lab_hint()

func _on_intent(action: String, value: Variant) -> void:
	if screen == "closing":return
	match action:
		"adventure":
			session.select_mode("story")
			show_characters()
		"training":
			screen = "training_characters"
			ui.show_training_characters(database.characters,str(session.profile.selection.character_id))
		"select_training_character":
			if database.characters.has(str(value)) and database.characters[value].enabled:_start_training(str(value))
		"begin_training":_start_training(str(session.profile.selection.character_id))
		"training_restore":
			if is_instance_valid(battle):battle.restore_training()
		"training_storage":
			if screen == "battle" and battle.is_training():
				screen = "training_storage"
				storage_page = 2+int(database.characters[str(session.run.character_id)].source_crt)
				ring_popup = false
				_refresh_storage()
		"training_storage_close":
			_close_original_overlay()
		"storage_close":_close_original_overlay()
		"storage_page":
			if screen in ["training_storage","intermission_storage"]:
				storage_page = int(value)
				ring_popup = false
				_refresh_storage()
		"storage_ring_choose":
			if screen in ["training_storage","intermission_storage"]:
				ring_popup = bool(value)
				_refresh_storage()
		"storage_action":
			if screen in ["training_storage","intermission_storage"] and value is Dictionary:
				var result: Dictionary = progression.transact(session.profile,str(value.operation),str(value.character_id))
				if result.ok:save_progress()
				else:ui.toast(str(result.message))
				ring_popup = false
				_refresh_storage()
		"game_menu":
			if screen == "battle":
				screen = "game_menu"
				ui.show_source_overlay("dropdown",_menu_snapshot(),selected_stage)
		"menu_page":
			if screen == "game_menu":
				menu_page = int(value)
				ui.show_source_overlay("menu",_menu_snapshot(),selected_stage,menu_page)
		"source_leave":
			save_progress()
			show_title()
		"auto_save":
			session.profile.settings.auto_save = bool(value)
			save_progress()
			_refresh_settings()
		"title":
			show_title()
		"modes":
			show_modes()
		"select_mode":
			if database.modes.has(str(value)) and database.modes[value].enabled:
				session.select_mode(str(value))
				save_progress()
				show_characters()
		"characters":
			show_characters()
		"select_character":
			if database.characters.has(str(value)) and database.characters[value].enabled:
				session.select_character(str(value))
				save_progress()
				show_difficulty()
		"begin":
			show_difficulty()
		"select_difficulty":
			if database.difficulties.has(str(value)) and database.difficulties[value].enabled:
				session.select_difficulty(str(value))
				save_progress()
				show_intro("root_2")
		"enter":
			enter_battle(selected_stage)
			_start_opening_dialogue()
		"shop":
			_show_shop()
		"shop_action":
			_shop_action(str(value))
		"dialogue_next":
			_dialogue_next(false)
		"dialogue_skip":
			_dialogue_next(true)
		"retry_first":
			var target := str(database.intermissions.get(intermission_id,{}).get("retry_stage","root_2"))
			_flow_cleanup(int(database.intermissions.get(intermission_id,{}).get("source_retry_cleanup_frame",0)))
			enter_battle(target)
			_start_opening_dialogue()
		"intermission_continue":
			if screen != "intermission":return
			var data: Dictionary = database.intermissions[intermission_id]
			var target := str(data.get("next_stage",""))
			if not database.stages.has(target):
				ui.toast(str(data.get("description","后续原流程尚未恢复")))
				return
			_flow_cleanup(int(data.get("source_continue_cleanup_frame",0)))
			enter_battle(target)
			_start_opening_dialogue()
		"intermission_storage":
			if screen != "intermission":return
			screen = "intermission_storage"
			storage_page = 2+int(database.characters[session.profile.selection.character_id].source_crt)
			ring_popup = false
			_refresh_storage()
		"pause":
			pause_battle()
		"resume":
			if screen in ["game_menu","training_storage"]:_close_original_overlay()
			else:resume_battle()
		"leave":
			save_progress()
			session.abandon()
			show_characters()
		"retry":
			if action_lab:open_action_lab(str(session.profile.selection.character_id),selected_stage)
			else:enter_battle(selected_stage)
		"continue":
			if screen == "result" and session.run.get("outcome") == "victory":
				_start_dialogue(selected_stage+"_clear")
		"volume":
			session.profile.settings.volume = clampf(float(value),0,1)
			audio.set_volume(session.profile.settings.volume)
			save_progress()
			_refresh_settings()

func _menu_snapshot() -> Dictionary:
	return {"profile":session.profile,"settings":session.profile.settings,"storage_page":storage_page,"ring_popup":ring_popup}

func _refresh_storage() -> void:
	ui.show_source_overlay("storage",_menu_snapshot(),selected_stage)

func _refresh_settings() -> void:
	if screen == "game_menu":ui.show_source_overlay("menu",_menu_snapshot(),selected_stage,menu_page)

func _close_original_overlay() -> void:
	if screen not in ["game_menu","training_storage","intermission_storage"]:return
	ui.close_source_overlay()
	screen = "intermission" if screen == "intermission_storage" else "battle"

func _flow_cleanup(source_frame: int) -> void:
	if source_frame > 0:flow_events.append({"source_root_frame":source_frame,"kind":"cleanup","from":intermission_id})
	_dispose_battle()

func _start_opening_dialogue() -> void:
	var id := str(database.stages[selected_stage].get("open_dialogue",""))
	if not id.is_empty():_start_dialogue(id)

func pause_battle() -> void:
	if screen != "battle":
		return
	battle.set_paused(true)
	screen = "pause"
	ui.show_pause()

func resume_battle() -> void:
	if screen != "pause":
		return
	battle.set_paused(false)
	screen = "battle"
	ui.show_hud(database.stages[selected_stage],battle)
	if action_lab:ui.show_lab_hint()

func _on_finished(outcome: String) -> void:
	screen = "result"
	if outcome == "defeat":ui.show_source_overlay("failure",_menu_snapshot(),selected_stage)
	else:ui.show_result(outcome,session.run,database.stages[selected_stage])

func _start_dialogue(id: String) -> void:
	if not database.dialogues.has(id):
		ui.toast("对话尚未接入："+id)
		return
	dialogue_id = id
	dialogue_index = 0
	flow_clock.reset()
	if is_instance_valid(battle):
		battle.set_paused(true)
	screen = "dialogue"
	ui.show_dialogue(database.dialogues[id],dialogue_index)

func _dialogue_next(skip := false) -> void:
	if screen != "dialogue":
		return
	dialogue_index += 1
	var dialogue: Dictionary = database.dialogues[dialogue_id]
	if not skip and dialogue_index < dialogue.frames.size():
		ui.show_dialogue(dialogue,dialogue_index)
		return
	if dialogue_id.ends_with("_open"):
		battle.set_paused(false)
		screen = "battle"
		ui.show_hud(database.stages[selected_stage],battle)
	elif dialogue_id == "root_6_clear":
		screen = "transition"
		transition_ticks = int(dialogue.outro.frames)
		flow_clock.reset()
		ui.show_transition(transition_ticks)
	else:
		_next_stage(str(database.stages[selected_stage].next_stage))

func _next_stage(id: String) -> void:
	var key := "intermission_"+id.trim_prefix("root_")
	if database.intermissions.has(key):
		_dispose_battle()
		intermission_id = key
		screen = "intermission"
		flow_events.append({"source_root_frame":int(database.intermissions[key].get("source_root_frame",7)),"kind":"intermission"})
		ui.show_intermission(database.intermissions[key],session.run)
	else:
		show_intro(id)

func _process(delta: float) -> void:
	if startup_ok and bool(session.profile.settings.get("auto_save",false)) and screen != "closing":
		_autosave_ticks += _autosave_clock.consume(delta)
		if _autosave_ticks >= 10:
			_autosave_ticks %= 10
			# Source3833 saves persistent fields, never the encounter. Avoid an
			# identical disk replacement while keeping its10-source-tick cadence.
			if JSON.stringify(session.profile) != _last_saved_profile:save_progress()
	if screen in ["battle","pause","game_menu","training_storage","result"] and is_instance_valid(battle):
		ui.update_hud(battle.snapshot(),battle.debug_draw)
		ui.set_world_offset(battle.position)
	elif screen in ["dialogue","transition"]:
		var ticks := flow_clock.consume(delta)
		if is_instance_valid(battle):
			battle.player.mp = minf(float(battle.player.definition.max_mp),battle.player.mp+0.05*ticks)
		if screen == "transition":
			transition_ticks -= ticks
			if transition_ticks <= 0:
				_next_stage("root_7")

func _unhandled_input(event: InputEvent) -> void:
	if screen == "closing" or event.is_echo():
		return
	if screen == "result" and session.run.get("outcome") == "defeat" and event is InputEventKey and event.pressed:
		var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if key in [KEY_SPACE,KEY_BACKSPACE]:
			_on_intent("retry" if key == KEY_SPACE else "source_leave",null)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("pause"):
		if screen == "battle":pause_battle()
		elif screen == "pause":resume_battle()
		elif screen == "intro":show_characters()
		elif screen in ["difficulty","shop"]:show_characters()
		elif screen in ["characters","training_characters","intermission"]:show_title()
		elif screen in ["training_storage","intermission_storage"]:_on_intent("storage_close",null)
		elif screen == "game_menu":_close_original_overlay()
		elif screen in ["dialogue","transition"]:show_characters()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_overlay") and is_instance_valid(battle):
		battle.toggle_debug()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("continue_flow"):
		if screen == "result":_on_intent("continue",null)
		elif screen == "dialogue":_dialogue_next(true)
		elif screen == "intro":_on_intent("enter",null)
		elif screen == "intermission":_on_intent("intermission_continue",null)
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if screen == "closing":return
	# OS chords such as Alt+F4 must not also reset the lab while shutdown drains audio.
	if action_lab and event is InputEventKey and event.pressed and not event.echo and not event.alt_pressed and not event.ctrl_pressed and not event.meta_pressed:
		match event.keycode:
			KEY_F1:
				open_action_lab("crt_0")
			KEY_F2:
				open_action_lab("crt_1")
			KEY_F4:
				open_action_lab(str(session.profile.selection.character_id))
			KEY_F5:
				if is_instance_valid(battle):
					battle.manual_clock = not battle.manual_clock
					battle.clock.reset()
			KEY_F6:
				if is_instance_valid(battle) and battle.manual_clock:
					battle.advance_real_time(0.04)
					battle.step(battle.take_commands())
			KEY_F7:
				var ids := ["root_2","root_4","root_6"]
				open_action_lab(str(session.profile.selection.character_id),ids[(ids.find(lab_stage)+1)%ids.size()])
			KEY_F8:
				if is_instance_valid(battle):
					var path := "user://action_lab/trace_%d_%d.json" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()]
					var code: Error = battle.export_trace(path)
					ui.toast("轨迹已导出："+path.get_file() if code == OK else "导出失败：%d" % code)
			KEY_F9:
				var ids := ["expert","master","king"]
				session.select_difficulty(ids[(ids.find(str(session.profile.selection.difficulty_id))+1)%ids.size()])
				open_action_lab(str(session.profile.selection.character_id))
			_:
				return
		get_viewport().set_input_as_handled()
		return
	if "--trace-input" in OS.get_cmdline_user_args() and event is InputEventKey:
		print("INPUT ",event.as_text()," key=",event.keycode," physical=",event.physical_keycode," pressed=",event.pressed," echo=",event.echo)

func _audio_error(message: String) -> void:
	if is_instance_valid(ui):
		ui.toast(message)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and screen == "battle" and not test_mode:
		pause_battle()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and screen in ["game_menu","training_storage"] and not test_mode and is_instance_valid(battle) and not battle.paused:
		_focus_paused_overlay = true
		battle.set_paused(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and _focus_paused_overlay:
		_focus_paused_overlay = false
		if is_instance_valid(battle) and screen in ["game_menu","training_storage","battle"]:battle.set_paused(false)
	elif what == NOTIFICATION_WM_CLOSE_REQUEST and screen != "closing":
		_shutdown()

func _shutdown() -> void:
	screen = "closing"
	_export_native_trace()
	if is_instance_valid(battle):
		battle.set_paused(true)
	if startup_ok:
		save_progress()
	if is_instance_valid(audio):
		await audio.stop_and_drain()
	get_tree().quit()

func _exit_tree() -> void:
	if is_instance_valid(audio):
		audio.stop_all()
