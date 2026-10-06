"""The movement review on the photo stage: a rig moves over the game's own course along a path the game recorded (tools/record_movement.gd), before anything is baked to 2D.
Runs in Blender for the render and in plain Python for everything else, so the logic is tested without it:

    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/art/blender/stage_review.py -- --creature goblin --recording R.json --out DIR

(tools/art/stage_review.py is the command that records, renders and assembles the GIF.)

A recorded tick says where the body is, how fast it goes and what it is doing (floor, air, wall, mantle, a verb). `states_of` turns that into the state a creature is posed in,
with the game's own rules (scripts/forms/form_pose.gd: a walk plays as fast as the body goes against the speed it was built for, a body is running above 1.35 times its walk);
`playback` walks the recording and gives each frame its clip, frame and phase, a gait's phase advancing by the speed over the stride so a planted foot does not skate;
`pose_for` is the one lookup from a state to a pose, and says `NoPose` for a state the creature was never given instead of showing its idle.
"""
import argparse
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import stage  # noqa: E402

# the game's rules for playing a gait (scripts/forms/form_pose.gd; test_stage_review.py keeps these equal to it)
RUN_RATIO = 1.35
RUN_SPEED = 1.9
RATE_RANGE = (0.2, 4.0)
MOVING = 1.0          # px/s: slower than this a body is standing (scripts/enemies/enemy.gd)
LAND_TICKS = 6        # how long a hard landing shows its crouch
LAND_MIN_VY = 150.0   # px/s: a fall faster than this lands hard
STRIPE_PX = 32        # the floor is striped this wide, so a body that slides over it shows it
CAP_PX = 3.0          # the lighter line along the top of every solid
GROUND_MARGIN_PX = 24.0  # the ground stays this far above the bottom of the frame while the body is low
FOLLOW = 0.15         # how much of the way the camera goes to its target each frame
DEPTH = 1.0           # how thick the course is behind the creature, in units; its front face is FRONT units behind the creature's middle
FRONT = 0.2

# the clip each state is posed with; a state not listed here has no pose until someone gives it one
STATE_CLIP = {"idle": "idle", "walk": "walk", "run": "run", "rise": "rise", "fall": "fall", "land": "land", "wall": "wall", "mantle": "mantle", "slide": "slide", "roll": "roll"}
GAITS = ("walk", "run")


class NoPose(Exception):
    """A creature has no pose for a state the recorded run puts it in."""
    def __init__(self, state, clip=""):
        super().__init__("no pose for the state %r%s" % (state, " (it has no %r clip)" % clip if clip else ""))
        self.state = state
        self.clip = clip


class BadRecording(Exception):
    """A recorded run that cannot be reviewed: it never lands, or the body fell out of the course."""


# ---- rates -------------------------------------------------------------------------------------------------------------------------

def phase_rate(speed, stride):
    """Cycles per second a gait turns at when the body goes `speed` px/s and one cycle covers `stride` px: the planted foot then stays planted."""
    return speed / stride


def authored_speed(gait, walk_speed):
    """The speed a gait's clip was built for: the form's walk speed, and a run's is RUN_SPEED times that."""
    return walk_speed * RUN_SPEED if gait == "run" else walk_speed


def stride_of(clip, gait, walk_speed):
    """The ground (game px) one cycle of the gait covers at the speed it was built for."""
    return authored_speed(gait, walk_speed) * sum(clip.durations)


# ---- states ------------------------------------------------------------------------------------------------------------------------

def state_of(tick, walk_speed):
    """The state a recorded tick is posed in (not counting a landing, which needs the ticks before it: see `states_of`)."""
    surface = tick["surface"]
    if surface == "mantle":
        return "mantle"
    if tick["verb"]:
        return tick["verb"]
    if surface in ("wall", "ceiling"):
        return surface
    if surface == "air" or not tick["on_floor"]:
        return "rise" if tick["vy"] < 0.0 else "fall"
    speed = abs(tick["vx"])
    if speed <= MOVING:
        return "idle"
    return "run" if speed > walk_speed * RUN_RATIO else "walk"


def states_of(ticks, walk_speed):
    """The state of every tick. A body that comes down hard and stands there crouches for LAND_TICKS."""
    states = [state_of(t, walk_speed) for t in ticks]
    hold = 0
    for i, t in enumerate(ticks):
        if i and states[i - 1] == "fall" and ticks[i - 1]["vy"] >= LAND_MIN_VY and states[i] == "idle":
            hold = LAND_TICKS
        if hold and states[i] == "idle":
            states[i] = "land"
            hold -= 1
        else:
            hold = 0
    return states


# ---- poses -------------------------------------------------------------------------------------------------------------------------

class Pose:
    """What a creature does in a state at a phase: the clip, the frame of it, the bone rotations and root, and whether the rig is set on the ground after."""
    def __init__(self, clip, frame, rot, root, grounded):
        self.clip, self.frame, self.rot, self.root, self.grounded = clip, frame, rot, root, grounded


def frame_at(durations, phase):
    """The frame showing at `phase` (cycles, wrapped to 0..1) of a clip whose frames last `durations`."""
    total = sum(durations)
    at = (phase % 1.0) * total
    done = 0.0
    for i, d in enumerate(durations):
        done += d
        if done > at + 1e-9:
            return i
    return len(durations) - 1


def pose_for(clips, state, phase):
    """The pose of `state` at `phase` from the creature's clips ({name: clip with frames, durations, loop, grounded}), or NoPose naming the state."""
    name = STATE_CLIP.get(state)
    if name is None:
        raise NoPose(state)
    clip = clips.get(name)
    if clip is None:
        raise NoPose(state, name)
    i = frame_at(clip.durations, phase)
    rot, root = clip.frames[i]
    return Pose(name, i, rot, root, clip.grounded)


class Frame:
    """One output frame of a review: which tick, where the body is, how it is posed."""
    def __init__(self, tick, t, x, y, facing, state, pose, phase, travel):
        self.tick, self.t, self.x, self.y, self.facing, self.state = tick, t, x, y, facing, state
        self.clip, self.frame, self.rot, self.root, self.grounded = pose.clip, pose.frame, pose.rot, pose.root, pose.grounded
        self.phase, self.travel = phase, travel


def playback(recording, clips, walk_speed, every=1):
    """Every `every`th tick of a recording as a Frame. A gait's phase is cumulative cycles, advanced every tick by the body's speed over the gait's stride (the speed kept within
    the game's playback range of the one the clip was built for); any other clip runs by the time spent in its state, a clip that does not loop by how far through the state it is."""
    ticks = recording["ticks"]
    fps = float(recording.get("fps", 60))
    states = states_of(ticks, walk_speed)
    run_start, run_len = {}, {}
    i = 0
    while i < len(ticks):  # how long each stretch of one state lasts
        j = i
        while j < len(ticks) and states[j] == states[i]:
            j += 1
        for k in range(i, j):
            run_start[k], run_len[k] = i, j - i
        i = j
    out = []
    phase, travel, gait_phase = 0.0, 0.0, 0.0
    for k, t in enumerate(ticks):
        if k:
            travel += abs(t["x"] - ticks[k - 1]["x"])
        state = states[k]
        if state in GAITS:
            clip = clips.get(state)
            if clip is None:
                raise NoPose(state, state)
            authored = authored_speed(state, walk_speed)
            speed = min(max(abs(t["vx"]), RATE_RANGE[0] * authored), RATE_RANGE[1] * authored)
            gait_phase += phase_rate(speed, stride_of(clip, state, walk_speed)) / fps
            phase = gait_phase
        else:
            clip = clips.get(STATE_CLIP.get(state, ""))
            if clip is None:
                raise NoPose(state, STATE_CLIP.get(state, ""))
            if clip.loop or len(clip.frames) == 1:
                phase = (k - run_start[k]) / fps / sum(clip.durations)
            else:
                phase = (k - run_start[k]) / float(run_len[k])
        if k % every == 0:
            out.append(Frame(k, t["t"], t["x"], t["y"], t["facing"], state, pose_for(clips, state, phase), phase, travel))
    return out


# ---- the recording and the course --------------------------------------------------------------------------------------------------

def check_recording(recording, course):
    """Raise BadRecording unless the run can be reviewed: it has ticks, ends on something and never leaves the course (the floor's width, the top of the walls, the floor's bottom)."""
    ticks = recording["ticks"]
    if not ticks:
        raise BadRecording("the recording is empty")
    fx, fy, fw, fh = course["floor"]
    top = min(w[1] for w in course["walls"])
    for i, t in enumerate(ticks):
        if t["x"] < fx or t["x"] > fx + fw or t["y"] < top or t["y"] > fy + fh:
            raise BadRecording("the body leaves the course at tick %d (%.0f, %.0f)" % (i, t["x"], t["y"]))
    if ticks[-1]["surface"] == "air":
        raise BadRecording("the run never lands: it ends in the air at (%.0f, %.0f)" % (ticks[-1]["x"], ticks[-1]["y"]))


class Box:
    """One block of the course in stage units: x0..x1 across, z0..z1 up, of a kind (floor_a, floor_b, solid, oneway, slick, hostile, cap)."""
    def __init__(self, name, kind, x0, x1, z0, z1):
        self.name, self.kind, self.x0, self.x1, self.z0, self.z1 = name, kind, x0, x1, z0, z1


def _box(name, kind, rect, ppu):
    x, y, w, h = rect
    return Box(name, kind, stage.px_to_units(x, ppu), stage.px_to_units(x + w, ppu), stage.px_to_units(-(y + h), ppu), stage.px_to_units(-y, ppu))


KIND_OF = {"oneway_ledge": "oneway", "slick_block": "slick", "slick_ceiling": "slick", "dummy": "hostile"}


def course_boxes(course, ppu):
    """The blocks of the course the game exported (tools/art/stage_course.json), in stage units at `ppu` pixels to the unit: the floor in alternating stripes, a lighter cap on
    the top of every solid, the dummy as a hostile marker."""
    boxes = []
    for key, value in course.items():
        if key in ("y_axis", "start"):
            continue
        rects = value if isinstance(value[0], list) else [value]
        for n, rect in enumerate(rects):
            name = key if len(rects) == 1 and not isinstance(value[0], list) else "%s_%d" % (key, n)
            if key == "floor":
                x, y, w, h = rect
                for s in range(-(-int(w) // STRIPE_PX)):
                    x0 = x + s * STRIPE_PX
                    boxes.append(_box("floor_%d" % s, "floor_a" if s % 2 == 0 else "floor_b", [x0, y, min(STRIPE_PX, x + w - x0), h], ppu))
                continue
            kind = KIND_OF.get(key, "solid")
            boxes.append(_box(name, kind, rect, ppu))
            if kind != "hostile":
                x, y, w, h = rect
                boxes.append(_box(name + "_cap", "cap", [x, y, w, CAP_PX], ppu))
    boxes += [_box("floor_cap", "cap", [course["floor"][0], course["floor"][1], course["floor"][2], CAP_PX], ppu)]
    return boxes


def camera_path(frames, ppu, view_w_px, view_h_px):
    """(x, z) in units of the camera for each frame: it follows the body, eased, keeps the ground in the frame while the body is low and keeps the body in the frame when it climbs."""
    view_h = view_h_px / ppu
    floor_cz = view_h / 2.0 - GROUND_MARGIN_PX / ppu
    out, cx, cz = [], None, None
    for f in frames:
        tx, tz = stage.px_to_units(f.x, ppu), max(floor_cz, stage.px_to_units(-f.y, ppu) + 0.12 * view_h)
        cx, cz = (tx, tz) if cx is None else (cx + FOLLOW * (tx - cx), cz + FOLLOW * (tz - cz))
        out.append((cx, cz))
    return out


# ---- the clips of a creature, from what its module builds --------------------------------------------------------------------------

def clips_for(creature, rig, variant):
    """({name: clip}, ppu, walk speed) of a creature module's form: the clips it was authored with, the scale it is drawn at and the speed its walk was built for."""
    clips, ppu = creature.clips_of(rig, variant)
    return clips, ppu, creature.motion(variant)


# ---- Blender -----------------------------------------------------------------------------------------------------------------------

COLOURS = {  # kind: (front face, cap)
    "floor_a": (96, 100, 118), "floor_b": (80, 84, 102), "solid": (128, 112, 92), "oneway": (150, 130, 96), "slick": (84, 120, 140),
    "hostile": (190, 60, 60), "cap": (205, 205, 215),
}
BACKGROUND = (0.07, 0.08, 0.11, 1.0)


def _load(name):
    import importlib.util
    spec = importlib.util.spec_from_file_location("creature_" + name, os.path.join(HERE, "creatures", name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _build_course(boxes, rigkit):
    import bmesh
    import bpy
    mats = {kind: rigkit.colour_material(rgb) for kind, rgb in COLOURS.items()}
    for b in boxes:
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co.x = b.x0 + (v.co.x + 0.5) * (b.x1 - b.x0)
            v.co.y = FRONT + (v.co.y + 0.5) * DEPTH
            v.co.z = b.z0 + (v.co.z + 0.5) * (b.z1 - b.z0)
        me = bpy.data.meshes.new(b.name)
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new(b.name, me)
        bpy.context.scene.collection.objects.link(ob)
        ob.data.materials.append(mats[b.kind])
        if b.kind == "hostile":
            ob.location.y = -0.3  # the dummy hangs in front of the body, not behind it


def _world(scene):
    import bpy
    world = bpy.data.worlds.new("stage")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = BACKGROUND
    scene.world = world
    scene.render.film_transparent = False


def render(args):
    import bpy
    import rigkit
    course = json.load(open(args.course))
    recording = json.load(open(args.recording))
    check_recording(recording, course)
    creature = _load(args.creature)
    scene = rigkit.reset()
    rig = creature.build(args.variant)
    clips, ppu, walk_speed = clips_for(creature, rig, args.variant)
    frames = playback(recording, clips, walk_speed, args.every)  # a NoPose stops here: nothing is rendered for a creature that cannot be posed
    view_w, view_h = args.size
    path = camera_path(frames, ppu, args.view_px, args.view_px * view_h / view_w)
    rigkit.setup_camera(scene, 64, ppu, 0, 1)  # the bake's engine settings; the camera is then made a tracking one
    cam = scene.camera
    cam.data.ortho_scale = stage.tracking_camera_params(args.view_px, ppu, 0.0, 0.0)["ortho_scale"]
    scene.render.resolution_x, scene.render.resolution_y = view_w, view_h
    _world(scene)
    _build_course(course_boxes(course, ppu), rigkit)
    for ob, rgb, far in rig.parts:
        ob.data.materials.clear()
        ob.data.materials.append(rigkit.colour_material(rigkit.shown_colour(rgb, far)))
    os.makedirs(args.out, exist_ok=True)
    log = []
    for n, (f, (cx, cz)) in enumerate(zip(frames, path)):
        x, z = stage.px_to_units(f.x, ppu), stage.px_to_units(-f.y, ppu)
        cam.location = stage.tracking_camera_params(args.view_px, ppu, cx, cz)["location"]
        rig.obj.scale.x = float(f.facing)
        rig.obj.location.x = x
        if f.grounded:
            rig.stand(f.rot, (0.0, 0.0, z))
        else:
            rig.pose(f.rot, (f.root[0], f.root[1], f.root[2] + z))
        scene.render.filepath = os.path.join(args.out, "frame_%04d.png" % n)
        bpy.ops.render.render(write_still=True)
        log.append({"frame": n, "tick": f.tick, "t": f.t, "x": f.x, "y": f.y, "state": f.state, "clip": f.clip, "clip_frame": f.frame, "facing": f.facing})
    json.dump({"creature": args.creature, "variant": args.variant or "", "ppu": ppu, "walk_speed": walk_speed, "view_px": args.view_px, "every": args.every,
               "fps": float(recording.get("fps", 60)) / args.every, "frames": log}, open(os.path.join(args.out, "review.json"), "w"))
    print("%s: %d frames in %s" % (args.creature, len(frames), args.out))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--creature", required=True)
    ap.add_argument("--variant")
    ap.add_argument("--recording", required=True)
    ap.add_argument("--course", default=os.path.join(HERE, "..", "stage_course.json"))
    ap.add_argument("--out", required=True)
    ap.add_argument("--every", type=int, default=3, help="pose every Nth recorded tick (60 ticks a second)")
    ap.add_argument("--size", default="640x360", help="the render, WxH")
    ap.add_argument("--view-px", type=float, default=360.0, help="how many game pixels wide the view is")
    a = ap.parse_args(argv)
    a.size = tuple(int(v) for v in a.size.split("x"))
    render(a)


if __name__ == "__main__":
    main()
