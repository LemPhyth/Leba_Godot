@tool
extends Resource
## Author-visible flow text/routes; runtime run/profile state is never stored here.
@export var dialogues: Dictionary = {}
@export var intermissions: Dictionary = {}
@export var routes: Dictionary = {}
@export_multiline var source := ""
