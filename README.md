# Corral

*An endless enclosure puzzle.* Drop chunky wall pieces on a 9 × 9 field. When your walls close off a patch of empty cells, the pen is captured: it flashes, fills with colour like a paint bucket, scores its area squared, and the walls around it vanish. One big pen beats several small ones, if you dare to wait for it.

Made with Godot 4.7.2 (GDScript, Compatibility renderer, so it also runs on the web). Portrait-first; works with touch and mouse.

**Play / download:** https://theramlakhan.com/corral/ (browser version and Android APK)
**Made by:** [Ramlakhan Madheshiya](https://theramlakhan.com), with Claude as AI co-developer.

## The game

- **Place, enclose, capture.** A tray offers three wall pieces (straights, corners, Ls, Us, Ts, S/Z, squares and big ring corners, 36 fixed orientations, no rotation). Drag one onto the grid; a ghost shows where it lands (red where it can't) and the board previews any pen it would close, with what it would score. Use all three and three more arrive. When none of your pieces fits anywhere, the game is over.
- **The enclosure rule.** An empty region is captured when none of its cells can reach the board's edge by stepping up, down, left or right through empty cells. The edge is open, so a region touching it is never enclosed, and diagonal gaps don't leak (a pen's corners aren't needed). Every wall touching a captured cell, diagonals included, vanishes; captured cells become empty again, keeping a faint stain of their colour.
- **Scoring: area squared.** A pen of area A scores A × A × 10 (4 cells = 160, 9 = 810, 16 = 2,560), each placed cell scores 1, each gem inside a pen doubles it (×2, ×4, ×8), and closing two or more pens with one piece is a combo (×1.5 for two, ×2 for three). Greed vs safety: hold out for a big pen while the board fills, or bank a small one now.
- **Rocks and gems.** Rocks count as walls but never vanish. Gems sit in empty cells (pieces can't cover them) and are never placed on the edge, where they could never be captured.
- **Classic** is endless. Difficulty follows the score on a log curve (full at 40,000): awkward pieces (T, S/Z, squares, big corners) get likelier and small ones rarer; from 3,000 points rocks drop in (then every 4,000, up to 8, never sealing a region by themselves); gems appear between trays (up to 3) and from 6,000 points they hop. **Fair trays:** every fresh tray contains at least one piece that fits when any piece could (rerolled up to six times, then one slot is swapped for a fitting piece from the friendliest class), without making the other two pieces easy. A run is saved after every move and resumes after the app closes.
- **Daily Board** is built on the phone from the date (`DailyBoard.build`), with no server: everyone gets the same rocks, gems, starting wall fragments and the same 30 pieces in the same order. The bot plays it once to set the star scores (★★ at 25% and ★★★ at 60% of the bot's score) and to make sure all 30 pieces can be placed (otherwise the next seeded variant is used). The board gets busier through the week and gems hop at weekends. Finishing on consecutive days builds a streak; coins are paid once a day, replays can raise the day's best.
- **Challenges: 8 chapters × 15 = 120 levels**, each with its own colour and idea: Meadow (first pens), Orchard (gems), Quarry (rocks), Lagoon (big pens), Canyon (combos), Marsh (hopping gems), Tundra (awkward pieces), Summit (everything). Each level has a layout, a fixed piece sequence and a goal: capture N pens, a pen of N+ cells, N gems, N combos, or a score. The level ends as soon as the goal is met. **Stars by pieces used:** ★★★ within the bot's count plus a little slack (`par[0]`), ★★ within `par[1]`, ★ otherwise. Clearing 10 challenges opens the next chapter; a level key opens any locked challenge.
- **Every level is achievable.** `tools/generate_levels.gd` builds each level from seeded layouts and sequences, lets the planning bot (`CorralBot`) play it, keeps only candidates the bot wins (rejecting 1-move "puzzles"), and picks the one whose length best fits the chapter's difficulty curve. The bot's winning moves are stored with the level and replayed by the tests.
- **Rewards** (each paid once): Classic coins for the score (1 per 400 points, up to 40) plus 20 for a new best; +10 for a first challenge clear and +5 per new star; +100 for a whole chapter; +30 for the Daily Board (+5 per streak day, up to +30 more); three **daily missions** (the same for everyone, 20/35/50 coins, paid automatically); **39 awards**.
- **Hints and help:** *Hint* (30 coins; first each day free, 3 for Supporters) outlines the bot's best spot and the piece to use. *Shuffle* (Classic, 50 coins) swaps the unused pieces. **One continue per Classic run**, only when the player asks: when nothing fits, a video or 150 coins clears the 14 walls nearest the centre and deals a fresh tray. Out of coins, the player can choose to watch a rewarded video for a hint or shuffle; on the web (no videos) these are free.
- **Shop** (the earlier games' model; one-time packs plus consumables, all via Google Play):

  | Product | What it gives |
  |---|---|
  | Complete pack | Everything below, plus 1,000 coins and 5 level keys |
  | Supporter pack | No banner ads or videos between games, 3 free hints a day |
  | Theme pack | 10 colour themes (5 light, 5 dark) that recolour the whole app (1-hour trial from a video) |
  | Pen styles | 6 looks for walls and pen colours: Candy, Stone, Neon, Fence, Glass, Ink (1-hour trial from a video) |
  | Coin bags | 100 to 6,000 coins; plus free coins from a video (5 a day) |
  | Level keys | 1–10 keys, 10% off for 5+; plus a free key from a video (3 a day) |
  | Tip jar | Say thanks; unlocks nothing. Four quick amounts, or pick your own with − / + (one amount at a time) and a slider from the smallest tip to the largest. 190 products: ₹10 to ₹1,000 in steps of ₹10, then ₹1,100 to ₹10,000 in steps of ₹100 (`tip_10` … `tip_10000`, priced in rupees in Play Console) |

  **Prices are always in the player's own currency:** every price on screen comes from `Store.price(id)`, which is Google Play's localised price once the product query answers (rupees in India, US dollars in the USA, Canadian dollars in Canada…) and until then a fallback guessed from the device locale (only India's shows ₹). The tip jar never asks for a rupee amount; it shows the local price of the selected tip, and refreshes when Play's prices arrive. The shop, every buy card and the tip jar carry a small line: "Purchases are made through Google Play. Sorry, we can't refund or undo a purchase." (also on the help page and at the end of the store listing).

  Product ids and Play Console setup: [`store/PLAY_PRODUCTS.md`](store/PLAY_PRODUCTS.md). Debug desktop builds simulate purchases; the web build explains that purchases are in the Android app.
- **Ads (Android):** a banner at the bottom of every screen, with its space reserved before the ad loads so the layout never jumps; it loads a fresh ad when the player changes screens (at most every 30 s, per AdMob policy). Rewarded videos only when the player asks (the continue, a hint or shuffle when out of coins, free coins, a level key, a pack trial). A short video plays after every 5th finished game (Classic run, Daily Board or cleared challenge), never during one. Supporters see no banners and no videos between games. The web build shows no ads.
- **Juice:** the opening splash builds a pen and fills it; walls are chunky joined blocks with a lip that pop when placed; captures flash white, fill cell by cell from the closing piece with rising pentatonic pops and confetti, show a score popup (and the gem multiplier), shake the screen softly by pen size, and the bordering walls shrink away; gems bob and fly out of captured pens; rocks drop in with a thud; haptics on pick-up, placement and captures.
- **First play:** Play goes straight into a guided Classic run: a pen with one side missing, an animated hand dragging the piece into the glowing gap, and captions that explain area scoring once the first pen closes (like Single Shot's hands-on tutorial). Afterwards Play opens the mode select.
- **Sharing:** after a game, Share makes a 1080×1350 picture of the run's painting (every pen captured, in its colour), the score, stars where they apply, the link and a QR code, then opens the phone's share sheet; Save puts it in the gallery (Pictures › Corral); Copy link copies the message. Android uses a small plugin (`plugins_src/corral_share`, built by CI).
- **Appearance:** a thin Auto / Dark / Light slider in Settings; Auto follows the phone's dark mode. It applies to the Original colours (Theme-pack themes keep their own); each challenge chapter tints the Original sky with its colour.
- **Settings:** Music and Sound volume sliders, Vibration, Appearance, colour theme and pen style pickers, How to play, Shop, Awards, About, Credits, Ad privacy (when required), and Reset progress (tap once to arm, again to erase; hidden during a game; keeps settings, packs, keys and bought coins).
- **Saving:** everything is saved locally with atomic writes and a backup; games in progress resume.

### Controls

| Input | Action |
|---|---|
| Drag a piece (touch or mouse) | Move it over the board; let go to place it |
| Esc / Android Back | Back (game → modes or its chapter → home) |

### Design decisions

Choices made where the brief left room:

- **Rocks** count as walls for enclosing and never vanish; they arrive in Classic by score and are pre-placed in dailies and challenges. A rock is never dropped where it alone would seal a region.
- **Gems** can't be covered by pieces, are never placed on the edge, and are consumed by the pen that captures them. Hopping gems move to a free orthogonal neighbour off the edge, with the run's own seeded generator, so a challenge plays out the same way every time for the same moves.
- **Combo** multiplier is ×(1 + 0.5 per extra pen) on the pens' points; placed cells score separately.
- **Daily Board** is a 30-piece score attack with no adaptive fairness (a fixed sequence is what makes it comparable); the bot proves each day's 30 pieces can all be placed.
- **Challenge stars** reward efficiency (fewer pieces) rather than score, so they read like the earlier games' "par".
- **Continue** clears the 14 walls nearest the centre and deals a fresh fitting tray: big enough to matter, small enough to keep the run's shape.
- **Scores** use a 32-bit seeded generator (mulberry32) everywhere, so saves are exact in JSON and dailies match on every device.

## Run

```sh
./play.sh              # launches the game window directly (no editor)
```

Debug desktop runs show a test ad banner and simulate purchases, so every flow can be tried without a phone.

## Test

```sh
./tests/run_all.sh
```

| Suite | What it checks |
|---|---|
| `tests/logic_test.gd` | Enclosure detection and its edge cases (edge is open, diagonal gaps, corridors, rocks as walls, gems as empty, a ring along the border), walls vanishing (8-neighbourhood, rocks stay, a wall deep inside a pen stays), scoring (area², gems stacking, combos), placing and game over, the drag preview, the piece generator's fairness over 400 crowded boards, difficulty mix, determinism of the random numbers, saves (exact round trip and identical play afterwards), the Daily Board (same date = same board, a pinned hash, 20 dailies placed in full by the bot), the continue and shuffle, hopping gems, missions, and the bot. |
| `tests/levels_test.gd` | All 120 challenges: well-formed, goals as planned, nothing enclosed at the start, gems off the edge and on empty cells, enough gems for gem goals, par within the pieces, the stored solution replays legally and wins with three stars, each chapter gets harder, and the generator reproduces the stored levels. |
| `tests/profile_test.tscn` | Coins, free hints, Classic rewards and best score, challenge stars and rewards (paid once), chapter unlocks, keys, the daily streak, missions (paid once, automatically), achievements (once), simulated purchases (packs, coins, keys, tips, the Complete pack's one-time bonus), trials, restart persistence, reset keeping purchases, corrupt-save recovery. |
| `tests/ui_flow.tscn` | The real app end to end with the mock ad provider: splash, banner space, the tutorial with real drags (a wrong drop slides back), Back, resuming a saved run, hints (free, paid, video when out of coins, skipped video), shuffle, the continue (video, then coins), the Classic result, the Daily Board played to the end, challenges (chapters, locked chapter, 15-tile grid, a full clear by dragging, Next, a failed attempt, a key), videos between games, the shop (free coins, a trial, Supporter removes the banner), settings, an app restart, Reset progress. |
| Boot smoke | Runs the game for 300 frames and fails on any error, warning or leak. |

Screenshots of every screen (needs a display; add `clean` to hide the test banner, `dark` for the dark look):

```sh
godot --path . res://tests/capture.tscn -- /tmp/corral_shots 450 800
```

## Make the levels and art

```sh
godot --headless --path . -s res://tools/generate_levels.gd            # all challenges
godot --headless --path . -s res://tools/generate_levels.gd -- canyon  # one chapter
godot --headless --path . -s res://tools/sim_classic.gd -- 10          # bot plays 10 Classic runs (balance)
python3 tools/synth_audio.py                                           # every sound and both music loops
godot --headless --path . -s res://tools/render_icons.gd               # Android icons and the web icon from the SVGs
godot --path . --resolution 1024x500 res://tools/render_store_art.tscn # feature graphic, Play icon, boot splash
```

Levels are generated from the plan in `data/chapters.json` and committed in `data/levels/`. The generator is deterministic (CI regenerates and fails on any difference). Store screenshots come from `tests/capture.tscn` at 900 × 1600 with `clean`, scaled to 1080 × 1920.

## Build & publish

Every push to `main` runs `.github/workflows/build.yml`: tests, the reproducibility check, a web export, the share plugin, a signed Android APK and App Bundle (Gradle build with the AdMob, Play Billing and share plugins), a GitHub release with the APK, publishing to `gh-pages` (served at `https://theramlakhan.com/corral/` with `play/`, `help/`, `privacy/` and `corral.apk`), and an upload to Google Play's internal track once the service-account secret exists.

Repository secrets:

| Secret | Purpose |
|---|---|
| `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEYSTORE_ALIAS` | Release signing (without them a throwaway key is used, and updates can't install over older builds) |
| `ADMOB_APP_ID`, `ADMOB_BANNER_ID`, `ADMOB_REWARDED_ID` (and optionally `ADMOB_INTERSTITIAL_ID`) | Real AdMob units (without them Google's test ads are used) |
| `PLAY_SERVICE_ACCOUNT_JSON` | Optional: uploads each AAB to Play's internal testing track |

Play Console forms, listing text and products: [`store/PLAY_CONSOLE.md`](store/PLAY_CONSOLE.md), [`store/listing.md`](store/listing.md), [`store/PLAY_PRODUCTS.md`](store/PLAY_PRODUCTS.md). Game design: [`docs/GDD.md`](docs/GDD.md).

## Project structure

| Path | What it holds |
|---|---|
| `game/core/` | Pure logic: `field.gd` (the board, placement, enclosure), `pieces.gd`, `scoring.gd`, `generator.gd` (fair trays), `run_state.gd` (a game in play: tray, score, goals, stars, events, continue, save), `bot.gd` (planning player for hints and validation), `daily_board.gd`, `level_maker.gd` (layouts and challenge generation), `rng.gd`, `economy.gd`, `achievements.gd`, `missions.gd` |
| `game/autoload/` | `save.gd` (versioned JSON save), `catalog.gd` (chapters, levels, daily), `profile.gd` (coins, scores, stars, unlocks, keys, purchases, trials, streaks, missions, achievements, settings), `store.gd` (catalogue and Play Billing), `share_service.gd`, `audio.gd`, `haptics.gd` |
| `game/ads/` | `ad_manager.gd` (banner and rewarded policy) and providers: AdMob (Android) and a mock (debug desktop, tests) |
| `game/board/` | `board_view.gd` (the board and every capture effect), `tray_view.gd` (the three pieces and dragging) |
| `game/ui/` | `app.gd` (screens, Back chain, overlays, toasts), `screen.gd`, `overlay.gd`, `ui_kit.gd`, `style.gd`, `look.gd` (themes and pen styles), `screens/` (home, modes, chapters, levels, play, shop), `overlays/` (settings, result, continue, missions, product, picker, keys, coins, tips, locked, how-to, about, credits, awards, share, messages), `widgets/` (splash, tutorial, demo board, backdrop, pen art, share image…) |
| `data/` | `chapters.json` (the challenge plan), `levels/` |
| `addons/` | Godot AdMob plugin (Poing Studios, MIT), Godot Google Play Billing (MIT), the share plugin's export hook |
| `plugins_src/` | The Android share plugin (built by CI) |
| `store/`, `web/`, `docs/` | Play listing, products and graphics; the website pages; the design document |
| `tools/`, `tests/` | Generators and renderers; the test suites |

## Credits

| Asset | Source | Licence |
|---|---|---|
| Engine: [Godot Engine](https://godotengine.org) 4.7.2 | Godot contributors | MIT |
| Font: [Outfit](https://github.com/google/fonts/tree/main/ofl/outfit) | Google Fonts | SIL OFL 1.1, `assets/fonts/OFL.txt` |
| Fallback glyphs: Noto Sans subsets | Google Fonts | SIL OFL 1.1, `assets/fonts/OFL-Noto.txt` |
| UI icons: [Lucide](https://lucide.dev) | lucide-static 0.460.0 | ISC, `assets/icons/LICENSE.txt` |
| Game icons and the app icon | Drawn for Corral (coin, key, star and similar items shared with the earlier games) | Released with the project |
| Music and sound effects | Generated by `tools/synth_audio.py`, no samples | Released with the project (CC0) |
| Challenge levels | Generated by `tools/generate_levels.gd` | Released with the project |
| [Godot AdMob Plugin](https://github.com/poingstudios/godot-admob-plugin) | Poing Studios | MIT, `addons/admob/LICENSE` |
| [Godot Google Play Billing](https://github.com/godot-sdk-integrations/godot-google-play-billing) | Godot contributors | MIT, `addons/GodotGooglePlayBilling/LICENSE` |

Game design and development: **Ramlakhan Madheshiya** — https://theramlakhan.com
