@tool
extends Resource
## Persistent sub-timeline parameters. Authored here once; import metadata cannot reset them.
@export var identifier := ""
@export var parameters: Dictionary = {}
@export var animations: Array[Resource] = []
@export_multiline var source := ""
