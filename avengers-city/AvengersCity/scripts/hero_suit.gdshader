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
	// Kopf: Haube mit offenem Gesicht
	if (p.y > 1.545 && ax < 0.13) {
		col = blue;
		rou = 0.5;
		hgt = 0.0;
		float hm = smoothstep(0.03, 0.07, p.z);
		float op = cov(box2(vec2(p.x, p.y - 1.640), vec2(0.040, 0.050)) - 0.020, w) * hm;
		col = mix(col, skin, op);
		rou = mix(rou, 0.65, op);
		// Augen, Brauen, Mund
		float eye = cov(box2(vec2(ax - 0.030, p.y - 1.664), vec2(0.010, 0.0045)), w);
		float brow = cov(seg(vec2(ax, p.y), vec2(0.02, 1.682), vec2(0.045, 1.690)) - 0.0035, w);
		float mouth = cov(seg(p.xy, vec2(-0.016, 1.598), vec2(0.016, 1.598)) - 0.0025, w);
		col = mix(col, lin(vec3(0.07, 0.05, 0.05)), max(eye, brow * 0.8) * hm);
		col = mix(col, lin(vec3(0.55, 0.22, 0.20)), mouth * hm);
		// weißes A auf der Stirn
		vec2 q = p.xy - vec2(0.0, 1.735);
		float la = seg(vec2(ax, q.y), vec2(0.0, 0.016), vec2(0.014, -0.014));
		float cb = seg(q, vec2(-0.008, -0.004), vec2(0.008, -0.004));
		col = mix(col, white, cov(min(la, cb) - 0.0028, w) * hm);
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
	// Kopf: roter Helm, goldene Maske
	if (p.y > 1.545 && ax < 0.13) {
		col = red;
		line = 0.0;
		float hm = smoothstep(0.03, 0.07, p.z);
		float fp = box2(vec2(p.x, p.y - 1.640), vec2(0.036, 0.058)) - 0.016;
		float mask = cov(fp, w) * hm;
		col = mix(col, gold, mask);
		col = mix(col, dark, cov(abs(fp) - 0.0018, w) * hm);
		// Augenschlitze
		vec2 eq = vec2(ax - 0.030, p.y - 1.668);
		float eye = cov(box2(vec2(eq.x + eq.y * 0.9, eq.y), vec2(0.019, 0.0065)), w) * hm;
		col = mix(col, cyan, eye);
		emi = cyan * eye * 3.0;
		met = mix(met, 0.0, eye);
		// Mund- und Wangenlinien
		float mo = cov(seg(p.xy, vec2(-0.018, 1.598), vec2(0.018, 1.598)) - 0.0018, w) * hm;
		float ch = cov(seg(vec2(ax, p.y), vec2(0.010, 1.628), vec2(0.030, 1.600)) - 0.0015, w) * hm;
		col = mix(col, dark, max(mo, ch) * 0.8);
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
	// Kopf: Haare, Gesicht, Bart
	if (p.y > 1.545 && ax < 0.13) {
		col = blond;
		met = 0.0;
		rou = 0.55;
		hgt = 0.0;
		float hm = smoothstep(0.03, 0.07, p.z);
		float op = cov(box2(vec2(p.x, p.y - 1.655), vec2(0.040, 0.050)) - 0.018, w) * hm;
		col = mix(col, skin, op);
		rou = mix(rou, 0.65, op);
		// Bart: unterer Teil des Gesichts
		float beard = cov(box2(vec2(p.x, p.y - 1.598), vec2(0.040, 0.020)) - 0.012, w) * hm;
		float must = cov(seg(vec2(ax, p.y), vec2(0.0, 1.632), vec2(0.026, 1.626)) - 0.004, w) * hm;
		col = mix(col, lin(vec3(0.62, 0.45, 0.17)), max(beard, must));
		// Augen und Brauen
		float eye = cov(box2(vec2(ax - 0.030, p.y - 1.676), vec2(0.009, 0.004)), w);
		float brow = cov(seg(vec2(ax, p.y), vec2(0.018, 1.692), vec2(0.045, 1.698)) - 0.0035, w);
		col = mix(col, lin(vec3(0.15, 0.30, 0.55)), eye * hm);
		col = mix(col, lin(vec3(0.45, 0.32, 0.12)), brow * hm * 0.9);
		// Mund
		float mouth = cov(seg(p.xy, vec2(-0.014, 1.618), vec2(0.014, 1.618)) - 0.002, w) * hm;
		col = mix(col, lin(vec3(0.45, 0.2, 0.15)), mouth);
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
