extends "res://tests/test_act05_crt3_actions.gd"
## Independent CRT4 world-chain suite. Normal Main/input and real source clocks.
## No action/object/marker/timer/flag injection. Resource/initial-space fixtures
## are explicitly recorded; local observer amounts are never whole-skill HP.
const EXPECTED := "res://tests/fixtures/act06_crt4_world_expected.json"
const FIELD_KEYS := {"d":KEY_D,"f":KEY_F,"g":KEY_G,"h":KEY_H}
var expected: Dictionary={}
var output := ""
var world_samples: Array[Dictionary]=[]
var world_events: Array[Dictionary]=[]
var seen_journal: Dictionary={}
var fixtures: Array[Dictionary]=[]
var source_hashes: Dictionary={}
var y_hold_samples: Dictionary={}
var visual_source_ids_by_texture: Dictionary={}

func _visual_source_id(sprite: Node2D) -> int:
	# SourceAnimation.to_runtime intentionally only supplies drawing data. Resolve
	# provenance through the actually consumed texture path, never its filename.
	if visual_source_ids_by_texture.is_empty():
		var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_catalog.json"))
		for animation: Dictionary in catalog.animations.values():
			var path:=str(animation.texture);var sid:=int(animation.get("source_sprite_id",0))
			if not visual_source_ids_by_texture.has(path):visual_source_ids_by_texture[path]=[]
			if sid>0 and sid not in visual_source_ids_by_texture[path]:visual_source_ids_by_texture[path].append(sid)
	var identities: Array=visual_source_ids_by_texture.get(str(sprite.definition.get("texture","")),[])
	return int(identities[0]) if identities.size()==1 else 0

func _check(label: String,passed: bool,detail: Variant="") -> void:
	checks.append({"name":label,"passed":passed,"detail":detail,"case":current_case})
	print(("PASS " if passed else "FAIL ")+label+(" "+str(detail) if not passed else ""))

func _integrity() -> Dictionary:
	var result: Dictionary={}
	for folder: String in ["res://content/actions/crt4","res://content/components/crt4"]:
		for file: String in DirAccess.get_files_at(folder):
			if file.ends_with(".tres"):result[folder.path_join(file)]=FileAccess.get_sha256(folder.path_join(file))
	for path: String in ["res://content/characters/crt_4.tres","res://content/index.tres","res://scenes/actors/crt4.tscn","res://scripts/main.gd","res://scripts/combat/battle.gd","res://scripts/combat/combatant.gd","res://scripts/services/audio_director.gd","res://data/asset_catalog.json",EXPECTED]:
		result[path]=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "MISSING"
	return result

func _objects(battle: Node2D,source_id: int=-1) -> Array:
	var result: Array=[]
	for item: Dictionary in battle._crt4_objects:
		if source_id<0 or int(item.get("source_id",-1))==source_id:result.append(item)
	return result

func _object(battle: Node2D,source_id: int) -> Dictionary:
	var rows:=_objects(battle,source_id)
	return rows.back() if not rows.is_empty() else {}

func _flag(battle: Node2D,source_id: int) -> bool:
	return bool(battle.crt4.get("fields",{}).get(str(source_id),false))

func _visual_liveness_issue(value: Variant) -> String:
	if not is_instance_valid(value):return "freed or missing instance"
	if not value is Node2D:return "not a Node2D drawing/root"
	var node: Node=value
	if not node.is_inside_tree():return "detached drawing/root"
	while node!=null:
		if node.is_queued_for_deletion():return "pending-deletion ancestor: "+str(node.name)
		node=node.get_parent()
	return ""

func _snapshot(battle: Node2D) -> Dictionary:
	var objects: Array=[]
	for item: Dictionary in _objects(battle):
		var row: Dictionary={}
		for key: String in ["source_id","id","born","frame","age","position","scale","depth","source_parent","parent_id","source_depth"]:
			if item.has(key):row[key]=item[key]
		var value: Variant=item.get("visual")
		var issue:=_visual_liveness_issue(value)
		if issue.is_empty():
			var view: Node2D=value
			row["visible"]=view.is_visible_in_tree()
			row["root_transform"]=view.global_transform
		else:
			row["invalid_visual"]=issue
			_check("live CRT4 object must retain a live root",false,{"tick":battle.session.run.source_ticks,"source_id":item.get("source_id"),"id":item.get("id"),"issue":issue})
		objects.append(row)
	var drawings: Array=[]
	for key: String in battle._crt4_views:
		# Validate the Variant before any typed assignment. Invalid references are
		# explicit failures, never silently skipped as if the drawing were absent.
		var value: Variant=battle._crt4_views[key]
		var issue:=_visual_liveness_issue(value)
		if not issue.is_empty():
			_check("registered CRT4 drawing must remain live",false,{"tick":battle.session.run.source_ticks,"key":key,"issue":issue})
			drawings.append({"key":key,"invalid_visual":issue,"source_id":0,"frame":0})
			continue
		var sprite: Node2D=value
		if not sprite.is_visible_in_tree():continue
		drawings.append({"key":key,"id":sprite.get_instance_id(),"source_id":_visual_source_id(sprite),"frame":sprite.source_frame,"texture":sprite.definition.get("texture",""),"alpha_bounds":sprite.frame.get("alpha_bounds",[]),"transform":sprite.global_transform})
	var targets: Array=[]
	for target: Node2D in battle.enemies:
		targets.append({"id":target.identifier,"hp":target.hp,"position":target.position,"hurt_rect":target.hurt_rect(),"airborne":target.airborne,"frozen":target.frozen,"frame":target.source_frame,"gravity":target.vertical_speed,"gacc":target.gravity_acceleration})
	var state: Dictionary={}
	for key: String in ["fields","kaz","bremen","saya","rhasa","ghost_frame","ghost_born","ghost_timer","kalla_frame","kalla_born","kalla_timer","ghost_step","kalla","y_slot_frame","y_slot_playing","air_frame","back_frame","ghost_type"]:
		state[key]=battle.crt4.get(key)
	state=state.duplicate(true) # Historical flags must not alias the live Runtime dictionary.
	var bleeds: Dictionary={}
	for target_id: String in battle._crt4_bleeds:
		bleeds[target_id]=_bleed_clock(battle,target_id)
	return {"case":current_case,"tick":battle.session.run.source_ticks,"ms":battle.real_time_ms,"state":battle.player.state,"frame":battle.player.source_frame,"source_id":int(battle.player.definition.actions.get(battle.player.state,{}).get("source_id",0)),"parent":battle.player.parent_frame,"position":battle.player.position,"facing":battle.player.facing,"hp":battle.player.hp,"mp":battle.player.mp,"cubes":battle.session.profile.progress.clear_cubes,"body":battle.player.hurt_rect(),"crt4":state,"objects":objects,"drawings":drawings,"targets":targets,"bleeds":bleeds,"combo":battle.combo,"ended":battle.ended}

func _bleed_clock(battle: Node2D,target_id: String) -> Dictionary:
	var result: Dictionary={}
	var live: Dictionary=battle._crt4_bleeds.get(target_id,{})
	for field: String in ["born","helper_born","slow_born","frame","helper","slow"]:
		if live.has(field):result[field]=live[field]
	return result

func _collect(battle: Node2D) -> void:
	var counts: Dictionary={}
	for original: Dictionary in battle.journal:
		if not str(original.event).begins_with("crt4_") and not (original.event=="damage" and str(original.get("source","")).begins_with("CRT4 ")):continue
		var key:=JSON.stringify(original)
		counts[key]=int(counts.get(key,0))+1
		if int(counts[key])<=int(seen_journal.get(key,0)):continue
		seen_journal[key]=int(counts[key])
		var row: Dictionary=original.duplicate(true);row["case"]=current_case
		world_events.append(row)
	world_samples.append(_snapshot(battle))

func _tick(battle: Node2D,count:=1) -> void:
	for n in range(count):battle.step(battle.take_commands());_collect(battle)

func _ms(battle: Node2D,delta: float) -> void:
	battle.advance_real_time(delta);_collect(battle)

func _events(name: String,source_id: int=-1) -> Array:
	return world_events.filter(func(row: Dictionary)->bool:return row.case==current_case and row.event==name and (source_id<0 or int(row.get("source_id",-1))==source_id))

func _local_observers(source_id: int,helper: int=-1) -> Array:
	return _events("crt4_helper_observer",source_id).filter(func(row: Dictionary)->bool:return helper<0 or int(row.get("helper",-1))==helper)

func _local_samples() -> Array:
	return world_samples.filter(func(row: Dictionary)->bool:return row.case==current_case)

func _seen_frame(source_id: int,frame: int) -> bool:
	if _local_samples().any(func(row: Dictionary)->bool:return (row.objects+row.drawings).any(func(item: Dictionary)->bool:return int(item.source_id)==source_id and int(item.frame)==frame)):return true
	return _events("crt4_world_retired",source_id).any(func(row: Dictionary)->bool:return int(row.get("frame",-1))==frame)

func _on_sound(alias: String,stream: AudioStream,offset: float,voice: AudioStreamPlayer) -> void:
	var event: Dictionary=app.database.assets.audio_events.get(alias,{})
	var path:=stream.resource_path if stream!=null else ""
	sounds.append({"case":current_case,"alias":alias,"path":path,"sound_id":int(event.get("sound_id",path.get_file().get_basename().to_int())),"source_id":int(event.get("sprite_id",0)),"offset":offset,"length":stream.get_length() if stream!=null else 0.0,"tick":app.session.run.get("source_ticks",-1),"valid":stream!=null and is_instance_valid(voice) and voice.stream==stream and voice.playing and voice.has_stream_playback()})

func _sounds_for(source_id: int,sound_id: int=-1) -> Array:
	return sounds.filter(func(row:Dictionary)->bool:return row.case==current_case and int(row.source_id)==source_id and (sound_id<0 or int(row.sound_id)==sound_id))

func _sound_requirements(source_id: int,exact_count: int=-1) -> void:
	for event: Dictionary in expected.local_start_sounds:
		if int(event.owner_source_id)!=source_id:continue
		var matches:=_sounds_for(source_id,int(event.sound_id))
		var offset:=float(event.sound_info.get("inPoint",0))/44100.0
		_check("source%d Sound%d reaches real AudioDirector stream/offset"%[source_id,int(event.sound_id)],not matches.is_empty() and matches.all(func(row:Dictionary)->bool:return row.valid and is_equal_approx(float(row.offset),offset)),matches)
		if exact_count>=0:_check("source%d Sound%d has original per-instance play count"%[source_id,int(event.sound_id)],matches.size()==exact_count,matches)

func _complete_exit_frame() -> void:
	# process_frame is emitted before the native frame tail. Reaching that signal
	# once is not proof deferred frees/audio mix retirement have actually passed.
	var before:=Engine.get_process_frames()
	for attempt in range(4):
		if Engine.get_process_frames()>before:break
		await process_frame
	_check("disposed encounter crosses a real engine frame boundary",Engine.get_process_frames()>before,{"before":before,"after":Engine.get_process_frames()})

func _world_fresh(label: String,facing:=1,stage:="root_41") -> Node2D:
	current_case=label+"_"+("right" if facing==1 else "left")
	_release();seen_journal={};notices.clear()
	app.action_lab=false;app.session.profile=app.saves.default_profile();app.show_title()
	var start: BaseButton=app.ui.get_button("Training")
	_check("normal title Training entry exists",start!=null)
	if start==null:return null
	start.pressed.emit()
	var selector: BaseButton=app.ui.get_button("Character_crt_4")
	_check("normal training offers real CRT4",selector!=null)
	if selector==null:return null
	selector.pressed.emit()
	if stage!="root_41":app.enter_battle(stage)
	var battle: Node2D=app.battle
	battle.manual_clock=true;battle.set_physics_process(false)
	battle.feedback.connect(func(message:String)->void:notices.append(message))
	for target: Node2D in battle.enemies:target.position=Vector2(520,-1000)
	_tick(battle,2)
	_move_to(battle,260)
	Input.action_press("move_right" if facing==1 else "move_left");_tick(battle);_release();_tick(battle)
	_check("real CRT4 parent and direction after normal entry",int(battle.player.definition.source_crt)==4 and battle.player.parent_frame==146 and battle.player.facing==facing,_snapshot(battle))
	return battle

func _move_to(battle: Node2D,x: float) -> void:
	Input.action_press("move_right" if battle.player.position.x<x else "move_left")
	for n in range(100):
		if absf(battle.player.position.x-x)<=12:break
		_tick(battle)
	_release();_tick(battle)

func _target_fixture(battle: Node2D,relative_x: float=45.0,hp:=5000.0,all_targets:=false) -> void:
	for i in range(battle.enemies.size() if all_targets else 1):
		var target: Node2D=battle.enemies[i]
		target.hp=hp
		target.position=battle.player.position+Vector2((relative_x+8*i)*battle.player.facing,46)
	fixtures.append({"case":current_case,"tick":battle.session.run.source_ticks,"kind":"one initial finite HP/relative space fixture; subsequent AI/physics live","relative_x":relative_x,"hp":hp,"all_targets":all_targets})

func _cast(battle: Node2D,code: int,action: String,hold:=false) -> bool:
	var mp: float=battle.player.mp;var cubes: int=battle.session.profile.progress.clear_cubes
	_down(battle,code)
	if not hold:_up(battle,code)
	var key: String=char(code).to_lower()
	var spec: Dictionary=expected.slots.get(key,{})
	_check("actual key starts "+action,battle.player.state==action,_snapshot(battle))
	if not spec.is_empty():
		_check("accepted transaction has source MP/cubes "+action,is_equal_approx(battle.player.mp,minf(float(battle.player.definition.max_mp),mp-float(spec.mp)+.05)) and cubes-int(battle.session.profile.progress.clear_cubes)==int(spec.cubes),_snapshot(battle))
	return battle.player.state==action

func _wait_object(battle: Node2D,source_id: int,cap:=120) -> bool:
	var ok:=_until(battle,func()->bool:return not _object(battle,source_id).is_empty(),cap)
	_check("actual source chain creates"+str(source_id),ok,_snapshot(battle))
	return ok

func _source_contract() -> void:
	var definition: Dictionary=app.database.characters.crt_4
	for key: String in expected.actions:
		var row: Dictionary=definition.actions.get(key,{})
		_check("formal authored world action "+key,not row.is_empty() and int(row.get("source_parent",-1))==int(expected.actions[key].parent_frame))
	for key: String in expected.slots:
		var row: Dictionary=definition.actions.get("skill_"+key,{})
		_check("author source fee "+key,float(row.get("cost",-1))==float(expected.slots[key].mp) and int(row.get("cubes",-1))==int(expected.slots[key].cubes))
	_check("production visuals component supplies source sounds and geometry",definition.components.has("visuals") and definition.components.visuals.has("sounds") and definition.components.visuals.has("geometry"),definition.components.keys())

func _field_lifecycle(key: String,facing: int) -> void:
	var battle:=_world_fresh("field_"+key+"_empty_lifecycle",facing)
	if battle==null:return
	var spec: Dictionary=expected.fields[key];var sid:=int(spec.source_id)
	var hp: float=battle.enemies[0].hp
	if not _cast(battle,FIELD_KEYS[key],"skill_"+key):return
	if not _wait_object(battle,sid,20):return
	var item:=_object(battle,sid);var at: Vector2=battle.player.position+Vector2(100*facing,0)
	_check("field birth is source7 and original world offset",battle.player.source_frame==7 and (item.position as Vector2).is_equal_approx(at),item)
	_check("field main returns but independent object persists",_idle(battle,30) and not _object(battle,sid).is_empty())
	_check("field original active flag occurs",_until(battle,func()->bool:return _flag(battle,sid),20))
	_check("field flag expires at its own source end",_until(battle,func()->bool:return not _flag(battle,sid),int(spec.flag_off_and_stop_frame)+5))
	_check("field source terminal frame observed independently",_seen_frame(sid,int(spec.flag_off_and_stop_frame)))
	_check("empty field cannot fabricate target damage",battle.enemies[0].hp==hp and _local_observers(sid).is_empty(),_snapshot(battle))
	if key in ["g","h"]:
		var child:=int(spec.visible_inner_source)
		var loop_frames:=int(spec.visible_inner_loop_frames)
		var frames: Array=[]
		for row: Dictionary in _local_samples():
			for child_row: Dictionary in row.drawings:
				if int(child_row.source_id)==child:frames.append(int(child_row.frame))
		_check("field visible inner child loops through original length",frames.has(loop_frames) and frames.count(1)>1,frames)
	var before:=_local_observers(sid).size();_tick(battle,30)
	_check("expired source field contributes no new observers",_local_observers(sid).size()==before)
	_sound_requirements(sid,1)

func _field_contact(key: String,outside: bool) -> void:
	var battle:=_world_fresh("field_"+key+("_outside" if outside else "_inside"))
	if battle==null:return
	var spec: Dictionary=expected.fields[key];var sid:=int(spec.source_id)
	if outside:_move_to(battle,430)
	if not _cast(battle,FIELD_KEYS[key],"skill_"+key):return
	_idle(battle,30)
	if outside:_move_to(battle,30)
	_target_fixture(battle,45.0 if key in ["d","f"] else 100.0)
	if key in ["d","f"]:_tap(battle,KEY_X)
	_tick(battle,80 if key in ["d","f","g"] else 220)
	if key=="d":
		var contributions:=_local_observers(316,313)
		_check("Kazhan uses player-in-field gate",contributions.is_empty() if outside else not contributions.is_empty(),contributions)
	elif key=="f":
		var contributions:=_local_observers(956,954)
		_check("Bremen retains source global observer without range gate",not contributions.is_empty() and contributions.any(func(row: Dictionary)->bool:return float(row.amount)==21),contributions)
	elif key=="g":
		var hits:=_events("crt4_helper_contact",816).filter(func(row:Dictionary)->bool:return int(row.helper)==815 and row.kind=="freeze")
		var damage:=_events("damage").filter(func(row:Dictionary)->bool:return str(row.source)=="CRT4 freeze contact")
		_check("Saya original helper causes real freeze and direct30",not hits.is_empty() and not damage.is_empty() and damage.all(func(row:Dictionary)->bool:return float(row.amount)==30) and _local_samples().any(func(row:Dictionary)->bool:return row.targets[0].frozen),{"contacts":hits,"direct_damage":damage})
	elif key=="h":
		_check("Rhasa overlap creates actual independent978",not _events("crt4_world_born",978).is_empty(),_events("crt4_world_born",978))
	_check("actual contact reduces finite target HP",battle.enemies[0].hp<5000,_snapshot(battle))

func _ghostwalk() -> void:
	var battle:=_world_fresh("ghostwalk_body_clock")
	if battle==null or not _cast(battle,KEY_W,"skill_w"):return
	_check("W starts6360 from source2 at main7",_frame(battle,"skill_w",7,20) and int(battle.crt4.ghost_frame)==2,_snapshot(battle))
	_check("W flag turns on at6360/13",_until(battle,func()->bool:return int(battle.crt4.ghost_step)==1,30))
	_idle(battle,30)
	_check("original6359 timer starts under6360/18",_until(battle,func()->bool:return int(battle.crt4.get("ghost_timer",0))>0,25))
	var timer_born: int=battle.crt4.ghost_born;var start_frame:=int(battle.crt4.ghost_timer)
	Input.action_press("move_right")
	_check("real W walk temporarily removes source body",_until(battle,func()->bool:return not _body_nonempty(battle.player.hurt_rect()),12),_snapshot(battle))
	_check("6395 independent recovery restores original body",_until(battle,func()->bool:return _body_nonempty(battle.player.hurt_rect()),50),_snapshot(battle))
	_release();_tick(battle)
	_check("6359 timer remains same live instance through walking pages",int(battle.crt4.ghost_born)==timer_born and int(battle.crt4.get("ghost_timer",0))>start_frame,_snapshot(battle))
	var last_clock:=int(battle.crt4.get("ghost_timer",0))
	for n in range(570):
		if int(battle.crt4.ghost_step)==0:break
		last_clock=int(battle.crt4.get("ghost_timer",0));_tick(battle)
	_check("ghost state ends through independent545 clock",int(battle.crt4.ghost_step)==0 and last_clock+1==int(expected.ghostwalk.timer_terminal_frame),last_clock)
	_check("ghost timer exit restores6360/1 and body",int(battle.crt4.ghost_frame)==1 and _body_nonempty(battle.player.hurt_rect()),_snapshot(battle))

func _start_kalla(battle: Node2D) -> bool:
	if not _cast(battle,KEY_T,"skill_t"):return false
	_check("T turns on state at child6384/3",_until(battle,func()->bool:return int(battle.crt4.kalla)==1,25))
	_check("T main returns while state lives",_idle(battle,35) and int(battle.crt4.kalla)==1)
	var clock_running:=_until(battle,func()->bool:return int(battle.crt4.get("kalla_timer",0))>0,20)
	_check("actual6380 timer runs under held6384/12",clock_running,_snapshot(battle))
	return clock_running

func _kalla_clones(facing: int,contact: bool) -> void:
	var battle:=_world_fresh("kalla_clones_"+("contact" if contact else "empty"),facing)
	if battle==null or not _start_kalla(battle):return
	if contact:_target_fixture(battle,110)
	_tap(battle,KEY_X)
	_check("active Kalla X uses actual source166",battle.player.state=="kalla_basic" and battle.player.parent_frame==166,_snapshot(battle))
	if not _wait_object(battle,1326,15):return
	var birth:=_object(battle,1326);var id: Variant=birth.id;var at: Vector2=birth.position
	_check("ground clone is born from source6527/3",battle.player.source_frame==3 and at.is_equal_approx(battle.player.position),birth)
	_tick(battle,38)
	var rows: Array=[]
	for sample: Dictionary in _local_samples():
		for item: Dictionary in sample.objects:
			if item.id==id:rows.append(item)
	var moves: Array=[]
	for i in range(1,rows.size()):
		var delta: Vector2=(rows[i].position as Vector2)-(rows[i-1].position as Vector2)
		if not is_zero_approx(delta.x):moves.append(delta.x)
	_check("ground clone movement keeps source20 per actual callback",not moves.is_empty() and moves.all(func(dx: float)->bool:return is_equal_approx(dx,20.0*facing)),moves)
	_sound_requirements(1326,1)
	if not contact:_check("empty ground flight reaches page2 after27 moves",moves.size()==27 and rows.any(func(row: Dictionary)->bool:return int(row.frame)==2),rows)
	else:
		_check("real clone contact changes target HP and runs impact1153",battle.enemies[0].hp<5000 and _seen_frame(1153,1),_snapshot(battle))
		_tick(battle,145)
		var stack_damage:=_events("damage").filter(func(row:Dictionary)->bool:return row.source=="CRT4 Kalla layer 3968")
		_check("target Kalla stack settles by original independent clocks",not stack_damage.is_empty() and stack_damage.all(func(row:Dictionary)->bool:return float(row.amount)==27),stack_damage)
	_tap(battle,KEY_DOWN);_down(battle,KEY_X)
	_check("real back-X creates diagonal clone1154",_wait_object(battle,1154,20))
	_release();_tick(battle,55)
	_check("diagonal clone reaches actual impact page, not generic27 age",_seen_frame(1154,2),_snapshot(battle))
	_sound_requirements(1154,1)

func _kalla_second_t_and_timeout() -> void:
	var battle:=_world_fresh("kalla_second_T")
	if battle==null or not _start_kalla(battle):return
	var mp: float=battle.player.mp;var cubes: int=battle.session.profile.progress.clear_cubes
	_tap(battle,KEY_T)
	_check("second T enters source165 despite first slot cooldown",battle.player.state=="t_finish" and battle.player.parent_frame==165,_snapshot(battle))
	_check("second T pays only MP8 and no second cube cost",is_equal_approx(battle.player.mp,mp-8+.05) and int(battle.session.profile.progress.clear_cubes)==cubes)
	_check("default second T exits Kalla state and returns",_idle(battle,60) and int(battle.crt4.kalla)==0)
	battle=_world_fresh("kalla_natural574")
	if battle==null or not _start_kalla(battle):return
	var last_clock:=int(battle.crt4.get("kalla_timer",0))
	for n in range(590):
		if int(battle.crt4.kalla)==0:break
		last_clock=int(battle.crt4.get("kalla_timer",0));_tick(battle)
	_check("unconsumed Kalla expires through6380/574",int(battle.crt4.kalla)==0 and last_clock+1==int(expected.kalla.timer_terminal_frame),last_clock)

func _kalla_air_clone(facing: int) -> void:
	var battle:=_world_fresh("kalla_actual_C_held_X",facing)
	if battle==null or not _start_kalla(battle):return
	_tap(battle,KEY_C);_down(battle,KEY_X)
	_check("actual C enters source167 while X is held",battle.player.parent_frame==167,_snapshot(battle))
	if not _wait_object(battle,1154,35):_release();return
	var clone:=_object(battle,1154)
	_check("air Kalla clone uses source world offsetYminus40",(clone.position as Vector2).is_equal_approx(battle.player.position+Vector2(0,-40)),clone)
	_check("air Kalla clone keeps independent facing",is_equal_approx(float(clone.scale.x),float(facing)),clone)
	_release();_tick(battle,65)
	_check("air clone hits original ground and reaches impact page",_seen_frame(1154,2),_snapshot(battle))
	_check("air Kalla returns normally after source animation",_idle(battle,50) and battle.player.parent_frame==146,_snapshot(battle))
	_sound_requirements(1154)

func _target_layers(battle: Node2D,target: Node2D) -> Array:
	return _objects(battle).filter(func(item:Dictionary)->bool:return int(item.source_id) in [3968,3969,3970] and item.get("target")==target)

func _kalla_three_layers_rearm() -> void:
	var battle:=_world_fresh("kalla_three_layers_retire_and_rearm")
	if battle==null or not _start_kalla(battle):return
	_target_fixture(battle,110,30000)
	var target: Node2D=battle.enemies[0]
	var spec: Dictionary=expected.repeat_lifecycles.kalla
	# Repeat actual X only after the real action and enemy physics allow the next
	# ground contact. The initial space/HP fixture is never reapplied.
	for attempt in range(4):
		if _target_layers(battle,target).size()==int(spec.layers):break
		var ready:=_idle(battle,40) and _until(battle,func()->bool:return not target.airborne and not target.frozen,130)
		_check("repeat Kalla X waits for actual grounded contact opportunity",ready,_snapshot(battle))
		if not ready:break
		_tap(battle,KEY_X)
		_check("repeat actual X enters Kalla action166",battle.player.parent_frame==166,_snapshot(battle))
		_until(battle,func()->bool:return _target_layers(battle,target).size()==int(spec.layers) or (battle.player.state=="idle" and not target.airborne),140)
	var layers:=_target_layers(battle,target)
	var original_ids: Array=layers.map(func(item:Dictionary)->int:return int(item.id))
	_check("real repeated contacts populate three distinct source layers",layers.size()==int(spec.layers) and [3968,3969,3970].all(func(sid:int)->bool:return layers.any(func(item:Dictionary)->bool:return int(item.source_id)==sid)),_snapshot(battle))
	if layers.size()!=int(spec.layers):return
	var owners:=_objects(battle,3971).filter(func(item:Dictionary)->bool:return item.get("target")==target)
	_check("full stack uses original3971 selector4",owners.size()==1 and int(owners[0].frame)==int(spec.full_selector),_snapshot(battle))
	var isolated_combo_checks:=0
	for n in range(int(spec.terminal_frame)+5):
		if not _events("crt4_kalla_stack_reset").is_empty():break
		var combo_before: int=battle.combo
		_tick(battle)
		# The production journal is bounded; source-tick identity survives its
		# oldest-row retirement whereas an array length cursor would lose events.
		var fresh: Array=battle.journal.filter(func(row:Dictionary)->bool:return int(row.get("tick",-1))==int(battle.session.run.source_ticks))
		var contributions:=fresh.filter(func(row:Dictionary)->bool:return row.event=="damage" and str(row.get("source","")).begins_with("CRT4 Kalla layer "))
		# The source DoAction increments combo for every layer damage. Only test
		# exact deltas where no common marker hit ran in this same real tick.
		if not contributions.is_empty() and not fresh.any(func(row:Dictionary)->bool:return row.event=="hit_combo"):
			isolated_combo_checks+=1
			_check("independent Kalla damage advances original combo per event",int(battle.combo)==combo_before+contributions.size(),{"before":combo_before,"after":battle.combo,"damage_events":contributions})
	_check("real layer clocks produce observable combo events",isolated_combo_checks>0)
	var retired: Array=[]
	for sid: int in [3968,3969,3970]:
		retired.append_array(_events("crt4_world_retired",sid).filter(func(row:Dictionary)->bool:return int(row.get("id",-1)) in original_ids))
	_check("all three actual children retire at original136 together",retired.size()==int(spec.layers) and retired.all(func(row:Dictionary)->bool:return int(row.get("frame",-1))==int(spec.terminal_frame)) and retired.all(func(row:Dictionary)->bool:return int(row.tick)==int(retired[0].tick)),retired)
	owners=_objects(battle,3971).filter(func(item:Dictionary)->bool:return item.get("target")==target)
	_check("three terminal children restore selector1 and release stack capacity",_target_layers(battle,target).is_empty() and owners.size()==1 and int(owners[0].frame)==int(spec.reset_selector) and int(battle.crt4.get("kalla_layers_"+target.identifier,-1))==0,_snapshot(battle))
	var ready:=_idle(battle,40) and _until(battle,func()->bool:return not target.airborne and not target.frozen,130)
	_check("original Kalla still permits input after natural stack retirement",ready and int(battle.crt4.kalla)==1,_snapshot(battle))
	if not ready or int(battle.crt4.kalla)!=1:return
	_tap(battle,KEY_X)
	var rearmed:=_until(battle,func()->bool:return _target_layers(battle,target).any(func(item:Dictionary)->bool:return int(item.source_id)==3968 and int(item.id) not in original_ids),45)
	_check("new real X can create a new first layer after full retirement",rearmed,_snapshot(battle))
	_check("repeat chain keeps the finite target alive",target.hp>0 and target.hp<30000,_snapshot(battle))

func _mummy_repeat_refresh() -> void:
	var battle:=_world_fresh("same_H_second_mummy_refreshes_only_subclocks")
	if battle==null:return
	_target_fixture(battle,100,30000)
	var target: Node2D=battle.enemies[0]
	var spec: Dictionary=expected.repeat_lifecycles.mummy
	if not _cast(battle,KEY_H,"skill_h"):return
	var started:=_until(battle,func()->bool:return battle._crt4_bleeds.has(target.identifier),250)
	_check("real first mummy27 contact creates actual bleed",started,_snapshot(battle))
	if not started:return
	var first:=_bleed_clock(battle,target.identifier)
	var first_tick: int=battle.session.run.source_ticks
	var first_contacts:=_events("crt4_helper_contact",978).filter(func(row:Dictionary)->bool:return row.get("kind")=="mummy_follow_bleed" and row.get("target")==target.identifier)
	_check("first attachment is original source27 and not injected status",not first_contacts.is_empty() and first_contacts.all(func(row:Dictionary)->bool:return int(row.frame)==int(spec.attachment_frame)),first_contacts)
	var refreshed:=_until(battle,func()->bool:return int(_bleed_clock(battle,target.identifier).get("helper_born",-1))>int(first.helper_born),220)
	_check("second independently born mummy reaches same target naturally",refreshed,_snapshot(battle))
	if not refreshed:return
	var second:=_bleed_clock(battle,target.identifier)
	var elapsed:=int(battle.session.run.source_ticks)-first_tick
	var contacts:=_events("crt4_helper_contact",978).filter(func(row:Dictionary)->bool:return row.get("kind")=="mummy_follow_bleed" and row.get("target")==target.identifier)
	var instances: Array=[]
	for row: Dictionary in contacts:
		if row.get("instance") not in instances:instances.append(row.get("instance"))
	_check("repeat refresh comes from distinct real978 instances",instances.size()>=2,contacts)
	_check("repeat attachment preserves existing blood birth and phase",int(second.born)==int(first.born) and int(second.frame)==(int(first.frame)-1+elapsed)%int(spec.blood_loop_frames)+1,{"first":first,"second":second,"elapsed":elapsed})
	_check("repeat attachment independently seeks helper4003 and slow3966 to2",int(second.helper)==int(spec.seek_frame) and int(second.slow)==int(spec.seek_frame) and int(second.helper_born)==int(battle.session.run.source_ticks) and int(second.slow_born)==int(battle.session.run.source_ticks),second)
	_check("single H input remains one paid cast through repeated attachments",_events("crt4_world_born",1121).size()==1 and int(battle.session.profile.progress.clear_cubes)==199,_snapshot(battle))
	_tick(battle,3)
	var later:=_bleed_clock(battle,target.identifier)
	_check("retained blood continues independently after refreshed children",int(later.born)==int(first.born) and int(later.frame)==(int(second.frame)-1+3)%int(spec.blood_loop_frames)+1,later)

func _tombstones(facing: int,cancel: bool) -> void:
	var battle:=_world_fresh("R_"+("cancel" if cancel else "contact"),facing)
	if battle==null:return
	seed(60404+facing)
	if not cancel:_target_fixture(battle,50,12000)
	if not _cast(battle,KEY_R,"skill_r"):return
	if not _wait_object(battle,1273,25):return
	if cancel:_tap(battle,KEY_C);_release()
	_idle(battle,130);_tick(battle,40)
	var births:=_events("crt4_world_born",1273)
	_check("R creates independent source1273 before returning",not births.is_empty(),births)
	for born: Dictionary in births:
		var original_position: Array=born.position
		var y_offset:=float(original_position[1])-float(battle.player.position.y)
		_check("R initial Y preserves original integer2..31 range",y_offset>=2 and y_offset<32 and is_equal_approx(y_offset,roundf(y_offset)),born)
	if not cancel:
		_check("R normal spawn cadence follows every third live EF",births.size()>2 and range(1,births.size()).all(func(i:int)->bool:return int(births[i].tick)-int(births[i-1].tick)==3),births)
		_check("real tombstone contact damages finite target",battle.enemies[0].hp<12000 and not _local_observers(1273).is_empty(),_local_observers(1273))
	else:
		var size:=births.size();_tick(battle,90)
		_check("C cancellation leaves no delayed old spawner births",_events("crt4_world_born",1273).size()==size and battle.player.state=="idle")
	_check("independent tombstone clock reaches source31",_seen_frame(1273,31))
	_sound_requirements(1273,births.size())

func _e_chain(held: bool,multi:=false) -> void:
	var battle:=_world_fresh("E_"+("held" if held else "released")+("_multi" if multi else ""),1,"root_4" if multi else "root_41")
	if battle==null:return
	_target_fixture(battle,45,8000,multi)
	if not _cast(battle,KEY_E,"skill_e",held):return
	_check("real E marks targets and starts independent3962",_wait_object(battle,3962,40))
	if held:
		_check("held E reaches source45 before returning",_frame(battle,"skill_e",45,40))
		_up(battle,KEY_E)
	_check("E completes original branch to146",_idle(battle,90) and battle.player.parent_frame==146)
	var interval_created:=_until(battle,func()->bool:return not _events("crt4_fly_interval_created").is_empty(),40)
	# Source3962/20 calls _parent.gotoAndStop(1): the child is removed in the
	# same source tick. A post-step held frame20 would contradict that lifecycle.
	var retired:=_events("crt4_world_retired",3962).filter(func(row:Dictionary)->bool:return int(row.get("frame",-1))==20 and row.get("reason","")=="source3962 resets3963 to1")
	var owners:=_objects(battle,3963);var created:=_events("crt4_fly_interval_created")
	var independent:=false
	for retirement: Dictionary in retired:
		if not created.any(func(row:Dictionary)->bool:return int(row.tick)==int(retirement.tick)):continue
		for sample: Dictionary in _local_samples():
			if int(sample.tick)!=int(retirement.tick):continue
			# Released E has already returned; held E is still on its own main
			# action. The same independently born child finishes in both cases.
			if int(sample.parent)==(157 if held else 146) and int(retirement.get("age",0))>1 and int(retirement.get("born",retirement.tick))<int(retirement.tick):independent=true
	_check("source target child reaches20 independent of actor",interval_created and not retired.is_empty() and independent and not owners.is_empty() and owners.all(func(row:Dictionary)->bool:return int(row.frame)==1) and _objects(battle,3962).is_empty(),{"retired":retired,"owners":owners.map(func(row:Dictionary)->Dictionary:return {"id":row.id,"frame":row.frame}),"created":created,"held_branch":held,"independent_actor_phase":independent})
	_check("real E target has actual HP loss",battle.enemies[0].hp<8000,_snapshot(battle))
	var requests:=_events("crt4_fly_interval_created")
	_check("E actual target creates shared interval",not requests.is_empty(),requests)
	if multi:_check("distinct real enemy child clocks request shared timer",requests.size()>=2,requests)
	var source_before: int=battle.session.run.source_ticks;var callbacks:=_events("crt4_fly_interval_fired").size()
	_ms(battle,.009)
	_check("9ms cannot consume a10ms callback",_events("crt4_fly_interval_fired").size()==callbacks)
	var positions: Array=battle.enemies.map(func(target:Node2D)->Vector2:return target.position)
	var airborne: Array=battle.enemies.map(func(target:Node2D)->bool:return target.airborne)
	var faces: Array=battle._crt4_fly.faces.duplicate()
	_ms(battle,.001)
	_check("10ms executes actual timer without source tick",_events("crt4_fly_interval_fired").size()>callbacks and battle.session.run.source_ticks==source_before)
	var first_fired:=_events("crt4_fly_interval_fired")
	var matched_request: Array=[]
	if not first_fired.is_empty():matched_request=requests.filter(func(row:Dictionary)->bool:return int(row.id)==int(first_fired[0].id))
	_check("E requests true10ms shared interval by actual fire time",not matched_request.is_empty() and is_equal_approx(float(first_fired[0].ms)-float(matched_request[0].ms),10.0),{"created":matched_request,"fired":first_fired})
	for index in range(battle.enemies.size()):
		var delta: float=battle.enemies[index].position.x-(positions[index] as Vector2).x
		var expected_delta: float=-.05*float(faces[index]) if bool(airborne[index]) and index<faces.size() else 0.0
		_check("E callback uses captured percent scale and current air body target"+str(index+1),is_equal_approx(delta,expected_delta),{"actual_dx":delta,"source_dx":expected_delta,"faces":faces,"airborne":airborne[index]})
	var fired:=_events("crt4_fly_interval_fired").size();_tick(battle,3)
	_check("source steps do not impersonate ms callbacks",_events("crt4_fly_interval_fired").size()==fired)
	battle.set_paused(true);var ms_before: float=battle.real_time_ms;_ms(battle,.2)
	_check("pause freezes shared E ms clock",is_equal_approx(ms_before,battle.real_time_ms) and _events("crt4_fly_interval_fired").size()==fired)
	battle.set_paused(false);_ms(battle,1.1)
	var cleared:=_events("crt4_fly_interval_cleared")
	_check("source timeout clears the current shared interval",not cleared.is_empty(),cleared)
	var after:=_events("crt4_fly_interval_fired").size();_ms(battle,.1)
	_check("expired E interval produces no later callbacks",_events("crt4_fly_interval_fired").size()==after)

func _e_old_timeout() -> void:
	var battle:=_world_fresh("E_old_timeout_clears_new_current_ID")
	if battle==null:return
	_target_fixture(battle,45,16000)
	if not _cast(battle,KEY_E,"skill_e"):return
	if not _until(battle,func()->bool:return not _events("crt4_fly_interval_created").is_empty(),100):
		_check("first actual E creates interval for replacement case",false,_snapshot(battle));return
	var first: Dictionary=_events("crt4_fly_interval_created").back().duplicate(true)
	_ms(battle,.5)
	# Source time and milliseconds are intentionally independent in this case.
	# This is not normal-speed gameplay and does not claim Flash host scheduling.
	_check("second E cooldown is obtained naturally on source clock",_until(battle,func()->bool:return _cooldown(battle,"skill_e")==0 and battle.player.state=="idle",560))
	_move_to(battle,battle.enemies[0].position.x-45)
	Input.action_press("move_right");_tick(battle);_release();_tick(battle)
	var request_count:=_events("crt4_fly_interval_created").size()
	if not _cast(battle,KEY_E,"skill_e"):return
	var another:=_until(battle,func()->bool:return _events("crt4_fly_interval_created").size()>request_count,100)
	_check("second real E target creates a new shared interval",another,_snapshot(battle))
	if not another:return
	var second: Dictionary=_events("crt4_fly_interval_created").back().duplicate(true)
	_check("replacement uses new ID at later ms",int(first.id)!=int(second.id) and is_equal_approx(float(second.ms)-float(first.ms),500.0),[first,second])
	_ms(battle,.499)
	_ms(battle,.001)
	var old_timeout:=_events("crt4_fly_interval_cleared").filter(func(row:Dictionary)->bool:return row.get("reason","")=="timeout" and int(row.get("origin_timeout",-1))==int(first.id))
	_check("old timeout clears newer current ID rather than captured old ID",not old_timeout.is_empty() and int(old_timeout[0].cleared_current_id)==int(second.id),old_timeout)
	var before:=_events("crt4_fly_interval_fired").size()
	_ms(battle,.01)
	_check("new interval stops after old timeout",_events("crt4_fly_interval_fired").size()==before)

func _y_chain(with_flags: bool,facing: int) -> void:
	var battle:=_world_fresh("Y_"+("six_flags" if with_flags else "zero_flags"),facing)
	if battle==null:return
	_check("Y becomes ready through original291 slot",_until(battle,func()->bool:return int(battle.crt4.y_slot_frame)==291,310))
	if with_flags:
		for key: String in ["d","f","g","h"]:
			_cast(battle,FIELD_KEYS[key],"skill_"+key);_idle(battle,30)
		_cast(battle,KEY_W,"skill_w");_idle(battle,30);_start_kalla(battle)
		_check("all six Y bonuses come from real earlier skills",[316,956,818,1121].all(func(sid:int)->bool:return _flag(battle,sid)) and int(battle.crt4.ghost_step)==1 and int(battle.crt4.kalla)==1,_snapshot(battle))
	_target_fixture(battle,100,20000)
	if not _cast(battle,KEY_Y,"skill_y"):return
	_check("Y use stops its slot2, no instant cooldown play",int(battle.crt4.y_slot_frame)==2 and not bool(battle.crt4.y_slot_playing))
	if not _wait_object(battle,944,35):return
	var swamp:=_object(battle,944)
	_check("Y swamp births at21 with original world offset",battle.player.source_frame==21 and (swamp.position as Vector2).is_equal_approx(battle.player.position+Vector2(0,-80)),swamp)
	_check("Y actor returns while independent swamp continues",_idle(battle,25) and not _object(battle,944).is_empty())
	_check("held parent944/20 has running independent943",_wait_object(battle,943,30) and int(_object(battle,944).frame)==20)
	if not _wait_object(battle,907,160):return
	var body:=_object(battle,907)
	_check("943/65 creates actual907 at original offset",_seen_frame(943,65) and (body.position as Vector2).is_equal_approx((swamp.position as Vector2)+Vector2(0,100)),body)
	_check("907 preserves original independent facing and150-percent scale",(body.scale as Vector2).is_equal_approx(Vector2(1.5*facing,1.5)),body.scale)
	var hold_count:=0;var child_clocks: Dictionary={}
	for sample: Dictionary in _local_samples():
		for item: Dictionary in sample.objects:
			if int(item.source_id)==943 and int(item.frame)==35:hold_count+=1
		for item: Dictionary in sample.drawings:
			if int(item.source_id)==942:
				var key:=str(item.id)
				if not child_clocks.has(key):child_clocks[key]=[]
				child_clocks[key].append(int(item.frame))
	_check("Y has multiple real942 visible instances",child_clocks.size()>1,child_clocks.keys())
	y_hold_samples["%d_%s"%[facing,str(with_flags)]]=hold_count
	if with_flags:
		var zero_count:=int(y_hold_samples.get("%d_false"%facing,-1))
		_check("six actual flags shorten one943 charge counter, not five counters",zero_count>hold_count and zero_count>=39 and hold_count<=1,{"zero_flags_source35_samples":zero_count,"six_flags_source35_samples":hold_count,"source_threshold":40,"source_load_bonus":48})
	var looped:=false
	for frames: Array in child_clocks.values():
		_check("942 child source frame stays within independent21 loop",frames.all(func(f:int)->bool:return f>=1 and f<=21),frames)
		for i in range(1,frames.size()):
			if int(frames[i-1])==21 and int(frames[i])==1:looped=true
	_check("at least one live942 visibly loops while943 continues",looped,child_clocks)
	_check("Y slot remains stopped until independent906 ends",int(battle.crt4.y_slot_frame)==2 and not bool(battle.crt4.y_slot_playing))
	_check("906/40 resumes Y preparation after world attack",_until(battle,func()->bool:return bool(battle.crt4.y_slot_playing),60) and _seen_frame(906,40))
	_check("world Y actually hits finite target after actor idle",battle.enemies[0].hp<20000 and not _local_observers(906).is_empty(),_local_observers(906))
	_check("Y slot does not become ready at body completion",int(battle.crt4.y_slot_frame)<291)
	_check("Y normal preparation completes again",_until(battle,func()->bool:return int(battle.crt4.y_slot_frame)==291,300))
	_sound_requirements(906,1)
	var first:=_sounds_for(906,884);var second:=_sounds_for(906,894);var third:=_sounds_for(906,905)
	_check("Y actual child sounds retain2-to4-to25 source intervals",first.size()==1 and second.size()==1 and third.size()==1 and int(second[0].tick)-int(first[0].tick)==2 and int(third[0].tick)-int(second[0].tick)==21,[first,second,third])

func _cleanup_and_rejections() -> void:
	for code: int in [KEY_D,KEY_F,KEY_G,KEY_H,KEY_W,KEY_T,KEY_E,KEY_R,KEY_Y]:
		var battle:=_world_fresh("no_MP_"+char(code))
		if battle==null:continue
		if code==KEY_Y:_until(battle,func()->bool:return int(battle.crt4.y_slot_frame)==291,310)
		battle.player.mp=0 # Explicit insufficient-resource boundary fixture, not action/state injection.
		var cubes: int=battle.session.profile.progress.clear_cubes;var before:=_objects(battle).size()
		_tap(battle,code);_tick(battle,5)
		_check("resource rejection creates no paid world object "+char(code),battle.player.state=="idle" and int(battle.session.profile.progress.clear_cubes)==cubes and _objects(battle).size()==before and not notices.is_empty(),_snapshot(battle))
	var battle:=_world_fresh("world_death_cleanup")
	if battle==null:return
	_cast(battle,KEY_D,"skill_d");_idle(battle,30);_cast(battle,KEY_W,"skill_w");_idle(battle,30);_start_kalla(battle)
	_check("cleanup fixture really has live worlds",not _objects(battle).is_empty())
	battle.player.receive_damage(battle.player.hp+1) # Public production combat entry.
	_tick(battle,40);_ms(battle,2.0)
	_check("death clears world instances and persistent flags",battle.ended and _objects(battle).is_empty() and int(battle.crt4.kalla)==0 and int(battle.crt4.ghost_step)==0,_snapshot(battle))
	var old: Node2D=battle
	battle=_world_fresh("world_reentry")
	_check("normal reentry cannot inherit old objects/flags",old.is_queued_for_deletion() and _objects(battle).is_empty() and [316,956,818,1121].all(func(sid:int)->bool:return not _flag(battle,sid)))

func _run() -> void:
	output=OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if output.is_empty():output="res://artifacts/leba_act06_20261117/crt4_world/run_%d_%d"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	OS.set_environment("LEBA_TEST_MODE","1");OS.set_environment("LEBA_SILENT_TEST","1")
	OS.set_environment("LEBA_TEST_PROFILE","user://act06_crt4_world/%d_%d/profile.json"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()])
	formal_exists=FileAccess.file_exists("user://profile.json")
	if formal_exists:formal_hash=FileAccess.get_sha256("user://profile.json")
	expected=JSON.parse_string(FileAccess.get_file_as_string(EXPECTED));source_hashes=_integrity()
	app=MainScene.instantiate();root.add_child(app);app.set_process(false)
	_check("normal Main starts with actual CRT4 authored content",app.startup_ok and app.database.characters.has("crt_4") and bool(app.database.characters.get("crt_4",{}).get("enabled",false)),app.database.issues)
	if app.startup_ok and app.database.characters.has("crt_4"):
		app.audio.sound_played.connect(_on_sound);_source_contract()
		for key: String in FIELD_KEYS:
			for facing: int in [1,-1]:_field_lifecycle(key,facing)
			_field_contact(key,false)
			if key in ["d","f"]:_field_contact(key,true)
		_ghostwalk();_kalla_second_t_and_timeout()
		for facing: int in [1,-1]:
			_kalla_clones(facing,false);_kalla_clones(facing,true)
			_kalla_air_clone(facing)
			_tombstones(facing,false);_tombstones(facing,true)
			_y_chain(false,facing);_y_chain(true,facing)
		_e_chain(false);_e_chain(true);_e_chain(true,true);_e_old_timeout()
		_kalla_three_layers_rearm();_mummy_repeat_refresh()
		_cleanup_and_rejections()
	_release();app._dispose_battle();await _complete_exit_frame()
	_check("actual audio drains before exit",await app.audio.stop_and_drain(1.0));app.queue_free();await process_frame
	_check("formal authors/Core/catalog/oracle bytes unchanged",_integrity()==source_hashes)
	_check("formal profile untouched",FileAccess.file_exists("user://profile.json")==formal_exists and (not formal_exists or FileAccess.get_sha256("user://profile.json")==formal_hash))
	_check("all consumed sounds have valid real streams/offsets",not sounds.is_empty() and sounds.all(func(row:Dictionary)->bool:return row.valid and row.offset>=0 and row.offset<row.length))
	var failures: int=checks.filter(func(row:Dictionary)->bool:return not row.passed).size()
	var report:=FileAccess.open(output.path_join("act06_crt4_world.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"events":world_events,"samples":world_samples,"sounds":sounds,"fixtures":fixtures,"hashes":source_hashes,"source_oracle":EXPECTED,"not_tested":["Original CRT4 dynamic phase/total damage equivalence","Natural OS keyboard","GPU actual visibility (separate harness)","Audible listening"]},"\t")+"\n")
	print("ACT06_CRT4_WORLD_RESULT "+JSON.stringify({"checks":checks.size(),"failures":failures,"output":output}))
	quit(0 if failures==0 else 1)
