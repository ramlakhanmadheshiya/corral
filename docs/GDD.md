# Corral: game design

## High concept
Corral is a minimalist portrait enclosure puzzle. You place wall pieces on a 9 × 9 grid; whenever walls fully enclose a patch of empty cells, that patch is captured, fills with colour and scores its area squared, and the walls around it vanish. It plays like a block puzzle, but instead of clearing lines you fence in space.

## Market references
- **Block Blast, Woodoku, 1010!:** a tray of three fixed-orientation pieces, refilled when used, game over when nothing fits; the "always a piece that fits" fairness players expect.
- **Go, Dots and Boxes, territory games:** the pleasure of closing off space.
- **Two Dots, I Love Hue, Alto's Odyssey:** calm pastel palettes, generous whitespace, audio that is part of the reward.

## Player promise
You build a fence piece by piece, hold your nerve while the board fills, and close a huge pen that floods with colour in a cascade of rising notes.

## Core loop
1. Look at the three pieces in the tray.
2. Drag one onto the board. The ghost shows where it lands; if it would close a pen, the pen glows and shows its score.
3. Let go. Captured pens flash, fill from the closing piece outward, score, and the walls around them vanish, freeing room.
4. When all three pieces are used, three more arrive (between trays, gems may appear or hop and rocks may drop in).
5. When none of the pieces fits anywhere, the game ends (Classic offers one continue).

## Rules
| Rule | Detail |
|---|---|
| Board | 9 × 9 cells: empty, wall (placed), rock (permanent). Gems sit in empty cells. |
| Pieces | 36 fixed orientations in four classes: small (dot, I2), easy (I3, corners), medium (I4, L/J, U), awkward (T, S/Z, square, big ring corners). No rotation. |
| Placing | Only on empty cells without a gem, fully on the board. |
| Enclosure | An empty region (4-connected) is captured when none of its cells can reach the board edge through empty cells. The edge is open; diagonal gaps do not leak; gems count as empty. |
| After a capture | Every wall 8-adjacent to a captured cell vanishes. Rocks stay. Captured cells become empty (a faint stain of the pen's colour stays). |
| Score | 1 per placed cell; a pen of area A scores A² × 10, doubled per gem inside; 2+ pens closed by one piece multiply the pens' points by 1 + 0.5 per extra pen. |
| End | No tray piece fits (stuck), the fixed sequence runs out, or (challenges) the goal is met. |

## Modes
| Mode | Pieces | Goal | Result |
|---|---|---|---|
| Classic | Generated, fair trays, harder as the score rises | Best score | Coins by score, new-best bonus, one optional continue |
| Daily Board | The date's fixed 30-piece sequence on the date's layout | Score | ★ by score (set by the bot), streak, daily coins |
| Challenges | A fixed sequence per level | A goal: pens, a pen size, gems, combos or a score | ★ by pieces used (par from the bot) |

## Classic difficulty
- `difficulty = log(1 + score/1000) / log(41)`, full at 40,000 points.
- Piece shares move from small 16% / easy 40% / medium 32% / awkward 12% to 3% / 24% / 38% / 35%.
- Rocks from 3,000 points, then every 4,000 (max 8), never sealing a region by themselves.
- Gems from the second tray, 45% chance per tray, up to 3; from 6,000 points they hop (60% each, per tray).
- Fairness: a fresh tray is redrawn up to six times until a piece fits; failing that, one slot gets a fitting piece from the friendliest class. If no piece in the game fits, the run ends.

## Challenges
8 chapters × 15 levels; 10 clears open the next chapter.

| Chapter | Idea | Goal mix |
|---|---|---|
| Meadow | First pens | Pens, pen size, score |
| Orchard | Gems double a pen | Gems |
| Quarry | Rocks never vanish | Mixed, 3–7 rocks |
| Lagoon | Big pens | Pen sizes up to 16, scores |
| Canyon | Combos | Close two pens at once (early levels have prebuilt twin pens) |
| Marsh | Hopping gems | Gems that move between trays |
| Tundra | Awkward pieces | Scores with tight pieces |
| Summit | Everything | Mixed, hopping gems |

Generation (`LevelMaker.challenge`): for each level, seeded attempts build a layout (rocks, gems off the edge, short wall fragments, never an enclosed region) and a 45-piece sequence at the level's difficulty; the planning bot plays it; winning candidates (at least 2 moves, 3 for combos) are kept and the one whose length best matches the chapter curve is chosen. The level stores `pieces = max(k + 3, 1.6k)`, `par = [k + max(1, k/5), k + max(2, k/2)]` and the bot's moves, which the tests replay.

## The bot
`CorralBot` picks a target rectangle (interior up to 5 × 5, no rock inside, no gem on its ring) that suits the goal, weighting value against missing ring cells (`value / (missing + 1)^2.2`), then rates every placement: points scored, goal progress, ring cells filled, cells wasted inside the target, hugging other walls, keeping the rest of the tray placeable, and free space. It is greedy (one move at a time) and fast (about 2 ms a move), which is enough for hints, the daily star scores and level validation.

## Economy
| Source | Coins |
|---|---|
| Start | 100 |
| Classic | 1 per 400 points (max 40) + 20 for a new best |
| Challenge | 10 first clear + 5 per new star; 100 per chapter |
| Daily Board | 30 + 5 per streak day (max +30) |
| Missions | 20 / 35 / 50 (three a day) |
| Awards | 20–800 each (39) |
| Videos | 25 coins (5 a day), a level key (3 a day) |

| Spend | Coins |
|---|---|
| Hint | 30 (first daily free; 3 for Supporters) |
| Shuffle (Classic) | 50 |
| Continue (Classic, once per run) | 150, or a video |

## Feel
- Chunky walls with a darker lip, joined into continuous fences; a pop when placed.
- Capture: white flash, paint-bucket fill from the closing piece (45 ms per step), pentatonic pops per wave front, confetti per cell and a burst per pen, score popup sized by the pen, gem multiplier popup, a soft shake scaled by area, walls shrinking away, a chord (a bigger one for 9+ cells).
- Gems bob and sparkle; captured gems float up and fade. Rocks drop in with a thud and a small shake.
- Haptics: tick on pick-up and placement, a stronger buzz on captures.
- Audio: all synthesised (`tools/synth_audio.py`): pluck, pop, wooden thunk, bells, pads; two looping pentatonic music tracks.

## Monetisation (player-friendly)
- Banner at the bottom with reserved space; a short video after every 5th finished game; none for Supporters.
- Rewarded videos only on request: the continue, hint/shuffle when out of coins, free coins, keys, pack trials.
- One-time packs: Supporter, Theme, Pen styles, Complete; consumables: coins, keys, tips.

## Retention
Best score, Daily Board streak, three daily missions, 39 awards, challenge stars and chapters, unlockable themes and pen styles, a shareable picture of every game.
