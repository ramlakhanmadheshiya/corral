class_name ShareImage
extends Control
## The picture players share after a game, like the earlier games': the board
## with every pen of the run painted in, the score, stars where they apply, and
## a QR code and link to the game. Rendered off-screen at 1080 x 1350 (4:5, the
## shape chat apps and feeds show best).

const SIZE: Vector2i = Vector2i(1080, 1350)
const SITE: String = "theramlakhan.com/corral"

var info: Dictionary = {}


## Renders the picture for `data` and calls back with an Image (null where
## nothing can be rendered, e.g. headless).
static func render(host: Node, data: Dictionary, done: Callable) -> void:
	if DisplayServer.get_name() == "headless":
		done.call(null)
		return
	var vp: SubViewport = SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	var card: ShareImage = ShareImage.new()
	card.info = data
	card.size = Vector2(SIZE)
	vp.add_child(card)
	host.add_child(vp)
	for i: int in 8:
		await RenderingServer.frame_post_draw
	if not is_instance_valid(vp):
		return
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	done.call(img)


func _ready() -> void:
	var accent: Color = info.get("accent", Style.AMBER)
	var icon: TextureRect = TextureRect.new()
	icon.texture = load("res://assets/icon.svg")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	icon.position = Vector2(72, 60)
	icon.size = Vector2(104, 104)
	add_child(icon)
	_label("Corral", 60, Style.INK, 700, Vector2(196, 72), Vector2(420, 80), HORIZONTAL_ALIGNMENT_LEFT)
	var mode: String = str(info.get("mode", "classic"))
	var right_top: String = {"classic": "Classic", "daily": "Daily Board", "challenge": "Challenge %d" % int(info.get("number", 0))}.get(mode, "")
	var right_sub: String = {"classic": "Endless run", "daily": str(info.get("date", "")), "challenge": str(info.get("chapter", ""))}.get(mode, "")
	_label(right_top, 36, accent, 800, Vector2(560, 66), Vector2(448, 50), HORIZONTAL_ALIGNMENT_RIGHT)
	_label(right_sub, 30, Style.MUTED, 600, Vector2(560, 116), Vector2(448, 44), HORIZONTAL_ALIGNMENT_RIGHT)
	# The run's painting: every pen captured, in its colour (walls left out so it shows).
	var s: RunState = info["state"]
	var board: BoardView = BoardView.new()
	board.quiet = true
	board.stain_alpha = 0.9
	board.wall_alpha = 0.0
	board.position = Vector2(180, 196)
	board.size = Vector2(720, 720)
	add_child(board)
	board.setup(s)
	board.set_process(false)
	var y: float = 930.0
	if mode != "classic":
		var stars: StarRow = StarRow.new()
		stars.position = Vector2(0, y)
		stars.size = Vector2(1080, 100)
		add_child(stars)
		stars.show_now(int(info.get("stars", 0)))
		y += 92.0
	_label(Catalog.thousands(int(info.get("score", 0))), 92 if mode == "classic" else 76, Style.INK, 800, Vector2(0, y), Vector2(1080, 110))
	var line: String = "%d pens · biggest %d cells · %d gems" % [s.captures, s.biggest, s.gems_captured]
	if mode == "challenge":
		line = "%s · in %d pieces" % [str(info.get("goal", "")), s.placed]
	_label(line, 30, Style.MUTED, 600, Vector2(0, y + (110 if mode == "classic" else 92)), Vector2(1080, 44))
	_label("Can you fence in more?" if mode != "challenge" else "Can you do it in fewer?", 34, Style.INK, 700, Vector2(72, 1240), Vector2(760, 48), HORIZONTAL_ALIGNMENT_LEFT)
	_label(SITE, 30, accent, 700, Vector2(72, 1284), Vector2(760, 44), HORIZONTAL_ALIGNMENT_LEFT)
	var qr: TextureRect = TextureRect.new()
	qr.texture = load("res://assets/share/qr.png")
	qr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	qr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	qr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	qr.position = Vector2(880, 1214)
	qr.size = Vector2(128, 128)
	add_child(qr)


func _label(text: String, fs: int, col: Color, weight: int, pos: Vector2, sz: Vector2, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var l: Label = UIKit.label(text, fs, col, weight, align)
	l.position = pos
	l.size = sz
	l.clip_text = true
	add_child(l)


func _draw() -> void:
	var sky: Array = info.get("sky", [Style.DEFAULT_SKY_TOP, Style.DEFAULT_SKY_BOTTOM])
	var top: Color = sky[0]
	var bottom: Color = sky[1]
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)]), PackedColorArray([top, top, bottom, bottom]))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	for i: int in 26:
		var p: Vector2 = Vector2(rng.randf() * size.x, rng.randf() * size.y)
		var s: float = rng.randf_range(14, 34)
		draw_style_box(UIKit.box(Color(Look.pen(i, "classic"), 0.22 if not Style.DARK else 0.12), int(s * 0.3)), Rect2(p, Vector2(s, s)))
	draw_line(Vector2(72, 1226), Vector2(840, 1226), Color(Style.INK, 0.14), 2.0, true)
