// Creatures to scale in a row on one baseline, with dashed reference heights (the player goblin, a boss), at the size the game draws them times the page zoom.
// {type: "lineup", items: [creature id | {sprites, scale?, label}], lines: [{label, height}]} (heights in game pixels). Each shows its first idle frame.
import { registerBlock } from "../registry.js";
import { h, notice } from "../dom.js";
import { loadSet, prepareClip } from "./sprite-set.js";
import { clipLayout } from "../hands.js";
import { defaultItems, drawItem } from "./held-draw.js";

registerBlock("lineup", async (el, data, ctx) => {
  const specs = (data.items || []).map((it) => (typeof it === "string" ? { id: it, sprites: `creatures/${it}/sprites.json`, label: it.replace(/^(goblin|wolf|spider|undead)_/, "") } : { label: it.sprites, ...it }));
  const loaded = await Promise.all(specs.map(async (spec) => {
    try {
      const set = await loadSet(ctx, spec.sprites);
      const names = Object.keys(set.listing.clips || {});
      const p = await prepareClip(set, set.listing.clips.idle ? "idle" : names[0]);
      if (!p || !p.frames.length) throw new Error("no frames");
      const items = await defaultItems(set);
      return { spec, frame: p.frames[0], scale: spec.scale || set.scale, items, layout: clipLayout([p.frames[0]], items) };
    } catch (err) {
      return { spec, missing: `no sprites: ${spec.id || spec.sprites}` };
    }
  }));
  if (!ctx.live()) return;
  if (!loaded.length) {
    el.append(notice("lineup: no items"));
    return;
  }
  const canvas = h("canvas", { class: "lineup" });
  el.append(canvas);
  const draw = () => {
    const z = ctx.zoom(), gap = 24, pad = 16, label = 40;
    const widths = loaded.map((it) => (it.missing ? 70 : Math.round(it.layout.w * it.scale * z)));   // a cell holds the items that reach out of the body, which keeps its own size in the label
    const tallest = Math.max(...loaded.map((it) => (it.missing ? 0 : Math.round(it.layout.ay * it.scale * z))), ...(data.lines || []).map((l) => l.height * z), 20);
    canvas.width = widths.reduce((a, b) => a + b, 0) + gap * (loaded.length - 1) + pad * 2;
    canvas.height = tallest + label + pad;
    canvas.style.width = `${canvas.width}px`;
    canvas.style.height = `${canvas.height}px`;
    const g = canvas.getContext("2d");
    g.imageSmoothingEnabled = false;
    const base = pad + tallest;
    g.font = "12px -apple-system, sans-serif";
    g.setLineDash([5, 5]);
    for (const line of data.lines || []) {
      const y = base - line.height * z;
      g.strokeStyle = "#6b6f86";
      g.beginPath(); g.moveTo(0, y + 0.5); g.lineTo(canvas.width, y + 0.5); g.stroke();
      g.fillStyle = "#8b8da0";
      g.fillText(`${line.label} ${line.height}`, 6, y - 4);
    }
    g.setLineDash([]);
    let x = pad + 0;
    loaded.forEach((it, i) => {
      g.fillStyle = "#e6e6ee";
      if (it.missing) {
        g.fillStyle = "#f0b252";
        g.fillText(it.missing, x, base - 6);
      } else {
        const s = it.scale * z, bodyW = Math.round(it.frame.w * s), hgt = Math.round(it.frame.h * s);
        const items = (side, far) => {   // the items are drawn in the sprite's own pixels, at the scale the body is
          g.save();
          g.translate(x, base - it.layout.ay * s);
          g.scale(s, s);
          drawItem(g, it.layout, it.frame.hands && it.frame.hands[side], it.items[side], far);
          g.restore();
        };
        items("f", true);   // behind the body
        g.drawImage(it.frame.image, it.frame.x, it.frame.y, it.frame.w, it.frame.h, x + Math.round((it.layout.ax - it.frame.w / 2) * s), base - hgt, bodyW, hgt);
        items("n", false);
        g.fillText(it.spec.label, x, base + 14);
        g.fillStyle = "#8b8da0";
        g.fillText(`${Math.round(it.frame.w * it.scale)}x${Math.round(it.frame.h * it.scale)}`, x, base + 29);
      }
      x += widths[i] + gap;
    });
  };
  draw();
  ctx.onControls((name) => { if (name === "zoom") draw(); });
});
