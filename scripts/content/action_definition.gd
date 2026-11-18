@tool
extends Resource
## Authored content is authoritative for exported fields; legacy extras are only unmigrated behavior.
@export var identifier := "idle"
@export var title := ""
@export var animation: Resource
@export var animation_key := ""
@export var component_definition: Resource
@export var source_parent := 1
@export var sequence := PackedInt32Array()
@export_group("Input and resources")
@export var input_id := ""
@export var allowed_states := PackedStringArray(["idle","move","basic"])
@export var cost := 0.0
@export var required_mp := 0.0
@export var hp_cost := 0.0
@export var required_hp := 0.0
@export var cubes := 0
@export var cooldown_ticks := 0
@export var cooldown_key := ""
@export_group("Clock and chaining")
@export var loop := false
@export var hold := false
@export var hold_at := PackedInt32Array()
@export var next_action := "idle"
@export var combo_next := ""
@export var combo_from := 1
@export var combo_until := 1
@export_group("Events and collision")
@export var events: Array[Resource] = []
@export var windows: Array[Resource] = []
@export var hurt_rect := Rect2(-15,-100,30,100)
@export var override_hurt_rect := false
@export var visual_offset := Vector2.ZERO
@export_group("Evidence and unmigrated details")
@export_multiline var source := ""
@export_multiline var calibration := ""
@export var extra: Dictionary = {}

func to_runtime() -> Dictionary:
	var row := extra.duplicate(true)
	row.merge({"animation":animation_key,"source_parent":source_parent,"sequence":Array(sequence),"input":input_id,"cost":cost,"required_mp":required_mp,"cubes":cubes,"cooldown_ticks":cooldown_ticks,"allowed_states":Array(allowed_states),"loop":loop,"hold":hold,"hold_at":Array(hold_at),"next_action":next_action,"events":[],"windows":[],"visual_offset":visual_offset},true)
	if not cooldown_key.is_empty():row["cooldown_key"] = cooldown_key
	row["hp_cost"] = hp_cost
	row["required_hp"] = required_hp
	if not combo_next.is_empty():row.merge({"combo_next":combo_next,"combo_from":combo_from,"combo_until":combo_until},true)
	if override_hurt_rect:row["hurt_rect_override"] = hurt_rect
	if component_definition != null:row["component_data"] = component_definition.parameters.duplicate(true)
	for event: Resource in events:row.events.append(event.to_runtime())
	for window: Resource in windows:row.windows.append(window.to_runtime())
	return row
