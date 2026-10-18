// Iron-Man-Panzer (Mark III / Avengers): dunkel verwitterter Klarlack, abgenutztes Gold, Silber-Platten.
// Wird von hero_suit.gdshader (Körper) und ironman_part.gdshader (Panzerteile aus Netzen) eingebunden.
// Alle Positionen sind Ruhepose-Koordinaten (Meter, Füsse bei y=0, +Z vorn, +X links).
// Stoffe (id): 0 roter Lack, 1 Gold, 2 Silber, 3 dunkles Metall, 4 helles Metall (Ringe), 5 Leuchten,
// 6 Wabengitter, 7 Gesichtsplatte, 8 Helmschale

vec3 im_lin(vec3 c) {
	return pow(c, vec3(2.2));
}

float im_cov(float d, float w) {
	return clamp(0.5 - d / w, 0.0, 1.0);
}

float im_gs(float x, float s) {
	return exp(-x * x / (2.0 * s * s));
}

float im_box(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float im_seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

float im_h3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float im_n3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(im_h3(i), im_h3(i + vec3(1, 0, 0)), f.x), mix(im_h3(i + vec3(0, 1, 0)), im_h3(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(im_h3(i + vec3(0, 0, 1)), im_h3(i + vec3(1, 0, 1)), f.x), mix(im_h3(i + vec3(0, 1, 1)), im_h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float im_fbm(vec3 p) {
	return im_n3(p) * 0.5 + im_n3(p * 2.03 + 3.1) * 0.3 + im_n3(p * 4.1 + 7.7) * 0.2;
}

// feine Kratzer: dünne, lange Streifen in einzelnen Bereichen (nur aus der Nähe sichtbar)
float im_scratch(vec3 p, float sd) {
	vec3 q = p + sd;
	float a = im_n3(vec3(q.x * 700.0, q.y * 15.0, q.z * 700.0));
	float b = im_n3(vec3((q.x + q.y) * 520.0, (q.x - q.y) * 12.0, q.z * 520.0));
	float c = im_n3(vec3(q.x * 13.0, q.y * 640.0, q.z * 640.0));
	float d = im_n3(vec3((q.z + q.y) * 560.0, (q.z - q.y) * 11.0, q.x * 560.0));
	float g = smoothstep(0.52, 0.78, im_fbm(q * 9.0));
	return smoothstep(0.80, 0.93, max(max(a, b), max(c, d))) * g;
}

// Basisfarben je Stoff; Abnutzung, Schmutz und Kratzer kommen darüber.
// id: Stoff, trim: 0 keine, 1 goldene Kantenlinie, 2 dunkle Zierlinie, 3 goldener Rand
// ed = Abstand zum Rand der Platte in Metern (gross = weit weg), sd = Zufallsstart je Platte
void im_mat(int id, int trim, vec3 p, float w, float ed, float sd,
		out vec3 col, out float met, out float rou, out vec3 emi, out float hgt) {
	vec3 red = im_lin(vec3(0.45, 0.028, 0.040));
	vec3 gold = im_lin(vec3(0.76, 0.55, 0.21));
	vec3 silver = im_lin(vec3(0.50, 0.53, 0.62));
	vec3 dark = im_lin(vec3(0.040, 0.040, 0.052));
	vec3 bare = im_lin(vec3(0.62, 0.52, 0.38)); // blankes Metall unter dem Lack
	emi = vec3(0.0);
	hgt = 0.0;
	float lod = smoothstep(0.0012, 0.0045, w); // aus der Ferne keine Feinheiten (flimmert sonst)
	float low = im_fbm(p * 6.0 + sd);
	float mid = mix(im_fbm(p * 34.0 + sd * 3.0), 0.5, lod);
	float fine = mix(im_n3(p * 520.0 + sd), 0.5, lod);
	bool painted = id == 0 || id == 8;
	if (painted) {
		col = red * (0.72 + 0.6 * low) * (0.94 + 0.12 * fine);
		met = 0.40;
		rou = 0.28 + 0.10 * mid;
	} else if (id == 1 || id == 7) {
		col = gold * (0.68 + 0.6 * low) * mix(vec3(1.0), vec3(0.80, 0.76, 0.52), 0.55 * mid) * (0.95 + 0.1 * fine);
		met = 0.70;
		rou = 0.30 + 0.16 * mid;
	} else if (id == 2) {
		col = silver * (0.70 + 0.5 * low) * mix(vec3(1.0), vec3(0.80, 0.85, 1.0), mid) * (0.96 + 0.08 * fine);
		met = 0.72;
		rou = 0.26 + 0.14 * mid;
	} else if (id == 4) {
		col = silver * (0.8 + 0.4 * low);
		met = 1.0;
		rou = 0.22;
	} else if (id == 5) {
		col = vec3(0.7, 0.9, 1.0);
		met = 0.0;
		rou = 0.4;
		emi = vec3(0.55, 0.88, 1.0) * 3.0;
	} else {
		col = dark * (0.8 + 0.5 * low);
		met = 0.60;
		rou = 0.42;
	}
	// Plattenfuge und Zierlinien (Relief fängt Licht)
	float groove = 1.0 - smoothstep(0.0006, 0.0018, ed);
	col *= 1.0 - 0.80 * groove;
	hgt -= groove * 0.0014;
	if (trim == 1) {
		float tl = im_cov(abs(ed - 0.0065) - 0.0020, w);
		col = mix(col, gold * (0.75 + 0.4 * mid), tl * 0.9);
		met = mix(met, 0.93, tl);
		hgt += tl * 0.0007;
	} else if (trim == 2) {
		float inset = im_cov(abs(ed - 0.0105) - 0.0006, w);
		col = mix(col, col * 0.35, inset * 0.9);
		hgt -= inset * 0.0006;
	} else if (trim == 3) {
		float tb = im_cov(ed - 0.011, w);
		col = mix(col, gold * (0.75 + 0.4 * mid), (1.0 - tb) * 0.95);
		met = mix(met, 0.93, 1.0 - tb);
	} else if (trim == 4) {
		// Brustplatte: Zierlinie am Rand, Schluesselbein und untere Brustkante
		float inset = im_cov(abs(ed - 0.0105) - 0.0006, w);
		float axx = abs(p.x);
		float fr = smoothstep(0.02, 0.07, p.z);
		float l1 = im_cov(im_seg(vec2(axx, p.y), vec2(0.055, 1.425), vec2(0.185, 1.462)) - 0.0008, w);
		float l2 = im_cov(im_seg(vec2(axx, p.y), vec2(0.02, 1.246), vec2(0.178, 1.306)) - 0.0008, w);
		float ln2 = max(inset * 0.9, max(l1, l2) * fr);
		col = mix(col, col * 0.30, ln2);
		hgt -= ln2 * 0.0008;
	}
	// Abnutzung: Lack platzt an den Kanten ab, Staub und Russ in Mulden und unten
	float edgeb = 1.0 - smoothstep(0.0, 0.012, ed);
	float chip = smoothstep(0.42, 0.62, mid + edgeb * 0.25 - 0.08);
	float wear = edgeb * chip;
	float dirt = smoothstep(0.50, 0.95, im_fbm(p * 13.0 + sd + 2.0)) * (0.30 + 0.70 * (1.0 - clamp(p.y / 1.6, 0.0, 1.0)));
	dirt += (1.0 - smoothstep(0.0, 0.005, ed)) * 0.3;
	dirt = clamp(dirt, 0.0, 1.0) * (id == 5 ? 0.0 : 1.0);
	if (painted) {
		col = mix(col, bare, wear * 0.7);
		met = mix(met, 1.0, wear);
		rou = mix(rou, 0.42, wear);
	} else {
		col = mix(col, col * vec3(0.72, 0.66, 0.5), wear * 0.6);
		rou = mix(rou, 0.5, wear * 0.7);
	}
	col *= 1.0 - 0.40 * dirt;
	col = mix(col, col * vec3(0.9, 0.82, 0.7), dirt * 0.4);
	rou = mix(rou, 0.5, dirt * 0.5);
	// Kratzer: helle Metallspuren im Lack
	float sc = im_scratch(p, sd) * (1.0 - lod) * (id == 5 ? 0.0 : 1.0);
	vec3 sccol = painted ? bare * 1.2 : col * 1.4 + vec3(0.04);
	col = mix(col, sccol, sc * 0.6);
	met = mix(met, 1.0, sc * 0.5);
	rou = mix(rou, 0.40, sc * 0.5);
	hgt -= sc * 0.0002;
}

// Wabengitter (Rücken): Zellen von 1 Einheit Breite. Gibt Abstand zum Zellrand (in Zellen) zurück.
float im_hex(vec2 uv, out vec2 cell) {
	const vec2 s = vec2(1.0, 1.7320508);
	vec4 hc = floor(vec4(uv, uv - vec2(0.5, 1.0)) / s.xyxy) + 0.5;
	vec4 h = vec4(uv - hc.xy * s, uv - (hc.zw + 0.5) * s);
	bool first = dot(h.xy, h.xy) < dot(h.zw, h.zw);
	vec2 q = first ? h.xy : h.zw;
	cell = first ? hc.xy : hc.zw + 0.5;
	q = abs(q);
	return 0.5 - max(dot(q, normalize(vec2(1.0, 1.7320508))), q.x);
}

// Gesichtsplatte: Gold mit Stirnkamm, Augenschlitzen, Mundplatte. p in Ruhepose, x = Mitte 0.
void im_face(vec3 p, float w, inout vec3 col, inout float met, inout float rou, inout vec3 emi, inout float hgt) {
	float ax = abs(p.x);
	float y = p.y;
	float front = smoothstep(0.03, 0.07, p.z);
	float line = 0.0;
	// roter Stirnkamm (oben Mitte)
	float dc = im_box(vec2(ax, y - 1.757), vec2(0.0155, 0.034)) - 0.0035;
	vec3 c2;
	float m2;
	float r2;
	vec3 e2;
	float h2;
	im_mat(8, 0, p, w, abs(dc), 5.0, c2, m2, r2, e2, h2);
	float crest = im_cov(dc, w) * front;
	col = mix(col, c2, crest);
	met = mix(met, m2, crest);
	rou = mix(rou, r2, crest);
	line = max(line, im_cov(abs(dc) - 0.0007, w) * front);
	// Augenschlitze: schräg, innen hoch, außen spitz
	vec2 ea = vec2(0.0115, 1.6655);
	vec2 eb = vec2(0.0610, 1.6805);
	vec2 eba = eb - ea;
	float eh = clamp(dot(vec2(ax, y) - ea, eba) / dot(eba, eba), 0.0, 1.0);
	float de = length(vec2(ax, y) - (ea + eba * eh)) - mix(0.0046, 0.0012, pow(eh, 0.8));
	float eye = im_cov(de, w) * front;
	vec3 ecol = mix(vec3(0.55, 0.80, 1.0), vec3(1.0), smoothstep(0.0, -0.0028, de));
	col = mix(col, ecol, eye);
	emi += ecol * eye * 4.5;
	met = mix(met, 0.0, eye);
	line = max(line, im_cov(abs(de - 0.0017) - 0.0007, w) * front * (1.0 - eye));
	// Schein der Augen auf dem Gold
	emi += vec3(0.35, 0.6, 0.9) * 0.10 * im_gs(max(de, 0.0), 0.010) * front * (1.0 - eye);
	// Mund: Spalt, Kinnplatte, Wangenlinien
	line = max(line, im_cov(abs(y - 1.5925) - 0.0010, w) * (1.0 - smoothstep(0.034, 0.040, ax)) * front);
	line = max(line, im_cov(im_seg(vec2(ax, y), vec2(0.0375, 1.5935), vec2(0.0525, 1.6280)) - 0.0010, w) * front);
	line = max(line, im_cov(im_seg(vec2(ax, y), vec2(0.0120, 1.5925), vec2(0.0150, 1.5640)) - 0.0008, w) * front);
	line = max(line, im_cov(abs(y - (1.5655 + ax * 0.12)) - 0.0008, w) * (1.0 - smoothstep(0.012, 0.030, ax)) * front);
	// Wangenplatte unter dem Auge
	line = max(line, im_cov(im_seg(vec2(ax, y), vec2(0.0575, 1.6555), vec2(0.0420, 1.6180)) - 0.0008, w) * front);
	// Brauenlinie über den Augen
	line = max(line, im_cov(abs(y - (1.6925 + ax * 0.20 - 0.0020)) - 0.0008, w) * (1.0 - smoothstep(0.050, 0.060, ax)) * front * (1.0 - crest));
	col = mix(col, col * 0.18, line * 0.9);
	hgt -= line * 0.0012;
	rou = mix(rou, 0.36, 0.0);
}

// Helmschale: roter Lack; Ohrscheiben und Rillen
void im_helm(vec3 p, float w, inout vec3 col, inout float met, inout float rou, inout vec3 emi, inout float hgt) {
	float ax = abs(p.x);
	float line = 0.0;
	// Ohrscheibe (seitlich): Ring und leicht anderer Ton
	vec2 q = vec2(p.z - 0.0, p.y - 1.665);
	float de = length(q * vec2(1.0, 1.15)) - 0.030;
	float side = smoothstep(0.065, 0.085, ax);
	line = max(line, im_cov(abs(de) - 0.0010, w) * side);
	col = mix(col, col * 1.15, im_cov(de, w) * side * 0.4);
	// Rille zwischen Schale und Kinn-/Nackenteil
	line = max(line, im_cov(abs(p.y - 1.585 - ax * 0.35) - 0.0010, w) * side * (1.0 - smoothstep(0.0, 0.03, p.z - 0.02)) * 0.0);
	col = mix(col, col * 0.2, line * 0.9);
	hgt -= line * 0.0012;
}

// Körper des Anzugs (Stellen, die keine Panzerplatte bedeckt): Bauch, Hüfte, Hände, Hals.
void iron_body(vec3 p, float w, out vec3 col, out float met, out float rou, out vec3 emi, out float hgt) {
	float ax = abs(p.x);
	bool arm = ax > 0.2 && p.y > 1.28;
	int id = 0;
	float ed = 1.0;
	float sd = 4.0;
	float front = smoothstep(0.0, 0.04, p.z);
	if (!arm && p.y > 0.97 && p.y < 1.26) {
		// Bauchplatten: waagrechte Bänder
		float per = 0.045;
		float k = (p.y - 0.97) / per;
		ed = abs(fract(k + 0.5) - 0.5) * per;
		sd = 7.0 + floor(k) * 3.1;
		// goldene Rippenstücke an den Seiten (schräg)
		float dd = 1.0;
		for (int i = 0; i < 3; i++) {
			float yy = 1.115 + float(i) * 0.040;
			dd = min(dd, im_seg(vec2(ax, p.y), vec2(0.085, yy + 0.014), vec2(0.135, yy - 0.006)) - 0.0075);
		}
		float gdash = im_cov(dd, w) * front;
		id = gdash > 0.5 ? 1 : 0;
		ed = min(ed, mix(1.0, abs(dd), front));
	}
	if (arm && ax > 0.74) {
		sd = 11.0;
	}
	if (p.y > 1.49 && ax < 0.13) {
		id = 3; // Hals
	}
	int trim = 0;
	im_mat(id, trim, p, w, ed, sd, col, met, rou, emi, hgt);
	if (arm && ax > 0.74) {
		col *= 0.8;
		// Handfläche (unten): Repulsor mit Ring und leuchtender Mitte
		float r = length(vec2(ax - 0.80, p.z + 0.06));
		float under = 1.0 - smoothstep(1.405, 1.418, p.y);
		float ring = im_cov(abs(r - 0.0295) - 0.0045, w) * under;
		float core = im_cov(r - 0.0235, w) * under;
		col = mix(col, im_lin(vec3(0.62, 0.64, 0.7)), ring);
		met = mix(met, 1.0, ring);
		rou = mix(rou, 0.25, ring);
		col = mix(col, vec3(0.75, 0.93, 1.0), core);
		emi = vec3(0.55, 0.88, 1.0) * core * 4.0;
		met = mix(met, 0.0, core);
	}
}
