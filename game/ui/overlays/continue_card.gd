class_name ContinueCard
extends Overlay
## Classic, when no piece fits: one continue per run, only if the player wants
## it, for a short video or for coins. It clears the walls nearest the middle and
## deals a fresh tray. "No thanks" ends the run.

var play: Node
var _status: Label


func _init() -> void:
	super._init()
	dismissable = false


func build() -> void:
	name = "Continue"
	body.add_child(UIKit.art_rect("continue", 96))
	body.add_child(UIKit.label("Out of room", Style.SIZE_H1, Style.INK, 600))
	body.add_child(UIKit.label("%s points so far" % Catalog.thousands(play.state.score), Style.SIZE_BODY, Style.AMBER, 700))
	body.add_child(UIKit.para("None of your pieces fit. Keep this run going once: %d walls near the middle disappear and three fresh pieces arrive." % RunState.CONTINUE_CLEARS, Style.SIZE_SMALL + 1, Style.INK))
	_status = UIKit.para("", Style.SIZE_SMALL, Style.MUTED)
	_status.name = "Status"
	if AdManager.provider != null:
		var watch: Button = UIKit.button("Continue with a video", "primary", Style.AMBER, 92, 28, "art:watch")
		watch.name = "WatchContinue"
		watch.pressed.connect(func() -> void:
			if not AdManager.rewarded_ready():
				_status.text = "No video available right now. Try again in a moment, or use coins."
				return
			AdManager.show_rewarded(func(ok: bool) -> void:
				if not is_inside_tree():
					return
				if ok:
					_resume()
				else:
					_status.text = "The video was closed early, so the run can't continue."
			)
		)
		body.add_child(watch)
	var coins: Button = UIKit.button("Continue for %d coins" % Economy.CONTINUE_COST, "soft" if AdManager.provider != null else "primary", Style.AMBER, 88, 26, "art:coin")
	coins.name = "CoinContinue"
	coins.disabled = Profile.coins() < Economy.CONTINUE_COST
	coins.pressed.connect(func() -> void:
		if Profile.spend(Economy.CONTINUE_COST):
			Audio.play("coin")
			_resume()
	)
	body.add_child(coins)
	if Profile.coins() < Economy.CONTINUE_COST:
		body.add_child(UIKit.para("You have %d coins." % Profile.coins(), Style.SIZE_CAPTION))
	body.add_child(_status)
	var no: Button = UIKit.button("No thanks", "ghost", Style.AMBER, 76, 24)
	no.name = "NoThanks"
	no.pressed.connect(func() -> void:
		close()
		play.finish_run()
	)
	body.add_child(no)


func _resume() -> void:
	close()
	Audio.play("unlock", 1.0, -3.0)
	play.continue_run()


func on_back() -> void:
	close()
	play.finish_run()
