class_name PartValidator
extends RefCounted
## Checks the part data so a broken part fails at startup and in tests.

const KINDS := ["graft", "held", "key"]

## `parts` is id -> PartDef.
static func validate(parts: Dictionary) -> PackedStringArray:
	var errs := PackedStringArray()
	for key in parts:
		var p: PartDef = parts[key]
		if p.id != key:
			errs.append("%s: id does not match its key" % key)
		if p.display_name == "":
			errs.append("%s: no name" % key)
		if p.text == "":
			errs.append("%s: no text" % key)
		if not KINDS.has(p.kind):
			errs.append("%s: unknown kind '%s'" % [key, p.kind])
			continue
		if p.kind == "graft":
			if p.slot == "":
				errs.append("%s: a graft needs a slot" % key)
			if p.worn_max < 1 or p.worn_max > 2:
				errs.append("%s: worn_max is 1 or 2, not %d" % [key, p.worn_max])
		elif p.slot != "":
			errs.append("%s: only a graft has a slot" % key)
		for s in p.stats:
			if not StatKeys.ALL.has(s):
				errs.append("%s: unknown stat '%s'" % [key, s])
	return errs
