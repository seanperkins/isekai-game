"""Not a creature: one held piece alone, rendered as the near hand's piece on the standard goblin's item bone (held_items.py renders every one). `variant` is an
item id from held.all_items(). The grip (where the hand is, in canvas pixels) goes into meta.json.
"""
import os
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import goblin_gear as gear  # noqa: E402
import goblin_kit as kit  # noqa: E402
import goblin_skeleton as skeleton  # noqa: E402
import held  # noqa: E402
import rigkit as k  # noqa: E402

NAME = "held_item"
CANVAS, MARGIN, CENTER_X = 96, 3, 0.3   # 3.2 units wide at the items' 30 pixels per unit: the longest spear and the widest sword fit


def build(variant=None):
    piece, options = held.all_items()[variant]
    rig = k.Rig("held_" + variant)
    g = kit.Goblin(rig, {}, "", 1.0)   # the standard goblin: no proportions of a form, no gear but the piece
    for name, head, tail, parent in skeleton.core():
        g.bone(name, head, tail, parent, raw=True)
    gear.GEAR[piece](g, side="n", **options)   # always the near hand's: a far piece's shade is the layer's to give
    rig.build()
    return rig


def setup(rig, variant):
    head = rig.rest["item_n"][0]
    px, py = held.project(CANVAS, held.ITEM_PPU, MARGIN, CENTER_X, head.x, head.z)
    return {"canvas": CANVAS, "ppu": held.ITEM_PPU, "margin": MARGIN, "center_x": CENTER_X, "still": "item_0",
            "anims": {"item": (1, lambda i, n: ({}, (0.0, 0.0, 0.0)), False)},
            "extra": {"loops": {"item": False}, "grip": [px, py]}}
