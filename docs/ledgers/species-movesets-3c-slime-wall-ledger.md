# Species movesets 3c (slime wall, ball, crawl, forgiving press): execution ledger and final review

Plan: `docs/superpowers/plans/2026-10-04-species-movesets-3c-slime-wall-ball-crawl.md`. Branch `feat/slime-wall`. Rulings below are in the order they were made; the plan text was not rewritten after them (it still names the first, cone-shaped ball and the 0.3 s ball timer).

## Ledger

```text
# SDD ledger — plan: docs/superpowers/plans/2026-10-04-species-movesets-3c-slime-wall-ball-crawl.md
Spec: docs/superpowers/specs/2026-10-04-species-movesets-design.md
Pre-flight: Task 2 produces the wall fields, Tasks 3-5 consume them (WallStep reads wall_*, last_vx, wall_touch); Task 3 produces WallStep.contact/jump and the lock skip, Tasks 4-5 extend them; Task 6 produces clip_for(wall, ball) and ball_scale/crawl_scale, Tasks 7-8 consume them. No conflict found.
Task 1: Ruling: test_movement_release's chain test pinned reset-at-landing; retargeted to run the 0.08 s grace out first — the plan moves the reset from the landing tick to grace expiry — cost if wrong: one test edit
Task 1: complete (commits e272bfe..e40c906, tests: tools/run_tests.sh test_movement → PASS: 59 tests)
Task 2: complete (commits e40c906..24f0019, tests: tools/run_tests.sh test_movement → PASS: 62 tests)
Task 3: complete (commits 24f0019..354bcde, tests: tools/run_tests.sh test_movement → PASS: 67 tests)
Task 4: complete (commits 354bcde..6869f46, tests: tools/run_tests.sh test_movement → PASS: 73 tests)
Task 5: complete (commits 6869f46..c37f1c4, tests: tools/run_tests.sh test_movement → PASS: 82 tests)
Task 6: complete (commits c37f1c4..0db1c27, tests: tools/run_tests.sh test_species_look → PASS: 13 tests)
Task 7: complete (commits 0db1c27..5e3361c, tests: tools/run_tests.sh test_movement → PASS: 86 tests)
Task 8: Ruling: a plain landing's squash and land frame now start one tick after touching down (judged once the step says whether it bounced) — a ball must replace the squash, and the step only knows next tick — cost if wrong: a 16 ms delay on the land frame
Task 8: complete (commits 5e3361c..0384303, tests: tools/run_tests.sh test_movement → PASS: 92 tests)
Task 9: Ruling: the full suite is deferred to the merge gate (it takes over 8 minutes and killed itself at the runner's 480 s ceiling twice); tasks 1-9 ran the movement, verb, species-look, slime, sandbox and spring suites — Sean asked not to burn time on it — cost if wrong: an unrelated suite regression is found at the merge gate instead
Task 9: complete (commits 0384303..3e28d43, tests: tools/run_tests.sh test_movement → PASS: 92 tests)
Final review: debate:run changeset panel (executor, auditor, pentester ran; cartographer failed: acpx did not advertise gpt-6-luna; executor-b, simplifier, antigravity, deepseek not configured). 4 findings survived verification (0 refuted), report archived as 16c31f3a-r1. Pentester: no findings.
Final: Re-graded: bounce-during-Tackle keeps the burst (Important: the slime bounces still in the tackle pose and cannot show the ball); ball keeps spring deformation (Important: it is the cone/elongated shape Sean reported); rotation survives a species switch (Important, same code); coyote jump plus wall bounce on one tick (Minor).
Final: minor (deferred): a buffered press on first wall contact shortly after leaving a ledge fires the coyote jump and also reflects x (wall bounce) instead of choosing one; a coyote jump should probably suppress the bounce.
Final: fixed bounce-during-Tackle — test_a_tackle_into_a_wall_with_jump_held_reflects_it RED→GREEN, test_verb_runner 20/20
Final: Ruling: the ball is drawn by a new SlimeBall (a round pixel-art body in the slime's palette, only the eyes roll) and the squared-and-spun `fall` frame, SpeciesLook.ball_scale and the sprite rotation are gone — Sean tried the sandbox and said the cone-shaped ball was wrong ("a bouncing ball ... eyes can roll around"), and it also resolves the two review findings on spring stretch and a rotation surviving a species switch — cost if wrong: SlimeBall is a stand-in until the art has a round frame
Final: fixed ball keeps spring deformation and rotation survives a species switch — test_a_timed_rebound_lands_as_a_ball_not_a_squash and test_switching_species_mid_bounce_leaves_nothing_of_the_ball_behind RED→GREEN, test_movement_sandbox 28/28, test_slime_ball 5/5, test_species_look 12/12
Final: fixed a wall bounce leaves the tackle pose — test_a_wall_bounce_shows_the_ball_not_the_tackle GREEN with the burst ended
Final: Ruling: the ball lasts the whole bounce (a bool cleared by a plain landing, a Tackle, a wall grip or any other launch) instead of a 0.3 s timer — Sean: 'the eyes can continue spinning until I am no longer a ball' — cost if wrong: one constant and a bool to revert; the plan text still names the old BALL_SECONDS
Final: merge gate: full suite on b302aeb (main c65b202 merged in) PASS: 2012 tests, no SCRIPT ERROR or Parse Error. Sean tried the sandbox between fixes and approved the round ball with rolling eyes ("it looks good now").
```

## Final review (debate:run, changeset mode)

Panel: executor, auditor and pentester ran (codex, xhigh floor, selector picked gpt-6-luna medium, gpt-6-astra medium, gpt-6-sol xhigh). Cartographer failed (acpx did not advertise gpt-6-luna). executor-b, simplifier, antigravity and deepseek are not configured on this machine. Four findings survived verification (none refuted); the report is archived as `~/.acpx/debate-reports/16c31f3a-r1.json`. Findings and what became of them are in the ledger above (three fixed with tests, one minor deferred). Panel output, verbatim:

### executor

```text
- **A wall bounce during Tackle keeps the Tackle active.** In [wall_step.gd](/Users/sean/sites/isekai-game/.worktrees/slime-wall/scripts/movement/wall_step.gd:19), a qualifying contact reverses `velocity.x` but leaves `s.verb` and `s.verb_left` untouched. The slime’s Tackle lasts 0.18 seconds and has no deceleration ([slime.tres](/Users/sean/sites/isekai-game/.worktrees/slime-wall/data/movement/slime.tres)); `VerbRunner` therefore continues to treat the reversed motion as an active Tackle ([verb_runner.gd](/Users/sean/sites/isekai-game/.worktrees/slime-wall/scripts/movement/verb_runner.gd:64)). The character bounces away while still in the tackle state and tinted as if tackling; the verb can also block horizontal steering until it expires. End or otherwise resolve the active burst on bounce, and cover the state transition in the Tackle wall-contact test.

- **A buffered press can turn the intended contact bounce into a coyote jump.** `WallStep.contact` marks `wall_bounced` before `_jump` runs ([ground_air_step.gd](/Users/sean/sites/isekai-game/.worktrees/slime-wall/scripts/movement/ground_air_step.gd:18–20)), but `_jump` can then launch a coyote jump before `WallStep.jump` gets a chance to select the wall jump ([ground_air_step.gd](/Users/sean/sites/isekai-game/.worktrees/slime-wall/scripts/movement/ground_air_step.gd:86)). `WallStep.jump` exits once anything has launched ([wall_step.gd](/Users/sean/sites/isekai-game/.worktrees/slime-wall/scripts/movement/wall_step.gd:43)). Thus, shortly after leaving a ledge, a buffered press on first wall contact with jump held can produce `"coyote"` plus a wall bounce instead of the documented wall jump. Prioritize the wall jump at contact when its buffer and grace conditions are met, or explicitly prevent the coyote branch from consuming that press.

VERDICT: REVISE
```

### auditor

```text
Found two regressions introduced by this diff:

1. **[P2] Switching species during a bounce preserves the ball’s rotation.** In [movement_sandbox.gd:259](/Users/sean/sites/isekai-game/.worktrees/slime-wall/scripts/movement/movement_sandbox.gd:259), `if profile.id != "slime":` immediately returns `Vector2.ONE`, bypassing `_sprite.rotation = 0.0` at line 270. Bounce as slime, then press 3 or 4 while the ball is spinning: the shared sprite keeps its current angle indefinitely as wolf or spider. `set_profile()` and `_set_look()` do not reset it. Reset rotation when switching profiles or before the non-slime return, and cover this transition in a sandbox test.

2. **[P2] The rendered ball retains spring deformation instead of staying square.** [movement_sandbox.gd:267](/Users/sean/sites/isekai-game/.worktrees/slime-wall/scripts/movement/movement_sandbox.gd:267) uses `out *= SpeciesLook.ball_scale(_sheet.frame_size(frame))`, where `out` already contains the spring scale. Although landing judgment calls `calm()`, line 180 runs `_spring.update(state.velocity.y, delta)` before drawing. Any upward rebound immediately stretches it again: [squash_spring.gd:21](/Users/sean/sites/isekai-game/.worktrees/slime-wall/scripts/movement/squash_spring.gd:21) computes `var target := clampf(absf(vy) / 400.0, 0.0, 1.0) * LIMIT`. The resulting ball is elongated while spinning. Assign the ball scale directly, bypassing spring and crawl deformation, and test the rendered dimensions during a rebound.

I inspected the source and callers. I did not run the test runner because it creates and deletes files, violating this review’s read-only constraint.

VERDICT: REVISE
```

### pentester

```text
No exploitable security findings. I reviewed the changed movement code in its surrounding sandbox, input, profile, and asset loading paths. I did not run tests because this was a read-only review.

VERDICT: APPROVED
```

### cartographer

```text
acpx error (exit 1):

[acpx] error: RUNTIME Cannot apply --model "gpt-6-luna": the ACP agent did not advertise that model. Available models: gpt-5.6-sol[low], gpt-5.6-sol[medium], gpt-5.6-sol[high], gpt-5.6-sol[xhigh], gpt-5.6-sol[max], gpt-5.6-sol[ultra], gpt-5.6-terra[low], gpt-5.6-terra[medium], gpt-5.6-terra[high], gpt-5.6-terra[xhigh], gpt-5.6-terra[max], gpt-5.6-terra[ultra], gpt-5.6-luna[low], gpt-5.6-luna[medium], gpt-5.6-luna[high], gpt-5.6-luna[xhigh], gpt-5.6-luna[max], gpt-5.5[low], gpt-5.5[medium], gpt-5.5[high], gpt-5.5[xhigh].
```
