extends Node
## The wallet and progress, with a throwaway save: coins, free hints, Classic
## rewards and best score, challenge stars and rewards (paid once), unlocks and
## keys, the daily streak, missions (paid once, automatically), achievements,
## simulated purchases and trials, the progress reset that keeps purchases,
## runs that survive a restart, and recovery from a corrupt save.
##
##   godot --headless --path . res://tests/profile_test.tscn

const SAVE: String = "user://profile_test_save.json"

var t: Check = Check.new("PROFILE")


func _ready() -> void:
	_wipe()
	Save.path = SAVE
	Save.load_data()
	Store.simulate = true
	_coins_and_hints()
	_classic()
	_challenges()
	_keys()
	_daily()
	_missions()
	_achievements()
	_purchases()
	_runs_and_restart()
	_reset()
	_corrupt()
	_wipe()
	get_tree().quit(t.report())


func _wipe() -> void:
	for s: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + s))


func _coins_and_hints() -> void:
	t.eq(Profile.coins(), Economy.START_COINS, "a new player starts with %d coins" % Economy.START_COINS)
	t.ok(Profile.spend(30), "can spend coins")
	t.eq(Profile.coins(), Economy.START_COINS - 30, "spending takes coins")
	t.ok(not Profile.spend(100000), "can't overspend")
	t.ok(not Profile.spend(-5), "can't spend a negative amount")
	t.eq(Profile.free_hints_left(), Economy.FREE_HINTS, "one free hint a day")
	t.ok(Profile.use_free_hint(), "use the free hint")
	t.eq(Profile.free_hints_left(), 0, "no free hints left")
	t.ok(not Profile.use_free_hint(), "can't use more free hints")
	Save.data["hint_day"]["day"] = "2000-01-01"
	t.eq(Profile.free_hints_left(), Economy.FREE_HINTS, "free hints come back the next day")
	var before: int = Profile.coins()
	for k: int in Economy.VIDEO_COINS_PER_DAY:
		t.ok(Profile.claim_video_coins(), "free coins video %d" % (k + 1))
	t.ok(not Profile.claim_video_coins(), "free coins videos are limited per day")
	t.eq(Profile.coins(), before + Economy.VIDEO_COINS * Economy.VIDEO_COINS_PER_DAY, "videos paid")


func _classic() -> void:
	var s: RunState = RunState.classic(5)
	s.score = 4000
	var c0: int = Profile.coins()
	var r: Dictionary = Profile.finish_classic(s)
	t.ok(bool(r["new_best"]), "the first run is a best")
	t.eq(Profile.best_score(), 4000, "best score saved")
	t.eq(int(r["coins"]), Economy.classic_coins(4000, false), "coins for the score (no bonus on the very first run)")
	t.eq(Profile.coins(), c0 + int(r["coins"]), "Classic coins paid")
	s.score = 2000
	r = Profile.finish_classic(s)
	t.ok(not bool(r["new_best"]), "a lower score isn't a best")
	t.eq(Profile.best_score(), 4000, "best kept")
	s.score = 9000
	r = Profile.finish_classic(s)
	t.ok(bool(r["new_best"]), "a higher score is a new best")
	t.eq(int(r["coins"]), Economy.classic_coins(9000, true), "a new best earns the bonus")
	t.eq(Economy.classic_coins(10000000, false), Economy.CLASSIC_COIN_CAP, "Classic coins are capped per run")
	t.eq(Profile.stat("runs"), 3, "runs counted")
	t.eq(Profile.stat("best_score"), 9000, "best score stat")


func _solve(ci: int, n: int) -> RunState:
	var lv: Dictionary = Catalog.level(ci, n)
	return CorralBot.replay(RunState.from_level(lv), lv["solution"])


func _challenges() -> void:
	t.ok(Profile.chapter_unlocked(0), "chapter 1 is open")
	t.ok(not Profile.chapter_unlocked(1), "chapter 2 starts locked")
	t.ok(Profile.level_unlocked(0, 1), "challenge 1 is open")
	t.ok(not Profile.level_unlocked(0, 2), "challenge 2 starts locked")
	var c0: int = Profile.coins()
	var s: RunState = _solve(0, 1)
	t.eq(s.stars(), 3, "the solution earns 3 stars")
	var r: Dictionary = Profile.complete_level("meadow-01", s)
	t.eq(int(r["coins"]), Economy.LEVEL_REWARD + 3 * Economy.STAR_REWARD, "first clear with 3 stars pays")
	t.eq(Profile.coins(), c0 + int(r["coins"]), "coins added")
	t.ok(Profile.level_unlocked(0, 2), "clearing opens the next challenge")
	r = Profile.complete_level("meadow-01", s)
	t.eq(int(r["coins"]), 0, "a replay pays nothing more")
	t.eq(Profile.stars_for("meadow-01"), 3, "stars kept")
	# A worse replay never lowers stars.
	var worse: RunState = s.clone()
	worse.placed = 99
	Profile.complete_level("meadow-01", worse)
	t.eq(Profile.stars_for("meadow-01"), 3, "a worse replay keeps the best stars")
	for n: int in range(2, Catalog.unlock_clears + 1):
		Profile.complete_level(Catalog.level_id("meadow", n), _solve(0, n))
	t.ok(Profile.chapter_unlocked(1), "clearing %d challenges opens chapter 2" % Catalog.unlock_clears)
	t.eq(Profile.chapter_clears(0), Catalog.unlock_clears, "chapter clears counted")
	t.eq(Profile.next_level(), [0, Catalog.unlock_clears + 1] as Array[int], "next challenge is the first uncleared one")
	var bonus_before: int = Profile.coins()
	for n: int in range(Catalog.unlock_clears + 1, Catalog.levels_per_chapter + 1):
		r = Profile.complete_level(Catalog.level_id("meadow", n), _solve(0, n))
	t.ok(bool(r["chapter_done"]), "the last clear completes the chapter")
	t.ok(Profile.coins() - bonus_before >= Economy.CHAPTER_BONUS, "chapter bonus paid")
	t.eq(Profile.stat("levels"), Catalog.levels_per_chapter, "levels stat")
	t.eq(Profile.total_stars(), Catalog.levels_per_chapter * 3, "45 stars")


func _keys() -> void:
	t.ok(not Profile.use_key("orchard-05"), "no keys yet")
	Profile.add_keys(2)
	t.ok(not Profile.level_unlocked(1, 5), "orchard 5 is locked")
	t.ok(Profile.use_key("orchard-05"), "use a key")
	t.ok(Profile.level_unlocked(1, 5), "the key opened it")
	t.eq(Profile.keys(), 1, "one key left")
	t.ok(not Profile.use_key("orchard-05"), "a key isn't spent twice on the same challenge")
	for k: int in Economy.VIDEO_KEYS_PER_DAY:
		t.ok(Profile.add_video_key(), "video key %d" % (k + 1))
	t.ok(not Profile.add_video_key(), "video keys are limited per day")


func _daily() -> void:
	var today: String = Catalog.today_key()
	var yesterday: String = Catalog.date_key_from_day(Catalog.day_number(today) - 1)
	var s: RunState = RunState.from_level(Catalog.daily(yesterday), "daily")
	s.score = 500
	var r: Dictionary = Profile.complete_daily(yesterday, s)
	t.ok(bool(r["first"]), "first daily")
	t.eq(int(r["streak"]), 1, "streak 1")
	t.eq(int(r["coins"]), Economy.daily_reward(1), "daily reward")
	s = RunState.from_level(Catalog.daily(today), "daily")
	s.score = 800
	r = Profile.complete_daily(today, s)
	t.eq(int(r["streak"]), 2, "consecutive days extend the streak")
	t.eq(int(r["coins"]), Economy.daily_reward(2), "streak bonus")
	t.eq(Profile.current_streak(), 2, "current streak")
	s.score = 1200
	r = Profile.complete_daily(today, s)
	t.eq(int(r["coins"]), 0, "a daily pays once")
	t.ok(bool(r["new_best"]), "a better replay raises today's best")
	t.eq(int(Profile.daily_result(today)["score"]), 1200, "today's best saved")
	Save.data["daily"]["last_date"] = Catalog.date_key_from_day(Catalog.day_number(today) - 3)
	t.eq(Profile.current_streak(), 0, "missing a day ends the streak")
	t.eq(Profile.stat("best_streak"), 2, "best streak kept")


func _missions() -> void:
	Save.data["missions"] = {"day": "", "progress": {}, "claimed": {}}
	var stat0: int = Profile.stat("missions")
	var list: Array[Dictionary] = Profile.missions()
	t.eq(list.size(), 3, "three missions today")
	var c0: int = Profile.coins()
	var paid: int = 0
	# Do everything a lot: every mission completes, each pays once.
	var big: Dictionary = {"pens": [{"area": 9, "gems": 3}, {"area": 4, "gems": 2}, {"area": 2, "gems": 2}]}
	for k: int in 130:
		Profile.record_turn(big)
	Profile._mission_max("score_run", 9000)
	Profile._mission_add("levels", 5)
	Profile._mission_add("daily", 1)
	for m: Dictionary in Profile.missions():
		t.ok(bool(m["done"]), "mission done: %s" % m["text"])
		paid += int(m["reward"])
	t.eq(Profile.coins(), c0 + paid, "missions paid exactly once each")
	Profile.record_turn(big)
	t.eq(Profile.coins(), c0 + paid, "no double payment")
	t.eq(Profile.missions_done(), 3, "3 of 3 done")
	t.eq(Profile.stat("missions"), stat0 + 3, "missions stat")
	t.ok(Profile.stat("combos") >= 130, "combos counted from turns")
	t.eq(Profile.stat("biggest"), 9, "biggest pen")


func _achievements() -> void:
	var got: Array[Dictionary] = Profile.check_achievements()
	t.ok(got.size() > 5, "achievements unlock when their stats are met (%d)" % got.size())
	t.ok(Profile.achievement_done("first_pen"), "First Pen")
	t.ok(Profile.achievement_done("chapter_meadow"), "the chapter achievement")
	var again: Array[Dictionary] = Profile.check_achievements()
	t.eq(again.size(), 0, "achievements pay once")
	t.eq(Achievements.all().size(), Achievements.BASE.size() + Catalog.chapter_count(), "one achievement per chapter")


func _purchases() -> void:
	t.ok(not Profile.is_supporter(), "not a supporter yet")
	Store.buy("supporter_pack")
	t.ok(Profile.is_supporter(), "simulated Supporter purchase")
	Save.data["hint_day"] = {"day": "", "used": 0}
	t.eq(Profile.free_hints_left(), Economy.SUPPORTER_FREE_HINTS, "Supporters get 3 free hints a day")
	var c0: int = Profile.coins()
	Store.buy("coins_1000")
	t.eq(Profile.coins(), c0 + 1000, "a coin bag adds coins")
	Store.buy("keys_5")
	t.ok(Profile.keys() >= 5, "a key pack adds keys")
	Store.buy("tip_50")
	t.eq(Profile.tips_given(), 1, "a tip is counted")
	t.ok(not Profile.owns("theme_pack"), "no themes yet")
	Profile.start_trial("theme_pack")
	t.ok(Profile.owns("theme_pack"), "a trial unlocks themes for now")
	t.ok(not Profile.bought("theme_pack"), "a trial isn't a purchase")
	Save.data["trials"]["theme_pack"] = int(Time.get_unix_time_from_system()) - 5
	t.ok(not Profile.owns("theme_pack"), "the trial runs out")
	var c1: int = Profile.coins()
	var k1: int = Profile.keys()
	Store.buy("complete_pack")
	t.ok(Profile.bought("style_pack") and Profile.bought("theme_pack"), "the Complete pack includes every pack")
	t.eq(Profile.coins(), c1 + Store.COMPLETE_COINS, "the Complete pack's coins")
	t.eq(Profile.keys(), k1 + Store.COMPLETE_KEYS, "the Complete pack's keys")
	Store.buy("complete_pack")
	t.eq(Profile.coins(), c1 + Store.COMPLETE_COINS, "buying it again doesn't pay twice")
	t.ok(Store.complete_saving() > 0, "the Complete pack is a saving")
	for id: String in Store.all_ids():
		t.ok(not Store.price(id).is_empty(), "%s has a price" % id)


func _runs_and_restart() -> void:
	var s: RunState = RunState.classic(9)
	for k: int in 6:
		var m: Array = CorralBot.best_move(s)
		s.place(int(m[0]), m[1])
	Profile.store_run("classic", s)
	Save.flush()
	Save.load_data()
	var back: Dictionary = Profile.saved_run("classic")
	t.eq(JSON.stringify(RunState.from_dict(back).to_dict()), JSON.stringify(s.to_dict()), "a run in progress survives a restart")
	t.eq(Profile.best_score(), 9000, "best score survives a restart")
	t.ok(Profile.is_supporter(), "purchases survive a restart")


func _reset() -> void:
	var coins_bought: int = int(Save.data["coins_bought"])
	Profile.reset_all()
	t.eq(Profile.best_score(), 0, "reset clears the best score")
	t.eq(Profile.total_stars(), 0, "reset clears stars")
	t.ok(Profile.is_supporter(), "reset keeps purchases")
	t.eq(Profile.coins(), Economy.START_COINS + coins_bought, "reset keeps bought coins")
	t.ok(Profile.keys() > 0, "reset keeps keys")
	t.ok(Profile.seen("complete_bonus"), "reset remembers the Complete pack bonus was paid")


func _corrupt() -> void:
	Save.flush()
	var f: FileAccess = FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	Save.load_data()
	t.eq(Save.recovered_from, "backup", "a corrupt save falls back to the backup")
	t.ok(Profile.is_supporter(), "the backup kept the purchases")
	var g: FileAccess = FileAccess.open(SAVE + ".bak", FileAccess.WRITE)
	g.store_string("")
	g.close()
	var h: FileAccess = FileAccess.open(SAVE, FileAccess.WRITE)
	h.store_string("[]")
	h.close()
	Save.load_data()
	t.eq(Save.recovered_from, "fresh", "with no good copy, a fresh save is used")
	t.eq(Profile.coins(), Economy.START_COINS, "fresh save defaults")
