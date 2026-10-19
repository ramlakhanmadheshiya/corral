class_name Look
extends RefCounted
## The player's chosen look: a colour theme (sky, board and accent; Theme pack)
## and a pen style (wall shape and the colours pens fill with; Style pack).
## "original" and "classic" are free. The Original theme follows Settings ›
## Appearance (Auto follows the phone, or always Dark / always Light).

const THEMES: Dictionary = {
	"mint": {"name": "Mint", "top": "#EEFBF4", "bottom": "#CDEFDD", "accent": "#2FA77A", "wall": "#3F8F72", "ink": "#21423A", "light": true},
	"peach": {"name": "Peach", "top": "#FFF3EC", "bottom": "#FFD9C7", "accent": "#F2724F", "wall": "#C9634A", "ink": "#4A2A22", "light": true},
	"lilac": {"name": "Lilac", "top": "#F6F1FF", "bottom": "#DDD1FA", "accent": "#8A63E8", "wall": "#7253C4", "ink": "#33275A", "light": true},
	"sky": {"name": "Sky", "top": "#EEF7FF", "bottom": "#C9E3F8", "accent": "#2F86D9", "wall": "#3D6FA8", "ink": "#1E3A55", "light": true},
	"sand": {"name": "Sand", "top": "#FBF6EA", "bottom": "#EBDDBE", "accent": "#C9853A", "wall": "#8C6A44", "ink": "#3D3122", "light": true},
	"night": {"name": "Night", "top": "#262A44", "bottom": "#121426", "accent": "#8CA8FF", "wall": "#B9C4FF", "ink": "#EEF1FF"},
	"forest": {"name": "Forest", "top": "#22382E", "bottom": "#0E1813", "accent": "#7BD39B", "wall": "#A8E0BC", "ink": "#EAF6EE"},
	"ocean": {"name": "Ocean", "top": "#173A52", "bottom": "#08141E", "accent": "#5CC8F2", "wall": "#9ED9F2", "ink": "#E6F4FB"},
	"plum": {"name": "Plum", "top": "#3A2342", "bottom": "#160C1A", "accent": "#F28BC8", "wall": "#E7B6E0", "ink": "#FBEAF5"},
	"ember": {"name": "Ember", "top": "#3E2018", "bottom": "#130806", "accent": "#FF8F5A", "wall": "#FFC4A3", "ink": "#FFEDE3"},
}

## Pen styles: how walls look and the colours captured pens fill with.
## radius: wall corner rounding (fraction of a cell); lip: the chunky darker edge;
## glow: soft light around fills.
const STYLES: Dictionary = {
	"classic": {"name": "Classic", "radius": 0.3, "lip": 0.12, "glow": 0.6, "colors": ["#7FDDB8", "#FFB08A", "#B9A6FF", "#8CCBFF", "#FFD86B", "#FF9EC7"]},
	"candy": {"name": "Candy", "radius": 0.5, "lip": 0.14, "glow": 0.8, "colors": ["#FF8FB1", "#7FD8FF", "#B9F18C", "#FFD36E", "#C79BFF", "#FF9E7A"], "wall": "#FF6F9C"},
	"stone": {"name": "Stone", "radius": 0.14, "lip": 0.16, "glow": 0.3, "colors": ["#A9C79A", "#D9B98C", "#9FB4C7", "#C7A0A0", "#C9C28E", "#A7A2C2"], "wall": "#8A8496"},
	"neon": {"name": "Neon", "radius": 0.34, "lip": 0.06, "glow": 1.6, "colors": ["#00E5A8", "#FF4FA3", "#4FC3FF", "#FFE14F", "#A77BFF", "#FF7B3D"], "wall": "#2E2A5C"},
	"wood": {"name": "Fence", "radius": 0.2, "lip": 0.18, "glow": 0.4, "colors": ["#9BD77A", "#F2C46B", "#7FC6A4", "#E8A27C", "#B8D86E", "#D9B3E0"], "wall": "#A9744F"},
	"glass": {"name": "Glass", "radius": 0.36, "lip": 0.04, "glow": 0.9, "colors": ["#BFE8F7", "#D7F2E6", "#E3DAFA", "#FAD9E6", "#FAEED2", "#D2F5F7"], "wall": "#8FC9E0"},
	"ink": {"name": "Ink", "radius": 0.1, "lip": 0.08, "glow": 0.2, "colors": ["#4F6DB8", "#B8564F", "#4F9E8A", "#B8954F", "#7D57B0", "#3F8FB8"], "wall": "#2C2A3A"},
}


static func theme_id() -> String:
	var id: String = str(Profile.setting("theme", "original"))
	return id if THEMES.has(id) and Profile.owns("theme_pack") else "original"


static func style_id() -> String:
	var id: String = str(Profile.setting("style", "classic"))
	return id if STYLES.has(id) and (id == "classic" or Profile.owns("style_pack")) else "classic"


## Sets every Style colour from the chosen theme. Called at start-up, on every
## screen change (so an ended trial reverts) and whenever the look changes.
static func apply() -> void:
	var t: String = theme_id()
	if t == "original":
		if original_is_light():
			_set_palette(Color("FFF6EC"), Color("F8E1D3"), Color("FF7A6B"), false, Color("3B3355"), Color("6C67B8"))
		else:
			_set_palette(Color("2C2B4A"), Color("16152A"), Color("FF8C7A"), true, Color("F4F0FF"), Color("C9C2FF"))
	else:
		var th: Dictionary = THEMES[t]
		var light: bool = bool(th.get("light", false))
		_set_palette(Color(th["top"]), Color(th["bottom"]), Color(th["accent"]), not light, Color(th["ink"]), Color(th["wall"]))
	var st: Dictionary = STYLES[style_id()]
	if st.has("wall"):
		var w: Color = Color(str(st["wall"]))
		# Very dark walls need lifting on dark themes, very light ones darkening on light themes.
		if Style.DARK and w.get_luminance() < 0.25:
			w = w.lightened(0.45)
		Style.WALL = w


static func _set_palette(top: Color, bottom: Color, accent: Color, dark: bool, ink: Color, wall: Color) -> void:
	Style.DARK = dark
	Style.DEFAULT_SKY_TOP = top
	Style.DEFAULT_SKY_BOTTOM = bottom
	Style.AMBER = accent
	Style.INK = ink
	Style.WALL = wall
	if dark:
		var mid: Color = top.lerp(bottom, 0.4)
		Style.MUTED = ink.lerp(top, 0.38)
		Style.CARD = mid.lightened(0.08)
		Style.SURFACE = mid.lightened(0.15)
		Style.PANEL = mid.lightened(0.05)
		Style.LIP = bottom.darkened(0.5)
		Style.FIELD = Color(ink, 0.07)
		Style.CARD_EDGE = Color(1, 1, 1, 0.10)
		Style.DIM = Color(bottom.darkened(0.6), 0.62)
		Style.BOARD = bottom.lerp(top, 0.25).darkened(0.18)
		Style.CELL = top.lerp(bottom, 0.15).lightened(0.06)
		Style.ROCK = Color("7E7891")
	else:
		Style.MUTED = ink.lerp(top, 0.45)
		Style.CARD = top.lerp(Color.WHITE, 0.7)
		Style.SURFACE = Color.WHITE
		Style.PANEL = top.lerp(Color.WHITE, 0.5)
		Style.LIP = bottom.darkened(0.12)
		Style.FIELD = Color(ink, 0.06)
		Style.CARD_EDGE = Color(ink, 0.10)
		Style.DIM = Color(ink.darkened(0.3), 0.42)
		Style.BOARD = bottom.lerp(top, 0.35).darkened(0.04)
		Style.CELL = top.lerp(Color.WHITE, 0.6)
		Style.ROCK = Color("A39BB3")


## Settings › Appearance for the Original colours: "auto" follows the phone's
## dark mode, "dark" or "light" always.
static func appearance() -> String:
	var a: String = str(Profile.setting("appearance", "auto"))
	return a if a in ["auto", "dark", "light"] else "auto"


static func original_is_light() -> bool:
	match appearance():
		"light":
			return true
		"dark":
			return false
	return not (DisplayServer.is_dark_mode_supported() and DisplayServer.is_dark_mode())


static func theme_ids() -> Array:
	return ["original"] + THEMES.keys()


static func style_ids() -> Array:
	return STYLES.keys()


static func theme_name(id: String) -> String:
	return "Original" if id == "original" else str(THEMES.get(id, {}).get("name", id))


static func style_name(id: String) -> String:
	return str(STYLES.get(id, {}).get("name", id))


## Sky colours for a chapter (or the home screen when chapter is empty). Each
## chapter tints the Original sky with its own hue.
static func sky(chapter: Dictionary) -> Array[Color]:
	if theme_id() != "original" or chapter.is_empty() or not chapter.has("accent"):
		return [Style.DEFAULT_SKY_TOP, Style.DEFAULT_SKY_BOTTOM]
	var hue: Color = chapter["accent"]
	if Style.DARK:
		return [Style.DEFAULT_SKY_TOP.lerp(hue, 0.18), Style.DEFAULT_SKY_BOTTOM.lerp(hue, 0.08)]
	return [hue.lerp(Color.WHITE, 0.9), hue.lerp(Color.WHITE, 0.72)]


static func accent(chapter: Dictionary) -> Color:
	if theme_id() != "original" or chapter.is_empty() or not chapter.has("accent"):
		return Style.AMBER
	var a: Color = chapter["accent"]
	# Deeper on daytime skies so captions and bars keep their contrast.
	return a.darkened(0.12) if not Style.DARK else a.lightened(0.1)


## Colour of the i-th pen fill in the current (or a given) style.
static func pen(i: int, style: String = "") -> Color:
	var s: Dictionary = STYLES[style if STYLES.has(style) else style_id()]
	var cols: Array = s["colors"]
	return Color(str(cols[posmod(i, cols.size())]))


static func wall_radius(style: String = "") -> float:
	return float(STYLES[style if STYLES.has(style) else style_id()]["radius"])


static func wall_lip(style: String = "") -> float:
	return float(STYLES[style if STYLES.has(style) else style_id()]["lip"])


static func glow(style: String = "") -> float:
	return float(STYLES[style if STYLES.has(style) else style_id()]["glow"])


## Wall colour for a style preview (the live board uses Style.WALL).
static func style_wall(style: String) -> Color:
	var st: Dictionary = STYLES.get(style, {})
	return Color(str(st["wall"])) if st.has("wall") else Style.WALL
