shader_type spatial;
#include "res://scripts/city_common.gdshaderinc"
#include "res://scripts/weather_wet.gdshaderinc"
// Strassen-Asphalt mit Fahrbahnmarkierungen, Rinnstein, Kanaldeckeln. Ein einziges Mesh fuer die ganze Stadt:
// das Strassenraster wird im Shader aus der Weltposition berechnet.

uniform sampler2D n_blotch : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D n_grain : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D n_crack : repeat_enable, filter_linear_mipmap_anisotropic;
uniform float city_half = 470.0;

const float STEP = 72.0;
const float RH = 6.0;
const float CR = 3.5;
const float PH = 30.0;

varying vec3 wp;

float sd_pad(vec2 p) {
	vec2 b = p - STEP * round(p / STEP);
	vec2 q = abs(b) - vec2(PH - CR);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - CR;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wp.xz;
	float px = max(max(length(dFdx(p)), length(dFdy(p))), 0.003);
	vec2 s = mod(p, STEP) - 36.0;
	vec2 a = abs(s);
	float d = sd_pad(p);

	// --- Asphalt ---
	float blot = texture(n_blotch, p * 0.0113).r;
	float blot2 = texture(n_blotch, p * 0.043 + vec2(0.31, 0.77)).r;
	float g1 = texture(n_grain, p * 0.83).r;
	float g2 = texture(n_grain, p * 2.9 + vec2(0.17, 0.53)).r;
	float g3 = texture(n_grain, p * 0.21 + vec2(0.61, 0.13)).r;
	vec3 asph = vec3(0.200, 0.200, 0.205);
	asph *= 0.70 + 0.65 * blot;
	asph *= 0.88 + 0.24 * blot2;
	float aggr = smoothstep(0.56, 0.86, g1);
	asph = mix(asph, vec3(0.42, 0.42, 0.43), aggr * 0.38);
	asph *= 0.82 + 0.36 * g2;
	float dark_spot = (1.0 - smoothstep(0.30, 0.62, g2)) * 0.18;
	asph *= 1.0 - dark_spot;
	float rough = 0.90;
	float metal = 0.0;
	float bump_h = (g1 * 0.0030 + g2 * 0.0014 + g3 * 0.004);

	// Reifenspuren (poliert, dunkler) entlang der Fahrspuren
	float in_x_arm = step(a.y, RH) * step(RH, a.x);
	float in_z_arm = step(a.x, RH) * step(RH, a.y);
	float trk_x = exp(-pow((a.y - 1.05) / 0.33, 2.0)) + exp(-pow((a.y - 2.75) / 0.33, 2.0));
	float trk_z = exp(-pow((a.x - 1.05) / 0.33, 2.0)) + exp(-pow((a.x - 2.75) / 0.33, 2.0));
	float trk = (trk_x * in_x_arm + trk_z * in_z_arm) * (0.45 + 0.55 * blot2);
	asph *= 1.0 - 0.20 * trk;
	rough = mix(rough, 0.66, trk * 0.8);

	// Rissnetz (nur in bestimmten Bereichen)
	float crk = texture(n_crack, p * 0.115).r;
	float crack_mask = smoothstep(0.55, 0.78, blot) * (1.0 - smoothstep(0.0, 0.035 + px * 0.5, crk));
	float crk2 = texture(n_crack, p * 0.37 + vec2(0.4, 0.2)).r;
	crack_mask += smoothstep(0.6, 0.85, blot2) * 0.6 * (1.0 - smoothstep(0.0, 0.03 + px * 0.5, crk2));
	crack_mask = clamp(crack_mask, 0.0, 1.0);
	asph *= 1.0 - 0.55 * crack_mask;
	bump_h -= 0.004 * crack_mask;

	// Flicken (Grabenreparaturen)
	vec2 pc = floor(p / 13.0);
	float ph = hash21(pc + 3.7);
	if (ph > 0.84) {
		vec2 pcen = (pc + 0.25 + 0.5 * hash22(pc + 9.1)) * 13.0;
		vec2 psz = vec2(0.6 + 1.4 * hash21(pc + 1.3), 0.4 + 0.6 * hash21(pc + 5.9));
		if (hash21(pc + 2.2) > 0.5) { psz = psz.yx; }
		vec2 dq = abs(p - pcen) - psz;
		float pm = 1.0 - smoothstep(-px, px, max(dq.x, dq.y));
		float edge = 1.0 - smoothstep(0.0, 0.05 + px, abs(max(dq.x, dq.y)));
		asph = mix(asph, vec3(0.1, 0.1, 0.105) * (0.9 + 0.2 * g2), pm * 0.7);
		asph = mix(asph, asph * 0.4, edge * 0.7);
		rough = mix(rough, 0.82, pm);
	}

	// Oelflecken in der Parkspur
	float oil = smoothstep(0.66, 0.82, texture(n_blotch, p * 0.27 + vec2(0.7, 0.2)).r);
	float park_zone = max(in_x_arm * smoothstep(3.5, 4.2, a.y), in_z_arm * smoothstep(3.5, 4.2, a.x));
	asph *= 1.0 - 0.45 * oil * park_zone;
	rough = mix(rough, 0.45, oil * park_zone * 0.7);

	vec3 col = asph;

	// --- Markierungen ---
	float la = 0.0;
	float lcn = 0.0;
	float arm = 0.0;
	if (in_x_arm > 0.5) {
		la = a.x;
		lcn = s.y * sign(s.x);
		arm = 1.0;
	} else if (in_z_arm > 0.5) {
		la = a.y;
		lcn = -s.x * sign(s.y);
		arm = 1.0;
	}
	// Zebrastreifen: Naeherung auch im Flaerebereich der Ecken (Bordstein schneidet ab)
	float zeb_arm = 0.0;
	float zla = 0.0;
	float zlc = 0.0;
	if (a.x >= a.y && a.y < RH + 3.0 && a.x < RH + 6.0) {
		zeb_arm = 1.0;
		zla = a.x;
		zlc = s.y;
	} else if (a.y > a.x && a.x < RH + 3.0 && a.y < RH + 6.0) {
		zeb_arm = 1.0;
		zla = a.y;
		zlc = s.x;
	}
	float white = 0.0;
	float yellow = 0.0;
	if (zeb_arm > 0.5) {
		float t = abs(fract(zlc + 0.5) - 0.5);
		float bar = 1.0 - smoothstep(0.27 - px, 0.27 + px, t);
		float zone = cov(zla, 7.2, 10.2, px);
		white += bar * zone * step(abs(zlc), 8.5);
	}
	if (arm > 0.5) {
		// Haltelinie nur auf den ankommenden Fahrspuren
		white += cov(la, 10.9, 11.55, px) * cov(lcn, -3.75, -0.15, px);
		// Doppelte gelbe Mittellinie und weisse Parkspurlinie
		float run = smoothstep(11.6, 11.9, la);
		float cl = abs(abs(lcn) - 0.15);
		yellow += (1.0 - smoothstep(0.055 - px * 0.5, 0.055 + px, cl)) * run;
		float pl = abs(abs(lcn) - 3.8);
		white += (1.0 - smoothstep(0.055 - px * 0.5, 0.055 + px, pl)) * run;
	}
	float wear = smoothstep(0.28, 0.72, g2 * 0.5 + g1 * 0.25 + blot2 * 0.6);
	float paint_a = (0.55 + 0.45 * wear) * (1.0 - 0.35 * trk);
	vec3 white_col = vec3(0.72, 0.72, 0.70) * (0.85 + 0.2 * g3);
	vec3 yellow_col = vec3(0.78, 0.58, 0.08) * (0.85 + 0.2 * g3);
	float wc = clamp(white, 0.0, 1.0) * paint_a;
	float yc = clamp(yellow, 0.0, 1.0) * paint_a;
	col = mix(col, white_col, wc);
	col = mix(col, yellow_col, yc);
	rough = mix(rough, 0.58, max(wc, yc));
	bump_h += 0.0006 * max(wc, yc);

	// --- Rinnstein (Betonstreifen am Bordstein) ---
	if (d > -0.5) {
		float gw = 1.0 - smoothstep(0.40, 0.55, d);
		vec3 conc = vec3(0.32, 0.31, 0.30) * (0.75 + 0.5 * g3);
		col = mix(col, conc, gw);
		rough = mix(rough, 0.88, gw);
		float dirt = (1.0 - smoothstep(0.0, 0.22, d)) * (0.5 + 0.5 * blot2);
		col *= 1.0 - 0.45 * dirt;
		// Fugen alle 3 m
		
		float along = mix(p.y, p.x, step(a.y, a.x));
		float jt = abs(fract((along + 0.37) / 3.0) - 0.5) * 3.0;
		col *= 1.0 - 0.4 * gw * (1.0 - smoothstep(0.012, 0.012 + px, abs(jt - 1.5)));
	}

	// --- Ablaeufe an den Bordsteinen ---
	float drain = 0.0;
	vec2 dr = vec2(0.0);
	if (a.y < RH + 0.2 && a.x > 13.0 && a.x < 14.6) {
		dr = vec2(a.x - 13.0, a.y - 5.25);
		drain = rect_cov(dr, vec2(0.0, 0.0), vec2(1.6, 0.62), vec2(px));
	} else if (a.x < RH + 0.2 && a.y > 13.0 && a.y < 14.6) {
		dr = vec2(a.y - 13.0, a.x - 5.25);
		drain = rect_cov(dr, vec2(0.0, 0.0), vec2(1.6, 0.62), vec2(px));
	}
	if (drain > 0.0) {
		float slots = 1.0 - smoothstep(0.0, 0.04 + px, abs(fract(dr.x * 7.0) - 0.5) - 0.18);
		vec3 gcol = mix(vec3(0.05, 0.05, 0.055), vec3(0.17, 0.16, 0.15), slots);
		col = mix(col, gcol, drain);
		rough = mix(rough, 0.5, drain);
		metal = drain * 0.5;
	}

	// --- Kanaldeckel ---
	vec2 mcell = floor(p / 18.0);
	vec2 mc = (mcell + 0.25 + 0.5 * hash22(mcell + 4.4)) * 18.0;
	vec2 ms = abs(mod(mc, STEP) - 36.0);
	if (hash21(mcell + 7.0) > 0.35 && min(ms.x, ms.y) < 3.2 && max(ms.x, ms.y) > 9.0) {
		float md = length(p - mc);
		float disc = cov(md, -1.0, 0.46, px);
		if (disc > 0.0) {
			float ring = 1.0 - smoothstep(0.0, 0.03 + px, abs(md - 0.39));
			float ridges = 0.5 + 0.5 * sin(md * 55.0);
			vec3 mcol = mix(vec3(0.075, 0.07, 0.07), vec3(0.16, 0.15, 0.14), ridges * 0.5 + ring * 0.4);
			col = mix(col, mcol, disc);
			rough = mix(rough, 0.45, disc);
			metal = max(metal, disc * 0.6);
			bump_h += disc * 0.004 * ridges;
		}
	}

	// --- Pfuetzen / Feuchtigkeit ---
	float pud_n = texture(n_blotch, p * 0.061 + vec2(0.13, 0.91)).r;
	// Wetter (wx_wet, scripts/weather.gd): trocken = Oelflecken/Schmutz wie frueher, bei Regen echte Pfuetzen (Spiegel)
	float pud = smoothstep(0.80 - wx_wet * 0.14, 0.88 - wx_wet * 0.14, pud_n + (1.0 - smoothstep(0.0, 1.5, d)) * (0.07 + 0.06 * wx_wet));
	pud *= step(0.0, d);
	float wet = clamp(wx_wet * (0.8 + 0.4 * blot2), 0.0, 1.0);
	float paint = max(wc, yc);
	col *= 1.0 - 0.45 * pud;
	col *= 1.0 - 0.40 * wet * (1.0 - 0.5 * paint);
	rough = mix(rough, 0.14 + 0.1 * g2, wet * (1.0 - 0.6 * paint));
	rough = mix(rough, 0.06 - 0.04 * wx_wet, pud);
	// Pfuetze = Spiegel (Metall-Trick: Albedo wird zur Spiegelfarbe)
	float pm = smoothstep(0.25, 0.9, pud) * smoothstep(0.1, 0.5, wx_wet);
	col = mix(col, vec3(0.50, 0.54, 0.60), pm);
	metal = max(metal, 0.85 * pm);
	bump_h *= max(0.0, 1.0 - pud * 0.85 - 0.5 * wet);
	bump_h += wx_ripples(p, smoothstep(0.004, 0.015, px)) * (pud + 0.4 * wet);

	// --- Umland ausserhalb der Stadt ---
	float out_m = smoothstep(city_half - 2.0, city_half + 40.0, max(abs(p.x), abs(p.y)));
	vec3 terr = mix(vec3(0.07, 0.15, 0.04), vec3(0.14, 0.17, 0.06), blot2) * (0.8 + 0.5 * g3) * (0.8 + 0.4 * blot);
	col = mix(col, terr, out_m);
	rough = mix(rough, 0.95, out_m);
	metal = mix(metal, 0.0, out_m);
	wet *= 1.0 - out_m;

	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = mix(0.5, 1.0, wet);
	// Bump nur im Nahbereich (spart Flimmern in der Ferne)
	float bump_fade = 1.0 - smoothstep(0.03, 0.12, px);
	NORMAL = bump_normal(NORMAL, VERTEX, bump_h * bump_fade, 1.0);
}
