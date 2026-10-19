extends Node
## Screenshots of every screen and card at a given window size, for visual
## review and the store. Runs the real app with a throwaway save and the mock ad
## banner. Needs a display (not --headless):
##
##   godot --path . res://tests/capture.tscn -- <out_dir> [width] [height] [clean] [dark|light]
##
## "clean" hides the test ad banner (for store and website screenshots).

const SAVE: String = "user://capture_save.json"

var out_dir: String = "/tmp/corral_shots"
var app: App
var _n: int = 0


func _ready() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() >= 1:
		out_dir = a[0]
	var win: Vector2i = Vector2i(450, 800)
	if a.size() >= 3:
		win = Vector2i(int(a[1]), int(a[2]))
	DisplayServer.window_set_size(win)
	DirAccess.make_dir_recursive_absolute(out_dir)
	for s: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + s))
	Save.path = SAVE
	Save.load_data()
	Profile.set_setting("music_volume", 0.0)
	Profile.set_setting("sound_volume", 0.0)
	Store.simulate = true
	Profile.set_setting("appearance", "dark" if a.has("dark") else "light")
	if a.has("clean"):
		AdManager.use_provider(null)
	_seed_progress()
	app = (load("res://game/scenes/main.tscn") as PackedScene).instantiate()
	add_child(app)
	await _wait(3.4)
	await _shot("home")
	app.go("modes")
	await _wait(0.9)
	await _shot("modes")
	# A Classic run in full swing, mid-capture.
	app.go("play", {"mode": "classic"})
	await _wait(0.8)
	var play: Node = app.screen
	_set_board(play, CLASSIC_BOARD, ["u3", "i3h", "c2"], 2140)
	await _wait(0.4)
	# Drag a piece over the gap so the capture preview shows.
	play.tray.begin_drag(1, play.tray.finger_for(1, Vector2i(1, 7)))
	await _wait(0.5)
	await _shot("play_preview")
	play.tray.end_drag()
	await _wait(0.45)
	await _shot("play_capture")
	await _wait(1.6)
	await _shot("play_after")
	# Classic game over -> continue offer -> result.
	_set_board(play, FULL_BOARD, ["o", "v1", "u2"], 8460)
	play.state._check_end()
	play._finish()
	await _wait(0.8)
	await _shot("continue")
	(app.top_overlay() as Overlay).close()
	# The run's painting for the share picture: the pens it captured.
	var paint: PackedStringArray = PAINTING.strip_edges().split("\n")
	for y: int in 9:
		for x: int in 9:
			var ch: String = paint[y][x]
			play.state.stain[y * 9 + x] = int(ch) if ch != "." else 0
	play.finish_run()
	await _wait(2.6)
	await _shot("result_classic")
	var result: Overlay = app.top_overlay()
	result.open_child(result._share_card())
	await _wait(2.0)
	await _shot("share")
	app.close_overlays()
	await _wait(0.3)
	# The Daily Board, part played.
	app.go("play", {"mode": "daily", "date": Catalog.today_key()})
	await _wait(0.9)
	play = app.screen
	for k: int in 9:
		var m: Array = CorralBot.best_move(play.state)
		if m.is_empty():
			break
		play.place(int(m[0]), m[1])
		await _wait(0.12)
	await _wait(1.6)
	await _shot("daily")
	# Challenges.
	app.go("chapters")
	await _wait(0.9)
	await _shot("chapters")
	app.go("levels", {"chapter": 2})
	await _wait(0.9)
	await _shot("levels")
	app.go("play", {"chapter": 2, "level": 9})
	await _wait(0.9)
	play = app.screen
	var sol: Array = Catalog.level(2, 9)["solution"]
	for k: int in sol.size() - 1:
		play.place(int(sol[k][0]), Vector2i(int(sol[k][1]), int(sol[k][2])))
		await _wait(0.1)
	await _wait(1.4)
	play.use_hint()
	await _wait(0.6)
	await _shot("challenge")
	var last: Array = sol[sol.size() - 1]
	board_clear_hint(play)
	play.place(int(last[0]), Vector2i(int(last[1]), int(last[2])))
	await _wait(3.6)
	await _shot("result_challenge")
	app.close_overlays()
	await _wait(0.3)
	app.go("shop")
	await _wait(1.0)
	await _shot("shop")
	for o: Overlay in [_product("complete_pack"), _product("style_pack"), CoinsCard.new(), KeysCard.new(), TipCard.new(), _picker("themes"), _picker("styles"), SettingsCard.new(), AchievementsCard.new(), MissionsCard.new(), HowToCard.new(), AboutCard.new(), CreditsCard.new(), _locked(3, 4)]:
		app.open(o)
		await _wait(0.8)
		await _shot(o.name.to_lower() + ("_" + str(o.get("mode")) if o is PickerCard else ("_" + str(o.get("product")) if o is ProductCard else "")))
		o.close()
		await _wait(0.35)
	# The first-play tutorial.
	Save.data["seen"].erase("tutorial_done")
	Profile.clear_run("classic")
	app.go("play", {"mode": "classic"})
	await _wait(1.0)
	await _wait(0.9)
	await _shot("tutorial")
	# Bought looks: a dark theme and a pen style.
	Save.data["owned"]["theme_pack"] = true
	Save.data["owned"]["style_pack"] = true
	Profile.mark_seen("tutorial_done")
	Profile.clear_run("classic")
	Profile.set_setting("theme", "night")
	Profile.set_setting("style", "candy")
	app.go("play", {"mode": "classic"})
	await _wait(0.8)
	play = app.screen
	_set_board(play, CLASSIC_BOARD, ["u3", "i3h", "c2"], 2140)
	play.place(1, Vector2i(1, 7))
	await _wait(0.5)
	await _shot("play_themed")
	app.go("home")
	await _wait(1.2)
	await _shot("home_themed")
	Profile.set_setting("theme", "original")
	Profile.set_setting("style", "classic")
	for s: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + s))
	print("CAPTURE: %d screenshots in %s" % [_n, out_dir])
	get_tree().quit()


const CLASSIC_BOARD: String = """
..##.....
.#..#..R.
.#..#....
..#...*..
.###.....
#*..#....
#...#..##
.........
.....##..
"""

const PAINTING: String = """
11.222.33
11.222.33
...222...
4455..666
4455..666
.....1666
22.3311..
22.3311.4
.....11.4
"""

const FULL_BOARD: String = """
##.##.###
#.##.##.#
.##.##.##
##R##.##.
#.##.##.#
.##.##.##
##.##R##.
#.##.##.#
.##.##.##
"""


func _set_board(play: Node, rows: String, tray: Array, score: int) -> void:
	var s: RunState = play.state
	s.field = Field.from_ascii(rows)
	for k: int in 3:
		s.tray[k] = str(tray[k])
	s.score = score
	s.captures = 9
	s.biggest = 9
	s.gems_captured = 2
	s.combos = 1
	s.placed = 31
	s.pens_total = 9
	for i: int in [10, 11, 12, 19, 20, 21, 29, 30, 46, 47, 55, 56, 57, 64, 65]:
		s.stain[i] = 1 + i % 5
	play.board.setup(s)
	play.tray.setup(s, play.board)
	play._refresh(true)


func board_clear_hint(play: Node) -> void:
	play.board.clear_hint()
	play.tray.hint_slot = -1


func _locked(ci: int, n: int) -> LockedCard:
	var o: LockedCard = LockedCard.new()
	o.chapter_idx = ci
	o.level = n
	return o


func _product(id: String) -> ProductCard:
	var o: ProductCard = ProductCard.new()
	o.product = id
	return o


func _picker(mode: String) -> PickerCard:
	var o: PickerCard = PickerCard.new()
	o.mode = mode
	return o


## A believable mid-game save: two chapters done with mixed stars, the third
## part way, a best score, a streak, some keys and coins.
func _seed_progress() -> void:
	for ci: int in 3:
		var id: String = Catalog.chapter(ci)["id"]
		var upto: int = 15 if ci < 2 else 8
		for n: int in range(1, upto + 1):
			Save.data["cleared"][Catalog.level_id(id, n)] = {"stars": 3 if n % 4 != 0 else (2 if n % 3 != 0 else 1), "best": 6}
	Save.data["coins"] = 1240
	Save.data["keys"] = 3
	Save.data["classic"]["best"] = 18420
	Save.data["stats"]["levels"] = 38
	Save.data["stats"]["stars"] = Profile.total_stars()
	Save.data["stats"]["pens"] = 412
	Save.data["stats"]["best_score"] = 18420
	Save.data["stats"]["biggest"] = 16
	Save.data["daily"]["streak"] = 4
	Save.data["daily"]["last_date"] = Catalog.date_key_from_day(Catalog.day_number(Catalog.today_key()) - 1)
	Save.data["seen"] = {"tutorial_done": true}
	Save.data["last_level"] = "quarry-09"
	Profile.check_achievements()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	_n += 1
	img.save_png("%s/%02d_%s.png" % [out_dir, _n, name])
