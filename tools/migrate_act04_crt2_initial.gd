extends SceneTree
## Explicit ACT04 initial-conversion repair. Never invoked by normal import.
## Remove only a proven generated appearance duplicate; retain all other events
## and every non-event author property. Backups precede every affected save.
const Convert = preload("res://tools/content_conversion.gd")
const Initial = preload("res://tools/convert_act04_crt2.gd")
var report: Dictionary = {"changes":[],"component_changes":[],"preserved":[],"conflicts":[],"checks":[]}
var output := ""

func _initialize() -> void:call_deferred("_run")

func _value(value: Variant) -> Variant:
	if value is Resource:
		var fields: Dictionary = {}
		for property: Dictionary in value.get_property_list():
			var name: String=property.name
			if int(property.usage)&PROPERTY_USAGE_STORAGE == 0 or name in ["resource_path","resource_local_to_scene"]:continue
			if name=="script":fields[name]=value.get_script().resource_path if value.get_script()!=null else ""
			else:fields[name]=_value(value.get(name))
		return fields
	if value is Array:
		var rows: Array=[]
		for item: Variant in value:rows.append(_value(item))
		return rows
	if value is Dictionary:
		var row: Dictionary={}
		for key: Variant in value:row[key]=_value(value[key])
		return row
	return value

func _non_event_snapshot(action: Resource) -> Dictionary:
	var value: Dictionary=_value(action)
	value.erase("events")
	return value

func _differences(first: Variant, second: Variant, path := "") -> Array:
	var result: Array=[]
	if first==second:return result
	# TextResource Variant parsing rounds the newly authored V100/44100
	# offset by4.77e-18 seconds despite the saved17-digit text. Limit tolerance
	# to sound offsets alone; every other author field still compares exactly.
	if first is float and second is float and path.contains("/sounds/") and path.ends_with("/offset") and absf(first-second)<=maxf(absf(first),absf(second))*5e-15:return result
	if first is Dictionary and second is Dictionary:
		for key: Variant in first:
			if not second.has(key):result.append(path+"/"+str(key)+" missing")
			else:result.append_array(_differences(first[key],second[key],path+"/"+str(key)))
		for key: Variant in second:
			if not first.has(key):result.append(path+"/"+str(key)+" added")
	elif first is Array and second is Array and first.size()==second.size():
		for index: int in range(first.size()):result.append_array(_differences(first[index],second[index],path+"/"+str(index)))
	else:result.append(path+": "+str(first).left(180)+" != "+str(second).left(180))
	return result

func _duplicate_key(key: String, animation: String) -> String:
	if key==animation+"_pren":return animation
	var prefix:=animation+"_pren_sound_"
	if key.begins_with(prefix) and key.trim_prefix(prefix).is_valid_int():return animation+"_sound_"+key.trim_prefix(prefix)
	return ""

func _add_missing(target: Dictionary, source: Dictionary) -> void:
	for key: Variant in source:
		if not target.has(key):target[key]=source[key].duplicate(true) if source[key] is Dictionary or source[key] is Array else source[key]
		elif target[key] is Dictionary and source[key] is Dictionary:_add_missing(target[key],source[key])

func _same_source(first: Resource, second: Resource) -> bool:
	if first.kind!="sound" or second.kind!="sound" or first.frame!=second.frame:return false
	if first.audio_offset!=second.audio_offset or first.audio_stream!=second.audio_stream:return false
	var a: Dictionary=_value(first)
	var b: Dictionary=_value(second)
	a.erase("sound");b.erase("sound")
	return a==b

func _source_sound_contract() -> void:
	# Regression for prefix isolation without coalescing legitimate same-frame
	# StartSound records. This tests the converter, never injects gameplay audio.
	var fixture: Dictionary={"animations":{"probe":{"source_sprite_id":1}},"audio_events":{}}
	for pair: Array in [["probe",11],["probe_sound_2",12],["probe_pren",11],["probe_pren_sound_2",12],["probe_other",11]]:
		fixture.audio_events[pair[0]]={"sprite_id":1,"frame":4,"sound_id":pair[1]}
	var rows: Array=Convert.new().source_sounds("probe",fixture,[4.0])
	assert(rows.size()==2 and rows[0].sound=="probe" and rows[1].sound=="probe_sound_2","sound matching must preserve distinct same-frame sounds and reject variants")
	report.checks.append("exact alias and sound_N accepted; pren/unrelated prefix rejected; distinct same-frame sounds preserved")

func _run() -> void:
	if "--migrate-act04-initial" not in OS.get_cmdline_user_args():quit(2);return
	output="res://artifacts/leba_act04_20261117/initial_migration/run_%d_%d"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.path_join("backup")))==OK)
	_source_sound_contract()
	var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/act04_crt2_rules.json"))
	var assets: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_catalog.json"))
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--audit-backup-dir="):continue
		var backup_dir:=argument.trim_prefix("--audit-backup-dir=")
		var audit: Dictionary={"scope":"read-only interrupted audio-clock migration audit","files":[],"failure_count":0,"observed_serializer_difference":"V sounds offset100/44100 reparsed delta4.77e-18 seconds; only sound offsets permit5e-15 relative tolerance"}
		for filename: String in DirAccess.get_files_at(backup_dir):
			if not filename.ends_with(".tres"):continue
			var before: Resource=load(backup_dir.path_join(filename))
			var expected: Dictionary=_non_event_snapshot(before)
			expected.extra["nested_audio"]=_value(Initial.nested_audio_rows(str(before.identifier),rules,assets))
			var after: Resource=load("res://content/actions/crt2/"+filename)
			var differences: Array=_differences(expected,_non_event_snapshot(after))
			differences.append_array(_differences(_value(before.events),_value(after.events)))
			audit.files.append({"path":after.resource_path,"backup":backup_dir.path_join(filename),"differences":differences,"nested_clocks":expected.extra.nested_audio.size()})
			audit.failure_count+=differences.size()
		var audit_file:=FileAccess.open(backup_dir.get_base_dir().path_join("recovery_audit.json"),FileAccess.WRITE)
		audit_file.store_string(JSON.stringify(audit,"\t")+"\n");audit_file.close()
		print("ACT04_MIGRATION_RECOVERY_AUDIT ",JSON.stringify(audit))
		quit(0 if audit.failure_count==0 else 1);return
	var untouched: Dictionary={}
	for folder: String in ["res://content/characters"]:
		for file: String in DirAccess.get_files_at(folder):
			if file.ends_with(".tres"):untouched[folder.path_join(file)]=FileAccess.get_sha256(folder.path_join(file))
	var base:="res://content/actions/crt2"
	for filename: String in DirAccess.get_files_at(base):
		if not filename.ends_with(".tres"):continue
		var path:=base.path_join(filename)
		var before_hash:=FileAccess.get_sha256(path)
		var action: Resource=load(path)
		var preserved: Dictionary=_non_event_snapshot(action)
		var kept: Array[Resource]=[]
		var changes: Array=[]
		var event_snapshots: Array=[]
		for event: Resource in action.events:
			var counterpart_key:=_duplicate_key(str(event.sound),str(action.animation_key)) if event.kind=="sound" else ""
			if not counterpart_key.is_empty():
				var match_found:=false
				for candidate: Resource in action.events:
					if candidate.sound==counterpart_key and _same_source(event,candidate):match_found=true;break
				if match_found:
					changes.append({"operation":"remove_proven_appearance_duplicate","frame":event.frame,"alias":event.sound,"kept_alias":counterpart_key})
					continue
				# Customized or unmatched variant events are not ours to delete.
				report.conflicts.append({"path":path,"alias":event.sound,"reason":"no exact retained source counterpart; preserved"})
			kept.append(event)
			event_snapshots.append(_value(event))
		# Work out target additions before mutation or save, so backup is exact.
		for index: int in range(kept.size()):
			var event: Resource=kept[index]
			var is_original_slot: bool=(action.identifier=="skill_r" and event.kind=="crt2_cooldown_resume" and event.frame==138 and int(event.parameters.get("slot_id",0))==4200) or (action.identifier=="jump_z" and event.kind=="crt2_slot_play" and event.frame==67 and int(event.parameters.get("slot_id",0))==4229)
			if is_original_slot and not event.parameters.has("target_frame"):
				changes.append({"operation":"restore_target_frame","index":index,"kind":event.kind,"trigger_frame":event.frame,"target_frame":2})
		var nested: Array=action.extra.get("nested_audio",[]).duplicate(true)
		var nested_added:=false
		for clock: Dictionary in Initial.nested_audio_rows(str(action.identifier),rules,assets):
			if nested.any(func(item: Dictionary)->bool:return str(item.get("identifier",""))==str(clock.identifier)):continue
			nested.append(clock)
			nested_added=true
			changes.append({"operation":"add_missing_independent_audio_clock","identifier":clock.identifier,"from_frame":clock.from_frame,"until_frame":clock.until_frame,"loop_frames":clock.get("loop_frames",0)})
		if changes.is_empty():
			report.preserved.append({"path":path,"sha256":before_hash})
			continue
		var backup:=output.path_join("backup").path_join(filename)
		assert(DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(backup))==OK)
		assert(FileAccess.get_sha256(backup)==before_hash)
		action.events=kept
		if nested_added:
			action.extra["nested_audio"]=nested
			preserved.extra["nested_audio"]=_value(nested)
		for change: Dictionary in changes:
			if change.operation=="restore_target_frame":
				action.events[change.index].parameters["target_frame"]=2
				event_snapshots[change.index].parameters["target_frame"]=2
		assert(_non_event_snapshot(action)==preserved,"non-event author data modified: "+path)
		for index: int in range(action.events.size()):assert(_value(action.events[index])==event_snapshots[index],"retained event changed outside explicit target repair: "+path)
		assert(ResourceSaver.save(action,path)==OK)
		var reloaded: Resource=ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)
		assert(_differences(_non_event_snapshot(reloaded),preserved).is_empty(),"serialized non-event author data changed: "+path)
		for index: int in range(reloaded.events.size()):assert(_differences(_value(reloaded.events[index]),event_snapshots[index]).is_empty(),"serialized retained event changed: "+path)
		report.changes.append({"path":path,"before_sha256":before_hash,"after_sha256":FileAccess.get_sha256(path),"backup":backup,"operations":changes,"existing_author_data_preserved":true,"retained_events_preserved":true})
	# Normalize only source-audio evidence into executable authored sound rows.
	# Existing sounds keys remain authoritative; all other parameters stay exact.
	var component_directory:="res://content/components/crt2"
	assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.path_join("backup/components")))==OK)
	for filename: String in DirAccess.get_files_at(component_directory):
		if not filename.ends_with(".tres"):continue
		var path:=component_directory.path_join(filename)
		var component: Resource=load(path)
		var normalized: Dictionary=Initial.runtime_component(component.parameters,assets)
		var animations: Array[Resource]=component.animations.duplicate()
		if component.identifier=="visuals":
			_add_missing(normalized.geometry.r_air,assets.source_geometry.act04_crt2_components.r_air)
			for key: String in ["crt2_r_air_back","crt2_r_air_hit","crt2_r_air_front"]:
				if not animations.any(func(item: Resource)->bool:return item.identifier==key):animations.append(Convert.new().animation(key,assets))
		if _value(normalized)==_value(component.parameters) and animations.size()==component.animations.size():
			untouched[path]=FileAccess.get_sha256(path)
			continue
		var before_hash:=FileAccess.get_sha256(path)
		var backup:=output.path_join("backup/components").path_join(filename)
		assert(DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(backup))==OK)
		assert(FileAccess.get_sha256(backup)==before_hash)
		var expected: Dictionary=_value(component)
		expected.parameters=_value(normalized)
		expected.animations=_value(animations)
		component.parameters=normalized
		component.animations=animations
		assert(ResourceSaver.save(component,path)==OK)
		var reloaded: Resource=ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)
		assert(_differences(_value(reloaded),expected).is_empty(),"component changed beyond audio normalization: "+path)
		report.component_changes.append({"path":path,"before_sha256":before_hash,"after_sha256":FileAccess.get_sha256(path),"backup":backup,"operation":"add_missing_R_parts_and_animation_references" if component.identifier=="visuals" else "normalize_source_audio_to_sounds","other_component_fields_preserved":true})
	for path: String in untouched:assert(FileAccess.get_sha256(path)==untouched[path],"unrelated author content changed: "+path)
	report.checks.append("character resources and all untouched components byte-identical; existing clocks and sounds preserved")
	report.checks.append("only sounds/offset permits5e-15 relative decimal-parser rounding; verified V100/44100 delta4.77e-18 seconds; all other author fields exact")
	var file:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	assert(file!=null)
	file.store_string(JSON.stringify(report,"\t")+"\n");file.close()
	print("ACT04_INITIAL_MIGRATION_RESULT ",JSON.stringify({"changed_files":report.changes.size(),"changed_components":report.component_changes.size(),"unchanged_files":report.preserved.size(),"conflicts":report.conflicts.size(),"report":output.path_join("report.json")}))
	quit(0 if report.conflicts.is_empty() else 1)
