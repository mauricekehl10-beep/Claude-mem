shader_type spatial;
// Ampellinsen: leuchten nach der Ampelphase (gleiche Rechnung wie CityTraffic.signal_state, Uhr = globaler Wert sig_clock).
// UV2.x = Lampe (0 rot, 1 gelb, 2 gruen), UV2.y = Achse des Verkehrs (0 = x, 1 = z), COLOR = Linsenfarbe.
global uniform float sig_clock;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float a = floor((wp.x - 36.0) / 72.0 + 0.5);
	float b = floor((wp.z - 36.0) / 72.0 + 0.5);
	float p = mod(a + b + 1.0, 2.0);
	float zc = mod(sig_clock + 12.0 * p, 24.0);
	float c = UV2.y > 0.5 ? zc : mod(zc + 12.0, 24.0);
	float st = c < 9.0 ? 0.0 : (c < 11.0 ? 1.0 : 2.0);
	float k = UV2.x;
	float lit = 0.0;
	if (k > 1.5) {
		lit = st < 0.5 ? 1.0 : 0.0;
	} else if (k > 0.5) {
		lit = (st > 0.5 && st < 1.5) ? 1.0 : 0.0;
	} else {
		lit = st > 1.5 ? 1.0 : 0.0;
	}
	vec3 col = pow(COLOR.rgb, vec3(2.2));
	ALBEDO = col * mix(0.05, 0.4, lit);
	ROUGHNESS = 0.25;
	EMISSION = col * lit * 7.0;
}
