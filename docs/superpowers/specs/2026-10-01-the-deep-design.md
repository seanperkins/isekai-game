# The Deep — Design

Status: draft before the debate (2026-10-01). Sub-project 7, the fourth area. It builds on the exploration spec
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
creatures and one rare one, **Tremor** (the first skill the `earth` essence feeds), three new behaviours (a pack that shares its alert, an unarmored
charger, a ground stomp), the area's rebirth pool and the third real kit.

One isolable slice sits at the end of the build order and the core ships and tests without it: **the rare slice** (the Taratect on a derived
sheet, D6 and its wall-cling gate). Nothing else here is a slice: the creatures, Tremor and the five rooms are the area.

## Decisions

| Topic | Decision |
|---|---|
| Entry | F4's east edge opens into D1's west edge: a side exit pair at the same world span, ungated (F4 is behind the Swim door already). No floor hole, so no ledge chain |
| Rooms | D1 Gloom Gate (1×1, the rebirth pool), D2 Wolf Run (2×1), D3 the Sinkhole (1×2, a climb), D4 the Den (2×1), D5 the Heart (1×1, Glow Pool and tablet; the area's last room); slice: D6 the Hollow (1×1, above D2) |
| Creatures | Gloom Wolf, Armed Ant, Stone Drake; in the slice the rare Taratect (a derived sheet of the Black Spider, no new drawing) |
| New behaviour | **Pack** (a creature that sees you alerts every same-kind packmate near it), **charges** (the charger's sequence without the armored front: the wolf), **stomper** (the drake: a telegraphed ground slam you dodge by being airborne) |
| Skill | **Tremor**, an essence skill from `earth` ×4 that slams the ground: damages grounded enemies through their DEF and stuns them. It is the counter to armor and the first use of `earth`. `flight` stays reserved (see Out of scope) |
| Art | Three frame sets (wolf, ant, drake) generated one at a time (the Grotto's pipeline) and assembled with traced shapes; the Taratect derives from the spider's frames; one skill icon. Tiles, backgrounds, decor, ambience and music exist |
| Evolution | Unchanged: `FormOffers.FIRST_EVOLUTION_AREAS` stays `["cave","grotto"]`. A life reborn in the Deep counts its Deep absorptions in the numerator in full (the Flooded's note) |
| Rebirth | D1 holds the area's pool and the third real kit (below) |
| Pacing | One rule, below: the Flooded and the Deep together fill stage 2; the Deep alone does not |
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
span (the validator enforces both). The map tab's room count goes from 17 to 22 (23 with D6); its bounds are computed from the rooms.

- **D1** (the landing): flat and open, with the area's rebirth pool a little way in and four Armed Ants. The entry span is a doorway in F4's east wall at
  floor height (F4's east end is moved to make it; nothing spawns on it).
- **D2** (wolves): a long hall with three Gloom Wolves and two ants; low ledges to jump a charge. In the slice, a one-screen chimney in its east half
  (two facing walls) under the top exit.
- **D3** (the Sinkhole): a tall shaft with a ledge climb between its two exits (base jumps only: every hop at most 55 px up, a ledge in every 55 px band),
  a Stone Drake on its floor shelf and ants. D2 enters at its upper row, D4 leaves from its lower row, so the shaft is climbed in both directions.
- **D4** (the Den): a wide cavern of four wolves and a drake with platforms over it. The pack is the room's danger.
- **D5** (the Heart): the Glow Pool, a tablet, a drake and a wolf; the area's last room (the Serpent's route is out of scope, so docs/rooms.md says the
  world ends here for now).
- **D6** (slice): the Hollow, a pocket above D2's chimney with the Taratect hanging from its ceiling.

### Traversal

- No floor hole means no one-way drop: every room joins its neighbours by side exits, and D3's climb is a ledge chain a base jump walks in both directions.
  The existing reachability test (base jumps only) covers D1–D5; D1 sits behind the Swim door because F4 does.
- **D6's gate** (slice) is the Grotto's G5 pattern, restated for the Deep: the chimney screens the opening below every early jump, no base-jump path reaches
  the top exit's sill, and Wall Cling does. It is the existing `wall_cling` label; no new gate label. A gated exit matches on both halves.

## Creatures

New ids: `gloom_wolf`, `armed_ant`, `stone_drake` (and `taratect` in the slice), added to `Sources.ALL`, generated by `tools/build_content.gd`, with
their portraits read from the creature's own sheet frame.

| Creature | HP | ATK | DEF | SPD | Essences | XP | Behaviour |
|---|---|---|---|---|---|---|---|
| Gloom Wolf | 6 | 3 | 0 | 100 | sound 1, earth 1 | 6 | A pack charger: patrols its beat; a wolf that sees you alerts every wolf within 240 px; each flicks and charges when level with you (the charger's windup, charge and rest). Not armored: a front tackle stuns it |
| Armed Ant | 5 | 2 | 1 | 90 | armor 1, earth 1 | 3 | A pack walker: patrols, and once alerted (by sight or a packmate) chases at full speed while level with you; weak alone, dangerous as four |
| Stone Drake | 16 | 4 | 3 | 40 | earth 3, armor 1 | 12 | The stomper: walks toward you at its slow pace; when you are within 110 px and level it rears (the windup), then slams: if you are on the floor within 110 px and level it hits you, so you dodge by being airborne. Rests 1.4 s. Armored front: stunned only from behind |
| Taratect (rare, slice) | 14 | 5 | 1 | 120 | thread 3, poison 2 | 12 | The Black Spider's ceiling dropper on an enlarged, tinted derived sheet |

First-time value per spawn is twice the XP (down plus eat, paid once each): wolf 12, ant 6, drake 24, taratect 24.

The table's HP, ATK and DEF are level-1 bases: the generator scales them by +8% a level at level 10 (`DEEP_LEVEL`), as the Flooded's are at 7 and the
Grotto's at 4 (so a wolf has 10 HP, an ant 9, a drake 27).

### What `CreatureDef` and `Enemy` gain

- `CreatureDef` gains three flags: `pack` (the wolves and ants), `charges` (the wolf) and `stomper` (the drake). `armored_charger` stays the armored front
  (the drake sets it too: it decides tackles, not the behaviour).
- **Kind.** One new Kind, `STOMPER`. `_resolve_kind` order becomes: the snake by id, ceiling walker, drifter, flier or swimmer, **stomper**, armored
  charger or **charges**, spitter, walker. The wolf is a CHARGER through `charges`; the ant stays a WALKER.
- **Pack.** In `_sense`, a pack creature that sees you calls `_share_alert()`: every other creature in a `pack` group with the same def id within
  `PACK_RADIUS` (240 px) gets `_alert = ALERT_MEMORY` (no line of sight needed, refreshed every frame its finder still sees you). Alert is a timer
  the creature already has (`is_alert()`), so a packmate chases or charges by its own existing logic and forgets you ALERT_MEMORY (2 s) after the finder
  loses you. A creature alerted this way never alerts others (only sight does), so a pack does not chain across a level.
- **The wolf's charge.** The CHARGER sequence (`_charger_act`) is reused. `charges` only widens the Kind check: `receive_tackle` still reads
  `armored_charger` for the front block, so a wolf is stunned from the front and a drake is not.
- **The stomp.** `_stomper_act(to_player, delta)` with tokens `""`/`windup`/`slam`/`rest`. In `""` it walks like `_walk`; alerted, within
  `STOMP_RANGE` (110) horizontally and `STOMP_LEVEL` (40) vertically, it enters `windup` (`STOMP_WINDUP` 0.7 s, the telegraph tint). At the end of the
  windup it slams (`slam`, one frame): the player takes `receive_hit(atk, "physical", position)` if on the floor and within `STOMP_REACH` (110) x and
  `STOMP_LEVEL` (30) y. Then `rest` (`STOMP_REST` 1.4 s). A stun cancels the sequence like every other kind's (the status machine owns it).
- **Animation.** `EnemyState.pick` shares arms where the behaviour matches: `gloom_wolf` joins the crab's charger arm (`windup`, `charge`, `rest`),
  `armed_ant` the plain walker's, and `stone_drake` has its own (`windup` rear, `stomp` slam, `rest`). `data/enemy_clips.json` gains each sheet's clips,
  and the test that walks every creature × every state still passes.

### Frames (each generated alone, then assembled with a shared per-creature scale)

- Gloom Wolf (11): the charger's list (idle, walk ×3, windup, charge ×2, rest, stunned, hurt, downed).
- Armed Ant (7): idle, walk ×3 (loop 1,2,3,2), stunned, hurt, downed.
- Stone Drake (9): idle, walk ×3, windup (rearing), stomp (the slam), stunned, hurt, downed.
- Taratect: derived from the spider's frames (`derive_from`, `tint`, an enlarge factor); no prompts.
- Their deaths, corpses, hit shapes and the contact fairness rules are the Cave's.

## Skills and essences

| Skill | Source | Unlock | Effect | Levels |
|---|---|---|---|---|
| Tremor | essence | absorb earth ×4 | Active, 5 MP: slam the ground. Every enemy standing on the floor within 72 px (and 28 px vertically) takes 3/4/5/6/7 damage that ignores its DEF and is stunned for 1.0 s | used ×8, max 5 |

- Tremor is an ability in `scripts/abilities/` modelled on `Jolt`, using `Ability.targets_around(radius)` filtered to bodies on the floor, and
  `receive_hit(damage, "physical", from, "other", true)` (the existing `ignore_def` weak-point parameter: no new damage type). `EnemyStatus.stun`
  already keeps the longer timer. Fliers, swimmers and drifters are not on the floor, so Tremor never hits them; it never hurts the player.
- Registration surfaces (the Flooded's list): `Sources.ALL`, `tools/build_content.gd` (skill and creatures), the audio catalog (`skill_used.tremor`
  gets a cue; the Water Blade cue is reused, as Jolt reuses it), the icon manifest (one 32×32 icon), `test_skill_caps`'s `TABLE`, `DefValidator`, the
  compendium and `test_content`'s counts.
- `earth` already exists in `Essences.ALL` and `RebirthKit.ESSENCES`; its header comment ("feed no skill yet") changes: earth feeds Tremor, flight
  alone is reserved.

## Rebirth

D1's `rebirth_pool` has id `D1`, area `deep`, and the kit: skills Leap, Wall Cling, Swim and Tremor (level 1, quietly granted), character level 5,
and affinity seeds chosen by a test, not by hand. The test counts the lineages eligible from the seeds plus what the kit can eat in D1 and D2 (the
rooms before the first heavy) against the first-evolution supply and asserts at least two are eligible and more than the same life has without
the seeds. A level-5 life needs 30 + 35 + 40 + 45 + 50 = 200 XP to the cap: more than D1 and D2's first pass (24 + 48 = 72, so it cannot evolve before
the Sinkhole) and less than the Deep's whole first pass (so a Deep-born life can finish stage 1 here, by design). Two assertions pin it.

## Pacing

One rule, computed by a test from the room data: a spawn's **first-time value** is twice its `xp` (a `water_pool` pays once), summed over the rooms'
non-optional set (D1–D5; D6 never).

- The Flooded's first pass (F1–F5, 188 today) plus the Deep's reaches stage 2's cap (403): a life that evolved at the Grotto's end finishes stage 2
  at the Deep's end.
- The Deep alone is below 403: stage 2 needs the Flooded too.

A guide, not a contract: D1 4 ants (24); D2 3 wolves and 2 ants (48); D3 1 drake and 3 ants (42); D4 4 wolves and 1 drake (72); D5 1 drake and 1 wolf (36) sum to
222, and 188 + 222 = 410.

## Existing tests rescoped

`tests/support/shipped_rooms.gd` (`IDS`, and its docstring's room and rule counts), `test_rooms` (its room id list), `test_constants` (`Sources.ALL`),
`test_audio_catalog` (the Tremor cue), `test_content` (counts of skills and creatures; its "every essence skill is supplied" check learns Tremor),
`test_enemy_sheets` (`SETS`), `test_skill_caps` (`TABLE`), `test_decor_lib` (its used-id pins change when the D rooms use `deep_*` pieces), the rebirth
kit tests (the eligibility test skips every pool outside the Grotto and the Flooded and hard-codes the rooms a life eats in: it learns D1 and D1/D2),
`test_world_view` (the room count, 17 to 22/23), `test_enemy_kind` (its KINDS pins), and the progression pacing tests (the Cave, Grotto and Flooded rules
stay scoped to their areas). The docs and comments that change: `docs/rooms.md` (the F5 and F4 rows; the rooms table; "the last room"),
`docs/playtest-checklist.md` (a Deep section), `enemy.gd`'s Kind and state-token docs, `essences.gd`'s header. The count pins move to the build step
that adds the rooms, not before it. The plan derives the exact list from a full-suite run after each registration step.

## Testing approach

- Data: every room validates; spawn keys unique; the pacing rule; the D1 kit eligibility; nothing spawns over F4's opened doorway or near a pool;
  every creature def loads with its sheet and every frame.
- Behaviours: a wolf that sees you alerts a wolf within 240 px and not one beyond, and never alerts an ant; a creature alerted by a packmate does not
  alert onward; a `charges` creature resolves to CHARGER, is stunned by a front tackle and the drake is not; the drake's slam hits a grounded player in
  reach, misses an airborne one, misses one out of reach, and a stun cancels the windup; every creature × state has a clip.
- Tremor: damages grounded enemies through DEF and stuns them, skips a flier and a swimmer and an enemy out of range or off the floor, and never
  hurts the player; it unlocks at earth ×4 and levels with use.
- Traversal: the existing base-jump reachability test covers D1–D5; in the slice, the three D6 gate tests.
- Real screenshots of each room, each creature and a stomp.

## Build order

1. Data: the Tremor skill and the three creature defs and their registration, the `CreatureDef` flags, and the rescoped pins.
2. Behaviours: `_share_alert`, the `charges` Kind arm, `STOMPER` and `_stomper_act`, `Tremor`, the clips.
3. Art: the three creature frame sets and the Tremor icon, generated in parallel.
4. Rooms: F4's east exit, D1–D5 authored by script through the editor model, the D1 pool and kit, the tablet, docs.
5. The rare slice: the derived Taratect sheet, def and clips, D2's chimney and top exit, D6, the three gate tests.
6. Review, gate, merge.

## Rulings made in this spec

- The Deep is entered by a side exit from F4, not a floor hole under F5: no chain, no one-way drop, F5 stays the Flooded's rest nook. Cost if wrong:
  the Deep reads as "east" more than "down"; moving the door is a data edit.
- Tremor ignores DEF through the existing `ignore_def` parameter, not a new damage type, and hits only creatures on the floor. Cost if wrong: it also
  cannot hit a stunned flier; fixable in the filter.
- `flight` stays reserved: Glide changes the player's physics and needs gap design and a gate, which is a spec of its own. Cost if wrong: the moths'
  flight essence stays decorative a little longer.
- The pack shares its alert by timer, not line of sight, within 240 px and among its own kind; an alerted mate never re-broadcasts. Cost if wrong: a wolf
  pulled alone pulls its pack, which is the point; a chain across a level is impossible by construction.
- The wolf is a `charges` creature (the charger sequence, no armored front) rather than an `armored_charger`: tackles still stun it from the front.
- The stomp is the one new Kind rather than a charger variant: it has its own tokens and a hit that depends on the player being airborne.
- Creature stats scale by +8% a level at level 10 (`DEEP_LEVEL`). Cost if wrong: a tuning constant.
- The Taratect is the Black Spider's behaviour on a derived sheet: it needs no new code, and its rarity comes from its room.
- The pacing rule couples to the Flooded's total (computed from data), so editing the Flooded's spawns changes the Deep's bound. Cost if wrong: one test.
- D1's kit grants Tremor (the area's own skill, as F1's grants Swim) and starts at level 5.
- No darkness or lighting: the Deep's feel is its art, tint, ambience and music, which already ship.
- Deferred to a playtest: the drake's slam reach against the jump arc, and D4's pack density against stage 2's damage.
