shader_type spatial;
#include "res://scripts/city_common.gdshaderinc"
// Parkrasen mit Maehstreifen, Wegen aus hellem Kies, Blumenbeeten. UV = Meter relativ zur Blockmitte.

uniform sampler2D n_blotch : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D n_grain : repeat_enable, filter_linear_mipmap_anisotropic;
uniform int variant = 0;

varying vec3 wp;
varying vec2 lp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lp = UV;
}

void fragment() {
	vec2 p = lp;
	float px = max(max(length(dFdx(p)), length(dFdy(p))), 0.003);
	float b1 = texture(n_blotch, wp.xz * 0.021).r;
	float b2 = texture(n_blotch, wp.xz * 0.09 + vec2(0.3, 0.1)).r;
	float g1 = texture(n_grain, wp.xz * 1.3).r;
	float g2 = texture(n_grain, wp.xz * 4.1 + vec2(0.5, 0.2)).r;
	// Wege
	float dpath = 100.0;
	float plaza = length(p) - 8.5;
	if (variant == 0) {
		dpath = min(min(abs(p.x), abs(p.y)) - 1.6, plaza);
	} else if (variant == 1) {
		dpath = min(min(abs(p.x - p.y), abs(p.x + p.y)) * 0.7071 - 1.6, plaza);
	} else {
		dpath = min(min(abs(length(p) - 15.0) - 1.5, min(abs(p.x), abs(p.y)) - 1.2), plaza);
	}
	float path = 1.0 - smoothstep(-px, px, dpath);
	float edge = 1.0 - smoothstep(0.0, 0.12 + px, abs(dpath));
	// Rasen
	vec3 grass = mix(vec3(0.035, 0.12, 0.02), vec3(0.08, 0.2, 0.03), b1);
	grass = mix(grass, vec3(0.12, 0.2, 0.04), smoothstep(0.55, 0.85, b2) * 0.6);
	float stripe = step(0.5, fract(p.x / 3.5 + 0.5 * floor(p.y / 7.0))) * 0.12;
	grass *= 0.85 + stripe + 0.25 * g1;
	grass *= 0.8 + 0.4 * g2;
	// Blumen im Beet um den Platz
	float bed = smoothstep(14.0, 10.5, length(p)) * smoothstep(8.5, 9.6, length(p));
	vec2 fc = floor(p * 3.2);
	float fh = hash21(fc);
	float flower = step(0.9, fh) * bed * (1.0 - smoothstep(0.15, 0.3, length(fract(p * 3.2) - 0.5)));
	vec3 fcol = mix(mix(vec3(0.8, 0.1, 0.1), vec3(0.9, 0.75, 0.1), step(0.35, hash21(fc + 3.0))), vec3(0.85, 0.85, 0.9), step(0.7, hash21(fc + 7.0)));
	grass = mix(grass, fcol, flower);
	vec3 gravel = vec3(0.32, 0.28, 0.21) * (0.75 + 0.5 * g1) * (0.85 + 0.3 * b1);
	gravel = mix(gravel, gravel * 0.7, smoothstep(0.6, 0.9, g2) * 0.5);
	vec3 col = mix(grass, gravel, path);
	col *= 1.0 - 0.3 * edge * path;
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.9, path);
	SPECULAR = 0.25;
	float bf = 1.0 - smoothstep(0.03, 0.1, px);
	NORMAL = bump_normal(NORMAL, VERTEX, (g1 * 0.012 + g2 * 0.005) * mix(1.0, 0.3, path) * bf, 1.0);
}
