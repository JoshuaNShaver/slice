shader_type canvas_item;
render_mode unshaded, blend_disabled;
// One Flatland eye (FlatView, design logs 0238-0240, 0249): drawn into a strip
// one pixel wide, a row per ray. Each ray starts at the eye and walks out
// through `world` (FlatMap: only solid things and the sea, in flat
// colours) until it meets something. The row takes its colour, lightening
// into the background with distance, gone by `range_px`; a ray that meets
// nothing sees only the background.

uniform sampler2D world : filter_nearest, repeat_disable;
uniform vec2 eye_uv = vec2(0.5);  // the eye in `world`
uniform vec2 uv_per_px = vec2(0.0003);  // `world` uv per world px
uniform float range_px = 450.0;  // the farthest an eye sees
uniform float step_px = 2.0;  // a ray's stride
uniform float top_angle = -1.0472;  // the top row's ray, radians (screen: -pi/2 is up)
uniform float sweep = 2.0944;  // from the top row to the bottom one
uniform vec4 far_color : source_color = vec4(0.94, 0.89, 0.78, 1.0);

const int MAX_STEPS = 800;

void fragment() {
	float a = top_angle + sweep * UV.y;
	vec2 per_px = vec2(cos(a), sin(a)) * uv_per_px;
	vec3 col = far_color.rgb;
	float d = 0.0;
	for (int i = 0; i < MAX_STEPS; i++) {
		if (d > range_px) {
			break;
		}
		vec2 uv = eye_uv + per_px * d;
		vec4 s = textureLod(world, uv, 0.0);
		if (s.a > 0.5 && uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0) {
			float fog = pow(clamp(d / range_px, 0.0, 1.0), 0.75);
			col = mix(s.rgb, far_color.rgb, fog);
			break;
		}
		d += step_px;
	}
	COLOR = vec4(col, 1.0);
}
