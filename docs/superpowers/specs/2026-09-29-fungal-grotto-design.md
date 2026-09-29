# The Fungal Grotto — Design

Status: draft for review (2026-09-29). Sub-project 5 of `2026-09-28-slime-forms-and-animation-design.md`
(section 4), built on the exploration spec (`2026-09-28-exploration-world-design.md`, Plan 2) and on what
has since shipped: frame-drawn creatures with kill-type deaths and shape hits, per-room set dressing,
evolution, and rebirth pools.

## Goal

Ship the second area. You reach it by dropping out of the Cave's Drop Shaft. It adds six rooms, four
creatures (drawn and animated like the Cave's), two essences and two skills, a rebirth pool with the first
real kit, the menu that lets you choose where to be reborn, and the pacing that makes the first evolution
land near its end.

## Decisions

| Topic | Decision |
|---|---|
| Entry | C5's floor opens: a `bottom` exit from C5 to G1's `top`. Nothing else connects the Cave and the Grotto |
| Rooms | G1 Grotto Mouth (2×1), G2 Spore Hall (3×2), G3 Vine Maze (2×2), G4 Glow Pool (1×1), G5 Pale Moth (1×1, wall-cling gated), G6 nook (1×1) |
| Beyond G3 | The Flooded Tunnels are a later plan: G3 has no exit down. The spec's "shortcut back to C1 from G4" is dropped: rebirth pools already solve travel |
| Torches / camp | None. Light is glowing fungus and spores. The nook holds a tablet; the abandoned-camp brazier from the earlier spec needs art that does not exist and is dropped |
| Creatures | Spore Moth, Mushroom Crab, Vine Snake, and the rare Pale Moth, which is the Spore Moth's sheet tinted and enlarged (a variant, not new art) |
| Art | The four creatures' frames are generated individually (the Plan 2/3 pipeline), assembled into `spore_moth`, `mushroom_crab` and `vine_snake` sheets with traced shapes. The Grotto gets its own dressing library (`dressing_grotto`, 8 pieces, mushroom-heavy) |
| Essences | `spore` and `shell` join `Essences.ALL`. Spore feeds the Toxic lineage, shell the Bulwark lineage (already in their `FormDef.essences`) |
| Skills | Spore Cloud (essence, active) and Hardened Shell (essence, passive), written for the raised maxima: Spore Cloud max 8, Hardened Shell max 8 |
| Rebirth | G1 holds the Grotto's pool. Its kit is a head start sized to the area (below). The `ReincarnationMenu` ships now |
| Pacing | A first-time pass of the Cave plus the Grotto pays at least 270 XP; the Cave alone pays under 270 |
| Out of scope | The Flooded Tunnels, Swim, shock, Jolt and Storm Jet; the Serpent Lair and victory; a second species |

## Layout

Cells are in screens (640×360). C5 is at cell (5,2) and is 1×3, so it ends at row 5.

```
[C5 Drop Shaft 1×3]  (bottom exit)
        │
[G1 Grotto Mouth 2×1  cell (5,5)]─[G2 Spore Hall 3×2  cell (7,5)]─[G6 nook 1×1  cell (10,5)]
                                        │ bottom exit (x in 8..9)
[G5 Pale Moth 1×1 cell (7,7)]⋯wall cling⋯[G3 Vine Maze 2×2  cell (8,7)]─[G4 Glow Pool 1×1  cell (10,7)]
```

- G1: the landing (a soft floor of moss under C5's exit), the rebirth pool, a first look at moths and
  crabs. The pool stands a little way in from the entrance, per the reincarnation spec.
- G2: the hub. Wide, two floors of mushroom-cap platforms, spore haze, all four ordinary creatures.
- G3: vines. Vine Snakes hide in the vine decor and lunge as you pass under; crabs patrol the ground.
- G4: a Glow Pool, a rest before the end of the area.
- G5: the rare room, reachable only by wall cling from G3 (the same gate style as C2's chimney).
- G6: a nook off G2 holding a tablet and a lit crystal cavern.
- Every exit is matched on both sides and spans clear of corners and the floor (the world validator
  already enforces this), and every exit fits the 2× slime (the Plan 1 test covers all rooms).

## Creatures

Approved numbers from the exploration spec. Behaviours reuse the enemy skeleton (`EnemyState`, telegraphs,
kill-type deaths, shape hits) and add one new pattern each.

| Creature | HP | ATK | DEF | SPD | Essences | XP | Behaviour |
|---|---|---|---|---|---|---|---|
| Spore Moth | 3 | 1 | 0 | 90 | spore 1, flight 1 | 2 | Flies in slow loops; every 3 s it drops a spore puff (poison 1, a short-lived hazard) under itself |
| Mushroom Crab | 8 | 2 | 2 | 70 | shell 2, earth 1 | 4 | Walks sideways; charges when level with you (telegraphed like the lizard); its shell blocks front tackles |
| Vine Snake | 5 | 3 | 0 | 150 | poison 1, thread 1 | 3 | Waits still inside vine decor; when you pass under it, it telegraphs and lunges out, then retreats |
| Pale Moth (rare) | 6 | 1 | 0 | 110 | spore 3, flight 2 | 8 | A faster, paler, larger Spore Moth with bigger puffs |

- `CreatureDef` gains `sprite_set` (the sheet, default its id), `tint` and `size`, so the Pale Moth wears
  the Spore Moth's sheet without new art. The enemy loads its sheet from `sprite_set`.
- Frames (each generated alone, then assembled with a shared per-creature scale):
  - Spore Moth: fly ×4, puff ×2, stunned, hurt, downed.
  - Mushroom Crab: idle ×2, walk ×4, windup ×2, charge ×2, rest ×1, stunned, hurt, downed.
  - Vine Snake: hide ×1, coil ×2, lunge ×2, slither ×4, stunned, hurt, downed.
- Their deaths, corpses (clippable), hit shapes and the contact fairness rules are the Cave's.
- Spore puffs are hazards in group `hazards`, like the toad's glob, and hurt with the shape-hit rule.

## Essences and skills

| Skill | Source | Unlock | Effect | Levels |
|---|---|---|---|---|
| Spore Cloud | essence | absorb spore ×4 | Active, 4 MP: a lingering cloud (2 s) on the aim that slows enemies and poisons them 1/s | used ×8; max 8: size and duration grow |
| Hardened Shell | essence | absorb shell ×4 | Passive: DEF +1 per level up to +8, knockback reduction 15% per level (max 60%) | take physical hits ×10; max 8 |

- Both need icons, generated like the existing ones and added to the manifest with the tests that pin
  the sprite count.
- Their maxima are within what their sources supply (the reachability test extends to them).

## Rebirth

- G1's `rebirth_pool` has id `G1`, area `grotto` and the kit: skills Leap and Wall Cling (level 1, quietly
  granted), character level 3, and seeded affinity chosen so at least two lineages are eligible from the
  Grotto's larger supply (a test computes it, not hand-tuned).
- The `ReincarnationMenu` (a `CanvasLayer`) shows the `RebirthChoice` decision when `Run` emits
  `choice_needed`: a vertical list with the last choice selected, locked pools as "???", and a confirm
  prompt. Up/Down (or the stick) moves, Enter/A confirms and calls `Run.choose`; a locked entry cannot be
  confirmed. It works with a controller and a keyboard, and does nothing until a decision is pending.

## Set dressing and art

- The Grotto's rooms get set dressing like the Cave's: a Grotto library of eight pieces (giant mushroom
  cap pillar, hanging spore-moss, glowing mushroom cluster, mushroom bridge, vine curtain, spore pod,
  stalactite with moss, dripping fungus shelf) in `assets/dressing/grotto/`, authored per room in
  `tools/build_world.gd` with the same validator.
- The Grotto's terrain art already exists (`assets/tiles/grotto`, `assets/backgrounds/grotto`).

## Pacing

Spawns are authored so a first-time pass (down and eat, each paid once per spawn) of the Grotto is worth
at least 146 XP, which with the Cave's 124 makes at least 270, while the Cave alone stays under 270. A test
computes both from the room data.

## Testing approach

- Data: every room validates (exits matched, spans, spawns known, features valid, dressing pieces known);
  spawn keys are unique; the pacing numbers above; the G1 kit validates and leaves two lineages eligible;
  every emitted event has an audio cue.
- Creatures: each behaviour has a scripted test (moth puff cadence and hazard, crab telegraph then charge
  and shell-blocked front tackle, snake hide-lunge-retreat); each sheet loads with every listed frame, on
  the floor line, with shapes hugging pixels; clips reference real frames; the Pale Moth uses the moth
  sheet tinted and larger.
- Skills: Spore Cloud spawns a cloud that slows and poisons and expires; Hardened Shell changes DEF and
  knockback per level; both unlock and level from their events; the validator accepts them.
- Menu: the decision renders in order, moves, confirms only unlocked entries, pre-selects the last choice,
  and drives a real death-to-new-life flow with the Grotto pool attuned.
- Real screenshots of each Grotto room, each new creature and the menu.

## Build order

1. Data: essences, the two skills, creature defs and `CreatureDef` sprite fields.
2. Art: the three creature frame sets and the Grotto dressing library, generated in parallel.
3. Behaviours: moth, crab, snake and the Pale Moth variant, with their sheets.
4. Rooms: G1–G6 authored, C5's exit, dressing, spawns tuned to the pacing.
5. Rebirth: G1's pool and kit, the menu.
6. Review, gate, merge.
