// Gesicht von Captain America (realistischer als human_face in hero_face.gdshaderinc, das Thor weiter nutzt):
// Hautschattierung mit Poren und Bartschatten, Augen mit schweren Lidern, kleiner Iris und Glanzpunkt,
// kräftige dunkle Brauen, schmalere Lippen. Wird von captain_suit.gdshaderinc eingebunden (braucht lin, cov, seg
// von dort und vn, gs, brow_cov aus hero_face.gdshaderinc). Maße: Ruhepose-Koordinaten (Meter).

// Auge. e = Lage zum Augenmittelpunkt (x nach aussen, y nach oben, Meter).
void cf_eye(vec2 e, float w, vec3 iris, float tilt, inout vec3 col, inout float rou, inout vec3 emi) {
	e.y -= e.x * tilt;
	float u = clamp(e.x / 0.0152, -1.0, 1.0);
	float s = max(1.0 - u * u, 0.0);
	float top = 0.0047 * pow(s, 0.72) - 0.0004 * smoothstep(0.0, 1.0, abs(u));
	float bot = -0.0044 * pow(s, 0.85);
	// Augenhöhle: weicher Schatten, Lidfalte (schwer), Tränensack darunter
	float sock = gs(e.x - 0.001, 0.0215) * gs(e.y - 0.003, 0.0120);
	col *= 1.0 - 0.26 * sock;
	float crease_y = 0.0082 * pow(s, 0.55) + 0.0015;
	float crease = cov(abs(e.y - crease_y) - 0.00055, w) * (1.0 - smoothstep(0.75, 1.0, abs(u)));
	col = mix(col, col * 0.62, crease * 0.70);
	col *= 1.0 - 0.16 * gs(e.y - 0.0052, 0.0030) * (1.0 - smoothstep(0.85, 1.0, abs(u))); // Oberlid (Haut) dunkler
	col *= 1.0 - 0.10 * gs(e.y + 0.0078, 0.0026) * (1.0 - smoothstep(0.7, 1.0, abs(u)));  // Tränensack
	float opn = cov(e.y - top, w) * cov(bot - e.y, w) * (1.0 - smoothstep(0.0144, 0.0152, abs(e.x)));
	// Augapfel: gedämpftes Weiss, oben vom Lid beschattet, Winkel gerötet
	vec3 white = lin(vec3(0.84, 0.80, 0.77));
	white *= 1.0 - 0.60 * smoothstep(top - 0.0050, top, e.y);
	white *= 1.0 - 0.42 * u * u;
	white = mix(white, lin(vec3(0.78, 0.46, 0.42)), 1.0 - smoothstep(-0.0145, -0.0100, e.x));
	float ir = length(e);
	float ang = atan(e.y, e.x);
	vec3 ic = iris * (0.55 + 0.95 * (1.0 - smoothstep(0.0016, 0.0046, ir)));
	ic *= 0.78 + 0.44 * vn(vec2(ang * 6.0, ir * 520.0));
	ic *= mix(0.22, 1.0, 1.0 - smoothstep(0.0038, 0.0050, ir)); // dunkler Randring
	vec3 eb = mix(white, ic, cov(ir - 0.0050, w));
	eb = mix(eb, vec3(0.008), cov(ir - 0.0021, w));
	// Lid wirft Schatten auf die Iris
	eb *= 1.0 - 0.55 * smoothstep(top - 0.0030, top, e.y) * cov(ir - 0.0052, w);
	float hl = cov(length(e - vec2(-0.0016, 0.0017)) - 0.0007, w);
	eb = mix(eb, vec3(1.6), hl);
	col = mix(col, eb, opn);
	rou = mix(rou, 0.12, opn);
	emi += vec3(hl * opn * 0.25);
	// Wimpernkante oben (kräftig, zum äusseren Winkel dicker), unten feiner
	float lash = cov(abs(e.y - top) - (0.0009 + 0.0009 * s + 0.0007 * smoothstep(0.0, 0.015, e.x)), w) * (1.0 - smoothstep(0.0150, 0.0172, abs(e.x)));
	col = mix(col, lin(vec3(0.045, 0.030, 0.025)), lash * 0.95);
	float low = cov(abs(e.y - bot) - 0.00035, w) * (1.0 - smoothstep(0.0125, 0.0148, abs(e.x)));
	col = mix(col, col * 0.58, low * 0.65);
	// Wimpern als feine Striche über dem Lidrand
	float lf = (1.0 - smoothstep(0.0, 0.0016, abs(fract(e.x * 520.0) - 0.5) - 0.28)) * cov(abs(e.y - top - 0.0010) - 0.0010, w);
	col = mix(col, lin(vec3(0.05, 0.035, 0.03)), lf * 0.35 * (1.0 - smoothstep(0.011, 0.016, abs(e.x))) * (1.0 - smoothstep(0.003, 0.008, w)));
}

// Menschliches Gesicht (Captain). hm = Gesichtsmaske (0 hinten, 1 vorn).
void cap_face(vec3 p, float w, vec3 skin, vec3 iris, vec3 browc, vec3 lipc, float hm, inout vec3 col, inout float rou, inout vec3 emi) {
	float ax = abs(p.x);
	float y = p.y;
	float fade = 1.0 - smoothstep(0.0010, 0.0035, w);   // 1 = nah: Poren und Barthaare zeigen
	vec3 sk = skin * (0.98 + 0.035 * vn(p.xy * 38.0)) * (0.99 + 0.02 * vn(p.xy * 240.0 + 4.0));
	// Poren: feine dunkle Punkte, etwas mehr an Nase und Wangen
	float pore = smoothstep(0.68, 0.9, vn(p.xy * 1150.0 + 9.0)) * fade;
	sk *= 1.0 - 0.07 * pore * (0.5 + 0.5 * gs(ax - 0.02, 0.03));
	// Wangen leicht gerötet, Augenpartie dunkler (Schatten), Nasenspitze und Ohren wärmer
	sk = mix(sk, lin(vec3(0.90, 0.50, 0.45)), 0.13 * gs(ax - 0.046, 0.016) * gs(y - 1.618, 0.016));
	sk = mix(sk, lin(vec3(0.58, 0.42, 0.50)), 0.12 * gs(ax - 0.031, 0.019) * gs(y - 1.659, 0.012));
	sk = mix(sk, lin(vec3(0.92, 0.52, 0.47)), 0.07 * gs(ax, 0.008) * gs(y - 1.629, 0.007));
	// Wangenknochen etwas heller, darunter weicher Schatten; Kiefermuskel
	sk *= 1.0 + 0.05 * gs(ax - 0.052, 0.012) * gs(y - 1.640, 0.008);
	sk *= 1.0 - 0.10 * gs(ax - 0.056, 0.014) * gs(y - 1.606, 0.011);
	sk *= 1.0 - 0.10 * gs(ax - 0.066, 0.010) * gs(y - 1.575, 0.012);
	// Nasolabialfalte, Nasenflügel, Nasenlöcher, Schatten unter der Nase
	float fold = cov(seg(vec2(ax, y), vec2(0.0165, 1.6275), vec2(0.0285, 1.6020)) - 0.0009, w);
	sk = mix(sk, sk * 0.76, fold * 0.50);
	float alar = cov(seg(vec2(ax, y), vec2(0.0100, 1.6245), vec2(0.0165, 1.6275)) - 0.0010, w);
	sk = mix(sk, sk * 0.52, alar * 0.55);
	float nost = cov(length(vec2(ax - 0.0088, (y - 1.6208) * 2.2)) - 0.0026, w);
	sk = mix(sk, lin(vec3(0.17, 0.08, 0.06)), nost * 0.75);
	sk *= 1.0 - 0.18 * gs(ax, 0.011) * gs(y - 1.6130, 0.0042);
	// Nasenseiten im Schatten, Nasenrücken heller
	sk *= 1.0 - 0.10 * gs(ax - 0.014, 0.005) * smoothstep(1.625, 1.655, y) * (1.0 - smoothstep(1.67, 1.69, y));
	// Bartschatten: Oberlippe, Kinn, Kiefer, Wangen unten (bläulich-grau, körnig)
	float st_zone = (smoothstep(1.628, 1.606, y) * (1.0 - smoothstep(0.045, 0.085, ax)) * smoothstep(0.0, 0.012, ax + 0.012)
		+ smoothstep(1.606, 1.588, y) * (1.0 - smoothstep(0.06, 0.1, ax))) * 0.62;
	st_zone *= 1.0 - 0.8 * smoothstep(0.016, 0.006, abs(y - 1.5963) + ax * 0.15) * smoothstep(0.0, 0.025, 0.026 - ax); // um den Mund heller
	float st_n = vn(p.xy * vec2(980.0, 1300.0)) * 0.6 + vn(p.xy * 330.0) * 0.4;
	float stub = clamp(st_zone * (0.45 + 0.8 * st_n), 0.0, 1.0);
	sk = mix(sk, lin(vec3(0.34, 0.30, 0.32)), stub * 0.26 * (0.55 + 0.45 * fade));
	col = mix(col, sk, hm);
	rou = mix(rou, 0.58, hm);
	// Lippen: schmaler, dem Hautton näher
	float lx = ax / 0.0225;
	float lm = max(1.0 - lx * lx, 0.0);
	float upper = 0.0082 * pow(lm, 0.75) - 0.0012 * (1.0 - smoothstep(0.0, 0.009, ax));
	float lower = 0.0086 * pow(lm, 0.7);
	float yl = y - 1.5963;
	float lipd = yl > 0.0 ? yl - upper : -yl - lower;
	float lips = cov(lipd, w * 1.4) * (1.0 - smoothstep(0.021, 0.024, ax));
	vec3 lcol = lipc * (yl > 0.0 ? 0.80 : 1.02);
	lcol *= 1.0 - 0.30 * smoothstep(0.012, 0.0225, ax);
	lcol *= 0.92 + 0.12 * vn(vec2(p.x * 900.0, p.y * 260.0));   // feine Rillen
	col = mix(col, lcol, lips * hm * 0.80);
	rou = mix(rou, 0.42, lips * hm);
	float mline = cov(abs(yl) - 0.00055 * (1.0 + 2.0 * gs(ax, 0.006)), w) * (1.0 - smoothstep(0.0205, 0.0235, ax));
	col = mix(col, lin(vec3(0.15, 0.06, 0.06)), mline * hm * 0.85);
	col *= 1.0 - 0.16 * gs(y - 1.5810, 0.0030) * gs(ax, 0.013) * hm;   // Schatten unter der Unterlippe
	col *= 1.0 - 0.10 * gs(y - 1.6045, 0.0030) * gs(ax, 0.014) * hm;   // Schatten unter der Oberlippe-Kante (Philtrum)
	// Augen und Brauen
	vec2 ec = vec2(ax - 0.0315, y - 1.6635);
	if (abs(ec.x) < 0.030 && abs(ec.y) < 0.020) {
		vec3 c2 = col;
		float r2 = rou;
		vec3 e2 = emi;
		cf_eye(ec, w, iris, 0.10, c2, r2, e2);
		col = mix(col, c2, hm);
		rou = mix(rou, r2, hm);
		emi = mix(emi, e2, hm);
	}
	float bh;
	float br = brow_cov(vec2(ax, y), vec2(0.0125, 1.6870), vec2(0.0565, 1.6870), 0.0048, 0.0022, 0.0052, w, bh);
	col = mix(col, browc * (0.50 + 0.65 * bh), br * 0.96 * hm);
	rou = mix(rou, 0.55, br * hm);
}
