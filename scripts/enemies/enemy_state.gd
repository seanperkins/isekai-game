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
		"spider":
			if on_ceiling:
				return "hang"
			if not on_floor:
				return "drop"
			return "crawl"
		"spore_moth", "pale_moth":
			return "fly"
		"mushroom_crab", "cave_crayfish":
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
	return "idle"
