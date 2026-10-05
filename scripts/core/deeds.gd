class_name Deeds
extends RefCounted
## What a run does, as ledger events a form's gate can count: how a kill was made, a guard broken, a hidden room found, a room
## cleared. They are emitted like any game event (and land in the rules engine's ledger), but they are not in Events.ALL, which two
## tests pin and the audio catalog must cover; `Deeds.known` is what the rules engine and the validators ask. A deed whose emitter does
## not exist yet is listed in RESERVED with the piece that will supply it, so a gate can be written now.

const DEFEATED := "defeated"
const GUARD_BROKEN := "guard_broken"
const BARRIER_BROKEN := "barrier_broken"
const HIDDEN_FOUND := "hidden_found"
const ROOM_CLEARED := "room_cleared"
const ROOM_ENTERED := "room_entered"
const SKILL_HIT := "skill_hit"
const SKILL_MISSED := "skill_missed"
const SWITCH_HIT := "switch_hit"
# no emitter yet: see RESERVED
const PART_HARVESTED := "part_harvested"
const GRAFT_ATTACHED := "graft_attached"
const GRAFT_SHED := "graft_shed"
const BOND_FORMED := "bond_formed"
const LESSON_LEARNED := "lesson_learned"
const TRAP_SPRUNG := "trap_sprung"
const WEAPON_FORGED := "weapon_forged"
const ITEM_STOLEN := "item_stolen"
const WARD_STONE_PLACED := "ward_stone_placed"
const PREY_COCOONED := "prey_cocooned"
const GAP_CROSSED := "gap_crossed"
const LAMP_DRUNK := "lamp_drunk"
const VILLAGE_KEPT := "village_kept"
const ROOM_HELD := "room_held"
const VIGIL_KEPT := "vigil_kept"
const CORPSE_LEFT := "corpse_left"
const ITEM_CARRIED := "item_carried"
const VILLAGE_VISITED_UNSEEN := "village_visited_unseen"
const PREY_FREED := "prey_freed"

const EVENTS := [DEFEATED, GUARD_BROKEN, BARRIER_BROKEN, HIDDEN_FOUND, ROOM_CLEARED, ROOM_ENTERED, SKILL_HIT, SKILL_MISSED, SWITCH_HIT,
	PART_HARVESTED, GRAFT_ATTACHED, GRAFT_SHED, BOND_FORMED, LESSON_LEARNED, TRAP_SPRUNG, WEAPON_FORGED, ITEM_STOLEN, WARD_STONE_PLACED,
	PREY_COCOONED, GAP_CROSSED, LAMP_DRUNK, VILLAGE_KEPT, ROOM_HELD, VIGIL_KEPT, CORPSE_LEFT, ITEM_CARRIED, VILLAGE_VISITED_UNSEEN, PREY_FREED]

## Every event a gate may count, and the tag keys it may name. Tags are true or absent (a false flag is left out), so a gate asks for
## `{"behind": true}`. The first block are the events the game already had.
const TAGS := {
	"jumped": [], "wall_touched": [], "damaged": ["damage_type"], "stunned_enemy": ["source"], "submerged": [],
	"predated": ["source", "kind", "species"], "absorbed": ["essence", "source"], "skill_used": ["id"],
	DEFEATED: ["source", "species", "behind", "ranged", "marked", "poison", "heavy", "ceiling", "dark", "unseen", "fleeing", "moonlit", "avenged"],
	GUARD_BROKEN: ["source"], BARRIER_BROKEN: [], HIDDEN_FOUND: [], ROOM_CLEARED: ["room", "alone"], ROOM_ENTERED: ["room", "area"],
	SKILL_HIT: ["id"], SKILL_MISSED: ["id"], SWITCH_HIT: ["far"],
	PART_HARVESTED: ["part"], GRAFT_ATTACHED: ["part"], GRAFT_SHED: ["part"], BOND_FORMED: ["kind", "creature"],
	LESSON_LEARNED: ["creature", "species", "element"], TRAP_SPRUNG: [], WEAPON_FORGED: [], ITEM_STOLEN: ["creature", "part"], WARD_STONE_PLACED: [],
	PREY_COCOONED: ["creature"], GAP_CROSSED: [], LAMP_DRUNK: [], VILLAGE_KEPT: [], ROOM_HELD: ["room"], VIGIL_KEPT: [], CORPSE_LEFT: ["source"],
	ITEM_CARRIED: [], VILLAGE_VISITED_UNSEEN: [], PREY_FREED: ["creature"],
}

## Deeds, and deed tags written `event.tag`, that nothing emits yet -> the piece that will. A later piece removes its own entries; the
## last one leaves it empty (tests/test_form_gates_data.gd lists what the gates still wait for).
const RESERVED := {
	BARRIER_BROKEN: "F2", HIDDEN_FOUND: "F2",  # the verbs report them; the rooms have nothing to dissolve or reveal yet
	VILLAGE_VISITED_UNSEEN: "F2", GAP_CROSSED: "F2", LAMP_DRUNK: "F2", VILLAGE_KEPT: "F2", ROOM_HELD: "F2", VIGIL_KEPT: "F2",
}

## A deed or an event the game always had.
static func known(event: String) -> bool:
	return EVENTS.has(event) or Events.ALL.has(event)

## Whether nothing emits `event` (or `event.tag`) yet.
static func is_reserved(key: String) -> bool:
	return RESERVED.has(key)
