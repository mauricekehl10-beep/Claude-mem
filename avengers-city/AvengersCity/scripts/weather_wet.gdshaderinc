// Wetter fuer die Stadt-Shader: globale Werte (setzt scripts/weather.gd) und Regenringe auf nassem Boden.
// wx_wet = Naesse der Strassen 0..1, wx_rain = Regenstaerke 0..1, wx_night = 0 Tag .. 1 Nacht, wx_wind = Sturm 0..1.
global uniform float wx_wet;
global uniform float wx_rain;
global uniform float wx_night;
global uniform float wx_wind;

float wx_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Eine Schicht Regenringe: je Zelle ein Tropfen, der Ring waechst und verblasst. Ergebnis = Hoehe in Metern.
float wx_ring_layer(vec2 p, float cell, float t, float rate, float amount) {
	vec2 q = p / cell;
	vec2 id = floor(q);
	vec2 f = q - id;
	float h1 = wx_hash(id + 11.3);
	if (h1 > amount) {
		return 0.0;
	}
	vec2 c = vec2(0.32 + 0.36 * wx_hash(id + 3.1), 0.32 + 0.36 * wx_hash(id + 7.7));
	float ph = fract(t * rate * (0.75 + 0.5 * wx_hash(id + 5.5)) + wx_hash(id + 1.9) * 9.0);
	float r = ph * 0.30;
	float d = length(f - c);
	float x = (d - r) * cell;
	float env = exp(-pow(x / 0.022, 2.0)) * (1.0 - ph) * (1.0 - ph);
	return sin(x * 150.0) * env * 0.0016;
}

// Regenringe (Hoehe in Metern) an Weltposition p; far = 0..1 blendet in der Ferne aus
float wx_ripples(vec2 p, float far) {
	if (wx_rain < 0.02 || far > 0.99) {
		return 0.0;
	}
	float a = clamp(wx_rain * 1.1, 0.0, 1.0);
	float h = wx_ring_layer(p, 0.8, TIME, 1.5, a * 0.9);
	h += wx_ring_layer(p + vec2(17.3, 5.1), 1.3, TIME, 1.1, a * 0.9);
	return h * (1.0 - far);
}
