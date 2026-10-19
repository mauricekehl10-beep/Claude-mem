// Captain America (Avengers-Anzug): matter, gedeckter Stoff mit feinem Gewebe, Falten, Nähte, Steppung, Streifen, Stern,
// Gurte, Lederhandschuhe, Stiefel, Haube. Wird von captain_body.gdshader (und hero_suit.gdshader) eingebunden
// (braucht lin, cov, box2, seg, ln, star5 von dort und vn, gs, human_face aus hero_face.gdshaderinc).
// Alle Maße sind Ruhepose-Koordinaten (Meter, +Z vorn, +X links; T-Pose: Arme entlang x, Handflächen nach unten).

float cs_h3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float cs_vn3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(cs_h3(i), cs_h3(i + vec3(1.0, 0.0, 0.0)), f.x), mix(cs_h3(i + vec3(0.0, 1.0, 0.0)), cs_h3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(cs_h3(i + vec3(0.0, 0.0, 1.0)), cs_h3(i + vec3(1.0, 0.0, 1.0)), f.x), mix(cs_h3(i + vec3(0.0, 1.0, 1.0)), cs_h3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

// Stoff-Muster (feine Rauten, wie gestrickter Anzugstoff): -0.5..0.5, T = Zellgröße in Metern.
// tw = Gewichte der drei Ebenen (nach Flächenrichtung). Bei grobem Pixel (Entfernung) blendet es aus.
float cs_cloth(vec3 p, vec3 tw, float w, float T) {
	vec2 g1 = p.zy / T;
	vec2 g2 = p.xz / T;
	vec2 g3 = p.xy / T;
	float d1 = abs(fract(g1.x + g1.y) - 0.5) + abs(fract(g1.x - g1.y) - 0.5);
	float d2 = abs(fract(g2.x + g2.y) - 0.5) + abs(fract(g2.x - g2.y) - 0.5);
	float d3 = abs(fract(g3.x + g3.y) - 0.5) + abs(fract(g3.x - g3.y) - 0.5);
	float d = tw.x * d1 + tw.y * d2 + tw.z * d3;
	return (d - 0.5) * (1.0 - smoothstep(T * 0.35, T * 0.9, w));
}

// Gestrichelte Naht: Linie bei d == 0, Stiche entlang s
float cs_stitch(float d, float s, float w) {
	float line = cov(abs(d) - 0.00045, w);
	float dash = step(0.45, fract(s / 0.0065));
	return line * mix(1.0, dash, 1.0 - smoothstep(0.0012, 0.0035, w));
}

// Falten: geschlängelte Rippen (0..1, 1 = Kamm). c = Richtung quer zu den Falten (Meter), a = Richtung entlang,
// freq = Falten je Meter, wob = Schlängeln.
float cs_fold(float c, float a, float freq, float wob, float seed) {
	float n = vn(vec2(a * 38.0 + seed * 7.0, c * freq * 0.25 + seed)) - 0.5;
	float t = c * freq + n * wob + seed;
	return 0.5 + 0.5 * sin(t * 6.2831853);
}

// feine Körnung (Leder, Stoff): -0.5..0.5, blendet bei grobem Pixel aus
float cs_grain(vec3 p, float w, float sc) {
	return (cs_vn3(p * sc) - 0.5) * (1.0 - smoothstep(0.0012, 0.0045, w));
}

// Leder: Maserung (Narben) und Abrieb
vec3 cs_leather(vec3 base, vec3 p, float w) {
	float f = 1.0 - smoothstep(0.0012, 0.0045, w);
	float g = cs_vn3(p * 520.0);
	float g2 = cs_vn3(p * 130.0);
	float pits = smoothstep(0.55, 0.8, cs_vn3(p * 330.0)) * f;
	return base * (0.80 + 0.30 * mix(0.5, g, f) + 0.35 * (g2 - 0.5)) * (1.0 - 0.18 * pits);
}

// Unterkante der Haube (Abstand von der Mitte -> Höhe), gleiche Werte wie YE_X/YE_Y in captain_suit.gd
const float CS_YE_X[7] = float[7](0.0, 0.012, 0.030, 0.050, 0.068, 0.075, 0.095);
const float CS_YE_Y[7] = float[7](1.642, 1.642, 1.622, 1.613, 1.606, 1.600, 1.598);

float cs_ye(float ax) {
	if (ax <= CS_YE_X[0]) {
		return CS_YE_Y[0];
	}
	for (int i = 0; i < 6; i++) {
		if (ax <= CS_YE_X[i + 1]) {
			return mix(CS_YE_Y[i], CS_YE_Y[i + 1], (ax - CS_YE_X[i]) / (CS_YE_X[i + 1] - CS_YE_X[i]));
		}
	}
	return CS_YE_Y[6];
}

// Gesichtsöffnung der Haube: < 0 offen (Haut), > 0 Haube. Unterkante plus zwei Augenlöcher.
float cs_open(float ax, float y) {
	float d_low = y - cs_ye(ax);
	float d_eye = box2(vec2(ax - 0.0345, y - 1.6635), vec2(0.0105, 0.0085)) - 0.011;
	return min(d_low, d_eye);
}

#include "res://scripts/captain_face.gdshaderinc"

void cap2(vec3 p, float w, out vec3 col, out float met, out float rou, out vec3 emi, out float hgt, out float ao, out float rim) {
	float ax = abs(p.x);
	float y = p.y;
	// Flächenrichtung in der Ruhepose (für das Stoffmuster auf allen Seiten)
	vec3 rn = abs(cross(dFdx(p), dFdy(p)));
	rn = rn * rn;
	vec3 tw = rn / (rn.x + rn.y + rn.z + 1e-12);

	vec3 blue = lin(vec3(0.30, 0.385, 0.52));
	vec3 blue_hi = lin(vec3(0.39, 0.48, 0.63));
	vec3 navy = lin(vec3(0.17, 0.215, 0.33));
	vec3 pants = lin(vec3(0.265, 0.33, 0.45));
	vec3 red = lin(vec3(0.54, 0.055, 0.155));
	vec3 white = lin(vec3(0.72, 0.70, 0.69));
	vec3 gray = lin(vec3(0.60, 0.61, 0.63));
	vec3 gray_dk = lin(vec3(0.34, 0.35, 0.38));
	vec3 strap = lin(vec3(0.43, 0.43, 0.45));
	vec3 leather = lin(vec3(0.20, 0.12, 0.11));
	vec3 leather_hi = lin(vec3(0.33, 0.21, 0.18));
	vec3 glove = lin(vec3(0.15, 0.10, 0.095));
	vec3 silver = lin(vec3(0.60, 0.60, 0.58));
	vec3 gun = lin(vec3(0.22, 0.225, 0.24));
	vec3 skin = lin(vec3(0.88, 0.70, 0.62));
	vec3 dust = lin(vec3(0.33, 0.30, 0.27));
	vec3 soot = lin(vec3(0.09, 0.085, 0.085));

	float front = smoothstep(0.0, 0.04, p.z);
	float back = 1.0 - smoothstep(-0.04, 0.0, p.z);
	bool arm = ax > 0.2 && y > 1.28;

	float cl = cs_cloth(p, tw, w, 0.0055);
	float mott = cs_vn3(p * 22.0) * 0.6 + cs_vn3(p * 61.0) * 0.4;
	float grime = cs_vn3(p * 8.0 + 3.0);
	float grain = cs_grain(p, w, 640.0);
	float near_f = 1.0 - smoothstep(0.0015, 0.006, w); // 1 = ganz nah (Feinheiten zeigen)

	col = blue;
	met = 0.0;
	rou = 0.80;
	emi = vec3(0.0);
	ao = 1.0;
	rim = 0.30;
	float hh = 0.0;

	// ------------------------------------------------ Hose
	if (y < 1.06 && !arm) {
		col = pants;
		// Seitenpaneele etwas dunkler (Oberschenkel aussen), Seitennaht und Innennaht
		float sx = mix(0.128, 0.178, smoothstep(0.3, 0.8, y));
		float panel = smoothstep(sx - 0.004, sx + 0.004, ax) * smoothstep(0.34, 0.5, y);
		col = mix(col, pants * 0.80, panel * 0.6);
		float seam = cs_stitch(ax - sx, y, w) * smoothstep(0.34, 0.5, y);
		col = mix(col, navy, seam * 0.7);
		hh += ln(ax, sx, 0.0011, w) * smoothstep(0.34, 0.5, y) * 0.0012;
		float inner = cs_stitch(ax - 0.022, y, w) * smoothstep(0.5, 0.7, y) * (1.0 - smoothstep(0.85, 0.95, y));
		col = mix(col, navy, inner * 0.5);
		// Wade hinten: Mittelnaht
		float cs_calf = cs_stitch(ax - 0.094, y, w) * back * smoothstep(0.36, 0.42, y) * (1.0 - smoothstep(0.50, 0.54, y));
		col = mix(col, navy, cs_calf * 0.6);
		// Knie: Polster aus drei Wülsten vorn, Quernähte, Kniekehle hinten
		float kpad = front * smoothstep(0.075, 0.065, abs(ax - 0.094)) * smoothstep(0.455, 0.475, y) * (1.0 - smoothstep(0.585, 0.605, y));
		float kr = 0.5 + 0.5 * sin((y - 0.47) / 0.135 * 3.0 * 6.2831853 - 1.5708);
		col = mix(col, pants * 0.74, kpad * 0.45);
		col = mix(col, navy * 0.8, kpad * smoothstep(0.55, 0.0, kr) * 0.30);
		hh += kpad * (0.0030 + 0.0020 * kr);
		ao *= 1.0 - 0.18 * kpad * (1.0 - kr);
		float kn = max(ln(y, 0.585, 0.0013, w), ln(y, 0.47, 0.0013, w)) * front;
		col = mix(col, navy, kn * 0.6);
		hh -= kn * 0.0014;
		// Falten: Leiste/Hüfte (schräg), Knie (quer), Kniekehle, Wade
		float gr = cs_fold(y - 0.62 * ax, p.z + p.x * 0.6, 24.0, 0.9, 1.3);
		float gz = front * smoothstep(0.62, 0.82, y) * (1.0 - smoothstep(0.99, 1.05, y)) * smoothstep(0.025, 0.06, ax) * (1.0 - smoothstep(0.17, 0.21, ax));
		col *= 1.0 - 0.20 * gz * (1.0 - gr);
		hh += gz * (gr - 0.5) * 0.0028;
		ao *= 1.0 - 0.28 * gz * (1.0 - gr);
		float kf = cs_fold(y, p.x * 1.0 + p.z, 52.0, 1.2, 2.1);
		float kz = back * smoothstep(0.43, 0.48, y) * (1.0 - smoothstep(0.58, 0.64, y)) + front * smoothstep(0.62, 0.66, y) * (1.0 - smoothstep(0.72, 0.78, y)) * 0.0;
		col *= 1.0 - 0.24 * kz * (1.0 - kf);
		hh += kz * (kf - 0.5) * 0.0024;
		ao *= 1.0 - 0.35 * kz * (1.0 - kf);
		float wf = cs_fold(y, p.x + p.z * 0.5, 38.0, 1.0, 4.7);
		float wz = smoothstep(0.36, 0.40, y) * (1.0 - smoothstep(0.44, 0.47, y)) * back;
		col *= 1.0 - 0.18 * wz * (1.0 - wf);
		// Steppung am Oberschenkel innen (feine Linien)
		float qt = max(cs_stitch(abs(ax - 0.094) - 0.040, y, w), 0.0) * smoothstep(0.66, 0.70, y) * (1.0 - smoothstep(0.88, 0.92, y)) * (1.0 - front);
		col = mix(col, navy, qt * 0.35);
		// Gewebe und Körnung
		col *= 1.0 + 0.10 * cl + 0.10 * grain * near_f;
		hh += cl * 0.00016 * near_f;
		// Verwitterung: Staub am Saum, Abrieb an Knien, Rußflecken
		col = mix(col, dust, 0.34 * (1.0 - smoothstep(0.0, 0.5, y)) * (0.35 + 0.65 * grime));
		col = mix(col, pants * 1.35, 0.30 * kpad * smoothstep(0.55, 0.9, cs_vn3(p * 55.0)));
		col = mix(col, soot, 0.28 * smoothstep(0.62, 0.9, cs_vn3(p * 11.0 + 7.0)) * smoothstep(0.3, 0.9, y) * (1.0 - front * 0.5));
		// Schritt / Gesäss: Falten, dunkler zwischen den Beinen
		ao *= 1.0 - 0.45 * smoothstep(0.05, 0.0, ax) * smoothstep(0.55, 0.9, y);
	}

	// ------------------------------------------------ Rumpf
	if (!arm && y >= 1.06) {
		// Seiten dunkler, Brust leicht heller
		float side = smoothstep(0.105, 0.155, ax) * (1.0 - smoothstep(1.34, 1.42, y));
		col = mix(col, navy, side * 0.5);
		float pec = front * smoothstep(0.17, 0.07, ax) * smoothstep(1.30, 1.35, y) * (1.0 - smoothstep(1.44, 1.49, y));
		col = mix(col, blue_hi, pec * 0.5);
		// Kragen und Halsansatz dunkler
		col = mix(col, navy, smoothstep(1.47, 1.52, y) * 0.65);
		// feine Rippen im Kragen
		float rib = step(0.5, fract(y / 0.007));
		col *= 1.0 - 0.10 * rib * smoothstep(1.495, 1.52, y) * (1.0 - smoothstep(1.0, 0.0, w / 0.003));
		// Y-Ausschnitt unter dem Kragen (dunkel)
		float vn_ = cov(max(ax - (0.060 - (1.505 - y) * 0.9), y - 1.505), w) * front;
		col = mix(col, navy, vn_ * smoothstep(1.40, 1.47, y) * 0.8);

		// Brust: Dach-Band unter dem Stern und Flügel zu den Schultern
		float bt = 1.336 - 0.45 * ax;
		float bb = 1.292 - 0.13 * ax;
		float band = cov(max(y - bt, bb - y), w) * front * (1.0 - smoothstep(0.15, 0.17, ax));
		col = mix(col, navy, band * 0.9);
		hh += band * 0.0016;
		float wing = cov(seg(vec2(ax, y), vec2(0.062, 1.405), vec2(0.150, 1.455)) - 0.0075, w) * front;
		col = mix(col, navy, wing * 0.9);
		float wing2 = cov(abs(seg(vec2(ax, y), vec2(0.075, 1.385), vec2(0.150, 1.430)) - 0.0035) - 0.0020, w) * front * (1.0 - wing);
		col = mix(col, blue_hi * 1.15, wing2 * 0.7);
		hh += wing * 0.0016 + wing2 * 0.0008;
		// Steppnähte der Brustplatten (zwei Reihen) und Mittelfurche
		float chest_zone = front * (1.0 - smoothstep(0.15, 0.17, ax)) * smoothstep(1.33, 1.36, y) * (1.0 - smoothstep(1.47, 1.5, y));
		float q1 = cs_stitch(y - (1.455 - 0.30 * ax), p.x, w) * chest_zone;
		col = mix(col, navy * 0.8, q1 * 0.5);
		float mid_gr = gs(ax, 0.0042) * front * smoothstep(1.30, 1.34, y) * (1.0 - smoothstep(1.40, 1.44, y));
		ao *= 1.0 - 0.30 * mid_gr;
		col *= 1.0 - 0.18 * mid_gr;

		// Stern (grauweiss, mit Rahmen und Facetten)
		vec2 sq = p.xy - vec2(0.0, 1.388);
		float dsf = star5(sq, 0.064 + 0.011, 0.42);
		col = mix(col, navy, cov(dsf, w) * front);
		float ds = star5(sq, 0.064, 0.42);
		float cs_ = cov(ds, w) * front;
		float ang = atan(sq.x, sq.y);
		float a72 = mod(ang + 0.6283185, 1.2566371) - 0.6283185; // -36..36 Grad zur nächsten Spitze
		vec3 star_c = lin(vec3(0.80, 0.79, 0.77)) * (1.0 + 0.10 * sign(a72)) * (0.90 + 0.20 * mott);
		col = mix(col, star_c, cs_);
		met = mix(met, 0.3, cs_);
		rou = mix(rou, 0.5, cs_);
		hh += cs_ * 0.0030 * (1.0 - abs(a72) / 0.6283185) * smoothstep(0.0, 0.015, -ds + 0.002);
		hh += cs_ * 0.0012;

		// Bauch: Streifen (Mitte rot mit runder Unterkante, dann weiss, rot, weiss, rot)
		if (y > 1.09 && y < 1.30) {
			float t = clamp((1.29 - y) / 0.19, 0.0, 1.0);
			float xr = 0.109 - 0.028 * t;
			float hw = 0.0255 - 0.004 * t;
			float top = 1.292 - 0.13 * ax;
			float zone = cov(max(y - top, ax - (xr + hw + 0.037)), w * 1.0) * front;
			float red_o = cov(abs(ax - xr) - hw, w);
			float ctr = min(cov(box2(vec2(p.x, y - 1.222), vec2(0.021, 0.068)), w) + cov(length(vec2(p.x, y - 1.154)) - 0.021, w), 1.0);
			float outer_w = cov(abs(ax - (xr + hw + 0.012)) - 0.012, w) * (1.0 - smoothstep(1.205, 1.215, y));
			float edge_r = cov(abs(ax - (xr + hw + 0.031)) - 0.006, w) * (1.0 - smoothstep(1.185, 1.195, y));
			vec3 sc = white;
			sc = mix(sc, red, red_o);
			sc = mix(sc, red, ctr);
			// ausserhalb der roten Streifen: nur unten weisse und rote Randstreifen, oben Anzug
			float ow = max(outer_w, edge_r);
			float outside = 1.0 - cov(ax - (xr + hw), w);       // 1 ausserhalb der roten Streifen
			vec3 oc = mix(white, red, edge_r * (1.0 - outer_w));
			sc = mix(sc, oc, outside * step(0.5, ow));
			float painted = zone * (1.0 - outside * (1.0 - ow));
			// Bauchmuskel-Segmente: weisse Streifen in Wülste (Querfurchen) geteilt
			float seg_y = 0.5 + 0.5 * sin((y - 1.115) / 0.058 * 6.2831853);
			float segm = smoothstep(0.15, 0.55, seg_y);
			vec3 scc = sc * (0.92 + 0.14 * mott + 0.5 * cl * 0.2);
			scc *= mix(1.0, 0.80 + 0.28 * segm, 1.0 - max(red_o, ctr) * 0.6);
			col = mix(col, scc, painted);
			rou = mix(rou, 0.76, painted);
			// Polster-Relief: weisse Flächen leicht erhaben, Ränder fangen Licht
			float white_a = painted * (1.0 - max(red_o, ctr));
			hh += white_a * (0.0022 + 0.0016 * segm) + painted * 0.0010;
			ao *= 1.0 - 0.22 * white_a * (1.0 - segm);
			// Kerbe zwischen den Flächen (dunkle feine Linie)
			float gap = max(cov(abs(abs(ax - xr) - hw) - 0.0007, w), cov(abs(length(vec2(p.x, y - 1.154)) - 0.021) - 0.0007, w) * step(y, 1.154)) * zone;
			col = mix(col, navy * 0.6, gap * 0.55);
			ao *= 1.0 - 0.25 * gap;
		}
		// Seitennähte (Steppung) unter der Brust und Rippen an der Flanke
		float flank = (1.0 - front * 0.0) * smoothstep(0.125, 0.135, ax) * smoothstep(1.10, 1.14, y) * (1.0 - smoothstep(1.30, 1.34, y));
		float fs1 = cs_stitch(ax - 0.168 + 0.20 * (y - 1.2), y, w) * flank;
		col = mix(col, navy * 0.7, fs1 * 0.5);
		float fr = cs_fold(y, p.z * 0.8, 17.0, 0.5, 0.4);
		col *= 1.0 - 0.14 * flank * (1.0 - fr);
		hh += flank * (fr - 0.5) * 0.0014;
		// Rücken: Mittelnaht, Schulterblatt-Nähte, Kreuzgurte
		float bk = back;
		float cseam = cs_stitch(p.x, y, w) * smoothstep(1.11, 1.15, y) * (1.0 - smoothstep(1.44, 1.47, y));
		col = mix(col, navy, cseam * 0.5 * bk);
		hh -= ln(p.x, 0.0, 0.0012, w) * bk * smoothstep(1.11, 1.15, y) * (1.0 - smoothstep(1.44, 1.47, y)) * 0.0014;
		float yoke = cs_stitch(y - 1.435 + 0.35 * ax * ax * 2.0, p.x, w) * (1.0 - smoothstep(0.15, 0.17, ax));
		col = mix(col, navy, yoke * 0.5 * bk);
		// Rücken: Schulterblatt-Platten (leicht dunkler abgesetzt), Lendenpartie
		float blade = bk * smoothstep(0.02, 0.05, ax) * (1.0 - smoothstep(0.14, 0.17, ax)) * smoothstep(1.30, 1.34, y) * (1.0 - smoothstep(1.43, 1.45, y));
		col = mix(col, blue * 0.82, blade * 0.40);
		float lum = bk * smoothstep(1.08, 1.12, y) * (1.0 - smoothstep(1.17, 1.21, y));
		col = mix(col, navy * 1.1, lum * 0.50);
		float lf = cs_fold(y, p.x, 36.0, 1.0, 5.2);
		col *= 1.0 - 0.14 * lum * (1.0 - lf);
		ao *= 1.0 - 0.30 * lum * (1.0 - lf);

		// Gurte (grau, Gurtband): vorn senkrecht über die Brust, hinten als X
		float fs = smoothstep(-0.075, -0.02, p.z);
		float bs = 1.0 - smoothstep(-0.075, -0.03, p.z);
		float f_sd = seg(vec2(ax, y), vec2(0.127, 1.515), vec2(0.168, 1.27)) - 0.0205;
		float s1 = seg(vec2(p.x, y), vec2(0.135, 1.515), vec2(-0.098, 1.105)) - 0.0215;
		float s2 = seg(vec2(p.x, y), vec2(-0.135, 1.515), vec2(0.098, 1.105)) - 0.0215;
		float f_cov = cov(f_sd, w) * fs;
		float b1 = cov(s1, w) * bs;
		float b2 = cov(s2, w) * bs;
		float sb = max(b1, b2);
		float st_cov = max(f_cov, sb);
		float web = 0.5 + 0.5 * sin((p.y + p.x * 0.4) * 800.0);
		vec3 stc = strap * (0.88 + 0.16 * mix(0.5, web, 1.0 - smoothstep(0.0015, 0.0045, w)) + 0.25 * (mott - 0.5));
		col = mix(col, stc, st_cov);
		rou = mix(rou, 0.8, st_cov);
		// Kanten-Stiche
		float st_edge = max(cs_stitch(f_sd + 0.0045, p.y, w) * fs, max(cs_stitch(s1 + 0.0045, p.x, w) * b1, cs_stitch(s2 + 0.0045, p.x, w) * b2));
		col = mix(col, navy * 0.6, st_edge * 0.55);
		// der obere Gurt liegt über dem unteren (Schatten an der Kreuzung)
		col *= 1.0 - 0.35 * gs(s2, 0.004) * b1 * (1.0 - b2);
		// Gurte werfen einen schmalen Schatten auf den Anzug
		ao *= 1.0 - 0.30 * gs(max(f_sd, 0.0), 0.0035) * fs * (1.0 - f_cov);
		ao *= 1.0 - 0.30 * gs(max(min(s1, s2), 0.0), 0.0035) * bs * (1.0 - sb);
		hh += st_cov * 0.0030;
		// Schnalle vorn
		float bkl = cov(box2(vec2(ax - 0.1335, y - 1.463), vec2(0.0165, 0.0125)), w) * fs * (1.0 - bs);
		col = mix(col, silver, bkl);
		met = mix(met, 0.85, bkl);
		rou = mix(rou, 0.38, bkl);
		float bkh = cov(box2(vec2(ax - 0.1335, y - 1.463), vec2(0.0085, 0.0065)), w) * fs * (1.0 - bs);
		col = mix(col, gun, bkh);
		hh += bkl * 0.0020;

		// Gürtel rundum (Leder), Schnalle und Taschen sind Zusatzteile (captain_suit.gd)
		if (y > 1.040 && y < 1.102) {
			float bz = cov(abs(y - 1.0715) - 0.0285, w);
			vec3 lc = cs_leather(leather_hi, p, w) * 0.80;
			col = mix(col, lc, bz);
			rou = mix(rou, 0.55, bz);
			float bst = max(cs_stitch(y - 1.0955, p.x + p.z, w), cs_stitch(y - 1.0475, p.x + p.z, w));
			col = mix(col, lin(vec3(0.5, 0.38, 0.3)), bst * 0.6 * bz);
			hh += bz * 0.0020;
		}
		// Gewebe, Körnung, Verwitterung: Falten und Abrieb am Bauch, Staub, Ruß
		col *= 1.0 + 0.08 * cl * (1.0 - st_cov) + 0.08 * grain * near_f;
		hh += cl * 0.00014 * near_f * (1.0 - st_cov);
		col *= 1.0 - 0.16 * smoothstep(0.55, 0.9, grime) * (1.0 - front * 0.4);
		col = mix(col, soot, 0.30 * smoothstep(0.62, 0.92, cs_vn3(p * vec3(13.0, 9.0, 13.0) + 2.0)) * (1.0 - smoothstep(1.2, 1.4, y)));
		col = mix(col, dust, 0.20 * smoothstep(0.5, 0.9, cs_vn3(p * 17.0 + 11.0)) * (1.0 - smoothstep(1.05, 1.3, y)));
	}

	// ------------------------------------------------ Arme
	if (arm) {
		// Schulter blau, Oberarm grau (Ärmel), Ellbogen, Stulpe, Handschuh
		float sl = smoothstep(0.30, 0.355, ax);
		col = mix(blue, gray, sl);
		col *= 1.0 + 0.10 * (mott - 0.5) + 0.20 * cl;
		col = mix(col, navy, ln(ax, 0.292, 0.003, w) * 0.7);
		// Ärmelnähte: Längsnaht oben und unten, Ring um den Bizeps, Ellbogen-Ring
		float armc = (p.y - 1.436) + 0.5 * (p.z + 0.062);
		col = mix(col, navy, cs_stitch(ax - 0.375, p.z * 1.0, w) * 0.45 * sl);
		float sl_s = (1.0 - smoothstep(0.455, 0.49, ax)) * smoothstep(0.31, 0.35, ax);
		float seam_t = cs_stitch(p.z + 0.062 + 0.012, p.x, w) * sl_s;
		col = mix(col, gray * 0.55, seam_t * 0.45);
		float seam_b = cs_stitch(p.z + 0.062 - 0.012, p.x, w) * sl_s;
		col = mix(col, gray * 0.55, seam_b * 0.40);
		hh -= ln(p.z + 0.062 + 0.012, 0.0, 0.0011, w) * sl_s * 0.0012;
		// Ellbogen: Falten (Innenseite vorn), dunkler Rand zum Stulpen
		float eb = smoothstep(0.43, 0.46, ax) * (1.0 - smoothstep(0.49, 0.50, ax));
		col = mix(col, gray * 0.62, eb * 0.55);
		float ef = cs_fold(ax, p.y * 1.0 + p.z, 78.0, 1.1, 0.7);
		float ez = smoothstep(0.405, 0.44, ax) * (1.0 - smoothstep(0.50, 0.54, ax)) * smoothstep(-0.075, -0.03, p.z);
		col *= 1.0 - 0.26 * ez * (1.0 - ef);
		hh += ez * (ef - 0.5) * 0.0030;
		ao *= 1.0 - 0.45 * ez * (1.0 - ef);
		// Falten am Oberarm (quer zum Arm, bei Bewegung gestaucht), Achsel
		float uf = cs_fold(ax, p.y + p.z, 40.0, 1.4, 3.3);
		float uz = smoothstep(0.31, 0.36, ax) * (1.0 - smoothstep(0.40, 0.44, ax));
		col *= 1.0 - 0.10 * uz * (1.0 - uf);
		hh += uz * (uf - 0.5) * 0.0016;
		// Bizeps/Trizeps: Schatten der Furche zwischen den Muskelbäuchen (unten am Arm)
		float groove = gs(p.y - 1.395, 0.012) * smoothstep(0.30, 0.34, ax) * (1.0 - smoothstep(0.44, 0.48, ax));
		col *= 1.0 - 0.18 * groove;
		ao *= 1.0 - 0.25 * groove;
		// Verwitterung: Staub und Ruß, fleckiger Stoff
		col = mix(col, gray * 0.7, 0.22 * sl * smoothstep(0.55, 0.9, grime));
		col = mix(col, soot, 0.20 * sl * smoothstep(0.66, 0.92, cs_vn3(p * 14.0 + 5.0)));
		col *= 1.0 + 0.06 * grain * near_f;
		hh += cl * 0.00014 * near_f;
		// Stulpe (Leder) unter den Zusatzteilen
		float gl = smoothstep(0.497, 0.503, ax);
		col = mix(col, cs_leather(leather, p, w), gl);
		// Hand: Lederhandschuh (dunkel), Naht, Knöchel, Fingerglieder
		float hd = smoothstep(0.732, 0.742, ax);
		vec3 gcol = cs_leather(glove, p, w);
		// Rücken (y hoch) und Handfläche (y tief): Handfläche etwas heller (abgegriffen)
		float palm = 1.0 - smoothstep(1.43, 1.44, y);
		gcol = mix(gcol, cs_leather(leather_hi * 0.8, p, w), palm * 0.55);
		// Fingerrillen (zwischen den Fingern) und Fingerglied-Falten quer
		float fz = (p.z + 0.062) / 0.0235 + 0.5;   // Fingerindex (Mitte = ganzzahlig + 0.5)
		float fsep = gs(fract(fz) - 0.0, 0.07) * smoothstep(0.86, 0.88, ax);
		gcol *= 1.0 - 0.45 * fsep;
		float j2 = mix(0.888, 0.902, smoothstep(-0.11, -0.06, p.z));
		float j3 = j2 + mix(0.026, 0.034, smoothstep(-0.11, -0.06, p.z));
		float jf = max(gs(ax - j2, 0.0016), gs(ax - j3, 0.0016)) * smoothstep(0.86, 0.88, ax) * (1.0 - smoothstep(0.96, 0.975, ax));
		gcol *= 1.0 - 0.55 * jf;
		ao *= 1.0 - 0.35 * jf - 0.25 * fsep;
		hh -= jf * 0.0007;
		// Knöchel und Fingerspitzen etwas abgewetzt
		float kn_ = gs(ax - 0.862, 0.008) * (1.0 - palm);
		gcol = mix(gcol, cs_leather(leather_hi, p, w), 0.45 * kn_);
		float tip = smoothstep(0.945, 0.97, ax);
		gcol = mix(gcol, cs_leather(leather_hi * 1.1, p, w), 0.35 * tip);
		gcol *= 1.0 - 0.20 * smoothstep(0.55, 0.9, cs_vn3(p * 70.0));
		col = mix(col, gcol, hd);
		// Naht über dem Handrücken und Daumenansatz
		col = mix(col, leather_hi * 0.8, cs_stitch(ax - 0.775, p.z, w) * hd * 0.6);
		col = mix(col, leather_hi * 0.8, cs_stitch(p.z + 0.062, p.x, w) * smoothstep(0.745, 0.80, ax) * (1.0 - smoothstep(0.84, 0.87, ax)) * hd * (1.0 - palm) * 0.45);
		rou = mix(0.80, 0.52, max(gl, hd));
		rim = mix(rim, 0.08, max(gl, hd));
		hh += gl * 0.0010;
	}

	// ------------------------------------------------ Stiefel (Fuss; der Schaft ist ein Zusatzteil)
	if (y < 0.37 && !arm) {
		vec3 bc = cs_leather(lin(vec3(0.21, 0.13, 0.095)), p, w);
		float bm = 1.0 - smoothstep(0.355, 0.365, y);
		col = mix(col, bc, bm);
		rou = mix(rou, 0.58, bm);
		rim = mix(rim, 0.10, bm);
		// Schnürung auf dem Fussrücken (helle Querstriche)
		float lace = step(0.5, fract(p.z / 0.016)) * cov(abs(ax - 0.092) - 0.011, w) * smoothstep(0.0, 0.03, p.z) * (1.0 - smoothstep(0.11, 0.13, p.z)) * smoothstep(0.06, 0.09, y);
		col = mix(col, lin(vec3(0.50, 0.42, 0.34)), lace * 0.7);
		// Kappe vorn dunkler mit Naht, Sohle schwarz mit Rand
		float toe = smoothstep(0.12, 0.15, p.z) * (1.0 - smoothstep(0.04, 0.10, y));
		col = mix(col, bc * 0.62, toe);
		col = mix(col, lin(vec3(0.5, 0.4, 0.32)), cs_stitch(p.z - 0.118 - 0.2 * abs(ax - 0.092), p.x, w) * (1.0 - smoothstep(0.075, 0.085, y)) * 0.5);
		float sole = 1.0 - smoothstep(0.018, 0.026, y);
		col = mix(col, lin(vec3(0.045, 0.04, 0.04)), sole);
		col = mix(col, lin(vec3(0.42, 0.33, 0.25)), cov(abs(y - 0.0305) - 0.0016, w) * (1.0 - sole));
		// Knöchel-Falten an der Beuge, Dreck
		float af = cs_fold(p.z, p.x, 60.0, 1.2, 1.1);
		float az = 0.0;
		col *= 1.0 - 0.2 * az * (1.0 - af);
		col = mix(col, dust, 0.50 * (1.0 - smoothstep(0.02, 0.2, y)) * (0.3 + 0.7 * grime));
		col = mix(col, dust * 0.8, 0.30 * smoothstep(0.55, 0.9, cs_vn3(p * 40.0)) * (1.0 - smoothstep(0.05, 0.3, y)));
		hh += cov(abs(y - 0.0305) - 0.0016, w) * 0.001;
		ao *= 1.0 - 0.5 * (1.0 - smoothstep(0.0, 0.03, y));
	}

	// ------------------------------------------------ Kopf: Haube mit Gesichtsöffnung
	if (y > 1.545 && ax < 0.13) {
		float hm = smoothstep(0.03, 0.07, p.z);
		float od = cs_open(ax, y);        // < 0 offen
		float op = cov(od, w) * hm;
		vec3 helm = lin(vec3(0.30, 0.38, 0.52));
		vec3 helm_hi = lin(vec3(0.33, 0.43, 0.57));
		float hcl = cs_cloth(p, tw, w, 0.0032);
		col = helm * (1.0 + 0.55 * hcl + 0.16 * (mott - 0.5));
		col *= 0.80 + 0.20 * smoothstep(-0.12, 0.08, p.z);
		rou = 0.58;
		met = 0.0;
		hh = 0.0;
		// Nähte: Mittelnaht, Seitennähte der Stirnplatte, Rand unten im Nacken
		float seam = cov(ax - 0.0011, w) * smoothstep(1.70, 1.72, y) * (1.0 - hm * smoothstep(1.77, 1.79, y) * 0.0);
		float xs = 0.060 + 0.014 * clamp((1.76 - y) / 0.12, 0.0, 1.0);
		float sseam = ln(ax, xs, 0.0011, w) * smoothstep(1.60, 1.64, y) * (1.0 - smoothstep(1.765, 1.785, y));
		col = mix(col, navy, (seam * 0.7 + sseam * 0.7) * (1.0 - op));
		hh -= (seam + sseam) * 0.0010;
		// Wulstiger Rand um Gesicht und Augen (heller, mit dunkler Kante)
		float bead = cov(abs(od - 0.0030) - 0.0026, w) * hm * (1.0 - op);
		col = mix(col, helm_hi, bead * 0.75);
		rou = mix(rou, 0.42, bead * 0.6);
		hh += bead * 0.0018;
		col = mix(col, navy * 0.7, cov(abs(od - 0.0004) - 0.0005, w) * hm * 0.55 * (1.0 - op));
		// Schatten der Haube auf dem Gesicht
		float shade = 1.0 - 0.28 * gs(od + 0.0035, 0.0045) * op;
		// Gesicht
		vec3 fcol = col;
		float frou = rou;
		vec3 femi = emi;
		cap_face(p, w, skin, lin(vec3(0.30, 0.42, 0.56)), lin(vec3(0.15, 0.09, 0.055)), lin(vec3(0.60, 0.36, 0.34)), op, fcol, frou, femi);
		col = fcol;
		col *= mix(1.0, shade, op);
		rou = frou;
		emi = femi;
		// weisses A auf der Stirn (erhabene Platte)
		vec2 aq = vec2(ax, y - 1.7365);
		float aleg = seg(aq, vec2(0.0335, -0.0285), vec2(0.0, 0.0315)) - 0.0070;
		float abar = box2(aq - vec2(0.0, -0.0105), vec2(0.0225, 0.0045));
		float ad = min(aleg, abar);
		float aa = cov(ad, w) * hm * (1.0 - op);
		vec3 ac = lin(vec3(0.46, 0.54, 0.63)) * (0.92 + 0.16 * mott);
		col = mix(col, ac, aa);
		rou = mix(rou, 0.45, aa);
		float ih = 0.0335 * (1.0 - (aq.y + 0.0285) / 0.06) - 0.0081;
		float cnt = cov(max(ax - ih, -0.0058 - aq.y), w) * hm * (1.0 - op);
		col *= 1.0 - 0.45 * cnt * (1.0 - aa);
		col *= 1.0 - 0.30 * gs(ad - 0.0008, 0.0016) * hm * (1.0 - aa) * (1.0 - op);
		hh += aa * 0.0030;
		// Rand der Haube am Hals
		col = mix(col, navy, ln(y, 1.548, 0.004, w) * 0.5 * (1.0 - hm));
	}
	// Hals zwischen Kragen und Haube
	if (y > 1.50 && y <= 1.545 && ax < 0.13) {
		col = mix(col, navy, 0.7);
	}
	hgt = hh;
}

// alte Schnittstelle (hero_suit.gdshader)
void cap(vec3 p, float w, out vec3 col, out float met, out float rou, out vec3 emi, out float hgt) {
	float ao;
	float rim;
	cap2(p, w, col, met, rou, emi, hgt, ao, rim);
}
