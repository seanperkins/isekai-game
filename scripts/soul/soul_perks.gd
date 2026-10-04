class_name SoulPerks
extends RefCounted
## Applies the perks the player has bought to a new body. Runs at the start of a life, after the rebirth kit; buying a perk in
## the world only changes SoulProgress, so it reaches the body from the next life.

## For each perk in `perks` bought at least once, adds `amount * times_bought` of each effect's stat as a level bonus, then
## re-reads max HP and MP and fills the vitals. Does nothing when no perk was bought.
static func apply(player: Player, soul: SoulProgress, perks: Array) -> void:
	var applied := false
	for perk: PerkDef in perks:
		var times := soul.perk_count(perk.id)
		if times <= 0:
			continue
		for effect in perk.effects:
			player.stats.add_level_bonus(str(effect["stat"]), int(effect["amount"]) * times)
		applied = true
	if applied:
		player.refresh_stats()
		player.fill_vitals()
