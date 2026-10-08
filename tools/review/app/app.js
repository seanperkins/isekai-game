// The review page: an index of creatures, and a page per creature made of the blocks the agent chose. Content changes arrive on /events and update the page
// in place; a change to this folder reloads it.
import { getBlock } from "./registry.js";
import { controls, setControl, onControls, onFrame, time } from "./controls.js";
import { h, notice } from "./dom.js";
import "./blocks/sprites.js";
import "./blocks/note.js";
import "./blocks/numbers.js";
import "./blocks/compare.js";
import "./blocks/figure.js";
import "./blocks/lineup.js";
import "./blocks/model.js";
import { flagBar, retryPending } from "./blocks/feedback.js";
import { BOX, thumbnail, invalidate, paintThumb } from "./thumbs.js";
import { layoutTree } from "./chart.js";

window.__loaded = Date.now();   // a marker the browser check uses to tell a reload from an in-place update

const view = document.getElementById("view");
const bar = document.getElementById("bar");
let creatures = [];
const contentVersions = new Map();   // content path -> how many times it has changed since the page loaded
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
const CARD = { w: 208, h: 72, gapX: 56, gapY: 10, head: 24 };   // CSS px
const SVG = "http://www.w3.org/2000/svg";

function chart(list) {
  const { nodes, edges, cols, rows } = layoutTree(list);
  const x = (col) => col * (CARD.w + CARD.gapX);
  const y = (row) => CARD.head + row * (CARD.h + CARD.gapY);
  const byId = new Map(nodes.map((n) => [n.c.id, n]));
  const links = document.createElementNS(SVG, "svg");
  links.setAttribute("class", "links");
  for (const [from, to] of edges) {   // a smooth line from the parent's right edge to the child's left
    const a = byId.get(from), b = byId.get(to);
    const x1 = x(a.col) + CARD.w, y1 = y(a.row) + CARD.h / 2, x2 = x(b.col), y2 = y(b.row) + CARD.h / 2, mid = (x1 + x2) / 2;
    const path = document.createElementNS(SVG, "path");
    path.setAttribute("d", `M${x1} ${y1} C${mid} ${y1} ${mid} ${y2} ${x2} ${y2}`);
    links.append(path);
  }
  const stages = new Map();
  for (const n of nodes) if (!stages.has(n.col)) stages.set(n.col, n.c.stage);
  const width = cols ? x(cols - 1) + CARD.w : 0;
  const height = CARD.head + (rows ? rows * (CARD.h + CARD.gapY) - CARD.gapY : 0);
  links.setAttribute("width", String(width));
  links.setAttribute("height", String(height));
  const inner = h("div", { class: "chart-inner", style: `width:${width}px;height:${height}px` }, links,
    [...stages].sort((a, b) => a[0] - b[0]).map(([col, stage]) => h("span", { class: "stage-head", style: `left:${x(col)}px` }, stage != null ? "stage " + stage : "")),
    nodes.map((n) => tile(n.c, x(n.col), y(n.row))));
  return h("div", { class: "chart" }, inner);
}

function tile(c, left, top) {
  const thumb = h("canvas", { class: "thumb", width: String(BOX.w), height: String(BOX.h) });
  thumbnail(c.id).then((result) => paintThumb(thumb, result));
  return h("a", { class: "creature-tile" + (c.error ? " broken" : ""), href: "#/creature/" + c.id, title: c.parent ? `${c.id}, from ${c.parent}` : c.id, style: `left:${left}px;top:${top}px;width:${CARD.w}px;height:${CARD.h}px` },
    thumb,
    h("span", { class: "tile-text" },
      h("span", { class: "tile-name" }, h("span", { class: "dot flag-" + (c.flag || "none"), title: c.flag ? "latest flag: " + c.flag : "no flag yet" }), h("span", { class: "title" }, c.title || c.id)),
      h("span", { class: "meta" }, c.stage != null ? "stage " + c.stage : ""),
      c.error ? notice(c.error, "error") : null));
}

function renderIndex() {
  const groups = new Map();
  for (const c of creatures) {
    const key = c.species || "other";
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(c);
  }
  const sections = [...groups.keys()].sort().map((species) => h("section", { class: "species" }, h("h2", {}, species), chart(groups.get(species))));
  view.replaceChildren(h("h1", {}, "Creatures"),
    ...(creatures.length ? sections : [notice("Nothing published yet. Run tools/review/publish.py sheet <form_id> to put a creature here.")]));
}

async function refreshIndex() {
  try {
    creatures = await fetchJson("/api/creatures");
  } catch (err) {
    if (open) return;   // keep the page the reviewer is on; the "reconnecting" light says the server is away, and the next refresh catches up
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
    live,
    url(rel) {
      item.deps.add(rel);
      return `${o.base}${rel}?v=${o.versions.get(rel) || 0}.${o.epoch}`;
    },
    contentUrl(path) {   // a file anywhere in the content folder (another creature's sprites, say); this block is drawn again when it changes
      item.cdeps.add(path);
      return `/content/${path}?v=${contentVersions.get(path) || 0}.${o.epoch}`;
    },
    zoom: () => controls.zoom,
    speed: () => controls.speed,
    playing: () => controls.playing,
    time,
    onFrame: register(onFrame),
    onCleanup: register((fn) => fn),   // fn runs when this block is drawn again or the page is left
    onControls: register(onControls),
  };
}

function renderItem(o, item) {
  teardown(item);
  item.deps = new Set();
  item.cdeps = new Set();
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
      item = { el: h("section", { class: "block" }), sig: null, block: null, deps: new Set(), cdeps: new Set(), offs: [], token: 0 };
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
    headerEl: h("header", { class: "creature-head" }), blocksEl: h("div", { class: "blocks" }), errorEl: null };
  open = o;
  view.replaceChildren(o.headerEl, o.blocksEl, h("section", { class: "block feedback" }, h("h2", {}, "Your note on this creature"), flagBar(id)));
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
  const parts = path.split("/");
  if (parts[0] === "creatures" && parts.length > 2 && parts[2] !== "page.json") invalidate(parts[1]);   // its sprites changed: its thumbnail is drawn again
  if (path.startsWith("creatures/") || path.startsWith("feedback")) {
    clearTimeout(indexTimer);
    indexTimer = setTimeout(refreshIndex, 100);
  }
  contentVersions.set(path, (contentVersions.get(path) || 0) + 1);
  if (!open) return;
  for (const item of open.items) if (item.cdeps.has(path)) renderItem(open, item);
  if (!path.startsWith(open.prefix)) return;
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
      retryPending();
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
