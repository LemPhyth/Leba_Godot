extends Node2D
## One encounter owns all combatants/projectiles; no actor survives scene exit.
signal finished(outcome: String)
signal feedback(message: String)
signal persistence_requested
const Actor = preload("res://scripts/combat/combatant.gd")
const Visual = preload("res://scripts/combat/source_sprite.gd")
const Clock = preload("res://scripts/core/source_clock.gd")
const Progression = preload("res://scripts/core/progression.gd")
const EXTRA_INPUTS = ["skill_a","skill_w","load_f","load_g","load_h","skill_q","skill_t","skill_e","skill_r","skill_y","skill_v","aim_up"]
var database: RefCounted
var session: RefCounted
var audio: Node
var stage: Dictionary
var player: Node2D
var enemies: Array[Node2D] = []
var projectiles: Array[Dictionary] = []
var clock := Clock.new()
var journal: Array[Dictionary] = []
var paused := false
var ended := false
var debug_draw := false
var manual_clock := false
var _presses: Dictionary = {}
var _key_events: Array[Dictionary] = []
var _background: Texture2D
var _background_data: Dictionary = {}
var _active_boxes: Array[Rect2] = []
var _markers: Dictionary = {}
var _enemy_timers: Dictionary = {}
var _held: Dictionary = {}
var real_time_ms := 0.0
var _z_interval_active := false
var _z_interval_id := 0
var _z_interval_next := 0.0
var _z_timeouts: Array[Dictionary] = []
var _z_direction := 1
var _last_air_parent := 0
var trace_enabled := false
var trace_frames: Array[Dictionary] = []
var trace_events: Array[Dictionary] = []
var skill_bar_frame := 1
var bar_initialization_pending := false
var _bar_new_tick := -1
var _y_slot_frame := 1
var _y_slot_playing := true
var grenades := {"f":{"stock":0,"icon_frame":1,"active":false},"g":{"stock":0,"icon_frame":1,"active":false},"h":{"stock":0,"icon_frame":1,"active":false}}
var _grenade_loads: Array[Dictionary] = []
var ammo_frames := {"fire":1,"silver":1}
var c4_count := 0
var c4_targets: Dictionary = {}
var combo := 0
var combo_frame := 1
var _q_choice_age := 0
var summons: Array[Dictionary] = []
var _next_root_depth := 1000
var _c4_views: Dictionary = {}
var enemy_status: Dictionary = {}
var _thaw_ticks: Dictionary = {}
var zab := ""
var pren := 0
var _v_trace: Dictionary = {}
var _y_summon: Dictionary = {}
var source_feedback: Dictionary = {}
var _callback_order := 0
var _transient_contacts: Array[Dictionary] = []
var sniper := {"root":1,"born":-1,"reticle":1,"reticle_born":-1,"local":Vector2(24,46.1),"ammo":1,"timer":0,"casings":[],"views":{},"glass_helper":Vector2(277,210)}
var authored_stage: Node2D
var authored_hud: Node2D
var crt1 := {"buff_frame":1,"w_ammo_frame":1,"w_shot_frame":1,"w_move_frame":1,"h_count":0,"t_slot_frame":1,"t_slot_playing":true,"t_hold":0,"t_timer":0,"t_kill":false}
var _crt1_views: Dictionary = {}
var _gunhawks: Array[Dictionary] = []
var _crt1_shots: Dictionary = {}
var _crt1_view_frames: Dictionary = {}
var _nested_audio: Dictionary = {}
var crt2 := {"frenzy_frame":1,"rage_frame":1,"lust_frame":1,"appearance_pren":0,"r_slot_frame":1,"r_slot_playing":true,"air_frame":1,"r_air_frame":1,"urlr":0}
var _crt2_objects: Array[Dictionary] = []
var _crt2_views: Dictionary = {}
var _crt2_bleeds: Dictionary = {}
var _crt2_feedback_bodies: Dictionary = {}
var crt3 := {"rigui":0,"pyeongta":0,"d_count":0,"q_count":0,"h_frame":1,"over":0,"e_slot_frame":1,"e_slot_playing":true,"air_frame":1,"back_frame":1,"w_cut":0,"w_key":0,"e_active":false,"e_w_frame":1,"e_start_frame":1,"e_circle_frame":1}
var _crt3_views: Dictionary = {}
var _crt3_clocks: Dictionary = {}
var _crt3_contacts: Dictionary = {}
var _crt3_objects: Array[Dictionary] = []
var _source_dynamic_layer: CanvasLayer
var crt4 := {"ghost_frame":1,"ghost_step":0,"kalla_frame":1,"kalla":0,"ghost_type":0,"y_slot_frame":1,"y_slot_playing":true,"air_frame":1,"back_frame":1,"a_charge":1,"fields":{},"kaz":0,"bremen":0,"saya":0,"rhasa":0}
var _crt4_objects: Array[Dictionary] = []
var _crt4_views: Dictionary = {}
var _crt4_contacts: Dictionary = {}
var _crt4_serial := 0
var _crt4_audio_frames: Dictionary = {}
var _crt4_bleeds: Dictionary = {}
var _crt4_fly := {"active":false,"id":0,"next":0.0,"faces":[],"timeouts":[]}

func _source_dynamic_parent() -> Node:
	# Flash positive attachMovie depths sort above root static display-list tags
	# (whose AVM1 depths are SWF-depth minus16384). Preserve that boundary without
	# renumbering static author layouts. Engineering menus remain on layer10.
	if not is_instance_valid(_source_dynamic_layer):
		_source_dynamic_layer=CanvasLayer.new()
		_source_dynamic_layer.name="SourceDynamicRoot"
		_source_dynamic_layer.layer=1
		add_child(_source_dynamic_layer)
	return _source_dynamic_layer

func setup(db: RefCounted, state: RefCounted, sound: Node, stage_id: String) -> void:
	database = db
	session = state
	Progression.new().normalize(session.profile)
	audio = sound
	stage = db.stages[stage_id].duplicate(true)
	if db.stage_scenes.has(stage_id):
		authored_stage = db.stage_scenes[stage_id].instantiate()
		add_child(authored_stage)
		stage = authored_stage.to_runtime()
		authored_hud = authored_stage.get_node_or_null("HUD")
		if authored_hud != null:authored_stage.remove_child(authored_hud)
	# Default stages retain3829 with pren0: clamp root coordinates0..550.
	if not bool(stage.get("authored_layout",false)):stage.bounds = [0.0,550.0]
	session.begin_stage(stage_id, int(stage.enemy_count))
	if is_training():session.run.mode_id = "training"
	_background_data = db.assets.textures.get(str(stage.get("background","forest")), {})
	if not _background_data.is_empty():
		_background = load(str(_background_data.path)) as Texture2D
	var character: Dictionary = db.characters[session.run.character_id].duplicate(true)
	if is_training():
		character.max_hp = float(stage.player_max_hp)
		character.max_mp = float(stage.player_max_mp)
	character.max_hp += Progression.new().max_hp_bonus(session.profile,str(session.run.character_id))
	player = _make_actor("player", "player", character, _vec(stage.player_position), _vec(stage.player_scale))
	player.z_index = int(stage.get("player_depth",1000))
	if stage.has("ground_texture") and authored_stage == null:
		var ground: Dictionary = db.assets.textures[stage.ground_texture]
		var ground_sprite := Sprite2D.new()
		ground_sprite.name = "SourceGround"
		ground_sprite.texture = load(str(ground.path))
		ground_sprite.centered = false
		ground_sprite.position = _vec(ground.stage_position)-_vec(ground.pivot)
		ground_sprite.z_index = int(stage.source_depths.ground)
		add_child(ground_sprite)
	for index in range(stage.enemy_positions.size()):
		var enemy_data: Dictionary = db.enemy_definition(str(stage.get("enemy_type","goblin_4030")))
		# Source6968 frame1 applies this once on stage entry, to hp AND hpm.
		if is_training():enemy_data.max_hp = float(stage.enemy_hp)
		else:enemy_data.max_hp = float(stage.get("enemy_hp",enemy_data.max_hp))*float(db.difficulties[session.run.difficulty_id].get("enemy_hp_multiplier",1.0))
		var size: Array = stage.enemy_scales[index] if stage.has("enemy_scales") else stage.enemy_scale
		var enemy: Node2D = _make_actor("enemy_%d" % index,"enemy",enemy_data,_vec(stage.enemy_positions[index]),_vec(size))
		enemy.ground_y = float(stage.floor_y)
		if not is_training():enemy.position.y = enemy.ground_y
		enemy.z_index = int(stage.get("enemy_depths",[100])[index]) if stage.has("enemy_depths") else 100
		enemy.set_facing(-1 if enemy.position.x > player.position.x else 1)
		enemies.append(enemy)
	bar_initialization_pending = true
	if int(player.definition.source_crt) == 0:_y_initialize()
	_bar_new_tick = 0
	audio.play_music(str(stage.music))
	_record("enter", {"stage":stage_id,"enemies":enemies.size()})

func is_training() -> bool:
	return bool(stage.get("training",false))

func restore_training() -> bool:
	if not is_training() or ended:return false
	# Original8495 only assigns200 and sends4391 to its empty frame7.
	player.hp = 200.0
	player.mp = 200.0
	skill_bar_frame = 7
	bar_initialization_pending = true
	_bar_new_tick = int(session.run.source_ticks)
	_record("training_restore",{"hp":player.hp,"mp":player.mp,"bar":7})
	return true

func _advance_skill_bar() -> void:
	if int(player.definition.source_crt) == 4:
		if skill_bar_frame == 7:
			skill_bar_frame=1;player.cooldowns.clear();crt4.y_slot_frame=1;crt4.y_slot_playing=true
			_bar_new_tick=int(session.run.source_ticks)
		else:
			if crt4.y_slot_playing:crt4.y_slot_frame=mini(291,int(crt4.y_slot_frame)+1)
			if bar_initialization_pending and int(session.run.source_ticks)>_bar_new_tick and player.parent_frame==146:
				player.cooldowns.clear();crt4.y_slot_frame=2;crt4.y_slot_playing=true;bar_initialization_pending=false
		player.cooldowns["skill_y"]=291-int(crt4.y_slot_frame)
		return
	if int(player.definition.source_crt) == 3:
		if skill_bar_frame == 7:
			skill_bar_frame=1;player.cooldowns.clear();crt3.e_slot_frame=1;crt3.e_slot_playing=true
			_bar_new_tick=int(session.run.source_ticks)
		else:
			if crt3.e_slot_playing:crt3.e_slot_frame=mini(442,int(crt3.e_slot_frame)+1)
			if bar_initialization_pending and int(session.run.source_ticks)>_bar_new_tick and player.parent_frame in [101,102,103]:
				player.cooldowns.clear();crt3.e_slot_frame=2;crt3.e_slot_playing=true;bar_initialization_pending=false
		player.cooldowns["skill_e"]=442-int(crt3.e_slot_frame)
		return
	if int(player.definition.source_crt) == 2:
		if skill_bar_frame == 7:
			skill_bar_frame = 1;player.cooldowns.clear()
			crt2.r_slot_frame = 1;crt2.r_slot_playing = true
			_bar_new_tick = int(session.run.source_ticks)
		else:
			if crt2.r_slot_playing:crt2.r_slot_frame = mini(430,int(crt2.r_slot_frame)+1)
			if bar_initialization_pending and int(session.run.source_ticks) > _bar_new_tick and player.parent_frame in [64,65,66,67]:
				player.cooldowns.clear();crt2.r_slot_frame = 2;crt2.r_slot_playing = true;bar_initialization_pending = false
		player.cooldowns["skill_r"] = 430-int(crt2.r_slot_frame)
		return
	if int(player.definition.source_crt) == 1:
		if skill_bar_frame == 7:
			skill_bar_frame = 1
			player.cooldowns.clear()
			crt1.t_slot_frame = 1
			crt1.t_slot_playing = true
			_bar_new_tick = int(session.run.source_ticks)
		else:
			if crt1.t_slot_playing:crt1.t_slot_frame = mini(405,int(crt1.t_slot_frame)+1)
			if bar_initialization_pending and int(session.run.source_ticks) > _bar_new_tick and player.parent_frame in [30,31,32,33]:
				player.cooldowns.clear()
				crt1.t_slot_frame = 2
				crt1.t_slot_playing = true
				bar_initialization_pending = false
		player.cooldowns["skill_t"] = 405-int(crt1.t_slot_frame)
		return
	if skill_bar_frame == 7:
		skill_bar_frame = 1
		player.cooldowns.clear()
		_y_slot_frame = 1
		_y_slot_playing = true
		_bar_new_tick = int(session.run.source_ticks)
		_record("skill_bar_rebuilt",{})
	else:
		if _y_slot_playing:_y_slot_frame = mini(533,_y_slot_frame+1)
		if bar_initialization_pending and int(session.run.source_ticks) > _bar_new_tick and player.parent_frame in [1,2,3,30,31,32,64,65,66,101,102,103,146,178]:
			# Rebuilt Y advances independently even while4112 waits for a base state.
			player.cooldowns.clear()
			_y_slot_frame = 2
			_y_slot_playing = true
			bar_initialization_pending = false
			_record("skill_bar_initialized",{"y_frame":2})
	player.cooldowns["skill_y"] = 533-_y_slot_frame

func _make_actor(id: String, team: String, definition: Dictionary, at: Vector2, size: Vector2) -> Node2D:
	var actor: Node2D
	var packed: PackedScene = definition.get("actor_scene",database.actor_scene if team == "player" else database.enemy_scene)
	var path := "PlayerSpawn/Actor" if team == "player" else "EnemySpawns/Enemy%s/Actor" % id.trim_prefix("enemy_")
	if authored_stage != null:actor = authored_stage.get_node_or_null(path)
	if actor != null and packed != null and actor.scene_file_path != packed.resource_path:
		actor.get_parent().remove_child(actor)
		actor.queue_free()
		actor = null
	if actor != null:actor.get_parent().remove_child(actor)
	else:actor = packed.instantiate() if packed != null else Actor.new()
	actor.name = id
	add_child(actor)
	actor.configure(id,team,definition,database.assets)
	actor.position = at
	actor.visual_scale = size
	actor.set_facing(1)
	actor.action_event.connect(_on_action_event)
	return actor

func _unhandled_input(event: InputEvent) -> void:
	if paused or ended:
		return
	if event.is_action("pause") or event.is_action("debug_overlay"):
		return
	# AS2 onClipEvent(keyDown) tests Key.isDown(88), not the event's key code.
	# A new/repeated key event while X is held is meaningful; held X alone is not.
	if event is InputEventKey and event.pressed:
		var attack := event.is_action_pressed("attack",true) or Input.is_action_pressed("attack")
		var entry := {"attack":attack,"skill":event.is_action_pressed("skill",true) or Input.is_action_pressed("skill"),"skill_s":event.is_action_pressed("skill_s",true) or Input.is_action_pressed("skill_s")}
		for key: String in ["jump","down","skill_z"]+EXTRA_INPUTS:
			entry[key] = event.is_action_pressed(key,true) or Input.is_action_pressed(key)
		entry["right"] = event.is_action_pressed("move_right",true) or Input.is_action_pressed("move_right")
		entry["left"] = event.is_action_pressed("move_left",true) or Input.is_action_pressed("move_left")
		for key: String in _authored_input_ids():entry[key] = event.is_action_pressed(key,true) or Input.is_action_pressed(key)
		entry["keycode"] = event.keycode if event.keycode != 0 else event.physical_keycode
		if entry.values().any(func(v:Variant)->bool:return v is bool and v):
			_key_events.append(entry)
			get_viewport().set_input_as_handled()
		return
	for action: String in ["attack", "skill", "skill_s", "jump", "down", "skill_z"]+EXTRA_INPUTS+_authored_input_ids():
		if event.is_action_pressed(action) and not event.is_echo():
			_presses[action] = true
			get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if paused or manual_clock:
		return
	if not is_finite(delta) or delta <= 0:
		return
	# Interleave 25Hz source boundaries and millisecond jobs; do not round10ms
	# to a source frame, or batch all source ticks at the same wall-clock time.
	var remaining := delta
	while remaining > 0.000000001:
		var slice := minf(remaining,Clock.STEP-clock.accumulator)
		advance_real_time(slice)
		var count := clock.consume(slice)
		remaining -= slice
		if count > 0:
			step(take_commands())

func take_commands() -> Dictionary:
	var commands := {"axis":Input.get_axis("move_left","move_right"),"attack":_presses.has("attack"),"skill":_presses.has("skill"),"skill_s":_presses.has("skill_s")}
	commands["key_events"] = _key_events.duplicate(true)
	commands["left"] = Input.is_action_pressed("move_left")
	commands["right"] = Input.is_action_pressed("move_right")
	commands["held_attack"] = Input.is_action_pressed("attack")
	for key: String in ["jump","down","skill_z"]+EXTRA_INPUTS:
		commands[key] = _presses.has(key)
	commands["held_e"] = Input.is_action_pressed("skill_e")
	commands["held_q"] = Input.is_action_pressed("skill_q")
	commands["held_d"] = Input.is_action_pressed("skill")
	commands["held_f"] = Input.is_action_pressed("load_f")
	commands["held_g"] = Input.is_action_pressed("load_g")
	commands["held_w"] = Input.is_action_pressed("skill_w")
	commands["held_s"] = Input.is_action_pressed("skill_s")
	commands["held_a"] = Input.is_action_pressed("skill_a")
	commands["held_z"] = Input.is_action_pressed("skill_z")
	commands["up"] = Input.is_action_pressed("aim_up")
	commands["held_down"] = Input.is_action_pressed("down")
	for key: String in _authored_input_ids():commands[key] = _presses.has(key)
	_key_events.clear()
	_presses.clear()
	return commands

func step(commands: Dictionary = {}) -> void:
	if paused or not is_instance_valid(player):
		return
	if ended:
		# Both normal25Hz updates and F6 use the same post-result death tail.
		if player.state == "dead":player.advance_tick()
		for enemy: Node2D in enemies:
			if enemy.state == "dead":enemy.advance_tick()
		return
	session.run.source_ticks += 1
	for action: String in player.cooldowns:
		if action != "skill_y" and not (int(player.definition.source_crt) == 1 and action == "skill_t") and not (int(player.definition.source_crt) == 2 and action == "skill_r") and not (int(player.definition.source_crt) == 3 and action == "skill_e"):player.cooldowns[action] = maxi(0,int(player.cooldowns[action])-1)
	_y_phase_controls()
	_advance_skill_bar()
	_advance_grenades_and_ammo()
	if combo_frame > 1:
		combo_frame += 1
		if combo_frame >= 83:combo_frame = 1;combo = 0
	_active_boxes.clear()
	_held = commands.duplicate(true)
	for enemy: Node2D in enemies:
		#3829 constrains the previous position before this source tick's drift.
		enemy.position.x = clampf(enemy.position.x,-100.0 if pren == 2 else 0.0,650.0 if pren == 2 else 550.0)
	_advance_enemy_status()
	_advance_markers()
	_player_input(commands)
	_y_follow_enter_frame()
	var d_push: bool = int(player.definition.source_crt) == 0 and player.state == "skill" and player.source_frame >= 8 and player.source_frame <= 18
	var already_airborne: Dictionary = {}
	for enemy: Node2D in enemies:
		already_airborne[enemy.identifier] = enemy.airborne
		_enemy_input(enemy)
	var previous_action: String = player.state
	if int(player.definition.source_crt) == 2:
		_crt2_feedback_bodies.clear()
		for target: Node2D in enemies:_crt2_feedback_bodies[target.identifier] = target.hurt_rect() if not target.airborne else Rect2()
	if int(player.definition.source_crt) == 2 and player.state in ["skill_s_start","hurt_z"] and player.source_frame <= 5 and not bool(_held.get("held_s",false)):
		player.set_action("skill_s_release")
	player.advance_tick()
	_advance_player_components()
	if int(player.definition.source_crt) == 2:_crt2_sword_feedback()
	_advance_nested_audio()
	if int(player.definition.source_crt) == 1:_advance_crt1_components(previous_action)
	if int(player.definition.source_crt) == 2:_advance_crt2_components(previous_action)
	if int(player.definition.source_crt) == 3:_advance_crt3_components(previous_action)
	if int(player.definition.source_crt) == 4:_advance_crt4_components(previous_action)
	_advance_v()
	_advance_sniper()
	_advance_source_feedback()
	_advance_summons()
	_y_advance_after_actor()
	for request: Dictionary in _y_take_projectile_requests():_spawn_projectile(player,{"host":request.host,"host_depth_key":request.replace_key,"projectile":"projectile"})
	_advance_c4()
	if previous_action not in ["idle","move"] and player.state == "idle":
		_ground_input(commands)
		player.consume_entry_frame()
	_advance_air_action()
	if player.state == "hit":
		# Only the hurt-state body carries the separate width/2 clamp.
		var half_width: float = player.hurt_rect().size.x/2.0 if int(player.definition.source_crt) in [3,4] else float(database.assets.source_geometry.crt0_body.rect[2])/2.0
		player.position.x = clampf(player.position.x,half_width,550.0-half_width)
		player.position.y = clampf(player.position.y,half_width,400.0-half_width)
	# The difficulty-display child polls before late enemy contacts. Only its
	# frame1 (Expert) retains the listener; Master/King replace that child.
	if player.state == "hit" and player.source_frame == 2 and session.run.difficulty_id == "expert" and bool(stage.get("difficulty_observer",true)):
		deal_damage(player,player,1.0,"6968 Expert child observer: hurt source2",false)
	_advance_projectiles()
	_resolve_transient_contacts()
	for enemy: Node2D in enemies:
		# Source ground listener runs before this tick's air integration. A
		# downward overshoot stays visible until the following source tick.
		if enemy.airborne and enemy.vertical_speed >= 0.0 and _touches_ground(enemy):
			enemy.position.y = enemy.ground_y
			enemy.airborne = false
			enemy.vertical_speed = 1e-9
			enemy.gravity_acceleration = 0.0
			enemy.set_action("dead" if enemy.pending_death else "idle")
			enemy.pending_death = false
			if is_training() and enemy.hp > 0:_training_movement(enemy)
		if not enemy.airborne and _touches_ground(enemy):
			enemy.position.y = enemy.ground_y
			enemy.vertical_speed = 1e-9
		if enemy.airborne:
			var away := signf(enemy.position.x-player.position.x)
			_source_shift_x(enemy,away*(16.8 if d_push and already_airborne[enemy.identifier] else 0.8))
			enemy.position.y = Actor.twips(Actor.source_coordinate(enemy.position.y)+(enemy.vertical_speed+enemy.gravity_acceleration))
			if enemy.vertical_speed <= 30.0:
				enemy.vertical_speed += 1.0
		# The source replaces the entire ground clip when entering outer frame2.
		# Its attack windows and ground timeline cannot keep running in the air.
		if not enemy.airborne and not enemy.frozen and not enemy.source_death_locked:
			enemy.advance_tick()
		if enemy.state == "evade":
			var retreat := float(enemy.definition.actions.evade.get("retreat_per_tick",6.0))
			if player.position.x >= enemy.position.x:enemy.position.x -= retreat
			if player.position.x <= enemy.position.x:enemy.position.x += retreat
		enemy.update_air_visual(int(session.run.source_ticks))
	_finish_stopped_markers()
	_observe_player_hurt()
	_sniper_contacts()
	_observe_frozen()
	player.hp = minf(float(player.definition.max_hp),player.hp)
	player.mp = minf(float(player.definition.max_mp),player.mp + 0.05)
	if player.hp <= 0:
		_end("defeat")
	if is_instance_valid(_source_dynamic_layer):_source_dynamic_layer.transform=global_transform
	if trace_enabled:
		var frame := snapshot()
		frame["input"] = commands.duplicate(true)
		frame["enemies"] = enemies.map(func(e:Node2D)->Dictionary:return {"id":e.identifier,"parent":e.parent_frame,"child":e.source_frame,"hp":e.hp,"position":[e.position.x,e.position.y],"air":e.airborne,"g":e.vertical_speed,"gacc":e.gravity_acceleration})
		trace_frames.append(frame)
		if trace_frames.size() >= 5000:
			trace_enabled = false
			feedback.emit("诊断轨迹已达5000帧，已停止记录；可导出或重置")
	queue_redraw()

func _player_input(input: Dictionary) -> void:
	if player.hp <= 0:
		return
	var key_events: Array = input.get("key_events",[])
	if key_events.is_empty():
		_action_input(input)
	else:
		for key_event: Dictionary in key_events:
			_action_input(key_event)
	_ground_input(input)

func _ground_input(input: Dictionary) -> void:
	if int(player.definition.source_crt)==4:
		_crt4_ground(input)
		return
	if player.state not in ["idle","move"]:
		return
	var axis := signf(float(input.get("axis",0.0)))
	var right := bool(input.get("right",axis > 0))
	var left := bool(input.get("left",axis < 0))
	if right or left:
		if player.state != "move":
			player.set_action("move")
		player.parent_frame = int(player.definition.get("movement_parent_start",2 if int(player.definition.source_crt) == 0 else 31))
		# Two ordered source if-statements: both held => net0, facing left.
		if right:_move_player(float(player.definition.move_per_tick));player.set_facing(1)
		if left:_move_player(-float(player.definition.move_per_tick));player.set_facing(-1)
	elif player.state == "move":
		player.parent_frame += 1
		if player.parent_frame >= int(player.definition.get("movement_parent_end",4 if int(player.definition.source_crt) == 0 else 33)):
			player.set_action("idle")

func _action_input(input: Dictionary) -> void:
	if int(player.definition.source_crt) == 4:
		_crt4_input(input)
		return
	if int(player.definition.source_crt) == 3:
		_crt3_input(input)
		return
	if int(player.definition.source_crt) == 2:
		_crt2_input(input)
		return
	if int(player.definition.source_crt) == 1:
		var serial: int = player.action_serial
		if _crt1_component_input(input):return
		for key: String in ["load_h","load_g","load_f","skill_z","skill_a","skill_s","skill","skill_q","skill_t","skill_e","skill_r","skill_v","skill_w"]:
			if bool(input.get(key,false)):_try_skill(_crt1_input_action(key))
		_dispatch_custom_inputs(input)
		if player.action_serial == serial:_actor_key_input(input,serial)
		return
	_sniper_key_down(input)
	var focused := _y_try_focus_keydown(input)
	var serial: int = player.action_serial
	# Original4391 depth order, including shared Z/A and the separate HUD throws.
	for key: String in ["load_h","load_g","load_f","skill_z","skill_a","skill_s","skill","skill_q","skill_t","skill_e","skill_r","skill_y","skill_v","skill_w"]:
		if bool(input.get(key,false)) and not (focused and key == "skill_y"):_try_skill(_resolve_author_input(key,key))
	_dispatch_custom_inputs(input)
	if player.action_serial == serial:_actor_key_input(input,serial)
	# Root6917 inventory is not destroyed by replacing the actor's old clip.
	for kind: String in ["f","g","h"]:
		if bool(input.get("load_"+kind,false)):_try_throw(kind)

func _actor_key_input(input: Dictionary, serial: int) -> void:
	var crt0: bool = int(player.definition.source_crt) == 0
	if crt0 and player.state == "skill_q" and player.source_frame == 12:
		if bool(input.get("aim_up",false)):
			player.seek_action_frame(13,true)
			return #f13 replaces the f12 head instance and invalidates queued Down.
		if bool(input.get("down",false)):player.seek_action_frame(22,true)
		return
	if bool(input.get("attack",false)):
		var current: Dictionary = player.definition.actions[player.state]
		if player.state in ["idle","move"]:
			if _start_actor_action(_resolve_author_input("attack","basic")):_record("basic_started",{})
		elif current.has("combo_next") and player.source_frame >= int(current.combo_from) and player.source_frame <= int(current.get("combo_until",999)):
			if _start_actor_action(str(current.combo_next)):_record("combo_started",{"action":player.state})
	if player.action_serial != serial:return
	if crt0 and player.state == "move" and bool(input.get("skill_z",false)):
		player.set_action("move_z")
		_record("z_started",{"entry":"movement","mp":player.mp})
		return
	if bool(input.get("jump",false)) and player.definition.actions.has("jump") and player.state in ["idle","move"]:
		if _start_actor_action(_resolve_author_input("jump","jump")):_record("jump_started",{})
		return
	if bool(input.get("down",false)) and player.definition.actions.has("down") and player.state in ["idle","move","basic","basic2","basic3","basic4","basic5","basic6"]:
		if _start_actor_action(_resolve_author_input("down","down")):_record("down_started",{})

func _try_skill(key: String) -> bool:
	if key.is_empty():return false
	if int(player.definition.source_crt)==4:
		if key=="skill_t" and int(crt4.kalla)!=0:return false
		if key=="t_finish" and int(crt4.kalla_frame)!=12:return false
		if key=="skill_y" and (int(crt4.y_slot_frame)!=291 or not bool(crt4.y_slot_playing)):return false
	var is_crt0 := int(player.definition.source_crt) == 0
	if key == "skill_t" and int(sniper.root) != 1:return false
	if skill_bar_frame == 7:return false
	if is_crt0 and key.begins_with("load_") and int(grenades[key.trim_prefix("load_")].stock) > 0:return false
	if is_crt0 and key == "skill_e":
		if player.mp < 7.0:
			feedback.emit("MP 不足 · 需要 7 MP")
			return false
		if c4_count == 3:key = "detonate"
	if not player.definition.actions.has(key):
		feedback.emit("该角色此按键动作尚未接入")
		_record("skill_rejected",{"reason":"unimplemented","action":key})
		return false
	var action: Dictionary = player.definition.actions[key]
	var cooldown_key := str(action.get("cooldown_key","skill_z" if is_crt0 and key == "skill_a" else ("skill_e" if key == "detonate" else key)))
	var cooldown: int = int(player.cooldowns.get(cooldown_key,0))
	if cooldown > 0:
		feedback.emit("技能冷却中 · %.1f 秒" % (cooldown/25.0))
		_record("skill_rejected",{"reason":"cooldown","action":key})
	elif player.state not in action.get("allowed_states",["idle","move","basic"]):
		_record("skill_rejected",{"reason":"state","action":key})
	elif not is_crt0 and action.has("source_allowed_parent_frames") and not _source_has(action.source_allowed_parent_frames,player.parent_frame):
		_record("skill_rejected",{"reason":"parent_state","action":key})
	elif action.has("required_pren") and pren != int(action.required_pren):
		feedback.emit("当前持续状态不允许此技能")
		_record("skill_rejected",{"reason":"pren","action":key})
	elif player.hp < maxf(float(action.get("hp_cost",0)),float(action.get("required_hp",0))):
		feedback.emit("HP 不足 · 需要 %s HP" % str(action.get("hp_cost",0)))
		_record("skill_rejected",{"reason":"hp","action":key})
	elif player.mp < maxf(float(action.cost),float(action.get("required_mp",0))):
		feedback.emit("MP 不足 · 需要 %d MP" % int(action.cost))
		_record("skill_rejected",{"reason":"mp","action":key})
	elif int(session.profile.progress.get("clear_cubes",200)) < int(action.get("cubes",0)):
		feedback.emit("无色不足 · 需要 %d" % int(action.cubes))
		_record("skill_rejected",{"reason":"cubes","action":key})
	elif key == "skill_y" and bar_initialization_pending:
		_record("skill_rejected",{"reason":"initial_wait","action":key})
	else:
		player.mp -= float(action.cost)
		player.hp -= float(action.get("hp_cost",0))
		if int(action.get("cubes",0)) > 0:session.profile.progress.clear_cubes -= int(action.cubes)
		player.cooldowns[cooldown_key] = int(action.get("cooldown_ticks",125))
		player.set_action(key)
		if int(player.definition.source_crt) == 1:_crt1_action_started(key,action)
		elif int(player.definition.source_crt) == 2:_crt2_action_started(key)
		elif int(player.definition.source_crt) == 3:_crt3_action_started(key)
		elif int(player.definition.source_crt) == 4:_crt4_action_started(key)
		elif key == "skill_y":_y_freeze_slot_after_activation()
		_record("skill_started",{"mp":player.mp,"action":key})
		if key == "skill_z":_record("z_started",{"entry":"skill_bar","mp":player.mp})
		return true
	return false

func _basic_skill_state() -> bool:
	return player.parent_frame in [1,2,3,4,7,8,9,10,16]

func _try_throw(kind: String) -> bool:
	var item: Dictionary = grenades[kind]
	if int(player.definition.source_crt) != 0 or not _basic_skill_state() or int(item.stock) <= 0 or int(item.icon_frame) != 1:return false
	if not player.definition.actions.has("throw_"+kind):
		push_error("榴弹动作资源未接入："+kind)
		return false
	item.stock -= 1
	item.icon_frame = 2
	player.set_action("throw_"+kind)
	_record("grenade_thrown",{"grenade":kind,"stock":item.stock})
	return true

func _advance_grenades_and_ammo() -> void:
	for job: Dictionary in _grenade_loads.duplicate():
		if int(job.due) <= int(session.run.source_ticks):
			grenades[job.kind].stock = {"f":5,"g":4,"h":3}[job.kind]
			_grenade_loads.erase(job)
	for kind: String in grenades:
		var item: Dictionary = grenades[kind]
		if int(item.icon_frame) > 1:
			item.icon_frame += 1
			if int(item.icon_frame) > 81:item.icon_frame = 1
		if item.active and int(item.stock) == 0 and not _grenade_loads.any(func(j:Dictionary)->bool:return j.kind == kind):
			item.active = false
			player.cooldowns["load_"+kind] = {"f":216,"g":269,"h":323}[kind]
	for kind: String in ammo_frames:
		if int(ammo_frames[kind]) > 1:ammo_frames[kind] = 1 if int(ammo_frames[kind]) >= 355 else int(ammo_frames[kind])+1

func _advance_player_components() -> void:
	if int(player.definition.source_crt) == 0 and player.state == "skill_q" and player.source_frame == 12:
		_q_choice_age += 1
		if _q_choice_age >= 101:player.seek_action_frame(13)
	else:_q_choice_age = 0

func _move_player(dx: float) -> void:
	# Node2D stores float32, while AVM1 reads its integer-twips translation as
	# a double. Recover that source value before arithmetic, then truncate like
	# the original setter (129.35+9.95 becomes139.25, not float32's139.30).
	var source_x := Actor.source_coordinate(player.position.x)
	var next_x := Actor.twips(source_x+dx)
	player.position.x = next_x if pren == 2 else clampf(next_x,float(stage.bounds[0]),float(stage.bounds[1]))

func _source_shift_x(actor: Node2D, dx: float) -> void:
	actor.position.x = Actor.twips(Actor.source_coordinate(actor.position.x)+dx)

func _touches_ground(actor: Node2D) -> bool:
	if stage.has("ground_rect"):
		var r: Array = stage.ground_rect
		return _overlaps(Rect2(r[0],r[1],r[2],r[3]),actor.gravity_rect())
	return actor.position.y >= actor.ground_y

func _advance_air_action() -> void:
	if int(player.definition.source_crt) in [2,3,4]:return # Character-owned independent children.
	if int(player.definition.source_crt) == 1:
		_advance_crt1_air()
		return
	if player.state != "jump":
		_last_air_parent = 0
		return
	var frame: int = player.source_frame
	var right: bool = bool(_held.get("right",float(_held.get("axis",0)) > 0))
	var left: bool = bool(_held.get("left",float(_held.get("axis",0)) < 0))
	if frame == 15 or frame == 30:
		player.air_action_frame = 1
	elif frame > 15 and frame < 30 and player.air_action_frame in [2,3,4,5]:
		player.air_action_frame += 1
	if frame >= 5 and frame < 30 and (frame < 15 or player.air_action_frame == 1):
		if right:_move_player(4);player.set_facing(1)
		if left:_move_player(-4);player.set_facing(-1)
	if frame > 15 and frame < 30:
		var sub: int = player.air_action_frame
		if sub != 1:
			_move_player(-3.0*player.facing)
			if left:_move_player((-9.0 if player.facing == 1 else 3.0)*player.facing)
			if right:_move_player((3.0 if player.facing == 1 else -9.0)*player.facing)
		if sub in [2,3]:
			var overlay: Dictionary = database.assets.source_geometry.crt0_jump.air_overlay_by_frame[str(frame)]
			_spawn_projectile(player,{"projectile":"projectile_diagonal","gravity":-3.0,"parent_y":220.0+float(overlay.child_offset_px[1])})
		if bool(_held.get("held_attack",false)) and sub in [1,6]:
			player.air_action_frame = 2
			audio.play_sfx("crt0_air_shot")
	player.update_jump_visual()
	_last_air_parent = frame

func _enemy_input(enemy: Node2D) -> void:
	if enemy.hp <= 0 or enemy.frozen:
		return
	if int(_thaw_ticks.get(enemy.identifier,-1)) == int(session.run.source_ticks):return
	if not enemy.airborne and enemy_status.get(enemy.identifier,{}).has("stun"):return
	if enemy.definition.has("timer"):
		var timer: Dictionary = _enemy_timers.get(enemy.identifier,{"elapsed":0,"running":true})
		if timer.running:
			timer.elapsed += 1
			if enemy.definition.timer.has("cycle_ticks"):
				for trigger: Dictionary in enemy.definition.timer.events:
					if int(timer.elapsed) == int(trigger.tick) and not enemy.airborne:
						enemy.set_action(str(trigger.action))
						_record("enemy_timer_action",{"actor":enemy.identifier,"action":trigger.action})
				if int(timer.elapsed) >= int(enemy.definition.timer.cycle_ticks):timer.elapsed = 0
			elif int(timer.elapsed) >= int(enemy.definition.timer.trigger_tick):
				timer.running = false
				# Source7178 stops even if its goto111 targets the air body4029.
				if not enemy.airborne:
					enemy.set_action("evade")
					_record("enemy_evade",{"actor":enemy.identifier})
		_enemy_timers[enemy.identifier] = timer
	if enemy.airborne:
		enemy.set_facing(1 if player.position.x > enemy.position.x else -1)
		return
	if enemy.state not in ["idle","move","recover"]:
		return
	var distance: float = player.position.x - enemy.position.x
	if enemy.state == "idle" and absf(distance) > 1.0:
		enemy.set_facing(1 if distance > 0.0 else -1)
	if is_training():
		# Root41 lacks root2's proximity/attack trigger. Its movement requires
		# both original move-body overlap and distance strictly beyond100.
		_training_movement(enemy)
		return
	if enemy.definition.has("trigger_order"):
		for action_id: String in enemy.definition.trigger_order:
			var field: String = {"attack":"proximity","ranged":"ranged","melee":"melee"}[action_id]
			var key := field+("_moving_rect" if enemy.state == "move" else "_rect")
			var target: Rect2 = player.hurt_rect() if action_id == "ranged" and str(enemy.definition.get("ranged_target_body","")) == "normal" else player.gravity_rect()
			if _overlaps(_definition_rect(enemy,key),target):enemy.set_action(action_id);return
		if _overlaps(_definition_rect(enemy,"move_rect"),player.gravity_rect()):
			_source_shift_x(enemy,signf(distance)*float(enemy.definition.move_per_tick))
			if enemy.state != "move":enemy.set_action("move")
		elif enemy.state == "move":enemy.set_action("recover")
		return
	var proximity: Rect2 = _definition_rect(enemy,"proximity_rect")
	if _overlaps(proximity,player.gravity_rect()):
		enemy.set_action("attack")
	elif enemy.definition.has("ranged_rect") and _overlaps(_definition_rect(enemy,"ranged_rect"),player.gravity_rect()):
		enemy.set_action("ranged")
	elif _overlaps(_definition_rect(enemy,"move_rect"),player.gravity_rect()):
		if player.position.x > enemy.position.x:enemy.position.x += float(enemy.definition.move_per_tick)
		if player.position.x < enemy.position.x:enemy.position.x -= float(enemy.definition.move_per_tick)
		if enemy.state != "move":
			enemy.set_action("move")
	elif enemy.state == "move":
		enemy.set_action("recover")

func _training_movement(enemy: Node2D) -> void:
	if not _overlaps(_definition_rect(enemy,"move_rect"),player.gravity_rect()):return
	var distance: float = player.position.x-enemy.position.x
	if absf(distance) > 100.0:_source_shift_x(enemy,2.0 if distance > 0 else -2.0)
	enemy.set_action("move") #Independent root41 record6, even within100.

func _definition_rect(actor: Node2D, key: String) -> Rect2:
	var r: Array = actor.definition.get(key,[0,0,0,0])
	if r.size() != 4:
		return Rect2()
	return actor.transform_rect(Rect2(r[0],r[1],r[2],r[3]))

func _on_action_event(actor: Node2D, event: Dictionary) -> void:
	if str(event.kind) in ["source_stop_sounds","stop_all_sounds"]:
		audio.stop_all()
		return
	if str(event.kind) == "sound":
		# CRT4 ghost movement replaces the ordinary6393 child with6397/6404;
		# its independently rendered6393 instance owns the footstep clock.
		if actor==player and int(player.definition.source_crt)==4 and player.state=="move" and int(crt4.ghost_step)==1 and int(event.get("source_id",-1))==6393:return
		if event.has("audio_stream"):
			# New explicitly source-labelled events publish their canonical alias;
			# legacy author streams retain their existing direct-stream contract.
			var source_alias:=str(event.get("sound",""))if event.has("source_id")else""
			audio.play_stream(event.audio_stream,float(event.get("offset",0.0)),source_alias)
		else:audio.play_sfx(str(event.sound),float(event.get("offset",0.0)))
		return
	if ended:
		return
	if str(event.kind) == "source_parent_enter" and actor == player:
		if int(player.definition.source_crt) == 3:_crt3_action_started(player.state)
		_record("source_parent_enter",event)
		return
	if str(event.kind).begins_with("crt1_"):
		_crt1_event(actor,event)
		return
	if str(event.kind).begins_with("crt3_"):
		_crt3_event(actor,event)
		return
	if str(event.kind).begins_with("crt4_"):
		_crt4_event(actor,event)
		return
	if str(event.kind).begins_with("crt2_"):
		_crt2_event(actor,event)
		return
	match str(event.kind):
		"authored_hit":
			var targets: Array = enemies if actor.team == "player" else [player]
			for local: Rect2 in event.get("local_rects",[]):
				var box: Rect2 = actor.transform_rect(local)
				_active_boxes.append(box)
				for target: Node2D in targets:
					if target.hp <= 0 or not _overlaps(box,target.hurt_rect()):continue
					if bool(event.get("once_per_action",true)) and not actor.claim_target(target.identifier):continue
					if float(event.get("damage",0)) > 0:deal_damage(actor,target,float(event.damage),"author window "+actor.state,false)
					if target.hp > 0 and actor.team == "player":_start_marker(actor,target,float(event.get("gravity",-5)),"author "+actor.state)
					target.position.x += actor.facing*float(event.get("knockback",0))
		"y_cutin":_start_source_feedback("cutin")
		"y_phase":_y_set_phase(int(event.phase))
		"sniper_start":
			sniper.root = 2
			sniper.born = int(session.run.source_ticks)
		"root_offset":
			if event.has("y"):position.y = float(event.y)
			if event.has("x"):position.x = float(event.x)
		"physical_window":
			for box: Rect2 in _action_rects(int(event.source_id),actor.source_frame):
				_active_boxes.append(box)
				for target: Node2D in enemies:
					if target.hp > 0 and _overlaps(box,target.hurt_rect()):_start_marker(actor,target,float(event.gravity),"source helper"+str(event.source_id))
		"source_stop_sounds":audio.stop_all()
		"return_idle":actor.set_action("idle")
		"ammo_start":
			ammo_frames[event.ammo] = 2
			_record("ammo_timer_started",{"ammo":event.ammo})
		"grenade_load":
			grenades[event.grenade].active = true
			grenades[event.grenade].icon_frame = 1
			_grenade_loads.append({"kind":event.grenade,"due":int(session.run.source_ticks)+1})
			_record("grenade_load_activated",{"grenade":event.grenade})
		"summon":_spawn_summon(str(event.summon))
		"grenade_window":_grenade_window(str(event.grenade))
		"c4_place":
			c4_count += 1
			_record("c4_count",{"count":c4_count})
		"c4_hit":
			if actor._hit_targets.has("c4_contact"):return
			for target: Node2D in enemies:
				if c4_targets.has(target.identifier) and int(c4_targets[target.identifier].count) >= 3:continue
				for box: Rect2 in _action_rects(4777,actor.source_frame):
					if _overlaps(box,target.hurt_rect()):
						var entry: Dictionary = c4_targets.get(target.identifier,{"count":0,"exploding":false,"charges":[]})
						entry.count += 1
						entry.charges.append({"age":1,"blink":1,"explosion":0,"born":int(session.run.source_ticks)})
						c4_targets[target.identifier] = entry
						actor.claim_target("c4_contact")
						_record("c4_attached",{"target":target.identifier,"count":entry.count})
						return
		"c4_hold_detonate":
			if bool(_held.get("held_e",false)) and not c4_targets.is_empty() and player.mp >= 7.0 and int(session.profile.progress.clear_cubes) >= 1:
				player.mp -= 7.0
				session.profile.progress.clear_cubes -= 1
				player.cooldowns["skill_e"] = 359
				c4_count = 0
				player.set_action("detonate")
		"c4_flash":
			for entry: Dictionary in c4_targets.values():
				for charge: Dictionary in entry.charges:
					charge.blink = 2
					charge["blink_tick"] = int(session.run.source_ticks)
			_record("c4_flash",{})
		"c4_explode":
			c4_count = 0
			for target_id: String in c4_targets:
				c4_targets[target_id].exploding = true
				for charge: Dictionary in c4_targets[target_id].charges:
					charge.explosion = 1
					charge["exploded_tick"] = int(session.run.source_ticks)
		"c4_clear":
			c4_count = 0
			for entry: Dictionary in c4_targets.values():
				if bool(entry.exploding):_push_c4_enemies(int(entry.count))
			_clear_c4()
		"root_motion":
			_move_player(float(event.dx)*player.facing)
		"z_finish":
			_move_player(player.action_child_x*player.facing)
		"z_lift":
			var id := "crt0_skill_z" if actor.state == "skill_z" else "crt0_move_z"
			var data: Dictionary = database.assets.source_geometry[id]
			var helper: Dictionary = data.hit_helper
			var offset: Array = data.initial_parent_offset_px
			var local_offset := Vector2(player.action_child_x if actor.state == "skill_z" else float(offset[0]),float(offset[1]))
			var box := _source_matrix_rect(actor,helper.source_rect,helper.matrix,local_offset)
			_active_boxes.append(box)
			for target: Node2D in enemies:
				if (target.hp > 0 or target.airborne) and _overlaps(box,target.hurt_rect()):
					_lift_target(actor,target,float(event.gravity),"Z physical helper",false)
					_record("z_contact",{"target":target.identifier,"source_frame":actor.source_frame,"gravity":event.gravity})
			if bool(event.timer):_restart_z_interval()
		"timer_restart":
			_enemy_timers[actor.identifier] = {"elapsed":0,"running":true}
		"projectile":
			_spawn_projectile(actor,event)
		"skill_hit":
			var box := skill_rect(actor)
			_active_boxes.append(box)
			for target: Node2D in enemies:
				if target.hp > 0 and _overlaps(box,target.hurt_rect()) and actor.claim_target(target.identifier):
					_start_marker(actor,target,-5.0,"D")
		"enemy_hit","enemy_knockdown":
			var local: Rect2
			if event.has("local_rects") and not event.local_rects.is_empty():local = event.local_rects[0]
			elif event.has("rect"):
				var r: Array = event.rect
				local = Rect2(r[0],r[1],r[2],r[3])
			else:
				var frame: int = clampi(actor.source_frame-26,0,2)
				var offsets := [Vector2(-263,-305),Vector2(-244,-12),Vector2(-584,221)]
				var scales := [Vector2.ONE,Vector2(1,0.590744),Vector2(0.750412,0.3438263)]
				local = Rect2((Vector2(-1224,-1146)*scales[frame]+offsets[frame]+Vector2(0,-1325))/20.0,Vector2(2437,2292)*scales[frame]/20.0)
			var box: Rect2 = actor.transform_rect(local)
			_active_boxes.append(box)
			if player.hp > 0 and _overlaps(box,player.hurt_rect()):
				# Source push applies on each overlapping tick; shared hurt marker gates damage.
				player.position.x = clampf(player.position.x + signf(player.position.x-actor.position.x)*float(event.get("knockback",0)),float(stage.bounds[0]),float(stage.bounds[1]))
				if str(event.kind) == "enemy_knockdown" and player.definition.actions.has("knockdown"):
					if player.state != "knockdown":player.set_action("knockdown")
					player.seek_action_frame(2)
				else:player.request_hurt(int(actor.definition.get("hurt_child_seek",0)))
				_record("player_hurt_contact",{"attacker":actor.identifier,"frame":actor.source_frame,"hurt_frame":player.source_frame})
		"death_settled":
			if actor.team == "enemy" and not actor._dead_emitted:
				actor._dead_emitted = true
				if is_training():
					_record("training_enemy_dead",{"actor":actor.identifier})
					return
				var rewards: Dictionary = stage.get("reward_by_difficulty",actor.definition.get("reward_by_difficulty",{}))
				var reward: int = int(rewards.get(session.run.difficulty_id,stage.get("reward",100)))
				if session.settle_enemy(actor.identifier,reward):
					_record("enemy_settled",{"actor":actor.identifier,"remaining":session.run.enemies_remaining,"gold":reward})
					persistence_requested.emit()
					if session.run.enemies_remaining == 0:
						_end("victory")

func _observe_player_hurt() -> void:
	if player.state == "knockdown" and player.source_frame == 3:
		var amounts: Array = stage.get("knockdown_hurt_observers",[])
		for index in range(mini(amounts.size(),enemies.size())):deal_damage(enemies[index],player,float(amounts[index]),"root knockdown3 observer",false)
		return
	if player.hp <= 0 or player.state != "hit" or player.source_frame != 2:
		return
	# Root clip listeners survive their internal enemy's death. They all read
	# the same player child, regardless of which enemy caused the contact.
	var observers: Array = stage.player_hurt_observers
	for index in range(observers.size()):
		deal_damage(enemies[index],player,float(observers[index]),"root clip observer%d: player hurt source2" % index,false)

func skill_rect(actor: Node2D) -> Rect2:
	# DefineShape4684 and placements in sprite4685 frames8..15, held to18.
	var x := [2630.0,3952.0,5276.0,6599.0,7923.0,9246.0,10569.0,11046.0]
	var y := [-788.0,-771.0,-754.0,-736.0,-719.0,-701.0,-684.0,-696.0]
	var sx := [0.71647644,0.7133026,0.7101135,0.7069397,0.7037506,0.7005768,0.6973877,0.69421387]
	var index := clampi(actor.source_frame - 8,0,7)
	var center: Vector2 = Vector2((x[index] - 892.0)/20.0,(y[index] + 17.0)/20.0) * actor.visual_scale
	center.x *= actor.facing
	var size: Vector2 = Vector2(2658.0/20.0 * sx[index],1736.0/20.0 * 3.8215) * actor.visual_scale
	return Rect2(actor.position + center - size/2.0,size)

func _spawn_projectile(actor: Node2D, event: Dictionary = {}) -> void:
	var key: String = str(event.get("projectile","projectile"))
	var base_key := key
	if int(actor.definition.get("source_crt",-1)) == 0:
		if key == "projectile_rising" and (_ammo_active("fire") or _ammo_active("silver")):key += "_silver"
		elif key != "projectile_rising":
			if _ammo_active("silver"):key += "_silver"
			elif _ammo_active("fire"):key += "_fire"
	var sprite: Node2D = Visual.new()
	var host: Node2D = event.get("host",null)
	if is_instance_valid(host):
		for old: Dictionary in projectiles.duplicate():
			if str(old.get("host_depth_key","")) == str(event.host_depth_key):
				old.visual.queue_free()
				projectiles.erase(old)
		host.add_child(sprite)
	else:add_child(sprite)
	sprite.configure(database.assets.animations[key])
	sprite.position = actor.position
	sprite.scale = actor.visual_scale * Vector2(actor.facing,1)
	projectiles.append({"visual":sprite,"origin":actor.position,"age":0,"born":int(session.run.source_ticks),"callback_order":_new_callback_order(),"direction":actor.facing,"scale":actor.visual_scale,"spent":false,"targets":{},"owner":actor,"key":base_key,"visual_key":key,"firec":0,"fire_depth":1000,"gravity":float(event.get("gravity",-5)),"parent_y":float(event.get("parent_y",0))})
	if is_instance_valid(host):
		projectiles[-1]["host"] = host
		projectiles[-1]["host_depth_key"] = str(event.host_depth_key)
		projectiles[-1].direction = 1
		projectiles[-1].scale = Vector2.ONE
		sprite.position = Vector2.ZERO
		sprite.scale = Vector2.ONE
	projectiles[-1]["head_empty"] = false
	projectiles[-1]["penetration_draws"] = []
	projectiles[-1]["spawn_offset"] = _vec(event.get("spawn_offset",[0,0]))
	projectiles[-1]["static_origin"] = bool(event.get("static_origin",false))
	if event.has("world_scale"):
		projectiles[-1].scale = _vec(event.world_scale)
		projectiles[-1].origin = actor.position+projectiles[-1].spawn_offset
		sprite.scale = projectiles[-1].scale*Vector2(actor.facing,1)
	else:projectiles[-1].origin += projectiles[-1].spawn_offset*actor.visual_scale*Vector2(actor.facing,1)
	if not is_instance_valid(host):sprite.position = projectiles[-1].origin
	sprite.z_index = actor.z_index
	_record("projectile_spawn",{"source_frame":actor.source_frame,"key":key,"sub_frame":actor.air_action_frame,"parent_y":event.get("parent_y",0)})

func _advance_projectiles() -> void:
	for index in range(projectiles.size()-1,-1,-1):
		var bullet: Dictionary = projectiles[index]
		if bullet.has("host") and not _live_source_host(bullet.host):
			if is_instance_valid(bullet.visual):bullet.visual.queue_free()
			projectiles.remove_at(index)
			continue
		if int(bullet.born) == int(session.run.source_ticks):continue #Load is not EnterFrame.
		if bullet.key in ["projectile_head","projectile_moving","projectile_diagonal_two"]:
			if not _advance_crt1_projectile(bullet):bullet.visual.queue_free();projectiles.remove_at(index)
			continue
		if bullet.has("host") and int(bullet.age) >= 10:continue #Inert11 stays in its true host until replacement/removal.
		bullet.age += 1
		var diagonal: bool = bullet.key == "projectile_diagonal"
		if int(bullet.age) >= 10:
			if bullet.has("host"):
				bullet.visual.source_frame = 11
				bullet.visual.visible = false #1474 f11 removes542, with no nonempty image.
				continue
			# Source11 is empty/stopped; release the inert container in Godot.
			# This is lifecycle cleanup, not a fabricated source12 hit event.
			bullet.visual.queue_free()
			projectiles.remove_at(index)
			continue
		bullet.visual.set_source_frame(int(bullet.age)+1)
		var geometry: Dictionary = database.assets.source_geometry["projectile_default" if bullet.key == "projectile" else bullet.key]
		bullet.origin = bullet.owner.position+bullet.get("spawn_offset",Vector2.ZERO)*bullet.scale*Vector2(int(bullet.direction),1)
		bullet.visual.position = bullet.origin+Vector2(0,bullet.parent_y*bullet.scale.y)
		var box: Rect2
		if diagonal:
			var matrix: Array = geometry.timeline_matrices[int(bullet.age)].matrix
			box = _source_matrix_rect(bullet.owner,geometry.rect,matrix,Vector2(0,bullet.parent_y),int(bullet.direction))
		else:
			var source_x: Array = geometry.timeline_x_twips
			var center: Vector2 = bullet.origin + Vector2(float(source_x[int(bullet.age)])/20.0*int(bullet.direction),-3.75)*bullet.scale
		# 542 default frame1 stroke bounds, then its source scale and player scale.
			var shape_scale: Vector2 = Vector2(1.2250977,1.6338501) * bullet.scale
			var offset := Vector2(-7.5,-6.3) * shape_scale
			var size := Vector2(14.85,12.65) * shape_scale
			if int(bullet.direction) < 0:offset.x = -offset.x - size.x
			box = Rect2(center + offset,size)
		if bullet.has("host"):
			bullet.visual.position = Vector2.ZERO
			var x: float = float(geometry.timeline_x_twips[int(bullet.age)])/20.0
			box = global_transform.affine_inverse()*bullet.host.global_transform*Rect2(Vector2(x,-3.75)+Vector2(-7.5,-6.3)*Vector2(1.2250977,1.6338501),Vector2(14.85,12.65)*Vector2(1.2250977,1.6338501))
		_active_boxes.append(box)
		_transient_contacts.append({"order":bullet.callback_order,"bullet":bullet,"box":box})

func _projectile_contacts(bullet: Dictionary, box: Rect2) -> void:
	for enemy: Node2D in enemies:
		if bool(bullet.head_empty):break
		if enemy.hp > 0 and not bullet.targets.has(enemy.identifier) and _overlaps(box,enemy.hurt_rect()):
			bullet.spent = true
			bullet.targets[enemy.identifier] = true
			var uses_default_head: bool = bullet.key in ["projectile","projectile_strong","projectile_rising","projectile_diagonal"]
			if uses_default_head:_projectile_penetration_draw(bullet)
			if enemy.frozen:_frozen_hit(enemy,2)
			else:
				_start_marker(bullet.owner,enemy,float(bullet.gravity),str(bullet.key))
				if _ammo_active("silver") or (bullet.key == "projectile_rising" and _ammo_active("fire")):_set_enemy_status(enemy,"silver")
				if uses_default_head:_projectile_penetration_draw(bullet)
			if bullet.key != "projectile_rising" and _ammo_active("fire") and int(bullet.firec) < 2:
				_spawn_fire_blast(enemy.position,int(bullet.fire_depth))
				bullet.fire_depth += 1
				bullet.firec += 1
			if bool(bullet.head_empty):bullet.visual.visible = false

func _projectile_penetration_draw(bullet: Dictionary) -> void:
	#1474/1473: two independent tests for a normal hit, one for frozen.
	#3833 sets default passper55; equipment85/1/25 branches remain separate.
	var value := randi_range(1,100)
	bullet.penetration_draws.append(value)
	if value < 55:bullet.head_empty = true

func _resolve_transient_contacts() -> void:
	var physical := {}
	for request: Dictionary in _y_collision_requests():
		physical[int(request.helper.callback_order)] = request
	for observer: Dictionary in _y_marker_observers():
		_transient_contacts.append({"order":observer.helper.callback_order,"observer":observer,"request":physical.get(int(observer.helper.callback_order),{})})
	# AVM1 enterFrame traverses the live instance creation list in reverse.
	# Timeline helper placement precedes queued DoAction attachMovie births.
	_transient_contacts.sort_custom(func(a: Dictionary, other: Dictionary)->bool:return int(a.order)>int(other.order))
	for callback: Dictionary in _transient_contacts:
		if callback.has("bullet"):_projectile_contacts(callback.bullet,callback.box)
		else:
			var request: Dictionary = callback.request
			if not request.is_empty():
				_active_boxes.append(request.rect)
				for target: Node2D in enemies:
					if target.hp <= 0 or not _overlaps(request.rect,target.hurt_rect()):continue
					if target.frozen:
						_frozen_hit(target,5)
						request.helper.frame = 2
						request.helper.playing = false
					else:_lift_target(player,target,-8.0,"Y1140",bool(request.normal_restart_marker))
			#Placement observers survive1140's empty3. They read marker2 at
			#their own creation-list position, before or after a later bullet.
			for target: Node2D in enemies:
				var marker: Dictionary = _markers.get(target.identifier,{})
				if int(marker.get("processed_tick",-1)) == int(session.run.source_ticks):deal_damage(player,target,float(callback.observer.amount),"Y1140 observer",false)
	_transient_contacts.clear()

func _new_callback_order() -> int:
	_callback_order += 1
	return _callback_order

func _ammo_active(kind: String) -> bool:
	return int(ammo_frames[kind]) >= 9

func _live_source_host(host: Node) -> bool:
	if not is_instance_valid(host):return false
	var node := host
	while is_instance_valid(node) and node != self:
		if node.is_queued_for_deletion():return false
		node = node.get_parent()
	return node == self

func _spawn_fire_blast(at: Vector2, depth: int) -> void:
	var route := "a" if randf() < 0.3 else "b"
	var key := "ammo_fire_blast_"+route
	_replace_root_depth(depth)
	var sprite := _new_source_visual(key,self)
	sprite.position = at
	sprite.z_index = clampi(depth+16384,-4096,4096)
	sprite.set_source_frame(1 if route == "a" else 27)
	sprite.visible = false
	summons.append({"kind":"ammo_fire","key":key,"depth":depth,"visual":sprite,"frame":1,"child":1,"born":int(session.run.source_ticks),"wait":0,"facing":1,"route":route,"seen_frames":{}})
	_sort_dynamic_root_views()

func _sort_dynamic_root_views() -> void:
	# Positive AS attach depths exceed Godot's4096 limit. Keep their actual
	# ordinal order among equal-z siblings, including a low-depth replacement
	# created after a higher-depth survivor. Node creation order alone is wrong.
	var roots: Array = []
	for item: Dictionary in summons:roots.append({"visual":item.visual,"depth":int(item.depth)+16384})
	if source_feedback.has("glass"):roots.append({"visual":source_feedback.glass.visual,"depth":15000+16384})
	roots.sort_custom(func(a: Dictionary, other: Dictionary)->bool:return int(a.depth)<int(other.depth))
	for item: Dictionary in roots:
		if is_instance_valid(item.visual) and not item.visual.is_queued_for_deletion():move_child(item.visual,get_child_count()-1)

func _replace_root_depth(depth: int) -> void:
	for old: Dictionary in summons.duplicate():
		if int(old.depth) == depth:
			old.visual.queue_free()
			summons.erase(old)

func _start_marker(attacker: Node2D, target: Node2D, gravity: float, source: String) -> void:
	_lift_target(attacker,target,gravity,source,true)

func _lift_target(attacker: Node2D, target: Node2D, gravity: float, source: String, restart_marker: bool) -> void:
	if target.frozen:
		_frozen_hit(target,2)
		return
	# Physics assignments occur for each hit source even when they share one marker.
	var new_layer: bool = not target.airborne
	var retained_marker: bool = not new_layer and target._air_hit_started >= 0 and target._air_hit_started < int(session.run.source_ticks)
	var pending_marker_stop: bool = retained_marker and int(session.run.source_ticks)-target._air_hit_started+1 == 8
	if new_layer:
		target.set_action("idle")
	target.airborne = true
	target.vertical_speed = gravity
	target.gravity_acceleration += 0.1
	if not new_layer and not restart_marker and target._air_hit_started >= 0:
		return
	var existing: Dictionary = _markers.get(target.identifier,{})
	if not new_layer and int(existing.get("processed_tick",-1)) == int(session.run.source_ticks):
		# gotoAndPlay2 while the same marker already processes2 preserves that
		# instance; repeated physical assignments above must still occur.
		return
	target.play_air_hit(int(session.run.source_ticks))
	target.update_air_visual(int(session.run.source_ticks))
	# Source has one target.공중.타격 clip, never parallel damage timers per target.
	# Re-hit scheduling vs Flash listener order remains a documented calibration point.
	var generation: int = int(_markers.get(target.identifier,{}).get("generation",0))+1
	_markers[target.identifier] = {"owner":attacker,"target":target,"age":0,"source":source,"generation":generation}
	if retained_marker:
		#3889 remains as empty stopped8 until4028 pose2 removes its instance.
		target.play_air_hit(int(session.run.source_ticks)-1)
		target.air_marker_stopped = pending_marker_stop
		_observe_marker_two(_markers[target.identifier],false)
		_markers[target.identifier].age = 1
		_markers[target.identifier]["stopped_two"] = pending_marker_stop
	_record("marker_started",{"target":target.identifier,"source":source})

func _freeze_target(target: Node2D) -> void:
	if not target.frozen:
		_markers.erase(target.identifier)
		target.begin_freeze()
		_record("freeze_started",{"target":target.identifier})

func _frozen_hit(target: Node2D, frame := 2) -> void:
	if not target.frozen:return
	target.freeze_hit_frame = frame
	target.refresh_freeze()

func _observe_frozen() -> void:
	for target: Node2D in enemies:
		if target.frozen and target.freeze_hit_frame in [2,5]:
			deal_damage(player,target,5.0 if target.freeze_hit_frame == 2 else 10.0,"root enemy frozen inner observer",false)

func _set_enemy_status(target: Node2D, kind: String) -> void:
	var states: Dictionary = enemy_status.get(target.identifier,{})
	if kind == "silver":
		if not states.has(kind):states[kind] = {"frame":12,"age":0}
	elif states.has(kind):
		states[kind].frame = 2
	else:
		var data: Dictionary = database.assets.source_geometry.enemy_status
		var root_matrix: Array = data.enemy_parent_placements[str(int(target.definition.source_id))].matrix
		var group := Node2D.new()
		add_child(group)
		group.z_index = target.z_index+2
		var visual := _new_source_visual("status_"+kind,group)
		states[kind] = {"frame":2,"age":0,"group":group,"visual":visual,"matrix":root_matrix}
	enemy_status[target.identifier] = states
	if kind != "silver":_play_source_audio("status_"+kind,2)
	_update_status_visuals(target)

func _update_status_visuals(target: Node2D) -> void:
	for kind: String in enemy_status.get(target.identifier,{}):
		var item: Dictionary = enemy_status[target.identifier][kind]
		if kind == "silver":continue #Original3991 has alpha0.
		var m: Array = item.matrix
		item.group.position = target.position+Vector2(m[4],m[5])*target.visual_scale
		item.group.scale = target.visual_scale*Vector2(m[0],m[3])
		item.visual.set_source_frame(int(item.frame))

func _advance_enemy_status() -> void:
	for target: Node2D in enemies:
		var was_frozen: bool = target.frozen
		target.advance_freeze()
		if was_frozen and not target.frozen:_thaw_ticks[target.identifier] = int(session.run.source_ticks)
		var states: Dictionary = enemy_status.get(target.identifier,{})
		for kind: String in states.keys():
			var item: Dictionary = states[kind]
			item.age += 1
			item.frame += 1
			var expired: bool = target.hp <= 0
			if kind == "silver":expired = expired or int(item.frame) >= 19
			elif kind == "sniper_hit":expired = expired or int(item.frame) >= 8
			else:
				if int(item.frame) >= 10:item.frame = 2
				expired = expired or int(item.age) > (200 if kind == "shock" else 90)
				if kind == "stun" and target.frozen and target.freeze_frame == 2:expired = true
				if kind == "stun" and not expired and not target.airborne and not target.frozen:
					if target.state != "hit":target.set_action("hit")
					target.seek_action_frame(53 if int(target.definition.source_id) == 4030 else 101)
					target._stopped = true
			if expired:
				if kind == "stun" and not target.airborne:target._stopped = false
				if item.has("group"):item.group.queue_free()
				states.erase(kind)
		_update_status_visuals(target)

func _new_source_visual(key: String, parent: Node) -> Node2D:
	var visual := Visual.new()
	parent.add_child(visual)
	visual.configure(database.assets.animations[key])
	return visual

func _advance_c4() -> void:
	var data: Dictionary = database.assets.source_geometry.c4_attached
	for target_id: String in c4_targets:
		var target: Node2D = null
		for actor: Node2D in enemies:
			if actor.identifier == target_id:target = actor;break
		if not is_instance_valid(target):continue
		var entry: Dictionary = c4_targets[target_id]
		var views: Array = _c4_views.get(target_id,[])
		var source_id := str(int(target.definition.source_id))
		var container: Array = data.enemy_placements_by_source_frame[source_id]["1"][0].matrix
		var placements: Array = data.charges_by_source_page[str(int(entry.count)+1)]
		for i in range(entry.charges.size()):
			var charge: Dictionary = entry.charges[i]
			if int(charge.born) != int(session.run.source_ticks):charge.age += 1
			if int(charge.blink) > 1 and int(charge.get("blink_tick",-1)) != int(session.run.source_ticks):charge.blink = 2 if int(charge.blink) >= 3 else 3
			if int(charge.explosion) > 0 and int(charge.get("exploded_tick",-1)) != int(session.run.source_ticks):charge.explosion += 1
			if i >= views.size():
				var group := Node2D.new()
				group.z_index = target.z_index+1
				add_child(group)
				var view := {"group":group,"charge":_new_source_visual("c4_charge",group),"glow":_new_source_visual("c4_charge_glow",group),"blink":_new_source_visual("c4_blink",group),"blast":_new_source_visual("c4_blast",group)}
				view.glow.modulate.a = float(data.parts["3912"].alpha_mult)/256.0
				views.append(view)
			var view: Dictionary = views[i]
			var matrix: Array = placements[i].matrix
			view.group.position = target.position+Vector2(container[4]+matrix[4],container[5]+matrix[5])*target.visual_scale
			view.group.scale = target.visual_scale
			view.charge.visible = int(charge.explosion) == 0
			view.glow.visible = int(charge.explosion) == 0
			view.blink.visible = int(charge.explosion) == 0 and int(charge.blink) > 1
			view.blast.visible = int(charge.explosion) > 0
			view.charge.set_source_frame((int(charge.age)-1)%10+1)
			view.glow.set_source_frame((int(charge.age)-1)%20+1)
			if view.blink.visible:view.blink.set_source_frame(int(charge.blink))
			if view.blast.visible:view.blast.set_source_frame(mini(9,int(charge.explosion)))
			if int(charge.get("exploded_tick",-1)) == int(session.run.source_ticks):_play_source_audio("c4_blast",1)
			if int(charge.explosion) == 2:
				var row: Dictionary = database.assets.source_geometry.act02_hit_windows.timelines["3916"].active_by_source_frame["2"][0]
				var box := _world_rect(row.rect,view.group.position,target.visual_scale)
				_active_boxes.append(box)
				for victim: Node2D in enemies:
					if victim.hp <= 0 or not _overlaps(box,victim.hurt_rect()):continue
					if victim.frozen:
						_frozen_hit(victim,5) #3916 records6..10, followed by16..20.
						victim.clear_freeze()
						victim.set_action("move")
					else:_lift_target(player,victim,-8.0,"C4 charge helper",false)
			#1140's shape becomes empty at3; its26..35 clip observers persist.
			if int(charge.explosion) >= 3:
				_push_c4_enemies(1)
		_c4_views[target_id] = views

func _push_c4_enemies(count: int) -> void:
	for i in range(count):
		for victim: Node2D in enemies:
			if not victim.airborne:continue
			if player.position.x <= victim.position.x:_source_shift_x(victim,2.0)
			if player.position.x >= victim.position.x:_source_shift_x(victim,-2.0)

func _advance_v() -> void:
	if int(player.definition.source_crt) in [2,3,4]:return
	_v_trace = {"zab":zab,"pren":pren,"anchor_active":false,"child":[-3.65,3.8]}
	if player.state != "skill_v":return
	if int(player.definition.source_crt) == 1:
		_advance_crt1_grab()
		return
	var frame: int = player.source_frame
	var source_id := int(player.definition.actions.skill_v.get("grab_source_id",5678))
	var table: Dictionary = database.assets.source_geometry.act03_crt1_hit_windows if int(player.definition.source_crt) == 1 else database.assets.source_geometry.act02_hit_windows
	var rows: Array = table.timelines[str(source_id)].active_by_source_frame.get(str(frame),[])
	if int(player.definition.source_crt) == 1:rows = _crt1_component("grab").timeline.get(str(frame),[])
	if frame == 7:
		for box: Rect2 in _action_rects(source_id,frame):
			for target: Node2D in enemies:
				if target.hp > 0 and not target.frozen and _overlaps(box,target.hurt_rect()):
					zab = target.identifier
					player.seek_action_frame(15)
					return
	if frame == 8:
		for box: Rect2 in _action_rects(source_id,frame):
			for target: Node2D in enemies:
				if target.hp > 0 and _overlaps(box,target.hurt_rect()):_lift_target(player,target,-12.0,"V empty fallback",false)
	if frame == 14:
		_move_player(-3.65*player.facing)
		player.set_action("idle")
		return
	if frame >= 16 and frame < 70:pren = 2
	if frame >= 68:zab = ""
	if frame >= 70:pren = 0
	if frame == 71:player.set_action("idle");return
	# Each651 creation requests one marker; its stopped2 has no repeated shape.
	if frame in [27,31,35,39,43,47,51,55,59,63,67,70]:
		var entry_frame := frame-1
		for row: Dictionary in rows:
			if int(row.source_id) != 651:continue
			var r: Array = row.rect
			var box: Rect2 = player.transform_rect(Rect2(r[0]-3.65,r[1]+3.8,r[2],r[3]))
			_active_boxes.append(box)
			for target: Node2D in enemies:
				if target.hp <= 0 or not _overlaps(box,target.hurt_rect()):continue
				var old_acc: float = target.gravity_acceleration
				_start_marker(player,target,-8.0 if entry_frame == 69 else (-0.1 if entry_frame == 66 else -0.3),"V651")
				if entry_frame == 26:target.gravity_acceleration = old_acc
				if entry_frame == 66:target.gravity_acceleration = 0.0
	if frame in range(16,68) and not zab.is_empty():
		for row: Dictionary in rows:
			if int(row.source_id) != 5652:continue
			for target: Node2D in enemies:
				if target.identifier != zab:continue
				var m: Array = row.matrix
				if not target.airborne:_lift_target(player,target,target.vertical_speed-2.0,"V anchor enters air",false)
				else:
					target.vertical_speed -= 2.0
					target.gravity_acceleration += 0.1
				target.position.x = Actor.twips(Actor.source_coordinate(player.position.x)+(-3.65+float(m[4]))*player.facing)
				target.position.y = Actor.twips(Actor.source_coordinate(player.position.y)+3.8+float(m[5]))
				_v_trace = {"zab":zab,"pren":pren,"anchor_active":true,"anchor_local":[m[4],m[5]],"child":[-3.65,3.8],"formula":[Actor.source_coordinate(target.position.x),Actor.source_coordinate(target.position.y)]}

func _matrix(values: Array) -> Transform2D:
	return Transform2D(Vector2(values[0],values[1]),Vector2(values[2],values[3]),Vector2(values[4],values[5]))

func _advance_crt1_grab() -> void:
	var data := _crt1_component("grab")
	var frame: int = player.source_frame
	var rows: Array = data.timeline.get(str(frame),[])
	var parent: Array = data.parent_matrix
	var offset := Vector2(parent[4],parent[5])
	_v_trace = {"zab":zab,"pren":pren,"anchor_active":false,"child":[offset.x,offset.y]}
	if _source_has(data.contact_frames,frame):
		for box: Rect2 in _action_rects(int(data.source_id),frame):
			for target: Node2D in enemies:
				if target.hp > 0 and not target.frozen and _overlaps(box,target.hurt_rect()):
					zab = target.identifier
					player.seek_action_frame(int(data.contact_destination))
					return
	if frame == int(data.fallback_frame):
		for box: Rect2 in _action_rects(int(data.source_id),frame):
			for target: Node2D in enemies:
				if target.hp > 0 and _overlaps(box,target.hurt_rect()):_lift_target(player,target,float(data.fallback_gravity),"CRT1 V fallback",false)
	if frame == int(data.normal_end_frame):
		_move_player(float(data.normal_end_x_transfer)*player.facing)
		player.set_action("idle");return
	if frame >= int(data.pren_start_frame) and frame < int(data.pren_clear_frame):pren = 2
	if frame >= int(data.zab_clear_frame):zab = ""
	if frame >= int(data.pren_clear_frame):pren = 0
	if frame == int(data.end_frame):player.set_action("idle");return
	if _source_has(data.marker_frames,frame):
		for row: Dictionary in rows:
			if int(row.source_id) != int(data.marker_helper_id):continue
			var r: Array = row.rect
			var box: Rect2 = player.transform_rect(_matrix(parent)*Rect2(r[0],r[1],r[2],r[3]))
			_active_boxes.append(box)
			for target: Node2D in enemies:
				if target.hp <= 0 or not _overlaps(box,target.hurt_rect()):continue
				var gravity := float(data.marker_gravity)
				if frame == int(data.marker_frames[-1]):gravity = float(data.marker_final_gravity)
				elif frame == int(data.marker_frames[-2]):gravity = float(data.marker_penultimate_gravity)
				_start_marker(player,target,gravity,"CRT1 V651")
				if frame == int(data.marker_gacc_reset_frame):target.gravity_acceleration = 0.0
	if frame >= int(data.anchor_from) and frame <= int(data.anchor_until) and not zab.is_empty():
		for row: Dictionary in rows:
			if int(row.source_id) != int(data.anchor_helper_id):continue
			for target: Node2D in enemies:
				if target.identifier != zab:continue
				var anchor: Array = row.matrix
				if not target.airborne:_lift_target(player,target,target.vertical_speed+float(data.anchor_gravity_delta),"CRT1 V anchor",false)
				else:
					target.vertical_speed += float(data.anchor_gravity_delta)
					target.gravity_acceleration += float(data.anchor_gacc_delta)
				target.position.x = Actor.twips(Actor.source_coordinate(player.position.x)+(offset.x+float(anchor[4]))*player.facing)
				target.position.y = Actor.twips(Actor.source_coordinate(player.position.y)+offset.y+float(anchor[5]))
				_v_trace = {"zab":zab,"pren":pren,"anchor_active":true,"anchor_local":[anchor[4],anchor[5]],"child":[offset.x,offset.y]}

func _sniper_key_down(input: Dictionary) -> void:
	if int(sniper.root) != 6 or int(sniper.reticle) != 1 or not bool(input.get("skill_t",false)):return
	sniper.reticle = 2
	sniper.reticle_born = int(session.run.source_ticks)
	sniper.ammo += 1
	_start_source_feedback("glass")
	var data: Dictionary = database.assets.source_geometry.sniper.ammo
	for placement: Dictionary in data.casings_created_by_count_source_frame.get(str(sniper.ammo),[]):
		sniper.casings.append({"frame":1,"born":int(session.run.source_ticks),"matrix":placement.matrix})
	_play_source_audio("sniper_random",randi_range(2,4))
	_play_source_audio("sniper_reticle",2)
	_record("sniper_shot",{"ammo":sniper.ammo})

func _sniper_exit(reason: String) -> void:
	if int(sniper.root) != 6:return
	sniper.root = 7
	sniper.born = int(session.run.source_ticks)
	sniper.casings.clear()
	sniper.glass_helper = Vector2(277,210)
	_record("sniper_exit",{"reason":reason})

func _advance_sniper() -> void:
	var tick := int(session.run.source_ticks)
	if int(sniper.root) > 1 and int(sniper.root) != 6 and int(sniper.born) < tick:
		sniper.root += 1
		if int(sniper.root) == 6:
			sniper.born = tick
			sniper.reticle = 1
			sniper.local = Vector2(24,46.1)
			sniper.ammo = 1
			sniper.timer = 1
		elif int(sniper.root) == 11:player.set_action("idle")
		elif int(sniper.root) > 12:sniper.root = 1
	if int(sniper.root) == 6 and int(sniper.born) < tick:
		sniper.timer += 1
		if int(sniper.reticle) == 1:
			for pair: Array in [["left",Vector2(-20,0)],["right",Vector2(20,0)],["up",Vector2(0,-20)],["held_down",Vector2(0,20)]]:
				if bool(_held.get(pair[0],false)):
					sniper.local += pair[1]
					sniper.glass_helper += pair[1]*0.635
			_sniper_wall()
		elif int(sniper.reticle_born) < tick:
			sniper.reticle += 1
			if int(sniper.reticle) > 15:sniper.reticle = 1
			if int(sniper.reticle) == 14 and int(sniper.ammo) == 7:_sniper_exit("ammo7 source13 observer")
		for casing: Dictionary in sniper.casings:
			if int(casing.born) < tick:casing.frame = mini(18,int(casing.frame)+1)
		if int(sniper.timer) >= 265:_sniper_exit("timer265")
	_render_sniper()

func _sniper_wall() -> void:
	var polygon := PackedVector2Array([Vector2(1280.3,-476.15),Vector2(1280.3,800.2),Vector2(912.15,800.2),Vector2(-724.2,800.2),Vector2(-724.2,-476.1),Vector2(-288.1,-476.1)])
	for side: int in range(4):
		var basis := _matrix(database.assets.source_geometry.sniper.root_matrix)*Transform2D(0.0,sniper.local)
		var bounds: Rect2 = basis*(_matrix([2.9929504,0,0,-2.5882263,23.2,23.35])*Rect2(-17.55,-18.5,35.15,37.15))
		#6780 uses world bounds with LOCAL x/y, in this original order.
		var point: Vector2 = [Vector2(bounds.end.x,23.35),Vector2(bounds.position.x,23.35),Vector2(23.2,bounds.end.y),Vector2(23.2,bounds.position.y)][side]
		if Geometry2D.is_point_in_polygon(point,polygon) and not Rect2(0,0,550,400).has_point(point):
			sniper.local += [Vector2(-20,0),Vector2(20,0),Vector2(0,-20),Vector2(0,20)][side]

func _sniper_contacts() -> void:
	if int(sniper.root) != 6 or int(sniper.reticle) not in [3,4,5]:return
	var row: Dictionary = database.assets.source_geometry.act02_hit_windows.timelines["6789"].active_by_source_frame[str(sniper.reticle)][0]
	var r: Array = row.rect
	var box := _matrix(database.assets.source_geometry.sniper.root_matrix)*Transform2D(0.0,sniper.local)*Rect2(r[0],r[1],r[2],r[3])
	_active_boxes.append(box)
	for target: Node2D in enemies:
		var status: Dictionary = enemy_status.get(target.identifier,{}).get("sniper_hit",{})
		if int(status.get("frame",1)) == 3:deal_damage(player,target,40.0,"6788 observer3945 source3",false)
	for target: Node2D in enemies:
		if target.hp <= 0 or not _overlaps(box,target.hurt_rect()):continue
		if target.airborne:
			target.vertical_speed = -3.0
			target.gravity_acceleration += 0.1
		else:
			_set_enemy_status(target,"stun")
			_set_enemy_status(target,"sniper_hit")
			if not target.frozen:target.set_action("hit") #Root normal contact repeatedly seeks51.

func _render_sniper() -> void:
	if sniper.views.is_empty():
		var group := Node2D.new()
		add_child(group)
		group.transform = _matrix(database.assets.source_geometry.sniper.root_matrix)
		group.z_index = int(stage.source_depths.sniper)
		sniper.views = {"group":group,"main":_new_source_visual("sniper_main",group),"reticle":_new_source_visual("sniper_reticle",group),"ammo":_new_source_visual("sniper_ammo",group),"timer":_new_source_visual("sniper_timer",group),"casings":[]}
	var view: Dictionary = sniper.views
	view.group.visible = int(sniper.root) > 1
	view.main.visible = int(sniper.root) <= 11
	if view.main.visible:view.main.set_source_frame(int(sniper.root))
	for part: String in ["reticle","ammo","timer"]:view[part].visible = int(sniper.root) == 6
	if int(sniper.root) == 6:
		view.reticle.position = sniper.local-Vector2(24,46.1)
		view.reticle.set_source_frame(int(sniper.reticle))
		view.ammo.set_source_frame(int(sniper.ammo))
		for page: Dictionary in database.assets.source_geometry.sniper.timer.image_ranges:
			if int(sniper.timer) >= int(page.from) and int(sniper.timer) <= int(page.through):view.timer.set_source_frame(int(page.image_source_frame))
	while view.casings.size() > sniper.casings.size():view.casings.pop_back().queue_free()
	while view.casings.size() < sniper.casings.size():view.casings.append(_new_source_visual("sniper_casing",view.group))
	for i: int in range(sniper.casings.size()):
		var casing: Dictionary = sniper.casings[i]
		view.casings[i].position = Vector2(casing.matrix[4]-11.8,casing.matrix[5]-.65)
		view.casings[i].set_source_frame(int(casing.frame))

func _start_source_feedback(kind: String) -> void:
	if source_feedback.has(kind):source_feedback[kind].visual.queue_free()
	var key := "hud_y_cutin" if kind == "cutin" else "sniper_glass"
	var sprite := _new_source_visual(key,self)
	if kind == "cutin":
		var row: Dictionary = database.assets.source_geometry.skill_cutin.root_placements_by_source_frame[str(stage.source_root_frame)][0]
		sprite.position = Vector2(row.matrix[4],row.matrix[5])
		sprite.z_index = int(row.depth)
	else:
		sprite.position = sniper.glass_helper
		sprite.z_index = 4096
	var frame := 2 if kind == "cutin" else 1
	sprite.set_source_frame(frame)
	_play_source_audio(key,frame)
	source_feedback[kind] = {"visual":sprite,"frame":frame,"born":int(session.run.source_ticks)}
	if kind == "glass":_sort_dynamic_root_views()

func _advance_source_feedback() -> void:
	for kind: String in source_feedback.keys():
		var item: Dictionary = source_feedback[kind]
		if int(item.born) == int(session.run.source_ticks):continue
		item.frame += 1
		if kind == "cutin" and int(item.frame) >= 33:
			item.visual.queue_free()
			source_feedback.erase(kind)
		else:
			item.visual.set_source_frame(mini(30,int(item.frame)))
			if int(item.frame) <= 30:_play_source_audio("sniper_glass" if kind == "glass" else "hud_y_cutin",int(item.frame))

func _clear_c4() -> void:
	for views: Array in _c4_views.values():
		for view: Dictionary in views:
			if is_instance_valid(view.group):view.group.queue_free()
	_c4_views.clear()
	c4_targets.clear()

func _world_rect(rect: Array, origin: Vector2, scale := Vector2.ONE) -> Rect2:
	var box := Rect2(Vector2(rect[0],rect[1])*scale,Vector2(rect[2],rect[3])*scale).abs()
	box.position += origin
	return box

func _action_rects(source_id: int, frame: int) -> Array[Rect2]:
	var crt_one := int(player.definition.source_crt) == 1
	if crt_one and player.state == "skill_t":
		var authored: Array[Rect2] = []
		for window: Dictionary in player.definition.actions.skill_t.get("windows",[]):
			if frame >= int(window.from) and frame <= int(window.until):
				for rect: Rect2 in window.get("local_rects",[]):authored.append(player.transform_rect(rect))
		return authored
	var source_data: Dictionary = database.assets.source_geometry.act03_crt1_hit_windows if crt_one else database.assets.source_geometry.act02_hit_windows
	var timeline: Dictionary = source_data.timelines.get(str(source_id),{})
	var rows: Array = timeline.get("active_by_source_frame",{}).get(str(frame),[])
	var result: Array[Rect2] = []
	var animation: String = str(player.definition.actions[player.state].animation)
	var placements: Dictionary = database.assets.source_geometry.act03_crt1_actions if crt_one else database.assets.source_geometry.default_skill_actions
	var placement: Array = placements[animation].parent_matrix
	if crt_one and player.state == "skill_v":
		var component := _crt1_component("grab")
		rows = component.timeline.get(str(frame),[])
		placement = component.parent_matrix
	for row: Dictionary in rows:
		var r: Array = row.rect
		result.append(player.transform_rect(Rect2(r[0]+placement[4],r[1]+placement[5],r[2],r[3])))
	return result

func _spawn_summon(kind: String) -> void:
	var key := "crt0_runner_wait" if kind == "runner" else ("summon_mine_right" if player.facing > 0 else "summon_mine_left")
	var depth := _next_root_depth if kind == "runner" else -16300
	if kind == "runner":_next_root_depth += 1
	if kind == "fire_floor":key = "crt0_fire_floor";depth = -16268
	if not database.assets.animations.has(key):
		push_error("派生对象资源尚未登记："+kind+" / "+key)
		return
	_replace_root_depth(depth)
	var sprite := Visual.new()
	add_child(sprite)
	sprite.configure(database.assets.animations[key])
	sprite.position = player.position
	sprite.z_index = clampi(depth+16384,-4096,4096)
	if kind == "fire_floor":
		sprite.position.y += 30
		sprite.scale.x = player.facing
		sprite.visible = false #1513 f1 has not placed child1503 yet.
	var item := {"kind":kind,"key":key,"depth":depth,"visual":sprite,"frame":1,"child":1,"born":int(session.run.source_ticks),"wait":0,"facing":player.facing,"seen_frames":{}}
	summons.append(item)
	_sort_dynamic_root_views()
	_record("summon_spawn",{"kind":kind,"depth":depth,"position":[sprite.position.x,sprite.position.y]})

func _advance_summons() -> void:
	for item: Dictionary in summons.duplicate():
		if int(item.born) == int(session.run.source_ticks):continue
		if item.kind == "runner":
			if int(item.frame) == 1:
				item.child += 1
				for target: Node2D in enemies:
					if target.hp > 0:
						if target.position.x > item.visual.position.x:_source_shift_x(item.visual,2.0)
						if target.position.x < item.visual.position.x:_source_shift_x(item.visual,-2.0)
				var detector: Array = database.assets.source_geometry.act02_hit_windows.wait_detectors.runner.rect
				if int(item.child) >= 150:_runner_blast(item,10)
				elif enemies.any(func(e:Node2D)->bool:return _overlaps(_world_rect(detector,item.visual.position),e.hurt_rect())):_runner_blast(item,2)
				else:item.visual.set_source_frame(int(item.child))
			elif int(item.frame) < 17:
				item.frame += 1
				if int(item.frame) < 10:
					if player.position.x > item.visual.position.x:_source_shift_x(item.visual,2.0)
					if player.position.x < item.visual.position.x:_source_shift_x(item.visual,-2.0)
				item.visual.set_source_frame(int(item.frame))
			_summon_windows(item,1108,-5.0)
		elif item.kind == "mine":
			if int(item.frame) < 23:item.frame += 1
			elif int(item.frame) == 23:
				item.wait += 1
				var detector: Dictionary = database.assets.source_geometry.act02_hit_windows.wait_detectors["mine_right" if int(item.facing) > 0 else "mine_left"]
				if int(item.wait) >= 229 or enemies.any(func(e:Node2D)->bool:return _overlaps(_world_rect(detector.frames1_to229.rect,item.visual.position),e.hurt_rect())):item.frame = 24
			elif int(item.frame) < 37:item.frame += 1
			item.visual.set_source_frame(int(item.frame))
			_summon_windows(item,613 if int(item.facing) > 0 else 603,-8.0)
		elif item.kind == "fire_floor":
			item.frame += 1
			if int(item.frame) >= 180:
				for spark: Dictionary in item.get("sparks",[]):spark.visual.queue_free()
				item.visual.queue_free()
				summons.erase(item)
			else:
				var child_frame := (int(item.frame)-2)%29+1
				item.visual.visible = true
				item.visual.set_source_frame(child_frame)
				item.visual.modulate.a = (float({3:131,4:189}.get(int(item.frame),236))/256.0) if int(item.frame) >= 3 else 1.0
				item.child = child_frame
				_advance_fire_sparks(item)
				_summon_windows(item,1503,-5.0)
		elif item.kind == "ammo_fire":
			item.frame = (3 if item.route == "a" else 27) if int(item.frame) == 1 else mini(10 if item.route == "a" else 34,int(item.frame)+1)
			item.visual.visible = true
			item.visual.set_source_frame(int(item.frame))
			if int(item.frame) in [4,8,28,32]:_summon_windows(item,731,-5.0)
		var audio_frame: int = int(item.child) if item.kind == "fire_floor" else int(item.frame)
		if int(item.get("audio_frame",-1)) != audio_frame:
			_play_source_audio(item.key,audio_frame)
			item["audio_frame"] = audio_frame

func _runner_blast(item: Dictionary, frame: int) -> void:
	item.frame = frame
	item.key = "crt0_runner_blast"
	item.visual.configure(database.assets.animations.crt0_runner_blast)
	item.visual.set_source_frame(frame)
	_record("runner_blast",{"frame":frame,"depth":item.depth})

func _advance_fire_sparks(item: Dictionary) -> void:
	if not item.has("sparks"):item["sparks"] = []
	for spark: Dictionary in item.sparks:
		spark.frame = mini(8,int(spark.frame)+1)
		spark.visual.set_source_frame(int(spark.frame))
	var data: Dictionary = database.assets.source_geometry.crt0_fire_floor.spark
	for placement: Dictionary in data.created_by_parent_source_frame.get(str(item.frame),[]):
		var sprite := _new_source_visual("crt0_fire_spark",self)
		sprite.transform = Transform2D(Vector2(item.facing,0),Vector2(0,1),item.visual.position)*_matrix(placement.matrix)
		sprite.z_index = item.visual.z_index+1
		item.sparks.append({"visual":sprite,"frame":1})

func _summon_windows(item: Dictionary, source_id: int, gravity: float) -> void:
	# Freshly placed helper receives Load, not EnterFrame, on10/30.
	if (source_id == 1108 and int(item.frame) == 10) or (source_id in [613,603] and int(item.frame) == 30):return
	var timeline: Dictionary = database.assets.source_geometry.act02_hit_windows.timelines[str(source_id)]
	var frame: int = int(item.child) if source_id == 1503 else int(item.frame)
	if source_id == 1503 and frame == 1:return
	var rows: Array = timeline.active_by_source_frame.get(str(frame),[])
	for row: Dictionary in rows:
		var local := Rect2(row.rect[0],row.rect[1],row.rect[2],row.rect[3])
		if source_id == 1503:
			var m: Array = database.assets.source_geometry.default_skill_actions.crt0_fire_floor.parent_matrix
			local = Transform2D(Vector2(m[0],m[1]),Vector2(m[2],m[3]),Vector2(m[4],m[5]))*local
		var box := _world_rect([local.position.x,local.position.y,local.size.x,local.size.y],item.visual.position,Vector2(int(item.facing) if source_id == 1503 else 1,1))
		_active_boxes.append(box)
		for target: Node2D in enemies:
			if target.hp > 0 and _overlaps(box,target.hurt_rect()):
				if source_id == 1503 and target.frozen:
					_frozen_hit(target,2)
					target.clear_freeze() #1513's separate normal-return observer.
					target.set_action("move")
				else:_lift_target(player,target,gravity,"summon "+str(item.kind),source_id != 1503)
				if item.kind == "mine":_set_enemy_status(target,"stun")

func _grenade_window(kind: String) -> void:
	var frame: int = player.source_frame
	if frame in [9,11,13,127,129,131,189,191,193]:return #New flight helper only receives Load.
	var destinations: Dictionary = {"f":{128:148,130:159,132:170},"g":{190:211,192:222,194:233},"h":{10:44,12:69,14:94}}[kind]
	var boxes := _action_rects(4744,frame)
	for target: Node2D in enemies:
		if target.hp <= 0:continue
		for box: Rect2 in boxes:
			_active_boxes.append(box)
			if not _overlaps(box,target.hurt_rect()):continue
			if destinations.has(frame):
				player.seek_action_frame(int(destinations[frame]))
				_grenade_window(kind) #Root H freeze observer sees the newly placed blast now.
				_record("grenade_early_contact",{"grenade":kind,"from":frame,"to":destinations[frame]})
				return
			if kind == "h":
				_freeze_target(target)
				if frame in range(95,98):
					target.freeze_frame = 1
					_frozen_hit(target,2)
				elif frame in range(20,22) or frame in range(45,47) or frame in range(70,72):target.freeze_frame = 1
			elif frame not in [137,148,159,170,199,211,222,233]:
				var tail := frame in [158,169,180,221,232,243]
				_lift_target(player,target,-10.0 if kind == "f" or tail else -8.0,"grenade "+kind,false)
				if kind == "g" and not tail:_set_enemy_status(target,"shock")
	if kind == "h":
		for target: Node2D in enemies:
			if target.frozen and target.freeze_frame == 5:
				var amount := 50.0 if (frame in range(20,22) or frame in range(45,47) or frame in range(70,72)) else 30.0
				deal_damage(player,target,amount,"H frozen outer5 observer",false)

func _play_source_audio(key: String, frame: int) -> void:
	for sound: String in database.assets.audio_events:
		if sound != key and not sound.begins_with(key+"_sound_"):continue
		var event: Dictionary = database.assets.audio_events[sound]
		if int(event.get("frame",-1)) == frame:audio.play_sfx(sound,float(event.get("in_point_samples_44100",0))/44100.0)

func _source_matrix_rect(actor: Node2D, rect: Array, matrix: Array, offset := Vector2.ZERO, direction := 0) -> Rect2:
	var transform := Transform2D(Vector2(matrix[0],matrix[1]),Vector2(matrix[2],matrix[3]),Vector2(matrix[4],matrix[5])+offset)
	var local := transform*Rect2(rect[0],rect[1],rect[2],rect[3])
	if direction == 0:return actor.transform_rect(local)
	var at: Vector2 = local.position*actor.visual_scale
	var size: Vector2 = local.size*actor.visual_scale
	if direction < 0:at.x = -at.x-size.x
	return Rect2(actor.position+at,size)

func _restart_z_interval() -> void:
	_z_direction = player.facing
	_z_interval_id += 1
	_z_interval_active = true
	_z_interval_next = real_time_ms+10.0
	_z_timeouts.append({"due":real_time_ms+500.0,"origin":_z_interval_id})
	_record("z_interval_created",{"id":_z_interval_id,"ms":real_time_ms})

func advance_real_time(delta: float) -> void:
	if paused or ended or not is_finite(delta) or delta <= 0:return
	if is_instance_valid(player) and int(player.definition.source_crt)==4:
		_crt4_advance_ms(delta)
		return
	var target_time := real_time_ms+delta*1000.0
	while true:
		var next: float = _z_interval_next if _z_interval_active else INF
		if not _z_timeouts.is_empty():next = minf(next,float(_z_timeouts[0].due))
		if next > target_time+0.000001:break
		real_time_ms = next
		if not _z_timeouts.is_empty() and float(_z_timeouts[0].due) <= next+0.000001:
			var timeout: Dictionary = _z_timeouts.pop_front()
			_z_interval_active = false
			_record("z_interval_cleared",{"origin_timeout":timeout.origin,"cleared_current_id":_z_interval_id,"ms":real_time_ms})
		elif _z_interval_active:
			for enemy: Node2D in enemies:
				if enemy.gravity_acceleration > 0:
					enemy.position.x = Actor.twips(Actor.source_coordinate(enemy.position.x)+3.0*_z_direction)
			_z_interval_next += 10.0
			_record("z_interval_tick",{"id":_z_interval_id,"ms":real_time_ms})
	real_time_ms = target_time

func _clear_ms_jobs() -> void:
	_z_interval_active = false
	_z_timeouts.clear()
	_crt4_fly.active=false;_crt4_fly.timeouts.clear()

func _crt4_object_part(item: Dictionary,key: String,host: int,f: int,child: int,sub: int,part: String,outer:=Transform2D.IDENTITY) -> void:
	var row:=_crt4_placement(host,f,child)
	if row.is_empty():
		_crt4_hide("world_%d_%s"%[int(item.id),part]);return
	var alpha:=float(row.get("alpha_mult",row.get("color_transform",{}).get("alphaMultTerm",256)))
	_crt4_emit_audio("world%d_"%int(item.id)+part,child,sub)
	_crt4_object_view(item,key,sub,outer*_matrix(row.matrix),part,alpha)
func _crt4_field(item: Dictionary) -> void:
	var sid:=int(item.source_id);var f:=int(item.frame)
	var spec:=_crt4_component(str(sid))
	if f==int(spec.flag_on_frame):crt4[str(spec.flag)]=1;crt4.fields[str(sid)]=true;item["activated"]=true
	if bool(item.get("activated",false)) and int(crt4[str(spec.flag)])==0:item.frame=int(spec.clear_frame);f=int(item.frame)
	if spec.has("ghost_select_frame") and f==int(spec.ghost_select_frame):crt4.ghost_type=int(spec.ghost_value)
	if f==int(spec.clear_frame):
		crt4[str(spec.flag)]=0
		crt4.fields[str(sid)]=false
		for id: String in _crt4_views.keys():
			if id.begins_with("world_%d_"%int(item.id)):_crt4_hide(id)
		return
	var child: int={316:313,956:954,818:816,1121:1120}[sid]
	var letter: String={316:"d",956:"f",818:"g",1121:"h"}[sid]
	var row:=_crt4_placement(sid,f,child)
	if row.is_empty():return
	var outer:=_matrix(row.matrix)
	_crt4_object_part(item,"crt4_field_"+letter+"_base",sid,f,child,1,"base")
	var phase:=f if f<9 else f-8
	if sid==1121:phase=f-9
	if sid==316 and f==539:phase=1
	var local_frame:=phase
	if child==816:local_frame=(phase-1)%29+1
	if child==1120:local_frame=(phase-1)%99+1
	var inner: int={313:312,954:953,816:813,1120:1117}[child]
	var length: int={312:12,953:13,813:12,1117:13}[inner]
	_crt4_object_part(item,"crt4_field_"+letter+"_loop",child,local_frame,inner,(phase-1)%length+1,"loop",outer)
	_crt4_windows(sid,f,item.visual.transform,"world"+str(item.id),item)
	if child in [816,1120]:_crt4_windows(child,local_frame,item.visual.transform*outer,"world"+str(item.id),item)
func _crt4_flight(item: Dictionary) -> void:
	var sid:=int(item.source_id)
	if int(item.frame)==1:
		if int(item.born)!=int(session.run.source_ticks):
			item.position+=Vector2((20 if sid==1326 else 12)*float(item.scale.x),0 if sid==1326 else 7)
			item.visual.position=item.position
		var helper:=_crt4_placement(sid,1,1151)
		var impact:=false
		if not helper.is_empty():
			var definition: Dictionary=_crt4_component(str(sid)).world_semantics.flight.helper
			# The transparent1151 helper wraps1150; its original bounds are stored
			# on the imported component geometry, never inferred from PNG alpha.
			var rows: Array=[definition.shape_rect]
			for raw: Array in rows:
				var box: Rect2=item.visual.transform*_matrix(helper.matrix)*Rect2(raw[0],raw[1],raw[2],raw[3])
				for enemy: Node2D in enemies:
					if _overlaps(box,_crt4_normal_rect(enemy)) or enemy.frozen and _overlaps(box,enemy.hurt_rect()):impact=true
				if sid==1154:
					var ground: Array=stage.ground_rect
					if _overlaps(box,Rect2(ground[0],ground[1],ground[2],ground[3])):impact=true
		if sid==1326 and int(item.age)>27:impact=true
		if impact:
			item.frame=2;item.phase_born=int(session.run.source_ticks)
			_crt4_hide("world_%d_flight"%int(item.id))
		else:
			_crt4_object_part(item,"crt4_clone_flight"if sid==1326 else"crt4_clone_diagonal_flight",sid,1,1149,(int(item.age)-1)%9+1,"flight")
	if int(item.frame)==2:
		var sub:=mini(8,int(session.run.source_ticks)-int(item.phase_born)+1)
		_crt4_object_part(item,"crt4_clone_hit"if sid==1326 else"crt4_clone_diagonal_hit",sid,2,1153,sub,"impact")
		var row:=_crt4_placement(sid,2,1153)
		if not row.is_empty():_crt4_windows(1153,sub,item.visual.transform*_matrix(row.matrix),"world"+str(item.id),item)
func _crt4_swamp(item: Dictionary) -> void:
	var f:=int(item.frame)
	#932 placements retain independent source clocks when944 stops at20.
	var tracks: Array=_crt4_component("944").placement_tracks
	var rows: Array=[]
	for change: Dictionary in tracks:
		if int(change.source_frame)>f:break
		rows=change.placements
	if not item.has("cells"):item["cells"]={}
	for row: Dictionary in rows:
		if int(row.source_id)!=932:continue
		var id:=str(int(row.depth))
		if not item.cells.has(id):item.cells[id]=int(session.run.source_ticks)
		var sub:=mini(10,int(session.run.source_ticks)-int(item.cells[id])+1)
		_crt4_object_view(item,"crt4_y_swamp_cell",sub,_matrix(row.matrix),"cell"+id)
	if f==20 and not item.has("swamp"):
		var row:=_crt4_placement(944,20,943)
		if row.is_empty():return
		var mat: Transform2D=item.visual.transform*_matrix(row.matrix)
		item["swamp"]=_crt4_spawn(943,mat.origin,item.scale,item.depth,false)
		item.swamp.visual.transform=mat
		item.swamp["parent_id"]=item.id;item.swamp["source_parent"]=944;item.swamp["swamp_position"]=item.position
func _crt4_y_controller(item: Dictionary) -> void:
	var f:=int(item.frame)
	if f==35:
		if not item.has("timer"):item["timer"]=_crt4_flag_count()*8;item["wisp_born"]=int(session.run.source_ticks)
		else:item.timer+=1
		if int(item.timer)>=40:item.frame=38;f=38
	if f>=1:
		var rows: Array=[]
		for change: Dictionary in _crt4_component("943").placement_tracks:
			if int(change.source_frame)>f:break
			rows=change.placements
		var active_wisps: Array[String]=[]
		for row: Dictionary in rows:
			if int(row.source_id)!=942:continue
			if not item.has("wisps"):item["wisps"]={}
			var slot:=str(int(row.depth))
			active_wisps.append("world_%d_wisp%s"%[int(item.id),slot])
			if not item.wisps.has(slot):item.wisps[slot]=int(session.run.source_ticks)
			var sub:=(int(session.run.source_ticks)-int(item.wisps[slot]))%21+1
			var alpha:=float(row.get("color_transform",{}).get("alphaMultTerm",256))
			_crt4_object_view(item,"crt4_y_wisp",sub,_matrix(row.matrix),"wisp"+slot,alpha)
			for command: Dictionary in _crt4_component("942").screen_displacements:
				if int(command.frame)!=sub:continue
				if command.has("dx"):position.x+=float(command.dx)
				if command.has("dy"):position.y+=float(command.dy)
				if command.has("set_x"):position.x=float(command.set_x)
				if command.has("set_y"):position.y=float(command.set_y)
		for id: String in _crt4_views.keys():
			if id.begins_with("world_%d_wisp"%int(item.id)) and id not in active_wisps:_crt4_hide(id)
	if f==65 and not item.has("beast"):
		item["beast"]=_crt4_spawn(907,item.get("swamp_position",item.position)+Vector2(0,100),Vector2(1.5*signf(item.scale.x),1.5))
		item.beast["parent_id"]=item.id;item.beast["source_parent"]=943
func _crt4_advance_objects() -> void:
	var tick:=int(session.run.source_ticks)
	for item: Dictionary in _crt4_objects.duplicate():
		# Earlier helpers in this same callback pass can replace an original
		# root depth. A snapshot entry must not resurrect the retired child.
		if item not in _crt4_objects:continue
		var sid:=int(item.source_id)
		if int(item.born)!=tick:
			item.age+=1
			var hold: Array={944:[20,21],943:[35,111],978:[19,200],1326:[1,2],1154:[1,2],3963:[1,2],3962:[20],3951:[1],3971:[1,2,3,4]}.get(sid,[])
			var maximum:=int(_crt4_component(str(sid)).get("source_frame_count",1))
			if sid==907:maximum=40
			if int(item.frame) not in hold:
				item.frame=1 if sid==3951 and int(item.frame)==maximum else mini(maximum,int(item.frame)+1)
			_crt4_emit_audio("root"+str(item.id),sid,int(item.frame))
		item.visual.position=item.position
		if sid in [316,956,818,1121]:_crt4_field(item)
		elif sid in [1326,1154]:_crt4_flight(item)
		elif sid==944:_crt4_swamp(item)
		elif sid==943:_crt4_y_controller(item)
		elif sid==907:
			var f:=int(item.frame)
			var row:=_crt4_placement(907,1,906)
			if not row.is_empty():
				_crt4_emit_audio("beast"+str(item.id),906,f)
				_crt4_object_view(item,"crt4_y_beast",f,_matrix(row.matrix))
				_crt4_windows(906,f,item.visual.transform*_matrix(row.matrix),"world"+str(item.id),item)
			if f==40 and not item.get("slot_released",false):crt4.y_slot_frame=2;crt4.y_slot_playing=true;item["slot_released"]=true
		elif sid==1273:
			_crt4_object_view(item,"crt4_tombstone",int(item.frame))
			_crt4_windows(sid,int(item.frame),item.visual.transform,"world"+str(item.id),item)
			if int(item.frame)==5:position.y+=3
			elif int(item.frame)==6:position.y-=6
			elif int(item.frame)==7:position.y=0
		elif sid==578:_crt4_object_view(item,"crt4_dark_hit",int(item.frame))
		elif sid==978:
			if int(item.frame)>=19 and int(crt4.rhasa)==0:item.frame=200
			if is_instance_valid(item.get("target")):item.position=item.target.position;item.visual.position=item.position
			_crt4_object_view(item,"crt4_mummy",int(item.frame))
			_crt4_windows(sid,int(item.frame),item.visual.transform,"world"+str(item.id),item)
			if int(item.frame)<=19:_crt4_object_part(item,"crt4_mummy_birth",978,int(item.frame),556,mini(10,int(item.age)),"birth")
			if int(item.frame)>=27 and int(item.frame)<=199:
				for target: Node2D in enemies:
					if int(_crt4_bleeds.get(target.identifier,{}).get("frame",0))==1:_crt4_observe(978,975,int(item.frame),target,1)
		elif sid in [3951,3962,3963,3971,3968,3969,3970]:_crt4_advance_target(item)
	_crt4_settle_layers()
func _crt4_advance_target(item: Dictionary) -> void:
	var target: Node2D=item.get("target")
	if not is_instance_valid(target):return
	item.position=target.position;item.visual.position=item.position
	var sid:=int(item.source_id);var f:=int(item.frame)
	item.visual.transform=_crt4_status_mat(target,3971 if sid in [3968,3969,3970]else 3963 if sid==3962 else sid)
	if sid==3951:
		_crt4_object_view(item,"crt4_q_status",f)
		_crt4_persistent_observers(sid,f)
	elif sid==3962:
		var placed:=_crt4_placement(3963,2,3962)
		if not placed.is_empty():_crt4_object_view(item,"crt4_ghostslash_status",f,_matrix(placed.matrix))
		if f==16 and not item.has("faces"):
			item["faces"]=enemies.map(func(enemy:Node2D)->int:return enemy.source_facing()*100)
		if f==20 and not item.get("launched",false):
			item["launched"]=true
			for victim: Node2D in enemies:
				if bool(crt4.get("marked_"+victim.identifier,false)):_start_marker(player,victim,-8,"CRT4 E global3962 callback")
			if _crt4_fly.active:_record("crt4_fly_interval_cleared",{"cleared_current_id":_crt4_fly.id,"ms":real_time_ms,"reason":"replacement"})
			_crt4_fly.active=false
			if player.parent_frame!=175:
				var spec:=_crt4_component("3962")
				zab="";_crt4_fly.id+=1;_crt4_fly.active=true;_crt4_fly["interval_ms"]=float(spec.timer_interval_ms)
				_crt4_fly.next=real_time_ms+float(spec.timer_interval_ms)
				_crt4_fly.faces=item.get("faces",[]).duplicate();_crt4_fly.timeouts.append({"due":real_time_ms+float(spec.timer_timeout_ms),"origin":_crt4_fly.id})
				_record("crt4_fly_interval_created",{"id":_crt4_fly.id,"ms":real_time_ms,"delay_ms":float(spec.timer_interval_ms),"timeout_ms":float(spec.timer_timeout_ms)})
			# Source3962/20 ends with _parent.gotoAndStop(1), removing this
			# child while the root millisecond interval/timeout keep running.
			for owner: Dictionary in _crt4_objects:
				if int(owner.source_id)==3963 and owner.get("target")==target:owner.frame=1
			_crt4_retire(item,"source3962 resets3963 to1")
	elif sid in [3968,3969,3970]:
		var outer:=_crt4_placement(3971,4,sid)
		if not outer.is_empty():_crt4_object_part(item,"crt4_clone_status",sid,f,1149,(int(item.age)-1)%9+1,"layer",_matrix(outer.matrix))
		for event: Dictionary in _crt4_component(str(sid)).get("damage_events",[]):
			if f==int(event.frame):
				combo+=1;combo_frame=2
				deal_damage(player,target,float(event.damage),"CRT4 Kalla layer "+str(sid),false);_crt4_spawn(578,target.position,Vector2.ONE,_next_root_depth)
func _crt4_advance_ms(delta: float) -> void:
	var target_time:=real_time_ms+delta*1000
	while true:
		var next: float=float(_crt4_fly.next)if _crt4_fly.active else INF
		if not _crt4_fly.timeouts.is_empty():next=minf(next,float(_crt4_fly.timeouts[0].due))
		if next>target_time+0.000001:break
		real_time_ms=next
		if not _crt4_fly.timeouts.is_empty() and float(_crt4_fly.timeouts[0].due)<=next+0.000001:
			var timeout: Dictionary=_crt4_fly.timeouts.pop_front();_crt4_fly.active=false
			_record("crt4_fly_interval_cleared",{"origin_timeout":timeout.origin,"cleared_current_id":_crt4_fly.id,"ms":real_time_ms,"reason":"timeout"})
		elif _crt4_fly.active:
			for index in range(enemies.size()):
				if enemies[index].gravity_acceleration>0 and index<_crt4_fly.faces.size():_source_shift_x(enemies[index],-0.05*float(_crt4_fly.faces[index]))
			_crt4_fly.next+=float(_crt4_fly.interval_ms)
			_record("crt4_fly_interval_fired",{"id":_crt4_fly.id,"ms":real_time_ms})
	real_time_ms=target_time

func _exit_tree() -> void:
	_clear_ms_jobs()

func _observe_marker_two(marker: Dictionary, preview := true) -> void:
	var target: Node2D = marker.target
	var phase_step := 1 if preview else 0
	marker["processed_tick"] = int(session.run.source_ticks)
	combo += 1
	combo_frame = 2
	_record("hit_combo",{"count":combo,"target":target.identifier})
	var damage := 5.0
	for statuses: Dictionary in enemy_status.values():
		if statuses.has("silver"):damage += 13.0
	if enemy_status.get(target.identifier,{}).has("shock"):damage += 8.0
	if player.state == "throw_f" and player.source_frame+phase_step >= 137:
		var next: int = player.source_frame+phase_step
		if next not in [147,180]:damage += 20.0 if next in [158,169] else 75.0
	if player.state == "throw_g" and player.source_frame+phase_step >= 199:
		var next: int = player.source_frame+phase_step
		if next not in [210,243]:damage += 25.0 if next in [221,232] else 50.0
	# Conditional helper reads the current player action, not projectile identity.
	if int(player.definition.source_crt) == 0 and player.state == "skill" and player.source_frame >= 8 and player.source_frame <= 18:
		damage += 70.0
	if int(player.definition.source_crt) == 0 and player.state == "skill_r" and player.source_frame+phase_step >= 26 and player.source_frame+phase_step <= 42:damage += 95.0
	var action: Dictionary = player.definition.actions[player.state]
	if action.has("marker_bonus") and player.source_frame >= int(action.get("marker_bonus_from",1)) and player.source_frame <= int(action.get("marker_bonus_until",2000)):
		damage += float(action.marker_bonus)
	if int(player.definition.source_crt) == 1:
		if int(crt1.buff_frame) >= 9:damage += float(_crt1_component("buff").marker2_extra_damage)
		if player.state == "skill_w":damage += float(_crt1_component("moving_fire").marker2_bonus)
	if int(player.definition.source_crt) == 2:damage += _crt2_marker_bonus(target,player.source_frame+phase_step)
	if int(player.definition.source_crt) == 3:damage += _crt3_marker_bonus(target,player.source_frame+phase_step)
	for item: Dictionary in summons:
		var next_frame := int(item.frame)+phase_step
		if item.kind == "runner" and next_frame in [11,12]:damage += 70.0
		if item.kind == "mine" and next_frame in [31,32]:damage += 80.0
		if item.kind == "fire_floor" and int(item.frame)+phase_step < 180 and ((int(item.child)-1+phase_step)%29+1) in [2,3]:damage += 10.0
		if item.kind == "ammo_fire" and int(item.frame)+phase_step in [3,4,7,8,27,28,31,32]:damage += 3.0
	if not (player.state == "detonate" and player.source_frame+phase_step >= 20):
		for entry: Dictionary in c4_targets.values():
			if bool(entry.exploding):damage += 60.0*int(entry.count)
	deal_damage(marker.owner,target,damage,"air marker2 base5 + active helper",false)

func _advance_markers() -> void:
	for identifier: String in _markers.keys():
		var marker: Dictionary = _markers[identifier]
		var target: Node2D = marker.target
		if target.hp <= 0:
			_markers.erase(identifier)
			continue
		if int(marker.age) == 0:
			_observe_marker_two(marker)
		elif int(marker.age) == 1:
			if bool(marker.get("stopped_two",false)) and not target.air_marker_stopped:
				_markers.erase(identifier)
				continue
			if int(player.definition.source_crt) == 0:
				deal_damage(marker.owner,target,10.0,"persistent3835 crt==0 OR expression",false)
			if bool(marker.get("stopped_two",false)) and target.air_marker_stopped:
				marker["processed_tick"] = int(session.run.source_ticks)
				marker["pending_stopped_base"] = true
				continue
			_markers.erase(identifier)
			continue
		marker.age += 1

func _finish_stopped_markers() -> void:
	for marker: Dictionary in _markers.values():
		if not bool(marker.get("pending_stopped_base",false)):continue
		marker.erase("pending_stopped_base")
		if marker.target.air_marker_stopped:_observe_marker_two(marker,false)

func deal_damage(attacker: Node2D, target: Node2D, amount: float, source: String, reaction := true) -> bool:
	if ended or target.hp <= 0:
		return false
	if target.team == "enemy" and target.hp <= amount and _crt1_t_touches(target):
		target.source_death_locked = true
		crt1.t_kill = true
	if not target.receive_damage(amount,reaction):
		return false
	_record("damage",{"attacker":attacker.identifier,"target":target.identifier,"amount":amount,"hp":target.hp,"source":source})
	return true

func _end(outcome: String) -> void:
	if ended:
		return
	if source_feedback.has("cutin"):
		source_feedback.cutin.visual.queue_free()
		source_feedback.erase("cutin")
	ended = true
	_clear_ms_jobs()
	for item: Dictionary in summons:
		for spark: Dictionary in item.get("sparks",[]):spark.visual.queue_free()
		item.visual.queue_free()
	summons.clear()
	if not _y_summon.is_empty():
		_y_clear_phase_nodes(_y_summon)
		_y_summon.phase = 1
		_y_summon.bk = false
	sniper.root = 1
	_render_sniper()
	_clear_c4()
	_grenade_loads.clear()
	ammo_frames = {"fire":1,"silver":1}
	for bullet: Dictionary in projectiles:
		bullet.visual.queue_free()
	projectiles.clear()
	_markers.clear()
	for item: Dictionary in _gunhawks:item.visual.queue_free()
	_gunhawks.clear()
	_crt1_hide_views("")
	for shot: Dictionary in _crt1_shots.values():
		if is_instance_valid(shot.get("visual")):shot.visual.queue_free()
	_crt1_shots.clear()
	_nested_audio.clear()
	_crt2_clear()
	_crt3_clear()
	_crt4_clear()
	_presses.clear()
	_key_events.clear()
	if session.finish(outcome) and not is_training():
		persistence_requested.emit()
	_record("finished",{"outcome":outcome})
	finished.emit(outcome)

func set_paused(value: bool) -> void:
	paused = value
	_presses.clear()
	_key_events.clear()
	clock.reset()

func toggle_debug() -> void:
	debug_draw = not debug_draw
	player.debug_draw = debug_draw
	for enemy: Node2D in enemies:
		enemy.debug_draw = debug_draw
	queue_redraw()

func snapshot() -> Dictionary:
	return {"stage":session.run.get("stage_id",""),"hp":player.hp,"max_hp":player.definition.max_hp,"mp":player.mp,
		"crt4":crt4.duplicate(true),"crt3":crt3.duplicate(true),"crt1":crt1.duplicate(true),"gunhawks":_gunhawks.size(),
		"v":_v_trace.merged({"zab":zab,"pren":pren},true),
		"training":is_training(),"skill_bar_frame":skill_bar_frame,"bar_initialization_pending":bar_initialization_pending,
		"clear_cubes":session.profile.progress.get("clear_cubes",200),
		"skill_slots":skill_slots(),
		"grenades":grenades.duplicate(true),"ammo_frames":ammo_frames.duplicate(),"c4_count":c4_count,"c4_targets":c4_targets.duplicate(true),
		"combo":combo,"combo_frame":combo_frame,"summons":summons.size(),
		"max_mp":player.definition.max_mp,"state":player.state,"source_frame":player.source_frame,
		"position":[player.position.x,player.position.y],"facing":player.facing,"remaining":session.run.get("enemies_remaining",0),
		"ticks":session.run.get("source_ticks",0),"projectiles":projectiles.size(),"paused":paused,"ended":ended,
		"gold":session.profile.progress.gold,"skill_cooldown":player.skill_cooldown,"cooldowns":player.cooldowns.duplicate(),"character_id":session.run.character_id,
		"available_skills":player.definition.actions.keys(),"enemy_hp":enemies.map(func(e:Node2D)->float:return e.hp),
		"parent_frame":player.parent_frame,"body_frame":player.body_frame,"air_action_frame":player.air_action_frame,
		"child_x":player.action_child_x,"real_time_ms":real_time_ms,"z_interval_active":_z_interval_active,"z_timeouts":_z_timeouts.size()}

func skill_slots() -> Dictionary:
	var result := {}
	if skill_bar_frame == 7:return result
	var mapping := {"a":"skill_z","s":"skill_s","d":"skill","f":"load_f","g":"load_g","h":"load_h","q":"skill_q","t":"skill_t","e":"skill_e","r":"skill_r","y":"skill_y","v":"skill_v","w":"skill_w"}
	if int(player.definition.source_crt) in [1,2,3,4]:mapping = player.definition.get("skill_slot_actions",mapping)
	var geometry: Dictionary = database.assets.source_geometry.get("battle_hud_crt%d"%int(player.definition.source_crt),database.assets.source_geometry.battle_hud)
	for key: String in geometry.skills:
		var slot: Dictionary = geometry.skills[key]
		var action_id:=str(mapping.get(key,""))
		var action: Dictionary=player.definition.actions.get(action_id,{})
		var remaining := int(player.cooldowns.get(str(action.get("cooldown_key",action_id)),0))
		var total := int(slot.source_frame_count)
		var frame := total-remaining+1 if remaining > 0 else 1
		if key == "y":frame = _y_slot_frame
		if key == "t" and int(player.definition.source_crt) == 1:frame = int(crt1.t_slot_frame)
		if key == "r" and int(player.definition.source_crt) == 2:frame = int(crt2.r_slot_frame)
		if key == "e" and int(player.definition.source_crt) == 3:frame = int(crt3.e_slot_frame)
		if key == "y" and int(player.definition.source_crt) == 4:frame = int(crt4.y_slot_frame)
		result[key] = {"frame":frame,"ready":remaining == 0 and (key != "y" or not bar_initialization_pending) and (int(player.definition.source_crt)!=3 or player.definition.actions.has(mapping.get(key,""))),"remaining":remaining}
	return result

func _record(kind: String, values: Dictionary) -> void:
	var item := values.duplicate(true)
	item["event"] = kind
	item["tick"] = session.run.get("source_ticks",0)
	item["ms"] = real_time_ms
	journal.append(item)
	if trace_enabled and trace_events.size() < 30000:trace_events.append(item.duplicate(true))
	if journal.size() > 400:
		journal.pop_front()

func export_trace(path: String) -> Error:
	if not path.begins_with("user://") and not path.begins_with("res://artifacts/"):
		return ERR_INVALID_PARAMETER
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null:return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"source_fps":25,"godot":Engine.get_version_info(),"stage":stage.source_root_frame,"frames":trace_frames,"events":trace_events,"limits":{"frames":5000,"events":30000}},"\t"))
	file.close()
	return OK

func _vec(value: Array) -> Vector2:
	return Vector2(float(value[0]),float(value[1]))

func _draw() -> void:
	draw_rect(Rect2(0,0,550,400),Color("15251d"))
	if _background != null and authored_stage == null:
		var pivot: Array = _background_data.get("pivot",[0,0])
		var at := _vec(_background_data.stage_position) - Vector2(pivot[0],pivot[1])
		var r: Array = _background_data.region
		draw_texture_rect_region(_background,Rect2(at,Vector2(r[2],r[3])),Rect2(r[0],r[1],r[2],r[3]))
	if debug_draw:
		draw_line(Vector2(stage.bounds[0],float(stage.floor_y)),Vector2(stage.bounds[1],float(stage.floor_y)),Color.YELLOW)
		for box: Rect2 in _active_boxes:
			draw_rect(box,Color(1,0.25,0.3,0.75),false,1)


#4491 and its timeline-owned parts share this encounter and projectile chain.
const Y_SHOTS := {
	4423:{16:"root",25:"self",33:"root",42:"self",50:"root",59:"self",67:"root",76:"self"},
	4436:{6:"self",13:"root",20:"self",27:"root",34:"self"},
	4482:{4:"root"},4485:{4:"self"}
}
const Y_BONUS := {4433:35.0,4459:15.0,4483:15.0,4484:25.0}

func _y_find() -> Dictionary:
	return _y_summon

func _y_tick() -> int:
	return int(session.run.source_ticks)

func _y_matrix(value: Array) -> Transform2D:
	return Transform2D(Vector2(value[0],value[1]),Vector2(value[2],value[3]),Vector2(value[4],value[5]))

func _y_sort_local_display_list(node: Node2D) -> void:
	# Source depths are LOCAL display-list order. Adding child source depths as
	# Godot relative z would incorrectly put group3/child164 above siblingtimer108.
	var children: Array = node.get_children()
	children.sort_custom(func(a: Node, other: Node)->bool:return float(a.get_meta("y_draw_depth",16384)) < float(other.get_meta("y_draw_depth",16384)))
	for index in range(children.size()):node.move_child(children[index],index)

func _y_row(phase: int, id: int) -> Dictionary:
	for row: Dictionary in database.assets.source_geometry.y_summon.root_pages.get(str(phase),[]):
		if int(row.source_id) == id:return row
	return {}

func _y_initialize() -> void:
	assert(_y_find().is_empty(),"Only one original root4491 per Battle")
	var root := Node2D.new()
	add_child(root)
	var geometry: Dictionary = database.assets.source_geometry.y_summon
	var stage_key := "training" if is_training() else "root_%d" % int(stage.source_root_frame)
	var matrix: Array = stage.get("y_initial_matrix",geometry.root_initial_matrices_by_stage.get(stage_key,[]))
	assert(matrix.size() == 6,"No source4491 stage placement")
	root.transform = _y_matrix(matrix)
	# Root41 source4491 depth358. Other stage depth must come from its placement;
	# do not universally assert358 is an original depth on every stage.
	root.z_index = int(stage.source_depths.y)
	root.visible = int(player.definition.source_crt) == 0
	_y_summon = {"kind":"y","visual":root,"depth":int(stage.source_depths.y),
		"phase":1,"frame":1,"child":1,"born":_y_tick(),"phase_born":_y_tick(),
		"bk":false,"facing":1,"phase_age":1,"normal_frame":1,
		"group":"","group_node":null,"parts":[],"effects":[],"timer_visual":null,
		"pending_projectiles":[],"serial":0}

func _y_freeze_slot_after_activation() -> void:
	# 4078/533: accepted input consumes5 cubes/30MP in existing _try_skill,
	# enters actor24, and immediately gotoAndStop2 before source4812/25.
	_y_slot_frame = 2
	_y_slot_playing = false
	player.cooldowns["skill_y"] = 531

func _y_try_focus_keydown(snapshot: Dictionary) -> bool:
	var y := _y_find()
	if y.is_empty() or int(y.phase) != 2 or not bool(y.bk):return false
	# key-event snapshot must expose held Y; do not auto-trigger every 25Hz tick.
	if not bool(snapshot.get("skill_y",false)):return false
	if player.parent_frame not in [1,2,3,4,7,8,9,10,16] or player.mp < 0.0:return false
	# MP0, no cube cost, no cooldown check, no new initial Y slot transition.
	player.set_action("y_focus")
	_record("y_focus_started",{"source_host":4465,"mp":player.mp})
	return true

func _y_clear_phase_nodes(y: Dictionary) -> void:
	# Clear only timeline-owned nodes; keep root itself. Root-hosted AS dynamic
	# depth0 bullets are not children of group_node and are not silently converted
	# into fixed world projectiles. Self-hosted bullets die with their part host.
	if is_instance_valid(y.group_node):y.group_node.queue_free()
	if is_instance_valid(y.timer_visual):y.timer_visual.queue_free()
	for effect: Dictionary in y.effects:
		if is_instance_valid(effect.visual):effect.visual.queue_free()
	y.group_node = null
	y.timer_visual = null
	y.parts = []
	y.effects = []
	y.group = ""

func _y_set_phase(phase: int) -> void:
	var y := _y_find()
	assert(not y.is_empty())
	_y_clear_phase_nodes(y)
	y.phase = phase
	y.frame = phase # generic trace only, not phase age
	y.phase_age = 1
	y.phase_born = _y_tick()
	if phase == 2:y.bk = true
	if phase in [3,4]:y["pending_phase_control"] = phase
	y.normal_frame = 1
	y.serial += 1
	if phase == 2:
		_y_select_group(y,"normal")
		y.timer_visual = _new_source_visual("y_timer",y.visual)
		y.timer_visual.visible = false
		y.timer_visual.set_meta("y_draw_depth",108)
	elif phase == 3:
		_y_select_group(y,"focus")
	elif phase == 4:
		var exit_visual: Node2D = _new_source_visual("y_exit",y.visual)
		exit_visual.set_meta("y_draw_depth",1)
		# y_exit immediate parent offset already lives in atlas pivot.
		y.effects.append({"visual":exit_visual,"frame":1,"end":9,"exit":true})
		# Source thereisnospoon!=1 branch. If that source cheat is implemented,
		# its other branch sets533 STOP; do not repurpose unrelated debug flags.
	if phase in [2,4]:
		for row: Dictionary in database.assets.source_geometry.y_summon.root_pages[str(phase)]:
			if int(row.source_id) != 4472:continue
			var visual: Node2D = _new_source_visual("y_spawn_fx",y.visual)
			visual.transform = _y_matrix(row.matrix) # this FX has NO baked offset
			visual.set_meta("y_draw_depth",int(row.depth))
			y.effects.append({"visual":visual,"frame":1,"end":7,"exit":false})
	_y_sort_local_display_list(y.visual)
	_record("y_phase",{"phase":phase,"root_x":y.visual.position.x,"slot":_y_slot_frame})
	if phase == 1:_y_follow_enter_frame()

func _y_phase_controls() -> void:
	var y := _y_find()
	if y.is_empty() or not y.has("pending_phase_control"):return
	var phase := int(y.pending_phase_control)
	y.erase("pending_phase_control")
	y.bk = false
	if phase == 4:
		#4491 DoAction runs after the original observer sees its new parent
		#page. Apply its queued slot2 before this tick's independent slot advance.
		_y_slot_frame = 2
		_y_slot_playing = true
		player.cooldowns["skill_y"] = 531

func _y_select_group(y: Dictionary, group: String) -> void:
	if y.group == group:return # goto2 while already walking retains its children
	if is_instance_valid(y.group_node):y.group_node.queue_free()
	y.parts = []
	y.group = group
	var data: Dictionary = database.assets.source_geometry.y_summon.groups[group]
	var outer := _y_row(int(y.phase),int(data.container_id))
	assert(not outer.is_empty())
	var container := Node2D.new()
	y.visual.add_child(container)
	container.transform = _y_matrix(outer.matrix)
	container.set_meta("y_draw_depth",int(outer.depth))
	y.group_node = container
	for definition: Dictionary in data.parts:
		var visual: Node2D = _new_source_visual(str(definition.animation),container)
		visual.set_meta("y_draw_depth",int(definition.depth)*2)
		# Visual already bakes immediate-parent offset in pivot. Collision and
		# attachMovie require a separate true local-coordinate host at full matrix.
		var host := Node2D.new()
		container.add_child(host)
		host.transform = _y_matrix(definition.matrix)
		host.set_meta("y_draw_depth",int(definition.depth)*2+1)
		y.parts.append({"definition":definition,"visual":visual,"host":host,
			"source_id":int(definition.source_id),"frame":1,"count":int(definition.frame_count),
			"born":_y_tick(),"helpers":{},"i_label":"undefined"})
		_play_source_audio(str(definition.animation),1)
	_y_sort_local_display_list(container)
	_y_sort_local_display_list(y.visual)

func _y_follow_enter_frame() -> void:
	var y := _y_find()
	if y.is_empty():return
	var root: Node2D = y.visual
	# Original property existence matters: do not substitute generic airborne.
	var jump_child_one: bool = player.parent_frame == 95 and player.air_action_frame == 1
	if int(y.phase) <= 2 and (player.parent_frame in [2,3] or jump_child_one):
		y.facing = player.facing
		root.scale.x = absf(root.scale.x)*int(y.facing)
	if int(y.phase) == 2:
		var detector: Dictionary = database.assets.source_geometry.y_summon.move_detector
		var bounds: Dictionary = detector.shape_bounds_twips
		var local := Rect2(float(bounds.Xmin)/20.0,float(bounds.Ymin)/20.0,
			(float(bounds.Xmax)-float(bounds.Xmin))/20.0,(float(bounds.Ymax)-float(bounds.Ymin))/20.0)
		var placement := _y_row(2,4415)
		var box: Rect2 = root.transform*_y_matrix(placement.matrix)*local
		# Battle-local rect coordinates match existing player.gravity_rect().
		if _overlaps(player.gravity_rect(),box):
			if player.position.x > root.position.x:_source_shift_x(root,5.0)
			if player.position.x < root.position.x:_source_shift_x(root,-5.0)
			# Second original callback re-evaluates hitTest AFTER the first moved.
			box = root.transform*_y_matrix(placement.matrix)*local
			if _overlaps(player.gravity_rect(),box):
				_y_select_group(y,"walk")
				y.normal_frame = 2
				y["normal_seek_tick"] = int(session.run.source_ticks)
	if int(y.phase) == 1:
		if player.position.x > root.position.x:_source_shift_x(root,20.0)
		if player.position.x < root.position.x:_source_shift_x(root,-20.0)
	# Both direction statements are independent; near-target overshoot can cancel.
	# Source never follows player Y, never clamps root X here, and phase3/4 lacks4415.

func _y_advance_after_actor() -> void:
	var y := _y_find()
	if y.is_empty():return
	if player.parent_frame == 25 and player.source_frame == 38 and int(y.phase) == 4:
		player.set_action("idle")
	if int(y.phase) == 1 or int(y.phase_born) == _y_tick():return
	y.phase_age += 1
	if (int(y.phase) == 2 and int(y.phase_age) >= 292) or (int(y.phase) == 3 and int(y.phase_age) >= 81):
		_y_set_phase(4)
		return
	if int(y.phase) == 4 and int(y.phase_age) >= 9:
		_y_set_phase(1)
		return
	if int(y.phase) == 2:
		if int(y.get("normal_seek_tick",-1)) != int(session.run.source_ticks):
			if int(y.normal_frame) == 2:y.normal_frame = 3
			elif int(y.normal_frame) == 3:
				y.normal_frame = 1
				_y_select_group(y,"normal")
		_y_timer_visual(y)
	for part: Dictionary in y.parts:
		if int(part.born) == _y_tick():continue
		part.frame = int(part.frame)%int(part.count)+1
		part.visual.set_source_frame(int(part.frame))
		_play_source_audio(str(part.definition.animation),int(part.frame))
		_y_sync_helper_instances(part)
		var shot_host: String = Y_SHOTS.get(int(part.source_id),{}).get(int(part.frame),"")
		if not shot_host.is_empty():_y_request_original_bullet(y,part,shot_host)
	for effect: Dictionary in y.effects:
		effect.frame = mini(int(effect.end),int(effect.frame)+1)
		effect.visual.set_source_frame(int(effect.frame))
	# After natural expiry set_phase4, actor25/38 polls on its next source callback.
	# If Root's common scheduler places that callback later in the SAME tick,
	# call the same hold-release predicate there; don't hardcode an extra delay.

func _y_timer_visual(y: Dictionary) -> void:
	var visual: Node2D = y.timer_visual
	var ranges: Array = database.assets.source_geometry.y_summon.normal_timer.image_ranges
	visual.visible = int(y.phase_age) >= 161
	if visual.visible:
		for r: Dictionary in ranges:
			if int(y.phase_age) >= int(r.from) and int(y.phase_age) <= int(r.through):
				visual.set_source_frame(int(r.image_source_frame))
	# 4480 placement enterFrame sets its OWN xscale from bug1. Its baked initial
	# offset must remain untranslated by this content flip: t-S*t compensation.
	var t := Vector2(-63.95,-112.05)
	var flip := Vector2(player.facing,1)
	visual.scale = flip
	visual.position = t-t*flip
	# Root4491 may have the opposite/frozen facing; preserve both transforms.

func _y_sync_helper_instances(part: Dictionary) -> void:
	var all: Dictionary = database.assets.source_geometry.act02_hit_windows.timelines
	var timeline: Dictionary = all.get(str(part.source_id),{})
	var rows: Array = timeline.get("active_by_source_frame",{}).get(str(part.frame),[])
	var live: Dictionary = {}
	for row: Dictionary in rows:
		var depth := int(row.depth)
		live[depth] = true
		if not part.helpers.has(depth):
			part.helpers[depth] = {"row":row,"frame":1,"playing":true,"born":_y_tick(),
				"host":part.host,"parent_source_id":part.source_id,"depth":depth,"callback_order":_new_callback_order()}
		else:
			var helper: Dictionary = part.helpers[depth]
			helper.row = row
			if bool(helper.playing):
				helper.frame = mini(3,int(helper.frame)+1)
				if int(helper.frame) == 3:helper.playing = false
	for depth: int in part.helpers.keys():
		if not live.has(depth):part.helpers.erase(depth)
	# Group recreation destroys all helper clocks/observers; no global modulo.

func _y_collision_requests() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var y := _y_find()
	if y.is_empty():return result
	for part: Dictionary in y.parts:
		for helper: Dictionary in part.helpers.values():
			if int(helper.born) == _y_tick() or int(helper.frame) == 3:continue
			var rect: Array = helper.row.rect # already includes1140 placement matrix
			var local := Rect2(rect[0],rect[1],rect[2],rect[3])
			var world: Rect2 = part.host.global_transform*local
			var box: Rect2 = global_transform.affine_inverse()*world
			result.append({"helper":helper,"rect":box,"normal_gravity":-8.0,
				"gravity_acceleration_add":0.1,"normal_restart_marker":int(part.source_id)==4459,
				"frozen_reaction_source_frame":5,"frozen_stops_helper_at":2})
	# Root resolves existing source NORMAL/FROZEN body types, not image overlap.
	# Normal: existing _lift_target(player,target,-8,source,restart_marker).
	# Frozen: existing frozen-body reaction5; helper.frame=2;playing=false.
	# No hardcoded collision damage here. Armor branches not reviewed in this
	# proposal remain explicit; do not claim normal semantics cover all targets.
	return result

func _y_marker_observers(preview := false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var y := _y_find()
	if y.is_empty():return result
	for part: Dictionary in y.parts:
		for helper: Dictionary in part.helpers.values():
			if int(helper.born) == _y_tick():continue
			if preview:
				if (int(y.phase) == 2 and int(y.phase_age)+1 >= 292) or (int(y.phase) == 3 and int(y.phase_age)+1 >= 81):continue
				var next_frame := int(part.frame)%int(part.count)+1
				var rows: Array = database.assets.source_geometry.act02_hit_windows.timelines[str(part.source_id)].active_by_source_frame.get(str(next_frame),[])
				if not rows.any(func(row: Dictionary)->bool:return int(row.depth) == int(helper.depth)):continue
			result.append({"host":helper.host,"helper":helper,"depth":helper.depth,"amount":Y_BONUS[int(part.source_id)],
				"source":"Y1140 global observer parent"+str(part.source_id),"born_tick":helper.born})
	# For each live callback owner, apply its amount through EXISTING deal_damage
	# to EACH original enemy whose ONE air marker currently reads2, regardless
	# of this helper's physical contact. Source1140 at empty stopped3 still owns
	# parent-placement callbacks until RemoveObject/group teardown.
	return result

func _y_request_original_bullet(y: Dictionary, part: Dictionary, kind: String) -> void:
	var host: Node2D = y.visual if kind == "root" else part.host
	var name_value := "총알"+str(part.i_label)
	part.i_label = "NaN" # undefined++ becomesNaN, then remainsNaN within this clip
	y.pending_projectiles.append({"host":host,"as_depth":0,"source_name":name_value,
		"source_id":1474,"source_parent_clip":part.source_id,"source_parent_frame":part.frame,
		"local_position":Vector2.ZERO,"local_scale":Vector2.ONE,"owner":player,
		"replace_key":str(host.get_instance_id())+":0","born_tick":_y_tick(),
		"source_root_lookup_matches":false,"failed_root_position_write":Vector2(90,250)})
	# Never assign the failed _root[name] position to the ACTUAL attached object.
	# root-host shots from different units share SAME ASdepth0 and replace there;
	# local-host shots replace only that unit's own depth0. Parent teardown kills
	# its dynamic child; a natural animation loop does not reset its locali.

func _y_take_projectile_requests() -> Array:
	var y := _y_find()
	if y.is_empty():return []
	var result: Array = y.pending_projectiles
	y.pending_projectiles = []
	return result

# CRT1 content adapters use the same actor, clock, damage and scene lifetime.
func _crt1_component(id: String) -> Dictionary:
	var key: String = {"jump":"jump","d_follow":"d_follow","moving_fire":"skill_w","awakening":"skill_t","buff":"skill_q","gunhawks":"skill_r","grab":"skill_v"}[id]
	return player.definition.actions.get(key,{}).get("component_data",{})

func _source_has(values: Array, frame: int) -> bool:
	# Extracted JSON source IDs are float; authored sequences are int.
	return values.any(func(value: Variant)->bool:return int(value) == frame)

func _crt1_input_action(key: String) -> String:
	if key == "skill_z":
		var id := "revenger" if player.state == "hit" else ("move_z" if player.state == "move" and player.parent_frame == 31 else "skill_z")
		if str(player.definition.actions[id].get("input","")) == key:return id
	return _resolve_author_input(key,key)

func _authored_input_ids() -> Array:
	return player.definition.get("author_input_actions",{}).keys().filter(func(id: String)->bool:return InputMap.has_action(id))

func _resolve_author_input(input_id: String, fallback: String) -> String:
	var choices: Array = player.definition.get("author_input_actions",{}).get(input_id,[])
	# A combo's follow-up shares X but must not replace its entry action.
	# State-specific Z/D/R controllers resolve their branch before this fallback.
	if fallback in choices and player.state in player.definition.actions[fallback].get("allowed_states",[]):return fallback
	for index in range(choices.size()-1,-1,-1):
		var id: String = choices[index]
		if player.state in player.definition.actions[id].get("allowed_states",[]):return id
	if player.definition.actions.has(fallback) and bool(player.definition.actions[fallback].get("source_author",false)) and str(player.definition.actions[fallback].get("input","")) != input_id:return ""
	return fallback

func _dispatch_custom_inputs(input: Dictionary) -> void:
	var stock := ["attack","skill","skill_s","jump","down","skill_z"]+EXTRA_INPUTS
	for key: String in _authored_input_ids():
		if key not in stock and bool(input.get(key,false)):_try_skill(_resolve_author_input(key,""))

func _start_actor_action(id: String) -> bool:
	if not player.definition.actions.has(id):return false
	var action: Dictionary = player.definition.actions[id]
	var cost := float(action.get("cost",0))
	var cubes := int(action.get("cubes",0))
	if player.mp < maxf(cost,float(action.get("required_mp",0))) or player.hp < maxf(float(action.get("hp_cost",0)),float(action.get("required_hp",0))) or int(session.profile.progress.clear_cubes) < cubes or int(player.cooldowns.get(id,0)) > 0:
		feedback.emit("动作资源不足或冷却中")
		return false
	player.mp -= cost
	player.hp -= float(action.get("hp_cost",0))
	session.profile.progress.clear_cubes -= cubes
	if int(action.get("cooldown_ticks",0)) > 0:player.cooldowns[id] = int(action.cooldown_ticks)
	return player.set_action(id)

func _crt1_action_started(key: String, action: Dictionary) -> void:
	if key == "skill_g":player.set_facing(-player.facing)
	if key == "skill_h":crt1.h_count = 0
	if key == "skill_w":crt1.w_ammo_frame = 2;crt1.w_shot_frame = 1;crt1.w_move_frame = 1
	if key == "skill_t":
		crt1.t_slot_frame = int(action.get("slot_start_frame",2))
		crt1.t_slot_playing = false
		crt1.t_hold = 0
		crt1.t_timer = 0
		crt1.t_kill = false
	if key == "skill_z":player.action_child_x = float(action.get("child_x_easing",{}).get("initial",-2.2))

func _crt1_component_input(input: Dictionary) -> bool:
	var action: Dictionary = player.definition.actions[player.state]
	var controller := str(action.get("controller",""))
	if controller == "crt1_d" and bool(input.get(str(action.follow_key),false)) and player.source_frame >= int(action.follow_from) and player.source_frame <= int(action.follow_until):
		player.set_action(str(action.follow_action));_record("crt1_d_follow",{});return true
	if controller == "crt1_moving_fire":
		if bool(input.get("jump",false)):player.set_action("idle");_crt1_end_w()
		elif bool(input.get("skill_z",false)):player.set_facing(-player.facing)
		return true
	if controller == "crt1_t":
		if _source_has(_crt1_component("awakening").turn_allowed_parent_frames,player.source_frame) and bool(input.get("skill_z",false)):player.set_facing(-player.facing)
		return true
	if controller == "crt1_gunhawk_catch" and player.source_frame >= int(action.follow_from) and player.source_frame <= int(action.follow_until) and action.follow_inputs.any(func(id: String)->bool:return bool(input.get(id,false))):
		player.seek_action_frame(int(action.follow_source_frame));return true
	if str(action.get("cancel_input","")) == "jump" and bool(input.get("jump",false)):
		player.set_action("idle");return true
	return false

func _crt1_event(actor: Node2D, event: Dictionary) -> void:
	match str(event.kind):
		"crt1_buff_start":
			crt1.buff_frame = 2
			crt1["buff_born"] = int(session.run.source_ticks)
			_play_source_audio(str(_crt1_component("buff").edges_animation),2)
			_record("crt1_buff_started",{})
		"crt1_gunhawk":_crt1_launch_gunhawk(int(event.stage))
		"crt1_head_projectile":
			_spawn_projectile(actor,event)
			projectiles[-1]["ranger_shot"] = true
			projectiles[-1]["shot_extra"] = float(event.get("damage",30))
		"crt1_line_shot":
			for rect: Rect2 in event.get("rectangles",[]):
				var box: Rect2 = actor.transform_rect(rect)
				_active_boxes.append(box)
				for target: Node2D in enemies:
					if target.hp > 0 and _overlaps(box,target.hurt_rect()):_crt1_shot_hit(target,float(event.get("gravity",-5)),float(event.get("damage",0)),"source4636 "+actor.state)
		"crt1_d_contact":
			if actor.source_frame >= int(actor.definition.actions.skill.contact_start_frame):return
			for rect: Rect2 in event.get("local_rects",[]):
				var box: Rect2 = actor.transform_rect(rect)
				if enemies.any(func(target: Node2D)->bool:return target.hp > 0 and _overlaps(box,target.hurt_rect())):
					actor.seek_action_frame(int(actor.definition.actions.skill.contact_start_frame))
					_record("crt1_d_contact",{});return
		"crt1_lift":
			for rect: Rect2 in event.get("local_rects",[]):
				var box: Rect2 = actor.transform_rect(rect)
				_active_boxes.append(box)
				for target: Node2D in enemies:
					var claim: String = actor.state+":"+str(event.get("helper_id",0))+":"+str(event.get("source_frame",event.get("from",1)))+":"+target.identifier
					if target.hp <= 0 or not _overlaps(box,target.hurt_rect()) or not actor.claim_target(claim):continue
					_start_marker(actor,target,float(event.gravity),"CRT1 "+actor.state)
					if float(event.get("damage",0)) > 0:deal_damage(actor,target,float(event.damage),"CRT1 source observer "+actor.state,false)
			if actor.state == "skill_z":_restart_z_interval()

func _advance_crt1_components(previous: String) -> void:
	var action: Dictionary = player.definition.actions[player.state]
	var frame: int = player.source_frame
	if previous == "skill_w" and player.state != "skill_w":_crt1_end_w()
	if previous == "skill_t" and player.state != "skill_t":_crt1_end_t()
	if action.has("child_x_easing"):
		var easing: Dictionary = action.child_x_easing
		player.action_child_x = Actor.twips(player.action_child_x+(float(easing.target)-player.action_child_x)/float(easing.divisor))
		player.visual.position.x = float(action.get("visual_offset",Vector2.ZERO).x)+(player.action_child_x-float(easing.initial))*player.visual_scale.x*player.facing
		if frame == int(easing.get("transfer_at",0)):_move_player(player.action_child_x*player.facing)
	if player.state == "move_z":
		for motion: Dictionary in action.get("source_movement",[]):
			if frame >= int(motion.from) and frame <= int(motion.until):_move_player(float(motion.per_tick)*player.facing)
	if player.state == "down" and action.has("backstep") and frame <= int(action.backstep.through_source_frame):_move_player(float(action.backstep.per_tick)*player.facing)
	if previous == "down" and player.state == "idle":_move_player(float(player.definition.actions.down.backstep.end_child_x)*player.facing)
	if previous == "d_follow" and player.state == "idle":_move_player(float(player.definition.actions.d_follow.root_x_transfer_at_end)*player.facing)
	match str(action.get("controller","")):
		"crt1_d":
			_crt1_move_held(float(action.held_move_per_tick))
			if frame == int(action.normal_end_source_frame):player.set_action("idle")
		"crt1_gunhawk_catch":
			if bool(_held.get("right",false)):player.set_facing(1)
			if bool(_held.get("left",false)):player.set_facing(-1)
			if frame == int(action.normal_end_source_frame):player.set_action("idle")
		"crt1_h":_crt1_h_direction(action)
		"crt1_moving_fire":_advance_crt1_w()
		"crt1_t":_advance_crt1_t()
	_advance_crt1_buff()
	_advance_crt1_gunhawks()
	_advance_crt1_shots()
	if _crt1_views.has("awakening_cutin"):
		var spec: Dictionary = _crt1_component("awakening").cutin
		var cutin_frame := int(spec.start_frame)+int(session.run.source_ticks)-int(crt1.cutin_born)
		if cutin_frame >= int(spec.end_frame):
			_crt1_views.awakening_cutin.queue_free()
			_crt1_views.erase("awakening_cutin")
		else:_crt1_views.awakening_cutin.set_source_frame(cutin_frame)

func _crt1_move_held(amount: float) -> bool:
	var moved := false
	if bool(_held.get("right",float(_held.get("axis",0)) > 0)):_move_player(amount);player.set_facing(1);moved = true
	if bool(_held.get("left",float(_held.get("axis",0)) < 0)):_move_player(-amount);player.set_facing(-1);moved = true
	return moved

func _crt1_h_direction(action: Dictionary) -> void:
	if player.source_frame == int(action.hh_increment_source_frame):crt1.h_count += 1
	if player.source_frame < int(action.direction_window_from) or player.source_frame > int(action.direction_window_until) or int(crt1.h_count) >= int(action.chain_limit):return
	var direction := ""
	if bool(_held.get("right",float(_held.get("axis",0)) > 0)):direction = "forward" if player.facing == 1 else "back"
	if bool(_held.get("left",float(_held.get("axis",0)) < 0)):direction = "forward" if player.facing == -1 else "back"
	if bool(_held.get("up",false)) or bool(_held.get("aim_up",false)):direction = "up"
	if bool(_held.get("held_down",false)) or bool(_held.get("down",false)):direction = "down"
	if not direction.is_empty():player.set_action(str(action.direction_actions[direction]));_record("crt1_h_direction",{"direction":direction,"count":crt1.h_count})

func _crt1_local_view(id: String, key: String, local := Transform2D.IDENTITY) -> Node2D:
	var visual: Node2D = _crt1_views.get(id)
	if not is_instance_valid(visual):
		visual = _new_source_visual(key,player.get_node("AuthorOffset"))
		_crt1_views[id] = visual
	var source_scale: Vector2 = player.visual_scale*Vector2(player.facing,1)
	visual.transform = Transform2D(Vector2(source_scale.x,0),Vector2(0,source_scale.y),Vector2.ZERO)*local
	visual.visible = true
	return visual

func _crt1_hide_views(prefix: String) -> void:
	for id: String in _crt1_views:
		if id.begins_with(prefix) and is_instance_valid(_crt1_views[id]):
			_crt1_views[id].visible = false
			_crt1_view_frames.erase(id)

func _crt1_view_frame(id: String, key: String, frame: int, local := Transform2D.IDENTITY) -> Node2D:
	var visual := _crt1_local_view(id,key,local)
	var token := key+":"+str(frame)
	if str(_crt1_view_frames.get(id,"")) != token:_play_source_audio(key,frame)
	_crt1_view_frames[id] = token
	visual.set_source_frame(frame)
	return visual

func _advance_crt1_air() -> void:
	if player.state not in ["jump","d_follow"]:return
	var data := _crt1_component("d_follow" if player.state == "d_follow" else "jump")
	var rows: Array = data.air_overlay_by_frame.get(str(player.source_frame),[])
	_crt1_move_held(float(data.held_move))
	if rows.is_empty():player.air_action_frame = 1;return
	var sub: int = player.air_action_frame
	_play_source_audio(str(data.air_animation),sub)
	if not _source_has(data.air_stop_frames,sub):player.air_action_frame += 1
	if sub != 1:_move_player(float(data.recoil_per_tick)*player.facing)
	if _source_has(data.fire_sub_frames,sub):
		var child: Array = rows[0].matrix
		var x := -50.0 if player.state == "d_follow" else 0.0
		var y := (160.0 if player.state == "d_follow" else 230.0)+float(child[5])
		_spawn_projectile(player,{"projectile":data.projectile,"gravity":-3.0,"parent_y":y,"spawn_offset":[x,0]})
	if bool(_held.get("held_attack",false)) and _source_has(data.held_x_restart_frames,sub):player.air_action_frame = 2
	player.update_jump_visual()

func _crt1_shot_hit(target: Node2D, gravity: float, extra: float, source: String) -> void:
	if target.frozen:_frozen_hit(target,2);return
	if not target.airborne:target.set_action("idle")
	target.airborne = true
	target.vertical_speed = gravity
	target.gravity_acceleration += .1
	target._air_hit_started = -1
	_markers.erase(target.identifier)
	var old: Dictionary = _crt1_shots.get(target.identifier,{})
	var visual: Node2D = old.get("visual")
	if not is_instance_valid(visual):
		visual = _new_source_visual("enemy7437_shot_marker" if int(target.definition.source_id) == 7437 else "enemy_shot_marker",target.visual_parent())
	visual.transform = target.air_hit_visual.transform
	visual.set_source_frame(1)
	_crt1_shots[target.identifier] = {"born":int(session.run.source_ticks),"age":0,"extra":extra,"source":source,"visual":visual}
	_record("crt1_shot_marker",{"target":target.identifier,"extra":extra,"source":source})

func _advance_crt1_shots() -> void:
	for target: Node2D in enemies:
		if not _crt1_shots.has(target.identifier):continue
		var shot: Dictionary = _crt1_shots[target.identifier]
		if int(shot.born) == int(session.run.source_ticks):continue
		shot.age += 1
		if not target.airborne or target.vertical_speed > 0 or target.hp <= 0:
			shot.visual.queue_free();_crt1_shots.erase(target.identifier);continue
		shot.visual.transform = target.air_hit_visual.transform
		shot.visual.set_source_frame(mini(4,int(shot.age)+1))
		if int(shot.age) == 1:
			combo += 1
			combo_frame = 2
			var damage := float(stage.get("shot_damage",20))+float(shot.extra)
			if player.state == "skill_g":damage += float(player.definition.actions.skill_g.shot_marker_bonus)
			if int(crt1.buff_frame) >= 9:damage += float(_crt1_component("buff").shot_marker2_extra_damage)
			if player.state == "skill_e":damage += float(player.definition.actions.skill_e.marker_bonus)
			deal_damage(player,target,damage,"CRT1 shot2 observer: "+str(shot.source),false)
		if player.state == "skill_w" and target.hp > 0:deal_damage(player,target,float(_crt1_component("moving_fire").marker9_bonus),"CRT1 W source marker9 observer",false)

func _advance_crt1_w() -> void:
	var data := _crt1_component("moving_fire")
	var moved := _crt1_move_held(float(data.move_per_tick))
	var key: String = data.move_animation if moved else data.idle_animation
	if player.visual.definition != database.assets.animations[key]:player.visual.configure(database.assets.animations[key])
	crt1.w_move_frame = int(crt1.w_move_frame)%int(data.move_control_frame)+1 if moved else 1
	player.visual.set_source_frame(int(crt1.w_move_frame) if moved else 1)
	var placement: Array = data.move.matrix if moved else data.idle.matrix
	var parent: Array = data.parent_matrix
	player.visual.position = player.definition.actions[player.state].get("visual_offset",Vector2.ZERO)+Vector2(parent[4]+placement[4],parent[5]+placement[5])*player.visual_scale*Vector2(player.facing,1)
	var frame := int(crt1.w_shot_frame)
	if _source_has(data.shot_stop_frames,frame):
		if bool(_held.get("held_w",false)) or bool(_held.get("held_attack",false)):frame += 1
	else:frame = 1 if frame >= database.assets.animations[data.shot_animation].frames.size() else frame+1
	crt1.w_shot_frame = frame
	_crt1_view_frame("w_shot",str(data.shot_animation),frame,_matrix(parent)*_matrix(placement)*_matrix(data.shot.matrix))
	if _source_has(data.shot_frames,frame):
		var index := 0 if frame == int(data.shot_frames[0]) else 1
		var spawn := Vector2(float(data.spawn.x_delta_times_facing)*player.facing,float(data.spawn.y_deltas[index]))
		_spawn_projectile(player,{"projectile":data.projectile,"gravity":float(data.shot_gravity),"spawn_offset":[spawn.x,spawn.y],"static_origin":true,"world_scale":[1.0,float(data.spawn.scale_y)]})
		projectiles[-1]["ranger_shot"] = true
		projectiles[-1]["shot_extra"] = 0.0
	if _source_has(data.ammo_consume_frames,frame):
		crt1.w_ammo_frame += 1
		_record("crt1_w_ammo",{"frame":crt1.w_ammo_frame})
	if int(crt1.w_ammo_frame) >= int(data.ammo_end_frame):player.set_action("idle");_crt1_end_w()

func _crt1_end_w() -> void:
	crt1.w_ammo_frame = 1
	crt1.w_shot_frame = 1
	_crt1_hide_views("w_")

func _advance_crt1_buff() -> void:
	var frame := int(crt1.buff_frame)
	if frame <= 1:return
	var data := _crt1_component("buff")
	if int(crt1.get("buff_born",-1)) != int(session.run.source_ticks):frame += 1
	if frame > int(data.frame_count):
		crt1.buff_frame = 1
		_crt1_hide_views("buff_");return
	crt1.buff_frame = frame
	var edges := _crt1_local_view("buff_edges",str(data.edges_animation))
	edges.visible = frame < int(data.active_start) or frame > int(data.parts_active_frames[1])
	if edges.visible:edges.set_source_frame(frame)
	for i in range(data.parts.size()):
		var part: Dictionary = data.parts[i]
		var animation: Dictionary = database.assets.animations[part.animation]
		var baked := _matrix(animation.get("baked_placement_matrix",[1,0,0,1,0,0]))
		var visual := _crt1_local_view("buff_part%d"%i,str(part.animation),_matrix(data.parent_placement.matrix)*_matrix(part.matrix)*baked.affine_inverse())
		visual.visible = frame >= int(data.active_start) and frame <= int(data.parts_active_frames[1])
		visual.modulate.a = float(part.alpha_mult)/float(animation.get("baked_alpha_mult",256))
		if visual.visible:visual.set_source_frame((frame-int(data.active_start))%int(part.loop_count)+1)

func _crt1_launch_gunhawk(index: int) -> void:
	var data := _crt1_component("gunhawks")
	var spec: Dictionary = data.stages[str(index)]
	for old: Dictionary in _gunhawks.duplicate():
		if int(old.stage) == index:old.visual.queue_free();_gunhawks.erase(old)
	var placement: Dictionary = {}
	for row: Dictionary in data.root_placements[str(stage.source_root_frame)]:
		if int(row.source_id) == int(spec.source_id):placement = row;break
	var visual := _new_source_visual(str(spec.animation),self)
	visual.position = Vector2(player.position.x,float(placement.matrix[5]))
	visual.scale.x = player.facing
	visual.z_index = mini(4096,int(placement.depth))
	visual.set_source_frame(int(spec.entry))
	_play_source_audio(str(spec.animation),int(spec.entry))
	_gunhawks.append({"stage":index,"frame":int(spec.entry),"visual":visual,"born":int(session.run.source_ticks),"facing":player.facing,"spec":spec.duplicate(true),"root":int(spec.source_id),"children":{}})
	_record("crt1_gunhawk_launch",{"stage":index})

func _advance_crt1_gunhawks() -> void:
	var data := _crt1_component("gunhawks")
	for item: Dictionary in _gunhawks.duplicate():
		if int(item.born) == int(session.run.source_ticks):continue
		item.frame += 1
		if int(item.frame) >= int(item.spec.end):item.visual.queue_free();_gunhawks.erase(item);continue
		item.visual.set_source_frame(int(item.frame))
		var live_children := {}
		for placement: Dictionary in data.child_instances[str(item.root)].get(str(item.frame),[]):
			var depth := str(int(placement.depth))
			var born := int(item.children.get(depth,{}).get("born",item.frame))
			live_children[depth] = {"born":born}
			var table: Dictionary = data.helper_timelines.get(str(int(placement.source_id)),{})
			var audio_key := str(data.get("child_audio",{}).get(str(int(placement.source_id)),""))
			if not audio_key.is_empty():_play_source_audio(audio_key,(int(item.frame)-born)%int(item.spec.helper_loop_frames)+1)
			#6771/6760/6752 own four-frame loops; helper4636 exists only1/2.
			if not _source_has(item.spec.helper_active_frames,(int(item.frame)-born)%int(item.spec.helper_loop_frames)+1):continue
			for hit: Dictionary in table.get("active_by_source_frame",{}).get("1",[]):
				var r: Array = hit.rect
				var box: Rect2 = item.visual.transform*(_matrix(placement.matrix)*Rect2(r[0],r[1],r[2],r[3]))
				for target: Node2D in enemies:
					if target.hp > 0 and _overlaps(box,target.hurt_rect()):
						_start_marker(player,target,float(item.spec.helper_gravity),"gunhawk"+str(item.stage))
						if float(item.spec.helper_marker_bonus) > 0 and int(_markers.get(target.identifier,{}).get("processed_tick",-1)) == int(session.run.source_ticks):deal_damage(player,target,float(item.spec.helper_marker_bonus),"gunhawk6752 marker2 observer",false)
		item.children = live_children
		if int(item.frame) >= int(item.spec.get("catch_source_frame",2000)) and player.state in ["idle","move","basic","basic2","basic3","basic4","basic5"]:
			for hit: Dictionary in data.root_timelines[str(item.root)].active_by_source_frame.get(str(item.frame),[]):
				if int(hit.source_id) != int(data.catch_detector_id):continue
				var r: Array = hit.rect
				if _overlaps((item.visual.transform*Rect2(r[0],r[1],r[2],r[3])),player.gunhawk_rect()):
					player.set_action(str(item.spec.catch_action))
					item.visual.queue_free();_gunhawks.erase(item)
					_record("crt1_gunhawk_catch",{"stage":item.stage});break

func _advance_crt1_t() -> void:
	var data := _crt1_component("awakening")
	var frame: int = player.source_frame
	if frame == int(data.death_release_source_frame):_crt1_release_deaths()
	if frame == int(data.cutin.trigger_frame) and not _crt1_views.has("awakening_cutin"):
		var cutin := _new_source_visual(str(data.cutin.animation),self)
		cutin.position = _vec(data.cutin.position)
		cutin.z_index = int(stage.get("source_depths",{}).get("hud",2623))
		cutin.set_source_frame(int(data.cutin.start_frame))
		_crt1_views["awakening_cutin"] = cutin
		crt1["cutin_born"] = int(session.run.source_ticks)
	if data.holds.has(str(frame)):
		if int(crt1.t_hold) != frame:
			crt1.t_hold = frame;crt1.t_timer = 1
			var entry: Dictionary = data.get("air_container_audio",{})
			if not entry.is_empty() and frame == int(entry.parent_frame):audio.play_sfx(str(entry.sound),float(entry.offset))
		else:crt1.t_timer += 1
		var hold: Dictionary = data.holds[str(frame)]
		var moved := _crt1_move_held(float(data.move_per_tick))
		if frame in [25,43]:
			for part: String in ["idle","move","fire","shell"]:
				var row: Dictionary = data.ground_parts[part]
				var key: String = data.part_animations[str(int(row.source_id))]
				var count: int = database.assets.animations[key].frames.size()
				var visual := _crt1_view_frame("t_"+part,key,mini(count,int(crt1.t_timer)) if data.part_stop_frames.has(str(int(row.source_id))) else (int(crt1.t_timer)-1)%count+1,_matrix(data.parent_matrix)*_matrix(hold.visual.matrix)*_matrix(row.matrix))
				visual.visible = (part != "idle" or not moved) and (part != "move" or moved)
		else:
			_crt1_hide_views("t_")
			for i in range(data.air_parts.size()):
				var row: Dictionary = data.air_parts[i]
				var key: String = data.part_animations[str(int(row.source_id))]
				var count: int = database.assets.animations[key].frames.size()
				_crt1_view_frame("t_air%d"%i,key,mini(count,int(crt1.t_timer)) if data.part_stop_frames.has(str(int(row.source_id))) else (int(crt1.t_timer)-1)%count+1,_matrix(data.parent_matrix)*_matrix(hold.visual.matrix)*_matrix(row.matrix))
		#5858 is its own5-frame loop (stage66 seeks1 at4), not a shot20 marker.
		var helper: Dictionary = data.phase_helpers[str(frame)]
		if _source_has(helper.active_frames,(int(crt1.t_timer)-1)%int(helper.loop_frames)+1):
			for rect: Rect2 in helper.hit_windows:
				var box: Rect2 = player.transform_rect(rect)
				_active_boxes.append(box)
				for target: Node2D in enemies:
					if target.hp > 0 and _overlaps(box,target.hurt_rect()):_start_marker(player,target,float(helper.gravity),"T5858")
		for target: Node2D in enemies:
			if target.hp > 0 and int(_markers.get(target.identifier,{}).get("processed_tick",-1)) == int(session.run.source_ticks):deal_damage(player,target,float(helper.marker_bonus),"T5858 phase observer",false)
		if int(crt1.t_timer) >= int(hold.timer_observed_frame):
			player.seek_action_frame(int(hold.next));crt1.t_hold = 0;_crt1_hide_views("t_")
	else:
		_crt1_hide_views("t_")
		if frame == int(data.kill_branch.check_frame) and crt1.t_kill:player.seek_action_frame(int(data.kill_branch.destination))
		elif frame == int(data.normal_end_frame) or frame == int(data.kill_branch.end_frame):player.set_action("idle");_crt1_end_t()

func _crt1_end_t() -> void:
	_crt1_release_deaths()
	crt1.t_slot_frame = 2
	crt1.t_slot_playing = true
	crt1.t_hold = 0
	crt1.t_timer = 0
	_crt1_hide_views("t_")

func _crt1_t_touches(target: Node2D) -> bool:
	if int(player.definition.source_crt) != 1 or player.state != "skill_t":return false
	var data := _crt1_component("awakening")
	var phase: Dictionary = data.get("phase_helpers",{}).get(str(player.source_frame),{})
	if not phase.is_empty():
		for rect: Rect2 in phase.hit_windows:
			if _overlaps(player.transform_rect(rect),target.hurt_rect()):return true
	for box: Rect2 in _action_rects(int(player.definition.actions.skill_t.source_id),player.source_frame):
		if _overlaps(box,target.hurt_rect()):return true
	return false

func _crt1_release_deaths() -> void:
	for target: Node2D in enemies:
		if not target.source_death_locked:continue
		target.source_death_locked = false
		if target.hp <= 0 and not target.airborne:
			if target.state != "dead":target.set_action("dead")
			target.seek_action_frame(2)

func _advance_crt1_projectile(bullet: Dictionary) -> bool:
	var geometry: Dictionary = database.assets.source_geometry[bullet.key]
	bullet.age += 1
	var frame := int(bullet.age)+1
	if frame >= int(geometry.stop_source_frame):return false
	bullet.visual.set_source_frame(frame)
	if not bool(bullet.static_origin):bullet.origin = bullet.owner.position+bullet.spawn_offset*bullet.scale*Vector2(int(bullet.direction),1)
	bullet.visual.position = bullet.origin+Vector2(0,float(bullet.parent_y)*float(bullet.scale.y))
	var matrix := Transform2D.IDENTITY
	var present := false
	for row: Dictionary in geometry.timeline_matrices:
		if int(row.source_frame) == frame:matrix = _matrix(row.matrix);present = true;break
	if not present:return true
	var r: Array = geometry.rect
	var transform := Transform2D(Vector2(float(bullet.scale.x)*int(bullet.direction),0),Vector2(0,bullet.scale.y),bullet.visual.position)
	var box := transform*(matrix*Rect2(r[0],r[1],r[2],r[3]))
	_active_boxes.append(box)
	for target: Node2D in enemies:
		if target.hp <= 0 or bullet.targets.has(target.identifier) or not _overlaps(box,target.hurt_rect()):continue
		bullet.targets[target.identifier] = true
		if bool(bullet.get("ranger_shot",false)):_crt1_shot_hit(target,float(bullet.gravity),float(bullet.get("shot_extra",0)),str(bullet.key))
		else:_start_marker(bullet.owner,target,float(bullet.gravity),str(bullet.key))
	return true


func _overlaps(first: Rect2, second: Rect2) -> bool:
	# Flash missing/empty display-list bodies cannot be hit. Godot accepts a
	# zero-area point inside another Rect2 unless positive area is checked.
	return first.has_area() and second.has_area() and first.intersects(second)

func _advance_nested_audio() -> void:
	# Each authored placement has an independent clock and the parent's lifetime.
	var action: Dictionary = player.definition.actions[player.state]
	var live := {}
	for spec: Dictionary in action.get("nested_audio",[]):
		if player.source_frame < int(spec.from_frame) or player.source_frame > int(spec.until_frame):continue
		var key := str(player.action_serial)+":"+str(spec.identifier)
		var clock: Dictionary = _nested_audio.get(key,{"frame":int(spec.get("entry_frame",1))-1})
		clock.frame += 1
		if int(spec.get("loop_frames",0)) > 0 and int(clock.frame) > int(spec.loop_frames):clock.frame = 1
		for event: Dictionary in spec.sounds:
			if int(clock.frame) != int(event.frame):continue
			if event.get("audio_stream") is AudioStream:audio.play_stream(event.audio_stream,float(event.get("offset",0)),str(event.get("sound","")))
			else:audio.play_sfx(str(event.sound),float(event.get("offset",0)))
		live[key] = clock
	_nested_audio = live

# CRT2 uses the same input transactions, source clock, marker/damage chain and
# encounter lifetime as CRT0/1. Components below are placed source clips, not a
# parallel character Runtime. Their parameters live in the author's Resources.
func _crt2_component(id: String) -> Dictionary:
	return player.definition.get("components",{}).get(id,{})

func _crt2_geometry(id: String) -> Dictionary:
	return _crt2_component("visuals").get("geometry",{}).get(id,{})

func _crt2_input(input: Dictionary) -> void:
	if player.state == "skill_a" and player.source_frame >= 16 and player.source_frame <= 28 and (bool(input.get("skill_a",false)) or bool(input.get("skill_z",false))):
		player.seek_action_frame(30,true);return
	if player.state == "jump" and player.source_frame in [4,5] and bool(input.get("skill_z",false)) and int(crt2.air_frame) == 1:
		_crt2_air_z(62,true);return
	var serial: int = player.action_serial
	for key: String in ["load_h","load_g","load_f","skill_z","skill_a","skill_s","skill","skill_q","skill_e","skill_r","skill_v","skill_w"]:
		if not bool(input.get(key,false)):continue
		var fallback: String = {"load_h":"skill_h_close" if pren == 1 else "skill_h","load_g":"skill_g","load_f":"skill_f","skill_s":"skill_s_start","skill":"skill_d","skill_z":"hurt_z" if player.state == "hit" else "skill_z"}.get(key,key)
		_try_skill(_resolve_author_input(key,fallback))
	_dispatch_custom_inputs(input)
	if serial != player.action_serial:return
	if bool(input.get("attack",false)):
		var action: Dictionary = player.definition.actions[player.state]
		if player.state in ["idle","move"]:
			_start_actor_action("pren_basic1" if pren == 1 else "basic")
		elif action.get("combo_input_semantics","") == "keyDown-heldX" and player.source_frame >= int(action.get("combo_from",999)) and player.source_frame <= int(action.get("combo_until",0)):
			_start_actor_action(str(action.combo_next))
	if serial == player.action_serial:
		if bool(input.get("jump",false)) and player.state in ["idle","move"]:_start_actor_action("jump")
		elif bool(input.get("down",false)) and player.parent_frame in [64,65,66,67,69,70,71,84,85,86,87]:_start_actor_action("down")

func _crt2_action_started(key: String) -> void:
	if key == "skill_r":crt2.r_slot_frame = 2;crt2.r_slot_playing = false
	if key in ["skill_d","skill_v"]:zab = ""
	if key == "skill_h_close":
		crt2.frenzy_frame = 1;pren = 0;crt2.appearance_pren = 0;crt2.urlr = 1

func _crt2_event(actor: Node2D, event: Dictionary) -> void:
	if actor != player:return
	match str(event.kind):
		"crt2_hit":_crt2_hit(event)
		"crt2_seek":player.seek_action_frame(int(event.target))
		"crt2_transfer_child":_move_player(float(player.action_child_x)*player.facing)
		"crt2_persistent_start":
			var field := str(event.component)+"_frame"
			crt2[field] = int(event.start_frame)
			crt2[str(event.component)+"_born"] = int(session.run.source_ticks)
			if event.component == "rage":_crt2_component_sounds(_crt2_component("rage"),2)
		"crt2_hp_gain":player.hp = minf(float(player.definition.max_hp),player.hp+float(event.amount))
		"crt2_set_urlr":crt2.urlr = int(event.value)
		"crt2_attach":
			var id := int(event.get("source_id",event.get("source_ids_by_facing",{}).get("right" if player.facing == 1 else "left",0)))
			_crt2_spawn(id,player.position)
		"crt2_cutin":
			var spec := _crt2_geometry("r_cutin")
			var view := _crt2_view("r_cutin",str(spec.animation),66,Transform2D.IDENTITY,false)
			# Immediate6835 placement is already encoded by the atlas pivot.
			# Apply only its root6917 ancestor, as the existing Y/T cutins do.
			var root_placement: Dictionary = spec.root_placements_by_source_frame[str(int(stage.source_root_frame))][0]
			view.transform = _matrix(root_placement.matrix)
			view.z_index = int(root_placement.depth)
			crt2["cutin_born"] = int(session.run.source_ticks)
		"crt2_cooldown_resume":crt2.r_slot_frame = 2;crt2.r_slot_playing = true
		"crt2_slot_play":
			player.cooldowns["jump_z"] = int(player.definition.actions.jump_z.cooldown_ticks)
			player.set_action("jump");player.seek_action_frame(28,true)

func _crt2_hit(event: Dictionary) -> void:
	var rule: Dictionary = event.source_rule
	var kind := str(rule.kind)
	if kind in ["marker_observer","grab_anchor","grab_target_observer"]:return
	for target: Node2D in enemies:
		if target.hp <= 0:continue
		var contact := false
		for local: Rect2 in event.get("local_rects",[]):
			var shifted := local
			shifted.position.x += _crt2_child_delta()
			var box: Rect2 = player.transform_rect(shifted)
			_active_boxes.append(box)
			if _overlaps(box,target.hurt_rect()):contact = true
		if not contact:continue
		if bool(event.get("once_per_action",false)) and not player.claim_target(target.identifier):continue
		if kind == "grab_acquire":
			if not zab.is_empty() or target.frozen:continue
			zab = target.identifier
			player.seek_action_frame(int(rule.next_action_source_frame),true)
			_record("crt2_grab_acquired",{"target":zab,"action":player.state})
			return
		if kind == "status":_crt2_bleed(target);continue
		if float(rule.get("direct_damage",0)) > 0:deal_damage(player,target,float(rule.direct_damage),"CRT2 source direct contact",false)
		_start_marker(player,target,float(event.gravity),"CRT2 "+player.state+" helper"+str(event.source_helper))

func _crt2_child_delta() -> float:
	var action: Dictionary = player.definition.actions[player.state]
	return player.action_child_x-float(action.get("parent_matrix",[1,0,0,1,0,0])[4])

func _crt2_marker_bonus(target: Node2D, frame: int) -> float:
	var value := 0.0
	if player.parent_frame == 84:value += 2
	if player.parent_frame == 90:value += 3
	if int(crt2.rage_frame) >= 9:value += float(_crt2_component("rage").marker_bonus)
	if int(crt2.lust_frame) >= 9 and target == enemies[0]:value += float(_crt2_component("lust").marker_bonus)
	var seen := {}
	for window: Dictionary in player.definition.actions[player.state].get("windows",[]):
		if frame < int(window.from) or frame > int(window.until):continue
		var key := str(window.get("source_depth",0))+":"+str(window.get("source_helper",0))
		if seen.has(key):continue
		seen[key] = true
		value += float(window.get("source_rule",{}).get("marker_bonus",0))
	for item: Dictionary in _crt2_objects:
		if item.source_id == 803 and int(item.frame) in [2,3,4]:value += 25
		if item.source_id == 1077 and (int(item.frame) in [1,2,5,6,9,10,11,12,13]):value += 25
	return value

func _crt2_view(id: String, key: String, frame: int, local := Transform2D.IDENTITY, attached := true) -> Node2D:
	var visual: Node2D = _crt2_views.get(id)
	if not is_instance_valid(visual):
		visual = _new_source_visual(key,player.visual_parent() if attached else self)
		_crt2_views[id] = visual
	elif visual.definition != database.assets.animations[key]:visual.configure(database.assets.animations[key])
	if attached:
		var scale: Vector2 = player.visual_scale*Vector2(player.facing,1)
		visual.transform = Transform2D(Vector2(scale.x,0),Vector2(0,scale.y),Vector2.ZERO)*local
	else:visual.transform = local
	visual.visible = true
	visual.set_source_frame(frame)
	return visual

func _crt2_remove_view(id: String) -> void:
	if is_instance_valid(_crt2_views.get(id)):_crt2_views[id].queue_free()
	_crt2_views.erase(id)

func _advance_crt2_components(previous: String) -> void:
	var action: Dictionary = player.definition.actions[player.state]
	var frame: int = player.source_frame
	if previous in ["skill_d","skill_v"] and player.state != previous:zab = "";_crt2_remove_view("d_blood")
	for row: Dictionary in action.get("motion",[]):
		if frame >= int(row.frames[0]) and frame <= int(row.frames[1]):_move_player(float(row.root_delta_x)*player.facing)
	if player.state in ["skill_s_start","hurt_z"] and frame <= 5 and not bool(_held.get("held_s",false)):
		player.set_action("skill_s_release");player.consume_entry_frame()
	elif player.state in ["pren_basic2","pren_basic3"] and frame == 10 and bool(_held.get("held_attack",false)):
		player.set_action(str(action.combo_next_if_pok) if player.state == "pren_basic2" and int(crt2.rage_frame) >= 9 else str(action.combo_next))
		player.consume_entry_frame()
	elif player.state == "skill_a" and frame == 29:player.set_action("idle")
	elif player.state == "skill_h_close" and frame == 2:player.seek_action_frame(90)
	elif player.state == "skill_d" and frame == 15:player.set_action("idle")
	elif player.state == "skill_v" and frame == 16:player.set_action("idle")
	elif player.state == "skill_w" and frame >= 40 and frame <= 109 and not bool(_held.get("held_w",false)):player.seek_action_frame(110)
	if action.has("child_x_target") and (not action.has("child_x_frames") or frame >= int(action.child_x_frames[0]) and frame <= int(action.child_x_frames[1])):
		player.action_child_x = Actor.twips(player.action_child_x+(float(action.child_x_target)-player.action_child_x)/float(action.child_x_divisor))
		player.visual.position.x = float(action.get("visual_offset",Vector2.ZERO).x)+_crt2_child_delta()*player.visual_scale.x*player.facing
		player.body_local_x = Actor.twips(player.body_local_x+(float(action.get("gravity_body_x_target",4.7))-player.body_local_x)/float(action.get("gravity_body_x_divisor",action.child_x_divisor)))
	_advance_crt2_grab()
	_advance_crt2_timers()
	_advance_crt2_air()
	_advance_crt2_objects()
	_advance_crt2_bleeds()
	_crt2_sync_appearance()
	for key: String in ["slash_가로","slash_왼대각","slash_오른대각"]:
		if _crt2_views.has(key):_crt2_views[key].set_source_frame(mini(7,int(session.run.source_ticks)-int(crt2[key+"_born"])+1))
	if player.state == "skill_w" and frame >= 13 and frame <= 108:
		_crt2_suction(4509,89,5)
	if player.state == "skill_w" and frame >= 13 and frame <= 119:combo = 0;combo_frame = 1
	if player.state == "skill_w" and frame >= 119 and frame <= 128:_crt2_push_air(10 if frame <= 121 else 8)
	if player.state == "skill_d" and frame >= 28 and frame <= 35:_crt2_push_air(20)
	if player.state == "skill_v" and frame >= 66 and frame <= 79:_crt2_push_air(8)
	if (player.state == "skill_e" and frame >= 35 and frame <= 82) or (player.state == "skill_r" and frame >= 47 and frame <= 129):
		for target: Node2D in enemies:
			if target.airborne:_source_shift_x(target,signf(player.position.x-target.position.x)*.8)
	if _crt2_views.has("r_cutin"):
		var cutin_frame := 66+int(session.run.source_ticks)-int(crt2.cutin_born)
		if cutin_frame >= 97:_crt2_remove_view("r_cutin")
		else:_crt2_views.r_cutin.set_source_frame(cutin_frame)
	if player.state == "skill_r" and frame >= 47 and frame <= 129:
		crt2.r_air_frame = (frame-47)%7+1
		var spec := _crt2_geometry("r_air")
		var parent := _matrix(action.parent_matrix)*_matrix(spec.placements_by_source_frame[str(frame)][0].matrix)
		for part: Dictionary in spec.get("parts",[]):
			_crt2_view("r_part_"+str(int(part.source_id)),str(part.animation),(frame-47)%int(part.frame_count)+1,parent*_matrix(spec.removed_subtree_placement.matrix)*_matrix(part.matrix))
		_crt2_view("r_air",str(spec.animation),int(crt2.r_air_frame),parent)
	else:
		crt2.r_air_frame = 1;_crt2_remove_view("r_air")
		for id: int in [5601,5609,5616]:_crt2_remove_view("r_part_"+str(id))
	if player.state == "hit" and frame == 2:_play_source_audio("player_hit_fx",2)

func _crt2_sync_appearance() -> void:
	var action: Dictionary = player.definition.actions[player.state]
	var key := str(action.animation)
	var variants: Dictionary = _crt2_component("visuals").get("variants",{})
	if int(crt2.appearance_pren) == 1:key = str(variants.get(key,key))
	if player.visual.definition != database.assets.animations[key]:player.visual.configure(database.assets.animations[key])
	player.visual.set_source_frame(player.source_frame)

func _advance_crt2_timers() -> void:
	for id: String in ["frenzy","rage","lust"]:
		var field := id+"_frame"
		var frame := int(crt2[field])
		var spec := _crt2_component(id)
		if frame <= 1:continue
		if int(crt2.get(id+"_born",-1)) != int(session.run.source_ticks):
			frame = mini(9,frame+1) if id == "frenzy" else frame+1
		if id != "frenzy" and frame > int(spec.end_frame):frame = 1
		crt2[field] = frame
		if id == "frenzy" and frame == 9:pren = 1;crt2.appearance_pren = 1
		var key := "crt2_g_timer" if id == "rage" else "crt2_lust_timer"
		if id != "frenzy":
			if frame <= 1:_crt2_remove_view(id)
			else:
				var timer: Dictionary = _crt2_geometry("timers")[str(int(spec.source_id))]
				var visual_frame := int(timer.constant_visual_frame) if frame >= int(timer.constant_frame_range[0]) and frame <= int(timer.constant_frame_range[1]) else frame
				_crt2_view(id,key,visual_frame,_matrix(timer.parent_placement.matrix))
	if pren == 1:player.hp -= .01
	if player.hp <= 5 and int(crt2.frenzy_frame) > 1:
		crt2.frenzy_frame = 1;pren = 0;crt2.appearance_pren = 1
		_record("crt2_frenzy_low_hp",{"hp":player.hp,"source_parts_page":2})
	if int(crt2.frenzy_frame) == 9:
		var aura := _crt2_geometry("h_aura")
		var age := int(session.run.source_ticks)-int(crt2.get("frenzy_born",0))-7
		_crt2_view("h_aura",str(aura.animation),maxi(0,age)%int(aura.frame_count)+1,_matrix(_crt2_component("frenzy").parent_matrix)*_matrix(aura.placement.matrix))
	else:_crt2_remove_view("h_aura")

func _crt2_push_air(amount: float) -> void:
	for target: Node2D in enemies:
		if target.hp > 0 and target.airborne:_source_shift_x(target,signf(target.position.x-player.position.x)*amount)

func _crt2_suction(helper: int, depth: int, amount: float) -> void:
	var table: Dictionary = database.assets.source_geometry.act04_crt2_hit_windows.timelines[str(int(player.definition.actions[player.state].source_id))]
	for hit: Dictionary in table.active_by_source_frame.get(str(player.source_frame),[]):
		if int(hit.source_id) != helper or int(hit.depth) != depth:continue
		var r: Array = hit.rect
		var local: Rect2 = _matrix(player.definition.actions[player.state].parent_matrix)*Rect2(r[0],r[1],r[2],r[3])
		for target: Node2D in enemies:
			if target.hp > 0 and _overlaps(player.transform_rect(local),target.hurt_rect()):_source_shift_x(target,signf(player.position.x-target.position.x)*amount)

func _advance_crt2_grab() -> void:
	if player.state not in ["skill_d","skill_v"]:return
	var spec := _crt2_component("grab_d" if player.state == "skill_d" else "grab_v")
	var frame: int = player.source_frame
	if frame >= int(spec.release_frame):zab = ""
	for target: Node2D in enemies:
		if target.identifier != zab or target.hp <= 0:continue
		var rows: Array = []
		if player.state == "skill_v":rows = spec.anchor_track.get(str(frame),[]) if frame <= 65 else []
		else:
			for track: Dictionary in spec.anchor_tracks.values():rows.append_array(track.get(str(frame),[]))
		for row: Dictionary in rows:
			var m: Array = row.matrix
			var parent: Array = spec.parent_matrix
			target.position = player.position+Vector2((parent[4]+m[4])*player.facing,parent[5]+m[5])
			target.airborne = true
			if player.state == "skill_d" and int(row.get("source_id",5260)) != 414:target.vertical_speed = 0;target.gravity_acceleration = 0
			else:target.vertical_speed += -2.0 if player.state == "skill_v" else -1.1;target.gravity_acceleration += .1
	if player.state == "skill_d" and frame >= 16 and frame <= 39:
		var data := _crt2_geometry("d_blood")
		var rows: Array = data.placements_by_source_frame.get(str(frame),[])
		if not rows.is_empty():
			if frame == 16:crt2["blood_frame"] = 1
			if frame == 28:
				for target: Node2D in enemies:
					if _crt2_bleeds.has(target.identifier) and _crt2_helper_touches(5291,30,target):crt2.blood_frame = 21
			elif int(crt2.get("blood_frame",1)) > 1:crt2.blood_frame = mini(40,int(crt2.blood_frame)+1)
			if int(crt2.get("blood_frame",1)) > 1:_crt2_view("d_blood",str(data.animation),int(crt2.blood_frame),_matrix(spec.parent_matrix)*_matrix(rows[0].matrix))
			else:_crt2_remove_view("d_blood") # Source1 is empty/stopped; selected atlas starts21.
	else:_crt2_remove_view("d_blood")

func _crt2_helper_touches(helper: int, depth: int, target: Node2D) -> bool:
	var action: Dictionary = player.definition.actions[player.state]
	for row: Dictionary in database.assets.source_geometry.act04_crt2_hit_windows.timelines[str(int(action.source_id))].active_by_source_frame.get(str(player.source_frame),[]):
		if int(row.source_id) != helper or int(row.depth) != depth:continue
		var r: Array = row.rect
		var status: Dictionary = database.assets.source_geometry.enemy_status.enemy_parent_placements[str(int(target.definition.source_id))]
		var bleed: Dictionary = _crt2_geometry("bleed_helper")
		var b: Array = bleed.rect_status_local
		var scale := Transform2D(Vector2(target.visual_scale.x,0),Vector2(0,target.visual_scale.y),Vector2.ZERO)
		var blood_body: Rect2 = target.visual_parent().global_transform*scale*_matrix(status.matrix)*Rect2(b[0],b[1],b[2],b[3])
		if _overlaps(player.transform_rect(_matrix(action.parent_matrix)*Rect2(r[0],r[1],r[2],r[3])),blood_body):return true
	return false

func _crt2_air_z(entry: int, immediate_cd: bool) -> bool:
	if int(crt2.air_frame) != 1 or not _try_skill("jump_z"):return false
	player.seek_action_frame(entry,true)
	if not immediate_cd:player.cooldowns["jump_z"] = 0
	_record("crt2_air_z",{"entry":entry,"immediate_cd":immediate_cd})
	return true

func _advance_crt2_air() -> void:
	if player.state == "jump_z":
		if player.source_frame == 61:player.body_frame = 7
		if player.source_frame == 67:
			player.set_action("jump");player.seek_action_frame(28,true)
		return
	if player.state != "jump":crt2.air_frame = 1;_crt2_remove_view("air_x");return
	var frame: int = player.source_frame
	var spec := _crt2_component("jump")
	if frame >= 4 and frame <= 30:
		if bool(_held.get("right",false)):_move_player(4);player.set_facing(1 if int(crt2.air_frame) == 1 else player.facing)
		if bool(_held.get("left",false)):_move_player(-4);player.set_facing(-1 if int(crt2.air_frame) == 1 else player.facing)
	if bool(_held.get("held_z",false)) and int(crt2.air_frame) == 1 and spec.air_z.later_poll_sources.has(str(frame)):
		if _crt2_air_z(int(spec.air_z.later_poll_sources[str(frame)]),false):return
	var parts: Array = _crt2_geometry("jump").parts
	var rows: Array = parts[0].placements_by_source_frame.get(str(frame),[])
	if rows.is_empty():crt2.air_frame = 1;_crt2_remove_view("air_x");return
	var sub := int(crt2.air_frame)
	if sub > 1:sub = 1 if sub >= 12 else sub+1
	if sub == 1 and bool(_held.get("held_attack",false)):sub = 2
	crt2.air_frame = sub;player.air_action_frame = sub
	var key: String = parts[0].animation
	var variants: Dictionary = _crt2_component("visuals").variants
	if int(crt2.appearance_pren) == 1:key = variants.get(key,key)
	_crt2_view("air_x",key,sub,_matrix(spec.parent_matrix)*_matrix(rows[0].matrix))
	for event: Dictionary in player.definition.actions.air_x.events:
		if event.kind == "sound" and int(event.frame) == sub:_on_action_event(player,event)
	for window: Dictionary in player.definition.actions.air_x.windows:
		if sub < int(window.from) or sub > int(window.until):continue
		for rect: Rect2 in window.local_rects:
			var box: Rect2 = player.transform_rect(_matrix(spec.parent_matrix)*_matrix(rows[0].matrix)*rect)
			for target: Node2D in enemies:
				if target.hp > 0 and _overlaps(box,target.hurt_rect()):_start_marker(player,target,float(window.gravity),"CRT2 air5416")
	# The transparent5417 is a distinct named sword-feedback helper at child5.
	if sub == 5:
		var left: Array = parts[1].placements_by_source_frame.get(str(frame),[])
		if not left.is_empty():
			var shape: Dictionary = spec.children.left_rect.source5_helper["5"][0]
			var rect: Array = database.assets.source_geometry.act04_crt2_hit_windows.hit_shapes["439"].rect
			var box: Rect2 = player.transform_rect(_matrix(spec.parent_matrix)*_matrix(left[0].matrix)*_matrix(shape.matrix)*Rect2(rect[0],rect[1],rect[2],rect[3]))
			for target: Node2D in enemies:
				if _overlaps(box,_crt2_feedback_bodies.get(target.identifier,Rect2())):_crt2_slash(target,"왼대각")

func _crt2_spawn(id: int, at: Vector2) -> void:
	var map := {803:"crt2_f_charge",1077:"crt2_f_burst",574:"crt2_air_z_right",971:"crt2_air_z_left",685:"crt2_e_right",676:"crt2_e_left",1023:"crt2_q_dust_right",593:"crt2_q_dust_left"}
	if not map.has(id):push_error("缺少CRT2源对象%d"%id);return
	var visual := _new_source_visual(map[id],self)
	visual.position = at;visual.set_source_frame(2 if id == 1077 else 1)
	var item := {"source_id":id,"frame":1,"child_frame":2 if id == 1077 else 1,"timer":0,"born":int(session.run.source_ticks),"position":at,"visual":visual,"facing":player.facing}
	_crt2_objects.append(item)
	if id == 1077:_crt2_component_sounds(_crt2_component("f_second"),1)
	_record("crt2_object_spawn",{"source_id":id,"position":at})

func _advance_crt2_objects() -> void:
	for item: Dictionary in _crt2_objects.duplicate():
		var id := int(item.source_id)
		if int(item.born) != int(session.run.source_ticks):
			if id in [685,676]:
				if int(item.frame) == 1 and player.source_frame == 51:item.frame = 2;item.child_frame = 1
				elif int(item.frame) == 7 and (player.source_frame == 81 or player.parent_frame == 68):item.frame = 8;item.child_frame = 1
				elif int(item.frame) not in [1,7]:item.frame += 1
			else:item.frame += 1
		var frame := int(item.frame)
		var end := int(_crt2_geometry("derived_spawns")[str(id)].frame_count)
		if frame >= end:
			item.visual.queue_free();_crt2_objects.erase(item);continue
		if id == 803:
			if int(item.child_frame) == 2:
				item.timer += 1
				if int(item.timer) >= 23:item.child_frame = 3
			else:item.child_frame += 1 if frame > 1 else 0
			var spec: Dictionary = _crt2_geometry("f").independent_child
			item.visual.transform = Transform2D(0,item.position)*_matrix(spec.placements_by_source_frame[str(frame)][0].matrix)
			item.visual.set_source_frame(mini(36,int(item.child_frame)))
			if int(item.child_frame) == 2:
				var rows: Array = spec.inner_charge.placements_by_source_frame.get("2",[])
				if not rows.is_empty():
					var core := _crt2_view("f_core_"+str(item.born),"crt2_f_charge_core",maxi(1,mini(23,int(item.timer))),item.visual.transform*_matrix(rows[0].matrix),false)
					core.z_index = item.visual.z_index+1
			else:_crt2_remove_view("f_core_"+str(item.born))
			if frame == 23:_crt2_spawn(1077,item.position)
		elif id == 1077:
			item.child_frame = mini(21,frame+1)
			item.visual.transform = Transform2D(0,item.position)*_matrix(_crt2_component("f_second").child.matrix)
			item.visual.set_source_frame(int(item.child_frame))
			if frame > 1:_crt2_component_sounds(_crt2_component("f_second"),frame)
		elif id in [685,676]:
			item.visual.set_source_frame(frame)
			item.child_frame = mini(9,int(item.child_frame)+1)
			var rows: Array = _crt2_geometry("e_charge").placements_by_host[str(id)].get(str(frame),[])
			if not rows.is_empty():_crt2_view("e_charge_"+str(item.born),"crt2_e_charge",int(item.child_frame),Transform2D(0,item.position)*_matrix(rows[0].matrix),false)
			else:_crt2_remove_view("e_charge_"+str(item.born))
		else:item.visual.set_source_frame(frame)
		var table: Dictionary = database.assets.source_geometry.act04_crt2_hit_windows.timelines.get(str(id),{})
		for hit: Dictionary in table.get("active_by_source_frame",{}).get(str(frame),[]):
			var r: Array = hit.rect
			var box := Rect2(item.position+Vector2(r[0],r[1]),Vector2(r[2],r[3]))
			for target: Node2D in enemies:
				if target.hp > 0 and _overlaps(box,target.hurt_rect()):_start_marker(player,target,-12 if id == 803 else (-6 if id in [574,971] else -5),"CRT2 object"+str(id))

func _crt2_sound_alias(alias: String) -> void:
	var spec: Dictionary = database.assets.audio_events[alias]
	audio.play_sfx(alias,float(spec.get("in_point_samples_44100",0))/44100.0)

func _crt2_component_sounds(component: Dictionary, frame: int) -> void:
	for event: Dictionary in component.get("sounds",[]):
		if int(event.frame) != frame:continue
		if event.get("audio_stream") is AudioStream:audio.play_stream(event.audio_stream,float(event.get("offset",0)),str(event.get("sound","")))
		else:audio.play_sfx(str(event.sound),float(event.get("offset",0)))

func _crt2_bleed(target: Node2D) -> void:
	if _crt2_bleeds.has(target.identifier):return
	var spec := _crt2_component("bleed_status")
	var visual := _new_source_visual("enemy_bleed",target.visual_parent())
	var status: Dictionary = database.assets.source_geometry.enemy_status.enemy_parent_placements[str(int(target.definition.source_id))]
	visual.transform = Transform2D(Vector2(target.visual_scale.x,0),Vector2(0,target.visual_scale.y),Vector2.ZERO)*_matrix(status.matrix)*_matrix(spec.visual_matrix)
	_crt2_bleeds[target.identifier] = {"target":target,"age":0,"visual":visual}
	_record("crt2_bleed",{"target":target.identifier,"source_status_frame":20})

func _advance_crt2_bleeds() -> void:
	for key: String in _crt2_bleeds.keys():
		var item: Dictionary = _crt2_bleeds[key]
		if item.target.hp <= 0:item.visual.queue_free();_crt2_bleeds.erase(key);continue
		var sub := int(item.age)%12+1
		item.visual.set_source_frame(sub)
		if sub == 1:deal_damage(player,item.target,2,"CRT2 source4021 page20 bleed4000 frame1",false)
		item.age += 1 # 4003 holds140; unknown unqualified callback does not justify auto-clear.

func _crt2_sword_feedback() -> void:
	var action: Dictionary = player.definition.actions[player.state]
	var table: Dictionary = database.assets.source_geometry.act04_crt2_hit_windows.timelines.get(str(int(action.source_id)),{})
	for row: Dictionary in table.get("active_by_source_frame",{}).get(str(player.source_frame),[]):
		if str(row.get("name","")) not in ["가로","왼대각","오른대각"]:continue
		var r: Array = row.rect
		var local: Rect2 = _matrix(action.parent_matrix)*Rect2(r[0],r[1],r[2],r[3])
		local.position.x += _crt2_child_delta()
		for target: Node2D in enemies:
			if _overlaps(player.transform_rect(local),_crt2_feedback_bodies.get(target.identifier,Rect2())):_crt2_slash(target,str(row.name))

func _crt2_slash(target: Node2D, category: String) -> void:
	# Root41's three independent named-helper listeners attach at AS depths1/2/3
	# (dynamic attach depths are above static timeline depths). Equality executes
	# both source if-statements; the latter replaces the same category depth.
	var choices: Array[String] = []
	if category == "가로":choices.append("horizontal")
	else:
		if player.position.x <= target.position.x:choices.append("left" if category == "왼대각" else "right")
		if player.position.x >= target.position.x:choices.append("right" if category == "왼대각" else "left")
	var key := "slash_"+category
	for orientation: String in choices:
		_crt2_remove_view(key)
		var view := _crt2_view(key,"crt2_hit_slash_"+orientation,1,Transform2D(0,target.position),false)
		view.z_index = 4096
		view.set_meta("source_attach_depth",{"가로":1,"왼대각":2,"오른대각":3}[category])
		crt2[key+"_born"] = int(session.run.source_ticks)
		audio.play_sfx("crt2_hit_slash_sound6")
	for id: String in ["slash_가로","slash_왼대각","slash_오른대각"]:
		if _crt2_views.has(id):move_child(_crt2_views[id],get_child_count()-1)

func _crt2_clear() -> void:
	for item: Dictionary in _crt2_objects:
		if is_instance_valid(item.visual):item.visual.queue_free()
	_crt2_objects.clear()
	for key: String in _crt2_views.keys():_crt2_remove_view(key)
	for item: Dictionary in _crt2_bleeds.values():
		if is_instance_valid(item.visual):item.visual.queue_free()
	_crt2_bleeds.clear()
	pren = 0;zab = "";crt2.frenzy_frame = 1;crt2.rage_frame = 1;crt2.lust_frame = 1


# CRT3 source adapters use this Battle, Actor, marker and AudioDirector chain.
# Their data lives in the same author Resource tree as the existing characters.
func _crt3_component(id: String) -> Dictionary:
	return player.definition.get("components",{}).get(id,{})
func _crt3_geometry() -> Dictionary:
	return _crt3_component("visuals").get("geometry",{})
func _crt3_action_started(id: String) -> void:
	_crt3_contacts.clear()
	if bool(player.definition.actions[id].get("reset_combo_counters",false)):crt3.rigui=0;crt3.pyeongta=0
	if id in ["basic","basic2"]:crt3.pyeongta=mini(2,int(crt3.pyeongta)+1)
	if id in ["skill_s","skill_s2"]:crt3.rigui=mini(2,int(crt3.rigui)+1)
	if id=="skill_d":crt3.d_count=1
	elif id.begins_with("skill_d"):crt3.d_count+=1
	if id=="skill_q":crt3.q_count=0
	if id=="skill_w":crt3.w_cut=0;crt3.w_key=0
	if id=="skill_v":zab=""
	if id=="jump":crt3.air_frame=1
	if id=="backstep":crt3.back_frame=1
	if id=="skill_e":crt3.e_slot_frame=1;crt3.e_slot_playing=false
func _crt3_begin(id: String) -> bool:
	if not _start_actor_action(id):return false
	_crt3_action_started(id)
	return true
func _crt3_input(input: Dictionary) -> void:
	if player.state=="skill_w" and bool(input.get("jump",false)):
		player.set_action("idle");return
	var action: Dictionary=player.definition.actions[player.state]
	for branch: Dictionary in action.get("branches",[]):
		if str(branch.get("kind",""))!="keydown_held" or player.source_frame<int(branch.from) or player.source_frame>int(branch.until):continue
		var key: String={68:"skill",71:"load_g"}.get(int(branch.get("keycode",0)),"")
		if not key.is_empty() and bool(input.get(key,false)):
			player.set_action(str(branch.next));_crt3_action_started(str(branch.next));return
	if player.state=="jump" and player.source_frame>=4 and player.source_frame<=27 and bool(input.get("skill_z",false)) and int(crt3.air_frame)==1:
		_crt3_air_z(63,false);return
	var serial: int=player.action_serial
	for key: String in ["skill_a","skill_z","skill","load_f","load_g","load_h","skill_q","skill_w","skill_e","skill_v"]:
		if not bool(input.get(key,false)):continue
		var id: String={"skill_a":"skill_a","skill_z":"skill_a","skill":"skill_d","load_f":"skill_f","load_g":"skill_g","load_h":"skill_h"}.get(key,key)
		if _try_skill(_resolve_author_input(key,id)):return
	_dispatch_custom_inputs(input)
	if serial!=player.action_serial:return
	var s_pressed:=bool(input.get("skill_s",false))
	var x_pressed:=bool(input.get("attack",false))
	if player.state in ["idle","move"]:
		if x_pressed:_crt3_begin("basic")
		elif s_pressed:_crt3_begin("skill_s")
		elif bool(input.get("jump",false)):_crt3_begin("jump")
		elif bool(input.get("down",false)):_crt3_begin("backstep")
		return
	if bool(input.get("down",false)) and player.parent_frame in [106,107,108,117,118,119]:_crt3_begin("backstep");return
	for branch: Dictionary in _crt3_component("combo").get("branches",[]):
		if int(branch.source_id)!=int(action.source_id):continue
		if not branch.has("listener_from") or player.source_frame<int(branch.listener_from) or player.source_frame>=int(branch.listener_until_control):continue
		if str(branch.input).contains(" S") and s_pressed:
			if branch.has("target_by_rigui"):_crt3_begin(["skill_s","skill_s2","skill_s3"][mini(2,int(crt3.rigui))]);return
			if player.state=="skill_s2":_crt3_begin("skill_s3");return
		elif str(branch.input).contains(" X") and x_pressed:
			var target:=int(branch.get("target_parent",106+int(crt3.pyeongta)))
			if target==106 and player.state=="basic":
				player.play_source_parent()
			else:_crt3_begin({106:"basic",107:"basic2",108:"basic3"}.get(target,"basic3"))
			return
func _crt3_event(actor: Node2D,event: Dictionary) -> void:
	if actor!=player:return
	match str(event.kind):
		"crt3_hit":_crt3_hit(event)
		"crt3_goto_source":player.seek_action_frame(int(event.target_frame),true)
		"crt3_set_counter":
			if str(event.get("name",""))=="맹룡포인트":crt3.q_count=int(event.value)
		"crt3_add_counter":
			if str(event.get("name",""))=="맹룡포인트":crt3.q_count+=int(event.value)
		"crt3_random_script_sound":_crt3_random_sound("crt3_q_random_",2)
		"crt3_over_start":
			crt3.h_frame=2;crt3.over=0;crt3["h_born"]=int(session.run.source_ticks);_crt3_sounds(4614,2)
		"crt3_cutin":
			var spec: Dictionary=_crt3_geometry().cutin
			var placement: Dictionary=spec.root_placements_by_source_frame[str(int(stage.source_root_frame))][0]
			var view:=_crt3_view("e_cutin","hud_crt3_e_cutin",98,_matrix(placement.matrix),false)
			view.z_index=int(placement.depth);crt3["cutin_born"]=int(session.run.source_ticks)
		"crt3_e_start":
			crt3.e_active=true;crt3.e_w_frame=1;crt3.e_start_frame=1;crt3.e_circle_frame=1
			crt3["e_born"]=int(session.run.source_ticks);crt3["e_skill_x"]=player.position.x+125*player.facing
		"crt3_body_goto_stop":player.body_frame=int(event.target_frame);player.body_stopped=true
		"crt3_slot_start":player.cooldowns["jump_z"]=int(player.definition.actions.jump_z.cooldown_ticks)
		"crt3_spawn":_crt3_spawn(int(event.right_id)if player.facing==1 else int(event.left_id),player.position)
		"crt3_release_grab":zab=""
func _crt3_sound(alias: String) -> void:
	var spec: Dictionary=_crt3_component("visuals").sounds.get(alias,{})
	if spec.is_empty():push_error("CRT3 sound missing: "+alias);return
	audio.play_stream(spec.audio_stream,float(spec.get("offset",0)),alias)
func _crt3_random_sound(prefix: String,count: int) -> void:
	var choice:=randi_range(0,count-1)
	_crt3_sound(prefix+str(choice));_record("crt3_random_sound",{"choice":choice,"prefix":prefix})
func _crt3_sounds(source_id: int,frame: int) -> void:
	var prefix: String={4614:"crt3_h_timer",6308:"crt3_jump_attack",6156:"crt3_backstep_attack",6276:"crt3_e_actor",6299:"crt3_e_start",6259:"crt3_e_hit",166:"crt3_w_illusion"}.get(source_id,"crt3_child_"+str(source_id))
	for alias: String in _crt3_component("visuals").get("sounds",{}):
		if alias!=prefix and not (alias.begins_with(prefix+"_sound_")and alias.trim_prefix(prefix+"_sound_").is_valid_int()):continue
		var event: Dictionary=_crt3_component("visuals").sounds[alias]
		if int(event.sprite_id)==source_id and int(event.frame)==frame:_crt3_sound(alias)
func _crt3_view(id: String,key: String,frame: int,local:=Transform2D.IDENTITY,attached:=true,alpha_mult:=256) -> Node2D:
	if database.assets.animations[key].has("baked_placement_matrix"):local=local*_matrix(database.assets.animations[key].baked_placement_matrix).affine_inverse()
	var view: Node2D=_crt3_views.get(id)
	if not is_instance_valid(view):view=_new_source_visual(key,player.visual_parent()if attached else self);_crt3_views[id]=view
	elif view.definition!=database.assets.animations[key]:view.configure(database.assets.animations[key])
	if attached:
		var size: Vector2=player.visual_scale*Vector2(player.facing,1)
		view.transform=Transform2D(Vector2(size.x,0),Vector2(0,size.y),Vector2.ZERO)*local
	else:view.transform=local
	view.visible=true;view.modulate.a=float(alpha_mult)/256.0;view.set_source_frame(frame)
	return view
func _crt3_remove_view(id: String) -> void:
	if is_instance_valid(_crt3_views.get(id)):_crt3_views[id].queue_free()
	_crt3_views.erase(id)
	_crt3_clocks.erase(id)
func _crt3_rows(host: int,frame: int,child: int) -> Array:
	var rows: Array=_crt3_geometry().get("tracks",{}).get(str(host),{}).get(str(child),{}).get(str(frame),[])
	return rows
func _crt3_hit(event: Dictionary) -> void:
	var rule: Dictionary=event.source_rule
	var kind:=str(rule.get("kind",""))
	if kind in ["marker_observer","marker_bonus","grab_anchor","grab_target_observer"]:return
	for target: Node2D in enemies:
		if target.hp<=0:continue
		var contact:=false
		for local: Rect2 in event.get("local_rects",[]):
			var box: Rect2=player.transform_rect(local);_active_boxes.append(box)
			if _overlaps(box,target.hurt_rect()):contact=true
		if not contact:continue
		if kind=="named_common_slash":
			if str(rule.category)=="horizontal":_crt3_slash(target,"horizontal")
			else:
				if target.position.x<=player.position.x:_crt3_slash(target,"left"if str(rule.category)=="left"else"right")
				if target.position.x>=player.position.x:_crt3_slash(target,"right"if str(rule.category)=="left"else"left")
			continue
		var token: String=str(player.action_serial)+":"+str(event.source_depth)+":"+str(event.get("source_helper",0))+":"+str(event.get("source_birth_frame",1))+":"+str(crt3.q_count)+":"+target.identifier
		var limit: int=int(rule.get("normal_contact_limit_per_target",rule.get("max_mr_per_enemy",rule.get("mr_gate",0)))if rule.get("normal_contact_limit_per_target",rule.get("max_mr_per_enemy",rule.get("mr_gate",0)))!=null else 0)
		if limit>0 and int(_crt3_contacts.get(token,0))>=limit:continue
		_crt3_contacts[token]=int(_crt3_contacts.get(token,0))+1
		if kind=="grab_acquire":
			if zab.is_empty() and not target.frozen:zab=target.identifier;player.seek_action_frame(17,true);_record("crt3_grab_acquired",{"target":zab})
			return
		if rule.get("direct_damage")!=null and float(rule.get("direct_damage",0))>0:deal_damage(player,target,float(rule.direct_damage),"CRT3 direct source contact",false)
		if rule.has("status"):
			var status: Variant=rule.status
			if str(status).contains("shock") or str(status).contains("감전"):_set_enemy_status(enemies[0]if player.state=="skill_q_finish"else target,"shock")
		if rule.get("gravity")!=null:
			var restart: bool=rule.get("reset_air_marker_to",rule.get("marker_seek"))!=null
			_lift_target(player,target,float(rule.gravity),"CRT3 "+player.state,restart)
func _crt3_slash(target: Node2D,category: String) -> void:
	var orientation: String={"left":"left","right":"right","horizontal":"horizontal"}.get(category,"horizontal")
	var id: String="slash_"+orientation
	var view:=_crt3_view(id,"crt2_hit_slash_"+orientation,1,Transform2D(0,target.position),false)
	if view.get_parent()!=_source_dynamic_parent():view.reparent(_source_dynamic_parent(),false)
	view.z_index=int({"horizontal":1,"left":2,"right":3}[orientation])
	view.set_meta("source_dynamic_depth",view.z_index)
	crt3[id+"_born"]=int(session.run.source_ticks)
	_crt3_sound("crt3_slash_contact")
func _crt3_marker_bonus(_target: Node2D,frame: int) -> float:
	var amount:=0.0
	var seen:={}
	for window: Dictionary in player.definition.actions[player.state].get("windows",[]):
		if frame<int(window.from)or frame>int(window.until):continue
		if int(window.source_rule.get("observer_marker_frame",2))!=2:continue
		var key:=str(window.source_depth)+":"+str(window.source_helper)
		if seen.has(key):continue
		seen[key]=true
		var rule: Dictionary=window.source_rule
		amount+=float(rule.get("marker_bonus",rule.get("observer_damage",rule.get("damage",0)))if rule.get("marker_bonus",rule.get("observer_damage",rule.get("damage",0)))!=null else 0)
	if int(crt3.h_frame)>=9:amount+=9 if int(crt3.h_frame)<=400 else 5
	for spec: Dictionary in _crt3_component("visuals").get("independent_windows",[]):
		if int(spec.source_id)==4614:continue # H's five explicit observers are represented once per target above.
		var clocks: Array=[]
		if int(spec.source_id)==6276 and bool(crt3.e_active):clocks.append(int(crt3.e_w_frame))
		for item: Dictionary in _crt3_objects:
			if int(item.source_id)==int(spec.source_id):clocks.append(int(item.frame))
		for clock_frame: int in clocks:
			if not _source_has(spec.get("active_source_frames",[]),clock_frame):continue
			var rule: Dictionary=spec.default_rule
			if int(rule.get("observer_marker_frame",2))==2:amount+=float(rule.get("observer_damage",rule.get("marker_bonus",0)))
	return amount
func _advance_crt3_components(previous: String) -> void:
	var action: Dictionary=player.definition.actions[player.state]
	var frame: int=player.source_frame
	if player.state=="idle":crt3.rigui=0;crt3.pyeongta=0;crt3.d_count=0;crt3.q_count=0
	if previous=="skill_v" and player.state!="skill_v":zab=""
	if player.state in ["hit","knockdown","fallen","dead"] and bool(crt3.e_active):_crt3_end_e(false)
	if player.state=="dead":crt3.h_frame=1;crt3.over=0;zab=""
	for motion: Dictionary in action.get("source_motion",[])if action.get("source_motion")is Array else []:
		if frame>=int(motion.from)and frame<=int(motion.until):_move_player((float(motion.dx)+float(player.definition.get("speed_bonus",0))if bool(motion.get("add_spd",false))else float(motion.dx))*player.facing)
	var polls: Dictionary=_crt3_component("d_chain").get("direction_poll_frames",{})
	var d_direction: bool=player.state.begins_with("skill_d") and polls.has(str(int(action.source_id))) and frame>=int(polls[str(int(action.source_id))][0])and frame<=int(polls[str(int(action.source_id))][-1])
	if d_direction or player.state=="skill_f"and frame==15 or player.state=="skill_q"and frame<=6 or player.state=="skill_q_finish"and frame<=4:
		if bool(_held.get("right",false)):player.set_facing(1)
		if bool(_held.get("left",false)):player.set_facing(-1)
	if player.state=="skill_s" and frame>8 and frame<17:
		if bool(_held.get("held_s",false)):_crt3_begin("skill_s2")
		if bool(_held.get("held_attack",false)):_crt3_begin(["basic","basic2","basic3"][mini(2,int(crt3.pyeongta))])
	if player.state=="skill_q"and frame>=13 and frame<=21 and bool(_held.get("held_q",false)):
		if int(crt3.q_count)<3:player.seek_action_frame(1,true)
		else:player.set_action("skill_q_finish")
	if player.state=="skill_w":_advance_crt3_w()
	if player.state=="skill_f":
		_advance_crt3_f()
		if frame<=14:_crt3_push_air(3.5)
	else:_crt3_remove_view("f_hit")
	if player.state=="skill_v"and frame>=65:_crt3_push_air(8)
	_advance_crt3_air()
	_advance_crt3_grab()
	_advance_crt3_over()
	_advance_crt3_e()
	_advance_crt3_screen()
	_advance_crt3_objects()
	for id: String in _crt3_views.keys():
		if not id.begins_with("slash_"):continue
		var sub:=int(session.run.source_ticks)-int(crt3.get(id+"_born",0))+1
		if sub>=7:_crt3_remove_view(id)
		else:_crt3_views[id].set_source_frame(sub)
	if _crt3_views.has("e_cutin"):
		var cutin_frame:=98+int(session.run.source_ticks)-int(crt3.cutin_born)
		if cutin_frame>=129 or player.state!="skill_e":_crt3_remove_view("e_cutin")
		else:_crt3_views.e_cutin.set_source_frame(cutin_frame)
func _advance_crt3_over() -> void:
	if int(crt3.h_frame)<=1:_crt3_remove_view("h_timer");return
	if int(crt3.get("h_born",-1))!=int(session.run.source_ticks):crt3.h_frame+=1
	if int(crt3.h_frame)>407:crt3.h_frame=1;crt3.over=0;_crt3_remove_view("h_timer");return
	if int(crt3.h_frame)==9:crt3.over=1
	var frame:=int(crt3.h_frame)
	if frame>2:_crt3_sounds(4614,frame)
	var visual_frame:=9 if frame>=9 and frame<=400 else frame
	var spec: Dictionary=_crt3_component("overdrive")
	_crt3_view("h_timer","crt3_h_timer",visual_frame,_matrix(spec.parent_placement.matrix))
func _crt3_air_z(entry: int,immediate: bool) -> bool:
	var body_age: int=player.body_frame
	var body_stop: bool=player.body_stopped
	if int(crt3.air_frame)!=1 or not _try_skill("jump_z"):return false
	player.body_frame=body_age;player.body_stopped=body_stop
	player.seek_action_frame(entry,true)
	player.cooldowns["jump_z"]=int(player.definition.actions.jump_z.cooldown_ticks)if immediate else 0
	_record("crt3_air_z",{"entry":entry,"immediate_cd":immediate})
	return true
func _advance_crt3_air() -> void:
	if player.state=="jump":
		var frame: int=player.source_frame
		if frame>=4 and frame<=29:
			if bool(_held.get("right",false)):_move_player(4);player.set_facing(1 if int(crt3.air_frame)==1 else player.facing)
			if bool(_held.get("left",false)):_move_player(-4);player.set_facing(-1 if int(crt3.air_frame)==1 else player.facing)
		if int(crt3.air_frame)==1 and bool(_held.get("held_z",false)):
			var branches: Array=_crt3_component("jump").z_branches
			# The two original listeners can race. Choose the actor-child listener
			# first while present; never charge two simultaneous callbacks.
			for branch: Dictionary in branches:
				if frame>=int(branch.from)and frame<=int(branch.until):
					if _crt3_air_z(int(branch.target_frame),bool(branch.get("immediate_slot_start",false))):_crt3_remove_view("air_x");return
		var rows:=_crt3_rows(6311,frame,6308)
		if not rows.is_empty():
			var sub:=int(crt3.air_frame)
			if sub>1:sub=1 if sub>=11 else sub+1
			if sub==1 and bool(_held.get("held_attack",false)):sub=2
			crt3.air_frame=sub;player.air_action_frame=sub
			_crt3_view("air_x","crt3_jump_attack",sub,_matrix(player.definition.actions.jump.parent_matrix)*_matrix(rows[0].matrix))
			_crt3_sounds(6308,sub)
			_crt3_independent_hit(6308,sub,_matrix(player.definition.actions.jump.parent_matrix)*_matrix(rows[0].matrix),"air_x")
		else:crt3.air_frame=1;_crt3_remove_view("air_x")
	else:crt3.air_frame=1;_crt3_remove_view("air_x")
	if player.state=="backstep":
		var rows:=_crt3_rows(6158,player.source_frame,6156)
		if not rows.is_empty():
			var sub:=int(crt3.back_frame)
			if sub>1:sub=1 if sub>=15 else sub+1
			if sub==1 and bool(_held.get("held_attack",false)) and int(player.cooldowns.get("backstep_x",0))==0:sub=2
			crt3.back_frame=sub
			if sub>1:player.cooldowns["backstep_x"]=81
			_crt3_sounds(6156,sub)
			var mat:=_matrix(player.definition.actions.backstep.parent_matrix)*_matrix(rows[0].matrix)
			_crt3_view("back_x","crt3_backstep_attack",sub,mat);_crt3_independent_hit(6156,sub,mat,"back_x")
			if sub==int(_crt3_component("sword_wave").get("backstep_attack_frame",-1)) and _crt3_wave_condition():_crt3_spawn_wave("backstep")
		else:_crt3_remove_view("back_x")
	else:crt3.back_frame=1;_crt3_remove_view("back_x")
func _advance_crt3_grab() -> void:
	if player.state!="skill_v":return
	var spec:=_crt3_component("grab");var frame: int=player.source_frame
	if frame==15:player.set_action("idle");zab="";return
	if frame>=65:zab="";return
	if zab.is_empty():return
	var target: Node2D=null
	for candidate: Node2D in enemies:
		if candidate.identifier==zab:target=candidate;break
	if target==null or target.hp<=0:zab="";return
	var rows: Array=database.assets.source_geometry.act05_crt3_hit_windows.timelines["6312"].active_by_source_frame.get(str(frame),[])
	for row: Dictionary in rows:
		if int(row.source_id)!=5652:continue
		var m:=_matrix(player.definition.actions.skill_v.parent_matrix)*_matrix(row.matrix)
		var at: Vector2=player.position+m.origin*Vector2(player.facing,1)
		target.position=Vector2(Actor.twips(at.x),Actor.twips(at.y));target.airborne=true;target.vertical_speed-=2;target.gravity_acceleration+=0.1
func _advance_crt3_f() -> void:
	var rows:=_crt3_rows(6088,player.source_frame,6067)
	if rows.is_empty():_crt3_remove_view("f_hit");return
	var sub:=int(_crt3_clocks.get("f_hit",1))
	if player.source_frame==15:sub=1
	elif sub>1:sub=1 if sub>=4 else sub+1
	for target: Node2D in enemies:
		if target.airborne and target._air_hit_started>=0 and (target.air_marker_stopped or int(session.run.source_ticks)-int(target._air_hit_started)+1==2):
			sub=2;_crt3_sound("crt3_f_contact")
	_crt3_clocks["f_hit"]=sub
	_crt3_view("f_hit","crt3_f_hit",sub,_matrix(player.definition.actions.skill_f.parent_matrix)*_matrix(rows[0].matrix),true,int(rows[0].alpha_mult))
func _advance_crt3_w() -> void:
	var spec:=_crt3_component("w_control");var frame: int=player.source_frame
	var wave:=_crt3_component("sword_wave")
	if _source_has(wave.get("default_w_frames",[]),frame) or _crt3_wave_condition() and _source_has(wave.get("conditional_w_frames",[]),frame):_crt3_spawn_wave("w")
	if frame>=5 and frame<=54:
		if bool(_held.get("held_w",false))or bool(_held.get("held_attack",false)):
			if int(crt3.w_key)==0:crt3.w_cut=mini(10,int(crt3.w_cut)+1);crt3.w_key=1
			elif int(crt3.w_key)==1:crt3.w_key=2
		else:crt3.w_key=0
		if frame==32+int(floor(float(crt3.w_cut)/2))*5:player.seek_action_frame(55,true);return
	for spawn: Dictionary in spec.get("illusionslash",{}).get("spawns",[]):
		if frame==int(spawn.parent_frame):
			var at: Vector2=player.position+Vector2(-32.5*player.facing,21)*player.visual_scale
			_crt3_spawn(166,at,int(spawn.entry_frame),int(spawn.stop_frame),_matrix(player.definition.actions.skill_w.parent_matrix)*Transform2D(0,Vector2(-32.5,21)),true,84)
	#6166 is a child display-list instance, not a source frame of the main atlas.
	var births: Array=spec.get("subattack_6166",{}).get("instances",[])
	for birth: Dictionary in births:
		if frame==int(birth.from_frame):_crt3_spawn(6166,player.position,1,14,_matrix(player.definition.actions.skill_w.parent_matrix)*_matrix(birth.placement.matrix),true,int(birth.until_frame))
func _crt3_spawn(source_id: int,at: Vector2,entry:=1,end:=0,local:=Transform2D.IDENTITY,attached:=false,host_end:=0) -> void:
	var keys:={574:"crt2_air_z_right",971:"crt2_air_z_left",1023:"crt2_q_dust_right",593:"crt2_q_dust_left",959:"crt3_q_clone_right",821:"crt3_q_clone_left",1030:"crt3_q_end_clone_right",1332:"crt3_q_end_clone_left",166:"crt3_w_illusion",6166:"crt3_w_subattack"}
	var key:=str(keys.get(source_id,""))
	if key.is_empty():push_error("CRT3 unknown source spawn "+str(source_id));return
	if end==0:end=int(database.assets.animations[key].frames[-1].source_frame)
	var id:="object_"+str(session.run.source_ticks)+"_"+str(_crt3_objects.size())
	var view:=_crt3_view(id,key,entry,local if attached else Transform2D(0,at),attached)
	_crt3_objects.append({"id":id,"source_id":source_id,"frame":entry,"end":end,"position":at,"facing":player.facing,"born":int(session.run.source_ticks),"attached":attached,"local":local,"host_end":host_end,"visual":view,"hits":{}})
	_crt3_sounds(source_id,entry)
func _advance_crt3_objects() -> void:
	for item: Dictionary in _crt3_objects.duplicate():
		if bool(item.get("sword_wave",false)):
			_advance_crt3_wave(item)
			continue
		var previous_frame:=int(item.frame)
		if int(item.born)!=int(session.run.source_ticks):item.frame=mini(int(item.end),int(item.frame)+1)if bool(item.attached)else int(item.frame)+1
		if int(item.frame)>int(item.end) or bool(item.attached)and(player.state!="skill_w"or player.source_frame>int(item.host_end)):
			_crt3_remove_view(str(item.id));_crt3_objects.erase(item);continue
		item.visual.set_source_frame(int(item.frame))
		if int(item.frame)!=previous_frame:_crt3_sounds(int(item.source_id),int(item.frame))
		if bool(item.attached):_crt3_independent_hit(int(item.source_id),int(item.frame),item.local,str(item.id))
		elif int(item.source_id)in[574,971]:_crt3_independent_hit(int(item.source_id),int(item.frame),Transform2D.IDENTITY,str(item.id),item.position,1)

func _crt3_wave_condition() -> bool:
	var profile:Dictionary=player.definition.get("source_profile",{})
	var spec:=_crt3_component("sword_wave")
	return not spec.is_empty() and (int(profile.get("weapon",0))==int(spec.condition_weapon) or int(profile.get("weaponmaster",0))==int(spec.condition_weaponmaster))

func _crt3_spawn_wave(origin: String) -> void:
	var spec:=_crt3_component("sword_wave")
	if spec.is_empty():push_error("CRT3剑气作者组件缺失");return
	var source_id:=1267 if player.facing==1 else 1311
	var key:=str(spec.objects[str(source_id)].animation)
	var depth:=_next_root_depth;_next_root_depth+=1
	var id:="sword_wave_"+str(depth)
	var at:Vector2=player.position
	var view:=_crt3_view(id,key,1,Transform2D(0,at),false)
	view.reparent(_source_dynamic_parent(),false)
	view.z_index=mini(depth,4095)
	view.set_meta("source_dynamic_depth",depth)
	_crt3_objects.append({"id":id,"sword_wave":true,"source_id":source_id,"frame":1,"age":1,"born":int(session.run.source_ticks),"position":at,"depth":depth,"facing":player.facing,"visual":view,"mr":{},"r":{},"origin":origin})
	_record("crt3_sword_wave_born",{"source_id":source_id,"depth":depth,"position":at,"origin":origin})

func _advance_crt3_wave(item: Dictionary) -> void:
	var spec:=_crt3_component("sword_wave")
	var age:=int(session.run.source_ticks)-int(item.born)+1
	item.age=age;item.frame=mini(age,int(spec.parent_stop_source_frame))
	item.visual.set_source_frame(mini(age,int(spec.empty_render_age)))
	if age<=1 or age>=int(spec.parent_stop_source_frame):return
	var rows:Array=spec.objects[str(item.source_id)].helpers.get(str(item.frame),[])
	# Original Ruffle wave probe: higher-depth524 EF precedes439 EF. They read
	# different marker phases, so their15 and4 cannot be one aggregate19 bonus.
	for target:Node2D in enemies:
		if target.airborne:
			if player.position.x<=target.position.x:_source_shift_x(target,10)
			if player.position.x>=target.position.x:_source_shift_x(target,-10)
	_crt3_wave_contacts(item,rows,524)
	_crt3_wave_observe(item,524,float(spec.helper524.marker_observer.damage))
	for target:Node2D in enemies:
		var r:=int(item.r.get(target.identifier,0))
		if r in [1,2,3]:
			var category:String={1:"horizontal",2:"left",3:"right"}[r]
			_crt3_slash(target,category)
			item.r[target.identifier]=0
	_crt3_wave_contacts(item,rows,439)
	_crt3_wave_observe(item,439,float(spec.helper439.marker_observer.damage))

func _crt3_wave_contacts(item: Dictionary,rows: Array,helper: int) -> void:
	var spec:=_crt3_component("sword_wave")
	for row:Dictionary in rows:
		if int(row.source_id)!=helper:continue
		var rect:Array=row.wave_local_aabb
		var box:=Rect2(item.position+Vector2(rect[0],rect[1]),Vector2(rect[2],rect[3]));_active_boxes.append(box)
		for target:Node2D in enemies:
			if target.hp<=0 or not _overlaps(box,target.hurt_rect()):continue
			if target.frozen:
				_frozen_hit(target,2)
				continue
			if helper==439:
				if int(item.mr.get(target.identifier,0))>=int(spec.helper439.normal_contact_limit):continue
				item.mr[target.identifier]=int(item.mr.get(target.identifier,0))+1
				item.r[target.identifier]=randi_range(0,2)
			_lift_target(player,target,-5,"CRT3 world sword-wave"+str(helper),helper==439)
			if helper==439:_record("crt3_sword_wave_contact",{"id":item.id,"source_frame":item.frame,"target":target.identifier,"mr":item.mr[target.identifier],"box":box})

func _crt3_wave_observe(item: Dictionary,helper: int,amount: float) -> void:
	for target:Node2D in enemies:
		var marker_two:bool=target.airborne and target._air_hit_started>=0 and (target.air_marker_stopped or int(session.run.source_ticks)-int(target._air_hit_started)+1==2)
		if not marker_two:continue
		var before:float=target.hp
		deal_damage(player,target,amount,"CRT3 wave"+str(helper)+" independent marker2 observer",false)
		_record("crt3_sword_wave_observer",{"id":item.id,"helper":helper,"source_frame":item.frame,"target":target.identifier,"damage":amount,"hp_before":before,"hp_after":target.hp})
func _crt3_independent_hit(source_id: int,frame: int,mat: Transform2D,instance: String,world_at:=Vector2.INF,direction:=1) -> void:
	var tables: Dictionary=database.assets.source_geometry.act05_crt3_hit_windows.timelines
	var list: Array=tables.get(str(source_id),{}).get("active_by_source_frame",{}).get(str(frame),[])
	for spec: Dictionary in _crt3_component("visuals").get("independent_windows",[]):
		if int(spec.source_id)!=source_id or not _source_has(spec.get("active_source_frames",[]),frame):continue
		var rule: Dictionary=spec.default_rule
		var gravity: Variant=rule.get("gravity",rule.get("normal_contact_gravity"))
		if int(rule.get("observer_marker_frame",0))==1 and float(rule.get("observer_damage",0))>0:
			for target: Node2D in enemies:
				if target.airborne and target._air_hit_started>=0 and int(session.run.source_ticks)-int(target._air_hit_started)+1==1:deal_damage(player,target,float(rule.observer_damage),"CRT3 source marker1 observer",false)
		if rule.has("outer2_push"):
			for target: Node2D in enemies:
				if not target.airborne:continue
				if target.position.x<=player.position.x:_source_shift_x(target,-10)
				if target.position.x>=player.position.x:_source_shift_x(target,10)
		if gravity==null and not bool(rule.get("pull_call",false)):continue
		for row: Dictionary in list:
			if int(row.source_id)!=int(spec.helper_id)or int(row.depth)!=int(spec.depth):continue
			var r: Array=row.rect;var local: Rect2=mat*Rect2(r[0],r[1],r[2],r[3])
			var box: Rect2=player.transform_rect(local)
			if world_at!=Vector2.INF:
				if direction<0:local.position.x=-local.end.x
				box=Rect2(world_at+local.position,local.size)
			for target: Node2D in enemies:
				if target.hp<=0 or not _overlaps(box,target.hurt_rect()):continue
				var token: String=instance+":"+str(spec.depth)+":"+str(spec.active_frames[0])+":"+target.identifier
				var max_hits:=int(rule.get("max_mr_per_enemy",rule.get("normal_contact_limit_per_target",0))if rule.get("max_mr_per_enemy",rule.get("normal_contact_limit_per_target",0))!=null else 0)
				if max_hits>0 and int(_crt3_contacts.get(token,0))>=max_hits:continue
				_crt3_contacts[token]=int(_crt3_contacts.get(token,0))+1
				if bool(rule.get("pull_call",false)):_crt3_e_pull()
				if gravity!=null:
					_lift_target(player,target,float(gravity),"CRT3 child"+str(source_id),rule.get("marker_seek",rule.get("reset_air_marker_to"))!=null)
					if rule.has("gravity_acceleration_assignment"):target.gravity_acceleration=float(rule.gravity_acceleration_assignment)
func _advance_crt3_e() -> void:
	if not bool(crt3.e_active):return
	if player.state!="skill_e":_crt3_end_e(false);return
	var spec:=_crt3_component("awakening_default");var born:=int(crt3.e_born)
	if born!=int(session.run.source_ticks):
		crt3.e_start_frame=mini(45,int(crt3.e_start_frame)+1);crt3.e_circle_frame=mini(11,int(crt3.e_circle_frame)+1)
		if int(crt3.e_w_frame)>1:crt3.e_w_frame+=1
	if int(crt3.e_start_frame)==39 and int(crt3.e_w_frame)==1:crt3.e_w_frame=2
	var parent:=_matrix(player.definition.actions.skill_e.parent_matrix)
	for child: Dictionary in spec.direct_children:
		var id:=int(child.source_id)
		var frame:=int(crt3.e_w_frame)if id==6276 else int(crt3.e_circle_frame)if id==6199 else int(crt3.e_start_frame)
		var key: String={6276:"crt3_e_actor",6199:"crt3_e_circle",6299:"crt3_e_start"}[id]
		_crt3_view("e_"+str(id),key,mini(int(child.get("actual_frames",frame)),frame),parent*_matrix(child.matrix))
		if int(_crt3_clocks.get("sound_"+str(id),0))!=frame:_crt3_sounds(id,frame);_crt3_clocks["sound_"+str(id)]=frame
	var tracks: Dictionary=_crt3_geometry().tracks
	var active_streaks:={}
	var streaks: Array=tracks.get("6299",{}).get("6278",{}).get(str(int(crt3.e_start_frame)),[])
	for child: Dictionary in streaks:
		var id:="e_streak_"+str(int(child.depth));active_streaks[id]=true;var entry:=int(_crt3_geometry().streak.entry_by_depth[str(int(child.depth))])
		var frame:=mini(44,entry+int(session.run.source_ticks)-born)
		_crt3_view(id,"crt3_e_streak",frame,parent*_matrix(spec.direct_children[2].matrix)*_matrix(child.matrix))
	for id: String in _crt3_views.keys():
		if id.begins_with("e_streak_")and not active_streaks.has(id):_crt3_remove_view(id)
	var active:={}
	var frame:=int(crt3.e_w_frame)
	for host: Dictionary in _crt3_geometry().get("timelines",{}).get("6276",{}).get(str(mini(148,frame)),[]):
		if int(host.source_id)not in[6259,6199]:continue
		var id:="e_child_"+str(int(host.source_id))+"_"+str(int(host.depth));active[id]=true
		var sub:=int(_crt3_clocks.get(id,0))
		if sub==0:
			sub=1;_crt3_sounds(int(host.source_id),1)
			if int(host.source_id)==6259:_crt3_random_sound("crt3_e_random_",3);_crt3_start_screen("flash")
		else:sub=mini(4 if int(host.source_id)==6259 else 11,sub+1)
		_crt3_clocks[id]=sub
		_crt3_view(id,str(_crt3_geometry().e_hit_variants[str(int(host.depth))])if int(host.source_id)==6259 else"crt3_e_circle",sub,parent*_matrix(spec.direct_children[0].matrix)*_matrix(host.matrix))
	for id: String in _crt3_views.keys():
		if id.begins_with("e_child_")and not active.has(id):_crt3_remove_view(id)
	_crt3_independent_hit(6276,frame,parent*_matrix(spec.direct_children[0].matrix),"e_6276")
	if frame==116 and int(crt3.get("dark_trigger",-1))!=int(crt3.e_born):crt3["dark_trigger"]=int(crt3.e_born);_crt3_start_screen("dark")
	if frame==128 and int(crt3.get("flash_trigger",-1))!=int(crt3.e_born):crt3["flash_trigger"]=int(crt3.e_born);_crt3_start_screen("flash")
	if frame==148:_crt3_end_e(true)
func _crt3_end_e(normal: bool) -> void:
	crt3.e_active=false
	for id: String in _crt3_views.keys():
		if id.begins_with("e_"):_crt3_remove_view(id)
	if normal:player.set_action("idle")
	crt3.e_slot_frame=1;crt3.e_slot_playing=true
	_record("crt3_e_end",{"normal":normal})
func _crt3_clear() -> void:
	for id: String in _crt3_views.keys():_crt3_remove_view(id)
	_crt3_objects.clear();_crt3_contacts.clear();_crt3_clocks.clear()
	crt3.h_frame=1;crt3.over=0;crt3.e_active=false;zab=""

func _crt3_e_pull() -> void:
	var bounds:=Rect2()
	for id: String in _crt3_views:
		if not id.begins_with("e_")or id=="e_cutin":continue
		var view: Node2D=_crt3_views[id]
		var definition: Dictionary=view.definition
		for frame: Dictionary in definition.frames:
			if int(frame.source_frame)!=int(view.source_frame):continue
			var r: Array=frame.get("alpha_bounds",[0,0,0,0])
			var box: Rect2=view.global_transform*Rect2(r[0],r[1],r[2],r[3])
			bounds=box if not bounds.has_area()else bounds.merge(box)
	var x:=float(crt3.e_skill_x)
	for target: Node2D in enemies:
		if target.hp<=0 or not _overlaps(bounds,target.hurt_rect()):continue
		if absf(x-target.position.x)<30:target.position.x=x
		elif x<target.position.x:_source_shift_x(target,-30)
		elif x>target.position.x:_source_shift_x(target,30)

func _crt3_push_air(amount: float) -> void:
	for target: Node2D in enemies:
		if target.hp<=0 or not target.airborne:continue
		if target.position.x<=player.position.x:_source_shift_x(target,-amount)
		if target.position.x>=player.position.x:_source_shift_x(target,amount)

func _crt3_start_screen(kind: String) -> void:
	var geometry: Dictionary=_crt3_geometry().screen_feedback
	var roots: Array=geometry.roots[str(int(stage.source_root_frame))]
	var ancestor: Dictionary={}
	for root_placement: Dictionary in roots:
		if kind=="flash"and int(root_placement.source_id)==6917 or kind=="dark"and int(root_placement.source_id)!=6917:ancestor=root_placement;break
	var children: Array=geometry.children.get(str(int(ancestor.get("source_id",0))),[])
	var child: Dictionary={}
	for placement: Dictionary in children:
		if int(placement.source_id)==int(geometry[kind].source_id):child=placement;break
	if child.is_empty():_record("crt3_screen_noop",{"kind":kind,"source_root":stage.source_root_frame});return
	crt3[kind+"_frame"]=int(geometry[kind].entry);crt3[kind+"_born"]=int(session.run.source_ticks)
	var id:="screen_"+kind
	var view:=_crt3_view(id,str(geometry[kind].animation),int(geometry[kind].entry),_matrix(ancestor.matrix)*_matrix(child.matrix),false)
	view.z_index=int(ancestor.depth)
	_record("crt3_screen_started",{"kind":kind,"source_id":int(geometry[kind].source_id),"frame":int(geometry[kind].entry)})
func _advance_crt3_screen() -> void:
	for kind: String in ["dark","flash"]:
		var id:="screen_"+kind
		if not _crt3_views.has(id):continue
		if int(crt3[kind+"_born"])==int(session.run.source_ticks):continue
		var frame:=int(crt3[kind+"_frame"])+1
		if kind=="flash"or frame>27:
			crt3[kind+"_frame"]=1;_crt3_remove_view(id);continue
		crt3[kind+"_frame"]=frame;_crt3_views[id].set_source_frame(frame)

# Finite CRT4 adapters share the existing Battle, source clock and author chain.
func _crt4_component(id: String) -> Dictionary:
	return player.definition.get("components",{}).get(id,{})
func _crt4_geometry() -> Dictionary:
	return _crt4_component("visuals").get("geometry",{})
func _crt4_action_started(id: String) -> void:
	_crt4_contacts.clear()
	if id=="skill_y":crt4.y_slot_frame=2;crt4.y_slot_playing=false
	if id=="jump":crt4.air_frame=1;crt4["air_born"]=int(session.run.source_ticks)
	if id=="jump":crt4["air_slash_frame"]=1
	if id=="backstep":crt4.back_frame=1;crt4["back_born"]=int(session.run.source_ticks)
	if id=="skill_a":crt4.a_charge=1;crt4.erase("a_charge_born")
	if id=="skill_v":zab=""
	if id=="skill_r":crt4["r_k"]=0
	if id=="skill_e":
		crt4.erase("e_dark_born")
		for target: Node2D in enemies:crt4["marked_"+target.identifier]=false
	if id=="t_finish" and int(player.definition.get("source_profile",{}).get("initialized_values",{}).get("blaze",0))!=5:
		crt4.kalla_frame=13;crt4.kalla=0;crt4["kalla_born"]=int(session.run.source_ticks)
func _crt4_begin(id: String) -> bool:
	if not _start_actor_action(id):return false
	_crt4_action_started(id)
	return true
func _crt4_input(input: Dictionary) -> void:
	var f: int=player.source_frame
	if bool(input.get("skill_s",false)) and player.state=="skill_s":
		if f>=5 and f<=9:player.seek_action_frame(11,true);return
		if f>=17 and f<=22:player.seek_action_frame(24,true);return
	if bool(input.get("jump",false)) and player.state=="skill_r" and f>=7 and f<=86:player.set_action("idle");return
	if bool(input.get("attack",false)):
		if player.state=="jump" and f>=4 and int(crt4.get("air_slash_frame",1))==1:
			crt4.air_slash_frame=2;crt4["air_slash_born"]=int(session.run.source_ticks)
		if player.state=="basic" and f>=9 and f<=16:_crt4_begin("basic2");return
		if player.state=="basic2" and f>=10 and f<=18:player.play_source_parent();return
		if player.state=="backstep" and int(crt4.kalla)==1 and int(crt4.back_frame)==1:
			crt4.back_frame=2;crt4["back_born"]=int(session.run.source_ticks)
	var serial: int=player.action_serial
	for key: String in ["load_h","load_g","load_f","skill_z","skill_a","skill_s","skill","skill_q","skill_w","skill_e","skill_r","skill_t","skill_y","skill_v"]:
		if not bool(input.get(key,false)):continue
		var id: String={"load_h":"skill_h","load_g":"skill_g","load_f":"skill_f","skill":"skill_d"}.get(key,key)
		if key=="skill_t" and int(crt4.kalla_frame)==12:id="t_finish"
		if _try_skill(_resolve_author_input(key,id)):return
	_dispatch_custom_inputs(input)
	if serial!=player.action_serial:return
	if player.state in ["idle","move"]:
		if bool(input.get("attack",false)):_crt4_begin("kalla_basic"if int(crt4.kalla)==1 else"basic")
		elif bool(input.get("jump",false)):_crt4_begin("jump")
		elif bool(input.get("down",false)):_crt4_begin("backstep")
	elif bool(input.get("down",false)) and player.state in ["basic","basic2","basic3"]:_crt4_begin("backstep")
func _crt4_ground(input: Dictionary) -> void:
	if player.state not in ["idle","move"]:return
	var axis:=signf(float(input.get("axis",0)))
	var right:=bool(input.get("right",axis>0));var left:=bool(input.get("left",axis<0))
	if right or left:
		if player.state!="move":
			player.set_action("move");crt4["move_selector"]=1;crt4["move_born"]=int(session.run.source_ticks)
		var movement: Dictionary=_crt4_component("visuals").movement
		var amount:=float(movement.static_ghostwalk_total if int(crt4.ghost_step)==1 else movement.static_normal_total)
		if right:_move_player(amount);player.set_facing(1)
		if left:_move_player(-amount);player.set_facing(-1)
	elif player.state=="move":player.set_action("idle")
func _crt4_event(actor: Node2D,event: Dictionary) -> void:
	if actor!=player:return
	match str(event.kind):
		"crt4_spawn_field":
			var sid:=int(event.source_id)
			var item:=_crt4_spawn(sid,player.position+Vector2(float(event.x_offset)*player.facing,float(event.y_offset)))
			if not crt4.fields.has(str(sid)):crt4.fields[str(sid)]=false
		"crt4_component_seek":
			if int(event.source_id)==6360:crt4.ghost_frame=int(event.source_frame);crt4["ghost_born"]=int(session.run.source_ticks)
			else:crt4.kalla_frame=int(event.source_frame);crt4["kalla_born"]=int(session.run.source_ticks);crt4["kalla_timer"]=0
		"crt4_spawn_clone":_crt4_spawn(1326,player.position,Vector2(player.facing,1))
		"crt4_spawn_swamp":_crt4_spawn(944,player.position+Vector2(0,float(event.y_offset)),Vector2(player.facing,float(event.scale_y)),int(event.depth_initial))
		"crt4_cutin":
			var roots: Dictionary=_crt4_geometry().source_geometry.cutin_root_placements
			var row: Dictionary=roots[str(int(stage.source_root_frame))][0]
			_crt4_view("cutin","hud_crt4_cutin",130,_matrix(row.matrix),false,int(row.depth))
			crt4["cutin_born"]=int(session.run.source_ticks)
		"crt4_ghostwalk_hide_and_map_dark":crt4.ghost_frame=20;_crt4_start_screen("dark")
		"crt4_ghostwalk_restore":crt4.ghost_frame=18 if int(crt4.ghost_step)==1 else 1
		"crt4_random_targets_reset":crt4["e_target_selector"]=1
		"crt4_ghostslash_release":_crt4_e_finish(not bool(_held.get("held_e",false)))
		"crt4_ghostslash_finish":_crt4_e_finish(false)
		"crt4_clear_persistent_states":_crt4_clear()
		"crt4_player_hit_marker":_record("crt4_player_hit_marker",{"frame":2})
		_:
			if event.has("source_rule"):_crt4_hit(event)
func _crt4_sounds(sid: int,f: int) -> void:
	for row: Dictionary in _crt4_component("visuals").get("source_audio",{}).get(str(sid),[]):
		if int(row.frame)==f:audio.play_stream(row.audio_stream,float(row.get("offset",0)),str(row.sound))
func _crt4_emit_audio(instance: String,sid: int,f: int) -> void:
	var key:=instance+":"+str(sid)
	if int(_crt4_audio_frames.get(key,-1))==f:return
	_crt4_audio_frames[key]=f
	_crt4_sounds(sid,f)
func _crt4_placement(sid: int,f: int,child: int) -> Dictionary:
	var tracks: Array=_crt4_geometry().source_geometry.action_tracks.get(str(sid),[])
	if tracks.is_empty():tracks=_crt4_component(str(sid)).get("placement_tracks",[])
	var rows: Array=[]
	for change: Dictionary in tracks:
		if int(change.source_frame)>f:break
		rows=change.placements
	for row: Dictionary in rows:
		if int(row.source_id)==child:return row
	# Imported animation tracks intentionally contain only selected drawable IDs.
	# A required transparent helper/controller can still live in the full author
	# component timeline. Never treat a filtered draw list as its whole display list.
	rows=[]
	for change: Dictionary in _crt4_component(str(sid)).get("placement_tracks",[]):
		if int(change.source_frame)>f:break
		rows=change.placements
	for row: Dictionary in rows:
		if int(row.source_id)==child:return row
	return {}
func _crt4_view(id: String,key: String,f: int,mat:=Transform2D.IDENTITY,attached:=true,depth:=1,alpha:=256.0) -> Node2D:
	var meta: Dictionary=database.assets.animations[key]
	if meta.has("baked_placement_matrix"):mat=mat*_matrix(meta.baked_placement_matrix).affine_inverse()
	var node: Node2D=_crt4_views.get(id)
	if not is_instance_valid(node):
		node=_new_source_visual(key,player.visual_parent() if attached else (_source_dynamic_parent()if depth>=0 else self));_crt4_views[id]=node
	elif node.definition!=meta:node.configure(meta)
	if attached:
		var size: Vector2=player.visual_scale*Vector2(player.facing,1)
		node.transform=Transform2D(Vector2(size.x,0),Vector2(0,size.y),Vector2.ZERO)*mat
	else:node.transform=mat
	node.z_index=clampi(depth,-4096,4096);node.set_meta("source_depth",depth)
	node.modulate.a=alpha/float(meta.get("baked_alpha_mult",256))
	var sample:=f
	var sparse: Dictionary=_crt4_geometry().get("sparse_visual_mapping",{}).get(key,{})
	if not sparse.is_empty():sample=int(sparse.source_frame_to_sample[str(f)])
	node.set_source_frame(sample);node.visible=true
	return node
func _crt4_hide(id: String) -> void:
	if is_instance_valid(_crt4_views.get(id)):_crt4_views[id].queue_free()
	_crt4_views.erase(id)
func _crt4_main_controls() -> void:
	var f: int=player.source_frame
	match player.state:
		"skill_a":
			if f==4 and not bool(_held.get("held_a",false)):player.seek_action_frame(27,true)
			elif f==15:player.seek_action_frame(26,true)
			elif f==26:
				if bool(_held.get("held_a",false)):player.seek_action_frame(26,true)
				else:player.seek_action_frame(49,true)
			elif f==57 and int(crt4.ghost_type) in [1,2,3]:player.seek_action_frame({1:58,2:86,3:114}[int(crt4.ghost_type)],true)
			elif f in [48,76,104,132]:player.set_action("idle")
		"skill_s":
			if f in [10,23,40]:player.set_action("idle")
		"skill_r":
			if f>=7 and f<=86:
				crt4.r_k+=1
				if int(crt4.r_k)>2:_crt4_tombstone();crt4.r_k=0
		"skill_e":
			if f>=45 and f<=64:
				for enemy: Node2D in enemies:
					if not enemy.airborne:continue
					if enemy.position.x>player.position.x:_source_shift_x(enemy,-8.5)
					if enemy.position.x<player.position.x:_source_shift_x(enemy,8.5)
		"skill_v":
			if f==16:player.set_action("idle")
			if f>=66:zab=""
func _advance_crt4_components(previous: String) -> void:
	if player.state=="dead":_crt4_clear();return
	if previous=="skill_v" and player.state!="skill_v":zab=""
	_crt4_main_controls()
	var action: Dictionary=player.definition.actions[player.state]
	for motion: Dictionary in action.get("source_displacement",[]):
		if player.source_frame>=int(motion.from) and player.source_frame<=int(motion.until):_move_player(float(motion.dx_per_tick)*player.facing)
	_crt4_persistent()
	_crt4_ghost_loop()
	_crt4_air()
	_crt4_main_children()
	_crt4_named_feedback()
	_crt4_advance_bleeds()
	_crt4_advance_objects()
	_crt4_persistent_observers(4318,1)
	if _crt4_views.has("screen_dark"):
		var sub:=2+int(session.run.source_ticks)-int(crt4.screen_dark_born)
		if sub>27:_crt4_hide("screen_dark")
		else:_crt4_views.screen_dark.set_source_frame(sub)
	if _crt4_views.has("cutin"):
		var f:=130+int(session.run.source_ticks)-int(crt4.cutin_born)
		if f>=161:_crt4_hide("cutin")
		else:_crt4_views.cutin.set_source_frame(f)

func _crt4_actor_mat() -> Transform2D:
	var size: Vector2=player.visual_scale*Vector2(player.facing,1)
	return Transform2D(Vector2(size.x,0),Vector2(0,size.y),player.position)
func _crt4_marker_two(target: Node2D) -> bool:
	return target.airborne and target._air_hit_started>=0 and (target.air_marker_stopped or int(session.run.source_ticks)-target._air_hit_started+1==2)
func _crt4_observe(sid: int,helper: int,f: int,target: Node2D,amount: float) -> void:
	if amount<=0 or target.hp<=0:return
	var before: float=target.hp
	deal_damage(player,target,amount,"CRT4 independent observer %d/%d"%[sid,helper],false)
	_record("crt4_helper_observer",{"source_id":sid,"helper":helper,"frame":f,"target":target.identifier,"amount":amount,"hp_before":before,"hp_after":target.hp})
func _crt4_hit(event: Dictionary) -> void:
	var action: Dictionary=player.definition.actions[player.state]
	var sid:=int(action.source_id)
	var boxes: Array[Rect2]=[]
	for rect: Rect2 in event.get("local_rects",[]):boxes.append(player.transform_rect(rect))
	_crt4_helper(sid,player.source_frame,int(event.source_helper),int(event.source_depth),int(event.source_birth_frame),event.source_rule,boxes,"action"+str(player.action_serial),{},event)
func _crt4_windows(sid: int,f: int,mat: Transform2D,instance: String,item: Dictionary={}) -> void:
	for row: Dictionary in _crt4_geometry().hit_windows:
		if int(row.source_id)!=sid or f<int(row.from) or f>int(row.until) or not bool(row.get("default_selected",true)):continue
		var boxes: Array[Rect2]=[]
		for rect: Array in row.get("local_rects_by_source_frame",{}).get(str(f),row.get("local_rects",[])):
			boxes.append(mat*Rect2(rect[0],rect[1],rect[2],rect[3]))
		if sid==316:
			var geometry: Dictionary=_crt4_component("316").world_semantics.geometry
			var rect: Array=geometry.aabb_by_child312_source_frame[str((maxi(1,f-8)-1)%12+1)]
			boxes=[mat*Rect2(rect[0],rect[1],rect[2],rect[3])]
		_crt4_helper(sid,f,int(row.helper_source_id),int(row.source_depth),int(row.from),row.default_rule,boxes,instance,item,row)
func _crt4_helper(sid: int,f: int,helper: int,depth: int,birth: int,rule: Dictionary,boxes: Array[Rect2],instance: String,item: Dictionary,event: Dictionary) -> void:
	var kind:=str(rule.kind)
	if kind in ["control","persistent_hud_observer"]:return
	for box: Rect2 in boxes:_active_boxes.append(box)
	if kind=="field_marker_observer":
		if bool(rule.get("requires_player_body_overlap",false)) and not boxes.any(func(r:Rect2)->bool:return _overlaps(r,player.gravity_rect())):return
		for target: Node2D in enemies:
			if _crt4_marker_two(target):_crt4_observe(sid,helper,f,target,float(rule.observer_damage.get("air",0)))
			if target.frozen and target.freeze_hit_frame==2:_crt4_observe(sid,helper,f,target,float(rule.observer_damage.get("frozen",0)))
			for status: Dictionary in _crt4_objects:
				if int(status.source_id)!=3962 or status.get("target")!=target:continue
				var key:="ghostslash"+str(int(status.frame))
				_crt4_observe(sid,helper,f,target,float(rule.observer_damage.get(key,0)))
		return
	if kind=="grab_anchor":
		for target: Node2D in enemies:
			if target.identifier!=zab:continue
			var placement: Dictionary={}
			for row: Dictionary in event.get("source_placement_track",[]):
				if int(row.source_frame)<=f:placement=row
			if placement.is_empty():continue
			var parent: Array=event.source_parent_matrix;var local: Array=placement.matrix
			target.position=Vector2(Actor.twips(player.position.x+(float(parent[4])+float(local[4]))*player.facing),Actor.twips(player.position.y+float(parent[5])+float(local[5])))
			target.vertical_speed-=2;target.gravity_acceleration+=0.1;target.airborne=true
			_v_trace={"zab":zab,"anchor_active":true,"anchor_local":[local[4],local[5]],"child":[parent[4],parent[5]]}
		return
	for target: Node2D in enemies:
		if target.hp<=0:continue
		var body: Rect2=target.hurt_rect()
		var normal: bool=not target.frozen
		if target.airborne:
			var source: Dictionary=database.assets.source_geometry.get("air_normal_proxy",{}).get(str(int(target.definition.source_id)),{})
			normal=not source.is_empty() and not target.frozen
			if normal:
				var rect: Array=source.rect_enemy_local
				body=target.transform_rect(Rect2(rect[0],rect[1],rect[2],rect[3]))
		var contact: bool=boxes.any(func(r:Rect2)->bool:return _overlaps(r,body))
		var frozen_contact: bool=target.frozen and "frozen" in rule.get("contact_bodies",[])
		var accepted: bool=normal and "normal" in rule.get("contact_bodies",[]) or frozen_contact
		var token:="%s:%d:%d:%s"%[instance,depth,birth,target.identifier]
		var count:=int(_crt4_contacts.get(token,0))
		if contact and accepted:
			var limit: Variant=rule.get("contact_limit_by_body",{}).get("frozen"if target.frozen else"normal")
			if limit!=null and count>=int(limit):continue
			_crt4_contacts[token]=count+1
			match kind:
				"launch":
					_lift_target(player,target,float(rule.gravity),"CRT4 source%d helper%d"%[sid,helper],bool(rule.get("reset_marker",false)))
					if sid==1153 and f<=2:_crt4_kalla_hit(target)
				"dark_hit_fx":_crt4_spawn(578,target.position,Vector2.ONE,int(rule.get("local_depth_initial",0)))
				"freeze":
					deal_damage(player,target,float(rule.get("direct_damage",0)),"CRT4 freeze contact",false)
					if target.hp>0:_freeze_target(target);_frozen_hit(target,2)
				"ground":
					target.airborne=false;target.vertical_speed=0;target.gravity_acceleration=0;target.position.y=target.ground_y
				"apply_observer_status":_crt4_target_status(3951,target,2)
				"ghostslash_mark":
					_crt4_target_status(3963,target,1)
					crt4["marked_"+target.identifier]=true
				"spawn_mummy":
					_crt4_spawn(978,target.position)
					var mirror_draw:=randf()<=0.5 # Original writes the incremented, absent name; do not mirror the newborn.
					_record("crt4_mummy_mirror_draw",{"value":mirror_draw,"next_depth":_next_root_depth})
				"mummy_contact":item.frame=20;item["phase_born"]=int(session.run.source_ticks)
				"mummy_follow_bleed":
					if not item.has("target"):item.target=target;item["bleed"]=true;_crt4_bleed(target)
				"grab_select":
					if zab.is_empty():zab=target.identifier
					player.seek_action_frame(17,true);return
			_record("crt4_helper_contact",{"source_id":sid,"helper":helper,"frame":f,"target":target.identifier,"kind":kind,"instance":instance})
	# Original observers read global markers independently of this helper contact.
	for observer: Dictionary in rule.get("observers",[]):
		var n:=int(observer.target)-1
		if n<0 or n>=enemies.size():continue
		var target: Node2D=enemies[n]
		var state:=str(observer.state)
		var air:=state in ["air","air_or_frozen"] and _crt4_marker_two(target)
		var frozen_marker: bool=state in ["frozen","air_or_frozen"] and target.frozen and target.freeze_hit_frame==2
		if air or frozen_marker:
			# Y's conditional bonus rows are represented by the finite flag rule.
			if sid==906 and f>=25 and float(observer.observer_damage)==75:continue
			var amount:=float(observer.observer_damage)
			if sid==906 and f>=25:amount+=float(rule.marker_bonus_per_active_flag)*_crt4_flag_count()
			_crt4_observe(sid,helper,f,target,amount)
	if kind=="marker_observer":
		for target: Node2D in enemies:
			if _crt4_marker_two(target):_crt4_observe(sid,helper,f,target,float(rule.observer_damage.get("air",0)))
			if target.frozen and target.freeze_hit_frame==2:_crt4_observe(sid,helper,f,target,float(rule.observer_damage.get("frozen",0)))
func _crt4_persistent_observers(sid: int,f: int) -> void:
	var spec:=_crt4_component(str(sid))
	if f<int(spec.active_from) or f>int(spec.active_until):return
	for value: Variant in spec.air_targets:
		var index:=int(value)-1
		if index<enemies.size() and _crt4_marker_two(enemies[index]):_crt4_observe(sid,1729,f,enemies[index],float(spec.air_damage))
	for value: Variant in spec.ghostslash_targets:
		var index:=int(value)-1
		if index>=enemies.size():continue
		for object: Dictionary in _crt4_objects:
			if int(object.source_id)==3962 and object.get("target")==enemies[index] and int(object.frame)==int(spec.ghostslash_frame):_crt4_observe(sid,1729,f,enemies[index],float(spec.ghostslash_damage))
func _crt4_flag_count() -> int:
	var count:=0
	for key: String in ["kaz","bremen","saya","rhasa","ghost_step","kalla"]:
		if int(crt4[key])==1:count+=1
	return count
func _crt4_target_status(sid: int,target: Node2D,entry: int) -> Dictionary:
	for object: Dictionary in _crt4_objects:
		if int(object.source_id)==sid and object.get("target")==target:
			object.frame=entry;object["phase_born"]=int(session.run.source_ticks)
			_crt4_emit_audio("root"+str(object.id),sid,entry)
			return object
	var object:=_crt4_spawn(sid,target.position,Vector2.ONE,target.z_index+2,false)
	object.target=target;object.frame=entry
	object["source_parent"]=4021
	if sid==3962:
		object.source_parent=3963
		for owner: Dictionary in _crt4_objects:
			if int(owner.source_id)==3963 and owner.get("target")==target:object["parent_id"]=owner.id
	_crt4_emit_audio("root"+str(object.id),sid,entry)
	return object
func _crt4_e_finish(released: bool) -> void:
	var ordered: Array=enemies.duplicate()
	if released:ordered.reverse()
	for target: Node2D in ordered:
		if not bool(crt4.get("marked_"+target.identifier,false)):continue
		if player.source_frame==28:
			_crt4_target_status(3963,target,2)
			_crt4_target_status(3962,target,1)
		var active:=_crt4_objects.any(func(item:Dictionary)->bool:return int(item.source_id)==3963 and item.get("target")==target and int(item.frame)==2)
		if active and (released or player.source_frame==45):
			deal_damage(player,target,350,"CRT4 E marked finish",false)
			_crt4_spawn(578,target.position,Vector2.ONE,6250)
			if player.source_frame==45:crt4["e_dark_born"]=int(session.run.source_ticks)
	if released:
		crt4.ghost_frame=18 if int(crt4.ghost_step)==1 else 1
		player.set_action("idle")
func _crt4_tombstone() -> void:
	var at: Vector2=player.position+Vector2(0,randi_range(0,29)+2)
	at.x=player.position.x+randi_range(0,199)-80
	for index in range(5):
		var draw:=randf()<0.5
		if index>=enemies.size():continue
		var target: Node2D=enemies[index]
		if draw and target.hp>0 and absf(target.position.x-player.position.x)<140:at.x=target.position.x
	var direction:=-1 if randf()<0.5 else 1
	_crt4_spawn(1273,at,Vector2(direction,1))

func _crt4_part(id: String,key: String,host: int,f: int,child: int,sub: int,outer:=Transform2D.IDENTITY,attached:=true,depth:=1) -> Node2D:
	var row:=_crt4_placement(host,f,child)
	if row.is_empty():_crt4_hide(id);return null
	var alpha:=float(row.get("alpha_mult",row.get("color_transform",{}).get("alphaMultTerm",256)))
	_crt4_emit_audio(id,child,sub)
	return _crt4_view(id,key,sub,outer*_matrix(row.matrix),attached,depth,alpha)
func _crt4_persistent() -> void:
	var tick:=int(session.run.source_ticks)
	var ghost: int=crt4.ghost_frame
	if ghost>1:
		if int(crt4.get("ghost_born",-1))!=tick and ghost<18:crt4.ghost_frame+=1
		ghost=int(crt4.ghost_frame)
		if ghost==13:crt4.ghost_step=1
		if ghost<18:crt4.erase("ghost_timer")
		if ghost>=18:
			if not crt4.has("ghost_timer"):crt4["ghost_timer"]=1
			else:crt4.ghost_timer+=1
			if int(crt4.ghost_timer)>=545:crt4.ghost_frame=1;crt4.ghost_step=0;crt4.erase("ghost_timer")
		if ghost<=18:_crt4_part("ghostwalk","crt4_ghostwalk",6732,player.parent_frame,6360,ghost)
		else:_crt4_hide("ghostwalk")
	else:crt4.ghost_step=0;crt4.erase("ghost_timer");_crt4_hide("ghostwalk")
	var kalla: int=crt4.kalla_frame
	if kalla>1:
		if int(crt4.get("kalla_born",-1))!=tick and kalla not in [12,21]:crt4.kalla_frame+=1
		kalla=int(crt4.kalla_frame)
		if kalla==3:crt4.kalla=1
		if kalla==13:crt4.kalla=0
		if kalla!=12:crt4.erase("kalla_timer")
		if kalla==12:
			crt4.kalla_timer=int(crt4.get("kalla_timer",0))+1
			if int(crt4.kalla_timer)>=574:crt4.kalla_frame=13;crt4.kalla=0;kalla=13
		_crt4_part("kalla","crt4_kalla",6732,player.parent_frame,6384,mini(kalla,21))
		if kalla==12:
			var rootrow:=_crt4_placement(6732,player.parent_frame,6384)
			var timerrow:=_crt4_placement(6384,kalla,6380)
			if not rootrow.is_empty() and not timerrow.is_empty():
				_crt4_part("kalla_body","crt4_kalla_body",6380,1,6378,(int(crt4.kalla_timer)-1)%8+1,_matrix(rootrow.matrix)*_matrix(timerrow.matrix))
		elif kalla in [11,13,14]:
			var rootrow:=_crt4_placement(6732,player.parent_frame,6384)
			var mode:=11 if kalla==11 else 13
			if int(crt4.get("kalla_direct_mode",0))!=mode:crt4["kalla_direct_mode"]=mode;crt4["kalla_direct_born"]=tick
			if not rootrow.is_empty():_crt4_part("kalla_body","crt4_kalla_body",6384,kalla,6378,(tick-int(crt4.kalla_direct_born))%8+1,_matrix(rootrow.matrix))
		else:_crt4_hide("kalla_body")
	else:_crt4_hide("kalla");_crt4_hide("kalla_body")
	if player.state=="move" and int(crt4.ghost_step)==1:
		var selector:=int(crt4.get("move_selector",1))
		if selector==1:
			crt4.move_selector=2;crt4["move_phase_born"]=tick;crt4.ghost_frame=19
			selector=2
		var age:=tick-int(crt4.move_phase_born)+1
		player.visual.visible=false;player.source_body_selector=2 if selector==2 else 1
		var main:=_matrix(player.definition.actions.idle.parent_matrix)
		var outer:=_crt4_placement(6406,16,6405)
		if not outer.is_empty():main=main*_matrix(outer.matrix)
		var selected:=_crt4_placement(6405,selector,6397 if selector==2 else 6404)
		if not selected.is_empty():
			main=main*_matrix(selected.matrix)
			_crt4_part("ghost_move_body","crt4_move_body",6397 if selector==2 else 6404,mini(age,9),6393,(age-1)%12+1,main)
			if selector==2 and age>=4:
				_crt4_part("ghost_move_timer","crt4_ghost_move_timer",6397,mini(age,9),6395,mini(age-3,35),main)
				if age-3>=35:crt4.move_selector=3;crt4.move_phase_born=tick+1
			elif selector==3:
				crt4.ghost_frame=18
				_crt4_part("ghost_move_exit","crt4_ghost_move_exit_fx",6404,mini(age,9),6402,mini(age,8),main)
	else:
		player.visual.visible=true;player.source_body_selector=1
		for id: String in ["ghost_move_body","ghost_move_timer","ghost_move_exit"]:_crt4_hide(id)
func _crt4_air() -> void:
	var f: int=player.source_frame
	var tick:=int(session.run.source_ticks)
	if player.state=="jump" and f>=4:
		var sub:=int(crt4.air_frame)
		if sub==1 and bool(_held.get("held_attack",false)):
			crt4.air_frame=13 if int(crt4.kalla)==1 else 2;crt4.air_born=tick;sub=int(crt4.air_frame)
		elif sub>1 and int(crt4.air_born)!=tick:
			crt4.air_frame=mini(21,sub+1);sub=int(crt4.air_frame)
			if sub==12:crt4.air_frame=1;sub=1
			if sub==21:
				if f==30:player.set_action("idle");return
				crt4.air_frame=1;sub=1
		var right:=bool(_held.get("right",false));var left:=bool(_held.get("left",false))
		if right:
			_move_player(4)
			if sub==1:player.set_facing(1)
		if left:
			_move_player(-4)
			if sub==1:player.set_facing(-1)
		if sub==15:_crt4_spawn(1154,player.position+Vector2(0,-40),Vector2(player.facing,1))
		var parent:=_matrix(player.definition.actions.jump.parent_matrix)
		_crt4_part("air","crt4_jump_attack",6530,f,6528,mini(sub,21),parent)
		var placed:=_crt4_placement(6530,f,6528)
		if not placed.is_empty():_crt4_windows(6528,sub,_crt4_actor_mat()*parent*_matrix(placed.matrix),"air"+str(player.action_serial))
		var slash:=int(crt4.get("air_slash_frame",1))
		if slash>1 and int(crt4.get("air_slash_born",-1))!=tick:crt4.air_slash_frame=1 if slash>=12 else slash+1
		if f==30 and sub<13:player.set_action("idle")
	else:_crt4_hide("air")
	if player.state=="backstep":
		var sub:=int(crt4.back_frame)
		if sub>1 and int(crt4.back_born)!=tick:
			crt4.back_frame=1 if sub+1>=9 else sub+1;sub=int(crt4.back_frame)
		if sub==3:_crt4_spawn(1154,player.position+Vector2(0,-10),Vector2(player.facing,1))
		_crt4_part("back","crt4_backstep_attack",6532,f,6531,sub,_matrix(player.definition.actions.backstep.parent_matrix))
	else:_crt4_hide("back")
func _crt4_main_children() -> void:
	var action: Dictionary=player.definition.actions[player.state]
	var f: int=player.source_frame
	if player.state=="skill_a" and f==26:
		if not crt4.has("a_charge_born"):crt4["a_charge_born"]=int(session.run.source_ticks);crt4.a_charge=1
		elif int(crt4.a_charge_born)!=int(session.run.source_ticks):crt4.a_charge=mini(6,int(crt4.a_charge)+1)
		_crt4_part("a_charge","crt4_a_charge",6446,f,6418,int(crt4.a_charge),_matrix(action.parent_matrix))
	else:_crt4_hide("a_charge")
	if player.state=="skill_e" and f>=45 and f<=64:
		var sub:=mini(10,2+int(session.run.source_ticks)-int(crt4.get("e_dark_born",session.run.source_ticks)))if crt4.has("e_dark_born")else 1
		_crt4_part("e_dark","crt4_e_dark_local",6506,f,6505,sub,_matrix(action.parent_matrix))
	else:_crt4_hide("e_dark")
func _crt4_spawn(sid: int,at: Vector2,size:=Vector2.ONE,depth:=-1,root_attachment:=true) -> Dictionary:
	_crt4_serial+=1
	if depth==-1:depth=_next_root_depth;_next_root_depth+=1
	if root_attachment:
		for item: Dictionary in _crt4_objects.duplicate():
			if bool(item.get("root_attachment",true))and int(item.depth)==depth:_crt4_retire(item,"source root depth replacement")
	var root:=Node2D.new();root.name="Source%d_%d"%[sid,_crt4_serial]
	(_source_dynamic_parent()if root_attachment and depth>=0 else self).add_child(root)
	root.position=at;root.scale=size;root.z_index=clampi(depth if depth>=0 else depth+16384,-4096,4096);root.set_meta("source_depth",depth)
	var item:={"source_id":sid,"id":_crt4_serial,"born":int(session.run.source_ticks),"frame":1,"age":1,"position":at,"scale":size,"visual":root,"depth":depth,"phase_born":int(session.run.source_ticks),"root_attachment":root_attachment}
	_crt4_objects.append(item)
	_record("crt4_world_born",{"source_id":sid,"id":item.id,"position":[at.x,at.y],"depth":depth,"scale":[size.x,size.y]})
	_crt4_emit_audio("root"+str(item.id),sid,1)
	return item
func _crt4_object_view(item: Dictionary,key: String,f: int,local:=Transform2D.IDENTITY,part:="main",alpha:=256.0) -> void:
	var id:="world_%d_%s"%[int(item.id),part]
	var mat: Transform2D=item.visual.transform*local
	var view:=_crt4_view(id,key,f,mat,false,int(item.depth),alpha)
	# Keep each object's root authoritative, including negative source depths.
	if view.get_parent()!=item.visual:view.reparent(item.visual,false)
	view.transform=item.visual.transform.affine_inverse()*mat
	if view.definition.has("baked_placement_matrix"):view.transform=view.transform*_matrix(view.definition.baked_placement_matrix).affine_inverse()
	view.z_index=0
func _crt4_retire(item: Dictionary,reason: String) -> void:
	if item not in _crt4_objects:return
	for child: Dictionary in _crt4_objects.duplicate():
		if int(child.get("parent_id",-1))==int(item.id)and not bool(child.get("root_attachment",true)):_crt4_retire(child,"source parent removed: "+reason)
	for id: String in _crt4_views.keys():
		if id.begins_with("world_%d_"%int(item.id)):_crt4_hide(id)
	if is_instance_valid(item.visual):item.visual.queue_free()
	_crt4_objects.erase(item)
	_record("crt4_world_retired",{"source_id":item.source_id,"id":item.id,"frame":item.frame,"age":item.age,"born":item.born,"reason":reason})
func _crt4_clear() -> void:
	for item: Dictionary in _crt4_objects.duplicate():_crt4_retire(item,"encounter_cleanup")
	for id: String in _crt4_views.keys():_crt4_hide(id)
	for key: String in ["ghost_step","kalla","kaz","bremen","saya","rhasa"]:crt4[key]=0
	crt4.fields.clear();crt4.ghost_frame=1;crt4.kalla_frame=1
	crt4.erase("ghost_timer");crt4.erase("kalla_timer");_crt4_contacts.clear();_crt4_audio_frames.clear();_crt4_bleeds.clear();zab="";position=Vector2.ZERO
	_crt4_fly.active=false;_crt4_fly.timeouts.clear()

func _crt4_kalla_hit(target: Node2D) -> void:
	var key: String="kalla_layers_"+target.identifier
	var count:=int(crt4.get(key,0))
	if count>=3:return
	count+=1;crt4[key]=count
	var status:=_crt4_target_status(3971,target,count+1)
	var item:=_crt4_spawn(3967+count,target.position,Vector2.ONE,target.z_index+2+count,false)
	item["target"]=target;item["parent_id"]=status.id;item["source_parent"]=3971;item["source_depth"]=count*2
func _crt4_bleed(target: Node2D) -> void:
	var tick:=int(session.run.source_ticks)
	if _crt4_bleeds.has(target.identifier):
		_crt4_bleeds[target.identifier].helper_born=tick;_crt4_bleeds[target.identifier].slow_born=tick
		_crt4_bleeds[target.identifier].helper=2;_crt4_bleeds[target.identifier].slow=2
		return
	_crt4_bleeds[target.identifier]={"target":target,"born":tick,"helper_born":tick,"slow_born":tick,"frame":1,"slow":2,"helper":2}
	_record("crt4_bleed_started",{"target":target.identifier,"container":4021,"frame":20})
func _crt4_advance_bleeds() -> void:
	for item: Dictionary in _crt4_bleeds.values():
		var age:=int(session.run.source_ticks)-int(item.born)
		item.frame=age%12+1
		item.helper=mini(140,int(session.run.source_ticks)-int(item.helper_born)+2)
		item.slow=mini(231,int(session.run.source_ticks)-int(item.slow_born)+2)
		var target: Node2D=item.target
		if target.hp<=0:continue
		if not target.airborne and not target.frozen and int(item.slow)<=229:target._stopped=int(item.slow)%2==1
		elif int(item.slow)==230:target._stopped=false
		var source: Dictionary=database.assets.source_geometry.enemy_status
		var root:=_matrix(source.enemy_parent_placements[str(int(target.definition.source_id))].matrix)
		var child:=_matrix(source.bleed.body_placement.matrix)
		var view:=_crt4_view("bleed_"+target.identifier,"enemy_bleed",int(item.frame),Transform2D.IDENTITY,false,target.z_index+2)
		if view.get_parent()!=target.visual_parent():view.reparent(target.visual_parent(),false)
		view.transform=Transform2D(Vector2(target.visual_scale.x,0),Vector2(0,target.visual_scale.y),Vector2.ZERO)*root*child

func _crt4_normal_rect(target: Node2D) -> Rect2:
	if target.frozen:return Rect2()
	if not target.airborne:return target.hurt_rect()
	var source: Dictionary=database.assets.source_geometry.get("air_normal_proxy",{}).get(str(int(target.definition.source_id)),{})
	if source.is_empty():return Rect2()
	var rect: Array=source.rect_enemy_local
	return target.transform_rect(Rect2(rect[0],rect[1],rect[2],rect[3]))
func _crt4_status_mat(target: Node2D,sid: int) -> Transform2D:
	var source: Dictionary=database.assets.source_geometry.enemy_status
	var mat:=Transform2D(Vector2(target.visual_scale.x,0),Vector2(0,target.visual_scale.y),target.position)*_matrix(source.enemy_parent_placements[str(int(target.definition.source_id))].matrix)
	var placements: Array=_crt4_geometry().source_geometry.world_semantics.enemy_status_placements.source_frames["1"]
	for row: Dictionary in placements:
		if int(row.source_id)==sid:return mat*_matrix(row.matrix)
	return mat
func _crt4_start_screen(kind: String) -> void:
	var spec: Dictionary=_crt4_geometry().source_geometry.screen_feedback
	var roots: Array=spec.roots[str(int(stage.source_root_frame))]
	for root: Dictionary in roots:
		for child: Dictionary in spec.children.get(str(int(root.source_id)),[]):
			if int(child.source_id)!=int(spec[kind].source_id):continue
			var id:="screen_"+kind
			var view:=_crt4_view(id,str(spec[kind].animation),int(spec[kind].entry),_matrix(root.matrix)*_matrix(child.matrix),false,int(root.depth))
			if view.get_parent()!=self:view.reparent(self,false)
			crt4[id+"_born"]=int(session.run.source_ticks);crt4[id+"_frame"]=int(spec[kind].entry)
			_record("crt4_screen_started",{"kind":kind,"source_id":int(child.source_id),"frame":int(spec[kind].entry)})
			return
	_record("crt4_screen_noop",{"kind":kind,"source_root":stage.source_root_frame})

func _crt4_settle_layers() -> void:
	for target: Node2D in enemies:
		var layers: Array=[]
		for item: Dictionary in _crt4_objects:
			if int(item.source_id)in[3968,3969,3970]and item.get("target")==target:layers.append(item)
		if layers.size()!=3 or not layers.all(func(item:Dictionary)->bool:return int(item.frame)==136):continue
		for item: Dictionary in layers:_crt4_retire(item,"three Kalla layers136 reset selector1")
		for item: Dictionary in _crt4_objects:
			if int(item.source_id)==3971 and item.get("target")==target:item.frame=1
		crt4["kalla_layers_"+target.identifier]=0
		_record("crt4_kalla_stack_reset",{"source_id":3971,"target":target.identifier,"frame":1})

func _crt4_named_feedback() -> void:
	for id: String in _crt4_views.keys():
		if not id.begins_with("slash_"):continue
		var f:=int(session.run.source_ticks)-int(crt4[id+"_born"])+1
		if f>=7:_crt4_hide(id)
		else:_crt4_views[id].set_source_frame(f)
	var table: Dictionary=_crt4_geometry().get("named_common_slash",{})
	var action: Dictionary=player.definition.actions[player.state]
	for proxy: Dictionary in table.get("actions",{}).get(player.state,{}).get("proxies",[]):
		if player.source_frame!=int(proxy.source_frame):continue
		if proxy.has("independent_clock_source_id") and int(crt4.get("air_slash_frame",1))!=int(proxy.active_child_source_frame):continue
		var mat:=_crt4_actor_mat()*_matrix(action.parent_matrix)*_matrix(proxy.placement.matrix)
		for target: Node2D in enemies:
			var touches:=false
			for rect: Array in proxy.local_rects:
				if _overlaps(mat*Rect2(rect[0],rect[1],rect[2],rect[3]),_crt4_normal_rect(target)):touches=true
			if not touches:continue
			var orientations: Array[String]=[]
			var category:=str(proxy.kind)
			if category=="horizontal":orientations.append("horizontal")
			else:
				if player.position.x<=target.position.x:orientations.append("left"if category=="left_diagonal"else"right")
				if player.position.x>=target.position.x:orientations.append("right"if category=="left_diagonal"else"left")
			var depth:=int(table.depths[category])
			var id:="slash_"+str(depth)
			for orientation: String in orientations:
				_crt4_hide(id)
				_crt4_view(id,"crt2_hit_slash_"+orientation,1,Transform2D(0,target.position),false,depth)
				crt4[id+"_born"]=int(session.run.source_ticks)
				var sound: Dictionary=_crt4_component("visuals").sounds.crt4_script_common_contact_sound5
				audio.play_stream(sound.audio_stream,float(sound.get("offset",0)),"crt4_script_common_contact_sound5")
				_record("crt4_named_feedback",{"source_id":int(action.source_id),"frame":player.source_frame,"target":target.identifier,"category":category,"orientation":orientation,"depth":depth,"sound_id":5})
func _crt4_ghost_loop() -> void:
	var spec: Dictionary=_crt4_component("6360").get("held_visual_loop",{})
	if spec.is_empty():return
	var ghost:=int(crt4.ghost_frame)
	if ghost<13:_crt4_hide("ghost_loop");crt4.erase("ghost_loop_mode");return
	var rows: Array=[]
	for change: Dictionary in spec.parent_tracks:
		if int(change.source_frame)>ghost:break
		rows=change.placements
	var placed: Dictionary={}
	for row: Dictionary in rows:
		if int(row.source_id) in [6356,6346]:placed=row;break
	if placed.is_empty():_crt4_hide("ghost_loop");return
	var mode:=20 if ghost==20 else 18 if ghost>=18 else 13
	if int(crt4.get("ghost_loop_mode",0))!=mode:
		crt4["ghost_loop_mode"]=mode;crt4["ghost_loop_born"]=int(session.run.source_ticks)
	var parent:=_crt4_placement(6732,player.parent_frame,6360)
	if parent.is_empty():_crt4_hide("ghost_loop");return
	var mat:=_matrix(parent.matrix)*_matrix(placed.matrix)
	if int(placed.source_id)==6356:mat=mat*_matrix(spec.container_inner_placement.matrix)
	var alpha:=float(placed.get("color_transform",{}).get("alphaMultTerm",256))
	_crt4_view("ghost_loop",str(spec.animation),(int(session.run.source_ticks)-int(crt4.ghost_loop_born))%int(spec.frames)+1,mat,true,1,alpha)
