extends SceneTree
## Source-derived contracts, not an original-host timing recording.
## Formal Main/Resource/InputMap/AudioDirector paths; Dummy audio is not listening.
## One-time offscreen enemies isolate persistent clocks. No cooldown/action/marker
## state is injected. Viewport-alpha intersection is geometric, not GPU proof.
const MainScene = preload("res://scenes/main.tscn")
const Save = preload("res://scripts/services/save_store.gd")
const EvidencePath := "res://artifacts/leba_act05_20261117/investigation/crt3_special.json"
const KEYS := {KEY_H:"load_h",KEY_E:"skill_e",KEY_Q:"skill_q",KEY_X:"attack"}
var app: Node
var checks: Array[Dictionary] = []
var sounds: Array[Dictionary] = []
var traces: Array[Dictionary] = []
var scope := "startup"
var evidence: Dictionary
var catalog: Dictionary
var output := ""
var formal_exists := false
var formal_hash := ""
var author_hashes: Dictionary = {}

func _initialize() -> void:call_deferred("_run")

func _check(label: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"name":label,"passed":passed,"detail":detail,"scope":scope})
	print(("PASS " if passed else "FAIL ")+label)

func _release() -> void:
	for action: String in KEYS.values():Input.action_release(action)

func _snapshot(battle: Node2D) -> Dictionary:
	var views := {}
	for key: String in battle._crt3_views:
		var view: Node2D = battle._crt3_views[key]
		if is_instance_valid(view):views[key]={"frame":int(view.source_frame),"visible":view.is_visible_in_tree(),"position":view.position}
	return {"tick":battle.session.run.source_ticks,"state":battle.player.state,"parent":battle.player.parent_frame,"source_frame":battle.player.source_frame,"hp":battle.player.hp,"mp":battle.player.mp,"cubes":battle.session.profile.progress.clear_cubes,"crt3":battle.crt3.duplicate(true),"views":views,"ended":battle.ended}

func _played(alias: String, stream: AudioStream, offset: float, voice: AudioStreamPlayer) -> void:
	var sid := int(app.database.assets.audio_events.get(alias,{}).get("sound_id",0))
	if sid==0 and stream!=null:sid=stream.resource_path.get_file().get_basename().to_int()
	var battle: Node2D = app.battle if is_instance_valid(app.battle) else null
	sounds.append({"scope":scope,"alias":alias,"sound_id":sid,"path":stream.resource_path if stream!=null else "","offset":offset,"length":stream.get_length() if stream!=null else 0.0,"voice_valid":is_instance_valid(voice) and voice.playing and voice.has_stream_playback() and voice.stream==stream,"parent":battle.player.parent_frame if battle!=null else -1,"frame":battle.player.source_frame if battle!=null else -1,"tick":battle.session.run.source_ticks if battle!=null else -1})

func _tick(battle: Node2D, count := 1) -> void:
	for n in range(count):battle.step(battle.take_commands())

func _tap(battle: Node2D, key: int) -> void:
	Input.action_press(KEYS[key])
	var event := InputEventKey.new()
	event.keycode=key
	event.physical_keycode=key
	event.pressed=true
	battle._unhandled_input(event)
	_tick(battle)
	Input.action_release(KEYS[key])
	event.pressed=false
	battle._unhandled_input(event)

func _until(battle: Node2D, predicate: Callable, limit := 500) -> bool:
	for n in range(limit+1):
		if predicate.call():return true
		if battle.ended:return false
		if n<limit:_tick(battle)
	return false

func _fresh(name: String, ready_e := false) -> Node2D:
	scope=name
	_release()
	app.action_lab=false
	app.session.profile=app.saves.default_profile()
	app._on_intent("training",null)
	app._on_intent("select_training_character","crt_3")
	var battle: Node2D = app.battle
	battle.manual_clock=true
	battle.set_physics_process(false)
	for enemy: Node2D in battle.enemies:enemy.position=Vector2(520,-1000)
	_tick(battle,2)
	_check("formal CRT3 training entry "+name,app.screen=="battle" and battle.is_training() and battle.player.definition.source_crt==3 and battle.player.parent_frame==101,_snapshot(battle))
	if ready_e:
		var ready := _until(battle,func()->bool:return int(battle.crt3.e_slot_frame)==442,500)
		_check("E naturally reaches original ready442 "+name,ready,_snapshot(battle))
	return battle

func _view(battle: Node2D, key: String) -> Node2D:
	return battle._crt3_views.get(key) as Node2D

func _frame(battle: Node2D, key: String) -> int:
	var view := _view(battle,key)
	return int(view.source_frame) if is_instance_valid(view) else -1

func _sound_count(start: int, ids: Array) -> int:
	return sounds.slice(start).filter(func(row:Dictionary)->bool:return int(row.sound_id) in ids).size()

func _formal_main_audio() -> void:
	scope="formal_resources"
	var character: Resource = load("res://content/characters/crt_3.tres")
	var covered := {}
	for action: Resource in character.actions:
		var asset: Dictionary = catalog.animations.get(action.animation_key,{})
		var sid := str(int(asset.get("source_sprite_id",0)))
		for expected: Dictionary in evidence.audio.default_main_events_by_id.get(sid,[]):
			if not int(expected.frame) in action.sequence:continue
			var matches: Array = action.events.filter(func(event:Resource)->bool:
				return event.kind=="sound" and int(event.frame)==int(expected.frame) and event.audio_stream!=null and event.audio_stream.resource_path.get_file().get_basename().to_int()==int(expected.sound_id))
			var key := sid+"/"+str(int(expected.frame))+"/"+str(int(expected.sound_id))
			covered[key]=true
			_check("formal Resource preserves source sound "+action.identifier+" "+key,matches.size()==1 and is_equal_approx(matches[0].audio_offset,float(expected.offset_seconds)),{"matches":matches.size(),"source":expected.evidence})
	var expected_count := 0
	for rows: Array in evidence.audio.default_main_events_by_id.values():expected_count+=rows.size()
	_check("all37 default main StartSound events are covered by real Resources",covered.size()==expected_count and expected_count==37,{"expected":expected_count,"covered":covered.size()})
	var h: Resource
	var e: Resource
	for action: Resource in character.actions:
		if action.source_parent==129:h=action
		if action.source_parent==132:e=action
	_check("H author preserves source129 default1..19",h!=null and h.sequence[0]==1 and h.sequence[-1]==19 and h.cost==5.0)
	_check("E author retains source132 main10 hold and30MP5cubes",e!=null and e.sequence[-1]==10 and (e.hold or 10 in e.hold_at) and e.cost==30.0 and e.cubes==5)

func _test_h_clock() -> void:
	var battle := _fresh("H_persistent_clock")
	var start := sounds.size()
	var mp: float = battle.player.mp
	_tap(battle,KEY_H)
	_check("real H key enters129 and pays5 plus source regen",battle.player.parent_frame==129 and is_equal_approx(battle.player.mp,mp-5.0+0.05),_snapshot(battle))
	var reached := _until(battle,func()->bool:return int(battle.crt3.h_frame)==9,40)
	_check("H independent clock reaches9 and sets over",reached and bool(battle.crt3.over),_snapshot(battle))
	var sound_h := _sound_count(start,[6143])
	var sound_timer := _sound_count(start,[3950])
	_check("H main and child clocks each consume their real source sound once",sound_h==1 and sound_timer==1,{"main6143":sound_h,"timer3950":sound_timer})
	var idle := _until(battle,func()->bool:return battle.player.parent_frame==101,30)
	var before := int(battle.crt3.h_frame)
	_tap(battle,KEY_X)
	_check("main action exit and a real X do not reset persistent H",idle and battle.player.parent_frame==106 and int(battle.crt3.h_frame)==before+1 and bool(battle.crt3.over),_snapshot(battle))
	reached=_until(battle,func()->bool:return int(battle.crt3.h_frame)==400,420)
	_check("H keeps source9..400 persistent phase",reached and bool(battle.crt3.over),_snapshot(battle))
	_tick(battle)
	_check("H crosses401 without clearing over",int(battle.crt3.h_frame)==401 and bool(battle.crt3.over),_snapshot(battle))
	_tick(battle,6)
	_check("H source407 is still active",int(battle.crt3.h_frame)==407 and bool(battle.crt3.over),_snapshot(battle))
	_tick(battle)
	_check("H natural wrap1 clears persistent over",int(battle.crt3.h_frame)==1 and not bool(battle.crt3.over),_snapshot(battle))
	_tick(battle,12)
	_check("H idle1 stops and does not replay child sound",int(battle.crt3.h_frame)==1 and _sound_count(start,[3950])==1,_snapshot(battle))
	traces.append(_snapshot(battle))

func _alpha_intersection(view: Node2D) -> Dictionary:
	if not is_instance_valid(view) or view.texture==null or view.frame.is_empty():return {"area":0.0}
	var image: Image = view.texture.get_image()
	if image==null:return {"area":0.0}
	var region: Array = view.frame.region
	var tile: Image = image.get_region(Rect2i(int(region[0]),int(region[1]),int(region[2]),int(region[3])))
	var used: Rect2i = tile.get_used_rect()
	if used.size==Vector2i.ZERO:return {"area":0.0}
	var pivot: Array = view.frame.pivot
	var scale_data: Array = view.definition.get("parent_scale",[1.0,1.0])
	var draw_scale := Vector2(float(scale_data[0]),float(scale_data[1]))
	var local := Rect2((Vector2(used.position)-Vector2(float(pivot[0]),float(pivot[1])))*draw_scale,Vector2(used.size)*draw_scale)
	var world: Rect2 = view.global_transform*local
	var overlap := world.intersection(Rect2(0,0,550,400))
	return {"area":overlap.get_area(),"world":world,"overlap":overlap,"alpha_bounds":used,"frame":view.source_frame,"visible":view.is_visible_in_tree() and view.modulate.a>0}

func _test_e_clock_and_sounds() -> void:
	var battle := _fresh("E_independent_clocks",true)
	var start := sounds.size()
	var mp: float=battle.player.mp
	var cubes: int=battle.session.profile.progress.clear_cubes
	_tap(battle,KEY_E)
	_check("real E key enters132 and pays30MP5cubes",battle.player.parent_frame==132 and is_equal_approx(battle.player.mp,mp-30.0+0.05) and battle.session.profile.progress.clear_cubes==cubes-5,_snapshot(battle))
	_check("E source slot stops1 during long action",int(battle.crt3.e_slot_frame)==1 and not bool(battle.crt3.e_slot_playing),_snapshot(battle))
	var reached := _until(battle,func()->bool:return battle.player.source_frame==10,20)
	_check("E main10 retains three separate actual child views",reached and is_instance_valid(_view(battle,"e_6276")) and is_instance_valid(_view(battle,"e_6199")) and is_instance_valid(_view(battle,"e_6299")),_snapshot(battle))
	_check("E main10 consumes both same-frame original sounds",_sound_count(start,[5878])==1 and _sound_count(start,[5240])==1,sounds.slice(start))
	var early_advance := false
	var observed_release := false
	var max_visible_cutin_area := 0.0
	var cutin_samples: Array = []
	var last_w := -1
	var hold_ticks := 0
	var slot_started_early := false
	for tick in range(260):
		if battle.player.parent_frame!=132:break
		var w:=_frame(battle,"e_6276")
		var prelude:=_frame(battle,"e_6299")
		if w>1 and prelude<39:early_advance=true
		if w>=2 and prelude>=39:observed_release=true
		if battle.player.source_frame==10:hold_ticks+=1
		if int(battle.crt3.e_slot_frame)!=1 or bool(battle.crt3.e_slot_playing):slot_started_early=true
		var cutin := _view(battle,"e_cutin")
		if is_instance_valid(cutin):
			var measure := _alpha_intersection(cutin)
			if bool(measure.get("visible",false)):max_visible_cutin_area=maxf(max_visible_cutin_area,float(measure.area))
			if cutin_samples.size()<40:cutin_samples.append(measure)
		if w in [1,2,23,48,116,128,147]:traces.append(_snapshot(battle))
		last_w=w
		_tick(battle)
	_check("E child6299 source39 controls release of held6276",not early_advance and observed_release,{"early_advance":early_advance,"observed_release":observed_release})
	_check("E main holds10 well beyond a ten-frame demo",hold_ticks>100 and not slot_started_early,{"hold_ticks":hold_ticks,"slot_started_early":slot_started_early})
	_check("E ends only after child147 advances to source148 control",battle.player.parent_frame==101 and last_w==147,_snapshot(battle))
	_check("E source148 starts cooldown after returning101",bool(battle.crt3.e_slot_playing) and int(battle.crt3.e_slot_frame)<=2,_snapshot(battle))
	_check("E cutin has real nontransparent texture area inside550x400",max_visible_cutin_area>0,{"max_alpha_intersection":max_visible_cutin_area,"samples":cutin_samples,"validation":"CPU texture alpha plus real transforms, not GPU or human visual acceptance"})
	_check("E each of24 source6259 births consumes StartSound6256 once",_sound_count(start,[6256])==24,{"actual":_sound_count(start,[6256])})
	_check("E each of24 source6259 births chooses one scripted source sound",_sound_count(start,[12,13,9])==24,{"actual":_sound_count(start,[12,13,9]),"not_claimed":"Flash PRNG sequence equivalence"})
	_check("E independent prelude and driver source sounds are consumed",_sound_count(start,[5698])==1 and _sound_count(start,[11])==1 and _sound_count(start,[5404])==1,sounds.slice(start))
	var prior:=sounds.size()
	_tick(battle,20)
	_check("completed E child clocks cannot emit residual sounds",sounds.size()==prior and not is_instance_valid(_view(battle,"e_6276")) and not is_instance_valid(_view(battle,"e_6299")),_snapshot(battle))
	_check("completed E cooldown continues naturally",int(battle.crt3.e_slot_frame)>2 and int(battle.crt3.e_slot_frame)<442,_snapshot(battle))

func _test_exit_reentry() -> void:
	var battle:=_fresh("E_exit_and_reentry",true)
	_tap(battle,KEY_H)
	_until(battle,func()->bool:return battle.player.parent_frame==101,60)
	_tap(battle,KEY_E)
	_until(battle,func()->bool:return battle.player.source_frame==10,20)
	var old: Node2D=battle
	var old_views: Array=battle._crt3_views.values().duplicate()
	app._on_intent("leave",null)
	_check("normal leave disposes active E/H battle",not is_instance_valid(app.battle) or app.battle!=old)
	var fresh:=_fresh("reentered_clean")
	_check("reenter does not retain H or E timers",int(fresh.crt3.h_frame)==1 and not bool(fresh.crt3.over) and int(fresh.crt3.e_slot_frame)<442 and _frame(fresh,"e_6276")==-1,_snapshot(fresh))
	var owned:=true
	for item: Variant in old_views:
		if is_instance_valid(item):owned=owned and (old.is_ancestor_of(item) or item.is_queued_for_deletion())
	_check("disposed independent views retain old battle ownership",owned)

func _run() -> void:
	if "--test-mode" not in OS.get_cmdline_user_args():
		push_error("Requires --test-mode and isolated save")
		quit(2)
		return
	output=OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if output.is_empty():output="res://artifacts/leba_act05_20261117/special/run_%d_%d"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	evidence=JSON.parse_string(FileAccess.get_file_as_string(EvidencePath))
	catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_catalog.json"))
	formal_exists=FileAccess.file_exists("user://profile.json")
	if formal_exists:formal_hash=FileAccess.get_sha256("user://profile.json")
	for directory: String in ["res://content/actions/crt3","res://content/components/crt3"]:
		if not DirAccess.dir_exists_absolute(directory):continue
		for filename: String in DirAccess.get_files_at(directory):
			var path:=directory.path_join(filename)
			if filename.ends_with(".tres"):author_hashes[path]=FileAccess.get_sha256(path)
	app=MainScene.instantiate()
	root.add_child(app)
	app.set_process(false)
	_check("Main loads actual enabledCRT3 author",app.startup_ok and app.test_mode and bool(app.database.characters.get("crt_3",{}).get("enabled",false)),app.database.issues)
	if app.startup_ok and bool(app.database.characters.get("crt_3",{}).get("enabled",false)):
		app.saves=Save.new("user://act05_special/run_%d_%d/profile.json"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()])
		app.audio.sound_played.connect(_played)
		_formal_main_audio()
		_test_h_clock()
		_test_e_clock_and_sounds()
		_test_exit_reentry()
		_check("all actual sound requests contain live real streams",not sounds.is_empty() and sounds.all(func(row:Dictionary)->bool:return row.voice_valid and row.length>0 and row.offset>=0 and row.offset<row.length),sounds.size())
	_release()
	_check("formal profile remains unchanged",FileAccess.file_exists("user://profile.json")==formal_exists and (not formal_exists or FileAccess.get_sha256("user://profile.json")==formal_hash))
	var untouched:=true
	for path: String in author_hashes:untouched=untouched and FileAccess.get_sha256(path)==author_hashes[path]
	_check("formal authored resources remain unchanged",untouched)
	app._dispose_battle()
	var drained: bool=await app.audio.stop_and_drain(1.0)
	_check("Dummy audio drains on teardown",drained and app.audio.snapshot().pending_playbacks==0)
	app.queue_free()
	await process_frame
	var failures:=checks.filter(func(row:Dictionary)->bool:return not row.passed).size()
	var file:=FileAccess.open(output.path_join("act05_crt3_special_tests.json"),FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify({"suite":"ACT05 CRT3 original-source special contracts","checks":checks,"failures":failures,"traces":traces,"sounds":sounds,"engine":Engine.get_version_info(),"fixtures":["normal training selection, one-time offscreen enemy position","manual25Hz steps through actual input queue; no action/cooldown/marker injection","CPU alpha bounds for cutin geometry"],"not_tested":["original native Flash/Ruffle per-tick source probe","GPU visibility and human visual acceptance","physical OS key dispatch","audible listening","multi-enemy H/E damage callback ordering and total damage","Flash PRNG equivalence"]},"\t")+"\n")
		file.close()
	print("ACT05_CRT3_SPECIAL_RESULT "+JSON.stringify({"checks":checks.size(),"failures":failures}))
	quit(0 if failures==0 else 1)
