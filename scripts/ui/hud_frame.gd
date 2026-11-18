@tool
extends "res://scripts/combat/source_sprite.gd"
## Same runtime SourceSprite; a safe representative frame is visible in the editor.
## No processing, input, audio, file writes or separate animation clock.
@export var editor_frame := 2:
	set(value):
		editor_frame = value
		if Engine.is_editor_hint() and is_inside_tree() and not definition.is_empty():set_source_frame(editor_frame)

func _ready() -> void:
	super()
	if Engine.is_editor_hint() and not definition.is_empty():set_source_frame(editor_frame)
