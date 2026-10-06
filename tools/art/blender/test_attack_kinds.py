"""The attacks that follow the verb a creature casts (attack_kinds.py, verbs.py): pure Python."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import attack_kinds as ak  # noqa: E402
import biped_motion as gm  # noqa: E402
import test_biped_motion as T  # noqa: E402
import verbs  # noqa: E402


class VerbsTest(unittest.TestCase):
    def test_the_table_has_the_goblins_and_the_wolves_verbs_by_form_id(self):
        t = verbs.table()
        self.assertEqual(t["goblin_redcap"], "buff")
        self.assertEqual(t["wolf_hellhound"], "dash")
        self.assertEqual(t["kraken"], "pull")

    def test_a_verb_an_enemy_does_not_cast_is_no_verb(self):
        self.assertIsNone(verbs.kind_of("goblin_smith"))
        self.assertEqual(verbs.kind_of("goblin_hob"), "ward")
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


if __name__ == "__main__":
    unittest.main()
