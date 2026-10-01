# The Deep — Design

Status: revised after debate round 1 (2026-10-01). Sub-project 7, the fourth area. It builds on the exploration spec
(`2026-09-28-exploration-world-design.md`), the Fungal Grotto (`2026-09-29-fungal-grotto-design.md`: the template for an area and its pacing)
and the Flooded Tunnels (`2026-10-01-flooded-tunnels-design.md`: the last area, the registration surfaces a new creature or skill touches, and the
way an area is authored with the editor's model). The art for the biome already ships: `assets/tiles/deep`, `assets/backgrounds/deep`, the
`deep_*` decor rows in `DecorLib`, the `deep` ambient tint, and the `deep` ambience and music in `data/audio/cues.json`.

## Inspiration

| Source | What it gave |
|---|---|
| *That Time I Got Reincarnated as a Slime* | The **Gloom Wolf**: the black star wolves, a pack that hunts as one. One that sees you calls the rest |
| *So I'm a Spider, So What?* | The labyrinth's deeper strata: things that outnumber a lone body (the **Armed Ant**, a soldier that works in a swarm), things that dwarf it (the **Stone Drake**, a slow rock-scaled earth dragon that strikes the ground) and the **Taratect**, the series' own spider, as the rare find. The slime's thread lineage is its mirror |

Nothing here copies a name or a design: the creatures and the skill keep the game's own names.

## Goal

Ship the fourth area. You walk into it out of the Flooded's marsh hall (F4). It adds five core rooms (D1–D5) and one optional rare room (D6), three
creatures and one rare one, **Tremor** (the first skill the `earth` essence feeds), three creature behaviours built on what exists (a pack that shares its
alert, an unarmored charger, a ground stomp), the area's rebirth pool and the third real kit.

One isolable slice sits at the end of the build order and the core ships and tests without it: **the rare slice** (the Taratect on a derived
sheet, D6 and its wall-cling gate). Nothing else here is a slice: the creatures, Tremor and the five rooms are the area.

## Decisions

| Topic | Decision |
|---|---|
| Entry | F4's east edge opens into D1's west edge: a side exit pair at the same world span, ungated (F4 is behind the Swim door already). No floor hole, so no ledge chain from the entry. F4's fourth lizardman and its flowers move out of the doorway's clear zone (they are relocated, not deleted: the Flooded's first pass stays 188) |
| Rooms | D1 Gloom Gate (1×1, the rebirth pool), D2 Wolf Run (2×1), D3 the Sinkhole (1×2, a climb), D4 the Den (2×1), D5 the Heart (1×1, Glow Pool and tablet; the area's last room); slice: D6 the Hollow (1×1, above D2) |
| Creatures | Gloom Wolf, Armed Ant, Stone Drake; in the slice the rare Taratect (a derived sheet of the Black Spider, no new drawing) |
| Behaviour | **No new Kind.** `CreatureDef` gains three flags: `pack` (the wolves and ants: a creature that sees you alerts its packmates), `charges` (the wolf: the charger's sequence without the armored front) and `stomper` (the drake: a charger whose "charge" is a ground slam you dodge by being airborne) |
| Skill | **Tremor**, an essence skill from `earth` ×24 that slams the ground: it damages every grounded enemy near you through its DEF and stuns it. It is the counter to armor and the first use of `earth`. `flight` stays reserved (see Out of scope) |
| Art | Three frame sets (wolf, ant, drake) generated one at a time (the Grotto's pipeline) and assembled with traced shapes; the Taratect derives from the spider's frames; one skill icon. Tiles, backgrounds, decor, ambience and music exist |
| Evolution | Unchanged: `FormOffers.FIRST_EVOLUTION_AREAS` stays `["cave","grotto"]`. A life reborn in the Deep counts its Deep absorptions in the numerator in full (the Flooded's note) |
| Rebirth | D1 holds the area's pool and the third real kit (below) |
| Pacing | One rule, below: the Flooded and the Deep together fill stage 2 |
| Out of scope | The Serpent Lair, the sealed arena and victory; a flight skill (Glide) and any physics for it; darkness and lighting; a behaviour framework for `Enemy`; the Deep's own water (the biome has no `water` rects) |

## Layout

Cells are screens (640×360). F4 is cell (15,6), 2×1, so its east edge is world x 10880 (cells 15 and 16). Nothing exists east of column 16.

| row \ col | 17 | 18 | 19 | 20 | 21 | 22 | 23 |
|---|---|---|---|---|---|---|---|
| 5 | | | D6 (slice) | | | | |
| 6 | D1 | D2 | D2 | D3 | | | |
| 7 | | | | D3 | D4 | D4 | D5 |

F4's east exit meets D1's west. D1's east meets D2's west. D2's east meets D3's upper row. D3's lower row opens east into D4's west. D4's east meets
D5's west. In the slice, D2's top exit (gate `wall_cling`) is D6's floor hole.

World pixels: D1 x 10880–11520, y 2160–2520; D2 x 11520–12800, y 2160–2520; D3 x 12800–13440, y 2160–2880; D4 x 13440–14720, y 2520–2880;
D5 x 14720–15360, y 2520–2880; D6 x 12160–12800, y 1800–2160. No two overlap, nor any earlier room, and every neighbour pair shares an exact world
span (the validator enforces both). The map tab's room count goes from 17 to 22 (23 with D6); its bounds are computed from the rooms, and the map
shrinks (a 1×1 room is about 25 px wide in the test panel, 35 before): a screenshot checks it still reads.

- **D1** (the landing): flat and open, with the area's rebirth pool a little way in and three Armed Ants. The entry span is a doorway in F4's east wall
  at floor height (`from` 240, `to` 320, the floor's top): F4's fourth Bog Lizardman (`F4.tres`, near x 1235), the flowers decor (near x 1230) and the east
  end of its last ledge (`Rect2(1120, 266, 100, 12)`, to x 1220) sit inside its 64 px front zone (x 1196–1260). The lizardman and flowers move west of it
  and the ledge is trimmed to `Rect2(1120, 266, 76, 12)` (it ends at x 1196: touching rects do not intersect). `new_room_beside` rejects a door whose zone
  holds any solid, ledges included, and would otherwise pick a span 60 px above the floor (180–260), a sill no base jump climbs back to. So the Flooded's
  spawn list and first pass are unchanged and a test pins that F4's east exit and D1's west exit both end at `to == 320`. `RoomLint` checks solids only
  in a door's zone, so a second test pins that no spawn or decor stands in it, by x-range (F4's is x 1196–1260, D1's x 556–620), since a decor base on the
  zone's bottom edge is outside `Rect2.has_point`. D1's ants stay clear of the pool (the lint's pool clearance) and of D1's zone.
- **D2** (wolves): a long hall with three Gloom Wolves and three ants; low ledges to jump a charge. In the slice, a one-screen chimney in its east half
  (two facing walls) under the top exit, kept clear of the walking route to the east exit and its clear zone.
- **D3** (the Sinkhole): a tall shaft. D2's east door arrives at D3's upper row at floor height (local y about 320) and D4's door leaves from D3's lower
  row, so the shaft is climbed in both directions: a ledge stands flush with D3's west wall at the door's floor height, and a chain of ledges goes down
  from it to D3's floor (every hop at most 55 px, the Flooded's chain geometry rules). A Stone Drake on its floor shelf and three ants.
- **D4** (the Den): a wide cavern of four wolves and a drake with platforms over it. The pack is the room's danger.
- **D5** (the Heart): the Glow Pool, a tablet, a drake and two wolves; the area's last room (the Serpent's route is out of scope, so docs/rooms.md says
  the world ends here for now).
- **D6** (slice): the Hollow, a pocket above D2's chimney with the Taratect hanging from its ceiling.

### Authoring

The rooms are written by a throwaway script through `RoomEditModel` (the Flooded's way). `new_room_beside` bottom-aligns a room it places to the right,
which gives D1, D2, D4 (beside D3's 1×2 cell) and D5's cells but not D3's (it would put D3 at (20,5)); the script creates D3's `RoomDef` with the
layout's `cell` and pairs its exits with `add_exit`, then places D4 beside it. F4's doorway is made after the ledge is trimmed and the lizardman and flowers are cleared, so
the floor-height door is the one the editor finds. The same trap applies to any room made beside one that already has solids near the shared wall: the
script authors each room's solids after its east neighbour exists, or passes the span explicitly. The `.tres` files are the source of truth and the validator the arbiter.

### Traversal

- No floor hole means no one-way drop: every room joins its neighbours by side exits. D1 sits behind the Swim door because F4 does.
- **A strip test for D3**, the Flooded's `test_the_two_floor_holes_have_chains_back_up...` shape (no search, no reach machinery): the ledges near D3's west
  edge, sorted by y, start with one flush with the west wall at the door's floor height (the exit's sill), every hop up is at most 55 px and the lowest
  ledge is within 55 px of D3's floor. The existing `RoomLint._ledge_reach` and `WorldValidator.reachable` do not prove this: they check ledges against
  the floor and the exit graph, never an exit's sill.
- **D6's gate** (slice) is the C2→C3 shape (a top exit over a chimney, not G5's side sill): the chimney's two walls rise from the floor to the room's
  ceiling flanking the opening, with nothing between them, so no base jump reaches the opening. It is the existing `wall_cling` label; no new gate label,
  and a gated exit matches on both halves. Its tests are C3's kind: the ungated route excludes D6 and the gated route includes it (`test_rooms`'s two
  reachability assertions), plus one short geometry assertion on the chimney's walls. No BFS and no cling-climb simulation (none exists in the repo), so
  nothing is copied from the Grotto's private reach helpers and no shipped test is rewritten.

## Creatures

New ids: `gloom_wolf`, `armed_ant`, `stone_drake` (and `taratect` in the slice), added to `Sources.ALL`, generated by `tools/build_content.gd`, with
their portraits read from the creature's own sheet frame (`PORTRAIT_FRAME` in `skill_screen.gd` gains the four ids).

| Creature | HP | ATK | DEF | SPD | Essences | XP | Behaviour |
|---|---|---|---|---|---|---|---|
| Gloom Wolf | 6 | 3 | 0 | 100 | sound 1, earth 1 | 6 | A pack charger: patrols its beat; a wolf that sees you alerts every wolf within 240 px; each flicks and charges when level with you (the charger's windup, charge and rest). Not armored: a front tackle stuns it |
| Armed Ant | 5 | 2 | 1 | 90 | armor 1, earth 1 | 3 | A pack walker: patrols, and once alerted (by sight or a packmate) chases at full speed while level with you (the existing `_walk`); weak alone, dangerous as three |
| Stone Drake | 16 | 4 | 3 | 40 | earth 3, armor 1 | 12 | Walks at its slow pace; alerted, within 110 px horizontally and 40 px vertically it rears (the windup, 0.7 s) and slams: if you are then on the floor in the same zone it hits you, so you dodge by being airborne. Rests 1.4 s. Armored front: stunned only from behind |
| Taratect (rare, slice) | 14 | 5 | 1 | 120 | thread 3, poison 2 | 12 | The Black Spider's ceiling dropper on an enlarged, tinted derived sheet |

First-time value per spawn is twice the XP (down plus eat, paid once each): wolf 12, ant 6, drake 24, taratect 24.

The table's HP, ATK and DEF are level-1 bases: the generator scales them (`_scaled`: +8% a level, rounded half up) at level 10 (`DEEP_LEVEL`), as the
Flooded's are at 7 and the Grotto's at 4. Resulting numbers: wolf HP 10, ATK 5, DEF 0; ant HP 9, ATK 3, DEF 2; drake HP 28, ATK 7, DEF 5; taratect HP 24,
ATK 9, DEF 2. A front tackle from a base slime does 1 to the drake (armor floors damage at 1); a backstab does twice the attacker's ATK ignoring DEF.

### What `CreatureDef` and `Enemy` gain

- `CreatureDef` gains `pack`, `charges` and `stomper` (default false). The drake sets `armored_charger` and `stomper` (a CHARGER with an armored front
  that slams instead of charging: the flag is finally true), the wolf `charges`. `armored_charger`'s doc in `creature_def.gd` learns that it names the
  front block and, with `charges`, the charger Kind.
- **Kind.** No new Kind. `_resolve_kind`'s CHARGER arm becomes `def.armored_charger or def.charges`; the ant stays a WALKER; the Taratect (`ceiling_walk`)
  a DROPPER. `receive_tackle` still reads `armored_charger` for the front block, so a wolf is stunned from the front and a drake is not.
- **Pack.** In `_sense`'s `if sees:` branch, a pack creature calls `_share_alert()`: every other `Enemy` in the `actors` group (the group also holds the player, the shortcut switch and test stubs, which have no `def`:
  `n is Enemy and n != self and n.def.pack and n.def.id == def.id`) within `PACK_RADIUS` (240 px) gets `_alert = ALERT_MEMORY` (no line of sight needed, refreshed every frame its finder still sees you). No
  new group. Alert is a timer every enemy has (`is_alert()`), so a packmate chases or charges by its own existing logic and forgets you ALERT_MEMORY (2 s)
  after its finder loses you. Because only sight calls `_share_alert`, a creature alerted this way never alerts others, and a pack does not chain
  across a level.
- **The wolf's charge** reuses the CHARGER sequence unchanged.
- **The stomp** is a `def.stomper` variant inside `_charger_act` (which gains the `player` argument; one call site), as the lizardman's spear is a variant
  inside the spitter. Three branches: the **trigger** (alerted, `absf(dx) <= STOMP_RANGE` 110 and `absf(dy) <= STOMP_LEVEL` 40, not the charger's
  forward-only test, so a point-blank stomp is allowed); the **windup** (`STOMP_WINDUP` 0.7 s, the charger's `windup` token and telegraph tint); and the
  **slam** at the windup's end: one `_slam(player)` check (`player` is a `Node2D`, so the floor read is `player is CharacterBody2D and player.is_on_floor()`; the
  player on the floor, `absf(dx) <= STOMP_RANGE`, `absf(dy) <= STOMP_LEVEL`) that does
  `receive_hit(atk, "physical", position)`, then `rest` for `STOMP_REST` (1.4 s) instead of the charge. A stun cancels it like every other kind's. If the
  fold needs more than about 15 lines of stomper branching, the plan extracts a `_stomp` helper called from `_charger_act`; it still adds no Kind.
  Because the windup and rest are the charger's tokens, `charge_state()`, `telegraphing()` and the tint need no new arms. The slam tests use the real
  `Player` or a stub that reports floor state (`EnemyRecorder.StubPlayer` has no `is_on_floor`), and the drake joins `test_enemy_traces` (`stone_drake_plain`,
  `stone_drake_stunned_in_windup`) next to the existing `lizard_*` and `crab_plain` traces, which are the regression net that the fold leaves the charger unchanged.
- **Animation.** `EnemyState.pick`: `gloom_wolf` and `armed_ant` join the crab and crayfish arm (it returns `walk`/`idle` when the token is `""`, which a
  WALKER's is); `stone_drake` has its own arm (`windup` → the windup clip, `rest` → the `stomp` pose held for the whole rest, else `walk`/`idle`);
  `taratect` joins the spider's arm. `data/enemy_clips.json` gains each sheet's clips (the Taratect's copy the spider's), and per-creature `pick` tests (as
  the Grotto and Flooded added) assert no Deep creature falls back to `idle` while moving.

### Frames (each generated alone, then assembled with a shared per-creature scale)

- Gloom Wolf (11): the charger's list (idle, walk ×3, windup, charge ×2, rest, stunned, hurt, downed).
- Armed Ant (7): idle, walk ×3 (loop 1,2,3,2), stunned, hurt, downed.
- Stone Drake (9): idle, walk ×3, windup (rearing), stomp (the slam, held for the rest), stunned, hurt, downed.
- Taratect: derived from the spider's frames (`derive_from`, `tint`, an enlarge factor); no prompts.
- Their deaths, corpses, hit shapes and the contact fairness rules are the Cave's.

## Skills and essences

| Skill | Source | Unlock | Effect | Levels |
|---|---|---|---|---|
| Tremor | essence | absorb earth ×24 | Active, 5 MP: slam the ground. Every enemy standing on the floor within 72 px takes the skill's damage (3/4/5/6/7 through `Damage.skill_power(value, ATK)`, as Jolt does) ignoring its DEF and is stunned for 1.0 s | used ×8, max 5 |

- **The threshold is derived, not trusted.** Earth is already in the Cave's lizards (4), the Grotto's crabs (12) and the Flooded's lizardmen (6): 22
  units before the Deep, so earth ×4 would hand a Cave life a skill that pierces armor at its start (a respawning room can be lapped, so ×24 raises the cost; it does not forbid
  the skill, as Echolocation's laps do not). A test computes the earth units the shipped
  rooms before the Deep hold and asserts the threshold is above them (a later edit that adds an earlier earth creature would otherwise hand a Cave life the skill); the Deep adds 27, so a
  full-clear life reaches Tremor in the Deep's first rooms, and the D1 kit grants it to a reborn one. The literal 24 is pinned in the data test, as every
  skill's is. Cost if wrong: it is a constant.
- Tremor is an ability in `scripts/abilities/` modelled on `Jolt`, with a scene `scenes/abilities/tremor.tscn` (an active skill with no scene never
  casts; `skill_rules` validates scenes at load, so a stub scene lands with the skill). It uses `Ability.targets_around(72)` and keeps a target only if it is
  an `Enemy` (`_foes` also yields a shortcut switch, whose `receive_hit` takes four arguments) and `is_on_floor()`. It then calls
  `receive_hit(power, "physical", from, "other", true)` (the existing `ignore_def` weak-point parameter: no new damage type) and, only
  `if t.def.predatable`, `status.stun(1.0)` (which keeps the longer timer): the tackle's shape, so the serpent takes the damage and is never stunned. One rule decides who is hit: **standing on any floor**, a ledge included (a crab on a ledge 60 px overhead is within the 72 px radius and is hit). Fliers
  and drifters are not; a stunned flier that has fallen to the floor is. It never hurts the player and has no caster condition (cast in the air it
  hits what stands on the floor below within the radius).
- Registration surfaces (the Flooded's list): `Sources.ALL`; `tools/build_content.gd` (skill and creatures); `scripts/ui/skill_screen_model.gd`'s
  `ACTIVE_LABEL` (`"tremor": "Damage"`); the audio catalog (`skill_used.tremor` gets a cue; the Water Blade cue is reused, as Jolt reuses it); the icon
  manifest (`tools/art/skill_icons_deep_frames.json`, one 32×32 icon, `icon_tremor` required by `test_art_assets`); `test_skill_caps`'s `TABLE`;
  `DefValidator`; the compendium; `PORTRAIT_FRAME`.
- `earth` already exists in `Essences.ALL` and `RebirthKit.ESSENCES`; its header comment ("feed no skill yet") changes: earth feeds Tremor, flight
  alone is reserved.

## Rebirth

D1's `rebirth_pool` has id `D1`, area `deep`, and the kit: skills Leap, Wall Cling, Swim and Tremor (level 1, quietly granted), character level 5, and
affinity seeds that a script computes once (the eligibility count below) and stores in the room data; the test asserts the stored kit, never a recomputed
one. The count is the lineages eligible from the seeds plus what the kit can eat in D1 and D2 (the Deep's rooms before its first drake) against the
first-evolution supply: at least two are eligible and more than the same life has without the seeds. This measures D1 and D2, not the room where a Deep-born
life would actually evolve; it mirrors the Flooded's F1 and F2 frame on purpose.

The kit tests stop being copied: `tests/test_rebirth_kit.gd` already carries two near-identical sets (the Grotto's and the Flooded's units helpers,
eligibility and kit-valid tests). The Deep's arrive as one table, each row `{rooms, expected pool count, expected kit skills, expected kit level}`
(`grotto`: G1..G4, one or more pools, Leap and Wall Cling at level 3; `flooded`: F1 and F2, exactly one pool, Leap, Wall Cling and Swim at level 4; `deep`:
D1 and D2, exactly one pool, Leap, Wall Cling, Swim and Tremor at level 5, so the refactor drops none of the existing per-area pins), and one loop over it
(the `untackleable` skip is a no-op outside the Flooded, so it applies everywhere), including the generic assertion that a kit's XP to the cap is at most the
first-evolution areas' total. No Deep-specific XP pins. The Flooded's "an F1 life reaches its first evolution only by going back up" test keeps its
assertions but is renamed or commented: an F1 life can also now go forward (188 + D1 + D2 reaches 225).

## Pacing

One rule, computed by a test from the room data: a spawn's **first-time value** is twice its `xp` (a `water_pool` pays once), summed over the non-optional
rooms (D1–D5; D6 never). **The Flooded's first pass (F1–F5, 188, unchanged by the doorway) plus the Deep's reaches stage 2's cap (403)**: a life that evolved at
the Grotto's end finishes stage 2 at the Deep's end. It is a tuning pin with a 19 XP margin, not a surprise: removing one wolf (12) still passes; two (24) or one drake (24) fail. There is no upper bound: the Deep alone (234) is far below 403 and a bound that cannot fail pins nothing. The sum is one helper,
`ShippedRooms.first_time(rooms, creatures, ids)` in `tests/support/shipped_rooms.gd`, which replaces the Grotto's and the Flooded's private `_first_time`
copies.

A guide, not a contract: D1 3 ants (18); D2 3 wolves and 3 ants (54); D3 1 drake and 3 ants (42); D4 4 wolves and 1 drake (72); D5 1 drake and 2 wolves
(48) sum to 234, and 188 + 234 = 422. The Deep holds 9 ants, 9 wolves and 3 drakes.

## Existing tests rescoped

The pins a new area touches (the plan confirms each by a full-suite run after each registration step): `tests/support/shipped_rooms.gd` (`IDS` and its
docstring's room and rule counts), `test_world_view` (the room count, 17 to 22/23), `test_content` (skills 31 → 32; creatures 15 → 18, 19 with the Taratect),
`test_constants` (`Sources.ALL`), `test_audio_catalog` (the Tremor cue), `test_enemy_sheets` (`SETS`, its `states` map and its attack-shape expectations:
which Deep frames carry `attack_from` is decided in the art task), `test_skill_caps` (`TABLE`), `test_skill_screen` (its hand list of portraits),
`test_decor_lib` (used ids when the D rooms use `deep_*` pieces), `test_enemy_kind` (its `KINDS` pins and the one invariant, that no def combines behaviours: `stomper` and `charges` imply a charger Kind and exclude spit), `test_grotto_data` (line 32 pins `armored_charger` to exactly lizard, mushroom crab and cave crayfish: it learns the
drake), `test_flooded_registrations` (`test_creature_def_flags_default_off` gains the three flags), `test_flooded_rooms` (the F4 doorway: its 188 stays),
`test_rebirth_kit` (the table above), `test_terrain` and `test_simple_layers` (`BIOMES` gains `"deep"`: nothing builds a deep room today), and the
progression pacing tests (the Cave, Grotto and Flooded rules stay scoped to their areas). The docs and comments that change: `docs/rooms.md` (its decor paragraph, "the 31 ids the shipped rooms use … the other 15 (all of `deep_*`, …) are chosen, not pinned": both counts and the parenthetical change once the D rooms use `deep_*`; the F4 row,
the rooms table, "the last room"), `docs/playtest-checklist.md` (a Deep section), `enemy.gd`'s Kind and state-token docs, `creature_def.gd`'s
`armored_charger` doc, `essences.gd`'s header. The count pins move to the build step that adds the rooms, not before it.

## Testing approach

- Data: every room validates and lints clean; spawn keys unique; the pacing rule; the D1 stored kit's eligibility; the Tremor threshold above the
  pre-Deep earth supply; nothing spawns or stands in F4's opened doorway zone (`RoomLint` checks solids only; the Flooded's own 188 pin already guards the relocation); creature stats at `DEEP_LEVEL` (a pin like
  the Flooded's); every creature def loads with its sheet and every frame, its portrait and its clips.
- Behaviours: a wolf that sees you alerts a wolf within 240 px and not one beyond, never alerts an ant, and the mate is calm again ALERT_MEMORY after its finder loses sight (one line: it is the existing decay); a creature alerted by a packmate does not alert onward; a `charges` creature is a CHARGER, is stunned by a front
  tackle, and the drake is not; the drake's slam hits a grounded player in the zone, misses an airborne one, misses one outside the zone (horizontally and
  vertically), and a stun cancels the windup; each Deep creature has a `pick` arm that is not `idle` while moving.
- Tremor: damages grounded enemies through DEF with an exact expected number at ATK > 1 and stuns them; skips a flier in the air, a body off the floor,
  one out of range (the in-air and off-floor cases are one parametrised case), a shortcut switch, and the serpent's stun (it takes the hit); hits a crab on
  a ledge above the caster; casts while airborne and hits what stands on the floor below within the radius; hits a stunned flier that landed; never hurts the player; unlocks at its threshold and
  levels with use; casts with its scene.
- Traversal: the D3 strip test; in the slice, D6's reachability and chimney assertions.
- Real screenshots of each room, each creature, a stomp (the windup and the held slam pose), a pack, and the map tab.

## Build order

1. Data: the Tremor skill and its stub scene, the three creature defs and their registration, the `CreatureDef` flags, the rescoped pins.
2. Behaviours: `_share_alert`, the `charges` arm, the stomp in `_charger_act`, `Tremor`, the animation arms and clips.
3. Art: the three creature frame sets and the Tremor icon, generated in parallel.
4. Rooms: F4's east exit (and its relocated lizardman and flowers), D1–D5 authored by script through the editor model, the D1 pool and kit, the tablet,
   the D3 chain test, the kit-test table, docs.
5. The rare slice: the derived Taratect sheet, def, clips and portrait, D2's chimney and top exit, D6, its reachability and chimney assertions.
6. Review, gate, merge.

## Rulings made in this spec

- The Deep is entered by a side exit from F4, not a floor hole under F5: no chain at the entry, F5 stays the Flooded's rest nook. Cost if wrong: it reads
  as "east" more than "down"; moving the door is a data edit.
- F4's fourth lizardman and its flowers are relocated out of the doorway's clear zone, not deleted. Cost if wrong: F4's east end is a little more crowded.
- Tremor's unlock is earth ×24, derived by a test from the room data, not ×4: earth is in the Cave from the start. Cost if wrong: a constant; a life that
  has not eaten the world meets the skill in the Deep.
- Tremor ignores DEF through the existing `ignore_def` parameter, not a new damage type, and hits whatever stands on the floor within 72 px (a stunned
  flier that has landed included). It needs no caster condition. Cost if wrong: a filter.
- `flight` stays reserved: Glide changes the player's physics and needs gap design and a gate, which is a spec of its own. Cost if wrong: the moths'
  flight essence stays decorative a little longer.
- The pack shares its alert by timer, not line of sight, within 240 px and among its own kind only (wolves do not wake ants); an alerted mate never
  re-broadcasts. Cost if wrong: one id comparison.
- The wolf is a `charges` creature (the charger sequence, no armored front) rather than an `armored_charger`: tackles still stun it from the front.
- The stomp is a `stomper` variant inside the charger sequence, not a new Kind (the simplifier's finding): no new tokens, arms or telegraph code. Cost if
  wrong: if the branching passes about 15 lines the plan extracts a `_stomp` helper called from `_charger_act`.
- Creature stats scale by +8% a level at level 10 (`DEEP_LEVEL`). The drake's 28 HP, DEF 5 and ATK 7 make it the area's wall. Cost if wrong: a tuning constant.
- The Taratect is the Black Spider's behaviour on a derived sheet: no new behaviour code, but the spider arm, clips, portrait and registrations learn its id.
- The pacing rule couples to the Flooded's total (computed from data), so editing the Flooded's spawns changes the Deep's bound. The D1 kit's tests are one
  shared table, not a third copy.
- D1's kit grants Tremor (the area's own skill, as F1's grants Swim) and starts at level 5.
- D1 holds three ants and the pool; its ants share one pack within 240 px, so a sighting pulls all three onto a freshly reborn life. Accepted.
- No darkness or lighting: the Deep's feel is its art, tint, ambience and music, which already ship.
- Deferred to a playtest: the drake's slam reach against the jump arc, the drake's ATK 7 and DEF 5 against a stage-2 body, and D4's pack density.
