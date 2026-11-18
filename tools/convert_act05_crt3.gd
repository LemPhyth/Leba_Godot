extends SceneTree
## Additive, explicitly invoked first conversion. Authors are never regenerated.
const Convert = preload("res://tools/content_conversion.gd")
const Component = preload("res://scripts/content/component_definition.gd")
var helper := Convert.new()
var assets: Dictionary
var rules: Dictionary
var actions: Dictionary = {}
const COMBOS := ["basic","basic2","basic3","skill_s","skill_s2","skill_s3"]
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	if "--convert-crt3" not in OS.get_cmdline_user_args():quit(2);return
	assets = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_catalog.json"))
	rules = JSON.parse_string(FileAccess.get_file_as_string("res://data/act05_crt3_rules.json"))
	for id: String in rules.actions:_action(id,rules.actions[id])
	if actions.size()!=rules.actions.size():push_error("CRT3动作转换不完整");quit(1);return
	var components: Array[Resource] = []
	for id: String in rules.components:
		if id == "source_audio":continue
		var c := Component.new();c.identifier=id;c.parameters=rules.components[id].duplicate(true)
		c.source="Original AS/XML default CRT3; reviewed rules in act05_crt3_rules.json"
		components.append(helper.save_new(c,"res://content/components/crt3/"+id+".tres"))
	var c := Component.new();c.identifier="visuals"
	c.parameters={"geometry":assets.source_geometry.act05_crt3_components.duplicate(true),"independent_windows":rules.independent_windows.duplicate(true),"sounds":{}}
	for key: String in assets.animations:
		if key.begins_with("crt3_") or key.begins_with("hud_crt3_"):c.animations.append(helper.animation(key,assets))
	for alias: String in assets.audio_events:
		if not alias.begins_with("crt3_"):continue
		var event: Dictionary=assets.audio_events[alias].duplicate(true)
		event["sound"]=alias;event["frame"]=int(event.frame);event["offset"]=float(event.get("in_point_samples_44100",0))/44100.0
		event["audio_stream"]=load(str(assets.audio.sfx[alias]))
		assert(event.audio_stream is AudioStream)
		c.parameters.sounds[alias]=event
	components.append(helper.save_new(c,"res://content/components/crt3/visuals.tres"))
	var character := Convert.Character.new();character.identifier="crt_3";character.title="角色编号3";character.source_crt=3
	character.actor_scene=_actor();character.components=components
	for id: String in actions:character.actions.append(actions[id])
	character.extra={"source_profile":rules.default_profile,"movement_parent_start":102,"movement_parent_end":104,"death_settlement_frame":25,"hit_fx_animation":"player_hit_fx","default_locked_slots":[4272,4276,4283,4288],"skill_slot_actions":{"a":"skill_a","s":"skill_s","d":"skill_d","f":"skill_f","g":"skill_g","q":"skill_q","h":"skill_h","w":"skill_w","e":"skill_e","v":"skill_v","air_z":"jump_z"}}
	character.source="Original3841 defaults;6732 parent101..140,4391 page4,2728 page5; ACT05 evidence report"
	helper.save_new(character,"res://content/characters/crt_3.tres")
	print("ACT05_CRT3_CONVERT actions=",actions.size()," components=",components.size(),"; existing author values preserved")
	quit()
func _action(id: String, data: Dictionary) -> void:
	var row := data.duplicate(true)
	row.sequence=Array(PackedInt32Array(row.sequence))
	row.animation=str(data.animation_key);assert(assets.animations.has(row.animation))
	row.cost=float(data.mp_cost);row.required_mp=row.cost;row.input=str(data.get("input","") if data.get("input")!=null else "")
	row.allowed_states=[]
	for state: String in data.allowed_states:
		if state=="attack":row.allowed_states.append_array(COMBOS)
		else:row.allowed_states.append(state)
	row.source_allowed_parent_frames=data.allowed_parents.duplicate()
	row["nested_audio"]=nested_rows(id,data,rules.components.source_audio,assets)
	row.next_action="idle";row.events=[];row.windows=[]
	row["reset_combo_counters"]=id in ["skill_a","skill_d","skill_f","skill_g","skill_q","skill_v"]
	if id=="skill_v":row.sequence.append_array(data.success_sequence)
	row.sequence=Array(PackedInt32Array(row.sequence))
	if id in ["fallen","dead"]:row.hold=true;row.hold_at=[int(data.hold_source_frame)]
	for event: Dictionary in data.events:
		if int(event.source_frame)==0 or event.kind=="player_hit_fx":continue
		var value:=event.duplicate(true);value.frame=int(event.source_frame);value.kind="crt3_"+str(event.kind)
		if event.kind=="stop_all_sounds":value.kind="stop_all_sounds"
		row.events.append(value)
	if data.has("afterimages"):
		for frame: int in data.afterimages.frames:row.events.append({"frame":frame,"kind":"crt3_spawn","right_id":int(data.afterimages.right_id),"left_id":int(data.afterimages.left_id)})
	if data.has("dust"):row.events.append({"frame":int(data.dust.frame),"kind":"crt3_spawn","right_id":int(data.dust.right_id),"left_id":int(data.dust.left_id)})
	if id=="skill_f":row.events.append({"frame":2,"kind":"crt3_spawn","right_id":1023,"left_id":593})
	row.events.append_array(helper.source_sounds(row.animation,assets,row.sequence))
	if id=="skill_h":row.events.append({"frame":11,"kind":"crt3_over_start"})
	if id=="skill_e":row.events.append({"frame":1,"kind":"crt3_cutin"});row.events.append({"frame":10,"kind":"crt3_e_start"})
	_windows(row)
	for key: String in ["id","animation_key","mp_cost","source_audio","main_source_audio","slot_source_paths","source_paths","input_source","control_scripts"]:row.erase(key)
	actions[id]=helper.action(id,row,assets,"res://content/actions/crt3/"+id+".tres")
func _windows(row: Dictionary) -> void:
	var table: Dictionary=assets.source_geometry.act05_crt3_hit_windows.timelines.get(str(int(row.source_id)),{})
	var m: Array=row.parent_matrix
	var parent:=Transform2D(Vector2(m[0],m[1]),Vector2(m[2],m[3]),Vector2(m[4],m[5]))
	for spec: Dictionary in rules.hit_windows_source:
		if int(spec.source_id)!=int(row.source_id) or bool(spec.get("excluded_default",false)):continue
		var rule: Dictionary=spec.default_rule
		if bool(rule.get("excluded_default",false)) or str(rule.get("kind","")) in ["excluded","equipment_only"]:continue
		var frames: Array=spec.get("active_source_frames",range(int(spec.active_frames[0]),int(spec.active_frames[-1])+1))
		for frame: int in frames:
			if frame not in row.sequence:continue
			var rectangles: Array=[]
			for hit: Dictionary in table.get("active_by_source_frame",{}).get(str(frame),[]):
				if int(hit.source_id)!=int(spec.helper_id) or int(hit.depth)!=int(spec.depth):continue
				var r: Array=hit.rect;rectangles.append(parent*Rect2(r[0],r[1],r[2],r[3]))
			row.windows.append({"from":frame,"until":frame,"kind":"crt3_hit","local_rects":rectangles,"gravity":float(rule.get("gravity",-5)) if rule.get("gravity")!=null else -5.0,"damage":float(rule.get("direct_damage",0)) if rule.get("direct_damage")!=null else 0.0,"once_per_action":false,"source_helper":int(spec.helper_id),"source_depth":int(spec.depth),"source_rule":rule.duplicate(true),"source_frame":frame,"source_birth_frame":int(spec.active_frames[0])})
func _actor() -> PackedScene:
	var node:=Node2D.new();node.name="Actor";node.set_script(load("res://scripts/combat/combatant.gd"))
	var offset: Node2D=helper.add(node,Node2D.new(),node,"AuthorOffset")
	var visual: Node2D=helper.add(offset,Node2D.new(),node,"Visual");visual.set_script(load("res://scripts/combat/source_sprite.gd"));visual.source_animation=actions.idle.animation
	var preview: Node2D=helper.add(offset,Node2D.new(),node,"ActionPreview");preview.set_script(load("res://scripts/content/action_preview.gd"));preview.action=actions.idle
	return helper.pack_new(node,"res://scenes/actors/crt3.tscn")

static func nested_rows(id: String,data: Dictionary,source_audio: Dictionary,catalog: Dictionary) -> Array:
	var rows: Array=[]
	for clock: Dictionary in source_audio.nested_candidates:
		if int(clock.source_id)not in [5732,6040]:continue
		var sounds: Array=[]
		var prefix:="crt3_child_"+str(int(clock.source_id))
		for alias: String in catalog.audio_events:
			if alias!=prefix and not(alias.begins_with(prefix+"_sound_")and alias.trim_prefix(prefix+"_sound_").is_valid_int()):continue
			var event: Dictionary=catalog.audio_events[alias].duplicate(true)
			event.merge({"frame":int(event.frame),"kind":"sound","sound":alias,"offset":float(event.get("in_point_samples_44100",0))/44100.0,"audio_stream":load(str(catalog.audio.sfx[alias]))},true)
			sounds.append(event)
		for birth: Dictionary in clock.placements:
			if int(birth.parent_source_id)!=int(data.source_id):continue
			rows.append({"identifier":"src%d_d%d_f%d"%[int(clock.source_id),int(birth.depth),int(birth.frame)],"source_id":int(clock.source_id),"from_frame":int(birth.frame),"until_frame":78 if id=="skill_v" else int(data.sequence[-1]),"entry_frame":1,"sounds":sounds})
	return rows
