extends SceneTree
## Explicit, idempotent repair of the confirmed ACT03 sound-filter omission.
const Migration = preload("res://tools/content_audio_migration.gd")
var out := "res://artifacts/leba_act04_20261117/audio_migration"

func _initialize() -> void:call_deferred("_run")

func _run() -> void:
	if "--migrate-crt1-audio" not in OS.get_cmdline_user_args():
		push_error("需要显式 -- --migrate-crt1-audio；普通导入不修改作者数据")
		quit(2);return
	var assets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_catalog.json"))
	var character: Resource = load("res://content/characters/crt_1.tres")
	var rows: Array = []
	var added := 0
	var directory := out+"/run_%d_%d"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	for action: Resource in character.actions:
		var before: Dictionary = action.to_runtime()
		before.erase("events")
		var existing: Array = action.events.duplicate()
		var path: String = action.resource_path
		var row: Dictionary = Migration.new().apply_action(action,assets)
		var after: Dictionary = action.to_runtime()
		after.erase("events")
		assert(before == after,"音效迁移意外改动动作参数："+path)
		for event: Resource in existing:assert(event in action.events,"音效迁移移除了已有事件："+path)
		if not row.added.is_empty():
			var backup := directory+"/"+path.get_file()
			assert(DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(backup)) == OK)
			row["before_sha256"] = FileAccess.get_sha256(path)
			assert(ResourceSaver.save(action,path) == OK,"音效迁移保存失败："+path)
			row["after_sha256"] = FileAccess.get_sha256(path)
			added += row.added.size()
		rows.append(row)
	var report := FileAccess.open(directory+"/report.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"added":added,"actions":rows,"policy":"source StartSound only; existing author sounds at the same frame retained as explicit overrides; all costs/windows/custom events preserved"},"\t"))
	report.close()
	print("ACT04_AUDIO_MIGRATION added=%d report=%s/report.json"%[added,directory])
	quit()
