class_name AudioSettings
extends RefCounted
## The four volume sliders (0..1). Saved in the Profile under `audio`; applied to the buses.
## A slider at 0 mutes its buses: linear_to_db(0) is -inf and must never reach AudioServer.

const KEYS := ["master", "music", "ambience", "sfx"]
const LABELS := {"master": "Master", "music": "Music", "ambience": "Ambience", "sfx": "Effects"}
const BUS_OF := {"master": ["Master"], "music": ["Music"], "ambience": ["Ambience"],
	"sfx": ["SFX_Player", "SFX_Enemy", "SFX_World"]}
const DEFAULT := 0.8
const STEP := 0.1
const FLOOR_LINEAR := 0.0001

var values := {}
var dirty := false

func _init() -> void:
	_reset()

func _reset() -> void:
	for k in KEYS:
		values[k] = DEFAULT

func load_from(profile: Profile) -> void:
	_reset()
	var raw := profile.dict_section("audio")
	for k in KEYS:
		var v = raw.get(k)
		if (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and float(v) >= 0.0 and float(v) <= 1.0:
			values[k] = float(v)
	dirty = false

func save_to(profile: Profile) -> bool:
	profile.set_section("audio", values.duplicate())
	dirty = false
	return profile.save()

func set_value(key: String, v: float) -> void:
	values[key] = clampf(snappedf(v, 0.05), 0.0, 1.0)
	dirty = true

func adjust(key: String, direction: int) -> void:
	set_value(key, float(values[key]) + direction * STEP)

func apply() -> void:
	for k in KEYS:
		for bus_name in BUS_OF[k]:
			var i := AudioServer.get_bus_index(bus_name)
			if i == -1:
				continue
			AudioServer.set_bus_mute(i, float(values[k]) <= 0.0)
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(float(values[k]), FLOOR_LINEAR)))
