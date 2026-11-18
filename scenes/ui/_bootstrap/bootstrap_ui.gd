extends SceneTree
## Explicit one-time ACT02 layout migration. Never called by import or gameplay.
## Existing author scenes are deliberately not overwritten.
const HudSeed = preload("res://scenes/ui/_bootstrap/hud_layout_seed.gd")
const PageSeed = preload("res://scenes/ui/_bootstrap/pages_layout_seed.gd")
const MenuSeed = preload("res://scenes/ui/_bootstrap/menu_layout_seed.gd")
var catalog: Dictionary
var theme_resource: Theme

func _initialize() -> void:
	if not "--bootstrap-ui" in OS.get_cmdline_user_args():
		push_error("Explicit --bootstrap-ui is required; this is not an import hook.")
		quit(2)
		return
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_catalog.json"))
	var seed := PageSeed.new()
	root.add_child(seed)
	seed.configure(catalog)
	theme_resource = seed.theme_resource
	# Reuse the existing imported font instead of serializing a duplicate cache.
	var source_font: Font = load(str(catalog.fonts.ui))
	theme_resource.default_font.fallbacks = [source_font]
	if not FileAccess.file_exists("res://scenes/ui/default_theme.tres"):
		ResourceSaver.save(theme_resource,"res://scenes/ui/default_theme.tres")
	theme_resource = load("res://scenes/ui/default_theme.tres")
	seed.free()
	_build_hud()
	_build_pages()
	_build_menus()
	quit()

func _owners(node: Node, scene: Node) -> void:
	for child: Node in node.get_children():
		child.owner = scene
		_owners(child,scene)

func _save(scene: Node, path: String) -> void:
	if FileAccess.file_exists(path):
		print("PRESERVED author scene: ",path)
		scene.free()
		return
	_owners(scene,scene)
	var packed := PackedScene.new()
	var result := packed.pack(scene)
	if result == OK:result = ResourceSaver.save(packed,path)
	if result != OK:push_error("Scene save failed %s: %s" % [path,error_string(result)])
	else:print("CREATED author scene: ",path)
	scene.free()

func _role(node: Node, role: String) -> void:
	node.set_meta("ui_role",role)

func _fill(hud: Node2D, art: Sprite2D, id: String) -> void:
	var layout := Node2D.new()
	layout.name = id+"Layout"
	layout.position = art.position
	layout.z_index = art.z_index
	_role(layout,id.to_lower()+"_layout")
	hud.add_child(layout)
	var motion := Node2D.new()
	motion.name = "FillState"
	_role(motion,id.to_lower()+"_fill")
	layout.add_child(motion)
	art.reparent(motion,false)
	art.name = "Artwork"
	art.position = Vector2.ZERO
	art.z_index = 0

func _build_hud() -> void:
	var path := "res://scenes/ui/source_hud.tscn"
	if FileAccess.file_exists(path):return
	var scene := Node2D.new()
	scene.name = "SourceHUD"
	scene.z_index = 567
	var pages := Node2D.new()
	pages.name = "Characters"
	scene.add_child(pages)
	for character: int in [0,1]:
		var hud := HudSeed.new()
		pages.add_child(hud)
		hud.configure(catalog,theme_resource,character,{"skills":567,"hp":791,"mp":789,"hud":2623})
		hud.name = "CRT"+str(character)
		hud.z_index = 0
		hud.set_meta("character_id",character)
		hud._panel.name = "SkillPanel"
		_role(hud._panel,"panel")
		_fill(hud,hud.hp_fill,"HP")
		_fill(hud,hud.mp_fill,"MP")
		hud._gold.name = "Gold"
		_role(hud._gold,"gold")
		hud._gold.text = "0"
		hud._cubes.name = "ClearCubes"
		_role(hud._cubes,"cubes")
		hud._cubes.text = "200"
		for key: String in hud.skill_masks:
			var mask: Polygon2D = hud.skill_masks[key]
			mask.name = "Cooldown_"+key
			mask.set_meta("skill_key",key)
			mask.visible = false
			var vertices := PackedVector2Array()
			for point: Array in hud.geometry.skills[key].cooldown.start_vertices:vertices.append(Vector2(point[0],point[1]))
			mask.polygon = vertices
		hud._combo_group.name = "ComboLayout"
		_role(hud._combo_group,"combo")
		var motion := Node2D.new()
		motion.name = "NumberMotion"
		_role(motion,"combo_motion")
		hud._combo_group.add_child(motion)
		hud._combo_number.reparent(motion,false)
		hud._combo_number.name = "Number"
		_role(hud._combo_number,"combo_number")
		hud._combo_number.text = "1"
		hud._combo_group.visible = false
		for kind: String in hud._hover_views:
			var view: Dictionary = hud._hover_views[kind]
			view.group.name = kind.to_upper()+"HoverLayout"
			view.group.set_meta("hover_key",kind)
			view.group.visible = false
			for i in range(view.fields.size()):view.fields[i].name = "Value"+str(i)
			var data: Dictionary = catalog.source_geometry.battle_hud_feedback.hover[kind]
			var area := Control.new()
			area.name = kind.to_upper()+"HoverArea"
			area.position = Vector2(data.stage_position[0]+data.hit_rect[0],data.stage_position[1]+data.hit_rect[1])
			area.size = Vector2(data.hit_rect[2],data.hit_rect[3])
			area.mouse_filter = Control.MOUSE_FILTER_IGNORE
			area.set_meta("hover_target",kind)
			hud.add_child(area)
		for kind: String in hud._grenade_views:
			var view: Dictionary = hud._grenade_views[kind]
			view.group.name = "Grenade"+kind.to_upper()+"Layout"
			view.group.set_meta("grenade_key",kind)
			view.cover.name = "Cooldown"
			view.number.name = "Stock"
			view.group.visible = false
		hud.set_script(null)
		hud.visible = character == 0
	scene.set_script(load("res://scripts/ui/source_hud.gd"))
	_save(scene,path)

func _strip_signals(node: Node) -> void:
	for info: Dictionary in node.get_signal_list():
		for connection: Dictionary in node.get_signal_connection_list(info.name):
			node.disconnect(info.name,connection.callable)
	for child: Node in node.get_children():_strip_signals(child)

func _page_from(seed: Node, id: String, label_roles: Array) -> void:
	var page := Control.new()
	page.name = id.to_pascal_case()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.theme = theme_resource
	var label_index := 0
	for child: Node in seed.root.get_children():
		child.reparent(page,false)
		if child is Label:
			if label_index < label_roles.size():child.name = str(label_roles[label_index])
			label_index += 1
	_strip_signals(page)
	_save(page,"res://scenes/ui/"+id+".tscn")

func _build_pages() -> void:
	var seed := PageSeed.new()
	root.add_child(seed)
	seed.configure(catalog)
	var db = load("res://scripts/core/content_db.gd").new()
	db.load_all()
	var profile: Dictionary = load("res://scripts/services/save_store.gd").new().default_profile()
	seed.show_title(profile,"")
	_page_from(seed,"title",["Title","Gold","SaveMessage"])
	seed.show_characters(db.characters,"crt_0")
	_page_from(seed,"characters",["Title","Controls"])
	seed.show_characters(db.characters,"crt_0")
	_page_from(seed,"training_characters",["Title","Controls"])
	seed.show_difficulty(db.difficulties,profile)
	_page_from(seed,"difficulty",["Title","Locked","VolumeLabel"])
	seed.show_modes(db.modes,profile)
	_page_from(seed,"modes",["Title","Description","VolumeLabel"])
	seed.show_shop(profile,"crt_0")
	_page_from(seed,"shop",["Title","Gold","Item","Price","Inventory","Rules","ShopMessage"])
	seed.show_intro(db.stages.root_2)
	_page_from(seed,"intro",["Title","Details"])
	seed.show_dialogue({"frames":[{"texts":[{"text":"- 对话角色"},{"text":"对话内容"}]}],"space_target":1},0)
	_page_from(seed,"dialogue",["DialogueSpeaker","PageNumber","DialogueText","Hint"])
	seed.show_intermission({"title":"阶段中转"},{"earned_gold":0,"source_ticks":0})
	_page_from(seed,"intermission",["Title","Subtitle","Stats","Description"])
	seed.show_transition(35)
	_page_from(seed,"transition",["Title","Description","Timing"])
	seed.show_result("victory",{"earned_gold":0,"source_ticks":0},{"title":"场景","next_stage":"root_4"})
	seed._button("Retry","重新挑战本场",Vector2(115,230),Vector2(230,34),"retry")
	_page_from(seed,"result",["Title","Stats","Description"])
	seed.clear()
	seed.show_pause()
	_page_from(seed,"pause",["Title"])
	seed.show_error(["必要资源缺失时会在这里显示来源路径。"])
	_page_from(seed,"error",["Title","Details"])
	seed.clear()
	var data: Dictionary = catalog.source_geometry.battle_hud.training
	seed._source_button("Pause",str(data.menu.texture),data.menu.stage_position,"game_menu")
	var training := Control.new()
	training.name = "Training"
	training.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seed.root.add_child(training)
	for child: Node in [seed._source_art("training_instructions",data.instructions.stage_position),seed._source_art("training_title",data.title.stage_position),seed._source_button("TrainingRestore","training_restore_up",data.restore.stage_position,"training_restore","training_restore_over","training_restore_down"),seed._source_button("TrainingStorage","training_storage_up",data.storage.stage_position,"training_storage","training_storage_over","training_storage_down")]:child.reparent(training,false)
	seed._label("",Vector2(95,365),400,12).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed._label("",Vector2(10,205),530,9)
	seed.show_lab_hint()
	_page_from(seed,"battle_controls",["Toast","Debug","LabHint"])
	seed.free()

func _convert_buttons(node: Node) -> void:
	if node is BaseButton and node.get_script() != null:
		var frames: Dictionary = node.frames
		var artwork: Sprite2D = node.artwork
		var layout := Node2D.new()
		layout.name = "ArtworkLayout"
		layout.position = artwork.position
		node.add_child(layout)
		artwork.reparent(layout,false)
		artwork.position = Vector2.ZERO
		node.set_script(load("res://scripts/ui/source_button.gd"))
		for mode: String in ["up","over","down"]:
			if not frames.has(mode):continue
			var prefix: String = {"up":"normal","over":"hover","down":"pressed"}[mode]
			node.set(prefix+"_texture",frames[mode].texture)
			node.set(prefix+"_pivot",frames[mode].pivot)
	for child: Node in node.get_children():_convert_buttons(child)

func _menu_page(seed: Control, id: String) -> void:
	var page := Control.new()
	page.name = id.to_pascal_case()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.theme = theme_resource
	seed.panel_root.set_meta("panel_root",true)
	if is_instance_valid(seed.panel_sprite):seed.panel_sprite.set_meta("panel_sprite",true)
	if is_instance_valid(seed.volume_sprite):seed.volume_sprite.set_meta("volume_sprite",true)
	for key: String in seed.buttons:seed.buttons[key].set_meta("button_key",key)
	for key: String in seed.checkbox_sprites:seed.checkbox_sprites[key].set_meta("checkbox_key",key)
	for key: String in seed.storage_fields:seed.storage_fields[key].set_meta("storage_field",key)
	for child: Node in seed.get_children():child.reparent(page,false)
	_strip_signals(page)
	_convert_buttons(page)
	_save(page,"res://scenes/ui/"+id+".tscn")

func _build_menus() -> void:
	var seed := MenuSeed.new()
	root.add_child(seed)
	seed.configure(catalog,theme_resource,"root_41")
	var snapshot := {"settings":{"volume":0.8,"auto_save":false,"auto_quality":false}}
	for page: int in [2,3,6]:
		seed.show_menu(page,snapshot)
		_menu_page(seed,{2:"menu_keys",3:"menu_actions",6:"menu_settings"}[page])
	seed.show_failure(snapshot)
	_menu_page(seed,"menu_failure")
	var profile := {"progress":{"gold":0,"clear_cubes":200},"inventory":{"haring":1},"equipment":{"rings":{"crt_0":1,"crt_1":1,"crt_2":1,"crt_3":1}}}
	for page: int in [2,3,8]:
		if not catalog.source_geometry.source_ui.warehouse.pages.has(str(page)):continue
		seed.show_storage({"profile":profile,"storage_page":page,"ring_popup":true})
		if seed.buttons.has("warehouse_crt1_rings"):seed.buttons.warehouse_crt1_rings.tooltip_text = "戒指"
		_menu_page(seed,"warehouse_"+str(page))
	for frame in range(1,13):
		seed.show_dropdown(snapshot)
		seed.dropdown_frame = frame
		seed._draw_dropdown()
		_menu_page(seed,"dropdown_"+str(frame))
	seed.free()
