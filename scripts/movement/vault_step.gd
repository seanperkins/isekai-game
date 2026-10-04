class_name VaultStep
extends RefCounted
## The wolf's vault: a low hard step in its path, met at a run, is hopped with no button. Pure static, run by VerbRunner
## after GroundAirStep. The impulse lifts the feet `vault_margin` above the step, so the speed is kept and the step is
## cleared on the way over; a taller step is a wall, and a launch this tick (a jump press) wins.

static func step(s: MoveState, i: MoveInput, p: MovementProfile) -> void:
	if not i.on_floor or s.launched != "" or absf(s.velocity.x) < p.vault_speed:
		return
	if i.step_ahead <= 0.0 or i.step_ahead > p.vault_step:
		return
	s.velocity.y = -sqrt(2.0 * p.gravity * (i.step_ahead + p.vault_margin))
	s.launched = "vault"
