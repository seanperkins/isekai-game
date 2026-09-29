# The Fungal Grotto — Design

Status: revised after debate round 2 (2026-09-29). Sub-project 5 of `2026-09-28-slime-forms-and-animation-design.md`
(section 4), built on the exploration spec (`2026-09-28-exploration-world-design.md`, Plan 2) and on what
has since shipped: frame-drawn creatures with kill-type deaths and shape hits, per-room set dressing,
evolution, and rebirth pools.

## Goal

Ship the second area. You reach it by dropping out of the Cave's Drop Shaft and can climb back. It adds
four core rooms (G1–G4) and one optional rare room (G5), four creatures (drawn and animated like the
Cave's), two essences and two skills, a rebirth pool with the first real kit, the menu that lets you
choose where to be reborn, and the pacing that makes the first evolution land in its last room.

The Pale Moth, its derived sheet and G5 are one isolable slice at the end of the build order: the
core Grotto ships and tests without it, and the slice can be dropped without rework.

## Decisions

| Topic | Decision |
|---|---|
| Entry | C5's floor opens: a `bottom` exit from C5 to G1's `top`. It is a two-way link: a ledge chain under each drop lets you climb back (see Traversal) |
| Rooms | G1 Grotto Mouth (2×1), G2 Spore Hall (3×2), G3 Vine Maze (2×2), G4 Glow Pool (1×1, holds the tablet); optional slice: G5 Pale Moth (1×1, wall-cling gated). The earlier G6 nook is dropped: its tablet moves to G4 |
| Beyond G3 | The Flooded Tunnels are a later plan: G3 has no exit down. The spec's "shortcut back to C1 from G4" is dropped: rebirth pools already solve travel |
| Torches / camp | None. Light is glowing fungus and spores. The abandoned-camp brazier from the earlier spec needs art that does not exist and is dropped |
| Creatures | Spore Moth, Mushroom Crab, Vine Snake; and in the optional slice the rare Pale Moth, a lightened and enlarged copy of the Spore Moth's frames (a derived sheet, no new drawing) |
| Art | The creatures' frames are generated individually (the Plan 2/3 pipeline), assembled into `spore_moth`, `mushroom_crab` and `vine_snake` sheets with traced shapes, at the Cave's frame counts (below). The Grotto gets its own dressing library (`dressing_grotto`, 8 pieces, mushroom-heavy) |
| Essences | `spore` and `shell` join `Essences.ALL`. Spore feeds the Toxic lineage, shell the Bulwark lineage (already in their `FormDef.essences`) |
| Skills | Spore Cloud (essence, active) and Hardened Shell (essence, passive). Both have max level 8, reached under the existing stage caps (5 at stage 1, 8 after an evolution) |
| Rebirth | G1 holds the Grotto's pool. Its kit is a head start sized to the area (below). The `ReincarnationMenu` ships now, thin |
| Pacing | One rule, in the Pacing section: the first evolution lands in G4 |
| Out of scope | The Flooded Tunnels, Swim, shock, Jolt and Storm Jet; the Serpent Lair and victory; a second species; a behaviour framework for `Enemy` |

## Layout

Cells are in screens (640×360). C5 is at cell (5,2) and is 1×3, so it ends at row 5.

```
[C5 Drop Shaft 1×3]  (bottom exit, two-way)
        │
[G1 Grotto Mouth 2×1  cell (5,5)]─[G2 Spore Hall 3×2  cell (7,5)]
                                        │ bottom exit
[G5 Pale Moth 1×1 cell (7,7)]⋯wall cling⋯[G3 Vine Maze 2×2  cell (8,7)]─[G4 Glow Pool 1×1  cell (10,7)]
```

World pixels: G1 spans x 3200–4480, y 1800–2160; G2 x 4480–6400, y 1800–2520; G3 x 5120–6400, y 2520–3240; G5 x 4480–5120, y 2520–2880; G4 x 6400–7040, y 2520–2880. The map tab's bounds grow from 6×5 to 11×9 cells; its screenshot is in the review list.

- G1: the landing (a soft floor of moss under C5's exit), the rebirth pool a little way in from the entrance, a first look at moths and crabs. Its east exit into G2 is on G2's upper row.
- G2: the hub. Wide, two floors of mushroom-cap platforms, spore haze, all three ordinary creatures. Its bottom exit is a hole in the lower floor whose span lies inside world x 5280–6380 (G3's local 160–1260), valid in both rooms (G2's local 20–1900).
- G3: vines. Vine Snakes hang in the ceiling and lunge as you pass under; crabs patrol the ground. Its east exit into G4 is on G3's upper level (local y 20–320 of the upper row): G4 touches only that row.
- G4: a Glow Pool and the tablet, the last room of the area.
- G5 (optional slice): the rare room, reachable only by wall cling from G3.
- Every exit is matched on both sides and spans clear of corners and the floor (the world validator already enforces this), and every exit fits the 2× slime (`test_player_spread` covers every room).

### Traversal (nothing is a one-way drop)

- A ledge chain under each floor hole (C5→G1 and G2→G3) reaches back up to the upper room's floor. The rock around a vertical exit is 60 px thick (the upper room's floor band 40 plus the lower room's ceiling band 20), and the last hop targets the upper room's floor top, so the chain's top ledge sits at local y 12–15 of the lower room (rise = y + 40 ≤ 55; and y ≥ 12 so the standing body centre, 12 px above the ledge top, is still inside the lower room: a lower y makes the world flip between the two rooms every frame, found and fixed in the build): it stands inside the exit span and flush with the span's west edge (x 220 in C5; the west edge of G2's hole in G2), partly plugging it. The west edge matters: a hole splits the upper floor into two pieces, and only the west piece connects to the rest of the room (C5's k=1 ledge and its zigzag to C4's exit; G2's west half and the G1 sill), so a climber landing on the east piece would be cut off from the Cave's XP, and the span is at least ledge width + 28 (2× body) + 8 wide so a falling body still passes it. The lower room's ceiling band (rock from y −40 to 20 outside the span) also caps every hop below it: a body standing at y = 67 bonks after 23 px of rise, within 11 px of horizontal travel. So the take-off point of every ledge whose top is above local y 105 (20 + 24 + the 60.5 px base apex) lies under the span; the stamp takes a ledge width and offset (the existing C5 zigzag is 100-wide ledges offset 140, which spans 240 px), and the ledge below the top one alternates toward the free side of the span, so the top two ledges are their own rule and the stamp zigzags freely only below y 105. This matters twice: a G1 rebirth needs the Cave's XP (below), and G3 has no exit down, so without the chain a player dropped into G3 would be stuck until they died.
- The chains are one `Prefabs` stamp (`tools/prefabs.gd`), extracted from C5's existing inline zigzag in `tools/build_world.gd` and parameterised by start, height, x, ledge width and offset, so "no more than 55 px of rise per hop" is checked once. C5, the C5/G1 chain and the G2/G3 chain all use it.
- C5's hole spans x 220–380. Cave content inside or beside it is moved clear by `tools/build_world.gd` without changing the Cave's XP: the dressing at x 300 and 320 moves to x 500 and 620 (the exit-span check tests the extent of wide parallax dressing, not only its anchor: a 200 px arch at 440 would still overhang the hole), the lizard spawn at (400,1020) moves to (470,1020) (enemies turn at edges; their probe reaches 16 px below the floor), and the spider at (500,32) and the crystal prism at (500,1040) stay (they are outside the span). A test asserts no spawn, decor or dressing (not solids: the climb chain's own top ledge stands in the span on purpose) stands over any floor hole's span: the horizontal extent of the object overlaps the span (wide parallax dressing counts by extent) and, for a floor hole, it sits within 120 px above the floor line or below it (C5's k=10 ledge with its glow fungus, higher up, is not over the hole).
- A new **directed** reachability test covers the two vertical chains (the horizontal exit pairs are already matched on both sides by the validator, and in-room ledge reach is `test_every_ledge_is_reachable_from_its_floor_by_base_jumps`). For each floor-hole pair it runs the same hop model from the lower room's floor to the exit span, measuring each hop's rise in world coordinates to the upper room's floor top, with a headroom term the existing model lacks: the rising body (28 wide, 24 tall) must not intersect any rock rect over the rise; it starts from the floor segment the top hop lands on and requires it to reach the upper room's other exit (C4's exit from C5's west piece; the G1 sill on G2's upper row from G2's west piece), so landing on a dead-end piece fails; in G2 it also asserts that G1's exit sill is reachable from that lower-floor piece, since a climber from G3 lands on the lower floor. The existing `_reach` in `test_rooms.gd` treats exits as undirected edges and cannot catch a one-way drop.

## Creatures

Approved numbers from the exploration spec. New ids: `spore_moth`, `mushroom_crab`, `vine_snake` (and `pale_moth` in the slice), added to `Sources.ALL` (the def validator requires a source for every def and a def for every source), generated by `tools/build_content.gd`, and their bestiary portraits read from the creature's own sheet frame (`SpriteSheet.load_set(id).frame_texture(...)`: the moth's `fly_1`, the crab's `idle_1`, the snake's `hide_1`): the new creatures ship only sheets, and `PORTRAIT` (`skill_screen.gd`) points at `assets/sprites/<name>.png` and would give a blank tile.

| Creature | HP | ATK | DEF | SPD | Essences | XP | Behaviour |
|---|---|---|---|---|---|---|---|
| Spore Moth | 3 | 1 | 0 | 90 | spore 1, flight 1 | 2 | Its own slow drift loop; every 3 s it drops a spore puff under itself, telegraphed by the existing telegraph flash on a `fly` frame |
| Mushroom Crab | 8 | 2 | 2 | 70 | shell 2, earth 1 | 4 | The lizard's charger with a shell: walks sideways, telegraphs, charges when level with you; a front tackle hurts it but does not stun it (the lizard's armored front today), it is stunned only from behind |
| Vine Snake | 5 | 3 | 0 | 150 | poison 1, thread 1 | 3 | The spider's trigger (you pass under it) with a tethered lunge: it telegraphs, lunges, then returns to its anchor. Its `hide` frame looks like a hanging vine, so it needs no cooperating dressing |
| Pale Moth (rare, slice) | 6 | 1 | 0 | 110 | spore 3, flight 2 | 8 | The Spore Moth's behaviour on its own paler, larger sheet (same puff) |

First-time value per spawn (down plus eat, paid once each) is twice the XP: moth 4, snake 6, crab 8, pale moth 16.

### What `CreatureDef` gains and how `Enemy` uses it

- `CreatureDef` gains data flags that match how the code is already keyed (`capabilities`, `_spit_damage`): `armored_charger` (bool; the lizard and the crab: it makes the creature a charger and gives it a front armor, so it is stunned only from behind) and `drifter` (bool; the Spore Moth and the Pale Moth). The lizard's `def.id == Sources.LIZARD` checks in `_act` (charger dispatch) and `receive_tackle` (armored front) become `armored_charger`, so the crab reuses them with no new mechanic. `def.id` stays the single key for everything else: sheets, clips, `frame_name` and `EnemyState.pick` arms list both ids where two share a behaviour (`"spore_moth", "pale_moth":`), and the snake, the only creature of its kind, is an id branch.
- `EnemyState.pick` gains no eleventh parameter. The snake maps `coil` → the charger's windup, `lunge` → charge, retreat → rest through the existing `charge` string; the moth's telegraph rides the existing `_telegraphing()` flash.
- **Movement is capability-keyed today and each creature sets its own.** The moth's `skills` list is empty, and its gravity exemption and drift branch are keyed on `drifter` and sit before the `flight`-capability branch (`enemy.gd` sends any flier to the bat's swoop first), so a moth neither falls nor dive-bombs. The snake keeps `ceiling_walk` but its lunge is tethered: it never clears `_on_ceiling`, it moves along the tether and back to a stored anchor with gravity off (the spider's one-way drop is not reused).
- **Stun and death physics.** The gravity exemption for `drifter` and the tethered snake holds while ACTIVE or STUNNED: a stunned snake stays on its tether (it never falls with `_on_ceiling` still set), a stunned moth stays aloft and rises back to its drift height, and a dying or downed one falls, so a corpse can be eaten. Scripted tests cover a snake stunned mid-lunge and a moth stunned mid-air.
- `data/enemy_clips.json` gains entries keyed by sheet name so every state `EnemyState.pick` can return has a clip. `EnemyState.pick` gets a `"spore_moth", "pale_moth": return "fly"` arm and the sheet a `fly` clip, like the bat's; the snake's `rest` clip plays its `hide` frame. A test walks every creature × every state it can reach and asserts the clip exists, and separately asserts `EnemyState.pick`'s mapping per creature (the crab returns `windup` and `charge` for those strings, the snake's map to `coil` and `lunge`, the moth's to `fly`), since an unmapped creature falls back to `idle`, which has a clip.

### Frames (at the Cave's counts; each generated alone, then assembled with a shared per-creature scale)

- Spore Moth (7): fly ×4, stunned, hurt, downed. The puff has no pose of its own.
- Mushroom Crab (11): idle ×1, walk ×3 (loop 1,2,3,2), windup ×1, charge ×2, rest ×1, stunned, hurt, downed.
- Vine Snake (10): hide ×1, coil ×1, lunge ×2, slither ×3, stunned, hurt, downed.
- Their deaths, corpses (clippable), hit shapes and the contact fairness rules are the Cave's.

### Spore puffs and Spore Cloud (two groups, no shared allegiance flag)

- A puff is a lingering hazard in group `hazards` (which hurts the player only, like the toad's glob). It lasts 2 s, has a 20 px radius, and hurts each target at most once (one hit per puff, so `receive_poison` is never called every frame).
- Spore Cloud is the player's, in a separate group `player_clouds` that affects enemies only. It is an `Ability` modelled on `poison_breath`, spawns a small `Area2D` for 2 s, and each second calls the enemy's existing hit path with poison damage 1 and slows through `Enemy.slow_for(seconds)`, which is `receive_thread`'s slow branch extracted, so `_slow` still has one writer.

## Essences and skills

| Skill | Source | Unlock | Effect | Levels |
|---|---|---|---|---|
| Spore Cloud | essence | absorb spore ×4 | Active, 4 MP: a cloud (2 s) on the aim that slows enemies and poisons them 1/s | used ×8; max 8: size and duration grow |
| Hardened Shell | essence | absorb shell ×4 | Passive: knockback taken −8% per level (−64% at level 8). No DEF: Body Armor already gives DEF from the same hits, and DEF saturates | take physical hits ×10; max 8 |

- Knockback is a constant today (`Player.KNOCKBACK`, applied directly), and `Stats` is integer-only. Hardened Shell adds `knockback_taken` as a modifier target outside `StatKeys`, parallel to `damage_taken` but with its own route, since the generic modifier path only reads `StatKeys` and `SkillEffects.damage_reduction` is hard-coded to `damage_taken`: `SkillEffects.KNOCKBACK_TAKEN`, `DefValidator` accepts it as a modifier target next to `DAMAGE_TAKEN`, a new `SkillEffects.knockback_factor(pairs) -> float` sums the owned skills' values at their levels (absolute per-level values `[-8, -16, …, -64]`, as `value_at` expects) and returns `maxf(0.36, 1.0 + sum / 100.0)` (`value_at` already clamps a single skill at −64; the floor guards a future second source), `PlayerSkillSet` exposes it, and `Player` multiplies both components of `KNOCKBACK` by it where it is applied. The skill screen's effect text learns the new target: `skill_screen_model.gd` gets a label and a percent case beside its `DAMAGE_TAKEN` case, so the line reads "Knockback taken −8%" and not "knockback_taken −8". Tests pin: no skill → factor 1.0 (full knockback, not the missing-key 0), level 4 → 0.68, level 8 and beyond → 0.36 (the floor), and a knocked-back player travels the scaled distance. The skill id `hardened_shell` is distinct from the Bulwark form's `trait_hard_shell`.
- Both need icons, generated like the existing ones and added to `tools/art/manifest.json` with the tests that pin the sprite count (`test_art_assets` requires an icon per skill).
- Their maxima are within what their sources supply, under the stage caps: with `BASE_STAGE_CAP` 5 they reach level 5 at stage 1 and 8 only after an evolution raises the cap. The reachability test extends to them with the needed events (56 and 70) inside its bounds.
- Registration surfaces: `Essences.ALL`, `tools/build_content.gd` (skills and creatures), `Sources.ALL`, the icon manifest, `test_skill_caps` `TABLE`.

## Rebirth

- G1's `rebirth_pool` has id `G1`, area `grotto` and the kit: skills Leap and Wall Cling (level 1, quietly granted), character level 3, and seeded affinity chosen by a test, not by hand. The test counts, for each shipped non-default pool, the lineages eligible from the kit's seeds plus the ungated Grotto's supply (what a G1 life eats there) against the whole-world supply, and asserts two things that can fail: at least two lineages are eligible, and more than the same life would have without the seeds (so the seeds are not decoration).
- A G1 life starts at level 3 with 0 EP and needs 245 XP to reach the cap. The Pacing total (≥ 270 on a fresh first-time pass) covers it; a test asserts that a life started at the kit's level can reach the cap from the ungated XP.
- The `ReincarnationMenu` (a `CanvasLayer` at layer 40, above the death card at layer 30 and the skill screen at 20) shows the `RebirthChoice` decision when `Run` emits `choice_needed`: the options in order, the last choice selected, locked pools as "???". Up/Down (or the stick) moves, Enter/A on the highlighted row confirms and calls `Run.choose` (no separate confirm screen); a locked entry cannot be confirmed. It takes input exclusively while a decision is pending and does nothing otherwise. Once `Game` connects it, `Run` no longer auto-picks, so tests that drive a whole `Game` with two attuned pools must call `choose` explicitly.

## Set dressing and art

- The Grotto's rooms get set dressing like the Cave's: a Grotto library of eight pieces (giant mushroom cap pillar, hanging spore-moss, glowing mushroom cluster, mushroom bridge, vine curtain, spore pod, stalactite with moss, dripping fungus shelf) in `assets/dressing/grotto/`, authored per room in `tools/build_world.gd` with the same validator. The mushroom-cap ledges of the climb chains use the existing terrain art.
- The Grotto's terrain art already exists (`assets/tiles/grotto`, `assets/backgrounds/grotto`).

## Pacing

One rule, computed by a test from the room data with the existing ungated semantics (`_reach(true)`: rooms behind a `gate` or `shortcut`, C3 and C6 in the Cave, do not count). It sums each spawn's `xp` directly, never through a `Progression` (which stops paying at the cap):

- Cave (ungated: 108 of its 124) + G1 + G2 + G3 + G4 ≥ 270, the cap for stage 1.
- Cave (ungated) + G1 + G2 + G3 < 270, so the first evolution lands in G4, the area's last room.
- The Cave alone stays under 270 (the existing assertion, filtered to `area == "cave"`, counted over all its rooms).

G5's Pale Moth (16) never counts. A guide, not a contract: G1 3 moths and 2 crabs (28); G2 4 moths, 3 crabs and 2 snakes (52); G3 4 snakes and 4 crabs (56); G4 3 moths and 3 crabs (36) sum to 172, so 108 + 172 = 280, and 108 + 136 = 244 through G3.

## Existing tests rescoped

Several existing tests loop over all rooms but encode Cave-only facts; the plan rescopes each to `area == "cave"` (or recomputes it) alongside the new assertions:

- `test_progression_stages` (`paid < 270` over every room), `test_skill_caps` ("the Cave alone cannot max Appraisal": 8 > types), `test_form_offers` (Weaver supply is 5 today and gains the snake's thread; the 60% eligibility examples), `test_rebirth_kit` (the "5 thread is all of Weaver's supply" assertion, and `test_every_shipped_non_default_pool_leaves_two_lineages_eligible`, which passes the seeds alone as the absorbed units: it is replaced by the rule in Rebirth, adding the ungated Grotto's units to the seeds before `RebirthKit.eligible_lineages`, and keeping the "more than without seeds" assertion), `test_rooms` (the exact C1..C6 id list), `test_constants` (`Sources.ALL`, `Essences.ALL`), `test_content` (22 skills → 24, 6 creatures → 9, 10 with the slice), `test_enemy_sheets` (`SETS`), `test_content` (its "every essence skill is supplied" check counts Cave-only creature minimums, which supply no spore or shell: it counts Grotto sources too) and `test_skill_caps` (the descending-values rule allows negative curves only for `slide_speed` and `predation_time`: it learns `knockback_taken`'s `[-8, …, -64]`).
- `WorldValidator.validate(rooms, creature_ids := [])` gains the checks its testing relies on and it does not make today: when `creature_ids` is passed (`Game` and the tests pass it), every spawn's creature id is in it, and every feature `kind` is one `RoomBuilder` builds. A typo must not silently drop a creature and its XP (`Game._spawn` only push_errors at runtime).

## The optional slice: the Pale Moth and G5

- The `pale_moth` def (`drifter`), a `pale_moth` sheet derived from the moth's frames: `tools/art/assemble_frames.py` reads optional `derive_from` and `lighten` keys in `pale_moth_frames.json` (widths are the moth's times the enlarge factor, with the same anchor; no prompts, since nothing is generated), lightening the keyed, cropped image (never the raw magenta-keyed source, which would stop keying), with one unit test beside `tools/art/test_assemble_frames.py`; (hit shapes are traced from the pixels, so the shape-hit rule, `DeathFx`, `EatCover`, the hurt flash and the stun and telegraph tints all work unchanged), its `data/enemy_clips.json` entry copied from the moth's, its portrait from the sheet, and G5 with its gate. No runtime tint or size, no new node, no `base`.
- G5's opening is a side opening in the west wall of G3's upper row. G5 is **not reachable by base movement or Leap**; traversal skills (Wall Cling, Sticky Thread, Hydraulic Propulsion) may reach it, exactly as C3 is reachable past C2's chimney today. The exit keeps `gate: "wall_cling"` as its graph tag. The gate is enforced structurally, not by a distance rule (a same-height distance is exceeded by fall height, Echo's speed and stage-2 airtime): a paired-wall chimney like C2's (C2's is inline solids today, so it is extracted like the chain stamp; walls ≤ 20 wide or > 24 tall so `test_every_ledge_is_reachable_from_its_floor_by_base_jumps` does not treat them as ledges) hangs from G3's ceiling to at least `T` px below the opening's lower lip, so the opening is screened from the east and its only mouth is the chimney's bottom. `T` is derived by the test, not hand-copied: the maximum over stages 1 and 2 of the jump apex with Leap at that stage's cap plus the best `jump_height` form bonus at that stage, plus 3 px (the apex is linear in `jump_height`: 60.5 px base, 78.7 px at stage 1's Leap 5, 93.8 px at stage 2's Leap 8 with Echo's +10), so `T` = 96.8 and authors use at least 97. The "not reachable by Leap" claim is scoped to stages 1 and 2: later forms reach further (Sky at stage 3 about 108.9 px, Storm at stage 4 about 111.9 px) and the design allows that, as it allows the traversal skills. The test also asserts that the paired walls exist and that no solid lies between them above the chimney's bottom (a ledge inside the chimney defeats the vertical rule). 
- G5 is optional content: a first life learns Wall Cling in the Cave (C2's chimney); a G1 life is granted it.

## Testing approach

- Data: every room validates (exits matched, spans, spawns known, features valid, dressing pieces known); spawn keys are unique; the pacing rule; the G1 kit validates and meets the eligibility test; every emitted event has an audio cue; nothing spawns or stands over an exit span.
- Traversal: the directed reachability test above.
- Creatures: each behaviour has a scripted test (a moth neither falls nor dives, its puff cadence, hazard and one-hit-per-puff; crab telegraph then charge, and a front tackle that damages but does not stun with facing both ways; snake hide-lunge and return to its anchor's y); each sheet loads with every listed frame, on the floor line, with shapes hugging pixels; every creature × reachable state has a clip; the Pale Moth (slice) loads its own sheet and clips, drifts like the moth, and its traced shape hugs its enlarged pixels.
- Skills: Spore Cloud spawns a cloud that slows and poisons and expires and never hurts the player; puffs never hurt enemies; Hardened Shell scales knockback per level (with the floor) and a player with no skill takes full knockback; both unlock and level from their events; the validator accepts them.
- Menu: one flow test (the decision renders in order, moves, confirms only unlocked entries, pre-selects the last choice, sits above the death card, and drives a real death-to-new-life flow with the Grotto pool attuned) and one input-order unit test.
- Real screenshots of each Grotto room, each new creature, the map tab and the menu.

## Build order

1. Data: essences, the two skills, the three creature defs and their registration, the `armored_charger` and `drifter` flags and the `Enemy` generalization, the `knockback_taken` route, the rescoped tests, the validator checks.
2. Art: the three creature frame sets and the Grotto dressing library, generated in parallel.
3. Behaviours: moth, crab, snake with their sheets and clips; Spore Cloud; `Enemy.slow_for`.
4. Rooms: G1–G4 authored, the `Prefabs` stamp and the climb chains, C5's hole (moving its contents), dressing, spawns tuned to the pacing, the directed reachability test.
5. Rebirth: G1's pool and kit, the menu.
6. The optional slice: the derived Pale Moth sheet, def and clips, and G5, in one commit range that can be dropped.
7. Review, gate, merge.
