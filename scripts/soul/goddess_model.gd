class_name GoddessModel
extends RefCounted
## The goddess's scene as pure state: three panels (where, who, head start), the cart, what it costs and what confirming gives.
## Nothing here draws or spends: the menu drives it, and the death flow spends `confirm()["cost"]`.
## `places`, `species` and `powers` are [{"id": String, "name": String}]: the attuned altars and the unlocked species (default
## first), and the head-start powers HeadStart.eligible_powers found. `last` is {"pool", "species"}, the previous choice.

enum Pane { WHERE, WHO, HEAD_START }

var panel: int = Pane.WHERE
## What is being bought: {"levels": int, "powers": Array of skill ids}.
var cart := {"levels": 0, "powers": []}
var soul: SoulProgress

var _rules: SoulRules
var _places: Array
var _species: Array
var _powers: Array
var _rows := [0, 0, 0]

func _init(places: Array, species: Array, powers: Array, p_soul: SoulProgress, rules: SoulRules, last := {}) -> void:
	_places = places
	_species = species
	_powers = powers
	soul = p_soul
	_rules = rules
	_rows[Pane.WHERE] = _index_of(places, str(last.get("pool", "")))
	_rows[Pane.WHO] = _index_of(species, str(last.get("species", "")))

func switch_panel(step: int) -> void:
	panel = posmod(panel + step, 3)

## Moves the highlighted row of the current panel, stopping at the ends.
func move(step: int) -> void:
	_rows[panel] = clampi(_rows[panel] + step, 0, maxi(0, _row_count(panel) - 1))

func row(p: int) -> int:
	return _rows[p]

## A panel's rows. Where and Who are the given lists; Head start is the level row, then one row per power.
func rows(p: int) -> Array:
	if p == Pane.WHERE:
		return _places
	if p == Pane.WHO:
		return _species
	var levels: int = cart["levels"]
	var next_price := int(_rules.level_prices[levels]) if levels < _max_levels() else -1
	var out: Array = [{"kind": "level", "levels": levels, "max": _max_levels(), "next_price": next_price}]
	for power in _powers:
		out.append({"kind": "power", "id": power["id"], "name": power["name"],
			"taken": cart["powers"].has(power["id"]), "price": _rules.power_price})
	return out

## Left (negative) or right (positive) on the Head start panel: a level more or fewer on the level row, a power taken (once) or
## dropped on a power row. Does nothing on the other panels.
func adjust(step: int) -> void:
	if panel != Pane.HEAD_START or step == 0:
		return
	var r: int = _rows[Pane.HEAD_START]
	if r == 0:
		cart["levels"] = clampi(int(cart["levels"]) + signi(step), 0, _max_levels())
		return
	var id: String = _powers[r - 1]["id"]
	var taken: Array = cart["powers"]
	if step > 0 and not taken.has(id):
		taken.append(id)
	elif step < 0:
		taken.erase(id)

func selected_place() -> String:
	return str(_places[_rows[Pane.WHERE]]["id"]) if not _places.is_empty() else ""

func selected_species() -> String:
	return str(_species[_rows[Pane.WHO]]["id"]) if not _species.is_empty() else ""

func cost() -> int:
	return HeadStart.price(_rules, cart)

func can_afford() -> bool:
	return cost() <= soul.total_points()

## {"altar", "species", "kit", "cost"}, or {} when the cart is unaffordable or there is nowhere or no one to be reborn as.
func confirm() -> Dictionary:
	if _places.is_empty() or _species.is_empty() or not can_afford():
		return {}
	return {"altar": selected_place(), "species": selected_species(), "kit": HeadStart.kit(cart), "cost": cost()}

## False when there is nothing to choose: one place, one species, and too few points to buy anything.
func need_menu() -> bool:
	if _places.size() > 1 or _species.size() > 1:
		return true
	var cheapest := HeadStart.cheapest(_rules, _powers.size())
	return cheapest >= 0 and soul.total_points() >= cheapest

func _max_levels() -> int:
	return _rules.level_prices.size()

func _row_count(p: int) -> int:
	if p == Pane.WHERE:
		return _places.size()
	if p == Pane.WHO:
		return _species.size()
	return 1 + _powers.size()

static func _index_of(items: Array, id: String) -> int:
	for i in items.size():
		if items[i]["id"] == id:
			return i
	return 0
