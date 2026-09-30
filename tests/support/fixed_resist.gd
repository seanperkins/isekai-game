class_name FixedResist
extends PlayerSkillSet
## Test double: a skill set whose incoming-damage reduction is a fixed percent, so a test can pick any resistance without
## levelling a skill. Install it with `player.skillset = FixedResist.make(rules, player.stats, pct)`.

var percent := 0

static func make(p_rules: SkillRulesEngine, p_stats: Stats, pct: int) -> FixedResist:
	var s := FixedResist.new(p_rules, p_stats)
	s.percent = pct
	return s

func incoming(_damage_type: String, _hp: int, _max_hp: int) -> Dictionary:
	return {"percent_off": percent, "flat_off": 0}
