extends SceneTree
## Explicit initial migration only. Never overwrites author resources or scenes.
const Convert = preload("res://tools/content_conversion.gd")
const Index = preload("res://scripts/content/content_index.gd")
var convert := Convert.new()
var db: RefCounted

func _initialize() -> void:call_deferred("_run")

func _run() -> void:
	if "--bootstrap-editor" not in OS.get_cmdline_user_args():
		push_error("仅首次转换使用：-- --bootstrap-editor；已有内容始终拒绝覆盖")
		quit(1)
		return
	if FileAccess.file_exists("res://content/index.tres"):
		print("作者索引已存在，保留全部内容；复制场景/资源或手动编辑索引。")
		quit()
		return
	db = load("res://scripts/core/content_db.gd").new()
	assert(db.load_all(),str(db.issues))
	var crt0 := Convert.Character.new()
	crt0.identifier = "crt_0"
	crt0.title = "角色编号0"
	for id: String in ["idle","basic","skill_s"]:
		crt0.actions.append(convert.action(id,db.characters.crt_0.actions[id],db.assets,"res://content/actions/crt0/"+id+".tres"))
	var crt1_idle: Resource = convert.action("idle",db.characters.crt_1.actions.idle,db.assets,"res://content/actions/crt1/idle.tres")
	var enemy_idle: Resource = convert.action("idle",db.enemies.goblin_4030.actions.idle,db.assets,"res://content/enemies/goblin_4030_actions/idle.tres")
	var actor := _actor(crt0.actions[0],"res://scenes/actors/combatant.tscn")
	_actor(crt1_idle,"res://scenes/actors/crt1.tscn")
	var enemy := _actor(enemy_idle,"res://scenes/actors/enemy.tscn")
	crt0.actor_scene = actor
	var index := Index.new()
	index.characters.append(convert.save_new(crt0,"res://content/characters/crt_0.tres"))
	index.actor_scene = actor
	index.enemy_scene = enemy
	for id: String in ["root_2","root_4","root_6","root_41"]:
		var packed := _stage(id,actor,enemy)
		assert(packed != null,"阶段转换失败，不保存索引："+id)
		index.stage_scenes.append(packed)
	convert.save_new(index,"res://content/index.tres")
	print("ACT03_EDITOR_BOOTSTRAP initial author scenes/resources created; future imports do not own these files")
	quit()

func _actor(preview: Resource, path: String) -> PackedScene:
	var node := Node2D.new()
	node.name = "Actor"
	node.set_script(load("res://scripts/combat/combatant.gd"))
	var offset: Node2D = convert.add(node,Node2D.new(),node,"AuthorOffset")
	var visual: Node2D = convert.add(offset,Node2D.new(),node,"Visual")
	visual.set_script(load("res://scripts/combat/source_sprite.gd"))
	visual.source_animation = preview.animation
	var tool: Node2D = convert.add(offset,Node2D.new(),node,"ActionPreview")
	tool.set_script(load("res://scripts/content/action_preview.gd"))
	tool.action = preview
	return convert.pack_new(node,path)

func _sprite(parent: Node, owner_node: Node, key: String, label: String) -> Sprite2D:
	var data: Dictionary = db.assets.textures[key]
	var sprite: Sprite2D = convert.add(parent,Sprite2D.new(),owner_node,label)
	sprite.texture = load(str(data.path))
	sprite.centered = false
	sprite.position = Vector2(data.stage_position[0]-data.pivot[0],data.stage_position[1]-data.pivot[1])
	return sprite

func _stage(id: String, actor: PackedScene, enemy: PackedScene) -> PackedScene:
	var data: Dictionary = db.stages[id]
	var rules := Convert.Stage.new()
	rules.identifier = id
	for key: String in ["title","source_root_frame","training","enemy_type","enemy_hp","player_max_hp","player_max_mp","next_stage","music","reward","difficulty_observer"]:
		if data.has(key):rules.set(key,data[key])
	rules.player_hurt_observers = PackedFloat32Array(data.player_hurt_observers)
	rules.extra = data.duplicate(true)
	for prop: Dictionary in rules.get_property_list():
		if int(prop.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE:rules.extra.erase(str(prop.name))
	for key: String in ["player_position","player_scale","enemy_positions","enemy_scale","enemy_count","enemy_depths","player_depth","floor_y","ground_rect","ground_texture","background"]:rules.extra.erase(key)
	var node := Node2D.new()
	node.name = id
	node.set_script(load("res://scripts/content/stage_layout.gd"))
	node.rules = convert.save_new(rules,"res://content/stages/"+id+".tres")
	_sprite(node,node,str(data.get("background","forest")),"Map")
	var ground := _sprite(node,node,"training_ground","SourceGround")
	ground.z_index = int(data.source_depths.ground)
	var bounds: Node = convert.add(node,Node2D.new(),node,"Bounds")
	for entry: Array in [["Left",0.0],["Right",550.0]]:
		var marker: Marker2D = convert.add(bounds,Marker2D.new(),node,entry[0])
		marker.position.x = entry[1]
	var floor_node: Area2D = convert.add(node,Area2D.new(),node,"Floor")
	floor_node.position.y = float(data.floor_y)
	floor_node.monitoring = false
	var shape: CollisionShape2D = convert.add(floor_node,CollisionShape2D.new(),node,"Collision")
	var rect: Array = data.ground_rect
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(rect[2],rect[3])
	shape.shape = rectangle
	shape.position = Vector2(rect[0]+rect[2]/2.0,rect[1]+rect[3]/2.0-float(data.floor_y))
	var player: Marker2D = convert.add(node,Marker2D.new(),node,"PlayerSpawn")
	player.position = Vector2(data.player_position[0],data.player_position[1])
	player.scale = Vector2(data.player_scale[0],data.player_scale[1])
	player.z_index = int(data.player_depth)
	convert.add(player,actor.instantiate(),node,"Actor")
	var enemies_node: Node2D = convert.add(node,Node2D.new(),node,"EnemySpawns")
	for i in range(data.enemy_positions.size()):
		var spawn: Marker2D = convert.add(enemies_node,Marker2D.new(),node,"Enemy%d" % i)
		spawn.position = Vector2(data.enemy_positions[i][0],data.enemy_positions[i][1])
		spawn.scale = Vector2(data.enemy_scale[0],data.enemy_scale[1])
		spawn.z_index = int(data.enemy_depths[i])
		convert.add(spawn,enemy.instantiate(),node,"Actor")
	var hud: Node2D = load("res://scenes/ui/source_hud.tscn").instantiate()
	convert.add(node,hud,node,"HUD")
	hud.z_index = int(data.source_depths.skills)
	for crt: String in ["CRT0","CRT1"]:
		hud.get_node("Characters/"+crt+"/HPLayout").z_index = int(data.source_depths.hp)-hud.z_index
		hud.get_node("Characters/"+crt+"/MPLayout").z_index = int(data.source_depths.mp)-hud.z_index
	return convert.pack_new(node,"res://scenes/stages/"+id+".tscn")
