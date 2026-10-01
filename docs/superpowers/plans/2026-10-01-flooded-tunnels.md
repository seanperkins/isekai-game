# The Flooded Tunnels Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the third area: deep water and swimming, shock and Jolt, four new creatures (and a rare slice), five rooms (and one more in the slice), the second real rebirth kit, and water in the room editor.

**Architecture:** Water is data (`RoomDef.water`, drawn by `DeepWater` nodes that the builder adds); the player's water model is one deep collaborator (`PlayerWater`) with three call sites in `player.gd`; creatures reuse the existing Kinds (eels are SWOOPERs, the jelly a DRIFTER, the lizardman a SPITTER with a `Spear`); the rooms are authored by a one-shot script through `RoomEditModel`'s API and saved as `.tres`; the first evolution's affinity is scoped to the Cave and Grotto.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1 (`tools/run_tests.sh [substr]`), Python art tools run with `uv` (Codex image generation).

**Spec:** `docs/superpowers/specs/2026-10-01-flooded-tunnels-design.md` (approved after three debate rounds and a verification pass). Read it with this plan: the plan implements it task by task.

## Global Constraints

Copied from the spec; every task's requirements include them.

- Godot 4.7 / GDScript / GUT 9.7.1. Every new `class_name` script needs `env HOME="$PWD/.tmp/gdhome" godot --headless --import` and its `.uid` file committed. A SCRIPT ERROR or Parse Error fails the run. Mouse and window tests are 64×64 under GUT.
- Water: `RoomDef.water` rects (local px), each ≥ 32×32, inside the room, never overlapping or touching another in the room.
- In water the player is "in water" while the centre of its body is inside a rect. Without Swim: horizontal ×0.6, gravity ×0.35 (`WATER_GRAVITY`), sink cap 60 px/s, a Jump is a bob `−160 · sqrt(jump_height / 100)` (`BOB_VELOCITY` 160) **only from the floor or a ledge** (no wall bob, no mid-water jump). On the in-water **entry edge** without Swim, upward speed is capped at the bob (`velocity.y = maxf(velocity.y, −BOB_VELOCITY · boost)`). With Swim: no gravity, 8-way at 120 / 150 / 180 px/s (`swim_speed` stat, base 120, modifier values `[0, 30, 60]`), steering from `move_left`, `move_right`, `aim_up`, `aim_down`; Jump with the centre within `SURFACE_REACH` (24 px) of the rect's top edge launches at the normal jump velocity, swim input ignored until the centre leaves the rect.
- `submerged` once per second in water (player only); Swim: unlock `submerged` ×20, `level_curve` 40, max level 3. The audio-only events are the existing `water_entered` / `water_exited`.
- Shock: `Damage.hit` already skips armor for non-physical types. A shock hit sets `_dash = maxf(_dash, SHOCK_STUN)` (0.3) in `Player.receive_hit` after the invulnerability guard **and after the knockback block**. Jolt: 5 MP, radius 40, damage 3/4/5/6/7, `status.stun(1.5)` on `swimmer` creatures; Jolt unlock absorb `shock` ×4, used ×8 per level, max 5. `EnemyStatus.stun` keeps the longer timer on an already stunned creature.
- Creatures (base numbers; the generator scales HP/ATK/DEF with `_at_level(FLOODED_LEVEL)`, `FLOODED_LEVEL = 7`, as the Grotto's are scaled at 4): Glass Eel 4/2/0/140 shock 1 water 1 XP 3; Cave Crayfish 9/3/3/60 shell 1 water 1 XP 5; Drift Jelly 3/2/0/30 shock 1 water 2 XP 3; Bog Lizardman 7/3/1/80 earth 1 water 1 XP 5; Storm Eel (slice) 10/4/1/160 shock 3 water 2 XP 10. First-time value is `2 × xp`.
- `CreatureDef` flags: `swimmer`, `untackleable`, `contact_type` (default `"physical"`), `projectile` (default `""`), `puffs` (the two moths). No `shock_stun`, no `Player.shock`.
- Spear: `SPEAR_RANGE` 140, `SPEAR_LEVEL` 40, `SPEAR_COOLDOWN` 3.0, `SPEAR_SPEED` 220; the pose window is `_spit_cd > cooldown − SPIT_POSE_SECONDS`.
- Lint: `water_rect`, `swimmer_dry`, `water_exit` (rules 13 → 16); `SURFACE_LIFT = ⌊JUMP_VELOCITY² / (2·GRAVITY) − BodyConfig.BOTTOM − 4⌋ = 44`; a shore is within 24 px horizontally of the rect with its top between `SURFACE_LIFT` above and `BodyConfig.BOTTOM` below the rect's top edge; an exit span counts only when open (no `shortcut`, no gate but `swim`). `WorldValidator.GATES` gains `swim`.
- Gate test bound: `B_entry = (JUMP_VELOCITY² − BOB_VELOCITY²) · jh_max / (2 · GRAVITY · 100) + B`, `B = BOB_VELOCITY² · jh_max / (2 · GRAVITY · WATER_GRAVITY · 100)`, `jh_max` 185 → `B` 75.2, `B_entry` 160.8; sill ≥ `B_entry + 3`.
- `FormOffers.FIRST_EVOLUTION_AREAS := ["cave", "grotto"]`; `supply` takes an optional `areas` filter.
- Rooms (cells, sizes): F1 Seep Mouth (10,8) 2×1; F2 Sump (12,7) 1×2; F3 Eel Run (12,6) 3×1; F4 Marsh Hall (15,6) 2×1; F5 Quiet Pool (15,7) 1×1; slice F6 Storm Pocket (15,5) 1×1. Pacing: the first-time sum over F1–F5 is in [150, 403), guide 188.
- Process: TDD with a failing run first; no attribution lines in commit messages; report only commit SHAs copied from git output; relative paths with a `./` prefix when giving paths to the user; scratch under `.tmp/`.

## Review Focus

The input classes the plan's task tests would not exercise unless asked. Each has a test in the task that owns the code.

1. **A dry jump, knockback or Hydraulic Propulsion carried into water by a non-swimmer.** Expect: the entry cap holds a jump to the bob and knockback is under it; Hydraulic Propulsion fired mid-water is not capped (Task 9).
2. **A room file saved before water existed, and water that touches an edge, an exit or another rect.** Expect: an old `.tres` loads with `water == []`; a save/load round trip keeps water; lint reports touching rects (Tasks 5 and 6).
3. **A swimmer spawned on a rect edge, outside its rect or in a rect barely bigger than its body, and a stunned eel.** Expect: it is clamped inside, an unhomed swimmer idles without error, and a stunned eel sinks to the rect bottom and stays there (Task 10).
4. **The player dying, changing room or evolving while in water.** Expect: `PlayerWater` resets on a new life, no `ballistic` flag outlives the rect, and a room change fires no exit-and-enter pair (Tasks 8 and 9).
5. **A contact that runs every frame during invulnerability, and a jelly that can only be eaten when downed.** Expect: the shock lock is applied once per accepted hit and is not shorter than the lock a knockback gives; a tackle toward a jelly does nothing and never swallows a tackle aimed at a creature behind it (Task 10).

---

## File map

**Create:** `scripts/world/deep_water.gd`, `scripts/player/player_water.gd`, `scripts/enemies/spear.gd`, `scripts/abilities/jolt.gd`, `scenes/abilities/jolt.tscn`, `tools/art/{glass_eel,cave_crayfish,drift_jelly,bog_lizardman,skill_icons_flooded}_frames.json`, `data/rooms/F1.tres`..`F5.tres` (and `F6.tres` in the slice), the new tests listed per task, `.tmp/flooded/author.gd` (the one-shot authoring script: not committed).

**Modify:** `scripts/world/{room_def,room_builder,room_lint,world_validator}.gd`, `scripts/editor/{room_edit_model,room_view}.gd` (+ the Water tool files in the slice), `scripts/player/player.gd`, `scripts/enemies/{enemy,enemy_state,enemy_status,spit_blob}.gd`, `scripts/abilities/ability.gd`, `scripts/forms/form_offers.gd`, `scripts/skills/creature_def.gd`, `scripts/core/{events,essences,sources,stat_keys}.gd`, `scripts/stats/stats.gd`, `scripts/ui/skill_screen.gd` (+ its model), `tools/build_content.gd`, `tools/art/make_icons.py`, `data/enemy_clips.json`, `data/audio/cues.json`, `data/creatures/*.tres`, `data/skills/*.tres` (generated), `data/rooms/G4.tres`, `docs/rooms.md`, `docs/playtest-checklist.md`, and the existing tests the spec's rescoped list names.

---

### Task 0: Worktree setup and the art kickoff

**Files:** Create `tools/art/{glass_eel,cave_crayfish,drift_jelly,bog_lizardman,skill_icons_flooded}_frames.json`; modify `tools/art/make_icons.py`.

**Interfaces:** Produces the frame lists the generator and `assemble_frames.py` read (`name`, `width`, `refs`, `prompt`, optional `attack_from`), later consumed by Task 13.

- [ ] **Step 1: Import the worktree.**

Run: `env HOME="$PWD/.tmp/gdhome" godot --headless --import` (twice if the first prints errors about missing imports).
Expected: exits 0.

- [ ] **Step 2: Write the five frame lists.** Each frame is generated alone. The creature `canonical` is the armored lizard (a style reference); the icons use the skill-icon sheet.

`tools/art/glass_eel_frames.json`:

```json
{
 "canonical": "assets/sprites/lizard_1.png",
 "style": "Modern pixel art with soft lighting (Style D): a long slender translucent glass eel, pale cyan body with a visible dark blue spine and a faint inner glow, a delicate frilled dorsal fin, two small black bead eyes, a clean dark outline, chunky readable pixels, gentle highlights and shading. Match the palette, outline weight and rendering of the reference image (an armored lizard) but draw this eel. Side view, the creature facing right. Draw only the creature: no water, no ground, no shadow, no effects.",
 "anchor": "swim_1",
 "frames": [
  {"name": "swim_1", "width": 52, "refs": [], "prompt": "The eel gliding forward, body in a gentle S-curve with the tail swung low."},
  {"name": "swim_2", "width": 52, "refs": ["swim_1"], "prompt": "The same eel mid-glide, body nearly straight, fins relaxed."},
  {"name": "swim_3", "width": 52, "refs": ["swim_1"], "prompt": "The same eel mid-glide, S-curve the other way, tail swung high."},
  {"name": "warn", "width": 52, "refs": ["swim_1"], "prompt": "The same eel arching its body backward like a drawn bow, mouth open, the inner glow flaring bright, about to dart."},
  {"name": "dart", "width": 60, "refs": ["swim_1", "warn"], "prompt": "The same eel darting forward at full speed: body stretched straight and thin, head thrust out, jaw open, a streak of glow behind.", "attack_from": 0.6},
  {"name": "stunned", "width": 52, "refs": ["swim_1"], "prompt": "The same eel dazed: body limp and sagging, eyes crossed, a few small sparks drifting around the head."},
  {"name": "hurt", "width": 52, "refs": ["swim_1"], "prompt": "The same eel flinching in pain, body kinked, eyes squeezed shut."},
  {"name": "downed", "width": 54, "refs": ["swim_1"], "prompt": "The same eel belly-up, body slack, fins drooping, the glow dim."}
 ]
}
```

`tools/art/cave_crayfish_frames.json`:

```json
{
 "canonical": "assets/sprites/lizard_1.png",
 "style": "Modern pixel art with soft lighting (Style D): a stocky cave crayfish with a pale blue-grey armored carapace, a segmented tail curled under, two large pincers, long thin antennae, small black eyes on short stalks, a clean dark outline, chunky readable pixels, gentle highlights and shading. Match the palette, outline weight and rendering of the reference image (an armored lizard) but draw this crayfish. Side view, the creature facing right. Draw only the creature: no ground, no shadow, no effects.",
 "anchor": "idle_1",
 "frames": [
  {"name": "idle_1", "width": 44, "refs": [], "prompt": "The crayfish standing still on all legs, pincers held low, antennae raised."},
  {"name": "walk_1", "width": 44, "refs": ["idle_1"], "prompt": "The same crayfish mid-scuttle, legs on the near side reaching forward."},
  {"name": "walk_2", "width": 44, "refs": ["idle_1"], "prompt": "The same crayfish mid-scuttle, legs gathered under the body."},
  {"name": "walk_3", "width": 44, "refs": ["idle_1"], "prompt": "The same crayfish mid-scuttle, legs on the far side reaching forward."},
  {"name": "windup_1", "width": 44, "refs": ["idle_1"], "prompt": "The same crayfish rearing up and back, pincers raised wide, tail tucked, about to lunge."},
  {"name": "charge_1", "width": 50, "refs": ["idle_1"], "prompt": "The same crayfish lunging hard: body low and stretched forward, pincers thrust out in front.", "attack_from": 0.55},
  {"name": "charge_2", "width": 50, "refs": ["idle_1", "charge_1"], "prompt": "The same crayfish lunging hard, a stride later, legs blurred, pincers snapping.", "attack_from": 0.55},
  {"name": "rest_1", "width": 44, "refs": ["idle_1"], "prompt": "The same crayfish panting after a lunge: body sagging low, pincers drooping."},
  {"name": "stunned", "width": 44, "refs": ["idle_1"], "prompt": "The same crayfish dazed: eyestalks drooping and crossed, pincers limp, a few stars above the carapace."},
  {"name": "hurt", "width": 44, "refs": ["idle_1"], "prompt": "The same crayfish flinching in pain, eyestalks flattened, pincers clamped shut."},
  {"name": "downed", "width": 46, "refs": ["idle_1"], "prompt": "The same crayfish knocked onto its back, legs curled in the air, carapace to the ground."}
 ]
}
```

`tools/art/drift_jelly_frames.json`:

```json
{
 "canonical": "assets/sprites/lizard_1.png",
 "style": "Modern pixel art with soft lighting (Style D): a small drifting cave jellyfish with a rounded translucent lavender-pink bell, a faint inner glow, a few short trailing tentacles and two tiny dark dots for eyes, a clean dark outline, chunky readable pixels, gentle highlights and shading. Match the palette, outline weight and rendering of the reference image (an armored lizard) but draw this jellyfish. Side view. Draw only the creature: no water, no ground, no shadow, no effects.",
 "anchor": "drift_1",
 "frames": [
  {"name": "drift_1", "width": 34, "refs": [], "prompt": "The jellyfish with its bell wide open, tentacles hanging straight down."},
  {"name": "drift_2", "width": 34, "refs": ["drift_1"], "prompt": "The same jellyfish with its bell contracted narrow, tentacles gathered together."},
  {"name": "drift_3", "width": 34, "refs": ["drift_1"], "prompt": "The same jellyfish with its bell relaxing open, tentacles flaring outward."},
  {"name": "stunned", "width": 34, "refs": ["drift_1"], "prompt": "The same jellyfish dazed: bell slumped to one side, tentacles limp, a few small sparks drifting around it."},
  {"name": "hurt", "width": 34, "refs": ["drift_1"], "prompt": "The same jellyfish flinching, bell clenched tight, tentacles curled up."},
  {"name": "downed", "width": 36, "refs": ["drift_1"], "prompt": "The same jellyfish collapsed, bell flat, tentacles spread limp, the glow dim."}
 ]
}
```

`tools/art/bog_lizardman_frames.json`:

```json
{
 "canonical": "assets/sprites/lizard_1.png",
 "style": "Modern pixel art with soft lighting (Style D): a small upright lizardman of the marsh with olive-green scales and a pale belly, a crest along its head, a long snout, a wrapped cloth belt, a thick tail, holding a long wooden spear, a clean dark outline, chunky readable pixels, gentle highlights and shading. Match the palette, outline weight and rendering of the reference image (an armored lizard) but draw this lizardman. Side view, the creature facing right. Draw only the creature: no ground, no shadow, no effects.",
 "anchor": "idle_1",
 "frames": [
  {"name": "idle_1", "width": 40, "refs": [], "prompt": "The lizardman standing on guard, the spear held upright beside him."},
  {"name": "walk_1", "width": 40, "refs": ["idle_1"], "prompt": "The same lizardman mid-stride, near leg forward, spear carried at his side."},
  {"name": "walk_2", "width": 40, "refs": ["idle_1"], "prompt": "The same lizardman mid-stride, legs together, spear carried at his side."},
  {"name": "walk_3", "width": 40, "refs": ["idle_1"], "prompt": "The same lizardman mid-stride, far leg forward, spear carried at his side."},
  {"name": "windup_1", "width": 44, "refs": ["idle_1"], "prompt": "The same lizardman leaning back with the spear drawn behind his shoulder, aiming it, eyes narrowed."},
  {"name": "throw_1", "width": 46, "refs": ["idle_1", "windup_1"], "prompt": "The same lizardman following through on a throw: arm thrust forward and empty, body leaning into it, tail swung back."},
  {"name": "stunned", "width": 40, "refs": ["idle_1"], "prompt": "The same lizardman dazed: swaying, eyes crossed, spear sagging, a few stars above his head."},
  {"name": "hurt", "width": 40, "refs": ["idle_1"], "prompt": "The same lizardman flinching in pain, head thrown back, spear gripped tight."},
  {"name": "downed", "width": 46, "refs": ["idle_1"], "prompt": "The same lizardman knocked flat on his back, limbs sprawled, spear beside him."}
 ]
}
```

`tools/art/skill_icons_flooded_frames.json`:

```json
{
 "canonical": "art_source/skill_icons_d.png",
 "style": "Modern pixel art with soft lighting (Style D), exactly matching the skill icons in the reference sheet: a single square skill icon, a dark navy rounded-square badge with a thin bright outline, and one glowing item centred inside it, chunky readable pixels, gentle highlights. Draw exactly one icon, centred, filling most of the frame.",
 "anchor": "icon_swim",
 "frames": [
  {"name": "icon_swim", "width": 128, "refs": [], "prompt": "A skill icon of a small blue slime body gliding through rippling water, a few bubbles trailing behind it."},
  {"name": "icon_jolt", "width": 128, "refs": [], "prompt": "A skill icon of a crackling cyan and white lightning burst radiating outward from a small glowing orb."}
 ]
}
```

- [ ] **Step 3: Parameterise `make_icons.py`** so it also reads the Flooded icons (it hard-codes the Grotto's directory):

```python
SRC_DIRS = ["art_source/frames/skill_icons_grotto", "art_source/frames/skill_icons_flooded"]
OUT = "assets/sprites"
...
def main():
    for src in SRC_DIRS:
        if not os.path.isdir(src):
            continue
        for name in sorted(f[:-4] for f in os.listdir(src) if f.endswith(".png")):
            icon = make_icon(Image.open(os.path.join(src, name + ".png")))
            icon.save(os.path.join(OUT, name + ".png"))
            print("wrote", name)
```

Remove the old `SRC` constant and update the docstring ("the generated skill icons").

- [ ] **Step 4: Validate the lists** (names match the generator's regex, every ref exists in its own set, widths are integers). Save this as `.tmp/validate_frames.py` and run `python3 .tmp/validate_frames.py`:

```python
import json
import re

for s in ["glass_eel", "cave_crayfish", "drift_jelly", "bog_lizardman", "skill_icons_flooded"]:
    d = json.load(open("tools/art/%s_frames.json" % s))
    names = [f["name"] for f in d["frames"]]
    for f in d["frames"]:
        assert re.match(r"^[a-z0-9_]+$", f["name"]), f["name"]
        assert isinstance(f["width"], int)
        for r in f["refs"]:
            assert r in names, (s, r)
    print(s, len(names))
```

Expected: prints `glass_eel 8`, `cave_crayfish 11`, `drift_jelly 6`, `bog_lizardman 9`, `skill_icons_flooded 2`.

- [ ] **Step 5: Commit the lists, then start generation in the background** (unsandboxed; whole command; one job per set so the sets run in parallel and each set's frames chain through their refs):

```bash
git add tools/art && git commit -m "art: frame lists for the Flooded Tunnels creatures and the Swim and Jolt icons"
```

Run each of these as its own background Bash call with `dangerouslyDisableSandbox: true`:
`uv run --python 3.12 python tools/art/generate_frames.py glass_eel` (and `cave_crayfish`, `drift_jelly`, `bog_lizardman`, `skill_icons_flooded`). Output lands in `art_source/frames/<set>/<name>.png`. The generator resumes (skips frames that exist), so a failed run is re-run as is. Task 13 assembles them.

---

### Task 1: Registrations and `CreatureDef` flags

**Files:** Modify `scripts/core/events.gd`, `scripts/core/stat_keys.gd`, `scripts/stats/stats.gd`, `scripts/skills/creature_def.gd`, `data/audio/cues.json`, `tests/test_constants.gd`; Create `tests/test_flooded_registrations.gd`.

**Interfaces:** Produces `Events.SUBMERGED`, `StatKeys.SWIM_SPEED`, `Stats.DEFAULTS["swim_speed"] = 120`, and `CreatureDef.{swimmer, untackleable, contact_type, projectile, puffs}`. Task 3 sets the flags in data; Tasks 9 and 10 read them.

- [ ] **Step 1: Write the failing test** `tests/test_flooded_registrations.gd`:

```gdscript
extends GutTest
## The names the Flooded Tunnels add to the shared registries, before any behaviour uses them.

func test_submerged_is_an_event_and_swim_speed_a_stat() -> void:
	assert_true(Events.ALL.has(Events.SUBMERGED))
	assert_eq(Events.SUBMERGED, "submerged")
	assert_true(StatKeys.ALL.has(StatKeys.SWIM_SPEED))
	assert_eq(StatKeys.SWIM_SPEED, "swim_speed")
	assert_eq(Stats.new().get_stat("swim_speed"), 120, "px/s, not a percent")

func test_creature_def_flags_default_off() -> void:
	var c := CreatureDef.new()
	assert_false(c.swimmer)
	assert_false(c.untackleable)
	assert_eq(c.contact_type, "physical")
	assert_eq(c.projectile, "")
	assert_false(c.puffs)

func test_submerged_has_a_silent_audio_entry_with_a_reason() -> void:
	var cues: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/audio/cues.json"))
	assert_true(cues["events"].has("submerged"))
	assert_null(cues["events"]["submerged"], "once a second is not a sound")
	assert_true(cues["events"].has("_why:submerged"))
```

- [ ] **Step 2: Run to confirm it fails.** `tools/run_tests.sh test_flooded_registrations` → FAIL (identifiers missing).

- [ ] **Step 3: Implement.**

`events.gd`: add `const SUBMERGED := "submerged"` after `SKILL_LEVELED`, append `SUBMERGED` to `ALL`, and change the file's doc line to: `## Event names emitted by the player to EventBus. All events are edge-triggered except SUBMERGED, which is periodic (once per second in water).` `scripts/player/player_sensors.gd`'s header says its emitters are edge-triggered: add the same exception there.

`stat_keys.gd`: add `const SWIM_SPEED := "swim_speed"`, append to `ALL`, and add a doc line: `## swim_speed is in px/s: neither integer nor percent.` (not added to `INTEGER` or `PERCENT`).

`stats.gd`: add `"swim_speed": 120` to `DEFAULTS`.

`creature_def.gd`: append

```gdscript
## Lives in a water rect (confined to it) and is what Jolt stuns: the eels and the jelly.
@export var swimmer: bool = false
## A tackle skips it: the jelly.
@export var untackleable: bool = false
## The damage type of its contact hit: "physical", or "shock" for the eels and the jelly.
@export var contact_type: String = "physical"
## "" for none, "spear" for the lizardman (a spitter that throws a Spear).
@export var projectile: String = ""
## Drops a spore puff (the two moths).
@export var puffs: bool = false
```

`cues.json`: in `events`, add `"submerged": null,` and `"_why:submerged": "once a second while swimming is not a sound; water_entered and water_exited carry the splash",` next to the `inspected` entries (match their formatting).

`test_constants.gd`: update the `StatKeys.ALL` and `Events.ALL` pins (add `"swim_speed"` and `"submerged"` at the ends).

- [ ] **Step 4: Run** `tools/run_tests.sh test_flooded_registrations` and `tools/run_tests.sh test_constants` and `tools/run_tests.sh test_audio_catalog` → PASS. Mutation check: delete `"swim_speed": 120` from `DEFAULTS` → the first test fails.

- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat: submerged, swim_speed and the creature flags the Flooded Tunnels need"`

---

### Task 2: Skills, essence, creatures and their data

**Files:** Modify `scripts/core/essences.gd`, `scripts/core/sources.gd`, `tools/build_content.gd`, `scripts/ui/skill_screen_model.gd`, `tests/test_skill_screen_model.gd`, `tests/test_constants.gd`, `tests/test_content.gd`, `tests/test_skill_caps.gd`, `tests/test_def_validator.gd`; Generate `data/skills/{swim,jolt}.tres`, `data/creatures/{glass_eel,cave_crayfish,drift_jelly,bog_lizardman}.tres`, regenerated moth defs; Create `tests/test_flooded_data.gd`.

**Interfaces:** Consumes Task 1's flags and `StatKeys.SWIM_SPEED`. Produces `Essences.SHOCK`, `Sources.{GLASS_EEL, CAVE_CRAYFISH, DRIFT_JELLY, BOG_LIZARDMAN}`, the skills `swim` and `jolt`, the four creature defs, and `puffs = true` on `spore_moth` and `pale_moth`.

- [ ] **Step 1: Read the surfaces to extend** (so the test names match): `scripts/core/sources.gd` (the `ALL` list), `tests/test_content.gd` (the skill and creature counts and the "every essence skill is supplied" check), `tests/test_skill_caps.gd` (`TABLE`), `scripts/skills/def_validator.gd` (how a creature and a skill are validated, which stats a modifier may name, which events an unlock may name).

- [ ] **Step 2: Write the failing test** `tests/test_flooded_data.gd`:

```gdscript
extends GutTest
## The Flooded Tunnels' skills and creatures as data: the numbers the spec fixes.

var creatures := {}
var skills := {}

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills[d.id] = d

func test_the_new_ids_are_sources_and_have_defs() -> void:
	for id in ["glass_eel", "cave_crayfish", "drift_jelly", "bog_lizardman"]:
		assert_true(Sources.ALL.has(id), id)
		assert_true(creatures.has(id), id)
	assert_true(Essences.ALL.has(Essences.SHOCK))

func test_creature_numbers_and_flags() -> void:
	var eel: CreatureDef = creatures["glass_eel"]
	assert_eq(eel.xp, 3)
	assert_eq(eel.essences, {"shock": 1, "water": 1})
	assert_true(eel.swimmer)
	assert_eq(eel.contact_type, "shock")
	assert_eq(eel.stats["spd"], 140)
	var crayfish: CreatureDef = creatures["cave_crayfish"]
	assert_eq(crayfish.xp, 5)
	assert_true(crayfish.armored_charger)
	assert_eq(crayfish.contact_type, "physical")
	var jelly: CreatureDef = creatures["drift_jelly"]
	assert_eq(jelly.xp, 3)
	assert_true(jelly.drifter and jelly.swimmer and jelly.untackleable)
	assert_eq(jelly.contact_type, "shock")
	assert_eq(jelly.essences, {"shock": 1, "water": 2})
	var lizardman: CreatureDef = creatures["bog_lizardman"]
	assert_eq(lizardman.xp, 5)
	assert_eq(lizardman.projectile, "spear")
	assert_eq(lizardman.skills, [], "no poison_spit: a spear is not poison")
	assert_eq(lizardman.essences, {"earth": 1, "water": 1})

func test_the_stats_are_scaled_like_the_grottos() -> void:
	var eel: CreatureDef = creatures["glass_eel"]
	assert_eq(eel.stats["max_hp"], floori(float(4 * (100 + 8 * 6) + 50) / 100.0), "level 7")
	assert_eq(eel.stats["max_hp"], 6)

func test_only_the_moths_puff() -> void:
	assert_true((creatures["spore_moth"] as CreatureDef).puffs)
	assert_true((creatures["pale_moth"] as CreatureDef).puffs)
	for id in creatures:
		if id != "spore_moth" and id != "pale_moth":
			assert_false((creatures[id] as CreatureDef).puffs, id)

func test_swim_and_jolt() -> void:
	var swim: SkillDef = skills["swim"]
	assert_eq(swim.source, "proficiency")
	assert_eq(swim.unlock[0]["event"], "submerged")
	assert_eq(swim.unlock[0]["n"], 20)
	assert_eq(swim.max_level, 3)
	assert_eq(swim.level_curve, 40)
	assert_true(swim.effects.any(func(e): return e.get("flag", "") == "swim"))
	var speed: Dictionary = swim.effects.filter(func(e): return e.get("stat", "") == "swim_speed")[0]
	assert_eq(speed["values"], [0, 30, 60])
	var jolt: SkillDef = skills["jolt"]
	assert_eq(jolt.source, "essence")
	assert_eq(jolt.mp_cost, 5)
	assert_eq(jolt.unlock[0]["tags"], {"essence": "shock"})
	assert_eq(jolt.max_level, 5)
	assert_eq(jolt.effects[0]["values"], [3, 4, 5, 6, 7])
```

- [ ] **Step 3: Run to confirm it fails.** `tools/run_tests.sh test_flooded_data` → FAIL.

- [ ] **Step 4: Implement.**

`essences.gd`: add `const SHOCK := "shock"` and append it to `ALL`; update the doc line (shock feeds Jolt).

`sources.gd`: add `GLASS_EEL := "glass_eel"`, `CAVE_CRAYFISH := "cave_crayfish"`, `DRIFT_JELLY := "drift_jelly"`, `BOG_LIZARDMAN := "bog_lizardman"` and append all four to `ALL`.

`tools/build_content.gd`: in `_skills()` add, after `hardened_shell`:

```gdscript
		_s({"id": "swim", "display_name": "Swim", "source": "proficiency",
			"description": "Move freely through deep water.", "hint": "The water holds you up a little more each time.",
			"announce": "Proficiency reached. Acquired [Swim].",
			"unlock": [_c("submerged", 20)], "levels_on": _on("submerged"), "level_curve": 40, "max_level": 3,
			"effects": [{"kind": "capability", "flag": "swim"}, _mod(StatKeys.SWIM_SPEED, [0, 30, 60])]}),
		_s({"id": "jolt", "display_name": "Jolt", "source": "essence", "hidden": false,
			"description": "A burst of shock around you that stuns swimmers.", "hint": "Something crackles faintly within.",
			"announce": "Analysis complete. Acquired [Jolt].",
			"unlock": [_c("absorbed", 4, {"essence": "shock"})],
			"levels_on": _on("skill_used", {"id": "jolt"}), "level_curve": 8, "max_level": 5,
			"effects": [_active("jolt", [3, 4, 5, 6, 7])], "mp_cost": 5}),
```

add `const FLOODED_LEVEL := 7` beside `GROTTO_LEVEL` (comment: "the Flooded's creatures are level 7"), set `"puffs": true` on `spore_moth` and `pale_moth`, and add to `_creatures()` after `pale_moth`:

```gdscript
		_cr({"id": "glass_eel", "display_name": "Glass Eel", "stats": _at_level(FLOODED_LEVEL, {"max_hp": 4, "atk": 2, "def": 0, "spd": 140}),
			"essences": {"shock": 1, "water": 1}, "skills": [], "swimmer": true, "contact_type": "shock",
			"eat_bonus": {"stat": "spd", "amount": 2, "per": 2}, "xp": 3}),
		_cr({"id": "cave_crayfish", "display_name": "Cave Crayfish", "stats": _at_level(FLOODED_LEVEL, {"max_hp": 9, "atk": 3, "def": 3, "spd": 60}),
			"essences": {"shell": 1, "water": 1}, "skills": [], "armored_charger": true,
			"eat_bonus": {"stat": "def", "amount": 1, "per": 3}, "xp": 5}),
		_cr({"id": "drift_jelly", "display_name": "Drift Jelly", "stats": _at_level(FLOODED_LEVEL, {"max_hp": 3, "atk": 2, "def": 0, "spd": 30}),
			"essences": {"shock": 1, "water": 2}, "skills": [], "drifter": true, "swimmer": true, "untackleable": true, "contact_type": "shock",
			"eat_bonus": {"stat": "max_mp", "amount": 1, "per": 2}, "xp": 3}),
		_cr({"id": "bog_lizardman", "display_name": "Bog Lizardman", "stats": _at_level(FLOODED_LEVEL, {"max_hp": 7, "atk": 3, "def": 1, "spd": 80}),
			"essences": {"earth": 1, "water": 1}, "skills": [], "projectile": "spear",
			"eat_bonus": {"stat": "atk", "amount": 1, "per": 3}, "xp": 5}),
```

Run the generator: `env HOME="$PWD/.tmp/gdhome" godot --headless -s tools/build_content.gd` (prints `wrote ...` per file; exit 0). Run it twice and `git status` to see the `.tres` change only where expected (the moths gain `puffs`).

Registration surfaces to update in the same step: `tests/test_constants.gd` (`Sources.ALL`, `Essences.ALL`), `tests/test_content.gd` (skill and creature counts; the "every essence skill is supplied" check must count the Flooded sources' shock, which exist now), `tests/test_skill_caps.gd` `TABLE` (add `swim` and `jolt` with the table's own columns: `max_level`, `level_curve`, effect values), and `DefValidator` if it rejects the new stat or flag (it should accept `swim_speed` through `StatKeys.ALL` and a `capability` flag named `swim`).

- [ ] **Step 4b: The skill screen's effect line for Swim.** Read `scripts/ui/skill_screen_model.gd` (its stat labels and the percent and seconds cases beside `DAMAGE_TAKEN`/`KNOCKBACK_TAKEN`). Add a test in `tests/test_skill_screen_model.gd` first:

```gdscript
func test_swim_speed_reads_as_pixels_per_second_not_a_percent() -> void:
	var swim: SkillDef = DefLoader.load_dir("res://data/skills").filter(func(d): return d.id == "swim")[0]
	var text := SkillScreenModel.effect_text(swim, 2)  # use the model's real function name for a skill's effect line
	assert_string_contains(text, "Swim speed")
	assert_string_contains(text, "150")
	assert_false(text.contains("%"), text)
```

then make it pass by labelling `swim_speed` ("Swim speed") and formatting it as `<n> px/s` where the model formats a stat modifier (the level-2 line shows the stat's value, 120 + 30 = 150). Use the model's actual function and constant names (the test above names the likely ones: adjust them to what the file defines).

- [ ] **Step 5: Run** `tools/run_tests.sh test_flooded_data`, `test_skill_screen_model`, `test_content`, `test_skill_caps`, `test_def_validator`, `test_constants`, `test_grotto` (the moths) → all PASS. Mutation check: remove `"puffs": true` from `pale_moth` in `build_content.gd`, rerun the generator → `test_only_the_moths_puff` fails; restore.

- [ ] **Step 6: Commit.** `git add -A && git commit -m "feat: the shock essence, Swim and Jolt, and the four Flooded creatures as data"`

---

### Task 3: The first evolution's affinity is scoped to the Cave and Grotto

**Files:** Modify `scripts/forms/form_offers.gd`, `tests/test_form_offers.gd`, `tests/test_form_tab.gd`, `tests/test_rebirth_kit.gd`; Create `tests/test_first_evolution_areas.gd`.

**Interfaces:** Produces `FormOffers.FIRST_EVOLUTION_AREAS` and `FormOffers.supply(rooms, creatures, forms, areas := [])`. `default_supply` passes the constant.

- [ ] **Step 1: Write the failing test** `tests/test_first_evolution_areas.gd`:

```gdscript
extends GutTest
## The affinity that picks the first evolution divides by the supply of the areas a stage-1 life plays, so a later area
## (the Flooded) does not dilute it.

func _creatures() -> Dictionary:
	var out := {}
	for c in DefLoader.load_dir("res://data/creatures"):
		out[c.id] = c
	return out

func _room(id: String, area: String, spawns: Array) -> RoomDef:
	var r := RoomDef.new()
	r.id = id
	r.area = area
	r.spawns = spawns
	return r

func test_supply_counts_only_the_listed_areas() -> void:
	var forms := FormLoader.load_all()
	var rooms := {
		"A": _room("A", "cave", [{"id": "toad", "pos": Vector2.ZERO}]),
		"B": _room("B", "flooded", [{"id": "drift_jelly", "pos": Vector2.ZERO}]),
	}
	var all := FormOffers.supply(rooms, _creatures(), forms)
	var scoped := FormOffers.supply(rooms, _creatures(), forms, ["cave"])
	assert_eq(all["tide"], 3, "toad water 1 + jelly water 2")
	assert_eq(scoped["tide"], 1, "only the cave's toad")

func test_the_default_supply_ignores_the_flooded() -> void:
	FormOffers._default_supply = {}
	var forms := FormLoader.load_all()
	var scoped := FormOffers.default_supply(forms)
	var rooms := World.load_rooms("res://data/rooms")
	var expected := FormOffers.supply(rooms, _creatures(), forms, FormOffers.FIRST_EVOLUTION_AREAS)
	assert_eq(scoped, expected)
	FormOffers._default_supply = {}

func test_the_first_evolution_areas_are_derived_not_trusted() -> void:
	# the Grotto's own rule, restated for the list: the ungated first-time XP of these areas reaches stage 1's cap, and
	# without the last area it does not
	var rooms := ShippedRooms.load_all()
	var creatures := _creatures()
	var reach := WorldValidator.reachable(rooms, true)
	var by_area := {}
	for id in reach:
		var r: RoomDef = rooms[id]
		for s in r.spawns:
			var c: CreatureDef = creatures[s["id"]]
			by_area[r.area] = int(by_area.get(r.area, 0)) + c.xp * (1 if c.id == "water_pool" else 2)
	var total := 0
	for a in FormOffers.FIRST_EVOLUTION_AREAS:
		total += int(by_area.get(a, 0))
	assert_gte(total, Progression.stage_total(1), "cave plus grotto reach the cap")
	var without_last: int = total - int(by_area.get(FormOffers.FIRST_EVOLUTION_AREAS.back(), 0))
	assert_lt(without_last, Progression.stage_total(1), "the cap lands in the last of them")
```

- [ ] **Step 2: Run to confirm it fails.** `tools/run_tests.sh test_first_evolution_areas` → FAIL (`FIRST_EVOLUTION_AREAS`, the fourth parameter).

- [ ] **Step 3: Implement** in `form_offers.gd`:

```gdscript
## The areas a stage-1 life plays before its first evolution (the Cave and Grotto reach stage 1's cap; test_first_evolution_areas
## derives it). Only stage 1 to 2 reads affinity, so a later area adds no denominator.
const FIRST_EVOLUTION_AREAS := ["cave", "grotto"]
```

Change `default_supply` to `_default_supply = supply(World.load_rooms("res://data/rooms"), creatures, forms, FIRST_EVOLUTION_AREAS)`; change `supply` to

```gdscript
## lineage -> units of its essences across every spawn in `rooms` (only the rooms of `areas`, when given).
static func supply(rooms: Dictionary, creatures: Dictionary, forms: Dictionary, areas: Array = []) -> Dictionary:
	...
	for id in rooms:
		if not areas.is_empty() and not areas.has((rooms[id] as RoomDef).area):
			continue
```

Update the file's header doc (it says "every spawn of the shipped rooms"): "the same essences across every spawn of the first-evolution areas' rooms".

Rescope the three existing tests with the explicit filter: `test_form_offers.gd` (its supply already filters to `"cave"`: confirm it still reads the Cave only), `test_form_tab.gd:91` (it calls `default_supply`: leave, now scoped by the constant), `test_rebirth_kit.gd` (every `FormOffers.supply(...)` call there passes `FormOffers.FIRST_EVOLUTION_AREAS` as the fourth argument, and the `_default_supply` pin helper does the same).

- [ ] **Step 4: Run** `tools/run_tests.sh test_first_evolution_areas`, `test_form_offers`, `test_form_tab`, `test_rebirth_kit` → PASS (no Flooded rooms exist yet, so the derived-areas test sees the Cave and Grotto). Mutation check: pass `[]` in `default_supply` → the second test fails once Task 12's rooms exist; for now flip the constant to `["cave"]` → the third test fails.

- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat: the first evolution's affinity reads only the Cave and Grotto"`

---

### Task 4: `RoomDef.water` and the editor core

**Files:** Modify `scripts/world/room_def.gd`, `scripts/editor/room_edit_model.gd`; Create `tests/test_room_edit_water.gd`.

**Interfaces:** Produces `RoomDef.water: Array` (of `Rect2`, local px), kept by `copy_room`, `same_room`, snapshots, undo, redo and the `.tres` save, and shifted by `_shift_content`.

- [ ] **Step 1: Write the failing test** `tests/test_room_edit_water.gd`:

```gdscript
extends GutTest
## Water rides the editor like every other stored property: snapshots, undo, redo, save, and a Grow.

func _model() -> RoomEditModel:
	var r := RoomDef.new()
	r.id = "T1"
	r.area = "flooded"
	r.cell = Vector2i(2, 2)
	r.size = Vector2i(1, 1)
	r.start = Vector2(60, 308)
	r.water = [Rect2(100, 200, 64, 64)]
	return RoomEditModel.new({"T1": r}, [])

func test_the_default_is_no_water() -> void:
	assert_eq(RoomDef.new().water, [])

func test_a_copy_keeps_water_and_is_independent() -> void:
	var a := RoomEditModel.copy_room(_model().rooms["T1"])
	assert_eq(a.water, [Rect2(100, 200, 64, 64)])
	a.water.append(Rect2(0, 0, 40, 40))
	assert_eq(RoomEditModel.copy_room(_model().rooms["T1"]).water.size(), 1, "a deep copy")

func test_a_grow_to_the_left_shifts_water_with_the_room_and_undo_restores_it() -> void:
	var m := _model()
	assert_eq(m.grow_room("T1", "left"), "")
	assert_eq(m.rooms["T1"].water, [Rect2(740, 200, 64, 64)], "one screen (640) right of where it was")
	assert_true(m.undo())
	assert_eq(m.rooms["T1"].water, [Rect2(100, 200, 64, 64)])
	assert_true(m.redo())
	assert_eq(m.rooms["T1"].water, [Rect2(740, 200, 64, 64)])

func test_a_grow_to_the_right_leaves_water_where_it_is() -> void:
	var m := _model()
	assert_eq(m.grow_room("T1", "right"), "")
	assert_eq(m.rooms["T1"].water, [Rect2(100, 200, 64, 64)])

func test_water_changes_make_a_room_dirty_and_survive_a_save_and_load() -> void:
	var m := _model()
	m.rooms["T1"].water = [Rect2(100, 200, 64, 64), Rect2(300, 220, 80, 60)]
	var dir := "user://test_water_rooms"
	DirAccess.make_dir_recursive_absolute(dir)
	var result := m.save_dirty(dir)
	assert_eq(result["errors"], {})
	var loaded := ResourceLoader.load("%s/T1.tres" % dir, "", ResourceLoader.CACHE_MODE_IGNORE) as RoomDef
	assert_eq(loaded.water, [Rect2(100, 200, 64, 64), Rect2(300, 220, 80, 60)])
	DirAccess.remove_absolute("%s/T1.tres" % dir)

func test_a_room_file_from_before_water_loads_with_none() -> void:
	var c1 := ResourceLoader.load("res://data/rooms/C1.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as RoomDef
	assert_eq(c1.water, [], "the shipped Cave rooms never had a water property")
```

- [ ] **Step 2: Run to confirm it fails.** `tools/run_tests.sh test_room_edit_water` → FAIL (`water`).

- [ ] **Step 3: Implement.** `room_def.gd`, after `features`:

```gdscript
## Deep water (Rect2, local px): swim physics, the swimmers' homes, drawn by RoomBuilder as DeepWater. At least 32x32,
## inside the room, never overlapping or touching another. Shallow water is decor.
@export var water: Array = []
```

`room_edit_model.gd` `_shift_content`, after the `hard_ledges` loop:

```gdscript
	for i in r.water.size():
		r.water[i] = Rect2((r.water[i] as Rect2).position + d, (r.water[i] as Rect2).size)
```

`_props()` already copies every exported property, so snapshots, undo, redo and `same_room` need no edit. Update the model's header doc listing what a room holds, if it lists properties.

- [ ] **Step 4: Run** `tools/run_tests.sh test_room_edit_water` and `tools/run_tests.sh test_room_edit` → PASS. Mutation check: delete the `_shift_content` arm → the Grow test fails.

- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat: RoomDef.water, kept through the editor's undo, save and Grow"`

---

### Task 5: Lint rules `water_rect`, `swimmer_dry`, `water_exit`, and the `swim` gate

**Files:** Modify `scripts/world/room_lint.gd`, `scripts/world/world_validator.gd`, `docs/rooms.md`, `tests/test_room_lint.gd`, `tests/test_world_validator.gd`; Create `tests/test_room_lint_water.gd`.

**Interfaces:** Consumes `RoomDef.water` (Task 4) and the creature flag `swimmer` (Task 2). Produces `RoomLint.SURFACE_LIFT`, `RoomLint.has_shore(r, rect)`, `RoomLint.reaches_edge(r, rect, e)`, `RoomLint.water_groups(rooms)` (the authored-world check, returns findings), the three rules in `RULES` and `check_room`, and `WorldValidator.GATES` containing `"swim"`.

- [ ] **Step 1: Write the failing test** `tests/test_room_lint_water.gd`. Build rooms by hand (a 1×1 `flooded` room is 640×360; its floor top is 320; walls 20):

```gdscript
extends GutTest
## The three water rules: water_rect, swimmer_dry and water_exit, and the authored-world shore check.

func _room(water: Array, solids: Array = [], spawns: Array = [], exits: Array = []) -> RoomDef:
	var r := RoomDef.new()
	r.id = "W1"
	r.area = "flooded"
	r.size = Vector2i(1, 1)
	r.start = Vector2(60, 308)
	r.water = water
	r.solids = solids
	r.spawns = spawns
	r.exits = exits
	return r

func _rules(r: RoomDef) -> Array:
	return RoomLint.check_room(r, {"W1": r}).map(func(f): return f["rule"])

func test_surface_lift_is_derived_from_the_jump_and_the_body() -> void:
	assert_eq(RoomLint.SURFACE_LIFT, floorf(pow(Player.JUMP_VELOCITY, 2.0) / (2.0 * Player.GRAVITY) - BodyConfig.BOTTOM - 4.0))
	assert_eq(RoomLint.SURFACE_LIFT, 44.0)

func test_the_rules_are_registered() -> void:
	for rule in ["water_rect", "swimmer_dry", "water_exit"]:
		assert_true(RoomLint.RULES.has(rule), rule)
	assert_eq(RoomLint.RULES.size(), 16)

# --- water_rect ---

func test_a_water_rect_outside_the_room_is_reported() -> void:
	assert_true(_rules(_room([Rect2(600, 200, 100, 60)])).has("water_rect"))

func test_a_water_rect_under_32_px_either_way_is_reported() -> void:
	assert_true(_rules(_room([Rect2(100, 200, 31, 60)])).has("water_rect"))
	assert_true(_rules(_room([Rect2(100, 200, 60, 31)])).has("water_rect"))

func test_overlapping_and_touching_rects_are_reported() -> void:
	assert_true(_rules(_room([Rect2(100, 200, 80, 80), Rect2(150, 220, 80, 80)])).has("water_rect"), "overlap")
	assert_true(_rules(_room([Rect2(100, 200, 80, 80), Rect2(180, 200, 80, 80)])).has("water_rect"), "touching edge to edge")

func test_a_clean_pool_with_a_shore_has_no_water_findings() -> void:
	var shore := Rect2(150, 245, 50, 12)  # a ledge just at the rect's left, top 245 is within the lift band of the surface at 240
	var r := _room([Rect2(200, 240, 160, 80)], [shore])
	var rules := _rules(r).filter(func(x): return x.begins_with("water"))
	assert_eq(rules, [])

# --- swimmer_dry ---

func test_a_swimmer_outside_every_water_rect_is_reported_and_a_walker_never_is() -> void:
	var dry := _room([Rect2(200, 240, 160, 80)], [Rect2(150, 245, 50, 12)], [{"id": "glass_eel", "pos": Vector2(60, 100)}])
	assert_true(_rules(dry).has("swimmer_dry"))
	var wet := _room([Rect2(200, 240, 160, 80)], [Rect2(150, 245, 50, 12)], [{"id": "glass_eel", "pos": Vector2(260, 280)}])
	assert_false(_rules(wet).has("swimmer_dry"))
	var walker := _room([Rect2(200, 240, 160, 80)], [Rect2(150, 245, 50, 12)], [{"id": "toad", "pos": Vector2(60, 100)}])
	assert_false(_rules(walker).has("swimmer_dry"), "a ground creature in or out of water is nothing")

# --- water_exit ---

func test_a_pit_with_no_shore_and_no_exit_traps_a_swimmer() -> void:
	var r := _room([Rect2(200, 240, 160, 80)])
	assert_true(_rules(r).has("water_exit"))

func test_a_ledge_inside_the_band_is_a_shore() -> void:
	var r := _room([Rect2(200, 240, 160, 80)], [Rect2(150, 236, 50, 12)])  # top 236 is 4 above the surface
	assert_false(_rules(r).has("water_exit"))

func test_a_ledge_too_high_above_or_too_deep_inside_is_no_shore() -> void:
	var high := _room([Rect2(200, 240, 160, 80)], [Rect2(150, 190, 50, 12)])  # 50 above the surface: past SURFACE_LIFT
	assert_true(_rules(high).has("water_exit"), "out of the surface jump's reach")
	var deep := _room([Rect2(200, 240, 160, 80)], [Rect2(250, 270, 60, 12)])  # a ledge inside the water, 30 below the surface
	assert_true(_rules(deep).has("water_exit"), "a body standing on it is still in water")

func test_a_ledge_more_than_24_px_from_the_rect_is_no_shore() -> void:
	var far := _room([Rect2(200, 240, 160, 80)], [Rect2(100, 236, 50, 12)])  # ends at x 150, 50 from the rect
	assert_true(_rules(far).has("water_exit"))

func test_an_open_exit_span_the_rect_reaches_is_a_way_out() -> void:
	var top := {"edge": "top", "from": 200.0, "to": 360.0, "room": "W2"}
	var r := _room([Rect2(200, 20, 160, 300)], [], [], [top])
	assert_false(_rules(r).has("water_exit"))

func test_a_shortcut_or_wall_cling_gated_exit_is_not_a_way_out_but_swim_is() -> void:
	var water := [Rect2(200, 20, 160, 300)]
	var base := {"edge": "top", "from": 200.0, "to": 360.0, "room": "W2"}
	var shortcut := base.duplicate()
	shortcut["shortcut"] = "s1"
	assert_true(_rules(_room(water, [], [], [shortcut])).has("water_exit"))
	var cling := base.duplicate()
	cling["gate"] = "wall_cling"
	assert_true(_rules(_room(water, [], [], [cling])).has("water_exit"))
	var swim := base.duplicate()
	swim["gate"] = "swim"
	assert_false(_rules(_room(water, [], [], [swim])).has("water_exit"))

# --- the authored-world check ---

func test_adjacent_rects_that_each_reach_a_shared_exit_still_need_a_shore_somewhere() -> void:
	var a := _room([Rect2(200, 20, 160, 300)], [], [], [{"edge": "top", "from": 200.0, "to": 360.0, "room": "W2"}])
	a.id = "W1"
	a.cell = Vector2i(0, 1)
	var b := RoomDef.new()
	b.id = "W2"
	b.area = "flooded"
	b.cell = Vector2i(0, 0)
	b.size = Vector2i(1, 1)
	b.water = [Rect2(200, 100, 160, 260)]  # reaches the bottom edge over the span
	b.exits = [{"edge": "bottom", "from": 200.0, "to": 360.0, "room": "W1"}]
	var rooms := {"W1": a, "W2": b}
	assert_eq(RoomLint.water_groups(rooms).size(), 1, "no shore in either: one trapped group")
	b.solids = [Rect2(150, 90, 50, 12)]  # a shore beside W2's rect: its top (90) is 10 above W2's surface (100), inside the lift band
	assert_eq(RoomLint.water_groups(rooms).size(), 0)

func test_a_rect_that_leaves_through_an_open_exit_into_dry_land_is_not_trapped() -> void:
	var a := _room([Rect2(200, 20, 160, 300)], [], [], [{"edge": "top", "from": 200.0, "to": 360.0, "room": "W2"}])
	a.cell = Vector2i(0, 1)
	var b := RoomDef.new()
	b.id = "W2"
	b.area = "flooded"
	b.cell = Vector2i(0, 0)
	b.size = Vector2i(1, 1)
	b.exits = [{"edge": "bottom", "from": 200.0, "to": 360.0, "room": "W1"}]  # a dry room above
	assert_eq(RoomLint.water_groups({"W1": a, "W2": b}), [])

func test_the_ceiling_and_walls_are_not_a_shore() -> void:
	var r := _room([Rect2(200, 20, 160, 300)])  # touches the ceiling band, no exit
	assert_true(_rules(r).has("water_exit"), "the ceiling's top (y 0) is inside the band but nothing stands on it")
```

Also in `tests/test_world_validator.gd` add:

```gdscript
func test_swim_is_a_gate_label() -> void:
	assert_true(WorldValidator.GATES.has("swim"))
```

- [ ] **Step 2: Run to confirm it fails.** `tools/run_tests.sh test_room_lint_water` → FAIL.

- [ ] **Step 3: Implement** in `room_lint.gd`:

Constants and rule names:

```gdscript
## How far above a water rect's top edge a swimmer's surface jump can put its feet (the apex less the body's reach below
## its centre, less 4 px of margin): a shore is a standable top within this much above the surface.
const SURFACE_LIFT := 44.0  # test_room_lint_water derives it: floor(JUMP_VELOCITY^2 / (2 GRAVITY) - BodyConfig.BOTTOM - 4)
const WATER_MIN := 32.0
const SHORE_REACH := 24.0
```

(A literal, not computed: `Player` is not safe to reference from a `RefCounted` static constant initializer in every load order, and the derivation test pins the literal.)

Add `"water_rect", "swimmer_dry", "water_exit"` to `RULES` and to `check_room`:

```gdscript
	out.append_array(_water_rect(r))
	out.append_array(_swimmer_dry(r))
	out.append_array(_water_exit(r))
```

Rule bodies and helpers:

```gdscript
static var _swimmers: Dictionary = {}

## Creature ids whose def is a `swimmer`, from the shipped defs (cached, like _hintable).
static func swimmer_ids() -> Dictionary:
	if _swimmers.is_empty():
		for c in DefLoader.load_dir("res://data/creatures"):
			_swimmers[c.id] = (c as CreatureDef).swimmer
	return _swimmers

static func _water_rect(r: RoomDef) -> Array:
	var out: Array = []
	var bounds := Rect2(Vector2.ZERO, r.pixel_size())
	for i in r.water.size():
		var w: Rect2 = r.water[i]
		if not bounds.encloses(w):
			out.append(_f(r, "water_rect", "the water at %s is outside the room" % _rect_text(w)))
		elif w.size.x < WATER_MIN or w.size.y < WATER_MIN:
			out.append(_f(r, "water_rect", "the water at %s is under %d px either way" % [_rect_text(w), int(WATER_MIN)]))
		for j in range(i + 1, r.water.size()):
			if w.intersects(r.water[j], true):
				out.append(_f(r, "water_rect", "the water at %s overlaps or touches the water at %s" % [_rect_text(w), _rect_text(r.water[j])]))
	return out

static func _swimmer_dry(r: RoomDef) -> Array:
	var out: Array = []
	for i in r.spawns.size():
		var s: Dictionary = r.spawns[i]
		if not bool(swimmer_ids().get(s["id"], false)):
			continue
		var wet := false
		for w in r.water:
			if (w as Rect2).has_point(s["pos"]):
				wet = true
		if not wet:
			out.append(_f(r, "swimmer_dry", "%s at %s is not in any water" % [s["id"], s["pos"]], "spawn", i))
	return out

## True when `e` is a way out of the room for a swimmer: no shortcut (closed until opened) and no gate but swim.
static func _open_for_swimmer(e: Dictionary) -> bool:
	return not e.has("shortcut") and (not e.has("gate") or e["gate"] == "swim")

## True when `rect` reaches the room edge of exit `e` over the exit's span.
static func reaches_edge(r: RoomDef, rect: Rect2, e: Dictionary) -> bool:
	var size := r.pixel_size()
	var a := float(e["from"])
	var b := float(e["to"])
	match e["edge"]:
		"top": return rect.position.y <= RoomDef.WALL + 0.5 and rect.end.x > a and rect.position.x < b
		"bottom": return rect.end.y >= size.y - 0.5 and rect.end.x > a and rect.position.x < b
		"left": return rect.position.x <= RoomDef.WALL + 0.5 and rect.end.y > a and rect.position.y < b
		"right": return rect.end.x >= size.x - RoomDef.WALL - 0.5 and rect.end.y > a and rect.position.y < b
	return false

## The standable tops of a room: its interior solids and its floor pieces (the generated floor, cut at every exit gap). The
## ceiling and the side walls are not standable.
static func standable(r: RoomDef) -> Array:
	var out: Array = r.solids.duplicate()
	for w in RoomBuilder.edge_walls(r.pixel_size(), r.exits):
		if w["kind"] == "ground":
			out.append(w["rect"])
	return out

## True when a standable top lies near `rect`: within SHORE_REACH of its x-span, its top between SURFACE_LIFT above the rect's
## top edge and the body's reach (BodyConfig.BOTTOM) below it, so a body standing on it has its centre out of the water.
static func has_shore(r: RoomDef, rect: Rect2) -> bool:
	for s in standable(r):
		var rr: Rect2 = s
		if rr.end.x < rect.position.x - SHORE_REACH or rr.position.x > rect.end.x + SHORE_REACH:
			continue
		if rr.position.y >= rect.position.y - SURFACE_LIFT and rr.position.y <= rect.position.y + BodyConfig.BOTTOM:
			return true
	return false

static func _water_exit(r: RoomDef) -> Array:
	var out: Array = []
	for w in r.water:
		var rect: Rect2 = w
		var escapes := false
		for e in r.exits:
			if _open_for_swimmer(e) and reaches_edge(r, rect, e):
				escapes = true
		if not escapes and not has_shore(r, rect):
			out.append(_f(r, "water_exit", "a swimmer in the water at %s cannot get out: no shore within reach of its surface and no open exit" % _rect_text(rect)))
	return out

## The authored-world check: water rects joined across open exit spans (a rect that reaches an exit's edge, and the partner
## room's rect that reaches the opposite edge over the same world span). A connected group is trapped when no member has a shore
## and no member leaves the water through an open exit that leads somewhere with no water at that span. One entry per trapped
## group: {rooms: [ids], text}.
static func water_groups(rooms: Dictionary) -> Array:
	var nodes: Array = []  # {room, i}
	var index := {}
	for id in rooms:
		var r: RoomDef = rooms[id]
		for i in r.water.size():
			index["%s:%d" % [id, i]] = nodes.size()
			nodes.append({"room": id, "i": i})
	var parent: Array = range(nodes.size())
	var leaves: Array = []
	leaves.resize(nodes.size())
	leaves.fill(false)
	var find := func(x: int) -> int:
		while parent[x] != x:
			parent[x] = parent[parent[x]]
			x = parent[x]
		return x
	for id in rooms:
		var r: RoomDef = rooms[id]
		for e in r.exits:
			if not _open_for_swimmer(e) or not rooms.has(e.get("room", "")):
				continue
			var b: RoomDef = rooms[e["room"]]
			var span := WorldValidator.world_span(r, e)
			for i in r.water.size():
				if not reaches_edge(r, r.water[i], e):
					continue
				var joined := false
				for f in b.exits:
					if f.get("room", "") != id or f["edge"] != WorldValidator.OPPOSITE[e["edge"]]:
						continue
					if not WorldValidator.world_span(b, f).is_equal_approx(span):
						continue
					for j in b.water.size():
						if reaches_edge(b, b.water[j], f):
							joined = true
							var x: int = find.call(index["%s:%d" % [id, i]])
							var y: int = find.call(index["%s:%d" % [e["room"], j]])
							parent[x] = y
				if not joined:
					leaves[index["%s:%d" % [id, i]]] = true
	var groups := {}
	for k in nodes.size():
		var root: int = find.call(k)
		if not groups.has(root):
			groups[root] = []
		groups[root].append(k)
	var out: Array = []
	for root in groups:
		var safe := false
		for k in groups[root]:
			var m: Dictionary = nodes[k]
			var rr: RoomDef = rooms[m["room"]]
			if leaves[k] or has_shore(rr, rr.water[m["i"]]):
				safe = true
		if not safe:
			out.append({"rooms": groups[root].map(func(k): return nodes[k]["room"]), "text": "a swimmer in this connected water has no shore and no way out"})
	return out
```

`world_validator.gd`: `const GATES := ["wall_cling", "swim"]`. `docs/rooms.md`: change "(today `wall_cling`)" to "(today `wall_cling` and `swim`)" and note that G4 is no longer the last room (the rest of that row is edited in Task 12); update `tests/test_room_lint.gd`'s rules-count pin from 13 to 16 and `tests/support/shipped_rooms.gd`'s docstring counts ("RoomLint's sixteen").

- [ ] **Step 4: Run** `tools/run_tests.sh test_room_lint_water`, `test_room_lint`, `test_world_validator` → PASS. Mutation checks (one each): make `_open_for_swimmer` ignore `shortcut` → the shortcut test fails; widen the band's lower bound to 30 → `test_a_ledge_too_high_above_or_too_deep_inside_is_no_shore` fails; make `water_rect` use `intersects(w)` without `true` → the touching test fails.

- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat: water lint (rect, swimmer_dry, exit), the world's shore check and the swim gate label"`

---

### Task 6: `DeepWater` and the builder

**Files:** Create `scripts/world/deep_water.gd`; Modify `scripts/world/room_builder.gd`; Create `tests/test_deep_water.gd`.

**Interfaces:** Produces `DeepWater` (a `Node2D` in group `deep_water`): `DeepWater.make(local_rect: Rect2) -> DeepWater`, `world_rect() -> Rect2`, `static at(tree: SceneTree, world_point: Vector2) -> DeepWater` (the node or null), and the builder adds one per `RoomDef.water` rect.

- [ ] **Step 1: Write the failing test** `tests/test_deep_water.gd`:

```gdscript
extends GutTest

func test_make_positions_the_node_and_joins_the_group() -> void:
	var w := DeepWater.make(Rect2(100, 200, 64, 48))
	add_child_autofree(w)
	assert_true(w.is_in_group("deep_water"))
	assert_eq(w.position, Vector2(100, 200))
	assert_eq(w.local_rect.size, Vector2(64, 48))

func test_at_finds_the_node_holding_a_world_point() -> void:
	var holder := Node2D.new()
	holder.position = Vector2(1000, 500)
	add_child_autofree(holder)
	var w := DeepWater.make(Rect2(100, 200, 64, 48))
	holder.add_child(w)
	assert_eq(w.world_rect(), Rect2(1100, 700, 64, 48), "a room node's position carries into the rect")
	assert_eq(DeepWater.at(get_tree(), Vector2(1120, 720)), w)
	assert_null(DeepWater.at(get_tree(), Vector2(1099, 720)), "just left of it")
	assert_null(DeepWater.at(get_tree(), Vector2(1120, 748)), "the bottom edge is outside")

func test_the_builder_adds_one_node_per_water_rect() -> void:
	var r := RoomDef.new()
	r.id = "W1"
	r.area = "flooded"
	r.cell = Vector2i(3, 2)
	r.size = Vector2i(1, 1)
	r.start = Vector2(60, 308)
	r.water = [Rect2(100, 200, 64, 48), Rect2(300, 220, 80, 60)]
	var node := RoomBuilder.build_room(r, {})
	add_child_autofree(node)
	var found: Array = node.get_children().filter(func(n): return n is DeepWater)
	assert_eq(found.size(), 2)
	assert_eq(found[0].world_rect(), Rect2(Vector2(3 * 640, 2 * 360) + Vector2(100, 200), Vector2(64, 48)))

func test_a_room_without_water_builds_none() -> void:
	var r := ShippedRooms.load_all()["C1"]
	var node := RoomBuilder.build_room(r, {})
	add_child_autofree(node)
	assert_eq(node.get_children().filter(func(n): return n is DeepWater).size(), 0)
```

- [ ] **Step 2: Run to confirm it fails.** `tools/run_tests.sh test_deep_water` → FAIL.

- [ ] **Step 3: Implement** `scripts/world/deep_water.gd`:

```gdscript
class_name DeepWater
extends Node2D
## One deep-water rect of a room: the volume swimming is measured against (PlayerWater, the swimmers' confinement) and its
## drawing: a translucent tint, a lighter surface line and a few bubbles rising. Solids draw in front of it.

const TINT := Color(0.25, 0.55, 0.85, 0.30)
const SURFACE := Color(0.75, 0.92, 1.0, 0.75)
const BUBBLE := Color(0.85, 0.95, 1.0, 0.6)

var local_rect := Rect2()
var _t := 0.0

static func make(rect: Rect2) -> DeepWater:
	var w := DeepWater.new()
	w.local_rect = Rect2(Vector2.ZERO, rect.size)
	w.position = rect.position
	w.add_to_group("deep_water")
	return w

func world_rect() -> Rect2:
	return Rect2(global_position, local_rect.size)

## The deep water holding `world_point` (the body centre), or null.
static func at(tree: SceneTree, world_point: Vector2) -> DeepWater:
	for n in tree.get_nodes_in_group("deep_water"):
		if (n as DeepWater).world_rect().has_point(world_point):
			return n
	return null

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(local_rect, TINT)
	var wave := sin(_t * 2.0) * 1.0
	draw_line(Vector2(0.0, wave), Vector2(local_rect.size.x, -wave), SURFACE, 1.5)
	for i in 5:
		var x := fposmod(float(i) * 37.0 + 11.0, local_rect.size.x)
		var rise := fposmod(_t * 14.0 + float(i) * 23.0, local_rect.size.y)
		draw_circle(Vector2(x, local_rect.size.y - rise), 1.2, BUBBLE)
```

`room_builder.gd` `build_room`: after the background (`TerrainLayers.simple_background` / `_backdrop`) and before the solids loop:

```gdscript
	for w in def.water:
		node.add_child(DeepWater.make(w))
```

- [ ] **Step 4: Import and run.** `env HOME="$PWD/.tmp/gdhome" godot --headless --import`, then `tools/run_tests.sh test_deep_water` and `tools/run_tests.sh test_room_builder` → PASS. Mutation check: build the node without `add_to_group` → `test_at_finds...` fails.

- [ ] **Step 5: Commit** (including `scripts/world/deep_water.gd.uid` and `tests/test_deep_water.gd.uid`). `git add -A && git commit -m "feat: DeepWater, the node a room's water rects build"`

---

### Task 7: `PlayerWater`

**Files:** Create `scripts/player/player_water.gd`, `tests/test_player_water.gd`.

**Interfaces:** Produces `PlayerWater` (a `RefCounted`). Constants: `WATER_GRAVITY` 0.35, `BOB_VELOCITY` 160.0, `SINK_CAP` 60.0, `WALK_SCALE` 0.6, `SURFACE_REACH` 24.0, `SUBMERGED_SECONDS` 1.0. State: `in_water: bool`, `rect: Rect2` (world; zero when dry), `ballistic: bool`. Calls: `step(tree, centre, delta) -> Dictionary` (`{"entered": bool, "exited": bool, "submerged": int}`), `adjust(velocity, grounded, swims, dir, swim_speed, boost, dashing, entered, delta) -> Vector2` (the frame's velocity in water), `jump(velocity, grounded, swims, boost, centre) -> Variant` (a new `Vector2` velocity when the press does something in water, else `null`), `reset()`, and static `bob_apex(jump_height_pct: float) -> float`.

- [ ] **Step 1: Write the failing test** `tests/test_player_water.gd` (pure unit tests, no physics):

```gdscript
extends GutTest

var water: PlayerWater
var pool: DeepWater

func before_each() -> void:
	water = PlayerWater.new()
	pool = DeepWater.make(Rect2(0, 0, 200, 200))
	add_child_autofree(pool)

func test_the_edges_and_the_clock() -> void:
	var out := water.step(get_tree(), Vector2(500, 500), 0.5)
	assert_false(out["entered"] or out["exited"])
	assert_false(water.in_water)
	out = water.step(get_tree(), Vector2(100, 100), 0.5)
	assert_true(out["entered"])
	assert_true(water.in_water)
	assert_eq(water.rect, Rect2(0, 0, 200, 200))
	assert_eq(out["submerged"], 0)
	out = water.step(get_tree(), Vector2(100, 100), 0.5)
	assert_eq(out["submerged"], 1, "once a second")
	out = water.step(get_tree(), Vector2(100, 100), 2.0)
	assert_eq(out["submerged"], 2)
	out = water.step(get_tree(), Vector2(500, 500), 0.1)
	assert_true(out["exited"])
	assert_eq(out["submerged"], 0, "nothing counts out of water")

func test_a_non_swimmer_walks_slow_floats_and_sinks_no_faster_than_the_cap() -> void:
	water.step(get_tree(), Vector2(100, 100), 0.016)
	var v := water.adjust(Vector2(140, 900), false, false, Vector2.ZERO, 120.0, 1.0, false, false, 1.0 / 60.0)
	assert_almost_eq(v.x, 140.0 * PlayerWater.WALK_SCALE, 0.001)
	assert_eq(v.y, PlayerWater.SINK_CAP, "a fall is capped at the sink speed")

func test_gravity_in_water_is_a_third_of_ordinary() -> void:
	water.step(get_tree(), Vector2(100, 100), 0.016)
	var v := water.adjust(Vector2.ZERO, false, false, Vector2.ZERO, 120.0, 1.0, false, false, 1.0)
	assert_almost_eq(v.y, minf(900.0 * PlayerWater.WATER_GRAVITY, PlayerWater.SINK_CAP), 0.001)

func test_the_entry_edge_caps_a_dry_jump_at_the_bob() -> void:
	water.step(get_tree(), Vector2(500, 500), 0.016)
	water.step(get_tree(), Vector2(100, 100), 0.016)  # entered
	var v := water.adjust(Vector2(0, -330), false, false, Vector2.ZERO, 120.0, 1.0, false, true, 0.0)
	assert_almost_eq(v.y, -PlayerWater.BOB_VELOCITY, 0.001, "a base jump rises no faster than the bob")
	var boosted := water.adjust(Vector2(0, -330 * 1.36), false, false, Vector2.ZERO, 120.0, 1.36, false, true, 0.0)
	assert_almost_eq(boosted.y, -PlayerWater.BOB_VELOCITY * 1.36, 0.001, "the bob is boosted like a jump")

func test_the_cap_applies_only_on_entry_and_never_to_a_swimmer() -> void:
	water.step(get_tree(), Vector2(100, 100), 0.016)
	var v := water.adjust(Vector2(0, -400), false, false, Vector2.ZERO, 120.0, 1.0, false, false, 0.0)
	assert_lt(v.y, -PlayerWater.BOB_VELOCITY, "Hydraulic Propulsion mid-water is not capped")
	var swimmer := water.adjust(Vector2(0, -330), false, true, Vector2.ZERO, 120.0, 1.0, false, true, 0.0)
	assert_eq(swimmer, Vector2.ZERO, "a swimmer's velocity comes from the input, never the cap")

func test_a_swimmer_moves_eight_way_at_its_speed_with_no_gravity() -> void:
	water.step(get_tree(), Vector2(100, 100), 0.016)
	var v := water.adjust(Vector2(0, 50), false, true, Vector2(1, -1).normalized(), 150.0, 1.0, false, false, 1.0 / 60.0)
	assert_almost_eq(v.length(), 150.0, 0.01)
	assert_gt(v.x, 0.0)
	assert_lt(v.y, 0.0)
	var still := water.adjust(Vector2(0, 50), false, true, Vector2.ZERO, 150.0, 1.0, false, false, 1.0 / 60.0)
	assert_eq(still, Vector2.ZERO, "no gravity: it hangs where it is")

func test_a_dashing_swimmer_keeps_its_impulse_and_slows_it() -> void:
	water.step(get_tree(), Vector2(100, 100), 0.016)
	var v := water.adjust(Vector2(300, 0), false, true, Vector2(-1, 0), 150.0, 1.0, true, false, 1.0 / 60.0)
	assert_gt(v.x, 0.0, "input is ignored while a hit or a tackle lock runs")
	assert_lt(v.x, 300.0, "water drags it")

func test_a_bob_only_from_the_floor() -> void:
	water.step(get_tree(), Vector2(100, 100), 0.016)
	var bob = water.jump(Vector2.ZERO, true, false, 1.0, Vector2(100, 100))
	assert_almost_eq((bob as Vector2).y, -PlayerWater.BOB_VELOCITY, 0.001)
	assert_null(water.jump(Vector2.ZERO, false, false, 1.0, Vector2(100, 100)), "no mid-water jump")
	var boosted = water.jump(Vector2.ZERO, true, false, 1.44, Vector2(100, 100))
	assert_almost_eq((boosted as Vector2).y, -PlayerWater.BOB_VELOCITY * 1.44, 0.001)

func test_a_swimmer_launches_from_within_the_surface_reach_only() -> void:
	water.step(get_tree(), Vector2(100, 10), 0.016)  # 10 below the top edge
	var up = water.jump(Vector2.ZERO, false, true, 1.0, Vector2(100, 10))
	assert_almost_eq((up as Vector2).y, -330.0, 0.001, "the normal jump velocity")
	assert_true(water.ballistic)
	water.reset()
	water.step(get_tree(), Vector2(100, 100), 0.016)  # 100 below
	assert_null(water.jump(Vector2.ZERO, false, true, 1.0, Vector2(100, 100)))

func test_a_ballistic_launch_ignores_input_until_the_centre_leaves_the_rect() -> void:
	water.step(get_tree(), Vector2(100, 10), 0.016)
	water.jump(Vector2.ZERO, false, true, 1.0, Vector2(100, 10))
	var v := water.adjust(Vector2(0, -330), false, true, Vector2(1, 0), 150.0, 1.0, false, false, 1.0 / 60.0)
	assert_eq(v, Vector2(0, -330), "the launch is not overwritten by the next frame's input")
	water.step(get_tree(), Vector2(100, -5), 0.016)  # out of the rect
	assert_false(water.ballistic)

func test_reset_forgets_the_water() -> void:
	water.step(get_tree(), Vector2(100, 100), 0.016)
	water.reset()
	assert_false(water.in_water)

func test_a_room_change_does_not_fire_an_exit_and_enter_pair() -> void:
	water.step(get_tree(), Vector2(100, 100), 0.016)
	pool.queue_free()
	var next := DeepWater.make(Rect2(0, 0, 200, 200))  # the next room's water covers the same point
	add_child_autofree(next)
	await get_tree().process_frame
	var out := water.step(get_tree(), Vector2(100, 100), 0.016)
	assert_false(out["exited"] or out["entered"], "the state carries across")

func test_the_bob_apex_is_the_spec_number() -> void:
	assert_almost_eq(PlayerWater.bob_apex(185.0), 75.2, 0.05)
	assert_almost_eq(PlayerWater.bob_apex(155.0), 63.0, 0.05)
```

- [ ] **Step 2: Run to confirm it fails.** `tools/run_tests.sh test_player_water` → FAIL (class missing).

- [ ] **Step 3: Implement** `scripts/player/player_water.gd`:

```gdscript
class_name PlayerWater
extends RefCounted
## The player's water model: whether the body centre is in a DeepWater, the once-a-second `submerged` clock, the entry and
## exit edges, and the frame's velocity in water. Pure of Input and of the physics body: player.gd passes what it knows.
##   Without Swim: slow (x0.6), a third of the gravity, a sink cap, a bob (not a jump) from the floor, and upward speed
##   carried in from a dry jump is capped at the bob on the entry edge.
##   With Swim: no gravity, 8-way at the swim speed, and a surface jump that stays ballistic until the centre leaves the rect.

const WATER_GRAVITY := 0.35
const BOB_VELOCITY := 160.0
const SINK_CAP := 60.0
const WALK_SCALE := 0.6
const SURFACE_REACH := 24.0
const SUBMERGED_SECONDS := 1.0
const DRAG := 600.0

var in_water := false
var rect := Rect2()
var ballistic := false
var _clock := 0.0

## The bob's apex in px for a jump height in percent (the gate test's B): the bob velocity boosted like a jump, rising at the
## water's gravity.
static func bob_apex(jump_height_pct: float) -> float:
	return BOB_VELOCITY * BOB_VELOCITY * (jump_height_pct / 100.0) / (2.0 * 900.0 * WATER_GRAVITY)

func reset() -> void:
	in_water = false
	rect = Rect2()
	ballistic = false
	_clock = 0.0

## One physics step: where the centre is, the edges, and how many whole seconds passed in water.
func step(tree: SceneTree, centre: Vector2, delta: float) -> Dictionary:
	var node := DeepWater.at(tree, centre)
	var was := in_water
	in_water = node != null
	rect = node.world_rect() if node != null else Rect2()
	var out := {"entered": in_water and not was, "exited": was and not in_water, "submerged": 0}
	if not in_water:
		ballistic = false
		return out
	_clock += delta
	while _clock >= SUBMERGED_SECONDS:
		_clock -= SUBMERGED_SECONDS
		out["submerged"] += 1
	return out

## The frame's velocity. `velocity` is what player.gd computed dry (walk speed already in x, gravity added); this replaces
## it with the water's version. `dir` is the steering vector (a swimmer's input), `dashing` whether a hit, tackle or shock
## lock owns the body, `entered` the entry edge this frame.
func adjust(velocity: Vector2, grounded: bool, swims: bool, dir: Vector2, swim_speed: float, boost: float, dashing: bool,
		entered: bool, delta: float) -> Vector2:
	if not in_water:
		return velocity
	if swims:
		if ballistic:
			return velocity
		if dashing:
			return velocity.move_toward(Vector2.ZERO, DRAG * delta)
		return dir * swim_speed
	var v := velocity
	if not dashing:
		v.x *= WALK_SCALE
	if entered:
		v.y = maxf(v.y, -BOB_VELOCITY * boost)
	# the dry gravity player.gd added this frame is replaced by the water's: undo it and add the third
	if not grounded:
		v.y += 900.0 * delta * (WATER_GRAVITY - 1.0)
	v.y = minf(v.y, SINK_CAP)
	return v

## What a Jump press does in water: a new velocity, or null when it does nothing here.
func jump(velocity: Vector2, grounded: bool, swims: bool, boost: float, centre: Vector2) -> Variant:
	if not in_water:
		return null
	if swims:
		if centre.y - rect.position.y <= SURFACE_REACH:
			ballistic = true
			return Vector2(velocity.x, -330.0 * boost)
		return null
	if grounded:
		return Vector2(velocity.x, -BOB_VELOCITY * boost)
	return null
```

Notes: `adjust` is applied after player.gd's own gravity line, so the non-swimmer branch subtracts the excess gravity (the tests that call it with `delta = 0.0` see no correction). Use `Player.JUMP_VELOCITY` for the `-330.0` in `jump` (a `RefCounted` may reference `Player` in a function body).

- [ ] **Step 4: Import and run.** `env HOME="$PWD/.tmp/gdhome" godot --headless --import`, `tools/run_tests.sh test_player_water` → PASS. Mutation checks: drop the `entered` cap → `test_the_entry_edge...` fails; make the swimmer's ballistic branch fall through → `test_a_ballistic_launch...` fails; set `SURFACE_REACH` to 200 → `...within the surface reach only` fails.

- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat: PlayerWater, the player's water model"`

---

### Task 8: The player in water

**Files:** Modify `scripts/player/player.gd`, `tests/test_audio_boundary.gd`; Create `tests/test_player_in_water.gd`.

**Interfaces:** Consumes `PlayerWater` (Task 7), `Events.SUBMERGED` (Task 1), the `swim` skill (Task 2). Produces the water step in `_physics_process`, the water arms in `do_jump`, the `submerged` emission, the audio events `water_entered` / `water_exited`, `PlayerWater.reset()` on a new life, and the shock lock in `receive_hit`. `test_audio_boundary`'s `reserved` list drops the two water events.

- [ ] **Step 1: Read** `scripts/player/player.gd` lines 144–205 (`_physics_process`), 307–327 (`do_jump`), 726–737 (`receive_hit`) and `_on_run_started`. The edits below are anchored to those.

- [ ] **Step 2: Write the failing test** `tests/test_player_in_water.gd`, built on `tests/test_player.gd`'s setup (rules, compendium, `Player.new()`), plus a floor and a pool:

```gdscript
extends GutTest
## The player in water, through the real physics: the modifiers, the bob, the swim, the entry cap, the shock lock and the events.

var rules: SkillRulesEngine
var compendium: CompendiumModel
var player: Player
var events: Array

func before_each() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	var creature_list := DefLoader.load_dir("res://data/creatures")
	rules = autofree(SkillRulesEngine.new())
	rules.report_error = func(msg: String) -> void: fail_test(msg)
	rules.setup(skills)
	compendium = CompendiumModel.new(skills, creature_list)
	CoreWiring.connect_core(rules, compendium, AnnouncerQueue.new())
	events = []
	player = Player.new()
	player.setup(rules, compendium, creature_list, func(n: String, t: Dictionary) -> void:
		events.append([n, t])
		rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()

func _floor(y := 100.0) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(0, y + 10.0)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(2000, 20)
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)

func _pool(rect: Rect2) -> DeepWater:
	var w := DeepWater.make(rect)
	add_child_autofree(w)
	return w

func _names() -> Array:
	return events.map(func(e): return e[0])

## Grants skills the way a rebirth kit does: quietly, after start_run.
func _give(skill_ids: Array) -> void:
	RebirthKit.apply(player, rules, compendium, {"skills": skill_ids})

func test_submerged_is_emitted_once_a_second_and_only_in_water() -> void:
	_floor()
	_pool(Rect2(-100, -200, 200, 300))
	player.global_position = Vector2(0, 80)
	await wait_physics_frames(130)
	assert_gte(_names().count("submerged"), 2)
	assert_lte(_names().count("submerged"), 3)
	events.clear()
	player.global_position = Vector2(900, 80)
	await wait_physics_frames(120)
	assert_eq(_names().count("submerged"), 0)

func test_entering_and_leaving_water_emit_the_audio_events() -> void:
	_floor()
	_pool(Rect2(-100, -200, 200, 300))
	var seen: Array = []
	var f := func(n: String, _t: Dictionary) -> void: seen.append(n)
	EventBus.world_event.connect(f)
	player.global_position = Vector2(900, 80)
	await wait_physics_frames(3)
	player.global_position = Vector2(0, 80)
	await wait_physics_frames(3)
	player.global_position = Vector2(900, 80)
	await wait_physics_frames(3)
	EventBus.world_event.disconnect(f)
	assert_eq(seen.filter(func(n): return n.begins_with("water_")), ["water_entered", "water_exited"])

func test_a_non_swimmer_in_water_walks_at_sixty_percent() -> void:
	_floor()
	_pool(Rect2(-300, -200, 600, 300))
	player.global_position = Vector2(0, 80)
	await wait_physics_frames(10)
	Input.action_press("move_right")
	await wait_physics_frames(10)
	var v := player.velocity.x
	Input.action_release("move_right")
	assert_almost_eq(v, Player.SPEED * 0.6, 2.0)

func test_a_jump_from_the_floor_in_water_is_a_bob() -> void:
	_floor()
	_pool(Rect2(-300, -200, 600, 300))
	player.global_position = Vector2(0, 80)
	await wait_physics_frames(15)
	assert_true(player.is_on_floor())
	player.do_jump()
	assert_almost_eq(player.velocity.y, -PlayerWater.BOB_VELOCITY, 0.5)

func test_no_wall_bob_in_water_without_swim() -> void:
	# Wall Cling's wall jump is a dry-land move: in water a wall gives a non-swimmer nothing
	_give(["wall_cling"])
	_pool(Rect2(-300, -300, 600, 600))
	var wall := StaticBody2D.new()
	wall.position = Vector2(30, 0)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(10, 400)
	shape.shape = box
	wall.add_child(shape)
	add_child_autofree(wall)
	player.global_position = Vector2(0, 0)
	Input.action_press("move_right")
	await wait_physics_frames(40)
	Input.action_release("move_right")
	assert_true(player.is_on_wall(), "pressed against the wall")
	player.do_jump()
	assert_gt(player.velocity.y, -1.0, "no upward velocity: a wall gives no bob")

func test_a_dry_jump_carried_into_water_is_capped_at_the_bob() -> void:
	_pool(Rect2(-300, -400, 600, 300))  # water above the origin
	player.global_position = Vector2(0, 0)  # dry, just under the pool
	await wait_physics_frames(1)
	player.global_position = Vector2(0, -200)  # inside the water: the next frame is the entry edge
	player.velocity = Vector2(0, -330)
	await wait_physics_frames(1)
	assert_gte(player.velocity.y, -PlayerWater.BOB_VELOCITY - 5.0, "the entry edge caps a dry jump's upward speed")

func test_hydraulic_propulsion_style_impulse_mid_water_is_not_capped() -> void:
	_pool(Rect2(-300, -600, 600, 900))
	player.global_position = Vector2(0, -200)
	await wait_physics_frames(3)  # already in water: no entry edge
	player.apply_impulse(Vector2(0, -380))
	await wait_physics_frames(1)
	assert_lt(player.velocity.y, -PlayerWater.BOB_VELOCITY - 20.0, "mid-water impulses keep their speed (the Grotto's traversal-skill rule)")

func test_a_swimmer_hangs_in_water_with_no_gravity() -> void:
	_give(["swim"])
	assert_true(player.skillset.has("swim"))
	_pool(Rect2(-300, -300, 600, 600))
	player.global_position = Vector2(0, 0)
	await wait_physics_frames(30)
	assert_almost_eq(player.global_position.y, 0.0, 1.0, "no gravity, no input: it hangs where it is")
	assert_eq(player.velocity, Vector2.ZERO)

func test_a_swimmer_swims_at_the_swim_speed_in_any_direction() -> void:
	_give(["swim"])
	_pool(Rect2(-300, -300, 600, 600))
	player.global_position = Vector2(0, 0)
	await wait_physics_frames(5)
	Input.action_press("move_right")
	Input.action_press("aim_up")
	await wait_physics_frames(10)
	var v := player.velocity
	Input.action_release("move_right")
	Input.action_release("aim_up")
	assert_gt(v.x, 0.0)
	assert_lt(v.y, 0.0)
	assert_almost_eq(v.length(), float(player.stats.get_stat("swim_speed")), 1.0)

func test_a_swimmer_leaves_through_the_surface_jump() -> void:
	_give(["swim"])
	_pool(Rect2(-300, 0, 600, 300))  # the surface is at y 0
	player.global_position = Vector2(0, 10)  # centre 10 below the top edge: inside the surface reach
	await wait_physics_frames(2)
	player.do_jump()
	assert_almost_eq(player.velocity.y, Player.JUMP_VELOCITY, 1.0, "the normal jump velocity")
	assert_true(player._water.ballistic)
	await wait_physics_frames(30)
	assert_false(player._water.in_water, "out of the rect")
	assert_false(player._water.ballistic, "ballistic ends with the water")
	assert_lt(player.global_position.y, 0.0)

func test_a_swimmer_deeper_than_the_surface_reach_cannot_jump_out() -> void:
	_give(["swim"])
	_pool(Rect2(-300, 0, 600, 300))
	player.global_position = Vector2(0, 100)
	await wait_physics_frames(2)
	player.do_jump()
	assert_gt(player.velocity.y, Player.JUMP_VELOCITY * 0.5)
	assert_false(player._water.ballistic)

func test_a_non_swimmers_swim_speed_stat_is_the_base_and_the_skill_raises_it() -> void:
	assert_eq(player.stats.get_stat("swim_speed"), 120)
	_give(["swim"])
	assert_eq(player.stats.get_stat("swim_speed"), 120, "level 1 adds 0")

func test_a_shock_hit_locks_input_for_at_least_the_shock_lock_after_the_knockback_block() -> void:
	player.receive_hit(2, "shock", Vector2(-10, 0))
	assert_gte(player._dash, Player.SHOCK_STUN - 0.001)
	player._dash = 0.0
	player._invuln = 0.0
	player.receive_hit(2, "physical", Vector2(-10, 0))
	assert_almost_eq(player._dash, 0.2, 0.001, "a physical hit keeps the knockback lock")

func test_a_shock_during_invulnerability_does_not_rearm_the_lock() -> void:
	player.receive_hit(2, "shock", Vector2(-10, 0))
	player._dash = 0.0  # the lock ran out
	player.receive_hit(2, "shock", Vector2(-10, 0))  # still invulnerable: refused
	assert_eq(player._dash, 0.0)

func test_a_new_life_forgets_the_water() -> void:
	_pool(Rect2(-100, -200, 200, 300))
	player.global_position = Vector2(0, 0)
	await wait_physics_frames(3)
	assert_true(player._water.in_water)
	rules.start_run()
	assert_false(player._water.in_water)
```

- [ ] **Step 3: Run to confirm it fails.** `tools/run_tests.sh test_player_in_water` → FAIL (`_water`, `SHOCK_STUN`). Note for the swim tests: `RebirthKit.apply` grants quietly after `start_run`; if `player.skillset.has("swim")` is false after it, read `RebirthKit.apply` and `PlayerSkillSet` and grant through whatever refresh the kit tests use.

- [ ] **Step 4: Implement** in `player.gd`:

Constants and state:

```gdscript
## A shock hit locks input this long (the same lock a hit's knockback uses, so it only adds the difference).
const SHOCK_STUN := 0.3
var _water := PlayerWater.new()
```

`_physics_process`: after `if _evolve_time > 0.0: ... return` and before `var dir := ...`, add

```gdscript
	var wet := _step_water(delta)
```

and after the gravity line (`if not is_on_floor(): velocity.y += GRAVITY * delta`) and the rope block, before the wall-slide line:

```gdscript
	if _water.in_water:
		var swims := skillset.has("swim")
		var steer := Input.get_vector("move_left", "move_right", "aim_up", "aim_down")
		velocity = _water.adjust(velocity, is_on_floor(), swims, steer, float(stats.get_stat("swim_speed")),
			sqrt(stats.get_stat("jump_height") / 100.0), _dash > 0.0, wet["entered"], delta)
```

(`wet` is the dictionary `_step_water` returns.) Replace the wall-slide condition with `... and not _water.in_water ...` so the slide does not apply in water. In the first `_dash` chain, the walk velocity is assigned before this; `adjust` scales it.

New helper:

```gdscript
## Steps the water model and emits what it saw: the audio edges and one `submerged` per second.
func _step_water(delta: float) -> Dictionary:
	var out := _water.step(get_tree(), global_position, delta)
	if out["entered"]:
		EventBus.world_event.emit("water_entered", {"pos": global_position})
	if out["exited"]:
		EventBus.world_event.emit("water_exited", {"pos": global_position})
	for i in int(out["submerged"]):
		_emit.call(Events.SUBMERGED, {})
	return out
```

`do_jump`: before the `if is_on_floor():` ground branch add

```gdscript
	if _water.in_water:
		var boost_w := sqrt(stats.get_stat("jump_height") / 100.0)
		var launched = _water.jump(velocity, is_on_floor(), skillset.has("swim"), boost_w, global_position)
		if launched != null:
			velocity = launched
			sensors.jumped("ground")
		return
```

(a jump press in water never falls through to the dry branches: no wall bob).

`receive_hit`: after the knockback block (the `if from != Vector2.INF and not health.is_dead():` block), add

```gdscript
	if damage_type == "shock" and not health.is_dead():
		_dash = maxf(_dash, SHOCK_STUN)
```

`_on_run_started`: add `_water.reset()`.

`tests/test_audio_boundary.gd` line ~51: remove `"water_entered"` and `"water_exited"` from the `reserved` list (they are emitted now).

- [ ] **Step 5: Run** `tools/run_tests.sh test_player_in_water`, `test_player`, `test_audio_boundary`, `test_audio_player_events` → PASS. Mutation checks: move the shock line before the knockback block → the shock-lock test fails; drop the `entered` argument → the entry-cap test fails; remove the `not _water.in_water` from the wall-slide line → (add a test if it survives) a wall-clinging non-swimmer in water slides at the dry slide speed.

- [ ] **Step 6: Commit.** `git add -A && git commit -m "feat: the player in water (slow, floaty, a bob, Swim) and the shock lock"`

---

### Task 9: Swimmers, contact type and the jelly

**Files:** Modify `scripts/enemies/enemy.gd`, `scripts/player/player.gd` (`_tackle_target`); Create `tests/test_flooded_creatures.gd`.

**Interfaces:** Consumes the flags (Task 1), the defs (Task 2) and `DeepWater` (Task 6). Produces: `_resolve_kind` sends a `swimmer` (not a drifter) to SWOOPER; the home water, its confinement and the same-rect alert; the `puffs` gate; the contact hit reading `def.contact_type`; the tackle skipping `untackleable`.

- [ ] **Step 1: Write the failing test** `tests/test_flooded_creatures.gd` (follow `tests/test_grotto_creatures.gd`'s stub player and helpers; the stub's `receive_hit` records `[raw, type]`):

```gdscript
extends GutTest
## The Flooded's swimmers: confined to their water, stalking and diving, shocking on contact; the jelly drifts without puffing
## and cannot be tackled.

class StubPlayer extends Node2D:
	var team := "player"
	var facing := 1
	var hits: Array = []
	func receive_hit(raw: int, damage_type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		hits.append([raw, damage_type])
	func receive_poison(_a: int, _t: int, _s: float) -> void:
		pass

var creatures := {}
var skills_by_id := {}
var fake_player: StubPlayer

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func before_each() -> void:
	fake_player = StubPlayer.new()
	add_child_autofree(fake_player)
	fake_player.add_to_group("player")

func _pool(rect: Rect2) -> DeepWater:
	var w := DeepWater.make(rect)
	add_child_autofree(w)
	return w

func _enemy(id: String, pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.use_sheet = false
	e.setup(creatures[id], skills_by_id)
	e.position = pos
	add_child_autofree(e)
	return e

func test_the_eels_are_swoopers_and_the_jelly_stays_a_drifter() -> void:
	_pool(Rect2(-100, -100, 200, 200))
	assert_eq(_enemy("glass_eel", Vector2.ZERO).kind, Enemy.Kind.SWOOPER)
	assert_eq(_enemy("drift_jelly", Vector2.ZERO).kind, Enemy.Kind.DRIFTER)
	assert_eq(_enemy("cave_crayfish", Vector2(50, 0)).kind, Enemy.Kind.CHARGER)
	assert_eq(_enemy("bog_lizardman", Vector2(-50, 0)).kind, Enemy.Kind.SPITTER)

func test_an_eel_stays_inside_its_water_rect() -> void:
	var rect := Rect2(-100, -100, 200, 120)
	_pool(rect)
	var eel := _enemy("glass_eel", Vector2(0, -40))
	fake_player.global_position = Vector2(400, -40)  # beyond the rect: the eel should not leave to chase
	await wait_physics_frames(120)
	assert_true(rect.grow(1.0).has_point(eel.global_position))
	eel.velocity = Vector2(900, 900)
	await wait_physics_frames(30)
	assert_true(rect.grow(1.0).has_point(eel.global_position), "a hard shove is clamped")

func test_an_eel_is_alerted_only_by_a_player_in_its_own_rect() -> void:
	var rect := Rect2(-100, -100, 200, 120)
	_pool(rect)
	var eel := _enemy("glass_eel", Vector2(0, -40))
	fake_player.global_position = Vector2(150, -40)  # in sight, near, but outside the rect
	await wait_physics_frames(10)
	assert_false(eel.is_alert())
	fake_player.global_position = Vector2(60, -40)
	await wait_physics_frames(10)
	assert_true(eel.is_alert())

func test_an_eel_telegraphs_then_dives_and_a_contact_is_a_shock_hit() -> void:
	var rect := Rect2(-200, -150, 400, 250)
	_pool(rect)
	var eel := _enemy("glass_eel", Vector2(-120, -40))
	fake_player.global_position = Vector2(0, -40)
	var saw_warn := false
	for i in 240:
		await wait_physics_frames(1)
		if eel.swoop_state() == "warn":
			saw_warn = true
			assert_true(eel.telegraphing())
		if not fake_player.hits.is_empty():
			break
	assert_true(saw_warn, "it flashes before it dives")
	assert_false(fake_player.hits.is_empty(), "the dive reached the player")
	assert_eq(fake_player.hits[0][1], "shock")

func test_a_stunned_eel_sinks_to_the_bottom_of_its_rect_and_stays() -> void:
	var rect := Rect2(-100, -100, 200, 120)
	_pool(rect)
	var eel := _enemy("glass_eel", Vector2(0, -40))
	eel.status.stun()
	await wait_physics_frames(120)
	assert_almost_eq(eel.global_position.y, rect.end.y - 6.0, 2.0, "held at the bottom by the clamp")
	assert_eq(eel.velocity.y, 0.0, "the clamp zeroes the fall instead of letting it grow")

func test_a_swimmer_with_no_water_idles() -> void:
	var eel := _enemy("glass_eel", Vector2(0, 0))
	fake_player.global_position = Vector2(40, 0)
	await wait_physics_frames(30)
	assert_eq(eel.velocity, Vector2.ZERO)

func test_a_spawn_on_the_rect_edge_is_inside_after_the_first_frame() -> void:
	var rect := Rect2(-100, -100, 200, 120)
	_pool(rect)
	var eel := _enemy("glass_eel", Vector2(100, -100))  # exactly on the corner
	await wait_physics_frames(3)
	assert_true(rect.has_point(eel.global_position))

func test_a_jelly_drifts_inside_a_narrow_rect_and_turns_at_the_wall() -> void:
	var rect := Rect2(-60, -100, 120, 100)  # narrower than the drifter's own +-96 loop
	_pool(rect)
	var jelly := _enemy("drift_jelly", Vector2(0, -50))
	var lo := INF
	var hi := -INF
	for i in 400:
		await wait_physics_frames(1)
		lo = minf(lo, jelly.global_position.x)
		hi = maxf(hi, jelly.global_position.x)
	assert_true(rect.has_point(jelly.global_position))
	assert_gt(hi - lo, 20.0, "it kept moving instead of pinning itself to one wall")

func test_a_jelly_never_drops_a_puff_and_a_moth_still_does() -> void:
	_pool(Rect2(-200, -200, 400, 300))
	var jelly := _enemy("drift_jelly", Vector2(0, -60))
	fake_player.global_position = Vector2(60, -60)
	await wait_physics_frames(int((Enemy.PUFF_INTERVAL + 1.0) * 60.0))
	assert_eq(get_tree().get_nodes_in_group("hazards").filter(func(n): return n is SporePuff).size(), 0)
	assert_false(jelly.telegraphing())

func test_a_jelly_is_skipped_by_a_tackle_and_never_swallows_one_aimed_beyond_it() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	var creature_list := DefLoader.load_dir("res://data/creatures")
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	var compendium := CompendiumModel.new(skills, creature_list)
	var player := Player.new()
	player.setup(rules, compendium, creature_list, func(_n, _t): pass)
	add_child_autofree(player)
	rules.start_run()
	var jelly := _enemy("drift_jelly", Vector2(14, 0))
	jelly.set_physics_process(false)
	var bat := _enemy("bat", Vector2(30, 0))
	bat.set_physics_process(false)
	player.global_position = Vector2.ZERO
	assert_eq(player._tackle_target(), bat, "the jelly is not a target; the bat behind it is")

func test_contact_reads_the_creatures_damage_type() -> void:
	# a crayfish's contact is physical, an eel's is shock (the call sits at the end of Enemy._physics_process)
	_pool(Rect2(-100, -100, 200, 200))
	var eel := _enemy("glass_eel", Vector2(0, 0))
	fake_player.global_position = Vector2(2, 0)
	await wait_physics_frames(5)
	assert_eq(fake_player.hits[0][1], "shock")
```

- [ ] **Step 2: Run to confirm it fails.** `tools/run_tests.sh test_flooded_creatures` → FAIL.

- [ ] **Step 3: Implement** in `enemy.gd`:

State:

```gdscript
## The water rect a swimmer lives in, resolved on the first physics frame (a spawn's position and room are not set in setup).
var _home_water: DeepWater
var _water_resolved := false
```

`_resolve_kind`: replace `if capabilities.has("flight"):` with `if capabilities.has("flight") or def.swimmer:` (it sits after the drifter check, so the jelly stays a DRIFTER). The kind doc comment gains the swimmer.

`_physics_process`: before the `active and player != null` branch add

```gdscript
	if def.swimmer and not _water_resolved:
		_home_water = DeepWater.at(get_tree(), global_position)
		_water_resolved = true
```

and change the AI call to

```gdscript
	if active and player != null:
		_sense(player, delta)
		if def.swimmer and _home_water == null:
			velocity = Vector2.ZERO  # no water: nothing to swim in (lint's swimmer_dry reports it)
		else:
			_act(player, delta)
```

after `move_and_slide()` add `if def.swimmer and _home_water != null: _confine()`, and change the contact line to `player.receive_hit(stats.get_stat("atk"), def.contact_type, global_position)`.

`_confine`:

```gdscript
## Holds a swimmer inside its water rect (shrunk by its half body): the position is clamped, the clamped velocity component is
## zeroed (a stunned eel's fall does not keep growing against a rect bottom that is not floor) and facing turns inward, which the
## drifter turns on.
func _confine() -> void:
	var half := BODY_SIZE / 2.0
	var box := _home_water.world_rect()
	var lo := box.position + half
	var hi := box.end - half
	if hi.x < lo.x or hi.y < lo.y:
		global_position = box.get_center()
		return
	var p := global_position
	var c := Vector2(clampf(p.x, lo.x, hi.x), clampf(p.y, lo.y, hi.y))
	if c.x != p.x:
		velocity.x = 0.0
		facing = 1 if p.x < lo.x else -1
	if c.y != p.y:
		velocity.y = 0.0
	global_position = c
```

`_sense`: after computing the sight test:

```gdscript
func _sense(player: Node2D, delta: float) -> void:
	var sees := global_position.distance_to(player.global_position) < CHASE_RANGE and can_see(player)
	if sees and def.swimmer and _home_water != null and not _home_water.world_rect().has_point(player.global_position):
		sees = false  # an eel is stirred only by a player in its own water
	if sees:
		_alert = ALERT_MEMORY
	else:
		_alert = maxf(0.0, _alert - delta)
```

`_drift_act`: change the puff gate line to `if not def.puffs or to_player.length() > PUFF_RANGE or not can_see(player):  # no puffs through rock, and only the moths puff`.

`player.gd` `_tackle_target`: in the loop, after the `can_be_hit` check add

```gdscript
		var nd = n.get("def")
		if nd is CreatureDef and nd.untackleable:
			continue  # the jelly cannot be tackled, and must not swallow a tackle meant for a creature beyond it
```

Doc updates in `enemy.gd`: the header comment (`swimmer`), the `Kind` precedence comment ("...a ceiling walker, a drifter, a swimmer, a flier..."), and the `_state` token comment.

- [ ] **Step 4: Run** `tools/run_tests.sh test_flooded_creatures`, `test_enemy`, `test_enemy_kind` (rescope its "idle for a bat" assertion to "idle for a swooper"), `test_grotto_creatures`, `test_hit_fairness`, `test_enemy_trace` (the golden traces must not change) → PASS. Mutation checks: remove `_confine()` → the clamp test fails; drop the `def.puffs` gate → the puff test fails; drop the `untackleable` skip → the tackle test fails; drop the same-rect check → the alert test fails.

- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat: the swimmers (eels as swoopers, the jelly), confinement, contact type and the untackleable jelly"`

---

### Task 10: The Bog Lizardman's spear

**Files:** Modify `scripts/enemies/spit_blob.gd`, `scripts/enemies/enemy.gd`; Create `scripts/enemies/spear.gd`, `tests/test_spear.gd`.

**Interfaces:** Consumes `CreatureDef.projectile` and `bog_lizardman` (Tasks 1 and 2). Produces `SpitBlob` seams (a per-instance `gravity` member, `_hit(player)`, `_look()`), `Spear extends SpitBlob`, the SPITTER arm for `projectile == "spear"`, the named `SPEAR_*` constants, the cooldown-derived pose window and the no-chase walk.

- [ ] **Step 1: Write the failing test** `tests/test_spear.gd` (same stub player; add a floor/wall helper like `test_grotto_creatures`):

```gdscript
extends GutTest
## The Bog Lizardman holds its beat and throws a flat, physical spear on its own cooldown; the toad's glob is untouched.

class StubPlayer extends Node2D:
	var team := "player"
	var facing := 1
	var hits: Array = []
	var poisons: Array = []
	func receive_hit(raw: int, damage_type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		hits.append([raw, damage_type])
	func receive_poison(a: int, t: int, s: float) -> void:
		poisons.append([a, t, s])

var creatures := {}
var skills_by_id := {}
var fake_player: StubPlayer

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func before_each() -> void:
	fake_player = StubPlayer.new()
	add_child_autofree(fake_player)
	fake_player.add_to_group("player")

func _enemy(id: String, pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.use_sheet = false
	e.setup(creatures[id], skills_by_id)
	e.position = pos
	add_child_autofree(e)
	return e

func _solid(r: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = r.position + r.size / 2.0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = r.size
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)

func _floor() -> void:
	_solid(Rect2(-600, 6, 1200, 20))

func test_the_lizardman_is_a_spitter_with_no_poison_spit() -> void:
	var l := _enemy("bog_lizardman", Vector2.ZERO)
	assert_eq(l.kind, Enemy.Kind.SPITTER)

func test_a_spitblob_is_unchanged_a_toads_glob_arcs_and_poisons() -> void:
	var blob := SpitBlob.new()
	assert_eq(blob.gravity, SpitBlob.GRAVITY)
	add_child_autofree(blob)
	blob.launch(Vector2(0, 0), Vector2(100, 0), 3, 1, 3.0)
	fake_player.global_position = Vector2(100, 0)
	await wait_physics_frames(60)
	assert_false(fake_player.poisons.is_empty())

func test_the_windup_throw_and_cooldown_use_the_spear_constants() -> void:
	_floor()
	var l := _enemy("bog_lizardman", Vector2(0, 0))
	fake_player.global_position = Vector2(100, 0)  # in sight, level, inside SPEAR_RANGE (140) but outside the toad's 90
	var winding := false
	for i in 120:
		await wait_physics_frames(1)
		if l.telegraphing():
			winding = true
			break
	assert_true(winding, "it raises its spear first")
	await wait_physics_frames(int(Enemy.SPIT_WINDUP * 60.0) + 5)
	assert_eq(get_tree().get_nodes_in_group("hazards").filter(func(n): return n is Spear).size(), 1, "one spear in flight")
	assert_almost_eq(l._spit_cd, Enemy.SPEAR_COOLDOWN, 0.2)

func test_the_throw_pose_shows_after_the_throw_for_the_pose_window() -> void:
	_floor()
	var l := _enemy("bog_lizardman", Vector2(0, 0))
	l._spit_cd = Enemy.SPEAR_COOLDOWN
	assert_true(l._spit_cd > l._spit_cooldown() - Enemy.SPIT_POSE_SECONDS, "right after a throw")
	l._spit_cd = Enemy.SPEAR_COOLDOWN - Enemy.SPIT_POSE_SECONDS - 0.01
	assert_false(l._spit_cd > l._spit_cooldown() - Enemy.SPIT_POSE_SECONDS, "the pose ends with the window")

func test_it_does_not_throw_at_a_player_off_level_or_out_of_range() -> void:
	_floor()
	var l := _enemy("bog_lizardman", Vector2(0, 0))
	fake_player.global_position = Vector2(100, -60)  # 60 above: past SPEAR_LEVEL
	await wait_physics_frames(90)
	assert_eq(get_tree().get_nodes_in_group("hazards").filter(func(n): return n is Spear).size(), 0)
	fake_player.global_position = Vector2(300, 0)  # past SPEAR_RANGE
	await wait_physics_frames(90)
	assert_eq(get_tree().get_nodes_in_group("hazards").filter(func(n): return n is Spear).size(), 0)

func test_the_spear_flies_a_straight_aimed_line_and_hits_physical_for_the_creatures_atk() -> void:
	var spear := Spear.new()
	add_child_autofree(spear)
	spear.launch(Vector2(0, 0), Vector2(100, -30), 3, 0, 0.0)
	assert_eq(spear.gravity, 0.0)
	var dir := (Vector2(100, -30)).normalized()
	assert_almost_eq(spear.velocity.normalized().x, dir.x, 0.001)
	assert_almost_eq(spear.velocity.length(), Spear.SPEED, 0.01)
	fake_player.global_position = Vector2(100, -30)
	await wait_physics_frames(60)
	assert_eq(fake_player.hits, [[3, "physical"]])
	assert_true(fake_player.poisons.is_empty())

func test_the_spear_dies_on_rock() -> void:
	_solid(Rect2(40, -50, 20, 100))
	var spear := Spear.new()
	add_child_autofree(spear)
	spear.launch(Vector2(0, 0), Vector2(200, 0), 3, 0, 0.0)
	fake_player.global_position = Vector2(200, 0)
	await wait_physics_frames(60)
	assert_true(fake_player.hits.is_empty(), "the rock stopped it")
	assert_false(is_instance_valid(spear) and spear.is_inside_tree())

func test_an_alerted_lizardman_stands_still_facing_the_player_and_never_chases() -> void:
	_floor()
	var l := _enemy("bog_lizardman", Vector2(0, 0))
	l._spit_cd = 99.0  # on cooldown: _spitter_act returns false and _walk runs
	fake_player.global_position = Vector2(-100, 0)
	await wait_physics_frames(30)
	assert_eq(l.velocity.x, 0.0, "it holds its post while alerted")
	assert_eq(l.facing, -1, "and faces you")
	assert_almost_eq(l.global_position.x, 0.0, 0.5)

func test_an_unalerted_lizardman_patrols_its_beat() -> void:
	_floor()
	var l := _enemy("bog_lizardman", Vector2(0, 0))
	fake_player.global_position = Vector2(2000, 0)
	await wait_physics_frames(60)
	assert_ne(l.velocity.x, 0.0)
```

- [ ] **Step 2: Run to confirm it fails.** `tools/run_tests.sh test_spear` → FAIL.

- [ ] **Step 3: Implement.**

`spit_blob.gd`: seams, without changing the toad's behaviour:

```gdscript
## Falling acceleration of this projectile (a spear sets 0).
var gravity := GRAVITY
```

in `_physics_process` replace `velocity.y += GRAVITY * delta` with `velocity.y += gravity * delta` and replace the on-hit line with `_hit(player)`:

```gdscript
## What a hit does to the player: the toad's poison (a Spear overrides this).
func _hit(player: Node2D) -> void:
	player.receive_poison(_damage, _tick, _seconds)
```

and move the green-glob construction in `_ready` into `_look()` (called from `_ready` when `get_child_count() == 0`), so a spear draws its own.

`scripts/enemies/spear.gd`:

```gdscript
class_name Spear
extends SpitBlob
## The Bog Lizardman's spear: a straight, flat, fast line at where the player stood, a physical hit for the creature's ATK,
## stopped by rock (the blob's own test).

const SPEED := 220.0

func launch(from: Vector2, to: Vector2, damage: int, tick: int, seconds: float) -> void:
	global_position = from
	velocity = (to - from).normalized() * SPEED
	gravity = 0.0
	_damage = damage
	_tick = tick
	_seconds = seconds
	rotation = velocity.angle()
	add_to_group("hazards")

func _hit(player: Node2D) -> void:
	player.receive_hit(_damage, "physical", global_position)

func _look() -> void:
	var shaft := ColorRect.new()
	shaft.color = Color(0.62, 0.45, 0.25)
	shaft.size = Vector2(14, 2)
	shaft.position = Vector2(-7, -1)
	add_child(shaft)
	var tip := ColorRect.new()
	tip.color = Color(0.85, 0.88, 0.9)
	tip.size = Vector2(4, 2)
	tip.position = Vector2(7, -1)
	add_child(tip)
```

`enemy.gd`:

```gdscript
## The Bog Lizardman's spear: how far, how level, how often and how fast it throws (the toad's are SPIT_*).
const SPEAR_RANGE := 140.0
const SPEAR_LEVEL := 40.0
const SPEAR_COOLDOWN := 3.0
```

(`Spear.SPEED` carries the speed; the spec's `SPEAR_SPEED` is `Spear.SPEED`.) `_resolve_kind`: `if _spit_damage > 0 or def.projectile == "spear": return Kind.SPITTER`. Helpers and edits:

```gdscript
func _throws_spear() -> bool:
	return def.projectile == "spear"

## Seconds between a throw and the next: the spear's own, else the toad's.
func _spit_cooldown() -> float:
	return SPEAR_COOLDOWN if _throws_spear() else SPIT_COOLDOWN
```

`_spitter_act`: the throw branch becomes

```gdscript
			if _state_t <= 0.0:
				if _throws_spear():
					var spear := Spear.new()
					get_parent().add_child(spear)
					spear.launch(global_position + Vector2(facing * 8.0, -6.0), player.global_position, stats.get_stat("atk"), 0, 0.0)
				else:
					var blob := SpitBlob.new()
					get_parent().add_child(blob)
					blob.launch(global_position + Vector2(facing * 8.0, -6.0), player.global_position, _spit_damage, SPIT_TICK, SPIT_SECONDS)
				_spit_cd = _spit_cooldown()
				_state = ""
```

and the trigger becomes

```gdscript
	var reach := SPEAR_RANGE if _throws_spear() else SPIT_RANGE
	var level_ok := absf(to_player.y) <= SPEAR_LEVEL if _throws_spear() else true
	if is_alert() and _spit_cd <= 0.0 and to_player.length() < reach and level_ok:
```

`_draw_sheet_frame` and `frame_name`: replace `SPIT_COOLDOWN - SPIT_POSE_SECONDS` with `_spit_cooldown() - SPIT_POSE_SECONDS`. `_walk`: at the top, after `var speed := _speed()`:

```gdscript
	if def.projectile != "" and is_alert():
		velocity.x = 0.0  # a thrower holds its post, facing you
		if absf(to_player.x) > TURN_LOCK_RANGE:
			facing = 1 if to_player.x > 0.0 else -1
		return
```

- [ ] **Step 4: Import and run.** `env HOME="$PWD/.tmp/gdhome" godot --headless --import`, `tools/run_tests.sh test_spear`, `test_grotto_creatures`, `test_enemy` (the toad's glob), `test_enemy_trace` → PASS. Mutation checks: restore `SPIT_COOLDOWN` in the throw → the cooldown test fails; remove the no-chase block → the stands-still test fails; drop `level_ok` → the off-level test fails.

- [ ] **Step 5: Commit** (with the `.uid`s). `git add -A && git commit -m "feat: the Bog Lizardman's spear (a spitter with a straight, physical projectile)"`

---

### Task 11: Jolt

**Files:** Modify `scripts/abilities/ability.gd`, `scripts/enemies/enemy_status.gd`, `data/audio/cues.json`; Create `scripts/abilities/jolt.gd`, `scenes/abilities/jolt.tscn`, `tests/test_jolt.gd`.

**Interfaces:** Produces `Ability.targets_around(radius) -> Array`, `EnemyStatus.stun` keeping the longer timer, `Jolt` (an `Ability`), the scene `res://scenes/abilities/jolt.tscn` (the path `_active("jolt")` already references), and the `skill_used.jolt` cue.

- [ ] **Step 1: Write the failing test** `tests/test_jolt.gd`:

```gdscript
extends GutTest

class Caster extends Node2D:
	var team := "player"
	var facing := 1
	var stats := Stats.new({"atk": 1})
	var hits: Array = []
	func receive_hit(raw: int, damage_type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		hits.append([raw, damage_type])

var creatures := {}
var skills_by_id := {}

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func _caster() -> Caster:
	var c := Caster.new()
	add_child_autofree(c)
	c.add_to_group("actors")
	return c

func _enemy(id: String, pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.use_sheet = false
	e.setup(creatures[id], skills_by_id)
	add_child_autofree(e)
	e.global_position = pos
	e.set_physics_process(false)
	return e

func _jolt(caster: Node2D, level := 1) -> Ability:
	var j: Ability = load("res://scenes/abilities/jolt.tscn").instantiate()
	j.setup(caster, [3, 4, 5, 6, 7], level)
	add_child_autofree(j)
	return j

func test_a_stun_never_shortens_a_longer_one() -> void:
	var s := EnemyStatus.new()
	s.stun(3.0)
	s.stun(1.5)
	s.update(2.0)
	assert_eq(s.state, EnemyStatus.STUNNED, "still stunned: the 3 s stayed")
	var fresh := EnemyStatus.new()
	fresh.stun(1.5)
	assert_eq(fresh.state, EnemyStatus.STUNNED)
	fresh.update(1.6)
	assert_eq(fresh.state, EnemyStatus.ACTIVE)

func test_targets_around_is_radial_other_team_and_alive() -> void:
	var c := _caster()
	var near := _enemy("bat", Vector2(30, 0))
	var far := _enemy("bat", Vector2(90, 0))
	var downed := _enemy("bat", Vector2(10, 0))
	downed.receive_hit(99, "physical")
	var j := _jolt(c)
	var got := j.targets_around(40.0)
	assert_true(got.has(near))
	assert_false(got.has(far))
	assert_false(got.has(downed), "a corpse is not a target")
	assert_false(got.has(c), "never the caster")

func test_jolt_damages_everything_in_radius_with_shock_and_stuns_only_swimmers() -> void:
	var c := _caster()
	var eel := _enemy("glass_eel", Vector2(20, 0))
	var crayfish := _enemy("cave_crayfish", Vector2(-25, 0))
	var jelly := _enemy("drift_jelly", Vector2(0, 20))
	_jolt(c).activate()
	assert_eq(eel.status.state, EnemyStatus.STUNNED, "an eel is stunned")
	assert_ne(crayfish.status.state, EnemyStatus.STUNNED, "a crayfish is only hurt")
	assert_lt(crayfish.health.hp, crayfish.health.max_hp)
	assert_true(jelly.status.state == EnemyStatus.DOWNED or jelly.status.state == EnemyStatus.DYING, "3 damage downs a 3 HP jelly outright")

func test_jolt_never_hurts_the_caster() -> void:
	var c := _caster()
	_jolt(c).activate()
	assert_eq(c.hits, [])

func test_jolt_damage_follows_the_level() -> void:
	var c := _caster()
	var bat := _enemy("lizard", Vector2(10, 0))
	var before: int = bat.health.hp
	_jolt(c, 5).activate()
	assert_gt(before - bat.health.hp, 0)
```

- [ ] **Step 2: Run to confirm it fails.** `tools/run_tests.sh test_jolt` → FAIL.

- [ ] **Step 3: Implement.**

`enemy_status.gd` `stun`:

```gdscript
## Stuns for `seconds`; on a creature already stunned the longer timer stays (a short stun never shortens a long one).
func stun(seconds: float = STUN_SECONDS) -> void:
	if state == ACTIVE or state == STUNNED:
		_timer = seconds if state == ACTIVE else maxf(_timer, seconds)
		state = STUNNED
```

`ability.gd`: extract the filter and add the radial sibling:

```gdscript
## Every other-team actor that can be hit (a corpse must not shadow a living target), unsorted.
func _foes() -> Array:
	var out: Array = []
	for n in actor.get_tree().get_nodes_in_group("actors"):
		if n == actor or n.get("team") == actor.team or not n.has_method("receive_hit"):
			continue
		if n.has_method("can_be_hit") and not n.can_be_hit():
			continue
		out.append(n)
	return out

## Other-team actors within `radius` of the caster, nearest first.
func targets_around(radius: float) -> Array:
	var out: Array = _foes().filter(func(n): return actor.global_position.distance_to(n.global_position) <= radius)
	out.sort_custom(func(a, b): return actor.global_position.distance_to(a.global_position) < actor.global_position.distance_to(b.global_position))
	return out
```

and rewrite `targets_in_front` to iterate `_foes()` instead of its inline filter (same geometry, same ordering).

`scripts/abilities/jolt.gd`:

```gdscript
extends Ability
## A burst of shock around the caster: every enemy in range takes shock damage, and the swimmers (the eels and the jelly) are
## stunned. Never touches the caster.

const RADIUS := 40.0
const STUN_SECONDS := 1.5

func _perform() -> void:
	for t in targets_around(RADIUS):
		t.receive_hit(Damage.skill_power(value(), actor_atk()), "shock", actor.global_position)
		var d = t.get("def")
		if d is CreatureDef and d.swimmer and t.get("status") != null:
			t.status.stun(STUN_SECONDS)
	var spots: Array = []
	for i in 8:
		var a := TAU * float(i) / 8.0
		spots.append(actor.global_position + Vector2(cos(a), sin(a)) * RADIUS * 0.8)
	Vfx.puffs(actor, Art.texture("spit_glob"), spots, Color(0.6, 0.95, 1.0, 0.9), 0.3)
```

`scenes/abilities/jolt.tscn`: copy `poison_breath.tscn` with the script path `res://scripts/abilities/jolt.gd` and node name `Jolt`.

`cues.json`: add `"jolt": "<an existing cue>"` to `skill_used` (read how `poison_breath` maps and reuse a close existing cue such as the water blade's or poison breath's cue; a new sound is a later polish), satisfying `test_every_active_skill_has_its_own_cue`.

- [ ] **Step 4: Import and run.** `env HOME="$PWD/.tmp/gdhome" godot --headless --import`, `tools/run_tests.sh test_jolt`, `test_abilities`, `test_poison_breath`, `test_audio_catalog`, `test_player` → PASS. Mutation checks: make `stun` overwrite again → the first test fails; stun every creature (drop the `swimmer` check) → the crayfish assertion fails.

- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat: Jolt, targets_around and a stun that never shortens"`

---

### Task 12: Sheets, clips, `EnemyState` arms, portraits and icons

**Files:** Modify `data/enemy_clips.json`, `scripts/enemies/enemy_state.gd`, `scripts/ui/skill_screen.gd`, `tests/test_enemy_sheets.gd`, `tests/test_enemy_state.gd`, `tools/art/manifest.json`; Create the assembled `assets/sheets/{glass_eel,cave_crayfish,drift_jelly,bog_lizardman}.{png,json}`, `assets/sprites/icon_{swim,jolt}.png`.

**Interfaces:** Consumes the generated frames (Task 0, `art_source/frames/<set>/`). Produces sheets with traced shapes, clips per sheet, `EnemyState.pick` arms, portraits from sheet frames, the two icons.

- [ ] **Step 1: Confirm generation finished.** `ls art_source/frames/glass_eel art_source/frames/cave_crayfish art_source/frames/drift_jelly art_source/frames/bog_lizardman art_source/frames/skill_icons_flooded`. Expected: 8, 11, 6, 9 and 2 PNGs. Re-run a set's `generate_frames.py` (resumes) for any missing frame. Read every generated frame with the Read tool (images) and regenerate any that is wrong (an unreadable pose, a stray background, the wrong direction) with `generate_frames.py <set> <frame>` (an explicit frame name regenerates it).

- [ ] **Step 2: Assemble the sheets** (unsandboxed, whole commands, one per set):

`uv run --python 3.12 --with Pillow python tools/art/assemble_frames.py glass_eel` (and `cave_crayfish`, `drift_jelly`, `bog_lizardman`). Then the icons: `uv run --python 3.12 --with Pillow python tools/art/make_icons.py`. Run `env HOME="$PWD/.tmp/gdhome" godot --headless --import` so the new PNGs import.

- [ ] **Step 3: Write the failing tests.** In `tests/test_enemy_sheets.gd` append the four ids to `SETS`. In `tests/test_enemy_state.gd` add:

```gdscript
func test_the_flooded_creatures_map_to_their_clips() -> void:
	var pick := func(id: String, charge := "", swoop := "idle", windup := false, recent := false, moving := false) -> String:
		return EnemyState.pick(id, EnemyStatus.ACTIVE, charge, swoop, windup, recent, false, true, moving, false)
	assert_eq(pick.call("glass_eel"), "swim")
	assert_eq(pick.call("glass_eel", "", "hover"), "swim")
	assert_eq(pick.call("glass_eel", "", "warn"), "warn")
	assert_eq(pick.call("glass_eel", "", "dive"), "dart")
	assert_eq(pick.call("drift_jelly"), "drift")
	assert_eq(pick.call("cave_crayfish", "windup"), "windup")
	assert_eq(pick.call("cave_crayfish", "charge"), "charge")
	assert_eq(pick.call("cave_crayfish", "", "idle", false, false, true), "walk")
	assert_eq(pick.call("bog_lizardman", "", "idle", true), "puff")
	assert_eq(pick.call("bog_lizardman", "", "idle", false, true), "spit")
	assert_eq(pick.call("bog_lizardman", "", "idle", false, false, true), "walk")
	assert_eq(pick.call("bog_lizardman"), "idle")
```

In `tests/test_enemy_sheets.gd` the existing "every creature × every state has a clip" test (read it) gains the new creatures' reachable states: the eels `swim`, `warn`, `dart`, `stunned`, `hurt`, `downed`; the jelly `drift`, `stunned`, `hurt`, `downed`; the crayfish the crab's; the lizardman `idle`, `walk`, `puff`, `spit`, `stunned`, `hurt`, `downed`.

- [ ] **Step 4: Run to confirm they fail.** `tools/run_tests.sh test_enemy_state test_enemy_sheets` → FAIL.

- [ ] **Step 5: Implement.** `enemy_state.gd`: add arms before the final `return "idle"`, and share where the behaviour matches:

```gdscript
		"glass_eel", "storm_eel":
			match swoop:
				"warn":
					return "warn"
				"dive":
					return "dart"
			return "swim"
		"drift_jelly":
			return "drift"
```

and widen the existing arms: `"mushroom_crab", "cave_crayfish":` (the charge/walk/idle arm) and `"toad", "bog_lizardman":` (the puff/spit/walk/idle arm).

`data/enemy_clips.json`: add (keep the file's formatting; each state a clip, the eel's loop 1,2,3,2):

```json
"glass_eel": {"swim": {"frames": ["swim_1","swim_2","swim_3","swim_2"], "fps": 8.0, "loop": true}, "warn": {"frames": ["warn"], "fps": 1.0, "loop": false}, "dart": {"frames": ["dart"], "fps": 1.0, "loop": false}, "stunned": {"frames": ["stunned"], "fps": 1.0, "loop": false}, "hurt": {"frames": ["hurt"], "fps": 1.0, "loop": false}, "downed": {"frames": ["downed"], "fps": 1.0, "loop": false}},
"drift_jelly": {"drift": {"frames": ["drift_1","drift_2","drift_3","drift_2"], "fps": 5.0, "loop": true}, "stunned": ..., "hurt": ..., "downed": ...},
"cave_crayfish": <copy mushroom_crab's clips>,
"bog_lizardman": {"idle": {"frames": ["idle_1"], ...}, "walk": {"frames": ["walk_1","walk_2","walk_3","walk_2"], "fps": 8.0, "loop": true}, "puff": {"frames": ["windup_1"], ...}, "spit": {"frames": ["throw_1"], ...}, "stunned": ..., "hurt": ..., "downed": ...}
```

`_load_sheet` in `enemy.gd` starts a creature in `idle` / `fly` / `hide`: add `"swim"` and `"drift"` to that fallback chain so the eel and the jelly start on their loops (`"idle" if has("idle") else ("fly" if ... else ("swim" if ... else ("drift" if ... else "hide")))`).

`skill_screen.gd`: extend `PORTRAIT_FRAME` with `"glass_eel": "swim_1", "cave_crayfish": "idle_1", "drift_jelly": "drift_1", "bog_lizardman": "idle_1"`. `tools/art/manifest.json`: add the two icons (read the file's shape for an existing icon entry) and whatever test pins the sprite count (`test_art_assets`: update the count).

- [ ] **Step 6: Run** `tools/run_tests.sh test_enemy_state`, `test_enemy_sheets`, `test_art_assets`, `test_skill_screen`, `test_compendium_model`, `test_enemy_clips` → PASS. Take real screenshots of each new creature in game (a window run is needed: `tools/enemy_in_game.gd`'s pattern, adding the four ids) and read them: the creature stands on the floor line, faces right, reads at game size, the eel's frames read as swimming. Fix frames (regenerate and re-assemble) as needed.

- [ ] **Step 7: Commit.** `git add -A && git commit -m "art: the Flooded creatures' sheets, clips, portraits and the Swim and Jolt icons"`

---

### Task 13: Rooms F1–F5 and G4's hole

**Files:** Create `data/rooms/F1.tres`..`F5.tres`, `.tmp/flooded/author.gd` (not committed), `tests/test_flooded_rooms.gd`; Modify `data/rooms/G4.tres`, `tests/support/shipped_rooms.gd`, `tests/test_rooms.gd`, `tests/test_decor_lib.gd`, `tests/test_world_view.gd`, `docs/rooms.md`.

**Interfaces:** Consumes everything above. Produces the five rooms, the G4 floor hole with its ledge chain, the F4→F5 hole and chain, the F2 column and its gate, F1's learning pool and rebirth pool (id `F1`, area `flooded`, kit in Task 14), the pacing and traversal tests.

- [ ] **Step 1: Write the failing tests** `tests/test_flooded_rooms.gd` (they need the rooms, so they fail until Step 3). Add `"F1".."F5"` to `ShippedRooms.IDS` first (and update its docstring: sixteen rooms) so every content pin sees them:

```gdscript
extends GutTest
## The Flooded Tunnels' rooms: the world is valid, the pacing rule holds, the chains and the doors work, and no swimmer is trapped.

const ROOMS := ["F1", "F2", "F3", "F4", "F5"]

var rooms: Dictionary
var creatures := {}

func before_all() -> void:
	rooms = World.load_rooms("res://data/rooms")
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c

func _first_time(ids: Array) -> int:
	var total := 0
	for id in ids:
		for s in (rooms[id] as RoomDef).spawns:
			var c: CreatureDef = creatures[s["id"]]
			total += c.xp * (1 if c.id == "water_pool" else 2)
	return total

func test_the_world_validates_and_lints_clean() -> void:
	var ids: Array = creatures.keys()
	assert_eq(WorldValidator.validate(rooms, ids), PackedStringArray())
	assert_eq(RoomLint.check(rooms), [], RoomLint.text(RoomLint.check(rooms), RoomLint.RULES))

func test_the_rooms_sit_where_the_spec_puts_them() -> void:
	var want := {"F1": [Vector2i(10, 8), Vector2i(2, 1)], "F2": [Vector2i(12, 7), Vector2i(1, 2)], "F3": [Vector2i(12, 6), Vector2i(3, 1)],
		"F4": [Vector2i(15, 6), Vector2i(2, 1)], "F5": [Vector2i(15, 7), Vector2i(1, 1)]}
	for id in want:
		assert_eq((rooms[id] as RoomDef).cell, want[id][0], id)
		assert_eq((rooms[id] as RoomDef).size, want[id][1], id)
		assert_eq((rooms[id] as RoomDef).area, "flooded", id)

func test_every_gated_exit_is_the_swim_door() -> void:
	var gated := []
	for id in ROOMS:
		for e in (rooms[id] as RoomDef).exits:
			if e.has("gate"):
				gated.append("%s:%s" % [id, e["gate"]])
	gated.sort()
	assert_eq(gated, ["F2:swim", "F3:swim"], "F2's top exit and F3's floor hole")

func test_the_pacing_rule() -> void:
	var total := _first_time(ROOMS)
	assert_gte(total, 150, "real payoff for a stage-1 life that just evolved")
	assert_lt(total, Progression.stage_total(2), "stage 2's cap needs more than this area")

func test_the_ungated_flooded_is_f1_and_f2_only() -> void:
	var reach := WorldValidator.reachable(rooms, true)
	for id in ["F1", "F2"]:
		assert_true(reach.has(id), id)
	for id in ["F3", "F4", "F5"]:
		assert_false(reach.has(id), "%s is behind the swim door" % id)

func test_the_two_floor_holes_have_chains_back_up_standing_on_dry_floor() -> void:
	# G4 -> F1 and F4 -> F5: the top ledge sits at local y 12-15 flush with the span's west edge, every hop at most 55 up
	for pair in [["G4", "F1"], ["F4", "F5"]]:
		var upper: RoomDef = rooms[pair[0]]
		var lower: RoomDef = rooms[pair[1]]
		var hole: Dictionary = upper.exits.filter(func(e): return e["edge"] == "bottom" and e["room"] == pair[1])[0]
		var span := WorldValidator.world_span(upper, hole)
		var west := span.x - WorldValidator.edge_origin(lower, "top")
		var tops: Array = lower.solids.map(func(s): return (s as Rect2).position.y)
		tops.sort()
		assert_between(tops[0], 12.0, 15.0, "%s: the top ledge" % pair[1])
		var top_ledge: Rect2 = lower.solids.filter(func(s): return (s as Rect2).position.y == tops[0])[0]
		assert_almost_eq(top_ledge.position.x, west, 1.0, "%s: flush with the span's west edge" % pair[1])
		for i in range(1, tops.size()):
			if tops[i] - tops[i - 1] > 55.0:
				break
			assert_lte(tops[i] - tops[i - 1], 55.0)
		for w in lower.water:
			for s in lower.solids:
				if (s as Rect2).position.y > 100.0:
					continue
				assert_false((s as Rect2).intersects(w), "%s: the chain stands outside every water rect" % pair[1])

## The Swim door of a room's top exit, in the three parts the Grotto's G5 test has.
func _assert_door(room_id: String) -> void:
	var r: RoomDef = rooms[room_id]
	var top: Dictionary = r.exits.filter(func(e): return e["edge"] == "top" and e.get("gate", "") == "swim")[0]
	var column: Rect2 = r.water.filter(func(w): return (w as Rect2).position.y <= RoomDef.WALL + 0.5 and (w as Rect2).end.x > float(top["from"]) and (w as Rect2).position.x < float(top["to"]))[0]
	# (a) the top exit's span lies inside the column's x-range and the column reaches the room's top edge
	assert_true(column.position.x <= float(top["from"]) and column.end.x >= float(top["to"]), "%s (a) the span is inside the column" % room_id)
	# (b) no solid inside the column, and the sill clears the true non-swimmer reach plus 3
	for s in r.solids:
		assert_false((s as Rect2).intersects(column), "%s (b) no solid inside the column" % room_id)
	var jh := 185.0
	var b := PlayerWater.bob_apex(jh)
	var b_entry := (pow(Player.JUMP_VELOCITY, 2.0) - pow(PlayerWater.BOB_VELOCITY, 2.0)) * jh / (2.0 * Player.GRAVITY * 100.0) + b
	assert_almost_eq(b_entry, 160.8, 0.3)
	var floor_top: float = r.pixel_size().y - RoomDef.FLOOR
	var sill_height := floor_top - RoomDef.WALL
	assert_gte(sill_height, b_entry + 3.0, "%s (b) the sill clears B_entry + 3" % room_id)
	# (c) no dry surface beside the column is high enough that a lateral dry jump from it enters the column within B_entry of the sill
	for s in r.solids:
		var rr: Rect2 = s
		var dry := true
		for w in r.water:
			if rr.intersects(w):
				dry = false
		if not dry or rr.end.x < column.position.x - 160.0 or rr.position.x > column.end.x + 160.0:
			continue
		assert_lte((floor_top - rr.position.y) + b_entry + 3.0, sill_height, "%s (c) a dry ledge beside the column reaches the sill" % room_id)

func test_the_swim_door_is_structural() -> void:
	_assert_door("F2")

func test_no_swimmer_is_trapped_anywhere_in_the_world() -> void:
	assert_eq(RoomLint.water_groups(rooms), [])

func test_every_swimmer_spawn_is_in_water_and_no_walker_needs_it() -> void:
	for id in ROOMS:
		var r: RoomDef = rooms[id]
		for s in r.spawns:
			if (creatures[s["id"]] as CreatureDef).swimmer:
				var wet := false
				for w in r.water:
					if (w as Rect2).has_point(s["pos"]):
						wet = true
				assert_true(wet, "%s %s" % [id, s["pos"]])

func test_f1_holds_the_rebirth_pool_and_f5_the_tablet() -> void:
	var f1_kinds: Array = (rooms["F1"] as RoomDef).features.map(func(f): return f["kind"])
	assert_true(f1_kinds.has("rebirth_pool"))
	var f5_kinds: Array = (rooms["F5"] as RoomDef).features.map(func(f): return f["kind"])
	assert_true(f5_kinds.has("tablet"))
	assert_true(f5_kinds.has("glow_pool"))

func test_g4_is_no_longer_the_last_room_and_has_a_hole_with_nothing_over_it() -> void:
	var g4: RoomDef = rooms["G4"]
	assert_true(g4.exits.any(func(e): return e["edge"] == "bottom" and e["room"] == "F1"))
```

`tests/test_rooms.gd` (its exact id list) gains `F1`–`F5`; `test_world_view.gd`'s `layout.size() == 11` becomes `16`; `test_decor_lib.gd`'s used-id pins change when the F rooms use `flooded_*` pieces (update them to the new set); `tests/test_grotto_rooms.gd`'s statement "G4 is the area's last room" (read it) gains the F1 hole.

- [ ] **Step 2: Run to confirm it fails.** `tools/run_tests.sh test_flooded_rooms` → FAIL (no rooms).

- [ ] **Step 3: Author the rooms with a one-shot script**, not committed: `.tmp/flooded/author.gd`, run as `env HOME="$PWD/.tmp/gdhome" godot --headless -s .tmp/flooded/author.gd`. It loads the shipped rooms into a `RoomEditModel`, builds the new rooms with the model's own API (`new_room_beside`, `add_exit`, `add_solid`, `add_spawn`, `add_feature`, `add_decor`), assigns `water`, and calls `save_dirty("res://data/rooms")`. The geometry below is the design; the script reports every `RoomLint`/`WorldValidator` finding it produces, and the rooms are adjusted until the report is empty. Coordinates are local px; every room's floor top is `height − 40`.

Room creation, in order (each call returns "" or the reason it refused; the script asserts `""`):

```gdscript
var m := RoomEditModel.new(ShippedRooms.only(World.load_rooms("res://data/rooms")), creature_ids)
assert(m.new_room_beside("G4", "bottom", "F1", "flooded", Vector2i(2, 1)) == "")
assert(m.new_room_beside("F1", "right", "F2", "flooded", Vector2i(1, 2)) == "")
assert(m.new_room_beside("F2", "top", "F3", "flooded", Vector2i(3, 1)) == "")
assert(m.new_room_beside("F3", "right", "F4", "flooded", Vector2i(2, 1)) == "")
assert(m.new_room_beside("F4", "bottom", "F5", "flooded", Vector2i(1, 1)) == "")
```

(`new_room_beside` places by the rule in the spec's layout table; the script asserts the resulting cells equal the spec's.) The model creates each pair of exits with a default 120 px door; set the exact spans with `set_field`/`add_exit` as needed:

- **G4 → F1** (bottom/top): G4's floor hole at local x 240–400 (160 wide, as C5's), matching F1's top exit. Move G4's content clear of the hole (the lint's `over_hole` names what is in the way): the glow pool x 320 → 470, the tablet x 500 → 575, the crystal prism decor x 250 → 150, the flowers decor x 400 → 520, the crab at x 260 → 110 (spawn y stays on the floor), the lichen hang stays (it is on the ceiling). F1's chain (the `Prefabs.ledge_chain` recipe, expanded into plain solids, 100-wide ledges offset 140, top ledge at y 14 flush with the span's west edge x 240, 12 tall, `step` 48 down to just above the floor) is added with `add_solid`.
- **F1** (1280×360): the landing under G4's drop with the chain up to it on the west side; the rebirth pool at x 640 (floor, y 320); a crayfish at x 520 and one at x 900; and the **learning pool** on the floor between x 760 and 1020: water `Rect2(760, 240, 260, 80)` (surface at y 240, bottom at the floor top 320), open on its left (a stepped shallow end of two thin ledges `Rect2(700, 296, 60, 12)` and `Rect2(660, 308, 60, 12)` leading down into it, so a non-swimmer walks in and out) and banked on its right by a solid `Rect2(1020, 244, 80, 76)` whose top (y 244, 4 below the surface) is the shore `water_exit` needs. Jellies at `(840, 270)` and `(940, 285)`. F1's east exit (to F2) at local y 200–320 on its right edge.
- **F2** (640×720): the column. Water `Rect2(20, 20, 600, 700)`: from the ceiling band to the bottom edge, so it reaches the top edge over the top exit, the left edge over the west exit and the bottom edge; no solid inside it. The west exit (from F1) is on the lower row at local y 560–680; the top exit at local x 240–400 carries `gate: "swim"` (matching F3's floor hole). Eels at `(480, 400)` and `(160, 560)`.
- **F3** (1920×360): one water rect `Rect2(20, 160, 1880, 200)` (surface at y 160, down to the bottom edge, so it also covers the floor hole where F2's column arrives at x 240–400 and a swimmer coming up keeps swimming). That hole carries `gate: "swim"`. Shore ledges along the surface: thin ledges whose tops are at y 150–172 (inside `[surface − 44, surface + 12]`) every ~300 px, which double as the climb for non-swimmers out of the water to the dry upper ledges and F3's east exit at local y 200–320 on its right edge. Eels at `(500, 230)`, `(900, 200)`, `(1300, 250)`, `(1600, 220)`; jellies at `(700, 260)`, `(1100, 240)`, `(1500, 270)` (all inside the water).
- **F4** (1280×360): shallow-water decor (`flooded_*` pieces) on dry platforms, the lizardmen's post (four lizardmen on the platforms at x 300, 500, 900, 1100), three crayfish on the floor at x 400, 700, 1000; the floor hole at local x 220–380 with F5's chain beneath it; F3's east exit meets F4's west.
- **F5** (640×360): the Quiet Pool: the Glow Pool at x 460 and the tablet (hint `jolt`, text "Water learns to carry you, and lightning learns to ride it.", title "Drowned tablet") at x 540; a small eel pool `Rect2(60, 250, 200, 70)` with a shore ledge, two eels in it, two lizardmen on dry floor at x 380 and 600; the chain up to F4.

Decor: use `DecorLib.ids_for_biome("flooded")` pieces (`flooded_*`) placed with `add_decor` on surfaces and under ledges for each room; the glow pieces carry their catalog light. No dressing.

Run the script; read its report; iterate the numbers until `RoomLint.check(rooms)`, `WorldValidator.validate(rooms, creature_ids)` and `RoomLint.water_groups(rooms)` are all empty and the pacing sum is in range (the guide: F1 2 crayfish and 2 jellies, F2 2 eels, F3 4 eels and 3 jellies, F4 4 lizardmen and 3 crayfish, F5 2 eels and 2 lizardmen = 188). The spawn list above is that guide.

- [ ] **Step 4: Run** `tools/run_tests.sh test_flooded_rooms`, `test_rooms`, `test_room_lint`, `test_world_validator`, `test_world_view`, `test_decor_lib`, `test_grotto_rooms`, `test_form_offers`, `test_rebirth_kit`, `test_first_evolution_areas`, `test_player_spread` (every exit fits the 2× slime) → PASS. Also: the whole-world reachability test the Grotto added (`test_every_ledge_is_reachable_from_its_floor_by_base_jumps` for the rooms) passes for the new rooms' dry ledges. Mutation checks: add a solid inside F2's column → the structural-door test fails; remove F4's chain's top ledge → the chain test fails; drop a shore ledge → the shore test fails.

- [ ] **Step 5: Real screenshots** of each room (the editor's shots tool or `tools/room_shots.gd`: extend its room list with F1–F5): read them; the water tint, the shore ledges, the creature positions and the decor must read. Fix what they show.

- [ ] **Step 6: Docs.** `docs/rooms.md`: add the rooms table rows (F1–F5), the water section (what `water` is, the three lint rules, the swim door and its test), the G4 row ("the last room" becomes "the way down to the Flooded"), and the F1 learning pool and F2 column notes. Update `docs/playtest-checklist.md` in Task 17.

- [ ] **Step 7: Commit** (the `.tres` files and tests; not `.tmp`). `git add -A && git commit -m "feat: the Flooded Tunnels, F1 to F5, and the way down from G4"`

---

### Task 14: F1's rebirth kit

**Files:** Modify `data/rooms/F1.tres` (its pool's `kit`), `tests/test_rebirth_kit.gd`.

**Interfaces:** Consumes the F1 pool (Task 13) and `FormOffers.FIRST_EVOLUTION_AREAS` (Task 3). Produces the kit `{"skills": ["leap", "wall_cling", "swim"], "level": 4, "affinity": {...}}` with seeds chosen by a test.

- [ ] **Step 1: Write the failing tests** in `tests/test_rebirth_kit.gd`:

```gdscript
## The essences a life can eat in the rooms before the first door (F1 and F2), without a stun source: jellies cannot be downed
## by tackle, so they are not counted.
func _flooded_units(rooms: Dictionary, creatures: Dictionary) -> Dictionary:
	var out := {}
	for id in ["F1", "F2"]:
		for s in (rooms[id] as RoomDef).spawns:
			var c: CreatureDef = creatures[s["id"]]
			if c.untackleable:
				continue
			for e in c.essences:
				out[e] = int(out.get(e, 0)) + int(c.essences[e])
	return out

func test_the_flooded_pool_leaves_two_lineages_eligible_and_its_seeds_matter() -> void:
	var forms := FormLoader.load_all()
	var rooms := ShippedRooms.load_all()
	var creatures := {}
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	var supply := FormOffers.supply(rooms, creatures, forms, FormOffers.FIRST_EVOLUTION_AREAS)
	var checked := 0
	for p in RebirthChoice.pools(rooms):
		if p["id"] == WorldProgress.DEFAULT_POOL or p["area"] != "flooded":
			continue
		checked += 1
		var seeds: Dictionary = (p["kit"] as Dictionary).get("affinity", {})
		var without := _flooded_units(rooms, creatures)
		var with_seeds := without.duplicate()
		for e in seeds:
			with_seeds[e] = int(with_seeds.get(e, 0)) + int(seeds[e])
		var n_with := RebirthKit.eligible_lineages(with_seeds, supply, forms)
		var n_without := RebirthKit.eligible_lineages(without, supply, forms)
		assert_gte(n_with, 2, "pool %s leaves two lineages eligible" % p["id"])
		assert_gt(n_with, n_without, "pool %s: the seeds are not decoration" % p["id"])
	assert_eq(checked, 1, "the Flooded ships one pool")

func test_the_flooded_pool_kit_is_valid_and_grants_leap_wall_cling_and_swim() -> void:
	var rooms := World.load_rooms("res://data/rooms")
	var pool: Dictionary = {}
	for p in RebirthChoice.pools(rooms):
		if p["id"] == "F1":
			pool = p
	assert_eq(pool["room"], "F1")
	assert_eq(pool["area"], "flooded")
	assert_eq(RebirthKit.validate(pool["kit"]).size(), 0)
	assert_eq(pool["kit"]["skills"], ["leap", "wall_cling", "swim"])
	assert_eq(pool["kit"]["level"], 4)

func test_an_f1_life_reaches_its_first_evolution_only_by_going_back_up() -> void:
	var rooms := ShippedRooms.load_all()
	var creatures := {}
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	var need := 0
	for l in range(4, Progression.LEVEL_CAP):
		need += Progression.xp_to_next(l)
	assert_eq(need, 225, "25 + 30 + 35 + 40 + 45 + 50")
	var first_pass := 0
	for id in ["F1", "F2", "F3", "F4", "F5"]:
		for s in (rooms[id] as RoomDef).spawns:
			var c: CreatureDef = creatures[s["id"]]
			first_pass += c.xp * 2
	assert_lt(first_pass, need, "the Flooded alone is not enough: the life climbs back to the Grotto or the Cave")
	var areas_total := 0
	for id in WorldValidator.reachable(rooms, true):
		var r: RoomDef = rooms[id]
		if FormOffers.FIRST_EVOLUTION_AREAS.has(r.area):
			for s in r.spawns:
				var c2: CreatureDef = creatures[s["id"]]
				areas_total += c2.xp * (1 if c2.id == "water_pool" else 2)
	assert_lte(need, areas_total, "the first-evolution areas supply it")
```

- [ ] **Step 2: Run to confirm it fails.** `tools/run_tests.sh test_rebirth_kit` → FAIL (the pool has no kit yet).

- [ ] **Step 3: Add the kit.** The affinity seeds are chosen by the test, not by hand: write a throwaway search in `.tmp/flooded/seeds.gd` that tries seed vectors (units 0–6 of `water`, `shell`, `earth`, `poison`, `thread`) against `_flooded_units` and the first-evolution supply and prints the smallest vector that leaves at least two lineages eligible and more than without. Put the result in `F1.tres`'s pool feature as `"kit": {"affinity": {...}, "level": 4, "skills": ["leap", "wall_cling", "swim"]}` (edit the `.tres` text or through `RoomEditModel.set_field`).

- [ ] **Step 4: Run** `tools/run_tests.sh test_rebirth_kit`, `test_rebirth_choice`, `test_game_flow` (the death-to-new-life flow with an attuned pool; it must call `choose` explicitly) → PASS. Mutation check: set the level to 9 → the XP assertion fails; empty the affinity → the "seeds matter" test fails.

- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat: the Flooded's rebirth kit"`

---

### Task 15: The room view draws water (editor core)

**Files:** Modify `scripts/editor/room_view.gd`, `tools/editor_shots.gd`; Create `tests/test_room_view_water.gd`.

**Interfaces:** Consumes `RoomDef.water`. Produces read-only water in the editor's room view (the in-game tint), with the room view built from the same `RoomBuilder` that adds `DeepWater` nodes; verification that the tool's Validate list reports the three lint rules.

- [ ] **Step 1: Read** how `RoomView.show_room` builds its content (it uses `RoomBuilder.build_room`, so water may already draw). **Write the test first:**

```gdscript
extends GutTest

func test_the_room_view_shows_a_rooms_water() -> void:
	var rooms := World.load_rooms("res://data/rooms")
	var model := RoomEditModel.new(rooms, [])
	var view := RoomView.new()
	add_child_autofree(view)
	view.show_room(model, "F2")
	var found := 0
	for n in get_tree().get_nodes_in_group("deep_water"):
		found += 1
	assert_gt(found, 0, "the editor draws the F2 column")

func test_validate_lists_a_trapped_swimmer() -> void:
	var r := RoomDef.new()
	r.id = "T1"
	r.area = "flooded"
	r.size = Vector2i(1, 1)
	r.start = Vector2(60, 308)
	r.water = [Rect2(200, 240, 160, 80)]  # no shore, no exit
	var model := RoomEditModel.new({"T1": r}, [])
	assert_true(model.problems().any(func(p): return str(p).find("water_exit") >= 0))
```

- [ ] **Step 2: Run.** If the first test already passes (the view reuses the builder), keep it as a pin; the second is expected to pass through `RoomLint`. If either fails, implement what it names: `show_room` must add `DeepWater` nodes for `def.water`, and `problems()` must include the new rules (they come through `RoomLint.check`).

- [ ] **Step 3: Shots.** Add F2 and F3 (water on screen) to `tools/editor_shots.gd`'s frame list; run it unsandboxed (`env HOME="$PWD/.tmp/editor-home" godot --path . -s res://tools/editor_shots.gd`) and read the frames: the tint reads, the selected-room outline and palettes are unchanged, the Validate button count includes water findings for a deliberately bad room if the shots tool builds one.

- [ ] **Step 4: Commit.** `git add -A && git commit -m "feat: the editor draws a room's water and lists its water findings"`

---

### Task 16: The Water tool (slice)

**Files:** Modify `scripts/editor/room_edit_model.gd`, `scripts/editor/room_view.gd`, `scripts/editor/editor_panels.gd`, `scripts/editor/room_editor.gd`, `scripts/editor/inspector_panel.gd`, `scripts/world/room_lint.gd` (the `pick`), `docs/rooms.md`; Create `tests/test_room_edit_water_tool.gd`, extend `tests/test_room_editor_scene.gd`.

**Interfaces:** Consumes the Solid tool's code paths (read them: `add_solid`, `_put_solid`, `hit_all`'s solid arm, `begin_move`, `move_to`, `delete_selection`, `get_field`, `set_field`, `_set_solid_field`, the room view's solid-draw release arm and its selection outline, the inspector's solid FIELDS, the toolbar list). Produces `RoomEditModel.add_water(room_id, a, b)`, selection kind `"water"` through `hit_all`/`hit`, `begin_move`/`move_to`/`delete_selection` arms, `get_field`/`set_field` keys `x y w h` for water, the Water tool in `EditorPanels.TOOLS`, `RoomView`'s draw-release arm and outline, the inspector's water fields, and the lint `pick` for water findings.

- [ ] **Step 1: Write the failing tests** `tests/test_room_edit_water_tool.gd`:

```gdscript
extends GutTest

var model: RoomEditModel

func before_each() -> void:
	var r := RoomDef.new()
	r.id = "T1"
	r.area = "flooded"
	r.size = Vector2i(2, 1)
	r.start = Vector2(60, 308)
	model = RoomEditModel.new({"T1": r}, [])

func test_add_water_draws_a_snapped_rect_and_selects_it_in_one_undo_step() -> void:
	assert_eq(model.add_water("T1", Vector2(203, 103), Vector2(405, 251)), "")
	var w: Rect2 = model.rooms["T1"].water[0]
	assert_eq(w.position, Vector2(model.snap(203), model.snap(103)))
	assert_eq(model.selection["kind"], "water")
	assert_eq(model.undo_depth(), 1)
	model.undo()
	assert_eq(model.rooms["T1"].water, [])

func test_add_water_refuses_small_outside_and_overlapping_rects() -> void:
	assert_ne(model.add_water("T1", Vector2(100, 100), Vector2(120, 120)), "", "under 32 px")
	assert_ne(model.add_water("T1", Vector2(-50, 100), Vector2(100, 200)), "", "outside the room")
	assert_eq(model.add_water("T1", Vector2(200, 100), Vector2(400, 250)), "")
	assert_ne(model.add_water("T1", Vector2(300, 150), Vector2(500, 300)), "", "overlaps the first")
	assert_ne(model.add_water("T1", Vector2(400, 100), Vector2(600, 250)), "", "touches the first")
	assert_eq(model.undo_depth(), 1, "refusals leave no history")

func test_water_is_hit_last_so_anything_in_it_wins() -> void:
	model.add_water("T1", Vector2(200, 100), Vector2(400, 250))
	assert_eq(model.hit("T1", Vector2(300, 180), 4.0)["kind"], "water")
	model.add_spawn("T1", "glass_eel", Vector2(300, 180))
	assert_eq(model.hit("T1", Vector2(300, 180), 4.0)["kind"], "spawn")

func test_water_moves_deletes_and_edits_by_field() -> void:
	model.add_water("T1", Vector2(200, 100), Vector2(400, 250))
	var sel := model.selection.duplicate()
	assert_true(model.begin_move(sel))
	model.move_to(Vector2(40, 20))
	model.end_move()
	assert_eq((model.rooms["T1"].water[0] as Rect2).position, Vector2(model.snap(240), model.snap(120)))
	assert_eq(model.get_field(sel, "w"), 200.0)
	assert_eq(model.set_field(sel, "w", 240.0), "")
	assert_eq((model.rooms["T1"].water[0] as Rect2).size.x, 240.0)
	assert_ne(model.set_field(sel, "w", 10.0), "", "under the minimum")
	assert_eq(model.delete_selection(), "")
	assert_eq(model.rooms["T1"].water, [])

func test_a_lint_finding_for_water_selects_it() -> void:
	var r: RoomDef = model.rooms["T1"]
	r.water = [Rect2(200, 240, 160, 80)]  # no shore: water_exit
	var f: Dictionary = RoomLint.check_room(r, {"T1": r}).filter(func(x): return x["rule"] == "water_exit")[0]
	assert_eq(f["pick"], {"room": "T1", "kind": "water", "index": 0})
```

and in `tests/test_room_editor_scene.gd` a scene test that picks the Water tool and drags a rect in the room view with real `InputEventMouseButton`/`Motion` events (pattern: the existing Solid tool drag test), asserting one water rect appears and the inspector shows X/Y/Width/Height for it.

- [ ] **Step 2: Run to confirm they fail.** `tools/run_tests.sh test_room_edit_water_tool` → FAIL.

- [ ] **Step 3: Implement**, each arm modelled on the Solid tool's (read it first): `add_water` (`MIN_WATER := 32.0`; refuses outside, small, overlapping or touching with `intersects(b, true)`; one `_snap`/`_push`; selects the new rect); `hit_all` appends water rects last (a volume: `rect.has_point(p)`, ties by index); `begin_move`/`move_to` clamp inside the room and refuse overlap (keep the old position on a refusal, as `_put_solid` does); `delete_selection`; `get_field`/`set_field` keys `x y w h` through a `_set_water_field` that enforces the minimum, containment and the no-overlap rule; the selection-kinds doc and `hit_all`'s comment; `RoomLint`'s `_f(..., "water", index)` picks for `water_rect` (and `water_exit`) findings; `EditorPanels.TOOLS` gains `Water` (after Solid); `RoomView` gets the Water tool's drag-release arm (the same drag as Solid, calling `add_water` and `_report`), the outline for kind `water` in `_selection_rect` (blue, like the in-game tint) and the status hint; `InspectorPanel.FIELDS` gains a `water` entry of four number fields; `docs/rooms.md` gains a line on the tool.

- [ ] **Step 4: Run** `tools/run_tests.sh test_room_edit_water_tool`, `test_room_editor_scene`, `test_room_edit`, `test_room_view`, `test_room_lint_water` → PASS. Mutation checks: let `add_water` skip the touching test → the touching assertion fails; drop the water arm from `hit_all` → the hit test fails.

- [ ] **Step 5: Shots** of the editor with a water rect selected (the inspector's fields visible): read them and fix what they show.

- [ ] **Step 6: Commit.** `git add -A && git commit -m "feat: the editor's Water tool"`

---

### Task 17: The rare slice: the Storm Eel and F6

**Files:** Create `tools/art/storm_eel_frames.json`, `assets/sheets/storm_eel.{png,json}`, `data/rooms/F6.tres`, `data/creatures/storm_eel.tres` (generated); Modify `tools/build_content.gd`, `scripts/core/sources.gd`, `data/enemy_clips.json`, `scripts/ui/skill_screen.gd`, `data/rooms/F4.tres`, `data/rooms/F5.tres`, `tests/support/shipped_rooms.gd`, `tests/test_flooded_rooms.gd`, `tests/test_enemy_sheets.gd`, `tests/test_constants.gd`, `tests/test_content.gd`, `docs/rooms.md`.

**Interfaces:** Consumes the eel's sheet (Task 12) via `derive_from`/`lighten` in `assemble_frames.py` (the Pale Moth's recipe). Produces the `storm_eel` creature (10/4/1/160, shock 3 water 2, XP 10, `swimmer`, `contact_type "shock"`), its derived sheet and clips, F4's second water column and top exit (gate `swim`, local x 440–600), and F6 (1×1 at (15,5)) with the Storm Eel.

- [ ] **Step 1: Write the failing tests.** In `tests/test_flooded_rooms.gd` add F6 to a `SLICE` list and tests that: F6 is at cell (15,5) size 1×1; F4's top exit and F6's bottom exit carry `gate: "swim"`; F4's second column passes the same structural door test as F2's (factor the F2 test into `_assert_door(room_id)` and call it for both); F6 holds exactly one `storm_eel` in water; F6 never counts toward the pacing sum (the pacing test stays over F1–F5); `RoomLint.check` and `WorldValidator.validate` still clean; `RoomLint.water_groups` empty. In `test_enemy_sheets`/`test_content`/`test_constants`: the `storm_eel` set, source and def; a test that the Storm Eel's sheet frames are the eel's frame names and wider than the eel's.

- [ ] **Step 2: Run to confirm they fail.** `tools/run_tests.sh test_flooded_rooms test_enemy_sheets` → FAIL.

- [ ] **Step 3: Implement.** `tools/art/storm_eel_frames.json` (no prompts; the derive recipe, as `pale_moth_frames.json`):

```json
{
 "derive_from": "glass_eel",
 "lighten": 0.25,
 "tint": [190, 215, 255],
 "tint_amount": 0.4,
 "anchor": "swim_1",
 "frames": [
  {"name": "swim_1", "width": 64, "refs": []}, {"name": "swim_2", "width": 64, "refs": []}, {"name": "swim_3", "width": 64, "refs": []},
  {"name": "warn", "width": 64, "refs": []}, {"name": "dart", "width": 74, "refs": [], "attack_from": 0.6},
  {"name": "stunned", "width": 64, "refs": []}, {"name": "hurt", "width": 64, "refs": []}, {"name": "downed", "width": 66, "refs": []}
 ]
}
```

(read `pale_moth_frames.json` and `assemble_frames.py`'s `derive_from` handling to match key names exactly; widths are the eel's × 1.23). Assemble: `uv run --python 3.12 --with Pillow python tools/art/assemble_frames.py storm_eel`. `sources.gd`: `STORM_EEL`; `build_content.gd`: the def with `_at_level(FLOODED_LEVEL, {"max_hp": 10, "atk": 4, "def": 1, "spd": 160})`, essences `{"shock": 3, "water": 2}`, `swimmer`, `contact_type "shock"`, XP 10, `eat_bonus {"stat": "spd", "amount": 2, "per": 1}`. `enemy_clips.json`: copy the eel's clips; `EnemyState` arm already covers `storm_eel`; `PORTRAIT_FRAME["storm_eel"] = "swim_1"`.

Rooms (script through the model as in Task 13, `.tmp/flooded/author_slice.gd`): `new_room_beside("F4", "top", "F6", "flooded", Vector2i(1,1))`; F4's top exit at local x 440–600 with `gate: "swim"` (both halves via `add_exit(..., {"gate": "swim"})`); F4's second water column `Rect2(430, 20, 180, 300)` (reaches the top edge over the span, its floor at the floor band, no solids inside, a shore ledge beside it for `water_exit` is NOT needed: the exit clause holds); F6: a small pocket with the lower water `Rect2(20, 200, 600, 120)` covering the span, shore ledges, one `storm_eel` at `(320, 270)`, and one decor piece or two. Add F6 to `ShippedRooms.IDS` (sixteen → seventeen) and update the pins that count rooms (`test_world_view` 17).

- [ ] **Step 4: Run** the suites named above plus `test_flooded_rooms`, `test_rooms`, `test_decor_lib`, `test_art_assets` → PASS. Take a real screenshot of F6 and the Storm Eel; read them.

- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat: the Storm Eel and F6 (the rare slice)"`

---

### Task 18: Docs, playtest lines, shots and the whole branch

**Files:** Modify `docs/rooms.md`, `docs/playtest-checklist.md`, `docs/superpowers/specs/2026-10-01-flooded-tunnels-design.md` (a status line), `tools/shoot_overview.gd` / `tools/shoot_rooms.gd` if they list rooms.

- [ ] **Step 1: Docs.** `docs/rooms.md`: the water section (the data, the three lint rules and what each catches, `SURFACE_LIFT`, the swim door and its structural test, the world shore check), the rooms table rows F1–F6, the "load-bearing details" (F2's column has no solid inside it and the test pins it; the learning pool's shore ledge; the F1/G4 chains' top ledge at y 12–15). `docs/playtest-checklist.md` gains the lines: wading in with and without Swim; the bob; a dry jump into the F2 column does not rise past a bob above where it entered; learning Swim in F1's pool in about 20 s; the surface jump leaving the water; eels stalking and diving, the telegraph flash; the jelly (a tackle does nothing, touching it shocks, Jolt downs it); the lizardman holds its post and throws on its cooldown, a front tackle stuns it; shock's 0.3 s lock reads (the deferred question); F2's eels against the 20 s dwell (the deferred question); evolving at G4 offers Tide as before; reborn at F1 with Swim; the Water tool in the editor.

- [ ] **Step 2: Overview and room shots.** Run the project's overview and room shot tools with the new rooms included (unsandboxed, windowed) and read every frame: the map tab shows F1–F6, the water reads in each room, nothing stands over a hole.

- [ ] **Step 3: Full suite.** `TEST_TIMEOUT=900 tools/run_tests.sh > .tmp/flooded-full.log 2>&1; tail -3 .tmp/flooded-full.log` → `PASS: N tests`. Fix anything red (a flake that passes alone and on rerun is ledgered, not fixed).

- [ ] **Step 4: Commit.** `git add -A && git commit -m "docs: the Flooded Tunnels' rooms, water and playtest lines"`

Then the final whole-branch review (the opus reviewer with the Review Focus above), the one fix pass, and the finish (merge, import, full suite on the merged tree, push, relaunch, clean up) as `superpowers:executing-plans` says.
