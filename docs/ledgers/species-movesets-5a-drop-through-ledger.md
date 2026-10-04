# Species movesets 5a (drop through one-way ledges): execution ledger and final review

Plan: `docs/superpowers/plans/2026-10-04-species-movesets-5a-drop-through.md`. Branch `feat/drop-through`. Requested by Sean mid-session: all species can press down on a one-way ledge to drop through it.

## Ledger

```text
# SDD ledger — plan: docs/superpowers/plans/2026-10-04-species-movesets-5a-drop-through.md
Spec: docs/superpowers/specs/2026-10-04-species-movesets-design.md
Pre-flight: Task 1 produces on_oneway_floor/fall_through/profile fall_through and the VerbRunner logic; Task 2 consumes fall_through and surface_oneway in SurfaceStep; Task 3 consumes fall_through and produces the sandbox probe and mask toggle. No conflict.
Task 1: complete (commits d59cffb..8048954, tests: tools/run_tests.sh test_movement → PASS: 129 tests)
Task 2: complete (commits 8048954..ce2c2d8, tests: tools/run_tests.sh test_surface_step → PASS: 31 tests)
Task 3: complete (commits ce2c2d8..372f92c, tests: tools/run_tests.sh test_movement → PASS: 133 tests)
Task 4: complete (commits 372f92c..372f92c, tests: tools/run_tests.sh → PASS: 2177 tests)
Final review: debate:run changeset panel (executor, auditor, pentester ran; cartographer not run: no selector assignment and its configured model fails in acpx; executor-b, simplifier, antigravity, deepseek not configured). 4 raw findings, 1 survived verification, 3 refuted; report archived as 1c80ff53-r1. Pentester: no findings.
Final: Re-graded: the sandbox's one-way floor probe is a single ray under the centre, so a body standing on a ledge's edge (centre past the end, box still on it) cannot drop through (Important: standing near a platform's edge is ordinary and the press does nothing).
Final: minor (deferred): a down press on the same tick as a zip aimed at a one-way anchor within about 80 px starts a fall-through, so the zip passes through that anchor instead of gripping it; gate fall_through on a zip or drop starting this tick.
Final: refuted: the spider gets stuck beside the ledge after dropping (it falls like the others; the real-collision test reaches the floor); an already-spread slime cannot drop (the press clears the spread and the flat box rests at the same height); a drop can start mid-zip or mid-slide (the body is airborne then, so no one-way floor underfoot).
Final: fixed one-way probe misses a ledge's edge — test_a_body_standing_on_the_edge_of_a_ledge_still_drops_through RED→GREEN (the probe is now the body's floor contacts), suite 2178/2178
```

## Final review (debate:run, changeset mode)

Panel: executor, auditor and pentester ran (codex). The cartographer was not run (no selector assignment; its configured model fails in acpx); executor-b, simplifier, antigravity and deepseek are not configured here. Four raw findings, one survived verification and three were refuted; the report is archived as `~/.acpx/debate-reports/1c80ff53-r1.json`. Panel output, verbatim:

### executor

```text
- **[P1] The spider gets stuck on the one-way ledge after dropping.** In [surface_step.gd](/Users/sean/sites/isekai-game/.worktrees/drop-through/scripts/movement/surface_step.gd:43), the drop clears `surface_n` and returns `false`, so the sandbox proceeds to `move_and_slide()`. But on the next tick `_attach()` refuses to grip while `fall_through > 0` at lines 93–95, and the spider’s `_crawl()` path does not run `move_and_slide()` or apply gravity. Its velocity was zeroed when it attached to the ledge and remains zero, so it stays beside the ledge until the timer expires, then grips it again. The sandbox’s one-way ledge assertion at `test_movement_sandbox.gd:743` expects it to reach the lower floor. Preserve/apply gravity or otherwise ensure the detached spider actually falls throughout the lockout.

- **[P1] Drop-through fails when the player is already spread.** In [verb_runner.gd](/Users/sean/sites/isekai-game/.worktrees/drop-through/scripts/movement/verb_runner.gd:54), the dropping press blocks `_ooze()` from flattening, but does not clear an existing `s.spread`. The sandbox applies the standing collision box at `movement_sandbox.gd:206`, while `fall_through` lasts only 0.2 s. A slime that was already flat has the shorter box, so it can fall through the 6 px ledge yet collide with the lower hard floor at the flat box’s resting height; its centre then remains about 7 px above the test’s expected `y == -12` at `test_movement_sandbox.gd:743`. Restore the standing box during the drop or define the landing behavior for a still-spread slime and test that state.

- **[P2] The verb runner can start a drop while a spider is zip-pulling or silk-dropping.** `fall_through` is started before the early returns for `ZipStep.step()` and `DropStep.step()` in [verb_runner.gd](/Users/sean/sites/isekai-game/.worktrees/drop-through/scripts/movement/verb_runner.gd:17–29). Those steps own the body and bypass `SurfaceStep`, so the sandbox mask is disabled while the existing verb continues; a zip/drop can then pass through one-way geometry unintentionally. Gate the trigger on those owning states, or specify and handle the interaction.
```

### auditor

```text
- **P2 — Drop-through fails near ledge edges.** In [movement_sandbox.gd:193](/Users/sean/sites/isekai-game/.worktrees/drop-through/scripts/movement/movement_sandbox.gd:193), the new detection is:
  ```gdscript
  i.on_oneway_floor = was_on_floor and _ray(Vector2.ZERO, Vector2(0.0, BodyConfig.BOTTOM + 3.0), false) == SurfaceStep.ONEWAY
  ```
  A biped settled at approximately `(155, -62)` still overlaps the ledge and stands on it, but this centre ray misses. The body is 28 px wide ([body_config.gd:8](/Users/sean/sites/isekai-game/.worktrees/drop-through/scripts/player/body_config.gd:8): `const COLLISION := Vector2(14, 12)`, with `SCALE := 2`), and the ledge starts at x=160 ([movement_sandbox.gd:20](/Users/sean/sites/isekai-game/.worktrees/drop-through/scripts/movement/movement_sandbox.gd:20): `const ONEWAY_LEDGE := Rect2(160, -50, 100, 6)`). Pressing down therefore leaves `fall_through` at zero and the body on the ledge. This defect is introduced by the new detection. Identify the supporting floor through collision contacts or a probe covering the foot width, and add regression cases at both edges.

Source review only; tests were not run because the runner writes files.

VERDICT: REVISE
```

### pentester

```text
No exploitable security findings. I reviewed the surrounding sandbox input, collision layer, and room-building code; the changes introduce no shell, file, credential, or external trust boundary. I did not run tests during this read-only review.

VERDICT: APPROVED
```
