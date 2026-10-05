# Species in the real Player (D1 to D4): execution ledger

Plan: `docs/superpowers/plans/2026-10-05-species-body-d.md`. Branch feat/species-body, merged to main locally. Final suite 2825 tests.

```
Spec: roadmap D1-D4. Baseline 2776 (main 00c3ebb).
Pre-flight: T1 SpeciesBody/for_species consumed by T2 (Player species path) and T3 (same body, more species); T2 species_body/uses_species_body consumed by T3; T4 Player.species consumed by Game. T2/T3 touch player.gd _physics_process: T3 extends T2's path only. No conflicts.
Task 1: Ruling: the move is split in two calls after fill_input: think (the species step) and move (pull, box, an adjust hook, move_and_slide), so the sandbox keeps its thread, dust and landing judgement between them and the Player can apply water — cost if wrong: none
Task 1: Ruling: the sandbox keeps thin _apply_box and _cast delegates because two of its 84 tests call them, so its tests stay untouched as the refactor's safety net — cost if wrong: two one-line methods
Task 1: complete (commits 224931e..ae9ed72, tests: tools/run_tests.sh → PASS: 2785 tests)
Task 2: Ruling: a species body adopts whatever wrote the Player's velocity since last tick (a room slide, an ability) at the start of each tick, instead of every writer also updating the species state — cost if wrong: a writer that sets velocity mid-tick after the move is picked up one tick later
Task 2: Ruling: a species body eats with no cover animation (the cover is the slime's own frames) and, with no sheet, draws the old slime frames — both until the species have their own art (G1) — cost if wrong: a wolf eating shows no engulf animation
Task 2: complete (commits ae9ed72..bf59e5b, tests: tools/run_tests.sh → PASS: 2797 tests)
Task 3: Ruling: a species body that finds itself more than 4 px from where its last tick left it (Recall, a placement) lets go of its surface and thread — the crawl state otherwise kept a teleported spider 'attached' in mid-air (found by debugging the silk-drop test) — cost if wrong: none
Task 3: Ruling: the rooms' one-way ledges are layer-1 solids with a one-way shape, while SpeciesBody's probes and drop-through expect layer 2 (the sandbox's) — so on a real ledge a species body probes it as a hard solid and cannot drop through it; the slime cannot either — cost if wrong: a spider zips to a ledge's side and hangs under one
Task 3: complete (commits bf59e5b..1ec5760, tests: tools/run_tests.sh → PASS: 2812 tests)
Task 4: Ruling: Game.species_arg returns '' (no override) for an absent, bare or unknown --species flag, not 'slime' as the plan said — 'slime' would have overridden the goddess's pick — cost if wrong: none
Task 4: Ruling: the species are set with Player.set_species after the start is resolved (the Player is built before the pending pick is read), rather than before setup() — cost if wrong: set_species rebuilds the body once more at start
Task 4: Ruling: the goblin and the undead unlock on stand-in creatures (3 armed ants, 3 bog lizardmen) until the goblin and skeleton creatures exist (F1); the wolf (defeat a gloom wolf) and the spider (eat or defeat 5 spiders) use real ones — cost if wrong: the first two species unlock by an arbitrary rule for now
Task 4: complete (commits 1ec5760..cf58908, tests: tools/run_tests.sh → PASS: 2820 tests)
Final review: debate panel (executor, auditor, cartographer, pentester; round 1 REVISE). 8 survived, 0 refuted.
Final: fixed species bodies ignored the rope (attach, swing, reel, stay within it, jump to let go) — test_a_wolf_swings_on_a_rope_stays_within_it_and_a_jump_lets_go RED→GREEN, suite 2820+/pass
Final: fixed a species jump in water was a dry jump (no bob or surface launch) — test_a_wolf_in_water_bobs_instead_of_jumping RED→GREEN
Final: fixed species jumps never counted for Leap — test_a_species_jump_is_a_jumped_event RED→GREEN
Final: fixed a spider on a surface discarded ability impulses — test_an_ability_impulse_moves_a_spider_standing_on_the_floor RED→GREEN (the impulse detaches it for 0.3 s)
Final: fixed a missing species sheet left the slime's sheet under the spider drawing (invalid frame keys) and drew slime art — test_a_spider_whose_sheet_is_missing_still_draws_something_while_slime_art_exists RED→GREEN (no sheet: the old frames, tinted per species)
Final: minor (deferred): movement_sandbox.gd's header still says "Keys 1 to 3 pick biped, slime or wolf" though key 4 picks the spider (predates this branch)
```
