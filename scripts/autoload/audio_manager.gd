extends Node

const SFX_POOL_SIZE: int = 16

var _sfx_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _music_calm_player: AudioStreamPlayer
var _music_calm: bool = false
var _music_fade: Tween
var _train_ambience_player: AudioStreamPlayer
var _current_music_name: String = ""
var _ambience_enabled: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	_music_player.finished.connect(func() -> void:
		if _current_music_name != "":
			_music_player.play()
	)
	add_child(_music_player)

	_music_calm_player = AudioStreamPlayer.new()
	_music_calm_player.bus = "Music"
	add_child(_music_calm_player)

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
	var path: String = "res://assets/audio/sfx/%s.wav" % sfx_name
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	for p in _sfx_players:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
			p.play()
			return


func play_music(track_name: String, pitch: float = 1.0) -> void:
	if _current_music_name == track_name and _music_player.playing:
		_music_player.pitch_scale = pitch
		_music_calm_player.pitch_scale = pitch
		return
	var path: String = "res://assets/audio/music/%s.wav" % track_name
	if not ResourceLoader.exists(path):
		return
	_current_music_name = track_name
	_music_player.stream = load(path)
	var calm_path: String = "res://assets/audio/music/%s_calm.wav" % track_name
	_music_calm_player.stream = load(calm_path) if ResourceLoader.exists(calm_path) else null
	_music_player.pitch_scale = pitch
	_music_calm_player.pitch_scale = pitch
	_apply_music_layers(0.0)
	_music_player.play()
	if _music_calm_player.stream != null:
		_music_calm_player.play()
	else:
		_music_calm_player.stop()


func stop_music() -> void:
	_current_music_name = ""
	_music_player.stop()
	_music_calm_player.stop()


func set_music_calm(calm: bool) -> void:
	if calm == _music_calm:
		return
	_music_calm = calm
	_apply_music_layers(1.5)


func _apply_music_layers(fade_time: float) -> void:
	var calm_on: bool = _music_calm and _music_calm_player.stream != null
	var main_vol: float = 0.0 if calm_on else 1.0
	var calm_vol: float = 1.0 if calm_on else 0.0
	if _music_fade != null:
		_music_fade.kill()
	if fade_time <= 0.0:
		_music_player.volume_linear = main_vol
		_music_calm_player.volume_linear = calm_vol
		return
	_music_fade = create_tween().set_parallel()
	_music_fade.tween_property(_music_player, "volume_linear", main_vol, fade_time)
	_music_fade.tween_property(_music_calm_player, "volume_linear", calm_vol, fade_time)


func set_dialogue_ducking(active: bool) -> void:
	var idx: int = AudioServer.get_bus_index("Music")
	if idx == -1:
		return
	var base_linear: float = float(Settings.music_volume) / 100.0
	var target_db: float = linear_to_db(maxf(0.001, base_linear)) - 6.0
	if active:
		target_db -= 4.0
	AudioServer.set_bus_volume_db(idx, target_db)
