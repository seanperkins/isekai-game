class_name CueCatalog
extends RefCounted
## data/audio/cues.json: playback rules per cue, which event plays which cue, each biome's beds, and the themes: tracks that take
## the music over from the room's bed for a while (the opening's battle). Pure data logic; Audio owns the players.

const ASSET_DIR := "res://assets/audio/"
const BUSES := ["Music", "Ambience", "SFX_Player", "SFX_Enemy", "SFX_World", "UI"]
const BIOMES := ["cave", "grotto", "flooded", "deep"]

var cues := {}
var events := {}
var biomes := {}
var themes := {}  # theme id -> {"music": file, "fade_in": seconds, "fade_out": seconds}
var _last := {}  # cue id -> index of the variant played last

static func load_file(path: String) -> CueCatalog:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return from_dict(data if typeof(data) == TYPE_DICTIONARY else {})

static func from_dict(data: Dictionary) -> CueCatalog:
	var c := CueCatalog.new()
	c.cues = data.get("cues", {})
	c.events = data.get("events", {})
	c.biomes = data.get("biomes", {})
	c.themes = data.get("themes", {})
	return c

## What an event does: {"cue": id} to play, {"stop": id} to end a looping cue, {"theme": id} to start a theme,
## {"theme_stop": id} to end it, {} for silence or an event the catalog does not know.
func route(event_name: String, tags: Dictionary) -> Dictionary:
	var entry = events.get(event_name)
	if entry == null:
		return {}
	if typeof(entry) == TYPE_STRING:
		return {"cue": entry}
	if typeof(entry) != TYPE_DICTIONARY:
		return {}
	if entry.has("stop"):
		return {"stop": entry["stop"]}
	if entry.has("theme"):
		return {"theme": entry["theme"]}
	if entry.has("theme_stop"):
		return {"theme_stop": entry["theme_stop"]}
	# JSON keys are strings, so a bool tag selects through its string form ("true" / "false").
	var picked = entry.get(str(tags.get(str(entry.get("by", "")), "")), entry.get("default"))
	return {"cue": picked} if typeof(picked) == TYPE_STRING else {}

## A res:// path for one of the cue's variants, never the same one twice in a row.
func pick_file(cue_id: String, rng: RandomNumberGenerator) -> String:
	var files: Array = cues.get(cue_id, {}).get("files", [])
	if files.is_empty():
		return ""
	var i := 0
	if files.size() > 1:
		i = rng.randi_range(0, files.size() - 1)
		if i == int(_last.get(cue_id, -1)):
			i = (i + 1 + rng.randi_range(0, files.size() - 2)) % files.size()
	_last[cue_id] = i
	return ASSET_DIR + str(files[i])

## Every mistake in the data, as readable strings. file_exists takes a res:// path.
func validate(file_exists: Callable) -> Array:
	var errors: Array = []
	for id in cues:
		var rule: Dictionary = cues[id]
		var files = rule.get("files")
		if typeof(files) != TYPE_ARRAY or files.is_empty() or files.size() > 4:
			errors.append("cue %s: files must list 1 to 4 variants" % id)
		else:
			for f in files:
				if not file_exists.call(ASSET_DIR + str(f)):
					errors.append("cue %s: missing file %s" % [id, f])
		if not BUSES.has(str(rule.get("bus", ""))):
			errors.append("cue %s: unknown bus '%s'" % [id, rule.get("bus", "")])
		var volume := float(rule.get("volume_db", 0.0))
		if volume < -40.0 or volume > 6.0:
			errors.append("cue %s: volume_db %s is outside -40..6" % [id, volume])
		var jitter := float(rule.get("pitch_jitter", 0.0))
		if jitter < 0.0 or jitter > 0.5:
			errors.append("cue %s: pitch_jitter %s is outside 0..0.5" % [id, jitter])
		if float(rule.get("cooldown", 0.0)) < 0.0:
			errors.append("cue %s: negative cooldown" % id)
	for name in events:
		if str(name).begins_with("_"):
			continue  # a "_why:<event>" comment
		var entry = events[name]
		if entry == null:
			if str(events.get("_why:" + str(name), "")).strip_edges() == "":
				errors.append("event %s: silent without a _why" % name)
			continue
		if typeof(entry) == TYPE_DICTIONARY and entry.has("stop"):
			if not bool(cues.get(entry["stop"], {}).get("loop", false)):
				errors.append("event %s: stop target %s is not a looping cue" % [name, entry["stop"]])
			continue
		if typeof(entry) == TYPE_DICTIONARY and (entry.has("theme") or entry.has("theme_stop")):
			var named = entry.get("theme", entry.get("theme_stop"))
			if not themes.has(named):
				errors.append("event %s: unknown theme %s" % [name, named])
			continue
		for target in _targets(entry):
			if not cues.has(target):
				errors.append("event %s: unknown cue %s" % [name, target])
	for id in themes:
		var theme = themes[id]
		if typeof(theme) != TYPE_DICTIONARY:
			errors.append("theme %s: must be an object" % id)
			continue
		if not file_exists.call(ASSET_DIR + str(theme.get("music", ""))):
			errors.append("theme %s: missing music file" % id)
		for key in ["fade_in", "fade_out"]:
			var seconds := float(theme.get(key, -1.0))
			if seconds < 0.0 or seconds > 10.0:
				errors.append("theme %s: %s must be 0..10" % [id, key])
	for area in BIOMES:
		var b = biomes.get(area)
		if typeof(b) != TYPE_DICTIONARY:
			errors.append("biome %s: missing" % area)
			continue
		for key in ["music", "ambience"]:
			if not file_exists.call(ASSET_DIR + str(b.get(key, ""))):
				errors.append("biome %s: missing %s file" % [area, key])
		var wet := float(b.get("reverb_wet", -1.0))
		if wet < 0.0 or wet > 1.0:
			errors.append("biome %s: reverb_wet must be 0..1" % area)
		var shots: Dictionary = b.get("oneshots", {})
		var shot_cues: Array = shots.get("cues", [])
		if shot_cues.is_empty():
			errors.append("biome %s: oneshots need at least one cue" % area)
		for cue_id in shot_cues:
			if not cues.has(cue_id):
				errors.append("biome %s: oneshot cue %s is unknown" % [area, cue_id])
		var interval: Array = shots.get("interval", [])
		if interval.size() != 2 or float(interval[0]) <= 0.0 or float(interval[1]) < float(interval[0]):
			errors.append("biome %s: oneshot interval must be [low, high] with 0 < low <= high" % area)
		if float(shots.get("radius", 0.0)) <= 0.0:
			errors.append("biome %s: oneshot radius must be above 0" % area)
	return errors

## The cue ids one event entry can play.
func _targets(entry) -> Array:
	if typeof(entry) == TYPE_STRING:
		return [entry]
	var out: Array = []
	if typeof(entry) == TYPE_DICTIONARY:
		for key in entry:
			if key != "by" and typeof(entry[key]) == TYPE_STRING:
				out.append(entry[key])
	return out
