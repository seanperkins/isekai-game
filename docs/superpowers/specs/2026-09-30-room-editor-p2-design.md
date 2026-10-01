# Room Editor, Phase 2 — Design

Status: revised after the verification pass of round 2 of the debate (2026-09-30). Phase 2 of
`docs/superpowers/specs/2026-09-29-room-editor-design.md`, shaped by Sean's note on LDtk ("look at this tool"): its good ideas
for this game are a world overview, entities with editable fields, and one place that tells you what is wrong. Research:
`docs/research/level-design-reference.md`.

## What I understood

P1 lets Sean draw solids, drop creatures, add paired exits, start a room beside another, play it from a spot and save. It
cannot place the rest of what a room holds (glow pools, tablets, switches, rebirth pools), cannot set an exit's `shortcut`
(P1's `add_exit` takes it only from code), cannot edit a tablet's text or a pool's kit, cannot make a room bigger, cannot tell
him what the *suite* would object to (its rule tests live in test bodies), and Play starts a fresh slime with no skills, so a
room behind a Wall Cling gate or a shortcut is unplayable from the editor.

**Success for P2:** build a whole new playable room without a text editor. Add a tablet and type its text; add a switch and a
shortcut exit it opens; place a rebirth pool and set its kit; make the room wider or taller; click a problem in the list and
land on it; and play the room with Wall Cling granted and shortcuts open. "Validate clean" becomes the same thing as "the
suite's rule tests would pass".

## The phases

| Phase | What it delivers |
|---|---|
| P1 (shipped) | Separate editor scene; Solids, creatures, paired exits, New room beside, undo, Validate (the world validator), save, Play from here |
| **P2 (this spec)** | `RoomLint` (the suite's rule tests as one shared module); a live, clickable problems list; the Feature tool (glow pool, tablet, switch, rebirth pool); an inspector for an exit's `shortcut`, a tablet's title and text, a switch's shortcut, a pool's level and skills; growing a room (left, right, top); two play toggles (Wall Cling, open shortcuts); a read-only World view |
| P3 (shipped: `2026-10-01-room-editor-p3-design.md`; what moved to P4 is listed there) | The Start tool and moving the world's start; scenery (the decor palette and `dressing`); the hard-ledge toggle; numeric geometry fields; an exit's `gate`, assumed abilities and the stricter `over_hole`; tablet hints; a pool's room `area` and kit affinity; a free-form play kit; shrinking and deleting rooms; physical reachability from one shared surface model; prefab stamps; jump ruler; moving a room on the World view; copy and paste; selection cycling; templates; autosave; a JSON export for CI |

## Lint

`RoomLint` is a new `scripts/world/room_lint.gd`: pure statics, no nodes. One entry point, `RoomLint.check_room(r: RoomDef,
rooms: Dictionary) -> Array` (the world is needed for exit partners, shortcuts and feature ids), and `RoomLint.check(rooms) ->
Array` as a loop over it; `RoomLint.text(findings, rules: Array) -> String` joins the findings of the named rules. A
**finding** is `{room: String, rule: String, text: String, pick: Dictionary}`: `pick` is a model selection (`{kind, index}`) of
an element that is a selection kind in P2 (`solid`, `spawn`, `exit`, `feature`), else `{}` (a finding on the start or on decor
has no pick). There are no severity levels, no context argument and no rectangles: the landing point is the picked element's
bounds. `RoomLint` also owns the shared pieces: `MIN_EXIT` (36), `CLEAR` (64), the reach budget (`REACH_RISE` 55, `REACH_GAP`
60, `REACH_HOP` 80), `rock(r: RoomDef) -> Array` (the interior solids plus `RoomBuilder.edge_walls`; `RoomEditModel.rock` is
that plus the closed-shortcut gates, so placement and lint share one set) and `embedded(r, base: Vector2, kind := "") -> bool`, the one
test of whether a feature base is stuck: the feature's drawn box (`RoomLint.FEATURE_BOX[kind]`, the one table of box sizes, also
read by the model and the view) reaches into a side wall column (`box.position.x + base.x < RoomDef.WALL` or `box.end.x + base.x >
width - RoomDef.WALL`, half-open like `Rect2`, which also keeps a respawning slime clear of a doorway), or the point **one pixel
above the base** is inside `rock(r)`; with no kind the box is the base point alone. (`Rect2.has_point` includes the top edge, so testing the
base itself would flag every feature on a ledge and refuse every horizontal drag; the probe makes a feature on a floor or on
top of a ledge clean.) `test_prefabs.gd`'s `CLEAR` and `MIN_EXIT`, `RoomEditModel.KEEP_CLEAR` and the model's `MIN_EXIT`, and
`test_grotto_rooms.gd`'s `RISE` and `GAP` become references to `RoomLint`'s.

Twelve rules. Nine are lifted from suite tests (the feature half of `in_rock` is changed, as its row says); three are new. The suite's rule tests call `RoomLint` on
**every room**, each asserting only the findings of its own rule (`RoomLint.text(findings, [rule])`), so a mutation of one thing
turns exactly that rule's test red; and one aggregate test, `test_rooms.gd::test_the_world_has_no_lint_findings`, asserts
`RoomLint.check(rooms)` is empty, so "Validate clean" and "the suite's rules pass" are the same set.

| Rule | What it checks | Source | pick |
|---|---|---|---|
| `solid_outside` | every solid inside its room | `test_prefabs` | solid |
| `outside` | a spawn or the start inside the room | `test_rooms` | spawn |
| `in_rock` | a spawn or the start not inside a solid or boundary wall; a feature not `embedded` | `test_rooms`, `test_prefabs` (features changed to the one-pixel probe) | spawn, feature |
| `exit_blocked` | no mass solid (thicker than 24 on both axes) in the `CLEAR` zone in front of an exit, measured from the wall face | `test_prefabs` | exit |
| `exit_narrow` | an exit span at least `MIN_EXIT`; a test pins `MIN_EXIT >=` the body-derived span of `test_player_spread` (32 on a side edge, 36 on a top or bottom edge) | `test_prefabs`, `test_player_spread` | exit |
| `start_floor` | the start's y is `height - FLOOR - BodyConfig.BOTTOM` within 0.6 (no Start tool in P2: a suite guard) | `test_prefabs` | none |
| `ledge_reach` | every ledge reachable from the floor by the base-jump budget | `test_rooms` | solid |
| `over_hole` | no spawn, decor or dressing piece over a bottom exit that has neither a `gate` nor a `shortcut` (the suite's skip, kept as is; that a gated hole is open in play, `RoomBuilder.is_exit_open` reads only `shortcut`, is a known gap that goes to P3 with the `gate` field) | `test_grotto_rooms` | spawn |
| `pool_clearance` | no spawn within 200 px of a rebirth pool; exempt is the default pool (`id == WorldProgress.DEFAULT_POOL`), not "non-grotto", so a new Cave pool is held to it too | `test_grotto_rooms` | spawn |
| `feature_id` | a feature id that is empty or used by two features in the world | new | feature |
| `shortcut_pair` | the set of the world's switch shortcuts equals the set of its exits' shortcuts: a switch whose shortcut no exit uses opens nothing, and an exit with a shortcut no switch uses can never open | new | feature, exit |
| `hint_unknown` | a non-empty tablet `hint` that is not a skill id **the Compendium accepts** (a skill whose `source` is not `enemy_only`: `CompendiumModel.raise` has no slot for the others and does nothing); skill ids come from `RebirthKit.skill_defs()` | new | feature |

**Shipped data fix:** `data/rooms/G4.tres` has `"hint": "spore shell"`, which is not a skill id, so reading that tablet has
hinted nothing; the lint finds it and the same task sets it to `spore_cloud`. This is a gameplay change (the tablet starts
raising `spore_cloud` to HINTED) and the commit says so.

## Decisions (P2)

| Topic | Decision |
|---|---|
| Boundary | The **validator** (`WorldValidator`) is what the game needs to load and run: graph, exit pairing, overlaps, one start, rebirth pools, dressing, hard ledges, creature ids. **Lint** is the level-design rules the suite enforces, plus three checks that have no suite test today. Both lists are advisory in the editor; Save is never blocked. |
| Problems list | `RoomEditModel.problems() -> Array` merges lint findings with `WorldValidator.validate` strings into `{room, text, pick}`; a validator string's room is the text before its first `": "` or `" overlaps "`, kept only when that is a room id (`world: need exactly one start` and unparseable strings have no room). **`RoomEditModel.validate()` stays** (the validator-only list its callers and tests use today); `problems()` is added beside it, and `room_editor.gd` and the scene test move to `problems()` in the view milestone. It is recomputed when `RoomEditModel.serial` changes, never per mouse motion. The **Validate** button's label carries the count (`Validate (3)`); pressing it opens the list in the right-hand slot and the open list refreshes on an edit instead of closing. Clicking a problem opens its room, selects its `pick` and centres the view on the selection's bounds (the list stays open so the author can fix the next problem; the selection outline marks the target, and the inspector is not shown while a list is open); a problem with a room and no `pick` only opens the room. The id `world` is reserved in `id_error` (case-insensitively, like the uniqueness check), **not** in `valid_id`, which also gates shortcut ids. |
| Selection | One new kind, `feature` (the model's creature kind stays `spawn`; "creature" is UI text only). `hit` priority: spawn, feature, exit, solid (smallest area first). A feature is hit-tested, outlined and drawn as a marker from one table, `RoomLint.FEATURE_BOX` (a `Rect2` relative to the base per kind, grown by the pick radius when hit): a tablet 12x18 above its base (`tablet.gd`), a switch 18x22 above (`shortcut_switch.gd`), a glow or rebirth pool `Rect2(-19, -20, 38, 24)` (the 37x23 `water_pool` sprite, whose bottom sits 4 px below the base). **Every kind has an explicit arm** in `hit`, `begin_move`, `move_to`, `delete_selection` and the view's selection outline, and each `_` arm **refuses** (P1's `delete_selection` fell through to `_delete_exit` for any unknown kind, which with a feature selected would have deleted an exit and its partner); a test selects a feature, presses Delete and checks `exits` are untouched. No selection cycling (P3). |
| Features | A **Feature** tool with a palette of `glow_pool`, `tablet`, `switch`, `rebirth_pool`. `RoomEditModel.surface_below(room_id, p, with_gates := false) -> Variant` (a y or null) is the one loop that finds the top of the first solid or boundary floor at or under a point; it returns null for a point **inside** rock. `with_gates` adds the gates of closed shortcut exits as surfaces. `floor_spot(room_id, p, with_gates := true)` keeps its P1 behaviour (null in rock, a ledge or a closed gate counts) as `Vector2(p.x, surface_below(...) - BodyConfig.BOTTOM)`; the two defaults are opposite on purpose and a comment says so. **Play passes `with_gates = not open_shortcuts`** (with shortcuts open the gate is never built, so standing on it would drop the slime into the hole) through **one** `RoomEditor._spot(pos)` that both `play_error` and `play` call. A feature's `pos` is `(snapped x, y)`: its base. Placing, and each step of a drag, takes the candidate base from `surface_below` queried **from one pixel above the candidate** (so a horizontal drag along a floor or between co-planar ledges is not "inside" the surface it stands on) and is refused when `RoomLint.embedded` says the base is stuck (inside the wall column or a side doorway, or in rock), when nothing is below, or outside the room. Moving a feature re-drops it the same way. Delete removes it. Ids are generated and **never editable** (they key persistence: tablet read state, pool attunement): `<room lower>_<kind>_<n>` for the first `n` that is unused by any feature in the world (a pure function of the world: no counter, so an undo can never skip one; the id of a feature deleted and saved can be reused later, a risk accepted). Defaults: tablet `{title: "Tablet", text: ""}`, switch `{shortcut: <its id>}`, rebirth pool `{area: the room's area, kit: {}}`. |
| Inspector | A right-hand slot (168 px wide, scrolling, since the kit checklist is 16 skills) shows, for the selection, **one panel built in `inspector_panel.gd` from a const per-kind field list**; the rules live in the model: `RoomEditModel.get_field(sel, key)` and `set_field(sel, key, value) -> String` with flat keys and one `match`. One undo step per edit; a refusal returns the reason and changes nothing; **a value equal to the stored one is a no-op** (no step, no dirty mark), so an Enter followed by a focus loss is one step. Fields: **exit** `shortcut` (`valid_id`), written to both halves in one step; **tablet** `title` and `text`, both single-line `LineEdit`s (a tablet shows "a line of lore"); **switch** `shortcut` (`valid_id`, a `LineEdit`); **rebirth pool** `kit_level` (an `OptionButton`: none, then 1 to `Progression.LEVEL_CAP`) and `kit_skills` (a checklist of the kit-legal skills: not `enemy_only`, not `evolution`), validated as a whole by `RebirthKit.validate`. **`kit_*` writes merge into the existing kit dictionary and keep every other key** (G1's pool carries `affinity`, which P2 cannot edit and must not erase). Optional keys (an exit's `shortcut`, a tablet's `text`, `kit_level`) are removed by `""` or none; **required keys are never removed**: a feature's `id` and `pos`, a tablet's `title`, a switch's `shortcut`, a pool's `area` and `kit` (a Dictionary). A feature's id and position are not edited here. A `LineEdit` commits on Enter or focus loss; every control is **bound to the selection captured when it was built**. The inspector's `OptionButton`s and `CheckBox`es use `FOCUS_NONE` (as P1's buttons do), so `EditorPanels.typing()` stays "a `LineEdit` or `SpinBox` has focus" (the New room dialog has `SpinBox`es); while it is true `RoomEditor` hands no Delete, Backspace or Tab key to the view or to its own handlers, except that **Cmd/Ctrl+S commits the pending text and saves even while typing** (Cmd+Z stays with the field). **The inspector is rebuilt only when the selection's room, kind or index changes**; any other model change (an edit, an undo, a redo) refreshes the control values in place and skips the control that has focus, so tabbing from one field to the next never frees the field that just took focus. **Pending text is committed before anything else happens:** one `RoomEditor._commit_pending()` calls `get_viewport().gui_release_focus()` first in `RoomView._press` (before `hit`) and in every `RoomEditor` action handler (undo, redo, save, play and its spot click, open room, the Validate and World buttons, Grow, the toggles, New room), so typed text is never lost to a Save, an Undo, a room switch or a click, and "type text, then Undo" has one defined result: the text commits as an edit and the Undo then undoes it. The inspector is rebuilt with `queue_free`, so a control is never freed while it emits. With nothing selected and no list open the slot is hidden. |
| Growing | A **Grow** menu (`MenuButton`: Left, Right, Top) in toolbar row two: `RoomEditModel.grow_room(room_id, side, screens := 1) -> String`. **Grow only** (shrinking and deleting rooms are P3, together) and no room-`area` edit (P3). The **bottom is anchored**, so the floor stays where floor-standing content (the start, features, creatures) is; a taller room is made by growing the top. Refused only when the result would **overlap another room** (a side with an exit always touches its partner, so growing it overlaps) or exceed `MAX_SCREENS` (6). Growing left or top changes `cell` and shifts every local position of **this room** by `screens` x 640 (x) or 360 (y): solids, `hard_ledges`, spawns, features, `decor`, `dressing`, `start` **only when `is_start()`** (a non-start room's `NO_START` is `(-1, -1)` and must not move), and this room's own exits' `from` and `to` along the shifted axis. World positions never change and partners are untouched: a grown room's exit ranges only widen, so existing spans stay valid. One undo step, one room. Content attached to the **old ceiling** (stalactite stacks, hanging decor and dressing, ceiling spiders) shifts down with everything else and ends up hanging mid-air under the new ceiling; the author drags solids and creatures back up, and decor and dressing (scenery, P3) are re-hung by editing the `.tres`. Dressing is parallax art keyed to the room's size, so far props also appear to sit differently after growing; the data's world positions are preserved. |
| Play toggles | Two toggle buttons beside Play: **Wall Cling** (a constant kit `{skills: [leap, wall_cling]}`, asserted valid by a test through `RebirthKit.validate`) and **Open shortcuts**. They are `RoomEditor.play_options` and ride in `Game.editor_resume`. `play()` adds `kit` and `open_shortcuts` to `Game.play_request`; `Game._ready` reads them with `.get(key, default)` (P1's seam tests build a request without them), passes `kit` as the start's kit (`begin_life` applies it after `start_run()`) **with no compendium in an editor Play**, so the kit grant itself never raises `Compendium.model` slots (the rest of a play session, eating or defeating, still updates the model as in the real game, but into the sandbox profile only), and, when `open_shortcuts`, calls `open_shortcut(id)` on the fresh in-memory `WorldProgress` for every `shortcut` id used by an exit in the working rooms **before the world builds its first room**, so the entry room has neither the gate nor the switch. The real profile is still never written (the HOME sandbox). |
| World view | A **World** button toggles a read-only overview over the room: every room as a rectangle with its id at its world position, scaled to fit (`WorldView.layout(rooms, rect) -> Array` of `{id, rect}` and `WorldView.room_at(layout, point) -> String` are pure statics, so the click mapping is tested without a window), the current room outlined. Clicking a room opens it. It does not edit and has no other decoration in P2. It is the last milestone and does not block the others. |
| Panels | The toolbar becomes two rows (48 px). Row one: the room selector and the tools Select, Solid, Creature, Feature, Exit. Row two: Undo, Redo, Fit room, 1:1, Grow, Validate (N), World, Wall Cling, Open shortcuts, Save, Play, New room. The Creature and Feature palettes share the left strip (92 px) and show for their own tool; the right slot (168 px) holds the problems list or the inspector, never both. **Tab hides or shows every panel** when no field has focus. `fit()` fits the room in the area the toolbar rows, status bar and the visible panels leave free. |
| One door rule | `RoomEditModel._default_door` (New room beside) keeps its `DOOR` size and its search, but its "clear in front" test uses `RoomLint`'s zone (a right exit: x from `w - 84` to `w - 20`, measured from the wall face, replacing P1's `[w - 64, w)`) and `RoomLint.CLEAR`, so a door the editor makes can never fail `exit_blocked`; P1's stricter "no solid of any kind in the zone" stays (it counts ledges too). A door P1 would have placed may now sit a little elsewhere. The tests that name the constants or the strip (`test_room_edit_new_room.gd`, `test_prefabs.gd`, `test_grotto_rooms.gd`) are updated in the same task. |
| Suite | The rule tests listed in the Lint table become thin calls into `RoomLint`. Content pins still iterate the shipped list. An edit to a *shipped* room can break a pin that Validate cannot predict: `test_grotto_rooms` cells and sizes (G1-G4), `test_room_dressing` screen-band prop counts (a taller shipped cave room), `test_rebirth_kit` seeds for a new Grotto pool in a shipped room, and `test_rooms.gd::test_the_main_route_needs_no_skills` (a new room between an ungated room and C3 changes the ungated route, and the editor has no `gate` field until P3); the author of that edit updates the pin. |

## Architecture (P2)

- `scripts/world/room_lint.gd` (new): the rules and shared pieces above.
- `scripts/editor/room_edit_model.gd` (extended, about 800 lines): `surface_below`, `FEATURE_BOX`, features, the `feature` arms of
  `hit`, `begin_move`, `move_to` and `delete_selection`, `get_field`/`set_field`, `grow_room`, `problems()` beside `validate()`,
  `rock()` built on `RoomLint.rock`. No forwarding split; if the file hurts it is split by state in P3.
- `scripts/editor/inspector_panel.gd` (new): the controls and the per-kind field list.
- `scripts/editor/room_view.gd` (extended): the Feature tool, feature markers and outlines (from `FEATURE_BOX`), click-to-land,
  `_commit_pending()` before a press.
- `scripts/editor/editor_panels.gd` (extended): two rows, the Feature palette, the toggles, the Grow menu, `typing()`, Tab. The
  right slot and the problems list go in `scripts/editor/editor_slot.gd` (new) up front.
- `scripts/editor/world_view.gd` (new): the overview.
- `scripts/game.gd`: `kit` and `open_shortcuts` in an editor Play, no compendium for the kit.
- Doc comments to sweep with the code: `room_def.gd` and `room_features.gd` feature kinds (add `rebirth_pool`),
  `room_edit_model.gd` selection kinds, `editor_panels.gd` tools, `game.gd` request/resume docs, `room_editor.gd` status hint,
  `tests/support/shipped_rooms.gd` rule-test scope, and the P1 spec's phase table (what moved to P3).

## Milestones (each green on its own)

A. `RoomLint`, the suite lift, the G4 data fix, the door rule and the constant sweep. B. Model: `surface_below`, features,
the `feature` arms, `get_field`/`set_field`, `grow_room`, `problems()` (`validate()` stays). C. Game seam for the play toggles.
D. View, inspector, slot, problems list, toggles, Grow menu, screenshots (`room_editor.gd` and the scene tests move to
`problems()` here). E. World view. About 19 tasks in one plan.

## Failure modes and edge cases

- An invalid inspector edit (a bad shortcut id, a kit the validator rejects): the reason goes to the status bar, the model is
  unchanged, the field shows the stored value.
- A switch before its exit, or an exit with a shortcut before its switch: allowed to exist while authoring; `shortcut_pair`
  lists it until its other half exists. Deleting the exit a switch refers to does the same.
- Growing the room that holds the start or a rebirth pool keeps both (they shift with the content, only when they exist).
- Growing the top leaves ceiling-attached content mid-air (see Growing); growing left or right does the same for content that
  touched the old side wall.
- A feature dropped on a ledge stands on it; one dropped over a floor hole, inside rock, in a wall or in a side doorway is
  refused.
- Typed text and a click, a Save, an Undo, a room switch or Play: the text commits first, to the element it was typed for.
- Editing a pool's level or skills keeps its `affinity` and any other kit key.
- A saved room whose feature `id` is empty or duplicated (hand-edited): `feature_id` reports it; the inspector never edits ids.
- A tablet whose stored hint is not a hintable skill: `hint_unknown` reports it; the inspector has no hint field and leaves it
  alone.
- An editor Play with Wall Cling grants its skills without raising `Compendium.model` slots, and `Compendium.progress` is
  untouched; whatever the played slime then eats or defeats updates the model into the sandbox profile only.
- The World view with one room fills its panel; with rooms far apart the scale fits the bounding box.
- Undo after growing restores the exact previous `cell`, `size` and every shifted position (a snapshot of the one room).
- A grown room that now overlaps another is refused with the room's id.

## Testing

`RoomLint`: shipped rooms are clean, the aggregate test asserts no findings at all, and each rule's suite test asserts only its
own rule, proved by one mutation per lifted rule on a `RoomEditModel.copy_room` of real data (move a spawn into rock, narrow an
exit, drop a ledge out of reach, put a spawn over a hole, a spawn beside a grotto pool, and so on) turning exactly that test red.
Synthetic cases only where shipped data cannot reach: `shortcut_pair` in both directions, `pool_clearance`, `feature_id`,
`hint_unknown` (including a hint naming an enemy-only skill), `embedded` (a pool at x 30 is flagged and at x 40 clean, a tablet at x 20 clean; a feature on a floor and on a ledge is clean; sunk
into a ledge, in the wall column and in a side doorway is flagged); `MIN_EXIT >=` the body-derived span; the G4 hint is a
hintable skill. Problems: routing (`overlaps`, `world:`, a room prefix, a room named `world` refused), recompute only on `serial`
change, `validate()` unchanged, click-to-land opens the room, selects `pick`, centres its bounds. Model: `surface_below` and
`floor_spot` (in rock is null, the C6 gate case with and without `with_gates`), each feature kind placed with defaults, refusal
in rock, in a wall (x 12), in a side doorway and over a hole, unique ids across the world, a move re-drops and a drag crosses
co-planar ledges and runs along a floor, Delete with a feature selected leaves exits unchanged, `set_field`/`get_field` round
trips, an equal value is a no-op, required keys refuse removal, an exit's shortcut lands on both halves in one step, G1's
`affinity` survives `kit_level` and `kit_skills` edits, a pool's kit through `RebirthKit.validate`; `grow_room` on each of left,
right and top (shifted positions and spans, world positions unchanged, `start` shifted only when `is_start()`, a non-start room
stays non-start, ceiling solids end mid-air as documented, overlap and `MAX_SCREENS` refusals, one undo step). Game seam: `kit`
starts the player with the skills, `open_shortcuts` leaves the entry room with no gate and no switch, a request without `kit` or
`open_shortcuts` still works, `Compendium.progress` is untouched and granting the kit leaves every `Compendium.model` state as it was, `play_error` and `play` agree
on the spot with the toggle on and off. Scene (real mouse events through the viewport): select a feature by clicking its drawn
body (a pool's upper half and its edges too), edit a tablet's text and see it in the model, type text and then click Save (the saved `.tres`
holds it), type text and then Undo (the defined result), a pending edit committed by a click that changes the selection goes to
the right element, after ticking a kit skill Delete and Cmd+Z still work, Delete and Backspace inside a field do not delete the
element, Enter then focus loss is one undo step, the Validate (N) label and live list, the two toggles reaching the request,
Grow, Tab, the World view's pure layout and click mapping. Real windowed screenshots of the editor with the inspector open, the
problems list, the World view, and a played room with Wall Cling granted are looked at before merge.

## Rulings I made

1. **The Start tool is deferred to P3.** `start_floor` requires the room floor, the validator needs the default pool in the
   start room, and no success sentence needs it. Cost if wrong: the world's start cannot move in the editor.
2. **Scenery (decor and dressing) is deferred together.** It is bulk, biome-specific and has its own rules. Cost if wrong:
   crystals and vines are placed by hand in the `.tres`.
3. **The hard-ledge toggle, numeric geometry fields, selection cycling, kit affinity, an exit's `gate`, tablet hints, the room
   `area` edit and a free-form play kit are deferred.** No shipped room has a hard ledge, drag already moves things, `gate` has
   no effect in play (`RoomBuilder.is_exit_open` reads only `shortcut`), and the success paragraph needs none of them. Cost if
   wrong: a few values need the `.tres`.
4. **Grow only, bottom anchored.** Shrinking carries six refusals and a moved bottom strands floor-standing content; growing the
   top extends upward with floor-standing content intact, and ceiling-attached content is re-hung by hand. Cost if wrong: a
   room cannot be made smaller in the editor (git and undo cover mistakes).
5. **Lint has no severity levels or rectangles.** Nothing branches on levels; the landing point is the picked element's bounds.
   A gated room that needs more than the base jump fails `ledge_reach` until P3's assumed abilities. Cost if wrong: such a room
   fails the suite until then.
6. **Cross-feature rules are lint, not validator.** The validator's existing synthetic-room tests stay untouched. Cost if wrong:
   a game launch does not report a switch with no exit.
7. **Feature ids are not editable** and shortcut ids are `valid_id`, because they key persistence and group names.
8. **The G4 tablet hint is fixed to `spore_cloud`** in the lint task: it is data the lint proved broken, and the fix is a
   gameplay change the commit names. Cost if wrong: it should hint `hardened_shell`.
9. **`over_hole` keeps the suite's `gate`-or-`shortcut` skip.** Making gated holes count is unobservable before the `gate` field
   exists (shipped C3's stone arch over its gated hole is dressing and would be flagged for no gameplay reason); it goes to P3.
10. **Play options are two toggles, not a dialog**, with a constant kit and no compendium. Cost if wrong: another kit needs a
    code edit.
11. **The World view is read-only, undecorated and last.** Cost if wrong: no drag-to-rearrange, no dirty or problem marks.
12. **Every validation and lint pass is advisory; Save is never blocked.**
13. **The model is not split in P2.** Cost if wrong: an 800-line file.
14. **The tablet text is one line.** A tablet shows a line of lore; a multiline field would need `TextEdit` handling for no
    shipped text. Cost if wrong: a long tablet needs the `.tres`.

## Later

See the phase table: P3.
