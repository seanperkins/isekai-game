# Right-Stick and Mouse Aiming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Play with keyboard and mouse, or with a controller, and aim a skill in any direction with the mouse cursor or the right stick and see where it will go, without changing the left stick or the keys.

**Architecture:** The two input schemes are the two values of `Controls.using_joypad`. `Controls.right_stick()` polls `Input.get_joy_axis` for the device that last pushed its right stick, gated on the pad being the last input used, and `Controls` keeps processing while the tree is paused. `Controls.mouse_aim` says the mouse was the last aimer, and the mouse buttons alias the first two skill slots. `Player.free_aim()` takes the right stick or the cursor direction, snaps it to an exact axis within 10 degrees (keeping the two "flat aim" sites exact), and `Player.cast_aim()` prefers it over the left stick and keys for the cast only. A small `AimReticle` node draws the direction while a cast could fire.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1.

**Spec:** `docs/superpowers/specs/2026-09-29-right-stick-aim-design.md`

## Global Constraints

- Run tests with `tools/run_tests.sh [substr]` from the worktree (`/Users/sean/sites/isekai-game/.worktrees/right-stick`); a SCRIPT ERROR fails the run. After adding a `class_name` script run `gtimeout -k 5 300 env HOME="$PWD/.tmp/gdhome" godot --headless --import >/dev/null 2>&1` first.
- `raw_aim()` is not changed: spread (`wants_spread`) and rope reeling stay on the left stick and keys.
- Constants from the spec, verbatim: `RIGHT_STICK_DEADZONE` 0.45, right-stick ownership threshold `STICK_DEADZONE` 0.25, `MOUSE_MOVE_MIN` 4 game px (accumulated), `MOUSE_DEADZONE` 12 world px, axis snap 10 degrees (`sin(10 degrees)` 0.17364817766693), reticle marks at 28, 40 and 52 px, mouse aliases left button to `active_1` and right button to `active_2`, left-hand aliases `Shift` tackle, `F` eat, `R` inspect, `Q` slot 3, `E` slot 4, slot labels `LMB/RMB/Q/E` with `mouse_aim`.
- The reticle is not a `ColorRect` (`test_art_visuals.gd` forbids one under the Player) and not in group `"vfx"` (tests free that group).
- No attribution lines in commit messages.
- Tests that send pad, key or mouse events use `PadInput` (Task 1) and call `PadInput.reset()` in `after_each`. `PadInput` goes through `Input.parse_input_event` + flush only: the engine delivers the event to `Controls._input` itself (measured), so a manual `Controls._input(ev)` would deliver it twice.
- After adding any `.gd` file run the headless import before committing, and stage directories (`git add autoload scripts tests docs tools`) so the `.gd.uid` files the import wrote are included and no pathspec is missing. Vector comparisons use `is_equal_approx`, except the snapped axes, which are exact. A test that pauses the tree unpauses it in `after_each`.

## Review Focus

1. A pointer a few degrees off horizontal cancelling a jump or a fall when it fires Jet Dash or Hydraulic Propulsion, or losing Hydraulic's lift (Task 3's flat-aim tests).
2. An idle second pad's noise, a pad that has gone quiet, or a paused tree taking or freezing the right stick (Task 1).
3. The reticle showing while eating, dead, evolving or mid-channel, pointing somewhere other than where the cast goes, or drawn at the wrong scale on a form with its own art (Task 4).
4. A pointer (right stick or mouse) reaching the puddle spread or the rope reel (Task 3).
5. The debug overlay's `aim` field disagreeing with what a cast uses when the two sticks point different ways (Task 4).
6. A bumped mouse changing a keyboard-only player's aim without a way back, the mouse and the pad both claiming the aim, or a mouse click failing to hold a channel (Tasks 2 and 3).

## File Map

- Modify: `autoload/controls.gd`, `tests/test_controls_joypad.gd` (only if a label test needs the new state reset), `scripts/player/player.gd`, `scripts/ui/hud.gd`, `scripts/abilities/hydraulic_propulsion.gd` (header comment only), `docs/playtest-checklist.md`, `tests/test_aiming.gd` (header), `tests/test_input_debug.gd`.
- Create: `tests/support/pad_input.gd`, `scripts/player/aim_reticle.gd`; tests `tests/test_right_stick.gd`, `tests/test_mouse_input.gd`, `tests/test_pointer_aim.gd`, `tests/test_aim_reticle.gd`.

---

### Task 1: `Controls.right_stick()` and the test helper

**Files:**
- Modify: `autoload/controls.gd`
- Create: `tests/support/pad_input.gd`, `tests/test_right_stick.gd`

**Interfaces:**
- Produces: `PadInput.axis(axis: int, value: float, device := 0)`, `PadInput.key(keycode: int)`, `PadInput.button(index: int, device := 0)`, `PadInput.reset()`; `Controls.aim_device: int` (-1 for none), `Controls.RIGHT_STICK_DEADZONE := 0.45`, `Controls.raw_right_stick() -> Vector2` (ungated), `Controls.right_stick() -> Vector2` (`ZERO` unless `using_joypad`, `aim_device >= 0` and the length is at least the deadzone), `Controls._on_joy_connection_changed(device: int, connected: bool)`; `Controls.process_mode` is `PROCESS_MODE_ALWAYS`.

- [ ] **Step 1: Write the helper and the failing tests**

`tests/support/pad_input.gd`:

```gdscript
class_name PadInput
extends RefCounted
## Pad, key and mouse input for tests. Every event goes through the engine's Input and nothing else: the engine delivers it
## to Controls._input itself (and updates get_joy_axis and the action state), so calling _input by hand too would deliver
## it twice. reset() puts all of it back.

static func _send(ev: InputEvent) -> void:
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

static func axis(axis_index: int, value: float, device := 0) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = axis_index as JoyAxis
	ev.axis_value = value
	_send(ev)

static func key(keycode: int) -> void:
	for pressed in [true, false]:
		var k := InputEventKey.new()
		k.pressed = pressed
		k.keycode = keycode as Key
		k.physical_keycode = keycode as Key  # the InputMap's bindings are physical keys, so is_action_pressed matches
		_send(k)

static func button(index: int, device := 0) -> void:
	for pressed in [true, false]:
		var b := InputEventJoypadButton.new()
		b.device = device
		b.button_index = index as JoyButton
		b.pressed = pressed
		_send(b)

static func reset() -> void:
	for dev in [0, 1]:
		for a in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
			axis(a, 0.0, dev)
	Controls.aim_device = -1
	Controls.last_device = -1
	Controls.last_stick = Vector2.ZERO
	Controls.using_joypad = false
	for a in ["aim_up", "aim_down", "move_left", "move_right"]:
		Input.action_release(a)
```

`tests/test_right_stick.gd`:

```gdscript
extends GutTest
## The right stick is polled per device, owned by the last pad to push it past 0.25, ignored once a key was the last input,
## and still seen while the tree is paused.

func after_each() -> void:
	PadInput.reset()
	get_tree().paused = false

func test_controls_keeps_processing_while_the_tree_is_paused() -> void:
	get_tree().paused = true
	assert_true(Controls.can_process(), "the skill screen pauses the tree; a paused Controls would miss every stick event")

func test_a_push_past_the_action_deadzone_makes_that_pad_the_owner_and_reads_back() -> void:
	PadInput.axis(JOY_AXIS_RIGHT_X, 0.8)
	PadInput.axis(JOY_AXIS_RIGHT_Y, -0.6)
	assert_eq(Controls.aim_device, 0)
	assert_true(Controls.right_stick().is_equal_approx(Vector2(0.8, -0.6)))

func test_nothing_pushed_reads_zero() -> void:
	assert_eq(Controls.right_stick(), Vector2.ZERO)

func test_a_pad_button_with_no_right_stick_push_reads_zero() -> void:
	PadInput.button(JOY_BUTTON_A)
	assert_true(Controls.using_joypad)
	assert_eq(Controls.aim_device, -1)
	assert_eq(Controls.right_stick(), Vector2.ZERO)

func test_a_resting_diagonal_under_the_right_stick_deadzone_reads_zero() -> void:
	PadInput.axis(JOY_AXIS_RIGHT_X, 0.3)
	PadInput.axis(JOY_AXIS_RIGHT_Y, 0.3)  # length 0.424, under 0.45; each axis is past the 0.25 that makes it the owner
	assert_eq(Controls.aim_device, 0)
	assert_eq(Controls.right_stick(), Vector2.ZERO)
	PadInput.axis(JOY_AXIS_RIGHT_X, 0.25)
	PadInput.axis(JOY_AXIS_RIGHT_Y, 0.25)  # 0.354
	assert_eq(Controls.right_stick(), Vector2.ZERO)
	assert_true(Controls.raw_right_stick().is_equal_approx(Vector2(0.25, 0.25)), "the raw reading is ungated")

func test_a_quiet_reading_from_a_second_pad_does_not_take_the_stick() -> void:
	PadInput.axis(JOY_AXIS_RIGHT_X, 1.0)
	PadInput.axis(JOY_AXIS_RIGHT_Y, 0.05, 1)
	assert_eq(Controls.aim_device, 0)
	assert_true(Controls.right_stick().is_equal_approx(Vector2(1.0, 0.0)))

func test_a_real_push_on_a_second_pad_takes_it_wholly() -> void:
	PadInput.axis(JOY_AXIS_RIGHT_X, 1.0)
	PadInput.axis(JOY_AXIS_RIGHT_Y, 0.9, 1)
	assert_eq(Controls.aim_device, 1)
	assert_true(Controls.right_stick().is_equal_approx(Vector2(0.0, 0.9)), "pad 1's stick, not a mix with pad 0's")

func test_a_key_press_silences_it_and_a_later_push_engages_it_again() -> void:
	PadInput.axis(JOY_AXIS_RIGHT_X, 1.0)
	PadInput.key(KEY_A)
	assert_eq(Controls.right_stick(), Vector2.ZERO)
	PadInput.axis(JOY_AXIS_RIGHT_X, 0.5)  # a pad that keeps emitting re-arms the gate itself: the documented limit
	assert_true(Controls.right_stick().is_equal_approx(Vector2(0.5, 0.0)))

func test_a_disconnect_resets_the_owner_even_with_the_stick_still_held() -> void:
	PadInput.axis(JOY_AXIS_RIGHT_X, 1.0)
	Controls._on_joy_connection_changed(1, false)
	assert_eq(Controls.aim_device, 0, "another pad leaving changes nothing")
	Controls._on_joy_connection_changed(0, true)
	assert_eq(Controls.aim_device, 0, "a connect changes nothing")
	Controls._on_joy_connection_changed(0, false)  # the engine's axis for device 0 is still 1.0
	assert_eq(Controls.aim_device, -1)
	assert_eq(Controls.right_stick(), Vector2.ZERO)
```

- [ ] **Step 2: Run to verify it fails**

Run the headless import (new `class_name PadInput`), then `tools/run_tests.sh test_right_stick`.
Expected: FAIL (Parse Error: `aim_device`, `right_stick`, `raw_right_stick`, `_on_joy_connection_changed` not found on `Controls`).

- [ ] **Step 3: Implement** in `autoload/controls.gd`

Add beside `last_stick` (and update the comments named in the spec's consistency sweep: the file header says the last device used picks the HUD labels; `using_joypad` also enables the right stick; `STICK_DEADZONE` also decides right-stick ownership; `last_stick` drives `raw_aim` and skill-screen navigation):

```gdscript
const RIGHT_STICK_DEADZONE := 0.45
...
## The pad whose right stick aims: the last to push it past STICK_DEADZONE (a quiet reading from another pad never
## takes it). -1 for none. The stick itself is polled in raw_right_stick(), never cached.
var aim_device := -1
```

In `_ready`, before `ensure_actions()`:

```gdscript
	process_mode = Node.PROCESS_MODE_ALWAYS  # the skill screen pauses the tree; a paused Controls would miss every stick and key event
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
```

In `_input`, extend the existing left-stick chain inside `if event is InputEventJoypadMotion:` with a third branch (the `last_device`/`last_pad_name` lines below it stay):

```gdscript
			elif (event.axis == JOY_AXIS_RIGHT_X or event.axis == JOY_AXIS_RIGHT_Y) and absf(event.axis_value) > STICK_DEADZONE:
				aim_device = event.device
```

New methods:

```gdscript
## The right stick of the pad that owns it, raw and ungated (the debug overlay shows it). ZERO with no owner.
func raw_right_stick() -> Vector2:
	if aim_device < 0:
		return Vector2.ZERO
	return Vector2(Input.get_joy_axis(aim_device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(aim_device, JOY_AXIS_RIGHT_Y))

## The right stick as an aim: ZERO unless the last input was the pad and it is pushed past the deadzone. Polled, so a pause
## and two pads at once are the engine's own per-device state; the deadzone is what protects against drift.
func right_stick() -> Vector2:
	if not using_joypad or aim_device < 0:
		return Vector2.ZERO
	var v := raw_right_stick()
	return v if v.length() >= RIGHT_STICK_DEADZONE else Vector2.ZERO

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not connected and device == aim_device:
		aim_device = -1
```

- [ ] **Step 4: Run to verify it passes**

Run: `tools/run_tests.sh test_right_stick`, then `tools/run_tests.sh test_controls` and `tools/run_tests.sh test_aim_fixes` and `tools/run_tests.sh test_skill_screen`.
Expected: all PASS.

- [ ] **Step 5: Import and commit**

```bash
gtimeout -k 5 300 env HOME="$PWD/.tmp/gdhome" godot --headless --import >/dev/null 2>&1
git add autoload scripts tests docs tools
git commit -m "feat: Controls polls the right stick per device and keeps processing while paused"
```

---

### Task 2: The mouse, the left-hand layout and the scheme signal

**Files:**
- Modify: `autoload/controls.gd`, `tests/support/pad_input.gd`, `scripts/player/player.gd` (the eat and inspect prompts only), `scripts/ui/skill_screen.gd` (connect the signal), `tests/test_accessors.gd`, `tests/test_controls_joypad.gd`, `tests/test_skill_screen.gd`
- Create: `tests/test_mouse_input.gd`

**Interfaces:**
- Consumes: `PadInput`, `Controls.using_joypad`, `Controls.aim_device` (Task 1).
- Produces: `Controls.mouse_aim: bool`, `Controls.MOUSE_MOVE_MIN := 4.0`, `Controls.MOUSE_BUTTONS`, `Controls.MOUSE_SLOT_LABELS := ["LMB", "RMB", "Q", "E"]`, `Controls.scheme_changed` (signal), `Controls.slot_labels()` (pad labels with `using_joypad`, `MOUSE_SLOT_LABELS` with `mouse_aim`, else `U/O/H/L`), `Controls.eat_label()` and `Controls.inspect_label()` (`B`/`Y` pad, `F`/`R` with `mouse_aim`, else `K`/`I`); the left and right mouse buttons bound (any device) to `active_1` and `active_2`; the left-hand key aliases `tackle` Shift, `predate` F, `inspect` R, `active_3` Q, `active_4` E; `PadInput.mouse_move(relative: Vector2)`, `PadInput.mouse_button(index: int, pressed := true)`, and `PadInput.reset()` also releasing both mouse buttons and clearing `mouse_aim` and `_mouse_travel`.

- [ ] **Step 1: Write the failing tests**

Extend `tests/support/pad_input.gd`:

```gdscript
static func mouse_move(relative: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.relative = relative
	_send(m)

static func mouse_button(index: int, pressed := true) -> void:
	var b := InputEventMouseButton.new()
	b.button_index = index as MouseButton
	b.pressed = pressed
	_send(b)
```

and, in `reset()`, `mouse_button(MOUSE_BUTTON_LEFT, false)`, `mouse_button(MOUSE_BUTTON_RIGHT, false)`, `Controls.mouse_aim = false`, `Controls._mouse_travel = 0.0`. `tests/test_mouse_input.gd`:

```gdscript
extends GutTest
## The mouse is the second pointing device of the keyboard scheme: enough travel or a click makes it the aimer, a pad or a
## vertical aim key hands the aim back, the buttons and the left-hand keys are skill and action aliases.

func after_each() -> void:
	PadInput.reset()

func test_small_moves_add_up_to_mouse_aim_and_clear_the_pad() -> void:
	Controls.using_joypad = true
	PadInput.mouse_move(Vector2(2, 0))
	assert_false(Controls.mouse_aim)
	PadInput.mouse_move(Vector2(0, 2))
	assert_true(Controls.mouse_aim)
	assert_false(Controls.using_joypad)

func test_a_jostle_under_the_threshold_does_nothing() -> void:
	Controls.using_joypad = true
	PadInput.mouse_move(Vector2(3, 0))
	assert_false(Controls.mouse_aim)
	assert_true(Controls.using_joypad)

func test_a_pad_input_between_two_moves_resets_the_total() -> void:
	PadInput.mouse_move(Vector2(2, 0))
	PadInput.axis(JOY_AXIS_LEFT_X, 0.8)
	PadInput.mouse_move(Vector2(2, 0))
	assert_false(Controls.mouse_aim)
	assert_true(Controls.using_joypad)

func test_a_button_press_sets_it_and_a_release_changes_nothing() -> void:
	Controls.using_joypad = true
	PadInput.mouse_button(MOUSE_BUTTON_LEFT)
	assert_true(Controls.mouse_aim)
	assert_false(Controls.using_joypad)
	PadInput.button(JOY_BUTTON_A)  # the pad takes over while the mouse button is still down
	PadInput.mouse_button(MOUSE_BUTTON_LEFT, false)
	assert_true(Controls.using_joypad, "a release is not a use of the mouse")
	assert_false(Controls.mouse_aim)

func test_the_wheel_is_not_aiming() -> void:
	Controls.using_joypad = true
	PadInput.mouse_button(MOUSE_BUTTON_WHEEL_UP)
	assert_false(Controls.mouse_aim)
	assert_true(Controls.using_joypad)

func test_a_pad_button_or_push_hands_the_aim_back() -> void:
	PadInput.mouse_move(Vector2(10, 0))
	PadInput.button(JOY_BUTTON_A)
	assert_false(Controls.mouse_aim)
	assert_true(Controls.using_joypad)
	PadInput.mouse_move(Vector2(10, 0))
	PadInput.axis(JOY_AXIS_LEFT_X, 0.8)
	assert_false(Controls.mouse_aim)

func test_a_vertical_aim_key_hands_it_back_but_a_movement_key_does_not() -> void:
	PadInput.mouse_move(Vector2(10, 0))
	PadInput.key(KEY_A)  # move_left
	assert_true(Controls.mouse_aim, "running does not drop the mouse aim")
	PadInput.key(KEY_W)  # aim_up
	assert_false(Controls.mouse_aim)
	PadInput.mouse_move(Vector2(10, 0))
	assert_true(Controls.mouse_aim, "and a move after it aims again")
	PadInput.key(KEY_S)  # aim_down
	assert_false(Controls.mouse_aim)

func test_the_mouse_buttons_and_the_left_hand_keys_are_bound() -> void:
	var left := InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	left.pressed = true
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	assert_true(InputMap.event_is_action(left, "active_1"))
	assert_true(InputMap.event_is_action(right, "active_2"))
	assert_false(InputMap.event_is_action(left, "active_2"))
	for pair in [["tackle", KEY_SHIFT], ["predate", KEY_F], ["inspect", KEY_R], ["active_3", KEY_Q], ["active_4", KEY_E]]:
		var keys := InputMap.action_get_events(pair[0]).filter(func(e): return e is InputEventKey).map(func(e): return e.physical_keycode)
		assert_true(keys.has(pair[1]), pair[0])

func test_a_click_reaches_the_action_state() -> void:
	PadInput.mouse_button(MOUSE_BUTTON_LEFT)
	assert_true(Input.is_action_pressed("active_1"))
	PadInput.mouse_button(MOUSE_BUTTON_LEFT, false)
	assert_false(Input.is_action_pressed("active_1"))

func test_labels_follow_the_scheme() -> void:
	assert_eq(Controls.slot_labels(), ["U", "O", "H", "L"])
	assert_eq([Controls.eat_label(), Controls.inspect_label()], ["K", "I"])
	PadInput.mouse_move(Vector2(10, 0))
	assert_eq(Controls.slot_labels(), ["LMB", "RMB", "Q", "E"])
	assert_eq([Controls.eat_label(), Controls.inspect_label()], ["F", "R"])
	PadInput.button(JOY_BUTTON_A)
	assert_eq(Controls.slot_labels(), ["LB", "RB", "LT", "RT"])
	assert_eq([Controls.eat_label(), Controls.inspect_label()], ["B", "Y"])

func test_scheme_changed_fires_once_per_change() -> void:
	var count := [0]
	var cb := func() -> void: count[0] += 1
	Controls.scheme_changed.connect(cb)
	PadInput.mouse_move(Vector2(10, 0))
	assert_eq(count[0], 1)
	PadInput.mouse_move(Vector2(10, 0))
	assert_eq(count[0], 1, "the labels did not change")
	PadInput.button(JOY_BUTTON_A)
	assert_eq(count[0], 2)
	Controls.scheme_changed.disconnect(cb)
```

In `tests/test_skill_screen.gd`, using that file's fixture (open the screen; `after_each` also calls `PadInput.reset()`): open the screen, `PadInput.mouse_move(Vector2(10, 0))`, then assert some `Label` under the screen (`screen.find_children("*", "Label", true, false)`) has text containing `LMB`. In `tests/test_accessors.gd:32` change the `tackle` event count from 2 to 3 (J, Shift and the pad button) with a comment; in `tests/test_controls_joypad.gd`'s `test_keyboard_skill_keys_are_u_o_h_l` expect slot 3 keys `[KEY_H, KEY_Q]` and slot 4 `[KEY_L, KEY_E]` (slots 1 and 2 stay `[KEY_U]`, `[KEY_O]`), rename it to say the left-hand aliases, with a comment.

- [ ] **Step 2: Run to verify it fails**

Run: `tools/run_tests.sh test_mouse_input`
Expected: FAIL (Parse Error: `Controls.mouse_aim`, `scheme_changed`, `eat_label`, `inspect_label` not found; `PadInput.reset()` also fails to compile against the missing `mouse_aim`, which turns `test_right_stick` red until Step 3; that is expected).

- [ ] **Step 3: Implement** in `autoload/controls.gd`

Extend `BINDINGS`: `"tackle": [KEY_J, KEY_SHIFT]`, `"predate": [KEY_K, KEY_F]`, `"inspect": [KEY_I, KEY_R]`, `"active_3": [KEY_H, KEY_Q]`, `"active_4": [KEY_L, KEY_E]` (`Q`/`E` are also `tab_prev`/`tab_next` in the skill screen, which pauses the tree). Then:

```gdscript
## Mouse buttons are skill aliases: left is slot 1, right is slot 2.
const MOUSE_BUTTONS := {"active_1": [MOUSE_BUTTON_LEFT], "active_2": [MOUSE_BUTTON_RIGHT]}
## Mouse travel (game px, summed since the last pad input or vertical aim key) that makes the mouse the aimer.
const MOUSE_MOVE_MIN := 4.0
const MOUSE_SLOT_LABELS := ["LMB", "RMB", "Q", "E"]
signal scheme_changed
...
## True after the mouse was the last aimer: enough travel or a click, until a pad input or a vertical aim key.
var mouse_aim := false
var _mouse_travel := 0.0
```

In `ensure_actions`, after the pad-button loop:

```gdscript
		for button in MOUSE_BUTTONS.get(action, []):
			var m := InputEventMouseButton.new()
			m.button_index = button
			m.device = -1  # any device, like the pad bindings
			_add(action, m)
```

Replace the `using_joypad` chain at the end of `_input` with:

```gdscript
	var before := slot_labels()
	if event is InputEventJoypadButton and event.pressed:
		_use_pad()
	elif event is InputEventJoypadMotion and absf(event.axis_value) > STICK_DEADZONE:
		_use_pad()
	elif event is InputEventKey and event.pressed:
		using_joypad = false
		if event.is_action_pressed("aim_up") or event.is_action_pressed("aim_down"):
			mouse_aim = false  # the keyboard is aiming now (is_action_pressed ignores key repeats)
			_mouse_travel = 0.0
	elif event is InputEventMouseButton:
		if event.pressed and not _is_wheel(event.button_index):
			using_joypad = false
			mouse_aim = true
	elif event is InputEventMouseMotion:
		_mouse_travel += event.relative.length()
		if _mouse_travel >= MOUSE_MOVE_MIN:
			using_joypad = false
			mouse_aim = true
	if slot_labels() != before:
		scheme_changed.emit()

func _use_pad() -> void:
	using_joypad = true
	mouse_aim = false
	_mouse_travel = 0.0

static func _is_wheel(button: int) -> bool:
	return button in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]
```

(this changes one existing behaviour on purpose: a mouse-button release no longer clears `using_joypad`; only a press does.) And:

```gdscript
func slot_labels() -> Array:
	if using_joypad:
		return PAD_SLOT_LABELS
	return MOUSE_SLOT_LABELS if mouse_aim else KEY_SLOT_LABELS

func eat_label() -> String:
	return "B" if using_joypad else ("F" if mouse_aim else "K")

func inspect_label() -> String:
	return "Y" if using_joypad else ("R" if mouse_aim else "I")
```

In `scripts/player/player.gd` use `Controls.inspect_label()` and `Controls.eat_label()` in the two prompts (`"%s: %s" % [Controls.inspect_label(), thing.prompt()]`, `"Hold %s to eat" % Controls.eat_label()`). In `scripts/ui/skill_screen.gd`, connect `Controls.scheme_changed` once (in `_ready`) to a handler that calls `_refresh()` when the screen is visible. Doc lines per the spec's consistency sweep.

- [ ] **Step 4: Run to verify it passes**

Run: `tools/run_tests.sh test_mouse_input`, then `tools/run_tests.sh test_controls`, `tools/run_tests.sh test_accessors`, `tools/run_tests.sh test_right_stick`, `tools/run_tests.sh test_aim_fixes`, `tools/run_tests.sh test_hud`, `tools/run_tests.sh test_skill_screen`, `tools/run_tests.sh test_player`.
Expected: all PASS.

- [ ] **Step 5: Import and commit**

```bash
gtimeout -k 5 300 env HOME="$PWD/.tmp/gdhome" godot --headless --import >/dev/null 2>&1
git add autoload scripts tests docs tools
git commit -m "feat: the mouse aims and casts, a left-hand layout for the keyboard scheme, and the labels follow the scheme"
```

---

### Task 3: `free_aim`, `cast_aim` and `can_cast` on the Player

**Files:**
- Modify: `scripts/player/player.gd` (`use_active`, near `raw_aim`/`aim_vector`, comments), `scripts/abilities/hydraulic_propulsion.gd` (header comment), `tests/test_aiming.gd` (header comment only)
- Create: `tests/test_pointer_aim.gd`

**Interfaces:**
- Consumes: `Controls.right_stick()`, `PadInput` (Task 1), `Controls.mouse_aim` and `PadInput.mouse_move` (Task 2).
- Produces: `Player.AXIS_SNAP := 0.17364817766693`, `Player.MOUSE_DEADZONE := 12.0`, `Player.pointer_override: Vector2` (INF for none; tests set a world point instead of the OS cursor), `Player.mouse_direction() -> Vector2` (ZERO unless `mouse_aim` and the cursor is at least the deadzone from the origin), `Player.free_aim() -> Vector2` (ZERO when neither pointer is engaged; the normalised right stick or cursor direction, but exactly `(sign(x), 0)` when `abs(y) <= AXIS_SNAP` and exactly `(0, sign(y))` when `abs(x) <= AXIS_SNAP`), `Player.cast_aim() -> Vector2` (`free_aim()` when not ZERO, else `aim_vector() if aim_held() else ZERO`), `Player.can_cast() -> bool` (not dead, not eating, no live channel, not evolving). `use_active` opens with `if not can_cast(): return` and sets `ability.aim = cast_aim()`.

- [ ] **Step 1: Write the failing tests** (`tests/test_pointer_aim.gd`)

Fixture like `tests/test_aim_fixes.gd:1-14` (rules from `DefLoader.load_dir("res://data/skills")`, `Player.new()`, `setup(rules, CompendiumModel.new([], []), [], func(n, t): rules.handle_event(n, t))`, `add_child_autofree(player)`, `rules.start_run()`), `after_each: PadInput.reset()` plus freeing group `vfx`, and two helpers `_right(x, y)` / `_left(x, y)` calling `PadInput.axis(JOY_AXIS_RIGHT_X/Y, ...)` and `PadInput.axis(JOY_AXIS_LEFT_X/Y, ...)`. Tests:

```gdscript
func test_thirty_degrees_up_from_right_is_that_exact_direction() -> void:
	var v := Vector2.from_angle(deg_to_rad(-30.0))
	_right(v.x, v.y)
	assert_true(player.free_aim().is_equal_approx(v))

func test_a_shallow_stick_snaps_to_the_exact_axis_on_all_four_sides() -> void:
	var axes := {0.0: Vector2(1, 0), 90.0: Vector2(0, 1), 180.0: Vector2(-1, 0), 270.0: Vector2(0, -1)}
	for base in axes:
		for off in [-5.0, 5.0]:
			var v := Vector2.from_angle(deg_to_rad(base + off))
			_right(v.x, v.y)
			assert_eq(player.free_aim(), axes[base], "%s degrees %s" % [base, off])

func test_the_snap_ends_between_9_9_and_10_1_degrees() -> void:
	var inside := Vector2.from_angle(deg_to_rad(9.9))
	_right(inside.x, inside.y)
	assert_eq(player.free_aim(), Vector2(1, 0))
	var outside := Vector2.from_angle(deg_to_rad(10.1))
	_right(outside.x, outside.y)
	assert_ne(player.free_aim().y, 0.0)
	assert_true(player.free_aim().is_equal_approx(outside))

func test_the_snap_compares_the_normalised_stick_not_the_raw_one() -> void:
	_right(0.55, 0.13)  # length 0.565 (engaged); raw |y| 0.13 is under 0.1736, but normalised it is 0.230: 13 degrees
	assert_ne(player.free_aim().y, 0.0)
	assert_true(player.free_aim().is_equal_approx(Vector2(0.55, 0.13).normalized()))

func test_cast_aim_falls_back_to_the_left_stick_then_to_nothing() -> void:
	assert_eq(player.cast_aim(), Vector2.ZERO)
	_left(0.0, -1.0)
	assert_eq(player.cast_aim(), Vector2(0, -1))

func test_the_right_stick_beats_the_left_stick_and_the_keys_for_the_cast() -> void:
	_left(0.0, -1.0)
	_right(1.0, 0.0)
	assert_eq(player.cast_aim(), Vector2(1, 0))
	assert_eq(player.aim_vector(), Vector2(0, -1), "the left stick's own aim is unchanged")
	PadInput.axis(JOY_AXIS_LEFT_Y, 0.0)
	Input.action_press("aim_down")
	assert_eq(player.cast_aim(), Vector2(1, 0), "and beats the keys")

func test_a_key_press_gives_the_cast_back_to_the_left_stick_or_the_keys() -> void:
	_right(1.0, 0.0, 1)  # a second pad's right stick
	PadInput.key(KEY_W)   # the keyboard is the last input: the gate closes
	Input.action_press("aim_up")
	assert_eq(player.cast_aim(), Vector2(0, -1), "the keys")
	Controls.last_stick = Vector2(-1, 0)  # a left stick held from before the key press (a new event would re-arm the pad)
	assert_eq(player.cast_aim(), Vector2(-1, 0), "a held left stick comes first, as raw_aim() reads today")

func test_the_right_stick_never_reaches_spread_or_the_rope_reel() -> void:
	_right(0.0, 1.0)  # straight down, the puddle gesture, on the wrong stick
	assert_eq(player.raw_aim(), Vector2.ZERO)
	assert_false(Player.wants_spread(true, player.aim_vector(), player.raw_aim().y, false))

func test_can_cast_in_each_state() -> void:
	assert_true(player.can_cast())
	player._channel = autofree(Ability.new())
	assert_false(player.can_cast(), "a live channel")
	player._channel = null
	player._begin_evolve_moment(FormLoader.load_all()["tide"])
	assert_false(player.can_cast(), "the evolve moment")
```

with `_right(x, y, device := 0)` taking the device for the second-pad case. Also in this file:

- **dead**: `player.health.take_hit(player.health.hp, "physical")` (setting `hp` does not set the dead flag), `assert_false(player.can_cast())`.
- **eating**: copy `tests/test_channel.gd:166-177`'s stunned bat 10 px away and `player.begin_predate()`, `assert_false(player.can_cast())`.
- **`use_active` does nothing** in dead / eating / channel: Hydraulic Propulsion in slot 0 (`for i in 4: rules.handle_event("absorbed", {"essence": "water", "source": "water_pool"})`, `player.mana.mp = 20`, as `tests/test_channel.gd:43-51` does), then per state `player.use_active(0)` leaves `player.last_cast` empty and MP at 20.
- **flat-aim sites**, Hydraulic Propulsion as above:

```gdscript
func test_hydraulic_keeps_its_lift_when_the_right_stick_is_a_few_degrees_off_horizontal() -> void:
	var v := Vector2.from_angle(deg_to_rad(-3.0))
	_right(v.x, v.y)
	player.use_active(0)
	assert_eq(player.velocity.y, load("res://scripts/abilities/hydraulic_propulsion.gd").HORIZONTAL_LIFT)
```

  and Jet Dash mid-jump (both also with the cursor 3 degrees off horizontal): replace the ability in slot 0 as `tests/test_channel.gd:204-210` does (`load("res://scenes/abilities/jet_dash.tscn")`, `setup(player, [100], 1)`, `player._abilities["hydraulic_propulsion"] = dash`), `player.velocity = Vector2(0, -330)`, right stick `Vector2.from_angle(deg_to_rad(3.0))`, `player.use_active(0)`, `assert_eq(player.velocity.y, -330.0)`.
- **the latch**: cast Hydraulic Propulsion held (`Input.action_press("active_1")`, wait 3 physics frames as `tests/test_channel.gd:71-77` does) with the right stick right, then move the right stick to the opposite side and wait 3 more frames: `(player._abilities["hydraulic_propulsion"])._dir` is unchanged, `Input.action_release("active_1")`.
- **a click drives a channel**: Hydraulic Propulsion in slot 0 (`slot 1`), `PadInput.mouse_button(MOUSE_BUTTON_LEFT)`, wait 3 physics frames: `player._channel != null`; `PadInput.mouse_button(MOUSE_BUTTON_LEFT, false)`, wait 2: `player._channel == null`.
- **end-to-end**: Water Blade in slot 0 the way `tests/test_channel.gd:204-210` swaps it in, right stick at 30 degrees up (and again with the cursor), `use_active(0)`; `player.last_cast["aim"]` is approximately `Vector2.from_angle(deg_to_rad(-30))` and the slash sprite in group `vfx` (texture `VfxArt.water_slash()`) has `rotation` approximately `deg_to_rad(-30)`.

The mouse (same file; `_mouse_at(point)` sets `player.pointer_override = point` and calls `PadInput.mouse_move(Vector2(10, 0))` so `mouse_aim` is live; the player sits at the origin):

```gdscript
func test_the_cursor_is_ignored_until_the_mouse_moves() -> void:
	player.pointer_override = Vector2(100, 0)
	assert_eq(player.free_aim(), Vector2.ZERO)

func test_the_cursor_thirty_degrees_up_is_that_exact_direction() -> void:
	var v := Vector2.from_angle(deg_to_rad(-30.0))
	_mouse_at(v * 100.0)
	assert_true(player.free_aim().is_equal_approx(v))

func test_the_cursor_snaps_to_horizontal_within_ten_degrees() -> void:
	_mouse_at(Vector2.from_angle(deg_to_rad(5.0)) * 100.0)
	assert_eq(player.free_aim(), Vector2(1, 0))

func test_a_cursor_on_the_body_falls_back_to_the_keys() -> void:
	_mouse_at(Vector2(5, 5))  # 7 px from the body, under the 12 px deadzone
	assert_eq(player.free_aim(), Vector2.ZERO)
	Input.action_press("aim_up")
	assert_eq(player.cast_aim(), Vector2(0, -1))

func test_a_pad_push_after_the_mouse_hands_the_aim_to_the_stick() -> void:
	_mouse_at(Vector2(0, -100))
	PadInput.axis(JOY_AXIS_RIGHT_X, 1.0)
	assert_eq(player.free_aim(), Vector2(1, 0))
	assert_eq(player.mouse_direction(), Vector2.ZERO, "the two pointers never both apply")

func test_the_cursor_beats_a_stale_left_stick_and_the_keys_for_the_cast() -> void:
	_mouse_at(Vector2(100, 0))
	Controls.last_stick = Vector2(0, -1)  # a stick held before the mouse moved sends no further events
	Input.action_press("aim_down")
	assert_eq(player.cast_aim(), Vector2(1, 0))
	assert_eq(player.raw_aim(), Vector2(0, -1), "raw_aim is unchanged: spread and the reel still read the stick and keys")

func test_the_cursor_never_reaches_spread_or_the_rope_reel() -> void:
	_mouse_at(Vector2(0, 100))  # straight down, the puddle gesture, on the mouse
	assert_eq(player.raw_aim(), Vector2.ZERO)
	assert_false(Player.wants_spread(true, player.aim_vector(), player.raw_aim().y, false))
```

- [ ] **Step 2: Run to verify it fails**

Run: `tools/run_tests.sh test_pointer_aim`
Expected: FAIL (Parse Error: `free_aim`, `cast_aim`, `can_cast`, `pointer_override` not found on `Player`).

- [ ] **Step 3: Implement** in `scripts/player/player.gd`

```gdscript
## sin(10 degrees): an aim this close to an axis reads as exactly that axis, so the two "flat aim" checks
## (Hydraulic's lift, apply_impulse's flat push) keep working, and a thumb's or a hand's wobble does not tilt a dash.
const AXIS_SNAP := 0.17364817766693
## A cursor closer than this (world px) to the origin does not aim: it would jitter at every step.
const MOUSE_DEADZONE := 12.0
## Tests set a world point here instead of moving the OS cursor.
var pointer_override := Vector2.INF
```

near `raw_aim()`:

```gdscript
## Where the cursor points from the origin (the point skills fire from): ZERO unless the mouse was the last aimer, and the
## cursor is at least MOUSE_DEADZONE away. get_global_mouse_position() applies the camera and zoom. Controls._input owns the
## exclusion with the right stick (a pad input clears mouse_aim), so it is not re-checked here.
func mouse_direction() -> Vector2:
	if not Controls.mouse_aim:
		return Vector2.ZERO
	var cursor := get_global_mouse_position() if pointer_override == Vector2.INF else pointer_override
	var d := cursor - global_position
	return d if d.length() >= MOUSE_DEADZONE else Vector2.ZERO

## The pointer's direction (the right stick, else the mouse): free (any angle) but for the axis snap, ZERO when neither is
## engaged. The reticle and the cast both read this and nothing else.
func free_aim() -> Vector2:
	var s := Controls.right_stick()
	if s == Vector2.ZERO:
		s = mouse_direction()
	if s == Vector2.ZERO:
		return Vector2.ZERO
	var d := s.normalized()
	if absf(d.y) <= AXIS_SNAP:
		return Vector2(signf(d.x), 0.0)
	if absf(d.x) <= AXIS_SNAP:
		return Vector2(0.0, signf(d.y))
	return d

## What a skill is fired along: the pointer if one is engaged, else the left stick or keys (8-way), else ZERO ("nothing
## held": each ability uses its own default). raw_aim() is deliberately not touched, so a pointer never drives the
## puddle spread or the rope reel.
func cast_aim() -> Vector2:
	var free := free_aim()
	if free != Vector2.ZERO:
		return free
	return aim_vector() if aim_held() else Vector2.ZERO

## A press on an active slot would do something now: today's guards, plus the evolve moment (unreachable in play, since
## _physics_process returns before any cast while evolving).
func can_cast() -> bool:
	return not (health.is_dead() or predation.active() or _channel != null or evolving())
```

In `use_active`, replace the first two guards (`if health.is_dead() or predation.active(): return` and `if _channel != null: return  # a channel is live: release it first`) with `if not can_cast(): return`, and the aim line and its comment with:

```gdscript
	# Nothing held: zero, so each ability uses its own default (forward, or up-forward for Swing). Held includes the pointer.
	ability.aim = cast_aim()
```

Update the comment on `AIM_DEADZONE` (it covers the left stick and keys; the right stick and the mouse have their own deadzones), the `raw_aim()` doc ("the left stick or keys; the pointers are deliberately excluded, see cast_aim"), the `tests/test_aiming.gd` header (8-way is true of the left stick and keys), and `hydraulic_propulsion.gd`'s header ("a horizontal burst" means within 10 degrees of horizontal for the right stick).

- [ ] **Step 4: Run to verify it passes**

Run: `tools/run_tests.sh test_pointer_aim`, then `tools/run_tests.sh test_aim`, `tools/run_tests.sh test_player`, `tools/run_tests.sh test_channel`, `tools/run_tests.sh test_mana`.
Expected: all PASS. (The `evolving()` guard in `use_active` is the one behaviour an existing test could notice: a failure there is a finding, not a test to weaken.)

- [ ] **Step 5: Import and commit**

```bash
gtimeout -k 5 300 env HOME="$PWD/.tmp/gdhome" godot --headless --import >/dev/null 2>&1
git add autoload scripts tests docs tools
git commit -m "feat: the right stick and the mouse aim casts freely, snapped to an exact axis near horizontal and vertical"
```

---

### Task 4: The reticle, the debug overlay, and the sweep

**Files:**
- Create: `scripts/player/aim_reticle.gd`, `tests/test_aim_reticle.gd`
- Modify: `scripts/player/player.gd` (`_build_body`, `form_size`), `scripts/ui/hud.gd`, `tests/test_input_debug.gd`, `docs/playtest-checklist.md`, `tools/vfx_shots.gd`

**Interfaces:**
- Consumes: `Player.free_aim()`, `Player.can_cast()`, `Player.pointer_override` (Task 3), `Controls.aim_device`, `Controls.raw_right_stick()` (Task 1), `Controls.mouse_aim` (Task 2).
- Produces: `Player.form_size() -> float` (the form definition's `size`, 1.0 with none), `AimReticle` (`class_name`, `Node2D` named `AimReticle`, `bind(player: Player)`), a child of the Player stored as `Player._reticle`.

- [ ] **Step 1: Write the failing tests** (`tests/test_aim_reticle.gd`, fixture and `_right`/`_mouse_at` helpers as in Task 3; the reticle is found by `player.get_node("AimReticle")`)

```gdscript
func _reticle() -> AimReticle:
	return player.get_node("AimReticle")

func _step() -> void:
	_reticle()._process(0.0)

func test_hidden_with_no_pointer() -> void:
	_step()
	assert_false(_reticle().visible)

func test_visible_and_rotated_to_the_stick() -> void:
	_right(0.0, -1.0)
	_step()
	assert_true(_reticle().visible)
	assert_almost_eq(_reticle().rotation, -PI / 2.0, 0.001)

func test_visible_and_rotated_to_the_cursor() -> void:
	_mouse_at(Vector2(0, 100))
	_step()
	assert_true(_reticle().visible)
	assert_almost_eq(_reticle().rotation, PI / 2.0, 0.001)

func test_scaled_by_the_forms_size_even_when_the_form_has_its_own_art() -> void:
	_right(1.0, 0.0)
	_step()
	assert_eq(_reticle().scale, Vector2.ONE, "a fresh slime")
	assert_true(player.advance_form("weaver", true))  # weaver: size 1.12 and its own sheet, so body_scale() is 1.0
	player._evolve_time = 0.0  # the evolve moment would hide the reticle
	assert_eq(player.body_scale(), 1.0)
	_step()
	assert_eq(_reticle().scale, Vector2.ONE * 1.12)

func test_hidden_whenever_a_cast_cannot_fire() -> void:
	_right(1.0, 0.0)
	player._channel = autofree(Ability.new())
	_step()
	assert_false(_reticle().visible, "a live channel: it is latched, so a live reticle would point elsewhere")
	player._channel = null
	_step()
	assert_true(_reticle().visible)
	player.health.take_hit(player.health.hp, "physical")
	_step()
	assert_false(_reticle().visible, "dead")

func test_it_does_not_hide_for_an_empty_slot() -> void:
	_right(1.0, 0.0)
	_step()
	assert_true(_reticle().visible, "no skill is even equipped")

func test_it_is_not_a_colorrect_and_not_a_vfx_node() -> void:
	assert_false(_reticle() is ColorRect)
	assert_false(_reticle().is_in_group("vfx"))
```

In `tests/test_input_debug.gd`: add `after_each` `PadInput.reset()` beside its existing reset, fix the header ("F1 / Back" is stale: the key is F3), and add tests on a live `game`: with the left stick up and the right stick right, `game.hud.input_debug_text()` contains `aim (1, 0)`; with nothing held it contains `aim default`; with the right stick at (0.3, 0.1) (under the deadzone) it contains `rstick dev 0 (0.30, 0.10)` (format from Step 3; the overlay prints two decimals) and still `aim default`; after `PadInput.mouse_move(Vector2(10, 0))` it contains `mouse on`.

- [ ] **Step 2: Run to verify it fails**

Run: `tools/run_tests.sh test_aim_reticle`
Expected: FAIL (no node named `AimReticle`; `AimReticle` unknown).

- [ ] **Step 3: Implement**

`scripts/player/aim_reticle.gd`:

```gdscript
class_name AimReticle
extends Node2D
## Where the pointer (right stick or mouse) aims: a chevron and two dots along +X, turned to the aim each frame and drawn over the body. Shown
## only while a cast could fire; it says where the aim points, not whether a skill is ready. Fixed geometry, so nothing is
## redrawn per frame.

const COLOR := Color(0.85, 0.95, 1.0)
const CHEVRON := 28.0
const DOTS := [40.0, 52.0]

var _player: Player

func _init() -> void:
	name = "AimReticle"
	visible = false
	z_index = 7

func bind(player: Player) -> void:
	_player = player

func _process(_delta: float) -> void:
	if _player == null:
		return
	var aim := _player.free_aim()
	visible = aim != Vector2.ZERO and _player.can_cast()
	if visible:
		rotation = aim.angle()
		scale = Vector2.ONE * _player.form_size()

func _draw() -> void:
	draw_polyline(PackedVector2Array([Vector2(CHEVRON - 5.0, -5.0), Vector2(CHEVRON + 1.0, 0.0), Vector2(CHEVRON - 5.0, 5.0)]), Color(COLOR, 0.95), 2.0)
	draw_circle(Vector2(DOTS[0], 0.0), 2.0, Color(COLOR, 0.7))
	draw_circle(Vector2(DOTS[1], 0.0), 1.5, Color(COLOR, 0.4))
```

In `Player`: `var _reticle: AimReticle`; in `_build_body`, after `add_child(rope_line)`: `_reticle = AimReticle.new()`, `_reticle.bind(self)`, `add_child(_reticle)` (`_build_body` runs only when the scene supplies no children, which is how tests and the game build it); next to `body_scale()`:

```gdscript
## The current form's nominal size (1.0 with none). body_scale() is 1.0 for the forms drawn from their own art, which are
## drawn larger natively; this is what the reticle scales by.
func form_size() -> float:
	var d := form_def()
	return d.size if d != null else 1.0
```

Run the headless import (new `class_name`).

`scripts/ui/hud.gd` `input_debug_text`: the doc line says it reports the aim a cast would use now (`cast_aim()`); replace `_vec(_player.aim_vector())` with `_aim_text(_player.cast_aim())`; the first line gains `rstick dev %d %s` with `Controls.aim_device` and `_vec(Controls.raw_right_stick())` (the owning pad's ungated reading) and `mouse %s` (`"on" if Controls.mouse_aim else "off"`); and:

```gdscript
static func _aim_text(v: Vector2) -> String:
	return "default" if v == Vector2.ZERO else _vec(v)
```

Sweep: `docs/playtest-checklist.md` lines 5, 6, 24 and 28 (the mouse or the right stick aims skills freely, snapped near horizontal and vertical, with a small reticle; LMB/RMB are skills 1 and 2; the left stick and keys are unchanged and 8-way), line 39 means the left stick and should start working with the paused-`Controls` fix, and new lines "unplug the pad while holding the right stick: the reticle goes away", "a bumped mouse aims; W/S hands the aim back", "crouch or reel with S while the mouse is live: the reticle hides and the chips show U/O/H/L until the mouse moves or clicks; a click still fires at the cursor", and "click a windowed game to focus it: note whether it casts"; line 25 ("assigns it to U (again: O)") gains "(LMB/RMB with the mouse)".

- [ ] **Step 4: Run to verify it passes**

Run: `tools/run_tests.sh test_aim_reticle`, `tools/run_tests.sh test_input_debug`, `tools/run_tests.sh test_art_visuals`, then the full suite `tools/run_tests.sh`.
Expected: all PASS.

- [ ] **Step 5: Screenshot and commit**

Real-renderer check (windowed, unsandboxed, as `tools/vfx_shots.gd` does; pin `Controls.mouse_aim = false` at the start of that script): send a right-stick event, shoot the reticle at two angles on the base slime and once on an enlarged form; then warp the real cursor (`Input.warp_mouse`) to a point in a room where the camera is away from the origin and shoot the reticle following it; and shoot the HUD with the `LMB/RMB/Q/E` chips (three characters in a 20 px chip). Read the images, fix anything that does not read. Then:

```bash
git add autoload scripts tests docs tools
git commit -m "feat: an aim reticle for the right stick and the mouse, the debug overlay reports the cast aim, docs swept"
```

---

## Final steps

Whole-branch review with an opus reviewer (`review-package` per the skill; give it the Review Focus above verbatim and the spec), one fix pass (each fix RED to GREEN, suite green), then `finishing-a-development-branch`: merge to `main`, run the full suite on the merged tree, push, relaunch the game.
