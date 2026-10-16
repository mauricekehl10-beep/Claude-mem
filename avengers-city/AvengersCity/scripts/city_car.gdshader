shader_type spatial;
// Kenney-Autos: Farbpalette-Textur, Lack wird per Farbton/Saettigung/Helligkeit umgefaerbt (Instanzdaten), Scheiben dunkel und glaenzend.

uniform sampler2D palette : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 tune = vec4(0.0, 1.0, 1.0, 0.0); // Hue-Shift, Saettigung, Helligkeit (wenn keine Instanzdaten genutzt werden)
uniform bool use_instance = true;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

varying vec3 v_tune;

void vertex() {
	v_tune = use_instance ? INSTANCE_CUSTOM.xyz : tune.xyz;
}

void fragment() {
	vec3 lin = texture(palette, UV).rgb;
	vec3 s = pow(lin, vec3(1.0 / 2.2));
	vec3 hsv = rgb2hsv(s);
	int cx = int(floor(UV.x * 16.0));
	int cy = int(floor(UV.y * 8.0));
	float is_win = (cx == 1 && cy >= 6) ? 1.0 : 0.0;
	float is_head = (cx == 3 && cy >= 6) ? 1.0 : 0.0;
	float is_tail = (cx == 5 && cy >= 6) ? 1.0 : 0.0;
	float lights = max(is_head, is_tail);
	float paint = smoothstep(0.30, 0.48, hsv.y) * step(0.40, hsv.z) * (1.0 - lights) * (1.0 - is_win);
	vec3 h2 = hsv;
	h2.x = fract(h2.x + v_tune.x);
	h2.y = clamp(h2.y * v_tune.y, 0.0, 1.0);
	h2.z = clamp(h2.z * v_tune.z, 0.0, 1.0);
	vec3 painted = pow(hsv2rgb(h2), vec3(2.2));
	vec3 albedo = mix(lin, painted, paint);
	albedo = mix(albedo, vec3(0.012, 0.02, 0.03), is_win);
	ALBEDO = albedo;
	float dark = 1.0 - smoothstep(0.1, 0.3, hsv.z);
	ROUGHNESS = mix(mix(0.55, 0.85, dark), 0.25, paint);
	ROUGHNESS = mix(ROUGHNESS, 0.04, is_win);
	METALLIC = paint * 0.45 + is_win * 0.3;
	SPECULAR = 0.5 + 0.4 * is_win;
	CLEARCOAT = paint;
	CLEARCOAT_ROUGHNESS = 0.06;
	EMISSION = lin * lights * 0.35;
}
