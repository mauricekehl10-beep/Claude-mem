shader_type spatial;
render_mode cull_disabled;
#include "res://scripts/city_common.gdshaderinc"
// Eisengitter (Feuertreppen, Gelaender, Zaeune, Gitter). UV in Metern. kind: 0 Gitterrost (Plattform), 1 Gelaender, 2 Staebe (Zaun), 3 Netz

uniform int kind = 1;
uniform vec3 iron_col : source_color = vec3(0.045, 0.05, 0.05);
uniform float bar_gap = 0.14;
uniform float bar_w = 0.018;

void fragment() {
	vec2 uv = UV;
	float px = max(max(length(dFdx(uv)), length(dFdy(uv))), 0.002);
	float a = 0.0;
	if (kind == 0) {
		// Gitterrost: engmaschig, bei Entfernung geschlossene Flaeche
		vec2 g = abs(fract(uv / 0.05) - 0.5) * 0.05;
		float c = max(cov(g.x, 0.0, 0.007, px), cov(g.y, 0.0, 0.007, px));
		a = mix(c, 0.65, smoothstep(0.01, 0.04, px));
		a = max(a, cov(uv.x, -0.1, 0.04, px) * 0.0);
	} else if (kind == 1) {
		// Gelaender: senkrechte Staebe, Handlauf oben, Fusslauf unten (UV.y = Hoehe in m)
		float bx = abs(fract(uv.x / bar_gap) - 0.5) * bar_gap;
		float bars = cov(bx, 0.0, bar_w * 0.5, px) * step(0.05, uv.y) * step(uv.y, 0.95);
		float top = cov(uv.y, 0.93, 1.0, px);
		float bot = cov(uv.y, 0.0, 0.07, px);
		float mid = cov(uv.y, 0.45, 0.49, px);
		a = max(max(bars, top), max(bot, mid));
		a = mix(a, 0.6, smoothstep(0.02, 0.06, px) * step(0.0, uv.y) * step(uv.y, 1.0));
	} else if (kind == 2) {
		float bx = abs(fract(uv.x / bar_gap) - 0.5) * bar_gap;
		float bars = cov(bx, 0.0, bar_w * 0.5, px);
		a = max(bars, max(cov(uv.y, 0.0, 0.06, px), cov(abs(uv.y - 0.2), 0.0, 0.025, px)));
		a = mix(a, 0.55, smoothstep(0.03, 0.08, px));
	} else {
		vec2 g = abs(fract(uv / 0.12) - 0.5) * 0.12;
		a = max(cov(g.x, 0.0, 0.006, px), cov(g.y, 0.0, 0.006, px));
		a = mix(a, 0.4, smoothstep(0.03, 0.08, px));
	}
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
	ALBEDO = iron_col * (0.8 + 0.4 * vnoise(uv * 9.0));
	ROUGHNESS = 0.6;
	METALLIC = 0.5;
}
