extends SceneTree
## Explicit initial conversion from reviewed source facts. Existing author
## resources/layouts are never regenerated; normal imports do not call this.
const Convert = preload("res://tools/content_conversion.gd")
const Component = preload("res://scripts/content/component_definition.gd")
var helper := Convert.new()
var assets: Dictionary
var rules: Dictionary
var actions: Dictionary = {}
var components: Array[Resource] = []
const COMBOS := ["basic","basic2","basic3","pren_basic1","pren_basic2","pren_basic3","pren_basic4"]
const INPUT_ALIASES := {"skill_d":"skill","skill_f":"load_f","skill_g":"load_g","skill_h":"load_h"}

func _initialize() -> void:call_deferred("_run")

func _matrix(row: Array) -> Transform2D:
	return Transform2D(Vector2(row[0],row[1]),Vector2(row[2],row[3]),Vector2(row[4],row[5]))

func _run() -> void:
	if "--convert-crt2" not in OS.get_cmdline_user_args():quit(2);return
	assets = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_catalog.json"))
	rules = JSON.parse_string(FileAccess.get_file_as_string("res://data/act04_crt2_rules.json"))
	for id: String in rules.actions:_action(id,rules.actions[id])
	if actions.size() != rules.actions.size():
		push_error("角色2首次转换未完整生成全部动作，拒绝注册或报告成功")
		quit(1);return
	_components()
	var actor := _actor()
	var character := Convert.Character.new()
	character.identifier = "crt_2"
	character.title = "角色编号2"
	character.source_crt = 2
	character.actor_scene = actor
	character.components = components
	for id: String in actions:character.actions.append(actions[id])
	character.extra = {"source_profile":rules.default_profile,"default_locked_slots":[4209,4213,4221,4227],"movement_parent_start":65,"movement_parent_end":67,"death_settlement_frame":25,"hit_fx_animation":"player_hit_fx",
		"skill_slot_actions":{"a":"skill_a","s":"skill_s_start","d":"skill_d","f":"skill_f","g":"skill_g","h":"skill_h","w":"skill_w","e":"skill_e","r":"skill_r","v":"skill_v","q":"skill_q","z":"skill_z","air_z":"jump_z"},
		"source_observers":rules.get("global_default_observers",[]),"calibration":"默认功能按AS/XML接通；源回调排队、重复命中总伤害及低血外观瞬态未宣称原生Flash一致。"}
	character.source = "原3841初始化、6732父64..112、4391页3；逐项来源见docs/LEBA-ACT-04_角色2与资源依据.md及data/act04_crt2_rules.json。"
	var authored: Resource = helper.save_new(character,"res://content/characters/crt_2.tres")
	var index: Resource = load("res://content/index.tres")
	if "--register-crt2" in OS.get_cmdline_user_args() and not index.characters.any(func(item: Resource)->bool:return item.identifier == "crt_2"):
		index.characters.append(authored)
		assert(ResourceSaver.save(index,index.resource_path) == OK)
	print("ACT04_CRT2_CONVERT actions=",authored.actions.size()," components=",authored.components.size(),"; existing author values preserved")
	quit()

func _action(id: String, source: Dictionary) -> void:
	var row := source.duplicate(true)
	row.animation = str(source.animation_key)
	assert(assets.animations.has(row.animation),"角色2动画缺失："+row.animation)
	row["cost"] = float(source.mp_cost)
	row["required_mp"] = row.cost
	row["required_hp"] = float(source.hp_cost)
	row["input"] = str(INPUT_ALIASES.get(str(source.input),source.input))
	row["allowed_states"] = []
	for state: String in source.allowed_states:
		if state == "attack":row.allowed_states.append_array(COMBOS)
		else:row.allowed_states.append(state)
	row["source_allowed_parent_frames"] = source.allowed_parents.duplicate()
	if row.source_allowed_parent_frames.is_empty():row.erase("source_allowed_parent_frames")
	row["normal_end_source_frame"] = int(source.sequence[-1])
	row["next_action"] = str(source.next) if source.next != null else "idle"
	row["events"] = []
	row["windows"] = []
	var nested := nested_audio_rows(id,rules,assets)
	if not nested.is_empty():row["nested_audio"] = nested
	if source.has("success_sequence"):row.sequence.append_array(source.success_sequence)
	if source.has("follow_sequence"):row.sequence.append_array(source.follow_sequence)
	if id == "skill_h_close":row.sequence = [1,2]+range(90,103)
	if id == "jump":row["next_action"] = "idle"
	if id == "jump_z":row.sequence = range(57,68);row["cooldown_deferred"] = true
	if id == "skill_r":row["cooldown_deferred"] = true
	if id in ["skill_s_release","skill_s_full","skill_z","skill_e"] and bool(source.get("end_x_transfer",false)):
		row.events.append({"frame":int(source.sequence[-1]),"kind":"crt2_transfer_child"})
	if id in ["dead","fallen"]:
		row["hold"] = true
		row["hold_at"] = [int(source.get("hold_source_frame",source.sequence[-1]))]
	if id in ["skill_s_start","hurt_z"]:
		row["cooldown_key"] = "skill_s_start"
		row["next_action"] = "skill_s_full"
	if id == "skill_h_close":row["cooldown_key"] = "skill_h"
	if source.has("combo_next"):
		row["combo_from"] = int(source.combo_source_frame)
		row["combo_until"] = int(source.sequence[-1])-1
	for data: Dictionary in source.events:
		var kind := str(data.kind)
		if kind in ["player_hit_fx","goto","stop"]:continue
		var event := data.duplicate(true)
		# Source facts use frame for the seek destination and source_frame for
		# dispatch. Preserve both instead of overwriting slot destination2.
		if data.has("frame"):event["target_frame"] = int(data.frame)
		event["frame"] = int(data.source_frame)
		if event.frame == 0:continue # Source entry operations belong to the input transaction.
		event["kind"] = kind if kind == "stop_all_sounds" else "crt2_"+kind
		row.events.append(event)
	for key: String in source.get("control_gotos",{}):row.events.append({"frame":int(key),"kind":"crt2_seek","target":int(source.control_gotos[key])})
	row.events.append_array(helper.source_sounds(row.animation,assets,row.sequence))
	_windows(id,row)
	row["body_metadata"] = "act04_crt2_body"
	row["source"] = str(source.get("source","原DefineSprite_%d"%int(source.source_id)))+"；source callbacks/default conditions见act04_crt2_rules。"
	row["calibration"] = "仅默认武器0/护甲1/master0；标注bonus是局部观察器贡献，非总伤害。"
	for key: String in ["mp_cost","animation_key","id","allowed_parents","next","source_sequence_includes_control_frames","input_source","control_scripts","parent_callback_sources","source_audio"]:row.erase(key)
	actions[id] = helper.action(id,row,assets,"res://content/actions/crt2/"+id+".tres")

func _windows(id: String, row: Dictionary) -> void:
	var table: Dictionary = assets.source_geometry.act04_crt2_hit_windows.timelines.get(str(int(row.source_id)),{})
	var parent := _matrix(row.get("parent_matrix",[1,0,0,1,0,0]))
	for spec: Dictionary in rules.hit_windows_source.get(id,[]):
		# 5649/f4/4843_34's entire marker10 observer requires bracelet5;
		# default3841 accessories0 does not execute it. It has no hit geometry.
		if id == "jump" and int(spec.helper_id) == 4843 and int(spec.depth) == 34:continue
		var rule: Dictionary = spec.default_rule
		for frame: int in range(int(spec.active_frames[0]),int(spec.active_frames[1])+1):
			var rectangles: Array = []
			for hit: Dictionary in table.get("active_by_source_frame",{}).get(str(frame),[]):
				if int(hit.source_id) != int(spec.helper_id) or int(hit.depth) != int(spec.depth):continue
				var r: Array = hit.rect
				rectangles.append(parent*Rect2(r[0],r[1],r[2],r[3]))
			if rectangles.is_empty() and bool(rule.get("requires_geometry",true)):continue
			row.windows.append({"from":frame,"until":frame,"kind":"crt2_hit","local_rects":rectangles,"gravity":float(rule.get("gravity",-5)) if rule.get("gravity") != null else -5.0,"damage":float(rule.get("direct_damage",0)),"once_per_action":bool(rule.get("normal_contact_once",false)),"source_helper":int(spec.helper_id),"source_depth":int(spec.depth),"source_rule":rule.duplicate(true),"source_frame":frame})

func _components() -> void:
	for key: String in rules.components:
		var value := Component.new()
		value.identifier = key
		value.parameters = runtime_component(rules.components[key],assets)
		value.source = "AS/XML静态规则首次转换；出处见parameters.source；作者Resource此后生效。"
		components.append(helper.save_new(value,"res://content/components/crt2/"+key+".tres"))
	var visuals := Component.new()
	visuals.identifier = "visuals"
	visuals.parameters = {"variants":assets.source_geometry.act04_crt2_pren_variants.duplicate(true),"geometry":assets.source_geometry.act04_crt2_components.duplicate(true)}
	for key: String in assets.animations:
		if key.begins_with("crt2_") or key.begins_with("hud_crt2_") or key == "enemy_bleed":visuals.animations.append(helper.animation(key,assets))
	visuals.source = "按需运行素材与源矩阵；variant不重置动作或独立子时钟。"
	components.append(helper.save_new(visuals,"res://content/components/crt2/visuals.tres"))

static func source_clock_sounds(source_id: int, catalog: Dictionary) -> Array:
	# Canonical aliases for independent clocks. Never collect a same-source
	# appearance alias or both the visual and clock aliases for5609.
	var prefix: String={4601:"crt2_g_timer",5416:"crt2_jump_attack_right",1077:"crt2_f_burst_host",5609:"crt2_r_air_hit_child",5511:"crt2_e_hit_child",298:"crt2_r_end_hit_child",5732:"crt2_v_hit_child"}.get(source_id,"")
	assert(not prefix.is_empty(),"independent audio source needs an explicit alias: "+str(source_id))
	var result: Array=[]
	for key: String in catalog.audio_events:
		var suffix:=key.trim_prefix(prefix+"_sound_")
		if key!=prefix and not (key.begins_with(prefix+"_sound_") and suffix.is_valid_int() and int(suffix)>0):continue
		var event: Dictionary=catalog.audio_events[key].duplicate(true)
		assert(int(event.sprite_id)==source_id)
		event.merge({"frame":int(event.frame),"kind":"sound","sound":key,"offset":float(event.get("in_point_samples_44100",0))/44100.0,"audio_stream":load(str(catalog.audio.sfx[key]))},true)
		assert(event.audio_stream is AudioStream)
		result.append(event)
	assert(not result.is_empty(),"independent audio missing: "+prefix)
	return result

static func nested_audio_rows(action_id: String, reviewed: Dictionary, catalog: Dictionary) -> Array:
	var result: Array=[]
	var parent_id: int={"skill_e":5520,"skill_v":5752,"skill_r":5619}.get(action_id,0)
	if parent_id==0:return result
	for clock: Dictionary in reviewed.nested_audio_clocks:
		var child_id:=int(clock.child_source_id)
		var in_r_air: bool=action_id=="skill_r" and child_id==5609
		if int(clock.parent_source_id)!=parent_id and not in_r_air:continue
		for birth: Dictionary in clock.births:
			var start:=47 if in_r_air else int(birth.source_frame)
			# Verified original display-list lifetimes: E children remain to81,
			# V5732 to79, three R298 children to137; R5609 belongs to47..129.
			var finish:=129 if in_r_air else (81 if parent_id==5520 else (79 if parent_id==5752 else 137))
			var row: Dictionary={"identifier":"src%d_depth%d_at%d"%[child_id,int(birth.depth),start],"from_frame":start,"until_frame":finish,"entry_frame":1,"source_id":child_id,"parent_source_id":int(clock.parent_source_id),"source_depth":int(birth.depth),"sounds":source_clock_sounds(child_id,catalog),"source":"原DefineSprite_%d placement child%d/depth%d；独立子时钟，移除时销毁。"%[int(clock.parent_source_id),child_id,int(birth.depth)]}
			if in_r_air:
				row["loop_frames"]=6
				row["calibration"]="5609六帧自然循环；5619→5618→5617实例相位未作原生逐tick动态对照。"
			result.append(row)
	return result

static func runtime_component(value: Variant, catalog: Dictionary) -> Variant:
	if value is Array:
		var rows: Array=[]
		for item: Variant in value:rows.append(runtime_component(item,catalog))
		return rows
	if not value is Dictionary:return value
	var row: Dictionary=value.duplicate(true)
	var raw_audio: bool=row.has("source_audio") or (row.has("audio") and row.audio is Array)
	if raw_audio or int(row.get("source_id",0))==4601:
		if not row.has("sounds"):row["sounds"]=source_clock_sounds(int(row.source_id),catalog)
		row.erase("source_audio")
		row.erase("audio")
	for key: Variant in row.keys():
		if key=="sound_info_xml":row.erase(key)
		elif key!="sounds":row[key]=runtime_component(row[key],catalog)
	return row

func _actor() -> PackedScene:
	var node := Node2D.new()
	node.name = "Actor"
	node.set_script(load("res://scripts/combat/combatant.gd"))
	var offset: Node2D = helper.add(node,Node2D.new(),node,"AuthorOffset")
	var visual: Node2D = helper.add(offset,Node2D.new(),node,"Visual")
	visual.set_script(load("res://scripts/combat/source_sprite.gd"))
	visual.source_animation = actions.idle.animation
	var preview: Node2D = helper.add(offset,Node2D.new(),node,"ActionPreview")
	preview.set_script(load("res://scripts/content/action_preview.gd"))
	preview.action = actions.idle
	return helper.pack_new(node,"res://scenes/actors/crt2.tscn")
