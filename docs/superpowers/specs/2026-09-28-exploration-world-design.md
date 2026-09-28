# Exploration World — Design

Status: draft for review (2026-09-28). Builds on `2026-09-27-slime-prototype-design.md`.

## Goal

Turn the single big cave into a hand-built, interconnected world you explore room by room,
like Hollow Knight, while keeping the roguelite loop: death restarts the run, and knowledge
persists. The world has three areas (Cave, Fungal Grotto, Flooded Tunnels), six new
creatures, new essences and skills, and the Cave Serpent as the run's goal. Exploration is
rewarded for its own sake, not only with items.

## Decisions (from the interview)

| Topic | Decision |
|---|---|
| World | One fixed, hand-built map, the same every run |
| Death | The run restarts in Cave 1. Skills, levels and stats reset |
| Persists across runs | Compendium, Bestiary, the map, opened shortcuts, read tablets |
| Rooms | Mixed sizes of 1–4 screens. The camera scrolls inside a room |
| Exits | On any of the four edges. Rooms connect sideways, up and down |
| Transition | Camera slide into the next room. You keep your momentum |
| Enemies | Respawn every time you enter a room |
| Gating | Soft gates. The main route needs only jumps. Side paths and shortcuts need skills |
| Side-path rewards | Rare creatures, shortcuts, hint tablets, and places that are only there to be found |
| Map | A Map tab on the menu screen, auto-filled as you visit rooms |
| Rest spots | Glow Pools, about one per area. They restore HP and MP. They are not respawn points |
| Announcer | Code keeps the name Great Sage. Pop-ups are labelled "A voice" |
| Goal | Cave 1 → … → Serpent Lair. Beating the serpent wins the run |
| Content | 2 new areas, 6 creatures, new essences and skills, with Swim as the traversal skill |
| Deep water | Before you have Swim it slows you and you slowly sink. With Swim you move freely |
| Loaded rooms | One room is live at a time, and nothing carries across an exit. This is an accepted trade-off: it is simple and matches Hollow Knight, but seamless streaming later would mean rewriting the transition and entity lifecycle |

## World layout

19 rooms: 16 on the routes plus 3 nooks (C6, G6 and F7, one per area). Sizes are in screens (1 screen = 640×360). The arrows are the main route;
the dotted links are soft-gated.

```
     [C6 nook]─[C3 Spider Loft 1×2]
                   │ up (wall cling or swing)
[C1 Start 2×1]─[C2 Thread Gap 2×1]─[C4 Glow Pool 1×1]─[C5 Drop Shaft 1×3]
      ⋮ shortcut back (opened from G4)                     │ down
                                                     [G1 Grotto Mouth 2×1]─[G2 Spore Hall 3×2]─[G6 nook]
                                                                                │
                              [G5 Rare: Pale Moth 1×1]⋯(wall cling)⋯[G3 Vine Maze 2×2]─[G4 Glow Pool 1×1]
                                                                                │ down
                                                           [F1 Flood Gate 2×1]─[F2 Eel Channel 3×1]
                                                                  │                  ⋮ (Swim)
                                                  [F7 nook]─[F3 Sunken Hall 2×2]    [F6 Rare: Storm Eel 1×1]
                                                                  │
                                                           [F4 Glow Pool 1×1]─[F5 Serpent Lair 3×2]
```
- **Cave (C1–C5):** today's cave, cut into rooms. The layout, lights and food are kept, so
  every Plan 2 skill can still be earned here.
- **Fungal Grotto (G1–G5):** glowing mushrooms, spore haze, vines. It adds spore and shell
  essences.
- **Flooded Tunnels (F1–F6):** shallow and deep water, and shock creatures. It adds shock
  essence and Swim.
- Every area has one **nook**: C6 off C3, G6 off G2, and F7 off F3. A nook is a small 1×1
  dead-end room that holds only a vista, a tablet or a lit crystal cavern. Nooks are ordinary
  rooms, so they count toward "Rooms found".

## Rooms and transitions

- `RoomDef` is a resource in `data/rooms/*.tres`, generated from `tools/build_world.gd`
  (content stays data-driven, like skills). It holds:
  - `id` and `area`;
  - `cell`: the room's top-left corner on the world grid, in screens. For example,
    C2 = (2, 0). All rooms share one world coordinate space, so a room's world rect is
    `cell × (640, 360)` plus its size. Rooms never overlap (tested);
  - `size`, in screens (for example, 2×1);
  - `solids`, `decor`, `spawns` and `water` (see below), in the same format as today's
    `RoomLayout`;
  - `exits`: `[{edge, from, to, room}]`. `edge` is left, right, top or bottom. `from`–`to`
    is the open span in pixels along that edge, measured in the room's local coordinates.
    `room` is the neighbour's id. There is no separate entry id: because rooms share world
    coordinates, the matching exit is simply the neighbour's opposite edge, and the two
    spans must overlap in world space (tested). The player keeps their world position when
    they cross, so they arrive exactly where they left.
  - `gate` on an exit (optional): the skill the path is designed around. This is
    documentation for level design and tests. The game does not check it.
  - `features`: glow pools, tablets and shortcut switches.
- **World:** one node owns the current room. When the player's centre crosses an open exit
  span, the world:
  1. builds the target room at its world position;
  2. applies the saved state to it (see Persistence);
  3. **freezes the player**: stores their velocity and turns off their physics, so nothing
     moves during the slide;
  4. turns off the camera limits and slides the camera from the old view to the target
     room's clamped view (0.35 s, eased);
  5. sets the camera limits to the target room's world rect;
  6. frees the old room; and
  7. unfreezes the player with the stored velocity.

  Bodies and projectiles never carry over between rooms.
- **Entering from below** gives a small upward boost, so a jump through a floor hole always
  clears the lip. **Falling in from above** keeps its fall speed.
- **Tests:**
  - Every exit has a matching exit back.
  - Spans on paired edges line up.
  - Every room on the main route can be reached from C1 using base jumps only (a BFS like
    today's ledge test, but across rooms).
  - Every gated room can be reached once its gate skill is added.

## Enemies and food

- Spawns rebuild every time you enter a room. Leaving a room clears its bodies.
- The per-run food minimums from the prototype spec still apply to the Cave alone, so
  today's skills stay reachable. Each new area has its own minimums for its essences.
- The Bestiary's "seen" check moves to the room: a creature is seen when it enters the
  camera view.

## Deep water and Swim

- `water` rects in a room mark deep water. Shallow water is decor only.
- `submerged` is a new player event. It goes into `Events.ALL` and the event table in the
  prototype spec, so the validator accepts the Swim skill. The player emits it once per
  second of time underwater, and only the player emits it (the actor boundary).
- **Without Swim:**
  - horizontal speed ×0.6;
  - gravity ×0.35, with a sink cap of 60 px/s;
  - Jump gives a small bob (−160) instead of a full jump.
  - Time underwater emits `submerged` once per second. This is a new event, and it is the
    counter behind Swim.
- **With Swim:** full 8-way movement at 120 px/s (Swim levels raise it), no gravity, and
  Jump launches you out of the surface.
- F2 → F6 is a flooded tunnel that is too long to cross by bobbing. That tunnel is the Swim
  gate.

## New creatures

These are the approved creatures, with starting numbers. Art will be generated with Codex in
Style D, like the existing sprites.

| Creature | Area | HP | ATK | DEF | SPD | Essences | Behaviour | XP |
|---|---|---|---|---|---|---|---|---|
| Spore Moth | Grotto | 3 | 1 | 0 | 90 | spore 1, flight 1 | Flies in slow loops and drops a spore puff (poison 1) under itself every 3 s | 2 |
| Mushroom Crab | Grotto | 8 | 2 | 2 | 70 | shell 2, earth 1 | Walks sideways. Charges when you're level with it. Its shell blocks front tackles (like the lizard) | 4 |
| Vine Snake | Grotto | 5 | 3 | 0 | 150 | poison 1, thread 1 | Hides in vine decor, then lunges out when you pass under | 3 |
| Glass Eel | Flooded | 4 | 2 | 0 | 140 | shock 1, water 1 | Swims only in deep water. A contact shock stuns you for 0.3 s | 3 |
| Cave Crayfish | Flooded | 9 | 3 | 3 | 60 | shell 1, water 1 | Patrols the shallows and pinches with a short lunge. It can only be stunned from behind | 5 |
| Drift Jelly | Flooded | 3 | 2 | 0 | 30 | shock 1, water 2 | Drifts up and down. It stings on contact and can't be tackled (you must use a skill or a thread) | 3 |
| Pale Moth (rare) | G5 | 6 | 1 | 0 | 110 | spore 3, flight 2 | A faster moth with bigger spore puffs | 8 |
| Storm Eel (rare) | F6 | 10 | 4 | 1 | 160 | shock 3, water 2 | A bigger eel whose shock also chains to nearby water | 10 |

These add new essences `spore`, `shell` and `shock` to `Essences.ALL`, and new sources to
`Sources.ALL`.

## New skills

| Skill | Source | Unlock | Effect | Levels |
|---|---|---|---|---|
| Spore Cloud | essence | absorb spore ×4 | Active, 4 MP: a lingering cloud (2 s) on the aim that slows enemies and poisons them 1/s | used ×8, max 5: size and duration |
| Hardened Shell | essence | absorb shell ×4 | Passive: DEF +1/+2/+3, knockback −30/−45/−60 % | take physical hits ×10, max 3 |
| Jolt | essence | absorb shock ×4 | Active, 5 MP: a burst of shock around you (radius 40) that deals 3/4/5/6/7 and stuns jellies and eels | used ×8, max 5 |
| Swim | proficiency | `submerged` ×20 (seconds underwater) | Movement in deep water as described above | `submerged` ×40, max 3: speed 120/150/180 |
| Storm Jet | evolution (2 EP) | Jolt Lv3 and Hydraulic Propulsion Lv3 | Active, 6 MP: a Hydraulic-style launch that leaves a shocking trail. It replaces Hydraulic Propulsion's slot | — |

Each skill needs an icon, generated like the existing icons.

## Glow Pools, tablets, shortcuts

- **Interaction:** a new `interactable` group, whose members have `interact(player)` and
  `prompt()`. Inspect checks these first: the nearest interactable within 24 px wins. Then it
  checks creatures (`inspectable`, as today), and then yourself. The "Hold K to eat" prompt
  gains a sibling "I: soak" / "I: read".

- **Glow Pool** (C4, G4 and F4, plus one in a secret nook):
  - Stand in it and press Inspect to soak. This refills HP and MP, and the pop-up reads "A
    voice: Your body settles."
  - It is not a checkpoint.
- **Tablet:**
  - Inspect it to read a line of lore.
  - Reading it raises one Compendium slot to HINTED.
  - It is recorded as read in the save.
- **Shortcut switch:** hitting it (tackle or skill) opens a gate between two rooms, for
  example G4 → C1. Opened shortcuts are saved and stay open in later runs.

## Map tab

- It is the fourth tab on the menu screen: Skills, Compendium, Bestiary, Map.
- Rooms are drawn to scale as boxes on a grid. It shows:
  - rooms you've visited, filled;
  - exits you've seen but not taken, as stubs;
  - the current room, highlighted;
  - glow pools and tablets, as icons.
- It also counts how much you've explored: "Rooms found N/19". Nooks are included, because
  they are rooms.

## Persistence and the run lifecycle

- **Profile:** one save file, `user://profile.json`, owned by a `Profile` store. It is the
  only thing that reads or writes persistent data. It holds sections — `compendium`,
  `bestiary`, `map` (visited room ids), `shortcuts` (opened ids) and `tablets` (read ids) —
  and always writes every section together, using the same safe write as today (tmp file,
  verify, rename, backup).
  - The Compendium, Bestiary and Map models keep their data in memory and ask `Profile` to
    save. None of them writes a file itself.
  - On first launch it migrates an existing `compendium.json` (slots and creatures) into the
    new file.
  - A bad section is dropped on its own. The other sections still load.
- **Room state:** when the World builds a room, it asks `Profile` which of that room's
  shortcuts are open and which tablets are read, and applies both before the room enters
  the tree. It also asks the run which switches were hit this run.
- **Run:** a `Run` node owns everything that lasts one run:
  - the player's skills, levels and stats;
  - which room you are in;
  - Glow Pool use.

  The Run handles death (the death card, then reset, then C1) and victory (the summary, then
  reset). The World only handles space: rooms, exits and the camera. `game.gd` shrinks to
  wiring the Run, the World and the HUD together.

## Serpent and victory

- The Serpent Lair (F5) is a sealed 3×2 arena, and the exits lock while the serpent lives.
  It uses the stats from the prototype spec and adds two attacks:
  - Water Blade volleys;
  - a Constrict lunge.
- **Downing the serpent:** a victory screen shows the run summary (skills, level, creatures
  eaten, rooms found). Then a new run starts in C1.
- Dying anywhere shows a short death card, then the run restarts in C1.

## Announcer label

- Pop-ups are titled "A voice" (for example, "A voice — Acquired [Leap].").
- Internal names (`Announcer`, "Great Sage" in code comments) stay as they are for now.

## Out of scope for this pass

- Benches and checkpoints, currency or shops, NPCs, and save slots.
- Procedural rooms.
- Any areas beyond the three.
- Music (the announcement chime from Plan 3 is still in scope).

## Suggested build order (three plans)

1. **World system:**
   - `Profile` (with the migration), `Run`, and interactables;
   - `RoomDef`, the world node, camera-slide transitions and edge exits;
   - cutting the Cave into C1–C6, and respawn on entry;
   - the Map tab and its persistence;
   - Glow Pools, tablets and shortcuts;
   - the "A voice" label.

   Playable at the end: the Cave explored room by room.

   Status: built in Plan 1 (docs/superpowers/plans/2026-09-28-world-system.md).
2. **Fungal Grotto:**
   - the G rooms and their art;
   - Spore Moth, Mushroom Crab, Vine Snake and Pale Moth;
   - spore and shell essences;
   - Spore Cloud and Hardened Shell.
3. **Flooded Tunnels:**
   - the F rooms, deep water and Swim;
   - Glass Eel, Crayfish, Drift Jelly and Storm Eel;
   - shock essence, Jolt and Storm Jet;
   - the Serpent Lair, victory and the death card.
