# Channeled Skills and Skill Effects — Design

Status: draft for debate (2026-09-29), rewritten after the skill-evolution work merged. Follows
`2026-09-29-skill-evolution-branches-design.md`. Answers Sean's note: "The animations for the web and the water blade just
looked like lines. Let's try to make them more interesting. And I think you should be able to hold down for the Web or the
water jet. So maybe before it becomes water blade it's like a water stream." Feel references: `docs/research/metroidvania-reference.md`
§ 3 (held and channelled attacks).

## What I understood

Two things about how skills feel:

1. **Hold to channel.** Every active is one press, one instant effect, then a 0.8 s cooldown. Sean wants the web (Sticky
   Thread) and the water jet (Hydraulic Propulsion) to be things you *hold*. "Before it becomes Water Blade it's like a water
   stream" reads directly against the evolution rule (an evolved skill replaces its parent): the base skill is the stream you
   sustain, and at level 3 it turns into a Water Blade or a Jet Dash. Likewise Sticky Thread is the web you hold before it
   turns into Swing Thread or Binding Web.
2. **Effects that read as matter, not lines.** Today the web is a 1 px `Line2D`, the blade a 3 px line for 0.2 s, the jet and
   dash a faded copy of the idle sprite, the new Venom Bolt a 2 px line, and every cloud (Spore Cloud, Miasma, Healing Spores,
   Puffball, Binding Web's patch) a flat translucent square (`SporeCloudArea`'s `ColorRect`). They should look like silk,
   water, a crescent, a bolt and a cloud.

Success: hold the button and the skill runs until you let go or run out of MP, and every player skill shows something that is
recognisably what it is. Damage, ranges and MP costs of the one-shot skills do not change.

## Decisions

| Topic | Decision |
|---|---|
| Which skills channel | The two **base** skills only: Sticky Thread (the web) and Hydraulic Propulsion (the water stream). Their evolutions stay one-shot with new looks: Swing Thread, Binding Web, Water Blade, Jet Dash and the poison and spore branches. A held Water Blade, a charged Jet Dash and a held Poison Breath are follow-ups (see "Not here") |
| Channel contract | `Ability` gains an optional lifecycle, off by default, so every one-shot ability is untouched: `channels := false`, `begin_channel() -> bool`, `channel_tick(delta: float) -> bool` (false ends it), `end_channel()`. `activate()` stays for one-shots. The player owns the loop |
| The loop | `Player._channel` holds the one live channelling ability and its slot index. On a slot press, `use_active(i)` is unchanged for one-shots; for a channelling ability it pays the start cost, calls `begin_channel()`, and each physics tick `_channel_step(delta)` refreshes the aim, drains MP, calls `channel_tick`, and ends the channel when the slot action is released or a stop condition holds. Only one channel runs at a time; pressing another slot ends the first |
| Stop conditions | Release of the slot action, MP short of the next drain, death, predation starting, a hit taken (water stream only), the evolution moment, the skill screen opening, a room change (`World.room_entered`), and a rope being attached (the stream only) |
| MP | `start` (today's `mp_cost`, so a tap costs what it costs now) plus `drain` per second after the first 0.5 s. `Mana` holds whole points, so the drain is a float accumulator that spends whole points as they fall due (a helper on `Player`, not on `Mana`). Empty MP ends the channel, and the ability's cooldown (0.8 s) starts when the channel ends |
| Data | Each channelling skill's `active` effect gains a `channel` dictionary in `tools/build_content.gd`: `{"drain": 2}` for both. `SkillEffects` reads it (`SkillEffects.channel(def)`), the validator checks it (a positive integer drain only on an active) |
| Levelling | `SKILL_USED` fires once per channel start, as one press does today, so holding is not a faster way to level |
| Water stream | Hold Hydraulic Propulsion: a jet sprays from the slime's back (opposite the aim) and the slime accelerates along the aim, 1100 px/s squared up to a cap of `BASE_PUSH x value/100 x 0.75` px/s (285 at level 1, 855 at level 15 of the existing table), for as long as it is held. Up works (a rising jet) and horizontal keeps the old lift. `Player` keeps horizontal control locked while the stream runs by refreshing its `_dash` timer. A tap is a short spurt about like the old burst. Enemies in the plume are not damaged. The stream is refused while a rope is attached (the rope wins) |
| Web | On the press, the first thing along the aim decides. **Terrain** nearest: the rope attaches exactly as today, no channel. **An enemy** nearest: the thread channels, holding a strand to it and re-applying `receive_thread` every 0.5 s: tier 1 (slow) after 0.4 s and the parent's own tier (`value()`, 2 held at higher levels) after 1.2 s, dropping when you release, when the enemy leaves range (`rope_range` plus 20 px), when rock blocks the line, or when it dies. **Nothing**: a short flash as today. Swing Thread and Binding Web are not channels: they already hold an enemy at once |
| Effects layer | `Vfx` grows constructors beside `line` and `puffs`: `strand` (a textured `Line2D` with a scroll and width curve), `burst` (a one-shot `CPUParticles2D` with a texture), `stream` (a persistent emitter a channel owns and stops), `flipbook` (a one-shot animated sprite) and `cloud` (the look of a zone: a soft sprite plus a slow particle emitter, replacing `SporeCloudArea`'s `ColorRect`, sized to the zone's radius). All are top-level, in group `vfx`, and free themselves; a channel's emitter is freed by `end_channel()` and the ability's `_exit_tree` |
| The looks | **Web strand**: a tileable silk texture with a slight sag and a knot where it sticks, used for every thread cast and for the rope (`Player.rope_line`, same points and rules). **Web patch**: a radial web sprite. **Water stream**: droplet and foam particles plus a soft additive plume behind the slime. **Water Blade**: a crescent flipbook that sweeps and dissolves along the aim, with a spray at the end. **Jet Dash**: a streak of droplets behind the slime instead of an idle-sprite ghost. **Venom Bolt**: a glowing bolt sprite that travels the line in 0.12 s with a green trail (the hit is still instant). **Miasma, Healing Spores, Puffball, Spore Cloud**: the cloud look, tinted per skill (Puffball also shows the pod's arc as a fast sprite from the caster to the landing point). **Poison Breath**: its existing globs, now with the cloud particles |
| Art | New small textures through the existing Codex `$imagegen` pipeline (`tools/art/generate_frames.py`, `assemble_frames.py`, magenta key): `vfx_water_droplet` (16x16), `vfx_water_foam` (24x24), `vfx_silk_strand` (64x8, tileable), `vfx_silk_mote` (12x12), `vfx_web_patch` (96x96), `vfx_cloud_soft` (96x96 soft puff, tinted in code), `vfx_bolt` (32x16), `vfx_pod` (16x16), and a `vfx_blade` flipbook (4 frames, 128x64). Sprites only under `assets/sprites/`; motion comes from particles |
| Headless vs seen | Tests assert structure and behaviour (an emitter exists and emits while held and stops after, textures are non-null with alpha, the flipbook has N frames, nodes free themselves, no `vfx` nodes leak after a run of casts). What it looks like is checked with real windowed screenshots, as for the terrain |
| Audio | No new audio in this spec: the skill's cue plays on the press. A sustained loop for the stream is a follow-up |

## Where each thing lives

- `scripts/abilities/ability.gd`: the optional channel API. `scripts/player/player.gd`: `_channel`, `_channel_step`,
  `_end_channel(reason)` and the drain accumulator; `use_active` splits into the one-shot path (unchanged) and the channel path.
- `scripts/abilities/hydraulic_propulsion.gd` (the stream), `thread_ability.gd` (the tether, only for the base thread),
  `sticky_thread.gd`, `vfx.gd` (the constructors), and one small script per look where a look has state (`vfx_cloud.gd`).
- `scripts/abilities/spore_cloud_area.gd`: the haze `ColorRect` becomes `Vfx.cloud`. `scripts/player/player.gd`
  `_update_rope_line` and the `rope_line` node: the strand.
- `water_blade.gd`, `jet_dash.gd`, `venom_bolt.gd`, `miasma.gd`, `puffball.gd`, `healing_spores.gd`, `binding_web.gd`,
  `poison_breath.gd`, `swing_thread.gd`: swap the effect call, not the behaviour.
- `tools/art/vfx_frames.json` and the generated `assets/sprites/vfx_*.png`; `tools/vfx_shots.gd` for screenshots.
- `tools/build_content.gd`, `scripts/core/skill_effects.gd`, `scripts/skills/def_validator.gd`: the `channel` data.

## Edge cases

- A press while a cooldown is running does nothing and costs nothing; a channel never starts on cooldown or with too little MP
  for the start cost (the ticker says "Not enough MP" as today).
- Releasing in the same physics frame as the press: `begin_channel()` ran, `channel_tick` never did, `end_channel()` still
  runs, so no emitter leaks.
- The tethered enemy dies or is eaten: the web ends that tick and the strand is freed.
- The slime is hurt while streaming: the stream ends (knockback owns the velocity). A hit does not end the web.
- A channel is running when the room changes or the run ends (death, rebirth): `_end_channel` frees its emitter.
- Two channelling skills in two slots and both buttons held: the later press wins.
- A trigger slot (`active_3`, `active_4`) that chatters around its actuation point: a release shorter than one physics tick
  after the press counts as a tap.
- The base skill evolves while it is channelling: the evolution moment ends the channel first.
- Zone looks in a crowded room: particle counts are capped per emitter and a room has at most a handful of zones (each lasts
  seconds), so the `vfx` group stays small; a test caps it.
- Reduced motion: none exists in the game yet; the looks add no screen shake or flashing above what is there.

## Testing

Ability contract: a one-shot ability is untouched (existing tests); a channel ability's begin, tick and end order; `end_channel`
runs exactly once however the channel stops. Player: press starts, held ticks drain, release ends, empty MP ends, another
slot preempts, hurt, death, room change, skill screen, rope and the evolution moment end it as specified, `SKILL_USED` fires
once, the cooldown starts on end. Drain arithmetic: 2 MP a second over 1.0 s and over 0.4 s from various pools, and the
accumulator across many ticks. Water stream: speed capped at the level's cap along the aim including up, refused on a rope,
horizontal control locked while it runs. Web: terrain first attaches and never channels; an enemy first channels; the
tiers at 0.4 s and 1.2 s (time driven through `channel_tick`); range, rock and death end it; nothing-in-reach flash. Vfx: each
constructor's node structure and self-freeing, textures present with transparency, flipbook frame count, particle caps,
no leaked `vfx` nodes after a run of casts, `SporeCloudArea` still passes its own tests with the new look. Data: the
`channel` block validates and reads. Screenshots: one image per skill in use, looked at before merge.

## Rulings I made

1. **Only the base skills channel.** The evolutions replace them, so a held Water Blade or a channelled Binding Web would be
   a second design question; Sean asked for the base skills ("before it becomes Water Blade"). Cost if wrong: a later
   `channels` flag on an evolved ability.
2. **Terrain still sticks on a tap.** Making the rope channel changes every swing the game teaches; only the enemy tether is
   new. Cost if wrong: one flag.
3. **The stream thrusts along the aim** and its plume trails behind, so it does what the burst did for movement. Cost if
   wrong: the sign of the thrust.
4. **`SKILL_USED` once per start.** Cost if wrong: it levels a little slower than a spammer would.
5. **Textures from the image model, motion from particles.** Cost if wrong: art regenerated, code untouched.
6. **No new audio here.**

## Not here

A held Water Blade, a charged Jet Dash, a held Poison Breath (a Caustic Stream), a Thread Recall teleport, sustained audio
loops, gamepad rumble, a hold indicator on the slot icon (the first thing to add if the channel is hard to read).
