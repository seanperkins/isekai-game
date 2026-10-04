class_name StatusText
extends RefCounted
## Pure text builders for the status screen, the inspect panel and the HUD.
## Progress toward hidden skills is only ever shown as a band, never as numbers.

static func self_lines(stats: Stats, health: Health, rules, compendium: CompendiumModel, appraisal_level: int) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("HP %d/%d" % [health.hp, health.max_hp])
	for key in ["atk", "def", "spd"]:
		var line := "%s %d" % [key.to_upper(), stats.get_stat(key)]
		var parts: Array = []
		if stats.eat_bonus(key) != 0:
			parts.append("%+d eat" % stats.eat_bonus(key))
		if stats.skill_bonus(key) != 0:
			parts.append("%+d skill" % stats.skill_bonus(key))
		if not parts.is_empty():
			line += " (%s)" % ", ".join(parts)
		lines.append(line)
	lines.append("Skills:")
	var ids: Array = rules.owned()
	ids.sort()
	for id in ids:
		lines.append("  %s Lv%d" % [rules.get_def(id).display_name, rules.level_of(id)])
	var essences: Array = []
	for ess in Essences.ALL:
		var n: int = rules.held(ess)
		if n > 0:
			essences.append("%s %d" % [ess, n])
	lines.append("Essences: " + (", ".join(essences) if not essences.is_empty() else "none"))
	var report := compendium.self_report(appraisal_level, rules)
	for h in report["hints"]:
		var line := "  %s — %s" % [h["name"], "it's close" if h["band"] == CompendiumModel.BAND_CLOSE else "something stirs"]
		if h.has("hint") and h["hint"] != "":
			line += " (%s)" % h["hint"]
		lines.append(line)
	for e in report["evolutions"]:
		lines.append("  Something could become %s…" % e["name"])
	return lines

static func creature_lines(report: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	if report.is_empty():
		lines.append("Nothing to appraise.")
		return lines
	lines.append(report["name"])
	lines.append("HP %d" % report["hp"])
	if report.has("stats") and not report["stats"].is_empty():
		var s: Dictionary = report["stats"]
		lines.append("ATK %d  DEF %d  SPD %d" % [s.get("atk", 0), s.get("def", 0), s.get("spd", 0)])
	if report.has("essences"):
		var parts: Array = []
		for ess in Essences.ALL:  # canonical order; .tres files store dictionary keys sorted
			if report["essences"].has(ess):
				parts.append("%s %d" % [ess, report["essences"][ess]])
		lines.append("Essences: " + ", ".join(parts))
	if report.has("eat_bonus") and not report["eat_bonus"].is_empty():
		var b: Dictionary = report["eat_bonus"]
		var per := int(b.get("per", 1))
		lines.append("Eat bonus: %+d %s%s" % [b["amount"], b["stat"], "" if per == 1 else " per %d eaten" % per])
	if report.has("skills"):
		var parts: Array = []
		for sk in report["skills"]:
			parts.append("%s Lv%d" % [sk["id"], sk["level"]])
		lines.append("Skills: " + ", ".join(parts))
	return lines

## `labels` are the four slot buttons for the current device, e.g. U/O/H/L or LB/RB/LT/RT.
static func slot_line(slots: ActiveSlots, rules, labels: Array = ["U", "O", "H", "L"]) -> String:
	var parts: Array = []
	for i in slots.slots.size():
		var id: String = slots.slots[i]
		var name: String = rules.get_def(id).display_name if id != "" and rules.get_def(id) != null else "—"
		parts.append("[%s] %s" % [labels[i], name])
	return "  ".join(parts)

static func ticker_text(entry: Dictionary, rules) -> String:
	match entry.get("kind", ""):
		"level":
			return "%s Lv%d" % [_name(entry["id"], rules), entry["level"]]
		"slot_replaced":
			return "%s replaced %s" % [_name(entry["new_id"], rules), _name(entry["old_id"], rules)]
		"note":
			return str(entry.get("text", ""))
	return ""

static func _name(id: String, rules) -> String:
	var d = rules.get_def(id)
	return d.display_name if d != null else id
