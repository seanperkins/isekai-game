class_name Mana
extends RefCounted
## MP pool. Regenerates 1 MP per second scaled by a percent rate (the mp_regen stat);
## fractions accumulate between frames.

signal changed(mp: int, max_mp: int)

const BASE_REGEN_PER_SECOND := 1.0

var mp: int
var max_mp: int
var _acc := 0.0

func _init(p_max_mp: int) -> void:
	max_mp = maxi(0, p_max_mp)
	mp = max_mp

func spend(cost: int) -> bool:
	if cost > mp:
		return false
	mp -= cost
	changed.emit(mp, max_mp)
	return true

func regen(delta: float, rate_percent: int) -> void:
	if mp >= max_mp:
		_acc = 0.0
		return
	_acc += delta * BASE_REGEN_PER_SECOND * rate_percent / 100.0
	var whole := int(floor(_acc + 0.0001))
	if whole > 0:
		_acc -= whole
		mp = mini(max_mp, mp + whole)
		changed.emit(mp, max_mp)

func restore(amount: int) -> void:
	mp = mini(max_mp, mp + amount)
	changed.emit(mp, max_mp)

## Raising max MP doesn't raise current MP; lowering it clamps.
func set_max_mp(value: int) -> void:
	max_mp = maxi(0, value)
	mp = mini(mp, max_mp)
	changed.emit(mp, max_mp)
