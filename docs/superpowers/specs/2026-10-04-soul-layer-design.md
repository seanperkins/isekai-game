# Soul Layer: Species, Soul Points, Perks and the Goddess's Death Scene — Design

Status: written for Sean's review (2026-10-04). Built from the design doc (`docs/isekai-chronicles-design-doc.md`, "Reincarnation and soul progression") and from the open-questions session of 2026-10-04, where every choice below was made. It replaces the rebirth pools and their kits.

## What I understood

You die, and a goddess sends you back. Today that is a death card, then (with two or more attuned pools) a menu of *places*. The design doc wants more: what you can come back as (species), how far along you start (soul points, spent), where you start (altars), and a goddess who greets you, remembers how you died, and offers all of it in one scene. Soul points come only from banking essence at an altar, which is also the story's hidden cost: every point feeds her.

Success:

- Dying opens one screen where you pick **where** (an attuned altar), **who** (an unlocked species) and **how far along** (levels and powers bought with soul points), and the next life starts exactly so.
- A species unlocks by the rule in its data (eat or defeat N, or defeat a rare creature or boss).
- Banking converts held essence into soul points at a flat rate, and the cost of evolving a power and of banking come out of the same held pool.
- The goddess speaks a line that depends on what killed you.
- The existing menus are a work in progress and are replaced where that fits the game; nothing here is bound to `RebirthChoice` or `ReincarnationMenu`.

## What exists today

- Death: `Run._resolve` asks `RebirthChoice.decide` for a list of *places* (pools), `ReincarnationMenu` shows it (keys only, no stick), `Run._begin` writes `WorldProgress.pending_start {pool, species}` and reloads the scene. `Game.resolve_start` turns that into a room, a spot and the pool's kit, and `Game.begin_life` applies the kit with `RebirthKit.apply` (granted skills plus a starting level).
- `species` is the string `"slime"` carried through `last_choice` and the save. There is no species definition.
- The Bestiary (`CompendiumModel.creature_record`) counts `eaten` and `defeated` per creature and persists them through the Profile.
- `Player.receive_hit` takes a cause and ignores it; `died` carries nothing. Enemy contact, the stomp and the spear are the only things that damage the player, plus poison ticks.
- `Compendium` (autoload) owns `profile`, `model` and `progress` (`WorldProgress`). `Profile` saves named sections (`set_section`, `list_section`, `dict_section`, `save`).
- `Stats.add_level_bonus` and `Player.start_at_level`, `refresh_stats`, `fill_vitals` already exist and are what `RebirthKit.apply` uses.

## Decisions

| Topic | Decision |
|---|---|
| Altars | One per area (Cave, Grotto, Flooded, Deep), keeping the pool ids C1, G1, F1 and D1 so saves stay valid. The same menu everywhere plus one fixed local perk each. Built in plan 3 |
| Where you choose | At death, in the goddess's scene. The in-world altar attunes, banks essence and sells its local perk |
| Scene layout | One screen, three panels (Where, Who, Head start), her line on top, soul points and the confirm key below |
| Locked things | Hidden. Where lists only attuned altars; Who lists only unlocked species |
| Species unlock | Data per species: `default`, `count` (eat or defeat N, read from the Bestiary) or `defeat` (one defeat of a rare creature or boss). "Eat it while in a given form" waits for the spider, which is when the form can be tracked at the eat. N is set per species; "scaled by rarity" is a tuning guideline, not a field |
| Earning points | Only by banking essence at an altar, at a flat rate whatever the element |
| Banking | Per element, with an adjustable amount (one soul point's worth per step). It spends held essence through the ledger's spend entries, so `held` and evolution affordability update with no new engine concept |
| Head start | Starting levels (a rising price per level, capped) and any power the Compendium shows as Owned-once, priced per power. Paid on confirm, not on selection |
| Perks | Data per perk, bought several times at a rising price. Only "stronger base stats" (Cave) ships now; part slot, remains decay and death seed are added with their own systems |
| Death cause | `Player` records the last hit's cause; `Run` reads it at death. A line per cause |
| No choice to make | When there is one place, one species and nothing affordable to buy, her line replaces the old death card and the menu is skipped |
| Persistence | A new `SoulProgress` object saved as its own Profile section, `soul` |

## Components

### Species

`SpeciesDef` (a `Resource` in `data/species/`): `id`, `display_name`, `movement_profile` (an id under `data/movement/`, "" for none yet), `unlock` (a Dictionary: `{"kind": "default"}`, `{"kind": "count", "creature": id, "n": int}` or `{"kind": "defeat", "creature": id}`). `SpeciesCatalog.load_all()` returns them by id; `SoulValidator` rejects an unknown kind, an unknown creature id, a missing `n`, a duplicate id and a catalog with no `default` species; it also checks perks (unique ids, positive prices, known stat names) and the goddess's lines (below).

`SpeciesUnlocks.is_unlocked(def, records) -> bool` is pure: `records` is the Bestiary's `{creature_id: {eaten, defeated, ...}}`. `count` is `eaten + defeated >= n`; `defeat` is `defeated >= 1`. Only `slime` ships (kind `default`); tests use fixture species.

### Soul progress, banking, perks

`SoulProgress` (`RefCounted`, built with the Profile like `WorldProgress`): `points: int`, `perks: Dictionary` (perk id to times bought), `deaths: int`, plus `session_points: int` (not saved; the `--soul=N` dev flag adds to it and it is spent first). Saved as the Profile section `soul` = `{"points", "perks", "deaths"}`; a malformed or negative value loads as zero and unknown perk ids are dropped. Methods: `total_points()`, `add(n)`, `spend(n) -> bool` (false and nothing spent when short), `buy_perk(def) -> bool`, `perk_count(id)`, `note_death()`.

`SoulRules` (a `Resource`, `data/soul/soul_rules.tres`), starting values tuned by play: `bank_rate` 10 (essence per soul point), `level_prices` `[2, 3, 4, 5]` (the 1st to 4th bought level; a start at level 5 is the cap, as the old kits reached), `power_price` 3, `many_deaths` 5.

`Banking` (static, pure over the engine): `max_units(rules, element) -> int` is `held(element)` rounded down to a multiple of `bank_rate`; `bank(rules, soul, element, units) -> int` calls the engine and adds `units / bank_rate` points. It refuses an amount that is not a multiple of the rate or that exceeds what is held. The engine gains one public method for this, `SkillRulesEngine.spend_essence(element, units) -> bool` (it writes `units` `essence_spent` entries tagged `{"essence": element}` and returns false, writing nothing, when `held(element)` is short); `evolve()` uses it too.

`PerkDef` (`data/perks/`): `id`, `display_name`, `description`, `altar` (the altar id that sells it), `price_base`, `price_step`, `effects` (an Array of `{"stat", "amount"}`). The price of the n-th purchase is `price_base + price_step * n`. `stats.tres` ships: Cave (C1), +2 max HP and +1 max MP per purchase, base 5, step 3. `SoulPerks.apply(player, soul, perks)` runs at life start after the kit: for each perk it adds `amount * times_bought` through `Stats.add_level_bonus`, then `refresh_stats` and `fill_vitals`.

### The head start

`HeadStart` (static, pure): `eligible_powers(rules, compendium) -> Array` is every base power the Compendium shows as Owned-once whose source is not `evolution`, `enemy_only` or the starting skill; `price(rules_data, cart) -> int` is the sum of the level prices for the levels bought plus `power_price` per power; `kit(cart) -> Dictionary` is `{"skills": [...], "level": 1 + levels}`, which `RebirthKit.apply` already applies. The cart is `{"levels": int, "powers": Array}`.

### The goddess's scene

`GoddessModel` (`RefCounted`, pure) is the whole scene's state: the three panels' rows, the highlighted row per panel, the cart, the cost, `can_afford`, and `confirm() -> Dictionary` returning `{"altar", "species", "kit", "cost"}` (or `{}` when the cart is unaffordable). Its inputs are the attuned altars, the unlocked species, `SoulProgress`, the Compendium and the last choice, which it pre-selects. `need_menu() -> bool` is false when there is nothing to choose: one attuned altar, one unlocked species, and `total_points()` below the cheapest thing the Head start panel sells (the first level, or the cheapest eligible power).

`GoddessMenu` (a `CanvasLayer`, layer 40) draws the approved layout and drives the model. Controls (keys, D-pad and left stick all work; the stick uses a shared `NavStep`, a small `RefCounted` holding the repeat state extracted from `SkillScreen.nav_step`, which stays as a one-line wrapper so its tests hold): Up and Down move the row; the shoulder buttons (Q and E on the keyboard) switch panel; Left and Right add or remove a level or a power in the Head start panel; Enter or A is "be reborn" from any panel. The mouse is not in the first version.

`Run._resolve` builds the model and shows her line: the death card (1.5 s) shows it instead of the fixed "You dissolve" text, and the menu, when needed, opens over the card with the same line on top. On confirm it spends the cost, writes `pending_start {altar, species, kit}`, remembers the choice and reloads the scene. `ReincarnationMenu`, `RebirthChoice.decide` and `accept`, `Run.choice_needed` and `Run.choose` are removed. `Game.resolve_start` returns the altar's room and spot (the default is the start room) and the chosen kit; `begin_life` applies kit then perks. An editor Play has no goddess: death returns to the editor as today.

### Death cause and her lines

`Player.last_hit_cause: String` is set in `receive_hit` from the existing `_cause` argument (renamed `cause`), falling back to the damage type. Enemy contact and the stomp pass `def.id`; the spear passes `"spear"`; poison ticks pass `"poison"`. `Run` reads it when the player dies.

`GoddessLines` (a `Resource`, `data/goddess/lines.tres`): `by_cause` (cause to an Array of lines), `first_death`, `many_deaths` and `fallback`. `line_for(cause, deaths) -> String` takes the first rule that applies: (1) `deaths == 1` gives a `first_death` line; (2) the cause has lines in `by_cause`, giving the one at index `deaths` modulo the list (so tests are deterministic); (3) `deaths >= many_deaths` gives a `many_deaths` line; (4) a `fallback` line. `Run` calls `soul.note_death()` first, then `line_for(cause, soul.deaths)`. Cause lines ship for the 18 creature ids that can hurt the player (every creature but the water pool) plus `poison` and `spear`, as copy for Sean to edit; `SoulValidator` rejects a `by_cause` key that is none of those.

### Altars (plan 3)

An `altar` room feature replaces `rebirth_pool`: `{id, area, perk}`, standing in the same four rooms with the same ids, attuned with Inspect as pools are now. `WorldProgress.rebirths` keeps its saved key (the list of attuned altar ids), so nothing migrates. The in-world `AltarMenu` has three rows: attune (once), bank (the per-element adjustable amount), and the local perk with its next price. `WorldValidator` checks altar ids are unique, each names a known perk and each area has at most one. The room editor's pool tool and inspector fields (`kit_level`, `kit_skills`) become an altar tool with a perk dropdown. The pool kits and `RebirthKit.validate` data checks go; `RebirthKit.apply` stays as the kit applier (renamed `HeadStart.apply` in that plan).

### The opening (plan 4, outline only)

A first-run flag in `SoulProgress` (`opening_seen`). The truck is a short, rigged, turn-based dodge (three trucks, plays once); then the goddess's menu with only slime, the Cave altar and nothing to buy, so her first meeting is the same scene as every death. Its beats get their own brainstorm.

## Data and persistence

New data: `data/species/slime.tres`, `data/perks/stats.tres`, `data/soul/soul_rules.tres`, `data/goddess/lines.tres`, written by a one-shot generator `tools/build_soul.gd` in the style of `tools/build_forms.gd` and then edited freely. `DefLoader` loads them; `SoulValidator` checks them (and runs in a test over the shipped data, like the skill validator). `Compendium` gains `soul: SoulProgress` beside `progress`. The Profile section `soul` is the only new persisted data; `pending_start` stays in memory.

## Sequencing

Each plan leaves the suite green and can ship alone.

1. **The pure core.** `SpeciesDef`, `SpeciesCatalog`, `SpeciesUnlocks`, `SoulRules`, `SoulProgress` (and its persistence), `Banking`, `PerkDef`, `SoulPerks`, `HeadStart`, `GoddessLines`, `GoddessModel`, `SoulValidator`, the generator and the shipped data. New files, `autoload/compendium.gd` (the `soul` member) and `SkillRulesEngine.spend_essence` in `scripts/skills/skill_rules_engine.gd`.
2. **The scene and the death flow.** `GoddessMenu`, `NavStep` (extracted from `SkillScreen`), the `Run` and `Game` changes, the `Player` cause (two lines in `player.gd`) and the enemy and spear call sites, the `--soul=N` flag, and the pool kits removed from the four room files. Places are still the pools until plan 3, and until then a perk can only be bought in tests.
3. **Altars.** The feature, `AltarMenu`, banking and the local perk in the world, the validator and editor changes, and the removal of `rebirth_pool`. It waits until the movement agent's reach-model plan has landed, because both touch `world_validator.gd`.
4. **The opening.** Outline above.

### Constraints on the work (another agent owns movement)

Never edited: `scripts/movement/`, `data/movement/`, the movement tests. Edited only as stated: `scripts/player/player.gd` (the cause, plan 2), `scripts/enemies/enemy.gd` and `spear.gd` (one argument each, plan 2), `world_validator.gd` and `room_lint.gd` (plan 3, after that agent's plan 2). Plans run in a worktree off `main`, merge when that agent is idle, and tell it before touching `player.gd`.

## Testing

Pure tests for every model: unlock rules for each kind and the Bestiary edge (`n` reached exactly, one short); banking math and its refusals; the perk price curve and its stat application; the head start's eligible powers, prices and kit; `SoulProgress` round trip, malformed section, negative values and `session_points`; `GoddessModel` navigation, the cart, `confirm` and the no-choice skip; `GoddessLines` selection for each branch; `SoulValidator` on good and bad data and on the shipped files. Wiring: a start-from-real-input test that dies, opens the menu, buys a level and a power, confirms, and checks the new life; a test that the cause reaches `Run`; the scene and room tests that name pools are updated in plan 2 and 3.

## Not here

Mouse in the goddess's menu; the other three perks and their systems; any species but slime; the `eat as a form` unlock kind; the death seed; the opening's beats; goddess art beyond a placeholder portrait (art need: her portrait, and a few expression frames); the soul-point price tuning beyond the starting values above.

## Open (tuned as data)

The bank rate, the level and power prices, the perk's numbers and the copy of the 20 cause lines and the three general lines are starting values. Whether a soul can start past stage 1 of the evolution tree stays open in the design doc.
