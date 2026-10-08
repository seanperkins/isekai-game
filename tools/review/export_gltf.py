"""Export a form's rig and every clip it plays as a glTF, for the review page's 3D view.

    python3 tools/review/export_gltf.py <species> <form> --out DIR        (form: the species' base form, e.g. `goblin goblin`, or any of its tree)

Writes DIR/model.glb (the meshes, the armature, one animation per clip) and DIR/model.json ({"form", "clips": {name: seconds}}). Run it from plain Python and it
runs itself again inside Blender. The poses are the ones the sprites are rendered from: the creature module's `build` and `setup`, and each clip's frame function,
in the same order as render_set.py. Each frame is kept for its own duration on a 50 fps grid (the engine's 20 ms tick), and a looping clip ends on its first pose.
"""
import importlib.util
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BLENDER_DIR = os.path.join(os.path.dirname(HERE), "art", "blender")
BLENDER = os.environ.get("BLENDER", "/Applications/Blender.app/Contents/MacOS/Blender")
FPS = 50
BASE_FORMS = {"goblin": "goblin", "wolf": "gloom_wolf", "spider": "spider", "undead": "skeleton", "slime": "slime"}   # as species_tree.SPECIES names the base
CREATURE_OF = {"goblin": "goblin", "wolf": "wolf", "spider": "spider", "undead": "undead", "slime": "slime"}

try:
    import bpy
except ImportError:
    bpy = None


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def load_creature(name):
    spec = importlib.util.spec_from_file_location("creature_" + name, os.path.join(BLENDER_DIR, "creatures", name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def forms_of(species):
    spec = importlib.util.spec_from_file_location(species + "_forms", os.path.join(BLENDER_DIR, species + "_forms.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.FORMS


def frame_times(durations, loop):
    """Where each frame starts, in seconds, and the clip's length: the sum of the durations (a duration under one tick counts as one)."""
    starts, t = [], 0.0
    for d in durations:
        starts.append(t)
        t += max(float(d), 1.0 / FPS)
    return starts, t


def colour_materials(rig):
    """A plain colour material for each part (the render's own are emission-only), lit parts emissive."""
    import rigkit
    cache = {}
    for ob, rgb, far in rig.parts:
        shown = rigkit.shown_colour(rgb, far)
        glow = ob in rig.glowing
        key = (shown, glow)
        if key not in cache:
            mat = bpy.data.materials.new("c%d_%d_%d%s" % (shown + ("g" if glow else "",)))
            mat.use_nodes = True
            node = mat.node_tree.nodes["Principled BSDF"]
            linear = tuple(srgb_to_linear(c / 255.0) for c in shown) + (1.0,)
            node.inputs["Base Color"].default_value = linear
            node.inputs["Roughness"].default_value = 0.9
            node.inputs["Metallic"].default_value = 0.0
            if glow:
                node.inputs["Emission Color"].default_value = linear
                node.inputs["Emission Strength"].default_value = 1.0
            cache[key] = mat
        ob.data.materials.clear()
        ob.data.materials.append(cache[key])


def bake_clip(rig, name, frames, durations, loop, grounded):
    """Bake one clip into an action; returns (action, length in seconds). The action is not on a track yet (see push_track).

    The rig has nothing animating it while it is posed: each pose's bone values are recorded first and written as keys afterwards. An animation that is attached
    while posing is evaluated by every later `rig.pose`, which pulls the bones back toward it: a landing exported after the idle ramped from the idle's pose to its own."""
    anim = rig.obj.animation_data
    anim.action = None
    starts, total = frame_times(durations, loop)
    pose = rig.stand if grounded else rig.pose
    keys = [(starts[i], frames[i]) for i in range(len(frames))]
    keys.append((total, frames[0] if loop else frames[-1]))   # a loop ends where it began; a one-shot holds its last frame
    recorded = []
    for t, (rot, root) in keys:
        pose(rot, root)
        recorded.append((round(t * FPS), [(pb.name, tuple(pb.location), tuple(pb.rotation_quaternion), tuple(pb.scale)) for pb in rig.obj.pose.bones]))   # frame 0 is time 0
    action = bpy.data.actions.new(name)
    anim.action = action
    for frame, bones in recorded:
        for bone, location, rotation, scale in bones:
            pb = rig.obj.pose.bones[bone]
            pb.location, pb.rotation_quaternion, pb.scale = location, rotation, scale
            pb.keyframe_insert("location", frame=frame)
            pb.keyframe_insert("rotation_quaternion", frame=frame)
            pb.keyframe_insert("scale", frame=frame)
    anim.action = None
    return action, total


def push_track(rig, name, action):
    """Put a baked action on a track of its own, at full strength. Done only after every clip is baked: a track that exists while the next clip is posed is evaluated
    and corrupts that pose."""
    track = rig.obj.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 0, action)
    strip.blend_type, strip.influence, strip.blend_in, strip.blend_out, strip.use_auto_blend = "REPLACE", 1.0, 0.0, 0.0, False


def export(species, form, out_dir):
    import rigkit
    base = BASE_FORMS[species]
    variant = None if form == base else form
    creature_name = (forms_of(species).get(form) or {}).get("creature", CREATURE_OF[species]) if variant else CREATURE_OF[species]
    creature = load_creature(creature_name)
    scene = rigkit.reset()
    scene.render.fps, scene.render.fps_base = FPS, 1.0
    bpy.context.preferences.edit.keyframe_new_interpolation_type = "LINEAR"
    rig = creature.build(variant)
    cfg = creature.setup(rig, variant)
    if rig.post_pose is not None:
        raise RuntimeError("%s %s deforms its meshes from the pose (its vertices move, not only its bones), which a glTF of bone animation cannot carry: "
                           "its model would show no squash, breathing or collapse" % (species, form))
    colour_materials(rig)
    rig.obj.animation_data_create()
    rig.pose({}, (0.0, 0.0, 0.0))
    baked = {}
    for name, (count, fn, grounded) in cfg["anims"].items():
        durations = cfg["extra"]["durations"][name]
        loop = cfg["extra"]["loops"].get(name, name in ("idle", "walk", "run"))
        baked[name] = bake_clip(rig, name, [fn(i, count) for i in range(count)], durations, loop, grounded)
    clips = {}
    for name, (action, length) in baked.items():
        push_track(rig, name, action)
        clips[name] = length
    rig.pose({}, (0.0, 0.0, 0.0))
    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, "model.glb"), export_format="GLB", export_animations=True, export_animation_mode="NLA_TRACKS",
                              export_force_sampling=True, export_skins=True, export_cameras=False, export_lights=False, export_yup=True, use_selection=False)
    with open(os.path.join(out_dir, "model.json"), "w") as fh:
        json.dump({"form": form if variant else base, "species": species, "clips": {k: round(v, 4) for k, v in clips.items()}}, fh, indent=1)
    return clips


def main(argv):
    import argparse
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("species", choices=sorted(BASE_FORMS))
    ap.add_argument("form")
    ap.add_argument("--out", required=True)
    ap.add_argument("--art", help="the checkout whose tools/art/blender to build the form from (default: this one)")
    args = ap.parse_args(argv)
    global BLENDER_DIR
    if args.art:
        BLENDER_DIR = os.path.join(os.path.abspath(args.art), "tools", "art", "blender")
    sys.path.insert(0, BLENDER_DIR)
    clips = export(args.species, args.form, os.path.abspath(args.out))
    print("EXPORT_COMPLETE %s %s %s" % (args.species, args.form, json.dumps(clips)), flush=True)


if __name__ == "__main__":
    if bpy is not None:
        main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    else:
        argv = sys.argv[1:]
        done = subprocess.run([BLENDER, "-b", "--factory-startup", "-P", os.path.abspath(__file__), "--"] + argv, capture_output=True, text=True)
        sys.stdout.write("".join(l + "\n" for l in done.stdout.splitlines() if l.startswith("EXPORT_COMPLETE")))
        if done.returncode != 0 or "EXPORT_COMPLETE" not in done.stdout:
            sys.exit("Blender failed:\n" + done.stdout[-2500:] + done.stderr[-2500:])
