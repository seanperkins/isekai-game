class_name RoomBarrier
extends RoomBlock
## A wall that opens three ways: the dissolve verb removes it at once (the group `dissolvable`, `dissolve()`: the verb says `barrier_broken`), and
## three tackles or hits break it (it says `barrier_broken` itself), so a form whose gate asks for barriers broken is not locked behind its own
## verb. It stands in front of a side room. Broken once in a life it is not built again that life (RoomFeatures.make asks the ledger).

## The blows that break it.
const HITS := 3
## How many loose pieces a broken wall leaves.
const RUBBLE_PIECES := 3

var team := "terrain"
var facing := 1
var _hits := 0

func setup(f: Dictionary, ctx: Dictionary) -> void:
	super.setup(f, ctx)
	add_to_group("dissolvable")
	add_to_group("actors")  # tackles and skills find it, as they find the shortcut stone; it never reports a stun

## The verb says the deed, with this node's id.
func dissolve() -> void:
	remove_from_group("dissolvable")
	_leave_rubble()
	queue_free()

## A broken wall leaves loose rubble where it stood.
func _leave_rubble() -> void:
	var host := get_parent()
	if host == null:
		return
	for i in RUBBLE_PIECES:
		var rock := Rubble.new()
		host.add_child(rock)
		rock.global_position = global_position + Vector2((float(i) - 1.0) * 10.0, size.y / 2.0)

func receive_tackle(_atk: int, _from_behind: bool, _from: Vector2 = Vector2.INF) -> bool:
	_struck()
	return false

func receive_hit(_raw: int, _damage_type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
	_struck()

func _struck() -> void:
	_hits += 1
	if _hits >= HITS:
		report(Deeds.BARRIER_BROKEN)
		remove_from_group("dissolvable")
		remove_from_group("actors")
		_leave_rubble()
		queue_free()
