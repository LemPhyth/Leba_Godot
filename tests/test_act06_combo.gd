extends SceneTree
## ACT06 P0: original same-parent play semantics through formal Main and keys.
## Original Ruffle probe01/02 proves106child9/17 play -> next source tick107.
## Fixtures: manual source clock, one initial offscreen enemy position, public
## receive_damage only in the separately labelled interruption case.
const MainScene = preload("res://scenes/main.tscn")
const Save = preload("res://scripts/services/save_store.gd")
const KEYS := {KEY_X:"attack",KEY_S:"skill_s",KEY_DOWN:"down"}
const INPUTS := ["move_left","move_right","attack","skill_s","down"]
var app: Node
var checks: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var sounds: Array[Dictionary] = []
var case_name := "startup"
var formal_exists := false
var formal_hash := ""
var author_hashes: Dictionary = {}

func _initialize() -> void:call_deferred("_run")
func _check(name: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"case":case_name,"name":name,"passed":passed,"detail":detail})
	print(("PASS " if passed else "FAIL ")+name+" "+str(detail))
func _release() -> void:
	for action: String in INPUTS:Input.action_release(action)
func _snapshot(b: Node2D) -> Dictionary:
	return {"tick":b.session.run.source_ticks,"parent":b.player.parent_frame,"child":b.player.source_frame,"action":b.player.state,"serial":b.player.action_serial,"pyeongta":b.crt3.pyeongta,"rigui":b.crt3.rigui,"position":b.player.position,"facing":b.player.facing,"animation":b.player.definition.actions[b.player.state].animation,"hp":b.player.hp,"mp":b.player.mp,"body_frame":b.player.body_frame,"ended":b.ended}
func _tick(b: Node2D, count := 1) -> void:
	for i in range(count):
		b.step(b.take_commands())
		samples.append({"case":case_name,"phase":"after_source_step","state":_snapshot(b)})
func _down(b: Node2D, code: int, echo := false) -> void:
	if KEYS.has(code):Input.action_press(KEYS[code])
	var event:=InputEventKey.new()
	event.keycode=code;event.physical_keycode=code;event.pressed=true;event.echo=echo
	b._unhandled_input(event)
	samples.append({"case":case_name,"phase":"key_down_queued","code":code,"echo":echo,"state":_snapshot(b)})
	_tick(b)
func _up(b: Node2D, code: int) -> void:
	if KEYS.has(code):Input.action_release(KEYS[code])
	var event:=InputEventKey.new()
	event.keycode=code;event.physical_keycode=code;event.pressed=false
	b._unhandled_input(event)
	samples.append({"case":case_name,"phase":"key_up_queued","code":code,"state":_snapshot(b)})
func _tap(b: Node2D, code: int, echo := false) -> void:_down(b,code,echo);_up(b,code)
func _fresh(name: String) -> Node2D:
	case_name=name;_release()
	app.action_lab=false;app.session.profile=app.saves.default_profile()
	app._on_intent("training",null);app._on_intent("select_training_character","crt_3")
	var b: Node2D=app.battle
	b.manual_clock=true;b.set_physics_process(false)
	for enemy: Node2D in b.enemies:enemy.position=Vector2(520,-1000)
	_check("normal Main training enters CRT3 idle",app.screen=="battle" and not app.action_lab and b.is_training() and int(b.player.definition.source_crt)==3 and b.player.parent_frame==101,_snapshot(b))
	return b
func _frame(b: Node2D, action: String, frame: int, cap:=30) -> bool:
	for i in range(cap+1):
		if b.player.state!=action or b.ended:return false
		if b.player.source_frame==frame:return true
		if i<cap:_tick(b)
	return false
func _idle(b: Node2D, cap:=35) -> bool:
	for i in range(cap+1):
		if b.player.state=="idle":return true
		if b.ended:return false
		if i<cap:_tick(b)
	return false

func _pure_chain(b: Node2D, follow_frame: int, echo: bool) -> void:
	var start_mp: float=b.player.mp
	var start_cubes: int=b.session.profile.progress.clear_cubes
	_tap(b,KEY_X)
	_check("pure X starts original106/5820 and counter1",b.player.parent_frame==106 and b.player.state=="basic" and int(b.crt3.pyeongta)==1 and b.player.definition.actions.basic.animation=="crt3_basic1",_snapshot(b))
	var ready:=_frame(b,"basic",follow_frame)
	_check("first original X window is reached",ready,_snapshot(b))
	if not ready:return
	var serial: int=b.player.action_serial
	_tap(b,KEY_X,echo)
	_check("same-parent play retains current child and counter in event tick",b.player.parent_frame==106 and b.player.source_frame==follow_frame and b.player.action_serial==serial and int(b.crt3.pyeongta)==1,_snapshot(b))
	_tick(b)
	_check("next source tick naturally enters107 and rebuilds5821 once",b.player.parent_frame==107 and b.player.source_frame==1 and b.player.state=="basic2" and b.player.action_serial==serial+1 and int(b.crt3.pyeongta)==2 and b.player.definition.actions.basic2.animation=="crt3_basic2",_snapshot(b))
	_tick(b)
	_check("107 stop preserves parent while child proceeds",b.player.parent_frame==107 and b.player.source_frame==2 and int(b.crt3.pyeongta)==2,_snapshot(b))
	ready=_frame(b,"basic2",8)
	_check("second original X window is reached",ready,_snapshot(b))
	if ready:
		_tap(b,KEY_X,echo)
		_check("only X reaches108/5822 with counter unchanged",b.player.parent_frame==108 and b.player.state=="basic3" and b.player.source_frame==1 and int(b.crt3.pyeongta)==2 and b.player.definition.actions.basic3.animation=="crt3_basic3",_snapshot(b))
	_check("complete pure X chain returns101 and resets both counters",_idle(b) and b.player.parent_frame==101 and int(b.crt3.pyeongta)==0 and int(b.crt3.rigui)==0,_snapshot(b))
	_check("pure X adds no MP/cube transaction",is_equal_approx(start_mp,b.player.mp) and start_cubes==int(b.session.profile.progress.clear_cubes),_snapshot(b))

func _test_pure_and_repeat() -> void:
	var b:=_fresh("pure_new_press_right")
	_pure_chain(b,9,false)
	case_name="repeat_same_encounter_left"
	Input.action_press("move_left");_tick(b);Input.action_release("move_left");_tick(b)
	_check("ordinary movement turns next chain left",b.player.facing==-1,_snapshot(b))
	_pure_chain(b,17,false)
	_check("late-window repeated chain preserves selected left facing",b.player.facing==-1,_snapshot(b))
	b=_fresh("pure_echo_events")
	_pure_chain(b,9,true)

func _test_event_boundaries() -> void:
	var b:=_fresh("hold_without_new_event")
	_down(b,KEY_X)
	var later_parent:=false
	for i in range(25):
		_tick(b);later_parent=later_parent or b.player.parent_frame in [107,108]
	_up(b,KEY_X)
	_check("holding X without new keyDown cannot fabricate a continuation",not later_parent and b.player.parent_frame==101 and int(b.crt3.pyeongta)==0,_snapshot(b))
	b=_fresh("early_press_and_release")
	_tap(b,KEY_X)
	var ready:=_frame(b,"basic",8)
	_check("pre-window source8 reached",ready,_snapshot(b))
	if ready:
		var serial: int=b.player.action_serial
		_tap(b,KEY_X)
		_check("source8 keyDown does not buffer into source9",b.player.parent_frame==106 and b.player.source_frame==9 and b.player.action_serial==serial,_snapshot(b))
	_check("released early input simply finishes first X",_idle(b) and b.player.parent_frame==101 and int(b.crt3.pyeongta)==0,_snapshot(b))
	b=_fresh("resume_then_echo_next_tick")
	_down(b,KEY_X)
	ready=_frame(b,"basic",9)
	_check("held first X reaches continuation window",ready,_snapshot(b))
	if ready:
		_down(b,KEY_X,true)
		var serial: int=b.player.action_serial
		_down(b,KEY_X,true)
		_check("another echo cannot postpone an already playing parent",b.player.parent_frame==107 and b.player.source_frame==1 and b.player.action_serial==serial+1 and int(b.crt3.pyeongta)==2,_snapshot(b))
	_release();_idle(b)

func _test_mixed_and_interruptions() -> void:
	var b:=_fresh("mixed_X_S_X2_X3")
	_tap(b,KEY_X)
	if _frame(b,"basic",9):
		_tap(b,KEY_S)
		_check("X to S retains original rigui entry117",b.player.parent_frame==117 and int(b.crt3.rigui)==1 and int(b.crt3.pyeongta)==1,_snapshot(b))
		Input.action_press("attack")
		for i in range(20):
			if b.player.parent_frame==107:break
			_tick(b)
		_release()
		_check("S held-X polling selects107 using original counter",b.player.parent_frame==107 and int(b.crt3.pyeongta)==2,_snapshot(b))
		if _frame(b,"basic2",8):_tap(b,KEY_X)
		_check("mixed continuation reaches108",b.player.parent_frame==108,_snapshot(b))
	_check("mixed chain returns with cleared counters",_idle(b) and int(b.crt3.rigui)==0 and int(b.crt3.pyeongta)==0,_snapshot(b))
	b=_fresh("pending_resume_interrupted_by_hurt")
	_tap(b,KEY_X)
	if _frame(b,"basic",9):_tap(b,KEY_X)
	# Public production damage is an explicit interruption fixture, not natural AI.
	b.player.receive_damage(1.0)
	_check("damage changes active parent to source133",b.player.state=="hit" and b.player.parent_frame==133,_snapshot(b))
	_tick(b)
	_check("interruption cancels pending parent playback",b.player.parent_frame==133 and b.player.state=="hit",_snapshot(b))
	_check("hurt returns idle without ghost X2",_idle(b) and b.player.parent_frame==101,_snapshot(b))
	_pure_chain(b,9,false)
	b=_fresh("backstep_cancels_pending")
	_tap(b,KEY_X)
	if _frame(b,"basic",9):_tap(b,KEY_X)
	_tap(b,KEY_DOWN)
	_check("normal down cancels into130 instead of pending107",b.player.parent_frame==130 and b.player.state=="backstep",_snapshot(b))
	_check("backstep completes and permits a new chain",_idle(b),_snapshot(b))
	_pure_chain(b,9,false)

func _test_reentry() -> void:
	var old:=_fresh("pending_then_leave")
	_tap(old,KEY_X)
	if _frame(old,"basic",9):_tap(old,KEY_X)
	var b:=_fresh("reentered_clean")
	_check("normal reentry disposes old pending encounter",old!=b and old.is_queued_for_deletion() and b.player.parent_frame==101 and int(b.crt3.pyeongta)==0,_snapshot(b))
	_pure_chain(b,9,false)

func _run() -> void:
	if "--test-mode" not in OS.get_cmdline_user_args():push_error("ACT06 combo requires --test-mode");quit(2);return
	formal_exists=FileAccess.file_exists("user://profile.json")
	if formal_exists:formal_hash=FileAccess.get_sha256("user://profile.json")
	for directory: String in ["res://content/actions/crt3","res://content/components/crt3"]:
		for filename: String in DirAccess.get_files_at(directory):
			if filename.ends_with(".tres"):author_hashes[directory.path_join(filename)]=FileAccess.get_sha256(directory.path_join(filename))
	app=MainScene.instantiate();root.add_child(app);app.set_process(false)
	_check("actual Main loads enabled CRT3",app.startup_ok and app.test_mode and app.database.characters.has("crt_3"),app.database.issues)
	if app.startup_ok:
		app.saves=Save.new("user://act06_combo/run_%d_%d/profile.json"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()])
		app.audio.sound_played.connect(func(alias:String,stream:AudioStream,offset:float,voice:AudioStreamPlayer)->void:sounds.append({"case":case_name,"alias":alias,"path":stream.resource_path if stream!=null else "","valid":stream!=null and is_instance_valid(voice) and voice.stream==stream and voice.playing and voice.has_stream_playback(),"offset":offset}))
		_test_pure_and_repeat();_test_event_boundaries();_test_mixed_and_interruptions();_test_reentry()
	_release()
	_check("actual original audio streams still consumed",not sounds.is_empty() and sounds.all(func(r:Dictionary)->bool:return r.valid),sounds.size())
	_check("formal profile untouched",FileAccess.file_exists("user://profile.json")==formal_exists and (not formal_exists or FileAccess.get_sha256("user://profile.json")==formal_hash))
	var unchanged:=true
	for path: String in author_hashes:unchanged=unchanged and FileAccess.get_sha256(path)==author_hashes[path]
	_check("author action and component values untouched",unchanged)
	app._dispose_battle()
	var drained: bool=await app.audio.stop_and_drain(1.0)
	_check("audio teardown drains actual playback",drained and app.audio.snapshot().pending_playbacks==0)
	app.queue_free();await process_frame
	var failures: int=checks.filter(func(r:Dictionary)->bool:return not r.passed).size()
	var output:=OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if output.is_empty():output="res://artifacts/leba_act06_20261117/combo/run_%d_%d"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var file:=FileAccess.open(output.path_join("act06_combo.json"),FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples,"sounds":sounds,"godot":Engine.get_version_info(),"source_evidence":"artifacts/leba_act06_20261117/investigation/crt3_combo.json","fixtures":["manual25Hz source clock","one initial enemy offscreen placement per encounter, ordinary AI remains active","public receive_damage1 only for interruption"],"not_tested":["actual GPU pixels/host keyboard in Godot","normal AI combat damage and exact original finalHP","audible listening or native Adobe Flash"]},"\t")+"\n");file.close()
	print("ACT06_COMBO_RESULT "+JSON.stringify({"checks":checks.size(),"failures":failures}))
	quit(0 if failures==0 else 1)
