extends SceneTree
## ACT04 real Main, native SubViewport mouse routing and formal input combat.
## No stage-win, enemy HP/AI, position, MP or cooldown is seeded. A pre-owned
## ring and public lethal damage are separately labelled lifecycle fixtures.
const MainScene=preload("res://scenes/main.tscn")
const Save=preload("res://scripts/services/save_store.gd")
const ACTIONS:=["move_left","move_right","attack","skill","skill_s","jump","down","skill_z","skill_a","skill_w","load_f","load_g","load_h","skill_q","skill_t","skill_e","skill_r","skill_y","skill_v","aim_up"]
const KEY_ACTIONS:={KEY_X:"attack",KEY_D:"skill",KEY_S:"skill_s",KEY_Z:"skill_z",KEY_A:"skill_a",KEY_W:"skill_w",KEY_F:"load_f",KEY_G:"load_g",KEY_H:"load_h",KEY_Q:"skill_q",KEY_E:"skill_e",KEY_R:"skill_r",KEY_V:"skill_v"}
var app: Node
var viewport: SubViewport
var checks: Array[Dictionary]=[]
var combat_runs: Array[Dictionary]=[]
var formal_exists:=false
var formal_hash:=""
var author_hashes: Dictionary={}
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
	if KEY_ACTIONS.has(code):Input.action_press(KEY_ACTIONS[code])
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


func _fresh_profile(label: String) -> void:
	_release()
	app._dispose_battle()
	app.saves=Save.new("user://act04_flow/%s_%d_%d/profile.json"%[label,Time.get_unix_time_from_system(),Time.get_ticks_usec()])
	app.session.profile=app.saves.default_profile()
	app.progression.normalize(app.session.profile)
	app.action_lab=false
	app.flow_events.clear()
	app.show_title()

func _select_adventure() -> bool:
	_fresh_profile("adventure")
	await process_frame
	if not await _click(_button("Start")):return false
	_check("normal title Start opens characters before difficulty",app.screen=="characters")
	if not await _click(_button("Character_crt_2")):return false
	_check("CRT2 selection opens difficulty",app.screen=="difficulty" and app.session.profile.selection.character_id=="crt_2",app.screen)
	if not await _click(_button("Difficulty_expert")):return false
	_check("expert selection opens root2 intro",app.screen=="intro" and app.selected_stage=="root_2" and app.session.profile.selection.difficulty_id=="expert",app.screen)
	return app.screen=="intro"

func _enter_selected(expected: String) -> Node2D:
	if app.screen=="intro":
		if not await _click(_button("EnterBattle")):return null
	if not is_instance_valid(app.battle):
		_check("normal stage creates encounter "+expected,false,app.screen)
		return null
	var battle:=_manual_battle()
	_check("normal flow enters CRT2 "+expected,app.selected_stage==expected and app.session.run.character_id=="crt_2" and int(battle.player.definition.source_crt)==2 and not app.action_lab,{"screen":app.screen,"stage":app.selected_stage})
	if app.screen=="dialogue":
		if not await _click(_button("DialogueSkip")):return null
	_check("opening dialogue resumes same encounter "+expected,app.screen=="battle" and not battle.paused and app.battle==battle)
	return battle

func _cooldown(battle: Node2D, id: String) -> int:
	var row: Dictionary=battle.player.definition.actions[id]
	return int(battle.player.cooldowns.get(str(row.get("cooldown_key",id)),0))

func _choose_skill(battle: Node2D, tick: int) -> Key:
	var actor: Node2D=battle.player
	if tick%3!=0:return KEY_X
	# All choices pass through the real input transaction. Read readiness to
	# avoid an automation policy that endlessly presses an unavailable skill.
	var choices: Array=[[KEY_R,"skill_r"],[KEY_G,"skill_g"],[KEY_S,"skill_s_start"],[KEY_V,"skill_v"],[KEY_D,"skill_d"],[KEY_Z,"skill_z"],[KEY_F,"skill_f"],[KEY_A,"skill_a"]]
	if battle.pren==1:choices.insert(2,[KEY_W,"skill_w"]);choices.insert(3,[KEY_E,"skill_e"]);choices.insert(4,[KEY_Q,"skill_q"])
	for choice: Array in choices:
		var id: String=choice[1]
		var data: Dictionary=actor.definition.actions[id]
		if _cooldown(battle,id)>0:continue
		if id=="skill_r" and int(battle.crt2.r_slot_frame)!=430:continue
		if actor.mp<float(data.required_mp) or actor.hp<float(data.get("required_hp",0))+15.0 or int(battle.session.profile.progress.clear_cubes)<int(data.cubes):continue
		return choice[0]
	return KEY_X

func _legal_combat(battle: Node2D, stage_id: String) -> bool:
	seed(20261117+int(stage_id.trim_prefix("root_")))
	var gold_before: int=app.session.profile.progress.gold
	var clears_before: int=app.session.profile.progress.clears.get(stage_id,0)
	var initial_hp: Dictionary={}
	for enemy: Node2D in battle.enemies:
		initial_hp[enemy.identifier]=enemy.hp
	var states: Dictionary={}
	var samples: Array=[]
	var saw_contact_damage:=false
	var count:=0
	for tick in range(7000):
		if battle.ended:break
		var actor: Node2D=battle.player
		var target: Node2D=null
		for enemy: Node2D in battle.enemies:
			if enemy.hp>0 and (target==null or absf(enemy.position.x-actor.position.x)<absf(target.position.x-actor.position.x)):target=enemy
		var code: Key=KEY_NONE
		var move:=0.0
		var held:=""
		if target!=null:
			var distance: float=target.position.x-actor.position.x
			if actor.state in ["idle","move"]:
				if absf(distance)>100:move=signf(distance)
				elif absf(distance)<40:move=-signf(distance)
				if absf(distance)<190:code=_choose_skill(battle,tick)
			elif str(actor.state).begins_with("basic") or str(actor.state).begins_with("pren_basic"):
				if tick%3==0:code=KEY_X
				held="attack"
			elif actor.state in ["skill_s_start","hurt_z"]:held="skill_s"
			elif actor.state=="skill_w" and actor.source_frame<85:held="skill_w"
		_tick(battle,code,move,held)
		states[actor.state]=int(states.get(actor.state,0))+1
		count+=1
		for enemy: Node2D in battle.enemies:
			if enemy.hp<float(initial_hp[enemy.identifier]):saw_contact_damage=true
		if tick%50==0:samples.append({"tick":tick,"hp":actor.hp,"mp":actor.mp,"position":actor.position,"action":actor.state,"frame":actor.source_frame,"enemies":battle.enemies.map(func(e:Node2D)->Dictionary:return {"id":e.identifier,"hp":e.hp,"state":e.state,"position":e.position})})
	var victory: bool=battle.ended and app.session.run.outcome=="victory" and battle.player.hp>0 and battle.enemies.all(func(e:Node2D)->bool:return e.hp<=0)
	combat_runs.append({"stage":stage_id,"seed":20261117+int(stage_id.trim_prefix("root_")),"ticks":count,"victory":victory,"hp":battle.player.hp,"outcome":app.session.run.get("outcome"),"states":states,"samples":samples,"initial_enemy_hp":initial_hp,"fixture":"No combat state seeded; real input, source AI and collision only"})
	_check("CRT2 real input causes contact damage "+stage_id,saw_contact_damage)
	_check("CRT2 actual combat defeats all enemies "+stage_id,victory,combat_runs[-1])
	if not victory:return false
	var gold_after: int=app.session.profile.progress.gold
	_check("one stage clear and zero living enemies "+stage_id,app.session.run.enemies_remaining==0 and int(app.session.profile.progress.clears.get(stage_id,0))==clears_before+1 and gold_after>gold_before,app.session.run)
	for n in range(20):_tick(battle)
	_check("ended ticks never duplicate death reward "+stage_id,app.session.profile.progress.gold==gold_after and app.session.profile.progress.clears.get(stage_id,0)==clears_before+1)
	return true

func _result_continue() -> bool:
	if not await _click(_button("Continue")):return false
	_check("result uses original clear dialogue",app.screen=="dialogue" and app.dialogue_id.ends_with("_clear"),app.dialogue_id)
	if not await _click(_button("DialogueSkip")):return false
	for n in range(100):
		if app.screen!="transition":break
		app._process(0.04)
	return true

func _storage_roundtrip(expected_screen: String) -> void:
	var menu: Control=app.ui.source_menu
	_check("CRT2 original warehouse page4 is real",app.screen==expected_screen and app.storage_page==4 and _warehouse_is_real("crt_2"),menu.errors.duplicate())
	await _click(menu.buttons.get("warehouse_crt2_rings",menu.buttons.get("warehouse_rings")))
	_check("CRT2 warehouse rings page8",app.storage_page==8 and menu.current_page==8)
	await _click(menu.buttons.get("warehouse_weapons"))
	_check("rings weapons returns current CRT2 page4",app.storage_page==4 and _warehouse_is_real("crt_2"),menu.errors.duplicate())
	await _click(menu.buttons.get("warehouse_close"))

func _adventure() -> void:
	if not await _select_adventure():return
	for stage_id: String in ["root_2","root_4","root_6"]:
		var battle: Node2D=await _enter_selected(stage_id)
		if battle==null or not _legal_combat(battle,stage_id):return
		if not await _result_continue():return
	_check("root6 actual victory reaches original root7",app.screen=="intermission" and app.intermission_id=="intermission_7" and not is_instance_valid(app.battle),app.flow_events)
	if app.screen!="intermission":return
	await _click(_button("Inventory"))
	await _storage_roundtrip("intermission_storage")
	_check("warehouse closes back to root7",app.screen=="intermission" and app.intermission_id=="intermission_7")
	await _click(_button("Continue"))
	_check("root7 Continue executes root8 cleanup",app.flow_events.any(func(row:Dictionary)->bool:return row.get("kind")=="cleanup" and int(row.get("source_root_frame",0))==8),app.flow_events)
	var final_battle: Node2D=await _enter_selected("root_9")
	if final_battle==null or not _legal_combat(final_battle,"root_9"):return
	if not await _result_continue():return
	_check("root9 actual victory reaches existing root10 boundary",app.screen=="intermission" and app.intermission_id=="intermission_10" and not is_instance_valid(app.battle))
	_check("root10 unsupported continuation stays explicit",is_instance_valid(_button("Continue")) and _button("Continue").disabled and not _button("Menu").disabled)
	await _click(_button("Inventory"))
	await _storage_roundtrip("intermission_storage")
	app.save_progress()
	var saved: Dictionary=app.saves.load_profile()
	_check("isolated save restores actual four clears and CRT2 selection",saved.ok and saved.profile.selection.character_id=="crt_2" and ["root_2","root_4","root_6","root_9"].all(func(id:String)->bool:return int(saved.profile.progress.clears.get(id,0))==1) and saved.profile.progress.gold==app.session.profile.progress.gold,saved)
	await _click(_button("Menu"))
	_check("root10 Menu returns title without encounter residue",app.screen=="title" and not is_instance_valid(app.battle))

func _training_storage_failure() -> void:
	_fresh_profile("training_lifecycle")
	await process_frame
	await _click(_button("Training"))
	await _click(_button("Character_crt_2"))
	var battle:=_manual_battle()
	_check("normal training entry CRT2 without action lab",app.screen=="battle" and battle.is_training() and battle.player.definition.source_crt==2 and not app.action_lab)
	app.session.profile.inventory.haring=1 # Explicit already-owned item fixture.
	await _click(_button("TrainingStorage"))
	await _storage_roundtrip("training_storage")
	_check("training warehouse returns same live encounter",app.screen=="battle" and app.battle==battle and not battle.paused)
	await _click(_button("TrainingStorage"))
	await _click(app.ui.source_menu.buttons.get("warehouse_crt2_rings",app.ui.source_menu.buttons.get("warehouse_rings")))
	await _click(app.ui.source_menu.buttons.get("ring_owned"))
	await _click(app.ui.source_menu.buttons.get("ring_equip_crt2"))
	_check("native ring selection equips CRT2 and saves isolated profile",app.session.profile.equipment.rings.crt_2==1 and app.saves.load_profile().profile.equipment.rings.crt_2==1)
	await _click(app.ui.source_menu.buttons.get("warehouse_close"))
	var gold: int=app.session.profile.progress.gold
	battle.deal_damage(battle.player,battle.player,battle.player.hp,"explicit lifecycle fixture; not enemy combat evidence",false)
	_tick(battle)
	_check("explicit lethal fixture opens actual failure panel",app.screen=="result" and app.session.run.outcome=="defeat" and app.ui.source_menu.buttons.has("failure_retry"))
	await _click(app.ui.source_menu.buttons.get("failure_retry"))
	var retry:=_manual_battle()
	_check("failure retry creates fresh CRT2 training with saved ring",retry!=battle and retry.is_training() and retry.player.definition.source_crt==2 and is_equal_approx(retry.player.hp,140.0) and retry.pren==0 and retry._crt2_objects.is_empty() and app.session.profile.progress.gold==gold)
	app.show_title()
	await process_frame
	await _click(_button("Training"))
	await _click(_button("Character_crt_2"))
	var reentered:=_manual_battle()
	_check("return and normal reentry keep profile but reset encounter",reentered!=retry and reentered.pren==0 and int(reentered.crt2.r_slot_frame)<430 and is_equal_approx(reentered.player.hp,140.0) and app.session.profile.equipment.rings.crt_2==1)

func _run() -> void:
	if "--test-mode" not in OS.get_cmdline_user_args():push_error("Requires isolated --test-mode");quit(2);return
	formal_exists=FileAccess.file_exists("user://profile.json")
	if formal_exists:formal_hash=FileAccess.get_sha256("user://profile.json")
	for folder: String in ["res://content/actions/crt2","res://content/components/crt2","res://content/characters"]:
		for filename: String in DirAccess.get_files_at(folder):
			if filename.ends_with(".tres"):author_hashes[folder.path_join(filename)]=FileAccess.get_sha256(folder.path_join(filename))
	viewport=SubViewport.new();viewport.size=Vector2i(550,400);viewport.disable_3d=true;root.add_child(viewport)
	app=MainScene.instantiate();viewport.add_child(app);app.set_process(false)
	_check("Main starts actual CRT2 content",app.startup_ok and app.test_mode and app.database.characters.crt_2.enabled,app.database.issues)
	if app.startup_ok:
		await _adventure()
		await _training_storage_failure()
	_release()
	_check("formal profile bytes unchanged",FileAccess.file_exists("user://profile.json")==formal_exists and (not formal_exists or FileAccess.get_sha256("user://profile.json")==formal_hash))
	var author_ok:=true
	for path: String in author_hashes:author_ok=author_ok and FileAccess.get_sha256(path)==author_hashes[path]
	_check("runtime preserves all CRT2 author resources",author_ok)
	app._dispose_battle()
	var drained: bool=await app.audio.stop_and_drain(1.0)
	_check("audio references drain after all flows",drained)
	viewport.queue_free();await process_frame
	var failures: int=checks.filter(func(row:Dictionary)->bool:return not row.passed).size()
	var path:=OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if path.is_empty():path="res://artifacts/leba_act04_20261117/flow/run_%d_%d"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	var file:=FileAccess.open(path.path_join("act04_flow.json"),FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify({"suite":"ACT04 CRT2 normal flow and actual input combat","checks":checks,"failures":failures,"combat_runs":combat_runs,"godot":Engine.get_version_info(),"fixtures":["pre-owned ring item","public lethal-damage call only for separate failure lifecycle"],"not_tested":["native OS keyboard dispatch","original CRT2 per-tick dynamic oracle","audible listening","GPU visual review","unimplemented root12/endings"]},"\t")+"\n");file.close()
	print("ACT04_FLOW_RESULT ",JSON.stringify({"checks":checks.size(),"failures":failures,"report":path}))
	quit(0 if failures==0 else 1)
