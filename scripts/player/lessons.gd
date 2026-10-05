class_name Lessons
extends RefCounted
## What a goblin has learned in a life. The first dealing with a creature type pays all of its essence, a repeat a trickle: one unit of
## its largest essence. A goblin learns instead of devouring (design doc), so this is where its essence comes from.

var _known := {}

## What dealing with `def` is worth: {"first": whether it is the first with this id, "element": its largest essence ("" for none),
## "essences": the essences paid, one entry per unit, in Essences.ALL order for a first dealing}.
func learn(def: CreatureDef) -> Dictionary:
	var first := not _known.has(def.id)
	_known[def.id] = true
	var element := Lessons.primary(def)
	var paid := []
	if first:
		for ess in Essences.ALL:
			for i in int(def.essences.get(ess, 0)):
				paid.append(ess)
	elif element != "":
		paid.append(element)
	return {"first": first, "element": element, "essences": paid}

func known(id: String) -> bool:
	return _known.has(id)

func count() -> int:
	return _known.size()

func reset() -> void:
	_known = {}

## The essence with the most units, ties to the earlier in Essences.ALL; "" when it has none.
static func primary(def: CreatureDef) -> String:
	var best := ""
	for ess in Essences.ALL:
		if int(def.essences.get(ess, 0)) > int(def.essences.get(best, 0)):
			best = ess
	return best
