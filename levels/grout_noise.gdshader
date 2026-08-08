shader_type canvas_item;

// Adds a little coherent (Perlin gradient) noise to the flat background ColorRect,
// so the grout showing between the hex floor tiles isn't perfectly uniform and the
// board reads less samey. The noise only lightens (adds 0 .. strength to the
// colour), so it stays a subtle texture rather than a pattern.
uniform float strength : hint_range(0.0, 1.0) = 0.2;
// Noise frequency in 1/pixels of board space -- roughly one feature per few tiles.
uniform float noise_scale = 0.006;

varying vec2 board_pos;

// A pseudo-random unit gradient vector for the integer lattice point p.
vec2 grad(vec2 p) {
	float a = fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123) * 6.2831853;
	return vec2(cos(a), sin(a));
}

// 2D Perlin gradient noise, remapped from its ~[-0.707, 0.707] range to ~[0, 1].
float perlin(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = dot(grad(i), f);
	float b = dot(grad(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
	float c = dot(grad(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
	float d = dot(grad(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
	float n = mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
	return clamp(n * 0.7071 + 0.5, 0.0, 1.0);
}

void vertex() {
	// Local (board-space) position, so the variation sticks to the board rather
	// than the screen when the level is scaled to fit.
	board_pos = VERTEX;
}

void fragment() {
	COLOR.rgb += perlin(board_pos * noise_scale) * strength;
}
