shader_type spatial;
#include "res://scripts/city_common.gdshaderinc"
// Allzweck-Shader fuer Strassenmoebel, Dachaufbauten, Gesimse: Farbe aus Vertexfarbe (sRGB), UV2 = (Rauheit, Metall), UV.x = Leuchtstaerke.

uniform sampler2D n_grain : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D n_blotch : repeat_enable, filter_linear_mipmap_anisotropic;

varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 col = pow(COLOR.rgb, vec3(2.2));
	float px = max(max(length(dFdx(wp)), length(dFdy(wp))), 0.002);
	vec2 tp = wp.xz + vec2(wp.y * 0.7, wp.y * 1.3);
	float g1 = texture(n_grain, tp * 0.9).r;
	float g2 = texture(n_blotch, tp * 0.12).r;
	float k = mix(1.0, 0.82 + 0.36 * g1, 1.0 - smoothstep(0.02, 0.08, px));
	col *= k * (0.88 + 0.24 * g2);
	// Staub und Schmutz nahe am Boden
	float low = 1.0 - smoothstep(0.0, 1.2, wp.y);
	col *= 1.0 - 0.25 * low * g2;
	ALBEDO = col;
	ROUGHNESS = UV2.x;
	METALLIC = UV2.y;
	SPECULAR = 0.5;
	EMISSION = col * UV.x;
	float bf = 1.0 - smoothstep(0.03, 0.1, px);
	NORMAL = bump_normal(NORMAL, VERTEX, (g1 - 0.5) * 0.002 * bf, 1.0);
}
