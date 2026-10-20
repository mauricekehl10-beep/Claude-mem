shader_type spatial;
render_mode cull_disabled;
#include "res://scripts/city_common.gdshaderinc"
#include "res://scripts/weather_wet.gdshaderinc"
// Auto: Lack mit Metallic-Flakes, Klarlack und leichter Verschmutzung, Kunststoff, Chrom, Reifen mit Seitenwandschrift, Felgen,
// Scheinwerfer, Ruecklichter, Grill, Tuerfugen, Kennzeichen. Art des Teils steckt in COLOR.a (Art/15).
// Innenseiten der Karosserie (cull_disabled) werden dunkel: so sieht man durch die Scheiben einen Innenraum.
// Wetter (weather.gd): nasser Lack glaenzt staerker mit Regentropfen, nachts leuchten Scheinwerfer und Ruecklichter.

uniform bool use_instance = true;
uniform vec4 paint_col = vec4(0.5, 0.5, 0.5, 1.0);    // Lackfarbe in sRGB (Einzelauto)
uniform float brake = 0.0;
uniform vec4 body = vec4(0.92, 4.8, 0.93, 0.30);      // halbe Breite, Laenge, Guertelhoehe, Schwellerhoehe
uniform vec4 wheelp = vec4(-1.4, 1.4, 0.33, 0.78);    // z Vorderachse, z Hinterachse, Radius, x Radmitte
uniform vec4 hl = vec4(0.50, 1.1, 0.56, 0.70);        // Scheinwerfer: x0 x1 y0 y1
uniform vec4 tl = vec4(0.50, 1.1, 0.72, 0.88);        // Ruecklicht
uniform vec4 gr = vec4(0.46, 0.46, 0.62, 0.0);        // Kuehlergrill: halbe Breite, y0, y1, w = Hoehe Taxischild
uniform vec4 doors = vec4(-0.8, 0.2, 1.05, -99.0);    // z der Tuerfugen
uniform vec4 flags = vec4(0.0);                       // Taxi, Polizei, Bus, Van
uniform float clad = 0.0;

varying vec3 lp;
varying vec3 ln;
varying vec4 v_col;
varying vec4 v_inst;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
	v_col = COLOR;
	v_inst = use_instance ? INSTANCE_CUSTOM : vec4(paint_col.rgb, brake);
}

float box2(float x, float lo, float hi, float aa) {
	return smoothstep(lo - aa, lo + aa, x) * (1.0 - smoothstep(hi - aa, hi + aa, x));
}

float segd(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

// Block-Buchstaben T A X I in einer Zelle 0..1
float glyph(vec2 q, int id) {
	float d = 9.0;
	if (id == 0) {
		d = min(segd(q, vec2(0.05, 0.92), vec2(0.95, 0.92)), segd(q, vec2(0.5, 0.92), vec2(0.5, 0.08)));
	} else if (id == 1) {
		d = min(min(segd(q, vec2(0.08, 0.08), vec2(0.5, 0.92)), segd(q, vec2(0.92, 0.08), vec2(0.5, 0.92))), segd(q, vec2(0.25, 0.4), vec2(0.75, 0.4)));
	} else if (id == 2) {
		d = min(segd(q, vec2(0.08, 0.08), vec2(0.92, 0.92)), segd(q, vec2(0.92, 0.08), vec2(0.08, 0.92)));
	} else {
		d = min(segd(q, vec2(0.5, 0.92), vec2(0.5, 0.08)), min(segd(q, vec2(0.25, 0.92), vec2(0.75, 0.92)), segd(q, vec2(0.25, 0.08), vec2(0.75, 0.08))));
	}
	return 1.0 - smoothstep(0.08, 0.13, d);
}

void fragment() {
	int kind = int(v_col.a * 15.0 + 0.5);
	vec3 col = pow(v_col.rgb, vec3(2.2));
	float rough = 0.6;
	float metal = 0.0;
	float clear = 0.0;
	vec3 emis = vec3(0.0);
	float hlen = body.y * 0.5;
	float px = max(max(length(dFdx(VERTEX)), length(dFdy(VERTEX))), 0.0005);
	float bf = 1.0 - smoothstep(0.004, 0.02, px);
	float lamps_on = smoothstep(0.25, 0.6, wx_night);
	float wetk = wx_wet;
	float spec = 0.5;

	if (kind == 0 || kind == 1) {
		vec3 base = kind == 0 ? pow(v_inst.rgb, vec3(2.2)) : col;
		float fin = hash11(dot(v_inst.rgb, vec3(12.9, 78.2, 37.7)) * 3.1);
		float ax = abs(lp.x);
		float side = smoothstep(0.55, 0.8, abs(ln.x));
		// Polizei: weisse Tueren (Schwarz-Weiss)
		if (flags.y > 0.5) {
			float dm = box2(lp.z, doors.x - 0.02, doors.z + 0.15, 0.02) * box2(lp.y, 0.28, body.z + 0.02, 0.02) * side;
			base = mix(base, vec3(0.78, 0.78, 0.8), dm);
		}
		float lum = dot(base, vec3(0.3, 0.59, 0.11));
		float mp = step(0.28, fin) * (1.0 - flags.x * 0.9);
		col = max(base, vec3(0.020, 0.020, 0.022));
		spec = 0.95;
		metal = mp * mix(0.45, 0.2, smoothstep(0.05, 0.5, lum));
		rough = 0.30 - 0.06 * mp;
		clear = 1.0;
		// Metallic-Flakes: winzige Glitzerzellen, blickwinkelabhaengig (nur nah genug, sonst flimmert es)
		vec3 fc = floor(lp * 520.0);
		float fr = hash21(fc.xy + fc.z * 17.31);
		float tw = hash21(fc.xy * 1.7 + floor(VIEW.xy * 6.0) + 3.0);
		float sp = step(0.965, fr) * step(0.35, tw) * mp * (1.0 - smoothstep(0.003, 0.012, px));
		col = mix(col, col * 2.4 + 0.02, sp * 0.8);
		metal = mix(metal, 0.95, sp * 0.8);
		rough = mix(rough, 0.18, sp);
		// Verschmutzung: Strassenfilm unten, an den Radhaeusern
		float dirt_k = 0.10 + 0.32 * hash11(dot(v_inst.rgb, vec3(5.3, 11.9, 2.1)) * 7.7);
		float dn = vnoise(lp.xz * 7.0 + lp.y * 3.0) * 0.6 + vnoise(lp.xz * 31.0 + lp.yy * 19.0) * 0.4;
		float grime = smoothstep(0.72, 0.18, lp.y + (dn - 0.5) * 0.25) * dirt_k;
		float wheelz = min(abs(lp.z - wheelp.x), abs(lp.z - wheelp.y));
		grime += smoothstep(0.7, 0.3, wheelz) * smoothstep(0.55, 0.2, lp.y) * dirt_k * 0.7;
		grime = clamp(grime, 0.0, 0.85);
		col = mix(col, vec3(0.095, 0.082, 0.07), grime * 0.78);
		rough = mix(rough, 0.62, grime);
		clear = mix(clear, 0.3, grime);
		metal = mix(metal, 0.0, grime);
		// Schweller und Stossfaenger: schwarzer Kunststoff
		float sill = (1.0 - smoothstep(body.w - 0.06, body.w - 0.01, lp.y)) * smoothstep(0.4, 0.7, abs(ln.x));
		float endk = smoothstep(hlen - 0.75, hlen - 0.35, abs(lp.z));
		float bump = endk * (1.0 - smoothstep(0.31, 0.40, lp.y));
		float blk = max(sill * (1.0 - clad), bump);
		// Tuerfugen, Griffe
		float vy = box2(lp.y, body.w + 0.02, body.z + 0.03, 0.004);
		float gap = 0.0;
		for (int i = 0; i < 4; i++) {
			float dz = abs(lp.z - doors[i]);
			gap = max(gap, 1.0 - smoothstep(0.0016, 0.0042, dz));
		}
		gap *= vy;
		float zlo = min(doors.x, min(doors.y, doors.z));
		float zhi = max(doors.x, max(doors.y, max(doors.z, doors.w)));
		float sillg = (1.0 - smoothstep(0.0016, 0.0042, abs(lp.y - (body.w + 0.02)))) * box2(lp.z, zlo, zhi, 0.004);
		float hy = box2(lp.y, body.z - 0.125, body.z - 0.095, 0.004);
		float handle = 0.0;
		for (int i = 1; i < 4; i++) {
			handle = max(handle, box2(lp.z, doors[i] - 0.30, doors[i] - 0.14, 0.004) * hy * step(doors[i], 50.0) * step(-50.0, doors[i]));
		}
		handle *= side;
		gap = max(gap, sillg) * side;
		col *= 1.0 - 0.18 * smoothstep(0.55, 0.12, lp.y);
		col = mix(col, vec3(0.012), blk);
		rough = mix(rough, 0.55, blk);
		metal = mix(metal, 0.0, blk);
		clear = mix(clear, 0.0, blk);
		col = mix(col, vec3(0.005), gap * 0.95);
		rough = mix(rough, 0.8, gap);
		clear = mix(clear, 0.0, gap);
		col = mix(col, vec3(0.6, 0.61, 0.63), handle * 0.9);
		metal = mix(metal, 1.0, handle * 0.9);
		rough = mix(rough, 0.25, handle * 0.9);
		// Kuehlergrill, Lufteinlass unten, Nebelscheinwerfer
		float front = smoothstep(0.35, 0.7, -ln.z) * step(lp.z, -hlen + 0.1);
		float gx = box2(ax, -1.0, gr.x, 0.012);
		float gy = box2(lp.y, gr.y, gr.z, 0.008);
		float grl = front * gx * gy;
		float gframe = front * clamp(box2(ax, -1.0, gr.x + 0.014, 0.006) * box2(lp.y, gr.y - 0.014, gr.z + 0.014, 0.006) - gx * gy, 0.0, 1.0);
		float intake = front * box2(ax, -1.0, gr.x * 1.3, 0.012) * box2(lp.y, 0.20, gr.y - 0.09, 0.008);
		float slats = smoothstep(0.32, 0.5, abs(fract(lp.y * 42.0) - 0.5));
		float hex = smoothstep(0.25, 0.4, abs(fract(lp.x * 55.0 + floor(lp.y * 55.0) * 0.5) - 0.5));
		float fogl = front * (1.0 - smoothstep(0.045, 0.06, length(vec2(ax - gr.x * 1.25, lp.y - 0.27))));
		// Scheinwerfer (ziehen um die Ecke), Ruecklichter
		float hlm = box2(ax, hl.x, hl.y, 0.012) * box2(lp.y, hl.z, hl.w, 0.012) * step(lp.z, -hlen + 0.46) * smoothstep(-0.1, 0.2, -ln.z);
		float tlm = box2(ax, tl.x, tl.y, 0.012) * box2(lp.y, tl.z, tl.w, 0.012) * step(hlen - 0.44, lp.z) * smoothstep(-0.1, 0.2, ln.z);
		float gm = max(grl, intake);
		vec3 gcol = vec3(0.008);
		gcol = mix(gcol, vec3(0.4, 0.41, 0.43), slats * grl);
		gcol = mix(gcol, vec3(0.05, 0.05, 0.055), hex * intake);
		col = mix(col, gcol, gm);
		metal = mix(metal, max(slats * grl, 0.5 * intake), gm);
		rough = mix(rough, 0.35, gm);
		clear = mix(clear, 0.0, gm);
		col = mix(col, vec3(0.62, 0.63, 0.66), gframe);
		metal = mix(metal, 1.0, gframe);
		rough = mix(rough, 0.2, gframe);
		clear = mix(clear, 0.0, gframe);
		col = mix(col, vec3(0.01), fogl);
		metal = mix(metal, 0.5, fogl);
		rough = mix(rough, 0.1, fogl);
		emis += vec3(1.0, 0.9, 0.7) * fogl * lamps_on * 0.8;
		// Emblem: kleines Chromoval mittig auf dem Grill
		float emb = (1.0 - smoothstep(0.022, 0.03, length(vec2(lp.x, (lp.y - (gr.y + gr.z) * 0.5) * 1.5)))) * front;
		col = mix(col, vec3(0.7), emb * 0.9);
		metal = mix(metal, 1.0, emb * 0.9);
		// Scheinwerfer: Klarglas ueber dunklem Reflektor, Projektor, LED-Tagfahrlicht
		float hin = box2(ax, hl.x + 0.04, hl.y - 0.07, 0.01) * box2(lp.y, hl.z + 0.02, hl.w - 0.02, 0.01);
		vec2 pc = vec2(ax - (hl.x + (hl.y - hl.x) * 0.38), lp.y - (hl.z + hl.w) * 0.5 + 0.004);
		float proj = 1.0 - smoothstep(0.03, 0.036, length(pc));
		float projr = 1.0 - smoothstep(0.0, 0.006, abs(length(pc) - 0.04));
		vec3 hcol = mix(vec3(0.52, 0.54, 0.58), vec3(0.025, 0.026, 0.03), hin);
		hcol = mix(hcol, vec3(0.55, 0.57, 0.6), projr * hin * 0.8);
		hcol = mix(hcol, vec3(0.75, 0.8, 0.9), proj * hin);
		float led = box2(lp.y, hl.w - 0.05, hl.w - 0.022, 0.006) * box2(ax, hl.x + 0.03, hl.y - 0.09, 0.01);
		col = mix(col, hcol, hlm);
		metal = mix(metal, 0.8, hlm);
		rough = mix(rough, 0.06, hlm);
		clear = mix(clear, 0.0, hlm);
		emis += vec3(1.0, 0.97, 0.92) * hlm * (led * (2.5 + lamps_on * 5.0) + proj * hin * (0.15 + lamps_on * 3.5) + 0.05);
		// Ruecklicht: rote Linse mit hellen Baendern, hell beim Bremsen
		float tin = box2(ax, tl.x + 0.03, tl.y - 0.05, 0.01) * box2(lp.y, tl.z + 0.02, tl.w - 0.02, 0.01);
		float band = box2(lp.y, mix(tl.z, tl.w, 0.45), mix(tl.z, tl.w, 0.7), 0.006);
		vec3 tcol = mix(vec3(0.33, 0.012, 0.01), vec3(0.62, 0.02, 0.015), tin);
		col = mix(col, tcol, tlm);
		metal = mix(metal, 0.0, tlm);
		rough = mix(rough, 0.08, tlm);
		clear = mix(clear, 0.0, tlm);
		float brk = v_inst.a > 0.5 ? 1.0 : 0.0;
		emis += vec3(1.0, 0.04, 0.03) * tlm * (0.10 + lamps_on * 0.9 + brk * 4.5 * (0.4 + 0.6 * tin) + band * tin * (0.6 + brk * 5.0));
		float rev = box2(ax, tl.x, tl.x + 0.07, 0.006) * box2(lp.y, tl.z + 0.02, tl.w - 0.04, 0.006) * tlm;
		col = mix(col, vec3(0.7), rev * 0.8);
		// Taxi: schwarz-weisses Schachbrettband an der Tuer
		if (flags.x > 0.5) {
			float stripe = box2(lp.y, body.z - 0.30, body.z - 0.22, 0.006) * box2(lp.z, doors.x + 0.05, doors.z + 0.3, 0.006) * side;
			float chk = step(0.5, fract(lp.z * 9.0));
			col = mix(col, mix(vec3(0.01), vec3(0.8, 0.7, 0.2), chk), stripe * 0.9);
		}
	} else if (kind == 2) {
		rough = 0.45;
		clear = 0.35;
		float n2 = vnoise(lp.xz * 90.0 + lp.yy * 40.0);
		col *= 0.85 + 0.3 * n2;
	} else if (kind == 3) {
		col = max(col, vec3(0.5));
		metal = 1.0;
		rough = 0.12;
	} else if (kind == 4) {
		// Reifen: UV.x rund herum, UV.y von innen nach aussen
		float tread = smoothstep(0.34, 0.38, UV.y) * (1.0 - smoothstep(0.62, 0.66, UV.y));
		float rib = abs(fract(UV.x * 58.0 + (UV.y - 0.5) * 3.0 * sign(UV.y - 0.5)) - 0.5);
		float lug = smoothstep(0.28, 0.42, rib);
		float mid = 1.0 - smoothstep(0.012, 0.026, abs(UV.y - 0.5));
		float grv = max(1.0 - smoothstep(0.012, 0.024, abs(UV.y - 0.42)), 1.0 - smoothstep(0.012, 0.024, abs(UV.y - 0.58)));
		float h = tread * max(max(lug * 0.7, mid), grv);
		float swall = 1.0 - tread;
		float ring = (1.0 - smoothstep(0.0, 0.012, abs(UV.y - 0.17))) + (1.0 - smoothstep(0.0, 0.012, abs(UV.y - 0.83)));
		float txt_band = box2(UV.y, 0.115, 0.145, 0.004) + box2(UV.y, 0.855, 0.885, 0.004);
		float cell = floor(UV.x * 210.0);
		float cf = fract(UV.x * 210.0);
		float letter = step(0.45, hash21(vec2(cell, 3.7))) * box2(cf, 0.15, 0.8, 0.05);
		float word = step(0.55, hash21(vec2(floor(UV.x * 7.0), 1.3)));
		float letters = txt_band * letter * word * (1.0 - smoothstep(0.004, 0.012, px));
		col = vec3(0.012) + vec3(0.045) * swall * (0.4 + ring) + vec3(0.2) * letters * swall;
		rough = 0.85 - 0.25 * letters;
		NORMAL = bump_normal(NORMAL, VERTEX, -h * 0.012 * bf, 1.0);
		float dirtw = 0.4 * vnoise(vec2(UV.x * 40.0, UV.y * 6.0));
		col = mix(col, vec3(0.05, 0.045, 0.04), dirtw * swall * 0.5);
	} else if (kind == 5) {
		// Felge: Scheibe -1..1 (flache Ausfuehrung) oder echte Speichen (UV = 0)
		vec2 p = UV * 2.0 - 1.0;
		float r = length(p);
		if (dot(UV, UV) < 0.0001) {
			col = max(col, vec3(0.45));
			metal = 1.0;
			rough = 0.22;
		} else {
			float a = atan(p.y, p.x) / 6.2831853;
			float f = abs(fract(a * 5.0 + 0.25) - 0.5);
			float spoke = 1.0 - smoothstep(0.075 + 0.05 * (1.0 - r), 0.115 + 0.05 * (1.0 - r), f);
			float rimr = smoothstep(0.84, 0.88, r);
			float hub = 1.0 - smoothstep(0.17, 0.2, r);
			float metalm = max(max(spoke * step(0.18, r), rimr), hub);
			vec3 rc = max(col, vec3(0.4));
			col = mix(vec3(0.03, 0.03, 0.035), rc, metalm);
			metal = mix(0.85, 1.0, metalm);
			rough = mix(0.5, 0.22, metalm);
			float hubc = 1.0 - smoothstep(0.05, 0.08, r);
			col = mix(col, vec3(0.02), hubc * 0.8);
		}
	} else if (kind == 6) {
		rough = 0.85;
		float f = vnoise(lp.xz * 60.0 + lp.yy * 30.0);
		col *= 0.8 + 0.4 * f;
	} else if (kind == 7) {
		// Taxischild: leuchtend gelb-weiss mit "TAXI"
		vec3 lc = vec3(1.0, 0.86, 0.5);
		float txt = 0.0;
		if (abs(ln.z) > 0.5) {
			float xx = (ln.z < 0.0 ? -lp.x : lp.x) + 0.26;
			float cx = floor(xx / 0.13);
			float lx = (xx - cx * 0.13) / 0.11;
			float ly = (lp.y - (gr.w - 0.065)) / 0.13;
			if (cx >= 0.0 && cx < 4.0 && lx < 1.0 && ly > 0.0 && ly < 1.0) {
				txt = glyph(vec2(lx, ly), int(cx));
			}
		}
		col = mix(lc * 0.4, vec3(0.03), txt);
		emis = mix(lc * 1.3, vec3(0.0), txt) * (0.55 + lamps_on * 1.0);
		rough = 0.3;
	} else if (kind == 8) {
		emis = col * 1.8;
		rough = 0.3;
	} else if (kind == 9) {
		float ph = step(0.5, fract(TIME * 2.2));
		float sd = lp.x < 0.0 ? ph : 1.0 - ph;
		vec3 lc = lp.x < 0.0 ? vec3(1.0, 0.05, 0.03) : vec3(0.1, 0.25, 1.0);
		col = lc * 0.4;
		emis = lc * (0.15 + sd * 4.0);
		rough = 0.2;
	} else if (kind == 10) {
		col = vec3(0.012);
		rough = 0.9;
	} else if (kind == 11) {
		// US-Kennzeichen: weiss, blaue Kopfzeile, dunkle Zeichen
		vec2 q = UV;
		float cell = floor(q.x * 7.0);
		float lx = fract(q.x * 7.0);
		float hh = 0.55 + 0.3 * hash21(vec2(cell, 3.0));
		float chr = box2(lx, 0.18, 0.82, 0.05) * box2(q.y, 0.54 - hh * 0.26, 0.54 + hh * 0.26, 0.05);
		chr *= 0.55 + 0.45 * step(0.5, fract(lx * 3.0 + hash21(vec2(cell, 7.0))));
		float head = box2(q.y, 0.0, 0.2, 0.02);
		float hchr = head * box2(fract(q.x * 14.0), 0.2, 0.75, 0.08) * step(0.4, hash21(vec2(floor(q.x * 14.0), 9.0)));
		col = mix(vec3(0.8, 0.8, 0.77), vec3(0.03), chr);
		col = mix(col, vec3(0.05, 0.1, 0.45), head * 0.9);
		col = mix(col, vec3(0.85), hchr * 0.7);
		rough = 0.35;
		clear = 0.3;
	} else if (kind == 12) {
		// Bremsscheibe (UV.x rund, UV.y radial) und Sattel
		if (UV.y > 0.001) {
			float slot = (1.0 - smoothstep(0.02, 0.06, abs(fract(UV.x * 36.0) - 0.5) - 0.34)) * box2(UV.y, 0.25, 0.8, 0.02);
			col = mix(vec3(0.19, 0.17, 0.16), vec3(0.015), slot * 0.9);
			col *= 0.8 + 0.4 * vnoise(vec2(UV.x * 120.0, UV.y * 8.0));
			metal = 0.85;
			rough = 0.35;
		} else {
			rough = 0.45;
			metal = 0.5;
		}
	} else if (kind == 13) {
		rough = 0.07;
		metal = 0.15;
		clear = 0.5;
	}

	if (kind <= 2 || kind == 13) {
		// Regentropfen auf nassem Lack: kleine Perlen auf waagerechten Flaechen
		float rainy = smoothstep(0.1, 0.6, wx_rain) * smoothstep(0.3, 0.8, ln.y);
		if (rainy > 0.01) {
			vec2 q = lp.xz * 85.0 + lp.y * 40.0;
			vec2 id = floor(q);
			vec2 f = fract(q) - vec2(0.5);
			vec2 o = (hash22(id) - 0.5) * 0.5;
			float dd = length(f - o);
			float rad = 0.12 + 0.2 * hash21(id + 3.3);
			float bead = (1.0 - smoothstep(rad - 0.05, rad, dd)) * step(0.4, hash21(id));
			NORMAL = bump_normal(NORMAL, VERTEX, bead * 0.0006 * bf * rainy, 1.0);
			rough = mix(rough, 0.05, bead * rainy);
		}
	}

	if (!FRONT_FACING && kind != 11) {
		col = vec3(0.012, 0.012, 0.014);
		rough = 0.95;
		metal = 0.0;
		clear = 0.0;
		emis = vec3(0.0);
	}
	if ((kind <= 2 || kind == 13) && FRONT_FACING) {
		// Spiegelung von Himmel und Haeuserwaenden (ergaenzt die Umgebungsspiegelung, damit dunkle Lacke sichtbar glaenzen)
		vec3 vw = normalize(VIEW);
		vec3 rw = normalize((INV_VIEW_MATRIX * vec4(reflect(-vw, NORMAL), 0.0)).xyz);
		float ndv2 = clamp(dot(NORMAL, vw), 0.0, 1.0);
		float fr2 = 0.06 + 0.94 * pow(1.0 - ndv2, 5.0);
		vec3 skyc = mix(vec3(0.62, 0.72, 0.9), vec3(0.22, 0.4, 0.8), clamp(rw.y, 0.0, 1.0));
		skyc = mix(skyc, vec3(dot(skyc, vec3(0.33))) * 0.8, wetk * 0.6);
		vec3 envc = mix(vec3(0.20, 0.19, 0.19), skyc, smoothstep(0.18, 0.7, rw.y));
		envc = rw.y < 0.0 ? vec3(0.13, 0.12, 0.11) : envc;
		envc *= 1.0 - wx_night * 0.9;
		emis += envc * fr2 * (kind == 13 ? 1.2 : (0.6 + 1.4 * clear)) * (1.0 + wetk * 0.6);
	}
	rough *= 1.0 - 0.45 * wetk;
	col *= 1.0 - 0.12 * wetk;
	emis *= 1.0 + wx_night * 1.5;
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = spec + (1.0 - spec) * wetk * 0.6;
	CLEARCOAT = clear;
	CLEARCOAT_ROUGHNESS = mix(0.04, 0.015, wetk);
	EMISSION = emis;
}
