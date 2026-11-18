extends SceneTree
const Convert = preload("res://tools/content_conversion.gd")
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	if "--migrate-q-icon" not in OS.get_cmdline_user_args():quit(2);return
	var assets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_catalog.json"))
	var component: Resource = load("res://content/components/crt1/buff.tres")
	var before: Dictionary = component.parameters.duplicate(true)
	var changed := false
	for part: Dictionary in assets.source_geometry.act03_crt1_components.buff.parts:
		if int(part.source_id) != 4591:continue
		if not component.parameters.parts.any(func(row: Dictionary)->bool:return int(row.source_id) == 4591):
			component.parameters.parts.append(part.duplicate(true));changed = true
		if not component.animations.any(func(animation: Resource)->bool:return animation.identifier == part.animation):
			component.animations.append(Convert.new().animation(str(part.animation),assets));changed = true
	if changed:
		for index in range(before.parts.size()):assert(before.parts[index] == component.parameters.parts[index])
		var backup := "res://artifacts/leba_act04_20261117/q_buff_before_icon.tres"
		if not FileAccess.file_exists(backup):assert(DirAccess.copy_absolute(ProjectSettings.globalize_path(component.resource_path),ProjectSettings.globalize_path(backup)) == OK)
		assert(ResourceSaver.save(component,component.resource_path) == OK)
	print("ACT04_Q_ICON changed=",changed," parts=",component.parameters.parts.size())
	quit()
