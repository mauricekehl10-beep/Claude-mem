shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Dampfwolken aus Gullydeckeln und Dampfschloten: Billboard-Puffs, die aufsteigen, wachsen und verblassen.
// Pro Instanz: INSTANCE_CUSTOM = (Phase 0..1, Geschwindigkeit, Groesse, Hoehe).

uniform sampler2D n_blotch : repeat_enable, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(0.92, 0.93, 0.95);

varying float v_age;
varying vec2 v_seed;

void vertex() {
	float ph = INSTANCE_CUSTOM.x;
	float sp = INSTANCE_CUSTOM.y;
	float sz = INSTANCE_CUSTOM.z;
	float hh = INSTANCE_CUSTOM.w;
	float age = fract(TIME * sp * 0.18 + ph);
	v_age = age;
	v_seed = vec2(ph * 13.0, ph * 7.0);
	// Weltposition der Instanz
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float rise = hh * (1.0 - pow(1.0 - age, 1.6));
	vec3 wind = vec3(0.35, 0.0, 0.15) * age * age * hh * 0.45;
	vec3 wob = vec3(sin(TIME * 0.6 + ph * 40.0), 0.0, cos(TIME * 0.5 + ph * 30.0)) * 0.25 * age * sz;
	vec3 c = origin + vec3(0.0, rise, 0.0) + wind + wob;
	float s = sz * mix(0.35, 1.7, sqrt(age));
	// Billboard
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 wpv = c + right * VERTEX.x * s + up * VERTEX.y * s;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wpv, 1.0);
}

void fragment() {
	vec2 u = UV * 2.0 - 1.0;
	float r = length(u);
	float n = texture(n_blotch, UV * 0.8 + v_seed * 0.1 + vec2(TIME * 0.01, 0.0)).r;
	float shape = smoothstep(1.0, 0.25, r + (n - 0.5) * 0.7);
	float fade = smoothstep(0.0, 0.12, v_age) * (1.0 - smoothstep(0.35, 1.0, v_age));
	ALBEDO = tint * (0.92 + 0.1 * n);
	ALPHA = shape * fade * 0.55;
}
