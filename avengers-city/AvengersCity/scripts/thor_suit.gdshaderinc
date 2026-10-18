// Thor: Anzug (wird von hero_suit.gdshader eingebunden; braucht lin, cov, box2, seg, ln, vn, gs, human_face von dort).
// Maße: Ruhepose (T-Pose, Meter, Füsse bei y=0, +Z vorn, +X links). Plastische Teile (Scheiben, Platten, Schienen,
// Gürtel, Umhang) stehen in thor_suit.gd; hier wird der Stoff darunter gemalt: Kettenhemd, Leder, Brustplatte, Stiefel.

// Rautenmuster (Kettenhemd/Schuppen): q in Zellen, bev = 1 in der Mitte einer Raute, 0 an der Kante
float t_diamond(vec2 q, out float bev, out float cell) {
	vec2 d = vec2(q.x + q.y, q.x - q.y) * 0.5;
	vec2 f = fract(d);
	float e = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	bev = smoothstep(0.0, 0.30, e);
	cell = h21(floor(d));
	return e;
}

// Kettenhemd malen: q = Rautenkoordinaten, fade = 1 wenn die Pixel zu klein sind (dann nur Mittelfarbe)
void t_mail(vec2 q, float w, float cellsz, vec3 dark, vec3 lite, inout vec3 col, inout float met, inout float rou, inout float hgt) {
	float bev;
	float cell;
	t_diamond(q, bev, cell);
	float fade = 1.0 - smoothstep(cellsz * 0.12, cellsz * 0.30, w);
	float b = mix(0.35, bev, fade);
	vec3 c = mix(dark * 0.55, lite, b * b * (0.55 + 0.45 * cell));
	c *= 0.8 + 0.4 * cell;
	col = c;
	met = 0.82;
	rou = mix(0.50, 0.30, b);
	hgt = bev * 0.0042 * fade;
}

void thor(vec3 p, float w, out vec3 col, out float met, out float rou, out vec3 emi, out float hgt) {
	float ax = abs(p.x);
	vec3 dk = lin(vec3(0.24, 0.25, 0.28));
	vec3 plate = lin(vec3(0.38, 0.39, 0.42));
	vec3 silver = lin(vec3(0.72, 0.74, 0.78));
	vec3 leather = lin(vec3(0.17, 0.165, 0.18));
	vec3 brown = lin(vec3(0.20, 0.11, 0.06));
	vec3 red = lin(vec3(0.50, 0.035, 0.045));
	vec3 skin = lin(vec3(0.88, 0.66, 0.52));
	vec3 blond = lin(vec3(0.75, 0.58, 0.34));
	vec3 mdark = lin(vec3(0.18, 0.19, 0.23));
	vec3 mlite = lin(vec3(0.70, 0.74, 0.82));
	col = dk;
	met = 0.3;
	rou = 0.55;
	emi = vec3(0.0);
	hgt = 0.0;
	float front = smoothstep(0.0, 0.04, p.z);
	bool arm = ax > 0.2 && p.y > 1.28;

	// Hose und Oberschenkel: schwarzes Leder mit blauem Glanz
	if (p.y < 1.04 && !arm) {
		float lg = vn(vec2(p.y * 90.0, p.x * 70.0 + p.z * 50.0));
		col = leather * (0.8 + 0.5 * lg) * 1.0;
		col = mix(col, lin(vec3(0.20, 0.24, 0.34)), 0.35 * smoothstep(0.5, 0.9, lg));
		met = 0.12;
		rou = 0.42 + 0.25 * lg;
		hgt = (lg - 0.5) * 0.0008;
		// Falten an den Knien und Nähte
		float seam = ln(ax, 0.093, 0.0012, w) * smoothstep(0.62, 0.7, p.y);
		float lx = ax - 0.093;
		// Kettenhemd-Streifen aussen an Oberschenkel und Hüfte
		if (p.y > 0.58 && p.y < 1.03 && lx > 0.028) {
			float a = atan(p.z + 0.004, lx);
			vec2 q = vec2(p.y / 0.021, a * 24.0 / 6.2831853);
			float strip = smoothstep(0.028, 0.04, lx) * (1.0 - smoothstep(0.58, 0.60, p.y));
			strip *= smoothstep(0.58, 0.62, p.y) * (1.0 - smoothstep(1.015, 1.03, p.y));
			vec3 c2 = col;
			float m2 = met;
			float r2 = rou;
			float h2 = hgt;
			t_mail(q, w, 0.021, mdark, mlite, c2, m2, r2, h2);
			col = mix(col, c2, strip);
			met = mix(met, m2, strip);
			rou = mix(rou, r2, strip);
			hgt = mix(hgt, h2, strip);
		}
		col = mix(col, lin(vec3(0.22, 0.22, 0.26)), seam * 0.35);
	}
	// Stiefel: hoher Schaft aus dunkelblauem Leder, Sohle schwarz
	if (p.y < 0.52) {
		float b = 1.0 - smoothstep(0.495, 0.51, p.y);
		float lg = vn(vec2(p.y * 70.0, p.x * 60.0 + p.z * 45.0)) * 0.6 + vn(p.xz * 110.0 + p.y * 40.0) * 0.4;
		vec3 bc = lin(vec3(0.17, 0.185, 0.23)) * (0.7 + 0.6 * lg);
		// Knitterfalten über dem Spann und am Knöchel
		float cr = smoothstep(0.55, 0.9, sin(p.y * 150.0 + vn(p.xz * 25.0) * 6.0));
		bc *= 1.0 - 0.28 * cr * smoothstep(0.1, 0.18, p.y) * (1.0 - smoothstep(0.26, 0.36, p.y));
		col = mix(col, bc, b);
		met = mix(met, 0.06, b);
		rou = mix(rou, 0.40 + 0.3 * lg, b);
		hgt = mix(hgt, (lg - 0.5) * 0.0007 - cr * 0.0007, b);
		// Sohle und Rand
		col = mix(col, lin(vec3(0.020, 0.018, 0.020)), (1.0 - smoothstep(0.022, 0.040, p.y)));
		float weltl = ln(p.y, 0.046, 0.003, w);
		col = mix(col, lin(vec3(0.12, 0.11, 0.12)), weltl * 0.8);
		hgt = max(hgt, weltl * 0.0015);
		rou = mix(rou, 0.7, 1.0 - smoothstep(0.022, 0.040, p.y));
	}
	// Rumpf: dunkle Rüstung mit silberner Brustplatte
	if (!arm && p.y > 1.04 && p.y < 1.545) {
		col = dk * (0.85 + 0.3 * vn(p.xy * 160.0));
		col *= 1.0;
		met = 0.35;
		rou = 0.42;
		float f = front * smoothstep(1.08, 1.1, p.y);
		// Platten: breite flache Teile in dunklem Grau, dazwischen Fugen
		float seg_a = ln(p.y, 1.165, 0.0016, w);
		float seg_b = ln(p.y, 1.125, 0.0016, w);
		float seg_c = ln(p.y, 1.095, 0.0016, w);
		float segs = max(max(seg_a, seg_b), seg_c) * f * cov(ax - 0.13, w);
		col = mix(col, plate * 0.5, segs);
		hgt = max(hgt, -segs * 0.0012);
		// Brustplatte: silberner Schmetterling (zwei Flügel schräg zur Mitte, Mittelsäule mit Schlitz)
		float s1 = seg(vec2(ax, p.y), vec2(0.105, 1.405), vec2(0.016, 1.322)) - 0.016;
		float s2 = seg(vec2(ax, p.y), vec2(0.016, 1.322), vec2(0.082, 1.232)) - 0.011;
		float s3 = box2(vec2(ax, p.y - 1.248), vec2(0.021, 0.082));
		float s4 = length(vec2(ax * 0.85, p.y - 1.318)) - 0.034;
		float sd = min(min(s1, s2), min(s3, s4));
		float sil = cov(sd, w) * f;
		float slot = cov(box2(vec2(ax, p.y - 1.255), vec2(0.0035, 0.032)), w);
		vec3 sc = silver * (0.78 + 0.30 * vn(vec2(p.x * 300.0 + p.y * 40.0, p.y * 30.0)));
		sc *= 1.0 - 0.45 * smoothstep(0.0, -0.012, sd) * 0.0;
		col = mix(col, sc, sil);
		col = mix(col, dk * 0.35, slot * sil);
		met = mix(met, 0.88, sil);
		rou = mix(rou, 0.36, sil);
		hgt = max(hgt, sil * (0.0045 * clamp(-sd / 0.008, 0.0, 1.0)) - slot * 0.002);
		// dunkle Tropfenplatten unten (mit den grossen Scheiben)
		vec2 tq = vec2((ax - 0.094) / 0.050, (p.y - 1.125) / 0.070);
		float td = (length(tq) - 1.0) * 0.05;
		float tdp = cov(td, w) * f;
		col = mix(col, plate * 0.75, tdp);
		float trim = cov(abs(td + 0.003) - 0.0018, w) * f;
		col = mix(col, silver * 0.7, trim * 0.8);
		met = mix(met, 0.7, tdp);
		hgt = max(hgt, tdp * 0.0025);
		// mittlere Bauchplatte, kleines silbernes Stück
		float lb = cov(box2(vec2(ax, p.y - 1.086), vec2(0.048, 0.011)), w) * f;
		col = mix(col, silver, lb);
		met = mix(met, 0.85, lb);
		hgt = max(hgt, lb * 0.003);
		// Seiten: Schuppen unter den Armen
		float sideb = smoothstep(0.115, 0.135, ax) * (1.0 - smoothstep(1.36, 1.40, p.y)) * smoothstep(1.06, 1.10, p.y);
		if (sideb > 0.01) {
			vec2 q = vec2(p.y / 0.020, p.x / 0.020);
			vec3 c2 = col;
			float m2 = met;
			float r2 = rou;
			float h2 = hgt;
			t_mail(q, w, 0.021, mdark, mlite, c2, m2, r2, h2);
			col = mix(col, c2, sideb);
			met = mix(met, m2, sideb);
			rou = mix(rou, r2, sideb);
			hgt = mix(hgt, h2, sideb);
		}
		// oben am Hals: roter Stoff mit V-Ausschnitt, darin Haut
		float vtop = 1.455 + ax * 1.2;
		float inn = smoothstep(1.418, 1.428, p.y) * front;
		float cloth = vn(vec2(p.x * 380.0, p.y * 380.0));
		float redm = inn * (1.0 - smoothstep(vtop - 0.004, vtop + 0.004, p.y));
		float skm = inn * smoothstep(vtop - 0.004, vtop + 0.004, p.y);
		col = mix(col, red * (0.75 + 0.45 * cloth), redm);
		col = mix(col, skin * 0.95, skm);
		met = mix(met, 0.0, max(redm, skm));
		rou = mix(rou, 0.85, redm);
		hgt = mix(hgt, (cloth - 0.5) * 0.0003, redm);
		// Gürtel (Leder), Schnalle (geometrisch)
		float belt = cov(abs(p.y - 1.043) - 0.032, w);
		col = mix(col, leather * 1.4, belt);
		met = mix(met, 0.0, belt);
		rou = mix(rou, 0.6, belt);
		// Rücken: Lederriemen über die Schultern mit Schnallen
		float back = 1.0 - front;
		float b1 = cov(seg(p.xy, vec2(0.11, 1.46), vec2(-0.05, 1.10)) - 0.013, w);
		float b2 = cov(seg(p.xy, vec2(-0.11, 1.46), vec2(0.05, 1.10)) - 0.013, w);
		float bst = max(b1, b2) * back * step(1.09, p.y);
		col = mix(col, brown * 0.9, bst);
		met = mix(met, 0.0, bst);
		rou = mix(rou, 0.6, bst);
		hgt = max(hgt, bst * 0.002);
		float bk = cov(length(p.xy - vec2(0.0, 1.27)) - 0.02, w) * back;
		col = mix(col, silver, bk);
		met = mix(met, 0.85, bk);
		// Rücken: dunkle Platte
		float rpl = cov(box2(vec2(ax, p.y - 1.27), vec2(0.06, 0.12)), w) * back * step(1.12, p.y);
		col = mix(col, plate * 0.5, rpl * 0.5 * (1.0 - bst));
	}
	// Arme: Kettenhemd von der Schulter bis zum Handgelenk, Armschienen (plastisch, thor_suit.gd), Hände
	if (arm) {
		float a = atan(p.z + 0.0617, p.y - 1.4357);
		vec2 q = vec2(ax / 0.0195, a * 20.0 / 6.2831853);
		t_mail(q, w, 0.0195, mdark, mlite, col, met, rou, hgt);
		// Wulst am Oberarm unter der Schulter: Leder-Streifen
		float st = ln(ax, 0.455, 0.008, w);
		col = mix(col, leather * 1.3, st * 0.8);
		met = mix(met, 0.0, st);
		hgt = max(hgt, st * 0.002);
		// unter den Armschienen dunkles Leder
		float fa = smoothstep(0.515, 0.525, ax);
		col = mix(col, leather * 1.2, fa);
		met = mix(met, 0.1, fa);
		rou = mix(rou, 0.55, fa);
		hgt = mix(hgt, 0.0, fa);
		// roter Ärmelrand am Handgelenk
		float cuff = smoothstep(0.715, 0.72, ax) * (1.0 - smoothstep(0.735, 0.74, ax));
		float cl = vn(vec2(ax * 600.0, a * 90.0));
		col = mix(col, red * (0.7 + 0.5 * cl), cuff);
		met = mix(met, 0.0, cuff);
		rou = mix(rou, 0.9, cuff);
		// Hand: nackte Haut
		float hand = smoothstep(0.738, 0.742, ax);
		float sv = vn(p.xz * 90.0 + p.y * 20.0);
		col = mix(col, skin * (0.93 + 0.1 * sv), hand);
		met = mix(met, 0.0, hand);
		rou = mix(rou, 0.62, hand);
		hgt = mix(hgt, 0.0, hand);
	}
	// Kopf: Haare, Gesicht, Vollbart (Relief: hero_face.gd; Haare und Bartsträhnen: thor_suit.gd)
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
	// Hals: Haut, unten der rote Halsausschnitt (V) des Untergewands
	if (p.y > 1.5 && p.y < 1.552 && ax < 0.12) {
		float cloth = vn(vec2(p.x * 380.0, p.y * 380.0));
		float vtop = 1.455 + ax * 1.2;
		float rm = (1.0 - smoothstep(vtop - 0.004, vtop + 0.004, p.y)) * smoothstep(0.0, 0.03, p.z + 0.04);
		col = skin;
		met = 0.0;
		rou = 0.65;
		hgt = 0.0;
		col = mix(col, red * (0.75 + 0.45 * cloth), rm);
		rou = mix(rou, 0.9, rm);
	}
}
