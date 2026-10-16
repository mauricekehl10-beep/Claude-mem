shader_type spatial;
#include "res://scripts/city_common.gdshaderinc"
// Gehweg (Betonplatten mit Fugen, Granit-Bordstein) fuer die erhoehten Blockflaechen.

uniform sampler2D n_blotch : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D n_grain : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D n_crack : repeat_enable, filter_linear_mipmap_anisotropic;

const float STEP = 72.0;
const float CR = 3.5;
const float PH = 30.0;
const float KH = 0.15;

varying vec3 wp;
varying vec3 wn;

float sd_pad(vec2 p) {
	vec2 b = p - STEP * round(p / STEP);
	vec2 q = abs(b) - vec2(PH - CR);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - CR;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = wp.xz;
	float px = max(max(length(dFdx(p)), length(dFdy(p))), 0.003);
	float sd = sd_pad(p);
	float blot = texture(n_blotch, p * 0.0151 + vec2(0.4, 0.2)).r;
	float blot2 = texture(n_blotch, p * 0.057).r;
	float g1 = texture(n_grain, p * 0.7).r;
	float g2 = texture(n_grain, p * 2.3 + vec2(0.33, 0.71)).r;
	vec3 col;
	float rough;
	float bh = 0.0;
	if (wn.y > 0.5) {
		// Platten
		vec2 b = p - STEP * round(p / STEP) + PH;
		vec2 sc = b / 1.5;
		vec2 sid = floor(sc);
		vec2 sf = fract(sc);
		float sh = hash21(sid + floor(p / STEP + 0.5) * 17.0);
		float jd = min(min(sf.x, 1.0 - sf.x), min(sf.y, 1.0 - sf.y)) * 1.5;
		float joint = 1.0 - smoothstep(0.007, 0.007 + px, jd);
		col = vec3(0.50, 0.49, 0.47);
		col *= 0.94 + 0.12 * sh;
		col *= 0.88 + 0.26 * blot;
		col *= 0.90 + 0.20 * blot2;
		col *= 0.88 + 0.24 * g1;
		// feine Koernung und Flecken
		col = mix(col, col * 0.55, smoothstep(0.62, 0.9, g2) * 0.35);
		// Risse
		float crk = texture(n_crack, p * 0.09).r;
		float cm = smoothstep(0.5, 0.75, blot) * (1.0 - smoothstep(0.0, 0.03 + px * 0.5, crk));
		col *= 1.0 - 0.45 * cm;
		// Schmutz am Bordstein und an der Hauswand
		float grime = (1.0 - smoothstep(0.0, 0.9, -sd)) * 0.25 + smoothstep(0.8, 3.8, -sd) * 0.2;
		col *= 1.0 - grime;
		// Granit-Bordsteinkante oben
		float curb = cov(-sd, 0.0, 0.20, px);
		vec3 gran = vec3(0.58, 0.58, 0.57) * (0.88 + 0.22 * g1);
		col = mix(col, gran, curb);
		float cj = abs(fract((mix(p.y, p.x, step(abs(p.x - STEP * round(p.x / STEP)), abs(p.y - STEP * round(p.y / STEP)))) + 0.3) / 2.2) - 0.5) * 2.2;
		col *= 1.0 - 0.35 * curb * (1.0 - smoothstep(0.01, 0.01 + px, abs(cj - 1.1)));
		col *= 1.0 - 0.28 * joint * (1.0 - curb);
		rough = mix(0.88, 0.7, curb);
		bh = g1 * 0.0012 + g2 * 0.0006 - joint * 0.0035 * (1.0 - curb);
	} else {
		// Bordsteinflanke
		float t = clamp(wp.y / KH, 0.0, 1.0);
		col = vec3(0.45, 0.45, 0.44) * (0.85 + 0.3 * g1);
		col *= 0.55 + 0.45 * t;
		col *= 0.85 + 0.3 * blot2;
		rough = 0.78;
		bh = g1 * 0.0012;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.45;
	float bump_fade = 1.0 - smoothstep(0.03, 0.12, px);
	NORMAL = bump_normal(NORMAL, VERTEX, bh * bump_fade, 1.0);
}
