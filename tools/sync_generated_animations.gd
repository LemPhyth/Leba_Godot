extends SceneTree
## Explicit synchronization of existing generated animation metadata only.
## Does not import assets, create new animation IDs, or save author resources.
const GENERATED := "res://generated/animations"
const CATALOG := "res://data/asset_catalog.json"
const ANIMATION_SCRIPT := "res://scripts/content/source_animation.gd"
var generated_directory := GENERATED
var report_path := "res://artifacts/leba_act03_20261116/generated_sync/latest.json"
var failures: Array[String] = []
var changed: Array[String] = []
var originals: Dictionary = {}
var author_before: Dictionary = {}
var uids: Dictionary = {}
var existing: PackedStringArray = []
var pending: Array[Dictionary] = []
var written_hashes: Dictionary = {}
var selected_keys := PackedStringArray()

func _initialize() -> void:call_deferred("_run")

func _hash_tree(path: String, result: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:return
	for filename: String in dir.get_files():result[path.path_join(filename)] = FileAccess.get_sha256(path.path_join(filename))
	for child: String in dir.get_directories():_hash_tree(path.path_join(child),result)

func _uid_token(path: String) -> String:
	var pattern := RegEx.new()
	pattern.compile('uid="([^"]+)"')
	var found := pattern.search(FileAccess.get_file_as_string(path).get_slice("\n",0))
	return found.get_string(1) if found != null else ""

func _paths() -> PackedStringArray:
	var values := PackedStringArray()
	var dir := DirAccess.open(generated_directory)
	if dir == null:return values
	for filename: String in dir.get_files():
		if filename.ends_with(".tres"):values.append(generated_directory.path_join(filename))
	values.sort()
	return values

func _preflight() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	if not data is Dictionary or not data.get("animations") is Dictionary:
		failures.append("无效的动画catalog："+CATALOG)
		return
	existing = _paths()
	if existing.is_empty():
		failures.append("没有已存在的generated/animations/*.tres；本工具不负责首次生成。")
		return
	for key: String in selected_keys:
		if not existing.has(generated_directory.path_join(key+".tres")):
			failures.append("指定的动画不存在；不创建新ID："+key)
	for path: String in existing:
		var key := path.get_file().get_basename()
		if not selected_keys.is_empty() and not selected_keys.has(key):continue
		var row: Variant = data.animations.get(key)
		if not row is Dictionary or not row.get("frames") is Array or row.frames.is_empty():
			failures.append("catalog缺少有效动画："+key)
			continue
		if not ResourceLoader.exists(str(row.get("texture","")),"Texture2D"):
			failures.append("图集尚未导入："+str(row.get("texture","")))
			continue
		var texture: Texture2D = ResourceLoader.load(str(row.texture),"Texture2D")
		if texture == null:
			failures.append("图集无法实际读取："+str(row.texture))
			continue
		var frames_valid := true
		for frame: Variant in row.frames:
			if not frame is Dictionary or not frame.has("source_frame") or not frame.get("region") is Array or frame.region.size() != 4 or not frame.get("pivot") is Array or frame.pivot.size() != 2:
				frames_valid = false
				break
		if not frames_valid:
			failures.append("动画帧缺少有效source_frame/region/pivot："+key)
			continue
		var value: Resource = ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)
		if value == null or value.get_script() == null or value.get_script().resource_path != ANIMATION_SCRIPT:
			failures.append("拒绝修改非SourceAnimation资源："+path)
			continue
		var scale_data: Variant = row.get("parent_scale",[1.0,1.0])
		if not scale_data is Array or scale_data.size() != 2:
			failures.append("parent_scale必须有两个数："+key)
			continue
		var scale_value := Vector2(scale_data[0],scale_data[1])
		var baked := PackedFloat64Array(row.get("baked_placement_matrix",[1,0,0,1,0,0]))
		var alpha := float(row.get("baked_alpha_mult",256))
		var expected_source := "asset_catalog.animations."+key+"；派生图集；来源与pivot见catalog。"
		uids[path] = _uid_token(path)
		if not str(uids[path]).is_empty() and ResourceUID.text_to_id(str(uids[path])) == ResourceUID.INVALID_ID:
			failures.append("资源UID无效，拒绝同步："+path)
			continue
		var same: bool = value.identifier == key and value.texture != null and value.texture.resource_path == str(row.texture) and value.parent_scale == scale_value and value.frames == row.frames and value.source == expected_source and value.baked_placement_matrix == baked and value.baked_alpha_mult == alpha
		if same:continue
		originals[path] = FileAccess.get_file_as_bytes(path)
		value.identifier = key
		value.texture = texture
		value.parent_scale = scale_value
		value.frames.assign(row.frames)
		value.baked_placement_matrix = baked
		value.baked_alpha_mult = alpha
		value.source = expected_source
		pending.append({"path":path,"resource":value})

func _restore_generated() -> void:
	for path: String in changed:
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != written_hashes.get(path,""):
			failures.append("派生文件在写入后又有外部变化，保留该变化、不覆盖回滚："+path)
			continue
		var file := FileAccess.open(path,FileAccess.WRITE)
		if file == null:
			failures.append("回滚派生文件失败："+path)
			continue
		file.store_buffer(originals[path])
		file.close()

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var sync := "--sync-generated" in arguments
	var dry := "--check" in arguments
	if sync == dry:
		print("用法：Godot --headless --audio-driver Dummy --path godot --script res://tools/sync_generated_animations.gd -- --check | --sync-generated [--keys=existing_key,...] [--report=res://artifacts/.../report.json] [--fixture-generated=res://artifacts/.../generated/animations]")
		quit(2)
		return
	for argument: String in arguments:
		if argument.begins_with("--keys="):
			selected_keys = argument.trim_prefix("--keys=").split(",",false)
			if selected_keys.is_empty():failures.append("--keys必须指定已有动画ID。")
			for key: String in selected_keys:
				if key != key.get_file() or key.contains(".") or key.contains(":"):
					failures.append("动画ID必须为已有文件的basename："+key)
		if argument.begins_with("--fixture-generated="):
			var fixture := argument.trim_prefix("--fixture-generated=").simplify_path()
			if not fixture.begins_with("res://artifacts/") or not fixture.ends_with("/generated/animations"):
				failures.append("测试目录只允许res://artifacts/.../generated/animations。")
			else:generated_directory = fixture
		if argument.begins_with("--report="):
			var requested := argument.trim_prefix("--report=").simplify_path()
			if not requested.begins_with("res://artifacts/") or not requested.ends_with(".json"):
				failures.append("报告必须位于res://artifacts/下且为.json。")
			else:report_path = requested
	_hash_tree("res://content",author_before)
	_hash_tree("res://scenes",author_before)
	if failures.is_empty():_preflight()
	if failures.is_empty() and sync:
		for item: Dictionary in pending:
			# Paths come only from the preflight existing-file enumeration.
			changed.append(item.path)
			var save_error := ResourceSaver.save(item.resource,item.path)
			# Non-editor headless saves can omit the original root UID. Restore it
			# through the resource API before accepting the generated replacement.
			if save_error == OK and not str(uids[item.path]).is_empty() and _uid_token(item.path) != str(uids[item.path]):
				save_error = ResourceSaver.set_uid(item.path,ResourceUID.text_to_id(str(uids[item.path])))
			if FileAccess.file_exists(item.path):written_hashes[item.path] = FileAccess.get_sha256(item.path)
			if save_error != OK:
				failures.append("保存派生元数据失败："+str(item.path))
				break
			if _uid_token(item.path) != str(uids[item.path]):
				failures.append("UID发生变化，拒绝本轮同步："+str(item.path))
				break
	var after: Dictionary = {}
	_hash_tree("res://content",after)
	_hash_tree("res://scenes",after)
	var authors_unchanged := after == author_before
	if not authors_unchanged:failures.append("content/scenes在运行期间发生变化；请停止并行作者编辑后重试。工具不会回滚作者改动。")
	if existing != _paths():failures.append("generated文件清单在运行期间变化；本工具不添加或删除动画ID。")
	var rolled_back := false
	if not failures.is_empty() and not changed.is_empty():
		_restore_generated()
		rolled_back = true
	var out_of_date: Array = pending.map(func(item:Dictionary)->String:return item.path)
	var report := {"tool":"sync_generated_animations","mode":"check" if dry else "sync","catalog":CATALOG,"generated_directory":generated_directory,"selected_keys":selected_keys,"existing_count":existing.size(),"pending":out_of_date,"updated":changed if not rolled_back else [],"rolled_back":rolled_back,"uid_tokens_before":uids,"author_file_count":author_before.size(),"authors_unchanged":authors_unchanged,"failures":failures,"policy":"existing generated animations only; fixture directory restricted to artifacts/.../generated/animations; no new IDs, no asset import, no content/scenes saves; unchanged files skipped"}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_path.get_base_dir()))
	var file := FileAccess.open(report_path,FileAccess.WRITE)
	if file != null:file.store_string(JSON.stringify(report,"\t"));file.close()
	else:failures.append("报告无法保存："+report_path)
	for message: String in failures:push_error(message)
	print("GENERATED_SYNC mode=%s existing=%d pending=%d updated=%d author_unchanged=%s failures=%d report=%s"%["check" if dry else "sync",existing.size(),pending.size(),0 if rolled_back else changed.size(),authors_unchanged,failures.size(),report_path])
	quit(1 if not failures.is_empty() else (3 if dry and not pending.is_empty() else 0))
