extends SceneTree
## Writes the opening's data: res://data/opening/opening.tres. Run once (then edit the .tres freely):
##   env HOME="$PWD/.tmp/gdhome" godot --headless -s tools/build_opening.gd
## It is its own generator so that re-running tools/build_soul.gd never overwrites Sean's edited soul copy.
## Every line below is PLACEHOLDER copy for Sean to rewrite: three rounds, five commands, and every command fails (except the first Dodge, which works once, and the old lady's round, where only saving her can be picked).

const CHOICES := [
	{"id": "fight", "label": "Fight"},
	{"id": "dodge", "label": "Dodge"},
	{"id": "jump", "label": "Jump"},
	{"id": "pray", "label": "Pray"},
	{"id": "run", "label": "Run"},
]
const TRUCKS := [
	{"prompt": "A truck is coming.", "results": {
		"fight": "You swing your umbrella with all your heart. The truck is, tragically, a truck.",
		"dodge": "You step aside. The truck steps with you.",
		"jump": "You jump. The truck is taller than you thought.",
		"pray": "You pray. The truck is not a religious truck.",
		"run": "You run. The truck is faster than your plans.",
	}},
	{"prompt": "Another truck is coming.", "results": {
		"fight": "You swing again, this time with feeling. The truck honks politely.",
		"dodge": "You dodge with real conviction. The truck finds you anyway.",
		"jump": "You jump higher. The truck was always going to be there when you landed.",
		"pray": "You pray harder. The truck arrives on time.",
		"run": "You run the other way. The road, it turns out, loops.",
	}},
	{"prompt": "Somehow, a third truck.", "results": {
		"fight": "One last swing. The umbrella folds. So, shortly, do you.",
		"dodge": "You dodge perfectly. It does not matter.",
		"jump": "You jump out of habit. The truck hits you out of habit too.",
		"pray": "You pray one last time. The truck is the answer.",
		"run": "You run, and you almost make it. Trucks do not respect almost.",
	}},
]
const DODGE_SUCCESS := "You dodge! The truck roars past and misses you completely. Then you hear a second engine."
const SECOND_TRUCK := "A second truck pulls in beside the first. There are two of them now."
const GRANDMA := {
	"id": "grandma",
	"label": "Save Grandma",
	"prompt": "An old lady has stepped into the road, right in front of the trucks!",
	"result": "You shove her out of the way. The trucks, regrettably, do not stop.",
}
const FALLBACK_LINE := "The truck does not care what you chose."
const GODDESS_LINE := "I am so sorry. That truck was never meant to be there. Come, let me make it up to you."

func _init() -> void:
	var failures := 0
	failures += _save(_opening(), "res://data/opening/opening.tres")
	quit(1 if failures > 0 else 0)

func _opening() -> OpeningDef:
	var d := OpeningDef.new()
	d.choices = CHOICES.duplicate(true)
	d.trucks = TRUCKS.duplicate(true)
	d.fallback = FALLBACK_LINE
	d.goddess_line = GODDESS_LINE
	d.dodge_success = DODGE_SUCCESS
	d.second_truck = SECOND_TRUCK
	d.grandma = GRANDMA.duplicate(true)
	return d

func _save(res: Resource, path: String) -> int:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err := ResourceSaver.save(res, path)
	if err != OK:
		printerr("failed to save %s: %s" % [path, error_string(err)])
		return 1
	return 0
