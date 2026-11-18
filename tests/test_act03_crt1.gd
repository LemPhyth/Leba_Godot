extends SceneTree
## Real Main/normal training and InputEventKey dispatch, with a manual25Hz clock.
## Explicit isolated-position/HP/MP/cube fixtures are recorded below; no source
## HP oracle is replayed into the runtime and no action outcome is assigned.
const MainScene = preload("res://scenes/main.tscn")
const Save = preload("res://scripts/services/save_store.gd")
const INPUTS := ["move_left","move_right","attack","skill","skill_s","jump","down","skill_z","skill_a","skill_w","load_f","load_g","load_h","skill_q","skill_t","skill_e","skill_r","skill_v","aim_up"]
const ENTRY_CASES := [[KEY_A,"skill_a",35,2.0,0],[KEY_S,"skill_s",42,3.0,0],[KEY_D,"skill",46,3.0,0],[KEY_F,"skill_f",48,3.0,0],[KEY_G,"skill_g",111,3.0,0],[KEY_Q,"skill_q",49,5.0,0],[KEY_H,"skill_h",145,5.0,1],[KEY_W,"skill_w",54,5.0,1],[KEY_E,"skill_e",55,5.0,1],[KEY_R,"skill_r",56,5.0,2],[KEY_V,"skill_v",99,5.0,0],[KEY_T,"skill_t",110,30.0,5],[KEY_Z,"skill_z",144,2.0,0]]
var app: Node
var checks: Array[Dictionary] = []
var traces: Array[Dictionary] = []
var formal_exists := false
var formal_hash := ""
var author_hashes: Dictionary = {}
const CHILD_AUDIO := ["crt1_jump_air","crt1_d_air","crt1_w_shot","crt1_w_shot_sound_2","crt1_gunhawk1","crt1_gunhawk2","crt1_gunhawk3","crt1_t_ground_fire","crt1_t_ground_fire_sound_2","crt1_t_air_fire2","crt1_q_buff_edges"]
var child_audio_seen: Dictionary = {}

func _initialize() -> void:call_deferred("_run")

func _check(label: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"name":label,"passed":passed,"detail":detail})
	print(("PASS " if passed else "FAIL ")+label+" "+str(detail))

func _release() -> void:
	for key: String in INPUTS:Input.action_release(key)

func _snapshot(battle: Node2D) -> Dictionary:
	var foes: Array = []
	for enemy: Node2D in battle.enemies:foes.append({"id":enemy.identifier,"hp":enemy.hp,"state":enemy.state,"source_frame":enemy.source_frame,"position":enemy.position,"airborne":enemy.airborne})
	return {"tick":battle.session.run.source_ticks,"state":battle.player.state,"parent":battle.player.parent_frame,"frame":battle.player.source_frame,"air_frame":battle.player.air_action_frame,"position":battle.player.position,"mp":battle.player.mp,"cubes":battle.session.profile.progress.clear_cubes,"crt1":battle.crt1.duplicate(true),"projectiles":battle.projectiles.size(),"gunhawks":battle._gunhawks.size(),"enemy":foes,"ended":battle.ended}

func _fresh(stage_id := "", park_enemies := true) -> Node2D:
	_release()
	app.action_lab = false
	app.session.profile = app.saves.default_profile()
	app.session.select_character("crt_1")
	app.session.select_difficulty("expert")
	app._on_intent("select_training_character","crt_1")
	if not stage_id.is_empty():app.enter_battle(stage_id)
	var battle: Node2D = app.battle
	battle.manual_clock = true
	battle.set_physics_process(false)
	# A one-time no-contact seed isolates component/input tests from hostile RNG.
	# Damage cases below use their own declared contact-position fixtures.
	if park_enemies:
		for enemy: Node2D in battle.enemies:enemy.position = Vector2(520,-1000)
	for tick in range(450):battle.step({})
	_check("normal Main CRT1 entry and natural initial readiness",app.screen=="battle" and not app.action_lab and battle.player.definition.source_crt==1 and not battle.ended and int(battle.crt1.t_slot_frame)==405,_snapshot(battle))
	return battle

func _tick(battle: Node2D, count := 1) -> void:
	for n in range(count):
		battle.step(battle.take_commands())
		_observe_child_audio(battle)

func _observe_child_audio(battle: Node2D) -> void:
	# Observe the real bounded AudioStreamPlayer pool. Each catalogue entry has
	# its own decoded stream instance, so equal MP3 paths do not conflate keys.
	for key: String in CHILD_AUDIO:
		if child_audio_seen.has(key):continue
		var stream: AudioStream = app.audio._streams.get("sfx/"+key)
		if stream == null:continue
		for voice: AudioStreamPlayer in app.audio._voices:
			if voice.stream == stream and voice.playing and voice.has_stream_playback():
				child_audio_seen[key] = {"tick":battle.session.run.source_ticks,"state":battle.player.state,"source_frame":battle.player.source_frame,"stream_id":stream.get_instance_id(),"playback_id":voice.get_stream_playback().get_instance_id(),"seconds":stream.get_length()}

func _key(battle: Node2D, code: int, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo
	battle._unhandled_input(event)
	_tick(battle)
	event.pressed = false
	event.echo = false
	battle._unhandled_input(event)

func _wait_idle(battle: Node2D, cap := 380) -> bool:
	for n in range(cap):
		if battle.player.state=="idle":return true
		if battle.ended:return false
		_tick(battle)
	return false

func _wait_frame(battle: Node2D, state: String, frame: int, cap := 200) -> bool:
	for n in range(cap):
		if battle.player.state==state and battle.player.source_frame>=frame:return true
		if battle.player.state!=state or battle.ended:return false
		_tick(battle)
	return false

func _authored_contract() -> void:
	var definition: Dictionary = app.database.characters["crt_1"]
	var expected := ["idle","move","basic","basic2","basic3","basic4","basic5","jump","down","skill_z","move_z","skill_a","skill_s","skill","d_follow","skill_f","skill_g","skill_q","skill_h","h_forward","h_back","h_down","h_up","skill_w","skill_e","skill_r","r_catch1","r_catch2","revenger","skill_v","skill_t","hit","dead","knockdown"]
	for id: String in expected:
		var row: Dictionary = definition.actions.get(id,{})
		_check("authored action and runtime atlas "+id,not row.is_empty() and app.database.assets.animations.has(str(row.get("animation",""))),row.get("source_parent",-1))
	for id: String in ["jump","d_follow","skill_w","skill_t","skill_q","skill_r","r_catch1","r_catch2","skill_v"]:
		_check("authored component authoritative reference "+id,not definition.actions[id].get("component_data",{}).is_empty())

func _test_default_entries() -> void:
	for entry: Array in ENTRY_CASES:
		var battle := _fresh()
		var before_mp: float = battle.player.mp
		var before_cubes: int = battle.session.profile.progress.clear_cubes
		_key(battle,entry[0])
		_check("key enters default "+str(entry[1]),battle.player.state==entry[1] and battle.player.parent_frame==entry[2],_snapshot(battle))
		_check("source MP/cube consumption "+str(entry[1]),absf((before_mp-battle.player.mp)-float(entry[3]))<=.051 and before_cubes-int(battle.session.profile.progress.clear_cubes)==int(entry[4]),_snapshot(battle))
		if entry[1]=="skill_w":_key(battle,KEY_C)
		_check("default action returns "+str(entry[1]),_wait_idle(battle),_snapshot(battle))
		traces.append({"case":"default_"+str(entry[1]),"end":_snapshot(battle)})

func _test_basic_air_and_backstep() -> void:
	var battle := _fresh()
	_key(battle,KEY_X)
	var sequence := [["basic",10,"basic2"],["basic2",5,"basic3"],["basic3",5,"basic4"],["basic4",5,"basic5"]]
	for part: Array in sequence:
		var reached := _wait_frame(battle,part[0],part[1])
		_check("X reaches combo input window "+str(part[0]),reached,_snapshot(battle))
		if not reached:break
		_key(battle,KEY_X,true)
		_check("repeated keyDown enters "+str(part[2]),battle.player.state==part[2],_snapshot(battle))
	_check("X full default chain ends",_wait_idle(battle),_snapshot(battle))
	battle = _fresh()
	Input.action_press("move_right")
	_tick(battle,3)
	_check("held direction uses CRT1 move31",battle.player.state=="move" and battle.player.parent_frame==31 and battle.player.facing==1)
	_key(battle,KEY_Z)
	traces.append({"case":"move_Z_priority_current_runtime_not_original_dynamic_oracle","after_key":_snapshot(battle)})
	_check("move Z resolves a supported source branch",battle.player.state in ["move_z","skill_z"],_snapshot(battle))
	_release()
	_check("move-Z branch returns",_wait_idle(battle),_snapshot(battle))
	battle = _fresh()
	var x: float = battle.player.position.x
	_key(battle,KEY_DOWN)
	_check("Down enters parent43",battle.player.parent_frame==43)
	_check("Down returns and moves backwards",_wait_idle(battle,30) and battle.player.position.x<x,_snapshot(battle))
	battle = _fresh()
	_key(battle,KEY_C)
	_check("C enters parent96",battle.player.parent_frame==96)
	_check("C reaches independent air overlay",_wait_frame(battle,"jump",15,30),_snapshot(battle))
	Input.action_press("attack")
	var projectile_seen := false
	for n in range(14):
		_tick(battle)
		projectile_seen = projectile_seen or not battle.projectiles.is_empty()
	_release()
	_check("held air X emits actual projectile",projectile_seen,_snapshot(battle))
	_check("C and airX end normally",_wait_idle(battle,60),_snapshot(battle))

func _test_rejections_and_reactions() -> void:
	var battle := _fresh()
	battle.player.mp = 0 # explicit insufficient-MP fixture
	_key(battle,KEY_A)
	_check("A rejects insufficient MP without starting cooldown",battle.player.state=="idle" and int(battle.player.cooldowns.get("skill_a",0))==0,_snapshot(battle))
	battle = _fresh()
	battle.session.profile.progress.clear_cubes = 0
	var mp: float = battle.player.mp
	_key(battle,KEY_H)
	_check("H rejects missing cube without spending MP",battle.player.state=="idle" and is_equal_approx(battle.player.mp,mp),_snapshot(battle))
	battle = _fresh()
	_key(battle,KEY_A)
	_wait_idle(battle,30)
	_key(battle,KEY_A)
	_check("A rejects still-active cooldown",battle.player.state=="idle" and int(battle.player.cooldowns.skill_a)>0,_snapshot(battle))
	battle = _fresh()
	battle.player.receive_damage(1.0) # documented public damage-chain fixture
	_check("public damage enters CRT1 real hit44",battle.player.parent_frame==44 and battle.player.state=="hit")
	_key(battle,KEY_Z)
	_check("hurt Z enters revenger63",battle.player.parent_frame==63 and battle.player.state=="revenger",_snapshot(battle))
	_check("revenger returns",_wait_idle(battle,40),_snapshot(battle))
	battle = _fresh()
	battle.player.receive_damage(1000.0)
	_tick(battle,31)
	_check("lethal damage plays real death62/source30 hold",battle.player.state=="dead" and battle.player.parent_frame==62 and battle.player.source_frame==30,_snapshot(battle))

func _test_h_w_q_t_components() -> void:
	for spec: Array in [["move_right","h_forward",50],["move_left","h_back",51],["down","h_down",52],["aim_up","h_up",53]]:
		var battle := _fresh()
		_key(battle,KEY_H)
		Input.action_press(spec[0])
		_tick(battle,5)
		_check("H direction real held input "+str(spec[1]),battle.player.state==spec[1] and battle.player.parent_frame==spec[2],_snapshot(battle))
		_tick(battle,100)
		_release()
		_check("H finite chain count and exit "+str(spec[1]),int(battle.crt1.h_count)<=5 and _wait_idle(battle,80),_snapshot(battle))
	var battle := _fresh()
	_key(battle,KEY_W)
	var x: float = battle.player.position.x
	Input.action_press("move_right")
	Input.action_press("attack")
	var fired := false
	for n in range(12):
		_tick(battle)
		fired = fired or not battle.projectiles.is_empty()
	_release()
	_check("W independent shooting, ammo and movement",fired and int(battle.crt1.w_ammo_frame)>2 and battle.player.position.x>x,_snapshot(battle))
	var facing: int = battle.player.facing
	_key(battle,KEY_Z)
	_check("W Z reverses facing while retained",battle.player.state=="skill_w" and battle.player.facing==-facing,_snapshot(battle))
	_key(battle,KEY_C)
	_check("W C cancels cleanly to idle",battle.player.state=="idle",_snapshot(battle))
	battle = _fresh()
	_key(battle,KEY_Q)
	_tick(battle,25)
	_check("Q independent buff persists after cast",battle.player.state=="idle" and int(battle.crt1.buff_frame)>=9,_snapshot(battle))
	_tick(battle,410)
	_check("Q independent source timer ends",int(battle.crt1.buff_frame)==1,_snapshot(battle))
	battle = _fresh()
	_key(battle,KEY_T)
	var holds: Dictionary = {}
	var timer_seen := false
	for n in range(330):
		if battle.player.state!="skill_t":break
		if battle.player.source_frame in [25,43,66]:holds[battle.player.source_frame]=true;timer_seen=timer_seen or int(battle.crt1.t_timer)>1
		_tick(battle)
	_check("T visits three independently timed hold phases",holds.has(25) and holds.has(43) and holds.has(66) and timer_seen,holds)
	_check("T normal route ends and cooldown resumes",battle.player.state=="idle" and bool(battle.crt1.t_slot_playing),_snapshot(battle))

func _test_damage_and_cleanup() -> void:
	for stage_id: String in ["","root_6","root_9"]:
		var battle := _fresh(stage_id)
		var target: Node2D = battle.enemies[0]
		# One-time contact seed. No marker/g/gacc, hit result or HP is rewritten
		# during execution; other enemies stay isolated above the playfield.
		target.position = Vector2(battle.player.position.x+70,battle.player.position.y+36)
		target.hp = 2000.0 #1e22 training HP cannot numerically represent a50-point change.
		var before: float = target.hp
		_key(battle,KEY_F)
		_tick(battle,60)
		_check("CRT1 F damages selected enemy "+str(target.definition.get("source_id",target.identifier)),target.hp<before,{"before":before,"after":target.hp,"stage":stage_id,"snapshot":_snapshot(battle)})
	var battle := _fresh()
	_key(battle,KEY_Q)
	_tick(battle,25)
	_key(battle,KEY_R)
	_tick(battle,4)
	var old: Node = battle
	var old_views: Array = battle._crt1_views.values().duplicate()
	var replacement := _fresh()
	_check("reentry removes previous battle and resets CRT1 clocks",old.is_queued_for_deletion() and replacement!=old and int(replacement.crt1.buff_frame)==1 and int(replacement.crt1.w_ammo_frame)==1 and replacement._gunhawks.is_empty() and replacement.projectiles.is_empty(),_snapshot(replacement))
	traces.append({"case":"exit_cleanup","old_independent_view_count":old_views.size(),"replacement":_snapshot(replacement)})

func _test_contact_and_gunhawk_routes() -> void:
	var battle := _fresh()
	var target: Node2D = battle.enemies[0]
	target.position = battle.player.position+Vector2(25,36) # one-time contact fixture
	_key(battle,KEY_D)
	var contact := _wait_frame(battle,"skill",12,20)
	_check("D real contact enters follow-enabled source segment",contact,_snapshot(battle))
	if contact:
		_key(battle,KEY_Z)
		_check("D plus Z enters parent47 follow",battle.player.state=="d_follow" and battle.player.parent_frame==47,_snapshot(battle))
		Input.action_press("attack")
		_tick(battle,15)
		_release()
		_check("D follow and air body return",_wait_idle(battle,80),_snapshot(battle))
	battle = _fresh()
	target = battle.enemies[0]
	target.position = battle.player.position+Vector2(40,36)
	_key(battle,KEY_V)
	var grabbed := _wait_frame(battle,"skill_v",15,35)
	_check("V real contact enters long grab route",grabbed,_snapshot(battle))
	if grabbed:_check("V grab releases and exits",_wait_idle(battle,100) and battle.pren==0,_snapshot(battle))
	battle = _fresh()
	_key(battle,KEY_R)
	for stage in [1,2]:
		# Source6763 returns at approximately+174 localx, so the player must
		# actually walk to its pickup area. Standing at the throw origin is not
		# a source promise of automatic catch (run01's wrong test assumption).
		Input.action_press("move_right")
		var caught := false
		for n in range(80):
			if battle.player.state=="r_catch%d"%stage:caught=true;break
			if battle.ended:break
			_tick(battle)
		_release()
		_check("gunhawk held movement reaches catch%d"%stage,caught,_snapshot(battle))
		if not caught:break
		_wait_frame(battle,"r_catch%d"%stage,5,15)
		_key(battle,KEY_X)
		_check("catch%d X continues throwing segment"%stage,battle.player.state=="r_catch%d"%stage and battle.player.source_frame>=26,_snapshot(battle))
	_tick(battle,100)
	_check("gunhawk lifecycle returns and removes root objects",battle.player.state=="idle" and battle._gunhawks.is_empty(),_snapshot(battle))

func _test_shot_and_cutin_visual_lifecycles() -> void:
	var battle := _fresh()
	var target: Node2D = battle.enemies[0]
	target.position = battle.player.position+Vector2(70,36)
	target.hp = 2000.0 # one-time finite HP/contact seed; actual F must create shot.
	_key(battle,KEY_F)
	var frames: Array[int] = []
	var shot_view: Node2D
	for n in range(70):
		var shot: Dictionary = battle._crt1_shots.get(target.identifier,{})
		if not shot.is_empty():
			shot_view = shot.visual
			if frames.is_empty() or frames.back()!=shot_view.source_frame:frames.append(shot_view.source_frame)
		_tick(battle)
	_check("real F creates shot visible source1,2,3 and empty source4",frames==[1,2,3,4],frames)
	_check("shot clip is removed at air lifecycle end",battle._crt1_shots.is_empty() and is_instance_valid(shot_view) and shot_view.is_queued_for_deletion(),_snapshot(battle))
	traces.append({"case":"F shot SourceSprite lifecycle","frames":frames,"end":_snapshot(battle)})
	battle = _fresh()
	_key(battle,KEY_T)
	var cutin_frames: Array[int] = []
	var cutin: Node2D
	for n in range(40):
		if battle._crt1_views.has("awakening_cutin"):
			cutin = battle._crt1_views.awakening_cutin
			cutin_frames.append(cutin.source_frame)
		_tick(battle)
	_check("T cutin uses actual independent SourceSprite34 through64",not cutin_frames.is_empty() and cutin_frames.front()==34 and cutin_frames.back()==64 and cutin_frames.size()==31,cutin_frames)
	_check("T cutin source65 removes visual",not battle._crt1_views.has("awakening_cutin") and is_instance_valid(cutin) and cutin.is_queued_for_deletion())
	battle = _fresh()
	_key(battle,KEY_T)
	_tick(battle,3)
	var old: Node2D = battle
	var old_cutin: Node2D = battle._crt1_views.get("awakening_cutin")
	var replacement := _fresh()
	_check("reentry tears down active cutin with old battle",is_instance_valid(old_cutin) and old.is_queued_for_deletion() and old.is_ancestor_of(old_cutin) and replacement._crt1_views.is_empty() and replacement._crt1_shots.is_empty(),_snapshot(replacement))

func _test_t_legal_kill_release() -> void:
	var battle := _fresh("root_9")
	var target: Node2D = battle.enemies[0]
	# One-time vulnerable target seed, followed exclusively by legal KEY_T and
	# the production combat chain. No HP0, death lock, marker or action is set.
	target.position = battle.player.position+Vector2(70,36)
	target.hp = 1.0
	var initial_count: int = battle.session.run.enemies_remaining
	var before_mp: float = battle.player.mp
	var before_cubes: int = battle.session.profile.progress.clear_cubes
	battle.trace_enabled = true
	_key(battle,KEY_T)
	_check("legal ready T spends30MP and5cubes",battle.player.state=="skill_t" and absf(before_mp-battle.player.mp-30.0)<=.051 and before_cubes-int(battle.session.profile.progress.clear_cubes)==5,_snapshot(battle))
	var empty_hurt: Rect2 = battle.player.hurt_rect()
	var enclosing := Rect2(empty_hurt.position-Vector2(10,10),Vector2(20,20))
	_check("missing T body is empty and cannot collide as an interior point",not empty_hurt.has_area() and not battle._overlaps(enclosing,empty_hurt) and not battle._overlaps(empty_hurt,enclosing),{"body":empty_hurt,"positive_rect":enclosing})
	var samples: Array = []
	var source_frames: Array[int] = []
	var locked_seen := false
	var retained_before_release := true
	var released_at_111 := false
	var jump_93_to_97 := false
	var previous_frame := 0
	for n in range(350):
		var frame: int = battle.player.source_frame
		if battle.player.state=="skill_t":
			if source_frames.is_empty() or source_frames.back()!=frame:source_frames.append(frame)
			if previous_frame==93 and frame==97:jump_93_to_97=true
			previous_frame=frame
		if target.source_death_locked:locked_seen=true
		if locked_seen and battle.player.state=="skill_t" and frame<111:
			retained_before_release=retained_before_release and target.source_death_locked and int(battle.session.run.enemies_remaining)==initial_count and not battle.ended
		if battle.player.state=="skill_t" and frame==111:released_at_111=not target.source_death_locked
		samples.append({"tick":battle.session.run.source_ticks,"action":battle.player.state,"frame":frame,"hp":target.hp,"enemy_action":target.state,"enemy_frame":target.source_frame,"airborne":target.airborne,"lock":target.source_death_locked,"remaining":battle.session.run.enemies_remaining,"ended":battle.ended})
		if battle.ended:break
		_tick(battle)
	_check("T actual lethal contact establishes per-enemy death lock",locked_seen and target.hp<=0,{"hp":target.hp,"frames":source_frames})
	_check("T source94 control selects kill branch97",jump_93_to_97 and source_frames.has(97) and not source_frames.has(95),source_frames)
	_check("T retains enemy count until source111",locked_seen and retained_before_release,{"initial_count":initial_count,"samples":samples})
	_check("T source111 releases the locked instance",released_at_111,{"lock":target.source_death_locked,"frames":source_frames})
	var settlements: Array = battle.trace_events.filter(func(row:Dictionary)->bool:return row.event=="enemy_settled")
	_check("T release causes one death and one battle settlement",battle.ended and int(battle.session.run.enemies_remaining)==initial_count-1 and settlements.size()==1 and target._dead_emitted,{"screen":app.screen,"settlements":settlements,"snapshot":_snapshot(battle)})
	var after_count: int = battle.session.run.enemies_remaining
	_tick(battle,12)
	_check("completed T cannot settle enemy twice",int(battle.session.run.enemies_remaining)==after_count and battle.trace_events.filter(func(row:Dictionary)->bool:return row.event=="enemy_settled").size()==1)
	traces.append({"case":"legal T lowHP root9 kill branch","fixture":{"hp":1,"offset":[70,36],"input":"KEY_T","source94_control":"Processed inside same tick, rendered93 transitions to97","run07_regression":"Original close-contact seed restored after shared empty-body collision fix; no forced hit/death/lock"},"samples":samples,"events":battle.trace_events.duplicate(true)})

func _test_crt0_root9_natural_knockdown() -> void:
	_release()
	app.action_lab=false
	app.session.profile=app.saves.default_profile()
	app.session.select_character("crt_0")
	app.session.select_difficulty("expert")
	app._on_intent("select_training_character","crt_0")
	app.enter_battle("root_9")
	var battle: Node2D = app.battle
	battle.manual_clock=true
	battle.set_physics_process(false)
	# Original ranged trigger is x[-244.25,-213.25], y[-47,-16] from enemy.
	# Seed positions only; AI chooses ranged itself, no action/seek/hit is forced.
	battle.player.position=Vector2(150,315)
	battle.enemies[0].position=Vector2(380,351)
	var terminal: Dictionary = {}
	battle.player.action_finished.connect(func(actor:Node2D,action:String)->void:
		if action=="knockdown":terminal.merge({"parent":actor.parent_frame,"frame":actor.source_frame,"tick":battle.session.run.source_ticks}))
	var ranged_seen := false
	var knockdown_seen := false
	var returned := false
	var samples: Array = []
	for n in range(110):
		# Move toward the already-triggered ranged animation for12 ticks, then
		# release. Standing still is pushed out of its final63..65 window.
		if n==1:Input.action_press("move_right")
		if n==13:_release()
		_tick(battle)
		ranged_seen=ranged_seen or battle.enemies[0].state=="ranged"
		knockdown_seen=knockdown_seen or (battle.player.state=="knockdown" and battle.player.parent_frame==15)
		samples.append({"tick":battle.session.run.source_ticks,"player":battle.player.state,"parent":battle.player.parent_frame,"frame":battle.player.source_frame,"enemy":battle.enemies[0].state,"enemy_frame":battle.enemies[0].source_frame,"hp":battle.player.hp})
		if knockdown_seen and battle.player.state=="idle":returned=true;break
	_check("root9 AI naturally selects ranged and contacts CRT0 knockdown15",ranged_seen and knockdown_seen,samples)
	_check("CRT0 knockdown source30 control returns idle",returned and int(terminal.get("parent",-1))==15 and int(terminal.get("frame",-1))==30,terminal)
	_check("root9 knockdown actual source3 observer damages player",knockdown_seen and battle.player.hp<100 and battle.player.hp>0,_snapshot(battle))
	_release()
	traces.append({"case":"CRT0 root9 natural AI knockdown","fixture":{"player":[150,315],"enemy":[380,351],"forced_actions":false,"input":"held right ticks2..13 then release"},"samples":samples,"terminal_signal":terminal})

func _run() -> void:
	if "--test-mode" not in OS.get_cmdline_user_args():
		push_error("必须 --test-mode，拒绝使用正式存档")
		quit(2)
		return
	formal_exists = FileAccess.file_exists("user://profile.json")
	if formal_exists:formal_hash=FileAccess.get_sha256("user://profile.json")
	for directory: String in ["res://content/actions/crt1","res://content/components/crt1"]:
		for file: String in DirAccess.get_files_at(directory):
			if file.ends_with(".tres"):author_hashes[directory.path_join(file)]=FileAccess.get_sha256(directory.path_join(file))
	app = MainScene.instantiate()
	root.add_child(app)
	app.set_process(false)
	_check("actual Main boots with CRT1 author content",app.startup_ok and app.test_mode and app.database.characters.has("crt_1"),app.database.issues)
	if app.startup_ok:
		app.saves = Save.new("user://act03_crt1/run_%d_%d/profile.json"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()])
		_authored_contract()
		_test_default_entries()
		_test_basic_air_and_backstep()
		_test_rejections_and_reactions()
		_test_h_w_q_t_components()
		_test_contact_and_gunhawk_routes()
		_test_damage_and_cleanup()
		_test_shot_and_cutin_visual_lifecycles()
		_test_t_legal_kill_release()
		_test_crt0_root9_natural_knockdown()
		for key: String in CHILD_AUDIO:_check("real child-clock AudioPool stream/playback "+key,child_audio_seen.has(key),child_audio_seen.get(key,{}))
		traces.append({"case":"real Dummy child audio playback observations","streams":child_audio_seen.duplicate(true)})
	_release()
	_check("formal save remains byte-identical",FileAccess.file_exists("user://profile.json")==formal_exists and (not formal_exists or FileAccess.get_sha256("user://profile.json")==formal_hash))
	var unchanged := true
	for path: String in author_hashes:unchanged=unchanged and FileAccess.get_sha256(path)==author_hashes[path]
	_check("runtime preserves authored action/component files",unchanged)
	app._dispose_battle()
	var drained: bool = await app.audio.stop_and_drain(1.0)
	_check("Dummy playback references drain",drained and app.audio.snapshot().pending_playbacks==0)
	app.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	var failures: int = checks.filter(func(row:Dictionary)->bool:return not row.passed).size()
	var output := OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if output.is_empty():output="res://artifacts/leba_act03_20261116/crt1"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var file := FileAccess.open(output.path_join("act03_crt1_tests.json"),FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify({"suite":"ACT03 CRT1 functional input","checks":checks,"failures":failures,"traces":traces,"godot":Engine.get_version_info(),"scope":"Actual Main normal entry/InputEventKey + shared clock, isolated deterministic source-derived fixtures; no exact original HP oracle.","not_tested":["physical OS keyboard","native Adobe Flash/Ruffle CRT1 oracle","all34 actions through natural enemy contact","D/V exact marker damage phases","GPU alignment and audible listening","original defaultZ/moveZ callback priority"]},"\t")+"\n")
		file.close()
	print("ACT03_CRT1_TESTS_RESULT "+JSON.stringify({"checks":checks.size(),"failures":failures}))
	quit(0 if failures==0 else 1)
