extends SceneTree
## Source expectations are finite original-AS facts, independent of author data.
## Main/key/held/25Hz only: never assign action, marker, combo, buff or victory.
const MainScene = preload("res://scenes/main.tscn")
const Save = preload("res://scripts/services/save_store.gd")
const EXPECTED_PATH := "res://tests/fixtures/act06_crt4_actions_expected.json"
const KEYS := {KEY_X:"attack",KEY_D:"skill",KEY_S:"skill_s",KEY_C:"jump",KEY_DOWN:"down",KEY_Z:"skill_z",KEY_A:"skill_a",KEY_F:"load_f",KEY_G:"load_g",KEY_H:"load_h",KEY_Q:"skill_q",KEY_W:"skill_w",KEY_E:"skill_e",KEY_R:"skill_r",KEY_T:"skill_t",KEY_Y:"skill_y",KEY_V:"skill_v"}
const LETTERS := {"a":KEY_A,"s":KEY_S,"d":KEY_D,"f":KEY_F,"g":KEY_G,"h":KEY_H,"q":KEY_Q,"w":KEY_W,"e":KEY_E,"r":KEY_R,"t":KEY_T,"y":KEY_Y,"v":KEY_V,"z":KEY_Z}
# Independent original-AS provenance, not generated from the Runtime/component.
const BACKSTEP_REPEAT_SOURCE := {
	"reset":{"path":"res/scripts/DefineSprite_6531/frame_9/DoAction.as","sha256":"35053f002c5674b71a6b615ae0d190871a1a56ad1c185af6cd86771bbcde532c","statement":"gotoAndPlay(1);"},
	"input":{"path":"res/scripts/DefineSprite_6732/frame_168/PlaceObject2_6532_41/CLIPACTIONRECORD onClipEvent(keyDown).as","sha256":"549b4fd22a9441e38673c85581b43320b51eb65ef54dba1fd639dc39b369f8f2"},
	"spawn":{"path":"res/scripts/DefineSprite_6732/frame_168/PlaceObject2_6532_41/CLIPACTIONRECORD onClipEvent(enterFrame)_2.as","sha256":"0fec13a44a9f002a53a2bc8fa96f8d6194c993f2aae8b892cd4d58381916c74c"},
	"parent_end":{"path":"res/scripts/DefineSprite_6532/frame_12/DoAction.as","sha256":"03e9cebe218452a07441beea1e8450971ec16a88e43ec5fb5937ad47f68fc063"},
	"audio":{"source_id":6531,"source_frame":2,"sound_id":6526,"alias":"crt4_source_6531_sound_1"}
}
var app: Node
var expected: Dictionary = {}
var checks: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var sounds: Array[Dictionary] = []
var notices: Array[String] = []
var case_name := "startup"
var author_hashes: Dictionary = {}
var formal_exists := false
var formal_hash := ""

func _initialize() -> void:call_deferred("_run")
func _check(label: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"case":case_name,"name":label,"passed":passed,"detail":detail})
	print(("PASS " if passed else "FAIL ")+label+" "+str(detail))
func _release() -> void:
	for key: int in KEYS:Input.action_release(KEYS[key])
	Input.action_release("move_left");Input.action_release("move_right")
func _objects(b: Node2D) -> Array:
	var result: Array=[]
	for row: Dictionary in b._crt4_objects:
		var item: Dictionary={}
		for key: String in ["id","kind","source_id","frame","age","position","born","depth"]:
			if row.has(key):item[key]=row[key]
		result.append(item)
	return result
func _has_object(b: Node2D, source_id: int) -> bool:
	return _objects(b).any(func(row:Dictionary)->bool:return int(row.get("source_id",-1))==source_id)
func _snapshot(b: Node2D) -> Dictionary:
	var foes: Array=[]
	for enemy: Node2D in b.enemies:foes.append({"id":enemy.identifier,"hp":enemy.hp,"state":enemy.state,"frame":enemy.source_frame,"position":enemy.position,"airborne":enemy.airborne,"hurt_rect":enemy.hurt_rect(),"gravity":enemy.vertical_speed,"gravity_acceleration":enemy.gravity_acceleration,"air_hit_started":enemy._air_hit_started,"air_marker_stopped":enemy.air_marker_stopped})
	return {"tick":b.session.run.source_ticks,"action":b.player.state,"parent":b.player.parent_frame,"frame":b.player.source_frame,"serial":b.player.action_serial,"position":b.player.position,"facing":b.player.facing,"hp":b.player.hp,"mp":b.player.mp,"cubes":b.session.profile.progress.clear_cubes,"crt4":b.crt4.duplicate(true),"objects":_objects(b),"body_frame":b.player.body_frame,"hurt":b.player.hurt_rect(),"gravity":b.player.gravity_rect(),"zab":b.zab,"enemies":foes,"ended":b.ended}
func _tick(b: Node2D, count:=1) -> void:
	for n in range(count):
		var commands: Dictionary=b.take_commands()
		b.step(commands)
		samples.append({"case":case_name,"phase":"after_source_step","commands":commands.duplicate(true),"state":_snapshot(b)})
func _down(b: Node2D, code: int, echo:=false) -> void:
	if KEYS.has(code):Input.action_press(KEYS[code])
	var event:=InputEventKey.new()
	event.keycode=code;event.physical_keycode=code;event.pressed=true;event.echo=echo
	b._unhandled_input(event)
	_tick(b)
func _up(b: Node2D, code: int) -> void:
	if KEYS.has(code):Input.action_release(KEYS[code])
	var event:=InputEventKey.new()
	event.keycode=code;event.physical_keycode=code;event.pressed=false
	b._unhandled_input(event)
func _tap(b: Node2D, code: int, echo:=false) -> void:_down(b,code,echo);_up(b,code)
func _until(b: Node2D, condition: Callable, cap:=100) -> bool:
	for n in range(cap+1):
		if condition.call():return true
		if b.ended:return false
		if n<cap:_tick(b)
	return false
func _frame(b: Node2D, action: String, frame: int, cap:=100) -> bool:
	for n in range(cap+1):
		if b.player.state!=action or b.ended:return false
		if b.player.source_frame==frame:return true
		if n<cap:_tick(b)
	return false
func _idle(b: Node2D, cap:=200) -> bool:return _until(b,func()->bool:return b.player.state=="idle",cap)
func _cooldown(b: Node2D, action: String) -> int:
	var row: Dictionary=b.player.definition.actions.get(action,{})
	return int(b.player.cooldowns.get(str(row.get("cooldown_key",action)),0))
func _seen_frame(action: String, first: int, last: int) -> bool:
	return samples.any(func(row:Dictionary)->bool:return row.case==case_name and row.state.action==action and int(row.state.frame)>=first and int(row.state.frame)<=last)
func _fresh(name: String) -> Node2D:
	case_name=name;_release();notices.clear()
	seed(40617) # Reproducible live AI sampling, not a source-randomness oracle.
	app.action_lab=false;app.session.profile=app.saves.default_profile()
	app.session.select_difficulty("expert")
	app._on_intent("training",null);app._on_intent("select_training_character","crt_4")
	var b: Node2D=app.battle
	b.manual_clock=true;b.set_physics_process(false)
	b.feedback.connect(func(message:String)->void:notices.append(message))
	# One spatial isolation fixture. Original AI remains live afterwards.
	for enemy: Node2D in b.enemies:enemy.position=Vector2(520,-1000)
	_check("formal Main selects CRT4 training146",app.screen=="battle" and not app.action_lab and b.is_training() and int(b.player.definition.source_crt)==4 and b.player.parent_frame==146,_snapshot(b))
	return b
func _ready_y(b: Node2D) -> bool:
	return _until(b,func()->bool:return int(b.crt4.y_slot_frame)==291,320)
func _on_sound(alias: String, stream: AudioStream, offset: float, voice: AudioStreamPlayer) -> void:
	sounds.append({"case":case_name,"alias":alias,"path":stream.resource_path if stream!=null else "","seconds":stream.get_length() if stream!=null else 0.0,"offset":offset,"valid":stream!=null and is_instance_valid(voice) and voice.stream==stream and voice.playing and voice.has_stream_playback()})

func _test_contract() -> void:
	case_name="independent_source_contract"
	var definition: Dictionary=app.database.characters.crt_4
	for id: String in expected.actions:
		var fact: Dictionary=expected.actions[id]
		var row: Dictionary=definition.actions.get(id,{})
		_check("author action has original parent and valid atlas "+id,not row.is_empty() and int(row.get("source_parent",-1))==int(fact.parent) and app.database.assets.animations.has(str(row.get("animation",""))),{"source":fact,"actual_parent":row.get("source_parent",-1)})
	for letter: String in expected.slots:
		var fact: Dictionary=expected.slots[letter]
		var row: Dictionary=definition.actions.get(fact.action,{})
		_check("source input MP/cube contract "+letter,str(row.get("input",""))==fact.input and is_equal_approx(float(row.get("cost",-1)),float(fact.mp)) and int(row.get("cubes",0))==int(fact.cubes),{"source":fact,"author_input":row.get("input","")})
	_check("movement remains source parent146",int(definition.actions.get("move",{}).get("source_parent",-1))==146)

func _test_entries_and_refusals() -> void:
	for letter: String in expected.slots:
		var fact: Dictionary=expected.slots[letter]
		var b:=_fresh("entry_"+letter)
		if letter=="y":_check("Y naturally reaches source ready291",_ready_y(b),_snapshot(b))
		var mp: float=b.player.mp
		var hp: float=b.player.hp
		var cubes: int=b.session.profile.progress.clear_cubes
		_tap(b,LETTERS[letter])
		_check("normal key enters source parent "+letter,b.player.state==fact.action and b.player.parent_frame==int(fact.parent_frame),_snapshot(b))
		_check("one source MP/cube transaction and no HP fee "+letter,absf(mp-b.player.mp-float(fact.mp))<=.051 and cubes-int(b.session.profile.progress.clear_cubes)==int(fact.cubes) and is_equal_approx(hp,b.player.hp),_snapshot(b))
		if letter=="y":_check("Y source slot freezes2",int(b.crt4.y_slot_frame)==2 and not bool(b.crt4.y_slot_playing),_snapshot(b))
		else:_check("accepted skill starts its real cooldown "+letter,_cooldown(b,fact.action)>0,_snapshot(b))
		_check("released default skill returns146 "+letter,_idle(b) and b.player.parent_frame==146,_snapshot(b))
		if expected.world_births.has(fact.action):_check("cast creates required independent field "+letter,_has_object(b,int(expected.world_births[fact.action])),_objects(b))
		b=_fresh("MP_refusal_"+letter)
		if letter=="y":_ready_y(b)
		b.player.mp=0.0 # Explicit initial resource boundary, not action injection.
		cubes=b.session.profile.progress.clear_cubes
		_tap(b,LETTERS[letter])
		_check("MP refusal does not start action or spend cubes "+letter,b.player.state=="idle" and b.player.mp<=.051 and cubes==int(b.session.profile.progress.clear_cubes) and not notices.is_empty(),{"state":_snapshot(b),"notice":notices.duplicate()})
		if int(fact.cubes)>0:
			b=_fresh("cube_refusal_"+letter)
			if letter=="y":_ready_y(b)
			b.session.profile.progress.clear_cubes=0
			mp=b.player.mp
			_tap(b,LETTERS[letter])
			_check("cube refusal does not spend MP "+letter,b.player.state=="idle" and absf(mp-b.player.mp)<=.051 and int(b.session.profile.progress.clear_cubes)==0 and not notices.is_empty(),_snapshot(b))
	var b:=_fresh("initial_Y_not_ready")
	var mp: float=b.player.mp
	_tap(b,KEY_Y)
	_check("initial Y cannot bypass source291 readiness",b.player.state=="idle" and absf(mp-b.player.mp)<=.051,_snapshot(b))
	b=_fresh("cooldown_and_unallowed_state")
	_tap(b,KEY_Q);_idle(b)
	mp=b.player.mp;_tap(b,KEY_Q)
	_check("Q repeated before cooldown does not restart or charge",b.player.state=="idle" and _cooldown(b,"skill_q")>0 and absf(mp-b.player.mp)<=.051,_snapshot(b))
	_tap(b,KEY_C);mp=b.player.mp;_tap(b,KEY_D)
	_check("ground field input rejected in jump",b.player.state=="jump" and absf(mp-b.player.mp)<=.051 and _cooldown(b,"skill_d")==0,_snapshot(b))

func _pure_chain(b: Node2D, second_window: int, echo:=false) -> void:
	_tap(b,KEY_X)
	_check("ordinary X begins150",b.player.parent_frame==150 and b.player.state=="basic",_snapshot(b))
	var ready:=_frame(b,"basic",9)
	_check("first X source9 window reached",ready,_snapshot(b))
	if not ready:return
	_tap(b,KEY_X,echo)
	_check("first X listener selects151/6409",b.player.parent_frame==151 and b.player.state=="basic2" and b.player.source_frame==1,_snapshot(b))
	ready=_frame(b,"basic2",second_window)
	_check("second X original listener window reached",ready,_snapshot(b))
	if not ready:return
	var serial: int=b.player.action_serial
	_tap(b,KEY_X,echo)
	_check("literal same151 play preserves child and identity",b.player.parent_frame==151 and b.player.source_frame==second_window and b.player.action_serial==serial,_snapshot(b))
	_tick(b)
	_check("following source tick naturally reaches152 once",b.player.parent_frame==152 and b.player.state=="basic3" and b.player.source_frame==1 and b.player.action_serial==serial+1,_snapshot(b))
	_check("complete ordinary pureX returns146",_idle(b,30) and b.player.parent_frame==146,_snapshot(b))
func _test_x() -> void:
	var b:=_fresh("pure_X_right")
	_pure_chain(b,10)
	case_name="repeat_pure_X_left_late"
	Input.action_press("move_left");_tick(b);_release();_tick(b)
	_check("real movement turns left without empty147 page",b.player.facing==-1 and b.player.parent_frame==146,_snapshot(b))
	_pure_chain(b,18)
	b=_fresh("pure_X_echo");_pure_chain(b,10,true)
	b=_fresh("X_hold_without_keydown")
	_down(b,KEY_X);_tick(b,25);_up(b,KEY_X)
	_check("holding X alone does not invent continuation",b.player.state=="idle" and not _seen_frame("basic2",1,19),_snapshot(b))
	b=_fresh("X_second_early9")
	_tap(b,KEY_X);_frame(b,"basic",9);_tap(b,KEY_X);_frame(b,"basic2",9)
	_tap(b,KEY_X);_idle(b)
	_check("second source9 press is not buffered into10",not _seen_frame("basic3",1,18),_snapshot(b))
	b=_fresh("X_pending_backstep_interrupt")
	_tap(b,KEY_X);_frame(b,"basic",9);_tap(b,KEY_X);_frame(b,"basic2",10);_tap(b,KEY_X)
	_tap(b,KEY_DOWN)
	_check("backstep cancels pending parent continuation",b.player.parent_frame==168,_snapshot(b))
	_idle(b)
	_check("interrupted pending cannot emit stale third X",not _seen_frame("basic3",1,18),_snapshot(b))
	for direction in [1,-1]:
		b=_fresh("pure_X_real_contact_"+str(direction))
		if direction<0:Input.action_press("move_left");_tick(b);_release();_tick(b)
		b.enemies[0].hp=2000.0;b.enemies[0].position=b.player.position+Vector2(60*direction,46)
		_pure_chain(b,10)
		_check("ordinary full X chain produces real target damage",b.enemies[0].hp<2000.0 and b.enemies[0].hp>0 and b.player.parent_frame==146,_snapshot(b))

func _test_a_s() -> void:
	var b:=_fresh("A_early_release")
	_tap(b,KEY_A)
	_check("early A returns through27..48",_idle(b,65) and _seen_frame("skill_a",27,47) and not _seen_frame("skill_a",49,132),_snapshot(b))
	for ghost in [1,2,3]:
		b=_fresh("A_full_ghost"+str(ghost))
		_tap(b,LETTERS[expected.a.setup_keys[str(ghost)]])
		_check("real field selects original ghost type",_idle(b) and _until(b,func()->bool:return int(b.crt4.ghost_type)==ghost,25),_snapshot(b))
		var mp: float=b.player.mp
		_down(b,KEY_A)
		_check("real input collector carries held A",bool(samples[-1].commands.get("held_a",false)),samples[-1].commands)
		var charged_mp: float=b.player.mp
		_check("charged A has one3MP transaction",absf(mp-charged_mp-3.0)<=.051,_snapshot(b))
		var ready:=_frame(b,"skill_a",26,25)
		_check("held A reaches stop26",ready,_snapshot(b))
		if ready:
			_tick(b,4)
			_check("held A stays26 without repeated fee",b.player.source_frame==26 and b.player.parent_frame==153 and b.player.mp>=charged_mp,_snapshot(b))
			_up(b,KEY_A);_tick(b)
			_check("real input collector observes released A",samples[-1].commands.has("held_a") and not bool(samples[-1].commands.held_a),samples[-1].commands)
			_check("release from26 resumes49",b.player.state=="skill_a" and b.player.source_frame==49,_snapshot(b))
			var branch: Array=expected.a.ghost_branches[str(ghost)]
			_check("A finishes actual ghost branch "+str(ghost),_idle(b,100) and _seen_frame("skill_a",int(branch[0]),int(branch[1])-1),_snapshot(b))
		_release()
	b=_fresh("S_two_continuations")
	var mp: float=b.player.mp
	_tap(b,KEY_S);_check("S source5 window reached",_frame(b,"skill_s",5),_snapshot(b))
	_tap(b,KEY_S);_check("S follows same action to11",b.player.parent_frame==154 and b.player.source_frame==11,_snapshot(b))
	_check("S source17 window reached",_frame(b,"skill_s",17),_snapshot(b))
	_tap(b,KEY_S);_check("S third segment begins24",b.player.parent_frame==154 and b.player.source_frame==24,_snapshot(b))
	_check("three S segments return without additional3MP transactions",_idle(b,30) and mp-b.player.mp<4.0,_snapshot(b))
	b=_fresh("A_allowed_from_S")
	_tap(b,KEY_S);_tap(b,KEY_A)
	_check("A can cancel source154 through real slot permission",b.player.parent_frame==153 and b.player.state=="skill_a",_snapshot(b))

func _activate_kalla(b: Node2D) -> bool:
	_tap(b,KEY_T)
	return _until(b,func()->bool:return b.player.state=="idle" and int(b.crt4.kalla)==1 and int(b.crt4.kalla_frame)==12,50)
func _test_kalla() -> void:
	var b:=_fresh("T_kalla_X_listener_identity")
	_check("real T creates persistent Kalla state",_activate_kalla(b),_snapshot(b))
	_tap(b,KEY_X)
	_check("Kalla X selects166 and invalidated146 listener does not overwrite150",b.player.parent_frame==166 and b.player.state=="kalla_basic",_snapshot(b))
	_check("Kalla source3 creates real horizontal clone1326",_until(b,func()->bool:return _has_object(b,1326),8),_objects(b))
	_idle(b)
	var mp: float=b.player.mp
	var cubes: int=b.session.profile.progress.clear_cubes
	_tap(b,KEY_T)
	_check("second T independently enters165 despite first cooldown",b.player.parent_frame==165 and b.player.state=="t_finish" and _cooldown(b,"skill_t")>0,_snapshot(b))
	_check("second T charges8MP and no additional cubes",absf(mp-b.player.mp-8.0)<=.051 and cubes==int(b.session.profile.progress.clear_cubes),_snapshot(b))
	_check("default second T exits Kalla and returns146",_idle(b,60) and int(b.crt4.kalla)==0,_snapshot(b))
	b=_fresh("T_finish_MP_refusal")
	_activate_kalla(b);b.player.mp=0.0;_tap(b,KEY_T)
	_check("insufficient secondT keeps Kalla active",b.player.state=="idle" and int(b.crt4.kalla)==1 and b.player.mp<=.051,_snapshot(b))

func _test_air_backstep_body() -> void:
	for active in [false,true]:
		var b:=_fresh("air_"+("kalla" if active else "normal"))
		if active:_check("air fixture activates Kalla by T",_activate_kalla(b),_snapshot(b))
		_tap(b,KEY_C)
		_check("C enters original167",b.player.state=="jump" and b.player.parent_frame==167,_snapshot(b))
		_check("jump reaches component placement4",_frame(b,"jump",4,8),_snapshot(b))
		Input.action_press("attack") # Original 6528 polls heldX, no fabricated keyDown.
		_tick(b)
		var start: int=13 if active else 2
		_check("held airX chooses proper child branch",int(b.crt4.air_frame)>=start and int(b.crt4.air_frame)<=start+1,_snapshot(b))
		_release()
		if active:_check("Kalla air source15 creates diagonal clone1154",_until(b,func()->bool:return _has_object(b,1154),8),_objects(b))
		_check("air child and parent clocks complete to146",_idle(b,60) and b.player.parent_frame==146,_snapshot(b))
		b=_fresh("backstep_"+("kalla" if active else "normal"))
		if active:_activate_kalla(b)
		var before: Vector2=b.player.position
		_tap(b,KEY_DOWN);_tap(b,KEY_X)
		if active:_check("Kalla backstep X creates actual diagonal clone",_until(b,func()->bool:return _has_object(b,1154),6),_objects(b))
		else:_check("normal backstep X does not invent Kalla clone",not _has_object(b,1154) and int(b.crt4.back_frame)==1,_snapshot(b))
		_check("backstep moves opposite facing and returns146",_idle(b,20) and b.player.position.x<before.x,_snapshot(b))
	var b:=_fresh("body_source_absence")
	_check("idle has actual normal and gravity bodies",b.player.hurt_rect().has_area() and b.player.gravity_rect().has_area(),_snapshot(b))
	_tap(b,KEY_S);_frame(b,"skill_s",3)
	_check("S missing normal body does not fall back to idle rectangle",not b.player.hurt_rect().has_area() and b.player.gravity_rect().has_area(),_snapshot(b))
	b=_fresh("W_persistent_ghost_state")
	_tap(b,KEY_W)
	_check("W source7 starts independent ghost timeline",_idle(b,30) and _until(b,func()->bool:return int(b.crt4.ghost_step)==1,30),_snapshot(b))
	_check("ghost state survives casting action ending",b.player.state=="idle" and int(b.crt4.ghost_frame)>=13,_snapshot(b))

func _test_kalla_backstep_repeat() -> void:
	var b:=_fresh("backstep_Kalla_source9_repeat_X")
	_check("repeat-back fixture activates Kalla through real T",_activate_kalla(b),_snapshot(b))
	_tap(b,KEY_DOWN)
	var parent_serial: int=b.player.action_serial
	_tap(b,KEY_X)
	_check("first back X starts child2 inside original168 parent2",b.player.state=="backstep" and b.player.parent_frame==168 and b.player.source_frame==2 and int(b.crt4.back_frame)==2,_snapshot(b))
	_tick(b)
	var first_clones: Array=_objects(b).filter(func(row:Dictionary)->bool:return int(row.source_id)==1154)
	_check("first child3 creates one actual1154",b.player.source_frame==3 and int(b.crt4.back_frame)==3 and first_clones.size()==1,{"state":_snapshot(b),"source":BACKSTEP_REPEAT_SOURCE.spawn})
	var reached_reset:=_frame(b,"backstep",9,8)
	_check("source6531 frame9 jumps to1 before parent12 ends",reached_reset and int(b.crt4.back_frame)==1 and b.player.action_serial==parent_serial,{"state":_snapshot(b),"source":BACKSTEP_REPEAT_SOURCE.reset})
	# New actual keyDown after the first X was released. No action/child clock seed.
	_tap(b,KEY_X)
	_check("new back X reopens child2 on same parent10",b.player.state=="backstep" and b.player.source_frame==10 and int(b.crt4.back_frame)==2 and b.player.action_serial==parent_serial,{"state":_snapshot(b),"source":BACKSTEP_REPEAT_SOURCE.input})
	_tick(b)
	var second_clones: Array=_objects(b).filter(func(row:Dictionary)->bool:return int(row.source_id)==1154)
	var unique_clones:=second_clones.size()==2 and int(second_clones[0].id)!=int(second_clones[1].id)
	_check("second child3 creates second1154 before same parent12",b.player.source_frame==11 and int(b.crt4.back_frame)==3 and b.player.action_serial==parent_serial and unique_clones,_snapshot(b))
	var played: Array=sounds.filter(func(row:Dictionary)->bool:return row.case==case_name and row.alias=="crt4_source_6531_sound_1")
	_check("each back child2 consumes actual6526 once",played.size()==2 and played.all(func(row:Dictionary)->bool:return row.valid and str(row.path).ends_with("/6526.mp3")),{"requests":played,"source":BACKSTEP_REPEAT_SOURCE.audio})
	_check("repeated back attacks still exit at original parent12",_idle(b,4) and b.player.parent_frame==146,{"state":_snapshot(b),"source":BACKSTEP_REPEAT_SOURCE.parent_end})

func _test_contact_reactions_cleanup() -> void:
	for direction in [1,-1]:
		var b:=_fresh("V_contact_"+str(direction))
		if direction<0:Input.action_press("move_left");_tick(b);_release();_tick(b)
		# One legitimate contact baseline; do not write marker, zab or enemy action.
		b.enemies[0].hp=2000.0;b.enemies[0].position=b.player.position+Vector2(35*direction,46)
		_tap(b,KEY_V)
		_check("one finite V contact fixture survives original first tick",is_equal_approx(b.enemies[0].hp,2000.0),_snapshot(b))
		var caught:=_until(b,func()->bool:return not b.zab.is_empty(),10)
		_check("V contact acquires target through source5..7",caught,_snapshot(b))
		_check("V success enters authored17..79 and actually damages",_idle(b,110) and caught and _seen_frame("skill_v",17,65) and b.enemies[0].hp<2000.0 and b.zab.is_empty(),_snapshot(b))
	var b:=_fresh("V_empty")
	_tap(b,KEY_V)
	_check("V miss ends16 without invented success",_idle(b,22) and b.zab.is_empty() and not _seen_frame("skill_v",17,79),_snapshot(b))
	b=_fresh("public_hurt_Z_fixture")
	b.player.receive_damage(1.0)
	_check("public hurt selects169",b.player.state=="hit" and b.player.parent_frame==169,_snapshot(b))
	var mp: float=b.player.mp
	_tap(b,KEY_Z)
	_check("Z legitimately cancels hurt169 into163 for2MP",b.player.parent_frame==163 and absf(mp-b.player.mp-2.0)<=.051,_snapshot(b))
	_check("hurtZ returns146",_idle(b,25),_snapshot(b))
	b=_fresh("active_objects_reentry")
	_tap(b,KEY_D);_idle(b);_activate_kalla(b)
	_check("cleanup baseline contains real field and Kalla",_has_object(b,316) and int(b.crt4.kalla)==1,_snapshot(b))
	var old:=b
	b=_fresh("reentered_clean")
	_check("reentry disposes encounter and resets independent state",old!=b and old.is_queued_for_deletion() and b._crt4_objects.is_empty() and int(b.crt4.kalla)==0 and int(b.crt4.ghost_step)==0 and int(b.crt4.air_frame)==1 and int(b.crt4.back_frame)==1 and b.zab.is_empty(),_snapshot(b))
	_tap(b,KEY_X)
	_check("reentered actor starts ordinary150 again",b.player.parent_frame==150,_snapshot(b))
	b=_fresh("death_fixture")
	_activate_kalla(b);b.player.receive_damage(1000.0);_tick(b,30)
	_check("death uses174 and holds source6540 frame25",b.player.state=="dead" and b.player.parent_frame==174 and b.player.source_frame==25,_snapshot(b))
	_check("death clears active Kalla and capture",int(b.crt4.kalla)==0 and b.zab.is_empty(),_snapshot(b))

func _run() -> void:
	if "--test-mode" not in OS.get_cmdline_user_args():push_error("ACT06 CRT4 requires --test-mode");quit(2);return
	expected=JSON.parse_string(FileAccess.get_file_as_string(EXPECTED_PATH))
	formal_exists=FileAccess.file_exists("user://profile.json")
	if formal_exists:formal_hash=FileAccess.get_sha256("user://profile.json")
	for directory: String in ["res://content/actions/crt4","res://content/components/crt4"]:
		for file: String in DirAccess.get_files_at(directory):
			if file.ends_with(".tres"):author_hashes[directory.path_join(file)]=FileAccess.get_sha256(directory.path_join(file))
	app=MainScene.instantiate();root.add_child(app);app.set_process(false)
	_check("actual Main loads enabled CRT4",app.startup_ok and app.test_mode and app.database.characters.has("crt_4") and bool(app.database.characters.get("crt_4",{}).get("enabled",false)),app.database.issues)
	if app.startup_ok and app.database.characters.has("crt_4"):
		app.saves=Save.new("user://act06_crt4_actions/run_%d_%d/profile.json"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()])
		app.audio.sound_played.connect(_on_sound)
		_test_contract();_test_entries_and_refusals();_test_x();_test_a_s();_test_kalla();_test_air_backstep_body();_test_kalla_backstep_repeat();_test_contact_reactions_cleanup()
		_check("all observed sounds consume actual streams",not sounds.is_empty() and sounds.all(func(row:Dictionary)->bool:return row.valid and row.seconds>0 and row.offset>=0 and row.offset<row.seconds),sounds.size())
	_release()
	_check("formal save remains unchanged",FileAccess.file_exists("user://profile.json")==formal_exists and (not formal_exists or FileAccess.get_sha256("user://profile.json")==formal_hash))
	var unchanged:=true
	for path: String in author_hashes:unchanged=unchanged and FileAccess.get_sha256(path)==author_hashes[path]
	_check("author values are read-only throughout test",unchanged)
	app._dispose_battle()
	# This synchronous suite compresses many encounters into the first host callback.
	# process_frame is emitted before the iteration's native retirement work;
	# wait for its counter to advance, not a fixed sleep or a relaxed audio limit.
	var exit_frame: int=Engine.get_process_frames()
	var exit_started: int=Time.get_ticks_msec()
	var exit_audio_before: Dictionary=app.audio.snapshot()
	while Engine.get_process_frames()<=exit_frame:
		await process_frame
	_check("scene exit completes actual host iteration before audio drain",Engine.get_process_frames()>exit_frame,{"before_frame":exit_frame,"after_frame":Engine.get_process_frames(),"elapsed_ms":Time.get_ticks_msec()-exit_started,"audio_before":exit_audio_before,"audio_after":app.audio.snapshot()})
	var audio_before: Dictionary=app.audio.snapshot()
	var drain_started: int=Time.get_ticks_msec()
	var drained: bool=await app.audio.stop_and_drain(1.0)
	_check("real audio pool drains at teardown",drained and app.audio.snapshot().pending_playbacks==0,{"before":audio_before,"after":app.audio.snapshot(),"elapsed_ms":Time.get_ticks_msec()-drain_started})
	app.queue_free();await process_frame
	var failures: int=checks.filter(func(row:Dictionary)->bool:return not row.passed).size()
	var output:=OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if output.is_empty():output="res://artifacts/leba_act06_20261117/crt4_actions/run_%d_%d"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var file:=FileAccess.open(output.path_join("act06_crt4_actions.json"),FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify({"suite":"ACT06 CRT4 formal Main/key actions","godot":Engine.get_version_info(),"checks":checks,"failures":failures,"samples":samples,"sounds":sounds,"source_fixture":EXPECTED_PATH,"source_fixture_sha256":FileAccess.get_sha256(EXPECTED_PATH),"fixtures":expected.fixtures,"not_claimed":expected.not_claimed,"author_hashes":author_hashes},"\t")+"\n");file.close()
	print("ACT06_CRT4_ACTIONS_RESULT "+JSON.stringify({"checks":checks.size(),"failures":failures}))
	quit(0 if failures==0 else 1)
