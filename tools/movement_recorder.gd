class_name MovementRecorder
extends Node
## Drives the movement sandbox (the game's own movement step on its own collision) through a scripted run and writes down where the body is every physics tick, so the
## 3D photo stage can move a rig along exactly that path (tools/art/blender/stage_review.py). Add it to the tree and `await record(species, script)`.
##
## A script is `{"start": Vector2 (feet, game px; optional), "steps": [...]}`. A step: `seconds` (the most it lasts), `dir` (-1 to 1), `up`, `down`, `jump` (a press on its
## first tick), `hold_jump` (the button stays down for the step), `signature` (a press on its first tick), `until_x` (ends early once the feet pass x, the way `dir`
## points) and `until_floor` (ends early once the body stands again, after a few ticks in the air).

const FPS := 60
const SCENE := "res://scenes/movement_sandbox.tscn"
const SETTLE_TICKS := 6
const AIR_TICKS := 6  # a jump is not over on the tick it starts

## The scripts a species can run: every one walks and jumps the ledges; the slime and the goblin kinds climb the shaft, the spider crawls, the wolf pounces.
const SCRIPTS_FOR := {
	"goblin": ["walk_run", "jump_ledges", "wall_shaft"],
	"undead": ["walk_run", "jump_ledges", "wall_shaft"],
	"slime": ["walk_run", "jump_ledges", "wall_shaft"],
	"wolf": ["walk_run", "jump_ledges", "pounce"],
	"spider": ["walk_run", "jump_ledges", "crawl"],
}

static func scripts_for(species: String) -> Array:
	return SCRIPTS_FOR.get(species, [])

static func make_script(script_name: String) -> Dictionary:
	match script_name:
		"walk_run":  # stand, walk, run, stop: the stride the walk cycle is judged against (it stops short of the slick block at x = 300)
			return {"steps": [
				{"seconds": 0.5},
				{"dir": 0.35, "until_x": 190.0, "seconds": 3.0},
				{"dir": 1.0, "until_x": 250.0, "seconds": 3.0},
				{"seconds": 1.0},
			]}
		"jump_ledges":  # from the floor between the slick block and the first ledge, hop up the three ledges, each from the edge of the last
			return {"start": Vector2(376.0, 0.0), "steps": [
				{"seconds": 0.3},
				{"dir": 1.0, "jump": true, "hold_jump": true, "seconds": 0.9, "until_floor": true},
				{"dir": 1.0, "until_x": 462.0, "seconds": 1.0},
				{"dir": 1.0, "jump": true, "hold_jump": true, "seconds": 0.9, "until_floor": true},
				{"dir": 1.0, "until_x": 585.0, "seconds": 1.0},
				{"dir": 1.0, "jump": true, "hold_jump": true, "seconds": 0.9, "until_floor": true},
				{"seconds": 0.6},
			]}
		"wall_shaft":  # up the shaft by the end wall, wall jump by wall jump: press into the wall to cling, then kick off it
			var steps: Array = [{"dir": 1.0, "seconds": 0.3}, {"dir": 1.0, "jump": true, "hold_jump": true, "seconds": 0.5}]
			var toward := 1.0
			for _k in 5:
				steps.append({"dir": toward, "seconds": 0.25})
				steps.append({"dir": -toward, "jump": true, "hold_jump": true, "seconds": 0.35})
				toward = -toward
			steps.append({"dir": toward, "seconds": 0.5})
			return {"start": Vector2(1380.0, 0.0), "steps": steps}
		"crawl":  # the spider up the pillar's wall, over the slab and under it, then down the far side
			return {"start": Vector2(728.0, 0.0), "steps": [
				{"seconds": 0.4},
				{"dir": 1.0, "until_x": 744.0, "seconds": 3.0},
				{"dir": 1.0, "up": 1.0, "seconds": 4.4},
				{"seconds": 0.5},
			]}
		"pounce":  # the wolf's signature leap at the dummy 20 px ahead of the start, then it stands
			return {"steps": [
				{"seconds": 0.5},
				{"dir": 1.0, "signature": true, "seconds": 0.6},
				{"seconds": 0.8},
			]}
	return {}

var profile_id := ""

## Runs `script_name` as `species` and returns `{"species", "script", "profile", "fps", "start", "ticks": [...]}`, or {} for a species or script it does not know. Each
## tick is `{"t", "x", "y", "vx", "vy", "facing", "verb", "on_floor", "surface", "normal"}`: x and y are the body's contact with what it stands on (the feet on a floor), in
## game px with y DOWN; `surface` is floor, wall, ceiling, air or mantle.
func record(species: String, script_name: String) -> Dictionary:
	profile_id = MovementProfile.SPECIES_PROFILE.get(species, "")
	var sc := make_script(script_name)
	if profile_id == "" or sc.is_empty() or not scripts_for(species).has(script_name):
		return {}
	var sb: MovementSandbox = load(SCENE).instantiate()
	add_child(sb)
	sb.scripted = MoveInput.new()
	sb.set_profile(profile_id)
	if sc.has("start"):
		var at: Vector2 = sc["start"]
		sb.body.global_position = at + Vector2(0.0, -BodyConfig.BOTTOM)
		sb.body.velocity = Vector2.ZERO
	for _k in SETTLE_TICKS:
		await get_tree().physics_frame
	var ticks: Array = [_tick(sb, 0)]
	for step: Dictionary in sc["steps"]:
		var count := int(round(float(step.get("seconds", 0.0)) * FPS))
		var dir := float(step.get("dir", 0.0))
		for k in count:
			var inp := sb.scripted
			inp.dir = dir
			inp.up = float(step.get("up", 0.0))
			inp.down = float(step.get("down", 0.0))
			inp.jump_pressed = k == 0 and bool(step.get("jump", false))
			inp.jump_held = bool(step.get("hold_jump", false)) or inp.jump_pressed
			inp.signature_pressed = k == 0 and bool(step.get("signature", false))
			await get_tree().physics_frame
			ticks.append(_tick(sb, ticks.size()))
			var here: float = ticks[-1]["x"]
			if step.has("until_x") and ((dir > 0.0 and here >= float(step["until_x"])) or (dir < 0.0 and here <= float(step["until_x"]))):
				break
			if step.get("until_floor", false) and k >= AIR_TICKS and sb.body.is_on_floor():
				break
	var start: Array = [ticks[0]["x"], ticks[0]["y"]]
	sb.scripted = null
	sb.free()  # at once: a sandbox left for the end of the frame runs one more tick over freed floors
	return {"species": species, "script": script_name, "profile": profile_id, "fps": FPS, "start": start, "ticks": ticks}

func _tick(sb: MovementSandbox, index: int) -> Dictionary:
	var st: MoveState = sb.state
	var up := Vector2.UP if st.surface_n == Vector2.ZERO else st.surface_n  # which way is out of the surface it is on
	var shape: CollisionShape2D = sb.body.get_node("Shape")
	var size: Vector2 = (shape.shape as RectangleShape2D).size
	var contact := shape.global_position - up * (absf(up.x) * size.x / 2.0 + absf(up.y) * size.y / 2.0)
	return {
		"t": snappedf(float(index) / FPS, 0.0001),
		"x": snappedf(contact.x, 0.01), "y": snappedf(contact.y, 0.01),
		"vx": snappedf(sb.body.velocity.x, 0.01), "vy": snappedf(sb.body.velocity.y, 0.01),
		"facing": st.facing, "verb": st.verb, "on_floor": sb.body.is_on_floor(),
		"surface": _surface(sb), "normal": [up.x, up.y],
	}

func _surface(sb: MovementSandbox) -> String:
	var st: MoveState = sb.state
	if st.surface_n != Vector2.ZERO:
		if st.surface_n.y < -0.5:
			return "floor"
		return "ceiling" if st.surface_n.y > 0.5 else "wall"
	if st.mantle_left > 0.0:
		return "mantle"
	if st.clinging:
		return "wall"
	return "floor" if sb.body.is_on_floor() else "air"
