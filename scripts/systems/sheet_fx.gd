extends Node2D
class_name SheetFx

var texture: Texture2D
var frame_size: Vector2 = Vector2(32.0, 32.0)
var columns: int = 1
var frames: int = 1
var fps: float = 12.0
var anchor: Vector2 = Vector2.ZERO
var loop: bool = false
var flip: bool = false
var fx_scale: float = 1.0
var tint: Color = Color.WHITE
var _t: float = 0.0


static func spawn(parent: Node, tex: Texture2D, pos: Vector2, size: Vector2, cols: int, count: int, rate: float, center: Vector2, scale_mult: float = 1.0, flipped: bool = false) -> SheetFx:
	var fx := SheetFx.new()
	fx.texture = tex
	fx.frame_size = size
	fx.columns = cols
	fx.frames = count
	fx.fps = rate
	fx.anchor = center
	fx.fx_scale = scale_mult
	fx.flip = flipped
	fx.global_position = pos
	fx.z_as_relative = false
	fx.z_index = 240
	parent.add_child(fx)
	return fx


func _process(delta: float) -> void:
	_t += delta
	if not loop and _t * fps >= float(frames):
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var f: int = int(_t * fps) % frames
	var src := Rect2(Vector2(float(f % columns), float(floori(float(f) / float(columns)))) * frame_size, frame_size)
	var size: Vector2 = frame_size * fx_scale
	var off: Vector2 = -anchor * fx_scale
	if flip:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0, 1.0))
	draw_texture_rect_region(texture, Rect2(off.round(), size), src, tint)
