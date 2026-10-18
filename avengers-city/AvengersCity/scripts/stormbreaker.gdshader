shader_type spatial;
render_mode cull_disabled;
// Stormbreaker: dunkles Uru-Metall mit blau-weiss leuchtenden Adern und Schneide, Holzstiel mit Glühen, Leder, Kern.
// kind: 0 = Uru-Metall, 1 = Holzstiel, 2 = Lederwickel, 3 = leuchtender Kern.
// glow = Aufladung (0 aus, 1 normal, 2 voll aufgeladen). edge_mode = 1: COLOR.r markiert die Schneide (nur das Blatt).

uniform int kind = 0;
uniform vec3 base = vec3(0.16, 0.17, 0.20);
uniform vec3 glow_col = vec3(0.28, 0.60, 1.0);
uniform float glow = 1.0;
uniform float edge_mode = 0.0;
uniform float fade = 1.0; // 0..1: Stoff löst sich auf (Wechsel, Wurf)

varying vec3 lp;
varying float edge;

float h31(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vn3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(h31(i), h31(i + vec3(1, 0, 0)), f.x), mix(h31(i + vec3(0, 1, 0)), h31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h31(i + vec3(0, 0, 1)), h31(i + vec3(1, 0, 1)), f.x), mix(h31(i + vec3(0, 1, 1)), h31(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

void vertex() {
	lp = VERTEX;
	edge = COLOR.r;
}

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 emi = vec3(0.0);
	float pulse = 0.85 + 0.15 * sin(TIME * 5.0 + lp.y * 4.0) + 0.1 * sin(TIME * 13.0 + lp.z * 7.0);
	if (kind == 0) {
		// Uru-Metall: gebürstet, dunkel, etwas bläulich
		float brush = vn3(vec3(lp.x * 90.0, lp.y * 4.0, lp.z * 90.0));
		float bl = vn3(lp * 11.0);
		ALBEDO = base * (0.75 + 0.5 * brush) * (0.85 + 0.3 * bl);
		METALLIC = 0.92;
		ROUGHNESS = 0.28 + 0.3 * brush;
		// Adern: dünne Linien dort, wo das Rauschen 0,5 kreuzt (zwei Größen), langsam wandernd
		float n1 = vn3(lp * 17.0 + vec3(0.0, TIME * 0.5, 0.0));
		float n2 = vn3(lp * 36.0 + vec3(3.0, -TIME * 0.7, 1.0));
		float vein = (1.0 - smoothstep(0.0, 0.045, abs(n1 - 0.5))) + 0.4 * (1.0 - smoothstep(0.0, 0.05, abs(n2 - 0.5)));
		float e = pow(clamp(edge, 0.0, 1.0), 11.0) * edge_mode;
		float strength = (vein * 0.55 * pulse + e * 3.0 + rim * 0.12) * glow;
		emi = mix(glow_col, vec3(1.0), clamp(strength * 0.22 - 0.25, 0.0, 0.7)) * strength;
	} else if (kind == 1) {
		// Stiel: dunkles Holz mit Maserung, nach oben dringt die Energie hinein
		float ang = atan(lp.z, lp.x);
		float grain = vn3(vec3(ang * 4.0, lp.y * 7.0, 1.0)) * 0.6 + vn3(vec3(ang * 9.0, lp.y * 30.0, 5.0)) * 0.4;
		ALBEDO = vec3(0.19, 0.10, 0.05) * (0.55 + 0.9 * grain);
		METALLIC = 0.0;
		ROUGHNESS = 0.62;
		float up = smoothstep(0.35, 0.80, lp.y);
		float spiral = 1.0 - smoothstep(0.0, 0.10, abs(fract(lp.y * 11.0 + ang * 0.318) - 0.5) * 2.0 - 0.85);
		float vein = (1.0 - smoothstep(0.0, 0.07, abs(vn3(vec3(ang * 3.0, lp.y * 16.0, TIME * 0.4)) - 0.5)));
		emi = glow_col * (vein * up * 1.4 + spiral * up * 0.5 + rim * 0.15) * glow * pulse;
	} else if (kind == 2) {
		// Lederwickel
		float w = vn3(vec3(lp.x * 60.0, lp.y * 90.0, lp.z * 60.0));
		ALBEDO = vec3(0.075, 0.045, 0.03) * (0.6 + 0.9 * w);
		METALLIC = 0.0;
		ROUGHNESS = 0.85;
		emi = glow_col * rim * 0.08 * glow;
	} else {
		// Kern: weiss-blau glühend
		ALBEDO = vec3(0.02, 0.03, 0.05);
		ROUGHNESS = 0.2;
		emi = mix(glow_col, vec3(1.0), 0.6) * (2.2 + 1.0 * sin(TIME * 7.0)) * glow;
	}
	EMISSION = emi * fade;
	if (fade < 0.999) {
		// Auflösen: Körnchen verschwinden zuerst
		float d = vn3(lp * 40.0 + vec3(0.0, 0.0, TIME));
		if (d > fade * 1.15) {
			discard;
		}
	}
}
