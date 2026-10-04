class_name OpeningModel
extends RefCounted
## The opening's truck dodge as pure state: a truck's prompt and the choices, then the chosen choice's line while it hits, then the
## next truck, until the last result is acknowledged. The scene (OpeningScene) only draws and drives it. Nothing here can fail:
## every choice leads to the same end.

enum Phase { PROMPT, RESULT, DONE }

var phase := Phase.PROMPT

var _def: OpeningDef
var _truck := 0
var _row := 0
var _chosen := ""

## A def with no trucks or no choices has nothing to play, so it starts done.
func _init(p_def: OpeningDef) -> void:
	_def = p_def
	if _def.trucks.is_empty() or _def.choices.is_empty():
		phase = Phase.DONE

func truck() -> int:
	return _truck

func truck_count() -> int:
	return _def.trucks.size()

## The current truck's prompt ("" once done); it stays through the result, while the truck hits.
func prompt() -> String:
	if phase == Phase.DONE:
		return ""
	return str((_def.trucks[_truck] as Dictionary).get("prompt", ""))

## The choice labels while a prompt shows; nothing at any other time.
func rows() -> Array:
	var out: Array = []
	if phase != Phase.PROMPT:
		return out
	for c in _def.choices:
		out.append(str((c as Dictionary).get("label", "")))
	return out

func row() -> int:
	return _row

## Moves the highlighted choice, stopping at the ends; ignored unless a prompt shows.
func move(step: int) -> void:
	if phase == Phase.PROMPT:
		_row = clampi(_row + step, 0, _def.choices.size() - 1)

## Enter. A prompt takes the highlighted choice and shows its result; a result moves to the next truck, or ends it after the last.
## False only when it is already done.
func act() -> bool:
	match phase:
		Phase.PROMPT:
			_chosen = str((_def.choices[_row] as Dictionary).get("id", ""))
			phase = Phase.RESULT
			return true
		Phase.RESULT:
			if _truck + 1 >= _def.trucks.size():
				phase = Phase.DONE
			else:
				_truck += 1
				_row = 0
				phase = Phase.PROMPT
			return true
	return false

## The id of the choice taken against this truck.
func chosen() -> String:
	return _chosen

## What happens to the player, while the result shows ("" at any other time).
func result_line() -> String:
	return _def.result_for(_truck, _chosen) if phase == Phase.RESULT else ""

func done() -> bool:
	return phase == Phase.DONE
