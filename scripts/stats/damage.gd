class_name Damage
extends RefCounted
## Damage math in integer arithmetic: percent reductions, then flat reductions, then floor.

## Direct hits: DEF and other flat reductions apply; always at least 1.
static func direct_hit(raw: int, percent_off: int, flat_off: int) -> int:
	var p := clampi(percent_off, 0, 100)
	return maxi(1, floori(float(raw * (100 - p) - flat_off * 100) / 100.0))

## DoT ticks: percent reductions only; may reach 0.
static func tick(raw: int, percent_off: int) -> int:
	var p := clampi(percent_off, 0, 100)
	return maxi(0, floori(float(raw * (100 - p)) / 100.0))
