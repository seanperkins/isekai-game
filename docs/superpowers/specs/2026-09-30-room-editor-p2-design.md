# Room Editor, Phase 2 — Design

Status: first draft (2026-09-30). Phase 2 of `docs/superpowers/specs/2026-09-29-room-editor-design.md`, shaped by Sean's note on
LDtk ("look at this tool"): its good ideas for this game are a world overview, entities with editable fields, and one
place that tells you what is wrong. Research: `docs/research/level-design-reference.md`.

## What I understood

P1 lets Sean draw solids, drop creatures, add paired exits, start a room beside another, play it from a spot and save. It
cannot place the rest of what a room holds (glow pools, tablets, switches, rebirth pools, the start spot, scenery), cannot
edit a thing's fields or exact numbers, cannot change a room's size, cannot tell him what the *suite* would object to
(its rule tests live in test bodies), and Play starts a fresh slime with no skills, so a room behind a Wall Cling gate is
unplayable from the editor.

**Success for P2:** build a whole new playable room without a text editor. Add a tablet and type its text; add a switch and
the shortcut exit it opens; place a rebirth pool and set its kit; make the room two screens wide; click a problem in the
list and land on it; and play the room with Wall Cling granted and shortcuts open. "Validate clean" becomes the same
thing as "the suite's rule tests would pass".

## The phases

| Phase | What it delivers |
|---|---|
| P1 (shipped) | Separate editor scene; Solids, creatures, paired exits, New room beside, undo, Validate (the world validator), save, Play from here |
| **P2 (this spec)** | `RoomLint` (the suite's rule tests as one shared module) with click-to-select results and a live count; features, the Start tool and decor; an inspector with exact numeric and typed fields; the hard-ledge toggle; resize by whole screens; play options; a read-only World view |
| P3 (later spec) | Physical reachability from one shared surface model with per-room assumed abilities and `gate` awareness; prefab stamps; jump ruler; editing `dressing`; moving a room on the World view; copy and paste; templates; autosave; a JSON export for CI |

## Decisions (P2)

| Topic | Decision |
|---|---|
| Lint | New `scripts/world/room_lint.gd` (`RoomLint`, pure statics, no nodes). `RoomLint.check(rooms: Dictionary, context := {}) -> Array` returns **findings**: `{room, rule, level: "error" or "warn", text, at: Rect2 (room-local; zero size means a point), pick: {kind, index} or {}}`; `check_room(r, rooms, context)` does one room (the world is needed for exit partners and shortcuts). `context` may carry `skill_ids` (Array) for the tablet-hint rule; rules that need context that is absent are skipped. Rules, each lifted from a suite test with the same logic: `solid_outside` (`test_prefabs`: every solid inside its room), `outside` (`test_rooms`: a spawn or the start inside the room), `in_rock` (`test_rooms`: a spawn or the start not inside a solid or boundary wall; `test_prefabs`: a feature not inside a solid), `exit_blocked` (`test_prefabs`: no mass solid, thicker than 24 on both axes, in the 64 px zone in front of an exit), `exit_narrow` (`test_prefabs` `MIN_EXIT` and `test_player_spread`: the span at least the rigged body plus 8), `start_floor` (`test_prefabs`: the start's y is `height - FLOOR - BodyConfig.BOTTOM` within 0.6), `ledge_reach` (`test_rooms`: every ledge reachable from the floor by the base-jump budget, level `warn`: a gated room may legitimately differ), `over_hole` (`test_grotto_rooms`: no spawn, decor or dressing over an ungated bottom exit); and three new ones: `feature_id` (empty or duplicate feature ids across the world), `switch_target` (`warn`: no exit in the world uses the switch's shortcut) and `hint_unknown` (`warn`: a non-empty tablet hint that is not a skill id; the hint is optional). **The suite's rule tests call `RoomLint`** and assert no findings (error or warn) on every shipped room, keeping their test names; the logic lives in one place. The world validator stays as it is. |
| Validate and live count | The Validate list shows lint findings and validator errors together, grouped by room. A finding is clickable: it opens its room, selects its element (`pick`) and centres the view on `at`; a validator string that starts with a room id and a colon opens that room only. The status bar always shows `N errors, M warnings` (lint plus validator), recomputed once after each completed edit, undo or redo (never per mouse motion), and clicking it opens the list. Save is never blocked. |
| Selection | `hit` gains kinds `feature`, `decor` and `start`. Priority: creature, feature, start, exit, decor, solid (smallest area first). `hit_all(room, p, pick) -> Array` returns every element under the point in that order; pressing again within 2 screen px of the previous press while the selection is in that list selects the next one, so a crystal on a ledge does not hide the ledge. |
| Features | A **Feature** tool with a palette of `glow_pool`, `tablet`, `switch`, `rebirth_pool`. Placing drops the feature to the surface below the click (`floor_surface`: the top of the first solid or floor under the point, a ledge included) and refuses a point inside a solid or outside the room, as features stand on something. Ids are generated unique per world (`<room>_<kind>_<n>`, lower case). Defaults: a tablet `{title: "Tablet", text: "", hint: ""}`, a switch `{shortcut: <id>}`, a rebirth pool `{area: the room's area, kit: {}}`. Moving a feature (drag) re-drops it on the surface under the new point. Delete removes it. |
| Start | A **Start** tool: a click drops the start to the floor below the click (`floor_spot`, the same rule as Play) and makes **this room** the world's start. If another room was the start its `start` is cleared in the same undo step (two rooms, one step). The start draws as a marker. Because the validator requires the default rebirth pool (id `C1`) to be in the start room, moving the start elsewhere raises that error until the pool is replaced: the tool's status message says so, and the lint list shows it. |
| Decor | A **Decor** tool with a palette **derived from the shipped data**: every distinct decor id used by the loaded rooms whose texture exists (`Art.texture(id) != null`), with its most common light colour (or none) and anchor. No new registry. Placing writes `{id, pos[, light][, anchor]}` at the snapped click point, inside the room. Decor is selectable, draggable and deletable like a creature; `dressing` is not touched. |
| Inspector | A right-hand panel (168 px wide, in the 640x360 viewport) for the selection, built from a **field schema**: `InspectorSchema.fields(room, selection, context) -> Array` of `{path, label, type: "text" or "int" or "float" or "bool" or "enum" or "color" or "list", options, min, max}` and `RoomEditModel.get_field(sel, path)` / `set_field(sel, path, value) -> String` (one undo step each, `""` or an unset optional removes the key, a refusal returns the reason and changes nothing). Fields: **solid** `x y w h` (exact, clipped to the room, minimum `MIN_SOLID`) and **hard ledge** (a checkbox, offered only when `RoomBuilder.is_one_way(rect)`; `hard_ledges` holds the rect); **creature** `id` (enum of creature ids) and `x y`; **exit** `from to` (exact, moves the partner as a drag does, same refusals), `gate` and `shortcut` (both halves, one step); **feature** `id` (text, unique) and `x y`; a **tablet** also `title text hint` (hint an enum of skill ids plus none), a **switch** `shortcut` (an enum of the shortcut ids the world's exits use, plus free text), a **rebirth pool** `area` (enum), `kit.level` (int 1 to `Progression.LEVEL_CAP`, 0 unsets), `kit.skills` (a list of skill ids from the kit-legal set: not `enemy_only`, not `evolution`) and `kit.affinity.<essence>` (an int per `RebirthKit.ESSENCES`, 0 unsets); **decor** `x y`, `light` (a colour, cleared removes it) and `anchor` (enum). A text field commits on Enter or focus loss, a numeric one on Enter, a checkbox or enum at once. Shortcut keys never fire while a field has focus (`panels.typing()`). With nothing selected the panel shows the **room panel**. |
| Room panel | The current room's `area` (enum; the biome art follows), its size in screens, and for each side `−` and `+` buttons. **Resize** is whole screens only: `resize_room(room_id, side, delta) -> String`. Growing or shrinking the right or bottom changes `size`; the left or top also changes `cell` and shifts **every local position** (solids, `hard_ledges`, spawns, features, decor, dressing, the start, and this room's own exits' `from` and `to` along the shifted axis) by the screens added or removed, so world positions never move. Refused, with the reason, when: the side has an exit (remove it first), the new rect overlaps another room, the size would go below one screen, any solid, spawn, feature, decor, dressing entry or the start lies (even partly) in a band being removed, or after the change any exit span on a perpendicular edge would fall outside `WorldValidator.edge_range` for this room or its partner's. One undo step touching only this room. No drag handles (a ruling below). |
| Play options | A **Play options** dialog: a kit (`skills` list and `level`, the same shape and the same validation as a rebirth kit, via `RebirthKit.validate`), and **open all shortcuts**. Two presets: *None* and *Cave movement* (`leap`, `wall_cling`). The options live on the editor (`RoomEditor.play_options`) and ride in `Game.editor_resume`, so they survive a Play. `play()` adds `kit` and `open_shortcuts` to `Game.play_request`; `Game._ready`, in an editor Play, passes `kit` as the start's kit (`begin_life` already applies it after `start_run()`) and, when `open_shortcuts`, calls `open_shortcut(id)` on the fresh in-memory `WorldProgress` for every `shortcut` id used by an exit in the working rooms. The real profile is still never written (the HOME sandbox). |
| World view | A **World** button and the `M` key toggle a read-only overview over the room: every room as a rectangle at its world position, scaled to fit, tinted by area, the current room outlined, `*` on dirty rooms, a red outline on rooms with lint errors, short ticks where exits meet. Clicking a room opens it. It does not edit. |
| Panels | The toolbar becomes two rows. Row one: the room selector and the tools Select, Solid, Creature, Feature, Decor, Exit, Start. Row two: Undo, Redo, Fit room, 1:1, Validate, World, Play options, Save, Play, New room. The creature, feature and decor palettes share the left strip and show for their own tool. **Tab hides or shows every side panel** (the inspector, the palettes, the Validate list) so the whole room can be reached; the room view's `fit()` leaves the toolbar rows and status bar clear. |
| Suite | The rule tests listed under Lint become thin calls into `RoomLint`. Content pins still iterate the shipped list. A room added by the editor must pass the lint rules; the suite runs them on every room (rule tests), as in P1. |

## Architecture (P2)

- `scripts/world/room_lint.gd` (new): the rules above, pure statics. The base-jump reach moves here from `tests/test_rooms.gd`
  (the 55 px rise, 60 px gap, 80 px hop budget, as constants).
- `scripts/editor/room_edit_model.gd` (extended): features, start, decor, `hit_all`, `floor_surface`, `get_field`/`set_field`,
  `resize_room`, `lint()` (lint plus `WorldValidator.validate`, merged and grouped), `decor_palette(rooms)`.
- `scripts/editor/inspector_schema.gd` (new): the field table per selection kind. Pure, so it is testable without nodes.
- `scripts/editor/inspector_panel.gd` (new): builds controls from the schema; emits `field_edited(path, value)`.
- `scripts/editor/room_view.gd` (extended): the new tools and markers (features, start, decor outlines), cycling selection.
- `scripts/editor/editor_panels.gd` (extended): two-row toolbar, palettes, room panel, the clickable Validate list with the live
  count, Play options dialog, Tab. Split the new dialogs and the room panel into `scripts/editor/editor_dialogs.gd` up front.
- `scripts/editor/world_view.gd` (new): the read-only overview.
- `scripts/game.gd`: `kit` and `open_shortcuts` in an editor Play.
- Tests: the suite's rule tests become `RoomLint` calls; new tests per module.

## Milestones (each green on its own)

A. `RoomLint` and the suite lift (no editor code). B. Model: features, start, decor, `hit_all`, `get_field`/`set_field`,
hard ledge, `resize_room`, `lint()` (headless). C. Game seam for play options. D. View, inspector, panels, World view and
the scene smoke tests, with real screenshots. About 25 tasks in one plan.

## Failure modes and edge cases

- An inspector edit that is invalid (a duplicate id, a kit the validator rejects, a span outside its edge): the reason goes
  to the status bar, the model is unchanged, and the field shows the stored value again.
- Two features with the same id: refused at edit time, and `feature_id` flags a world that already has them.
- A switch whose shortcut no exit uses: allowed (the exit may come next); `switch_target` warns until one does.
- Deleting an exit that a switch refers to: allowed; the switch's warning appears.
- Resizing the room that holds the start, or a rebirth pool, keeps both (they shift with the content). Resizing a room that
  would cut one off is refused like any other element.
- Moving the start to another room before the default pool: the validator error is shown, never hidden.
- Play options with a skill that was removed from the data: `RebirthKit.validate` names it and Play refuses.
- The World view with one room, or rooms far apart: the scale fits the bounding box; a single room fills the panel.
- Undo after a resize or a start move restores the exact previous cells, positions and starts (snapshots of the rooms
  touched, as in P1).
- `Tab` while a text field has focus moves focus, not the panels.

## Testing

`RoomLint`: each rule has a red and a green case on synthetic rooms and the shipped rooms are clean, including the new rules;
the rule tests in the suite are the shipped-room checks and a mutation (move a spawn into rock) turns the right one red.
Model: placing each feature kind (surface drop, refusal in rock, unique ids, defaults), the Start tool (one start in the world,
two rooms in one undo step, validator message), decor (palette derived from the shipped rooms; place, move, delete, undo),
`hit_all` order and cycling, `set_field`/`get_field` round trips for every schema path including nested kit paths and clearing
a key, refusals that change nothing, exit `from`/`to` through the inspector moving the partner, the hard-ledge toggle only on
a thin solid and keeping `hard_ledges` valid, `resize_room` on each side (shifted positions with world positions unchanged,
exits on perpendicular edges, refusal for an exit on the side, an overlap, cut content, a perpendicular span out of range),
and that a resize is one undo step. Game seam: a request with `kit` starts the player with the skills, `open_shortcuts` opens
every shortcut id of the working rooms on the in-memory progress, `Compendium.progress` is still untouched. Scene: select by
click and by cycling, an inspector edit reaching the model, Validate click-to-select opening another room, the live count, the
World view click, Tab, the Play options dialog; real windowed screenshots of the editor with the inspector open, the World view
and a played room with Wall Cling granted are looked at before merge.

## Rulings I made

1. **The suite's rule tests move into `RoomLint`; the validator is not merged into it.** The validator checks the room graph;
   lint checks one room's contents against the world. Cost if wrong: two lists to read, merged in the UI.
2. **Resize by buttons in whole screens, not drag handles.** A handle drag would need snapping, live content checks and the
   side-exit refusal every motion; buttons give the same result with a clear refusal reason. Cost if wrong: a drag is faster.
3. **Features drop to the surface below the click.** Features stand on something; the shipped ones do. Cost if wrong: floating
   features cannot be placed.
4. **The decor palette is derived from the shipped data**, not a registry. Cost if wrong: a sprite no shipped room uses is not
   offered.
5. **`dressing` stays out of the editor** (P3): it is bulk scenery with its own validation and depth rules.
6. **The World view is read-only.** Moving a room changes adjacency, and with it every exit pairing. Cost if wrong: no
   drag-to-rearrange.
7. **Every validation and lint pass is advisory; Save is never blocked.** Sean may save a half-built room. Cost if wrong: an
   invalid world on disk, which every game launch then reports.
8. **Exact numbers are editable through the inspector** (solids, exits, positions), the readout the P1 spec said was missing.
9. **`ledge_reach` is a warning** because gated rooms legitimately need skills the base budget lacks; the suite still requires
   the shipped rooms to be clean of it.

## Later

See the phase table: physical reachability, prefab stamps, the jump ruler, dressing, moving a room, copy and paste, templates,
autosave, JSON export for CI.
