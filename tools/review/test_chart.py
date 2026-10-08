"""The index's evolution-chart layout (app/chart.js), a pure function: run through Node when it is installed."""
import json
import os
import shutil
import subprocess
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
NODE = shutil.which("node")


def layout(creatures):
    """Run layoutTree(creatures) in Node and return {id: (col, row)}, the edge list and the size."""
    script = ('import { layoutTree } from "%s/app/chart.js"; const list = JSON.parse(process.argv[1]); '
              'const out = layoutTree(list); console.log(JSON.stringify({ nodes: out.nodes.map((n) => [n.c.id, n.col, n.row]), edges: out.edges, cols: out.cols, rows: out.rows }));' % HERE)
    done = subprocess.run([NODE, "--input-type=module", "-e", script, json.dumps(creatures)], capture_output=True, text=True, timeout=30)
    assert done.returncode == 0, done.stderr
    data = json.loads(done.stdout)
    return {i: (c, r) for i, c, r in data["nodes"]}, [tuple(e) for e in data["edges"]], data["cols"], data["rows"]


def c(id, stage, parent=None):
    return {"id": id, "stage": stage, "parent": parent}


@unittest.skipUnless(NODE, "needs Node")
class LayoutTest(unittest.TestCase):
    def test_a_chain_goes_one_column_per_stage_on_one_row(self):
        nodes, edges, cols, rows = layout([c("a", 1), c("b", 2, "a"), c("d", 3, "b")])
        self.assertEqual(nodes, {"a": (0, 0), "b": (1, 0), "d": (2, 0)})
        self.assertEqual(sorted(edges), [("a", "b"), ("b", "d")])
        self.assertEqual((cols, rows), (3, 1))

    def test_a_parent_sits_centred_beside_its_children_and_each_leaf_has_its_own_row(self):
        nodes, edges, cols, rows = layout([c("a", 1), c("x", 2, "a"), c("y", 2, "a"), c("z", 2, "a")])
        self.assertEqual([nodes[k][1] for k in "xyz"], [0, 1, 2])
        self.assertEqual(nodes["a"], (0, 1))
        self.assertEqual(rows, 3)

    def test_siblings_are_ordered_by_stage_then_id_whatever_order_they_arrive_in(self):
        nodes, _, _, _ = layout([c("a", 1), c("zed", 2, "a"), c("amy", 2, "a"), c("kay", 2, "a")])
        self.assertEqual(sorted(("amy", "kay", "zed"), key=lambda k: nodes[k][1]), ["amy", "kay", "zed"])

    def test_a_child_whose_stage_is_not_after_its_parents_goes_in_the_next_column(self):
        nodes, _, _, _ = layout([c("a", 2), c("b", 2, "a"), c("d", 1, "b")])
        self.assertEqual([nodes[k][0] for k in "abd"], [1, 2, 3])

    def test_a_parent_that_is_not_in_the_list_leaves_its_child_a_root_in_its_own_stage_column(self):
        nodes, edges, _, _ = layout([c("a", 1), c("b", 3, "ghost")])
        self.assertEqual(nodes["b"][0], 2)
        self.assertEqual(edges, [])

    def test_roots_stack_one_below_the_other(self):
        nodes, _, _, rows = layout([c("a", 1), c("a2", 2, "a"), c("z", 1), c("z2", 2, "z"), c("z3", 2, "z")])
        self.assertEqual(rows, 3)
        self.assertEqual(nodes["a"][1], 0)
        self.assertEqual(nodes["z"][1], 1.5)

    def test_a_parent_loop_does_not_hang_and_places_both(self):
        nodes, _, _, _ = layout([c("a", 1, "b"), c("b", 2, "a")])
        self.assertEqual(set(nodes), {"a", "b"})

    def test_a_creature_that_is_its_own_parent_is_a_root(self):
        nodes, edges, _, _ = layout([c("a", 1, "a")])
        self.assertEqual((nodes["a"], edges), ((0, 0), []))

    def test_a_missing_stage_still_gets_a_place_after_its_parent(self):
        nodes, _, _, _ = layout([c("a", 1), {"id": "b", "parent": "a"}])
        self.assertEqual(nodes["b"][0], 1)

    def test_no_two_cards_in_a_column_are_closer_than_one_row_in_a_big_tree(self):
        tree = [c("g", 1)]
        for i in range(4):
            tree.append(c("m%d" % i, 2, "g"))
            for j in range(3):
                tree.append(c("m%d_%d" % (i, j), 3, "m%d" % i))
                for k in range(2):
                    tree.append(c("m%d_%d_%d" % (i, j, k), 4, "m%d_%d" % (i, j)))
        nodes, edges, cols, rows = layout(tree)
        self.assertEqual(len(nodes), len(tree))
        self.assertEqual(len(edges), len(tree) - 1)
        for col in range(cols):
            ys = sorted(r for cc, r in nodes.values() if cc == col)
            self.assertTrue(all(b - a >= 1 for a, b in zip(ys, ys[1:])), (col, ys))
        for parent, child in edges:
            self.assertGreater(nodes[child][0], nodes[parent][0])


if __name__ == "__main__":
    unittest.main()
