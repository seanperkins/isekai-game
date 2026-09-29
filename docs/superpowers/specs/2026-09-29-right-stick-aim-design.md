# Aiming with the right stick or the mouse: design

## Goal

Play with keyboard and mouse, or with a controller, and aim a skill in any direction with the second pointing device of
either: the mouse cursor, or the right stick. See where the skill will go. The left stick and the keys keep working exactly
as they do now, every action is reachable without taking the right hand off the mouse, and a player who never touches the
mouse or the right stick notices nothing.

## Today

- `Player.raw_aim()` reads the left stick (`Controls.last_stick`, raw, so a light tilt counts) or the keys
  (`move_left/right`, `aim_up/down`); a held left stick beats the keys. `resolve_aim` snaps it to 8 directions; under
  `AIM_DEADZONE` (0.35) it is "no aim".
- `use_active` stores `ability.aim = aim_vector() if aim_held() else Vector2.ZERO` at the press. `ZERO` means "nothing
  held": each ability applies its own default (`aim_dir()`: forward, or up-and-forward for Swing Thread).
- Nothing re-reads the aim after the press. Hydraulic Propulsion latches its own direction (`_dir`); Sticky Thread latches
  its target.
- `raw_aim()` also drives things that are not casting: the puddle spread (`wants_spread`) and rope reeling (`raw_aim().y`).
- `Controls._input` caches the left stick per axis (`last_stick`, last writer wins). For every joypad motion event it also
  sets `last_device`; an axis past 0.25 or a pad button sets `using_joypad`, and a key press or any mouse button event
  clears it. `using_joypad` picks the HUD's slot labels and hints (`slot_labels()`: `LB/RB/LT/RT` or `U/O/H/L`; the eat and
  inspect prompts say `B`/`Y` or `K`/`I`). The right stick has no input action and the mouse has no binding: skills are
  `U/O/H/L` or `LB/RB/LT/RT`, tackle `J`, eat `K`, inspect `I`, all under the right hand.
- **Two sites rely on the 8-way snap making a "flat" aim exactly `y == 0`**: Hydraulic Propulsion's horizontal lift
  (`is_zero_approx(dir.y)`) and `Player.apply_impulse`'s "a flat push keeps the current vertical speed"
  (`is_zero_approx(v.y)`), which Jet Dash and Hydraulic Propulsion both go through. A free-angle aim would almost never
  hit exactly zero, so a "forward" dash would cancel a jump or a fall and lose the lift.
- Measured in a spike on this engine (4.7, headless): `Input.parse_input_event` of a joypad motion updates
  `Input.get_joy_axis(device, axis)` per device, so the right stick can be polled and two pads never mix. And a tree that
  is paused does not deliver `_input` to `Controls` (`can_process()` is false): while the skill screen is open no stick
  or key event reaches it, so `last_stick` (which the skill screen reads for navigation) goes stale, and a right stick
  first pushed during a pause would never be noticed.

## Design

The two schemes are the two values of `using_joypad`: **pad** (left stick moves, right stick aims) and **keyboard and
mouse** (keys move, the cursor aims). Whichever device was used last is the scheme.

1. **`Controls` reads the right stick.**
   - `process_mode = PROCESS_MODE_ALWAYS` in `_ready`, so it keeps seeing input while the skill screen has the tree paused.
     `Controls` only observes events and never consumes them, so this has no downside; it also fixes `last_stick` under the
     skill screen and lets F11 work while paused.
   - `aim_device` (int, -1 for none): the device of the last right-stick event past `STICK_DEADZONE` (0.25), set in
     `_input`. A reading under 0.25 from another pad (sensor noise from an idle second pad) does not take the stick.
     A pad button press can set `using_joypad` before any right-stick push, so `aim_device` can be -1 while `using_joypad`
     is true: `right_stick()` is `ZERO` then.
   - `raw_right_stick()` is `Vector2(Input.get_joy_axis(aim_device, JOY_AXIS_RIGHT_X), ...RIGHT_Y)` (`ZERO` for device -1),
     ungated; the debug overlay shows the owning pad's raw reading. `right_stick()` is that reading when `using_joypad` is
     true, `aim_device >= 0` and its length is at least `RIGHT_STICK_DEADZONE` (0.45), else `ZERO`. Polling fixes a pause
     and two pads at once. It does not fix a stick released with no final event: the engine's per-device axis is as stale
     as a cached one would be, so what protects against drift is the deadzone. A resting stick at (0.25, 0.25), the action
     deadzone on each axis, is 0.354 and must not aim; and any reading of 0.45 or more has an axis of at least 0.318, past
     0.25, so it has produced an owning event.
   - `Input.joy_connection_changed`: when the device that left is `aim_device`, reset it to -1.
   - `using_joypad` also enables the right stick. A key press or mouse click clears it, so a pad that has gone quiet cannot
     steer a keyboard player; a pad that keeps emitting past 0.25 sets it again on its own (a limit, see Failure modes). A
     keyboard skill press (U/O/H/L) closes the gate, so with a right stick at rest that cast uses what `raw_aim()` reads
     today: a held left stick first, then the keys.
2. **`Controls` reads the mouse and gives the keyboard scheme a left-hand layout.**
   - `mouse_aim` (bool): true once the mouse has moved 4 game px in total (`MOUSE_MOVE_MIN`; `_mouse_travel` sums each
     motion's `relative` length, so a slow drag counts and a single sensor twitch does not) or a mouse button has been
     pressed (the wheel does not count, and a release does nothing); either also clears `using_joypad`. `_use_pad()` (any
     pad input: the places that set `using_joypad`) clears `mouse_aim` and zeroes `_mouse_travel`, and so does a
     vertical aim key press while the tree is not paused (`aim_up` or `aim_down`; key presses only, since the D-pad and
     left stick already go through `_use_pad()`; while the skill screen has the tree paused W/S navigate it and aim
     nothing, so they leave the mouse aim and the badge alone). The last of "the mouse moved" and "an aim key was pressed" aims. Horizontal movement keys do not affect
     it, so running never drops the mouse aim. A player who never touches the mouse has `mouse_aim` false forever.
   - Mouse buttons are skill aliases, bound for any device: left button to `active_1`, right button to `active_2`
     (`MOUSE_BUTTONS`, added by `ensure_actions`). A click casts on press; holding it holds a channel (the release check reads
     the action's raw strength).
   - Left-hand aliases, so nothing needs the right hand while it is on the mouse: `Shift` tackle, `F` eat (hold), `R`
     inspect, `Q` slot 3, `E` slot 4. `J`, `K`, `I`, `U`, `O`, `H` and `L` keep working. `Q`/`E` are also the skill screen's
     tab keys; that screen pauses the tree, so no cast can fire from them.
   - `slot_labels()`: the pad labels when `using_joypad`, `LMB/RMB/Q/E` when `mouse_aim`, else `U/O/H/L`. `eat_label()` and
     `inspect_label()` (used by the eat and inspect prompts in `Player`): `B`/`Y` for the pad, `F`/`R` when `mouse_aim`,
     else `K`/`I`.
   - `signal scheme_changed`, emitted from `_input` whenever `slot_labels()` changes. `Controls` now processes while paused,
     so the scheme can change under the skill screen, which builds its slot badge and hints only when it refreshes; it
     connects the signal and refreshes while open.
3. **`Player.free_aim()`**: the pointer's direction, `ZERO` when neither pointer is engaged. The source is
   `Controls.right_stick()`, else `mouse_direction()`: `ZERO` unless `Controls.mouse_aim` is true, else
   `cursor - global_position` when its length is at least `MOUSE_DEADZONE` (12 world px from the origin, so a cursor close
   to the body does not jitter); `cursor` is `get_global_mouse_position()` (which applies the camera and zoom), or
   `pointer_override` when a test sets one. `Controls._input` owns the exclusion between the two pointers (`_use_pad()`
   clears `mouse_aim`; a mouse event clears `using_joypad`), so `mouse_direction()` does not re-check it. The source is
   normalised, then free (any angle) except: if
   `abs(y) <= sin(10 degrees)` it is exactly `(sign(x), 0)`, and if `abs(x) <= sin(10 degrees)` exactly `(0, sign(y))`.
   That keeps both flat-aim sites above exact (a shallow aim reads as flat) and absorbs a thumb's or a hand's wobble;
   comparing components has no wrap-around at 180 degrees. The reticle and the cast both read this and nothing else, so
   the deadzone rules live in one place.
4. **`Player.cast_aim()`**: the direction a skill is fired in. `free_aim()` when it is not `ZERO`, else
   `aim_vector() if aim_held() else Vector2.ZERO` (left stick or keys, 8-way, or "nothing held"). `use_active` sets
   `ability.aim = cast_aim()`; `last_cast["aim"]` is still `ability.aim_dir()`. With the mouse live and the cursor more than 12 px
   from the origin there is always an aim: skills go where the cursor is.
5. **`raw_aim()` is unchanged.** Spread and rope reeling stay on the left stick and keys, so neither the right stick nor the
   mouse ever flattens the slime or reels a rope. The pointer beats the left stick and keys for the cast only.
6. **`Player.can_cast()`**: `not (health.is_dead() or predation.active() or _channel != null or evolving())`. `use_active`
   opens with `if not can_cast(): return`: today's guards plus `evolving()`, which is unreachable in play (`_physics_process`
   returns before any cast while evolving) and harmless. The reticle asks it too.
7. **`AimReticle`** (a `Node2D` named `AimReticle`, its own file, added in `Player._build_body()` beside `rope_line`): a
   chevron and two dots drawn once along +X with `_draw()`, at 28, 40 and 52 px from the player's origin (the point skills
   fire from), on top of the body. Each frame it reads `free_aim()` once, sets `visible = aim != ZERO and can_cast()`, and
   while visible `rotation = aim.angle()` and `scale = Vector2.ONE * player.form_size()`. `form_size()` (an instance method)
   is the form definition's `size` (1.0 with none): `body_scale()` is 1.0 for the four forms drawn from their own art,
   which are drawn larger natively, so it cannot be used. It shows for the mouse as well as the right stick: the cursor is
   the target, the reticle is the exact (snapped) direction the skill will take. Empty slots, cooldowns and low MP do not
   hide it: it shows where the aim points, not whether a cast is ready. It does not hide for the skill screen or a room
   slide: the first covers the world with a dim and a panel, and the second is 0.35 s. It shows the **aim direction**, not a
   trajectory: Jet Dash flattens the vertical part and Puffball lobs, so those land differently.
8. **Debug overlay** (`hud.gd`): the `aim` field, documented as the aim the player would cast with right now, becomes
   `cast_aim()` (printed as `default` when it is `ZERO`); the first line also shows `Controls.aim_device` and
   `Controls.raw_right_stick()` (the owning pad's ungated reading), and `mouse_aim`.
9. **Facing** does not follow the right stick or the mouse: it follows movement, as today, so a cast behind the slime leaves
   it facing forward. Turning to face the aim is a later change.

## Failure modes

- Drift and release: a stick under 0.45 does not engage; a disconnect resets the owning device.
- Two pads: the last pad to push its right stick past 0.25 owns it, wholly. If the engine keeps a departed device's axis
  values, a pad that reconnects could read a stale axis until it moves; check in the playtest.
- Ghost or unmapped axes (some generic pads report triggers on the right-stick axes): if such a pad keeps emitting
  motion it re-arms `using_joypad` after every key press and pins the aim. This is a known limit; the fix is remapping,
  which is not in this change; the same pad also keeps a keyboard-and-mouse player from holding mouse aim. Playtest with a
  real pad.
- A keyboard-only player who bumps the mouse (4 px in total) gets mouse aim until they press a vertical aim key. Accepted:
  the reticle shows it at once, and W/S (or the arrows) hands the aim back.
- W/S are also the puddle key and the rope-reel keys, so a mouse player who crouches or reels presses an aim key: the reticle hides and the chips flip to `U/O/H/L` until the mouse moves 4 px or clicks, and a cast on a keyboard
  skill key in that window goes along the keys. A click still fires at the cursor (a button press sets `mouse_aim`
  before the physics step that casts). Accepted: every cheaper rule (never clear it, or clear it on any key) is worse.
- Shift is tackle and is mashable; on Windows five quick Shift presses can open the Sticky Keys prompt. Note it if a
  Windows build is planned.
- The click that focuses a windowed game may arrive as a mouse press: it can cast skill 1 and turn mouse aim on. Check in
  the playtest (the game starts fullscreen, where it does not arise).
- The cursor within 12 px of the origin falls back to the keys or forward, so a cast never fires at a random angle. Where
  the cursor is aimed when it leaves the window is left to the engine; check in the playtest.
- Free angles: every ability reads `aim_dir()` (a normalised vector); the only 8-way assumptions were the two flat-aim
  sites, handled by the snap. Jet Dash's damped vertical and Puffball's lift are existing shaping of the aim.
- Non-monotonic bands the free aim can reach, accepted: Hydraulic Propulsion at levels 1 to 7 lifts less aimed 10 to
  about 22 degrees up than aimed flat (the flat lift is a fixed -140, the aimed lift grows with the angle); a mid-jump Jet
  Dash aimed from 10 degrees up to `asin(rise / 420)` rises less than a flat one (52 degrees at the start of a base jump,
  more with high jump height; the 8-way diagonal already sits in this band early in a jump), and aimed just under the snap
  band downward it cancels the rise.
- The left stick already aims from a resting (0.25, 0.25) (length 0.354 is over `AIM_DEADZONE`); out of scope.

## Consistency sweep (surfaces that change)

- `docs/playtest-checklist.md`: the Controls and Gamepad lines (5, 6: add the mouse, the right stick and the skill
  aliases), "aims the skill (8-way)" (24), the controller aiming check (28): add the mouse, the right stick and the
  reticle; line 39 ("the stick moves one row per push") means the left stick and is expected to start working with the
  paused-`Controls` fix; add "unplug the pad while holding the right stick: the reticle goes away" and "a bumped mouse
  aims; W/S hands the aim back".
- `Player`: the eat and inspect prompts (`Controls.eat_label()`, `inspect_label()`), comment on `AIM_DEADZONE` ("Stick/keys below this length cast forward"), the "Nothing held" comment in
  `use_active`, the `raw_aim()` doc (left stick or keys; the pointers are deliberately excluded).
- `Controls`: the header ("the last device used picks the HUD labels"), a doc line on `using_joypad` (it also enables the
  right stick), on `STICK_DEADZONE` (it also decides right-stick ownership), on `last_stick` (it drives `raw_aim` and
  skill-screen navigation), on `aim_device` and on `mouse_aim`; `slot_labels()` and its test
  (`tests/test_controls_joypad.gd`, which keeps passing: `mouse_aim` is false there).
- `skill_screen.gd`: connects `Controls.scheme_changed` and refreshes its badge and hints while open.
- `tools/vfx_shots.gd` runs windowed and scripts casts that expect the default aim: it pins `Controls.mouse_aim = false`.
- `docs/playtest-checklist.md:25` ("assigns it to U (again: O)") gains "(LMB/RMB with the mouse)", and line 5 the left-hand
  layout: "(with the mouse: Shift tackle, F hold to eat, R inspect, Q/E skills 3 and 4)".
- `hud.gd`: the doc above `input_debug_text` and its format string (`aim_device`, the raw right stick, `mouse_aim`,
  `default` for a zero aim). `hydraulic_propulsion.gd`'s header ("A horizontal burst also lifts"): now within 10 degrees.
- Existing tests that pin bindings and change with the left-hand aliases, each with a comment saying why:
  `tests/test_accessors.gd:32` (`tackle` has J, Shift and the pad button: 3 events) and
  `tests/test_controls_joypad.gd`'s `test_keyboard_skill_keys_are_u_o_h_l` (slots 3 and 4 also carry Q and E).
- `tests/test_aiming.gd` header ("8-way") and `tests/test_input_debug.gd` header ("F1 / Back"; the key is F3): true only
  of the left stick and keys.

## Not in this change

Aim assist toward nearby enemies, steering a channel with the pointer, turning to face the aim, a remapping UI,
skill-aware trajectory previews, hiding the reticle for the skill screen or a room slide, hiding the OS cursor while a pad
is used, confining the cursor to the window, mouse wheel actions, mouse buttons for tackle, eat and inspect (the left-hand
keys cover them).

## Tests

`tests/support/pad_input.gd` (`class_name PadInput`, as `tests/support/test_defs.gd` is) holds the helpers every new test
uses. Each sends its event through `Input.parse_input_event` and `Input.flush_buffered_events()` and nothing else: measured
in a spike, the engine delivers a parsed event to `Controls._input` (and updates `get_joy_axis` and the action state) while
the tree is not paused, so calling `_input` by hand as well would deliver it twice and double the accumulated mouse travel.
`axis(axis, value, device := 0)`, `key(keycode)` (press then release), `button(index, device := 0)` (pad button, press then
release), `mouse_move(relative)`, `mouse_button(index, pressed := true)`, and `reset()` (zero all four stick axes on devices
0 and 1, release both mouse buttons, reset `aim_device`, `last_device`, `last_stick`, `using_joypad`, `mouse_aim` and
`_mouse_travel`, release `aim_up`/`aim_down`/`move_left`/`move_right`). Every new test file, and `tests/test_input_debug.gd`
(which will now push both sticks on a live game), calls `PadInput.reset()` in `after_each`, and a test that pauses the tree
unpauses it there. Vector comparisons use `is_equal_approx`, except the snapped axes, which are exact.

- `Controls`, right stick: paused, `Controls.can_process()` is still true and a right-stick push sent while paused still sets
  `aim_device` (the positive case: `PROCESS_MODE_ALWAYS` delivers input under a pause); a push past 0.25 makes its device the owner and
  the polled reading comes back; a pad button press with no right-stick push (`using_joypad` true, `aim_device` -1) reads
  `ZERO`; an owning push of (0.3, 0.3) reads `ZERO` (0.424, under 0.45), and so does (0.25, 0.25) after it; a sub-0.25
  event from a second device does not take the stick (device 0 right = 1.0, then device 1 right-Y = 0.05: still (1, 0)); a
  real push on the second takes it wholly; a key press makes it `ZERO` and a 0.5 right-stick event after it engages it
  again (the limit, pinned); the disconnect handler, called directly with the axis still held on the departing device,
  resets the owner and reads `ZERO`.
- `Controls`, mouse (`PadInput.mouse_move` speaks game px: it applies the root viewport's stretch scale first, because the
  engine divides an event's `relative` by it on the way in, and a pin test checks `_mouse_travel` after a 3 px move):
  3 px then 3 px sets `mouse_aim` and clears `using_joypad`; a single 3 px does neither; a pad input between two 3 px
  moves resets the total (nothing set); a left or right button press (each) does both and its release changes
  nothing (hold a button, push the pad, release: the pad stays live); a wheel event does neither; a pad button or push
  clears `mouse_aim`; `aim_up` or `aim_down` pressed clears it; `move_left` pressed does not; `active_1` and `active_2`
  each have a mouse-button event in the `InputMap` and the left-hand aliases exist (`tackle` Shift, `predate` F, `inspect`
  R, `active_3` Q, `active_4` E); a parsed left-button press makes `Input.is_action_pressed("active_1")` true and its
  release false; `slot_labels()` is `LMB/RMB/Q/E` with `mouse_aim`, the pad labels with `using_joypad`, `U/O/H/L`
  otherwise, and `eat_label()`/`inspect_label()` follow the same three states; `scheme_changed` fires once when the labels
  change and not when they do not; the skill screen, open with a slotted skill selected, shows `[U]` and then `[LMB]` when
  the mouse first moves, and pressing S while it is open leaves `mouse_aim` and the badge alone.
- `Player.free_aim`/`cast_aim`, right stick: 30 degrees up from right is that exact normalised vector; the snap holds on all
  four axes at 5 degrees each side (including 180 +/- 5), does not snap at 10.1 degrees and does at 9.9; a partial tilt of
  (0.55, 0.13) (13 degrees once normalised) is not snapped, so the comparison is on the normalised vector; under the
  deadzone (a right stick at (0.3, 0.1)) falls back to the left stick's snapped aim, then to `ZERO`; the right stick wins over a held left stick and over
  the keys; a device-1 right stick then a key press (which clears the gate) then a left stick held from before the key
  press (`Controls.last_stick` set directly: a new left-stick event would re-arm the pad and the right stick would win)
  casts along the left stick, and with the left stick neutral along the keys.
- `Player.free_aim`/`cast_aim`, mouse (with `pointer_override`): `ZERO` while `mouse_aim` is false; the cursor 30 degrees up
  from the player is that exact direction; the snap holds at 5 degrees off horizontal; a cursor 5 px away is `ZERO` and
  falls back to the keys; a pad push after the mouse hands the aim back to the stick; the cast follows the cursor over a held
  left stick and over the keys.
- `can_cast()`: once per state (dead through `health.take_hit(health.hp, "physical")` because setting `hp` does not set
  the dead flag; eating; channel live; evolving; none), and `use_active` does nothing in the first three.
- A mouse click drives a channel: a parsed left-button press with Hydraulic Propulsion in slot 1 starts it, and the
  parsed release ends it.
- One end-to-end cast: with the right stick at 30 degrees, `use_active` on Water Blade sets `ability.aim`,
  `last_cast["aim"]` matches, and the slash is turned to the angle; the same with the cursor.
- The two flat-aim sites: Hydraulic Propulsion cast with the aim 3 degrees off horizontal keeps its lift; Jet Dash mid-jump
  3 degrees off horizontal keeps `velocity.y`.
- Spread and rope reel ignore both pointers.
- The pointer moving during a live Hydraulic hold does not change `_dir`.
- Reticle: hidden with no pointer; visible and rotated to the stick, and to the cursor; scaled by the form's `size` (evolve to
  weaver, 1.12, which has its own art, then clear the evolve moment; a fresh player is 1.0); hidden when `can_cast()` is
  false; not a `ColorRect` and not in group `vfx`.
- Debug overlay: with the left stick up and the right stick right the `aim` field reads right, it reads `default` with
  nothing held, and the first line shows the owning pad's raw right stick even under the deadzone (`(0.30, 0.10)`: the
  overlay prints two decimals), and `mouse_aim`.
