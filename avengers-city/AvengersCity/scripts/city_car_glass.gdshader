shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;
// Autoscheiben: leicht getoent, durchscheinend, spiegelnd (Fresnel macht sie zum Rand hin undurchsichtiger).

void vertex() {
}

void fragment() {
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 3.0);
	float dark = COLOR.r;
	ALBEDO = vec3(0.012, 0.02, 0.026);
	ROUGHNESS = 0.02;
	METALLIC = 0.25;
	SPECULAR = 0.95;
	ALPHA = clamp(mix(0.40 + dark * 0.42, 1.0, fres), 0.0, 1.0);
}
