shader_type spatial;
render_mode cull_disabled, alpha_to_coverage;
// Haar: Strähnen-Bänder (UV.x quer, UV.y entlang 0 Wurzel .. 1 Spitze, COLOR = Strähnenfarbe, TANGENT = Haarrichtung).
// Weiches Wiegen, Licht durch die Haare und Glanz wie bei echtem Haar (zwei Lichtstreifen quer zur Strähne, Kajiya-Kay).

uniform float sway = 1.0;

varying vec3 tang;

void vertex() {
	float s = UV.y;
	VERTEX.x += sin(TIME * 1.5 + VERTEX.y * 17.0 + VERTEX.z * 9.0) * 0.0022 * s * s * sway;
	VERTEX.z += cos(TIME * 1.2 + VERTEX.x * 21.0) * 0.0018 * s * s * sway;
	tang = normalize((MODELVIEW_MATRIX * vec4(TANGENT, 0.0)).xyz);
}

void fragment() {
	float u = UV.x;
	float s = UV.y;
	float edge = 1.0 - abs(u * 2.0 - 1.0);
	float strands = 0.5 + 0.5 * sin(u * 52.0 + COLOR.r * 70.0) * sin(u * 23.0 + COLOR.g * 40.0);
	float tipcut = smoothstep(0.35, 1.0, s);
	ALPHA = smoothstep(0.0, 0.45, edge) * (1.0 - smoothstep(0.85, 1.0, s)) * mix(1.0, smoothstep(0.1, 0.55, strands + (1.0 - tipcut) * 0.5), tipcut);
	// feine Haarlinien entlang der Strähne, Wurzel dunkler, Spitzen heller
	float line = 0.80 + 0.20 * sin(u * 46.0 + COLOR.r * 90.0) + 0.08 * sin(u * 113.0 + s * 3.0);
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	float tone = mix(0.50, 1.15, smoothstep(0.0, 0.40, s)) * mix(1.0, 1.08, s);
	ALBEDO = base * tone * line;
	ROUGHNESS = 0.5;
	SPECULAR = 0.0;
	METALLIC = 0.0;
	BACKLIGHT = ALBEDO * 0.55;
	RIM = 0.15;
	RIM_TINT = 0.7;
}

void light() {
	vec3 N = normalize(NORMAL);
	float ndl = dot(N, LIGHT);
	// weiches, um die Strähne gewickeltes Licht (ein Haarband ist dünn und rund)
	float wrap = clamp(ndl * 0.62 + 0.38, 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * wrap / PI;
	// Durchscheinen: von hinten beleuchtetes Haar leuchtet
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * BACKLIGHT * clamp(-ndl, 0.0, 1.0) / PI;
	// Glanz: Lichtstreifen quer zur Haarrichtung
	vec3 T = normalize(tang);
	vec3 H = normalize(LIGHT + VIEW);
	float dt = dot(T, H);
	float st = sqrt(max(1.0 - dt * dt, 0.0));
	float vary = 0.65 + 0.35 * sin(UV.x * 61.0 + UV.y * 5.0);
	float sharp = pow(st, 260.0);
	float broad = pow(st, 60.0);
	vec3 sp = (sharp * vec3(1.0, 0.96, 0.88) * 0.55 * vary + broad * ALBEDO * 0.22) * LIGHT_COLOR * ATTENUATION;
	SPECULAR_LIGHT += sp * smoothstep(0.0, 0.4, ndl) / PI;
}
