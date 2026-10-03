# Skill Tree Screen — Design

Status: draft for Sean's review (2026-10-03). Built from the design doc (`docs/isekai-chronicles-design-doc.md`, committed
`15a09e2`): "one combined, zoomable graph … if evolutions are hard to show alongside powers, fall back to one evolution at a
time, plus where the next evolution is once unlocked". It is built **after** the essence overhaul
(`2026-10-03-essence-overhaul-design.md`), whose `FormDef.powers`, `evolution_price` and `held` it reads.

## What I understood

Today the Skills tab is a grouped list (Proficiency, Essence, Evolution) and the Compendium tab is a second list of
discovery states. Neither shows how powers connect to each other or to the body forms they lead to. Sean wants a **node graph**:
connected nodes you can zoom out to see the shape and zoom in to read, that **grows as you find it**.

I read "evolutions alongside powers" as **body forms alongside powers**: the graph holds the powers (with their evolution branches,
which are skills) and the form stages (slime, then lineage, then child, then sovereign). The fallback then means: if forms and
powers will not fit legibly at 640×360, show **one lineage of forms at a time** (the current body and its next stage) while powers
stay in full. If that reading is wrong, see "Open for Sean".

Success:

- a **Tree** tab opens a graph of every discovered power and form, with `???` stubs one step past what you know;
- you can select, zoom and read a node on **keyboard, mouse and a pad**;
- a ready, affordable evolution can be taken from its node, exactly as from the Skills tab;
- forms you reached in earlier lives stay on the graph, so the tree is a record of the soul, not of one life;
- a recipe's exact ingredients show only for a power you have owned once (the Compendium's rule), never before;
- the labels are legible at 640×360 at the normal zoom (checked by screenshot, below).

## Decisions

| Topic | Decision |
|---|---|
| Where | A new **Tree** tab, second in the strip. The Skills tab stays: it is where actives are assigned to slots, which a graph is poor at. The Compendium and Form tabs stay as they are. The Form tab is still where the body evolution is **chosen**; the tree shows forms read-only. With the Form tab showing there are seven tabs, so `tab_layout` gains a narrower stride |
| Model | A pure `SkillTreeModel` (like `SkillScreenModel.map_view`): `build(rules, compendium, forms, form_log, current_form, species)` returns nodes, edges and a layout; no scene code, so everything but the drawing is unit-testable |
| Nodes | `power` (a non-enemy skill that is not an evolution), `evolution` (a skill whose `source` is `evolution`), `form` (a `FormDef`, plus the base slime as the stage-1 root). Each node carries its state: `owned`, `retired` (evolved away: dim, "evolved"), `closed` (a sibling took the branch: dim), `ready` (an evolution whose conditions are met: glows), `current` (the body's form), `reached`, or `stub` |
| Edges | power → evolution (the evolution's `replaces`); power → the stage-2 form of every lineage that lists it in `FormDef.powers` ("opens"); form → child form (`parents`); slime → each stage-2 form. Nothing else connects |
| Growing | A **skill** node shows when its Compendium state is at least Named (a Hinted node also shows its hint; Owned-once also shows its conditions, with element chips for a mix). An **Unknown** skill is absent, except that an evolution of a node you show appears as a `???` stub until it is Named. A **form** shows when it has been offered or reached (persisted, below); its children appear as `???` stubs. A stub never shows a name, an icon or ingredients |
| Layout | Two bands in one canvas. **Upper:** powers, one per row, with a power's evolution branches to its right (base → two branches). **Lower:** forms, the stage across (slime, stage 2, 3, 4) and the lineages down. The "opens" edges run from a power in the upper band to its lineage's stage-2 form in the lower. Positions are computed from the **full** tree, discovered or not (columns by depth; power rows in name order; lineage rows in `FormOffers.LINEAGE_ORDER`), so a node never moves when another is discovered, and an undiscovered node leaves its slot empty, which also shows how much is left to find. This is the Map tab's rule (`map_view` returns the bounds of the whole world so its scale never shifts) |
| Zoom and pan | Three semantic zoom levels, not a continuous scale: **overview** (dots and edges, no labels), **normal** (name and state) and **close** (name, level pips and one detail line). The camera **follows the selection**. Mouse: wheel zooms, drag pans, click selects. Keyboard and pad: the direction keys, left stick or D-pad move the selection to the **nearest node in that direction** (`SkillTreeModel.neighbor(id, dir)`); two zoom actions step the level (keys, and the pad triggers, which are free in a menu); the right stick pans freely. New InputMap actions are added in `project.godot`; the hint line switches with `Controls.using_joypad` as the other tabs do |
| Detail | The existing right-hand card shows the selected node. A power reuses `SkillScreenModel.detail`; an evolution adds its price and what you hold ("Evolve for water 4 + dark 4 — you hold 6 water, 2 dark"); a form reuses the Form tab's card (stats, grants, blurb) and says whether it is current, reached earlier or unreached. Hidden conditions follow `compendium_rows`: shown only at Owned-once |
| Evolving | `accept()` on a **ready** evolution node arms it, and a second press evolves, through one shared helper that the Skills tab's row uses too (so the two entry points cannot drift). It does nothing on an unaffordable node except say what is short. Accepting a form node does nothing |
| Persistence | `FormLog`, a small model over `Profile` (it already offers `dict_section`), stores `{species: {form_id: "offered" | "reached"}}`. The species key is in the shape from the start so the spider adds a branch instead of a migration. `reached` is written when a body evolution is taken (the `evolved_body` event the player already emits); `offered` is written when the level cap is first reached and the offers exist (a new `form_offered` world event with the ids). The stage-1 slime is always reached. The Compendium stays global for now; splitting it per species belongs to the spider spec |
| Fallback | If the combined graph fails the legibility bar below at the normal zoom, `build()` takes a `forms_focus` option that keeps only the current form, its parent line and its next stage (with its stubs), and the power band is unchanged. This is Sean's "one evolution at a time", and it is a model filter, so it needs no second view. It is off unless the screenshot check requires it |

## Rendering

The screen is a code-built `CanvasLayer` (layer 20) at 640×360. The Map tab is the precedent for a drawn view: pure data in
`SkillScreenModel`, drawn into a box with panels and `ColorRect`s. The tree draws into a clipped `Control` ("viewport") whose single
child ("world") carries the camera as its `position`, so panning is one assignment. Nodes are small panels with a label; edges
are drawn by one `_draw` pass on the world node (lines in the existing palette: `COL_BORDER` for a known edge, `COL_DIM` for an edge
to a stub). Node count is bounded (about 22 skills and 25 forms, fewer while undiscovered), so no culling is needed. Labels use
the screen's `FONT_SMALL` (8) at normal and close; overview hides them.

**Legibility bar** (the thing the screenshot check decides): at the normal zoom with everything discovered, no two nodes overlap,
no edge crosses a node, every label fits its node untruncated, and the selected node's card is readable beside the graph.

## Engine and data changes

- `scripts/ui/skill_tree_model.gd` (new): nodes, edges, states, layout, `neighbor`, the `forms_focus` filter.
- `scripts/forms/form_log.gd` (new): the persisted record; `scripts/persistence/profile.gd` is used as is.
- `scripts/ui/skill_screen.gd`: the Tree tab (`_build_tree`, camera, zoom, input), the shared evolve helper, `tab_layout` for seven tabs.
- `scripts/ui/skill_screen_model.gd`: node card text (price, held, form card) and the mix-condition wording.
- `scripts/player/player.gd`: emit `form_offered` at the level cap; `evolved_body` already exists.
- `project.godot`: the zoom (and free-pan) actions for keyboard and pad.
- `tools/tree_shots.gd` (new, modelled on `tools/evolution_shots.gd`): screenshots of the tab at each zoom with nothing, a little and everything discovered.

## Testing

Run `tools/run_tests.sh`.

- **Model:** every non-enemy skill and every form appears as a node when fully discovered; every evolution has exactly one parent edge, and each stage-2 form has one "opens" edge per power it lists; an undiscovered skill is absent and its discovered parent shows it as a stub; a stub carries no name; Owned-once is the only state with ingredients; retired and closed derive from the engine as the Skills tab does; layout is deterministic and computed from the full tree, nodes never overlap, and discovering a node never moves another; `neighbor` reaches every node from the root by direction moves; the `forms_focus` filter keeps the current form, its parents and its next stage only.
- **Persistence:** `FormLog` round trip; a malformed section is dropped and warns, as `Profile` already does for other sections; `reached` survives a new life; `offered` is written once at the cap.
- **Screen:** the Tree tab is second; selection follows `neighbor`; zoom clamps at both ends; the camera keeps the selection inside the box; `accept()` on a ready affordable evolution arms then evolves and spends the price, and on an unaffordable one it changes nothing and says what is short; the Skills tab and the tree share one evolve helper; seven tabs lay out inside the strip.
- **By eye:** `tools/tree_shots.gd` at 640×360 for each zoom with nothing, partly and fully discovered, judged against the legibility bar; the result decides whether `forms_focus` ships on.

## Not here

- Per-species Compendium and shared-skill display (the open question about a power two species share): it arrives with the spider.
- Choosing the body evolution in the tree. The Form tab keeps that.
- Retiring the Compendium tab, which this graph makes partly redundant.
- Stage 2 → 3 pairing by the evolved power (the tree draws today's "both children" edges until the pairings are authored; see the essence overhaul spec).
- A free-form node editor, tooltips on hover, search.

## Open for Sean

1. **Do "evolutions" mean body forms?** I built the combined graph from powers plus forms. If you meant only the **power** evolution branches, the graph is smaller and the fallback is unneeded; the forms stay on the Form tab. Say so and I drop the lower band.
2. **Keep the Skills and Compendium tabs next to the tree?** Recommended, because the Skills tab assigns slots and the Compendium holds hints and conditions in a form that reads well as a list. The cost is three views of overlapping information.
3. **Evolve from the tree.** Allowed here with the same two presses. If you want the tree to be read-only, the shared helper is the only thing that goes.
