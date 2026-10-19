class_name ProductPreview
extends Control
## A small live picture of what a shop item gives: themes as swatches, pen
## styles as a little pen cycling through looks, coins as a stack, keys, the
## Supporter pen, the tip jar, and the Complete pack as a little of everything.

var product: String = ""
var _t: float = 0.0


func _init(id: String = "", px: float = 96.0) -> void:
	product = id
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var o: Vector2 = (size - Vector2(s, s)) / 2.0
	var box: Rect2 = Rect2(o, Vector2(s, s))
	draw_style_box(UIKit.box(Color(Style.INK, 0.07) if not Style.DARK else Color(0, 0, 0, 0.25), int(s * 0.26)), box)
	var c: Vector2 = box.get_center()
	if product.begins_with("coins") or product == "free_coins":
		var amount: int = int(product.trim_prefix("coins_")) if product.begins_with("coins_") else 100
		var n: int = 0 if amount <= 300 else (1 if amount <= 1000 else (2 if amount <= 2500 else 3))
		_art("coin_stack", c + Vector2(0, s * 0.02), s * (0.62 + 0.06 * n))
		if n >= 2:
			_art("coin", c + Vector2(s * 0.24, s * 0.2), s * 0.3)
		if n >= 3:
			_art("coin", c + Vector2(-s * 0.26, s * 0.22), s * 0.26)
	elif product == "coins":
		_art("coin_stack", c, s * 0.66)
	elif product == "keys":
		_art("key", c, s * 0.66)
	elif product == "tips":
		_art("heart", c, s * 0.6)
	elif product == "theme_pack":
		_art("theme", c, s * 0.7)
	elif product == "style_pack":
		var ids: Array = ["candy", "neon", "wood", "stone"]
		var id: String = ids[int(_t * 0.8) % ids.size()]
		var cell: float = s * 0.2
		var o2: Vector2 = c - Vector2(cell, cell) * 1.5
		for k: int in 9:
			var r: Rect2 = Rect2(o2 + Vector2(k % 3, k / 3) * cell, Vector2(cell, cell)).grow(-cell * 0.06)
			if k == 4:
				draw_style_box(UIKit.box(Look.pen(int(_t * 1.6), id), int(cell * 0.3)), r)
			else:
				draw_style_box(UIKit.box(Look.style_wall(id), int(cell * Look.wall_radius(id))), r)
	elif product == "supporter_pack":
		_art("corral", c + Vector2(-s * 0.06, -s * 0.04), s * 0.66)
		_art("heart", c + Vector2(s * 0.24, s * 0.24), s * 0.32)
	else:
		_art("corral", c + Vector2(-s * 0.12, -s * 0.06), s * 0.6)
		_art("coin_stack", c + Vector2(s * 0.2, s * 0.2), s * 0.4)
		_art("star", c + Vector2(s * 0.24, -s * 0.24), s * 0.3)


func _art(name: String, c: Vector2, px: float) -> void:
	draw_texture_rect(UIKit.art(name), Rect2(c - Vector2(px, px) / 2.0, Vector2(px, px)), false)
