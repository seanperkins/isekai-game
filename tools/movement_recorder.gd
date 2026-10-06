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
## The run being recorded: the sandbox, its steps, the settling ticks left, which step and tick of it was fed in last, and the ticks so far.
var _job := {}

signal _finished

func _ready() -> void:
	process_physics_priority = 100  # after the sandbox's own step in the same tick, so what it records is what that step did
	set_physics_process(false)

## Runs `script_name` as `species` and returns `{"species", "script", "profile", "fps", "start", "ticks": [...]}`, or {} for a species or script it does not know. Each
## tick is `{"t", "x", "y", "vx", "vy", "speed", "crawl", "body", "facing", "verb", "on_floor", "surface", "normal"}`: x and y are the body's contact with what it stands on (the feet on a
## floor), in game px with y DOWN; `surface` is floor, wall, ceiling, air or mantle; `speed` is how fast it goes along what it stands on (a crawler moves by shifting the body, so its
## velocity is zero and its speed is read from where the body was: `body` is its origin, which does not jump at a corner as the contact does); `crawl` says it is on a surface it crawls (the
## spider's), whatever the surface, and `normal` which way is out of it. Tick 0 is the body settled before the first input; tick n is where the sandbox's n-th step left it.
func record(species: String, script_name: String) -> Dictionary:
	if not scripts_for(species).has(script_name):
		return {}
	var result: Dictionary = await record_script(species, make_script(script_name))
	if not result.is_empty():
		result["script"] = script_name
	return result

## The same for a script given outright (`{"start": Vector2, "steps": [...]}`); its "script" is "custom".
func record_script(species: String, sc: Dictionary) -> Dictionary:
	profile_id = MovementProfile.SPECIES_PROFILE.get(species, "")
	if profile_id == "" or sc.is_empty() or not _job.is_empty():
		return {}
	var sb: MovementSandbox = load(SCENE).instantiate()
	add_child(sb)
	sb.scripted = MoveInput.new()
	sb.set_profile(profile_id)
	if sc.has("start"):
		var at: Vector2 = sc["start"]
		sb.body.global_position = at + Vector2(0.0, -BodyConfig.BOTTOM)
		sb.body.velocity = Vector2.ZERO
	_job = {"sb": sb, "steps": sc["steps"], "settle": SETTLE_TICKS, "step": 0, "k": 0, "ticks": []}
	set_physics_process(true)
	await _finished
	await get_tree().process_frame  # out of this node's own signal: whoever awaits the run may free the recorder when it resumes
	set_physics_process(false)
	var ticks: Array = _job["ticks"]
	_job = {}
	sb.scripted = null
	sb.free()  # at once: a sandbox left for the end of the frame runs one more tick over freed floors
	return {"species": species, "script": "custom", "profile": profile_id, "fps": FPS, "start": [ticks[0]["x"], ticks[0]["y"]], "ticks": ticks}

func _physics_process(_delta: float) -> void:
	if _job.is_empty():
		return
	if _job.is_empty() or _job.get("ended", false):
		return
	var sb: MovementSandbox = _job["sb"]
	var ticks: Array = _job["ticks"]
	if _job["settle"] > 0:
		_job["settle"] -= 1
		if _job["settle"] > 0:
			return
		ticks.append(_tick(sb, 0, {}))
	else:
		ticks.append(_tick(sb, ticks.size(), ticks[-1]))  # the sandbox has just taken the step the last input asked for
		var steps: Array = _job["steps"]
		var step: Dictionary = steps[_job["step"]]
		var k: int = _job["k"]
		var dir := float(step.get("dir", 0.0))
		var here: float = ticks[-1]["x"]
		var done := k + 1 >= _count(step)
		done = done or (step.has("until_x") and ((dir > 0.0 and here >= float(step["until_x"])) or (dir < 0.0 and here <= float(step["until_x"]))))
		done = done or (step.get("until_floor", false) and k >= AIR_TICKS and sb.body.is_on_floor())
		if done:
			_job["step"] += 1
			_job["k"] = 0
		else:
			_job["k"] = k + 1
	_feed_next(sb)

## Sets the input for the next tick (skipping steps that last no time), or ends the run when the steps are used up.
func _feed_next(sb: MovementSandbox) -> void:
	var steps: Array = _job["steps"]
	while _job["step"] < steps.size() and _count(steps[_job["step"]]) == 0:
		_job["step"] += 1
	if _job["step"] >= steps.size():
		_job["ended"] = true
		_finished.emit.call_deferred()
		return
	var step: Dictionary = steps[_job["step"]]
	var inp := sb.scripted
	var first: bool = _job["k"] == 0
	inp.dir = float(step.get("dir", 0.0))
	inp.up = float(step.get("up", 0.0))
	inp.down = float(step.get("down", 0.0))
	inp.jump_pressed = first and bool(step.get("jump", false))
	inp.jump_held = bool(step.get("hold_jump", false)) or inp.jump_pressed
	inp.signature_pressed = first and bool(step.get("signature", false))

func _count(step: Dictionary) -> int:
	return int(round(float(step.get("seconds", 0.0)) * FPS))

func _tick(sb: MovementSandbox, index: int, previous: Dictionary) -> Dictionary:
	var st: MoveState = sb.state
	var up := Vector2.UP if st.surface_n == Vector2.ZERO else st.surface_n  # which way is out of the surface it is on
	var shape: CollisionShape2D = sb.body.get_node("Shape")
	var size: Vector2 = (shape.shape as RectangleShape2D).size
	var contact := shape.global_position - up * (absf(up.x) * size.x / 2.0 + absf(up.y) * size.y / 2.0)
	var crawl := st.surface_n != Vector2.ZERO
	var speed := absf(sb.body.velocity.x)
	var body_at: Vector2 = sb.body.global_position
	if crawl and not previous.is_empty():
		if Vector2(previous["normal"][0], previous["normal"][1]) == up:
			speed = (body_at - Vector2(previous["body"][0], previous["body"][1])).length() * FPS
		else:
			speed = float(previous["speed"])  # the body wraps round a corner in one tick: that is not a speed, so it keeps the one it had
	return {
		"t": snappedf(float(index) / FPS, 0.0001),
		"x": snappedf(contact.x, 0.01), "y": snappedf(contact.y, 0.01),
		"vx": snappedf(sb.body.velocity.x, 0.01), "vy": snappedf(sb.body.velocity.y, 0.01),
		"speed": snappedf(speed, 0.01), "crawl": crawl, "body": [snappedf(body_at.x, 0.01), snappedf(body_at.y, 0.01)],
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
