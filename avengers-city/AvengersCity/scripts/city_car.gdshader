shader_type spatial;
render_mode cull_disabled;
#include "res://scripts/city_common.gdshaderinc"
// Auto: Lack mit Klarlack, Kunststoff, Chrom, Reifen mit Profil, Felgen, Lampen, Tuerfugen. Art des Teils steckt in COLOR.a (Art/15).
// Innenseiten der Karosserie (cull_disabled) werden dunkel: so sieht man durch die Scheiben einen Innenraum.

uniform bool use_instance = true;
uniform vec4 paint_col : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float brake = 0.0;
uniform vec4 body = vec4(0.92, 4.8, 0.93, 0.30);      // halbe Breite, Laenge, Guertelhoehe, Schwellerhoehe
uniform vec4 wheelp = vec4(-1.4, 1.4, 0.33, 0.78);    // z Vorderachse, z Hinterachse, Radius, x Radmitte
uniform vec4 hl = vec4(0.50, 1.1, 0.56, 0.70);        // Scheinwerfer: x0 x1 y0 y1
uniform vec4 tl = vec4(0.50, 1.1, 0.72, 0.88);        // Ruecklicht
uniform vec4 gr = vec4(0.46, 0.46, 0.62, 0.0);        // Kuehlergrill: halbe Breite, y0, y1
uniform vec4 doors = vec4(-0.8, 0.2, 1.05, -99.0);    // z der Tuerfugen
uniform vec4 accent_col : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform vec4 accent_box = vec4(-0.8, 1.1, 0.3, 0.95);

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

void fragment() {
	int kind = int(v_col.a * 15.0 + 0.5);
	vec3 col = pow(v_col.rgb, vec3(2.2));
	float rough = 0.6;
	float metal = 0.0;
	float clear = 0.0;
	vec3 emis = vec3(0.0);
	bool bodyk = kind <= 2;
	float hwb = body.x;
	float hlen = body.y * 0.5;
	float px = max(max(length(dFdx(VERTEX)), length(dFdy(VERTEX))), 0.0005);
	float bf = 1.0 - smoothstep(0.004, 0.02, px);

	if (bodyk) {
		// Radkaesten ausschneiden
		if (abs(lp.x) > wheelp.w - 0.40) {
			float dy = lp.y - wheelp.z;
			float d1 = length(vec2(lp.z - wheelp.x, dy));
			float d2 = length(vec2(lp.z - wheelp.y, dy));
			if (min(d1, d2) < wheelp.z + 0.06) {
				discard;
			}
		}
	}

	if (kind == 0 || kind == 1) {
		vec3 base = kind == 0 ? pow(v_inst.rgb, vec3(2.2)) : col;
		// Akzentflaeche (Polizei: weisse Tueren)
		float am = accent_col.a * box2(lp.z, accent_box.x, accent_box.y, 0.01) * box2(lp.y, accent_box.z, accent_box.w, 0.01) * smoothstep(0.5, 0.8, abs(ln.x));
		base = mix(base, pow(accent_col.rgb, vec3(1.0)), am);
		float lum = dot(base, vec3(0.3, 0.59, 0.11));
		col = base;
		metal = mix(0.30, 0.06, smoothstep(0.05, 0.5, lum));
		rough = 0.26;
		clear = 1.0;
		float ay = abs(ln.y);
		// Schweller und Stossfaenger: schwarzer Kunststoff
		float sill = (1.0 - smoothstep(body.w - 0.05, body.w + 0.01, lp.y)) * smoothstep(0.4, 0.7, abs(ln.x));
		float endk = smoothstep(hlen - 0.75, hlen - 0.35, abs(lp.z));
		float bump = endk * (1.0 - smoothstep(0.31, 0.40, lp.y));
		float blk = max(sill, bump);
		blk = max(blk, smoothstep(-0.2, -0.6, ln.y));
		// Tuerfugen und Klinken (nur Seiten, unterhalb der Scheiben)
		float side = smoothstep(0.55, 0.8, abs(ln.x));
		float vy = box2(lp.y, body.w, body.z + 0.03, 0.004);
		float gap = 0.0;
		for (int i = 0; i < 4; i++) {
			float dz = abs(lp.z - doors[i]);
			gap = max(gap, 1.0 - smoothstep(0.0018, 0.0045, dz));
		}
		gap *= vy;
		float zlo = min(doors.x, min(doors.y, doors.z));
		float zhi = max(doors.x, max(doors.y, max(doors.z, doors.w)));
		float sillg = (1.0 - smoothstep(0.0018, 0.0045, abs(lp.y - body.w))) * box2(lp.z, zlo, zhi, 0.004);
		float hy = box2(lp.y, body.z - 0.115, body.z - 0.085, 0.004);
		float handle = 0.0;
		for (int i = 1; i < 4; i++) {
			handle = max(handle, box2(lp.z, doors[i] - 0.30, doors[i] - 0.16, 0.004) * hy * step(doors[i], 50.0) * step(-50.0, doors[i]));
		}
		handle *= side;
		gap = max(gap, sillg) * side;
		// Kuehlergrill
		float front = smoothstep(0.35, 0.7, -ln.z) * step(lp.z, -hlen + 0.1);
		float rear = smoothstep(0.35, 0.7, ln.z) * step(hlen - 0.1, lp.z);
		float ax = abs(lp.x);
		float grl = front * box2(ax, -1.0, gr.x, 0.01) * box2(lp.y, gr.y, gr.z, 0.008);
		float intake = front * box2(ax, -1.0, gr.x * 1.25, 0.01) * box2(lp.y, 0.20, 0.34, 0.008);
		float slats = smoothstep(0.35, 0.5, abs(fract(lp.y * 38.0) - 0.5));
		// Scheinwerfer (ziehen um die Ecke), Ruecklichter
		float hlm = box2(ax, hl.x, hl.y, 0.012) * box2(lp.y, hl.z, hl.w, 0.012) * step(lp.z, -hlen + 0.42) * smoothstep(-0.1, 0.2, -ln.z);
		float tlm = box2(ax, tl.x, tl.y, 0.012) * box2(lp.y, tl.z, tl.w, 0.012) * step(hlen - 0.40, lp.z) * smoothstep(-0.1, 0.2, ln.z);

		col *= 1.0 - 0.22 * smoothstep(0.55, 0.15, lp.y);
		col = mix(col, vec3(0.012), blk);
		rough = mix(rough, 0.55, blk);
		metal = mix(metal, 0.0, blk);
		clear = mix(clear, 0.0, blk);
		col = mix(col, vec3(0.006), gap * 0.95);
		rough = mix(rough, 0.8, gap);
		clear = mix(clear, 0.0, gap);
		col = mix(col, vec3(0.55, 0.56, 0.58), handle * 0.9);
		metal = mix(metal, 1.0, handle * 0.9);
		rough = mix(rough, 0.25, handle * 0.9);
		// Grill: dunkel mit Chromlamellen
		float gm = max(grl, intake);
		vec3 gcol = mix(vec3(0.008), vec3(0.45, 0.46, 0.48), slats * grl);
		col = mix(col, gcol, gm);
		metal = mix(metal, slats * grl, gm);
		rough = mix(rough, 0.35, gm);
		clear = mix(clear, 0.0, gm);
		// Scheinwerfer: Klarglas, innen Reflektor und Leuchtstreifen
		float hin = box2(ax, hl.x + 0.05, hl.y - 0.06, 0.01) * box2(lp.y, hl.z + 0.025, hl.w - 0.025, 0.01);
		vec3 hcol = mix(vec3(0.55, 0.57, 0.6), vec3(0.03, 0.03, 0.035), hin);
		float led = box2(lp.y, hl.w - 0.045, hl.w - 0.02, 0.006) * box2(ax, hl.x + 0.04, hl.y - 0.08, 0.01);
		col = mix(col, hcol, hlm);
		metal = mix(metal, 0.7, hlm);
		rough = mix(rough, 0.08, hlm);
		clear = mix(clear, 0.0, hlm);
		emis += vec3(1.0, 0.97, 0.9) * led * hlm * 3.0 + vec3(1.0, 0.95, 0.85) * hlm * 0.06;
		// Ruecklicht: rote Linse, hell beim Bremsen
		float tin = box2(ax, tl.x + 0.03, tl.y - 0.05, 0.01) * box2(lp.y, tl.z + 0.02, tl.w - 0.02, 0.01);
		vec3 tcol = mix(vec3(0.35, 0.015, 0.012), vec3(0.6, 0.02, 0.015), tin);
		col = mix(col, tcol, tlm);
		metal = mix(metal, 0.0, tlm);
		rough = mix(rough, 0.1, tlm);
		clear = mix(clear, 0.0, tlm);
		emis += vec3(1.0, 0.04, 0.03) * tlm * (0.12 + v_inst.a * 5.0 * (0.4 + 0.6 * tin));
		// Rueckfahrlicht (weiss, klein) im Ruecklicht innen
		float rev = box2(ax, tl.x, tl.x + 0.07, 0.006) * box2(lp.y, tl.z + 0.02, tl.w - 0.04, 0.006) * tlm;
		col = mix(col, vec3(0.7), rev * 0.8);
	} else if (kind == 2) {
		rough = 0.42;
		clear = 0.4;
	} else if (kind == 3) {
		col = max(col, vec3(0.5));
		metal = 1.0;
		rough = 0.12;
	} else if (kind == 4) {
		// Reifen: UV.x rund herum, UV.y von innen nach aussen
		float tread = smoothstep(0.30, 0.36, UV.y) * (1.0 - smoothstep(0.64, 0.70, UV.y));
		float rib = abs(fract(UV.x * 56.0 + UV.y * 3.0) - 0.5);
		float lug = smoothstep(0.30, 0.42, rib);
		float mid = 1.0 - smoothstep(0.015, 0.03, abs(UV.y - 0.5));
		float h = tread * max(lug * 0.7, mid);
		float ring = (1.0 - smoothstep(0.0, 0.012, abs(UV.y - 0.18))) + (1.0 - smoothstep(0.0, 0.012, abs(UV.y - 0.82)));
		col = vec3(0.012) + vec3(0.045) * (1.0 - tread) * (0.4 + ring);
		rough = 0.9;
		NORMAL = bump_normal(NORMAL, VERTEX, -h * 0.012 * bf, 1.0);
	} else if (kind == 5) {
		// Felge: UV ist eine Scheibe -1..1, Speichen nach Winkel
		vec2 p = UV * 2.0 - 1.0;
		float r = length(p);
		float a = atan(p.y, p.x) / 6.2831853;
		float f = abs(fract(a * 5.0 + 0.25) - 0.5);
		float spoke = 1.0 - smoothstep(0.075 + 0.05 * (1.0 - r), 0.115 + 0.05 * (1.0 - r), f);
		float rimr = smoothstep(0.84, 0.88, r);
		float hub = 1.0 - smoothstep(0.17, 0.2, r);
		float metalm = max(max(spoke * step(0.18, r), rimr), hub);
		vec3 rc = col;
		col = mix(vec3(0.03, 0.03, 0.035), rc, metalm);
		metal = mix(0.85, 1.0, metalm);
		rough = mix(0.5, 0.22, metalm);
		float hubc = 1.0 - smoothstep(0.05, 0.08, r);
		col = mix(col, vec3(0.02), hubc * 0.8);
	} else if (kind == 6) {
		rough = 0.85;
	} else if (kind == 7) {
		emis = col * 2.0;
	} else if (kind == 8) {
		emis = col * 1.8;
		rough = 0.3;
	} else if (kind == 9) {
		float ph = step(0.5, fract(TIME * 2.2));
		float side = lp.x < 0.0 ? ph : 1.0 - ph;
		vec3 lc = lp.x < 0.0 ? vec3(1.0, 0.05, 0.03) : vec3(0.1, 0.25, 1.0);
		col = lc * 0.4;
		emis = lc * (0.15 + side * 4.0);
		rough = 0.2;
	} else if (kind == 10) {
		col = vec3(0.012);
		rough = 0.9;
	} else if (kind == 11) {
		// Kennzeichen: weiss, blauer Streifen, dunkle Zeichen
		vec2 q = UV;
		float cell = floor(q.x * 8.0);
		float lx = fract(q.x * 8.0);
		float hh = 0.45 + 0.4 * hash21(vec2(cell, 3.0));
		float chr = box2(lx, 0.2, 0.8, 0.04) * box2(q.y, 0.5 - hh * 0.5, 0.5 + hh * 0.5, 0.05) * step(1.0, cell);
		chr *= 0.55 + 0.45 * step(0.5, fract(lx * 3.0 + hash21(vec2(cell, 7.0))));
		col = mix(vec3(0.78, 0.78, 0.75), vec3(0.03), chr);
		col = mix(col, vec3(0.05, 0.1, 0.5), 1.0 - step(1.0, q.x * 8.0));
		rough = 0.35;
	}

	if (bodyk && !FRONT_FACING) {
		col = vec3(0.012, 0.012, 0.014);
		rough = 0.95;
		metal = 0.0;
		clear = 0.0;
		emis = vec3(0.0);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.5;
	CLEARCOAT = clear;
	CLEARCOAT_ROUGHNESS = 0.03;
	EMISSION = emis;
}
