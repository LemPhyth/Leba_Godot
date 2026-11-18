@tool
extends Resource
## A source-clock event. Mutable actor state never belongs to this definition.
@export_range(1,2000,1) var frame := 1
@export var kind := "sound"
@export var sound := ""
@export var audio_stream: AudioStream
@export_range(0,60,0.01) var audio_offset := 0.0
@export var projectile := "projectile"
@export var offset := Vector2.ZERO
@export var gravity := -5.0
@export var damage := 5.0
@export var parameters: Dictionary = {}
@export_multiline var source := ""

func to_runtime() -> Dictionary:
	var row := parameters.duplicate(true)
	row.merge({"frame":frame,"kind":kind},true)
	if kind == "sound":
		row["sound"] = sound
		row["offset"] = audio_offset
		if audio_stream != null:row["audio_stream"] = audio_stream
	if kind in ["projectile","crt1_head_projectile"]:row.merge({"projectile":projectile,"gravity":gravity,"damage":damage,"spawn_offset":[offset.x,offset.y]},true)
	return row
