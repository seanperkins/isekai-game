# Channeled Skills and Skill Effects — Design

Status: draft for debate (2026-09-29). Follows `2026-09-29-skill-evolution-branches-design.md`. Answers Sean's note: "The
animations for the web and the water blade just looked like lines. Let's try to make them more interesting. And I think
you should be able to hold down for the Web or the water jet. So maybe before it becomes water blade it's like a water
stream." Sources for the feel: `docs/research/metroidvania-reference.md` § 3 (held and channelled attacks).

## What I understood

Two things, both about how the skills feel to use:

1. **Hold to channel.** Today every active is one press, one instant effect, then a 0.8 s cooldown. Sean wants Sticky Thread
   (the web) and Hydraulic Propulsion (the water jet) to be things you *hold*. The water skill starts life as a stream you
   sustain, and its evolutions grow out of that stream (a Water Blade is the stream sharpened into a cutting edge).
2. **Effects that read as matter, not lines.** The web is a `Line2D` of one width and colour, the blade is a 3 px line for
   0.2 s, the jet and dash are a faded copy of the idle sprite. They should look like silk, water and a cutting edge.

Success: hold the button and the skill runs until you let go or run out of MP; the effect on screen is recognisably a
strand of silk, a jet of water, a crescent of water; the numbers of every other system stay as they are.

## Decisions

| Topic | Decision |
|---|---|
| Channel contract | `Ability` gains an optional lifecycle, off by default, so the seven existing one-shot abilities are untouched. `channels: bool` (a script constant), `begin_channel() -> bool`, `channel_tick(delta: float) -> bool` (false ends it) and `end_channel()`. `activate()` stays for one-shots. The player owns the loop: it starts a channel on the press, feeds it the aim every physics tick, drains MP, and ends it |
| Who is in the loop | `Player._channel` holds the one live channelling ability and its slot index; only one channel at a time. Pressing another slot while channelling ends the first (the second then starts if it can). The channel ends on: release of its slot action, MP short of the next drain, death, predation starting, a stun or hurt-lock, the evolution moment, opening the skill screen, and leaving the room (`Player` already survives room changes, so it is ended on `World.room_changed`) |
| MP | Cost has two parts, both data: `start` (paid on the press, today's `mp_cost`, so a tap costs what it costs now) and `drain` (MP per second while held after the first 0.5 s). `Mana` holds whole points, so the drain accumulates in a float and spends whole points as they fall due. An empty pool ends the channel and leaves it on cooldown |
| Levelling | `SKILL_USED` fires once per channel start, as one press does today, so holding is not a faster way to level. Holding earns nothing extra |
| Cooldown | Starts when the channel ends (0.8 s as today). A tap of a channel skill is a short burst; nothing is lost by tapping |
| Water Stream (Hydraulic Propulsion) | Holding sprays a jet from the slime's back and thrusts the slime along the aim (steady acceleration up to a speed cap that grows with level; the old value table gives the cap). The exhaust is the visible stream. A tap gives about what the old burst gave. Drain 2 MP per second. Enemies in the plume are shoved a little, not damaged |
| Water Blade | Focuses the stream: hold to gather (0.5 s), release to fire one blade whose length and damage scale with the hold (a tap is the old short blade). It is the same channel contract with the release effect in `end_channel()`. Jet Dash and Torrent keep their one-shot form here; a charged Jet Dash is a follow-up |
| Web (Sticky Thread) | On the press the first thing along the aim decides. **Terrain** (nearest): the rope attaches exactly as today, no channel. **An enemy** (nearest): the web channels, holding a strand to it and re-applying `receive_thread` every 0.5 s: tier 1 (slow) after 0.4 s, tier 2 (held) after 1.2 s, and it drops when you release, when the enemy leaves range (the thread's `rope_range` plus 20 px), when rock blocks the line, or when the enemy dies. **Nothing**: a 0.25 s spray of silk that falls short, as the empty cast does now |
| Rope | The plain `rope_line` `Line2D` becomes a textured silk strand: a tileable silk texture, a slight sag toward the middle, and a small knot where it sticks. Its points and rules are unchanged |
| Effects layer | `Vfx` grows four constructors on top of `line` and `puffs`: `strand` (textured `Line2D` with a scroll and a width curve), `burst` (one-shot `CPUParticles2D` with a texture), `stream` (a *persistent* `CPUParticles2D` emitter that a channel owns and stops) and `flipbook` (one-shot animated sprite from a sheet). All are top-level (global coordinates) like today's effects, are in group `vfx`, and free themselves; a channel's emitter is freed by `end_channel()` and by the ability's own `_exit_tree` |
| Art | New small textures, generated through the existing Codex `$imagegen` pipeline (`tools/art/generate_frames.py` + `assemble_frames.py`, magenta key): `vfx_water_droplet` (16×16), `vfx_water_foam` (24×24), `vfx_silk_strand` (64×8, tileable), `vfx_silk_mote` (12×12), `vfx_web_patch` (96×96, radial), and the `vfx_blade` flipbook (4 frames, 128×64, a crescent sweeping and dissolving). The affected abilities use them; nothing else changes |
| Headless vs seen | Tests assert structure (emitter exists, is emitting while held and stops after, textures are non-null with alpha, flipbook has N frames, node freed on end). What it *looks* like is checked with real screenshots from a windowed run, as for the terrain |

## Feel targets (tunable numbers, starting values)

| Skill | Press | Hold | Release |
|---|---|---|---|
| Water Stream | short spurt, about the old burst | thrust 1100 px/s² to the cap, exhaust plume behind, drain 2 MP/s | thrust stops, spray fades in 0.2 s |
| Water Blade | short blade (as now) | gather ring and droplets pulled in for 0.5 s | crescent of 160 px at tap, up to 260 px and 2x damage at full hold |
| Web on enemy | strand shoots out | strand stays tight, silk motes run along it; slow at 0.4 s, held at 1.2 s | strand snaps back |
| Web on rock | strand shoots out and sticks | (no channel) | (as today) |

## Where each thing lives

- `scripts/abilities/ability.gd`: the optional channel API.
- `scripts/player/player.gd`: `use_active(i)` splits into a one-shot path (unchanged) and a channel path; a new
  `_channel_step(delta)` in `_physics_process`; `_end_channel(reason)`. `SlimeState` and the sprite stay as they are; a
  channelling slime uses the existing cast pose.
- `scripts/abilities/hydraulic_propulsion.gd` (Water Stream), `water_blade.gd`, `thread_ability.gd` (Web tether),
  `vfx.gd` (the four constructors).
- `scripts/player/player.gd` `_update_rope_line` and the `rope_line` node: the silk strand.
- `tools/art/vfx_frames.json` and the generated `assets/sprites/vfx_*.png` sheets; `tools/vfx_shots.gd` for screenshots.
- `data/skills` (via `tools/build_content.gd`): each channel skill's `channel` block (`start`, `drain`, `gather`).

## Edge cases

- A press while a cooldown is running does nothing and costs nothing, as now; a channel never starts on cooldown.
- Releasing in the same frame as the press: `begin_channel()` ran, `channel_tick` never did; `end_channel()` still runs, so no
  emitter leaks.
- The enemy dies or is eaten while tethered: the web ends that tick and the strand is freed.
- The slime is hurt while channelling: the water stream ends (knockback owns the velocity); the web survives a hit.
- A channel is running when the room changes or the run ends (death, rebirth): `_end_channel("room")` frees its emitter.
- Two skills that channel are in two slots and both buttons are held: the later press wins, the earlier is ended.
- A gamepad trigger slot (`active_3`/`active_4` are triggers): `Input.is_action_pressed` is the held test for keys and
  triggers alike; a trigger that hovers around the actuation point may chatter, so a release shorter than one physics tick
  after the press is treated as a tap.
- The Water Stream thrust and the rope's own velocity rules both write `velocity`: the stream is refused while a rope is
  attached (the rope wins), so the two never fight.

## Testing

Ability contract: a one-shot ability is untouched (existing tests), a channel ability's begin/tick/end order, `end_channel`
always runs once. Player: press starts, held ticks drain, release ends, empty MP ends, another slot preempts, hurt/death/
room-change/skill-screen end it, `SKILL_USED` fires once, cooldown starts on end. Drain arithmetic: 2 MP/s over 1.0 s and
over 0.4 s from various starting pools, and the whole-point accumulator across many ticks. Water Stream: speed capped at the
level's cap, thrust along the aim including up, refused on a rope. Water Blade: length and damage at tap, at half and at full
hold, release effect exactly once. Web: terrain first attaches and never channels; an enemy first channels; tiers at 0.4 s
and 1.2 s (time faked through `channel_tick`); range, rock and death end it; nothing-in-reach spray. Vfx: each constructor's
node structure and self-freeing, textures present with transparency, flipbook frame count, no leaked `vfx` nodes after a run
of casts. Screenshots: one image per skill in use, looked at before merge.

## Rulings I made

1. **Terrain still sticks on a tap.** Making the rope channel too (hold to keep it) changes the feel of every swing the
   game already teaches; only the enemy tether is new. Cost if wrong: a later "hold to keep the rope" is one flag.
2. **The water skill thrusts along the aim** and its exhaust trails behind, so the stream matches what the old burst did
   for movement. Cost if wrong: the direction of thrust is one sign.
3. **`SKILL_USED` once per start**, not per second held. Cost if wrong: a skill levels a little slower than a spammer would.
4. **Textures from the image model, motion from particles.** A drawn crescent sheet and a few droplet sprites give the
   look; the stream and the strand animate procedurally. Cost if wrong: art regenerated, code untouched.
5. **No new audio in this spec.** The skill's existing cue plays on the press. A sustained loop is a follow-up.

## Not here

Charged Jet Dash, held Poison Breath (a Caustic Stream), a Thread Recall teleport, sustained audio loops, gamepad
rumble, a hold indicator on the slot icon (a small glow is the first thing to add if the channel is hard to read).
