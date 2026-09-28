extends SceneTree
## Generates res://data/skills/*.tres and res://data/creatures/*.tres.
## This file is the source of truth for all content numbers; edit here, then re-run:
##   env HOME="$PWD/.tmp/gdhome" godot --headless -s tools/build_content.gd

const ABILITY := "res://scenes/abilities/%s.tscn"

func _init() -> void:
	var failures := 0
	for d in _skills():
		failures += _save(d, "res://data/skills/%s.tres" % d.id)
	for c in _creatures():
		failures += _save(c, "res://data/creatures/%s.tres" % c.id)
	quit(1 if failures > 0 else 0)

func _save(res: Resource, path: String) -> int:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err := ResourceSaver.save(res, path)
	if err != OK:
		printerr("failed to save %s: %s" % [path, error_string(err)])
		return 1
	print("wrote ", path)
	return 0

static func _c(event: String, n: int, tags: Dictionary = {}) -> Dictionary:
	return {"kind": "counter", "event": event, "tags": tags, "n": n}

static func _lv(id: String, n: int) -> Dictionary:
	return {"kind": "skill_level", "id": id, "n": n}

static func _on(event: String, tags: Dictionary = {}) -> Dictionary:
	return {"event": event, "tags": tags}

static func _mod(stat: String, values: Array, op: String = "add") -> Dictionary:
	return {"kind": "modifier", "stat": stat, "op": op, "values": values}

static func _active(id: String, values: Array = []) -> Dictionary:
	var e := {"kind": "active", "scene": ABILITY % id}
	if not values.is_empty():
		e["values"] = values
	return e

func _s(f: Dictionary) -> SkillDef:
	var d := SkillDef.new()
	for key in f:
		d.set(key, f[key])
	return d

func _skills() -> Array:
	return [
		# --- Proficiency (hidden) ---
		_s({"id": "leap", "display_name": "Leap", "source": "proficiency",
			"description": "Jump higher.", "hint": "Your body remembers every leap.",
			"announce": "Proficiency reached. Acquired [Leap].",
			"unlock": [_c("jumped", 40)], "levels_on": _on("jumped"), "level_curve": 40, "max_level": 5,
			"effects": [_mod("jump_height", [10, 15, 20, 25, 30])]}),
		_s({"id": "wall_cling", "display_name": "Wall Cling", "source": "proficiency",
			"description": "Stick to walls and slide down slowly.", "hint": "Walls feel less slippery than before.",
			"announce": "Proficiency reached. Acquired [Wall Cling].",
			"unlock": [_c("wall_touched", 15)], "levels_on": _on("wall_touched"), "level_curve": 20, "max_level": 3,
			"effects": [{"kind": "capability", "flag": "wall_cling"}, _mod("slide_speed", [-30, -45, -60])]}),
		_s({"id": "poison_resistance", "display_name": "Poison Resistance", "source": "proficiency",
			"description": "Take less poison damage.", "hint": "Poison stings a little less each time.",
			"announce": "Proficiency reached. Acquired [Poison Resistance].",
			"unlock": [_c("damaged", 6, {"damage_type": "poison"})],
			"levels_on": _on("damaged", {"damage_type": "poison"}), "level_curve": 6, "max_level": 5,
			"effects": [{"kind": "modifier", "stat": "damage_taken", "op": "percent_off",
				"scope": {"damage_type": "poison"}, "values": [20, 35, 50, 65, 80]}]}),
		_s({"id": "pain_resistance", "display_name": "Pain Resistance", "source": "proficiency",
			"description": "Take less damage while badly hurt.", "hint": "Surviving the brink hardens you.",
			"announce": "Proficiency reached. Acquired [Pain Resistance].",
			"unlock": [_c("hp_low_exited", 2)], "levels_on": _on("hp_low_exited"), "level_curve": 2, "max_level": 3,
			"effects": [{"kind": "conditional_modifier", "stat": "damage_taken", "op": "flat_off",
				"condition": {"hp_below_percent": 30}, "values": [1, 2, 3]}]}),
		_s({"id": "toughness", "display_name": "Toughness", "source": "proficiency",
			"description": "Raise max HP.", "hint": "Every bruise makes you sturdier.",
			"announce": "Proficiency reached. Acquired [Toughness].",
			"unlock": [_c("damaged", 20, {"damage_type": "physical"})],
			"levels_on": _on("damaged", {"damage_type": "physical"}), "level_curve": 20, "max_level": 5,
			"effects": [_mod("max_hp", [3, 6, 9, 12, 15])]}),
		_s({"id": "appraisal", "display_name": "Appraisal", "source": "proficiency", "hidden": false,
			"starting": true, "description": "Inspect creatures and yourself.",
			"hint": "Look closely at new things.", "announce": "",
			"levels_on": _on("inspected", {"first_time": true, "appraisal_target": true}),
			"level_curve": 2, "max_level": 4,
			"effects": [{"kind": "capability", "flag": "appraise"}]}),
		_s({"id": "glutton", "display_name": "Glutton", "source": "proficiency", "secret": true,
			"description": "Eat faster and heal more from creatures.", "hint": "",
			"announce": "Unique condition met. Acquired [Glutton].",
			"unlock": [{"kind": "reset_counter", "event": "predated", "tags": {"kind": "creature"},
				"reset_on": "damaged", "n": 5}],
			"levels_on": _on("predated", {"kind": "creature"}), "level_curve": 5, "max_level": 3,
			"effects": [_mod("predation_time", [-30, -45, -60])],
			"trigger": {"on": "predated", "tags": {"kind": "creature"}, "action": "heal", "amount": 3}}),
		_s({"id": "mana_recovery", "display_name": "Mana Recovery", "source": "proficiency",
			"description": "Regain MP faster.", "hint": "Magic flows back faster the more you spend it.",
			"announce": "Proficiency reached. Acquired [Mana Recovery].",
			"unlock": [_c("mana_spent", 60)], "levels_on": _on("mana_spent"), "level_curve": 60, "max_level": 3,
			"effects": [_mod("mp_regen", [50, 100, 150])]}),
		# --- Essence (from eating) ---
		_s({"id": "echolocation", "display_name": "Echolocation", "source": "essence", "hidden": false,
			"description": "Reveal hidden passages nearby.", "hint": "Sounds carry shapes to you.",
			"announce": "Analysis complete. Acquired [Echolocation].",
			"unlock": [_c("absorbed", 3, {"essence": "sound"})],
			"levels_on": _on("absorbed", {"essence": "sound"}), "level_curve": 1, "max_level": 3,
			"effects": [{"kind": "capability", "flag": "reveals_hidden", "values": [1, 2, 3]}]}),
		_s({"id": "poison_breath", "display_name": "Poison Breath", "source": "essence", "hidden": false,
			"description": "Breathe a short cone of poison.", "hint": "Something toxic gathers inside you.",
			"announce": "Analysis complete. Acquired [Poison Breath].",
			"unlock": [_c("absorbed", 4, {"essence": "poison"})],
			"levels_on": _on("skill_used", {"id": "poison_breath"}), "level_curve": 8, "max_level": 5,
			"effects": [_active("poison_breath", [2, 3, 4, 5, 6])], "mp_cost": 4}),
		_s({"id": "body_armor", "display_name": "Body Armor", "source": "essence", "hidden": false,
			"description": "Raise DEF.", "hint": "Your skin wants to harden.",
			"announce": "Analysis complete. Acquired [Body Armor].",
			"unlock": [_c("absorbed", 3, {"essence": "armor"})],
			"levels_on": _on("damaged"), "level_curve": 10, "max_level": 3,
			"effects": [_mod("def", [1, 2, 3])]}),
		_s({"id": "sticky_thread", "display_name": "Sticky Thread", "source": "essence", "hidden": false,
			"description": "Shoot a thread that slows, then holds, an enemy.", "hint": "Something silky stirs within.",
			"announce": "Analysis complete. Acquired [Sticky Thread].",
			"unlock": [_c("absorbed", 3, {"essence": "thread"})],
			"levels_on": _on("skill_used", {"id": "sticky_thread"}), "level_curve": 8, "max_level": 5,
			"effects": [_active("sticky_thread", [1, 1, 2, 2, 2])], "mp_cost": 3}),
		_s({"id": "hydraulic_propulsion", "display_name": "Hydraulic Propulsion", "source": "essence", "hidden": false,
			"description": "A short water-powered burst.", "hint": "Water sloshes eagerly inside you.",
			"announce": "Analysis complete. Acquired [Hydraulic Propulsion].",
			"unlock": [_c("absorbed", 4, {"essence": "water"})],
			"levels_on": _on("skill_used", {"id": "hydraulic_propulsion"}), "level_curve": 6, "max_level": 5,
			"effects": [_active("hydraulic_propulsion", [100, 120, 140, 160, 180])], "mp_cost": 3}),
		_s({"id": "regeneration", "display_name": "Regeneration", "source": "essence", "hidden": false,
			"description": "Slowly regain HP.", "hint": "Everything you eat makes you whole.",
			"announce": "Analysis complete. Acquired [Regeneration].",
			"unlock": [_c("predated", 10, {"kind": "creature"})],
			"levels_on": _on("predated", {"kind": "creature"}), "level_curve": 8, "max_level": 3,
			"effects": [_mod("regen_interval", [8, 6, 4], "set")]}),
		# --- Evolutions (hidden, parents kept) ---
		_s({"id": "water_blade", "display_name": "Water Blade", "source": "evolution",
			"description": "Fire a blade of water.", "hint": "",
			"announce": "Skill evolved. Acquired [Water Blade].",
			"unlock": [_lv("hydraulic_propulsion", 2)], "effects": [_active("water_blade", [3])], "mp_cost": 5}),
		_s({"id": "swing_thread", "display_name": "Swing Thread", "source": "evolution",
			"description": "Swing from a thread like a grappling hook.", "hint": "",
			"announce": "Skill evolved. Acquired [Swing Thread].",
			"unlock": [_lv("sticky_thread", 3), _lv("wall_cling", 2)], "effects": [_active("swing_thread")], "mp_cost": 4}),
		_s({"id": "jet_dash", "display_name": "Jet Dash", "source": "evolution",
			"description": "A long horizontal dash.", "hint": "",
			"announce": "Skill evolved. Acquired [Jet Dash].",
			"unlock": [_lv("hydraulic_propulsion", 3), _lv("leap", 2)], "effects": [_active("jet_dash")], "mp_cost": 5}),
		# --- Enemy-only ---
		_s({"id": "flight", "display_name": "Flight", "source": "enemy_only", "hidden": false,
			"description": "Flies and ignores ground pathing.", "effects": [{"kind": "capability", "flag": "flight"}]}),
		_s({"id": "ceiling_walk", "display_name": "Ceiling Walk", "source": "enemy_only", "hidden": false,
			"description": "Clings to ceilings and drops on prey.", "effects": [{"kind": "capability", "flag": "ceiling_walk"}]}),
		_s({"id": "poison_spit", "display_name": "Poison Spit", "source": "enemy_only", "hidden": false,
			"description": "4 poison on hit, then 2 per second for 3 s.", "effects": [_active("poison_spit", [4])]}),
		_s({"id": "tail_swipe", "display_name": "Tail Swipe", "source": "enemy_only", "hidden": false,
			"description": "5 physical damage and knockback.", "effects": [_active("tail_swipe", [5])]}),
		_s({"id": "constrict", "display_name": "Constrict", "source": "enemy_only", "hidden": false,
			"description": "Grabs for 2 s: a 3-physical hit each second. Jump twice to break free.",
			"effects": [_active("constrict", [3])]}),
	]

func _cr(f: Dictionary) -> CreatureDef:
	var c := CreatureDef.new()
	for key in f:
		c.set(key, f[key])
	return c

func _creatures() -> Array:
	return [
		_cr({"id": "bat", "display_name": "Cave Bat", "stats": {"max_hp": 2, "atk": 3, "def": 0, "spd": 140},
			"essences": {"sound": 1, "flight": 1},
			"skills": [{"id": "echolocation", "level": 1}, {"id": "flight", "level": 1}],
			"eat_bonus": {"stat": "spd", "amount": 2, "per": 1}}),
		_cr({"id": "toad", "display_name": "Poison Toad", "stats": {"max_hp": 3, "atk": 3, "def": 0, "spd": 70},
			"essences": {"poison": 1, "water": 1},
			"skills": [{"id": "poison_spit", "level": 1}, {"id": "poison_resistance", "level": 2}],
			"eat_bonus": {"stat": "max_hp", "amount": 1, "per": 1}}),
		_cr({"id": "lizard", "display_name": "Armored Lizard", "stats": {"max_hp": 5, "atk": 5, "def": 1, "spd": 80},
			"essences": {"armor": 1, "earth": 1},
			"skills": [{"id": "body_armor", "level": 2}, {"id": "tail_swipe", "level": 1}],
			"eat_bonus": {"stat": "def", "amount": 1, "per": 3}}),
		_cr({"id": "spider", "display_name": "Black Spider", "stats": {"max_hp": 3, "atk": 4, "def": 0, "spd": 110},
			"essences": {"thread": 1, "poison": 1},
			"skills": [{"id": "sticky_thread", "level": 1}, {"id": "ceiling_walk", "level": 1}],
			"eat_bonus": {"stat": "atk", "amount": 1, "per": 3}}),
		_cr({"id": "water_pool", "display_name": "Water Pool", "stats": {},
			"essences": {"water": 2}, "skills": [], "eat_bonus": {}}),
		_cr({"id": "serpent", "display_name": "Cave Serpent", "stats": {"max_hp": 40, "atk": 6, "def": 1, "spd": 90},
			"essences": {}, "skills": [{"id": "water_blade", "level": 1}, {"id": "constrict", "level": 1}],
			"eat_bonus": {}, "predatable": false, "appraisal_target": false}),
	]
