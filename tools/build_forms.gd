extends SceneTree
## Writes res://data/forms/*.tres from the table below. Run once (then edit the .tres freely):
##   env HOME="$PWD/.tmp/gdhome" godot --headless -s tools/build_forms.gd

const STAGE_SIZE := {2: 1.12, 3: 1.25, 4: 1.4}
## Every stage adds this much on top of the lineage's own flavour.
const STAGE_BASE := {
	2: {"max_hp": 5, "max_mp": 3},
	3: {"max_hp": 12, "max_mp": 6, "atk": 1},
	4: {"max_hp": 22, "max_mp": 10, "atk": 2, "def": 1},
}

## id: [display, stage, lineage, parents, tint, flavour stats, traits, grants, sprite_set, blurb]
static func table() -> Dictionary:
	var weaver_tint := Color(0.78, 0.7, 1.0)
	var tide_tint := Color(0.55, 0.8, 1.0)
	var toxic_tint := Color(0.65, 1.0, 0.55)
	var bulwark_tint := Color(0.9, 0.78, 0.6)
	var echo_tint := Color(0.95, 0.65, 1.0)
	var greater_tint := Color(1.0, 0.92, 0.7)
	return {
		"weaver": ["Weaver", 2, "weaver", ["slime"], weaver_tint, {"spd": 5}, ["spinner"], ["sticky_thread"], "form_weaver",
			"Silk spins inside you. Thread skills cost less."],
		"snare": ["Snare", 3, "weaver", ["weaver"], weaver_tint, {"def": 1}, ["spinner"], ["sticky_thread"], "form_snare",
			"A living net: heavier, and harder to shake off."],
		"arachne": ["Arachne", 3, "weaver", ["weaver"], weaver_tint, {"spd": 10}, ["spinner"], ["sticky_thread", "wall_cling"], "form_arachne",
			"Silk legs let you scale any wall."],
		"silkbound": ["Silkbound Sovereign", 4, "weaver", ["snare", "arachne"], Color(0.85, 0.75, 1.0), {"spd": 12, "def": 1}, ["spinner"], ["sticky_thread", "wall_cling"], "form_silkbound",
			"Crowned in silk. The web answers to you."],
		"tide": ["Tide", 2, "tide", ["slime"], tide_tint, {"mp_regen": 25}, ["water_thrift"], ["hydraulic_propulsion"], "",
			"Water sloshes eagerly inside you. Water skills cost less."],
		"brook": ["Brook", 3, "tide", ["tide"], tide_tint, {"mp_regen": 40}, ["water_thrift"], ["hydraulic_propulsion"], "",
			"A quick, clear current."],
		"tempest": ["Tempest", 3, "tide", ["tide"], tide_tint, {"mp_regen": 40, "atk": 1}, ["water_thrift"], ["hydraulic_propulsion"], "",
			"A storm held in a body."],
		"tidal": ["Tidal Sovereign", 4, "tide", ["brook", "tempest"], Color(0.6, 0.85, 1.0), {"mp_regen": 60}, ["water_thrift"], ["hydraulic_propulsion"], "",
			"The tide itself, wearing a body."],
		"toxic": ["Toxic", 2, "toxic", ["slime"], toxic_tint, {"atk": 1}, ["venom_blood"], ["poison_breath"], "",
			"Poison and spores run through you."],
		"acid": ["Acid", 3, "toxic", ["toxic"], toxic_tint, {"atk": 1}, ["venom_blood"], ["poison_breath"], "",
			"Corrosive: what touches you burns."],
		"blight": ["Blight", 3, "toxic", ["toxic"], toxic_tint, {"max_hp": 4}, ["venom_blood"], ["poison_breath", "poison_resistance"], "",
			"A creeping rot you are immune to."],
		"venom": ["Venom Sovereign", 4, "toxic", ["acid", "blight"], Color(0.7, 1.0, 0.6), {"atk": 2}, ["venom_blood"], ["poison_breath", "poison_resistance"], "",
			"Every breath is a warning."],
		"bulwark": ["Bulwark", 2, "bulwark", ["slime"], bulwark_tint, {"def": 1, "spd": -5}, ["hard_shell"], ["body_armor"], "",
			"Plated and steady: slower, tougher."],
		"golem": ["Golem", 3, "bulwark", ["bulwark"], bulwark_tint, {"def": 2, "spd": -8}, ["hard_shell"], ["body_armor", "toughness"], "",
			"Living stone."],
		"crystal": ["Crystal", 3, "bulwark", ["bulwark"], bulwark_tint, {"def": 2, "spd": -4}, ["hard_shell"], ["body_armor"], "",
			"A faceted body that turns blows aside."],
		"stone": ["Stone Sovereign", 4, "bulwark", ["golem", "crystal"], Color(0.95, 0.85, 0.65), {"def": 3, "spd": -6}, ["hard_shell"], ["body_armor", "toughness"], "",
			"A mountain that decided to move."],
		"echo": ["Echo", 2, "echo", ["slime"], echo_tint, {"spd": 10, "jump_height": 10}, ["sonar"], ["echolocation"], "",
			"You feel the shape of every room."],
		"phantom": ["Phantom", 3, "echo", ["echo"], echo_tint, {"spd": 12, "jump_height": 15}, ["sonar"], ["echolocation", "leap"], "",
			"Half a sound, half a body."],
		"sky": ["Sky", 3, "echo", ["echo"], echo_tint, {"spd": 8, "jump_height": 25}, ["sonar"], ["echolocation", "leap"], "",
			"Light enough to ride the air."],
		"storm": ["Storm Sovereign", 4, "echo", ["phantom", "sky"], Color(1.0, 0.75, 1.0), {"spd": 16, "jump_height": 30}, ["sonar"], ["echolocation", "leap"], "",
			"Thunder learned to walk."],
		"greater_slime": ["Greater Slime", 2, "greater", ["slime"], greater_tint, {"predation_time": -10}, ["adaptable"], ["regeneration"], "",
			"No lineage claimed you. Bigger, and good at recovering."],
		"vast": ["Vast Slime", 3, "greater", ["greater_slime"], greater_tint, {"max_hp": 6, "predation_time": -15}, ["adaptable"], ["regeneration", "toughness"], "",
			"Simply more of you."],
		"radiant": ["Radiant Slime", 3, "greater", ["greater_slime"], greater_tint, {"max_mp": 6, "predation_time": -15}, ["adaptable"], ["regeneration", "mana_recovery"], "",
			"A steady inner light."],
		"prime": ["Prime Sovereign", 4, "greater", ["vast", "radiant"], Color(1.0, 0.95, 0.75), {"predation_time": -25, "mp_regen": 25}, ["adaptable"], ["regeneration", "toughness", "mana_recovery"], "",
			"Everything a slime can become, all at once."],
	}

static func stats_for(stage: int, flavour: Dictionary) -> Dictionary:
	var out: Dictionary = (STAGE_BASE[stage] as Dictionary).duplicate()
	for k in flavour:
		out[k] = int(out.get(k, 0)) + int(flavour[k])
	return out

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/forms"))
	var failures := 0
	var t := table()
	for id in t:
		var row: Array = t[id]
		var f := FormDef.new()
		f.id = id
		f.display_name = row[0]
		f.stage = row[1]
		f.lineage = row[2]
		f.parents = row[3]
		f.tint = row[4]
		f.stats = stats_for(f.stage, row[5])
		f.traits = row[6]
		f.grants = row[7]
		f.sprite_set = row[8]
		f.blurb = row[9]
		f.size = STAGE_SIZE[f.stage]
		if f.stage == 2 and f.lineage != "greater":
			f.essences = essences_of(f.lineage)
		var path := "res://data/forms/%s.tres" % id
		var err := ResourceSaver.save(f, path)
		if err != OK:
			printerr("failed to save %s: %s" % [path, error_string(err)])
			failures += 1
	quit(1 if failures > 0 else 0)

static func essences_of(lineage: String) -> Array:
	match lineage:
		"weaver":
			return ["thread"]
		"tide":
			return ["water"]
		"toxic":
			return ["poison", "spore"]
		"bulwark":
			return ["armor", "earth", "shell"]
		"echo":
			return ["sound", "flight"]
	return []
