class_name ShotRunner
extends RefCounted
## What the room MCP's menagerie_shot tool needs to take real pictures of the game. The MCP server is headless, so it cannot render:
## it runs tools/menagerie_shots.sh, which starts a second Godot with a tiny off-screen window (nothing takes over the screen), and
## reads the frames back. `run` is a Callable(argv: Array) -> {"code": int, "output": String}; tests hand in a fake.

const MAX_STOPS := 4
const MAX_X := 12000.0
## A creature is shown from this far left of it, so the slime is not drawn over it.
const VIEW_LEAD := 90.0
const SCRIPT := "res://tools/menagerie_shots.sh"
const FRAMES := "res://.tmp/menagerie-frames"
const DEFAULT_SCALE := 0.5
const OUTPUT_TAIL := 600

var frames_dir: String
var _run: Callable

func _init(p_run := Callable(), p_frames := FRAMES) -> void:
	_run = p_run if p_run.is_valid() else Callable(self, "_execute")
	frames_dir = p_frames

## The argv `env` is run with: the Godot to use for the second run, then the script and its stops (plain numbers, so nothing in it is
## shell syntax; there is no shell here anyway).
static func command(godot: String, script: String, stops: Array) -> Array:
	var argv: Array = ["GODOT=" + godot, "bash", script]
	for x in stops:
		argv.append(str(int(x)))
	return argv

## {"stops": [x, ...], "labels": [String, ...], "error": ""}: where the player stands for each picture. A creature is shown from
## VIEW_LEAD left of it; an x is used as given.
func stops_for(creature_ids: Array, xs: Array, defs: Array) -> Dictionary:
	var stops: Array = []
	var labels: Array = []
	for id in creature_ids:
		var x := Menagerie.x_of(str(id), defs)
		if x < 0.0:
			return {"stops": [], "labels": [], "error": "'%s' is not a creature in the menagerie (the water pool is terrain, not a creature)" % str(id)}
		stops.append(maxf(x - VIEW_LEAD, Menagerie.START.x))
		labels.append("x %d, in front of %s" % [int(stops[-1]), id])
	for x in xs:
		stops.append(float(x))
		labels.append("x %d" % int(x))
	if stops.is_empty():
		return {"stops": [], "labels": [], "error": "give at least one creature id or one x"}
	if stops.size() > MAX_STOPS:
		return {"stops": [], "labels": [], "error": "at most %d pictures at a time, not %d" % [MAX_STOPS, stops.size()]}
	return {"stops": stops, "labels": labels, "error": ""}

## Runs the script and reads the frames back, scaled: {"images": [Image, ...], "error": ""}.
func shoot(stops: Array, scale: float) -> Dictionary:
	var done: Dictionary = _run.call(command(OS.get_executable_path(), ProjectSettings.globalize_path(SCRIPT), stops))
	if int(done["code"]) != 0:
		var text := str(done["output"]).strip_edges()
		return {"images": [], "error": "the screenshot run failed (exit %d): %s" % [int(done["code"]), text.substr(maxi(0, text.length() - OUTPUT_TAIL))]}
	var images: Array = []
	for i in stops.size():
		var path := "%s/stop_%d.png" % [ProjectSettings.globalize_path(frames_dir), i]
		var img: Image = Image.load_from_file(path) if FileAccess.file_exists(path) else null
		if img == null:
			return {"images": [], "error": "the run finished but frame %d is missing" % i}
		if scale != 1.0:
			img.resize(maxi(1, int(img.get_width() * scale)), maxi(1, int(img.get_height() * scale)), Image.INTERPOLATE_NEAREST)
		images.append(img)
	return {"images": images, "error": ""}

func _execute(argv: Array) -> Dictionary:
	var output: Array = []
	var code := OS.execute("/usr/bin/env", argv, output, true)
	return {"code": code, "output": "\n".join(output)}
