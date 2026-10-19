class_name TrayView
extends Control
## The three pieces under the board. Press one and drag it up onto the board: it
## grows to board size and floats above your finger so you can see where it
## lands. Let go on a good spot to place it; anywhere else and it slides home.
## Pieces that fit nowhere on the board are shown faded.

signal drag_started(slot: int)
signal drag_moved(slot: int, corner: Vector2)
signal drag_released(slot: int, corner: Vector2)

## How far above the finger the dragged piece floats, in board cells.
const LIFT_CELLS: float = 1.6

var state: RunState
var board: BoardView
var enabled: bool = true
## The slot a hint points at (outlined in gold until it is used).
var hint_slot: int = -1

var _drag_slot: int = -1
## True for drags started from code (tests, demos): real pointer moves are ignored.
var _code_drag: bool = false
var _finger: Vector2 = Vector2.ZERO
var _returning: Dictionary = {}  # slot -> {corner, start}
var _deal: Dictionary = {}       # slot -> start time
var _t: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, 176)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func setup(s: RunState, b: BoardView) -> void:
	state = s
	board = b
	_drag_slot = -1
	deal()


## Pops the current pieces in, one after another.
func deal() -> void:
	for k: int in RunState.SLOTS:
		_deal[k] = _t + 0.08 * k
	queue_redraw()


func dragging() -> int:
	return _drag_slot


func slot_rect(k: int) -> Rect2:
	var w: float = size.x / float(RunState.SLOTS)
	return Rect2(Vector2(w * k, 0), Vector2(w, size.y))


func mini_cell() -> float:
	return minf(size.x / float(RunState.SLOTS) / 4.6, size.y / 4.4)


## Where slot k's piece sits at tray size (local top-left corner).
func rest_corner(k: int) -> Vector2:
	var p: String = state.tray[k] if state != null else ""
	var ms: float = mini_cell()
	var sz: Vector2 = Vector2(Pieces.size_of(p)) * ms
	return slot_rect(k).get_center() - sz / 2.0


## The dragged piece's top-left corner in global coordinates.
func drag_corner() -> Vector2:
	var cs: float = board.cell_size() if board != null else mini_cell()
	var sz: Vector2 = Vector2(Pieces.size_of(state.tray[_drag_slot])) * cs
	return _finger - Vector2(sz.x / 2.0, sz.y + LIFT_CELLS * cs)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = e
		if mb.pressed:
			_press(mb.position)
		elif _drag_slot >= 0 and not _code_drag:
			_release()
		accept_event()
	elif e is InputEventMouseMotion and _drag_slot >= 0 and not _code_drag:
		_finger = get_global_transform() * (e as InputEventMouseMotion).position
		drag_moved.emit(_drag_slot, drag_corner())
		queue_redraw()
		accept_event()


func _press(local: Vector2) -> void:
	if not enabled or state == null or state.is_over():
		return
	for k: int in RunState.SLOTS:
		if slot_rect(k).has_point(local) and not state.tray[k].is_empty():
			_drag_slot = k
			_code_drag = false
			_returning.erase(k)
			if k == hint_slot:
				hint_slot = -1
			_finger = get_global_transform() * local
			Audio.play("pick", randf_range(0.95, 1.1), -6.0)
			Haptics.tick()
			drag_started.emit(k)
			drag_moved.emit(k, drag_corner())
			queue_redraw()
			return


func _release() -> void:
	var k: int = _drag_slot
	var corner: Vector2 = drag_corner()
	_drag_slot = -1
	drag_released.emit(k, corner)
	queue_redraw()


## Starts a drag from code (tests and the tutorial demo use this).
func begin_drag(k: int, finger_global: Vector2) -> void:
	_drag_slot = k
	_code_drag = true
	_finger = finger_global
	drag_started.emit(k)
	drag_moved.emit(k, drag_corner())


func move_drag(finger_global: Vector2) -> void:
	if _drag_slot >= 0:
		_finger = finger_global
		drag_moved.emit(_drag_slot, drag_corner())
		queue_redraw()


func end_drag() -> void:
	if _drag_slot >= 0:
		_release()


## A finger position that would drop slot k's piece with its top-left on board cell `origin`.
func finger_for(k: int, origin: Vector2i) -> Vector2:
	var cs: float = board.cell_size()
	var sz: Vector2 = Vector2(Pieces.size_of(state.tray[k])) * cs
	var corner: Vector2 = board.grid_global() + Vector2(origin) * cs
	return corner + Vector2(sz.x / 2.0, sz.y + LIFT_CELLS * cs)


## The piece didn't land: slide it back from where it was let go.
func return_piece(k: int, corner_global: Vector2) -> void:
	_returning[k] = {"corner": corner_global - global_position, "start": _t}
	Audio.play("invalid", 1.0, -8.0)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _drag_slot >= 0 or not _returning.is_empty() or not _deal.is_empty() or hint_slot >= 0:
		queue_redraw()
	for k: Variant in _deal.keys():
		if _t > float(_deal[k]) + 0.4:
			_deal.erase(k)
	for k: Variant in _returning.keys():
		if _t > float(_returning[k]["start"]) + 0.25:
			_returning.erase(k)


func _draw() -> void:
	if state == null:
		return
	var ms: float = mini_cell()
	for k: int in RunState.SLOTS:
		var r: Rect2 = slot_rect(k).grow(-8)
		draw_style_box(UIKit.box(Color(Style.INK, 0.035), 30), r)
		if k == hint_slot and not state.tray[k].is_empty():
			var pulse: float = 0.5 + 0.5 * sin(_t * 6.0)
			draw_style_box(UIKit.box(Color(Style.GOLD, 0.12 + 0.12 * pulse), 30, Style.GOLD, 4), r)
		var p: String = state.tray[k]
		if p.is_empty() or k == _drag_slot:
			continue
		var fits: bool = state.field.fits_anywhere(p)
		var corner: Vector2 = rest_corner(k)
		var cs: float = ms
		if _returning.has(k):
			var q: float = clampf((_t - float(_returning[k]["start"])) / 0.22, 0.0, 1.0)
			q = 1.0 - pow(1.0 - q, 3)
			var bcs: float = board.cell_size() if board != null else ms
			corner = (_returning[k]["corner"] as Vector2).lerp(corner, q)
			cs = lerpf(bcs, ms, q)
		var s: float = 1.0
		if _deal.has(k):
			s = BoardView._ease_back(clampf((_t - float(_deal[k])) / 0.3, 0.0, 1.0))
		if s <= 0.01:
			continue
		var sz: Vector2 = Vector2(Pieces.size_of(p)) * cs
		var centre: Vector2 = corner + sz / 2.0
		draw_piece(self, p, centre - sz * s / 2.0, cs * s, Style.WALL, 1.0 if fits else 0.32)
	if _drag_slot >= 0:
		var cs2: float = board.cell_size() if board != null else ms
		var c2: Vector2 = drag_corner() - global_position
		var sz2: Vector2 = Vector2(Pieces.size_of(state.tray[_drag_slot])) * cs2
		draw_texture_rect(Style.glow_texture(), Rect2(c2 - sz2 * 0.25 + Vector2(0, cs2 * 0.5), sz2 * 1.5), false, Color(0, 0, 0, 0.18))
		draw_piece(self, state.tray[_drag_slot], c2, cs2, Style.WALL, 0.95)


## Draws a piece as joined chunky blocks with its top-left corner at `corner`.
static func draw_piece(ci: CanvasItem, piece: String, corner: Vector2, cs: float, col: Color, alpha: float = 1.0, style: String = "") -> void:
	var gap: float = maxf(1.0, cs * 0.06)
	var rad: int = int(cs * Look.wall_radius(style))
	var lip_h: float = maxf(2.0, cs * Look.wall_lip(style))
	var cells: Array[Vector2i] = Pieces.cells(piece)
	var lip: Color = Color(col.darkened(0.28), alpha)
	var top: Color = Color(col, alpha)
	for pass_i: int in 2:
		var c: Color = lip if pass_i == 0 else top
		var off: Vector2 = Vector2(0, lip_h) if pass_i == 0 else Vector2.ZERO
		for v: Vector2i in cells:
			var r: Rect2 = Rect2(corner + Vector2(v) * cs, Vector2(cs, cs)).grow(-gap * 0.5)
			ci.draw_style_box(UIKit.box(c, rad), Rect2(r.position + off, r.size))
			if cells.has(v + Vector2i(1, 0)):
				ci.draw_rect(Rect2(Vector2(r.get_center().x, r.position.y) + off, Vector2(cs, r.size.y)), c)
			if cells.has(v + Vector2i(0, 1)):
				ci.draw_rect(Rect2(Vector2(r.position.x, r.get_center().y) + off, Vector2(r.size.x, cs)), c)
	for v: Vector2i in cells:
		var r2: Rect2 = Rect2(corner + Vector2(v) * cs, Vector2(cs, cs)).grow(-gap * 0.5)
		ci.draw_style_box(UIKit.box(Color(1, 1, 1, 0.22 * alpha), int(cs * 0.06)), Rect2(r2.position + r2.size * Vector2(0.16, 0.14), r2.size * Vector2(0.36, 0.13)))
