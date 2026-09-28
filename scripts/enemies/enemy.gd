class_name Enemy
extends CharacterBody2D
## A creature built from its CreatureDef: stats, its own skills, simple AI.
## Enemies never emit gameplay events (Health has no emitter).

const GRAVITY := 900.0
const BASE_SPEED := 60.0
const CHASE_RANGE := 160.0
const CONTACT_RANGE := 18.0
const PATROL_RANGE := 48.0
const SPIT_RANGE := 120.0
const SPIT_COOLDOWN := 3.0
const SPIT_TICK := 2
const SPIT_SECONDS := 3.0
const SLOW_SECONDS := 2.0
const COLORS := {"bat": Color(0.45, 0.35, 0.6), "toad": Color(0.3, 0.7, 0.3),
	"lizard": Color(0.6, 0.5, 0.3), "spider": Color(0.15, 0.15, 0.15), "serpent": Color(0.2, 0.4, 0.8)}

var def: CreatureDef
var stats: Stats
var health: Health
var status := EnemyStatus.new()
var capabilities := {}
var team := "enemy"
var facing := -1
var _home_x := 0.0
var _on_ceiling := false
var _spit_damage := 0
var _spit_cd := 0.0
var _slow := 0.0

func setup(p_def: CreatureDef, skill_defs_by_id: Dictionary) -> void:
	def = p_def
	stats = Stats.new(def.stats)
	for s in def.skills:
		var sd: SkillDef = skill_defs_by_id.get(s["id"])
		if sd == null:
			continue
		var lv := int(s["level"])
		stats.set_modifiers(sd.id, SkillEffects.stat_modifiers(sd, lv))
		capabilities.merge(SkillEffects.capabilities(sd, lv), true)
		if sd.id == "poison_spit":
			_spit_damage = int(SkillEffects.value_at(sd.effects[0], lv))
	health = Health.new(stats.get_stat("max_hp"))  # no emit_event: actor boundary
	health.died.connect(_on_died)
	_on_ceiling = capabilities.has("ceiling_walk")
	add_to_group("actors")
	add_to_group("predatable")
	add_to_group("inspectable")

func _ready() -> void:
	_home_x = global_position.x
	if get_child_count() == 0:
		_build_body()

func receive_hit(raw: int, damage_type: String) -> void:
	if status.state == EnemyStatus.DOWNED or status.state == EnemyStatus.GONE:
		return
	health.take_hit(Damage.direct_hit(raw, 0, stats.get_stat("def")), damage_type)

## Returns true when the tackle stunned or downed this enemy (the player emits stunned_enemy).
func receive_tackle(atk: int, from_behind: bool) -> bool:
	if status.state == EnemyStatus.DOWNED or status.state == EnemyStatus.GONE:
		return false
	receive_hit(atk, "physical")
	if status.state == EnemyStatus.DOWNED:
		return true
	if not def.predatable:
		return false  # the serpent can't be stunned
	if def.id == Sources.LIZARD and not from_behind:
		return false  # armored front
	status.stun()
	return true

func receive_thread(tier: int) -> void:
	if tier >= 2 and def.predatable:
		status.stun()
	else:
		_slow = SLOW_SECONDS

func can_be_predated() -> bool:
	return def.predatable and status.predatable()

func set_held(v: bool) -> void:
	status.held = v

func consume() -> CreatureDef:
	status.consume()
	queue_free()
	return def

func _on_died() -> void:
	if def.predatable:
		status.down()
	else:
		status.consume()  # Plan 3 turns the serpent's death into victory

func _physics_process(delta: float) -> void:
	status.update(delta)
	if status.state == EnemyStatus.GONE:
		queue_free()
		return
	_spit_cd = maxf(0.0, _spit_cd - delta)
	_slow = maxf(0.0, _slow - delta)
	var player: Node2D = get_tree().get_first_node_in_group("player")
	var active := status.state == EnemyStatus.ACTIVE
	if active and player != null:
		_act(player)
	else:
		velocity.x = 0.0
	var flying := capabilities.has("flight") and active
	if not flying and not (_on_ceiling and active):
		velocity.y += GRAVITY * delta
	move_and_slide()
	if active and player != null and global_position.distance_to(player.global_position) <= CONTACT_RANGE:
		player.receive_hit(stats.get_stat("atk"), "physical")

func _act(player: Node2D) -> void:
	var speed := BASE_SPEED * stats.get_stat("spd") / 100.0 * (0.5 if _slow > 0.0 else 1.0)
	var to_player: Vector2 = player.global_position - global_position
	if _on_ceiling:
		velocity = Vector2.ZERO
		if absf(to_player.x) < 40.0 and to_player.y > 0.0:
			_on_ceiling = false  # drop on prey
		return
	if capabilities.has("flight"):
		if to_player.length() < CHASE_RANGE:
			velocity = to_player.normalized() * speed
		else:
			velocity = Vector2(0.0, sin(Time.get_ticks_msec() / 300.0) * 20.0)
		facing = 1 if velocity.x >= 0.0 else -1
		return
	if absf(to_player.x) < CHASE_RANGE and absf(to_player.y) < 48.0:
		facing = 1 if to_player.x > 0.0 else -1
		velocity.x = facing * speed
	else:
		if global_position.x > _home_x + PATROL_RANGE:
			facing = -1
		elif global_position.x < _home_x - PATROL_RANGE:
			facing = 1
		velocity.x = facing * speed * 0.5
	if _spit_damage > 0 and _spit_cd <= 0.0 and to_player.length() < SPIT_RANGE:
		_spit_cd = SPIT_COOLDOWN
		player.receive_poison(_spit_damage, SPIT_TICK, SPIT_SECONDS)

func _build_body() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 12)
	shape.shape = rect
	add_child(shape)
	var visual := ColorRect.new()
	visual.size = Vector2(16, 12)
	visual.position = Vector2(-8, -6)
	visual.color = COLORS.get(def.id if def != null else "", Color.WHITE)
	add_child(visual)
