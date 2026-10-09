// Laying a clip out with the things a goblin holds. Frames and hands are in the game's sprite space: origin at the bottom centre of the frame, x right, y down (up is
// negative), a hand turned `a` degrees clockwise on the screen; an item is its own picture w x h with its grip at `grip` in the same kind of space (origin at the picture's
// bottom centre). Pure functions, so they are tested without a browser (test_hands.py).

// The corners of the item's picture, scaled by `scale` and turned by hand.a about the grip, placed at the hand: its bounds in the frame's space.
export function itemBounds(hand, item, scale) {
  const turn = (hand.a * Math.PI) / 180;
  const cos = Math.cos(turn);
  const sin = Math.sin(turn);
  const xs = [];
  const ys = [];
  for (const [cx, cy] of [[-item.w / 2, -item.h], [item.w / 2, -item.h], [item.w / 2, 0], [-item.w / 2, 0]]) {
    const dx = (cx - item.grip[0]) * scale;
    const dy = (cy - item.grip[1]) * scale;
    xs.push(hand.x + dx * cos - dy * sin);
    ys.push(hand.y + dx * sin + dy * cos);
  }
  return { x0: Math.min(...xs), y0: Math.min(...ys), x1: Math.max(...xs), y1: Math.max(...ys) };
}

// The canvas a clip is drawn on, {w, h, ax, ay}: whole pixels that hold every frame (bottom-centre, as drawFrame places them) and every chosen item at its hand in every frame,
// and the pixel (ax, ay) where the frames' origin lands. `frames` are {w, h, hands}; `held` is {n, f} of {w, h, grip, scale} or nothing. With no item the canvas is the
// largest frame's own box, as ever; with items it grows on the side an item sticks out, rounded outward.
export function clipLayout(frames, held) {
  const boxW = frames.reduce((m, f) => Math.max(m, f.w), 1);
  const boxH = frames.reduce((m, f) => Math.max(m, f.h), 1);
  let [x0, y0, x1, y1] = [-boxW / 2, -boxH, boxW / 2, 0];
  let any = false;
  for (const f of frames) {
    for (const side of ["n", "f"]) {
      const item = held && held[side];
      const hand = f.hands && f.hands[side];
      if (!item || !hand) continue;
      any = true;
      const b = itemBounds(hand, item, item.scale);
      [x0, y0, x1, y1] = [Math.min(x0, b.x0), Math.min(y0, b.y0), Math.max(x1, b.x1), Math.max(y1, b.y1)];
    }
  }
  if (!any) return { w: boxW, h: boxH, ax: boxW / 2, ay: boxH };
  const left = Math.floor(x0);
  const top = Math.floor(y0);
  return { w: Math.ceil(x1) - left, h: Math.ceil(y1) - top, ax: -left, ay: -top };
}

// Where a frame's hand is on the canvas of `layout`.
export function handAt(layout, hand) {
  return [layout.ax + hand.x, layout.ay + hand.y];
}

// One canvas for several clip layouts (the two sides of a compare), their origins on the same pixel: the origin is the larger of each side's, and the canvas reaches the
// farthest edge of any side in every direction. With no items anywhere it is the largest frame's box, as before.
export function mergeLayouts(layouts) {
  const ax = Math.max(...layouts.map((l) => l.ax));
  const ay = Math.max(...layouts.map((l) => l.ay));
  const right = Math.max(...layouts.map((l) => l.w - l.ax));
  const below = Math.max(...layouts.map((l) => l.h - l.ay));
  return { w: Math.ceil(ax + right), h: Math.ceil(ay + below), ax, ay };
}
