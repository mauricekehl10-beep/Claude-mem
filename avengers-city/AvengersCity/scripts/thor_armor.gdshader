shader_type spatial;
render_mode cull_disabled;
// Rüstungsteile von Thor (Scheiben, Platten, Armschienen, Leder, roter Stoff, Mjolnir).
// Gemalt wird nach der Position im Teil (Ruhepose bzw. Teil-Koordinaten). COLOR.a = Kantenabnutzung (1 an Kanten).

uniform int kind = 0;   // 0 Silber, 1 dunkles Metall, 2 Leder, 3 roter Stoff, 4 Mjolnir-Kopf, 5 Mjolnir-Griff, 6 Kettenhemd
uniform vec4 base : source_color = vec4(0.62, 0.64, 0.68, 1.0);
uniform float metal = 0.9;
uniform float rough = 0.35;

varying vec3 lp;
varying vec4 vc;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	lp = VERTEX;
	vc = COLOR;
}

float cov(float d, float w) {
	return clamp(0.5 - d / w, 0.0, 1.0);
}

float box2(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

void fragment() {
	float w = max(length(fwidth(lp)), 0.0003);
	vec3 col = base.rgb;
	float met = metal;
	float rou = rough;
	float hgt = 0.0;
	float wear = vc.a;
	vec3 emi = vec3(0.0);
	float rim = 0.0;
	if (kind == 0 || kind == 1) {
		// gebürstetes Metall: feine Linien entlang der Platte, leichte Kratzer, abgeriebene Kanten
		float br = vn(vec2(lp.x * 420.0 + lp.z * 90.0, lp.y * 24.0 + lp.z * 30.0));
		float br2 = vn(vec2(lp.y * 380.0 + lp.z * 120.0, lp.x * 30.0));
		float sc = vn(vec2(lp.x * 90.0 + lp.y * 50.0, lp.z * 90.0 + lp.y * 40.0));
		col *= 0.80 + 0.20 * br + 0.10 * br2;
		col *= 1.0 - 0.18 * smoothstep(0.72, 0.95, sc);
		rou = rough + 0.12 * br2 + 0.10 * smoothstep(0.7, 1.0, sc);
		hgt = (br - 0.5) * 0.00008;
		if (kind == 1) {
			col = mix(col, col * vec3(0.8, 0.9, 1.3), 0.25 * br);
		}
		col = mix(col, base.rgb * 1.25, wear * 0.55);
		rou = mix(rou, 0.22, wear * 0.7);
	} else if (kind == 2) {
		// Leder: Narbung, Falten, helle abgegriffene Kanten
		float gr = vn(lp.xy * 260.0) * vn(lp.yz * 210.0 + 3.0) + vn(lp.xz * 330.0 + 7.0) * 0.5;
		float fl = vn(vec2(lp.y * 40.0 + lp.x * 9.0, lp.x * 70.0));
		col *= 0.70 + 0.34 * gr + 0.18 * fl;
		col = mix(col, base.rgb * 1.8, wear * 0.45);
		rou = rough + 0.15 * gr;
		hgt = (gr - 0.5) * 0.0003 + (fl - 0.5) * 0.0004;
		met = 0.0;
	} else if (kind == 3) {
		// roter Samtstoff: dichte Fasern, Falten, heller Schimmer an den Rändern der Falten
		float fb = vn(lp.xy * 520.0) * 0.5 + vn(lp.yz * 610.0 + 2.0) * 0.5;
		float fo = sin(lp.x * 38.0 + vn(lp.yz * 6.0) * 4.0) * 0.5 + 0.5;
		col *= 0.78 + 0.22 * fb;
		col *= 0.80 + 0.30 * fo;
		hgt = (fo - 0.5) * 0.004 + (fb - 0.5) * 0.0001;
		met = 0.0;
		rou = 0.92;
		rim = 0.55;
	} else if (kind == 4) {
		// Mjolnir-Kopf: dunkelsilbernes Metall, eingravierte Rahmenlinien und Muster. lp = Teil-Koordinaten (x quer, y Griffachse, z lang)
		float br = vn(vec2(lp.z * 360.0, lp.y * 22.0 + lp.x * 30.0));
		float br2 = vn(vec2(lp.x * 300.0 + lp.z * 40.0, lp.y * 300.0));
		float sc = vn(vec2(lp.x * 140.0 + lp.z * 70.0, lp.y * 120.0 + lp.z * 90.0));
		col *= 0.76 + 0.24 * br + 0.08 * br2;
		col *= 1.0 - 0.22 * smoothstep(0.70, 0.95, sc);
		rou = rough + 0.14 * br2 + 0.12 * smoothstep(0.65, 1.0, sc);
		// Gravuren: Rahmen auf den Seiten und Endplatten
		vec3 an = abs(lp);
		vec3 ex = vec3(0.0575, 0.0525, 0.086);   // halbe Außenmaße (x, y, z)
		float g = 0.0;
		// lange Seiten (Normale in x): Rahmen und Raute
		vec3 nrm = abs(vec3(dot(normalize(cross(dFdx(lp), dFdy(lp))), vec3(1.0, 0.0, 0.0)),
			dot(normalize(cross(dFdx(lp), dFdy(lp))), vec3(0.0, 1.0, 0.0)),
			dot(normalize(cross(dFdx(lp), dFdy(lp))), vec3(0.0, 0.0, 1.0))));
		if (nrm.x > 0.6) {
			float d1 = box2(lp.zy, vec2(ex.z - 0.024, ex.y - 0.024));
			float d2 = box2(lp.zy, vec2(ex.z - 0.040, ex.y - 0.040));
			g = max(cov(abs(d1) - 0.0016, w), cov(abs(d2) - 0.0010, w) * 0.8);
			// Rune in der Mitte
			vec2 q = lp.zy * vec2(1.0, 1.0);
			float rn = min(cov(abs(abs(q.x) + abs(q.y) * 1.8 - 0.030) - 0.0014, w), 1.0);
			g = max(g, rn * 0.9);
		} else if (nrm.z > 0.6) {
			float d1 = box2(lp.xy, vec2(ex.x - 0.012, ex.y - 0.012));
			g = cov(abs(d1) - 0.0014, w);
			g = max(g, cov(abs(lp.x) - 0.0014, w) * cov(abs(lp.y) - 0.028, w));
			g = max(g, cov(abs(lp.y) - 0.0014, w) * cov(abs(lp.x) - 0.028, w));
		} else {
			float d1 = box2(lp.xz, vec2(ex.x - 0.012, ex.z - 0.020));
			g = cov(abs(d1) - 0.0014, w);
		}
		col = mix(col, col * 0.28, g);
		rou = mix(rou, 0.5, g);
		hgt = -g * 0.0007 + (br - 0.5) * 0.00006;
		col = mix(col, base.rgb * 1.25, wear * 0.6);
		rou = mix(rou, 0.2, wear * 0.7);
	} else if (kind == 5) {
		// Mjolnir-Griff: dunkles Leder mit silbernem Zickzack-Geflecht, lp.y = Länge
		float a = atan(lp.z, lp.x);
		float t = lp.y * 62.0;
		float zz = abs(fract(t + a * 0.955) - 0.5) * 2.0;
		float zz2 = abs(fract(-t + a * 0.955) - 0.5) * 2.0;
		float ln = min(zz, zz2);
		float wire = smoothstep(0.30, 0.18, ln);
		vec3 lea = vec3(0.025, 0.020, 0.018) * (0.7 + 0.5 * vn(vec2(a * 40.0, lp.y * 300.0)));
		vec3 sil = vec3(0.50, 0.52, 0.56) * (0.8 + 0.3 * vn(vec2(a * 30.0, lp.y * 200.0)));
		col = mix(lea, sil, wire);
		met = mix(0.1, 0.85, wire);
		rou = mix(0.7, 0.35, wire);
		hgt = wire * 0.0006;
	} else {
		float fb = vn(lp.xy * 400.0);
		col *= 0.8 + 0.2 * fb;
	}
	// Relief: Höhe nach Bildschirm-Gefälle in die Normale kippen
	vec2 slope = vec2(dFdx(hgt), dFdy(hgt)) / w;
	NORMAL = normalize(NORMAL - vec3(slope, 0.0) * 2.0);
	ALBEDO = col;
	METALLIC = met;
	ROUGHNESS = clamp(rou, 0.05, 1.0);
	SPECULAR = 0.5;
	EMISSION = emi;
	if (rim > 0.0) {
		RIM = rim;
		RIM_TINT = 0.3;
	}
}
