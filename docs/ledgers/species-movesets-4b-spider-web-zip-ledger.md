# Species movesets 4b (the spider's web zip): execution ledger and final review

Plan: `docs/superpowers/plans/2026-10-04-species-movesets-4b-spider-web-zip.md`. Branch `feat/spider-zip`.

## Ledger

```text
# SDD ledger — plan: docs/superpowers/plans/2026-10-04-species-movesets-4b-spider-web-zip.md
Spec: docs/superpowers/specs/2026-10-04-species-movesets-design.md
Pre-flight: Task 1 produces aim/cast on MoveInput, zip_* on MoveState/MovementProfile and FakeSurfaceWorld.cast; Task 2 consumes them and produces ZipStep.step/direction; Task 3 calls ZipStep from VerbRunner; Task 4 consumes the zip state in the sandbox. ZipStep reuses SurfaceStep.HT/HN/tangent and the surface_shift displacement channel (the sandbox applies it only while attached today: Task 4 changes that, ruled as the fix for the plan 4a deferred minor). No other conflict.
Task 1: complete (commits f23da0a..efc488a, tests: tools/run_tests.sh test_movement → PASS: 111 tests)
Task 2: Ruling: ZipStep.direction takes the already-resolved cast aim (normalised, ZERO for the facing) and does not snap to 8 ways — the player's cast_aim() already returns a pointer's free direction or the left stick 8-way, so the caller resolves it (the sandbox snaps its stick) — cost if wrong: move the snap into direction()
Task 2: complete (commits efc488a..b137d32, tests: tools/run_tests.sh test_zip_step → PASS: 10 tests)
Task 3: complete (commits b137d32..4cfd970, tests: tools/run_tests.sh test_verb_runner → PASS: 26 tests)
Task 4: Ruling: the sandbox applies surface_shift on every tick a crawler is off a surface (a zip pulls it, a ledge fall and a drop use it), and a sliver ledge's convex_nothing now sets the shift to the motion instead of the 19 px wrap — resolves the plan 4a deferred minor; found while wiring the zip — cost if wrong: none
Task 4: complete (commits 4cfd970..02f3c5d, tests: tools/run_tests.sh test_movement → PASS: 118 tests)
Task 5: complete (commits 02f3c5d..747d3e8, tests: tools/run_tests.sh → PASS: 2132 tests)
Final review: debate:run changeset panel (executor, auditor, pentester ran; cartographer not run: no selector assignment and its configured model fails in acpx; executor-b, simplifier, antigravity, deepseek not configured). 3 raw findings, 2 survived verification, 1 refuted; report archived as d73f6b3d-r1. Pentester: no findings.
Final: Re-graded: a diagonal downward cast anchors on a one-way ledge's side (Important: confirmed in real physics, the zip would pull the spider into the ledge); a stale surface_event after a corner makes the sprite trail the body by ~13 px for the whole zip (Important by effect: it sits on the signature verb and lasts the whole pull, though it needs a corner on the tick before the zip).
Final: refuted: the wall-grip correction moves the spider into the wall (the wall box is narrower, 24 against 28, so shifting 2 px toward the wall is exactly flush; the tests pin x 188 and 388).
Final: fixed diagonal cast anchors on a one-way ledge's side — test_cast_down_a_diagonal_ignores_a_ledges_side_and_finds_what_is_beyond and test_a_diagonal_cast_down_past_a_ledge_ignores_its_side RED→GREEN (the sandbox's real-physics ray confirmed the bug before the fix); suite 2135/2135
Final: fixed stale surface_event during a zip — test_a_zip_starting_right_after_a_corner_does_not_carry_the_corner_event RED→GREEN
```

## Final review (debate:run, changeset mode)

Panel: executor, auditor and pentester ran (codex). The cartographer was not run (no selector assignment; its configured model fails in acpx); executor-b, simplifier, antigravity and deepseek are not configured here. Three raw findings, two survived verification and one was refuted; the report is archived as `~/.acpx/debate-reports/d73f6b3d-r1.json`. Panel output, verbatim:

### executor

```text
- [scripts/movement/zip_step.gd](/Users/sean/sites/isekai-game/.worktrees/spider-zip/scripts/movement/zip_step.gd:71): The wall-grip correction moves the spider **into** the wall. `normal` points out of the surface, but subtracting `normal * 2` shifts the body opposite the normal. For a left-facing wall (`normal == Vector2.LEFT`), that shifts it right by 2 px; the wider wall-crawl box then overlaps the wall. `_crawl()` tries to resolve that overlap with `move_and_collide(Vector2.ZERO)`, so wall zips rely on depenetration to recover. Add the correction along the normal instead, and cover both wall orientations with a test.

VERDICT: REVISE
```

### auditor

```text
1. **[P2] Downward diagonal casts accept a one-way ledge’s side.**  
   [movement_sandbox.gd:290](/Users/sean/sites/isekai-game/.worktrees/spider-zip/scripts/movement/movement_sandbox.gd:290):
   > `var hit := get_world_2d().direct_space_state.intersect_ray(q)`

   `_cast` returns this hit without checking its normal. From `(130, -77)`, aiming down-right misses the existing ledge’s top at `(157, -50)` but intersects its left side at `(160, -47)`. The zip accepts that invalid anchor instead of continuing to the floor at `(207, 0)`. The new fake cast has the same defect: [fake_surface_world.gd:156](/Users/sean/sites/isekai-game/.worktrees/spider-zip/tests/support/fake_surface_world.gd:156) uses `var hit := _enter_segment(a, b, r)` without restricting the entry face.

   Accept only upward-facing one-way hits, continue searching past rejected hits, and add this diagonal-side case to both probe tests.

2. **[P2] Starting a zip after a corner repeatedly applies corner animation displacement.**  
   [verb_runner.gd:21](/Users/sean/sites/isekai-game/.worktrees/spider-zip/scripts/movement/verb_runner.gd:21):
   > `return  # a thread pulling the spider owns the body until it grips or cancels`

   This bypasses `SurfaceStep`, which normally clears `surface_event`. `ZipStep` clears `zip_event` and `surface_shift`, but leaves `surface_event` unchanged. Fire immediately after a `"convex"` or `"concave"` tick—for example, after rounding onto the first block’s top, zip right toward the second block—and every pull tick reaches the existing [movement_sandbox.gd:381](/Users/sean/sites/isekai-game/.worktrees/spider-zip/scripts/movement/movement_sandbox.gd:381):
   > `_vis_off += _prev_pos - body.global_position`

   The sprite consequently trails its collision body by approximately 13 extra pixels at 60 Hz. The animation consumer is outside the diff; the new early return introduces the stale-event path. Clear the per-tick surface event when the zip takes ownership and test a corner-to-zip transition.

Static review only; tests were not run because the runner writes files.

VERDICT: REVISE
```

### pentester

```text
I found no exploitable security path in this changeset. The zip takes local input and physics results; the reviewed code introduces no shell, file, network, or credential handling. Review was read-only, and I did not run tests.

VERDICT: APPROVED
```
