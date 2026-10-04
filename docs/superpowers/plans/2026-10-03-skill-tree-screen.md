# Skill Tree Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a zoomable, read-only **Tree** tab, second in the pause screen's strip, that draws every discovered power, its evolutions and the body forms as a node graph that grows as the soul finds it. The Sound tab's sliders move into a Settings menu opened from the pause screen.

**Architecture:** There are three steps. Step 0 moves the sliders into a `SettingsMenu` overlay inside `SkillScreen` and swaps the Sound tab for the Tree tab, so the strip keeps five tabs and `tab_layout` is unchanged. Step 1 adds a pure `SkillTreeModel` (nodes, states, edges, a layout computed from the full tree, `neighbor`), a `SkillTreeView` builder (a clipped `Control`: one panel per node, one `_draw` pass for the edges, the camera a pure function of the selection and the zoom), and the tab hosting it. The tab gets keys, the D-pad, a two-axis stick step, `tree_zoom` and the mouse. Step 2 adds the forms band: `WorldProgress.forms_reached` is written through a new `Player.form_advanced` signal, `SkillScreenModel.form_card` is extracted from the Form tab, and the model gains form nodes, "opens" edges and the Greater rule. A fourth step, `forms_focus`, is an appendix built only if the screenshots fail the legibility bar.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1 (`tools/run_tests.sh [file-substring]`), headless Godot for tests, the windowed renderer for `tools/tree_shots.gd`.

**Spec:** `docs/superpowers/specs/2026-10-03-skill-tree-screen-design.md`. Read it with this plan; the plan implements it task by task. It is built **after** the essence overhaul (`docs/superpowers/specs/2026-10-03-essence-overhaul-design.md` and its own plan), which ships first.

## Global Constraints

These apply to every task.

- Godot 4.7 / GDScript / GUT 9.7.1. Every new script (a `class_name` file or a test) needs `gtimeout -k 5 180 env HOME="$PWD/.tmp/gdhome" godot --headless --import > .tmp/test-logs/import.log 2>&1` before its first run, so the global class cache knows it. Commit its `.uid` file. A `SCRIPT ERROR` or `Parse Error` in the log fails `tools/run_tests.sh`. For the whole suite, use `TEST_TIMEOUT=900 tools/run_tests.sh`.
- `var x := <expr>` is a parse error when `<expr>` has no static type (a Dictionary element, an untyped call). Type such variables explicitly (`var nodes: Dictionary = m["nodes"]`).
- **Essence overhaul interfaces.** This plan may use exactly these, and only after the overhaul has landed:
  - `SkillDef.evolution_price` (Dictionary element → units, set once on the base power);
  - `SkillRulesEngine.held(element) -> int`, `can_afford(id) -> bool` and `evolution_price(id) -> Dictionary`;
  - `FormDef.powers` (Array of skill ids, stage-2 lineage forms only);
  - `FormOffers.open_lineages(forms: Dictionary, rules) -> Array` (lineage ids in `FormOffers.LINEAGE_ORDER`).
  - `SkillScreenModel.price_text(price: Dictionary) -> String` and `SkillScreenModel.shortfall_text(rules, price: Dictionary) -> String` (overhaul part 3; this plan's `price_line` and `short_line` build on them, and must not reuse those two names).

  The overhaul rewrites parts of `skill_screen.gd`, `skill_screen_model.gd` and `form_offers.gd`. So the `file:line` citations below (read before the overhaul) are approximate: locate code by the function names given.
- The screen is 640×360. The tree box is the list column, `Rect2(158, 46, 244, 274)`, so the card stays where it is (`DETAIL_X` 418). Node labels use `FONT_SMALL` (8) at the normal zoom; the overview hides them.
- Tabs: `TABS == ["skills", "tree", "compendium", "bestiary", "map"]` (indexes 0 to 4). Form stays at 5 when shown. `tab_layout` and its two strides are unchanged: five tabs end at x = 532.
- Input actions live in `autoload/controls.gd` (`BINDINGS`, `PAD_BUTTONS`). `project.godot` has no `[input]` section. Every new action needs a `BINDINGS` entry, because `ensure_actions` iterates `BINDINGS` only.
  - `tree_zoom` is Z plus L3 (`JOY_BUTTON_LEFT_STICK`).
  - `settings` is Tab plus R3 (`JOY_BUTTON_RIGHT_STICK`).
  - Taken in the game: Q E W A S D, the arrows, Enter, Space, Backspace, Esc, J K I R U O H L F, Shift, F3, F11, and F5 (editor Play's return, `scripts/editor/editor_return.gd:13`). The pad triggers are `active_3`/`active_4`. Tab and Z appear only in the room editor scene.
- The tree is read-only. Evolving a power stays in the Skills tab; choosing a body evolution stays in the Form tab.
- A secret skill is absent, with no reserved slot, until its Compendium state is Owned-once. A stub never carries a name, an icon or ingredients. A condition shows only at Owned-once.
- Reached forms live in `WorldProgress.forms_reached`, saved through `Profile.list_section`. The slime is reached by definition and never stored. The section is written only through `Player.form_advanced` → `progress.reach_form`, never through `EventBus.world_event` (audio-only).
- Process:
  - TDD: run each new test and see it fail first.
  - Conventional commit messages with no attribution lines.
  - Report only commit SHAs copied from git output.
  - Scratch files go under `.tmp/<task-dir>/`; worktrees under `.worktrees/`.
  - Do not edit the spec.

## Review Focus

These are the input classes the spec implies but no task's tests would exercise unless asked. Each has a test in the task that owns the code.

1. **A diagonal stick push on a list tab.** Today a stick at (0.8, 0.6) moves the Skills list down a row. A dominant-axis step would return "right" and freeze every list. Expected: the lists read only the vertical part, so a diagonal still moves them and a sideways push does not (Task 3).
2. **Esc, Start or B while the Settings menu is open.** `menu` is checked first in `_unhandled_input` and toggles the whole screen, and Audio saves on `menu_closed`. Expected: each closes only the menu, the game stays paused, no `menu_closed` is sent, and the tab is unchanged (Task 1).
3. **A real click through the viewport while the tree is paused.** The click itself switches the scheme to the mouse, and `Controls.scheme_changed` rebuilds the screen inside `Controls._input`, before the GUI sees the click. Expected: the click still lands on the rebuilt panel and selects it, because the canvas stretch does the hit-testing and the screen runs with `PROCESS_MODE_ALWAYS` (Task 10).
4. **A stale id in `forms_reached`** from an older save, after a form was renamed or removed. Expected: it is ignored, with no node and no error, and the other reached forms still show (Task 15).
5. **A scheme change while the tree is open** (a pad touched mid-browse). Expected: the screen rebuilds with the same selection and zoom, and the hint switches to the pad's words (Task 9).

---

## File Structure

**Create:**
- `scripts/ui/settings_menu.gd`: `SettingsMenu`, the overlay `Control` holding the Sound sliders (step 0).
- `scripts/ui/skill_tree_model.gd`: `SkillTreeModel`, pure data with nodes, states, edges, layout, `root`, `neighbor` (and `forms_focus` only if the appendix ships).
- `scripts/ui/skill_tree_view.gd`: `SkillTreeView`, the clipped box with node panels, the edge segments, `camera()`, and the mouse signals.
- `tools/tree_shots.gd`: real-renderer shots of the Tree tab, modelled on `tools/evolution_shots.gd`.
- `tests/test_skill_tree_model.gd`, `tests/test_skill_tree_view.gd`, `tests/test_tree_tab.gd`, `tests/test_forms_reached.gd`.

**Modify:**
- `scripts/ui/skill_screen.gd`:
  - Step 0: the Settings menu, then the Tree tab replacing Sound.
  - Step 1: the two-axis `nav_step`, the tree state, input and card.
  - Step 2: the reached forms and the `form_card` use.
- `scripts/ui/skill_screen_model.gd`: `tree_card`, `price_line`, `short_line`, `form_card`.
- `autoload/controls.gd`: the `settings` and `tree_zoom` actions.
- `scripts/world/world_progress.gd`: `forms_reached`, `reach_form`, `is_form_reached`.
- `scripts/player/player.gd`: `signal form_advanced(id)`.
- `scripts/game.gd`: connect it to `progress.reach_form`.
- `tests/support/pad_input.gd`: `mouse_click`.
- Tab-index churn (Task 2): `tests/test_skill_screen.gd`, `tests/test_audio_ui.gd`, `tests/test_map.gd`.
- Other test files: `tests/test_menu_input.gd` (Tasks 1 and 3), `tests/test_world_progress.gd`, `tests/test_form_tab.gd`.

**Checked and left alone:**
- `tests/test_evolution_screen.gd`: `switch_tab(4)` then `switch_tab(0)` now visits Map instead of Sound and still disarms, because `switch_tab(0)` resets `_sel`.
- `tests/test_form_tab.gd` tab tests: Form stays at 5, and `tab_layout(5)` is unchanged.
- `tools/evolution_shots.gd`: `switch_tab(5)` still lands on Form.

---

## Step 0: the Settings menu

### Task 1: The Settings menu holds the Sound sliders

**Files:**
- Create: `scripts/ui/settings_menu.gd`
- Modify: `scripts/ui/skill_screen.gd` (`_ready` ~83, `_on_scheme_changed` ~92, `close` ~107, `_process` ~237, `_unhandled_input` ~245, `_refresh` ~312)
- Modify: `autoload/controls.gd` (`BINDINGS` ~7, `PAD_BUTTONS` ~31)
- Test: `tests/test_audio_ui.gd`, `tests/test_menu_input.gd`

**Interfaces:**
- Consumes (existing, read):
  - `SkillScreenModel.sound_rows(settings) -> Array` (`scripts/ui/skill_screen_model.gd:228`);
  - `Audio.adjust_setting(key: String, direction: int)` (`autoload/audio.gd:71`);
  - `Audio.settings.values`, `.dirty`, and the save on `menu_closed` (`autoload/audio.gd:142-145`);
  - `SkillScreen` colour and font constants (`scripts/ui/skill_screen.gd:31-44`).
- Produces:
  - `SettingsMenu` (extends `Control`): `open()`, `close()`, `is_open() -> bool`, `move(delta: int)`, `adjust(direction: int)`, `selected_id() -> String`, `rows() -> Array`, `hint_text() -> String`, `redraw()`, `handle(event: InputEvent) -> bool`;
  - `SkillScreen.settings_menu: SettingsMenu`, `SkillScreen.open_settings()`, `SkillScreen.settings_hint() -> String`;
  - the `settings` input action (Tab, R3).

- [ ] **Step 1: Write the failing tests**

In `tests/test_audio_ui.gd`, change `after_each` to reset the pad helper:

```gdscript
func after_each() -> void:
	EventBus.world_event.disconnect(_record)
	PadInput.reset()
	get_tree().paused = false
	Audio.settings = AudioSettings.new()
	Audio.settings.apply()
```

Replace `test_the_sound_tab_lists_four_sliders_and_adjusts_the_selected_one`, `test_a_changed_slider_is_saved_when_the_screen_closes` and `test_every_control_on_the_sound_tab_stays_on_the_screen` with this block. Leave the other tests in the file alone for now; Task 2 changes them.

```gdscript
# --- the Settings menu (the sliders that were the Sound tab) ---

func test_the_settings_key_opens_the_menu_over_the_tabs_and_back_returns_to_the_same_tab() -> void:
	screen.open()
	screen.switch_tab(2)
	var before := screen.tab()
	PadInput.key(KEY_TAB)
	assert_true(screen.settings_menu.is_open())
	assert_true(screen.is_open(), "the menu sits on top of the tabs")
	PadInput.key(KEY_BACKSPACE)
	assert_false(screen.settings_menu.is_open())
	assert_true(screen.is_open())
	assert_eq(screen.tab(), before)

func test_r3_opens_the_menu_and_b_closes_only_the_menu() -> void:
	screen.open()
	PadInput.button(JOY_BUTTON_RIGHT_STICK)
	assert_true(screen.settings_menu.is_open())
	PadInput.button(JOY_BUTTON_B)
	assert_false(screen.settings_menu.is_open())
	assert_true(screen.is_open())
	assert_true(get_tree().paused)

func test_esc_and_start_close_only_the_menu_and_send_no_menu_closed() -> void:
	screen.open()
	screen.open_settings()
	seen = []
	PadInput.key(KEY_ESCAPE)
	assert_false(screen.settings_menu.is_open())
	assert_true(screen.is_open(), "Esc backs out of the menu, not out of the pause screen")
	assert_true(get_tree().paused)
	assert_false(_names().has("menu_closed"), "Audio saves on menu_closed: the sub-menu must not send it")
	screen.open_settings()
	PadInput.button(JOY_BUTTON_START)
	assert_false(screen.settings_menu.is_open())
	assert_true(screen.is_open())

func test_the_settings_menu_lists_four_sliders_and_adjusts_the_selected_one() -> void:
	screen.open()
	screen.open_settings()
	assert_eq(screen.settings_menu.rows().map(func(r): return r["id"]), ["master", "music", "ambience", "sfx"])
	assert_almost_eq(Audio.settings.values["master"], 0.8, 0.0001)
	seen = []
	screen.settings_menu.adjust(1)
	assert_almost_eq(Audio.settings.values["master"], 0.9, 0.0001)
	assert_has(_names(), "menu_move")
	screen.settings_menu.move(1)
	screen.settings_menu.adjust(-1)
	assert_almost_eq(Audio.settings.values["music"], 0.7, 0.0001)

func test_keys_move_and_adjust_inside_the_menu_and_the_tabs_do_not_switch() -> void:
	screen.open()
	var before := screen.tab()
	screen.open_settings()
	PadInput.key(KEY_S)
	assert_eq(screen.settings_menu.selected_id(), "music")
	PadInput.key(KEY_D)
	assert_almost_eq(Audio.settings.values["music"], 0.9, 0.0001)
	PadInput.key(KEY_E)  # tab_next: swallowed while the menu is open
	assert_eq(screen.tab(), before)
	assert_true(screen.settings_menu.is_open())

func test_a_changed_slider_is_saved_when_the_screen_closes() -> void:
	screen.open()
	screen.open_settings()
	screen.settings_menu.adjust(-1)
	assert_true(Audio.settings.dirty)
	screen.close()
	assert_false(screen.settings_menu.is_open(), "closing the screen closes the menu too")
	assert_false(Audio.settings.dirty)

func test_every_control_in_the_settings_menu_stays_on_the_screen() -> void:
	screen.open()
	screen.open_settings()
	for c in screen.find_children("*", "Control", true, false):
		var r: Rect2 = c.get_global_rect()
		assert_true(r.position.x >= 0.0 and r.end.x <= 640.0 and r.position.y >= 0.0 and r.end.y <= 360.0, str(c.name, r))

func test_the_hints_name_the_settings_button_for_the_scheme() -> void:
	screen.open()
	assert_string_contains(screen.hint_text(), "Tab Settings")
	screen.open_settings()
	assert_string_contains(screen.settings_menu.hint_text(), "Esc Back")
	screen.settings_menu.close()
	Controls.using_joypad = true
	screen.open()  # refreshes with the pad's words
	assert_string_contains(screen.hint_text(), "R3 Settings")
```

In `tests/test_menu_input.gd`, add:

```gdscript
func test_the_settings_action_has_a_key_and_a_stick_click() -> void:
	Controls.ensure_actions()
	var evs := InputMap.action_get_events("settings")
	assert_true(evs.any(func(e): return e is InputEventKey and e.physical_keycode == KEY_TAB))
	assert_true(evs.any(func(e): return e is InputEventJoypadButton and e.button_index == JOY_BUTTON_RIGHT_STICK))
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tools/run_tests.sh audio_ui`
Expected: `FAIL: engine error or empty run`. The log shows a `Parse Error` that `open_settings()` / `settings_menu` is not found in base `SkillScreen`.

Run: `tools/run_tests.sh menu_input`
Expected: `FAIL: 1 of 5 failed` (`test_the_settings_action_has_a_key_and_a_stick_click`: the `settings` action has no events).

- [ ] **Step 3: Write the minimal implementation**

Create `scripts/ui/settings_menu.gd`:

```gdscript
class_name SettingsMenu
extends Control
## The Settings menu: opened from the pause screen (Tab / R3), drawn over the tabs, and closed back to the same tab (Esc,
## Backspace, B, Start, or the Settings button again). It holds the Sound sliders. Built in code for 640x360.

const BOX := Rect2(150, 70, 340, 200)
const ROW_TOP := 110.0
const ROW_PITCH := 30.0

var _rows: Array = []
var _sel := 0
var _open := false
var _body := Control.new()
var _hint := ""

func _ready() -> void:
	visible = false
	var shade := ColorRect.new()
	shade.color = SkillScreen.COL_DIM_BG
	shade.size = Vector2(640, 360)
	add_child(shade)  # stops clicks: nothing under the menu can be clicked while it is open
	add_child(_body)

func is_open() -> bool:
	return _open

func open() -> void:
	_open = true
	_sel = 0
	visible = true
	redraw()

func close() -> void:
	_open = false
	visible = false

func rows() -> Array:
	return _rows.duplicate(true)

func selected_id() -> String:
	return "" if _rows.is_empty() else str(_rows[_sel]["id"])

func hint_text() -> String:
	return _hint

func move(delta: int) -> void:
	if not _open or _rows.is_empty():
		return
	var before := _sel
	_sel = clampi(_sel + delta, 0, _rows.size() - 1)
	if _sel != before:
		EventBus.world_event.emit("menu_move", {})
	redraw()

## Changes the selected slider by one step (direction is -1 or +1).
func adjust(direction: int) -> void:
	if not _open or _rows.is_empty():
		return
	Audio.adjust_setting(selected_id(), direction)
	EventBus.world_event.emit("menu_move", {})
	redraw()

## The menu's share of input while it is open: true when it used the event.
func handle(event: InputEvent) -> bool:
	if event.is_action_pressed("settings") or event.is_action_pressed("menu") or event.is_action_pressed("menu_back") \
			or event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("aim_up"):
		move(-1)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("aim_down"):
		move(1)
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		adjust(-1)
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		adjust(1)
	else:
		return false
	return true

## Rebuilds the menu from the current settings (and the scheme, for the hint line).
func redraw() -> void:
	_rows = SkillScreenModel.sound_rows(Audio.settings)
	_sel = clampi(_sel, 0, _rows.size() - 1)
	for c in _body.get_children():
		c.free()
	var x := BOX.position.x
	_panel(BOX.position, BOX.size, SkillScreen.COL_BG, 2)
	_text("SETTINGS", Vector2(x + 12, BOX.position.y + 8), Vector2(200, 16), SkillScreen.FONT_BIG, SkillScreen.COL_TITLE)
	_text("Sound", Vector2(x + 12, BOX.position.y + 26), Vector2(200, 12), SkillScreen.FONT_SMALL, SkillScreen.COL_DIM)
	var y := ROW_TOP
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		if i == _sel:
			_panel(Vector2(x + 6, y - 5), Vector2(BOX.size.x - 12, 24), SkillScreen.COL_SELECTED, 1)
		_text(r["name"], Vector2(x + 14, y), Vector2(80, 14), SkillScreen.FONT_MAIN, Color.WHITE)
		_rect(Vector2(x + 100, y + 3), Vector2(170, 8), Color(0.1, 0.12, 0.2))
		_rect(Vector2(x + 100, y + 3), Vector2(170.0 * clampf(r["value"], 0.0, 1.0), 8), SkillScreen.COL_PIP_ON)
		_text("%d%%" % int(round(r["value"] * 100.0)), Vector2(x + 280, y), Vector2(50, 14), SkillScreen.FONT_MAIN, SkillScreen.COL_DIM)
		y += ROW_PITCH
	_hint = "Up/Down Choose    Left/Right Adjust    B Back" if Controls.using_joypad else "W/S Choose    A/D Adjust    Esc Back"
	var h := _text(_hint, Vector2(x, BOX.end.y - 18), Vector2(BOX.size.x, 12), SkillScreen.FONT_SMALL, SkillScreen.COL_DIM)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _panel(pos: Vector2, box_size: Vector2, color: Color, border: int) -> void:
	var p := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = SkillScreen.COL_BORDER
	style.set_border_width_all(border)
	style.set_corner_radius_all(3)
	p.add_theme_stylebox_override("panel", style)
	p.position = pos
	p.size = box_size
	_body.add_child(p)

func _rect(pos: Vector2, box_size: Vector2, color: Color) -> void:
	var r := ColorRect.new()
	r.color = color
	r.position = pos
	r.size = box_size
	_body.add_child(r)

func _text(text: String, pos: Vector2, box_size: Vector2, font: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", color)
	l.clip_text = true
	_body.add_child(l)
	l.size = box_size
	return l
```

In `autoload/controls.gd`, add an entry to `BINDINGS`, after `"menu_back": [KEY_BACKSPACE],`:

```gdscript
	"settings": [KEY_TAB],
```

Then add an entry to `PAD_BUTTONS`, after `"menu_back": [JOY_BUTTON_B],`:

```gdscript
	"settings": [JOY_BUTTON_RIGHT_STICK],
```

In `scripts/ui/skill_screen.gd`, make the following edits.

1. Add the menu beside the other member `var`s (after `var _nav_timer := 0.0`):

```gdscript
## The Settings menu: a child drawn over the tabs (see open_settings()).
var settings_menu := SettingsMenu.new()
```

2. In `_ready()`, after `_build_frame()`, add it last so it draws on top:

```gdscript
	add_child(settings_menu)
```

3. Replace `_on_scheme_changed()` with:

```gdscript
func _on_scheme_changed() -> void:
	if visible:
		_refresh()
	if settings_menu.is_open():
		settings_menu.redraw()
```

4. In `close()`, add `settings_menu.close()` as the first line, so the function reads:

```gdscript
func close() -> void:
	settings_menu.close()
	_armed = ""
	visible = false
	get_tree().paused = false
	EventBus.world_event.emit("menu_closed", {})
```

5. Add these two functions after `toggle()`:

```gdscript
## Opens the Settings menu over the tabs (only while the screen is open); closing it returns to the same tab.
func open_settings() -> void:
	if not visible or settings_menu.is_open():
		return
	settings_menu.open()
	EventBus.world_event.emit("menu_move", {})

## The Settings button's name for the scheme in use; every tab's hint line ends with it.
func settings_hint() -> String:
	return "R3 Settings" if Controls.using_joypad else "Tab Settings"
```

6. Replace `_process()` with:

```gdscript
func _process(delta: float) -> void:
	if not visible:
		_nav_dir = 0
		return
	var step := nav_step(Controls.last_stick.y, delta)
	if step == 0:
		return
	if settings_menu.is_open():
		settings_menu.move(step)
	else:
		move(step)
```

7. In `_unhandled_input()`, insert this block as the first statement of the function, before the `menu` check:

```gdscript
	if visible and settings_menu.is_open():
		if not (event is InputEventJoypadMotion):  # the stick is read in _process
			settings_menu.handle(event)
		get_viewport().set_input_as_handled()
		return
```

Then add this branch directly after the `tab_next` branch:

```gdscript
	elif event.is_action_pressed("settings"):
		open_settings()
```

8. Rename the existing `func _refresh() -> void:` to `func _refresh_tab() -> void:` (body unchanged), and add the new `_refresh()` directly above it:

```gdscript
## Rebuilds the open tab, then ends its hint line with the Settings button.
func _refresh() -> void:
	_refresh_tab()
	if _player != null:
		_hint.text += "    " + settings_hint()
```

9. Update the class doc comment's second line to mention the menu:

```gdscript
## Great Sage skill window (Style D): Skills, Compendium, Bestiary, Map and Sound tabs, stats, grouped list and a
## detail card. Esc / Start opens it and pauses the game; Q/E or LB/RB switch tabs; Tab / R3 opens the Settings menu;
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `gtimeout -k 5 180 env HOME="$PWD/.tmp/gdhome" godot --headless --import > .tmp/test-logs/import.log 2>&1; tools/run_tests.sh audio_ui && tools/run_tests.sh menu_input && tools/run_tests.sh skill_screen && tools/run_tests.sh levels`
Expected: four `PASS: <n> tests` lines. `test_levels.gd:143` still finds "Evolve" in the hint, which now ends with "Tab Settings".

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/settings_menu.gd scripts/ui/settings_menu.gd.uid scripts/ui/skill_screen.gd autoload/controls.gd tests/test_audio_ui.gd tests/test_menu_input.gd
git commit -m "feat(ui): a Settings menu on the pause screen holds the sound sliders"
```

### Task 2: The Tree tab takes the Sound tab's place in the strip

`TABS` must hold five entries at every commit: `tab_layout` tests `n <= TABS.size()` (`scripts/ui/skill_screen.gd:130`), and `test_form_tab.gd:72` pins `tab_layout(5)`. So Sound leaves and Tree arrives in one commit. The Tree tab is empty until Task 9.

**Files:**
- Modify: `scripts/ui/skill_screen.gd` (`TABS` :8, `adjust` :186-192, the Sound branch of `_refresh_tab` :333-344, `_unhandled_input` :265-268, `_build_sound` :607-617)
- Test: `tests/test_skill_screen.gd`, `tests/test_audio_ui.gd`, `tests/test_map.gd`

**Interfaces:**
- Consumes: `SkillScreen._refresh_tab()` and `settings_menu` (Task 1).
- Produces: `SkillScreen.TABS == ["skills", "tree", "compendium", "bestiary", "map"]`. `tab() == "tree"` at index 1. `SkillScreen.adjust` and `_build_sound` are removed.

- [ ] **Step 1: Write the failing tests (the tab-index churn)**

In `tests/test_skill_screen.gd`:
- in `test_compendium_tab_shows_unknown_slots`, change `screen.switch_tab(1)` to `screen.switch_tab(2)`;
- in `test_bestiary_tab_lists_creatures_and_shows_a_card`, change `screen.switch_tab(2)` to `screen.switch_tab(3)`;
- replace `test_tabs_cycle_through_all_five` with:

```gdscript
func test_tabs_cycle_through_all_five() -> void:
	_screen()
	screen.open()
	screen.switch_tab(1)
	assert_eq(screen.tab(), "tree")
	screen.switch_tab(4)
	assert_eq(screen.tab(), "map")
	screen.switch_tab(5)
	assert_eq(screen.tab(), "skills")
	screen.switch_tab(-1)
	assert_eq(screen.tab(), "map")

func test_the_tree_tab_is_second_and_accept_on_it_assigns_nothing() -> void:
	_screen()
	screen.open()
	screen.switch_tab(1)
	assert_eq(screen.tab(), "tree")
	var slots_before: Array = player.skillset.slots.slots.duplicate()
	screen.accept()
	assert_eq(player.skillset.slots.slots, slots_before)
	assert_true(screen.is_open())
```

In `tests/test_audio_ui.gd`, replace `test_there_are_five_tabs_and_the_wrap_includes_sound` with the test below, and delete `test_adjust_does_nothing_off_the_sound_tab` (`adjust` leaves the screen; the menu's own `adjust` is tested in Task 1):

```gdscript
func test_there_are_five_tabs_and_sound_is_not_one_of_them() -> void:
	assert_eq(SkillScreen.TABS, ["skills", "tree", "compendium", "bestiary", "map"])
	screen.open()
	screen.switch_tab(5)
	assert_eq(screen.tab(), "skills")
	screen.switch_tab(-1)
	assert_eq(screen.tab(), "map")
```

In `tests/test_map.gd`, change both `screen.switch_tab(3)` calls (in `test_the_map_tab_draws_inside_the_screen` and `test_the_map_tab_without_a_world_says_so`) to `screen.switch_tab(4)`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tools/run_tests.sh skill_screen`
Expected: `FAIL: 4 of <n> failed`: the compendium, bestiary, cycle and tree tests read the old order ("compendium" where "tree" is expected, and so on).

Run: `tools/run_tests.sh map`
Expected: `FAIL: 1 of 3 failed` (`test_the_map_tab_draws_inside_the_screen`: tab is "sound", not "map").

- [ ] **Step 3: Write the minimal implementation**

In `scripts/ui/skill_screen.gd`, make the following edits.

1. Replace the `TABS` comment and constant:

```gdscript
## The five base tabs. A sixth, "form", joins once the body has evolved or can (see tabs()). Sound lives in the Settings menu.
const TABS := ["skills", "tree", "compendium", "bestiary", "map"]
```

2. Replace the class doc comment's first two lines:

```gdscript
## Great Sage skill window (Style D): Skills, Tree, Compendium, Bestiary and Map tabs, stats, grouped list and a
## detail card. Esc / Start opens it and pauses the game; Q/E or LB/RB switch tabs; Tab / R3 opens the Settings menu;
```

3. Delete the whole `adjust(direction: int)` function and its `## Sound tab: ...` comment.
4. Delete the whole `_build_sound()` function.
5. In `_unhandled_input`, delete these four lines (left and right do nothing on the list tabs; Task 9 gives them to the tree):

```gdscript
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		adjust(-1)
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		adjust(1)
```

6. In `_refresh_tab`, replace the whole `if tab() == "sound":` block (through its `return`) with:

```gdscript
	if tab() == "tree":
		_rows = []
		_selectable = []
		_hint.text = "LB/RB Tabs    B Back" if Controls.using_joypad else "Q/E Tabs    Esc Back"
		_build_stats()
		_clear(_list)
		_clear(_detail)
		_label(_list, "TREE", Vector2(LIST_X + 4, LIST_TOP + 2), Vector2(200, 12), FONT_SMALL, COL_TITLE)
		return
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `tools/run_tests.sh skill_screen && tools/run_tests.sh audio_ui && tools/run_tests.sh map && tools/run_tests.sh form_tab && tools/run_tests.sh evolution_screen`
Expected: five `PASS: <n> tests` lines. `test_form_tab` and `test_evolution_screen` pass unedited.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/skill_screen.gd tests/test_skill_screen.gd tests/test_audio_ui.gd tests/test_map.gd
git commit -m "feat(ui): the Tree tab takes the Sound tab's place in the strip"
```

---

## Step 1: the power graph

### Task 3: The stick step takes both axes

**Files:**
- Modify: `scripts/ui/skill_screen.gd` (`_nav_dir` :68, `nav_step` :216-235, `_process`)
- Test: `tests/test_menu_input.gd`

**Interfaces:**
- Consumes: `Controls.last_stick: Vector2` (`autoload/controls.gd:88`); `settings_menu` (Task 1).
- Produces: `SkillScreen.nav_step(stick: Vector2, delta: float) -> Vector2i`. It returns `Vector2i.ZERO`, `UP`, `DOWN`, `LEFT` or `RIGHT`: the dominant axis past `NAV_THRESHOLD`, edge-triggered, then repeating after `NAV_DELAY` every `NAV_REPEAT`. `_nav_dir` becomes a `Vector2i`.

- [ ] **Step 1: Write the failing tests**

In `tests/test_menu_input.gd`, change `after_each` to:

```gdscript
func after_each() -> void:
	Controls.last_stick = Vector2.ZERO
	get_tree().paused = false
```

Replace `test_one_stick_push_is_one_step_then_it_repeats_slowly` with these three tests:

```gdscript
func test_one_stick_push_is_one_step_then_it_repeats_slowly() -> void:
	var down := Vector2(0.0, 0.9)
	assert_eq(screen.nav_step(Vector2(0.0, 0.8), 0.016), Vector2i.DOWN)
	assert_eq(screen.nav_step(down, 0.016), Vector2i.ZERO)
	assert_eq(screen.nav_step(down, 0.2), Vector2i.ZERO)
	assert_eq(screen.nav_step(down, 0.2), Vector2i.DOWN)  # held past the delay: repeat
	assert_eq(screen.nav_step(down, 0.05), Vector2i.ZERO)
	assert_eq(screen.nav_step(down, 0.1), Vector2i.DOWN)
	assert_eq(screen.nav_step(Vector2(0.0, 0.1), 0.016), Vector2i.ZERO)  # released
	assert_eq(screen.nav_step(Vector2(0.0, -0.7), 0.016), Vector2i.UP)

func test_the_step_is_the_dominant_axis_in_all_four_directions() -> void:
	var cases := {Vector2(0.9, 0.2): Vector2i.RIGHT, Vector2(-0.8, 0.3): Vector2i.LEFT,
		Vector2(0.1, -0.9): Vector2i.UP, Vector2(-0.2, 0.7): Vector2i.DOWN}
	for stick in cases:
		screen.nav_step(Vector2.ZERO, 0.016)  # release between pushes
		assert_eq(screen.nav_step(stick, 0.016), cases[stick], str(stick))
	screen.nav_step(Vector2.ZERO, 0.016)
	assert_eq(screen.nav_step(Vector2(0.3, 0.3), 0.016), Vector2i.ZERO, "inside the threshold on both axes")

func test_a_diagonal_push_still_moves_a_list_and_a_sideways_push_does_not() -> void:
	rules.grant("leap")  # with Appraisal: two selectable rows on the Skills tab
	screen.open()
	var first := screen.selected_id()
	Controls.last_stick = Vector2(0.9, 0.1)
	screen._process(0.016)
	assert_eq(screen.selected_id(), first, "the lists read only the vertical part")
	Controls.last_stick = Vector2.ZERO
	screen._process(0.016)
	Controls.last_stick = Vector2(0.8, 0.6)
	screen._process(0.016)
	assert_ne(screen.selected_id(), first, "a diagonal push moves the list down, as it did before")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tools/run_tests.sh menu_input`
Expected: `FAIL: engine error or empty run`. The log shows a `Parse Error` that argument 1 of `nav_step()` should be "float" but is "Vector2".

- [ ] **Step 3: Write the minimal implementation**

In `scripts/ui/skill_screen.gd`, change `var _nav_dir := 0` to:

```gdscript
var _nav_dir := Vector2i.ZERO
```

Replace the `nav_step` comment and function with:

```gdscript
## The selection step for a stick reading: the dominant axis past NAV_THRESHOLD as a four-way direction (Vector2i.UP is up),
## edge-triggered, then slow repeats while held. Stick motion arrives as a stream of events, so reading it per event skipped rows.
func nav_step(stick: Vector2, delta: float) -> Vector2i:
	var dir := Vector2i.ZERO
	if maxf(absf(stick.x), absf(stick.y)) >= NAV_THRESHOLD:
		dir = Vector2i(int(signf(stick.x)), 0) if absf(stick.x) > absf(stick.y) else Vector2i(0, int(signf(stick.y)))
	if dir == Vector2i.ZERO:
		_nav_dir = Vector2i.ZERO
		return dir
	if dir != _nav_dir:
		_nav_dir = dir
		_nav_timer = NAV_DELAY
		return dir
	_nav_timer -= delta
	if _nav_timer <= 0.0:
		_nav_timer = NAV_REPEAT
		return dir
	return Vector2i.ZERO
```

Replace `_process()` with:

```gdscript
func _process(delta: float) -> void:
	if not visible:
		_nav_dir = Vector2i.ZERO
		return
	# The lists read only the vertical part, so a diagonal push still moves a list.
	var step := nav_step(Vector2(0.0, Controls.last_stick.y), delta)
	if step.y == 0:
		return
	if settings_menu.is_open():
		settings_menu.move(step.y)
	else:
		move(step.y)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `tools/run_tests.sh menu_input && tools/run_tests.sh audio_ui`
Expected: two `PASS: <n> tests` lines.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/skill_screen.gd tests/test_menu_input.gd
git commit -m "feat(ui): the menu stick step reads both axes and returns a direction"
```

### Task 4: `SkillTreeModel`: power and evolution nodes, their states and edges

**Files:**
- Create: `scripts/ui/skill_tree_model.gd`
- Test: `tests/test_skill_tree_model.gd` (create)

**Interfaces:**
- Consumes (existing):
  - `CompendiumModel.states() -> Dictionary` (one key per non-enemy skill), `state(id) -> int`, `raise(id, state)`, and the `State` enum (`scripts/compendium/compendium_model.gd:8,37,40,43`);
  - `SkillRulesEngine.get_def(id)`, `owned()`, `is_retired(id)`, `is_closed(id)` and `is_evolution_ready(id)` (`scripts/skills/skill_rules_engine.gd:92-124`);
  - `SkillScreenModel.condition_text(d, by_id) -> String` (`scripts/ui/skill_screen_model.gd:164`);
  - `TestDefs.skill`, `.counter` and `.level` (`tests/support/test_defs.gd`).
- Consumes, from the essence overhaul plan: `SkillDef.evolution_price`. It is set only on the test fixture's base power, so that `evolve()` can pay in `_fixture_rules()`.
- Produces:
  - `SkillTreeModel.build(rules, compendium: CompendiumModel, forms: Dictionary, reached_forms: Array, current_form: String) -> Dictionary`. It returns `{"nodes": {id: node}, "edges": [edge]}`.
  - A node is `{"id", "kind" ("power" | "evolution"), "state"}`. Unless it is a stub, it also carries `"name"`, plus `"hint"` (Compendium Hinted or more) and `"condition"` (Owned-once only).
  - An edge is `{"from", "to", "kind" ("evolves"), "known": bool}`.
  - The state constants `OWNED`, `NAMED`, `RETIRED`, `CLOSED`, `READY`, `CURRENT`, `REACHED` and `STUB` (Strings).
  - `forms`, `reached_forms` and `current_form` are accepted now and read from Task 15 on.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_skill_tree_model.gd`:

```gdscript
extends GutTest
## The Tree tab's pure model: which powers, evolutions and forms show, in what state, joined by which edges, and where.

var skills: Array
var rules: SkillRulesEngine
var compendium: CompendiumModel
var by_id := {}

func before_each() -> void:
	skills = DefLoader.load_dir("res://data/skills")
	by_id = {}
	for d in skills:
		by_id[d.id] = d
	var creature_list := DefLoader.load_dir("res://data/creatures")
	rules = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	compendium = CompendiumModel.new(skills, creature_list)
	CoreWiring.connect_core(rules, compendium, AnnouncerQueue.new())
	rules.start_run()

func _build(forms := {}, reached: Array = [], current := "slime") -> Dictionary:
	return SkillTreeModel.build(rules, compendium, forms, reached, current)

func _discover_all() -> void:
	for id in compendium.states():
		compendium.raise(id, CompendiumModel.State.OWNED_ONCE)

func _player_skill_ids() -> Array:
	var out: Array = []
	for d in skills:
		if d.source != "enemy_only":
			out.append(d.id)
	out.sort()
	return out

## A base power with two evolutions, levelled until both are ready. Its price is water 2 and it holds water 1.
func _fixture_rules() -> SkillRulesEngine:
	var hydro := TestDefs.skill("hydraulic_propulsion", {"source": "essence",
		"unlock": [TestDefs.counter("absorbed", 1, {"essence": "water"})],
		"levels_on": {"event": "skill_used", "tags": {"id": "hydraulic_propulsion"}}, "level_curve": 2, "max_level": 8,
		"evolution_price": {"water": 2}})
	var evo := {"source": "evolution", "replaces": "hydraulic_propulsion", "unlock": [TestDefs.level("hydraulic_propulsion", 2)]}
	var defs := [hydro, TestDefs.skill("blade", evo.duplicate(true)), TestDefs.skill("dash", evo.duplicate(true))]
	var r: SkillRulesEngine = autofree(SkillRulesEngine.new())
	r.setup(defs)
	compendium = CompendiumModel.new(defs, [])
	CoreWiring.connect_core(r, compendium, AnnouncerQueue.new())
	r.start_run()
	for d in defs:
		compendium.raise(d.id, CompendiumModel.State.OWNED_ONCE)
	r.handle_event("absorbed", {"essence": "water"})
	for i in 2:
		r.handle_event("skill_used", {"id": "hydraulic_propulsion"})
	return r

func _fixture_defs() -> Dictionary:
	var out := {}
	for id in ["hydraulic_propulsion", "blade", "dash"]:
		out[id] = rules.get_def(id)
	return out

# --- nodes, states and edges ---

func test_fully_discovered_every_player_skill_is_a_node_of_its_kind() -> void:
	_discover_all()
	var nodes: Dictionary = _build()["nodes"]
	var ids := nodes.keys()
	ids.sort()
	assert_eq(ids, _player_skill_ids())
	for id in nodes:
		assert_eq(nodes[id]["kind"], "evolution" if by_id[id].source == "evolution" else "power", id)
		assert_eq(nodes[id]["name"], by_id[id].display_name, id)

func test_every_evolution_has_exactly_one_parent_edge() -> void:
	_discover_all()
	var edges: Array = _build()["edges"]
	for d in skills:
		if d.source != "evolution":
			continue
		var into := edges.filter(func(e): return e["to"] == d.id)
		assert_eq(into.size(), 1, d.id)
		assert_eq(into[0]["from"], d.replaces, d.id)
		assert_eq(into[0]["kind"], "evolves", d.id)
		assert_true(into[0]["known"], d.id)

func test_a_new_soul_shows_only_its_starting_power() -> void:
	var m := _build()
	assert_eq(m["nodes"].keys(), ["appraisal"])
	assert_eq(m["nodes"]["appraisal"]["state"], SkillTreeModel.OWNED)
	assert_eq(m["edges"], [])

func test_an_unknown_evolution_of_an_owned_once_power_is_a_nameless_stub() -> void:
	compendium.raise("hydraulic_propulsion", CompendiumModel.State.OWNED_ONCE)
	var m := _build()
	for id in ["water_blade", "jet_dash"]:
		var n: Dictionary = m["nodes"][id]
		assert_eq(n["state"], SkillTreeModel.STUB, id)
		assert_eq(n.keys().filter(func(k): return k in ["name", "hint", "condition"]), [], "a stub carries no name and no ingredients")
	var edge: Array = m["edges"].filter(func(e): return e["to"] == "water_blade")
	assert_eq(edge.size(), 1)
	assert_false(edge[0]["known"], "an edge to a stub is drawn dim")

func test_a_merely_named_power_reveals_no_branches() -> void:
	compendium.raise("poison_breath", CompendiumModel.State.NAMED)
	var m := _build()
	assert_eq(m["nodes"]["poison_breath"]["state"], SkillTreeModel.NAMED)
	assert_false(m["nodes"]["poison_breath"].has("condition"))
	assert_false(m["nodes"].has("miasma"))
	assert_false(m["nodes"].has("venom_bolt"))
	assert_eq(m["edges"], [])

func test_an_edge_to_an_absent_parent_is_dropped() -> void:
	compendium.raise("miasma", CompendiumModel.State.NAMED)
	var m := _build()
	assert_eq(m["nodes"]["miasma"]["state"], SkillTreeModel.NAMED)
	assert_false(m["nodes"].has("poison_breath"))
	assert_eq(m["edges"], [], "never left dangling")

func test_only_owned_once_carries_the_condition() -> void:
	assert_ne(by_id["leap"].hint, "")
	compendium.raise("leap", CompendiumModel.State.HINTED)
	compendium.raise("wall_cling", CompendiumModel.State.OWNED_ONCE)
	var nodes: Dictionary = _build()["nodes"]
	assert_eq(nodes["leap"]["state"], SkillTreeModel.NAMED)
	assert_eq(nodes["leap"]["hint"], by_id["leap"].hint)
	assert_false(nodes["leap"].has("condition"))
	assert_eq(nodes["wall_cling"]["condition"], SkillScreenModel.condition_text(by_id["wall_cling"], by_id))
	assert_ne(nodes["wall_cling"]["condition"], "")

func test_a_secret_skill_leaves_no_trace_until_owned_once() -> void:
	assert_true(by_id["glutton"].secret)
	for st in [CompendiumModel.State.NAMED, CompendiumModel.State.HINTED]:
		compendium.raise("glutton", st)
		assert_false(_build()["nodes"].has("glutton"), str(st))
	compendium.raise("glutton", CompendiumModel.State.OWNED_ONCE)
	assert_true(_build()["nodes"].has("glutton"))

func test_every_edge_ends_on_a_visible_node_at_every_stage_of_discovery() -> void:
	var steps := [func(): pass,
		func(): compendium.raise("hydraulic_propulsion", CompendiumModel.State.OWNED_ONCE),
		func(): compendium.raise("miasma", CompendiumModel.State.NAMED),
		func(): _discover_all()]
	for step in steps:
		step.call()
		var m := _build()
		for e in m["edges"]:
			assert_true(m["nodes"].has(e["from"]) and m["nodes"].has(e["to"]), str(e))

func test_ready_retired_and_closed_come_from_the_engine() -> void:
	rules = _fixture_rules()
	var nodes: Dictionary = _build()["nodes"]
	assert_eq(nodes["hydraulic_propulsion"]["state"], SkillTreeModel.OWNED)
	assert_eq([nodes["blade"]["state"], nodes["dash"]["state"]], [SkillTreeModel.READY, SkillTreeModel.READY])
	rules.handle_event("absorbed", {"essence": "water"})  # the price is water 2
	assert_true(rules.evolve("blade"))
	nodes = _build()["nodes"]
	assert_eq(nodes["hydraulic_propulsion"]["state"], SkillTreeModel.RETIRED)
	assert_eq(nodes["blade"]["state"], SkillTreeModel.OWNED)
	assert_eq(nodes["dash"]["state"], SkillTreeModel.CLOSED)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `gtimeout -k 5 180 env HOME="$PWD/.tmp/gdhome" godot --headless --import > .tmp/test-logs/import.log 2>&1; tools/run_tests.sh skill_tree_model`
Expected: `FAIL: engine error or empty run`. The log shows `Parse Error: Identifier "SkillTreeModel" not declared in the current scope.`

- [ ] **Step 3: Write the minimal implementation**

Create `scripts/ui/skill_tree_model.gd`:

```gdscript
class_name SkillTreeModel
extends RefCounted
## Pure data for the Tree tab: the nodes (powers, their evolutions and the body forms), the edges that join them, and
## where each one sits. No scene code: SkillTreeView draws it. A node is {"id", "kind", "state"} and, unless it is a stub,
## its "name", plus "hint" and "condition" as far as the Compendium state allows.

const OWNED := "owned"
const NAMED := "named"
const RETIRED := "retired"
const CLOSED := "closed"
const READY := "ready"
const CURRENT := "current"
const REACHED := "reached"
const STUB := "stub"

## {"nodes": {id: node}, "edges": [{"from", "to", "kind", "known"}]}. Every edge joins two nodes in "nodes".
static func build(rules, compendium: CompendiumModel, forms: Dictionary, reached_forms: Array, current_form: String) -> Dictionary:
	var defs := _skill_defs(rules, compendium)
	var by_id := {}
	for d in defs:
		by_id[d.id] = d
	var nodes := {}
	for d in defs:
		var n := _skill_node(rules, compendium, d, by_id)
		if not n.is_empty():
			nodes[d.id] = n
	var edges: Array = []
	for d in defs:
		if d.source == "evolution" and d.replaces != "":
			edges.append({"from": d.replaces, "to": d.id, "kind": "evolves"})
	return {"nodes": nodes, "edges": _visible_edges(nodes, edges)}

## Every non-enemy skill, in id order: the Compendium keeps one slot for each.
static func _skill_defs(rules, compendium: CompendiumModel) -> Array:
	var ids: Array = compendium.states().keys()
	ids.sort()
	var out: Array = []
	for id in ids:
		var d: SkillDef = rules.get_def(id)
		if d != null:
			out.append(d)
	return out

## A skill's node, or {} when it does not show. It shows from Named, a secret one only from Owned-once, and an Unknown
## evolution of a power owned once is a nameless stub (a merely Named power reveals no branches).
static func _skill_node(rules, compendium: CompendiumModel, d: SkillDef, by_id: Dictionary) -> Dictionary:
	var kind := "evolution" if d.source == "evolution" else "power"
	var st := compendium.state(d.id)
	if d.secret and st < CompendiumModel.State.OWNED_ONCE:
		return {}
	if st == CompendiumModel.State.UNKNOWN:
		if kind == "evolution" and compendium.state(d.replaces) == CompendiumModel.State.OWNED_ONCE:
			return {"id": d.id, "kind": kind, "state": STUB}
		return {}
	var n := {"id": d.id, "kind": kind, "state": _skill_state(rules, d.id), "name": d.display_name}
	if st >= CompendiumModel.State.HINTED and d.hint != "":
		n["hint"] = d.hint
	if st == CompendiumModel.State.OWNED_ONCE:
		n["condition"] = SkillScreenModel.condition_text(d, by_id)
	return n

## The state the engine gives a shown skill, read as the Skills tab reads it.
static func _skill_state(rules, id: String) -> String:
	if rules.is_retired(id):
		return RETIRED
	if rules.owned().has(id):
		return OWNED
	if rules.is_closed(id):
		return CLOSED
	if rules.is_evolution_ready(id):
		return READY
	return NAMED

## The edges whose two ends are both nodes, each marked known unless one end is a stub (an edge to a stub is drawn dim).
static func _visible_edges(nodes: Dictionary, edges: Array) -> Array:
	var out: Array = []
	for e in edges:
		if nodes.has(e["from"]) and nodes.has(e["to"]):
			out.append({"from": e["from"], "to": e["to"], "kind": e["kind"],
				"known": nodes[e["from"]]["state"] != STUB and nodes[e["to"]]["state"] != STUB})
	return out
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `gtimeout -k 5 180 env HOME="$PWD/.tmp/gdhome" godot --headless --import > .tmp/test-logs/import.log 2>&1; tools/run_tests.sh skill_tree_model`
Expected: `PASS: 10 tests`

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/skill_tree_model.gd scripts/ui/skill_tree_model.gd.uid tests/test_skill_tree_model.gd tests/test_skill_tree_model.gd.uid
git commit -m "feat(ui): the skill tree model's power and evolution nodes, states and edges"
```

### Task 5: The power band's layout

Positions are computed from the **full** tree minus the unowned secrets. A node never moves when another is discovered, and an undiscovered node leaves its slot empty.
- **Rows:** the powers that evolve, in id order for now (Task 15 orders them by lineage), each with its two evolutions in the next column.
- **Grid:** the other powers fill a two-column grid from column 2, by name. An owned secret takes the next cell after it, in id order.

Every edge runs from column 0 to column 1 (and, in Task 15, between adjacent form columns). So edges stay in the 14 px gaps between columns and never cross a label.

**Files:**
- Modify: `scripts/ui/skill_tree_model.gd`
- Test: `tests/test_skill_tree_model.gd`

**Interfaces:**
- Consumes: `SkillTreeModel.build` and `_skill_defs` (Task 4); `SkillScreen.FONT_SMALL` (`scripts/ui/skill_screen.gd:44`).
- Produces:
  - every node gains `"pos": Vector2` (top-left, canvas px at the normal zoom);
  - `build()` adds `"size": Vector2` (the canvas);
  - constants `NODE_SIZE := Vector2(104, 12)`, `LABEL_INSET := 3.0`, `COL_PITCH := 118.0`, `ROW_PITCH := 14.0`, `GRID_COLS := 2`;
  - private helpers `_row_powers(defs) -> Array`, `_evolutions_of(defs, id) -> Array`, `_power_slots(defs, row_powers, nodes) -> Dictionary` and `_canvas(slots) -> Vector2`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_skill_tree_model.gd`:

```gdscript
# --- layout ---

func _rects(m: Dictionary) -> Dictionary:
	var out := {}
	for id in m["nodes"]:
		out[id] = Rect2(m["nodes"][id]["pos"], SkillTreeModel.NODE_SIZE)
	return out

func _assert_no_overlap(rects: Dictionary) -> void:
	var ids := rects.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			assert_false(rects[ids[i]].intersects(rects[ids[j]]), "%s overlaps %s" % [ids[i], ids[j]])

func test_the_layout_is_deterministic_and_no_two_nodes_overlap() -> void:
	_discover_all()
	var a := _build()
	var ra := _rects(a)
	assert_eq(ra, _rects(_build()))
	_assert_no_overlap(ra)
	for id in ra:
		assert_true(Rect2(Vector2.ZERO, a["size"]).encloses(ra[id]), id + " is inside the canvas")

func test_discovering_a_node_never_moves_another() -> void:
	compendium.raise("hydraulic_propulsion", CompendiumModel.State.OWNED_ONCE)
	compendium.raise("leap", CompendiumModel.State.NAMED)
	var before := _rects(_build())
	_discover_all()
	var after := _rects(_build())
	for id in before:
		assert_eq(after[id], before[id], id)

func test_a_revealed_secret_takes_a_trailing_grid_cell_and_moves_nothing() -> void:
	for id in compendium.states():
		if id != "glutton":
			compendium.raise(id, CompendiumModel.State.OWNED_ONCE)
	var before := _rects(_build())
	assert_false(before.has("glutton"))
	compendium.raise("glutton", CompendiumModel.State.OWNED_ONCE)
	var after := _rects(_build())
	for id in before:
		assert_eq(after[id], before[id], id)
	var lowest := 0.0
	for id in before:
		if before[id].position.x >= 2.0 * SkillTreeModel.COL_PITCH:
			lowest = maxf(lowest, before[id].position.y)
	assert_gte(after["glutton"].position.y, lowest, "after every other grid power")

func test_the_evolving_powers_are_drawn_as_three_node_trees() -> void:
	_discover_all()
	var nodes: Dictionary = _build()["nodes"]
	for d in skills:
		if d.source != "evolution":
			continue
		var base: Vector2 = nodes[d.replaces]["pos"]
		var evo: Vector2 = nodes[d.id]["pos"]
		assert_eq(evo.x, base.x + SkillTreeModel.COL_PITCH, d.id + " sits one column right of its base")
		assert_true(evo.y >= base.y and evo.y <= base.y + SkillTreeModel.ROW_PITCH, d.id + " is level with its base or one row down")

func test_every_label_fits_its_node() -> void:
	_discover_all()
	var nodes: Dictionary = _build()["nodes"]
	var room := SkillTreeModel.NODE_SIZE.x - 2.0 * SkillTreeModel.LABEL_INSET
	for id in nodes:
		var w := ThemeDB.fallback_font.get_string_size(nodes[id]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, SkillScreen.FONT_SMALL).x
		assert_lte(w, room, nodes[id]["name"])
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tools/run_tests.sh skill_tree_model`
Expected: `FAIL: engine error or empty run`. The log shows `Parse Error` that `NODE_SIZE` / `COL_PITCH` is not found in `SkillTreeModel`.

- [ ] **Step 3: Write the minimal implementation**

In `scripts/ui/skill_tree_model.gd`, add after the state constants:

```gdscript
## Node size and spacing at the normal zoom, in canvas px. Every edge joins adjacent columns, so it runs in the gap between
## them and never crosses a label.
const NODE_SIZE := Vector2(104, 12)
const LABEL_INSET := 3.0
const COL_PITCH := 118.0
const ROW_PITCH := 14.0
const GRID_COLS := 2
```

Replace `build()` and its comment with:

```gdscript
## {"nodes": {id: node}, "edges": [{"from", "to", "kind", "known"}], "size": Vector2}. Every edge joins two nodes in "nodes";
## each node's "pos" is its top-left corner on the canvas at the normal zoom.
static func build(rules, compendium: CompendiumModel, forms: Dictionary, reached_forms: Array, current_form: String) -> Dictionary:
	var defs := _skill_defs(rules, compendium)
	var by_id := {}
	for d in defs:
		by_id[d.id] = d
	var nodes := {}
	for d in defs:
		var n := _skill_node(rules, compendium, d, by_id)
		if not n.is_empty():
			nodes[d.id] = n
	var edges: Array = []
	for d in defs:
		if d.source == "evolution" and d.replaces != "":
			edges.append({"from": d.replaces, "to": d.id, "kind": "evolves"})
	var slots := _power_slots(defs, _row_powers(defs), nodes)
	for id in nodes:
		nodes[id]["pos"] = slots[id]
	return {"nodes": nodes, "edges": _visible_edges(nodes, edges), "size": _canvas(slots)}
```

Add these functions at the end of the file:

```gdscript
## The powers drawn one per row, with their evolutions beside them: those that evolve, in id order.
static func _row_powers(defs: Array) -> Array:
	var out: Array = []
	for d in defs:
		if d.source != "evolution" and not _evolutions_of(defs, d.id).is_empty():
			out.append(d.id)
	return out

## The evolutions that replace `id`, in id order.
static func _evolutions_of(defs: Array, id: String) -> Array:
	var out: Array = []
	for d in defs:
		if d.source == "evolution" and d.replaces == id:
			out.append(d.id)
	return out

## A slot for every skill that can show, shown or not, so discovering one never moves another. The row powers go down
## column 0 with their evolutions in column 1; the other powers fill a GRID_COLS-wide grid from column 2, by name. A secret
## takes a slot only once it is a node, after the rest of the grid, in id order: a reserved empty cell would give it away.
static func _power_slots(defs: Array, row_powers: Array, nodes: Dictionary) -> Dictionary:
	var slots := {}
	var row := 0
	for id in row_powers:
		slots[id] = Vector2(0, row * ROW_PITCH)
		var kids := _evolutions_of(defs, id)
		for i in kids.size():
			slots[kids[i]] = Vector2(COL_PITCH, (row + i) * ROW_PITCH)
		row += maxi(1, kids.size())
	var grid := defs.filter(func(d): return d.source != "evolution" and not row_powers.has(d.id) and not d.secret)
	grid.sort_custom(func(a, b): return a.display_name < b.display_name)
	var secrets := defs.filter(func(d): return d.source != "evolution" and not row_powers.has(d.id) and d.secret and nodes.has(d.id))
	grid.append_array(secrets)  # defs are in id order already
	for i in grid.size():
		slots[grid[i].id] = Vector2((2 + i % GRID_COLS) * COL_PITCH, (i / GRID_COLS) * ROW_PITCH)
	return slots

## The canvas: just large enough for every slot.
static func _canvas(slots: Dictionary) -> Vector2:
	var out := Vector2.ZERO
	for id in slots:
		out = out.max(slots[id] + NODE_SIZE)
	return out
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `tools/run_tests.sh skill_tree_model`
Expected: `PASS: 15 tests`. If `test_every_label_fits_its_node` reports a name wider than the room, raise `NODE_SIZE.x` and `COL_PITCH` together by 4 until it passes. Never go past 108 and 122: a base and its branch, `COL_PITCH + NODE_SIZE.x`, must stay within the 244 px box.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/skill_tree_model.gd tests/test_skill_tree_model.gd
git commit -m "feat(ui): lay the power band out from the full tree so discoveries never move a node"
```

### Task 6: `root` and `neighbor`

**Files:**
- Modify: `scripts/ui/skill_tree_model.gd`
- Test: `tests/test_skill_tree_model.gd`

**Interfaces:**
- Consumes: the `"pos"` field and `NODE_SIZE` (Task 5).
- Produces:
  - `SkillTreeModel.root(model: Dictionary) -> String`: the top-left node (least y, then least x, then id), or `""` for an empty tree.
  - `SkillTreeModel.neighbor(model: Dictionary, id: String, dir: Vector2i) -> String`. It picks the nearest node joined to `id` by an edge lying within 45° of `dir`, else the nearest node in `dir`'s open half-plane, with ties broken by id. It returns `id` when nothing lies that way, or when `id` is not a node.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_skill_tree_model.gd`:

```gdscript
# --- navigation ---

func _walk(m: Dictionary) -> Dictionary:
	var start := SkillTreeModel.root(m)
	var seen := {start: true}
	var todo: Array = [start]
	while not todo.is_empty():
		var id: String = todo.pop_back()
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next := SkillTreeModel.neighbor(m, id, dir)
			if not seen.has(next):
				seen[next] = true
				todo.append(next)
	return seen

func test_walking_neighbor_from_the_root_reaches_every_node() -> void:
	var steps := [func(): pass,
		func(): compendium.raise("hydraulic_propulsion", CompendiumModel.State.OWNED_ONCE),
		func(): _discover_all()]
	for step in steps:
		step.call()
		var m := _build()
		var seen := _walk(m)
		for id in m["nodes"]:
			assert_true(seen.has(id), "%s is reachable from %s" % [id, SkillTreeModel.root(m)])

func test_neighbor_prefers_an_edge_and_stays_put_at_the_border() -> void:
	_discover_all()
	var m := _build()
	var right := SkillTreeModel.neighbor(m, "hydraulic_propulsion", Vector2i.RIGHT)
	assert_true(["water_blade", "jet_dash"].has(right), "an evolution, joined by an edge, first: got " + right)
	var top_left := SkillTreeModel.root(m)
	assert_eq(SkillTreeModel.neighbor(m, top_left, Vector2i.UP), top_left, "nothing above the top row")
	assert_eq(SkillTreeModel.neighbor(m, top_left, Vector2i.LEFT), top_left, "nothing left of column 0")
	assert_eq(SkillTreeModel.neighbor(m, "no_such_node", Vector2i.DOWN), "no_such_node")

func test_root_is_the_top_left_node() -> void:
	_discover_all()
	var m := _build()
	var r := SkillTreeModel.root(m)
	var rp: Vector2 = m["nodes"][r]["pos"]
	for id in m["nodes"]:
		var p: Vector2 = m["nodes"][id]["pos"]
		assert_true(rp.y < p.y or (rp.y == p.y and rp.x <= p.x), id)
	assert_eq(SkillTreeModel.root({"nodes": {}, "edges": [], "size": Vector2.ZERO}), "")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tools/run_tests.sh skill_tree_model`
Expected: `FAIL: engine error or empty run`. The log shows `Parse Error` that static function `root()` / `neighbor()` is not found in `SkillTreeModel`.

- [ ] **Step 3: Write the minimal implementation**

Add to the end of `scripts/ui/skill_tree_model.gd`:

```gdscript
## Where the selection starts: the top-left node ("" for an empty tree). Every node can be reached from it by neighbor().
static func root(model: Dictionary) -> String:
	var best := ""
	for id in model["nodes"]:
		if best == "" or _before(model["nodes"][id], model["nodes"][best], id, best):
			best = id
	return best

static func _before(a: Dictionary, b: Dictionary, a_id: String, b_id: String) -> bool:
	var pa: Vector2 = a["pos"]
	var pb: Vector2 = b["pos"]
	if pa.y != pb.y:
		return pa.y < pb.y
	if pa.x != pb.x:
		return pa.x < pb.x
	return a_id < b_id

## The node a move in `dir` (Vector2i.UP is up) selects from `id`. It is the nearest node joined to `id` by an edge that lies
## in that direction (within 45 degrees of it), else the nearest node in that open half-plane, ties broken by id; `id`
## itself when nothing lies that way. The cone keeps a nearly sideways edge from beating the node straight below or above:
## from a form whose children flank it, "down" must reach the form underneath.
static func neighbor(model: Dictionary, id: String, dir: Vector2i) -> String:
	var nodes: Dictionary = model["nodes"]
	if not nodes.has(id):
		return id
	var from := _centre(nodes[id])
	var joined: Array = []
	for e in model["edges"]:
		if e["from"] == id:
			joined.append(e["to"])
		elif e["to"] == id:
			joined.append(e["from"])
	var best := _nearest(nodes, from, dir, joined, true)
	if best == "":
		best = _nearest(nodes, from, dir, nodes.keys(), false)
	return id if best == "" else best

## The nearest of `ids` ahead of `from` in `dir`: in the open half-plane, or within the 45-degree cone when `cone`.
static func _nearest(nodes: Dictionary, from: Vector2, dir: Vector2i, ids: Array, cone: bool) -> String:
	var sorted := ids.duplicate()
	sorted.sort()
	var best := ""
	var best_d := INF
	for other in sorted:
		var off := _centre(nodes[other]) - from
		var along := off.dot(Vector2(dir))
		if along <= 0.0 or (cone and absf(off.cross(Vector2(dir))) > along):
			continue
		if off.length() < best_d:
			best_d = off.length()
			best = other
	return best

static func _centre(node: Dictionary) -> Vector2:
	return node["pos"] + NODE_SIZE / 2.0
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `tools/run_tests.sh skill_tree_model`
Expected: `PASS: 18 tests`

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/skill_tree_model.gd tests/test_skill_tree_model.gd
git commit -m "feat(ui): neighbor and root for moving through the skill tree"
```

### Task 7: The node card's text, the price and `affordable`

This is the one step-1 task that needs the essence overhaul's price and held values.

**Files:**
- Modify: `scripts/ui/skill_tree_model.gd` (`_skill_node`)
- Modify: `scripts/ui/skill_screen_model.gd` (add after `capped_text`, ~131)
- Test: `tests/test_skill_tree_model.gd`

**Interfaces:**
- Consumes (existing):
  - `SkillScreenModel.detail(rules, d, slots, atk) -> Dictionary` (`scripts/ui/skill_screen_model.gd:122`). It is used only for a power held now: on an unowned power, `level_progress` is zeros, so `progress` is −1 and the card would read "MAX LEVEL".
  - `ActiveSlots.new()` (`scripts/player/active_slots.gd`).
- Consumes, from the essence overhaul plan: `SkillRulesEngine.can_afford(id) -> bool`, `held(element) -> int` and `evolution_price(id) -> Dictionary`; and, from its part 3, `SkillScreenModel.price_text(price: Dictionary) -> String` ("water 6, dark 10") and `SkillScreenModel.shortfall_text(rules, price: Dictionary) -> String` ("needs 2 more water", empty when affordable).
- Produces:
  - a READY node gains `"affordable": bool`;
  - `SkillScreenModel.price_line(rules, id: String) -> String`, for example `"Evolve for water 6, dark 10 — you hold 8 water, 4 dark"`;
  - `SkillScreenModel.short_line(rules, id: String) -> String`: `"Needs 2 more dark"`, or `"Evolve in the Skills tab"` when nothing is short;
  - `SkillScreenModel.TREE_STATUS: Dictionary`;
  - `SkillScreenModel.tree_card(rules, node: Dictionary, defs: Dictionary, forms: Dictionary, slots: ActiveSlots, atk := 1) -> Dictionary`. It returns `{"title": String, "status": String, "lines": Array}`. `forms` is read from Task 15 on.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_skill_tree_model.gd`:

```gdscript
# --- the price and the card ---

func test_a_ready_evolution_says_whether_it_is_affordable() -> void:
	rules = _fixture_rules()
	assert_false(_build()["nodes"]["blade"]["affordable"], "holds water 1, the price is water 2")
	rules.handle_event("absorbed", {"essence": "water"})
	assert_true(_build()["nodes"]["blade"]["affordable"])
	assert_false(_build()["nodes"]["hydraulic_propulsion"].has("affordable"), "only a ready evolution carries it")

func test_the_price_line_names_the_price_what_you_hold_and_what_is_short() -> void:
	rules = _fixture_rules()
	assert_eq(SkillScreenModel.price_line(rules, "blade"), "Evolve for water 2 — you hold 1 water")
	assert_eq(SkillScreenModel.short_line(rules, "blade"), "Needs 1 more water")
	rules.handle_event("absorbed", {"essence": "water"})
	assert_eq(SkillScreenModel.short_line(rules, "blade"), "Evolve in the Skills tab")

func test_the_card_for_a_held_power_reuses_the_skill_detail() -> void:
	var card := SkillScreenModel.tree_card(rules, _build()["nodes"]["appraisal"], by_id, {}, ActiveSlots.new())
	var d := SkillScreenModel.detail(rules, by_id["appraisal"], ActiveSlots.new())
	assert_eq(card["title"], "Appraisal")
	assert_eq(card["status"], "Owned  Lv %d / %d" % [d["level"], d["max_level"]])
	assert_true(card["lines"].has(d["description"]))

func test_the_card_for_a_stub_says_nothing_about_it() -> void:
	compendium.raise("hydraulic_propulsion", CompendiumModel.State.OWNED_ONCE)
	var card := SkillScreenModel.tree_card(rules, _build()["nodes"]["water_blade"], by_id, {}, ActiveSlots.new())
	assert_eq(card, {"title": "???", "status": "Undiscovered", "lines": []})

func test_a_named_card_shows_the_hint_and_only_owned_once_shows_how() -> void:
	compendium.raise("leap", CompendiumModel.State.HINTED)
	compendium.raise("wall_cling", CompendiumModel.State.OWNED_ONCE)
	var nodes: Dictionary = _build()["nodes"]
	var leap := SkillScreenModel.tree_card(rules, nodes["leap"], by_id, {}, ActiveSlots.new())
	assert_eq(leap["status"], "Not yet learned")
	assert_true(leap["lines"].has(by_id["leap"].hint))
	assert_false(leap["lines"].any(func(l): return String(l).begins_with("How: ")))
	var cling := SkillScreenModel.tree_card(rules, nodes["wall_cling"], by_id, {}, ActiveSlots.new())
	assert_true(cling["lines"].has("How: " + SkillScreenModel.condition_text(by_id["wall_cling"], by_id)))

func test_a_ready_card_names_the_price_what_is_short_and_its_base() -> void:
	rules = _fixture_rules()
	var card := SkillScreenModel.tree_card(rules, _build()["nodes"]["blade"], _fixture_defs(), {}, ActiveSlots.new())
	assert_eq(card["status"], "Ready to evolve")
	assert_true(card["lines"].has("Evolve for water 2 — you hold 1 water"))
	assert_true(card["lines"].has("Needs 1 more water"))
	assert_true(card["lines"].has("Evolves from Hydraulic Propulsion"))
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tools/run_tests.sh skill_tree_model`
Expected: `FAIL: engine error or empty run`. The log shows `Parse Error` that static function `price_line()` / `tree_card()` is not found in `SkillScreenModel`.

- [ ] **Step 3: Write the minimal implementation**

In `scripts/ui/skill_tree_model.gd`, in `_skill_node`, add before `return n`:

```gdscript
	if n["state"] == READY:
		n["affordable"] = rules.can_afford(d.id)
```

In `scripts/ui/skill_screen_model.gd`, add after `capped_text()`:

```gdscript
## A ready evolution's price and what you hold: "Evolve for water 6, dark 10 — you hold 8 water, 4 dark". The price text is the
## essence overhaul's price_text(price), so the Skills tab and the Tree tab word a price the same way.
static func price_line(rules, id: String) -> String:
	var price: Dictionary = rules.evolution_price(id)
	var held: Array = []
	for e in Essences.ALL:
		if price.has(e):
			held.append("%d %s" % [int(rules.held(e)), e])
	return "Evolve for %s — you hold %s" % [price_text(price), ", ".join(held)]

## What a ready evolution still needs ("Needs 2 more dark"), or where to evolve it once nothing is short. The shortfall is the
## essence overhaul's shortfall_text(rules, price), capitalised.
static func short_line(rules, id: String) -> String:
	var short := shortfall_text(rules, rules.evolution_price(id))
	return "Evolve in the Skills tab" if short == "" else short.substr(0, 1).to_upper() + short.substr(1)

## The Tree tab's status line per node state.
const TREE_STATUS := {"owned": "Owned", "named": "Not yet learned", "retired": "Evolved",
	"closed": "Closed: a sibling took the branch", "ready": "Ready to evolve", "current": "Your body now",
	"reached": "Reached before", "stub": "Undiscovered"}

## The Tree tab's card for a node: {"title", "status", "lines"}. A power held now reuses detail(). A ready evolution adds its
## price, what you hold and what is short. The hint and the condition follow compendium_rows: the model only gives the
## condition at Owned-once. A stub says nothing about itself.
static func tree_card(rules, node: Dictionary, defs: Dictionary, forms: Dictionary, slots: ActiveSlots, atk := 1) -> Dictionary:
	if node["state"] == SkillTreeModel.STUB:
		return {"title": "???", "status": TREE_STATUS[SkillTreeModel.STUB], "lines": []}
	var d: SkillDef = defs[node["id"]]
	var status: String = TREE_STATUS[node["state"]]
	var lines: Array = []
	if node["state"] == SkillTreeModel.OWNED:
		var c := detail(rules, d, slots, atk)
		status = "Owned  Lv %d / %d" % [c["level"], c["max_level"]]
		lines.append(c["description"])
		lines.append_array(c["lines"])
	elif node.has("condition") or [SkillTreeModel.READY, SkillTreeModel.RETIRED].has(node["state"]):
		lines.append(d.description)
	if node["state"] == SkillTreeModel.READY:
		lines.append(price_line(rules, d.id))
		lines.append(short_line(rules, d.id))
	if node.has("hint"):
		lines.append(node["hint"])
	if node.has("condition"):
		lines.append("How: " + node["condition"])
	if d.source == "evolution" and defs.has(d.replaces):
		lines.append("Evolves from " + defs[d.replaces].display_name)
	return {"title": d.display_name, "status": status, "lines": lines}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `tools/run_tests.sh skill_tree_model && tools/run_tests.sh skill_screen`
Expected: `PASS: 24 tests`, then `PASS: <n> tests`.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/skill_tree_model.gd scripts/ui/skill_screen_model.gd tests/test_skill_tree_model.gd
git commit -m "feat(ui): the tree card's text, with an evolution's price, what you hold and what is short"
```

### Task 8: `SkillTreeView`: panels, edges and the camera

**Files:**
- Create: `scripts/ui/skill_tree_view.gd`
- Test: `tests/test_skill_tree_view.gd` (create)

**Interfaces:**
- Consumes:
  - `SkillTreeModel.build`, `NODE_SIZE`, `LABEL_INSET`, `root`, and the state constants (Tasks 4 to 6);
  - `SkillScreen.COL_ROW`, `COL_SELECTED`, `COL_BORDER`, `COL_DIM`, `COL_CAPPED` and `FONT_SMALL` (`scripts/ui/skill_screen.gd:34-44`).
- Produces:
  - `SkillTreeView` (extends `Control`, clipped, positioned at `BOX`):
    - `const BOX := Rect2(158, 46, 244, 274)`;
    - `static camera(model, sel: String, overview: bool, box_size := BOX.size) -> Dictionary` (`{"scale": float, "offset": Vector2}`);
    - `static neighborhood(model, id: String) -> Rect2` (the node and its edge neighbors, in canvas px);
    - `static look_for(state: String, selected: bool) -> Dictionary`;
    - `show_model(model: Dictionary, sel: String, overview: bool)`, `panel_for(id) -> Panel` (null when not built), `panel_count() -> int`;
    - `segments: Array` (`[{"a", "b", "color"}]`).
  - Signals `node_clicked(id: String)` and `zoom_requested(overview: bool)`, emitted deferred: a left click on a node, wheel up (normal), wheel down (overview). A left click on empty space emits nothing.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_skill_tree_view.gd`:

```gdscript
extends GutTest
## The Tree tab's drawing: the camera as a function of selection and zoom, the panels, the edges and the mouse signals.

var skills: Array
var rules: SkillRulesEngine
var compendium: CompendiumModel
var model: Dictionary

func before_each() -> void:
	skills = DefLoader.load_dir("res://data/skills")
	rules = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	compendium = CompendiumModel.new(skills, [])
	CoreWiring.connect_core(rules, compendium, AnnouncerQueue.new())
	rules.start_run()
	for id in compendium.states():
		compendium.raise(id, CompendiumModel.State.OWNED_ONCE)
	model = SkillTreeModel.build(rules, compendium, {}, [], "slime")

func _view(sel: String, overview := false) -> SkillTreeView:
	var v := SkillTreeView.new()
	add_child_autofree(v)
	v.show_model(model, sel, overview)
	return v

func _box() -> Rect2:
	return Rect2(Vector2.ZERO, SkillTreeView.BOX.size)

func _node_rect(cam: Dictionary, id: String) -> Rect2:
	return Rect2(cam["offset"] + model["nodes"][id]["pos"] * cam["scale"], SkillTreeModel.NODE_SIZE * cam["scale"])

func _button(index: MouseButton) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = index
	ev.pressed = true
	return ev

func _stub_model() -> void:
	compendium = CompendiumModel.new(skills, [])
	compendium.raise("hydraulic_propulsion", CompendiumModel.State.OWNED_ONCE)
	model = SkillTreeModel.build(rules, compendium, {}, [], "slime")

func test_the_camera_is_a_pure_function_of_selection_and_zoom() -> void:
	for id in model["nodes"]:
		assert_eq(SkillTreeView.camera(model, id, false), SkillTreeView.camera(model, id, false), id)
	var a := _view("leap")
	var b := _view("leap")
	assert_eq(a.panel_for("leap").position, b.panel_for("leap").position, "a rebuild draws the same picture")

func test_the_normal_camera_keeps_every_selection_inside_the_box() -> void:
	for id in model["nodes"]:
		var cam := SkillTreeView.camera(model, id, false)
		assert_eq(cam["scale"], 1.0)
		assert_true(_box().encloses(_node_rect(cam, id)), "%s at %s" % [id, _node_rect(cam, id)])

func test_a_selection_and_its_edge_neighbors_share_the_screen_when_they_fit() -> void:
	for id in model["nodes"]:
		var group := SkillTreeView.neighborhood(model, id)
		if group.size.x > _box().size.x or group.size.y > _box().size.y:
			continue
		var cam := SkillTreeView.camera(model, id, false)
		var shown := Rect2(cam["offset"] + group.position, group.size)
		assert_true(_box().encloses(shown), "%s and its neighbors at %s" % [id, shown])

func test_the_overview_fits_the_whole_canvas() -> void:
	var cam := SkillTreeView.camera(model, "leap", true)
	assert_lt(cam["scale"], 1.0)
	for id in model["nodes"]:
		assert_true(_box().encloses(_node_rect(cam, id)), id)

func test_the_normal_zoom_labels_a_node_with_its_name() -> void:
	var labels := _view("leap").panel_for("leap").find_children("*", "Label", true, false)
	assert_eq(labels.size(), 1)
	assert_eq(labels[0].text, "Leap")

func test_a_stub_is_drawn_without_its_name() -> void:
	_stub_model()
	var labels := _view("water_blade").panel_for("water_blade").find_children("*", "Label", true, false)
	assert_eq(labels[0].text, "???")

func test_the_overview_draws_dots_without_labels() -> void:
	var v := _view("leap", true)
	assert_eq(v.find_children("*", "Label", true, false).size(), 0)
	assert_lt(v.panel_for("leap").size.x, SkillTreeModel.NODE_SIZE.x)

func test_edges_are_bright_when_known_and_dim_to_a_stub() -> void:
	var v := _view("leap", true)
	assert_eq(v.segments.size(), model["edges"].size())
	assert_true(v.segments.all(func(s): return s["color"] == SkillScreen.COL_BORDER))
	_stub_model()
	var stubbed := _view("hydraulic_propulsion", true)
	assert_eq(stubbed.segments.map(func(s): return s["color"]), [SkillScreen.COL_DIM, SkillScreen.COL_DIM])

func test_panels_wholly_outside_the_box_are_not_built() -> void:
	var v := _view(SkillTreeModel.root(model))
	assert_lt(v.panel_count(), model["nodes"].size(), "at the normal zoom the canvas is wider than the box")
	for c in v.get_children():
		assert_true(_box().intersects(Rect2(c.position, c.size)), str(c.name))

func test_a_click_on_a_node_asks_for_it_once_the_frame_is_over() -> void:
	var v := _view("leap")
	watch_signals(v)
	v.panel_for("leap").gui_input.emit(_button(MOUSE_BUTTON_LEFT))
	assert_signal_not_emitted(v, "node_clicked", "deferred: the panel is still inside its own gui_input")
	await wait_process_frames(1)
	assert_signal_emitted_with_parameters(v, "node_clicked", ["leap"])

func test_the_wheel_asks_for_a_zoom_and_a_click_on_empty_space_asks_for_nothing() -> void:
	var v := _view("leap")
	watch_signals(v)
	v.gui_input.emit(_button(MOUSE_BUTTON_WHEEL_DOWN))
	await wait_process_frames(1)
	assert_signal_emitted_with_parameters(v, "zoom_requested", [true])
	v.gui_input.emit(_button(MOUSE_BUTTON_WHEEL_UP))
	await wait_process_frames(1)
	assert_signal_emitted_with_parameters(v, "zoom_requested", [false])
	v.gui_input.emit(_button(MOUSE_BUTTON_LEFT))
	await wait_process_frames(1)
	assert_signal_not_emitted(v, "node_clicked")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `gtimeout -k 5 180 env HOME="$PWD/.tmp/gdhome" godot --headless --import > .tmp/test-logs/import.log 2>&1; tools/run_tests.sh skill_tree_view`
Expected: `FAIL: engine error or empty run`. The log shows `Parse Error: Identifier "SkillTreeView" not declared in the current scope.`

- [ ] **Step 3: Write the minimal implementation**

Create `scripts/ui/skill_tree_view.gd`:

```gdscript
class_name SkillTreeView
extends Control
## The Tree tab's drawing: a clipped box filled with one panel per node and one _draw pass for the edges. The camera is a
## pure function of the selected node and the zoom level (camera()), so a rebuild with the same two draws the same picture.
## Clicks and the wheel arrive through gui_input and leave as signals deferred to the end of the frame: the screen rebuilds
## on them, and a panel must not be freed while its own gui_input is running.

signal node_clicked(id: String)
signal zoom_requested(overview: bool)

## The skill screen's list column; the card stays beside it.
const BOX := Rect2(158, 46, 244, 274)
const COL_STUB := Color(0.03, 0.06, 0.16, 0.9)

## The edges as drawn, in box coordinates: [{"a", "b", "color"}], from the right middle of the first node to the left
## middle of the second.
var segments: Array = []
var _panels := {}

func _init() -> void:
	position = BOX.position
	size = BOX.size
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_input.bind(""))

## {"scale", "offset"}: a node's box position is offset + pos * scale. The overview fits the whole canvas in the box. The
## normal zoom is 1:1 and centred on the selected node together with its edge neighbors, as far as that keeps the
## selection itself inside the box, then clamped to the canvas. The selection is always inside the box, and so is every
## neighbor whenever the group fits.
static func camera(model: Dictionary, sel: String, overview: bool, box_size := BOX.size) -> Dictionary:
	var canvas: Vector2 = model["size"]
	if overview:
		var s := minf(1.0, minf(box_size.x / maxf(1.0, canvas.x), box_size.y / maxf(1.0, canvas.y)))
		return {"scale": s, "offset": ((box_size - canvas * s) / 2.0).floor()}
	var focus := canvas / 2.0
	if model["nodes"].has(sel):
		var me := Rect2(model["nodes"][sel]["pos"], SkillTreeModel.NODE_SIZE)
		focus = neighborhood(model, sel).get_center()
		focus.x = clampf(focus.x, me.end.x - box_size.x / 2.0, me.position.x + box_size.x / 2.0)
		focus.y = clampf(focus.y, me.end.y - box_size.y / 2.0, me.position.y + box_size.y / 2.0)
	return {"scale": 1.0, "offset": Vector2(_axis(box_size.x, canvas.x, focus.x), _axis(box_size.y, canvas.y, focus.y)).floor()}

## The canvas rect around a node and every node an edge joins it to.
static func neighborhood(model: Dictionary, id: String) -> Rect2:
	var nodes: Dictionary = model["nodes"]
	var r := Rect2(nodes[id]["pos"], SkillTreeModel.NODE_SIZE)
	for e in model["edges"]:
		if e["from"] == id:
			r = r.merge(Rect2(nodes[e["to"]]["pos"], SkillTreeModel.NODE_SIZE))
		elif e["to"] == id:
			r = r.merge(Rect2(nodes[e["from"]]["pos"], SkillTreeModel.NODE_SIZE))
	return r

static func _axis(box: float, canvas: float, focus: float) -> float:
	if canvas <= box:
		return (box - canvas) / 2.0
	return clampf(box / 2.0 - focus, box - canvas, 0.0)

## A node's colours, {"bg", "border", "text"}: a ready evolution and the current form are outlined in gold; retired, closed
## and stub nodes are dim; a named node's text is dim.
static func look_for(state: String, selected: bool) -> Dictionary:
	var look := {"bg": SkillScreen.COL_SELECTED if selected else SkillScreen.COL_ROW, "border": SkillScreen.COL_BORDER,
		"text": Color.WHITE}
	if state == SkillTreeModel.READY or state == SkillTreeModel.CURRENT:
		look["border"] = SkillScreen.COL_CAPPED
	elif state == SkillTreeModel.NAMED:
		look["text"] = SkillScreen.COL_DIM
	elif state == SkillTreeModel.RETIRED or state == SkillTreeModel.CLOSED:
		look["text"] = SkillScreen.COL_DIM
		look["border"] = SkillScreen.COL_DIM
	elif state == SkillTreeModel.STUB:
		look["bg"] = SkillScreen.COL_SELECTED if selected else COL_STUB
		look["text"] = SkillScreen.COL_DIM
		look["border"] = SkillScreen.COL_DIM
	return look

## Rebuilds the picture for `model` with `sel` selected, at the overview (dots and edges) or the normal zoom (names).
## Panels wholly outside the box are not built.
func show_model(model: Dictionary, sel: String, overview: bool) -> void:
	for c in get_children():
		c.free()
	_panels.clear()
	segments.clear()
	var cam := camera(model, sel, overview, size)
	var s: float = cam["scale"]
	var off: Vector2 = cam["offset"]
	var nodes: Dictionary = model["nodes"]
	var half := SkillTreeModel.NODE_SIZE.y / 2.0
	for e in model["edges"]:
		var a: Vector2 = nodes[e["from"]]["pos"] + Vector2(SkillTreeModel.NODE_SIZE.x, half)
		var b: Vector2 = nodes[e["to"]]["pos"] + Vector2(0.0, half)
		segments.append({"a": off + a * s, "b": off + b * s, "color": SkillScreen.COL_BORDER if e["known"] else SkillScreen.COL_DIM})
	var ids := nodes.keys()
	ids.sort()
	for id in ids:
		var n: Dictionary = nodes[id]
		var at: Vector2 = n["pos"]
		var rect := Rect2(off + at * s, SkillTreeModel.NODE_SIZE * s)
		if not Rect2(Vector2.ZERO, size).intersects(rect):
			continue
		var look := look_for(n["state"], id == sel)
		var p := Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = look["bg"]
		style.border_color = look["border"]
		style.set_border_width_all(2 if id == sel else 1)
		style.set_corner_radius_all(2)
		p.add_theme_stylebox_override("panel", style)
		p.position = rect.position
		p.size = rect.size
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		p.gui_input.connect(_on_input.bind(id))
		add_child(p)
		_panels[id] = p
		if not overview:
			var l := Label.new()
			l.text = "???" if n["state"] == SkillTreeModel.STUB else n["name"]
			l.position = Vector2(SkillTreeModel.LABEL_INSET, 0)
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.clip_text = true
			l.add_theme_font_size_override("font_size", SkillScreen.FONT_SMALL)
			l.add_theme_color_override("font_color", look["text"])
			p.add_child(l)
			l.size = Vector2(rect.size.x - 2.0 * SkillTreeModel.LABEL_INSET, rect.size.y)
	queue_redraw()

## The panel drawn for `id`, or null when it lies outside the box or is not a node.
func panel_for(id: String) -> Panel:
	return _panels.get(id)

func panel_count() -> int:
	return _panels.size()

func _draw() -> void:
	for seg in segments:
		draw_line(seg["a"], seg["b"], seg["color"], 1.0)

func _on_input(event: InputEvent, id: String) -> void:
	var b := event as InputEventMouseButton
	if b == null or not b.pressed:
		return
	if b.button_index == MOUSE_BUTTON_LEFT and id != "":
		call_deferred("_emit_click", id)
	elif b.button_index == MOUSE_BUTTON_WHEEL_UP:
		call_deferred("_emit_zoom", false)
	elif b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		call_deferred("_emit_zoom", true)
	else:
		return
	accept_event()

func _emit_click(id: String) -> void:
	node_clicked.emit(id)

func _emit_zoom(overview: bool) -> void:
	zoom_requested.emit(overview)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `gtimeout -k 5 180 env HOME="$PWD/.tmp/gdhome" godot --headless --import > .tmp/test-logs/import.log 2>&1; tools/run_tests.sh skill_tree_view`
Expected: `PASS: 11 tests`

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/skill_tree_view.gd scripts/ui/skill_tree_view.gd.uid tests/test_skill_tree_view.gd tests/test_skill_tree_view.gd.uid
git commit -m "feat(ui): the skill tree view draws nodes and edges with a camera that follows the selection"
```

### Task 9: The Tree tab: keys, the D-pad, the stick, `tree_zoom` and the card

**Files:**
- Modify: `scripts/ui/skill_screen.gd` (member vars, `switch_tab` :137, `selected_id` :153, `accept` :160, `_process`, `_unhandled_input`, the tree branch of `_refresh_tab`)
- Modify: `autoload/controls.gd` (`BINDINGS`, `PAD_BUTTONS`)
- Test: `tests/test_tree_tab.gd` (create)

**Interfaces:**
- Consumes:
  - `SkillTreeModel.build`, `root` and `neighbor` (Tasks 4 to 6);
  - `SkillScreenModel.tree_card` (Task 7);
  - `SkillTreeView.new`, `show_model`, `panel_for` and `BOX` (Task 8);
  - `nav_step(stick: Vector2, delta) -> Vector2i` (Task 3);
  - `settings_menu` and `settings_hint()` (Task 1);
  - `Player.forms` and `Player.form.form_id` (`scripts/player/player.gd:103-104`);
  - `PadInput.key`, `.button`, `.axis` and `.reset` (`tests/support/pad_input.gd`).
- Produces:
  - `SkillScreen.tree_model() -> Dictionary`, `tree_view() -> SkillTreeView`, `tree_overview() -> bool`;
  - `tree_move(dir: Vector2i)`, `select_tree_node(id: String)`, `set_tree_overview(overview: bool)`, `toggle_tree_zoom()`;
  - `selected_id()` returns the tree's selection on the Tree tab;
  - the `tree_zoom` action (Z, L3).
  - Task 10 connects the view's signals to `select_tree_node` / `set_tree_overview`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_tree_tab.gd`:

```gdscript
extends GutTest
## The Tree tab on the skill screen: moving the selection with keys, the D-pad, the stick and the mouse, the zoom, the camera
## across rebuilds, the card, and the forms band.

var rules: SkillRulesEngine
var compendium: CompendiumModel
var skills: Array
var player: Player
var screen: SkillScreen

func before_each() -> void:
	skills = DefLoader.load_dir("res://data/skills")
	var creature_list := DefLoader.load_dir("res://data/creatures")
	rules = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	compendium = CompendiumModel.new(skills, creature_list)
	CoreWiring.connect_core(rules, compendium, AnnouncerQueue.new())
	player = Player.new()
	player.setup(rules, compendium, creature_list, func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()
	screen = SkillScreen.new()
	add_child_autofree(screen)
	screen.bind(player, rules, compendium, skills)

func after_each() -> void:
	PadInput.reset()
	get_tree().paused = false

func _discover_all() -> void:
	for id in compendium.states():
		compendium.raise(id, CompendiumModel.State.OWNED_ONCE)

func _open_tree() -> void:
	screen.open()
	screen.switch_tab(1)

func test_the_tree_tab_opens_on_the_root() -> void:
	_open_tree()
	assert_eq(screen.tab(), "tree")
	assert_ne(screen.selected_id(), "")
	assert_eq(screen.selected_id(), SkillTreeModel.root(screen.tree_model()))
	assert_not_null(screen.tree_view())

func test_the_direction_keys_and_the_dpad_follow_neighbor() -> void:
	_discover_all()
	_open_tree()
	var first := SkillTreeModel.neighbor(screen.tree_model(), screen.selected_id(), Vector2i.RIGHT)
	assert_ne(first, screen.selected_id(), "the first press must move, or this proves nothing")
	var presses := [[KEY_RIGHT, Vector2i.RIGHT], [KEY_S, Vector2i.DOWN], [KEY_A, Vector2i.LEFT], [KEY_UP, Vector2i.UP]]
	for p in presses:
		var expected := SkillTreeModel.neighbor(screen.tree_model(), screen.selected_id(), p[1])
		PadInput.key(p[0])
		assert_eq(screen.selected_id(), expected, str(p))
	var down := SkillTreeModel.neighbor(screen.tree_model(), screen.selected_id(), Vector2i.DOWN)
	PadInput.button(JOY_BUTTON_DPAD_DOWN)
	assert_eq(screen.selected_id(), down)

func test_the_left_stick_moves_the_selection_in_all_four_directions_with_the_repeat() -> void:
	_discover_all()
	_open_tree()
	for dir in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var expected := SkillTreeModel.neighbor(screen.tree_model(), screen.selected_id(), dir)
		Controls.last_stick = Vector2(dir)
		screen._process(0.016)
		assert_eq(screen.selected_id(), expected, str(dir))
		Controls.last_stick = Vector2.ZERO
		screen._process(0.016)
	var one := SkillTreeModel.neighbor(screen.tree_model(), screen.selected_id(), Vector2i.DOWN)
	var two := SkillTreeModel.neighbor(screen.tree_model(), one, Vector2i.DOWN)
	assert_ne(two, one, "needs two steps down to prove the repeat")
	Controls.last_stick = Vector2(0, 1)
	screen._process(0.016)
	assert_eq(screen.selected_id(), one)
	screen._process(0.2)
	assert_eq(screen.selected_id(), one, "held, inside the delay")
	screen._process(0.2)
	assert_eq(screen.selected_id(), two, "held past the delay: repeat")

func test_tree_zoom_flips_between_the_two_levels_from_the_key_and_the_stick_click() -> void:
	_open_tree()
	assert_false(screen.tree_overview())
	PadInput.key(KEY_Z)
	assert_true(screen.tree_overview())
	assert_eq(screen.tree_view().find_children("*", "Label", true, false).size(), 0, "the overview has no labels")
	PadInput.button(JOY_BUTTON_LEFT_STICK)
	assert_false(screen.tree_overview())

func test_a_tab_switch_resets_the_tree_and_tree_zoom_does_nothing_elsewhere() -> void:
	_discover_all()
	_open_tree()
	PadInput.key(KEY_RIGHT)
	PadInput.key(KEY_Z)
	screen.switch_tab(0)
	PadInput.key(KEY_Z)
	screen.switch_tab(1)
	assert_false(screen.tree_overview())
	assert_eq(screen.selected_id(), SkillTreeModel.root(screen.tree_model()))

func test_the_camera_is_the_same_after_a_rebuild_and_keeps_the_selection_in_the_box() -> void:
	_discover_all()
	_open_tree()
	for i in 3:
		screen.tree_move(Vector2i.DOWN)
	var id := screen.selected_id()
	var before := screen.tree_view().panel_for(id).get_global_rect()
	screen.open()  # rebuilds the open tab
	var after := screen.tree_view().panel_for(id).get_global_rect()
	assert_eq(after, before)
	assert_true(SkillTreeView.BOX.encloses(after))

func test_the_tree_tab_stays_on_the_screen_at_both_zooms() -> void:
	_discover_all()
	_open_tree()
	for overview in [false, true]:
		screen.set_tree_overview(overview)
		for c in screen.find_children("*", "Control", true, false):
			var r: Rect2 = c.get_global_rect()
			assert_true(r.position.x >= 0.0 and r.end.x <= 640.0 and r.position.y >= 0.0 and r.end.y <= 360.0, str(c.name, r))

func test_a_scheme_change_keeps_the_selection_and_the_zoom_and_switches_the_hint() -> void:
	_discover_all()
	_open_tree()
	PadInput.key(KEY_RIGHT)
	PadInput.key(KEY_Z)
	var sel := screen.selected_id()
	assert_string_contains(screen.hint_text(), "Z Zoom")
	PadInput.axis(JOY_AXIS_RIGHT_X, 0.9)  # the pad becomes the scheme: Controls.scheme_changed rebuilds the open screen
	assert_string_contains(screen.hint_text(), "L3 Zoom")
	assert_eq(screen.selected_id(), sel)
	assert_true(screen.tree_overview())

func test_the_card_shows_the_selected_node_and_a_stub_shows_no_name() -> void:
	compendium.raise("hydraulic_propulsion", CompendiumModel.State.OWNED_ONCE)
	_open_tree()
	screen.select_tree_node("water_blade")
	var card := "\n".join(screen.detail_texts())
	assert_string_contains(card, "???")
	assert_false(card.contains("Water Blade"))
	screen.select_tree_node("appraisal")
	assert_string_contains("\n".join(screen.detail_texts()), "Appraisal")

func test_accept_on_the_tree_changes_nothing() -> void:
	_open_tree()
	var slots_before: Array = player.skillset.slots.slots.duplicate()
	screen.accept()
	assert_eq(player.skillset.slots.slots, slots_before)
	assert_true(screen.is_open())
	assert_eq(screen.tab(), "tree")

func test_the_tree_zoom_action_has_a_key_and_a_stick_click() -> void:
	Controls.ensure_actions()
	var evs := InputMap.action_get_events("tree_zoom")
	assert_true(evs.any(func(e): return e is InputEventKey and e.physical_keycode == KEY_Z))
	assert_true(evs.any(func(e): return e is InputEventJoypadButton and e.button_index == JOY_BUTTON_LEFT_STICK))
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `gtimeout -k 5 180 env HOME="$PWD/.tmp/gdhome" godot --headless --import > .tmp/test-logs/import.log 2>&1; tools/run_tests.sh tree_tab`
Expected: `FAIL: engine error or empty run`. The log shows `Parse Error` that function `tree_model()` is not found in base `SkillScreen`.

- [ ] **Step 3: Write the minimal implementation**

In `autoload/controls.gd`, add to `BINDINGS` (after `"settings": [KEY_TAB],`):

```gdscript
	"tree_zoom": [KEY_Z],
```

Add to `PAD_BUTTONS` (after `"settings": [JOY_BUTTON_RIGHT_STICK],`):

```gdscript
	"tree_zoom": [JOY_BUTTON_LEFT_STICK],
```

In `scripts/ui/skill_screen.gd`, make the following edits.

1. Add beside the other member `var`s:

```gdscript
## Tree tab: the selected node and the zoom are the only state that outlives a rebuild; the camera follows from them.
var _tree_sel := ""
var _tree_overview := false
var _tree_model := {}
```

2. Replace `switch_tab()`:

```gdscript
func switch_tab(i: int) -> void:
	_tab = posmod(i, tabs().size())
	_sel = 0
	_scroll = 0
	_tree_sel = ""
	_tree_overview = false
	_refresh()
	EventBus.world_event.emit("menu_move", {})
```

3. Replace `selected_id()`:

```gdscript
func selected_id() -> String:
	if tab() == "tree":
		return _tree_sel
	if _selectable.is_empty():
		return ""
	return _rows[_selectable[_sel]].get("id", "")
```

4. In `accept()`, insert as the first two lines of the body:

```gdscript
	if tab() == "tree":
		return  # read-only: a power evolves in the Skills tab, the body in the Form tab
```

5. Add the tree's public functions after `selected_id()`:

```gdscript
func tree_model() -> Dictionary:
	return _tree_model

func tree_overview() -> bool:
	return _tree_overview

## The SkillTreeView showing now, or null off the Tree tab.
func tree_view() -> SkillTreeView:
	for c in _list.get_children():
		if c is SkillTreeView:
			return c
	return null

## Moves the tree's selection one step in `dir` (Vector2i.UP is up), along SkillTreeModel.neighbor.
func tree_move(dir: Vector2i) -> void:
	if tab() != "tree" or _tree_model.is_empty():
		return
	var next := SkillTreeModel.neighbor(_tree_model, _tree_sel, dir)
	if next != _tree_sel:
		_tree_sel = next
		EventBus.world_event.emit("menu_move", {})
	_refresh()

func select_tree_node(id: String) -> void:
	if tab() != "tree" or not _tree_model.get("nodes", {}).has(id):
		return
	_tree_sel = id
	EventBus.world_event.emit("menu_move", {})
	_refresh()

## The overview (dots and edges) or the normal zoom (names).
func set_tree_overview(overview: bool) -> void:
	if tab() != "tree" or overview == _tree_overview:
		return
	_tree_overview = overview
	EventBus.world_event.emit("menu_move", {})
	_refresh()

func toggle_tree_zoom() -> void:
	set_tree_overview(not _tree_overview)

## One step on the open tab: the tree moves four ways, a list up or down.
func _step(dir: Vector2i) -> void:
	if tab() == "tree":
		tree_move(dir)
	elif dir.y != 0:
		move(dir.y)
```

6. Replace `_process()`:

```gdscript
func _process(delta: float) -> void:
	if not visible:
		_nav_dir = Vector2i.ZERO
		return
	var stick := Controls.last_stick
	if settings_menu.is_open() or tab() != "tree":
		stick = Vector2(0.0, stick.y)  # the lists read only the vertical part, so a diagonal push still moves a list
	var step := nav_step(stick, delta)
	if step == Vector2i.ZERO:
		return
	if settings_menu.is_open():
		settings_menu.move(step.y)
	else:
		_step(step)
```

7. Replace `_unhandled_input()`:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if visible and settings_menu.is_open():
		if not (event is InputEventJoypadMotion):  # the stick is read in _process
			settings_menu.handle(event)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("menu"):
		if not visible and _player != null and _player.health.is_dead():
			return  # no menu over the death card: the restart would inherit the pause
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	if event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()  # the stick is read in _process
		return
	var tree := tab() == "tree"
	if event.is_action_pressed("ui_up") or event.is_action_pressed("aim_up"):
		_step(Vector2i.UP)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("aim_down"):
		_step(Vector2i.DOWN)
	elif event.is_action_pressed("tab_prev"):
		switch_tab(_tab - 1)
	elif event.is_action_pressed("tab_next"):
		switch_tab(_tab + 1)
	elif tree and (event.is_action_pressed("move_left") or event.is_action_pressed("ui_left")):
		tree_move(Vector2i.LEFT)
	elif tree and (event.is_action_pressed("move_right") or event.is_action_pressed("ui_right")):
		tree_move(Vector2i.RIGHT)
	elif tree and event.is_action_pressed("tree_zoom"):
		toggle_tree_zoom()
	elif event.is_action_pressed("settings"):
		open_settings()
	elif event.is_action_pressed("menu_accept") or event.is_action_pressed("ui_accept"):
		accept()
	elif event.is_action_pressed("menu_back") or event.is_action_pressed("ui_cancel"):
		close()
	else:
		return
	get_viewport().set_input_as_handled()
```

8. In `_refresh_tab`, replace the whole `if tab() == "tree":` block (Task 2's placeholder) with:

```gdscript
	if tab() == "tree":
		_refresh_tree()
		return
```

9. Add after `_build_map()`:

```gdscript
## Tree tab: the graph of what the soul has found, the selected node's card and the hint. Rebuilt on every refresh like the
## Map; the selected id and the zoom flag survive it, and the camera follows from them.
func _refresh_tree() -> void:
	_rows = []
	_selectable = []
	_tree_model = SkillTreeModel.build(_rules, _compendium, _player.forms, [], _player.form.form_id)
	if not _tree_model["nodes"].has(_tree_sel):
		_tree_sel = SkillTreeModel.root(_tree_model)
	_hint.text = ("LB/RB Tabs    D-pad Move    L3 Zoom    B Back" if Controls.using_joypad
		else "Q/E Tabs    Arrows Move    Z Zoom    Esc Back")
	_build_stats()
	_clear(_list)
	_clear(_detail)
	var view := SkillTreeView.new()
	_list.add_child(view)
	view.show_model(_tree_model, _tree_sel, _tree_overview)
	_build_tree_card()

## The card beside the tree, from SkillScreenModel.tree_card. A stub shows the locked icon and no name.
func _build_tree_card() -> void:
	if _tree_sel == "":
		_label(_detail, "Nothing found yet.", Vector2(DETAIL_X, 52), Vector2(190, 12), FONT_MAIN, COL_DIM)
		return
	var n: Dictionary = _tree_model["nodes"][_tree_sel]
	var card := SkillScreenModel.tree_card(_rules, n, _defs, _player.forms, _player.skillset.slots, int(_player.stats.get_stat("atk")))
	var x := DETAIL_X
	if n["kind"] != "form":
		_icon(_detail, "icon_locked" if n["state"] == SkillTreeModel.STUB else "icon_" + _tree_sel, Vector2(DETAIL_X, 50), 40)
		x = DETAIL_X + 46
	_label(_detail, card["title"], Vector2(x, 52), Vector2(DETAIL_X + 192 - x, 16), FONT_BIG, Color.WHITE)
	_label(_detail, card["status"], Vector2(x, 70), Vector2(DETAIL_X + 192 - x, 12), FONT_SMALL, COL_TITLE)
	var y := 100.0
	for line in card["lines"]:
		if y > 290.0:
			break
		var l := _label(_detail, line, Vector2(DETAIL_X, y), Vector2(190, 34), FONT_SMALL, Color.WHITE, true)
		y += maxf(12.0, l.get_line_count() * 11.0 + 3.0)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `tools/run_tests.sh tree_tab && tools/run_tests.sh skill_screen && tools/run_tests.sh menu_input && tools/run_tests.sh audio_ui && tools/run_tests.sh map`
Expected: `PASS: 11 tests` for `tree_tab`, then four `PASS: <n> tests` lines.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/skill_screen.gd autoload/controls.gd tests/test_tree_tab.gd tests/test_tree_tab.gd.uid
git commit -m "feat(ui): the Tree tab hosts the graph and moves by keys, D-pad and stick, with tree_zoom"
```

### Task 10: The mouse on the tree

Nothing under `scripts/ui` handles the mouse yet, so this is the first mouse path. It carries its own canary. The view's panels take clicks through `gui_input` with a stopping `mouse_filter`, so Godot's canvas stretch does the 640×360 hit-testing. The click arrives while `open()` has paused the tree, which proves `PROCESS_MODE_ALWAYS` reaches the view.

**Files:**
- Modify: `scripts/ui/skill_screen.gd` (`_refresh_tree`)
- Modify: `tests/support/pad_input.gd`
- Test: `tests/test_tree_tab.gd`

**Interfaces:**
- Consumes:
  - `SkillTreeView.node_clicked` / `zoom_requested` (Task 8);
  - `SkillScreen.select_tree_node` / `set_tree_overview` (Task 9);
  - `PadInput._send` (`tests/support/pad_input.gd:6`).
- Produces: `PadInput.mouse_click(game_pos: Vector2, index := MOUSE_BUTTON_LEFT)`, a press and a release at a position in game px.

- [ ] **Step 1: Write the failing tests**

In `tests/support/pad_input.gd`, add after `mouse_button`:

```gdscript
## A press and a release at `game_pos` in game px. The root viewport maps a window position back through its stretch
## transform, so this applies that transform first, as mouse_move does for a relative motion.
static func mouse_click(game_pos: Vector2, index := MOUSE_BUTTON_LEFT) -> void:
	var at := (Engine.get_main_loop() as SceneTree).root.get_final_transform() * game_pos
	for pressed in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = index as MouseButton
		b.pressed = pressed
		b.position = at
		b.global_position = at
		_send(b)
```

Append to `tests/test_tree_tab.gd`:

```gdscript
# --- the mouse ---

func _centre_of(id: String) -> Vector2:
	return screen.tree_view().panel_for(id).get_global_rect().get_center()

## A point inside the tree box that no panel covers (the gaps between columns are 14 px wide).
func _empty_point() -> Vector2:
	var box := SkillTreeView.BOX
	for y in range(int(box.position.y) + 2, int(box.end.y) - 2, 2):
		for x in range(int(box.position.x) + 2, int(box.end.x) - 2, 2):
			var p := Vector2(x, y)
			if not screen.tree_view().get_children().any(func(c): return c.get_global_rect().has_point(p)):
				return p
	return Vector2(-1, -1)

func test_a_real_click_on_a_node_selects_it_while_the_tree_is_paused() -> void:
	_discover_all()
	_open_tree()
	var target := SkillTreeModel.neighbor(screen.tree_model(), screen.selected_id(), Vector2i.RIGHT)
	assert_ne(target, screen.selected_id())
	assert_true(get_tree().paused, "the click must reach the view through PROCESS_MODE_ALWAYS")
	PadInput.mouse_click(_centre_of(target))
	await wait_process_frames(2)
	assert_eq(screen.selected_id(), target, "if this is red, the click is not reaching the panel through the stretch")

func test_the_wheel_flips_the_zoom() -> void:
	_open_tree()
	var centre := SkillTreeView.BOX.get_center()
	PadInput.mouse_click(centre, MOUSE_BUTTON_WHEEL_DOWN)
	await wait_process_frames(2)
	assert_true(screen.tree_overview())
	PadInput.mouse_click(centre, MOUSE_BUTTON_WHEEL_UP)
	await wait_process_frames(2)
	assert_false(screen.tree_overview())

func test_a_click_on_empty_space_changes_nothing() -> void:
	_discover_all()
	_open_tree()
	var empty := _empty_point()
	assert_ne(empty, Vector2(-1, -1), "the box has a gap somewhere")
	var sel := screen.selected_id()
	PadInput.mouse_click(empty)
	await wait_process_frames(2)
	assert_eq(screen.selected_id(), sel)
	assert_false(screen.tree_overview())
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tools/run_tests.sh tree_tab`
Expected: `FAIL: 2 of 14 failed`. `test_a_real_click_on_a_node_selects_it_while_the_tree_is_paused` fails because the selection is unchanged, and `test_the_wheel_flips_the_zoom` fails because the overview stays false: nothing listens to the view's signals yet. The empty-space test passes already.

- [ ] **Step 3: Write the minimal implementation**

In `scripts/ui/skill_screen.gd`, in `_refresh_tree()`, after `view.show_model(_tree_model, _tree_sel, _tree_overview)`, add:

```gdscript
	view.node_clicked.connect(select_tree_node)
	view.zoom_requested.connect(set_tree_overview)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `tools/run_tests.sh tree_tab && tools/run_tests.sh mouse_input`
Expected: `PASS: 14 tests`, then `PASS: <n> tests`.

If the click test is still red, the stretch mapping is wrong, not the screen. Print `get_tree().root.get_final_transform()` and the panel's global rect in the test, and fix `PadInput.mouse_click`. Do not move the click handling into `_unhandled_input`.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/skill_screen.gd tests/support/pad_input.gd tests/test_tree_tab.gd
git commit -m "feat(ui): click a tree node to select it and wheel to zoom"
```

### Task 11: `tools/tree_shots.gd`

**Files:**
- Create: `tools/tree_shots.gd` (modelled on `tools/evolution_shots.gd`)

**Interfaces:**
- Consumes:
  - `game.skill_screen` (`scripts/game.gd:21`);
  - `SkillScreen.switch_tab`, `set_tree_overview` and `select_tree_node` (Task 9);
  - `CompendiumModel.store`, `_states`, `states()` and `raise()` (`scripts/compendium/compendium_model.gd:13,16,40,43`);
  - `SkillRulesEngine.grant` (`scripts/skills/skill_rules_engine.gd:163`).
- Produces: `.tmp/tree/{nothing,some,everything}_{normal,overview}.png` and `.tmp/tree/everything_spore_cloud.png`.

- [ ] **Step 1: Write the tool**

Create `tools/tree_shots.gd`:

```gdscript
extends SceneTree
## Real-renderer shots of the Tree tab at both zooms with nothing, some and everything discovered. Run from the project
## root with the windowed renderer (--headless has no texture to read):
##   env HOME="$PWD/.tmp/gdhome" godot --path . -s res://tools/tree_shots.gd
## Writes .tmp/tree/*.png. It saves nothing: the Compendium's store is detached before anything is raised.

const OUT := "res://.tmp/tree/"
var game
var frame := 0

func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("%s%s.png" % [OUT, n]))

func _compendium() -> CompendiumModel:
	return root.get_node("Compendium").model

## Every slot back to Unknown, in memory only, then the starting power Owned-once, as a new soul has it.
func _forget_everything() -> void:
	var c := _compendium()
	c.store = null
	for id in c.states():
		c._states[id] = CompendiumModel.State.UNKNOWN
	c.raise("appraisal", CompendiumModel.State.OWNED_ONCE)

func _discover_some() -> void:
	var c := _compendium()
	root.get_node("SkillRules").grant("hydraulic_propulsion")
	c.raise("hydraulic_propulsion", CompendiumModel.State.OWNED_ONCE)
	c.raise("poison_breath", CompendiumModel.State.NAMED)
	c.raise("leap", CompendiumModel.State.HINTED)

func _discover_everything() -> void:
	var c := _compendium()
	for id in c.states():
		c.raise(id, CompendiumModel.State.OWNED_ONCE)

func _process(_delta: float) -> bool:
	var screen: SkillScreen = game.skill_screen
	frame += 1
	match frame:
		30:
			_forget_everything()
			screen.open()
			screen.switch_tab(1)
		36:
			_shot("nothing_normal")
			screen.set_tree_overview(true)
		42:
			_shot("nothing_overview")
			_discover_some()
			screen.switch_tab(1)
		48:
			_shot("some_normal")
			screen.set_tree_overview(true)
		54:
			_shot("some_overview")
			_discover_everything()
			screen.switch_tab(1)
		60:
			_shot("everything_normal")
			screen.select_tree_node("spore_cloud")
		66:
			_shot("everything_spore_cloud")
			screen.set_tree_overview(true)
		72:
			_shot("everything_overview")
		78:
			quit()
	return false
```

- [ ] **Step 2: Run it and check the output**

The windowed renderer needs the sandbox off: run this Bash call with `dangerouslyDisableSandbox: true`, and say so in the report.

Run: `mkdir -p .tmp/tree && rm -f .tmp/tree/*.png && gtimeout -k 5 120 env HOME="$PWD/.tmp/gdhome" godot --path . -s res://tools/tree_shots.gd > .tmp/test-logs/tree_shots.log 2>&1; ls .tmp/tree/*.png | wc -l; grep -cE 'SCRIPT ERROR|Parse Error' .tmp/test-logs/tree_shots.log`
Expected: `7`, then `0`.

Open the seven PNGs with the Read tool and check:
- `nothing_*` shows only Appraisal;
- `some_*` shows Hydraulic Propulsion with two `???` stubs, Poison Breath with no branches, and Leap;
- `everything_normal` names every node in the box with no label cut off.

The full legibility verdict waits for the forms band (Task 16).

- [ ] **Step 3: Commit**

```bash
git add tools/tree_shots.gd tools/tree_shots.gd.uid
git commit -m "chore(tools): screenshots of the Tree tab at both zooms"
```

---

## Step 2: the forms band

### Task 12: `forms_reached` on `WorldProgress`

**Files:**
- Modify: `scripts/world/world_progress.gd` (doc comment :3-4, member vars :12-22, `_init` :24-31, `_save` :94-102)
- Test: `tests/test_world_progress.gd`

**Interfaces:**
- Consumes (existing):
  - `Profile.list_section(name) -> Array` (`scripts/persistence/profile.gd:49`), which drops a malformed section with a warning;
  - `Profile.set_section`, `.save` and `.warn`;
  - `Form.BASE == "slime"` (`scripts/forms/form.gd`).
- Produces: `WorldProgress.forms_reached: Array`, `reach_form(id: String)` and `is_form_reached(id: String) -> bool`. `is_form_reached` is true for `"slime"`, which `reach_form` never stores.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_world_progress.gd`:

```gdscript
# --- reached forms ---

func test_the_slime_is_reached_by_definition_and_never_stored() -> void:
	var w := WorldProgress.new()
	assert_true(w.is_form_reached("slime"))
	w.reach_form("slime")
	w.reach_form("")
	assert_eq(w.forms_reached, [])

func test_reached_forms_are_unique_and_survive_a_reload() -> void:
	var w := WorldProgress.new(_profile())
	w.reach_form("weaver")
	w.reach_form("weaver")
	w.reach_form("snare")
	assert_eq(w.forms_reached, ["weaver", "snare"])
	var again := WorldProgress.new(_profile())
	assert_eq(again.forms_reached, ["weaver", "snare"])
	assert_true(again.is_form_reached("snare"))
	assert_false(again.is_form_reached("arachne"))

func test_other_saves_keep_the_reached_forms() -> void:
	var w := WorldProgress.new(_profile())
	w.reach_form("tide")
	w.visit("C2")
	w.sanitize(["C1"])
	assert_eq(WorldProgress.new(_profile()).forms_reached, ["tide"])

func test_a_malformed_forms_section_is_dropped_with_a_warning() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var f := FileAccess.open(dir.path_join("profile.json"), FileAccess.WRITE)
	f.store_string('{"version": 1, "forms_reached": ["weaver", 3], "map": ["C1"]}')
	f.close()
	var warnings: Array = []
	var p := Profile.new(dir.path_join("profile.json"))
	p.warn = func(msg: String) -> void: warnings.append(msg)
	p.reload()
	var w := WorldProgress.new(p)
	assert_eq(w.forms_reached, [])
	assert_eq(w.visited, ["C1"], "the other sections still load")
	assert_eq(warnings.size(), 1)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tools/run_tests.sh world_progress`
Expected: `FAIL: engine error or empty run`. The log shows `Parse Error` that function `is_form_reached()` is not found in base `WorldProgress`.

- [ ] **Step 3: Write the minimal implementation**

In `scripts/world/world_progress.gd`, make the following edits.

1. Replace the class doc comment:

```gdscript
## What the player has found, kept across runs: visited rooms (the map), opened shortcuts, read tablets and the body
## forms reached in any life. Saves through the Profile when one is given; without one it lives in memory.
```

2. Add after `var rebirths: Array = []`:

```gdscript
## Body forms reached in any life (the Tree tab keeps them). The base slime is reached by definition and never stored.
var forms_reached: Array = []
```

3. In `_init`, after `rebirths = profile.list_section("rebirths")`, add:

```gdscript
		forms_reached = profile.list_section("forms_reached")
```

4. Add after `is_attuned()`:

```gdscript
## Written by the game when Player.form_advanced fires.
func reach_form(id: String) -> void:
	if id == "" or id == Form.BASE or forms_reached.has(id):
		return
	forms_reached.append(id)
	_save()

func is_form_reached(id: String) -> bool:
	return id == Form.BASE or forms_reached.has(id)
```

5. In `_save()`, add after `profile.set_section("rebirths", rebirths.duplicate())`:

```gdscript
	profile.set_section("forms_reached", forms_reached.duplicate())
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `tools/run_tests.sh world_progress && tools/run_tests.sh profile`
Expected: `PASS: 8 tests`, then `PASS: <n> tests`.

- [ ] **Step 5: Commit**

```bash
git add scripts/world/world_progress.gd tests/test_world_progress.gd
git commit -m "feat(world): remember the body forms reached in any life"
```

### Task 13: `Player.form_advanced` and the game's wiring

**Files:**
- Modify: `scripts/player/player.gd` (signals :5-7, `advance_form` :596-614)
- Modify: `scripts/game.gd` (after `skill_screen.bind_world(world, progress)`, ~84)
- Test: `tests/test_forms_reached.gd` (create)

**Interfaces:**
- Consumes:
  - `WorldProgress.reach_form` / `is_form_reached` / `forms_reached` (Task 12);
  - `Player.advance_form(id, force := false) -> bool` (`scripts/player/player.gd:596`);
  - `Game.play_request` and `game.world.ctx["progress"]` (`scripts/game.gd:50-56`, as `tests/test_editor_play.gd:57-70` reads it);
  - `Compendium.progress`.
- Produces: `signal form_advanced(id: String)` on `Player`, emitted only from a successful `advance_form`. `Game` connects it to the run's progress (the real one, or an editor Play's in-memory one).

- [ ] **Step 1: Write the failing tests**

Create `tests/test_forms_reached.gd`:

```gdscript
extends GutTest
## Reached forms: the player says when a body evolution succeeds, and the game records it in the world's progress (the
## real profile, or an editor Play's own in-memory progress).

var game: Game
var _reached_before: Array = []

func before_each() -> void:
	Game.play_request = {}
	Game.editor_resume = null
	_reached_before = Compendium.progress.forms_reached.duplicate()

func after_each() -> void:
	Game.play_request = {}
	Game.editor_resume = null
	get_tree().paused = false
	SkillRules.reset_run()
	Announcer.queue.clear()
	Compendium.progress.forms_reached = _reached_before
	Compendium.progress._save()  # the suite's profile outlives the run: leave it as it was

func _player() -> Player:
	var skills := DefLoader.load_dir("res://data/skills")
	var creature_list := DefLoader.load_dir("res://data/creatures")
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	var p := Player.new()
	p.setup(rules, CompendiumModel.new(skills, creature_list), creature_list, func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(p)
	rules.start_run()
	return p

func test_the_signal_fires_on_a_successful_evolution_and_not_on_a_refused_one() -> void:
	var p := _player()
	var got: Array = []
	p.form_advanced.connect(func(id: String) -> void: got.append(id))
	assert_false(p.advance_form("weaver"), "below the level cap")
	assert_false(p.advance_form("snare", true), "not a child of the slime")
	assert_eq(got, [])
	assert_true(p.advance_form("weaver", true))
	assert_eq(got, ["weaver"])

func test_the_game_records_a_reached_form_and_a_new_life_keeps_it() -> void:
	Compendium.progress.forms_reached.erase("weaver")
	var first: Game = load("res://scenes/main.tscn").instantiate()
	add_child(first)
	await wait_physics_frames(3)
	assert_true(first.player.advance_form("weaver", true))
	assert_true(Compendium.progress.is_form_reached("weaver"))
	first.queue_free()
	await wait_process_frames(2)
	game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(3)
	assert_eq(game.player.form.stage, 1, "a new life starts as a slime")
	assert_true(game.world.ctx["progress"].is_form_reached("weaver"), "and the soul still has the form it reached")

func test_an_editor_play_records_it_in_its_own_progress_only() -> void:
	Compendium.progress.forms_reached.erase("tide")
	var real_before: Array = Compendium.progress.forms_reached.duplicate()
	Game.play_request = {"rooms": World.load_rooms("res://data/rooms"), "room": "C2", "pos": Vector2(200, 250)}
	game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(3)
	assert_true(game.player.advance_form("tide", true))
	assert_true(game.world.ctx["progress"].is_form_reached("tide"))
	assert_eq(Compendium.progress.forms_reached, real_before, "an editor Play never reaches the real profile")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `gtimeout -k 5 180 env HOME="$PWD/.tmp/gdhome" godot --headless --import > .tmp/test-logs/import.log 2>&1; tools/run_tests.sh forms_reached`
Expected: `FAIL: engine error or empty run`. The log shows a `Parse Error` that member `form_advanced` is not found in base `Player`.

- [ ] **Step 3: Write the minimal implementation**

In `scripts/player/player.gd`, add after `signal not_enough_mp(skill_id: String)`:

```gdscript
## A body evolution succeeded (advance_form): the game records the form as reached.
signal form_advanced(id: String)
```

In `advance_form`, add after `EventBus.world_event.emit("evolved_body", {"id": id, "stage": form.stage})`:

```gdscript
	form_advanced.emit(id)
```

In `scripts/game.gd`, after `skill_screen.bind_world(world, progress)`, add:

```gdscript
	# The run's progress, so an editor Play's evolutions stay in its own in-memory progress.
	player.form_advanced.connect(progress.reach_form)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `tools/run_tests.sh forms_reached && tools/run_tests.sh editor_play && tools/run_tests.sh form_tab`
Expected: `PASS: 3 tests`, then two `PASS: <n> tests` lines.

- [ ] **Step 5: Commit**

```bash
git add scripts/player/player.gd scripts/game.gd tests/test_forms_reached.gd tests/test_forms_reached.gd.uid
git commit -m "feat(player): form_advanced records a reached form in the run's progress"
```

### Task 14: `form_card`, shared by the Form tab and the Tree tab

**Files:**
- Modify: `scripts/ui/skill_screen_model.gd` (add after `tree_card`)
- Modify: `scripts/ui/skill_screen.gd` (`_build_form`, the card part :704-721)
- Test: `tests/test_form_tab.gd`

**Interfaces:**
- Consumes:
  - `FormEffects.stat_lines(def) -> Array` and `FormEffects.TRAITS` (`scripts/forms/form_effects.gd:8,35`);
  - `rules.is_retired(id)` and `rules.get_def(id)`;
  - the existing grant-hiding behaviour (`scripts/ui/skill_screen.gd:714-721`).
- Produces: `SkillScreenModel.form_card(def: FormDef, rules) -> Dictionary`, with `{"name": String, "stage": int, "blurb": String, "stats": Array, "traits": Array, "grants": String}`. `"grants"` is `"Grants: A, B"` over the grants whose skill has not retired, or `""`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_form_tab.gd`:

```gdscript
# --- form_card: the card the Form tab and the Tree tab share ---

class FakeRules:
	var retired: Array = []
	var defs := {}

	func is_retired(id: String) -> bool:
		return retired.has(id)

	func get_def(id: String) -> SkillDef:
		return defs.get(id)

func test_form_card_names_the_stats_traits_and_the_grants_still_receivable() -> void:
	var tide: FormDef = player.forms["tide"]
	var fake := FakeRules.new()
	for d in skills:
		fake.defs[d.id] = d
	var card := SkillScreenModel.form_card(tide, fake)
	assert_eq(card["name"], tide.display_name)
	assert_eq(card["stage"], 2)
	assert_eq(card["blurb"], tide.blurb)
	assert_eq(card["stats"], FormEffects.stat_lines(tide))
	assert_eq(card["traits"], tide.traits.map(func(t): return FormEffects.TRAITS.get(t, str(t))))
	assert_eq(card["grants"], "Grants: Hydraulic Propulsion")
	fake.retired = ["hydraulic_propulsion"]
	assert_eq(SkillScreenModel.form_card(tide, fake)["grants"], "", "a retired grant is hidden")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tools/run_tests.sh form_tab`
Expected: `FAIL: engine error or empty run`. The log shows `Parse Error` that static function `form_card()` is not found in `SkillScreenModel`.

- [ ] **Step 3: Write the minimal implementation**

In `scripts/ui/skill_screen_model.gd`, add after `tree_card()`:

```gdscript
## A form's card, shared by the Form tab and the Tree tab: {"name", "stage", "blurb", "stats", "traits", "grants"}.
## "grants" lists only the grants the player can still receive: a grant whose skill has retired is hidden.
static func form_card(def: FormDef, rules) -> Dictionary:
	var names: Array = []
	for g in def.grants:
		if rules.is_retired(g):
			continue  # the player evolved it: the form can no longer give it
		var sd = rules.get_def(g)
		names.append(sd.display_name if sd != null else g)
	return {"name": def.display_name, "stage": def.stage, "blurb": def.blurb, "stats": FormEffects.stat_lines(def),
		"traits": def.traits.map(func(t): return FormEffects.TRAITS.get(t, str(t))),
		"grants": "" if names.is_empty() else "Grants: " + ", ".join(names)}
```

In `scripts/ui/skill_screen.gd`, in `_build_form()`, replace everything from `_label(_detail, sel.display_name, ...` to the end of the function with:

```gdscript
	var card := SkillScreenModel.form_card(sel, _rules)
	_label(_detail, card["name"], Vector2(DETAIL_X, 122), Vector2(190, 16), FONT_BIG, Color.WHITE)
	_label(_detail, "Stage %d" % card["stage"], Vector2(DETAIL_X, 138), Vector2(190, 12), FONT_SMALL, COL_TITLE)
	_label(_detail, card["blurb"], Vector2(DETAIL_X, 152), Vector2(190, 34), FONT_SMALL, Color.WHITE, true)
	var dy := 190.0
	for line in card["stats"]:
		_label(_detail, line, Vector2(DETAIL_X, dy), Vector2(190, 12), FONT_SMALL, COL_DIM)
		dy += 11.0
	for t in card["traits"]:
		_label(_detail, t, Vector2(DETAIL_X, dy), Vector2(190, 22), FONT_SMALL, COL_TITLE, true)
		dy += 22.0
	if card["grants"] != "":
		_label(_detail, card["grants"], Vector2(DETAIL_X, dy), Vector2(190, 24), FONT_SMALL, Color.WHITE, true)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `tools/run_tests.sh form_tab`
Expected: `PASS: 21 tests`. The existing `test_the_form_card_lists_a_receivable_grant` and `test_the_form_card_omits_grants_the_player_has_retired` are the safety net for the refactor.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/skill_screen_model.gd scripts/ui/skill_screen.gd tests/test_form_tab.gd
git commit -m "refactor(ui): extract form_card so the Form and Tree tabs share one card"
```

### Task 15: The forms band: form nodes, "opens" edges, the Greater rule and the form card on the tree

**Files:**
- Modify: `scripts/ui/skill_tree_model.gd` (`build`, `_row_powers`, plus new functions)
- Modify: `scripts/ui/skill_screen_model.gd` (`tree_card`, plus `FORM_STATUS` and `_form_tree_card`)
- Modify: `scripts/ui/skill_screen.gd` (`_refresh_tree`)
- Test: `tests/test_skill_tree_model.gd`, `tests/test_skill_tree_view.gd`, `tests/test_tree_tab.gd`

**Interfaces:**
- Consumes:
  - `FormLoader.load_all()`, `stage2_forms(forms)` (id order) and `children_of` (`scripts/forms/form_loader.gd`);
  - `FormDef.stage`, `lineage`, `parents` and `display_name` (`scripts/forms/form_def.gd`);
  - `FormOffers.LINEAGE_ORDER` (`scripts/forms/form_offers.gd:9`);
  - `Form.BASE`;
  - `WorldProgress.forms_reached` (Task 12) through `SkillScreen._progress` (bound by `bind_world`, `scripts/ui/skill_screen.gd:564`);
  - `SkillScreenModel.form_card` (Task 14).
- Consumes, from the essence overhaul plan: `FormDef.powers` and `FormOffers.open_lineages(forms, rules)`.
- Produces:
  - `build()` now returns form nodes (`"kind": "form"`, states `CURRENT`, `REACHED`, `NAMED` or `STUB`; the slime is id `"slime"`, `CURRENT` or `REACHED`);
  - edges of kind `"grows"` (parent → child, so the slime → each stage-2 form) and `"opens"` (power → its lineage's stage-2 form);
  - constants `GREATER := "greater"` and `BAND_GAP := 16.0`;
  - `_row_powers(defs, forms)` orders the powers that open a lineage by `LINEAGE_ORDER`;
  - `SkillScreenModel.FORM_STATUS`;
  - `tree_card` handles form nodes;
  - `SkillScreen._reached_forms() -> Array`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_skill_tree_model.gd`:

```gdscript
# --- the forms band ---

func _forms() -> Dictionary:
	return FormLoader.load_all()

func _assert_walk_reaches_everything(m: Dictionary) -> void:
	var seen := _walk(m)
	for id in m["nodes"]:
		assert_true(seen.has(id), "%s is reachable from %s" % [id, SkillTreeModel.root(m)])

func test_a_new_soul_sees_the_slime_and_the_greater_slime_on_offer() -> void:
	var nodes: Dictionary = _build(_forms())["nodes"]
	assert_eq(nodes["slime"]["state"], SkillTreeModel.CURRENT)
	assert_eq(nodes["greater_slime"]["state"], SkillTreeModel.NAMED, "no lineage is open, so the Form tab would offer it")
	for id in ["vast", "radiant"]:
		assert_eq(nodes[id]["state"], SkillTreeModel.STUB, id)
	assert_false(nodes.has("prime"), "a stage-4 form waits for a named parent")
	for id in ["weaver", "tide", "toxic", "bulwark", "echo"]:
		assert_false(nodes.has(id), id + ": no power that opens it is known")

func test_an_open_lineage_names_its_stage_two_form_and_stubs_its_children() -> void:
	assert_true(_forms()["weaver"].powers.has("sticky_thread"))
	rules.grant("sticky_thread")  # level 1: the Weaver lineage is open this life
	var m := _build(_forms())
	var nodes: Dictionary = m["nodes"]
	assert_eq(nodes["weaver"]["state"], SkillTreeModel.NAMED)
	for id in ["arachne", "snare"]:
		assert_eq(nodes[id]["state"], SkillTreeModel.STUB, id)
	assert_false(nodes.has("silkbound"))
	var opens: Array = m["edges"].filter(func(e): return e["kind"] == "opens" and e["to"] == "weaver")
	assert_eq(opens.map(func(e): return e["from"]), ["sticky_thread"])

func test_a_power_known_but_not_reached_this_life_shows_its_lineage_as_a_stub() -> void:
	assert_true(_forms()["echo"].powers.has("echolocation"))
	compendium.raise("echolocation", CompendiumModel.State.NAMED)
	var nodes: Dictionary = _build(_forms())["nodes"]
	assert_eq(nodes["echo"]["state"], SkillTreeModel.STUB)
	assert_false(nodes.has("phantom"), "a stub's children stay hidden")

func test_greater_slime_is_a_stub_once_two_lineages_open_unless_it_was_reached() -> void:
	rules.grant("sticky_thread")
	rules.grant("hydraulic_propulsion")
	assert_eq(_build(_forms())["nodes"]["greater_slime"]["state"], SkillTreeModel.STUB)
	assert_eq(_build(_forms(), ["greater_slime"])["nodes"]["greater_slime"]["state"], SkillTreeModel.REACHED)

func test_forms_reached_in_earlier_lives_stay_on_the_tree() -> void:
	var nodes: Dictionary = _build(_forms(), ["weaver", "snare"])["nodes"]
	assert_eq(nodes["weaver"]["state"], SkillTreeModel.REACHED, "shown though no power that opens it is known this life")
	assert_eq(nodes["snare"]["state"], SkillTreeModel.REACHED)
	assert_eq(nodes["arachne"]["state"], SkillTreeModel.STUB)
	assert_eq(nodes["silkbound"]["state"], SkillTreeModel.STUB, "a stage-4 stub once a parent is named")
	assert_eq(nodes["slime"]["state"], SkillTreeModel.CURRENT)

func test_the_current_form_is_current_and_the_slime_is_reached() -> void:
	var nodes: Dictionary = _build(_forms(), ["weaver"], "weaver")["nodes"]
	assert_eq(nodes["weaver"]["state"], SkillTreeModel.CURRENT)
	assert_eq(nodes["slime"]["state"], SkillTreeModel.REACHED)

func test_a_stale_reached_id_from_an_old_save_is_ignored() -> void:
	var m := _build(_forms(), ["no_such_form", "weaver"])
	assert_false(m["nodes"].has("no_such_form"))
	assert_eq(m["nodes"]["weaver"]["state"], SkillTreeModel.REACHED)

func test_fully_discovered_every_form_shows_with_its_edges() -> void:
	_discover_all()
	var all_forms := _forms()
	var m := _build(all_forms, all_forms.keys())
	var nodes: Dictionary = m["nodes"]
	assert_eq(nodes["slime"]["kind"], "form")
	for id in all_forms:
		assert_eq(nodes[id]["kind"], "form", id)
	assert_eq(nodes.size(), _player_skill_ids().size() + all_forms.size() + 1)
	for f in FormLoader.stage2_forms(all_forms):
		var opens: Array = m["edges"].filter(func(e): return e["kind"] == "opens" and e["to"] == f.id)
		assert_eq(opens.size(), f.powers.size(), f.id + ": one opens edge per power it lists")
		var from_slime: Array = m["edges"].filter(func(e): return e["from"] == "slime" and e["to"] == f.id)
		assert_eq(from_slime.size(), 1, f.id)
	for e in m["edges"]:
		assert_true(nodes.has(e["from"]) and nodes.has(e["to"]), str(e))

func test_discovering_a_form_never_moves_another_node() -> void:
	rules.grant("sticky_thread")
	var before := _rects(_build(_forms()))
	_discover_all()
	var after := _rects(_build(_forms(), _forms().keys()))
	for id in before:
		assert_eq(after[id], before[id], id)

func test_the_full_tree_has_no_overlap_fits_its_labels_and_walks_from_the_root() -> void:
	_discover_all()
	var m := _build(_forms(), _forms().keys())
	_assert_no_overlap(_rects(m))
	var room := SkillTreeModel.NODE_SIZE.x - 2.0 * SkillTreeModel.LABEL_INSET
	for id in m["nodes"]:
		var w := ThemeDB.fallback_font.get_string_size(m["nodes"][id]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, SkillScreen.FONT_SMALL).x
		assert_lte(w, room, m["nodes"][id]["name"])
	_assert_walk_reaches_everything(m)

func test_the_powers_that_open_a_lineage_are_rowed_in_lineage_order() -> void:
	_discover_all()
	var all_forms := _forms()
	var nodes: Dictionary = _build(all_forms, all_forms.keys())["nodes"]
	var order: Array = []
	for lineage in FormOffers.LINEAGE_ORDER:
		for f in FormLoader.stage2_forms(all_forms):
			if f.lineage == lineage:
				for p in f.powers:
					if not order.has(p):
						order.append(p)
	assert_gt(order.size(), 1)
	for i in range(1, order.size()):
		var above: Vector2 = nodes[order[i - 1]]["pos"]
		var below: Vector2 = nodes[order[i]]["pos"]
		assert_lt(above.y, below.y, "%s above %s" % [order[i - 1], order[i]])
		assert_eq(below.x, 0.0, order[i] + " is a row power, in column 0")

func test_the_canvas_is_no_taller_than_two_boxes() -> void:
	_discover_all()
	var m := _build(_forms(), _forms().keys())
	assert_lte(m["size"].y, 2.0 * SkillTreeView.BOX.size.y)
```

Append to `tests/test_skill_tree_view.gd`:

```gdscript
func test_with_the_forms_band_every_group_is_no_taller_than_the_box_and_shares_the_screen_when_it_fits() -> void:
	var forms := FormLoader.load_all()
	model = SkillTreeModel.build(rules, compendium, forms, forms.keys(), "slime")
	for id in model["nodes"]:
		var group := SkillTreeView.neighborhood(model, id)
		assert_lte(group.size.y, _box().size.y, id + " and its neighbors stack within one box")
		if group.size.x > _box().size.x:
			continue  # a stage-2 or stage-3 form's neighbors span three columns: see the Self-Review
		var cam := SkillTreeView.camera(model, id, false)
		assert_true(_box().encloses(Rect2(cam["offset"] + group.position, group.size)), id)
```

Append to `tests/test_tree_tab.gd`:

```gdscript
# --- the forms band ---

func test_the_tree_shows_the_forms_band_and_reads_reached_forms_from_the_progress() -> void:
	var progress := WorldProgress.new()
	progress.reach_form("weaver")
	screen.bind_world(null, progress)
	_open_tree()
	var nodes: Dictionary = screen.tree_model()["nodes"]
	assert_eq(nodes["slime"]["state"], SkillTreeModel.CURRENT)
	assert_eq(nodes["weaver"]["state"], SkillTreeModel.REACHED)

func test_a_form_card_shows_its_stage_blurb_and_grants_and_a_form_stub_shows_no_name() -> void:
	_open_tree()
	screen.select_tree_node("greater_slime")
	var gs: FormDef = player.forms["greater_slime"]
	var card := "\n".join(screen.detail_texts())
	assert_string_contains(card, gs.display_name)
	assert_string_contains(card, "Stage 2")
	assert_string_contains(card, "Grants: " + rules.get_def("regeneration").display_name)
	screen.select_tree_node("vast")
	card = "\n".join(screen.detail_texts())
	assert_string_contains(card, "???")
	assert_false(card.contains(player.forms["vast"].display_name))
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tools/run_tests.sh skill_tree_model`
Expected: `FAIL: engine error or empty run`. The log shows `SCRIPT ERROR: Invalid access to key "slime"` and similar form ids. Nine of the twelve new tests fail; `test_discovering_a_form_never_moves_another_node`, `test_the_full_tree_has_no_overlap_fits_its_labels_and_walks_from_the_root` and `test_the_canvas_is_no_taller_than_two_boxes` already pass on the power band alone, and stay as guards.

Run: `tools/run_tests.sh tree_tab`
Expected: `FAIL: engine error or empty run`, from the missing `slime` and `greater_slime` nodes.

- [ ] **Step 3: Write the minimal implementation**

In `scripts/ui/skill_tree_model.gd`, make the following edits.

1. Add after `GRID_COLS`:

```gdscript
## The lineage of Greater Slime, which no power opens.
const GREATER := "greater"
## Between the power band and the form band.
const BAND_GAP := 16.0
```

2. Replace `build()` and its comment:

```gdscript
## {"nodes": {id: node}, "edges": [{"from", "to", "kind", "known"}], "size": Vector2}. Every edge joins two nodes in "nodes";
## each node's "pos" is its top-left corner on the canvas at the normal zoom. The power band sits above the form band.
static func build(rules, compendium: CompendiumModel, forms: Dictionary, reached_forms: Array, current_form: String) -> Dictionary:
	var defs := _skill_defs(rules, compendium)
	var by_id := {}
	for d in defs:
		by_id[d.id] = d
	var nodes := {}
	for d in defs:
		var n := _skill_node(rules, compendium, d, by_id)
		if not n.is_empty():
			nodes[d.id] = n
	nodes.merge(_form_nodes(rules, forms, reached_forms, current_form, nodes))
	var edges: Array = []
	for d in defs:
		if d.source == "evolution" and d.replaces != "":
			edges.append({"from": d.replaces, "to": d.id, "kind": "evolves"})
	for id in _sorted_keys(forms):
		var f: FormDef = forms[id]
		for p in f.parents:
			edges.append({"from": p, "to": id, "kind": "grows"})
		if f.stage == 2:
			for pw in f.powers:
				edges.append({"from": pw, "to": id, "kind": "opens"})
	var row_powers := _row_powers(defs, forms)
	var slots := _power_slots(defs, row_powers, nodes)
	if not forms.is_empty():
		slots.merge(_form_slots(forms, _band_rows(defs, row_powers) * ROW_PITCH + BAND_GAP))
	for id in nodes:
		nodes[id]["pos"] = slots[id]
	return {"nodes": nodes, "edges": _visible_edges(nodes, edges), "size": _canvas(slots)}
```

3. Replace `_row_powers()` and its comment:

```gdscript
## The powers drawn one per row, with their evolutions beside them. First come the powers that open a lineage, in
## FormOffers.LINEAGE_ORDER and each stage-2 form's own order, so the "opens" edges run to adjacent rows instead of crossing.
## Then any other power that evolves, in id order.
static func _row_powers(defs: Array, forms: Dictionary) -> Array:
	var known := defs.map(func(d): return d.id)
	var out: Array = []
	for lineage in FormOffers.LINEAGE_ORDER:
		for f in FormLoader.stage2_forms(forms):
			if f.lineage != lineage:
				continue
			for p in f.powers:
				if known.has(p) and not out.has(p):
					out.append(p)
	for d in defs:
		if d.source != "evolution" and not out.has(d.id) and not _evolutions_of(defs, d.id).is_empty():
			out.append(d.id)
	return out
```

4. Add at the end of the file:

```gdscript
## Rows the power band takes: the row powers' or the grid's, whichever is more. Every secret counts as a cell, owned or
## not, so owning one never moves the form band.
static func _band_rows(defs: Array, row_powers: Array) -> int:
	var rows := 0
	for id in row_powers:
		rows += maxi(1, _evolutions_of(defs, id).size())
	var cells := defs.filter(func(d): return d.source != "evolution" and not row_powers.has(d.id)).size()
	return maxi(rows, ceili(cells / float(GRID_COLS)))

## The form band's nodes, or {} without forms.
## - The slime is always there: current, or reached by definition.
## - A stage-2 form shows once a power that opens it shows, or once reached. It is named when reached or when its lineage
##   is open this life (FormOffers.open_lineages, the same function that decides the Form tab's first offers).
## - Greater Slime has no opening power. It is always there, named when reached or on offer (fewer than two lineages open).
## - A stage-3 or stage-4 form is a stub once a parent is named, and named only when reached.
static func _form_nodes(rules, forms: Dictionary, reached: Array, current: String, skill_nodes: Dictionary) -> Dictionary:
	var out := {}
	if forms.is_empty():
		return out
	out[Form.BASE] = {"id": Form.BASE, "kind": "form", "state": CURRENT if current == Form.BASE else REACHED, "name": "Slime"}
	var open: Array = FormOffers.open_lineages(forms, rules)
	for f in FormLoader.stage2_forms(forms):
		var greater: bool = f.lineage == GREATER
		var named: bool = reached.has(f.id) or f.id == current or (open.size() < 2 if greater else open.has(f.lineage))
		if named or greater or f.powers.any(func(p): return skill_nodes.has(p)):
			out[f.id] = _form_node(f, named, reached, current)
	for stage in [3, 4]:
		for id in _sorted_keys(forms):
			var f: FormDef = forms[id]
			if f.stage == stage and f.parents.any(func(p): return out.has(p) and out[p]["state"] != STUB):
				out[id] = _form_node(f, reached.has(id) or id == current, reached, current)
	return out

static func _form_node(f: FormDef, named: bool, reached: Array, current: String) -> Dictionary:
	if not named:
		return {"id": f.id, "kind": "form", "state": STUB}
	var state := CURRENT if f.id == current else (REACHED if reached.has(f.id) else NAMED)
	return {"id": f.id, "kind": "form", "state": state, "name": f.display_name}

## The form band from canvas y `top`: the stage across (the slime in column 0, then stages 2 to 4), two rows per lineage
## down (FormOffers.LINEAGE_ORDER, then greater). The stage-3 pair fills the two rows, stages 2 and 4 sit between them,
## and the slime sits level with the middle of the band. Every edge joins adjacent columns.
static func _form_slots(forms: Dictionary, top: float) -> Dictionary:
	var lineages: Array = FormOffers.LINEAGE_ORDER.duplicate()
	lineages.append(GREATER)
	var slots := {Form.BASE: Vector2(0, top + (lineages.size() - 0.5) * ROW_PITCH)}
	for li in lineages.size():
		var row := li * 2
		var thirds := 0
		for id in _sorted_keys(forms):
			var f: FormDef = forms[id]
			if f.lineage != lineages[li]:
				continue
			if f.stage == 3:
				slots[id] = Vector2(2 * COL_PITCH, top + (row + thirds) * ROW_PITCH)
				thirds += 1
			else:
				slots[id] = Vector2((f.stage - 1) * COL_PITCH, top + (row + 0.5) * ROW_PITCH)
	return slots

static func _sorted_keys(d: Dictionary) -> Array:
	var ids := d.keys()
	ids.sort()
	return ids
```

In `scripts/ui/skill_screen_model.gd`, in `tree_card()`, insert after the stub check's `return` line (before `var d: SkillDef = defs[node["id"]]`):

```gdscript
	if node["kind"] == "form":
		return _form_tree_card(rules, node, forms)
```

Then add after `tree_card()`:

```gdscript
## A shown form's status on the Tree tab.
const FORM_STATUS := {"current": "Your body now", "reached": "Reached before", "named": "Not yet reached"}

## The Tree tab's card for a shown form: form_card's stats, traits and grants, with its stage and whether it is the body now,
## was reached before, or is not yet reached. The slime is not a FormDef.
static func _form_tree_card(rules, node: Dictionary, forms: Dictionary) -> Dictionary:
	var status: String = FORM_STATUS[node["state"]]
	if not forms.has(node["id"]):
		return {"title": node["name"], "status": "Stage 1  " + status, "lines": ["Every life begins as a slime."]}
	var c := form_card(forms[node["id"]], rules)
	var lines: Array = [c["blurb"]]
	lines.append_array(c["stats"])
	lines.append_array(c["traits"])
	if c["grants"] != "":
		lines.append(c["grants"])
	return {"title": c["name"], "status": "Stage %d  %s" % [c["stage"], status], "lines": lines}
```

In `scripts/ui/skill_screen.gd`, make the following edits.

1. Add after `_refresh_tree()`:

```gdscript
## Forms reached in any life, from the bound progress (none without one).
func _reached_forms() -> Array:
	return _progress.forms_reached if _progress != null else []
```

2. In `_refresh_tree()`, replace the build line with:

```gdscript
	_tree_model = SkillTreeModel.build(_rules, _compendium, _player.forms, _reached_forms(), _player.form.form_id)
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `tools/run_tests.sh skill_tree_model && tools/run_tests.sh skill_tree_view && tools/run_tests.sh tree_tab && tools/run_tests.sh form_tab`
Expected: `PASS: 36 tests`, `PASS: 12 tests`, `PASS: 16 tests`, `PASS: 21 tests`.

If `test_the_full_tree_has_no_overlap_fits_its_labels_and_walks_from_the_root` names a node the walk cannot reach, the layout stranded it. Fix the slot, not `neighbor`, and do not weaken the walk.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/skill_tree_model.gd scripts/ui/skill_screen_model.gd scripts/ui/skill_screen.gd tests/test_skill_tree_model.gd tests/test_skill_tree_view.gd tests/test_tree_tab.gd
git commit -m "feat(ui): the forms band, with reached forms, opens edges and the Greater rule"
```

### Task 16: Shoot the full tree and judge the legibility bar

**Files:**
- Modify: `tools/tree_shots.gd`

**Interfaces:**
- Consumes:
  - `WorldProgress.forms_reached` and `.profile` (Task 12) via `root.get_node("Compendium").progress`;
  - `game.player.forms`;
  - `SkillScreen.select_tree_node` (Task 9).
- Produces: `.tmp/tree/everything_silkbound.png` and `.tmp/tree/everything_toxic.png` in addition to Task 11's shots, plus the verdict that decides the appendix.

- [ ] **Step 1: Extend the tool**

In `tools/tree_shots.gd`, make the following edits.

1. Replace `_forget_everything()`:

```gdscript
## Every slot back to Unknown and no form reached, in memory only, then the starting power Owned-once, as a new soul has it.
func _forget_everything() -> void:
	var c := _compendium()
	c.store = null
	for id in c.states():
		c._states[id] = CompendiumModel.State.UNKNOWN
	c.raise("appraisal", CompendiumModel.State.OWNED_ONCE)
	var progress = root.get_node("Compendium").progress
	progress.profile = null  # nothing below reaches the profile
	progress.forms_reached = []
```

2. Replace `_discover_some()`:

```gdscript
func _discover_some() -> void:
	var c := _compendium()
	root.get_node("SkillRules").grant("hydraulic_propulsion")
	c.raise("hydraulic_propulsion", CompendiumModel.State.OWNED_ONCE)
	c.raise("poison_breath", CompendiumModel.State.NAMED)
	c.raise("leap", CompendiumModel.State.HINTED)
	root.get_node("Compendium").progress.forms_reached = ["tide"]
```

3. Replace `_discover_everything()`:

```gdscript
func _discover_everything() -> void:
	var c := _compendium()
	for id in c.states():
		c.raise(id, CompendiumModel.State.OWNED_ONCE)
	root.get_node("Compendium").progress.forms_reached = game.player.forms.keys()
```

4. In `_process`, replace the `72:` and `78:` branches with:

```gdscript
		72:
			_shot("everything_overview")
			screen.set_tree_overview(false)
			screen.select_tree_node("silkbound")
		78:
			_shot("everything_silkbound")
			screen.select_tree_node("toxic")
		84:
			_shot("everything_toxic")
		90:
			quit()
```

- [ ] **Step 2: Run it**

Run this Bash call with `dangerouslyDisableSandbox: true` (windowed renderer).

Run: `mkdir -p .tmp/tree && rm -f .tmp/tree/*.png && gtimeout -k 5 120 env HOME="$PWD/.tmp/gdhome" godot --path . -s res://tools/tree_shots.gd > .tmp/test-logs/tree_shots.log 2>&1; ls .tmp/tree/*.png | wc -l; grep -cE 'SCRIPT ERROR|Parse Error' .tmp/test-logs/tree_shots.log`
Expected: `9`, then `0`.

- [ ] **Step 3: Judge the legibility bar by eye**

Open every PNG in `.tmp/tree/` with the Read tool. Judge `everything_normal`, `everything_spore_cloud`, `everything_silkbound` and `everything_toxic` against the spec's bar:
1. No two nodes overlap.
2. No edge runs through a node's label.
3. Every label fits its node, untruncated.
4. The selected node's card is readable beside the graph.
5. The selected node and its edge neighbors fit on one screen, with the camera following the selection.

The tests already pin 1 to 3, and pin 5 vertically. Item 5 has a **known spec conflict, pending Sean's decision**: a stage-2 or stage-3 form's neighbors span three columns (340 px) in the 244 px box, so its far neighbor is partly off-screen. `forms_focus` cannot fix it, so this case alone does not trigger Appendix A. Record it in the verdict and leave the decision to Sean.

Then decide:
- **The bar passes** (apart from the known spec conflict on item 5): the appendix is not built.
- **The bar fails** on anything else: build Appendix Task A next.

- [ ] **Step 4: Commit, with the verdict in the message body**

If the bar passes:

```bash
git add tools/tree_shots.gd
git commit -m "chore(tools): tree shots with the forms band" -m "Legibility bar: pass at 640x360 apart from the known stage-2/3 horizontal conflict (pending Sean); forms_focus not needed."
```

If it fails, name the failed item from Step 3 in the body. For example, for item 4:

```bash
git add tools/tree_shots.gd
git commit -m "chore(tools): tree shots with the forms band" -m "Legibility bar: fail (item 4, the card is unreadable beside the graph); Appendix A follows."
```

Then run the whole suite once:

Run: `TEST_TIMEOUT=900 tools/run_tests.sh`
Expected: `PASS: <n> tests` with no engine error.

---

## Appendix (conditional): Task A, `forms_focus`

**Build this only if Task 16's verdict is "fail".** It is the spec's "one evolution at a time" fallback. It is a model filter, so it needs no second view.

**Files:**
- Modify: `scripts/ui/skill_tree_model.gd` (`build` signature and body, plus `_focus`)
- Modify: `scripts/ui/skill_screen.gd` (`_refresh_tree`)
- Test: `tests/test_skill_tree_model.gd`

**Interfaces:**
- Consumes: `build`, `_visible_edges` and `_form_nodes` (Tasks 4 to 15); `FormLoader.children_of(forms, id)`.
- Produces: `SkillTreeModel.build(rules, compendium, forms, reached_forms, current_form, forms_focus := false)`. With `forms_focus`, the form band keeps only:
  - the current form;
  - the line it came by (its reached parents back to the slime, or all parents where none is reached);
  - its next stage, as named or stub, the same as without the filter.

  Every edge touching a dropped node goes too, the "opens" edges included. Positions and the power band are unchanged.

- [ ] **A.1: Write the failing test**

Append to `tests/test_skill_tree_model.gd`:

```gdscript
func test_forms_focus_keeps_the_current_form_its_line_and_its_next_stage() -> void:
	_discover_all()
	var all_forms := _forms()
	var m := SkillTreeModel.build(rules, compendium, all_forms, ["weaver", "snare"], "snare", true)
	var nodes: Dictionary = m["nodes"]
	var form_ids: Array = nodes.keys().filter(func(id): return nodes[id]["kind"] == "form")
	form_ids.sort()
	assert_eq(form_ids, ["silkbound", "slime", "snare", "weaver"])
	for e in m["edges"]:
		assert_true(nodes.has(e["from"]) and nodes.has(e["to"]), str(e))
	var full: Dictionary = _build(all_forms, ["weaver", "snare"], "snare")["nodes"]
	for id in full:
		if full[id]["kind"] != "form":
			assert_true(nodes.has(id), id + ": the power band is unchanged")
	for id in nodes:
		assert_eq(nodes[id]["pos"], full[id]["pos"], id + ": the filter never moves a node")
```

Run: `tools/run_tests.sh skill_tree_model`
Expected: `FAIL: engine error or empty run`. The log shows `Parse Error` reporting too many arguments for `build()`.

- [ ] **A.2: Write the minimal implementation**

In `scripts/ui/skill_tree_model.gd`, make the following edits.

1. Change the signature of `build`:

```gdscript
static func build(rules, compendium: CompendiumModel, forms: Dictionary, reached_forms: Array, current_form: String, forms_focus := false) -> Dictionary:
```

2. Replace the line `nodes.merge(_form_nodes(rules, forms, reached_forms, current_form, nodes))` with:

```gdscript
	var form_nodes := _form_nodes(rules, forms, reached_forms, current_form, nodes)
	if forms_focus:
		var keep := _focus(forms, reached_forms, current_form)
		for id in form_nodes.keys():
			if not keep.has(id):
				form_nodes.erase(id)
	nodes.merge(form_nodes)
```

3. Add at the end of the file:

```gdscript
## The forms forms_focus keeps: the current form, the line it came by back to the slime (the reached parents, or all of
## them where none is reached), and its next stage.
static func _focus(forms: Dictionary, reached: Array, current: String) -> Dictionary:
	var keep := {Form.BASE: true, current: true}
	var todo: Array = [current]
	while not todo.is_empty():
		var f: FormDef = forms.get(todo.pop_back())
		if f == null:
			continue
		var parents: Array = f.parents.filter(func(p): return p == Form.BASE or reached.has(p))
		if parents.is_empty():
			parents = f.parents
		for p in parents:
			if not keep.has(p):
				keep[p] = true
				todo.append(p)
	for k in FormLoader.children_of(forms, current):
		keep[k.id] = true
	return keep
```

In `scripts/ui/skill_screen.gd`, in `_refresh_tree()`, pass the filter:

```gdscript
	_tree_model = SkillTreeModel.build(_rules, _compendium, _player.forms, _reached_forms(), _player.form.form_id, true)
```

- [ ] **A.3: Run the tests, re-shoot and commit**

Run: `tools/run_tests.sh skill_tree_model && tools/run_tests.sh tree_tab`
Expected: `PASS: 37 tests`, then `PASS: 16 tests`.

Re-run Task 16's Step 2 command (unsandboxed) and judge the shots again with Task 16's Step 3 checklist.

```bash
git add scripts/ui/skill_tree_model.gd scripts/ui/skill_screen.gd tests/test_skill_tree_model.gd
git commit -m "feat(ui): forms_focus shows one lineage of forms at a time"
```

---

## Self-Review

### Spec coverage

| Spec requirement | Task |
|---|---|
| **Decisions: Where.** Tree second; Sound moves to a Settings menu; five base tabs; `tab_layout` unchanged; indexes Skills 0, Tree 1, Compendium 2, Bestiary 3, Map 4, Form 5 | 1, 2 |
| **Decisions: Model.** Pure `SkillTreeModel.build(rules, compendium, forms, reached_forms, current_form)` | 4 (layout 5, navigation 6, forms 15) |
| **Decisions: Nodes.** `power`, `evolution` and `form` kinds; states `owned`, `named`, `retired`, `closed`, `ready` (+ `affordable`), `current`, `reached`, `stub`; the slime reached by definition | 4, 7, 15 |
| **Decisions: Edges.** Power → evolution; power → stage-2 form ("opens"); form → child; slime → each stage-2 form; dangling edges filtered | 4, 15 |
| **Decisions: Growing.** Shown from Named; hint at Hinted; condition at Owned-once; stubs only under powers owned once; a Named power reveals no branches; secrets absent with no slot; stage-2 shown and named rules (`open_lineages`); stage 3/4 stubs and names; the Greater rule; stubs nameless | 4, 5, 15 |
| **Decisions: Layout.** Two bands; three-node trees; edge-bearing powers ordered by `LINEAGE_ORDER`; a grid for the rest; positions from the full tree; secrets in the trailing row; canvas at most two screens | 5, 15 |
| **Decisions: Zoom and pan.** Two levels and one `tree_zoom`; the camera a pure function of selection and zoom; click, wheel and empty click; `gui_input` with a stopping filter; stretch hit-testing and `PROCESS_MODE_ALWAYS` verified; D-pad and keys; the left stick via the generalised `nav_step` | 3, 8, 9, 10 |
| **Decisions: Navigation.** `neighbor` (edge first, then the half-plane, ties by id, stays put); the walk reaches every node | 6, 15 |
| **Decisions: Input.** Actions in `controls.gd` with a key binding; a stick click; motion consumed; the hint switches with the scheme | 1, 9 |
| **Decisions: Detail.** A power reuses `detail` (held powers only); an evolution's price and held; a form's stats, grants and blurb, plus current/reached/unreached; `form_card(def, rules)` extracted; conditions as in `compendium_rows` | 7, 14, 15 |
| **Decisions: Evolving.** Read-only (`accept` returns on the tree) | 2, 9 |
| **Decisions: Persistence.** `forms_reached` on `WorldProgress` via `list_section`; `form_advanced` → `progress.reach_form`; editor Play isolated; the slime never stored | 12, 13 |
| **Decisions: Fallback.** `forms_focus`, only if the shots fail | 16, Appendix A |
| **The Settings menu.** Opens inside the pause screen, returns to the same tab, keyboard and pad bindings, holds the sliders, ships first | 1 |
| **Rendering.** `SkillTreeView` builder; `COL_BORDER` / `COL_DIM` edges; `FONT_SMALL` labels; the overview hides labels; selection and zoom reset by `switch_tab` | 8, 9 |
| **Legibility bar.** Overlap, labels, edges off labels and vertical neighbor fit pinned by tests; the rest by eye | 5, 8, 15, 16 |
| **Testing: Model.** All nodes; one parent edge per evolution; one opens edge per listed power; endpoints visible (with and without focus); stubs; Owned-once ingredients; secrets; `named` and `affordable`; open-lineage naming and stage-3 stubs; Greater; retired and closed; deterministic, non-overlapping layout that never moves; the walk; the focus filter | 4, 5, 6, 7, 15, A |
| **Testing: Persistence.** Slime by definition; round trip; malformed section warned; survives a new life; editor Play isolated; signal on success only | 12, 13, 15 |
| **Testing: Screen.** Tree second; selection follows `neighbor`; click, wheel and empty click; stick in four directions with repeat, other tabs vertical only; `nav_step` takes a vector; `tree_zoom` flips; camera stable across rebuilds and inside the box; five- and six-tab strips unchanged (existing `test_audio_ui` / `test_form_tab` tests); hint switches; `tree_zoom` bound | 2, 3, 9, 10 |
| **Testing: Changed by the tab change.** `test_menu_input`, `test_skill_screen`, `test_audio_ui`, `test_map`. `test_evolution_screen`, `test_form_tab` and `tools/evolution_shots.gd` checked and unchanged | 1, 2, 3 |
| **Testing: By eye.** `tools/tree_shots.gd` at each zoom with nothing, some and everything | 11, 16 |
| **Engine and data:** `skill_tree_model.gd` | 4, 5, 6, 7, 15, A |
| **Engine and data:** `skill_tree_view.gd` | 8 |
| **Engine and data:** `world_progress.gd` | 12 |
| **Engine and data:** `player.gd` and `game.gd` | 13 |
| **Engine and data:** `skill_screen.gd` | 1, 2, 3, 9, 10, 14, 15 |
| **Engine and data:** `skill_screen_model.gd` | 7, 14, 15 |
| **Engine and data:** `controls.gd` | 1, 9 |
| **Engine and data:** `tools/tree_shots.gd` | 11, 16 |

### Decisions this plan makes that the spec leaves open

- **The tree box** is the list column, `Rect2(158, 46, 244, 274)`, so the card stays beside the graph. `MAP_BOX` would cover the card.
- **Bindings.**
  - `tree_zoom` is Z plus L3: Z is a mnemonic and unbound in the game.
  - `settings` is Tab plus R3. An accidental L3 click while steering with the left stick only flips the zoom, which is harmless.
- **The camera** centres on the selected node and its edge neighbors, clamped so the selection stays in the box. It is still a pure function of (selection, zoom) over the model. A node-centred camera could not show a stage-2 form with its opening power even when the pair fits.
- **Panels wholly outside the box are not built.** The spec's "no culling is needed" was about cost. Culling here keeps every built `Control` inside 640×360 and keeps hidden panels out of hit-testing.
- **"Joined by an edge in that direction"** means within 45° of the direction. With the plain half-plane, "down" from Radiant chose Prime or Greater Slime (edges 7 px down, 118 px across) over Vast directly below, and Vast could never be reached. The fallback keeps the spec's half-plane.
- **"Until you own it"** for a secret means Compendium Owned-once, the soul's record, not owned this life.
- **A named-but-unowned power's card** shows its hint and, at Owned-once, its condition and description. It never shows `detail()`'s level and progress.
- **The view emits clicks and wheel deferred.** `_refresh` frees and rebuilds the view, and freeing a panel inside its own `gui_input` is an error.

### Known limitation the screenshot check should expect

A stage-2 or stage-3 form's edge neighbors span three columns (slime or openers, the form, its children), which is 340 px in a 244 px box. Their far neighbor is partly off-screen at the normal zoom. The tests pin the vertical fit for every node and the full fit wherever the group fits. This is a **known spec conflict, pending Sean's decision**: read literally, the spec's rule (the bar fails, so build `forms_focus`) would always trigger an appendix that cannot fix this. Task 16 records the case and does not let it alone trigger Appendix A.

### Placeholder scan, type consistency, Review Focus

- **Placeholders.** None found. The two run-time decisions are explicit instructions with their outcomes listed: Task 5's label-width fallback and Task 16's verdict.
- **Type consistency.** These names are used identically everywhere:
  - `build(rules, compendium, forms, reached_forms, current_form[, forms_focus])`, `root(model)`, `neighbor(model, id, dir: Vector2i)`;
  - `camera(model, sel, overview, box_size)`, `neighborhood(model, id)`;
  - `tree_card(rules, node, defs, forms, slots, atk)`, `form_card(def, rules)`, `price_line(rules, id)`, `short_line(rules, id)`;
  - `nav_step(stick: Vector2, delta) -> Vector2i`, `reach_form(id)`, `is_form_reached(id)`, `form_advanced(id)`, `mouse_click(game_pos, index)`.
- **Review Focus.** Each of the five lines has its test in the owning task: 3, 1, 10, 15 and 9.
