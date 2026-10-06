"""Runs Blender headless (skipped when it is not installed): the render passes must mean what toon.py assumes."""
import json
import os
import subprocess
import sys
import tempfile
import unittest

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
BLENDER = os.environ.get("BLENDER", "/Applications/Blender.app/Contents/MacOS/Blender")


def blender(*args):
    done = subprocess.run([BLENDER, "-b", *args], capture_output=True, text=True)
    return done


@unittest.skipUnless(os.path.exists(BLENDER), "Blender is not installed")
class PipelineTest(unittest.TestCase):
    def test_the_normal_pass_encodes_right_up_and_toward_the_viewer(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "sphere.png")
            blender("-P", os.path.join(HERE, "probe_sphere.py"), "--", path)
            with Image.open(path) as im:
                n = im.convert("RGBA")
            w, h = n.size
            cx, cy, r = w // 2, h - 16 * 4, int(0.38 * 32 * 4)  # the sphere's centre sits 16 game px above the ground
            def near(px, want):
                for got, expect in zip(px[:3], want):
                    self.assertAlmostEqual(got, expect, delta=6)
            near(n.getpixel((cx, cy)), (128, 128, 255))        # facing the viewer: blue
            self.assertGreater(n.getpixel((cx + r, cy))[0], 230)  # facing right: red
            self.assertGreater(n.getpixel((cx, cy - r))[1], 230)  # facing up: green
            self.assertLess(n.getpixel((cx - r, cy))[0], 25)      # facing left: no red

    def render(self, creature, tmp):
        done = blender("-P", os.path.join(HERE, "render_set.py"), "--", "--creature", creature, "--out", tmp, "--anims", "idle", "--ss", "2")
        self.assertEqual(done.returncode, 0, done.stdout[-1500:] + done.stderr[-1500:])
        with open(os.path.join(tmp, "meta.json")) as fh:
            return json.load(fh)

    def test_every_creature_renders_both_passes_inside_its_canvas_and_stands_on_the_ground(self):
        for creature in ("goblin", "spider", "wolf"):
            with self.subTest(creature=creature), tempfile.TemporaryDirectory() as tmp:
                meta = self.render(creature, tmp)
                size = meta["canvas"] * meta["ss"]
                for i in range(meta["anims"]["idle"]):
                    with Image.open(os.path.join(tmp, "idle_%d_albedo.png" % i)) as a, Image.open(os.path.join(tmp, "idle_%d_normal.png" % i)) as n:
                        albedo, normal = a.convert("RGBA"), n.convert("RGBA")
                    self.assertEqual(albedo.size, (size, size))
                    box = albedo.split()[3].point(lambda v: 255 if v > 127 else 0).getbbox()
                    self.assertIsNotNone(box, "something is drawn")
                    self.assertGreater(box[0], 0)
                    self.assertGreater(box[1], 0)
                    self.assertLess(box[2], size)
                    ground = size - meta["margin"] * meta["ss"]
                    self.assertAlmostEqual(box[3], ground, delta=meta["ss"] * 2, msg="the lowest pixel rests on the ground line")
                    self.assertEqual(albedo.split()[3].getbbox(), normal.split()[3].getbbox(), "both passes cover the same pixels")

    def render_anim(self, creature, anim, tmp):
        done = blender("-P", os.path.join(HERE, "render_set.py"), "--", "--creature", creature, "--out", tmp, "--anims", anim, "--ss", "2")
        self.assertEqual(done.returncode, 0, done.stdout[-1500:] + done.stderr[-1500:])
        with open(os.path.join(tmp, "meta.json")) as fh:
            return json.load(fh)

    def test_a_galloping_wolf_has_frames_on_the_ground_and_frames_in_the_air(self):
        with tempfile.TemporaryDirectory() as tmp:
            meta = self.render_anim("wolf", "run", tmp)
            ground = (meta["canvas"] - meta["margin"]) * meta["ss"]
            bottoms = []
            for i in range(meta["anims"]["run"]):
                with Image.open(os.path.join(tmp, "run_%d_albedo.png" % i)) as a:
                    bottoms.append(a.convert("RGBA").split()[3].point(lambda v: 255 if v > 127 else 0).getbbox()[3])
            self.assertTrue(any(abs(b - ground) <= meta["ss"] for b in bottoms), "a paw is down in some frame")
            self.assertTrue(any(b < ground - 3 * meta["ss"] for b in bottoms), "and in some frame every paw is off the ground")

    def test_glowing_parts_take_the_lit_band_whatever_their_shape(self):
        lit = tuple(int(round((0.5 + 0.5 * c / 0.99) * 255)) for c in (-0.45, 0.70, 0.55))
        for creature in ("goblin", "spider", "wolf"):
            with self.subTest(creature=creature), tempfile.TemporaryDirectory() as tmp:
                self.render(creature, tmp)
                with Image.open(os.path.join(tmp, "idle_0_normal.png")) as n:
                    px = list(n.convert("RGBA").get_flattened_data())
                glowing = [p for p in px if p[3] and all(abs(a - b) <= 4 for a, b in zip(p[:3], lit))]
                self.assertGreater(len(glowing), 4, "the eyes and marks face the light")

    def test_a_goblin_form_fits_its_canvas_stands_on_the_ground_and_keeps_the_footprint_of_the_still_it_replaces(self):
        with open(os.path.join(HERE, "before", "forms_goblin.json")) as fh:
            before = json.load(fh)["frames"]
        for form in ("hob", "rat_king", "beast_rider"):  # a stout one, one with a backpack of rats, one on a wolf
            with self.subTest(form=form), tempfile.TemporaryDirectory() as tmp:
                done = blender("-P", os.path.join(HERE, "render_set.py"), "--", "--creature", "goblin", "--variant", form, "--out", tmp, "--anims", "idle", "--ss", "2")
                self.assertEqual(done.returncode, 0, done.stdout[-1500:] + done.stderr[-1500:])
                with open(os.path.join(tmp, "meta.json")) as fh:
                    meta = json.load(fh)
                size, ss = meta["canvas"] * meta["ss"], meta["ss"]
                for i in range(meta["anims"]["idle"]):
                    with Image.open(os.path.join(tmp, "idle_%d_albedo.png" % i)) as a:
                        box = a.convert("RGBA").split()[3].point(lambda v: 255 if v > 127 else 0).getbbox()
                    self.assertGreater(box[0], 0)
                    self.assertLess(box[2], size)
                    self.assertGreater(box[1], 0)
                    self.assertAlmostEqual(box[3], size - meta["margin"] * ss, delta=ss)
                with Image.open(os.path.join(tmp, "idle_0_albedo.png")) as a:
                    box = a.convert("RGBA").split()[3].point(lambda v: 255 if v > 127 else 0).getbbox()
                w, h = (box[2] - box[0]) / ss, (box[3] - box[1]) / ss
                rect = before[form]["rect"]
                self.assertTrue(0.6 < (w * h) / (rect[2] * rect[3]) < 1.7, "%s covers %.0f px against %d before" % (form, w * h, rect[2] * rect[3]))

    def test_every_frame_of_every_goblin_clip_is_drawn_inside_its_canvas_and_never_below_the_ground(self):
        with tempfile.TemporaryDirectory() as tmp:
            done = blender("-P", os.path.join(HERE, "render_set.py"), "--", "--creature", "goblin", "--variant", "hob", "--out", tmp, "--ss", "1")
            self.assertEqual(done.returncode, 0, done.stdout[-1500:] + done.stderr[-1500:])
            with open(os.path.join(tmp, "meta.json")) as fh:
                meta = json.load(fh)
            size, ground = meta["canvas"], meta["canvas"] - meta["margin"]
            self.assertEqual(set(meta["anims"]), {"idle", "walk", "run", "attack", "hurt", "die"})
            for anim, count in meta["anims"].items():
                self.assertEqual(len(meta["durations"][anim]), count, anim)
                for i in range(count):
                    with Image.open(os.path.join(tmp, "%s_%d_albedo.png" % (anim, i))) as a:
                        box = a.convert("RGBA").split()[3].point(lambda v: 255 if v > 127 else 0).getbbox()
                    self.assertIsNotNone(box, "%s %d is drawn" % (anim, i))
                    self.assertTrue(box[0] > 0 and box[1] > 0 and box[2] < size, "%s %d is inside the canvas: %s" % (anim, i, box))
                    self.assertLessEqual(box[3], ground + 1, "%s %d is not below the ground" % (anim, i))
                    if anim in ("idle", "die") and i == count - 1 or anim == "idle":
                        self.assertGreaterEqual(box[3], ground - 1, "%s %d stands on the ground" % (anim, i))

    def test_the_flat_skeleton_the_motion_is_tested_on_matches_the_real_armature_in_every_clip(self):
        sys.path.insert(0, HERE)
        import goblin_forms as forms
        import goblin_skeleton as gs
        for variant in ("redcap", "tomte"):
            with self.subTest(variant=variant), tempfile.TemporaryDirectory() as tmp:
                path = os.path.join(tmp, "pose.json")
                done = blender("-P", os.path.join(HERE, "probe_pose.py"), "--", path, variant)
                self.assertTrue(os.path.exists(path), done.stdout[-1500:] + done.stderr[-1500:])
                with open(path) as fh:
                    probes = json.load(fh)
                form = forms.FORMS[variant]
                skel = gs.skeleton(gs.BASE_BX * form.get("bx", 1.0), gs.BASE_TALL * form.get("tall", 1.0), extra=gs.ears(form.get("ears", 1.0)))
                self.assertEqual({p["clip"] for p in probes}, {"idle", "walk", "run", "attack", "hurt", "die"})
                for probe in probes:
                    posed = skel.pose({k: tuple(v) for k, v in probe["rot"].items()}, tuple(probe["root"]))
                    for bone, (head, tail, _) in posed.items():
                        want_head, want_tail = probe["bones"][bone]
                        for got, want in ((head, want_head), (tail, want_tail)):
                            self.assertAlmostEqual(got[0], want[0], delta=1e-4, msg="%s %d %s" % (probe["clip"], probe["frame"], bone))
                            self.assertAlmostEqual(got[1], want[1], delta=1e-4, msg="%s %d %s" % (probe["clip"], probe["frame"], bone))

    def test_the_flat_canine_skeleton_matches_the_real_armature_in_every_clip(self):
        sys.path.insert(0, HERE)
        import quad_skeleton as qs
        import wolf_forms
        for variant in ("gloom_wolf", "dire_wolf", "wepwawet"):
            with self.subTest(variant=variant), tempfile.TemporaryDirectory() as tmp:
                path = os.path.join(tmp, "pose.json")
                done = blender("-P", os.path.join(HERE, "probe_pose.py"), "--", path, variant, "wolf")
                self.assertTrue(os.path.exists(path), done.stdout[-1500:] + done.stderr[-1500:])
                with open(path) as fh:
                    probes = json.load(fh)
                form = wolf_forms.FORMS[variant]
                skel = qs.skeleton(leg=form.get("leg", 1.0), neck=form.get("neck", 1.0), tail=form.get("tail", 1.0), head=form.get("head", 1.0),
                                   tail_shape=form.get("tail_shape", qs.TAIL_DROOPING))
                self.assertEqual({p["clip"] for p in probes}, {"idle", "walk", "run", "attack", "hurt", "die"})
                for probe in probes:
                    posed = skel.pose({k: tuple(v) for k, v in probe["rot"].items()}, tuple(probe["root"]))
                    for bone, (head, tail, _) in posed.items():
                        want_head, want_tail = probe["bones"][bone]
                        for got, want in ((head, want_head), (tail, want_tail)):
                            self.assertAlmostEqual(got[0], want[0], delta=1e-4, msg="%s %d %s" % (probe["clip"], probe["frame"], bone))
                            self.assertAlmostEqual(got[1], want[1], delta=1e-4, msg="%s %d %s" % (probe["clip"], probe["frame"], bone))

    def test_the_flat_wolf_man_skeleton_matches_the_real_armature_in_every_clip(self):
        sys.path.insert(0, HERE)
        import werewolf_skeleton as ws
        import wolf_forms
        for variant in ("moonbound", "beast_of_gevaudan"):
            with self.subTest(variant=variant), tempfile.TemporaryDirectory() as tmp:
                path = os.path.join(tmp, "pose.json")
                done = blender("-P", os.path.join(HERE, "probe_pose.py"), "--", path, variant, "werewolf")
                self.assertTrue(os.path.exists(path), done.stdout[-1500:] + done.stderr[-1500:])
                with open(path) as fh:
                    probes = json.load(fh)
                form = wolf_forms.FORMS[variant]
                skel = ws.skeleton(tall=form.get("tall", 1.0), arm=form.get("arm", 1.0))
                self.assertEqual({p["clip"] for p in probes}, {"idle", "walk", "run", "attack", "hurt", "die"})
                for probe in probes:
                    posed = skel.pose({k: tuple(v) for k, v in probe["rot"].items()}, tuple(probe["root"]))
                    for bone, (head, tail, _) in posed.items():
                        want_head, want_tail = probe["bones"][bone]
                        for got, want in ((head, want_head), (tail, want_tail)):
                            self.assertAlmostEqual(got[0], want[0], delta=1e-4, msg="%s %d %s" % (probe["clip"], probe["frame"], bone))
                            self.assertAlmostEqual(got[1], want[1], delta=1e-4, msg="%s %d %s" % (probe["clip"], probe["frame"], bone))

    def test_every_frame_of_every_wolf_man_clip_is_drawn_inside_its_canvas_and_never_below_the_ground(self):
        with tempfile.TemporaryDirectory() as tmp:
            done = blender("-P", os.path.join(HERE, "render_set.py"), "--", "--creature", "werewolf", "--variant", "wolfskin_champion", "--out", tmp, "--ss", "1")
            self.assertEqual(done.returncode, 0, done.stdout[-1500:] + done.stderr[-1500:])
            with open(os.path.join(tmp, "meta.json")) as fh:
                meta = json.load(fh)
            size, ground = meta["canvas"], meta["canvas"] - meta["margin"]
            self.assertEqual(set(meta["anims"]), {"idle", "walk", "run", "attack", "hurt", "die"})
            for anim, count in meta["anims"].items():
                for i in range(count):
                    with Image.open(os.path.join(tmp, "%s_%d_albedo.png" % (anim, i))) as a:
                        box = a.convert("RGBA").split()[3].point(lambda v: 255 if v > 127 else 0).getbbox()
                    self.assertIsNotNone(box, "%s %d is drawn" % (anim, i))
                    self.assertTrue(box[0] > 0 and box[1] > 0 and box[2] < size, "%s %d is inside the canvas: %s" % (anim, i, box))
                    self.assertLessEqual(box[3], ground + 1, "%s %d is not below the ground" % (anim, i))

    def test_every_frame_of_every_wolf_clip_is_drawn_inside_its_canvas_and_never_below_the_ground(self):
        with tempfile.TemporaryDirectory() as tmp:
            done = blender("-P", os.path.join(HERE, "render_set.py"), "--", "--creature", "wolf", "--variant", "warg", "--out", tmp, "--ss", "1")
            self.assertEqual(done.returncode, 0, done.stdout[-1500:] + done.stderr[-1500:])
            with open(os.path.join(tmp, "meta.json")) as fh:
                meta = json.load(fh)
            size, ground = meta["canvas"], meta["canvas"] - meta["margin"]
            self.assertEqual(set(meta["anims"]), {"idle", "walk", "run", "attack", "hurt", "die"})
            for anim, count in meta["anims"].items():
                self.assertEqual(len(meta["durations"][anim]), count, anim)
                for i in range(count):
                    with Image.open(os.path.join(tmp, "%s_%d_albedo.png" % (anim, i))) as a:
                        box = a.convert("RGBA").split()[3].point(lambda v: 255 if v > 127 else 0).getbbox()
                    self.assertIsNotNone(box, "%s %d is drawn" % (anim, i))
                    self.assertTrue(box[0] > 0 and box[1] > 0 and box[2] < size, "%s %d is inside the canvas: %s" % (anim, i, box))
                    self.assertLessEqual(box[3], ground + 1, "%s %d is not below the ground" % (anim, i))

    def test_a_rig_calls_its_post_pose_hook_after_the_bones_and_poses_the_same_without_one(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "hook.json")
            done = blender("-P", os.path.join(HERE, "probe_slime.py"), "--", path, "--hook")
            self.assertTrue(os.path.exists(path), done.stdout[-1500:] + done.stderr[-1500:])
            with open(path) as fh:
                probe = json.load(fh)
            self.assertEqual(len(probe["seen"]), 1, "called once per pose")
            self.assertEqual(probe["seen"][0]["rot"], {"arm": [0, -30, 0]})
            self.assertEqual(probe["seen"][0]["root"], [0.5, 0, 0])
            self.assertTrue(probe["seen"][0]["same_rig"])
            self.assertEqual(probe["seen"][0]["bones"], probe["plain"]["bones"], "the hook sees the bones already solved")
            self.assertNotEqual(probe["seen"][0]["bones"], probe["unposed"], "(which differ from the unposed rig)")
            self.assertEqual(probe["plain"]["bones"], probe["hooked"]["bones"], "the bones are solved as before")
            moved = [b[2] - a[2] for a, b in zip(probe["plain"]["verts"], probe["hooked"]["verts"])]
            self.assertGreater(max(moved), 0.1, "what the hook does to a mesh shows in the pose")

    def test_the_slimes_real_jelly_and_bones_are_where_the_pure_soft_body_puts_them(self):
        sys.path.insert(0, HERE)
        import slime_forms
        import slime_motion as sm
        for form in ("slime", "kraken", "poltergeist", "mimic"):
            with self.subTest(form=form), tempfile.TemporaryDirectory() as tmp:
                path = os.path.join(tmp, "probe.json")
                done = blender("-P", os.path.join(HERE, "probe_slime.py"), "--", path, form)
                self.assertTrue(os.path.exists(path), done.stdout[-1500:] + done.stderr[-1500:])
                with open(path) as fh:
                    probe = json.load(fh)
                body = sm.SlimeBody(slime_forms.FORMS[form])
                self.assertEqual({f["clip"] for f in probe["frames"]}, {"idle", "walk", "run", "attack", "hurt", "die"})
                rest = [tuple(v) for v in probe["rest"]]
                ours = body.shape.mesh()[0]
                self.assertEqual(len(rest), len(ours))
                for f in probe["frames"]:
                    rot = {k: (tuple(v) if isinstance(v, list) else v) for k, v in f["rot"].items()}
                    root = tuple(f["root"])
                    soft = sm.soft_of(rot)
                    for v, got in list(zip(rest, f["jelly"]))[::5]:
                        want = sm.deform(v, soft, body.shape)
                        for g, w in zip(got, (want[0] + root[0], want[1] + root[1], want[2] + root[2])):
                            self.assertAlmostEqual(g, w, delta=1e-4, msg="%s %s %d" % (form, f["clip"], f["frame"]))
                    posed = sm.pose_bones(body, rot, root)
                    for ch in body.chains:     # a chain's root is carried in depth too, so it stays on the surface as the body spreads
                        want = sm.deform(ch["anchor"], soft, body.shape)[1] + root[1]
                        self.assertAlmostEqual(f["depth"][ch["name"]], want, delta=1e-4, msg="%s %s %d %s depth" % (form, f["clip"], f["frame"], ch["name"]))
                    for bone, (head, tail, _) in posed.items():
                        want_head, want_tail = f["bones"][bone]
                        for got, want in ((head, want_head), (tail, want_tail)):
                            self.assertAlmostEqual(got[0], want[0], delta=1e-4, msg="%s %s %d %s" % (form, f["clip"], f["frame"], bone))
                            self.assertAlmostEqual(got[1], want[1], delta=1e-4, msg="%s %s %d %s" % (form, f["clip"], f["frame"], bone))

    def test_every_frame_of_every_slime_clip_is_drawn_inside_its_canvas_and_never_below_the_ground(self):
        sys.path.insert(0, HERE)
        import export_forms
        for form in ("kraken", "cloud_rider", "cube", "alkahest"):     # tentacles, a hover form, a stiff one, drips
            with self.subTest(form=form), tempfile.TemporaryDirectory() as tmp:
                done = blender("-P", os.path.join(HERE, "render_set.py"), "--", "--creature", "slime", "--variant", form, "--out", tmp, "--ss", "1")
                self.assertEqual(done.returncode, 0, done.stdout[-1500:] + done.stderr[-1500:])
                with open(os.path.join(tmp, "meta.json")) as fh:
                    meta = json.load(fh)
                export_forms.check_timing(meta, export_forms.engine_constants())
                size, ground = meta["canvas"], meta["canvas"] - meta["margin"]
                self.assertEqual(set(meta["anims"]), {"idle", "walk", "run", "attack", "hurt", "die"})
                for anim, count in meta["anims"].items():
                    self.assertEqual(len(meta["durations"][anim]), count, anim)
                    for i in range(count):
                        with Image.open(os.path.join(tmp, "%s_%d_albedo.png" % (anim, i))) as a:
                            box = a.convert("RGBA").split()[3].point(lambda v: 255 if v > 127 else 0).getbbox()
                        self.assertIsNotNone(box, "%s %d is drawn" % (anim, i))
                        self.assertTrue(box[0] > 0 and box[1] > 0 and box[2] < size, "%s %d is inside the canvas: %s" % (anim, i, box))
                        self.assertLessEqual(box[3], ground + 1, "%s %d is not below the ground" % (anim, i))
                        if form != "cloud_rider" and anim == "idle":
                            self.assertGreaterEqual(box[3], ground - 1, "%s %d stands on the ground" % (anim, i))

    def test_a_variant_changes_colours_and_parts_but_not_the_animation(self):
        with tempfile.TemporaryDirectory() as plain, tempfile.TemporaryDirectory() as red:
            self.render("goblin", plain)
            done = blender("-P", os.path.join(HERE, "render_set.py"), "--", "--creature", "goblin", "--variant", "redcap", "--out", red, "--anims", "idle", "--ss", "2")
            self.assertEqual(done.returncode, 0)
            with Image.open(os.path.join(plain, "idle_0_albedo.png")) as a, Image.open(os.path.join(red, "idle_0_albedo.png")) as b:
                self.assertNotEqual(list(a.convert("RGBA").get_flattened_data()), list(b.convert("RGBA").get_flattened_data()))
            with open(os.path.join(red, "meta.json")) as fh:
                self.assertEqual(json.load(fh)["variant"], "redcap")


if __name__ == "__main__":
    unittest.main()
