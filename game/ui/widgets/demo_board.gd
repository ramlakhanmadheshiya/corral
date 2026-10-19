class_name DemoBoard
extends Control
## The home screen's live board: the hint bot quietly plays a Classic run, pens
## close and fill with colour, and it starts over when the board fills up.

const STEP: float = 1.15

var board: BoardView
var _state: RunState
var _clock: float = 0.6
var _seed: int = 11


func _init(px: float = 300.0) -> void:
	custom_minimum_size = Vector2(px, px)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	board = BoardView.new()
	board.quiet = true
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(board)
	_restart()


func _restart() -> void:
	_seed += 1
	_state = RunState.classic(_seed)
	# Start with a few walls down so the first pen closes quickly.
	_state.field = Field.from_ascii(START)
	board.setup(_state)


const START: String = """
.........
..##.....
.#..#....
.#.......
..##..*..
.........
....#....
.........
.........
"""


func _process(delta: float) -> void:
	_clock -= delta
	if _clock > 0.0 or board.busy():
		return
	_clock = STEP
	if _state.is_over() or _state.placed > 36:
		_restart()
		return
	var m: Array = CorralBot.best_move(_state)
	if m.is_empty():
		_restart()
		return
	var r: Dictionary = _state.place(int(m[0]), m[1])
	board.play_result(r)
