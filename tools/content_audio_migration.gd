extends RefCounted
## Add missing source sounds only. Never regenerates an authored action.
const Convert = preload("res://tools/content_conversion.gd")

func apply_action(action: Resource, assets: Dictionary) -> Dictionary:
	var expected: Array = Convert.new().source_sounds(action.animation_key,assets,Array(action.sequence))
	var names: Array = expected.map(func(row: Dictionary)->String:return row.sound)
	var added: Array = []
	var overrides: Array = []
	var present: Array = []
	for row: Dictionary in expected:
		var matched := false
		var custom := false
		for event: Resource in action.events:
			# `kind=sound` is the script default and need not appear in .tres text.
			if str(event.kind) != "sound" or int(event.frame) != int(row.frame):continue
			if str(event.sound) == str(row.sound):matched = true
			elif str(event.sound) not in names:custom = true
		if matched:present.append(row.sound);continue
		if custom:
			overrides.append({"sound":row.sound,"frame":row.frame,"reason":"existing authored sound at this frame preserved"})
			continue
		var item := Convert.Event.new()
		item.frame = int(row.frame)
		item.sound = str(row.sound)
		item.audio_offset = float(row.offset)
		item.audio_stream = load(str(assets.audio.sfx[row.sound]))
		assert(item.audio_stream != null,"声音资源不能加载："+row.sound)
		item.parameters = row.duplicate(true)
		for key: String in ["kind","frame","sound","offset"]:item.parameters.erase(key)
		item.source = "原StartSound：sprite%d/frame%d/Sound%d；起播%d samples@44100；ACT04定向补接，不重生成动作。"%[int(row.sprite_id),int(row.frame),int(row.sound_id),int(row.get("in_point_samples_44100",0))]
		action.events.append(item)
		added.append({"sound":row.sound,"frame":row.frame,"sound_id":row.sound_id,"offset":row.offset})
	return {"action":action.identifier,"path":action.resource_path,"expected":expected.size(),"added":added,"already_present":present,"author_overrides":overrides}
