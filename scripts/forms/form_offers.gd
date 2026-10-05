class_name FormOffers
extends RefCounted
## Which bodies a species is offered when it can evolve. Pure functions over data.
##   Stage 1 to 2, the slime: every lineage whose offer threshold its diet has met (offered_lineages), in LINEAGE_ORDER, plus the
##     Greater Slime fallback when fewer than two are offered. No ranking and no cap.
##   Stage 1 to 2, any other species: its stage-2 forms whose gates the run has met (FormGate).
##   Stage 2 to 3: the form's two children, the slime's always, another species' when their gates are met. Stage 3 to 4: the
##   lineage's Sovereign, or its two stage-4 forms the same way. Stage 4: none.
## `locked` is the other half: the candidates whose gates are not met, for the Form tab to show with what is missing.

const LINEAGE_ORDER := ["weaver", "tide", "toxic", "bulwark", "echo"]
const FALLBACK := "greater_slime"
const GREATER := "greater"

## The lineages of a species in the order the Tree tab lists them: the slime's six, or another species' own in form-id order.
static func lineage_order(forms: Dictionary, species := Form.DEFAULT_SPECIES) -> Array:
	if species == Form.DEFAULT_SPECIES:
		return LINEAGE_ORDER + [GREATER]
	var out: Array = []
	for f in FormLoader.stage2_forms(forms, species):
		if not out.has((f as FormDef).lineage):
			out.append((f as FormDef).lineage)
	return out

## The slime's lineage -> the skill ids that open it, read from the stage-2 forms (the Greater lineage opens on nothing).
static func lineage_powers(forms: Dictionary) -> Dictionary:
	var out := {}
	for f in FormLoader.stage2_forms(forms):
		if (f as FormDef).lineage != "greater":
			out[(f as FormDef).lineage] = (f as FormDef).powers
	return out

## Each owned power of a lineage counts this much towards every element of its thresholds. Powers help; they never gate alone.
const POWER_BONUS := 3

## The slime's lineages its diet has revealed this life, in LINEAGE_ORDER: what it has absorbed, with a little help from the
## lineage's owned powers, meets the lineage form's `reveal`. `rules.level_of` keeps answering the level a retired parent reached,
## so an evolved power still counts as owned.
static func revealed_lineages(forms: Dictionary, rules) -> Array:
	return _lineages_meeting(forms, rules, false)

## The lineages on the stage-2 menu: revealed, and the diet meets the higher `offer` as well.
static func offered_lineages(forms: Dictionary, rules) -> Array:
	return _lineages_meeting(forms, rules, true)

## The Tree tab's name for the revealed lineages.
static func open_lineages(forms: Dictionary, rules) -> Array:
	return revealed_lineages(forms, rules)

static func _lineages_meeting(forms: Dictionary, rules, offer: bool) -> Array:
	var out: Array = []
	for l in LINEAGE_ORDER:
		for f in FormLoader.stage2_forms(forms):
			if (f as FormDef).lineage == l and _meets(f, rules, offer):
				out.append(l)
	return out

static func _meets(f: FormDef, rules, offer: bool) -> bool:
	var need: Dictionary = f.offer if offer else f.reveal
	if need.is_empty():
		return false
	var owned := 0
	for p in f.powers:
		if rules.level_of(p) > 0:
			owned += 1
	for e in need:
		if rules.absorbed(e) + POWER_BONUS * owned < int(need[e]):
			return false
	return true

## The form ids on offer for `form` (a Form), given the rules state.
static func offers(forms: Dictionary, form: Form, rules) -> Array:
	if form.stage == 1:
		return _first_offers(forms, form.species, rules)
	var out: Array = []
	for k in FormLoader.children_of(forms, form.form_id):
		if form.species == Form.DEFAULT_SPECIES or FormGate.met(k, rules):
			out.append((k as FormDef).id)
	return out

## The forms `form` could grow into whose gates are not met yet. The slime's forms have no gate (its lineages use `reveal` and `offer`), so
## nothing of the slime's is ever locked.
static func locked(forms: Dictionary, form: Form, rules) -> Array:
	var candidates: Array = FormLoader.stage2_forms(forms, form.species) if form.stage == 1 else FormLoader.children_of(forms, form.form_id)
	return candidates.filter(func(f: FormDef) -> bool: return not FormGate.met(f, rules))

static func _first_offers(forms: Dictionary, species: String, rules) -> Array:
	if species != Form.DEFAULT_SPECIES:
		return FormLoader.stage2_forms(forms, species).filter(func(f: FormDef) -> bool: return FormGate.met(f, rules)).map(func(f: FormDef) -> String: return f.id)
	var out := offered_lineages(forms, rules)
	if out.size() < 2 and forms.has(FALLBACK):
		out.append(FALLBACK)
	return out
