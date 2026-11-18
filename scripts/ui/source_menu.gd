extends Control
## Persistent author pages. No layout writes, profile mutation or Battle ownership.
signal intent(action: String, value: Variant)
const SourceClock = preload("res://scripts/core/source_clock.gd")
const QUALITY_NOTICE := "原作 Flash 矢量画质尚未映射为 Godot 设置，此选项当前不可用。"
@export_group("Author state textures")
@export var volume_textures: Array[Texture2D] = [] # 0,25,50,75,100.
@export var auto_save_textures: Array[Texture2D] = [] # unchecked, checked.
@export var auto_quality_textures: Array[Texture2D] = []
@export var checkbox_frame_offsets: Array[Vector2] = []
var catalog: Dictionary
var geometry: Dictionary
var state: Dictionary = {}
var stage_id := ""
var buttons: Dictionary = {}
var current_page := 1
var panel_root: Node2D
var panel_sprite: Sprite2D
var volume_sprite: Sprite2D
var checkbox_sprites: Dictionary = {}
var storage_fields: Dictionary = {}
var ready_ok := false
var errors: Array[String] = []
var dropdown_frame := 1
var _drawn_dropdown_frame := 1
var _dropdown_active := false
var _clock := SourceClock.new()
var _active_page: Control
var _pages: Control

func configure(assets: Dictionary, _theme: Theme, source_stage: String) -> bool:
	catalog = assets
	geometry = catalog.get("source_geometry",{}).get("source_ui",{})
	stage_id = source_stage
	_pages = get_node_or_null("Pages")
	errors.clear()
	ready_ok = _pages != null and not geometry.is_empty()
	if volume_textures.size() != 5 or auto_save_textures.size() != 2 or auto_quality_textures.size() != 2 or checkbox_frame_offsets.size() != 2:
		_fail("source_menu.tscn: settings state textures/offsets are incomplete; inspect Author state textures.")
		ready_ok = false
	if not ready_ok:
		_fail("SourceMenu requires scenes/ui/source_menu.tscn and source_ui metadata.")
		return false
	_bind_actions(_pages)
	_reset_owned()
	visible = false
	return true

func _bind_actions(node: Node) -> void:
	if node is BaseButton:
		var handler := _pressed.bind(node)
		if not node.pressed.is_connected(handler):node.pressed.connect(handler)
	for child: Node in node.get_children():_bind_actions(child)

func _reset_owned() -> void:
	# Author nodes keep their identity, transforms, resources and native hit areas.
	if _pages != null:
		for child: CanvasItem in _pages.get_children():child.visible = false
	var error := get_node_or_null("Error")
	if error != null:error.visible = false
	buttons.clear()
	checkbox_sprites.clear()
	storage_fields.clear()
	panel_root = null
	panel_sprite = null
	volume_sprite = null
	_active_page = null
	_dropdown_active = false
	_drawn_dropdown_frame = 1
	_clock.reset()
	set_process(false)

func _activate(id: String) -> bool:
	if not ready_ok:
		_show_error()
		return false
	_active_page = _pages.get_node_or_null(id) if _pages != null else null
	if _active_page == null:
		_fail("缺少作者菜单场景："+id)
		_show_error()
		return false
	visible = true
	_active_page.visible = true
	_collect(_active_page)
	return true

func _collect(node: Node) -> void:
	if node.has_meta("panel_root"):panel_root = node
	if node.has_meta("panel_sprite"):panel_sprite = node
	if node.has_meta("volume_sprite"):volume_sprite = node
	if node.has_meta("checkbox_key"):checkbox_sprites[str(node.get_meta("checkbox_key"))] = node
	if node.has_meta("storage_field"):storage_fields[str(node.get_meta("storage_field"))] = node
	if node.has_meta("button_key") and node.is_visible_in_tree():buttons[str(node.get_meta("button_key"))] = node
	for child: Node in node.get_children():_collect(child)

func show_menu(page: int, snapshot: Dictionary) -> void:
	_reset_owned()
	state = snapshot.duplicate(true)
	current_page = page
	if page == 1:
		visible = false
		return
	var id: String = {2:"menu_keys",3:"menu_actions",6:"menu_settings"}.get(page,"")
	if not _activate(id):return
	if page == 6:_update_settings()

func show_failure(snapshot: Dictionary) -> void:
	_reset_owned()
	state = snapshot.duplicate(true)
	current_page = 2
	_activate("menu_failure")

func show_storage(snapshot: Dictionary) -> void:
	_reset_owned()
	state = snapshot.duplicate(true)
	current_page = int(state.get("storage_page",2))
	if not _activate("warehouse_"+str(current_page)):return
	var profile: Dictionary = state.get("profile",{})
	var progress: Dictionary = profile.get("progress",{})
	for key: String in storage_fields:
		storage_fields[key].text = "0" if key == "pama_stones" else str(progress.get(key,"—"))
	if current_page != 8:return
	var owned := int(profile.get("inventory",{}).get("haring",0)) == 1
	panel_root.get_node("OwnedRing").visible = owned
	panel_root.get_node("RingChoice").visible = owned and bool(state.get("ring_popup",false))
	var rings: Dictionary = profile.get("equipment",{}).get("rings",{})
	for id: String in ["crt_0","crt_1","crt_2","crt_3"]:
		var group := panel_root.get_node("Equipment"+id)
		var value := int(rings.get(id,0))
		group.visible = value != 0
		var equipped := group.find_child("ring_unequip_"+id,true,false) as BaseButton
		equipped.visible = value == 1
		equipped.disabled = value != 1
		equipped.tooltip_text = "此槽装备编号%d尚未接入，原记录保留。" % value if value not in [0,1] else "卸下此戒指；清除原四角色记录，生命增益在重入后更新。"
		var unknown := group.find_child("ring_unknown_"+id,true,false) as BaseButton
		if unknown != null:
			unknown.visible = value not in [0,1]
			unknown.tooltip_text = "此槽装备编号%d尚未接入，未修改原记录。" % value
		var choose: BaseButton = panel_root.find_child("ring_equip_crt"+id.right(1),true,false)
		choose.disabled = value not in [0,1]
		choose.tooltip_text = "此角色槽位已有未接入装备，暂不可替换。" if choose.disabled else "装备HP +10戒指；重新进入场景生效。"
	buttons.clear()
	_collect(_active_page)

func _update_settings() -> void:
	var settings: Dictionary = state.get("settings",{})
	var percent := float(settings.get("volume",0.8))*100.0
	var displayed := 100
	for value: int in [0,25,50,75]:
		if percent == value:displayed = value
	if volume_textures.size() == 5:volume_sprite.texture = volume_textures[displayed/25]
	for value: int in [0,25,50,75,100]:buttons["volume_"+str(value)].tooltip_text = "设为%d%%（当前%s%%）" % [value,str(snappedf(percent,0.01))]
	for key: String in checkbox_sprites:
		var checked := bool(settings.get(key,false))
		var textures: Array[Texture2D] = auto_save_textures if key == "auto_save" else auto_quality_textures
		if textures.size() == 2:checkbox_sprites[key].texture = textures[1 if checked else 0]
		if checkbox_frame_offsets.size() == 2:checkbox_sprites[key].offset = checkbox_frame_offsets[1 if checked else 0]
		buttons[key].set_meta("source_checked",checked)
		buttons[key].tooltip_text = ("关闭自动保存" if checked else "开启自动保存") if key == "auto_save" else QUALITY_NOTICE

func show_dropdown(snapshot: Dictionary) -> void:
	_reset_owned()
	state = snapshot.duplicate(true)
	current_page = 1
	_dropdown_active = true
	dropdown_frame = 2
	_draw_dropdown()
	set_process(true)

func _draw_dropdown() -> void:
	if dropdown_frame == 7 and _drawn_dropdown_frame == 6 and _active_page != null:
		buttons.dropdown_top.disabled = false
		buttons.dropdown_top.tooltip_text = "收起菜单"
		_drawn_dropdown_frame = 7
		return
	if _active_page != null:_active_page.visible = false
	buttons.clear()
	# Source6 and stopped7 retain the same native button instances and held press.
	var page := 6 if dropdown_frame == 7 else dropdown_frame
	if not _activate("dropdown_"+str(page)):return
	_drawn_dropdown_frame = dropdown_frame
	buttons.dropdown_top.disabled = dropdown_frame not in [1,7]
	buttons.dropdown_top.tooltip_text = "收起菜单" if dropdown_frame == 7 else "展开菜单"

func _pressed(button: BaseButton) -> void:
	if button.disabled:return
	var key := str(button.get_meta("button_key",""))
	if not button.intent_action.is_empty():
		intent.emit(button.intent_action,button.intent_payload.get("value"))
		return
	if key == "dropdown_top":
		if dropdown_frame == 7:dropdown_frame = 8
		elif dropdown_frame == 1:dropdown_frame = 2
		else:return
		_clock.reset()
		_draw_dropdown()
		return
	if key.begins_with("volume_"):
		intent.emit("volume",float(key.trim_prefix("volume_"))/100.0)
	elif key == "auto_save":intent.emit("auto_save",not bool(state.get("settings",{}).get("auto_save",false)))
	elif key.begins_with("dropdown_"):intent.emit("menu_page",{"dropdown_settings":6,"dropdown_actions":3,"dropdown_keys":2}[key])
	elif key == "warehouse_close":intent.emit("storage_close",null)
	elif key in ["warehouse_weapons","warehouse_rings","warehouse_crt1_rings","warehouse_crt2_rings","warehouse_crt3_rings","warehouse_crt4_rings"]:
		var character := str(state.get("profile",{}).get("selection",{}).get("character_id","crt_0"))
		intent.emit("storage_page",2+character.right(1).to_int() if key == "warehouse_weapons" else 8)
	elif key in ["ring_owned","ring_cancel"]:intent.emit("storage_ring_choose",key == "ring_owned")
	elif key.begins_with("ring_equip_crt"):intent.emit("storage_action",{"operation":"equip","character_id":"crt_"+key.right(1)})
	elif key.begins_with("ring_unequip_crt_"):intent.emit("storage_action",{"operation":"unequip","character_id":"crt_"+key.right(1)})
	elif key.ends_with("retry"):intent.emit("retry",null)
	elif key.ends_with("return"):intent.emit("source_leave",null)
	elif key == "close":intent.emit("resume",null)

func _process(delta: float) -> void:
	if not _dropdown_active:return
	for tick in range(_clock.consume(delta)):
		if dropdown_frame in [1,7]:continue
		dropdown_frame += 1
		if dropdown_frame >= 13:
			dropdown_frame = 1
			_dropdown_active = false
			set_process(false)
			visible = false
			intent.emit("resume",null)
			break
		_draw_dropdown()

func _fail(message: String) -> void:
	errors.append(message)
	push_error(message)

func _show_error() -> void:
	var label := get_node_or_null("Error") as Label
	if label == null:return
	label.text = "菜单资源无法显示：\n"+"\n".join(errors)
	label.visible = true
	visible = true
