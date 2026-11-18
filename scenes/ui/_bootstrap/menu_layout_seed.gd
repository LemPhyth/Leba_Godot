extends Control
## Source-art overlay. Owns presentation only: no Battle, profile, save or audio writes.
## The caller handles every intention and supplies a new authoritative snapshot.
signal intent(action: String, value: Variant)
const SourceClock = preload("res://scripts/core/source_clock.gd")
const QUALITY_NOTICE := "原作 Flash 矢量画质尚未映射为 Godot 设置，此选项当前不可用。"

class SourceButton extends BaseButton:
	var artwork: Sprite2D
	var frames: Dictionary = {}
	var hit_origin := Vector2.ZERO
	var visual_state := "up"

	func setup(images: Dictionary, hit: Rect2, hint: String, enabled := true) -> void:
		frames = images
		hit_origin = hit.position
		position = hit.position
		size = hit.size
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		tooltip_text = hint
		disabled = not enabled
		artwork = Sprite2D.new()
		artwork.name = "Artwork"
		artwork.centered = false
		add_child(artwork)
		mouse_entered.connect(refresh_art)
		mouse_exited.connect(refresh_art)
		button_down.connect(refresh_art)
		button_up.connect(refresh_art)
		refresh_art()

	func _draw() -> void:refresh_art()

	func refresh_art() -> void:
		if not is_instance_valid(artwork):return
		visual_state = "up"
		if not disabled:
			if get_draw_mode() in [BaseButton.DRAW_PRESSED,BaseButton.DRAW_HOVER_PRESSED]:visual_state = "down"
			elif get_draw_mode() == BaseButton.DRAW_HOVER:visual_state = "over"
		artwork.visible = not frames.is_empty()
		if frames.is_empty():return # Original volume/check targets have no hover art.
		var frame: Dictionary = frames.get(visual_state,frames.get("up",{}))
		if frame.is_empty():return
		artwork.texture = frame.texture
		artwork.position = -hit_origin-frame.pivot
		artwork.modulate = Color(1,1,1,0.45 if disabled else 1.0)

var catalog: Dictionary
var geometry: Dictionary
var state: Dictionary = {} # Read-only render cache, never an authoritative profile.
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
var _images: Dictionary = {}
var _stage_key := ""

func configure(assets: Dictionary, ui_theme: Theme, source_stage: String) -> bool:
	_reset_owned()
	catalog = assets
	geometry = catalog.get("source_geometry",{}).get("source_ui",{})
	stage_id = source_stage
	_stage_key = stage_id.trim_prefix("root_")
	theme = ui_theme
	name = "SourceMenu"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(550,400)
	clip_contents = false
	errors.clear()
	_images.clear()
	ready_ok = not geometry.is_empty() and geometry.get("root_placements_by_source_frame",{}).has(_stage_key)
	if not ready_ok:_fail("原菜单未登记场景："+stage_id)
	if ready_ok:
		_validate_images(geometry)
		ready_ok = errors.is_empty()
	visible = false
	set_process(false)
	return ready_ok

func show_menu(page: int, snapshot: Dictionary) -> void:
	_reset_owned()
	state = snapshot.duplicate(true)
	current_page = page
	if page == 1:
		visible = false
		return
	visible = true
	if not ready_ok:
		_show_error()
		return
	var key: String = {2:"keys",3:"actions",6:"settings"}.get(page,"")
	if key.is_empty():
		_fail("原菜单页面未接入："+str(page))
		_show_error()
		return
	_build_panel(key)
	if page == 6:_build_settings()

func show_failure(snapshot: Dictionary) -> void:
	_reset_owned()
	state = snapshot.duplicate(true)
	current_page = 2
	visible = true
	if ready_ok:_build_panel("failure")
	else:_show_error()

func show_dropdown(snapshot: Dictionary) -> void:
	_reset_owned()
	state = snapshot.duplicate(true)
	current_page = 1
	visible = true
	if not ready_ok or not geometry.has("dropdown"):
		_fail("原6934展开菜单资源尚未登记")
		_show_error()
		return
	_dropdown_active = true
	dropdown_frame = 2
	_clock.reset()
	_draw_dropdown()
	set_process(true)

func show_storage(snapshot: Dictionary) -> void:
	_reset_owned()
	state = snapshot.duplicate(true)
	current_page = int(state.get("storage_page",2))
	visible = true
	if not ready_ok or not geometry.has("warehouse"):
		_fail("原仓库资源尚未登记")
		_show_error()
		return
	var data: Dictionary = geometry.warehouse
	var placements: Array = data.root_placements_by_source_frame.get(_stage_key,[])
	if placements.is_empty() or not data.pages.has(str(current_page)):
		_fail("此场景或仓库页尚未接入："+stage_id+" / "+str(current_page))
		_show_error()
		return
	var main := _group(self,"WarehouseRoot",placements[0])
	panel_root = _group(main,"InventoryRoot",{"matrix":data.container_matrix})
	var page: Dictionary = data.pages[str(current_page)]
	panel_sprite = _sprite(panel_root,str(page.texture))
	_surface(panel_root,panel_sprite,"当前仅接入武器页浏览和HP +10戒指；其他装备分类、兑换及翻页尚未接入。")
	for key: String in _sorted_keys(page.buttons):
		var action := "storage_close" if key == "warehouse_close" else "storage_page"
		var value: Variant = null if key == "warehouse_close" else 8 if key == "warehouse_rings" else 2
		_button(panel_root,key,page.buttons[key],action,value,true,"关闭仓库" if value == null else "戒指" if value == 8 else "武器")
	var profile: Dictionary = state.get("profile",{})
	var progress: Dictionary = profile.get("progress",{})
	for key: String in page.fields:
		var value: Variant = progress.get(key,null)
		if key == "pama_stones":value = 0 # Explicit unimplemented-material scope.
		storage_fields[key] = _storage_field(panel_root,page.fields[key],str(value) if value != null else "—","装备材料尚未接入，当前显示默认0。" if key == "pama_stones" else "")
	for index in range(page.get("unsupported_controls",[]).size()):
		var row: Dictionary = page.unsupported_controls[index]
		var group := _group(panel_root,"Unsupported"+str(index),row)
		_hit_button(group,"unsupported_"+str(index),{},_hit(row.hit_rect_local),"unimplemented",null,false,"此分类、兑换或翻页尚未接入。")
	if current_page == 8:
		_build_ring_inventory(data,profile)
		if bool(state.get("ring_popup",false)) and int(profile.get("inventory",{}).get("haring",0)) == 1:_build_ring_choice(data,profile)

func _reset_owned() -> void:
	# Only remove this overlay's own presentation. Existing HUD/Battle survive.
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	buttons.clear()
	checkbox_sprites.clear()
	storage_fields.clear()
	panel_root = null
	panel_sprite = null
	volume_sprite = null
	_dropdown_active = false
	_drawn_dropdown_frame = 1
	_clock.reset()
	set_process(false)

func _placement(source_id: int) -> Dictionary:
	for row: Dictionary in geometry.root_placements_by_source_frame[_stage_key]:
		if int(row.source_id) == source_id:return row
	_fail("原菜单场景缺少放置："+stage_id+" / "+str(source_id))
	return {}

func _matrix(raw: Array) -> Transform2D:
	return Transform2D(Vector2(raw[0],raw[1]),Vector2(raw[2],raw[3]),Vector2(raw[4],raw[5]))

func _group(parent: Node, title: String, placement: Dictionary) -> Node2D:
	var group := Node2D.new()
	group.name = title
	parent.add_child(group)
	group.transform = _matrix(placement.matrix)
	group.set_meta("source_depth",int(placement.get("depth",0)))
	return group

func _image(key: String) -> Dictionary:
	if _images.has(key):return _images[key]
	var data: Dictionary = catalog.get("textures",{}).get(key,{})
	if data.is_empty() or not ResourceLoader.exists(str(data.get("path",""))):
		_fail("原菜单素材缺失："+key+" / "+str(data.get("path","未登记")))
		return {}
	var texture := load(str(data.path)) as Texture2D
	if texture == null:
		_fail("原菜单纹理无法读取："+key+" / "+str(data.path))
		return {}
	var result := {"texture":texture,"pivot":Vector2(data.pivot[0],data.pivot[1]),"key":key}
	_images[key] = result
	return result

func _validate_images(value: Variant) -> void:
	if value is Dictionary:
		for child: Variant in value.values():_validate_images(child)
	elif value is Array:
		for child: Variant in value:_validate_images(child)
	elif value is String and value.begins_with("source_"):
		_image(value)

func _sprite(parent: Node, key: String) -> Sprite2D:
	var data := _image(key)
	if data.is_empty():return null
	var sprite := Sprite2D.new()
	sprite.name = key
	sprite.texture = data.texture
	sprite.centered = false
	sprite.position = -data.pivot
	parent.add_child(sprite)
	return sprite

func _hit(raw: Array) -> Rect2:return Rect2(raw[0],raw[1],raw[2],raw[3])

func _button(parent: Node, key: String, placement: Dictionary, action: String, value: Variant = null, enabled := true, hint := "", instance_key := "") -> BaseButton:
	var data: Dictionary = geometry.buttons[key]
	var images := {}
	for mode: String in ["up","over","down"]:
		var frame := _image(str(data.textures[mode]))
		if not frame.is_empty():images[mode] = frame
	var identifier := key if instance_key.is_empty() else instance_key
	var group := _group(parent,identifier+"Registration",placement)
	return _hit_button(group,identifier,images,_hit(data.hit_rect_local),action,value,enabled and images.size() == 3,hint)

func _hit_button(parent: Node, key: String, images: Dictionary, rect: Rect2, action: String, value: Variant, enabled: bool, hint: String) -> BaseButton:
	var button := SourceButton.new()
	button.name = key
	parent.add_child(button)
	button.setup(images,rect,hint,enabled)
	button.pressed.connect(func()->void:
		if not button.disabled:intent.emit(action,value))
	buttons[key] = button
	return button

func _sorted_keys(placements: Dictionary) -> Array:
	var result := placements.keys()
	# GUI input picking follows child order, not CanvasItem z_index. Preserve the
	# original depth order also where two transparent hit unions overlap.
	result.sort_custom(func(a:Variant,b:Variant)->bool:return int(placements[a].get("depth",0)) < int(placements[b].get("depth",0)))
	return result

func _build_panel(key: String) -> void:
	var panel: Dictionary = geometry.panels[key]
	var placement := _placement(int(panel.source_id))
	if placement.is_empty():
		_show_error()
		return
	panel_root = _group(self,"PanelRoot",placement)
	panel_sprite = _sprite(panel_root,str(panel.texture))
	_surface(panel_root,panel_sprite)
	for button_key: String in _sorted_keys(panel.buttons):
		var action := "resume"
		if button_key.ends_with("retry"):action = "retry"
		elif button_key.ends_with("return"):action = "source_leave"
		var quality := button_key.begins_with("quality_")
		_button(panel_root,button_key,panel.buttons[button_key],action,null,not quality,QUALITY_NOTICE if quality else {"resume":"关闭菜单，返回游戏","retry":"重新开始","source_leave":"返回标题"}[action])

func _build_settings() -> void:
	if not is_instance_valid(panel_root):return
	var settings: Dictionary = state.get("settings",{})
	var volume: float = float(settings.get("volume",float(geometry.original_defaults.volume_percent)/100.0))
	var percent: float = volume*100.0
	#1974 uses exact25-step values;65/80 remain page1. Rendering must not snap
	# or save the caller's real volume simply because the original art has5pages.
	var displayed := 100
	for known: int in [0,25,50,75]:
		if percent == float(known):displayed = known
	var volume_root := _group(panel_root,"VolumeRoot",geometry.volume.placement)
	volume_sprite = _sprite(volume_root,str(geometry.volume.image_by_volume[str(displayed)]))
	for target: Dictionary in geometry.volume.click_targets:
		var value := int(target.volume_percent)
		# This rect ALREADY includes the target child matrix, in1974 local space.
		_hit_button(volume_root,"volume_"+str(value),{},_hit(target.hit_rect_volume_local),"volume",value/100.0,true,"设为%d%%（当前%s%%）" % [value,str(snappedf(percent,0.01))])
	for key: String in geometry.checkboxes:
		var checkbox: Dictionary = geometry.checkboxes[key]
		var checked := bool(settings.get(key,false))
		var group := _group(panel_root,key+"Root",checkbox.placement)
		checkbox_sprites[key] = _sprite(group,str(checkbox.textures["1" if checked else "0"]))
		var enabled := key == "auto_save"
		var button := _hit_button(group,key,{},_hit(checkbox.hit_rect_local),key,not checked,enabled,("关闭自动保存" if checked else "开启自动保存") if enabled else QUALITY_NOTICE)
		if not enabled and is_instance_valid(checkbox_sprites[key]):checkbox_sprites[key].modulate.a = 0.45
		button.set_meta("source_checked",checked)

func _surface(parent: Node, art: Sprite2D, hint := "") -> void:
	if not is_instance_valid(art):return
	var blocker := Control.new()
	blocker.name = "PanelMouseSurface"
	blocker.position = art.position
	blocker.size = art.texture.get_size()
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.tooltip_text = hint
	parent.add_child(blocker)

func _storage_field(parent: Node, data: Dictionary, text: String, hint: String) -> Label:
	var label := Label.new()
	label.name = "Field"+str(data.source_id)
	label.text = text
	label.tooltip_text = hint
	label.mouse_filter = Control.MOUSE_FILTER_PASS if hint.is_empty() else Control.MOUSE_FILTER_STOP
	label.theme = theme
	var font_path: String = catalog.get("fonts",{}).get("inventory","")
	if not font_path.is_empty():label.add_theme_font_override("font",load(font_path))
	label.add_theme_font_size_override("font_size",int(data.font_size_px))
	var rgba: Array = data.get("color_rgba",[255,255,255,255])
	label.add_theme_color_override("font_color",Color(rgba[0]/255.0,rgba[1]/255.0,rgba[2]/255.0,rgba[3]/255.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if int(data.align) == 1 else HORIZONTAL_ALIGNMENT_CENTER if int(data.align) == 2 else HORIZONTAL_ALIGNMENT_LEFT
	var field_root := _group(parent,label.name+"Registration",data)
	label.position = Vector2(data.bounds_local[0],data.bounds_local[1])
	label.size = Vector2(data.bounds_local[2],data.bounds_local[3])
	field_root.add_child(label)
	return label

func _build_ring_inventory(data: Dictionary, profile: Dictionary) -> void:
	var owned := int(profile.get("inventory",{}).get("haring",0)) == 1
	var rings: Dictionary = profile.get("equipment",{}).get("rings",{})
	if owned:
		var item: Dictionary = data.ring_inventory
		var group := _group(panel_root,"OwnedRing",item.placement)
		var icon_root := _group(group,"Icon",item.icon)
		_sprite(icon_root,str(item.icon.texture))
		var target_root := _group(group,"ClickTarget",item.click_target)
		_hit_button(target_root,"ring_owned",{},_hit(item.click_target.hit_rect_local),"storage_ring_choose",true,true,"选择角色装备HP +10戒指；生命增益在重新进入场景时生效。")
	# Source owned flag and equipped slots are deliberately independent. A sold
	# owned flag must not hide equipped copies; a click only requests the source
	# all-four-slot unequip operation from the authoritative Progression owner.
	var characters: Array = data.equipped_rings.keys()
	characters.sort_custom(func(a:Variant,b:Variant)->bool:return int(data.equipped_rings[a].group.depth) < int(data.equipped_rings[b].group.depth))
	for character: String in characters:
		var item: Dictionary = data.equipped_rings[character]
		var group := _group(panel_root,"Equipment"+character,item.group)
		var slot := _group(group,"RingSlot",item.ring_slot)
		var equipped := int(rings.get(character,0))
		if equipped == 1:
			_button(slot,"ring_unequip",item.button,"storage_action",{"operation":"unequip","character_id":character},true,"卸下此戒指；按原作清除四角色的同款记录，生命增益在重入场景时更新。","ring_unequip_"+character)
		elif equipped != 0:
			var registration := _group(slot,"UnimplementedRing",item.button)
			var target: BaseButton = _hit_button(registration,"ring_unknown_"+character,{},_hit(geometry.buttons.ring_unequip.hit_rect_local),"unimplemented",null,false,"此槽装备编号%d尚未接入，未修改原记录。" % equipped)
			var notice := Label.new()
			notice.text = "未接入"
			notice.theme = theme
			notice.add_theme_font_size_override("font_size",10)
			notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
			target.add_child(notice)

func _build_ring_choice(data: Dictionary, profile: Dictionary) -> void:
	var popup: Dictionary = data.choose_ring
	var group := _group(panel_root,"RingChoice",popup.placement)
	var art := _sprite(group,str(popup.texture))
	_surface(group,art)
	var rings: Dictionary = profile.get("equipment",{}).get("rings",{})
	for key: String in _sorted_keys(popup.buttons):
		if key == "ring_cancel":
			_button(group,key,popup.buttons[key],"storage_ring_choose",false,true,"取消选择")
		else:
			var character := "crt_"+key.right(1)
			var supported := int(rings.get(character,0)) in [0,1]
			_button(group,key,popup.buttons[key],"storage_action",{"operation":"equip","character_id":character},supported,"为编号%s装备HP +10戒指；重新进入场景生效。" % key.right(1) if supported else "该角色槽位已有未接入装备，暂不可替换。")

func _draw_dropdown() -> void:
	# Dropdown owns only its panel. No state/profile mutation or gameplay clock.
	# The original buttons created on6 remain the SAME instances on stopped7.
	# Keeping them prevents losing a mouse press held across this frame boundary.
	if dropdown_frame == 7 and _drawn_dropdown_frame == 6 and is_instance_valid(panel_root):
		var top_button: BaseButton = buttons.dropdown_top
		top_button.disabled = false
		top_button.tooltip_text = "收起菜单"
		top_button.refresh_art()
		_drawn_dropdown_frame = 7
		return
	if is_instance_valid(panel_root):
		remove_child(panel_root)
		panel_root.queue_free()
	buttons.clear()
	var data: Dictionary = geometry.dropdown
	_drawn_dropdown_frame = dropdown_frame
	var placement: Dictionary = data.root_placements_by_source_frame[_stage_key][0]
	panel_root = _group(self,"DropdownRoot",placement)
	var rows: Array = data.frames[str(dropdown_frame)].duplicate()
	rows.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return int(a.depth) < int(b.depth))
	for row: Dictionary in rows:
		if row.has("button_key"):
			var key: String = row.button_key
			var metadata: Dictionary = data.buttons[key]
			_button(panel_root,key,row,"menu_page",int(metadata.target_source_frame),true,{2:"按键说明",3:"重新开始或返回标题",6:"设置"}.get(int(metadata.target_source_frame),""))
		elif row.has("texture"):
			var group := _group(panel_root,"Source"+str(row.source_id)+"Depth"+str(row.depth),row)
			_sprite(group,str(row.texture))
	# The source trigger exists in each page; clicks only act at stopped1/7.
	var top: Dictionary = data.top
	var top_group := _group(panel_root,"DropdownTop",top)
	var top_button := _hit_button(top_group,"dropdown_top",{},_hit(top.hit_rect_local),"dropdown_toggle",null,dropdown_frame in [1,7],"收起菜单" if dropdown_frame == 7 else "展开菜单")
	# Keep this local presentation action from reaching profile/gameplay owners.
	for connection: Dictionary in top_button.pressed.get_connections():top_button.pressed.disconnect(connection.callable)
	top_button.pressed.connect(func()->void:
		if dropdown_frame == 7:dropdown_frame = 8
		elif dropdown_frame == 1:dropdown_frame = 2
		else:return
		_clock.reset()
		_draw_dropdown())

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
	var label := Label.new()
	label.name = "SourceMenuError"
	label.text = "菜单资源无法显示：\n"+"\n".join(errors)
	label.position = Vector2(25,140)
	label.size = Vector2(500,100)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color",Color(1,0.65,0.65))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
