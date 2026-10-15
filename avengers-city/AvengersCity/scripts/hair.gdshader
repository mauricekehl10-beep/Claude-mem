shader_type spatial;
// Haare: Strähnen als Streifen entlang der Längsachse des Teils (Mesh-Y).

uniform vec3 base : source_color = vec3(0.86, 0.66, 0.26);

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float a = atan(lp.x, lp.z);
	float s = sin(a * 14.0 + lp.y * 5.0) * 0.5 + 0.5;
	float s2 = sin(a * 37.0 - lp.y * 9.0) * 0.5 + 0.5;
	float k = 0.62 + 0.34 * s + 0.12 * s2;
	ALBEDO = base * k;
	ROUGHNESS = 0.45;
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
