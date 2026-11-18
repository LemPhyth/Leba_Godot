extends "res://tests/render_act06_crt4_world.gd"
## Actual GL main-action evidence. This reuses the normal Main/input fixture and
## same-source-tick GPU hide/restore pairs, not a second gameplay implementation.
## Only initial enemy space/finite HP and the explicitly labelled public hurt
## fixture are controlled. No action/frame/marker/cost/cooldown writes are used.
const ACTION_EXPECTED := "res://tests/fixtures/act06_crt4_actions_expected.json"
const GROUPS := ["x","a_early","a_ghost1","a_ghost2","a_ghost3","s","z","hurt_z","q","v_contact","v_empty","air","kalla_air","w_move"]
# Finite StartSound facts independently read from res/structure/game.xml.
# Rows: [source frame, sound ID, inPoint in 44100-Hz samples]. No raw AS/XML or
# ignored artifact is required at runtime. The source snapshot SHA is provenance
# for that read, not a replacement for observing AudioDirector's actual stream.
const AUDIO_SOURCE_SNAPSHOT_SHA256 := "9a1715911c469b7b1cba0b56f5ebd846a31302723ece042a0cd145bcc9249551"
const SOURCE_SOUNDS := {
	6408:[[3,5181,0]],6409:[[3,5203,300]],6413:[[2,5205,300]],
	6446:[[8,6414,0],[27,6430,3400],[49,6431,0],[59,6430,0],[60,3958,0],[77,6431,0],[87,6430,0],[88,3958,0],[105,6431,0],[115,6430,0],[116,3958,0]],
	6458:[[3,4695,0],[3,6449,800],[13,4695,0],[26,6457,0],[26,4695,0]],
	6487:[[7,3950,0]],6511:[[2,6510,0]],6530:[[2,4624,0],[28,4616,0]],
	6528:[[3,5181,0],[14,6526,0]],6541:[[5,4695,3500],[17,4695,3500],[26,5698,0],[29,5240,3500]],
	6393:[[11,4616,0]],3951:[[2,3950,0]]
}
var action_expected: Dictionary={}
var audio_coverage: Array[Dictionary]=[]

func _gpu_integrity() -> Dictionary:
	var result:=super._gpu_integrity()
	for path: String in ["res://tests/render_act06_crt4_actions.gd",ACTION_EXPECTED,"res://tests/test_act05_crt3_actions.gd"]:
		result[path]=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "MISSING"
	return result

func _on_sound(alias: String,stream: AudioStream,offset: float,voice: AudioStreamPlayer) -> void:
	super._on_sound(alias,stream,offset,voice)
	var event: Dictionary=app.database.assets.audio_events.get(alias,{})
	var row: Dictionary=sounds.back()
	row["source_sound_frame"]=int(event.get("frame",-1))
	row["in_point_samples_44100"]=int(event.get("in_point_samples_44100",0))
	if is_instance_valid(app.battle):
		row["actor_state"]=app.battle.player.state
		row["actor_frame"]=app.battle.player.source_frame
		row["actor_parent"]=app.battle.player.parent_frame
		row["milliseconds"]=app.battle.real_time_ms

func _audio_frames(source_id: int,frames: Array) -> void:
	for fact: Array in SOURCE_SOUNDS.get(source_id,[]):
		if int(fact[0]) not in frames:continue
		var matches:=_sounds_for(source_id,int(fact[1])).filter(func(row:Dictionary)->bool:return int(row.get("source_sound_frame",-1))==int(fact[0]))
		var expected_offset:=float(fact[2])/44100.0
		var valid:=matches.size()==1 and matches.all(func(row:Dictionary)->bool:return bool(row.valid) and is_equal_approx(float(row.offset),expected_offset))
		var detail:={"case":current_case,"source_id":source_id,"source_frame":fact[0],"sound_id":fact[1],"expected_count":1,"offset":expected_offset,"actual":matches,"passed":valid,"source":"res/structure/game.xml DefineSprite_%d StartSound frame_%d"%[source_id,int(fact[0])]}
		audio_coverage.append(detail)
		_check("actual source%d f%d Sound%d stream/offset/count"%[source_id,int(fact[0]),int(fact[1])],valid,detail)

func _exact_main(battle: Node2D,action: String,frame: int,cap:=80) -> bool:
	var reached:=_frame(battle,action,frame,cap)
	var exact: bool=reached and battle.player.state==action and battle.player.source_frame==frame
	_check("real input reaches exact main %s/%d"%[action,frame],exact,_snapshot(battle))
	if exact:
		_check("main sprite consumes current action/frame",battle.player.visual.source_frame==frame and _visual_source_id(battle.player.visual)==int(action_expected.actions[action].source_id),_visual_metadata(battle.player.visual))
		await _pair(battle,"main_"+action+"_"+str(frame),[battle.player.visual])
	return exact

func _finish_action(battle: Node2D,cap:=150) -> void:
	_release()
	_check("normal action completion returns parent146",_idle(battle,cap) and battle.player.parent_frame==146,_snapshot(battle))
	await _finish_gpu(battle)

func _x_gpu(facing: int) -> void:
	var battle:=await _fresh_gpu("pure_X",facing)
	if battle==null:return
	_target_fixture(battle,60,5000)
	_tap(battle,KEY_X)
	await _exact_main(battle,"basic",5)
	var ready:=_frame(battle,"basic",9,20)
	_check("pure X first real listener window9",ready,_snapshot(battle))
	if ready:
		_tap(battle,KEY_X);await _exact_main(battle,"basic2",4)
		ready=_frame(battle,"basic2",10,20)
		_check("pure X second real listener window10",ready,_snapshot(battle))
		if ready:
			var serial: int=battle.player.action_serial
			_tap(battle,KEY_X)
			_check("same151 continuation preserves current child this tick",battle.player.parent_frame==151 and battle.player.source_frame==10 and battle.player.action_serial==serial,_snapshot(battle))
			_tick(battle)
			_check("following real tick enters152",battle.player.parent_frame==152 and battle.player.source_frame==1,_snapshot(battle))
			await _exact_main(battle,"basic3",6)
	_idle(battle,35)
	_check("ordinary chain makes actual finite-target contact",battle.enemies[0].hp<5000 and battle.enemies[0].hp>0,_snapshot(battle))
	for sid: int in [6408,6409,6413]:_audio_frames(sid,[2,3])
	await _finish_action(battle)

func _a_gpu(facing: int,ghost: int) -> void:
	var battle:=await _fresh_gpu("A_early" if ghost==0 else "A_ghost"+str(ghost),facing)
	if battle==null:return
	if ghost==0:
		_tap(battle,KEY_A)
		await _exact_main(battle,"skill_a",27)
		_idle(battle,60);_audio_frames(6446,[27])
	else:
		var key: String=action_expected.a.setup_keys[str(ghost)]
		_cast(battle,FIELD_KEYS[key],"skill_"+key);_idle(battle,35)
		_check("real field establishes ghost type "+str(ghost),_until(battle,func()->bool:return int(battle.crt4.ghost_type)==ghost,30),_snapshot(battle))
		_down(battle,KEY_A)
		if await _exact_main(battle,"skill_a",26,35):
			var charge:=_views_for(battle,[6418],1,false)
			_check("A26 new independent charge begins at child1",charge.size()==1 and charge[0].source_frame==1,charge.map(func(view:Node2D)->Dictionary:return _visual_metadata(view)))
			await _pair(battle,"charge_child1",charge)
			_tick(battle,5)
			charge=_views_for(battle,[6418],1,false)
			_check("held A keeps parent26 while child reaches empty6",battle.player.source_frame==26 and charge.size()==1 and charge[0].source_frame==6,_snapshot(battle))
			for frame: int in range(1,7):_check("charge independent child visits"+str(frame),_seen_frame(6418,frame))
			await _pair(battle,"charge_child6_empty",charge,false)
			_up(battle,KEY_A);_tick(battle)
			await _exact_main(battle,"skill_a",49)
			await _pair_sources(battle,"charge_removed_after_release",[6418],false)
			var branch: Array=action_expected.a.ghost_branches[str(ghost)]
			await _exact_main(battle,"skill_a",int(branch[0]),30)
			# Keep the entry capture and naturally advance to the distinct follow-up
			# source61/89/117; no seek, injected action or skipped sound consumers.
			await _exact_main(battle,"skill_a",int(branch[0])+3,5)
			_idle(battle,50)
			_audio_frames(6446,[8,49,int(branch[0])+1,int(branch[0])+2])
	await _finish_action(battle)

func _s_gpu(facing: int) -> void:
	var battle:=await _fresh_gpu("S_chain",facing)
	if battle==null:return
	_tap(battle,KEY_S);await _exact_main(battle,"skill_s",3)
	var ready:=_frame(battle,"skill_s",5,8)
	_check("S real listener window5 reached",ready,_snapshot(battle))
	if ready:
		_tap(battle,KEY_S);await _exact_main(battle,"skill_s",11)
		ready=_frame(battle,"skill_s",17,10)
		_check("S real listener window17 reached",ready,_snapshot(battle))
		if ready:_tap(battle,KEY_S);await _exact_main(battle,"skill_s",24)
	_idle(battle,45);_audio_frames(6458,[3,13,26])
	await _finish_action(battle)

func _z_gpu(facing: int,from_hurt: bool) -> void:
	var battle:=await _fresh_gpu("hurt_Z" if from_hurt else "Z",facing)
	if battle==null:return
	if from_hurt:
		fixtures.append({"case":current_case,"kind":"public receive_damage(1), production reaction; not natural enemy-AI acceptance","tick":battle.session.run.source_ticks})
		battle.player.receive_damage(1.0)
		_check("public hurt selects source169",battle.player.state=="hit" and battle.player.parent_frame==169,_snapshot(battle))
		await _exact_main(battle,"hit",1)
	_tap(battle,KEY_Z);await _exact_main(battle,"skill_z",6)
	_idle(battle,25);_audio_frames(6511,[2])
	await _finish_action(battle)

func _q_gpu(facing: int) -> void:
	var battle:=await _fresh_gpu("Q_contact_status",facing)
	if battle==null:return
	_target_fixture(battle,45,10000)
	_tap(battle,KEY_Q)
	var born:=_until(battle,func()->bool:return not _object(battle,3951).is_empty(),20)
	_check("actual Q contact creates target-owned3951",born,_snapshot(battle))
	if born:
		var status:=_object(battle,3951)
		_check("new Q target child is explicitly source2",int(status.frame)==2,status)
		var entered:=_sounds_for(3951,3950)
		_check("new status2 consumes Sound3950 on its actual birth tick",entered.size()==1 and int(entered[0].tick)==int(status.born),entered)
		await _pair(battle,"Q_main_at_status_birth",[battle.player.visual])
		await _pair_sources(battle,"Q_target_status_first2",[3951])
		if _wait_drawing(battle,[3951],9,15):await _pair_sources(battle,"Q_target_status_active9",[3951])
	_idle(battle,30)
	_check("Q target state outlives main action",battle.player.state=="idle" and not _object(battle,3951).is_empty(),_snapshot(battle))
	_audio_frames(6487,[7]);_audio_frames(3951,[2])
	await _finish_action(battle)

func _v_gpu(facing: int,contact: bool) -> void:
	var battle:=await _fresh_gpu("V_contact" if contact else "V_empty",facing)
	if battle==null:return
	if contact:_target_fixture(battle,35,5000)
	_tap(battle,KEY_V)
	if contact:
		_check("real V helper acquires target",_until(battle,func()->bool:return not battle.zab.is_empty(),10),_snapshot(battle))
		await _exact_main(battle,"skill_v",17)
		await _exact_main(battle,"skill_v",36,30)
		_idle(battle,70)
		_check("V actual contact damages and releases captured target",battle.enemies[0].hp<5000 and battle.zab.is_empty(),_snapshot(battle))
		_audio_frames(6541,[5,17,26,29])
	else:
		await _exact_main(battle,"skill_v",5)
		_check("empty V returns through original short route",_idle(battle,20) and battle.zab.is_empty() and not _local_samples().any(func(row:Dictionary)->bool:return row.state=="skill_v" and int(row.frame)>=17),_snapshot(battle))
		_audio_frames(6541,[5])
	await _finish_action(battle)

func _air_gpu(facing: int,kalla: bool) -> void:
	var battle:=await _fresh_gpu("Kalla_air_X" if kalla else "ordinary_air_X",facing)
	if battle==null:return
	if kalla:_check("Kalla activated by actual T",_start_kalla(battle),_snapshot(battle))
	_tap(battle,KEY_C);await _exact_main(battle,"jump",2)
	_check("original jump child placement4 reached",_frame(battle,"jump",4,6),_snapshot(battle))
	# The original6528 uses held polling, independently of a ground keyDown event.
	Input.action_press("attack");_tick(battle);_release()
	var child_frame:=15 if kalla else 4
	var ready:=_until(battle,func()->bool:return int(battle.crt4.air_frame)==child_frame,12)
	_check("held airX reaches source6528 branch"+str(child_frame),ready,_snapshot(battle))
	if ready:
		# Source6530 is explicitly empty from4; the actual child supplies the body.
		await _pair(battle,"jump_main_original_empty",[battle.player.visual],false)
		await _pair_sources(battle,"actual_air_body_"+str(child_frame),[6528])
		if kalla:
			_check("Kalla child15 creates real diagonal clone1154",not _object(battle,1154).is_empty(),_snapshot(battle))
			if _wait_drawing(battle,[1149],1,10):await _pair_sources(battle,"Kalla_air_clone",[1149])
	_idle(battle,60);_audio_frames(6530,[2,28]);_audio_frames(6528,[14] if kalla else [3])
	await _finish_action(battle)

func _w_move_gpu(facing: int) -> void:
	var battle:=await _fresh_gpu("W_independent_move",facing)
	if battle==null:return
	_tap(battle,KEY_W);await _exact_main(battle,"skill_w",7)
	_check("real W activates independent ghost movement",_idle(battle,35) and _until(battle,func()->bool:return int(battle.crt4.ghost_step)==1,25),_snapshot(battle))
	var sound_start:=sounds.size()
	Input.action_press("move_right" if facing==1 else "move_left")
	_tick(battle,11)
	await _pair_sources(battle,"W_move_independent_body11",[6393])
	_tick(battle,12)
	await _pair_sources(battle,"W_move_body_second11",[6393])
	_release();_tick(battle)
	var footsteps:=sounds.slice(sound_start).filter(func(row:Dictionary)->bool:return int(row.source_id)==6393 and int(row.sound_id)==4616)
	_check("W source6393 steps play once per independent12-frame loop",footsteps.size()==2 and int(footsteps[1].tick)-int(footsteps[0].tick)==12,footsteps)
	_sound_requirements(6489,1);_sound_requirements(6360,1)
	await _finish_action(battle)

func _run() -> void:
	output=OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if output.is_empty():output="res://artifacts/leba_act06_20261117/crt4_actions_window/run_%d_%d"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	OS.set_environment("LEBA_TEST_MODE","1");OS.set_environment("LEBA_SILENT_TEST","1")
	OS.set_environment("LEBA_TEST_PROFILE","user://act06_crt4_actions_render/%d_%d/profile.json"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()])
	var requested:=OS.get_environment("LEBA_ACTION_RENDER_CASES")
	if not requested.is_empty():case_filter=requested.split(",",false)
	formal_exists=FileAccess.file_exists("user://profile.json")
	if formal_exists:formal_hash=FileAccess.get_sha256("user://profile.json")
	expected=JSON.parse_string(FileAccess.get_file_as_string(EXPECTED))
	action_expected=JSON.parse_string(FileAccess.get_file_as_string(ACTION_EXPECTED));gpu_hashes=_gpu_integrity()
	root.size=Vector2i(550,400)
	_check("actual GL display required",DisplayServer.get_name()!="headless")
	_check("all requested action groups are known",Array(case_filter).all(func(group:String)->bool:return group in GROUPS),case_filter)
	if DisplayServer.get_name()=="headless" or not checks.back().passed:quit(2);return
	app=MainScene.instantiate();root.add_child(app);app.set_process(false);await process_frame
	_check("formal Main uses isolated test profile",app.startup_ok and app.test_mode and app.saves.path!="user://profile.json",app.database.issues)
	if app.startup_ok:
		app.audio.sound_played.connect(_on_sound)
		for facing: int in [1,-1]:
			if _wanted("x"):await _x_gpu(facing)
			if _wanted("a_early"):await _a_gpu(facing,0)
			for ghost: int in [1,2,3]:
				if _wanted("a_ghost"+str(ghost)):await _a_gpu(facing,ghost)
			if _wanted("s"):await _s_gpu(facing)
			if _wanted("z"):await _z_gpu(facing,false)
			if _wanted("hurt_z"):await _z_gpu(facing,true)
			if _wanted("q"):await _q_gpu(facing)
			if _wanted("v_contact"):await _v_gpu(facing,true)
			if _wanted("v_empty"):await _v_gpu(facing,false)
			if _wanted("air"):await _air_gpu(facing,false)
			if _wanted("kalla_air"):await _air_gpu(facing,true)
			if _wanted("w_move"):await _w_move_gpu(facing)
	_release();app._dispose_battle();await _complete_exit_frame()
	_check("actual Dummy audio drains within unchanged1s deadline",await app.audio.stop_and_drain(1.0))
	app.queue_free();await process_frame
	_check("runtime/authors/catalog/reviewer bytes unchanged",_gpu_integrity()==gpu_hashes)
	_check("formal profile unchanged",FileAccess.file_exists("user://profile.json")==formal_exists and (not formal_exists or FileAccess.get_sha256("user://profile.json")==formal_hash))
	_check("observed audio uses real streams and offsets",not sounds.is_empty() and sounds.all(func(row:Dictionary)->bool:return row.valid and row.offset>=0 and row.offset<row.length))
	var failures: int=checks.filter(func(row:Dictionary)->bool:return not row.passed).size()
	var report:=FileAccess.open(output.path_join("review.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"pairs":gpu_pairs,"cases":gpu_cases,"sound_requests":sounds,"sound_coverage":audio_coverage,"events":world_events,"source_samples":world_samples,"fixtures":fixtures,"hashes":gpu_hashes,"source_oracle":ACTION_EXPECTED,"source_audio_snapshot_sha256":AUDIO_SOURCE_SNAPSHOT_SHA256,"requested_groups":case_filter,"coverage":"all14 groups both facings" if case_filter.is_empty() else "explicit filtered partial run","renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"godot":Engine.get_version_info(),"method":"Actual GL550x400, Dummy audio. Normal title Training selector, real InputEventKey/InputMap/take_commands source steps. Main SourceSprite hidden alone on same tick; separate child visibility pairs for original main-empty air, A charge and Q status. No action/frame/cost/marker/timer injection. One-time finite HP/space and labelled public hurt fixtures only. Real engine exit frame, unchanged1s audio drain.","visual_review":"pending image inspection","not_tested":["Audible listening","Natural OS keyboard dispatch","Original Flash complete dynamic action comparison","Hurt-Z fixture is not natural enemy AI acceptance"]},"\t")+"\n")
	print("ACT06_CRT4_ACTIONS_GPU "+JSON.stringify({"checks":checks.size(),"failures":failures,"pairs":gpu_pairs.size(),"cases":gpu_cases.size(),"output":output}))
	quit(0 if failures==0 else 1)
