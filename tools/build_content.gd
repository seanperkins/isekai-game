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
			"unlock": [_c("jumped", 40)], "levels_on": _on("jumped"), "level_curve": 20, "max_level": 10,
			"effects": [_mod("jump_height", [10, 15, 20, 25, 30, 35, 40, 45, 50, 55])]}),
		_s({"id": "wall_cling", "display_name": "Wall Cling", "source": "proficiency",
			"description": "Stick to walls and slide down slowly.", "hint": "Walls feel less slippery than before.",
			"announce": "Proficiency reached. Acquired [Wall Cling].",
			"unlock": [_c("wall_touched", 15)], "levels_on": _on("wall_touched"), "level_curve": 12, "max_level": 8,
			"effects": [{"kind": "capability", "flag": "wall_cling"}, _mod("slide_speed", [-30, -40, -50, -58, -65, -71, -76, -80])]}),
		_s({"id": "poison_resistance", "display_name": "Poison Resistance", "source": "proficiency",
			"description": "Take less poison damage, and less from poison over time.", "hint": "Poison stings a little less each time.",
			"announce": "Proficiency reached. Acquired [Poison Resistance].",
			"unlock": [_c("damaged", 6, {"damage_type": "poison"})],
			"levels_on": _on("damaged", {"damage_type": "poison"}), "level_curve": 6, "max_level": 12,
			"effects": [{"kind": "modifier", "stat": "damage_taken", "op": "percent_off",
				"scope": {"damage_type": "poison"}, "values": [20, 32, 42, 52, 60, 67, 73, 78, 83, 87, 90, 92]}]}),
		_s({"id": "pain_resistance", "display_name": "Pain Resistance", "source": "proficiency",
			"description": "Take less damage while badly hurt.", "hint": "Surviving the brink hardens you.",
			"announce": "Proficiency reached. Acquired [Pain Resistance].",
			"unlock": [_c("hp_low_exited", 2)], "levels_on": _on("hp_low_exited"), "level_curve": 2, "max_level": 6,
			"effects": [{"kind": "conditional_modifier", "stat": "damage_taken", "op": "flat_off",
				"condition": {"hp_below_percent": 30}, "values": [1, 2, 3, 4, 5, 6]}]}),
		_s({"id": "toughness", "display_name": "Toughness", "source": "proficiency",
			"description": "Raise max HP.", "hint": "Every bruise makes you sturdier.",
			"announce": "Proficiency reached. Acquired [Toughness].",
			"unlock": [_c("damaged", 20, {"damage_type": "physical"})],
			"levels_on": _on("damaged", {"damage_type": "physical"}), "level_curve": 20, "max_level": 12,
			"effects": [_mod("max_hp", [3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36])]}),
		_s({"id": "appraisal", "display_name": "Appraisal", "source": "proficiency", "hidden": false,
			"starting": true, "description": "Inspect creatures and yourself.",
			"hint": "Look closely at new things.", "announce": "",
			"levels_on": _on("inspected", {"first_time": true, "appraisal_target": true}),
			"level_curve": 2, "max_level": 5,
			"effects": [{"kind": "capability", "flag": "appraise"}]}),
		_s({"id": "glutton", "display_name": "Glutton", "source": "proficiency", "secret": true,
			"description": "Eat faster and heal more from creatures.", "hint": "",
			"announce": "Unique condition met. Acquired [Glutton].",
			"unlock": [{"kind": "reset_counter", "event": "predated", "tags": {"kind": "creature"},
				"reset_on": "damaged", "n": 5}],
			"levels_on": _on("predated", {"kind": "creature"}), "level_curve": 5, "max_level": 8,
			"effects": [_mod("predation_time", [-30, -45, -60, -68, -74, -79, -83, -86])],
			"trigger": {"on": "predated", "tags": {"kind": "creature"}, "action": "heal", "amount": 3}}),
		_s({"id": "mana_recovery", "display_name": "Mana Recovery", "source": "proficiency",
			"description": "Regain MP faster.", "hint": "Magic flows back faster the more you spend it.",
			"announce": "Proficiency reached. Acquired [Mana Recovery].",
			"unlock": [_c("mana_spent", 60)], "levels_on": _on("mana_spent"), "level_curve": 60, "max_level": 8,
			"effects": [_mod("mp_regen", [50, 100, 150, 190, 225, 255, 280, 300])]}),
		# --- Essence (from eating) ---
		_s({"id": "echolocation", "display_name": "Echolocation", "source": "essence", "hidden": false,
			"description": "Reveal hidden passages nearby.", "hint": "Sounds carry shapes to you.",
			"announce": "Analysis complete. Acquired [Echolocation].",
			"unlock": [_c("absorbed", 6, {"essence": "air"})],
			"levels_on": _on("absorbed", {"essence": "air"}), "level_curve": 9, "max_level": 8,
			"effects": [{"kind": "capability", "flag": "reveals_hidden", "values": [1, 2, 3, 4, 5, 6, 7, 8]}]}),
		_s({"id": "poison_breath", "evolution_price": {"water": 6, "dark": 10}, "display_name": "Poison Breath", "source": "essence", "hidden": false,
			"description": "Breathe a short cone of poison.", "hint": "Something toxic gathers inside you.",
			"announce": "Analysis complete. Acquired [Poison Breath].",
			"unlock": [_c("absorbed", 4, {"essence": "water"}), _c("absorbed", 4, {"essence": "dark"})],
			"levels_on": _on("skill_used", {"id": "poison_breath"}), "level_curve": 8, "max_level": 15,
			"effects": [_active("poison_breath", [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16])], "mp_cost": 4}),
		_s({"id": "body_armor", "display_name": "Body Armor", "source": "essence", "hidden": false,
			"description": "Raise DEF against physical damage.", "hint": "Your skin wants to harden.",
			"announce": "Analysis complete. Acquired [Body Armor].",
			"unlock": [_c("absorbed", 6, {"essence": "earth"})],
			"levels_on": _on("damaged"), "level_curve": 10, "max_level": 8,
			"effects": [_mod("def", [1, 2, 3, 4, 5, 6, 7, 8])]}),
		_s({"id": "sticky_thread", "evolution_price": {"dark": 14}, "display_name": "Sticky Thread", "source": "essence", "hidden": false,
			"description": "Shoot a thread: it slows, then holds, an enemy, or sticks to rock so you can swing. Hold it on an enemy to keep it webbed.", "hint": "Something silky stirs within.",
			"announce": "Analysis complete. Acquired [Sticky Thread].",
			"unlock": [_c("predated", 3, {"source": "spider"})],
			"levels_on": _on("skill_used", {"id": "sticky_thread"}), "level_curve": 8, "max_level": 15,
			"effects": [_active("sticky_thread", [1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2])], "mp_cost": 3}),
		_s({"id": "hydraulic_propulsion", "evolution_price": {"water": 6}, "display_name": "Hydraulic Propulsion", "source": "essence", "hidden": false,
			"description": "A short water-powered burst. Hold to keep the stream going.", "hint": "Water sloshes eagerly inside you.",
			"announce": "Analysis complete. Acquired [Hydraulic Propulsion].",
			"unlock": [_c("absorbed", 8, {"essence": "water"})],
			"levels_on": _on("skill_used", {"id": "hydraulic_propulsion"}), "level_curve": 6, "max_level": 15,
			"effects": [_active("hydraulic_propulsion", [100, 120, 140, 160, 180, 195, 210, 225, 240, 250, 260, 270, 280, 290, 300])], "mp_cost": 3}),
		_s({"id": "regeneration", "display_name": "Regeneration", "source": "essence", "hidden": false,
			"description": "Slowly regain HP.", "hint": "Everything you eat makes you whole.",
			"announce": "Analysis complete. Acquired [Regeneration].",
			"unlock": [_c("predated", 10, {"kind": "creature"})],
			"levels_on": _on("predated", {"kind": "creature"}), "level_curve": 8, "max_level": 6,
			"effects": [_mod("regen_interval", [8, 6, 4, 3, 2, 1], "set")]}),
		_s({"id": "spore_cloud", "evolution_price": {"air": 6, "dark": 12}, "display_name": "Spore Cloud", "source": "essence", "hidden": false,
			"description": "Release a lingering cloud of spores that slows and poisons.", "hint": "Something spongy stirs within.",
			"announce": "Analysis complete. Acquired [Spore Cloud].",
			"unlock": [_c("absorbed", 8, {"essence": "air"}), _c("absorbed", 4, {"essence": "dark"})],
			"levels_on": _on("skill_used", {"id": "spore_cloud"}), "level_curve": 8, "max_level": 8,
			"effects": [_active("spore_cloud", [24, 28, 32, 36, 40, 44, 48, 52])], "mp_cost": 4}),
		_s({"id": "hardened_shell", "display_name": "Hardened Shell", "source": "essence", "hidden": false,
			"description": "Take less knockback.", "hint": "Your skin wants to harden, and your footing with it.",
			"announce": "Analysis complete. Acquired [Hardened Shell].",
			"unlock": [_c("absorbed", 14, {"essence": "earth"})],
			"levels_on": _on("damaged", {"damage_type": "physical"}), "level_curve": 10, "max_level": 8,
			"effects": [_mod(SkillEffects.KNOCKBACK_TAKEN, [-8, -16, -24, -32, -40, -48, -56, -64])]}),
		_s({"id": "swim", "display_name": "Swim", "source": "proficiency",
			"description": "Move freely through deep water.", "hint": "The water holds you up a little more each time.",
			"announce": "Proficiency reached. Acquired [Swim].",
			"unlock": [_c("submerged", 20)], "levels_on": _on("submerged"), "level_curve": 40, "max_level": 3,
			"effects": [{"kind": "capability", "flag": "swim"}, _mod(StatKeys.SWIM_SPEED, [0, 30, 60])]}),
		_s({"id": "jolt", "display_name": "Jolt", "source": "essence", "hidden": false,
			"description": "A burst of shock around you that stuns swimmers.", "hint": "Something crackles faintly within.",
			"announce": "Analysis complete. Acquired [Jolt].",
			"unlock": [_c("absorbed", 4, {"essence": "light"}), _c("absorbed", 4, {"essence": "air"})],
			"levels_on": _on("skill_used", {"id": "jolt"}), "level_curve": 8, "max_level": 5,
			"effects": [_active("jolt", [3, 4, 5, 6, 7])], "mp_cost": 5}),
		_s({"id": "tremor", "display_name": "Tremor", "source": "essence", "hidden": false,
			"description": "Slam the ground: everything standing near you is hurt through its armor and stunned.", "hint": "The ground feels heavier underfoot.",
			"announce": "Analysis complete. Acquired [Tremor].",
			"unlock": [_c("absorbed", 59, {"essence": "earth"})],
			"levels_on": _on("skill_used", {"id": "tremor"}), "level_curve": 8, "max_level": 5,
			"effects": [_active("tremor", [3, 4, 5, 6, 7])], "mp_cost": 5}),
		# --- Evolutions (each replaces its parent; siblings unlock together on it) ---
		_s({"id": "water_blade", "display_name": "Water Blade", "source": "evolution",
			"description": "Fire a blade of water.", "hint": "",
			"announce": "Skill evolved. Acquired [Water Blade].",
			"unlock": [_lv("hydraulic_propulsion", 3)], "effects": [_active("water_blade", [3])], "mp_cost": 5,
			"replaces": "hydraulic_propulsion"}),
		_s({"id": "swing_thread", "display_name": "Swing Thread", "source": "evolution",
			"description": "A longer, faster thread: swing farther and launch harder. Holds enemies.", "hint": "",
			"announce": "Skill evolved. Acquired [Swing Thread].",
			"unlock": [_lv("sticky_thread", 3)], "effects": [_active("swing_thread", [2])], "mp_cost": 4,
			"replaces": "sticky_thread"}),
		_s({"id": "binding_web", "display_name": "Binding Web", "source": "evolution",
			"description": "Hold an enemy with thread and leave a web that slows anything inside.", "hint": "",
			"announce": "Skill evolved. Acquired [Binding Web].",
			"unlock": [_lv("sticky_thread", 3)], "effects": [_active("binding_web", [2])], "mp_cost": 4,
			"replaces": "sticky_thread"}),
		_s({"id": "miasma", "display_name": "Miasma", "source": "evolution",
			"description": "Breathe poison and leave a lingering cloud where it ends.", "hint": "",
			"announce": "Skill evolved. Acquired [Miasma].",
			"unlock": [_lv("poison_breath", 4)], "effects": [_active("miasma", [9])], "mp_cost": 5,
			"replaces": "poison_breath"}),
		_s({"id": "venom_bolt", "display_name": "Venom Bolt", "source": "evolution",
			"description": "A piercing bolt of poison along your aim.", "hint": "",
			"announce": "Skill evolved. Acquired [Venom Bolt].",
			"unlock": [_lv("poison_breath", 4)], "effects": [_active("venom_bolt", [9])], "mp_cost": 5,
			"replaces": "poison_breath"}),
		_s({"id": "healing_spores", "display_name": "Healing Spores", "source": "evolution",
			"description": "A cloud of spores that mends you and slows enemies.", "hint": "",
			"announce": "Skill evolved. Acquired [Healing Spores].",
			"unlock": [_lv("spore_cloud", 4)], "effects": [_active("healing_spores", [40])], "mp_cost": 4,
			"replaces": "spore_cloud"}),
		_s({"id": "puffball", "display_name": "Puffball", "source": "evolution",
			"description": "Lob a spore pod that bursts into a wide cloud.", "hint": "",
			"announce": "Skill evolved. Acquired [Puffball].",
			"unlock": [_lv("spore_cloud", 4)], "effects": [_active("puffball", [64])], "mp_cost": 5,
			"replaces": "spore_cloud"}),
		_s({"id": "jet_dash", "display_name": "Jet Dash", "source": "evolution",
			"description": "A long horizontal dash.", "hint": "",
			"announce": "Skill evolved. Acquired [Jet Dash].",
			"unlock": [_lv("hydraulic_propulsion", 3)], "effects": [_active("jet_dash")], "mp_cost": 5,
			"replaces": "hydraulic_propulsion"}),
		# --- Enemy-only ---
		_s({"id": "flight", "display_name": "Flight", "source": "enemy_only", "hidden": false,
			"description": "Flies and ignores ground pathing.", "effects": [{"kind": "capability", "flag": "flight"}]}),
		_s({"id": "ceiling_walk", "display_name": "Ceiling Walk", "source": "enemy_only", "hidden": false,
			"description": "Clings to ceilings and drops on prey.", "effects": [{"kind": "capability", "flag": "ceiling_walk"}]}),
		_s({"id": "poison_spit", "display_name": "Poison Spit", "source": "enemy_only", "hidden": false,
			"description": "4 poison on hit, then 1 per second for 3 s.", "effects": [_active("poison_spit", [4])]}),
		_s({"id": "tail_swipe", "display_name": "Tail Swipe", "source": "enemy_only", "hidden": false,
			"description": "5 physical damage and knockback.", "effects": [_active("tail_swipe", [5])]}),
		_s({"id": "constrict", "display_name": "Constrict", "source": "enemy_only", "hidden": false,
			"description": "Grabs for 2 s: a 3-physical hit each second. Jump twice to break free.",
			"effects": [_active("constrict", [3])]}),
	]

## A creature's stats at a level: max_hp, atk and def (the keys present) grow 8% a level, rounded half up; SPD and the rest are
## untouched. Level 1 is the identity and 0 stays 0. The level is a generator concept: the .tres files carry only the result.
static func _at_level(level: int, stats: Dictionary) -> Dictionary:
	var out := stats.duplicate()
	for key in ["max_hp", "atk", "def"]:
		if out.has(key):
			out[key] = _scaled(int(out[key]), level)
	return out

static func _scaled(base: int, level: int) -> int:
	return floori(float(base * (100 + 8 * (maxi(level, 1) - 1)) + 50) / 100.0)

## The Grotto's creatures are level 4; the Cave's stay at their base numbers.
const GROTTO_LEVEL := 4
## The Flooded Tunnels' creatures are level 7: the spec's numbers are level-1 bases, scaled as the Grotto's are.
const FLOODED_LEVEL := 7
## The Deep's creatures are level 10.
const DEEP_LEVEL := 10

func _cr(f: Dictionary) -> CreatureDef:
	var c := CreatureDef.new()
	for key in f:
		c.set(key, f[key])
	return c

func _creatures() -> Array:
	return [
		_cr({"id": "bat", "display_name": "Cave Bat", "stats": {"max_hp": 2, "atk": 3, "def": 0, "spd": 140},
			"essences": {"air": 2},
			"skills": [{"id": "echolocation", "level": 1}, {"id": "flight", "level": 1}],
			"eat_bonus": {"stat": "spd", "amount": 2, "per": 1}, "xp": 2}),
		_cr({"id": "toad", "display_name": "Poison Toad", "stats": {"max_hp": 3, "atk": 3, "def": 0, "spd": 70},
			"essences": {"water": 2, "dark": 1},
			"skills": [{"id": "poison_spit", "level": 1}, {"id": "poison_resistance", "level": 2}],
			"eat_bonus": {"stat": "max_hp", "amount": 1, "per": 1}, "xp": 3}),
		_cr({"id": "lizard", "display_name": "Armored Lizard", "stats": {"max_hp": 5, "atk": 5, "def": 1, "spd": 80},
			"essences": {"earth": 2}, "armored_charger": true,
			"skills": [{"id": "body_armor", "level": 2}, {"id": "tail_swipe", "level": 1}],
			"eat_bonus": {"stat": "def", "amount": 1, "per": 3}, "xp": 5}),
		_cr({"id": "spider", "display_name": "Black Spider", "stats": {"max_hp": 3, "atk": 4, "def": 0, "spd": 110},
			"essences": {"water": 1, "dark": 1},
			"skills": [{"id": "sticky_thread", "level": 1}, {"id": "ceiling_walk", "level": 1}],
			"eat_bonus": {"stat": "atk", "amount": 1, "per": 3}, "xp": 3}),
		_cr({"id": "spore_moth", "display_name": "Spore Moth", "stats": _at_level(GROTTO_LEVEL, {"max_hp": 3, "atk": 1, "def": 0, "spd": 90}),
			"essences": {"air": 2, "dark": 1}, "skills": [], "drifter": true, "puffs": true,
			"eat_bonus": {"stat": "max_mp", "amount": 1, "per": 2}, "xp": 2}),
		_cr({"id": "mushroom_crab", "display_name": "Mushroom Crab", "stats": _at_level(GROTTO_LEVEL, {"max_hp": 8, "atk": 2, "def": 2, "spd": 70}),
			"essences": {"earth": 3}, "skills": [], "armored_charger": true,
			"eat_bonus": {"stat": "def", "amount": 1, "per": 3}, "xp": 4}),
		_cr({"id": "vine_snake", "display_name": "Vine Snake", "stats": _at_level(GROTTO_LEVEL, {"max_hp": 5, "atk": 3, "def": 0, "spd": 150}),
			"essences": {"water": 1, "dark": 1}, "skills": [{"id": "ceiling_walk", "level": 1}],
			"eat_bonus": {"stat": "atk", "amount": 1, "per": 3}, "xp": 3}),
		_cr({"id": "pale_moth", "display_name": "Pale Moth", "stats": _at_level(GROTTO_LEVEL, {"max_hp": 6, "atk": 1, "def": 0, "spd": 110}),
			"essences": {"air": 5, "dark": 3}, "skills": [], "drifter": true, "puffs": true,
			"eat_bonus": {"stat": "max_mp", "amount": 2, "per": 1}, "xp": 8}),
		_cr({"id": "glass_eel", "display_name": "Glass Eel", "stats": _at_level(FLOODED_LEVEL, {"max_hp": 4, "atk": 2, "def": 0, "spd": 140}),
			"essences": {"light": 1, "air": 1, "water": 1}, "skills": [], "swimmer": true, "contact_type": "shock",
			"eat_bonus": {"stat": "spd", "amount": 2, "per": 2}, "xp": 3}),
		_cr({"id": "cave_crayfish", "display_name": "Cave Crayfish", "stats": _at_level(FLOODED_LEVEL, {"max_hp": 9, "atk": 3, "def": 3, "spd": 60}),
			"essences": {"earth": 1, "water": 1}, "skills": [], "armored_charger": true,
			"eat_bonus": {"stat": "def", "amount": 1, "per": 3}, "xp": 5}),
		_cr({"id": "drift_jelly", "display_name": "Drift Jelly", "stats": _at_level(FLOODED_LEVEL, {"max_hp": 3, "atk": 2, "def": 0, "spd": 30}),
			"essences": {"light": 1, "air": 1, "water": 2}, "skills": [], "drifter": true, "swimmer": true, "untackleable": true, "contact_type": "shock",
			"eat_bonus": {"stat": "max_mp", "amount": 1, "per": 2}, "xp": 3}),
		_cr({"id": "bog_lizardman", "display_name": "Bog Lizardman", "stats": _at_level(FLOODED_LEVEL, {"max_hp": 7, "atk": 3, "def": 1, "spd": 80}),
			"essences": {"earth": 1, "water": 1}, "skills": [], "projectile": "spear",
			"eat_bonus": {"stat": "atk", "amount": 1, "per": 3}, "xp": 5}),
		_cr({"id": "storm_eel", "display_name": "Storm Eel", "stats": _at_level(FLOODED_LEVEL, {"max_hp": 10, "atk": 4, "def": 1, "spd": 160}),
			"essences": {"light": 3, "air": 3, "water": 2}, "skills": [], "swimmer": true, "contact_type": "shock",
			"eat_bonus": {"stat": "spd", "amount": 2, "per": 1}, "xp": 10}),
		_cr({"id": "gloom_wolf", "display_name": "Gloom Wolf", "stats": _at_level(DEEP_LEVEL, {"max_hp": 6, "atk": 3, "def": 0, "spd": 100}),
			"essences": {"air": 1, "earth": 1}, "skills": [], "charges": true, "pack": true,
			"eat_bonus": {"stat": "spd", "amount": 2, "per": 2}, "xp": 6}),
		_cr({"id": "armed_ant", "display_name": "Armed Ant", "stats": _at_level(DEEP_LEVEL, {"max_hp": 5, "atk": 2, "def": 1, "spd": 90}),
			"essences": {"earth": 2}, "skills": [], "pack": true,
			"eat_bonus": {"stat": "def", "amount": 1, "per": 3}, "xp": 3}),
		_cr({"id": "stone_drake", "display_name": "Stone Drake", "stats": _at_level(DEEP_LEVEL, {"max_hp": 16, "atk": 4, "def": 3, "spd": 40}),
			"essences": {"earth": 4}, "skills": [], "armored_charger": true, "stomper": true,
			"eat_bonus": {"stat": "max_hp", "amount": 1, "per": 1}, "xp": 12}),
		_cr({"id": "taratect", "display_name": "Taratect", "stats": _at_level(DEEP_LEVEL, {"max_hp": 14, "atk": 5, "def": 1, "spd": 120}),
			"essences": {"water": 2, "dark": 2},
			"skills": [{"id": "sticky_thread", "level": 1}, {"id": "ceiling_walk", "level": 1}],
			"eat_bonus": {"stat": "atk", "amount": 2, "per": 1}, "xp": 12}),
		_cr({"id": "water_pool", "display_name": "Water Pool", "stats": {},
			"essences": {"water": 2}, "skills": [], "eat_bonus": {}}),
		_cr({"id": "serpent", "display_name": "Cave Serpent", "stats": {"max_hp": 40, "atk": 6, "def": 1, "spd": 90},
			"essences": {}, "skills": [{"id": "water_blade", "level": 1}, {"id": "constrict", "level": 1}],
			"eat_bonus": {}, "predatable": false, "appraisal_target": false, "xp": 20}),
	]
