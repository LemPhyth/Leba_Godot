extends SceneTree
## Narrow explicit first-generation correction. No gameplay or automatic import.
const TARGET := "res://content/actions/crt4/jump.tres"
const OLD := "hold_at = PackedInt32Array()"
const NEW := "hold = true\nhold_at = PackedInt32Array(30)"

func _initialize() -> void:call_deferred("_run")

func _run() -> void:
	if "--migrate-crt4-jump-hold" not in OS.get_cmdline_user_args():
		push_error("Explicit --migrate-crt4-jump-hold required; no author changed");quit(2);return
	if not FileAccess.file_exists(TARGET):
		push_error("CRT4 jump author missing; no author changed");quit(1);return
	var source:=FileAccess.get_file_as_string(TARGET)
	if source.count("identifier = \"jump\"")!=1 or source.count("source_parent = 167\n")!=1 or not source.contains("parent167/source6530"):
		push_error("CRT4 jump identity guard failed; no author changed");quit(1);return
	if source.count(NEW)==1 and source.count(OLD)==0:
		print("ACT06_CRT4_JUMP_HOLD_MIGRATION already_correct; no writes");quit(0);return
	if source.count(OLD)!=1 or source.contains("\nhold = "):
		push_error("CRT4 jump hold has an unexpected author value; not overwritten");quit(1);return
	var output:=source.replace(OLD,NEW)
	if output.replace(NEW,OLD)!=source:
		push_error("CRT4 jump non-hold byte guard failed; no author changed");quit(1);return
	var before:=FileAccess.get_sha256(TARGET)
	var folder:="res://artifacts/leba_act06_20261117/migrations/crt4_jump_hold_%d_%d"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))!=OK:
		push_error("CRT4 jump backup directory failed; no author changed");quit(1);return
	var backup:=folder.path_join("jump.tres")
	if DirAccess.copy_absolute(ProjectSettings.globalize_path(TARGET),ProjectSettings.globalize_path(backup))!=OK or FileAccess.get_sha256(backup)!=before:
		push_error("CRT4 jump backup verification failed; no author changed");quit(1);return
	if FileAccess.get_sha256(TARGET)!=before:
		push_error("CRT4 jump author changed after preflight; not overwritten");quit(1);return
	var file:=FileAccess.open(TARGET,FileAccess.WRITE)
	if file==null:
		push_error("CRT4 jump write failed; backup="+backup);quit(1);return
	file.store_string(output);file.close()
	if FileAccess.get_file_as_string(TARGET)!=output:
		push_error("CRT4 jump output mismatch; backup="+backup);quit(1);return
	var report:={"path":TARGET,"before_sha256":before,"after_sha256":FileAccess.get_sha256(TARGET),"backup":backup,"changed":["hold=true","hold_at=[30]"],"all_other_bytes_preserved":true,"source":"res/scripts/DefineSprite_6530/frame_30/DoAction.as: stop(); only child<13 returns146; Kalla13..21 remains independent"}
	var audit:=FileAccess.open(folder.path_join("report.json"),FileAccess.WRITE)
	if audit==null:
		push_error("CRT4 jump migrated but audit failed: "+folder);quit(1);return
	audit.store_string(JSON.stringify(report,"\t")+"\n");audit.close()
	print("ACT06_CRT4_JUMP_HOLD_MIGRATION ",JSON.stringify(report))
	quit(0)
