"""The undead tree as data: the base skeleton and the 29 forms of `data/forms/undead_*.tres`, each described the way
tools/art/forms_undead_frames.json describes it (simplified to what reads at 17 to 31 pixels).

  body       "biped" (biped_motion), "hop" (a jiangshi: biped bones, its own gait), "candle", "ghost" or "skull" (floating: undead_motion)
  posture    how it carries itself and gaits (undead_motion.POSTURES)
  style      what its body is made of: "bone" (a skeleton), "flesh" (a corpse), "mummy" (a corpse in linen)
  shape      proportions (undead_skeleton.py): tall, bx, leg, torso, arm, head, shoulder, foot; `bulk` thickens the flesh and bone
  skin       the colour of its bone or flesh; `eyes` the colour of what glints in its sockets
  attack     how it attacks (undead_motion.ATTACKS); `weight` "normal" or "heavy" (a longer held apex, a quicker swing, a bigger settle)
  arms       a pose of the arms (biped_motion.ARMS); `stance` a stance (biped_motion.STANCES); `item_angle` {side: degrees} tilts what it holds
  gear       [(name, {options})...] in undead_gear.GEAR
  still      the frame that becomes the form's still in the game; `width` its drawn width in game pixels (forms_undead_frames.json)
"""

BONE, OLD_BONE, YELLOW_BONE = (208, 192, 156), (192, 174, 138), (208, 190, 136)
RUST, IRON, DKIRON, STEEL, BRONZE, GOLD = (150, 86, 54), (104, 108, 118), (66, 66, 78), (150, 156, 168), (186, 128, 62), (222, 176, 66)
CLOTH, DKCLOTH, TAN, LINEN = (116, 84, 60), (84, 62, 48), (170, 136, 92), (200, 186, 150)
VIOLET, DKVIOLET, LAVENDER = (98, 70, 128), (66, 48, 92), (186, 160, 220)
CYAN, ROSE, CRIMSON, EMBER = (150, 222, 232), (226, 150, 174), (162, 30, 48), (255, 128, 48)
GREEN_BLACK, TEAL, MOSS, FUR = (54, 70, 58), (56, 104, 100), (96, 120, 64), (128, 110, 92)
ZOMBIE, GHOUL, DRAUGR, VAMPIRE, JIANG, JACK, PATCH = (124, 138, 104), (150, 132, 108), (82, 96, 120), (226, 222, 218), (150, 170, 150), (196, 186, 170), (150, 150, 130)
HONEY, WHITE, BLACK = (206, 160, 88), (236, 236, 230), (44, 40, 48)


def G(name, **kw):
    return (name, kw)


FORMS = {
    "skeleton": dict(stage=1, parent=None, width=17, body="biped", posture="bones", style="bone", skin=BONE, attack="slash", arms="free",
                     shape=dict(tall=1.0, bx=0.95), item_angle={"n": 180.0},
                     gear=[G("rag", color=CLOTH), G("sword_short", side="n", color=RUST)]),

    # ---- the shambling line: zombie; ghoul (vampire, jiangshi); draugr (barrow king, abomination) ----
    "zombie": dict(stage=2, parent="skeleton", width=25, body="biped", posture="shamble", style="flesh", skin=ZOMBIE, eyes=(210, 214, 170), attack="maul",
                   weight="heavy", arms="zombie", shape=dict(tall=1.0, bx=1.25, arm=1.12, head=1.05, shoulder=1.15), bulk=1.35,
                   gear=[G("rags", color=(92, 84, 72)), G("trousers", color=(78, 70, 64)), G("bruise", color=(96, 74, 110)), G("ribs_showing"),
                         G("hair_thin", color=(70, 64, 56)), G("clod", color=(110, 86, 58))]),
    "ghoul": dict(stage=3, parent="zombie", width=21, body="biped", posture="ghoul", style="flesh", skin=GHOUL, eyes=(240, 220, 120), attack="swipe",
                  arms="claws", shape=dict(tall=1.05, bx=0.95, arm=1.22, head=0.95, leg=1.05), bulk=0.85,
                  gear=[G("snout", color=GHOUL), G("claws", color=(30, 26, 30)), G("wraps", color=(186, 160, 116)), G("headcloth", color=(170, 146, 106)),
                        G("ribs_showing"), G("stains", color=(96, 72, 108))]),
    "vampire": dict(stage=4, parent="ghoul", width=24, body="biped", posture="regal", style="flesh", skin=VAMPIRE, eyes=CRIMSON, attack="cast",
                    arms="goblet", shape=dict(tall=1.12, bx=0.95), bulk=0.9,
                    gear=[G("hair_slick", color=(36, 32, 40)), G("fangs"), G("waistcoat", color=DKVIOLET), G("trousers", color=(40, 36, 46)),
                          G("boots", color=(36, 32, 40)), G("coat", color=(38, 34, 44), lining=CRIMSON, length=1.05, collar=True),
                          G("goblet", side="n")]),
    "jiangshi": dict(stage=4, parent="ghoul", width=24, body="hop", posture="hop", style="flesh", skin=JIANG, eyes=(230, 236, 200), attack="hop_claw",
                     arms="stiff", shape=dict(tall=1.02, bx=1.0), bulk=0.95,
                     gear=[G("qing_robe", color=TEAL, trim=CYAN), G("official_hat", color=(40, 38, 44)), G("talisman", color=(232, 204, 92)),
                           G("nails", color=(40, 36, 40)), G("boots", color=(40, 38, 44))]),
    "draugr": dict(stage=3, parent="zombie", width=28, body="biped", posture="heavy", style="flesh", skin=DRAUGR, eyes=(220, 236, 240), attack="cleave",
                   weight="heavy", arms="guard", item_angle={"n": 4.0}, shape=dict(tall=1.12, bx=1.4, shoulder=1.3, head=1.0), bulk=1.5,
                   gear=[G("chainmail", color=(96, 98, 104)), G("tunic", color=(92, 84, 76)), G("helm", style="iron", color=IRON), G("beard", color=(150, 150, 146), length=0.30, braid=True),
                         G("arm_ring", color=GOLD), G("greatsword", side="n", color=RUST, length=1.05)]),
    "barrow_king": dict(stage=4, parent="draugr", width=31, body="biped", posture="giant", style="flesh", skin=(110, 112, 104), eyes=(236, 220, 150), attack="slam",
                        weight="heavy", arms="fists", shape=dict(tall=1.18, bx=1.55, shoulder=1.35, arm=1.1), bulk=1.7,
                        gear=[G("plate", color=(110, 104, 92), trim=(128, 98, 58)), G("moss", color=MOSS), G("fur_cloak", color=(96, 80, 60), length=0.8, fur=FUR),
                              G("crown", color=GOLD, style="barrow"), G("beard", color=(156, 152, 146), length=0.34), G("coins", color=GOLD), G("fists", color=(110, 112, 104))]),
    "abomination": dict(stage=4, parent="draugr", width=31, body="biped", posture="heavy", style="flesh", skin=PATCH, eyes=(226, 210, 90), attack="cleave",
                        weight="heavy", arms="cleaver_up", item_angle={"n": 10.0}, shape=dict(tall=1.15, bx=1.45, shoulder=1.3, head=0.92), bulk=1.6,
                        gear=[G("patches", colors=[(126, 146, 110), (184, 162, 128), (120, 120, 120)]), G("stitches", color=(30, 28, 32)), G("big_arm"),
                              G("spare_arm"), G("shoulder_plate", color=IRON), G("chains", color=DKIRON), G("trousers", color=(78, 66, 56)),
                              G("cleaver", side="n", color=(150, 150, 156), big=1.5)]),

    # ---- the warrior line: bone warrior; revenant knight (dullahan, bone colossus); spartoi hoplite (sower of teeth, master of the dance) ----
    "bone_warrior": dict(stage=2, parent="skeleton", width=25, body="biped", posture="braced", style="bone", skin=(200, 184, 150), eyes=VIOLET, attack="chop",
                         arms="guard_n", shape=dict(tall=1.0, bx=1.3, shoulder=1.15), bulk=1.45,
                         gear=[G("fang_jaw"), G("helm", style="crest", color=BRONZE, crest=CRIMSON), G("pauldron", color=BRONZE, side="n"),
                               G("rag", color=(120, 92, 62)), G("shield", side="f", color=BRONZE, size=0.95), G("cleaver", side="n", color=BRONZE)]),
    "revenant_knight": dict(stage=3, parent="bone_warrior", width=28, body="biped", posture="knight", style="bone", skin=OLD_BONE, eyes=LAVENDER, attack="cleave",
                            weight="heavy", arms="guard", item_angle={"n": 4.0}, shape=dict(tall=1.14, bx=1.2, shoulder=1.15), bulk=1.2,
                            gear=[G("plate", color=(64, 64, 74), trim=(92, 88, 96)), G("helm", style="great", color=(64, 64, 74), slit=LAVENDER),
                                  G("surcoat", color=DKVIOLET), G("chains", color=RUST), G("greaves", color=(64, 64, 74)), G("greatsword", side="n", color=(130, 128, 136), length=1.15)]),
    "dullahan": dict(stage=4, parent="revenant_knight", width=31, body="biped", posture="knight", style="bone", skin=OLD_BONE, eyes=(236, 220, 140), attack="whip",
                     arms="head_whip", shape=dict(tall=1.18, bx=1.15, shoulder=1.1), bulk=1.2, headless=True,
                     gear=[G("plate", color=(46, 44, 54), trim=(72, 68, 80)), G("cloak", color=DKVIOLET, length=0.85, spread=0.0), G("greaves", color=(46, 44, 54)),
                           G("head_held", hair=(70, 60, 50)), G("whip", length=1.0)]),
    "bone_colossus": dict(stage=4, parent="revenant_knight", width=31, body="biped", posture="giant", style="bone", skin=(204, 188, 150), eyes=(200, 190, 150), attack="cleave",
                          weight="heavy", arms="guard", item_angle={"n": 6.0}, shape=dict(tall=1.2, bx=1.55, shoulder=1.45, head=0.62, arm=1.1), bulk=2.1,
                          gear=[G("boulders", color=(204, 188, 150)), G("iron_bands", color=DKIRON), G("moss", color=MOSS), G("rocks", color=(120, 116, 110)),
                                G("bone_cleaver", side="n", color=RUST)]),
    "spartoi_hoplite": dict(stage=3, parent="bone_warrior", width=21, body="biped", posture="hoplite", style="bone", skin=(204, 190, 156), eyes=VIOLET, attack="spear",
                            arms="shield_spear", item_angle={"f": 0.0}, shape=dict(tall=0.96, bx=1.05), bulk=1.1,
                            gear=[G("helm", style="corinthian", color=BRONZE, crest=(54, 44, 50)), G("cuirass", color=BRONZE), G("greaves", color=BRONZE),
                                  G("rag", color=(150, 116, 80)), G("shield", side="n", color=BRONZE, size=1.15, forward=True), G("spear", side="f", length=1.25)]),
    "sower_of_teeth": dict(stage=4, parent="spartoi_hoplite", width=24, body="biped", posture="bones", style="bone", skin=(208, 194, 160), eyes=VIOLET, attack="throw",
                           arms="sow", shape=dict(tall=1.04, bx=1.0), bulk=1.0,
                           gear=[G("chiton", color=(176, 146, 104)), G("cuirass", color=BRONZE, small=True), G("helm", style="pushed", color=BRONZE),
                                 G("seed_bag", color=(120, 84, 52)), G("fangs", side="n"), G("dagger_belt", color=BRONZE)]),
    "master_of_the_dance": dict(stage=4, parent="spartoi_hoplite", width=24, body="biped", posture="dancer", style="bone", skin=BONE, eyes=VIOLET, attack="cast",
                                arms="flourish", stance="dance", shape=dict(tall=1.14, bx=0.92, leg=1.05), bulk=0.95,
                                gear=[G("doublet", color=DKVIOLET), G("ruff", color=(206, 200, 196)), G("cape", color=VIOLET, length=0.55),
                                      G("cap", style="feathered", color=DKVIOLET, feather=(220, 214, 200)), G("pointed_shoes", color=(54, 44, 60))]),

    # ---- the archer line: skeletal archer; deadeye (arash, wild huntsman); corpse candle (stingy jack, banshee) ----
    "skeletal_archer": dict(stage=2, parent="skeleton", width=19, body="biped", posture="alert", style="bone", skin=BONE, eyes=CYAN, attack="shoot",
                            arms="bow", shape=dict(tall=0.98, bx=0.92), bulk=0.95,
                            gear=[G("hood", color=(118, 104, 92)), G("scarf", color=CYAN), G("quiver", color=(110, 82, 56), fletch=WHITE),
                                  G("throwing_bones"), G("bow", side="f", color=(184, 166, 128), half=0.42)]),
    "deadeye": dict(stage=3, parent="skeletal_archer", width=21, body="biped", posture="alert", style="bone", skin=BONE, eyes=VIOLET, attack="shoot",
                    arms="bow", shape=dict(tall=1.02, bx=0.95), bulk=1.0, one_eye=True,
                    gear=[G("hunting_coat", color=GREEN_BLACK), G("cap", style="plumed", color=(40, 50, 44), feather=(150, 60, 60)),
                          G("bandolier", color=(86, 64, 46), tips=[STEEL] * 6 + [VIOLET]), G("bow", side="f", color=(120, 84, 56), half=0.50)]),
    "arash": dict(stage=4, parent="deadeye", width=24, body="biped", posture="alert", style="bone", skin=(220, 214, 196), eyes=CYAN, attack="shoot", aim=45.0,
                  arms="bow", shape=dict(tall=1.06, bx=0.9), bulk=0.9, glow_ribs=CYAN, still="attack_3",
                  gear=[G("cap", style="pointed", color=(178, 60, 52)), G("scale_vest", color=(150, 130, 86)), G("sash", color=(170, 62, 54)),
                        G("bow", side="f", color=(176, 140, 84), half=0.58), G("arrow_glow", color=CYAN)]),
    "wild_huntsman": dict(stage=4, parent="deadeye", width=24, body="biped", posture="stride", style="bone", skin=(204, 194, 170), eyes=(220, 240, 244), attack="shoot",
                          arms="bow", shape=dict(tall=1.12, bx=0.95, head=1.05), bulk=1.0,
                          gear=[G("antlers", color=(176, 150, 112)), G("cloak", color=DKVIOLET, lining=CYAN, length=0.95, ragged=True),
                                G("horn_hip", color=(206, 196, 168)), G("quiver", color=(46, 40, 50), fletch=CYAN), G("bow", side="f", color=(84, 66, 52), half=0.50)]),
    "corpse_candle": dict(stage=3, parent="skeletal_archer", width=18, body="candle", posture="float", skin=CYAN, attack="flare",
                          shape=dict(tall=1.0), core=DKVIOLET, wax=(222, 214, 190), gear=[]),
    "stingy_jack": dict(stage=4, parent="corpse_candle", width=24, body="biped", posture="wanderer", style="flesh", skin=JACK, eyes=(250, 190, 120), attack="lantern",
                        arms="lantern_up", item_angle={"n": 0.0}, shape=dict(tall=1.0, bx=0.92, arm=1.05), bulk=0.85,
                        gear=[G("patched_coat", color=(92, 82, 74), patches=[(118, 100, 80), (76, 70, 86)]), G("flat_cap", color=(70, 64, 60)), G("grin"),
                              G("trousers", color=(66, 60, 58)), G("boots", color=(56, 48, 44)), G("pocket_hand"), G("lantern", side="n", color=EMBER)]),
    "banshee": dict(stage=4, parent="corpse_candle", width=20, body="ghost", posture="float", skin=(222, 236, 240), attack="wail",
                    shape=dict(tall=1.0), shroud=(176, 214, 226), hair=(236, 240, 242), shadow=DKVIOLET, gear=[]),

    # ---- the caster line: adept; lich (deathless, demilich, hierophant); mummy priest (pharaoh, heart weigher) ----
    "adept": dict(stage=2, parent="skeleton", width=19, body="biped", posture="bones", style="bone", skin=BONE, eyes=VIOLET, attack="cast",
                  arms="palm_up", shape=dict(tall=0.96, bx=0.92), bulk=0.95,
                  gear=[G("robe", color=DKVIOLET, length=0.62), G("hood", color=DKVIOLET, deep=True), G("charm", color=BONE),
                        G("staff", side="n", color=(110, 80, 52), top="crystal", glow=VIOLET, length=1.05)]),
    "lich": dict(stage=3, parent="adept", width=21, body="biped", posture="regal", style="bone", skin=OLD_BONE, eyes=ROSE, attack="cast",
                 arms="beckon", shape=dict(tall=1.06, bx=0.95), bulk=1.0,
                 gear=[G("robe", color=(44, 38, 52), length=0.78, collar=DKVIOLET), G("cloak", color=DKVIOLET, length=1.0), G("crown", color=(150, 146, 140), style="jagged"),
                       G("phylactery", color=ROSE), G("staff", side="n", color=(66, 58, 60), top="skull", glow=ROSE, length=1.2)]),
    "deathless": dict(stage=4, parent="lich", width=24, body="biped", posture="regal", style="bone", skin=(206, 196, 176), eyes=ROSE, attack="cast",
                      arms="hilt", shape=dict(tall=1.16, bx=0.9, head=1.0), bulk=0.9,
                      gear=[G("robe", color=DKVIOLET, length=0.82, collar=(200, 190, 176), trim=(196, 186, 200)), G("cap", style="fur_tall", color=(186, 176, 162), band=DKVIOLET),
                            G("beard", color=(232, 230, 222), length=0.42), G("locket", color=(232, 226, 210), gem=ROSE), G("sword_hilt", color=GOLD, gem=ROSE)]),
    "demilich": dict(stage=4, parent="lich", width=20, body="skull", posture="float", skin=YELLOW_BONE, eyes=VIOLET, attack="dive",
                     shape=dict(tall=1.0), gem=ROSE, band=(150, 130, 90), gear=[]),
    "hierophant": dict(stage=4, parent="lich", width=24, body="biped", posture="still", style="mummy", skin=HONEY, eyes=None, attack="cast",
                       arms="bless", shape=dict(tall=1.14, bx=0.98), bulk=1.0,
                       gear=[G("nimbus", color=GOLD), G("robe", color=(226, 218, 196), length=0.84, trim=GOLD), G("stole", color=GOLD, bands=ROSE),
                             G("cap", style="ceremonial", color=(230, 222, 200), band=GOLD), G("staff", side="n", color=GOLD, top="sun", glow=GOLD, length=1.3)]),
    "mummy_priest": dict(stage=3, parent="adept", width=21, body="biped", posture="mummy", style="mummy", skin=(206, 184, 136), eyes=VIOLET, attack="cast",
                         arms="raise_n", shape=dict(tall=0.98, bx=1.05), bulk=1.25,
                         gear=[G("wrap_stripes", color=(140, 118, 84)), G("collar_gold", color=GOLD), G("headcloth", color=DKVIOLET, stripes=(132, 112, 160)),
                               G("bandages", color=(196, 180, 140)), G("sand", color=(196, 170, 120))]),
    "pharaoh": dict(stage=4, parent="mummy_priest", width=24, body="biped", posture="regal", style="mummy", skin=LINEN, eyes=VIOLET, attack="cast",
                    arms="crossed", shape=dict(tall=1.2, bx=1.0), bulk=1.05,
                    gear=[G("wrap_stripes", color=(166, 146, 110)), G("nemes", color=GOLD, stripes=(52, 76, 150)), G("false_beard", color=(52, 76, 150)),
                          G("collar_gold", color=GOLD), G("cloak", color=DKVIOLET, length=1.1), G("crook_flail", color=GOLD, band=(52, 76, 150)),
                          G("bandages", color=(196, 180, 140))]),
    "heart_weigher": dict(stage=4, parent="mummy_priest", width=24, body="biped", posture="still", style="mummy", skin=(150, 128, 104), eyes=(236, 210, 120), attack="bite",
                          arms="scale", shape=dict(tall=1.24, bx=0.95), bulk=1.0,
                          gear=[G("croc_head", color=(118, 140, 92), teeth=WHITE), G("mane", color=(92, 74, 60)), G("kilt", color=DKVIOLET, stripes=GOLD),
                                G("wrap_stripes", color=(108, 90, 74)), G("balance", side="n", color=(196, 150, 70), heart=CRIMSON, feather=WHITE)]),
}

ORDER = list(FORMS)
BIPEDS = [n for n, f in FORMS.items() if f["body"] in ("biped", "hop")]
FLOATERS = [n for n, f in FORMS.items() if f["body"] in ("candle", "ghost", "skull")]
