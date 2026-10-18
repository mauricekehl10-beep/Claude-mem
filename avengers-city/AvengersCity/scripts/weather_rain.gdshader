shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
#include "res://scripts/weather_wet.gdshaderinc"
// Regen ohne Teilchen-Simulation: jede Instanz (MultiMesh) berechnet ihre Position aus Zeit und Zufallswerten,
// die Tropfen wandern in einem Kasten mit der Kamera mit. Drei Arten:
// kind 0 = fallende Streifen (nah und fern), 1 = Spritzring am Boden, 2 = hochspritzende Tropfen am Boden.

uniform int kind = 0;
uniform vec3 box = vec3(30.0, 22.0, 30.0);   // Groesse des Regenkastens um die Kamera (Meter)
uniform float fall_speed = 14.0;
uniform float streak_len = 0.5;
uniform float streak_width = 0.008;
uniform float base_alpha = 0.3;
uniform vec3 rain_col : source_color = vec3(0.75, 0.8, 0.88);
uniform float splash_rate = 2.2;

varying vec2 v_uv;
varying float v_a;
varying float v_t;
varying float v_seed;

const float STEP = 72.0;
const float PH = 30.0;
const float CR = 3.5;

// Hoehe des Bodens: Gehweg-Bloecke liegen 15 cm hoeher als die Strasse
float ground_y(vec2 p) {
	vec2 b = p - STEP * round(p / STEP);
	vec2 q = abs(b) - vec2(PH - CR);
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - CR;
	return d < 0.0 ? 0.15 : 0.0;
}

void vertex() {
	float id = float(INSTANCE_ID);
	vec3 cam = MODEL_MATRIX[3].xyz;
	float h1 = wx_hash(vec2(id, 1.7));
	float h2 = wx_hash(vec2(id, 5.3));
	float h3 = wx_hash(vec2(id, 9.1));
	float h4 = wx_hash(vec2(id, 13.7));
	// nur ein Teil der Instanzen sichtbar, je nach Regenstaerke
	float vis = step(h4, wx_rain);
	v_uv = UV;
	v_seed = h3;
	vec3 view_pos;
	v_a = 0.0;
	if (kind == 0) {
		vec3 vel = vec3(wx_wind * 5.0 + 0.6, -fall_speed * (0.9 + 0.25 * h3), wx_wind * 2.5);
		vec3 p0 = vec3(h1, h2, h3) * box;
		vec3 p = p0 + vel * TIME;
		vec3 rel = mod(p - cam + box * 0.5, box) - box * 0.5;
		vec3 world = cam + rel;
		vec3 dirv = normalize((VIEW_MATRIX * vec4(normalize(vel), 0.0)).xyz);
		vec3 pv = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
		float dist = length(pv);
		float edge = max(max(abs(rel.x) / (box.x * 0.5), abs(rel.y) / (box.y * 0.5)), abs(rel.z) / (box.z * 0.5));
		float w = streak_width * (1.0 + dist * 0.025);
		float ln = streak_len * (0.8 + 0.4 * h1);
		vec3 side = normalize(cross(dirv, pv));
		vec3 vp = pv - dirv * ln * VERTEX.y + side * VERTEX.x * w;
		view_pos = vp;
		v_a = vis * base_alpha * (1.0 - smoothstep(0.65, 1.0, edge)) * smoothstep(0.4, 2.0, dist) * step(0.12, world.y) * (0.6 + 0.4 * h2);
		v_t = VERTEX.y;
	} else {
		// Spritzer: jede Instanz springt nach jedem Durchlauf an einen neuen Ort
		float cyc = TIME * splash_rate * (0.7 + 0.6 * h1) + h2 * 20.0;
		float cell = floor(cyc);
		float t = fract(cyc);
		vec2 r = vec2(wx_hash(vec2(id, cell + 3.3)), wx_hash(vec2(id + 7.0, cell + 8.1)));
		vec2 pxz = r * box.xz;
		vec2 rel = mod(pxz - cam.xz + box.xz * 0.5, box.xz) - box.xz * 0.5;
		vec2 wxz = cam.xz + rel;
		float gy = ground_y(wxz);
		vec3 world = vec3(wxz.x, gy + 0.012, wxz.y);
		float edge = max(abs(rel.x) / (box.x * 0.5), abs(rel.y) / (box.z * 0.5));
		float gate = step(wx_hash(vec2(id, cell + 1.1)), wx_rain);
		v_t = t;
		v_a = gate * base_alpha * (1.0 - smoothstep(0.6, 1.0, edge)) * step(abs(cam.y - gy), 60.0);
		if (kind == 1) {
			// flacher Ring auf dem Boden
			float rad = 0.04 + 0.14 * t;
			vec3 wv = world + vec3(VERTEX.x * 2.0 * rad, 0.0, (VERTEX.y - 0.5) * 2.0 * rad);
			view_pos = (VIEW_MATRIX * vec4(wv, 1.0)).xyz;
		} else {
			// senkrechte Karte (zur Kamera gedreht) fuer die spritzenden Tropfen
			vec3 pv = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
			vec3 up_v = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
			vec3 right_v = normalize(cross(up_v, pv));
			float sz = 0.2;
			view_pos = pv + right_v * VERTEX.x * sz * 2.0 + up_v * VERTEX.y * sz;
		}
	}
	POSITION = PROJECTION_MATRIX * vec4(view_pos, 1.0);
}

void fragment() {
	ALBEDO = rain_col;
	if (kind == 0) {
		// Streifen: Mitte hell, Enden laufen aus
		float across = 1.0 - abs(v_uv.x * 2.0 - 1.0);
		float along = sin(v_t * 3.14159);
		ALPHA = v_a * across * across * (0.25 + 0.75 * along);
	} else if (kind == 1) {
		vec2 q = v_uv * 2.0 - 1.0;
		float rr = length(q);
		float ring = exp(-pow((rr - (0.25 + 0.75 * v_t)) / 0.12, 2.0));
		ALPHA = v_a * ring * (1.0 - v_t) * (1.0 - v_t) * step(rr, 1.0);
		ALBEDO = rain_col * 1.2;
	} else {
		// 5 Tropfen fliegen nach oben und fallen zurueck
		vec2 q = vec2(v_uv.x * 2.0 - 1.0, v_uv.y);
		float a = 0.0;
		float t = v_t * 1.25;
		for (int i = 0; i < 5; i++) {
			float fi = float(i);
			float ang = (fi - 2.0) * 0.38 + (wx_hash(vec2(fi, v_seed * 17.0)) - 0.5) * 0.2;
			float vy = 0.55 + 0.45 * wx_hash(vec2(fi + 3.0, v_seed * 7.0));
			float px = ang * t * 1.4;
			float py = vy * t - 1.1 * t * t;
			float dd = length((q - vec2(px, py * 0.9 + 0.04)) * vec2(1.0, 1.0));
			a += smoothstep(0.055, 0.015, dd) * step(0.0, py);
		}
		ALPHA = v_a * clamp(a, 0.0, 1.0) * (1.0 - v_t);
		ALBEDO = rain_col * 1.3;
	}
}
