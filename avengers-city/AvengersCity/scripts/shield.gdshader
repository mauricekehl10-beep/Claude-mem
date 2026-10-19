shader_type spatial;
// Schild von Captain America (Avengers-Look): roter Aussenring, weisser Ring, roter Ring, blaue Mitte mit weissem Stern.
// Matt-metallisch, leicht abgenutzt (Kratzer, Beulen, abgeplatzte Farbe am Rand). Gemalt nach der Lage
// auf der Scheibe (Ebene x/z des Meshes), Sternspitze nach -Z. Am Arm und im Flug sieht es gleich aus.

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

vec3 lin(vec3 c) {
	return pow(c, vec3(2.2));
}

float cov(float d, float w) {
	return clamp(0.5 - d / w, 0.0, 1.0);
}

float h3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float vn3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1.0, 0.0, 0.0)), f.x), mix(h3(i + vec3(0.0, 1.0, 0.0)), h3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(h3(i + vec3(0.0, 0.0, 1.0)), h3(i + vec3(1.0, 0.0, 1.0)), f.x), mix(h3(i + vec3(0.0, 1.0, 1.0)), h3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

float star5(vec2 p, float r, float rf) {
	vec2 k1 = vec2(0.809016994375, -0.587785252292);
	vec2 k2 = vec2(-k1.x, k1.y);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

// Höhe der Oberfläche (Meter) für Beulen
float relief(vec3 p) {
	return vn3(p * 22.0) * 0.0011 + vn3(p * 70.0) * 0.0005 + vn3(p * 230.0) * 0.00015;
}

void fragment() {
	float R = 0.31;
	vec2 q = vec2(lp.x, -lp.z) / R; // 1.0 = Rand
	float r = length(q);
	float w = max(length(fwidth(q)), 0.002);
	float wm = w * R; // Pixelgröße in Metern
	vec3 red = lin(vec3(0.58, 0.085, 0.10));
	vec3 white = lin(vec3(0.78, 0.77, 0.74));
	vec3 blue = lin(vec3(0.115, 0.19, 0.40));
	vec3 steel = lin(vec3(0.66, 0.67, 0.69));
	vec3 col = red;
	// Ringe: rot 1.0-0.74, weiss 0.74-0.545, rot 0.545-0.385, blau innen
	col = mix(col, white, cov(abs(r - 0.6425) - 0.0975, w));
	col = mix(col, blue, cov(r - 0.385, w));
	// Stern, Spitze zeigt nach -Z (nach oben im Bild q)
	float ds = star5(q, 0.372, 0.41);
	float st = cov(ds, w);
	col = mix(col, white, st);
	// Farbe leicht fleckig und ausgeblichen
	float n1 = vn3(lp * 18.0);
	float n2 = vn3(lp * 75.0);
	col *= 0.90 + 0.18 * n1 + 0.08 * (n2 - 0.5);
	// feine dunkle Trennlinien zwischen den Ringen
	float line = max(cov(abs(r - 0.74) - 0.005, w), max(cov(abs(r - 0.545) - 0.005, w), cov(abs(r - 0.385) - 0.005, w)));
	col = mix(col, vec3(0.012), line * 0.55);
	// Kratzer: feine, lange Striche in zwei Richtungen
	float fade = 1.0 - smoothstep(0.0015, 0.006, wm);
	col *= 0.95 + 0.10 * mix(0.5, vn3(vec3(r * 420.0, atan(q.y, q.x) * 1.5, 1.5)), fade); // Drehspuren (gebürstet)
	col = mix(col, steel * 0.9, smoothstep(0.965, 0.995, r) * 0.6);                       // Rand blank gescheuert
	float sc1 = smoothstep(0.80, 0.93, vn3(vec3(lp.x * 520.0 + lp.z * 160.0, lp.z * 22.0 - lp.x * 9.0, 0.5)));
	float sc2 = smoothstep(0.82, 0.94, vn3(vec3(lp.z * 480.0 - lp.x * 200.0, lp.x * 26.0 + lp.z * 10.0, 3.5)));
	float scratch = max(sc1, sc2) * fade;
	// abgeplatzte Farbe: am Rand und an wenigen Stellen in der Fläche, darunter blankes Metall
	float chip_n = vn3(lp * 150.0) * 0.6 + vn3(lp * 45.0) * 0.4;
	float chip = smoothstep(0.60, 0.70, chip_n) * (smoothstep(0.80, 0.97, r) * 0.95 + 0.07);
	// Dreck: dunkle Schlieren, vor allem am Rand
	float dirt = smoothstep(0.45, 0.85, vn3(lp * vec3(9.0, 4.0, 9.0) + 4.0)) * (0.35 + 0.65 * smoothstep(0.5, 1.0, r));
	col = mix(col, col * 0.55, dirt * 0.5);
	float bare = max(scratch * 0.55, chip);
	col = mix(col, steel * (0.8 + 0.3 * n2), bare);
	// Relief: Beulen, Ringkanten und Stern leicht erhaben
	float h = relief(lp) + 0.0018 * st + 0.0010 * cov(abs(r - 0.74) - 0.004, w);
	vec2 slope = vec2(dFdx(h), dFdy(h)) / max(length(fwidth(lp)), 0.0004);
	NORMAL = normalize(NORMAL - vec3(slope, 0.0) * 1.6);
	ALBEDO = col;
	METALLIC = mix(0.38, 0.95, bare);
	ROUGHNESS = mix(0.52 + 0.14 * n2, 0.34, bare);
	SPECULAR = 0.5;
}
