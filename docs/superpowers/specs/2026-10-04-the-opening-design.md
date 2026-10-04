# The Opening (soul layer, plan 4) — design

Date: 2026-10-04. Builds on `docs/superpowers/specs/2026-10-04-soul-layer-design.md` (plans 1 to 3 are on main: the goddess, her menu, altars). The soul spec left this one as an outline ("its beats get their own brainstorm"); this is that brainstorm. The design doc's "Opening sequence" section is the product intent.

## What it is

On a profile that has never played, the game opens with a joke for anyone who knows isekai: a truck, a tiny JRPG menu, three trucks, death. Then the goddess meets the player in her usual menu, with only slime, the Cave altar and nothing to buy. It plays once, ever. It is not a real tutorial.

Decided in the brainstorm (2026-10-04, Sean):
- **Look:** a black screen, a thin road strip, a small code-drawn truck sprite that slides in and a small figure, with a JRPG text box. No new art files; restyle later.
- **Menu:** each of the three trucks offers Dodge, Jump, Pray and Run. Every choice fails, each with its own deadpan line, so the choice only picks the joke.
- **No skip.** It is short; Enter advances.
- **Copy:** placeholder lines drafted in a data file for Sean to rewrite, as with her death lines.
- **Old saves:** a profile that already has a map and no opening flag counts as seen and never gets the truck. A profile that quits mid-opening replays it.

## Flow

1. `Game._ready` builds the world, the player and `begin_life` as it does today. If `Game.wants_opening(...)` is true, `start_opening()` runs at the end of `_ready`, after `begin_life` (the life under the scene is thrown away by the restart that follows her menu).
2. `OpeningScene` (a `CanvasLayer`, layer 45, `PROCESS_MODE_ALWAYS`, with a child `Node2D` stage that holds the drawing) pauses the tree and covers the screen in black, so the live Cave and its bats cannot touch the player. It plays three beats; each is a prompt ("A truck is coming."), the four choices, the chosen choice's result line with the truck hitting, then Enter for the next truck.
3. After the third result it hides its layer (the tree stays paused, so the goddess's menu at layer 40 is not left behind its layer 45) and emits `finished`. `Game` answers with `run.open_first_meeting(def.goddess_line)`, which opens `GoddessMenu` with her first words even though there is nothing to choose, counts no death, and (when the player confirms) marks the opening seen and begins the life through the existing `_begin` and restart path: `pending_start` is `{altar: "C1", species: "slime", kit: {}}`. If `open_first_meeting` returns false, `Game` unpauses the tree and the player simply plays on, the opening still unseen: it must never leave the game paused with nothing to press.
4. The scene reloads, `resolve_start` consumes the pending start, and the game plays as it does after any rebirth. The tree is unpaused by `Game._prepare_restart`, as for every restart.

The truck's hit emits `world_event("opening_hit", {})`, routed in `data/audio/cues.json` to a new cue `opening_hit` that reuses the `enemy_impact` files on the `UI` bus, not positional: `Audio` keeps only `UI` voices alive while the tree is paused, and `enemy_impact` (bus `SFX_Enemy`, positional) would be silent under the opening. The approach is silent for now. No `player_died` event is emitted, so the death cue, `many_deaths` and the heartbeat are untouched.

## Units

**`OpeningDef`** (`scripts/soul/opening_def.gd`, a `Resource`; `data/opening/opening.tres`, written by a one-shot addition to `tools/build_soul.gd` and then edited freely):
- `choices: Array` of `{"id": String, "label": String}` (dodge, jump, pray, run).
- `trucks: Array` of `{"prompt": String, "results": Dictionary}`, `results` mapping a choice id to its line.
- `fallback: String`: the result line for a choice a truck has no entry for.
- `goddess_line: String`: her first words (a few sentences; her menu's line label wraps to two lines).
- `func result_for(truck: int, choice_id: String) -> String`: the truck's entry, else `fallback`.

**`OpeningValidator`** (`scripts/soul/opening_validator.gd`): `static func validate(def: OpeningDef) -> PackedStringArray`. Errors for: `choices` or `trucks` not an Array or empty, an entry that is not a Dictionary, a choice `id` or `label` that is not a String or is blank or duplicated, a truck `prompt` that is not a String or is blank, `results` that is not a Dictionary, a `results` key that is not a choice id, a result that is not a String or is blank, a blank `fallback`, a blank `goddess_line`. A test runs it over the shipped file; `Game.start_opening()` runs it on the loaded resource too.

**`OpeningModel`** (`scripts/soul/opening_model.gd`, `RefCounted`, pure): `enum Phase {PROMPT, RESULT, DONE}`; `_init(def: OpeningDef)`; `phase`; `truck() -> int`; `truck_count() -> int`; `prompt() -> String` ("" once done); `rows() -> Array` (the choice labels in PROMPT, else `[]`); `row() -> int`; `move(step: int)` (PROMPT only, clamped); `act() -> bool` (PROMPT takes the highlighted choice and enters RESULT; RESULT enters the next truck's PROMPT, or DONE after the last; false in DONE); `chosen() -> String` (the id taken this truck); `result_line() -> String` (RESULT only); `done() -> bool`.

**`OpeningScene`** (`scripts/ui/opening_scene.gd`, `CanvasLayer`): `signal finished`; `func play(def: OpeningDef) -> bool` (false, and nothing starts, when the tree is already paused or a play is under way); `is_playing()`; `text_lines() -> Array` and `row_texts() -> Array` for tests (a highlighted row starts "> ", the others two spaces). It drives an `OpeningModel` from keys, the D-pad and the left stick through `NavStep` (the menu actions `ui_up`, `ui_down`, `menu_accept`/`ui_accept`, as `AltarMenu` reads them); no mouse. It is added last, so it sees input first, and while playing it marks every key and joypad event handled, so the skill screen's menu key, Escape and the world's actions do nothing and there is no skip. The stage draws the road, the truck and the figure with `_draw` (a `CanvasLayer` is not a `CanvasItem` and cannot), and the truck slides in over a short tween while the prompt shows; the hit is a one-frame white flash. Beats are a few seconds each.

**`SoulProgress`** gains `var opening_seen := false`, saved in the `soul` section as `opening_seen`. Loading: a saved boolean wins; with no key, `opening_seen` is true when the Profile's `map` section is non-empty (a save from before the opening existed). `begin_opening()` saves (so a profile that quits mid-opening holds an explicit `false` and replays it); `finish_opening()` sets it true and saves. `_save()` always writes the key.

**`Run`** gains `func open_first_meeting(line: String) -> bool`: false (and nothing happens) with no goddess or no progress (an editor Play) or while a choice is pending; otherwise it builds `goddess.model(_progress, _pools)`, remembers it, flags the opening, and emits `goddess_needed(model, line)`; with no listener it begins the pre-selected start directly, as `_resolve` does, so the game never hangs. `_begin` calls `goddess.soul.finish_opening()` when that flag is set. `accept`'s check against the pending model is unchanged.

**`GoddessMenu`** becomes `PROCESS_MODE_ALWAYS` so it works over the tree the opening paused (the death flow leaves the tree unpaused, so nothing there changes).

**`Game`** gains `static func wants_opening(soul: SoulProgress, args: Array, headless: bool, editor_play: bool) -> bool` (never in an editor Play; `--skip-opening` is false; `--opening` is true; a headless run is false so every existing test skips it; else `not soul.opening_seen`), `var opening: OpeningScene`, and `func start_opening() -> bool`: loads `data/opening/opening.tres`; a failed load or any `OpeningValidator` error is `push_error`'d with the path and the errors and returns false with nothing paused and nothing saved; otherwise it calls `opening.play(def)` and only when that returns true calls `soul.begin_opening()` (so a refused start, over a pause or a play under way, changes no saved state); on `finished` it calls `run.open_first_meeting`, unpausing if that is refused. Tests call `start_opening()` directly.

## Data and persistence

New: `data/opening/opening.tres`. The only new persisted field is `opening_seen` in the existing `soul` section. Nothing migrates.

## Constraints

Another agent owns movement: this plan touches nothing under `scripts/movement/`, `data/movement/` or the movement tests, and not `scripts/player/player.gd`. It edits `scripts/game.gd`, `scripts/run.gd`, `scripts/ui/goddess_menu.gd`, `scripts/soul/soul_progress.gd` and `data/audio/cues.json`; the movement agent has said it does not touch those.

## Testing

Pure: `OpeningModel` (phase flow, clamped rows, a result per choice, DONE after the last truck), `OpeningDef.result_for`, `OpeningValidator` (each error and the shipped file), `SoulProgress` (the flag round-trips; an old profile with a map and no key loads as seen; a fresh one loads unseen; a quit mid-opening reloads unseen; the key is always saved), `Game.wants_opening` (every flag and the headless and editor cases). Scene: `OpeningScene` (play pauses, refuses when paused, rows and text follow the model, keys and the stick drive it, finished fires once). Flow: one end-to-end test through real keys on the real scene, which replaces `_restart` with a counter as `test_goddess_flow.gd` does (a real restart would reload the runner's scene and clear `pending_start`): `start_opening()`, three trucks with a different choice each, the opening's layer is hidden and her menu is visible with `goddess_line`, Enter, the counter is 1, `pending_start` is the Cave altar and slime, `opening_seen` is saved true; and a test that a death afterwards reads as death 1 (the opening counted none). That a restart unpauses is `Game._prepare_restart`'s existing test (`test_run.gd`). Refusals: a `start_opening()` over a pause or a play under way leaves the saved flag unchanged and the pause alone; a malformed resource (a string `results`) returns false, saves nothing and leaves the tree unpaused; a refused `open_first_meeting` unpauses.

## Docs

The design doc's opening section and checklist, the design-review page, and the playtest checklist (with the `-- --opening` and `-- --skip-opening` flags).

## Review focus

- A profile with progress never sees the truck, and a brand-new one always does (the load rule, tested both ways).
- The opening cannot start over a pause, in an editor Play, or in a headless run, and the world under it cannot hurt the player.
- Quitting mid-opening replays it; accepting the goddess's menu ends it for good, and a death afterwards counts as the first.
- A malformed `opening.tres` (blank lines, an unknown choice key, a wrong type) is named by the validator at runtime too, never a crash, and never leaves the game paused or the flag saved.
- The truck's hit is audible while the tree is paused (the `UI`-bus cue).

## Out of scope

Real truck and figure art, voice or music, a skip, and any change to her death lines. The copy is placeholder.
