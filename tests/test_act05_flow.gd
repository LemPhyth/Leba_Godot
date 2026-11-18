extends SceneTree
## ACT05 real Main, native SubViewport mouse routing and formal input combat.
## Run headless with --audio-driver Dummy --script this_file -- --test-mode.
## Written for integrated regression; source observations are not runtime fixtures.
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
var isolated_profiles: Array[String]=[]
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
	app.saves=Save.new("user://act05_flow/%s_%d_%d/profile.json"%[label,Time.get_unix_time_from_system(),Time.get_ticks_usec()])
	isolated_profiles.append(app.saves.path)
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
	_locked_characters("CRT3 adventure selection")
	if not await _click(_button("Character_crt_3")):return false
	_check("CRT3 selection opens difficulty",app.screen=="difficulty" and app.session.profile.selection.character_id=="crt_3",app.screen)
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
	_check("normal flow enters CRT3 "+expected,app.selected_stage==expected and app.session.run.character_id=="crt_3" and int(battle.player.definition.source_crt)==3 and not app.action_lab,{"screen":app.screen,"stage":app.selected_stage})
	if app.screen=="dialogue":
		if not await _click(_button("DialogueSkip")):return null
	_check("opening dialogue resumes same encounter "+expected,app.screen=="battle" and not battle.paused and app.battle==battle)
	return battle

func _cooldown(battle: Node2D, id: String) -> int:
	var row: Dictionary=battle.player.definition.actions[id]
	return int(battle.player.cooldowns.get(str(row.get("cooldown_key",id)),0))

func _choose_skill(battle: Node2D, tick: int) -> Key:
	var actor: Node2D=battle.player
	# A source-frame modulo gate can starve skills when a combo always ends
	# on another residue. Read readiness on every genuine neutral decision.
	# Read authored readiness only. Every cast still passes the actual input,
	# cost, slot and allowed-parent transaction; this is not an action shortcut.
	var choices: Array=[[KEY_E,"skill_e"],[KEY_W,"skill_w"],[KEY_G,"skill_g"],[KEY_Q,"skill_q"],[KEY_D,"skill_d"],[KEY_F,"skill_f"],[KEY_V,"skill_v"],[KEY_A,"skill_a"],[KEY_H,"skill_h"]]
	for choice: Array in choices:
		var id: String=choice[1]
		if not actor.definition.actions.has(id):continue
		var data: Dictionary=actor.definition.actions[id]
		if _cooldown(battle,id)>0:continue
		if id=="skill_e" and int(battle.crt3.e_slot_frame)!=442:continue
		if actor.mp<float(data.get("required_mp",data.get("cost",0))) or int(battle.session.profile.progress.clear_cubes)<int(data.get("cubes",0)):continue
		return choice[0]
	return KEY_X

func _legal_combat(battle: Node2D, stage_id: String) -> bool:
	seed(20261117+int(stage_id.trim_prefix("root_")))
	var gold_before: int=app.session.profile.progress.gold
	var clears_before: int=app.session.profile.progress.clears.get(stage_id,0)
	var initial_hp: Dictionary={}
	for enemy: Node2D in battle.enemies:
		initial_hp[enemy.identifier]=enemy.hp
	var expected_hp: Dictionary={"root_2":[200.0],"root_4":[200.0,200.0,200.0,200.0],"root_6":[400.0],"root_9":[500.0]}
	var starting_hp: Array=initial_hp.values()
	starting_hp.sort()
	_check("expert encounter keeps full source HP "+stage_id,starting_hp==expected_hp[stage_id],starting_hp)
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
				# Turn/approach in real input ticks before attacking. Action input is
				# dispatched before ground movement, so simultaneous X+direction
				# cannot be assumed to turn a newly started attack.
				if absf(distance)>65 or (not is_zero_approx(distance) and actor.facing!=int(signf(distance))):
					move=signf(distance)
				else:code=_choose_skill(battle,tick)
			elif str(actor.state).begins_with("basic"):
				if absf(distance)<100 and actor.source_frame>=9 and tick%3==0:code=KEY_S
			elif str(actor.state).begins_with("skill_s"):
				if absf(distance)<100 and actor.source_frame>=9 and tick%3==0:code=KEY_X
			elif str(actor.state).begins_with("skill_d") or actor.state=="skill_g":
				for branch: Dictionary in actor.definition.actions[actor.state].get("branches",[]):
					if str(branch.get("kind",""))=="keydown_held" and actor.source_frame>=int(branch.from) and actor.source_frame<=int(branch.until) and tick%3==0:
						code=KEY_D if str(actor.state).begins_with("skill_d") else KEY_G
			elif actor.state=="skill_q":held="skill_q"
			elif actor.state=="skill_w" and actor.source_frame<54:held="skill_w"
			elif actor.state=="skill_f" and actor.source_frame<10:held="load_f"
		_tick(battle,code,move,held)
		states[actor.state]=int(states.get(actor.state,0))+1
		count+=1
		for enemy: Node2D in battle.enemies:
			if enemy.hp<float(initial_hp[enemy.identifier]):saw_contact_damage=true
		if tick%50==0:samples.append({"tick":tick,"hp":actor.hp,"mp":actor.mp,"position":actor.position,"action":actor.state,"frame":actor.source_frame,"enemies":battle.enemies.map(func(e:Node2D)->Dictionary:return {"id":e.identifier,"hp":e.hp,"state":e.state,"position":e.position})})
	var victory: bool=battle.ended and app.session.run.outcome=="victory" and battle.player.hp>0 and battle.enemies.all(func(e:Node2D)->bool:return e.hp<=0)
	combat_runs.append({"stage":stage_id,"seed":20261117+int(stage_id.trim_prefix("root_")),"ticks":count,"victory":victory,"hp":battle.player.hp,"outcome":app.session.run.get("outcome"),"states":states,"samples":samples,"initial_enemy_hp":initial_hp,"fixture":"No combat state seeded; real input, source AI and collision only"})
	_check("CRT3 real input causes contact damage "+stage_id,saw_contact_damage)
	_check("CRT3 actual combat defeats all enemies "+stage_id,victory,combat_runs[-1])
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
	_check("CRT3 original warehouse page5 is real",app.screen==expected_screen and app.storage_page==5 and _warehouse_is_real("crt_3"),menu.errors.duplicate())
	await _click(menu.buttons.get("warehouse_crt3_rings",menu.buttons.get("warehouse_rings")))
	_check("CRT3 warehouse rings page8",app.storage_page==8 and menu.current_page==8)
	await _click(menu.buttons.get("warehouse_weapons"))
	_check("rings weapons returns current CRT3 page5",app.storage_page==5 and _warehouse_is_real("crt_3"),menu.errors.duplicate())
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
	_check("isolated save restores actual four clears and CRT3 selection",saved.ok and saved.profile.selection.character_id=="crt_3" and ["root_2","root_4","root_6","root_9"].all(func(id:String)->bool:return int(saved.profile.progress.clears.get(id,0))==1) and saved.profile.progress.gold==app.session.profile.progress.gold,saved)
	await _click(_button("Menu"))
	_check("root10 Menu returns title without encounter residue",app.screen=="title" and not is_instance_valid(app.battle))

func _hud_matches(character: int, battle: Node2D) -> void:
	# Main automatic processing is disabled by this deterministic test. Pump
	# its production HUD update once, without advancing the battle clock.
	app._process(0.0)
	var hud: Node2D=app.ui.source_hud
	if not is_instance_valid(hud):
		_check("actual character HUD exists "+str(character),false);return
	var all_pages_correct:=true
	if all_pages_correct:
		for index in range(4):
			var page:=hud.get_node_or_null("Characters/CRT"+str(index))
			all_pages_correct=all_pages_correct and is_instance_valid(page) and page.visible==(index==character)
	_check("actual character HUD source page "+str(character),all_pages_correct and int(hud.geometry.panel.source_id)==4391 and int(hud.geometry.panel.source_frame)==character+1 and is_instance_valid(hud._panel.texture),hud.geometry.get("panel",{}))
	_check("HUD HP MP read actual encounter "+str(character),is_equal_approx(float(hud.state.hp),battle.player.hp) and is_equal_approx(float(hud.state.mp),battle.player.mp) and str(hud.state.character_id)=="crt_"+str(character),hud.state.get("character_id"))

func _locked_characters(context: String) -> void:
	# ACT06 registers CRT4; CRT5 remains outside the restored default set.
	for index in [5]:
		var button:=_button("Character_crt_"+str(index))
		_check(context+" character "+str(index)+" remains disabled",is_instance_valid(button) and button.disabled)

func _return_title() -> bool:
	if not await _click(_button("Pause")):return false
	_check("actual battle menu opens",app.screen=="game_menu")
	var menu: Control=app.ui.source_menu
	menu.set_process(false)
	for n in range(8):menu._process(0.04)
	if not await _click(menu.buttons.get("dropdown_actions")):return false
	if not await _click(menu.buttons.get("menu_return")):return false
	_check("native menu return disposes encounter",app.screen=="title" and not is_instance_valid(app.battle))
	return app.screen=="title"

func _ring_panel() -> bool:
	if not await _click(_button("TrainingStorage")):return false
	return await _click(app.ui.source_menu.buttons.get("warehouse_crt3_rings"))

func _training_storage_failure() -> void:
	_fresh_profile("training_lifecycle")
	await process_frame
	if not await _click(_button("Training")):return
	_locked_characters("training selection")
	if not await _click(_button("Character_crt_3")):return
	if not is_instance_valid(app.battle):
		_check("CRT3 normal training creates encounter",false,app.screen);return
	var battle:=_manual_battle()
	_check("normal training entry CRT3 without action lab",app.screen=="battle" and app.selected_stage=="root_41" and battle.is_training() and battle.player.definition.source_crt==3 and not app.action_lab)
	_check("training initial HP MP follow source root41",is_equal_approx(battle.player.hp,130.0) and is_equal_approx(battle.player.mp,130.0),battle.snapshot())
	_hud_matches(3,battle)
	if not await _click(_button("TrainingRestore")):return
	_check("native restore immediately applies 200 HP MP and bar7",is_equal_approx(battle.player.hp,200.0) and is_equal_approx(battle.player.mp,200.0) and battle.skill_bar_frame==7,battle.snapshot())
	for n in range(3):_tick(battle)
	_check("restore bar reinitializes without encounter replacement",app.battle==battle and battle.skill_bar_frame==1 and not battle.bar_initialization_pending and battle.player.state=="idle",battle.snapshot())
	_hud_matches(3,battle)
	app.session.profile.inventory.haring=1 # Explicit already-owned item fixture, not a shop claim.
	if not await _click(_button("TrainingStorage")):return
	await _storage_roundtrip("training_storage")
	_check("training warehouse returns same live encounter",app.screen=="battle" and app.battle==battle and not battle.paused)
	if not await _ring_panel():return
	if not await _click(app.ui.source_menu.buttons.get("ring_owned")):return
	if not await _click(app.ui.source_menu.buttons.get("ring_equip_crt3")):return
	_check("native ring equip saves CRT3 isolated profile",app.session.profile.equipment.rings.crt_3==1 and app.saves.load_profile().profile.equipment.rings.crt_3==1)
	if not await _click(app.ui.source_menu.buttons.get("ring_unequip_crt_3")):return
	_check("native ring unequip returns inventory and saves",app.session.profile.equipment.rings.crt_3==0 and app.session.profile.inventory.haring==1 and app.saves.load_profile().profile.equipment.rings.crt_3==0)
	if not await _click(app.ui.source_menu.buttons.get("ring_owned")):return
	if not await _click(app.ui.source_menu.buttons.get("ring_equip_crt3")):return
	if not await _click(app.ui.source_menu.buttons.get("warehouse_close")):return
	var gold: int=app.session.profile.progress.gold
	# Public damage API is used ONLY to enter the failure screen, never to win.
	battle.deal_damage(battle.player,battle.player,battle.player.hp,"explicit lifecycle fixture; not enemy combat evidence",false)
	_tick(battle)
	_check("explicit lethal fixture opens actual failure panel",app.screen=="result" and app.session.run.outcome=="defeat" and app.ui.source_menu.buttons.has("failure_retry"))
	if not await _click(app.ui.source_menu.buttons.get("failure_retry")):return
	if not is_instance_valid(app.battle):
		_check("failure retry creates encounter",false,app.screen);return
	var retry:=_manual_battle()
	_check("failure retry creates fresh CRT3 training with saved ring",retry!=battle and retry.is_training() and retry.player.definition.source_crt==3 and is_equal_approx(retry.player.hp,140.0) and is_equal_approx(retry.player.mp,130.0) and app.session.profile.progress.gold==gold)
	_check("failure retry resets CRT3 independent state",not bool(retry.crt3.e_active) and int(retry.crt3.over)==0 and int(retry.crt3.e_slot_frame)<442 and retry._crt3_objects.is_empty() and retry.zab.is_empty(),retry.crt3.duplicate(true))
	if not await _ring_panel():return
	if not await _click(app.ui.source_menu.buttons.get("ring_unequip_crt_3")):return
	if not await _click(app.ui.source_menu.buttons.get("warehouse_close")):return
	if not await _return_title():return
	if not await _click(_button("Training")):return
	if not await _click(_button("Character_crt_3")):return
	var reentered:=_manual_battle()
	_check("unequipped normal reentry restores source base HP",reentered!=retry and reentered.player.definition.source_crt==3 and is_equal_approx(reentered.player.hp,130.0) and int(reentered.crt3.e_slot_frame)<442 and app.session.profile.equipment.rings.crt_3==0)
	await _return_title()

func _existing_characters() -> void:
	for character in range(3):
		_fresh_profile("existing_crt"+str(character))
		await process_frame
		if not await _click(_button("Start")):return
		_locked_characters("adventure selection CRT"+str(character))
		var button:=_button("Character_crt_"+str(character))
		_check("existing adventure character remains enabled "+str(character),is_instance_valid(button) and not button.disabled)
		if not await _click(_button("Back")):return
		if not await _click(_button("Training")):return
		if not await _click(_button("Character_crt_"+str(character))):return
		if not is_instance_valid(app.battle):
			_check("existing training encounter "+str(character),false,app.screen);return
		var battle:=_manual_battle()
		_check("existing training selection preserved "+str(character),battle.is_training() and int(battle.player.definition.source_crt)==character and not app.action_lab)
		_hud_matches(character,battle)
		if not await _click(_button("TrainingStorage")):return
		_check("existing original warehouse page "+str(character+2),app.storage_page==character+2 and _warehouse_is_real("crt_"+str(character)),app.ui.source_menu.errors.duplicate())
		if not await _click(app.ui.source_menu.buttons.get("warehouse_close")):return
		_check("existing storage closes to same encounter "+str(character),app.battle==battle and app.screen=="battle" and not battle.paused)
		if not await _return_title():return

func _author_snapshot(folder: String) -> void:
	for filename: String in DirAccess.get_files_at(folder):
		if filename.ends_with(".tres") or filename.ends_with(".tscn"):
			var path:=folder.path_join(filename)
			author_hashes[path]=FileAccess.get_sha256(path)
	for child: String in DirAccess.get_directories_at(folder):_author_snapshot(folder.path_join(child))

func _run() -> void:
	if "--test-mode" not in OS.get_cmdline_user_args():push_error("Requires isolated --test-mode");quit(2);return
	formal_exists=FileAccess.file_exists("user://profile.json")
	if formal_exists:formal_hash=FileAccess.get_sha256("user://profile.json")
	_author_snapshot("res://content")
	_author_snapshot("res://scenes")
	viewport=SubViewport.new();viewport.size=Vector2i(550,400);viewport.disable_3d=true;root.add_child(viewport)
	app=MainScene.instantiate();viewport.add_child(app);app.set_process(false)
	_check("Main starts actual CRT3 content",app.startup_ok and app.test_mode and app.database.characters.crt_3.enabled,app.database.issues)
	if app.startup_ok:
		await _adventure()
		await _training_storage_failure()
		await _existing_characters()
	_release()
	_check("formal profile bytes unchanged",FileAccess.file_exists("user://profile.json")==formal_exists and (not formal_exists or FileAccess.get_sha256("user://profile.json")==formal_hash))
	var author_ok:=true
	for path: String in author_hashes:author_ok=author_ok and FileAccess.get_sha256(path)==author_hashes[path]
	_check("runtime preserves all content and scene author bytes",author_ok)
	app._dispose_battle()
	var drained: bool=await app.audio.stop_and_drain(1.0)
	_check("audio references drain after all flows",drained)
	viewport.queue_free();await process_frame
	var failures: int=checks.filter(func(row:Dictionary)->bool:return not row.passed).size()
	var path:=OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if path.is_empty():path="res://artifacts/leba_act05_20261117/flow/run_%d_%d"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	var file:=FileAccess.open(path.path_join("act05_flow.json"),FileAccess.WRITE)
	if file==null:
		push_error("Cannot save ACT05 flow report: "+path);quit(2);return
	if file!=null:
		file.store_string(JSON.stringify({"suite":"ACT05 CRT3 normal flow and actual input combat","checks":checks,"failures":failures,"combat_runs":combat_runs,"godot":Engine.get_version_info(),"isolated_profiles":isolated_profiles,"author_files":author_hashes.size(),"fixtures":["isolated default profiles; formal user://profile.json protected","pre-owned ring item only for equip/unequip lifecycle","public lethal-damage call only for separate failure lifecycle","manual 25Hz clock with formal InputEventKey and native SubViewport mouse routing"],"not_tested":["native OS keyboard dispatch","original CRT3 per-tick dynamic oracle","audible listening","GPU visual review","unimplemented root12/endings"]},"\t")+"\n");file.close()
	print("ACT05_FLOW_RESULT ",JSON.stringify({"checks":checks.size(),"failures":failures,"report":path}))
	quit(0 if failures==0 else 1)
