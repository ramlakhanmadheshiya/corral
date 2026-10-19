extends SceneTree
## Builds the challenge levels from the plan in data/chapters.json and writes
## data/levels/<chapter>.json. Deterministic: CI regenerates them and fails on
## any difference.
##
##   godot --headless --path . -s res://tools/generate_levels.gd            # everything
##   godot --headless --path . -s res://tools/generate_levels.gd -- meadow  # one chapter


func _init() -> void:
	var only: PackedStringArray = OS.get_cmdline_user_args()
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapters.json"))
	var per: int = int(plan["levels_per_chapter"])
	var chapters: Array = plan["chapters"]
	for c: int in chapters.size():
		var ch: Dictionary = chapters[c]
		if not only.is_empty() and not only.has(str(ch["id"])):
			continue
		var t0: int = Time.get_ticks_msec()
		var levels: Array = []
		for n: int in range(1, per + 1):
			var level: Dictionary = LevelMaker.challenge(ch, c, n, per)
			if level.is_empty():
				push_error("could not build %s level %d" % [ch["id"], n])
				quit(1)
				return
			levels.append(level)
		var out: FileAccess = FileAccess.open("res://data/levels/%s.json" % ch["id"], FileAccess.WRITE)
		out.store_string(_pretty(levels, ch["id"]))
		out.close()
		var ks: PackedStringArray = PackedStringArray()
		for l: Dictionary in levels:
			ks.append("%s%d" % [str(l["goal"]["type"]).substr(0, 2), int(l["bot_moves"])])
		print("%s: %d levels in %.1fs  [%s]" % [ch["id"], levels.size(), (Time.get_ticks_msec() - t0) / 1000.0, " ".join(ks)])
	quit(0)


## One level per line, so diffs stay readable.
func _pretty(levels: Array, id: String) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for l: Dictionary in levels:
		lines.append("  " + JSON.stringify(l, "", false))
	return "{\"chapter\": \"%s\", \"levels\": [\n%s\n]}\n" % [id, ",\n".join(lines)]
