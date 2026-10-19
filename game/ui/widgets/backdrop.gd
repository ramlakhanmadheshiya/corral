class_name Backdrop
extends Control
## The soft sky behind every screen: a vertical gradient that eases between
## chapter colours, with a few pastel blocks and rings drifting slowly upward.

const SHAPE_COUNT: int = 14

var top: Color = Style.DEFAULT_SKY_TOP
var bottom: Color = Style.DEFAULT_SKY_BOTTOM
var _shapes: Array[Dictionary] = []
var _t: float = 0.0
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Offsets too: anchors alone keep the empty rect it was added with.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in SHAPE_COUNT:
		_shapes.append({
			"x": rng.randf(), "y": rng.randf(), "speed": rng.randf_range(0.004, 0.012),
			"size": rng.randf_range(16.0, 38.0), "phase": rng.randf() * TAU, "kind": rng.randi_range(0, 2),
			"color": rng.randi_range(0, 5), "spin": rng.randf_range(-0.3, 0.3),
		})


## Eases the sky to new colours.
func set_sky(new_top: Color, new_bottom: Color, seconds: float = 0.8) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_property(self, "top", new_top, seconds)
	_tween.tween_property(self, "bottom", new_bottom, seconds)


func _process(delta: float) -> void:
	_t += delta
	for l: Dictionary in _shapes:
		l["y"] = float(l["y"]) - float(l["speed"]) * delta
		if float(l["y"]) < -0.08:
			l["y"] = 1.08
	queue_redraw()


func _draw() -> void:
	var s: Vector2 = size
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([top, top, bottom, bottom]))
	var a: float = 0.16 if Style.DARK else 0.32
	for l: Dictionary in _shapes:
		var p: Vector2 = Vector2((float(l["x"]) + 0.02 * sin(_t * 0.5 + float(l["phase"]))) * s.x, float(l["y"]) * s.y)
		var r: float = l["size"]
		var c: Color = Color(Look.pen(int(l["color"]), "classic"), a)
		draw_set_transform(p, float(l["phase"]) + _t * float(l["spin"]))
		match int(l["kind"]):
			0:
				draw_style_box(UIKit.box(c, int(r * 0.3)), Rect2(-r / 2.0, -r / 2.0, r, r))
			1:
				draw_arc(Vector2.ZERO, r * 0.5, 0.0, TAU, 24, c, r * 0.16, true)
			_:
				draw_style_box(UIKit.box(c, int(r * 0.2)), Rect2(-r * 0.7, -r * 0.2, r * 1.4, r * 0.4))
	draw_set_transform(Vector2.ZERO)
