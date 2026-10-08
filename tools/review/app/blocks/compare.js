// Two sprite sets side by side on one clock, so a frame in one is the same moment in the other; a swap button, and a blink mode that alternates them in place
// (the quickest way to see what moved). {type: "compare", clip, a: {label, sprites}, b: {label, sprites}}; `sprites` is a listing path (see sprite-set.js).
import { registerBlock } from "../registry.js";
import { frameAt } from "../player.js";
import { h, notice } from "../dom.js";
import { loadSet, prepareClip, drawFrame } from "./sprite-set.js";

registerBlock("compare", async (el, data, ctx) => {
  const sides = [data.a, data.b];
  const sets = await Promise.all(sides.map((s) => loadSet(ctx, s.sprites)));
  const clips = await Promise.all(sets.map((set) => prepareClip(set, data.clip)));
  if (!ctx.live()) return;
  const missing = clips.findIndex((c) => !c);
  if (missing >= 0) {
    el.append(notice(`compare: ${sides[missing].sprites} has no clip "${data.clip}"`));
    return;
  }
  const items = sides.map((s, i) => ({ label: s.label || s.sprites, set: sets[i], p: clips[i] }));
  const box = items.reduce((b, it) => ({ w: Math.max(b.w, it.p.box.w), h: Math.max(b.h, it.p.box.h) }), { w: 1, h: 1 });
  let swapped = false;
  let blink = false;
  const mk = () => h("canvas", { width: String(box.w), height: String(box.h) });
  const canvases = [mk(), mk()];
  const labels = [h("span", { class: "clip-name" }), h("span", { class: "clip-name" })];
  const swap = h("button", { type: "button" }, "swap sides");
  const blinkBtn = h("button", { type: "button" }, "blink: off");
  const row = h("div", { class: "compare-row" });
  const layout = () => {
    row.replaceChildren(...(blink ? [h("figure", { class: "tile" }, labels[0], canvases[0])]
      : [0, 1].map((k) => h("figure", { class: "tile" }, labels[k], canvases[k]))));
  };
  const size = () => {
    for (const c of canvases) {
      c.style.width = `${box.w * items[0].set.scale * ctx.zoom()}px`;
      c.style.height = `${box.h * items[0].set.scale * ctx.zoom()}px`;
    }
  };
  swap.addEventListener("click", () => { swapped = !swapped; paint(ctx.time()); });
  blinkBtn.addEventListener("click", () => { blink = !blink; blinkBtn.textContent = `blink: ${blink ? "on" : "off"}`; layout(); paint(ctx.time()); });
  el.append(h("div", { class: "tools" }, swap, blinkBtn, h("span", { class: "meta" }, `clip: ${data.clip}`)), row);
  layout();
  size();
  ctx.onControls((name) => { if (name === "zoom") size(); });
  const paint = (time) => {
    const order = swapped ? [1, 0] : [0, 1];
    const shown = blink ? [order[Math.floor(performance.now() / 400) % 2]] : order;   // blink runs on real time so it still alternates while paused
    shown.forEach((idx, k) => {
      const it = items[idx];
      const g = canvases[k].getContext("2d");
      const i = frameAt(it.p.durations, it.p.clip.loop, time);
      labels[k].textContent = it.label;
      g.clearRect(0, 0, box.w, box.h);
      if (i >= 0) drawFrame(g, box, it.p.frames[i]);
    });
  };
  paint(ctx.time());   // a first frame at once: a hidden tab runs no animation frames
  ctx.onFrame(paint);
});
