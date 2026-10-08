// A creature's clips, animated at game scale: the listing's frames drawn on canvases that CSS scales with nearest-neighbour, at the game's draw scale
// (the twin's sprite_size) times the page's zoom, on the page's shared clock.
import { registerBlock } from "../registry.js";
import { frameAt, durationsOf } from "../player.js";
import { h, notice } from "../dom.js";
import { flagBar } from "./feedback.js";

function loadImage(url, retries = 1) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => {
      if (retries > 0) setTimeout(() => loadImage(url, retries - 1).then(resolve, reject), 400);   // a file may still be arriving
      else reject(new Error(`could not load ${url.split("?")[0].replace("/content/", "")}`));
    };
    img.src = url;
  });
}

async function frameSource(frame, sheet, ctx) {
  if (frame.rect) return { image: sheet, x: frame.rect[0], y: frame.rect[1], w: frame.rect[2], h: frame.rect[3] };
  const img = await loadImage(ctx.url(frame.src));
  return { image: img, x: 0, y: 0, w: img.naturalWidth, h: img.naturalHeight };
}

registerBlock("sprites", async (el, data, ctx) => {
  const res = await fetch(ctx.url(data.sprites), { cache: "no-store" });
  if (!res.ok) throw new Error(`${res.status} ${data.sprites}`);
  const listing = await res.json();
  const clips = listing.clips || {};
  const names = (Array.isArray(data.clips) && data.clips.length ? data.clips : Object.keys(clips)).filter((n) => clips[n]);
  if (!names.length) {
    el.append(notice("no clips"));
    return;
  }
  const sheet = listing.image ? await loadImage(ctx.url(listing.image)) : null;
  const prepared = [];
  for (const name of names) {
    const clip = clips[name];
    const frames = await Promise.all((clip.frames || []).map((f) => frameSource(f, sheet, ctx)));
    prepared.push({ name, clip, durations: durationsOf(clip), frames });
  }
  if (!ctx.live()) return;   // this block was drawn again while its files were loading: the newer render owns the element
  let normals = null;   // loaded the first time the toggle is on
  let showNormals = false;
  const tiles = [];
  for (const { name, clip, durations, frames } of prepared) {
    const box = frames.reduce((b, f) => ({ w: Math.max(b.w, f.w), h: Math.max(b.h, f.h) }), { w: 1, h: 1 });
    const canvas = h("canvas", { width: String(box.w), height: String(box.h), title: name });
    const info = h("span", { class: "meta" }, frames.length ? `${frames.length} frame${frames.length === 1 ? "" : "s"}, ${durations.reduce((a, b) => a + b, 0).toFixed(2)} s${clip.loop ? ", loops" : ""}` : "no frames");
    el.append(h("figure", { class: "tile" }, h("div", { class: "tile-head" }, h("span", { class: "clip-name" }, name), info), canvas, flagBar(ctx.creature, name, { compact: true })));
    tiles.push({ clip, durations, frames, box, canvas, g: canvas.getContext("2d"), last: -2 });
  }
  const size = () => {
    for (const t of tiles) {
      t.canvas.style.width = `${t.box.w * (listing.scale || 1) * ctx.zoom()}px`;
      t.canvas.style.height = `${t.box.h * (listing.scale || 1) * ctx.zoom()}px`;
    }
  };
  size();
  ctx.onControls((name) => { if (name === "zoom") size(); });
  if (listing.normal) {
    const toggle = h("button", { type: "button", class: "toggle" }, "normals: off");
    toggle.addEventListener("click", async () => {
      showNormals = !showNormals;
      if (showNormals && !normals) normals = await loadImage(ctx.url(listing.normal));
      toggle.textContent = `normals: ${showNormals ? "on" : "off"}`;
      for (const t of tiles) t.last = -2;
    });
    el.prepend(h("div", { class: "tools" }, toggle));
  }
  ctx.onFrame((time) => {
    for (const t of tiles) {
      const i = frameAt(t.durations, t.clip.loop, time);
      if (i === t.last) continue;
      t.last = i;
      t.g.clearRect(0, 0, t.box.w, t.box.h);
      if (i < 0) continue;
      const f = t.frames[i];
      const image = showNormals && normals && f.image === sheet ? normals : f.image;
      t.g.imageSmoothingEnabled = false;
      t.g.drawImage(image, f.x, f.y, f.w, f.h, Math.floor((t.box.w - f.w) / 2), t.box.h - f.h, f.w, f.h);   // bottom-centre: the sprite stands on one line
      t.canvas.dataset.frame = String(i);
    }
  });
});
