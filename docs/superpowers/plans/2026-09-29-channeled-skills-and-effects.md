# Channeled Skills and Skill Effects Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (Sean's standing choice: native, inline). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Hold Sticky Thread (the web) and Hydraulic Propulsion (the water stream) to sustain them, and give the thread, the water blade and Binding Web's patch real looks.

**Architecture:** `Ability` gets an optional channel lifecycle (`can_channel`, `begin_channel` defaulting to `_perform`, `channel_tick`, `end_channel`, `max_channel`); `Player` owns one live channel and steps it after the `use_active` checks each physics tick (release, MP beat, cap, tick). The stream is an extended burst through `apply_impulse`; the web sustains `receive_thread`. Looks are procedural textures in a small `VfxArt`, a few `Vfx` helpers, and persistent effect nodes that are children of the ability.

**Tech Stack:** Godot 4.7 GDScript, GUT 9.7.1. Tests: `tools/run_tests.sh [substr]` (whole suite about 3 minutes). After adding a `class_name`/scene/asset run `gtimeout -k 5 300 env HOME="$PWD/.tmp/gdhome" godot --headless --import >/dev/null 2>&1`. Content is regenerated with `godot --headless -s tools/build_content.gd`.

**Spec:** `docs/superpowers/specs/2026-09-29-channeled-skills-and-effects-design.md` (debated through three rounds plus a verification pass). Read it before Task 1; it is the authority, and this plan only orders the work.

## Global Constraints

- A tap (a release seen on the first channel step) is today's cast for both skills: `begin_channel()` defaults to `_perform()`, and the stream's burst impulse and the web's immediate `receive_thread(value())` are unchanged.
- `max_channel` is a `var` set in `_init()` (0.6 for the stream, 3.0 for the web); a subclass cannot redeclare a parent `const`.
- Per-tick channel order in `Player._channel_step`: release (`Input.get_action_raw_strength(action) < 0.3`), then the MP beat (one `Mana.spend(1)` every 0.5 s with an epsilon, one `MANA_SPENT` per point), then the cap (`elapsed >= max_channel - EPS`), then `channel_tick(delta)`. `_channel_step` runs immediately after the four `use_active` checks and before `move_and_slide`.
- While a channel is live every press is ignored. The direction is latched by the ability in `begin_channel()` (`_dir := aim_dir()`); `ability.aim` is never rewritten by `Player`.
- Stop sites (call `end_channel(true)` via `Player.end_channel()`): beside each `drop_rope()` in `begin_predate`, `_begin_evolve_moment`, `_on_run_started`, `_on_health_died`; `World._transition` (under a `has_method("end_channel")` guard); `SkillScreen.open()` (`if _player != null`, before pausing); and `Player.receive_hit` right after its invuln/dead gate, outside the knockback block.
- Persistent effect nodes (stream `CPUParticles2D`, tether `Line2D`) are children of the ability, built once, not in group `vfx`. The tether strand is redrawn in the ability's `_process`, which calls `super._process(delta)` first.
- All textures are procedural (`VfxArt`: `silk()`, `web(px)`, `crescent()`); the soft spray texture is `Art.light_texture()`, tinted through `modulate`/particle `color` only.
- Commit messages carry no attribution lines. Work in this worktree (`.worktrees/effects`, branch `feat/channeled-effects`).

## Review Focus

1. The stream steering with `facing` when no stick is held (Task 2's test holds the other direction).
2. A poison hit (no `from`) not ending a channel (Task 1).
3. A trigger dipping to 0.4 mid-hold ending the channel because of the action deadzone (Task 1, real `InputEventJoypadMotion`).
4. The overriding `_process` swallowing the cooldown (Task 4).
5. A multi-tick tap losing part of the burst's 0.25 s lock (Task 2).

## File Map

- Modify: `scripts/abilities/ability.gd`, `hydraulic_propulsion.gd`, `sticky_thread.gd`, `thread_ability.gd`, `water_blade.gd`, `binding_web.gd`, `spore_cloud_area.gd`, `vfx.gd`; `scripts/player/player.gd`, `scripts/world/world.gd`, `scripts/ui/skill_screen.gd`, `scripts/ui/skill_screen_model.gd`; `tools/build_content.gd` (descriptions), regenerate `data/skills`; `docs/playtest-checklist.md`.
- Create: `scripts/ui/vfx_art.gd`, `tools/vfx_shots.gd`; tests `tests/test_channel.gd`, `tests/test_vfx_art.gd`, and additions to existing files.
- Tests that change: `test_vfx.gd:53-63` and `test_aiming.gd:71-74` (Water Blade line becomes a crescent), `test_player_rope.gd:16-23` (the rope's last point is the anchor).

---

### Task 1: The channel contract and the Player loop

**Files:** Modify `scripts/abilities/ability.gd`, `scripts/player/player.gd`, `scripts/world/world.gd`, `scripts/ui/skill_screen.gd`; Create `tests/test_channel.gd`.

**Interfaces:** Produces `Ability.can_channel() -> bool`, `begin_channel()`, `channel_tick(delta) -> bool`, `end_channel(hard := false)`, `var max_channel := 0.0`; `Player.CHANNEL_BEAT := 0.5`, `Player.end_channel()`, `Player._channel`.

- [ ] **Step 1: Read the fixtures.** Read `tests/test_player.gd` (how a `Player` with a slotted skill is built; the test around line 165 `test_use_active_emits_skill_used_with_cooldown`), `tests/test_mana.gd:100-110`, and `tests/test_controls_joypad.gd:8-13` (the `_axis` helper that feeds an `InputEventJoypadMotion`). Reuse their setup in the new file.
- [ ] **Step 2: Failing tests** — `tests/test_channel.gd` with a test-only channelling ability:
  ```gdscript
  class TestChannel extends Ability:
  	var began := 0
  	var ticks := 0
  	var ended := []
  	func _init() -> void:
  		max_channel = 1.0
  	func can_channel() -> bool:
  		return true
  	func begin_channel() -> void:
  		began += 1
  	func channel_tick(_delta: float) -> bool:
  		ticks += 1
  		return true
  	func end_channel(hard := false) -> void:
  		ended.append(hard)
  		super.end_channel(hard)
  ```
  Register it in the player's ability cache for a slotted skill (`player._abilities["hydraulic_propulsion"] = ch`, the way tests substitute abilities; check `_ability(id)` for the cache). Tests (each drives real physics frames with `Input.action_press("active_1")` / `action_release`):
  - a press starts the channel once: `began == 1`, one `skill_used`, one MP cost, `player._channel == ch`;
  - a second `use_active(0)` and a `use_active(1)` while live change nothing (cost, event, `began`);
  - releasing ends it exactly once, softly (`ended == [false]`), and the cooldown then runs: a press right after costs nothing, a press after 0.85 s casts again;
  - MP beat: hold 1.0 s from 20 MP: MP is 20 - cost - 2; `MANA_SPENT` count is cost + 2; hold to the cap (1.0 s): ends with `ended == [false]`;
  - MP runs out: start with only `cost + 0` MP left after the start cost: the first beat ends it silently;
  - `max_channel` ends it at the cap even with regen 400% (set `stats` modifier `mp_regen` to 400);
  - a trigger axis: bind slot 3 (`active_3`), feed `InputEventJoypadMotion` axis 0.4 mid-hold: still channelling; 0.2: ended (and assert `Input.get_action_strength("active_3") == 0.0` at 0.4 to prove the deadzone is why raw is used);
  - a contact hit (`player.receive_hit(1, "physical", Vector2(-50, 0))`) ends it hard and the knockback velocity survives; `receive_poison(1, 1, 2.0)` ends it too; a hit swallowed by `_invuln` does not;
  - predation (`begin_predate` with a target), `_begin_evolve_moment`, `_on_health_died`, `_on_run_started`, `World._transition` and `SkillScreen.open()` each end it hard (`ended == [true]`).
  A one-shot ability (`water_blade`) still casts through `activate()`.
- [ ] **Step 3: RED** — `tools/run_tests.sh test_channel` (the API does not exist).
- [ ] **Step 4: Implement `Ability`** (`scripts/abilities/ability.gd`): add
  ```gdscript
  ## Channelling (opt in): an ability that can be held. `can_channel` is asked after `aim` is set and before anything is paid;
  ## `begin_channel` defaults to the one-shot cast, so a tap is today's cast; `channel_tick` returns false to end; `end_channel`
  ## starts the cooldown. `max_channel` is the hold's cap in seconds (0 = none), set in `_init()` like `rope_range`.
  var max_channel := 0.0

  func can_channel() -> bool:
  	return false

  func begin_channel() -> void:
  	_perform()

  func channel_tick(_delta: float) -> bool:
  	return true

  ## `hard` is a stop from outside the hold (menu, hit, room change...): subclasses also hide their persistent nodes at once.
  func end_channel(_hard := false) -> void:
  	_cooldown = COOLDOWN_SECONDS
  ```
  and update the file header's actor contract to say the stream reads `velocity` and calls `apply_impulse`.
- [ ] **Step 5: Implement `Player`** (`scripts/player/player.gd`):
  ```gdscript
  const CHANNEL_BEAT := 0.5
  const CHANNEL_EPS := 0.0001
  const CHANNEL_RELEASE := 0.3  # raw strength: a trigger dipping under its 0.5 press deadzone mid-hold keeps the channel

  var _channel: Ability = null
  var _channel_slot := 0
  var _channel_time := 0.0
  var _channel_beat := 0.0
  ```
  `use_active(i)`: first line after the dead/predation guard: `if _channel != null: return  # release first`. After the `ready()` check and the MP payment, replace the tail with:
  ```gdscript
  	ability.level = _rules.level_of(id)
  	ability.aim = aim_vector() if aim_held() else Vector2.ZERO
  	# the MP payment moves after the channel decision is known; see below
  ```
  Concretely, restructure so the order is: `ready()`, `ability.level`, `ability.aim`, `var channels := ability.can_channel()`, pay the cost (unchanged), then `if channels: ability.begin_channel(); _channel = ability; _channel_slot = i; _channel_time = 0.0; _channel_beat = 0.0 else: ability.activate()`, then the unchanged `last_cast`, `SKILL_USED` and `MANA_SPENT` lines. (Setting the aim before the payment is harmless: a refused payment returns without casting.)
  `_channel_step`, called in `_physics_process` right after the `use_active(3)` line and before `var fall_speed := velocity.y`:
  ```gdscript
  func _channel_step(delta: float) -> void:
  	if _channel == null:
  		return
  	if Input.get_action_raw_strength("active_%d" % (_channel_slot + 1)) < CHANNEL_RELEASE:
  		end_channel(false)
  		return
  	_channel_time += delta
  	_channel_beat += delta
  	while _channel_beat >= CHANNEL_BEAT - CHANNEL_EPS:
  		_channel_beat -= CHANNEL_BEAT
  		if not mana.spend(1):
  			end_channel(false)
  			return
  		_emit.call(Events.MANA_SPENT, {})
  	if _channel.max_channel > 0.0 and _channel_time >= _channel.max_channel - CHANNEL_EPS:
  		end_channel(false)
  		return
  	if not _channel.channel_tick(delta):
  		end_channel(false)
  ```
  and
  ```gdscript
  ## Ends the live channel, if any. A hard stop (anything but the hold running its course) also clears the ability's spray/strand.
  func end_channel(hard := true) -> void:
  	if _channel == null:
  		return
  	var c := _channel
  	_channel = null
  	c.end_channel(hard)
  ```
  (The public no-argument call is a hard stop; `_channel_step` passes `false` for its own soft endings.) Call `end_channel()` beside `drop_rope()` in `begin_predate`, `_begin_evolve_moment`, `_on_run_started` and `_on_health_died`, and in `receive_hit` right after `if _invuln > 0.0 or health.is_dead(): return`. Update the header comment.
  The beat: verify the boundary in the test with the exact tick counts the spec pins (2 points by 1.0 s from a press on tick 1).
- [ ] **Step 6: `World` and `SkillScreen`.** `world.gd` `_transition`: under the existing `if player.has_method("drop_rope"): player.drop_rope()` add `if player.has_method("end_channel"): player.end_channel()`. `skill_screen.gd` `open()`: first line `if _player != null:\n\t\t_player.end_channel()`.
- [ ] **Step 7: GREEN** — `tools/run_tests.sh test_channel`, then `test_player`, `test_mana`, `test_world`, `test_menu_input`, `test_skill_screen`.
- [ ] **Step 8: Mutation checks** — swap `get_action_raw_strength` for `get_action_strength` (the 0.4 test must fail); move the `receive_hit` stop inside the `if from != Vector2.INF` block (the poison test must fail); restore.
- [ ] **Step 9: Commit** — `git add -A scripts tests && git commit -m "feat: the channel contract and the Player loop (release, MP beat, cap, stops)"`.

---

### Task 2: The water stream

**Files:** Modify `scripts/abilities/hydraulic_propulsion.gd`; extend `tests/test_channel.gd` or create `tests/test_water_stream.gd`.

- [ ] **Step 1: Failing tests** (real `Player`, the real `hydraulic_propulsion` ability slotted, physics frames, gravity applies in the air, no floor below):
  - a tap (`action_press`, one physics frame, `action_release`) equals today's cast: the existing `test_abilities.gd:71-77` and `test_aiming.gd:81-83` still pass (impulse via `activate()`), and at Player level the slime travels at least 95 px horizontally after a horizontal tap (it keeps the burst's full 0.25 s lock);
  - a 6-tick press travels at least as far as the tap (never less: the lock is not cut);
  - a full horizontal hold (held past 0.6 s) ends at the cap, moves at most 3.5x a tap's distance, and gravity still applies (y grows);
  - a full upward hold rises at most 1.6x a tap's apex;
  - with no stick held and facing right, holding `move_left` for the whole hold never drops `velocity.x` below the burst value (the latched direction);
  - the hold ends at 0.6 s with regen 400%; the emitter is a child of the ability, emitting while held and not after; a hard stop hides it at once;
  - cost: a full hold spends the start cost + 1 MP.
- [ ] **Step 2: RED**, **Step 3: Implement** `hydraulic_propulsion.gd`:
  ```gdscript
  extends Ability
  ## Water-powered burst along the aim; values are percent of base distance. A horizontal burst also lifts a little so it
  ## clears small gaps. Held, it keeps going: an extended burst (thrust while below the burst's own speed, 0.6 s at most),
  ## with a spray behind the slime. It stretches the burst; it does not fly.

  const BASE_PUSH := 380.0
  const HORIZONTAL_LIFT := -140.0
  const THRUST := 300.0  # px/s^2 along the latched aim, only while below the burst speed

  var _dir := Vector2.RIGHT
  var _spray: CPUParticles2D

  func _init() -> void:
  	max_channel = 0.6

  func _ready() -> void:
  	_spray = CPUParticles2D.new()
  	_spray.emitting = false
  	_spray.amount = 24
  	_spray.lifetime = 0.35
  	_spray.local_coords = false
  	_spray.texture = Art.light_texture()
  	_spray.scale_amount_min = 0.03
  	_spray.scale_amount_max = 0.06
  	_spray.color = Color(0.5, 0.85, 1.0, 0.8)
  	_spray.spread = 25.0
  	_spray.initial_velocity_min = 60.0
  	_spray.initial_velocity_max = 110.0
  	_spray.gravity = Vector2(0, 120)
  	add_child(_spray)

  func _perform() -> void:
  	var dir := aim_dir()
  	var push := dir * BASE_PUSH * value() / 100.0
  	if is_zero_approx(dir.y):
  		push.y += HORIZONTAL_LIFT
  	actor.apply_impulse(push)
  	Vfx.puffs(actor, Art.texture("slime_idle"), [actor.global_position], Color(0.5, 0.8, 1.0, 0.6), 0.25)  # afterimage

  func can_channel() -> bool:
  	return true

  func begin_channel() -> void:
  	_dir = aim_dir()  # latched: with nothing held aim_dir() would follow `facing` every tick
  	_perform()
  	_spray.emitting = true
  	_spray.visible = true
  	_aim_spray()

  func channel_tick(delta: float) -> bool:
  	var v: Vector2 = actor.velocity
  	if v.dot(_dir) < BASE_PUSH * value() / 100.0:
  		v += _dir * THRUST * delta
  	actor.apply_impulse(v)  # keeps velocity.y when it is zero, and re-arms the burst's 0.25 s lock
  	_aim_spray()
  	return true

  func end_channel(hard := false) -> void:
  	_spray.emitting = false
  	if hard:
  		_spray.visible = false
  	super.end_channel(hard)

  func _aim_spray() -> void:
  	_spray.position = -_dir * 10.0
  	_spray.direction = -_dir
  ```
  Adjust the particle setup to whatever renders acceptably in Step 6's screenshot (numbers are starting values); keep the structure. `begin_channel` shows the spray if a previous hard stop hid it.
- [ ] **Step 4: GREEN**, then `test_abilities`, `test_aiming`, `test_vfx`, `test_player`.
- [ ] **Step 5: Screenshot** the stream (a scratch script in `.tmp/`, windowed, unsandboxed), Read the image, adjust the spray so it reads as spray behind the slime.
- [ ] **Step 6: Commit** — `git commit -m "feat: hold Hydraulic Propulsion for a water stream (an extended burst)"`.

---

### Task 3: VfxArt, the strand helpers and the rope

**Files:** Create `scripts/ui/vfx_art.gd`, `tests/test_vfx_art.gd`; Modify `scripts/abilities/vfx.gd`, `scripts/abilities/thread_ability.gd`, `scripts/player/player.gd`; modify `tests/test_player_rope.gd`, extend `tests/test_vfx.gd`.

- [ ] **Step 1: Failing tests** — `tests/test_vfx_art.gd`: `VfxArt.silk()` is 32x4, non-null, alpha present, and tiles (the pattern repeats with period 8 px: column `x` equals column `x + 8` for all rows); `VfxArt.web(80)` is 80x80, exactly symmetric under a quarter turn (compare `get_image()` pixels rotated by 90 degrees), has opaque threads and transparent gaps; `VfxArt.crescent()` is 96x48 with more than two distinct alpha values; each returns the same cached object on a second call. `tests/test_vfx.gd`: `Vfx.sag_points(Vector2.ZERO, Vector2(100, 0))` has 5 points, first `(0,0)`, last `(100,0)`, the middle sagging below the chord; `Vfx.style_strand(line)` sets texture, `texture_mode` tile, `texture_repeat` enabled and width 4; the thread flash (`Vfx.strand`) is a `Line2D` in group `vfx` with 5 points ending at the target. `tests/test_player_rope.gd:16-23`: change `rope_line.points[1] == anchor` to `points[-1] == anchor` and `points[0] == global_position`, and assert the rope line's texture is `VfxArt.silk()`.
- [ ] **Step 2: RED**, **Step 3: Implement.** `scripts/ui/vfx_art.gd`:
  ```gdscript
  class_name VfxArt
  extends RefCounted
  ## Procedural effect textures, white and tinted in the engine so any of them can be replaced without touching a caller.
  ## Built like terrain_motes.gd: an Image, then ImageTexture.create_from_image, cached.

  static var _silk: Texture2D
  static var _crescent: Texture2D
  static var _web := {}

  ## A 32x4 tileable silk strand: two bright centre rows, faint outer rows, a brighter bead every 8 px.
  static func silk() -> Texture2D:
  	if _silk == null:
  		var img := Image.create(32, 4, false, Image.FORMAT_RGBA8)
  		for x in 32:
  			var bead := x % 8 < 2
  			img.set_pixel(x, 0, Color(1, 1, 1, 0.25))
  			img.set_pixel(x, 1, Color(1, 1, 1, 1.0 if bead else 0.8))
  			img.set_pixel(x, 2, Color(1, 1, 1, 1.0 if bead else 0.8))
  			img.set_pixel(x, 3, Color(1, 1, 1, 0.25))
  		_silk = ImageTexture.create_from_image(img)
  	return _silk

  ## A web `px` across: 8 spokes and 3 rings, drawn as one octant and mirrored so it is exactly symmetric.
  static func web(px: int) -> Texture2D:
  	if not _web.has(px):
  		var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
  		var c := (px - 1) / 2.0
  		for y in px:
  			for x in px:
  				var dx := absf(x - c)
  				var dy := absf(y - c)
  				var r := sqrt(dx * dx + dy * dy)
  				var ring := false
  				for k in [0.35, 0.65, 0.95]:
  					if absf(r - k * c) < 0.9:
  						ring = true
  				var spoke := dx < 0.9 or dy < 0.9 or absf(dx - dy) < 0.9
  				if r <= c and (ring or spoke):
  					img.set_pixel(x, y, Color(1, 1, 1, 0.9))
  		_web[px] = ImageTexture.create_from_image(img)
  	return _web[px]

  ## A 96x48 crescent from two circles with a soft alpha edge and a bright rim.
  static func crescent() -> Texture2D:
  	if _crescent == null:
  		var img := Image.create(96, 48, false, Image.FORMAT_RGBA8)
  		for y in 48:
  			for x in 96:
  				var outer := Vector2(x - 24.0, y - 24.0).length()   # the big circle, open to the right
  				var inner := Vector2(x - 40.0, y - 24.0).length()   # bites the crescent out of it
  				var a := clampf((24.0 - outer) / 6.0, 0.0, 1.0) * clampf((inner - 20.0) / 6.0, 0.0, 1.0)
  				if a > 0.0:
  					var rim := clampf(1.0 - (24.0 - outer) / 10.0, 0.0, 1.0)
  					img.set_pixel(x, y, Color(1, 1, 1, a * (0.55 + 0.45 * rim)))
  		_crescent = ImageTexture.create_from_image(img)
  	return _crescent
  ```
  (The `web` loop is symmetric by construction because it uses `dx`, `dy` absolute values; the octant claim in the spec is satisfied by that symmetry, and the quarter-turn test proves it.) `Vfx` (`scripts/abilities/vfx.gd`): 
  ```gdscript
  ## Five points on a shallow quadratic from `from` to `to` (the first is `from`, the last `to`), sagging a little.
  static func sag_points(from: Vector2, to: Vector2) -> PackedVector2Array:
  	var out := PackedVector2Array()
  	var sag := minf(from.distance_to(to) * 0.06, 8.0)
  	for i in 5:
  		var t := i / 4.0
  		out.append(from.lerp(to, t) + Vector2(0.0, sag * 4.0 * t * (1.0 - t)))
  	return out

  ## Silk look for a Line2D: the strand texture, tiled along the line, 4 px wide.
  static func style_strand(l: Line2D) -> void:
  	l.texture = VfxArt.silk()
  	l.texture_mode = Line2D.LINE_TEXTURE_TILE
  	l.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
  	l.width = 4.0
  	l.default_color = Color(0.95, 0.95, 1.0, 0.9)

  ## A thread flash: a silk strand that fades and frees itself.
  static func strand(actor: Node2D, from: Vector2, to: Vector2, seconds: float) -> Line2D:
  	var l := Line2D.new()
  	l.add_to_group("vfx")
  	l.top_level = true
  	style_strand(l)
  	l.points = sag_points(from, to)
  	_host(actor).add_child(l)
  	_fade(l, seconds)
  	return l
  ```
  `thread_ability.gd`: replace the two `Vfx.line(actor, ..., THREAD_COLOR, 1.0, 0.35)` calls with `Vfx.strand(actor, from, ..., 0.35)`. `player.gd` `_build_body`: replace the `rope_line.width/default_color` lines with `Vfx.style_strand(rope_line)`; `_update_rope_line`: `rope_line.points = Vfx.sag_points(global_position, rope.anchor)`. Update `vfx.gd`'s header comment ("short-lived ... free themselves": persistent channel nodes are not `vfx`).
- [ ] **Step 4: Import** (new `class_name`), **GREEN** — `test_vfx_art`, `test_vfx`, `test_player_rope`, `test_grapple`, `test_abilities`, `test_aiming`.
- [ ] **Step 5: Commit** — `git commit -m "feat: silk strand, web and crescent textures; the thread flash and the rope draw as silk"`.

---

### Task 4: The web tether

**Files:** Modify `scripts/abilities/thread_ability.gd`, `scripts/abilities/sticky_thread.gd`; extend `tests/test_evolution_abilities.gd` or create `tests/test_web_tether.gd` (use the `RopeActor`/`_enemy` doubles from `test_grapple.gd`, adding `velocity`, `can_be_hit` where needed).

- [ ] **Step 1: Failing tests:**
  - enemy first: `can_channel()` true; `begin_channel()` applies `receive_thread(value())` at once (a tap is today's) and the flash strand exists; terrain first: `can_channel()` false, `activate()` ropes with the cooldown; nothing in reach: false;
  - each `channel_tick` re-applies `receive_thread`; it returns false (ends) when the target is out of `rope_range + 20`, behind a solid, freed (`is_instance_valid`), or has `can_be_hit()` false; a double without `can_be_hit` is treated as hittable;
  - through a real `Player`: a hold longer than 3.0 s ends at the cap; the full hold costs start + 6 MP; the persistent tether strand is a `Line2D` child of the ability, visible while channelling with the silk texture, hidden after, not in group `vfx`, and redrawn after the physics step (its last point tracks the target in `_process`);
  - the cooldown: after a soft end, a press within 0.8 s costs nothing and a press after 0.85 s casts again (the `_process` override calls `super`);
  - `swing_thread` and `binding_web` never channel (`can_channel()` false).
- [ ] **Step 2: RED**, **Step 3: Implement.** `thread_ability.gd`: factor the decision out of `_perform`:
  ```gdscript
  ## What the thread meets first along the aim: {"target": Node2D or null, "anchor": Vector2 or null}.
  func _first_contact() -> Dictionary:
  	var dir := aim_dir()
  	var from := actor.global_position
  	var target: Node2D = null
  	for t in targets_in_front(rope_range, 24.0):
  		if t.has_method("receive_thread"):
  			target = t
  			break
  	var anchor = terrain_hit(from, from + dir * rope_range)
  	if target != null and (anchor == null or from.distance_to(target.global_position) <= from.distance_to(anchor)):
  		return {"target": target, "anchor": null}
  	return {"target": null, "anchor": anchor}
  ```
  and have `_perform()` use it (behaviour unchanged: enemy branch, rope branch, flash branch as today). `sticky_thread.gd`:
  ```gdscript
  extends ThreadAbility
  ## Short thread: slows then holds an enemy, or swings from terrain up to 120 px away. Held on an enemy it keeps re-applying.

  var _target: Node2D = null
  var _strand: Line2D

  func _init() -> void:
  	rope_range = 120.0
  	reel_speed = 60.0
  	release_boost = 1.0
  	max_channel = 3.0

  func _ready() -> void:
  	_strand = Line2D.new()
  	_strand.top_level = true
  	Vfx.style_strand(_strand)
  	_strand.visible = false
  	add_child(_strand)

  func can_channel() -> bool:
  	return _first_contact()["target"] != null

  func begin_channel() -> void:
  	_target = _first_contact()["target"]
  	_perform()  # the tier at once and the flash, exactly a tap
  	_strand.visible = true

  func channel_tick(_delta: float) -> bool:
  	if _target == null or not is_instance_valid(_target):
  		return false
  	if _target.has_method("can_be_hit") and not _target.can_be_hit():
  		return false
  	var from := actor.global_position
  	if from.distance_to(_target.global_position) > rope_range + 20.0 or terrain_hit(from, _target.global_position) != null:
  		return false
  	_target.receive_thread(value())
  	return true

  func end_channel(hard := false) -> void:
  	_strand.visible = false
  	_target = null
  	super.end_channel(hard)

  func _process(delta: float) -> void:
  	super._process(delta)
  	if _strand.visible and _target != null and is_instance_valid(_target):
  		_strand.points = Vfx.sag_points(actor.global_position, _target.global_position)
  ```
  (Swing Thread extends `ThreadAbility`, not `StickyThread`, so it never channels; Binding Web too.)
- [ ] **Step 4: GREEN**, then `test_grapple`, `test_abilities`, `test_aiming`, `test_evolution_abilities`, `test_vfx`.
- [ ] **Step 5: Commit** — `git commit -m "feat: hold Sticky Thread on an enemy to keep it webbed"`.

---

### Task 5: The water blade crescent and Binding Web's patch look

**Files:** Modify `scripts/abilities/water_blade.gd`, `scripts/abilities/spore_cloud_area.gd`, `scripts/abilities/binding_web.gd`; modify `tests/test_vfx.gd:53-63`, `tests/test_aiming.gd:71-74`; extend `tests/test_zone.gd` / `test_evolution_abilities.gd`.

- [ ] **Step 1: Tests.** Water Blade: after a cast, one `vfx` `Sprite2D` with `texture == VfxArt.crescent()` exists at the caster plus 24 px, rotated to the aim; it slides out toward the blade's end (the enemy hit, else full range) and frees itself within 0.3 s; damage and range unchanged (existing tests). Replace the old `Line2D`-points assertions (`test_vfx.gd:53-63`, `test_aiming.gd:71-74`) with the crescent's position/rotation. Zone look: `launch(..., {"look": "web"})` makes child 0 a `Sprite2D` with `VfxArt.web(int(radius * 2))`, sized to the radius; with no look it is still a `ColorRect` (`test_spore_cloud.gd:78-83` unchanged); Binding Web's patch has the web look.
- [ ] **Step 2: RED**, **Step 3: Implement.** `water_blade.gd`: keep the targeting; replace the `Vfx.line` with:
  ```gdscript
  	var dir := aim_dir()
  	var crescent := Sprite2D.new()
  	crescent.add_to_group("vfx")
  	crescent.top_level = true
  	crescent.texture = VfxArt.crescent()
  	crescent.modulate = Color(0.45, 0.85, 1.0, 0.9)
  	crescent.global_position = actor.global_position + dir * 24.0
  	crescent.rotation = dir.angle()
  	crescent.scale = Vector2(0.6, 0.6)
  	Vfx._host(actor).add_child(crescent)
  	var tw := crescent.create_tween().set_parallel(true)
  	tw.tween_property(crescent, "scale", Vector2(1.3, 1.3), 0.22)
  	tw.tween_property(crescent, "global_position", end - dir * 24.0, 0.22)
  	tw.tween_property(crescent, "modulate:a", 0.0, 0.22)
  	tw.chain().tween_callback(crescent.queue_free)
  ```
  (add a public `Vfx.host(actor)` wrapper instead of calling `_host` if the style objects; keep the crescent's centre a little short of `end` so it reads as arriving at the target.) Update `water_blade.gd`'s header ("drawn as a crescent"). `spore_cloud_area.gd`: in `launch`, `if opts.get("look", "") == "web": var s := Sprite2D.new(); s.texture = VfxArt.web(int(radius * 2.0)); s.centered = true; s.modulate = opts.get("color", Color(1, 1, 1, 0.9)); add_child(s) else: (the existing ColorRect)`; update the doc comments (`opts` list and "never touches the player"). `binding_web.gd`: pass `"look": "web"` in the patch opts.
- [ ] **Step 4: GREEN**, then `test_vfx`, `test_aiming`, `test_spore_cloud`, `test_zone`, `test_evolution_abilities`.
- [ ] **Step 5: Commit** — `git commit -m "feat: Water Blade is a crescent; Binding Web's patch is a web"`.

---

### Task 6: The Skills card, descriptions, docs, screenshots, full suite

**Files:** Modify `scripts/ui/skill_screen_model.gd`, `scripts/ui/skill_screen.gd`, `tools/build_content.gd`, `docs/playtest-checklist.md`; Create `tools/vfx_shots.gd`; extend `tests/test_skill_screen.gd`.

- [ ] **Step 1: Tests.** The card for `sticky_thread` and `hydraulic_propulsion` includes the line "Hold: +1 MP every 0.5 s" (formatted from `Player.CHANNEL_BEAT`); Swing Thread's does not; the two skills' descriptions mention holding.
- [ ] **Step 2: Implement.** `SkillScreenModel`: `const CHANNEL_SKILLS := ["sticky_thread", "hydraulic_propulsion"]` beside `ACTIVE_LABEL`, and in `detail()` add a `hold_line` (or append to `lines`) when `CHANNEL_SKILLS.has(d.id)`: `"Hold: +1 MP every %s s" % str(Player.CHANNEL_BEAT)`. `tools/build_content.gd`: Sticky Thread's description "Shoot a thread: it slows, then holds, an enemy, or sticks to rock so you can swing. Hold it on an enemy to keep it webbed."; Hydraulic Propulsion "A short water-powered burst. Hold to keep the stream going." Regenerate skills. `docs/playtest-checklist.md`: update lines 22, 24 and 31 and add: "Hold Hydraulic Propulsion: a spray trails the slime and it keeps going a little longer than a tap (0.6 s at most); hold Sticky Thread on an enemy: a silk strand stays taut and the enemy stays stunned, MP ticks down, letting go frees it; a rope on rock is still a tap".
- [ ] **Step 3: Screenshots.** `tools/vfx_shots.gd` (copy `tools/evolution_shots.gd`'s structure): cast and hold each look in a room and save one PNG each (stream mid-hold, tether on an enemy, rope on rock, Water Blade at a target, Binding Web patch). Run unsandboxed, Read every image, fix anything that does not read.
- [ ] **Step 4: Full suite** — `tools/run_tests.sh`; all green.
- [ ] **Step 5: Commit** — `git commit -m "feat: hold hint on the skill card, descriptions, checklist and screenshots for the channels"`.

---

## Final steps (executing-plans)

Whole-branch review with an opus reviewer (`review-package` per the skill; give it the plan's Review Focus verbatim and the spec), one fix pass (each fix RED to GREEN, suite green), then `finishing-a-development-branch`: merge to `main`, run the full suite on the merged tree, push, relaunch the game.
