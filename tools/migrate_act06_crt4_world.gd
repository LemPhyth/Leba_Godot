extends SceneTree
## Explicit, additive first migration of finite CRT4 world semantics.
## Usage: Godot --headless --audio-driver Dummy --path godot --script
## res://tools/migrate_act06_crt4_world.gd -- --migrate-crt4-world [--dry-run]
## Never called by startup/import. Existing world_semantics keys are authoritative.
## Text insertion preserves all existing author bytes, Resource UIDs and references.
const Component = preload("res://scripts/content/component_definition.gd")
const DATA := "res://data/act06_crt4_world_semantics.json"
const ROOT := "res://content/components/crt4/"
const IDS := ["1326", "1154", "316", "978", "visuals"]
var problem := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if "--migrate-crt4-world" not in args:
		_fail("Explicit --migrate-crt4-world required; no author changed", 2)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if not parsed is Dictionary:
		_fail("Missing/invalid finite world semantics: " + DATA)
		return
	var world: Dictionary = parsed
	if not _valid_world(world):
		_fail(problem)
		return
	var pending: Array[Dictionary] = []
	var preserved: Array[String] = []
	for id: String in IDS:
		var path := ROOT + id + ".tres"
		if not FileAccess.file_exists(path):
			_fail("Required CRT4 author missing; no writes: " + path)
			return
		var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if resource == null or resource.get_script() != Component or str(resource.get("identifier")) != id:
			_fail("CRT4 component identity/script guard failed: " + path)
			return
		var parameters: Dictionary = resource.get("parameters")
		if id != "visuals" and int(parameters.get("source_id", -1)) != int(id):
			_fail("Original source ID guard failed: " + path)
			return
		var source := FileAccess.get_file_as_string(path)
		var patch := _plan_patch(id, source, parameters, world)
		if not problem.is_empty():
			_fail(problem + ": " + path)
			return
		if patch.is_empty():
			preserved.append(path)
			continue
		patch.merge({"id":id, "path":path, "before_sha256":FileAccess.get_sha256(path)})
		pending.append(patch)
	var report := {"input":DATA, "input_sha256":FileAccess.get_sha256(DATA), "pending":pending.size(),
		"existing_world_semantics_preserved":preserved,
		"policy":"Only missing world_semantics key; all other author bytes and UIDs preserved", "changes":[]}
	for row: Dictionary in pending:
		report.changes.append({"path":row.path, "before_sha256":row.before_sha256, "inserted_path":row.inserted_path})
	if "--dry-run" in args or pending.is_empty():
		report["changed"] = 0
		report["dry_run"] = "--dry-run" in args
		print("ACT06_CRT4_WORLD_MIGRATION ", JSON.stringify(report))
		quit(0)
		return
	var directory := "res://artifacts/leba_act06_20261117/migrations/crt4_world_%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory)) != OK:
		_fail("Backup directory creation failed; no author changed")
		return
	# Verify every backup before touching the first author. No wildcard/write root.
	for row: Dictionary in pending:
		var backup := directory.path_join(str(row.id) + ".tres")
		if FileAccess.file_exists(backup) or DirAccess.copy_absolute(ProjectSettings.globalize_path(row.path), ProjectSettings.globalize_path(backup)) != OK:
			_fail("Backup failed; no author changed: " + backup)
			return
		if FileAccess.get_sha256(backup) != str(row.before_sha256):
			_fail("Backup checksum mismatch; no author changed: " + backup)
			return
		row["backup"] = backup
	report["backup_directory"] = directory
	report["status"] = "prepared"
	if not _report(directory, report):
		_fail("Pre-write audit could not be saved; no author changed: " + directory)
		return
	for row: Dictionary in pending:
		if FileAccess.get_sha256(row.path) != str(row.before_sha256):
			_fail("Author changed after preflight; stopped without overwriting it. Backups: " + directory)
			return
		var file := FileAccess.open(row.path, FileAccess.WRITE)
		if file == null:
			_fail("Author write failed. Verified backups: " + directory)
			return
		file.store_string(row.output)
		file.close()
		if FileAccess.get_file_as_string(row.path) != str(row.output):
			_fail("Author output verification failed. Verified backups: " + directory)
			return
		var written: Resource = ResourceLoader.load(row.path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if written == null or written.get_script() != Component:
			_fail("Modified author did not reload. Verified backups: " + directory)
			return
		var actual: Dictionary = written.get("parameters")
		var actual_value: Variant = actual.get("world_semantics")
		if str(row.id) == "visuals":
			actual_value = actual.get("geometry", {}).get("source_geometry", {}).get("world_semantics")
		if actual_value != row.expected:
			_fail("Reloaded semantic value differs. Verified backups: " + directory)
			return
		for change: Dictionary in report.changes:
			if change.path == row.path:
				change["after_sha256"] = FileAccess.get_sha256(row.path)
				change["backup"] = row.backup
				change["all_other_bytes_preserved"] = true
	report["changed"] = pending.size()
	report["status"] = "complete"
	if not _report(directory, report):
		_fail("Authors migrated but final audit write failed: " + directory)
		return
	print("ACT06_CRT4_WORLD_MIGRATION ", JSON.stringify(report))
	quit(0)

func _valid_world(world: Dictionary) -> bool:
	if str(world.get("character_id", "")) != "crt_4" or int(world.get("schema_version", 0)) != 1:
		problem = "World data character/schema guard failed"
		return false
	for id: String in ["1326", "1154"]:
		var row: Variant = world.get("flights", {}).get(id)
		if not row is Dictionary or int(row.get("source_id", -1)) != int(id):
			problem = "World flight source missing or wrong: " + id
			return false
		var shape: Variant = row.get("flight", {}).get("helper", {}).get("shape_rect")
		if not shape is Array or shape.size() != 4:
			problem = "Original finite flight shape rectangle missing: " + id
			return false
	for field: String in ["field_316", "mummy_978"]:
		if not world.get(field) is Dictionary:
			problem = "World semantics section missing: " + field
			return false
	if int(world.field_316.get("source_id", -1)) != 316 or int(world.mummy_978.get("source_id", -1)) != 978:
		problem = "World field/mummy source guard failed"
		return false
	if str(world.get("provenance", {}).get("input_sha256", "")).length() != 64:
		problem = "World semantics input provenance SHA missing"
		return false
	var statuses: Dictionary = world.get("enemy_status_placements", {})
	if int(statuses.get("status_root_source_id", -1)) != 4021:
		problem = "Original enemy status-root placement contract missing"
		return false
	for page: String in ["1", "20"]:
		if not statuses.get("source_frames", {}).get(page) is Array:
			problem = "Original enemy status page placement missing: " + page
			return false
	var selector: Dictionary = statuses.get("kalla_selector", {})
	for id: String in ["3968", "3969", "3970"]:
		if int(selector.get("inner_children", {}).get(id, {}).get("source_id", -1)) != int(id):
			problem = "Original Kalla status child placement missing: " + id
			return false
	var spawning: Dictionary = world.get("y_world_spawn", {})
	if int(spawning.get("swamp", {}).get("source_id", -1)) != 944 or int(spawning.get("beast", {}).get("source_id", -1)) != 907:
		problem = "Original Y world spawn/mirror branches missing"
		return false
	return true

func _plan_patch(id: String, source: String, parameters: Dictionary, world: Dictionary) -> Dictionary:
	var marker := "parameters = {"
	if source.count(marker) != 1:
		problem = "Author parameters serialization is not recognized; no rewrite attempted"
		return {}
	var opening := source.find(marker) + marker.length() - 1
	var key := "world_semantics"
	var value: Dictionary
	var inserted_path := "parameters.world_semantics"
	if id == "visuals":
		var geometry: Variant = parameters.get("geometry")
		if not geometry is Dictionary:
			problem = "Visuals geometry is missing or is not a Dictionary"
			return {}
		var parent: Variant = geometry.get("source_geometry", {})
		if not parent is Dictionary:
			problem = "Existing source_geometry is not a Dictionary; author preserved"
			return {}
		if parent.has(key):
			return {}
		opening = _child_dictionary(source, opening, "geometry")
		if opening < 0:
			problem = "Visuals geometry text does not match loaded Resource"
			return {}
		if geometry.has("source_geometry"):
			opening = _child_dictionary(source, opening, "source_geometry")
			if opening < 0:
				problem = "Visuals source_geometry text does not match loaded Resource"
				return {}
			value = world.duplicate(true)
		else:
			key = "source_geometry"
			value = {"world_semantics":world.duplicate(true)}
		inserted_path = "parameters.geometry.source_geometry.world_semantics"
	else:
		if parameters.has(key):
			return {}
		if id in ["1326", "1154"]:
			value = world.flights[id].duplicate(true)
		elif id == "316":
			value = world.field_316.duplicate(true)
		else:
			value = world.mummy_978.duplicate(true)
	var insertion := "\n" + var_to_str(key) + ": " + var_to_str(value) + ","
	var at := opening + 1
	var output := source.insert(at, insertion)
	if output.substr(0, at) + output.substr(at + insertion.length()) != source:
		problem = "Insertion could not prove unrelated byte preservation"
		return {}
	var expected: Dictionary = world.duplicate(true) if id == "visuals" else value.duplicate(true)
	return {"output":output, "expected":expected, "inserted_path":inserted_path}

func _child_dictionary(text: String, parent: int, wanted: String) -> int:
	# Read one direct Dictionary key, respecting escaped strings and comments.
	var depth := 0
	var i := parent
	while i < text.length():
		var c := text.substr(i, 1)
		if c == ";":
			var newline := text.find("\n", i)
			i = text.length() if newline < 0 else newline + 1
			continue
		if c == "\"":
			var start := i
			i += 1
			while i < text.length():
				if text.substr(i, 1) == "\\":
					i += 2
					continue
				if text.substr(i, 1) == "\"":
					break
				i += 1
			if depth == 1 and text.substr(start + 1, i - start - 1) == wanted:
				var after := i + 1
				while after < text.length() and text.substr(after, 1) in [" ", "\t", "\r", "\n"]:after += 1
				if text.substr(after, 1) == ":":
					after += 1
					while after < text.length() and text.substr(after, 1) in [" ", "\t", "\r", "\n"]:after += 1
					return after if text.substr(after, 1) == "{" else -2
		elif c == "{":
			depth += 1
		elif c == "}":
			depth -= 1
			if depth == 0:return -1
		i += 1
	return -1

func _report(directory: String, report: Dictionary) -> bool:
	var file := FileAccess.open(directory.path_join("report.json"), FileAccess.WRITE)
	if file == null:return false
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	return true

func _fail(message: String, code: int = 1) -> void:
	push_error(message)
	quit(code)
