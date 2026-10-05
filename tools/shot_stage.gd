class_name ShotStage
extends RefCounted
## Where the shot tools draw the game. Godot cannot render headless, so a tool needs a real window; this keeps that window a tiny one
## (tools/shot_run.sh makes it) and draws the game into a SubViewport of the size the frames should be, which the tool saves. A tool
## mounts its game with `view = ShotStage.mount(root, game)` and saves `view.get_texture()` where it used to save the root's.
## Input events pushed to the root do not reach a SubViewport: a tool that sends mouse events pushes them to `view`.

const VIEW := Vector2i(1280, 720)
const GAME := Vector2i(640, 360)  # the game's own resolution

## An empty stage `size` pixels big. With `game_size` set the 2D drawing is scaled up from that size to `size` (the game draws at
## 640x360, so a 1280x720 frame is the game at twice the size); ZERO draws one canvas unit to a pixel.
static func open(root: Window, size := VIEW, game_size := GAME) -> SubViewport:
	var view := SubViewport.new()
	view.size = size
	if game_size != Vector2i.ZERO:
		view.size_2d_override = game_size
		view.size_2d_override_stretch = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_skip_the_opening(root)
	root.add_child(view)
	print(window_line())  # the runner checks that the OS window was the tiny one
	return view

## A fresh profile plays the opening over every frame, so mark it seen, in memory only. A -s script's _initialize runs before the
## autoloads are ready (the Compendium has no `soul` yet), so then wait for its ready: it comes before the game's, which is added later.
static func _skip_the_opening(root: Window) -> void:
	var compendium = root.get_node_or_null("Compendium")  # an autoload, so untyped: a -s script cannot name it and Node has no `soul`
	if compendium == null:
		return
	if compendium.get("soul") != null:
		compendium.soul.opening_seen = true
	else:
		compendium.ready.connect(func() -> void: compendium.soul.opening_seen = true, CONNECT_ONE_SHOT)

## A stage with `node` in it.
static func mount(root: Window, node: Node, size := VIEW, game_size := GAME) -> SubViewport:
	var view := open(root, size, game_size)
	view.add_child(node)
	return view

static func resize(view: SubViewport, size: Vector2i) -> void:
	view.size = size

static func save(view: SubViewport, path: String) -> void:
	view.get_texture().get_image().save_png(path)

static func window_line() -> String:
	return "shots: window mode=%d size=%s" % [DisplayServer.window_get_mode(), DisplayServer.window_get_size()]
