"""The attack kinds a two-legged creature has beyond the weapon blows (chop, stab, thrust, cast, swipe): what it does when the verb it casts is a slam, a roar, a
lunge or a guard. Each is the four-key paths of biped_motion._attack (windup, mid-swing, impact, follow-through per channel, in the goblin's degrees), registered
into its ATTACKS. Pure Python.
"""


# Every verb-shaped attack as the keyword arguments of biped_motion._attack (four values per channel: windup, mid-swing, impact, follow-through, in the goblin's degrees), so a family
# that moves like the biped (the undead) can take them through `register_undead` instead of authoring them twice. The first five are the verbs an enemy cast first; the rest are the
# gestures of tools/verb_anims.json that need both hands, a crouch or a throw.
SPECS = {
    # both hands raised overhead, brought down together as the body drops: a burst or a ring (the engine draws the shock)
    "slam": dict(lean=(8, 30, 52, 54), head=(0, 14, 32, 34), px=(-0.06, 0.06, 0.14, 0.14), pz=(-0.04, -0.10, -0.18, -0.14),
                 arm_n=(200, 130, 40, 25), fore_n=(215, 140, 50, 30), item=(-30, 20, 80, 90), arm_f=(200, 130, 40, 25), fore_f=(215, 140, 50, 30), step=0.10, jaw=(14, 24, 6, 0)),
    # the chest thrown back and the head up with the jaw wide, the arms flung out: a howl, a call, a buff
    "roar": dict(lean=(10, 8, 12, 18), head=(-14, -26, -20, -4), px=(-0.04, -0.06, -0.06, -0.03), pz=(-0.03, 0.03, 0.03, 0.0),
                 arm_n=(150, 165, 165, 140), fore_n=(165, 175, 175, 150), item=(0, 10, 10, 0), arm_f=(140, 155, 155, 130), fore_f=(160, 170, 170, 145), step=0.0, lift=0.0, heel=-8.0, jaw=(30, 44, 40, 10)),
    # a crouch and a spring forward with the whole body behind the arms: a dash (the engine moves the body as well, so little travel here)
    "lunge": dict(lean=(18, 44, 58, 56), head=(8, 26, 36, 36), px=(-0.12, 0.06, 0.18, 0.16), pz=(-0.12, -0.10, -0.14, -0.08),
                  arm_n=(-30, 60, 100, 90), fore_n=(-10, 70, 100, 95), item=(-10, 50, 80, 70), arm_f=(-40, 50, 95, 90), fore_f=(-20, 60, 95, 90), step=0.30, lift=0.15, heel=-30.0, jaw=(10, 28, 6, 0)),
    # a clawed hand raised and cut down across the body: the wolf-men's blow
    "claw": dict(lean=(16, 36, 52, 56), head=(8, 18, 30, 32), px=(-0.08, 0.06, 0.16, 0.15), pz=(-0.08, -0.09, -0.12, -0.08),
                 arm_n=(125, 85, 65, 25), fore_n=(150, 100, 80, 40), item=(0, 20, 40, 40), arm_f=(40, 30, 20, 10), fore_f=(70, 50, 40, 30), step=0.24, jaw=(20, 34, 14, 0)),
    # braced low behind the forearms: a ward, a zone, an aura
    "guard": dict(lean=(34, 38, 36, 32), head=(14, 16, 16, 14), px=(-0.04, -0.05, -0.05, -0.03), pz=(-0.10, -0.12, -0.12, -0.08),
                  arm_n=(60, 80, 90, 80), fore_n=(120, 130, 135, 120), item=(-10, 10, 20, 10), arm_f=(60, 80, 90, 80), fore_f=(120, 130, 135, 120), step=0.0, lift=0.0, jaw=(8, 18, 18, 6)),
    # one arm drawn back, then straight out along the line of sight with the chest turned into it, the other arm back for balance: a mark, a hunt, a fate
    "point": dict(lean=(14, 20, 28, 26), head=(6, 10, 14, 14), px=(-0.03, 0.02, 0.05, 0.05), pz=(-0.04, -0.05, -0.05, -0.03),
                  arm_n=(30, 75, 92, 84), fore_n=(70, 88, 92, 86), item=(0, 0, 0, 0), arm_f=(20, 10, 0, 0), fore_f=(60, 40, 30, 30), step=0.10, lift=0.05, heel=-10.0, jaw=(4, 6, 6, 2)),
    # an overhand toss: the arm back and up, then over and forward with the step, the free hand forward for balance: a decoy, a stone, a trap
    "throw": dict(lean=(6, 20, 40, 46), head=(0, 10, 22, 26), px=(-0.08, 0.02, 0.14, 0.15), pz=(-0.05, -0.06, -0.08, -0.05),
                  arm_n=(215, 150, 70, 35), fore_n=(230, 170, 80, 45), item=(0, 0, 0, 0), arm_f=(70, 80, 40, 20), fore_f=(90, 90, 50, 30), step=0.28, lift=0.12, heel=-24.0, jaw=(6, 12, 10, 2)),
    # an overhand toss with the free hand while the arm that carries a shield braces it in front of the chest and lifts it as the hand lets go: a throw with the shield going up behind it
    "throw_free": dict(lean=(6, 20, 40, 46), head=(0, 10, 22, 26), px=(-0.08, 0.02, 0.14, 0.15), pz=(-0.05, -0.06, -0.08, -0.05),
                       arm_n=(8, 14, 24, 20), fore_n=(92, 100, 110, 104), item=(0, 4, 10, 6), arm_f=(215, 150, 70, 35), fore_f=(230, 170, 80, 45),
                       step=0.28, lift=0.12, heel=-24.0, jaw=(6, 12, 10, 2)),
    # both arms raised palms up and the head back: a summons, a raising, an offer
    "summon": dict(lean=(14, 8, 4, 10), head=(0, -14, -22, -10), px=(-0.02, -0.03, -0.03, -0.01), pz=(-0.04, 0.02, 0.04, 0.02),
                   arm_n=(110, 150, 172, 160), fore_n=(120, 165, 190, 175), item=(0, 0, 0, 0), arm_f=(106, 146, 168, 156), fore_f=(116, 160, 186, 170), step=0.0, lift=0.0, heel=-6.0, jaw=(8, 20, 26, 12)),
    # a hand to the mouth and the head tipped back: to drink, devour or swallow
    "drink": dict(lean=(14, 10, 6, 10), head=(4, -10, -20, -6), px=(-0.02, 0.0, 0.02, 0.02), pz=(-0.04, -0.04, -0.04, -0.02),
                  arm_n=(40, 60, 70, 60), fore_n=(110, 160, 172, 150), item=(0, 0, 0, 0), arm_f=(40, 35, 35, 35), fore_f=(70, 65, 65, 65), step=0.0, lift=0.0, heel=-6.0, jaw=(14, 30, 36, 10)),
    # a deep crouch with both hands working low in front: forging, spinning, rigging, bridging
    "craft": dict(lean=(30, 52, 58, 52), head=(14, 32, 36, 30), px=(-0.02, 0.08, 0.10, 0.08), pz=(-0.10, -0.24, -0.26, -0.16),
                  arm_n=(25, 55, 20, 40), fore_n=(60, 88, 55, 70), item=(0, 0, 0, 0), arm_f=(20, 50, 16, 35), fore_f=(55, 82, 50, 65), step=0.0, lift=0.0, heel=-4.0, jaw=(4, 6, 6, 2)),
    # low and forward on a creeping step, one hand trailing and the other reaching: a veil, a stalk, a swap, a blink
    "sneak": dict(lean=(34, 44, 48, 42), head=(16, 22, 24, 20), px=(-0.04, 0.06, 0.10, 0.08), pz=(-0.12, -0.16, -0.16, -0.10),
                  arm_n=(-30, -40, -35, -30), fore_n=(10, 0, 5, 10), item=(0, 0, 0, 0), arm_f=(50, 70, 75, 65), fore_f=(80, 90, 92, 85), step=0.22, lift=0.10, heel=-18.0, jaw=(2, 4, 4, 2)),
    # the hands drawn to the chest, then opened outward with the chest lifted: a heal, a light, a soul
    "pulse": dict(lean=(10, 6, 2, 6), head=(0, -6, -10, -4), px=(-0.04, -0.02, 0.0, 0.0), pz=(-0.05, -0.02, 0.02, 0.0),
                  arm_n=(40, 80, 125, 115), fore_n=(150, 135, 130, 120), item=(0, 0, 0, 0), arm_f=(36, 76, 120, 110), fore_f=(146, 130, 125, 115), step=0.0, lift=0.0, heel=-6.0, jaw=(4, 10, 14, 6)),
}


def register(attacks, attack):
    """Add every spec to a table of biped attacks, built by `attack` (biped_motion._attack)."""
    attacks.update({name: attack(**spec) for name, spec in SPECS.items()})


def undead_kind(spec, goblin_lean, goblin_head):
    """A spec as an undead_motion kind: the lean and the head as offsets from the form's own (the undead's channels are the biped's with the same meaning), the held tilt as `item_n`."""
    out = {"d_lean": tuple(v - goblin_lean for v in spec["lean"]), "d_head": tuple(v - goblin_head for v in spec["head"])}
    for name in ("px", "pz", "arm_n", "fore_n", "arm_f", "fore_f", "jaw", "step", "lift", "heel"):
        if name in spec:
            out[name] = spec[name]
    if "item" in spec:
        out["item_n"] = spec["item"]
    return out


def register_undead(kinds, goblin_lean, goblin_head):
    """Give the undead's attack kinds every spec it has none of its own for (slam, cast, throw and the blows keep theirs)."""
    for name, spec in SPECS.items():
        kinds.setdefault(name, undead_kind(spec, goblin_lean, goblin_head))


WEAPON = ("chop", "stab", "thrust")


def choose(weapon_kind, verb_kind, family="biped", anim=None):
    """The attack for a creature whose weapon blow would be `weapon_kind` and whose verb is of `verb_kind` (None for no verb): the gesture of the verb's kind (verb_anims.py) in the preset its rig
    `family` plays it with, or `anim`, the gesture its row says, which beats a weapon too. A blow with a weapon stays a weapon blow when the verb is a bolt or a burst and the row says no gesture."""
    import verb_anims
    if verb_kind is None and anim is None:
        return weapon_kind
    if anim is None and verb_kind in ("burst", "bolt") and weapon_kind in WEAPON:
        return weapon_kind
    return verb_anims.PRESETS[family][anim or verb_anims.archetype_of(verb_kind)]


def resolve(form, form_id, weapon_kind, family="biped"):
    """The attack a form uses: the one it names itself, else what its weapon and its verb make of it (`form_id` is `<species>_<form>`, as tools/form_verbs.json has it): the verb's gesture in the
    preset its rig family plays it with."""
    import verbs
    if form.get("attack"):
        return form["attack"]
    for row in verbs.rows():
        if row["form"] == form_id:
            return choose(weapon_kind, row["spec"].get("kind"), family, row.get("anim"))
    return weapon_kind
