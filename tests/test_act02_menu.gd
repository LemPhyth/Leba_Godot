extends SceneTree
## Isolated source-menu GUI dispatch. Headless Dummy; no Main/Battle/OS window.
## Native Viewport mouse events validate hit areas and signals, not PNG pixels.
const SourceMenu = preload("res://scenes/ui/source_menu.tscn")
var viewport: SubViewport
var host: Control
var view: Control
var catalog: Dictionary
var checks: Array[Dictionary] = []
var received: Array[Dictionary] = []
var before_exists := false
var before_hash := ""

func _initialize() -> void:call_deferred("_run")

func _check(name: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"name":name,"passed":passed,"detail":detail})
	print(("PASS " if passed else "FAIL ")+name+" "+str(detail))

func _near(a: Vector2,b: Vector2) -> bool:return a.distance_to(b) < 0.0001

func _snapshot(volume := 0.65, auto_save := false, auto_quality := false) -> Dictionary:
	return {"stage":"root_41","mode":"training","training":true,"hp":130.0,"settings":{"volume":volume,"auto_save":auto_save,"auto_quality":auto_quality}}

func _motion(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	viewport.push_input(event,true)
	await process_frame

func _mouse(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	viewport.push_input(event,true)
	await process_frame

func _click(key: String) -> void:
	var button: BaseButton = view.buttons[key]
	var center: Vector2 = button.get_global_rect().get_center()
	await _motion(center)
	await _mouse(center,true)
	await _mouse(center,false)

func _last(action: String, value: Variant = null) -> bool:
	return not received.is_empty() and received[-1].action == action and received[-1].value == value

func _run() -> void:
	before_exists = FileAccess.file_exists("user://profile.json")
	if before_exists:before_hash = FileAccess.get_sha256("user://profile.json")
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_catalog.json"))
	viewport = SubViewport.new()
	viewport.name = "IsolatedMenuViewport"
	viewport.size = Vector2i(550,400)
	viewport.disable_3d = true
	root.add_child(viewport)
	host = Control.new()
	host.size = Vector2(550,400)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(host)
	var hud := Control.new()
	hud.name = "ExistingHUDSentinel"
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(hud)
	view = SourceMenu.instantiate()
	host.add_child(view)
	view.intent.connect(func(action:String,value:Variant)->void:received.append({"action":action,"value":value}))
	_check("source menu configures actual imported assets without Main",view.configure(catalog,Theme.new(),"root_41"),view.errors)
	if not view.ready_ok:
		_finish()
		return
	await process_frame
	await _test_panel_buttons()
	await _test_settings_snapshot()
	await _test_failure()
	await _test_dropdown()
	await _test_storage()
	view.show_menu(1,_snapshot())
	_check("source overlay hides only itself and preserves existing HUD sibling",not view.visible and is_instance_valid(hud) and hud.get_parent() == host and host.get_node("ExistingHUDSentinel") == hud)
	_check("menu presentation leaves formal profile unchanged",FileAccess.file_exists("user://profile.json") == before_exists and (not before_exists or FileAccess.get_sha256("user://profile.json") == before_hash))
	_check("isolated component has no source-resource errors",view.errors.is_empty(),view.errors)
	viewport.queue_free()
	await process_frame
	_finish()

func _test_panel_buttons() -> void:
	view.show_menu(3,_snapshot())
	await process_frame
	_check("source6956 actions panel keeps original root registration",_near(view.panel_root.position,Vector2(290.55,224.55)) and _near(view.panel_sprite.global_position,Vector2(142.55,126.0)))
	var button: BaseButton = view.buttons.menu_retry
	var rect: Rect2 = button.get_global_rect()
	_check("menu retry source transparent hit union is independent from cropped PNG",_near(rect.position,Vector2(213.55,184.55)) and _near(rect.size,Vector2(154.55,38.5)) and button.artwork.get_parent().position+button.artwork.position == -button.position-Vector2(75.05,17.0),rect)
	await _motion(rect.get_center())
	_check("native hover selects original over art",button.visual_state == "over" and button.artwork.texture.resource_path == catalog.textures.source_menu_retry_over.path)
	await _mouse(rect.get_center(),true)
	_check("native button down selects original down art without intent",button.visual_state == "down" and received.is_empty() and button.artwork.texture.resource_path == catalog.textures.source_menu_retry_down.path)
	await _mouse(rect.get_center(),false)
	_check("native release emits one retry intention",received.size() == 1 and _last("retry") and button.visual_state == "over")
	var count: int = received.size()
	await _mouse(rect.get_center(),true)
	await _motion(Vector2(30,30))
	await _mouse(Vector2(30,30),false)
	_check("release outside original hit region does not trigger retry",received.size() == count)
	# Leftmost0.5px of original union lies beyond the cropped visible background.
	await _motion(rect.position+Vector2(0.1,rect.size.y*0.5))
	await _mouse(rect.position+Vector2(0.1,rect.size.y*0.5),true)
	await _mouse(rect.position+Vector2(0.1,rect.size.y*0.5),false)
	_check("transparent original hit area remains clickable",received.size() == count+1 and _last("retry"))
	await _click("menu_return")
	_check("original return emits source_leave rather than inventing a destination",_last("source_leave"))
	await _click("close")
	_check("original close emits resume and leaves screen routing to owner",_last("resume") and view.visible)
	view.show_menu(2,_snapshot())
	await process_frame
	_check("source keys page displays only its original close button",view.buttons.keys() == ["close"] and view.panel_sprite.texture.resource_path == catalog.textures.source_menu_keys.path)
	await _click("close")
	_check("keys close uses same real resume intention",_last("resume"))

func _test_settings_snapshot() -> void:
	var supplied := _snapshot()
	var untouched: Dictionary = supplied.duplicate(true)
	view.show_menu(6,supplied)
	await process_frame
	_check("source settings root and background pivot are applied once",_near(view.panel_root.position,Vector2(290.55,224.55)) and _near(view.panel_sprite.global_position,Vector2(142.55,117.0)))
	_check("existing65percent displays original page1 without changing true volume",view.volume_sprite.texture.resource_path == catalog.textures.source_volume_100.path and supplied == untouched and view.state.settings.volume == 0.65 and "65" in view.buttons.volume_75.tooltip_text)
	for percent: int in [0,25,50,75,100]:
		var before: int = received.size()
		await _click("volume_"+str(percent))
		_check("native source volume target emits exact setting "+str(percent),received.size() == before+1 and _last("volume",percent/100.0))
	_check("setting clicks never optimistically rewrite caller or cached profile",supplied == untouched and view.state.settings.volume == 0.65 and view.volume_sprite.texture.resource_path == catalog.textures.source_volume_100.path)
	for percent: int in [0,25,50,75,80,100]:
		view.show_menu(6,_snapshot(percent/100.0))
		var expected := 100 if percent == 80 else percent
		_check("authoritative volume snapshot selects original page "+str(percent),view.volume_sprite.texture.resource_path == catalog.textures["source_volume_"+str(expected)].path and view.state.settings.volume == percent/100.0)
	view.show_menu(6,supplied)
	await process_frame
	var original_rect: Rect2 = view.buttons.auto_save.get_global_rect()
	await _click("auto_save")
	_check("source auto-save checkbox emits request without changing supplied state",_last("auto_save",true) and supplied == untouched and not view.state.settings.auto_save and view.checkbox_sprites.auto_save.texture.resource_path == catalog.textures.source_checkbox_off.path)
	view.show_menu(6,_snapshot(0.65,true,true))
	await process_frame
	_check("checked texture keeps original registration and unchanged transparent hit area",view.checkbox_sprites.auto_save.texture.resource_path == catalog.textures.source_checkbox_on.path and view.buttons.auto_save.get_global_rect().is_equal_approx(original_rect) and view.checkbox_sprites.auto_save.position+view.checkbox_sprites.auto_save.offset == -Vector2(21.5,34.25))
	await _click("auto_save")
	_check("owner-confirmed checked state emits disable request",_last("auto_save",false))
	for key: String in ["quality_high","quality_medium","quality_low","auto_quality"]:
		var count: int = received.size()
		await _click(key)
		_check("unmapped Flash option is visibly disabled and emits nothing: "+key,view.buttons[key].disabled and "尚未映射" in view.buttons[key].tooltip_text and received.size() == count)
	_check("unmapped existing auto-quality remains visible without changing profile",view.buttons.auto_quality.get_meta("source_checked") and view.checkbox_sprites.auto_quality.texture.resource_path == catalog.textures.source_checkbox_on.path and view.state.settings.auto_quality)

func _test_failure() -> void:
	for stage: String in ["root_2","root_4","root_6","root_41"]:
		_check("failure stage has source root placement: "+stage,view.configure(catalog,Theme.new(),stage))
		view.show_failure(_snapshot())
		await process_frame
		_check("failure preserves off-stage parent742.15 and actual art origin: "+stage,_near(view.panel_root.position,Vector2(742.15,284.6)) and _near(view.panel_sprite.global_position,Vector2(-1.4,0)) and _near(view.buttons.failure_retry.get_global_rect().position,Vector2(281.25,234.6)))
		await _click("failure_retry")
		_check("source failure retry emits owner-handled retry: "+stage,_last("retry"))
		await _click("failure_return")
		_check("source failure return emits root1 intention: "+stage,_last("source_leave"))
	# The hit unions overlap by5.7px. Original return depth7 must win over retry5.
	var count: int = received.size()
	await _motion(Vector2(284,245))
	await _mouse(Vector2(284,245),true)
	await _mouse(Vector2(284,245),false)
	_check("overlapping failure hits preserve original source depth priority",received.size() == count+1 and _last("source_leave"))

func _test_dropdown() -> void:
	view.configure(catalog,Theme.new(),"root_41")
	view.show_dropdown(_snapshot())
	view.set_process(false) # Presentation time supplied deterministically below.
	_check("source6934 starts opening2 at original root coordinates",view.dropdown_frame == 2 and _near(view.panel_root.position,Vector2(514.55,102.75)) and not view.buttons.has("dropdown_settings"))
	for tick in range(4):view._process(0.04)
	_check("source6934 creates navigation on6 before stopped7",view.dropdown_frame == 6 and view.buttons.has("dropdown_settings") and view.buttons.dropdown_top.disabled)
	await process_frame
	var pressed: BaseButton = view.buttons.dropdown_settings
	var point: Vector2 = pressed.get_global_rect().get_center()
	await _motion(point)
	await _mouse(point,true)
	view._process(0.04)
	_check("dropdown6 to7 retains original button instance during mouse press",view.dropdown_frame == 7 and view.buttons.dropdown_settings == pressed and pressed.is_pressed())
	await _mouse(point,false)
	_check("mouse held across source6 to7 releases one settings intention",_last("menu_page",6))
	for pair: Array in [["dropdown_actions",3],["dropdown_keys",2]]:
		await _click(pair[0])
		_check("original navigation emits actual source page "+str(pair[1]),_last("menu_page",pair[1]))
	var frame: int = view.dropdown_frame
	view._process(0.4)
	_check("original open7 stops despite elapsed presentation time",view.dropdown_frame == frame and frame == 7)
	await _click("dropdown_top")
	_check("original top release starts closing8 without immediate routing",view.dropdown_frame == 8 and view.visible)
	var before: int = received.size()
	for tick in range(5):view._process(0.04)
	_check("original control13 returns to1 and signals overlay close once",view.dropdown_frame == 1 and not view.visible and received.size() == before+1 and _last("resume"))
	view._process(1.0)
	_check("closed dropdown cannot repeat resume after timer end",received.size() == before+1)
	view.show_dropdown(_snapshot())
	view.set_process(false)
	view._process(0.02)
	_check("UI25FPS presentation does not confuse half a tick with a source frame",view.dropdown_frame == 2)
	view._process(0.02)
	_check("UI25FPS presentation advances at complete source tick",view.dropdown_frame == 3)
	for tick in range(4):view._process(0.04)
	_check("dropdown can reopen cleanly without stale buttons",view.dropdown_frame == 7 and view.buttons.size() == 4)

func _storage_snapshot(page := 2, popup := false) -> Dictionary:
	return {"storage_page":page,"ring_popup":popup,"character_id":"crt_0","profile":{"progress":{"gold":1234,"clear_cubes":77},"inventory":{"haring":1},"equipment":{"rings":{"crt_0":0,"crt_1":1,"crt_2":0,"crt_3":1}}}}

func _test_storage() -> void:
	view.configure(catalog,Theme.new(),"root_41")
	var supplied := _storage_snapshot()
	var original: Dictionary = supplied.duplicate(true)
	view.show_storage(supplied)
	await process_frame
	_check("original storage composes root7346 and child2728 once",_near(view.panel_root.global_position,Vector2(282.7,199.8)) and _near(view.panel_sprite.global_position,Vector2(121.75,3.05)))
	_check("storage numbers read authoritative profile rather than editor placeholders",view.storage_fields.gold.text == "1234" and view.storage_fields.clear_cubes.text == "77" and view.storage_fields.pama_stones.text == "0" and "尚未接入" in view.storage_fields.pama_stones.tooltip_text)
	_check("storage numeric source field keeps white color12px and right alignment",view.storage_fields.gold.get_theme_color("font_color") == Color.WHITE and view.storage_fields.gold.get_theme_font_size("font_size") == 12 and view.storage_fields.gold.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT and _near(view.storage_fields.gold.global_position,Vector2(369.8,341.95)))
	var unsupported: Array = view.buttons.keys().filter(func(key:Variant)->bool:return str(key).begins_with("unsupported_"))
	_check("original unsupported categories and arrows have explicit disabled hits",unsupported.size() == 11)
	var count: int = received.size()
	for key: String in unsupported:await _click(key)
	_check("unsupported storage controls never pretend a navigation succeeded",received.size() == count and unsupported.all(func(key:Variant)->bool:return view.buttons[key].disabled and "尚未接入" in view.buttons[key].tooltip_text))
	await _click("warehouse_rings")
	_check("source category click requests page8 without altering supplied data",_last("storage_page",8) and supplied == original and view.current_page == 2)
	view.show_storage(_storage_snapshot(8))
	await process_frame
	_check("owned ring and independently equipped actor slots are rendered separately",view.buttons.has("ring_owned") and view.buttons.has("ring_unequip_crt_1") and view.buttons.has("ring_unequip_crt_3") and not view.buttons.has("ring_unequip_crt_0") and not view.buttons.has("ring_unequip_crt_2"))
	var equipped: BaseButton = view.buttons.ring_unequip_crt_1
	var anchor: Vector2 = equipped.get_global_transform()*(-equipped.position)
	await _motion(equipped.get_global_rect().get_center())
	var art: Sprite2D = equipped.artwork
	var pivot: Array = catalog.textures.source_ring_unequip_over.pivot
	var rendered_registration: Vector2 = art.global_position+art.global_transform.basis_xform(Vector2(pivot[0],pivot[1]))
	_check("large original ring hover artwork keeps registration despite differing crop pivot",equipped.visual_state == "over" and art.texture.resource_path == catalog.textures.source_ring_unequip_over.path and _near(rendered_registration,anchor))
	await _click("ring_owned")
	_check("owned ring requests original character selector without equipping",_last("storage_ring_choose",true) and view.state.profile.equipment.rings.crt_0 == 0)
	view.show_storage(_storage_snapshot(8,true))
	await process_frame
	_check("source2615 popup preserves warehouse-relative registration",_near(view.panel_root.get_node("RingChoice").global_position,Vector2(280.9,178.8)))
	for index in range(4):
		await _click("ring_equip_crt"+str(index))
		_check("source equipment choice emits exact target character "+str(index),_last("storage_action",{"operation":"equip","character_id":"crt_"+str(index)}) and view.state.profile.equipment.rings == {"crt_0":0,"crt_1":1,"crt_2":0,"crt_3":1})
	await _click("ring_cancel")
	_check("source ring cancel changes no gameplay state",_last("storage_ring_choose",false) and supplied == original)
	var sold := _storage_snapshot(8)
	sold.profile.inventory.haring = 0
	view.show_storage(sold)
	await process_frame
	_check("sold owned flag does not hide remaining equipped source records",not view.buttons.has("ring_owned") and view.buttons.has("ring_unequip_crt_1") and view.buttons.has("ring_unequip_crt_3"))
	await _click("ring_unequip_crt_1")
	_check("source unequip delegates all-slot behavior to existing progression owner",_last("storage_action",{"operation":"unequip","character_id":"crt_1"}) and sold.profile.inventory.haring == 0 and sold.profile.equipment.rings.crt_3 == 1)
	var unknown := _storage_snapshot(8,true)
	unknown.profile.equipment.rings.crt_3 = 9
	view.show_storage(unknown)
	await process_frame
	count = received.size()
	await _click("ring_equip_crt3")
	_check("unimplemented equipped item cannot be overwritten through selector",view.buttons.ring_equip_crt3.disabled and received.size() == count and unknown.profile.equipment.rings.crt_3 == 9)
	view.show_storage(_storage_snapshot(8))
	await process_frame
	await _click("warehouse_weapons")
	_check("source weapon category requests page2 without resetting progress",_last("storage_page",2) and view.state.profile.progress.gold == 1234)
	await _click("warehouse_close")
	_check("storage close only emits dedicated return intention",_last("storage_close") and view.visible)

func _finish() -> void:
	var failures := checks.filter(func(row:Dictionary)->bool:return not row.passed).size()
	var output := OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if output.is_empty():output = "res://artifacts/leba_act02_20261115/menu"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var file := FileAccess.open(output.path_join("act02_menu_tests.json"),FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"suite":"act02_source_menu","checks":checks,"failures":failures,"signals":received,"scope":"Isolated actual SourceMenu/SubViewport native GUI input with original textures and hit geometry; no Main/Battle, OS input, pixel-render comparison, profile migration or gameplay integration claim."},"\t")+"\n")
		file.close()
	print("ACT02_MENU_TESTS_RESULT "+JSON.stringify({"checks":checks.size(),"failures":failures}))
	quit(0 if failures == 0 else 1)
