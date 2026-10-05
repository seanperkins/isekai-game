# Species evolutions: the roadmap, in pieces

Status: proposal (2026-10-05). Source design: `docs/research/species-form-branches.md` (every form, its world twin, the essences, the monsters to add) and the review page `docs/evolutions/` (live at `/evolutions/`). This file splits building it into pieces. Each piece gets its own short spec or plan, test-first, in its own worktree and branch, reviewed and merged on its own, and ends with something the player can see or play. Built so far: A1 (species-aware forms), A2 (fire, mind and blood), A3 (the other four species' 99 forms as data), B1 and B2 (the slime's diet gates, one parent per Sovereign, 18 new stage-4 forms, the tree layout), C1 (the verb framework: a skill whose active effect carries a data `spec`, 21 kinds of effect, `tools/form_verbs.json` as the one table of verbs) and B3 (the slime's 17 form-four verbs, each cast for real in a test; Quicksilver Slime has none). C2 added a verb for every other form (116 in all), D put the four species' bodies in the Player, G1 gave every form a still, and the review aids added `--form=` and the verb and sacrifice lines on the cards. F1-lite is built too: all 168 creatures as data (`tools/build_creatures.py`), enemies that cast their form's verb, art on every creature, and the Menagerie, one room with all of them (`godot --path . -- --room=menagerie`). H1 made every wolf, undead, spider and goblin form's "Opened by" rule a gate (`FormDef.gate`, `tools/form_gates.json`): essence plus the deeds a run can earn (`defeated` with how, guards broken, rooms cleared, strikes that hit or miss, a far switch, rooms entered, an avenged death), offered only when met and shown on the cards with progress. F2a built the room builder (`tools/build_areas.sh`, `docs/research/areas-f2.md`) and the forest, nine rooms above the cave (the first new area; twins are placed in F2f). F2b built the swamp (five rooms) and the goblin village (four rooms and the Sump) east of the forest. F2c built the sacred cluster: a cemetery, a cathedral and a crypt (fourteen rooms) above and east of the Deep. F2d built the volcano under the Deep and the demon area past the crypt (fourteen rooms), which finishes the areas: eight areas, 47 new rooms. E2d built the spider's cocoons (a spider webs a stunned creature into a carried cocoon, eats it later or lets it go), which finishes E2. E2c built the goblin's hands (pickpocket on the inspect button; the Tinker's Rig trap; the Smith's Forge from two carried parts; ward-stones as a verb deed). E2b built bonds and companions (a wolf bonds and a goblin tames a stunned creature with the inspect button; the companion follows, fights and is lost if it dies). E2a built the goblin's lessons (`docs/research/items-e2.md`: a goblin's essence comes from the first dealing with each creature type, a trickle after, and `lesson_learned` is said), and a heap of junk to learn from. E1 built the parts: ten parts as data, drops on every creature that leaves one, pickups, an inventory the undead wear grafts from (four at most, a passive each, knocked off by a hit of a quarter of max HP) and everyone else carries, and remains where a life ended (`docs/ledgers/parts-e1-ledger.md`). Gate atoms that need a system not built yet wait on it (`Deeds.RESERVED`: 9 on the new areas' rooms (F2)); those forms stay locked until their piece lands. Still to build: the nine deeds that wait on rooms (F2e), the twins' places in them (F2f), calibration (F3), and art beyond stills. The 24 slime forms already existed.

## What exists and what is missing

| Part | Today | Missing |
|---|---|---|
| Forms | 24 slime forms: `FormDef` (stats, traits, grants, tint, size), `Form.BASE = "slime"`, six hard-coded lineages, `FormOffers` gated on owning a power | species other than the slime; 117 new forms; reveal and offer thresholds; one parent per Sovereign |
| Verbs | slime skills as ability scenes (`scripts/abilities`, `data/skills`); the species movesets exist only in the movement sandbox | about a hundred form verbs (Rise, Veil, Consecrate and so on) |
| Player | `player.gd` (984 lines) with the slime's own hard-coded movement and one body | wolf, biped and spider bodies on the shared movement model |
| Species | `data/species/slime.tres` only; the soul layer carries `start["species"]` but nothing applies it | species data, unlocks, the goddess's menu, a Player built for the chosen species |
| Essences | five elements | fire, mind and blood; absorbed-per-life counters per element for thresholds |
| Creatures | 19 shipped | 168 new creature types (140 form twins, 28 support monsters), their kits as enemies, their sprites |
| Items | none | corpses, parts and grafts, harvest, remains, lessons, taming, cocoons |
| World | 4 areas, 23 rooms | forest, swamp, village, sacred hall, cemetery, crypt, volcano, demon area, with their rules |
| Art | 4 forms with art; the rest tinted or empty | art for the new forms and creatures (the Codex pipeline) |

## The pieces

Sizes are relative (S, M, L, XL), not time. "Playable" says what you can do when the piece merges.

### A. Foundations

| # | Piece | Scope | Depends on | Done when | Size |
|---|---|---|---|---|---|
| A1 | **Species-aware forms** (built on `feat/species-forms`, plan `2026-10-05-species-forms-a1.md`) | `FormDef.species`; a base form per species instead of `Form.BASE`; per-species lineages and stage caps; `FormLoader`, `FormValidator`, `FormOffers` and the skill tree screen take a species; the persisted form state migrates. No new content. | none | every existing slime test still passes unchanged, and a fixture second species passes the same validator and offers tests | M |
| A2 | **Fire, mind and blood** | the three elements in the vocabulary, the validator, the HUD and the skill rules; per-element "absorbed this life" counters | none | an essence event of each new element is counted, shown and validated; a form may read them (as a stub until a creature carries them) | S |
| A3 | **Form data for all 141** | a generator from the design doc's tables to `data/forms/*.tres`: stats by tier, traits, tint, size, host, "opened by" as data, the verb id each form grants (the verb itself is piece C); the validator learns the new fields | A1, A2 | all 141 forms load and validate; the review page's counts equal the data's | L |

### B. The slime, fully (the first visible win)

| # | Piece | Scope | Depends on | Done when | Size |
|---|---|---|---|---|---|
| B1 | **Slime lineage gate** | reveal and offer thresholds on absorbed essence, powers counting +3, Weaver at dark 24, the Greater fallback; the tree screen shows reveal progress | A1, A2 | the stage-2 menu follows the diet table in the design doc; the Cave-start numbers are pinned in `tests/test_content.gd` | M |
| B2 | **Slime tree rebuild** | each Sovereign to one parent; the 18 new form-4s as data (tinted slime art); evolution tests rewritten test-first; the Tree tab's layout (`SkillTreeModel._form_slots`) for several stage-4 siblings per lineage, which every species now has (siblings share one slot today) | A3, B1 | all 42 slime forms are reachable and evolvable in a run | M |
| B3 | **Slime verbs** | the form-4 verbs: Bind, Recall, Stalk, Shed, Maelstrom, Flood, Dissolve, Contagion, Network, Guardian, Transmute, Engulf, Copy, Hurl, Ride, Pseudopod, Court and the Quicksilver form (needs C1) | C1 | each slime form-4 verb works on an enemy in a test and in the sandbox | L |

### C. The verb system

| # | Piece | Scope | Depends on | Done when | Size |
|---|---|---|---|---|---|
| C1 | **Verb framework** | a data-driven `VerbDef` (kind, cost, cooldown, parameters) and a small set of effect primitives: projectile, cone, ring or aura, dash, summon, mark, ward, trap, buff or stance, pull, reveal, transform. Existing ability scenes keep working. Active-slot, MP and aim wiring. | A1 | a verb defined only in data fires, costs MP, respects its cooldown and affects an enemy, tested | L |
| C2 | **Verbs by species** | the verbs of C1's primitives, one piece per species: wolf, undead, spider, goblin (the slime's are B3) | C1 and the species' body (D) | every form's Verb column works as the same kit on a creature (the twin) and on the player | L each |

### D. Species in the real Player

| # | Piece | Scope | Depends on | Done when | Size |
|---|---|---|---|---|---|
| D1 | **Wolf in the Player** | `VerbRunner` becomes the single owner of movement writes; the Player runs the wolf profile, look and body; pounce and vault hooked to combat; per-species reach in lint | A1 | start a run as the wolf and play it through the Cave | XL |
| D2 | **Biped in the Player** | the goblin and every undead form: roll, slide, mantle, wall jump on the Player | D1 | the same for the goblin and the skeleton | L |
| D3 | **Spider in the Player** | crawl, web zip, silk drop, slick | D1 | the same for the spider | XL |
| D4 | **Species and the goddess** | `SpeciesDef` for wolf, goblin, spider and undead; unlock rules (eat N); the goddess's menu offers them; `start["species"]` builds that Player | D1 (then D2, D3 as they land) | unlock the wolf by eating enough gloom wolves, pick it at the altar, run it | M |

### E. Items

| # | Piece | Scope | Depends on | Done when | Size |
|---|---|---|---|---|---|
| E1 | **Corpses, parts and remains** (built) | a kill leaves a corpse that gives a part; the part table (ribs, claws, weapon arm, bow arm, skull or focus, wrappings, phylactery shard, Moonstone); remains pile and decay | A1 | kill, harvest, carry, die and recover a part | L |
| E2 | **Grafts, lessons, taming, cocoons** (built) | undead grafts that steer a form; goblin lessons per creature type; taming and one companion; spider cocoons; the goblin's radial wheel and combine | E1, D2 | each "opened by" condition in the design doc that names a part, a lesson, a bond or a cocoon can be met | XL |

### F. The world

| # | Piece | Scope | Depends on | Done when | Size |
|---|---|---|---|---|---|
| F1 | **Creature data and kits** | the base creatures first, then the 140 form twins and 28 support monsters as `CreatureDef` data, each enemy running its form's verb; placeholder sprites by tint until art exists; the bestiary lists them | A3, C1 | every creature spawns, fights and is edible, validated and tested | XL. F1-lite is built: the data, the verbs, the art and the Menagerie. Per-area spawns wait for F2 |
| F2 | **New areas** | forest, swamp, village, sacred hall, cemetery, crypt, volcano, demon area: rooms with the room MCP, their rules (mud, holy emitter, sealed gates, standing), altars, art borrowed from a built biome | F1 | each area is walkable end to end and its creatures spawn | XL each |
| F3 | **Calibration** | recalibrate the slime thresholds on the real roster and rooms; calibrate the other species' gates; pin the numbers in tests | F1, F2 | the diet table in the design doc is true of the shipped world | M |

### H. Gates

| # | Piece | Scope | Depends on | Done when | Size |
|---|---|---|---|---|---|
| H1 | **Form gates** (built) | every non-slime form's gate as data: essence from its reads, plus deed atoms from its "Opened by" text; the deeds the game already earns; offers and cards read them | A3, C2, F1 | a wolf is offered the Black Dog when its run has the essence and the kills from behind; the Form tab lists what the others still need | L |

Each later piece burns down its share of `Deeds.RESERVED`: E1 (built) emits the graft, part, corpse and carried-item deeds; E2a to E2d (built) the lesson, bond, trap, forging, theft, ward-stone, cocoon and freed-prey deeds; E2 the forging, theft, ward-stone, cocoon and freed-prey deeds; F2 puts dissolvable and hidden things in rooms and supplies gaps, lamps, a village, a Vigil, held rooms and moonlight. The last of them leaves the list empty, and every form is then reachable.

### G. Art (a parallel track)

| # | Piece | Scope | Done when |
|---|---|---|---|
| G1 | **Art for the new forms and creatures** | the Codex pipeline (`tools/art`) per line: the form-2 body, then form-3 and form-4 parts; creature sheets | each line has sheets and clips; the review page's art table shows it |

## Order

1. **A1, A2** (in parallel: they touch different code), then **A3**.
2. **B1, B2**: the slime is playable with its whole tree, no new verbs yet.
3. **C1**, then **B3**: the slime's verbs, the first proof of the framework.
4. **D1** then **D4**: the wolf is selectable and playable. Then **C2 (wolf)**, so its forms do something.
5. **F1 (wolf creatures)** and the first slice of **F2 (forest)**: the wolf has a world.
6. **D2** with **C2 (goblin and undead)**, **E1**, **E2**: the biped species, with the items they need.
7. **D3** with **C2 (spider)**.
8. The rest of **F1** and **F2**, then **F3**. **G1** runs alongside everything.

Each step leaves `main` green and the game playable; a form whose verb or part does not exist yet shows as locked in the tree, not broken.

## What "all of them work" means

A form works when it can be reached by its design-doc rule, shows in the tree, changes the body (stats, trait, art), grants a verb that does what its Verb column says, and exists in the world as its twin. The review page's counts become a checklist: forms reachable, verbs working, twins spawning, art present. Until each piece lands, those counts stay honest on the page.

## Risks

- **`player.gd` is slime-shaped** (984 lines, its own hard-coded movement and one body). D1 is the largest risk: the movement model has to become the Player's single owner without breaking 2,490 tests.
- **A hundred verbs** is a content volume. C1's primitives are what keeps it tractable; a verb that no primitive fits is listed and built by hand.
- **Items are a new system** with no code today, and several forms cannot be opened without it (E).
- **World volume**: 168 creature types and eight areas are a lot of authoring even with placeholder art. F1 and F2 are staged so every area ships playable on its own.
- **Calibration drifts** whenever creatures or rooms are added, which is why F3 comes after them and the numbers are pinned.
