# Polished Sound — Design

Status: draft for review (2026-09-28). Builds on `2026-09-28-terrain-art-design.md` (biomes,
`area`) and `2026-09-28-slime-forms-and-animation-design.md` (slime states). The game has no
audio today: no buses, no streams, no audio files.

## Goal

Give the game a polished, cohesive soundscape: a sound for every player and enemy action, a
music loop and an ambience bed per biome, and a mix that suits the bright, luminous tone of the
Cave, Grotto and Flooded Tunnels. Sound is tuned from data and asset files, without editing
gameplay code.

## Decisions

| Topic | Decision |
|---|---|
| Asset source | Hybrid. SFX are synthesized procedurally in-repo. Music and ambience beds are AI-generated |
| AI provider | Not fixed. `gen_bed.py` has a provider adapter (prompt file in, looped `.ogg` out). The provider is chosen at implementation, and the key comes from Sean |
| Music model | One looping music track per biome, crossfaded on room entry, plus a separate ambience bed. No adaptive stems |
| Runtime | One `Audio` autoload with a data-driven cue catalog (`data/audio/cues.json`) |
| Triggers | Gameplay emits **semantic events** and never names a cue. `Audio` is the only translator from event to cue, through the catalog. Sources: `EventBus.game_event`, a new `EventBus.world_event`, the `SkillRules` signals, and room entry |
| Pipeline rule | Individual assets, one at a time, assembled and validated by a tool (Sean's standing rule). Built `.ogg` files are committed. Raw provider output is gitignored |
| Out of scope | Adaptive or layered music, voice acting, per-surface footsteps, a dynamic score |

## Runtime architecture

| Unit | Path | Purpose | Depends on |
|---|---|---|---|
| `Audio` | `autoload/audio.gd` | Listens to the event sources (see Triggers) and turns each event into a cue. Also `set_biome(area)`. `process_mode` is always, so tweens and ducking run while the tree is paused. Registered after `Announcer` | catalog, pool, director, `EventBus`, `SkillRules` |
| `CueCatalog` | `scripts/audio/cue_catalog.gd` | Loads and validates `data/audio/cues.json`; resolves an event to a cue, and a cue to a stream variant; holds the biome table | `res://assets/audio/` |
| `VoicePool` | `scripts/audio/voice_pool.gd` | Fixed pool of players (16). Per-cue cooldown. When full, steals the quietest voice | catalog |
| `MusicDirector` | `scripts/audio/music_director.gd` | Music and ambience players. Crossfades both on biome change. Owns the music duck | buses |
| `AudioSettings` | `scripts/audio/audio_settings.gd` | Master, Music, Ambience and SFX volumes, saved in the `Profile` under an `audio` section | `Profile` |

### Cue catalog format

`data/audio/cues.json` has three sections: `cues` (playback rules), `events` (which event plays which cue) and `biomes` (music, ambience, reverb).

`cues` maps a cue id to its playback rules:

```json
{ "slime_land_soft": { "files": ["sfx/slime_land_soft_1.ogg", "sfx/slime_land_soft_2.ogg"],
                       "bus": "SFX_Player", "volume_db": -6, "pitch_jitter": 0.08,
                       "cooldown": 0.06, "positional": false } }
```

- `files`: one to four variants, picked at random and never the same twice in a row.
- `positional`: true plays through an `AudioStreamPlayer2D` at `pos`. Otherwise a plain player.
- Cues that have no file are a validation error, not a silent skip.

`events` maps a semantic event name to a cue, or to a tag-selected cue:

```json
"events": { "landed": { "by": "hard", "true": "slime_land_hard", "false": "slime_land_soft" },
            "jumped": "slime_jump",
            "skill_used": { "by": "id", "sticky_thread": "skill_sticky_thread", "default": "skill_generic" },
            "mana_spent": null }
```

A `null` entry is an intentionally silent event and must carry a `"_why"` comment key beside
it in the file (for example `mana_spent` is one event per MP point and would machine-gun).

`biomes` maps `cave`, `grotto`, `flooded` and `deep` to their beds and one-shots:

```json
"biomes": { "cave": { "music": "music/cave.ogg", "ambience": "ambience/cave.ogg",
                      "reverb_wet": 0.15,
                      "oneshots": { "cues": ["amb_drip", "amb_crystal_ping"], "interval": [4.0, 12.0], "radius": 220 } } }
```

`radius` is the distance in pixels from the player at which a one-shot can appear. The catalog
validates that every biome file and one-shot cue exists.

### Buses

`default_bus_layout.tres` is committed:

```
Master
├─ Music
├─ Ambience
├─ SFX_Player
├─ SFX_Enemy
├─ SFX_World      (reverb, wetness set per biome)
└─ UI
```

- The `SFX_World` reverb wetness follows the biome (`reverb_wet` in the `biomes` catalog section):
  Cave large and dry, Grotto medium, Flooded wet, `deep` sparse.
- The Music bus ducks −4 dB (0.15 s attack, 0.6 s release) while a stinger plays or the skill
  screen is open. The screen's `open()` and `close()` emit `menu_opened` and `menu_closed` world
  events; `Audio` is `PROCESS_MODE_ALWAYS`, so the duck tween runs while `get_tree().paused` is true.
- A limiter on Master stops summed cues from clipping.

### Triggers

One rule: **gameplay code says what happened, `Audio` decides what it sounds like.** Gameplay
never contains a cue id, a bus name or a file path, so audio can be removed or reworked without
touching gameplay.

| Source | Carries | Notes |
|---|---|---|
| `EventBus.game_event(name, tags)` | The existing player events in `Events.ALL`, except the two in `Events.INTERNAL` (`skill_unlocked`, `skill_leveled`), which are queued inside `SkillRules` and never emitted here | Unchanged. Counted by `SkillRules` and `Compendium` |
| `EventBus.world_event(name, tags)` | **New.** Non-counted semantic events: `landed`, `enemy_hit`, `enemy_died`, `tablet_inspected`, `switch_pulled`, `water_entered`, `water_exited`, `pool_rested`, `menu_opened`, `menu_closed`, `ticker_shown`, `denied` and so on | Nothing but `Audio` listens. It exists because `SkillRules` warns on unknown `game_event` names and counts every one of them, so audio-only events must not go there |
| `SkillRules` signals | `skill_unlocked`, `skill_leveled`, `evolution_ready` | These are the only source for the two `Events.INTERNAL` names, plus `evolution_ready`. They never reach `EventBus`. `Audio` connects to the autoload directly and maps them through the same `events` catalog section |
| `Game._on_room_entered(id)` | Room entry | Calls `Audio.set_biome(area)`, the same biome key that `TerrainArt.AMBIENT` uses |

Gameplay scripts emit a `world_event` at the moment something happens, with the tags a
mapping might need (for example `landed` with `{"hard": true, "speed": 480.0}`). All
event-to-cue routing lives in the `events` section of `cues.json`. There is no second route
and no `Audio.play` call in gameplay code.

Looped or continuous sounds (squish-run, wall-slide, heartbeat) use paired events
(`run_started` / `run_stopped`), and the catalog marks such a cue `"loop": true`.

## Cue coverage (first pass)

| Group | Cues |
|---|---|
| Slime | jump, land soft, land hard (fall speed), squish-run (looped by step), crouch-spread, wall-cling, wall-slide, hurt, low-HP heartbeat, death, level-up, evolve |
| Eating | cover, absorb (pitch rises with essence total), predated |
| Skills | one cue per ability: sticky thread, swing thread, poison spit, poison breath, water blade, jet dash, hydraulic propulsion, tail swipe, constrict, leap, and the skill unlock and level-up stingers |
| Enemies | hit, stun, death (four death cues: flyer, crawler, beast, boss, chosen by creature id in the catalog) |
| World | tablet read, shortcut switch, glow-pool rest, water enter and exit (catalogued; emitted once a swim mechanic exists), ambience one-shots (drip, crystal ping, hum, bubble, spore) |
| UI | pop-up ticker, skill screen open and close, not-enough-MP denial, menu move and confirm |

Every name in `Events.ALL`, every `world_event` name and the three `SkillRules` signals has an
entry in `events`: a cue, or an explicit `null` with a `_why`.

## Music and ambience

- `Audio.set_biome(area)` starts a 2 s equal-power crossfade of the music and ambience together.
  Setting the biome that is already playing does nothing.
- Loops are seamless: the tool finds a loop point and crossfades the seam before export.
- Ambience one-shots (drips, crystal pings, distant hum) come from the biome's `oneshots` entry
  in the catalog: a random cue from `cues` on a random `interval` seconds timer, placed at a
  random offset up to `radius` px from the player.
- `deep` is reserved: it gets a dark, sparse bed, but no room uses it yet.
- Biomes: `cave`, `grotto`, `flooded`, `deep`.

## Asset pipeline

```
art_source/audio/recipes/*.json   ──synth_sfx.py──▶  assets/audio/sfx/*.ogg
art_source/audio/beds/<biome>.json ─gen_bed.py─▶  art_source/audio/raw/   (gitignored)
                                            └─▶  assets/audio/music|ambience/<biome>.ogg
```

- **`tools/audio/synth_sfx.py`.** Recipes describe oscillators, noise, an envelope, filters and
  pitch sweeps. Each recipe renders 2–4 variants from fixed seeds, so output is reproducible.
  Encodes to Ogg Vorbis with ffmpeg.
- **`tools/audio/gen_bed.py`.** Reads a prompt file per biome, calls the provider adapter, then
  trims silence, finds the loop point, crossfades the seam, normalizes and writes the `.ogg`.
  The prompts follow the art tone: bright, warm, crystalline, lively, never dread.
- **`tools/audio/build_cues.py`.** Regenerates `data/audio/cues.json` entries from the files in
  `assets/audio/sfx/` for recipes that do not override the defaults, so a new recipe becomes a
  cue with sensible defaults.
- **Failure behavior.** Every tool exits non-zero if ffmpeg, a recipe or the provider call
  fails. Each writes to a temp file, validates it (`ffprobe` reads it as Ogg Vorbis, duration
  above zero, no clipping), and only then renames it into `assets/audio/`. A failed run never
  leaves a partial file. `build_cues.py` refuses to add a cue for an invalid file and exits
  non-zero.
- **Loudness targets:** SFX are peak-normalised to −2 dBFS and balanced by each cue's `volume_db`
  (LUFS is not meaningful for clips under half a second, and transient sounds cannot reach −16 LUFS
  under the peak ceiling). Music is about −20 LUFS and ambience about −24 LUFS. Nothing peaks
  above −1 dBTP, measured as sample peak after encoding.
- **Encoding:** Ogg Vorbis, stereo, through ffmpeg's native `vorbis` encoder (`-strict -2`), which
  accepts two channels only. Mono sources are duplicated to stereo.
- **Loop edges:** every bed fades to silence over its first and last 10 ms. Vorbis zero-pads the
  end of a stream, so a bed that ended mid-wave decoded with a jump from its tail back to its head.
- **Placeholder beds:** until a provider is chosen, `gen_bed.py` renders each bed itself with a
  built-in synth provider. A `local` provider decodes a file dropped in `art_source/audio/raw/`,
  and the ElevenLabs provider replaces the placeholders when Sean supplies a key.
- **Gitignore:** add `art_source/audio/raw/` with a comment like the terrain entry. Built
  `.ogg` files and recipes are committed.

## Settings and persistence

- There is no options screen yet. The Great Sage menu (`scripts/ui/skill_screen.gd`, Q/E or LB/RB
  switch tabs) gets a **Sound** tab with four sliders: Master, Music, Ambience, SFX (0–100, default 80).
  Left/right or the d-pad adjusts the selected slider.
- The existing four tabs sit at `x = 28 + i * 128`, width 120 (`skill_screen.gd:216`), so a fifth
  would end at x=660 on a 640 px canvas. All five tabs are re-laid out at `x = 28 + i * 102`,
  width 96, ending at x=532. A test checks that the last tab's right edge is under 612 and that
  each label fits its tab width.
- Values are stored as linear 0–1 in the `Profile` under `audio` and applied as `linear_to_db`
  on the buses at startup.
- A missing or malformed `audio` section resets to defaults, as other sections do.

## Testing

Headless tests in `tests/` (run with `tools/run_tests.sh`):

1. **Catalog:** every cue has at least one file that exists; buses exist; volume and pitch
   ranges are sane; no file in `assets/audio/` is referenced by no cue.
2. **Events:** every name in `Events.ALL`, every `world_event` name emitted in `scripts/` and the
   `SkillRules` signals has an `events` entry; every `events` entry points to an existing cue;
   every silent entry has a `_why`. A grep-based test fails if a gameplay script contains a cue id
   or calls `Audio.play`.
3. **Voice pool:** the cap holds, a cooldown drops the second play, and a full pool steals the
   quietest voice.
4. **Variants:** the same variant never plays twice in a row when a cue has two or more.
5. **Loop seams** (Python, `tools/audio/test_assets.py`): the jump from a file's last sample to its
   first is under 3× the loudest normal sample-to-sample step, for every bed and every looping cue.
6. **Loudness** (Python, same file): music and ambience are within ±2 LU of their targets, and no
   file peaks above −1 dBFS. These are Python because they need PCM samples, which headless Godot
   cannot provide; run them with `python3 -m unittest discover -s tools/audio -p "test_*.py"`.
7. **Settings:** slider values round-trip through `Profile`, and a malformed section resets.
8. **Biome switch:** `set_biome` for an unknown area warns and keeps the current bed.
9. **Pause:** with the tree paused, a `menu_opened` event still ducks the Music bus.
10. **Tool failure:** a recipe that fails to encode leaves no file in `assets/audio/` and
    `build_cues.py` exits non-zero.

Headless Godot cannot judge how it sounds. `tools/audio/preview.tscn` lists every cue and
biome with a play button so Sean can audition them, and a checklist item in
`docs/playtest-checklist.md` covers the by-ear pass.

## Ownership

New paths: `autoload/audio.gd`, `scripts/audio/`, `data/audio/`, `assets/audio/`,
`art_source/audio/` (recipes, beds and gitignored raw output), `tools/audio/` (tools and their
Python tests, `test_*.py`), `default_bus_layout.tres`, `tests/test_audio_*.gd`.

Edits to existing files:
- `project.godot`: the autoload and the bus layout.
- `autoload/event_bus.gd`: the `world_event` signal.
- `scripts/game.gd`: `set_biome` on room entry.
- One `EventBus.world_event.emit` line in each gameplay script that owns a non-`game_event`
  moment: player, enemy, water pool, tablet, switch, glow pool, HUD and skill screen.
- `scripts/persistence/profile.gd`: an `audio` section.
- `scripts/ui/skill_screen.gd`: the Sound tab, the five-tab layout and the open/close events.
