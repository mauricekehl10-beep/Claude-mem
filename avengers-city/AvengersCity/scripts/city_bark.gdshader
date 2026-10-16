shader_type spatial;
#include "res://scripts/city_common.gdshaderinc"
// Rinde: senkrechte Furchen aus Rauschen (Eiche, Ahorn, Nadelbaum); Birke: helle Rinde mit dunklen Querflecken.
// UV: x = Umfang in Metern, y = Laenge in Metern. COLOR = Rindenfarbe.

uniform sampler2D n_grain : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D n_blotch : repeat_enable, filter_linear_mipmap_anisotropic;
uniform bool birch = false;

varying vec2 buv;
varying float by;

void vertex() {
	buv = UV;
	by = VERTEX.y;
}

void fragment() {
	vec3 tint = COLOR.rgb;
	float f1 = texture(n_grain, vec2(buv.x * 1.3, buv.y * 0.14)).r;
	float f2 = texture(n_blotch, vec2(buv.x * 0.6 + 0.3, buv.y * 0.09)).r;
	float f3 = texture(n_grain, vec2(buv.x * 3.1 + 0.5, buv.y * 0.5)).r;
	vec3 col;
	float h;
	if (birch) {
		float m = texture(n_grain, vec2(buv.x * 0.9, buv.y * 1.7)).r;
		float dark = smoothstep(0.60, 0.68, m) * smoothstep(0.35, 0.6, f2);
		col = tint * (0.9 + 0.2 * f3);
		col = mix(col, vec3(0.07, 0.065, 0.06), dark * 0.9);
		col = mix(col, col * vec3(0.7, 0.68, 0.55), smoothstep(1.2, 0.0, by) * 0.6);
		h = dark * 0.01 + f3 * 0.004;
	} else {
		float fis = 1.0 - smoothstep(0.3, 0.62, f1);
		col = tint * (0.5 + 0.9 * f1) * (0.78 + 0.45 * f2);
		col *= 1.0 - 0.5 * fis;
		col = mix(col, col * vec3(0.8, 0.95, 0.7), smoothstep(0.55, 0.9, f3) * 0.35);
		h = (f1 * 0.02 + f3 * 0.006);
	}
	ALBEDO = col;
	ROUGHNESS = birch ? 0.7 : 0.95;
	SPECULAR = 0.2;
	NORMAL = bump_normal(NORMAL, VERTEX, h, 1.0);
}
