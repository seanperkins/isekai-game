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

function step(dt) {
  if (controls.playing) clock += dt * controls.speed;
  for (const fn of [...frameFns]) {
    try {
      fn(clock);
    } catch (err) {
      console.error(err);
    }
  }
}

function tick(now) {
  const dt = Math.min((now - last) / 1000, 0.1);
  last = now;
  step(dt);
  requestAnimationFrame(tick);
}

// With ?debug in the URL the clock can be stepped by hand (window.__reviewClock.advance(seconds)): a tab that is hidden runs no animation frames, so this is how a
// check, or a screenshot at a chosen moment, drives the animation.
if (new URLSearchParams(location.search).has("debug")) window.__reviewClock = { advance: step, time: () => clock };
requestAnimationFrame(tick);

export function onFrame(fn) {
  frameFns.add(fn);
  return () => frameFns.delete(fn);
}

export function time() {
  return clock;
}
