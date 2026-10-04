# Creature scale ladder: ledger

Requested by Sean (2026-10-04, playing the sandbox): "think about the scale of size between our different species and monsters". His rule: **every monster must feel a good size next to the others; the player's body boxes and reach are tuned to fit that, not the other way round.** The goblin stays 39 px tall (17x39).

## What changed

A to-scale lineup of every creature (first frame, px as drawn) showed four that read wrong. Sean approved the proposals:

| Creature | Before | After | Why |
|---|---|---|---|
| Stone Drake | 72x33 | 108x50 | lower than the wolf (37) and the lizardman (48), it did not loom |
| Taratect (boss) | 60x41 | 90x62 | under twice the player spider (33x23) |
| Armed Ant | 36x45 | 31x38 | taller than the wolf; it reads as a warrior, no taller than the goblin (39) |
| Pale Moth | 42x47 | 34x38 | nearly as tall as the lizardman |

Done by scaling the `width` of every frame in `tools/art/<set>_frames.json` and re-running `assemble_frames.py <set>` from the source frames (no regeneration; the hurt and attack shapes are retraced, so hitboxes follow the art). `tests/test_creature_scale.gd` pins every creature's size and the four relations above, so a change of art is now a decision.

## Rulings

- Ruling: the Pale Moth's pin in `tests/test_pale_moth.gd` ("at least 1.3 times as wide as the Spore Moth", from the plan that made it a larger derived sheet) is relaxed to 1.1. The approved 0.8 makes it 1.13 times the Spore Moth; it is still the larger moth. Cost if wrong: say so and it goes to about 0.93 (39 px wide, 44 tall), which brings it back near the lizardman's height.

## Not done, open

- The rooms that hold the bigger creatures (D3, D4, D5 drakes; D6 taratect; G5 moth) pass their data tests, but nobody has looked at them with the new sizes in the real renderer: the drake's windup frame is 108x99, the taratect's drop frame 100x89. The tools that screenshot rooms start the game through the new opening and need a way past it.
- Per-species player body boxes derived from the sprites (the wolf is 54 wide in a 28x24 box), and the reach model and room lint per species, are the next plan. The mantle's reach (32 px) is in it.
- `form_arachne` (55x33, a player form) against the 33x23 spider: which is the playable spider is undecided.
