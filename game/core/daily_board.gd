class_name DailyBoard
extends RefCounted
## The Daily Board, built on the phone from the date alone (no server, no stored
## pool): everyone gets the same rocks, gems, starting walls and the same 30
## pieces in the same order on the same date. The bot plays it once to set the
## star scores and to make sure every piece can be placed.

const PIECES: int = 30
const EPOCH_Y: int = 2026
const EPOCH_M: int = 10
const EPOCH_D: int = 1
const MAX_TRIES: int = 12


static func day_number(date_key: String) -> int:
	var parts: PackedStringArray = date_key.split("-")
	if parts.size() != 3:
		return 0
	var t: int = Time.get_unix_time_from_datetime_dict({"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2]), "hour": 12})
	var t0: int = Time.get_unix_time_from_datetime_dict({"year": EPOCH_Y, "month": EPOCH_M, "day": EPOCH_D, "hour": 12})
	return int(round(float(t - t0) / 86400.0))


static func date_key_from_day(day: int) -> String:
	var t0: int = Time.get_unix_time_from_datetime_dict({"year": EPOCH_Y, "month": EPOCH_M, "day": EPOCH_D, "hour": 12})
	return Time.get_date_string_from_unix_time(t0 + day * 86400)


## Weekday 0 = Monday ... 6 = Sunday; the board gets a little busier through the week.
static func weekday(date_key: String) -> int:
	return posmod(day_number(date_key) + 3, 7)  # 1 Oct 2026 is a Thursday


static func build(date_key: String) -> Dictionary:
	for attempt: int in MAX_TRIES:
		var level: Dictionary = _layout(date_key, attempt)
		var start: RunState = RunState.from_level(level, "daily")
		var run: Dictionary = CorralBot.play(start, PIECES + 5)
		var end: RunState = run["state"]
		if end.placed >= PIECES or attempt == MAX_TRIES - 1:
			var top: int = maxi(200, end.score)
			level["thresholds"] = [_round(top * 0.25), _round(top * 0.6)]
			level["bot_score"] = end.score
			return level
	return {}


static func _round(v: float) -> int:
	return maxi(10, int(v / 10.0) * 10)


static func _layout(date_key: String, attempt: int) -> Dictionary:
	var rng: Rng = Rng.new(Rng.hash_string("corral-daily-%s-%d" % [date_key, attempt]))
	var wd: int = weekday(date_key)
	var f: Field = Field.new()
	var rocks: int = 2 + wd / 2 + rng.range_i(0, 1)
	var gems: int = 2 + (1 if wd >= 3 else 0) + rng.range_i(0, 1)
	var fragments: int = 2 + rng.range_i(0, 2)
	LevelMaker.scatter(f, rng, rocks, gems, fragments)
	var seq: Array = []
	var d: float = 0.15 + 0.08 * wd
	for k: int in PIECES:
		seq.append(PieceGenerator.draw_one(rng, d))
	var level: Dictionary = f.to_dict()
	level["id"] = "daily-" + date_key
	level["date"] = date_key
	level["sequence"] = seq
	level["hop"] = wd >= 5
	return level
