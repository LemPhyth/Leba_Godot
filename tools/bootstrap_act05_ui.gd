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
	var target := "res://artifacts/leba_act05_20261117/ui_before/"+path.trim_prefix("res://")
	if FileAccess.file_exists(target):return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target.get_base_dir()))
	assert(DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(target)) == OK)
func _run() -> void:
	if "--bootstrap-act05-ui" not in OS.get_cmdline_user_args():quit(2);return
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_catalog.json"))
	var path := "res://scenes/ui/source_hud.tscn"
	var hud: Node = load(path).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	if not hud.has_node("Characters/CRT3"):
		_backup(path)
		var page: Node2D = hud.get_node("Characters/CRT1").duplicate()
		hud.get_node("Characters").add_child(page)
		page.name = "CRT3";page.visible = false;page.set_meta("character_id",3)
		_owner(page,hud)
		var geometry: Dictionary = catalog.source_geometry.battle_hud_crt3
		page.get_node("SkillPanel").texture = load(catalog.textures.hud_panel_crt3_ready.path)
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
	path = "res://scenes/ui/warehouse_5.tscn"
	if not FileAccess.file_exists(path):
		var warehouse: Node = load("res://scenes/ui/warehouse_4.tscn").instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
		warehouse.name = "Warehouse5"
		var panel: Sprite2D = warehouse.find_child("source_warehouse_crt2_weapons_panel",true,false)
		panel.name = "source_warehouse_crt3_weapons_panel";panel.texture = load(catalog.textures.source_warehouse_crt3_weapons_panel.path)
		var ring: BaseButton = warehouse.find_child("warehouse_crt2_rings",true,false)
		ring.name = "warehouse_crt3_rings";ring.set_meta("button_key","warehouse_crt3_rings")
		for pair: Array in [["normal_texture","up"],["hover_texture","over"],["pressed_texture","down"]]:ring.set(pair[0],load(catalog.textures["source_warehouse_crt3_rings_"+str(pair[1])].path))
		_save(warehouse,path)
	path = "res://scenes/ui/source_menu.tscn"
	var menu: Node = load(path).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	if not menu.has_node("Pages/warehouse_5"):
		_backup(path)
		var page: Node = load("res://scenes/ui/warehouse_5.tscn").instantiate()
		page.name = "warehouse_5";page.visible = false
		menu.get_node("Pages").add_child(page);page.owner = menu
		_save(menu,path)
	else:menu.free()
	# Only new CRT3 depth overrides are added; CRT0/1 author transforms survive.
	for id: int in [2,4,6,9,41]:
		path = "res://scenes/stages/root_%d.tscn"%id
		var scene: Node = load(path).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
		if not scene.has_meta("act05_crt3_hud"):
			_backup(path)
			var instance: Node2D = scene.get_node("HUD")
			scene.set_editable_instance(instance,true)
			var depths: Dictionary = scene.rules.extra.source_depths
			instance.get_node("Characters/CRT3/HPLayout").z_index = int(depths.hp)-instance.z_index
			instance.get_node("Characters/CRT3/MPLayout").z_index = int(depths.mp)-instance.z_index
			scene.set_meta("act05_crt3_hud",true)
			_save(scene,path)
		else:scene.free()
	var index: Resource = load("res://content/index.tres")
	if not index.characters.any(func(item: Resource)->bool:return item.identifier == "crt_3"):
		_backup("res://content/index.tres")
		index.characters.append(load("res://content/characters/crt_3.tres"))
		assert(ResourceSaver.save(index,index.resource_path) == OK)
	print("ACT05 author HUD4/warehouse5/stage depth/index additive migration complete")
	quit()
