# Adding a creature family to the Blender art pipeline

How the goblin and wolf families are built, so another (spider, undead, slime...) is built the same way. Everything is under `tools/art/blender/`.
The pipeline is: a low-poly rigged model in Blender, posed by pure-Python motion code, rendered headless (colour pass + normal pass), shrunk and
lit at sprite size (`shade.py`), written into the game as an animated sheet with a normal map and a set of clips. Read `docs/research/blender-pipeline-spike.md`
and `docs/research/rig-weight-research.md` for why.

## The pieces of a family (copy the wolf's, `quad_*`/`wolf_*`, or the goblin's, `goblin_*`)

A two-legged family does **not** write its own motion: it passes a posture to `biped_motion.Body(skel, feet, form, present, posture=dict(...))` (how low it crouches, how
far it leans, its gait overrides, how hard a blow throws it: see `POSTURES`) and gets idle, walk, run, the attacks (chop, stab, thrust, cast, swipe), hurt and die. Its
skeleton must have the goblin's bone names (`hips, spine, head, arm_n/f, fore_n/f, item_n/f, thigh_n/f, shin_n/f, foot_n/f`; more bones are fine, and ears or cloth
bones are followed through by `secondary.py` when listed in the motion's `SECONDARY` table) with its own proportions (`goblin_skeleton.py` is the template).
Anything a family cannot do with that (hopping, floating, a different number of legs) is its own motion module, written like `quad_motion.py`.

| File | Pure Python? | What it is |
|---|---|---|
| `<fam>_skeleton.py` | yes | The skeleton as a table `core(**proportions)` of `(name, head, tail, parent)` in standard coordinates, and `skeleton(...)` returning a flat `skeleton2d.Skeleton2D`. The kit and the motion code both read it. |
| `<fam>_motion.py` | yes | Poses: `idle`, gaits (`walk`, `run`), `attack`, `hurt`, `die` as functions returning `(rot, root)`, and `*_clip(body)` returning `Clip(frames, durations, loop, grounded)`. `Body` holds the flat skeleton, the measured feet and the form. |
| `<fam>_kit.py` | no (bpy) | Builds the meshes from the skeleton: lofts, blades, ellipsoids, limbs bound to bones (`rigkit.py`). |
| `<fam>_gear.py` | no | One function per piece of gear: `fn(kit, **options)`; a registry `GEAR`. |
| `<fam>_forms.py` | yes | The family tree as data: `FORMS = {name: dict(stage, parent, width, proportions, colours, gear=[(name, {...})], ...)}`. |
| `creatures/<fam>.py` | no | The Blender glue: `build(variant)`, `setup(rig, variant)` (camera, clips, timings), measuring feet from meshes, sizing from the game data (`sizing.py`). |
| `test_<fam>_motion.py`, additions to `test_pipeline.py` | | Tests (below). |

Shared, do not change without a reason (tell the integrator): `anim.py` (IK, the foot as a rigid body on moving ground, springs), `limbs.py` (`Leg`, `aim`),
`skeleton2d.py`, `rigkit.py`, `secondary.py` (follow-through), `shade.py`/`spike.py`/`toon.py` (shading), `render_set.py`, `clips.py`, `export_forms.py`, `sizing.py`.

## Conventions

* The camera is at -Y looking at +Y; X is right, Z is up; creatures face +X. The near side is y < 0.
* Angles: **degrees from straight down, forward positive** (0 down, 90 forward, 180 up). A rotation `rot[bone] = (0, theta, 0)` is clockwise as the camera
  sees it; a bone's direction after posing is `rest direction - sum of theta down its chain` (`skeleton2d.py`). Use `limbs.aim(skel, rot, bone, direction)` to
  point a bone in the world; do not paste anatomical angles into rotation tables.
* A leg is a `limbs.Leg` (two bones solved by IK to an ankle target, and a foot with `ankle_h`, `heel`, `toe` measured from its meshes). Place feet with
  `anim.foot_pose` (a rigid foot: heel, flat, toe pivots that do not slide, a swing whose velocity matches the ground's) and `anim.plant`. Pass `rot` to `Leg.solve`
  when the bones above the leg are turned.
* Time is in seconds. Clips have per-frame durations. The engine plays them on a 20 ms grid (`clips.on_grid`).
* **The engine's timings are fixed** (`scripts/enemies/enemy.gd`, read by `export_forms.engine_constants`): the attack is two clips, `windup` (frames that last exactly
  `VERB_WINDUP` = 0.35 s, the last ones being the release; the verb fires when it ends) and `recover` (starting with the impact frame, lasting no more than `VERB_RECOVER`
  = 0.30 s); the flinch lasts `HURT_SECONDS` = 0.25 s; a walk plays at the creature's real speed (the walk clip is built for `sizing.speed_of`; a run for 1.9 times that).
  The last frame of an attack or a flinch is the rest pose the idle starts from.
* A gait's stride is `speed * duty * cycle`, so the cycle is chosen from the stride a leg can reach (`plan_gait`) and never longer: no foot may skate or fall short.
* Frames: idle 8, walk 10 to 12, run 10, attack 10, hurt 5, die 8 (hold the last). Hold the anticipation and the impact, make the swing fast.
* `render_set` calls `rig.stand` for a clip with `grounded=True` (a fall, whose feet are not planted: root z is then ignored), `rig.pose` otherwise.
  No part of the model may go below z = 0 in a planted pose (the sprite sits on its lowest point).

## Style (the target is `docs/research/images/art-target/goblin-reference-sheet.png`)

Crouched, wiry, angular; thin tapering limbs with round joints; flat wedge feet; a small head with a brow; flat swept ears; weapons and gear with clear flat silhouettes
(`rigkit.blade`, `rigkit.loft`, `rigkit.sheet`: not ellipsoids); cloth is a thin sheet (`rigkit.sheet` with `Rig.skin` weights) with an uneven hem. A 1 to 2 px gap
between the arm and the body in side view. Keep high values (near white) to small areas; use darker dominant planes and small bright accents. Colours: a dark
creature is lifted (`wolf_kit.room`) so the shading ramps have room. Do not draw anything below the ground line.

## Looking at it

```
python3 tools/art/blender/species_tree.py <species> <form> --out .tmp/x                # render + shade one form of any family: .tmp/x/<form>/frames/<clip>_<n>.png
python3 tools/art/blender/strip.py .tmp/x/<form> idle,walk,run,attack,hurt,die --zoom 3   # every frame in rows: strip.png
python3 tools/art/blender/lookdev.py form1 form2 ... --creature <creature>        # several forms side by side in one pose
python3 tools/art/blender/species_tree.py <species> [--only quads|bipeds] [form ...] --out .tmp/<species>-tree   # the whole tree: tree.png, compare.png, walk.gif
```
(`spike.py <creature> [--variant form]` does the same for goblin, spider and wolf only: its `CURRENT` table (the shipped sheets it compares against) has no undead or slime.)
(`species_tree.py` knows a species by its entry in `SPECIES`.) Always look at the frames, at native size and at 3x to 6x, before saying a pose works.
Scratch output goes in `.tmp/` (ignored). Blender is `/Applications/Blender.app/Contents/MacOS/Blender`.

## Tests (write them first; run the pure ones on every change)

```
python3 -W error::ResourceWarning -m unittest discover -s tools/art/blender -p "test_*.py"     # about 30 s, includes the gated Blender tests
```
* The motion is tested on the flat skeleton with no Blender: feet planted and not sliding (track the sole's own points, not a definition of contact), nothing below
  the ground, every foot reaches its target at every speed and scale the form can have (a sweep), loops close, the attack's timing equals the engine's, the last
  frames equal the rest pose, no tail or cloth through the floor.
* `test_pipeline.py` (skipped without Blender): the flat skeleton equals the real armature in every clip (`probe_pose.py`); every frame of every clip is drawn inside its canvas
  and never below the ground. Add one of each for the new family.
* Check a test can fail: change a constant in the code and watch it go red.

## Putting it in the game (the integrator does this)

```
python3 tools/art/blender/species_tree.py <species> --out .tmp/<species>-tree        # render all forms
python3 tools/art/blender/export_forms.py <species> --from .tmp/<species>-tree        # sheets, normal maps, data/form_clips.json (checks the timings)
python3 tools/build_bestiary.py && TEST_TIMEOUT=1700 tools/run_tests.sh                # the pages and the full suite
tools/shot_run.sh tools/form_anim_shots.gd -- --form=<species>_<form> --out=$PWD/.tmp/form-anim/<name>   # the real Enemy drawing it
```
A twin plays its form's clips when `data/creatures/twin_<species>_<form>.tres` has `form = "<species>_<form>"` and `assets/sheets/anim_<species>_<form>.png` exists. The slime's twins are named bare (`twin_<form>.tres`, `form = "<form>"`, `anim_<form>.png`; shoot one with `--form=<form>`); a form with no twin is left out of the export. `export_base.py <creature>` does the same for a base creature (goblin, gloom_wolf, spider, slime).
