shader_type spatial;
#include "res://scripts/city_common.gdshaderinc"
// Wasser (Fluss, Teich): dunkle Tiefe, Wellen als Bump, spiegelt Himmel und Haeuser (Reflexionen kommen aus der Umgebung).

uniform sampler2D n_blotch : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D n_grain : repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec3 deep : source_color = vec3(0.045, 0.085, 0.10);
uniform vec3 shallow : source_color = vec3(0.10, 0.20, 0.20);
uniform float wave = 1.0;
uniform float speed = 1.0;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wp.xz;
	float dist = length(VERTEX);
	float t = TIME * speed;
	float h = texture(n_blotch, p * 0.021 + vec2(t * 0.010, t * 0.006)).r * 1.0;
	h += texture(n_blotch, p * 0.067 - vec2(t * 0.017, -t * 0.011)).r * 0.55;
	h += texture(n_grain, p * 0.31 + vec2(t * 0.03, -t * 0.02)).r * 0.14;
	h += texture(n_grain, p * 0.9 - vec2(t * 0.05, t * 0.04)).r * 0.04;
	float fade = 1.0 - smoothstep(40.0, 320.0, dist);
	NORMAL = bump_normal(NORMAL, VERTEX, h * 0.9 * wave * fade, 1.0);
	float sh = texture(n_blotch, p * 0.005 + vec2(0.3, 0.7)).r;
	vec3 col = mix(deep, shallow, smoothstep(0.35, 0.8, sh) * 0.7);
	ALBEDO = col;
	ROUGHNESS = mix(0.10, 0.04, fade * 0.5);
	METALLIC = 0.0;
	SPECULAR = 0.85;
}
