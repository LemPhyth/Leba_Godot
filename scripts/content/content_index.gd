@tool
extends Resource
## Add a character/action or stage here; no second registration constant in ContentDB.
@export var characters: Array[Resource] = []
@export var stage_scenes: Array[PackedScene] = []
@export var enemy_definitions: Array[Resource] = []
@export var actor_scene: PackedScene
@export var enemy_scene: PackedScene
@export var flow: Resource
