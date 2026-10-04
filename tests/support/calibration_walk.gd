class_name CalibrationWalk
extends RefCounted
## Walks the shipped rooms and eats every spawn once, through a real SkillRulesEngine, so a tool and a test report the same
## unlock points. A creature a tackle cannot down (the jelly) is skipped.

const AREAS := ["cave", "grotto", "flooded", "deep"]

## Room ids in the order a walk meets them: the start area first (room-id order), then the later areas, then the earlier ones
## nearest first (a life may walk back). An empty start area is the Cave start: cave, grotto, flooded, deep.
static func order(rooms: Dictionary, start_area: String) -> Array:
	var areas: Array = AREAS.duplicate()
	if start_area != "":
		var i := AREAS.find(start_area)
		areas = AREAS.slice(i)
		var back: Array = AREAS.slice(0, i)
		back.reverse()
		areas.append_array(back)
	var out: Array = []
	for a in areas:
		var ids: Array = []
		for id in rooms:
			if (rooms[id] as RoomDef).area == a:
				ids.append(id)
		ids.sort()
		out.append_array(ids)
	return out

static func eat(rules: SkillRulesEngine, c: CreatureDef) -> void:
	rules.handle_event("predated", {"source": c.id, "kind": "creature" if c.id != "water_pool" else "terrain"})
	for e in c.essences:
		for i in int(c.essences[e]):
			rules.handle_event("absorbed", {"essence": e, "source": c.id})

## essence-skill id -> the eat (counting from 1) at which it unlocked on this walk; absent when it never did.
static func unlock_points(skills: Array, creatures: Dictionary, rooms: Dictionary, start_area: String) -> Dictionary:
	var rules := SkillRulesEngine.new()
	rules.setup(skills)
	rules.start_run()
	var watched: Array = skills.filter(func(d: SkillDef) -> bool: return d.source == "essence")
	var out := {}
	var eats := 0
	for id in order(rooms, start_area):
		for s in (rooms[id] as RoomDef).spawns:
			var c: CreatureDef = creatures[s["id"]]
			if c.untackleable:
				continue
			eats += 1
			eat(rules, c)
			for d in watched:
				if not out.has(d.id) and rules.level_of(d.id) > 0:
					out[d.id] = eats
	rules.free()
	return out

## area -> {skill id -> level} at the end of each area on the Cave-start walk, for skills that level on an absorbed element.
static func levels_by_area(skills: Array, creatures: Dictionary, rooms: Dictionary) -> Dictionary:
	var rules := SkillRulesEngine.new()
	rules.setup(skills)
	rules.start_run()
	var levelled: Array = skills.filter(func(d: SkillDef) -> bool: return d.source == "essence" and d.levels_on.get("event", "") == "absorbed")
	var out := {}
	for a in AREAS:
		var ids: Array = []
		for id in rooms:
			if (rooms[id] as RoomDef).area == a:
				ids.append(id)
		ids.sort()
		for id in ids:
			for s in (rooms[id] as RoomDef).spawns:
				var c: CreatureDef = creatures[s["id"]]
				if not c.untackleable:
					eat(rules, c)
		var row := {}
		for d in levelled:
			row[d.id] = rules.level_of(d.id)
		out[a] = row
	rules.free()
	return out
