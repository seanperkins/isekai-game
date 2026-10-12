// A creature's clips, animated at game scale: the listing's frames drawn on canvases that CSS scales with nearest-neighbour, at the game's draw scale
// (the twin's sprite_size) times the page's zoom, on the page's shared clock.
import { registerBlock } from "../registry.js";
import { frameAt, durationsOf } from "../player.js";
import { h, notice } from "../dom.js";
import { loadImage, frameSource, trimToUnion } from "./sprite-set.js";
import { clipLayout, sideOf, shownPicks, offered } from "../hands.js";
import { drawItem } from "./held-draw.js";
import { flagBar } from "./feedback.js";

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
  const set = { sheet, url: (rel) => ctx.url(rel) };
  const held = listing.held || null;   // a goblin form drawn empty-handed: what it holds, and every item that could be put in a hand
  const picked = held ? { primary: held.form.primary, secondary: held.form.secondary } : { primary: "", secondary: "" };   // the stored choices; shownPicks says what the hands show
  const loaded = {};   // item id -> its picture, once it has been loaded
  const ensureItem = async (id) => { if (id && !loaded[id]) loaded[id] = await loadImage(ctx.url(held.items[id].image)); };
  for (const role of ["primary", "secondary"]) await ensureItem(picked[role]);
  const chosen = () => {   // by the arm each role is on: the frames' hands are keyed by arm
    const out = {};
    if (!held) return out;
    const shown = shownPicks(picked, held.items);
    for (const role of ["primary", "secondary"]) {
      const id = shown[role];
      if (id && loaded[id]) out[sideOf(role, held.form.handed)] = { ...held.items[id], scale: held.form.scale, image: loaded[id] };
    }
    return out;
  };
  const prepared = [];
  for (const name of names) {
    const clip = clips[name];
    const frames = trimToUnion(await Promise.all((clip.frames || []).map((f) => frameSource(f, set))));
    prepared.push({ name, clip, durations: durationsOf(clip), frames });
  }
  if (!ctx.live()) return;   // this block was drawn again while its files were loading: the newer render owns the element
  let normals = null;   // loaded the first time the toggle is on
  let showNormals = false;
  const tiles = [];
  for (const { name, clip, durations, frames } of prepared) {
    const layout = clipLayout(frames, chosen());
    const box = { w: layout.w, h: layout.h };
    const canvas = h("canvas", { width: String(layout.w), height: String(layout.h), title: name });
    const info = h("span", { class: "meta" }, frames.length ? `${frames.length} frame${frames.length === 1 ? "" : "s"}, ${durations.reduce((a, b) => a + b, 0).toFixed(2)} s${clip.loop ? ", loops" : ""}` : "no frames");
    el.append(h("figure", { class: "tile" }, h("div", { class: "tile-head" }, h("span", { class: "clip-name" }, name), info), canvas, flagBar(ctx.creature, name, { compact: true })));
    const tile = { clip, durations, frames, box, layout, canvas, g: canvas.getContext("2d"), last: -2, start: ctx.time() };
    if (!clip.loop) {   // a one-shot plays from when it was drawn, not from when the page loaded, and a click plays it again
      canvas.title = `${name}: click to play again`;
      canvas.classList.add("replay");
      canvas.addEventListener("click", () => { tile.start = ctx.time(); tile.last = -2; paint(ctx.time()); });
    }
    tiles.push(tile);
  }
  const size = () => {
    for (const t of tiles) {
      t.canvas.style.width = `${t.box.w * (listing.scale || 1) * ctx.zoom()}px`;
      t.canvas.style.height = `${t.box.h * (listing.scale || 1) * ctx.zoom()}px`;
    }
  };
  size();
  ctx.onControls((name) => { if (name === "zoom") size(); });
  const relayout = () => {   // an item was changed: every clip's canvas is made to hold it wherever it reaches, and drawn again even when the page is paused
    for (const t of tiles) {
      t.layout = clipLayout(t.frames, chosen());
      t.box = { w: t.layout.w, h: t.layout.h };
      t.canvas.width = t.layout.w;
      t.canvas.height = t.layout.h;
      t.last = -2;
    }
    size();
    paint(ctx.time());
  };
  if (held) {
    const selects = {};
    const sync = () => {   // what each picker shows: a two-handed primary item empties the secondary hand and disables its picker; the stored choice comes back with another primary item
      const shown = shownPicks(picked, held.items);
      const blocked = !!picked.primary && held.items[picked.primary].two_handed;
      for (const role of ["primary", "secondary"]) selects[role].value = shown[role];
      selects.secondary.disabled = blocked;
    };
    const picker = (label, role) => {
      const select = h("select", { title: label, "data-hand": role }, h("option", { value: "" }, "nothing"), offered(role, held.items).map((id) => h("option", { value: id }, id)));
      selects[role] = select;
      select.addEventListener("change", async () => {
        picked[role] = select.value;
        await ensureItem(select.value);
        await ensureItem(picked.secondary);
        sync();
        relayout();
      });
      return h("label", { class: "pick" }, `${label} `, select);
    };
    el.prepend(h("div", { class: "tools" }, picker("primary hand", "primary"), picker("secondary hand", "secondary")));
    sync();
  }
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
  const paint = (time) => {
    for (const t of tiles) {
      const i = frameAt(t.durations, t.clip.loop, t.clip.loop ? time : time - t.start);
      if (i === t.last) continue;
      t.last = i;
      t.g.clearRect(0, 0, t.box.w, t.box.h);
      if (i < 0) continue;
      const f = t.frames[i];
      const image = showNormals && normals && f.image === sheet ? normals : f.image;
      const items = showNormals ? {} : chosen();   // the normal map is the body's
      t.g.imageSmoothingEnabled = false;
      drawItem(t.g, t.layout, f.hands && f.hands.f, items.f, true);   // behind the body
      t.g.drawImage(image, f.x, f.y, f.w, f.h, Math.floor(t.layout.ax - f.w / 2), t.layout.ay - f.h, f.w, f.h);   // bottom-centre: the sprite stands on one line
      drawItem(t.g, t.layout, f.hands && f.hands.n, items.n, false);   // in front of it
      t.canvas.dataset.frame = String(i);
    }
  };
  paint(ctx.time());   // a first frame at once: a hidden tab runs no animation frames
  ctx.onFrame(paint);
});
