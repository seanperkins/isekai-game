"""The goblin tree as data: the base goblin and the 28 forms of `data/forms/goblin_*.tres`, each described the way tools/art/forms_goblin_frames.json
describes it. A form names its proportions, colours, gear (goblin_gear.py), the pose of its arms, a stance, and (for the riders) a mount.

  bx, tall   build (widens every part) and height (stretches every part)
  ears, head ear length and head size
  skin       the goblin's skin colour (olive-green by default)
  gear       [(name, {options})...] in goblin_gear.GEAR
  arms       a pose from goblin.ARMS; stance a pose from goblin.STANCES
  mount      {"scale", "fur", "belly", "barding"}: the goblin rides a wolf
  still      the frame that becomes the form's still in the game
  width      the form's drawn width in game pixels, from tools/art/forms_goblin_frames.json
"""

TAN, LEATHER, DKLEATHER, RED = (176, 132, 86), (134, 92, 58), (88, 62, 42), (180, 56, 48)
CREAM, GOLD, CYAN, ROSE = (200, 186, 152), (222, 176, 66), (120, 190, 204), (214, 126, 150)
VIOLET, DKVIOLET, CHAR = (104, 74, 142), (62, 44, 92), (58, 58, 68)
IRON, DKIRON, STEEL, BRASS = (112, 118, 130), (74, 80, 92), (166, 176, 190), (190, 146, 66)
CRIMSON, BLOOD, GREY, WHITE = (160, 32, 48), (128, 24, 38), (114, 112, 120), (212, 212, 204)
LEAF, DKGREEN, WOOL, WOOLGREY = (98, 150, 72), (46, 96, 60), (134, 118, 102), (196, 192, 184)
BONE, WRAP = (214, 206, 182), (168, 150, 112)


def G(name, **kw):
    return (name, kw)


FORMS = {
    "goblin": dict(stage=1, parent=None, line="", width=19, arms="free",
                   gear=[G("jerkin", color=DKLEATHER), G("sash", color=RED), G("wraps", color=WRAP)]),

    # ---- the beast line: herder, piper, rider ----
    "beastcaller": dict(stage=2, parent="goblin", line="beast", width=19, arms="offer", ears=1.1,
                        gear=[G("jerkin", color=TAN, collar=WOOLGREY), G("headband", color=LEATHER), G("feather", color=CYAN),
                              G("necklace"), G("sash", color=RED), G("wraps", color=WRAP), G("offering", side="n")]),
    "pied_piper": dict(stage=3, parent="beastcaller", line="beast", width=21, arms="play", tall=1.04,
                       gear=[G("floppy_cap", color=ROSE, height=0.34), G("feather", color=CREAM, base=(0.10, 0.10, 1.80), tip=(-0.20, 0.14, 2.14)),
                             G("jerkin", color=CYAN, skirt=0.55), G("patches", colors=[ROSE, CREAM, ROSE, CREAM]),
                             G("curled_shoes", color=DKLEATHER), G("pipe", side="n")]),
    "rat_king": dict(stage=4, parent="pied_piper", line="beast", width=24, arms="free", tall=1.06, ears=1.15,
                     gear=[G("crown", color=TAN, spikes=7), G("jerkin", color=TAN, skirt=0.40), G("belt", color=DKLEATHER),
                           G("rat_ball"), G("wraps", color=WRAP)]),
    "orpheus": dict(stage=4, parent="pied_piper", line="beast", width=24, arms="cradle", tall=1.06, bx=0.92,
                    gear=[G("wreath", color=GOLD), G("jerkin", color=CREAM, skirt=0.62), G("sash", color=ROSE),
                          G("lyre", side="n")]),
    "beast_rider": dict(stage=3, parent="beastcaller", line="beast", width=30, arms="carry", ride=True,
                        mount=dict(scale=1.15, fur=(118, 118, 126), belly=(206, 204, 206)),
                        gear=[G("helm", color=DKLEATHER), G("jerkin", color=TAN), G("sash", color=RED), G("spear", side="n")]),
    "wolf_lord": dict(stage=4, parent="beast_rider", line="beast", width=34, arms="carry", ride=True, bx=1.15, still="attack_3",
                      mount=dict(scale=1.35, fur=(84, 84, 94), belly=(130, 128, 136), barding=IRON),
                      gear=[G("helm", color=IRON, horns=BONE), G("jerkin", color=DKLEATHER, collar=WOOL), G("cloak", color=WOOL, length=0.5),
                            G("spear", side="n", couched=True, pennant=CYAN)]),
    "lord_of_beasts": dict(stage=4, parent="beast_rider", line="beast", width=34, arms="raise_n", ride=True,
                           mount=dict(scale=1.3, fur=(132, 130, 138), belly=(208, 206, 208)),
                           gear=[G("antlers", color=(150, 112, 74)), G("jerkin", color=TAN, collar=(200, 150, 92)), G("pauldron", color=(200, 150, 92)),
                                 G("hawk", side="n")]),

    # ---- the tinker line: inventor, miner, smith ----
    "tinker": dict(stage=2, parent="goblin", line="tinker", width=19, arms="offer_up", ears=1.1,
                   gear=[G("cap", color=DKLEATHER, tip=(0.10, 0, 1.92)), G("goggles", color=BRASS), G("jerkin", color=LEATHER),
                         G("belt", color=DKLEATHER, buckle=BRASS), G("pouch", color=TAN), G("sash", color=RED), G("wraps", color=WRAP),
                         G("trap", side="n")]),
    "knocker": dict(stage=3, parent="tinker", line="tinker", width=21, arms="guard", stance="listen",
                    gear=[G("helm", color=DKLEATHER), G("candle"), G("jerkin", color=LEATHER, skirt=0.18), G("belt", color=DKLEATHER),
                          G("boots", color=DKLEATHER, big=1.2), G("pick", side="n"), G("lantern", side="f")]),
    "gremlin": dict(stage=4, parent="knocker", line="tinker", width=24, arms="guard", bx=0.9, tall=1.04, ears=1.7,
                    gear=[G("helm", color=DKLEATHER), G("goggles", color=BRASS), G("scarf", color=CYAN), G("jerkin", color=LEATHER),
                          G("bandolier", color=DKLEATHER, items=[STEEL, IRON, STEEL, IRON]), G("wrench", side="n")]),
    "rumpelstiltskin": dict(stage=4, parent="knocker", line="tinker", width=24, arms="carry", stance="hop", bx=0.95,
                            gear=[G("floppy_cap", color=TAN, height=0.38), G("beard", color=WOOLGREY, length=0.14, width=0.07),
                                  G("jerkin", color=ROSE), G("cloak", color=TAN, length=0.6), G("spindle", side="n"), G("straw", side="f")]),
    "smith": dict(stage=3, parent="tinker", line="tinker", width=21, arms="guard", bx=1.2, tall=0.95,
                  gear=[G("helm", color=DKLEATHER), G("apron", color=DKLEATHER), G("wraps", color=LEATHER), G("sash", color=RED),
                        G("hammer", side="n"), G("tongs", side="f")]),
    "mastersmith": dict(stage=4, parent="smith", line="tinker", width=34, arms="guard", bx=1.32, stance="wide",
                        gear=[G("goggles", color=BRASS), G("apron", color=BRASS, trim=STEEL), G("pauldron", color=STEEL, side="n"),
                              G("belt", color=DKLEATHER, buckle=GOLD), G("hammer", side="n", big=1.15), G("sword_big", side="f", length=0.7)]),
    "ring_maker": dict(stage=4, parent="smith", line="tinker", width=24, arms="raise_n", bx=0.88, stance="hunch",
                       gear=[G("hood", color=DKVIOLET), G("cloak", color=DKVIOLET, length=0.9), G("jerkin", color=CHAR),
                             G("belt", color=DKLEATHER), G("ring", side="n")]),

    # ---- the skulker line: sneak, redcap, trickster ----
    "skulker": dict(stage=2, parent="goblin", line="skulker", width=19, arms="guard_n", bx=0.9, ears=1.05,
                    gear=[G("hood", color=DKVIOLET), G("scarf", color=DKVIOLET, face=True, tail=False), G("cloak", color=VIOLET, length=0.5),
                          G("sash", color=CHAR), G("wraps", color=CHAR), G("pouch", color=CYAN, glow=True), G("dagger", side="n")]),
    "redcap": dict(stage=3, parent="skulker", line="skulker", width=21, arms="guard_n",
                   gear=[G("floppy_cap", color=BLOOD, height=0.36), G("jerkin", color=DKVIOLET), G("wraps", color=DKVIOLET),
                         G("boots", color=IRON, height=0.3, big=1.15), G("axe", side="n")]),
    "ironboot": dict(stage=4, parent="redcap", line="skulker", width=34, arms="fists", bx=1.3, stance="stomp",
                     gear=[G("floppy_cap", color=BLOOD, height=0.22), G("jerkin", color=DKLEATHER), G("pauldron", color=IRON, side="n"),
                           G("pauldron", color=IRON, side="f"), G("belt", color=TAN),
                           G("boots", color=IRON, height=0.38, big=1.2, plate=DKIRON, spike=True)]),
    "bloodcap": dict(stage=4, parent="redcap", line="skulker", width=24, arms="guard_n", bx=0.92,
                     gear=[G("cloak", color=DKVIOLET, length=0.85), G("cap", color=CRIMSON, tip=(0.0, 0, 2.12), r=0.24), G("crown", color=STEEL, spikes=6),
                           G("sash", color=CRIMSON), G("spiked_cap_held", side="n")]),
    "puck": dict(stage=3, parent="skulker", line="skulker", width=21, arms="lantern", ears=1.1,
                 gear=[G("wreath", color=LEAF), G("feather", color=ROSE, base=(0.10, 0.12, 1.76), tip=(-0.16, 0.16, 2.12)),
                       G("jerkin", color=DKVIOLET, skirt=0.12), G("patches", colors=[LEAF, LEAF, DKGREEN, LEAF]),
                       G("curled_shoes", color=DKGREEN), G("lantern", side="n", color=CYAN)]),
    "changeling": dict(stage=4, parent="puck", line="skulker", width=24, arms="carry", bx=0.95,
                       gear=[G("mask", color=WHITE), G("cloak", color=DKVIOLET, length=0.7, spread=0.1), G("jerkin", color=DKVIOLET, skirt=0.3),
                             G("sash", color=CREAM), G("doll", side="n")]),
    "leprechaun": dict(stage=4, parent="puck", line="skulker", width=24, arms="carry", stance="tiptoe",
                       gear=[G("cap", color=CHAR, tip=(0.12, 0, 2.06), r=0.2), G("headband", color=GOLD), G("jerkin", color=DKGREEN),
                             G("apron", color=LEATHER), G("curled_shoes", color=DKLEATHER), G("pouch", color=GOLD),
                             G("hammer_small", side="n"), G("coin", side="f"), G("trail", color=CYAN)]),

    # ---- the hob line: household spirit, hearth, knight ----
    "hob": dict(stage=2, parent="goblin", line="hob", width=19, arms="offer", bx=1.12, tall=0.97,
                gear=[G("apron", color=CREAM, trim=GOLD), G("spoon"), G("wraps", color=WRAP), G("bowl", side="n")]),
    "tomte": dict(stage=3, parent="hob", line="hob", width=21, arms="carry", tall=0.98, bx=1.05,
                  gear=[G("floppy_cap", color=RED, height=0.34), G("beard", color=WOOLGREY, length=0.34, width=0.11),
                        G("jerkin", color=WOOL, skirt=0.28), G("belt", color=DKLEATHER), G("clogs", color=TAN),
                        G("stone", side="n"), G("lantern", side="f")]),
    "hearth_god": dict(stage=4, parent="tomte", line="hob", width=24, arms="raise_f", tall=1.02, stance="dance",
                       gear=[G("wreath", color=GOLD), G("jerkin", color=WHITE, skirt=0.22), G("belt", color=GOLD), G("horn", side="f"),
                             G("stone", side="n", color=GOLD)]),
    "boggart": dict(stage=4, parent="tomte", line="hob", width=24, arms="guard", stance="hunch", ears=1.2,
                    gear=[G("floppy_cap", color=CHAR, height=0.26), G("cloak", color=DKVIOLET, length=0.7), G("apron", color=GREY),
                          G("stone", side="n", color=(150, 100, 210))]),
    "paladin": dict(stage=3, parent="hob", line="hob", width=30, arms="shield_ready", bx=1.12, attack="throw_free",   # the Blessed throw: the free hand throws, the shield arm stays up in front
                    gear=[G("helm", color=STEEL, rim=GOLD), G("jerkin", color=TAN, collar=GREY), G("cloak", color=CREAM, length=0.8),
                          G("bandolier", color=LEATHER, items=[CYAN, ROSE, CYAN]), G("shield")]),
    "horn_bearer": dict(stage=4, parent="paladin", line="hob", width=34, arms="play", tall=1.12,
                        gear=[G("helm", color=STEEL, wings=CYAN), G("jerkin", color=TAN, collar=GREY), G("cloak", color=CREAM, length=0.95, spread=0.3),
                              G("shield_back"), G("belt", color=DKLEATHER), G("horn", side="n")]),
    "giant_killer": dict(stage=4, parent="paladin", line="hob", width=34, arms="sword", bx=1.1, stance="wide",
                         gear=[G("jerkin", color=LEATHER), G("belt", color=DKLEATHER, buckle=GOLD), G("cloak", color=CREAM, length=0.5),
                               G("boots", color=TAN), G("bandolier", color=LEATHER, items=[GREY, GREY, GREY]), G("sling", side="f"),
                               G("sword_big", side="n", length=1.0)]),
}

ORDER = list(FORMS)
