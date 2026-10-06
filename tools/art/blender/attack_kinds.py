"""The attack kinds a two-legged creature has beyond the weapon blows (chop, stab, thrust, cast, swipe): what it does when the verb it casts is a slam, a roar, a
lunge or a guard. Each is the four-key paths of biped_motion._attack (windup, mid-swing, impact, follow-through per channel, in the goblin's degrees), registered
into its ATTACKS. Pure Python.
"""


def register(attacks, attack):
    attacks.update({
        # both hands raised overhead, brought down together as the body drops: a burst or a ring (the engine draws the shock)
        "slam": attack(lean=(8, 30, 52, 54), head=(0, 14, 32, 34), px=(-0.06, 0.06, 0.14, 0.14), pz=(-0.04, -0.10, -0.18, -0.14),
                       arm_n=(200, 130, 40, 25), fore_n=(215, 140, 50, 30), item=(-30, 20, 80, 90), arm_f=(200, 130, 40, 25), fore_f=(215, 140, 50, 30), step=0.10, jaw=(14, 24, 6, 0)),
        # the chest thrown back and the head up with the jaw wide, the arms flung out: a howl, a call, a buff
        "roar": attack(lean=(10, 8, 12, 18), head=(-14, -26, -20, -4), px=(-0.04, -0.06, -0.06, -0.03), pz=(-0.03, 0.03, 0.03, 0.0),
                       arm_n=(150, 165, 165, 140), fore_n=(165, 175, 175, 150), item=(0, 10, 10, 0), arm_f=(140, 155, 155, 130), fore_f=(160, 170, 170, 145), step=0.0, lift=0.0, heel=-8.0, jaw=(30, 44, 40, 10)),
        # a crouch and a spring forward with the whole body behind the arms: a dash (the engine moves the body as well, so little travel here)
        "lunge": attack(lean=(18, 44, 58, 56), head=(8, 26, 36, 36), px=(-0.12, 0.06, 0.18, 0.16), pz=(-0.12, -0.10, -0.14, -0.08),
                        arm_n=(-30, 60, 100, 90), fore_n=(-10, 70, 100, 95), item=(-10, 50, 80, 70), arm_f=(-40, 50, 95, 90), fore_f=(-20, 60, 95, 90), step=0.30, lift=0.15, heel=-30.0, jaw=(10, 28, 6, 0)),
        # a clawed hand raised and cut down across the body: the wolf-men's blow
        "claw": attack(lean=(16, 36, 52, 56), head=(8, 18, 30, 32), px=(-0.08, 0.06, 0.16, 0.15), pz=(-0.08, -0.09, -0.12, -0.08),
                       arm_n=(125, 85, 65, 25), fore_n=(150, 100, 80, 40), item=(0, 20, 40, 40), arm_f=(40, 30, 20, 10), fore_f=(70, 50, 40, 30), step=0.24, jaw=(20, 34, 14, 0)),
        # braced low behind the forearms: a ward, a zone, an aura
        "guard": attack(lean=(34, 38, 36, 32), head=(14, 16, 16, 14), px=(-0.04, -0.05, -0.05, -0.03), pz=(-0.10, -0.12, -0.12, -0.08),
                        arm_n=(60, 80, 90, 80), fore_n=(120, 130, 135, 120), item=(-10, 10, 20, 10), arm_f=(60, 80, 90, 80), fore_f=(120, 130, 135, 120), step=0.0, lift=0.0, jaw=(8, 18, 18, 6)),
    })


# What a verb of each kind an enemy can cast looks like (tools/form_verbs.json; scripts/abilities/verb_kinds.gd ENEMY_KINDS). A blow with a weapon stays a weapon
# blow when the verb is a bolt or a burst; anything else takes the attack that reads like the verb.
BY_VERB = {"burst": "slam", "ring": "slam", "dash": "lunge", "zone": "guard", "aura": "roar", "buff": "roar", "ward": "guard", "mark": "cast", "pull": "cast",
           "chain": "cast", "heal": "cast", "bolt": "cast", "rage": "roar", "blink": "cast", "devour": "slam", "summon": "cast"}
BY_VERB_QUAD = {"burst": "slam", "ring": "roar", "dash": "lunge", "zone": "guard", "aura": "roar", "buff": "roar", "ward": "guard", "mark": "roar", "pull": "bite",
                "chain": "bite", "heal": "guard", "bolt": "roar", "rage": "roar", "blink": "lunge", "devour": "bite", "summon": "roar"}
WEAPON = ("chop", "stab", "thrust")


def choose(weapon_kind, verb_kind, quad=False):
    """The attack for a creature whose weapon blow would be `weapon_kind` and whose verb is of `verb_kind` (None for no verb, or one an enemy does not cast)."""
    if verb_kind is None:
        return weapon_kind
    if not quad and verb_kind in ("burst", "bolt") and weapon_kind in WEAPON:
        return weapon_kind
    return (BY_VERB_QUAD if quad else BY_VERB).get(verb_kind, weapon_kind)


def resolve(form, form_id, weapon_kind, quad=False):
    """The attack a form uses: the one it names itself, else what its weapon and its verb make of it (`form_id` is `<species>_<form>`, as tools/form_verbs.json has it)."""
    import verbs
    if form.get("attack"):
        return form["attack"]
    return choose(weapon_kind, verbs.kind_of(form_id), quad)
