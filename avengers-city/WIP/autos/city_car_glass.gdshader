shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;
#include "res://scripts/city_common.gdshaderinc"
#include "res://scripts/weather_wet.gdshaderinc"
// Autoscheiben: leicht getoent, durchscheinend, spiegelnd (Fresnel macht sie zum Rand hin undurchsichtiger).
// Bei Regen perlen Tropfen auf den Scheiben.

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	float ndv = clamp(dot(n, normalize(VIEW)), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 3.0);
	float dark = COLOR.r;
	float bead = 0.0;
	if (wx_rain > 0.1) {
		vec2 q = lp.xz * 55.0 + lp.y * 45.0;
		vec2 id = floor(q);
		vec2 f = fract(q) - vec2(0.5);
		vec2 o = (hash22(id) - 0.5) * 0.5;
		float rad = 0.10 + 0.22 * hash21(id + 1.7);
		bead = (1.0 - smoothstep(rad - 0.06, rad, length(f - o))) * step(0.45, hash21(id)) * smoothstep(0.1, 0.5, wx_rain);
		float px = max(max(length(dFdx(VERTEX)), length(dFdy(VERTEX))), 0.0005);
		NORMAL = bump_normal(NORMAL, VERTEX, bead * 0.0008 * (1.0 - smoothstep(0.004, 0.02, px)), 1.0);
	}
	ALBEDO = vec3(0.008, 0.014, 0.018);
	ROUGHNESS = mix(0.02, 0.06, bead);
	METALLIC = 0.25;
	SPECULAR = 0.95;
	ALPHA = clamp(mix(0.66 + dark * 0.26 + bead * 0.12, 1.0, fres), 0.0, 1.0);
}
