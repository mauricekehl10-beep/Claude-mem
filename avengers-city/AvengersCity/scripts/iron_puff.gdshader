shader_type spatial;
// Teilchen für Düsen und Staub (iron_fx.gd): Billboard, weicher Kreis ohne Textur, Farbe und Alpha aus der Teilchenfarbe.
// add = 1: addiert (Funken, leuchtet), add = 0: normal gemischt (Dampf, Staub).
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float add = 0.0;
uniform float energy = 1.0;
uniform float hard = 0.3;

void vertex() {
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sx, INV_VIEW_MATRIX[1] * sy, INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float f = 1.0 - smoothstep(hard * 0.8, 1.0, r);
	f *= f;
	float a = clamp(COLOR.a * f, 0.0, 1.0);
	ALBEDO = COLOR.rgb * energy * a;
	ALPHA = a * (1.0 - add);
}
