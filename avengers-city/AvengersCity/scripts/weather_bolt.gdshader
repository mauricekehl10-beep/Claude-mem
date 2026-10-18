shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
// Blitz-Band (Gewitter): helles, additives Leuchten; Helligkeit setzt scripts/weather.gd.

uniform float intensity = 6.0;

void fragment() {
	// Kern heller, Rand weich (UV.x quer zum Band)
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	ALBEDO = vec3(0.72, 0.82, 1.0) * intensity * (0.15 + 0.85 * across * across);
	ALPHA = 1.0;
}
