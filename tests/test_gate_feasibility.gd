extends GutTest
## Every gate atom that names a thing (a creature, a species, a part, a bond, an element) can be met by what the world holds: the checked-in
## rooms of every area, the placed creatures included. The atoms that name nothing in the world (a deed, a streak, a verb) are counted, not
## skipped silently.

## How many gate atoms in the data this test cannot check against the world (they ask for a deed, a streak or a verb used).
const UNCHECKED := 53

## A gate's essence must be this many times in the world, for a life that will not eat all of it.
const MARGIN := 2.5

var forms := {}
var defs := {}
var present := {}  # creature id -> how many spawns of it the world has
var supply := {}  # element -> units over every spawn of the world a tackle can down
var dropped := {}  # part -> true when some creature of the world drops it
var bonds := {}  # bond kind -> true when some creature of the world accepts it
var species := {}  # species -> true when some creature of the world is of it

func before_all() -> void:
	forms = FormLoader.load_all()
	for c in DefLoader.load_dir("res://data/creatures"):
		defs[c.id] = c
	var rooms := World.load_rooms(AreaBuilder.ROOMS_DIR)
	for id in rooms:
		for s in (rooms[id] as RoomDef).spawns:
			present[s["id"]] = int(present.get(s["id"], 0)) + 1
	for cid in present:
		var c: CreatureDef = defs[cid]
		if c.species != "":
			species[c.species] = true
		for d in c.drops:
			dropped[str(d["part"])] = true
		for b in c.bonds:
			bonds[str(b)] = true
		if not c.untackleable:
			for e in c.essences:
				supply[e] = int(supply.get(e, 0)) + int(c.essences[e]) * int(present[cid])

## null when the world has nothing to say about this atom; true or false when it does.
func _met(a: Dictionary):
	var tags: Dictionary = a.get("tags", {})
	match a.get("kind", ""):
		"held":
			return int(supply.get(a["element"], 0)) >= int(a["n"])
		"counter":
			var event: String = a["event"]
			if tags.has("creature") or tags.has("source"):
				var id: String = str(tags.get("creature", tags.get("source", "")))
				if defs.has(id):  # a creature id (an essence source such as "water" is not one)
					return present.has(id)
			if tags.has("species") and ["lesson_learned", "predated", "defeated"].has(event):
				return species.has(tags["species"])
			if tags.has("part") and ["part_harvested", "graft_attached", "item_stolen"].has(event):
				return dropped.has(tags["part"])
			if event == "absorbed" and tags.has("essence"):
				return float(supply.get(tags["essence"], 0)) >= MARGIN * float(a["n"])
			if event == "bond_formed" and tags.has("kind"):
				return bonds.has(tags["kind"]) or (tags["kind"] == "long" and not bonds.is_empty())  # a long bond is any bond kept a while
			if event == "lesson_learned" and tags.has("element"):
				var kinds := 0
				for id in present:
					if int((defs[id] as CreatureDef).essences.get(tags["element"], 0)) > 0:
						kinds += 1
				return kinds >= int(a["n"])
	return null

func test_every_atom_that_names_a_thing_can_be_met_by_the_world() -> void:
	var unchecked := 0
	var checked := 0
	for f: FormDef in forms.values():
		for a in f.gate:
			var alts: Array = a["of"] if a.get("kind", "") == "any" else [a]
			var verdicts := alts.map(func(x: Dictionary): return _met(x))
			if verdicts.all(func(v) -> bool: return v == null):
				unchecked += alts.size()
				continue
			checked += 1
			assert_true(verdicts.any(func(v) -> bool: return v == true) or verdicts.any(func(v) -> bool: return v == null), "%s: no alternative of %s can be met by the world" % [f.id, str(a)])
	assert_gt(checked, 30, "a good part of the gates name something")
	assert_eq(unchecked, UNCHECKED, "the atoms the world has nothing to say about")

func test_the_scarcest_essence_a_gate_asks_for_is_in_the_world_three_times_over() -> void:
	var scarcest := INF
	for f: FormDef in forms.values():
		for a in f.gate:
			var element := ""
			var n := 0
			if a.get("kind", "") == "held":
				element = a["element"]
				n = int(a["n"])
			elif a.get("event", "") == "absorbed":
				element = a["tags"]["essence"]
				n = int(a["n"])
			if element != "":
				scarcest = minf(scarcest, float(supply.get(element, 0)) / float(n))
				assert_gte(float(supply.get(element, 0)), MARGIN * float(n), "%s: %s %d asked, the world holds %d" % [f.id, element, n, supply.get(element, 0)])
	assert_almost_eq(scarcest, 3.0, 0.05, "blood: 22 asked of 65 in the world")

func test_every_new_creature_is_in_the_world_so_every_named_creature_can_be_met() -> void:
	for id in MenagerieIds.ALL:
		assert_true(present.has(id), id)
