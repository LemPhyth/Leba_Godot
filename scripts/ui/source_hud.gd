extends Node2D
## Author layout lives in source_hud.tscn. Runtime only changes state children.
## Move Layout nodes, edit Artwork/font resources; FillState/NumberMotion are live clocks.
@export var use_stage_depths := false # Compatibility for an unmigrated stage only.
var catalog: Dictionary
var geometry: Dictionary
var state: Dictionary = {}
var hp_fill: Node2D
var mp_fill: Node2D
var skill_masks: Dictionary = {}
var _panel: Sprite2D
var _gold: Label
var _cubes: Label
var _combo_group: Node2D
var _combo_number: Label
var _combo_motion: Node2D
var _grenade_views: Dictionary = {}
var _hover_views: Dictionary = {}
var source_depths: Dictionary = {}
var _page: Node2D
var _roles: Dictionary = {}
var _w_ammo_layout: Node2D
var _w_ammo: Node2D

func configure(assets: Dictionary, _theme: Theme, character := 0, depths: Dictionary = {}) -> void:
	catalog = assets
	source_depths = depths
	var geometry_key := "battle_hud" if character == 0 else "battle_hud_crt%d"%character
	if not catalog.source_geometry.has(geometry_key):
		push_error("缺少角色HUD来源："+geometry_key)
		return
	geometry = catalog.source_geometry[geometry_key]
	var pages := get_node_or_null("Characters")
	if pages == null:
		push_error("SourceHUD requires scenes/ui/source_hud.tscn; a script-only node has no author layout.")
		return
	for child: Node2D in pages.get_children():
		child.visible = int(child.get_meta("character_id",-1)) == character
		if child.visible:_page = child
	_roles.clear()
	skill_masks.clear()
	_grenade_views.clear()
	_hover_views.clear()
	_scan(_page)
	_panel = _roles.panel
	hp_fill = _roles.hp_fill
	mp_fill = _roles.mp_fill
	_gold = _roles.gold
	_cubes = _roles.cubes
	_combo_group = _roles.combo
	_combo_number = _roles.combo_number
	_combo_motion = _roles.combo_motion
	_w_ammo_layout = _roles.get("w_ammo_layout")
	_w_ammo = _roles.get("w_ammo")
	if use_stage_depths:
		# Only the compatibility instance created for a legacy stage uses this.
		# A saved stage-owned HUD never reapplies catalog placement or source z.
		z_index = int(depths.get("skills",567))
		_roles.hp_layout.z_index = int(depths.get("hp",791))-z_index
		_roles.mp_layout.z_index = int(depths.get("mp",789))-z_index
		for view: Dictionary in _grenade_views.values():view.group.z_index = int(depths.get("hud",2623))
		if is_instance_valid(_w_ammo_layout):_w_ammo_layout.z_index = int(depths.get("hud",2623))

func _scan(node: Node) -> void:
	if node.has_meta("ui_role"):_roles[str(node.get_meta("ui_role"))] = node
	if node.has_meta("skill_key"):skill_masks[str(node.get_meta("skill_key"))] = node
	if node.has_meta("grenade_key"):
		_grenade_views[str(node.get_meta("grenade_key"))] = {"group":node,"cover":node.get_node("Cooldown"),"number":node.get_node("Stock")}
	if node.has_meta("hover_key"):
		var key := str(node.get_meta("hover_key"))
		var view: Dictionary = _hover_views.get(key,{})
		view.merge({"group":node,"fields":[node.get_node("Value0"),node.get_node("Value1")]},true)
		_hover_views[key] = view
	if node.has_meta("hover_target"):
		var key := str(node.get_meta("hover_target"))
		var view: Dictionary = _hover_views.get(key,{})
		view.target = node
		_hover_views[key] = view
	for child: Node in node.get_children():_scan(child)

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
		mask.visible = present and bool(slot.visible_slot) and not bool(live.ready)
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


func _update_feedback() -> void:
	if is_instance_valid(_w_ammo):
		var ammo_frame := int(state.get("crt1",{}).get("w_ammo_frame",1))
		_w_ammo_layout.visible = ammo_frame in range(2,22) and not bool(state.get("ended",false))
		if _w_ammo.source_frame != ammo_frame:_w_ammo.set_source_frame(ammo_frame)
	var feedback: Dictionary = catalog.source_geometry.battle_hud_feedback
	var frame := int(state.get("combo_frame",1))
	_combo_group.visible = frame > 1 and int(state.get("combo",0)) > 0
	if _combo_group.visible:
		_combo_number.text = str(int(state.combo))
		for row: Dictionary in feedback.combo.frames[str(frame)]:
			if not bool(row.dynamic):continue
			var m: Array = row.matrix
			var bounds: Dictionary = feedback.combo.number_fields[str(int(row.source_id))].bounds_twips
			_combo_motion.scale = Vector2(m[0],m[3])
			_combo_motion.position = Vector2(feedback.combo.stage_position[0]+m[4]+float(bounds.Xmin)/20.0*m[0],feedback.combo.stage_position[1]+m[5]+float(bounds.Ymin)/20.0*m[3])
	for kind: String in _grenade_views:
		var item: Dictionary = state.get("grenades",{}).get(kind,{"active":false,"stock":0,"icon_frame":1})
		var view: Dictionary = _grenade_views[kind]
		view.group.visible = bool(item.active) and not bool(state.get("ended",false)) #6917 page2 removes its page1 inventory children.
		view.cover.visible = int(item.icon_frame) > 1
		view.number.text = str(int(item.stock))
	for kind: String in _hover_views:
		var target: Control = _hover_views[kind].target
		_hover_views[kind].group.visible = target.get_global_rect().has_point(target.get_global_mouse_position())
		var fields: Array = _hover_views[kind].fields
		fields[0].text = str(int(state.hp if kind == "hp" else state.mp))
		fields[1].text = str(int(state.max_hp if kind == "hp" else state.max_mp))
