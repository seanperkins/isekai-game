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
import copy
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import stage  # noqa: E402
import verb_anims  # noqa: E402

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
STATE_CLIP = {"idle": "idle", "walk": "walk", "run": "run", "rise": "rise", "fall": "fall", "land": "land", "wall": "wall", "mantle": "mantle", "slide": "slide", "roll": "roll",
              "cast": "attack"}
GAITS = ("walk", "run")
# the engine's time for a verb: the windup before it fires and the recovery after it (scripts/enemies/enemy.gd VERB_WINDUP and VERB_RECOVER; export_forms.check_timing reads them)
CAST_WINDUP = 0.35
CAST_RECOVER = 0.30


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


def authored_speed(gait, walk_speed, run_factor=RUN_SPEED):
    """The speed a gait's clip was built for: the form's walk speed, and a run's is `run_factor` times that (RUN_SPEED, but a creature may build its run for more:
    the base wolf's is its charge)."""
    return walk_speed * run_factor if gait == "run" else walk_speed


def stride_of(clip, gait, walk_speed, run_factor=RUN_SPEED):
    """The ground (game px) one cycle of the gait covers at the speed it was built for."""
    return authored_speed(gait, walk_speed, run_factor) * sum(clip.durations)


# ---- states ------------------------------------------------------------------------------------------------------------------------

def _gait_of(speed, walk_speed):
    if speed <= MOVING:
        return "idle"
    return "run" if speed > walk_speed * RUN_RATIO else "walk"


def state_of(tick, walk_speed):
    """The state a recorded tick is posed in (not counting a landing, which needs the ticks before it: see `states_of`). A body that crawls (the spider's) is on its
    gait whatever it crawls on: its walk is turned to lie on the surface (`surface_angle`), it is not a wall or a ceiling pose."""
    surface = tick["surface"]
    speed = tick.get("speed", abs(tick["vx"]))
    if tick.get("cast"):
        return "cast"  # a verb being cast: its gesture, whatever the body is doing under it
    if surface == "mantle":
        return "mantle"
    if tick["verb"]:
        return tick["verb"]
    if tick.get("crawl") and surface != "air":
        return _gait_of(speed, walk_speed)
    if surface in ("wall", "ceiling"):
        return surface
    if surface == "air" or not tick["on_floor"]:
        return "rise" if tick["vy"] < 0.0 else "fall"
    return _gait_of(speed, walk_speed)


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


def surface_angle(normal):
    """The turn about the camera's axis (degrees, Blender's Y) that lays a body's up on the surface it is on, given the surface's normal in game px (y down)."""
    return math.degrees(math.atan2(normal[0], -normal[1]))


class Frame:
    """One output frame of a review: which tick, where the body is, how it is posed. `angle` turns the body onto a surface it crawls; `missing` names the state it has no pose for
    (the pose shown is then the last one it had)."""
    def __init__(self, tick, t, x, y, facing, state, pose, phase, travel, angle=0.0, missing=None, normal=None):
        self.tick, self.t, self.x, self.y, self.facing, self.state = tick, t, x, y, facing, state
        self.normal = normal
        self.clip, self.frame, self.rot, self.root, self.grounded = pose.clip, pose.frame, pose.rot, pose.root, pose.grounded
        self.phase, self.travel, self.angle, self.missing = phase, travel, angle, missing


def _clip_and_phase(clips, state, k, run_start, run_len, fps, gait_phase, speed, walk_speed, run_factor, cast_t=None):
    """(clip name, phase, the gait phase after this tick) for a tick in `state`: a gait turns by speed over stride, any other clip runs by the time spent in the state."""
    if state in GAITS:
        clip = clips.get(state)
        if clip is None:
            raise NoPose(state, state)
        authored = authored_speed(state, walk_speed, run_factor)
        eff = min(max(speed, RATE_RANGE[0] * authored), RATE_RANGE[1] * authored)
        gait_phase += phase_rate(eff, stride_of(clip, state, walk_speed, run_factor)) / fps
        return state, gait_phase, gait_phase
    name = STATE_CLIP.get(state, "")
    clip = clips.get(name)
    if clip is None:
        raise NoPose(state, name)
    if state == "cast" and cast_t is not None:  # a gesture runs by the time since the cast began, the clip's own length being the engine's windup and recovery
        return name, cast_t / sum(clip.durations), gait_phase
    if clip.loop or len(clip.frames) == 1:
        return name, (k - run_start[k]) / fps / sum(clip.durations), gait_phase
    return name, (k - run_start[k]) / float(run_len[k]), gait_phase


def playback(recording, clips, walk_speed, every=1, hold_missing=False, run_factor=RUN_SPEED):
    """Every `every`th tick of a recording as a Frame. A gait's phase is cumulative cycles, advanced every tick by the body's speed over the gait's stride (the speed kept within
    the game's playback range of the one the clip was built for); any other clip runs by the time spent in its state, a clip that does not loop by how far through the state it is.
    A state the creature has no pose for raises NoPose, or with `hold_missing` keeps the last pose it had and marks the frame `missing`."""
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
    travel, gait_phase, shown, facing = 0.0, 0.0, None, ticks[0]["facing"] if ticks else 1
    for k, t in enumerate(ticks):
        if k:
            prev = ticks[k - 1]
            if t.get("crawl") and "body" in t and "body" in prev:  # a crawler goes along its surface, up a wall as well as across a floor
                travel += math.hypot(t["body"][0] - prev["body"][0], t["body"][1] - prev["body"][1])
            else:
                travel += abs(t["x"] - prev["x"])
        state = states[k]
        crawling = bool(t.get("crawl")) and t["surface"] != "air"
        angle = surface_angle(t["normal"]) if crawling else 0.0
        if crawling and k:
            along = (t["x"] - ticks[k - 1]["x"]) * math.cos(math.radians(angle)) + (-(t["y"] - ticks[k - 1]["y"])) * -math.sin(math.radians(angle))
            if abs(along) > 1e-6:
                facing = 1 if along > 0.0 else -1
        elif not crawling:
            facing = t["facing"]
        missing = None
        try:
            name, phase, gait_phase = _clip_and_phase(clips, state, k, run_start, run_len, fps, gait_phase, t.get("speed", abs(t["vx"])), walk_speed, run_factor, t.get("cast_t"))
            pose = pose_for(clips, state, phase)
        except NoPose:
            if not hold_missing or shown is None:
                raise
            missing, pose, phase = state, shown, 0.0
        shown = pose
        if k % every == 0:
            out.append(Frame(k, t["t"], t["x"], t["y"], facing, state, pose, phase, travel, angle, missing, tuple(t["normal"])))
    return out


def slide_px(frames, clips, walk_speed, run_factor=RUN_SPEED):
    """How far the playback would drag a planted foot over the ground, the most in one step between frames: the body went `travel` px while the gait's phase advanced by `phase`
    cycles, which puts the foot back by phase times the stride. This checks the playback's arithmetic (clamped rates show here); `contact_slide` measures the feet themselves.
    Zero for a body that is not walking or running."""
    worst = 0.0
    for a, b in zip(frames, frames[1:]):
        if a.state == b.state and a.state in GAITS and a.normal == b.normal and not (a.missing or b.missing):  # not over a corner, where the surface turns
            stride = stride_of(clips[a.state], a.state, walk_speed, run_factor)
            worst = max(worst, abs((b.travel - a.travel) - (b.phase - a.phase) * stride))
    return worst


def missing_states(recording, clip_names, walk_speed):
    """The states a recorded run puts a creature in that none of its clips poses (the names of the clips it has go in `clip_names`), sorted."""
    needed = set(states_of(recording["ticks"], walk_speed))
    return sorted(s for s in needed if STATE_CLIP.get(s) not in clip_names)


SPECIES = ["goblin", "undead", "wolf", "spider", "slime"]
# what the recorder can run for each species (tools/movement_recorder.gd SCRIPTS_FOR)
RUNS = {"goblin": ["walk_run", "jump_ledges", "wall_shaft"], "undead": ["walk_run", "jump_ledges", "wall_shaft"], "slime": ["walk_run", "jump_ledges", "wall_shaft"],
        "wolf": ["walk_run", "jump_ledges", "pounce"], "spider": ["walk_run", "jump_ledges", "crawl"]}


# ---- the feet themselves ----------------------------------------------------------------------------------------------------------

class Change:
    """A gait changing pose: to which `frame` of the clip of `state`, with the body at (x, y) at that very moment (between two ticks), and the frame it is posed as. `run` numbers
    the stretch of one unbroken gait it belongs to: two changes of one run are two steps of the same stride, however slow."""
    def __init__(self, state, frame, x, y, pose_frame, run=0):
        self.state, self.frame, self.x, self.y, self.pose_frame, self.run = state, frame, x, y, pose_frame, run
        self.rot, self.root, self.grounded = pose_frame.rot, pose_frame.root, pose_frame.grounded


def pose_changes(frames, clips, walk_speed, run_factor=RUN_SPEED):
    """The moments a walk or a run goes on to its next pose, from `frames` posed every tick: for each, where the body is when the gait's phase reaches the new frame, worked out between
    the two ticks it falls between. A planted foot is judged at these moments (the pose is the gait sampled exactly there), not where the ticks fall."""
    out, run, was = [], 0, None
    for a, b in zip(frames, frames[1:]):
        gait = a.state == b.state and a.state in GAITS and a.normal == b.normal and not (a.missing or b.missing)
        if not gait:
            was = None  # standing, in the air, a verb: the stride is broken
            continue
        if was is None or a.state != was:
            run += 1
        was = a.state
        if a.frame == b.frame or b.phase <= a.phase:
            continue
        durations = clips[b.clip].durations
        start = sum(durations[:b.frame]) / sum(durations)
        t = min(max((math.floor(b.phase) + start - a.phase) / (b.phase - a.phase), 0.0), 1.0)
        out.append(Change(a.state, b.frame, a.x + t * (b.x - a.x), a.y + t * (b.y - a.y), b, run))
    return out


def contact_spans(points_by_bone):
    """Where the rig's mesh rests on the ground: `points_by_bone` maps each bone to the (x, z) of the vertices of its parts that are on it, and each bone that touches gets the span
    (first x, last x) of them. A foot is the bone its sole is bound to, so a foot stays itself from one step to the next whatever the other feet do."""
    return {bone: (min(x for x, _ in pts), max(x for x, _ in pts)) for bone, pts in points_by_bone.items() if pts}


def contact_slide(previous, current):
    """How far the bones that rest on the ground in both `previous` and `current` (bone -> span) have been dragged along it, the most of any. A foot that rolls (heel, flat, toe) keeps one
    end of its patch where it came down, so a bone is dragged by the smaller move of its two ends; a bone that was in the air or is now has just come down or left and is not counted."""
    return max([min(abs(current[b][0] - previous[b][0]), abs(current[b][1] - previous[b][1])) for b in current if b in previous] or [0.0])


def gif_durations(count, fps):
    """The duration of each of `count` frames played at `fps`, in milliseconds a GIF can store (hundredths of a second): the rounding is shared out by where each frame starts, so the
    loop takes as long as it should instead of every frame being rounded the same way."""
    start = lambda i: int(round(i * 1000.0 / fps / 10.0)) * 10
    return [start(i + 1) - start(i) for i in range(count)]


def positive_int(text):
    """argparse type: a whole number of at least 1."""
    try:
        n = int(text)
    except ValueError:
        raise argparse.ArgumentTypeError("%r is not a whole number" % text)
    if n < 1:
        raise argparse.ArgumentTypeError("%d is not at least 1" % n)
    return n


# the gestures (verb_anims.ARCHETYPES) each creature's base body has no preset for yet, by creature module (the next tasks author them): checked against the real creatures by test_stage_gaps.py
KNOWN_ARCHETYPES = {
    "goblin": [],
    "undead": [],
    "wolf": ["cast", "craft", "drink", "point", "pulse", "sneak", "summon", "throw"],
    "spider": ["craft", "drink", "guard", "point", "pulse", "roar", "sneak", "summon"],
    "slime": ["craft", "drink", "guard", "point", "roar", "sneak", "summon"],
}


# the gaps in what each species can be posed in, by the scripts it is recorded on: states the recorded run reaches that none of its clips poses yet (the verb motions are
# the next plan). Checked against the real creatures by test_stage_gaps.py: a gap that closes or a new one fails there until this says so.
KNOWN_MISSING = {
    "wolf": {"jump_ledges": ["fall", "rise"], "pounce": ["pounce"]},
    "spider": {"jump_ledges": ["fall", "rise"]},
    "slime": {"jump_ledges": ["fall", "rise"], "wall_shaft": ["fall", "rise", "wall"]},
}


# ---- the recording and the course --------------------------------------------------------------------------------------------------

def cast_recording(archetype, windup=CAST_WINDUP, recover=CAST_RECOVER, fps=60, lead=0.3, tail=0.3, x=100.0):
    """A recording of a body that stands where the course starts and casts a verb of gesture `archetype` once: it stands for `lead` seconds, casts for the engine's windup and
    recovery (the ticks carry `cast` and the seconds since it began, `cast_t`) and stands for `tail` more. The gesture is judged on its own, the body does not move."""
    def tick(i, cast_t=None):
        return {"t": round(i / fps, 4), "x": x, "y": 0.0, "vx": 0.0, "vy": 0.0, "speed": 0.0, "crawl": False, "facing": 1, "verb": "", "on_floor": True, "surface": "floor",
                "normal": [0.0, -1.0], "cast": archetype if cast_t is not None else "", "cast_t": cast_t if cast_t is not None else 0.0}
    n_lead, n_cast, n_tail = int(round(lead * fps)), int(round(windup * fps)) + int(round(recover * fps)), int(round(tail * fps))
    ticks = [tick(i) for i in range(n_lead)]
    ticks += [tick(n_lead + i, round(i / fps, 4)) for i in range(n_cast)]
    ticks += [tick(n_lead + n_cast + i) for i in range(n_tail)]
    return {"species": "gesture", "script": "gesture_" + archetype, "fps": fps, "start": [x, 0.0], "ticks": ticks}


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
    """({name: clip}, ppu, walk speed, run factor) of a creature module's form: the clips it was authored with, the scale it is drawn at, the speed its walk was built for and how many
    times faster its run was (a creature says so with `run_factor(variant)`; the rest are RUN_SPEED)."""
    clips, ppu = creature.clips_of(rig, variant)
    factor = creature.run_factor(variant) if hasattr(creature, "run_factor") else RUN_SPEED
    return clips, ppu, creature.motion(variant), factor


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


FOOT_EPS_PX = 0.6      # a vertex this close to the ground is resting on it
NO_FEET = ("slime",)   # a jelly hops; it has no foot to plant


def _pose_rig(rig, f, ppu, frozen=None):
    """Put the rig where frame `f` says it is, posed as it says (or as `frozen`, a (rot, root, grounded) tuple, says instead): the same thing the render does."""
    x, z = stage.px_to_units(f.x, ppu), stage.px_to_units(-f.y, ppu)
    rot, root, grounded = frozen if frozen else (f.rot, f.root, f.grounded)
    rig.obj.scale = (float(f.facing), 1.0, 1.0)
    rig.obj.rotation_euler = (0.0, math.radians(f.angle), 0.0)
    if grounded:  # set on the ground by its lowest point, then lifted to where the body is
        rig.obj.location = (x, 0.0, 0.0)
        rig.stand(rot, (0.0, 0.0, z))
    else:  # a stance carries its own root; the body's place is the rig's, so a body turned onto a wall is turned about its contact
        rig.obj.location = (x, 0.0, z)
        rig.pose(rot, root)


def resting_points(rig, ground_z, eps):
    """{bone: [(x, z)]}: the vertices of every part of the rig, in the world as posed, that are within `eps` of the ground at `ground_z`, by the bone the part is bound to."""
    import bpy
    from mathutils import Vector
    deps = bpy.context.evaluated_depsgraph_get()
    points = {}
    for ob, _, _ in rig.parts:
        ev = ob.evaluated_get(deps)
        mw = ev.matrix_world
        if min((mw @ Vector(c)).z for c in ev.bound_box) > ground_z + eps:
            continue
        mesh = ev.to_mesh()
        for v in mesh.vertices:
            w = mw @ v.co
            if w.z <= ground_z + eps:
                points.setdefault(rig.owner[ob], []).append((w.x, w.z))
        ev.to_mesh_clear()
    return points


def foot_slide_px(rig, frames, clips, walk_speed, run_factor, ppu, frozen=None):
    """How far a planted foot moves over the ground from one pose of a gait to the next, the most of any, measured on the posed meshes. The rig is posed at each moment the gait changes pose
    (`pose_changes`, with the body where it really is then) and where each bone's vertices rest on the ground is compared with the pose before: a foot that is planted stays where it came
    down, so what it moves is the animation's error (the feet drifting with the body between two poses is the frame rate's, and nobody's to fix). `frozen` poses every moment the same way
    instead: a check that the measure notices feet that do not move."""
    worst, before, last = 0.0, None, None
    for c in pose_changes(frames, clips, walk_speed, run_factor):
        if c.pose_frame.angle != 0.0:
            before = None
            continue
        f = copy.copy(c.pose_frame)
        f.x, f.y = c.x, c.y
        _pose_rig(rig, f, ppu, frozen)
        spans = contact_spans(resting_points(rig, stage.px_to_units(-f.y, ppu), stage.px_to_units(FOOT_EPS_PX, ppu)))
        if before is not None and c.run == last:  # the next pose of the same unbroken gait, however slow: not a walk handing over to a run or starting again after a stop
            worst = max(worst, contact_slide(before, spans) * ppu)
        before, last = spans, c.run
    return worst


def gaps(args):
    """Without rendering: for each recording, the states the creature has no pose for and how far a foot is dragged; printed as one `GAPS {json}` line."""
    import rigkit
    creature = _load(args.creature)
    rigkit.reset()
    rig = creature.build(args.variant)
    clips, ppu, walk_speed, run_factor = clips_for(creature, rig, args.variant)
    with open(args.course) as fh:
        course = json.load(fh)
    out = {}
    for path in args.recording:
        with open(path) as fh:
            rec = json.load(fh)
        out[rec["script"]] = _report(rec, clips, walk_speed, run_factor, course, rig, ppu, args.creature, args.frozen_feet)
    print("GAPS " + json.dumps(out))


def _report(rec, clips, walk_speed, run_factor, course, rig, ppu, creature, frozen=False):
    """What is wrong with a recorded run for a creature: the states it has no pose for, how far the playback drags a foot (the arithmetic) and how far a foot actually moves on the posed meshes."""
    check_recording(rec, course)
    frames = playback(rec, clips, walk_speed, 1, hold_missing=True, run_factor=run_factor)
    out = {"missing": missing_states(rec, set(clips), walk_speed), "slide_px": round(slide_px(frames, clips, walk_speed, run_factor), 4), "foot_slide_px": None}
    if creature not in NO_FEET and rec["script"] == "walk_run":  # the walk is what a foot is judged on: the same motion drives the rest
        idle = frames[0]
        out["foot_slide_px"] = round(foot_slide_px(rig, frames, clips, walk_speed, run_factor, ppu, (idle.rot, idle.root, idle.grounded) if frozen else None), 4)
    return out


def gesture_gaps(args):
    """Without rendering: the gestures of verb_anims.ARCHETYPES this creature has no preset for, printed as one `GESTURES {json}` line."""
    import rigkit
    creature = _load(args.creature)
    rigkit.reset()
    rig = creature.build(args.variant)
    lacking = []
    for name in verb_anims.ARCHETYPES:
        try:
            creature.gesture_clip(rig, args.variant, name)
        except KeyError:
            lacking.append(name)
    print("GESTURES " + json.dumps({"missing": lacking}))


def render(args):
    import bpy
    import rigkit
    with open(args.course) as fh:
        course = json.load(fh)
    creature = _load(args.creature)
    scene = rigkit.reset()
    rig = creature.build(args.variant)
    clips, ppu, walk_speed, run_factor = clips_for(creature, rig, args.variant)
    rigkit.setup_camera(scene, 64, ppu, 0, 1)  # the bake's engine settings; the camera is then made a tracking one
    cam = scene.camera
    cam.data.ortho_scale = stage.tracking_camera_params(args.view_px, ppu, 0.0, 0.0)["ortho_scale"]
    view_w, view_h = args.size
    scene.render.resolution_x, scene.render.resolution_y = view_w, view_h
    _world(scene)
    _build_course(course_boxes(course, ppu), rigkit)
    own = {ob: rigkit.colour_material(rigkit.shown_colour(rgb, far)) for ob, rgb, far in rig.parts}
    red = rigkit.colour_material((225, 45, 45))  # a pose the creature does not have is shown held, in red
    for ob, mat in own.items():
        ob.data.materials.clear()
        ob.data.materials.append(mat)
    tinted = False
    runs, lacking = [], []  # (recording, the clips it is played with, its folder)
    if args.gesture:
        for name in (verb_anims.ARCHETYPES if args.gesture == "all" else [args.gesture]):
            try:
                gesture = creature.gesture_clip(rig, args.variant, name)
            except KeyError:
                lacking.append(name)  # a gap, named: nothing is rendered for a gesture the creature cannot play
                continue
            runs.append((cast_recording(name), dict(clips, attack=gesture), "gesture_" + name))
    for path in args.recording or []:
        with open(path) as fh:
            runs.append((json.load(fh), clips, None))
    for recording, run_clips, folder in runs:
        check_recording(recording, course)
        frames = playback(recording, run_clips, walk_speed, args.every, hold_missing=not args.strict, run_factor=run_factor)
        view_path = camera_path(frames, ppu, args.view_px, args.view_px * view_h / view_w)
        out = os.path.join(args.out, folder) if folder else (args.out if len(runs) == 1 else os.path.join(args.out, recording["script"]))
        os.makedirs(out, exist_ok=True)
        log = []
        for n, (f, (cx, cz)) in enumerate(zip(frames, view_path)):
            cam.location = stage.tracking_camera_params(args.view_px, ppu, cx, cz)["location"]
            _pose_rig(rig, f, ppu)
            if bool(f.missing) != tinted:
                tinted = bool(f.missing)
                for ob, mat in own.items():
                    ob.data.materials.clear()
                    ob.data.materials.append(red if tinted else mat)
            scene.render.filepath = os.path.join(out, "frame_%04d.png" % n)
            bpy.ops.render.render(write_still=True)
            log.append({"frame": n, "tick": f.tick, "t": f.t, "x": f.x, "y": f.y, "state": f.state, "clip": f.clip, "clip_frame": f.frame, "facing": f.facing,
                        "angle": round(f.angle, 2), "missing": f.missing or ""})
        meta = {"creature": args.creature, "variant": args.variant or "", "script": recording["script"], "ppu": ppu, "walk_speed": walk_speed, "view_px": args.view_px,
                "every": args.every, "fps": float(recording.get("fps", 60)) / args.every, "frames": log}
        meta.update(_report(recording, run_clips, walk_speed, run_factor, course, rig, ppu, args.creature))
        with open(os.path.join(out, "review.json"), "w") as fh:
            json.dump(meta, fh)
        print("%s %s: %d frames in %s" % (args.creature, recording["script"], len(frames), out))
    if args.gesture:
        with open(os.path.join(args.out, "gesture_gaps.json"), "w") as fh:
            json.dump({"missing": lacking}, fh)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--creature", required=True)
    ap.add_argument("--variant")
    ap.add_argument("--recording", nargs="*", help="one or more recordings (tools/record_movement.gd); with several, --out gets a folder for each script")
    ap.add_argument("--gesture", help="a gesture of verb_anims.ARCHETYPES (or `all`) cast in place instead of a recording; --out gets a folder gesture_<name> for each")
    ap.add_argument("--gesture-gaps", action="store_true", help="print the gestures the creature has no preset for and render nothing")
    ap.add_argument("--course", default=os.path.join(HERE, "..", "stage_course.json"))
    ap.add_argument("--out")
    ap.add_argument("--every", type=positive_int, default=3, help="pose every Nth recorded tick (60 ticks a second)")
    ap.add_argument("--size", default="640x360", help="the render, WxH")
    ap.add_argument("--view-px", type=float, default=360.0, help="how many game pixels wide the view is")
    ap.add_argument("--strict", action="store_true", help="stop at a state the creature has no pose for instead of holding the last pose in red")
    ap.add_argument("--gaps", action="store_true", help="print the missing states and the planted-foot slide of each recording and render nothing")
    ap.add_argument("--frozen-feet", action="store_true", help="with --gaps: measure the feet with every walking frame posed as the first (a check that the measure notices)")
    a = ap.parse_args(argv)
    a.size = tuple(int(v) for v in a.size.split("x"))
    if a.gesture_gaps:
        gesture_gaps(a)
    elif a.gaps:
        if not a.recording:
            ap.error("--gaps needs --recording")
        gaps(a)
    else:
        if not (a.recording or a.gesture):
            ap.error("give --recording or --gesture")
        if not a.out:
            ap.error("--out is required to render")
        render(a)


if __name__ == "__main__":
    main()
