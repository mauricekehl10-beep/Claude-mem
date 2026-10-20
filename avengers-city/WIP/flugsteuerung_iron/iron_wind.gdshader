shader_type canvas_item;
// Windlinien am Bildrand: dünne Striche laufen vom Bildrand nach aussen (Gefühl von Tempo).
// inten 0..1 = wie viele Striche und wie hell; tm = Zeit; shift = Fluchtpunkt (Bildmitte plus Flugrichtung)

uniform float inten : hint_range(0.0, 1.0) = 0.0;
uniform float tm = 0.0;
uniform vec2 shift = vec2(0.0);
uniform vec2 asp = vec2(1.78, 1.0);
uniform vec4 tint : source_color = vec4(0.86, 0.93, 1.0, 1.0);

float h11(float n) {
	return fract(sin(n * 127.1 + 31.7) * 43758.5453);
}

void fragment() {
	vec2 p = (UV - 0.5 - shift) * vec2(asp.x, 1.0);
	float r = length(p);
	float ang = atan(p.y, p.x) / 6.2831853 + 0.5;
	float a = 0.0;
	for (int layer = 0; layer < 3; layer++) {
		float n = layer == 0 ? 56.0 : (layer == 1 ? 97.0 : 151.0);
		float x = ang * n;
		float id = floor(x) + float(layer) * 211.0;
		float fx = abs(fract(x) - 0.5);
		float r1 = h11(id);
		float r2 = h11(id + 17.3);
		float r3 = h11(id + 53.9);
		// nur ein Teil der Striche ist da, je nach Tempo
		float live = step(r1, inten * 0.85 + 0.05);
		float wdt = 0.07 + 0.08 * r2;
		float line = 1.0 - smoothstep(wdt * 0.5, wdt, fx);
		// jeder Strich wandert nach aussen (Kopf vorn, Schweif hinten)
		float spd = 0.9 + 1.6 * r3 + 1.2 * inten;
		float head = 0.20 + fract(r2 * 5.7 + tm * spd) * 1.1;
		float len = 0.10 + 0.34 * r1 * inten;
		float seg = smoothstep(head - len, head, r) * (1.0 - smoothstep(head, head + 0.015, r));
		a += line * seg * live * (0.55 + 0.45 * r2);
	}
	float edge = smoothstep(0.22, 0.62, r);
	a = clamp(a, 0.0, 1.0) * edge * clamp(inten * 1.3, 0.0, 1.0) * 0.8;
	COLOR = vec4(tint.rgb, a);
}
