extends Screen
## Playing Classic (args {mode: "classic"}), a Daily Board ({mode: "daily",
## date}) or a challenge ({chapter, level}). Laid out like the earlier games'
## game screens: header, a strip with the score (and the goal or pieces left),
## a message line, the board, the tray, and a bottom bar with Back, Hint,
## Shuffle (Classic) and Restart. The run is saved after every move, so it
## resumes after the app closes.

const MONTHS: Array[String] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

var state: RunState
var board: BoardView
var tray: TrayView
var mode: String = "classic"
var chapter_idx: int = -1
var level_n: int = 0
var date_key: String = ""
var run_key: String = ""
var level_data: Dictionary = {}
var tutorial: Tutorial

var _score_label: Label
var _shown_score: float = 0.0
var _score_tween: Tween
var _side_label: Label
var _side_caption: Label
var _goal_label: Label
var _goal_bar: ProgressBar
var _stars_label: Label
var _msg: Label
var _msg_box: PanelContainer
var _msg_tween: Tween
var _hint_btn: Button
var _hint_badge: Label
var _shuffle_btn: Button
var _shuffle_badge: Label
var _done: bool = false
var _confirm_restart: bool = false


func chapter_info() -> Dictionary:
	if args.has("chapter"):
		return Catalog.chapter(int(args.get("chapter", 0)))
	if str(args.get("mode", "")) == "daily":
		return {"accent": Color("7C93F2")}
	return {}


func in_game() -> bool:
	return true


func build() -> void:
	if args.has("chapter"):
		mode = "challenge"
		chapter_idx = int(args.get("chapter", 0))
		level_n = int(args.get("level", 1))
		level_data = Catalog.level(chapter_idx, level_n)
		run_key = str(level_data.get("id", ""))
	else:
		mode = str(args.get("mode", "classic"))
		if mode == "daily":
			date_key = str(args.get("date", Catalog.today_key()))
			level_data = Catalog.daily(date_key)
			run_key = "daily-" + date_key
		else:
			mode = "classic"
			run_key = "classic"
	if mode != "classic" and level_data.is_empty():
		_build_error()
		return
	state = _start_state()
	if state.tutorial and Profile.seen("tutorial_done"):
		# The guided tray was already shown (this is a resumed run): carry on normally.
		state.tutorial = false
	if mode == "challenge":
		Profile.set_last_level(run_key)
	Audio.music("play")
	_build_ui()
	_refresh(true)
	if state.tutorial:
		_start_tutorial.call_deferred()
	elif state.is_over():
		_finish.call_deferred()


func _start_state() -> RunState:
	var saved: Dictionary = Profile.saved_run(run_key)
	if not saved.is_empty():
		var s: RunState = RunState.from_dict(saved)
		if not s.is_over() and s.mode == (mode if mode != "classic" else "classic"):
			return s
	match mode:
		"challenge":
			return RunState.from_level(level_data, "challenge")
		"daily":
			return RunState.from_level(level_data, "daily")
	var seed_value: int = int(Time.get_unix_time_from_system()) ^ (Time.get_ticks_usec() & 0xFFFF)
	if not Profile.seen("tutorial_done"):
		return RunState.first_run(seed_value)
	return RunState.classic(seed_value)


func _build_error() -> void:
	body.add_child(header("Unavailable"))
	body.add_child(UIKit.gap(120))
	body.add_child(UIKit.icon_rect("info", 96, Style.MUTED))
	body.add_child(UIKit.para("This board could not be loaded. %s" % Catalog.last_error, Style.SIZE_BODY))
	var b: Button = UIKit.button("Back", "soft")
	b.pressed.connect(app.back)
	body.add_child(b)


func _title() -> Array:
	match mode:
		"challenge":
			return ["%s %d" % [Catalog.chapter(chapter_idx)["name"], level_n], "Challenge"]
		"daily":
			return ["Daily Board", _pretty_date(date_key)]
	return ["Classic", "Endless"]


func _build_ui() -> void:
	body.add_theme_constant_override("separation", 10)
	var t: Array = _title()
	body.add_child(header(str(t[0]), str(t[1])))
	body.add_child(_strip())
	# The message line: combos, warnings and tips, on their own line (it keeps its
	# height so nothing jumps).
	var line: CenterContainer = CenterContainer.new()
	line.name = "MessageLine"
	line.custom_minimum_size.y = 50
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg_box = PanelContainer.new()
	_msg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg_box.add_theme_stylebox_override("panel", UIKit.box(Style.PANEL, 26, Color(Style.INK, 0.08), 2, Vector2(22, 4)))
	_msg = UIKit.label("", 25, Style.INK, 700)
	_msg.name = "Message"
	_msg_box.add_child(_msg)
	_msg_box.modulate.a = 0.0
	line.add_child(_msg_box)
	body.add_child(line)

	board = BoardView.new()
	board.name = "Board"
	board.setup(state)
	body.add_child(board)

	tray = TrayView.new()
	tray.name = "Tray"
	body.add_child(tray)
	tray.setup(state, board)
	tray.drag_moved.connect(_on_drag_moved)
	tray.drag_released.connect(_on_drag_released)

	var bar: HBoxContainer = UIKit.hbox(30)
	bar.name = "Bar"
	bar.add_child(_action("layout-grid" if mode == "challenge" else "house", "LEVELS" if mode == "challenge" else "BACK", "BackButton", 76, func() -> void: app.back()))
	var hint: Array = _priced_action("art:hint", "HINT", "Hint", use_hint)
	_hint_btn = hint[0]
	_hint_badge = hint[1]
	bar.add_child(hint[2])
	if mode == "classic":
		var sh: Array = _priced_action("art:shuffle", "SHUFFLE", "Shuffle", use_shuffle)
		_shuffle_btn = sh[0]
		_shuffle_badge = sh[1]
		bar.add_child(sh[2])
	bar.add_child(_action("rotate-ccw", "RESTART", "Restart", 76, ask_restart))
	body.add_child(bar)


## The strip over the board: the score on the left; best score, pieces left or
## the goal on the right.
func _strip() -> PanelContainer:
	var row: HBoxContainer = UIKit.hbox(14, BoxContainer.ALIGNMENT_BEGIN)
	row.name = "Strip"
	var left: VBoxContainer = UIKit.vbox(-6)
	left.custom_minimum_size.x = 190
	left.add_child(UIKit.caption("Score", Style.MUTED, 16, HORIZONTAL_ALIGNMENT_LEFT))
	_score_label = UIKit.label("0", 46, Style.INK, 800, HORIZONTAL_ALIGNMENT_LEFT)
	_score_label.name = "Score"
	left.add_child(_score_label)
	row.add_child(left)
	if mode == "challenge":
		var goal: VBoxContainer = UIKit.vbox(4)
		goal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var grow: HBoxContainer = UIKit.hbox(8, BoxContainer.ALIGNMENT_BEGIN)
		grow.add_child(UIKit.art_rect(Catalog.goal_icon(state.goal), 30))
		_goal_label = UIKit.label("", 21, Style.INK, 700, HORIZONTAL_ALIGNMENT_LEFT)
		_goal_label.name = "Goal"
		_goal_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grow.add_child(_goal_label)
		goal.add_child(grow)
		_goal_bar = UIKit.progress_bar(0.0, accent(), 10)
		goal.add_child(_goal_bar)
		row.add_child(goal)
	else:
		var fill: Control = Control.new()
		fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(fill)
	var right: VBoxContainer = UIKit.vbox(-6)
	right.custom_minimum_size.x = 150
	_side_caption = UIKit.caption("Best" if mode == "classic" else "Pieces", Style.MUTED, 16, HORIZONTAL_ALIGNMENT_RIGHT)
	right.add_child(_side_caption)
	_side_label = UIKit.label("", 38, Style.INK, 700, HORIZONTAL_ALIGNMENT_RIGHT)
	_side_label.name = "Side"
	right.add_child(_side_label)
	if mode != "classic":
		_stars_label = UIKit.label("", 18, Style.GOLD.darkened(0.15) if not Style.DARK else Style.GOLD, 700, HORIZONTAL_ALIGNMENT_RIGHT)
		_stars_label.name = "StarsLine"
		right.add_child(_stars_label)
	row.add_child(right)
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.lip_box(Style.PANEL, 28, Style.LIP, 5, Vector2(22, 8)))
	p.add_child(row)
	return p


func _action(icon_name: String, caption: String, node_name: String, size_px: float, cb: Callable) -> VBoxContainer:
	var box: VBoxContainer = UIKit.vbox(4)
	var b: Button = UIKit.icon_button(icon_name, size_px)
	b.name = node_name
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	box.add_child(b)
	box.add_child(UIKit.caption(caption, Style.MUTED, 15))
	return box


## A button with a price badge. Returns [button, badge, box].
func _priced_action(icon_name: String, caption: String, node_name: String, cb: Callable) -> Array:
	var box: VBoxContainer = _action(icon_name, caption, node_name, 84, cb)
	var b: Button = box.get_child(0)
	var badge: Label = UIKit.label("", 16, Style.PAPER_INK, 800)
	badge.name = "Badge"
	badge.add_theme_stylebox_override("normal", UIKit.box(Style.GOLD, 13, Color.TRANSPARENT, 0, Vector2(8, 1)))
	badge.position = Vector2(50, -8)
	b.add_child(badge)
	return [b, badge, box]


func _pretty_date(key: String) -> String:
	var parts: PackedStringArray = key.split("-")
	if parts.size() != 3:
		return key
	return "%s %d" % [MONTHS[clampi(int(parts[1]) - 1, 0, 11)], int(parts[2])]


func _refresh(instant: bool = false) -> void:
	if state == null or _score_label == null:
		return
	_set_score(state.score, instant)
	match mode:
		"classic":
			_side_label.text = Catalog.thousands(maxi(Profile.best_score(), state.score))
		"daily":
			_side_label.text = str(state.pieces_left())
			var th: Array = state.thresholds
			if th.size() >= 2:
				if state.score >= int(th[1]):
					_stars_label.text = "★★★ reached"
				elif state.score >= int(th[0]):
					_stars_label.text = "★★★ at %s" % Catalog.thousands(int(th[1]))
				else:
					_stars_label.text = "★★ at %s" % Catalog.thousands(int(th[0]))
		"challenge":
			_side_label.text = str(state.pieces_left())
			_goal_label.text = "%s  %s/%s" % [Catalog.goal_text(state.goal), Catalog.thousands(mini(state.goal_value(), state.goal_target())), Catalog.thousands(state.goal_target())]
			_goal_bar.value = clampf(float(state.goal_value()) / float(maxi(1, state.goal_target())), 0.0, 1.0)
			var par: Array = state.par
			if par.size() >= 2:
				var next_piece: int = state.placed + 1
				var stars: int = 3 if next_piece <= int(par[0]) else (2 if next_piece <= int(par[1]) else 1)
				_stars_label.text = "★".repeat(stars) + "☆".repeat(3 - stars) + " on offer"
	var free: int = Profile.free_hints_left()
	_hint_badge.text = "FREE" if free > 0 else str(Economy.HINT_COST)
	_hint_badge.reset_size()
	_hint_btn.disabled = _done or state.is_over()
	if _shuffle_btn != null:
		_shuffle_badge.text = str(Economy.SHUFFLE_COST)
		_shuffle_badge.reset_size()
		_shuffle_btn.disabled = _done or state.is_over() or state.tutorial


func _set_score(v: int, instant: bool) -> void:
	if _score_tween != null:
		_score_tween.kill()
	if instant:
		_shown_score = v
		_score_label.text = Catalog.thousands(v)
		return
	_score_tween = create_tween()
	_score_tween.tween_method(func(x: float) -> void:
		_shown_score = x
		_score_label.text = Catalog.thousands(int(round(x))), _shown_score, float(v), 0.5).set_delay(0.35)
	if v - int(_shown_score) >= 100:
		_score_label.pivot_offset = _score_label.size / 2.0
		var pop: Tween = create_tween()
		pop.tween_interval(0.35)
		pop.tween_property(_score_label, "scale", Vector2(1.18, 1.18), 0.12)
		pop.tween_property(_score_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A short message on the line above the board (0 s = until hidden).
func show_message(text: String, seconds: float = 1.8, color: Color = Style.INK) -> void:
	_msg.text = text
	_msg.add_theme_color_override("font_color", color)
	_msg_box.reset_size()
	if _msg_tween != null:
		_msg_tween.kill()
	_msg_tween = create_tween()
	_msg_tween.tween_property(_msg_box, "modulate:a", 1.0, 0.12)
	if seconds > 0.0:
		_msg_tween.tween_interval(seconds)
		_msg_tween.tween_property(_msg_box, "modulate:a", 0.0, 0.3)


# --- Dragging and placing --------------------------------------------------------

func _on_drag_moved(slot: int, corner: Vector2) -> void:
	if state == null or state.is_over() or state.tray[slot].is_empty():
		return
	var o: Vector2i = board.snap(corner)
	var sz: Vector2i = Pieces.size_of(state.tray[slot])
	if o.x < -sz.x or o.y < -sz.y or o.x > Field.N or o.y > Field.N:
		board.clear_ghost()
		return
	var valid: bool = state.can_place(slot, o)
	board.set_ghost(state.tray[slot], o, valid, state.preview(slot, o) if valid else ([] as Array[PackedInt32Array]))


func _on_drag_released(slot: int, corner: Vector2) -> void:
	board.clear_ghost()
	if state == null or state.is_over():
		return
	var o: Vector2i = board.snap(corner)
	if state.can_place(slot, o):
		place(slot, o)
	else:
		tray.return_piece(slot, corner)


## Places a piece and plays out the result (tests call this directly too).
func place(slot: int, origin: Vector2i) -> Dictionary:
	if _done or not state.can_place(slot, origin):
		return {"ok": false}
	var r: Dictionary = state.place(slot, origin)
	board.play_result(r)
	Profile.record_turn(r)
	var pens: Array = r["pens"]
	if int(r["combo"]) >= 2:
		show_message("Combo! %d pens at once · ×%s" % [int(r["combo"]), BoardView._mult_text(Scoring.combo_mult(int(r["combo"])))], 2.0, Style.AMBER)
	elif not pens.is_empty():
		var area: int = 0
		var gems: int = 0
		for p: Dictionary in pens:
			area = maxi(area, int(p["area"]))
			gems += int(p["gems"])
		if gems > 0:
			show_message("Gem pen! ×%d" % int(pow(2, gems)), 1.6, Style.GEM.darkened(0.2) if not Style.DARK else Style.GEM)
		elif area >= 16:
			show_message("Huge pen! %d cells" % area, 1.6, Style.AMBER)
		elif area >= 9:
			show_message("Big pen! %d cells" % area, 1.6, Style.AMBER)
	for e: Dictionary in r.get("events", []):
		if str(e["type"]) == "rock":
			show_message("A rock landed · rocks never vanish", 2.0, Style.MUTED)
	if bool(r["refilled"]) and not state.is_over():
		get_tree().create_timer(0.25).timeout.connect(func() -> void:
			if is_instance_valid(tray):
				tray.deal())
	if tutorial != null:
		tutorial.on_placed(r)
	if state.is_over():
		_done = true
		tray.enabled = false
		Profile.clear_run(run_key)
		var wait: float = maxf(0.6, board._busy_until - board._t + 0.25)
		get_tree().create_timer(wait).timeout.connect(func() -> void:
			if is_inside_tree():
				_finish())
	else:
		Profile.store_run(run_key, state)
		if mode == "daily" or mode == "challenge":
			if state.pieces_left() <= 3 and state.pieces_left() > 0 and not state.goal_met():
				show_message("%d %s left" % [state.pieces_left(), "piece" if state.pieces_left() == 1 else "pieces"], 1.4, Style.MUTED)
	Profile.check_achievements()
	_refresh()
	return r


# --- Ending --------------------------------------------------------------------

func _finish() -> void:
	_done = true
	tray.enabled = false
	_refresh()
	if mode == "classic" and state.end == RunState.End.STUCK and state.continues == 0 and not state.tutorial:
		Audio.play("gameover", 1.0, -4.0)
		show_message("No room for these pieces", 0.0, Style.ERROR)
		var c: ContinueCard = ContinueCard.new()
		c.play = self
		app.open(c)
		return
	finish_run()


## Records the result and shows the result card.
func finish_run() -> void:
	var reward: Dictionary = {}
	match mode:
		"classic":
			reward = Profile.finish_classic(state)
			Audio.play("complete" if bool(reward.get("new_best", false)) else "gameover", 1.0, -3.0)
		"daily":
			reward = Profile.complete_daily(date_key, state)
			Audio.play("complete", 1.0, -3.0)
		"challenge":
			if state.goal_met():
				reward = Profile.complete_level(run_key, state)
				Audio.play("complete", 1.0, -3.0)
			else:
				reward = {"failed": true}
				Audio.play("gameover", 1.0, -3.0)
				Haptics.error()
	Profile.clear_run(run_key)
	Profile.check_achievements()
	var o: ResultCard = ResultCard.new()
	o.play = self
	o.reward = reward
	app.open(o)


## The one continue (after a video or for coins): clears walls, deals a new tray.
func continue_run() -> void:
	var cleared: PackedInt32Array = state.continue_run()
	_done = state.is_over()
	tray.enabled = not _done
	for k: int in cleared.size():
		board._vanish[cleared[k]] = board._t + 0.03 * k
	Audio.play("vanish", 1.0, -2.0)
	tray.deal()
	show_message("Fresh start: walls cleared, new pieces", 2.0, Style.SUCCESS)
	Profile.store_run(run_key, state)
	_refresh()
	if _done:
		finish_run()


## Next: the next challenge, or (Classic and Daily) back to the modes.
func go_next() -> void:
	if mode == "challenge" and state.goal_met():
		if level_n < Catalog.levels_per_chapter:
			app.go("play", {"chapter": chapter_idx, "level": level_n + 1})
		elif chapter_idx + 1 < Catalog.chapter_count() and Profile.chapter_unlocked(chapter_idx + 1):
			app.go("levels", {"chapter": chapter_idx + 1})
		else:
			app.go("chapters")
	elif mode == "classic":
		restart()
	else:
		app.go("modes")


func restart() -> void:
	Profile.clear_run(run_key)
	app.go("play", args)


func ask_restart() -> void:
	if _done:
		restart()
		return
	if state.placed == 0:
		return
	var o: MessageCard = MessageCard.new()
	o.title_text = "Start over?"
	o.message = "This run's score (%s) will be lost." % Catalog.thousands(state.score) if mode == "classic" else "You'll start this board again from the first piece."
	o.icon_name = "rotate-ccw"
	o.buttons = [["Start over", "primary", func() -> void:
		o.close()
		restart()
	], ["Keep playing", "ghost", func() -> void: o.close()]]
	app.open(o)


# --- Hints and shuffles ------------------------------------------------------------

## Shows where the best piece goes (free once a day, then coins, or a video when
## out of coins; on the web, where there are no videos, it's free).
func use_hint() -> void:
	if _done or state.is_over():
		return
	if Profile.free_hints_left() > 0:
		Profile.use_free_hint()
		_give_hint()
	else:
		_pay(Economy.HINT_COST, "a hint", _give_hint)


func _give_hint() -> void:
	var m: Array = CorralBot.best_move(state)
	if m.is_empty():
		return
	state.hints += 1
	Profile.record_hint()
	board.show_hint(state.tray[int(m[0])], m[1])
	tray.hint_slot = int(m[0])
	Audio.play("unlock", 1.4, -8.0)
	show_message("The gold outline shows a good spot", 2.0, Style.MUTED)
	_refresh()


func use_shuffle() -> void:
	if _done or state.is_over() or mode != "classic":
		return
	_pay(Economy.SHUFFLE_COST, "a shuffle", func() -> void:
		state.shuffle_tray()
		board.clear_hint()
		tray.hint_slot = -1
		tray.deal()
		Audio.play("pick", 0.8, -2.0)
		Profile.store_run(run_key, state)
		_refresh()
		if state.is_over():
			_finish()
	)


## Pays `cost` coins for something; out of coins, offers a video instead (the
## player chooses), or the coin shop.
func _pay(cost: int, what: String, then: Callable) -> void:
	if Profile.spend(cost):
		Audio.play("coin", 1.0, -6.0)
		then.call()
		return
	if AdManager.provider == null:
		# The web build has no videos: rather than a dead end, it's on the house.
		then.call()
		return
	var o: MessageCard = MessageCard.new()
	o.title_text = "Not enough coins"
	o.message = "%s costs %d coins. Watch a short video for it instead, or get more coins." % [what.capitalize(), cost]
	o.icon_name = "coin"
	o.buttons = [["Watch a video", "primary", func() -> void:
		o.close()
		AdManager.show_rewarded(func(ok: bool) -> void:
			if ok and is_inside_tree():
				then.call()
			elif is_inside_tree():
				show_message("The video was closed early", 1.6, Style.MUTED))
	], ["Get coins", "soft", func() -> void:
		o.close()
		app.open(CoinsCard.new())
	], ["Not now", "ghost", func() -> void: o.close()]]
	app.open(o)


# --- Tutorial ------------------------------------------------------------------------

func _start_tutorial() -> void:
	tutorial = Tutorial.new()
	tutorial.play = self
	add_child(tutorial)


func refresh() -> void:
	_refresh(true)


func on_back() -> bool:
	return false
