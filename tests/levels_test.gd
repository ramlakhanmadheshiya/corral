extends SceneTree
## Every challenge level: well-formed, fair at the start (nothing enclosed, gems
## off the edge), goals as planned, stars that make sense, and achievable: the
## bot's recorded solution is replayed with the real rules and must meet the goal
## within par. Each chapter must get harder, and the generator must reproduce
## the stored levels exactly.
##
##   godot --headless --path . -s res://tests/levels_test.gd

var t: Check = Check.new("LEVELS")


func _init() -> void:
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapters.json"))
	var per: int = int(plan["levels_per_chapter"])
	var chapters: Array = plan["chapters"]
	t.eq(chapters.size(), 8, "8 chapters")
	var total: int = 0
	var ids: Dictionary = {}
	for c: int in chapters.size():
		var ch: Dictionary = chapters[c]
		t.eq((ch["goals"] as Array).size(), per, "%s plans %d goals" % [ch["id"], per])
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/%s.json" % ch["id"]))
		t.ok(data is Dictionary, "%s.json parses" % ch["id"])
		if not data is Dictionary:
			continue
		var levels: Array = data["levels"]
		t.eq(levels.size(), per, "%s has %d levels" % [ch["id"], per])
		var moves: Array[int] = []
		for n: int in levels.size():
			var lv: Dictionary = levels[n]
			total += 1
			var id: String = "%s-%02d" % [ch["id"], n + 1]
			t.eq(str(lv["id"]), id, "level id %s" % id)
			t.ok(not ids.has(id), "%s is unique" % id)
			ids[id] = true
			_check_level(lv, str((ch["goals"] as Array)[n]), bool(ch.get("hop", false)))
			moves.append(int(lv.get("bot_moves", 0)))
		# Difficulty climbs through each chapter.
		var third: int = per / 3
		t.ok(_avg(moves.slice(per - third)) > _avg(moves.slice(0, third)), "%s gets harder (first third %.1f, last third %.1f moves)" % [ch["id"], _avg(moves.slice(0, third)), _avg(moves.slice(per - third))])
		# Reproducible: regenerate two levels and compare.
		for n: int in [1, per]:
			var again: Dictionary = LevelMaker.challenge(ch, c, n, per)
			t.eq(JSON.stringify(JSON.parse_string(JSON.stringify(again))), JSON.stringify(levels[n - 1]), "%s level %d regenerates identically" % [ch["id"], n])
	t.eq(total, 120, "120 challenges in all")
	quit(t.report())


func _avg(a: Array) -> float:
	var s: float = 0.0
	for v: Variant in a:
		s += float(v)
	return s / float(maxi(1, a.size()))


func _check_level(lv: Dictionary, kind: String, hop: bool) -> void:
	var id: String = str(lv["id"])
	var goal: Dictionary = lv["goal"]
	t.eq(str(goal["type"]), kind, "%s goal type follows the plan" % id)
	t.ok(int(goal["target"]) >= 1, "%s has a target" % id)
	t.eq(bool(lv.get("hop", false)), hop, "%s hops only in hopping chapters" % id)
	var seq: Array = lv["sequence"]
	t.eq(seq.size(), int(lv["pieces"]), "%s sequence length matches its piece count" % id)
	for p: Variant in seq:
		t.ok(Pieces.has(str(p)), "%s piece %s exists" % [id, p])
	var par: Array = lv["par"]
	t.ok(int(par[0]) <= int(par[1]) and int(par[1]) <= int(lv["pieces"]), "%s par is ordered and within the pieces" % id)
	t.ok(int(lv["pieces"]) >= int(lv["bot_moves"]) + 2, "%s leaves spare pieces" % id)
	var seen: Dictionary = {}
	for key: String in ["walls", "rocks", "gems"]:
		for i: Variant in lv.get(key, []):
			t.ok(int(i) >= 0 and int(i) < Field.N * Field.N, "%s %s in range" % [id, key])
			if key != "gems":
				t.ok(not seen.has(int(i)), "%s cells don't overlap" % id)
				seen[int(i)] = true
	for g: Variant in lv.get("gems", []):
		t.ok(not seen.has(int(g)), "%s gem sits on an empty cell" % id)
		t.ok(not Field.is_border(int(g)), "%s gem is off the edge" % id)
	if kind == "gems":
		t.ok((lv["gems"] as Array).size() >= int(goal["target"]), "%s has enough gems for its goal" % id)
	var start: RunState = RunState.from_level(lv)
	t.eq(start.field.enclosed_regions().size(), 0, "%s starts with nothing enclosed" % id)
	t.ok(not start.goal_met(), "%s isn't won before the first move" % id)
	var end: RunState = CorralBot.replay(start, lv["solution"])
	t.ok(end != null, "%s solution is legal" % id)
	if end != null:
		t.ok(end.goal_met(), "%s solution meets the goal" % id)
		t.eq(end.end, RunState.End.WON, "%s solution wins" % id)
		t.eq(end.placed, int(lv["bot_moves"]), "%s solution length" % id)
		t.eq(end.stars(), 3, "%s solution earns three stars" % id)
