# Opening battle: music and sounds (ledger)

Built on `feat/opening-sound` after Sean asked: "Make the battle music and other sounds. Update the docs. The two trucks are fine." Bounded change inside the existing audio system (`docs/superpowers/specs/2026-09-28-polished-sound-design.md`): no plan file; this is the record.

## Built

- **Battle music.** A 32-bar, 172 bpm, A-minor chiptune battle theme (about 45 s, a bar-exact loop): square-wave lead, pulse arpeggio, triangle bass, drums, a saw pad in the B and last sections. It is data, `art_source/audio/scores/opening_battle.json` (melody as note strings, chords, drum patterns), rendered by the new `tools/audio/score.py` and built by `tools/audio/gen_bed.py opening_battle` into `assets/audio/music/opening_battle.ogg`.
- **Themes.** A new `themes` section in `data/audio/cues.json`: a theme takes the music over from the room's bed. Events `{"theme": id}` and `{"theme_stop": id}` start and end it; `MusicDirector` holds the biome beds silent under it (equal power, both ways), a room change meanwhile waits, `Audio.reset()` ends it at once, and stopping part-way through a fade does not jump.
- **19 sound effects**, synthesized in-repo from `art_source/audio/recipes/opening.json` (28 files): `op_turn`, `op_arrive`, `op_arrive_horn`, `op_steps`, `op_swing`, `op_bonk`, `op_dodge`, `op_jump`, `op_pray`, `op_run`, `op_dash`, `op_shove`, `op_safe`, `op_charge`, `op_rage`, `op_crash`, `op_pass`, `op_ko_fall`, `op_whiteout`. All on the UI bus, so they sound while the tree is paused.
- **Events.** `OpeningScene` says what happens and never names a sound: `opening_started`, `opening_turn`, `opening_truck_arrive` (index 0 or 1), `opening_grandma_arrive`, `opening_action` (the command id), `opening_umbrella_hit`, `opening_shove`, `opening_grandma_safe`, `opening_charge` (rage or not), `opening_pass`, `opening_hit`, `opening_ko`, `opening_ended`, `opening_whiteout`, plus the existing `menu_move`, `menu_confirm` and `denied` (the cursor ticks when it moves; in the old lady's round trying to leave her row is denied). The `events` section maps them. The stand-in `opening_impact` (it borrowed the enemy hit) is gone: `opening_hit` plays `op_crash`.
- **Tool fixes.** `build_cues.py` used to rebuild `cues` from recipes only, which would have deleted every hand-added cue (the boss stand-ins, the old `opening_impact`). It now keeps any cue no recipe makes while its files exist, and keeps `themes`. `gen_bed.py` has a `score` provider that skips the trim and crossfade a recorded bed gets (it is already a bar-exact loop).
- **Verified end to end** in the real game with Godot's movie maker: the whole opening recorded with its audio, every event mapped to its cue in order, the theme running from the first frame to the knock-out, and after it the theme gone and the Cave music back (`bed_gain` 1).

## Rulings

- Ruling: the music is composed in-repo, not generated. The ElevenLabs music API (the project's provider for beds) returned 402 "paid plan required" for both requests (this key is on the free tier; the ambience beds use its sound-generation API, which works), so I did not retry. Cost if wrong: swap the bed spec's provider to `elevenlabs` once there is a paid plan (the prompt is in the spec); the theme wiring does not change.
- Ruling: "other sounds" means every moment of the opening battle, not her menu or the rest of the game. Cost if wrong: add cues and events the same way.
- Ruling: sound effects are synthesized from recipes (the project's standing rule: SFX are procedural, music and ambience are AI), tuned by measured level against the existing cues since nobody can listen in a test. Cost if wrong: edit `volume_db` or layers in `opening.json`.
- Ruling: the music ends at the knock-out (it fades out over 1.8 s as the white comes in) and the Cave music returns over her menu; no separate theme for her. Cost if wrong: one more theme and two events.
- Ruling: the truck's turn has no chime (its engine says whose turn it is); only yours does. Cost if wrong: one line in `events`.
- Ruling: the theme loudness is the project's music target (-23 LUFS), not louder. Cost if wrong: a `volume_db` on the theme.

## Not verified

Nobody on this side can hear audio. The score is checked by rule (every lead note is in A minor or the leading tone, every note on the beat is a chord tone, 32 bars, 16 steps each, drum patterns well formed), the loop by measurement (no seam click, -23 LUFS, no peak over -1 dBFS), the effects by level against their neighbours, and the wiring by the recording. Whether it sounds good is Sean's ear: the playtest checklist's Sound section lists what to listen for, and `art_source/audio/scores/opening_battle.json` and `art_source/audio/recipes/opening.json` are where to change it.

## Rebuilding

- Music: `TMPDIR="$PWD/.tmp/audio-work" python3 tools/audio/gen_bed.py opening_battle`
- Effects: `TMPDIR="$PWD/.tmp/audio-work" python3 tools/audio/synth_sfx.py op_crash ...` (name the cues; building all rewrites every Ogg), then `python3 tools/audio/build_cues.py`
- Checks: `python3 -m unittest discover -s tools/audio -p "test_*.py"` and `tools/run_tests.sh audio`
- A paid-plan alternative for the music (ElevenLabs, `{"provider": "elevenlabs", "seconds": 45}` in the bed spec). Two prompts to try: the one in the spec, and: "A frantic, comedic chiptune and orchestra hybrid battle theme at about 170 BPM: bouncy staccato bassoon and pizzicato strings, a snappy snare, a quirky xylophone and square-wave lead, and mock-epic brass stabs. Panicky but cheerful, like a silly JRPG random encounter against a delivery truck. Instrumental, no vocals, a tight groove that loops cleanly."

## Follow-ups

- Sean's ear on the theme and effects (tempo, instruments, levels).
- Her menu has no sound of its own and is still dark navy after the white fade.
- The truck's engine is not looped under its turn; each effect is a one-shot.
