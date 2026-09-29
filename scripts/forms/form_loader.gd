class_name FormLoader
extends RefCounted
## Loads the form tree and answers questions about it.

static func load_all(dir := "res://data/forms") -> Dictionary:
	var out := {}
	for f in DefLoader.load_dir(dir, "FormDef"):
		out[f.id] = f
	return out

## The forms that list `id` among their parents, in id order.
static func children_of(forms: Dictionary, id: String) -> Array:
	var out: Array = []
	var ids := forms.keys()
	ids.sort()
	for k in ids:
		if (forms[k] as FormDef).parents.has(id):
			out.append(forms[k])
	return out

## The stage-2 forms (children of the base slime), in id order.
static func stage2_forms(forms: Dictionary) -> Array:
	return children_of(forms, Form.BASE)
