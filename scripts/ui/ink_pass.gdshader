shader_type canvas_item;
// Ink on paper (logs 0191, 0194): a pass over the world that makes it look
// drawn by hand. Ink bleeds a little into the paper around it and the paper
// has fibrous grain. Flatland's fog: the farther from your eye (`focus`,
// your shape on screen), the paler the world gets and the more it's hatched
// over, one set of strokes, then a crossing set, the way a Flatlander
// reads distance by dimness. Hatching and grain are pinned to the world, so
// they scroll with it. Underground (chalk on slate) the bleed fades out and
// the hatching is in chalk.

uniform sampler2D screen : hint_screen_texture, filter_linear;
// The view's top-left in world px, and its size in px.
uniform vec2 origin = vec2(0.0);
uniform vec2 view_size = vec2(1280.0, 720.0);
// Your shape on screen, in px; the fog grows away from it.
uniform vec2 focus = vec2(640.0, 360.0);
uniform float bleed = 0.4;
uniform float grain = 0.07;
// How much fog: 0 is none (the menu's picture), 1 is the world's.
uniform float fog = 1.0;
// The fog starts this far from your eye and is thickest by fog_far, in px.
uniform float fog_near = 360.0;
uniform float fog_far = 1000.0;
// 0 above ground, 1 underground: the paper and the ink swap.
uniform float under = 0.0;
uniform vec3 ink = vec3(0.23, 0.16, 0.12);
uniform vec3 paper = vec3(0.937, 0.89, 0.784);
uniform vec3 chalk = vec3(0.925, 0.902, 0.839);
uniform vec3 slate = vec3(0.239, 0.255, 0.282);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// One set of pen strokes along `dir`, `gap` px apart: a little wavy, of
// uneven weight, broken now and then, as if drawn quickly by hand.
float strokes(vec2 world, vec2 dir, float gap, float seed) {
	vec2 across = vec2(-dir.y, dir.x);
	float along = dot(world, dir);
	float off = dot(world, across) + (noise(vec2(along * 0.02, seed)) - 0.5) * 3.0;
	float row = floor(off / gap);
	float d = abs(fract(off / gap) - 0.5) * gap;  // px from the stroke's middle
	float weight = mix(0.5, 1.1, hash(vec2(row, seed)));
	float line = 1.0 - smoothstep(weight * 0.5, weight * 0.5 + 0.9, d);
	// Each stroke stops and starts: gaps along it, placed per row.
	float dash = step(0.28, noise(vec2(along * 0.025 + row * 7.3, row + seed)));
	return line * dash;
}

void fragment() {
	vec2 px = 1.0 / view_size;
	vec2 world = origin + SCREEN_UV * view_size;
	vec3 c = texture(screen, SCREEN_UV).rgb;

	// Bleed: pale paper beside dark ink takes a little of it (not on slate).
	vec3 darkest = c;
	darkest = min(darkest, texture(screen, SCREEN_UV + vec2(px.x, 0.0)).rgb);
	darkest = min(darkest, texture(screen, SCREEN_UV - vec2(px.x, 0.0)).rgb);
	darkest = min(darkest, texture(screen, SCREEN_UV + vec2(0.0, px.y)).rgb);
	darkest = min(darkest, texture(screen, SCREEN_UV - vec2(0.0, px.y)).rgb);
	c = mix(c, darkest, bleed * (1.0 - under) * smoothstep(0.45, 0.8, luma(c)));

	// Fog: far things fade toward the paper, then get hatched over.
	float dist = length(SCREEN_UV * view_size - focus);
	float depth = smoothstep(fog_near, fog_far, dist) * fog;
	vec3 ground = mix(paper, slate, under);
	vec3 pen = mix(ink, chalk, under);
	c = mix(c, ground, depth * 0.35);
	float hatch = strokes(world, normalize(vec2(1.0, -1.0)), 7.0, 1.0) * smoothstep(0.0, 0.5, depth);
	hatch = max(hatch, strokes(world, normalize(vec2(1.0, 1.0)), 9.0, 2.0) * smoothstep(0.45, 1.0, depth));
	c = mix(c, pen, hatch * 0.16);

	// Grain: blotchy paper, with fibres running sideways.
	float g = noise(world * 0.8) * 0.45 + noise(world * 0.12) * 0.35
			+ noise(vec2(world.x * 0.04, world.y * 1.3)) * 0.2;
	c *= 1.0 - grain * g;

	COLOR = vec4(c, 1.0);
}
