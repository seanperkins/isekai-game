"""The wolf family as data: the base gloom wolf and the forms of `data/forms/wolf_*.tres`, described the way tools/art/forms_wolf_frames.json describes
them. A form names its proportions, colours and gear (wolf_gear.py). The upright werewolves (`body: "biped"`) are built by the werewolf kit instead.

  leg, neck, tail, head   proportions: leg length (a hound is above 1), neck, tail and head
  bulk                    how thick every part is
  fur, belly, dark, tail_colour, ear, eye, star_colour   colours
  tail_shape              the tail's carriage (quad_skeleton.TAIL_*)
  star                    False for a form with no mark on its forehead
  gear                    [(name, {options})...] in wolf_gear.GEAR
  gait                    "glide" for a creature that flies
  width                   the form's drawn width in game pixels, from tools/art/forms_wolf_frames.json
"""
import quad_skeleton as qs
from wolf_gear import BONE_C, CRIMSON, CYAN, EMBER, GOLD, IRON, LEATHER, TAN

NEAR_BLACK, VIOLET_BLACK = (62, 56, 70), (44, 38, 56)
GHOST, ICE_FUR = (226, 226, 232), (66, 72, 92)


def G(name, **kw):
    return (name, kw)


FORMS = {
    "gloom_wolf": dict(stage=1, parent=None, width=55, gear=[]),

    # ---- the hound line: black dog, barghest, hellhound, black shuck; cwn annwn, cu sith, gabriel hound ----
    "black_dog": dict(stage=2, parent="gloom_wolf", width=60, leg=1.08, neck=0.9, tail=1.15, head=0.95, bulk=0.88, fur=(50, 46, 60),
                      gear=[G("wisps", color=CYAN)]),
    "barghest": dict(stage=3, parent="black_dog", width=68, leg=1.2, neck=1.1, tail=1.2, head=1.05, bulk=0.95, fur=(40, 34, 52), eye=(236, 230, 255),
                     gear=[G("ruff", size=1.25, color=(52, 44, 70)), G("wisps", color=(120, 90, 190))]),
    "hellhound": dict(stage=4, parent="barghest", width=76, leg=1.1, neck=1.0, bulk=1.25, head=1.1, fur=(46, 40, 50), eye=EMBER, star_colour=EMBER,
                      gear=[G("ruff", size=1.1), G("collar", color=IRON, spikes=True, chain=IRON), G("cracks"), G("flames")]),
    "black_shuck": dict(stage=4, parent="barghest", width=76, leg=0.9, neck=0.95, tail=1.2, head=1.15, bulk=1.3, fur=(42, 38, 52), star=False,
                        gear=[G("ruff", size=1.1), G("single_eye"), G("wisps", color=(110, 80, 170))]),
    "cwn_annwn": dict(stage=3, parent="black_dog", width=68, leg=1.2, bulk=0.88, fur=GHOST, belly=(244, 244, 248), eye=(246, 206, 96), star_colour=GOLD,
                      ear=CRIMSON, tail_colour=(236, 236, 240), gear=[G("wisps", color=GOLD, where=("tail3", "paw_n", "paw_f"))]),
    "cu_sith": dict(stage=4, parent="cwn_annwn", width=76, leg=1.3, neck=1.1, tail=1.15, head=1.0, bulk=1.0, fur=(56, 84, 64), belly=(86, 112, 90),
                    tail_colour=(64, 94, 72), tail_shape=qs.TAIL_RAISED, tail_r=0.7, eye=(170, 236, 236), star_colour=(190, 240, 210),
                    gear=[G("wisps", color=CYAN, where=("paw_n", "paw_f"))]),
    "gabriel_hound": dict(stage=4, parent="cwn_annwn", width=76, leg=1.15, bulk=0.85, fur=(168, 174, 200), belly=(200, 206, 224), eye=(170, 236, 246), star_colour=(190, 230, 240),
                          tail_colour=(186, 192, 214), gait="glide", gear=[G("wisps", color=CYAN, where=("tail3", "tail2", "paw_n", "paw_f", "meta_n", "meta_f"))]),

    # ---- the war wolf line: warg, church grim, dire wolf; lupa, wepwawet; fenrir, amarok ----
    "warg": dict(stage=2, parent="gloom_wolf", width=60, leg=0.92, neck=0.85, head=1.2, bulk=1.2, fur=(66, 58, 62), eye=(240, 196, 110),
                 gear=[G("harness")]),
    "church_grim": dict(stage=3, parent="warg", width=68, leg=1.0, neck=1.0, head=1.05, bulk=1.08, fur=(46, 42, 54), eye=(246, 206, 96), star_colour=GOLD,
                        gear=[G("collar", color=TAN, stone=(170, 150, 110))]),
    "dire_wolf": dict(stage=3, parent="warg", width=68, leg=0.88, neck=0.75, tail=0.9, head=1.3, bulk=1.45, fur=(56, 50, 58), eye=(240, 196, 110),
                      gear=[G("ruff", size=1.3), G("plates", color=TAN)]),
    "lupa": dict(stage=4, parent="church_grim", width=76, leg=1.0, bulk=1.1, fur=(58, 50, 54), belly=(120, 96, 84), eye=(246, 176, 196), star_colour=(244, 150, 180),
                 gear=[G("belly_panel"), G("teats"), G("wisps", color=(244, 190, 150), where=("tail3",))]),
    "wepwawet": dict(stage=4, parent="church_grim", width=76, leg=1.35, neck=1.15, head=0.95, bulk=0.85, fur=(40, 36, 46), eye=(246, 206, 96), star_colour=GOLD,
                     ears=1.5, gear=[G("gold_collar"), G("sash", color=CYAN)]),
    "fenrir": dict(stage=4, parent="dire_wolf", width=76, leg=0.95, neck=0.85, head=1.3, bulk=1.55, fur=(52, 46, 54), eye=(240, 196, 110),
                   gear=[G("ruff", size=1.5), G("chains")]),
    "amarok": dict(stage=4, parent="dire_wolf", width=76, leg=1.2, neck=0.95, head=1.15, bulk=1.15, fur=ICE_FUR, belly=(120, 130, 150), eye=(180, 226, 246), star_colour=(180, 226, 246),
                   gear=[G("ruff", size=1.2, color=(82, 90, 112)), G("frost")]),

    # ---- the werewolf line: stands upright (the werewolf kit) ----
    "moonbound": dict(stage=2, parent="gloom_wolf", width=45, body="biped", creature="werewolf", arms="free", attack="claw", gear=[]),
    "loup_garou": dict(stage=3, parent="moonbound", width=50, body="biped", creature="werewolf", tall=1.05, bulk=1.1, stance="hunch", eye=(236, 120, 150), arms="free", attack="claw",
                       gear=[G("breeches"), G("blood")]),
    "ulfhedinn": dict(stage=3, parent="moonbound", width=50, body="biped", creature="werewolf", tall=1.05, bulk=1.15, arms="guard", attack="claw", eye=(220, 214, 255),
                      gear=[G("pelt"), G("straps"), G("bracers"), G("paint")]),
    "beast_of_gevaudan": dict(stage=4, parent="loup_garou", width=56, body="biped", creature="werewolf", tall=1.1, arm=1.15, bulk=0.95, head=1.1, stance="hunch", arms="offer", attack="claw",
                              eye=(200, 210, 230), gear=[G("mane"), G("stripe"), G("blood")]),
    "lycaon": dict(stage=4, parent="loup_garou", width=56, body="biped", creature="werewolf", tall=1.1, bulk=0.9, attack="cast", arms="raise_n", eye=(220, 210, 255),
                   tail_colour=(60, 52, 80), gear=[G("cloak"), G("crown")]),
    "wolfskin_champion": dict(stage=4, parent="ulfhedinn", width=56, body="biped", creature="werewolf", tall=1.12, bulk=1.25, arms="shield", attack="claw", eye=(220, 214, 255),
                              gear=[G("pelt"), G("straps"), G("bracers"), G("trophies"), G("paint"), G("shield")]),
    # skoll is a galloping four-legged wolf, a child of the ulfhedinn
    "skoll": dict(stage=4, parent="ulfhedinn", width=76, leg=1.1, neck=0.75, bulk=0.9, tail=1.3, tail_shape=qs.TAIL_RAISED, fur=(46, 42, 56), eye=(170, 236, 246), star_colour=(170, 236, 246),
                  gear=[G("ruff", size=1.5), G("wisps", color=CYAN)]),
}

ORDER = list(FORMS)
QUADS = [n for n, f in FORMS.items() if f.get("body", "quad") == "quad" and n != "gloom_wolf"]
BIPEDS = [n for n, f in FORMS.items() if f.get("body") == "biped"]
