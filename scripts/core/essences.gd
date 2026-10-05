class_name Essences
extends RefCounted
## Essence names. FIRST_PASS are the five elements the shipped creatures carry; LATER are the three that arrive with the volcano
## (fire), the sacred hall (mind) and the cemetery (blood). The order is canonical: Player emits ABSORBED in the order of ALL.

const WATER := "water"
const EARTH := "earth"
const AIR := "air"
const LIGHT := "light"
const DARK := "dark"
const FIRE := "fire"
const MIND := "mind"
const BLOOD := "blood"

const FIRST_PASS := [WATER, EARTH, AIR, LIGHT, DARK]
const LATER := [FIRE, MIND, BLOOD]
## The whole vocabulary: what a creature, a skill or a form may name.
const ALL := [WATER, EARTH, AIR, LIGHT, DARK, FIRE, MIND, BLOOD]

## The pair Transmute moves essence between: the first-pass element held most (at least `need` of it) and the one held least of the
## others, ties in element order. Empty when none is held enough or every element is held as much as the most (nowhere to move it).
## It never names fire, mind or blood: those arrive from the world, not from a verb.
static func transmute_pair(held: Dictionary, need: int) -> Array:
	var from := ""
	for e in FIRST_PASS:
		if int(held.get(e, 0)) >= need and (from == "" or int(held[e]) > int(held[from])):
			from = e
	if from == "":
		return []
	var to := ""
	for e in FIRST_PASS:
		if e != from and (to == "" or int(held.get(e, 0)) < int(held.get(to, 0))):
			to = e
	if int(held.get(to, 0)) >= int(held[from]):
		return []
	return [from, to]
