class_name FormValidator
extends RefCounted
## Checks the form tree data so a broken form fails at startup and in tests, not mid-run.

## The slime's lineages. Another species names its own: any non-empty id, shared by a stage-2 form and all its descendants.
const LINEAGES := ["weaver", "tide", "toxic", "bulwark", "echo", "greater"]
## Whether a slime lineage form must carry a reveal and an offer.
const REQUIRE_GATES := true
## The areas a form may be found in: the four built and the eight planned.
const AREAS := ["cave", "grotto", "flooded", "deep", "forest", "swamp", "village", "sacred", "cemetery", "crypt", "volcano", "demon"]

## `check_art` also requires every form's sprite set to have its sheet (the art tests turn it on). `verb_ids` are the ids of the
## form_verb skills, which a form's `verb` must be one of.
static func validate(forms: Dictionary, skill_ids: Array, check_art := false, verb_ids: Array = []) -> PackedStringArray:
	var errs := PackedStringArray()
	for id in forms:
		var f: FormDef = forms[id]
		if f.id != id:
			errs.append("%s: id does not match its key" % id)
		if not Form.SPECIES.has(f.species):
			errs.append("%s: unknown species '%s'" % [id, f.species])
			continue
		if f.stage < 2 or f.stage > 4:
			errs.append("%s: stage %d is outside 2..4" % [id, f.stage])
		if f.species == Form.DEFAULT_SPECIES:
			if not LINEAGES.has(f.lineage):
				errs.append("%s: unknown lineage '%s'" % [id, f.lineage])
		elif f.lineage == "":
			errs.append("%s: no lineage" % id)
		if f.parents.is_empty():
			errs.append("%s: no parents" % id)
		for p in f.parents:
			if Form.is_base(p):
				if p != f.species:
					errs.append("%s: parent '%s' is another species' base" % [id, p])
				elif f.stage != 2:
					errs.append("%s: only stage-2 forms grow from the base %s" % [id, f.species])
			elif not forms.has(p):
				errs.append("%s: unknown parent '%s'" % [id, p])
			elif (forms[p] as FormDef).species != f.species:
				errs.append("%s: parent '%s' is a %s form" % [id, p, (forms[p] as FormDef).species])
			elif (forms[p] as FormDef).stage != f.stage - 1:
				errs.append("%s: parent '%s' is not one stage below" % [id, p])
			elif f.stage > 2 and (forms[p] as FormDef).lineage != f.lineage:
				errs.append("%s: lineage '%s' differs from its parent's '%s'" % [id, f.lineage, (forms[p] as FormDef).lineage])
		for s in f.stats:
			if not StatKeys.ALL.has(s):
				errs.append("%s: unknown stat '%s'" % [id, s])
		for g in f.grants:
			if not skill_ids.has(g):
				errs.append("%s: grants unknown skill '%s'" % [id, g])
		if f.verb != "":
			if not verb_ids.has(f.verb):
				errs.append("%s: verb '%s' is not a form_verb skill" % [id, f.verb])
			if not f.grants.has(f.verb):
				errs.append("%s: verb '%s' must be in its grants" % [id, f.verb])
		for t in f.traits:
			if not FormEffects.TRAITS.has(t):
				errs.append("%s: unknown trait '%s'" % [id, t])
		# Only the slime's lineages open by powers; another species' stage-2 forms may list powers or none (their gates are A3 and B1).
		var lists_powers_ok: bool = f.stage == 2 and (f.species != Form.DEFAULT_SPECIES or f.lineage != "greater")
		if f.stage == 2 and f.species == Form.DEFAULT_SPECIES and f.lineage != "greater" and f.powers.is_empty():
			errs.append("%s: a lineage form needs at least one opening power" % id)
		elif not f.powers.is_empty() and not lists_powers_ok:
			errs.append("%s: only stage-2 lineage forms list powers" % id)
		for p in f.powers:
			if not skill_ids.has(p):
				errs.append("%s: lists unknown power '%s'" % [id, p])
		_check_gate(f, errs)
		for e in f.reads:
			if not Essences.ALL.has(e):
				errs.append("%s: reads unknown essence '%s'" % [id, e])
		for a in f.host:
			if not AREAS.has(a):
				errs.append("%s: host names unknown area '%s'" % [id, a])
		if f.size < 1.0 or f.size > 1.5:
			errs.append("%s: size %.2f outside 1.0..1.5" % [id, f.size])
		for c in [f.tint.r, f.tint.g, f.tint.b]:
			if c < 0.0 or c > 1.0:
				errs.append("%s: tint outside 0..1" % id)
				break
		if check_art and f.sprite_set != "" and not SpriteSheet.available(f.sprite_set):
			errs.append("%s: sprite set '%s' has no sheet" % [id, f.sprite_set])
	return errs

## The reveal and offer thresholds of a lineage form: known elements, positive amounts, the same elements, offer at least reveal.
static func _check_gate(f: FormDef, errs: PackedStringArray) -> void:
	var gated := not f.reveal.is_empty() or not f.offer.is_empty()
	var can_gate: bool = f.stage == 2 and (f.species != Form.DEFAULT_SPECIES or f.lineage != "greater")
	if gated and not can_gate:
		errs.append("%s: only a stage-2 lineage form carries a reveal and an offer" % f.id)
		return
	if not gated:
		if REQUIRE_GATES and can_gate and f.species == Form.DEFAULT_SPECIES:
			errs.append("%s: a lineage form needs a reveal and an offer" % f.id)
		return
	for kind in ["reveal", "offer"]:
		var d: Dictionary = f.reveal if kind == "reveal" else f.offer
		for e in d:
			if not Essences.ALL.has(e):
				errs.append("%s: %s names unknown essence '%s'" % [f.id, kind, e])
			elif int(d[e]) <= 0:
				errs.append("%s: %s of '%s' must be positive" % [f.id, kind, e])
	var a := f.reveal.keys()
	var b := f.offer.keys()
	a.sort()
	b.sort()
	if a != b:
		errs.append("%s: offer must name the same elements as its reveal" % f.id)
		return
	for e in f.reveal:
		if int(f.offer[e]) < int(f.reveal[e]):
			errs.append("%s: offer of '%s' is below its reveal" % [f.id, e])
