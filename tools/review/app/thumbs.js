// Thumbnails for the index: the first frame of a creature's idle clip (or its first clip), cropped to the pixels that are drawn and set bottom-centre in a fixed box, as large as
// fits in whole pixels so it stays crisp. Read from the creature's sprites listing; the result is kept until one of the creature's files changes.
import { loadSet, prepareClip } from "./blocks/sprite-set.js";

export const BOX = { w: 72, h: 64 };   // CSS px

// How much to magnify a w x h sprite to fill the box: the largest whole number up to `max` that fits, or less than 1 for a sprite bigger than the box.
export function fitScale(w, h, box = BOX, max = 4) {
  const fit = Math.min(box.w / w, box.h / h);
  return fit < 1 ? fit : Math.min(max, Math.floor(fit));
}

const cache = new Map();   // creature id -> a promise of {canvas, w, h}, or of null when it has nothing to show

export function invalidate(id) {
  cache.delete(id);
}

export function thumbnail(id) {
  if (!cache.has(id)) cache.set(id, build(id));
  return cache.get(id);
}

// The frame cut down to the pixels that are drawn: the game's sheet cells carry transparent padding, which would make a small creature a small speck in its tile.
function tightCrop(f) {
  const cell = document.createElement("canvas");
  cell.width = f.w;
  cell.height = f.h;
  const g = cell.getContext("2d", { willReadFrequently: true });
  g.drawImage(f.image, f.x, f.y, f.w, f.h, 0, 0, f.w, f.h);
  const px = g.getImageData(0, 0, f.w, f.h).data;
  let x0 = f.w, y0 = f.h, x1 = -1, y1 = -1;
  for (let y = 0; y < f.h; y++) {
    for (let x = 0; x < f.w; x++) {
      if (px[(y * f.w + x) * 4 + 3] > 8) {
        if (x < x0) x0 = x;
        if (x > x1) x1 = x;
        if (y < y0) y0 = y;
        if (y > y1) y1 = y;
      }
    }
  }
  if (x1 < 0) return { canvas: cell, w: f.w, h: f.h };   // nothing drawn: show the cell as it is
  const w = x1 - x0 + 1;
  const h = y1 - y0 + 1;
  const out = document.createElement("canvas");
  out.width = w;
  out.height = h;
  out.getContext("2d").drawImage(cell, x0, y0, w, h, 0, 0, w, h);
  return { canvas: out, w, h };
}

async function build(id) {
  const stamp = Date.now();
  const ctx = { contentUrl: (path) => `/content/${path}?v=${stamp}` };
  try {
    const set = await loadSet(ctx, `creatures/${id}/sprites.json`);
    const clips = set.listing.clips || {};
    const clip = await prepareClip(set, clips.idle ? "idle" : Object.keys(clips)[0]);
    if (!clip || !clip.frames.length) return null;
    return tightCrop(clip.frames[0]);
  } catch {
    cache.delete(id);   // a creature that is half published gets another try on the next draw
    return null;
  }
}

// Draw a thumbnail result onto a canvas that is BOX-sized.
export function paintThumb(target, result) {
  const g = target.getContext("2d");
  g.clearRect(0, 0, target.width, target.height);
  if (!result) return;
  const k = fitScale(result.w, result.h, { w: target.width, h: target.height });
  const w = Math.round(result.w * k);
  const h = Math.round(result.h * k);
  g.imageSmoothingEnabled = false;
  g.drawImage(result.canvas, 0, 0, result.w, result.h, Math.floor((target.width - w) / 2), target.height - h - 2, w, h);
}
