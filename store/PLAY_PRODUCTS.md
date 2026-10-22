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
| `tip_10`, `tip_20` … `tip_1000` (steps of ₹10, 100 products), then `tip_1100`, `tip_1200` … `tip_10000` (steps of ₹100, 90 products) | Consumable | A tip: nothing unlocked. 190 products, each priced in rupees at the amount in its id (Play converts for other countries). Every tip's Play title is just "Tip jar" and its description names no currency, so buyers abroad never see a rupee title on Play's purchase screen | ₹ = the number in the id |

Consumables are consumed after granting, so they can be bought again. One-time packs
are acknowledged and restored on every launch and from **Restore purchases**.

Players always see prices in their own currency: the game shows Google Play's
`formatted_price` for each product (rupees in India, US dollars in the USA, Canadian
dollars in Canada…), and until Play answers, a fallback guessed from the device locale
(only India's shows ₹). The tip jar picks an amount with − / + and a slider over these
190 products and shows each one's local price; nothing is typed in rupees.

Every tip id, in order:

`tip_10`, `tip_20`, `tip_30`, `tip_40`, `tip_50`, `tip_60`, `tip_70`, `tip_80`, `tip_90`, `tip_100`, `tip_110`, `tip_120`, `tip_130`, `tip_140`, `tip_150`, `tip_160`, `tip_170`, `tip_180`, `tip_190`, `tip_200`, `tip_210`, `tip_220`, `tip_230`, `tip_240`, `tip_250`, `tip_260`, `tip_270`, `tip_280`, `tip_290`, `tip_300`, `tip_310`, `tip_320`, `tip_330`, `tip_340`, `tip_350`, `tip_360`, `tip_370`, `tip_380`, `tip_390`, `tip_400`, `tip_410`, `tip_420`, `tip_430`, `tip_440`, `tip_450`, `tip_460`, `tip_470`, `tip_480`, `tip_490`, `tip_500`, `tip_510`, `tip_520`, `tip_530`, `tip_540`, `tip_550`, `tip_560`, `tip_570`, `tip_580`, `tip_590`, `tip_600`, `tip_610`, `tip_620`, `tip_630`, `tip_640`, `tip_650`, `tip_660`, `tip_670`, `tip_680`, `tip_690`, `tip_700`, `tip_710`, `tip_720`, `tip_730`, `tip_740`, `tip_750`, `tip_760`, `tip_770`, `tip_780`, `tip_790`, `tip_800`, `tip_810`, `tip_820`, `tip_830`, `tip_840`, `tip_850`, `tip_860`, `tip_870`, `tip_880`, `tip_890`, `tip_900`, `tip_910`, `tip_920`, `tip_930`, `tip_940`, `tip_950`, `tip_960`, `tip_970`, `tip_980`, `tip_990`, `tip_1000`, `tip_1100`, `tip_1200`, `tip_1300`, `tip_1400`, `tip_1500`, `tip_1600`, `tip_1700`, `tip_1800`, `tip_1900`, `tip_2000`, `tip_2100`, `tip_2200`, `tip_2300`, `tip_2400`, `tip_2500`, `tip_2600`, `tip_2700`, `tip_2800`, `tip_2900`, `tip_3000`, `tip_3100`, `tip_3200`, `tip_3300`, `tip_3400`, `tip_3500`, `tip_3600`, `tip_3700`, `tip_3800`, `tip_3900`, `tip_4000`, `tip_4100`, `tip_4200`, `tip_4300`, `tip_4400`, `tip_4500`, `tip_4600`, `tip_4700`, `tip_4800`, `tip_4900`, `tip_5000`, `tip_5100`, `tip_5200`, `tip_5300`, `tip_5400`, `tip_5500`, `tip_5600`, `tip_5700`, `tip_5800`, `tip_5900`, `tip_6000`, `tip_6100`, `tip_6200`, `tip_6300`, `tip_6400`, `tip_6500`, `tip_6600`, `tip_6700`, `tip_6800`, `tip_6900`, `tip_7000`, `tip_7100`, `tip_7200`, `tip_7300`, `tip_7400`, `tip_7500`, `tip_7600`, `tip_7700`, `tip_7800`, `tip_7900`, `tip_8000`, `tip_8100`, `tip_8200`, `tip_8300`, `tip_8400`, `tip_8500`, `tip_8600`, `tip_8700`, `tip_8800`, `tip_8900`, `tip_9000`, `tip_9100`, `tip_9200`, `tip_9300`, `tip_9400`, `tip_9500`, `tip_9600`, `tip_9700`, `tip_9800`, `tip_9900`, `tip_10000`

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
