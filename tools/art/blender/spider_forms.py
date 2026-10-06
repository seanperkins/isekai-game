"""The spider family as data: the base spider and the forms of `data/forms/spider_*.tres`, described the way tools/art/forms_spider_frames.json
describes them. Pure Python (species_tree.py reads it outside Blender).

  span, ride, thorax, abdomen, abd_len, abd_lift, tars    the skeleton's proportions (spider_skeleton.py): leg length, how high it rides, the
                          cephalothorax's and the abdomen's size, the abdomen's length and how far it is carried up behind, the tarsus's length
  drider                  dict(tall, lean, hair, cloth): a person's upper body rising from the front (spider_skeleton.py)
  swarm                   True: the rear crumbles into spiderlings that scuttle (bones swarm1 to swarm4)
  leg_w, hairy            how thick the legs are; hair on the body and legs (a tarantula)
  chitin, leg, mark, eye, joint   colours: the body, the legs, the markings, the eyes, the ring at each knee
  skin, hair, robe, trim  a drider's colours
  gear                    [(name, {options})...] in spider_gear.GEAR
  attack                  bite, pounce, slash, spit (spider_motion.ATTACKS) or a drider's cast, bow, fan, throw, smash (spider_motion.GESTURES)
  idle                    still (default), ready (forelegs up to pounce), dance (the tarantella)
  raised                  pairs of legs held up all the time and never walked on (the walk then goes on six)
  arms                    how a drider holds its arms at rest (spider_motion.ARMS); item_n, item_f the world direction of what each hand holds
  pitch, lean, head_lean  the body's pitch (nose up), the drider's lean and the head's, degrees
  width                   the form's drawn width in game pixels (tools/art/forms_spider_frames.json)
"""
from spider_gear import AIR, BLOOD, CLAY, DARK, EMBER, GOLD, PEACH, RED, SILK, TAN, WATER

BLACK, PITCH, INK = (44, 40, 54), (30, 28, 40), (36, 32, 52)


def G(name, **kw):
    return (name, kw)


FORMS = {
    "spider": dict(stage=1, parent=None, width=36, gear=[G("hourglass"), G("eyes")]),

    # ---- the weavermaid line: driders. jorogumo (seven spider spirits, tsuchigumo), loom-weaver (norn, anansi) ----
    "weavermaid": dict(stage=2, parent="spider", width=34, span=0.9, abdomen=0.95, drider=dict(tall=1.35), skin=(200, 188, 212), hair=DARK, robe=(66, 52, 86),
                       arms="silk", attack="bow", item_f=100.0,
                       gear=[G("hourglass"), G("eyes", small=True), G("bow"), G("silk_strand"), G("bodice", color=(66, 52, 86), sleeves=False)]),
    "jorogumo": dict(stage=3, parent="weavermaid", width=38, span=0.95, abdomen=1.1, drider=dict(tall=1.45, cloth=1.3, hair=1.4), skin=(222, 210, 214), hair=(30, 26, 38),
                     robe=(62, 48, 92), trim=(196, 44, 56), arms="fan", attack="fan", item_n=150.0,
                     gear=[G("hourglass"), G("kimono"), G("fan"), G("spider_eyes"), G("sleeve_silk"), G("leg_tips")]),
    "seven_spider_spirits": dict(stage=4, parent="jorogumo", width=42, span=1.0, abdomen=1.15, drider=dict(tall=1.5, cloth=1.4, hair=1.6), skin=(214, 220, 228),
                                 hair=(52, 50, 70), robe=(168, 172, 186), trim=DARK, arms="silk", attack="cast",
                                 gear=[G("hourglass"), G("kimono", shroud=True), G("seven_eyes"), G("silk_ropes")]),
    "tsuchigumo": dict(stage=4, parent="jorogumo", width=42, span=1.0, thorax=1.25, abdomen=1.3, leg_w=1.5, drider=dict(tall=1.45, lean=10.0, hair=1.1), skin=(132, 132, 140),
                       hair=(28, 26, 32), arms="fists", attack="smash", lean=12.0, head_lean=14.0,
                       gear=[G("hourglass", dim=True), G("clay_crust"), G("leg_spikes", color=CLAY), G("oni"), G("loincloth", color=(70, 56, 46))]),
    "loom_weaver": dict(stage=3, parent="weavermaid", width=38, span=0.95, abdomen=1.05, drider=dict(tall=1.4), skin=(206, 190, 176), hair=(58, 44, 40),
                        robe=(122, 104, 86), arms="shuttle", attack="throw", item_n=95.0,
                        gear=[G("hourglass", woven=True), G("bodice", color=(122, 104, 86), sleeves=False), G("hairband"), G("shuttle"), G("tapestry")]),
    "norn": dict(stage=4, parent="loom_weaver", width=42, span=1.0, abdomen=1.15, drider=dict(tall=1.55, cloth=1.4, hair=1.2), skin=(226, 214, 204), hair=(74, 62, 92),
                 robe=(70, 56, 104), trim=(232, 230, 238), arms="thread", attack="cast", head_lean=0.0, lean=2.0,
                 gear=[G("hourglass", runes=True), G("kimono", hood=True), G("halo"), G("gold_thread"), G("shears")]),
    "anansi": dict(stage=4, parent="loom_weaver", width=41, span=1.25, tars=1.2, abdomen=1.0, leg_w=0.85, drider=dict(tall=1.5, lean=8.0, hair=0.6), skin=(98, 64, 44),
                   hair=(26, 22, 24), arms="story", attack="cast", lean=10.0,
                   gear=[G("hourglass"), G("eyes", small=True), G("hat"), G("kente"), G("story_pot"), G("story_thread")]),

    # ---- the broodmother line: heavy biters. brood queen (cocoon mother, swarm sovereign), cave matriarch (light-eater, chasm-weaver) ----
    "broodmother": dict(stage=2, parent="spider", width=37, span=0.92, ride=0.85, thorax=1.12, abdomen=1.3, leg_w=1.2,
                        gear=[G("hourglass"), G("eyes"), G("brood", count=26), G("egg_sac")]),
    "brood_queen": dict(stage=3, parent="broodmother", width=41, span=1.0, ride=0.95, thorax=1.2, abdomen=1.38, leg_w=1.25, idle="ready",
                        gear=[G("hourglass"), G("eyes"), G("plates"), G("crown", gem=PEACH), G("brood", count=7)]),
    "cocoon_mother": dict(stage=4, parent="brood_queen", width=46, span=0.95, ride=0.9, thorax=1.2, abdomen=1.62, abd_len=1.1, leg_w=1.3, raised=[0], raised_pose="hold",
                          gear=[G("hourglass"), G("eyes"), G("wrapping"), G("cocoons"), G("held_cocoon")]),
    "swarm_sovereign": dict(stage=4, parent="brood_queen", width=45, span=1.0, thorax=1.2, abdomen=1.15, abd_len=0.85, leg_w=1.2, swarm=True,
                            gear=[G("hourglass"), G("eyes"), G("crown"), G("swarmlings")]),
    "cave_matriarch": dict(stage=3, parent="broodmother", width=41, span=0.95, ride=0.85, thorax=1.35, abdomen=1.45, leg_w=1.6, mark=(150, 50, 44),
                           gear=[G("hourglass", cracks=True), G("eyes", big=True, color=(236, 226, 196)), G("leg_spikes", color=TAN), G("knobs"), G("fangs", size=1.5), G("dust")]),
    "light_eater": dict(stage=4, parent="cave_matriarch", width=46, span=1.0, thorax=1.3, abdomen=1.62, leg_w=1.4, chitin=PITCH, leg=PITCH, mark=(74, 40, 92), gloss=False,
                        joint=(70, 50, 96),
                        gear=[G("hourglass", cracks=True), G("maw"), G("eyes", color=(120, 100, 160)), G("sparks"), G("fangs", size=1.6)]),
    "chasm_weaver": dict(stage=4, parent="cave_matriarch", width=46, span=1.42, ride=1.4, tars=1.2, thorax=0.92, abdomen=0.9, abd_len=1.3, abd_lift=32.0, leg_w=0.8,
                         gear=[G("hourglass"), G("eyes"), G("dust"), G("cable")]),

    # ---- the stalker line: hunters. shadow-stalker (nightstalker, veil-spinner), venomspinner (plaguemother, tarantella) ----
    "stalker": dict(stage=2, parent="spider", width=37, span=1.12, ride=0.6, thorax=0.95, abdomen=0.9, abd_len=1.2, abd_h=0.78, abd_lift=6.0, leg_w=0.9, idle="ready", attack="pounce",
                    gear=[G("hourglass", slim=True), G("eyes", color=AIR), G("coil")]),
    "shadow_stalker": dict(stage=3, parent="stalker", width=41, span=1.2, ride=0.62, thorax=0.95, abdomen=0.92, abd_len=1.25, abd_h=0.78, abd_lift=4.0, leg_w=0.85, idle="ready",
                           attack="pounce", chitin=INK, leg=INK, mark=(120, 40, 70),
                           gear=[G("hourglass", slim=True, dim=True), G("eyes", color=AIR), G("smoke")]),
    "nightstalker": dict(stage=4, parent="shadow_stalker", width=46, span=1.15, ride=0.62, thorax=1.0, abdomen=0.8, abd_len=1.4, abd_h=0.6, abd_lift=-2.0, leg_w=0.9, raised=[0], raised_pose="scythe",
                         attack="slash", chitin=PITCH, leg=PITCH, joint=EMBER, mark=EMBER,
                         gear=[G("scythes"), G("six_eyes"), G("midline")]),
    "veil_spinner": dict(stage=4, parent="shadow_stalker", width=46, span=1.15, ride=0.85, thorax=0.9, abdomen=0.85, leg_w=0.75, raised=[0], raised_pose="veil", attack="pounce",
                         gear=[G("hourglass"), G("eyes"), G("veil"), G("dust")]),
    "venomspinner": dict(stage=3, parent="stalker", width=41, span=1.05, ride=0.9, abdomen=1.0, leg_w=1.0, attack="spit", joint=WATER,
                         gear=[G("hourglass"), G("eyes"), G("fangs", size=1.4, drip=True), G("venom_sheen"), G("coil", beads=True)]),
    "plaguemother": dict(stage=4, parent="venomspinner", width=46, span=0.98, ride=0.9, thorax=1.05, abdomen=1.6, abd_len=1.05, leg_w=0.75, attack="spit",
                         leg=(64, 60, 72),
                         gear=[G("hourglass"), G("eyes"), G("blisters"), G("vapour"), G("fangs", size=1.2, drip=True)]),
    "tarantella": dict(stage=4, parent="venomspinner", width=46, span=1.08, ride=0.95, thorax=1.1, abdomen=1.15, leg_w=1.35, hairy=True, idle="dance",
                       gear=[G("hourglass"), G("eyes"), G("hair"), G("ribbons"), G("fangs", size=1.2, drip=True)]),
}

ORDER = list(FORMS)
