extends SceneTree
## Writes the soul layer's data: res://data/species, perks, soul and goddess. Run once (then edit the .tres freely; the lines
## are Sean's copy to rewrite):
##   env HOME="$PWD/.tmp/gdhome" godot --headless -s tools/build_soul.gd

## cause (a creature id, "poison" or "spear") -> her line. One each; the loader cycles lists if more are added.
const CAUSE_LINES := {
	"armed_ant": "Outdone by an ant with a spear. I will not tell the others.",
	"bat": "A bat. Of all the things.",
	"bog_lizardman": "The lizardman did not even need the bog. Try the high ground.",
	"cave_crayfish": "A crayfish. Mind the claws, dear.",
	"drift_jelly": "You touched the jelly. Everyone touches the jelly.",
	"glass_eel": "The eel was nearly invisible. That is a reason, not an excuse.",
	"gloom_wolf": "A gloom wolf. Wolves do not forgive hesitation.",
	"lizard": "A lizard. Small, quick, and entirely unimpressed with you.",
	"mushroom_crab": "The crab, the caps, the whole sorry business.",
	"pale_moth": "Dusted by a moth. Dignity is not what it used to be.",
	"serpent": "The serpent. Do not look so surprised; it was long and it was hungry.",
	"spider": "Eight legs, and you watched the wrong ones.",
	"spore_moth": "Spores. You breathed them in and they did the rest.",
	"stone_drake": "The drake fell on you. That is what drakes are for.",
	"storm_eel": "A storm eel. Water and lightning: you knew better.",
	"taratect": "The taratect. I will allow that no one is ready for the taratect.",
	"toad": "A toad. I have decided not to ask.",
	"vine_snake": "The vine was a snake. The snake was a vine. Look closer next time.",
	"poison": "Poison is patient. You were not.",
	"spear": "A spear, thrown by someone who meant it.",
}
const MANY_DEATHS_LINES := [
	"That is another five. I count, so that you do not have to.",
	"You come back so often. I do not mind. Truly.",
	"Rest if you like. There is always another life.",
]
const FALLBACK_LINE := "Back so soon. Come, there is still time."

func _init() -> void:
	var failures := 0
	failures += _save(_slime(), "res://data/species/slime.tres")
	failures += _save(_stats_perk(), "res://data/perks/stats.tres")
	failures += _save(SoulRules.new(), "res://data/soul/soul_rules.tres")
	failures += _save(_lines(), "res://data/goddess/lines.tres")
	quit(1 if failures > 0 else 0)

func _slime() -> SpeciesDef:
	var d := SpeciesDef.new()
	d.id = "slime"
	d.display_name = "Slime"
	d.movement_profile = "slime"
	d.unlock = {"kind": "default"}
	return d

func _stats_perk() -> PerkDef:
	var p := PerkDef.new()
	p.id = "stats"
	p.display_name = "Stronger base stats"
	p.description = "+2 max HP and +1 max MP for every purchase, from your next life."
	p.altar = "C1"
	p.price_base = 5
	p.price_step = 3
	p.effects = [{"stat": "max_hp", "amount": 2}, {"stat": "max_mp", "amount": 1}]
	return p

func _lines() -> GoddessLines:
	var l := GoddessLines.new()
	for cause in CAUSE_LINES:
		l.by_cause[cause] = [CAUSE_LINES[cause]]
	l.many_deaths = MANY_DEATHS_LINES.duplicate()
	l.fallback = FALLBACK_LINE
	return l

func _save(res: Resource, path: String) -> int:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err := ResourceSaver.save(res, path)
	if err != OK:
		printerr("failed to save %s: %s" % [path, error_string(err)])
		return 1
	return 0
