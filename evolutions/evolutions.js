(function () {
  'use strict';
  const D = window.EVOLUTIONS;

  // ---------- helpers ----------
  const $ = (sel, root = document) => root.querySelector(sel);
  function h(tag, attrs, ...kids) {
    const node = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs || {})) {
      if (v == null || v === false) continue;
      if (k === 'class') node.className = v;
      else if (k.startsWith('on')) node.addEventListener(k.slice(2), v);
      else if (v === true) node.setAttribute(k, '');
      else node.setAttribute(k, v);
    }
    for (const kid of kids.flat(Infinity)) {
      if (kid == null || kid === false) continue;
      node.append(kid.nodeType ? kid : document.createTextNode(String(kid)));
    }
    return node;
  }

  const nodes = {};
  D.forms.forEach((f) => { nodes[f.id] = f; });
  D.bases.forEach((b) => { nodes[b.id] = b; });
  const species = {};
  D.species.forEach((s) => { species[s.id] = s; });
  const later = new Set(D.essences.filter((e) => e.later).map((e) => e.id));
  const areaName = {};
  D.areas.forEach((a) => { areaName[a.id] = a.name; });

  const TABS = D.species.map((s) => ({ id: s.id, name: s.name }))
    .concat([{ id: 'movesets', name: 'Movesets' }, { id: 'essences', name: 'Essences' }, { id: 'roster', name: 'World roster' }, { id: 'art', name: 'Art' }]);

  // ---------- small parts ----------
  function chip(e, amount) {
    const isLater = later.has(e);
    return h('span', { class: 'chip el-' + e + (isLater ? ' later' : ''), title: isLater ? e + ': no creature carries it yet' : e },
      h('span', {}, amount != null ? e + ' ' + amount : e));
  }
  function essenceChips(map) {
    return Object.keys(map).map((e) => chip(e, map[e]));
  }
  function tag(kind, text) { return h('span', { class: 'tag ' + kind }, text); }
  function tagsOf(n) {
    const t = [];
    if (n.ask) t.push(tag('ask', '★ ask'));
    if (n.built) t.push(tag('built', 'built'));
    if (n.decided) t.push(tag('decided', 'decided'));
    if (n.secret) t.push(tag('secret', 'secret'));
    return t;
  }
  function areaTags(list) { return list.map((a) => tag('area', areaName[a] || a)); }

  const images = new Map();
  function loadImage(src) {
    if (!images.has(src)) {
      images.set(src, new Promise((resolve, reject) => {
        const img = new Image();
        img.onload = () => resolve(img);
        img.onerror = reject;
        img.src = src;
      }));
    }
    return images.get(src);
  }
  function spriteCanvas(sprite, height) {
    const [x, y, w, hh] = sprite.rect;
    const scale = Math.max(1, Math.min(4, Math.floor(height / hh)));
    const c = h('canvas', { width: w * scale, height: hh * scale, 'aria-hidden': 'true' });
    c.style.height = height + 'px';
    c.style.width = 'auto';
    loadImage(sprite.image).then((img) => {
      const ctx = c.getContext('2d');
      ctx.imageSmoothingEnabled = false;
      ctx.drawImage(img, x, y, w, hh, 0, 0, w * scale, hh * scale);
      if (sprite.tint) {
        const rgb = sprite.tint.map((v) => Math.round(Math.min(1, v) * 255)).join(',');
        ctx.globalCompositeOperation = 'multiply';
        ctx.fillStyle = 'rgb(' + rgb + ')';
        ctx.fillRect(0, 0, c.width, c.height);
        ctx.globalCompositeOperation = 'destination-in';
        ctx.drawImage(img, x, y, w, hh, 0, 0, w * scale, hh * scale);
        ctx.globalCompositeOperation = 'source-over';
      }
    }).catch(() => {});
    return c;
  }

  // ---------- species tabs ----------
  function nodeButton(n) {
    const reads = n.mixed ? [h('span', { class: 'chip' }, h('span', {}, 'mixed diet'))] : (n.reads || []).map((e) => chip(e));
    const tags = tagsOf(n);
    return h('button', {
      type: 'button', class: 'node' + (n.ask ? ' ask' : '') + (n.secret ? ' secret' : ''), 'data-id': n.id, 'aria-pressed': 'false',
      onclick: () => select(n.id),
    },
    h('div', { class: 'node-top' }, n.sprite ? spriteCanvas(n.sprite, 36) : null,
      h('div', {}, h('div', { class: 'node-name' }, n.name), h('div', { class: 'node-sub' }, 'Form ' + n.stage + ' · ' + n.id))),
    reads.length ? h('div', { class: 'chips' }, reads) : null,
    tags.length ? h('div', { class: 'chips' }, tags) : null);
  }
  function treeItem(n) {
    const li = h('li', {}, nodeButton(n));
    if (n.children && n.children.length) {
      const ul = h('ul');
      n.children.forEach((id) => ul.append(treeItem(nodes[id])));
      li.append(ul);
    }
    return li;
  }
  function renderLine(line) {
    const root = nodes[line.id];
    const ul = h('ul', { class: 'tree' });
    ul.append(treeItem(root));
    return h('section', { class: 'line', 'aria-label': root.name + ' line' },
      h('h3', {}, root.name + ' line ', h('span', {}, areaTags(root.host))), ul);
  }
  function renderSpecies(sid) {
    const sp = species[sid];
    const base = nodes[sp.base];
    const total = sp.counts['2'] + sp.counts['3'] + sp.counts['4'];
    const built = D.forms.filter((f) => f.species === sid && f.built).length;
    return h('div', {},
      h('div', { class: 'species-head' }, h('h2', {}, sp.name),
        h('button', { type: 'button', class: 'base', 'data-id': base.id, 'aria-pressed': 'false', onclick: () => select(base.id) },
          base.sprite ? spriteCanvas(base.sprite, 36) : null, h('span', {}, 'Form 1: ' + base.name)),
        h('p', {}, sp.archetype + ' · ' + sp.essenceMethod)),
      h('p', { class: 'note' }, sp.lines.length + ' lines · ' + sp.counts['2'] + ' form 2, ' + sp.counts['3'] + ' form 3, ' + sp.counts['4'] +
        ' form 4 (' + total + ' forms)' + (built ? ' · ' + built + ' already built' : '') + '. Click a form for its details and its world twin.'),
      sp.lines.map(renderLine));
  }

  // ---------- details ----------
  function dlRow(term, value) {
    if (value == null || (Array.isArray(value) && !value.length) || value === '') return null;
    return [h('dt', {}, term), h('dd', {}, value)];
  }
  function linkButtons(ids) {
    return h('div', { class: 'links' }, ids.map((id) => h('button', { type: 'button', onclick: () => select(id) }, nodes[id].name + ' (' + id + ')')));
  }
  function showDetail(id) {
    const n = nodes[id];
    const d = $('#detail');
    if (!n) { d.hidden = true; return; }
    d.hidden = false;
    const tw = n.twin;
    const art = n.sprite
      ? h('div', { class: 'art' }, spriteCanvas(n.sprite, 96), h('span', { class: 'node-sub' },
        n.sprite.ofTwin ? 'art of its existing twin' : n.sprite.tint ? 'the slime sprite, tinted: no art of its own yet' : 'built art'))
      : h('div', { class: 'noart' }, 'No art yet.');
    const reads = n.mixed ? 'a mixed diet' : (n.reads || []).length ? (n.reads || []).map((e) => chip(e)) : null;
    const sp = species[n.species];
    d.replaceChildren(...[
      h('button', { type: 'button', class: 'close', onclick: () => go(currentTab()) }, 'Close'),
      h('h2', {}, n.name),
      h('div', { class: 'chips' }, tag('area', sp.name + ' · Form ' + n.stage + ' · ' + n.id), tagsOf(n)),
      art,
      h('dl', {},
        n.source ? dlRow('Source (folklore)', n.source) : null,
        dlRow('Reads', reads),
        n.verb ? dlRow('What it does', n.verb) : null,
        n.givesUp ? dlRow('Gives up', n.givesUp) : null,
        n.openedBy ? dlRow('Opened by', n.openedBy) : null,
        n.host ? dlRow('Where it is found', areaTags(n.host)) : null,
        n.profile ? dlRow('Movement', n.profile) : null),
      h('div', { class: 'twin' }, h('h3', {}, 'In the world'),
        h('dl', {},
          dlRow('As a creature', tw.name + (tw.status === 'existing' ? ' (an existing creature: ' + tw.creature + ')' : ' (a new creature)')),
          dlRow('Appears as', tw.role),
          dlRow('Spawns in', areaTags(tw.areas)),
          dlRow('Carries', essenceChips(tw.essence)),
          dlRow('Pays', tw.xp + ' XP'),
          n.verb ? dlRow('Its kit', 'The same as above: the enemy does this to you.') : null,
          tw.note ? dlRow('Note', tw.note) : null)),
      n.parent ? [h('h3', {}, 'Comes from'), linkButtons([n.parent])] : null,
      n.children && n.children.length ? [h('h3', {}, 'Goes to'), linkButtons(n.children)] : null,
    ].flat(Infinity).filter(Boolean));
  }

  // ---------- movesets ----------
  function renderMovesets() {
    const M = D.movesets;
    if (!M) return h('p', { class: 'empty' }, 'The moveset GIFs have not been captured yet (tools/moveset_gifs.gd).');
    return h('div', {},
      h('p', { class: 'note' }, 'Each GIF is a scripted run of the real movement code in the movement sandbox (scripts/movement), not a mock-up. The biped body is the goblin’s and every undead form’s; the wolf, spider and slime keep their own. A form keeps its species’ moveset; what differs between forms is the verb in the tree, not the way it walks. The GIFs loop and cannot be paused.'),
      M.species.map((s) => h('section', {},
        h('h2', {}, s.name + ' moveset'),
        h('div', { class: 'cards' }, s.clips.map((c) => h('figure', { class: 'card', style: 'margin:0' },
          h('h3', {}, c.title),
          h('img', { src: 'movesets/' + c.file, alt: s.name + ': ' + c.title + '. ' + c.caption, loading: 'lazy' }),
          h('p', {}, c.caption)))))));
  }

  // ---------- art ----------
  function renderArt() {
    const tally = {};
    D.species.forEach((s) => { tally[s.id] = { own: 0, tinted: 0, twin: 0, none: 0 }; });
    D.forms.forEach((f) => {
      const t = tally[f.species];
      if (!f.sprite) t.none++;
      else if (f.sprite.ofTwin) t.twin++;
      else if (f.sprite.tint) t.tinted++;
      else t.own++;
    });
    const rows = D.species.map((s) => h('tr', {}, h('td', {}, s.name), h('td', {}, tally[s.id].own), h('td', {}, tally[s.id].tinted), h('td', {}, tally[s.id].twin), h('td', {}, tally[s.id].none)));
    const totals = Object.values(tally).reduce((a, t) => ({ own: a.own + t.own, tinted: a.tinted + t.tinted, twin: a.twin + t.twin, none: a.none + t.none }), { own: 0, tinted: 0, twin: 0, none: 0 });
    const out = [
      h('p', { class: 'note' }, 'The art that exists today, animating, and how much of the tree it covers. Most of the 141 forms have no art yet: a built slime form reuses the slime sprite with its tint, and the rest wait for the Codex art pipeline (tools/art).'),
      h('div', { class: 'table-scroll' }, h('table', {},
        h('thead', {}, h('tr', {}, ['Species', 'Own art', 'Slime sprite, tinted', 'Art of an existing twin', 'No art yet'].map((x) => h('th', {}, x)))),
        h('tbody', {}, rows, h('tr', {}, h('td', {}, h('strong', {}, 'All forms')), h('td', {}, totals.own), h('td', {}, totals.tinted), h('td', {}, totals.twin), h('td', {}, totals.none))))),
    ];
    const A = D.art;
    if (!A) { out.push(h('p', { class: 'empty' }, 'The sprite GIFs have not been made yet (tools/art/sprite_gifs.py).')); return h('div', {}, out); }
    const groups = [['species', 'Playable species'], ['form', 'Built slime forms'], ['creature', 'Creatures']];
    groups.forEach(([key, title]) => {
      const items = A.sprites.filter((s) => s.group === key);
      if (!items.length) return;
      out.push(h('h2', {}, title));
      out.push(h('div', { class: 'cards' }, items.map((s) => h('figure', { class: 'card', style: 'margin:0' },
        h('h3', {}, s.name),
        s.clips.map((c) => h('div', {}, h('img', { src: 'art/' + c.file, alt: s.name + ' ' + c.id, loading: 'lazy' }), h('p', {}, c.id)))))));
    });
    return h('div', {}, out);
  }

  // ---------- essences ----------
  function renderEssences() {
    const maxSupply = Math.max(...D.essences.map((e) => e.shippedSupply), 1);
    const maxRead = Math.max(...D.essences.map((e) => e.formsReadingTotal), 1);
    const table = h('div', { class: 'table-scroll' }, h('table', {},
      h('thead', {}, h('tr', {}, ['Essence', 'Arrives in', 'Units in the shipped rooms', 'Forms that read it', 'New monsters that carry it', 'Form twins that carry it'].map((x) => h('th', {}, x)))),
      h('tbody', {}, D.essences.map((e) => h('tr', {},
        h('td', {}, chip(e.id)), h('td', {}, e.arrives),
        h('td', {}, h('div', {}, String(e.shippedSupply)), h('div', { class: 'bar', title: e.shippedSupply + ' units' }, h('i', { style: 'width:' + Math.round(100 * e.shippedSupply / maxSupply) + '%;background:var(--' + e.id + ')' }))),
        h('td', {}, h('div', {}, String(e.formsReadingTotal)), h('div', { class: 'bar', title: e.formsReadingTotal + ' forms' }, h('i', { style: 'width:' + Math.round(100 * e.formsReadingTotal / maxRead) + '%;background:var(--' + e.id + ')' }))),
        h('td', {}, e.support.length), h('td', {}, e.twinTypes + ' types, ' + e.twinUnits + ' units'))))));
    const hot = D.essences.filter((e) => !e.later && e.formsReadingTotal > e.shippedSupply).map((e) => e.id);
    const note = h('p', { class: 'note' }, 'Dashed essences (fire, mind, blood) are carried by no shipped creature; their forms are stubs until the volcano, sacred hall and cemetery arrive. ' +
      (hot.length ? 'Forms read ' + hot.join(', ') + ' more often than the shipped rooms supply it, so those areas need more of it (dark especially: the world holds 31 units) or the thresholds need recalibrating once the twins are placed.' : ''));
    const cards = h('div', { class: 'es-grid' }, D.essences.map((e) => {
      const per = Object.keys(e.formsReading).filter((s) => e.formsReading[s]).map((s) => species[s].name + ' ' + e.formsReading[s]).join(' · ');
      return h('section', { class: 'es-card el-' + e.id + (e.later ? ' later' : '') },
        h('h3', {}, e.id + (e.later ? ' (later)' : '')),
        h('dl', {},
          dlRow('Arrives in', e.arrives), dlRow('First sources', e.sources), dlRow('Note', e.note),
          dlRow('In the shipped rooms', e.shippedSupply + ' units'),
          dlRow('Forms that read it', e.formsReadingTotal + (per ? ' (' + per + ')' : '')),
          dlRow('Shipped creatures', e.existing.length ? e.existing.map((c) => c.name + ' ' + c.amount).join(', ') : 'none'),
          dlRow('New monsters', e.support.length ? e.support.map((c) => c.name + ' ' + c.amount).join(', ') : 'none')));
    }));
    return h('div', {}, note, table, h('h2', {}, 'Each essence'), cards);
  }

  // ---------- world roster ----------
  const rosterState = { kind: 'all', area: 'all', species: 'all', q: '' };
  function renderRoster() {
    const wrap = h('div', {});
    const count = h('p', { class: 'note' });
    const body = h('tbody');
    function row(c) {
      const sprite = c.sprite ? spriteCanvas(c.sprite, 28) : null;
      const kind = c.kind === 'twin' ? 'form twin' : c.kind === 'support' ? 'new monster' : 'shipped';
      let rel = '';
      if (c.kind === 'twin') rel = h('button', { type: 'button', onclick: () => select(c.twinOf), style: 'border:1px solid var(--line);background:var(--surface-2);border-radius:6px;padding:1px 8px;cursor:pointer' }, c.twinOf + ' · ' + species[c.species].name + ' form ' + c.stage);
      else if (c.twinOf && nodes[c.twinOf]) rel = h('button', { type: 'button', onclick: () => select(c.twinOf), style: 'border:1px solid var(--line);background:var(--surface-2);border-radius:6px;padding:1px 8px;cursor:pointer' }, 'base of ' + species[nodes[c.twinOf].species].name);
      else rel = c.why || '';
      return h('tr', {}, h('td', {}, h('div', { class: 'node-top' }, sprite, h('strong', {}, c.name))), h('td', {}, kind), h('td', {}, areaTags(c.areas)), h('td', {}, c.role),
        h('td', {}, h('div', { class: 'chips' }, essenceChips(c.essence))), h('td', {}, String(c.xp)), h('td', {}, rel));
    }
    function draw() {
      const list = D.creatures.filter((c) => {
        if (rosterState.kind !== 'all' && c.kind !== rosterState.kind) return false;
        if (rosterState.area !== 'all' && !c.areas.includes(rosterState.area)) return false;
        if (rosterState.species !== 'all' && c.species !== rosterState.species) return false;
        if (rosterState.q && !(c.name + ' ' + c.twinOf + ' ' + (c.why || '')).toLowerCase().includes(rosterState.q.toLowerCase())) return false;
        return true;
      });
      const order = { existing: 0, support: 1, twin: 2 };
      list.sort((a, b) => order[a.kind] - order[b.kind] || D.areas.findIndex((x) => x.id === a.areas[0]) - D.areas.findIndex((x) => x.id === b.areas[0]) || a.name.localeCompare(b.name));
      body.replaceChildren(...list.map(row));
      count.textContent = 'Showing ' + list.length + ' of ' + D.creatures.length + ' creatures. ' + D.summary.newCreatureTypes + ' are new: ' + D.summary.support +
        ' support monsters and ' + D.summary.newTwins + ' form twins. Twins share a line’s art, so the real art cost is the ' +
        D.species.reduce((a, s) => a + s.lines.length, 0) + ' lines plus their parts, not one sprite each.';
    }
    function segButton(group, value, label) {
      return h('button', { type: 'button', 'aria-pressed': String(rosterState[group] === value), onclick: (ev) => {
        rosterState[group] = value;
        ev.currentTarget.parentElement.querySelectorAll('button').forEach((b) => b.setAttribute('aria-pressed', String(b === ev.currentTarget)));
        draw();
      } }, label);
    }
    const areaSel = h('select', { id: 'f-area', onchange: (ev) => { rosterState.area = ev.target.value; draw(); } },
      h('option', { value: 'all' }, 'All areas'), D.areas.map((a) => h('option', { value: a.id, selected: rosterState.area === a.id }, a.name + (a.built ? '' : ' (planned)'))));
    const spSel = h('select', { id: 'f-species', onchange: (ev) => { rosterState.species = ev.target.value; draw(); } },
      h('option', { value: 'all' }, 'Any species'), D.species.map((s) => h('option', { value: s.id, selected: rosterState.species === s.id }, s.name)));
    const search = h('input', { type: 'search', id: 'f-q', placeholder: 'Search name or form id', value: rosterState.q, oninput: (ev) => { rosterState.q = ev.target.value; draw(); } });
    wrap.append(
      h('div', { class: 'filters' },
        h('div', { class: 'seg', role: 'group', 'aria-label': 'Kind' }, segButton('kind', 'all', 'All'), segButton('kind', 'existing', 'Shipped'), segButton('kind', 'support', 'New monsters'), segButton('kind', 'twin', 'Form twins')),
        h('label', {}, 'Area ', areaSel), h('label', {}, 'Species ', spSel), h('label', {}, 'Find ', search)),
      count,
      h('div', { class: 'table-scroll' }, h('table', {},
        h('thead', {}, h('tr', {}, ['Creature', 'Kind', 'Where', 'Role', 'Essence it carries', 'XP', 'Twin of / why'].map((x) => h('th', {}, x)))), body)));
    draw();
    return wrap;
  }

  // ---------- routing ----------
  let tabNow = null;
  function currentTab() { return tabNow || TABS[0].id; }
  function parseHash() {
    const parts = location.hash.replace(/^#/, '').split('/');
    const tab = TABS.some((t) => t.id === parts[0]) ? parts[0] : TABS[0].id;
    return { tab: tab, id: parts[1] && nodes[parts[1]] ? parts[1] : '' };
  }
  function go(tab, id) { location.hash = id ? tab + '/' + id : tab; }
  function select(id) { go(nodes[id].species, id); }

  function renderTab(tab) {
    const panel = $('#panel');
    if (species[tab]) panel.replaceChildren(renderSpecies(tab));
    else if (tab === 'movesets') panel.replaceChildren(renderMovesets());
    else if (tab === 'essences') panel.replaceChildren(renderEssences());
    else if (tab === 'roster') panel.replaceChildren(renderRoster());
    else if (tab === 'art') panel.replaceChildren(renderArt());
    panel.setAttribute('aria-label', TABS.find((t) => t.id === tab).name);
    document.querySelectorAll('#tabs button').forEach((b) => b.setAttribute('aria-selected', String(b.dataset.tab === tab)));
  }
  function route() {
    const r = parseHash();
    if (r.tab !== tabNow) { tabNow = r.tab; renderTab(r.tab); }
    document.querySelectorAll('[data-id]').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.id === r.id)));
    showDetail(r.id);
    if (r.id) {
      const el = $('#panel [data-id="' + r.id + '"]');
      if (el && el.scrollIntoView) el.scrollIntoView({ block: 'nearest', inline: 'nearest' });
    }
  }

  // ---------- page chrome ----------
  function stats() {
    const clips = D.movesets ? D.movesets.species.reduce((a, s) => a + s.clips.length, 0) : 0;
    const items = [
      [D.summary.forms, 'forms in five species, ' + D.summary.built + ' already built'],
      [D.summary.newCreatureTypes, 'new creature types (' + D.summary.support + ' support, ' + D.summary.newTwins + ' form twins)'],
      [D.essences.length, 'essences, ' + later.size + ' not carried by any creature yet'],
      [D.species.reduce((a, s) => a + s.lines.length, 0), 'evolution lines'],
      [clips, 'moveset GIFs'],
    ];
    $('#stats').replaceChildren(...items.map(([n, label]) => h('div', { class: 'stat' }, h('b', {}, String(n)), h('span', {}, label))));
    $('#built').textContent = 'Built ' + D.built.date + (D.built.sha ? ' from ' + D.built.sha : '');
  }
  function tabs() {
    $('#tabs').replaceChildren(...TABS.map((t) => h('button', { type: 'button', role: 'tab', 'data-tab': t.id, 'aria-selected': 'false', onclick: () => go(t.id) }, t.name)));
  }

  stats();
  tabs();
  window.addEventListener('hashchange', route);
  route();
})();
