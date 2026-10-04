class_name VerbRunner
extends RefCounted
## The species' verbs on top of the ground and air step: facing, Ooze (the flat slime), the bursts (Tackle, the puddle
## slide), the crawl (the spider's surfaces, handed to SurfaceStep while it is on one) its web zip (ZipStep, first) and its silk drop (DropStep, after it). Pure statics like GroundAirStep. A burst only owns horizontal velocity, so the step keeps
## running underneath it (gravity, jump, coyote and the jump buffer never stop), as Player._dash does today.

## The raw down input at which the slime flattens and holds flat.
const SPREAD_DOWN := 0.6
## Walking speed while flat, as a fraction.
const SPREAD_SPEED := 0.5
## Standing up from flat needs this many px free above (the standing box's extra height).
const STAND_RISE := 14.0

static func step(s: MoveState, i: MoveInput, p: MovementProfile, dt: float, speed_scale := 1.0, jump_boost := 1.0) -> void:
	s.down_pressed = i.down >= SPREAD_DOWN and s.down_prev < SPREAD_DOWN  # a press: the edge, not a held direction
	s.down_prev = i.down
	if s.down_pressed and (i.on_oneway_floor or (s.surface_n == Vector2.UP and s.surface_oneway)):
		s.fall_through = p.fall_through  # down on a one-way ledge drops through it (every species)
	else:
		s.fall_through = maxf(0.0, s.fall_through - dt)
	if i.dir != 0.0:
		s.facing = 1 if i.dir > 0.0 else -1
	_tick_cooldowns(s, dt)
	if i.on_floor or (p.verbs.has("wall") and i.wall_side != 0) or s.surface_n != Vector2.ZERO:
		s.air_verb_used = false  # landing, or touching a wall, gives the air verb back
	if p.verbs.has("zip") and ZipStep.step(s, i, p, dt):
		return  # a thread pulling the spider owns the body until it grips or cancels
	if p.verbs.has("drop") and DropStep.step(s, i, p, dt):
		return  # sliding down a thread owns the body until it lets go or lands
	if p.verbs.has("crawl") and SurfaceStep.step(s, i, p, dt, jump_boost):
		return  # on a surface the crawl owns the body (the caller moves it by surface_shift); in the air the ground step runs
	_ooze(s, i, p)
	_bursts(s, i, p, dt)
	var input := i
	if s.spread and i.jump_pressed and i.clearance_above < STAND_RISE:
		input = i.copy()  # a flat slime under a low ceiling cannot jump, and the press is not buffered
		input.jump_pressed = false
	var scale := speed_scale * (SPREAD_SPEED if s.spread else 1.0)
	GroundAirStep.step(s, input, p, dt, scale, jump_boost)
	if p.verbs.has("vault") and s.verb == "":
		VaultStep.step(s, i, p)  # after the ground step, which resets `launched` (a jump press this tick is the jump); a burst owns the velocity
	if s.wall_bounced and s.verb != "":
		_end(_row(p, s.verb), s)  # a wall bounce ends the burst: the slime leaves the wall bouncing, not tackling

## True while the body should use the flat collision box: spread, or a flat burst (the puddle slide) running.
static func is_flat(s: MoveState, p: MovementProfile) -> bool:
	if s.spread:
		return true
	var row := _row(p, s.verb) if s.verb != "" else null
	return row != null and row.flat

## Down on the floor flattens the slime; it stands again once down is released (or it jumps) with room above.
static func _ooze(s: MoveState, i: MoveInput, p: MovementProfile) -> void:
	if not p.verbs.has("ooze"):
		return
	var want := i.on_floor and i.down >= SPREAD_DOWN and not i.jump_pressed and s.fall_through <= 0.0
	if want:
		s.spread = true
	elif s.spread and i.clearance_above >= STAND_RISE:
		s.spread = false

static func _tick_cooldowns(s: MoveState, dt: float) -> void:
	for id in s.cooldowns.keys():
		var left := maxf(0.0, float(s.cooldowns[id]) - dt)
		if left > 0.0:
			s.cooldowns[id] = left
		else:
			s.cooldowns.erase(id)

## Begins the first burst whose trigger holds; while one runs, ends it or lets it bleed. The clock is checked first and
## decremented after, so a 0.15 s burst holds its velocity for exactly nine ticks.
static func _bursts(s: MoveState, i: MoveInput, p: MovementProfile, dt: float) -> void:
	if s.verb == "":
		for row in p.bursts:
			if _can_begin(row as BurstDef, s, i):
				_begin(row as BurstDef, s, i)
				break
	if s.verb == "":
		return
	var row := _row(p, s.verb)
	if row != null and row.aimed and i.touching_hostile:
		s.pounce_hit = true  # before the end check: contact on the tick it expires still counts
	if row == null or _ended(row, s, i):
		_end(row, s)
		return
	s.verb_left -= dt
	if row.decel > 0.0:
		s.velocity.x = move_toward(s.velocity.x, 0.0, row.decel * dt)

static func _row(p: MovementProfile, id: String) -> BurstDef:
	for row in p.bursts:
		if (row as BurstDef).id == id:
			return row as BurstDef
	return null

static func _can_begin(row: BurstDef, s: MoveState, i: MoveInput) -> bool:
	if s.cooldowns.get(row.id, 0.0) > 0.0 or (not i.on_floor and s.air_verb_used):
		return false
	match row.trigger:
		"signature":
			return i.signature_pressed
		"down_run":
			return i.on_floor and i.down >= SPREAD_DOWN and absf(s.velocity.x) >= row.min_start_speed and s.fall_through <= 0.0
	return false

static func _begin(row: BurstDef, s: MoveState, i: MoveInput) -> void:
	s.air_verb_used = s.air_verb_used or not i.on_floor
	s.verb = row.id
	s.verb_left = row.duration
	if row.aimed:
		var way := i.aim.normalized() if i.aim != Vector2.ZERO else Vector2(s.facing, 0.0)
		s.verb_dir = signf(way.x)  # 0 for straight up or down: no wall is ahead
		s.pounce_hit = false
		s.jumping = false  # the leap replaces any jump, so a released one adds no extra gravity to it
		s.velocity = way * (row.speed + row.run_fraction * absf(s.velocity.x))
		return
	s.verb_dir = float(s.facing) if row.speed > 0.0 else signf(s.velocity.x)
	s.velocity.x = s.verb_dir * (row.speed if row.speed > 0.0 else absf(s.velocity.x))

static func _ended(row: BurstDef, s: MoveState, i: MoveInput) -> bool:
	return s.verb_left <= 1e-6 \
		or (row.needs_floor and not i.on_floor) \
		or (row.ends_at_wall and i.wall_side != 0 and s.verb_dir * float(i.wall_side) > 0.0) \
		or (row.needs_down and i.down < SPREAD_DOWN) \
		or (row.min_speed > 0.0 and absf(s.velocity.x) < row.min_speed)

static func _end(row: BurstDef, s: MoveState) -> void:
	if row != null and row.cooldown > 0.0:
		s.cooldowns[row.id] = row.cooldown
	s.verb = ""
	s.verb_left = 0.0
