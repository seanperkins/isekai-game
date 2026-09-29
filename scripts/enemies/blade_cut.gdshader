shader_type canvas_item;
// Draws one half of a sprite, split by a line through its centre. `normal` points to the kept side.

uniform vec2 normal = vec2(0.0, -1.0);
uniform float side = 1.0;
varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	if (dot(local, normal) * side < 0.0) {
		discard;
	}
}
