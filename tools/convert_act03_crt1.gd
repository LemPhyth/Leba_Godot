extends SceneTree
## Explicit first conversion. The normal importer never writes author resources.
const Convert = preload("res://tools/content_conversion.gd")
const Component = preload("res://scripts/content/component_definition.gd")
var helper := Convert.new()
var assets: Dictionary
var actions: Dictionary = {}
var base_states: Array = ["idle","move","basic","basic2","basic3","basic4","basic5"]
var base_parents: Array = [30,31,32,33,37,38,39,40,41]

func _initialize() -> void:call_deferred("_run")

func _run() -> void:
	if "--convert-crt1" not in OS.get_cmdline_user_args():
		push_error("显式首次转换需要 -- --convert-crt1；现有作者资源不会覆盖")
		quit(1)
		return
	assets = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_catalog.json"))
	assert(assets.source_geometry.has("act03_crt1_hit_windows"))
	_make_actions()
	var character := Convert.Character.new()
	character.identifier = "crt_1"
	character.title = "角色编号1"
	character.source_crt = 1
	character.actor_scene = load("res://scenes/actors/crt1.tscn")
	character.source = "原6732父30起；默认武器0、装扮1、master0。AS/XML路径、默认与解锁边界见各Action和asset_catalog.act03_crt1_*。"
	character.extra = {"source_profile":{"weapon":0,"armor":1,"master":0},"default_locked_slots":[4151,4155,4165,4172],"skill_slot_actions":{"a":"skill_a","s":"skill_s","d":"skill","f":"skill_f","q":"skill_q","h":"skill_h","w":"skill_w","e":"skill_e","r":"skill_r","revenger":"revenger","v":"skill_v","t":"skill_t","g":"skill_g","z":"skill_z"},"calibration":"默认功能链依据静态AS/XML恢复；伤害分期和手感不宣称已通过精确原作运行oracle。"}
	for id: String in actions:
		character.actions.append(helper.action(id,actions[id],assets,"res://content/actions/crt1/"+id+".tres"))
	var result: Resource = helper.save_new(character,"res://content/characters/crt_1.tres")
	_migrate_components()
	_migrate_crt0_knockdown()
	print("ACT03_CRT1_CONVERT actions=",result.actions.size(),"; existing author files preserved; index registration belongs to the main integrator")
	quit()

func _migrate_components() -> void:
	# Explicit first migration only: existing component parameters and action values survive.
	var bindings := {"jump":["jump"],"d_follow":["d_follow"],"moving_fire":["skill_w"],"awakening":["skill_t"],"buff":["skill_q"],"gunhawks":["skill_r","r_catch1","r_catch2"],"grab":["skill_v"]}
	var dependencies := {
		"jump":["crt1_jump","crt1_jump_air","projectile_diagonal"],
		"d_follow":["crt1_d_follow","crt1_d_air","projectile_diagonal_two"],
		"moving_fire":["crt1_w_idle","crt1_w_move","crt1_w_shot","projectile_moving","hud_crt1_w_ammo"],
		"awakening":["crt1_skill_t","crt1_t_hold_body","crt1_t_move_body","crt1_t_ground_fire","crt1_t_ground_shell","crt1_t_air_fire1","crt1_t_air_fire2","crt1_t_air_body","hud_crt1_t_cutin"],
		"buff":["crt1_q_buff_edges","crt1_q_buff_ring","crt1_q_buff_cloud"],
		"gunhawks":["crt1_gunhawk1","crt1_gunhawk2","crt1_gunhawk3"],
		"grab":["crt1_skill_v"],
	}
	var attached := 0
	var extended := 0
	for key: String in bindings:
		var value := Component.new()
		value.identifier = "crt1_"+key
		value.parameters = assets.source_geometry.act03_crt1_components.get(key,{}).duplicate(true)
		value.source = "首次派生：asset_catalog.source_geometry.act03_crt1_components."+key+"；此Resource自此为作者参数权威，普通资源导入不覆盖。来源原AS/XML及边界见docs/LEBA-ACT-03_角色1与资源依据.md。"
		if key=="grab":value.source="原5679及6732父99矩阵，首次来源asset_catalog.act03_crt1_actions/act03_crt1_hit_windows；作者parameters是运行权威，普通导入不覆盖。"
		for animation_key: String in dependencies[key]:value.animations.append(helper.animation(animation_key,assets))
		var component_path := "res://content/components/crt1/"+key+".tres"
		var authored: Resource = helper.save_new(value,component_path)
		var before: Dictionary = authored.parameters.duplicate(true)
		if _fill_missing(authored.parameters,_component_additions(key)):
			assert(_preserves_values(authored.parameters,before),"迁移意外改动已有作者值："+key)
			assert(ResourceSaver.save(authored,component_path)==OK,"首次补入组件参数失败："+key)
			extended += 1
		for action_id: String in bindings[key]:
			var path := "res://content/actions/crt1/"+action_id+".tres"
			var action: Resource = load(path)
			if action.component_definition != null:continue
			action.component_definition = authored
			assert(ResourceSaver.save(action,path)==OK,"首次补入组件引用失败："+path)
			attached += 1
	print("ACT03_CRT1_COMPONENTS seven author definitions; newly attached actions=",attached,"; extended components=",extended)

func _fill_missing(target: Dictionary, defaults: Dictionary) -> bool:
	# Dictionaries permit additive schema migration; existing scalars/arrays are
	# atomic author values. Never replace a deliberately edited array or number.
	var changed := false
	for key: Variant in defaults:
		if not target.has(key):
			target[key]=defaults[key].duplicate(true) if defaults[key] is Dictionary or defaults[key] is Array else defaults[key]
			changed=true
		elif target[key] is Dictionary and defaults[key] is Dictionary:
			changed=_fill_missing(target[key],defaults[key]) or changed
	return changed

func _preserves_values(current: Dictionary, before: Dictionary) -> bool:
	for key: Variant in before:
		if not current.has(key):return false
		if before[key] is Dictionary:
			if not current[key] is Dictionary or not _preserves_values(current[key],before[key]):return false
		elif current[key]!=before[key]:return false
	return true

func _component_additions(key: String) -> Dictionary:
	var timelines: Dictionary = assets.source_geometry.act03_crt1_hit_windows.timelines
	match key:
		"grab":
			return {
				"source_id":5679,"source_parent":99,
				"parent_matrix":assets.source_geometry.act03_crt1_actions.crt1_skill_v.parent_matrix.duplicate(),
				"timeline":timelines["5679"].active_by_source_frame.duplicate(true),
				"contact_helper_id":1234,"contact_source_frames":[6,7],"contact_frames":[7],"contact_destination":15,
				"contact_normal":true,"contact_superarmor":true,"contact_frozen":false,
				"fallback_frame":8,"fallback_gravity":-12.0,
				"normal_end_frame":14,"normal_end_x_transfer":-3.25,"transfer_uses_root_scale":false,
				"pren_start_frame":15,"pren_value":2,"zab_clear_frame":68,"pren_clear_frame":70,"end_frame":71,"idle_parent":30,
				"marker_helper_id":651,"marker_source_frames":[26,30,34,38,42,46,50,54,58,62,66,69],"marker_frames":[27,31,35,39,43,47,51,55,59,63,67,70],
				"marker_gravity":-0.3,"marker_penultimate_gravity":-0.1,"marker_final_gravity":-8.0,"marker_gacc_delta":0.1,"marker_gacc_reset_frame":67,"marker_gacc_reset_source_frame":66,"marker_gacc_reset_value":0.0,
				"anchor_helper_id":5652,"anchor_source_from":15,"anchor_source_until":67,"anchor_from":16,"anchor_until":67,"anchor_gravity_delta":-2.0,"anchor_gacc_delta":0.1,"anchor_uses_root_scale":false,
				"space":"timeline rectangles are5679 local; parent matrix applied once for hit geometry. Anchor/normal-end positions use source root coordinates with facing only, no actor scale.",
				"phase_note":"source_frames describe actual AS/XML; contact/marker/anchor observer frames retain the shared25Hz post-advance callback boundary. No CRT0 first-marker gacc-preservation special case is asserted for CRT1.",
			}
		"gunhawks":
			var helpers: Dictionary = {}
			var roots: Dictionary = {}
			var stages: Dictionary = {}
			for i in range(3):
				var id: int = [6771,6760,6752][i]
				helpers[str(id)]=timelines[str(id)].duplicate(true)
				stages[str(i+1)]={"helper_loop_frames":4,"helper_active_frames":[1,2],"helper_gravity":-5.0,"helper_marker_bonus":1.0 if i==2 else 0.0}
			for id: int in [6772,6764]:roots[str(id)]=timelines[str(id)].duplicate(true)
			roots["6753"]={"frame_count":49,"active_by_source_frame":{},"space":"6753 root local","inactive_source_frames":"All; original third gunhawk contains no6763 catch detector."}
			return {"helper_timelines":helpers,"root_timelines":roots,"stages":stages}
		"awakening":
			var phases: Dictionary = {}
			for frame: int in [25,43,66]:
				phases[str(frame)]={"source_id":5858,"loop_frames":4 if frame==66 else 5,"active_frames":[1,2],"gravity":-5.0 if frame==66 else -3.0,"marker_bonus":11.0 if frame==66 else 9.0,"hit_windows":_rectangles({"animation":"crt1_skill_t"},5881,frame,[5858]),"space":"actor local; original5881 parent matrix already applied once"}
			return {"phase_helpers":phases,"cutin":{"animation":"hud_crt1_t_cutin","position":[742.15,284.6],"start_frame":34,"end_frame":65,"trigger_frame":2},"death_release_source_frame":111}
		"moving_fire":return {"shot_gravity":-4.0,"marker2_bonus":12.0,"marker9_bonus":5.0}
	return {}

func _migrate_crt0_knockdown() -> void:
	var key := "crt0_knockdown"
	var row := {"animation":key,"source_parent":15,"sequence":assets.animations[key].source_frame_sequence.duplicate(),"input":"knockdown","cost":0.0,"cooldown_ticks":0,"source_id":4698,"source_entry_frame":2,"next_action":"idle","events":[],"windows":[],"source":"res/scripts/DefineSprite_6732/frame_15 + DefineSprite_4698/frame_30；actor parent15原旋转已烘在crt0_knockdown图集，不二次旋转。","calibration":"原根9敌人击倒令공중gotoAndPlay2，子30回玩家1。此处只生成作者动作，不修改crt_0角色注册。"}
	for sound: String in assets.audio_events:
		var source: Dictionary = assets.audio_events[sound]
		if int(source.sprite_id)==4698 and sound.begins_with(key):
			var event: Dictionary = source.duplicate(true)
			event.merge({"kind":"sound","sound":sound,"offset":float(source.get("in_point_samples_44100",0))/44100.0},true)
			row.events.append(event)
	helper.action("knockdown",row,assets,"res://content/actions/crt0/knockdown.tres")

func _row(id: String, animation: String, parent: int, cost := 0.0, cooldown := 0, input_id := "", cubes := 0) -> Dictionary:
	var a: Dictionary = assets.animations[animation]
	var row := {"animation":animation,"source_parent":parent,"sequence":a.source_frame_sequence.duplicate(),"input":input_id if not input_id.is_empty() else id,"cost":cost,"required_mp":cost,"cooldown_ticks":cooldown,"cubes":cubes,"allowed_states":base_states.duplicate(),"source_allowed_parent_frames":base_parents.duplicate(),"events":[],"windows":[],"source_id":int(a.source_sprite_id),"body_metadata":"act03_crt1_body","source":"res/scripts/DefineSprite_6732/frame_%d + DefineSprite_%d；父矩阵/选帧见asset_catalog.animations.%s" % [parent,int(a.source_sprite_id),animation],"calibration":"AS/XML静态证实帧、消耗、冷却和入口；原作伤害观察器相位及手感留待人工校准。"}
	row.events.append_array(helper.source_sounds(animation,assets,row.sequence))
	actions[id] = row
	return row

func _allow(row: Dictionary, parents: Array, states: Array) -> void:
	row.source_allowed_parent_frames = parents.duplicate()
	row.allowed_states = states.duplicate()

func _rectangles(row: Dictionary, source_id: int, frame: int, children: Array = [], depth := -1) -> Array:
	var result: Array = []
	var parent: Array = assets.source_geometry.act03_crt1_actions.get(row.animation,{}).get("parent_matrix",[1,0,0,1,0,0])
	var transform := Transform2D(Vector2(parent[0],parent[1]),Vector2(parent[2],parent[3]),Vector2(parent[4],parent[5]))
	var timeline: Dictionary = assets.source_geometry.act03_crt1_hit_windows.timelines.get(str(source_id),{})
	for data: Dictionary in timeline.get("active_by_source_frame",{}).get(str(frame),[]):
		if not children.is_empty() and int(data.source_id) not in children:continue
		if depth >= 0 and int(data.depth)!=depth:continue
		var r: Array = data.rect
		result.append(transform*Rect2(r[0],r[1],r[2],r[3]))
	return result

func _window(row: Dictionary, source_id: int, child: int, from_frame: int, until_frame: int, gravity: float, damage := 0.0, kind := "crt1_lift", depth := -1) -> void:
	var rectangles := _rectangles(row,source_id,from_frame,[child],depth)
	assert(not rectangles.is_empty(),"原判定没有对应矩形：%d/%d/%d"%[source_id,from_frame,child])
	row.windows.append({"from":from_frame,"until":until_frame,"kind":kind,"damage":damage,"gravity":gravity,"once_per_action":true,"local_rects":rectangles,"source_id":source_id,"helper_id":child,"source_depth":depth,"source_frame":from_frame,"source_geometry":"act03_crt1_hit_windows","source_matrix_applied":true,"calibration":"伤害字段仅本动作已知观察器贡献；公共marker分期另计。"})

func _line_events(row: Dictionary, source_id: int) -> void:
	var timeline: Dictionary = assets.source_geometry.act03_crt1_hit_windows.timelines[str(source_id)]
	var old_depths: Dictionary = {}
	for frame: int in row.sequence:
		var live: Dictionary = {}
		var added := false
		for item: Dictionary in timeline.active_by_source_frame.get(str(frame),[]):
			if int(item.source_id)!=4636:continue
			live[int(item.depth)] = true
			if not old_depths.has(int(item.depth)):added = true
		if added:row.events.append({"frame":frame,"kind":"crt1_line_shot","source_id":source_id,"helper_id":4636,"rectangles":_rectangles(row,source_id,frame,[4636]),"gravity":-5.0,"damage":0.0,"marker_frame":9,"source_matrix_applied":true,"damage_scope":"原4636碰撞写marker9/샷；实际扣血由原公共观察器及本动作额外观察器组合。"})
		old_depths = live

func _make_actions() -> void:
	var r := _row("idle","crt1_idle",30)
	r.loop = true
	r = _row("move","crt1_move",31)
	r.loop = true
	r.events.append({"frame":7,"kind":"sound","sound":"move"})
	var basics := [["basic","crt1_basic",37,8,10,"basic2"],["basic2","crt1_basic2",38,3,5,"basic3"],["basic3","crt1_basic3",39,3,5,"basic4"],["basic4","crt1_basic4",40,3,5,"basic5"],["basic5","crt1_basic5",41,6,0,""]]
	for spec: Array in basics:
		r = _row(spec[0],spec[1],spec[2],0,0,"attack")
		r.events.append({"frame":spec[3],"kind":"projectile","projectile":"projectile_strong"if spec[0]=="basic5"else"projectile","gravity":-5.0,"damage":5.0})
		if not str(spec[5]).is_empty():r.merge({"combo_from":spec[4],"combo_until":int(r.sequence[-1])-1,"combo_next":spec[5]},true)
	r = _row("jump","crt1_jump",96,0,0,"jump")
	r.controller = "crt1_jump"
	r.component = "jump"
	_allow(r,[30,31,32,33],["idle","move"])
	r = _row("down","crt1_down",43,0,0,"down")
	r.merge({"backstep":{"through_source_frame":11,"per_tick":-5.0,"end_source_frame":12,"end_child_x":-4.4},"body_clip_id":4673},true)
	r = _row("skill_z","crt1_skill_z",144,2,65,"skill_z")
	_allow(r,base_parents+[46],base_states+["skill"])
	r.merge({"body_clip_id":6334,"child_x_easing":{"initial":-2.2,"target":10.0,"divisor":2.0,"transfer_at":14},"source_timer":{"interval_ms":10,"duration_ms":500,"enemy_x_step":3.0,"all_airborne_targets":true,"refresh_each_active_callback":true}},true)
	_window(r,6335,1234,6,8,-15)
	r = _row("move_z","crt1_move_z",36,0,0,"skill_z")
	_allow(r,[31],["move"])
	r.merge({"source_movement":[{"from":7,"until":10,"per_tick":20.0},{"from":11,"until":14,"per_tick":10.0},{"from":15,"until":18,"per_tick":6.0},{"from":19,"until":22,"per_tick":4.0}],"body_x_easing":{"initial":4.7,"target":180.0,"divisor":6.0}},true)
	_window(r,4858,439,7,10,-5)
	r = _row("skill_a","crt1_skill_a",35,2,65,"skill_a")
	_allow(r,base_parents+[46],base_states+["skill"])
	r.child_x_easing = {"initial":-3.15,"target":10.0,"divisor":2.0,"transfer_at":0}
	_window(r,4851,4684,5,7,-3,45)
	r = _row("skill_s","crt1_skill_s",42,3,79,"skill_s")
	_allow(r,base_parents+[35,46],base_states+["skill_a","skill"])
	r.merge({"marker_bonus":20.0,"marker_bonus_from":6,"marker_bonus_until":17},true)
	r.events.append({"frame":7,"kind":"projectile","projectile":"projectile_rising","gravity":-12.0,"damage":5.0})
	r = _row("skill","crt1_skill_d",46,3,109,"skill")
	_allow(r,[30,31,32,33,36,37,38,39,40,41],base_states+["move_z"])
	r.merge({"controller":"crt1_d","normal_end_source_frame":11,"contact_start_frame":12,"contact_end_frame":29,"follow_key":"skill_z","follow_action":"d_follow","follow_from":12,"follow_until":28,"held_move_per_tick":5.0,"source_ignored_special_branch":{"frames":[30,37],"condition":"ring3"}},true)
	_window(r,4928,858,1,5,0,0,"crt1_d_contact")
	_window(r,4928,1234,12,13,-5,20)
	_window(r,4928,1234,19,20,-5,20)
	r = _row("d_follow","crt1_d_follow",47)
	r.merge({"controller":"crt1_d_follow","component":"d_follow","root_x_transfer_at_end":10.0},true)
	_window(r,4954,1234,1,2,-10,8,"crt1_lift",32)
	_window(r,4954,1234,1,2,-10,15,"crt1_lift",34)
	_window(r,4954,1234,5,6,-10,20,"crt1_lift",32)
	r = _row("skill_f","crt1_skill_f",48,3,169,"load_f")
	_allow(r,base_parents+[35,46],base_states+["skill_a","skill"])
	r.events.append({"frame":6,"kind":"crt1_head_projectile","projectile":"projectile_head","gravity":-5.0,"damage":30.0})
	r.events.append_array([{"frame":2,"kind":"root_offset","y":4},{"frame":3,"kind":"root_offset","y":-8},{"frame":4,"kind":"root_offset","y":0}])
	r = _row("skill_g","crt1_skill_g",111,3,174,"load_g")
	_allow(r,base_parents+[35,46],base_states+["skill_a","skill"])
	r.merge({"turn_on_start":true,"source_jump":{"1":2},"shot_marker_bonus":15.0},true)
	r.events.append({"frame":8,"kind":"crt1_head_projectile","projectile":"projectile_head","gravity":-5.0,"damage":30.0})
	r.events.append_array([{"frame":2,"kind":"root_offset","y":4},{"frame":3,"kind":"root_offset","y":-8},{"frame":4,"kind":"root_offset","y":0}])
	r = _row("skill_q","crt1_skill_q",49,5,599,"skill_q")
	r.events.append({"frame":11,"kind":"crt1_buff_start","component":"buff","buff_source_id":4592})
	r = _row("skill_h","crt1_skill_h",145,5,299,"load_h",1)
	_allow(r,base_parents+[35,46],base_states+["skill_a","skill"])
	r.merge({"controller":"crt1_h","direction_window_from":3,"direction_window_until":21,"chain_limit":5,"direction_actions":{"forward":"h_forward","back":"h_back","down":"h_down","up":"h_up"},"hh_increment_source_frame":0},true)
	for spec: Array in [["h_forward","crt1_h_forward",50,5114],["h_back","crt1_h_back",51,5116],["h_down","crt1_h_down",52,5122],["h_up","crt1_h_up",53,5123]]:
		r = _row(spec[0],spec[1],spec[2])
		r.merge({"controller":"crt1_h","direction_window_from":6,"direction_window_until":int(r.sequence[-1])-1,"chain_limit":5,"direction_actions":{"forward":"h_forward","back":"h_back","down":"h_down","up":"h_up"},"hh_increment_source_frame":2},true)
		_line_events(r,spec[3])
	r = _row("skill_w","crt1_w_idle",54,5,449,"skill_w",1)
	r.merge({"controller":"crt1_moving_fire","component":"moving_fire","hold":true,"hold_at":[1]},true)
	r = _row("skill_e","crt1_skill_e",55,5,560,"skill_e",1)
	_allow(r,base_parents+[35,46],base_states+["skill_a","skill"])
	r.merge({"cancel_input":"jump","marker_bonus":6.0,"marker_bonus_from":1,"marker_bonus_until":45},true)
	_line_events(r,5158)
	r = _row("skill_r","crt1_skill_r",56,5,699,"skill_r",2)
	_allow(r,base_parents+[35,46],base_states+["skill_a","skill"])
	r.events.append({"frame":3,"kind":"crt1_gunhawk","stage":1})
	for stage: int in [1,2]:
		r = _row("r_catch%d"%stage,"crt1_r_catch%d"%stage,56+stage)
		r.merge({"controller":"crt1_gunhawk_catch","stage":stage,"normal_end_source_frame":25,"follow_source_frame":26,"follow_inputs":["attack","skill_r"],"follow_from":5,"follow_until":24,"held_direction_turn":true},true)
		r.events.append({"frame":26,"kind":"crt1_gunhawk","stage":stage+1})
		r.events.append_array([{"frame":1,"kind":"root_offset","x":3},{"frame":2,"kind":"root_offset","x":-6},{"frame":3,"kind":"root_offset","x":0}])
	r = _row("revenger","crt1_revenger",63,5,265,"skill_z")
	r.cooldown_key = "revenger"
	_allow(r,[44],["hit"])
	_line_events(r,5177)
	r = _row("skill_v","crt1_skill_v",99,5,215,"skill_v")
	r.merge({"controller":"crt1_v","normal_end_source_frame":14,"grab_start_source_frame":15,"source_geometry":"act03_crt1_hit_windows","grab_source_id":5679,"grab_release_frame":68,"pren_clear_frame":70,"end_frame":71},true)
	r = _row("skill_t","crt1_skill_t",110,30,403,"skill_t",5)
	_allow(r,base_parents+[35,46],base_states+["skill_a","skill"])
	r.merge({"controller":"crt1_t","component":"awakening","hold_at":[25,43,66],"source_slot_id":4147,"ready_source_frame":405,"slot_start_frame":2,"slot_stop_on_use":true,"cooldown_after_finish":true,"normal_end_source_frame":96,"kill_branch_check_frame":94,"kill_branch_start_frame":97,"kill_branch_end_frame":120,"marker_bonus":2.0},true)
	_window(r,5881,1234,12,14,-10,100)
	_window(r,5881,1234,33,35,-12,40)
	_window(r,5881,1234,52,55,-15,40)
	r = _row("hit","crt1_hit",44)
	r.events.append({"frame":2,"kind":"sound","sound":"player_hit_fx"})
	r = _row("dead","crt1_dead",62)
	r.hold = true
	r.events.append({"frame":30,"kind":"stop_all_sounds"})
	r = _row("knockdown","crt1_knockdown",45)
	r.source_entry_frame = 2
	r.next_action = "idle"
