class_name Player
extends CharacterBody2D
## The slime. Reads input, moves, and is the only actor that emits gameplay events.

signal died
signal inspect_report(lines: PackedStringArray)

const SPEED := 140.0
const JUMP_VELOCITY := -330.0
const WALL_JUMP_PUSH := 180.0
const GRAVITY := 900.0
const WALL_SLIDE_SPEED := 90.0
const TACKLE_RANGE := 28.0
const TACKLE_SPEED := 260.0
const TACKLE_SECONDS := 0.15
const PREDATE_RANGE := 32.0
const INSPECT_RANGE := 96.0
const INVULN_SECONDS := 0.6
const EAT_HEAL := 5
const BASE_STATS := {"max_hp": 30, "atk": 1, "def": 0, "spd": 100}

var team := "player"
var facing := 1
var stats: Stats
var health: Health
var skillset: PlayerSkillSet
var sensors := PlayerSensors.new()
var predation := PredationHold.new()

var _rules: SkillRulesEngine
var _compendium: CompendiumModel
var _creatures := {}
var _emit: Callable
var _invuln := 0.0
var _dash := 0.0
var _poison_left := 0.0
var _poison_tick := 0
var _poison_acc := 0.0
var _regen_acc := 0.0
var _abilities := {}

func setup(rules: SkillRulesEngine, compendium: CompendiumModel, creature_defs: Array, emit: Callable) -> void:
	_rules = rules
	_compendium = compendium
	_emit = emit
	for c in creature_defs:
		_creatures[c.id] = c
	stats = Stats.new(BASE_STATS)
	health = Health.new(BASE_STATS["max_hp"])
	health.emit_event = emit
	health.died.connect(_on_health_died)
	sensors.emit_event = emit
	skillset = PlayerSkillSet.new(rules, stats)
	rules.skill_unlocked.connect(_on_skill_unlocked)
	rules.skill_leveled.connect(_on_skill_leveled)
	rules.run_started.connect(_on_run_started)
	add_to_group("player")
	add_to_group("actors")
	if get_child_count() == 0:
		_build_body()

func _physics_process(delta: float) -> void:
	if health == null or health.is_dead():
		return
	var dir := Input.get_axis("move_left", "move_right")
	if predation.active():
		dir = 0.0
	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1
	if _dash > 0.0:
		_dash -= delta
	else:
		velocity.x = dir * SPEED * stats.get_stat("spd") / 100.0
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if skillset.has("wall_cling") and is_on_wall() and not is_on_floor() and velocity.y > 0.0:
		velocity.y = minf(velocity.y, WALL_SLIDE_SPEED * stats.get_stat("slide_speed") / 100.0)
	if Input.is_action_just_pressed("jump"):
		do_jump()
	if Input.is_action_just_pressed("tackle"):
		do_tackle()
	if Input.is_action_pressed("predate"):
		if predation.active():
			process_predate(delta)
		else:
			begin_predate()
	elif predation.active():
		cancel_predate()
	if Input.is_action_just_pressed("inspect"):
		do_inspect()
	if Input.is_action_just_pressed("active_1"):
		use_active(0)
	if Input.is_action_just_pressed("active_2"):
		use_active(1)
	if Input.is_action_just_pressed("cycle"):
		skillset.slots.cycle()
	move_and_slide()
	sensors.physics_update(is_on_wall(), is_on_floor())
	tick(delta)

func do_jump() -> void:
	if health.is_dead():
		return
	var boost := sqrt(stats.get_stat("jump_height") / 100.0)
	if is_on_floor():
		velocity.y = JUMP_VELOCITY * boost
		sensors.jumped("ground")
	elif skillset.has("wall_cling") and is_on_wall():
		velocity.y = JUMP_VELOCITY * boost
		velocity.x = get_wall_normal().x * WALL_JUMP_PUSH
		_dash = 0.15
		sensors.jumped("wall")

func do_tackle() -> void:
	if health.is_dead() or predation.active() or _dash > 0.0:
		return
	velocity.x = facing * TACKLE_SPEED
	_dash = TACKLE_SECONDS
	var target = _nearest_in_front(TACKLE_RANGE)
	if target == null or not target.has_method("receive_tackle"):
		return
	var from_behind: bool = target.facing == facing
	if target.receive_tackle(stats.get_stat("atk"), from_behind):
		_emit.call(Events.STUNNED_ENEMY, {"source": target.def.id})

func begin_predate() -> void:
	if health.is_dead():
		return
	var target = _nearest_in_group("predatable", PREDATE_RANGE, func(n): return n.can_be_predated())
	if target == null:
		return
	target.set_held(true)
	predation.start(target, stats.get_stat("predation_time"))

func process_predate(delta: float) -> void:
	var t = predation.target
	if health.is_dead() or not is_instance_valid(t) or not t.can_be_predated():
		cancel_predate()
		return
	if predation.update(delta):
		_complete_predation(t)

func cancel_predate() -> void:
	var t = predation.target
	if is_instance_valid(t):
		t.set_held(false)
	predation.cancel()

func do_inspect() -> void:
	if health.is_dead():
		return
	var target = _nearest_in_group("inspectable", INSPECT_RANGE, func(_n): return true)
	if target == null:
		sensors.inspected("self", true)
		inspect_report.emit(StatusText.self_lines(stats, health, _rules, _compendium, _rules.level_of("appraisal")))
		return
	var c: CreatureDef = target.def
	sensors.inspected(c.id, c.appraisal_target)
	inspect_report.emit(StatusText.creature_lines(_compendium.creature_report(c.id, _rules.level_of("appraisal"))))

func use_active(i: int) -> void:
	if health.is_dead():
		return
	var id := skillset.slots.use(i)
	if id == "":
		return
	var ability := _ability(id)
	if ability == null:
		return
	ability.level = _rules.level_of(id)
	if ability.activate():
		_emit.call(Events.SKILL_USED, {"id": id})

func receive_hit(raw: int, damage_type: String) -> void:
	if _invuln > 0.0 or health.is_dead():
		return
	var m := skillset.incoming(damage_type, health.hp, health.max_hp)
	health.take_hit(Damage.direct_hit(raw, m["percent_off"], m["flat_off"] + stats.get_stat("def")), damage_type)
	_invuln = INVULN_SECONDS

func receive_poison(application: int, tick_amount: int, seconds: float) -> void:
	if _invuln > 0.0 or health.is_dead():
		return
	receive_hit(application, "poison")
	_poison_left = seconds
	_poison_tick = tick_amount
	_poison_acc = 0.0

func tick(delta: float) -> void:
	_invuln = maxf(0.0, _invuln - delta)
	if health.is_dead():
		return
	if _poison_left > 0.0:
		_poison_acc += delta
		while _poison_acc >= 1.0 - 0.0001 and _poison_left > 0.0:
			_poison_acc -= 1.0
			_poison_left -= 1.0
			var m := skillset.incoming("poison", health.hp, health.max_hp)
			health.take_tick(Damage.tick(_poison_tick, m["percent_off"]))
	var interval := stats.get_stat("regen_interval")
	if interval > 0:
		_regen_acc += delta
		if _regen_acc >= interval:
			_regen_acc -= interval
			health.heal(1)
	else:
		_regen_acc = 0.0

func apply_impulse(v: Vector2) -> void:
	velocity = Vector2(v.x, velocity.y + v.y)
	_dash = 0.25

func _complete_predation(t) -> void:
	predation.cancel()
	var c: CreatureDef = t.consume()
	var kind := "terrain" if c.id == Sources.WATER_POOL else "creature"
	_emit.call(Events.PREDATED, {"source": c.id, "kind": kind})
	for ess in Essences.ALL:  # canonical order, independent of how the .tres stored the keys
		for i in int(c.essences.get(ess, 0)):
			_emit.call(Events.ABSORBED, {"essence": ess, "source": c.id})
	stats.apply_eat(c)
	_sync_max_hp()
	health.heal(EAT_HEAL + skillset.heal_on(Events.PREDATED, {"source": c.id, "kind": kind}))

func _ability(id: String) -> Ability:
	if _abilities.has(id):
		return _abilities[id]
	var d := _rules.get_def(id)
	if d == null:
		return null
	var path := SkillEffects.active_scene(d)
	if path == "" or not ResourceLoader.exists(path):
		return null
	var node = load(path).instantiate()
	if not (node is Ability):
		node.free()
		return null
	node.setup(self, SkillEffects.active_values(d), _rules.level_of(id))
	add_child(node)
	_abilities[id] = node
	return node

func _nearest_in_front(range_px: float):
	var best = null
	var best_dx := INF
	for n in get_tree().get_nodes_in_group("actors"):
		if n == self or n.get("team") == team:
			continue
		var dx: float = (n.global_position.x - global_position.x) * facing
		if dx < -4.0 or dx > range_px or absf(n.global_position.y - global_position.y) > 20.0:
			continue
		if dx < best_dx:
			best = n
			best_dx = dx
	return best

func _nearest_in_group(group: String, range_px: float, accept: Callable):
	var best = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group(group):
		if n == self or not is_instance_valid(n):
			continue
		var d := global_position.distance_to(n.global_position)
		if d <= range_px and d < best_d and accept.call(n):
			best = n
			best_d = d
	return best

func _sync_max_hp() -> void:
	health.set_max_hp(stats.get_stat("max_hp"))

func _on_skill_unlocked(id: String) -> void:
	skillset.on_skill_unlocked(id)
	_sync_max_hp()

func _on_skill_leveled(_id: String, _level: int) -> void:
	skillset.refresh()
	_sync_max_hp()

func _on_run_started() -> void:
	skillset.reset()
	stats.reset_run()
	_sync_max_hp()

func _on_health_died() -> void:
	cancel_predate()
	died.emit()

func _build_body() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 12)
	shape.shape = rect
	add_child(shape)
	var visual := ColorRect.new()
	visual.size = Vector2(14, 12)
	visual.position = Vector2(-7, -6)
	visual.color = Color(0.4, 0.8, 1.0)
	add_child(visual)
