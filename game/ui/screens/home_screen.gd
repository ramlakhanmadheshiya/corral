extends Screen
## Title screen: Shop, keys, coins and Settings along the top; the name; a live
## demo board; then one centred column with Play, Challenges and Awards,
## today's Daily Board and today's missions.

var _daily_status: Label
var _daily_btn: Button
var _missions: Label


func build() -> void:
	Audio.music("menu")
	body.add_theme_constant_override("separation", 14)
	var top: HBoxContainer = UIKit.hbox(12, BoxContainer.ALIGNMENT_BEGIN)
	top.custom_minimum_size.y = 92
	var shop: Button = UIKit.icon_button("art:bag", Style.TOP_BUTTON)
	shop.name = "Shop"
	shop.pressed.connect(func() -> void: app.go("shop"))
	top.add_child(shop)
	var fill: Control = Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(fill)
	var keys: CounterChip = UIKit.key_chip()
	keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(keys)
	var coins: CounterChip = UIKit.coin_chip()
	coins.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(coins)
	var settings: Button = UIKit.icon_button("settings", Style.TOP_BUTTON)
	settings.name = "SettingsButton"
	settings.pressed.connect(func() -> void: app.open_settings())
	top.add_child(settings)
	body.add_child(top)

	var title_box: VBoxContainer = UIKit.vbox(0)
	var title: Label = UIKit.label("Corral", 86, Style.INK, 700)
	title.name = "Title"
	title_box.add_child(title)
	title_box.add_child(UIKit.caption("Fence in big pens", Style.AMBER))
	body.add_child(title_box)

	var demo: DemoBoard = DemoBoard.new(320)
	demo.name = "Demo"
	body.add_child(demo)

	var column: VBoxContainer = UIKit.vbox(14)
	column.custom_minimum_size.x = 560
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var play: Button = UIKit.button("Play", "primary", Style.AMBER, 112, 40, "play")
	play.name = "Play"
	play.pressed.connect(_on_play)
	column.add_child(play)
	var pulse: Tween = create_tween().set_loops()
	pulse.tween_property(play, "scale", Vector2(1.03, 1.03), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(play, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	play.resized.connect(func() -> void: play.pivot_offset = play.size / 2)
	play.button_down.connect(func() -> void: pulse.kill())
	var best: int = Profile.best_score()
	var where: Label = UIKit.label("Best score %s" % Catalog.thousands(best) if best > 0 else "Classic · Daily Board · Challenges", Style.SIZE_SMALL + 1, Style.MUTED, 600)
	where.name = "BestLine"
	column.add_child(where)
	var row: HBoxContainer = UIKit.hbox(14)
	var chapters: Button = UIKit.button("Challenges", "soft", Style.AMBER, 84, 26, "art:star")
	chapters.name = "Challenges"
	chapters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chapters.pressed.connect(func() -> void: app.go("chapters"))
	row.add_child(chapters)
	var awards: Button = UIKit.button("Awards", "soft", Style.AMBER, 84, 26, "art:trophy")
	awards.name = "Awards"
	awards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	awards.pressed.connect(func() -> void: app.open(AchievementsCard.new()))
	row.add_child(awards)
	column.add_child(row)
	column.add_child(_daily_card())
	column.add_child(_missions_row())
	body.add_child(column)

	var timer: Timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_update_daily)
	add_child(timer)
	_update_daily()


## First time: straight into a guided Classic run. After that: pick a mode.
func _on_play() -> void:
	if not Profile.seen("tutorial_done"):
		app.go("play", {"mode": "classic"})
	else:
		app.go("modes")


func _daily_card() -> PanelContainer:
	var row: HBoxContainer = UIKit.hbox(16, BoxContainer.ALIGNMENT_BEGIN)
	row.add_child(UIKit.art_rect("calendar", 58))
	var mid: VBoxContainer = UIKit.vbox(2)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(UIKit.label("Daily Board", Style.SIZE_BODY, Style.INK, 700, HORIZONTAL_ALIGNMENT_LEFT))
	_daily_status = UIKit.label("", Style.SIZE_CAPTION + 1, Style.MUTED, 500, HORIZONTAL_ALIGNMENT_LEFT)
	_daily_status.name = "DailyStatus"
	_daily_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mid.add_child(_daily_status)
	row.add_child(mid)
	_daily_btn = UIKit.button("Play", "primary", Color("8FA8FF") if not Style.DARK else Color("9DB2FF"), 72, 26)
	_daily_btn.name = "Daily"
	_daily_btn.custom_minimum_size.x = 140
	_daily_btn.pressed.connect(func() -> void: app.go("play", {"mode": "daily", "date": Catalog.today_key()}))
	row.add_child(_daily_btn)
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.lip_box(Style.PANEL, 30, Style.LIP, 6, Vector2(20, 12)))
	p.add_child(row)
	return p


func _missions_row() -> Button:
	var b: Button = UIKit.button("", "ghost", Style.AMBER, 74, 22)
	b.name = "Missions"
	b.pressed.connect(func() -> void: app.open(MissionsCard.new()))
	var row: HBoxContainer = UIKit.hbox(12, BoxContainer.ALIGNMENT_BEGIN)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 20
	row.offset_right = -16
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UIKit.icon_rect("list-checks", 34, Style.AMBER))
	_missions = UIKit.label("", Style.SIZE_SMALL, Style.INK, 600, HORIZONTAL_ALIGNMENT_LEFT)
	_missions.name = "MissionsText"
	_missions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_missions)
	row.add_child(UIKit.icon_rect("chevron-right", 26, Style.MUTED))
	b.add_child(row)
	return b


func _update_daily() -> void:
	var today: String = Catalog.today_key()
	var streak: int = Profile.current_streak()
	var streak_text: String = "%d-day streak" % streak if streak > 0 else "Start a streak"
	if Profile.daily_done(today):
		var now: Dictionary = Time.get_time_dict_from_system()
		var left: int = 86400 - (int(now["hour"]) * 3600 + int(now["minute"]) * 60 + int(now["second"]))
		var res: Dictionary = Profile.daily_result(today)
		_daily_status.text = "%s pts · %s · next in %dh %02dm" % [Catalog.thousands(int(res.get("score", 0))), streak_text, left / 3600, (left % 3600) / 60]
		_daily_btn.text = "Replay"
	else:
		_daily_status.text = "Same pieces for everyone · +%d coins" % Economy.daily_reward(streak + 1)
		_daily_btn.text = "Play"
	var done: int = Profile.missions_done()
	_missions.text = "Today's missions · %d/3 done" % done if done < 3 else "All of today's missions done ✓"


func refresh() -> void:
	_update_daily()
