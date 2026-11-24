extends Node

const SFX_POOL_SIZE: int = 16
const CALM_TRACKS: Array[String] = ["wagon_1", "wagon_2", "wagon_3", "wagon_4"]
const CALM_CUTOFF_HZ: float = 1400.0
const OPEN_CUTOFF_HZ: float = 20500.0
const CALM_VOLUME: float = 0.6

var _sfx_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _music_calm: bool = false
var _music_filter: AudioEffectLowPassFilter
var _music_fade: Tween
var _train_ambience_player: AudioStreamPlayer
var _current_music_name: String = ""
var _ambience_enabled: bool = false
var _sfx_cache: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
	Settings.apply_audio()

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	_music_player.finished.connect(func() -> void:
		if _current_music_name != "":
			_music_player.play()
	)
	add_child(_music_player)

	_music_filter = AudioEffectLowPassFilter.new()
	_music_filter.cutoff_hz = OPEN_CUTOFF_HZ
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Music"), _music_filter)

	_train_ambience_player = AudioStreamPlayer.new()
	_train_ambience_player.bus = "SFX"
	_train_ambience_player.volume_db = -9.0
	_train_ambience_player.finished.connect(func() -> void:
		if _ambience_enabled:
			_train_ambience_player.play()
	)
	add_child(_train_ambience_player)

	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)

	# Carrega o recurso Texture2D normalmente (compatível com exportação e sem avisos)
	var icon_res_path: String = "res://assets/sprites/ui/icon.png"
	if ResourceLoader.exists(icon_res_path):
		var tex: Texture2D = load(icon_res_path) as Texture2D
		if tex != null:
			var img: Image = tex.get_image()
			if img != null and not img.is_empty():
				DisplayServer.set_icon(img)


func set_train_ambience(active: bool, pitch: float = 1.0) -> void:
	_ambience_enabled = active
	if not active:
		_train_ambience_player.stop()
		return
	var path: String = "res://assets/audio/sfx/train_ambience.wav"
	if not ResourceLoader.exists(path):
		return
	if _train_ambience_player.stream == null:
		_train_ambience_player.stream = load(path)
	_train_ambience_player.pitch_scale = pitch
	if not _train_ambience_player.playing:
		_train_ambience_player.play()


func play_sfx(sfx_name: String, pitch_variance: float = 0.05) -> void:
	var stream: AudioStream = _get_sfx_stream(sfx_name)
	if stream == null:
		return
	for p in _sfx_players:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
			p.play()
			return


func _get_sfx_stream(sfx_name: String) -> AudioStream:
	if not _sfx_cache.has(sfx_name):
		var takes: Array[AudioStream] = []
		var path: String = "res://assets/audio/sfx/%s.wav" % sfx_name
		if ResourceLoader.exists(path):
			takes.append(load(path))
			var i: int = 2
			while ResourceLoader.exists("res://assets/audio/sfx/%s_%d.wav" % [sfx_name, i]):
				takes.append(load("res://assets/audio/sfx/%s_%d.wav" % [sfx_name, i]))
				i += 1
		else:
			push_warning("AudioManager: SFX ausente: %s" % path)
		_sfx_cache[sfx_name] = takes
	var cached: Array = _sfx_cache[sfx_name]
	if cached.is_empty():
		return null
	return cached[randi() % cached.size()]


func play_music(track_name: String, pitch: float = 1.0) -> void:
	if _current_music_name == track_name and _music_player.playing:
		_music_player.pitch_scale = pitch
		return
	var path: String = music_path(track_name)
	if path == "":
		return
	_current_music_name = track_name
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_music_player.stream = stream
	_music_player.pitch_scale = pitch
	_apply_music_layers(0.0)
	_music_player.play()


func music_path(track_name: String) -> String:
	for ext in ["ogg", "wav"]:
		var path: String = "res://assets/audio/music/%s.%s" % [track_name, ext]
		if ResourceLoader.exists(path):
			return path
	return ""


func stop_music() -> void:
	_current_music_name = ""
	_music_player.stop()


func set_music_calm(calm: bool) -> void:
	if calm == _music_calm:
		return
	_music_calm = calm
	_apply_music_layers(1.5)


func _apply_music_layers(fade_time: float) -> void:
	var calm_on: bool = _music_calm and CALM_TRACKS.has(_current_music_name)
	var vol: float = CALM_VOLUME if calm_on else 1.0
	var cutoff: float = CALM_CUTOFF_HZ if calm_on else OPEN_CUTOFF_HZ
	if _music_fade != null:
		_music_fade.kill()
	if fade_time <= 0.0:
		_music_player.volume_linear = vol
		_music_filter.cutoff_hz = cutoff
		return
	_music_fade = create_tween().set_parallel()
	_music_fade.tween_property(_music_player, "volume_linear", vol, fade_time)
	_music_fade.tween_property(_music_filter, "cutoff_hz", cutoff, fade_time).set_trans(Tween.TRANS_EXPO)


func set_dialogue_ducking(active: bool) -> void:
	var idx: int = AudioServer.get_bus_index("Music")
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, Settings.music_bus_db(-4.0 if active else 0.0))
