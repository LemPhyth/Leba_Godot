extends SceneTree

const SaveStore = preload("res://scripts/services/save_store.gd")
const AudioDirector = preload("res://scripts/services/audio_director.gd")

var checks: Array[Dictionary] = []
var test_root: String
var unverified: Array[String] = []


func _initialize() -> void:
	call_deferred("_probe_audio_shutdown" if OS.get_cmdline_user_args().has("--audio-shutdown-probe") else "_run")


func _probe_audio_shutdown() -> void:
	# Diagnostic mode: compare the service with a bare Godot player. WeakRef
	# observes server-held playback objects without keeping them alive itself.
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var plain: bool = args.has("--plain-player")
	var drain_seconds: float = 0.0
	for argument: String in args:
		if argument.begins_with("--drain-seconds="):
			drain_seconds = maxf(0.0, argument.trim_prefix("--drain-seconds=").to_float())
	var observed: Array[WeakRef] = []
	var host: Node
	if plain:
		var player := AudioStreamPlayer.new()
		host = player
		root.add_child(player)
		player.stream = load("res://assets/audio/4421.mp3")
		for index: int in 100:
			player.play()
			observed.append(weakref(player.get_stream_playback()))
			player.stop()
		player.stream = null
	else:
		var audio = AudioDirector.new()
		host = audio
		root.add_child(audio)
		audio.configure({"music": {"probe": "res://assets/audio/4421.mp3"}, "sfx": {}})
		for index: int in 100:
			audio.play_music("probe")
			observed.append(weakref(audio.get_node("Music").get_stream_playback()))
			audio.stop_all()
	var live_after_stop: int = observed.filter(func(item: WeakRef) -> bool: return item.get_ref() != null).size()
	var drain_ok: Variant = null
	if not plain and args.has("--observed-drain"):
		drain_ok = await host.stop_and_drain()
	host.queue_free()
	await process_frame
	if drain_seconds > 0.0:
		await create_timer(drain_seconds).timeout
	var live_before_quit: int = observed.filter(func(item: WeakRef) -> bool: return item.get_ref() != null).size()
	print("AUDIO_SHUTDOWN_PROBE " + JSON.stringify({
		"implementation": "bare_AudioStreamPlayer" if plain else "AudioDirector",
		"driver": AudioServer.get_driver_name(), "play_stop_count": observed.size(),
		"drain_seconds": drain_seconds, "live_playbacks_after_stop": live_after_stop,
		"live_playbacks_before_quit": live_before_quit, "node_freed": not is_instance_valid(host),
		"observed_drain_ok": drain_ok,
	}))
	quit()


func _check(label: String, passed: bool, detail: String = "") -> void:
	checks.append({"name": label, "passed": passed, "detail": detail})
	print(("PASS " if passed else "FAIL ") + label + (": " + detail if not detail.is_empty() else ""))


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _run() -> void:
	test_root = "user://service_tests/run_%d_%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(test_root))
	_test_save()
	await _test_audio()
	await _test_original_audio()
	var failed: int = 0
	for check: Dictionary in checks:
		if not check["passed"]:
			failed += 1
	var report: Dictionary = {
		"suite": "ticket01_services", "checks": checks, "failures": failed,
		"save_test_root": test_root, "unverified": unverified,
		"scope": "Real Godot file IO; AudioStreamPlayer loops with a synthetic short WAV; registered original MP3 playback checked through bus PCM capture. No claim of physical speaker output or full game integration.",
	}
	var report_dir := OS.get_environment("LEBA_TEST_ARTIFACT_DIR")
	if report_dir.is_empty():
		report_dir = "res://artifacts"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_dir))
	_write(report_dir.path_join("service_tests.json"), JSON.stringify(report, "\t") + "\n")
	print("SERVICE_TESTS_RESULT " + JSON.stringify({"checks": checks.size(), "failures": failed}))
	quit(0 if failed == 0 else 1)


func _test_save() -> void:
	var path: String = test_root + "/profile.json"
	var store = SaveStore.new(path)
	var first: Dictionary = store.load_profile()
	_check("missing save yields defaults without writing", first["ok"] and first["status"] == "new" and not FileAccess.file_exists(path))
	var profile: Dictionary = first["profile"]
	profile["settings"]["volume"] = 0.2
	profile["progress"]["clears"]["root_2"] = 1
	profile["progress"]["gold"] = 100
	profile["future_extension"] = {"item": [1, "keep", true]}
	_check("first valid save", store.save_profile(profile) == OK, store.last_message)
	var loaded: Dictionary = SaveStore.new(path).load_profile()
	_check("profile round trip including unknown fields", loaded["ok"] and loaded["profile"]["progress"]["gold"] == 100 and loaded["profile"]["future_extension"]["item"][1] == "keep")
	# Original3841 new-profile volume80; existing schema1 values are not snapped.
	_check("default profile is not shared and keeps original80 percent", store.default_profile()["settings"]["volume"] == 0.8 and store.default_profile()["progress"]["clears"].is_empty())
	var legacy_store = SaveStore.new(test_root + "/legacy65.json")
	var legacy: Dictionary = store.default_profile()
	legacy.settings = {"volume":0.65}
	_check("legacy schema1 volume65 survives real save and read without new-default overwrite",legacy_store.save_profile(legacy) == OK and legacy_store.load_profile().profile.settings.volume == 0.65)
	profile["progress"]["gold"] = 200
	_check("subsequent save produces backup", store.save_profile(profile) == OK and FileAccess.file_exists(path + ".bak"), store.last_message)
	var before: String = FileAccess.get_sha256(path)
	var bad: Dictionary = profile.duplicate(true)
	bad["progress"]["gold"] = -1
	_check("reject negative gold", store.save_profile(bad) == ERR_INVALID_DATA and FileAccess.get_sha256(path) == before)
	bad = profile.duplicate(true)
	bad["progress"]["clears"]["root_2"] = 0.5
	_check("reject fractional clear count", store.save_profile(bad) == ERR_INVALID_DATA and FileAccess.get_sha256(path) == before)
	bad = profile.duplicate(true)
	bad["settings"]["volume"] = true
	_check("reject boolean volume", store.save_profile(bad) == ERR_INVALID_DATA and FileAccess.get_sha256(path) == before)
	bad = profile.duplicate(true)
	bad["settings"]["volume"] = NAN
	_check("reject non-finite JSON values", store.save_profile(bad) == ERR_INVALID_DATA and FileAccess.get_sha256(path) == before)
	_write(path, "{not valid json")
	var corrupt_hash: String = FileAccess.get_sha256(path)
	loaded = store.load_profile()
	_check("invalid current recovers valid backup without overwriting", loaded["ok"] and loaded["status"] == "recovered" and loaded["profile"]["progress"]["gold"] == 100 and FileAccess.get_sha256(path) == corrupt_hash)
	_check("saving after recovery preserves invalid original", store.save_profile(loaded["profile"]) == OK and store.last_backup_path.contains(".invalid_") and FileAccess.get_sha256(store.last_backup_path) == corrupt_hash, store.last_message)
	var future: Dictionary = profile.duplicate(true)
	future["schema_version"] = 99
	_write(path, JSON.stringify(future))
	var future_hash: String = FileAccess.get_sha256(path)
	loaded = store.load_profile()
	_check("future schema does not silently fall back", not loaded["ok"] and loaded["status"] == "unsupported")
	_check("future schema is never overwritten by this build", store.save_profile(profile) == ERR_UNAVAILABLE and FileAccess.get_sha256(path) == future_hash)
	var interrupted_path: String = test_root + "/interrupted.json"
	var interrupted = SaveStore.new(interrupted_path)
	interrupted.save_profile(profile)
	DirAccess.rename_absolute(ProjectSettings.globalize_path(interrupted_path), ProjectSettings.globalize_path(interrupted_path + ".bak"))
	loaded = interrupted.load_profile()
	_check("recover interruption between renames", loaded["ok"] and loaded["status"] == "recovered" and loaded["profile"]["progress"]["gold"] == 200)
	var invalid_path: String = test_root + "/invalid.json"
	_write(invalid_path, "[]")
	loaded = SaveStore.new(invalid_path).load_profile()
	_check("invalid schema gives explicit default result", not loaded["ok"] and loaded["status"] == "invalid" and loaded["profile"]["progress"]["gold"] == 0 and FileAccess.get_file_as_string(invalid_path) == "[]")
	var unsafe = SaveStore.new("user://../../outside_profile.json")
	_check("reject traversal save path", unsafe.save_profile(profile) == ERR_INVALID_PARAMETER and not unsafe.load_profile()["ok"])
	var failure_path: String = test_root + "/blocked.json"
	var blocked = SaveStore.new(failure_path)
	blocked.save_profile(profile)
	var existing_hash: String = FileAccess.get_sha256(failure_path)
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(failure_path + ".bak"))
	_check("backup rename failure preserves current file", blocked.save_profile(profile) != OK and FileAccess.get_sha256(failure_path) == existing_hash, blocked.last_message)


func _test_audio() -> void:
	# This generated fixture tests the real completion/loop mechanism, not any
	# original game's rules. Its resource stays in ignored test output only.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.local/service_tests"))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var pcm: PackedByteArray = PackedByteArray()
	pcm.resize(2205 * 2)
	for index: int in 2205:
		pcm.encode_s16(index * 2, int(sin(float(index) * TAU * 440.0 / 22050.0) * 3000.0))
	wav.data = pcm
	var fixture: String = "res://.local/service_tests/tone.tres"
	_check("audio fixture saved", ResourceSaver.save(wav, fixture) == OK)
	var audio = AudioDirector.new()
	root.add_child(audio)
	await process_frame
	var errors: Array[String] = []
	audio.error_reported.connect(func(message: String) -> void: errors.append(message))
	var catalog: Dictionary = {"music": {"first": fixture, "second": fixture}, "sfx": {"effect": fixture}}
	_check("configure imported audio resources", audio.configure(catalog))
	audio.set_volume(0.35)
	_check("music starts through AudioStreamPlayer", audio.play_music("first") and audio.snapshot()["music_playing"] and is_equal_approx(audio.snapshot()["volume"], 0.35))
	await create_timer(0.65).timeout
	_check("music naturally completes and loops", audio.snapshot()["music_playing"] and audio.snapshot()["loop_restarts"] >= 2, str(audio.snapshot()))
	var loops: int = audio.snapshot()["loop_restarts"]
	_check("re-request same track does not restart", audio.play_music("first") and audio.snapshot()["loop_restarts"] == loops)
	_check("switch music resets track loop state", audio.play_music("second") and audio.snapshot()["music_id"] == "second" and audio.snapshot()["loop_restarts"] == 0)
	for index: int in 20:
		audio.play_sfx("effect")
	_check("sound effects use a bounded pool", audio.snapshot()["sfx_active"] == 8 and audio.get_child_count() == 9)
	var voice_resource_ids: Dictionary = {}
	for voice: Node in audio.get_children():
		if voice.name != "Music":
			voice_resource_ids[voice.stream.get_instance_id()] = true
	_check("simultaneous voices share an immutable audio stream", voice_resource_ids.size() == 1 and not voice_resource_ids.has(wav.get_instance_id()))
	_check("unknown sound is observable", not audio.play_sfx("missing") and errors.size() == 1 and audio.last_error.contains("missing"))
	_check("bad catalog is rejected without dropping active music", not audio.configure({"music": {"broken": "res://does_not_exist.wav"}, "sfx": {}}) and audio.snapshot()["music_id"] == "second" and audio.snapshot()["music_playing"])
	var active_before: int = audio.snapshot()["sfx_active"]
	_check("reject negative sound offset without stopping active voices", not audio.play_sfx("effect", -0.01) and audio.snapshot()["sfx_active"] == active_before)
	_check("reject NaN sound offset", not audio.play_sfx("effect", NAN))
	_check("reject infinite sound offset", not audio.play_sfx("effect", INF))
	_check("reject sound offset exactly at end", not audio.play_sfx("effect", wav.get_length()))
	_check("reject sound offset beyond end", not audio.play_sfx("effect", wav.get_length() + 1.0))
	_check("accept valid sound offset", audio.play_sfx("effect", 0.04))
	audio.set_volume(0.0)
	_check("mute reaches all player nodes", audio.get_children().all(func(node: Node) -> bool: return is_zero_approx(node.volume_linear)))
	audio.stop_all()
	_check("stop releases player stream references", audio.get_children().all(func(node: Node) -> bool: return node.stream == null))
	await create_timer(0.2).timeout
	_check("stop clears music and effects without delayed restart", not audio.snapshot()["music_playing"] and audio.snapshot()["sfx_active"] == 0 and audio.snapshot()["music_id"].is_empty())
	audio.queue_free()
	await process_frame


func _test_original_audio() -> void:
	if not FileAccess.file_exists("res://data/asset_catalog.json"):
		unverified.append("Original audio catalogue not available")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_catalog.json"))
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("audio"):
		_check("original catalogue contains audio mapping", false)
		return
	var audio = AudioDirector.new()
	root.add_child(audio)
	await process_frame
	var configured: bool = audio.configure(parsed["audio"])
	_check("original audio catalogue loads", configured)
	if not configured:
		audio.queue_free()
		return
	var capture: AudioEffectCapture = AudioEffectCapture.new()
	capture.buffer_length = 1.0
	var effect_index: int = AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, capture)
	audio.set_volume(0.5)
	for track: String in ["title", "battle", "training"]:
		capture.clear_buffer()
		var path: String = str(parsed["audio"]["music"].get(track, ""))
		var source_hash: String = FileAccess.get_sha256(path) if not path.is_empty() else ""
		var playing: bool = audio.play_music(track)
		if playing:
			audio.get_node("Music").seek(5.0)
		await create_timer(0.35).timeout
		var samples: PackedVector2Array = capture.get_buffer(capture.get_frames_available())
		var peak: float = _peak(samples)
		_check("original %s MP3 emits PCM" % track, playing and samples.size() > 0 and peak > 0.00001, "frames=%d peak=%f" % [samples.size(), peak])
		_check("original %s audio file unchanged" % track, not source_hash.is_empty() and FileAccess.get_sha256(path) == source_hash)
		if playing:
			var music: AudioStreamPlayer = audio.get_node("Music")
			music.seek(maxf(0.0, music.stream.get_length() - 0.05))
		await create_timer(0.4).timeout
		_check("original %s MP3 end naturally restarts" % track, playing and audio.snapshot()["loop_restarts"] >= 1 and audio.snapshot()["music_playing"], str(audio.snapshot()))
	audio.set_volume(0.0)
	await create_timer(0.15).timeout
	capture.clear_buffer()
	await create_timer(0.25).timeout
	var muted: PackedVector2Array = capture.get_buffer(capture.get_frames_available())
	_check("original music mute emits zero PCM", muted.size() > 0 and _peak(muted) < 0.000001, "frames=%d peak=%f" % [muted.size(), _peak(muted)])
	audio.stop_all()
	audio.set_volume(0.5)
	if parsed["audio"]["sfx"].is_empty():
		unverified.append("No original SFX has been registered yet")
	for sound_id: String in parsed["audio"]["sfx"]:
		audio.stop_all()
		await create_timer(0.1).timeout
		capture.clear_buffer()
		var offset: float = 3900.0 / 44100.0 if sound_id == "skill_fire" else 0.0
		var played: bool = audio.play_sfx(sound_id, offset)
		await create_timer(0.3).timeout
		var samples: PackedVector2Array = capture.get_buffer(capture.get_frames_available())
		_check("original SFX %s emits PCM" % sound_id, played and samples.size() > 0 and _peak(samples) > 0.00001, "offset=%f frames=%d peak=%f" % [offset, samples.size(), _peak(samples)])
	AudioServer.remove_bus_effect(0, effect_index)
	var drained: bool = await audio.stop_and_drain()
	_check("shutdown observes native playback release", drained and audio.snapshot()["pending_playbacks"] == 0, str(audio.snapshot()))
	audio.queue_free()
	await process_frame


func _peak(samples: PackedVector2Array) -> float:
	var peak: float = 0.0
	for sample: Vector2 in samples:
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	return peak
