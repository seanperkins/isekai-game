class_name DefLoader
extends RefCounted
## Loads every .tres resource in a directory, sorted by file name.

static func load_dir(dir_path: String) -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(dir_path):
		return out
	var files := Array(DirAccess.get_files_at(dir_path))
	files.sort()
	for f in files:
		var file_name: String = f.trim_suffix(".remap")  # exported builds rename resources
		if not file_name.ends_with(".tres"):
			continue
		var res = load(dir_path.path_join(file_name))
		if res != null:
			out.append(res)
	return out
