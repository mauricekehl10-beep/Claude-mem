shader_type spatial;
// Passanten (Mixamo-Figur): Hose, Oberteil, Haut und Schuhe nach Hoehe im Modell gefaerbt.

uniform vec3 shirt : source_color = vec3(0.6, 0.1, 0.1);
uniform vec3 pants : source_color = vec3(0.1, 0.12, 0.2);
uniform vec3 skin : source_color = vec3(0.8, 0.6, 0.45);
uniform vec3 shoes : source_color = vec3(0.05, 0.05, 0.05);
uniform float base_y = 0.0;
uniform float body_h = 1.8;

varying float ly;

void vertex() {
	ly = (VERTEX.y - base_y) / body_h;
}

void fragment() {
	vec3 c = pants;
	c = mix(c, shirt, smoothstep(0.47, 0.50, ly));
	c = mix(c, skin, smoothstep(0.83, 0.85, ly));
	c = mix(c, shoes, 1.0 - smoothstep(0.03, 0.05, ly));
	ALBEDO = c;
	ROUGHNESS = 0.85;
	SPECULAR = 0.3;
}
