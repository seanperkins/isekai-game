class_name Form
extends RefCounted
## The player's body: which stage and which form. advance() is the only way either changes.

const STAGE_CAPS := [5, 8, 12, 15]
const BASE := "slime"

var stage := 1
var form_id := BASE

## Moves to `id` if it is a legal next step: a stage-2 form from the base slime, or a child of the current
## form. Anything else changes nothing and returns false.
func advance(id: String, forms: Dictionary) -> bool:
	var f: FormDef = forms.get(id)
	if f == null or f.stage != stage + 1 or not f.parents.has(form_id):
		return false
	stage = f.stage
	form_id = id
	return true

## The highest level a skill may reach at this stage.
func cap() -> int:
	return STAGE_CAPS[clampi(stage, 1, STAGE_CAPS.size()) - 1]

func reset() -> void:
	stage = 1
	form_id = BASE
