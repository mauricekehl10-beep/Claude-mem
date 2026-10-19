shader_type spatial;
// Wärmeflimmern hinter den Düsen: heisse Luft als schwach flimmernde, wandernde Schlieren (ohne Bildschirm-Textur, damit es überall läuft).
// Mesh: Zylinder der Höhe 1 wie bei iron_flame.gdshader.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float amount = 1.0;
uniform float seed = 0.0;

varying float vt;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	vt = clamp(0.5 - VERTEX.y, 0.0, 1.0);
	VERTEX.y -= 0.5;
}

void fragment() {
	float ndv = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float edge = pow(ndv, 1.2);
	float along = smoothstep(0.0, 0.15, vt) * pow(clamp(1.0 - vt, 0.0, 1.0), 0.9);
	// Schlieren laufen mit der Zeit nach hinten
	float ang = atan(NORMAL.x, NORMAL.z) * 1.5;
	float n = vnoise(vec2(vt * 9.0 - TIME * 7.0 + seed, ang * 2.0 + seed)) * 0.6 + vnoise(vec2(vt * 21.0 - TIME * 13.0, ang * 3.0 + TIME * 2.0)) * 0.4;
	float a = edge * along * smoothstep(0.3, 0.95, n) * amount;
	ALBEDO = vec3(1.0, 0.85, 0.65) * a * 0.12;
}
