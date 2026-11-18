extends Node2D
## Render original HUD parts from authoritative Battle snapshots. No game state lives here.
var catalog: Dictionary
var geometry: Dictionary
var state: Dictionary = {}
var hp_fill: Sprite2D
var mp_fill: Sprite2D
var skill_masks: Dictionary = {}
var _panel: Sprite2D
var _gold: Label
var _cubes: Label
var _combo_group: Node2D
var _combo_number: Label
var _grenade_views: Dictionary = {}
var _hover_views: Dictionary = {}
var source_depths: Dictionary = {}

func configure(assets: Dictionary, theme: Theme, character := 0, depths: Dictionary = {}) -> void:
	catalog = assets
	source_depths = depths
	name = "SourceHUD"
	z_index = int(depths.get("skills",567))
	geometry = catalog.source_geometry.battle_hud_crt1 if character == 1 else catalog.source_geometry.battle_hud
	_panel = _sprite(str(geometry.panel.texture),geometry.panel.stage_position)
	hp_fill = _sprite(str(geometry.hp.texture),geometry.hp.stage_position)
	hp_fill.z_index = int(depths.get("hp",int(geometry.hp.source_depth)))-z_index
	mp_fill = _sprite(str(geometry.mp.texture),geometry.mp.stage_position)
	mp_fill.z_index = int(depths.get("mp",int(geometry.mp.source_depth)))-z_index
	for key: String in geometry.skills:
		var slot: Dictionary = geometry.skills[key]
		if not bool(slot.visible_slot):continue
		var mask := Polygon2D.new()
		mask.color = Color(0,0,0,float(slot.cooldown.alpha))
		mask.position = Vector2(slot.stage_position[0],slot.stage_position[1])
		add_child(mask)
		skill_masks[key] = mask
	_gold = _field(geometry.dynamic_fields.gold,theme)
	_cubes = _field(geometry.dynamic_fields.clear_cubes,theme)
	_build_feedback(theme,character)

func _sprite(key: String, at: Array) -> Sprite2D:
	var data: Dictionary = catalog.textures[key]
	var sprite := Sprite2D.new()
	sprite.texture = load(str(data.path))
	sprite.centered = false
	sprite.position = Vector2(at[0]-data.pivot[0],at[1]-data.pivot[1])
	add_child(sprite)
	return sprite

func _field(data: Dictionary, theme: Theme) -> Label:
	var label := Label.new()
	label.theme = theme
	var font_key: String = {1557:"inventory",2171:"numeric",1599:"combo"}.get(int(data.font_id),"ui")
	label.add_theme_font_override("font",load(str(catalog.fonts[font_key])))
	label.add_theme_font_size_override("font_size",int(data.font_height_px))
	label.position = Vector2(data.stage_position[0]-2,data.stage_position[1]-2)
	label.size = Vector2(float(data.bounds_twips.Xmax)/20.0,14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if str(data.source_definition.align) == "1" else HORIZONTAL_ALIGNMENT_LEFT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func update_state(snapshot: Dictionary) -> void:
	state = snapshot.duplicate(true)
	var present := int(state.get("skill_bar_frame",1)) != 7
	_panel.visible = present
	hp_fill.scale.x = clampf(float(state.hp)/float(state.max_hp),0.0,1.0)
	mp_fill.scale.x = clampf(float(state.mp)/float(state.max_mp),0.0,1.0)
	_gold.text = str(int(state.gold))
	_cubes.text = str(int(state.get("clear_cubes",0)))
	_gold.visible = present
	_cubes.visible = present
	for key: String in skill_masks:
		var slot: Dictionary = geometry.skills[key]
		var live: Dictionary = state.get("skill_slots",{}).get(key,{"frame":1,"ready":true})
		var mask: Polygon2D = skill_masks[key]
		mask.visible = present and not bool(live.ready)
		if not mask.visible:continue
		var morph: Dictionary = slot.cooldown
		var ratio := float(morph.ratio_by_source_frame.get(str(live.frame),0))/float(morph.ratio_denominator)
		var vertices := PackedVector2Array()
		for i in range(morph.start_vertices.size()):
			var a: Array = morph.start_vertices[i]
			var b: Array = morph.end_vertices[i]
			vertices.append(Vector2(lerpf(a[0],b[0],ratio),lerpf(a[1],b[1],ratio)))
		mask.polygon = vertices
	_update_feedback()

func _build_feedback(theme: Theme, character: int) -> void:
	var feedback: Dictionary = catalog.source_geometry.battle_hud_feedback
	var combo_data: Dictionary = feedback.combo
	_combo_group = Node2D.new()
	_combo_group.z_as_relative = false
	_combo_group.z_index = 4095
	add_child(_combo_group)
	var art := _sprite(str(combo_data.label_texture),[combo_data.stage_position[0]+combo_data.label_offset_px[0],combo_data.stage_position[1]+combo_data.label_offset_px[1]])
	remove_child(art)
	_combo_group.add_child(art)
	_combo_number = Label.new()
	_combo_number.theme = theme
	_combo_number.add_theme_font_override("font",load(str(catalog.fonts.combo)))
	_combo_number.add_theme_font_size_override("font_size",35)
	_combo_number.add_theme_color_override("font_color",Color("0066ff"))
	_combo_number.add_theme_color_override("font_outline_color",Color.BLACK)
	_combo_number.add_theme_constant_override("outline_size",5)
	_combo_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_number.size = Vector2(102.6,40.55)
	_combo_group.add_child(_combo_number)
	for kind: String in feedback.hover:
		var data: Dictionary = feedback.hover[kind]
		var group := Node2D.new()
		group.z_index = 300
		add_child(group)
		var label_art := _sprite(str(data.texture),data.stage_position)
		remove_child(label_art)
		group.add_child(label_art)
		var fields: Array[Label] = []
		for field: Dictionary in data.fields:
			var label := _numeric_field(field,theme)
			label.position += Vector2(data.stage_position[0],data.stage_position[1])
			group.add_child(label)
			fields.append(label)
		_hover_views[kind] = {"group":group,"fields":fields}
	if character != 0:return
	for kind: String in feedback.grenades:
		var data: Dictionary = feedback.grenades[kind]
		var group := Node2D.new()
		group.z_as_relative = false
		group.z_index = int(source_depths.get("hud",2623))
		add_child(group)
		var panel := _sprite(str(data.panel_texture),data.stage_position)
		remove_child(panel)
		group.add_child(panel)
		var at := [data.stage_position[0]+data.icon_matrix[4],data.stage_position[1]+data.icon_matrix[5]]
		var icon := _sprite(str(data.icon_texture),at)
		remove_child(icon)
		group.add_child(icon)
		var cd: Array = data.independent_icon_clock.cooldown_matrix
		var cover := _sprite(str(data.independent_icon_clock.cooldown_texture),[at[0]+cd[4],at[1]+cd[5]])
		cover.modulate.a = float(data.independent_icon_clock.cooldown_alpha_mult)/256.0
		remove_child(cover)
		group.add_child(cover)
		var number := _numeric_field(data.number_field,theme)
		number.position += Vector2(data.stage_position[0],data.stage_position[1])
		group.add_child(number)
		_grenade_views[kind] = {"group":group,"cover":cover,"number":number}

func _numeric_field(data: Dictionary, theme: Theme) -> Label:
	var label := Label.new()
	label.theme = theme
	var key := "numeric" if int(data.font_id) == 2171 else "inventory"
	label.add_theme_font_override("font",load(str(catalog.fonts[key])))
	label.add_theme_font_size_override("font_size",int(data.font_height_px))
	var color: Array = data.color_rgba
	label.add_theme_color_override("font_color",Color(color[0]/255.0,color[1]/255.0,color[2]/255.0,color[3]/255.0))
	var bounds: Dictionary = data.bounds_twips
	var m: Array = data.matrix
	label.scale = Vector2(m[0],m[3])
	label.position = Vector2(m[4]+float(bounds.Xmin)/20.0*m[0],m[5]+float(bounds.Ymin)/20.0*m[3])
	label.size = Vector2((float(bounds.Xmax)-float(bounds.Xmin))/20.0,(float(bounds.Ymax)-float(bounds.Ymin))/20.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if int(data.align) == 2 else HORIZONTAL_ALIGNMENT_RIGHT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _update_feedback() -> void:
	var feedback: Dictionary = catalog.source_geometry.battle_hud_feedback
	var frame := int(state.get("combo_frame",1))
	_combo_group.visible = frame > 1 and int(state.get("combo",0)) > 0
	if _combo_group.visible:
		_combo_number.text = str(int(state.combo))
		for row: Dictionary in feedback.combo.frames[str(frame)]:
			if not bool(row.dynamic):continue
			var m: Array = row.matrix
			var bounds: Dictionary = feedback.combo.number_fields[str(int(row.source_id))].bounds_twips
			_combo_number.scale = Vector2(m[0],m[3])
			_combo_number.position = Vector2(feedback.combo.stage_position[0]+m[4]+float(bounds.Xmin)/20.0*m[0],feedback.combo.stage_position[1]+m[5]+float(bounds.Ymin)/20.0*m[3])
	for kind: String in _grenade_views:
		var item: Dictionary = state.get("grenades",{}).get(kind,{"active":false,"stock":0,"icon_frame":1})
		var view: Dictionary = _grenade_views[kind]
		view.group.visible = bool(item.active) and not bool(state.get("ended",false)) #6917 page2 removes its page1 inventory children.
		view.cover.visible = int(item.icon_frame) > 1
		view.number.text = str(int(item.stock))
	for kind: String in _hover_views:
		var data: Dictionary = feedback.hover[kind]
		var origin := Vector2(data.stage_position[0],data.stage_position[1])
		var r: Array = data.hit_rect
		_hover_views[kind].group.visible = Rect2(origin+Vector2(r[0],r[1]),Vector2(r[2],r[3])).has_point(get_local_mouse_position())
		var fields: Array = _hover_views[kind].fields
		fields[0].text = str(int(state.hp if kind == "hp" else state.mp))
		fields[1].text = str(int(state.max_hp if kind == "hp" else state.max_mp))
