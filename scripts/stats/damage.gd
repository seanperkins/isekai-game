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

## Thousandths of an HP: what a poison tick is counted in, so a resisted 1-point tick is a fraction to carry, not a zero.
const MILLI := 1000

## A poison tick in thousandths of an HP per second: Poison Resistance reaches 1-point ticks instead of deleting them.
static func tick_milli(raw: int, resist_pct: int) -> int:
	return floori(float(raw * (100 - clampi(resist_pct, 0, RESIST_CAP)) * MILLI) / 100.0)
