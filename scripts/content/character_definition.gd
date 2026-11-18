@tool
extends Resource
@export var identifier := "crt_0"
@export var title := "角色编号0"
@export var enabled := true
@export var source_crt := 0
@export var max_hp := 100.0
@export var max_mp := 100.0
@export var move_per_tick := 6.0
@export var actor_scene: PackedScene
@export var actions: Array[Resource] = []
## Persistent/independent components can outlive the action that starts them.
@export var components: Array[Resource] = []
@export var extra: Dictionary = {}
@export_multiline var source := ""

func apply_to(base: Dictionary, assets: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	row.merge(extra.duplicate(true),true)
	row.merge({"title":title,"enabled":enabled,"source_crt":source_crt,"max_hp":max_hp,"max_mp":max_mp,"move_per_tick":move_per_tick,"actor_scene":actor_scene},true)
	if not row.has("actions"):row["actions"] = {}
	row["components"] = {}
	for component: Resource in components:
		row.components[component.identifier] = component.parameters.duplicate(true)
		for animation: Resource in component.animations:assets.animations[animation.identifier] = animation.to_runtime()
	row["author_input_actions"] = {}
	for action: Resource in actions:
		row.actions[action.identifier] = action.to_runtime()
		row.actions[action.identifier]["source_author"] = true
		var inputs: Array = row.actions[action.identifier].get("input_aliases",[]).duplicate()
		if not action.input_id.is_empty() and action.input_id not in inputs:inputs.append(action.input_id)
		for input: String in inputs:
			if not row.author_input_actions.has(input):row.author_input_actions[input] = []
			if action.identifier not in row.author_input_actions[input]:row.author_input_actions[input].append(action.identifier)
		if action.animation != null:assets.animations[action.animation_key] = action.animation.to_runtime()
		if action.component_definition != null:
			for animation: Resource in action.component_definition.animations:assets.animations[animation.identifier] = animation.to_runtime()
	return row
