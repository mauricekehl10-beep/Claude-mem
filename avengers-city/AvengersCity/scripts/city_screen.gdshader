shader_type spatial;
render_mode cull_disabled;
#include "res://scripts/city_common.gdshaderinc"
// LED-Werbeflaeche (Times Square): animierte Muster aus Farbverlaeufen, Balken, Lauftext und Blitzen.
// UV = 0..1 ueber die Flaeche, UV2 = Groesse in Metern, COLOR.rgb = Grundfarbe, COLOR.a = Muster/Zufall.

uniform float energy = 2.2;

varying vec2 v_uv;
varying vec2 v_sz;
varying vec4 v_col;

void vertex() {
	v_uv = UV;
	v_sz = UV2;
	v_col = COLOR;
}

vec3 pal(float t) {
	return 0.5 + 0.5 * cos(6.28318 * (t + vec3(0.0, 0.33, 0.67)));
}

// Inhalt an Stelle u (0..1 x 0..1), Zeit t
vec3 content(vec2 u, vec2 sz, float t, float seed, vec3 base) {
	float kind = floor(seed * 5.0);
	float s2 = fract(seed * 5.0);
	vec2 m = u * sz;
	vec3 c = vec3(0.0);
	if (kind < 1.0) {
		// Werbeplakat: Farbverlauf, laufendes Lichtband, grosse Figur
		c = mix(base, pal(s2 + u.y * 0.35 + t * 0.03), 0.55) * (0.55 + 0.45 * u.y);
		float band = smoothstep(0.12, 0.0, abs(fract(u.x * 0.6 - u.y * 0.4 - t * 0.12) - 0.5));
		c += vec3(1.0, 0.95, 0.85) * band * 0.35;
		vec2 q = (u - vec2(0.5 + 0.1 * sin(t * 0.7 + s2 * 6.0), 0.5)) * vec2(sz.x / sz.y, 1.0);
		float d = length(q) - (0.28 + 0.04 * sin(t * 2.0));
		c = mix(c, vec3(1.0, 0.97, 0.9), smoothstep(0.02, 0.0, d));
		c = mix(c, base * 0.3, smoothstep(0.02, 0.0, abs(d + 0.07) - 0.012));
	} else if (kind < 2.0) {
		// Laufschrift: dunkler Grund, Zeilen aus kleinen hellen Bloecken, die nach links wandern
		c = base * 0.12;
		float rows = max(2.0, floor(sz.y / 1.3));
		float ry = u.y * rows;
		float rid = floor(ry);
		float rf = fract(ry);
		float speed = 0.6 + 1.4 * hash11(rid + seed * 31.0);
		float x = m.x * 1.7 + t * speed * (mod(rid, 2.0) * 2.0 - 1.0) + rid * 7.0;
		float cid = floor(x / 1.0);
		float cf = fract(x / 1.0);
		float on = step(0.35, hash21(vec2(cid, rid + seed * 13.0))) * step(0.12, rf) * step(rf, 0.7) * step(0.1, cf) * step(cf, 0.8);
		vec3 tc = mix(vec3(1.0, 0.85, 0.25), pal(seed * 3.0 + rid * 0.17), 0.5 + 0.5 * step(0.5, hash11(rid)));
		c = mix(c, tc, on);
		c += base * smoothstep(0.08, 0.0, abs(rf - 0.9)) * 0.5;
	} else if (kind < 3.0) {
		// Plasma / Video
		float v = sin(m.x * 0.9 + t * 1.3) + sin(m.y * 1.1 - t) + sin((m.x + m.y) * 0.6 + t * 0.7) + sin(length(m - sz * 0.5) * 0.9 - t * 1.6);
		c = pal(v * 0.18 + s2 + t * 0.05) * (0.6 + 0.4 * sin(v * 2.0));
		c = mix(c, base, 0.25);
	} else if (kind < 4.0) {
		// Schlussverkauf: schraege Balken in Gelb/Rot, blinkende Mitte
		float st = fract((m.x + m.y) * 0.25 - t * 0.35);
		c = mix(vec3(0.95, 0.12, 0.08), vec3(1.0, 0.85, 0.1), step(0.5, st));
		float blink = step(0.5, fract(t * 1.2 + s2));
		vec2 q = abs(u - 0.5) * vec2(sz.x / sz.y, 1.0);
		float box = step(max(q.x, q.y), 0.25);
		c = mix(c, mix(vec3(0.02), vec3(1.0), blink), box);
	} else {
		// Logo-Blitz: Farbblock wechselt, weisse Raute
		float ph = floor(t * 0.5 + s2 * 8.0);
		vec3 bg = pal(hash11(ph + seed * 7.0));
		c = bg * (0.5 + 0.5 * u.y);
		vec2 q = abs(u - 0.5) * vec2(sz.x / sz.y, 1.0);
		float dia = step(q.x + q.y, 0.3 + 0.05 * sin(t * 3.0));
		c = mix(c, vec3(1.0), dia);
		c = mix(c, bg * 0.4, step(q.x + q.y, 0.18) * dia);
	}
	return c;
}

void fragment() {
	vec2 m = v_uv * v_sz;
	float cell = 0.16;
	vec2 cid = floor(m / cell);
	vec2 cf = fract(m / cell);
	vec2 uq = (cid + 0.5) * cell / v_sz;
	vec3 c = content(uq, v_sz, TIME, v_col.a, v_col.rgb);
	// LED-Punkte nur aus der Naehe
	float px = max(length(dFdx(m)), length(dFdy(m))) / cell;
	vec2 dd = abs(cf - 0.5) * 2.0;
	float led = 1.0 - smoothstep(0.75, 1.0, max(dd.x, dd.y));
	led = mix(led, 0.8, smoothstep(0.15, 0.5, px));
	c *= led;
	ALBEDO = c * 0.05;
	EMISSION = c * energy;
	ROUGHNESS = 0.4;
	SPECULAR = 0.4;
}
