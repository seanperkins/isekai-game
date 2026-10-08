// The page's shared controls (zoom, speed, play/pause) and its one animation clock. Settings persist in localStorage, which may be unavailable.
const KEY = "review.controls";
const defaults = { zoom: 3, speed: 1, playing: true };

function load() {
  try {
    const saved = JSON.parse(localStorage.getItem(KEY) || "{}");
    return { ...defaults, ...(typeof saved === "object" && saved ? saved : {}) };
  } catch {
    return { ...defaults };
  }
}

export const controls = load();
const listeners = new Set();

export function setControl(name, value) {
  controls[name] = value;
  try {
    localStorage.setItem(KEY, JSON.stringify(controls));
  } catch {
    /* private window or blocked storage: the setting lasts until the page closes */
  }
  for (const fn of [...listeners]) fn(name);
}

export function onControls(fn) {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

// One requestAnimationFrame loop for the whole page. The clock stands still while paused and runs at `speed`, so every block shows the same moment.
let clock = 0;
let last = performance.now();
const frameFns = new Set();

function tick(now) {
  const dt = Math.min((now - last) / 1000, 0.1);
  last = now;
  if (controls.playing) clock += dt * controls.speed;
  for (const fn of [...frameFns]) {
    try {
      fn(clock);
    } catch (err) {
      console.error(err);
    }
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);

export function onFrame(fn) {
  frameFns.add(fn);
  return () => frameFns.delete(fn);
}

export function time() {
  return clock;
}
