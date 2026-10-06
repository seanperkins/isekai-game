# The slime family in the Blender pipeline

The plain blue jelly slime and its eighteen stage-four forms, built like the wolf and the goblin (`docs/art-kit-guide.md`) but on a soft body
instead of a skeleton of limbs. Everything is in `tools/art/blender/`.

| File | What it is |
|---|---|
| `slime_motion.py` (pure) | The rest dome (`Shape`), the deformation (`deform`), the body (`SlimeBody`: a root bone and the form's chains), every clip |
| `slime_forms.py` (pure) | The forms as data: shape, colours, chains, loose-part groups, flags (hover, stiff, attack), gear; `speed_of` |
| `slime_kit.py`, `slime_gear.py` | The Blender meshes: the dome, its rim and ink shells, inner glow, gloss, eyes; one function per piece of gear |
| `creatures/slime.py` | `build(variant)`, `setup(rig, variant)` (the wolf's contract) |
| `probe_slime.py`, `check_slime_tree.py` | The Blender probe for the gated tests; a check of a rendered tree (timing, canvas, ground) |
| `test_slime_motion.py`, `test_pipeline.py` | The pure tests; the gated ones (the hook, the real jelly against the pure maths, frames in their canvas) |

## The soft body

`Rig.pose` turns bones only, so `rigkit.Rig` has one additive hook, `post_pose(rig, rot, root)`, called after the bones are solved. A frame carries
its soft parameters in its rotation table under the key `_soft` (no bone has that name, so `Rig.pose`, `skeleton2d` and `secondary` ignore it):
`sq` (height scale), `vol` (volume kept), `lean`, `bulge`/`bc`, `wave`/`phase`, and `off` (per-group moves of loose parts: a blink, a thrown
pebble, a dropped crown, plates clattering off, the cloud dispersing, the inner stone lagging). The deformation is z' = z sq, x and y scaled by
sqrt(vol / sq), with the sideways terms growing from zero at the base: the base never leaves the ground or shears, and the volume is kept to
first order. Appendages (tentacles, vine, ribbon ends, pelt, miasma, drips, pseudopods, the mimic's lid) are bone chains rooted on the surface;
the hook moves each chain's first bone by where the deformed surface took its root, and each link chases its direction on a spring (lag against
the root's velocity, deliberate sway or lash), so it follows through.

## Movement

A slime hops: `walk` is a hop of 12 frames (landing squash on the first, rebound, anticipation coil, stretch at take-off, a parabolic flight),
`run` a longer, higher one of 10 at 1.9 times the speed. While the base is down, it moves back in the sprite's frame at the speed; in the air,
the body flies forward, so a cycle covers speed times cycle. The cycle is chosen for a hop of 0.75 (run 1.2) body widths and shortened if that
is more than the body can throw itself. The cloud rider and the poltergeist glide with a bob instead. Attack frames and hurt frames are the
wolf's (windup 0.35 s in five frames, recovery 0.30 s, flinch 0.25 s), ending on the idle's first frame. Styles: lunge, slam (cube, talos:
stiff), lash (kraken, shoggoth, beanstalk), bite (mimic), throw (poltergeist), pulse (king).

## For the integrator

Handled, and kept here as the reasons for the code:

* The slime twins are `data/creatures/twin_<form>.tres` with `form = "<form>"` (not `twin_slime_<form>` like the other families), and their sheets are
  `anim_<form>`. `sizing.twin_path`, `export_forms.form_id` and `BASES` (`"slime": "slime"`) know it, so `export_forms.py slime` installs under
  the bare form ids; shoot one with `--form=<form>` (not `slime_<form>`).
* `slime_forms.speed_of` reads the twin's own file (every form: spd 80, sprite size 1.4, so 34.3 px/s).
* `species_tree.py slime` lays the forms out one per row (their stage-three parents, snare, arachne, tempest..., belong to other species, so
  every form's `parent` is the base and its real branch is kept as `branch`).
* `spike.py` has no slime entry (its `CURRENT` table holds goblin, spider and wolf): render a slime form with `species_tree.py slime <form> --out .tmp/x`.
