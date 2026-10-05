"""GIFs of the existing art animating, for the review page: every clip of the four playable species (slime, goblin, gloom wolf,
spider), the slime's four forms (idle and run) and, for each creature, its idle and one movement or attack clip. Frames come
from assets/sheets/<id>.png (rects in <id>.json) and the clips from data/slime_clips.json (the slime and its forms) and
data/enemy_clips.json (everything else), drawn at 4x on a dark floor-line background, as tools/art/slime_gifs.py does.
Writes docs/evolutions/art/<id>-<clip>.gif and docs/evolutions/art/art.json. Run from the project root:
  uv run --python 3.12 --with Pillow python tools/art/sprite_gifs.py
"""
import importlib.util
import json
import math
import os
import re

from PIL import Image, ImageDraw

OUT = "docs/evolutions/art"
SCALE = 4
BG = (18, 18, 32, 255)
FLOOR_LINE = (70, 70, 110, 255)
PAD_X = 12 * SCALE  # room each side of the widest frame
HEADROOM = 8 * SCALE
FLOOR_MARGIN = 4 * SCALE  # below the floor line
HOVER = 6 * SCALE  # how far above the floor line a flyer's box sits
MIN_SECONDS = 1.5  # a looping clip repeats until it lasts this long
HOLD_SECONDS = 0.6  # a one-shot clip holds its last frame this long
COLORS = 128

SPECIES = ["slime", "goblin", "gloom_wolf", "spider"]
FORMS = ["form_weaver", "form_snare", "form_arachne", "form_silkbound"]
FLYERS = {"bat", "spore_moth", "pale_moth", "glass_eel", "storm_eel", "drift_jelly"}  # centred above the floor line, not standing on it
# creature -> the idle clip and one movement or attack clip (a creature with only one clip shows it)
CREATURE_CLIPS = {
    "bat": ["hover", "fly"],
    "toad": ["idle", "walk"],
    "lizard": ["idle", "charge"],
    "spore_moth": ["fly"],
    "mushroom_crab": ["idle", "charge"],
    "vine_snake": ["hide", "slither"],
    "pale_moth": ["fly"],
    "glass_eel": ["swim", "dart"],
    "cave_crayfish": ["idle", "charge"],
    "bog_lizardman": ["idle", "walk"],
    "armed_ant": ["idle", "walk"],
    "stone_drake": ["idle", "walk"],
    "storm_eel": ["swim", "dart"],
    "taratect": ["hang", "crawl"],
    "drift_jelly": ["drift"],
}
# the slime's clips that the existing slime_gifs.py sequences by hand (a lead-in, the loop, an exit)
SLIME_SEQUENCES = {
    "cover": (["cover_1"] * 3 + ["cover_2"] * 3 + ["cover_3", "cover_3", "cover_4", "cover_4"] * 3 + ["cover_5"] * 4, 8.0),
    "spread": (["idle_1"] * 4 + ["spread_1", "spread_2"] + ["spread_2"] * 8 + ["spread_2", "spread_1"] + ["idle_1"] * 4, 10.0),
}


def player_species_names():
    spec = importlib.util.spec_from_file_location("build_bestiary", "tools/build_bestiary.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return {k: v[0] for k, v in module.PLAYER_SPECIES.items()}


def creature_name(cid):
    path = "data/creatures/%s.tres" % cid
    if os.path.exists(path):
        found = re.search(r'display_name = "([^"]+)"', open(path).read())
        if found:
            return found.group(1)
    return cid.replace("_", " ").title()


def display_name(cid, players):
    if cid in players:
        return players[cid]
    if cid.startswith("form_"):
        return cid[5:].replace("_", " ").title() + " (player form)"
    return creature_name(cid)


class Sheet:
    def __init__(self, sid, used):
        """`used`: the frame names the shown clips play; the canvas fits the largest of them (so it is the same for every clip)."""
        self.id = sid
        self.image = Image.open("assets/sheets/%s.png" % sid).convert("RGBA")
        self.frames = json.load(open("assets/sheets/%s.json" % sid))["frames"]
        fit = [self.frames[n]["rect"] for n in used if n in self.frames]
        self.max_w = max(r[2] for r in fit)
        self.max_h = max(r[3] for r in fit)
        self.flyer = sid in FLYERS
        self.size = (self.max_w * SCALE + 2 * PAD_X, HEADROOM + self.max_h * SCALE + HOVER * (1 if self.flyer else 0) + FLOOR_MARGIN)
        self.floor = self.size[1] - FLOOR_MARGIN

    def draw(self, name):
        x, y, w, h = self.frames[name]["rect"]
        canvas = Image.new("RGBA", self.size, BG)
        ImageDraw.Draw(canvas).line([(0, self.floor), (self.size[0], self.floor)], fill=FLOOR_LINE)
        sprite = self.image.crop((x, y, x + w, y + h)).resize((w * SCALE, h * SCALE), Image.NEAREST)
        if self.flyer:
            top = self.floor - HOVER - (self.max_h * SCALE + h * SCALE) // 2  # centred in the tallest frame's box, hovering
        else:
            top = self.floor - h * SCALE  # standing on the line, bottom centre, as the game anchors it
        canvas.alpha_composite(sprite, ((self.size[0] - w * SCALE) // 2, top))
        return canvas.convert("RGB")


def sequence_for(clip, fps, loop):
    """The frame names to play, and the fps, for a clip definition: a loop repeats to MIN_SECONDS, a one-shot holds its end."""
    names = list(clip["frames"])
    if len(names) == 1:
        return names, fps
    if loop:
        cycles = min(6, max(1, math.ceil(MIN_SECONDS / (len(names) / fps))))
        return names * cycles, fps
    hold = max(1, round(HOLD_SECONDS * fps))
    return names + [names[-1]] * hold, fps


def durations(count, per_frame_ms):
    """Per-frame delays in whole centiseconds that add up to the real time."""
    out, emitted, total = [], 0, 0.0
    for _ in range(count):
        total += per_frame_ms
        cs = max(2, round(total / 10.0) - emitted)
        emitted += cs
        out.append(cs * 10)
    return out


def save_gif(frames, fps, path):
    uniq = list({f.tobytes(): f for f in frames}.values())
    sheet = Image.new("RGB", (uniq[0].width, uniq[0].height * len(uniq)))
    for i, f in enumerate(uniq):
        sheet.paste(f, (0, i * f.height))
    palette = sheet.quantize(colors=COLORS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    quant = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]
    if len(quant) == 1:
        quant[0].save(path)
    else:
        quant[0].save(path, save_all=True, append_images=quant[1:], duration=durations(len(quant), 1000.0 / fps), loop=0, optimize=True)
    return os.path.getsize(path)


def clip_entries(sid, slime_clips, enemy_clips):
    """[(clip id, frame names, fps)] for a sheet, in the order they are shown."""
    if sid == "slime" or sid.startswith("form_"):
        wanted = list(slime_clips) if sid == "slime" else ["idle", "run"]
        out = []
        for cid in wanted:
            if cid in SLIME_SEQUENCES:
                names, fps = SLIME_SEQUENCES[cid]
                out.append((cid, names, fps))
            else:
                clip = slime_clips[cid]
                names, fps = sequence_for(clip, clip["fps"], clip.get("loop", False))
                out.append((cid, names, fps))
        return out
    clips = enemy_clips[sid]
    wanted = list(clips) if sid in SPECIES else CREATURE_CLIPS[sid]
    out = []
    for cid in wanted:
        clip = clips[cid]
        names, fps = sequence_for(clip, clip["fps"], clip.get("loop", False))
        out.append((cid, names, fps))
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    slime_clips = json.load(open("data/slime_clips.json"))
    enemy_clips = json.load(open("data/enemy_clips.json"))
    players = player_species_names()
    creatures = sorted(CREATURE_CLIPS)
    order = [(s, "species") for s in SPECIES] + [(s, "form") for s in FORMS] + [(s, "creature") for s in creatures]
    sprites = []
    total = 0
    for sid, group in order:
        entries = clip_entries(sid, slime_clips, enemy_clips)
        sheet = Sheet(sid, {n for _, names, _ in entries for n in names})
        clips_out = []
        for cid, names, fps in entries:
            missing = [n for n in names if n not in sheet.frames]
            if missing:
                print("SKIP %s-%s: no frame %s" % (sid, cid, sorted(set(missing))))
                continue
            drawn = {n: sheet.draw(n) for n in set(names)}
            name = "%s-%s.gif" % (sid, cid)
            size = save_gif([drawn[n] for n in names], fps, os.path.join(OUT, name))
            total += size
            print("%-28s %3d frames %6.0f KB  %dx%d" % (name, len(names), size / 1024.0, sheet.size[0], sheet.size[1]))
            clips_out.append({"id": cid, "file": name, "fps": fps if fps == int(fps) else round(fps, 1)})
        sprites.append({"id": sid, "name": display_name(sid, players), "group": group, "clips": clips_out})
    with open(os.path.join(OUT, "art.json"), "w") as f:
        json.dump({"sprites": sprites}, f, indent=2)
        f.write("\n")
    print("total %.2f MB, %d sprites" % (total / 1048576.0, len(sprites)))


if __name__ == "__main__":
    main()
