class_name FormOffers
extends RefCounted
## Which bodies the slime is offered when it can evolve. Pure functions over data.
##   Stage 1 to 2: by affinity: the units of a lineage's essences absorbed this run divided by that
##     lineage's supply (the same essences across every spawn of the first-evolution areas' rooms, FIRST_EVOLUTION_AREAS).
##   Stage 2 to 3: the form's two children. Stage 3 to 4: the lineage's one Sovereign. Stage 4: none.

const ELIGIBLE := 0.6
const MAX_OFFERS := 3
const LINEAGE_ORDER := ["weaver", "tide", "toxic", "bulwark", "echo"]
const FALLBACK := "greater_slime"
## The areas a stage-1 life plays before its first evolution (the Cave and Grotto reach stage 1's cap; test_first_evolution_areas
## derives it). Only stage 1 to 2 reads affinity, so a later area (the Flooded) adds no denominator and dilutes nothing.
const FIRST_EVOLUTION_AREAS := ["cave", "grotto"]

static var _default_supply := {}

## The supply over the first-evolution areas of the shipped rooms and creatures (res://data), computed once.
static func default_supply(forms: Dictionary) -> Dictionary:
	if _default_supply.is_empty():
		var creatures := {}
		for c in DefLoader.load_dir("res://data/creatures"):
			creatures[c.id] = c
		_default_supply = supply(World.load_rooms("res://data/rooms"), creatures, forms, FIRST_EVOLUTION_AREAS)
	return _default_supply

## lineage -> its essences, read from the stage-2 forms.
static func lineage_essences(forms: Dictionary) -> Dictionary:
	var out := {}
	for f in FormLoader.stage2_forms(forms):
		if (f as FormDef).lineage != "greater":
			out[(f as FormDef).lineage] = (f as FormDef).essences
	return out

## lineage -> units of its essences across every spawn in `rooms` (only the rooms of `areas`, when given).
static func supply(rooms: Dictionary, creatures: Dictionary, forms: Dictionary, areas: Array = []) -> Dictionary:
	var by_lineage := lineage_essences(forms)
	var out := {}
	for l in by_lineage:
		out[l] = 0
	for id in rooms:
		if not areas.is_empty() and not areas.has((rooms[id] as RoomDef).area):
			continue
		for s in (rooms[id] as RoomDef).spawns:
			var c: CreatureDef = creatures.get(s["id"])
			if c == null:
				continue
			for l in by_lineage:
				for e in by_lineage[l]:
					out[l] += int(c.essences.get(e, 0))
	return out

## lineage -> absorbed units / supply (0 when the lineage has no supply).
static func affinity(absorbed: Dictionary, p_supply: Dictionary, forms: Dictionary) -> Dictionary:
	var by_lineage := lineage_essences(forms)
	var out := {}
	for l in by_lineage:
		var units := 0
		for e in by_lineage[l]:
			units += int(absorbed.get(e, 0))
		var total := int(p_supply.get(l, 0))
		out[l] = float(units) / float(total) if total > 0 else 0.0
	return out

## essence -> units absorbed this run, from the skill engine's ledger.
static func absorbed_units(rules: SkillRulesEngine, seeded := {}) -> Dictionary:
	var out := {}
	for e in Essences.ALL:
		out[e] = rules.count(Events.ABSORBED, {"essence": e})
	for e in seeded:  # a rebirth kit's seeded units count here, and only here
		out[e] = int(out.get(e, 0)) + int(seeded[e])
	return out

## The form ids on offer for `form` (a Form), given what was absorbed and the supply.
static func offers(forms: Dictionary, form: Form, absorbed: Dictionary, p_supply: Dictionary) -> Array:
	if form.stage == 1:
		return _first_offers(forms, absorbed, p_supply)
	var out: Array = []
	for k in FormLoader.children_of(forms, form.form_id):
		out.append((k as FormDef).id)
	return out

static func _first_offers(forms: Dictionary, absorbed: Dictionary, p_supply: Dictionary) -> Array:
	var a := affinity(absorbed, p_supply, forms)
	var eligible: Array = []
	for l in LINEAGE_ORDER:
		if float(a.get(l, 0.0)) >= ELIGIBLE and forms.has(l):
			eligible.append(l)
	# highest affinity first; the stable sort keeps lineage order for ties
	eligible.sort_custom(func(x, y): return float(a[x]) > float(a[y]))
	var out: Array = eligible.slice(0, MAX_OFFERS)
	if out.size() < 2 and forms.has(FALLBACK):
		out.append(FALLBACK)
	return out
