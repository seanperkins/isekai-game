class_name FormGate
extends RefCounted
## A form's gate read against the run's ledger. A gate is a list of atoms, all of which must hold. An atom is a condition like a
## skill's `unlock` (`counter`, `skill_level`) plus `held` (essence still held), `streak` (the best unbroken run of matching events this
## life: a gate that opened stays open, which a current run would not) and `any` (one of several), with a `text` the cards show:
## {"kind": "counter", "event": "defeated", "tags": {"behind": true}, "n": 5, "text": "kills from behind"}.

const KINDS := ["counter", "streak", "skill_level", "held", "any"]

static func met(def: FormDef, rules) -> bool:
	for atom in def.gate:
		if not _row(atom, rules)["met"]:
			return false
	return true

## One row per atom: {"text", "have", "need", "met"}, `have` never above `need`. An `any` atom shows its nearest member.
static func progress(def: FormDef, rules) -> Array:
	var out: Array = []
	for atom in def.gate:
		out.append(_row(atom, rules))
	return out

## What is still missing ("dark essence 8/26, kills from behind 2/5"), or "ready" when nothing is.
static func summary(def: FormDef, rules) -> String:
	var parts: PackedStringArray = []
	for row in progress(def, rules):
		if not row["met"]:
			parts.append("%s %d/%d" % [row["text"], row["have"], row["need"]])
	return ", ".join(parts) if not parts.is_empty() else "ready"

static func _row(atom: Dictionary, rules) -> Dictionary:
	if atom.get("kind", "") == "any":
		var best := {"have": 0, "need": 1, "met": false}
		var best_fraction := -1.0
		for member in atom.get("of", []):
			var row := _row(member, rules)
			var fraction := float(row["have"]) / float(maxi(1, row["need"]))
			if fraction > best_fraction:
				best = row
				best_fraction = fraction
		return {"text": atom.get("text", ""), "have": best["have"], "need": best["need"], "met": best["met"]}
	var need := int(atom.get("n", 1))
	var have: int = rules.condition_value(atom)
	return {"text": atom.get("text", ""), "have": mini(have, need), "need": need, "met": have >= need}

## The errors in a form's gate (without the form's id: FormValidator adds it).
static func validate(def: FormDef) -> PackedStringArray:
	var errs := PackedStringArray()
	for i in def.gate.size():
		_check(def.gate[i], "gate atom %d" % (i + 1), true, errs)
	return errs

static func _check(atom, where: String, needs_text: bool, errs: PackedStringArray) -> void:
	if typeof(atom) != TYPE_DICTIONARY:
		errs.append("%s is not a dictionary" % where)
		return
	var kind: String = atom.get("kind", "")
	if not KINDS.has(kind):
		errs.append("%s: unknown kind '%s'" % [where, kind])
		return
	if needs_text and str(atom.get("text", "")) == "":
		errs.append("%s: no text" % where)
	if kind == "any":
		var members: Array = atom.get("of", [])
		if members.is_empty():
			errs.append("%s: an any needs members" % where)
		for m in members:
			_check(m, where + " (member)", false, errs)
		return
	if int(atom.get("n", 0)) < 1:
		errs.append("%s: n must be at least 1" % where)
	match kind:
		"counter", "streak":
			var event: String = atom.get("event", "")
			if not Deeds.TAGS.has(event):
				errs.append("%s: unknown event '%s'" % [where, event])
			else:
				var tags = atom.get("tags", {})
				if typeof(tags) != TYPE_DICTIONARY:
					errs.append("%s: tags is not a dictionary" % where)
				else:
					for key in tags:
						if not (Deeds.TAGS[event] as Array).has(key):
							errs.append("%s: event '%s' has no tag '%s'" % [where, event, key])
			if kind == "streak" and atom.get("reset_on", "") != "" and not Deeds.known(atom["reset_on"]):
				errs.append("%s: resets on unknown event '%s'" % [where, atom["reset_on"]])
		"skill_level":
			if str(atom.get("id", "")) == "":
				errs.append("%s: a skill_level needs a skill id" % where)
		"held":
			if not Essences.ALL.has(atom.get("element", "")):
				errs.append("%s: held names unknown essence '%s'" % [where, atom.get("element", "")])
