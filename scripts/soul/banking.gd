class_name Banking
extends RefCounted
## Converting held essence into soul points at an altar: a flat rate, any element. The run's essence is spent through the
## engine's ledger (so `held` and evolution affordability follow), the points go to SoulProgress, which saves them at once.

## Held essence of `element`, rounded down to a multiple of the bank rate: the most that can be banked now.
static func max_units(rules: SoulRules, engine: SkillRulesEngine, element: String) -> int:
	var held := engine.held(element)
	if rules.bank_rate <= 0 or held <= 0:
		return 0
	return held - held % rules.bank_rate

## Banks `units` of `element`. Returns the soul points added; 0, with nothing spent, when `units` is not positive, not a
## multiple of the rate, or more than `max_units`.
static func bank(rules: SoulRules, engine: SkillRulesEngine, soul: SoulProgress, element: String, units: int) -> int:
	if units <= 0 or rules.bank_rate <= 0 or units % rules.bank_rate != 0 or units > max_units(rules, engine, element):
		return 0
	if not engine.spend_essence(element, units):
		return 0
	@warning_ignore("integer_division")
	var gained := units / rules.bank_rate
	soul.add(gained)
	return gained
