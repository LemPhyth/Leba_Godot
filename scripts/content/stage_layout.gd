extends Node2D
## The scene's actual saved transforms/collision are the runtime placement authority.
@export var rules: Resource
@export var preview_character := "crt_0"

func to_runtime() -> Dictionary:
	var row: Dictionary = rules.to_runtime()
	var spawn: Node2D = get_node("PlayerSpawn")
	row["player_position"] = [spawn.position.x,spawn.position.y]
	row["player_scale"] = [spawn.scale.x,spawn.scale.y]
	row["player_depth"] = spawn.z_index
	row["enemy_positions"] = []
	row["enemy_scales"] = []
	row["enemy_depths"] = []
	for enemy: Node2D in get_node("EnemySpawns").get_children():
		var spawn_transform: Transform2D = get_node("EnemySpawns").transform * enemy.transform
		row.enemy_positions.append([spawn_transform.origin.x,spawn_transform.origin.y])
		var size: Vector2 = spawn_transform.get_scale()
		row.enemy_scales.append([size.x,size.y])
		row.enemy_depths.append(enemy.z_index)
		row["enemy_scale"] = row.enemy_scales[0]
	row["enemy_count"] = row.enemy_positions.size()
	row["bounds"] = [get_node("Bounds/Left").position.x,get_node("Bounds/Right").position.x]
	row["floor_y"] = get_node("Floor").position.y
	var collision: CollisionShape2D = get_node("Floor/Collision")
	var rect := collision.transform * collision.shape.get_rect()
	row["ground_rect"] = [rect.position.x+get_node("Floor").position.x,rect.position.y+get_node("Floor").position.y,rect.size.x,rect.size.y]
	return row

func _ready() -> void:
	# F6 of an authored stage uses the same Main, profile and Battle. No preview runtime.
	if get_parent() == get_tree().root:call_deferred("_run_standalone")

func _run_standalone() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.start_stage_override = rules.identifier
	main.start_character_override = preview_character
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	queue_free()
