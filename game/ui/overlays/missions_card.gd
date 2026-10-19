class_name MissionsCard
extends Overlay
## Today's three missions (the same for everyone), their progress and coins.
## Each pays out by itself the moment it is done.


func build() -> void:
	name = "MissionsCard"
	add_title("Missions")
	body.add_child(UIKit.caption("New missions every day"))
	for m: Dictionary in Profile.missions():
		body.add_child(_row(m))
	var now: Dictionary = Time.get_time_dict_from_system()
	var left: int = 86400 - (int(now["hour"]) * 3600 + int(now["minute"]) * 60 + int(now["second"]))
	body.add_child(UIKit.para("Fresh missions in %dh %02dm. Coins are added as soon as a mission is done." % [left / 3600, (left % 3600) / 60], Style.SIZE_CAPTION))


func _row(m: Dictionary) -> PanelContainer:
	var done: bool = bool(m["done"])
	var row: HBoxContainer = UIKit.hbox(16, BoxContainer.ALIGNMENT_BEGIN)
	if done:
		row.add_child(UIKit.art_rect("check", 50))
	else:
		row.add_child(UIKit.icon_rect("target", 46, Style.AMBER))
	var mid: VBoxContainer = UIKit.vbox(6)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t: Label = UIKit.label(str(m["text"]), Style.SIZE_BODY - 3, Style.INK, 600, HORIZONTAL_ALIGNMENT_LEFT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(t)
	if not done:
		mid.add_child(UIKit.progress_bar(float(m["value"]) / float(maxi(1, int(m["target"]))), Style.AMBER, 10))
		mid.add_child(UIKit.label("%s / %s" % [Catalog.thousands(int(m["value"])), Catalog.thousands(int(m["target"]))], Style.SIZE_CAPTION, Style.MUTED, 500, HORIZONTAL_ALIGNMENT_LEFT))
	row.add_child(mid)
	var right: HBoxContainer = UIKit.hbox(6)
	right.add_child(UIKit.art_rect("coin", 30))
	right.add_child(UIKit.label("Done" if done else "+%d" % int(m["reward"]), Style.SIZE_SMALL, Style.SUCCESS if done else Style.INK, 700))
	row.add_child(right)
	return UIKit.panel(row, Color(Style.INK, 0.06 if done else 0.04), 26, Vector2(20, 14))
