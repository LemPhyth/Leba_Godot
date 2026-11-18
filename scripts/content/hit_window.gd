@tool
extends Resource
## Local source-pixel boxes. Preview and Battle consume the same rectangles.
@export_range(1,2000,1) var from_frame := 1
@export_range(1,2000,1) var until_frame := 1
@export var kind := "authored_hit"
@export var rectangles: Array[Rect2] = []
@export var damage := 0.0
@export var gravity := -5.0
@export var knockback := 0.0
@export var once_per_action := true
@export var parameters: Dictionary = {}
@export_multiline var source := ""

func to_runtime() -> Dictionary:
	var row := parameters.duplicate(true)
	row.merge({"from":from_frame,"until":until_frame,"kind":kind,"damage":damage,"gravity":gravity,"knockback":knockback,"once_per_action":once_per_action},true)
	if not rectangles.is_empty():row["local_rects"] = rectangles.duplicate()
	return row
