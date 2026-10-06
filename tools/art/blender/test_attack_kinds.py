"""The attacks that follow the verb a creature casts (attack_kinds.py, verbs.py): pure Python."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import attack_kinds as ak  # noqa: E402
import biped_motion as gm  # noqa: E402
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

    def test_a_four_legged_creature_has_its_own_table(self):
        self.assertEqual(ak.choose("bite", "dash", quad=True), "lunge")
        self.assertEqual(ak.choose("bite", "burst", quad=True), "slam")
        self.assertEqual(ak.choose("bite", "ring", quad=True), "roar")
        self.assertEqual(ak.choose("bite", None, quad=True), "bite")

    def test_every_attack_a_choice_can_return_exists_for_both_kinds_of_body(self):
        import quad_motion as qm
        for kind in set(ak.BY_VERB.values()):
            self.assertIn(kind, gm.ATTACKS)
        for kind in set(ak.BY_VERB_QUAD.values()):
            self.assertIn(kind, qm.ATTACKS)


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


if __name__ == "__main__":
    unittest.main()
