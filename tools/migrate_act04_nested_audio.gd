extends SceneTree
## Source-reviewed, additive nested-clock repair; never runs on normal import.
const DATA := "res://data/act04_crt1_nested_audio.json"
var changed: Array = []
var out := "res://artifacts/leba_act04_20261117/nested_migration"

func _initialize() -> void:call_deferred("_run")

func _save(value: Resource, directory: String) -> void:
	var path: String = value.resource_path
	var backup := directory+"/"+path.trim_prefix("res://").replace("/","_")
	assert(DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(backup)) == OK)
	assert(ResourceSaver.save(value,path) == OK)
	changed.append(path)

func _run() -> void:
	if "--migrate-nested-audio" not in OS.get_cmdline_user_args():quit(2);return
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_catalog.json"))
	for key: String in source.aliases.values():assert(catalog.audio.sfx.has(key),"嵌套声音尚未发布："+key)
	var directory := out+"/run_%d_%d"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	for id: String in source.action_extra_nested_audio:
		var action: Resource = load("res://content/actions/crt1/"+id+".tres")
		var list: Array = action.extra.get("nested_audio",[]).duplicate(true)
		var added := false
		for row: Dictionary in source.action_extra_nested_audio[id]:
			if list.any(func(item: Dictionary)->bool:return str(item.identifier) == str(row.identifier)):continue
			list.append(row.duplicate(true));added = true
		if added:action.extra["nested_audio"] = list;_save(action,directory)
	var hawks: Resource = load("res://content/components/crt1/gunhawks.tres")
	var aliases: Dictionary = hawks.parameters.get("child_audio",{}).duplicate()
	var added := false
	for key: String in source.gunhawks_child_audio:
		if not aliases.has(key):aliases[key] = source.gunhawks_child_audio[key];added = true
	if added:hawks.parameters["child_audio"] = aliases;_save(hawks,directory)
	var awakening: Resource = load("res://content/components/crt1/awakening.tres")
	if not awakening.parameters.has("air_container_audio"):
		awakening.parameters["air_container_audio"] = source.awakening_air_container_audio.duplicate(true)
		_save(awakening,directory)
	var report := FileAccess.open(directory+"/report.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"changed":changed,"source":DATA,"policy":"missing source-instance IDs only; existing author clock/sound values preserved"},"\t"));report.close()
	print("ACT04_NESTED_AUDIO changed=",changed.size()," report=",directory+"/report.json")
	quit()
