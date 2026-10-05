class_name VerbArena
extends RefCounted
## A small arena a verb is cast in, for the whole-set tests: a fresh Player at the origin facing right and hurt a little, three stub
## foes ahead, a real lizard, a hidden thing, some water essence to spend and a creature appraised. snapshot() reads everything a
## cast can change, so a verb that does nothing shows as an equal snapshot. (Not the player's position or speed: it falls here.)

class Foe extends Node2D:
	var team := "enemy"
	var hits: Array = []
	func receive_hit(raw: int, damage_type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		hits.append([raw, damage_type])

class Hidden extends Node2D:
	var revealed := 0
	func reveal() -> void:
		revealed += 1

const GROUPS := ["verb_fields", "verb_allies", "verb_vines", "verb_husks", "verb_bridges", "player_clouds"]
const STATS := ["atk", "def", "spd", "max_hp", "max_mp"]

var test: GutTest
var rules: SkillRulesEngine
var player: Player
var foes: Array = []
var lizard: Enemy
var hidden: Hidden
var _skills: Array
var _creatures := {}
var _skills_by_id := {}

func _init(p_test: GutTest) -> void:
	test = p_test
	_skills = DefLoader.load_dir("res://data/skills")
	for d in _skills:
		_skills_by_id[d.id] = d
	for c in DefLoader.load_dir("res://data/creatures"):
		_creatures[c.id] = c

## A clean arena: nothing from the last cast (a glide, a buff, a mark) is left to change this snapshot.
func fresh() -> void:
	rules = test.autofree(SkillRulesEngine.new())
	rules.setup(_skills)
	player = Player.new()
	player.setup(rules, CompendiumModel.new(_skills, []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	test.add_child_autofree(player)
	rules.start_run()
	foes = []
	for x in [40.0, 80.0, 120.0]:
		var f := Foe.new()
		test.add_child_autofree(f)
		f.add_to_group("actors")
		f.global_position = Vector2(x, 0)
		foes.append(f)
	lizard = Enemy.new()
	lizard.setup(_creatures["lizard"], _skills_by_id)
	lizard.position = Vector2(30, 0)
	test.add_child_autofree(lizard)
	lizard.health.max_hp = 100
	lizard.health.hp = 100
	hidden = Hidden.new()
	test.add_child_autofree(hidden)
	hidden.add_to_group("hidden")
	hidden.global_position = Vector2(60, 0)
	player.global_position = Vector2.ZERO
	player.facing = 1
	player.health.hp = player.health.max_hp - 10
	player.mana.mp = player.mana.max_mp - 8
	for i in 5:
		rules.handle_event(Events.ABSORBED, {"essence": "water", "source": "test"})
	player.last_inspected = _creatures["lizard"]

## The verb a form grants, built as the Player builds it, on the arena's player.
func verb(form_id: String) -> VerbAbility:
	var d: SkillDef = _skills_by_id["verb_" + form_id]
	var a: VerbAbility = load(SkillEffects.active_scene(d)).instantiate()
	player.add_child(a)
	a.spec = SkillEffects.active_spec(d)
	a.setup(player, SkillEffects.active_values(d), 1)
	return a

func snapshot() -> Dictionary:
	var hits := 0
	for f in foes:
		hits += f.hits.size()
	var out := {"hits": hits, "hp": lizard.health.hp, "rooted": lizard.is_rooted(), "state": lizard.status.state, "mark": player.has_meta(VerbKinds.ANCHOR_META),
		"water": rules.held("water"), "glide": player._glide, "ward": player._ward, "my_hp": player.health.hp, "my_mp": player.mana.mp,
		"revealed": hidden.revealed}
	for g in GROUPS:
		out[g] = test.get_tree().get_nodes_in_group(g).size()
	for s in STATS:
		out[s] = player.stats.get_stat(s)
	return out

## Cast `form_id`'s verb once, wait a moment and say whether anything changed.
func changes_something(form_id: String) -> bool:
	var before := snapshot()
	var ability := verb(form_id)
	if not ability.activate():
		return false
	await test.wait_physics_frames(2)
	return snapshot() != before

func clean() -> void:
	for g in GROUPS:
		for n in test.get_tree().get_nodes_in_group(g):
			n.free()
	for n in foes + [lizard, hidden, player]:
		if is_instance_valid(n):
			n.free()
