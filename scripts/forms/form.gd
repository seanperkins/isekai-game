class_name Form
extends RefCounted
## The player's body: which species, which stage and which form. advance() is the only way either changes.
## A species' base form (stage 1) has the species' own id, and is not a FormDef.

const STAGE_CAPS := [5, 8, 12, 15]
const SPECIES := ["slime", "wolf", "undead", "spider", "goblin"]
const DEFAULT_SPECIES := "slime"
## The slime's base form id: kept for the code that means the slime. Another species' base is its own id.
const BASE := DEFAULT_SPECIES

var species := DEFAULT_SPECIES
var stage := 1
var form_id := DEFAULT_SPECIES

func _init(p_species := DEFAULT_SPECIES) -> void:
	species = p_species
	form_id = p_species

## Whether `id` is a species' base form rather than an evolved form.
static func is_base(id: String) -> bool:
	return SPECIES.has(id)

## Moves to `id` if it is a legal next step: a stage-2 form of this species from its base, or a child of the current
## form. Anything else changes nothing and returns false.
func advance(id: String, forms: Dictionary) -> bool:
	var f: FormDef = forms.get(id)
	if f == null or f.species != species or f.stage != stage + 1 or not f.parents.has(form_id):
		return false
	stage = f.stage
	form_id = id
	return true

## The highest level a skill may reach at this stage.
func cap() -> int:
	return STAGE_CAPS[clampi(stage, 1, STAGE_CAPS.size()) - 1]

func reset() -> void:
	stage = 1
	form_id = species
