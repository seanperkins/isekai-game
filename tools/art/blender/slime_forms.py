"""The slime family as data: the plain blue jelly slime and its eighteen stage-four forms (data/creatures/twin_<form>.tres), described the way
tools/art/forms_slime_frames.json describes them. Pure Python.

  shape     the rest dome (slime_motion.Shape): R half-width, D half-depth, H height, zc where it is widest, n_top/n_bot/plan exponents, lumps, snout
  colours   jelly (the body), rim (its bright gel edge), core (the inner glow), eye
  chains    appendages as bone chains rooted on the surface: name, at (plan angle, elevation), links [(direction, length)], and their springs
            (freq, zeta, drag), idle sway, attack lash_sign, death droop
  groups    {group: pivot} of loose parts the motion moves (pebbles, cloud puffs, a crown, a pulse, plates, cracks, bubbles, sparkles)
  inner     the pivot of the things inside the jelly that lag it (a stone, a coin, the beans)
  hover     how high a hovering form floats (it bobs and glides instead of hopping)
  stiff     how much it gives (1 jelly; the cube and the talos much less: they slam and slump)
  attack    lunge (the default), slam, lash (with `lash` the striking chain), throw, pulse, bite
  gear      [(name, {options})] in slime_gear.GEAR
  width     its drawn width in game pixels (forms_slime_frames.json)
  parent    the base, for the boards (the game's own tree is data/forms: snare, arachne, tempest... are other species' stage three)
"""
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
BASE_SPEED = 60.0


def G(name, **kw):
    return (name, kw)


def C(name, at, links, **kw):
    return dict(name=name, at=at, links=links, **kw)


SILVER, GOLD, BRASS, RUBY = (206, 214, 236), (236, 186, 70), (206, 170, 96), (220, 50, 70)

FORMS = {
    "slime": dict(stage=1, parent=None, width=44, shape=dict(H=0.78), colours=dict(jelly=(34, 150, 238), rim=(120, 232, 255), core=(70, 182, 250)), gear=[]),

    # ---- bound and threaded ----
    "gleipnir": dict(stage=4, parent="slime", branch="snare", width=62, colours=dict(jelly=(44, 56, 156), rim=(116, 140, 228), core=(76, 100, 210)),
                     chains=[C("rib_a", (172, 74), [(-80, 0.24), (-50, 0.22)], sway=10, freq=2.4, drag=40, droop=40),
                             C("rib_b", (168, 72), [(-112, 0.22), (-92, 0.20)], sway=12, phase=1.4, freq=2.6, drag=40, droop=60)],
                     gear=[G("bands", colour=SILVER, at=(18, 46, -10)), G("bow", colour=SILVER), G("glints", colour=(236, 244, 255))]),
    "ariadne": dict(stage=4, parent="slime", branch="arachne", width=62, colours=dict(jelly=(146, 216, 234), rim=(226, 250, 255), core=(196, 240, 250)),
                    chains=[C("thread", (182, 2), [(-72, 0.08), (-28, 0.07), (40, 0.06), (100, 0.05)], sway=14, freq=2.0, drag=30, droop=60, lift=0.12)],
                    inner=(0.0, -0.3, 0.30),
                    gear=[G("spiral", colour=(255, 196, 228)), G("spool", colour=(240, 190, 210)), G("blush")]),
    "beanstalk": dict(stage=4, parent="slime", branch="arachne", width=62, colours=dict(jelly=(122, 214, 178), rim=(196, 250, 222), core=(160, 236, 200)),
                      chains=[C("vine", (150, 62), [(176, 0.15), (198, 0.14), (160, 0.13), (205, 0.10)], sway=7, freq=2.2, zeta=0.35, drag=25, lash_sign=1.0, droop=-70)],
                      attack="lash", lash="vine", inner=(0.02, -0.3, 0.24),
                      gear=[G("leaves", colour=(70, 160, 70)), G("beans", colour=(206, 170, 110)), G("lumps", colour=(150, 116, 80))]),
    "selkie": dict(stage=4, parent="slime", branch="brook", width=61, shape=dict(R=0.52, H=0.56, D=0.42, zc=0.30, snout=(0.16, 4.0)),
                   colours=dict(jelly=(62, 150, 222), rim=(156, 222, 255), core=(110, 196, 246)),
                   chains=[C("pelt", (178, 45), [(-30, 0.16), (-8, 0.12)], sway=5, freq=2.0, zeta=0.45, drag=35, droop=30, lift=0.06)],
                   gear=[G("pelt", colour=(150, 140, 122), spots=(108, 100, 92)), G("whiskers", colour=(236, 240, 246)), G("droplets", colour=(220, 244, 255))]),

    # ---- the deep ----
    "kraken": dict(stage=4, parent="slime", branch="tempest", width=62, shape=dict(R=0.46, H=0.64), colours=dict(jelly=(40, 70, 170), rim=(100, 132, 226), core=(70, 104, 206)),
                   chains=[C("t_back", (178, 10), [(-118, 0.15), (-160, 0.14), (160, 0.12), (110, 0.09)], sway=8, freq=2.2, drag=30, droop=-70, clear=0.08),
                           C("t_far", (130, 50), [(-165, 0.14), (175, 0.13), (130, 0.10), (80, 0.08)], sway=8, phase=2.0, freq=2.4, drag=30, droop=-90, clear=0.08),
                           C("t_near", (-140, 40), [(-150, 0.13), (175, 0.12), (140, 0.10), (95, 0.07)], sway=8, phase=1.0, freq=2.3, drag=30, droop=-70, clear=0.08),
                           C("t_front", (-50, 10), [(105, 0.13), (140, 0.12), (185, 0.10), (235, 0.07)], sway=7, phase=3.0, freq=2.5, drag=25, droop=60, clear=0.08)],
                   attack="lash", lash="t_front", gear=[G("swirl", colour=(120, 160, 236)), G("suckers", colour=(176, 160, 230))]),
    "tiamat": dict(stage=4, parent="slime", branch="tempest", width=62, colours=dict(jelly=(28, 104, 128), rim=(96, 196, 206), core=(56, 150, 170)),
                   gear=[G("crest", colour=(226, 246, 250), deep=(80, 170, 190)), G("horns", colour=(190, 76, 84)), G("serpents", colour=(70, 170, 180)),
                         G("glints", colour=(240, 236, 250))]),

    # ---- acid and blight ----
    "alkahest": dict(stage=4, parent="slime", branch="acid", width=62, colours=dict(jelly=(190, 220, 232), rim=(246, 252, 255), core=(222, 238, 244)),
                     chains=[C("drip_a", (176, -10), [(-30, 0.08), (-8, 0.06)], sway=6, freq=1.8, drag=30, droop=20, clear=0.06),
                             C("drip_b", (140, -25), [(-14, 0.06), (0, 0.05)], sway=5, phase=1.2, freq=2.0, drag=25, clear=0.06),
                             C("drip_c", (-120, -30), [(-4, 0.05)], sway=4, phase=2.0, freq=2.2, drag=20, clear=0.06)],
                     groups={"bubble0": (0.10, -0.40, 0.22), "bubble1": (-0.06, -0.40, 0.30), "bubble2": (0.18, -0.36, 0.38)}, bubble_rise=0.28,
                     gear=[G("bubbles", colour=(250, 252, 255)), G("flecks", colour=(176, 140, 90)), G("drips", colour=(214, 196, 140))]),
    "pestilence": dict(stage=4, parent="slime", branch="blight", width=62, no_core=True, colours=dict(jelly=(98, 80, 116), rim=(160, 140, 178), core=(150, 196, 96)),
                       chains=[C("mia_a", (176, 50), [(-140, 0.15), (-112, 0.15), (-135, 0.14), (-108, 0.12)], sway=14, freq=1.4, zeta=0.3, drag=40),
                               C("mia_b", (150, 78), [(-172, 0.14), (-140, 0.14), (-160, 0.13), (-130, 0.11)], sway=16, phase=1.8, freq=1.5, zeta=0.3, drag=40)],
                       gear=[G("blotches", colour=(120, 160, 80)), G("boils", colour=(140, 110, 156)), G("miasma", colour=(150, 186, 110), dark=(156, 128, 182)), G("tatters")]),
    "slime_mold": dict(stage=4, parent="slime", branch="blight", width=62, shape=dict(R=0.62, D=0.46, H=0.40, zc=0.24, n_top=2.7, n_bot=3.6),
                       colours=dict(jelly=(214, 184, 96), rim=(252, 226, 150), core=(240, 210, 120)),
                       gear=[G("veins", colour=(236, 140, 26)), G("nodes", colour=(250, 130, 180)), G("tendrils", colour=(226, 190, 80))]),

    # ---- metal and stone ----
    "talos": dict(stage=4, parent="slime", branch="golem", width=62, stiff=0.32, shape=dict(R=0.52, H=0.66, zc=0.34, n_top=2.3),
                  core_glow=True, core_at=(-100, -10), colours=dict(jelly=(210, 92, 36), rim=(250, 170, 90), core=(255, 200, 70)),
                  groups={"plate0": (-0.36, -0.25, 0.34), "plate1": (-0.10, -0.33, 0.52), "plate2": (0.26, -0.25, 0.48), "plate3": (-0.06, -0.1, 0.64)},
                  gear=[G("plates", colour=(112, 72, 44), rivet=(240, 196, 128)), G("nail", colour=(176, 130, 70), ichor=(255, 70, 40))]),
    "philosophers_stone": dict(stage=4, parent="slime", branch="crystal", width=62, core_glow=True, core_size=1.3, colours=dict(jelly=(226, 170, 70), rim=(255, 222, 136), core=(255, 206, 110)),
                               inner=(0.02, -0.3, 0.28), inner_gain=1.6,
                               groups={"spark0": (-0.22, -0.3, 0.42), "spark1": (0.20, -0.3, 0.18), "spark2": (-0.05, -0.32, 0.52), "spark3": (0.28, -0.25, 0.36)},
                               gear=[G("stone", colour=(226, 64, 48), ring=(255, 244, 200)), G("sparks", colour=(255, 240, 170))]),
    "cube": dict(stage=4, parent="slime", branch="crystal", width=62, stiff=0.28,
                 shape=dict(R=0.44, D=0.40, H=0.80, zc=0.5, n_top=9.0, n_bot=9.0, plan=8.0),
                 colours=dict(jelly=(204, 218, 158), rim=(244, 252, 222), core=(226, 238, 190)), inner=(0.0, -0.3, 0.36), inner_gain=1.2,
                 groups={"crack": (0.0, -0.4, 0.4)},
                 gear=[G("coin", colour=(232, 190, 70)), G("bone", colour=(214, 196, 150)), G("cracks", colour=(120, 130, 90)), G("edges", colour=(250, 255, 236))]),
    "mimic": dict(stage=4, parent="slime", branch="phantom", width=62, attack="bite", eyes=False,
                  shape=dict(R=0.50, D=0.40, H=0.42, zc=0.5, n_top=7.0, n_bot=7.0, plan=6.0),
                  colours=dict(jelly=(156, 222, 240), rim=(222, 250, 255), core=(196, 238, 250)),
                  chains=[C("lid", (180, 66), [(90, 0.98)], sway=0, freq=14.0, zeta=1.0, drag=0, lift=0.02)],
                  gear=[G("lid", colour=(132, 206, 232), band=BRASS), G("bands", colour=BRASS, vertical=(-40, -140)), G("teeth", colour=(250, 250, 244)),
                        G("tongue", colour=(240, 120, 150)), G("blush")]),
    "poltergeist": dict(stage=4, parent="slime", branch="phantom", width=62, hover=0.10, attack="throw", shape=dict(R=0.48, H=0.62, zc=0.36),
                        colours=dict(jelly=(176, 228, 240), rim=(236, 252, 255), core=(206, 242, 252)), pebble_r=0.045,
                        chains=[C("tail", (180, 8), [(-74, 0.13), (-94, 0.11), (-70, 0.08)], sway=9, freq=1.8, zeta=0.35, drag=35)],
                        groups={"pebble0": (0.50, -0.30, 0.16), "pebble1": (-0.30, -0.36, 0.58), "pebble2": (0.22, -0.30, 0.74), "pebble3": (-0.20, -0.2, 0.0)},
                        gear=[G("wisp", colour=(206, 242, 252)), G("pebbles", colour=(176, 146, 104), brick=(176, 94, 72))]),
    "cloud_rider": dict(stage=4, parent="slime", branch="sky", width=62, hover=0.30, puff_h=0.10, shape=dict(R=0.40, H=0.56, D=0.36),
                        colours=dict(jelly=(150, 216, 240), rim=(226, 248, 255), core=(196, 236, 250)),
                        groups={"puff0": (-0.38, -0.06, -0.10), "puff1": (-0.14, -0.12, -0.12), "puff2": (0.12, -0.12, -0.12), "puff3": (0.36, -0.06, -0.10),
                                "puff4": (-0.26, 0.08, -0.04), "puff5": (0.24, 0.08, -0.04),
                                "puff6": (-0.56, -0.04, -0.04), "puff7": (-0.66, -0.06, 0.07), "puff8": (-0.58, -0.08, 0.15)},
                        gear=[G("cloud", colour=(244, 250, 252), shade=(196, 230, 244)), G("air", colour=(226, 246, 255))]),

    # ---- the vast and the radiant ----
    "shoggoth": dict(stage=4, parent="slime", branch="vast", width=62, attack="lash", lash="p_front",
                     shape=dict(R=0.54, D=0.44, H=0.58, zc=0.30, n_top=2.2, lumps=((0.10, 3, 2, 0.4), (0.08, 5, -3, 1.9), (0.06, 8, 4, 3.1))),
                     colours=dict(jelly=(74, 52, 104), rim=(150, 110, 200), core=(100, 70, 140), eye=(16, 10, 24)),
                     chains=[C("p_front", (-20, 10), [(105, 0.13), (130, 0.10), (165, 0.07)], sway=10, freq=2.4, drag=30, droop=-40, clear=0.10),
                             C("p_back", (178, 10), [(-108, 0.13), (-135, 0.10), (-170, 0.07)], sway=10, phase=1.0, freq=2.2, drag=30, droop=40, clear=0.10),
                             C("p_top", (110, 72), [(205, 0.12), (170, 0.09), (130, 0.07)], sway=12, phase=2.0, freq=2.6, drag=30, droop=-90, clear=0.10),
                             C("p_up", (-130, 62), [(-150, 0.11), (-180, 0.08), (-210, 0.06)], sway=11, phase=4.0, freq=2.5, drag=30, droop=-80, clear=0.10),
                             C("p_front2", (-40, 50), [(135, 0.10), (165, 0.08)], sway=9, phase=5.0, freq=2.6, drag=30, droop=-60, clear=0.10),
                             C("p_low", (-150, -40), [(-60, 0.11), (-25, 0.08)], sway=8, phase=3.0, freq=2.4, drag=25, clear=0.10)],
                     gear=[G("many_eyes"), G("sheen", colour=(110, 150, 190))]),
    "king_slime": dict(stage=4, parent="slime", branch="radiant", width=62, attack="pulse", shape=dict(R=0.52, H=0.66, zc=0.33),
                       core_glow=True, core_size=0.75, core_at=(-100, -40), colours=dict(jelly=(40, 92, 214), rim=(122, 172, 252), core=(250, 206, 96)),
                       groups={"crown": (0.04, 0.0, 0.70), "pulse": (0.0, 0.0, 0.30), "spark0": (-0.40, -0.2, 0.62), "spark1": (0.46, -0.2, 0.70),
                               "spark2": (-0.52, -0.1, 0.30), "spark3": (0.56, -0.1, 0.40)},
                       gear=[G("crown", colour=GOLD, gem=RUBY), G("sparks", colour=(255, 236, 150)), G("pulse", colour=(255, 226, 120))]),
    "quicksilver_slime": dict(stage=4, parent="slime", branch="radiant", width=62, shape=dict(R=0.52, H=0.58, zc=0.30, n_top=2.2),
                              no_core=True, colours=dict(jelly=(150, 158, 180), rim=(246, 250, 255), core=(222, 230, 244), eye=(30, 34, 52)),
                              groups={"bubble0": (0.62, -0.1, 0.03), "bubble1": (-0.62, -0.1, 0.03)}, bubble_rise=0.0,
                              gear=[G("mirror", colour=(250, 252, 255), dark=(110, 118, 140)), G("droplets", colour=(220, 226, 240), groups=True)]),
}

ORDER = list(FORMS)
STAGE4 = [n for n in FORMS if n != "slime"]


def twin_path(form):
    """The slime twins are named by their form alone (data/creatures/twin_<form>.tres, not twin_slime_<form> as sizing.twin_path expects)."""
    return os.path.join(ROOT, "data", "creatures", "twin_%s.tres" % form)


def speed_of(form):
    """How fast this form crosses the ground in the game, in the sprite's own pixels per second, as sizing.speed_of reckons it (60 px/s times its
    spd stat over 100, over the size its sprite is drawn at) but read from the slime twin's own file. The base slime walks at 60."""
    if form in (None, "slime"):
        return BASE_SPEED
    with open(twin_path(form)) as fh:
        text = fh.read()
    spd = re.search(r'"spd":\s*(\d+)', text)
    sz = re.search(r"^sprite_size = ([0-9.]+)", text, re.M)
    return BASE_SPEED * (float(spd.group(1)) if spd else 100.0) / 100.0 / (float(sz.group(1)) if sz else 1.0)
