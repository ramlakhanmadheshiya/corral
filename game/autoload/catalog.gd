extends Node
## Read-only game content: the challenge chapters and their levels (data/), and
## the Daily Board, built from the date. Missing or broken files are reported
## through `last_error`.

var chapters: Array[Dictionary] = []
var levels_per_chapter: int = 15
var unlock_clears: int = 10
var last_error: String = ""

var _level_cache: Dictionary = {}
var _daily_cache: Dictionary = {}
## Today's Daily Board is built on a worker thread at start-up (the bot plays it
## once to set the star scores), so opening it later doesn't stall.
var _daily_task: int = -1
var _daily_task_key: String = ""
var _daily_result: Dictionary = {}


func _ready() -> void:
	_load_meta()
	_warm_daily.call_deferred()


func _warm_daily() -> void:
	# Tests stay single-threaded; the web build has no threads.
	if DisplayServer.get_name() == "headless" or OS.has_feature("web") or _daily_task >= 0:
		return
	# Fill the shared lookup tables here first, so the worker only reads them.
	Field.new()
	for id: String in Pieces.ids():
		Pieces.cells(id)
	_daily_task_key = today_key()
	var key: String = _daily_task_key
	_daily_task = WorkerThreadPool.add_task(func() -> void: _daily_result = DailyBoard.build(key), false, "Daily Board")


func _finish_warm_daily() -> void:
	if _daily_task < 0:
		return
	WorkerThreadPool.wait_for_task_completion(_daily_task)
	_daily_task = -1
	if not _daily_result.is_empty():
		_daily_cache[_daily_task_key] = _daily_result


func _exit_tree() -> void:
	_finish_warm_daily()


## Drops cached content and reads it again (used by the error card's Retry).
func reload() -> void:
	chapters.clear()
	_level_cache.clear()
	_daily_cache.clear()
	last_error = ""
	_load_meta()


func _load_meta() -> void:
	var catalog: Variant = _json("res://data/chapters.json")
	if catalog is Dictionary:
		levels_per_chapter = int(catalog.get("levels_per_chapter", 15))
		unlock_clears = int(catalog.get("unlock_clears", 10))
		for c: Variant in catalog.get("chapters", []):
			var d: Dictionary = (c as Dictionary).duplicate(true)
			d["accent"] = Color(str(d.get("accent", "#FF7A6B")))
			chapters.append(d)


func _json(p: String) -> Variant:
	if not FileAccess.file_exists(p):
		last_error = "Missing game data: %s" % p.get_file()
		return null
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	if v == null:
		last_error = "Damaged game data: %s" % p.get_file()
	return v


func chapter_count() -> int:
	return chapters.size()


func chapter(index: int) -> Dictionary:
	return chapters[index] if index >= 0 and index < chapters.size() else {}


func chapter_index(id: String) -> int:
	for i: int in chapters.size():
		if chapters[i]["id"] == id:
			return i
	return -1


func total_levels() -> int:
	return chapters.size() * levels_per_chapter


static func level_id(chapter_id: String, n: int) -> String:
	return "%s-%02d" % [chapter_id, n]


## Splits "quarry-07" into [chapter index, 7]; [-1, 0] if unknown.
func parse_level_id(id: String) -> Array[int]:
	var dash: int = id.rfind("-")
	if dash <= 0:
		return [-1, 0]
	return [chapter_index(id.substr(0, dash)), int(id.substr(dash + 1))]


func _levels(chapter_id: String) -> Array:
	if not _level_cache.has(chapter_id):
		var v: Variant = _json("res://data/levels/%s.json" % chapter_id)
		_level_cache[chapter_id] = v.get("levels", []) if v is Dictionary else []
	return _level_cache[chapter_id]


## The data for challenge n (1-based) of a chapter, or {} if it cannot be loaded.
func level(chapter_idx: int, n: int) -> Dictionary:
	var c: Dictionary = chapter(chapter_idx)
	if c.is_empty():
		last_error = "Unknown chapter"
		return {}
	var levels: Array = _levels(c["id"])
	if n < 1 or n > levels.size():
		if last_error.is_empty():
			last_error = "Challenge %d of %s is missing" % [n, c["name"]]
		return {}
	return levels[n - 1]


## A short sentence for a goal, e.g. "Capture a pen of 9+ cells".
static func goal_text(goal: Dictionary) -> String:
	var n: int = int(goal.get("target", 0))
	match str(goal.get("type", "")):
		"score":
			return "Score %s points" % Catalog.thousands(n)
		"pen":
			return "Capture a pen of %d+ cells" % n
		"captures":
			return "Capture %d pens" % n
		"gems":
			return "Capture %d %s" % [n, "gem" if n == 1 else "gems"]
		"combo":
			return "Close two pens with one piece" if n == 1 else "Close two pens at once, %d times" % n
	return ""


## Icon (assets/art) for a goal type.
static func goal_icon(goal: Dictionary) -> String:
	return {"score": "trophy", "pen": "pen", "captures": "corral", "gems": "gem", "combo": "spark"}.get(str(goal.get("type", "")), "star")


static func thousands(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


static func day_number(date_key: String) -> int:
	return DailyBoard.day_number(date_key)


static func date_key_from_day(day: int) -> String:
	return DailyBoard.date_key_from_day(day)


static func today_key() -> String:
	return Time.get_date_string_from_system()


## The Daily Board for a date (built once, then cached).
func daily(date_key: String) -> Dictionary:
	if date_key == _daily_task_key:
		_finish_warm_daily()
	if not _daily_cache.has(date_key):
		_daily_cache[date_key] = DailyBoard.build(date_key)
	return _daily_cache[date_key]
