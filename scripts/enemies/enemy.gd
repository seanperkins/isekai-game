class_name Enemy
extends CharacterBody2D
## A creature built from its CreatureDef: stats, its own skills, and its behaviour.
## Every enemy needs line of sight to notice you and forgets you ALERT_MEMORY seconds after
## losing you; walkers turn at ledges and walls; every attack is telegraphed:
##   swoop (bats):     hover above you, flash, dive at where you were, climb back
##   charger (lizard): stop and flick, charge, then rest (hit it from behind)
##   spitter (toad):   puff up, then lob a poison glob in an arc
##   dropper (spider): hang until you pass under, then drop and walk
## Enemies never emit gameplay events (Health has no emitter).

## Reaches 0 HP. The game awards the player XP for it (a direct signal, not an EventBus event).
signal downed(def: CreatureDef)

const GRAVITY := 900.0
const BASE_SPEED := 60.0
const CHASE_RANGE := 160.0
const CONTACT_RANGE := 18.0  # centre distance, for a player with no body box (test stubs)
## The enemy's collision box, and the slack that lets two touching boxes count as in contact.
const BODY_SIZE := Vector2(16, 12)
const CONTACT_MARGIN := 2.0
const PATROL_RANGE := 48.0
const SPIT_RANGE := 90.0
const SPIT_COOLDOWN := 5.0
const SPIT_TICK := 1
const SPIT_SECONDS := 3.0
const SLOW_SECONDS := 2.0
## Seconds an enemy keeps hunting after it last saw you.
const ALERT_MEMORY := 2.0
## Walkers probe this far ahead and this far down for the ground before stepping on.
const LEDGE_PROBE := 10.0
const LEDGE_DEPTH := 16.0
const SPIT_WINDUP := 0.4
const CHARGE_RANGE := 120.0
const CHARGE_LEVEL := 24.0
const CHARGE_WINDUP := 0.5
const CHARGE_SECONDS := 0.6
const CHARGE_REST := 1.0
const CHARGE_MULT := 3.0
## Bats hover this high over you for HOVER_SECONDS (+ up to HOVER_JITTER, per bat).
const HOVER_HEIGHT := 60.0
const HOVER_SECONDS := 0.8
const HOVER_JITTER := 0.4
const WARN_SECONDS := 0.3
const DIVE_SECONDS := 0.6
const DIVE_MULT := 2.2
const CLIMB_SECONDS := 0.8
const TELEGRAPH_TINT := Color(1.0, 0.8, 0.45)
## Ground enemies do not turn while the player is this close, so jumping over one opens
## a window to hit it from behind (the lizard is only stunned from behind).
const TURN_LOCK_RANGE := 32.0
const ANIM_SECONDS := 0.25
const SPIT_POSE_SECONDS := 0.4
const BODY_BOTTOM := 6.0
const STUNNED_TINT := Color(0.6, 0.6, 0.85)

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
var _sprite: Sprite2D
var _anim_t := 0.0
var _alert := 0.0
var _spit_windup := 0.0
var _charge := ""  # "", "windup", "charge", "rest"
var _charge_t := 0.0
var _swoop := "idle"  # idle, hover, warn, dive, climb
var _swoop_t := 0.0
## Why the last blow landed ("tackle", "poison", "blade", "other") and where it came from.
var _cause := ""
var _killed_from := Vector2.INF
var _dive_dir := Vector2.ZERO
var _rng := RandomNumberGenerator.new()

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
	_rng.seed = get_instance_id()  # each bat keeps its own rhythm
	if get_child_count() == 0:
		_build_body()

static func cause_for(damage_type: String) -> String:
	return "poison" if damage_type == "poison" else "other"

func _untouchable() -> bool:
	return status.state == EnemyStatus.DOWNED or status.state == EnemyStatus.GONE or status.state == EnemyStatus.DYING

## `cause` names the blow for the death effect; it is stored before the hit because _on_died() takes
## no arguments.
func receive_hit(raw: int, damage_type: String, from: Vector2 = Vector2.INF, cause: String = "") -> void:
	if _untouchable():
		return
	_cause = cause if cause != "" else cause_for(damage_type)
	_killed_from = from
	health.take_hit(Damage.direct_hit(raw, 0, stats.get_stat("def")), damage_type)

## Returns true when the tackle stunned or downed this enemy (the player emits stunned_enemy).
func receive_tackle(atk: int, from_behind: bool, from: Vector2 = Vector2.INF) -> bool:
	if _untouchable():
		return false
	receive_hit(atk, "physical", from, "tackle")
	if status.state == EnemyStatus.DYING or status.state == EnemyStatus.DOWNED:
		return true
	if not def.predatable:
		return false  # the serpent can't be stunned
	if def.id == Sources.LIZARD and not from_behind:
		return false  # armored front
	status.stun()
	return true

func receive_thread(tier: int) -> void:
	if _untouchable():
		return
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

## Ends the death effect: the creature lies downed and its 5 s eat window starts.
func finish_dying() -> void:
	if status.state == EnemyStatus.DYING:
		status.down()

func _on_died() -> void:
	if def.predatable:
		status.die()  # the death effect ends in down() and starts the eat window
	else:
		status.consume()  # Plan 3 turns the serpent's death into victory
	downed.emit(def)

func _physics_process(delta: float) -> void:
	status.update(delta)
	_anim_t += delta
	if status.state == EnemyStatus.GONE:
		queue_free()
		return
	_spit_cd = maxf(0.0, _spit_cd - delta)
	_slow = maxf(0.0, _slow - delta)
	var player: Node2D = get_tree().get_first_node_in_group("player")
	var active := status.state == EnemyStatus.ACTIVE
	if active and player != null:
		_sense(player, delta)
		_act(player, delta)
	else:
		velocity.x = 0.0
		_charge = ""
		_spit_windup = 0.0
	var flying := capabilities.has("flight") and active
	if not flying and not (_on_ceiling and active):
		velocity.y += GRAVITY * delta
	move_and_slide()
	if active and player != null and is_touching(player):
		player.receive_hit(stats.get_stat("atk"), "physical", global_position)
	_update_visual()

## True when this enemy's box touches the player's. The bodies block each other, so they can only
## touch, never overlap: the margin bridges that. A player with no body box (a test stub) falls back
## to the old centre distance.
func is_touching(player: Node2D) -> bool:
	if player.has_method("body_rect"):
		var mine := Rect2(global_position - BODY_SIZE / 2.0, BODY_SIZE).grow(CONTACT_MARGIN)
		return mine.intersects(player.body_rect())
	return global_position.distance_to(player.global_position) <= CONTACT_RANGE

func is_alert() -> bool:
	return _alert > 0.0

func charge_state() -> String:
	return _charge

func swoop_state() -> String:
	return _swoop

## True when no rock lies between this enemy and `target`.
func can_see(target: Node2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -4), target.global_position + Vector2(0, -4))
	var skip: Array[RID] = []
	for n in get_tree().get_nodes_in_group("actors"):
		if n is CollisionObject2D:
			skip.append(n.get_rid())
	if target is CollisionObject2D:
		skip.append(target.get_rid())
	query.exclude = skip
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _sense(player: Node2D, delta: float) -> void:
	if global_position.distance_to(player.global_position) < CHASE_RANGE and can_see(player):
		_alert = ALERT_MEMORY
	else:
		_alert = maxf(0.0, _alert - delta)

## Which sprite to draw for this creature right now. All sheets face right.
func frame_name() -> String:
	var alternate := int(_anim_t / ANIM_SECONDS) % 2 == 1
	match def.id:
		"bat":
			return "bat_2" if alternate else "bat_1"
		"toad":
			return "toad_spit" if _spit_windup > 0.0 or _spit_cd > SPIT_COOLDOWN - SPIT_POSE_SECONDS else "toad_idle"
		"lizard":
			return "lizard_2" if alternate and absf(velocity.x) > 1.0 else "lizard_1"
		"spider":
			return "spider_hang" if _on_ceiling else "spider_crawl"
	return def.id

func _update_visual() -> void:
	if _sprite == null:
		return
	Art.set_frame(_sprite, frame_name(), BODY_BOTTOM)
	_sprite.flip_h = facing < 0
	_sprite.flip_v = status.state == EnemyStatus.DOWNED
	if status.state == EnemyStatus.STUNNED:
		_sprite.modulate = STUNNED_TINT
	elif _telegraphing() and int(_anim_t / 0.08) % 2 == 0:
		_sprite.modulate = TELEGRAPH_TINT
	else:
		_sprite.modulate = Color.WHITE

func _telegraphing() -> bool:
	return _charge == "windup" or _swoop == "warn" or _spit_windup > 0.0

func _speed() -> float:
	return BASE_SPEED * stats.get_stat("spd") / 100.0 * (0.5 if _slow > 0.0 else 1.0)

func _act(player: Node2D, delta: float) -> void:
	var to_player: Vector2 = player.global_position - global_position
	if _on_ceiling:
		velocity = Vector2.ZERO
		if is_alert() and absf(to_player.x) < 40.0 and to_player.y > 0.0:
			_on_ceiling = false  # drop on prey
		return
	if capabilities.has("flight"):
		_swoop_act(player, delta)
		return
	if def.id == Sources.LIZARD and _charger_act(to_player, delta):
		return
	if _spit_damage > 0 and _spitter_act(player, to_player, delta):
		return
	_walk(to_player)

## Chase while alert (holding at a ledge or wall rather than walking off it), else patrol home.
func _walk(to_player: Vector2) -> void:
	var speed := _speed()
	if is_alert() and absf(to_player.y) < 48.0:
		if absf(to_player.x) > TURN_LOCK_RANGE:
			facing = 1 if to_player.x > 0.0 else -1
		velocity.x = 0.0 if _blocked_ahead() else facing * speed
		return
	if global_position.x > _home_x + PATROL_RANGE:
		facing = -1
	elif global_position.x < _home_x - PATROL_RANGE:
		facing = 1
	if _blocked_ahead():
		facing = -facing
	velocity.x = facing * speed * 0.5

## A wall in front, or no ground a step ahead. Only meaningful on the floor.
func _blocked_ahead() -> bool:
	if not is_on_floor():
		return false
	if is_on_wall() and get_wall_normal().x * facing < 0.0:
		return true
	var ahead := global_position + Vector2(facing * LEDGE_PROBE, 0)
	var query := PhysicsRayQueryParameters2D.create(ahead, ahead + Vector2(0, BODY_BOTTOM + LEDGE_DEPTH))
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

## Wind-up, charge, rest. Returns true while the charge sequence owns movement.
func _charger_act(to_player: Vector2, delta: float) -> bool:
	match _charge:
		"windup":
			velocity.x = 0.0
			_charge_t -= delta
			if _charge_t <= 0.0:
				_charge = "charge"
				_charge_t = CHARGE_SECONDS
			return true
		"charge":
			_charge_t -= delta
			if _charge_t <= 0.0 or _blocked_ahead():
				_charge = "rest"
				_charge_t = CHARGE_REST
				velocity.x = 0.0
			else:
				velocity.x = facing * _speed() * CHARGE_MULT
			return true
		"rest":
			velocity.x = 0.0
			_charge_t -= delta
			if _charge_t <= 0.0:
				_charge = ""
			return true
	var ahead := to_player.x * facing
	if is_alert() and absf(to_player.y) < CHARGE_LEVEL and ahead > TURN_LOCK_RANGE and ahead <= CHARGE_RANGE:
		_charge = "windup"
		_charge_t = CHARGE_WINDUP
		velocity.x = 0.0
		return true
	return false

## Puff up, then lob a glob at where the player stands. Returns true while winding up.
func _spitter_act(player: Node2D, to_player: Vector2, delta: float) -> bool:
	if _spit_windup > 0.0:
		velocity.x = 0.0
		_spit_windup -= delta
		if _spit_windup <= 0.0:
			var blob := SpitBlob.new()
			get_parent().add_child(blob)
			blob.launch(global_position + Vector2(facing * 8.0, -6.0), player.global_position, _spit_damage, SPIT_TICK, SPIT_SECONDS)
			_spit_cd = SPIT_COOLDOWN
		return true
	if is_alert() and _spit_cd <= 0.0 and to_player.length() < SPIT_RANGE:
		facing = 1 if to_player.x > 0.0 else -1
		_spit_windup = SPIT_WINDUP
		velocity.x = 0.0
		return true
	return false

## Hover above you, flash, dive in a straight line at where you were, climb back up.
func _swoop_act(player: Node2D, delta: float) -> void:
	var speed := _speed()
	_swoop_t -= delta
	match _swoop:
		"idle":
			velocity = Vector2(0.0, sin(_anim_t * 3.3) * 20.0)
			if is_alert():
				_swoop = "hover"
				_swoop_t = HOVER_SECONDS + _rng.randf() * HOVER_JITTER
		"hover":
			var spot := player.global_position + Vector2(0.0, -HOVER_HEIGHT)
			velocity = (spot - global_position).limit_length(speed)
			if not is_alert():
				_swoop = "idle"
			elif _swoop_t <= 0.0:
				_swoop = "warn"
				_swoop_t = WARN_SECONDS
		"warn":
			velocity = Vector2.ZERO
			if _swoop_t <= 0.0:
				_swoop = "dive"
				_swoop_t = DIVE_SECONDS
				_dive_dir = (player.global_position - global_position).normalized()
		"dive":
			velocity = _dive_dir * speed * DIVE_MULT
			if _swoop_t <= 0.0 or is_on_floor() or is_on_wall():
				_swoop = "climb"
				_swoop_t = CLIMB_SECONDS
		"climb":
			velocity = Vector2(-_dive_dir.x * speed * 0.5, -speed * 0.8)
			if _swoop_t <= 0.0:
				_swoop = "hover" if is_alert() else "idle"
				_swoop_t = HOVER_SECONDS + _rng.randf() * HOVER_JITTER
	if absf(velocity.x) > 1.0:
		facing = 1 if velocity.x > 0.0 else -1

func _build_body() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = BODY_SIZE
	shape.shape = rect
	add_child(shape)
	if def != null:
		_sprite = Art.sprite(frame_name(), BODY_BOTTOM)
		add_child(_sprite)
		_update_visual()
