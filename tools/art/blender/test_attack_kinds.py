"""The attacks that follow the verb a creature casts (attack_kinds.py, verbs.py): pure Python."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import attack_kinds as ak  # noqa: E402
import anim  # noqa: E402
import biped_motion as gm  # noqa: E402
import quad_motion as qm  # noqa: E402
import slime_motion as slm  # noqa: E402
import spider_motion as sm  # noqa: E402
import test_spider_motion as TS  # noqa: E402
import test_biped_motion as T  # noqa: E402
import test_undead_motion as TU  # noqa: E402
import undead_motion as um  # noqa: E402
import verb_anims  # noqa: E402
import verbs  # noqa: E402


class VerbsTest(unittest.TestCase):
    def test_the_table_has_the_goblins_and_the_wolves_verbs_by_form_id(self):
        t = verbs.table()
        self.assertEqual(t["goblin_redcap"], "rage")
        self.assertEqual(t["wolf_hellhound"], "dash")
        self.assertEqual(t["kraken"], "pull")

    def test_a_verb_an_enemy_does_not_cast_is_no_verb(self):
        self.assertIsNone(verbs.kind_of("goblin_smith"))
        self.assertIsNone(verbs.kind_of("goblin_hob"))  # a stone is a player's to plant
        self.assertEqual(verbs.kind_of("goblin_redcap"), "rage")  # a window an enemy can open
        self.assertEqual(verbs.kind_of("undead_zombie"), "devour")
        self.assertEqual(verbs.kind_of("goblin_leprechaun"), "blink")
        self.assertIsNone(verbs.kind_of("nobody"))


class ChooseTest(unittest.TestCase):
    def test_a_weapon_blow_stays_a_weapon_blow_for_a_burst_or_a_bolt_but_other_verbs_have_their_own_look(self):
        self.assertEqual(ak.choose("chop", "burst"), "chop")
        self.assertEqual(ak.choose("thrust", "bolt"), "thrust")
        self.assertEqual(ak.choose("swipe", "burst"), "slam")
        self.assertEqual(ak.choose("chop", "dash"), "lunge")
        self.assertEqual(ak.choose("chop", "ward"), "guard")
        self.assertEqual(ak.choose("swipe", "buff"), "roar")
        self.assertEqual(ak.choose("chop", None), "chop")

    def test_every_verb_kind_has_its_gesture_not_only_the_ones_an_enemy_casts(self):
        self.assertEqual(ak.choose("chop", "mark"), "point")
        self.assertEqual(ak.choose("chop", "heal"), "pulse")
        self.assertEqual(ak.choose("chop", "forge"), "craft", "a smith's forge is a crouch, whatever it holds")
        self.assertEqual(ak.choose("chop", "stone"), "craft")
        self.assertEqual(ak.choose("chop", "drink"), "drink")

    def test_a_four_legged_creature_has_its_own_table(self):
        self.assertEqual(ak.choose("bite", "dash", family="quad"), "lunge")
        self.assertEqual(ak.choose("bite", "burst", family="quad"), "slam")
        self.assertEqual(ak.choose("bite", "dissolve", family="quad"), "bite", "its claw is its bite")
        self.assertEqual(ak.choose("bite", None, family="quad"), "bite")

    def test_what_a_form_names_itself_is_what_it_does(self):
        self.assertEqual(ak.resolve({"attack": "swipe"}, "goblin_redcap", "chop"), "swipe")

    def test_a_row_that_says_its_own_gesture_has_it_even_over_a_weapon_blow(self):
        self.assertEqual(ak.resolve({}, "goblin_paladin", "chop"), "throw", "the blessed throw")
        self.assertEqual(ak.resolve({}, "wolf_barghest", "bite", family="quad"), "roar", "the fear howl")
        self.assertEqual(ak.resolve({}, "undead_banshee", "slash", family="undead"), "roar", "the wail")

    def test_a_form_with_a_weapon_and_a_bolt_or_burst_swings_the_weapon_and_one_with_no_verb_does_its_default(self):
        self.assertEqual(ak.resolve({}, "goblin_giant_killer", "chop"), "chop", "a blow that scales with size")
        self.assertEqual(ak.resolve({}, "goblin_nobody", "chop"), "chop")

    def test_every_verb_row_has_a_preset_in_its_family(self):
        import biped_motion
        import quad_motion
        import slime_forms
        import spider_forms
        import spider_motion
        import undead_forms
        import undead_motion
        import goblin_forms
        import wolf_forms
        tables = {"biped": biped_motion.ATTACKS, "undead": undead_motion.KINDS, "quad": quad_motion.ATTACKS, "slime": slm.STYLES, "spider": spider_motion.ATTACKS, "drider": spider_motion.GESTURES}
        species = (("goblin", goblin_forms.FORMS, "goblin_"), ("undead", undead_forms.FORMS, "undead_"), ("wolf", wolf_forms.FORMS, "wolf_"), ("spider", spider_forms.FORMS, "spider_"), ("slime", slime_forms.FORMS, ""))
        seen = 0
        for sp, forms, prefix in species:
            for name, form in forms.items():
                if verbs.anim_of(prefix + name) is None:
                    continue
                family = verb_anims.family_of(sp, form)
                preset = ak.resolve({}, prefix + name, "chop" if family in ("biped", "undead") else "bite", family=family)
                self.assertIn(preset, list(tables[family]), "%s%s (%s)" % (prefix, name, family))
                seen += 1
        self.assertGreater(seen, 100)


class BipedKindsTest(unittest.TestCase):
    def test_each_new_kind_has_the_engines_timing_ends_at_rest_and_keeps_its_far_foot_down_unless_it_lunges(self):
        for kind in ("slam", "roar", "lunge", "guard"):
            body = T.body_of("redcap", attack=kind)
            frames, windup = gm.attack_frames(body)
            self.assertAlmostEqual(sum(d for _, d in frames[:windup]), gm.ENGINE_WINDUP, places=9, msg=kind)
            self.assertAlmostEqual(sum(d for _, d in frames[windup:]), gm.ENGINE_RECOVER, places=9, msg=kind)
            idle, _ = gm.idle_pose(body, 0.0)
            last = gm.attack_pose(body, frames[-1][0])[0]
            for bone in ("spine", "head", "arm_n", "fore_n", "thigh_n"):
                self.assertAlmostEqual(last[bone][1], idle[bone][1], delta=0.6, msg="%s %s" % (kind, bone))
            for t, _ in frames:
                rot, root = gm.attack_pose(body, t)
                heel, toe = T.sole(body, "f", rot, root)
                self.assertGreaterEqual(min(heel[1], toe[1]), -1e-6, kind)

    def test_a_roar_throws_the_head_back_with_the_jaw_open_and_a_slam_raises_both_hands_then_brings_them_down(self):
        body = T.body_of("redcap", attack="roar")
        apex = body.skel.pose(*gm.attack_pose(body, gm.T_HOLD))
        rest = body.skel.pose(*gm.idle_pose(body, 0.0))
        self.assertLess(180.0 - apex["head"][2], 180.0 - rest["head"][2] - 20.0)
        self.assertGreater(gm.attack_pose(body, gm.T_HIT)[0]["jaw"][1] if "jaw" in gm.attack_pose(body, gm.T_HIT)[0] else 1.0, 0.0)
        slam = T.body_of("redcap", attack="slam")
        up = slam.skel.pose(*gm.attack_pose(slam, gm.T_HOLD))
        down = slam.skel.pose(*gm.attack_pose(slam, gm.T_HIT))
        self.assertGreater(up["item_n"][0][1], up["head"][1][1] - 0.2, "the hands are over the head")
        self.assertLess(down["item_n"][0][1], up["item_n"][0][1] - 0.5, "and come down")
        self.assertLess(down["item_f"][0][1], up["item_f"][0][1] - 0.5)


class GestureTest(unittest.TestCase):
    """The gestures of tools/verb_anims.json on the two-legged bodies: each is there, keeps the engine's timing, comes back to rest, and is a motion of its own."""

    def bodies(self, kind):
        return (("goblin", T.body_of("redcap", attack=kind), gm), ("undead", TU.body_of("skeleton", attack=kind), um))

    def test_the_two_legged_bodies_have_a_preset_for_every_gesture(self):
        self.assertEqual([a for a in verb_anims.ARCHETYPES if a not in gm.ATTACKS], [])
        self.assertEqual([a for a in verb_anims.ARCHETYPES if a not in um.KINDS], [])

    def test_every_gesture_has_the_engines_timing_ends_at_rest_and_never_sinks_a_foot(self):
        for kind in verb_anims.ARCHETYPES:
            for family, body, mod in self.bodies(kind):
                label = "%s %s" % (family, kind)
                frames, windup = mod.attack_frames(body)
                self.assertAlmostEqual(sum(d for _, d in frames[:windup]), gm.ENGINE_WINDUP, places=9, msg=label)
                self.assertAlmostEqual(sum(d for _, d in frames[windup:]), gm.ENGINE_RECOVER, places=9, msg=label)
                idle, _ = gm.idle_pose(body, 0.0)
                last = mod.attack_pose(body, frames[-1][0])[0]
                for bone in ("spine", "head", "arm_n", "fore_n", "thigh_n"):
                    self.assertAlmostEqual(last[bone][1], idle[bone][1], delta=0.6, msg="%s %s" % (label, bone))
                for t, _ in frames:
                    rot, root = mod.attack_pose(body, t)[:2]
                    for side in "nf":
                        heel, toe = T.sole(body, side, rot, root)
                        self.assertGreaterEqual(min(heel[1], toe[1]), -1e-6, "%s %s foot" % (label, side))

    def test_no_two_gestures_are_the_same_motion_under_two_names(self):
        def key_poses(kind):
            body = T.body_of("redcap", attack=kind)
            out = []
            for t in (gm.T_HOLD, gm.T_HIT):
                posed = body.skel.pose(*gm.attack_pose(body, t))
                out.append([posed[b][2] for b in ("spine", "head", "arm_n", "fore_n", "arm_f", "fore_f")])
            return out
        poses = {kind: key_poses(kind) for kind in verb_anims.ARCHETYPES}
        names = list(poses)
        for i, a in enumerate(names):
            for b in names[i + 1:]:
                apart = max(sum(abs(x - y) for x, y in zip(pa, pb)) for pa, pb in zip(poses[a], poses[b]))
                self.assertGreater(apart, 80.0, "%s and %s read as the same gesture (%d degrees apart in the apex or the impact)" % (a, b, apart))

    def test_the_undead_take_the_bipeds_presets_for_the_gestures_they_had_no_kind_of(self):
        spec = ak.SPECS["pulse"]
        kind = um.KINDS["pulse"]
        self.assertEqual(kind["arm_n"], spec["arm_n"])
        self.assertEqual(kind["d_lean"], tuple(v - gm.GOBLIN_LEAN for v in spec["lean"]))
        self.assertEqual(um.KINDS["slam"]["arm_n"], (184, 130, 30, 30), "a kind the undead had keeps its own")

    def test_a_gesture_is_not_a_weapon_blow_so_a_form_that_casts_one_keeps_both_hands_free(self):
        for kind in ("summon", "pulse", "craft", "drink"):
            self.assertNotIn(kind, ak.WEAPON)


class QuadGestureTest(unittest.TestCase):
    """The same gestures on the four-legged bodies (the generic tests in test_quad_motion.py cover their timing, hind paws and return to rest for every preset)."""

    def test_the_quad_attacks_have_a_preset_for_every_gesture_but_the_claw_which_is_the_bite(self):
        self.assertEqual([a for a in verb_anims.ARCHETYPES if a != "claw" and a not in qm.ATTACKS], [])
        self.assertIn("bite", qm.ATTACKS)

    def test_no_two_gestures_are_the_same_motion_under_two_names(self):
        channels = ("hips", "spine", "neck", "head", "jaw", "fn_lift", "ff_lift", "fn_x")

        def key_poses(kind):
            out = []
            for t in (qm.T_HOLD, qm.T_HIT):
                out.append([anim.sample(qm.ATTACKS[kind][c], t) * (60.0 if c in ("fn_lift", "ff_lift", "fn_x") else 1.0) for c in channels]
                           + [100.0 * anim.sample(qm.ATTACKS[kind][c], t) for c in ("root_z", "root_x")])
            return out
        kinds = [a for a in verb_anims.ARCHETYPES if a != "claw"]   # the claw is the bite, the wolf's tearing blow
        poses = {k: key_poses(k) for k in kinds}
        for i, a in enumerate(kinds):
            for b in kinds[i + 1:]:
                apart = max(sum(abs(x - y) for x, y in zip(pa, pb)) for pa, pb in zip(poses[a], poses[b]))
                self.assertGreater(apart, 50.0, "%s and %s read as the same gesture" % (a, b))


class SpiderGestureTest(unittest.TestCase):
    """The gestures on the spiders: a plain spider has its own presets (its blows for the cast, the lunge and the claw), a drider the biped's arms for the rest."""
    PLAIN = {"cast": "spit", "lunge": "pounce", "claw": "slash"}   # creatures/spider.py GESTURES

    def test_a_plain_spider_has_a_preset_for_every_gesture(self):
        self.assertEqual([a for a in verb_anims.ARCHETYPES if self.PLAIN.get(a, a) not in sm.ATTACKS], [])

    def test_a_drider_has_the_arms_for_every_gesture(self):
        self.assertEqual([a for a in verb_anims.ARCHETYPES if a != "slam" and a not in sm.GESTURES], [])
        self.assertIn("smash", sm.GESTURES, "the drider's own slam")
        self.assertEqual(sm.GESTURES["cast"]["arm_n"], (150, 110, 82, 72), "a gesture the driders had keeps its own arms")

    def test_no_two_plain_gestures_are_the_same_motion_under_two_names(self):
        channels = ("root_x", "root_z", "pitch", "abd", "fang", "f0x", "f0z", "f0c")

        def key_poses(name):
            keys = sm.ATTACKS[self.PLAIN.get(name, name)]
            return [[anim.sample(keys[c], t) * (30.0 if c in ("f0x", "f0z", "root_x", "root_z") else 1.0) for c in channels] for t in (sm.T_HOLD, sm.T_HIT)]
        poses = {a: key_poses(a) for a in verb_anims.ARCHETYPES}
        names = list(poses)
        for i, a in enumerate(names):
            for b in names[i + 1:]:
                apart = max(sum(abs(x - y) for x, y in zip(pa, pb)) for pa, pb in zip(poses[a], poses[b]))
                self.assertGreater(apart, 45.0, "%s and %s read as the same gesture" % (a, b))

    def test_a_kind_both_tables_have_is_a_plain_spiders_own_blow_and_a_driders_arms(self):
        import spider_forms as sf
        plain = TS.body_of("spider")
        rest = sm.attack_pose(plain, 0.0)[1][2]
        for kind, when in (("slam", sm.T_HOLD), ("summon", sm.T_HIT)):   # reared up in the windup, and held up at the impact
            plain.form = dict(plain.form, attack=kind)
            self.assertGreater(sm.attack_pose(plain, when)[1][2], rest + 0.2 * plain.U, "%s rears the plain spider up" % kind)
        norn = TS.body_of("norn")
        norn.form = dict(norn.form, attack="roar")
        up = norn.skel.pose(*sm.attack_pose(norn, sm.T_HIT))
        self.assertGreater(up["arm_n"][1][1], up["chest"][0][1], "a drider's roar lifts its arms above its chest")


class SlimeGestureTest(unittest.TestCase):
    """The gestures on the jellies: attack styles of their own, the styles forms name (lash, throw, pulse) left alone."""

    def test_the_slimes_have_a_style_for_every_gesture_they_have_one_for(self):
        for style in ("roar", "guard", "point", "toss", "summon", "drink", "craft", "sneak", "throb"):
            self.assertIn(style, slm.STYLES)
        self.assertIs(slm.STYLES["throw"], slm.STYLES["lash"], "the named styles are as they were")
        self.assertIs(slm.STYLES["pulse"], slm.STYLES["lash"])

    def test_every_style_has_every_channel_the_soft_body_reads_and_ends_where_it_began(self):
        for name, keys in slm.STYLES.items():
            self.assertEqual(set(keys), {"sq", "lean", "bulge", "wave", "x", "z"}, name)
            for channel, path in keys.items():
                self.assertEqual(path[0][1], 0.0, "%s %s starts at rest" % (name, channel))
                self.assertEqual(path[-1][1], 0.0, "%s %s ends at rest" % (name, channel))

    def test_no_two_slime_gestures_are_the_same_motion_under_two_names(self):
        styles = ["roar", "guard", "point", "toss", "summon", "drink", "craft", "sneak", "throb", "slam", "lunge"]

        def key_poses(name):
            return [[10.0 * anim.sample(slm.STYLES[name][c], t) for c in ("sq", "lean", "bulge", "wave", "x", "z")] for t in (slm.T_HOLD, slm.T_HIT)]
        poses = {a: key_poses(a) for a in styles}
        for i, a in enumerate(styles):
            for b in styles[i + 1:]:
                apart = max(sum(abs(x - y) for x, y in zip(pa, pb)) for pa, pb in zip(poses[a], poses[b]))
                self.assertGreater(apart, 2.5, "%s and %s read as the same gesture" % (a, b))


if __name__ == "__main__":
    unittest.main()
