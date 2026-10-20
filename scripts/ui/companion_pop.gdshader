// Colors the terminal companion's ink (design log 0143). Her frames are
// black ink on clear; the ink becomes color by how dense it is around it:
// hatched hair and clothes get a pink-to-violet gradient with a cyan
// shimmer passing over, the sparse lines of her face and hand stay bright,
// and a soft glow sits behind it all. Ink inside a frame's blush areas
// (its anim.cfg, log 0144) is drawn pink and glows pink. Needs the
// texture's mipmaps (the wide looks use them as a cheap blur).
shader_type canvas_item;

uniform vec4 hair_top : source_color = vec4(1.0, 0.36, 0.70, 1.0);
uniform vec4 hair_bottom : source_color = vec4(0.58, 0.40, 1.0, 1.0);
uniform vec4 lines : source_color = vec4(1.0, 0.93, 0.97, 1.0);
uniform vec4 shimmer : source_color = vec4(0.40, 0.95, 1.0, 1.0);
uniform float glow = 0.55;
uniform float shimmer_speed = 0.35;
uniform vec4 blush : source_color = vec4(1.0, 0.42, 0.58, 1.0);
// This frame's blush areas in UV: x0, y0, x1, y1; the first blush_count count.
uniform vec4 blush_areas[4];
uniform int blush_count = 0;

// 1 inside any blush area, fading to 0 just outside it.
float in_blush(vec2 uv, vec2 pixel) {
	float best = 0.0;
	for (int i = 0; i < 4; i++) {
		if (i >= blush_count) {
			break;
		}
		vec4 r = blush_areas[i];
		vec2 inside = min(uv - r.xy, r.zw - uv) / pixel;  // px in from the nearest edge
		best = max(best, smoothstep(-4.0, 4.0, min(inside.x, inside.y)));
	}
	return best;
}

void fragment() {
	// Thresholds drop the near-clear specks the pictures have in their
	// background, which would otherwise show as a faint box.
	float ink = smoothstep(0.12, 0.6, texture(TEXTURE, UV).a);
	float density = textureLod(TEXTURE, UV, 4.0).a;  // ink nearby, roughly
	float halo = smoothstep(0.04, 0.45, textureLod(TEXTURE, UV, 2.5).a);
	// Some pictures have a stray line of ink along an edge: fade the last
	// few pixels.
	vec2 px = UV / TEXTURE_PIXEL_SIZE;
	vec2 far = (1.0 - UV) / TEXTURE_PIXEL_SIZE;
	float edge = min(min(px.x, px.y), min(far.x, far.y));
	ink *= smoothstep(2.0, 5.0, edge);
	halo *= smoothstep(4.0, 18.0, edge);  // the blur spreads that line inward

	float wobble = 0.06 * sin(UV.x * 7.0 + TIME * 0.8);
	vec3 gradient = mix(hair_top.rgb, hair_bottom.rgb, clamp(UV.y + wobble, 0.0, 1.0));
	float hatched = smoothstep(0.10, 0.28, density);
	vec3 color = mix(lines.rgb, gradient, hatched);

	// A band of light sweeping diagonally over the hatching now and then.
	float sweep = fract((UV.x + UV.y) * 0.5 - TIME * shimmer_speed);
	float band = smoothstep(0.0, 0.06, sweep) * (1.0 - smoothstep(0.06, 0.14, sweep));
	color = mix(color, shimmer.rgb, band * hatched * 0.85);

	vec3 glow_color = mix(lines.rgb, gradient, 0.7);
	float blushing = in_blush(UV, TEXTURE_PIXEL_SIZE);
	color = mix(color, blush.rgb, blushing);
	glow_color = mix(glow_color, blush.rgb, blushing);
	COLOR.rgb = mix(glow_color, color, ink);
	COLOR.a = max(ink, halo * glow);
}
