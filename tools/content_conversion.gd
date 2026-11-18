extends RefCounted
## One-time conversion helpers. All saves reject existing files. Import never calls these.
const AnimationData = preload("res://scripts/content/source_animation.gd")
const Action = preload("res://scripts/content/action_definition.gd")
const Event = preload("res://scripts/content/action_event.gd")
const HitWindow = preload("res://scripts/content/hit_window.gd")
const Character = preload("res://scripts/content/character_definition.gd")
const Stage = preload("res://scripts/content/stage_definition.gd")

func source_sounds(animation_key: String, assets: Dictionary, sequence: Array) -> Array:
	# JSON arrays contain float Variants. Array.has/in compares those differently
	# from integer frame IDs; normalize the domain once before source filtering.
	var frames := PackedInt32Array(sequence)
	var animation: Dictionary = assets.animations[animation_key]
	var result: Array = []
	for key: String in assets.audio_events:
		var source: Dictionary = assets.audio_events[key]
		# Appearance variants can share a source sprite and sound IDs. They are
		# not additional events of the base animation. Keep each exact sibling
		# _sound_N event, including distinct sounds on the same source frame.
		var suffix := key.trim_prefix(animation_key+"_sound_")
		# The established _charge alias is another StartSound in CRT1 S4917,
		# not a separate appearance animation. Retain it with the same-ID check.
		var belongs := key == animation_key or key == animation_key+"_charge" or (key.begins_with(animation_key+"_sound_") and suffix.is_valid_int() and int(suffix) > 0)
		if not belongs or int(source.sprite_id) != int(animation.source_sprite_id) or not frames.has(int(source.frame)):continue
		var event := source.duplicate(true)
		event.merge({"frame":int(source.frame),"kind":"sound","sound":key,"offset":float(source.get("in_point_samples_44100",0))/44100.0},true)
		result.append(event)
	return result

func save_new(value: Resource, path: String) -> Resource:
	if FileAccess.file_exists(path):return load(path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var result := ResourceSaver.save(value,path)
	assert(result == OK,"内容首次转换保存失败："+path)
	return load(path)

func animation(key: String, assets: Dictionary) -> Resource:
	var value := AnimationData.new()
	var data: Dictionary = assets.animations[key]
	value.identifier = key
	value.texture = load(str(data.texture))
	value.frames.assign(data.frames)
	value.baked_placement_matrix = PackedFloat64Array(data.get("baked_placement_matrix",[1,0,0,1,0,0]))
	value.baked_alpha_mult = float(data.get("baked_alpha_mult",256))
	value.parent_scale = Vector2(data.get("parent_scale",[1,1])[0],data.get("parent_scale",[1,1])[1])
	value.source = "asset_catalog.animations."+key+"；派生图集；来源与pivot见catalog。"
	return save_new(value,"res://generated/animations/"+key+".tres")

func action(id: String, row: Dictionary, assets: Dictionary, path: String) -> Resource:
	var value := Action.new()
	value.identifier = id
	value.title = id
	value.animation_key = row.animation
	value.animation = animation(str(row.animation),assets)
	value.source_parent = int(row.get("source_parent",1))
	value.sequence = PackedInt32Array(row.get("sequence",[]))
	value.input_id = str(row.get("input",id))
	value.allowed_states = PackedStringArray(row.get("allowed_states",["idle","move","basic"]))
	value.cost = float(row.get("cost",0))
	value.required_mp = float(row.get("required_mp",0))
	value.hp_cost = float(row.get("hp_cost",0))
	value.required_hp = float(row.get("required_hp",0))
	value.cubes = int(row.get("cubes",0))
	value.cooldown_ticks = int(row.get("cooldown_ticks",0))
	value.cooldown_key = str(row.get("cooldown_key",""))
	value.loop = bool(row.get("loop",false))
	value.hold = bool(row.get("hold",false))
	value.hold_at = PackedInt32Array(row.get("hold_at",[]))
	value.next_action = str(row.get("next_action","idle"))
	value.combo_next = str(row.get("combo_next",""))
	value.combo_from = int(row.get("combo_from",1))
	value.combo_until = int(row.get("combo_until",1))
	value.source = str(row.get("source","已有AS/XML动作定义；动画"+str(row.animation)))
	value.calibration = str(row.get("calibration",""))
	value.visual_offset = row.get("visual_offset",Vector2.ZERO)
	value.extra = row.duplicate(true)
	for key: String in ["animation","source_parent","sequence","input","allowed_states","cost","required_mp","hp_cost","required_hp","cubes","cooldown_ticks","cooldown_key","loop","hold","hold_at","next_action","combo_next","combo_from","combo_until","events","windows","source","calibration","visual_offset"]:value.extra.erase(key)
	for data: Dictionary in row.get("events",[]):
		var item := Event.new()
		item.frame = int(data.frame)
		item.kind = str(data.kind)
		item.sound = str(data.get("sound",""))
		item.audio_offset = float(data.get("offset",0))
		if not item.sound.is_empty() and assets.audio.sfx.has(item.sound):item.audio_stream = load(str(assets.audio.sfx[item.sound]))
		item.projectile = str(data.get("projectile","projectile"))
		item.gravity = float(data.get("gravity",-5))
		item.damage = float(data.get("damage",5))
		item.parameters = data.duplicate(true)
		for key: String in ["frame","kind","sound","offset","projectile","gravity","damage"]:item.parameters.erase(key)
		value.events.append(item)
	for data: Dictionary in row.get("windows",[]):
		var item := HitWindow.new()
		item.from_frame = int(data.from)
		item.until_frame = int(data.until)
		item.kind = str(data.kind)
		item.damage = float(data.get("damage",0))
		item.gravity = float(data.get("gravity",-5))
		item.knockback = float(data.get("knockback",0))
		item.once_per_action = bool(data.get("once_per_action",true))
		for rect: Rect2 in data.get("local_rects",[]):item.rectangles.append(rect)
		item.parameters = data.duplicate(true)
		for key: String in ["from","until","kind","damage","gravity","knockback","once_per_action","status","status_ticks","local_rects"]:item.parameters.erase(key)
		value.windows.append(item)
	return save_new(value,path)

func pack_new(node: Node, path: String) -> PackedScene:
	if FileAccess.file_exists(path):
		node.free()
		return load(path)
	var packed := PackedScene.new()
	assert(packed.pack(node) == OK)
	var result := save_new(packed,path) as PackedScene
	node.free()
	return result

func add(parent: Node, child: Node, owner: Node, label: String) -> Node:
	child.name = label
	parent.add_child(child)
	child.owner = owner
	return child
