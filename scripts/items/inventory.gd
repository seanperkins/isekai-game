class_name Inventory
extends RefCounted
## The parts one life carries and wears. A graft is worn when the body can graft and its slot has room (and fewer than GRAFT_CAP
## are worn); everything else is carried. Pure data: the player turns stat_mods() into modifiers.

const GRAFT_CAP := 4

## Slots a body has beyond the usual (a stitched body wears more); the Player sets it from its traits.
var extra_slots := 0

func graft_cap() -> int:
	return GRAFT_CAP + extra_slots
## A cocoon is carried like a part, as the id "cocoon:<creature>"; a spider carries at most this many.
const COCOON_PREFIX := "cocoon:"
const COCOON_COUNT_MAX := 2

var _parts: Dictionary
var _worn: Array = []
var _carried: Array = []

func _init(parts: Dictionary) -> void:
	_parts = parts

static func is_cocoon(id: String) -> bool:
	return id.begins_with(COCOON_PREFIX) and id.length() > COCOON_PREFIX.length()

func add(id: String, can_graft: bool) -> Dictionary:
	if Inventory.is_cocoon(id):
		var ok := add_cocoon(id.trim_prefix(COCOON_PREFIX))
		return {"ok": ok, "worn": false}
	if not _parts.has(id):
		return {"ok": false, "worn": false}
	var worn := _can_wear(_parts[id], can_graft)
	if worn:
		_worn.append(id)
	else:
		_carried.append(id)
	return {"ok": true, "worn": worn}

## The most recently worn graft, taken off; "" when nothing is worn.
func shed_one() -> String:
	if _worn.is_empty():
		return ""
	return _worn.pop_back()

## One carried part (the first), taken out: what a goblin offers a creature it tames. "" when no part is carried; a worn graft and a cocoon
## are never taken.
func take_carried() -> String:
	for i in _carried.size():
		if not Inventory.is_cocoon(_carried[i]):
			var id: String = _carried[i]
			_carried.remove_at(i)
			return id
	return ""

## The carried parts that can be spent as craft material (a forge, a rig, a spin, a corrosion): grafts. A key (a Moonstone) or a held item (a phylactery
## shard) is carried for what it is for and is never spent that way.
func craft_stock() -> Array:
	return _carried.filter(func(id: String) -> bool: return not Inventory.is_cocoon(id) and _parts.has(id) and _parts[id].kind == "graft")

## The first craft part, taken out of the pack; "" when none is carried.
func take_craft() -> String:
	for i in _carried.size():
		var id: String = _carried[i]
		if not Inventory.is_cocoon(id) and _parts.has(id) and _parts[id].kind == "graft":
			_carried.remove_at(i)
			return id
	return ""

## A cocoon holding a living creature, carried; false (and nothing added) at COCOON_COUNT_MAX.
func add_cocoon(creature_id: String) -> bool:
	if cocoons().size() >= COCOON_COUNT_MAX:
		return false
	_carried.append(COCOON_PREFIX + creature_id)
	return true

## The creatures in the carried cocoons, in the order they were webbed.
func cocoons() -> Array:
	return _carried.filter(func(id: String) -> bool: return Inventory.is_cocoon(id)).map(func(id: String) -> String: return id.trim_prefix(COCOON_PREFIX))

## The first cocoon's creature, taken out of the pack; "" when none is carried.
func take_cocoon() -> String:
	for i in _carried.size():
		if Inventory.is_cocoon(_carried[i]):
			var id: String = _carried[i]
			_carried.remove_at(i)
			return id.trim_prefix(COCOON_PREFIX)
	return ""

## What is carried that is a part: everything but the cocoons.
func carried_parts() -> Array:
	return _carried.filter(func(id: String) -> bool: return not Inventory.is_cocoon(id))

func carried() -> Array:
	return _carried.duplicate()

func worn() -> Array:
	return _worn.duplicate()

func count(id: String) -> int:
	return _worn.count(id) + _carried.count(id)

## One modifier per stat of every worn graft, in the shape Stats.set_modifiers takes.
func stat_mods() -> Array:
	var mods := []
	for id in _worn:
		var stats: Dictionary = _parts[id].stats
		for stat in stats:
			mods.append({"stat": stat, "op": "add", "value": stats[stat]})
	return mods

## Everything, worn and carried; the inventory is left empty.
func take_all() -> Array:
	var all := _worn + _carried
	_worn = []
	_carried = []
	return all

func give_all(ids: Array, can_graft: bool) -> void:
	for id in ids:
		add(id, can_graft)

func _can_wear(def: PartDef, can_graft: bool) -> bool:
	if not can_graft or def.kind != "graft" or _worn.size() >= graft_cap():
		return false
	var in_slot := _worn.filter(func(id: String) -> bool: return _parts[id].slot == def.slot).size()
	return in_slot < def.worn_max
