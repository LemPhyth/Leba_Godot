extends SceneTree
## Isolated silent native component validation; never loads Main or a player save.
var checks := 0
var failures := 0
var events: Array = []
var results: Array[Dictionary] = []
var output := ""
var author_hashes: Dictionary = {}
var formal_hash := ""
var formal_exists := false

func _initialize() -> void:call_deferred("run")

func check(label: String, passed: bool) -> void:
	checks += 1
	results.append({"name":label,"passed":passed})
	if not passed:
		failures += 1
		push_error(label)

func click(viewport: SubViewport, button: BaseButton) -> void:
	var at := button.get_global_transform_with_canvas()*(button.size*0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	viewport.push_input(motion,true)
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		viewport.push_input(event,true)
		await process_frame

func _hash_tree(path: String, result: Dictionary) -> void:
	var directory := DirAccess.open(path)
	if directory == null:return
	for name_: String in directory.get_files():
		if name_.get_extension() in ["tscn","tres","gd"]:result[path.path_join(name_)] = FileAccess.get_sha256(path.path_join(name_))
	for name_: String in directory.get_directories():
		if name_ != "_bootstrap":_hash_tree(path.path_join(name_),result)

func run() -> void:
	output = OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if output.is_empty():output = "res://artifacts/leba_act03_20261116/ui/author01"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	_hash_tree("res://scenes/ui",author_hashes)
	_hash_tree("res://scripts/ui",author_hashes)
	formal_exists = FileAccess.file_exists("user://profile.json")
	if formal_exists:formal_hash = FileAccess.get_sha256("user://profile.json")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_catalog.json"))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(550,400)
	viewport.handle_input_locally = true
	root.add_child(viewport)
	var ui = load("res://scenes/ui/game_ui.tscn").instantiate()
	viewport.add_child(ui)
	ui.configure(catalog)
	ui.intent.connect(func(action:String,value:Variant):events.append([action,value]))
	var profile := {"progress":{"gold":3500,"clear_cubes":200},"selection":{"character_id":"crt_0","difficulty_id":"expert"},"settings":{"volume":0.65,"auto_save":false,"auto_quality":false},"inventory":{"haring":1},"equipment":{"rings":{"crt_0":1,"crt_1":0,"crt_2":0,"crt_3":0}}}
	ui.show_title(profile,"")
	await process_frame
	var title_button: BaseButton = ui.get_button("Training")
	var first_id := title_button.get_instance_id()
	title_button.position += Vector2(7,3)
	var edited := title_button.position
	await click(viewport,title_button)
	check("native edited training target emits training",events.back() == ["training",null])
	ui.show_training_characters({"crt_0":{"title":"角色0","enabled":true},"crt_1":{"title":"角色1","enabled":true}},"crt_0")
	await click(viewport,ui.get_button("Character_crt_1"))
	check("training selector emits selected character1",events.back() == ["select_training_character","crt_1"])
	ui.show_title(profile,"")
	check("title page identity and authored position survive switching",ui.get_button("Training").get_instance_id() == first_id and ui.get_button("Training").position == edited)
	ui.root.position = Vector2(3,4)
	ui.set_world_offset(Vector2(0,20))
	ui.clear()
	check("clear preserves author root offset",ui.root.position == Vector2(3,4))
	ui.root.position = Vector2.ZERO
	ui.show_intermission({"title":"root7","next_stage":"root_9","allow_inventory":true,"allow_retry":true},{})
	await click(viewport,ui.get_button("Continue"))
	check("intermission continue intent",events.back() == ["intermission_continue",null])
	ui.show_intermission({"title":"root10","next_stage":"","allow_inventory":true},{})
	check("unrestored next branch remains explicitly disabled",ui.get_button("Continue").disabled)
	var menu: Control = ui.source_menu
	ui.clear()
	var snapshot := {"settings":profile.settings,"profile":profile,"storage_page":8,"ring_popup":true}
	ui.show_source_overlay("menu",snapshot,"root_41",3)
	await process_frame
	var retry: BaseButton = menu.buttons.menu_retry
	var retry_id := retry.get_instance_id()
	retry.position += Vector2(4,2)
	var retry_edit := retry.position
	await click(viewport,retry)
	check("native original menu target emits retry after authored edit",events.back() == ["retry",null])
	ui.show_source_overlay("menu",snapshot,"root_41",6)
	await click(viewport,menu.buttons.volume_50)
	check("source volume target emits true value",events.back() == ["volume",0.5])
	check("menu snapshot does not mutate profile",profile.settings.volume == 0.65)
	ui.show_source_overlay("menu",snapshot,"root_41",3)
	check("source menu switching preserves button identity and layout",menu.buttons.menu_retry.get_instance_id() == retry_id and menu.buttons.menu_retry.position == retry_edit)
	ui.show_source_overlay("storage",snapshot,"root_41")
	await click(viewport,menu.buttons.ring_equip_crt1)
	check("warehouse saved native target emits equip",events.back() == ["storage_action",{"operation":"equip","character_id":"crt_1"}])
	snapshot.storage_page = 3
	ui.show_source_overlay("storage",snapshot,"root_41")
	check("CRT1 warehouse uses original2728 page3 art rather than renamed CRT0",menu.current_page == 3 and menu.panel_sprite.texture.resource_path == catalog.textures.source_warehouse_crt1_weapons_panel.path and menu.panel_sprite.texture.resource_path != catalog.textures.source_warehouse_weapons_panel.path)
	check("CRT1 warehouse actual source fields read the one profile",menu.storage_fields.gold.text == "3500" and menu.storage_fields.clear_cubes.text == "200" and menu.storage_fields.pama_stones.text == "0")
	await click(viewport,menu.buttons.warehouse_crt1_rings)
	check("original2639 CRT1 ring category requests source page8",events.back() == ["storage_page",8])
	await click(viewport,menu.buttons.warehouse_weapons)
	check("original2635 weapon target preserves source page2 intention",events.back() == ["storage_page",2])
	ui.show_source_overlay("dropdown",snapshot,"root_41")
	menu.set_process(false)
	for i in range(4):menu._process(0.04)
	var dropdown_id: int = menu.buttons.dropdown_settings.get_instance_id()
	menu._process(0.04)
	check("dropdown6 to7 keeps real held-button instance",menu.dropdown_frame == 7 and menu.buttons.dropdown_settings.get_instance_id() == dropdown_id)
	var hud = load("res://scenes/ui/source_hud.tscn").instantiate()
	viewport.add_child(hud)
	var author: Node2D = hud.get_node("Characters/CRT0/HPLayout")
	author.position += Vector2(12,9)
	var author_position := author.position
	hud.configure(catalog,ui.theme_resource,0,{"skills":99,"hp":100})
	hud.update_state({"hp":65.0,"max_hp":130.0,"mp":32.5,"max_mp":130.0,"gold":9,"clear_cubes":199,"skill_slots":{}})
	check("HUD state ratio updates without author layout or depth reset",is_equal_approx(hud.hp_fill.scale.x,0.5) and author.position == author_position and hud.z_index == 567)
	hud.configure(catalog,ui.theme_resource,1,{})
	check("saved CRT1 HUD page is actual selected presentation",hud.get_node("Characters/CRT1").visible and not hud.get_node("Characters/CRT0").visible)
	check("CRT1 author page includes each default source slot without copying CRT0 keys",hud.skill_masks.size() == 14 and hud.skill_masks.has("revenger") and not hud.skill_masks.has("y"))
	var slots: Dictionary = {}
	for key: String in catalog.source_geometry.battle_hud_crt1.skills:slots[key] = {"frame":2,"ready":false}
	hud.update_state({"hp":90.0,"max_hp":100.0,"mp":70.0,"max_mp":100.0,"gold":9,"clear_cubes":199,"skill_slots":slots})
	check("CRT1 live source cooldowns retain visible V and hidden replacementZ",hud.skill_masks.v.visible and hud.skill_masks.revenger.visible and not hud.skill_masks.z.visible and hud.skill_masks.t.polygon.size() == 5)
	var t_mask: Polygon2D = hud.skill_masks.t
	t_mask.position += Vector2(9,6)
	var mask_position := t_mask.position
	hud.update_state({"hp":90.0,"max_hp":100.0,"mp":70.0,"max_mp":100.0,"gold":9,"clear_cubes":199,"skill_slots":slots})
	check("live source morph never overwrites saved mask placement",t_mask.position == mask_position)
	var w_layout: Node2D = hud.get_node("Characters/CRT1/WAmmoLayout")
	var w_frame: Node2D = w_layout.get_node("FrameState")
	var w_snapshot := {"hp":90.0,"max_hp":100.0,"mp":70.0,"max_mp":100.0,"gold":9,"clear_cubes":199,"skill_slots":slots,"crt1":{"w_ammo_frame":2}}
	hud.update_state(w_snapshot)
	check("W ammo HUD consumes actual source2 frame with no independent counter",w_layout.visible and w_frame.source_frame == 2 and hud.state.crt1.w_ammo_frame == 2)
	check("W6884 uses6917 stage ancestor once and keeps baked child offset",w_layout.position.is_equal_approx(Vector2(742.15,284.6)) and w_frame.position == Vector2.ZERO and (w_layout.position-Vector2(w_frame.frame.pivot[0],w_frame.frame.pivot[1])).is_equal_approx(Vector2(37,327.15)))
	w_layout.position += Vector2(8,11)
	var w_position := w_layout.position
	w_snapshot.crt1.w_ammo_frame = 21
	hud.update_state(w_snapshot)
	check("last W round selects source21 without overwriting author layout",w_frame.source_frame == 21 and w_layout.visible and w_layout.position == w_position)
	w_snapshot.crt1.w_ammo_frame = 1
	hud.update_state(w_snapshot)
	check("inactive W inventory is hidden by actual source1",w_frame.source_frame == 1 and not w_layout.visible)
	# Save/reopen a separate isolated author-scene copy, never the repo source.
	var authored = load("res://scenes/ui/menu_actions.tscn").instantiate()
	var edited_button: BaseButton = authored.find_child("menu_retry",true,false)
	var old_hit := edited_button.get_global_rect().get_center()
	edited_button.position += Vector2(60,80)
	var packed := PackedScene.new()
	check("author page can pack for native saving",packed.pack(authored) == OK)
	var path := output.path_join("author_menu_actions.tscn")
	check("isolated native author scene saves",ResourceSaver.save(packed,path) == OK)
	var reopened = load(path).instantiate()
	check("reopened native author scene retains edited hit target",reopened.find_child("menu_retry",true,false).position == edited_button.position)
	ui.clear()
	hud.visible = false
	viewport.add_child(reopened)
	await process_frame
	var saved_button: BaseButton = reopened.find_child("menu_retry",true,false)
	var saved_clicks := [0]
	saved_button.pressed.connect(func():saved_clicks[0] += 1)
	await click(viewport,saved_button)
	check("saved and reloaded native button receives GUI at moved hit area",saved_clicks[0] == 1)
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = old_hit
		event.global_position = old_hit
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		viewport.push_input(event,true)
		await process_frame
	check("saved hit region no longer accepts former source position",saved_clicks[0] == 1)
	var after_hashes: Dictionary = {}
	_hash_tree("res://scenes/ui",after_hashes)
	_hash_tree("res://scripts/ui",after_hashes)
	check("author UI scenes resources and scripts are untouched by runtime and isolated save",author_hashes == after_hashes)
	check("formal profile existence and bytes are unchanged",FileAccess.file_exists("user://profile.json") == formal_exists and (not formal_exists or FileAccess.get_sha256("user://profile.json") == formal_hash))
	reopened.queue_free()
	authored.free()
	viewport.queue_free()
	await process_frame
	var report := {"suite":"act03_ui","checks":results,"failures":failures,"events":events,"author_hashes":author_hashes,"saved_scene":path,"scope":"Headless Dummy actual native SubViewport mouse input and isolated PackedScene save/reopen; real author layouts and hit rectangles. No OS/editor human acceptance or full gameplay claim."}
	var file := FileAccess.open(output.path_join("act03_ui_tests.json"),FileAccess.WRITE)
	if file != null:file.store_string(JSON.stringify(report,"\t")+"\n")
	print("ACT03_UI_TESTS_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures == 0 else 1)
