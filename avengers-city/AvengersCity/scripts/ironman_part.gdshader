shader_type spatial;
// Panzerteile von Iron Man (Netze aus ironman_suit.gd). Das Netz liegt in Ruhepose-Koordinaten;
// UV = Lage auf der Platte, CUSTOM0 = (Länge u, Länge v, Stoff + 100 * Zierlinie, Zufallsstart).

varying vec3 rp;
varying vec4 cu;

#include "res://scripts/ironman_suit.gdshaderinc"

void vertex() {
	rp = VERTEX;
	cu = CUSTOM0;
}

void fragment() {
	vec3 p = rp;
	float w = max(length(fwidth(p)), 0.0004);
	float tr = floor((cu.z + 0.5) / 100.0);
	int id = int(cu.z + 0.5 - tr * 100.0);
	float ed = min(min(UV.x, 1.0 - UV.x) * cu.x, min(UV.y, 1.0 - UV.y) * cu.y);
	vec3 col;
	float met;
	float rou;
	vec3 emi;
	float hgt;
	im_mat(id, int(tr + 0.5), p, w, ed, cu.w, col, met, rou, emi, hgt);
	if (id == 7) {
		im_face(p, w, col, met, rou, emi, hgt);
	} else if (id == 8) {
		im_helm(p, w, col, met, rou, emi, hgt);
	}
	if (id == 5) {
		float c = clamp(UV.y, 0.0, 1.0);
		float seg = step(0.5, fract(UV.x * 10.0));
		float zone = smoothstep(0.25, 0.4, c) * (1.0 - smoothstep(0.62, 0.78, c));
		float k = mix(1.0, 0.45 + 0.55 * seg, zone);
		emi = mix(vec3(0.30, 0.62, 1.0), vec3(0.95, 1.0, 1.0), smoothstep(0.55, 1.0, c)) * (1.6 + 1.8 * c) * k;
		col = vec3(0.7, 0.9, 1.0);
	}
	if (id == 6) {
		vec2 cell;
		float hd = im_hex(p.xy * 90.0, cell);
		float line = 1.0 - smoothstep(0.0, 0.07 + w * 90.0, hd);
		float pit = smoothstep(0.0, 0.25, hd);
		col = mix(im_lin(vec3(0.42, 0.43, 0.47)) * (0.7 + 0.5 * fract(sin(dot(cell, vec2(12.9, 78.2))) * 43758.5)), im_lin(vec3(0.02, 0.02, 0.025)), line);
		met = 0.9;
		rou = mix(0.45, 0.3, pit);
		hgt = -line * 0.0015;
	}
	vec2 slope = vec2(dFdx(hgt), dFdy(hgt)) / w;
	NORMAL = normalize(NORMAL - vec3(slope, 0.0) * 2.0);
	ALBEDO = col;
	METALLIC = met;
	ROUGHNESS = rou;
	SPECULAR = 0.4;
	EMISSION = emi;
	CLEARCOAT = smoothstep(0.5, 0.3, rou);
	CLEARCOAT_ROUGHNESS = 0.07;
}
