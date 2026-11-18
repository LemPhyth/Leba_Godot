extends CanvasLayer
## Permanent native pages display caller-owned values and emit intentions.
signal intent(action: String, value: Variant)
const HUD_SCENE = preload("res://scenes/ui/source_hud.tscn")
const Progression = preload("res://scripts/core/progression.gd")
var source_hud: Node2D
var source_menu: Control
var root: Control
var catalog: Dictionary
var theme_resource: Theme
var _pages: Control
var _active: Control
var _offset: Control
var _battle: Node2D
var _debug: Label
var _toast: Label
var _lab_hint: Label
var _toast_time := 0.0
var _lab_enabled := false

func configure(assets: Dictionary) -> void:
	catalog = assets
	root = get_node_or_null("UI")
	if root == null:
		push_error("GameUI requires scenes/ui/game_ui.tscn; script-only construction has no author pages.")
		return
	_offset = root.get_node("RuntimeTransitionOffset")
	_pages = _offset.get_node("Pages")
	theme_resource = root.theme
	source_menu = _offset.get_node("SourceMenu")
	if not source_menu.intent.is_connected(_forward):source_menu.intent.connect(_forward)
	for page: Control in _pages.get_children():_bind(page,page.name)
	clear()

func _forward(action: String, value: Variant) -> void:
	intent.emit(action,value)

func _bind(node: Node, page: String) -> void:
	if node is BaseButton:
		var handler := _pressed.bind(page,str(node.name))
		if not node.pressed.is_connected(handler):node.pressed.connect(handler)
	if node is HSlider:
		var handler := _volume_changed
		if not node.value_changed.is_connected(handler):node.value_changed.connect(handler)
	for child: Node in node.get_children():_bind(child,page)

func _volume_changed(value: float) -> void:intent.emit("volume",value)

func _pressed(page: String, id: String) -> void:
	var button := _pages.get_node(page).find_child(id,true,false) as BaseButton
	if button == null or button.disabled:return
	if id.begins_with("Character_"):
		intent.emit("select_training_character" if page == "training_characters" else "select_character",id.trim_prefix("Character_"))
		return
	if id.begins_with("Difficulty_"):
		intent.emit("select_difficulty",id.trim_prefix("Difficulty_"))
		return
	if id.begins_with("Mode_"):
		intent.emit("select_mode",id.trim_prefix("Mode_"))
		return
	if page == "intermission":
		intent.emit({"Continue":"intermission_continue","Inventory":"intermission_storage","Retry":"retry_first","Menu":"title"}[id],null)
		return
	if page == "shop" and id in ["Buy","Equip","Unequip","Sell"]:
		intent.emit("shop_action",id.to_lower())
		return
	var action: String = {"Start":"adventure","Training":"training","Store":"shop","Begin":"begin","EnterBattle":"enter","DialogueNext":"dialogue_next","DialogueSkip":"dialogue_skip","Pause":"game_menu","TrainingRestore":"training_restore","TrainingStorage":"training_storage","Resume":"resume","Retry":"retry","Continue":"continue","Menu":"leave"}.get(id,"")
	if id == "Back":action = "title" if page in ["characters","training_characters","modes"] else "characters"
	if page == "training_characters" and id == "Begin":action = "begin_training"
	if not action.is_empty():intent.emit(action,null)

func clear() -> void:
	if _pages == null:return
	for page: Control in _pages.get_children():page.visible = false
	_active = null
	if is_instance_valid(source_hud):source_hud.visible = false
	close_source_overlay()
	if _offset != null:_offset.position = Vector2.ZERO
	_toast_time = 0.0
	_lab_enabled = false

func _show(id: String) -> Control:
	clear()
	_active = _pages.get_node(id)
	_active.visible = true
	return _active

func get_button(id: String) -> BaseButton:
	if is_instance_valid(source_menu) and source_menu.visible and source_menu.buttons.has(id):return source_menu.buttons[id]
	for page: Control in _pages.get_children():
		if not page.visible:continue
		var found := page.find_child(id,true,false) as BaseButton
		if found != null and found.is_visible_in_tree():return found
	return null

func set_world_offset(value: Vector2) -> void:
	if _offset != null:_offset.position = value

func show_title(profile: Dictionary, save_message: String) -> void:
	var page := _show("title")
	page.get_node("Gold").text = "金币 %d" % int(profile.progress.gold)
	page.get_node("SaveMessage").text = save_message

func show_modes(modes: Dictionary, profile: Dictionary) -> void:
	var page := _show("modes")
	for id: String in modes:
		var button := page.get_node_or_null("Mode_"+id) as Button
		if button == null:continue
		button.text = str(modes[id].title)
		button.disabled = not bool(modes[id].enabled)
		button.tooltip_text = str(modes[id].get("reason",modes[id].get("source","")))
	page.get_node("Volume").set_value_no_signal(float(profile.settings.volume))

func _characters(id: String, characters: Dictionary, selected: String) -> void:
	var page := _show(id)
	for key: String in characters:
		var button := page.get_node_or_null("Character_"+key) as Button
		if button == null:continue
		var data: Dictionary = characters[key]
		button.text = str(data.title)+("  ✓" if key == selected else "")
		button.disabled = not bool(data.enabled)
		button.tooltip_text = str(data.get("reason","选择后进入练习。" if id == "training_characters" else "选择此角色，继续选择难度。"))
	page.get_node("Begin").visible = id != "training_characters"
	page.get_node("Store").visible = id != "training_characters"

func show_characters(characters: Dictionary, selected: String) -> void:_characters("characters",characters,selected)
func show_training_characters(characters: Dictionary, selected: String) -> void:_characters("training_characters",characters,selected)

func show_difficulty(difficulties: Dictionary, profile: Dictionary) -> void:
	var page := _show("difficulty")
	var selected := str(profile.get("selection",{}).get("difficulty_id","expert"))
	for id: String in ["expert","master","king"]:
		var data: Dictionary = difficulties.get(id,{})
		var button := page.get_node("Difficulty_"+id) as Button
		button.text = str(data.get("title",id.capitalize()))+("  ✓" if id == selected else "")
		button.disabled = not bool(data.get("enabled",false))
		button.tooltip_text = str(data.get("reason","选择后进入冒险。"))
	page.get_node("Volume").set_value_no_signal(float(profile.get("settings",{}).get("volume",0.8)))

func show_shop(profile: Dictionary, character_id: String, message: String = "") -> void:
	var page := _show("shop")
	var gold := int(profile.get("progress",{}).get("gold",0))
	var owned := int(profile.get("inventory",{}).get("haring",0)) == 1
	var rings: Dictionary = profile.get("equipment",{}).get("rings",{})
	var equipped := int(rings.get(Progression.new().equipment_family(character_id),0)) == 1
	var any_equipped := false
	for id: String in ["crt_0","crt_1","crt_2","crt_3"]:any_equipped = any_equipped or int(rings.get(id,0)) == 1
	page.get_node("Gold").text = "金币 %d" % gold
	page.get_node("Inventory").text = "库存：%s    当前角色 %s：%s" % ["持有" if owned else "未持有",character_id.trim_prefix("crt_"),"已装备" if equipped else "未装备"]
	page.get_node("Buy").disabled = owned or gold < 3000
	page.get_node("Equip").disabled = not owned or equipped
	page.get_node("Unequip").disabled = not any_equipped
	page.get_node("Sell").disabled = not owned
	page.get_node("ShopMessage").text = message

func show_intro(stage: Dictionary) -> void:
	var page := _show("intro")
	page.get_node("Title").text = str(stage.title)
	page.get_node("Details").text = "敌人：%d\n\n← → 移动  ·  X 普通攻击 / 连段\n技能按键与可用状态见战斗界面。\nEsc 打开工程暂停。" % int(stage.get("enemy_count",1))

func show_dialogue(dialogue: Dictionary, page_index: int) -> void:
	var page := _show("dialogue")
	var frames: Array = dialogue.get("frames",[])
	var frame: Dictionary = frames[clampi(page_index,0,frames.size()-1)] if not frames.is_empty() else {}
	var speaker := ""
	var lines: PackedStringArray = []
	for entry: Dictionary in frame.get("texts",[]):
		var text := str(entry.get("text",""))
		if text.begins_with("- "):speaker = text.trim_prefix("- ")
		elif not text.is_empty():lines.append(text)
	page.get_node("DialogueSpeaker").text = speaker
	page.get_node("DialogueText").text = "\n".join(lines) if not frames.is_empty() else "对话资料尚未接入"
	page.get_node("PageNumber").text = "%d / %d" % [clampi(page_index+1,1,maxi(frames.size(),1)),frames.size()]
	page.get_node("DialogueNext").text = "下一句" if page_index < frames.size()-1 else "继续"
	page.get_node("DialogueSkip").disabled = not dialogue.has("space_target")

func show_intermission(data: Dictionary, run: Dictionary) -> void:
	var page := _show("intermission")
	page.get_node("Title").text = str(data.get("title","阶段中转"))
	page.get_node("Subtitle").text = str(data.get("subtitle","本阶段结束"))
	page.get_node("Stats").text = "本场金币 +%d  ·  本场用时 %.2f 秒" % [int(run.get("earned_gold",0)),float(run.get("source_ticks",0))/25.0]
	var has_next := not str(data.get("next_stage","")).is_empty()
	page.get_node("Continue").disabled = not has_next
	page.get_node("Continue").text = "进入下一关" if has_next else "后续流程 · 尚未恢复"
	page.get_node("Inventory").disabled = not bool(data.get("allow_inventory",true))
	page.get_node("Inventory").text = "查看仓库 / 整备"
	page.get_node("Retry").disabled = not bool(data.get("allow_retry",true))
	page.get_node("Description").text = str(data.get("description","可继续下一场，或打开仓库整备。" if has_next else "后续原流程尚未恢复。此处是中转节点，不是原作结局。"))

func show_transition(ticks: int) -> void:
	var page := _show("transition")
	page.get_node("Timing").text = "过场时序 %.2f 秒" % (maxi(ticks,0)/25.0)

func show_hud(stage: Dictionary, battle: Node2D = null) -> void:
	var page := _show("battle_controls")
	page.get_node("Training").visible = bool(stage.get("training",false))
	_toast = page.get_node("Toast")
	_debug = page.get_node("Debug")
	_lab_hint = page.get_node("LabHint")
	_lab_hint.visible = false
	_debug.visible = false
	_toast.text = ""
	if battle == null:return
	if not is_instance_valid(source_hud) or _battle != battle:
		_battle = battle
		var authored: Variant = battle.get("authored_hud")
		if is_instance_valid(authored):source_hud = authored
		elif battle.has_meta("active_source_hud") and is_instance_valid(battle.get_meta("active_source_hud")):source_hud = battle.get_meta("active_source_hud")
		else:
			source_hud = HUD_SCENE.instantiate()
			source_hud.use_stage_depths = true
		if source_hud.get_parent() == null:battle.add_child(source_hud)
		battle.set_meta("active_source_hud",source_hud)
	source_hud.configure(catalog,theme_resource,int(battle.player.definition.source_crt),stage.get("source_depths",{}))
	source_hud.visible = true

func update_hud(snapshot: Dictionary, debug_visible: bool) -> void:
	if not is_instance_valid(source_hud):return
	source_hud.update_state(snapshot)
	if _debug == null:return
	_debug.visible = debug_visible
	_debug.text = "25Hz tick%d | 父%d / 子%d / 空中%d / 身体%d\n原点(%.2f,%.2f) 朝向%d | 弹%d | 毫秒%.0f Z%s" % [snapshot.ticks,snapshot.parent_frame,snapshot.source_frame,snapshot.air_action_frame,snapshot.body_frame,snapshot.position[0],snapshot.position[1],snapshot.facing,snapshot.projectiles,snapshot.real_time_ms,str(snapshot.z_interval_active)]

func toast(message: String) -> void:
	if is_instance_valid(_toast):
		_toast.text = message
		_toast_time = 2.0

func show_lab_hint() -> void:
	_lab_enabled = true
	if is_instance_valid(_lab_hint):_lab_hint.visible = true

func show_training_storage(profile: Dictionary, character_id: String) -> void:
	# Original2728 weapon pages are 2+crt; the caller owns character selection.
	var page := 2+int(character_id.trim_prefix("crt_"))
	show_source_overlay("storage",{"profile":profile,"storage_page":page},"root_41")

func close_source_overlay() -> void:
	if is_instance_valid(source_menu):
		source_menu._reset_owned()
		source_menu.visible = false

func show_source_overlay(kind: String, snapshot: Dictionary, stage_id: String, page := 2) -> void:
	source_menu.configure(catalog,theme_resource,stage_id)
	match kind:
		"dropdown":source_menu.show_dropdown(snapshot)
		"failure":source_menu.show_failure(snapshot)
		"storage":source_menu.show_storage(snapshot)
		_:source_menu.show_menu(page,snapshot)

func _process(delta: float) -> void:
	if is_instance_valid(_lab_hint):_lab_hint.visible = _lab_enabled and _toast_time <= 0.0
	if _toast_time > 0:
		_toast_time -= delta
		if _toast_time <= 0 and is_instance_valid(_toast):_toast.text = ""

func show_pause() -> void:
	_pages.get_node("pause").visible = true

func show_result(outcome: String, run: Dictionary, stage: Dictionary) -> void:
	var page := _show("result")
	page.get_node("Title").text = "本场完成" if outcome == "victory" else "角色倒下了"
	page.get_node("Stats").text = "%s\n本场获得金币：%d\n用时 %.2f 秒（源时间轴）" % [stage.title,int(run.earned_gold),float(run.source_ticks)/25.0]
	page.get_node("Retry").visible = outcome != "victory"
	page.get_node("Continue").visible = outcome == "victory"
	var has_next := not str(stage.get("next_stage","")).is_empty()
	page.get_node("Continue").disabled = not has_next
	page.get_node("Description").text = "原作结束对话后进入下一场。\nSpace 或点击继续。" if has_next else "本场结束，后续流程尚未恢复。"

func show_error(messages: Array) -> void:
	var page := _show("error")
	page.get_node("Details").text = "\n".join(messages)
