class_name PlayerSkillSet
extends RefCounted
## Turns the player's owned skills into stat modifiers, capability flags, active slots,
## incoming-damage reductions and triggers. Recomputed from SkillRules on every change.

signal slot_replaced(new_id: String, old_id: String)

var rules: SkillRulesEngine
var stats: Stats
var slots := ActiveSlots.new()
var capabilities := {}
## What the body adds on top of the skills: stat modifiers (source "form") and trait flags.
var form_mods: Array = []
var form_flags := {}

func _init(p_rules: SkillRulesEngine, p_stats: Stats) -> void:
	rules = p_rules
	stats = p_stats
	# A method callable, not a lambda: a lambda would capture self and form a RefCounted
	# cycle with slots, leaking one skill set per run.
	slots.slot_replaced.connect(_forward_slot_replaced)

func on_skill_unlocked(id: String) -> void:
	var d := rules.get_def(id)
	if d != null and SkillEffects.active_scene(d) != "":
		if d.replaces != "":
			slots.replace(d.replaces, id)
		else:
			slots.add(id)
	refresh()

func refresh() -> void:
	stats.clear_modifiers()
	capabilities.clear()
	for id in rules.owned():
		var d := rules.get_def(id)
		var lv := rules.level_of(id)
		stats.set_modifiers(id, SkillEffects.stat_modifiers(d, lv))
		capabilities.merge(SkillEffects.capabilities(d, lv), true)
	if not form_mods.is_empty():
		stats.set_modifiers(FormEffects.SOURCE, form_mods)
	capabilities.merge(form_flags, true)
	if capabilities.has("trait_sonar") and capabilities.has("reveals_hidden"):
		capabilities["reveals_hidden"] = int(capabilities["reveals_hidden"]) + 1  # sonar: Echolocation reads one level stronger

func reset() -> void:
	slots.reset()
	form_mods = []
	form_flags = {}
	refresh()

func has(flag: String) -> bool:
	return capabilities.has(flag)

func level(flag: String) -> int:
	return int(capabilities.get(flag, 0))

func incoming(damage_type: String, hp: int, max_hp: int) -> Dictionary:
	var pairs: Array = []
	for id in rules.owned():
		pairs.append([rules.get_def(id), rules.level_of(id)])
	var out := SkillEffects.damage_reduction(pairs, damage_type, hp, max_hp)
	if damage_type == "poison" and has("trait_venom_blood"):
		out["percent_off"] = mini(100, int(out["percent_off"]) + FormEffects.VENOM_PERCENT)
	if has("trait_hard_shell"):
		out["flat_off"] = int(out["flat_off"]) + FormEffects.SHELL_FLAT
	return out

## Extra healing from owned triggers matching this event (e.g. Glutton on creature eats).
func heal_on(event_name: String, tags: Dictionary) -> int:
	var total := 0
	for id in rules.owned():
		var t: Dictionary = rules.get_def(id).trigger
		if t.is_empty() or t.get("on", "") != event_name or t.get("action", "") != "heal":
			continue
		if Ledger._matches(tags, t.get("tags", {})):
			total += int(t.get("amount", 0))
	return total

func _forward_slot_replaced(new_id: String, old_id: String) -> void:
	slot_replaced.emit(new_id, old_id)
