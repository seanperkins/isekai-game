class_name Damage
extends RefCounted
## Damage math in integer arithmetic: percent reductions, then flat reductions, then floor.

## Armor's weight against the size of the hit: DEF is a percent of the hit, never 100%.
const ARMOR_PER_HIT := 80
## The most any resistance percent can take off a hit or a tick.
const RESIST_CAP := 95

## DEF as a percent of the hit's size: never 100%, no plateau. Physical hits only (see hit()).
static func armor_pct(defense: int, power: int) -> int:
	if defense <= 0 or power <= 0:
		return 0
	return floori(10000.0 * defense / (100 * defense + ARMOR_PER_HIT * power))

## One resolution for every hit: armor (physical only) and resistance multiply, then the flat reductions subtract; at least 1.
static func hit(power: int, damage_type: String, defense: int, resist_pct: int, flat_off: int) -> int:
	var armor := armor_pct(defense, power) if damage_type == "physical" else 0
	var through := (100 - armor) * (100 - clampi(resist_pct, 0, RESIST_CAP))
	return maxi(1, floori(float(power * through) / 10000.0) - flat_off)

## DoT ticks: percent reductions only; may reach 0.
static func tick(raw: int, percent_off: int) -> int:
	var p := clampi(percent_off, 0, 100)
	return maxi(0, floori(float(raw * (100 - p)) / 100.0))
