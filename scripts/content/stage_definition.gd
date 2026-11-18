@tool
extends Resource
@export var identifier := "root_41"
@export var title := "练习模式"
@export var source_root_frame := 41
@export var training := false
@export var enemy_type := "goblin_4030"
@export var enemy_hp := 200.0
@export var shot_damage := 20.0
@export var player_max_hp := 130.0
@export var player_max_mp := 130.0
@export var next_stage := ""
@export var music := "battle"
## Only used when neither the stage nor the enemy has a difficulty reward table.
@export var reward := 100
@export var player_hurt_observers := PackedFloat32Array([2.0])
@export var difficulty_observer := true
@export var extra: Dictionary = {}
@export_multiline var source := ""

func to_runtime() -> Dictionary:
	var row := extra.duplicate(true)
	row.merge({"title":title,"source_root_frame":source_root_frame,"training":training,"enemy_type":enemy_type,"enemy_hp":enemy_hp,"player_max_hp":player_max_hp,"player_max_mp":player_max_mp,"next_stage":next_stage,"music":music,"reward":reward,"player_hurt_observers":Array(player_hurt_observers),"difficulty_observer":difficulty_observer,"authored_layout":true},true)
	row["shot_damage"] = shot_damage
	return row
