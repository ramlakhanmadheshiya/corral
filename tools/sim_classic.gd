extends SceneTree
## Plays Classic runs with the bot and prints how they went (balance checks).
##   godot --headless --path . -s res://tools/sim_classic.gd -- [runs] [greed]

func _init() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var runs: int = int(a[0]) if a.size() > 0 else 10
	var greed: float = float(a[1]) if a.size() > 1 else CorralBot.GREED
	var total: int = 0
	var t0: int = Time.get_ticks_msec()
	for k: int in runs:
		var s: RunState = RunState.classic(1000 + k)
		var r: Dictionary = CorralBot.play(s, 600, greed)
		var e: RunState = r["state"]
		total += e.score
		print("run %d: score %d, pieces %d, pens %d, biggest %d, gems %d, combos %d, rocks %d, end %d" % [k, e.score, e.placed, e.captures, e.biggest, e.gems_captured, e.combos, e.field.count(Field.ROCK), e.end])
	print("avg %d  (%.1fs)" % [total / runs, (Time.get_ticks_msec() - t0) / 1000.0])
	quit()
