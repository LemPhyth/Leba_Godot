extends Node2D
## Shared health, action clock, facing and exactly-once death events.
signal action_event(actor: Node2D, event: Dictionary)
signal state_changed(actor: Node2D)
signal action_finished(actor: Node2D, action: String)
const Visual = preload("res://scripts/combat/source_sprite.gd")
const BodyGeometry = preload("res://scripts/content/body_geometry.gd")
var identifier := ""
var team := "player"
var definition: Dictionary
var assets: Dictionary
var hp := 100.0
var mp := 100.0
var facing := 1
var state := "idle"
var action_age := 0
var source_frame := 1
var parent_frame := 1
var body_frame := 1
var body_stopped := false
var source_body_selector := 1
var body_local_x := 4.7
var action_child_x := 0.0
var air_action_frame := 1
var jump_visual: Node2D
var last_processed_frame := 0
var action_serial := 0
var visual: Node2D
var air_visual: Node2D
var air_hit_visual: Node2D
var hurt_visual: Node2D
var _air_hit_started := -1
var air_marker_stopped := false
var visual_scale := Vector2.ONE
var _sequence: Array = []
var _events_fired: Dictionary = {}
var _hit_targets: Dictionary = {}
var _dead_emitted := false
var _entry_pending := true
var _stopped := false
var _skip_child_advance := false
var source_parent_playing := false
var _parent_resume_pending := false
var independent_age := 1
var q_loading_visual: Node2D
var debug_draw := false
var vertical_speed := 0.0
var gravity_acceleration := 0.0
var airborne := false
var pending_death := false
## Source5881/5826 holds only T-marked enemy death clips at1 until source111.
var source_death_locked := false
var ground_y := 363.7
var cooldowns: Dictionary = {}
var _enemy_bar_textures: Dictionary = {}
var frozen := false
var freeze_frame := 1
var freeze_hit_frame := 1
var frozen_visual: Node2D
var t_hold_visual: Node2D
var skill_cooldown: int:
	get: return int(cooldowns.get("skill",0))
	set(value): cooldowns["skill"] = value

func visual_parent() -> Node:
	var author := get_node_or_null("AuthorOffset")
	return author if author != null else self

func configure(id: String, faction: String, data: Dictionary, catalog: Dictionary) -> void:
	identifier = id
	team = faction
	definition = data.duplicate(true)
	assets = catalog
	if team == "enemy":
		for key: String in ["enemy_hp_frame","enemy_hp_fill","enemy7437_hp_fill"]:
			if assets.textures.has(key):_enemy_bar_textures[key] = load(str(assets.textures[key].path))
	hp = float(definition.max_hp)
	mp = float(definition.max_mp)
	visual = get_node_or_null("AuthorOffset/Visual")
	if visual == null:
		visual = Visual.new()
		add_child(visual)
	if team == "player":
		hurt_visual = Visual.new()
		visual_parent().add_child(hurt_visual)
		hurt_visual.configure(assets.animations[str(definition.get("hit_fx_animation","player_hit_fx"))])
		hurt_visual.visible = false
		if int(definition.source_crt) in [0,1]:
			jump_visual = Visual.new()
			visual_parent().add_child(jump_visual)
			jump_visual.configure(assets.animations.crt0_jump_air if int(definition.source_crt) == 0 else assets.animations.crt1_jump_air)
			jump_visual.visible = false
			if int(definition.source_crt) == 0 and assets.animations.has("crt0_q_loading"):
				q_loading_visual = Visual.new()
				visual_parent().add_child(q_loading_visual)
				q_loading_visual.configure(assets.animations.crt0_q_loading)
				q_loading_visual.visible = false
	if definition.has("air_animation"):
		air_visual = Visual.new()
		visual_parent().add_child(air_visual)
		air_visual.configure(assets.animations[definition.air_animation])
		air_visual.visible = false
		air_hit_visual = Visual.new()
		visual_parent().add_child(air_hit_visual)
		air_hit_visual.configure(assets.animations[str(definition.get("air_hit_animation","air_hit_marker"))])
		air_hit_visual.visible = false
	set_action("idle")

func set_action(next: String) -> bool:
	if state == "dead" or not definition.actions.has(next):
		return false
	state = next
	action_age = 0
	_entry_pending = true
	_stopped = false
	_skip_child_advance = false
	source_parent_playing = false
	_parent_resume_pending = false
	independent_age = 1
	last_processed_frame = 0
	action_serial += 1
	_events_fired.clear()
	_hit_targets.clear()
	var action: Dictionary = definition.actions[next]
	parent_frame = int(action.get("source_parent",1))
	body_frame = 1;body_stopped = false
	source_body_selector = 1
	body_local_x = 4.7
	action_child_x = float(action.get("child_x_easing",{}).get("initial",-3.0 if next == "skill_z" else 0.0))
	if team == "player" and int(definition.source_crt) in [2,3,4]:action_child_x = float(action.get("parent_matrix",[1,0,0,1,0,0])[4])
	air_action_frame = 1
	visual.position = action.get("visual_offset",Vector2.ZERO)
	if is_instance_valid(jump_visual):
		jump_visual.visible = false
	if is_instance_valid(q_loading_visual):q_loading_visual.visible = false
	if is_instance_valid(t_hold_visual):t_hold_visual.visible = false
	var animation: Dictionary = assets.animations[action.animation]
	_sequence = []
	for raw_frame: Variant in action.get("sequence", []):
		# JSON numeric values are floats in Godot; source frame IDs are integers.
		_sequence.append(int(raw_frame))
	if _sequence.is_empty():
		for item: Dictionary in animation.frames:
			_sequence.append(int(item.source_frame))
	visual.configure(animation)
	source_frame = int(_sequence[0])
	if action.has("parent_sequence"):
		parent_frame = int(action.parent_sequence[0])
	elif bool(action.get("parent_from_source_frame",false)):
		parent_frame = source_frame
	visual.set_source_frame(source_frame)
	_update_facing()
	_update_hurt_visual()
	state_changed.emit(self)
	return true

func set_facing(value: int) -> void:
	facing = -1 if value < 0 else 1
	_update_facing()

func play_source_parent() -> void:
	# AVM1 same-frame gotoAndPlay resumes a stopped parent without reconstructing
	# its child or rerunning its stop/counter script. The next tick enters parent+1.
	# ACT06 original Ruffle probe contrasts same gotoAndStop, play and goto107.
	if source_parent_playing:return
	source_parent_playing = true
	_parent_resume_pending = true
	_skip_child_advance = true

func _update_facing() -> void:
	if is_instance_valid(visual):
		visual.scale = Vector2(visual_scale.x * source_facing(), visual_scale.y)
	if is_instance_valid(air_visual):
		air_visual.scale = visual.scale
		var marker: Dictionary = assets.source_geometry.air_hit_markers[str(int(definition.source_id))]
		air_hit_visual.position = Vector2(marker.offset_px[0],marker.offset_px[1])*visual.scale
		air_hit_visual.scale = Vector2(marker.scale[0],marker.scale[1])*visual.scale
	if is_instance_valid(hurt_visual):
		var fx: Dictionary = assets.source_geometry.player_hit_fx["crt_%d" % int(definition.source_crt)]
		var at: Array=fx.get("offset_by_parent",{}).get(str(parent_frame),fx.offset_px)
		hurt_visual.position = Vector2(at[0],at[1])*visual.scale
		hurt_visual.scale = visual.scale
	if is_instance_valid(jump_visual):
		jump_visual.scale = visual.scale
	if is_instance_valid(q_loading_visual):q_loading_visual.scale = visual.scale
	if is_instance_valid(t_hold_visual):t_hold_visual.scale = visual.scale

func update_jump_visual() -> void:
	if not is_instance_valid(jump_visual):
		return
	if int(definition.source_crt) == 1:
		var key := "d_follow" if state == "d_follow" else "jump"
		var component: Dictionary = definition.actions[key].component_data
		var rows: Array = component.air_overlay_by_frame.get(str(source_frame),[])
		jump_visual.visible = state in ["jump","d_follow"] and not rows.is_empty()
		if jump_visual.visible:
			if jump_visual.definition != assets.animations[component.air_animation]:jump_visual.configure(assets.animations[component.air_animation])
			var parent: Array = component.parent_matrix
			var child: Array = rows[0].matrix
			jump_visual.position = Vector2(parent[4]+child[4],parent[5]+child[5])*visual.scale
			jump_visual.set_source_frame(air_action_frame)
		return
	var frames: Dictionary = assets.source_geometry.crt0_jump.air_overlay_by_frame
	jump_visual.visible = state == "jump" and frames.has(str(source_frame))
	if jump_visual.visible:
		var at: Array = frames[str(source_frame)].offset_px
		jump_visual.position = Vector2(at[0],at[1])*visual.scale
		jump_visual.set_source_frame(air_action_frame)

func _update_hurt_visual() -> void:
	if is_instance_valid(hurt_visual):
		hurt_visual.visible = state == "hit" or int(definition.get("source_crt",-1))==4 and state=="knockdown"
		if hurt_visual.visible:
			hurt_visual.set_source_frame(mini(source_frame,8))

func request_hurt(child_frame := 0) -> void:
	if hp <= 0:
		return
	var existing_child := state == "hit"
	if not existing_child:
		set_action("hit")
		# A late collision creates source1 now; next source tick advances to2.
		_entry_pending = false
	if child_frame > 0:
		if not seek_action_frame(child_frame):
			return
		if existing_child:
			# Ruffle controlled goto/seek and real-contact probes: an existing
			# child still advances in this frame; a newly placed child does not.
			advance_tick()

func seek_action_frame(frame_number: int, defer_child_tick := false) -> bool:
	var index := _sequence.find(frame_number)
	if index < 0:
		push_error("动作 %s 不含源帧%d" % [state,frame_number])
		return false
	action_age = index
	_skip_child_advance = defer_child_tick
	_stopped = frame_number in definition.actions[state].get("hold_at",[])
	_entry_pending = false
	source_frame = frame_number
	last_processed_frame = frame_number
	_events_fired.clear()
	visual.set_source_frame(source_frame)
	_update_hurt_visual()
	return _dispatch_frame_events(definition.actions[state],action_serial)

func play_air_hit(source_tick: int) -> void:
	_air_hit_started = source_tick
	air_marker_stopped = false

func update_air_visual(source_tick: int) -> void:
	if not is_instance_valid(air_visual):
		return
	visual.visible = not airborne
	air_visual.visible = airborne
	if not airborne:
		air_hit_visual.visible = false
		_air_hit_started = -1
		air_marker_stopped = false
		return
	var pose := 2 if vertical_speed > 0.0 else 1
	air_visual.set_source_frame(pose)
	if pose == 2:
		# Source outer air pose2 removes the child marker; it does not freeze it.
		_air_hit_started = -1
		air_marker_stopped = false
	var effect_frame := 2 if air_marker_stopped else source_tick-_air_hit_started+1
	air_hit_visual.visible = _air_hit_started >= 0 and effect_frame <= 7
	if air_hit_visual.visible:
		air_hit_visual.set_source_frame(effect_frame)

func source_facing() -> int:
	# Source3898 faces left by default; crt0 faces right. Logic always uses +/-worldX.
	return facing * int(definition.get("source_facing",1))

func advance_tick() -> void:
	if source_parent_playing:
		if _parent_resume_pending:
			_parent_resume_pending = false
		else:
			var next_parent := parent_frame+1
			var next_action := ""
			for key: String in definition.actions:
				if int(definition.actions[key].get("source_parent",-1)) == next_parent:
					next_action = key
					break
			if next_action.is_empty():
				push_error("源父时间线缺少下一页 %d" % next_parent)
				source_parent_playing = false
			else:
				var previous_parent := parent_frame
				set_action(next_action)
				action_event.emit(self,{"kind":"source_parent_enter","previous_parent":previous_parent,"parent":next_parent})
	var action: Dictionary = definition.actions[state]
	if _entry_pending:
		_entry_pending = false
	else:
		independent_age += 1
		if not _stopped and not _skip_child_advance:action_age += 1
		_skip_child_advance = false
		if action.has("body_track"):
			var stop: int = int(assets.source_geometry[action.body_track].body_track.stop_source_frame)
			body_frame = mini(body_frame+1,stop)
		elif team == "player" and int(definition.source_crt) in [1,2,3,4] and not body_stopped:body_frame += 1
		if state == "skill_z" and int(definition.get("source_crt",-1)) == 0:
			action_child_x = twips(action_child_x + (10.0-action_child_x)/2.0)
			visual.position.x = float(action.get("visual_offset",Vector2.ZERO).x)+(action_child_x+3.0)*visual_scale.x*facing
		if state == "move_z" and int(definition.get("source_crt",-1)) == 0:
			body_local_x = twips(body_local_x+(180.0-body_local_x)/6.0)
		if action_age >= _sequence.size():
			if bool(action.get("loop",false)):
				action_age = 0
				_events_fired.clear()
			else:
				action_age = _sequence.size()-1
	source_frame = int(_sequence[action_age])
	if source_frame in action.get("hold_at",[]):_stopped = true
	if action.has("parent_sequence"):
		parent_frame = int(action.parent_sequence[action_age])
	elif bool(action.get("parent_from_source_frame",false)):
		parent_frame = source_frame
	visual.set_source_frame(source_frame)
	update_jump_visual()
	if is_instance_valid(q_loading_visual):
		q_loading_visual.visible = state == "skill_q" and source_frame <= 12
		if q_loading_visual.visible:q_loading_visual.set_source_frame(mini(independent_age,19))
	if team == "player" and int(definition.source_crt) == 0 and state == "skill_t" and source_frame == 6:
		if not is_instance_valid(t_hold_visual):
			t_hold_visual = Visual.new()
			add_child(t_hold_visual)
			t_hold_visual.configure(assets.animations.crt0_t_hold)
			t_hold_visual.scale = visual.scale
		t_hold_visual.visible = true
		t_hold_visual.set_source_frame((independent_age-6)%16+1)
	_update_hurt_visual()
	var serial := action_serial
	last_processed_frame = source_frame
	# Provenance-labelled StartSound belongs to entering the original frame.
	# Contact can seek this child later (V5->17), without erasing its entry cue.
	# Ordinary authored sound events keep their ordered/interruptible semantics.
	if not _dispatch_frame_events(action,serial,true):
		_entry_pending = false
		return
	for window: Dictionary in action.get("windows", []):
		if source_frame >= int(window.from) and source_frame <= int(window.until):
			action_event.emit(self, window)
			if action_serial != serial:
				_entry_pending = false
				return
	if not _dispatch_frame_events(action,serial):
		_entry_pending = false
		return
	# Terminal control frames return to their parent in the same source tick.
	# Otherwise keep the processed pose on screen until the next source tick.
	if action_age == _sequence.size()-1 and not bool(action.get("loop",false)) and not bool(action.get("hold",false)):
		action_finished.emit(self,state)
		if action_serial == serial:
			set_action(str(action.get("next_action","idle")))
		_entry_pending = false
	queue_redraw()

func consume_entry_frame() -> void:
	# Used for a child placed after this actor's source advance in the same tick.
	_entry_pending = false

func _dispatch_frame_events(action: Dictionary, serial: int, sounds_only := false) -> bool:
	var events: Array = action.get("events", [])
	for index in range(events.size()):
		var event: Dictionary = events[index]
		if sounds_only and (str(event.get("kind",""))!="sound" or not event.has("source_sound_info")):continue
		var key := str(index)
		if source_frame == int(event.frame) and not _events_fired.has(key):
			_events_fired[key] = true
			action_event.emit(self, event)
			if action_serial != serial:
				return false
	return true

func receive_damage(amount: float, reaction := true) -> bool:
	if hp <= 0 or amount <= 0:
		return false
	hp = maxf(0, hp - amount)
	queue_redraw()
	if hp == 0:
		if frozen:clear_freeze()
		if airborne:
			pending_death = true
		else:
			set_action("dead")
	elif reaction:
		set_action("hit")
	state_changed.emit(self)
	return true

func claim_target(target_id: String) -> bool:
	if _hit_targets.has(target_id):
		return false
	_hit_targets[target_id] = true
	return true

func hurt_rect() -> Rect2:
	var current_action: Dictionary = definition.actions[state]
	if current_action.has("hurt_rect_override"):return transform_rect(current_action.hurt_rect_override)
	if not airborne and source_frame in definition.get("hurt_body_excluded_source_frames",[]):return Rect2()
	if team == "player" and int(definition.source_crt) == 1:return _crt1_body("몸빵")
	if team == "player" and int(definition.source_crt) == 2:return _crt2_body("몸빵")
	if team == "player" and int(definition.source_crt) == 3:return _crt3_body("몸빵")
	if team == "player" and int(definition.source_crt) == 4:return transform_rect(BodyGeometry.crt4_rect(assets.source_geometry,parent_frame,body_frame,"몸빵",source_body_selector))
	if frozen:
		var row: Dictionary = assets.source_geometry.enemy_status.frozen[str(int(definition.source_id))]
		var inner: Array = row.inner_root_placement.matrix
		for child: Dictionary in row.inner_display_list:
			if int(child.alpha_mult) != 0:continue
			var m: Array = child.matrix
			var r := Rect2(-48.25,-95.95,104.85,172.45)
			return transform_rect(Transform2D(Vector2(m[0],m[1]),Vector2(m[2],m[3]),Vector2(m[4]+inner[4],m[5]+inner[5]))*r)
	var action: Dictionary = definition.actions[state]
	if bool(action.get("body_absent",false)):
		return Rect2()
	if action.has("body_track"):
		var track: Dictionary = assets.source_geometry[action.body_track].body_track
		var body: Dictionary = track.frames_by_body_frame[str(mini(body_frame,int(track.stop_source_frame)))]
		if body.empty:
			return Rect2()
		var rect: Array = body.rect
		return transform_rect(Rect2(rect[0],rect[1],rect[2],rect[3]))
	if state == "move_z":
		var rect: Array = assets.source_geometry.crt0_body.rect
		return transform_rect(Rect2(rect[0]+body_local_x-4.7,rect[1],rect[2],rect[3]))
	if airborne and definition.has("air_hurt_rect"):
		var air_rect: Array = definition.air_hurt_rect
		return transform_rect(Rect2(air_rect[0],air_rect[1],air_rect[2],air_rect[3]))
	if definition.has("hurt_rect"):
		var rect: Array = definition.hurt_rect
		return transform_rect(Rect2(rect[0],rect[1],rect[2],rect[3]))
	if team == "player":
		var r: Array = assets.source_geometry.crt0_body.rect
		return transform_rect(Rect2(r[0],r[1],r[2],r[3]))
	# 1119 action body in 3898, then parent offset (0,-1325) twips.
	return transform_rect(Rect2((-965.0*0.9993286-155.0)/20.0,(-1919.0*0.9997101-229.0-1325.0)/20.0,2097.0*0.9993286/20.0,3449.0*0.9997101/20.0))

func gravity_rect() -> Rect2:
	# This original body persists when normal Z removes the attackable body.
	if team == "player":
		if int(definition.source_crt) == 1:return _crt1_body("중력몸빵")
		if int(definition.source_crt) == 2:return _crt2_body("중력몸빵")
		if int(definition.source_crt) == 3:return _crt3_body("중력몸빵")
		if int(definition.source_crt) == 4:return transform_rect(BodyGeometry.crt4_rect(assets.source_geometry,parent_frame,body_frame,"중력몸빵",source_body_selector))
		var r: Array = assets.source_geometry.crt0_body.rect
		return transform_rect(Rect2(r[0],r[1],r[2],r[3]))
	if definition.has("gravity_rect"):
		var r: Array = definition.gravity_rect
		return Rect2(position+Vector2(r[0],r[1])*visual_scale,Vector2(r[2],r[3])*visual_scale)
	if assets.source_geometry.has("enemy_gravity_body"):
		var data: Dictionary = assets.source_geometry.enemy_gravity_body[str(int(definition.source_id))]
		var r: Array = data.placements_by_outer_source_frame["1"].rect_enemy_local
		# Outer root never flips with its inner action or air pose.
		return Rect2(position+Vector2(r[0],r[1])*visual_scale,Vector2(r[2],r[3])*visual_scale)
	return hurt_rect()

func begin_freeze() -> void:
	if hp <= 0:return
	if not frozen:
		set_action("idle")
		frozen = true
		freeze_hit_frame = 1
		frozen_visual = Visual.new()
		visual_parent().add_child(frozen_visual)
		var row: Dictionary = assets.source_geometry.enemy_status.frozen[str(int(definition.source_id))]
		frozen_visual.configure(assets.animations[row.body_animation])
	freeze_frame = 1
	airborne = false
	vertical_speed = 0.0
	gravity_acceleration = 0.0
	refresh_freeze()

func refresh_freeze() -> void:
	if not frozen:return
	var row: Dictionary = assets.source_geometry.enemy_status.frozen[str(int(definition.source_id))]
	parent_frame = 1
	source_frame = int(row.inner_source_frame)
	visual.visible = false
	air_visual.visible = false
	air_hit_visual.visible = false
	var inner: Array = row.inner_root_placement.matrix
	var ice: Array = row.inner_display_list[0].matrix
	frozen_visual.position = Vector2(inner[4]+ice[4],inner[5]+ice[5])*visual_scale*Vector2(source_facing(),1)
	frozen_visual.scale = visual_scale*Vector2(source_facing(),1)
	frozen_visual.set_source_frame(freeze_hit_frame)

func advance_freeze() -> void:
	if not frozen:return
	freeze_frame += 1
	if freeze_hit_frame > 1:
		freeze_hit_frame += 1
		if freeze_hit_frame in [4,7]:freeze_hit_frame = 1
	if freeze_frame >= 145:clear_freeze()
	else:refresh_freeze()

func clear_freeze() -> void:
	frozen = false
	if is_instance_valid(frozen_visual):frozen_visual.queue_free()
	frozen_visual = null
	set_action("idle")
	visual.visible = true

static func twips(value: float) -> float:
	return float(int(value*20.0))/20.0

static func source_coordinate(value: float) -> float:
	# Node2D is float32; recover the integer-twips value before AS2 double arithmetic.
	return float(roundi(value*20.0))/20.0

func transform_rect(local: Rect2) -> Rect2:
	var origin := local.position * visual_scale
	var size := local.size * visual_scale
	if source_facing() < 0:
		origin.x = -origin.x - size.x
	var author := get_node_or_null("AuthorOffset")
	var transformed := Rect2(origin,size)
	if author != null:transformed = author.transform * transformed
	transformed.position += position
	return transformed

func _crt1_body(kind: String) -> Rect2:
	var override_x := body_local_x if state == "move_z" and kind == "몸빵" else INF
	return transform_rect(BodyGeometry.crt1_rect(assets.source_geometry,parent_frame,body_frame,kind,override_x))

func gunhawk_rect() -> Rect2:
	return _crt1_body("건호크몸빵") if team == "player" and int(definition.source_crt) == 1 else Rect2()

func _draw() -> void:
	if team == "enemy" and assets.source_geometry.has("battle_hud"):
		# Outer enemy root never flips; only its inner/air action does.
		var bars: Dictionary = assets.source_geometry.battle_hud.enemy_bars.get(str(int(definition.source_id)),{})
		for id: String in bars:
			var filled: bool = str(bars[id].get("role","fill" if id == "3902" else "frame")) == "fill"
			if filled and hp <= 0:continue
			var key := str(bars[id].get("texture_key","enemy_hp_fill" if filled else "enemy_hp_frame"))
			var data: Dictionary = assets.textures[key]
			var matrix: Array = bars[id].matrix
			var amount := clampf(hp/float(definition.max_hp),0.0,1.0) if filled else 1.0
			draw_set_transform(Vector2(matrix[4],matrix[5])*visual_scale,0,visual_scale*Vector2(amount,1))
			draw_texture(_enemy_bar_textures[key],Vector2(-data.pivot[0],-data.pivot[1]))
			draw_set_transform(Vector2.ZERO)
	if debug_draw:
		var box := hurt_rect()
		box.position -= position
		draw_rect(box,Color(0.2,0.9,1.0,0.8),false,1.0)
		draw_circle(Vector2.ZERO,2.0,Color.YELLOW)

func _crt2_body(kind: String) -> Rect2:
	var rect := BodyGeometry.crt2_rect(assets.source_geometry,parent_frame,body_frame,kind)
	if kind == "중력몸빵" and rect.has_area():rect.position.x += body_local_x-4.7
	return transform_rect(rect)

func _crt3_body(kind: String) -> Rect2:
	var rect := BodyGeometry.crt3_rect(assets.source_geometry,parent_frame,body_frame,kind)
	if kind == "중력몸빵" and rect.has_area():rect.position.x += body_local_x-4.7
	return transform_rect(rect)
