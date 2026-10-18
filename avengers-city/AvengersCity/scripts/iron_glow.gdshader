shader_type spatial;
// Leuchtfleck an der Düse (Billboard): heller Kern mit weichem Hof und flackernden Strahlen.
// Deckend gemischt statt addiert, damit helle Hintergründe nicht über die Bloom-Schwelle springen.
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(1.0, 0.8, 0.5);
uniform float energy = 1.0;
uniform float seed = 0.0;
uniform float star = 0.35;

void vertex() {
	// Billboard: Quad zur Kamera drehen, Grösse aus der Skalierung
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), 1.0);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(sc.x, 0.0, 0.0, 0.0), vec4(0.0, sc.y, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float core = exp(-r * r * 9.0);
	float halo = exp(-r * 3.2) * 0.45;
	float ang = atan(p.y, p.x);
	float rays = pow(abs(sin(ang * 3.0 + TIME * 3.0 + seed)), 6.0) * exp(-r * 4.0) * star;
	float fl = 0.92 + 0.08 * sin(TIME * 52.0 + seed * 2.0);
	float edge = smoothstep(1.0, 0.7, r);
	float a = clamp((core * 1.2 + halo + rays) * edge * fl * energy, 0.0, 1.0);
	ALBEDO = tint * a;
	ALPHA = a * 0.85;
}
