# Essence calibration (2026-10-03)

What the element vocabulary did to unlock timing. Produced by `tools/calibrate_essences.gd`; the Cave-start column is pinned in `tests/test_content.gd`. A number is "the eat, counting from 1, at which the skill unlocks" over every spawn of the shipped rooms (the jelly skipped), walking the Cave start in area order, and the three rebirth starts (G1, F1, D1) by their own area first, then forward, then back.

| Skill | Cave before | Cave after | G1 before | G1 after | F1 before | F1 after | D1 before | D1 after |
|---|---|---|---|---|---|---|---|---|
| Body Armor | 13 | 13 | 52 | 5 | 23 | 12 | 3 | 3 |
| Echolocation | 3 | 3 | 55 | 3 | 26 | 8 | 6 | 16 |
| Hardened Shell | 27 | 27 | 5 | 12 | 14 | 22 | 36 | 9 |
| Hydraulic Propulsion | 7 | 7 | 33 | 31 | 4 | 8 | 26 | 28 |
| Jolt | 57 | 57 | 35 | 35 | 6 | 6 | 28 | 28 |
| Poison Breath | 7 | 7 | 16 | 16 | 56 | 44 | 56 | 44 |
| Regeneration | 11 | 11 | 10 | 10 | 10 | 10 | 10 | 10 |
| Spore Cloud | 28 | **16** | 6 | 6 | 48 | 44 | 48 | 44 |
| Sticky Thread | 14 | 14 | 15 | **85** | 42 | **85** | 22 | **85** |
| Tremor | 73 | 73 | 55 | 57 | 36 | **52** | 19 | **52** |

Echolocation's level by the end of each area (Cave start, stage-1 cap 5): before 2, 2, 2, 5 on sound; after 1, 4, 5, 5 on air with `level_curve` 9, because the Grotto's moths now carry air.

## The deliberate moves

- **Spore Cloud** unlocks in the Cave (eat 16, was 28): air 8 from bats and dark 4 from toads and spiders. Accepted by Sean.
- **Sticky Thread** from G1, F1 and D1 needs a walk back to the Cave's Black Spiders (eat 85): the only creature its `source` condition counts. Reachable, later than before (a vine snake or the Taratect supplied thread).
- **Tremor** holds its Cave-start point (earth 59) and so unlocks later on F1 and D1 lives (52, was 36 and 19): an F1 or D1 life holds 50 earth in one forward pass and walks back for the rest.
- **Echolocation** and **Body Armor** unlock earlier on G1 and F1 lives (the Grotto's moths carry air; its crabs carry earth).
- **Echolocation** reaches the stage-1 cap by the end of the Flooded instead of staying at level 2.
