class_name OpeningModel
extends RefCounted
## The opening's truck dodge as pure state: a truck's prompt and the choices, then the chosen choice's line while it hits, then the
## next truck, until the last result is acknowledged. The first Dodge always works: that round is not used up, a second truck
## arrives and stays, and the round is played again. In the last round an old lady is in the road, every command but saving her is
## grayed out, and saving her is the way it ends. The scene (OpeningScene) only draws and drives it. Nothing here can fail: every
## choice leads to the same end.

enum Phase { PROMPT, RESULT, DONE }

## The choice id whose first use always works.
const DODGE_ID := "dodge"

var phase := Phase.PROMPT

var _def: OpeningDef
var _truck := 0
var _row := 0
var _chosen := ""
var _free := false  # the dodge now showing cannot fail
var _doubled := false  # the second truck has arrived and stays
var _arrival := false  # this round is the one replayed after the free dodge

## A def with no trucks or no choices has nothing to play, so it starts done.
func _init(p_def: OpeningDef) -> void:
	_def = p_def
	if _def.trucks.is_empty() or _def.choices.is_empty():
		phase = Phase.DONE
	_reset_row()

func truck() -> int:
	return _truck

func truck_count() -> int:
	return _def.trucks.size()

## One truck on the street, or two once the first dodge has brought the second.
func trucks_on_screen() -> int:
	return 2 if _doubled else 1

## Whether the old lady is in the road: the last round, when the def has her.
func grandma_here() -> bool:
	return phase != Phase.DONE and not _def.grandma.is_empty() and _truck == _def.trucks.size() - 1

## The current round's prompt ("" once done); it stays through the result, while the trucks hit. The old lady's round shows her
## line, the replayed round shows the second truck's arrival.
func prompt() -> String:
	if phase == Phase.DONE:
		return ""
	if grandma_here() and str(_def.grandma.get("prompt", "")).strip_edges() != "":
		return str(_def.grandma["prompt"])
	if _arrival and _def.second_truck.strip_edges() != "":
		return _def.second_truck
	return str((_def.trucks[_truck] as Dictionary).get("prompt", ""))

## The choice labels while a prompt shows (with the old lady's last when she is there); nothing at any other time.
func rows() -> Array:
	var out: Array = []
	if phase != Phase.PROMPT:
		return out
	for c in _def.choices:
		out.append(str((c as Dictionary).get("label", "")))
	if grandma_here():
		out.append(str(_def.grandma.get("label", "")))
	return out

## Whether row `i` can be taken: all of them, except that with the old lady there only hers can.
func enabled(i: int) -> bool:
	if phase != Phase.PROMPT:
		return false
	if grandma_here():
		return i == _def.choices.size()
	return i >= 0 and i < _def.choices.size()

func row() -> int:
	return _row

## Moves the highlighted choice, stopping at the ends; ignored unless a prompt shows, and ignored while the old lady is there (the
## highlight sits on the one thing you can do).
func move(step: int) -> void:
	if phase == Phase.PROMPT and not grandma_here():
		_row = clampi(_row + step, 0, _def.choices.size() - 1)

## Enter. A prompt takes the highlighted choice and shows its result; a result moves on: after a free dodge the same round is played
## again with a second truck, otherwise it is the next round, or the end after the last. False only when it is already done.
func act() -> bool:
	match phase:
		Phase.PROMPT:
			if grandma_here():
				_chosen = str(_def.grandma.get("id", "grandma"))
			else:
				_chosen = str((_def.choices[_row] as Dictionary).get("id", ""))
			_free = _chosen == DODGE_ID and not _doubled and not grandma_here()
			phase = Phase.RESULT
			return true
		Phase.RESULT:
			if _free:
				_free = false
				_doubled = true
				_arrival = true
				phase = Phase.PROMPT
			elif _truck + 1 >= _def.trucks.size():
				phase = Phase.DONE
			else:
				_truck += 1
				_arrival = false
				phase = Phase.PROMPT
			_reset_row()
			return true
	return false

## The id of the choice taken against this truck.
func chosen() -> String:
	return _chosen

## Whether the choice taken is the old lady's, whatever her id is.
func grandma_chosen() -> bool:
	return grandma_here() and _chosen == str(_def.grandma.get("id", "grandma"))

## Whether the result showing is the dodge that cannot fail.
func free_dodge() -> bool:
	return _free and phase == Phase.RESULT

## What happens to the player, while the result shows ("" at any other time).
func result_line() -> String:
	if phase != Phase.RESULT:
		return ""
	if _free and _def.dodge_success.strip_edges() != "":
		return _def.dodge_success
	if grandma_chosen():
		var line := str(_def.grandma.get("result", ""))
		return line if line.strip_edges() != "" else _def.fallback
	return _def.result_for(_truck, _chosen)

func done() -> bool:
	return phase == Phase.DONE

func _reset_row() -> void:
	_row = _def.choices.size() if grandma_here() else 0
