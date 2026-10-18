shader_type spatial;
#include "res://scripts/city_common.gdshaderinc"
#include "res://scripts/weather_wet.gdshaderinc"
// Flachdach: Teerpappe/Kies mit Bahnen, Flecken und Pfuetzen; UV = Weltmeter (x,z).

uniform sampler2D n_grain : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D n_blotch : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D n_crack : repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec3 tone : source_color = vec3(0.17, 0.17, 0.18);

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wp.xz;
	float px = max(max(length(dFdx(p)), length(dFdy(p))), 0.003);
	float g1 = texture(n_grain, p * 0.8).r;
	float g2 = texture(n_grain, p * 2.7 + vec2(0.2, 0.4)).r;
	float b1 = texture(n_blotch, p * 0.06).r;
	float b2 = texture(n_blotch, p * 0.19 + vec2(0.7, 0.1)).r;
	vec3 col = tone * COLOR.rgb;
	col *= 0.7 + 0.6 * b1;
	col *= 0.85 + 0.3 * b2;
	// Kies
	float gravel = smoothstep(0.45, 0.75, g1) * (1.0 - smoothstep(0.02, 0.08, px));
	col = mix(col, col * 1.5, gravel * 0.5);
	col *= 0.88 + 0.24 * g2;
	// Dachbahnen (1 m breit)
	float sx = fract(p.x * 0.9);
	float seam = 1.0 - smoothstep(0.0, 0.02 + px, min(sx, 1.0 - sx));
	col *= 1.0 - 0.28 * seam;
	// Flecken
	col *= 1.0 - 0.3 * smoothstep(0.62, 0.9, texture(n_blotch, p * 0.11 + vec2(0.3, 0.8)).r);
	// Pfuetzen
	float pud = smoothstep(0.80 - 0.25 * wx_wet, 0.86 - 0.25 * wx_wet, texture(n_blotch, p * 0.045 + vec2(0.5, 0.2)).r); // Wetter: bei Regen mehr Pfuetzen
	col *= (1.0 - 0.4 * pud) * (1.0 - 0.3 * wx_wet);
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.92, 0.4, wx_wet), 0.03, pud);
	SPECULAR = 0.4;
	float bf = 1.0 - smoothstep(0.03, 0.1, px);
	NORMAL = bump_normal(NORMAL, VERTEX, (g1 * 0.004 + g2 * 0.002 - seam * 0.002) * bf, 1.0);
}
