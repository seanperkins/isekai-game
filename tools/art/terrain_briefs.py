"""Writes the Grotto and Flooded biome briefs into tools/art/terrain_prompts.json.

Every biome uses the same piece list (see the Cave block) but must feel like its own place: its own
material, platform shape, light and mood, not a recolour. Edit the fragments below, run
  python3 tools/art/terrain_briefs.py
then generate with terrain_gen.py. The Cave and the reserved `deep` biome are hand-written in the JSON.
"""
import json

PATH = "tools/art/terrain_prompts.json"
STYLE_REF = ["art_source/sprites_tiles_d.png"]
SEAM = "The far-left and far-right ends must continue seamlessly so the strip tiles horizontally."


def brief(name, palette, f):
    fill = [f"art_source/terrain/{name}/fill_a_raw.png"]

    def pc(bg, refs, prompt):
        return {"bg": bg, "refs": refs, "prompt": prompt}

    pieces = {
        "fill_a": pc("opaque", [], f"A seamless, tileable texture of {f['stone']}. Flat straight-on view, no perspective. Left/right and top/bottom edges must continue seamlessly. Square 1024x1024."),
        "backwall": pc("opaque", fill, f"A seamless tileable texture of a recessed far cave back wall: {f['back']}. Calmer and a little darker than the reference stone so a character in front stands out, but still colourful, never grey or black. Edges continue seamlessly. Square 1024x1024."),
        "cap_top": pc("key", fill, f"A wide horizontal strip, 1536x384: the TOP EDGE of a floor block, side view. The lower 65% is the same material as the reference texture. The top surface is a roughly flat walkable lip: {f['top']}. Above the surface is magenta. {SEAM}"),
        "cap_bottom": pc("key", fill, f"A wide horizontal strip, 1536x384: the UNDERSIDE EDGE of a ceiling block, side view. The upper 65% is the same material as the reference texture. The lower surface is: {f['under']}. Below the surface is magenta. {SEAM}"),
        "edge_left": pc("key", fill, f"A tall vertical strip, 512x1536: the LEFT FACE of a solid wall block, side view. The right 70% is the same material as the reference texture. The left boundary is {f['edge']}. To the left of the silhouette is magenta. The top and bottom ends must continue seamlessly so the strip tiles vertically."),
        "ledge": pc("key", fill, f"A wide narrow floating platform, 1536x384, side view: {f['ledge']}. It has a flat walkable top edge, chunky ends, and small drips and growths under it. The middle 60% must be a uniform repeatable stretch so it can be lengthened. Magenta everywhere else."),
        "far_haze": pc("opaque", [], f"A distant luminous atmosphere layer for parallax, wide 16:9 landscape (1792x1008): {f['haze']}. Misty and dreamy, bright and inviting, low contrast, no foreground objects."),
        "far_rock": pc("key", [], f"A distant parallax layer, wide 16:9 landscape (1792x1008): {f['far']}, hanging from the top edge and rising from the bottom edge, tiny bright glow dots, hazy and low contrast but colourful. The middle of the image is magenta (empty)."),
        "mid_rock": pc("key", [], f"A middle-distance parallax layer, wide 16:9 landscape (1792x1008): {f['mid']}. Bright and vibrant. The centre of the image is magenta (empty)."),
        "foreground": pc("key", [], f"A foreground parallax frame, wide 16:9 landscape (1792x1008): {f['front']}, only along the left edge, right edge and top edge (rich saturated colours, not black), slightly out of focus but pixelated. The whole centre of the image is magenta (empty)."),
    }
    for piece, text in f["decor"].items():
        refs = STYLE_REF if "crystal" in piece else []
        pieces[piece] = pc("key", refs, text + " Centred with margin. Square 1024x1024.")
    return {"palette": palette, "pieces": pieces}


GROTTO = dict(
    stone="packed dark plum-brown and olive earth woven with thick pale roots and glowing mycelium threads, small pebbles and tiny mushrooms, soft lumpy and organic, no cobblestones and no rounded fitted rocks",
    back="a recessed earthen wall with hanging root hairs, mycelium webs and faint golden spore glints, warm plum and olive",
    top="a thick spongy amber-gold moss cushion with rows of tiny glowing orange and magenta mushrooms, root tips and floating spore dots",
    under="a dripping, root-tangled underside with glowing spore pods, mycelium strands and tiny mushroom tips in magenta and gold",
    edge="a soft, lumpy silhouette of packed earth with protruding root ends and mycelium threads, small glowing mushrooms, no rounded rocks",
    ledge="a wide flat bracket (shelf) mushroom growing sideways, cream ringed gills underneath and a glowing amber-orange top with tiny mushrooms on it",
    haze="a vast warm-lit mushroom-forest cavern, giant fungal columns, amber and magenta god rays and drifting spore clouds, like a fairy forest at dusk",
    far="far-away giant mushroom stalks and caps in soft amber, magenta and teal, and hanging root curtains",
    mid="huge glowing mushrooms in orange, magenta, cyan and lime with translucent gills, hanging root curtains with glowing pods from the top edge, spongy mounds and ferns rising from the bottom edge",
    front="big soft mushroom caps, hanging roots with glowing pods and spore-laden ferns in deep magenta, amber and green",
    decor={
        "glow_fungus": "One cluster of large bioluminescent grotto mushrooms growing on the ground, side view, caps in orange, magenta and cyan with translucent glowing gills, moss at the base.",
        "lichen_hang": "One hanging curtain of glowing roots with luminous spore pods in gold and magenta hanging from a small earthy ceiling nub at the top, side view. Tall.",
        "wall_crystal": "One small cluster of prismatic glowing crystals in magenta, gold and teal growing sideways out of a lump of earth and roots, side view, in the same crystal style as the reference.",
        "stalagmite": "One cluster of three tall thin glowing mushroom stalks of different heights rising from a mossy base, side view.",
        "root_hang": "A few thick pale roots with glowing orange buds and tiny mushrooms dangling down from the top edge, side view. Tall.",
        "rubble": "A small low pile of mossy earth clods and rocks with tiny glowing mushrooms growing between them, side view, wider than tall.",
        "flowers": "A patch of small glowing spore flowers with round petals in magenta, orange, cyan and white on short green stems with moss, side view, wider than tall.",
        "puddle_glow": "A shallow flat glowing spring pool of luminous magenta-tinted turquoise water in a small dip of mossy earth, seen from the side at ground level, wider than tall, with a bright rim.",
        "crystal_rose": "One cluster of tall glowing magenta and pink crystals growing from a mossy earth base, faceted and luminous, side view, same crystal style as the reference.",
        "crystal_gold": "One cluster of tall glowing amber and gold crystals with lime highlights growing from a mossy earth base, faceted and luminous, side view, same crystal style as the reference.",
        "crystal_prism": "One large prismatic crystal cluster whose facets show a full rainbow of colours, like opal, growing from a mossy earth base, glowing brightly, side view, same crystal style as the reference.",
    },
)

FLOODED = dict(
    stone="water-polished pale limestone in long flat horizontal strata layers with smooth worn edges and a wet glossy sheen, sea-green and pale blue-grey, natural rock not built, with tiny coral, shells and glinting water droplets; clean straight courses, no rounded cobbles",
    back="a recessed wall of smooth layered limestone with faint caustic light ripples, tiny shells and algae, dim aqua and sea-green",
    top="a glossy wet lip with a thin shimmering film of water, bright green algae, small coral tufts and pearly shells",
    under="a smooth layered underside with hanging kelp strands, falling water drops, pointed limestone stalactites and tiny glowing sea-glass tips in aqua and pink",
    edge="a straight-ish layered silhouette with chipped corners, like cut strata, with a crust of green algae and small coral",
    ledge="a flat smooth slab of layered limestone with chipped corners and a waterline sheen, small coral and shells on top, seaweed hanging beneath",
    haze="a flooded vaulted cavern of natural rock arches half underwater, shafts of aqua light with caustic ripples, far-off waterfalls and glowing pools, cool, serene and calm",
    far="far-away natural rock arches, layered cliffs and waterfalls in soft turquoise and coral",
    mid="lush half-flooded cave formations: kelp forests, coral clusters, glowing jellyfish-like plants, layered rock arches, waterfalls pouring from the top edge, sea-glass crystal clusters in aqua, coral and violet rising from the bottom edge",
    front="drooping kelp curtains, reeds and hanging glowing jelly-plants in deep teal, coral and violet",
    decor={
        "glow_fungus": "One cluster of glowing bioluminescent sea-anemone-like plants growing on the ground, side view, in aqua, pink and lime, small stones and algae at the base.",
        "lichen_hang": "One hanging curtain of glowing kelp strands and luminous water plants with small pink and aqua glowing buds, hanging from a small rocky ceiling nub at the top, side view. Tall.",
        "wall_crystal": "One small cluster of prismatic sea-glass crystals in aqua, coral and violet growing sideways out of a lump of wet layered rock, side view, in the same crystal style as the reference.",
        "stalagmite": "One cluster of three wet layered-limestone spires with coral growing on them and glowing tips, of different heights, rising from a small pebbly base, side view.",
        "root_hang": "A few thick strands of green kelp and reeds with tiny glowing buds dangling down from the top edge, side view. Tall.",
        "rubble": "A small low pile of wet rocks with coral, shells and algae, side view, wider than tall.",
        "flowers": "A patch of small pearly shells and pink and aqua sea flowers on short green stems with algae, side view, wider than tall.",
        "puddle_glow": "A shallow flat glowing pool of luminous turquoise water sitting in a small dip of wet rock with ripples and floating lily leaves, seen from the side at ground level, wider than tall, with a bright rim.",
        "crystal_rose": "One cluster of tall glowing coral-pink sea-glass crystals growing from a wet rock base, faceted and luminous, side view, same crystal style as the reference.",
        "crystal_gold": "One cluster of tall glowing aqua and seafoam crystals growing from a wet rock base, faceted and luminous, side view, same crystal style as the reference.",
        "crystal_prism": "One large prismatic crystal cluster whose facets show a full rainbow of colours, like opal, growing from a wet rock base, glowing brightly, side view, same crystal style as the reference.",
    },
)

if __name__ == "__main__":
    cfg = json.load(open(PATH))
    cfg["biomes"]["grotto"] = brief(
        "grotto", "Palette: warm plum-brown and olive earth, amber-gold moss, glowing mushrooms in orange, magenta, cyan and lime, golden spore light. Mood: warm, cozy and dreamy, like a fairy forest at dusk.", GROTTO)
    cfg["biomes"]["flooded"] = brief(
        "flooded", "Palette: pale sea-green and blue-grey layered stone, turquoise and aquamarine water with sunlit caustics, coral pink, pearly white and violet sea-glass, bright green algae. Mood: cool, serene and luminous, like a sunlit drowned cavern.", FLOODED)
    json.dump(cfg, open(PATH, "w"), indent=2)
    print("wrote", sorted(cfg["biomes"]))
