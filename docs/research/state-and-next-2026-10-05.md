# Where the game stands and what to do next

2026-10-05. Written from the code, data and ledgers on `main` (every number below was counted from `data/` or the ledgers, not remembered). Where I am guessing, it says so.

## Read this first

The evolution roadmap is built: every form of the five species has a world twin, 169 new creatures stand in 47 generated rooms, and the gates, deeds and calibration are in. What is **not** built is mostly the layer that makes it feel like a game: places that look and sound different, bosses, the goddess story, and a world that asks for your forms.

Ranked, with who has to do it:

| # | Next piece | Why it comes first | Who |
| --- | --- | --- | --- |
| 1 | **Play the eight new areas** | 47 rooms pass lint and a reachability model; no ledger records anyone playing them, and `docs/playtest-checklist.md` does not mention them | You play, I prepare a route and a screenshot tour |
| 2 | **Make the new areas ownable**: altars, hand-ownership, own art and music | Eight areas have no altar (a death in the volcano is a long walk), wear the four old backdrops, and a hand edit is wiped by the next `build_areas.sh` | Me (altars, adoption); art needs you or the art process |
| 3 | **Make the world ask for forms** | Only 6 gated doors exist, and only two kinds (`wall_cling`, `swim`). 99+ forms barely change where you can go | Design with you, I build |
| 4 | **The story spine**: bosses, Cave Serpent, last area, goddess reveal, the three missing perks, essence seed | One boss exists (the Taratect, untuned); 1 of 4 perks exists; no reveal | Design with you, I build |
| 5 | **Art that you can maintain** (below): hand-drawn assets, source-of-truth safety, shared rigs | 160 MB of the creature art sources are git-ignored; 169 creatures have no bespoke animation | You draw, I build the hand-off |
| 6 | **Writing**: tablets, goddess lines, creature lore | 9 tablets in the whole game; the goddess has death lines for 18 creatures of 187 (every one of the 169 new creatures falls back to her generic line) | Me drafting in her voice, you rewriting |

## The world as a whole

```
Cave ─── Grotto ─── Flooded ─── Deep ──┬── Cemetery ── Cathedral   (dead end)
  │                    ▲                ├── Crypt ───── Demon       (dead end)
  │ wall_cling         │ shortcut       └── Volcano                 (dead end)
Forest ─── Swamp ─── Village ┘          (Cemetery and Crypt also connect)
```

- It is a chain of four hand-built areas with the eight new ones hanging off it. The Deep is the hub of the late game.
- Three dead ends (Cathedral, Volcano, Demon) are the natural homes for bosses. The Demon area sits furthest east, which is where "the last area past the Deep" naturally continues.
- `data/area_art.json` already names two areas that do not exist yet, `last` and `serpent`.
- Gates: 6 pairs of doors carry a gate label (`wall_cling` x4, `swim` x2). The label does not stop anyone; the movement does.
- Essence supply of the whole world: dark 564, earth 477, air 323, water 152, light 149, mind 97, fire 78, blood 65. The scarce ones are concentrated: light is 56% Cathedral (84 of 149), fire is Volcano 46 and Demon 26 of 78, blood is Demon 27 and Crypt 15 of 65, mind is Cathedral 34 of 97 with the rest scattered. Forms that need them send you to specific areas, which is right.

## The twelve areas, one by one

Counts are rooms / screens / creatures placed. "Mix" is the share of essence a full clear of the area holds.

### The four hand-built areas

**Cave** (6 / 11 / 37). Mix: earth 48, air 30, water 15. Start of the game; the Cave mouth altar, a glow pool, one tablet, one switch. Branches east to the Grotto and up (wall_cling) to the Forest. Placement put 15 twins (5 each of stages 2, 3, 4) in the starting area next to 22 shipped creatures. *Check:* is a stage-4 twin in the first cave the pacing you want? Own art, music and ambience. Altar sells the base-stats perk (the only perk built).

**Grotto** (5 / 14 / 39). Earth 31, dark 30, air 23. Twelve Mushroom Crabs and ten Spore Moths: the densest single-species area. Altar, glow pool, tablet. Own art and music, and the only other biome with dressing pieces. Its altar is meant to sell the extra part slot: **not built**.

**Flooded Tunnels** (6 / 11 / 33). Water 54. Two swim gates, six water rects, altar, glow pool, tablet, switch. Its altar is meant to slow remains decay: **not built**. Village shortcut drops into it.

**The Deep** (7 / 11 / 48). Earth 37, dark 31, air 19. The hub, the boss (Taratect, room D6 behind an antechamber with a pool), and the most crowded area: 25 stage-4 twins. My F2f ledger flagged D2, D3 and D4 at 12 or 13 creatures in two screens. Its altar is meant to grow the death seed: **not built**. One altar means dying to the Taratect costs the walk back from D1 (deferred, boss-arenas ledger).

### The eight generated areas

All eight: no altar (glow pools only), the four old backdrops (forest wears the grotto's, swamp the flooded's, village, cemetery, cathedral and volcano the cave's, crypt and demon the deep's), decor but no dressing, music and ambience of the borrowed biome. All eight are built from code in `tools/areas/` and are regenerated by `tools/build_areas.sh`.

**Forest** (9 / 16 / 34). Earth 31, dark 28, air 23. Above the Cave. Six `moonlit` rooms (a deed), a hold, two gaps, a glow pool. 15 support monsters, 19 twins. Its essence mix is the Grotto's again, so its identity has to come from art, verbs and the moonlight deeds.

**Swamp** (5 / 7 / 17). Dark 41. A barrier and two gaps. Bog Wisp, Blood Leech, Firefly Swarm, Corpse Candle. The thinnest of the early areas.

**Goblin Village** (5 / 8 / 21). Dark 31, earth 25. A lamp and the village watch deed. **Its goblins are hostile** (a known gap: they should be neutral until provoked). Shortcut into the Flooded Tunnels.

**Cemetery** (4 / 6 / 13). Dark 52, light 12. A vigil, a tablet. The smallest and emptiest area. Skeletons, Carrion Crows, a Draugr, a Ghost.

**Cathedral** (5 / 10 / 30). Light 43, mind 17. A lamp, a hidden room, a vigil, a hold. The biggest source of light (84 of 149) and of mind (34 of 97), and a dead end: the natural home for a light or mind boss.

**Crypt** (5 / 10 / 29). Dark 66, blood 9. A lamp and a hold. Skeletons, Vampire Bats, Bone Hounds. Leads on to the Demon area.

**Volcano** (7 / 10 / 17). Fire 62, earth 32. The main fire source (46 of 78; the Demon area has 26). Barrier, switch, two tablets, two pools, a hold. **The heat is not a hazard**: no heat rule exists, so it is a cave with warm tablets. A dead end under the Deep.

**Demon area** (7 / 13 / 24). Dark 51, blood 20, fire 19. A vigil, a hidden room, a tablet. Imps, Blinkers, Demon Hounds. The farthest area east.

## The systems, and how they tie together

**Forms and the world (the biggest gap).** The design says species are runes: a new form opens routes that were closed. Today the world asks for two abilities (wall_cling, swim). The new areas ask for nothing; they gate *forms* (the deeds) but never gate *you*. Candidates the data already supports: heat resistance (the volcano), flight or glide, squeeze through small gaps, break a barrier by strength (the barrier deed exists), light sources in dark rooms, holy or taint hazards (Cathedral, Swamp), a heavy form to hold a switch. Each is a gate label plus a movement rule, and `tools/areas/` can place them. This is where the evolution trees and the world finally meet.

**Soul layer.** Built: altars, attuning, banking essence for soul points, the goddess's menu, species unlock by count, one perk (base stats, sold at the Cave altar). Not built: the other three perks (extra part slot, slower remains decay, bigger death seed), the essence seed from the thing that killed you, soul-point prices tuned, the goddess reveal and the last area. Eight areas have no altar, so none of this reaches them.

**Bosses.** One: the Taratect in D6, with arena doors, tremor and a glimpse. It fights with the dropper's ordinary behaviour, no health bar, music or phases, and its web and claw decor is not drawn. The framework (`boss`, `tremor`, `glimpse`, antechamber lint) is reusable: the Sovereigns and stage-4 twins are ready-made boss bodies, and a boss arena is a room plus a data entry.

**Creatures and combat.** 187 creatures. Their stats come from a formula in `tools/build_creatures.py`, not from play. Verbs are approximate (each is a data spec, cast for real in a test, never tuned by feel). First-time XP from placed creatures is far above a stage cost for a player who eats them (I left it). Nothing in the ledgers records tuning them by play.

**Writing.** 9 tablets (5 hand-written, 4 generated stubs). Goddess death lines exist for the 18 shipped creatures, plus poison and spears; a death to any of the other 169 gets her generic line. The opening's 15 result lines and her first words are placeholders for you to rewrite. The 169 new creatures have names and stats and no lore.

**Tools for making content.** Room editor (`tools/edit_rooms.sh`) and its MCP; area builder; creature, form, verb and gate builders; shot tools; the new `tools/creature_sheet.sh`. **A trap:** the area builder regenerates the generated rooms from code and strips what it wrote, so a hand edit to FO, SW, VI, CM, CA, CR, VO or DM rooms is lost on the next build, and so is a spawn the placement module put in any room. To polish a room by hand it must first be adopted (removed from the builder). I would add `tools/build_areas.sh --adopt <prefix>` so the editor owns it from then on.

**Quality.** Suite 3590 passing. Three tests are known to flake under full-suite load (`test_web_tether`, `test_water_stream`, one vfx timing test). The README's status line still says the wolf, goblin and spider are "not yet wired into the real player" while `Game` starts as any of them; the design-review page is a dated snapshot.

## Art that you can maintain

### What exists

- Sprites go through one seam: a PNG per frame at `art_source/frames/<set>/<name>.png` (transparent or magenta background), a spec `tools/art/<set>_frames.json` (frame names and target widths), and `tools/art/assemble_frames.py`, which crops, scales to the width, thresholds the alpha and traces hurt and attack shapes. **It does not care where the PNG came from.** Today they are AI-generated 1254 px images shrunk to 30 to 76 px wide.
- 18 creatures have animated sheets; 140 twins are a single still each (now moved in code); 29 support monsters wear a shipped creature's frames in a tint (26) or a still (3).
- **Risk:** `art_source/frames/forms_*/` (about 160 MB, the sources of the 140 twin stills) is git-ignored. AI generation is not repeatable, so a lost disk loses the sources; only the built sheets are committed. Cheapest fix: back the folder up now (or Git LFS). I did not do it, because it is your disk and a repo policy.

### Hand-drawing assets that already exist

Because the seam is "a PNG per frame", your drawing drops straight in. Two ways to work, both ending in the same folder:

1. **Paint big, let the pipeline shrink it** (Procreate on the iPad). Canvas about 1254 px square, creature facing right, nothing but the creature, background transparent, export PNG. This is exactly what the AI frames are, so it needs no change. The catch: a 76 px sprite is a 16x shrink, so keep outlines fat (about 16 px at that size) or they vanish.
2. **Draw at final size** (Aseprite on the Mac, which you have installed, with your tablet). The sprite is 30 to 76 px wide, so you draw the real pixels. Needs one small change: tell the assembler to take the frame as is (no resize) so your pixels are never blended. This is the more maintainable route for animation: `.aseprite` files keep layers, frame tags and a palette, and `aseprite -b` exports frames from the command line.

What I will build for either route (`tools/art/handdraw.py`): `pack <set>` writes an underlay of each existing frame at the right canvas size with a ground line and a bounding guide, plus a one-page spec; `check <folder>` validates your exports (transparent, facing right, not touching the edge, outline thick enough to survive) and writes a preview at game size beside the current art; `import <set> <folder>` backs up what it replaces, drops your frames in, runs the assembler and records the asset as hand-drawn. Status: **built** (`tools/art/handdraw.py`, how-to in `docs/hand-drawing.md`; 46 Python tests, and run end to end on a copy of the `bat` set). The assembler gained a `native` flag so pixels drawn at final size are never resized. One thing it taught me already: the pipeline's magenta key also erases any pink close to magenta inside a drawing (the bat's glowing eyes at final size), so `check` warns about it.

### Would Blender help? (and a spike I ran)

Short answer: **yes for the many-variant lines, no as a wholesale switch.** Your point about the earlier rig is right: `archive/rig-spike` rigged only the slime, by its own plan ("Only the slime is rigged. Enemies, forms ... out of scope"). We now have four movement profiles (slime, biped, spider, wolf), seven enemy behaviours and about 100 forms that share bodies, so a shared skeleton and animation set per archetype pays far better than it did for one slime.

The maintainability levers are the same in 3D (Blender) and in 2D (a skeleton in Godot driven by parts you draw in Procreate):

- one rig and one animation set per archetype, reused by every form of that line (wolf 21 forms, undead 30, goblin 28, spider 20, slime 18);
- variants by recolor and part swap, not a new drawing per frame;
- the sources are files in git, a change is one command, and nothing depends on a generator you cannot rerun.

**The spike** (`docs/research/images/blender-spike-wolf.png`, top row): a primitive wolf with an 8-frame walk, rendered by headless Blender 5.2 (the Blender in `/Applications`) to transparent PNGs, an outline added in code, then shrunk by the game's own `fit_frame` to 64 px wide, next to shipped sprites.

- It works as a pipeline: headless render, no window, same assembler, frames identical in proportion, the walk is a loop of eight numbers that re-renders in seconds.
- It does not match the look. A shape built from primitives reads as a toy at 64 px: no fur, no glow, no face. At that size what survives is the silhouette plus about three tones, so 3D buys consistency and animation, not detail. Reaching the painterly look of Fenrir or Skoll means real modelling and hand-painted textures per creature.
- Not conclusive: my script's colours did not render (the model came out grey), so this says nothing about colour or lighting. Real use would add a shader and a palette step.

My recommendation, because you said a small style change is fine: **do not rebuild everything in 3D. Pilot one line.** The wolf line (21 forms, one body plan, I already have the quadruped walk) in two ways, Blender and a 2D skeleton from your Procreate parts, then compare cost per new form. In either case:

- keep the assembler contract as the seam, so the choice can differ per asset;
- lock a shared palette and outline weight (the single biggest consistency win for hand work too);
- add an origin record for every set (ai, hand, blender) so you always know what to redraw;
- hand-draw the player forms and bosses (most looked at), rig the lines that have many variants, leave AI stills for background fauna.

## Deferred items, triaged

**Reopen now (they block or mislead):**
- Altars for the eight new areas, and the three missing perks (part slot, remains decay, death seed); the soul layer is incomplete without them.
- The Taratect: no health bar, music, phases; one altar in the Deep.
- Hand-ownership of generated rooms (`--adopt`).
- Stale docs that mislead: README status line, `docs/design-review/index.html`, species doc line 390 (Copy "waits for F1").
- Neutral village creatures are hostile.
- The Deep's crowding (D2 to D4).
- Placeholder text: opening result lines, goddess first words.

**Needs your taste or a decision:** pacing of twins in the starting Cave; first-time XP vs stage costs; how hard the new creatures hit (never played); the goddess's menu is dark navy after the white fade.

**Safe to leave:** about 60 test-wording, comment and polish nits across the ledgers (`docs/ledgers/*`, search `minor (deferred)`); the 31 rulings are in `docs/research/decisions-f2-to-alive-stills.md`.

**Not built, by design deferral:** mud, heat, taint and holy hazard rules; spawn gates; traps; the `heat_resist` gate; species verb lanes; boss arenas for the new areas; the goddess reveal; the last area; the Cave Serpent area.

## What I can do next without you

1. A screenshot tour of all 71 rooms and a numbered playtest route (so your first play is directed).
2. `--adopt`, then altars for the eight areas.
3. The hand-draw kit above.
4. Drafts in the goddess's voice: death lines for the 169 uncovered creatures, a tablet for each generated room, for you to rewrite.
5. One new gate kind end to end (heat resistance in the volcano) as the pattern for the rest.
