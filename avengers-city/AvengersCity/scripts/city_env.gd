extends RefCounted
# Umgebung der Stadt: Himmel mit Wolken, Sonne, Dunst, Tonemapping, Farbkorrektur.

const Tex = preload("res://scripts/city_tex.gd")
const Weather = preload("res://scripts/weather.gd")

# Richtung ZUR Sonne (Nachmittag, ca. 40 Grad ueber dem Horizont, schraeg zum Strassenraster)
const SUN_DIR := Vector3(0.47, 0.80, 0.47)


# Globale Shader-Werte fuer das Wetter muessen existieren, bevor der erste Stadt-Shader geladen wird
static func _static_init() -> void:
	Weather.ensure_globals()


static func build(parent: Node3D) -> Node:
	var vp := parent.get_viewport()
	vp.msaa_3d = Viewport.MSAA_4X
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)  # HIGH+8192 kostet ~2x (gemessen)
	RenderingServer.directional_shadow_atlas_set_size(4096, true)
	RenderingServer.environment_set_volumetric_fog_volume_size(96, 64)  # feinere Lichtstrahlen (Standard 64x64)

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://scripts/city_sky.gdshader")
	sm.set_shader_parameter("noise_tex", Tex.noise("cloud"))
	sky.sky_material = sm
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 2.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	# Tonemapping und Glow
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 0.9
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.2
	env.glow_hdr_scale = 1.5
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 0.4)
	env.set_glow_level(2, 0.8)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(4, 0.8)
	env.set_glow_level(5, 0.4)

	# Dunst: Tiefe und Luftperspektive
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.66, 0.77, 0.92)
	env.fog_light_energy = 1.0
	env.fog_density = 0.0007
	env.fog_aerial_perspective = 0.55
	env.fog_sky_affect = 0.0
	env.fog_sun_scatter = 0.25
	env.fog_height = 0.0
	env.fog_height_density = 0.0

	# Lichtschneisen zwischen den Haeusern (volumetrischer Dunst)
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.004
	env.volumetric_fog_albedo = Color(0.9, 0.93, 1.0)
	env.volumetric_fog_emission = Color(0, 0, 0)
	env.volumetric_fog_length = 140.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_gi_inject = 0.5
	env.volumetric_fog_ambient_inject = 0.3
	env.volumetric_fog_anisotropy = 0.65
	env.volumetric_fog_sky_affect = 0.0

	# Spiegelungen auf Glas und Pfuetzen (Bildschirmraum)
	env.ssr_enabled = true
	env.ssr_max_steps = 64
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.3

	# Verdeckung und Streulicht
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.9
	env.ssao_power = 1.5
	env.ssao_detail = 0.8
	env.ssao_light_affect = 0.25

	# Globale Beleuchtung (Licht, das von Waenden zurueckgeworfen wird)
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = false
	env.sdfgi_read_sky_light = true
	env.sdfgi_bounce_feedback = 0.6
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.4
	env.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_100_PERCENT
	env.sdfgi_energy = 1.4
	env.sdfgi_normal_bias = 1.1
	env.sdfgi_probe_bias = 1.1

	# Farbkorrektur
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12

	var we := WorldEnvironment.new()
	we.environment = env
	we.name = "CityEnvironment"
	parent.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.basis = Basis.looking_at(-SUN_DIR.normalized(), Vector3.UP)
	sun.light_energy = 2.0
	sun.light_color = Color(1.0, 0.90, 0.76)
	sun.light_angular_distance = 0.25
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.0
	sun.shadow_blur = 1.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 190.0
	sun.directional_shadow_split_1 = 0.06
	sun.directional_shadow_split_2 = 0.18
	sun.directional_shadow_split_3 = 0.45
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 0.85
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	parent.add_child(sun)

	# Wetter-System (Taste T): steuert Sonne, Himmel, Dunst, Naesse, Regen und Blitze
	var weather := Weather.new()
	weather.name = "Weather"
	parent.add_child(weather)
	weather.setup(env, sm, sun)
	return weather
