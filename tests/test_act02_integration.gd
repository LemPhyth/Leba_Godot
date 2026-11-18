extends SceneTree
## Actual Main + native SubViewport GUI events, isolated disk saves, Dummy audio.
## Owned ring / lethal HP are explicit integration fixtures, not source gameplay.
const MainScene = preload("res://scenes/main.tscn")
class CountingSave extends "res://scripts/services/save_store.gd":
	var writes := 0
	func _init(save_path: String) -> void:super(save_path)
	func save_profile(profile: Dictionary) -> Error:
		var result := super.save_profile(profile)
		if result == OK:writes += 1
		return result

var app: Node
var viewport: SubViewport
var checks: Array[Dictionary] = []
var observations: Array[Dictionary] = []
var formal_exists := false
var formal_hash := ""

func _initialize() -> void:call_deferred("_run")

func _check(label: String, passed: bool, details: Variant = "") -> void:
	checks.append({"name":label,"passed":passed,"detail":details})
	print(("PASS " if passed else "FAIL ")+label+" "+str(details))

func _click(button: BaseButton) -> bool:
	if not is_instance_valid(button):
		_check("actual GUI target exists",false)
		return false
	var center := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	viewport.push_input(motion,true)
	await process_frame
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = center
		event.global_position = center
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		viewport.push_input(event,true)
		await process_frame
	return true

func _ui(name_: String) -> BaseButton:
	return app.ui.get_button(name_)

func _menu(name_: String) -> BaseButton:
	if not is_instance_valid(app.ui.source_menu):return null
	return app.ui.source_menu.buttons.get(name_) as BaseButton

func _controlled_battle() -> Node2D:
	var battle: Node2D = app.battle
	battle.set_physics_process(false)
	battle.manual_clock = false
	# No-contact control keeps menu lifecycle independent of enemy attack RNG.
	battle.enemies[0].position.x = 520
	return battle

func _advance(ticks: int) -> void:
	for tick in range(ticks):
		if is_instance_valid(app.battle):app.battle._physics_process(0.04)
		app._process(0.04)

func _dropdown(page_button: String) -> bool:
	await _click(_ui("Pause")) # Original source HUD menu button, not Esc pause.
	if not is_instance_valid(app.ui.source_menu):
		_check("HUD menu opens source6934 overlay",false,app.screen)
		return false
	var view: Control = app.ui.source_menu
	view.set_process(false)
	for tick in range(6):view._process(0.04)
	await process_frame
	if not view.buttons.has(page_button):
		_check("expanded6934 exposes requested original button",false,page_button)
		return false
	await _click(view.buttons[page_button])
	return true

func _key(code: Key) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		viewport.push_input(event,true)
		await process_frame

func _run() -> void:
	formal_exists = FileAccess.file_exists("user://profile.json")
	if formal_exists:formal_hash = FileAccess.get_sha256("user://profile.json")
	viewport = SubViewport.new()
	viewport.size = Vector2i(550,400)
	viewport.disable_3d = true
	root.add_child(viewport)
	app = MainScene.instantiate()
	viewport.add_child(app)
	app.set_process(false) # Only explicitly supplied deltas drive save cadence.
	_check("integration starts actual normal Main title with isolated test mode",app.startup_ok and app.test_mode and not app.action_lab and app.screen == "title")
	if not app.startup_ok:
		_finish()
		return
	app.saves = CountingSave.new("user://act02_integration/run_%d_%d/profile.json" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()])
	var legacy: Dictionary = app.saves.default_profile()
	_check("new profile uses source80 percent and disabled automatic options",legacy.settings == {"volume":0.8,"auto_save":false,"auto_quality":false})
	legacy.settings = {"volume":0.65}
	_check("legacy65 percent fixture writes only the isolated real save",app.saves.save_profile(legacy) == OK)
	var loaded: Dictionary = app.saves.load_profile()
	app.session.profile = loaded.profile
	app.progression.normalize(app.session.profile)
	app.audio.set_volume(app.session.profile.settings.volume)
	_check("additive original settings retain legacy65 percent",loaded.ok and app.session.profile.settings == {"volume":0.65,"auto_save":false,"auto_quality":false} and is_equal_approx(float(app.audio.snapshot().volume),0.65))
	# Explicit pre-owned source ring fixture; acquisition/shop is not this suite.
	app.session.profile.inventory.haring = 1
	app.session.profile.progress.gold = 37
	app.show_title()
	await process_frame
	await _click(_ui("Training"))
	await _click(_ui("Character_crt_0"))
	_check("native title and character0 selection enters source3016 training root41",app.screen == "battle" and is_instance_valid(app.battle) and app.battle.is_training() and app.selected_stage == "root_41" and app.session.run.character_id == "crt_0")
	if not is_instance_valid(app.battle):
		_finish()
		return
	var battle := _controlled_battle()
	var actor: Node2D = battle.player
	var hud: Node2D = app.ui.source_hud
	_check("normal training starts unmodified130HP and actual sourceHUD",is_equal_approx(float(actor.definition.max_hp),130.0) and is_instance_valid(hud) and hud.get_parent() == battle)
	await _test_settings(battle,actor,hud)
	await _test_storage(battle,actor)
	await _test_reentry_failure()
	_check("integration leaves formal profile existence and hash unchanged",FileAccess.file_exists("user://profile.json") == formal_exists and (not formal_exists or FileAccess.get_sha256("user://profile.json") == formal_hash))
	app._dispose_battle()
	var drained: bool = await app.audio.stop_and_drain(1.0)
	_check("integrated Dummy audio drains before actual tree release",drained and app.audio.snapshot().pending_playbacks == 0)
	viewport.queue_free()
	await process_frame
	_finish()

func _test_settings(battle: Node2D, actor: Node2D, hud: Node2D) -> void:
	if not await _dropdown("dropdown_settings"):return
	_check("source dropdown settings route to actual page6 without replacing encounter",app.screen == "game_menu" and app.ui.source_menu.current_page == 6 and app.battle == battle and battle.player == actor and app.ui.source_hud == hud and not battle.paused)
	var volume_display := {"value":app.ui.source_menu.state.settings.volume,"tooltip":_menu("volume_50").tooltip_text,"texture":app.ui.source_menu.volume_sprite.texture.resource_path}
	# Numeric formatting may retain .0; the authoritative value and original
	# page1 image matter, rather than requiring one incidental tooltip spelling.
	_check("page6 reads actual65 percent profile despite original page1 volume art",is_equal_approx(float(volume_display.value),0.65) and "当前65" in str(volume_display.tooltip) and volume_display.texture == app.database.assets.textures.source_volume_100.path,volume_display)
	var ticks: int = app.session.run.source_ticks
	actor.mp = 100
	_advance(3)
	_check("source settings overlay keeps actual combat clock and MP regeneration running",app.session.run.source_ticks == ticks+3 and is_equal_approx(actor.mp,100.15) and not battle.paused and is_equal_approx(float(hud.state.mp),actor.mp))
	var writes: int = app.saves.writes
	await _click(_menu("volume_50"))
	var disk: Dictionary = app.saves.load_profile()
	_check("native volume target updates one authoritative profile audio and real save",is_equal_approx(float(app.session.profile.settings.volume),0.5) and is_equal_approx(float(app.audio.snapshot().volume),0.5) and is_equal_approx(float(disk.profile.settings.volume),0.5) and app.saves.writes == writes+1 and is_equal_approx(float(app.ui.source_menu.state.settings.volume),0.5))
	writes = app.saves.writes
	await _click(_menu("auto_save"))
	_check("native automatic-save checkbox commits true and refreshes source view",app.session.profile.settings.auto_save and app.ui.source_menu.state.settings.auto_save and app.saves.load_profile().profile.settings.auto_save and app.saves.writes == writes+1)
	app._autosave_clock.reset()
	app._autosave_ticks = 0
	writes = app.saves.writes
	app.session.profile.progress.gold += 11 # Explicit persistent mutation fixture.
	_advance(9)
	_check("automatic save waits for10 complete source ticks",app.saves.writes == writes and app.saves.load_profile().profile.progress.gold == 37)
	_advance(1)
	_check("automatic save persists dirty profile exactly at tenth source tick",app.saves.writes == writes+1 and app.saves.load_profile().profile.progress.gold == 48)
	writes = app.saves.writes
	actor.hp = 99 # Volatile encounter state must not dirty persistent profile.
	_advance(20)
	_check("unchanged persistent profile and changing HP MP do not rewrite disk",app.saves.writes == writes and not app.saves.load_profile().profile.has("hp") and not app.saves.load_profile().profile.has("run"))
	await _click(_menu("close"))
	_check("source settings close restores same encounter and HUD without pause",app.screen == "battle" and app.battle == battle and battle.player == actor and app.ui.source_hud == hud and not battle.paused and not app.ui.source_menu.visible)
	await _key(KEY_ESCAPE)
	_check("Esc remains a distinct engineering pause from source menu",app.screen == "pause" and battle.paused)
	ticks = app.session.run.source_ticks
	_advance(1)
	_check("engineering pause stops actual battle source clock",app.session.run.source_ticks == ticks)
	await _key(KEY_ESCAPE)
	_check("Esc resumes existing encounter",app.screen == "battle" and not battle.paused and app.battle == battle)
	observations.append({"phase":"settings","writes":app.saves.writes,"profile":app.session.profile.duplicate(true),"source_ticks":app.session.run.source_ticks})

func _test_storage(battle: Node2D, actor: Node2D) -> void:
	var hud: Node2D = app.ui.source_hud # Esc may rebuild display; encounter stays.
	await _click(_ui("TrainingStorage"))
	_check("native training storage opens source page2 without resetting actors",app.screen == "training_storage" and app.ui.source_menu.current_page == 2 and app.battle == battle and battle.player == actor and not battle.paused)
	var ticks: int = app.session.run.source_ticks
	_advance(2)
	_check("original warehouse overlay keeps Battle and HUD live",app.session.run.source_ticks == ticks+2 and not battle.paused and app.ui.source_hud == hud)
	await _click(_menu("warehouse_rings"))
	_check("source warehouse category routes to page8 with real gold and cubes",app.storage_page == 8 and app.ui.source_menu.current_page == 8 and app.ui.source_menu.storage_fields.gold.text == "48" and app.ui.source_menu.storage_fields.clear_cubes.text == "200")
	await _click(_menu("ring_owned"))
	_check("owned source ring opens real character selector without premature equip",app.ring_popup and app.session.profile.equipment.rings.crt_0 == 0)
	var writes: int = app.saves.writes
	await _click(_menu("ring_equip_crt0"))
	_check("source ring selector delegates equip to authoritative progression and saves",app.session.profile.equipment.rings.crt_0 == 1 and app.session.profile.inventory.haring == 1 and not app.ring_popup and app.saves.writes == writes+1 and app.saves.load_profile().profile.equipment.rings.crt_0 == 1)
	_check("equipping in warehouse preserves live actor stats until reentry",app.battle == battle and battle.player == actor and is_equal_approx(float(actor.definition.max_hp),130.0))
	await _click(_menu("warehouse_close"))
	_check("source warehouse closes to same battle and current HUD",app.screen == "battle" and app.battle == battle and battle.player == actor and app.ui.source_hud == hud and not battle.paused)
	observations.append({"phase":"storage","writes":app.saves.writes,"profile":app.session.profile.duplicate(true),"source_ticks":app.session.run.source_ticks})

func _test_reentry_failure() -> void:
	var old_battle: Node2D = app.battle
	if not await _dropdown("dropdown_actions"):return
	await _click(_menu("menu_return"))
	_check("source return routes to original title and disposes encounter",app.screen == "title" and not is_instance_valid(app.battle) and (not is_instance_valid(old_battle) or old_battle.is_queued_for_deletion()))
	await _click(_ui("Training"))
	await _click(_ui("Character_crt_0"))
	var battle := _controlled_battle()
	_check("normal training reentry applies saved HP10 ring once",app.screen == "battle" and battle.is_training() and is_equal_approx(float(battle.player.definition.max_hp),140.0) and is_equal_approx(battle.player.hp,140.0) and app.session.profile.equipment.rings.crt_0 == 1)
	battle.grenades.f.active = true # Explicit inventory fixture before death; not a fabricated load success.
	battle.grenades.f.stock = 3
	battle.deal_damage(battle.player,battle.player,battle.player.hp,"integration fixture: lethalHP to test real failure route",false)
	battle.step({})
	app._process(0.0)
	_check("real defeat settlement opens original failure panel over ended training",app.screen == "result" and battle.ended and is_instance_valid(app.ui.source_menu) and app.ui.source_menu.buttons.has("failure_retry") and app.session.run.outcome == "defeat")
	_check("source failure page removes inventory presentation without a second stock value",not app.ui.source_hud._grenade_views.f.group.visible and battle.grenades.f.stock == 3)
	await _click(_menu("failure_retry"))
	var retried := _controlled_battle()
	_check("native source failure retry rebuilds same training with persistent equipment",app.screen == "battle" and retried != battle and retried.is_training() and not retried.ended and is_equal_approx(float(retried.player.definition.max_hp),140.0) and app.session.profile.progress.gold == 48 and app.session.profile.settings.auto_save)
	retried.deal_damage(retried.player,retried.player,retried.player.hp,"integration fixture: second failure return",false)
	retried.step({})
	await _click(_menu("failure_return"))
	_check("native source failure return reaches title and preserves full persistent profile",app.screen == "title" and not is_instance_valid(app.battle) and app.saves.load_profile().profile == app.session.profile)
	observations.append({"phase":"failure_return","writes":app.saves.writes,"profile":app.session.profile.duplicate(true),"screen":app.screen})

func _finish() -> void:
	var failures := checks.filter(func(row:Dictionary)->bool:return not row.passed).size()
	var output := OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if output.is_empty():output = "res://artifacts/leba_act02_20261115/integration"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var file := FileAccess.open(output.path_join("act02_integration_tests.json"),FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"suite":"act02_integration","checks":checks,"failures":failures,"observations":observations,"scope":"Actual Main normal title/training/source-menu/settings/warehouse/failure flows using native SubViewport GUI input. Headless Dummy, real isolated disk saves counted without substituting success. Owned ring, persistent gold mutation, distant enemy and lethalHP are explicit fixtures. No OS keyboard/GPU pixel/native Flash/complete skill claim."},"\t")+"\n")
		file.close()
	print("ACT02_INTEGRATION_TESTS_RESULT "+JSON.stringify({"checks":checks.size(),"failures":failures}))
	quit(0 if failures == 0 else 1)
