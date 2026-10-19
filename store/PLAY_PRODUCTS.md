# Google Play products for Corral

Every id below must exist in the Play Console (Monetize › Products › In-app products)
before the shop works in a Play build. Prices are set in the Console; the game shows
Google Play's localised price and falls back to the regional prices in
`game/autoload/store.gd` until Play answers. `python3 store/play_products.py create KEY.json`
creates them all (see `store/PLAY_CONSOLE.md`); `store/products.csv` lists them.

| Product id | Type | What it gives | Suggested price |
|---|---|---|---|
| `complete_pack` | One-time (non-consumable) | Everything: no banner ads or videos between games, 3 free hints a day, all 10 themes and 6 pen styles, plus 1,000 coins and 5 level keys (granted once) | ₹449 / $5.99 |
| `supporter_pack` | One-time | No banner ads or videos between games, 3 free hints a day | ₹249 / $2.99 |
| `theme_pack` | One-time | 10 colour themes (1-hour trial from a video) | ₹149 / $1.99 |
| `style_pack` | One-time | 6 pen styles: wall looks and pen colours (1-hour trial from a video) | ₹149 / $1.99 |
| `coins_100` … `coins_6000` | Consumable | 100, 250, 300, 500, 750, 1,000, 1,500, 2,000, 2,500 or 6,000 coins | ₹29 … ₹449 |
| `keys_1` … `keys_10` | Consumable | 1–10 level keys (₹30 / $0.49 each, 10% off for 5+); each opens a locked challenge | ₹30 × n |
| `tip_10` … `tip_1000` (steps of 10) | Consumable | A tip: nothing unlocked (priced in rupees) | ₹10 × n |

Consumables are consumed after granting, so they can be bought again. One-time packs
are acknowledged and restored on every launch and from **Restore purchases**.

## What coins buy

| Use | Price | Free option |
|---|---|---|
| Hint (outlines a good spot) | 30 coins | First hint each day (3 for Supporters); a video when out of coins |
| Shuffle (Classic: new pieces) | 50 coins | A video when out of coins |
| Continue (Classic, once per run: clears 14 walls, fresh tray) | 150 coins | A video, only if the player asks |

## Ads (AdMob)

Set three repository secrets so CI builds use the real units (otherwise Google's test
units are used): `ADMOB_APP_ID`, `ADMOB_BANNER_ID` (anchored adaptive banner) and
`ADMOB_REWARDED_ID` (rewarded video) and, optionally, `ADMOB_INTERSTITIAL_ID` (the short
video after every fifth finished game; without it Google's test unit is used). Banners
show at the bottom of every screen except for Supporters, with their space reserved so
the board never jumps; rewarded videos only play when the player asks (the one continue
per run, a hint or shuffle when out of coins, free coins, a level key, or a 1-hour pack
trial). A short interstitial video plays after every fifth finished game (Classic runs,
Daily Boards and cleared challenges), never during one, and never for Supporters. The
banner loads a fresh ad when the player changes screens, at most once every 30 seconds.
