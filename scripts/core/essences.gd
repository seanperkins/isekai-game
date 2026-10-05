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
