# Art for the new forms (G1): execution ledger

Plan: `docs/superpowers/plans/2026-10-05-form-art-g1.md`. Branch feat/form-art, merged to main locally. Final suite 2840 tests; Python tests pass.

```
Spec: roadmap G1. Baseline 2825 (main 20c9c1e). Assets and bestiary data copied in before Task 1 (uncommitted).
Pre-flight: T1 FormDef.sprite_frame/FormEffects.look/art_for consumed by T2 (Player draws sprite_frame). No conflicts.
Task 1: Ruling: the raw frames (art_source/frames/forms_*, ~160 MB) are git-ignored and stay on disk; the sheets, the frame specs and the bestiary page data are committed — the repo is already 396 MB and the sheets are what ships — cost if wrong: re-assembling the sheets on another machine needs the frames regenerated
Task 1: Ruling: test_forms' 'no art' expectation now allows a form with a still frame to name its species' sheet — the new forms have art — cost if wrong: none
Task 2: Ruling: a form that has art but no animated clips (every new form) is drawn as its one still on every pose, with no landing squash or run cycle, and eats with no cover animation — until the animated sheets exist — cost if wrong: the new forms look static
Task 1: Ruling: Task 1's standalone full suite failed only in test_player_species (a wolf evolved into a form with a still, which the Player could not draw yet); Tasks 1 and 2 landed together and the full suite below covers both
Task 2: complete (commits abbb295..bc213ff, tests: tools/run_tests.sh → PASS: 2838 tests)
Final review: debate panel (executor, auditor, cartographer; pentester skipped by the lens classifier; round 1 REVISE). 7 survived, 0 refuted.
Final: fixed a still spider kept the base spider's hurt shape, never swelled through evolution and never flashed when hit — test_a_still_spider_has_its_frames_hurt_shape_swells_through_evolution_and_flashes_when_hit RED→GREEN (shared _form_scale/_form_tint; the evolve moment now draws the species body, not the slime's)
Final: fixed FormEffects.look picked a missing idle_1 when a named still was absent (an invalid key in the Form tab) — test_look_falls_back_to_the_base_when_the_requested_frame_is_missing RED→GREEN
Final: fixed the bestiary labelled the new form sheets as enemies — tools/test_build_bestiary.py RED→GREEN (classify(); the page data regenerated)
Final: fixed the evolutions page showed the new forms without art and said most had none — tools/test_build_evolutions.py RED→GREEN (each form's still read from its sheet; the page regenerated and checked in a screenshot)
```
