class_name Splash
extends Control
## The opening moment: eight chunky walls drop in around an empty cell with
## rising notes, the pen closes and fills with colour in a burst of confetti,
## and the name appears. Matches the boot splash colour so the hand-off is
## seamless. Tap to skip.

signal finished

const LENGTH: float = 2.4
## Fixed brand colours (not the theme), matching the boot splash.
const BG_TOP: Color = Color("FFF6EC")
const BG_BOTTOM: Color = Color("F8E1D3")
const WALL: Color = Color("6C67B8")
const INK: Color = Color("3B3355")
const ACCENT: Color = Color("FF7A6B")
const ORDER: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 2), Vector2i(0, 1)]
const DROP_EVERY: float = 0.09
const CLOSE_AT: float = 0.95

var _t: float = 0.0
## Driven frame by frame (for the store renderer) instead of by the clock.
var manual: bool = false
var _done: bool = false
var _dropped: int = 0
var _closed: bool = false
var _bits: Array[Dictionary] = []


func show_at(t: float) -> void:
	_t = t
	queue_redraw()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if manual:
		set_process(false)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_finish()
	)


func _process(delta: float) -> void:
	_t += delta
	while _dropped < ORDER.size() and _t > 0.2 + _dropped * DROP_EVERY:
		Audio.pop(_dropped, -10.0)
		_dropped += 1
	if not _closed and _t > CLOSE_AT:
		_closed = true
		Audio.play("capture", 1.0, -4.0)
		Haptics.success()
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 3
		for k: int in 26:
			var a: float = rng.randf() * TAU
			_bits.append({"v": Vector2(cos(a), sin(a)) * rng.randf_range(160, 420), "c": Look.pen(k % 6, "classic"), "s": rng.randf_range(8, 16)})
	if _t >= LENGTH:
		_finish()
	queue_redraw()


func _finish() -> void:
	if _done:
		return
	_done = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		finished.emit()
		queue_free()
	)


func _draw() -> void:
	var s: Vector2 = size
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([BG_TOP, BG_TOP, BG_BOTTOM, BG_BOTTOM]))
	var cell: float = minf(s.x, s.y) * 0.17
	var centre: Vector2 = s * Vector2(0.5, 0.42)
	var origin: Vector2 = centre - Vector2(cell, cell) * 1.5
	var gap: float = cell * 0.07
	var wall: Color = WALL
	var fill_k: float = clampf((_t - CLOSE_AT) / 0.3, 0.0, 1.0)
	# The pen filling.
	if fill_k > 0.0:
		var g: float = BoardView._ease_back(fill_k)
		var r: Rect2 = Rect2(centre - Vector2(cell, cell) * 0.5 * g, Vector2(cell, cell) * g).grow(-gap)
		draw_texture_rect(Style.glow_texture(), r.grow(cell * 0.9), false, Color(Look.pen(0, "classic"), 0.5 * fill_k))
		draw_style_box(UIKit.box(Look.pen(0, "classic"), int(cell * 0.24)), r)
		var flash: float = 1.0 - clampf((_t - CLOSE_AT) / 0.2, 0.0, 1.0)
		if flash > 0.0:
			draw_style_box(UIKit.box(Color(1, 1, 1, flash), int(cell * 0.24)), r)
	else:
		draw_style_box(UIKit.box(Color(INK, 0.06), int(cell * 0.24)), Rect2(centre - Vector2(cell, cell) * 0.5, Vector2(cell, cell)).grow(-gap))
	# The walls dropping in.
	for k: int in ORDER.size():
		var start: float = 0.2 + k * DROP_EVERY
		var q: float = clampf((_t - start) / 0.22, 0.0, 1.0)
		if q <= 0.0:
			continue
		var y_off: float = -(1.0 - BoardView._ease_out(q)) * cell * 1.2
		var r2: Rect2 = Rect2(origin + Vector2(ORDER[k]) * cell + Vector2(0, y_off), Vector2(cell, cell)).grow(-gap)
		draw_style_box(UIKit.box(Color(wall.darkened(0.28), q), int(cell * 0.3)), Rect2(r2.position + Vector2(0, cell * 0.12), r2.size))
		draw_style_box(UIKit.box(Color(wall, q), int(cell * 0.3)), r2)
		draw_style_box(UIKit.box(Color(1, 1, 1, 0.25 * q), int(cell * 0.06)), Rect2(r2.position + r2.size * Vector2(0.16, 0.14), r2.size * Vector2(0.36, 0.13)))
	# Confetti.
	var age: float = _t - CLOSE_AT
	if age > 0.0:
		for b: Dictionary in _bits:
			var p: Vector2 = centre + (b["v"] as Vector2) * age + Vector2(0, 700.0 * age * age)
			var a: float = 1.0 - clampf(age / 1.0, 0.0, 1.0)
			draw_rect(Rect2(p, Vector2(float(b["s"]), float(b["s"]) * 0.6)), Color(b["c"], a))
	# The name.
	var tk: float = clampf((_t - 1.15) / 0.4, 0.0, 1.0)
	if tk > 0.0:
		var f: Font = UIKit.font(700)
		var fs: int = int(minf(s.x, s.y) * 0.13)
		var w: float = f.get_string_size("Corral", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var y: float = centre.y + cell * 2.3 + (1.0 - BoardView._ease_out(tk)) * 30.0
		draw_string(f, Vector2(s.x / 2.0 - w / 2.0, y), "Corral", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(INK, tk))
		var cap: FontVariation = (UIKit.font(600) as FontVariation).duplicate()
		cap.spacing_glyph = 4
		var fs2: int = int(fs * 0.24)
		var line: String = "FENCE IN BIG PENS"
		var w2: float = cap.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		draw_string(cap, Vector2(s.x / 2.0 - w2 / 2.0, y + fs * 0.62), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(ACCENT, tk))
