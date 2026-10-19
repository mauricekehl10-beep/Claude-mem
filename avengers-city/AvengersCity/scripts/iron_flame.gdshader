shader_type spatial;
// Düsenflamme von Iron Man: heller Kern, orange Rand, flackernd, Spitze läuft aus.
// Mesh: Zylinder der Höhe 1 (oben Düse, unten Ende). Die Grösse kommt aus der Skalierung (x/z = Radius, y = Länge).
// grow = 0: Nadel (spitzer Kern), grow = 1: Schweif, der nach hinten breiter wird und weich ausläuft.
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 core_col : source_color = vec3(1.0, 0.97, 0.88);
uniform vec3 mid_col : source_color = vec3(1.0, 0.74, 0.32);
uniform vec3 edge_col : source_color = vec3(1.0, 0.38, 0.10);
uniform float energy = 2.0;
uniform float alpha_mul = 0.7;
uniform float seed = 0.0;
uniform float grow = 0.0;

varying float vt;

void vertex() {
	vt = clamp(0.5 - VERTEX.y, 0.0, 1.0);
	VERTEX.y -= 0.5;
	float needle = 1.0 - pow(vt, 1.15);
	float plume = (0.45 + 1.5 * sqrt(vt)) * (1.0 - smoothstep(0.78, 1.0, vt));
	float prof = mix(needle, plume, grow);
	// Flackern: der Mantel pulsiert in Wellen entlang der Flamme
	float w = 1.0 + 0.11 * sin(vt * 13.0 - TIME * 41.0 + seed) + 0.06 * sin(vt * 31.0 - TIME * 67.0 + seed * 1.7);
	VERTEX.xz *= prof * w;
}

void fragment() {
	float ndv = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float body = pow(ndv, mix(1.25, 1.6, grow));
	float along = pow(clamp(1.0 - vt, 0.0, 1.0), mix(1.1, 1.0, grow));
	// Stossdiamanten: Helligkeitsringe, die nach hinten wandern
	float diam = 0.8 + 0.2 * sin(vt * 24.0 - TIME * 55.0 + seed);
	float flick = 0.9 + 0.1 * sin(TIME * 47.0 + seed * 3.1) * sin(TIME * 29.0 + seed);
	float a = body * along * mix(diam, 1.0, grow) * flick;
	vec3 c = mix(core_col, mid_col, smoothstep(0.08, mix(0.6, 0.25, grow), vt));
	c = mix(c, edge_col, smoothstep(mix(0.45, 0.15, grow), 1.0, vt));
	c = mix(edge_col, c, smoothstep(0.0, 0.8, body));
	ALBEDO = c * a * energy;
	ALPHA = clamp(a * alpha_mul, 0.0, 1.0);
}
