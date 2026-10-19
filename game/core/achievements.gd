class_name Achievements
extends RefCounted
## Achievement definitions. Each unlocks once when `stat` reaches `goal` and pays
## its reward exactly once (see Profile.check_achievements). Every chapter also
## has its own "chapter complete" achievement, built from the catalogue.

const BASE: Array[Dictionary] = [
	{"id": "first_pen", "title": "First Pen", "desc": "Capture your first pen", "stat": "pens", "goal": 1, "reward": 20, "icon": "corral"},
	{"id": "pens_50", "title": "Shepherd", "desc": "Capture 50 pens", "stat": "pens", "goal": 50, "reward": 50, "icon": "corral"},
	{"id": "pens_250", "title": "Rancher", "desc": "Capture 250 pens", "stat": "pens", "goal": 250, "reward": 150, "icon": "corral"},
	{"id": "pens_1000", "title": "Land Baron", "desc": "Capture 1,000 pens", "stat": "pens", "goal": 1000, "reward": 400, "icon": "corral"},
	{"id": "pen_9", "title": "Roomy", "desc": "Capture a pen of 9 cells or more", "stat": "biggest", "goal": 9, "reward": 30, "icon": "pen"},
	{"id": "pen_16", "title": "Ranch", "desc": "Capture a pen of 16 cells or more", "stat": "biggest", "goal": 16, "reward": 80, "icon": "pen"},
	{"id": "pen_25", "title": "Prairie", "desc": "Capture a pen of 25 cells or more", "stat": "biggest", "goal": 25, "reward": 200, "icon": "pen"},
	{"id": "gems_10", "title": "Glimmer", "desc": "Capture 10 gems", "stat": "gems", "goal": 10, "reward": 40, "icon": "gem"},
	{"id": "gems_50", "title": "Treasure Pen", "desc": "Capture 50 gems", "stat": "gems", "goal": 50, "reward": 120, "icon": "gem"},
	{"id": "gems_200", "title": "Gem Keeper", "desc": "Capture 200 gems", "stat": "gems", "goal": 200, "reward": 300, "icon": "gem"},
	{"id": "combo_1", "title": "Double Up", "desc": "Close two pens with one piece", "stat": "combos", "goal": 1, "reward": 30, "icon": "spark"},
	{"id": "combo_25", "title": "Two Birds", "desc": "Close two or more pens at once 25 times", "stat": "combos", "goal": 25, "reward": 150, "icon": "spark"},
	{"id": "score_1k", "title": "Getting Going", "desc": "Score 1,000 in a Classic run", "stat": "best_score", "goal": 1000, "reward": 20, "icon": "trophy"},
	{"id": "score_5k", "title": "High Fences", "desc": "Score 5,000 in a Classic run", "stat": "best_score", "goal": 5000, "reward": 60, "icon": "trophy"},
	{"id": "score_20k", "title": "Big Country", "desc": "Score 20,000 in a Classic run", "stat": "best_score", "goal": 20000, "reward": 150, "icon": "trophy"},
	{"id": "score_50k", "title": "Open Range", "desc": "Score 50,000 in a Classic run", "stat": "best_score", "goal": 50000, "reward": 400, "icon": "trophy"},
	{"id": "runs_10", "title": "Regular", "desc": "Finish 10 Classic runs", "stat": "runs", "goal": 10, "reward": 40, "icon": "play"},
	{"id": "pieces_1000", "title": "Fence Builder", "desc": "Place 1,000 wall pieces", "stat": "pieces", "goal": 1000, "reward": 100, "icon": "wall"},
	{"id": "levels_1", "title": "Challenger", "desc": "Clear your first challenge", "stat": "levels", "goal": 1, "reward": 20, "icon": "star"},
	{"id": "levels_30", "title": "Trailblazer", "desc": "Clear 30 challenges", "stat": "levels", "goal": 30, "reward": 100, "icon": "star"},
	{"id": "levels_120", "title": "Every Challenge", "desc": "Clear all 120 challenges", "stat": "levels", "goal": 120, "reward": 600, "icon": "trophy"},
	{"id": "stars_100", "title": "Starry Fields", "desc": "Earn 100 stars", "stat": "stars", "goal": 100, "reward": 100, "icon": "star"},
	{"id": "stars_360", "title": "Every Star", "desc": "Earn all 360 stars", "stat": "stars", "goal": 360, "reward": 800, "icon": "star"},
	{"id": "perfect_10", "title": "Tidy Builder", "desc": "Clear 10 challenges with three stars", "stat": "perfect", "goal": 10, "reward": 60, "icon": "star"},
	{"id": "daily_1", "title": "Morning Round", "desc": "Finish a Daily Board", "stat": "dailies", "goal": 1, "reward": 20, "icon": "calendar"},
	# Daily streaks count days in a row: missing a day starts the count again.
	{"id": "streak_3", "title": "Three Days", "desc": "Play the Daily Board 3 days in a row", "stat": "best_streak", "goal": 3, "reward": 40, "icon": "flame"},
	{"id": "streak_7", "title": "A Week of Pens", "desc": "Play the Daily Board 7 days in a row", "stat": "best_streak", "goal": 7, "reward": 100, "icon": "flame"},
	{"id": "streak_14", "title": "Two Weeks Steady", "desc": "Play the Daily Board 14 days in a row", "stat": "best_streak", "goal": 14, "reward": 250, "icon": "flame"},
	{"id": "streak_30", "title": "A Month of Mornings", "desc": "Play the Daily Board 30 days in a row", "stat": "best_streak", "goal": 30, "reward": 600, "icon": "flame"},
	{"id": "missions_10", "title": "Errand Runner", "desc": "Complete 10 daily missions", "stat": "missions", "goal": 10, "reward": 60, "icon": "check"},
	{"id": "missions_50", "title": "Foreman", "desc": "Complete 50 daily missions", "stat": "missions", "goal": 50, "reward": 200, "icon": "check"},
]

const CHAPTER_REWARD: int = 50


## Base achievements plus one per chapter ("Meadow complete").
static func all() -> Array[Dictionary]:
	var out: Array[Dictionary] = BASE.duplicate()
	for i: int in Catalog.chapter_count():
		var ch: Dictionary = Catalog.chapter(i)
		out.append({
			"id": "chapter_" + str(ch["id"]), "title": "%s complete" % ch["name"],
			"desc": "Clear all %d challenges of chapter %d" % [Catalog.levels_per_chapter, i + 1],
			"stat": "ch_" + str(ch["id"]), "goal": 1, "reward": CHAPTER_REWARD, "icon": "trophy",
		})
	return out


static func by_id(id: String) -> Dictionary:
	for a: Dictionary in all():
		if a["id"] == id:
			return a
	return {}
