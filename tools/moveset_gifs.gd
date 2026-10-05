extends SceneTree
## Real-renderer captures of each species' moveset, played in the movement sandbox by scripted input, one PNG sequence per clip.
## Run from the project root, windowed and unsandboxed (tools/art/moveset_gifs.py assembles the GIFs and movesets.json):
##   mkdir -p .tmp/moveset-gifs && D=$(mktemp -d .tmp/moveset-gifs/run.XXXXXX)
##   env HOME="$PWD/.tmp/gdhome" TMPDIR="$PWD/$D" gtimeout -k 5 600 godot --path . --windowed --resolution 640x360 --fixed-fps 60 \
##     -s res://tools/moveset_gifs.gd -- --out="$PWD/$D" [--only=wolf-pounce,slime] [--trace]
## Writes <out>/<species>-<clip>/NNNN.png and <out>/manifest.json (and <out>/trace.txt with --trace). The engine runs on a fixed
## 60 Hz clock (--fixed-fps 60), so one rendered frame is exactly one physics tick, and every STRIDE-th tick is kept. Nothing here
## changes the game: it sets MovementSandbox.scripted (the input the sandbox reads instead of the keyboard), moves the camera,
## hides the sandbox's help text, and draws a row of key chips and a verb readout for what the script is "pressing".

const STRIDE := 2
const DEFAULT_SIZE := Vector2i(640, 360)
const SANDBOX := "res://scenes/movement_sandbox.tscn"
const CLEAR := Color(0.07, 0.07, 0.11)
const CHIP_ON := Color(0.95, 0.8, 0.3)
const CHIP_OFF := Color(0.2, 0.2, 0.28)
const DUMMY_COLOR := Color(0.85, 0.25, 0.25, 0.7)
const DUMMY_HIT := Color(1.0, 0.95, 0.6, 1.0)
## How many ticks a tapped key (jump, the signature button) stays lit on its chip, and how long a verb name lingers after it ends.
const TAP_LIT := 8
const NAME_LINGER := 14
## A taller view for clips that jump: 3x pixels, 267 x 160 world px.
const TALL := Vector2i(800, 480)

var out_dir := ""
var only := PackedStringArray()
var trace := false
var trace_file: FileAccess
var sb: MovementSandbox
var cam: Camera2D
var win := DEFAULT_SIZE
var meta: Array = []
var rec := false
var rec_dir := ""
var rec_count := 0
var rec_stride := STRIDE
var rec_slow := 1
var tick := 0
var bad_frames := 0
var follow_x := false
var follow_y := false
var follow_off := Vector2.ZERO
var hit_flash := 0
var was_hit := false
var chips := {}
var lit := {"jump": 0, "sig": 0}
var hud_layer: CanvasLayer
var action_label: Label
var action_name := ""
var action_age := 0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a == "--trace":
			trace = true
		elif a.begins_with("--only="):
			only = a.substr(7).split(",", false)
	if out_dir == "":
		out_dir = ProjectSettings.globalize_path("res://.tmp/moveset-gifs/frames")
	DirAccess.make_dir_recursive_absolute(out_dir)
	if trace:
		trace_file = FileAccess.open(out_dir.path_join("trace.txt"), FileAccess.WRITE)
	RenderingServer.set_default_clear_color(CLEAR)
	if root.has_node("Controls"):
		root.get_node("Controls").mouse_aim = false  # autoloads are not compile-time names in a -s script
	_run()

func _run() -> void:
	await process_frame  # the tree is only ready after the first frame: add_child before it does not run _ready yet
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)  # project.godot asks for fullscreen
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED  # 1 canvas unit = 1 pixel: the camera zoom is the only scale
	await _fit(DEFAULT_SIZE)
	await _slime()
	await _biped()
	await _wolf()
	await _spider()
	_write_manifest()
	print("moveset_gifs: wrote ", meta.size(), " clips to ", out_dir, ", wrong-size frames: ", bad_frames)
	quit()

# --- plumbing ---

## The manifest keeps the clips of earlier runs into the same directory that this run did not redo (so one clip can be recaptured).
func _write_manifest() -> void:
	var path := out_dir.path_join("manifest.json")
	var clips: Array = []
	if FileAccess.file_exists(path):
		var old = JSON.parse_string(FileAccess.get_file_as_string(path))
		if old is Dictionary:
			for c in old.get("clips", []):
				var redone := false
				for m in meta:
					redone = redone or (m["species"] == c["species"] and m["id"] == c["id"])
				if not redone:
					clips.append(c)
	clips.append_array(meta)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"tick_hz": 60, "clips": clips}, "  "))
	f.close()

## Puts the window at `size` pixels. macOS re-applies its own size a little after a mode or size change, so keep setting ours for a
## while in real time (the fixed clock does not wait).
func _fit(size: Vector2i) -> void:
	win = size
	for _k in 40:
		await process_frame
		OS.delay_msec(10)
		DisplayServer.window_set_size(size)
	assert(root.size == size, "the window is %s, not %s" % [root.size, size])

## A fresh sandbox (no leftover dust, thread or box shape), the species picked and the body put at `pos`.
## opts: size (the window, 640x360), zoom (2), cam (the fixed centre, world px, default the body), follow ("x", "y" or "xy": the camera
## tracks the body on those axes), off (the follow offset), surface (the spider's starting surface normal), dummy (show the hostile
## dummy), blocks (extra solid Rect2s, built by the sandbox's own _block), settle (physics ticks before recording, 30: the landing
## squash is over), boost; and for `_clip`: stride (the ticks between frames, 2) and slow (playback slowdown, 1).
func _setup(species: String, pos: Vector2, opts := {}) -> void:
	if sb != null:
		sb.queue_free()
		await process_frame
	var size: Vector2i = opts.get("size", DEFAULT_SIZE)
	if size != win:
		await _fit(size)
	sb = load(SANDBOX).instantiate()
	root.add_child(sb)
	sb.scripted = MoveInput.new()
	sb.set_profile(species)
	sb.body.global_position = pos
	if opts.has("surface"):
		sb.state.surface_n = opts["surface"]
	sb._label.visible = false
	sb._dummy.visible = opts.get("dummy", false)
	sb._cam.enabled = false
	cam = Camera2D.new()
	var z: float = opts.get("zoom", 2.0)
	cam.zoom = Vector2(z, z)
	var f: String = opts.get("follow", "")
	follow_x = f.contains("x")
	follow_y = f.contains("y")
	follow_off = opts.get("off", Vector2.ZERO)
	cam.position = opts.get("cam", pos + follow_off)
	sb.add_child(cam)
	cam.make_current()
	for r in opts.get("blocks", []):
		sb._block(r)
	if opts.get("boost", false):
		sb.set_boost(true)
	hit_flash = 0
	was_hit = false
	action_name = ""
	action_age = 0
	lit = {"jump": 0, "sig": 0}
	_make_hud()
	rec = false
	await _t(opts.get("settle", 30))

func _make_hud() -> void:
	if hud_layer != null:
		hud_layer.queue_free()
	hud_layer = CanvasLayer.new()
	root.add_child(hud_layer)
	chips = {}
	var x := 8.0
	var specs := [["left", "<", 18.0], ["right", ">", 18.0], ["up", "^", 18.0], ["down", "v", 18.0], ["jump", "SPACE", 46.0], ["sig", "J", 18.0]]
	for s in specs:
		var panel := ColorRect.new()
		panel.size = Vector2(s[2] * 1.2, 22.0)
		panel.position = Vector2(x, 8.0)
		panel.color = CHIP_OFF
		var label := Label.new()
		label.text = s[1]
		label.add_theme_font_size_override("font_size", 13)
		label.size = panel.size
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(label)
		hud_layer.add_child(panel)
		chips[s[0]] = {"panel": panel, "label": label}
		x += s[2] * 1.2 + 4.0
	action_label = Label.new()
	action_label.position = Vector2(8.0, 36.0)
	action_label.add_theme_font_size_override("font_size", 17)
	action_label.add_theme_color_override("font_color", CHIP_ON)
	hud_layer.add_child(action_label)
	hud_layer.visible = false

## Starts recording a clip (every `stride`-th tick from here on, to play back `slow` times slower than it happened); `_end_clip` closes it.
func _begin(species: String, id: String, stride := STRIDE, slow := 1) -> void:
	rec_dir = out_dir.path_join("%s-%s" % [species, id])
	DirAccess.make_dir_recursive_absolute(rec_dir)
	rec_count = 0
	rec_stride = stride
	rec_slow = slow
	tick = 0
	rec = true
	hud_layer.visible = true

func _end_clip(species: String, id: String) -> void:
	rec = false
	meta.append({"species": species, "id": id, "frames": rec_count, "stride": rec_stride, "slow": rec_slow, "dir": "%s-%s" % [species, id], "size": [win.x, win.y]})
	print("clip ", species, "-", id, " ", rec_count, " frames")

## `_setup` then `_begin`, for the common case.
func _clip(species: String, id: String, pos: Vector2, opts := {}) -> void:
	await _setup(species, pos, opts)
	_begin(species, id, opts.get("stride", STRIDE), opts.get("slow", 1))

## Whether a clip is wanted (the --only filter: "wolf" for a species, "wolf-pounce" for a clip).
func _want(species: String, id: String) -> bool:
	return only.is_empty() or only.has("%s-%s" % [species, id]) or only.has(species)

## Advances n physics ticks. Each one resumes at the start of a tick, when the viewport still shows the render of the one before.
func _t(n: int) -> void:
	for _k in n:
		await physics_frame
		_frame()

## Waits (up to `limit` ticks) for `cond`; true if it came true.
func _until(cond: Callable, limit: int) -> bool:
	for _k in limit:
		if cond.call():
			return true
		await _t(1)
	return cond.call()

func _frame() -> void:
	if root.size != win:
		DisplayServer.window_set_size(win)  # the window manager moved it: put it back (a frame at the wrong size is rejected below)
	if (follow_x or follow_y) and is_instance_valid(sb.body):
		var target: Vector2 = sb.body.global_position + follow_off
		if follow_x:
			cam.position.x = roundf(target.x * 2.0) / 2.0
		if follow_y:
			cam.position.y = roundf(target.y * 2.0) / 2.0
	lit["jump"] = maxi(0, lit["jump"] - 1)
	lit["sig"] = maxi(0, lit["sig"] - 1)
	var sc: MoveInput = sb.scripted
	var aim := sc.aim
	_chip("left", sc.dir < -0.3 or aim.x < -0.3)
	_chip("right", sc.dir > 0.3 or aim.x > 0.3)
	_chip("up", sc.up > 0.3 or aim.y < -0.3)
	_chip("down", sc.down > 0.3 or aim.y > 0.3)
	_chip("jump", sc.jump_held or lit["jump"] > 0)
	_chip("sig", lit["sig"] > 0)
	_name_the_move()
	_flash_dummy()
	if not rec:
		return
	if trace and tick % rec_stride == 0:
		trace_file.store_line("%s t=%d pos=(%.0f,%.0f) v=(%.0f,%.0f) verb=%s clip=%s launched=%s surf=%s zip=%s drop=%s mantle=%s skid=%s clinging=%s hit=%s" % [
			rec_dir.get_file(), tick, sb.body.global_position.x, sb.body.global_position.y, sb.body.velocity.x, sb.body.velocity.y,
			sb.state.verb, sb.clip(), sb.state.launched, sb.state.surface_n, sb.state.zip_event, sb.state.drop_event, sb.state.mantle_event,
			sb.state.skidding, sb.state.clinging, sb.state.pounce_hit])
	if tick % rec_stride == 0:
		var img := root.get_texture().get_image()
		if img.get_size() != win:
			bad_frames += 1
			push_error("frame at %s, not %s" % [img.get_size(), win])
		img.save_png(rec_dir.path_join("%04d.png" % rec_count))
		rec_count += 1
	tick += 1

func _chip(id: String, on: bool) -> void:
	(chips[id]["panel"] as ColorRect).color = CHIP_ON if on else CHIP_OFF
	(chips[id]["label"] as Label).add_theme_color_override("font_color", Color(0.1, 0.1, 0.12) if on else Color(0.95, 0.95, 1.0))

## The name of what the body is doing right now, read from the sandbox's own state (it lingers a moment so a short verb can be read).
func _name_the_move() -> void:
	var s: MoveState = sb.state
	var now := ""
	if s.zip_dir != Vector2.ZERO:
		now = "web zip"
	elif s.drop_up > 0.0:
		now = "silk drop"
	elif s.mantle_left > 0.0:
		now = "mantle"
	elif s.verb != "":
		now = s.verb
	elif s.launched == "vault":
		now = "vault"
	elif s.launched == "wall":
		now = "wall jump"
	elif sb.clip() == "ball" or s.wall_bounced:
		now = "bounce"
	elif s.skidding:
		now = "skid"
	elif sb.profile.id == "wolf" and sb.clip() == "charge":
		now = "gallop"
	elif s.clinging:
		now = "wall cling" if s.velocity.y < 30.0 and s.wall_stick > 0.0 else "wall slide"
	elif s.spread and sb.profile.id == "slime":
		now = "flat"
	elif s.surface_n != Vector2.ZERO and sb.profile.id == "spider":
		now = "floor" if s.surface_n == Vector2.UP else ("ceiling" if s.surface_n == Vector2.DOWN else "wall")
	if now != "":
		action_name = now
		action_age = 0
	else:
		action_age += 1
		if action_age > NAME_LINGER:
			action_name = ""
	action_label.text = action_name

## The dummy marks contact and does nothing else; light it for a moment when the pounce touches it (capture only).
func _flash_dummy() -> void:
	if not sb._dummy.visible:
		return
	var hit: bool = sb.state.pounce_hit
	if hit and not was_hit:
		hit_flash = 16
	was_hit = hit
	hit_flash = maxi(0, hit_flash - 1)
	(sb._dummy.get_child(1) as ColorRect).color = DUMMY_HIT if hit_flash > 0 else DUMMY_COLOR

# --- input helpers (the scripted MoveInput) ---

func _dir(v: float) -> void:
	sb.scripted.dir = v

func _hold_jump(on: bool) -> void:
	sb.scripted.jump_held = on

## A press of Space; `hold` keeps it down until `_hold_jump(false)`.
func _jump_press(hold := true) -> void:
	sb.scripted.jump_pressed = true
	sb.scripted.jump_held = hold
	lit["jump"] = TAP_LIT

## A press of the signature button (J), with the aim the stick or pointer gives.
func _sig(aim := Vector2.ZERO) -> void:
	sb.scripted.signature_pressed = true
	sb.scripted.aim = aim
	lit["sig"] = TAP_LIT

func _aim(v: Vector2) -> void:
	sb.scripted.aim = v

func _down(v: float) -> void:
	sb.scripted.down = v

func _up(v: float) -> void:
	sb.scripted.up = v

## Lets go of everything held.
func _release() -> void:
	sb.scripted.dir = 0.0
	sb.scripted.down = 0.0
	sb.scripted.up = 0.0
	sb.scripted.aim = Vector2.ZERO
	sb.scripted.jump_held = false

# --- the clips ---

## A low, wide view for clips along the floor: 3x pixels, 280 x 80 world px with the floor line at the bottom, centred on `x`.
func _ground(x: float) -> Dictionary:
	return {"size": Vector2i(840, 240), "zoom": 3.0, "cam": Vector2(x, -34)}

## Runs right then back left on the open floor (the species' own top speed), ending where it began.
func _run_there_and_back(species: String, id: String, there: int, back: int) -> void:
	await _clip(species, id, Vector2(60, -12), _ground(140))
	await _t(14)
	_dir(1.0)
	await _t(there)
	_dir(-1.0)
	await _t(back)
	_release()
	await _t(24)
	_end_clip(species, id)

func _slime() -> void:
	if _want("slime", "run"):
		await _run_there_and_back("slime", "run", 62, 62)
	if _want("slime", "jump"):
		await _clip("slime", "jump", Vector2(372, -12), {"size": TALL, "zoom": 3.0, "cam": Vector2(466, -62)})
		await _t(14)
		_jump_press(false)  # a tap: a short hop
		await _t(40)
		_dir(1.0)
		_jump_press(true)  # held: clears the 40 px ledge
		await _t(24)
		_hold_jump(false)
		await _until(func(): return sb.body.is_on_floor(), 60)
		_dir(0.0)
		await _t(24)
		_dir(1.0)
		await _t(10)
		_jump_press(true)  # held: the 60 px ledge, with the base jump to spare of 3 px
		await _t(26)
		_hold_jump(false)
		await _until(func(): return sb.body.is_on_floor(), 60)
		_dir(0.0)
		await _t(30)
		_end_clip("slime", "jump")
	if _want("slime", "bounce"):
		await _clip("slime", "bounce", Vector2(110, -125), {"cam": Vector2(200, -70), "settle": 1})
		_hold_jump(true)
		await _t(170)
		_hold_jump(false)
		await _t(50)
		_end_clip("slime", "bounce")
	if _want("slime", "tackle"):
		var view := _ground(140)
		view["stride"] = 1
		view["slow"] = 2
		await _clip("slime", "tackle", Vector2(60, -12), view)
		await _t(14)
		for _k in 2:
			_sig()
			await _t(34)
		await _t(20)
		_end_clip("slime", "tackle")
	if _want("slime", "puddle"):
		await _clip("slime", "puddle", Vector2(850, -12), {"size": Vector2i(1080, 240), "zoom": 3.0, "cam": Vector2(1005, -34)})
		await _t(14)
		_dir(1.0)
		await _t(14)
		_down(1.0)
		await _until(func(): return sb.body.global_position.x > 1138.0, 400)
		_down(0.0)  # nearly out of the tunnel: it stays flat until there is room, then stands
		await _until(func(): return not sb.state.spread and not sb.state.crouched, 120)
		_release()
		await _t(30)
		_end_clip("slime", "puddle")
	if _want("slime", "wall"):
		await _clip("slime", "wall", Vector2(1318, -12), {"size": Vector2i(360, 560), "cam": Vector2(1350, -125)})
		await _t(14)
		await _climb_the_shaft(4)
		_end_clip("slime", "wall")

## From the floor beside the pillar: into the pillar's face and up, then a kick off each wall in turn across the shaft.
func _climb_the_shaft(kicks: int) -> void:
	var side := -1.0
	_dir(side)
	_jump_press(true)
	for _k in kicks:
		await _until(func(): return sb.state.clinging, 90)
		await _t(10)
		side = -side
		_dir(side)
		_jump_press(true)
		await _t(12)
		_hold_jump(false)
	await _until(func(): return sb.state.clinging, 90)
	await _t(24)
	_release()  # let go: it falls down the wall to the floor, about where it began
	await _until(func(): return sb.body.is_on_floor(), 150)
	await _t(30)

func _biped() -> void:
	if _want("biped", "run"):
		await _run_there_and_back("biped", "run", 62, 62)
	if _want("biped", "jump"):
		await _clip("biped", "jump", Vector2(96, -12), {"size": TALL, "zoom": 3.0, "cam": Vector2(150, -50)})
		await _t(14)
		_jump_press(false)  # a tap: a short hop
		await _t(40)
		_dir(1.0)
		_jump_press(true)  # held: up through the thin ledge and onto it
		await _t(26)
		_hold_jump(false)
		await _until(func(): return sb.body.is_on_floor(), 60)
		_dir(0.0)
		await _t(30)
		_end_clip("biped", "jump")
	if _want("biped", "roll"):
		await _clip("biped", "roll", Vector2(100, -12), _ground(140))
		await _t(14)
		_sig()
		await _t(40)
		_dir(-1.0)
		_sig()
		await _t(2)
		_dir(0.0)
		await _t(46)
		_end_clip("biped", "roll")
	if _want("biped", "slide"):
		await _clip("biped", "slide", Vector2(50, -12), _ground(140))
		await _t(14)
		_dir(1.0)
		await _t(22)
		_sig()
		await _t(34)
		_dir(0.0)
		await _t(36)
		_end_clip("biped", "slide")
	if _want("biped", "dropthrough"):
		await _clip("biped", "dropthrough", Vector2(200, -62), {"zoom": 3.0, "size": TALL, "cam": Vector2(200, -50)})
		await _t(16)
		_down(1.0)
		await _t(6)
		_down(0.0)
		await _until(func(): return sb.body.is_on_floor() and sb.body.global_position.y > -20.0, 90)
		await _t(20)
		_jump_press(true)  # and back up through it from below
		await _t(30)
		_hold_jump(false)
		await _until(func(): return sb.body.is_on_floor(), 90)
		await _t(24)
		_end_clip("biped", "dropthrough")
	if _want("biped", "mantle"):
		await _clip("biped", "mantle", Vector2(490, -12), {"size": TALL, "zoom": 3.0, "cam": Vector2(545, -50), "stride": 1, "slow": 2})
		await _t(14)
		_dir(1.0)
		_jump_press(true)
		await _until(func(): return sb.state.mantle_event == "stand", 80)
		_hold_jump(false)
		await _t(10)
		_dir(0.0)
		await _t(36)
		_end_clip("biped", "mantle")
	if _want("biped", "walljump"):
		await _clip("biped", "walljump", Vector2(1318, -12), {"size": Vector2i(360, 560), "cam": Vector2(1350, -125)})
		await _t(14)
		await _climb_the_shaft(4)
		_end_clip("biped", "walljump")

func _wolf() -> void:
	if _want("wolf", "gallop"):
		await _clip("wolf", "gallop", Vector2(90, -12), _ground(150))
		await _t(14)
		_dir(1.0)
		await _t(54)
		_dir(0.0)
		await _t(24)
		_dir(-1.0)
		await _t(44)
		_dir(0.0)
		await _t(30)
		_end_clip("wolf", "gallop")
	if _want("wolf", "skid"):
		var view := _ground(150)
		view["stride"] = 1
		view["slow"] = 2
		await _clip("wolf", "skid", Vector2(90, -12), view)
		await _t(8)
		_dir(1.0)
		await _t(44)
		_dir(-1.0)  # the reversal at a gallop
		await _t(26)
		_dir(0.0)
		await _t(30)
		_end_clip("wolf", "skid")
	if _want("wolf", "pounce"):
		var view := _ground(115)
		view["dummy"] = true
		view["stride"] = 1
		view["slow"] = 2
		await _clip("wolf", "pounce", Vector2(80, -12), view)
		await _t(10)
		_sig(Vector2(1.0, -1.0).normalized())
		await _t(3)
		_aim(Vector2.ZERO)
		await _t(62)
		_sig(Vector2(-1.0, -1.0).normalized())
		await _t(3)
		_aim(Vector2.ZERO)
		await _t(40)
		_end_clip("wolf", "pounce")
	if _want("wolf", "vault"):
		# the sandbox's own 16 px step sits 20 px from the left wall, too close for the wolf to land past it: one more, in the open
		var view := _ground(150)
		view["blocks"] = [Rect2(130, -16, 25, 16)]
		await _clip("wolf", "vault", Vector2(255, -12), view)
		await _t(14)
		_dir(-1.0)
		await _until(func(): return sb.body.global_position.x < 125.0, 140)  # still in the air over the step: the leap keeps its speed, so let go early
		_dir(0.0)
		await _t(40)
		_end_clip("wolf", "vault")

func _spider() -> void:
	var spot := {"size": Vector2i(480, 560), "cam": Vector2(825, -110)}
	if _want("spider", "crawl"):
		await _clip("spider", "crawl", Vector2(740, -12), spot)
		await _t(14)
		_dir(1.0)
		var seen := {}
		await _until(func():
			seen[sb.state.surface_n] = true
			return seen.size() >= 4 and sb.state.surface_n == Vector2.UP and sb.body.global_position.x > 810.0 and sb.body.global_position.y > -20.0, 1200)
		await _t(20)
		_release()
		await _t(30)
		_end_clip("spider", "crawl")
	if _want("spider", "zip"):
		var view := spot.duplicate()
		view["stride"] = 1
		view["slow"] = 2
		await _clip("spider", "zip", Vector2(850, -12), view)
		await _t(14)
		_sig(Vector2.UP)
		await _t(3)
		_aim(Vector2.ZERO)
		await _until(func(): return sb.state.surface_n == Vector2.DOWN, 60)
		await _t(40)
		_sig(Vector2(-1.0, 1.0).normalized())
		await _t(3)
		_aim(Vector2.ZERO)
		await _until(func(): return sb.state.surface_n == Vector2.RIGHT, 60)
		await _t(50)
		_end_clip("spider", "zip")
	if _want("spider", "drop"):
		await _clip("spider", "drop", Vector2(830, -138), {"size": Vector2i(480, 560), "cam": Vector2(825, -110), "surface": Vector2.DOWN})
		await _t(20)
		_down(1.0)
		await _t(26)
		_down(0.0)
		_up(1.0)
		await _t(22)
		_up(0.0)
		_down(1.0)
		await _until(func(): return sb.state.drop_event == "land", 240)
		_down(0.0)
		await _t(36)
		_end_clip("spider", "drop")
	if _want("spider", "slick"):
		await _clip("spider", "slick", Vector2(200, -12), {"size": Vector2i(480, 560), "cam": Vector2(300, -110)})
		await _t(14)
		_sig(Vector2.RIGHT)  # from 100 px away, well in range: a zip at a slick block fizzles
		await _t(3)
		_aim(Vector2.ZERO)
		await _t(34)
		_dir(1.0)
		await _t(80)  # crawls up to the slick face and stops
		_jump_press(false)  # a hop at it does not grip
		await _t(60)
		_release()
		await _t(30)
		_end_clip("spider", "slick")
