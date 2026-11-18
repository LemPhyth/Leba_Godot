extends SceneTree
## Add only ACT06 wave data/references. Existing action/profile/visual author values survive.
const Conversion=preload("res://tools/content_conversion.gd")
const Component=preload("res://scripts/content/component_definition.gd")
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	if "--bootstrap-act06-crt3" not in OS.get_cmdline_user_args():quit(2);return
	var helper:=Conversion.new()
	var assets:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_catalog.json"))
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/act06_crt3_waves.json"))
	var component:=Component.new();component.identifier="sword_wave";component.parameters=data
	component.source="ACT06 original1267/1311; root attach from6732 parent130/131; original sources readonly."
	for key:String in ["crt3_sword_wave_right","crt3_sword_wave_left"]:component.animations.append(helper.animation(key,assets))
	var saved:Resource=helper.save_new(component,"res://content/components/crt3/sword_wave.tres")
	var character:Resource=load("res://content/characters/crt_3.tres")
	if not character.components.any(func(c:Resource)->bool:return c.identifier=="sword_wave"):
		character.components.append(saved)
		assert(ResourceSaver.save(character,character.resource_path)==OK)
	print("ACT06 CRT3 sword-wave component added; existing author values retained")
	quit()
