shader_type spatial;
render_mode cull_disabled;
// Laub aus Karten: gemalte Blatt-Textur (Alpha-Test), Farbe aus Instanzfarbe x Karten-Farbe x Blatthelligkeit,
// weiche Kugel-Normalen, Wind (Baum wiegt, Blaetter flattern), Licht scheint durch die Blaetter (BACKLIGHT).

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float alpha_cut = 0.5;
uniform float trans = 0.55;
uniform float wind = 1.0;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 root = MODEL_MATRIX[3].xyz;
	float h = clamp(VERTEX.y * 0.11, 0.0, 1.0);
	float ph = root.x * 0.13 + root.z * 0.17;
	float sw = sin(TIME * 1.1 + ph) * 0.05 + sin(TIME * 2.3 + ph * 1.7 + w.y * 0.3) * 0.022;
	VERTEX.x += sw * h * h * wind;
	VERTEX.z += cos(TIME * 0.9 + ph * 1.3) * 0.035 * h * h * wind;
	float fl = sin(TIME * 3.4 + dot(VERTEX, vec3(2.9, 3.7, 3.3)) + ph * 2.0);
	VERTEX += NORMAL * fl * 0.018 * wind * (0.4 + h);
}

void fragment() {
	vec4 t = texture(leaf_tex, UV);
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ALBEDO = COLOR.rgb * t.rgb * 1.5;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ROUGHNESS = 0.72;
	SPECULAR = 0.28;
	BACKLIGHT = ALBEDO * trans;
}
