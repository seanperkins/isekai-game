"""The Blender half of the Dead Cells style pipeline (a spike). Runs inside Blender:
    /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/art/blender/render_set.py -- --creature goblin --out DIR

A creature is a handful of low-poly parts (ellipsoids, tapered limbs, cones) bound rigidly to the bones of a real armature, so the .blend
a person opens is an ordinary rigged model. Poses are given as rotations about the WORLD axes at each bone's head (a forward kinematics
solver in `Rig.pose`), which keeps animation tables readable: the camera looks along +Y, X is right, Z is up, and a creature faces +X.

Every frame is rendered twice with Cycles at one sample and no filtering, as emission only: a colour pass (each part's flat albedo) and a
normal pass (the camera-space normal encoded as colour). tools/art/blender/toon.py lights them.
"""
import math

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

NEAR = -1.0  # the side of the creature the camera sees (the camera is at -Y)
LIGHT = (-0.45, 0.70, 0.55)  # where toon.py puts the light; a glowing part's normal points at it, so it is always in the lit band


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return bpy.context.scene


# ---- parts -----------------------------------------------------------------------------------------------------------

def _object(name, bm, smooth):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if smooth:
        for poly in me.polygons:
            poly.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def ellipsoid(name, center, radii, segments=12, rings=8, smooth=True):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * radii[0], v.co.y * radii[1], v.co.z * radii[2])) + Vector(center)
    return _object(name, bm, smooth)


def limb(name, a, b, r0, r1, sides=7, smooth=True, caps=True):
    """A tapered tube from point a (radius r0) to point b (radius r1); a cone when r1 is 0."""
    a, b = Vector(a), Vector(b)
    axis = b - a
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=caps, cap_tris=False, segments=sides, radius1=r0, radius2=r1, depth=axis.length)
    turn = Vector((0, 0, 1)).rotation_difference(axis.normalized()).to_matrix()
    mid = (a + b) / 2.0
    for v in bm.verts:
        v.co = turn @ v.co + mid
    return _object(name, bm, smooth)


def box(name, center, size, smooth=False):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) + Vector(center)
    return _object(name, bm, smooth)


# ---- the rig ---------------------------------------------------------------------------------------------------------

class Rig:
    def __init__(self, name):
        self.data = bpy.data.armatures.new(name)
        self.obj = bpy.data.objects.new(name, self.data)
        bpy.context.scene.collection.objects.link(self.obj)
        self.rest = {}   # bone -> (head, tail, parent)
        self.order = []  # parents before children
        self.parts = []  # (object, rgb 0..255, far)
        self.owner = {}  # part -> the bone it is bound to
        self.glowing = set()  # parts lit whatever their shape: eyes, marks

    def bone(self, name, head, tail, parent=None):
        self.rest[name] = (Vector(head), Vector(tail), parent)
        self.order.append(name)

    def build(self):
        bpy.context.view_layer.objects.active = self.obj
        bpy.ops.object.mode_set(mode="EDIT")
        edit = self.data.edit_bones
        for name in self.order:
            head, tail, parent = self.rest[name]
            b = edit.new(name)
            b.head, b.tail = head, tail
            if parent:
                b.parent = edit[parent]
        bpy.ops.object.mode_set(mode="OBJECT")

    def part(self, ob, bone, rgb, far=False, glow=False):
        """Bind a mesh rigidly to a bone (all its vertices weighted 1.0 to that bone's group) and give it a flat colour."""
        group = ob.vertex_groups.new(name=bone)
        group.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
        mod = ob.modifiers.new("Armature", "ARMATURE")
        mod.object = self.obj
        ob.parent = self.obj
        self.parts.append((ob, rgb, far))
        self.owner[ob] = bone
        if glow:
            self.glowing.add(ob)
        return ob

    def pose(self, rot=None, root=(0.0, 0.0, 0.0)):
        """Set a pose. `rot` maps a bone to (rx, ry, rz) degrees about the world axes at its head, on top of what its parent does;
        `root` moves the whole creature. Parents are solved first."""
        rot = rot or {}
        mats, totals = {}, {}
        for name in self.order:
            head, _, parent = self.rest[name]
            r = Euler(tuple(math.radians(a) for a in rot.get(name, (0, 0, 0))), "XYZ").to_matrix()
            if parent is None:
                carried, rp = Vector(root) + head, Matrix.Identity(3)
            else:
                carried, rp = mats[parent] @ head, totals[parent]
            total = r @ rp
            totals[name] = total
            mats[name] = Matrix.Translation(carried) @ total.to_4x4() @ Matrix.Translation(-head)
        for name in self.order:
            pb = self.obj.pose.bones[name]
            pb.matrix = mats[name] @ pb.bone.matrix_local
            bpy.context.view_layer.update()

    def lowest(self):
        """The lowest world z of any part in the current pose."""
        deps = bpy.context.evaluated_depsgraph_get()
        low = 1e9
        for ob, _, _ in self.parts:
            ev = ob.evaluated_get(deps)
            low = min(low, min((ev.matrix_world @ Vector(c)).z for c in ev.bound_box))
        return low

    def extent(self):
        """(min x, max x, min z, max z) of every part in the current pose."""
        deps = bpy.context.evaluated_depsgraph_get()
        xs, zs = [], []
        for ob, _, _ in self.parts:
            ev = ob.evaluated_get(deps)
            for c in ev.bound_box:
                w = ev.matrix_world @ Vector(c)
                xs.append(w.x)
                zs.append(w.z)
        return min(xs), max(xs), min(zs), max(zs)

    def bounds_of(self, bone):
        """(min x, max x, min z, max z) of the parts bound to `bone` in the current pose, or None."""
        deps = bpy.context.evaluated_depsgraph_get()
        xs, zs = [], []
        for ob, _, _ in self.parts:
            if self.owner[ob] != bone:
                continue
            ev = ob.evaluated_get(deps)
            for c in ev.bound_box:
                w = ev.matrix_world @ Vector(c)
                xs.append(w.x)
                zs.append(w.z)
        return (min(xs), max(xs), min(zs), max(zs)) if xs else None

    def stand(self, rot=None, root=(0.0, 0.0, 0.0)):
        """Pose, then drop or lift the whole creature until its lowest point rests on the ground (z = 0), a stand-in for foot IK.
        The root's z is then a height above the ground (0 for a creature standing, more for a leap)."""
        self.pose(rot, (root[0], root[1], 0.0))
        low = self.lowest()
        self.pose(rot, (root[0], root[1], root[2] - low))


# ---- materials and rendering -----------------------------------------------------------------------------------------

def _emission_material(name, setup):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    tree = mat.node_tree
    tree.nodes.clear()
    out = tree.nodes.new("ShaderNodeOutputMaterial")
    emit = tree.nodes.new("ShaderNodeEmission")
    tree.links.new(emit.outputs["Emission"], out.inputs["Surface"])
    setup(tree, emit)
    return mat


def colour_material(rgb):
    def setup(tree, emit):
        emit.inputs["Color"].default_value = (rgb[0] / 255.0, rgb[1] / 255.0, rgb[2] / 255.0, 1.0)
    return _emission_material("colour_%d_%d_%d" % tuple(rgb), setup)


def normal_material():
    """Emits the camera-space normal as colour: 0.5 + 0.5 * N on each axis."""
    def setup(tree, emit):
        geo = tree.nodes.new("ShaderNodeNewGeometry")
        xform = tree.nodes.new("ShaderNodeVectorTransform")
        xform.vector_type, xform.convert_from, xform.convert_to = "NORMAL", "WORLD", "CAMERA"
        flip = tree.nodes.new("ShaderNodeVectorMath")  # Blender's camera space looks down -Z: make "toward the viewer" +1 (a normal map's blue)
        flip.operation = "MULTIPLY"
        flip.inputs[1].default_value = (1.0, 1.0, -1.0)
        half = tree.nodes.new("ShaderNodeVectorMath")
        half.operation = "MULTIPLY_ADD"
        half.inputs[1].default_value = (0.5, 0.5, 0.5)
        half.inputs[2].default_value = (0.5, 0.5, 0.5)
        tree.links.new(geo.outputs["Normal"], xform.inputs["Vector"])
        tree.links.new(xform.outputs["Vector"], flip.inputs[0])
        tree.links.new(flip.outputs["Vector"], half.inputs[0])
        tree.links.new(half.outputs["Vector"], emit.inputs["Color"])
    return _emission_material("normal", setup)


def setup_camera(scene, canvas, ppu, margin, supersample, center_x=0.0):
    """A side-on orthographic camera: `canvas` game pixels square at `ppu` pixels per unit, the ground `margin` pixels above the bottom."""
    data = bpy.data.cameras.new("cam")
    data.type = "ORTHO"
    data.ortho_scale = canvas / ppu
    cam = bpy.data.objects.new("cam", data)
    cam.location = (center_x, -20.0, canvas / (2.0 * ppu) - margin / ppu)
    cam.rotation_euler = (math.radians(90), 0.0, 0.0)
    scene.collection.objects.link(cam)
    scene.camera = cam
    r = scene.render
    r.engine = "CYCLES"
    r.resolution_x = r.resolution_y = canvas * supersample
    r.resolution_percentage = 100
    r.film_transparent = True
    r.image_settings.file_format = "PNG"
    r.image_settings.color_mode = "RGBA"
    r.image_settings.color_depth = "8"
    c = scene.cycles
    c.device = "CPU"
    c.samples = 1
    c.use_adaptive_sampling = False
    c.use_denoising = False
    c.filter_width = 0.01
    scene.view_settings.view_transform = "Raw"
    scene.view_settings.look = "None"


def glow_normal_material():
    """A normal that faces the light exactly: a part wearing it always takes the brightest band."""
    n = LIGHT
    length = math.sqrt(sum(c * c for c in n))

    def setup(tree, emit):
        emit.inputs["Color"].default_value = tuple(0.5 + 0.5 * c / length for c in n) + (1.0,)
    return _emission_material("glow_normal", setup)


FAR_SHADE = 0.8  # parts on the far side of the creature are drawn this much darker


def shown_colour(rgb, far):
    return tuple(int(c * FAR_SHADE) for c in rgb) if far else tuple(rgb)


def render_passes(scene, rig, path_prefix):
    """Write <prefix>_albedo.png and <prefix>_normal.png for the current pose."""
    mats = {}
    for ob, rgb, far in rig.parts:
        mats[ob] = colour_material(shown_colour(rgb, far))
    for ob, mat in mats.items():
        ob.data.materials.clear()
        ob.data.materials.append(mat)
    scene.render.filepath = path_prefix + "_albedo.png"
    bpy.ops.render.render(write_still=True)
    nm, gm = normal_material(), glow_normal_material()
    for ob in mats:
        ob.data.materials.clear()
        ob.data.materials.append(gm if ob in rig.glowing else nm)
    scene.render.filepath = path_prefix + "_normal.png"
    bpy.ops.render.render(write_still=True)
