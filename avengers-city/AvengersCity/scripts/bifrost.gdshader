shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
// Bifrost: Strahl aus dem Himmel (offener Zylinder, Radius 1). Senkrechte Streifen in blassem Regenbogen (rosa, gelb, grün, cyan),
// die nach oben wandern, innen weiss. reveal: der Strahl schlägt von oben nach unten ein (0 -> 1). fade: Gesamthelligkeit.

uniform float reveal = 1.0;
uniform float fade = 1.0;
uniform float height = 160.0;
uniform float energy = 1.5;
uniform float whiten = 0.0; // 1 = innerer Kern (fast weiss)

varying vec3 lp;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec3 hsv(float h, float s, float v) {
	vec3 k = clamp(abs(fract(vec3(h) + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	return v * mix(vec3(1.0), k, s);
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float hn = lp.y / height + 0.5; // 0 = Boden, 1 = Spitze
	float ang = atan(lp.z, lp.x) / 6.2831853 + 0.5;
	float up = hn * height;
	float s1 = vn(vec2(ang * 22.0, up * 0.05 - TIME * 4.0));
	float s2 = vn(vec2(ang * 47.0 + 5.0, up * 0.11 - TIME * 7.5));
	float s3 = vn(vec2(ang * 9.0 + 2.0, up * 0.02 - TIME * 1.6));
	float streak = 0.30 + 0.70 * (0.45 * s1 + 0.35 * s2 + 0.20 * s3);
	float hue = fract(ang * 2.0 + s3 * 0.6 - TIME * 0.05);
	vec3 col = mix(vec3(1.0), hsv(hue, 1.0, 1.0), 0.85 * (1.0 - whiten));
	col = mix(col, vec3(1.0, 0.96, 1.0), 0.10 + 0.6 * whiten);
	// volumetrisch: dort hell, wo man durch die dickste Stelle schaut
	float ndv = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float vol = pow(ndv, 0.75);
	// Einschlag: sichtbar nur unterhalb der Front, die Front selbst blitzt
	float front = 1.0 - reveal;
	float vis = smoothstep(front - 0.03, front, hn);
	float flash = exp(-pow((hn - front) * height * 0.06, 2.0)) * (1.0 - step(0.999, reveal));
	// oben auslaufen, unten am Boden etwas heller
	float top = 1.0 - smoothstep(0.55, 1.0, hn);
	float base = 1.0 + 0.5 * exp(-up * 0.12);
	float b = (streak * vol * top * base + flash * 0.7 * vol) * vis;
	ALBEDO = col * energy * b * fade * 0.55;
	ALPHA = clamp(b * fade * 0.8, 0.0, 1.0);
}
