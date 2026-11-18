extends RefCounted
## One registry for assets and all playable/disabled content entries.
var assets: Dictionary = {}
var issues: Array[String] = []
var characters: Dictionary = {}
var stages: Dictionary = {}
var modes: Dictionary = {}
var difficulties: Dictionary = {}
var level_catalog: Dictionary = {}
var dialogues: Dictionary = {}
var intermissions: Dictionary = {}
var enemies: Dictionary = {}
var author_index: Resource
var stage_scenes: Dictionary = {}
var actor_scene: PackedScene
var enemy_scene: PackedScene
var routes: Dictionary = {}

func load_all(provided_index: Resource = null) -> bool:
	issues.clear()
	var path := "res://data/asset_catalog.json"
	if not FileAccess.file_exists(path):
		issues.append("资源目录缺失：" + path + "；请运行 tools/import_runtime_assets.py")
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		issues.append("资源目录 JSON 无效：" + path)
		return false
	assets = parsed
	for key: String in ["animations", "textures", "audio"]:
		if not assets.has(key):
			issues.append("资源目录缺少字段：" + key)
	if not issues.is_empty():
		return false
	for id: String in assets.animations:
		var anim: Dictionary = assets.animations[id]
		if not ResourceLoader.exists(str(anim.get("texture", ""))):
			issues.append("动画 %s 的图集不存在：%s" % [id, anim.get("texture", "")])
		if anim.get("frames", []).is_empty():
			issues.append("动画没有帧：" + id)
	for key: String in ["player_idle", "player_move", "player_basic", "player_hit", "player_skill", "enemy_idle", "enemy_move", "enemy_attack", "enemy_hit", "enemy_death", "projectile", "crt0_basic2", "crt0_basic3", "crt0_basic5", "crt0_basic6", "crt0_skill_s", "crt1_idle", "crt1_move", "crt1_basic", "crt1_hit", "crt1_skill_s", "projectile_rising", "projectile_strong", "boss7176_idle", "boss7176_move", "boss7176_attack", "boss7176_ranged", "boss7176_hit", "boss7176_evade", "boss7176_dead"]:
		if not assets.animations.has(key):
			issues.append("必要动画未登记：" + key)
	for key: String in ["enemy_air","boss7176_air","air_hit_marker","player_hit_fx","crt0_jump","crt0_jump_air","crt0_down","crt0_skill_z","crt0_move_z","projectile_diagonal"]:
		if not assets.animations.has(key):
			issues.append("必要浮空组件未登记："+key)
	for key: String in ["crt0_skill_a","crt0_skill_w","crt0_load_f","crt0_load_g","crt0_load_h","crt0_grenade_f","crt0_grenade_g","crt0_grenade_h","crt0_skill_q","crt0_skill_e","crt0_detonate","crt0_skill_r","crt0_skill_t","crt0_t_hold","crt0_skill_v","crt0_skill_y","crt0_y_focus","crt0_fire_floor","crt0_fire_spark","sniper_main","sniper_reticle","sniper_ammo","sniper_timer","sniper_glass","hud_y_cutin","enemy_frozen","status_shock","status_stun","status_sniper_hit"]:
		if not assets.animations.has(key):issues.append("ACT02必要动作未登记："+key)
	for key: String in ["training","battle_hud","battle_hud_feedback","source_ui","act02_hit_windows","default_skill_actions","enemy_status","sniper","y_summon","skill_cutin"]:
		if not assets.get("source_geometry",{}).has(key):issues.append("ACT02必要来源结构未登记："+key)
	for key: String in ["air_hit_markers","enemy_air_body"]:
		if not assets.get("source_geometry",{}).has(key):
			issues.append("必要浮空来源矩阵未登记："+key)
	for key: String in ["forest","title","training_map","training_ground","training_title","training_instructions"]:
		if not assets.textures.has(key) or not ResourceLoader.exists(str(assets.textures.get(key,{}).get("path",""))):
			issues.append("必要场景纹理缺失：" + key)
	for key: String in ["source_geometry","stage_2_placements","stage_4_placements"]:
		if not assets.has(key):
			issues.append("来源坐标资料缺失：" + key)
	if not issues.is_empty():
		return false
	var level_path := "res://data/level02_catalog.json"
	if not FileAccess.file_exists(level_path):
		issues.append("关卡依据目录缺失：" + level_path)
		return false
	var levels: Variant = JSON.parse_string(FileAccess.get_file_as_string(level_path))
	if not levels is Dictionary or not levels.has("stages") or not levels.has("enemies"):
		issues.append("关卡依据 JSON 无效：" + level_path)
		return false
	level_catalog = levels
	if not level_catalog.stages.has("root_6") or not level_catalog.enemies.has("goblin_7176"):
		issues.append("关卡依据缺少 root_6 或 goblin_7176")
		return false
	_build_content()
	_load_author_content(provided_index)
	return issues.is_empty()

func _load_author_content(provided_index: Resource = null) -> void:
	var path := "res://content/index.tres"
	if not ResourceLoader.exists(path):return # Explicit first conversion bootstrap only.
	author_index = provided_index if provided_index != null else load(path)
	if author_index == null:
		issues.append("作者内容索引无法读取："+path)
		return
	var registered := {}
	for group: String in ["characters","enemy_definitions"]:
		for definition: Resource in author_index.get(group):
			if definition == null:issues.append("作者索引包含空定义："+group);continue
			var id := group+":"+str(definition.identifier)
			if str(definition.identifier).is_empty() or registered.has(id):issues.append("作者定义ID为空或重复："+id)
			registered[id] = true
			var action_ids := {}
			for action: Resource in definition.actions:
				if action == null:issues.append("动作引用为空："+id);continue
				if action.identifier.is_empty() or action_ids.has(action.identifier):issues.append("动作ID为空或重复："+id+"/"+action.identifier)
				action_ids[action.identifier] = true
	if not issues.is_empty():return
	actor_scene = author_index.actor_scene
	enemy_scene = author_index.enemy_scene
	if author_index.flow != null:
		dialogues.merge(author_index.flow.dialogues.duplicate(true),true)
		intermissions.merge(author_index.flow.intermissions.duplicate(true),true)
		routes = author_index.flow.routes.duplicate(true)
	for definition: Resource in author_index.characters:
		characters[definition.identifier] = definition.apply_to(characters.get(definition.identifier,{}),assets)
	for definition: Resource in author_index.enemy_definitions:
		enemies[definition.identifier] = definition.apply_to(enemies.get(definition.identifier,{}),assets)
	for packed: PackedScene in author_index.stage_scenes:
		if packed == null:issues.append("作者场景索引含空引用");continue
		var layout := packed.instantiate()
		if layout.rules == null:
			issues.append("场景缺少规则资源："+packed.resource_path)
		else:
			if registered.has("stage:"+str(layout.rules.identifier)):
				issues.append("作者场景ID重复："+str(layout.rules.identifier))
				layout.free();continue
			registered["stage:"+str(layout.rules.identifier)] = true
			stages[layout.rules.identifier] = layout.to_runtime()
			stage_scenes[layout.rules.identifier] = packed
		layout.free()

func _build_content() -> void:
	modes = {
		"story": {"title": "冒险", "enabled": true, "first_stage": "root_2", "source": "角色选择后由难度按钮设置nan → 根帧2"},
		"training": {"title":"练习模式","enabled":true,"first_stage":"root_41","source":"3016设置crt0→根40→41"},
		"tower": {"title": "其他模式 · 待还原", "enabled": false, "reason": "入口已定位，玩法和场景尚未接入。"}}
	difficulties = {
		"expert":{"title":"Expert","nan":0,"enabled":true,"source_button":2000,"enemy_hp_multiplier":1.0},
		"master":{"title":"Master","nan":1,"enabled":true,"source_button":1994,"enemy_hp_multiplier":1.5},
		"king":{"title":"King","nan":2,"enabled":true,"source_button":1997,"enemy_hp_multiplier":2.0},
		"slayer":{"title":"Slayer","nan":3,"enabled":false,"source_button":2017,"reason":"需要原作难度解锁层；相关流程尚未还原。"},
		"beast":{"title":"Beast","nan":4,"enabled":false,"source_button":2019,"reason":"需要原作难度解锁层；相关流程尚未还原。"}}
	characters = {"crt_0": {"title": "角色编号 0", "enabled": true, "source_crt": 0,
		"max_hp": 100.0, "max_mp": 100.0, "move_per_tick": 6.0,
		"actions": {
			"idle": {"animation": "player_idle", "loop": true},
			"move": {"animation": "player_move", "loop": true,"events":[_sound("move")]},
			"basic": {"animation": "player_basic", "sequence": [1,2,3,6,7,8,9,10,11,12,13,14,15,16,17,18,19],"source_jump":{"4":6},"combo_from":10,"combo_until":18,"combo_next":"basic2", "events": [_sound("basic"),_projectile(8)]},
			"basic2":{"animation":"crt0_basic2","sequence":range(1,14),"combo_from":5,"combo_until":12,"combo_next":"basic3","events":[_sound("crt0_basic2"),_projectile(3)]},
			"basic3":{"animation":"crt0_basic3","sequence":range(1,14),"combo_from":5,"combo_until":12,"combo_next":"basic4","events":[_sound("crt0_basic3"),_projectile(3)]},
			"basic4":{"animation":"crt0_basic3","sequence":range(14,27),"combo_from":18,"combo_until":25,"combo_next":"basic5","events":[_sound("crt0_basic3",15),_projectile(16)]},
			"basic5":{"animation":"crt0_basic5","sequence":range(1,14),"combo_from":5,"combo_until":12,"combo_next":"basic6","events":[_sound("crt0_basic5"),_projectile(3)]},
			"basic6":{"animation":"crt0_basic6","sequence":range(1,21),"events":[_sound("crt0_basic6_charge"),_sound("crt0_basic6"),_projectile(6,"projectile_strong")]},
			"skill": {"animation": "player_skill", "cost": 5.0,"cooldown_ticks":125,"input":"skill", "sequence": range(1,23),"allowed_states":["idle","move","basic","basic2","basic3","basic4","basic5","basic6","hit"], "windows": [{"from":8,"until":18,"kind":"skill_hit","damage":75.0,"gravity":-5.0,"damage_scope":"shared marker frame2; airborne marker3 is separate"}], "events":[_sound("skill"),_sound("skill_fire")]},
			"skill_s":{"animation":"crt0_skill_s","cost":3.0,"cooldown_ticks":79,"input":"skill_s","sequence":[1,2,3,4,6,7,8,9,10,11,12,13,14,15,16,17],"allowed_states":["idle","move","basic","basic2","basic3","basic4","basic5","basic6"],"source_allowed_parent_frames":[1,2,3,4,7,8,9,10,16],"events":[_sound("crt0_skill_s_charge"),_sound("crt0_skill_s"),_projectile(7,"projectile_rising",-12.0)]},
			"hit": {"animation": "player_hit","events":[_sound("player_hit_fx")]},
			"dead": {"animation": "player_hit", "hold": true}
		}},
		"crt_1":{"title":"角色编号 1","enabled":true,"source_crt":1,"max_hp":100.0,"max_mp":100.0,"move_per_tick":6.0,
		"actions":{
			"idle":{"animation":"crt1_idle","loop":true},
			"move":{"animation":"crt1_move","loop":true,"events":[_sound("move")]},
			"basic":{"animation":"crt1_basic","sequence":range(1,19),"events":[_sound("crt1_basic"),_projectile(8)]},
			"skill_s":{"animation":"crt1_skill_s","cost":3.0,"cooldown_ticks":79,"input":"skill_s","sequence":range(1,18),"allowed_states":["idle","move","basic"],"source_allowed_parent_frames":[30,31,32,33,35,37,38,39,40,41,46],"marker_bonus":20.0,"marker_bonus_from":6,"marker_bonus_until":17,"events":[_sound("crt1_skill_s_charge"),_sound("crt1_skill_s"),_projectile(7,"projectile_rising",-12.0)]},
			"hit":{"animation":"crt1_hit","events":[_sound("player_hit_fx")]},
			"dead":{"animation":"crt1_hit","hold":true}
		}}}
	for index in range(2,6):
		characters["crt_%d" % index] = {"title":"角色编号 %d · 待还原" % index,"enabled":false,"source_crt":index,"reason":"选择编号已确认，动作与能力尚未接入。"}
	stages = {
		"root_2": {"title":"哥布林之森 · 第一场", "source_root_frame":2, "enemy_count":1,
			"player_position":[129.35,312.9], "enemy_positions":[[411.2,363.7]], "next_stage":"root_4",
			"end_source":"计数4413到2 → 对话7009帧10 → Space → 根帧3 → 根帧4",
			"bounds":[35.0,520.0],"player_scale":[0.6369171,0.65245056],"enemy_scale":[0.52941895,0.51246643],"floor_y":360.15,"enemy_type":"goblin_4030","enemy_hp":200,"reward":100,"reward_by_difficulty":_difficulty_rewards([100,120,150,170,200]),"music":"battle","open_dialogue":"root_2_open","clear_dialogue":"root_2_clear"},
		"root_4": {"title":"哥布林之森 · 第二场", "source_root_frame":4, "enemy_count":4,
			"player_position":[273.35,314.9], "enemy_positions":[[494.9,363.7],[411.45,363.7],[168.5,363.7],[50.4,363.7]],
			"next_stage":"root_6", "end_source":"计数4413到5 → 7142帧2..7 → 根5 → 根6",
			"bounds":[35.0,520.0],"player_scale":[0.6369171,0.65245056],"enemy_scale":[0.52941895,0.51246643],"floor_y":360.15,"enemy_type":"goblin_4030","enemy_hp":200,"reward":100,"reward_by_difficulty":_difficulty_rewards([100,120,150,170,200]),"music":"battle","clear_dialogue":"root_4_clear"}}
	# Exact extracted placements override only layout; gameplay remains explicit.
	for id: String in stages:
		var placement: Dictionary = assets["stage_%d_placements" % int(stages[id].source_root_frame)]
		stages[id].player_position = placement.player.position.duplicate()
		stages[id].player_scale = placement.player.scale.duplicate()
		var enemy_placements: Array = placement.get("enemies",[placement.get("enemy",{})])
		stages[id].enemy_positions = enemy_placements.map(func(e:Dictionary)->Array:return e.position.duplicate())
		stages[id].enemy_scale = enemy_placements[0].scale.duplicate()
		stages[id].enemy_count = enemy_placements.size()
	var stage6: Dictionary = level_catalog.stages.root_6.duplicate(true)
	stage6.merge({"title":"哥布林之森 · 十夫长","next_stage":"root_7","bounds":[35.0,520.0],"enemy_count":1,"enemy_hp":400.0,"reward":300,"reward_by_difficulty":_difficulty_rewards([300,350,400,450,550]),"music":"battle","end_source":"7192对话帧2..8 → 7191帧35 → 根7结算"},true)
	stages["root_6"] = stage6
	var training: Dictionary = assets.stage_41_placements
	stages["root_41"] = {"title":"STAGE0 - 练习模式","source_root_frame":41,"training":true,
		"background":"training_map","ground_texture":"training_ground","music":"training",
		"player_position":training.player.position.duplicate(),"player_scale":training.player.scale.duplicate(),
		"player_depth":int(training.player.depth),"enemy_depths":training.enemies.map(func(e:Dictionary)->int:return int(e.depth)),
		"enemy_positions":training.enemies.map(func(e:Dictionary)->Array:return e.position.duplicate()),
		"enemy_scale":training.enemies[0].scale.duplicate(),"enemy_count":1,"enemy_type":"goblin_4030",
		"enemy_hp":1e22,"player_max_hp":130.0,"player_max_mp":130.0,"floor_y":360.15,"bounds":[0.0,550.0],
		"ground_rect":assets.source_geometry.training.ground.stage_rect.duplicate(),
		"reward":0,"next_stage":"","player_hurt_observers":[2.0],"difficulty_observer":false,
		"end_source":"训练根41没有남은수/难度实例，无普通胜利推进；6917失败→角色父29/重试40"}
	# Effective root display lists in game.xml; root2 combo4679 survives4/6/41.
	var layouts := {
		"root_2":{"player":909,"enemies":[222],"ground":686,"y":703,"sniper":2625,"skills":472,"hp":696,"mp":694,"hud":2723},
		"root_4":{"player":1652,"enemies":[224,705,1142,1389],"ground":688,"y":952,"sniper":3368,"skills":474,"hp":698,"mp":696,"hud":3466},
		"root_6":{"player":933,"enemies":[458],"ground":441,"y":743,"sniper":2651,"skills":227,"hp":451,"mp":449,"hud":2749},
		"root_41":{"player":801,"enemies":[111],"ground":781,"y":358,"sniper":2525,"skills":567,"hp":791,"mp":789,"hud":2623}}
	for stage_id: String in layouts:
		var layout: Dictionary = layouts[stage_id]
		stages[stage_id]["source_depths"] = layout
		stages[stage_id]["player_depth"] = int(layout.player)
		stages[stage_id]["enemy_depths"] = layout.enemies.duplicate()
		#4393 has identical placement/color transform in all four source stages.
		stages[stage_id]["ground_texture"] = "training_ground"
		stages[stage_id]["ground_rect"] = assets.source_geometry.training.ground.stage_rect.duplicate()
	# Damage listeners belong to placed root clips, not only the shared sprite ID.
	# Root4 contains four persistent observers of2, including internally dead clips.
	stages.root_2["player_hurt_observers"] = [10.0]
	stages.root_4["player_hurt_observers"] = [2.0,2.0,2.0,2.0]
	stages.root_6["player_hurt_observers"] = [3.5]
	dialogues = level_catalog.get("dialogues",{}).duplicate(true)
	intermissions = level_catalog.get("intermissions",{}).duplicate(true)
	if intermissions.has("intermission_7"):
		intermissions["root_7"] = intermissions.intermission_7.duplicate(true)
	_build_enemies()
	_extend_m1_actions()
	_extend_act02_actions()

func _extend_act02_actions() -> void:
	var actions: Dictionary = characters.crt_0.actions
	var b := ["idle","move","basic","basic2","basic3","basic4","basic5","basic6"]
	var specs := {
		"skill_a":["crt0_skill_a",113,range(21,31),7.0,65],
		"skill_w":["crt0_skill_w",113,range(1,11),7.0,269],
		"load_f":["crt0_load_f",114,range(1,16),5.0,0],
		"load_g":["crt0_load_g",115,range(1,16),5.0,0],
		"load_h":["crt0_load_h",116,range(1,16),5.0,0],
		"skill_q":["crt0_skill_q",18,range(1,9)+range(12,31),8.0,299],
		"skill_e":["crt0_skill_e",21,range(3,14),0.0,0],
		"detonate":["crt0_detonate",22,range(1,22),7.0,359],
		"skill_r":["crt0_skill_r",23,range(1,44),12.0,659],
		"skill_v":["crt0_skill_v",98,range(1,72),5.0,217],
		"skill_y":["crt0_skill_y",24,range(1,41),30.0,0],
		"y_focus":["crt0_y_focus",25,range(1,39),0.0,0],
		"skill_t":["crt0_skill_t",20,range(1,7),15.0,800],
		"throw_f":["crt0_grenade_f",19,range(123,181),0.0,0],
		"throw_g":["crt0_grenade_g",19,range(185,244),0.0,0],
		"throw_h":["crt0_grenade_h",19,range(5,119),0.0,0]}
	for id: String in specs:
		var spec: Array = specs[id]
		if not assets.animations.has(spec[0]):continue
		actions[id] = {"animation":spec[0],"source_parent":spec[1],"sequence":spec[2],"cost":spec[3],"cooldown_ticks":spec[4],"allowed_states":b.duplicate(),"events":_source_sounds(spec[0])}
	if actions.has("skill_a"):actions.skill_a.events.append({"frame":25,"kind":"summon","summon":"runner"})
	if actions.has("skill_w"):actions.skill_w.events.append({"frame":5,"kind":"summon","summon":"mine"})
	for kind: String in ["f","g","h"]:
		if actions.has("load_"+kind):actions["load_"+kind].events.append({"frame":13,"kind":"grenade_load","grenade":kind})
	if actions.has("skill_q"):
		actions.skill_q["hold_at"] = [12]
		actions.skill_q["body_track"] = "crt0_skill_q"
		actions.skill_q.events.append_array([{ "frame":13,"kind":"ammo_start","ammo":"fire"},{"frame":22,"kind":"ammo_start","ammo":"silver"},{"frame":21,"kind":"return_idle"}])
	for id: String in ["skill_r","detonate","skill_y","skill_t"]:
		if actions.has(id):actions[id]["cubes"] = {"skill_r":1,"detonate":1,"skill_y":5,"skill_t":2}[id]
	if actions.has("skill_e"):
		actions.skill_e.events.append_array([{ "frame":6,"kind":"c4_place"},{"frame":12,"kind":"c4_hold_detonate"}])
		actions.skill_e["windows"] = [{"from":7,"until":9,"kind":"c4_hit"}]
	if actions.has("detonate"):
		actions.detonate.events.append_array([{ "frame":5,"kind":"c4_flash"},{"frame":12,"kind":"c4_explode"},{"frame":20,"kind":"c4_clear"}])
	if actions.has("skill_r"):
		actions.skill_r.events.append_array([{ "frame":25,"kind":"summon","summon":"fire_floor"},{"frame":25,"kind":"root_offset","y":10},{"frame":26,"kind":"root_offset","y":-10},{"frame":27,"kind":"root_offset","y":0}])
		actions.skill_r["windows"] = [{"from":26,"until":42,"kind":"physical_window","source_id":4798,"gravity":-12.0}]
	if actions.has("skill_t"):
		actions.skill_t["hold_at"] = [6]
		actions.skill_t["hold"] = true
		actions.skill_t.events.append({"frame":5,"kind":"sniper_start"})
	if actions.has("y_focus"):
		actions.y_focus["hold_at"] = [38]
		actions.y_focus["hold"] = true
		actions.y_focus.events.append({"frame":33,"kind":"y_phase","phase":3})
	if actions.has("skill_y"):actions.skill_y.events.append_array([{ "frame":9,"kind":"y_cutin"},{"frame":25,"kind":"y_phase","phase":2}])
	for kind: String in ["f","g","h"]:
		if not actions.has("throw_"+kind):continue
		var action: Dictionary = actions["throw_"+kind]
		action["windows"] = [{"from":int(action.sequence[0]),"until":int(action.sequence[-1]),"kind":"grenade_window","grenade":kind}]
		var ends: Array = {"f":[147,158,169,180],"g":[210,221,232,243],"h":[43,68,93,118]}[kind]
		for frame: int in ends:action.events.append({"frame":frame,"kind":"return_idle"})
	for character_id: String in ["crt_0","crt_1"]:
		var animation := "crt0_dead" if character_id == "crt_0" else "crt1_dead"
		if assets.animations.has(animation):
			characters[character_id].actions.dead = {"animation":animation,"source_parent":29 if character_id == "crt_0" else 62,"sequence":range(1,31),"hold":true,"events":_source_sounds(animation)+[{"frame":30,"kind":"source_stop_sounds"}]}

func _source_sounds(prefix: String) -> Array:
	var events: Array = []
	for id: String in assets.audio_events:
		if id == prefix or id.begins_with(prefix+"_sound_"):events.append(_sound(id))
	return events

func _extend_m1_actions() -> void:
	var actions: Dictionary = characters.crt_0.actions
	actions["jump"] = {"animation":"crt0_jump","sequence":range(1,36),"source_parent":95,
		"body_track":"crt0_jump","events":[_sound("crt0_jump_takeoff"),_sound("crt0_jump_land")]}
	actions["down"] = {"animation":"crt0_down","sequence":range(1,13),"source_parent":12,
		"body_track":"crt0_down","windows":[{"from":2,"until":11,"kind":"root_motion","dx":-5.0}],
		"events":[_sound("crt0_down_start"),_sound("crt0_down_end"),{"frame":12,"kind":"root_motion","dx":-3.0}]}
	actions["skill_z"] = {"animation":"crt0_skill_z","sequence":range(1,15),"source_parent":5,
		"cost":3.0,"cooldown_ticks":65,"body_absent":true,
		"allowed_states":["idle","move","basic","basic2","basic3","basic4","basic5","basic6","hit"],
		"events":[_sound("crt0_z_swing"),_sound("crt0_z_effect"),{"frame":14,"kind":"z_finish"}],
		"windows":[{"from":7,"until":8,"kind":"z_lift","gravity":-15.0,"timer":true}]}
	actions["move_z"] = {"animation":"crt0_move_z","sequence":range(1,23),"source_parent":6,
		"events":[_sound("crt0_move_z")],"windows":[
			{"from":7,"until":10,"kind":"root_motion","dx":20.0},
			{"from":11,"until":14,"kind":"root_motion","dx":10.0},
			{"from":15,"until":18,"kind":"root_motion","dx":6.0},
			{"from":19,"until":22,"kind":"root_motion","dx":4.0},
			{"from":8,"until":10,"kind":"z_lift","gravity":-5.0,"timer":false}]}
	var parents := {"idle":1,"move":2,"basic":7,"basic2":8,"basic3":9,"basic4":9,"basic5":16,"basic6":10,"skill":13,"skill_s":11,"hit":14}
	for id: String in parents:
		actions[id]["source_parent"] = parents[id]
	for id: String in {"idle":30,"move":31,"basic":37,"skill_s":42,"hit":44}:
		characters.crt_1.actions[id]["source_parent"] = {"idle":30,"move":31,"basic":37,"skill_s":42,"hit":44}[id]
	for id: String in enemies:
		var enemy: Dictionary = enemies[id]
		enemy.actions["recover"] = {"animation":enemy.actions.move.animation,"sequence":[1,2,3],"parent_sequence":[2,3,4],"next_action":"idle"}
		enemy.actions.idle["source_parent"] = 1
		enemy.actions.move["source_parent"] = 2
		enemy.actions.attack["parent_from_source_frame"] = true
		enemy.actions.attack["next_action"] = "recover"
		enemy.actions.hit["parent_from_source_frame"] = true
		if id == "goblin_7176":
			enemy.actions.hit["next_action"] = "recover"
			enemy.actions.ranged["parent_from_source_frame"] = true
			enemy.actions.ranged["next_action"] = "recover"
			enemy.actions.evade["source_parent"] = 111
			enemy.actions.evade["next_action"] = "recover"
			enemy.actions.dead["source_parent"] = 112
		else:
			enemy.actions.dead["source_parent"] = 64

func _build_enemies() -> void:
	enemies = {"goblin_4030":{"max_hp":200.0,"max_mp":0.0,"move_per_tick":2.0,"source_id":4030,"source_facing":-1,
		"movement_status":"已确认仅移动触发区相交时每源tick移动2；mobsp分支未确认，不能全程追逐",
		"move_condition":"player gravity body intersects move_rect while source trigger exists",
		"move_rect":[-392.9,-184.15,388.4,206.05],"move_source_frames":[1,2,3],
		"proximity_rect":[-52.95,-160.25,104.85,172.45],"ranged_rect":[],
		"hurt_rect":[-55.96760495,-173.622184095,104.77960371,172.400006745],
		"reward_by_difficulty":_difficulty_rewards([100,120,150,170,200]),"airborne_drift_per_tick":0.8,
		"actions": {
			"idle":{"animation":"enemy_idle","loop":true},
			"move":{"animation":"enemy_move","loop":true},
			"attack":{"animation":"enemy_attack","windows":[{"from":26,"until":28,"kind":"enemy_hit","damage":10.0,"knockback":10.0}],"events":[_sound("enemy_attack")]},
			"hit":{"animation":"enemy_hit"},
			"dead":{"animation":"enemy_death","hold":true,"events":[{"frame":3,"kind":"death_settled"},_sound("death")]}}}}
	var boss: Dictionary = level_catalog.enemies.goblin_7176.duplicate(true)
	boss["max_hp"] = float(boss.hp)
	boss["max_mp"] = 0.0
	boss["reward_by_difficulty"] = _difficulty_rewards([300,350,400,450,550])
	boss["movement_status"] = "已确认移动区相交时每源tick移动3；非无条件追逐"
	for action_id: String in boss.actions:
		var action: Dictionary = boss.actions[action_id]
		action["sequence"] = action.get("source_frames",[]).duplicate()
		if action_id == "dead":
			action["hold"] = true
		var events: Array = []
		for event: Dictionary in action.get("events",[]):
			if str(event.kind) == "sound":
				events.append(_sound("boss7176_death" if action_id == "dead" else "boss7176_attack",int(event.frame)))
			else:
				events.append(event.duplicate(true))
		action["events"] = events
	enemies["goblin_7176"] = boss
	enemies.goblin_4030["hurt_child_seek"] = 0
	enemies.goblin_7176["hurt_child_seek"] = 2
	for id: String in enemies:
		# Both outer frame2 clips place4029 at(115,-1827)twips;
		# 4029 places1119 at(25,194), scale(.9993286,.9997101).
		enemies[id]["air_hurt_rect"] = [-41.21760495,-177.572184095,104.77960371,172.400006745]
		enemies[id]["air_animation"] = "enemy_air" if id == "goblin_4030" else "boss7176_air"

func enemy_definition(id: String = "goblin_4030") -> Dictionary:
	if not enemies.has(id):
		push_error("敌人未登记：" + id)
		return {}
	return enemies[id].duplicate(true)

func _sound(id: String, frame: int = -1) -> Dictionary:
	var sources: Dictionary = assets.get("audio_events",{})
	if not sources.has(id):
		issues.append("音效事件未登记：" + id)
		return {"frame":frame,"kind":"sound","sound":id}
	var event: Dictionary = sources[id].duplicate(true)
	event["kind"] = "sound"
	event["sound"] = id
	event["offset"] = float(event.get("in_point_samples_44100",0)) / 44100.0
	if frame >= 0:
		event["frame"] = frame
	return event

func _projectile(frame: int, animation: String = "projectile", gravity: float = -5.0) -> Dictionary:
	return {"frame":frame,"kind":"projectile","projectile":animation,"gravity":gravity,"damage":5.0,"damage_scope":"shared marker frame2; airborne marker3 is separate"}

func _difficulty_rewards(values: Array) -> Dictionary:
	return {"expert":int(values[0]),"master":int(values[1]),"king":int(values[2]),"slayer":int(values[3]),"beast":int(values[4])}
