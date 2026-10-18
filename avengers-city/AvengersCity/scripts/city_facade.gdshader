shader_type spatial;
#include "res://scripts/city_common.gdshaderinc"
#include "res://scripts/weather_wet.gdshaderinc"
// Fassaden fuer die ganze Stadt: Ziegel, Naturstein, Beton-Fensterband, Glas-Vorhangfassade, Putz, Ladenzone, Parkhaus.
// UV  = (Spalte, Geschoss) in Zelleneinheiten, UV2 = (Meter je Spalte, Meter je Geschoss), COLOR.rgb = Farbton, COLOR.a = Zufallswert (0 = Brandmauer ohne Fenster).

uniform int kind = 0;
uniform vec3 wall_col : source_color = vec3(0.55, 0.27, 0.20);
uniform vec3 trim_col : source_color = vec3(0.70, 0.66, 0.60);
uniform vec3 frame_col : source_color = vec3(0.85, 0.85, 0.82);
uniform vec3 glass_col : source_color = vec3(0.05, 0.09, 0.14);
uniform vec2 win_size = vec2(1.15, 1.75);
uniform float sill_h = 0.95;
uniform float glass_metal = 0.15;
uniform float glass_rough = 0.06;
uniform float grime = 0.6;
uniform float arch_top = 0.0;
uniform sampler2D n_blotch : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D n_grain : repeat_enable, filter_linear_mipmap_anisotropic;

varying vec2 v_cell;
varying vec2 v_msz;
varying vec4 v_col;
varying vec3 v_wp;
varying vec3 v_wn;

void vertex() {
	v_cell = UV;
	v_msz = UV2;
	v_col = COLOR;
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Fensterinhalt: Spiegelung, Jalousie, Vorhang, dunkles Zimmer
void window_content(float r, vec2 pq, vec2 psz, float rnd2, out vec3 col, out float refl) {
	refl = 1.0;
	col = glass_col;
	float t = pq.y / psz.y; // 0 unten, 1 oben
	if (r > 0.52 && r < 0.64) {
		// Jalousie: unten offen, oben Lamellen
		float drop = 0.35 + 0.65 * rnd2;
		if (t > 1.0 - drop) {
			float lam = 0.5 + 0.5 * sin(pq.y * 70.0);
			col = mix(vec3(0.62, 0.58, 0.50), vec3(0.78, 0.74, 0.66), lam);
			refl = 0.15;
		}
	} else if (r >= 0.64 && r < 0.76) {
		// Vorhang
		float side = 0.28 + 0.2 * rnd2;
		float fold = 0.5 + 0.5 * sin(pq.x * 22.0);
		vec3 cc = mix(vec3(0.62, 0.16, 0.14), vec3(0.18, 0.28, 0.46), step(0.5, rnd2));
		cc = mix(cc, vec3(0.78, 0.70, 0.52), step(0.8, rnd2));
		if (pq.x < psz.x * side || pq.x > psz.x * (1.0 - side)) {
			col = cc * (0.65 + 0.35 * fold);
			refl = 0.25;
		} else {
			col = glass_col * 1.2;
		}
	} else if (r >= 0.76 && r < 0.86) {
		// helles Zimmer
		col = mix(vec3(0.55, 0.45, 0.30), vec3(0.28, 0.22, 0.14), t) * (0.6 + 0.6 * rnd2);
		refl = 0.55;
	}
}

void fragment() {
	vec2 m = v_cell * v_msz;
	float px = max(max(length(dFdx(m)), length(dFdy(m))), 0.002);
	vec2 id = floor(v_cell);
	vec2 q = fract(v_cell) * v_msz;
	float seed = v_col.a;
	float blank = step(seed, 0.01);
	float rr = hash21(id + vec2(seed * 57.3, seed * 13.1));
	float rr2 = hash21(id * 1.7 + vec2(seed * 91.7, 3.3));
	float rr3 = hash21(id * 2.3 + vec2(17.0, seed * 7.9));
	vec3 tint = v_col.rgb;
	float blot = texture(n_blotch, v_wp.xz * 0.02 + v_wp.y * 0.017).r;
	float blot2 = texture(n_blotch, vec2(m.x * 0.11 + seed * 7.0, m.y * 0.11)).r;
	float g1 = texture(n_grain, vec2(m.x, m.y) * 0.8).r;
	float g2 = texture(n_grain, vec2(m.x, m.y) * 2.7 + vec2(0.3, 0.9)).r;

	vec3 col = wall_col * tint;
	float rough = 0.85;
	float metal = 0.0;
	float bh = 0.0;
	float ao = 1.0;
	vec3 emis = vec3(0.0);

	// ---------------- Wandmaterial ----------------
	if (kind == 0 || kind == 8) {
		// Ziegel im Laeuferverband
		vec2 bu = vec2(0.225, 0.0725);
		vec2 bq = m / bu;
		float row = floor(bq.y);
		float off = mod(row, 2.0) * 0.5;
		vec2 bf = vec2(fract(bq.x + off), fract(bq.y));
		vec2 bid = vec2(floor(bq.x + off), row);
		float bh1 = hash21(bid + seed * 31.0);
		float bh2 = hash21(bid * 1.3 + 5.0);
		vec2 aab = vec2(px) / bu;
		float mort = 1.0 - rect_cov(bf, vec2(0.035, 0.10), vec2(0.965, 0.90), aab);
		vec3 bcol = col * (0.72 + 0.5 * bh1) * (0.92 + 0.16 * g2);
		bcol = mix(bcol, bcol * vec3(1.15, 0.95, 0.85), step(0.9, bh2) * 0.7);
		vec3 mcol = vec3(0.55, 0.54, 0.50);
		vec3 c = mix(bcol, mcol, mort);
		vec3 avg = mix(col * 0.98, mcol, 0.17);
		float lod = smoothstep(0.018, 0.07, px);
		col = mix(c, avg, lod);
		bh = -0.005 * mort * (1.0 - lod) + 0.0015 * g1;
		rough = 0.88;
	} else if (kind == 1 || kind == 9) {
		// Naturstein-Quader
		vec2 su = vec2(0.95, 0.5);
		vec2 sq = m / su;
		float row = floor(sq.y);
		float off = mod(row, 2.0) * 0.5;
		vec2 sf = vec2(fract(sq.x + off), fract(sq.y));
		vec2 sid = vec2(floor(sq.x + off), row);
		float sh = hash21(sid + seed * 11.0);
		vec2 aas = vec2(px) / su;
		float jn = 1.0 - rect_cov(sf, vec2(0.012, 0.022), vec2(0.988, 0.978), aas);
		vec3 sc = col * (0.90 + 0.18 * sh) * (0.93 + 0.14 * g2);
		vec3 c = mix(sc, sc * 0.55, jn);
		float lod = smoothstep(0.03, 0.12, px);
		col = mix(c, col * 0.97, lod);
		bh = -0.004 * jn * (1.0 - lod) + 0.002 * g1;
		rough = 0.82;
	} else if (kind == 2) {
		// Betonfertigteile
		col *= 0.88 + 0.22 * g1;
		float pj = 1.0 - cov(min(fract(v_cell.x), 1.0 - fract(v_cell.x)) * v_msz.x, 0.012, 1.0, px);
		col *= 1.0 - 0.45 * pj * (1.0 - smoothstep(0.03, 0.12, px));
		rough = 0.8;
		bh = 0.0012 * g1 - 0.002 * pj;
	} else if (kind == 4 || kind == 6) {
		// Putz
		col *= 0.92 + 0.14 * g1 * g2 + 0.06 * g2;
		rough = 0.9;
		bh = 0.001 * g1;
	} else if (kind == 5) {
		col *= 0.9 + 0.2 * g1;
		rough = 0.8;
	} else {
		col *= 0.9 + 0.2 * g1;
		rough = 0.85;
	}

	float is_glass = 0.0;
	float glass_refl = 0.0;
	vec3 gcol = glass_col;

	// ---------------- Oeffnungen ----------------
	if (blank < 0.5) {
		if (kind == 0 || kind == 1 || kind == 4 || kind == 8 || kind == 9) {
			// Lochfassade: ein Fenster je Zelle, zentriert
			float ww = win_size.x;
			float wh = win_size.y;
			float cx = v_msz.x * 0.5;
			vec2 lo = vec2(cx - ww * 0.5, sill_h);
			vec2 hi = vec2(cx + ww * 0.5, sill_h + wh);
			vec2 aa = vec2(px);
			float wc = rect_cov(q, lo, hi, aa);
			// Rundbogen-Option (arch_top > 0): oben abgerundet
			if (arch_top > 0.5) {
				float rad = ww * 0.5;
				vec2 cc = vec2(cx, hi.y - rad);
				float inarch = step(cc.y, q.y);
				float dd = length(q - cc);
				float archcov = 1.0 - smoothstep(rad - px, rad + px, dd);
				wc = mix(wc, archcov * cov(q.x, lo.x, hi.x, px), inarch);
			}
			// Fenstereinfassung / Sims / Sturz
			float sill = rect_cov(q, vec2(lo.x - 0.10, lo.y - 0.11), vec2(hi.x + 0.10, lo.y), aa);
			float lintel = rect_cov(q, vec2(lo.x - 0.12, hi.y), vec2(hi.x + 0.12, hi.y + 0.20), aa);
			float surround = 0.0;
			if (kind == 1 || kind == 9) {
				surround = rect_cov(q, lo - vec2(0.16, 0.0), hi + vec2(0.16, 0.0), aa) * (1.0 - wc);
			}
			vec3 tcol = trim_col * (0.9 + 0.15 * g1);
			col = mix(col, tcol, max(max(sill, lintel), surround));
			// Rahmen
			float fw = 0.075;
			float inner = rect_cov(q, lo + vec2(fw), hi - vec2(fw), aa);
			if (arch_top > 0.5) { inner = wc * cov(q.x, lo.x + fw, hi.x - fw, px) * cov(q.y, lo.y + fw, hi.y - fw * 3.0, px); }
			float frame = wc * (1.0 - inner);
			// Fensterkreuz: Querholm und ggf. Mittelsprosse
			float rail = rect_cov(q, vec2(lo.x, mix(lo.y, hi.y, 0.62) - 0.025), vec2(hi.x, mix(lo.y, hi.y, 0.62) + 0.025), aa);
			float mull = 0.0;
			if (ww > 1.0) { mull = rect_cov(q, vec2(cx - 0.025, lo.y), vec2(cx + 0.025, hi.y), aa); }
			frame = max(frame, max(rail, mull) * wc);
			// Fensterinhalt
			vec2 pq = q - lo - vec2(fw);
			vec2 psz = vec2(ww, wh) - vec2(2.0 * fw);
			vec3 icol;
			float irefl;
			window_content(rr, pq, psz, rr2, icol, irefl);
			// Tiefe: Laibung wirft Schatten (oben/links dunkler)
			float rev = 1.0 - 0.45 * (1.0 - smoothstep(0.0, 0.22, hi.y - q.y)) - 0.25 * (1.0 - smoothstep(0.0, 0.12, q.x - lo.x));
			icol *= rev;
			// Klimageraet im unteren Fenster
			float ac = step(0.88, rr3) * rect_cov(q, vec2(cx - 0.35, lo.y + 0.05), vec2(cx + 0.35, lo.y + 0.50), aa) * wc;
			vec3 base_after_frame = icol;
			float is_g = wc * inner;
			// Farbmischung
			col = mix(col, frame_col * (0.9 + 0.15 * g1), frame * wc);
			col = mix(col, icol, is_g * (1.0 - frame));
			col = mix(col, vec3(0.62, 0.64, 0.66), ac);
			is_glass = is_g * (1.0 - frame) * (1.0 - ac);
			glass_refl = irefl;
			// Hoehenprofil: Fenster liegt zurueck
			bh = bh - 0.14 * wc * smoothstep(0.0, 1.0, 1.0 - frame * 0.5) + 0.03 * max(sill, lintel) * (1.0 - wc);
			// Schmutzfahnen unter Fenstern
			float streak = vnoise(vec2(q.x * 14.0 + id.x * 5.0, m.y * 0.5));
			float below = smoothstep(lo.y - 0.9, lo.y, q.y) * (1.0 - smoothstep(lo.y - 0.02, lo.y, q.y));
			col *= 1.0 - grime * 0.22 * below * streak * step(abs(q.x - cx), ww * 0.65);
			ao = mix(ao, 0.65, wc * 0.4);
		} else if (kind == 2) {
			// Fensterband ueber die ganze Zellenbreite
			float marg = 0.35;
			vec2 lo = vec2(marg, sill_h);
			vec2 hi = vec2(v_msz.x - marg, sill_h + win_size.y);
			vec2 aa = vec2(px);
			float wc = rect_cov(q, lo, hi, aa);
			float fw = 0.06;
			float inner = rect_cov(q, lo + vec2(fw), hi - vec2(fw), aa);
			float frame = wc * (1.0 - inner);
			float mull = rect_cov(q, vec2(v_msz.x * 0.5 - 0.03, lo.y), vec2(v_msz.x * 0.5 + 0.03, hi.y), aa) * wc;
			frame = max(frame, mull);
			vec2 pq = q - lo - vec2(fw);
			vec2 psz = vec2(hi.x - lo.x, win_size.y) - vec2(2.0 * fw);
			vec3 icol;
			float irefl;
			window_content(rr, pq, psz, rr2, icol, irefl);
			icol *= 1.0 - 0.4 * (1.0 - smoothstep(0.0, 0.2, hi.y - q.y));
			col = mix(col, frame_col, frame);
			col = mix(col, icol, wc * inner * (1.0 - frame));
			is_glass = wc * inner * (1.0 - frame);
			glass_refl = irefl;
			// Brüstungsband heller
			float spandrel = rect_cov(q, vec2(-1.0, 0.0), vec2(v_msz.x + 1.0, sill_h), aa);
			col = mix(col, trim_col * tint * 0.95, spandrel * 0.5);
			bh = bh - 0.1 * wc;
			ao = mix(ao, 0.7, wc * 0.4);
		} else if (kind == 3) {
			// Vorhangfassade
			float sp = 0.95;
			vec2 aa = vec2(px);
			float slab = rect_cov(q, vec2(-1.0, v_msz.y - 0.30), vec2(v_msz.x + 1.0, v_msz.y + 1.0), aa);
			float spand = rect_cov(q, vec2(-1.0, -1.0), vec2(v_msz.x + 1.0, sp), aa);
			float mull_v = 1.0 - cov(min(q.x, v_msz.x - q.x), 0.045, 100.0, px);
			float mull_h = max(cov(q.y, sp - 0.04, sp + 0.04, px), 0.0);
			float frame = clamp(max(mull_v, mull_h), 0.0, 1.0);
			vec3 spcol = wall_col * tint * (0.9 + 0.2 * g1);
			vec2 pq = q - vec2(0.0, sp);
			float gv = 1.0 - max(slab, spand);
			// leichte Variation von Scheibe zu Scheibe
			vec3 icol = gcol * (0.8 + 0.5 * rr);
			float irefl = 1.0;
			if (rr > 0.9) { icol = mix(icol, vec3(0.6, 0.58, 0.5), 0.6 * (1.0 - smoothstep(0.0, 1.0, pq.y / 1.6))); irefl = 0.35; }
			col = mix(icol, spcol, max(slab, spand));
			col = mix(col, frame_col, frame * 0.9);
			is_glass = gv * (1.0 - frame);
			glass_refl = irefl;
			rough = 0.5;
			metal = 0.0;
			bh = -0.02 * gv + 0.01 * frame;
			// Glas-Kippung: dezente senkrechte Streifen
			float st = vnoise(vec2(m.x * 3.0, m.y * 0.15));
			col *= 1.0 - 0.1 * st * gv;
		} else if (kind == 5) {
			// Ladenzone: Schaufenster, Tuer, Schriftband, Sockel
			float cw = v_msz.x;
			float fhgt = v_msz.y;
			vec2 aa = vec2(px);
			float is_door = step(0.6, rr) * step(0.35, rr2);
			float is_shut = step(0.86, rr3) * (1.0 - is_door);
			// Sockel
			float base = rect_cov(q, vec2(-1.0, -1.0), vec2(cw + 1.0, 0.45), aa);
			// Schriftband
			float signb = rect_cov(q, vec2(0.0, fhgt - 0.95), vec2(cw, fhgt - 0.12), aa);
			// Glasflaeche
			vec2 lo = vec2(0.18, 0.5);
			vec2 hi = vec2(cw - 0.18, fhgt - 1.15);
			float wc = rect_cov(q, lo, hi, aa);
			float fw = 0.07;
			float inner = rect_cov(q, lo + vec2(fw), hi - vec2(fw), aa);
			float frame = wc * (1.0 - inner);
			float mull = rect_cov(q, vec2(cw * 0.5 - 0.035, lo.y), vec2(cw * 0.5 + 0.035, hi.y), aa) * wc;
			float trans = rect_cov(q, vec2(lo.x, hi.y - 0.55 - 0.03), vec2(hi.x, hi.y - 0.55 + 0.03), aa) * wc;
			frame = max(frame, max(mull * (1.0 - is_door), trans));
			vec3 scol = vec3(0.5, 0.2, 0.15);
			float hh = hash21(vec2(id.x * 1.3, floor(seed * 100.0)));
			scol = mix(vec3(0.72, 0.12, 0.1), vec3(0.1, 0.25, 0.5), step(0.25, hh));
			scol = mix(scol, vec3(0.1, 0.38, 0.22), step(0.5, hh));
			scol = mix(scol, vec3(0.15, 0.13, 0.12), step(0.7, hh));
			scol = mix(scol, vec3(0.85, 0.72, 0.15), step(0.88, hh));
			col = wall_col * tint * (0.9 + 0.2 * g1);
			col = mix(col, vec3(0.08, 0.08, 0.09), base);
			col = mix(col, scol, signb);
			// helle Schrift-Andeutung (Streifen) im Schriftband
			float letters = step(0.5, vnoise(vec2(q.x * 7.0, 1.0 + floor(seed * 40.0)))) * rect_cov(q, vec2(0.25, fhgt - 0.75), vec2(cw - 0.25, fhgt - 0.32), aa);
			col = mix(col, vec3(0.95, 0.93, 0.88), letters * 0.8 * signb);
			emis += vec3(0.95, 0.93, 0.88) * letters * signb * 0.12;
			// Innenraum: Gradient (hell unten), Regalbretter, Waren, Deckenlicht
			vec2 pq = q - lo - vec2(fw);
			vec2 psz2 = hi - lo - vec2(2.0 * fw);
			float ty = clamp(pq.y / max(psz2.y, 0.1), 0.0, 1.0);
			vec3 icol = mix(vec3(0.30, 0.22, 0.15), vec3(0.06, 0.055, 0.05), smoothstep(0.1, 1.0, ty));
			float bay = floor(pq.x / 0.45);
			float ph2 = hash21(vec2(bay, id.x * 3.0 + floor(seed * 50.0)));
			float shelf_y = fract(pq.y / 0.55);
			float product = step(0.12, shelf_y) * step(shelf_y, 0.8) * step(pq.y, 1.9) * step(0.3, ph2);
			vec3 prod = mix(mix(vec3(0.55, 0.14, 0.1), vec3(0.15, 0.3, 0.55), ph2), vec3(0.7, 0.62, 0.3), step(0.7, ph2));
			icol = mix(icol, prod * 0.7, product * 0.55);
			float shelf_line = 1.0 - smoothstep(0.0, 0.03, abs(shelf_y - 0.05));
			icol = mix(icol, vec3(0.22, 0.17, 0.12), shelf_line * step(pq.y, 1.9) * 0.6);
			float lite = cov(ty, 0.9, 0.96, 0.02) * step(0.5, fract(pq.x / 1.2 + 0.25));
			icol += vec3(1.0, 0.95, 0.85) * lite * 0.6;
			icol = mix(icol, glass_col * 0.6, 0.35 * rr3);
			col = mix(col, frame_col * 0.6, frame);
			col = mix(col, icol, wc * inner * (1.0 - frame));
			is_glass = wc * inner * (1.0 - frame) * (1.0 - is_shut);
			glass_refl = 0.55;
			emis += icol * is_glass * 0.35;
			// Tuer
			if (is_door > 0.5) {
				float dm = rect_cov(q, vec2(cw * 0.5 - 0.55, 0.0), vec2(cw * 0.5 + 0.55, 2.25), aa);
				float din = rect_cov(q, vec2(cw * 0.5 - 0.46, 0.1), vec2(cw * 0.5 + 0.46, 2.15), aa);
				col = mix(col, vec3(0.06, 0.06, 0.07), dm);
				col = mix(col, glass_col * 0.9 + vec3(0.04, 0.03, 0.02), din);
				is_glass = max(is_glass, din * 0.9);
				glass_refl = 0.7;
				emis += vec3(0.25, 0.2, 0.12) * din * 0.4;
			}
			// Rolladen
			if (is_shut > 0.5) {
				float sh2 = wc;
				float ribs = 0.5 + 0.5 * sin(q.y * 95.0);
				col = mix(col, vec3(0.36, 0.37, 0.39) * (0.8 + 0.2 * ribs) * (0.8 + 0.4 * blot2), sh2);
				float gr = step(0.55, vnoise(vec2(q.x * 2.1, q.y * 2.4 + id.x * 7.0)));
				col = mix(col, vec3(0.7, 0.25, 0.5) * 0.6, sh2 * gr * 0.35 * step(0.5, rr2));
				metal = 0.3 * sh2;
				rough = mix(rough, 0.55, sh2);
			}
			bh = bh - 0.08 * wc;
		} else if (kind == 6) {
			// Parkhaus: Betonbrüstung + offene Felder mit Autos im Dunkeln
			float cw = v_msz.x;
			vec2 aa = vec2(px);
			float slab = rect_cov(q, vec2(-1.0, -1.0), vec2(cw + 1.0, 1.05), aa);
			float colm = 1.0 - cov(min(q.x, cw - q.x), 0.3, 100.0, px);
			float op = (1.0 - max(slab, colm));
			vec3 inside = vec3(0.04, 0.04, 0.045);
			float car = step(0.45, rr) * rect_cov(q, vec2(0.3, 1.05), vec2(cw - 0.3, 1.85), aa);
			float cc = hash21(id + 4.0);
			vec3 carc = mix(vec3(0.35, 0.05, 0.05), vec3(0.65, 0.65, 0.7), step(0.5, cc));
			carc = mix(carc, vec3(0.08, 0.1, 0.2), step(0.8, cc));
			inside = mix(inside, carc * 0.4, car);
			float lite = rect_cov(q, vec2(cw * 0.5 - 0.5, v_msz.y - 0.5), vec2(cw * 0.5 + 0.5, v_msz.y - 0.38), aa);
			inside += vec3(0.9, 0.9, 0.8) * lite * 0.15;
			col = mix(col, inside, op);
			col *= 0.9 + 0.2 * g1;
			emis += vec3(0.9, 0.9, 0.8) * lite * op * 0.25;
			rough = mix(0.85, 0.9, op);
			bh = bh - 0.3 * op;
			ao = mix(ao, 0.5, op);
		}
	}

	// ---------------- Verschmutzung ----------------
	float h = v_wp.y;
	float low = 1.0 - smoothstep(0.0, 2.4, h);
	col *= 1.0 - grime * 0.35 * low * (0.5 + 0.5 * blot2);
	float streaks = vnoise(vec2(m.x * 2.7 + seed * 40.0, m.y * 0.35));
	col *= 1.0 - grime * 0.16 * smoothstep(0.35, 0.9, streaks) * (0.4 + 0.6 * blot);
	col *= 0.9 + 0.2 * blot;

	// ---------------- Ausgabe ----------------
	vec3 gcol_out = col;
	float gm = is_glass;
	float refl_m = glass_metal * glass_refl;
	// Wetter (scripts/weather.gd): Waende werden bei Regen dunkler und glatter; nachts leuchtet ein Teil der Fenster warm
	col *= 1.0 - 0.22 * wx_wet * (1.0 - gm);
	rough *= 1.0 - 0.3 * wx_wet;
	if (wx_night > 0.01 && gm > 0.01) {
		float on = step(1.0 - 0.12 - 0.45 * wx_night, hash21(id * 1.31 + vec2(seed * 53.0, 4.7)));
		vec3 wcol = mix(vec3(1.0, 0.72, 0.40), vec3(0.62, 0.80, 1.0), step(0.86, hash21(id * 2.7 + vec2(9.1, seed * 21.0))));
		float room = (0.45 + 0.55 * vnoise(vec2(m.x * 1.7 + seed * 13.0, m.y * 1.1))) * mix(1.0, 0.4, clamp(q.y / max(v_msz.y, 0.5), 0.0, 1.0)); // Licht im Zimmer ist nicht gleichmaessig
		emis += wcol * gm * on * room * (0.25 + 1.45 * wx_night * wx_night) * (0.7 + 0.5 * rr2) * clamp(2.2 / v_msz.x, 0.5, 1.0);
	}
	ALBEDO = col;
	ROUGHNESS = mix(rough, glass_rough, gm);
	METALLIC = mix(metal, refl_m, gm);
	SPECULAR = mix(0.5, 1.0, gm);
	AO = ao;
	AO_LIGHT_AFFECT = 0.4;
	EMISSION = emis;
	float bump_fade = 1.0 - smoothstep(0.05, 0.2, px);
	NORMAL = bump_normal(NORMAL, VERTEX, bh * (0.35 + 0.65 * bump_fade), 1.0);
}
