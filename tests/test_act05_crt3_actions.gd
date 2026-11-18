extends SceneTree
## ACT05: formal authored CRT3 -> Main training -> actual key event/held input.
## Only source clock, initial resources and one-time enemy positions are fixtures.
## Never assign action, combo counter, marker, cooldown, grab result or victory.
const MainScene = preload("res://scenes/main.tscn")
const Save = preload("res://scripts/services/save_store.gd")
const INPUTS := ["move_left","move_right","attack","skill","skill_s","jump","down","skill_z","skill_a","skill_w","load_f","load_g","load_h","skill_q","skill_t","skill_e","skill_r","skill_y","skill_v","aim_up"]
const KEYS := {KEY_X:"attack",KEY_D:"skill",KEY_S:"skill_s",KEY_C:"jump",KEY_DOWN:"down",KEY_Z:"skill_z",KEY_A:"skill_a",KEY_F:"load_f",KEY_G:"load_g",KEY_Q:"skill_q",KEY_V:"skill_v",KEY_H:"load_h",KEY_W:"skill_w",KEY_E:"skill_e",KEY_R:"skill_r",KEY_T:"skill_t",KEY_Y:"skill_y"}
const ACTIONS := ["idle","move","basic","basic2","basic3","skill_s","skill_s2","skill_s3","skill_a","skill_d","skill_d2","skill_d3","skill_d4","skill_d5","skill_f","skill_g","skill_g_follow","skill_q","skill_q_finish","backstep","jump","jump_z","skill_v","hit","knockdown","fallen","dead"]
const ENTRY_CASES := [[KEY_A,"skill_a",109,3.0,0],[KEY_Z,"skill_a",109,3.0,0],[KEY_D,"skill_d",120,3.0,0],[KEY_F,"skill_f",125,3.0,0],[KEY_G,"skill_g",126,5.0,1],[KEY_Q,"skill_q",127,6.0,1],[KEY_V,"skill_v",140,5.0,0]]
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
	for input: String in INPUTS:Input.action_release(input)

func _snapshot(battle: Node2D) -> Dictionary:
	var enemies: Array = []
	for enemy: Node2D in battle.enemies:
		enemies.append({"id":enemy.identifier,"hp":enemy.hp,"state":enemy.state,"frame":enemy.source_frame,"position":enemy.position,"airborne":enemy.airborne})
	return {"tick":battle.session.run.source_ticks,"state":battle.player.state,"parent":battle.player.parent_frame,"frame":battle.player.source_frame,"position":battle.player.position,"facing":battle.player.facing,"hp":battle.player.hp,"mp":battle.player.mp,"cubes":battle.session.profile.progress.clear_cubes,"crt3":battle.crt3.duplicate(true),"zab":battle.zab,"body_frame":battle.player.body_frame,"hurt_rect":battle.player.hurt_rect(),"gravity_rect":battle.player.gravity_rect(),"enemies":enemies,"ended":battle.ended}

func _on_sound(alias: String, stream: AudioStream, offset: float, voice: AudioStreamPlayer) -> void:
	sounds.append({"case":current_case,"alias":alias,"path":stream.resource_path if stream!=null else "","seconds":stream.get_length() if stream!=null else 0.0,"offset":offset,"valid":stream!=null and is_instance_valid(voice) and voice.stream==stream and voice.playing and voice.has_stream_playback()})

func _fresh(name: String) -> Node2D:
	current_case=name
	_release()
	notices.clear()
	app.action_lab=false
	app.session.profile=app.saves.default_profile()
	app.session.select_difficulty("expert")
	app._on_intent("training",null)
	app._on_intent("select_training_character","crt_3")
	var battle: Node2D=app.battle
	battle.manual_clock=true
	battle.set_physics_process(false)
	battle.feedback.connect(func(message:String)->void:notices.append(message))
	# Initial isolation only. AI is neither disabled nor continually repositioned.
	for enemy: Node2D in battle.enemies:enemy.position=Vector2(520,-1000)
	_check("formal training enters CRT3 "+name,app.screen=="battle" and not app.action_lab and battle.is_training() and int(battle.player.definition.source_crt)==3 and battle.player.parent_frame==101 and not battle.ended,_snapshot(battle))
	return battle

func _tick(battle: Node2D, count := 1) -> void:
	for n in range(count):battle.step(battle.take_commands())

func _down(battle: Node2D, code: int, echo := false) -> void:
	if KEYS.has(code):Input.action_press(KEYS[code])
	var event:=InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=true
	event.echo=echo
	battle._unhandled_input(event)
	_tick(battle)

func _up(battle: Node2D, code: int) -> void:
	if KEYS.has(code):Input.action_release(KEYS[code])
	var event:=InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=false
	battle._unhandled_input(event)

func _tap(battle: Node2D, code: int, echo := false) -> void:
	_down(battle,code,echo)
	_up(battle,code)

func _until(battle: Node2D, condition: Callable, cap := 120) -> bool:
	for n in range(cap+1):
		if condition.call():return true
		if battle.ended:return false
		if n<cap:_tick(battle)
	return false

func _idle(battle: Node2D, cap := 160) -> bool:
	return _until(battle,func()->bool:return battle.player.state=="idle",cap)

func _frame(battle: Node2D, action: String, frame: int, cap := 80) -> bool:
	for n in range(cap+1):
		if battle.player.state!=action or battle.ended:return false
		if battle.player.source_frame>=frame:return true
		if n<cap:_tick(battle)
	return false

func _cooldown(battle: Node2D, action: String) -> int:
	var row: Dictionary=battle.player.definition.actions.get(action,{})
	return int(battle.player.cooldowns.get(str(row.get("cooldown_key",action)),0))

func _body_nonempty(rect: Rect2) -> bool:return rect.size.x>0 and rect.size.y>0

func _authored_contract() -> void:
	var definition: Dictionary=app.database.characters.crt_3
	for id: String in ACTIONS:
		var row: Dictionary=definition.actions.get(id,{})
		_check("author action/atlas exists "+id,not row.is_empty() and app.database.assets.animations.has(str(row.get("animation",""))),row.get("source_parent",-1))
	var forbidden := []
	for id: String in definition.actions:
		if str(definition.actions[id].get("input","")) in ["skill_r","skill_t","skill_y"]:forbidden.append(id)
	_check("no invented default R/T/Y",forbidden.is_empty(),forbidden)
	for pair: Array in [["skill_d","skill"],["skill_f","load_f"],["skill_g","load_g"]]:
		_check("authored key mapping "+pair[0],str(definition.actions.get(pair[0],{}).get("input",""))==pair[1])
	var bodies: Dictionary=app.database.assets.source_geometry.get("act05_crt3_body",{})
	_check("CRT3 has explicit body source instead of CRT0 fallback",bodies.has("parents") and bodies.parents.has("139") and bodies.parents.has("140"),bodies.keys())

func _test_entries() -> void:
	for entry: Array in ENTRY_CASES:
		var battle:=_fresh("entry_"+str(entry[0]))
		var mp: float=battle.player.mp
		var cubes: int=battle.session.profile.progress.clear_cubes
		_tap(battle,entry[0])
		_check("key enters original parent "+str(entry[1]),battle.player.state==entry[1] and battle.player.parent_frame==entry[2],_snapshot(battle))
		_check("entry charges exact MP/cubes once "+str(entry[1]),absf(mp-battle.player.mp-float(entry[3]))<=.051 and cubes-int(battle.session.profile.progress.clear_cubes)==int(entry[4]),_snapshot(battle))
		_check("accepted entry starts cooldown "+str(entry[1]),_cooldown(battle,entry[1])>0,_snapshot(battle))
		_check("unextended default returns101 "+str(entry[1]),_idle(battle) and battle.player.parent_frame==101,_snapshot(battle))
		_check("return101 clears source combo counters",int(battle.crt3.rigui)==0 and int(battle.crt3.pyeongta)==0 and int(battle.crt3.q_count)==0,_snapshot(battle))

func _test_resource_alias_and_rejections() -> void:
	var battle:=_fresh("A_Z_alias")
	Input.action_press("skill_z")
	var mp: float=battle.player.mp
	_down(battle,KEY_A)
	_check("simultaneous A/Z has one shared transaction",battle.player.parent_frame==109 and absf(mp-battle.player.mp-3.0)<=.051,_snapshot(battle))
	_release()
	_idle(battle)
	mp=battle.player.mp
	_tap(battle,KEY_Z)
	_check("Z cannot bypass A shared cooldown",battle.player.state=="idle" and _cooldown(battle,"skill_a")>0 and absf(mp-battle.player.mp)<=.051,_snapshot(battle))
	var ready:=_until(battle,func()->bool:return _cooldown(battle,"skill_a")==0,70)
	_check("shared A/Z cooldown naturally finishes",ready,_snapshot(battle))
	_tap(battle,KEY_Z)
	_check("Z works again after natural shared cooldown",battle.player.parent_frame==109,_snapshot(battle))
	for entry: Array in ENTRY_CASES:
		battle=_fresh("insufficient_MP_"+str(entry[0]))
		battle.player.mp=0.0
		var cubes: int=battle.session.profile.progress.clear_cubes
		_tap(battle,entry[0])
		_check("insufficient MP refuses without cooldown/cube spend "+str(entry[0]),battle.player.state=="idle" and _cooldown(battle,entry[1])==0 and cubes==int(battle.session.profile.progress.clear_cubes) and not notices.is_empty(),{"snapshot":_snapshot(battle),"notices":notices.duplicate()})
	for code: int in [KEY_G,KEY_Q]:
		battle=_fresh("insufficient_cubes_"+str(code))
		battle.session.profile.progress.clear_cubes=0
		mp=battle.player.mp
		_tap(battle,code)
		_check("cube gate is atomic "+str(code),battle.player.state=="idle" and absf(mp-battle.player.mp)<=.051 and not notices.is_empty(),_snapshot(battle))
	battle=_fresh("invalid_parent")
	_tap(battle,KEY_F)
	mp=battle.player.mp
	_tap(battle,KEY_A)
	_check("A cannot cancel unlicensed F parent125",battle.player.parent_frame==125 and _cooldown(battle,"skill_a")==0 and absf(mp-battle.player.mp)<=.051,_snapshot(battle))
	battle=_fresh("unbound_keys")
	for code: int in [KEY_R,KEY_T,KEY_Y]:
		_tap(battle,code)
		_check("unbound default key stays CRT3 idle "+str(code),battle.player.parent_frame==101 and battle.player.state=="idle",_snapshot(battle))

func _test_x_s_counters() -> void:
	var battle:=_fresh("X_S_X2_X3")
	_tap(battle,KEY_X)
	_check("X starts106 and increments pyeongta",battle.player.state=="basic" and battle.player.parent_frame==106 and int(battle.crt3.pyeongta)==1,_snapshot(battle))
	var reached:=_frame(battle,"basic",9,20)
	_check("X reaches source9 cross-input window",reached,_snapshot(battle))
	if reached:
		_tap(battle,KEY_S)
		_check("X to S uses rigui0 ->117",battle.player.state=="skill_s" and battle.player.parent_frame==117 and int(battle.crt3.rigui)==1,_snapshot(battle))
		Input.action_press("attack")
		var switched:=_until(battle,func()->bool:return battle.player.parent_frame==107,20)
		_check("S parent poll remembers X counter and enters107",switched and battle.player.state=="basic2" and int(battle.crt3.pyeongta)==2,_snapshot(battle))
		_release()
		if switched and _frame(battle,"basic2",8,20):
			_tap(battle,KEY_X,true)
			_check("X2 source8 event enters108",battle.player.state=="basic3" and battle.player.parent_frame==108,_snapshot(battle))
	_check("mixed chain returns and resets",_idle(battle,35) and int(battle.crt3.rigui)==0 and int(battle.crt3.pyeongta)==0,_snapshot(battle))
	battle=_fresh("held_S_then_repeat_event")
	var mp: float=battle.player.mp
	_down(battle,KEY_S)
	_check("S starts117 without MP cost",battle.player.parent_frame==117 and absf(mp-battle.player.mp)<=.051,_snapshot(battle))
	var second:=_until(battle,func()->bool:return battle.player.parent_frame==118,20)
	_check("held S parent117 polling enters118",second and int(battle.crt3.rigui)==2,_snapshot(battle))
	if second:
		var ready:=_frame(battle,"skill_s2",10,16)
		_check("S2 held alone does not fake keyDown continuation",ready and battle.player.parent_frame==118,_snapshot(battle))
		_down(battle,KEY_S,true)
		_check("S repeat keyDown enters119",battle.player.state=="skill_s3" and battle.player.parent_frame==119,_snapshot(battle))
	_release()
	_check("three S stages finish without a skill fee",_idle(battle,35) and absf(mp-battle.player.mp)<=.051,_snapshot(battle))
	battle=_fresh("X_repeat_source_same_parent")
	_tap(battle,KEY_X)
	if _frame(battle,"basic",9,20):
		var serial:int=battle.player.action_serial
		_tap(battle,KEY_X,true)
		_check("same106 resumes parent without replaying child9",battle.player.parent_frame==106 and battle.player.source_frame==9 and battle.player.action_serial==serial and int(battle.crt3.pyeongta)==1,_snapshot(battle))
		_tick(battle)
		_check("resumed parent naturally enters107 next source tick",battle.player.parent_frame==107 and battle.player.source_frame==1 and int(battle.crt3.pyeongta)==2,_snapshot(battle))
		if _frame(battle,"basic2",8,20):
			_tap(battle,KEY_X)
			_check("pure X continues to108 without S",battle.player.parent_frame==108,_snapshot(battle))
		traces.append({"case":"ACT06 original Ruffle same-frame play probe applied; native Adobe Flash not tested","snapshot":_snapshot(battle)})
	_idle(battle,30)

func _test_d_f_g_q() -> void:
	var battle:=_fresh("D_five_stages")
	var mp: float=battle.player.mp
	_tap(battle,KEY_D)
	for row: Array in [["skill_d",8,"skill_d2",121],["skill_d2",7,"skill_d3",122],["skill_d3",7,"skill_d4",123],["skill_d4",8,"skill_d5",124]]:
		var reached:=_frame(battle,row[0],row[1],25)
		_check("D reaches continued event window "+str(row[0]),reached,_snapshot(battle))
		if not reached:break
		Input.action_press("move_left")
		_tap(battle,KEY_D,true)
		_tick(battle)
		_check("D continuation enters "+str(row[2]),battle.player.state==row[2] and battle.player.parent_frame==row[3],_snapshot(battle))
		_check("continued D permits original left turn",battle.player.facing==-1,_snapshot(battle))
		Input.action_release("move_left")
	_check("all D stages end without additional MP fee",_idle(battle,35) and battle.player.mp>=mp-3.051 and _cooldown(battle,"skill_d")>0,_snapshot(battle))
	battle=_fresh("D_held_no_new_key_event")
	_down(battle,KEY_D)
	var another_stage:=false
	for n in range(28):
		another_stage=another_stage or battle.player.parent_frame in [121,122,123,124]
		_tick(battle)
	_release()
	_check("held D alone does not fabricate continuation events",not another_stage and battle.player.state=="idle",_snapshot(battle))
	battle=_fresh("F_default_held")
	var start_x: float=battle.player.position.x
	_down(battle,KEY_F)
	var charged:=false
	var finished:=false
	for n in range(40):
		charged=charged or (battle.player.state=="skill_f" and battle.player.source_frame>=29)
		if battle.player.state=="idle":finished=true;break
		_tick(battle)
	_release()
	_check("default held F returns28 instead of equipment charge29",finished and not charged and battle.player.position.x>start_x,_snapshot(battle))
	battle=_fresh("G_second_press")
	var cubes: int=battle.session.profile.progress.clear_cubes
	_tap(battle,KEY_G)
	var g_window:=_frame(battle,"skill_g",23,30)
	_check("G reaches second listener segment23",g_window,_snapshot(battle))
	if g_window:
		_tap(battle,KEY_G,true)
		_check("second G enters36 with no second cube fee",battle.player.state=="skill_g_follow" and battle.player.source_frame>=36 and cubes-int(battle.session.profile.progress.clear_cubes)==1,_snapshot(battle))
	_check("G follow ends58",_idle(battle,35),_snapshot(battle))
	battle=_fresh("Q_three_dashes")
	cubes=battle.session.profile.progress.clear_cubes
	_down(battle,KEY_Q)
	var max_count:=int(battle.crt3.q_count)
	var finish_seen:=false
	var samples: Array=[]
	for n in range(85):
		max_count=maxi(max_count,int(battle.crt3.q_count))
		samples.append({"tick":battle.session.run.source_ticks,"parent":battle.player.parent_frame,"frame":battle.player.source_frame,"count":battle.crt3.q_count})
		finish_seen=finish_seen or battle.player.parent_frame==128
		if battle.player.state=="idle":break
		_tick(battle)
	_release()
	_check("held Q reaches third-count finisher128",max_count==3 and finish_seen, samples)
	_check("Q natural final return clears count and costs one cube",battle.player.state=="idle" and int(battle.crt3.q_count)==0 and cubes-int(battle.session.profile.progress.clear_cubes)==1,_snapshot(battle))
	traces.append({"case":current_case,"samples":samples})

func _test_air_backstep_and_body() -> void:
	var battle:=_fresh("ground_and_absent_body")
	_check("idle has source normal and gravity bodies",_body_nonempty(battle.player.hurt_rect()) and _body_nonempty(battle.player.gravity_rect()),_snapshot(battle))
	_tap(battle,KEY_A)
	_check("A removes ordinary body but preserves gravity body",not _body_nonempty(battle.player.hurt_rect()) and _body_nonempty(battle.player.gravity_rect()),_snapshot(battle))
	_idle(battle,25)
	_check("idle reconstructs its body after A",_body_nonempty(battle.player.hurt_rect()),_snapshot(battle))
	battle=_fresh("movement_both_directions")
	var start_x: float=battle.player.position.x
	Input.action_press("move_right")
	_tick(battle,3)
	_check("normal movement uses CRT3 and right facing",battle.player.state=="move" and battle.player.position.x>start_x and battle.player.facing==1 and battle.player.parent_frame in [101,102,103],_snapshot(battle))
	Input.action_press("move_left")
	start_x=battle.player.position.x
	_tick(battle,2)
	_check("both directions cancel distance and leave left facing",absf(start_x-battle.player.position.x)<.051 and battle.player.facing==-1,_snapshot(battle))
	_release()
	_tick(battle)
	battle=_fresh("backstep_X")
	start_x=battle.player.position.x
	_tap(battle,KEY_DOWN)
	_check("Down enters130 rather than another character",battle.player.state=="backstep" and battle.player.parent_frame==130,_snapshot(battle))
	Input.action_press("attack")
	var back_attack:=_until(battle,func()->bool:return int(battle.crt3.back_frame)>1,6)
	_check("backstep heldX starts independent6156",back_attack and battle.player.parent_frame==130,_snapshot(battle))
	_release()
	_check("backstep attack still ends with parent12",_idle(battle,20) and battle.player.position.x<start_x,_snapshot(battle))
	battle=_fresh("jump_air_X")
	_tap(battle,KEY_C)
	_check("C enters139 with its own body clock",battle.player.state=="jump" and battle.player.parent_frame==139,_snapshot(battle))
	var placed:=_frame(battle,"jump",4,8)
	_check("jump reaches6308 placement",placed,_snapshot(battle))
	Input.action_press("attack")
	var air_attack:=_until(battle,func()->bool:return int(battle.crt3.air_frame)>1,5)
	_check("held airX starts6308 child without replacing parent",air_attack and battle.player.parent_frame==139,_snapshot(battle))
	Input.action_press("move_left")
	start_x=battle.player.position.x
	_tick(battle,2)
	_check("air input still moves while child slash plays",battle.player.position.x<start_x,_snapshot(battle))
	_release()
	_check("independent airX cannot prevent landing",_idle(battle,35),_snapshot(battle))
	for source_frame: int in [4,6,9,11,20,24]:
		battle=_fresh("air_Z_poll_"+str(source_frame))
		_tap(battle,KEY_C)
		var reached:=_frame(battle,"jump",source_frame,30)
		_check("C reaches original Z polling region "+str(source_frame),reached,_snapshot(battle))
		var mp: float=battle.player.mp
		_down(battle,KEY_Z)
		_check("airZ poll charges once and enters default range "+str(source_frame),battle.player.parent_frame==139 and battle.player.source_frame>=57 and battle.player.source_frame<=67 and absf(mp-battle.player.mp-5.0)<=.051,_snapshot(battle))
		if source_frame==4:_check("earliest child-only airZ starts63",battle.player.source_frame in [63,64],_snapshot(battle))
		traces.append({"case":current_case,"region":source_frame,"accepted":_snapshot(battle),"phase_limit":"Competing original placement callback ordering has not been dynamically probed; later region asserts default range and one transaction, not invented unique callback priority."})
		_up(battle,KEY_Z)
		_check("airZ finishes via source28 landing "+str(source_frame),_idle(battle,30) and battle.player.parent_frame==101,_snapshot(battle))

func _test_contact_grab_and_reaction() -> void:
	for entry: Array in [[KEY_A,"skill_a"],[KEY_D,"skill_d"],[KEY_F,"skill_f"],[KEY_G,"skill_g"],[KEY_Q,"skill_q"]]:
		var battle:=_fresh("contact_"+str(entry[1]))
		var target: Node2D=battle.enemies[0]
		# Finite HP permits observing real damage (training default1e22 loses small deltas).
		target.hp=2000.0
		target.position=battle.player.position+Vector2(60,46)
		var hp: float=target.hp
		_tap(battle,entry[0])
		var hit:=_until(battle,func()->bool:return target.hp<hp,40)
		_check("real contact changes target HP "+str(entry[1]),hit,_snapshot(battle))
	var battle:=_fresh("V_empty")
	_tap(battle,KEY_V)
	var false_success:=false
	for n in range(22):
		false_success=false_success or not battle.zab.is_empty() or (battle.player.state=="skill_v" and battle.player.source_frame>=17)
		if battle.player.state=="idle":break
		_tick(battle)
	_check("empty V follows15 return without false target",not false_success and battle.player.state=="idle",_snapshot(battle))
	battle=_fresh("V_legal_contact")
	var target: Node2D=battle.enemies[0]
	target.hp=2000.0
	target.position=battle.player.position+Vector2(35,46)
	var target_start: Vector2=target.position
	var hp: float=target.hp
	_tap(battle,KEY_V)
	var grabbed:=_until(battle,func()->bool:return battle.player.state=="skill_v" and battle.player.source_frame>=17 and not battle.zab.is_empty(),12)
	_check("V source4..6 real collision enters17",grabbed,_snapshot(battle))
	var moved:=false
	for n in range(85):
		moved=moved or target.position.distance_to(target_start)>1.0
		if battle.player.state=="idle":break
		_tick(battle)
	_check("V successful sequence damages/controls/releases",grabbed and moved and target.hp<hp and battle.player.state=="idle" and battle.zab.is_empty(),_snapshot(battle))
	battle=_fresh("hurt_A_recovery")
	battle.player.receive_damage(1.0) # Public production damage fixture; not source damage oracle.
	_check("real damage selects CRT3 hit133",battle.player.state=="hit" and battle.player.parent_frame==133,_snapshot(battle))
	var mp: float=battle.player.mp
	_tap(battle,KEY_Z)
	_check("hurt Z is shared A source109 with3MP",battle.player.parent_frame==109 and absf(mp-battle.player.mp-3.0)<=.051,_snapshot(battle))
	_check("hurt-A branch can return normally",_idle(battle,25),_snapshot(battle))
	battle=_fresh("death")
	battle.player.receive_damage(1000.0)
	_tick(battle,30)
	_check("CRT3 death uses138 and holds6307 frame25",battle.player.state=="dead" and battle.player.parent_frame==138 and battle.player.source_frame==25,_snapshot(battle))
	_check("death leaves no captured target",battle.zab.is_empty(),_snapshot(battle))

func _test_reentry() -> void:
	var old:=_fresh("active_air_then_reentry")
	_tap(old,KEY_C)
	_frame(old,"jump",4,8)
	Input.action_press("attack")
	_tick(old,2)
	var replacement:=_fresh("reentered")
	_check("normal reentry disposes old encounter and resets controls",old!=replacement and old.is_queued_for_deletion() and replacement.player.state=="idle" and replacement.zab.is_empty() and int(replacement.crt3.rigui)==0 and int(replacement.crt3.pyeongta)==0 and int(replacement.crt3.q_count)==0 and int(replacement.crt3.air_frame)==1 and int(replacement.crt3.back_frame)==1,_snapshot(replacement))
	_tap(replacement,KEY_X)
	_check("reentered actor accepts fresh normal X",replacement.player.parent_frame==106 and int(replacement.crt3.pyeongta)==1,_snapshot(replacement))

func _test_root9_natural_knockdown() -> void:
	var unused_training:=_fresh("root9_natural_knockdown")
	# Reuse the established ACT03 ranged-contact spatial/input fixture. A fixed
	# RNG seed makes AI sampling reproducible; no enemy action or hit is assigned.
	seed(30509)
	app.enter_battle("root_9")
	var battle: Node2D=app.battle
	battle.manual_clock=true
	battle.set_physics_process(false)
	battle.player.position=Vector2(150,315)
	battle.enemies[0].position=Vector2(380,351)
	var hp: float=battle.player.hp
	var terminal: Dictionary={}
	battle.player.action_finished.connect(func(actor:Node2D,action:String)->void:
		if action=="knockdown":terminal.merge({"parent":actor.parent_frame,"frame":actor.source_frame,"tick":battle.session.run.source_ticks}))
	var ranged_seen:=false
	var knocked:=false
	var returned:=false
	var samples: Array=[]
	for n in range(110):
		if n==1:Input.action_press("move_right")
		if n==13:_release()
		_tick(battle)
		ranged_seen=ranged_seen or battle.enemies[0].state=="ranged"
		knocked=knocked or (battle.player.state=="knockdown" and battle.player.parent_frame==134)
		samples.append({"tick":battle.session.run.source_ticks,"parent":battle.player.parent_frame,"frame":battle.player.source_frame,"enemy_state":battle.enemies[0].state,"enemy_frame":battle.enemies[0].source_frame,"hp":battle.player.hp})
		if knocked and battle.player.state=="idle":returned=true;break
	_release()
	_check("root9 AI real ranged contact selects CRT3 parent134",ranged_seen and knocked and unused_training.is_queued_for_deletion(),samples)
	_check("source6303 frame30 restores CRT3 idle",returned and int(terminal.get("parent",-1))==134 and int(terminal.get("frame",-1))==30,terminal)
	_check("knockdown source3 observer changes real player HP",knocked and battle.player.hp<hp and battle.player.hp>0,_snapshot(battle))
	traces.append({"case":current_case,"seed":30509,"player_position":[150,315],"enemy_position":[380,351],"input":"move_right ticks2..13 then release","samples":samples,"terminal":terminal})

func _run() -> void:
	if "--test-mode" not in OS.get_cmdline_user_args():push_error("ACT05 requires --test-mode and isolated profile");quit(2);return
	formal_exists=FileAccess.file_exists("user://profile.json")
	if formal_exists:formal_hash=FileAccess.get_sha256("user://profile.json")
	for directory: String in ["res://content/actions/crt3","res://content/components/crt3"]:
		for file: String in DirAccess.get_files_at(directory):
			if file.ends_with(".tres"):author_hashes[directory.path_join(file)]=FileAccess.get_sha256(directory.path_join(file))
	app=MainScene.instantiate()
	root.add_child(app)
	app.set_process(false)
	_check("actual Main loads enabled CRT3",app.startup_ok and app.test_mode and app.database.characters.has("crt_3") and bool(app.database.characters.get("crt_3",{}).get("enabled",false)),app.database.issues)
	if app.startup_ok and app.database.characters.has("crt_3"):
		app.saves=Save.new("user://act05_actions/run_%d_%d/profile.json"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()])
		app.audio.sound_played.connect(_on_sound)
		_authored_contract()
		_test_entries()
		_test_resource_alias_and_rejections()
		_test_x_s_counters()
		_test_d_f_g_q()
		_test_air_backstep_and_body()
		_test_contact_grab_and_reaction()
		_test_reentry()
		_test_root9_natural_knockdown()
		_check("all observed requests use actual decoded audio streams",not sounds.is_empty() and sounds.all(func(row:Dictionary)->bool:return row.valid and row.seconds>0 and row.offset>=0 and row.offset<row.seconds),sounds.size())
	_release()
	_check("formal save remains untouched",FileAccess.file_exists("user://profile.json")==formal_exists and (not formal_exists or FileAccess.get_sha256("user://profile.json")==formal_hash))
	var unchanged:=true
	for path: String in author_hashes:unchanged=unchanged and FileAccess.get_sha256(path)==author_hashes[path]
	_check("formal author resources remain untouched",unchanged)
	app._dispose_battle()
	var drained: bool=await app.audio.stop_and_drain(1.0)
	_check("audio pool drains on teardown",drained and app.audio.snapshot().pending_playbacks==0)
	app.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	var failures: int=checks.filter(func(row:Dictionary)->bool:return not row.passed).size()
	var output:=OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if output.is_empty():output="res://artifacts/leba_act05_20261117/actions/run_%d_%d"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var file:=FileAccess.open(output.path_join("act05_crt3_actions.json"),FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify({"suite":"ACT05 CRT3 ordinary actions through formal Main/input; ACT06 corrected same-parent continuation","checks":checks,"failures":failures,"traces":traces,"sounds":sounds,"godot":Engine.get_version_info(),"fixtures":["manual25Hz clock","one-time offscreen/near-contact enemy positions with active AI","finite initial2000 enemyHP for representable damage","initial resource refusal boundary","public receive_damage for player reaction/death"],"not_tested":["H/E/W special lifetime and exhaustive sound matrix owned by separate suite","exhaustive original Flash/Ruffle per-tick and finalHP oracle","host keyboard dispatch and audible listening","GPU visibility/layer/anchor inspection","full adventure progression/warehouse","fallen136 natural trigger/recovery","competing airZ callback order"]},"\t")+"\n")
		file.close()
	print("ACT05_CRT3_ACTIONS_RESULT "+JSON.stringify({"checks":checks.size(),"failures":failures}))
	quit(0 if failures==0 else 1)
