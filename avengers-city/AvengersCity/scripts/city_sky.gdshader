shader_type sky;
// Himmel fuer alle Wetterlagen (Werte setzt scripts/weather.gd): Verlauf, Sonne/Mond, Schoenwetterwolken,
// geschlossene Wolkendecke (bewoelkt/Regen/Gewitter), Sterne (Nacht) und Blitz-Aufhellung.

uniform vec3 zenith_color : source_color = vec3(0.13, 0.28, 0.58);
uniform vec3 mid_color : source_color = vec3(0.30, 0.49, 0.78);
uniform vec3 horizon_color : source_color = vec3(0.66, 0.78, 0.92);
uniform vec3 ground_color : source_color = vec3(0.50, 0.47, 0.42);
uniform vec3 sun_glow_color : source_color = vec3(1.0, 0.80, 0.55);
uniform float glow_k = 1.0;            // Staerke des Sonnenscheins im Himmel (Sonnenuntergang: gross)
uniform float sun_radius = 0.0095;
uniform float sun_energy = 60.0;       // Helligkeit der Sonnenscheibe (Nacht: Mond)
uniform float cloud_cover = 0.52;
uniform float cloud_speed = 0.004;
uniform vec3 cloud_shade : source_color = vec3(0.50, 0.58, 0.72);
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.99, 0.96);
uniform float deck_amount = 0.0;       // 0 = offener Himmel, 1 = geschlossene Wolkendecke
uniform vec3 deck_color : source_color = vec3(0.74, 0.76, 0.80);
uniform float deck_contrast = 0.35;    // Struktur in der Decke (Gewitter: grosse dunkle Fetzen)
uniform float star_amount = 0.0;
uniform float flash = 0.0;             // Blitz: Himmel wird kurz hell
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;

float cloud_shape(vec2 p) {
	float a = texture(noise_tex, p * 0.32).r;
	float b = texture(noise_tex, p * 0.9 + vec2(0.37, 0.11)).r;
	float c = texture(noise_tex, p * 2.7 + vec2(0.71, 0.53)).r;
	return a * 0.55 + b * 0.30 + c * 0.15;
}

float star_hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
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
	// Sterne (nicht im Spiegelungswuerfel, sonst flimmert die Spiegelung)
	if (star_amount > 0.01 && h > 0.0 && !AT_CUBEMAP_PASS) {
		vec3 sp = d * 150.0;
		vec3 cell = floor(sp);
		vec3 fp = fract(sp) - 0.5;
		float sh = star_hash(cell);
		float st = step(0.965, sh) * pow(max(0.0, 1.0 - length(fp) * 2.2), 5.0);
		col += vec3(0.8, 0.88, 1.0) * st * star_amount * (0.5 + 1.8 * fract(sh * 91.0)) * smoothstep(0.0, 0.25, h) * 2.0;
	}
	// Warmer Schein um die Sonne (Mie-Streuung)
	float glow1 = pow(max(sdot, 0.0), 5.0);
	float glow2 = pow(max(sdot, 0.0), 90.0);
	col += sun_glow_color * (glow1 * 0.16 + glow2 * 0.55) * glow_k;
	// tiefe Sonne: breiter Schein entlang des Horizonts
	col += sun_glow_color * pow(max(sdot, 0.0), 2.5) * exp(-abs(h) * 5.0) * 0.12 * max(glow_k - 1.0, 0.0);
	// Boden (unter dem Horizont): in Dunst uebergehen, damit der Horizont weich bleibt
	if (h < 0.0) {
		col = mix(horizon_color * 0.98, ground_color, smoothstep(0.0, 0.35, -h));
	}

	// Wolken
	float cloud_alpha = 0.0;
	float deck_a = 0.0;
	if (h > -0.02) {
		float hh = max(h, 0.0);
		vec2 uv = d.xz / (hh * 0.85 + 0.16);
		uv += vec2(TIME * cloud_speed, TIME * cloud_speed * 0.4);
		float s = cloud_shape(uv);
		float cov = min(cloud_cover, 0.98);
		float dens = smoothstep(1.0 - cov, 1.0 - cov + 0.2, s);
		// Selbstschatten: Dichte zur Sonne hin abtasten
		vec2 toward = sun_dir.xz / max(length(sun_dir.xz), 0.2) * 0.045;
		float s2 = cloud_shape(uv + toward);
		float lit = clamp(0.5 + (s - s2) * 7.0, 0.0, 1.0);
		float core = smoothstep(1.0 - cov + 0.05, 1.0 - cov + 0.5, s);
		vec3 lit_col = mix(cloud_lit, sun_col, 0.35) * 1.15;
		vec3 ccol = mix(cloud_shade, lit_col, lit * (1.0 - core * 0.35));
		// helle Raender (Silberrand) nahe der Sonne
		ccol += sun_glow_color * glow1 * (1.0 - core) * 0.35 * glow_k;
		float fade = smoothstep(-0.01, 0.20, h);
		cloud_alpha = dens * fade * 0.96;
		col = mix(col, mix(ccol, horizon_color, (1.0 - fade) * 0.8), cloud_alpha);

		// Geschlossene Wolkendecke (grau, mit Struktur, hell um die Sonne)
		if (deck_amount > 0.001) {
			float sd = cloud_shape(uv * 0.55 + vec2(0.23, 0.61));
			float sd2 = cloud_shape(uv * 1.6 + vec2(0.9, 0.2));
			float var_ = (sd - 0.5) * 1.6 + (sd2 - 0.5) * 0.9;
			vec3 dcol = deck_color * (1.0 + var_ * deck_contrast * 1.6);
			dcol += sun_glow_color * (pow(max(sdot, 0.0), 6.0) * 0.5 + pow(max(sdot, 0.0), 40.0) * 0.6) * (1.0 - deck_contrast) * glow_k * 0.5;
			float dfade = smoothstep(-0.01, 0.16, h);
			deck_a = deck_amount * dfade;
			// Richtung Horizont wird die Decke heller/dunstiger
			dcol = mix(dcol, horizon_color * (0.85 + 0.3 * deck_color.r), (1.0 - smoothstep(0.0, 0.5, h)) * 0.35);
			col = mix(col, dcol, deck_a);
		}
	}
	// Blitz hellt Himmel und Wolken auf
	col += vec3(0.62, 0.72, 1.0) * flash * (0.35 + 0.65 * (1.0 - clamp(h, 0.0, 1.0) * 0.6)) * 1.4;

	// Sonnenscheibe (nur im sichtbaren Himmel, nicht im Reflexionswuerfel)
	if (!AT_CUBEMAP_PASS && LIGHT0_ENABLED) {
		float disk = smoothstep(cos(sun_radius * 1.25), cos(sun_radius * 0.9), sdot);
		col += sun_col * disk * sun_energy * (1.0 - cloud_alpha) * (1.0 - deck_a);
	}
	COLOR = col;
}
