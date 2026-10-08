// The index as an evolution chart: a column for each stage, a row for each creature that nothing grows from, and every parent centred beside its children.
// Pure (no DOM), so it can be tested on its own. `list` is the index entries {id, stage, parent}; returns the cards' places and the lines between them.
export function layoutTree(list) {
  const ids = new Set(list.map((c) => c.id));
  const kids = new Map();
  for (const c of list) {
    const parent = c.parent && ids.has(c.parent) && c.parent !== c.id ? c.parent : null;   // a parent that is not published, or is itself, leaves a root
    if (!kids.has(parent)) kids.set(parent, []);
    kids.get(parent).push(c);
  }
  const order = (a, b) => (a.stage ?? 99) - (b.stage ?? 99) || a.id.localeCompare(b.id);
  const col = new Map();
  const row = new Map();
  const seen = new Set();
  const edges = [];
  let next = 0;
  const place = (c, minCol) => {
    seen.add(c.id);
    const mine = Math.max((c.stage ?? minCol + 1) - 1, minCol);   // its stage's column, but never left of the one after its parent's
    col.set(c.id, mine);
    const children = (kids.get(c.id) || []).sort(order).filter((k) => !seen.has(k.id));
    if (!children.length) {
      row.set(c.id, next++);
      return;
    }
    for (const k of children) {
      edges.push([c.id, k.id]);
      place(k, mine + 1);
    }
    row.set(c.id, (row.get(children[0].id) + row.get(children[children.length - 1].id)) / 2);
  };
  for (const root of (kids.get(null) || []).sort(order)) place(root, 0);
  for (const c of list.filter((c) => !seen.has(c.id)).sort(order)) place(c, 0);   // a parent loop, however it came about, still shows
  const nodes = list.map((c) => ({ c, col: col.get(c.id), row: row.get(c.id) }));
  return { nodes, edges, cols: nodes.length ? Math.max(...nodes.map((n) => n.col)) + 1 : 0, rows: next };
}
