shader_type spatial;
// Schild von Captain America: rot, weiss, rot, blau mit weissem Stern. Gemalt nach der Lage
// auf der Scheibe (Ebene x/z des Meshes), Sternspitze nach -Z.

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

vec3 lin(vec3 c) {
	return pow(c, vec3(2.2));
}

float cov(float d, float w) {
	return clamp(0.5 - d / w, 0.0, 1.0);
}

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

void fragment() {
	vec2 q = vec2(lp.x, -lp.z) / 0.31; // 1.0 = Rand
	float r = length(q);
	float w = max(length(fwidth(q)), 0.002);
	vec3 red = lin(vec3(0.80, 0.07, 0.10));
	vec3 white = lin(vec3(0.93, 0.93, 0.95));
	vec3 blue = lin(vec3(0.07, 0.17, 0.55));
	vec3 col = red;
	col = mix(col, white, cov(abs(r - 0.66) - 0.07, w));        // weisser Ring
	col = mix(col, blue, cov(r - 0.46, w));                      // blaue Mitte
	col = mix(col, white, cov(star5(q, 0.44, 0.40), w));         // Stern
	// feine dunkle Trennlinien zwischen den Ringen
	float line = max(cov(abs(r - 0.73) - 0.006, w), max(cov(abs(r - 0.59) - 0.006, w), cov(abs(r - 0.46) - 0.006, w)));
	col = mix(col, vec3(0.02), line * 0.5);
	ALBEDO = col;
	METALLIC = 0.55;
	ROUGHNESS = 0.3;
}
