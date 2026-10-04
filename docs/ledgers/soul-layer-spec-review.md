# Soul layer spec: debate panel review, round 1 (2026-10-04)

Spec: `docs/superpowers/specs/2026-10-04-soul-layer-design.md` (written in 24ecbfb).
Panel: executor (GPT-6 Luna), auditor (GPT-6 Sol), antigravity (Gemini 3.1 Pro). All three returned REVISE.
The repo reads as private and the registry's models carry no `route: 31501`, so the ZDR guard blocked the run; Sean allowed this one run without it.
Every claim was checked against the code before a ruling. The fixes were not re-reviewed by the panel.

| # | Finding (seat) | Check | Ruling |
|---|---|---|---|
| 1 | Species choice has no effect on the body (executor) | True: `resolve_start` and `begin_life` carry no species | Species is carried as `start["species"]`; applying its profile is the movement agent's wiring plan. Stated in the spec |
| 2 | Cause wiring misses call sites (executor) | `enemy.gd:329`, `enemy.gd:618`, `spear.gd:19`; spec said "one argument each" | Spec names all three sites. Ability hits pass their own tags, which fall to the general line |
| 3 | Poison deaths cannot name the creature (executor) | `spit_blob.gd:66`, `spore_puff.gd:41` call `receive_poison`, which passes only `"poison"` | Scoped to the one general `poison` line; per-creature lines deferred |
| 4 | `--soul=N` unspecified (executor) | True | `Game.soul_points_arg`: 0 to 9999, bad input reads 0, `_ready` sets (not adds) `session_points` |
| 5 | Removing pool kits in plan 2 breaks the validator (auditor) | `world_validator.gd:97` requires a `kit` dictionary | Kit removal moves to plan 3 with the validator change |
| 6 | `eaten + defeated` counts one creature twice (auditor) | Defeat raises `defeated`, eating the body raises `eaten` | `count` is `max(eaten, defeated)` |
| 7 | Map loses altar markers (auditor) | `skill_screen_model.gd:309-310` test `kind == "rebirth_pool"` | Plan 3 lists the full blast radius, including this file |
| 8 | "At most one altar per area" allows no `C1` (auditor) | `world_progress.gd` `is_attuned` treats `C1` as default; validator requires it today | The default-altar invariant is kept and tested |
| 9 | First death always gets the general line (auditor) | True. Also found by the orchestrator: `many_deaths` could never fire for a known cause | `first_death` dropped (the opening owns her first words); `many_deaths` fires on every fifth death, ahead of cause lines |
| 10 | Banking crosses the run and profile boundary (antigravity) | The run ledger is never persisted (no ledger in `scripts/persistence`), so no duplication is possible | Spec states `SoulProgress` saves on every change and why quitting cannot duplicate |
| 11 | Perks bought in the world apply only next life (antigravity) | True | Stated: applies from the next life; the altar row says so |
| 12 | `session_points` mixes dev data into the model (antigravity) | Seeding saved points would write invented points to a real profile | Rejected; reason recorded in the spec |
| 13 | Signatures: `Banking` lacked the engine, `HeadStart.price` named `rules_data` (orchestrator) | Spec inconsistency | Fixed |

Deferred: per-creature lines for poison and ability kills (each ability would pass its actor's id).
