extends Control
## The Google Play feature graphic (1024 x 500): a corner of the board with two
## pens filling with colour, the name and a plain line about the game. Rendered
## by tools/render_store_art.tscn.

const TOP: Color = Color("FFF6EC")
const BOTTOM: Color = Color("F9DCCB")
const WALL: Color = Color("6C67B8")
const INK: Color = Color("3B3355")
const ACCENT: Color = Color("FF7A6B")

const BOARD: Array[String] = [
	"..##..#",
	".#00#.#",
	".#00#..",
	"..##.##",
	".##.#11",
	"#22#.#1",
	".##..R.",
]


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)]),
		PackedColorArray([TOP, TOP, BOTTOM, BOTTOM]))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	for i: int in 16:
		var p: Vector2 = Vector2(rng.randf() * size.x, rng.randf() * size.y)
		var s: float = rng.randf_range(12, 26)
		draw_style_box(UIKit.box(Color(Look.pen(i, "classic"), 0.3), int(s * 0.3)), Rect2(p, Vector2(s, s)))
	var cell: float = 60.0
	var o: Vector2 = Vector2(48, 38)
	draw_style_box(UIKit.lip_box(Color("F3E6DA"), 30, Color("E0CDBE"), 8, Vector2.ZERO), Rect2(o - Vector2(12, 12), Vector2(cell * 7 + 24, cell * 7 + 24)))
	var gap: float = 4.0
	for y: int in 7:
		for x: int in 7:
			var rc: Rect2 = Rect2(o + Vector2(x, y) * cell, Vector2(cell, cell)).grow(-gap)
			draw_style_box(UIKit.box(Color("FFFAF4"), 13), rc)
			var ch: String = BOARD[y][x]
			if ch >= "0" and ch <= "9":
				var col: Color = Look.pen(int(ch), "classic")
				draw_texture_rect(Style.glow_texture(), rc.grow(18), false, Color(col, 0.25))
				draw_style_box(UIKit.box(col, 13), rc)
	for y: int in 7:
		for x: int in 7:
			var ch2: String = BOARD[y][x]
			var rc2: Rect2 = Rect2(o + Vector2(x, y) * cell, Vector2(cell, cell)).grow(-gap * 0.5)
			if ch2 == "#":
				draw_style_box(UIKit.box(WALL.darkened(0.28), 18), Rect2(rc2.position + Vector2(0, 7), rc2.size))
				draw_style_box(UIKit.box(WALL, 18), rc2)
				draw_style_box(UIKit.box(Color(1, 1, 1, 0.25), 4), Rect2(rc2.position + rc2.size * Vector2(0.16, 0.14), rc2.size * Vector2(0.36, 0.13)))
			elif ch2 == "R":
				draw_style_box(UIKit.box(Color("A39BB3").darkened(0.3), 18), Rect2(rc2.position + Vector2(0, 6), rc2.size).grow(-3))
				draw_style_box(UIKit.box(Color("A39BB3"), 18), rc2.grow(-3))
	var title: Font = UIKit.font(700)
	draw_string(title, Vector2(530, 228), "Corral", HORIZONTAL_ALIGNMENT_LEFT, -1, 108, INK)
	var body: Font = UIKit.font(500)
	draw_string(body, Vector2(536, 296), "Fence in empty space.", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(INK, 0.75))
	draw_string(body, Vector2(536, 344), "Bigger pens, far bigger scores.", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, ACCENT.darkened(0.1))
	draw_string(body, Vector2(536, 410), "Classic · Daily Board · 120 Challenges", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(INK, 0.55))
