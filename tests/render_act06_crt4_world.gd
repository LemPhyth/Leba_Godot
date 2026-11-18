extends "res://tests/test_act06_crt4_world.gd"
## Actual GL evidence, not an alternate gameplay runner. Normal Main selection,
## real InputMap/key events and production source/ms clocks; Dummy audio only.
## Same-tick visibility pairs alter drawing visibility only, then restore it.
const SourceSprite = preload("res://scripts/combat/source_sprite.gd")
const FIELD_DRAW_SOURCES := {"d":[313,312],"f":[954,953],"g":[816,813],"h":[1120,1117]}
var gpu_pairs: Array[Dictionary]=[]
var gpu_cases: Array[Dictionary]=[]
var gpu_hashes: Dictionary={}
var case_filter: PackedStringArray=[]

func _gpu_integrity() -> Dictionary:
	var result:=_integrity()
	for path: String in ["res://tests/render_act06_crt4_world.gd","res://tests/test_act06_crt4_world.gd","res://scripts/combat/source_sprite.gd","res://scripts/content/source_animation.gd","res://scenes/main.tscn","res://project.godot"]:
		result[path]=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "MISSING"
	return result

func _wanted(group: String) -> bool:
	return case_filter.is_empty() or group in case_filter

func _source_views(node: Node) -> Array:
	var result: Array=[]
	if not is_instance_valid(node) or node.is_queued_for_deletion():return result
	if node.get_script()==SourceSprite:result.append(node)
	for child: Node in node.get_children():result.append_array(_source_views(child))
	return result

func _matrix_array(value: Transform2D) -> Array:
	return [value.x.x,value.x.y,value.y.x,value.y.y,value.origin.x,value.origin.y]

func _screen_bounds(view: Node2D) -> Rect2:
	var alpha: Array=view.frame.get("alpha_bounds",[])
	if alpha.size()!=4 or float(alpha[2])<=0 or float(alpha[3])<=0:return Rect2()
	var scale_row: Array=view.definition.get("parent_scale",[1,1])
	var rect:=Rect2(Vector2(alpha[0],alpha[1])*Vector2(scale_row[0],scale_row[1]),Vector2(alpha[2],alpha[3])*Vector2(scale_row[0],scale_row[1]))
	return view.get_global_transform_with_canvas()*rect

func _has_screen_ink(view: Node2D) -> bool:
	return view.is_visible_in_tree() and view.modulate.a>0 and _screen_bounds(view).intersection(Rect2(0,0,550,400)).has_area()

func _views_for(battle: Node2D,sources: Array,minimum_frame:=1,screen_only:=true) -> Array:
	return _source_views(battle).filter(func(view:Node2D)->bool:return _visual_source_id(view) in sources and view.source_frame>=minimum_frame and (not screen_only or _has_screen_ink(view)))

func _wait_drawing(battle: Node2D,sources: Array,minimum_frame:=1,cap:=120) -> bool:
	var okay:=_until(battle,func()->bool:return not _views_for(battle,sources,minimum_frame).is_empty(),cap)
	_check("actual source drawing reaches screen "+str(sources),okay,{"minimum_frame":minimum_frame,"state":_snapshot(battle)})
	return okay

func _visual_metadata(view: Node2D) -> Dictionary:
	var box:=_screen_bounds(view)
	var path:=str(view.definition.get("texture",""))
	return {"node":str(view.get_path()),"instance_id":view.get_instance_id(),"source_id":_visual_source_id(view),"source_frame":view.source_frame,"texture":path,"texture_sha256":FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "","atlas_frame":view.frame.duplicate(true),"global_matrix":_matrix_array(view.get_global_transform_with_canvas()),"local_matrix":_matrix_array(view.transform),"alpha":view.modulate.a,"z_index":view.z_index,"z_relative":view.z_as_relative,"screen_bounds":[box.position.x,box.position.y,box.size.x,box.size.y],"viewport_area":box.intersection(Rect2(0,0,550,400)).get_area()}

func _assert_world_view_lifecycle(battle: Node2D,phase: String,require_retired_freed:=false) -> void:
	var invalid: Array=[]
	for key: String in battle._crt4_views:
		var issue:=_visual_liveness_issue(battle._crt4_views[key])
		if not issue.is_empty():invalid.append({"key":key,"issue":issue})
	for item: Dictionary in _objects(battle):
		var issue:=_visual_liveness_issue(item.get("visual"))
		if not issue.is_empty():invalid.append({"source_id":item.source_id,"id":item.id,"issue":issue})
	_check("GPU boundary retains only live registered source views: "+phase,invalid.is_empty(),invalid)
	var resurrected: Array=[]
	var retired:=_events("crt4_world_retired")
	for row: Dictionary in retired:
		var prefix:="world_%d_"%int(row.id)
		var old_name:="Source%d_%d"%[int(row.source_id),int(row.id)]
		var old_root: Variant=battle.find_child(old_name,true,false)
		var retained_keys: Array=battle._crt4_views.keys().filter(func(key:String)->bool:return key.begins_with(prefix))
		var retained_items: Array=_objects(battle).filter(func(item:Dictionary)->bool:return int(item.id)==int(row.id))
		var root_survives: bool=is_instance_valid(old_root) and (require_retired_freed or not old_root.is_queued_for_deletion())
		if root_survives or not retained_keys.is_empty() or not retained_items.is_empty():
			resurrected.append({"retirement":row,"root_name":old_name,"root_still_live":root_survives,"drawing_keys":retained_keys,"live_object_count":retained_items.size()})
	_check("retired source roots cannot resurrect views: "+phase,resurrected.is_empty(),{"retired_count":retired.size(),"require_frame_end_free":require_retired_freed,"violations":resurrected})

func _pair(battle: Node2D,phase: String,selected: Array,expect_ink:=true) -> void:
	app.ui.update_hud(battle.snapshot(),false)
	app.ui.set_world_offset(battle.position)
	await process_frame;RenderingServer.force_draw(false)
	_assert_world_view_lifecycle(battle,phase+" before GPU toggle")
	var before: int=battle.session.run.source_ticks
	var ms_before: float=battle.real_time_ms
	var normal: Image=root.get_texture().get_image()
	var path:=output.path_join(current_case+"_"+phase+".png")
	_check("GL viewport is550x400",normal!=null and normal.get_size()==Vector2i(550,400))
	if normal==null:return
	_check("save actual world framebuffer "+phase,normal.save_png(path)==OK)
	var views: Array=[];var old_visibility: Array=[];var bounds:=Rect2()
	for value: Variant in selected:
		# A real source child may retire before the awaited GPU frame. Validate
		# the Variant before assigning a typed node; retain the positive-ink
		# assertion so an expired selection cannot become a fabricated pass.
		if not is_instance_valid(value) or not value is Node2D or value.is_queued_for_deletion():continue
		var view: Node2D=value
		views.append(_visual_metadata(view));old_visibility.append({"view":view,"visible":view.visible})
		var box:=_screen_bounds(view).intersection(Rect2(0,0,550,400))
		if box.has_area():bounds=box if not bounds.has_area() else bounds.merge(box)
		view.visible=false
	await process_frame;RenderingServer.force_draw(false)
	var hidden: Image=root.get_texture().get_image()
	var hidden_path:=output.path_join(current_case+"_"+phase+"_hidden.png")
	_check("save same-tick hidden comparison",hidden!=null and hidden.save_png(hidden_path)==OK)
	for row: Dictionary in old_visibility:
		if is_instance_valid(row.view):row.view.visible=row.visible
	await process_frame;RenderingServer.force_draw(false)
	_assert_world_view_lifecycle(battle,phase+" after GPU restore")
	var changed:=0;var outside:=0
	if hidden!=null:
		for y in range(400):
			for x in range(550):
				if normal.get_pixel(x,y)!=hidden.get_pixel(x,y):
					if bounds.has_point(Vector2(x+.5,y+.5)):changed+=1
					else:outside+=1
	var row:={"case":current_case,"phase":phase,"image":path,"hidden_image":hidden_path,"image_sha256":FileAccess.get_sha256(path),"hidden_sha256":FileAccess.get_sha256(hidden_path),"source_tick":before,"milliseconds":ms_before,"state":_snapshot(battle),"selected_visuals":views,"viewport_bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"selected_changed_pixels":changed,"outside_changed_pixels":outside,"expected_visible":expect_ink,"source_and_ms_unchanged":before==battle.session.run.source_ticks and is_equal_approx(ms_before,battle.real_time_ms),"manual_visual_review":"pending","audible_review":"未试听"}
	gpu_pairs.append(row)
	_check("same-tick drawing toggle never advances source or ms clocks",bool(row.source_and_ms_unchanged))
	_check("actual selected GPU ink "+phase,changed>0 if expect_ink else changed==0,row)

func _pair_sources(battle: Node2D,phase: String,sources: Array,expect_ink:=true) -> void:
	await _pair(battle,phase,_views_for(battle,sources,1,expect_ink),expect_ink)

func _main_pose(battle: Node2D,action: String,frame: int) -> void:
	var reached:=_frame(battle,action,frame,35)
	_check("normal input reaches main pose "+action+"/"+str(frame),reached,_snapshot(battle))
	if reached:await _pair(battle,"main_"+action+"_"+str(battle.player.source_frame),[battle.player.visual])

func _fresh_gpu(label: String,facing: int,stage:="root_41") -> Node2D:
	# Let prior queue_free and the engine's audio mix/update reach a frame end.
	# This does not change the service deadline or fabricate a drained result.
	if is_instance_valid(app.battle):app._dispose_battle()
	await _complete_exit_frame()
	var battle:=_world_fresh("GPU_"+label,facing,stage)
	if battle==null:return null
	await process_frame
	gpu_cases.append({"case":current_case,"group":label,"facing":facing,"stage":stage,"input":"normal title/Training/CRT4; InputEventKey + InputMap held + take_commands/step","space_fixture":"Initial offscreen isolation; optional single finite-HP enemy placement before input. No action, frame, flag, marker, cooldown or object injection.","source_tick":battle.session.run.source_ticks,"sound_start":sounds.size(),"pair_start":gpu_pairs.size(),"manual_visual_review":"pending","audible_review":"未试听"})
	return battle

func _finish_gpu(battle: Node2D) -> void:
	_release()
	await _complete_exit_frame()
	_assert_world_view_lifecycle(battle,"case actual engine frame end",true)
	gpu_cases.back()["terminal"]=_snapshot(battle)
	gpu_cases.back()["sounds"]=sounds.slice(int(gpu_cases.back().sound_start))
	var views:=_source_views(battle)
	app.show_title();await _complete_exit_frame();RenderingServer.force_draw(false)
	_check("normal title exit disposes encounter and source visuals",app.battle==null and not is_instance_valid(battle) and views.all(func(view:Variant)->bool:return not is_instance_valid(view)))

func _field_gpu(key: String,facing: int) -> void:
	var battle:=await _fresh_gpu("field_"+key,facing)
	if battle==null:return
	_target_fixture(battle,100 if key in ["g","h"] else 45,10000)
	if _cast(battle,FIELD_KEYS[key],"skill_"+key):
		await _main_pose(battle,"skill_"+key,7)
		if _wait_drawing(battle,FIELD_DRAW_SOURCES[key],1,25):await _pair_sources(battle,"field_active",FIELD_DRAW_SOURCES[key])
		var sid:=int(expected.fields[key].source_id)
		# The early drawing exists before the original active flag (Saya source9).
		# Observing initial false is not observing expiry.
		_check("field original active flag is reached before expiry",_until(battle,func()->bool:return _flag(battle,sid),25))
		_idle(battle,35)
		if key in ["d","f"]:
			_tap(battle,KEY_X)
			if _wait_drawing(battle,[578],1,25):await _pair_sources(battle,"actual_X_dark_contact",[578])
		elif key=="h":
			if _wait_drawing(battle,[978],20,150):await _pair_sources(battle,"independent_mummy_contact",[978,556])
		else:
			_check("G actual helper freezes target",_until(battle,func()->bool:return battle.enemies[0].frozen,50))
			await _pair_sources(battle,"frozen_contact_field",FIELD_DRAW_SOURCES[key])
		# First contact creates the real marker/status; damage occurs later on
		# its own source clock. Rhasa's independent mummy waits through source200.
		_check("actual field/contact chain changes finite HP",_until(battle,func()->bool:return battle.enemies[0].hp<10000,220),_snapshot(battle))
		_check("field reaches original flag expiry",_until(battle,func()->bool:return not _flag(battle,sid),int(expected.fields[key].flag_off_and_stop_frame)+10))
		await _pair_sources(battle,"field_empty_after_expiry",FIELD_DRAW_SOURCES[key],false)
		_sound_requirements(sid,1)
	await _finish_gpu(battle)

func _ghost_gpu(facing: int) -> void:
	var battle:=await _fresh_gpu("ghostwalk",facing)
	if battle==null:return
	if _cast(battle,KEY_W,"skill_w"):
		await _main_pose(battle,"skill_w",7)
		if _wait_drawing(battle,[6360],13,30):await _pair_sources(battle,"6360_flag_on",[6360])
		_idle(battle,30);Input.action_press("move_right" if facing==1 else "move_left")
		if _wait_drawing(battle,[6395],5,45):await _pair_sources(battle,"independent_walk_clock",[6395])
		_release();_tick(battle)
		_check("W independent timer expires normally",_until(battle,func()->bool:return int(battle.crt4.ghost_step)==0,580))
		await _pair_sources(battle,"ghost_expired",[6360,6395,6402],false)
		_sound_requirements(6360,1)
	await _finish_gpu(battle)

func _kalla_gpu(facing: int,kind: String) -> void:
	var battle:=await _fresh_gpu("kalla_"+kind,facing)
	if battle==null:return
	if not _cast(battle,KEY_T,"skill_t"):await _finish_gpu(battle);return
	if kind=="contact":await _main_pose(battle,"skill_t",7)
	_idle(battle,40)
	if _wait_drawing(battle,[6378],2,20) and kind=="contact":await _pair_sources(battle,"persistent_kalla_body",[6378])
	if kind=="contact":_target_fixture(battle,110,10000);_tap(battle,KEY_X)
	elif kind=="air":_tap(battle,KEY_C);_down(battle,KEY_X)
	else:_tap(battle,KEY_DOWN);_down(battle,KEY_X)
	if _wait_drawing(battle,[1149],1,35):await _pair_sources(battle,"actual_"+kind+"_flight",[1149])
	_release()
	if _wait_drawing(battle,[1153],1,55):await _pair_sources(battle,"independent_impact",[1153])
	_idle(battle,70)
	if kind=="contact":
		_check("ground clone actual contact changes finite HP",battle.enemies[0].hp<10000,_snapshot(battle))
		_tap(battle,KEY_T)
		await _main_pose(battle,"t_finish",15)
		_idle(battle,70)
		_check("second actual T clears state",int(battle.crt4.kalla)==0,_snapshot(battle))
	await _finish_gpu(battle)

func _r_gpu(facing: int) -> void:
	var battle:=await _fresh_gpu("tombstones",facing)
	if battle==null:return
	_target_fixture(battle,50,15000);seed(60640+facing)
	if _cast(battle,KEY_R,"skill_r"):
		await _main_pose(battle,"skill_r",7)
		if _wait_drawing(battle,[1273],5,25):await _pair_sources(battle,"world_tombstones_contact",[1273])
		_idle(battle,100);_tick(battle,40)
		_check("R damages actual finite target",battle.enemies[0].hp<15000,_snapshot(battle))
		# Source1023 is a seven-frame sprite, not a morph shape. Its four
		# instances are born at1273/5 and independently stop on empty frame7.
		# The root remains at31, but retaining it must not retain visible dust.
		_check("R reaches its original stationary terminal31",_objects(battle,1273).size()>0 and _objects(battle,1273).all(func(item:Dictionary)->bool:return int(item.frame)==31))
		await _pair_sources(battle,"tombstone_stationary_stop31_empty",[1273],false)
		_sound_requirements(1273,_events("crt4_world_born",1273).size())
	await _finish_gpu(battle)

func _e_gpu(facing: int,held: bool) -> void:
	var battle:=await _fresh_gpu("E_"+("held" if held else "release"),facing)
	if battle==null:return
	_target_fixture(battle,45,10000)
	if _cast(battle,KEY_E,"skill_e",held):
		await _main_pose(battle,"skill_e",2)
		if _wait_drawing(battle,[6835],130,28):await _pair_sources(battle,"cutin130_screen_ink",[6835])
		if _wait_drawing(battle,[3962],16,60):await _pair_sources(battle,"independent_target3962",[3962])
		if held:
			if _wait_drawing(battle,[6505],1,30):await _pair_sources(battle,"held_local_dark45",[6505])
			_up(battle,KEY_E)
		_idle(battle,80)
		_check("real E target loses HP",battle.enemies[0].hp<10000,_snapshot(battle))
		_check("real source20 creates E timer",_until(battle,func()->bool:return not _events("crt4_fly_interval_created").is_empty(),30))
		_ms(battle,.04);_ms(battle,1.1)
		_check("E actual ms callback and timeout observed",not _events("crt4_fly_interval_fired").is_empty() and not _events("crt4_fly_interval_cleared").is_empty())
		_sound_requirements(3962)
	await _finish_gpu(battle)

func _y_gpu(facing: int,six_flags: bool,stage:="root_41") -> void:
	var battle:=await _fresh_gpu("Y_"+("six_flags" if six_flags else "zero_flags")+"_"+stage,facing,stage)
	if battle==null:return
	_check("Y ready291 reached naturally",_until(battle,func()->bool:return int(battle.crt4.y_slot_frame)==291,310))
	if six_flags:
		for key: String in FIELD_KEYS:_cast(battle,FIELD_KEYS[key],"skill_"+key);_idle(battle,30)
		_cast(battle,KEY_W,"skill_w");_idle(battle,30);_start_kalla(battle)
		_check("six Y flags come from real earlier skills",[316,956,818,1121].all(func(sid:int)->bool:return _flag(battle,sid)) and int(battle.crt4.ghost_step)==1 and int(battle.crt4.kalla)==1)
	# Root9 is the independent background/depth check. Its enemies remain at the
	# declared initial offscreen fixture; contact is verified in normal training.
	if stage=="root_41":_target_fixture(battle,100,25000)
	if _cast(battle,KEY_Y,"skill_y"):
		if not six_flags:await _main_pose(battle,"skill_y",1)
		if _wait_drawing(battle,[6835],130,28) and not six_flags:await _pair_sources(battle,"Y_cutin130_screen_ink",[6835])
		if _wait_drawing(battle,[932],1,35) and not six_flags:await _pair_sources(battle,"swamp944_independent_cells",[932])
		_idle(battle,40)
		# The first central942/4 is legitimately behind the player: the original
		# rootq=-16300 maps to84, below source player801/1014. At943/10 a second
		# independent942 is placed at(50.85,2.75); its source8 at943/17 provides
		# a readable side sample without changing input, depth or actor position.
		var side_wisp_reached:=_until(battle,func()->bool:return _objects(battle,943).any(func(item:Dictionary)->bool:return int(item.frame)>=17) and _views_for(battle,[942],8).any(func(view:Node2D)->bool:return view.source_frame==8),45)
		_check("Y reaches original side942 source8 after943 source17",side_wisp_reached,_snapshot(battle))
		if side_wisp_reached:
			var side_views:=_views_for(battle,[942],8).filter(func(view:Node2D)->bool:return view.source_frame==8)
			var roots944:=_objects(battle,944)
			var roots943:=_objects(battle,943)
			var original_back_layer: bool=roots944.size()==1 and roots943.size()==1
			if original_back_layer:
				var root944: Node2D=roots944[0].visual
				var root943: Node2D=roots943[0].visual
				original_back_layer=int(roots944[0].depth)==-16300 and root944.z_index==84 and root944.get_canvas()==root943.get_canvas() and root944.get_canvas()==battle.player.visual.get_canvas() and root944.z_index<battle.player.z_index
			_check("Y942 retains original negative-depth swamp canvas behind player",original_back_layer,{"player_z":battle.player.z_index,"state":_snapshot(battle)})
			await _pair(battle,"controller943_independent_wisps_side8",side_views)
			var wisp_pair: Dictionary=gpu_pairs.back()
			var box: Array=wisp_pair.viewport_bounds
			var projected_area: float=float(box[2])*float(box[3])
			# This is a screenshot legibility gate, not an original gameplay rule.
			# Reject the former36px sliver; preserve the source's correct occlusion.
			wisp_pair["review_minimum_changed_pixels"]=maxi(128,int(ceil(projected_area*.10)))
			wisp_pair["review_projected_area"]=projected_area
			wisp_pair["review_gate_scope"]="Readable side942 evidence; no claim of Flash pixel equality."
			_check("Y side942 contributes a readable source drawing, not only a few edge pixels",int(wisp_pair.selected_changed_pixels)>=int(wisp_pair.review_minimum_changed_pixels),wisp_pair)
		if _wait_drawing(battle,[906],4,150) and not six_flags:await _pair_sources(battle,"907_body906_first_attack",[906])
		if _wait_drawing(battle,[906],25,40):await _pair_sources(battle,"907_body906_final_attack",[906])
		_check("Y world continues after actor return",battle.player.state=="idle",_snapshot(battle))
		if stage=="root_41":_check("world Y actual contact changes finite targetHP",battle.enemies[0].hp<25000,_snapshot(battle))
		_check("Y slot resumes only after actual child40",_until(battle,func()->bool:return bool(battle.crt4.y_slot_playing),50))
		await _pair_sources(battle,"906_empty_terminal40",[906],false)
		_sound_requirements(906,1)
	await _finish_gpu(battle)

func _run() -> void:
	output=OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if output.is_empty():output="res://artifacts/leba_act06_20261117/crt4_world_window/run_%d_%d"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	OS.set_environment("LEBA_TEST_MODE","1");OS.set_environment("LEBA_SILENT_TEST","1")
	OS.set_environment("LEBA_TEST_PROFILE","user://act06_crt4_world_render/%d_%d/profile.json"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()])
	var requested:=OS.get_environment("LEBA_WORLD_RENDER_CASES")
	if not requested.is_empty():case_filter=requested.split(",",false)
	formal_exists=FileAccess.file_exists("user://profile.json")
	if formal_exists:formal_hash=FileAccess.get_sha256("user://profile.json")
	expected=JSON.parse_string(FileAccess.get_file_as_string(EXPECTED));gpu_hashes=_gpu_integrity()
	root.size=Vector2i(550,400)
	_check("actual GL display is required for GPU evidence",DisplayServer.get_name()!="headless")
	if DisplayServer.get_name()=="headless":quit(2);return
	app=MainScene.instantiate();root.add_child(app);app.set_process(false);await process_frame
	_check("formal isolated Main starts",app.startup_ok and app.test_mode and app.saves.path!="user://profile.json",app.database.issues)
	if app.startup_ok:
		app.audio.sound_played.connect(_on_sound)
		for facing: int in [1,-1]:
			for key: String in FIELD_KEYS:
				if _wanted("field_"+key):await _field_gpu(key,facing)
			if _wanted("w"):await _ghost_gpu(facing)
			if _wanted("t"):
				for kind: String in ["contact","air","back"]:await _kalla_gpu(facing,kind)
			if _wanted("r"):await _r_gpu(facing)
			if _wanted("e"):await _e_gpu(facing,false);await _e_gpu(facing,true)
			if _wanted("y"):await _y_gpu(facing,false);await _y_gpu(facing,true)
			if _wanted("root9"):await _y_gpu(facing,false,"root_9")
	_release();app._dispose_battle();await _complete_exit_frame()
	_check("actual Dummy playback drains within unchanged1s deadline",await app.audio.stop_and_drain(1.0))
	app.queue_free();await process_frame
	_check("runtime/authors/catalog/reviewer bytes unchanged",_gpu_integrity()==gpu_hashes)
	_check("formal profile untouched",FileAccess.file_exists("user://profile.json")==formal_exists and (not formal_exists or FileAccess.get_sha256("user://profile.json")==formal_hash))
	_check("all observed sounds use real valid streams and offsets",not sounds.is_empty() and sounds.all(func(row:Dictionary)->bool:return row.valid and row.offset>=0 and row.offset<row.length))
	var failures: int=checks.filter(func(row:Dictionary)->bool:return not row.passed).size()
	var report:=FileAccess.open(output.path_join("review.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"pairs":gpu_pairs,"cases":gpu_cases,"sound_requests":sounds,"events":world_events,"source_samples":world_samples,"fixtures":fixtures,"hashes":gpu_hashes,"source_oracle":EXPECTED,"requested_groups":case_filter,"coverage":"all configured groups" if case_filter.is_empty() else "explicitly filtered partial run","renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"godot":Engine.get_version_info(),"method":"Real GL550x400 with Dummy. Actual normal Main selection and production input/source/ms clocks. Same-tick visual hide/restore only; no injected skill, marker, cooldown, object or sound. Title exit between cases; normal engine frame end before1s audio drain.","visual_review":"pending human/image inspection","not_tested":["Audible listening","Natural OS keyboard dispatch","Original Flash dynamic world callback phase and whole-skill damage equality"]},"\t")+"\n")
	print("ACT06_CRT4_WORLD_GPU "+JSON.stringify({"checks":checks.size(),"failures":failures,"pairs":gpu_pairs.size(),"cases":gpu_cases.size(),"output":output}))
	quit(0 if failures==0 else 1)
