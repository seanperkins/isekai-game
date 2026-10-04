class_name AltarModel
extends RefCounted
## An altar's menu as pure state: attune once, bank held essence into soul points per element, and buy the altar's local perk.
## Rows, in order: attune, one per essence (water, earth, air, light, dark), then the perk when the altar has one. Banking and
## buying need an attuned altar. A perk bought here applies from the next life (SoulPerks), never to the live body.

## What the last action did, for the menu's footer.
var message := ""

var _id: String
var _perk: PerkDef
var _progress: WorldProgress
var _soul: SoulProgress
var _rules: SoulRules
var _engine: SkillRulesEngine
var _on_attuned: Callable
var _row := 0
var _units := {}  # element -> the amount chosen to bank (always a multiple of the bank rate, within what is held)

## `perk` may be null (an altar with no local perk yet); `on_attuned` runs once, when the altar is attuned.
func _init(altar_id: String, perk: PerkDef, progress: WorldProgress, soul: SoulProgress, rules: SoulRules,
		engine: SkillRulesEngine, on_attuned := Callable()) -> void:
	_id = altar_id
	_perk = perk
	_progress = progress
	_soul = soul
	_rules = rules
	_engine = engine
	_on_attuned = on_attuned

func attuned() -> bool:
	return _progress.is_attuned(_id)

func rows() -> Array:
	var out: Array = [{"kind": "attune", "done": attuned()}]
	for element in Essences.ALL:
		var units := _units_of(element)
		@warning_ignore("integer_division")
		var points := units / maxi(1, _rules.bank_rate)
		out.append({"kind": "element", "element": element, "held": _engine.held(element), "units": units, "points": points})
	if _perk != null:
		var times := _soul.perk_count(_perk.id)
		out.append({"kind": "perk", "id": _perk.id, "name": _perk.display_name, "times": times, "price": _perk.price_of(times)})
	return out

func row() -> int:
	return _row

## Moves the highlighted row, stopping at the ends.
func move(step: int) -> void:
	_row = clampi(_row + step, 0, _row_count() - 1)

## Left (negative) or right (positive) on an element row: one soul point's worth of that essence less or more, within what is held.
func adjust(step: int) -> void:
	var element := _element_at(_row)
	if element == "":
		return
	_units[element] = clampi(_units_of(element) + step * _rules.bank_rate, 0, Banking.max_units(_rules, _engine, element))

## The highlighted row's action. False when nothing happened; `message` says why.
func act() -> bool:
	if _row == 0:
		return _attune()
	var element := _element_at(_row)
	if element != "":
		return _bank(element)
	return _buy()

func _attune() -> bool:
	if attuned():
		return false
	_progress.attune(_id)
	if _on_attuned.is_valid():
		_on_attuned.call()
	message = "Attuned."
	return true

func _bank(element: String) -> bool:
	if not attuned():
		message = "Attune first."
		return false
	var gained := Banking.bank(_rules, _engine, _soul, element, _units_of(element))
	if gained <= 0:
		message = "Nothing to bank."
		return false
	_units[element] = 0
	message = "Banked %d soul point%s." % [gained, "" if gained == 1 else "s"]
	return true

func _buy() -> bool:
	if not attuned():
		message = "Attune first."
		return false
	if not _soul.buy_perk(_perk):
		message = "Not enough soul points."
		return false
	message = "%s bought. It applies from your next life." % _perk.display_name
	return true

func _row_count() -> int:
	return 1 + Essences.ALL.size() + (1 if _perk != null else 0)

## The essence of an element row, or "" for the attune and perk rows.
func _element_at(row: int) -> String:
	return Essences.ALL[row - 1] if row >= 1 and row <= Essences.ALL.size() else ""

func _units_of(element: String) -> int:
	return clampi(int(_units.get(element, 0)), 0, Banking.max_units(_rules, _engine, element))

## The soul points the player holds (saved plus session), for the menu's footer.
func points() -> int:
	return _soul.total_points()
