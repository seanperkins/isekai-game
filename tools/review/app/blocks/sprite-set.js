// Reading a sprites listing, shared by the blocks that draw sprites. A listing is named either by a path inside the creature's own folder ("sprites.json") or by a
// content path to another creature's ("creatures/goblin/sprites.json"); its media are resolved against the folder the listing is in.
import { durationsOf } from "../player.js";

export function loadImage(url, retries = 1) {
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

export async function loadSet(ctx, ref) {
  const other = ref.startsWith("creatures/");
  const folder = other ? ref.slice(0, ref.lastIndexOf("/") + 1) : "";
  const url = (rel) => (other ? ctx.contentUrl(folder + rel) : ctx.url(rel));
  const res = await fetch(other ? ctx.contentUrl(ref) : ctx.url(ref), { cache: "no-store" });
  if (!res.ok) throw new Error(`${res.status} ${ref}`);
  const listing = await res.json();
  const sheet = listing.image ? await loadImage(url(listing.image)) : null;
  return { ref, listing, sheet, url, scale: listing.scale || 1 };
}

export async function frameSource(frame, set) {
  if (frame.rect) return { image: set.sheet, x: frame.rect[0], y: frame.rect[1], w: frame.rect[2], h: frame.rect[3] };
  const img = await loadImage(set.url(frame.src));
  return { image: img, x: 0, y: 0, w: img.naturalWidth, h: img.naturalHeight, whole: true };
}

function opaqueBounds(img) {
  const c = document.createElement("canvas");
  c.width = img.naturalWidth;
  c.height = img.naturalHeight;
  const g = c.getContext("2d", { willReadFrequently: true });
  g.drawImage(img, 0, 0);
  const px = g.getImageData(0, 0, c.width, c.height).data;
  let x0 = c.width, y0 = c.height, x1 = -1, y1 = -1;
  for (let y = 0; y < c.height; y++) {
    for (let x = 0; x < c.width; x++) {
      if (px[(y * c.width + x) * 4 + 3] > 8) {
        if (x < x0) x0 = x;
        if (x > x1) x1 = x;
        if (y < y0) y0 = y;
        if (y > y1) y1 = y;
      }
    }
  }
  return x1 < 0 ? null : { x0, y0, x1, y1 };
}

// Frames rendered on a whole canvas carry a lot of transparent padding. Crop every frame of a clip to the box that holds all of them, so the frames still line up
// with each other and the box is the sprite's real size. Frames cut from a sheet are already boxes.
export function trimToUnion(frames) {
  const whole = frames.filter((f) => f.whole);
  if (!whole.length) return frames;
  const bounds = whole.map((f) => opaqueBounds(f.image)).filter(Boolean);
  if (!bounds.length) return frames;
  const u = { x0: Math.min(...bounds.map((b) => b.x0)), y0: Math.min(...bounds.map((b) => b.y0)), x1: Math.max(...bounds.map((b) => b.x1)), y1: Math.max(...bounds.map((b) => b.y1)) };
  for (const f of whole) Object.assign(f, { x: u.x0, y: u.y0, w: u.x1 - u.x0 + 1, h: u.y1 - u.y0 + 1 });
  return frames;
}

// A clip ready to draw: its frames as image sources, its durations, and the box that holds the largest frame; null when the set has no such clip.
export async function prepareClip(set, name) {
  const clip = (set.listing.clips || {})[name];
  if (!clip) return null;
  const frames = trimToUnion(await Promise.all((clip.frames || []).map((f) => frameSource(f, set))));
  const box = frames.reduce((b, f) => ({ w: Math.max(b.w, f.w), h: Math.max(b.h, f.h) }), { w: 1, h: 1 });
  return { name, clip, frames, durations: durationsOf(clip), box };
}

// Draw one frame bottom-centre in `box`, so a sprite stands on one line whatever its width.
export function drawFrame(g, box, f, image = f.image) {
  g.imageSmoothingEnabled = false;
  g.drawImage(image, f.x, f.y, f.w, f.h, Math.floor((box.w - f.w) / 2), box.h - f.h, f.w, f.h);
}
