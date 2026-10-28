extends CanvasLayer
class_name BossCutscene

# Cutscenes do Boss no estilo "cartão de apresentação" (Borderlands):
# o jogo congela, faixas de cinema entram, a câmera aproxima do Maquinista e um cartaz
# com a arte dele, o nome em letras grandes e um apelido entra batendo sobre uma mancha de tinta.
# Tudo roda com a árvore pausada; ENTER / F / clique pulam.

signal finished

const ART_P1: Texture2D = preload("res://assets/sprites/cutscene/boss_splash_p1.png")
const ART_P3: Texture2D = preload("res://assets/sprites/cutscene/boss_splash_p3.png")
const SPLASH_TEX: Texture2D = preload("res://assets/sprites/cutscene/paint_splash.png")

const BAR_H: float = 30.0
const ART_X: float = 296.0
const BANNER_X: float = 10.0

var _level: Node2D
var _root: Control
var _bar_top: ColorRect
var _bar_bot: ColorRect
var _art: TextureRect
var _banner: TextureRect
var _tag: Label
var _name: Label
var _sub: Label
var _skip_hint: Label
var _skip: bool = false
var _running: bool = false
var _shake_t: float = 0.0
var _tweens: Array[Tween] = []


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("boss_cutscene")

	_root = Control.new()
	_root.size = Vector2(480.0, 270.0)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)

	_banner = TextureRect.new()
	_banner.texture = SPLASH_TEX
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_banner)

	_art = TextureRect.new()
	_art.texture = ART_P1
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_art)

	# faixas por cima da arte: escondem o corte reto da base do cartaz
	_bar_top = _make_bar()
	_bar_bot = _make_bar()

	_tag = _make_label(10, Color("#fff1c9"), 3)
	_name = _make_label(40, Color("#fff1c9"), 6)
	_sub = _make_label(10, Color("#fff1c9"), 3)
	if Settings.title_font != null:
		_name.add_theme_font_override("font", Settings.title_font)

	_skip_hint = _make_label(10, Color("#8fb8c4"), 0)
	Settings.bind_prompt_text(_skip_hint, "{confirm} PULAR")
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_hint.position = Vector2(300.0, 270.0 - BAR_H + 8.0)
	_skip_hint.size = Vector2(172.0, 14.0)


func _make_bar() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color("#0d0b12")
	r.size = Vector2(480.0, BAR_H)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(r)
	return r


func _make_label(font_size: int, col: Color, outline: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color("#0d0b12"))
		l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	return l


func _process(delta: float) -> void:
	if not _running:
		return
	if Input.is_action_just_pressed("confirm") or Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("skip_dialogue") or TouchControls.consume_tap():
		_skip = true
	# tremida própria (o tremor do nível não roda com a árvore pausada)
	if _shake_t > 0.0:
		_shake_t -= delta
		_root.position = Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)).round()
	else:
		_root.position = Vector2.ZERO


# ------------------------------------------------------------------------------
# Sequências públicas
# ------------------------------------------------------------------------------
func play_intro(level: Node2D, boss: Node2D) -> void:
	await _play(level, boss, {
		"tag": "CHEFE · LOCOMOTIVA",
		"name": "O MAQUINISTA",
		"sub": "Pontual até o fim do mundo.",
		"art": ART_P1,
		"zoom": 2.0,
		"approach": 1.1,
		"hold": 2.6,
		"sfx_in": "whistle",
	})


func play_phase(level: Node2D, boss: Node2D, phase: int) -> void:
	var cfg: Dictionary
	if phase == 2:
		cfg = {
			"tag": "FASE 2",
			"name": "PRESSÃO MÁXIMA",
			"sub": "«%s»" % String(GameState.dialogue_db.get("boss_float_p2", "")),
			"art": ART_P1,
		}
	else:
		cfg = {
			"tag": "FASE 3",
			"name": "CALDEIRA EM CHAMAS",
			"sub": "«%s»" % String(GameState.dialogue_db.get("boss_float_p3", "")),
			"art": ART_P3,
			"banner_tint": Color("#ff6b3d"),
		}
	cfg["zoom"] = 1.6
	cfg["approach"] = 0.5
	cfg["hold"] = 1.8
	await _play(level, boss, cfg)


func play_defeat(level: Node2D, boss: Node2D) -> void:
	await _play(level, boss, {
		"tag": "CHEFE DERROTADO",
		"name": "FIM DA LINHA",
		"sub": "...mas a bomba continua contando.",
		"art": ART_P3,
		"art_tint": Color(0.5, 0.46, 0.56),
		"zoom": 1.8,
		"approach": 0.7,
		"hold": 2.0,
	})


# ------------------------------------------------------------------------------
# Motor da cutscene
# ------------------------------------------------------------------------------
func _play(level: Node2D, boss: Node2D, cfg: Dictionary) -> void:
	_level = level
	_skip = false
	_running = true
	var was_paused: bool = get_tree().paused
	get_tree().paused = true
	var hud: CanvasLayer = level.get("hud")
	if hud != null:
		hud.visible = false

	# estado inicial: faixas fora da tela, cartaz escondido
	_root.visible = true
	_bar_top.position = Vector2(0.0, -BAR_H)
	_bar_bot.position = Vector2(0.0, 270.0)
	_art.texture = cfg.get("art", ART_P1)
	_art.size = _art.texture.get_size()
	_art.position = Vector2(480.0, 270.0 - BAR_H - _art.size.y + 14.0)
	_art.modulate = cfg.get("art_tint", Color.WHITE)
	_banner.size = SPLASH_TEX.get_size()
	_banner.position = Vector2(-_banner.size.x, 104.0)
	_banner.modulate = cfg.get("banner_tint", Color.WHITE)
	_tag.text = String(cfg["tag"])
	_name.text = String(cfg["name"])
	_sub.text = String(cfg["sub"])
	# nomes longos descem de 40 para 30 px para caber à esquerda da arte
	_name.add_theme_font_size_override("font_size", 40 if _name.text.length() <= 13 else 30)
	for l in [_tag, _name, _sub]:
		(l as Label).modulate.a = 0.0
	_tag.position = Vector2(BANNER_X + 14.0, 108.0)
	_name.position = Vector2(BANNER_X + 12.0, 116.0)
	_sub.position = Vector2(BANNER_X + 14.0, 160.0)
	_skip_hint.modulate.a = 0.0

	# 1) faixas de cinema + aproximação da câmera no boss
	var zoom: float = float(cfg.get("zoom", 1.8))
	var target_pos: Vector2 = Vector2(240.0, 135.0) - boss.global_position * zoom
	var t1 := _tween()
	t1.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t1.tween_property(_bar_top, "position:y", 0.0, 0.35)
	t1.tween_property(_bar_bot, "position:y", 270.0 - BAR_H, 0.35)
	t1.tween_property(_skip_hint, "modulate:a", 1.0, 0.35)
	t1.tween_property(level, "scale", Vector2(zoom, zoom), float(cfg.get("approach", 1.0)))
	t1.tween_property(level, "position", target_pos, float(cfg.get("approach", 1.0)))
	if cfg.has("sfx_in"):
		AudioManager.play_sfx(String(cfg["sfx_in"]), 0.0)
	await _wait(float(cfg.get("approach", 1.0)) + 0.1)

	# 2) congela: mundo escurece, cartaz entra batendo
	if not _skip:
		AudioManager.play_sfx("clang", 0.0)
		_shake_t = 0.25
		var t2 := _tween()
		t2.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t2.tween_property(level, "modulate", Color(0.42, 0.38, 0.5), 0.15)
		t2.tween_property(_banner, "position:x", BANNER_X, 0.22)
		t2.tween_property(_art, "position:x", ART_X, 0.28)
		t2.tween_property(_tag, "modulate:a", 1.0, 0.2)
		# o nome cai de cima, grande, e "carimba" no lugar
		_name.pivot_offset = Vector2(0.0, 20.0)
		_name.scale = Vector2(2.0, 2.0)
		var t3 := _tween(false)
		t3.tween_interval(0.12)
		t3.tween_property(_name, "modulate:a", 1.0, 0.08)
		t3.parallel().tween_property(_name, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t3.tween_callback(func() -> void:
			_shake_t = 0.2
			AudioManager.play_sfx("boss_phase", 0.0))
		t3.tween_interval(0.25)
		t3.tween_property(_sub, "modulate:a", 1.0, 0.25)
		await _wait(float(cfg.get("hold", 2.0)) + 0.6)

	# 3) saída: cartaz sai, mundo volta, câmera solta, faixas recolhem
	_kill_tweens()
	var t4 := _tween()
	t4.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t4.tween_property(_art, "position:x", 480.0, 0.22)
	t4.tween_property(_banner, "position:x", -_banner.size.x, 0.22)
	for l in [_tag, _name, _sub, _skip_hint]:
		t4.tween_property(l, "modulate:a", 0.0, 0.15)
	t4.tween_property(level, "modulate", Color.WHITE, 0.25)
	t4.tween_property(level, "scale", Vector2.ONE, 0.35)
	t4.tween_property(level, "position", Vector2.ZERO, 0.35)
	t4.tween_property(_bar_top, "position:y", -BAR_H, 0.35)
	t4.tween_property(_bar_bot, "position:y", 270.0, 0.35)
	await t4.finished

	level.scale = Vector2.ONE
	level.position = Vector2.ZERO
	level.modulate = Color.WHITE
	_root.visible = false
	_running = false
	_shake_t = 0.0
	if hud != null:
		hud.visible = true
	get_tree().paused = was_paused
	finished.emit()


func _tween(parallel: bool = true) -> Tween:
	var t := create_tween().set_parallel(parallel)
	_tweens.append(t)
	return t


func _kill_tweens() -> void:
	for t in _tweens:
		if t.is_valid():
			t.kill()
	_tweens.clear()


# Espera que respeita o pulo (o jogo está pausado, então conta frames de processamento)
func _wait(seconds: float) -> void:
	var elapsed: float = 0.0
	while elapsed < seconds and not _skip:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
