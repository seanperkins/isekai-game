# Species movesets 4a (the spider's surface crawl): execution ledger and final review

Plan: `docs/superpowers/plans/2026-10-04-species-movesets-4a-spider-surface.md`. Branch `feat/spider-surface`. Spike and findings: `docs/research/spider-crawl-spike.md`; feel rules: `docs/research/spider-locomotion.md`.

## Ledger

```text
# SDD ledger — plan: docs/superpowers/plans/2026-10-04-species-movesets-4a-spider-surface.md
Spec: docs/superpowers/specs/2026-10-04-species-movesets-design.md, docs/research/spider-crawl-spike.md
Pre-flight: Task 1 produces MoveInput/MoveState/MovementProfile fields and the public GroundAirStep.timers; Tasks 3-5 consume them. Task 2 produces FakeSurfaceWorld (consumes nothing); Tasks 3-5 consume it. Task 3 produces SurfaceStep.step/tangent/box_size; Tasks 4-5 extend step, Task 6 calls it, Tasks 7-8 consume surface_n/surface_shift. Task 5 reuses surface_lock for both the corner lockout and the re-attach lock after a hop (same 0.1 s) - ruled: one field, documented. The attach tick returns true (it owns the body) with velocity zeroed - ruled, the plan text says only "attaches". No other conflict.
Task 1: complete (commits f6ce249..6b469a2, tests: tools/run_tests.sh test_movement → PASS: 99 tests)
Task 2: Ruling: wrote the fake world's tests and implementation in one step, so the first run was green; verified the tests can fail by mutating the face sign and the box swap (2 of 6 failed), then restored — a RED step observed after the fact — cost if wrong: none, the mutation covered both behaviours
Task 2: complete (commits 6b469a2..53c1763, tests: tools/run_tests.sh test_fake_surface_world → PASS: 6 tests)
Task 3: Ruling: along-surface speed is instant (full speed or none) — 0.03 s and 0.02 s are under two ticks and the spike's instant model played well; the profile's ground_* times stay for the ground step — cost if wrong: add an accel clamp in SurfaceStep
Task 3: complete (commits 53c1763..66a4de7, tests: tools/run_tests.sh test_surface_step → PASS: 6 tests)
Task 4: Ruling: the latch captures the stick's dominant axis, not its raw direction (the spike captured the raw one) — the noisy-input test stranded the spider on a wall when a (1, 0.5) stick set the latch and a later (1, -0.5) fell outside its 45 degree cone — cost if wrong: a stick held exactly diagonal (0.7, -0.7) latches vertical at a corner (a tie goes to y); deferred, not tested
Task 4: complete (commits 66a4de7..06865bb, tests: tools/run_tests.sh test_surface_step → PASS: 13 tests)
Task 5: Ruling: a ledge fall and a convex_nothing also set the re-attach lock (0.1 s) — the body is still over the ledge by a hair on the next tick and re-gripped it at once (the fake-world test showed it) — cost if wrong: none
Task 5: complete (commits 06865bb..e88397e, tests: tools/run_tests.sh test_surface_step → PASS: 21 tests)
Task 6: complete (commits e88397e..4929141, tests: tools/run_tests.sh test_verb_runner → PASS: 23 tests)
Task 7: Ruling: the one-way ledge is Rect2(160, -50, 100, 6) (left of the first ledge) not (1150, -50, 100, 6) — at 1150 its end was 10 px from the shaft wall, so a spider dropped off the end gripped the wall instead of falling to the floor (found by the real-collision test) — cost if wrong: the plan text names the old position
Task 7: complete (commits 4929141..771287d, tests: tools/run_tests.sh test_movement → PASS: 105 tests)
Task 8: complete (commits 771287d..4e70098, tests: tools/run_tests.sh test_movement → PASS: 109 tests)
Task 9: complete (commits 4e70098..9856368, tests: tools/run_tests.sh → PASS: 2078 tests)
Final review: debate:run changeset panel (executor, auditor, pentester ran; cartographer not run: the selector gives it no assignment and its configured model fails in acpx; executor-b, simplifier, antigravity, deepseek not configured). 6 raw findings, 4 survived verification, 2 refuted; report archived as 14826831-r1. Pentester: no findings.
Final: Re-graded: a press on the attach tick is lost (Important: a landing press is the forgiving-press case); a floor hop leaves coyote so a second jump follows in the air (Important: breaks the one-hop rule); a wall attach accepted from 19 px but the support probe holds 15 so the next move drops the spider (Important); convex_nothing leaves a displacement the sandbox ignores (Minor: the body falls from where it was, which is the better behaviour).
Final: minor (deferred): the surface_shift contract says the caller applies it every tick, but the sandbox applies it only while attached, so a ledge_fall or convex_nothing tick's shift (at most 2.3 px, or the 19 px wrap for convex_nothing) is ignored; either apply it always (and set convex_nothing's shift to the motion) or document attached-only.
Final: refuted (kept as noted): attach on a floor beside a wall labelled UP (a down ray cannot hit a wall face, the hop lock covers the first tick, and climbing works); stale on_floor after a corner (attach only runs when detached, and every detach goes through move_and_slide).
Final: fixed press on the attach tick lost — test_a_press_on_the_attach_tick_is_kept RED→GREEN, test_surface_step 24/24
Final: fixed floor hop leaves a second jump — test_a_floor_hop_leaves_no_second_jump RED→GREEN
Final: fixed wall grip accepted from beyond what the support probe holds — test_a_wall_grip_needs_the_wall_within_what_the_support_probe_holds RED→GREEN
```

## Final review (debate:run, changeset mode)

Panel: executor (gpt-6-luna medium), auditor (gpt-6-astra high) and pentester (gpt-6-sol xhigh) ran. The cartographer was not run (the selector gives it no assignment and its configured model fails in acpx); executor-b, simplifier, antigravity and deepseek are not configured here. Six raw findings, four survived verification and two were refuted; the report is archived as `~/.acpx/debate-reports/14826831-r1.json`. Dispositions are in the ledger above. Panel output, verbatim:

### executor

```text
- **[scripts/movement/surface_step.gd:86–89](scripts/movement/surface_step.gd:86)** attaches to any surface the downward ray hits while `i.on_floor` is true, including a hard block or wall when the body is pressed against it. After a hop, `on_floor` can still be true for the first physics tick; if the body lands against a wall, this branch labels it as a floor crawl and skips the wall-grip check. The spider can attach with `surface_n == UP` while beside a wall, then fail to climb it. Check that the ray hit is actually below the body and that the contact is a floor before choosing `UP`.

- **[scripts/movement/movement_sandbox.gd:181–184](scripts/movement/movement_sandbox.gd:181)** sets `on_ceiling` and the probes, but does not refresh `on_floor` after `_crawl` moves the body with `move_and_collide(Vector2.ZERO)` at line 260. On a corner turn, floor contact state can therefore describe the previous surface for the next tick. Since `_attach` uses `on_floor` as its floor decision, a stale floor flag can cause the same misclassification above. Refresh contact flags after the crawl move, or derive attachment from the ray hit direction and normal.

- **[scripts/movement/surface_step.gd:167–170](scripts/movement/surface_step.gd:167)** detaches with `"convex_nothing"` but leaves `surface_shift` set to the full wrap displacement computed at line 165. The sandbox then applies that shift in `_crawl` only when `surface_n != ZERO`; here it falls through to normal movement and never applies the shift. In the real sandbox, the first unsupported edge tick therefore leaves the body at its old position instead of moving it to the computed drop point. Clear `surface_shift` or apply the transition displacement in the air path.
```

### auditor

```text
Three defects need changes; all originate in this diff.

1. **[P2] A jump pressed on the attachment tick is lost.**  
   [surface_step.gd:34](/Users/sean/sites/isekai-game/.worktrees/spider-surface/scripts/movement/surface_step.gd:34): `return _attach(s, i)`

   With `surface_n == ZERO`, `buffer == 0`, floor contact and `jump_pressed == true`, attachment returns before the timers capture the press. `VerbRunner` then skips `GroundAirStep`. The sandbox consumes the press, so the next tick has neither a press nor a buffer: the spider never jumps. Process jump input on successful attachment and add a regression covering a fresh press on that tick. The existing test only supplies an already-populated buffer.

2. **[P2] A floor hop leaves an extra airborne jump available.**  
   [surface_step.gd:72](/Users/sean/sites/isekai-game/.worktrees/spider-surface/scripts/movement/surface_step.gd:72): `s.buffer = 0.0`

   `_hop` clears the buffer but leaves coyote time, which the preceding timer call just refilled to `0.1` on the floor. Hop, release, then press again two frames later: attachment remains locked, but the ground step accepts another launch through [ground_air_step.gd:86](/Users/sean/sites/isekai-game/.worktrees/spider-surface/scripts/movement/ground_air_step.gd:86): `if s.buffer > 0.0 and (i.on_floor or s.coyote > 0.0):`

   Clear `s.coyote` when hopping, as the existing ground and wall launch paths do. Test rapid release/repress after a floor hop.

3. **[P2] Wall attachment accepts positions that cannot sustain crawling.**  
   [surface_step.gd:91](/Users/sean/sites/isekai-game/.worktrees/spider-surface/scripts/movement/surface_step.gd:91): `kind = i.ray.call(Vector2.ZERO, Vector2(float(i.wall_side) * (HT + 2.0 * STICK), 0.0), true)`

   This accepts a wall 20 px from the centre without moving the body toward it. Subsequent support checks reach only 15 px.

   Concrete sandbox case: airborne at `(621, -60)`, press right toward the block starting at `x = 640`. The existing 6 px wall probe detects it, and attachment succeeds 19 px from the wall. Press up next: the support ray ends at `x = 636`, misses the uninterrupted wall, and incorrectly triggers `convex_nothing`, dropping the spider. Snap successful wall attachments to the required stand-off distance, or restrict attachment to positions the support probe can maintain. Test attachment followed by crawling from the outer wall-detection range.

Reviewed source and callers directly. Runtime tests were not run because the runner writes logs and results, contrary to this review’s read-only constraint.

VERDICT: REVISE
```

### pentester

```text
No exploitable security path found in this changeset. The new probes are supplied by the local sandbox, and profile selection uses fixed species IDs. This was a read-only security review; I did not run tests.

VERDICT: APPROVED
```
