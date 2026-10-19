extends Node
## The player's progress and wallet: best scores, challenge stars and unlocks,
## rewards, hints, keys, purchases, daily streaks, missions and achievements.
## Every reward is keyed by what earned it, so it is paid only once.

signal coins_changed(total: int)
signal keys_changed(total: int)
signal achievement_unlocked(achievement: Dictionary)
signal mission_completed(mission: Dictionary)
signal settings_changed
signal purchases_changed
signal supporter_changed(on: bool)

var _d: Dictionary:
	get:
		return Save.data


# --- Coins -------------------------------------------------------------------

func coins() -> int:
	return int(_d["coins"])


func add_coins(n: int) -> void:
	if n <= 0:
		return
	_d["coins"] = coins() + n
	Save.mark_dirty()
	coins_changed.emit(coins())


## Coins bought in the shop (kept if progress is reset).
func add_bought_coins(n: int) -> void:
	if n <= 0:
		return
	_d["coins_bought"] = int(_d["coins_bought"]) + n
	add_coins(n)


## Takes coins if the player has enough. Returns false (and changes nothing) otherwise.
func spend(n: int) -> bool:
	if n < 0 or coins() < n:
		return false
	_d["coins"] = coins() - n
	Save.mark_dirty()
	coins_changed.emit(coins())
	return true


func _today_counter(key: String) -> Dictionary:
	var c: Dictionary = _d[key]
	if str(c.get("day", "")) != Catalog.today_key():
		c["day"] = Catalog.today_key()
		for k: Variant in c.keys():
			if k != "day":
				c[k] = 0
	return c


## Free hints left today (1 a day, 3 for Supporters).
func free_hints_left() -> int:
	var allowed: int = Economy.SUPPORTER_FREE_HINTS if is_supporter() else Economy.FREE_HINTS
	return maxi(0, allowed - int(_today_counter("hint_day").get("used", 0)))


func use_free_hint() -> bool:
	if free_hints_left() <= 0:
		return false
	var c: Dictionary = _today_counter("hint_day")
	c["used"] = int(c.get("used", 0)) + 1
	Save.mark_dirty()
	return true


func video_coins_left() -> int:
	return maxi(0, Economy.VIDEO_COINS_PER_DAY - int(_today_counter("video").get("coins", 0)))


## Pays the reward for a watched "free coins" video (limited per day).
func claim_video_coins() -> bool:
	if video_coins_left() <= 0:
		return false
	var c: Dictionary = _today_counter("video")
	c["coins"] = int(c.get("coins", 0)) + 1
	add_coins(Economy.VIDEO_COINS)
	return true


# --- Classic -------------------------------------------------------------------

func best_score() -> int:
	return int(_d["classic"]["best"])


## Records a finished Classic run; pays coins for its score (and a new best).
func finish_classic(state: RunState) -> Dictionary:
	var c: Dictionary = _d["classic"]
	var old_best: int = int(c["best"])
	var new_best: bool = state.score > old_best
	c["runs"] = int(c["runs"]) + 1
	c["last"] = state.score
	if new_best:
		c["best"] = state.score
	var s: Dictionary = _d["stats"]
	s["runs"] = int(s["runs"]) + 1
	s["best_score"] = maxi(int(s["best_score"]), state.score)
	_mission_max("score_run", state.score)
	clear_run("classic")
	var reward: int = Economy.classic_coins(state.score, new_best and old_best > 0)
	add_coins(reward)
	Save.mark_dirty()
	return {"coins": reward, "new_best": new_best, "best": maxi(old_best, state.score), "old_best": old_best}


# --- Challenges: levels, stars and chapters ----------------------------------

func is_cleared(id: String) -> bool:
	return (_d["cleared"] as Dictionary).has(id)


func stars_for(id: String) -> int:
	return int((_d["cleared"] as Dictionary).get(id, {}).get("stars", 0))


func chapter_clears(ci: int) -> int:
	var c: Dictionary = Catalog.chapter(ci)
	if c.is_empty():
		return 0
	var n: int = 0
	for k: int in range(1, Catalog.levels_per_chapter + 1):
		if is_cleared(Catalog.level_id(c["id"], k)):
			n += 1
	return n


func chapter_stars(ci: int) -> int:
	var c: Dictionary = Catalog.chapter(ci)
	if c.is_empty():
		return 0
	var n: int = 0
	for k: int in range(1, Catalog.levels_per_chapter + 1):
		n += stars_for(Catalog.level_id(c["id"], k))
	return n


func total_stars() -> int:
	var n: int = 0
	for v: Variant in (_d["cleared"] as Dictionary).values():
		n += int((v as Dictionary).get("stars", 0))
	return n


## A chapter opens when enough challenges of the one before it are cleared.
func chapter_unlocked(ci: int) -> bool:
	if ci <= 0:
		return ci == 0
	if ci >= Catalog.chapter_count():
		return false
	return chapter_clears(ci - 1) >= Catalog.unlock_clears


## A challenge is open when the one before it is cleared, or a key opened it.
func level_unlocked(ci: int, n: int) -> bool:
	if not chapter_unlocked(ci) or n < 1 or n > Catalog.levels_per_chapter:
		return false
	var cid: String = Catalog.chapter(ci)["id"]
	var id: String = Catalog.level_id(cid, n)
	return n == 1 or is_cleared(id) or key_unlocked(id) or is_cleared(Catalog.level_id(cid, n - 1))


func open_in(ci: int) -> int:
	var n: int = 0
	for k: int in range(1, Catalog.levels_per_chapter + 1):
		if level_unlocked(ci, k):
			n += 1
	return n


func unlocked_chapter_count() -> int:
	var n: int = 0
	for i: int in Catalog.chapter_count():
		if chapter_unlocked(i):
			n += 1
	return n


## The next challenge to play: the last one tried if still unfinished, otherwise
## the first open, uncleared one.
func next_level() -> Array[int]:
	var last: String = str(_d["last_level"])
	if not last.is_empty() and not is_cleared(last):
		var cn: Array[int] = Catalog.parse_level_id(last)
		if cn[0] >= 0 and level_unlocked(cn[0], cn[1]):
			return cn
	for ci: int in Catalog.chapter_count():
		if not chapter_unlocked(ci):
			continue
		for n: int in range(1, Catalog.levels_per_chapter + 1):
			if level_unlocked(ci, n) and not is_cleared(Catalog.level_id(Catalog.chapter(ci)["id"], n)):
				return [ci, n]
	return [maxi(0, Catalog.chapter_count() - 1), Catalog.levels_per_chapter]


func set_last_level(id: String) -> void:
	_d["last_level"] = id
	Save.mark_dirty()


## Marks a challenge cleared with its stars and pays for it: LEVEL_REWARD on the
## first clear and STAR_REWARD for every star earned for the first time. Clearing a
## whole chapter pays its bonus once.
func complete_level(id: String, state: RunState) -> Dictionary:
	var stars: int = state.stars()
	var cn: Array[int] = Catalog.parse_level_id(id)
	var first: bool = not is_cleared(id)
	var old_best: int = stars_for(id)
	var chapters_before: int = unlocked_chapter_count()
	var best: int = maxi(old_best, stars)
	var new_stars: int = best - old_best
	var reward: int = (Economy.LEVEL_REWARD if first else 0) + new_stars * Economy.STAR_REWARD
	var prev: Dictionary = (_d["cleared"] as Dictionary).get(id, {})
	var fewest: int = mini(int(prev.get("best", 9999)), state.placed)
	_d["cleared"][id] = {"stars": best, "best": fewest}
	var s: Dictionary = _d["stats"]
	if first:
		s["levels"] = int(s["levels"]) + 1
		_mission_add("levels", 1)
	s["stars"] = int(s["stars"]) + new_stars
	if stars == 3 and old_best < 3:
		s["perfect"] = int(s["perfect"]) + 1
	var chapter_done: bool = false
	if cn[0] >= 0:
		var key: String = "ch_" + str(Catalog.chapter(cn[0])["id"])
		if int(s.get(key, 0)) == 0 and chapter_clears(cn[0]) == Catalog.levels_per_chapter:
			s[key] = 1
			chapter_done = true
			reward += Economy.CHAPTER_BONUS
	clear_run(id)
	add_coins(reward)
	Save.mark_dirty()
	return {
		"coins": reward, "first": first, "stars": stars, "best": best, "new_stars": new_stars,
		"chapter_done": chapter_done, "chapter_unlocked": unlocked_chapter_count() > chapters_before,
	}


# --- Level keys --------------------------------------------------------------

func keys() -> int:
	return int(_d["keys"])


func add_keys(n: int) -> void:
	if n <= 0:
		return
	_d["keys"] = keys() + n
	Save.mark_dirty()
	keys_changed.emit(keys())


## Spends a key to open one locked challenge for good. False if there are no keys.
func use_key(id: String) -> bool:
	if keys() <= 0 or key_unlocked(id):
		return false
	_d["keys"] = keys() - 1
	_d["unlocked"][id] = true
	Save.mark_dirty()
	keys_changed.emit(keys())
	return true


func key_unlocked(id: String) -> bool:
	return (_d["unlocked"] as Dictionary).has(id)


func video_keys_left() -> int:
	return maxi(0, Economy.VIDEO_KEYS_PER_DAY - int(_today_counter("video").get("keys", 0)))


func add_video_key() -> bool:
	if video_keys_left() <= 0:
		return false
	var c: Dictionary = _today_counter("video")
	c["keys"] = int(c.get("keys", 0)) + 1
	add_keys(1)
	return true


# --- Purchases and trials ----------------------------------------------------

## True if bought (directly or through the Complete pack) or, for cosmetic
## packs, on a video trial that hasn't run out.
func owns(product: String) -> bool:
	return bought(product) or trial_left(product) > 0


func bought(product: String) -> bool:
	var owned: Dictionary = _d["owned"]
	return bool(owned.get(product, false)) or bool(owned.get("complete_pack", false))


func set_owned(product: String, on: bool) -> void:
	var was_supporter: bool = is_supporter()
	_d["owned"][product] = on
	Save.mark_dirty()
	purchases_changed.emit()
	if is_supporter() != was_supporter:
		supporter_changed.emit(is_supporter())


func is_supporter() -> bool:
	return bought("supporter_pack")


func trial_left(product: String) -> int:
	var until: int = int((_d["trials"] as Dictionary).get(product, 0))
	return maxi(0, until - int(Time.get_unix_time_from_system()))


func start_trial(product: String) -> void:
	_d["trials"][product] = int(Time.get_unix_time_from_system()) + Economy.TRIAL_SECONDS
	Save.mark_dirty()
	purchases_changed.emit()


## "42:13" left on a trial (or "" when none).
func trial_clock(product: String) -> String:
	var left: int = trial_left(product)
	if left <= 0:
		return ""
	return "%d:%02d" % [left / 60, left % 60]


func tips_given() -> int:
	return int(_d["tips"])


func add_tip() -> void:
	_d["tips"] = tips_given() + 1
	Save.mark_dirty()


# --- Runs in progress (survive restarts) -------------------------------------

func saved_run(key: String) -> Dictionary:
	return (_d["runs"] as Dictionary).get(key, {})


func store_run(key: String, state: RunState) -> void:
	_d["runs"][key] = state.to_dict()
	Save.mark_dirty()


func clear_run(key: String) -> void:
	(_d["runs"] as Dictionary).erase(key)
	Save.mark_dirty()


# --- Play stats and missions -----------------------------------------------------

## Counts one placement's results toward stats and today's missions.
func record_turn(result: Dictionary) -> void:
	var s: Dictionary = _d["stats"]
	var pens: Array = result.get("pens", [])
	s["pieces"] = int(s["pieces"]) + 1
	_mission_add("pieces", 1)
	if pens.is_empty():
		Save.mark_dirty()
		return
	var gems: int = 0
	var big: int = 0
	for p: Dictionary in pens:
		gems += int(p["gems"])
		big = maxi(big, int(p["area"]))
	s["pens"] = int(s["pens"]) + pens.size()
	s["biggest"] = maxi(int(s["biggest"]), big)
	s["gems"] = int(s["gems"]) + gems
	_mission_add("pens", pens.size())
	_mission_add("gems", gems)
	_mission_max("big_pen", big)
	if pens.size() >= 2:
		s["combos"] = int(s["combos"]) + 1
		_mission_add("combos", 1)
	Save.mark_dirty()


func record_hint() -> void:
	_d["stats"]["hints"] = int(_d["stats"]["hints"]) + 1
	Save.mark_dirty()


func _missions_today() -> Dictionary:
	var m: Dictionary = _d["missions"]
	if str(m.get("day", "")) != Catalog.today_key():
		m["day"] = Catalog.today_key()
		m["progress"] = {}
		m["claimed"] = {}
	return m


func _mission_add(stat: String, n: int) -> void:
	if n <= 0:
		return
	var p: Dictionary = _missions_today()["progress"]
	p[stat] = int(p.get(stat, 0)) + n
	_check_missions()


func _mission_max(stat: String, v: int) -> void:
	var p: Dictionary = _missions_today()["progress"]
	if v > int(p.get(stat, 0)):
		p[stat] = v
		_check_missions()


## Today's missions with their progress: [{..., value, done}].
func missions() -> Array[Dictionary]:
	var m: Dictionary = _missions_today()
	var out: Array[Dictionary] = []
	var list: Array[Dictionary] = Missions.for_date(Catalog.today_key())
	for i: int in list.size():
		var e: Dictionary = list[i].duplicate()
		e["value"] = mini(int((m["progress"] as Dictionary).get(e["stat"], 0)), int(e["target"]))
		e["done"] = (m["claimed"] as Dictionary).has(str(i))
		out.append(e)
	return out


func missions_done() -> int:
	var n: int = 0
	for e: Dictionary in missions():
		if e["done"]:
			n += 1
	return n


func _check_missions() -> void:
	var m: Dictionary = _missions_today()
	var list: Array[Dictionary] = Missions.for_date(Catalog.today_key())
	for i: int in list.size():
		var e: Dictionary = list[i]
		if (m["claimed"] as Dictionary).has(str(i)):
			continue
		if int((m["progress"] as Dictionary).get(e["stat"], 0)) >= int(e["target"]):
			m["claimed"][str(i)] = true
			_d["stats"]["missions"] = int(_d["stats"]["missions"]) + 1
			add_coins(int(e["reward"]))
			mission_completed.emit(e)
	Save.mark_dirty()


# --- Daily Board -------------------------------------------------------------

func daily_done(date_key: String) -> bool:
	return (_d["daily"]["done"] as Dictionary).has(date_key)


func daily_result(date_key: String) -> Dictionary:
	return (_d["daily"]["done"] as Dictionary).get(date_key, {})


## The streak as it stands today: it survives until a whole day is missed.
func current_streak() -> int:
	var daily: Dictionary = _d["daily"]
	var last: String = str(daily["last_date"])
	if last.is_empty():
		return 0
	var gap: int = Catalog.day_number(Catalog.today_key()) - Catalog.day_number(last)
	return int(daily["streak"]) if gap <= 1 else 0


## Pays for a daily once per date (a replay can still raise its best score) and
## extends the streak when days are consecutive.
func complete_daily(date_key: String, state: RunState) -> Dictionary:
	var daily: Dictionary = _d["daily"]
	clear_run("daily-" + date_key)
	var stars: int = state.stars()
	if daily_done(date_key):
		var prev: Dictionary = daily["done"][date_key]
		var better: bool = state.score > int(prev.get("score", 0))
		if better:
			daily["done"][date_key] = {"score": state.score, "stars": maxi(stars, int(prev.get("stars", 0)))}
			Save.mark_dirty()
		return {"coins": 0, "first": false, "streak": current_streak(), "stars": stars, "new_best": better}
	daily["done"][date_key] = {"score": state.score, "stars": stars}
	var last: String = str(daily["last_date"])
	var streak: int = 1
	if not last.is_empty():
		var gap: int = Catalog.day_number(date_key) - Catalog.day_number(last)
		if gap == 1:
			streak = int(daily["streak"]) + 1
		elif gap <= 0:
			streak = maxi(1, int(daily["streak"]))
	if last.is_empty() or Catalog.day_number(date_key) >= Catalog.day_number(last):
		daily["last_date"] = date_key
		daily["streak"] = streak
	daily["best_streak"] = maxi(int(daily["best_streak"]), streak)
	var s: Dictionary = _d["stats"]
	s["dailies"] = int(s["dailies"]) + 1
	s["best_streak"] = int(daily["best_streak"])
	if date_key == Catalog.today_key():
		_mission_add("daily", 1)
	var reward: int = Economy.daily_reward(streak)
	add_coins(reward)
	Save.mark_dirty()
	return {"coins": reward, "first": true, "streak": streak, "stars": stars, "new_best": true}


# --- Achievements ------------------------------------------------------------

func stat(key: String) -> int:
	return int(_d["stats"].get(key, 0))


func achievement_done(id: String) -> bool:
	return (_d["achievements"] as Dictionary).has(id)


## Unlocks (and pays, once) every achievement whose goal is met.
func check_achievements() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a: Dictionary in Achievements.all():
		if achievement_done(a["id"]) or stat(a["stat"]) < int(a["goal"]):
			continue
		_d["achievements"][a["id"]] = Catalog.today_key()
		add_coins(int(a["reward"]))
		out.append(a)
		achievement_unlocked.emit(a)
	if not out.is_empty():
		Save.mark_dirty()
	return out


# --- Settings and one-time flags ---------------------------------------------

func setting(key: String, fallback: Variant = null) -> Variant:
	var st: Variant = _d.get("settings", {})
	return (st as Dictionary).get(key, fallback) if st is Dictionary else fallback


func set_setting(key: String, value: Variant) -> void:
	_d["settings"][key] = value
	Save.mark_dirty()
	settings_changed.emit()


func seen(key: String) -> bool:
	return (_d["seen"] as Dictionary).has(key)


func mark_seen(key: String) -> void:
	_d["seen"][key] = true
	Save.mark_dirty()


func reset_all() -> void:
	Save.reset()
	coins_changed.emit(coins())
	keys_changed.emit(keys())
	settings_changed.emit()
