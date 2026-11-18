extends "res://tests/test_act05_crt3_actions.gd"
## ACT06 source-grounded sword-wave supplement. Formal saved Resource variants,
## actual Main/input, one-time target fixtures; never seed waves/markers/actions.
const WAVE_ORACLE := "res://tests/fixtures/act06_waves_expected.json"
var output := ""
var variants: Dictionary = {}
var source_oracle: Dictionary = {}
var samples: Array[Dictionary] = []
var wave_events: Array[Dictionary] = []
var case_seen: Dictionary = {}
var run_hashes: Dictionary = {}
var config_id := "default"

func _hashes() -> Dictionary:
	var result := {}
	for directory: String in ["res://content/actions/crt3","res://content/components/crt3"]:
		for name: String in DirAccess.get_files_at(directory):
			if name.ends_with(".tres"):result[directory.path_join(name)]=FileAccess.get_sha256(directory.path_join(name))
	for path: String in ["res://content/index.tres","res://content/characters/crt_3.tres","res://scripts/combat/battle.gd","res://scripts/combat/combatant.gd","res://scripts/main.gd","res://data/asset_catalog.json",WAVE_ORACLE]:result[path]=FileAccess.get_sha256(path)
	return result

func _make_variants() -> void:
	var original: Resource=load("res://content/index.tres")
	for spec: Array in [["default",0,0],["weapon3",3,0],["master1",0,1]]:
		var index: Resource=original.duplicate(false)
		index.characters=original.characters.duplicate()
		var changed: Resource
		var target_index:=-1
		for i in range(index.characters.size()):
			if index.characters[i].identifier=="crt_3":
				changed=index.characters[i].duplicate(false);target_index=i;break
		if changed==null:_check("CRT3 author exists for saved configuration",false);continue
		changed.extra=changed.extra.duplicate(true)
		changed.extra.source_profile.weapon=int(spec[1])
		changed.extra.source_profile.weaponmaster=int(spec[2])
		var char_path:=output.path_join(str(spec[0])+"_character.tres")
		var index_path:=output.path_join(str(spec[0])+"_index.tres")
		_check("save isolated actual CharacterDefinition "+str(spec[0]),ResourceSaver.save(changed,char_path)==OK)
		index.characters[target_index]=ResourceLoader.load(char_path,"",ResourceLoader.CACHE_MODE_IGNORE)
		_check("save isolated actual ContentIndex "+str(spec[0]),ResourceSaver.save(index,index_path)==OK)
		var reread: Resource=ResourceLoader.load(index_path,"",ResourceLoader.CACHE_MODE_IGNORE)
		_check("saved author config rereads "+str(spec[0]),reread!=null and int(reread.characters[target_index].extra.source_profile.weapon)==int(spec[1]) and int(reread.characters[target_index].extra.source_profile.weaponmaster)==int(spec[2]))
		variants[str(spec[0])]={"index":index_path,"character":char_path,"weapon":int(spec[1]),"weaponmaster":int(spec[2]),"sha256":FileAccess.get_sha256(char_path)}

func _open_main(id: String) -> void:
	if is_instance_valid(app):
		app._dispose_battle()
		_check("previous Main audio drains",await app.audio.stop_and_drain(1.0))
		app.queue_free();await process_frame
	config_id=id
	app=MainScene.instantiate()
	app.content_registry=ResourceLoader.load(str(variants[id].index),"",ResourceLoader.CACHE_MODE_IGNORE)
	root.add_child(app);app.set_process(false)
	_check("formal Main loads saved "+id+" author config",app.startup_ok and app.test_mode,app.database.issues)
	if app.startup_ok:app.audio.sound_played.connect(_on_sound)

func _training(name: String, facing: int, target := false) -> Node2D:
	current_case=config_id+"_"+("right_" if facing==1 else "left_")+name
	_release();case_seen={}
	app.session.profile=app.saves.default_profile()
	app.show_title()
	var training: BaseButton=app.ui.get_button("Training")
	if training==null:_check("normal Training button exists",false);return null
	training.pressed.emit()
	var selector: BaseButton=app.ui.get_button("Character_crt_3")
	if selector==null:_check("normal CRT3 selector exists",false);return null
	selector.pressed.emit()
	var battle: Node2D=app.battle
	battle.manual_clock=true;battle.set_physics_process(false)
	for enemy: Node2D in battle.enemies:enemy.position=Vector2(520,-1000)
	_tick(battle,2)
	Input.action_press("move_right")
	for n in range(55):
		if battle.player.position.x>=264:break
		_tick(battle)
	_release();_tick(battle)
	Input.action_press("move_right" if facing==1 else "move_left");_tick(battle)
	_release();_tick(battle)
	var profile: Dictionary=battle.player.definition.get("source_profile",{})
	_check("normal training consumes saved gate and direction",app.screen=="battle" and battle.is_training() and battle.player.facing==facing and int(profile.get("weapon",-1))==int(variants[config_id].weapon) and int(profile.get("weaponmaster",-1))==int(variants[config_id].weaponmaster),profile)
	if target:
		# Initial finite resource/spatial fixture only; AI remains live thereafter.
		battle.enemies[0].hp=2000.0
		battle.enemies[0].position=battle.player.position+Vector2(250*facing,46)
		traces.append({"case":current_case,"fixture":"one-time initial enemy HP2000 and relative(250*facing,46), live AI; no action/marker/result injection","target":battle.enemies[0].position})
	return battle

func _waves(battle: Node2D) -> Array:
	return battle._crt3_objects.filter(func(item: Dictionary)->bool:return bool(item.get("sword_wave",false)))

func _dynamic_layer(view: Node2D) -> int:
	var ancestor: Node=view.get_parent()
	while ancestor!=null:
		if ancestor is CanvasLayer:return ancestor.layer
		ancestor=ancestor.get_parent()
	return 0

func _sample(battle: Node2D) -> void:
	var waves: Array=[]
	for item: Dictionary in _waves(battle):
		var view: Node2D=item.visual
		var row: Dictionary={"id":item.id,"source_id":item.source_id,"origin":item.origin,"age":item.age,"frame":item.frame,"visual_frame":view.source_frame,"position":item.position,"depth":item.depth,"mr":item.mr.duplicate(true),"r":item.r.duplicate(true),"alpha_bounds":view.frame.get("alpha_bounds",[]),"texture":view.definition.texture}
		waves.append(row)
		if not case_seen.has(str(item.id)):
			case_seen[str(item.id)]=row.duplicate(true)
			wave_events.append({"case":current_case,"event":"observed_birth","tick":battle.session.run.source_ticks,"player_state":battle.player.state,"player_frame":battle.player.source_frame,"back_frame":battle.crt3.back_frame,"player_position":battle.player.position,"wave":row.duplicate(true)})
	var tick: int=battle.session.run.source_ticks
	for row: Dictionary in battle.journal:
		if int(row.tick)==tick and str(row.event) in ["crt3_sword_wave_contact","crt3_sword_wave_observer"]:
			var entry: Dictionary=row.duplicate(true);entry["case"]=current_case;entry["player_state"]=battle.player.state;entry["enemy_hp"]=battle.enemies[0].hp;entry["airborne"]=battle.enemies[0].airborne;wave_events.append(entry)
	var slashes: Array=[]
	for key: String in ["slash_horizontal","slash_left","slash_right"]:
		var view: Node2D=battle._crt3_views.get(key)
		if is_instance_valid(view):slashes.append({"key":key,"canvas_layer":_dynamic_layer(view),"z":view.z_index,"source_depth":view.get_meta("source_dynamic_depth",-1)})
	samples.append({"case":current_case,"tick":tick,"action":battle.player.state,"frame":battle.player.source_frame,"back_frame":battle.crt3.back_frame,"facing":battle.player.facing,"position":battle.player.position,"enemy_hp":battle.enemies[0].hp,"enemy_marker":battle.enemies[0]._air_hit_started,"enemy_airborne":battle.enemies[0].airborne,"waves":waves,"slashes":slashes})

func _tick(battle: Node2D, count := 1) -> void:
	for n in range(count):
		battle.step(battle.take_commands());_sample(battle)

func _on_sound(alias: String, stream: AudioStream, offset: float, voice: AudioStreamPlayer) -> void:
	var battle: Node2D=app.battle if is_instance_valid(app.battle) else null
	var path: String=stream.resource_path if stream!=null else ""
	var source: Dictionary=app.database.assets.audio_events.get(alias,{})
	sounds.append({"case":current_case,"alias":alias,"path":path,"sound_id":int(source.get("sound_id",path.get_file().get_basename().to_int())),"source_id":int(source.get("sprite_id",0)),"seconds":stream.get_length() if stream!=null else 0.0,"offset":offset,"valid":stream!=null and is_instance_valid(voice) and voice.stream==stream and voice.playing and voice.has_stream_playback(),"tick":battle.session.run.source_ticks if battle!=null else -1,"action":battle.player.state if battle!=null else "","frame":battle.player.source_frame if battle!=null else -1})

func _births() -> Array:
	return wave_events.filter(func(row: Dictionary)->bool:return row.case==current_case and row.event=="observed_birth")

func _contacts() -> Array:
	return wave_events.filter(func(row: Dictionary)->bool:return row.case==current_case and row.event=="crt3_sword_wave_contact")

func _source_contract() -> void:
	var wave: Dictionary=app.database.characters.crt_3.components.get("sword_wave",{})
	_check("formal sword_wave Resource is loaded",not wave.is_empty())
	if wave.is_empty():return
	var mismatch: Array=[]
	for sid: String in ["1267","1311"]:
		for frame in range(1,19):
			var expected: Array=source_oracle.objects[sid].timeline[str(frame)].helpers
			var actual: Array=wave.objects[sid].helpers.get(str(frame),[])
			if actual!=expected:mismatch.append({"source_id":sid,"frame":frame,"expected":expected,"actual":actual})
	_check("both world-helper matrices match independent original XML1..18",mismatch.is_empty(),mismatch)
	_check("original terminal/empty ages retain18 stop then22 empty",int(wave.parent_stop_source_frame)==18 and int(wave.empty_render_age)==22)
	_check("439/524 observers retain independent4/15 and cap7",int(wave.helper439.normal_contact_limit)==7 and float(wave.helper439.marker_observer.damage)==4 and float(wave.helper524.marker_observer.damage)==15)

func _w_cycle(facing: int, contact: bool) -> void:
	var battle:=_training("W_"+("contact" if contact else "empty"),facing,contact)
	if battle==null:return
	seed(60617+facing)
	var beginning:=samples.size();var sound_start:=sounds.size()
	_tap(battle,KEY_W)
	for n in range(130):
		if battle.player.state=="idle":break
		# Real repeated W down/release extends the original cut counter; no seeded
		# source frame/counter, so all conditional6/21/36/51 are actually visited.
		if battle.player.state=="skill_w" and battle.player.source_frame>=5 and battle.player.source_frame<30:
			_tap(battle,KEY_W,true);_tick(battle)
		else:_tick(battle)
	_check("normal complete W returns idle",battle.player.state=="idle",_snapshot(battle))
	var births:=_births()
	var expected: Array=[64] if config_id=="default" else [6,21,36,51,64]
	_check("actual W birth frames obey original condition",births.map(func(row: Dictionary):return int(row.player_frame))==expected,births)
	_check("wave origin/root source/initial transform is independent",births.all(func(row: Dictionary)->bool:return row.wave.origin=="w" and int(row.wave.source_id)==(1267 if facing==1 else 1311) and (row.wave.position as Vector2).is_equal_approx(row.player_position) and int(row.wave.age)==1 and int(row.wave.frame)==1),births)
	_check("new helper Load does not fabricate birth-tick contact",_contacts().all(func(c: Dictionary)->bool:return births.all(func(b: Dictionary)->bool:return c.id!=b.wave.id or int(c.tick)>int(b.tick))),_contacts())
	var before_settle:=_waves(battle).size()
	_check("W completion retains independent root objects",before_settle==expected.size(),_snapshot(battle))
	_check("source dynamic wave depth stays above static map actor HUD and below menus",not _waves(battle).is_empty() and _waves(battle).all(func(item: Dictionary)->bool:return _dynamic_layer(item.visual)>0 and _dynamic_layer(item.visual)<10 and int(item.visual.get_meta("source_dynamic_depth",-1))==int(item.depth) and item.visual.z_index==int(item.depth)))
	_tick(battle,25)
	_check("18 stop and22 empty retain inert roots",_waves(battle).size()==before_settle and _waves(battle).all(func(item: Dictionary)->bool:return int(item.frame)==18 and item.visual.source_frame==22 and float(item.visual.frame.alpha_bounds[2])==0 and float(item.visual.frame.alpha_bounds[3])==0))
	var local: Array=samples.slice(beginning)
	_check("wave root stays at recorded birth position through complete lifecycle",local.all(func(row: Dictionary)->bool:return row.waves.all(func(item: Dictionary)->bool:return (item.position as Vector2).is_equal_approx(case_seen[str(item.id)].position))))
	_check("actual tail persists at age18 and21; empties22",[18,21,22].all(func(age: int)->bool:return local.any(func(row: Dictionary)->bool:return row.waves.any(func(item: Dictionary)->bool:return int(item.age)==age and int(item.frame)==18 and int(item.visual_frame)==age and (float(item.alpha_bounds[2])>0 if age<22 else float(item.alpha_bounds[2])==0)))))
	_check("W host6170 actually plays once at64",sounds.slice(sound_start).filter(func(row: Dictionary)->bool:return int(row.sound_id)==6170 and row.action=="skill_w" and int(row.frame)==64 and row.valid).size()==1)
	if contact:
		_check("real world wave contact produces marker and finite HP loss",not _contacts().is_empty() and battle.enemies[0].hp<2000 and local.any(func(row: Dictionary)->bool:return row.enemy_airborne and int(row.enemy_marker)>=0),_contacts())
		_check("per-wave per-target contact cap never exceeds7",_contacts().all(func(row: Dictionary)->bool:return int(row.mr)>=1 and int(row.mr)<=7))
		_check("real delayed random slash dispatch consumes Sound4",sounds.slice(sound_start).any(func(row: Dictionary)->bool:return row.alias=="crt3_slash_contact" and int(row.sound_id)==4 and row.valid),sounds.slice(sound_start))
		_check("delayed slash keeps root dynamic layer and fixed source depth identity",local.any(func(row: Dictionary)->bool:return not row.waves.is_empty() and not row.slashes.is_empty()) and local.all(func(row: Dictionary)->bool:return row.slashes.all(func(s: Dictionary)->bool:return int(s.canvas_layer)>0 and int(s.canvas_layer)<10 and int(s.z)==int(s.source_depth) and int(s.z) in [1,2,3])))
	else:_check("empty W does not fake world contacts",_contacts().is_empty())
	# Actual UI restoration permits another legal cast without assigning cooldown.
	var restore: BaseButton=app.ui.get_button("TrainingRestore")
	_check("actual training restore button exists",restore!=null)
	if restore!=null:restore.pressed.emit();_tick(battle,3)
	_tap(battle,KEY_W);_idle(battle,130)
	var all_births:=_births()
	var expected_second:=1 if config_id=="default" else 3 # tap-only original cut0 visits6,21,64.
	_check("repeat W adds only legitimately revisited source frames",all_births.size()==expected.size()+expected_second,all_births)
	var depths: Dictionary={}
	for row: Dictionary in all_births:depths[int(row.wave.depth)]=true
	_check("root depths are unique across repeated casts",all_births.size()==depths.size())
	var prior: Node2D=battle
	app.show_title();await process_frame
	_check("title exit frees encounter and wave draw nodes",not is_instance_valid(prior) and app.battle==null)

func _back_cycle(facing: int, contact: bool) -> void:
	var battle:=_training("back_X_"+("contact" if contact else "empty"),facing,contact)
	if battle==null:return
	seed(60619+facing)
	var sound_start:=sounds.size()
	_tap(battle,KEY_DOWN);_down(battle,KEY_X)
	for n in range(45):_tick(battle)
	_release()
	var births:=_births();var allowed:=config_id!="default"
	_check("backstep child4 gate is exact",births.size()==(1 if allowed else 0) and births.all(func(row: Dictionary)->bool:return int(row.back_frame)==4 and row.wave.origin=="backstep"),births)
	_check("normal backstep-X finishes and keeps proper direction",battle.player.state=="idle" and battle.player.facing==facing,_snapshot(battle))
	_check("backstep source4 sound5181 is actual playback",sounds.slice(sound_start).any(func(row: Dictionary)->bool:return int(row.sound_id)==5181 and row.valid))
	if allowed:
		_check("backstep wave uses correct source and fixed root position",births.all(func(row: Dictionary)->bool:return int(row.wave.source_id)==(1267 if facing==1 else 1311) and (row.wave.position as Vector2).is_equal_approx(row.player_position)),births)
		_check("backstep completion does not kill independent wave",_waves(battle).size()==1 and int(_waves(battle)[0].age)>22 and int(_waves(battle)[0].frame)==18)
		if contact:_check("backstep wave actually contacts beyond main action",not _contacts().is_empty() and battle.enemies[0].hp<2000,_contacts())
	else:_check("default backstep never sneaks in a wave or wave hit",_waves(battle).is_empty() and _contacts().is_empty())
	_tap(battle,KEY_DOWN);_down(battle,KEY_X);_tick(battle,45);_release()
	_check("backstep attack slot cooldown blocks premature second wave",_births().size()==(1 if allowed else 0),_births())
	_check("backstep attack slot naturally becomes ready",_until(battle,func()->bool:return int(battle.player.cooldowns.get("backstep_x",0))==0,120))
	_tap(battle,KEY_DOWN);_down(battle,KEY_X);_tick(battle,45);_release()
	_check("repeat actual backstep adds one wave per legal child4 only",_births().size()==(2 if allowed else 0) and _births().all(func(row: Dictionary)->bool:return int(row.back_frame)==4),_births())
	if allowed and not contact:_check("legal empty repeated backstep does not invent contacts",_contacts().is_empty())
	var old: Node2D=battle
	battle=_training("back_X_reentry",facing)
	_check("reentry has no old wave/counter/child",old.is_queued_for_deletion() and _waves(battle).is_empty() and int(battle.crt3.back_frame)==1)

func _interruptions() -> void:
	var battle:=_training("W_C_early",1)
	_tap(battle,KEY_W)
	_frame(battle,"skill_w",10,20);_tap(battle,KEY_C);_release();_tick(battle,100)
	_check("C early exit cannot spawn delayed64 wave",battle.player.state=="idle" and _births().is_empty(),_births())
	battle=_training("W_hurt_before64",1)
	_tap(battle,KEY_W);_frame(battle,"skill_w",10,20)
	battle.player.receive_damage(1.0) # Public combat entry fixture, never set_action.
	_tick(battle,100)
	_check("public hurt before64 removes old birth listener",_births().is_empty(),_births())
	battle=_training("W_hurt_after_birth",1)
	_tap(battle,KEY_W)
	var born:=_until(battle,func()->bool:return not _waves(battle).is_empty(),100)
	_check("ordinary input reaches wave before hurt fixture",born)
	if born:
		var depth: int=_waves(battle)[0].depth
		battle.player.receive_damage(1.0);_tick(battle,8)
		_check("hurt does not destroy already independent root wave",_waves(battle).size()==1 and int(_waves(battle)[0].depth)==depth and int(_waves(battle)[0].age)>=9)
		battle.player.receive_damage(battle.player.hp+1.0)
		_tick(battle,40)
		_check("death settlement clears root waves without late births",battle.ended and _waves(battle).is_empty() and _births().size()==1,_snapshot(battle))

func _observer_phases(facing: int) -> void:
	var battle:=_training("W_observer_original_fixture",facing)
	var oracle: Dictionary=source_oracle.dynamic_observer_probe
	_tap(battle,KEY_W)
	_check("actual W reaches bounded original fixture at62",_frame(battle,"skill_w",int(oracle.fixture.when_player_frame),110))
	var target: Node2D=battle.enemies[0]
	_check("fixture begins with original ground target, no seeded marker",not target.airborne and is_zero_approx(target.gravity_acceleration))
	target.hp=float(oracle.fixture.enemy_hp)
	target.position=Vector2(battle.player.position.x+float(oracle.fixture.enemy_relative_x)*facing,float(oracle.fixture.enemy_y))
	traces.append({"case":current_case,"fixture":"Original probe bounded W62 target fixture, actual Main/W input. Relative80/ground361/HP2000; no marker/action injection, no later position writes. Player root differs by normal movement grid; no total HP oracle.","player":battle.player.position,"enemy":target.position})
	_check("source fixture reaches new W64 world wave",_until(battle,func()->bool:return not _waves(battle).is_empty(),10))
	if _waves(battle).is_empty():return
	_tick(battle,18)
	var observers: Array=wave_events.filter(func(row: Dictionary)->bool:return row.case==current_case and row.event=="crt3_sword_wave_observer")
	var mismatches: Array=[]
	for frame in range(1,19):
		# JSON numeric fields are floats; compare the source integer IDs/amounts
		# explicitly so Dictionary type identity does not disguise equal values.
		var expected: Array=oracle.expected_local_observers_by_wave_frame[str(frame)].map(func(row: Dictionary)->Dictionary:return {"helper":int(row.helper),"damage":int(row.damage)})
		var actual: Array=observers.filter(func(row: Dictionary)->bool:return int(row.source_frame)==frame).map(func(row: Dictionary)->Dictionary:return {"helper":int(row.helper),"damage":int(row.damage)})
		if actual!=expected:mismatches.append({"frame":frame,"expected":expected,"actual":actual})
	_check("original524-before439 phase avoids repeated automatic19",mismatches.is_empty(),{"first_differences":mismatches,"actual_observers":observers})
	_check("each recorded local observer actually changes unified target HP",not observers.is_empty() and observers.all(func(row: Dictionary)->bool:return is_equal_approx(float(row.hp_before)-float(row.hp_after),float(row.damage))),observers)
	var contacts:=_contacts()
	_check("original ground contact limit reaches7 atsource8 without extra contact",contacts.map(func(row: Dictionary):return int(row.source_frame))==[2,3,4,5,6,7,8] and contacts.map(func(row: Dictionary):return int(row.mr))==[1,2,3,4,5,6,7],contacts)

func _run() -> void:
	output=OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if output.is_empty():output="res://artifacts/leba_act06_20261117/waves/run_%d_%d"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	OS.set_environment("LEBA_TEST_MODE","1");OS.set_environment("LEBA_SILENT_TEST","1")
	OS.set_environment("LEBA_TEST_PROFILE","user://act06_waves/%d_%d/profile.json"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()])
	formal_exists=FileAccess.file_exists("user://profile.json")
	if formal_exists:formal_hash=FileAccess.get_sha256("user://profile.json")
	run_hashes=_hashes();source_oracle=JSON.parse_string(FileAccess.get_file_as_string(WAVE_ORACLE))
	_make_variants()
	for id: String in ["default","weapon3","master1"]:
		await _open_main(id)
		if not app.startup_ok:continue
		if id=="default":_source_contract()
		for facing: int in [1,-1]:
			await _w_cycle(facing,true)
			_back_cycle(facing,id!="default")
			if id!="default":_back_cycle(facing,false)
		if id=="default":
			_interruptions();await _w_cycle(1,false)
			for facing: int in [1,-1]:_observer_phases(facing)
	_release()
	if is_instance_valid(app):
		app._dispose_battle();_check("final audio drains",await app.audio.stop_and_drain(1.0));app.queue_free();await process_frame
	_check("formal author/runtime/oracle bytes unchanged",_hashes()==run_hashes)
	_check("formal profile untouched",FileAccess.file_exists("user://profile.json")==formal_exists and (not formal_exists or FileAccess.get_sha256("user://profile.json")==formal_hash))
	_check("all source sounds are valid actual requests",not sounds.is_empty() and sounds.all(func(row: Dictionary)->bool:return row.valid and row.seconds>0 and row.offset>=0 and row.offset<row.seconds))
	var failures: int=checks.filter(func(row: Dictionary)->bool:return not row.passed).size()
	var file:=FileAccess.open(output.path_join("act06_waves.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"events":wave_events,"samples":samples,"sounds":sounds,"variants":variants,"hashes":run_hashes,"source_oracle":WAVE_ORACLE,"godot":Engine.get_version_info(),"fixtures":["saved/reloaded isolated real author Resource/index variants","manual25Hz source clock with real Main/input","one initial finite HP2000/relative250,46 target fixture; AI live","public receive_damage only for interruption/death","ordinary TrainingRestore button for repeat cast"],"not_tested":["GPU pixel visibility (separate window supplement)","audible listening","natural OS keyboard dispatch","original Flash/Ruffle wave callback phase probe","superarmor target behavior"]},"\t")+"\n");file.close()
	print("ACT06_WAVES_RESULT "+JSON.stringify({"checks":checks.size(),"failures":failures,"output":output}))
	quit(0 if failures==0 else 1)
