extends SceneTree
## ACT04 functional regression through real Main, normal training and real key
## events. Only the source25Hz clock is stepped manually. Initial HP/MP/cubes
## and enemy positions are explicit engineering fixtures, never source oracles.
## No action, pren, grab result, marker, cooldown, audio event or victory is seeded.
const MainScene = preload("res://scenes/main.tscn")
const Save = preload("res://scripts/services/save_store.gd")
const INPUTS := ["move_left","move_right","attack","skill","skill_s","jump","down","skill_z","skill_a","skill_w","load_f","load_g","load_h","skill_q","skill_t","skill_e","skill_r","skill_y","skill_v","aim_up"]
const KEY_ACTIONS := {KEY_X:"attack",KEY_D:"skill",KEY_S:"skill_s",KEY_C:"jump",KEY_DOWN:"down",KEY_Z:"skill_z",KEY_A:"skill_a",KEY_W:"skill_w",KEY_F:"load_f",KEY_G:"load_g",KEY_H:"load_h",KEY_Q:"skill_q",KEY_E:"skill_e",KEY_R:"skill_r",KEY_V:"skill_v",KEY_T:"skill_t",KEY_Y:"skill_y"}
const EXPECTED_ACTIONS := ["idle","move","basic","basic2","basic3","skill_z","down","hit","knockdown","skill_a","skill_s_start","skill_s_release","skill_s_full","skill_d","skill_g","skill_f","skill_h","pren_basic1","pren_basic2","pren_basic3","pren_basic4","skill_w","skill_e","skill_r","fallen","dead","jump","skill_v","skill_q","skill_h_close","hurt_z","jump_z","air_x"]
# key, action, parent, MP, HP, cubes, requires active frenzy
const ENTRIES := [[KEY_Z,"skill_z",72,2.0,0.0,0,false],[KEY_A,"skill_a",76,0.0,2.0,0,false],[KEY_S,"skill_s_start",77,4.0,0.0,0,false],[KEY_D,"skill_d",80,5.0,0.0,0,false],[KEY_G,"skill_g",81,8.0,0.0,0,false],[KEY_F,"skill_f",82,7.0,0.0,1,false],[KEY_H,"skill_h",83,4.0,0.0,1,false],[KEY_W,"skill_w",88,11.0,0.0,1,true],[KEY_E,"skill_e",89,0.0,7.0,2,true],[KEY_R,"skill_r",90,30.0,0.0,5,false],[KEY_V,"skill_v",100,5.0,0.0,0,false],[KEY_Q,"skill_q",112,0.0,5.0,1,true]]
# Source proof of a principal sound. Full nested-clock sound coverage is a
# separate matrix; a valid stream alone does not mean every original sound ran.
const MAIN_SOUND_IDS := {"skill_z":5209,"skill_a":4695,"skill_s_start":5240,"skill_d":0,"skill_g":5314,"skill_f":345,"skill_h":5364,"skill_w":5432,"skill_e":5494,"skill_r":4002,"skill_v":4695,"skill_q":5240}
var app: Node
var checks: Array[Dictionary] = []
var traces: Array[Dictionary] = []
var sounds: Array[Dictionary] = []
var notices: Array[String] = []
var current_case := "startup"
var formal_exists := false
var formal_hash := ""
var author_hashes: Dictionary = {}

func _initialize() -> void:call_deferred("_run")

func _check(label: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"name":label,"passed":passed,"detail":detail,"case":current_case})
	print(("PASS " if passed else "FAIL ")+label+" "+str(detail))

func _release() -> void:
	for key: String in INPUTS:Input.action_release(key)

func _snapshot(battle: Node2D) -> Dictionary:
	var foes: Array = []
	for enemy: Node2D in battle.enemies:
		foes.append({"id":enemy.identifier,"hp":enemy.hp,"state":enemy.state,"frame":enemy.source_frame,"position":enemy.position,"airborne":enemy.airborne})
	return {"tick":battle.session.run.source_ticks,"state":battle.player.state,"parent":battle.player.parent_frame,"frame":battle.player.source_frame,"position":battle.player.position,"hp":battle.player.hp,"mp":battle.player.mp,"cubes":battle.session.profile.progress.clear_cubes,"pren":battle.pren,"zab":battle.zab,"crt2":battle.crt2.duplicate(true),"objects":battle._crt2_objects.size(),"views":battle._crt2_views.keys(),"enemy":foes,"ended":battle.ended}

func _on_sound(alias: String, stream: AudioStream, from_seconds: float, voice: AudioStreamPlayer) -> void:
	var sid := int(app.database.assets.audio_events.get(alias,{}).get("sound_id",0))
	if sid==0 and stream!=null:sid=stream.resource_path.get_file().get_basename().to_int()
	var battle: Node2D = app.battle if is_instance_valid(app.battle) else null
	sounds.append({"case":current_case,"alias":alias,"sound_id":sid,"path":stream.resource_path if stream!=null else "","seconds":stream.get_length() if stream!=null else 0.0,"from":from_seconds,"voice_valid":is_instance_valid(voice) and voice.stream==stream and voice.playing and voice.has_stream_playback(),"tick":battle.session.run.source_ticks if battle!=null else -1,"action":battle.player.state if battle!=null else "","frame":battle.player.source_frame if battle!=null else -1})

func _fresh(name: String, ready := true) -> Node2D:
	current_case=name
	_release()
	notices.clear()
	app.action_lab=false
	app.session.profile=app.saves.default_profile()
	app.session.select_difficulty("expert")
	app._on_intent("training",null)
	app._on_intent("select_training_character","crt_2")
	var battle: Node2D = app.battle
	battle.manual_clock=true
	battle.set_physics_process(false)
	battle.feedback.connect(func(message:String)->void:notices.append(message))
	# One initial spatial seed isolates action cases from hostile AI contacts.
	for enemy: Node2D in battle.enemies:enemy.position=Vector2(520,-1000)
	if ready:_tick(battle,450)
	_check("normal training CRT2 entry "+name,app.screen=="battle" and not app.action_lab and battle.is_training() and battle.player.definition.source_crt==2 and battle.player.parent_frame==64 and not battle.ended,_snapshot(battle))
	if ready:_check("source R430 becomes naturally ready "+name,int(battle.crt2.r_slot_frame)==430,_snapshot(battle))
	return battle

func _tick(battle: Node2D, count := 1) -> void:
	for n in range(count):battle.step(battle.take_commands())

func _press(battle: Node2D, code: int, echo := false) -> void:
	if KEY_ACTIONS.has(code):Input.action_press(KEY_ACTIONS[code])
	var event := InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=true
	event.echo=echo
	battle._unhandled_input(event)
	_tick(battle)

func _up(battle: Node2D, code: int) -> void:
	if KEY_ACTIONS.has(code):Input.action_release(KEY_ACTIONS[code])
	var event := InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=false
	battle._unhandled_input(event)

func _tap(battle: Node2D, code: int, echo := false) -> void:
	_press(battle,code,echo)
	_up(battle,code)

func _until(battle: Node2D, condition: Callable, cap := 180) -> bool:
	for n in range(cap+1):
		if condition.call():return true
		if battle.ended:return false
		if n<cap:_tick(battle)
	return false

func _idle(battle: Node2D, cap := 250) -> bool:
	return _until(battle,func()->bool:return battle.player.state=="idle",cap)

func _frame(battle: Node2D, action: String, source_frame: int, cap := 180) -> bool:
	for n in range(cap+1):
		if battle.player.state!=action or battle.ended:return false
		if battle.player.source_frame>=source_frame:return true
		if n<cap:_tick(battle)
	return false

func _cooldown(battle: Node2D, action: String) -> int:
	var data: Dictionary = battle.player.definition.actions[action]
	return int(battle.player.cooldowns.get(str(data.get("cooldown_key",action)),0))

func _frenzy(battle: Node2D) -> bool:
	_tap(battle,KEY_H)
	var okay := _until(battle,func()->bool:return battle.pren==1 and battle.player.state=="idle",50)
	_check("H legally enables pren1 and returns",okay,_snapshot(battle))
	return okay

func _authored_contract() -> void:
	var definition: Dictionary = app.database.characters["crt_2"]
	for id: String in EXPECTED_ACTIONS:
		var row: Dictionary = definition.actions.get(id,{})
		_check("author/runtime action exists "+id,not row.is_empty() and app.database.assets.animations.has(str(row.get("animation",""))),row.get("source_parent",-1))
	for pair: Array in [["skill_d","skill"],["skill_f","load_f"],["skill_g","load_g"],["skill_h","load_h"]]:
		_check("formal input resource mapping "+pair[0],str(definition.actions.get(pair[0],{}).get("input",""))==pair[1])
	var wrong_input := false
	for row: Dictionary in definition.actions.values():
		if str(row.get("input","")) in ["skill_t","skill_y"]:wrong_input=true
	_check("default CRT2 has no invented T/Y binding",not wrong_input)

func _test_entries_and_costs() -> void:
	for entry: Array in ENTRIES:
		var action: String = entry[1]
		var battle := _fresh("entry_"+action)
		if entry[6] and not _frenzy(battle):continue
		var hp: float=battle.player.hp
		var mp: float=battle.player.mp
		var cubes: int=battle.session.profile.progress.clear_cubes
		_press(battle,entry[0])
		_check("key enters source action "+action,battle.player.state==action and battle.player.parent_frame==entry[2],_snapshot(battle))
		_check("source HP/MP/cube cost "+action,absf(mp-battle.player.mp-float(entry[3]))<=.051 and absf(hp-battle.player.hp-float(entry[4]))<=.011 and cubes-int(battle.session.profile.progress.clear_cubes)==int(entry[5]),_snapshot(battle))
		if action=="skill_r":_check("R holds source slot2 during release",int(battle.crt2.r_slot_frame)==2 and not bool(battle.crt2.r_slot_playing),_snapshot(battle))
		else:_check("accepted input starts shared source cooldown "+action,_cooldown(battle,action)>0,_snapshot(battle))
		_up(battle,entry[0])
		_check("default chain returns64 "+action,_idle(battle,320) and battle.player.parent_frame==64,_snapshot(battle))
		var expected_sound: int=MAIN_SOUND_IDS[action]
		if expected_sound>0:
			var heard: bool=sounds.any(func(row:Dictionary)->bool:return row["case"]=="entry_"+action and int(row.sound_id)==expected_sound and row.voice_valid)
			_check("formal action requests original principal sound "+action,heard,expected_sound)
		traces.append({"case":current_case,"terminal":_snapshot(battle)})

func _test_rejections() -> void:
	for code: int in [KEY_W,KEY_E,KEY_Q]:
		var battle := _fresh("pren_gate_"+str(code))
		var mp: float=battle.player.mp
		var hp: float=battle.player.hp
		var cubes: int=battle.session.profile.progress.clear_cubes
		_tap(battle,code)
		_check("pren-required input rejects without fees "+str(code),battle.player.state=="idle" and is_equal_approx(hp,battle.player.hp) and absf(mp-battle.player.mp)<=.051 and cubes==int(battle.session.profile.progress.clear_cubes),_snapshot(battle))
	for spec: Array in [[KEY_A,"skill_a","hp",1.0],[KEY_S,"skill_s_start","mp",0.0],[KEY_F,"skill_f","cubes",0.0],[KEY_E,"skill_e","hp",6.0],[KEY_Q,"skill_q","hp",4.0]]:
		var battle := _fresh("reject_"+str(spec[1]))
		if spec[1] in ["skill_e","skill_q"] and not _frenzy(battle):continue
		# Initial resource boundary, not an action outcome or cooldown fixture.
		if spec[2]=="hp":battle.player.hp=spec[3]
		elif spec[2]=="mp":battle.player.mp=spec[3]
		else:battle.session.profile.progress.clear_cubes=0
		var mp: float=battle.player.mp
		var cubes: int=battle.session.profile.progress.clear_cubes
		notices.clear()
		_tap(battle,spec[0])
		_check("insufficient resource rejects "+str(spec[1]),battle.player.state=="idle" and _cooldown(battle,spec[1])==0 and absf(mp-battle.player.mp)<=.051 and cubes==int(battle.session.profile.progress.clear_cubes) and not notices.is_empty(),{"notices":notices.duplicate(),"snapshot":_snapshot(battle)})
	var battle := _fresh("cooldown_and_state_rejection")
	_tap(battle,KEY_A)
	_idle(battle)
	var hp: float=battle.player.hp
	_tap(battle,KEY_A)
	_check("A repeat during cooldown rejects without HP cost",battle.player.state=="idle" and _cooldown(battle,"skill_a")>0 and is_equal_approx(hp,battle.player.hp),_snapshot(battle))
	battle=_fresh("disallowed_parent")
	_press(battle,KEY_S)
	var before_hp: float=battle.player.hp
	_tap(battle,KEY_A)
	_check("A cannot interrupt source77 charge",battle.player.parent_frame==77 and is_equal_approx(before_hp,battle.player.hp) and _cooldown(battle,"skill_a")==0,_snapshot(battle))
	_release()
	battle=_fresh("unimplemented_T_Y")
	for code: int in [KEY_T,KEY_Y]:
		_tap(battle,code)
		_check("unbound input does not enter another character skill "+str(code),battle.player.state=="idle",_snapshot(battle))

func _test_combo_move_and_a() -> void:
	var battle := _fresh("normal_X_chain")
	_tap(battle,KEY_X)
	_check("X starts normal parent69",battle.player.state=="basic" and battle.player.parent_frame==69,_snapshot(battle))
	for spec: Array in [["basic",9,"basic2",70],["basic2",9,"basic3",71]]:
		var reached:=_frame(battle,spec[0],spec[1],30)
		_check("X reaches legal keyDown window "+str(spec[0]),reached,_snapshot(battle))
		if not reached:break
		_tap(battle,KEY_X,true)
		_check("X repeat event enters "+str(spec[2]),battle.player.state==spec[2] and battle.player.parent_frame==spec[3],_snapshot(battle))
	_check("normal three-hit chain returns",_idle(battle,35),_snapshot(battle))
	battle=_fresh("move_down")
	var x: float=battle.player.position.x
	Input.action_press("move_right")
	_tick(battle,3)
	_check("right movement and CRT2 parent65",battle.player.state=="move" and battle.player.parent_frame==65 and battle.player.position.x>x and battle.player.facing==1,_snapshot(battle))
	_release()
	_tick(battle)
	x=battle.player.position.x
	_tap(battle,KEY_DOWN)
	_check("Down enters CRT2 parent73",battle.player.parent_frame==73,_snapshot(battle))
	_check("Down ends and moves backward",_idle(battle,25) and battle.player.position.x<x,_snapshot(battle))
	battle=_fresh("A_follow")
	var hp: float=battle.player.hp
	_tap(battle,KEY_A)
	var reached:=_frame(battle,"skill_a",16,25)
	_check("A reaches follow window16",reached,_snapshot(battle))
	if reached:
		_tap(battle,KEY_Z)
		_check("A follow Z seeks source30 without another cost",battle.player.state=="skill_a" and battle.player.source_frame>=30 and is_equal_approx(hp-battle.player.hp,2.0),_snapshot(battle))
	_check("A follow ends50 to64",_idle(battle,60),_snapshot(battle))

func _test_s_and_hurt_z() -> void:
	for release_frame: int in range(1,6):
		var early := _fresh("S_release_"+str(release_frame))
		_press(early,KEY_S)
		var reached:=_frame(early,"skill_s_start",release_frame,5)
		_check("held S reaches release-listener frame "+str(release_frame),reached and early.player.source_frame==release_frame,_snapshot(early))
		_up(early,KEY_S)
		_tick(early)
		_check("S release at "+str(release_frame)+" enters short78",early.player.state=="skill_s_release" and early.player.parent_frame==78,_snapshot(early))
		_check("short S ends from "+str(release_frame),_idle(early,40),_snapshot(early))
	var battle:=_fresh("S_full_late_release")
	_press(battle,KEY_S)
	var reached:=_frame(battle,"skill_s_start",6,10)
	_check("held S passes release-listener lifetime",reached,_snapshot(battle))
	_up(battle,KEY_S)
	var full_seen:=_until(battle,func()->bool:return battle.player.state=="skill_s_full",6)
	_check("release after source5 still reaches full79",full_seen and battle.player.parent_frame==79,_snapshot(battle))
	_check("full S ends",_idle(battle,40),_snapshot(battle))
	battle=_fresh("hurt_Z_shared_S_slot")
	battle.player.receive_damage(1.0) # public production damage API, not a source damage oracle
	_check("damage uses real CRT2 hit74",battle.player.parent_frame==74 and battle.player.state=="hit",_snapshot(battle))
	var mp: float=battle.player.mp
	_tap(battle,KEY_Z)
	_check("hurt Z spends8MP and enters the S branch",battle.player.parent_frame in [77,78] and battle.player.state in ["hurt_z","skill_s_start","skill_s_release"] and absf(mp-battle.player.mp-8.0)<=.051,_snapshot(battle))
	_check("hurt Z starts shared S cooldown",_cooldown(battle,"skill_s_start")>0,_snapshot(battle))
	_check("hurt Z route ends",_idle(battle,50),_snapshot(battle))

func _test_frenzy_and_rage() -> void:
	var battle := _fresh("pren_X_four_chain")
	if _frenzy(battle):
		_tap(battle,KEY_X)
		_check("H changes X to source84",battle.player.state=="pren_basic1" and battle.player.parent_frame==84,_snapshot(battle))
		if _frame(battle,"pren_basic1",12,25):
			_press(battle,KEY_X,true)
			_check("blood X event reaches85",battle.player.state=="pren_basic2",_snapshot(battle))
			var third:=_until(battle,func()->bool:return battle.player.state=="pren_basic3",25)
			_check("held X at second10 reaches86",third,_snapshot(battle))
			var fourth:=_until(battle,func()->bool:return battle.player.state=="pren_basic4",25)
			_check("held X at third10 reaches87",fourth,_snapshot(battle))
		_release()
		_check("blood chain ends",_idle(battle,35),_snapshot(battle))
	battle=_fresh("G_H_combo_loop")
	if _frenzy(battle):
		_tap(battle,KEY_G)
		_idle(battle,35)
		_check("G starts independent rage clock",int(battle.crt2.rage_frame)>=9,_snapshot(battle))
		_tap(battle,KEY_X)
		if _frame(battle,"pren_basic1",12,25):
			_press(battle,KEY_X,true)
			var back:=_until(battle,func()->bool:return battle.player.state=="pren_basic1",25)
			_check("G pok changes second10 back to first84",back,_snapshot(battle))
		_release()
		_idle(battle,40)
		_tick(battle,410)
		_check("G407 returns inactive source1",int(battle.crt2.rage_frame)==1,_snapshot(battle))
	battle=_fresh("H_manual_close")
	battle.player.hp=60.0 # initial low-enough resource permits observing uncapped +20
	if _frenzy(battle):
		var ready:=_until(battle,func()->bool:return _cooldown(battle,"skill_h")==0,280)
		_check("H close waits for its genuine shared cooldown",ready,_snapshot(battle))
		var before_hp: float=battle.player.hp
		var before_mp: float=battle.player.mp
		var cubes: int=battle.session.profile.progress.clear_cubes
		_tap(battle,KEY_H)
		_check("H close is parent89 with7MP and no cube",battle.player.state=="skill_h_close" and battle.player.parent_frame==89 and battle.pren==0 and absf(before_mp-battle.player.mp-7.0)<=.051 and cubes==int(battle.session.profile.progress.clear_cubes),_snapshot(battle))
		var done:=_idle(battle,35)
		_check("H close102 returns and heals20",done and absf(battle.player.hp-before_hp-20.0)<=.021 and int(battle.crt2.frenzy_frame)==1,_snapshot(battle))
	battle=_fresh("H_low_HP_auto_off")
	battle.player.hp=5.2 # enough HP to finish the legal startup before natural .01/tick crosses5
	if _frenzy(battle):
		var off:=_until(battle,func()->bool:return battle.pren==0,30)
		_check("H low HP source observer disables pren",off and int(battle.crt2.frenzy_frame)==1,_snapshot(battle))
		var after_hp: float=battle.player.hp
		_tick(battle,20)
		_check("disabled H does not keep draining HP",is_equal_approx(after_hp,battle.player.hp),_snapshot(battle))

func _test_jump_and_air_inputs() -> void:
	var battle := _fresh("C_air_X")
	_tap(battle,KEY_C)
	_check("C starts97 and keeps its own parent timeline",battle.player.state=="jump" and battle.player.parent_frame==97,_snapshot(battle))
	var entered:=_frame(battle,"jump",4,10)
	_check("jump reaches independently placed5416",entered,_snapshot(battle))
	Input.action_press("attack")
	var slash_seen:=_until(battle,func()->bool:return int(battle.crt2.air_frame)>1,8)
	_check("held air X starts its own slash clock",slash_seen and battle.player.parent_frame==97,_snapshot(battle))
	_release()
	_check("airX does not prevent normal landing",_idle(battle,45),_snapshot(battle))
	for jump_frame: int in [4,10]:
		battle=_fresh("air_Z_from_"+str(jump_frame))
		_tap(battle,KEY_C)
		var reached:=_frame(battle,"jump",jump_frame,20)
		_check("jump reaches source Z polling region "+str(jump_frame),reached,_snapshot(battle))
		var mp: float=battle.player.mp
		_press(battle,KEY_Z)
		_check("air Z consumes5MP into source57..67",battle.player.parent_frame==97 and battle.player.source_frame>=57 and battle.player.source_frame<=67 and absf(mp-battle.player.mp-5.0)<=.051,_snapshot(battle))
		_up(battle,KEY_Z)
		var impact_seen := false
		for n in range(25):
			impact_seen=impact_seen or not battle._crt2_objects.is_empty()
			if battle.player.state=="idle":break
			_tick(battle)
		_check("air Z creates actual independent impact object",impact_seen,_snapshot(battle))
		_check("air Z returns via landing",_idle(battle,25),_snapshot(battle))

func _test_grabs_and_objects() -> void:
	for spec: Array in [[KEY_D,"skill_d",16,34],[KEY_V,"skill_v",17,66]]:
		var battle := _fresh("miss_"+str(spec[1]))
		_tap(battle,spec[0])
		var success_seen := false
		for n in range(24):
			success_seen=success_seen or (battle.player.state==spec[1] and battle.player.source_frame>=int(spec[2]))
			if battle.player.state=="idle":break
			_tick(battle)
		_check("empty grab follows failure route "+str(spec[1]),not success_seen and battle.player.state=="idle" and battle.zab.is_empty(),_snapshot(battle))
		battle=_fresh("contact_"+str(spec[1]))
		var target: Node2D=battle.enemies[0]
		# One-time nearby normal-body position, inside documented broad contact
		# rectangle. AI is active; no body, marker, action or grab result is forced.
		target.position=battle.player.position+Vector2(25,36)
		target.hp=2000.0 # training1e22 cannot represent ordinary point damage
		var hp: float=target.hp
		_tap(battle,spec[0])
		var grabbed:=_until(battle,func()->bool:return battle.player.state==spec[1] and battle.player.source_frame>=int(spec[2]) and not battle.zab.is_empty(),25)
		_check("legal contact enters grab branch "+str(spec[1]),grabbed,_snapshot(battle))
		var changed_position: bool = target.position!=battle.player.position+Vector2(25,36)
		var complete:=_idle(battle,120)
		_check("grab causes real response and releases "+str(spec[1]),grabbed and complete and changed_position and target.hp<hp and battle.zab.is_empty(),_snapshot(battle))
		if spec[1]=="skill_d":
			_check("successful D starts independent lust timer",int(battle.crt2.lust_frame)>=9,_snapshot(battle))
			_tick(battle,310)
			_check("D lust296 returns inactive source1",int(battle.crt2.lust_frame)==1,_snapshot(battle))
		else:_check("CRT2 V does not fabricate pren2",battle.pren==0,_snapshot(battle))
	var battle := _fresh("F_independent_objects")
	_tap(battle,KEY_F)
	var object_seen: bool=not battle._crt2_objects.is_empty()
	for n in range(55):
		_tick(battle)
		object_seen=object_seen or not battle._crt2_objects.is_empty()
	_check("F creates finite real source objects",object_seen and battle.player.state=="idle" and battle._crt2_objects.is_empty(),_snapshot(battle))
	battle=_fresh("W_held_release")
	if _frenzy(battle):
		_press(battle,KEY_W)
		var reached:=_frame(battle,"skill_w",50,70)
		_check("held W continues through source40 listener",reached,_snapshot(battle))
		_up(battle,KEY_W)
		_tick(battle)
		_check("W release takes source110 branch",battle.player.state=="skill_w" and battle.player.source_frame>=110,_snapshot(battle))
		_check("W release returns128",_idle(battle,35),_snapshot(battle))

func _test_r_readiness_cutin_and_cleanup() -> void:
	var battle := _fresh("R_initial_wait",false)
	var mp: float=battle.player.mp
	var cubes: int=battle.session.profile.progress.clear_cubes
	_tap(battle,KEY_R)
	_check("R rejects before430 without spending",battle.player.state=="idle" and int(battle.crt2.r_slot_frame)<430 and absf(mp-battle.player.mp)<=.051 and cubes==int(battle.session.profile.progress.clear_cubes),_snapshot(battle))
	var ready:=_until(battle,func()->bool:return int(battle.crt2.r_slot_frame)==430,450)
	_check("R independent source preparation finishes430",ready,_snapshot(battle))
	_tap(battle,KEY_R)
	var air_seen := false
	var cutin_seen := false
	var samples: Array = []
	for n in range(180):
		air_seen=air_seen or int(battle.crt2.r_air_frame)>1
		for view: Variant in battle._crt2_views.values():
			if is_instance_valid(view) and view.get("source_frame")!=null:
				var animation: Dictionary=view.definition
				if str(animation.get("texture",""))==str(app.database.assets.animations.hud_crt2_r_cutin.texture) and view.visible:cutin_seen=true
		samples.append({"tick":battle.session.run.source_ticks,"action":battle.player.state,"frame":battle.player.source_frame,"r_slot":battle.crt2.r_slot_frame,"playing":battle.crt2.r_slot_playing,"r_air":battle.crt2.r_air_frame})
		if battle.player.state=="idle":break
		_tick(battle)
	_check("R actual independent air and cutin visuals occur",air_seen and cutin_seen,{"air":air_seen,"cutin":cutin_seen,"snapshot":_snapshot(battle)})
	_check("R source138 returns and resumes slot2",battle.player.state=="idle" and bool(battle.crt2.r_slot_playing) and int(battle.crt2.r_slot_frame)<430,_snapshot(battle))
	traces.append({"case":"R finite timeline","samples":samples})
	battle=_fresh("cleanup_active_H_R")
	if _frenzy(battle):
		_tap(battle,KEY_R)
		_tick(battle,50)
	var old: Node2D=battle
	var old_views: Array=battle._crt2_views.values().duplicate()
	var replacement:=_fresh("replacement_clean",false)
	_check("normal reentry disposes old state and objects",old.is_queued_for_deletion() and replacement!=old and replacement.pren==0 and int(replacement.crt2.frenzy_frame)==1 and int(replacement.crt2.rage_frame)==1 and int(replacement.crt2.lust_frame)==1 and replacement._crt2_objects.is_empty() and replacement._crt2_views.is_empty(),_snapshot(replacement))
	var parent_owned := true
	for view: Variant in old_views:
		if is_instance_valid(view):parent_owned=parent_owned and (old.is_ancestor_of(view) or view.is_queued_for_deletion())
	_check("active CRT2 visuals remain owned by disposed battle",parent_owned,old_views.size())

func _test_death_and_training_restore() -> void:
	var battle := _fresh("death_cleanup")
	_frenzy(battle)
	battle.player.receive_damage(1000.0) # public lethal damage API fixture
	_tick(battle,30)
	_check("CRT2 lethal damage uses94/source25 hold",battle.player.state=="dead" and battle.player.parent_frame==94 and battle.player.source_frame==25,_snapshot(battle))
	_check("death releases persistent frenzy and grabs",battle.pren==0 and battle.zab.is_empty() and battle._crt2_objects.is_empty(),_snapshot(battle))
	battle=_fresh("training_restore")
	_tap(battle,KEY_A)
	_idle(battle,40)
	battle.player.hp=30.0
	battle.player.mp=20.0
	app._on_intent("training_restore",null)
	# Button8495 assigns200 immediately; root41 HP/MP enterFrame clamps to
	# hpm/mpm130 on the next tick. It never raises the character's max stats.
	_check("source restore button immediately assigns200",is_equal_approx(battle.player.hp,200.0) and is_equal_approx(battle.player.mp,200.0),_snapshot(battle))
	_tick(battle,3)
	_check("normal restore obeys source max clamps and resets slots",is_equal_approx(battle.player.hp,float(battle.player.definition.max_hp)) and is_equal_approx(battle.player.mp,float(battle.player.definition.max_mp)) and _cooldown(battle,"skill_a")==0 and int(battle.crt2.r_slot_frame)<430,_snapshot(battle))

func _run() -> void:
	if "--test-mode" not in OS.get_cmdline_user_args():
		push_error("Requires --test-mode; formal save must not be used")
		quit(2)
		return
	formal_exists=FileAccess.file_exists("user://profile.json")
	if formal_exists:formal_hash=FileAccess.get_sha256("user://profile.json")
	for directory: String in ["res://content/actions/crt2","res://content/components/crt2"]:
		for file: String in DirAccess.get_files_at(directory):
			if file.ends_with(".tres"):author_hashes[directory.path_join(file)]=FileAccess.get_sha256(directory.path_join(file))
	app=MainScene.instantiate()
	root.add_child(app)
	app.set_process(false)
	_check("actual Main boots with enabled CRT2 author content",app.startup_ok and app.test_mode and app.database.characters.has("crt_2") and bool(app.database.characters.get("crt_2",{}).get("enabled",false)),app.database.issues)
	if app.startup_ok and app.database.characters.has("crt_2"):
		app.saves=Save.new("user://act04_crt2/run_%d_%d/profile.json"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()])
		app.audio.sound_played.connect(_on_sound)
		_authored_contract()
		_test_entries_and_costs()
		_test_rejections()
		_test_combo_move_and_a()
		_test_s_and_hurt_z()
		_test_frenzy_and_rage()
		_test_jump_and_air_inputs()
		_test_grabs_and_objects()
		_test_r_readiness_cutin_and_cleanup()
		_test_death_and_training_restore()
		_check("all observed SFX used valid real stream and playback",not sounds.is_empty() and sounds.all(func(row:Dictionary)->bool:return row.seconds>0 and row.voice_valid and row.from>=0 and row.from<row.seconds),sounds.size())
	_release()
	_check("formal save remains unchanged",FileAccess.file_exists("user://profile.json")==formal_exists and (not formal_exists or FileAccess.get_sha256("user://profile.json")==formal_hash))
	var unchanged := true
	for path: String in author_hashes:unchanged=unchanged and FileAccess.get_sha256(path)==author_hashes[path]
	_check("test preserves authored CRT2 resources",unchanged)
	app._dispose_battle()
	var drained: bool=await app.audio.stop_and_drain(1.0)
	_check("Dummy audio references drain on teardown",drained and app.audio.snapshot().pending_playbacks==0)
	app.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	var failures: int=checks.filter(func(row:Dictionary)->bool:return not row.passed).size()
	var output:=OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if output.is_empty():output="res://artifacts/leba_act04_20261117/crt2/run_%d_%d"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var file:=FileAccess.open(output.path_join("act04_crt2_tests.json"),FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify({"suite":"ACT04 CRT2 formal-input functional regression","checks":checks,"failures":failures,"traces":traces,"sounds":sounds,"godot":Engine.get_version_info(),"fixtures":["one-time offscreen enemy positions for isolated functional cases","initial resource insufficiency or uncapped H-heal boundary","one-time normal enemy contact positions and finite2000HP","public receive_damage for reaction/death chain"],"not_tested":["native OS key dispatch","original Flash/Ruffle CRT2 per-tick oracle","full adventure progression and every enemy matchup","all independent sound events and audible listening","GPU placement/visual review","exact marker damage, simultaneous targets and callback scheduling"]},"\t")+"\n")
		file.close()
	print("ACT04_CRT2_TESTS_RESULT "+JSON.stringify({"checks":checks.size(),"failures":failures}))
	quit(0 if failures==0 else 1)
