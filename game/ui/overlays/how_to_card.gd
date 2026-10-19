class_name HowToCard
extends Overlay
## How to play, a page at a time, each with a little board showing the idea.

const ALL_PAGES: Array[String] = ["walls", "pens", "bigger", "gems", "modes", "help"]

## Each page: a title, the text, and a board ("#" wall, "R" rock, "*" gem,
## digits = a pen painted in that colour).
const PAGES: Dictionary = {
	"walls": {
		"title": "Place wall pieces",
		"text": "Drag a piece from the tray under the board and drop it on empty cells. Pieces never rotate. Use all three and three more arrive. When none of your pieces fits anywhere, the run is over.",
		"board": [".........", ".##......", ".#.......", ".........", "...##....", "....#....", ".........", "......###", "........."],
	},
	"pens": {
		"title": "Close a pen",
		"text": "Wall in empty cells on all four sides and they're captured: the pen fills with colour, scores, and every wall touching it vanishes, freeing space. The board's edge is open, so it can't be one of your walls.",
		"board": [".........", "..##.....", ".#00#....", ".#00#....", "..##.....", ".........", ".....#...", "....#.#..", "........."],
	},
	"bigger": {
		"title": "Bigger is better",
		"text": "A pen scores its area × area × 10: 1 cell = 10, 4 cells = 160, 9 cells = 810, 16 cells = 2,560. Go greedy for one big pen, or play safe with small ones? Watch the preview: it shows what a pen would score before you drop the piece.",
		"board": [".........", ".###.....", "#111#....", "#111#....", "#111#....", ".###.....", ".........", "......#..", "........."],
	},
	"gems": {
		"title": "Gems, rocks and combos",
		"text": "A gem inside a pen doubles that pen (two gems: ×4). Rocks are walls that never vanish. Close two pens with one piece for a combo: ×1.5 (three pens: ×2). In longer Classic runs rocks drop in and gems start to hop.",
		"board": [".........", "..###....", ".#222#...", ".#2*2#.R.", "..###....", ".....##..", "....#33#.", ".....##..", "........."],
	},
	"modes": {
		"title": "Three ways to play",
		"text": "Classic is endless: chase your best score. The Daily Board gives everyone the same rocks, gems and 30 pieces today; score for stars and keep your streak. Challenges set a goal in a fixed set of pieces: fewer pieces used earns more stars.",
		"board": [".........", ".##.##...", "#44#55#..", ".##.##...", ".........", "...R.....", "..###....", ".#000#...", "..###...."],
	},
	"help": {
		"title": "Hints and help",
		"text": "Stuck? A hint (%d coins, your first each day is free) outlines a good spot. In Classic, a shuffle (%d coins) swaps your pieces, and once per run you can continue with a video or %d coins. Out of coins, you can watch a short video instead.",
		"board": [".........", ".........", "..#.#....", ".#...#...", ".#...#...", "..###....", ".........", ".........", "........."],
	},
}

var pages: Array = ALL_PAGES
var _index: int = 0
var _holder: VBoxContainer
var _prev: Button
var _next: Button
var _dots: HBoxContainer


func build() -> void:
	name = "HowTo"
	add_title("How to play")
	_holder = UIKit.vbox(14)
	body.add_child(_holder)
	var nav: HBoxContainer = UIKit.hbox(16)
	_prev = UIKit.icon_button("chevron-left", 80)
	_prev.name = "Prev"
	_prev.pressed.connect(func() -> void: _show(_index - 1))
	nav.add_child(_prev)
	_dots = UIKit.hbox(10)
	_dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(_dots)
	_next = UIKit.button("Next", "primary", Style.AMBER, 80, 28)
	_next.name = "Next"
	_next.custom_minimum_size.x = 200
	_next.pressed.connect(func() -> void:
		if _index >= pages.size() - 1:
			close()
		else:
			_show(_index + 1)
	)
	nav.add_child(_next)
	body.add_child(nav)
	_show(0)


func _show(i: int) -> void:
	_index = clampi(i, 0, pages.size() - 1)
	for c: Node in _holder.get_children():
		c.queue_free()
	var key: String = pages[_index]
	var page: Dictionary = PAGES[key]
	_holder.add_child(_demo(page))
	_holder.add_child(UIKit.label(page["title"], Style.SIZE_H2, Style.AMBER, 600))
	var text: String = str(page["text"])
	if key == "help":
		text = text % [Economy.HINT_COST, Economy.SHUFFLE_COST, Economy.CONTINUE_COST]
	_holder.add_child(UIKit.para(text, Style.SIZE_BODY - 3, Style.INK))
	_prev.visible = pages.size() > 1
	_prev.disabled = _index == 0
	_next.text = "Got it" if _index == pages.size() - 1 else "Next"
	for c: Node in _dots.get_children():
		c.queue_free()
	if pages.size() > 1:
		for k: int in pages.size():
			var dot: ColorRect = ColorRect.new()
			dot.custom_minimum_size = Vector2(14, 14) if k != _index else Vector2(34, 14)
			dot.color = Style.AMBER if k == _index else Color(Style.INK, 0.25)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_dots.add_child(dot)
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	refit()


## A still board showing the page's idea.
func _demo(page: Dictionary) -> BoardView:
	var rows: Array = page["board"]
	var s: RunState = RunState.new()
	s.field = Field.from_ascii("\n".join(PackedStringArray(rows)))
	var b: BoardView = BoardView.new()
	b.quiet = true
	b.custom_minimum_size = Vector2(0, 330)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for y: int in rows.size():
		var row: String = rows[y]
		for x: int in row.length():
			if row[x] >= "0" and row[x] <= "9":
				b.paint[y * Field.N + x] = Look.pen(int(row[x]))
	b.setup(s)
	return b
