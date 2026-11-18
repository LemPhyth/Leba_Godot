extends SceneTree
## T5 evidence generator. Real Main training, InputMap held state, key events,
## take_commands and source25Hz step. GL + Dummy only; never an ear/OS verdict.
const MainScene = preload("res://scenes/main.tscn")
const Visual = preload("res://scripts/combat/source_sprite.gd")
const RULES := "res://data/act04_crt2_rules.json"
const KEYS := {KEY_LEFT:"move_left",KEY_RIGHT:"move_right",KEY_X:"attack",KEY_D:"skill",KEY_S:"skill_s",KEY_C:"jump",KEY_DOWN:"down",KEY_Z:"skill_z",KEY_A:"skill_a",KEY_W:"skill_w",KEY_F:"load_f",KEY_G:"load_g",KEY_H:"load_h",KEY_Q:"skill_q",KEY_E:"skill_e",KEY_R:"skill_r",KEY_V:"skill_v"}
var app: Node
var output := ""
var rules: Dictionary = {}
var catalog: Dictionary = {}
var texture_keys: Dictionary = {}
var images: Array[Dictionary] = []
var sounds: Array[Dictionary] = []
var cases: Array[Dictionary] = []
var checks: Array[Dictionary] = []
var current_case := "startup"
var current_facing := 1
var author_hashes: Dictionary = {}
var runtime_hashes: Dictionary = {}
var formal_exists := false
var formal_hash := ""

func _initialize() -> void:call_deferred("_run")

func _check(okay: bool, label: String, detail: Variant = "") -> bool:
	checks.append({"case":current_case,"passed":okay,"label":label,"detail":detail})
	print(("PASS " if okay else "FAIL ")+label)
	return okay

func _authors() -> Dictionary:
	var result := {}
	for folder: String in ["res://content/actions/crt2","res://content/components/crt2"]:
		for file: String in DirAccess.get_files_at(folder):
			var path := folder.path_join(file)
			result[path] = FileAccess.get_sha256(path)
	for path: String in ["res://content/characters/crt_2.tres","res://scenes/actors/crt2.tscn"]:result[path]=FileAccess.get_sha256(path)
	return result

func _runtime() -> Dictionary:
	var result := {}
	for path: String in ["res://scripts/main.gd","res://scripts/combat/battle.gd","res://scripts/combat/combatant.gd","res://scripts/combat/source_sprite.gd","res://scripts/services/audio_director.gd","res://data/asset_catalog.json",RULES,"res://tests/render_act04_crt2.gd"]:
		result[path]=FileAccess.get_sha256(path)
	return result

func _release() -> void:
	for action: String in KEYS.values():Input.action_release(action)

func _press(battle: Node2D, key: int, echo := false) -> void:
	Input.action_press(KEYS[key])
	var event := InputEventKey.new()
	event.keycode=key;event.physical_keycode=key;event.pressed=true;event.echo=echo
	battle._unhandled_input(event)
	_tick(battle)

func _up(battle: Node2D, key: int) -> void:
	Input.action_release(KEYS[key])
	var event := InputEventKey.new()
	event.keycode=key;event.physical_keycode=key;event.pressed=false
	battle._unhandled_input(event)

func _tap(battle: Node2D, key: int, echo := false) -> void:
	_press(battle,key,echo)
	_up(battle,key)

func _tick(battle: Node2D, count := 1) -> void:
	for index in range(count):battle.step(battle.take_commands())

func _fresh(label: String, facing: int, topics: Array, ready_ticks := 2) -> Node2D:
	_release()
	current_case=("right_" if facing==1 else "left_")+label
	current_facing=facing
	app.session.profile=app.saves.default_profile()
	app._on_intent("training",null)
	var selector: BaseButton=app.ui.get_button("Character_crt_2")
	if not _check(selector!=null,"normal training offers Character_crt_2"):return null
	selector.pressed.emit()
	var battle: Node2D=app.battle
	battle.manual_clock=true
	battle.set_physics_process(false)
	# One-time spatial fixture only. No frame/state/charge/grab outcome is seeded.
	battle.player.position.x=275.0
	for enemy: Node2D in battle.enemies:enemy.position=Vector2(520,-1000)
	_tick(battle,ready_ticks)
	Input.action_press("move_right" if facing==1 else "move_left")
	_tick(battle)
	_release()
	_tick(battle)
	_idle(battle,20)
	_check(app.screen=="battle" and battle.player.definition.source_crt==2 and battle.player.state=="idle" and battle.player.facing==facing,"real training CRT2 starts facing "+str(facing),_state(battle))
	cases.append({"id":current_case,"topics":topics,"facing":facing,"input":"InputMap held + InputEventKey + take_commands/step","initial_fixture":"Player x275 once; noncontact enemies(520,-1000) once; ordinary AI/physics remain enabled; direction through held movement","sound_start":sounds.size(),"image_start":images.size(),"entry_tick":app.session.run.source_ticks,"manual_visual_review":"pending","listening":"未试听"})
	return battle

func _state(battle: Node2D) -> Dictionary:
	return {"stage":app.session.run.stage_id,"tick":app.session.run.source_ticks,"action":battle.player.state,"parent_frame":battle.player.parent_frame,"source_frame":battle.player.source_frame,"air_action_frame":battle.player.air_action_frame,"body_frame":battle.player.body_frame,"position":[battle.player.position.x,battle.player.position.y],"facing":battle.player.facing,"hp":battle.player.hp,"mp":battle.player.mp,"cubes":app.session.profile.progress.clear_cubes,"ended":battle.ended}

func _matrix(value: Transform2D) -> Array:
	return [value.x.x,value.x.y,value.y.x,value.y.y,value.origin.x,value.origin.y]

func _views(node: Node) -> Array:
	var result := []
	if node.get_script()==Visual:result.append(node)
	for child: Node in node.get_children():result.append_array(_views(child))
	return result

func _ink(view: Node2D) -> bool:
	if not view.is_visible_in_tree() or view.modulate.a<=0:return false
	var bounds: Array=view.frame.get("alpha_bounds",[])
	return bounds.is_empty() or (float(bounds[2])>0 and float(bounds[3])>0)

func _visible_animation(battle: Node2D, key: String) -> bool:
	if not catalog.animations.has(key):return false
	var texture: String=catalog.animations[key].texture
	return _views(battle).any(func(view: Node2D)->bool:return str(view.definition.get("texture",""))==texture and _ink(view))

func _visual_rows(battle: Node2D) -> Array:
	var result := []
	for view: Node2D in _views(battle):
		if not view.is_visible_in_tree():continue
		var path: String=view.definition.get("texture","")
		var keys: Array=texture_keys.get(path,[])
		var source := []
		for key: String in keys:
			var row: Dictionary=catalog.animations[key]
			source.append({"animation":key,"source_id":row.get("source_sprite_id",0),"source_parent":row.get("source_parent_id",0),"render_profile":row.get("render_profile",""),"source_png_sha256":row.get("rendered_frames_sha256",{}).get(str(view.source_frame),"")})
		result.append({"node":str(battle.get_path_to(view)),"texture":path,"texture_sha256":FileAccess.get_sha256(path) if not path.is_empty() else "","source_frame":view.source_frame,"source":source,"has_ink":_ink(view),"global_matrix":_matrix(view.global_transform),"alpha":view.modulate.a,"z_index":view.z_index,"z_relative":view.z_as_relative,"atlas_frame":view.frame.duplicate(true)})
	return result

func _capture(battle: Node2D, phase: String) -> void:
	app.ui.update_hud(battle.snapshot(),false)
	await process_frame
	RenderingServer.force_draw(false)
	var bitmap:=root.get_texture().get_image()
	var path:=output.path_join(current_case+"_"+phase+".png")
	if not _check(bitmap!=null and not bitmap.is_empty(),"GL framebuffer "+phase):return
	if not _check(bitmap.save_png(path)==OK,"saved "+path.get_file()):return
	images.append({"case":current_case,"phase":phase,"path":path,"sha256":FileAccess.get_sha256(path),"dimensions":[bitmap.get_width(),bitmap.get_height()],"state":_state(battle),"visuals":_visual_rows(battle),"manual_visual_review":"pending","listening":"未试听"})

func _until_action(battle: Node2D, action: String, frame: int, cap := 180) -> bool:
	for index in range(cap+1):
		if battle.player.state==action and battle.player.source_frame==frame:return true
		if battle.ended and action!="dead":break
		if index<cap:_tick(battle)
	return _check(false,"reached "+action+" source"+str(frame),_state(battle))

func _capture_action(battle: Node2D, action: String, frame: int, phase := "") -> bool:
	if not _until_action(battle,action,frame):return false
	await _capture(battle,phase if not phase.is_empty() else action+"_%03d"%frame)
	return true

func _idle(battle: Node2D, cap := 220) -> bool:
	for index in range(cap+1):
		if battle.player.state=="idle":return true
		if battle.ended:break
		if index<cap:_tick(battle)
	return _check(false,"returns to normal idle",_state(battle))

func _frenzy(battle: Node2D) -> bool:
	_tap(battle,KEY_H)
	if not _idle(battle,55):return false
	return _check(_visible_animation(battle,"crt2_h_aura"),"H enables visible source4599 aura",_state(battle))

func _contact(battle: Node2D) -> void:
	var target: Node2D=battle.enemies[0]
	target.position=battle.player.position+Vector2(25*current_facing,36)
	target.hp=2000.0
	cases.back().contact_fixture="One-time enemy at actor+(25*facing,36), HP2000; normal AI, geometry and reaction; never seed grab/marker"

func _walk(battle: Node2D, targets: Array, animations: Array, ticks: int) -> void:
	var pending_targets: Array=targets.duplicate(true)
	var pending_animations: Array=animations.duplicate()
	for index in range(ticks+1):
		for target: Array in pending_targets.duplicate():
			if battle.player.state==str(target[0]) and battle.player.source_frame==int(target[1]):
				await _capture(battle,str(target[0])+"_%03d"%int(target[1]));pending_targets.erase(target)
		for key: String in pending_animations.duplicate():
			if _visible_animation(battle,key):
				await _capture(battle,key);pending_animations.erase(key)
		if index<ticks:_tick(battle)
	_check(pending_targets.is_empty() and pending_animations.is_empty(),"selected main/independent effects occurred",{"unseen_main":pending_targets,"unseen_effects":pending_animations,"terminal":_state(battle)})

func _finish_case(battle: Node2D, settle_ticks := 0) -> void:
	_release()
	_idle(battle)
	_tick(battle,settle_ticks)
	cases.back().terminal=_state(battle)
	cases.back().sound_end=sounds.size()
	cases.back().image_end=images.size()

func _base_and_combo(facing: int) -> void:
	var battle:=_fresh("ordinary",facing,["idle","move","basic","basic2","basic3","down","skill_z"])
	if battle==null:return
	await _capture(battle,"idle")
	Input.action_press("move_right" if facing==1 else "move_left")
	_tick(battle,11)
	await _capture(battle,"move")
	_release();_tick(battle)
	_tap(battle,KEY_X)
	await _capture_action(battle,"basic",6)
	if _until_action(battle,"basic",9):_tap(battle,KEY_X,true)
	await _capture_action(battle,"basic2",6)
	if _until_action(battle,"basic2",9):_tap(battle,KEY_X,true)
	await _capture_action(battle,"basic3",7)
	_idle(battle)
	_tap(battle,KEY_DOWN)
	await _capture_action(battle,"down",5)
	_idle(battle)
	_tap(battle,KEY_Z)
	await _capture_action(battle,"skill_z",7)
	_finish_case(battle)
	await _sword_contacts(facing)

func _sword_contacts(facing: int) -> void:
	var phases: Array=[["basic",6,"left" if facing==1 else "right"],["basic2",6,"horizontal"],["basic3",7,"right" if facing==1 else "left"]]
	for spec: Array in phases:
		var battle:=_fresh("x_source_sword_"+str(spec[0]),facing,[spec[0]])
		if battle==null:continue
		_tap(battle,KEY_X)
		if spec[0] in ["basic2","basic3"] and _until_action(battle,"basic",9):_tap(battle,KEY_X,true)
		if spec[0]=="basic3" and _until_action(battle,"basic2",9):_tap(battle,KEY_X,true)
		if not _until_action(battle,str(spec[0]),int(spec[1])-1):break
		_contact(battle)
		_check(not battle.enemies[0].airborne,"contact fixture retains original ground action-body before "+str(spec[0]))
		var sound_start:=sounds.size()
		_tick(battle)
		_check(_visible_animation(battle,"crt2_hit_slash_"+str(spec[2])),"original named helper creates "+str(spec[2])+" sword feedback",_state(battle))
		_check(sounds.slice(sound_start).any(func(row: Dictionary)->bool:return row.alias=="crt2_hit_slash_sound6" and row.valid_playback and row.registered_alias_stream),"new original sword feedback consumes Sound6")
		await _capture(battle,str(spec[0])+"_contact")
		cases.back().contact_fixture="Fresh encounter for each source named-helper window. Earlier X segments intentionally miss; place the still-ground enemy once before the selected source event (6/6/7). No per-tick replay, forced action, forced slash or injected damage. Geometry fixture, not uninterrupted natural combat."
		_finish_case(battle,15)
		await _capture(battle,"finished")

func _a_and_s(facing: int) -> void:
	for follow in [false,true]:
		var battle:=_fresh("a_follow" if follow else "a_normal",facing,["skill_a"])
		if battle==null:continue
		_tap(battle,KEY_A)
		await _capture_action(battle,"skill_a",14)
		if follow and _until_action(battle,"skill_a",16):
			_tap(battle,KEY_Z)
			await _capture_action(battle,"skill_a",34)
		_finish_case(battle)
	for full in [false,true]:
		var next_action: String="skill_s_full" if full else "skill_s_release"
		var battle:=_fresh("s_full" if full else "s_short",facing,["skill_s_start",next_action])
		if battle==null:continue
		_press(battle,KEY_S)
		await _capture_action(battle,"skill_s_start",4)
		if full:_until_action(battle,"skill_s_start",6)
		_up(battle,KEY_S)
		_tick(battle)
		await _capture_action(battle,next_action,10 if full else 7)
		_finish_case(battle)

func _grabs(facing: int) -> void:
	for spec: Array in [[KEY_D,"skill_d",16,28],[KEY_V,"skill_v",17,32]]:
		for hit in [false,true]:
			var battle:=_fresh(str(spec[1])+("_contact" if hit else "_miss"),facing,[spec[1]])
			if battle==null:continue
			if hit:_contact(battle)
			_tap(battle,int(spec[0]))
			if hit:
				await _walk(battle,[[spec[1],spec[2]],[spec[1],spec[3]]],[],105)
				if spec[1]=="skill_d":
					_check(not images.slice(int(cases.back().image_start)).any(func(row: Dictionary)->bool:return row.visuals.any(func(view: Dictionary)->bool:return view.has_ink and str(view.texture)==str(catalog.animations.crt2_d_blood.texture))),"ordinary D does not invent a bleed-dependent blood effect")
					_check(_visible_animation(battle,"crt2_lust_timer"),"D shows independent lust status")
					await _capture(battle,"lust_active")
			else:await _capture_action(battle,str(spec[1]),9)
			_finish_case(battle,30)
			await _capture(battle,"finished")
	await _bleeding_grab(facing)

func _bleeding_grab(facing: int) -> void:
	var battle:=_fresh("a_bleed_then_d",facing,["skill_a","skill_d"])
	if battle==null:return
	_tap(battle,KEY_A)
	if _until_action(battle,"skill_a",21):
		# The source A22 status window is used, rather than setting any status.
		# This one-time placement isolates that real window from A14's launch.
		_contact(battle)
		battle.enemies[0].position=battle.player.position+Vector2(40*facing,36)
		_tick(battle,3)
		_check(_visible_animation(battle,"enemy_bleed"),"actual A22-24 contact creates original bleed visual",_state(battle))
		await _capture(battle,"a_status_contact")
	_idle(battle)
	# Retain the status and actor; only arrange a second, explicit contact scene.
	_contact(battle)
	cases.back().contact_fixture="Two documented spatial fixtures: enemy+(40*facing,36) just before A22 status; same actor +(25*facing,36) before D. Real input, status observer, AI and hit geometry; no seeded bleed/grab."
	_tap(battle,KEY_D)
	await _walk(battle,[["skill_d",16],["skill_d",28]],["crt2_d_blood"],105)
	_finish_case(battle,15)
	await _capture(battle,"finished")

func _air(facing: int) -> void:
	var battle:=_fresh("air_x",facing,["jump","air_x"])
	if battle==null:return
	_tap(battle,KEY_C)
	await _capture_action(battle,"jump",4)
	Input.action_press("attack")
	await _walk(battle,[["jump",14]],["crt2_jump_attack_right"],20)
	_finish_case(battle)
	await _capture(battle,"landed")
	for trigger in [4,10]:
		battle=_fresh("air_z_%02d"%trigger,facing,["jump","jump_z"])
		if battle==null:continue
		_tap(battle,KEY_C)
		if _until_action(battle,"jump",trigger):_press(battle,KEY_Z)
		await _walk(battle,[["jump_z",63],["jump_z",66]],["crt2_air_z_right" if facing==1 else "crt2_air_z_left"],25)
		_up(battle,KEY_Z)
		_finish_case(battle,8)
		await _capture(battle,"landed")

func _f_and_g(facing: int) -> void:
	var battle:=_fresh("f_objects",facing,["skill_f"])
	if battle==null:return
	_tap(battle,KEY_F)
	await _walk(battle,[["skill_f",8]],["crt2_f_charge","crt2_f_charge_core","crt2_f_burst"],65)
	_finish_case(battle,10)
	await _capture(battle,"finished")
	battle=_fresh("g_status",facing,["skill_g"])
	if battle==null:return
	_tap(battle,KEY_G)
	await _walk(battle,[["skill_g",7]],["crt2_g_timer"],30)
	_finish_case(battle,410)
	await _capture(battle,"expired")

func _h_and_pren_combo(facing: int) -> void:
	var battle:=_fresh("h_pren_chain",facing,["skill_h","pren_basic1","pren_basic2","pren_basic3","pren_basic4","skill_h_close"])
	if battle==null:return
	_tap(battle,KEY_H)
	await _capture_action(battle,"skill_h",12)
	_idle(battle)
	await _capture(battle,"pren_idle")
	_tap(battle,KEY_X)
	await _capture_action(battle,"pren_basic1",7)
	if _until_action(battle,"pren_basic1",12):_press(battle,KEY_X,true)
	await _capture_action(battle,"pren_basic2",7)
	await _capture_action(battle,"pren_basic3",7)
	await _capture_action(battle,"pren_basic4",8)
	_up(battle,KEY_X)
	_idle(battle)
	_tick(battle,280)
	_tap(battle,KEY_H)
	await _capture_action(battle,"skill_h_close",95)
	_finish_case(battle)
	await _capture(battle,"pren_closed")
	battle=_fresh("g_pren_loop",facing,["skill_h","skill_g","pren_basic1","pren_basic2"])
	if battle==null:return
	if _frenzy(battle):
		_tap(battle,KEY_G);_idle(battle)
		_tap(battle,KEY_X)
		if _until_action(battle,"pren_basic1",12):_press(battle,KEY_X,true)
		await _capture_action(battle,"pren_basic2",7)
		await _capture_action(battle,"pren_basic1",7,"g_returns_first")
	_finish_case(battle)

func _w_e_q(facing: int) -> void:
	var battle:=_fresh("w_held",facing,["skill_w"])
	if battle==null:return
	if _frenzy(battle):
		_press(battle,KEY_W)
		await _capture_action(battle,"skill_w",13)
		await _capture_action(battle,"skill_w",50)
		_up(battle,KEY_W)
		_tick(battle)
		await _capture_action(battle,"skill_w",119)
	_finish_case(battle,25)
	await _capture(battle,"released")
	battle=_fresh("e_quake",facing,["skill_e"])
	if battle==null:return
	if _frenzy(battle):
		_tap(battle,KEY_E)
		await _walk(battle,[["skill_e",35],["skill_e",51],["skill_e",75]],["crt2_e_right" if facing==1 else "crt2_e_left","crt2_e_charge"],110)
	_finish_case(battle,20)
	await _capture(battle,"finished")
	battle=_fresh("q_dust",facing,["skill_q"])
	if battle==null:return
	if _frenzy(battle):
		_tap(battle,KEY_Q)
		await _walk(battle,[["skill_q",18],["skill_q",43]],["crt2_q_dust_right" if facing==1 else "crt2_q_dust_left"],70)
	_finish_case(battle,15)
	await _capture(battle,"finished")

func _r(facing: int) -> void:
	var battle:=_fresh("r_full",facing,["skill_r"],450)
	if battle==null:return
	_tap(battle,KEY_R)
	await _walk(battle,[["skill_r",25],["skill_r",54],["skill_r",131]],["hud_crt2_r_cutin","crt2_r_air"],170)
	_finish_case(battle,15)
	await _capture(battle,"finished")

func _reactions(facing: int) -> void:
	await _enemy_knockdown(facing)
	var fallen:=_fresh("fallen_author_preview",facing,["fallen"])
	if fallen!=null:
		fallen.player.set_action("fallen")
		cases.back().reaction_fixture="Explicit source93 authored controlled preview via actual Actor.set_action(fallen). Current roots have no verified natural fallen trigger; this is not an enemy/keyboard acceptance."
		await _capture(fallen,"source93_child1")
		_tick(fallen,10)
		_check(fallen.player.state=="fallen" and fallen.player.source_frame==1,"source5624 frame1 stop remains held",_state(fallen))
		await _capture(fallen,"source93_hold")
		cases.back().terminal=_state(fallen)
		cases.back().sound_end=sounds.size();cases.back().image_end=images.size()
	var battle:=_fresh("hurt_z",facing,["hit","hurt_z","skill_s_release"])
	if battle==null:return
	battle.player.receive_damage(1.0)
	cases.back().reaction_fixture="Public receive_damage(1), ordinary reaction chain; no source damage claim"
	await _capture_action(battle,"hit",2)
	_tap(battle,KEY_Z)
	await _capture(battle,"hurt_z_entry")
	await _capture_action(battle,"skill_s_release",7)
	_finish_case(battle)
	battle=_fresh("death",facing,["dead"])
	if battle==null:return
	battle.player.receive_damage(1000.0)
	cases.back().reaction_fixture="Public lethal receive_damage(1000); not an enemy contact/source damage oracle"
	await _capture_action(battle,"dead",2)
	_tick(battle,27)
	await _capture(battle,"dead_hold")
	cases.back().terminal=_state(battle)
	cases.back().sound_end=sounds.size();cases.back().image_end=images.size()

func _enemy_knockdown(facing: int) -> void:
	var training:=_fresh("root9_enemy_knockdown",facing,["knockdown"])
	if training==null:return
	app.session.select_mode("story")
	app.enter_battle("root_9")
	var battle: Node2D=app.battle
	battle.manual_clock=true;battle.set_physics_process(false)
	battle.player.position.x=275
	for enemy: Node2D in battle.enemies:enemy.position.x=275+facing*35
	Input.action_press("move_right" if facing==1 else "move_left")
	_tick(battle);_release()
	cases.back().reaction_fixture="Production Main.enter_battle(root_9), original7437 AI/attack/geometry. One-time x placement player275/enemy275+35*facing; no forced attack, damage, reaction or source frame. Not a natural full-stage playthrough."
	var trace: Array=[]
	var hit:=false
	for index in range(420):
		trace.append({"player":_state(battle),"enemies":battle.enemies.map(func(enemy: Node2D)->Dictionary:return {"state":enemy.state,"frame":enemy.source_frame,"position":[enemy.position.x,enemy.position.y]})})
		if battle.player.state=="knockdown":hit=true;break
		if battle.ended:break
		_tick(battle)
	_check(hit,"actual root9 enemy AI enters CRT2 knockdown",trace)
	if hit:
		await _capture(battle,"actual_contact")
		await _capture_action(battle,"knockdown",10)
		await _capture_action(battle,"knockdown",28)
		_idle(battle,60)
		await _capture(battle,"recovered")
	cases.back().reaction_trace=trace
	cases.back().terminal=_state(battle)
	cases.back().sound_end=sounds.size();cases.back().image_end=images.size()

func _on_sound(alias: String, stream: AudioStream, offset: float, voice: AudioStreamPlayer) -> void:
	var battle: Node2D=app.battle if is_instance_valid(app.battle) else null
	var source: Dictionary=catalog.audio_events.get(alias,{})
	var actual_state: String=battle.player.state if battle!=null else ""
	var path: String=stream.resource_path if not stream.resource_path.is_empty() else str(catalog.audio.sfx.get(alias,""))
	var source_id: int=int(source.get("sprite_id",0))
	if alias.is_empty() and battle!=null:
		# Empty alias is the authored main-action path. Do not attribute enemy
		# main sounds to the player merely because the player exists.
		var main_id: int=int(battle.player.definition.actions.get(actual_state,{}).get("source_id",0))
		var main_audio: Array=rules.actions.get(actual_state,{}).get("source_audio",[])
		if main_audio.any(func(row: Dictionary)->bool:return int(row.source_frame)==battle.player.source_frame and int(row.sound_id)==path.get_file().get_basename().to_int()):source_id=main_id
		if actual_state=="jump" and rules.actions.air_x.source_audio.any(func(row: Dictionary)->bool:return int(row.source_frame)==battle.player.air_action_frame and int(row.sound_id)==path.get_file().get_basename().to_int()):
			# Independent5416 uses the authored action-event dispatcher. Its
			# public child clock, not parent5649.source_frame, identifies it.
			source_id=int(rules.actions.air_x.source_id)
			source={"frame":battle.player.air_action_frame,"sound_id":path.get_file().get_basename().to_int()}
	var registered: bool=not alias.is_empty() and app.audio._streams.get("sfx/"+alias)==stream
	var authored: bool=not path.is_empty() and ResourceLoader.exists(path) and load(path)==stream and (alias.is_empty() or str(catalog.audio.sfx.get(alias,""))==path)
	sounds.append({"case":current_case,"facing":current_facing,"alias":alias,"source_id":source_id,"declared_source_frame":int(source.get("frame",battle.player.source_frame if battle!=null else -1)),"sound_id":int(source.get("sound_id",path.get_file().get_basename().to_int())),"path":path,"stream_id":stream.get_instance_id(),"offset":offset,"length":stream.get_length(),"valid_playback":is_instance_valid(voice) and voice.stream==stream and voice.playing and voice.has_stream_playback(),"registered_alias_stream":registered or authored,"stream_route":"registry_duplicate" if registered else "authored_resource" if authored else "unresolved","state":actual_state,"parent_frame":battle.player.source_frame if battle!=null else -1,"tick":app.session.run.source_ticks if battle!=null else -1})

func _offset(xml: String) -> float:
	var expression:=RegEx.new()
	expression.compile('inPoint="([0-9]+)"')
	var found:=expression.search(xml)
	return float(found.get_string(1))/44100.0 if found!=null else 0.0

func _audio_matrix() -> Array:
	var result := []
	for source: Dictionary in rules.recursive_sound_candidates.rows:
		var grouped := {}
		for event: Dictionary in source.sounds:
			var signature: String="%d/%d/%.10f"%[int(event.source_frame),int(event.sound_id),_offset(event.sound_info_xml)]
			if not grouped.has(signature):grouped[signature]={"source_id":int(source.source_id),"source_frame":int(event.source_frame),"sound_id":int(event.sound_id),"offset":_offset(event.sound_info_xml),"original_multiplicity":0,"source_sound_info_xml":event.sound_info_xml}
			grouped[signature].original_multiplicity+=1
		for expected: Dictionary in grouped.values():
			var by_facing := {}
			for facing in [1,-1]:
				var matches: Array=sounds.filter(func(row: Dictionary)->bool:return row.facing==facing and row.source_id==expected.source_id and row.declared_source_frame==expected.source_frame and row.sound_id==expected.sound_id and is_equal_approx(row.offset,expected.offset) and row.valid_playback and row.registered_alias_stream)
				var by_tick := {}
				for request: Dictionary in matches:
					var key: String=str(request["case"])+"/"+str(request.tick)
					by_tick[key]=int(by_tick.get(key,0))+1
				var maximum:=0
				for count: int in by_tick.values():maximum=maxi(maximum,count)
				by_facing[str(facing)]={"requests":matches.size(),"cases":matches.map(func(row: Dictionary):return row["case"]),"per_case_tick":by_tick,"max_same_tick_requests":maximum,"covered":maximum>=int(expected.original_multiplicity)}
			expected.actual_by_facing=by_facing
			expected.listening="未试听；只核对实际播放请求、流和偏移"
			expected.phase_boundary="Alias source frame is its catalog event provenance; request also records actual parent/tick. Exact child callback phases need separate source timing regression."
			result.append(expected)
	return result

func _action_matrix() -> Array:
	var result := []
	for id: String in rules.actions:
		var rule: Dictionary=rules.actions[id]
		var linked: Array=cases.filter(func(row: Dictionary)->bool:return id in row.topics)
		var evidence: Array=images.filter(func(row: Dictionary)->bool:return linked.any(func(item: Dictionary)->bool:return item.id==row["case"]))
		result.append({"action":id,"source_id":rule.source_id,"source_parent":rule.source_parent,"input":rule.get("physical_key",rule.input),"source":rule.get("source","res/scripts/DefineSprite_%d/"%int(rule.source_id)),"expected_main_audio":rule.get("source_audio",[]),"cases":linked.map(func(row: Dictionary):return row.id),"images":evidence.map(func(row: Dictionary):return row.path),"execution_status":"not_exercised" if linked.is_empty() else "author_controlled_preview_only" if id=="fallen" else "see_case_checks_and_captures","visual_review":"pending","listening":"未试听","remaining":"Current stages do not naturally trigger source93; explicit author preview only" if id=="fallen" else "Source static provenance does not certify exact original timing or subjective feel"})
	return result

func _run() -> void:
	output=OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if output.is_empty():output="res://artifacts/leba_act04_20261117/crt2/render_%d_%d"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	rules=JSON.parse_string(FileAccess.get_file_as_string(RULES))
	catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_catalog.json"))
	for key: String in catalog.animations:
		var path: String=catalog.animations[key].texture
		if not texture_keys.has(path):texture_keys[path]=[]
		texture_keys[path].append(key)
	author_hashes=_authors()
	runtime_hashes=_runtime()
	formal_exists=FileAccess.file_exists("user://profile.json")
	if formal_exists:formal_hash=FileAccess.get_sha256("user://profile.json")
	OS.set_environment("LEBA_TEST_MODE","1")
	OS.set_environment("LEBA_SILENT_TEST","1")
	OS.set_environment("LEBA_TEST_PROFILE","user://act04_crt2_render/%d_%d/profile.json"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()])
	root.size=Vector2i(550,400)
	app=MainScene.instantiate();root.add_child(app);app.set_process(false)
	if _check(app.startup_ok and app.test_mode and app.saves.path!="user://profile.json","isolated formal Main startup"):
		app.audio.sound_played.connect(_on_sound)
		for facing in [1,-1]:
			await _base_and_combo(facing)
			await _a_and_s(facing)
			await _grabs(facing)
			await _air(facing)
			await _f_and_g(facing)
			await _h_and_pren_combo(facing)
			await _w_e_q(facing)
			await _r(facing)
			await _reactions(facing)
	_release()
	if is_instance_valid(app.battle):app._dispose_battle()
	var drained: bool=await app.audio.stop_and_drain(1.0)
	_check(drained,"actual playback references drain")
	app.queue_free();await process_frame
	_check(_authors()==author_hashes,"CRT2 author Resources unchanged")
	_check(_runtime()==runtime_hashes,"rendered runtime/catalog snapshot unchanged during capture")
	_check(FileAccess.file_exists("user://profile.json")==formal_exists and (not formal_exists or FileAccess.get_sha256("user://profile.json")==formal_hash),"formal profile unchanged")
	_check(sounds.all(func(row: Dictionary)->bool:return row.valid_playback and row.registered_alias_stream and row.offset>=0 and row.offset<row.length),"observed audio requests use correct registered streams/playback")
	var audio_matrix:=_audio_matrix()
	for expected: Dictionary in audio_matrix:
		_check(expected.actual_by_facing["1"].covered and expected.actual_by_facing["-1"].covered,"source sound consumed both directions %s/%s:%s"%[expected.source_id,expected.source_frame,expected.sound_id],expected)
	var failures: int=checks.filter(func(row: Dictionary)->bool:return not row.passed).size()
	var report: Dictionary={"images":images,"cases":cases,"checks":checks,"failures":failures,"sound_requests":sounds,"action_matrix":_action_matrix(),"source_audio_matrix":audio_matrix,"author_hashes":author_hashes,"runtime_hashes":runtime_hashes,"rules_sha256":FileAccess.get_sha256(RULES),"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"godot":Engine.get_version_info(),"scope":"Actual GL Main/Battle source25Hz via normal training selection/InputMap held/key events; root9 original AI contact fixture. AudioDirector real play requests under Dummy. Explicit position/contact/resource and public damage fixtures. Source93 fallen alone uses labeled Actor.set_action author preview; no forced skill frame/state. No replacement gameplay executor or OS-keyboard/Flash dynamic/audible acceptance. Pixel review remains pending until images are inspected.","unexercised_reactions":["natural enemy trigger for fallen93"]}
	var file:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n");file.close()
	print("ACT04_CRT2_RENDER ",JSON.stringify({"images":images.size(),"cases":cases.size(),"failures":failures,"sounds":sounds.size(),"output":output}))
	quit(0 if failures==0 else 1)
