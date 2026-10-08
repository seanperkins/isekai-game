// The review page: an index of creatures, and a page per creature made of the blocks the agent chose. Content changes arrive on /events and update the page
// in place; a change to this folder reloads it.
import { getBlock } from "./registry.js";
import { controls, setControl, onControls, onFrame, time } from "./controls.js";
import { h, notice } from "./dom.js";

window.__loaded = Date.now();   // a marker the browser check uses to tell a reload from an in-place update

const view = document.getElementById("view");
const bar = document.getElementById("bar");
let creatures = [];
let open = null;   // the creature page on show: {id, prefix, base, versions, epoch, items, headerEl, blocksEl}

async function fetchJson(url) {
  const res = await fetch(url, { cache: "no-store" });
  const name = url.split("?")[0].replace("/content/", "");
  if (!res.ok) throw new Error(`${res.status} ${name}`);
  try {
    return JSON.parse(await res.text());
  } catch (err) {
    throw new Error(`${name}: ${err.message}`);
  }
}

// ---- the bar -----------------------------------------------------------------------------------------------------------------------
function buildBar() {
  const select = (name, values, label) => {
    const el = h("select", { title: name }, values.map((v) => h("option", { value: v }, label(v))));
    el.value = String(controls[name]);
    el.addEventListener("change", () => setControl(name, Number(el.value)));
    onControls((changed) => { if (changed === name) el.value = String(controls[name]); });
    return el;
  };
  const play = h("button", { type: "button", title: "play or pause" });
  const showPlay = () => { play.textContent = controls.playing ? "pause" : "play"; };
  showPlay();
  play.addEventListener("click", () => setControl("playing", !controls.playing));
  onControls((changed) => { if (changed === "playing") showPlay(); });
  bar.replaceChildren(
    h("a", { href: "#/", class: "brand" }, "Creature review"), h("span", { class: "spacer" }),
    h("label", {}, "zoom ", select("zoom", [1, 2, 3, 4, 6, 8], (v) => v + "x")),
    h("label", {}, "speed ", select("speed", [0.25, 0.5, 1, 2], (v) => v + "x")),
    play, h("span", { id: "live", class: "live", title: "connected to the server" }, "live"));
}

function setLive(on) {
  const live = document.getElementById("live");
  live.className = "live" + (on ? "" : " off");
  live.textContent = on ? "live" : "reconnecting";
}

// ---- the index ---------------------------------------------------------------------------------------------------------------------
function orderTree(list) {
  const ids = new Set(list.map((c) => c.id));
  const kids = new Map();
  for (const c of list) {
    const parent = c.parent && ids.has(c.parent) && c.parent !== c.id ? c.parent : null;
    if (!kids.has(parent)) kids.set(parent, []);
    kids.get(parent).push(c);
  }
  const order = (a, b) => (a.stage ?? 99) - (b.stage ?? 99) || a.id.localeCompare(b.id);
  const out = [];
  const seen = new Set();
  const walk = (parent, depth) => {
    for (const c of (kids.get(parent) || []).sort(order)) {
      if (seen.has(c.id)) continue;
      seen.add(c.id);
      out.push([c, depth]);
      walk(c.id, depth + 1);
    }
  };
  walk(null, 0);
  for (const c of list.filter((c) => !seen.has(c.id)).sort(order)) out.push([c, 0]);   // a parent loop, however it came about, still shows
  return out;
}

function renderIndex() {
  const groups = new Map();
  for (const c of creatures) {
    const key = c.species || "other";
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(c);
  }
  const sections = [...groups.keys()].sort().map((species) => h("section", { class: "species" }, h("h2", {}, species),
    orderTree(groups.get(species)).map(([c, depth]) => h("a", { class: "card" + (c.error ? " broken" : ""), href: "#/creature/" + c.id, style: `margin-left:${depth * 22}px` },
      h("span", { class: "dot flag-" + (c.flag || "none"), title: c.flag ? "latest flag: " + c.flag : "no flag yet" }),
      h("span", { class: "title" }, c.title || c.id),
      h("span", { class: "meta" }, c.stage != null ? "stage " + c.stage : ""),
      c.error ? notice(c.error, "error") : null))));
  view.replaceChildren(h("h1", {}, "Creatures"),
    ...(creatures.length ? sections : [notice("Nothing published yet. Run tools/review/publish.py sheet <form_id> to put a creature here.")]));
}

async function refreshIndex() {
  try {
    creatures = await fetchJson("/api/creatures");
  } catch (err) {
    creatures = [];
    view.replaceChildren(notice(`The server did not answer: ${err.message}`, "error"));
    return;
  }
  if (!open) renderIndex();
}

// ---- a creature --------------------------------------------------------------------------------------------------------------------
function teardown(item) {
  item.token++;   // an answer that arrives for an earlier render is ignored
  for (const off of item.offs) off();
  item.offs = [];
}

function makeCtx(o, item, token) {
  const live = () => item.token === token;
  const register = (add) => (fn) => {
    if (!live()) return () => {};
    const off = add(fn);
    item.offs.push(off);
    return off;
  };
  return {
    creature: o.id,
    url(rel) {
      item.deps.add(rel);
      return `${o.base}${rel}?v=${o.versions.get(rel) || 0}.${o.epoch}`;
    },
    zoom: () => controls.zoom,
    speed: () => controls.speed,
    playing: () => controls.playing,
    time,
    onFrame: register(onFrame),
    onControls: register(onControls),
  };
}

function renderItem(o, item) {
  teardown(item);
  item.deps = new Set();
  item.el.replaceChildren();
  item.el.dataset.type = item.block.type;
  const render = getBlock(item.block.type);
  if (!render) {
    item.el.append(notice(`unknown block: ${item.block.type}`));
    return;
  }
  const token = item.token;
  const fail = (err) => {
    if (item.token === token) item.el.replaceChildren(notice(`block ${item.block.type} failed: ${err && err.message ? err.message : err}`, "error"));
  };
  try {
    Promise.resolve(render(item.el, item.block, makeCtx(o, item, token))).catch(fail);
  } catch (err) {
    fail(err);
  }
}

function reconcile(o, blocks, force) {
  blocks.forEach((block, i) => {
    const sig = JSON.stringify(block);
    let item = o.items[i];
    if (!item) {
      item = { el: h("section", { class: "block" }), sig: null, block: null, deps: new Set(), offs: [], token: 0 };
      o.items[i] = item;
      o.blocksEl.append(item.el);
    }
    if (force || item.sig !== sig) {
      item.block = block;
      item.sig = sig;
      renderItem(o, item);
    }
  });
  while (o.items.length > blocks.length) {
    const item = o.items.pop();
    teardown(item);
    item.el.remove();
  }
}

function clearItems(o) {
  for (const item of o.items) teardown(item);
  o.items = [];
  o.blocksEl.replaceChildren();
}

async function loadPage(o, force = false) {
  let page;
  try {
    page = await fetchJson(`${o.base}page.json?v=${Date.now()}`);
    if (!page || typeof page !== "object" || !Array.isArray(page.blocks || [])) throw new Error(`creatures/${o.id}/page.json: not a page`);
  } catch (err) {
    if (open !== o) return;
    clearItems(o);
    o.headerEl.replaceChildren(h("a", { href: "#/", class: "back" }, "all creatures"), h("h1", {}, o.id));
    o.errorEl = notice(err.message, "error");   // a half-written page is shown by name, not as a blank
    o.blocksEl.append(o.errorEl);
    return;
  }
  if (open !== o) return;   // the reviewer went elsewhere while this was loading
  const parent = page.parent ? h("a", { href: "#/creature/" + page.parent }, page.parent) : null;
  o.headerEl.replaceChildren(h("a", { href: "#/", class: "back" }, "all creatures"), h("h1", {}, page.title || o.id),
    h("p", { class: "meta" }, [page.species, page.stage != null ? "stage " + page.stage : null].filter(Boolean).join(" . "), parent ? " . from " : "", parent,
      page.updated ? " . updated " + new Date(page.updated).toLocaleTimeString() : ""));
  if (o.errorEl) {
    o.errorEl.remove();
    o.errorEl = null;
  }
  reconcile(o, page.blocks || [], force);
}

function closeCreature() {
  if (open) clearItems(open);
  open = null;
}

function showCreature(id) {
  closeCreature();
  const o = { id, prefix: `creatures/${id}/`, base: `/content/creatures/${id}/`, versions: new Map(), epoch: 0, items: [],
    headerEl: h("header", { class: "creature-head" }), blocksEl: h("div", { class: "blocks" }) };
  open = o;
  view.replaceChildren(o.headerEl, o.blocksEl);
  loadPage(o);
}

function route() {
  const m = location.hash.match(/^#\/creature\/([a-z0-9_]+)$/);
  if (m) {
    showCreature(m[1]);
  } else {
    closeCreature();
    renderIndex();
  }
}

// ---- live updates ------------------------------------------------------------------------------------------------------------------
let indexTimer = 0;
function onContent(path) {
  if (path.startsWith("creatures/") || path.startsWith("feedback")) {
    clearTimeout(indexTimer);
    indexTimer = setTimeout(refreshIndex, 100);
  }
  if (!open || !path.startsWith(open.prefix)) return;
  const rel = path.slice(open.prefix.length);
  open.versions.set(rel, (open.versions.get(rel) || 0) + 1);
  if (rel === "page.json") {
    loadPage(open);
  } else {
    for (const item of open.items) if (item.deps.has(rel)) renderItem(open, item);   // a file this block reads has changed
  }
}

function resync() {
  refreshIndex();
  if (open) {
    open.epoch++;   // every file URL changes, so nothing stale survives a server restart
    loadPage(open, true);
  }
}

function connect() {
  let failed = false;
  const source = new EventSource("/events");
  source.onopen = () => {
    setLive(true);
    if (failed) {
      failed = false;
      resync();
    }
  };
  source.onerror = () => {
    failed = true;
    setLive(false);   // the browser reconnects by itself
  };
  source.onmessage = (message) => {
    let event;
    try {
      event = JSON.parse(message.data);
    } catch {
      return;
    }
    if (event.type === "app") location.reload();
    else if (event.type === "content") onContent(event.path);
  };
}

buildBar();
window.addEventListener("hashchange", route);
refreshIndex().then(route);
connect();
