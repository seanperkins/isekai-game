class_name SkillTreeModel
extends RefCounted
## Pure data for the Tree tab: the nodes (powers, their evolutions and the body forms), the edges that join them, and
## where each one sits. No scene code: SkillTreeView draws it. A node is {"id", "kind", "state"} and, unless it is a stub,
## its "name", plus "hint" and "condition" as far as the Compendium state allows.

const OWNED := "owned"
const NAMED := "named"
const RETIRED := "retired"
const CLOSED := "closed"
const READY := "ready"
const CURRENT := "current"
const REACHED := "reached"
const STUB := "stub"

## Node size and spacing at the normal zoom, in canvas px. Every edge joins adjacent columns, so it runs in the gap between
## them and never crosses a label.
const NODE_SIZE := Vector2(104, 12)
const LABEL_INSET := 3.0
const COL_PITCH := 118.0
const ROW_PITCH := 14.0
const GRID_COLS := 2

## {"nodes": {id: node}, "edges": [{"from", "to", "kind", "known"}], "size": Vector2}. Every edge joins two nodes in "nodes";
## each node's "pos" is its top-left corner on the canvas at the normal zoom.
static func build(rules, compendium: CompendiumModel, forms: Dictionary, reached_forms: Array, current_form: String) -> Dictionary:
	var defs := _skill_defs(rules, compendium)
	var by_id := {}
	for d in defs:
		by_id[d.id] = d
	var nodes := {}
	for d in defs:
		var n := _skill_node(rules, compendium, d, by_id)
		if not n.is_empty():
			nodes[d.id] = n
	var edges: Array = []
	for d in defs:
		if d.source == "evolution" and d.replaces != "":
			edges.append({"from": d.replaces, "to": d.id, "kind": "evolves"})
	var slots := _power_slots(defs, _row_powers(defs), nodes)
	for id in nodes:
		nodes[id]["pos"] = slots[id]
	return {"nodes": nodes, "edges": _visible_edges(nodes, edges), "size": _canvas(slots)}

## Every non-enemy skill, in id order: the Compendium keeps one slot for each.
static func _skill_defs(rules, compendium: CompendiumModel) -> Array:
	var ids: Array = compendium.states().keys()
	ids.sort()
	var out: Array = []
	for id in ids:
		var d: SkillDef = rules.get_def(id)
		if d != null:
			out.append(d)
	return out

## A skill's node, or {} when it does not show. It shows from Named, a secret one only from Owned-once, and an Unknown
## evolution of a power owned once is a nameless stub (a merely Named power reveals no branches).
static func _skill_node(rules, compendium: CompendiumModel, d: SkillDef, by_id: Dictionary) -> Dictionary:
	var kind := "evolution" if d.source == "evolution" else "power"
	var st := compendium.state(d.id)
	if d.secret and st < CompendiumModel.State.OWNED_ONCE:
		return {}
	if st == CompendiumModel.State.UNKNOWN:
		if kind == "evolution" and compendium.state(d.replaces) == CompendiumModel.State.OWNED_ONCE:
			return {"id": d.id, "kind": kind, "state": STUB}
		return {}
	var n := {"id": d.id, "kind": kind, "state": _skill_state(rules, d.id), "name": d.display_name}
	if st >= CompendiumModel.State.HINTED and d.hint != "":
		n["hint"] = d.hint
	if st == CompendiumModel.State.OWNED_ONCE:
		n["condition"] = SkillScreenModel.condition_text(d, by_id)
	if n["state"] == READY:
		n["affordable"] = rules.can_afford(d.id)
	return n

## The state the engine gives a shown skill, read as the Skills tab reads it.
static func _skill_state(rules, id: String) -> String:
	if rules.is_retired(id):
		return RETIRED
	if rules.owned().has(id):
		return OWNED
	if rules.is_closed(id):
		return CLOSED
	if rules.is_evolution_ready(id):
		return READY
	return NAMED

## The edges whose two ends are both nodes, each marked known unless one end is a stub (an edge to a stub is drawn dim).
static func _visible_edges(nodes: Dictionary, edges: Array) -> Array:
	var out: Array = []
	for e in edges:
		if nodes.has(e["from"]) and nodes.has(e["to"]):
			out.append({"from": e["from"], "to": e["to"], "kind": e["kind"],
				"known": nodes[e["from"]]["state"] != STUB and nodes[e["to"]]["state"] != STUB})
	return out

## The powers drawn one per row, with their evolutions beside them: those that evolve, in id order.
static func _row_powers(defs: Array) -> Array:
	var out: Array = []
	for d in defs:
		if d.source != "evolution" and not _evolutions_of(defs, d.id).is_empty():
			out.append(d.id)
	return out

## The evolutions that replace `id`, in id order.
static func _evolutions_of(defs: Array, id: String) -> Array:
	var out: Array = []
	for d in defs:
		if d.source == "evolution" and d.replaces == id:
			out.append(d.id)
	return out

## A slot for every skill that can show, shown or not, so discovering one never moves another. The row powers go down
## column 0 with their evolutions in column 1; the other powers fill a GRID_COLS-wide grid from column 2, by name. A secret
## takes a slot only once it is a node, after the rest of the grid, in id order: a reserved empty cell would give it away.
static func _power_slots(defs: Array, row_powers: Array, nodes: Dictionary) -> Dictionary:
	var slots := {}
	var row := 0
	for id in row_powers:
		slots[id] = Vector2(0, row * ROW_PITCH)
		var kids := _evolutions_of(defs, id)
		for i in kids.size():
			slots[kids[i]] = Vector2(COL_PITCH, (row + i) * ROW_PITCH)
		row += maxi(1, kids.size())
	var grid := defs.filter(func(d): return d.source != "evolution" and not row_powers.has(d.id) and not d.secret)
	grid.sort_custom(func(a, b): return a.display_name < b.display_name)
	var secrets := defs.filter(func(d): return d.source != "evolution" and not row_powers.has(d.id) and d.secret and nodes.has(d.id))
	grid.append_array(secrets)  # defs are in id order already
	for i in grid.size():
		slots[grid[i].id] = Vector2((2 + i % GRID_COLS) * COL_PITCH, (i / GRID_COLS) * ROW_PITCH)
	return slots

## The canvas: just large enough for every slot.
static func _canvas(slots: Dictionary) -> Vector2:
	var out := Vector2.ZERO
	for id in slots:
		out = out.max(slots[id] + NODE_SIZE)
	return out

## Where the selection starts: the top-left node ("" for an empty tree). Every node can be reached from it by neighbor().
static func root(model: Dictionary) -> String:
	var best := ""
	for id in model["nodes"]:
		if best == "" or _before(model["nodes"][id], model["nodes"][best], id, best):
			best = id
	return best

static func _before(a: Dictionary, b: Dictionary, a_id: String, b_id: String) -> bool:
	var pa: Vector2 = a["pos"]
	var pb: Vector2 = b["pos"]
	if pa.y != pb.y:
		return pa.y < pb.y
	if pa.x != pb.x:
		return pa.x < pb.x
	return a_id < b_id

## The node a move in `dir` (Vector2i.UP is up) selects from `id`. It is the nearest node joined to `id` by an edge that lies
## in that direction (within 45 degrees of it), else the nearest node in that open half-plane, ties broken by id; `id`
## itself when nothing lies that way. The cone keeps a nearly sideways edge from beating the node straight below or above:
## from a form whose children flank it, "down" must reach the form underneath.
static func neighbor(model: Dictionary, id: String, dir: Vector2i) -> String:
	var nodes: Dictionary = model["nodes"]
	if not nodes.has(id):
		return id
	var from := _centre(nodes[id])
	var joined: Array = []
	for e in model["edges"]:
		if e["from"] == id:
			joined.append(e["to"])
		elif e["to"] == id:
			joined.append(e["from"])
	var best := _nearest(nodes, from, dir, joined, true)
	if best == "":
		best = _nearest(nodes, from, dir, nodes.keys(), false)
	return id if best == "" else best

## The nearest of `ids` ahead of `from` in `dir`: in the open half-plane, or within the 45-degree cone when `cone`.
static func _nearest(nodes: Dictionary, from: Vector2, dir: Vector2i, ids: Array, cone: bool) -> String:
	var sorted := ids.duplicate()
	sorted.sort()
	var best := ""
	var best_d := INF
	for other in sorted:
		var off := _centre(nodes[other]) - from
		var along := off.dot(Vector2(dir))
		if along <= 0.0 or (cone and absf(off.cross(Vector2(dir))) > along):
			continue
		if off.length() < best_d:
			best_d = off.length()
			best = other
	return best

static func _centre(node: Dictionary) -> Vector2:
	return node["pos"] + NODE_SIZE / 2.0
