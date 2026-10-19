shader_type spatial;
// Anzug von Captain America. Gemalt wird nach der Position in der Ruhepose (T-Pose, Meter, Füsse bei y=0,
// +Z vorn, +X links); sie steckt in CUSTOM0 und bewegt sich mit dem Skelett. Das Netz trägt in COLOR.r eine
// Verdeckung (Achseln, Innenseiten, Falten), die Malerei steht in captain_suit.gdshaderinc.

uniform bool joint = false; // true = Gelenk-Fläche (dunkler Unterbau)

varying vec3 rp;
varying float vao;

void vertex() {
	rp = CUSTOM0.xyz;
	vao = COLOR.r;
}

vec3 lin(vec3 c) {
	return pow(c, vec3(2.2));
}

// Deckung einer Form: d = Abstand zum Rand (negativ innen), w = Pixelgröße in Metern
float cov(float d, float w) {
	return clamp(0.5 - d / w, 0.0, 1.0);
}

float box2(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

// Linie bei v == at mit halber Dicke hw
float ln(float v, float at, float hw, float w) {
	return cov(abs(v - at) - hw, w);
}

// Fünfzackiger Stern, Spitze nach oben
float star5(vec2 p, float r, float rf) {
	vec2 k1 = vec2(0.809016994375, -0.587785252292);
	vec2 k2 = vec2(-k1.x, k1.y);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

#include "res://scripts/hero_face.gdshaderinc"
#include "res://scripts/captain_suit.gdshaderinc"

void fragment() {
	vec3 p = rp;
	float w = max(length(fwidth(p)), 0.0004);
	vec3 col;
	float met;
	float rou;
	vec3 emi;
	float hgt;
	float ao = 1.0;
	float rim = 0.0;
	cap2(p, w, col, met, rou, emi, hgt, ao, rim);
	if (joint) {
		col *= 0.6;
		emi = vec3(0.0);
		hgt = 0.0;
	}
	ao *= mix(1.0, vao, 0.95);
	// Relief: Höhe nach Bildschirm-Gefälle in die Normale kippen (Kanten fangen Licht)
	vec2 slope = vec2(dFdx(hgt), dFdy(hgt)) / w;
	NORMAL = normalize(NORMAL - vec3(slope, 0.0) * 2.4);
	ALBEDO = col * mix(1.0, ao, 0.65);
	AO = ao;
	AO_LIGHT_AFFECT = 0.5;
	METALLIC = met;
	ROUGHNESS = rou;
	SPECULAR = 0.3 + 0.15 * met;
	RIM = rim;
	RIM_TINT = 0.6;
	EMISSION = emi;
}
