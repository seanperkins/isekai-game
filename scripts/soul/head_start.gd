class_name HeadStart
extends RefCounted
## The head start bought with soul points in the goddess's menu: starting levels and powers the Compendium has seen owned.
## The cart is {"levels": int, "powers": Array of skill ids}; its kit is what RebirthKit.apply gives at the start of a life.

## Ids of the base powers that can be taken: Owned-once in the Compendium, and never an evolution, an enemy-only skill or the
## starting skill. Sorted by display name.
static func eligible_powers(compendium: CompendiumModel, skill_defs: Array) -> Array:
	var ids: Array = []
	for d: SkillDef in skill_defs:
		if d.source == "evolution" or d.source == "enemy_only" or d.starting:
			continue
		if compendium.state(d.id) == CompendiumModel.State.OWNED_ONCE:
			ids.append(d.id)
	ids.sort_custom(func(a: String, b: String) -> bool: return compendium.skill_name(a) < compendium.skill_name(b))
	return ids

## The first `levels` level prices (capped at the priced levels) plus `power_price` for each power.
static func price(rules: SoulRules, cart: Dictionary) -> int:
	var levels := clampi(int(cart.get("levels", 0)), 0, rules.level_prices.size())
	var total := 0
	for i in levels:
		total += int(rules.level_prices[i])
	var powers: Array = cart.get("powers", [])
	return total + rules.power_price * powers.size()

## The rebirth kit for a cart: "skills" only when powers are bought, "level" (1 + levels) only when levels are bought, so an
## empty cart is {} and begin_life skips it.
static func kit(cart: Dictionary) -> Dictionary:
	var out := {}
	var powers: Array = cart.get("powers", [])
	if not powers.is_empty():
		out["skills"] = powers.duplicate()
	var levels := int(cart.get("levels", 0))
	if levels > 0:
		out["level"] = 1 + levels
	return out

## The least anything in the menu costs, or -1 when nothing is for sale (no levels priced and no power to take).
static func cheapest(rules: SoulRules, power_count: int) -> int:
	var best := -1
	if not rules.level_prices.is_empty():
		best = int(rules.level_prices[0])
	if power_count > 0 and (best < 0 or rules.power_price < best):
		best = rules.power_price
	return best
