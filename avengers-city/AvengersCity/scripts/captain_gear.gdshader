shader_type spatial;
// Ausrüstung von Captain America (Leder, Metall, Stoff, Gurtband, Polster): matt, abgenutzt.
// Gemalt nach der Lage im Teil (VERTEX), damit die Muster am Knochen mitwandern.

uniform vec4 base : source_color = vec4(0.2, 0.12, 0.1, 1.0);
uniform vec4 worn : source_color = vec4(0.36, 0.25, 0.21, 1.0); // Farbe der abgeriebenen Stellen
uniform int kind = 0;       // 0 Leder, 1 Metall, 2 Stoff (Haube, Kragen), 3 Gurtband, 4 Polster/Platte
uniform float wear = 0.5;   // Stärke der Abnutzung

varying vec3 lp;

void vertex() {
	lp = VERTEX;
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

void fragment() {
	float w = max(length(fwidth(lp)), 0.0003);
	// Rauschen in drei Größen; wird bei groben Pixeln ausgeblendet (kein Flimmern)
	float n_big = vn3(lp * 38.0);
	float n_mid = vn3(lp * 150.0);
	float f_mid = 1.0 - smoothstep(0.004, 0.012, w);
	float n_fine = vn3(lp * 620.0);
	float f_fine = 1.0 - smoothstep(0.0012, 0.004, w);
	vec3 col = base.rgb;
	float met = 0.0;
	float rou = 0.6;
	float spec = 0.3;
	// abgeriebene Stellen: ungleichmässig, meist an den Kanten sichtbar
	float scuff = smoothstep(0.55, 0.85, n_big * 0.65 + n_mid * 0.35) * wear;
	if (kind == 0) {
		// Leder: Narbung, helle abgeriebene Flecken, dunkle Fettränder
		col *= 0.80 + 0.40 * mix(0.5, n_fine, f_fine) + 0.10 * (n_mid - 0.5) * f_mid;
		col = mix(col, worn.rgb, scuff * 0.8);
		col *= 1.0 - 0.25 * smoothstep(0.7, 0.2, n_big) * wear;
		rou = 0.52 + 0.25 * scuff;
		spec = 0.4;
	} else if (kind == 1) {
		// Metall: dunkles Stahl-Grau, Kratzer
		float sc = smoothstep(0.62, 0.9, vn3(lp * vec3(900.0, 60.0, 900.0)));
		col = mix(col, worn.rgb, scuff * 0.7 + sc * 0.4 * wear);
		col *= 0.85 + 0.3 * n_mid;
		met = 0.85;
		rou = 0.38 + 0.25 * scuff;
		spec = 0.5;
	} else if (kind == 2) {
		// Stoff: feines Gewebe
		float g = abs(fract(lp.x / 0.005 + lp.y / 0.005) - 0.5) + abs(fract(lp.x / 0.005 - lp.z / 0.005) - 0.5);
		col *= 1.0 + 0.16 * (g - 0.5) * (1.0 - smoothstep(0.002, 0.005, w)) + 0.12 * (n_big - 0.5);
		col = mix(col, worn.rgb, scuff * 0.35);
		rou = 0.82;
		spec = 0.22;
	} else if (kind == 3) {
		// Gurtband: Längsrippen, ausgeblichen
		float rib = 0.5 + 0.5 * sin((lp.x + lp.z * 0.7) * 700.0);
		col *= 0.88 + 0.16 * mix(0.5, rib, 1.0 - smoothstep(0.0015, 0.0045, w)) + 0.2 * (n_mid - 0.5) * f_mid;
		col = mix(col, worn.rgb, scuff * 0.5);
		rou = 0.78;
		spec = 0.22;
	} else {
		// Polster/Platte: hartes, mattes Material mit feinen Kratzern
		col *= 0.85 + 0.30 * (n_mid * f_mid + 0.5 * (1.0 - f_mid));
		col = mix(col, worn.rgb, scuff * 0.7);
		rou = 0.58 + 0.2 * scuff;
		spec = 0.4;
	}
	ALBEDO = col;
	METALLIC = met;
	ROUGHNESS = rou;
	SPECULAR = spec;
}
