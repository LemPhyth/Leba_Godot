@tool
extends Node2D
## Atlas slices preserve their Flash registration offset across every frame.
var definition: Dictionary = {}
var texture: Texture2D
var frame: Dictionary = {}
var source_frame := 1
@export var source_animation: Resource:
	set(value):
		source_animation = value
		if is_inside_tree() and source_animation != null:configure(source_animation.to_runtime())

func _ready() -> void:
	if source_animation != null:configure(source_animation.to_runtime())

func configure(value: Dictionary) -> void:
	definition = value
	texture = value.get("texture_resource") as Texture2D
	if texture == null:texture = load(str(value.texture)) as Texture2D
	set_source_frame(int(value.frames[0].source_frame))

func set_source_frame(value: int) -> void:
	source_frame = value
	for candidate: Dictionary in definition.get("frames", []):
		if int(candidate.source_frame) == value:
			frame = candidate
			queue_redraw()
			return
	push_error("图集缺少原始帧 %s：%s" % [value, definition.get("texture", "")])

func _draw() -> void:
	if texture == null or frame.is_empty():
		return
	var r: Array = frame.region
	var pivot: Array = frame.pivot
	var region := Rect2(float(r[0]),float(r[1]),float(r[2]),float(r[3]))
	var original_scale: Array = definition.get("parent_scale",[1,1])
	var draw_scale := Vector2(original_scale[0],original_scale[1])
	draw_texture_rect_region(texture,Rect2(-Vector2(pivot[0],pivot[1])*draw_scale,region.size*draw_scale),region)
