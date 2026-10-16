// Gesichter der Helden (wird von hero_suit.gdshader eingebunden; braucht lin, cov, seg, ln, box2 von dort).
// Alle Maße sind Ruhepose-Koordinaten (Meter, +Z vorn, +X links); das Relief dazu steht in hero_face.gd.

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float gs(float x, float s) {
	return exp(-x * x / (2.0 * s * s));
}

// Breite der Haubenöffnung (Captain) und der Gesichtsplatte (Iron Man) je Höhe (wie in hero_face.gd)
const float OPEN_Y[9] = float[9](1.545, 1.551, 1.566, 1.600, 1.640, 1.680, 1.706, 1.719, 1.727);
const float OPEN_W[9] = float[9](0.0, 0.030, 0.048, 0.057, 0.059, 0.057, 0.049, 0.034, 0.0);
const float MASK_Y[10] = float[10](1.543, 1.548, 1.565, 1.585, 1.610, 1.640, 1.668, 1.695, 1.714, 1.722);
const float MASK_W[10] = float[10](0.0, 0.013, 0.026, 0.039, 0.047, 0.053, 0.052, 0.047, 0.036, 0.0);

float open_w(float y) {
	if (y <= OPEN_Y[0] || y >= OPEN_Y[8]) return 0.0;
	for (int i = 0; i < 8; i++) {
		if (y <= OPEN_Y[i + 1]) return mix(OPEN_W[i], OPEN_W[i + 1], (y - OPEN_Y[i]) / (OPEN_Y[i + 1] - OPEN_Y[i]));
	}
	return 0.0;
}

float mask_w(float y) {
	if (y <= MASK_Y[0] || y >= MASK_Y[9]) return 0.0;
	for (int i = 0; i < 9; i++) {
		if (y <= MASK_Y[i + 1]) return mix(MASK_W[i], MASK_W[i + 1], (y - MASK_Y[i]) / (MASK_Y[i + 1] - MASK_Y[i]));
	}
	return 0.0;
}

// Auge. e = Lage zum Augenmittelpunkt (x nach außen, y nach oben, Meter). Malt Hautschatten, Lidfalte, Augapfel,
// Iris, Pupille, Lichtreflex und Wimpernkante.
void eye_paint(vec2 e, float w, vec3 iris, float tilt, inout vec3 col, inout float rou, inout vec3 emi) {
	e.y -= e.x * tilt;
	float u = clamp(e.x / 0.0156, -1.0, 1.0);
	float s = max(1.0 - u * u, 0.0);
	float top = 0.0066 * pow(s, 0.7);
	float bot = -0.0042 * pow(s, 0.85);
	// weicher Schatten der Augenhöhle und Lidfalte
	float sock = gs(e.x - 0.001, 0.0225) * gs(e.y - 0.002, 0.0125);
	col *= 1.0 - 0.20 * sock;
	float crease_y = 0.0098 * pow(s, 0.55) + 0.0016;
	float crease = cov(abs(e.y - crease_y) - 0.0006, w) * (1.0 - smoothstep(0.8, 1.0, abs(u)));
	col = mix(col, col * 0.68, crease * 0.65);
	float opn = cov(e.y - top, w) * cov(bot - e.y, w) * (1.0 - smoothstep(0.0150, 0.0160, abs(e.x)));
	// Augapfel
	vec3 white = lin(vec3(0.93, 0.90, 0.87));
	white *= 1.0 - 0.45 * smoothstep(top - 0.0045, top, e.y);
	white *= 1.0 - 0.38 * u * u;
	white = mix(white, lin(vec3(0.86, 0.50, 0.46)), 1.0 - smoothstep(-0.0150, -0.0105, e.x));
	float ir = length(e);
	float ang = atan(e.y, e.x);
	vec3 ic = iris * (0.50 + 1.05 * (1.0 - smoothstep(0.0024, 0.0058, ir)));
	ic *= 0.82 + 0.36 * vn(vec2(ang * 5.0, ir * 420.0));
	ic *= mix(0.30, 1.0, 1.0 - smoothstep(0.0046, 0.0060, ir));
	vec3 eb = mix(white, ic, cov(ir - 0.0060, w));
	eb = mix(eb, vec3(0.01), cov(ir - 0.0026, w));
	// Lid wirft Schatten auf die Iris (oben dunkler)
	eb *= 1.0 - 0.35 * smoothstep(top - 0.0030, top, e.y) * cov(ir - 0.0062, w);
	float hl = cov(length(e - vec2(-0.0018, 0.0021)) - 0.0011, w);
	eb = mix(eb, vec3(2.0), hl);
	col = mix(col, eb, opn);
	rou = mix(rou, 0.10, opn);
	emi += vec3(hl * opn * 0.4);
	// Wimpernkante oben, feine Linie unten
	float lash = cov(abs(e.y - top) - (0.0010 + 0.0008 * s), w) * (1.0 - smoothstep(0.0158, 0.0178, abs(e.x)));
	col = mix(col, lin(vec3(0.05, 0.035, 0.03)), lash * 0.92);
	float low = cov(abs(e.y - bot) - 0.0004, w) * (1.0 - smoothstep(0.0130, 0.0150, abs(e.x)));
	col = mix(col, col * 0.62, low * 0.7);
}

// Braue von a nach b (b außen), Dicke t0 innen bis t1 außen, Bogen bw nach oben in der Mitte
float brow_cov(vec2 p, vec2 a, vec2 b, float t0, float t1, float bw, float w, out float hair) {
	vec2 ab = b - a;
	float k = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
	vec2 c = a + ab * k + vec2(0.0, bw * 4.0 * k * (1.0 - k));
	float th = mix(t0, t1, k * k);
	float d = length(p - c) - th * (1.0 - 0.15 * k);
	hair = vn(vec2(k * 90.0, (p.y - c.y) * 900.0)) * 0.5 + vn(vec2(k * 220.0 + 3.0, (p.y - c.y) * 1800.0)) * 0.5;
	return cov(d, w);
}

// Menschliches Gesicht (Captain, Thor) vorn am Kopf. hm = Gesichtsmaske (0 hinten, 1 vorn).
void human_face(vec3 p, float w, vec3 skin, vec3 iris, vec3 browc, vec3 lipc, float hm, inout vec3 col, inout float rou, inout vec3 emi) {
	float ax = abs(p.x);
	float y = p.y;
	vec3 sk = skin * (0.985 + 0.03 * vn(p.xy * 40.0)) * (0.99 + 0.02 * vn(p.xy * 260.0 + 4.0));
	// Wangen rosig, Augenpartie etwas dunkler, Stirn heller, Nasenspitze gerötet
	sk = mix(sk, lin(vec3(0.93, 0.52, 0.46)), 0.16 * gs(ax - 0.046, 0.017) * gs(y - 1.619, 0.017));
	sk = mix(sk, lin(vec3(0.62, 0.42, 0.48)), 0.10 * gs(ax - 0.031, 0.020) * gs(y - 1.660, 0.013));
	sk *= 1.0 + 0.06 * smoothstep(1.69, 1.72, y);
	sk = mix(sk, lin(vec3(0.95, 0.55, 0.50)), 0.08 * gs(ax, 0.0085) * gs(y - 1.629, 0.0075));
	// Nasolabialfalte, Nasenflügel, Nasenlöcher, Schatten unter der Nase
	float fold = cov(seg(vec2(ax, y), vec2(0.0165, 1.6275), vec2(0.0285, 1.6020)) - 0.0010, w);
	sk = mix(sk, sk * 0.78, fold * 0.55);
	float alar = cov(seg(vec2(ax, y), vec2(0.0100, 1.6245), vec2(0.0165, 1.6275)) - 0.0010, w);
	sk = mix(sk, sk * 0.55, alar * 0.55);
	float nost = cov(length(vec2(ax - 0.0088, (y - 1.6208) * 2.2)) - 0.0028, w);
	sk = mix(sk, lin(vec3(0.20, 0.09, 0.07)), nost * 0.7);
	sk *= 1.0 - 0.14 * gs(ax, 0.011) * gs(y - 1.6130, 0.0042);
	col = mix(col, sk, hm);
	rou = mix(rou, 0.62, hm);
	// Lippen
	float lx = ax / 0.0235;
	float lm = max(1.0 - lx * lx, 0.0);
	float upper = 0.0100 * pow(lm, 0.75) - 0.0012 * (1.0 - smoothstep(0.0, 0.009, ax));
	float lower = 0.0092 * pow(lm, 0.7);
	float yl = y - 1.5963;
	float lipd = yl > 0.0 ? yl - upper : -yl - lower;
	float lips = cov(lipd, w * 1.3) * (1.0 - smoothstep(0.022, 0.025, ax));
	vec3 lcol = lipc * (yl > 0.0 ? 0.80 : 1.0);
	lcol *= 1.0 - 0.30 * smoothstep(0.014, 0.0235, ax);
	col = mix(col, lcol, lips * hm * 0.92);
	rou = mix(rou, 0.38, lips * hm);
	float mline = cov(abs(yl) - 0.0006 * (1.0 + 2.0 * gs(ax, 0.006)), w) * (1.0 - smoothstep(0.0215, 0.0245, ax));
	col = mix(col, lin(vec3(0.16, 0.06, 0.06)), mline * hm * 0.88);
	col *= 1.0 - 0.18 * gs(y - 1.5805, 0.0030) * gs(ax, 0.013) * hm;
	// Augen und Brauen
	vec2 ec = vec2(ax - 0.0315, y - 1.6635);
	if (abs(ec.x) < 0.030 && abs(ec.y) < 0.020) {
		vec3 c2 = col;
		float r2 = rou;
		vec3 e2 = emi;
		eye_paint(ec, w, iris, 0.10, c2, r2, e2);
		col = mix(col, c2, hm);
		rou = mix(rou, r2, hm);
		emi = mix(emi, e2, hm);
	}
	float bh;
	float br = brow_cov(vec2(ax, y), vec2(0.0125, 1.6875), vec2(0.0560, 1.6885), 0.0042, 0.0020, 0.0060, w, bh);
	col = mix(col, browc * (0.55 + 0.7 * bh), br * 0.94 * hm);
	rou = mix(rou, 0.55, br * hm);
}
