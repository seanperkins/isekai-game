class_name EnemyState
extends RefCounted
## Which animation a creature plays, derived from its AI and status (the AI itself is untouched).
## Status wins, then a hit flinch, then the creature's own behaviour. Like SlimeState for the slime.

static func pick(creature: String, status: int, charge: String, swoop: String, spit_windup: bool,
		spit_recent: bool, on_ceiling: bool, on_floor: bool, moving: bool, hurt: bool) -> String:
	if status == EnemyStatus.DOWNED:
		return "downed"
	if status == EnemyStatus.STUNNED:
		return "stunned"
	if status == EnemyStatus.DYING or hurt:
		return "hurt"
	match creature:
		"bat":
			match swoop:
				"hover":
					return "hover"
				"warn":
					return "warn"
				"dive":
					return "dive"
			return "fly"
		"toad", "bog_lizardman":
			if spit_windup:
				return "puff"
			if spit_recent:
				return "spit"
			return "walk" if moving else "idle"
		"lizard":
			if charge != "":
				return charge
			return "walk" if moving else "idle"
		"spider", "taratect":
			if on_ceiling:
				return "hang"
			if not on_floor:
				return "drop"
			return "crawl"
		"spore_moth", "pale_moth":
			return "fly"
		"mushroom_crab", "cave_crayfish", "gloom_wolf", "armed_ant":
			if charge != "":
				return charge
			return "walk" if moving else "idle"
		"vine_snake":
			match charge:
				"windup":
					return "coil"
				"charge":
					return "lunge"
				"rest":
					return "rest"
			return "hide"
		"glass_eel", "storm_eel":
			match swoop:
				"warn":
					return "warn"
				"dive":
					return "dart"
			return "swim"
		"drift_jelly":
			return "drift"
		"stone_drake":
			match charge:
				"windup":
					return "windup"
				"rest":
					return "stomp"
			return "walk" if moving else "idle"
	return "idle"

## What an animated twin (a form with its own clips) plays when it has no clip for a state: a stun or a downing shows the hit, anything else
## the idle loop.
const FORM_FALLBACK := {"stunned": "hurt", "downed": "hurt", "hurt": "idle", "windup": "idle", "recover": "idle", "walk": "idle"}
const LOCOMOTION := ["idle", "walk"]

## The clip an animated twin plays: its status first, then a hit, then the state of its verb, then whether it is walking. `clips` is its
## {state: clip} table; a state it has no clip for takes the fallback.
static func pick_form(clips: Dictionary, status: int, verb_state: String, moving: bool, hurt: bool) -> String:
	var want := "idle"
	if status == EnemyStatus.DOWNED:
		want = "downed"
	elif status == EnemyStatus.STUNNED:
		want = "stunned"
	elif status == EnemyStatus.DYING or hurt:
		want = "hurt"
	elif verb_state == "windup" or verb_state == "recover":
		want = verb_state
	elif moving:
		want = "walk"
	while not clips.has(want) and FORM_FALLBACK.has(want):
		want = FORM_FALLBACK[want]
	return want

## Standing or walking: the states a one-shot that is still playing keeps the creature out of.
static func is_locomotion(state: String) -> bool:
	return state in LOCOMOTION
