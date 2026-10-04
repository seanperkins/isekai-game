class_name FormOffers
extends RefCounted
## Which bodies the slime is offered when it can evolve. Pure functions over data.
##   Stage 1 to 2: every lineage whose power the player has reached (open_lineages), in LINEAGE_ORDER, plus the
##     Greater Slime fallback when fewer than two lineages are open. No ranking and no cap.
##   Stage 2 to 3: the form's two children. Stage 3 to 4: the lineage's one Sovereign. Stage 4: none.

const LINEAGE_ORDER := ["weaver", "tide", "toxic", "bulwark", "echo"]
const FALLBACK := "greater_slime"

## lineage -> the skill ids that open it, read from the stage-2 forms (the Greater lineage opens on nothing).
static func lineage_powers(forms: Dictionary) -> Dictionary:
	var out := {}
	for f in FormLoader.stage2_forms(forms):
		if (f as FormDef).lineage != "greater":
			out[(f as FormDef).lineage] = (f as FormDef).powers
	return out

## The lineages the player has opened this life, in LINEAGE_ORDER. A lineage is open when any of its powers has been reached:
## `rules.level_of` keeps answering the level a retired parent reached, so an evolved power still opens its lineage.
static func open_lineages(forms: Dictionary, rules) -> Array:
	var powers := lineage_powers(forms)
	var out: Array = []
	for l in LINEAGE_ORDER:
		if not powers.has(l) or not forms.has(l):
			continue
		for p in powers[l]:
			if rules.level_of(p) > 0:
				out.append(l)
				break
	return out

## The form ids on offer for `form` (a Form), given the rules state.
static func offers(forms: Dictionary, form: Form, rules) -> Array:
	if form.stage == 1:
		return _first_offers(forms, rules)
	var out: Array = []
	for k in FormLoader.children_of(forms, form.form_id):
		out.append((k as FormDef).id)
	return out

static func _first_offers(forms: Dictionary, rules) -> Array:
	var out := open_lineages(forms, rules)
	if out.size() < 2 and forms.has(FALLBACK):
		out.append(FALLBACK)
	return out
