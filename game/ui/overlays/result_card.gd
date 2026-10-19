class_name ResultCard
extends Overlay
## Shown when a game ends. Classic: the score counts up, a new best is
## celebrated, with the run's pens, biggest pen, gems and combos. Daily Board:
## stars by score and the streak. Challenge: stars by pieces used (or, if the
## goal was missed, how close it got). Coins count up, then the next step:
## Play again / Next, with Again, Levels, Share and Home underneath.

const STAR_TITLES: Array[String] = ["Not quite", "Done", "Nicely done", "Perfect!"]

var play: Node
var reward: Dictionary = {}


func _init() -> void:
	super._init()
	dismissable = false


func build() -> void:
	name = "Result"
	body.add_theme_constant_override("separation", 12)
	var s: RunState = play.state
	var acc: Color = play.accent()
	var failed: bool = bool(reward.get("failed", false))
	var where: String = "Classic"
	match play.mode:
		"daily":
			where = "Daily Board · %s" % play._pretty_date(play.date_key)
		"challenge":
			where = "%s · Challenge %d" % [Catalog.chapter(play.chapter_idx)["name"], play.level_n]
	body.add_child(UIKit.caption(where, acc))
	var title: Label = UIKit.label(_title(), Style.SIZE_H1 + 6, Style.INK, 600)
	title.name = "ResultTitle"
	body.add_child(title)
	if play.mode != "classic" and not failed:
		var row: StarRow = StarRow.new()
		row.name = "Stars"
		body.add_child(row)
		row.play(s.stars())
	if failed:
		body.add_child(UIKit.para("%s · goal %s/%s" % ["No room left for your pieces" if s.end == RunState.End.STUCK else "Out of pieces", Catalog.thousands(mini(s.goal_value(), s.goal_target())), Catalog.thousands(s.goal_target())], Style.SIZE_BODY - 2, Style.INK))
		body.add_child(UIKit.para(Catalog.goal_text(s.goal) + ". A hint shows a good spot when you're stuck.", Style.SIZE_SMALL))
	else:
		var score: Label = UIKit.label("0", 84, Style.INK, 800)
		score.name = "FinalScore"
		body.add_child(score)
		var tw: Tween = create_tween()
		tw.tween_interval(0.3)
		tw.tween_method(func(v: float) -> void: score.text = Catalog.thousands(int(v)), 0.0, float(s.score), 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		body.add_child(_stats(s))
	if play.mode == "classic":
		var best: int = int(reward.get("best", s.score))
		if bool(reward.get("new_best", false)) and int(reward.get("old_best", 0)) > 0:
			body.add_child(_note("trophy", "New best! Up from %s" % Catalog.thousands(int(reward["old_best"])), Style.GOLD))
		else:
			body.add_child(UIKit.label("Best %s" % Catalog.thousands(best), Style.SIZE_SMALL, Style.MUTED, 600))
	elif play.mode == "challenge" and not failed:
		body.add_child(UIKit.label("Goal done in %d pieces · ★★★ in %d or fewer" % [s.placed, int(s.par[0]) if s.par.size() > 0 else s.placed], Style.SIZE_SMALL, Style.MUTED, 500))
	var coins: int = int(reward.get("coins", 0))
	if coins > 0:
		var coin_row: HBoxContainer = UIKit.hbox(12)
		coin_row.add_child(UIKit.art_rect("coin", 48))
		var amount: Label = UIKit.label("+0", 38, Style.GOLD.darkened(0.1) if not Style.DARK else Style.GOLD, 700)
		amount.name = "Reward"
		coin_row.add_child(amount)
		body.add_child(coin_row)
		var tw2: Tween = create_tween()
		tw2.tween_interval(1.1)
		tw2.tween_method(func(v: float) -> void: amount.text = "+%d" % int(v), 0.0, float(coins), 0.6)
		tw2.tween_callback(func() -> void: Audio.play("coin"))
	if play.mode == "daily":
		if bool(reward.get("first", false)):
			body.add_child(_note("flame", "%d-day streak · a new board arrives tomorrow" % int(reward.get("streak", 1)), Color("FF8A3D")))
		else:
			body.add_child(UIKit.para("Today's coins are paid once. Replays can still raise today's best.", Style.SIZE_CAPTION))
	if play.mode == "challenge" and not failed:
		if not bool(reward.get("first", true)) and coins == 0:
			body.add_child(UIKit.para("Rewards are paid once per challenge, and for each new star.", Style.SIZE_CAPTION))
		if bool(reward.get("chapter_done", false)):
			body.add_child(_note("trophy", "Chapter complete! +%d bonus coins" % Economy.CHAPTER_BONUS, Style.GOLD))
		if bool(reward.get("chapter_unlocked", false)):
			var nc: Dictionary = Catalog.chapter(play.chapter_idx + 1)
			if not nc.is_empty():
				body.add_child(_note("lock", "New chapter open: %s" % nc["name"], nc["accent"]))
				get_tree().create_timer(1.0).timeout.connect(func() -> void: Audio.play("unlock"))

	body.add_child(UIKit.gap(4))
	var next_text: String = "Play again"
	var next_icon: String = "rotate-ccw"
	match play.mode:
		"daily":
			next_text = "Done"
			next_icon = "check"
		"challenge":
			if failed:
				next_text = "Try again"
			else:
				next_text = "Next challenge" if play.level_n < Catalog.levels_per_chapter else "Next chapter"
				next_icon = "arrow-right"
	var next: Button = UIKit.button(next_text, "primary", acc, 100, 34, next_icon)
	next.name = "Next"
	next.pressed.connect(func() -> void:
		if failed:
			_leave(Callable(play, "restart"))
		else:
			_leave(Callable(play, "go_next")))
	body.add_child(next)
	var actions: HBoxContainer = UIKit.hbox(24)
	if play.mode != "classic" and not failed:
		actions.add_child(_action("rotate-ccw", "AGAIN", "Again", func() -> void: _leave(Callable(play, "restart"))))
	if play.mode == "challenge":
		actions.add_child(_action("layout-grid", "LEVELS", "Levels", func() -> void: _leave(app.go.bind("levels", {"chapter": play.chapter_idx}))))
	if not failed:
		actions.add_child(_action("share-2", "SHARE", "Share", func() -> void: open_child(_share_card())))
	actions.add_child(_action("house", "HOME", "Home", func() -> void: _leave(app.go.bind("home"))))
	body.add_child(actions)


func _title() -> String:
	var s: RunState = play.state
	match play.mode:
		"classic":
			if bool(reward.get("new_best", false)) and s.score > 0:
				return "New best!"
			return "Run over"
		"daily":
			return ["", "Good round", "Great round", "Superb!"][clampi(s.stars(), 1, 3)]
	if bool(reward.get("failed", false)):
		return "Not quite"
	return STAR_TITLES[clampi(s.stars(), 1, 3)]


func _stats(s: RunState) -> HBoxContainer:
	var stats: HBoxContainer = UIKit.hbox(8)
	stats.name = "RunStats"
	for item: Array in [["Pens", s.captures], ["Biggest", s.biggest], ["Gems", s.gems_captured], ["Combos", s.combos]]:
		var col: VBoxContainer = UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(str(item[1]), Style.SIZE_H2 - 2, Style.INK, 700))
		col.add_child(UIKit.caption(str(item[0]), Style.MUTED, 15))
		stats.add_child(col)
	return stats


## Leaves the result. Every few games a short video plays first (see
## AdManager.after_game); `then` belongs to the game screen or the App, so it
## still runs after this card has gone.
func _leave(then: Callable) -> void:
	close()
	AdManager.after_game(then)


func _share_card() -> ShareCardOverlay:
	var s: RunState = play.state
	var o: ShareCardOverlay = ShareCardOverlay.new()
	o.info = {
		"mode": play.mode, "state": s, "score": s.score, "stars": s.stars(), "biggest": s.biggest,
		"title": _title(), "date": play.date_key, "number": play.level_n,
		"chapter": str(Catalog.chapter(play.chapter_idx).get("name", "")) if play.mode == "challenge" else "",
		"goal": Catalog.goal_text(s.goal), "accent": play.accent(), "sky": play.sky(),
	}
	return o


func _action(icon_name: String, caption: String, node_name: String, cb: Callable) -> VBoxContainer:
	var box: VBoxContainer = UIKit.vbox(6)
	var b: Button = UIKit.icon_button(icon_name, 76)
	b.name = node_name
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	box.add_child(b)
	box.add_child(UIKit.caption(caption, Style.MUTED, 15))
	return box


func _note(icon_name: String, text: String, tint: Color) -> PanelContainer:
	var row: HBoxContainer = UIKit.hbox(12)
	if UIKit.art(icon_name) != null:
		row.add_child(UIKit.art_rect(icon_name, 36))
	else:
		row.add_child(UIKit.icon_rect(icon_name, 34, tint))
	var l: Label = UIKit.label(text, Style.SIZE_SMALL, Style.INK, 600)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return UIKit.panel(row, Color(tint, 0.14), 26, Vector2(20, 10))


func on_back() -> void:
	_leave(app.go.bind("home") if play.mode != "challenge" else app.go.bind("levels", {"chapter": play.chapter_idx}))
