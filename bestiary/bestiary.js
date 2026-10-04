(function () {
  'use strict';

  var data = window.BESTIARY;
  var creatures = data.creatures;
  var byId = {};
  creatures.forEach(function (c) { byId[c.id] = c; });

  var state = {
    zoom: 3, view: 'overlay', body: true, hurt: true, attack: true, floor: true, rulers: true,
    sort: 'height', group: 'all', frame: {}
  };
  creatures.forEach(function (c) { state.frame[c.id] = c.default; });

  var images = {};
  var lineupItems = [];

  function $(sel) { return document.querySelector(sel); }
  function css(name) { return getComputedStyle(document.documentElement).getPropertyValue(name).trim(); }
  function colors() {
    return { body: css('--body'), playerBody: css('--player-body'), hurt: css('--hurt'), attack: css('--attack'),
             floor: css('--floor'), ruler: css('--ruler'), ink: css('--ink'), muted: css('--muted') };
  }

  // --- geometry ---------------------------------------------------------------------------------------------------

  function frameOf(c, name) { return c.frames[name || state.frame[c.id]]; }
  function sizeOf(f) { return { w: f.rect[2], h: f.rect[3] }; }
  function hull(poly) {
    if (!poly || poly.length < 3) { return null; }
    var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    poly.forEach(function (p) {
      minX = Math.min(minX, p[0]); maxX = Math.max(maxX, p[0]);
      minY = Math.min(minY, p[1]); maxY = Math.max(maxY, p[1]);
    });
    return { w: Math.round(maxX - minX), h: Math.round(maxY - minY) };
  }
  function bodyWidth(c) { return c.bodies.reduce(function (m, b) { return Math.max(m, b.w); }, 0); }
  function bodyHeight(c) { return c.bodies.reduce(function (m, b) { return Math.max(m, b.h); }, 0); }
  function contentWidth(c, name) { return Math.max(sizeOf(frameOf(c, name)).w, bodyWidth(c)); }
  function contentHeight(c, name) { return Math.max(sizeOf(frameOf(c, name)).h, bodyHeight(c)); }
  function maxOverFrames(c, fn) { return c.order.reduce(function (m, n) { return Math.max(m, fn(c, n)); }, 0); }
  function bodiesText(c) {
    return c.bodies.map(function (b) { return b.w + '×' + b.h + ' (' + b.label.toLowerCase() + ')'; }).join(', ');
  }

  // --- drawing ----------------------------------------------------------------------------------------------------

  function setupCanvas(canvas, cssW, cssH) {
    var dpr = window.devicePixelRatio || 1;
    canvas.width = Math.round(cssW * dpr);
    canvas.height = Math.round(cssH * dpr);
    canvas.style.width = cssW + 'px';
    canvas.style.height = cssH + 'px';
    var ctx = canvas.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.imageSmoothingEnabled = false;
    return ctx;
  }

  function drawSprite(ctx, c, name, ox, oy, z, alpha) {
    var img = images[c.id];
    var r = frameOf(c, name).rect;
    if (!img) { return; }
    ctx.save();
    ctx.globalAlpha = alpha;
    ctx.drawImage(img, r[0], r[1], r[2], r[3], Math.round(ox - r[2] * z / 2), Math.round(oy - r[3] * z), r[2] * z, r[3] * z);
    ctx.restore();
  }

  function polygon(ctx, pts, ox, oy, z, color) {
    if (!pts || pts.length < 3) { return; }
    ctx.beginPath();
    pts.forEach(function (p, i) {
      var x = ox + p[0] * z, y = oy + p[1] * z;
      if (i === 0) { ctx.moveTo(x, y); } else { ctx.lineTo(x, y); }
    });
    ctx.closePath();
    ctx.save();
    ctx.globalAlpha = 0.1;
    ctx.fillStyle = color;
    ctx.fill();
    ctx.restore();
    ctx.lineWidth = 1.5;
    ctx.strokeStyle = color;
    ctx.stroke();
  }

  function drawShapes(ctx, c, name, ox, oy, z, col) {
    var f = frameOf(c, name);
    if (state.body) {
      c.bodies.forEach(function (b) {
        ctx.save();
        ctx.setLineDash([5, 3]);
        ctx.lineWidth = 1.5;
        ctx.strokeStyle = b.label.indexOf('Player') === 0 ? col.playerBody : col.body;
        ctx.strokeRect(ox - b.w * z / 2, oy - b.h * z, b.w * z, b.h * z);
        ctx.restore();
      });
    }
    if (state.hurt) { polygon(ctx, f.hurt, ox, oy, z, col.hurt); }
    if (state.attack) { polygon(ctx, f.attack, ox, oy, z, col.attack); }
  }

  function drawFloor(ctx, x0, x1, y, col) {
    if (!state.floor) { return; }
    ctx.save();
    ctx.strokeStyle = col.floor;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(x0, y + 1);
    ctx.lineTo(x1, y + 1);
    ctx.stroke();
    ctx.restore();
  }

  /** One creature at `ox` (its centre) standing on `oy`: the sprite with the shapes over it, or the two side by side. */
  function drawCreature(ctx, c, name, ox, oy, z, col, panelW) {
    if (state.view === 'overlay') {
      drawSprite(ctx, c, name, ox, oy, z, 1);
      drawShapes(ctx, c, name, ox, oy, z, col);
      return;
    }
    var left = ox - panelW / 2, right = ox + panelW / 2;
    drawSprite(ctx, c, name, left, oy, z, 1);
    drawSprite(ctx, c, name, right, oy, z, 0.16);
    drawShapes(ctx, c, name, right, oy, z, col);
  }

  // --- the lineup -------------------------------------------------------------------------------------------------

  function visibleCreatures() {
    var list = creatures.filter(function (c) { return state.group === 'all' || c.group === state.group; });
    var groupRank = { player: 0, form: 1, enemy: 2 };
    list.sort(function (a, b) {
      if (state.sort === 'name') { return a.name.localeCompare(b.name); }
      if (state.sort === 'group') { return groupRank[a.group] - groupRank[b.group] || a.name.localeCompare(b.name); }
      return sizeOf(frameOf(a, a.default)).h - sizeOf(frameOf(b, b.default)).h || a.name.localeCompare(b.name);
    });
    return list;
  }

  function drawLineup() {
    var canvas = $('#lineup');
    var wrap = canvas.parentElement;
    var cssW = Math.max(280, wrap.clientWidth - 16);
    var z = state.zoom;
    var col = colors();
    var split = state.view === 'split';
    var list = visibleCreatures();
    var gap = 14, labelH = 40, minItem = 92;

    var rows = [], row = null, x = 0;
    list.forEach(function (c) {
      var cw = contentWidth(c, c.default) + 4;
      var panelW = cw * z;
      var itemW = Math.max((split ? panelW * 2 : panelW) + gap, minItem);
      if (!row || (x + itemW > cssW && row.items.length)) { row = { items: [], h: 0 }; rows.push(row); x = 0; }
      row.items.push({ c: c, x: x, w: itemW, panelW: panelW });
      row.h = Math.max(row.h, contentHeight(c, c.default));
      x += itemW;
    });
    // the 24 px ruler is always there; the 60 px one only where a creature is tall enough for it to matter
    rows.forEach(function (r) { r.h = Math.max(r.h, state.rulers ? (r.h >= 36 ? 62 : 26) : 0); });

    var total = 0;
    rows.forEach(function (r) { r.top = total; r.px = r.h * z + 10; total += r.px + labelH; });
    var ctx = setupCanvas(canvas, cssW, Math.max(60, total));
    lineupItems = [];
    rows.forEach(function (r) {
      var floorY = r.top + r.px;
      drawFloor(ctx, 0, cssW, floorY, col);
      if (state.rulers) {
        [[data.refs.playerBox[1], '24 px: the player box height'], [data.refs.baseJump, '60 px: the base jump rise']].forEach(function (ref) {
          var y = floorY - ref[0] * z;
          if (y < r.top) { return; }
          ctx.save();
          ctx.strokeStyle = col.ruler;
          ctx.globalAlpha = 0.55;
          ctx.lineWidth = 1;
          ctx.setLineDash([2, 4]);
          ctx.beginPath();
          ctx.moveTo(0, y);
          ctx.lineTo(cssW, y);
          ctx.stroke();
          ctx.restore();
          ctx.fillStyle = col.ruler;
          ctx.font = '11px system-ui, sans-serif';
          ctx.textAlign = 'left';
          ctx.fillText(ref[1], 4, y - 3);
        });
      }
      r.items.forEach(function (it) {
        var c = it.c;
        var ox = it.x + (split ? it.panelW : it.panelW / 2) + gap / 2;
        drawCreature(ctx, c, c.default, ox, floorY, z, col, it.panelW);
        ctx.fillStyle = col.ink;
        ctx.font = '600 12px system-ui, sans-serif';
        ctx.textAlign = 'center';
        var cx = it.x + it.w / 2;
        ctx.fillText(c.name.replace(' (player form)', ''), cx, floorY + 16);
        var s = sizeOf(frameOf(c, c.default));
        ctx.fillStyle = col.muted;
        ctx.font = '11px system-ui, sans-serif';
        ctx.fillText(s.w + '×' + s.h, cx, floorY + 30);
        lineupItems.push({ c: c, x: it.x, y: r.top, w: it.w, h: r.px + labelH });
      });
    });
    canvas.setAttribute('aria-label', 'All ' + list.length + ' creatures at ' + z + 'x with their hit shapes, smallest first: ' +
      list.map(function (c) { return c.name; }).join(', ') + '. The numbers are in the table below.');
  }

  function itemAt(ev) {
    var rect = $('#lineup').getBoundingClientRect();
    var x = ev.clientX - rect.left, y = ev.clientY - rect.top;
    for (var i = 0; i < lineupItems.length; i++) {
      var it = lineupItems[i];
      if (x >= it.x && x < it.x + it.w && y >= it.y && y < it.y + it.h) { return it.c; }
    }
    return null;
  }

  function describe(c, name) {
    var f = frameOf(c, name);
    var s = sizeOf(f), h = hull(f.hurt), a = hull(f.attack);
    return c.name.replace(' (player form)', '') + ' · ' + (name || state.frame[c.id]) + ' · sprite ' + s.w + '×' + s.h +
      ' · hurt shape ' + (h ? h.w + '×' + h.h : 'none') + (a ? ' · attack shape ' + a.w + '×' + a.h : '') +
      ' · ' + bodiesText(c);
  }

  // --- cards ------------------------------------------------------------------------------------------------------

  var GROUP_NAMES = { enemy: 'Enemy', player: 'Player', form: 'Player form' };

  function buildCards() {
    var host = $('#cards');
    host.innerHTML = '';
    visibleCreatures().forEach(function (c) {
      var card = document.createElement('section');
      card.className = 'card';
      card.id = 'card-' + c.id;
      var h3 = document.createElement('h3');
      h3.textContent = c.name.replace(' (player form)', '');
      var tag = document.createElement('span');
      tag.className = 'tag';
      tag.textContent = GROUP_NAMES[c.group];
      h3.appendChild(tag);
      card.appendChild(h3);
      if (c.note) {
        var note = document.createElement('p');
        note.className = 'note';
        note.textContent = c.note;
        card.appendChild(note);
      }
      var scroll = document.createElement('div');
      scroll.className = 'canvas-scroll';
      scroll.style.overflowX = 'auto';
      var canvas = document.createElement('canvas');
      canvas.setAttribute('role', 'img');
      scroll.appendChild(canvas);
      card.appendChild(scroll);
      var info = document.createElement('p');
      info.className = 'info';
      card.appendChild(info);
      if (c.stats) {
        var st = document.createElement('p');
        st.className = 'stats';
        st.textContent = 'HP ' + c.stats.max_hp + ' · ATK ' + c.stats.atk + ' · DEF ' + c.stats.def + ' · SPD ' + c.stats.spd;
        card.appendChild(st);
      }
      var frames = document.createElement('div');
      frames.className = 'frames';
      frames.setAttribute('role', 'group');
      frames.setAttribute('aria-label', c.name + ' frames');
      c.order.forEach(function (name) {
        var b = document.createElement('button');
        b.type = 'button';
        b.textContent = name;
        b.dataset.frame = name;
        if (hull(c.frames[name].attack)) { b.className = 'has-attack'; b.title = 'has an attack shape'; }
        b.addEventListener('click', function () {
          state.frame[c.id] = name;
          drawCard(c);
        });
        frames.appendChild(b);
      });
      card.appendChild(frames);
      host.appendChild(card);
      drawCard(c);
    });
  }

  function drawCard(c) {
    var card = document.getElementById('card-' + c.id);
    if (!card) { return; }
    var canvas = card.querySelector('canvas');
    var z = state.zoom;
    var col = colors();
    var split = state.view === 'split';
    var cw = maxOverFrames(c, contentWidth) + 6;
    var ch = maxOverFrames(c, contentHeight) + 4;
    var panelW = cw * z;
    var ctx = setupCanvas(canvas, split ? panelW * 2 : panelW, ch * z + 6);
    var floorY = ch * z;
    drawFloor(ctx, 0, split ? panelW * 2 : panelW, floorY, col);
    var name = state.frame[c.id];
    drawCreature(ctx, c, name, split ? panelW : panelW / 2, floorY, z, col, panelW);
    canvas.setAttribute('aria-label', describe(c, name));
    card.querySelector('.info').textContent = describe(c, name).split(' · ').slice(1).join(' · ');
    card.querySelectorAll('.frames button').forEach(function (b) {
      b.setAttribute('aria-pressed', String(b.dataset.frame === name));
    });
  }

  // --- the numbers ------------------------------------------------------------------------------------------------

  function buildTable() {
    var body = $('#numbers tbody');
    body.innerHTML = '';
    creatures.slice().sort(function (a, b) {
      return sizeOf(frameOf(a, a.default)).h - sizeOf(frameOf(b, b.default)).h || a.name.localeCompare(b.name);
    }).forEach(function (c) {
      var f = frameOf(c, c.default), s = sizeOf(f), h = hull(f.hurt);
      var tr = document.createElement('tr');
      [c.name.replace(' (player form)', ''), GROUP_NAMES[c.group], s.w + '×' + s.h, h ? h.w + '×' + h.h : '-',
       c.bodies.map(function (b) { return b.w + '×' + b.h; }).join(' / '),
       c.stats ? c.stats.max_hp + ' / ' + c.stats.atk + ' / ' + c.stats.def + ' / ' + c.stats.spd : '-',
       String(c.order.length)].forEach(function (text) {
        var td = document.createElement('td');
        td.textContent = text;
        tr.appendChild(td);
      });
      body.appendChild(tr);
    });
  }

  // --- wiring -----------------------------------------------------------------------------------------------------

  function renderAll() {
    drawLineup();
    creatures.forEach(drawCard);
  }

  function pressGroup(container, attr, value) {
    container.querySelectorAll('button').forEach(function (b) { b.setAttribute('aria-pressed', String(b.dataset[attr] === value)); });
  }

  function init() {
    var built = data.built || {};
    $('#built').textContent = 'Built ' + (built.date || '') + (built.sha ? ' from main ' + built.sha : '');
    $('#zoom').addEventListener('change', function (e) { state.zoom = Number(e.target.value); renderAll(); });
    $('#sort').addEventListener('change', function (e) { state.sort = e.target.value; buildCards(); drawLineup(); });
    document.querySelectorAll('#view button').forEach(function (b) {
      b.addEventListener('click', function () { state.view = b.dataset.view; pressGroup($('#view'), 'view', state.view); renderAll(); });
    });
    document.querySelectorAll('#group button').forEach(function (b) {
      b.addEventListener('click', function () { state.group = b.dataset.group; pressGroup($('#group'), 'group', state.group); buildCards(); drawLineup(); });
    });
    ['body', 'hurt', 'attack', 'floor', 'rulers'].forEach(function (k) {
      $('#show-' + k).addEventListener('change', function (e) { state[k] = e.target.checked; renderAll(); });
    });
    var lineup = $('#lineup');
    lineup.addEventListener('mousemove', function (e) {
      var c = itemAt(e);
      lineup.style.cursor = c ? 'pointer' : 'default';
      $('#status').textContent = c ? describe(c, c.default) : 'Hover a creature for its numbers; click it to jump to its card.';
    });
    lineup.addEventListener('click', function (e) {
      var c = itemAt(e);
      var card = c && document.getElementById('card-' + c.id);
      if (!card) { return; }
      card.scrollIntoView({ behavior: 'smooth', block: 'center' });
      card.classList.add('flash');
      setTimeout(function () { card.classList.remove('flash'); }, 1400);
    });
    var timer = null;
    window.addEventListener('resize', function () { clearTimeout(timer); timer = setTimeout(drawLineup, 120); });
    var mq = window.matchMedia('(prefers-color-scheme: dark)');
    if (mq.addEventListener) { mq.addEventListener('change', renderAll); }
    buildTable();
    buildCards();
    drawLineup();
  }

  var pending = creatures.length;
  creatures.forEach(function (c) {
    var img = new Image();
    img.onload = img.onerror = function () { images[c.id] = img.complete && img.naturalWidth ? img : null; pending -= 1; if (pending === 0) { init(); } };
    img.src = c.image;
  });
})();
