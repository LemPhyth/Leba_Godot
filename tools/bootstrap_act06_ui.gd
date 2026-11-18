extends SceneTree
## Explicit additive author migration. Existing pages/layouts keep their values.
func _initialize() -> void:call_deferred("_run")
func _owner(node: Node, root: Node) -> void:
	node.owner = root
	for child: Node in node.get_children():_owner(child,root)
func _save(node: Node, path: String) -> void:
	var packed := PackedScene.new()
	assert(packed.pack(node) == OK)
	assert(ResourceSaver.save(packed,path) == OK)
	node.free()
func _backup(path: String) -> void:
	var target := "res://artifacts/leba_act06_20261117/ui_before/"+path.trim_prefix("res://")
	if FileAccess.file_exists(target):return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target.get_base_dir()))
	assert(DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(target)) == OK)
func _run() -> void:
	if "--bootstrap-act06-ui" not in OS.get_cmdline_user_args():quit(2);return
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_catalog.json"))
	var path := "res://scenes/ui/source_hud.tscn"
	var hud: Node = load(path).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	if not hud.has_node("Characters/CRT4"):
		_backup(path)
		var page: Node2D = hud.get_node("Characters/CRT1").duplicate()
		hud.get_node("Characters").add_child(page)
		page.name = "CRT4";page.visible = false;page.set_meta("character_id",4)
		_owner(page,hud)
		var geometry: Dictionary = catalog.source_geometry.battle_hud_crt4
		page.get_node("SkillPanel").texture = load(catalog.textures.hud_panel_crt4_ready.path)
		for child: Node in page.get_children():
			if child.has_meta("skill_key") or child.name == "WAmmoLayout":
				page.remove_child(child);child.free()
		for key: String in geometry.skills:
			var spec: Dictionary = geometry.skills[key]
			if not spec.get("cooldown",{}).has("start_vertices"):continue
			var polygon := Polygon2D.new()
			polygon.name = "Cooldown_"+key
			polygon.position = Vector2(spec.stage_position[0],spec.stage_position[1])
			polygon.color = Color(0.004,0.004,0.004,float(spec.cooldown.get("alpha",0.6)))
			var vertices := PackedVector2Array()
			for vertex: Array in spec.cooldown.start_vertices:vertices.append(Vector2(vertex[0],vertex[1]))
			polygon.polygon = vertices;polygon.set_meta("skill_key",key)
			page.add_child(polygon);polygon.owner = hud
		_save(hud,path)
	else:hud.free()
	path = "res://scenes/ui/warehouse_6.tscn"
	if not FileAccess.file_exists(path):
		var warehouse: Node = load("res://scenes/ui/warehouse_4.tscn").instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
		warehouse.name = "Warehouse5"
		var panel: Sprite2D = warehouse.find_child("source_warehouse_crt2_weapons_panel",true,false)
		panel.name = "source_warehouse_crt4_shared_panel";panel.texture = load(catalog.textures.source_warehouse_crt4_shared_panel.path)
		var texture_data:Dictionary=catalog.textures.source_warehouse_crt4_shared_panel
		panel.position=-Vector2(texture_data.pivot[0],texture_data.pivot[1])
		var surface:Control=warehouse.find_child("PanelMouseSurface",true,false)
		surface.position=panel.position;surface.size=Vector2(texture_data.region[2],texture_data.region[3])
		surface.tooltip_text="角色3与角色4共用原作饰品栏；当前已接入戒指整备，其他交易尚未恢复。"
		var inventory:Node2D=warehouse.get_node("WarehouseRoot/InventoryRoot")
		for child:Node in inventory.get_children():
			if str(child.name).begins_with("Unsupported"):inventory.remove_child(child);child.free()
		var unsupported:Array=catalog.source_geometry.source_ui.warehouse.pages["6"].unsupported_controls
		for n in range(unsupported.size()):
			var record:Dictionary=unsupported[n];var m:Array=record.matrix;var r:Array=record.hit_rect_local
			var group:=Node2D.new();group.name="Unsupported"+str(n)
			group.transform=Transform2D(Vector2(m[0],m[1]),Vector2(m[2],m[3]),Vector2(m[4],m[5]))
			inventory.add_child(group)
			var control:=BaseButton.new();control.name="unsupported_"+str(n)
			control.set_script(load("res://scripts/ui/source_button.gd"))
			control.position=Vector2(r[0],r[1]);control.size=Vector2(r[2],r[3]);control.disabled=true
			control.tooltip_text=str(record.tooltip);control.set_meta("button_key",str(control.name))
			group.add_child(control)
		for child:Node in warehouse.get_children():_owner(child,warehouse)
		var ring: BaseButton = warehouse.find_child("warehouse_crt2_rings",true,false)
		ring.name = "warehouse_crt4_rings";ring.set_meta("button_key","warehouse_crt4_rings")
		for pair: Array in [["normal_texture","up"],["hover_texture","over"],["pressed_texture","down"]]:ring.set(pair[0],load(catalog.textures["source_warehouse_crt4_rings_"+str(pair[1])].path))
		_save(warehouse,path)
	path = "res://scenes/ui/source_menu.tscn"
	var menu: Node = load(path).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	if not menu.has_node("Pages/warehouse_6"):
		_backup(path)
		var page: Node = load("res://scenes/ui/warehouse_6.tscn").instantiate()
		page.name = "warehouse_6";page.visible = false
		menu.get_node("Pages").add_child(page);page.owner = menu
		_save(menu,path)
	else:menu.free()
	# Only new CRT4 depth overrides are added; CRT0/1 author transforms survive.
	for id: int in [2,4,6,9,41]:
		path = "res://scenes/stages/root_%d.tscn"%id
		var scene: Node = load(path).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
		if not scene.has_meta("act06_crt4_hud"):
			_backup(path)
			var instance: Node2D = scene.get_node("HUD")
			scene.set_editable_instance(instance,true)
			var depths: Dictionary = scene.rules.extra.source_depths
			instance.get_node("Characters/CRT4/HPLayout").z_index = int(depths.hp)-instance.z_index
			instance.get_node("Characters/CRT4/MPLayout").z_index = int(depths.mp)-instance.z_index
			scene.set_meta("act06_crt4_hud",true)
			_save(scene,path)
		else:scene.free()
	var index: Resource = load("res://content/index.tres")
	if not index.characters.any(func(item: Resource)->bool:return item.identifier == "crt_4"):
		_backup("res://content/index.tres")
		index.characters.append(load("res://content/characters/crt_4.tres"))
		assert(ResourceSaver.save(index,index.resource_path) == OK)
	print("ACT06 author HUD5/warehouse6/stage depth/index additive migration complete")
	quit()
