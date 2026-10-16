shader_type sky;
// Klarer Tag mit weichem Dunst am Horizont, Sonnenscheibe und lockeren Schoenwetterwolken.

uniform vec3 zenith_color : source_color = vec3(0.13, 0.28, 0.58);
uniform vec3 mid_color : source_color = vec3(0.30, 0.49, 0.78);
uniform vec3 horizon_color : source_color = vec3(0.66, 0.78, 0.92);
uniform vec3 ground_color : source_color = vec3(0.50, 0.47, 0.42);
uniform vec3 sun_glow_color : source_color = vec3(1.0, 0.80, 0.55);
uniform float sun_radius = 0.0095;
uniform float sun_energy = 60.0;
uniform float cloud_cover = 0.52;
uniform float cloud_speed = 0.004;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;

float cloud_shape(vec2 p) {
	float a = texture(noise_tex, p * 0.32).r;
	float b = texture(noise_tex, p * 0.9 + vec2(0.37, 0.11)).r;
	float c = texture(noise_tex, p * 2.7 + vec2(0.71, 0.53)).r;
	return a * 0.55 + b * 0.30 + c * 0.15;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 sun_dir = vec3(0.0, 1.0, 0.0);
	vec3 sun_col = vec3(1.0);
	if (LIGHT0_ENABLED) {
		sun_dir = normalize(LIGHT0_DIRECTION);
		sun_col = LIGHT0_COLOR;
	}
	float sdot = clamp(dot(d, sun_dir), -1.0, 1.0);

	// Himmelsverlauf
	float t = clamp(h, 0.0, 1.0);
	vec3 col = mix(horizon_color, mid_color, smoothstep(0.0, 0.32, t));
	col = mix(col, zenith_color, smoothstep(0.18, 0.95, t));
	// Dunstband direkt am Horizont
	col = mix(col, horizon_color * 1.05, (1.0 - smoothstep(0.0, 0.16, abs(h))) * 0.55);
	// Warmer Schein um die Sonne (Mie-Streuung)
	float glow1 = pow(max(sdot, 0.0), 5.0);
	float glow2 = pow(max(sdot, 0.0), 90.0);
	col += sun_glow_color * (glow1 * 0.16 + glow2 * 0.55);
	// Boden (unter dem Horizont): in Dunst uebergehen, damit der Horizont weich bleibt
	if (h < 0.0) {
		col = mix(horizon_color * 0.98, ground_color, smoothstep(0.0, 0.35, -h));
	}

	// Wolken
	float cloud_alpha = 0.0;
	if (h > -0.02) {
		float hh = max(h, 0.0);
		vec2 uv = d.xz / (hh * 0.85 + 0.16);
		uv += vec2(TIME * cloud_speed, TIME * cloud_speed * 0.4);
		float s = cloud_shape(uv);
		float dens = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.2, s);
		// Selbstschatten: Dichte zur Sonne hin abtasten
		vec2 toward = sun_dir.xz / max(length(sun_dir.xz), 0.2) * 0.045;
		float s2 = cloud_shape(uv + toward);
		float lit = clamp(0.5 + (s - s2) * 7.0, 0.0, 1.0);
		float core = smoothstep(1.0 - cloud_cover + 0.05, 1.0 - cloud_cover + 0.5, s);
		vec3 shade_col = vec3(0.50, 0.58, 0.72);
		vec3 lit_col = mix(vec3(1.0, 0.99, 0.96), sun_col, 0.35) * 1.15;
		vec3 ccol = mix(shade_col, lit_col, lit * (1.0 - core * 0.35));
		// helle Raender (Silberrand) nahe der Sonne
		ccol += sun_glow_color * glow1 * (1.0 - core) * 0.35;
		float fade = smoothstep(-0.01, 0.20, h);
		cloud_alpha = dens * fade * 0.96;
		col = mix(col, mix(ccol, horizon_color, (1.0 - fade) * 0.8), cloud_alpha);
	}

	// Sonnenscheibe (nur im sichtbaren Himmel, nicht im Reflexionswuerfel)
	if (!AT_CUBEMAP_PASS && LIGHT0_ENABLED) {
		float disk = smoothstep(cos(sun_radius * 1.25), cos(sun_radius * 0.9), sdot);
		col += sun_col * disk * sun_energy * (1.0 - cloud_alpha);
	}
	COLOR = col;
}
