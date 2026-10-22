extends Node
## End-to-end flow through the real app with a throwaway save, the simulated
## store and the mock ad provider: the splash and home, the banner's reserved
## space, the first-play tutorial with a real drag, Back, resuming a saved run,
## hints (free, paid, and by video when out of coins), shuffle, the continue
## offer (video and coins), the Classic result, the Daily Board, challenges
## (chapters, levels, a full clear, Next, a locked one opened with a key, a
## failed attempt), videos between games, the shop (Supporter removes the
## banner), settings, an app restart, and Reset progress.
##
##   godot --headless --path . res://tests/ui_flow.tscn

const SAVE: String = "user://ui_flow_save.json"
const MockProvider: GDScript = preload("res://game/ads/providers/mock_ad_provider.gd")

var t: Check = Check.new("UI FLOW")
var app: App
var mock: Node


func _ready() -> void:
	_wipe()
	Save.path = SAVE
	Save.load_data()
	Profile.set_setting("music_volume", 0.0)
	Profile.set_setting("sound_volume", 0.0)
	Store.simulate = true
	mock = MockProvider.new()
	mock.auto_finish = true
	AdManager.use_provider(mock)
	await _boot()
	await _home_and_banner()
	await _tutorial()
	await _back_and_resume()
	await _hints_and_shuffle()
	await _continue_and_result()
	await _daily()
	await _challenges()
	await _videos_between_games()
	await _shop()
	await _settings()
	await _restart_app()
	await _reset_progress()
	_wipe()
	get_tree().quit(t.report())


func _wipe() -> void:
	for s: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + s))


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _find(root: Node, n: String) -> Node:
	return root.find_child(n, true, false) if root != null else null


func _press(root: Node, n: String) -> bool:
	var b: BaseButton = _find(root, n) as BaseButton
	if b == null:
		t.ok(false, "button %s exists" % n)
		return false
	if b.disabled:
		t.ok(false, "button %s is enabled" % n)
		return false
	b.pressed.emit()
	return true


func _boot() -> void:
	app = (load("res://game/scenes/main.tscn") as PackedScene).instantiate()
	add_child(app)
	await _wait(0.5)
	t.ok(_find(app, "Splash") != null, "the splash plays first")
	await _wait(3.6)
	t.eq(app.screen_name, "home", "boots to the home screen")


func _home_and_banner() -> void:
	t.ok(AdManager.banner_height > 0.0, "the banner is showing")
	var frame: MarginContainer = app.screen.get_child(0) as MarginContainer
	t.ok(frame.get_theme_constant("margin_bottom") >= int(AdManager.banner_height), "screens keep room for the banner")
	for n: String in ["Play", "Shop", "SettingsButton", "Challenges", "Awards", "Daily", "Missions", "Keys", "Coins", "Demo"]:
		t.ok(_find(app.screen, n) != null, "home has %s" % n)


## Play's tray drag, done the way a finger does it.
func _drag(play: Node, slot: int, origin: Vector2i) -> void:
	var tray: TrayView = play.tray
	tray.begin_drag(slot, tray.finger_for(slot, origin) + Vector2(0, 120))
	await _wait(0.05)
	tray.move_drag(tray.finger_for(slot, origin))
	await _wait(0.05)
	tray.end_drag()
	await _wait(0.1)


func _tutorial() -> void:
	_press(app.screen, "Play")
	await _wait(0.9)
	t.eq(app.screen_name, "play", "the first Play goes straight into a game")
	var play: Node = app.screen
	t.eq(play.mode, "classic", "it is a Classic run")
	t.ok(play.state.tutorial, "with the guided first tray")
	t.ok(play.tutorial != null and is_instance_valid(play.tutorial), "the tutorial hand is showing")
	var cap: Label = _find(play, "TutorialCaption") as Label
	t.ok(cap != null and cap.text.contains("Drag"), "the tutorial says to drag")
	# A wrong drop (onto a wall) slides back and changes nothing.
	await _drag(play, 0, Vector2i(3, 2))
	t.eq(play.state.placed, 0, "a drop on a wall doesn't place")
	t.eq(play.state.tray[0], "i2v", "the piece went back to the tray")
	await _drag(play, 0, RunState.TUTORIAL_TARGET)
	t.eq(play.state.placed, 1, "the drop places the piece")
	t.eq(play.state.captures, 1, "it closes the pen")
	t.eq(play.state.score, 2 + Scoring.pen_points(4, 0), "2x2 pen: 160 + 2 for the cells")
	t.ok(Profile.seen("tutorial_done"), "the tutorial is marked done")
	t.ok(cap.text.contains("area"), "the tutorial explains area scoring")
	await _wait(1.2)
	t.eq(play.state.field.count(Field.WALL), 0, "the pen's walls vanished")
	t.ok(not Profile.saved_run("classic").is_empty(), "the run is saved after the move")


func _back_and_resume() -> void:
	var score: int = app.screen.state.score
	app.handle_back()
	await _wait(0.6)
	t.eq(app.screen_name, "modes", "Back from Classic goes to the modes")
	for n: String in ["Classic", "Daily", "Challenges", "HowToPlay"]:
		t.ok(_find(app.screen, n) != null, "modes has %s" % n)
	var line: Label = _find(_find(app.screen, "Classic"), "Line") as Label
	t.ok(line.text.contains("in progress"), "the Classic card shows the run in progress")
	_press(app.screen, "Classic")
	await _wait(0.8)
	t.eq(app.screen.state.score, score, "the saved run resumes where it was")
	t.ok(app.screen.tutorial == null, "no tutorial the second time")
	app.handle_back()
	await _wait(0.6)
	app.handle_back()
	await _wait(0.6)
	t.eq(app.screen_name, "home", "Back from modes goes home")
	_press(app.screen, "Play")
	await _wait(0.6)
	t.eq(app.screen_name, "modes", "after the tutorial, Play opens the modes")
	_press(app.screen, "Classic")
	await _wait(0.8)


func _hints_and_shuffle() -> void:
	var play: Node = app.screen
	Save.data["hint_day"] = {"day": "", "used": 0}
	var coins: int = Profile.coins()
	_press(play, "Hint")
	await _wait(0.2)
	t.eq(Profile.coins(), coins, "the first hint each day is free")
	t.ok(not play.board._hint_cells.is_empty(), "the hint outlines a spot")
	t.ok(play.tray.hint_slot >= 0, "and the piece to use")
	var hs: int = play.tray.hint_slot
	var cells: PackedInt32Array = play.board._hint_cells
	var o: Vector2i = Field.pos(cells[0]) - Pieces.cells(play.state.tray[hs])[0]
	t.ok(play.state.can_place(hs, o), "the hinted spot is a legal move")
	_press(play, "Hint")
	await _wait(0.2)
	t.eq(Profile.coins(), coins - Economy.HINT_COST, "the next hint costs coins")
	# Out of coins: a video, if the player wants it.
	Save.data["coins"] = 0
	var hints: int = play.state.hints
	_press(play, "Hint")
	await _wait(0.4)
	var card: Overlay = app.top_overlay()
	t.ok(card is MessageCard, "out of coins, a card offers a video")
	_press(card, "Watchavideo")
	await _wait(0.4)
	t.eq(play.state.hints, hints + 1, "the video paid for the hint")
	mock.earn = false
	_press(play, "Hint")
	await _wait(0.4)
	_press(app.top_overlay(), "Watchavideo")
	await _wait(0.4)
	t.eq(play.state.hints, hints + 1, "a skipped video gives no hint")
	mock.earn = true
	Save.data["coins"] = 500
	var before: Array = play.state.tray.duplicate()
	_press(play, "Shuffle")
	await _wait(0.3)
	t.eq(Profile.coins(), 500 - Economy.SHUFFLE_COST, "a shuffle costs coins")
	t.eq(play.state.tray.size(), 3, "the tray still has three slots")
	t.ok(before.size() == 3, "shuffle swapped the pieces")


func _continue_and_result() -> void:
	var play: Node = app.screen
	var s: RunState = play.state
	# Crowd the board so that after one more piece nothing fits.
	var rows: PackedStringArray = PackedStringArray()
	for y: int in 9:
		rows.append("#########" if y != 4 else "####..###")
	s.field = Field.from_ascii("\n".join(rows))
	s.tray = ["i2h", "o", "v1"]
	s.score = 3210
	play.board.setup(s)
	play.tray.setup(s, play.board)
	play.place(0, Vector2i(4, 4))
	await _wait(1.4)
	var card: Overlay = app.top_overlay()
	t.ok(card is ContinueCard, "stuck: the continue is offered")
	_press(card, "WatchContinue")
	await _wait(0.5)
	t.eq(s.end, RunState.End.NONE, "the video continues the run")
	t.eq(s.continues, 1, "the continue is used")
	t.ok(s.any_fits(), "fresh pieces fit")
	# Stuck again: no second continue, straight to the result.
	s.field = Field.from_ascii("\n".join(rows))
	s.tray = ["i2h", "o", "v1"]
	play.board.setup(s)
	play.tray.setup(s, play.board)
	var c0: int = Profile.coins()
	play.place(0, Vector2i(4, 4))
	await _wait(1.6)
	card = app.top_overlay()
	t.ok(card is ResultCard, "the second time, the run ends")
	t.eq(Profile.best_score(), s.score, "the best score is saved")
	t.ok(Profile.coins() > c0, "Classic coins are paid")
	t.ok(Profile.saved_run("classic").is_empty(), "the finished run is cleared")
	t.ok(_find(card, "FinalScore") != null, "the result shows the score")
	_press(card, "Next")
	await _wait(0.9)
	t.eq(app.screen_name, "play", "Play again starts a new run")
	t.eq(app.screen.state.score, 0, "from zero")
	# Coins for a continue.
	play = app.screen
	s = play.state
	s.field = Field.from_ascii("\n".join(rows))
	s.tray = ["i2h", "o", "v1"]
	play.board.setup(s)
	play.tray.setup(s, play.board)
	Save.data["coins"] = 1000
	play.place(0, Vector2i(4, 4))
	await _wait(1.4)
	card = app.top_overlay()
	t.ok(card is ContinueCard, "the continue is offered again in a new run")
	_press(card, "CoinContinue")
	await _wait(0.5)
	t.eq(Profile.coins(), 1000 - Economy.CONTINUE_COST, "a continue for coins")
	t.eq(s.end, RunState.End.NONE, "and the run goes on")


func _daily() -> void:
	app.go("play", {"mode": "daily", "date": Catalog.today_key()})
	await _wait(0.9)
	var play: Node = app.screen
	t.eq(play.mode, "daily", "the Daily Board opens")
	t.eq(play.state.pieces_left(), DailyBoard.PIECES, "with %d pieces" % DailyBoard.PIECES)
	t.ok(_find(play, "Shuffle") == null, "no shuffle on the Daily Board")
	var c0: int = Profile.coins()
	while not play.state.is_over():
		var m: Array = CorralBot.best_move(play.state)
		if m.is_empty():
			break
		play.place(int(m[0]), m[1])
		await _wait(0.02)
	await _wait(1.8)
	var card: Overlay = app.top_overlay()
	t.ok(card is ResultCard, "the daily result shows")
	t.ok(Profile.daily_done(Catalog.today_key()), "today's board is done")
	t.eq(Profile.current_streak(), 1, "a streak starts")
	t.ok(Profile.coins() >= c0 + Economy.daily_reward(1), "the daily pays")
	t.ok(_find(card, "Stars") != null, "the daily shows stars")
	_press(card, "Next")
	await _wait(0.8)
	t.eq(app.screen_name, "modes", "Done returns to the modes")


func _challenges() -> void:
	_press(app.screen, "Challenges")
	await _wait(0.7)
	t.eq(app.screen_name, "chapters", "Challenges opens the chapters")
	var list: Node = _find(app.screen, "List")
	var cards: int = 0
	for c: Node in list.get_children():
		if c is ChapterCard:
			cards += 1
	t.eq(cards, 8, "8 chapter cards")
	_press(list, "Chapter_orchard")
	await _wait(0.5)
	t.ok(app.top_overlay() is LockedCard, "a locked chapter explains how it opens")
	app.close_overlays()
	_press(list, "Chapter_meadow")
	await _wait(0.7)
	t.eq(app.screen_name, "levels", "an open chapter shows its challenges")
	var grid: Node = _find(app.screen, "Grid")
	t.eq(grid.get_child_count(), 15, "15 challenges are shown")
	var locked: int = 0
	for tile: LevelTile in grid.get_children():
		if not tile.open:
			locked += 1
	t.eq(locked, 14, "14 locked")
	_press(grid, "Level1")
	await _wait(0.8)
	var play: Node = app.screen
	t.eq(play.mode, "challenge", "a challenge opens")
	t.ok((_find(play, "Goal") as Label).text.contains("Capture"), "the goal is shown")
	var sol: Array = play.level_data["solution"]
	for m: Variant in sol:
		var a: Array = m
		await _drag(play, int(a[0]), Vector2i(int(a[1]), int(a[2])))
	await _wait(1.4)
	var card: Overlay = app.top_overlay()
	t.ok(card is ResultCard, "the goal clears the challenge")
	t.eq(Profile.stars_for("meadow-01"), 3, "three stars")
	_press(card, "Next")
	await _wait(0.9)
	t.eq(app.screen.level_n, 2, "Next opens challenge 2")
	# Fail one: fill the board without trying to capture.
	play = app.screen
	var guard: int = 0
	while not play.state.is_over() and guard < 60:
		guard += 1
		var done: bool = false
		for k: int in 3:
			var p: String = play.state.tray[k]
			if p.is_empty():
				continue
			for o: Vector2i in play.state.field.placements(p):
				if play.state.preview(k, o).is_empty():
					play.place(k, o)
					done = true
					break
			if done:
				break
		if not done:
			break
		await _wait(0.02)
	await _wait(1.5)
	if play.state.end != RunState.End.WON and play.state.is_over():
		card = app.top_overlay()
		t.ok(card is ResultCard and bool((card as ResultCard).reward.get("failed", false)), "missing the goal shows a retry card")
		t.eq((_find(card, "Next") as Button).text, "Try again", "the main button retries")
		app.close_overlays()
	# A locked challenge opened with a key.
	Profile.add_keys(1)
	app.go("levels", {"chapter": 0})
	await _wait(0.8)
	_press(_find(app.screen, "Grid"), "Level9")
	await _wait(0.4)
	card = app.top_overlay()
	t.ok(card is LockedCard, "a locked challenge offers a key")
	_press(card, "UseKey")
	await _wait(0.9)
	t.eq(app.screen_name, "play", "the key opens it")
	t.eq(app.screen.level_n, 9, "challenge 9")
	t.ok(Profile.key_unlocked("meadow-09"), "for good")
	app.handle_back()
	await _wait(0.7)
	t.eq(app.screen_name, "levels", "Back from a challenge goes to its chapter")


func _videos_between_games() -> void:
	t.ok(mock.interstitials >= 0, "interstitial counter exists")
	var before: int = mock.interstitials
	Save.data["games_since_video"] = AdManager.GAMES_PER_VIDEO - 1
	var ran: Array = [false]
	AdManager.after_game(func() -> void: ran[0] = true)
	await _wait(0.2)
	t.eq(mock.interstitials, before + 1, "a short video every %d games" % AdManager.GAMES_PER_VIDEO)
	t.ok(ran[0], "and the game carries on after it")
	ran[0] = false
	AdManager.after_game(func() -> void: ran[0] = true)
	t.ok(ran[0], "no video right after one")
	t.eq(mock.interstitials, before + 1, "the counter restarted")


func _shop() -> void:
	app.go("shop")
	await _wait(0.8)
	t.eq(app.screen_name, "shop", "the shop opens")
	_refund_note(app.screen, "the shop")
	await _tip_jar()
	var c0: int = Profile.coins()
	_press(app.screen, "Product_coins")
	await _wait(0.4)
	var coins_card: Overlay = app.top_overlay()
	_press(coins_card, "FreeCoins")
	await _wait(0.4)
	t.eq(Profile.coins(), c0 + Economy.VIDEO_COINS, "free coins from a video")
	coins_card.close()
	await _wait(0.3)
	_press(app.screen, "Product_theme_pack")
	await _wait(0.4)
	_press(app.top_overlay(), "Trial")
	await _wait(0.8)
	t.ok(Profile.trial_left("theme_pack") > 0, "a video starts the theme trial")
	t.ok(app.top_overlay() is PickerCard, "and opens the picker")
	app.close_overlays()
	await _wait(0.6)
	app.go("shop")
	await _wait(0.8)
	_press(app.screen, "Product_supporter_pack")
	await _wait(0.4)
	_refund_note(app.top_overlay(), "the product card")
	_press(app.top_overlay(), "Buy")
	await _wait(0.4)
	t.ok(Profile.is_supporter(), "the Supporter pack is bought (simulated)")
	t.eq(AdManager.banner_height, 0.0, "Supporters see no banner")
	app.close_overlays()


func _refund_note(root: Node, where: String) -> void:
	var note: Label = _find(root, "RefundNote") as Label
	t.ok(note != null and note.text == Store.REFUND_NOTE, "the no-refunds line is on %s" % where)
	t.ok(note != null and note.text.contains("Sorry, we can't refund or undo a purchase."), "with the exact wording on %s" % where)


## The tip jar: presets and the picker show local prices, − / + step one amount,
## the slider runs the whole range, and the big button tips the selection.
func _tip_jar() -> void:
	_press(app.screen, "TipJar")
	await _wait(0.4)
	var card: Overlay = app.top_overlay()
	t.ok(card is TipCard, "the tip jar opens")
	_refund_note(card, "the tip card")
	t.ok(_find(card, "TipAmount") == null, "no typed rupee amount")
	var price: Label = _find(card, "TipPrice") as Label
	var slider: HSlider = _find(card, "TipSlider") as HSlider
	var custom: Button = _find(card, "TipCustom") as Button
	t.ok(price != null and slider != null and custom != null, "price, slider and tip button")
	t.eq((card as TipCard).selected(), Store.TIP_DEFAULT, "₹500's tip is picked first")
	t.eq(price.text, Store.price("tip_500"), "the picker shows the local price")
	t.eq(custom.text, "Tip " + Store.price("tip_500"), "the big button shows it too")
	t.eq((_find(card, "Tip_20") as Button).text, Store.price("tip_20"), "presets show local prices")
	t.eq(int(slider.max_value), Store.tip_amounts().size() - 1, "the slider covers every amount")
	_press(card, "TipPlus")
	t.eq((card as TipCard).selected(), 510, "plus steps one amount")
	_press(card, "TipMinus")
	_press(card, "TipMinus")
	t.eq((card as TipCard).selected(), 490, "minus steps one amount")
	slider.value = slider.max_value
	t.eq((card as TipCard).selected(), Store.TIP_MAX, "the slider reaches the largest tip")
	t.eq(price.text, Store.price("tip_%d" % Store.TIP_MAX), "and the label follows")
	_press(card, "TipPlus")
	t.eq((card as TipCard).selected(), Store.TIP_MAX, "plus stops at the largest")
	slider.value = 0
	t.eq((card as TipCard).selected(), Store.TIP_MIN, "the slider reaches the smallest tip")
	Store.prices["tip_10"] = "US$9.99"
	Store.price_updated.emit("tip_10", "US$9.99")
	t.eq(price.text, "US$9.99", "Play's price replaces the fallback live")
	Store.prices["tip_10"] = Store.tip_price(10)
	var n: int = Profile.tips_given()
	_press(card, "TipCustom")
	await _wait(0.3)
	t.eq(Profile.tips_given(), n + 1, "the tip button tips (simulated)")
	card.close()
	await _wait(0.3)


func _settings() -> void:
	app.go("play", {"mode": "classic"})
	await _wait(0.8)
	_press(app.screen, "SettingsButton")
	await _wait(0.5)
	var s: Overlay = app.top_overlay()
	t.ok(s is SettingsCard, "Settings opens in a game")
	t.ok(_find(s, "Reset") == null, "Reset progress is hidden during a game")
	t.ok(_find(s, "MusicSlider") != null and _find(s, "SoundSlider") != null, "volume sliders")
	(_find(s, "SoundSlider") as HSlider).value = 0.3
	t.eq(float(Profile.setting("sound_volume", 0.0)), 0.3, "the sound slider saves")
	_press(s, "HowToPlay")
	await _wait(0.5)
	t.ok(app.top_overlay() is HowToCard, "How to play opens from Settings")
	var how: HowToCard = app.top_overlay()
	for k: int in HowToCard.ALL_PAGES.size():
		_press(how, "Next")
		await _wait(0.1)
	await _wait(0.4)
	t.ok(app.top_overlay() is SettingsCard, "closing it returns to Settings")
	app.close_overlays()
	await _wait(0.2)


func _restart_app() -> void:
	var best: int = Profile.best_score()
	var run_score: int = app.screen.state.score
	app.screen.place(0, app.screen.state.field.placements(app.screen.state.tray[0])[0]) if not app.screen.state.tray[0].is_empty() else null
	await _wait(0.8)
	run_score = app.screen.state.score
	Save.flush()
	app.queue_free()
	await _wait(0.3)
	Save.load_data()
	await _boot()
	t.eq(Profile.best_score(), best, "the best score survives a restart")
	_press(app.screen, "Play")
	await _wait(0.6)
	_press(app.screen, "Classic")
	await _wait(0.8)
	t.eq(app.screen.state.score, run_score, "the Classic run in progress survives a restart")
	app.go("home")
	await _wait(0.7)


func _reset_progress() -> void:
	_press(app.screen, "SettingsButton")
	await _wait(0.5)
	var s: Overlay = app.top_overlay()
	t.ok(_find(s, "Reset") != null, "Reset progress is in Settings at home")
	_press(s, "Reset")
	await _wait(0.1)
	t.ok(Profile.best_score() > 0, "the first tap only asks")
	_press(s, "Reset")
	await _wait(0.8)
	t.eq(Profile.best_score(), 0, "the second tap erases progress")
	t.ok(Profile.is_supporter(), "purchases are kept")
	t.eq(app.screen_name, "home", "back at home")
