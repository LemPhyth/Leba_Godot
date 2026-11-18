extends SceneTree
## Explicit, additive first conversion. Import and startup never invoke this tool.
## Existing authors are authoritative: every save uses save_new/pack_new.
const Convert = preload("res://tools/content_conversion.gd")
const Component = preload("res://scripts/content/component_definition.gd")
const RULES_PATH := "res://data/act06_crt4_rules.json"
const PLAN_PATH := "res://data/act06_crt4_import.json"
const WORLD_PATH := "res://data/act06_crt4_world_semantics.json"
const COMMON_CONTACT_SOUND := "crt4_script_common_contact_sound5"
var helper := Convert.new()
var assets: Dictionary
var rules: Dictionary
var plan: Dictionary
var world: Dictionary
var actions: Dictionary = {}
var sounds_by_source: Dictionary = {}
var sounds_by_alias: Dictionary = {}
var animation_resources: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if "--convert-crt4" not in OS.get_cmdline_user_args():
		push_error("CRT4 first conversion requires explicit --convert-crt4; no files written")
		quit(2)
		return
	assets = _read_json("res://data/asset_catalog.json")
	rules = _read_json(RULES_PATH)
	plan = _read_json(PLAN_PATH)
	world = _read_json(WORLD_PATH)
	# Validate all dependencies before creating any generated or authored file.
	if not _preflight():
		quit(1)
		return
	_prepare_sounds()
	for key: String in assets.animations:
		if key.begins_with("crt4_") or key.begins_with("hud_crt4_"):
			animation_resources[key] = helper.animation(key, assets)
	for id: String in rules.actions:
		_action(id, rules.actions[id])
	var components: Array[Resource] = []
	for id: String in rules.components:
		var value := Component.new()
		value.identifier = id
		value.parameters = rules.components[id].duplicate(true)
		if id == "6528":value.parameters["directional_fx_proxies"] = _directional_fx_proxies()
		# Runtime sound rows carry actual AudioStreams; raw SOUNDINFO is audit data.
		value.parameters.erase("sound_events")
		value.parameters["sounds"] = sounds_by_source.get(id, []).duplicate(true)
		if id in ["1326", "1154"]:
			value.parameters["world_semantics"] = world.flights[id].duplicate(true)
		elif id == "316":
			value.parameters["world_semantics"] = world.field_316.duplicate(true)
		elif id == "978":
			value.parameters["world_semantics"] = world.mummy_978.duplicate(true)
		value.source = "Original AS/XML source " + id + "; " + RULES_PATH + ".components." + id
		for key: String in animation_resources:
			if int(assets.animations[key].source_sprite_id) == int(id):
				value.animations.append(animation_resources[key])
		components.append(helper.save_new(value, "res://content/components/crt4/" + id + ".tres"))
	var visuals := Component.new()
	visuals.identifier = "visuals"
	visuals.parameters = {
		"geometry": _geometry(),
		"sounds": sounds_by_alias.duplicate(true),
		"source_audio": sounds_by_source.duplicate(true),
		"movement": rules.movement.duplicate(true),
	}
	for key: String in animation_resources:
		visuals.animations.append(animation_resources[key])
	visuals.source = "Original source-layer placements and independent clocks; " + PLAN_PATH + "; canonical sound aliases from " + RULES_PATH
	components.append(helper.save_new(visuals, "res://content/components/crt4/visuals.tres"))
	var character := Convert.Character.new()
	character.identifier = "crt_4"
	character.title = "角色编号4"
	character.source_crt = 4
	character.move_per_tick = float(rules.movement.static_normal_total)
	character.actor_scene = _actor()
	character.components = components
	for id: String in actions:
		character.actions.append(actions[id])
	character.extra = {
		"source_profile": rules.default_profile.duplicate(true),
		"source_equipment_character_id": "crt_3",
		"movement_parent_start": 146,
		"movement_parent_end": 146,
		"death_settlement_frame": 25,
		"hit_fx_animation": "player_hit_fx",
		"skill_slot_actions": {"a":"skill_a", "s":"skill_s", "d":"skill_d", "f":"skill_f", "g":"skill_g", "h":"skill_h", "q":"skill_q", "w":"skill_w", "e":"skill_e", "r":"skill_r", "t":"skill_t", "y":"skill_y", "v":"skill_v", "z":"skill_z"},
	}
	character.source = "Original shared CRT3 equipment fields,6732 parents146..176,4391 page5,2728 page6; source paths and uncertainties in act06_crt4_rules.json. No independent fifth equipment/ring family."
	helper.save_new(character, "res://content/characters/crt_4.tres")
	print("ACT06_CRT4_CONVERT actions=", actions.size(), " components=", components.size(), " animations=", animation_resources.size(), " sounds=", sounds_by_alias.size(), "; existing authors preserved")
	quit(0)

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Missing CRT4 conversion input: " + path)
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary:
		push_error("Invalid CRT4 conversion JSON: " + path)
		return {}
	return value

func _preflight() -> bool:
	var failures: Array[String] = []
	if assets.is_empty() or rules.is_empty() or plan.is_empty() or world.is_empty():
		return false
	if not world.has("flights") or not world.flights.has("1326") or not world.flights.has("1154") or not world.has("field_316") or not world.has("mummy_978"):
		push_error("CRT4 finite world semantics missing required flight/field/mummy definitions")
		return false
	if int(world.get("enemy_status_placements", {}).get("status_root_source_id", 0)) != 4021 or int(world.get("y_world_spawn", {}).get("swamp", {}).get("source_id", 0)) != 944 or int(world.get("y_world_spawn", {}).get("beast", {}).get("source_id", 0)) != 907:
		failures.append("CRT4 world semantics missing exact status4021/swamp944/beast907 contracts")
	for key: String in ["actions", "components", "source_audio", "body", "hit_windows", "movement", "default_profile"]:
		if not rules.has(key):failures.append("Rules field missing: " + key)
	if not failures.is_empty():
		for issue: String in failures:push_error(issue)
		return false
	for key: String in plan.animations:
		if not assets.animations.has(key):
			failures.append("Catalog animation missing: " + key)
			continue
		var texture: String = str(assets.animations[key].texture)
		if not ResourceLoader.exists(texture) or not load(texture) is Texture2D:
			failures.append("Animation texture not imported/loadable: " + texture)
	for id: String in rules.actions:
		var row: Dictionary = rules.actions[id]
		if not assets.animations.has(str(row.animation)):
			failures.append("Action " + id + " animation missing: " + str(row.animation))
		if row.sequence.is_empty() or row.parent_matrix.size() != 6:
			failures.append("Action sequence/matrix invalid: " + id)
		for nested: Dictionary in row.get("nested_audio", []):
			if not rules.source_audio.has(str(int(nested.source_id))):
				failures.append("Nested clock audio source missing: " + str(nested.source_id))
	for sid: String in rules.source_audio:
		for event: Dictionary in rules.source_audio[sid]:
			var alias := str(event.alias)
			if not assets.audio.sfx.has(alias) or not assets.audio_events.has(alias):
				failures.append("Exact canonical sound alias missing: " + alias)
				continue
			var path := str(assets.audio.sfx[alias])
			if not ResourceLoader.exists(path) or not load(path) is AudioStream:
				failures.append("Sound is not an imported AudioStream: " + path + " (" + alias + ")")
	if int(rules.get("named_common_slash", {}).get("sound", {}).get("sound_id", 0)) != 5:
		failures.append("CRT4 named contact slash requires its original script Sound5 contract")
	elif not assets.audio.sfx.has(COMMON_CONTACT_SOUND) or not assets.audio_events.has(COMMON_CONTACT_SOUND):
		failures.append("Exact script sound alias missing: " + COMMON_CONTACT_SOUND)
	elif not ResourceLoader.exists(str(assets.audio.sfx[COMMON_CONTACT_SOUND])) or not load(str(assets.audio.sfx[COMMON_CONTACT_SOUND])) is AudioStream:
		failures.append("Script contact sound is not an imported AudioStream: " + str(assets.audio.sfx[COMMON_CONTACT_SOUND]))
	for issue: String in failures:push_error(issue)
	return failures.is_empty()

func _prepare_sounds() -> void:
	for sid: String in rules.source_audio:
		var rows: Array = []
		for source: Dictionary in rules.source_audio[sid]:
			var alias := str(source.alias)
			var value: Dictionary = assets.audio_events[alias].duplicate(true)
			value.merge({"kind":"sound", "frame":int(source.source_frame), "sound":alias, "offset":float(value.get("in_point_samples_44100", 0))/44100.0, "audio_stream":load(str(assets.audio.sfx[alias])), "source_id":int(sid)}, true)
			rows.append(value)
			sounds_by_alias[alias] = value
		sounds_by_source[sid] = rows
	# Script Sound.start belongs to each actual root slash birth, not to a main
	# action timeline; keep one editable real stream without duplicating events.
	var contact: Dictionary = assets.audio_events[COMMON_CONTACT_SOUND].duplicate(true)
	contact.merge({"kind":"sound", "frame":1, "sound":COMMON_CONTACT_SOUND, "offset":0.0, "audio_stream":load(str(assets.audio.sfx[COMMON_CONTACT_SOUND])), "source_sound_id":5}, true)
	sounds_by_alias[COMMON_CONTACT_SOUND] = contact

func _action(id: String, source: Dictionary) -> void:
	var row := source.duplicate(true)
	row.sequence = _integer_sequence(row.sequence)
	var inputs := {"skill_f":"load_f", "skill_g":"load_g", "skill_h":"load_h"}
	if inputs.has(str(row.input)):
		row["source_input"] = str(row.input)
		row.input = inputs[str(row.input)]
	row.source_references = row.source.duplicate(true)
	row.source = "Original6732 parent%d/source%d; %s.actions.%s; source_references preserve individual AS paths/hashes" % [int(row.source_parent), int(row.source_id), RULES_PATH, id]
	row.events = []
	for event: Dictionary in source.events:
		var value := event.duplicate(true)
		value.frame = int(value.frame)
		# Dispatch frame and target source_frame differ for seeks/cutins.
		if value.kind == "crt4_stop_all_sounds":value.kind = "stop_all_sounds"
		row.events.append(value)
	for sound: Dictionary in sounds_by_source.get(str(int(row.source_id)), []):
		if int(sound.frame) not in row.sequence:continue
		var value := sound.duplicate(true)
		value.erase("audio_stream") # Convert.action resolves the exact alias to a Resource.
		row.events.append(value)
	row.nested_audio = _nested_audio(source)
	row.windows = _windows(source)
	if id == "jump":
		#6530/f30 stops its parent action while6528's Kalla13..21 child finishes.
		# Runtime owns the conditional return146; an automatic action end loses it.
		row.hold = true
		row.hold_at = [30]
	if bool(row.get("hold", false)) and not row.has("hold_at"):
		row.hold_at = [int(row.sequence[-1])]
	actions[id] = helper.action(id, row, assets, "res://content/actions/crt4/" + id + ".tres")

func _integer_sequence(sequence: Array) -> Array:
	var output: Array = []
	for frame: Variant in sequence:
		var value := int(frame)
		if value not in output:output.append(value)
	return output

func _windows(action: Dictionary) -> Array:
	var result: Array = []
	var parent := _matrix(action.parent_matrix)
	var sequence := PackedInt32Array(action.sequence)
	for spec: Dictionary in action.windows:
		if not bool(spec.get("default_selected", true)):continue
		var rule: Dictionary = spec.default_rule
		for frame: int in range(int(spec.from), int(spec.until) + 1):
			if not sequence.has(frame):continue
			var rects: Array = []
			for raw: Array in spec.get("local_rects_by_source_frame", {}).get(str(frame), spec.get("local_rects", [])):
				rects.append(parent * Rect2(raw[0], raw[1], raw[2], raw[3]))
			result.append({"from":frame, "until":frame, "kind":str(spec.kind), "local_rects":rects,
				"damage":float(rule.get("direct_damage", 0)), "gravity":float(rule.get("gravity", -5)),
				"once_per_action":bool(rule.get("once_per_action", false)),
				"source_helper":int(spec.helper_source_id), "source_depth":int(spec.source_depth),
				"source_frame":frame, "source_birth_frame":int(spec.from), "source_rule":rule.duplicate(true),
				"source_parent_matrix":action.parent_matrix.duplicate(), "source_placement_track":spec.get("placement_track", []).duplicate(true),
				"source_references":spec.get("source", []).duplicate(true), "rect_space":"actor_local; source parent matrix applied once"})
	return result

func _nested_audio(action: Dictionary) -> Array:
	var result: Array = []
	for original: Dictionary in action.get("nested_audio", []):
		var row := original.duplicate(true)
		row.source_id = int(row.source_id)
		row["identifier"] = str(row.get("identifier", "src%d_d%d_f%d" % [row.source_id, int(row.get("depth", 0)), int(row.from_frame)]))
		row["sounds"] = sounds_by_source[str(row.source_id)].duplicate(true)
		row.erase("alias_prefix")
		row.erase("audio_alias_prefix")
		result.append(row)
	return result

func _geometry() -> Dictionary:
	var result := {"body":rules.body.duplicate(true), "hit_windows":rules.hit_windows.duplicate(true), "components":rules.components.duplicate(true)}
	result["named_common_slash"] = rules.named_common_slash.duplicate(true)
	result.components["6528"]["directional_fx_proxies"] = _directional_fx_proxies()
	if assets.get("source_geometry", {}).has("act06_crt4_components"):
		# First-copy only. Runtime reads this author-owned placement/feedback table;
		# later catalog imports cannot overwrite manually adjusted child matrices.
		result["source_geometry"] = assets.source_geometry.act06_crt4_components.duplicate(true)
	if not result.has("source_geometry"):
		result["source_geometry"] = {}
	result.source_geometry["world_semantics"] = world.duplicate(true)
	for key: String in ["independent_children_removed", "sparse_visual_mapping", "render_stop_hold", "visual_clock_reuse", "transparent_clocks_without_png", "parent_scales", "appearance_by_source_frame"]:
		if plan.has(key):result[key] = plan[key].duplicate(true)
	# Sources remain independently editable components, not a hidden XML sound table.
	for sid: String in result.components:
		result.components[sid].erase("sound_events")
	return result

func _directional_fx_proxies() -> Dictionary:
	return {"nested_proxy":rules.components["6528"].ordinary_air_x.nested_directional_proxy.duplicate(true), "root_observed_component":5417, "root_observed_parent_source":6530, "sound_alias":COMMON_CONTACT_SOUND}

func _matrix(values: Array) -> Transform2D:
	return Transform2D(Vector2(values[0], values[1]), Vector2(values[2], values[3]), Vector2(values[4], values[5]))

func _actor() -> PackedScene:
	var node := Node2D.new()
	node.name = "Actor"
	node.set_script(load("res://scripts/combat/combatant.gd"))
	var offset: Node2D = helper.add(node, Node2D.new(), node, "AuthorOffset")
	var visual: Node2D = helper.add(offset, Node2D.new(), node, "Visual")
	visual.set_script(load("res://scripts/combat/source_sprite.gd"))
	visual.source_animation = actions.idle.animation
	var preview: Node2D = helper.add(offset, Node2D.new(), node, "ActionPreview")
	preview.set_script(load("res://scripts/content/action_preview.gd"))
	preview.action = actions.idle
	return helper.pack_new(node, "res://scenes/actors/crt4.tscn")
