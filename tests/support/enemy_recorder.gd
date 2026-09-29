class_name EnemyRecorder
extends RefCounted
## Runs one EnemyScenarios scenario on real physics and returns its per-tick trace. Sampling awaits
## `physics_frame` directly (GUT's wait_physics_frames(1) spans two ticks), so every tick is one sample.
## Sample k shows the state after tick k-1; scripted moves act before the enemies' tick k. The differential and
## the committed transitions use the same runner, so that offset cancels.

class StubPlayer extends Node2D:
	var team := "player"
	var facing := 1
	var tick := 0
	var hits: Array = []
	var poisons: Array = []
	func receive_hit(raw: int, damage_type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		hits.append([tick, raw, damage_type])
	func receive_poison(application: int, tick_amount: int, seconds: float) -> void:
		poisons.append([tick, application, tick_amount, seconds])

static var _creatures := {}
static var _skills := {}

static func _load() -> void:
	if not _creatures.is_empty():
		return
	for c in DefLoader.load_dir("res://data/creatures"):
		_creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		_skills[d.id] = d

static func _r(v: float) -> float:
	return snappedf(v, 0.01)

static func _read(e: Enemy, key: String):
	match key:
		"charge_state":
			return e.charge_state()
		"swoop_state":
			return e.swoop_state()
		"anim_state":
			return e.anim_state()
		"telegraphing":
			return e.telegraphing()
	return null

## Returns {"samples": [...], "hazards": [[tick, class, x, y]], "events": [[tick, name]], "hits": [...], "poisons": [...]}.
static func run(host: Node, sc: Dictionary) -> Dictionary:
	_load()
	await host.get_tree().physics_frame  # always start at a physics_frame resume: a caller in the idle loop would otherwise be one tick out of phase
	var root := Node2D.new()
	host.add_child(root)
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(0, 16)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(4000, 20)
	shape.shape = box
	floor_body.add_child(shape)
	root.add_child(floor_body)
	var player := StubPlayer.new()
	player.add_to_group("player")
	root.add_child(player)
	player.global_position = sc["player"][0][1]
	var e := Enemy.new()
	e.setup(_creatures[sc["creature"]], _skills)
	e.position = sc["start"]
	e.facing = sc["facing"]
	root.add_child(e)
	e.seed_rng(sc["seed"])
	var out := {"samples": [], "hazards": [], "events": [], "hits": [], "poisons": []}
	var tick := [0]
	var log_event := func(n: String, _t: Dictionary) -> void:
		if n == "spore_puff" or n == "enemy_died" or n == "enemy_hit":
			out["events"].append([tick[0], n])
	var bus: Node = host.get_tree().root.get_node("EventBus")
	bus.world_event.connect(log_event)
	var seen := {}
	var armed := {}  # act index -> tick the condition was first seen
	var fired := {}
	for t in sc["ticks"]:
		await host.get_tree().physics_frame
		tick[0] = t
		player.tick = t
		for mv in sc["player"]:
			if mv[0] == t:
				player.global_position = mv[1]
		if is_instance_valid(e):
			for i in sc["acts"].size():
				var a: Array = sc["acts"][i]
				match a[0]:
					"stun":
						if a[1] == t:
							e.status.stun(a[2])
					"slow":
						if a[1] == t:
							e.slow_for(a[2])
					"stun_when", "kill_when", "player_when":
						if fired.has(i):
							continue
						if not armed.has(i) and _read(e, a[1]) == a[2]:
							armed[i] = t
						if armed.has(i) and t >= armed[i] + a[3]:
							fired[i] = true
							if a[0] == "stun_when":
								e.status.stun(a[4])
							elif a[0] == "kill_when":
								e.receive_hit(999, "physical", Vector2.INF, "tackle")
							else:
								player.global_position = a[4]
		for h in host.get_tree().get_nodes_in_group("hazards"):
			if not seen.has(h.get_instance_id()):
				seen[h.get_instance_id()] = true
				out["hazards"].append([t, h.get_script().get_global_name(), _r(h.global_position.x), _r(h.global_position.y)])
		if is_instance_valid(e):
			out["samples"].append({"t": t, "x": _r(e.global_position.x), "y": _r(e.global_position.y),
				"vx": _r(e.velocity.x), "vy": _r(e.velocity.y), "f": e.facing, "c": e.charge_state(), "s": e.swoop_state(),
				"a": e.anim_state(), "T": e.telegraphing(), "st": e.status.state, "hp": e.health.hp})
	bus.world_event.disconnect(log_event)
	out["hits"] = player.hits
	out["poisons"] = player.poisons
	# free at once, not with queue_free: a lingering stub player would still be "the player" for the next scenario's first tick
	for h in host.get_tree().get_nodes_in_group("hazards"):
		h.free()
	root.free()
	return out

## Run-length transitions of the observable state: [[tick, charge, swoop, anim, telegraphing, status], ...].
static func transitions(samples: Array) -> Array:
	var out: Array = []
	var last := []
	for s in samples:
		var cur := [s["c"], s["s"], s["a"], s["T"], s["st"]]
		if cur != last:
			out.append([s["t"]] + cur)
			last = cur
	return out

## A list of stub-player hits as [count, first tick] (contact damage lands every tick you overlap, so the list itself is bulky).
static func summary(hits: Array) -> Array:
	return [hits.size(), hits[0][0] if not hits.is_empty() else -1]

