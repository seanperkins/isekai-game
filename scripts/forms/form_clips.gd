class_name FormClips
extends RefCounted
## data/form_clips.json (tools/art/blender/export_forms.py): the clips of every animated form, {form id: {state: {frames, fps, loop}}}, and under
## "_walk_speeds" the speed in sprite pixels per second each form's walk was built for. A form's frames are the sheet `anim_<form id>`.

static var _cache := {}

static func _all() -> Dictionary:
	var path := Enemy.form_clips_path
	if not _cache.has(path):
		_cache[path] = SlimeAnimator.load_clips(path) if FileAccess.file_exists(path) else {}
	return _cache[path]

## Whether this form has clips (the speed table is not a form).
static func has_form(id: String) -> bool:
	return not id.begins_with("_") and typeof(_all().get(id)) == TYPE_DICTIONARY

static func clips_of(id: String) -> Dictionary:
	return _all().get(id, {}) if has_form(id) else {}

## The speed the form's walk was built for; a form with none recorded walks at the enemy default.
static func walk_speed_of(id: String) -> float:
	var speeds = _all().get("_walk_speeds")
	return float((speeds as Dictionary).get(id, Enemy.BASE_SPEED)) if speeds is Dictionary else Enemy.BASE_SPEED

static func sheet_of(id: String) -> String:
	return "anim_" + id
