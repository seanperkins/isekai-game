# Channeled Skills and Skill Effects — Design

Status: revised after debate round 3 (2026-09-29). Follows `2026-09-29-skill-evolution-branches-design.md` (an evolved skill
replaces its parent). Answers Sean's note: "The animations for the web and the water blade just looked like lines. Let's try to
make them more interesting. And I think you should be able to hold down for the Web or the water jet. So maybe before it
becomes water blade it's like a water stream." Feel references: `docs/research/metroidvania-reference.md` § 3.

## What I understood

1. **Hold to channel.** Every active is one press and one instant effect. Sean wants the web (Sticky Thread) and the water
   jet (Hydraulic Propulsion) to be things you *hold*. "Before it becomes Water Blade it's like a water stream" reads against
   the evolution rule: the base skill is the stream you sustain, and at level 3 it turns into a Water Blade or a Jet Dash. The
   same holds for Sticky Thread, the web you hold before it turns into Swing Thread or Binding Web.
2. **The web and the water blade should not look like lines.** The thread is a 1 px `Line2D` (`ThreadAbility`'s flash and
   `Player.rope_line`), the blade a 3 px line for 0.2 s (`WaterBlade`), and Binding Web's patch a flat translucent square.

Success: hold the button and the skill runs until you let go, run out of MP or hit its short limit; a tap does exactly what it
does today; the thread looks like silk, the blade like a crescent of water, the stream like a jet of spray, and Binding Web's
patch like a web. The other skills' looks are a follow-up (see "Not here").

## Decisions

| Topic | Decision |
|---|---|
| Which skills channel | The two **base** skills only: Sticky Thread and Hydraulic Propulsion. Their evolutions stay one-shot |
| Contract | `Ability` gains `can_channel() -> bool` (default false; asked after `aim` is set, before anything is paid), `begin_channel()` (**defaults to `_perform()`**, so a tap is literally today's cast), `channel_tick(delta: float) -> bool` (false ends it), `end_channel(hard := false)` (sets the 0.8 s cooldown; subclasses stop their effects first; a **hard** stop, from any stop site other than release, the MP beat, the cap or the tick ending, also hides the persistent nodes at once so no spray or strand is left frozen or drifting, while a soft stop lets the last 0.35 s of spray finish) and `var max_channel := 0.0` (seconds; 0 means no cap; set in `_init()` like `rope_range`, since a subclass cannot redeclare a parent `const`). A one-shot ability never sees any of it |
| `use_active(i)` | While a channel is live, **every press is ignored** (no cost, no event, no preemption: release first). Otherwise: after the existing `ready()` check, set the aim, and if `can_channel()`: pay the start cost as today (with the form discount), call `begin_channel()`, remember the ability in `Player._channel`, emit `SKILL_USED` and set `last_cast` once. If `can_channel()` is false the press is the unchanged one-shot `activate()` path with the cooldown at press. A refused or one-shot press pays nothing extra |
| The loop | `Player._channel_step(delta)` runs each physics tick **immediately after the four `use_active` checks and before `move_and_slide`** (so the press tick is step 1, a beat lands on the 30th physics frame after the press, and the stream sees this tick's gravity), in this order: **release** (`Input.get_action_raw_strength(action) < 0.3`, raw so a trigger that dips below its 0.5 press deadzone mid-hold keeps the channel; the tests feed a real `InputEventJoypadMotion`), then the **MP beat** (below), then the **cap** (`elapsed >= max_channel - EPS` when `max_channel > 0`), then `channel_tick(delta)`. Any of them ending calls `end_channel()` once. The direction is **latched at the press by the ability**: with no stick held `ability.aim` stays `Vector2.ZERO` and `aim_dir()` re-reads `facing` on every call, so the stream stores `_dir := aim_dir()` in `begin_channel()` and uses `_dir` for the thrust and the spray, and nothing re-reads `aim_dir()` per tick. `Player` does not write the resolved direction back into `ability.aim` (`test_aim_fixes.gd:58` pins a zero aim for a cast with nothing held) |
| MP | The start cost is today's `mp_cost`. While held, **one point every 0.5 s** (2 MP/s): a cadence timer with a small epsilon calling `Mana.spend(1)` and emitting one `MANA_SPENT` per point like the start cost, so holding counts toward Mana Recovery; trait discounts apply to the start cost only; running out ends the channel silently; regen keeps running. Beats fall on the ticks at 0.5 s, 1.0 s and so on, so a hold of 1.0 s pays 2 points; a full stream hold (0.6 s) pays 1 (3 + 1); a full web hold (3.0 s, the beat at 3.0 s is paid before the cap ends it) pays 6 (3 + 6) |
| Stop | Beside each existing `drop_rope()` call: `begin_predate`, `_begin_evolve_moment`, `_on_run_started`, `_on_health_died`, and `World._transition` (before the slide freezes the player; under the same `has_method` guard as `drop_rope`, since `World.player` can be a plain body in tests). Also `SkillScreen.open()` (`if _player != null`, before it pauses, since a paused tree cannot tick and a held button could otherwise outlive a slot change or an evolution made in the menu) and `Player.receive_hit`, **right after its invulnerability and dead gate, unconditionally and outside the `if from != Vector2.INF` knockback block**, so a spit or spore-puff hit (no `from`) also ends it (a hit ends any channel, like Hollow Knight's Focus; a hit the gate ignores does not). `Player.end_channel()` is public and does nothing when no channel is live |
| Water stream | `can_channel()` is always true. `begin_channel()` is the burst (`_perform`, the impulse and the afterimage), so a tap that releases on the first step is today's cast. While held, each tick the ability computes `v = actor.velocity` (which already includes this tick's gravity), adds `300 px/s squared` along the latched aim only while `v.dot(aim) < BASE_PUSH x value/100`, and calls `actor.apply_impulse(v)`, which keeps `velocity.y` when the new y is zero and re-arms the 0.25 s lock; no new `Player` API. `max_channel` 0.6 s. Level 1: a full horizontal hold (0.6 s plus the 0.25 s lock tail) travels about 323 px against a tap's 95 while falling about 200 px; a full upward hold rises about 120 px against 80 (thrust 300 is a third of gravity 900, so the net deceleration is 600). So the stream stretches the burst and does not fly: it cannot climb a shaft (a tap chain out-climbs it). A full hold costs 3 + 1 MP. `end_channel()` stops the emitter and leaves `_dash` alone. Enemies in the spray are not hurt |
| Web | `sticky_thread.gd` only. `ThreadAbility._perform`'s target-versus-terrain decision is factored into `_first_contact()` used by both paths. `can_channel()` is true when an **enemy** is the first contact. `begin_channel()` is `_perform()` (the tier applies at once, the 0.35 s flash draws) and shows the persistent tether strand. While held, **every tick**: the target must pass `is_instance_valid()` (a non-predatable enemy is freed a tick after it dies) and then `can_be_hit()` where the target has it (`has_method`, as `Ability.targets_in_front` guards it; false for downed, dying and gone enemies), be within `rope_range + 20` px and not behind rock (`terrain_hit`); then `receive_thread(value())` is re-applied (idempotent: the stun timer resets, the slow is a max) and the strand redrawn. Any failure ends the channel. `max_channel` 3.0 s, so a held predatable enemy stays stunned at most 3 s plus its normal 3 s after (3 + 6 MP). Terrain first and nothing in reach are the unchanged one-shot: the rope attaches, or the strand flashes, with the press cooldown. Swing Thread and Binding Web never channel |
| Persistent nodes | The stream emitter (`CPUParticles2D`) and the tether strand (`Line2D`, `top_level`) are **children of the ability**, built once, toggled by `emitting` / `visible`, and not in group `vfx`; the ability is a child of the player and cached for the run. Only the self-freeing crescent and the flash strand are `vfx` nodes. The tether strand is redrawn in the ability's `_process`, which must call `super._process(delta)` first (the base advances the cooldown) (after the physics step, like `rope_line` in `_update_visual`), not inside `channel_tick`, so it does not trail the slime by a tick |
| Textures | All **procedural**, cached, in one small `VfxArt` (`scripts/ui/vfx_art.gd`, beside `Art`; three textures, built like `terrain_motes.gd`'s `Image` plus `ImageTexture.create_from_image`): `silk()` (a 32x4 tileable strand: bright centre rows with a brighter bead every 8 px), `web(px)` (an `Image` with 8 spokes and 3 rings, drawn crisp at the patch's real size, 80x80 for Binding Web's radius 40; one octant is drawn and mirrored so it is exactly symmetric), `crescent()` (a 96x48 crescent from two circles with a soft alpha edge and a bright rim). The soft spray texture is `Art.light_texture()` itself (the cached radial gradient the point lights share), tinted only through `modulate` and particle `color`, never edited. No image-model art and no pipeline: `assemble_frames.py` packs sheets and `crisp_alpha` erases thin threads and soft edges, so the image pipeline fits neither. RGB is white and tinted in the engine, so a texture can be replaced later without touching a caller |
| Look: web | `Vfx.style_strand(line)` (texture `silk()`, tile mode, `texture_repeat` enabled, width 4) and `Vfx.sag_points(from, to) -> PackedVector2Array` (5 points on a shallow quadratic, first the slime and last the anchor) are shared by the flash strand (`Vfx.strand(actor, from, to, seconds)` replacing `Vfx.line` for every thread flash), the tether strand and `Player.rope_line` (whose ends are unchanged). Binding Web's patch: `SporeCloudArea.launch` takes `opts.look = "web"` and puts a `web(80)` sprite where the square is; a zone with no look keeps its square |
| Look: water | **Stream**: the emitter emits from the slime's back (opposite the latched aim) with `soft()` tinted blue, a scale of about 0.05 for droplets, and `local_coords = false` so the spray trails. **Water Blade**: one `crescent()` `Sprite2D` (top-level, group `vfx`) starting at the caster plus 24 px along the aim, rotated to the aim, and tweened over 0.22 s (scale 0.6 to 1.3, alpha to 0, and sliding out to the blade's end: the enemy it hit, else full range), so a far hit still has a blade near it. The blade's damage and range are unchanged |
| Skill card | The Skills tab card adds "Hold: +1 MP every 0.5 s" for the two channel skills (`SkillScreenModel.CHANNEL_SKILLS := ["sticky_thread", "hydraulic_propulsion"]` beside `ACTIVE_LABEL`, since the model is static and sees only defs), the number read statically from `Player.CHANNEL_BEAT`; their descriptions say to hold; `ACTIVE_LABEL` for `hydraulic_propulsion` stays "Distance %" (the value is still the burst's push) |
| Actor contract | `ability.gd`'s header adds that the stream reads `velocity` and calls `apply_impulse` (which it already required). Test doubles that call `channel_tick` need a `velocity` variable |

## Where each thing lives

- `scripts/abilities/ability.gd` (the contract), `scripts/player/player.gd` (`_channel`, `_channel_step`, `end_channel()`,
  `CHANNEL_BEAT`, the calls beside each `drop_rope`, the hit hook, `rope_line` styling and `_update_rope_line`'s sag),
  `scripts/world/world.gd` (`end_channel()` beside `drop_rope()`), `scripts/ui/skill_screen.gd` (`open()` ends the channel),
  `scripts/ui/skill_screen_model.gd` (the card line).
- `hydraulic_propulsion.gd` (stream), `sticky_thread.gd` (tether), `thread_ability.gd` (`_first_contact`, the strand flash),
  `water_blade.gd` (crescent), `binding_web.gd` and `spore_cloud_area.gd` (the web look, and their doc comments for `opts.look`),
  `vfx.gd` (`strand`, `style_strand`, `sag_points`), `scripts/ui/vfx_art.gd` (new), `tools/build_content.gd` (descriptions),
  `docs/playtest-checklist.md`, `tools/vfx_shots.gd` (new, copied from `tools/evolution_shots.gd`, for screenshots).

## Failure modes and edge cases

- A press while a channel is live is ignored, whatever the slot.
- Releasing in the same physics frame as the press: the first `_channel_step` sees the release and ends it, so `end_channel()`
  runs once and nothing leaks; that is the definition of a tap in the tests.
- The tethered enemy dies, is downed or is eaten: the next tick's checks end the channel and the strand hides.
- A room change or the skill screen mid-channel: ended before the slide or the pause, so no spray or strand shows.
- A hit ends the channel in `receive_hit` before knockback sets the velocity, so the knockback survives the frame.
- `do_tackle` is refused while `_dash > 0` (the stream re-arms it each tick, 0.25 s): a tackle straight out of a stream waits
  for that tail, as after any burst.
- Streaming while already roped behaves like today's burst on a rope: `_swing` and `_stay_on_rope` constrain velocity every
  tick, so the stream needs no refusal (a rope cannot attach mid-stream, since presses are ignored).
- An upward stream keeps `velocity.x` at 0 for the hold plus the 0.25 s lock (the `_dash` gate skips walking), so a sideways
  drift onto a ledge waits for the tail; a playtest check.
- Mana Recovery at its maximum (+300, regen 400%): regen keeps running, and the caps (0.6 s, 3.0 s) bound every channel.
- A multi-tick press differs from today's tap by design (a 6-tick upward press rises about 92 px against 80): the channel
  extends the burst. The cooldown starts at release, not at the press.
- The Skills tab and the HUD show the start cost as before (the slot dimming compares against it).

## Testing

Ability contract: a one-shot ability is untouched; `can_channel` defaults false; `begin_channel` defaults to `_perform`;
`end_channel` sets the cooldown and runs once however the channel stops. Player, driving real physics frames: press starts (a press with nothing held while facing right, then `move_left` held for the whole hold, keeps `velocity.x` at the burst value: the latched direction),
held ticks, release ends (a trigger fed through a parsed `InputEventJoypadMotion` at 0.4 keeps the channel and at 0.2 ends
it, and the test asserts `get_action_strength` would have read 0 at 0.4), MP short ends it silently, `max_channel` ends it,
every press on any slot is ignored while a channel is live (one cost, one `skill_used`; `test_use_active_emits_skill_used_with_cooldown`
stays green), a contact hit **and a `receive_poison`** end it (knockback velocity intact for the contact hit), a press in the 0.8 s after release costs nothing and a press after 0.8 s casts again (press, release step, press again: one cost; wait 0.8 s: a second cast, for Sticky Thread too, since its `_process` override calls `super`), and predation, the evolution moment, death, run start,
`World._transition` and `SkillScreen.open()` end it. MP: beats at 0.5 s and 1.0 s from any start (the float boundary: exactly
2 points by 1.0 s), one `MANA_SPENT` per point, a discounted start with an undiscounted beat, the full stream hold 3 + 1 and
the full web hold 3 + 6. Stream: a Player-level tap (release on the first step, and a 6-tick press) keeps the burst's full
0.25 s lock and at least 95 px, a full horizontal hold moves at most 3.5x a tap (simulated 3.0x), a full upward hold rises at most 1.6x a
tap's apex, it ends at 0.6 s even at regen 400%, and gravity still applies. Web: enemy first channels with the tier applied
at once and the flash drawn (a tap equals today's), each tick re-applies, ends on range, rock, a freed target, a downed
target and release, holds at most 3 s; terrain first and nothing in reach are the unchanged one-shot with the press cooldown
and the rope re-aim cannot be spammed. Look: `sag_points` has 5 points ending at the anchor, the strand texture is set with
repeat on, the rope keeps its endpoints (`test_player_rope.gd:16-23`), the emitter toggles with the channel and is a child of the
ability, the persistent nodes are not in `vfx`, the crescent tweens and frees itself, the web look replaces the square only for
Binding Web (`test_spore_cloud.gd` haze assertions untouched), and the three `VfxArt` textures have their sizes, `crescent()` has
more than two alpha levels, `silk()` tiles (its first and last columns continue the pattern), `web(80)` is exactly symmetric under a quarter turn. Screenshots: one image per look in use, looked at before merge.

**Tests that change, with why:** `test_vfx.gd:53-63` and `test_aiming.gd:71-74` (Water Blade was a `Line2D`; it becomes a
crescent sprite), `test_player_rope.gd:16-23` (`rope_line.points[1]` becomes the last point). The other Sticky Thread and
Hydraulic Propulsion tests call `activate()`, which is unchanged.

**Consistency surfaces:** the Sticky Thread and Hydraulic Propulsion descriptions in `tools/build_content.gd`, the regenerated
`data/skills/*.tres`, `docs/playtest-checklist.md` lines 22, 24 and 31, and the header comments of `hydraulic_propulsion.gd`,
`sticky_thread.gd`, `thread_ability.gd`, `ability.gd`, `vfx.gd`, `binding_web.gd`, `water_blade.gd` ("drawn as a streak") and `spore_cloud_area.gd` (the option list).

## Rulings I made

1. **Only the base skills channel.** The evolutions replace them; Sean asked for the base skills. Cost if wrong: an override of
   `can_channel()` on an evolved ability.
2. **A tap that releases on the first step is today's cast** for both skills (`begin_channel` is `_perform`). Cost if wrong: none.
3. **The stream is an extended burst, not a jetpack.** Thrust 300 px/s squared, a 0.6 s cap and the burst's own speed as the
   thrust cap keep a full hold to about 3.0x a tap horizontally (323 px against a simulated tap of 108) and 1.5x vertically; a sustained flight would skip every
   vertical gate. Cost if wrong: two constants.
4. **Presses are ignored while a channel is live.** One rule instead of preemption ordering. Cost if wrong: you cannot cast a
   second skill out of a hold without releasing first.
5. **Holding a web keeps a predatable enemy stunned** for up to 3 s at 2 MP/s: the value of the channel.
6. **Drained points emit `MANA_SPENT`**, so holding feeds Mana Recovery (bounded by the caps).
7. **All textures are procedural.** The image pipeline packs sheets and thresholds alpha, and the looks are simple shapes.
   Cost if wrong: less hand-drawn charm; replacing a texture touches `VfxArt` only.
8. **The drain is a constant beat in `Player`**, not data; a second channel skill needing another rate is the moment to change it.

## Not here

The looks of Venom Bolt (a travelling bolt), Jet Dash, Poison Breath, Miasma, Healing Spores, Puffball (the pod) and every
other zone (Spore Cloud's square); a held Water Blade, a charged Jet Dash, a held Poison Breath; a Thread Recall teleport;
sustained audio loops; gamepad rumble; a hold indicator on the slot icon.
