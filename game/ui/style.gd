class_name Style
extends RefCounted
## Design tokens: colours, sizes and shared textures. Soft pastel paper, chunky
## rounded walls, pens that fill with colour.

## Theme-driven colours. They start as the "Original" daytime palette and are
## replaced as a set by Look.apply() when the theme or appearance changes, so
## the whole app follows: sky, cards, buttons, panels, board and walls.
static var INK: Color = Color("3B3355")
static var MUTED: Color = Color("8A82A6")
static var CARD: Color = Color("FFFDFB")
static var CARD_EDGE: Color = Color(0.23, 0.2, 0.33, 0.08)
static var FIELD: Color = Color(0.23, 0.2, 0.33, 0.06)
## Raised surfaces: soft buttons, shop rows, chips.
static var SURFACE: Color = Color("FFFFFF")
## The darker edge under raised surfaces.
static var LIP: Color = Color("E6D7CB")
## Flat panels: the score strip, the daily card.
static var PANEL: Color = Color("FFF8F1")
## The board: its tray, empty cells, and the walls the player places.
static var BOARD: Color = Color("F3E6DA")
static var CELL: Color = Color("FFFAF4")
static var WALL: Color = Color("6C67B8")
static var ROCK: Color = Color("A39BB3")
## The accent (buttons, highlights). Named AMBER for the shared UI kit.
static var AMBER: Color = Color("FF7A6B")
static var DIM: Color = Color(0.18, 0.14, 0.28, 0.45)
static var DEFAULT_SKY_TOP: Color = Color("FFF6EC")
static var DEFAULT_SKY_BOTTOM: Color = Color("F8E1D3")
## False for light themes (dark text).
static var DARK: bool = false

## Fixed colours that read on any theme.
const PAPER: Color = Color("FFF8EF")
const PAPER_INK: Color = Color("2A2244")
const GOLD: Color = Color("FFC94D")
const GEM: Color = Color("3FD0E6")
const ERROR: Color = Color("FF5D6C")
const SUCCESS: Color = Color("3FC283")

## Every round icon button in a top bar (Back, Settings, Shop) is this size on
## every screen, so they never change size between pages.
const TOP_BUTTON: float = 84.0
## Every card's close (X) button is this size.
const CLOSE_BUTTON: float = 72.0

const GUTTER: int = 24
const MAX_WIDTH: int = 720
const RADIUS: int = 28

const SIZE_HERO: int = 76
const SIZE_H1: int = 48
const SIZE_H2: int = 36
const SIZE_BODY: int = 28
const SIZE_SMALL: int = 23
const SIZE_CAPTION: int = 19


static var _glow: Texture2D


static func clear_caches() -> void:
	_glow = null


## Soft round light, white in the middle fading to nothing, tinted by modulate.
static func glow_texture() -> Texture2D:
	if _glow == null:
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.45))
		var tex: GradientTexture2D = GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 128
		tex.height = 128
		_glow = tex
	return _glow
