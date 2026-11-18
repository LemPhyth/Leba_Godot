extends CanvasLayer
## UI displays caller-owned state and emits intentions; it owns no game values.
signal intent(action: String, value: Variant)
const SourceHUD = preload("res://scripts/ui/source_hud.gd")
const SourceMenu = preload("res://scripts/ui/source_menu.gd")
var source_hud: Node2D
var source_menu: Control
var root: Control
var catalog: Dictionary
var _hp: ProgressBar
var _mp: ProgressBar
var _status: Label
var _enemy: Label
var _hint: Label
var _debug: Label
var _toast: Label
var _lab_hint: Label
var _toast_time := 0.0
var theme_resource: Theme

func configure(assets: Dictionary) -> void:
	catalog = assets
	layer = 10
	root = Control.new()
	root.name = "UI"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	theme_resource = Theme.new()
	theme_resource.default_font_size = 13
	var system := SystemFont.new()
	system.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","Noto Sans CJK SC"])
	var fonts: Dictionary = assets.get("fonts",{})
	var font_path: Variant = fonts.get("ui","")
	if font_path is Dictionary:
		font_path = font_path.get("path","")
	if not str(font_path).is_empty() and ResourceLoader.exists(str(font_path)):
		var source_font: Font = load(str(font_path)).duplicate()
		# Extracted subset has some nonstandard punctuation glyph mappings.
		# Native CJK UI text first, retained source subset for fallback glyphs.
		system.fallbacks = [source_font]
		theme_resource.default_font = system
	else:
		theme_resource.default_font = system
	root.theme = theme_resource
	for type: String in ["Button", "OptionButton"]:
		theme_resource.set_stylebox("normal",type,_style(Color("262235"),Color("625775")))
		theme_resource.set_stylebox("hover",type,_style(Color("403050"),Color("e5b86d")))
		theme_resource.set_stylebox("pressed",type,_style(Color("5b3c61"),Color("f3dba2")))
		theme_resource.set_stylebox("disabled",type,_style(Color("171920"),Color("32313d")))
		theme_resource.set_stylebox("focus",type,_style(Color(0,0,0,0),Color("f2cb83")))
		theme_resource.set_color("font_color",type,Color("f4e9d6"))
		theme_resource.set_color("font_disabled_color",type,Color("77727e"))

func _style(fill: Color, outline: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = outline
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	return style

func clear() -> void:
	root.position = Vector2.ZERO
	source_menu = null
	if is_instance_valid(source_hud):
		source_hud.get_parent().remove_child(source_hud)
		source_hud.queue_free()
		source_hud = null
	for child: Node in root.get_children():
		root.remove_child(child)
		child.queue_free()
	_hp = null
	_mp = null
	_status = null
	_enemy = null
	_hint = null
	_toast = null
	_lab_hint = null
	_debug = null
	_toast_time = 0.0

func _label(text: String, at: Vector2, width: float, size := 14) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = Vector2(width,26)
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("eee8dc"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)
	return label

func _panel(at: Vector2, size: Vector2, opacity := 0.96) -> Panel:
	var panel := Panel.new()
	panel.position = at
	panel.size = size
	panel.add_theme_stylebox_override("panel",_style(Color(0.07,0.075,0.10,opacity),Color("554b61")))
	root.add_child(panel)
	return panel

func _button(id: String, text: String, at: Vector2, size: Vector2, action: String, payload: Variant = null, enabled := true) -> Button:
	var button := Button.new()
	button.name = id
	button.text = text
	button.position = at
	button.size = size
	button.disabled = not enabled
	button.pressed.connect(func():intent.emit(action,payload))
	root.add_child(button)
	return button

func _background() -> void:
	var background := TextureRect.new()
	background.texture = load(str(catalog.textures.title.path)) as Texture2D
	background.size = Vector2(550,265)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	var shade := ColorRect.new()
	shade.size = Vector2(550,400)
	shade.color = Color(0.025,0.03,0.04,0.85)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

func show_title(profile: Dictionary, save_message: String) -> void:
	clear()
	var base := ColorRect.new()
	base.size = Vector2(550,400)
	base.color = Color("11121a")
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(base)
	var image := TextureRect.new()
	image.texture = load(str(catalog.textures.title.path)) as Texture2D
	image.size = Vector2(550,265)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(image)
	_panel(Vector2(130,234),Vector2(290,152))
	_label("雷巴的冒险 EX · 还原版",Vector2(162,242),260,17)
	_button("Start","开始冒险",Vector2(175,273),Vector2(200,30),"adventure")
	_button("Training","练习模式 · 角色0",Vector2(175,307),Vector2(200,30),"training")
	_label("金币 %d" % int(profile.progress.gold),Vector2(173,341),260,11)
	_label(save_message,Vector2(145,361),270,10)

func show_modes(modes: Dictionary, profile: Dictionary) -> void:
	clear()
	_background()
	_panel(Vector2(65,45),Vector2(420,320))
	_label("选择模式",Vector2(90,62),350,24)
	var row := 0
	for id: String in modes:
		var mode: Dictionary = modes[id]
		var button := _button("Mode_"+id,str(mode.title),Vector2(90,112+row*52),Vector2(370,40),"select_mode",id,bool(mode.enabled))
		button.tooltip_text = str(mode.get("reason",mode.get("source","")))
		row += 1
	_label("冒险流程：选择角色 → 选择难度。\n其他模式暂未接入。",Vector2(92,225),365,12)
	_label("音量",Vector2(92,282),70,12)
	var volume := HSlider.new()
	volume.name = "Volume"
	volume.position = Vector2(155,283)
	volume.size = Vector2(190,22)
	volume.min_value = 0
	volume.max_value = 1
	volume.step = 0.05
	volume.value = float(profile.settings.volume)
	volume.value_changed.connect(func(v:float):intent.emit("volume",v))
	root.add_child(volume)
	_button("Back","返回",Vector2(90,322),Vector2(90,28),"title")

func show_characters(characters: Dictionary, selected: String) -> void:
	clear()
	_background()
	_panel(Vector2(35,30),Vector2(480,345))
	_label("选择角色",Vector2(55,43),400,24)
	var index := 0
	for id: String in characters:
		var character: Dictionary = characters[id]
		var title: String = str(character.title)
		if id == selected:
			title += "  ✓"
		var button := _button("Character_"+id,title,Vector2(55+(index%2)*225,92+(index/2)*52),Vector2(215,42),"select_character",id,bool(character.enabled))
		button.tooltip_text = str(character.get("reason","选择此角色，继续选择难度。"))
		index += 1
	_label("← → 移动  ·  X 普通攻击 / 连段\n角色0：C跳跃、↓后撤、Z/S/D  ·  角色1：S\nEsc 暂停 / 返回   F3 调试信息",Vector2(58,253),435,12)
	_button("Back","返回标题",Vector2(55,323),Vector2(105,32),"title")
	_button("Store","商店 / 装备",Vector2(170,323),Vector2(125,32),"shop")
	_button("Begin","选择难度",Vector2(305,323),Vector2(190,32),"begin")

func show_difficulty(difficulties: Dictionary, profile: Dictionary) -> void:
	clear()
	_background()
	_panel(Vector2(65,30),Vector2(420,345))
	_label("选择难度",Vector2(90,45),350,24)
	var selected := str(profile.get("selection",{}).get("difficulty_id","expert"))
	var row := 0
	for id: String in ["expert","master","king"]:
		var difficulty: Dictionary = difficulties.get(id,{})
		var title := str(difficulty.get("title",id.capitalize()))
		if id == selected:
			title += "  ✓"
		var button := _button("Difficulty_"+id,title,Vector2(90,94+row*47),Vector2(370,37),"select_difficulty",id,bool(difficulty.get("enabled",false)))
		button.tooltip_text = str(difficulty.get("reason","选择后进入冒险。"))
		row += 1
	_label("Slayer / Beast：尚未开放\n高难度的解锁与后续流程仍待还原。",Vector2(92,240),365,12)
	_label("音量",Vector2(92,296),60,12)
	var volume := HSlider.new()
	volume.name = "Volume"
	volume.position = Vector2(151,297)
	volume.size = Vector2(250,22)
	volume.min_value = 0
	volume.max_value = 1
	volume.step = 0.05
	volume.value = float(profile.get("settings",{}).get("volume",0.65))
	volume.value_changed.connect(func(v:float):intent.emit("volume",v))
	root.add_child(volume)
	_button("Back","返回选人",Vector2(90,331),Vector2(110,29),"characters")

func show_shop(profile: Dictionary, character_id: String, message: String = "") -> void:
	clear()
	_background()
	_panel(Vector2(35,25),Vector2(480,350))
	_label("商店 / 装备",Vector2(55,40),330,24)
	var gold := int(profile.get("progress",{}).get("gold",0))
	var owned := int(profile.get("inventory",{}).get("haring",0)) == 1
	var rings: Dictionary = profile.get("equipment",{}).get("rings",{})
	var equipped := int(rings.get(character_id,0)) == 1
	var any_equipped := false
	for id: String in ["crt_0","crt_1","crt_2","crt_3"]:
		any_equipped = any_equipped or int(rings.get(id,0)) == 1
	_label("金币 %d" % gold,Vector2(365,48),135,14)
	_label("HP +10 戒指",Vector2(57,91),390,20)
	_label("购买 3000 金币  ·  出售 600 金币",Vector2(57,125),400,13)
	_label("库存：%s    当前角色 %s：%s" % ["持有" if owned else "未持有",character_id.trim_prefix("crt_"),"已装备" if equipped else "未装备"],Vector2(57,155),425,13)
	_button("Buy","购买",Vector2(55,195),Vector2(102,33),"shop_action","buy",not owned and gold >= 3000)
	_button("Equip","装备",Vector2(168,195),Vector2(102,33),"shop_action","equip",owned and not equipped)
	_button("Unequip","卸下",Vector2(281,195),Vector2(102,33),"shop_action","unequip",any_equipped)
	_button("Sell","出售",Vector2(394,195),Vector2(102,33),"shop_action","sell",owned)
	_label("原作规则：出售保留已装备效果；卸下会清除四个\n角色的此戒指装备，并将戒指放回库存。",Vector2(57,240),430,12)
	var feedback := _label(message,Vector2(57,284),430,12)
	feedback.name = "ShopMessage"
	_button("Back","返回选人",Vector2(55,331),Vector2(125,29),"characters")

func show_intro(stage: Dictionary) -> void:
	clear()
	_background()
	_panel(Vector2(60,75),Vector2(430,255))
	_label(str(stage.title),Vector2(84,94),390,23)
	_label("敌人：%d\n\n← → 移动  ·  X 普通攻击 / 连段\n技能按键与可用状态见战斗界面。\nEsc 打开菜单。" % int(stage.get("enemy_count",1)),Vector2(85,140),380,13)
	_button("Back","返回选择",Vector2(85,279),Vector2(130,32),"characters")
	_button("EnterBattle","进入战斗",Vector2(260,279),Vector2(200,32),"enter")

func show_dialogue(dialogue: Dictionary, page_index: int) -> void:
	clear()
	# The battle remains caller-owned beneath this overlay, including paused state.
	_panel(Vector2(18,172),Vector2(514,212),0.98)
	var pages: Array = dialogue.get("frames",[])
	if pages.is_empty():
		_label("对话资料尚未接入",Vector2(38,197),470,20)
		_button("Menu","返回菜单",Vector2(38,332),Vector2(150,32),"leave")
		return
	var page: Dictionary = pages[clampi(page_index,0,pages.size()-1)]
	var speaker := ""
	var lines: PackedStringArray = []
	for entry: Dictionary in page.get("texts",[]):
		var text := str(entry.get("text",""))
		if text.begins_with("- "):
			speaker = text.trim_prefix("- ")
		elif not text.is_empty():
			lines.append(text)
	var speaker_label := _label(speaker,Vector2(38,187),360,18)
	speaker_label.name = "DialogueSpeaker"
	_label("%d / %d" % [clampi(page_index+1,1,pages.size()),pages.size()],Vector2(462,190),55,11)
	var body := _label("\n".join(lines),Vector2(38,220),470,14)
	body.name = "DialogueText"
	body.size.y = 88
	_label("点击逐句阅读  ·  Space 跳过本段",Vector2(38,307),465,11)
	_button("DialogueNext","下一句" if page_index < pages.size()-1 else "继续",Vector2(38,337),Vector2(175,31),"dialogue_next")
	_button("DialogueSkip","跳过本段（Space）",Vector2(282,337),Vector2(230,31),"dialogue_skip",null,dialogue.has("space_target"))

func show_intermission(data: Dictionary, run: Dictionary) -> void:
	clear()
	_background()
	_panel(Vector2(45,27),Vector2(460,348))
	_label(str(data.get("title","STAGE1 CLEAR")),Vector2(68,43),425,28)
	_label("森林阶段完成",Vector2(70,86),405,16)
	_label("本场金币 +%d  ·  本场用时 %.2f 秒" % [int(run.get("earned_gold",0)),float(run.get("source_ticks",0))/25.0],Vector2(70,117),410,13)
	_button("Retry","◀ 重新挑战",Vector2(70,162),Vector2(192,36),"retry_first")
	_button("Continue","进入下一关 · 待还原",Vector2(278,162),Vector2(202,36),"continue",null,false)
	_button("Inventory","查看仓库 · 待还原",Vector2(70,211),Vector2(410,34),"inventory",null,false)
	_label("原作下一场与完整仓库暂未接入。\n可重新挑战森林，或返回菜单选择角色。",Vector2(71,260),408,13)
	_button("Menu","返回菜单",Vector2(70,326),Vector2(192,31),"leave")

func show_transition(ticks: int) -> void:
	clear()
	_background()
	_panel(Vector2(85,112),Vector2(380,181))
	_label("前往阶段结算…",Vector2(110,132),335,24)
	_label("过场画面待还原，按原作时序推进。",Vector2(110,176),335,13)
	_label("过场时序 %.2f 秒" % (maxi(ticks,0)/25.0),Vector2(110,202),335,12)
	_button("Back","返回选人",Vector2(110,246),Vector2(145,29),"characters")

func show_hud(stage: Dictionary, battle: Node2D = null) -> void:
	clear()
	if is_instance_valid(battle) and catalog.source_geometry.has("battle_hud"):
		source_hud = SourceHUD.new()
		battle.add_child(source_hud)
		source_hud.configure(catalog,theme_resource,int(battle.player.definition.source_crt),stage.get("source_depths",{}))
		var data: Dictionary = catalog.source_geometry.battle_hud.training
		_source_button("Pause",str(data.menu.texture),data.menu.stage_position,"game_menu")
		if bool(stage.get("training",false)):
			_source_art("training_instructions",data.instructions.stage_position)
			_source_art("training_title",data.title.stage_position)
			_source_button("TrainingRestore","training_restore_up",data.restore.stage_position,"training_restore","training_restore_over","training_restore_down")
			_source_button("TrainingStorage","training_storage_up",data.storage.stage_position,"training_storage","training_storage_over","training_storage_down")
		_toast = _label("",Vector2(95,365),400,12)
		_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_debug = _label("",Vector2(10,205),530,9)
		return
	_panel(Vector2(8,8),Vector2(230,61),0.87)
	_hp = _bar("HUDHP",Vector2(18,17),Color("c95466"))
	_mp = _bar("HUDMP",Vector2(18,39),Color("59b4d5"))
	_status = _label("",Vector2(168,16),65,11)
	_label(str(stage.title),Vector2(267,10),270,15)
	_enemy = _label("",Vector2(269,36),200,12)
	_button("Pause","菜单",Vector2(492,41),Vector2(50,25),"pause")
	_panel(Vector2(8,371),Vector2(534,23),0.85)
	_hint = _label("← → 移动   X 普通动作   D 技能 · 5MP   Esc 暂停",Vector2(17,372),520,11)
	_toast = _label("",Vector2(90,70),380,14)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_debug = _label("",Vector2(10,103),510,10)

func _bar(id: String, at: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = id
	bar.show_percentage = false
	bar.step = 0.01
	bar.position = at
	bar.size = Vector2(140,17)
	bar.add_theme_stylebox_override("background",_style(Color("13141b"),Color("625775")))
	bar.add_theme_stylebox_override("fill",_style(color,color))
	root.add_child(bar)
	return bar

func update_hud(state: Dictionary, debug_visible: bool) -> void:
	if is_instance_valid(source_hud):
		source_hud.update_state(state)
		_debug.visible = debug_visible
		_debug.text = "25Hz tick%d | 父%d / 子%d / 空中%d / 身体%d\n原点(%.2f,%.2f) 朝向%d | 弹%d | 毫秒%.0f Z%s" % [state.ticks,state.parent_frame,state.source_frame,state.air_action_frame,state.body_frame,state.position[0],state.position[1],state.facing,state.projectiles,state.real_time_ms,str(state.z_interval_active)]
		return
	if not is_instance_valid(_hp):
		return
	_hp.max_value = state.max_hp
	_hp.value = state.hp
	_mp.max_value = state.max_mp
	_mp.value = state.mp
	_status.text = "%.1f HP\n%.1f MP" % [float(state.hp),float(state.mp)]
	_enemy.text = "剩余 %d  ·  金币 %d" % [state.remaining,state.gold]
	var character_id := str(state.get("character_id","crt_0"))
	var cooldowns: Dictionary = state.get("cooldowns",{"skill":state.get("skill_cooldown",0)})
	var available: Array = state.get("available_skills",["skill_s","skill"] if character_id == "crt_0" else ["skill"])
	var skills: PackedStringArray = []
	for id: String in ["skill_z","skill_s","skill"]:
		if available.has(id):
			var key := "Z" if id == "skill_z" else ("S" if id == "skill_s" else "D")
			var ticks := float(cooldowns.get(id,0))
			skills.append("%s %.1fs" % [key,ticks/25.0] if ticks > 0 else key+" 技能")
	_hint.text = "← →  X  C跳  ↓后撤  %s  Esc" % "  ".join(skills) if character_id == "crt_0" else "← → 移动  X  %s  Esc" % "  ".join(skills)
	_debug.visible = debug_visible
	_debug.text = "25Hz tick%d | 父%d / 子%d / 空中子%d / 身体%d\n敌HP %s | 原点 %s | 弹%d\n红：攻击 / 青：身体 | 毫秒%.0f Z任务%s" % [state.ticks,state.get("parent_frame",0),state.source_frame,state.get("air_action_frame",0),state.get("body_frame",1),str(state.enemy_hp),str(state.position),state.projectiles,state.get("real_time_ms",0),str(state.get("z_interval_active",false))]

func toast(message: String) -> void:
	if is_instance_valid(_toast):
		_toast.text = message
		_toast_time = 2.0

func show_lab_hint() -> void:
	_lab_hint = _label("动作检查 · 静音 · 不保存进度\nF1/F2角色 F4重置 F5停帧 F6单步 F7场景 F8导出 F9难度",Vector2(12,165),530,9)

func _source_art(key: String, at: Array) -> TextureRect:
	var data: Dictionary = catalog.textures[key]
	var texture := TextureRect.new()
	texture.texture = load(str(data.path))
	texture.position = Vector2(at[0]-data.pivot[0],at[1]-data.pivot[1])
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(texture)
	return texture

func _source_button(id: String, key: String, at: Array, action: String, hover := "", pressed := "") -> TextureButton:
	var data: Dictionary = catalog.textures[key]
	var button := TextureButton.new()
	button.name = id
	button.texture_normal = load(str(data.path))
	if not hover.is_empty():button.texture_hover = load(str(catalog.textures[hover].path))
	if not pressed.is_empty():button.texture_pressed = load(str(catalog.textures[pressed].path))
	button.position = Vector2(at[0]-data.pivot[0],at[1]-data.pivot[1])
	button.pressed.connect(func():intent.emit(action,null))
	root.add_child(button)
	return button

func show_training_storage(profile: Dictionary, character_id: String) -> void:
	show_source_overlay("storage",{"profile":profile,"storage_page":2},"root_41")

func close_source_overlay() -> void:
	if is_instance_valid(source_menu):
		root.remove_child(source_menu)
		source_menu.queue_free()
	source_menu = null

func show_source_overlay(kind: String, state: Dictionary, stage_id: String, page := 2) -> void:
	close_source_overlay()
	source_menu = SourceMenu.new()
	root.add_child(source_menu)
	source_menu.configure(catalog,theme_resource,stage_id)
	source_menu.intent.connect(func(action:String,value:Variant):intent.emit(action,value))
	match kind:
		"dropdown":source_menu.show_dropdown(state)
		"failure":source_menu.show_failure(state)
		"storage":source_menu.show_storage(state)
		_:source_menu.show_menu(page,state)

func _process(delta: float) -> void:
	if is_instance_valid(_lab_hint):_lab_hint.visible = _toast_time <= 0
	if _toast_time > 0:
		_toast_time -= delta
		if _toast_time <= 0 and is_instance_valid(_toast):
			_toast.text = ""

func show_pause() -> void:
	_panel(Vector2(130,113),Vector2(290,175))
	_label("暂停",Vector2(230,126),160,25)
	_button("Resume","继续战斗",Vector2(160,179),Vector2(230,35),"resume")
	_button("Menu","保存进度并返回菜单",Vector2(160,230),Vector2(230,35),"leave")

func show_result(outcome: String, run: Dictionary, stage: Dictionary) -> void:
	clear()
	_panel(Vector2(85,65),Vector2(380,275))
	_label("本场完成" if outcome == "victory" else "角色倒下了",Vector2(115,86),330,28)
	_label("%s\n本场获得金币：%d\n用时 %.2f 秒（源时间轴）" % [stage.title,int(run.earned_gold),float(run.source_ticks)/25.0],Vector2(115,135),330,14)
	if outcome == "victory" and not str(stage.get("next_stage","")).is_empty():
		_label("原作结束对话后进入下一场。\nSpace 或点击继续。",Vector2(115,205),330,12)
		_button("Continue","继续下一场",Vector2(115,260),Vector2(230,34),"continue")
	elif outcome == "victory":
		_label("本轮已接入内容完成。\n后续场景待还原，可返回菜单再次进入。",Vector2(115,205),330,12)
		_button("Continue","后续场景 · 待还原",Vector2(115,260),Vector2(230,34),"continue",null,false)
	else:
		_button("Retry","重新挑战本场",Vector2(115,230),Vector2(230,34),"retry")
	_button("Menu","返回菜单",Vector2(115,300),Vector2(230,28),"leave")

func show_error(messages: Array) -> void:
	clear()
	_panel(Vector2(25,30),Vector2(500,340))
	_label("启动检查未通过",Vector2(45,47),460,22)
	_label("\n".join(messages),Vector2(45,91),455,12)
