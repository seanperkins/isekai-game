class_name DefLoader
extends RefCounted
## Loads every .tres resource in a directory, sorted by file name. A file that fails to
## load, or holds another resource type, is reported in `errors` instead of vanishing:
## a partial rule set must never run.

static func load_dir(dir_path: String, expected_class: String = "", errors: Array = [],
		loader: Callable = func(p: String) -> Resource: return load(p)) -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(dir_path):
		return out
	var files := Array(DirAccess.get_files_at(dir_path))
	files.sort()
	for f in files:
		var file_name: String = f.trim_suffix(".remap")  # exported builds rename resources
		if not file_name.ends_with(".tres"):
			continue
		var path := dir_path.path_join(file_name)
		var res: Resource = loader.call(path)
		if res == null:
			errors.append("%s: could not be loaded" % path)
			continue
		if expected_class != "" and _class_of(res) != expected_class:
			errors.append("%s: is not a %s" % [path, expected_class])
			continue
		out.append(res)
	return out

## Loads skill and creature content and validates it. `errors` empty means safe to run.
static func load_content(skills_dir: String, creatures_dir: String) -> Dictionary:
	var errors: Array = []
	var skills := load_dir(skills_dir, "SkillDef", errors)
	var creatures := load_dir(creatures_dir, "CreatureDef", errors)
	errors.append_array(Array(DefValidator.validate(skills, creatures)))
	return {"skills": skills, "creatures": creatures, "errors": errors}

static func _class_of(res: Resource) -> String:
	var script: Script = res.get_script()
	return script.get_global_name() if script != null else res.get_class()
