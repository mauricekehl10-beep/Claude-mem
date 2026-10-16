shader_type spatial;
// Anzug der drei Helden. Gemalt wird nach der Position in der Ruhepose (T-Pose, Meter,
// Füsse bei y=0, +Z vorn, +X links). Die Position steckt in CUSTOM0 und bewegt sich mit
// dem Skelett mit. So bleiben Sterne, Streifen und Platten scharf, egal wie fein das Netz ist.

uniform int hero = 0;       // 0 Captain America, 1 Iron Man, 2 Thor
uniform bool joint = false; // true = Gelenk-Fläche

varying vec3 rp;

void vertex() {
	rp = CUSTOM0.xyz;
}

vec3 lin(vec3 c) {
	return pow(c, vec3(2.2));
}

// Deckung einer Form: d = Abstand zum Rand (negativ innen), w = Pixelgröße in Metern
float cov(float d, float w) {
	return clamp(0.5 - d / w, 0.0, 1.0);
}

float box2(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

// Linie bei v == at mit halber Dicke hw
float ln(float v, float at, float hw, float w) {
	return cov(abs(v - at) - hw, w);
}

// Fünfzackiger Stern, Spitze nach oben
float star5(vec2 p, float r, float rf) {
	vec2 k1 = vec2(0.809016994375, -0.587785252292);
	vec2 k2 = vec2(-k1.x, k1.y);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

// Streifen: 1 bei geraden Streifen, 0 bei ungeraden
float stripes(float y, float y0, float hs, float w) {
	float k = (y - y0) / hs;
	float e = max(w * 0.5 / hs, 0.001);
	return clamp((abs(fract(k * 0.5) - 0.5) - 0.25) / e, -0.5, 0.5) + 0.5;
}

#include "res://scripts/hero_face.gdshaderinc"

// ---------------------------------------------------------------- Captain America
// col/met/rou/emi = Farbe, Metall, Rauheit, Leuchten; hgt = Relief in Metern (für Kanten-Licht)
void cap(vec3 p, float w, out vec3 col, out float met, out float rou, out vec3 emi, out float hgt) {
	float ax = abs(p.x);
	vec3 blue = lin(vec3(0.07, 0.17, 0.52));
	vec3 navy = lin(vec3(0.045, 0.095, 0.32));
	vec3 red = lin(vec3(0.80, 0.07, 0.10));
	vec3 white = lin(vec3(0.94, 0.94, 0.95));
	vec3 brown = lin(vec3(0.30, 0.16, 0.08));
	vec3 skin = lin(vec3(0.90, 0.68, 0.55));
	vec3 silver = lin(vec3(0.70, 0.70, 0.66));
	col = blue;
	met = 0.05;
	rou = 0.62;
	emi = vec3(0.0);
	hgt = 0.0;
	float front = smoothstep(0.0, 0.04, p.z);
	float back = 1.0 - smoothstep(-0.04, 0.0, p.z);
	bool arm = ax > 0.2 && p.y > 1.28;

	if (p.y < 1.05 && !arm) {
		col = navy; // Hose
		// feine Naht an der Außenseite
		col = mix(col, blue, ln(ax, 0.17, 0.003, w) * smoothstep(0.35, 0.5, p.y) * (1.0 - smoothstep(0.9, 1.0, p.y)) * 0.5);
	}
	// Rumpf: dunklere Seiten und Schulterpartie
	if (!arm && p.y > 1.1 && p.y < 1.52) {
		float side = smoothstep(0.105, 0.13, ax) * (1.0 - smoothstep(1.36, 1.42, p.y));
		col = mix(col, navy, side * 0.7);
		col = mix(col, navy, smoothstep(1.43, 1.47, p.y) * 0.8);
	}
	// Brust: Stern
	if (!arm && p.y > 1.2 && p.y < 1.5) {
		float ds = star5(p.xy - vec2(0.0, 1.318), 0.085, 0.42);
		col = mix(col, white, cov(ds, w) * front);
		met = mix(met, 0.3, cov(ds, w) * front);
	}
	// Bauch: rote und weiße Streifen
	if (!arm && p.y > 1.095 && p.y < 1.262) {
		float s = stripes(p.y, 1.095, 0.0334, w);
		col = mix(white, red, s);
		rou = 0.55;
	}
	// Gürtel mit Schnalle
	if (!arm && p.y > 1.03 && p.y < 1.095) {
		col = brown;
		float bk = cov(box2(p.xy - vec2(0.0, 1.064), vec2(0.03, 0.021)), w) * front;
		col = mix(col, silver, bk);
		met = bk * 0.9;
		rou = mix(0.7, 0.25, bk);
		hgt = bk * 0.004 + 0.002;
	}
	// Rücken: kreuzende Lederriemen
	if (!arm && p.y > 1.09 && p.y < 1.47) {
		float s1 = cov(seg(p.xy, vec2(0.12, 1.45), vec2(-0.05, 1.11)) - 0.011, w);
		float s2 = cov(seg(p.xy, vec2(-0.12, 1.45), vec2(0.05, 1.11)) - 0.011, w);
		float st = max(s1, s2) * back;
		col = mix(col, brown, st);
		rou = mix(rou, 0.7, st);
		hgt = max(hgt, st * 0.003);
		float bk = cov(length(p.xy - vec2(0.0, 1.28)) - 0.017, w) * back;
		col = mix(col, silver, bk);
		met = mix(met, 0.9, bk);
	}
	// Ärmel, Handschuh
	if (arm) {
		col = blue;
		col = mix(col, navy, ln(ax, 0.215, 0.004, w) * 0.8);
		float glove = smoothstep(0.69, 0.71, ax);
		col = mix(col, brown, glove);
		// Stulpe (heller, wulstig)
		float cuff = ln(ax, 0.68, 0.016, w) * (1.0 - glove);
		col = mix(col, lin(vec3(0.42, 0.24, 0.12)), cuff);
		hgt = cuff * 0.003;
		rou = mix(0.62, 0.7, glove);
	}
	// Stiefel
	if (p.y < 0.30) {
		float b = 1.0 - smoothstep(0.285, 0.295, p.y);
		col = mix(col, lin(vec3(0.25, 0.13, 0.065)), b);
		float top = ln(p.y, 0.29, 0.012, w);
		col = mix(col, lin(vec3(0.42, 0.24, 0.12)), top);
		hgt = max(hgt, top * 0.003);
		col = mix(col, lin(vec3(0.07, 0.05, 0.04)), 1.0 - smoothstep(0.012, 0.02, p.y));
		rou = mix(rou, 0.65, b);
	}
	// Kopf: Haube mit offenem Gesicht (Öffnung: open_w, Relief: hero_face.gd)
	if (p.y > 1.545 && ax < 0.13) {
		float hm = smoothstep(0.03, 0.07, p.z);
		float od = ax - open_w(p.y);  // < 0 in der Öffnung
		float op = cov(od, w) * hm;
		// Haube: feines Gewebe, Mittelnaht, gesteppter Rand
		col = blue * (0.88 + 0.22 * vn(vec2(p.x + p.z, p.y) * 460.0));
		col *= 0.80 + 0.20 * smoothstep(-0.12, 0.08, p.z);
		rou = 0.52;
		hgt = 0.0;
		float seam = cov(abs(p.x) - 0.0009, w) * smoothstep(1.76, 1.78, p.y);
		col = mix(col, navy, seam * 0.8);
		float hem = cov(abs(od - 0.0030) - 0.0005, w) * hm * step(0.5, fract((p.y + ax * 0.6) * 240.0));
		col = mix(col, lin(vec3(0.20, 0.30, 0.65)), hem * 0.7 * (1.0 - op));
		col = mix(col, navy, 0.35 * gs(od - 0.004, 0.004) * hm * (1.0 - op));
		// Gesicht
		vec3 fcol = col;
		float frou = rou;
		vec3 femi = emi;
		human_face(p, w, skin, lin(vec3(0.30, 0.48, 0.70)), lin(vec3(0.20, 0.12, 0.07)), lin(vec3(0.62, 0.30, 0.28)), op, fcol, frou, femi);
		col = fcol;
		rou = frou;
		emi = femi;
		col *= 1.0 - 0.20 * gs(od + 0.003, 0.004) * op;
		// weißes A auf der Stirn
		vec2 q = vec2(ax, p.y - 1.7475);
		float la = seg(q, vec2(0.0145, -0.0175), vec2(0.0, 0.0165));
		float cb = seg(q, vec2(0.0, -0.0085), vec2(0.0082, -0.0085));
		float aa = cov(min(la, cb) - 0.0030, w) * hm * (1.0 - op);
		col = mix(col, white, aa);
		rou = mix(rou, 0.4, aa);
		hgt = aa * 0.002;
		// Rand der Haube am Hals
		col = mix(col, navy, ln(p.y, 1.545, 0.004, w) * 0.5);
	}
}

// ---------------------------------------------------------------- Iron Man
void iron(vec3 p, float w, out vec3 col, out float met, out float rou, out vec3 emi, out float hgt) {
	float ax = abs(p.x);
	vec3 red = lin(vec3(0.62, 0.025, 0.04));
	vec3 gold = lin(vec3(0.86, 0.55, 0.12));
	vec3 dark = lin(vec3(0.06, 0.06, 0.08));
	vec3 cyan = vec3(0.45, 0.9, 1.0);
	col = red;
	met = 0.8;
	rou = 0.3;
	emi = vec3(0.0);
	hgt = 0.0;
	float front = smoothstep(0.0, 0.04, p.z);
	bool arm = ax > 0.2 && p.y > 1.28;
	float line = 0.0;

	// Hüfte und Oberschenkel: rot, Naht
	if (p.y < 1.04 && !arm) {
		col = red;
		line = max(line, ln(p.y, 0.78, 0.0025, w));
		// goldene Hüftplatten seitlich
		float hp = cov(box2(vec2(ax - 0.165, p.y - 0.97), vec2(0.03, 0.05)), w);
		col = mix(col, gold, hp);
		line = max(line, ln(p.y, 0.86, 0.0022, w) * cov(ax - 0.07, w));
	}
	// Knie und Schienbein: Gold
	if (p.y < 0.62 && !arm) {
		float kn = cov(abs(p.y - 0.535) - 0.055, w);
		float shin = 1.0 - smoothstep(0.43, 0.45, p.y);
		col = mix(col, gold, max(kn, shin));
		line = max(line, ln(p.y, 0.34, 0.0025, w) * shin);
		line = max(line, ln(p.y, 0.25, 0.0025, w) * shin);
		line = max(line, ln(p.y, 0.595, 0.0025, w));
		line = max(line, ln(p.y, 0.475, 0.0025, w));
	}
	// Stiefel: Fuß rot, Knöchelring gold, Sohle dunkel
	if (p.y < 0.13) {
		col = mix(col, red, 1.0 - smoothstep(0.1, 0.12, p.y));
		col = mix(col, gold, ln(p.y, 0.125, 0.012, w));
		col = mix(col, dark, 1.0 - smoothstep(0.012, 0.02, p.y));
	}
	// Rumpf
	if (!arm && p.y > 1.04 && p.y < 1.52) {
		// Hüftgürtel
		float belt = cov(abs(p.y - 1.065) - 0.03, w);
		col = mix(red, gold, belt);
		// goldene Bauchplatten
		float ab = cov(abs(p.y - 1.17) - 0.07, w) * (1.0 - belt) * cov(ax - 0.095, w);
		col = mix(col, gold, ab);
		line = max(line, ln(p.y, 1.13, 0.002, w) * cov(ax - 0.1, w));
		line = max(line, ln(p.y, 1.17, 0.002, w) * cov(ax - 0.1, w));
		line = max(line, ln(p.y, 1.21, 0.002, w) * cov(ax - 0.1, w));
		line = max(line, ln(ax, 0.0, 0.002, w) * step(p.y, 1.24));
		// goldene Brustplatte (oben breit, unten schmal)
		float hw = mix(0.04, 0.105, clamp((p.y - 1.24) / 0.19, 0.0, 1.0));
		float cd = max(ax - hw, abs(p.y - 1.335) - 0.095) - 0.012;
		col = mix(col, gold, cov(cd, w) * front);
		line = max(line, cov(abs(cd) - 0.002, w) * front);
		// Rücken: goldene Wirbelplatte, zwei runde Düsen
		float bd = max(ax - mix(0.035, 0.05, clamp((p.y - 1.15) / 0.3, 0.0, 1.0)), abs(p.y - 1.30) - 0.15) - 0.01;
		col = mix(col, gold, cov(bd, w) * (1.0 - front));
		line = max(line, cov(abs(bd) - 0.002, w) * (1.0 - front));
		line = max(line, ln(p.y, 1.25, 0.0022, w) * cov(ax - 0.05, w) * (1.0 - front));
		float nz = length(vec2(ax - 0.085, p.y - 1.385));
		col = mix(col, gold, cov(nz - 0.032, w) * (1.0 - front));
		col = mix(col, dark, cov(nz - 0.024, w) * (1.0 - front));
		col = mix(col, cyan, cov(nz - 0.015, w) * (1.0 - front));
		emi = cyan * cov(nz - 0.015, w) * (1.0 - front) * 1.6;
		// Kragen
		col = mix(col, gold, ln(p.y, 1.475, 0.012, w));
		// Arc-Reaktor
		vec2 rc = p.xy - vec2(0.0, 1.322);
		float r = length(rc);
		float ring = cov(abs(r - 0.040) - 0.007, w) * front;
		float core = cov(r - 0.031, w) * front;
		col = mix(col, lin(vec3(0.15, 0.17, 0.2)), cov(r - 0.052, w) * front);
		col = mix(col, cyan, core);
		emi += cyan * (core * 2.4 + ring * 1.6) * (0.92 + 0.08 * sin(TIME * 3.0));
		met = mix(met, 0.0, core);
	}
	// Arme
	if (arm) {
		col = red;
		// Schulterkante
		col = mix(col, gold, ln(ax, 0.30, 0.012, w));
		// Ellbogen-Ring und goldener Unterarm
		float fa = smoothstep(0.50, 0.505, ax);
		col = mix(col, gold, fa);
		col = mix(col, gold, ln(ax, 0.44, 0.01, w));
		line = max(line, ln(ax, 0.50, 0.0025, w));
		line = max(line, ln(ax, 0.58, 0.0025, w));
		line = max(line, ln(ax, 0.66, 0.0025, w));
		// Hand rot, Handfläche (Repulsor) leuchtet
		float hand = smoothstep(0.715, 0.72, ax);
		col = mix(col, red, hand);
		line = max(line, ln(ax, 0.72, 0.003, w));
		float pal = cov(length(vec2(ax - 0.80, p.z + 0.055)) - 0.028, w) * (1.0 - smoothstep(1.40, 1.42, p.y));
		col = mix(col, cyan, pal);
		emi = cyan * pal * 4.0;
		met = mix(met, 0.0, pal);
	}
	// Kopf: roter Helm, goldene Gesichtsplatte (Relief: hero_face.gd)
	if (p.y > 1.545 && ax < 0.13) {
		col = red;
		line = 0.0;
		hgt = 0.0;
		float hm = smoothstep(0.03, 0.07, p.z);
		float md = ax - mask_w(p.y);
		float mask = cov(md, w) * hm;
		// Helmschale: Mittelrippe, Seitenfuge über den Ohren
		line = max(line, cov(ax - 0.0011, w) * smoothstep(1.74, 1.76, p.y) * (1.0 - cov(md, w) * hm));
		line = max(line, ln(p.y, 1.735, 0.0011, w) * smoothstep(0.075, 0.095, ax) * 0.8);
		col = mix(col, gold * (0.92 + 0.16 * vn(vec2(p.y * 700.0, ax * 60.0))), mask);
		met = mix(met, 0.95, mask);
		rou = mix(rou, 0.24, mask);
		// Fuge um die Platte
		line = max(line, cov(abs(md) - 0.0014, w) * hm);
		// Augenschlitze (schräg), leuchtend
		float ex = ax - 0.0275;
		float ey = p.y - (1.6665 + ex * 0.30);
		float hh = mix(0.0030, 0.0014, clamp((ex + 0.0165) / 0.033, 0.0, 1.0));
		float ed = max(abs(ex) - 0.0165, abs(ey) - hh);
		float eye = cov(ed, w) * hm * mask;
		line = max(line, cov(ed - 0.0018, w) * hm * mask * (1.0 - eye));
		col = mix(col, cyan * 0.9, eye);
		emi = cyan * eye * 2.4;
		met = mix(met, 0.0, eye);
		// Brauenkante, Nasenrücken, Wangenlinien, Mundspalt, Kinn
		line = max(line, cov(abs(p.y - (1.6835 + ax * 0.12) - 0.0035) - 0.0008, w) * (1.0 - smoothstep(0.040, 0.050, ax)) * mask);
		line = max(line, cov(abs(ax - mix(0.0075, 0.0044, clamp((1.690 - p.y) / 0.09, 0.0, 1.0))) - 0.0008, w) * smoothstep(1.595, 1.615, p.y) * (1.0 - smoothstep(1.685, 1.695, p.y)) * mask * 0.8);
		line = max(line, cov(seg(vec2(ax, p.y), vec2(0.0125, 1.628), vec2(0.0300, 1.578)) - 0.0010, w) * mask);
		line = max(line, cov(abs(p.y - 1.5935) - 0.0010, w) * (1.0 - smoothstep(0.013, 0.019, ax)) * mask);
		line = max(line, ln(p.y, 1.567, 0.0010, w) * mask);
		col *= 1.0 - 0.25 * gs(md + 0.002, 0.004) * mask;
	}
	if (p.y > 1.5 && p.y < 1.552 && ax < 0.12) {
		col = dark;
		met = 0.6;
	}
	col = mix(col, dark, line * 0.85);
	hgt = -line * 0.0025;
}

// ---------------------------------------------------------------- Thor
void thor(vec3 p, float w, out vec3 col, out float met, out float rou, out vec3 emi, out float hgt) {
	float ax = abs(p.x);
	vec3 dk = lin(vec3(0.07, 0.07, 0.085));
	vec3 silver = lin(vec3(0.74, 0.76, 0.80));
	vec3 leather = lin(vec3(0.20, 0.11, 0.06));
	vec3 skin = lin(vec3(0.88, 0.66, 0.52));
	vec3 blond = lin(vec3(0.80, 0.60, 0.22));
	col = dk;
	met = 0.3;
	rou = 0.55;
	emi = vec3(0.0);
	hgt = 0.0;
	float front = smoothstep(0.0, 0.04, p.z);
	bool arm = ax > 0.2 && p.y > 1.28;

	// Hose
	if (p.y < 1.04 && !arm) {
		col = lin(vec3(0.12, 0.10, 0.10));
		met = 0.0;
		rou = 0.7;
		// Lederriemen am Oberschenkel
		float st = max(ln(p.y, 0.74, 0.012, w), ln(p.y, 0.62, 0.008, w));
		col = mix(col, leather, st * step(0.5, p.y));
		hgt = st * 0.002;
	}
	// Stiefel
	if (p.y < 0.34) {
		float b = 1.0 - smoothstep(0.325, 0.335, p.y);
		col = mix(col, leather, b);
		float band = ln(p.y, 0.315, 0.014, w);
		col = mix(col, silver, band);
		met = mix(met, 0.85, band);
		hgt = band * 0.003;
		col = mix(col, lin(vec3(0.06, 0.045, 0.035)), 1.0 - smoothstep(0.012, 0.02, p.y));
		rou = mix(rou, 0.65, b);
	}
	// Rumpf: dunkle Rüstung mit silbernen Scheiben
	if (!arm && p.y > 1.04 && p.y < 1.52) {
		col = dk;
		met = 0.35;
		rou = 0.5;
		float f = front * (1.0 - smoothstep(1.44, 1.47, p.y)) * smoothstep(1.095, 1.115, p.y);
		float sp = 0.078;
		vec2 g = (p.xy - vec2(0.0, 1.0)) / sp;
		vec2 a = fract(g) - 0.5;
		vec2 b = fract(g - 0.5) - 0.5;
		vec2 gv = dot(a, a) < dot(b, b) ? a : b;
		float dd = length(gv) * sp;
		float disc = cov(dd - 0.027, w) * f * cov(ax - 0.15, w);
		float shade = 0.55 + 0.45 * smoothstep(0.027, 0.0, dd);
		col = mix(col, silver * shade, disc);
		met = mix(met, 0.55, disc);
		rou = mix(rou, 0.42, disc);
		hgt = disc * 0.004 * (0.5 + 0.5 * smoothstep(0.027, 0.01, dd));
		// Gürtel mit Schnalle
		float belt = cov(abs(p.y - 1.065) - 0.03, w);
		col = mix(col, leather, belt);
		met = mix(met, 0.0, belt);
		rou = mix(rou, 0.65, belt);
		float bk = cov(length(p.xy - vec2(0.0, 1.065)) - 0.026, w) * front;
		col = mix(col, silver, bk);
		met = mix(met, 0.9, bk);
		rou = mix(rou, 0.3, bk);
		hgt = max(hgt, bk * 0.004);
		// Rücken: Lederriemen über die Schulter
		float back = 1.0 - front;
		float s1 = cov(seg(p.xy, vec2(0.11, 1.45), vec2(-0.06, 1.1)) - 0.012, w);
		float s2 = cov(seg(p.xy, vec2(-0.11, 1.45), vec2(0.06, 1.1)) - 0.012, w);
		float st = max(s1, s2) * back * step(1.09, p.y);
		col = mix(col, leather, st);
		met = mix(met, 0.0, st);
		hgt = max(hgt, st * 0.003);
	}
	// Arme: nackte Oberarme, Armschienen
	if (arm) {
		col = skin;
		met = 0.0;
		rou = 0.65;
		// Schulter dunkel
		float sh = 1.0 - smoothstep(0.24, 0.27, ax);
		col = mix(col, dk, sh);
		// Armschiene
		float br = smoothstep(0.495, 0.50, ax) * (1.0 - smoothstep(0.715, 0.72, ax));
		col = mix(col, silver, br);
		met = mix(met, 0.85, br);
		rou = mix(rou, 0.35, br);
		float bands = max(ln(ax, 0.54, 0.006, w), max(ln(ax, 0.61, 0.006, w), ln(ax, 0.68, 0.006, w))) * br;
		col = mix(col, leather, bands);
		met = mix(met, 0.0, bands);
		hgt = bands * 0.003 + br * 0.002;
		// Handgelenk-Riemen
		float wr = smoothstep(0.715, 0.72, ax) * (1.0 - smoothstep(0.74, 0.745, ax));
		col = mix(col, leather, wr);
		hgt = max(hgt, wr * 0.003);
	}
	// Kopf: Haare, Gesicht, Vollbart (Relief: hero_face.gd; Haare und Bartsträhnen: hero_parts.gd)
	if (p.y > 1.545 && ax < 0.13) {
		float hm = smoothstep(0.03, 0.07, p.z);
		col = blond * (0.72 + 0.5 * vn(vec2(p.x * 380.0, p.y * 26.0 + p.z * 20.0)));
		met = 0.0;
		rou = 0.5;
		hgt = 0.0;
		float hairline = 1.723 + 0.009 * smoothstep(0.02, 0.055, ax);
		float sm = (1.0 - smoothstep(hairline - 0.003, hairline + 0.002, p.y)) * (1.0 - smoothstep(0.056, 0.064, ax)) * hm;
		vec3 fcol = col;
		float frou = rou;
		vec3 femi = emi;
		human_face(p, w, skin, lin(vec3(0.30, 0.50, 0.75)), lin(vec3(0.46, 0.33, 0.13)), lin(vec3(0.62, 0.33, 0.30)), sm, fcol, frou, femi);
		col = fcol;
		rou = frou;
		emi = femi;
		// Vollbart: Wangen, Kinn, Schnurrbart; der Mund bleibt frei
		float jt = 1.606 + 0.034 * smoothstep(0.030, 0.060, ax);
		float inz = (1.0 - smoothstep(jt - 0.003, jt + 0.003, p.y)) * (1.0 - smoothstep(0.056, 0.064, ax));
		float lipz = (1.0 - smoothstep(0.022, 0.028, ax)) * smoothstep(1.5815, 1.5845, p.y) * (1.0 - smoothstep(1.6075, 1.6105, p.y));
		float must = (1.0 - smoothstep(0.024, 0.030, ax)) * smoothstep(1.6055, 1.6085, p.y) * (1.0 - smoothstep(1.6195, 1.6215, p.y)) * smoothstep(0.0, 0.003, ax);
		float bcov = max(inz * (1.0 - lipz), must) * step(1.54, p.y);
		float bn = vn(p.xy * 330.0);
		float bm = smoothstep(0.35, 0.65, bcov + (bn - 0.5) * 0.45) * hm;
		vec3 bcol = lin(vec3(0.56, 0.40, 0.16)) * (0.60 + 0.75 * vn(vec2(p.x * 760.0, p.y * 48.0)));
		bcol *= 0.85 + 0.3 * smoothstep(1.54, 1.60, p.y);
		col = mix(col, bcol, bm);
		rou = mix(rou, 0.7, bm);
	}
	if (p.y > 1.5 && p.y < 1.552 && ax < 0.12) {
		col = skin;
		met = 0.0;
		rou = 0.65;
	}
}

void fragment() {
	vec3 p = rp;
	float w = max(length(fwidth(p)), 0.0004);
	vec3 col;
	float met;
	float rou;
	vec3 emi;
	float hgt;
	if (hero == 0) {
		cap(p, w, col, met, rou, emi, hgt);
	} else if (hero == 1) {
		iron(p, w, col, met, rou, emi, hgt);
	} else {
		thor(p, w, col, met, rou, emi, hgt);
	}
	if (joint) {
		col *= 0.6;
		if (hero == 1) {
			met = 0.85;
			rou = 0.4;
		}
		emi = vec3(0.0);
		hgt = 0.0;
	}
	// Relief: Höhe nach Bildschirm-Gefälle in die Normale kippen (Kanten fangen Licht)
	vec2 slope = vec2(dFdx(hgt), dFdy(hgt)) / w;
	NORMAL = normalize(NORMAL - vec3(slope, 0.0) * 2.0);
	ALBEDO = col;
	METALLIC = met;
	ROUGHNESS = rou;
	SPECULAR = 0.3;
	EMISSION = emi;
}
