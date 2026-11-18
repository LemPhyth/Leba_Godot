extends SceneTree
## Explicit additive migration; never invoked by startup or import.
## Run after selected atlases/import/generated resources are ready:
## --script res://tools/migrate_act06_crt4_nested.gd -- --migrate-crt4-nested [--dry-run]
## Existing fields are authoritative. Insertions preserve every preexisting byte.
const Component = preload("res://scripts/content/component_definition.gd")
const Character = preload("res://scripts/content/character_definition.gd")
const SourceAnimation = preload("res://scripts/content/source_animation.gd")
const RULES := "res://data/act06_crt4_rules.json"
const PLAN := "res://data/act06_crt4_import.json"
const CATALOG := "res://data/asset_catalog.json"
const ROOT := "res://content/components/crt4/"
const SOUND := "crt4_script_common_contact_sound5"
const NEW_ANIMATIONS := ["crt4_clone_status", "crt4_ghostwalk_loop"]
var problem := ""
var preserved: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if "--migrate-crt4-nested" not in args:
		_fail("Explicit --migrate-crt4-nested required; no author changed", 2)
		return
	var rules := _json(RULES)
	var plan := _json(PLAN)
	var assets := _json(CATALOG)
	if not problem.is_empty() or not _preflight(rules, plan, assets):
		_fail(problem)
		return
	var rows: Array[Dictionary] = []
	var child := _new_child(rules.components["5417"])
	rows.append(child)
	var walk := _existing(ROOT + "6360.tres", "6360", Component)
	_put(walk, [], "held_visual_loop", rules.components["6360"].held_visual_loop)
	rows.append(walk)
	var air := _existing(ROOT + "6528.tres", "6528", Component)
	var proxies := {"nested_proxy":rules.components["6528"].ordinary_air_x.nested_directional_proxy.duplicate(true),
		"root_observed_component":5417, "root_observed_parent_source":6530, "sound_alias":SOUND}
	_put(air, [], "directional_fx_proxies", proxies)
	rows.append(air)
	var visual := _existing(ROOT + "visuals.tres", "visuals", Component)
	_put(visual, ["geometry"], "named_common_slash", rules.named_common_slash)
	_put(visual, ["geometry", "components"], "5417", child.expected)
	_put(visual, ["geometry", "components", "6360"], "held_visual_loop", rules.components["6360"].held_visual_loop)
	_put(visual, ["geometry", "components", "6528"], "directional_fx_proxies", proxies)
	_add_air_window(visual, rules)
	# Whole existing tracks, including manually edited matrices, remain untouched.
	# 5417 carries its separate parent_placement_tracks if6530 already exists.
	var source_tracks: Dictionary = assets.source_geometry.act06_crt4_components.get("action_tracks", {})
	for sid: String in ["6356", "6360", "5417", "6530"]:
		var track: Array = []
		if sid == "6356":
			track = [{"source_frame":1, "placements":[rules.components["6360"].held_visual_loop.container_inner_placement.duplicate(true)]}]
		elif sid == "6360":
			track = rules.components["6360"].held_visual_loop.parent_tracks.duplicate(true)
		elif sid == "5417":
			track = rules.components["5417"].placement_tracks.duplicate(true)
		else:
			track = source_tracks.get(sid, rules.components["5417"].parent_placement_tracks).duplicate(true)
		_put(visual, ["geometry", "source_geometry", "action_tracks"], sid, track)
	for key: String in NEW_ANIMATIONS:
		_append_resource(visual, "animations", "res://generated/animations/" + key + ".tres", "nested_" + key)
	var sound_row: Dictionary = assets.audio_events[SOUND].duplicate(true)
	sound_row.merge({"kind":"sound", "sound":SOUND, "frame":1, "offset":0.0,
		"audio_stream":load(str(assets.audio.sfx[SOUND])), "source_branch":"crt==4 -> attachSound('도') -> Sound5"}, true)
	if visual.expected.get("sounds", {}).has(SOUND):
		preserved.append("visuals.sounds." + SOUND)
	else:
		var sound_ref := _external(visual, str(assets.audio.sfx[SOUND]), "AudioStream", "nested_sound5")
		var sound_text := _serialize_sound(sound_row, sound_ref)
		_put(visual, ["sounds"], SOUND, sound_row, sound_text)
	rows.append(visual)
	var character := _existing("res://content/characters/crt_4.tres", "crt_4", Character)
	_append_resource(character, "components", ROOT + "5417.tres", "nested_component5417")
	rows.append(character)
	if not problem.is_empty():
		_fail(problem)
		return
	var pending: Array[Dictionary] = []
	for row: Dictionary in rows:
		if row.output != row.before:
			var restored: String = row.output
			for i: int in range(row.insertions.size() - 1, -1, -1):
				var edit: Dictionary = row.insertions[i]
				if restored.substr(edit.at, edit.text.length()) != str(edit.text):
					_fail("Insertion audit mismatch: " + row.path)
					return
				restored = restored.erase(edit.at, edit.text.length())
			if not row.is_new and restored != str(row.before):
				_fail("Could not prove existing author byte preservation: " + row.path)
				return
			pending.append(row)
	var report := {"inputs":{}, "preserved_existing_fields":preserved, "pending":pending.size(),
		"policy":"Missing keys/items only; existing costs, events, windows, placement matrices, Resource references and UIDs remain byte-identical", "changes":[]}
	for path: String in [RULES, PLAN, CATALOG]:report.inputs[path] = FileAccess.get_sha256(path)
	for row: Dictionary in pending:report.changes.append({"path":row.path, "new":row.is_new, "before_sha256":row.before_sha, "insertions":row.insertions.size()})
	if "--dry-run" in args or pending.is_empty():
		report["changed"] = 0
		report["dry_run"] = "--dry-run" in args
		print("ACT06_CRT4_NESTED_MIGRATION ", JSON.stringify(report))
		quit(0)
		return
	var backup := "res://artifacts/leba_act06_20261117/migrations/crt4_nested_%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(backup)) != OK:
		_fail("Cannot create audit/backup directory; no authors changed")
		return
	# Complete every original backup and verify it before the first author write.
	for row: Dictionary in pending:
		if row.is_new:continue
		var destination := backup.path_join(str(row.id) + ".tres")
		if FileAccess.file_exists(destination) or DirAccess.copy_absolute(ProjectSettings.globalize_path(row.path), ProjectSettings.globalize_path(destination)) != OK or FileAccess.get_sha256(destination) != str(row.before_sha):
			_fail("Backup failed; no authors changed: " + destination)
			return
		row["backup"] = destination
	report["backup_directory"] = backup
	report["status"] = "prepared"
	if not _report(backup, report):
		_fail("Cannot persist pre-write audit; no authors changed")
		return
	for row: Dictionary in pending:
		if (row.is_new and FileAccess.file_exists(row.path)) or (not row.is_new and FileAccess.get_sha256(row.path) != str(row.before_sha)):
			_fail("Author changed after preflight; preserved concurrent change. Backups: " + backup)
			return
		var file := FileAccess.open(row.path, FileAccess.WRITE)
		if file == null:
			_fail("Write failed; verified backups: " + backup)
			return
		file.store_string(row.output)
		file.close()
		if FileAccess.get_file_as_string(row.path) != str(row.output) or not _verify_resource(row):
			_fail("Written resource verification failed: " + row.path + "; backups: " + backup + "; " + problem)
			return
		for change: Dictionary in report.changes:
			if change.path == row.path:change["after_sha256"] = FileAccess.get_sha256(row.path)
	report["changed"] = pending.size()
	report["status"] = "complete"
	if not _report(backup, report):
		_fail("Migration completed but final audit failed: " + backup)
		return
	print("ACT06_CRT4_NESTED_MIGRATION ", JSON.stringify(report))
	quit(0)

func _preflight(rules: Dictionary, plan: Dictionary, assets: Dictionary) -> bool:
	if str(rules.get("character_id", "")) != "crt_4" or str(plan.get("character_id", "")) != "crt_4":
		problem = "CRT4 rules/import identity guard failed"
		return false
	for sid: String in ["5417", "6360", "6528"]:
		if int(rules.get("components", {}).get(sid, {}).get("source_id", -1)) != int(sid):
			problem = "Missing original CRT4 component: " + sid
			return false
	if int(rules.get("named_common_slash", {}).get("sound", {}).get("sound_id", -1)) != 5:
		problem = "Original CRT4 common contact Sound5 proof missing"
		return false
	if not rules.components["6360"].has("held_visual_loop") or not rules.components["6528"].has("ordinary_air_x"):
		problem = "Finite W/air child contract missing"
		return false
	for key: String in ["crt4_clone_status", "crt4_ghostwalk_loop", "crt4_ghostwalk"]:
		var path := "res://generated/animations/" + key + ".tres"
		var source: Variant = assets.get("animations", {}).get(key)
		if not source is Dictionary or not ResourceLoader.exists(path):
			problem = "Import and sync selected animation first: " + key
			return false
		var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if resource == null or resource.get_script() != SourceAnimation or str(resource.get("identifier")) != key or not resource.get("texture") is Texture2D:
			problem = "Generated animation identity/Texture2D guard failed: " + key
			return false
		if str(resource.get("texture").resource_path) != str(source.texture):
			problem = "Generated texture differs from selected catalog: " + key
			return false
		var actual_frames: Array = []
		for frame: Dictionary in resource.get("frames"):actual_frames.append(int(frame.get("source_frame", -1)))
		var required_frames: Array = []
		for frame: Variant in plan.animations[key].frames:required_frames.append(int(frame))
		if actual_frames != required_frames:
			problem = "Generated selected-frame sequence differs from finite import plan: " + key
			return false
	var sound: String = str(assets.get("audio", {}).get("sfx", {}).get(SOUND, ""))
	if int(assets.get("audio_events", {}).get(SOUND, {}).get("sound_id", -1)) != 5 or not ResourceLoader.exists(sound) or not load(sound) is AudioStream:
		problem = "Imported canonical Sound5 AudioStream missing: " + SOUND
		return false
	if not assets.get("source_geometry", {}).get("act06_crt4_components") is Dictionary:
		problem = "Finite CRT4 source geometry missing"
		return false
	return true

func _json(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if value is Dictionary:return value
	problem = "Missing/invalid input JSON: " + path
	return {}

func _existing(path: String, id: String, script: Script) -> Dictionary:
	var row := {"path":path, "id":id, "script":script, "before":"", "output":"", "before_sha":"", "is_new":false, "insertions":[], "expected":{}, "resource_arrays":{}}
	if not problem.is_empty():return row
	var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if resource == null or resource.get_script() != script or str(resource.get("identifier")) != id:
		problem = "Author identity/script guard failed: " + path
		return row
	row.before = FileAccess.get_file_as_string(path)
	row.output = row.before
	row.before_sha = FileAccess.get_sha256(path)
	if script == Component:row.expected = resource.get("parameters").duplicate(true)
	for field: String in (["components"] if script == Character else ["animations"]):
		var paths: Array = []
		for item: Resource in resource.get(field):paths.append(item.resource_path)
		row.resource_arrays[field] = paths
	return row

func _new_child(source: Dictionary) -> Dictionary:
	var path := ROOT + "5417.tres"
	if FileAccess.file_exists(path):return _existing(path, "5417", Component)
	var params := source.duplicate(true)
	params.erase("sound_events")
	params["sounds"] = []
	var text := '[gd_resource type="Resource" format=3]\n\n[ext_resource type="Script" path="res://scripts/content/component_definition.gd" id="1_script"]\n\n[resource]\nscript = ExtResource("1_script")\nidentifier = "5417"\nparameters = ' + var_to_str(params) + '\nsource = "Original6530/4 direct left-diagonal keyDown proxy5417; finite authored clocks and original geometry from act06_crt4_rules.json."\n'
	return {"path":path, "id":"5417", "script":Component, "before":"", "output":text, "before_sha":"", "is_new":true, "insertions":[], "expected":params, "resource_arrays":{"animations":[]}}

func _insert(row: Dictionary, at: int, text: String) -> void:
	row.output = str(row.output).insert(at, text)
	row.insertions.append({"at":at, "text":text})

func _put(row: Dictionary, path: Array, key: String, value: Variant, encoded: String = "") -> void:
	if not problem.is_empty():return
	var expected: Dictionary = row.expected
	var marker := "parameters = {"
	if str(row.output).count(marker) != 1:
		problem = "Unrecognized parameters serialization: " + row.path
		return
	var opening := str(row.output).find(marker) + marker.length() - 1
	for part: String in path:
		if not expected.has(part):
			_insert(row, opening + 1, "\n" + var_to_str(part) + ": {},")
			expected[part] = {}
		if not expected[part] is Dictionary:
			problem = "Existing non-Dictionary author field preserved: " + part
			return
		opening = _key_value(row.output, opening, part)
		if opening < 0 or str(row.output).substr(opening, 1) != "{":
			problem = "Dictionary text differs from loaded author: " + part
			return
		expected = expected[part]
	if expected.has(key):
		preserved.append(str(row.id) + "." + ".".join(path) + "." + key)
		return
	if encoded.is_empty() and _has_resource(value):
		problem = "New Dictionary would need an unplanned Resource reference; preserved author: " + str(row.id) + "." + key
		return
	_insert(row, opening + 1, "\n" + var_to_str(key) + ": " + (var_to_str(value) if encoded.is_empty() else encoded) + ",")
	expected[key] = value

func _add_air_window(row: Dictionary, rules: Dictionary) -> void:
	if not problem.is_empty():return
	var windows: Variant = row.expected.get("geometry", {}).get("hit_windows")
	if not windows is Array:
		problem = "Existing authored geometry.hit_windows must be an Array"
		return
	for old: Dictionary in windows:
		if int(old.get("source_id", -1)) == 6528:
			preserved.append("visuals.geometry.hit_windows.source6528")
			return
	var found: Array = []
	for candidate: Dictionary in rules.hit_windows:
		if int(candidate.get("source_id", -1)) == 6528:found.append(candidate)
	if found.size() != 1 or int(found[0].source_depth) != 45 or int(found[0].from) != 4 or int(found[0].until) != 6 or bool(found[0].default_rule.reset_marker):
		problem = "Expected exactly one original6528d45 source4..6 no-reset window"
		return
	var opening := str(row.output).find("parameters = {") + "parameters = ".length()
	opening = _key_value(row.output, opening, "geometry")
	opening = _key_value(row.output, opening, "hit_windows")
	var closing := _closing(row.output, opening)
	if closing < 0:
		problem = "Cannot locate authored hit-window Array boundary"
		return
	_insert(row, closing, (",\n" if not windows.is_empty() else "\n") + var_to_str(found[0]))
	windows.append(found[0].duplicate(true))

func _external(row: Dictionary, path: String, type: String, id: String) -> String:
	if not problem.is_empty():return ""
	for line: String in str(row.output).split("\n"):
		if line.begins_with("[ext_resource ") and ('path="' + path + '"') in line:
			return line.get_slice(' id="', 1).get_slice('"', 0)
	if ('id="' + id + '"') in str(row.output):
		problem = "Requested external-resource ID already belongs to another resource: " + id
		return ""
	var at := str(row.output).find("[resource]")
	if at < 0:
		problem = "Resource header missing: " + row.path
		return ""
	_insert(row, at, '[ext_resource type="' + type + '" path="' + path + '" id="' + id + '"]\n\n')
	return id

func _append_resource(row: Dictionary, field: String, path: String, id: String) -> void:
	if not problem.is_empty():return
	var paths: Array = row.resource_arrays[field]
	if path in paths:
		preserved.append(str(row.id) + "." + field + ":" + path)
		return
	var external := _external(row, path, "Resource", id)
	var marker := field + " = Array[Resource](["
	if str(row.output).count(marker) != 1:
		problem = "Unsupported typed Resource Array serialization: " + field
		return
	var closing := str(row.output).find("])", str(row.output).find(marker) + marker.length())
	if closing < 0:
		problem = "Typed Resource Array terminator missing: " + field
		return
	_insert(row, closing, (", " if not paths.is_empty() else "") + 'ExtResource("' + external + '")')
	paths.append(path)

func _serialize_sound(value: Dictionary, resource_id: String) -> String:
	var data := value.duplicate(true)
	data.erase("audio_stream")
	var encoded := var_to_str(data)
	return encoded.insert(1, '\n"audio_stream": ExtResource("' + resource_id + '"),')

func _key_value(text: String, parent: int, wanted: String) -> int:
	if parent < 0:return -1
	var depth := 0
	var i := parent
	while i < text.length():
		var c := text.substr(i, 1)
		if c == ";":
			var end := text.find("\n", i)
			i = text.length() if end < 0 else end + 1
			continue
		if c == '"':
			var start := i
			i = _string_end(text, i)
			if i < 0:return -1
			if depth == 1 and text.substr(start + 1, i - start - 1) == wanted:
				var at := i + 1
				while at < text.length() and text.substr(at, 1) in [" ", "\t", "\r", "\n"]:at += 1
				if text.substr(at, 1) == ":":
					at += 1
					while at < text.length() and text.substr(at, 1) in [" ", "\t", "\r", "\n"]:at += 1
					return at
		elif c in ["{", "["]:depth += 1
		elif c in ["}", "]"]:
			depth -= 1
			if depth == 0:return -1
		i += 1
	return -1

func _closing(text: String, opening: int) -> int:
	if opening < 0 or text.substr(opening, 1) not in ["{", "["]:return -1
	var depth := 0
	var i := opening
	while i < text.length():
		var c := text.substr(i, 1)
		if c == ";":
			var end := text.find("\n", i)
			i = text.length() if end < 0 else end + 1
			continue
		if c == '"':
			i = _string_end(text, i)
			if i < 0:return -1
		elif c in ["{", "["]:depth += 1
		elif c in ["}", "]"]:
			depth -= 1
			if depth == 0:return i
		i += 1
	return -1

func _string_end(text: String, start: int) -> int:
	var i := start + 1
	while i < text.length():
		if text.substr(i, 1) == "\\":i += 2
		elif text.substr(i, 1) == '"':return i
		else:i += 1
	return -1

func _normalize(value: Variant) -> Variant:
	if value is Resource:return {"resource_path":value.resource_path}
	if value is Dictionary:
		var out := {}
		for key: Variant in value:out[key] = _normalize(value[key])
		return out
	if value is Array:
		var out: Array = []
		for item: Variant in value:out.append(_normalize(item))
		return out
	return value

func _has_resource(value: Variant) -> bool:
	if value is Resource:return true
	if value is Dictionary:
		for child: Variant in value.values():
			if _has_resource(child):return true
	elif value is Array:
		for child: Variant in value:
			if _has_resource(child):return true
	return false

func _verify_resource(row: Dictionary) -> bool:
	var resource: Resource = ResourceLoader.load(row.path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if resource == null or resource.get_script() != row.script or str(resource.get("identifier")) != str(row.id):return false
	if row.script == Component and _normalize(resource.get("parameters")) != _normalize(row.expected):return false
	for field: String in row.resource_arrays:
		var actual: Array = []
		for item: Resource in resource.get(field):actual.append(item.resource_path)
		if actual != row.resource_arrays[field]:return false
	return true

func _report(directory: String, report: Dictionary) -> bool:
	var file := FileAccess.open(directory.path_join("report.json"), FileAccess.WRITE)
	if file == null:return false
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	return true

func _fail(message: String, code: int = 1) -> void:
	push_error(message)
	quit(code)
