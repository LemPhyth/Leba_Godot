extends SceneTree
## Engineering fixtures for the actual author-resource boundary. All saves go to
## a new artifacts directory. These edited values are NOT original game rules.
## Main, the real Battle, native InputMap events, actors and AudioDirector run.
const MainScene = preload("res://scenes/main.tscn")
const EventData = preload("res://scripts/content/action_event.gd")
const WindowData = preload("res://scripts/content/hit_window.gd")
const STAGE_ID := "editor_fixture_stage"
const CHARACTER_ID := "editor_fixture_crt0"
const ENEMY_ID := "editor_fixture_enemy7437"
const COPY_ACTION := "editor_copy_s"
const COPY_INPUT := "editor_copy_input"
const PLAYER_AT := Vector2(120,295)
const HP_LAYOUT_AT := Vector2(47.25,62.5)
const HUD_AT := Vector2(7,4)
const MAP_AT := Vector2(13,17)
const HIT_RECT := Rect2(35,-100,105,160)
var directory := ""
var checks: Array[Dictionary] = []
var event_records: Array[Dictionary] = []
var author_hashes: Dictionary = {}
var fixture_hashes: Dictionary = {}
var saved_fixture_resources := PackedStringArray()
var formal_exists := false
var formal_hash := ""
var previous_test_profile := ""
var custom_input_existed := false
var custom_input_events: Array[InputEvent] = []
var loaded_index: Resource
var applications: Array[Node] = []
var viewports: Array[SubViewport] = []

func _initialize() -> void:call_deferred("_run")

func _check(label: String, condition: bool, detail: Variant = "") -> void:
	checks.append({"name":label,"passed":condition,"detail":detail})
	print(("PASS " if condition else "FAIL ")+label+" "+str(detail))

func _hash_tree(path: String, result: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:return
	for filename: String in dir.get_files():result[path.path_join(filename)] = FileAccess.get_sha256(path.path_join(filename))
	for child: String in dir.get_directories():_hash_tree(path.path_join(child),result)

func _unchanged(snapshot: Dictionary) -> bool:
	for path: String in snapshot:
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != snapshot[path]:return false
	return true

func _save(resource: Resource, filename: String) -> Resource:
	var path := directory.path_join(filename)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var error := ResourceSaver.save(resource,path)
	_check("save isolated author file "+filename,error == OK,error)
	if error != OK:return null
	if path not in saved_fixture_resources:saved_fixture_resources.append(path)
	return ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP)

func _sync_generated_check() -> void:
	# Only this isolated generated copy is deliberately made stale. Production
	# generated metadata is hashed but never written by this test case.
	var real_generated: Dictionary = {}
	_hash_tree("res://generated/animations",real_generated)
	var fixture_root := directory.path_join("generated/animations")
	var stale: Resource = load("res://generated/animations/crt0_skill_s.tres").duplicate(false)
	stale.frames = stale.frames.duplicate(true)
	stale.frames[0].pivot[0] += 3.0
	stale.parent_scale = Vector2(1.25,0.75)
	stale.source = "Intentionally stale isolated metadata; engineering fixture"
	var fixture_file := fixture_root.path_join("crt0_skill_s.tres")
	_save(stale,"generated/animations/crt0_skill_s.tres")
	# Include a real UID-bearing file so preservation is tested through a save,
	# not only through the current production files' absent UID state.
	var uid := ResourceUID.id_to_text(ResourceUID.create_id())
	var source := FileAccess.get_file_as_string(fixture_file)
	var header := source.get_slice("\n",0)
	var uid_pattern := RegEx.new()
	uid_pattern.compile(' uid="[^"]+"')
	var new_header := uid_pattern.sub(header,"",true).trim_suffix("]")+' uid="'+uid+'"]'
	var uid_file := FileAccess.open(fixture_file,FileAccess.WRITE)
	uid_file.store_string(source.replace(header,new_header))
	uid_file.close()
	var previous_generated: Dictionary = {}
	var results: Array[Dictionary] = []
	for iteration in [1,2]:
		var report := directory.path_join("sync_%d.json"%iteration)
		var output: Array = []
		var args := PackedStringArray(["--headless","--audio-driver","Dummy","--path",ProjectSettings.globalize_path("res://"),"--script","res://tools/sync_generated_animations.gd","--","--sync-generated","--fixture-generated="+fixture_root,"--report="+report])
		var code := OS.execute(OS.get_executable_path(),args,output,true)
		var log := FileAccess.open(directory.path_join("sync_%d.log"%iteration),FileAccess.WRITE)
		if log != null:
			for line: Variant in output:log.store_string(str(line))
			log.close()
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(report)) if FileAccess.file_exists(report) else null
		_check("explicit generated synchronization run%d succeeds"%iteration,code == 0 and parsed is Dictionary and parsed.failures.is_empty(),{"exit":code,"report":report})
		if parsed is Dictionary:
			results.append(parsed)
			_check("sync run%d preserves original author hashes"%iteration,bool(parsed.authors_unchanged) and _unchanged(author_hashes),parsed.author_file_count)
			if iteration == 1:_check("isolated stale metadata exercises an actual one-file save",parsed.updated == [fixture_file],parsed.updated)
		var snapshot: Dictionary = {}
		_hash_tree(fixture_root,snapshot)
		if iteration == 2:
			_check("second synchronization is byte-idempotent and writes no files",code == 0 and snapshot == previous_generated and parsed is Dictionary and parsed.failures.is_empty() and parsed.updated.is_empty(),snapshot.size())
		previous_generated = snapshot
	if results.size() == 2:_check("UID-bearing generated copy retains UID through actual save",results[0].updated == [fixture_file] and results[0].failures.is_empty() and results[1].failures.is_empty() and results[0].uid_tokens_before == results[1].uid_tokens_before and results[1].uid_tokens_before.get(fixture_file) == uid,uid)
	var refreshed: Resource = ResourceLoader.load(fixture_file,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_catalog.json"))
	var expected: Dictionary = catalog.animations.crt0_skill_s
	_check("actual sync restores catalog pivot frames texture and parent scale",refreshed.frames == expected.frames and refreshed.texture.resource_path == str(expected.texture) and refreshed.parent_scale == Vector2(expected.get("parent_scale",[1.0,1.0])[0],expected.get("parent_scale",[1.0,1.0])[1]) and refreshed.source == "asset_catalog.animations.crt0_skill_s；派生图集；来源与pivot见catalog。")
	_check("isolated write-branch verification leaves real generated files untouched",_unchanged(real_generated),real_generated.size())

func _build_fixture() -> Resource:
	var original: Resource = load("res://content/index.tres")
	# A saved one-second silent PCM stream proves the explicit AudioStream field
	# wins over a deliberately nonexistent catalog alias, with no audible output.
	var pcm := AudioStreamWAV.new()
	pcm.format = AudioStreamWAV.FORMAT_8_BITS
	pcm.mix_rate = 8000
	var bytes := PackedByteArray()
	bytes.resize(8000)
	bytes.fill(128)
	pcm.data = bytes
	var audio_stream := _save(pcm,"editor_silence.tres") as AudioStream
	var texture := GradientTexture2D.new()
	texture.width = 17
	texture.height = 11
	texture.gradient = Gradient.new()
	texture.gradient.colors = PackedColorArray([Color(0.7,0.1,0.6),Color(0.1,0.8,0.3)])
	var map_texture := _save(texture,"editor_map.tres") as Texture2D
	var action: Resource = load("res://content/actions/crt0/skill_s.tres").duplicate(true)
	action.cost = 7.25
	action.required_mp = 7.25
	action.cooldown_ticks = 19
	action.sequence = PackedInt32Array([1,2,3,4,6,7,8,9,10])
	action.source = "ACT03 editor engineering fixture, not an original rule"
	action.events.clear()
	action.windows.clear()
	var sound := EventData.new()
	sound.kind = "sound"
	sound.frame = 3
	sound.sound = "editor_stream_has_no_catalog_alias"
	sound.audio_stream = audio_stream
	sound.audio_offset = 0.0
	action.events.append(sound)
	var motion := EventData.new()
	motion.kind = "root_motion"
	motion.frame = 4
	motion.parameters = {"dx":11.25}
	action.events.append(motion)
	var hit := WindowData.new()
	hit.kind = "authored_hit"
	hit.from_frame = 6
	hit.until_frame = 7
	hit.damage = 23.5
	hit.gravity = -2.0
	hit.rectangles.assign([HIT_RECT])
	hit.once_per_action = true
	action.windows.append(hit)
	action = _save(action,"edited_skill_s.tres")
	var copied: Resource = action.duplicate(true)
	copied.identifier = COPY_ACTION
	copied.title = "Editor copied action"
	copied.input_id = COPY_INPUT
	copied.cost = 2.0
	copied.required_mp = 2.0
	copied.cooldown_ticks = 13
	copied.events[0].frame = 4
	copied.events[0].audio_stream = audio_stream
	copied.events[1].frame = 6
	copied.events[1].parameters.dx = 4.5
	copied.windows[0].damage = 9.25
	copied = _save(copied,"copied_action.tres")
	var character: Resource = load("res://content/characters/crt_0.tres").duplicate(false)
	character.identifier = CHARACTER_ID
	character.title = "Editor fixture actor"
	character.actions = character.actions.duplicate()
	for i in range(character.actions.size()):
		if character.actions[i].identifier == "skill_s":character.actions[i] = action
	character.actions.append(copied)
	character = _save(character,"character.tres")
	var enemy: Resource = load("res://content/enemies/goblin_7437.tres").duplicate(false)
	enemy.identifier = ENEMY_ID
	enemy.title = "Editor fixture stationary target"
	enemy.extra = enemy.extra.duplicate(true)
	# Author-only target setup isolates window geometry from enemy AI. No actor
	# positions, HP, cooldowns or collision outcomes are assigned during S/K use.
	enemy.extra.erase("timer")
	enemy.extra.move_rect = [10000.0,10000.0,1.0,1.0]
	enemy.extra.trigger_order = []
	enemy = _save(enemy,"enemy.tres")
	var layout: Node2D = load("res://scenes/stages/root_9.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	layout.scene_file_path = ""
	var rules: Resource = layout.rules.duplicate(true)
	rules.identifier = STAGE_ID
	rules.title = "Editor save/reload fixture"
	rules.training = true
	rules.enemy_type = ENEMY_ID
	rules.enemy_hp = 400.0
	rules.player_max_hp = 100.0
	rules.player_max_mp = 100.0
	rules.next_stage = ""
	rules.difficulty_observer = false
	rules.player_hurt_observers = PackedFloat32Array()
	rules.extra.erase("open_dialogue")
	rules.extra.erase("clear_dialogue")
	layout.rules = _save(rules,"stage_rules.tres")
	layout.get_node("PlayerSpawn").position = PLAYER_AT
	layout.get_node("PlayerSpawn").scale = Vector2.ONE
	layout.get_node("EnemySpawns/Enemy0").position = Vector2(211,340)
	layout.get_node("EnemySpawns/Enemy0").scale = Vector2.ONE
	var extra_spawn := Marker2D.new()
	extra_spawn.name = "Enemy1"
	extra_spawn.position = Vector2(450,340)
	layout.get_node("EnemySpawns").add_child(extra_spawn)
	extra_spawn.owner = layout
	var extra_actor: Node2D = original.enemy_scene.instantiate()
	extra_actor.name = "Actor"
	extra_spawn.add_child(extra_actor)
	extra_actor.owner = layout
	layout.get_node("Floor").position = Vector2(0,330)
	var collision: CollisionShape2D = layout.get_node("Floor/Collision")
	collision.position = Vector2(150,10)
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(300,20)
	collision.shape = rectangle
	layout.get_node("Map").texture = map_texture
	layout.get_node("Map").position = MAP_AT
	var hud: Node2D = layout.get_node("HUD")
	layout.set_editable_instance(hud,true)
	hud.position = HUD_AT
	hud.get_node("Characters/CRT0/HPLayout").position = HP_LAYOUT_AT
	var packed := PackedScene.new()
	_check("pack copied authored scene",packed.pack(layout) == OK)
	layout.free()
	packed = _save(packed,"stage.tscn") as PackedScene
	var registry: Resource = original.duplicate(false)
	registry.characters = original.characters.duplicate()
	registry.characters.append(character)
	registry.enemy_definitions = original.enemy_definitions.duplicate()
	registry.enemy_definitions.append(enemy)
	registry.stage_scenes = original.stage_scenes.duplicate()
	registry.stage_scenes.append(packed)
	return _save(registry,"index.tres")

func _spawn_main(label: String) -> Node:
	OS.set_environment("LEBA_TEST_PROFILE","user://act03_editing/"+directory.get_file()+"_"+label+"/profile.json")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(550,400)
	viewport.disable_3d = true
	root.add_child(viewport)
	var app: Node = MainScene.instantiate()
	app.content_registry = loaded_index
	app.start_stage_override = STAGE_ID
	app.start_character_override = CHARACTER_ID
	viewport.add_child(app)
	app.set_process(false)
	applications.append(app)
	viewports.append(viewport)
	_check(label+" actual Main consumes fresh copied index and stage",app.startup_ok and app.database.stages.has(STAGE_ID) and app.database.characters.has(CHARACTER_ID) and app.session.run.stage_id == STAGE_ID and app.session.run.character_id == CHARACTER_ID,app.database.issues)
	if not is_instance_valid(app.battle):return app
	app.battle.manual_clock = true
	app.battle.set_physics_process(false)
	app.battle.player.action_event.connect(_on_event.bind(app,label))
	return app

func _on_event(actor: Node2D, event: Dictionary, app: Node, label: String) -> void:
	var record := {"app":label,"tick":app.session.run.source_ticks,"action":actor.state,"frame":actor.source_frame,"kind":str(event.kind),"position":[actor.position.x,actor.position.y],"enemy_hp":app.battle.enemies.map(func(e:Node2D)->float:return e.hp)}
	if event.has("damage"):record.damage = event.damage
	if event.has("local_rects"):
		record.rectangles = event.local_rects.map(func(r:Rect2)->Array:return [r.position.x,r.position.y,r.size.x,r.size.y])
	if str(event.kind) == "sound":record.explicit_stream_playing = _explicit_audio_playing(app)
	event_records.append(record)

func _explicit_audio_playing(app: Node) -> bool:
	for voice: AudioStreamPlayer in app.audio._voices:
		if voice.playing and voice.stream != null and voice.stream.resource_path == directory.path_join("editor_silence.tres"):return true
	return false

func _tick(app: Node, key: Key = KEY_NONE) -> void:
	if key != KEY_NONE:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = true
		app.get_viewport().push_input(event,true)
	var commands: Dictionary = app.battle.take_commands()
	app.battle.advance_real_time(0.04)
	app.battle.step(commands)
	app._process(0.04)
	if key != KEY_NONE:
		var released := InputEventKey.new()
		released.keycode = key
		released.physical_keycode = key
		released.pressed = false
		app.get_viewport().push_input(released,true)

func _layout_checks(app: Node) -> void:
	var battle: Node2D = app.battle
	_check("saved PlayerSpawn drives actual actor position and scale",battle.player.position.is_equal_approx(PLAYER_AT) and battle.player.visual_scale.is_equal_approx(Vector2.ONE),battle.player.position)
	_check("saved HUDLayout is same live author instance with edited transform",app.ui.source_hud == battle.authored_hud and app.ui.source_hud.position.is_equal_approx(HUD_AT) and app.ui.source_hud.get_node("Characters/CRT0/HPLayout").position.is_equal_approx(HP_LAYOUT_AT))
	var map: Sprite2D = battle.authored_stage.get_node("Map")
	_check("saved Map texture reference and position survive Main load",map.texture.resource_path == directory.path_join("editor_map.tres") and map.texture.get_size() == Vector2(17,11) and map.position == MAP_AT,{"texture":map.texture.resource_path,"position":map.position})
	_check("saved floor shape feeds actual ground rectangle",battle.stage.ground_rect == [0.0,330.0,300.0,20.0] and is_equal_approx(battle.stage.floor_y,330.0),battle.stage.ground_rect)
	_check("copied new action ID registered with distinct saved resource",battle.player.definition.actions.has(COPY_ACTION) and battle.player.definition.actions[COPY_ACTION].input == COPY_INPUT)
	_tick(app)
	_tick(app)
	_check("saved floor collision affects only intersecting target",is_equal_approx(battle.enemies[0].position.y,330.0) and is_equal_approx(battle.enemies[1].position.y,340.0),[battle.enemies[0].position.y,battle.enemies[1].position.y])

func _exercise(a: Node, b: Node) -> void:
	var player: Node2D = a.battle.player
	var initial_mp := float(player.mp)
	_tick(a,KEY_S)
	_check("normal S input enters edited saved action",player.state == "skill_s")
	_check("edited S cost and cooldown affect live actor",is_equal_approx(player.mp,initial_mp-7.25+0.05) and int(player.cooldowns.get("skill_s",0)) == 19,{"mp":player.mp,"cooldown":player.cooldowns.get("skill_s")})
	_check("shared character resource does not share cooldown or MP across actors",a.content_registry == b.content_registry and int(b.battle.player.cooldowns.get("skill_s",0)) == 0 and is_equal_approx(b.battle.player.mp,100.0))
	_check("edited sound does not fire before source3",not _explicit_audio_playing(a))
	_tick(a)
	_check("source2 still precedes edited event and hit window",not _explicit_audio_playing(a) and a.battle.enemies[0].hp == 400.0 and player.position == PLAYER_AT)
	_tick(a)
	_check("source3 plays explicit saved AudioStream through real pool",player.source_frame == 3 and _explicit_audio_playing(a),a.audio.snapshot())
	_tick(a)
	_check("source4 executes edited root-motion event",player.source_frame == 4 and is_equal_approx(player.position.x,PLAYER_AT.x+11.25),player.position)
	_tick(a)
	var first_hits := event_records.filter(func(x:Dictionary)->bool:return x.app == "A" and x.action == "skill_s" and x.kind == "authored_hit" and x.frame == 6)
	_check("source6 edited HitWindow hits near target for authored23.5",first_hits.size() == 1 and is_equal_approx(first_hits[0].enemy_hp[0],376.5) and first_hits[0].enemy_hp[1] == 400.0 and first_hits[0].rectangles == [[35.0,-100.0,105.0,160.0]],first_hits)
	for i in range(4):_tick(a)
	var damage_rows: Array = a.battle.journal.filter(func(x:Dictionary)->bool:return x.event == "damage" and str(x.get("source","")) == "author window skill_s")
	_check("two-frame window claims each target once and excludes far target",damage_rows.size() == 1 and is_equal_approx(damage_rows[0].amount,23.5) and a.battle.enemies[1].hp == 400.0,damage_rows)
	_check("edited S ends through ordinary action transition",player.state == "idle",player.state)
	var serial := int(player.action_serial)
	_tick(a,KEY_S)
	_check("normal S rejected while edited cooldown remains",player.action_serial == serial and int(player.cooldowns.get("skill_s",0)) > 0)
	for i in range(25):
		if int(player.cooldowns.get("skill_s",0)) == 0:break
		_tick(a)
	_tick(a,KEY_S)
	_check("normal S becomes usable after edited cooldown expires",player.state == "skill_s" and int(player.cooldowns.get("skill_s",0)) == 19)
	# Explicit state-isolation fixture uses Actor's real health method, separate
	# from collision verification above. It is not an original enemy-damage claim.
	player.receive_damage(6.25,false)
	a._process(0.04)
	_check("shared definition never shares HP or mutates maxHP",is_equal_approx(player.hp,93.75) and is_equal_approx(b.battle.player.hp,100.0) and is_equal_approx(player.definition.max_hp,100.0) and is_equal_approx(b.battle.player.definition.max_hp,100.0))
	_check("HUD state update changes fill only and retains saved layout",is_equal_approx(a.ui.source_hud.hp_fill.scale.x,0.9375) and a.ui.source_hud.get_node("Characters/CRT0/HPLayout").position == HP_LAYOUT_AT and a.ui.source_hud.position == HUD_AT)
	_tick(b,KEY_K)
	_check("new action input_id dispatches physical K through real InputMap",b.battle.player.state == COPY_ACTION,b.battle.player.state)
	_check("new copied action has independent edited cost and cooldown",is_equal_approx(b.battle.player.mp,98.05) and int(b.battle.player.cooldowns.get(COPY_ACTION,0)) == 13,{"mp":b.battle.player.mp,"cooldowns":b.battle.player.cooldowns})
	for i in range(4):_tick(b)
	var k_sound := event_records.filter(func(x:Dictionary)->bool:return x.app == "B" and x.action == COPY_ACTION and x.kind == "sound")
	_check("copied action source4 event plays saved stream by registered newID",k_sound.size() == 1 and k_sound[0].frame == 4 and k_sound[0].explicit_stream_playing,k_sound)
	var k_hits := event_records.filter(func(x:Dictionary)->bool:return x.app == "B" and x.action == COPY_ACTION and x.kind == "authored_hit" and x.frame == 6)
	_check("copied action distinct damage is consumed by same combat runtime",k_hits.size() == 1 and is_equal_approx(k_hits[0].enemy_hp[0],390.75) and k_hits[0].enemy_hp[1] == 400.0,k_hits)

func _run() -> void:
	if "--test-mode" not in OS.get_cmdline_user_args():
		push_error("--test-mode required; no production profile allowed")
		quit(2)
		return
	var supplied_directory := OS.get_environment("LEBA_TEST_ARTIFACT_DIR").strip_edges()
	if supplied_directory.is_empty():
		directory = "res://artifacts/leba_act03_20261116/editing/run_%d_%d"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	else:
		directory = ProjectSettings.localize_path(supplied_directory.simplify_path()).trim_suffix("/")
		if not directory.begins_with("res://artifacts/"):
			push_error("LEBA_TEST_ARTIFACT_DIR必须是工程artifacts内的res://或绝对路径；拒绝覆盖作者目录。")
			quit(2)
			return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	previous_test_profile = OS.get_environment("LEBA_TEST_PROFILE")
	formal_exists = FileAccess.file_exists("user://profile.json")
	if formal_exists:formal_hash = FileAccess.get_sha256("user://profile.json")
	_hash_tree("res://content",author_hashes)
	_hash_tree("res://scenes",author_hashes)
	_sync_generated_check()
	custom_input_existed = InputMap.has_action(COPY_INPUT)
	if custom_input_existed:custom_input_events = InputMap.action_get_events(COPY_INPUT)
	else:InputMap.add_action(COPY_INPUT)
	InputMap.action_erase_events(COPY_INPUT)
	var k := InputEventKey.new()
	k.physical_keycode = KEY_K
	InputMap.action_add_event(COPY_INPUT,k)
	loaded_index = _build_fixture()
	_check("fresh load yields isolated registry resource",loaded_index != null and loaded_index.resource_path == directory.path_join("index.tres"))
	# The runner streams stdout/stderr inside this same output directory. Protect
	# every actual ResourceSaver output, not unrelated live diagnostic files.
	# Snapshot after synchronization so its intentional fixture update is complete.
	for path: String in saved_fixture_resources:fixture_hashes[path] = FileAccess.get_sha256(path)
	if loaded_index != null:
		var a := _spawn_main("A")
		var b := _spawn_main("B")
		if a.startup_ok and b.startup_ok and is_instance_valid(a.battle) and is_instance_valid(b.battle):
			_layout_checks(a)
			_layout_checks(b)
			_exercise(a,b)
	for app: Node in applications:
		app._dispose_battle()
		if is_instance_valid(app.audio):await app.audio.stop_and_drain(1.0)
	for viewport: SubViewport in viewports:viewport.queue_free()
	await process_frame
	_check("original content and scenes bytes remain unchanged",_unchanged(author_hashes),author_hashes.size())
	_check("runtime never writes state into copied author files",_unchanged(fixture_hashes),fixture_hashes.size())
	_check("formal profile existence and bytes remain unchanged",FileAccess.file_exists("user://profile.json") == formal_exists and (not formal_exists or FileAccess.get_sha256("user://profile.json") == formal_hash))
	OS.set_environment("LEBA_TEST_PROFILE",previous_test_profile)
	if custom_input_existed:
		InputMap.action_erase_events(COPY_INPUT)
		for event: InputEvent in custom_input_events:InputMap.action_add_event(COPY_INPUT,event)
	else:InputMap.erase_action(COPY_INPUT)
	_finish()

func _finish() -> void:
	var failures := checks.filter(func(x:Dictionary)->bool:return not x.passed).size()
	var report := {"suite":"ACT03 saved-author-editing","directory":directory,"godot":Engine.get_version_info(),"checks":checks,"events":event_records,"failures":failures,"original_author_hashes":author_hashes,"fixture_hashes":fixture_hashes,"saved_fixture_resources":saved_fixture_resources,"evidence":"Actual ResourceSaver/IGNORE_DEEP reload; Main.content_registry; SubViewport key down/up -> InputMap S/K -> Battle -> Actor/AudioDirector; headless Dummy","limitations":["Values, silent audio, target AI and terrain are explicit engineering fixtures, not original rules","HP isolation additionally uses Actor.receive_damage directly; collision assertions use real authored windows","No OS keyboard, audible listening or manual editor drag is claimed"]}
	var file := FileAccess.open(directory.path_join("report.json"),FileAccess.WRITE)
	if file != null:file.store_string(JSON.stringify(report,"\t"));file.close()
	print("ACT03_EDITING checks=%d failures=%d report=%s"%[checks.size(),failures,directory.path_join("report.json")])
	quit(0 if failures == 0 else 1)
