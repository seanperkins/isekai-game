"""Blender -P script: build one goblin form's rig and print which item bone each held part is bound to, as one `HANDS {part: bone}` JSON line.

    /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P tools/art/blender/probe_hands.py -- paladin
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import rigkit  # noqa: E402
from creatures import goblin  # noqa: E402

rigkit.reset()
rig = goblin.build(sys.argv[sys.argv.index("--") + 1])
print("HANDS " + json.dumps({ob.name: rig.owner[ob] for ob, _, _ in rig.parts if rig.owner[ob].startswith("item_")}))
