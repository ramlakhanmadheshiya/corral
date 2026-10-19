class_name Missions
extends RefCounted
## Three daily missions, picked from the date (the same three for everyone that
## day): an easy, a medium and a hard one. Progress counts only today's play.
## Each pays its coins once, automatically, when it is done.

## stat: the day counter it reads; "max" stats keep the best single value.
const POOL: Array[Dictionary] = [
	{"id": "pens", "text": "Capture %s pens", "stat": "pens", "targets": [5, 12, 25]},
	{"id": "big_pen", "text": "Capture a pen of %s+ cells", "stat": "big_pen", "targets": [4, 6, 9], "max": true},
	{"id": "gems", "text": "Capture %s gems", "stat": "gems", "targets": [2, 4, 7]},
	{"id": "combos", "text": "Close two pens with one piece %s×", "stat": "combos", "targets": [1, 2, 3]},
	{"id": "score_run", "text": "Score %s in one Classic run", "stat": "score_run", "targets": [1000, 3000, 8000], "max": true},
	{"id": "pieces", "text": "Place %s pieces", "stat": "pieces", "targets": [30, 60, 120]},
	{"id": "levels", "text": "Clear %s challenges", "stat": "levels", "targets": [1, 2, 4]},
	{"id": "daily", "text": "Finish today's Daily Board", "stat": "daily", "targets": [1, 1, 1]},
]
const REWARDS: Array[int] = [20, 35, 50]


## Today's three missions: [{id, text, stat, target, reward, max}].
static func for_date(date_key: String) -> Array[Dictionary]:
	var rng: Rng = Rng.new(Rng.hash_string("corral-missions-" + date_key))
	var pool: Array = range(POOL.size())
	rng.shuffle(pool)
	var out: Array[Dictionary] = []
	for tier: int in 3:
		var m: Dictionary = POOL[int(pool[tier])]
		var target: int = int((m["targets"] as Array)[tier])
		out.append({
			"id": m["id"], "stat": m["stat"], "target": target, "reward": REWARDS[tier],
			"max": bool(m.get("max", false)),
			"text": str(m["text"]) % _num(target) if str(m["text"]).contains("%s") else str(m["text"]),
		})
	return out


static func _num(n: int) -> String:
	var s: String = str(n)
	if n >= 1000:
		s = "%d,%03d" % [n / 1000, n % 1000]
	return s
