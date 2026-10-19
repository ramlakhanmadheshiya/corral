extends Screen
## Pick how to play: Classic (endless, best score), the Daily Board (same pieces
## for everyone today) or Challenges (chapters of goals with stars).


func build() -> void:
	body.add_child(header("Play", "Choose a mode"))
	body.add_child(chip_row([UIKit.key_chip(), UIKit.coin_chip()]))
	var scroll: TouchScroll = TouchScroll.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var list: VBoxContainer = UIKit.vbox(18)
	list.name = "List"
	scroll.set_content(list)
	list.add_child(UIKit.gap(4))

	var saved: Dictionary = Profile.saved_run("classic")
	var best: int = Profile.best_score()
	var classic_line: String = "Best %s" % Catalog.thousands(best) if best > 0 else "No best score yet"
	if not saved.is_empty():
		classic_line = "Run in progress · %s pts · best %s" % [Catalog.thousands(int(saved.get("score", 0))), Catalog.thousands(best)]
	list.add_child(_card("Classic", "Classic", "Endless. Close big pens for big scores, until the pieces stop fitting.", classic_line, "infinity", Style.AMBER,
		func() -> void: app.go("play", {"mode": "classic"})))

	var today: String = Catalog.today_key()
	var streak: int = Profile.current_streak()
	var daily_line: String
	if Profile.daily_done(today):
		var res: Dictionary = Profile.daily_result(today)
		daily_line = "Today: %s pts, %s · %d-day streak" % [Catalog.thousands(int(res.get("score", 0))), "★".repeat(int(res.get("stars", 0))), streak]
	else:
		daily_line = ("%d-day streak · " % streak if streak > 0 else "") + "+%d coins today" % Economy.daily_reward(streak + 1)
	list.add_child(_card("Daily", "Daily Board", "The same rocks, gems and %d pieces for everyone today. Score as high as you can." % DailyBoard.PIECES, daily_line, "calendar", Color("7C93F2"),
		func() -> void: app.go("play", {"mode": "daily", "date": today})))

	var next: Array[int] = Profile.next_level()
	var ch: Dictionary = Catalog.chapter(next[0])
	var ch_line: String = "★ %d / %d · next: %s %d" % [Profile.total_stars(), Catalog.total_levels() * 3, ch.get("name", ""), next[1]]
	list.add_child(_card("Challenges", "Challenges", "%d goals in %d chapters: big pens, gems, combos and scores in a set number of pieces." % [Catalog.total_levels(), Catalog.chapter_count()], ch_line, "star", Color("4FB389"),
		func() -> void: app.go("chapters")))
	list.add_child(UIKit.gap(8))
	var how: Button = UIKit.button("How to play", "ghost", Style.AMBER, 76, 24, "circle-help")
	how.name = "HowToPlay"
	how.custom_minimum_size.x = 360
	how.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	how.pressed.connect(func() -> void: app.open(HowToCard.new()))
	list.add_child(how)
	list.add_child(UIKit.gap(16))


func _card(node_name: String, title: String, blurb: String, line: String, icon_name: String, tint: Color, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.name = node_name
	b.custom_minimum_size = Vector2(0, 200)
	b.focus_mode = Control.FOCUS_ALL
	var fill: Color = Style.SURFACE.lerp(tint, 0.1 if not Style.DARK else 0.14)
	b.add_theme_stylebox_override("normal", UIKit.lip_box(fill, 34, Style.LIP, 8, Vector2(8, 8), false, Color(tint, 0.55)))
	b.add_theme_stylebox_override("hover", UIKit.lip_box(fill.lightened(0.04), 34, Style.LIP, 8, Vector2(8, 8), false, Color(tint, 0.7)))
	b.add_theme_stylebox_override("pressed", UIKit.lip_box(fill.darkened(0.04), 34, Style.LIP, 8, Vector2(8, 8), true, Color(tint, 0.7)))
	b.add_theme_stylebox_override("hover_pressed", UIKit.lip_box(fill.darkened(0.04), 34, Style.LIP, 8, Vector2(8, 8), true, Color(tint, 0.7)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	UIKit.juice(b)
	b.pressed.connect(cb)
	var row: HBoxContainer = UIKit.hbox(20, BoxContainer.ALIGNMENT_BEGIN)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 26
	row.offset_right = -22
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var badge: PanelContainer = UIKit.panel(UIKit.icon_rect(icon_name, 52, Style.PAPER_INK), tint, 30, Vector2(20, 20))
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(badge)
	var text: VBoxContainer = UIKit.vbox(4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(UIKit.label(title, 36, Style.INK, 700, HORIZONTAL_ALIGNMENT_LEFT))
	var bl: Label = UIKit.label(blurb, 21, Style.MUTED, 400, HORIZONTAL_ALIGNMENT_LEFT)
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(bl)
	var ln: Label = UIKit.label(line, 21, tint.darkened(0.15) if not Style.DARK else tint.lightened(0.2), 700, HORIZONTAL_ALIGNMENT_LEFT)
	ln.name = "Line"
	ln.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(ln)
	row.add_child(text)
	row.add_child(UIKit.icon_rect("chevron-right", 30, Style.MUTED))
	return b
