// Drawing the things a goblin holds on a canvas, shared by the blocks that draw sprites (see ../hands.js for the layout). An item is drawn with its grip on the hand, turned with
// it and scaled by the form's scale; the far hand's is behind the body and a little darker, as the game draws it.
import { loadImage } from "./sprite-set.js";
import { handAt, sideOf } from "../hands.js";

const FAR_BRIGHTNESS = 0.8;

// One item in one hand, on the canvas of `layout`.
export function drawItem(g, layout, hand, item, far) {
  if (!hand || !item) return;
  const [x, y] = handAt(layout, hand);
  g.save();
  g.translate(x, y);
  g.rotate((hand.a * Math.PI) / 180);
  g.scale(item.scale, item.scale);
  if (far) g.filter = `brightness(${FAR_BRIGHTNESS})`;
  g.drawImage(item.image, -item.w / 2 - item.grip[0], -item.h - item.grip[1], item.w, item.h);
  g.restore();
}

// A frame bottom-centre on the canvas of `layout`, with the items in its hands: the far one behind it, the near one in front.
export function drawFrameWithItems(g, layout, frame, image, items = {}) {
  g.imageSmoothingEnabled = false;
  drawItem(g, layout, frame.hands && frame.hands.f, items.f, true);
  g.drawImage(image, frame.x, frame.y, frame.w, frame.h, Math.floor(layout.ax - frame.w / 2), layout.ay - frame.h, frame.w, frame.h);
  drawItem(g, layout, frame.hands && frame.hands.n, items.n, false);
}

// What a listing's form holds by default, ready to draw: {n, f} of {w, h, grip, scale, image}; nothing for a listing without a `held` block (a render folder, a creature the game
// has no items for). `set` is what loadSet returned.
export async function defaultItems(set) {
  const held = set.listing.held;
  const out = {};
  if (!held) return out;
  for (const role of ["primary", "secondary"]) {   // by the arm each role is on, which is what the frames' hands are keyed by
    const id = held.form[role];
    if (id && held.items[id]) out[sideOf(role, held.form.handed)] = { ...held.items[id], scale: held.form.scale, image: await loadImage(set.url(held.items[id].image)) };
  }
  return out;
}
