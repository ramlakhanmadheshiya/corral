class_name PenArt
extends Control
## A little pen: eight chunky walls around a centre that fills with colour as
## `fill` goes from 0 to 1 (chapter cards show their progress this way).

var color: Color = Color("7FDDB8")
var fill: float = 1.0
var label: String = ""
var dim: bool = false
var bob: bool = true
var _t: float = 0.0


func _init(px: float = 120.0) -> void:
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if bob:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var cell: float = s / 3.0
	var o: Vector2 = (size - Vector2(s, s)) / 2.0 + Vector2(0, sin(_t * 1.6) * s * 0.012)
	var gap: float = cell * 0.07
	var a: float = 0.45 if dim else 1.0
	var wall: Color = Style.WALL
	var centre: Rect2 = Rect2(o + Vector2(cell, cell), Vector2(cell, cell)).grow(-gap)
	draw_style_box(UIKit.box(Color(Style.INK, 0.08 * a), int(cell * 0.24)), centre)
	if fill > 0.0:
		var h: float = centre.size.y * clampf(fill, 0.0, 1.0)
		var fr: Rect2 = Rect2(Vector2(centre.position.x, centre.end.y - h), Vector2(centre.size.x, h))
		draw_texture_rect(Style.glow_texture(), centre.grow(cell * 0.5), false, Color(color, 0.35 * fill * a))
		draw_style_box(UIKit.box(Color(color, a), int(cell * 0.24)), fr)
	for k: int in 9:
		if k == 4:
			continue
		var r: Rect2 = Rect2(o + Vector2(k % 3, k / 3) * cell, Vector2(cell, cell)).grow(-gap)
		draw_style_box(UIKit.box(Color(wall.darkened(0.28), a), int(cell * 0.3)), Rect2(r.position + Vector2(0, cell * 0.1), r.size))
		draw_style_box(UIKit.box(Color(wall, a), int(cell * 0.3)), r)
		draw_style_box(UIKit.box(Color(1, 1, 1, 0.22 * a), int(cell * 0.06)), Rect2(r.position + r.size * Vector2(0.16, 0.14), r.size * Vector2(0.36, 0.13)))
	if not label.is_empty():
		var f: Font = UIKit.font(800)
		var fs: int = int(cell * 0.62)
		var w: float = f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var c: Vector2 = centre.get_center()
		draw_string(f, Vector2(c.x - w / 2.0, c.y + (f.get_ascent(fs) - f.get_descent(fs)) / 2.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Style.PAPER_INK if fill > 0.5 else Style.INK, a))
