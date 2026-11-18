extends SceneTree
## Real Main actors, authored atlas frames and shared input. Geometry assertions
## use the actual SourceSprite draw rectangle transformed into stage pixels.
## Only the stage entry and one-time distant enemy positions are fixtures.
## No action, source frame, cooldown, ready slot, MP or cube count is assigned.
const MainScene=preload("res://scenes/main.tscn")
const Save=preload("res://scripts/services/save_store.gd")
const STAGE_RECT:=Rect2(0,0,550,400)
const ACTIONS:=["move_left","move_right","attack","skill","skill_s","jump","down","skill_z","skill_a","skill_w","load_f","load_g","load_h","skill_q","skill_t","skill_e","skill_r","skill_y","skill_v","aim_up"]
const CASES:=[
 ["crt_2","root_2",KEY_R,"skill_r","r_cutin",430,71,97,"hud_crt2_r_cutin"],
 ["crt_2","root_4",KEY_R,"skill_r","r_cutin",430,71,97,"hud_crt2_r_cutin"],
 ["crt_2","root_6",KEY_R,"skill_r","r_cutin",430,71,97,"hud_crt2_r_cutin"],
 ["crt_2","root_9",KEY_R,"skill_r","r_cutin",430,71,97,"hud_crt2_r_cutin"],
 ["crt_2","root_41",KEY_R,"skill_r","r_cutin",430,71,97,"hud_crt2_r_cutin"],
 ["crt_0","root_9",KEY_Y,"skill_y","cutin",533,7,33,"hud_y_cutin"],
 ["crt_1","root_9",KEY_T,"skill_t","awakening_cutin",405,39,65,"hud_crt1_t_cutin"]]
var app: Node
var checks: Array[Dictionary]=[]
var observations: Array[Dictionary]=[]
var current_case:="startup"
var formal_exists:=false
var formal_hash:=""
var content_hashes: Dictionary={}

func _initialize() -> void:call_deferred("_run")
func _check(label: String, okay: bool, detail: Variant="") -> void:
	checks.append({"name":label,"passed":okay,"case":current_case,"detail":detail})
	print(("PASS " if okay else "FAIL ")+label+" "+str(detail))
func _release() -> void:
	for action: String in ACTIONS:Input.action_release(action)
func _tick(battle: Node2D) -> void:battle.step(battle.take_commands())

func _fresh(character: String, stage: String) -> Node2D:
	_release()
	app.action_lab=false
	app.session.profile=app.saves.default_profile()
	app.session.select_difficulty("expert")
	if stage=="root_41":
		app._on_intent("training",null)
		app._on_intent("select_training_character",character)
	else:
		# Selecting a specific existing stage isolates its ancestor transform;
		# the full title/dialogue/progression route has separate flow tests.
		app.session.select_character(character)
		app.enter_battle(stage)
	var battle: Node2D=app.battle
	battle.manual_clock=true
	battle.set_physics_process(false)
	for enemy: Node2D in battle.enemies:enemy.position=Vector2(2000,-1000)
	_check("actual Main creates selected encounter",app.screen=="battle" and app.session.run.character_id==character and app.selected_stage==stage and not app.action_lab,{"stage":stage,"character":character,"tick":app.session.run.source_ticks})
	return battle

func _slot(battle: Node2D, character: String) -> int:
	if character=="crt_2":return int(battle.crt2.r_slot_frame)
	if character=="crt_1":return int(battle.crt1.t_slot_frame)
	return int(battle._y_slot_frame)

func _view(battle: Node2D, character: String) -> Node2D:
	if character=="crt_2":return battle._crt2_views.get("r_cutin")
	if character=="crt_1":return battle._crt1_views.get("awakening_cutin")
	return battle.source_feedback.get("cutin",{}).get("visual")

func _logical_frame(battle: Node2D, character: String, view: Node2D) -> int:
	# Original Y visual holds source30 while its owner clock reaches31/32.
	if character=="crt_0":return int(battle.source_feedback.cutin.frame)
	return int(view.source_frame)

func _bounds(view: Node2D) -> Dictionary:
	if not is_instance_valid(view) or view.texture==null or view.frame.is_empty():return {}
	var region: Array=view.frame.region
	var pivot: Array=view.frame.pivot
	var scale_row: Array=view.definition.get("parent_scale",[1,1])
	var draw_scale:=Vector2(scale_row[0],scale_row[1])
	var local:=Rect2(-Vector2(pivot[0],pivot[1])*draw_scale,Vector2(region[2],region[3])*draw_scale)
	var stage_bounds: Rect2=view.global_transform*local
	stage_bounds=stage_bounds.abs()
	var intersection: Rect2=STAGE_RECT.intersection(stage_bounds)
	return {"source_frame":view.source_frame,"texture":view.definition.get("texture",""),"pivot":pivot,"region":region,"parent_scale":scale_row,"local_draw_rect":local,"global_transform":view.global_transform,"global_draw_rect":stage_bounds,"stage_intersection":intersection,"intersection_area":intersection.get_area(),"visible_in_tree":view.is_visible_in_tree(),"modulate_alpha":view.modulate.a,"self_modulate_alpha":view.self_modulate.a}

func _cast_and_reach_sample(battle: Node2D, spec: Array) -> Node2D:
	var waited:=0
	while _slot(battle,spec[0])<int(spec[5]) and waited<560 and not battle.ended:
		_tick(battle);waited+=1
	var ready: bool=_slot(battle,spec[0])==int(spec[5]) and battle.player.state=="idle" and not battle.ended
	_check("source slot becomes naturally ready",ready,{"slot":_slot(battle,spec[0]),"expected":spec[5],"waited_ticks":waited,"mp":battle.player.mp,"cubes":battle.session.profile.progress.clear_cubes})
	if not ready:return null
	Input.action_press(spec[3])
	var event:=InputEventKey.new()
	event.keycode=spec[2];event.physical_keycode=spec[2];event.pressed=true
	battle._unhandled_input(event)
	_tick(battle)
	Input.action_release(spec[3]);event.pressed=false;battle._unhandled_input(event)
	_check("actual key enters requested skill",battle.player.state==spec[3],{"state":battle.player.state,"parent":battle.player.parent_frame,"frame":battle.player.source_frame})
	var frames: Array[int]=[]
	var found: Node2D=null
	for n in range(60):
		var view:=_view(battle,spec[0])
		if is_instance_valid(view):
			frames.append(int(view.source_frame))
			if int(view.source_frame)==int(spec[6]):found=view;break
		if battle.ended:break
		_tick(battle)
	_check("independent cutin reaches stable visible source frame",is_instance_valid(found),{"expected":spec[6],"observed_frames":frames})
	if not is_instance_valid(found):return null
	var geometry:=_bounds(found)
	var overlap: Rect2=geometry.get("stage_intersection",Rect2())
	var expected_texture: String=app.database.assets.animations[spec[8]].texture
	# These original settled cutins cover roughly46k..66k stage pixels. A
	# significant20k-pixel/100x100 intersection rejects an off-screen sprite
	# or a tiny clipping sliver; node.visible alone is not sufficient.
	_check("actual atlas cutin significantly intersects550x400",not geometry.is_empty() and str(geometry.texture)==expected_texture and found.is_visible_in_tree() and overlap.size.x>=100 and overlap.size.y>=100 and overlap.get_area()>=20000,geometry)
	observations.append({"case":current_case,"geometry":geometry,"player_frame":battle.player.source_frame,"source_tick":battle.session.run.source_ticks})
	return found

func _case(spec: Array) -> void:
	current_case=str(spec[0])+"/"+str(spec[1])
	var battle:=_fresh(spec[0],spec[1])
	var cutin:=_cast_and_reach_sample(battle,spec)
	if not is_instance_valid(cutin):return
	var last_logical:=_logical_frame(battle,spec[0],cutin)
	for n in range(45):
		var active:=_view(battle,spec[0])
		if not is_instance_valid(active):break
		last_logical=_logical_frame(battle,spec[0],active)
		_tick(battle)
	_check("cutin terminal control removes actual source object",not is_instance_valid(_view(battle,spec[0])) and last_logical==int(spec[7])-1 and (not is_instance_valid(cutin) or cutin.is_queued_for_deletion()),{"last_logical":last_logical,"end_control":spec[7],"old_visual_queued":is_instance_valid(cutin) and cutin.is_queued_for_deletion()})
	# Build another legal cast, then leave while its actual visual is on-screen.
	battle=_fresh(spec[0],spec[1])
	var active_cutin:=_cast_and_reach_sample(battle,spec)
	if not is_instance_valid(active_cutin):return
	var prior:=battle
	var replacement:=_fresh(spec[0],spec[1])
	_check("reentry removes active cutin from rendered tree",prior.is_queued_for_deletion() and not prior.is_inside_tree() and not active_cutin.is_inside_tree() and not is_instance_valid(_view(replacement,spec[0])),{"prior_inside_tree":prior.is_inside_tree(),"visual_inside_tree":active_cutin.is_inside_tree(),"replacement_tick":app.session.run.source_ticks})
	await process_frame
	_check("old cutin freed after deferred deletion",not is_instance_valid(active_cutin) and not is_instance_valid(prior) and not is_instance_valid(_view(replacement,spec[0])))

func _run() -> void:
	if "--test-mode" not in OS.get_cmdline_user_args():push_error("Requires isolated --test-mode");quit(2);return
	formal_exists=FileAccess.file_exists("user://profile.json")
	if formal_exists:formal_hash=FileAccess.get_sha256("user://profile.json")
	for path: String in ["res://content/components/crt2/visuals.tres","res://content/components/crt2/r_air.tres","res://content/components/crt1/awakening.tres","res://data/asset_catalog.json"]:content_hashes[path]=FileAccess.get_sha256(path)
	app=MainScene.instantiate();root.add_child(app);app.set_process(false)
	_check("Main starts real authored content",app.startup_ok and app.test_mode,app.database.issues)
	if app.startup_ok:
		app.saves=Save.new("user://act04_cutin/run_%d_%d/profile.json"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()])
		for spec: Array in CASES:await _case(spec)
	_release()
	_check("formal profile unchanged",FileAccess.file_exists("user://profile.json")==formal_exists and (not formal_exists or FileAccess.get_sha256("user://profile.json")==formal_hash))
	var unchanged:=true
	for path: String in content_hashes:unchanged=unchanged and FileAccess.get_sha256(path)==content_hashes[path]
	_check("test preserves author and asset metadata",unchanged)
	app._dispose_battle()
	var drained: bool=await app.audio.stop_and_drain(1.0)
	_check("Dummy playback references drain",drained)
	app.queue_free();await process_frame
	var failures: int=checks.filter(func(row:Dictionary)->bool:return not row.passed).size()
	var output:=OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if output.is_empty():output="res://artifacts/leba_act04_20261117/cutin/run_%d_%d"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var file:=FileAccess.open(output.path_join("act04_cutin.json"),FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify({"suite":"ACT04 actual cutin stage intersection and lifecycle","checks":checks,"failures":failures,"observations":observations,"godot":Engine.get_version_info(),"fixtures":["explicit existing stage selected through Main","one-time enemy positions2000,-1000 for safe visual isolation"],"not_tested":["GPU rendered alpha-pixel or occlusion review","audible listening","original host callback-timing equivalence"]},"\t")+"\n");file.close()
	print("ACT04_CUTIN_RESULT ",JSON.stringify({"checks":checks.size(),"failures":failures,"report":output}))
	quit(0 if failures==0 else 1)
