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
| Triggers | `Audio` listens to `EventBus.game_event` and room entry. Everything else calls `Audio.play` from the owning script |
| Pipeline rule | Individual assets, one at a time, assembled and validated by a tool (Sean's standing rule). Built `.ogg` files are committed. Raw provider output is gitignored |
| Out of scope | Adaptive or layered music, voice acting, per-surface footsteps, a dynamic score |

## Runtime architecture

| Unit | Path | Purpose | Depends on |
|---|---|---|---|
| `Audio` | `autoload/audio.gd` | API: `play(cue, pos := Vector2.INF)`, `set_biome(area)`, `stinger(cue)`. Registered after `Announcer` | catalog, pool, director, `EventBus` |
| `CueCatalog` | `scripts/audio/cue_catalog.gd` | Loads and validates `data/audio/cues.json`; resolves a cue to a stream variant | `res://assets/audio/` |
| `VoicePool` | `scripts/audio/voice_pool.gd` | Fixed pool of players (16). Per-cue cooldown. When full, steals the quietest voice | catalog |
| `MusicDirector` | `scripts/audio/music_director.gd` | Music and ambience players. Crossfades both on biome change. Owns the music duck | buses |
| `AudioSettings` | `scripts/audio/audio_settings.gd` | Master, Music, Ambience and SFX volumes, saved in the `Profile` under an `audio` section | `Profile` |

### Cue catalog format

`data/audio/cues.json` maps a cue id to its playback rules:

```json
{ "slime_land_soft": { "files": ["sfx/slime_land_soft_1.ogg", "sfx/slime_land_soft_2.ogg"],
                       "bus": "SFX_Player", "volume_db": -6, "pitch_jitter": 0.08,
                       "cooldown": 0.06, "positional": false } }
```

- `files`: one to four variants, picked at random and never the same twice in a row.
- `positional`: true plays through an `AudioStreamPlayer2D` at `pos`. Otherwise a plain player.
- Cues that have no file are a validation error, not a silent skip.

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

- The `SFX_World` reverb wetness follows the biome: Cave large and dry, Grotto medium, Flooded
  wet, `deep` sparse. Values live in a table in `music_director.gd` next to the biome id.
- The Music bus ducks −4 dB (0.15 s attack, 0.6 s release) while a stinger plays or the skill
  screen is open.
- A limiter on Master stops summed cues from clipping.

### Triggers

- `EventBus.game_event(name, tags)` → cue through a small `EVENT_CUES` map inside `audio.gd`.
  `tags` can select a variant (for example `skill_used` with `skill_id`).
- `Game._on_room_entered(id)` → `Audio.set_biome(area)`. The same biome key that
  `TerrainArt.AMBIENT` uses.
- Everything else (landing, running, enemy hits and deaths, water, tablets, switches, UI) is
  one `Audio.play` call in the script that owns it. Gameplay scripts never touch buses,
  streams or files.

## Cue coverage (first pass)

| Group | Cues |
|---|---|
| Slime | jump, land soft, land hard (fall speed), squish-run (looped by step), crouch-spread, wall-cling, wall-slide, hurt, low-HP heartbeat, death, level-up, evolve |
| Eating | cover, absorb (pitch rises with essence total), predated |
| Skills | one cue per ability: sticky thread, swing thread, poison spit, poison breath, water blade, jet dash, hydraulic propulsion, tail swipe, constrict, leap, and the skill unlock and level-up stingers |
| Enemies | hit, stun, death (one per creature family, not per creature) |
| World | tablet inspect, shortcut switch, glow-pool rest, water enter, water exit, crystal chime |
| UI | pop-up ticker, skill screen open and close, not-enough-MP denial, menu move and confirm |

Every name in `Events.ALL` maps to a cue or is listed in `SILENT_EVENTS`, with a comment
saying why (for example `mana_spent` is one event per MP point and would machine-gun).

## Music and ambience

- `Audio.set_biome(area)` starts a 2 s equal-power crossfade of the music and ambience together.
  Setting the biome that is already playing does nothing.
- Loops are seamless: the tool finds a loop point and crossfades the seam before export.
- Ambience one-shots (drips, crystal pings, distant hum) fire on a random 4–12 s timer at a
  random offset near the player, per biome list in the catalog.
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
- **Loudness targets:** SFX about −16 LUFS, music about −20, ambience about −24. True peak
  under −1 dBTP.
- **Gitignore:** add `art_source/audio/raw/` with a comment like the terrain entry. Built
  `.ogg` files and recipes are committed.

## Settings and persistence

- There is no options screen yet. The Great Sage menu (`scripts/ui/skill_screen.gd`, Q/E or LB/RB
  switch tabs) gets a **Sound** tab with four sliders: Master, Music, Ambience, SFX (0–100, default 80).
  Left/right or the d-pad adjusts the selected slider.
- Values are stored as linear 0–1 in the `Profile` under `audio` and applied as `linear_to_db`
  on the buses at startup.
- A missing or malformed `audio` section resets to defaults, as other sections do.

## Testing

Headless tests in `tests/` (run with `tools/run_tests.sh`):

1. **Catalog:** every cue has at least one file that exists; buses exist; volume and pitch
   ranges are sane; no file in `assets/audio/` is referenced by no cue.
2. **Events:** every name in `Events.ALL` is in `EVENT_CUES` or `SILENT_EVENTS`.
3. **Voice pool:** the cap holds, a cooldown drops the second play, and a full pool steals the
   quietest voice.
4. **Variants:** the same variant never plays twice in a row when a cue has two or more.
5. **Loop seams:** the difference between the last and first sample window of each loop is
   under a set multiple of the file's normal sample-to-sample difference (the same approach as
   the parallax seam test).
6. **Loudness:** measured loudness of each built file is within ±2 LU of its bus target.
7. **Settings:** slider values round-trip through `Profile`, and a malformed section resets.
8. **Biome switch:** `set_biome` for an unknown area warns and keeps the current bed.

Headless Godot cannot judge how it sounds. `tools/audio/preview.tscn` lists every cue and
biome with a play button so Sean can audition them, and a checklist item in
`docs/playtest-checklist.md` covers the by-ear pass.

## Ownership

New paths: `autoload/audio.gd`, `scripts/audio/`, `data/audio/`, `assets/audio/`,
`art_source/audio/`, `tools/audio/`, `default_bus_layout.tres`, `tests/test_audio_*.gd`.

One-line edits to existing files: `project.godot` (autoload and bus layout), `scripts/game.gd`
(`set_biome` on room entry), and one `Audio.play` call in each gameplay script that owns a
non-event cue (player, enemy, water pool, tablet, switch, glow pool, HUD and skill screen). The
`Profile` gains an `audio` section, and the skill screen gains the Sound tab.
