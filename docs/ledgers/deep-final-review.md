# Final review: The Deep (62ab728..63693c3)

I did this review in one pass, in this order: the scripts, then the new and rescoped tests, then the room data, then the docs. I compared the scripts with the base commit. I did not run the suite. I read the existing screenshots under `.tmp/`.

## Strengths

- **The charger fold is clean.** The non-stomper path in `_charger_act` is the same as the base, token for token. `test_enemy_traces` has no edits in the diff, so the lizard and crab goldens remain the regression net, as the spec asked. The stomper adds about 12 lines inside the function. It never writes `charge`, and a test checks this over 100 ticks.
- **`_slam` duck-types the floor read** (`has_method("is_on_floor")`, enemy.gd:615). On the real `Player`, a CharacterBody2D, `has_method` returns true for the native method, so the read works in real play.
- **Tremor's ordering is safe.**
  - It filters `t is Enemy` first, so the four-argument shortcut switch is never called.
  - It hits before it stuns, and `EnemyStatus.stun()` does nothing on DYING, so a killing blow followed by a stun is harmless.
  - The serpent goes through `def.predatable`, as the tackle does.
  - Every enemy has a non-null `def` before `setup()` adds it to `actors`, so `t.def` is safe.
- **`_share_alert` is correct and cheap.**
  - `n is Enemy` short-circuits before `.def` is read.
  - Only sight calls it, so a pack cannot chain. The chain test places the second wolf 220 px from the first and 420 px from the finder, which proves this.
  - The cost is the same order as the `actors` walk `can_see` already does every frame.
  - During a room transition, the old room's wolves are disabled and then freed, so a stray `_alert` written to them does no harm.
- **The F4 doorway matches the spec.** The ledge is trimmed to x 1196, and the lizardman and flowers are moved west with their spawn index kept. Both door halves are pinned at `to == 320`, the 188 pin still holds, and the closed-rect door-zone loop covers F4's new door and every exit of D1–D5.
- **The data checks out.**
  - The pacing guide adds up to 18 + 54 + 42 + 72 + 48 = 234, and 188 + 234 = 422 ≥ 403.
  - The census is 9 ants, 9 wolves and 3 drakes.
  - D3's chain rises from y 680 to 656 and then in steps of 48 to 320, with the top ledge flush with the wall at the sill.
  - D6's bottom exit (world 12440–12520) meets D2's top exit exactly.
  - The 39 decor ids add up: 31 plus all 8 `deep_*` ids.
- **The kit-table refactor keeps the per-area skill and level pins for the Grotto and the Flooded.** The pool-count check tightens from `>= 1` to `== 1`. One shared `first_time` helper replaces two copies.
- **The tests mostly check real behaviour with exact numbers.** For example, Tremor's 6 damage through DEF 5. The `_ticks` helper is a sound fix for the variable `wait_physics_frames`.

## Issues

### Critical (Must Fix)

None.

### Important (Should Fix)

1. **D6's Taratect hangs directly over D6's open floor hole, so the rare slice's only creature cannot be eaten.**
   - The spawn is at `Vector2(320, 32)` (data/rooms/D6.tres:32). The bottom exit spans x 280–360 (D6.tres:36, :39). The screenshot `.tmp/room-shots/D6_0.png` shows the spider right above the gap.
   - The gap is open in play. `RoomBuilder.is_exit_open` only closes `shortcut` exits, and this one is gated `wall_cling`.
   - A stunned or dying dropper loses its no-gravity state (enemy.gd:322, `no_gravity = _on_ceiling and active`). An inactive enemy has `velocity.x = 0`, so it falls straight down at x 320, through the hole and out of the loaded room. That happens when a thread stuns it, when ranged damage kills it, or when the Taratect drops on its own.
   - The eat window is lost, and nothing handles a body that leaves its room.
   - The drop the checklist describes ("drops on you", playtest-checklist.md:139) will not happen in practice either:
     - The dropper needs `is_alert()` and `|dx| < 40` (enemy.gd:518).
     - Alert needs a distance under `CHASE_RANGE` 160 (enemy.gd:19).
     - A player standing in D6 is at y ≥ ~256 (ledges) or ~308 (floor), at least 224 px below y 32.
     - The base jump apex is about 60 px (330² / 1800).
   - So the only way to get the Taratect down is to stun it from range, and then it falls into D2.
   - The Cave already avoids this. C3's spiders hang at x 240 and 520, clear of its hole at x 300–380.
   - The lint misses it because `_over_hole` only looks within 120 px of the floor (room_lint.gd:216-218).
   - **The plan shares the fault:** plan line 1394 specifies `Vector2(320, 40)`.
   - **Fix (data, plus a test):**
     - Move the spawn well clear of x 280–360, over solid floor or a ledge.
     - Give D6 a perch the player can stand on within 160 px of the spider, as C2's high ledges do, or hang the spider lower.
     - Add a `test_deep_slice` assertion that the Taratect's x is at least 40 px from the hole span.

### Minor (Nice to Have)

1. **The D3 drake can never slam a player standing on D3's floor.**
   - The drake stands on its shelf (`Rect2(360, 632, 160, 48)`), with its origin at y 626 (pos 620 plus 6). A player on the floor stands with its origin at 680 − 12 = 668: the Player's feet are 12 px below its origin (`BodyConfig.BOTTOM`; the ENTRY_BOOST comment in world.gd says "12 px feet"), while the Enemy's `BODY_BOTTOM` is 6 (enemy.gd:64).
   - That gives dy = 42, which is above `STOMP_LEVEL` 40.
   - The stub-based tests put the player and the drake at the same y, so they cannot see this 6 px origin offset.
   - It is harmless for the route, because the player has to climb onto the shelf to reach the D4 door, and there it gets slammed. But the playtest should know this, since slam reach is already deferred to it.
2. **`test_the_scene_exists_and_casts` (test_tremor.gd:65) only checks that the scene exists.** Casting through the scene is covered by every other Tremor test, so this is a naming issue. The spec's parametrised case "the in-air and off-floor cases are one parametrised case" is only the airborne bat. There is no explicit "unlocks at earth ×24" event test: the 24 is pinned as data, and the levelling curve lives in `test_skill_caps`.
3. **`test_it_hits_a_stunned_flier_that_has_fallen_to_the_floor` has an upper timing bound** (test_tremor.gd:106, `wait_physics_frames(60)`, against a 3 s stun). The executor's own ruling says `wait_physics_frames` can span about 1.7× its count. A loaded run would have to stretch it to 3× to fail, but it should use the `_ticks` helper like the other Deep tests.
4. **`test_the_actors_group_holds_things_that_are_not_enemies` can only fail through a SCRIPT ERROR.** The finder's `_alert` is set before `_share_alert` runs. It relies on the runner treating script errors as failures, which the Task 10 ledger note suggests it does.
5. **The kit-table test finds pools by room, not by id**, so the old `"G1"` and `"F1"` id lookups, and the ruled `"D1"` id, are no longer pinned in that test. `test_the_flooded_alone…` still uses `"F1"`.
6. **Two inaccuracies in docs/playtest-checklist.md:134:**
   - "you take 7 physical damage" quotes the drake's raw ATK, but `Player.receive_hit` applies DEF and the skillset mitigation first.
   - "does double through its DEF" reads as "reduced by DEF". The weak-point hit passes `ignore_def`, so "ignoring its DEF" would be clearer. The Tremor wording uses the same "through" idiom; consider "ignoring" there too.
7. **The Deep rooms use the Cave's pink and yellow motes**, because `TerrainMotes.STYLES` has no `deep` entry and falls back to cave. This is cosmetic.
8. **Only D2 and D6 have per-room shots in `.tmp/room-shots/`.** D1 and D3–D5 appear only in the overview shots (`.tmp/shots/deep_overview*.png`), and the stomp and pack shots exist. The Task 8 ruling leans on "the room screenshots" for the dark-outline skip. A look at D3 and D4 up close would complete that.
9. **tremor.gd:21 `float(i / 2 + 1)`** triggers GDScript's INTEGER_DIVISION warning. Write `float(i / 2) + 1.0` or use `floori`.
10. **The `n.def.pack` check in `_share_alert` is redundant** given `n.def.id == def.id`. It is harmless.

## Declined to judge

- **Tremor and Jolt hit through walls,** because the radius is centre-to-centre with no line of sight. This is the existing ability pattern, and the spec says only "within 72 px".
- **The drake does not turn to face the player when it starts its windup.** That affects which side counts as its "front" for a backstab during the windup. The spec is silent and it matches how chargers behave. It's a playtest call.
- **`_share_alert` can refresh `_alert` on a stunned, dying or downed packmate.** The only effect is up to 2 s of alertness after it recovers. This follows the spec's "timer, no line of sight" rule.
- **Tremor's 1 s area stun makes every grounded enemy edible and makes an armored drake take weak-point tackles from the front.** That is a design synergy the spec chose ("stuns the stunnable ones").
- **An eel resting on its water's floor counts as "standing on a floor" for Tremor.** It follows the spec's single rule; it's for tuning.
- **The existing Cave spiders (C2) also hang at y 32**, beyond the range at which a player can alert them. That is pre-existing and outside this change. Only the D6 placement over a hole is in scope.
- **Ruling (Task 2):** the essence-minimums test uses the full Deep census as "minimums". This is accepted; the census test pins the rooms.
- **Ruling (Task 8):** the dark-outline skip for the deep biome is accepted, subject to Minor 8.
- **Ruling (Task 9):** the seeds are thread 7 and water 6, with no Deep essence. This follows the plan's tiebreak rule.
- **Eat bonuses** (wolf spd, ant def, drake max_hp, Taratect atk +2 per eat) are in the plan, not the spec's table. That's tuning.

## Verdict

**Merge after a data fix.** The core area (D1–D5, the three flags, the stomp, the pack and Tremor) matches the spec. The charger fold is provably behaviour-preserving, and the tests check real behaviour.

The rare slice ships with its only creature parked over D6's open floor hole. It can never be alerted, and any stun or kill drops it out of the room. Move the spawn off the hole, give the player a perch within alert range, and add the guard assertion. The plan specified this position, so the plan should be corrected too.

The Minor items can follow.
