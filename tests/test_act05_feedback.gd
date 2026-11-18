extends SceneTree
## Actual Main/E input contracts. Original AS/XML facts are independent evidence.
## Only one initial enemy Y=-10000 isolates long clocks; HP/AI/count stay intact.
const MainScene=preload("res://scenes/main.tscn")
const Save=preload("res://scripts/services/save_store.gd")
const Visual=preload("res://scripts/combat/source_sprite.gd")
const SOURCE_FACTS="res://artifacts/leba_act05_20261117/screen_feedback.json"
const IMPORT_FACTS="res://artifacts/leba_act05_20261117/investigation/act05_import_plan.json"
var app: Node
var output: String
var scope:="startup"
var checks: Array[Dictionary]=[]
var traces: Array[Dictionary]=[]
var captures: Array[Dictionary]=[]
var protected: Dictionary={}
var formal_exists:=false
var formal_hash:=""
var flash_births: Array[int]=[]
var source_facts: Dictionary
var texture_sources: Dictionary={}

func _initialize() -> void:call_deferred("_run")
func _check(name: String, passed: bool, detail: Variant="") -> void:
	checks.append({"scope":scope,"name":name,"passed":passed,"detail":detail})
	print(("PASS " if passed else "FAIL ")+name)
func _state(b: Node2D) -> Dictionary:
	return {"tick":b.session.run.source_ticks,"stage":b.stage.source_root_frame,"action":b.player.state,"frame":b.player.source_frame,"hp":b.player.hp,"mp":b.player.mp,"cubes":b.session.profile.progress.clear_cubes,"enemies":b.enemies.map(func(e:Node2D)->Dictionary:return {"hp":e.hp,"position":e.position}),"crt3":b.crt3.duplicate(true)}
func _tick(b: Node2D, count:=1) -> void:
	for n in range(count):b.step(b.take_commands())
	app._process(0.0)
func _until(b: Node2D, predicate: Callable, limit:=600) -> bool:
	for n in range(limit+1):
		if predicate.call():return true
		if b.ended:return false
		if n<limit:_tick(b)
	return false
func _tap_e(b: Node2D) -> void:
	Input.action_press("skill_e")
	var event:=InputEventKey.new();event.keycode=KEY_E;event.physical_keycode=KEY_E;event.pressed=true
	b._unhandled_input(event);_tick(b)
	Input.action_release("skill_e");event.pressed=false;b._unhandled_input(event)
func _button(id: String) -> bool:
	var button: BaseButton=app.ui.get_button(id)
	if not is_instance_valid(button) or button.disabled:
		_check("normal UI enabled button "+id,false);return false
	button.pressed.emit();return true
func _fresh(stage_id: String) -> Node2D:
	scope=stage_id
	Input.action_release("skill_e")
	app.saves=Save.new("user://act05_feedback/%d_%d/profile.json"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()])
	app.session.profile=app.saves.default_profile();app.action_lab=false;app.show_title()
	if stage_id=="root_41":
		if not _button("Training") or not _button("Character_crt_3"):return null
	else:
		if not _button("Start") or not _button("Character_crt_3") or not _button("Difficulty_expert"):return null
		# Existing Main scene-selection API: explicit root9 routing fixture,
		# not evidence of campaign completion (covered independently by flow).
		if stage_id=="root_9":app.show_intro(stage_id)
		if not _button("EnterBattle"):return null
		if app.screen=="dialogue" and not _button("DialogueSkip"):return null
	var b: Node2D=app.battle
	b.manual_clock=true;b.set_physics_process(false)
	for enemy: Node2D in b.enemies:enemy.position.y=-10000.0
	_check("actual requested CRT3 stage with original live enemies",app.screen=="battle" and app.selected_stage==stage_id and int(b.player.definition.source_crt)==3 and not app.action_lab and b.enemies.all(func(e:Node2D)->bool:return e.hp>0),_state(b))
	var ready:=_until(b,func()->bool:return int(b.crt3.e_slot_frame)==442,500)
	_check("E naturally reaches442 without cooldown injection",ready,_state(b))
	return b
func _view(b: Node2D, kind: String) -> Node2D:return b._crt3_views.get("screen_"+kind) as Node2D
func _effective_z(item: CanvasItem) -> int:
	var result:=0;var node: Node=item
	while node!=null:
		if node is CanvasItem:
			result+=int(node.z_index)
			if not node.z_as_relative:break
		node=node.get_parent()
	return result
func _source_id(view: Node2D) -> int:
	return int(texture_sources.get(str(view.definition.get("texture","")),0))
func _count_source(node: Node, source_id: int) -> int:
	var count:=0
	if not node.is_queued_for_deletion() and node.get_script()==Visual and _source_id(node)==source_id:count+=1
	for child: Node in node.get_children():count+=_count_source(child,source_id)
	return count
func _capture_phase(_b: Node2D, _kind: String, _label: String) -> void:
	# Override only in ignored GL sampler; same gameplay method and clock.
	pass
func _test_stage(stage_id: String) -> void:
	var b:=_fresh(stage_id)
	if b==null:return
	var hp: float=b.player.hp;var mp: float=b.player.mp;var cubes: int=b.session.profile.progress.clear_cubes
	_tap_e(b)
	_check("real E key pays30MP5cubes and enters132",b.player.parent_frame==132 and is_equal_approx(b.player.mp,mp-30.0+0.05) and int(b.session.profile.progress.clear_cubes)==cubes-5,_state(b))
	var reached:=_until(b,func()->bool:return bool(b.crt3.e_active) and int(b.crt3.e_w_frame)==2,100)
	_check("E held main10 starts independent6276",reached,_state(b))
	if not reached:return
	var observed_flash: Array[int]=[];var observed_dark: Array[int]=[]
	var dark_instance:=0;var unique_nodes:=true;var one_flash_tick:=true;var dark_timeline:=true
	for n in range(170):
		var frame:=int(b.crt3.e_w_frame)
		var flash:=_view(b,"flash");var dark:=_view(b,"dark")
		var expect_flash:=frame in flash_births or frame==128
		one_flash_tick=one_flash_tick and is_instance_valid(flash)==expect_flash
		unique_nodes=unique_nodes and _count_source(b,6861)<=1 and _count_source(b,1410)<=1
		if is_instance_valid(flash):
			observed_flash.append(frame)
			one_flash_tick=one_flash_tick and int(flash.source_frame)==22 and int(b.crt3.get("flash_frame",1))==22
			if frame==48:
				_check("source6259 birth48 creates actual6861 white-flash22",_source_id(flash)==6861 and flash.position.is_equal_approx(Vector2(743.45,461.0)) and _effective_z(flash)>_effective_z(app.ui.source_hud),{"position":flash.position,"z":_effective_z(flash),"hud_z":_effective_z(app.ui.source_hud)})
				await _capture_phase(b,"flash","birth48")
		if stage_id=="root_41":
			dark_timeline=dark_timeline and not is_instance_valid(dark)
		elif frame>=116 and frame<=141:
			var expected:=frame-114
			dark_timeline=dark_timeline and is_instance_valid(dark) and int(dark.source_frame)==expected and int(b.crt3.get("dark_frame",1))==expected
			if is_instance_valid(dark):
				observed_dark.append(int(dark.source_frame))
				if dark_instance==0:dark_instance=dark.get_instance_id()
				dark_timeline=dark_timeline and dark.get_instance_id()==dark_instance
				if frame==116:
					var expected_origin:=Vector2(267.55,190.15) if stage_id=="root_2" else Vector2(272.8,202.65)
					var z:=_effective_z(dark)
					_check("source116 starts actual1410 at2 under actors and HUD",_source_id(dark)==1410 and dark.position.distance_to(expected_origin)<0.002 and is_equal_approx(dark.transform.x.x,1.1309052) and is_equal_approx(dark.transform.y.y,1.1300049) and z<_effective_z(b.player) and z<_effective_z(app.ui.source_hud),{"position":dark.position,"z":z,"actor_z":_effective_z(b.player),"hud_z":_effective_z(app.ui.source_hud)})
				if frame==117:await _capture_phase(b,"dark","driver117")
		else:dark_timeline=dark_timeline and not is_instance_valid(dark)
		traces.append({"stage":stage_id,"w":frame,"tick":b.session.run.source_ticks,"dark_frame":int(b.crt3.get("dark_frame",1)),"flash_frame":int(b.crt3.get("flash_frame",1)),"dark_present":is_instance_valid(dark),"flash_present":is_instance_valid(flash),"active1410":_count_source(b,1410),"active6861":_count_source(b,6861)})
		if not bool(b.crt3.e_active):break
		_tick(b)
	var expected_births:=flash_births.duplicate();expected_births.append(128)
	_check("every original6259 birth and128 flashes exactly22 then neutral1",one_flash_tick and observed_flash==expected_births,{"observed":observed_flash,"expected":expected_births})
	_check("screen effects have no duplicate live source nodes",unique_nodes)
	_check("training missing暗전 is faithful no-op" if stage_id=="root_41" else "1410 progresses2through27 then source1 without restart",dark_timeline and (observed_dark.is_empty() if stage_id=="root_41" else observed_dark==range(2,28)),observed_dark)
	_check("normal E exit clears screens and returns101",not bool(b.crt3.e_active) and b.player.parent_frame==101 and not is_instance_valid(_view(b,"dark")) and not is_instance_valid(_view(b,"flash")) and is_equal_approx(b.player.hp,hp),_state(b))
	_tick(b,5)
	_check("idle does not respawn screen effects",not is_instance_valid(_view(b,"dark")) and not is_instance_valid(_view(b,"flash")))
	app._on_intent("leave",null)
	await process_frame
	_check("normal leave frees prior encounter and all owned screen nodes",not is_instance_valid(b) and not is_instance_valid(app.battle))
func _interrupt_cleanup() -> void:
	var b:=_fresh("root_2")
	if b==null:return
	_tap_e(b)
	var reached:=_until(b,func()->bool:return int(b.crt3.e_w_frame)==116 and is_instance_valid(_view(b,"dark")),220)
	_check("cleanup case reaches original simultaneous dark and flash",reached and is_instance_valid(_view(b,"flash")))
	var dark:=_view(b,"dark");var flash:=_view(b,"flash")
	app._on_intent("leave",null);await process_frame
	_check("mid-E leave frees both feedback nodes",not is_instance_valid(dark) and not is_instance_valid(flash) and not is_instance_valid(b))
	var fresh:=_fresh("root_41")
	_check("cross-stage reentry has neutral feedback state",fresh!=null and not is_instance_valid(_view(fresh,"dark")) and not is_instance_valid(_view(fresh,"flash")) and int(fresh.crt3.get("dark_frame",1))==1 and int(fresh.crt3.get("flash_frame",1))==1)
func _hash_folder(folder: String) -> void:
	for filename: String in DirAccess.get_files_at(folder):
		var path:=folder.path_join(filename)
		if filename.ends_with(".tres") or filename.ends_with(".tscn"):protected[path]=FileAccess.get_sha256(path)
	for directory: String in DirAccess.get_directories_at(folder):_hash_folder(folder.path_join(directory))
func _report() -> Dictionary:
	return {"suite":"ACT05 E screen feedback","checks":checks,"failures":checks.filter(func(r:Dictionary)->bool:return not r.passed).size(),"traces":traces,"captures":captures,"godot":Engine.get_version_info(),"source_evidence":SOURCE_FACTS,"fixtures":["isolated default profiles; actual title/character/difficulty and normal Main entry","root9 uses existing Main.show_intro scene-selection fixture; not campaign completion evidence","once at entry, enemy Y=-10000; AI,HP,count remain untouched","source clock manually stepped, actual InputEventKey E; no action/fee/CD/state-marker injection"],"not_tested":["audible listening","natural OS keyboard","native Flash/Ruffle callback ordering equivalence","user acceptance"]}
func _run() -> void:
	if "--test-mode" not in OS.get_cmdline_user_args():push_error("Requires --test-mode");quit(2);return
	output=OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if output.is_empty():output="res://artifacts/leba_act05_20261117/feedback_%d_%d"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	source_facts=JSON.parse_string(FileAccess.get_file_as_string(SOURCE_FACTS))
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_catalog.json"))
	for animation: Dictionary in catalog.animations.values():texture_sources[str(animation.texture)]=int(animation.get("source_sprite_id",0))
	var plan: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(IMPORT_FACTS))
	for row: Dictionary in plan.e_hit_parent_wrappers.variants:flash_births.append(int(row.parent_source_frame))
	_check("independent source facts contain24 genuine6259 births",flash_births.size()==24 and flash_births[0]==48 and flash_births[-1]==116)
	formal_exists=FileAccess.file_exists("user://profile.json")
	if formal_exists:formal_hash=FileAccess.get_sha256("user://profile.json")
	_hash_folder("res://content");_hash_folder("res://scenes")
	for path: String in ["res://scripts/combat/battle.gd","res://scripts/main.gd","res://data/asset_catalog.json"]:protected[path]=FileAccess.get_sha256(path)
	OS.set_environment("LEBA_TEST_MODE","1");OS.set_environment("LEBA_SILENT_TEST","1");OS.set_environment("LEBA_TEST_PROFILE","user://act05_feedback/start_%d/profile.json"%Time.get_ticks_usec())
	root.size=Vector2i(550,400)
	app=MainScene.instantiate();root.add_child(app);app.set_process(false)
	_check("Main loads formal CRT3 and feedback Resources",app.startup_ok and app.test_mode and app.database.characters.crt_3.enabled,app.database.issues)
	if app.startup_ok:
		for stage: String in ["root_2","root_9","root_41"]:await _test_stage(stage)
		await _interrupt_cleanup()
	Input.action_release("skill_e");app._dispose_battle()
	var drained: bool=await app.audio.stop_and_drain(1.0)
	_check("Dummy audio drains",drained)
	app.queue_free();await process_frame
	_check("formal profile remains byte-identical",FileAccess.file_exists("user://profile.json")==formal_exists and (not formal_exists or FileAccess.get_sha256("user://profile.json")==formal_hash))
	_check("production runtime and author files remain byte-identical",protected.keys().all(func(path:String)->bool:return FileAccess.get_sha256(path)==protected[path]),protected.size())
	var report:=_report();var file:=FileAccess.open(output.path_join("feedback.json"),FileAccess.WRITE)
	if file==null:push_error("Cannot write feedback report");quit(2);return
	file.store_string(JSON.stringify(report,"\t")+"\n");file.close()
	print("ACT05_FEEDBACK_RESULT "+JSON.stringify({"checks":checks.size(),"failures":report.failures,"report":output}))
	quit(0 if int(report.failures)==0 else 1)
