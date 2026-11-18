extends SceneTree
## Actual Main/native GUI routing and shared input. Headless/Dummy only.
## The root7 starting node, owned ring, and failure-health seed are explicit
## lifecycle fixtures. The separate root9 combat cases never write actor HP,
## enemy HP, positions, MP, cooldowns, rewards, markers or victory outcomes.
## This is not an original Flash/Ruffle root9 comparison or full-game test.
const MainScene = preload("res://scenes/main.tscn")
const Save = preload("res://scripts/services/save_store.gd")
const ACTIONS := ["move_left","move_right","attack","skill","skill_s","jump","down","skill_z","skill_a","skill_w","load_f","load_g","load_h","skill_q","skill_t","skill_e","skill_r","skill_y","skill_v","aim_up"]
var app: Node
var viewport: SubViewport
var checks: Array[Dictionary] = []
var combat_runs: Array[Dictionary] = []
var formal_exists := false
var formal_hash := ""
var authored_hashes: Dictionary = {}

func _initialize() -> void:call_deferred("_run")

func _check(label: String, ok: bool, detail: Variant = "") -> void:
	checks.append({"name":label,"passed":ok,"detail":detail})
	print(("PASS " if ok else "FAIL ")+label+" "+str(detail))

func _release() -> void:
	for action: String in ACTIONS:Input.action_release(action)

func _button(id: String) -> BaseButton:return app.ui.get_button(id)

func _warehouse_is_real(character_id: String) -> bool:
	var menu: Control = app.ui.source_menu
	var page := menu.get_node_or_null("Pages/warehouse_"+str(2+int(character_id.trim_prefix("crt_"))))
	var error_label := menu.get_node_or_null("Error")
	return menu.errors.is_empty() and is_instance_valid(page) and page.is_visible_in_tree() and is_instance_valid(menu.panel_root) and menu.buttons.has("warehouse_close") and (error_label == null or not error_label.visible)

func _click(button: BaseButton) -> bool:
	if not is_instance_valid(button) or button.disabled:
		_check("native GUI requested enabled button",false,str(button))
		return false
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	viewport.push_input(motion,true)
	await process_frame
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		viewport.push_input(event,true)
		await process_frame
	return true

func _key_event(battle: Node2D, code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	battle._unhandled_input(event)

func _tick(battle: Node2D, code: Key = KEY_NONE, move := 0.0, hold_action := "") -> void:
	_release()
	if move < 0:Input.action_press("move_left")
	if move > 0:Input.action_press("move_right")
	if not hold_action.is_empty():Input.action_press(hold_action)
	if code != KEY_NONE:_key_event(battle,code,true)
	var commands: Dictionary = battle.take_commands()
	battle.advance_real_time(0.04)
	battle.step(commands)
	if code != KEY_NONE:_key_event(battle,code,false)
	_release()
	app._process(0.04)

func _manual_battle() -> Node2D:
	var battle: Node2D = app.battle
	battle.set_physics_process(false)
	battle.manual_clock = true
	return battle

func _fresh_profile(character_id: String) -> void:
	_release()
	app._dispose_battle()
	app.saves = Save.new("user://act03_flow/%s_%d_%d/profile.json"%[character_id,Time.get_unix_time_from_system(),Time.get_ticks_usec()])
	app.session.profile = app.saves.default_profile()
	app.progression.normalize(app.session.profile)
	app.action_lab = false
	app.flow_events.clear()
	app.show_title()

func _select_character(character_id: String, difficulty_id := "expert") -> bool:
	_fresh_profile(character_id)
	await process_frame
	if not await _click(_button("Start")):return false
	if not await _click(_button("Character_"+character_id)):return false
	if not await _click(_button("Difficulty_"+difficulty_id)):return false
	_check(character_id+" native selection preserves adventure difficulty and character",app.screen == "intro" and app.session.profile.selection.character_id == character_id and app.session.profile.selection.difficulty_id == difficulty_id,{"screen":app.screen,"difficulty":difficulty_id})
	# Prior root2/4/6 gameplay is covered by its existing suites. Seed only the
	# intermission entry for this bounded root7→9→10 test, never a win outcome.
	app._next_stage("root_7")
	await process_frame
	_check(character_id+" explicit root7 navigation fixture reaches real authored page",app.screen == "intermission" and app.intermission_id == "intermission_7")
	return app.screen == "intermission"

func _enter9(character_id: String) -> Node2D:
	if not await _click(_button("Continue")):return null
	_check(character_id+" root7 Continue executes cleanup8 then root9 opening",app.selected_stage == "root_9" and app.screen == "dialogue" and app.dialogue_id == "root_9_open" and app.flow_events.any(func(x:Dictionary)->bool:return x.get("kind") == "cleanup" and int(x.get("source_root_frame",0)) == 8),app.flow_events)
	if not is_instance_valid(app.battle):return null
	var battle := _manual_battle()
	var expected_hp := float({"expert":500.0,"master":750.0,"king":1000.0}[str(app.session.run.difficulty_id)])
	_check(character_id+" root9 uses the selected actor and difficulty-scaled source HP",app.session.run.character_id == character_id and battle.player.definition.source_crt == int(character_id.trim_prefix("crt_")) and battle.enemies.size() == 1 and is_equal_approx(battle.enemies[0].hp,expected_hp) and is_equal_approx(battle.player.hp,100.0),{"player":battle.player.hp,"enemy":battle.enemies[0].hp,"difficulty":app.session.run.difficulty_id})
	if character_id == "crt_0":
		_check("crt0 original4491 host initialized at this authored stage",not battle._y_summon.is_empty() and is_instance_valid(battle._y_summon.get("visual")),battle._y_summon.keys())
	if not await _click(_button("DialogueSkip")):return null
	_check(character_id+" opening source7→16 resumes same encounter",app.screen == "battle" and app.battle == battle and not battle.paused)
	return battle

func _legal_combat(character_id: String) -> bool:
	if not await _select_character(character_id):return false
	var battle: Node2D = await _enter9(character_id)
	if battle == null:return false
	seed(20261116)
	var before_gold := int(app.session.profile.progress.gold)
	var used: Dictionary = {}
	var samples: Array[Dictionary] = []
	var choices: Array[Key] = [KEY_D,KEY_S,KEY_V,KEY_G,KEY_A,KEY_H,KEY_F,KEY_E,KEY_R,KEY_Z,KEY_X]
	var index := 0
	var tick_count := 0
	for tick in range(5000):
		if battle.ended:break
		var enemy: Node2D = battle.enemies[0]
		var actor: Node2D = battle.player
		var code: Key = KEY_NONE
		var move := 0.0
		var hold_action := ""
		var distance := enemy.position.x-actor.position.x
		if actor.state in ["idle","move"]:
			# Move by normal InputMap state and use normal keyboard listeners;
			# never teleport or stop the enemy's AI/timer to manufacture a win.
			if absf(distance) > 190.0:move = signf(distance)
			elif absf(distance) < 55.0:move = -signf(distance)
			if tick%3 == 0:
				code = choices[index%choices.size()]
				index += 1
		elif actor.state == "skill_q":
			code = KEY_UP
			hold_action = "aim_up"
		elif actor.state in ["basic","basic2","basic3","basic4","basic5","basic6"] and tick%5 == 0:code = KEY_X
		_tick(battle,code,move,hold_action)
		used[actor.state] = int(used.get(actor.state,0))+1
		tick_count += 1
		if tick%50 == 0:samples.append({"tick":tick,"hp":actor.hp,"mp":actor.mp,"enemy_hp":enemy.hp,"player_x":actor.position.x,"enemy_x":enemy.position.x,"state":actor.state,"enemy_state":enemy.state})
	var passed: bool = battle.ended and app.session.run.outcome == "victory" and battle.enemies[0].hp <= 0.0 and battle.player.hp > 0.0
	combat_runs.append({"character_id":character_id,"seed":20261116,"ticks":tick_count,"outcome":app.session.run.get("outcome"),"player_hp":battle.player.hp,"enemy_hp":battle.enemies[0].hp,"states":used,"samples":samples,"fixture":"root7 navigation only; combat actor/enemy state never seeded or overwritten","passed":passed})
	_check(character_id+" legal shared-input combat defeats complete500HP7437",passed,combat_runs[-1].duplicate())
	if not passed:return false
	_check(character_id+" death awards300 exactly once and removes one living enemy",int(app.session.profile.progress.gold)-before_gold == 300 and app.session.run.enemies_remaining == 0 and app.session.run.earned_gold == 300 and int(app.session.profile.progress.clears.get("root_9",0)) == 1,app.session.run)
	for i in range(20):_tick(battle)
	_check(character_id+" ended ticks do not duplicate reward or completion",int(app.session.profile.progress.gold)-before_gold == 300 and int(app.session.profile.progress.clears.get("root_9",0)) == 1)
	await _click(_button("Continue"))
	_check(character_id+" real result Continue opens original clear dialogue",app.screen == "dialogue" and app.dialogue_id == "root_9_clear")
	await _click(_button("DialogueSkip"))
	_check(character_id+" root9 clear22 reaches root10 without fabricated ending",app.screen == "intermission" and app.intermission_id == "intermission_10" and not is_instance_valid(app.battle))
	_check(character_id+" root10 leaves unrecovered root12 explicit and usable return",is_instance_valid(_button("Continue")) and _button("Continue").disabled and is_instance_valid(_button("Menu")) and not _button("Menu").disabled)
	app.save_progress()
	var saved: Dictionary = app.saves.load_profile()
	_check(character_id+" actual isolated save preserves gold clear character",saved.ok and saved.profile.progress.gold == before_gold+300 and saved.profile.selection.character_id == character_id and saved.profile.progress.clears.root_9 == 1)
	return true

func _storage_and_failure(character_id: String) -> void:
	if not await _select_character(character_id):return
	app.session.profile.inventory.haring = 1 # Explicit pre-owned ring fixture.
	await _click(_button("Inventory"))
	_check(character_id+" intermission warehouse opens correct original character page",app.screen == "intermission_storage" and app.storage_page == 2+int(character_id.trim_prefix("crt_")) and _warehouse_is_real(character_id),app.ui.source_menu.errors.duplicate())
	# Exercise the real progression service through Main's original storage intent.
	# Native ring popup/hit regions have their dedicated shared UI regression.
	app._on_intent("storage_action",{"operation":"equip","character_id":character_id})
	_check(character_id+" equip persists one authoritative existing ring slot",int(app.session.profile.equipment.rings[character_id]) == 1 and app.saves.load_profile().profile.equipment.rings[character_id] == 1)
	_check(character_id+" equipped warehouse refresh retains real authored page",_warehouse_is_real(character_id),app.ui.source_menu.errors.duplicate())
	app._on_intent("storage_close",null)
	_check(character_id+" warehouse close returns to same intermission not missing battle",app.screen == "intermission" and app.intermission_id == "intermission_7" and not app.ui.source_menu.visible and not is_instance_valid(app.battle))
	await _click(_button("Continue"))
	if not is_instance_valid(app.battle):return
	var prior := _manual_battle()
	await _click(_button("DialogueSkip"))
	_check(character_id+" next encounter applies saved ring HP without actor state leakage",is_equal_approx(prior.player.hp,110.0) and is_equal_approx(prior.player.definition.max_hp,110.0) and is_equal_approx(prior.enemies[0].hp,500.0))
	prior.player.hp = 0.0 # Failure lifecycle fixture, not an enemy damage claim.
	_tick(prior)
	_check(character_id+" explicit failure fixture reaches real failure overlay",app.screen == "result" and app.session.run.outcome == "defeat" and app.ui.source_menu.visible)
	var retry: BaseButton = app.ui.source_menu.buttons.get("failure_retry")
	await _click(retry)
	_check(character_id+" failure retry creates new root9 and preserves selected gear",is_instance_valid(app.battle) and app.battle != prior and app.selected_stage == "root_9" and app.session.run.character_id == character_id and is_equal_approx(app.battle.player.hp,110.0) and is_equal_approx(app.battle.enemies[0].hp,500.0) and app.session.run.enemies_remaining == 1)
	_check(character_id+" failure never awards a stage clear or gold",int(app.session.profile.progress.gold) == 0 and not app.session.profile.progress.clears.has("root_9"))
	app._next_stage("root_10") # Navigation fixture checks root10 warehouse return.
	await process_frame
	await _click(_button("Inventory"))
	_check(character_id+" root10 warehouse also selects current actor page",app.screen == "intermission_storage" and app.storage_page == 2+int(character_id.trim_prefix("crt_")) and _warehouse_is_real(character_id),app.ui.source_menu.errors.duplicate())
	app._on_intent("storage_close",null)
	_check(character_id+" root10 storage returns to root10 without repeating rewards",app.screen == "intermission" and app.intermission_id == "intermission_10" and app.session.profile.progress.gold == 0)
	await _click(_button("Retry"))
	_check(character_id+" root10 retry goes through root8 to root9 opening",app.selected_stage == "root_9" and app.screen == "dialogue" and app.dialogue_id == "root_9_open")
	app.show_title()
	_check(character_id+" return frees encounter while retaining character progress",app.screen == "title" and not is_instance_valid(app.battle) and app.session.profile.selection.character_id == character_id)

func _other_difficulties() -> void:
	# Only selection/initialization is tested here; these are not high-difficulty wins.
	for row: Array in [["crt_0","master"],["crt_1","king"]]:
		if not await _select_character(row[0],row[1]):continue
		var battle := await _enter9(row[0])
		if battle != null:
			_check(row[1]+" entering and leaving does not grant reward",app.session.profile.progress.gold == 0 and not app.session.profile.progress.clears.has("root_9"))
		app.show_title()

func _run() -> void:
	if "--test-mode" not in OS.get_cmdline_user_args():
		push_error("必须 --test-mode，拒绝使用正式存档")
		quit(2)
		return
	formal_exists = FileAccess.file_exists("user://profile.json")
	if formal_exists:formal_hash = FileAccess.get_sha256("user://profile.json")
	for path: String in ["res://scenes/stages/root_9.tscn","res://content/stages/root_9.tres","res://content/enemies/goblin_7437.tres","res://data/act03_flow.json","res://content/index.tres"]:
		if FileAccess.file_exists(path):authored_hashes[path] = FileAccess.get_sha256(path)
	viewport = SubViewport.new()
	viewport.size = Vector2i(550,400)
	viewport.disable_3d = true
	root.add_child(viewport)
	app = MainScene.instantiate()
	viewport.add_child(app)
	app.set_process(false)
	_check("actual Main boots with registered root9 author scene and7437 data",app.startup_ok and app.test_mode and app.database.stages.has("root_9") and app.database.enemies.has("goblin_7437"),app.database.issues)
	if app.startup_ok and app.database.stages.has("root_9"):
		for character_id: String in ["crt_0","crt_1"]:
			await _legal_combat(character_id)
			await _storage_and_failure(character_id)
		await _other_difficulties()
	_release()
	_check("formal profile existence and bytes remain unchanged",FileAccess.file_exists("user://profile.json") == formal_exists and (not formal_exists or FileAccess.get_sha256("user://profile.json") == formal_hash))
	var author_unchanged := true
	for path: String in authored_hashes:
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != authored_hashes[path]:author_unchanged = false
	_check("runtime never saves actor state into author files",author_unchanged,authored_hashes.keys())
	app._dispose_battle()
	await app.audio.stop_and_drain(1.0)
	viewport.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	var failures := checks.filter(func(x:Dictionary)->bool:return not bool(x.passed)).size()
	var report := {"suite":"ACT03 flow and input combat","godot":Engine.get_version_info(),"checks":checks,"combat_runs":combat_runs,"failures":failures,"evidence":"Headless actual Main/SubViewport/native GUI + shared input; no original root9 dynamic comparison; explicit lifecycle fixtures separate","limitations":["root7 starting navigation is seeded; this suite does not replay root2/4/6","AI keyboard driver is deterministic automation, not manual play or original-host timing proof","No root12 or ending is fabricated"]}
	var path := "res://artifacts/leba_act03_20261116/flow/latest.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--report=res://artifacts/"):path = argument.trim_prefix("--report=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	print("ACT03_FLOW checks=%d failures=%d report=%s"%[checks.size(),failures,path])
	quit(0 if failures == 0 else 1)
