class_name Health
extends RefCounted
## HP with low-HP bands. Emits gameplay events only when emit_event is set, which only
## the player does (actor boundary). DoT ticks never emit and never take HP below 1.

signal changed(hp: int, max_hp: int)
signal died

const LOW_ENTER_PERCENT := 30
const LOW_EXIT_PERCENT := 60

var hp: int
var max_hp: int
var emit_event: Callable = Callable()
var _low := false
var _dead := false

func _init(p_max_hp: int) -> void:
	max_hp = maxi(1, p_max_hp)
	hp = max_hp

func take_hit(amount: int, damage_type: String) -> void:
	if _dead:
		return
	hp = maxi(0, hp - amount)
	_emit(Events.DAMAGED, {"damage_type": damage_type})
	_after_change()

func take_tick(amount: int) -> void:
	if _dead:
		return
	hp = maxi(mini(hp, 1), hp - amount)
	_after_change()

func heal(amount: int) -> void:
	if _dead:
		return
	hp = mini(max_hp, hp + amount)
	_after_change()

func set_max_hp(value: int) -> void:
	max_hp = maxi(1, value)
	hp = mini(hp, max_hp)
	_after_change()

func is_dead() -> bool:
	return _dead

func is_low() -> bool:
	return _low

func _after_change() -> void:
	if hp > 0:
		if not _low and hp * 100 < max_hp * LOW_ENTER_PERCENT:
			_low = true
			_emit(Events.HP_LOW_ENTERED, {})
		elif _low and hp * 100 >= max_hp * LOW_EXIT_PERCENT:
			_low = false
			_emit(Events.HP_LOW_EXITED, {})
	changed.emit(hp, max_hp)
	if hp <= 0 and not _dead:
		_dead = true
		died.emit()

func _emit(event_name: String, tags: Dictionary) -> void:
	if emit_event.is_valid():
		emit_event.call(event_name, tags)
