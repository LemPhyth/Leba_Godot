extends SceneTree
## Explicit narrow correction of the three just-created CRT4 input bindings.
## Text substitution preserves every unrelated author byte, UID and parameter.
## Never called by import/startup. Root runs this after reviewing the report.
const CHANGES := {
	"skill_f": {"old":"skill_f", "new":"load_f", "parent":159},
	"skill_g": {"old":"skill_g", "new":"load_g", "parent":160},
	"skill_h": {"old":"skill_h", "new":"load_h", "parent":162},
}

func _initialize() -> void:call_deferred("_run")

func _run() -> void:
	if "--migrate-crt4-inputs" not in OS.get_cmdline_user_args():
		push_error("Explicit --migrate-crt4-inputs required; no author changed")
		quit(2)
		return
	var pending: Array[Dictionary] = []
	var already_correct: Array[String] = []
	for id: String in CHANGES:
		var path := "res://content/actions/crt4/"+id+".tres"
		if not FileAccess.file_exists(path):
			push_error("CRT4 migration input missing: "+path);quit(1);return
		var source := FileAccess.get_file_as_string(path)
		var old_line := "input_id = \""+str(CHANGES[id].old)+"\""
		var new_line := "input_id = \""+str(CHANGES[id].new)+"\""
		if source.count("identifier = \""+id+"\"") != 1 or source.count("source_parent = "+str(CHANGES[id].parent)+"\n") != 1:
			push_error("CRT4 migration identity/parent guard failed: "+path);quit(1);return
		if source.count(new_line)==1 and source.count(old_line)==0:
			already_correct.append(path)
			continue
		if source.count(old_line)!=1 or source.count(new_line)!=0:
			push_error("CRT4 binding has an unexpected author value; not overwritten: "+path);quit(1);return
		var output := source.replace(old_line,new_line)
		if output.replace(new_line,old_line)!=source:
			push_error("CRT4 migration non-binding byte guard failed: "+path);quit(1);return
		pending.append({"id":id,"path":path,"source":source,"output":output,"before_sha256":FileAccess.get_sha256(path),"old":CHANGES[id].old,"new":CHANGES[id].new})
	if pending.is_empty():
		print("ACT06_CRT4_INPUT_MIGRATION ",JSON.stringify({"changed":0,"already_correct":already_correct,"preserved":true}))
		quit(0)
		return
	var backup := "res://artifacts/leba_act06_20261117/migrations/crt4_inputs_%d_%d"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(backup))!=OK:
		push_error("Cannot create CRT4 migration backup; no author changed");quit(1);return
	# Back up every target before the first write.
	for row: Dictionary in pending:
		var path := backup.path_join(str(row.id)+".tres")
		if FileAccess.file_exists(path) or DirAccess.copy_absolute(ProjectSettings.globalize_path(row.path),ProjectSettings.globalize_path(path))!=OK:
			push_error("CRT4 backup failed; no author changed: "+path);quit(1);return
		if FileAccess.get_sha256(path)!=str(row.before_sha256):
			push_error("CRT4 backup verification failed; no author changed: "+path);quit(1);return
	var report: Array[Dictionary] = []
	for row: Dictionary in pending:
		if FileAccess.get_sha256(row.path)!=str(row.before_sha256):
			push_error("CRT4 author changed during migration; stop. Backups: "+backup);quit(1);return
		var file := FileAccess.open(row.path,FileAccess.WRITE)
		if file==null:
			push_error("CRT4 write failed. Backups: "+backup);quit(1);return
		file.store_string(row.output)
		file.close()
		if FileAccess.get_file_as_string(row.path)!=str(row.output):
			push_error("CRT4 output verification failed. Backups: "+backup);quit(1);return
		report.append({"path":row.path,"old":row.old,"new":row.new,"before_sha256":row.before_sha256,"after_sha256":FileAccess.get_sha256(row.path),"all_other_bytes_preserved":true})
	var payload := {"changed":report.size(),"changes":report,"already_correct":already_correct,"backup":backup,"scope":"Only input_id on three newly introduced CRT4 actions; all other bytes preserved"}
	var audit := FileAccess.open(backup.path_join("report.json"),FileAccess.WRITE)
	if audit==null:
		push_error("CRT4 migration succeeded but audit write failed: "+backup);quit(1);return
	audit.store_string(JSON.stringify(payload,"\t")+"\n")
	audit.close()
	print("ACT06_CRT4_INPUT_MIGRATION ",JSON.stringify(payload))
	quit(0)
