class_name BoardView
extends Control
## Draws the 9 x 9 field and everything that happens on it: chunky walls that
## join up with their neighbours, rocks, bobbing gems, the drag ghost with a
## preview of the pens it would close (and what they'd score), and the capture
## itself: a white flash, colour spreading cell by cell like a paint bucket from
## the piece that closed it, rising pentatonic pops, confetti, a score popup, a
## soft shake, and the bordering walls shrinking away. The rules live in
## RunState; this only shows them.

signal animation_done

const FILL_STEP: float = 0.045
const FILL_LEAD: float = 0.1
const FILL_HOLD: float = 0.45
const FILL_FADE: float = 0.5
const STAIN_ALPHA: float = 0.14

var state: RunState
## Pen style to draw with ("" = the player's chosen one).
var style_id: String = ""
## No sounds or vibration (the home screen's demo board, previews).
var quiet: bool = false
## Cells painted solid (cell -> Color): how-to pictures and the share picture.
var paint: Dictionary = {}
## How strongly past pens' stains show (the share picture shows the whole painting).
var stain_alpha: float = STAIN_ALPHA
## Walls can be hidden (0) so the painting underneath shows (the share picture).
var wall_alpha: float = 1.0

var _cs: float = 40.0
var _origin: Vector2 = Vector2.ZERO
var _panel: Rect2 = Rect2()
var _t: float = 0.0

var _ghost_piece: String = ""
var _ghost_origin: Vector2i = Vector2i.ZERO
var _ghost_valid: bool = false
var _preview: Array[PackedInt32Array] = []
var _hint_cells: PackedInt32Array = PackedInt32Array()
var _target_cells: PackedInt32Array = PackedInt32Array()

var _pop: Dictionary = {}          # cell -> age (placed pop)
var _fills: Dictionary = {}        # cell -> {color, start, end}
var _vanish: Dictionary = {}       # cell -> start time
var _spawn: Dictionary = {}        # cell -> {start, kind}
var _hops: Dictionary = {}         # cell -> {from, start}
var _gem_fx: Array[Dictionary] = []  # captured gems flying up
var _particles: Array[Dictionary] = []
var _popups: Array[Dictionary] = []
var _sched: Array[Dictionary] = []
var _shake: float = 0.0
var _busy_until: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resized.connect(_layout)


func setup(s: RunState) -> void:
	state = s
	_fills.clear()
	_vanish.clear()
	_spawn.clear()
	_hops.clear()
	_pop.clear()
	_gem_fx.clear()
	_particles.clear()
	_popups.clear()
	_sched.clear()
	clear_ghost()
	_layout()
	queue_redraw()


func _layout() -> void:
	var side: float = floorf(minf(size.x, size.y))
	_panel = Rect2(((size - Vector2(side, side)) / 2.0).floor(), Vector2(side, side))
	var pad: float = roundf(side * 0.028)
	_cs = (side - 2.0 * pad) / float(Field.N)
	_origin = _panel.position + Vector2(pad, pad)
	queue_redraw()


func cell_size() -> float:
	return _cs


func cell_rect(i: int) -> Rect2:
	return Rect2(_origin + Vector2(i % Field.N, i / Field.N) * _cs, Vector2(_cs, _cs))


func cell_center(i: int) -> Vector2:
	return cell_rect(i).get_center()


## Global position of the grid's top-left corner.
func grid_global() -> Vector2:
	return global_position + _origin


## The top-left cell a piece would snap to when its top-left corner is at `corner` (global).
func snap(corner: Vector2) -> Vector2i:
	var local: Vector2 = corner - grid_global()
	return Vector2i(roundi(local.x / _cs), roundi(local.y / _cs))


func busy() -> bool:
	return _t < _busy_until


# --- Ghost, preview and hints ------------------------------------------------------

func set_ghost(piece: String, origin: Vector2i, valid: bool, preview: Array[PackedInt32Array]) -> void:
	_ghost_piece = piece
	_ghost_origin = origin
	_ghost_valid = valid
	_preview = preview
	queue_redraw()


func clear_ghost() -> void:
	_ghost_piece = ""
	_preview = []
	queue_redraw()


func show_hint(piece: String, origin: Vector2i) -> void:
	_hint_cells = Field.cover(piece, origin)
	queue_redraw()


func clear_hint() -> void:
	_hint_cells = PackedInt32Array()


## Cells to outline gently (the tutorial's gap).
func set_target(cells: PackedInt32Array) -> void:
	_target_cells = cells
	queue_redraw()


# --- Playing a placement -------------------------------------------------------------

## Animates what RunState.place() returned.
func play_result(r: Dictionary) -> void:
	clear_hint()
	var placed: PackedInt32Array = r["cells"]
	for i: int in placed:
		_pop[i] = 0.0
	_sfx("place", randf_range(0.95, 1.05), -2.0)
	if not quiet: Haptics.tick()
	var pens: Array = r.get("pens", [])
	var end_t: float = _t + 0.25
	if not pens.is_empty():
		end_t = _capture(pens, placed, int(r.get("combo", 1)), int(r.get("points", 0)), r["vanished"])
	var ev_t: float = maxf(_t + 0.2, end_t - 0.2)
	for e: Dictionary in r.get("events", []):
		var c: int = int(e["cell"])
		match str(e["type"]):
			"gem":
				_spawn[c] = {"start": ev_t, "kind": "gem"}
				_at(ev_t, func() -> void: _sfx("gem", 1.3, -10.0))
			"rock":
				_spawn[c] = {"start": ev_t, "kind": "rock"}
				_at(ev_t + 0.18, func() -> void:
					_sfx("rock", 1.0, -3.0)
					_shake = maxf(_shake, 6.0))
			"hop":
				_hops[c] = {"from": int(e["from"]), "start": ev_t}
				_at(ev_t, func() -> void: _sfx("hop", randf_range(0.9, 1.15), -8.0))
		ev_t += 0.06
	_busy_until = maxf(_busy_until, maxf(end_t, ev_t))
	_at(_busy_until, func() -> void: animation_done.emit())
	queue_redraw()


func _capture(pens: Array, placed: PackedInt32Array, combo: int, points: int, vanished: PackedInt32Array) -> float:
	var last: float = _t
	var total_area: int = 0
	var note: int = 0
	var any_gems: bool = false
	for pen: Dictionary in pens:
		var cells: PackedInt32Array = pen["cells"]
		total_area += cells.size()
		var col: Color = Look.pen(int(pen["color"]), style_id)
		var dist: Dictionary = _wave(cells, placed)
		var far: int = 0
		for i: int in cells:
			far = maxi(far, int(dist[i]))
		var step: float = FILL_STEP * clampf(8.0 / float(maxi(1, far)), 0.45, 1.0)
		for i: int in cells:
			var start: float = _t + FILL_LEAD + float(dist[i]) * step
			_fills[i] = {"color": col, "start": start, "end": _t + FILL_LEAD + far * step + FILL_HOLD}
			var cell: int = i
			_at(start, func() -> void: _burst(cell_center(cell), col, 3, 160.0))
		# A rising pop for each wave front.
		for k: int in far + 1:
			if note < 16:
				var n: int = note
				_at(_t + FILL_LEAD + k * step, func() -> void: _pop_sfx(n))
			note += 1
		var done: float = _t + FILL_LEAD + far * step + 0.05
		last = maxf(last, done)
		var centre: Vector2 = Vector2.ZERO
		for i: int in cells:
			centre += cell_center(i)
		centre /= float(cells.size())
		var pts: int = int(pen["points"])
		var gems: PackedInt32Array = pen.get("gem_cells", PackedInt32Array())
		for g: int in gems:
			any_gems = true
			_gem_fx.append({"pos": cell_center(g), "start": _t + FILL_LEAD + float(dist[g]) * step})
		_at(done, func() -> void:
			_burst(centre, col, 18 + mini(cells.size(), 30), 420.0)
			_popup(centre, "+" + Catalog.thousands(pts), Style.INK if not Style.DARK else Color.WHITE, 44 + mini(cells.size(), 25))
			if not gems.is_empty():
				_popup(centre + Vector2(0, _cs * 0.75), "gem ×%d" % int(pow(2, gems.size())), Style.GEM, 30)
		)
	var big: bool = total_area >= 9
	_at(last, func() -> void:
		_sfx("big" if big else "capture", 1.0, -1.0)
		if not quiet: Haptics.success()
		_shake = clampf(3.0 + total_area * 0.7, 4.0, 18.0)
		if any_gems:
			_sfx("gem", 1.0, -4.0)
	)
	if combo >= 2:
		_at(last + 0.12, func() -> void:
			_sfx("combo", 1.0, -2.0)
			_popup(_panel.get_center() - Vector2(0, _cs * 2.2), "COMBO ×%s" % _mult_text(Scoring.combo_mult(combo)), Style.AMBER, 52)
		)
	var vt: float = last + 0.25
	for i: int in vanished:
		_vanish[i] = vt + randf_range(0.0, 0.08)
	if not vanished.is_empty():
		_at(vt, func() -> void: _sfx("vanish", 1.0, -6.0))
	return vt + 0.35


static func _mult_text(m: float) -> String:
	return str(int(m)) if is_equal_approx(m, roundf(m)) else ("%.1f" % m)


## Distance of every pen cell from the cells the piece covered (the paint spreads from there).
func _wave(cells: PackedInt32Array, placed: PackedInt32Array) -> Dictionary:
	var dist: Dictionary = {}
	var queue: Array[int] = []
	var inside: Dictionary = {}
	for i: int in cells:
		inside[i] = true
	for i: int in cells:
		for j: int in Field.ring8(i):
			if placed.has(j):
				dist[i] = 0
				queue.append(i)
				break
	if queue.is_empty():
		dist[cells[0]] = 0
		queue.append(cells[0])
	var head: int = 0
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		for j: int in Field.orth(i):
			if inside.has(j) and not dist.has(j):
				dist[j] = int(dist[i]) + 1
				queue.append(j)
	for i: int in cells:
		if not dist.has(i):
			dist[i] = 0
	return dist


func _sfx(name: String, pitch: float = 1.0, db: float = 0.0) -> void:
	if not quiet:
		Audio.play(name, pitch, db)


func _pop_sfx(n: int) -> void:
	if not quiet:
		Audio.pop(n)


func _at(time: float, fn: Callable) -> void:
	_sched.append({"at": time, "fn": fn})


func _burst(at: Vector2, col: Color, n: int, speed: float) -> void:
	for k: int in n:
		var ang: float = randf() * TAU
		var v: float = randf_range(0.35, 1.0) * speed
		_particles.append({
			"pos": at, "vel": Vector2(cos(ang), sin(ang)) * v - Vector2(0, speed * 0.35),
			"life": randf_range(0.45, 0.85), "age": 0.0, "size": randf_range(0.07, 0.15) * _cs,
			"color": col.lerp(Color.WHITE, randf_range(0.0, 0.4)), "spin": randf_range(-8.0, 8.0),
		})


func _popup(at: Vector2, text: String, col: Color, fs: int) -> void:
	_popups.append({"pos": at, "text": text, "color": col, "size": fs, "age": 0.0})


# --- Frame update ------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	var i: int = 0
	while i < _sched.size():
		if _t >= float(_sched[i]["at"]):
			var fn: Callable = _sched[i]["fn"]
			_sched.remove_at(i)
			if fn.is_valid():
				fn.call()
		else:
			i += 1
	for k: Variant in _pop.keys():
		_pop[k] = float(_pop[k]) + delta
		if float(_pop[k]) > 0.35:
			_pop.erase(k)
	for k: Variant in _fills.keys():
		if _t > float(_fills[k]["end"]) + FILL_FADE:
			_fills.erase(k)
	for k: Variant in _vanish.keys():
		if _t > float(_vanish[k]) + 0.35:
			_vanish.erase(k)
	for k: Variant in _spawn.keys():
		if _t > float(_spawn[k]["start"]) + 0.5:
			_spawn.erase(k)
	for k: Variant in _hops.keys():
		if _t > float(_hops[k]["start"]) + 0.4:
			_hops.erase(k)
	var j: int = 0
	while j < _gem_fx.size():
		if _t > float(_gem_fx[j]["start"]) + 0.9:
			_gem_fx.remove_at(j)
		else:
			j += 1
	j = 0
	while j < _particles.size():
		var p: Dictionary = _particles[j]
		p["age"] = float(p["age"]) + delta
		if float(p["age"]) >= float(p["life"]):
			_particles.remove_at(j)
			continue
		p["vel"] = (p["vel"] as Vector2) + Vector2(0, 900.0 * delta)
		p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
		j += 1
	j = 0
	while j < _popups.size():
		var q: Dictionary = _popups[j]
		q["age"] = float(q["age"]) + delta
		if float(q["age"]) > 1.3:
			_popups.remove_at(j)
		else:
			j += 1
	_shake *= exp(-9.0 * delta)
	if _shake < 0.2:
		_shake = 0.0
	queue_redraw()


# --- Drawing -------------------------------------------------------------------------

func _draw() -> void:
	if state == null:
		return
	if _shake > 0.0:
		draw_set_transform(Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake)
	var f: Field = state.field
	var gap: float = maxf(1.5, _cs * 0.06)
	var r_cell: int = int(_cs * 0.22)
	# The board tray.
	draw_style_box(UIKit.lip_box(Style.BOARD, int(_panel.size.x * 0.05), Style.BOARD.darkened(0.12), int(maxf(4.0, _cs * 0.12)), Vector2.ZERO), _panel)
	# Empty cells (with faint stains where pens once were).
	for i: int in Field.N * Field.N:
		var rc: Rect2 = cell_rect(i).grow(-gap)
		draw_style_box(UIKit.box(Style.CELL, r_cell), rc)
		if state.stain[i] > 0 and (f.cells[i] == Field.EMPTY or (wall_alpha <= 0.0 and f.cells[i] == Field.WALL)):
			draw_style_box(UIKit.box(Color(Look.pen(state.stain[i] - 1, style_id), stain_alpha), r_cell), rc)
		if paint.has(i):
			var pc: Color = paint[i]
			draw_texture_rect(Style.glow_texture(), rc.grow(_cs * 0.3), false, Color(pc, 0.18 * Look.glow(style_id)))
			draw_style_box(UIKit.box(pc, r_cell), rc)
	# Tutorial target.
	if not _target_cells.is_empty():
		var pulse: float = 0.5 + 0.5 * sin(_t * 5.0)
		for i: int in _target_cells:
			draw_style_box(UIKit.box(Color(Style.AMBER, 0.14 + 0.16 * pulse), r_cell, Color(Style.AMBER, 0.5 + 0.4 * pulse), 3), cell_rect(i).grow(-gap * 0.5))
	# Preview of pens this placement would close, with what they'd score.
	if not _preview.is_empty() and _ghost_valid:
		var pulse2: float = 0.5 + 0.5 * sin(_t * 7.0)
		var col: Color = Look.pen(state.pens_total, style_id)
		var total: int = 0
		var gems_total: int = 0
		var centre: Vector2 = Vector2.ZERO
		var n: int = 0
		var values: Array = []
		for reg: PackedInt32Array in _preview:
			var g: int = 0
			for i: int in reg:
				draw_style_box(UIKit.box(Color(col, 0.35 + 0.25 * pulse2), r_cell), cell_rect(i).grow(-gap))
				g += f.gems[i]
				centre += cell_center(i)
				n += 1
			gems_total += g
			values.append(Scoring.pen_points(reg.size(), g))
		total = Scoring.turn_points(Pieces.count(_ghost_piece), values)
		if n > 0:
			_text(centre / float(n), "+" + Catalog.thousands(total), int(_cs * 0.55), Style.INK if not Style.DARK else Color.WHITE, 1.0)
	# Captured pens filling with colour.
	for k: Variant in _fills:
		var e: Dictionary = _fills[k]
		var age: float = _t - float(e["start"])
		if age < 0.0:
			continue
		var grow: float = _ease_back(clampf(age / 0.22, 0.0, 1.0))
		var fade: float = 1.0 - clampf((_t - float(e["end"])) / FILL_FADE, 0.0, 1.0)
		var col2: Color = e["color"]
		var rc2: Rect2 = cell_rect(int(k)).grow(-gap)
		var sz: Vector2 = rc2.size * grow
		var rr: Rect2 = Rect2(rc2.get_center() - sz / 2.0, sz)
		var g2: float = Look.glow(style_id)
		if g2 > 0.0:
			draw_texture_rect(Style.glow_texture(), rr.grow(_cs * 0.35), false, Color(col2, 0.22 * g2 * fade))
		draw_style_box(UIKit.box(Color(col2, maxf(STAIN_ALPHA, fade)), r_cell), rr)
		var flash: float = 1.0 - clampf(age / 0.18, 0.0, 1.0)
		if flash > 0.0:
			draw_style_box(UIKit.box(Color(1, 1, 1, 0.8 * flash), r_cell), rr)
	# Walls: lips first, then the tops, then highlights, so neighbours join up.
	var lip_h: float = maxf(2.0, _cs * Look.wall_lip(style_id))
	var wall: Color = Color(Style.WALL, wall_alpha)
	var lip: Color = Color(Style.WALL.darkened(0.28), wall_alpha)
	var rad: int = int(_cs * Look.wall_radius(style_id))
	for pass_i: int in (2 if wall_alpha > 0.0 else 0):
		var col3: Color = lip if pass_i == 0 else wall
		var off: Vector2 = Vector2(0, lip_h) if pass_i == 0 else Vector2.ZERO
		for i: int in Field.N * Field.N:
			if f.cells[i] != Field.WALL:
				continue
			var rc3: Rect2 = _wall_rect(i, gap)
			draw_style_box(UIKit.box(col3, rad), Rect2(rc3.position + off, rc3.size))
			var x: int = i % Field.N
			if x < Field.N - 1 and f.cells[i + 1] == Field.WALL and not _pop.has(i) and not _pop.has(i + 1):
				var b: Rect2 = _wall_rect(i + 1, gap)
				draw_rect(Rect2(Vector2(rc3.get_center().x, rc3.position.y) + off, Vector2(b.get_center().x - rc3.get_center().x, rc3.size.y)), col3)
			if i + Field.N < Field.N * Field.N and f.cells[i + Field.N] == Field.WALL and not _pop.has(i) and not _pop.has(i + Field.N):
				var b2: Rect2 = _wall_rect(i + Field.N, gap)
				draw_rect(Rect2(Vector2(rc3.position.x, rc3.get_center().y) + off, Vector2(rc3.size.x, b2.get_center().y - rc3.get_center().y)), col3)
	for i: int in (Field.N * Field.N if wall_alpha > 0.0 else 0):
		if f.cells[i] == Field.WALL:
			var rc4: Rect2 = _wall_rect(i, gap)
			draw_style_box(UIKit.box(Color(1, 1, 1, 0.22), int(_cs * 0.06)), Rect2(rc4.position + rc4.size * Vector2(0.16, 0.14), rc4.size * Vector2(0.36, 0.13)))
	# Walls shrinking away after a capture.
	for k: Variant in _vanish:
		var cell: int = int(k)
		if f.cells[cell] != Field.EMPTY:
			continue
		var age2: float = _t - float(_vanish[k])
		var s: float = 1.0 if age2 < 0.0 else 1.0 - _ease_in(clampf(age2 / 0.3, 0.0, 1.0))
		if s <= 0.01:
			continue
		var rc5: Rect2 = cell_rect(cell).grow(-gap)
		var sz2: Vector2 = rc5.size * s
		var rr2: Rect2 = Rect2(rc5.get_center() - sz2 / 2.0 + Vector2(0, (1.0 - s) * -_cs * 0.2), sz2)
		draw_style_box(UIKit.box(Color(lip, s), rad), Rect2(rr2.position + Vector2(0, lip_h * s), rr2.size))
		draw_style_box(UIKit.box(Color(wall, s), rad), rr2)
	# Rocks.
	for i: int in Field.N * Field.N:
		if f.cells[i] == Field.ROCK:
			_draw_rock(i, gap)
	# Gems.
	for i: int in Field.N * Field.N:
		if f.gems[i] != 0:
			_draw_gem_at(i)
	for e: Dictionary in _gem_fx:
		var age3: float = _t - float(e["start"])
		if age3 < 0.0:
			_draw_gem(e["pos"], 1.0, 1.0)
		else:
			var k3: float = clampf(age3 / 0.9, 0.0, 1.0)
			_draw_gem((e["pos"] as Vector2) - Vector2(0, _cs * 1.4 * _ease_out(k3)), 1.0 + 0.5 * k3, 1.0 - k3)
	# The ghost of the piece being dragged.
	if not _ghost_piece.is_empty():
		var gc: Color = Color(wall, 0.55) if _ghost_valid else Color(Style.ERROR, 0.4)
		for c: Vector2i in Pieces.cells(_ghost_piece):
			var x2: int = _ghost_origin.x + c.x
			var y2: int = _ghost_origin.y + c.y
			if x2 < 0 or y2 < 0 or x2 >= Field.N or y2 >= Field.N:
				continue
			draw_style_box(UIKit.box(gc, rad), cell_rect(y2 * Field.N + x2).grow(-gap))
	# A hint: where the bot would put a piece.
	if not _hint_cells.is_empty():
		var hp: float = 0.5 + 0.5 * sin(_t * 6.0)
		for i: int in _hint_cells:
			draw_style_box(UIKit.box(Color(Style.GOLD, 0.25 + 0.25 * hp), rad, Style.GOLD, 4), cell_rect(i).grow(-gap * 0.6))
	# Confetti and popups on top.
	for p: Dictionary in _particles:
		var a: float = 1.0 - float(p["age"]) / float(p["life"])
		var ps: float = float(p["size"])
		draw_set_transform((p["pos"] as Vector2) + (Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake if _shake > 0.0 else Vector2.ZERO), float(p["age"]) * float(p["spin"]))
		draw_rect(Rect2(-ps / 2.0, -ps / 2.0, ps, ps * 0.6), Color(p["color"], a))
	draw_set_transform(Vector2.ZERO)
	for q: Dictionary in _popups:
		var age4: float = float(q["age"])
		var a2: float = 1.0 - clampf((age4 - 0.8) / 0.5, 0.0, 1.0)
		var sc: float = _ease_back(clampf(age4 / 0.25, 0.0, 1.0))
		_text((q["pos"] as Vector2) - Vector2(0, age4 * 50.0), str(q["text"]), int(float(q["size"]) * sc), q["color"], a2)


func _wall_rect(i: int, gap: float) -> Rect2:
	var rc: Rect2 = cell_rect(i).grow(-gap * 0.5)
	if _pop.has(i):
		var k: float = clampf(float(_pop[i]) / 0.3, 0.0, 1.0)
		var s: float = 1.0 + 0.2 * (1.0 - k) * (1.0 - k)
		var sz: Vector2 = rc.size * s
		return Rect2(rc.get_center() - sz / 2.0, sz)
	return rc


func _draw_rock(i: int, gap: float) -> void:
	var rc: Rect2 = cell_rect(i).grow(-gap * 1.2)
	var drop: float = 0.0
	var a: float = 1.0
	if _spawn.has(i) and str(_spawn[i]["kind"]) == "rock":
		var k: float = clampf((_t - float(_spawn[i]["start"])) / 0.25, 0.0, 1.0)
		drop = -(1.0 - k * k) * _cs * 1.5
		a = k
	rc.position.y += drop
	var lip_h: float = maxf(2.0, _cs * 0.1)
	draw_style_box(UIKit.box(Color(Style.ROCK.darkened(0.3), a), int(_cs * 0.32)), Rect2(rc.position + Vector2(0, lip_h), rc.size))
	draw_style_box(UIKit.box(Color(Style.ROCK, a), int(_cs * 0.32)), rc)
	var c: Vector2 = rc.get_center()
	draw_circle(c + Vector2(-_cs * 0.14, -_cs * 0.08), _cs * 0.07, Color(Style.ROCK.darkened(0.22), a), true, -1.0, true)
	draw_circle(c + Vector2(_cs * 0.12, _cs * 0.1), _cs * 0.05, Color(Style.ROCK.darkened(0.22), a), true, -1.0, true)
	draw_circle(c + Vector2(_cs * 0.08, -_cs * 0.16), _cs * 0.035, Color(Style.ROCK.lightened(0.25), a), true, -1.0, true)


func _draw_gem_at(i: int) -> void:
	var pos: Vector2 = cell_center(i)
	var scale_k: float = 1.0
	if _hops.has(i):
		var k: float = clampf((_t - float(_hops[i]["start"])) / 0.35, 0.0, 1.0)
		var from: Vector2 = cell_center(int(_hops[i]["from"]))
		pos = from.lerp(pos, k) - Vector2(0, sin(k * PI) * _cs * 0.6)
	if _spawn.has(i) and str(_spawn[i]["kind"]) == "gem":
		scale_k = _ease_back(clampf((_t - float(_spawn[i]["start"])) / 0.35, 0.0, 1.0))
	pos.y += sin(_t * 3.0 + float(i)) * _cs * 0.035
	_draw_gem(pos, scale_k, 1.0)


func _draw_gem(c: Vector2, s: float, a: float) -> void:
	if s <= 0.01 or a <= 0.01:
		return
	var h: float = _cs * 0.36 * s
	draw_texture_rect(Style.glow_texture(), Rect2(c - Vector2(h, h) * 1.8, Vector2(h, h) * 3.6), false, Color(Style.GEM, 0.35 * a))
	var top: Vector2 = c + Vector2(0, -h * 0.85)
	var pts: PackedVector2Array = PackedVector2Array([
		c + Vector2(-h * 0.55, -h * 0.85), c + Vector2(h * 0.55, -h * 0.85), c + Vector2(h, -h * 0.3),
		c + Vector2(0, h), c + Vector2(-h, -h * 0.3)])
	draw_colored_polygon(pts, Color(Style.GEM.darkened(0.25), a))
	var inner: PackedVector2Array = PackedVector2Array([
		c + Vector2(-h * 0.5, -h * 0.78), c + Vector2(h * 0.5, -h * 0.78), c + Vector2(h * 0.86, -h * 0.3),
		c + Vector2(0, h * 0.82), c + Vector2(-h * 0.86, -h * 0.3)])
	draw_colored_polygon(inner, Color(Style.GEM, a))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-h * 0.5, -h * 0.78), top + Vector2(h * 0.15, 0), c + Vector2(-h * 0.2, -h * 0.3), c + Vector2(-h * 0.86, -h * 0.3)]), Color(1, 1, 1, 0.45 * a))
	draw_line(c + Vector2(-h * 0.86, -h * 0.3), c + Vector2(h * 0.86, -h * 0.3), Color(1, 1, 1, 0.5 * a), maxf(1.0, h * 0.08), true)
	var tw: float = 0.5 + 0.5 * sin(_t * 4.0 + c.x)
	draw_circle(c + Vector2(h * 0.35, -h * 0.55), h * 0.09 * (0.6 + tw), Color(1, 1, 1, 0.9 * a), true, -1.0, true)


func _text(at: Vector2, text: String, fs: int, col: Color, alpha: float) -> void:
	if fs <= 2 or alpha <= 0.01:
		return
	var f: Font = UIKit.font(800)
	var w: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p: Vector2 = Vector2(at.x - w / 2.0, at.y + (f.get_ascent(fs) - f.get_descent(fs)) / 2.0)
	var outline: Color = Style.CELL if not Style.DARK else Style.BOARD.darkened(0.4)
	draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(4, fs / 6), Color(outline, alpha))
	draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, alpha))


static func _ease_back(x: float) -> float:
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3) + c1 * pow(x - 1.0, 2)


static func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3)


static func _ease_in(x: float) -> float:
	return x * x * x
