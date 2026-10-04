# Species movesets 4c (the spider's silk drop): execution ledger and final review

Plan: `docs/superpowers/plans/2026-10-04-species-movesets-4c-spider-silk-drop.md`. Branch `feat/spider-drop`.

## Ledger

```text
# SDD ledger — plan: docs/superpowers/plans/2026-10-04-species-movesets-4c-spider-silk-drop.md
Spec: docs/superpowers/specs/2026-10-04-species-movesets-design.md
Pre-flight: Task 1 produces down_pressed/drop_* state, drop_* profile numbers and the runner edge; Task 2 consumes them and produces DropStep.step; Task 3 calls DropStep from VerbRunner after ZipStep; Task 4 consumes drop_up/drop_target in the sandbox and reuses the zip thread node. DropStep shares air_verb_used with ZipStep (ruled: one air verb per airtime, the spec rule). No conflict.
Task 1: complete (commits 91429a7..d3bfe8d, tests: tools/run_tests.sh test_movement → PASS: 120 tests)
Task 2: complete (commits d3bfe8d..19166aa, tests: tools/run_tests.sh test_drop_step → PASS: 12 tests)
Task 3: complete (commits 19166aa..7c98813, tests: tools/run_tests.sh test_verb_runner → PASS: 30 tests)
Task 4: complete (commits 7c98813..198781e, tests: tools/run_tests.sh test_movement → PASS: 126 tests)
Task 4: Ruling: fixed a bug Sean found playing the zip and drop build (hop onto the pillar's wall, then climb: stuck at the top-left corner) inside plan 4c rather than as its own plan — the wall grip left the body up to 2 px off the wall, so the turn over the top corner found no surface and dropped (convex_nothing), and holding toward the wall did not climb because only a walked-in corner set the latch; attach now closes the gap and latches, the zip grip latches too — RED→GREEN in test_surface_step, test_zip_step and the sandbox — cost if wrong: none
Task 5: complete (commits 198781e..2c7c716, tests: tools/run_tests.sh → PASS: 2164 tests)
Final review: debate:run changeset panel (executor, auditor, pentester ran; cartographer not run: no selector assignment and its configured model fails in acpx; executor-b, simplifier, antigravity, deepseek not configured). 7 raw findings, 3 survived verification, 4 refuted; report archived as e241fb70-r1. Pentester: no findings.
Final: Re-graded: gripping a wall from the air or a zip while holding right+down climbs up (Important: the stick says down and the spider goes up); a jump release at the anchor limit gives an upward 60 px/s from the requested reel instead of the resolved one (Minor: about 2 px of rise); the drop's two axis sweeps both start at the unmoved body so a diagonal step can clip a corner by up to 1.5 px before physics recovery (Minor).
Final: minor (deferred): DropStep's jump release uses the requested reel speed, so releasing at the anchor limit with up held launches at -60 px/s; track the resolved vertical speed (a drop_vy) instead.
Final: minor (deferred): DropStep sweeps x and y from the same origin, so a diagonal step into a corner can overlap by up to 1.5 px (physics recovery corrects it, drop_up is not corrected); sweep the second axis from the first's resolved position or sweep the combined motion.
Final: refuted: a ceiling drop cannot start (it can: down moves away from the ceiling, real-physics tests cover the hang-and-drop); a jump out of a drop is consumed before it launches (it is not a launch by design: it lets go with the velocity it has and moves the same tick); the release velocity should be the current vertical velocity (it is: -60 while climbing, 0 hanging, 90 reeling); a mid-drop probe loss leaves drop_up set (callers always supply probes for crawl species).
Final: fixed gripping a wall holding toward it and down climbs up — test_gripping_a_wall_holding_down_and_toward_it_does_not_climb and test_a_zip_onto_a_wall_holding_down_and_toward_it_does_not_climb RED→GREEN, suite 2166/2166
Final: merge gate: full suite on the final code PASS: 2166 tests. Sean's feedback during the build is in the ledger rulings (the hop-onto-the-wall bug) and the plan 4d (slick) and drop-through requests that follow this plan.
```

## Final review (debate:run, changeset mode)

Panel: executor, auditor and pentester ran (codex). The cartographer was not run (no selector assignment; its configured model fails in acpx); executor-b, simplifier, antigravity and deepseek are not configured here. Seven raw findings, three survived verification and four were refuted; the report is archived as `~/.acpx/debate-reports/e241fb70-r1.json`. Panel output, verbatim:

### executor

```text
**Findings**

- **High — A ceiling drop cannot start when called through `VerbRunner`.** In [`verb_runner.gd:20-21`](scripts/movement/verb_runner.gd), any nonzero `surface_n` clears `air_verb_used` before `DropStep.step`. A ceiling drop is then accepted unconditionally by [`drop_step.gd:22-24`](scripts/movement/drop_step.gd), but its anchor is only the same ceiling the spider is already attached to. At the sandbox’s documented hanging position, the cast finds the underside 12 px above the body; [`drop_step.gd:40`](scripts/movement/drop_step.gd) immediately reels down and [`drop_step.gd:76-79`](scripts/movement/drop_step.gd) detects that ceiling contact as a blocked downward move. It does not count as a landing, so the step returns while leaving `drop_up` positive and `surface_n` zero. The spider is stuck “dropping” against the ceiling and never descends. The new sandbox test presses down while holding `down` already high from attachment, so it cannot produce the required fresh press edge either. Preserve the ceiling as a drop start without reeling into it, and ensure a fresh down press can be delivered while hanging.

- **High — Jumping out of a drop clears the drop before the jump input is consumed.** [`drop_step.gd:44-55`](scripts/movement/drop_step.gd) handles a buffered jump, sets `drop_up = 0`, and returns `true`. On the next tick, [`verb_runner.gd:24-27`](scripts/movement/verb_runner.gd) falls through to `SurfaceStep.step`, which reports that the body is airborne, then `GroundAirStep.step` runs. But [`ground_air_step.gd:86`](scripts/movement/ground_air_step.gd) only launches with a live buffer when on the floor or within the coyote window. After a hanging ceiling release, coyote is zero; the buffered press therefore does not launch. Even in the air case where `GroundAirStep` does launch, the release velocity is applied on the following tick, so the body moves one frame later. Carry the release velocity into normal air processing without consuming the jump press as an ordinary airborne jump, and verify the release timing.

- **Medium — Jump release inherits negative or zero reel velocity instead of the specified current vertical velocity.** [`drop_step.gd:47`](scripts/movement/drop_step.gd) assigns `velocity.y` from `_reel_speed`. Releasing while climbing therefore launches upward at −60 px/s; releasing while idle launches with zero vertical velocity, with no gravity applied until the next tick. The plan’s stated release cases require the current descent speed while reeling down and falling from rest when hanging idle. Track the drop’s actual vertical motion and use that value for release.

- **Medium — The plan’s “no probes” guarantee is not enforced during a running drop.** [`drop_step.gd:13-14`](scripts/movement/drop_step.gd) checks for both valid probes before checking `drop_up`. If the caller omits either probe on a later tick, `step` returns `false` while leaving `drop_up > 0`; subsequent movement runs through ordinary air physics, but the state still says a drop is active, so the sandbox keeps drawing the thread and drop pose. A running drop should either continue safely or be explicitly ended when required probes disappear.
```

### auditor

```text
1. **[P2] The separate axis sweeps permit diagonal movement into solid corners.** [drop_step.gd:74](/Users/sean/sites/isekai-game/.worktrees/spider-drop/scripts/movement/drop_step.gd:74):
   > `var hy: Dictionary = i.sweep.call(Vector2(0.0, dy))`

   Both sweeps start at the unchanged body position; line 78 combines their results. In the sandbox, a dropping spider at `(885.5, -64.5)` steering right and down at 60 Hz requests `(1.167, 1.5)`. Neither axis alone hits the tunnel at `(900, -52)`, but their combination overlaps it. The caller applies that displacement directly, leaving physics recovery to correct the penetration without correcting `drop_up`. Sweep the combined motion, or perform the second sweep from the first axis’s resolved position. Add a diagonal corner regression.

2. **[P2] The new wall latch makes down-diagonal input climb upward.** [surface_step.gd:126](/Users/sean/sites/isekai-game/.worktrees/spider-drop/scripts/movement/surface_step.gd:126):
   > `s.surface_sigma = tangent(n).dot(Vector2.UP)`

   Grip the pillar’s left face while holding right+down. `grip_wall` creates a rightward latch and sets upward movement. On subsequent ticks, `_intent` preserves that latch because the normalized diagonal’s dot product with right is approximately `0.707`, exceeding `LATCH_DOT = 0.7`. The spider therefore climbs **up while down is held**. This affects both airborne attachment and zip attachment through the newly added calls. Preserve explicit vertical intent when establishing the latch; default to upward climbing only without vertical input.

3. **[P2] Jump release can manufacture upward velocity while climbing is stopped.** [drop_step.gd:47](/Users/sean/sites/isekai-game/.worktrees/spider-drop/scripts/movement/drop_step.gd:47):
   > `s.velocity = Vector2(s.drop_vx, _reel_speed(i, p))  # let go with what it has: no extra impulse`

   With `drop_up == 12` and up held, `_reel` clamps movement to zero. Pressing jump nevertheless assigns `velocity.y = -60`, because release uses the requested reel speed rather than the permitted motion. Steering beyond the slab’s edge first makes this an unobstructed upward launch from rest. Track the resolved reel velocity and preserve it on release, including zero when the anchor limit or collision stops climbing.

These defects are introduced by this changeset. I inspected the surrounding callers and tests; I did not run the test runner because it writes files.

VERDICT: REVISE
```

### pentester

```text
No exploitable security findings. I reviewed the changed movement code in context, including how the sandbox supplies input and collision results. The changes expose no attacker-controlled path to a shell, file operation, credential, or permission boundary.

VERDICT: APPROVED
```
