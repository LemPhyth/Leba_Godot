extends Node
## Non-positional music and a bounded SFX pool. Settings remain caller-owned.

signal error_reported(message: String)
signal music_changed(track_id: String)
## Emitted only after a real pool voice has accepted the production request.
signal sound_played(alias: String, stream: AudioStream, from_seconds: float, voice: AudioStreamPlayer)

const SFX_CAPACITY: int = 8

var last_error: String = ""
var _catalog: Dictionary = {"music": {}, "sfx": {}}
var _streams: Dictionary = {}
var _music: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _voice_cursor: int = 0
var _volume: float = 0.65
var _current_music: String = ""
var _loop_restarts: int = 0
var _playback_refs: Array[WeakRef] = []
var _draining: bool = false


func _ready() -> void:
	_ensure_players()


func _exit_tree() -> void:
	# Release Node-owned playback references when its scene leaves the tree.
	# AudioServer retires stopped playbacks asynchronously on its mixer thread.
	stop_all()


func configure(catalog: Dictionary) -> bool:
	var next_streams: Dictionary = {}
	for group: String in ["music", "sfx"]:
		if typeof(catalog.get(group)) != TYPE_DICTIONARY:
			return _report_error("音频目录缺少对象：" + group)
		for identifier: Variant in catalog[group]:
			var path: Variant = catalog[group][identifier]
			if typeof(identifier) != TYPE_STRING or str(identifier).is_empty() or typeof(path) != TYPE_STRING or not str(path).begins_with("res://"):
				return _report_error("音频条目必须有标识和工程内路径：%s/%s" % [group, str(identifier)])
			if not ResourceLoader.exists(path, "AudioStream"):
				return _report_error("缺少音频资源 %s/%s：%s" % [group, identifier, path])
			var stream: AudioStream = ResourceLoader.load(path, "AudioStream") as AudioStream
			if stream == null:
				return _report_error("无法加载音频资源 %s/%s：%s" % [group, identifier, path])
			# One non-looping copy per catalogue entry, not per play() request.
			# AudioStream is reusable; each player creates its own playback state.
			next_streams[group + "/" + identifier] = _without_native_loop(stream)
	stop_all()
	_catalog = catalog.duplicate(true)
	_streams = next_streams
	last_error = ""
	_ensure_players()
	return true


func set_volume(value: float) -> void:
	if not is_finite(value):
		_report_error("音量必须是有限数值。")
		return
	_volume = clampf(value, 0.0, 1.0)
	if is_instance_valid(_music):
		_music.volume_linear = _volume
	for voice: AudioStreamPlayer in _voices:
		voice.volume_linear = _volume


func play_music(track_id: String) -> bool:
	if _draining:
		return _report_error("正在等待音频停止，不能启动新音乐。")
	if not _streams.has("music/" + track_id):
		return _report_error("音乐未登记：" + track_id)
	if not is_inside_tree():
		return _report_error("AudioDirector 尚未进入场景树，不能播放音乐。")
	_ensure_players()
	if _current_music == track_id and _music.playing:
		return true
	_music.stop()
	_current_music = track_id
	_loop_restarts = 0
	_music.stream = _streams["music/" + track_id]
	_music.play()
	_remember_playback(_music)
	last_error = ""
	music_changed.emit(track_id)
	return true


func play_sfx(sound_id: String, from_seconds: float = 0.0) -> bool:
	if _draining:
		return _report_error("正在等待音频停止，不能启动新音效。")
	if not _streams.has("sfx/" + sound_id):
		return _report_error("音效未登记：" + sound_id)
	var source: AudioStream = _streams["sfx/" + sound_id]
	var duration: float = source.get_length()
	if not is_finite(from_seconds) or from_seconds < 0.0:
		return _report_error("音效播放起点必须是有限非负秒数：" + sound_id)
	if not is_finite(duration) or duration <= 0.0 or from_seconds >= duration:
		return _report_error("音效播放起点必须小于有效时长：%s，起点=%s，时长=%s" % [sound_id, str(from_seconds), str(duration)])
	if not is_inside_tree():
		return _report_error("AudioDirector 尚未进入场景树，不能播放音效。")
	_ensure_players()
	var target: AudioStreamPlayer = null
	for voice: AudioStreamPlayer in _voices:
		if not voice.playing:
			target = voice
			break
	if target == null:
		target = _voices[_voice_cursor]
		_voice_cursor = (_voice_cursor + 1) % SFX_CAPACITY
	target.stop()
	target.stream = source
	target.play(from_seconds)
	_remember_playback(target)
	sound_played.emit(sound_id,source,from_seconds,target)
	last_error = ""
	return true


func stop_all() -> void:
	_current_music = ""
	_loop_restarts = 0
	if is_instance_valid(_music):
		_music.stop()
		_music.stream = null
	for voice: AudioStreamPlayer in _voices:
		voice.stop()
		voice.stream = null

func play_stream(stream: AudioStream, from_seconds := 0.0, source_alias := "") -> bool:
	if stream == null or not is_finite(from_seconds) or from_seconds < 0.0 or from_seconds >= stream.get_length():
		return _report_error("作者动作音效或播放起点无效。")
	if not is_inside_tree():return _report_error("音频尚未进入场景树。")
	_ensure_players()
	var target: AudioStreamPlayer = _voices[_voice_cursor]
	_voice_cursor = (_voice_cursor+1)%SFX_CAPACITY
	for voice: AudioStreamPlayer in _voices:
		if not voice.playing:target = voice;break
	target.stop()
	target.stream = stream
	target.play(from_seconds)
	_remember_playback(target)
	sound_played.emit(source_alias,stream,from_seconds,target)
	return true


func stop_and_drain(timeout_seconds: float = 1.0) -> bool:
	# stop() only queues native playback retirement. Await the actual WeakRef
	# release before process shutdown, instead of assuming a fixed sleep is enough.
	if not is_finite(timeout_seconds) or timeout_seconds < 0.0:
		return _report_error("音频停止等待时间必须是有限非负秒数。")
	if _draining:
		return _report_error("音频停止等待已在进行。")
	_draining = true
	stop_all()
	var deadline: int = Time.get_ticks_msec() + int(ceil(timeout_seconds * 1000.0))
	while _pending_playback_count() > 0:
		if not is_inside_tree() or Time.get_ticks_msec() >= deadline:
			_draining = false
			return _report_error("音频服务器未在等待时间内释放 %d 个播放对象。" % _pending_playback_count())
		await get_tree().process_frame
	_draining = false
	_playback_refs.clear()
	return true


func snapshot() -> Dictionary:
	var active: int = 0
	for voice: AudioStreamPlayer in _voices:
		if voice.playing:
			active += 1
	return {
		"music_id": _current_music,
		"music_path": _catalog["music"].get(_current_music, ""),
		"music_playing": is_instance_valid(_music) and _music.playing,
		"music_position": _music.get_playback_position() if is_instance_valid(_music) else 0.0,
		"loop_restarts": _loop_restarts,
		"volume": _volume,
		"sfx_active": active,
		"sfx_capacity": SFX_CAPACITY,
		"pending_playbacks": _pending_playback_count(),
		"draining": _draining,
		"last_error": last_error,
	}


func _ensure_players() -> void:
	if is_instance_valid(_music):
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.volume_linear = _volume
	_music.finished.connect(_on_music_finished)
	add_child(_music)
	for index: int in SFX_CAPACITY:
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.name = "Sfx%d" % index
		voice.volume_linear = _volume
		add_child(voice)
		_voices.append(voice)


func _on_music_finished() -> void:
	if not _current_music.is_empty() and is_instance_valid(_music) and is_inside_tree():
		_loop_restarts += 1
		_music.play()
		_remember_playback(_music)


func _remember_playback(player: AudioStreamPlayer) -> void:
	_playback_refs = _playback_refs.filter(func(item: WeakRef) -> bool: return item.get_ref() != null)
	if player.has_stream_playback():
		_playback_refs.append(weakref(player.get_stream_playback()))


func _pending_playback_count() -> int:
	var count: int = 0
	for reference: WeakRef in _playback_refs:
		if reference.get_ref() != null:
			count += 1
	return count


func _without_native_loop(source: AudioStream) -> AudioStream:
	# Avoid mutating shared imported resources or allowing an SFX to loop.
	var stream: AudioStream = source.duplicate() as AudioStream
	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = false
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return stream


func _report_error(message: String) -> bool:
	last_error = message
	error_reported.emit(message)
	push_warning(message)
	return false
