class_name OpeningValidator
extends RefCounted
## Checks the opening's data: the choices, the trucks and what each choice does to each, the fallback and her first words. An empty
## result means the data is safe to play. Counts are data (a test pins the shipped copy's three trucks and five choices), so any
## number of each is fine. Every entry is type-checked: a hand-edited file must be named, never crash the scene.

static func validate(def: OpeningDef) -> PackedStringArray:
	var out := PackedStringArray()
	if def == null:
		out.append("opening: no data")
		return out
	var ids := _choice_errors(def.choices, out)
	_truck_errors(def.trucks, ids, out)
	_grandma_errors(def.grandma, def.choices, out)
	if def.fallback.strip_edges() == "":
		out.append("opening: fallback is blank")
	if def.goddess_line.strip_edges() == "":
		out.append("opening: goddess_line is blank")
	return out

## The old lady's entry is optional (empty means none); when it is there it names a row of its own.
static func _grandma_errors(grandma: Dictionary, choices: Array, out: PackedStringArray) -> void:
	if grandma.is_empty():
		return
	for key in ["id", "label", "prompt", "result"]:
		var value = grandma.get(key)
		if typeof(value) != TYPE_STRING or value.strip_edges() == "":
			out.append("opening: grandma needs a non-blank string id, label, prompt and result")
			return
	for c in choices:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		if c.get("id") == grandma["id"]:
			out.append("opening: grandma id '%s' is also a choice" % grandma["id"])
		if c.get("label") == grandma["label"]:
			out.append("opening: grandma label '%s' is also a choice label" % grandma["label"])

## Reports the choices' mistakes into `out` and returns the ids that are usable, for the trucks to check against.
static func _choice_errors(choices: Array, out: PackedStringArray) -> Array:
	var ids: Array = []
	if choices.is_empty():
		out.append("opening: choices must be a non-empty list")
		return ids
	if choices.size() > OpeningDef.MAX_CHOICES:
		out.append("opening: at most %d choices fit on the screen" % OpeningDef.MAX_CHOICES)
	var labels: Array = []
	for i in choices.size():
		var c = choices[i]
		if typeof(c) != TYPE_DICTIONARY:
			out.append("opening: choice %d must be a Dictionary" % i)
			continue
		var id = c.get("id")
		var label = c.get("label")
		if typeof(id) != TYPE_STRING or typeof(label) != TYPE_STRING or id.strip_edges() == "" or label.strip_edges() == "":
			out.append("opening: choice %d needs a non-blank string id and label" % i)
			continue
		if ids.has(id):
			out.append("opening: duplicate choice id '%s'" % id)
		if labels.has(label):
			out.append("opening: duplicate choice label '%s'" % label)
		ids.append(id)
		labels.append(label)
	return ids

static func _truck_errors(trucks: Array, ids: Array, out: PackedStringArray) -> void:
	if trucks.is_empty():
		out.append("opening: trucks must be a non-empty list")
		return
	for i in trucks.size():
		var t = trucks[i]
		if typeof(t) != TYPE_DICTIONARY:
			out.append("opening: truck %d must be a Dictionary" % i)
			continue
		var prompt = t.get("prompt")
		if typeof(prompt) != TYPE_STRING or prompt.strip_edges() == "":
			out.append("opening: truck %d needs a non-blank prompt" % i)
		var results = t.get("results")
		if typeof(results) != TYPE_DICTIONARY:
			out.append("opening: truck %d results must be a Dictionary" % i)
			continue
		for id in results:
			if not ids.has(id):
				out.append("opening: truck %d results name '%s', which is not a choice" % [i, str(id)])
			var line = results[id]
			if typeof(line) != TYPE_STRING or line.strip_edges() == "":
				out.append("opening: truck %d result '%s' needs a non-blank string line" % [i, str(id)])
