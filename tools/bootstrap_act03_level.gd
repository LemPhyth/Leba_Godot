extends SceneTree
## Explicit initial authoring of root9 only. Existing author resources/scenes are preserved.
## Does not edit ContentDB, runtime, shared index, asset catalog or original resources.
const Convert = preload("res://tools/content_conversion.gd")
const SOURCE := "res/scripts/frame_9/PlaceObject3_7437_294/"
const INNER := "res/scripts/DefineSprite_7427/"
var convert := Convert.new()
var assets: Dictionary

func _initialize() -> void:call_deferred("_run")

func _run() -> void:
	if "--bootstrap-root9" not in OS.get_cmdline_user_args():
		push_error("仅首次生成使用：-- --bootstrap-root9；已有作者文件保留。")
		quit(1)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_catalog.json"))
	if not parsed is Dictionary:
		push_error("asset_catalog.json 无效")
		quit(1)
		return
	assets = parsed
	var missing: Array[String] = []
	for key: String in ["idle","move","attack","ranged","melee","special","hit","evade","dead","air","frozen","air_hit_marker"]:
		if not assets.animations.has("enemy7437_"+key):missing.append("animations.enemy7437_"+key)
	for key: String in ["map7370","training_ground"]:
		if not assets.textures.has(key):missing.append("textures."+key)
	for key: String in ["enemy7437_attack","enemy7437_ranged","enemy7437_swing","enemy7437_melee","enemy7437_special_start","enemy7437_special_hit","enemy7437_death"]:
		if not assets.audio.sfx.has(key):missing.append("audio.sfx."+key)
	for path: String in ["res://scenes/actors/combatant.tscn","res://scenes/actors/enemy.tscn","res://scenes/ui/source_hud.tscn"]:
		if not FileAccess.file_exists(path):missing.append(path)
	if not missing.is_empty():
		push_error("原资源派生尚未就绪，未创建作者文件："+str(missing))
		quit(1)
		return
	var enemy: Resource = _enemy()
	var packed := _stage(enemy)
	# Read the saved scene back; inspect serialization, not transient generator nodes.
	var saved: Node2D = packed.instantiate()
	var hud: Node2D = saved.get_node("HUD")
	var layers: Dictionary = {"HUD":hud.z_index}
	for crt: String in ["CRT0","CRT1"]:
		for id: String in ["HPLayout","MPLayout","HPHoverLayout","MPHoverLayout"]:
			var item: Node2D = hud.get_node("Characters/"+crt+"/"+id)
			layers[crt+"/"+id] = {"z":item.z_index,"relative":item.z_as_relative}
	var w_ammo: Node2D = hud.get_node("Characters/CRT1/WAmmoLayout")
	layers["CRT1/WAmmoLayout"] = {"z":w_ammo.z_index,"relative":w_ammo.z_as_relative}
	print("ACT03_ROOT9_SAVED_LAYOUT "+JSON.stringify(layers))
	saved.free()
	print("ACT03_ROOT9_BOOTSTRAP authored root9/enemy7437 created or preserved; index remains root-agent owned")
	quit()

func _rect(bounds: Array, matrix: Array) -> Rect2:
	# Source rectangle and translation are twips. Matrix order [sx,skewY,skewX,sy,tx,ty].
	var result := Rect2()
	var first := true
	for x: float in [float(bounds[0]),float(bounds[2])]:
		for y: float in [float(bounds[1]),float(bounds[3])]:
			var point := Vector2(float(matrix[0])*x+float(matrix[2])*y+float(matrix[4]),float(matrix[1])*x+float(matrix[3])*y+float(matrix[5]))/20.0
			if first:
				result = Rect2(point,Vector2.ZERO)
				first = false
			else:result = result.expand(point)
	return result

func _array(rect: Rect2) -> Array:return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]

func _window(first: int, last: int, bounds: Array, matrix: Array, knockdown := false) -> Dictionary:
	return {"from":first,"until":last,"kind":"enemy_knockdown" if knockdown else "enemy_hit",
		"damage":5.0 if knockdown else 4.0,"knockback":3.0 if knockdown else 20.0,
		"once_per_action":false,"local_rects":[_rect(bounds,matrix)],
		"source":INNER+"frames %d..%d; root9 observer %s"%[first,last,"34/38" if knockdown else "33/37"],
		"source_damage_note":"Damage is observed on the unique player marker, not directly for every overlapping source tick."}

func _sound(frame: int, key: String, sound_id: int) -> Dictionary:
	return {"frame":frame,"kind":"sound","sound":key,"source_sound_id":sound_id}

func _actions() -> Dictionary:
	var normal := [-1110,-1341,1110,20]
	var wave1 := [-2250,-2670,2250,0]
	var wave2 := [-1642,-2545,1642,0]
	var slash := [-423,-1070,545,20]
	var blast := [-2901,-2241,2901,20]
	return {
		"idle":{"animation":"enemy7437_idle","source_parent":1,"sequence":[1],"hold":true},
		"move":{"animation":"enemy7437_move","source_parent":2,"sequence":range(1,11),"loop":true},
		"recover":{"animation":"enemy7437_move","source_parent":2,"sequence":[1,2,3],"parent_sequence":[2,3,4],"next_action":"idle"},
		"attack":{"animation":"enemy7437_attack","source_parent":6,"parent_from_source_frame":true,"sequence":range(6,30)+range(152,156),"next_action":"recover",
			"windows":[_window(13,21,normal,[2.0639038,0,0,1.6659241,-1660,171])],"events":[_sound(10,"enemy7437_attack",7383)]},
		"ranged":{"animation":"enemy7437_ranged","source_parent":41,"parent_from_source_frame":true,"sequence":range(41,101)+range(30,41),"next_action":"idle",
			"windows":[_window(54,54,normal,[.9268799,0,0,.93844604,-1403,155]),
				_window(55,57,normal,[.9268799,0,0,.93844604,-2210,155]),
				_window(58,58,wave1,[.9268799,0,0,.93844604,-2486,-94]),
				_window(59,59,wave1,[.8952942,-.2428894,.23989868,.9064636,-2586,164]),
				_window(60,61,wave2,[.9268799,0,0,.93844604,-3869,51]),
				_window(62,62,wave2,[1.2774353,0,0,.49578857,-4592,203]),
				_window(63,65,normal,[.9268799,0,0,.93844604,-4527,155],true)],
			"events":[_sound(42,"enemy7437_ranged",7406),_sound(54,"enemy7437_swing",169),_sound(63,"enemy7437_swing",169)]},
		"melee":{"animation":"enemy7437_melee","source_parent":101,"parent_from_source_frame":true,"sequence":range(101,121),"next_action":"recover",
			"windows":[_window(108,108,slash,[2.0306396,0,0,1.9714355,-1756,60],true),_window(109,111,slash,[3.31839,0,0,2.4095306,-1178,10],true)],
			"events":[_sound(106,"enemy7437_melee",5209)]},
		"special":{"animation":"enemy7437_special","source_parent":121,"parent_from_source_frame":true,"sequence":range(121,141),"next_action":"recover",
			"windows":[_window(131,137,blast,[1.5552673,0,0,.94776917,-88,260],true)],
			"events":[_sound(121,"enemy7437_special_start",6089),_sound(131,"enemy7437_special_hit",6096)]},
		"hit":{"animation":"enemy7437_hit","source_parent":141,"parent_from_source_frame":true,"sequence":range(141,149),"next_action":"recover"},
		"evade":{"animation":"enemy7437_evade","source_parent":150,"sequence":range(1,36),"next_action":"recover","retreat_per_tick":3.0},
		"dead":{"animation":"enemy7437_dead","source_parent":151,"sequence":range(1,9),"hold":true,
			"events":[{"frame":3,"kind":"death_settled"},_sound(7,"enemy7437_death",5625)]},
		"frozen":{"animation":"enemy7437_frozen","source_parent":149,"sequence":[1],"hold":true}
	}

func _enemy() -> Resource:
	var enemy := Convert.Character.new()
	enemy.identifier = "goblin_7437"
	enemy.title = "巨剑阿修罗（7437）"
	enemy.source_crt = -1
	enemy.max_hp = 500.0
	enemy.max_mp = 0.0
	enemy.move_per_tick = 3.0
	enemy.actor_scene = load("res://scenes/actors/enemy.tscn")
	enemy.source = SOURCE+"load/_2=HP500; source6968 difficulty multipliers; docs/LEBA-ACT-03_流程依据.md"
	var trigger := [-310,-600,310,20]
	var body := _rect([-813,-1179,813,1179],[1,0,0,.6920471,-62,-799])
	var air_shape := _rect([-965,-1919,1132,1530],[.9993286,0,0,.9997101,25,194])
	var air_rect := Rect2(Vector2(-4.35,-48.85)+air_shape.position*Vector2(.74661255,.56915283),air_shape.size*Vector2(.74661255,.56915283))
	enemy.extra = {
		"source_id":7437,"source_facing":-1,"hurt_child_seek":0,"airborne_drift_per_tick":0.8,
		"hurt_rect":_array(body),"air_hurt_rect":_array(air_rect),
		"gravity_rect":_array(_rect([-889,-2237,888,30],[1,0,0,1,-16,-142])),
		"move_rect":_array(_rect([-746,-754,745,754],[6.061737,0,0,1.152771,-5145,-852])),
		"move_source_frames":[1,2,3],"trigger_source_frames":[1,2,3],
		"proximity_rect":_array(_rect(trigger,[2.9310303,0,0,5.137924,-2518,480])),
		"proximity_moving_rect":_array(_rect(trigger,[2.9310303,0,0,5.137924,-2378,480])),
		"ranged_rect":_array(_rect(trigger,[1,0,0,1,-4575,-340])),
		"ranged_moving_rect":_array(_rect(trigger,[1,0,0,1,-4675,-360])),
		"ranged_target_body":"normal",
		"melee_rect":_array(_rect(trigger,[2.4396973,0,0,2.0905762,-300,-124])),
		"melee_moving_rect":_array(_rect(trigger,[2.4396973,0,0,2.0905762,-220,-124])),
		"trigger_order":["attack","ranged","melee"],"hurt_body_excluded_source_frames":range(121,131),
		"air_animation":"enemy7437_air","air_hit_animation":"enemy7437_air_hit_marker",
		"frozen_animation":"enemy7437_frozen","freeze_duration":145,
		"knockdown_hurt_observer":5.0,"source_player_knockdown_parents":{"crt_0":15,"crt_1":45},
		"knockdown_push_per_tick":3.0,
		"timer":{"cycle_ticks":215,"events":[{"tick":118,"action":"evade"},{"tick":215,"action":"special"}],"source_id":7440},
		"reward_by_difficulty":{"expert":300,"master":350,"king":400,"slayer":450,"beast":600},
		"movement_status":"Source root9 EF5/6 conditional3; EF7/8 sniper5; mobsp unassigned, no unconditional chase.",
		"calibration":"Static AS/XML restoration; root9 natural Flash/Ruffle play not yet observed. Exact concurrent callback timing remains later calibration."
	}
	for id: String in _actions():
		var row: Dictionary = _actions()[id]
		row["source"] = INNER+" / "+SOURCE+"; docs/LEBA-ACT-03_流程依据.md §4"
		row["calibration"] = "Source frames and matrices confirmed statically; original root9 dynamic play not yet compared."
		enemy.actions.append(convert.action(id,row,assets,"res://content/enemies/goblin_7437_actions/"+id+".tres"))
	return convert.save_new(enemy,"res://content/enemies/goblin_7437.tres")

func _sprite(parent: Node, owner_node: Node, key: String, label: String, stage_position: Vector2, depth: int) -> Sprite2D:
	var row: Dictionary = assets.textures[key]
	var sprite: Sprite2D = convert.add(parent,Sprite2D.new(),owner_node,label)
	sprite.texture = load(str(row.path))
	sprite.centered = false
	sprite.position = stage_position-Vector2(row.pivot[0],row.pivot[1])
	sprite.z_index = depth
	return sprite

func _stage(enemy: Resource) -> PackedScene:
	var rules := Convert.Stage.new()
	rules.identifier = "root_9"
	rules.title = "巨剑阿修罗"
	rules.source_root_frame = 9
	rules.enemy_type = "goblin_7437"
	rules.enemy_hp = 500.0
	rules.player_max_hp = 100.0
	rules.player_max_mp = 100.0
	rules.next_stage = "root_10"
	rules.music = "battle"
	rules.reward = 300
	rules.player_hurt_observers = PackedFloat32Array([4.0])
	rules.source = "res/scripts/frame_9; res/structure/game.xml root9; docs/LEBA-ACT-03_流程依据.md"
	rules.extra = {"source_map_id":7370,"y_initial_matrix":[1.0,0.0,0.0,1.0,-6.3,320.55],"open_dialogue":"root_9_open","clear_dialogue":"root_9_clear",
		"clear_counter_frame":2,"progress_gain":1,"retry_source_root_frame":8,"knockdown_hurt_observers":[5.0],
		"reset_hp":100.0,"reset_mp":100.0,"reward_by_nan":{"0":300,"1":350,"2":400,"3":450,"4":600},
		"reward_by_difficulty":{"expert":300,"master":350,"king":400,"slayer":450,"beast":600},
		"source_depths":{"enemies":[294],"ground":999,"hp":1009,"mp":1007,"player":1014,"skills":595,"sniper":2734,"y":809,"hud":2832},
		"end_source":"7437 death7426/3 -> root9 count2/child2 -> 7469/17..21 ->22 ->root.gotoAndStop10",
		"unimplemented_source_content":["Random equipment drops source _70/_71 and password branch normally bypassed at7469/7"]}
	var node := Node2D.new()
	node.name = "root_9"
	node.set_script(load("res://scripts/content/stage_layout.gd"))
	node.rules = convert.save_new(rules,"res://content/stages/root_9.tres")
	_sprite(node,node,"map7370","Map",Vector2(302.35,88.6),3)
	_sprite(node,node,"training_ground","SourceGround",Vector2(305.85,360.15),999)
	var bounds: Node2D = convert.add(node,Node2D.new(),node,"Bounds")
	for entry: Array in [["Left",0.0],["Right",550.0]]:
		var marker: Marker2D = convert.add(bounds,Marker2D.new(),node,entry[0])
		marker.position.x = entry[1]
	var floor_node: Area2D = convert.add(node,Area2D.new(),node,"Floor")
	floor_node.position.y = 360.15
	floor_node.monitoring = false
	var shape: CollisionShape2D = convert.add(floor_node,CollisionShape2D.new(),node,"Collision")
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(761.05,39.0)
	shape.shape = rectangle
	shape.position = Vector2(305.875,19.0)
	var player: Marker2D = convert.add(node,Marker2D.new(),node,"PlayerSpawn")
	player.position = Vector2(92.9,315.9)
	player.scale = Vector2(.6369171,.65245056)
	player.z_index = 1014
	convert.add(player,load("res://scenes/actors/combatant.tscn").instantiate(),node,"Actor")
	var spawns: Node2D = convert.add(node,Node2D.new(),node,"EnemySpawns")
	var spawn: Marker2D = convert.add(spawns,Marker2D.new(),node,"Enemy0")
	spawn.position = Vector2(471.3,364.55)
	spawn.z_index = 294
	var actor: Node2D = convert.add(spawn,enemy.actor_scene.instantiate(),node,"Actor")
	var preview: Resource = enemy.actions[0]
	for action: Resource in enemy.actions:
		if action.identifier == "idle":preview = action
	actor.get_node("AuthorOffset/Visual").source_animation = preview.animation
	actor.get_node("AuthorOffset/ActionPreview").action = preview
	node.set_editable_instance(actor,true)
	var hud: Node2D = convert.add(node,load("res://scenes/ui/source_hud.tscn").instantiate(),node,"HUD")
	node.set_editable_instance(hud,true)
	hud.z_index = 595
	for crt: String in ["CRT0","CRT1"]:
		hud.get_node("Characters/"+crt+"/HPLayout").z_index = 1009-hud.z_index
		hud.get_node("Characters/"+crt+"/MPLayout").z_index = 1007-hud.z_index
		# Root9 Flash depths4691/4697 exceed a Godot CanvasItem's z range.
		# Preserve their order above world/HUD content; keep source depths as provenance.
		for entry: Array in [["HPHoverLayout",4000,4691],["MPHoverLayout",4001,4697]]:
			var hover: Node2D = hud.get_node("Characters/"+crt+"/"+str(entry[0]))
			hover.z_as_relative = false
			hover.z_index = int(entry[1])
			hover.set_meta("source_depth",int(entry[2]))
	for kind: String in ["F","G","H"]:
		hud.get_node("Characters/CRT0/Grenade"+kind+"Layout").z_index = 2832
	hud.get_node("Characters/CRT1/WAmmoLayout").z_index = 2832
	return convert.pack_new(node,"res://scenes/stages/root_9.tscn")
