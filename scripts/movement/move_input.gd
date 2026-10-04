class_name MoveInput
extends RefCounted
## What the body wants this tick, and what it stands on. The caller rebuilds it every tick (player.gd reads Input and
## the physics body; the sandbox and tests fill it by hand).

## Left (-1) to right (1); an analog stick gives a fraction.
var dir := 0.0
var on_floor := true
## True only on the tick the jump button went down; held is true for as long as it stays down.
var jump_pressed := false
var jump_held := false
