class_name Art
extends RefCounted
## Style D sprites cut by tools/art/slice_sheets.py into res://assets/sprites/.

const DIR := "res://assets/sprites/%s.png"

## Texture for a sprite name from tools/art/manifest.json, or null when it doesn't exist.
static func texture(sprite_name: String) -> Texture2D:
	var path := DIR % sprite_name
	if not ResourceLoader.exists(path):
		return null
	return load(path)
