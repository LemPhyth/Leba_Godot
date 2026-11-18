extends SceneTree
## Explicit additive registration. Existing author values/layouts are kept.
const Convert = preload("res://tools/content_conversion.gd")
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	if "--register-act03" not in OS.get_cmdline_user_args():quit(1);return
	var index: Resource = load("res://content/index.tres")
	for path: String in ["res://content/characters/crt_1.tres"]:
		var value: Resource = load(path)
		if not index.characters.any(func(item: Resource)->bool:return item.identifier == value.identifier):index.characters.append(value)
	var enemy: Resource = load("res://content/enemies/goblin_7437.tres")
	if not index.enemy_definitions.any(func(item: Resource)->bool:return item.identifier == enemy.identifier):index.enemy_definitions.append(enemy)
	var stage: PackedScene = load("res://scenes/stages/root_9.tscn")
	if not index.stage_scenes.any(func(item: PackedScene)->bool:return item.resource_path == stage.resource_path):index.stage_scenes.append(stage)
	if index.flow == null:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/act03_flow.json"))
		var flow: Resource = load("res://scripts/content/flow_definition.gd").new()
		flow.dialogues = data.dialogues
		flow.intermissions = data.intermissions
		flow.routes = data.routes
		flow.source = "首次转换自data/act03_flow.json；此后编辑本Resource，普通导入不覆盖。"
		index.flow = Convert.new().save_new(flow,"res://content/flow.tres")
	var crt0: Resource = load("res://content/characters/crt_0.tres")
	if ResourceLoader.exists("res://content/actions/crt0/knockdown.tres") and not crt0.actions.any(func(action: Resource)->bool:return action.identifier == "knockdown"):
		crt0.actions.append(load("res://content/actions/crt0/knockdown.tres"))
		assert(ResourceSaver.save(crt0,crt0.resource_path) == OK)
	if "--migrate-act03-layouts" in OS.get_cmdline_user_args():_migrate_layouts()
	assert(ResourceSaver.save(index,"res://content/index.tres") == OK)
	print("ACT03_REGISTER added crt1/root9/7437/author flow; existing values kept")
	quit()

func _migrate_layouts() -> void:
	# Explicit, once-only correction of our initial conversion. Never startup/refresh.
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_catalog.json"))
	for id: int in [2,4,6,41]:
		var path := "res://scenes/stages/root_%d.tscn"%id
		var packed: PackedScene = load(path)
		var scene: Node2D = packed.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
		if scene.has_meta("act03_layout_migrated"):scene.free();continue
		var depths: Dictionary = scene.rules.extra.source_depths
		var hud: Node2D = scene.get_node("HUD")
		scene.set_editable_instance(hud,true)
		for crt: String in ["CRT0","CRT1"]:
			var page: Node = hud.get_node("Characters/"+crt)
			page.get_node("HPLayout").z_index = int(depths.hp)-hud.z_index
			page.get_node("MPLayout").z_index = int(depths.mp)-hud.z_index
		for key: String in ["GrenadeFLayout","GrenadeGLayout","GrenadeHLayout"]:hud.get_node("Characters/CRT0/"+key).z_index = int(depths.hud)
		hud.get_node("Characters/CRT1/WAmmoLayout").z_index = int(depths.hud)
		if id == 6:
			var actor: Node = scene.get_node("EnemySpawns/Enemy0/Actor")
			scene.set_editable_instance(actor,true)
			var convert := Convert.new()
			var action: Resource = convert.action("idle",{"animation":"boss7176_idle","sequence":range(1,7),"loop":true},catalog,"res://content/enemies/goblin7176_idle.tres")
			actor.get_node("AuthorOffset/Visual").source_animation = action.animation
			actor.get_node("AuthorOffset/ActionPreview").action = action
		scene.set_meta("act03_layout_migrated",true)
		var output := PackedScene.new()
		assert(output.pack(scene) == OK)
		assert(ResourceSaver.save(output,path) == OK)
		scene.free()
