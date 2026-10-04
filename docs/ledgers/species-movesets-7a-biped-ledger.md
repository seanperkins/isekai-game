# Species movesets 7a (the biped: roll, slide, mantle, wall jump, and the goblin): execution ledger and final review

Plan: `docs/superpowers/plans/2026-10-04-species-movesets-7a-biped.md`. Branch `feat/biped`. Requested by Sean: "start on the wolf then do the bipedal goblin"; after playing the sandbox he asked for a real body ("its just a box") and a mantle that grabs a ledge hit half way up.

## Ledger

```text
# SDD ledger — plan: docs/superpowers/plans/2026-10-04-species-movesets-7a-biped.md
Spec: docs/superpowers/specs/2026-10-04-species-movesets-design.md
Pre-flight: Task 1 produces BurstDef max_start_speed/iframes/cooldown_group, MoveState invulnerable/crouched and the biped's roll/slide rows (VerbRunner consumes them); Task 2 is data only (biped.tres wall numbers; WallStep consumes); Task 3 produces MoveInput.mantle, MoveState mantle_*/queued_jump, profile mantle numbers, MantleStep, the biped's `mantle` verb (VerbRunner calls it; Task 2's `verbs` line becomes ["wall","mantle"], one edit of biped.tres); Task 4 consumes Task 1 (invulnerable, crouched, is_flat) and Task 3 (mantle probe) in the sandbox. VerbRunner is touched by Tasks 1 and 3 (different parts). No conflict.
Task 1: Ruling: test_species_without_a_tackle_row_ignore_the_button used the biped as the species with no burst row; the biped now has roll/slide, so it checks the spider (button = zip, no probes) and is renamed _without_a_burst_row_ — cost if wrong: none
Task 1: complete (commits 40d8228..6260ceb, tests: tools/run_tests.sh test_verb_runner → PASS: 53 tests)
Task 2: Ruling: test_the_other_species_have_no_wall_kit listed the biped; the biped now has the wall verb (spec: innate), so it covers the wolf and spider and is renamed; the biped's own numbers are pinned by test_the_biped_has_the_wall_verb_with_the_spec_numbers — cost if wrong: none
Task 2: guard test test_the_biped_does_not_bounce_off_a_wall passed before the numbers existed (wall_bounce_keep defaults to 0)
Task 2: complete (commits 6260ceb..b97901a, tests: tools/run_tests.sh test_movement_wall → PASS: 24 tests)
Task 3: complete (commits b97901a..c9f5d8b, tests: tools/run_tests.sh test_mantle_step → PASS: 9 tests)
Task 4: Ruling: the sandbox wall-jump test uses the left end wall (as the slime's does), not the shaft — one wall kick and the no-stick slide are what is pinned; the shaft climb is the same two kicks and stays an open scenario
Task 4: the mantle test does not assert air_verb_used: wall contact (the biped has the wall verb) refreshes the air verb every tick the body is beside the wall, which is the spec rule (touching a wall gives the air verb back); the 6 px reach is the ceiling that keeps the mantle's added reach bounded
Task 4: guard tests that passed before the probe/visuals existed: the tunnel crouch, the box duck, the one-way and too-low mantle refusals, the wall slide and kick (the model already did them; they pin the sandbox wiring)
Task 4: complete (commits c9f5d8b..62e68f9, tests: tools/run_tests.sh test_movement_sandbox → PASS: 81 tests)
Task 5: Ruling: test_wall_contact_refreshes_the_air_tackle used the biped as the species without the wall verb; it uses the wolf now (the biped's wall verb is the spec's) — found by the full suite, not the Task 2 filter (test_movement does not match test_verb_runner); cost if wrong: none
Task 5: complete (commits 62e68f9..e313968, tests: tools/run_tests.sh → PASS: 2310 tests)
Final: panel executor/auditor/codex-regression (codex, gpt-6 luna/sol/astra) and omp-auditor (glm-5.2): 7 findings survived verification (4 major, 1 minor, 1 minor, 1 nit), 1 refuted (two plan-listed sandbox tests absent: documented deviations); no pentester (no untrusted input in this diff)
Final: fixed a mantle extends a roll's invulnerability (the burst keeps running) — test_a_mantle_taking_the_body_ends_a_running_roll_and_its_invulnerability RED→GREEN, suite 2315/2315
Final: fixed mantle pull not swept (a ceiling over the approach was crossed) — test_a_mantle_into_a_ceiling_on_the_way_up_is_stopped RED→GREEN, suite 2315/2315
Final: fixed a queued jump after a mantle becomes a wall jump (stale wall grace) — test_a_queued_jump_after_a_mantle_is_never_a_wall_jump RED→GREEN (the first draft passed vacuously: on_floor defaulted true so the mantle never started; fixed and re-watched fail), suite 2315/2315
Final: fixed a puddle ending with room still crouched for a tick (slime slowed 137→114 px/s) — test_a_puddle_that_ends_with_room_to_stand_does_not_slow_that_tick RED→GREEN, suite 2315/2315
Final: fixed the mantle's room check measured the flat box while crouched — test_a_crouched_biped_does_not_mantle_where_the_standing_box_does_not_fit RED→GREEN (the first two slab placements passed vacuously: the probe's ray hit the slab first; re-aimed, watched fail without the fix, restored), suite 2315/2315
Final: minor fixed with the above: launched cleared at mantle start (latent, no test); the one-tick crouched-in-the-air nit is gone with the puddle fix (room above clears the crouch on the end tick)
Art (Sean, after trying the sandbox: "its just a box"): Ruling: generated the goblin sheet with the project's own pipeline (Codex $imagegen, 14 frames: idle 2, run 4, rise, fall, roll 2, slide, mantle 2, wall; tools/art/goblin_frames.json, art_source/frames/goblin, assets/sheets/goblin.*), one shared scale (standing 39 px tall; the lizard reference gave the palette and outline), roll and slide sized to 16 px tall so they fit the 12 px duck gap (the `anchor` key was dropped, it forces one scale); SpeciesLook gained the biped arm and enemy_clips.json a `goblin` entry; the sandbox shows it. Cost if wrong: tuning (sizes in the JSON) or regenerating a frame (generate_frames.py goblin <frame>)
Art: look tests were written before the code but not run RED (has_look("biped") was false before, so test_which_species_have_a_look could not have passed); the sandbox look tests passed on the first run with the sheet in place
Mantle (Sean playing, 'He doesn't mantle up onto a ledge if you hit it half way up'): Ruling: mantle_reach 6 → 32 px and the rising-speed limit (40 px/s) removed — the spec's 6 px corner assist missed every ledge hit before the top of a jump, which is what a mantle is for; the hands reach a little over the head. Added reach: a base jump now mantles ledges up to ~92 px (the sandbox's 100 px ledge still needs the boost); the reach-model plan must carry it. Cost if wrong: two numbers in biped.tres/profile defaults
Final: minor (deferred): a blocked mantle retries every tick while the stick stays toward the wall and the body is still within reach (each retry sweeps and aborts, so it costs one test_move a tick; the body falls out of reach in a few ticks)
Final: minor (deferred): a jump out of a roll or slide ends it and the roll's speed bleeds at the biped's air control (a rolling leap that carries the speed is a tuning question for Sean; in the spec)
Final: minor (deferred): the shaft climb by wall jumps has no scenario of its own (the same two kicks as the slime's; in the spec)
Final: suite on the tree merged with main (ba07d27, docs only): 2317/2317 at --fixed-fps 60
```

## Final review

`debate:run` on the changeset against 54d466e (+792/-23, 17 files): executor (gpt-6 luna, medium), auditor (gpt-6 sol), codex-regression (gpt-6 astra, high) and omp-auditor (glm-5.2, high). 7 findings survived verification (4 major, 2 minor, 1 nit), 1 was refuted (two plan-listed sandbox tests absent: documented deviations); all but the nit and the latent minor were fixed test-first (see the Final lines; the nit went away with the puddle fix). omp-auditor approved. The panel was two labs; antigravity is removed from the debate config.

## After the review

Sean's play feedback: the goblin art (14 frames through the project's Codex pipeline) and a mantle reach of 32 px with no rising limit; both are in the ledger above and the spec.
