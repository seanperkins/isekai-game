// Two sprite sets side by side on one clock, so a frame in one is the same moment in the other; a swap button, and a blink mode that alternates them in place
// (the quickest way to see what moved). {type: "compare", clip, a: {label, sprites}, b: {label, sprites}}; `sprites` is a listing path (see sprite-set.js).
import { registerBlock } from "../registry.js";
import { frameAt } from "../player.js";
import { h, notice } from "../dom.js";
import { loadSet, prepareClip } from "./sprite-set.js";
import { clipLayout, mergeLayouts } from "../hands.js";
import { defaultItems, drawFrameWithItems } from "./held-draw.js";

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
  const held = await Promise.all(sets.map((set) => defaultItems(set)));   // a goblin holds what its form holds, in both sides
  if (!ctx.live()) return;
  const items = sides.map((s, i) => ({ label: s.label || s.sprites, set: sets[i], p: clips[i], held: held[i], layout: clipLayout(clips[i].frames, held[i]) }));
  const merged = mergeLayouts(items.map((it) => it.layout));   // both sides on one origin, and wide and tall enough for an item that reaches out
  const box = { w: merged.w, h: merged.h };
  let swapped = false;
  let blink = false;
  let start = ctx.time();   // a one-shot clip plays from when the block was drawn; a click plays it again
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
  swap.addEventListener("click", () => { swapped = !swapped; paint(ctx.time()); });
  blinkBtn.addEventListener("click", () => { blink = !blink; blinkBtn.textContent = `blink: ${blink ? "on" : "off"}`; layout(); paint(ctx.time()); });
  el.append(h("div", { class: "tools" }, swap, blinkBtn, h("span", { class: "meta" }, `clip: ${data.clip}`)), row);
  layout();
  ctx.onControls((name) => { if (name === "zoom") paint(ctx.time()); });
  if (!clips[0].clip.loop) for (const c of canvases) c.addEventListener("click", () => { start = ctx.time(); paint(ctx.time()); });
  const paint = (time) => {
    const order = swapped ? [1, 0] : [0, 1];
    const shown = blink ? [order[Math.floor(performance.now() / 400) % 2]] : order;   // blink runs on real time so it still alternates while paused
    shown.forEach((idx, k) => {
      const it = items[idx];
      const g = canvases[k].getContext("2d");
      const i = frameAt(it.p.durations, it.p.clip.loop, it.p.clip.loop ? time : time - start);
      canvases[k].style.width = `${box.w * it.set.scale * ctx.zoom()}px`;   // each side at its own game scale, so a larger creature looks larger
      canvases[k].style.height = `${box.h * it.set.scale * ctx.zoom()}px`;
      labels[k].textContent = it.label;
      g.clearRect(0, 0, box.w, box.h);
      if (i >= 0) drawFrameWithItems(g, merged, it.p.frames[i], it.p.frames[i].image, it.held);
    });
  };
  paint(ctx.time());   // a first frame at once: a hidden tab runs no animation frames
  ctx.onFrame(paint);
});
