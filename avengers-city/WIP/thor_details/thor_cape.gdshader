shader_type spatial;
render_mode cull_disabled;
// Umhang von Thor: dicker roter Samt aussen, dunkleres Futter innen, gesäumter Rand mit Naht, Falten und Fasern.
// UV.x = quer (0..1), UV.y = entlang (0 Schulter .. 1 Saum), COLOR.r = Verschattung in den Falten.

uniform vec4 outer_col : source_color = vec4(0.47, 0.018, 0.035, 1.0);
uniform vec4 inner_col : source_color = vec4(0.30, 0.012, 0.030, 1.0);
uniform bool flip_side = false;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float w = max(length(fwidth(VERTEX)), 0.0002);
	float u = UV.x;
	float v = UV.y;
	bool outside = FRONT_FACING != flip_side;
	// Falten und Knitter als weiches Höhenfeld
	float wr = 0.5 + 0.5 * sin(u * 23.0 + v * 4.0 + sin(v * 9.0 + u * 5.0) * 1.2);
	float wr2 = 0.5 + 0.5 * sin(u * 71.0 - v * 8.0 + sin(v * 31.0 + u * 13.0) * 2.0);
	float fib = vn(vec2(u * 260.0, v * 180.0));
	float fade = 1.0 - smoothstep(0.004, 0.012, w);
	// Gewebe: feine Kreuzung aus Kette und Schuss
	float weave = 0.5 + 0.5 * sin(u * 900.0) * sin(v * 620.0);
	float hgt = (wr - 0.5) * 0.010 + (wr2 - 0.5) * 0.0015 * fade + (weave - 0.5) * 0.00012 * fade;
	// Saum: Rand rundum umgeschlagen (dicker, etwas dunkler) mit Naht
	float edge = min(min(u, 1.0 - u), 1.0 - v);
	float hem = 1.0 - smoothstep(0.006, 0.026, edge);
	float seam = smoothstep(0.0, 0.0022, abs(edge - 0.028));
	float stitch = (1.0 - seam) * smoothstep(0.3, 0.7, fract((u + v) * 190.0));
	float hemline = smoothstep(0.0, 0.004, edge) * (1.0 - smoothstep(0.004, 0.009, edge));
	hgt += hem * 0.004 + hemline * 0.0018 - (1.0 - seam) * 0.0008;
	vec3 col = outside ? outer_col.rgb : inner_col.rgb;
	float ao = COLOR.r;
	col *= (0.90 + 0.18 * mix(0.5, fib, fade)) * (0.84 + 0.28 * wr) * (0.94 + 0.12 * weave);
	col *= 1.0 - 0.30 * hemline;
	col = mix(col, col * vec3(0.78, 0.7, 0.7), hem * 0.55);
	col = mix(col, col * 1.45 + vec3(0.03, 0.0, 0.0), stitch * 0.7 * step(0.003, edge));
	col *= ao;
	float rou = outside ? 0.90 : 0.50;
	vec2 slope = vec2(dFdx(hgt), dFdy(hgt)) / w;
	slope *= min(1.0, 0.8 / max(length(slope), 0.0001));
	NORMAL = normalize(NORMAL - vec3(slope, 0.0) * 1.2);
	ALBEDO = col;
	METALLIC = 0.0;
	ROUGHNESS = rou;
	SPECULAR = outside ? 0.25 : 0.55;
	RIM = outside ? 0.50 : 0.25;
	RIM_TINT = 0.55;
	BACKLIGHT = col * 0.35;
}
