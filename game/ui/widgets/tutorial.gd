class_name Tutorial
extends Control
## Hands-on first-play tutorial (the first Classic run). It never blocks input:
## the player really drags the piece while an animated hand and short captions
## show how: drag -> drop on the gap -> the pen is captured -> bigger is better.

enum Step { SHOW, DRAGGING, CAPTURED, FREE, DONE }

var play: Node
var step: Step = Step.SHOW
var _t: float = 0.0
var _caption: Label
var _bubble: PanelContainer
var _shown_text: String = ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble = PanelContainer.new()
	_bubble.name = "TutorialBubble"
	_bubble.add_theme_stylebox_override("panel", UIKit.box(Style.INK, 30, Color.TRANSPARENT, 0, Vector2(28, 14)))
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption = UIKit.label("", 25, Style.PAPER if not Style.DARK else Style.PAPER_INK, 600)
	_caption.name = "TutorialCaption"
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.custom_minimum_size = Vector2(470, 0)
	_bubble.add_child(_caption)
	add_child(_bubble)
	play.tray.drag_started.connect(func(_k: int) -> void:
		if step == Step.SHOW:
			_go(Step.DRAGGING))
	play.tray.drag_released.connect(func(_k: int, _c: Vector2) -> void:
		if step == Step.DRAGGING:
			_go.call_deferred(Step.SHOW if play.state.tray[0] == "i2v" else Step.FREE))
	play.board.set_target(_target_cells())
	_go(Step.SHOW)


func _target_cells() -> PackedInt32Array:
	return Field.cover("i2v", RunState.TUTORIAL_TARGET)


func _go(next: Step) -> void:
	if step == Step.DONE:
		return
	step = next
	_t = 0.0
	match step:
		Step.SHOW:
			_say("Drag the wall piece into the glowing gap")
		Step.DRAGGING:
			_say("Drop it on the gap to close the pen")
		Step.CAPTURED:
			play.board.set_target(PackedInt32Array())
			_say("A pen! It scores its area × area, so bigger pens score far more")
		Step.FREE:
			play.board.set_target(PackedInt32Array())
			_say("Wall in empty cells on all four sides to capture them")
		Step.DONE:
			_say("")


## Called by the game screen after every placement.
func on_placed(r: Dictionary) -> void:
	if step == Step.DONE:
		return
	if not (r["pens"] as Array).is_empty():
		_go(Step.CAPTURED)
		Profile.mark_seen("tutorial_done")
		var tw: Tween = create_tween()
		tw.tween_interval(3.4)
		tw.tween_callback(func() -> void: _say("Use all three pieces and three more arrive. Keep going!"))
		tw.tween_interval(3.2)
		tw.tween_callback(_finish)
	elif play.state.tray_count() == 3 or play.state.refills > 1:
		# The first tray is used up without a capture: carry on normally.
		Profile.mark_seen("tutorial_done")
		_finish()
	else:
		_go(Step.SHOW if play.state.tray[0] == "i2v" else Step.FREE)


func _finish() -> void:
	step = Step.DONE
	play.board.set_target(PackedInt32Array())
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)


func _say(text: String) -> void:
	if text == _shown_text:
		return
	_shown_text = text
	_bubble.visible = not text.is_empty()
	_caption.text = text
	_bubble.reset_size()
	_bubble.pivot_offset = _bubble.size * 0.5
	_bubble.scale = Vector2(0.9, 0.9)
	create_tween().tween_property(_bubble, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	var b: BoardView = play.board
	var top: Vector2 = b.grid_global() - global_position
	_bubble.position = Vector2((size.x - _bubble.size.x) * 0.5, top.y + b.cell_size() * 0.25)
	queue_redraw()


func _draw() -> void:
	if step != Step.SHOW or play.state.tray[0] != "i2v":
		return
	var tray: TrayView = play.tray
	var b: BoardView = play.board
	var cs: float = b.cell_size()
	# A looping demo: the hand presses the piece, drags it up into the gap, lets go.
	var cycle: float = fmod(_t, 2.8) / 2.8
	var press: float = clampf(cycle / 0.12, 0.0, 1.0)
	var move: float = clampf((cycle - 0.14) / 0.56, 0.0, 1.0)
	move = 1.0 - pow(1.0 - move, 3.0)
	var release: float = clampf((cycle - 0.76) / 0.12, 0.0, 1.0)
	var start: Vector2 = tray.global_position - global_position + tray.slot_rect(0).get_center()
	var finger_end: Vector2 = tray.finger_for(0, RunState.TUTORIAL_TARGET) - global_position
	var hand: Vector2 = start.lerp(finger_end, move)
	var alpha: float = minf(press, 1.0 - clampf((cycle - 0.9) / 0.1, 0.0, 1.0))
	# The ghost piece travelling with the hand.
	var sz: Vector2 = Vector2(Pieces.size_of("i2v")) * cs
	var corner: Vector2 = hand - Vector2(sz.x / 2.0, sz.y + TrayView.LIFT_CELLS * cs)
	if move > 0.02:
		TrayView.draw_piece(self, "i2v", corner, lerpf(tray.mini_cell(), cs, minf(1.0, move * 2.0)), Style.WALL, 0.55 * alpha)
	draw_arc(start, 18.0 + 22.0 * press, 0.0, TAU, 32, Color(Style.AMBER, 0.6 * (1.0 - press)), 3.0, true)
	if release > 0.0:
		draw_arc(hand, 16.0 + 30.0 * release, 0.0, TAU, 32, Color(Style.AMBER, 0.7 * (1.0 - release)), 3.0, true)
	var s: float = 84.0 * (1.0 - 0.12 * press + 0.12 * release)
	var r: Rect2 = Rect2(hand - Vector2(s * 0.3, s * 0.05), Vector2(s, s))
	draw_texture_rect(UIKit.icon("pointer-filled"), r, false, Color(1, 1, 1, alpha))
	draw_texture_rect(UIKit.icon("pointer"), r, false, Color(Style.PAPER_INK, alpha))
