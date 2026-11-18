extends SceneTree
## Synthetic Main focus notifications; actual Battle, clocks, input queues and
## isolated SaveStore. This is not OS alt-tab or human focus acceptance.
var app: Node
var checks: Array[Dictionary] = []
var formal_exists := false
var formal_hash := ""
var output := ""
var profile_path := ""

func _initialize() -> void:call_deferred("_run")

func _check(label: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"name":label,"passed":passed,"detail":detail})
	print(("PASS " if passed else "FAIL ")+label)

func _advance(count: int) -> void:
	for tick in range(count):
		app.battle._physics_process(0.04)
		app._process(0.04)

func _start() -> Node2D:
	app._start_training("crt_0")
	app.battle.set_physics_process(false)
	app.battle.enemies[0].position.x = 520 # Explicit no-contact fixture.
	app.battle.player.mp = 100.0
	return app.battle

func _focus(what: int) -> void:
	var original: bool = app.test_mode
	app.test_mode = false # Exercise the actual production focus branch only.
	app.notification(what)
	app.test_mode = original

func _open(kind: String) -> void:
	app._on_intent(kind,null)
	if kind == "game_menu":app._on_intent("menu_page",6)

func _press(id: String) -> bool:
	var button: BaseButton = app.ui.get_button(id)
	if button == null or button.disabled:
		_check("actual UI button is available: "+id,false,{"screen":app.screen,"missing":button == null})
		return false
	button.pressed.emit() # Actual connected author node; synthetic signal, not OS mouse.
	return true

func _training_storage_roles() -> void:
	var original_gold: int = int(app.session.profile.progress.gold)
	var original_cubes: int = int(app.session.profile.progress.clear_cubes)
	for source_crt: int in [0,1]:
		var character_id := "crt_"+str(source_crt)
		var expected_page := 2+source_crt # Original2728 role-specific weapon page.
		var prefix := character_id+" training storage "
		app.show_title()
		if not _press("Training"):return
		_check(prefix+"starts at the actual title character-selection entry",app.screen == "training_characters")
		if not _press("Character_"+character_id):return
		var battle: Node2D = app.battle
		var actor: Node2D = battle.player
		var hud: Node2D = app.ui.source_hud
		battle.set_physics_process(false)
		battle.enemies[0].position.x = 520 # Explicit no-contact fixture, not source spawn.
		_check(prefix+"selection creates the selected role in real root41",app.screen == "battle" and app.selected_stage == "root_41" and app.session.run.character_id == character_id and battle.is_training())
		# Deliberate isolated-profile display fixtures, not original starting funds.
		var gold := 4321+source_crt
		var cubes := 123+source_crt
		app.session.profile.progress.gold = gold
		app.session.profile.progress.clear_cubes = cubes
		if not _press("TrainingStorage"):return
		var menu: Control = app.ui.source_menu
		var page: Control = menu.get_node("Pages/warehouse_"+str(expected_page))
		var other: Control = menu.get_node("Pages/warehouse_"+str(3-source_crt))
		_check(prefix+"opens only its original weapon author page",app.screen == "training_storage" and app.storage_page == expected_page and menu.current_page == expected_page and page.is_visible_in_tree() and not other.visible,{"expected_page":expected_page,"main_page":app.storage_page,"view_page":menu.current_page})
		var art_key := "source_warehouse_weapons_panel" if source_crt == 0 else "source_warehouse_crt1_weapons_panel"
		_check(prefix+"uses the corresponding original2728 artwork",menu.panel_sprite.texture.resource_path == app.database.assets.textures[art_key].path)
		_check(prefix+"reads gold and cubes from the one isolated profile",menu.storage_fields.gold.text == str(gold) and menu.storage_fields.clear_cubes.text == str(cubes) and menu.storage_fields.pama_stones.text == "0")
		var tick: int = app.session.run.source_ticks
		var ms: float = battle.real_time_ms
		_advance(2)
		_check(prefix+"keeps the same battle actor and HUD ticking",not battle.paused and app.battle == battle and battle.player == actor and app.ui.source_hud == hud and app.session.run.source_ticks == tick+2 and is_equal_approx(battle.real_time_ms,ms+80.0))
		if not _press("warehouse_close"):return
		_check(prefix+"native close resumes the same encounter",app.screen == "battle" and not menu.visible and not battle.paused and app.battle == battle and battle.player == actor and app.ui.source_hud == hud)
		app.session.profile.progress.gold = gold+7
		app.session.profile.progress.clear_cubes = cubes-1
		if not _press("TrainingStorage"):return
		_check(prefix+"reopening keeps the role page and refreshes current values",menu.current_page == expected_page and page.is_visible_in_tree() and menu.storage_fields.gold.text == str(gold+7) and menu.storage_fields.clear_cubes.text == str(cubes-1))
		app.ui.show_training_storage(app.session.profile,character_id)
		_check(prefix+"compatibility entry also honors its supplied role",menu.current_page == expected_page and page.is_visible_in_tree() and not other.visible)
		if not _press("warehouse_close"):return
		_check(prefix+"compatibility close also retains battle ownership",app.screen == "battle" and app.battle == battle and battle.player == actor and app.ui.source_hud == hud and not menu.visible)
	app.session.profile.progress.gold = original_gold
	app.session.profile.progress.clear_cubes = original_cubes
	app.show_title()

func _run() -> void:
	formal_exists = FileAccess.file_exists("user://profile.json")
	if formal_exists:formal_hash = FileAccess.get_sha256("user://profile.json")
	output = OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if output.is_empty():output = "res://artifacts/leba_act03_20261116/ui/focus01"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	profile_path = "user://act03_focus/%d_%d/profile.json" % [int(Time.get_unix_time_from_system()),Time.get_ticks_usec()]
	OS.set_environment("LEBA_TEST_MODE","1")
	OS.set_environment("LEBA_SILENT_TEST","1")
	OS.set_environment("LEBA_TEST_PROFILE",profile_path)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.set_process(false)
	_check("actual Main boots with a new isolated profile",app.startup_ok and app.test_mode and app.saves.path == profile_path)
	if not app.startup_ok:
		await _finish()
		return
	_training_storage_roles()
	for kind: String in ["game_menu","training_storage"]:
		var battle := _start()
		var actor: Node2D = battle.player
		var hud: Node2D = app.ui.source_hud
		_open(kind)
		var tick: int = app.session.run.source_ticks
		var ms: float = battle.real_time_ms
		_advance(2)
		_check(kind+" keeps actual battle ticking before focus loss",app.screen == kind and not battle.paused and app.session.run.source_ticks == tick+2 and is_equal_approx(battle.real_time_ms,ms+80.0))
		var event := InputEventKey.new()
		event.keycode = KEY_X
		event.physical_keycode = KEY_X
		event.pressed = true
		battle._unhandled_input(event)
		_check(kind+" fixture queues a real bound action before blur",not battle._key_events.is_empty())
		tick = app.session.run.source_ticks
		ms = battle.real_time_ms
		var mp: float = actor.mp
		_focus(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		_check(kind+" focus-out suspends battle without replacing the active overlay",app._focus_paused_overlay and battle.paused and app.screen == kind and app.battle == battle and battle.player == actor and app.ui.source_hud == hud and app.ui.source_menu.visible)
		_check(kind+" pause clears buffered input in the shared battle",battle._key_events.is_empty() and battle._presses.is_empty())
		_advance(4)
		_check(kind+" focus suspension freezes source time milliseconds and regeneration",app.session.run.source_ticks == tick and battle.real_time_ms == ms and actor.mp == mp)
		_focus(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		_check(kind+" repeated focus-out retains its suspension ownership",app._focus_paused_overlay and battle.paused)
		_focus(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		_check(kind+" focus-in resumes only the existing owned suspension",not app._focus_paused_overlay and not battle.paused and app.screen == kind and app.battle == battle)
		_advance(1)
		_check(kind+" resumes one real tick without replaying stale action",app.session.run.source_ticks == tick+1 and is_equal_approx(battle.real_time_ms,ms+40.0) and actor.state == "idle")
		# Closing a focus-suspended overlay changes the page, not pause ownership.
		_focus(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		app._on_intent("resume" if kind == "game_menu" else "storage_close",null)
		_check(kind+" close during blur does not run the suspended encounter",app.screen == "battle" and battle.paused and app._focus_paused_overlay and not app.ui.source_menu.visible)
		_focus(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		_check(kind+" return focus after close resumes the same encounter",not battle.paused and not app._focus_paused_overlay and app.battle == battle)
		# An already paused encounter belongs to another pause request.
		_open(kind)
		battle.set_paused(true)
		_focus(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		_focus(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		_check(kind+" focus events do not resume an independently paused battle",battle.paused and not app._focus_paused_overlay)
		battle.set_paused(false)
		_focus(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		app._on_intent("source_leave",null)
		_focus(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		_check(kind+" exit clears ownership and focus cannot resurrect the encounter",app.screen == "title" and not is_instance_valid(app.battle) and not app._focus_paused_overlay)
	var battle := _start()
	_open("game_menu")
	_focus(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	app._on_intent("resume",null)
	app.pause_battle()
	_focus(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_check("manual pause acquired during an overlay blur is not cancelled on focus-in",app.screen == "pause" and battle.paused and not app._focus_paused_overlay)
	app.resume_battle()
	app.pause_battle()
	_focus(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_focus(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_check("manual engineering pause survives both focus notifications",app.screen == "pause" and battle.paused and not app._focus_paused_overlay)
	app.resume_battle()
	_check("manual pause still resumes through its actual command",app.screen == "battle" and not battle.paused)
	_focus(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check("plain battle focus-out keeps existing engineering pause behavior",app.screen == "pause" and battle.paused and not app._focus_paused_overlay)
	_focus(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_check("plain battle focus-in does not silently dismiss engineering pause",app.screen == "pause" and battle.paused)
	_check("notification tests restore test_mode and preserve isolated save ownership",app.test_mode and app.saves.path == profile_path)
	app.show_title()
	_check("real isolated profile persisted without touching the formal file",app.saves.load_profile().ok and FileAccess.file_exists("user://profile.json") == formal_exists and (not formal_exists or FileAccess.get_sha256("user://profile.json") == formal_hash))
	await _finish()

func _finish() -> void:
	if is_instance_valid(app):
		app.test_mode = true
		if is_instance_valid(app.battle):app._dispose_battle()
		if is_instance_valid(app.audio):
			await app.audio.stop_and_drain()
			var audio_state: Dictionary = app.audio.snapshot()
			_check("actual Dummy audio drains before Main is freed",not audio_state.music_playing and audio_state.sfx_active == 0 and audio_state.pending_playbacks == 0)
		app.queue_free()
		await process_frame
	var failures := checks.filter(func(row: Dictionary)->bool:return not row.passed).size()
	var file := FileAccess.open(output.path_join("act03_focus_tests.json"),FileAccess.WRITE)
	if file != null:file.store_string(JSON.stringify({"suite":"act03_focus","checks":checks,"failures":failures,"profile":profile_path,"scope":"Actual Main/Battle and both-role training storage via connected author button signals, production notification branches with temporary test_mode=false, isolated SaveStore and Dummy audio. Synthetic button/focus events; no OS mouse/focus/alt-tab acceptance."},"\t")+"\n")
	print("ACT03_FOCUS_TESTS_RESULT ",JSON.stringify({"checks":checks.size(),"failures":failures}))
	quit(0 if failures == 0 else 1)
