extends SceneTree
## First-copy only: two selected independent visual IDs, never author Resources.
func _initialize() -> void:
	if "--bootstrap-act06-nested-animations" not in OS.get_cmdline_user_args():
		push_error("Explicit selected animation bootstrap flag required");quit(2);return
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_catalog.json"))
	var convert=preload("res://tools/content_conversion.gd").new()
	for key: String in ["crt4_clone_status","crt4_ghostwalk_loop"]:
		if not catalog.animations.has(key):push_error("Selected original atlas missing: "+key);quit(1);return
		convert.animation(key,catalog)
	print("ACT06_NESTED_ANIMATIONS two selected IDs available; existing authors untouched")
	quit(0)
