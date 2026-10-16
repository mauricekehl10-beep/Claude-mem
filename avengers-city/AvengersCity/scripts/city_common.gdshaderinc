// Gemeinsame Hilfsfunktionen fuer die Stadt-Shader (Rauschen, Abdeckung, Bump aus Ableitungen).

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

// Abdeckung eines Intervalls [lo, hi] an Stelle x bei Pixelbreite aa (analytisches Antialiasing)
float cov(float x, float lo, float hi, float aa) {
	return clamp((x - lo) / aa + 0.5, 0.0, 1.0) * clamp((hi - x) / aa + 0.5, 0.0, 1.0);
}

float rect_cov(vec2 q, vec2 lo, vec2 hi, vec2 aa) {
	return cov(q.x, lo.x, hi.x, aa.x) * cov(q.y, lo.y, hi.y, aa.y);
}

// Bump-Mapping ohne Tangenten: h = Hoehe in Metern an dieser Stelle, pos = Position im Sichtraum
vec3 bump_normal(vec3 n, vec3 pos, float h, float k) {
	vec3 dpx = dFdx(pos);
	vec3 dpy = dFdy(pos);
	float dhx = dFdx(h);
	float dhy = dFdy(h);
	vec3 r1 = cross(dpy, n);
	vec3 r2 = cross(n, dpx);
	float det = dot(dpx, r1);
	vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
	return normalize(abs(det) * n - k * grad);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
