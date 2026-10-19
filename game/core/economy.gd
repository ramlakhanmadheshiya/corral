class_name Economy
extends RefCounted
## Every coin amount and price in one place.

const START_COINS: int = 100
## Challenge levels: first clear, and each star earned for the first time.
const LEVEL_REWARD: int = 10
const STAR_REWARD: int = 5
## Clearing every level of a chapter.
const CHAPTER_BONUS: int = 100
const DAILY_REWARD: int = 30
const STREAK_BONUS_PER_DAY: int = 5
const STREAK_BONUS_CAP_DAYS: int = 6
## Classic: one coin per CLASSIC_POINTS_PER_COIN points, up to CLASSIC_COIN_CAP a run,
## plus a bonus for a new best score.
const CLASSIC_POINTS_PER_COIN: int = 400
const CLASSIC_COIN_CAP: int = 40
const NEW_BEST_BONUS: int = 20

## Hint: shows the best place for a piece. Shuffle: new pieces in the tray
## (Classic). Continue: clears walls and deals a fresh tray once per run (Classic).
const HINT_COST: int = 30
const SHUFFLE_COST: int = 50
const CONTINUE_COST: int = 150
## Free hints each day (Supporters get more).
const FREE_HINTS: int = 1
const SUPPORTER_FREE_HINTS: int = 3
## "Free coins" videos in the shop.
const VIDEO_COINS: int = 25
const VIDEO_COINS_PER_DAY: int = 5
## Level keys from videos.
const VIDEO_KEYS_PER_DAY: int = 3
## Cosmetic pack trial from a video.
const TRIAL_SECONDS: int = 3600


static func classic_coins(score: int, new_best: bool) -> int:
	return clampi(score / CLASSIC_POINTS_PER_COIN, 0, CLASSIC_COIN_CAP) + (NEW_BEST_BONUS if new_best and score > 0 else 0)


## Coins for finishing a daily on day `streak` of a streak (streak >= 1).
static func daily_reward(streak: int) -> int:
	return DAILY_REWARD + STREAK_BONUS_PER_DAY * clampi(streak - 1, 0, STREAK_BONUS_CAP_DAYS)
