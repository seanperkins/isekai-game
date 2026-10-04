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

## {"nodes": {id: node}, "edges": [{"from", "to", "kind", "known"}]}. Every edge joins two nodes in "nodes".
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
	return {"nodes": nodes, "edges": _visible_edges(nodes, edges)}

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
