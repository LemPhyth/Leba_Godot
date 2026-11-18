extends RefCounted
## One versioned Godot profile, independent from the original Flash SharedObject.
## The caller owns the live state. Loading never overwrites an existing file.

const SCHEMA_VERSION: int = 1
const MAX_FILE_BYTES: int = 1024 * 1024

var path: String
var last_message: String = ""
var last_backup_path: String = ""


func _init(save_path: String = "user://profile.json") -> void:
	path = save_path


func default_profile() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"settings": {"volume": 0.8,"auto_save":false,"auto_quality":false},
		"selection": {"character_id": "crt_0", "mode_id": "story"},
		"progress": {"clears": {}, "gold": 0},
		"unlocks": [],
		"equipment": {},
	}


func load_profile() -> Dictionary:
	last_message = ""
	last_backup_path = ""
	if not _path_is_safe():
		return _load_failure("invalid_path", "存档路径必须位于本游戏的 user:// 目录内。")
	if not FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			var backup: Dictionary = _read_profile(path + ".bak")
			if backup["ok"]:
				last_backup_path = path + ".bak"
				return _loaded(backup["profile"], "recovered", "主存档缺失，已从上次备份读取；备份仍保留。")
			return _load_failure("invalid", "主存档缺失，备份也无法读取：" + str(backup["message"]))
		return _loaded(default_profile(), "new", "尚无存档，使用初始进度。")
	var current: Dictionary = _read_profile(path)
	if current["ok"]:
		return _loaded(current["profile"], "loaded", "已读取存档。")
	# A newer schema may contain data this build cannot understand. Do not roll
	# it back to an older backup and later overwrite it with this version.
	if current["status"] == "unsupported":
		return _load_failure("unsupported", str(current["message"]))
	if FileAccess.file_exists(path + ".bak"):
		var backup: Dictionary = _read_profile(path + ".bak")
		if backup["ok"]:
			last_backup_path = path + ".bak"
			return _loaded(backup["profile"], "recovered", "当前存档无法读取，已读取上次备份；原文件仍保留。")
	return _load_failure(str(current["status"]), "存档无法读取，使用初始进度；原文件仍保留。 " + str(current["message"]))


func save_profile(profile: Dictionary) -> Error:
	last_message = ""
	last_backup_path = ""
	if not _path_is_safe():
		return _save_failure(ERR_INVALID_PARAMETER, "拒绝写入 user:// 目录以外的存档路径。")
	var problem: String = _validate_profile(profile)
	if not problem.is_empty():
		return _save_failure(ERR_INVALID_DATA, problem)
	var text: String = JSON.stringify(profile, "\t") + "\n"
	if text.to_utf8_buffer().size() > MAX_FILE_BYTES:
		return _save_failure(ERR_OUT_OF_MEMORY, "存档超过本版本的 1 MiB 上限。")
	var absolute: String = ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(absolute):
		return _save_failure(ERR_CANT_CREATE, "存档目标是目录，未写入：" + path)
	var error: Error = DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if error != OK:
		return _save_failure(error, "无法创建存档目录：" + path.get_base_dir())
	var old_state: Dictionary = {}
	if FileAccess.file_exists(path):
		old_state = _read_profile(path)
		if old_state["status"] == "unsupported":
			return _save_failure(ERR_UNAVAILABLE, "保留不支持版本的现有存档，未覆盖：" + path)
		if old_state["status"] == "io_error":
			return _save_failure(ERR_FILE_CANT_READ, "现有存档无法读取，未覆盖：" + path)
	var suffix: String = "%d_%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]
	var temporary: String = path + ".tmp_" + suffix
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _save_failure(FileAccess.get_open_error(), "无法创建临时存档：" + temporary)
	file.store_string(text)
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK:
		return _save_failure(error, "写入临时存档失败；原档未修改：" + temporary)
	var written: Dictionary = _read_profile(temporary)
	if not written["ok"]:
		return _save_failure(ERR_FILE_CORRUPT, "临时存档回读失败；原档未修改：" + temporary)
	var restore_path: String = ""
	if not old_state.is_empty():
		if old_state["ok"]:
			restore_path = path + ".bak"
			# The current valid profile remains intact while the older backup is
			# rotated. A failed removal aborts before touching that current file.
			if FileAccess.file_exists(restore_path):
				error = DirAccess.remove_absolute(ProjectSettings.globalize_path(restore_path))
				if error != OK:
					return _save_failure(error, "无法轮换存档备份；当前存档未修改。")
		else:
			restore_path = path + ".invalid_" + suffix
		error = DirAccess.rename_absolute(absolute, ProjectSettings.globalize_path(restore_path))
		if error != OK:
			return _save_failure(error, "无法保留当前存档，取消替换：" + restore_path)
		last_backup_path = restore_path
	error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), absolute)
	if error != OK:
		if not restore_path.is_empty():
			var restore_error: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(restore_path), absolute)
			if restore_error != OK:
				return _save_failure(error, "新存档安装失败且自动恢复失败；旧数据保存在：" + restore_path)
		return _save_failure(error, "新存档安装失败；旧存档已恢复，临时文件保留：" + temporary)
	last_message = "已保存进度。"
	if not old_state.is_empty() and not old_state["ok"]:
		last_message = "已保存新进度；无法读取的旧存档保留于：" + restore_path
	return OK


func _path_is_safe() -> bool:
	if not path.begins_with("user://") or path.ends_with("/") or path.get_file().is_empty():
		return false
	var root: String = ProjectSettings.globalize_path("user://").simplify_path().trim_suffix("/")
	var destination: String = ProjectSettings.globalize_path(path).simplify_path()
	return destination.begins_with(root + "/")


func _read_profile(file_path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {"ok": false, "status": "io_error", "message": "无法打开 " + file_path}
	if file.get_length() > MAX_FILE_BYTES:
		file.close()
		return {"ok": false, "status": "invalid", "message": "存档文件超过 1 MiB。"}
	var text: String = file.get_as_text()
	var read_error: Error = file.get_error()
	file.close()
	if read_error != OK and read_error != ERR_FILE_EOF:
		return {"ok": false, "status": "io_error", "message": "读取存档失败：" + file_path}
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return {"ok": false, "status": "invalid", "message": "JSON 第 %d 行：%s" % [json.get_error_line(), json.get_error_message()]}
	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return {"ok": false, "status": "invalid", "message": "存档根节点必须是对象。"}
	if _integer(data.get("schema_version")) and int(data["schema_version"]) != SCHEMA_VERSION:
		return {"ok": false, "status": "unsupported", "message": "本版本不支持存档版本 %s，原文件未修改。" % str(data["schema_version"])}
	var problem: String = _validate_profile(data)
	if not problem.is_empty():
		return {"ok": false, "status": "invalid", "message": problem}
	var profile: Dictionary = data.duplicate(true)
	profile["schema_version"] = SCHEMA_VERSION
	profile["progress"]["gold"] = int(profile["progress"]["gold"])
	for key: String in profile["progress"]["clears"]:
		profile["progress"]["clears"][key] = int(profile["progress"]["clears"][key])
	# JSON numbers are floats. Restore only fields already validated as integers;
	# unknown profile fields retain their original JSON meaning.
	if profile.progress.has("clear_cubes"):profile.progress.clear_cubes = int(profile.progress.clear_cubes)
	if profile.get("inventory",{}).has("haring"):profile.inventory.haring = int(profile.inventory.haring)
	if profile.equipment.get("rings",{}) is Dictionary:
		for id: String in profile.equipment.get("rings",{}):profile.equipment.rings[id] = int(profile.equipment.rings[id])
	return {"ok": true, "status": "loaded", "profile": profile, "message": ""}


func _validate_profile(profile: Dictionary) -> String:
	if not _json_value(profile, 0):
		return "存档包含不支持或过深的数据类型。"
	if not _integer(profile.get("schema_version")) or int(profile["schema_version"]) != SCHEMA_VERSION:
		return "schema_version 必须为 1。"
	for key: String in ["settings", "selection", "progress", "equipment"]:
		if typeof(profile.get(key)) != TYPE_DICTIONARY:
			return "%s 必须是对象。" % key
	var volume: Variant = profile["settings"].get("volume")
	if not _number(volume) or float(volume) < 0.0 or float(volume) > 1.0:
		return "settings.volume 必须在 0 到 1 之间。"
	for key: String in ["auto_save","auto_quality"]:
		if profile.settings.has(key) and not profile.settings[key] is bool:return "settings.%s 必须是布尔值。" % key
	for key: String in ["character_id", "mode_id"]:
		if not _identifier(profile["selection"].get(key)):
			return "selection.%s 必须是非空标识。" % key
	if profile.selection.has("difficulty_id") and not _identifier(profile.selection.difficulty_id):
		return "selection.difficulty_id 必须是非空标识。"
	if profile.has("inventory"):
		if not profile.inventory is Dictionary:
			return "inventory 必须是对象。"
		if profile.inventory.has("haring") and (not _integer(profile.inventory.haring) or int(profile.inventory.haring) not in [0,1]):
			return "inventory.haring 必须为 0 或 1。"
	if profile.equipment.has("rings"):
		if not profile.equipment.rings is Dictionary:
			return "equipment.rings 必须是对象。"
		for actor_id: Variant in profile.equipment.rings:
			if not _identifier(actor_id) or not _integer(profile.equipment.rings[actor_id]) or float(profile.equipment.rings[actor_id]) < 0:
				return "戒指装备槽必须是非负整数。"
	var clears: Variant = profile["progress"].get("clears")
	var gold: Variant = profile["progress"].get("gold")
	if profile.progress.has("clear_cubes") and (not _integer(profile.progress.clear_cubes) or float(profile.progress.clear_cubes) < 0):
		return "progress.clear_cubes 必须是非负整数。"
	if not _integer(gold) or float(gold) < 0:
		return "progress.gold 必须是非负整数。"
	if typeof(clears) != TYPE_DICTIONARY:
		return "progress.clears 必须是对象。"
	for key: Variant in clears:
		if not _identifier(key) or not _integer(clears[key]) or float(clears[key]) < 0:
			return "关卡完成次数必须以非空关卡标识为键，值为非负整数。"
	if typeof(profile.get("unlocks")) != TYPE_ARRAY:
		return "unlocks 必须是数组。"
	for value: Variant in profile["unlocks"]:
		if not _identifier(value):
			return "unlocks 条目必须是非空标识。"
	return ""


func _json_value(value: Variant, depth: int) -> bool:
	if depth > 16:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return true
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_ARRAY:
			if value.size() > 10000:
				return false
			for item: Variant in value:
				if not _json_value(item, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			if value.size() > 10000:
				return false
			for key: Variant in value:
				if typeof(key) != TYPE_STRING or not _json_value(value[key], depth + 1):
					return false
			return true
	return false


func _identifier(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not value.strip_edges().is_empty() and value.length() <= 128


func _number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))


func _integer(value: Variant) -> bool:
	return _number(value) and float(value) == floor(float(value)) and abs(float(value)) <= 9007199254740991.0


func _loaded(profile: Dictionary, status: String, message: String) -> Dictionary:
	last_message = message
	return {"ok": true, "profile": profile, "status": status, "message": message}


func _load_failure(status: String, message: String) -> Dictionary:
	last_message = message
	return {"ok": false, "profile": default_profile(), "status": status, "message": message}


func _save_failure(error: Error, message: String) -> Error:
	last_message = message
	return error
