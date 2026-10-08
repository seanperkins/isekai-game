// Which frame of a clip is showing at a moment. Pure: no DOM, so a browser console can exercise it directly.
const MIN = 0.02;   // the game plays on a 20 ms grid; a zero, negative or missing duration counts as one tick so a loop can neither spin nor stall

// durations: seconds per frame. Returns the frame index, or -1 for a clip with no frames. A looping clip wraps; a one-shot holds its last frame.
export function frameAt(durations, loop, t) {
  const n = Array.isArray(durations) ? durations.length : 0;
  if (n === 0) return -1;
  if (n === 1) return 0;
  const d = durations.map((x) => (Number.isFinite(x) && x >= MIN ? x : MIN));
  const total = d.reduce((a, b) => a + b, 0);
  let u = loop ? ((t % total) + total) % total : Math.min(Math.max(t, 0), total - 1e-9);
  for (let i = 0; i < n; i++) {
    if (u < d[i]) return i;
    u -= d[i];
  }
  return n - 1;
}

// A clip's durations made to fit its frames: absent or the wrong length means one tick each.
export function durationsOf(clip) {
  const n = (clip.frames || []).length;
  return Array.isArray(clip.durations) && clip.durations.length === n ? clip.durations : new Array(n).fill(MIN);
}
