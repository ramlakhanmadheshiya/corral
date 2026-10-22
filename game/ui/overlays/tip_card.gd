class_name TipCard
extends Overlay
## The tip jar, like Single Shot's: four quick amounts, or pick your own with
## − / + (one amount at a time) and a slider that runs from the smallest tip to
## the largest. Every amount is its own Google Play product and every price shown
## is the player's own currency (Store.price), so nothing here is typed in rupees.

var _status: Label
var _price: Label
var _slider: HSlider
var _custom: Button
var _presets: Dictionary = {}
var _amounts: Array = Store.tip_amounts()
var _index: int = 0


func build() -> void:
	name = "Tips"
	add_title("Tip jar")
	body.add_child(UIKit.para("Say thanks, as often as you like. A tip opens nothing new: it all goes into making the next chapter.", Style.SIZE_SMALL))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	body.add_child(grid)
	for rupees: int in Store.TIP_PRESETS:
		var b: Button = UIKit.button(Store.price("tip_%d" % rupees), "soft", Style.AMBER, 84, 28)
		b.name = "Tip_%d" % rupees
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: _tip(rupees))
		grid.add_child(b)
		_presets[rupees] = b
	body.add_child(UIKit.caption("Or pick your own"))
	var row: HBoxContainer = UIKit.hbox(14)
	var minus: Button = UIKit.icon_button("minus", 68)
	minus.name = "TipMinus"
	minus.pressed.connect(func() -> void: _select(_index - 1))
	row.add_child(minus)
	_price = UIKit.label("", 34, Style.INK, 600)
	_price.name = "TipPrice"
	_price.custom_minimum_size = Vector2(220, 76)
	_price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_price)
	var plus: Button = UIKit.icon_button("plus", 68)
	plus.name = "TipPlus"
	plus.pressed.connect(func() -> void: _select(_index + 1))
	row.add_child(plus)
	body.add_child(row)
	_slider = HSlider.new()
	_slider.name = "TipSlider"
	_slider.min_value = 0
	_slider.max_value = _amounts.size() - 1
	_slider.step = 1
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIKit.style_slider(_slider)
	_index = maxi(0, _amounts.find(Store.TIP_DEFAULT))
	_slider.value = _index
	_slider.value_changed.connect(func(v: float) -> void:
		if int(v) != _index:
			_index = int(v)
			_refresh()
	)
	body.add_child(_slider)
	_custom = UIKit.button("", "primary", Style.AMBER, 88, 28, "art:heart")
	_custom.name = "TipCustom"
	_custom.pressed.connect(func() -> void: _tip(selected()))
	body.add_child(_custom)
	_status = UIKit.para(_thanks(), Style.SIZE_SMALL, Style.AMBER)
	_status.name = "Status"
	body.add_child(_status)
	body.add_child(UIKit.refund_note())
	Store.purchase_finished.connect(func(ok: bool, msg: String, id: String) -> void:
		if is_inside_tree() and (Store.is_tip(id) or id.is_empty()):
			_status.text = msg if not ok else _thanks()
			if ok:
				Audio.play("unlock", 1.0, -3.0)
	)
	# Google Play's prices (in the player's currency) replace the fallbacks live.
	Store.price_updated.connect(func(id: String, _p: String) -> void:
		if is_inside_tree() and Store.is_tip(id):
			_refresh()
	)
	_refresh()


## The selected tip amount (rupees, as in the product id).
func selected() -> int:
	return int(_amounts[_index])


func _select(i: int) -> void:
	_index = clampi(i, 0, _amounts.size() - 1)
	_slider.set_value_no_signal(_index)
	_refresh()


func _refresh() -> void:
	var p: String = Store.price("tip_%d" % selected())
	_price.text = p
	_custom.text = "Tip %s" % p
	for rupees: int in _presets:
		(_presets[rupees] as Button).text = Store.price("tip_%d" % rupees)


func _tip(rupees: int) -> void:
	_status.text = "Opening Google Play…"
	Store.buy("tip_%d" % rupees)


func _thanks() -> String:
	var n: int = Profile.tips_given()
	return "" if n == 0 else "You've tipped %d %s. Thank you ♥" % [n, "time" if n == 1 else "times"]
