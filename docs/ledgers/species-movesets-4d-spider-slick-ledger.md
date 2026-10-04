# Species movesets 4d (slick surfaces for the spider): execution ledger and final review

Plan: `docs/superpowers/plans/2026-10-04-species-movesets-4d-spider-slick.md`. Branch `feat/spider-slick`. Requested by Sean mid-session: slippery surfaces to prove the spider cannot use them (the game has no spike hazard tiles).

## Ledger

```text
# SDD ledger — plan: docs/superpowers/plans/2026-10-04-species-movesets-4d-spider-slick.md
Spec: docs/superpowers/specs/2026-10-04-species-movesets-design.md
Pre-flight: Task 1 produces SurfaceStep.SLICK, the slick flags on sweep/cast results and FakeSurfaceWorld.add_slick with SLICK_BLOCK/SLICK_CEILING; Tasks 2 and 3 consume them in SurfaceStep/ZipStep/DropStep; Task 4 produces the sandbox side (layer 4, masks 5 and 7, flags) that the real tests use. No conflict.
Task 1: complete (commits db92569..98934b8, tests: tools/run_tests.sh test_movement → PASS: 134 tests)
Task 2: Ruling: the model reads a probe hit's slick flag with .get("slick", false), not hit["slick"] — a probe that does not report it (older callers, the sandbox until Task 4) is then simply not slick; and the fake world's sweep treats a body already touching a face as blocked by it (>= on the entry tie), because a slick stop leaves the body flush and the next tick walked into it — cost if wrong: none
Task 2: complete (commits 98934b8..3bad84f, tests: tools/run_tests.sh test_surface_step → PASS: 35 tests)
Task 3: complete (commits 3bad84f..068fd8d, tests: tools/run_tests.sh test_movement → PASS: 134 tests)
Task 4: Ruling: the slick block and ceiling sit at x 300 to 360 in the sandbox (the plan's constants), so eight older ball and zip tests that dropped the slime at x 300 or zipped right from x 250 now use x 100 and the pillar's side (850, aiming left); their assertions are unchanged except one tolerance (the grip frame adds 2 px to the pull-speed sample) — cost if wrong: none
Task 4: complete (commits 068fd8d..fc7c4e3, tests: tools/run_tests.sh test_movement → PASS: 140 tests)
Task 5: complete (commits fc7c4e3..c202034, tests: tools/run_tests.sh → PASS: 2196 tests)
Final review: debate:run changeset panel (executor, auditor, pentester ran; cartographer not run: no selector assignment and its configured model fails in acpx; executor-b, simplifier, antigravity, deepseek not configured). 5 raw findings, 2 survived verification, 3 refuted; report archived as fbb803e6-r1. Pentester: no findings.
Final: Re-graded: the silk drop starts from a slick floor (Important: down on the ground is not a drop, and slick floors leave the spider on the ground step with no surface); the silk drop's landing grips a slick floor (Important: it is the one path that grips slick, so the spider would crawl on it).
Final: refuted: a slick floor is released one tick before the ground step runs (deliberate, same as the other let-go exits, nothing is lost); the fake-world slick floor and wall cases cannot be told apart (each isolates its own flag with a sticky control); the ceiling zip test does not start from the floor (a floor start is impossible there: the slick block fills the floor under the ceiling and the range is 160).
Final: fixed silk drop starts from a slick floor — test_standing_on_a_slick_floor_a_press_of_down_is_not_a_drop RED→GREEN (the airborne test now includes not on_floor)
Final: fixed silk drop landing grips a slick floor — test_reeling_down_onto_a_slick_floor_ends_the_thread_without_gripping_it RED→GREEN, suite 2198/2198
```

## Final review (debate:run, changeset mode)

Panel: executor, auditor and pentester ran (codex). The cartographer was not run (no selector assignment; its configured model fails in acpx); executor-b, simplifier, antigravity and deepseek are not configured here. Five raw findings, two survived verification and three were refuted; the report is archived as `~/.acpx/debate-reports/fbb803e6-r1.json`. Panel output, verbatim:

### executor

```text
- **A slick floor is released, but the ground step may not take over until the next tick.** In [`surface_step.gd`](</Users/sean/sites/isekai-game/.worktrees/spider-slick/scripts/movement/surface_step.gd:76>), when `_support` reports `SLICK`, the code advances the full `motion`, calls `_let_go`, and returns `true`. The next tick returns `false` so the ground step can run, but this tick remains owned by the crawl; if the body has moved off the slick floor’s edge, it misses ground-step handling for that frame. Consider stopping at the support transition or returning control in a way that preserves the displacement without skipping the ground step.

- **The planned fake-world tests cannot distinguish a slick floor from a slick wall during attachment.** In [`test_surface_step.gd`](</Users/sean/sites/isekai-game/.worktrees/spider-slick/tests/test_surface_step.gd:486>), the “slick floor” case sets `on_floor = true` while the body is above `SLICK_BLOCK`. `_attach` first probes down, sees the slick top, and correctly refuses that floor; however, `wall_side` is unset, so this does not exercise walking on a slick floor and letting the ground step take over. More significantly, the sandbox changes several existing bounce test start positions from x=300 to x=100 because x=300 is now blocked by slick terrain. This is consistent with the new block, but the other-species test only covers slime and does not cover the planned wolf behavior.

- **The new movement-sandbox test for zipping “straight up from the floor under” the slick ceiling is not actually from the floor.** In [`test_movement_sandbox.gd`](</Users/sean/sites/isekai-game/.worktrees/spider-slick/tests/test_movement_sandbox.gd:829>), the second zip begins at `(330, -102)` on top of the slick block, then aims up. It tests a slick ceiling cast from the block’s top, rather than the stated floor scenario; this may leave the intended floor-to-ceiling case unverified.

VERDICT: REVISE
```

### auditor

```text
1. **[P2] Standing on slick ground incorrectly permits Silk drop.** In [drop_step.gd:22](/Users/sean/sites/isekai-game/.worktrees/spider-slick/scripts/movement/drop_step.gd:22), the exact line is:
   > `var airborne := s.surface_n == Vector2.ZERO`

   Slick floors deliberately leave `surface_n` zero. With `i.on_floor == true`, a sticky ceiling within 200 px, and a fresh down press, `_start` therefore starts a thread from the floor; holding up then reels the spider upward. This violates the floor restriction. The faulty classification is **outside the diff**, newly exposed by slick floors. Include physical floor contact in the eligibility check and add a test with a slick floor beneath a sticky ceiling.

2. **[P2] Silk-drop landings still grip slick floors.** In [drop_step.gd:81](/Users/sean/sites/isekai-game/.worktrees/spider-slick/scripts/movement/drop_step.gd:81), the exact line is:
   > `s.surface_n = Vector2.UP`

   Reeling downward into a sweep hit with `normal == Vector2.UP` and `slick == true` executes this unconditional assignment. `VerbRunner` returns immediately after `DropStep`, so `SurfaceStep` cannot reject the grip that tick. The sandbox consequently processes the landing as crawling. This assignment is **outside the diff**, but needs updating for the new material contract. End the thread on slick contact while leaving `surface_n` zero; test both slick and sticky landings.

Review performed against the surrounding source. Tests were not run because the runner writes logs and artifacts.

VERDICT: REVISE
```

### pentester

```text
No exploitable security path found in the changeset. I reviewed the surrounding probe, zip, drop, and sandbox callers. Player input affects movement and physics queries; the changed paths do not pass it to a shell, filesystem, log, or privileged operation. I did not run tests during this read-only review.

VERDICT: APPROVED
```
