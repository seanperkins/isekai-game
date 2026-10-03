# Essence Overhaul — Design

Status: draft for Sean's review (2026-10-03). Built from the design doc (`docs/isekai-chronicles-design-doc.md`, committed
`15a09e2`) and its review page (`docs/design-review/index.html`), which hold every decision below as Sean made it. This is the
first of the three things the doc puts before the spider (the essence overhaul, the skill tree screen, and slime movement).
The tree screen is a separate spec (`2026-10-03-skill-tree-screen-design.md`) and builds on this one.

## What I understood

The game has ten **trait essences** tied to particular creatures (sound, flight, poison, water, armor, earth, thread, spore, shell,
shock). The design replaces them with **elements**: a power is unlocked by an element or a mix of elements, and **evolving a power
spends essence** instead of an Evolution Point (EP). The stage-1 body forms stop reading an affinity ratio and are offered by the
powers you own.

Success: a life plays as it does today (same rooms, same creatures, each power unlocking within one eat of where it does now on a full clear, or the move recorded as deliberate), but

- every creature carries elements, and no skill, form, kit or test names a trait essence;
- Poison Breath and Spore Cloud unlock from a **mix** (poison is water and dark; spore is air and dark), Jolt from light and air;
- a ready evolution costs an authored price in the elements its power runs on, paid from essence you **hold**, and EP is gone;
- the first evolution offers the lineages whose powers you own, not an affinity ratio;
- the full suite passes, and a data test pins the new vocabulary the way `tests/test_constants.gd` pins the old one.

## Decisions

| Topic | Decision |
|---|---|
| Elements | `Essences.ALL` becomes the five **first-pass** elements: `water`, `earth`, `air`, `light`, `dark`. Fire, mind and blood join the list with the first creature that carries them (the doc's "later, with new creatures"). Poison and Physical are not elements: poison is water and dark, and earth covers what Physical would have |
| Mapping | Each trait unit becomes one unit of each element it maps to. `sound`, `flight` → air. `poison` → water + dark. `spore` → air + dark. `armor`, `shell` → earth. `shock` → light + air. `thread` has no element and is dropped. `water` and `earth` are unchanged. A creature's duplicate elements add (a bat's sound 1 and flight 1 become air 2). The derived creature table is below; any creature may be re-themed later (the Gloom Wolf is a candidate for dark), not here |
| Thread | Thread powers unlock by **eating a spider**, not by an essence. `CreatureDef` gains `family` (`"spider"` for the Black Spider and the Taratect, empty elsewhere), `PREDATED` events carry it as a tag, and Sticky Thread unlocks on `predated` with `{"family": "spider"}`. The engine already matches a counter on any tag subset, so this is data plus one event tag |
| Eaten and held | **Eaten** is what the ledger already counts (`ABSORBED` per element). Recipes read it, so spending never undoes an unlock. **Held** is `eaten − spent`, where `spent` is new per-life state on `SkillRulesEngine` (cleared by `reset_run()`). Both reset with the life. Banking and the death seed are later milestones and will read `held`; nothing here uses them |
| Mix unlocks | A recipe is several `counter` conditions on `absorbed`, and `unlock` already means all of them (AND). So poison is `water ≥ n` and `dark ≥ n`, with no engine change. **Alternative recipes** (lightning from fire and air *or* light and air) need an OR the engine lacks; they are not needed until fire exists, so the OR group is deferred to the spec that adds fire. Spore is air and dark here; whether earth joins it is the doc's open question and is left out |
| Thresholds | Merging elements changes how fast each element accrues, and the mapping adds **new sources** for some skills: the Black Spider, Vine Snake and Taratect now carry water (Hydraulic Propulsion), both moths carry air (Echolocation), and the armor and shell creatures now feed Tremor. So keeping the cheapest source's eat count is not enough. The criterion is the **point where each power unlocks on a full clear** of the first-evolution areas (the Flooded and the Deep for their own powers), walking the rooms and spawns in order, the way `FormOffers.supply` already does. The plan's one-off calibration script (a) prints that unlock point per skill before and after, and (b) lists every creature that feeds a skill now but did not before. Thresholds are chosen to hold each unlock point within one eat of today's, and any deliberate move is written down. This spec does not pin the numbers. The three earth skills (Body Armor, Hardened Shell, Tremor) become one element at three thresholds, in that order |
| Price | `SkillDef` gains `evolution_price: Dictionary` (element → units). It is required and non-empty on an evolution and empty everywhere else; `DefValidator` enforces it, rejects unknown elements, and requires **siblings to share one price** (as they already share one unlock), so the player always chooses among branches that cost the same. `evolution_cost()` (EP) is replaced by `evolution_price()`. The engine treats an empty price as free, so tests that build their own defs and call `evolve()` (`test_evolution_branches`) keep working; the validator is what requires a price on the shipped evolutions |
| Who pays | `SkillRulesEngine.evolve(id)` now checks the price, spends it into `spent` and grants, in one call. Today its comment says "the caller has already paid its EP"; that split goes. A new `can_afford(id)` and `held(element)` serve the UI. `evolution_ready` still fires when the conditions are met; affordability is separate, so the row can say "Ready — needs 2 more dark" |
| EP | **Removed.** `Progression.ep`, `spend_ep`, the HUD's "EP n", the "— N EP in Skills" announcer text, and the "no EP" rule and comment in the rebirth kit go. Levels still raise stats and gate the body evolution at the cap. Nothing else used EP. This is a cleanup of built code, not free; it touches the evolution, progression, HUD and kit tests listed below |
| Evolving | Evolving stays in the **Skills tab with today's two presses** (arm, then confirm), now priced in essence. The HUD gains a **persistent ready indicator** (it lights while any evolution is ready and affordable and names the first one), in addition to the pop-up that disappears after 2.5 s. The frictionless in-world chooser the doc wants is **not here**: it needs a borrowed-button design for a controller whose buttons are all taken in play (see "Open for Sean" 4) |
| Forms | `FormDef.essences` becomes `FormDef.powers`. A lineage is **open** when the player has reached any of its powers (`level_of(id) > 0`, which already counts a retired parent). Stage 1 → 2 offers the open lineages, ranked by the total levels reached across the lineage's powers (ties by `LINEAGE_ORDER`), at most three, and the Greater Slime fallback is appended when fewer than two are open (as now). `FormOffers.supply`, `affinity`, `absorbed_units`, `ELIGIBLE`, `FIRST_EVOLUTION_AREAS` and `Progression.seeded` are removed. Stage 2 → 3 and 3 → 4 are unchanged |
| Lineage powers | weaver: `sticky_thread` · tide: `hydraulic_propulsion` · toxic: `poison_breath`, `spore_cloud` · bulwark: `body_armor`, `hardened_shell`, `tremor` · echo: `echolocation`. Evolved powers count through their retired parent |
| Rebirth kits | The three pools seeded `affinity` so that at least two lineages were eligible; with no affinity the kits grant the lineage-opening powers the seeds stood in for. G1 adds `echolocation` and `sticky_thread` (Echo, Weaver). F1 adds `sticky_thread` and `hydraulic_propulsion` (Weaver, Tide). D1 adds the same two beside its `tremor` (Weaver, Tide, Bulwark). `RebirthKit` loses `ESSENCES` and the `affinity` key; its rule becomes "a non-default pool's granted skills open at least two lineages", and `eligible_lineages` is rewritten to count that. The room editor's kit fields drop `affinity` |
| Display | The status text and the Skills tab's stats column show **held** per element (hiding zeros, as now). Locked powers still show Appraisal bands from the ledger, so the player never reads a raw eaten count. The unlock line for a mix reads "Absorb water and dark essence". Creature cards list their elements; a creature hints a locked power when it carries **any** of that power's elements (`compendium_model.gd` currently asks for an exact match on one) |

## The derived creature table

Applying the mapping mechanically (thread dropped). These are the starting numbers for `tools/build_content.gd`, the source of truth.

| Creature | Today | Becomes |
|---|---|---|
| Cave Bat | sound 1, flight 1 | air 2 |
| Poison Toad | poison 1, water 1 | water 2, dark 1 |
| Armored Lizard | armor 1, earth 1 | earth 2 |
| Black Spider | thread 1, poison 1 | water 1, dark 1 (family spider) |
| Spore Moth | spore 1, flight 1 | air 2, dark 1 |
| Mushroom Crab | shell 2, earth 1 | earth 3 |
| Vine Snake | poison 1, thread 1 | water 1, dark 1 |
| Pale Moth | spore 3, flight 2 | air 5, dark 3 |
| Glass Eel | shock 1, water 1 | light 1, air 1, water 1 |
| Cave Crayfish | shell 1, water 1 | earth 1, water 1 |
| Drift Jelly | shock 1, water 2 | light 1, air 1, water 2 |
| Bog Lizardman | earth 1, water 1 | unchanged |
| Storm Eel | shock 3, water 2 | light 3, air 3, water 2 |
| Gloom Wolf | sound 1, earth 1 | air 1, earth 1 |
| Armed Ant | armor 1, earth 1 | earth 2 |
| Stone Drake | earth 3, armor 1 | earth 4 |
| Taratect | thread 3, poison 2 | water 2, dark 2 (family spider) |
| Water Pool | water 2 | unchanged |
| Cave Serpent | none | none |

## The powers

Unlock conditions after the change. `n` values are set by the calibration script; the shape is what the spec fixes.

| Power | Unlock now | Levels on | Evolution price (starting values, tuned by play) |
|---|---|---|---|
| Echolocation | air | air absorbed | — |
| Poison Breath | water **and** dark | skill used | Miasma / Venom Bolt: water + dark |
| Spore Cloud | air **and** dark | skill used | Healing Spores / Puffball: air + dark |
| Jolt | light **and** air | skill used | — |
| Hydraulic Propulsion | water | skill used | Water Blade / Jet Dash: water |
| Body Armor, Hardened Shell, Tremor | earth, at three thresholds | unchanged | — |
| Sticky Thread | eat a spider (`family`) | skill used | Swing Thread / Binding Web: **dark** (see "Open for Sean") |
| Regeneration | unchanged (eat creatures) | unchanged | — |

## Engine and data changes

- `scripts/core/essences.gd`: the five elements; a doc comment that fire, mind and blood arrive with their first creature.
- `scripts/skills/skill_def.gd`: `evolution_price`; `essences_used()` returns every element a mix names.
- `scripts/skills/creature_def.gd`: `family`. `Player._complete_predation` adds it to the `PREDATED` tags.
- `scripts/skills/skill_rules_engine.gd`: `_spent`, `held()`, `can_afford()`, `evolution_price()`, `evolve()` pays; `reset_run()` clears `_spent`.
- `scripts/skills/def_validator.gd`: elements checked against the new list; price rules; sibling-price rule.
- `tools/build_content.gd` (source of truth): creature table above, skill unlocks, `levels_on`, prices, `family`. Re-run it to regenerate `data/skills` and `data/creatures`.
- `scripts/forms/*`, `tools/build_forms.gd`, `data/forms/*.tres`: `powers` replaces `essences`; `FormOffers` rewritten as above.
- `scripts/world/rebirth_kit.gd`, `data/rooms/{G1,F1,D1}.tres`, `scripts/editor/room_edit_model.gd`: kits as above.
- `scripts/actors/progression.gd`: `ep`, `spend_ep`, `seeded` removed; `start_at` loses its EP bookkeeping.
- `scripts/player/player.gd`: `try_evolve` stops spending EP; `form_offers()` passes the rules, not an absorbed table.
- `scripts/core/core_wiring.gd`, `scripts/ui/hud.gd`, `scripts/ui/skill_screen_model.gd`, `scripts/ui/skill_screen.gd`, `scripts/ui/status_text.gd`: price, held, ready indicator, wording, as in "Display".
- `scripts/compendium/compendium_model.gd`: the any-element creature hint.

No save migration: the profile persists the Compendium, Bestiary, map, shortcuts, tablets, attuned pools, last choice and species id, none of which names a trait essence, and essence counters were never persisted.

## Testing

Run `tools/run_tests.sh` (it reads the log and the JUnit file, not just the exit code).

- **New:** the vocabulary pin replaces `Essences.ALL` in `tests/test_constants.gd`; a data test that every creature's elements are in `Essences.ALL` and that its derived numbers match the table above; the mix unlocks (Poison Breath needs both elements, the unlock waits for the second); `held` and `spent` across an evolve, and that a recipe still counts spent essence; `can_afford` false then true; `evolve()` refuses when it cannot pay and spends exactly the price when it can; sibling-price and price-presence validator rules; `family` in the `PREDATED` tags and Sticky Thread unlocking on the third spider; `FormOffers` by owned powers (open lineage, retired parent counts, ranking, fallback, the three-offer cap); each non-default pool opens at least two lineages; the calibration script's before and after table, committed under `docs/` as the record of what changed.
- **Changed:** the EP assertions in `test_progression_stages`, `test_levels`, `test_aim_fixes`, `test_form_effects` and `test_rebirth_kit`; the HUD level text ("… EP 0") in `test_form_tab`; the "Level up to earn EP" line in `test_evolution_screen`; the tests that call `evolve()` on the **real** defs and now need the price paid first, by feeding `ABSORBED` events (`test_evolution_trees`, `test_scripted_run`); the essence-name assertions in `test_grotto_data`, `test_flooded_data`, `test_deep_data`, `test_content`, `test_status_text`, `test_skill_screen`, `test_def_validator`, `test_compendium_model` and `test_form_offers`. Damage-type strings such as `"poison"` and `"physical"` are **not** essences and stay.
- **Verification beyond tests:** play the first areas once with `--evolve` and a fresh life, and confirm by hand that Poison Breath, Spore Cloud, Jolt and Sticky Thread unlock from the intended creatures and that the first evolution offers sensible lineages. Screenshots through the existing `tools/evolution_shots.gd` if the Skills tab layout moves.

## Not here

- The skill tree screen (its own spec) and slime movement feel.
- The **in-world one-press chooser** for evolving. It needs a decision about which button a prompt borrows while it shows (the doc's `Y: attune` precedent works because Inspect already means something at a pool), and the tab flow works meanwhile.
- Stage 2 → 3 pairing by the evolved power. Bulwark and Echo have no branching power to pick a child from, and Toxic has four evolved powers for two children, so the pairings need authoring and a rule first.
- The OR recipe group and fire (lightning's second recipe); mind and blood; spore's possible earth.
- The essence seed on death, banking at shrines and soul points. They will read `held`; none of them is built here.
- Items, corpses and the other species (a later milestone, designed in the doc).

## Open for Sean

1. **What pays for the thread evolutions?** Thread is not an essence now, so Swing Thread and Binding Web need an element. I proposed **dark** (the spiders carry it). The alternatives are **earth** (silk as a hard, structural thing) or making the Weaver's evolutions free.
2. **D1, F1, G1 now grant powers instead of seeds.** The seeds only made lineages eligible; granting `sticky_thread`, `hydraulic_propulsion` and `echolocation` at those pools does the same job but also hands the slime those powers on arrival. The alternative is a kit field that names the lineages it opens without granting anything, which keeps the old head start exactly but adds a field that means nothing outside forms.
3. **EP removal.** Recommended and written as decided above, because nothing else spends it. If you would rather keep EP for something later, say so and this spec stops at "evolution costs essence and EP is unused".
4. **Tab-based evolving now, the in-world prompt later?** The doc records frictionless evolving (a threshold tells you, you press a button) as your working idea. This spec keeps the two-press Skills-tab flow, priced in essence, and adds only a persistent HUD indicator, because the in-world prompt needs a button the controller does not have free in play. Ship tab-based evolving now and design the in-world prompt as its own follow-up (recommended), or hold this milestone for that design?
