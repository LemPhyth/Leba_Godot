@tool
extends Resource
## Generated atlas metadata. Author actions reference this resource; import owns this file.
@export var identifier := ""
@export var texture: Texture2D
@export var parent_scale := Vector2.ONE
@export var frames: Array[Dictionary] = []
## Original child placement/filter may be baked into derived pixels. Runtime
## removes this matrix/alpha once before applying the editable author values.
@export var baked_placement_matrix := PackedFloat64Array([1,0,0,1,0,0])
@export var baked_alpha_mult := 256.0
@export_multiline var source := ""

func to_runtime() -> Dictionary:
	return {"texture":texture.resource_path if texture != null else "","texture_resource":texture,"parent_scale":[parent_scale.x,parent_scale.y],"frames":frames.duplicate(true),"baked_placement_matrix":Array(baked_placement_matrix),"baked_alpha_mult":baked_alpha_mult}
