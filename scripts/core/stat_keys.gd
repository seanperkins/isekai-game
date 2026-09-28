class_name StatKeys
extends RefCounted
## Stat keys. INTEGER stats are whole numbers, PERCENT stats are percents of base 100,
## and regen_interval is in seconds (0 means no regeneration).

const MAX_HP := "max_hp"
const ATK := "atk"
const DEF := "def"
const SPD := "spd"
const JUMP_HEIGHT := "jump_height"
const SLIDE_SPEED := "slide_speed"
const PREDATION_TIME := "predation_time"
const REGEN_INTERVAL := "regen_interval"
const MAX_MP := "max_mp"
const MP_REGEN := "mp_regen"

const ALL := [MAX_HP, ATK, DEF, SPD, JUMP_HEIGHT, SLIDE_SPEED, PREDATION_TIME, REGEN_INTERVAL, MAX_MP, MP_REGEN]
const INTEGER := [MAX_HP, ATK, DEF, MAX_MP]
const PERCENT := [SPD, JUMP_HEIGHT, SLIDE_SPEED, PREDATION_TIME, MP_REGEN]
