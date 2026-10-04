class_name FormValidator
extends RefCounted
## Checks the form tree data so a broken form fails at startup and in tests, not mid-run.

const LINEAGES := ["weaver", "tide", "toxic", "bulwark", "echo", "greater"]

## `check_art` also requires every form's sprite set to have its sheet (the art tests turn it on).
static func validate(forms: Dictionary, skill_ids: Array, check_art := false) -> PackedStringArray:
	var errs := PackedStringArray()
	for id in forms:
		var f: FormDef = forms[id]
		if f.id != id:
			errs.append("%s: id does not match its key" % id)
		if f.stage < 2 or f.stage > 4:
			errs.append("%s: stage %d is outside 2..4" % [id, f.stage])
		if not LINEAGES.has(f.lineage):
			errs.append("%s: unknown lineage '%s'" % [id, f.lineage])
		if f.parents.is_empty():
			errs.append("%s: no parents" % id)
		for p in f.parents:
			if p == Form.BASE:
				if f.stage != 2:
					errs.append("%s: only stage-2 forms grow from the base slime" % id)
			elif not forms.has(p):
				errs.append("%s: unknown parent '%s'" % [id, p])
			elif (forms[p] as FormDef).stage != f.stage - 1:
				errs.append("%s: parent '%s' is not one stage below" % [id, p])
		for s in f.stats:
			if not StatKeys.ALL.has(s):
				errs.append("%s: unknown stat '%s'" % [id, s])
		for g in f.grants:
			if not skill_ids.has(g):
				errs.append("%s: grants unknown skill '%s'" % [id, g])
		for t in f.traits:
			if not FormEffects.TRAITS.has(t):
				errs.append("%s: unknown trait '%s'" % [id, t])
		if f.stage == 2 and f.lineage != "greater":
			if f.powers.is_empty():
				errs.append("%s: a lineage form needs at least one opening power" % id)
		elif not f.powers.is_empty():
			errs.append("%s: only stage-2 lineage forms list powers" % id)
		for p in f.powers:
			if not skill_ids.has(p):
				errs.append("%s: lists unknown power '%s'" % [id, p])
		if f.size < 1.0 or f.size > 1.5:
			errs.append("%s: size %.2f outside 1.0..1.5" % [id, f.size])
		for c in [f.tint.r, f.tint.g, f.tint.b]:
			if c < 0.0 or c > 1.0:
				errs.append("%s: tint outside 0..1" % id)
				break
		if check_art and f.sprite_set != "" and not SpriteSheet.available(f.sprite_set):
			errs.append("%s: sprite set '%s' has no sheet" % [id, f.sprite_set])
	return errs
