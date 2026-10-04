# Species movesets 6a (the wolf: pounce, vault, skid): execution ledger and final review

Plan: `docs/superpowers/plans/2026-10-04-species-movesets-6a-wolf.md`. Branch `feat/wolf`. Requested by Sean: "start on the wolf then do the bipedal goblin".

## Ledger

```text
# SDD ledger — plan: docs/superpowers/plans/2026-10-04-species-movesets-6a-wolf.md
Spec: docs/superpowers/specs/2026-10-04-species-movesets-design.md
Pre-flight: Task 1 produces BurstDef run_fraction/aimed/ends_at_wall, MoveInput.touching_hostile, MoveState.pounce_hit and the wolf pounce row (VerbRunner consumes them); Task 2 produces MoveInput.step_ahead, the vault profile numbers and VaultStep (called from VerbRunner after GroundAirStep); Task 3 produces MoveState.skidding and skid_speed; Task 4 consumes all of them in the sandbox and SpeciesLook. VerbRunner is touched by Tasks 1 and 2 (different parts: _begin/_ended/_bursts vs the post-step call). No conflict.
Task 1: Ruling: pounce rise bound is 33–37 px in the test, not ≤33.5 — the sim steps at 60 Hz and explicit Euler adds v·dt/2 (2.5 px) to 300²/(2·1344)=33.5; still far under the base jump's 60 px — cost if wrong: none, the number is in data
Task 1: complete (commits 5d84c1e..c11e9e0, tests: tools/run_tests.sh test_verb_runner → PASS: 41 tests)
Task 2: complete (commits c11e9e0..a4025f3, tests: tools/run_tests.sh test_vault_step → PASS: 7 tests)
Task 3: complete (commits a4025f3..393dc6a, tests: tools/run_tests.sh test_movement_ground → PASS: 9 tests)
Task 4: Ruling: the vault probe looks VAULT_LOOKAHEAD 0.12 s of travel (min 6 px) ahead of the leading edge, not a fixed 6 px — at 230 px/s a hop started 6 px before a 16 px step has risen only ~7 px at the step's face (the impulse needs ~0.09 s to clear it), so the body would hit the step's side; cost if wrong: a number in the sandbox
Task 4: Ruling: _wall_side reports a wall on the floor for a species whose burst ends_at_wall (the wolf) — the pounce runs along the floor into the slick block and must end there; others keep 0 on the floor; cost if wrong: none for other species
Task 4: guard test test_a_40_px_ledge_is_not_vaulted_at_any_speed passed before the probe existed (it pins the 24 px limit once it does); the slime-tackles and spider-zips unchanged checks are the existing test_the_slime_still_tackles_on_the_same_button and test_a_zip_pulls_the_spider_to_a_wall_and_it_grips
Task 4: complete (commits 393dc6a..161967b, tests: tools/run_tests.sh test_movement_sandbox → PASS: 75 tests)
Task 5: complete (commits 161967b..bf9bcf4, tests: tools/run_tests.sh → PASS: 2227 tests)
Final: panel executor/auditor/pentester (codex, one lab; executor and pentester approved with no findings, cartographer dropped as the known always-failing seat; executor-b/simplifier/antigravity/deepseek not configured): 3 findings survived verification, 0 refuted
Final: fixed vault overrides a pounce begun the same tick (and vaults a step behind it) — test_a_vault_never_overrides_a_pounce_begun_on_the_same_tick + test_no_vault_while_a_pounce_is_running RED→GREEN, suite 2231/2231
Final: fixed an air pounce inherits the released jump's extra gravity (s.jumping left set) — test_an_air_pounce_after_a_released_jump_is_not_slowed_by_the_release RED→GREEN, suite 2231/2231
Final: fixed contact on the tick the pounce expires dropped (latch after the end check) — test_contact_on_the_tick_the_pounce_expires_still_marks_the_hit RED→GREEN, suite 2231/2231
Final: minor (deferred): a pounce aimed straight down (or down-diagonal) from the floor goes nowhere vertically (the floor zeroes +vy) and still spends the 0.8 s cooldown; the plain-stick case is a feel call for Sean
Final: minor (deferred): a pounce begun pressed against a wall it faces ends at once and spends the cooldown (in the spec)
Final: minor (deferred): a wolf between two walls on the floor sees only one wall_side (the one the stick points to first), so pounce_ends_at_wall may miss the other
Final: minor (deferred): the vault's lookahead (0.12 s) is a sandbox number; the game's caller (wiring plan) must probe the same way or tune it
Final: suite on the tree merged with main (bc9ad88, the soul opening): 2280/2280 at --fixed-fps 60
```

## Final review

`debate:run` on the changeset against 34c8baf (+654/-12, 21 files): executor and pentester (codex, medium and xhigh) approved with no findings; auditor (codex, high) returned three findings, all verified, all fixed test-first (see the Final lines). The panel was one lab (the openai models); antigravity is removed from the debate config, `cartographer` always fails, and `executor-b`, `simplifier` and `deepseek` are not configured here.
