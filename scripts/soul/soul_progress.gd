class_name SoulProgress
extends RefCounted
## What the player has earned across lives: soul points (banked at altars), the perks bought with them and how often they have
## died. Saves through the Profile ('soul' section) on every change; without a Profile it lives in memory.

var profile  # Profile, or null
var points := 0
## perk id -> times bought.
var perks := {}
var deaths := 0
## Points granted by the `--soul=N` dev flag. Never saved; spent before the saved points.
var session_points := 0

var _unknown_perks := {}  # saved counts for perk ids the data does not hold; written back as they were

## A malformed or negative saved value loads as zero. A perk the data does not hold (not in `known_perks`) is not counted, but
## it stays in the saved section untouched: perk data that fails to load for a moment, or a perk renamed on another branch,
## must not erase what the player bought.
func _init(p_profile = null, known_perks: Array = []) -> void:
	profile = p_profile
	if profile == null:
		return
	var saved: Dictionary = profile.dict_section("soul")
	points = _count(saved.get("points"))
	deaths = _count(saved.get("deaths"))
	var raw = saved.get("perks")
	if typeof(raw) == TYPE_DICTIONARY:
		for id in raw:
			var times := _count(raw[id])
			if times <= 0:
				continue
			if known_perks.has(str(id)):
				perks[str(id)] = times
			else:
				_unknown_perks[str(id)] = times

func total_points() -> int:
	return points + session_points

func add(n: int) -> void:
	if n <= 0:
		return
	points += n
	_save()

## Takes `n` points, session points first. False, and nothing taken, when `n` is negative or more than is held.
func spend(n: int) -> bool:
	if not _take(n):
		return false
	_save()
	return true

## Pays the next price of `def` and counts the purchase, in one save. False when the points are short.
func buy_perk(def: PerkDef) -> bool:
	if not _take(def.price_of(perk_count(def.id))):
		return false
	perks[def.id] = perk_count(def.id) + 1
	_save()
	return true

func perk_count(id: String) -> int:
	return int(perks.get(id, 0))

func note_death() -> void:
	deaths += 1
	_save()

func _take(n: int) -> bool:
	if n < 0 or n > total_points():
		return false
	var from_session := mini(n, session_points)
	session_points -= from_session
	points -= n - from_session
	return true

static func _count(value) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return maxi(0, int(value))
	return 0

func _save() -> void:
	if profile == null:
		return
	var saved_perks := _unknown_perks.duplicate()
	saved_perks.merge(perks, true)
	profile.set_section("soul", {"points": points, "perks": saved_perks, "deaths": deaths})
	profile.save()
