"""The held-item layer's rules, in pure Python (no Blender): which gear pieces a hand carries, the id of each item, how big it is on a form, and the
camera maths that turn a bone's place in a render into the pixel the game draws an item at. The goblin kit renders its forms empty-handed and
records where each hand is; the engine draws the item (scripts/ui/held_item_layer.gd) from data/held_items.json, which this module writes.
"""
import hashlib
import json
import math
import os

import goblin_forms
import goblin_skeleton as skeleton

ITEM_PPU = 30.0   # the pixels per unit every item is rendered at: about a goblin form's own, so a form's scale is near 1

# piece -> the hand it goes to when a form does not say (goblin_gear.py: every function bound to an item bone; a test keeps this honest)
HELD = {"hawk": "n", "club": "n", "dagger": "n", "axe": "n", "spear": "n", "sword_big": "n", "hammer": "n", "hammer_small": "n", "tongs": "f",
        "pick": "n", "wrench": "n", "staff": "n", "spindle": "n", "pipe": "n", "lyre": "n", "horn": "n", "lantern": "f", "stone": "n", "bowl": "n",
        "trap": "n", "shield": "n", "sling": "n", "coin": "f", "ring": "n", "offering": "n", "spiked_cap_held": "n", "straw": "f", "doll": "n"}


# the hand a piece goes in when a form does not say: what a form acts with is its primary hand, an off-hand piece is secondary; `shield` is made for the near arm but is an off-hand piece
ROLE_OF = {piece: "secondary" if piece in ("tongs", "lantern", "coin", "straw", "shield") else "primary" for piece in HELD}
TWO_HANDED = frozenset({"spear", "staff"})   # primary only: they fill the primary hand and leave the secondary empty
PLACEMENT = ("side", "hand")   # the gear options that say where a piece is held, not what it looks like


def role_of(piece, kw):
    """The role a gear entry holds its piece in: its `hand` option, else the piece's default."""
    return kw.get("hand", ROLE_OF[piece])


def physical_side(role, handed):
    """The arm (`"n"` near, `"f"` far) a role is on in a form whose primary arm is `handed`."""
    return handed if role == "primary" else ("f" if handed == "n" else "n")


def _options(kw):
    return {k: v for k, v in kw.items() if k not in PLACEMENT}


def item_id(piece, kw):
    """The piece's name, or the name and six hex digits of its options (colour, length, size) when it has any: the same piece with other options is another
    picture. The hand it is held in (`side`, `hand`) is not an option."""
    options = _options(kw)
    if not options:
        return piece
    return "%s_%s" % (piece, hashlib.sha1(json.dumps(options, sort_keys=True).encode()).hexdigest()[:6])


def held_of(gear):
    """{"primary": item id or "", "secondary": ...}: what a form holds in each role, from its gear list [(name, options)]. Two pieces in one role, a two-handed piece in the secondary
    role, and a two-handed primary beside a secondary piece are errors."""
    out, pieces = {"primary": "", "secondary": ""}, {}
    for name, kw in gear:
        if name not in HELD:
            continue
        role = role_of(name, kw)
        if pieces.get(role):
            raise ValueError("two held pieces in the %s hand: %s and %s" % (role, pieces[role], name))
        if role == "secondary" and name in TWO_HANDED:
            raise ValueError("%s is held in two hands: it can only be primary" % name)
        pieces[role], out[role] = name, item_id(name, kw)
    if pieces.get("primary") in TWO_HANDED and out["secondary"]:
        raise ValueError("%s fills both hands: nothing can be held beside it (%s)" % (pieces["primary"], pieces["secondary"]))
    return out


def primary_piece(gear):
    """The name of the piece in the primary role, or None."""
    for name, kw in gear:
        if name in HELD and role_of(name, kw) == "primary":
            return name
    return None


def validate_form(name, form):
    """Raise a ValueError that names the form if its `handed` is not "n" or "f" or its held pieces break the role rules."""
    handed = form.get("handed", "n")
    if handed not in ("n", "f"):
        raise ValueError("form %s: handed is \"n\" or \"f\", not %r" % (name, handed))
    try:
        held_of(form["gear"])
    except ValueError as err:
        raise ValueError("form %s: %s" % (name, err)) from None


def items_of(gear):
    """{item id: (piece, options without the hand)} for the held pieces in a gear list."""
    return {item_id(name, kw): (name, _options(kw)) for name, kw in gear if name in HELD}


def all_items():
    """Every item the game can draw: what each form holds, and every held piece at its default options (a piece no form holds today can still be picked up)."""
    items = {}
    for form in goblin_forms.FORMS.values():
        items.update(items_of(form["gear"]))
    for piece in HELD:
        items[item_id(piece, {})] = (piece, {})
    return items


def form_scale(form, ppu):
    """How much an item is scaled on this form: the form's pixels per unit over the item's, times the factor the kit puts on every gear radius
    (goblin_kit.Goblin.R), relative to the standard goblin the items are rendered on. `form` is the form's table row (goblin_forms.FORMS)."""
    bx, tall = form.get("bx", 1.0), form.get("tall", 1.0)
    kit = (skeleton.BASE_BX * bx + skeleton.BASE_TALL * tall) / (skeleton.BASE_BX + skeleton.BASE_TALL)
    return ppu / ITEM_PPU * kit


def form_entry(form_name, ppu):
    """The form's row of data/held_items.json: the scale of its items at the pixels per unit it was rendered at, which arm is primary, and what it holds in each role (a role with nothing
    in it has no key). Every goblin form has one, empty-handed or not: any hand can be given an item."""
    row = goblin_forms.FORMS[form_name]
    validate_form(form_name, row)
    entry = {"scale": round(form_scale(row, ppu), 4), "handed": row.get("handed", "n")}
    entry.update({role: item for role, item in held_of(row["gear"]).items() if item})
    return entry


def project(canvas, ppu, margin, center_x, x, z):
    """The pixel (px, py) in a render's canvas of the world point (x, z): the side-on camera of stage.camera_params, which puts the ground `margin` pixels
    above the bottom and `center_x` on the middle column."""
    return (canvas / 2.0 + (x - center_x) * ppu, canvas - margin - z * ppu)


def bone_turn(rest_head, rest_tail, head, tail):
    """How far a bone has turned from its rest direction, in degrees clockwise on the screen (x right, z up), in (-180, 180]. Points are (x, z)."""
    def heading(a, b):
        return math.degrees(math.atan2(b[0] - a[0], b[1] - a[1]))
    d = (heading(head, tail) - heading(rest_head, rest_tail) + 180.0) % 360.0 - 180.0
    return 180.0 if d <= -180.0 else d


def local_of(px, py, box):
    """A canvas pixel in the frame-local space of the cell cut from `box` (left, top, right, bottom): origin at the cell's bottom centre, x right, y down
    (the space of the sheet's hit shapes)."""
    left, _, right, bottom = box
    return (px - left - (right - left) / 2.0, py - bottom)


def check_empty_handed(meta):
    """Refuse a goblin render that still carries its weapons: installed beside the layer it would draw every weapon twice. Other creatures are not checked."""
    if meta.get("creature") == "goblin" and meta.get("hold") is not False:
        raise ValueError("this goblin render is armed (its meta.json has no \"hold\": false): render it again with --empty-hands")


def update_table(path, items=None, forms=None):
    """Merge items and forms into the held-items JSON ({"items", "forms"}), keeping what is there, sorted by key."""
    table = {"items": {}, "forms": {}}
    if os.path.exists(path):
        with open(path) as fh:
            table.update(json.load(fh))
    table["items"].update(items or {})
    table["forms"].update(forms or {})
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "w") as fh:
        json.dump({"items": dict(sorted(table["items"].items())), "forms": dict(sorted(table["forms"].items()))}, fh, indent=1)
        fh.write("\n")
