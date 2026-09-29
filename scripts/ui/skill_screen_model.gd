class_name SkillScreenModel
extends RefCounted
## Pure data for the Skills / Compendium screen.

const GROUPS := [["PROFICIENCY", "proficiency"], ["ESSENCE", "essence"], ["EVOLUTION", "evolution"]]
const ACTIVE_LABEL := {"poison_breath": "Damage", "water_blade": "Damage",
	"hydraulic_propulsion": "Distance %", "sticky_thread": "Hold tier",
	"swing_thread": "Hold tier"}
const STAT_LABEL := {"max_hp": "Max HP", "atk": "ATK", "def": "DEF", "spd": "SPD",
	"jump_height": "Jump height", "slide_speed": "Slide speed", "predation_time": "Eat time",
	"max_mp": "Max MP", "mp_regen": "MP regen"}
const EVENT_TEXT := {"jumped": "Jump", "wall_touched": "Touch a wall mid-air",
	"hp_low_exited": "Recover from low HP", "predated": "Eat creatures", "mana_spent": "Spend MP",
	"inspected": "Appraise", "skill_used": "Use the skill", "stunned_enemy": "Stun enemies"}

## Skills tab: owned skills per group, plus one "???" row where unowned, non-secret skills remain.
static func skill_rows(rules, all_defs: Array) -> Array:
	var rows: Array = []
	for g in GROUPS:
		rows.append({"kind": "header", "text": g[0]})
		var locked := false
		for d in _sorted(all_defs):
			if d.source != g[1]:
				continue
			if rules.level_of(d.id) > 0:
				rows.append({"kind": "skill", "id": d.id, "name": d.display_name,
					"level": rules.level_of(d.id), "max_level": d.max_level})
			elif not d.secret and not rules.is_evolution_ready(d.id):
				locked = true
		if g[1] == "evolution":
			for id in rules.ready_evolutions():
				var d = _find(all_defs, id)
				if d != null:
					rows.append({"kind": "ready", "id": id, "name": d.display_name, "cost": rules.evolution_cost(id)})
		if locked:
			rows.append({"kind": "locked"})
	return rows

static func _find(defs: Array, id: String):
	for d in defs:
		if d.id == id:
			return d
	return null

## Compendium tab: every slot at its discovery state. Exact conditions only once owned.
static func compendium_rows(compendium: CompendiumModel, all_defs: Array) -> Array:
	var by_id := {}
	for d in all_defs:
		by_id[d.id] = d
	var rows: Array = []
	for g in GROUPS:
		rows.append({"kind": "header", "text": g[0]})
		for d in _sorted(all_defs):
			if d.source != g[1]:
				continue
			var state := compendium.state(d.id)
			var row := {"kind": "slot", "id": d.id, "state": state,
				"name": "???" if state == CompendiumModel.State.UNKNOWN else d.display_name}
			if state >= CompendiumModel.State.HINTED and d.hint != "":
				row["hint"] = d.hint
			if state == CompendiumModel.State.OWNED_ONCE:
				row["condition"] = condition_text(d, by_id)
				if d.hint != "":
					row["hint"] = d.hint
			rows.append(row)
	return rows

## Bestiary tab: every creature, named once seen, with how far you've got with it.
static func bestiary_rows(compendium: CompendiumModel) -> Array:
	var rows: Array = [{"kind": "header", "text": "CREATURES"}]
	for id in compendium.bestiary_ids():
		var rec := compendium.creature_record(id)
		rows.append({"kind": "creature", "id": id, "seen": rec["seen"],
			"name": compendium.creature_def(id).display_name if rec["seen"] else "???",
			"status": _bestiary_status(rec)})
	return rows

static func _bestiary_status(rec: Dictionary) -> String:
	if rec["eaten"] > 0:
		return "eaten ×%d" % rec["eaten"]
	if rec["appraisal"] > 0:
		return "appraised"
	return "seen" if rec["seen"] else ""

## What the Bestiary card shows. Seen: name. Appraised: what that Appraisal level reveals
## (HP; then stats, essences and eat bonus; then skills). Eaten: essences and eat bonus too.
static func bestiary_detail(compendium: CompendiumModel, id: String) -> Dictionary:
	var rec := compendium.creature_record(id)
	var c := compendium.creature_def(id)
	if c == null or not rec["seen"]:
		return {"id": id, "name": "???", "seen": false}
	var out := {"id": id, "name": c.display_name, "seen": true, "status": _bestiary_status(rec),
		"eaten": rec["eaten"], "defeated": rec["defeated"]}
	var report := compendium.creature_report(id, rec["appraisal"]) if rec["appraisal"] > 0 else {}
	if report.has("hp"):
		out["hp"] = report["hp"]
	if report.has("stats"):
		out["stats"] = report["stats"]
	if report.has("skills"):
		out["skills"] = report["skills"].map(func(s): return compendium.skill_name(s.get("id", "")))
	if report.has("essences") or rec["eaten"] > 0:
		out["essences"] = c.essences.duplicate()
		out["eat_bonus"] = c.eat_bonus.duplicate()
	return out

static func detail(rules, d: SkillDef, slots: ActiveSlots) -> Dictionary:
	var level: int = rules.level_of(d.id)
	var p: Dictionary = rules.level_progress(d.id)
	var slot := slots.slots.find(d.id)  # -1 when not slotted
	return {"id": d.id, "name": d.display_name, "level": level, "max_level": d.max_level,
		"description": d.description, "mp_cost": d.mp_cost, "lines": effect_lines(d, maxi(level, 1)),
		"progress": float(p["current"]) / p["target"] if p["target"] > 0 else -1.0, "slot": slot}

static func effect_lines(d: SkillDef, level: int) -> Array:
	var lines: Array = []
	for e in d.effects:
		var v := int(SkillEffects.value_at(e, level))
		match e.get("kind", ""):
			"active":
				if e.has("values"):
					lines.append("%s %d" % [ACTIVE_LABEL.get(d.id, "Power"), v])
			"modifier", "conditional_modifier":
				var stat: String = e.get("stat", "")
				if stat == SkillEffects.DAMAGE_TAKEN:
					var kind: String = e.get("scope", {}).get("damage_type", "")
					var what := (kind.capitalize() + " damage") if kind != "" else "Damage"
					if e.get("op", "") == "percent_off":
						lines.append("%s −%d%%" % [what, v])
					else:
						lines.append("%s −%d at low HP" % [what, v])
				elif stat == StatKeys.REGEN_INTERVAL:
					lines.append("Regen 1 HP every %d s" % v)
				else:
					var pct := "%" if StatKeys.PERCENT.has(stat) else ""
					lines.append("%s %+d%s" % [STAT_LABEL.get(stat, stat), v, pct])
	return lines

static func condition_text(d: SkillDef, by_id: Dictionary) -> String:
	var parts: Array = []
	for c in d.unlock:
		match c.get("kind", ""):
			"counter":
				parts.append("%s ×%d" % [_event_text(c["event"], c.get("tags", {})), c["n"]])
			"reset_counter":
				parts.append("Eat creatures in a row without taking damage ×%d" % c["n"])
			"skill_level":
				var parent = by_id.get(c["id"])
				parts.append("%s Lv%d" % [parent.display_name if parent != null else c["id"], c["n"]])
	return " and ".join(parts)

static func _event_text(event: String, tags: Dictionary) -> String:
	match event:
		"absorbed":
			return "Absorb %s essence" % tags.get("essence", "")
		"damaged":
			return "Take %s hits" % tags.get("damage_type", "any") if tags.has("damage_type") else "Take hits"
	return EVENT_TEXT.get(event, event)

static func _sorted(defs: Array) -> Array:
	var out := defs.filter(func(d): return d.source != "enemy_only")
	out.sort_custom(func(a, b): return a.display_name < b.display_name)
	return out

## Map tab data: visited rooms (with the current one flagged, plus pool and tablet marks),
## stubs for exits from visited rooms into rooms not yet visited, the bounds of the whole
## world (so the map's scale never shifts), and the "Rooms found" count.
static func map_view(rooms: Dictionary, progress, current_id: String) -> Dictionary:
	var shown: Array = []
	var stubs: Array = []
	var bounds := Rect2()
	var ids := rooms.keys()
	ids.sort()
	for id in ids:
		var r: RoomDef = rooms[id]
		bounds = r.world_rect() if bounds.size == Vector2.ZERO else bounds.merge(r.world_rect())
		if not progress.is_visited(id):
			continue
		var rect := r.world_rect()
		shown.append({"id": id, "rect": rect, "current": id == current_id,
			"pool": r.features.any(func(f: Dictionary) -> bool: return f.get("kind", "") == "glow_pool"),
			"tablet": r.features.any(func(f: Dictionary) -> bool: return f.get("kind", "") == "tablet")})
		for e in r.exits:
			if progress.is_visited(e["room"]):
				continue
			var span := WorldValidator.world_span(r, e)
			var mid := (span.x + span.y) / 2.0
			var point := Vector2(mid, rect.position.y)
			match e["edge"]:
				"right":
					point = Vector2(rect.end.x, mid)
				"left":
					point = Vector2(rect.position.x, mid)
				"bottom":
					point = Vector2(mid, rect.end.y)
			stubs.append({"room": id, "edge": e["edge"], "point": point})
	return {"rooms": shown, "stubs": stubs, "bounds": bounds,
		"found": "Rooms found %d/%d" % [shown.size(), rooms.size()]}

## The Sound tab's rows: one slider per setting, in AudioSettings.KEYS order.
static func sound_rows(settings) -> Array:
	var out: Array = []
	for k in AudioSettings.KEYS:
		out.append({"kind": "slider", "id": k, "name": AudioSettings.LABELS[k], "value": float(settings.values[k])})
	return out
