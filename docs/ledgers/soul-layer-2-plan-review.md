# Soul layer plan 2: debate panel review (2026-10-04)

Plan: `docs/superpowers/plans/2026-10-04-soul-layer-2-scene-and-death-flow.md`.
Panel: executor (GPT-6 Luna) and auditor (GPT-6 Sol). The debate config changed during the session: `antigravity` was removed and the default panel is now those two, so the stale `antigravity` seat I named was skipped by the runner. The repo is public now, so no ZDR override was needed.
Rounds: 1 both REVISE; 2 executor APPROVED, auditor REVISE (two small fixes); verification pass (auditor only) APPROVED. Each finding was checked against the code before a ruling.

| # | Finding (seat) | Check | Ruling |
|---|---|---|---|
| 1 | `Run.accept` trusts the caller's kit and cost, so cost 0 or -1 gives a free kit (executor, auditor) | True: `_begin` spends only when `cost > 0` | `accept` takes only a result exactly equal to the pending model's own `confirm()`; the forged-result test covers cost 0, -1, 99, a mismatched kit and a stale result |
| 2 | `SpeciesCatalog.unlocked` returns `SpeciesDef`s, which have no `name` (auditor) | True: the model reads `id` and `name` from rows | Task 3 maps each def to `{"id", "name": display_name}` and tests the Who rows |
| 3 | The stick test with two rows cannot tell one step from two (auditor) | True: `move` clamps | The test uses three places |
| 4 | Swallowing joypad motion does not stop `Controls` recording it (executor) | Partly: `Controls._input` runs first, as stated; the menu marks it handled so no later handler acts | Intent stated in the plan, and the test sends a real event through the viewport and checks one row moves via `_process` |
| 5 | The no-listener test may not reach the fallback (executor) | 5 points do reach the first level's price of 2, but the plan did not say so | The test asserts `need_menu()` first |
| 6 | The end-to-end test leaves Compendium state behind (executor) | `begin_life` only raises `leap` to NAMED, as the existing kit test already does; no test asserts it unknown | Declined; the plan notes why |
| 7 | The editor-play test lambda has two arguments, not three (auditor, round 2) | True | Fixed |
| 8 | Task 6 needs a known starting choice and must restore `pending_start` and `session_points` (auditor, round 2) | True | Fixed |
