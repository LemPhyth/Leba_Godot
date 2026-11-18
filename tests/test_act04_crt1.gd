extends SceneTree
## Actual formal Resource -> Combatant -> Battle -> AudioDirector playback requests.
## Source seeks isolate main event wiring; normal key cases exercise child clocks.
## Dummy audio verifies streams and requests, not human listening or OS input.
const MainScene = preload("res://scenes/main.tscn")
const Convert = preload("res://tools/content_conversion.gd")
const Migration = preload("res://tools/content_audio_migration.gd")
const AuditPath := "res://artifacts/leba_act04_20261117/investigation/crt1_audio_audit.json"
const PatchPath := "res://artifacts/leba_act04_20261117/investigation/crt1_nested_audio_patch.json"
const INPUTS := ["move_left","move_right","attack","jump","down","aim_up","skill_w"]
var app: Node
var audit: Dictionary
var checks: Array[Dictionary] = []
var sounds: Array[Dictionary] = []
var scope := ""
var output := ""
var formal_exists := false
var formal_hash := ""
var author_hashes: Dictionary = {}

func _initialize() -> void:call_deferred("_run")

func _check(label: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"name":label,"passed":passed,"detail":detail})
	print(("PASS " if passed else "FAIL ")+label)

func _hash_authors() -> Dictionary:
	var result := {}
	for folder: String in ["res://content/actions/crt1","res://content/components/crt1"]:
		for name: String in DirAccess.get_files_at(folder):
			var path := folder.path_join(name)
			result[path] = FileAccess.get_sha256(path)
	return result

func _played(alias: String, stream: AudioStream, offset: float, voice: AudioStreamPlayer) -> void:
	var player: Node2D = app.battle.player if is_instance_valid(app.battle) else null
	# AudioDirector deliberately duplicates imported alias streams to disable
	# looping without mutating the import. That copy has no resource_path; verify
	# its real registry identity plus declared source path, not a fictional path.
	var registered: bool = alias.is_empty() or app.audio._streams.get("sfx/"+alias) == stream
	var source_path: String = stream.resource_path if alias.is_empty() else str(app.audio._catalog.sfx.get(alias,""))
	sounds.append({"scope":scope,"alias":alias,"stream_id":stream.get_instance_id(),"stream_path":stream.resource_path,"source_path":source_path,"alias_stream_matches":registered,"length":stream.get_length(),"offset":offset,"voice_id":voice.get_instance_id(),"playing":voice.playing,"has_playback":voice.has_stream_playback(),"voice_stream_matches":voice.stream == stream,"state":player.state if player != null else "","frame":player.source_frame if player != null else 0,"air_frame":player.air_action_frame if player != null else 0,"tick":int(app.session.run.get("source_ticks",0))})

func _release() -> void:
	for action: String in INPUTS:Input.action_release(action)

func _fresh(ready_ticks := 2) -> Node2D:
	_release()
	app.action_lab = false
	app.session.profile = app.saves.default_profile()
	app._on_intent("select_training_character","crt_1")
	var battle: Node2D = app.battle
	battle.manual_clock = true
	battle.set_physics_process(false)
	# Explicit one-time no-contact fixture. No runtime outcomes are replayed.
	for enemy: Node2D in battle.enemies:enemy.position = Vector2(520,-1000)
	for tick in range(ready_ticks):battle.step({})
	return battle

func _tick(battle: Node2D, count := 1) -> void:
	for tick in range(count):battle.step(battle.take_commands())

func _key(battle: Node2D, code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	battle._unhandled_input(event)
	_tick(battle)
	event.pressed = false
	battle._unhandled_input(event)

func _until_idle(battle: Node2D, cap := 400) -> bool:
	for tick in range(cap):
		if battle.player.state == "idle":return true
		if battle.ended:return false
		_tick(battle)
	return false

func _alias_rows(alias: String, from_index := 0) -> Array:
	return sounds.slice(from_index).filter(func(row: Dictionary)->bool:return row.alias == alias)

func _has_voice(row: Dictionary, offset: float, path: String) -> bool:
	return row.playing and row.has_playback and row.voice_stream_matches and row.alias_stream_matches and row.length > offset and is_equal_approx(row.offset,offset) and row.source_path == path

func _test_converter_and_migration() -> void:
	var character: Resource = load("res://content/characters/crt_1.tres")
	# The converter consumes the original catalog. ContentDB replaces animation
	# rows with SourceAnimation.to_runtime(), whose runtime schema intentionally
	# omits source_frame_sequence/source_sprite_id provenance.
	var assets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_catalog.json"))
	var missing := 0
	for evidence: Dictionary in audit.actions:
		var action: Resource
		for entry: Resource in character.actions:
			if entry.identifier == evidence.id:action = entry;break
		var json_frames: Array = assets.animations[action.animation_key].source_frame_sequence
		var typed: Array = Array(action.sequence)
		var from_json: Array = Convert.new().source_sounds(action.animation_key,assets,json_frames)
		var from_author: Array = Convert.new().source_sounds(action.animation_key,assets,typed)
		_check("normalized JSON/author source frame domain "+action.identifier,from_json == from_author and from_json.size() == evidence.expected_catalog_sounds.size(),{"expected":evidence.expected_catalog_sounds.size(),"actual":from_json.size()})
		for expected: Dictionary in evidence.expected_catalog_sounds:
			var matches: Array = action.events.filter(func(event: Resource)->bool:return event.kind == "sound" and event.sound == expected.key and int(event.frame) == int(expected.frame))
			var okay: bool = matches.size() == 1 and matches[0].audio_stream != null and is_equal_approx(matches[0].audio_offset,expected.offset_seconds)
			_check("formal source event "+str(expected.key),okay,{"action":action.identifier,"frame":expected.frame,"sound_id":expected.sound_id,"matches":matches.size()})
			if not okay:missing += 1
	_check("all62 missing main source sounds are present in delivered Resources",missing == 0 and int(audit.counts.missing_main_catalog_events_before_migration) == 62)
	var fixture: Resource = load("res://content/actions/crt1/skill_q.tres").duplicate(true)
	fixture.events = fixture.events.filter(func(event: Resource)->bool:return event.sound != "crt1_skill_q")
	fixture.cost = 12.5 # Deliberate private author edit, not original skill cost.
	fixture.cooldown_ticks = 731
	var custom := Convert.Event.new()
	custom.frame = 4
	custom.kind = "root_offset"
	custom.parameters = {"x":7.25}
	fixture.events.append(custom)
	var before: Dictionary = fixture.to_runtime()
	before.erase("events")
	var retained: Array = fixture.events.duplicate()
	var first: Dictionary = Migration.new().apply_action(fixture,assets)
	var second: Dictionary = Migration.new().apply_action(fixture,assets)
	var after: Dictionary = fixture.to_runtime()
	after.erase("events")
	_check("targeted repair adds only the missing source sound and is idempotent",first.added.size() == 1 and second.added.is_empty())
	_check("repair preserves edited costs cooldowns windows and custom events",before == after and retained.all(func(event: Resource)->bool:return event in fixture.events))
	var fixture_path := output.path_join("edited_q_repair.tres")
	var save_result := ResourceSaver.save(fixture,fixture_path)
	var reopened: Resource = ResourceLoader.load(fixture_path,"",ResourceLoader.CACHE_MODE_IGNORE) if save_result == OK else null
	_check("private repaired Resource saves and reloads with author edits",reopened != null and reopened.cost == 12.5 and reopened.cooldown_ticks == 731 and reopened.events.size() == fixture.events.size())
	var override: Resource = load("res://content/actions/crt1/skill_q.tres").duplicate(true)
	override.events = override.events.filter(func(event: Resource)->bool:return event.sound != "crt1_skill_q")
	var sound := Convert.Event.new() # kind=sound uses the script default.
	sound.frame = 4
	sound.sound = "custom_author_sound"
	sound.audio_stream = load(assets.audio.sfx.move)
	sound.audio_offset = 0.013
	override.events.append(sound)
	var preserve: Dictionary = Migration.new().apply_action(override,assets)
	_check("same-frame authored audio override is retained without duplicate source audio",preserve.added.is_empty() and preserve.author_overrides.size() == 1 and sound in override.events and sound.audio_offset == 0.013)

func _test_all_formal_main_requests() -> void:
	# Controlled source seek is an existing production operation. No event is
	# injected and no fake AudioService is substituted. Input behavior is tested
	# separately by ACT03 and the normal-key cases below.
	var character: Resource = load("res://content/characters/crt_1.tres")
	for action: Resource in character.actions:
		var events: Array = action.events.filter(func(event: Resource)->bool:return event.kind == "sound")
		if events.is_empty():continue
		var battle := _fresh()
		scope = "formal_source_seek/"+action.identifier
		var frames := {}
		for event: Resource in events:frames[int(event.frame)] = true
		for frame: int in frames:
			battle.player.set_action(action.identifier)
			var first := sounds.size()
			var sought: bool = battle.player.seek_action_frame(frame)
			var actual := sounds.slice(first).filter(func(row: Dictionary)->bool:return row.alias.is_empty())
			var expected := events.filter(func(event: Resource)->bool:return int(event.frame) == frame)
			var okay := sought and actual.size() == expected.size()
			for index in range(mini(actual.size(),expected.size())):
				var event: Resource = expected[index]
				var stream: AudioStream = event.audio_stream
				okay = okay and stream != null and actual[index].stream_id == stream.get_instance_id() and _has_voice(actual[index],event.audio_offset,stream.resource_path) and actual[index].frame == frame
			_check("formal Combatant/Battle requests every source sound "+action.identifier+"/"+str(frame),okay,{"expected":expected.size(),"actual":actual})
			# Re-dispatching the same current source frame without a seek must not
			# replay its events. The actor's existing event cursor is the authority.
			var count := sounds.size()
			battle.player._dispatch_frame_events(battle.player.definition.actions[action.identifier],battle.player.action_serial)
			_check("same source frame event cursor does not replay "+action.identifier+"/"+str(frame),sounds.size() == count)

func _test_nested_h_e_t() -> void:
	for spec: Array in [["move_left","h_back"],["down","h_down"],["aim_up","h_up"]]:
		var battle := _fresh()
		scope = "normal_H/"+str(spec[1])
		var first := sounds.size()
		_key(battle,KEY_H)
		Input.action_press(spec[0])
		for tick in range(20):
			if battle.player.state == spec[1]:break
			_tick(battle)
		_release()
		var entered: bool = battle.player.state == spec[1]
		var ended := _until_idle(battle,80)
		var rows := _alias_rows("crt1_h_direction_child",first)
		_check("H actual direction child2 sound "+str(spec[1]),entered and ended and rows.size() == 1 and rows[0].frame == 4,rows)
	var battle := _fresh()
	scope = "normal_E_complete"
	var first := sounds.size()
	_key(battle,KEY_E)
	var ended := _until_idle(battle,80)
	var flash := _alias_rows("crt1_e_flash_child",first)
	var tail := _alias_rows("crt1_e_tail_child",first)
	var patch: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PatchPath))
	var expected_flash: Array = []
	var expected_tail: Array = []
	for pair: Array in patch.e_expected_uncancelled_observations.flash_parent_frames:
		for n in range(int(pair[1])):expected_flash.append(int(pair[0]))
	for pair: Array in patch.e_expected_uncancelled_observations.tail_parent_frames:
		for n in range(int(pair[1])):expected_tail.append(int(pair[0]))
	_check("E sixteen independent flash clocks play only at their source2",ended and flash.map(func(row: Dictionary):return int(row.frame)) == expected_flash,flash)
	_check("E fourteen tail clocks reach11 while final two are removed first",tail.map(func(row: Dictionary):return int(row.frame)) == expected_tail,tail)
	battle = _fresh()
	scope = "normal_E_cancel"
	first = sounds.size()
	_key(battle,KEY_E)
	while battle.player.state == "skill_e" and battle.player.source_frame < 5:_tick(battle)
	_key(battle,KEY_C)
	var cancel_count := sounds.size()
	_tick(battle,20)
	_check("E C cancel removes all pending child sounds with its action",battle.player.state == "idle" and _alias_rows("crt1_e_tail_child",first).is_empty() and _alias_rows("crt1_e_flash_child",cancel_count).is_empty())
	battle = _fresh(450)
	scope = "normal_T"
	first = sounds.size()
	_key(battle,KEY_T)
	ended = _until_idle(battle,400)
	var phase := _alias_rows("crt1_t_phase_hit",first)
	var air := _alias_rows("crt1_t_air_container",first)
	_check("T six independent phase children play at source2",ended and phase.map(func(row: Dictionary):return int(row.frame)) == [16,16,36,36,53,53],phase)
	_check("T air container source1 plays once despite held parent66",air.size() == 1 and air[0].frame == 66,air)

func _test_existing_and_r_clocks() -> void:
	var battle := _fresh()
	scope = "normal_jump"
	_key(battle,KEY_C)
	Input.action_press("attack")
	_until_idle(battle,80)
	_release()
	battle = _fresh()
	scope = "normal_D_follow"
	battle.enemies[0].position = battle.player.position+Vector2(25,36) # Explicit one-time contact seed.
	_key(battle,KEY_D)
	for tick in range(20):
		if battle.player.state != "skill" or battle.player.source_frame >= 12:break
		_tick(battle)
	_key(battle,KEY_Z)
	Input.action_press("attack")
	_until_idle(battle,80)
	_release()
	battle = _fresh()
	scope = "normal_W"
	_key(battle,KEY_W)
	Input.action_press("attack")
	_tick(battle,15)
	_release()
	_key(battle,KEY_C)
	battle = _fresh()
	scope = "normal_R_three_stages"
	var first := sounds.size()
	_key(battle,KEY_R)
	for stage in [1,2]:
		Input.action_press("move_right")
		for tick in range(80):
			if battle.player.state == "r_catch%d"%stage:break
			_tick(battle)
		_release()
		var caught: bool = battle.player.state == "r_catch%d"%stage
		_check("R sound fixture uses real pickup for segment%d"%stage,caught)
		if not caught:break
		while battle.player.source_frame < 5:_tick(battle)
		_key(battle,KEY_X)
	_tick(battle,110)
	for stage in [1,2,3]:
		var rows := _alias_rows("crt1_r_helper%d"%stage,first)
		_check("R segment%d independent child loops request actual sound"%stage,not rows.is_empty(),{"count":rows.size()})
	var after_exit := sounds.size()
	_tick(battle,12)
	_check("completed R objects cannot continue their child sound clocks",battle._gunhawks.is_empty() and sounds.slice(after_exit).all(func(row: Dictionary)->bool:return not row.alias.begins_with("crt1_r_helper")))

func _matrix(values: Array) -> Transform2D:
	return Transform2D(Vector2(values[0],values[1]),Vector2(values[2],values[3]),Vector2(values[4],values[5]))

func _test_q_visual_and_lifecycle() -> void:
	for facing in [1,-1]:
		var battle := _fresh()
		scope = "normal_Q/"+str(facing)
		battle.player.set_facing(facing)
		_key(battle,KEY_Q)
		for tick in range(25):
			if int(battle.crt1.buff_frame) >= 2:break
			_tick(battle)
		_check("Q source2 begins independent visible edge "+str(facing),int(battle.crt1.buff_frame) == 2 and battle._crt1_views.buff_edges.visible)
		_tick(battle,7)
		var data: Dictionary = battle.player.definition.actions.skill_q.component_data
		var source_ids := PackedInt32Array(data.parts.map(func(part: Dictionary):return int(part.source_id)))
		source_ids.sort()
		_check("Q retained source9 display list includes the visible yellow4591 icon "+str(facing),source_ids == PackedInt32Array([4580,4589,4591]),Array(source_ids))
		for index in range(data.parts.size()):
			var part: Dictionary = data.parts[index]
			var view: Node2D = battle._crt1_views["buff_part%d"%index]
			var generated: Dictionary = view.definition
			var baked: Array = generated.get("baked_placement_matrix",[])
			var alpha := float(generated.get("baked_alpha_mult",0))
			var actor_scale: Vector2 = battle.player.visual_scale*Vector2(facing,1)
			var expected := Transform2D(Vector2(actor_scale.x,0),Vector2(0,actor_scale.y),Vector2.ZERO)*_matrix(data.parent_placement.matrix)*_matrix(part.matrix)
			var effective := view.transform*_matrix(baked) if baked.size() == 6 else Transform2D.IDENTITY
			_check("Q corrected child basis and alpha apply once "+str(facing)+"/"+str(part.source_id),view.visible and view.source_frame == 1 and baked.size() == 6 and effective.is_equal_approx(expected) and is_equal_approx(view.modulate.a*alpha,float(part.alpha_mult)),{"baked":baked,"alpha":alpha,"effective":str(effective),"expected":str(expected)})
		for tick in range(410):
			if int(battle.crt1.buff_frame) >= 401:break
			_tick(battle)
		var sustained_hidden := true
		for index in range(data.parts.size()):sustained_hidden = sustained_hidden and not battle._crt1_views["buff_part%d"%index].visible
		_check("Q source401 hides all sustained children and shows ending edge "+str(facing),battle._crt1_views.buff_edges.visible and sustained_hidden)
		_tick(battle,7)
		_check("Q completed407 resets without residual visible parts "+str(facing),int(battle.crt1.buff_frame) == 1 and battle._crt1_views.values().all(func(view: Node2D)->bool:return not view.visible))
		app._on_intent("training_restore",null)
		_tick(battle,2)
		_key(battle,KEY_Q)
		_tick(battle,12)
		var old: Node2D = battle
		var views: Array = battle._crt1_views.values()
		app._on_intent("select_training_character","crt_0")
		app.battle.set_physics_process(false)
		_check("switching role removes the prior Q hierarchy "+str(facing),old.is_queued_for_deletion() and app.battle != old and views.all(func(view: Node2D)->bool:return old.is_ancestor_of(view)))
		battle = _fresh()
		_check("reentering CRT1 starts no buff or stale Q sound task "+str(facing),int(battle.crt1.buff_frame) == 1 and battle._crt1_views.is_empty())

func _verify_all_child_streams() -> void:
	for family: Dictionary in audit.component_sound_clocks:
		for key: String in family.catalog_keys:
			var source: Dictionary = app.database.assets.audio_events[key]
			var rows := _alias_rows(key)
			_check("existing independent source stream consumed "+key,not rows.is_empty() and rows.all(func(row: Dictionary)->bool:return _has_voice(row,float(source.get("in_point_samples_44100",0))/44100.0,app.database.assets.audio.sfx[key])),{"requests":rows.size()})
	var patch: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PatchPath))
	for source_id: String in patch.aliases:
		var key: String = patch.aliases[source_id]
		var source: Dictionary = app.database.assets.audio_events.get(key,{})
		var rows := _alias_rows(key)
		_check("new nested source stream consumed "+key,not source.is_empty() and not rows.is_empty() and rows.all(func(row: Dictionary)->bool:return _has_voice(row,float(source.get("in_point_samples_44100",0))/44100.0,app.database.assets.audio.sfx[key])),{"requests":rows.size()})

func _run() -> void:
	output = OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if output.is_empty():output = "res://artifacts/leba_act04_20261117/crt1/run_%d_%d"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	author_hashes = _hash_authors()
	formal_exists = FileAccess.file_exists("user://profile.json")
	if formal_exists:formal_hash = FileAccess.get_sha256("user://profile.json")
	OS.set_environment("LEBA_TEST_MODE","1")
	OS.set_environment("LEBA_SILENT_TEST","1")
	OS.set_environment("LEBA_TEST_PROFILE","user://act04_crt1/%d_%d/profile.json"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()])
	audit = JSON.parse_string(FileAccess.get_file_as_string(AuditPath))
	app = MainScene.instantiate()
	root.add_child(app)
	app.set_process(false)
	_check("formal Main starts with isolated profile and Dummy audio",app.startup_ok and app.test_mode and not app.saves.path == "user://profile.json")
	if app.startup_ok:
		app.audio.sound_played.connect(_played)
		_test_converter_and_migration()
		_test_all_formal_main_requests()
		_test_nested_h_e_t()
		_test_existing_and_r_clocks()
		_test_q_visual_and_lifecycle()
		_verify_all_child_streams()
	_release()
	if is_instance_valid(app.battle):app._dispose_battle()
	await app.audio.stop_and_drain()
	app.queue_free()
	await process_frame
	_check("formal author Resources remain byte-identical",_hash_authors() == author_hashes)
	_check("formal profile is unchanged",FileAccess.file_exists("user://profile.json") == formal_exists and (not formal_exists or FileAccess.get_sha256("user://profile.json") == formal_hash))
	var failures := checks.filter(func(row: Dictionary)->bool:return not row.passed).size()
	var file := FileAccess.open(output.path_join("act04_crt1_tests.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"sound_requests":sounds,"author_hashes":author_hashes,"scope":"Dummy actual formal Resource/Combatant/Battle/AudioDirector requests. Main event wiring uses controlled source seek; nested clocks and Q use normal bound keys with declared no-contact/contact fixtures. No audible listening, original runtime timing or new GPU image acceptance."},"\t")+"\n")
	print("ACT04_CRT1_TESTS_RESULT ",JSON.stringify({"checks":checks.size(),"failures":failures}))
	quit(0 if failures == 0 else 1)
