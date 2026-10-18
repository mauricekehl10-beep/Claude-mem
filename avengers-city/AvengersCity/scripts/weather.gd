extends Node
# Wetter-System der Stadt: Sonnig, Bewoelkt, Regen, Gewitter, Nebel, Sonnenuntergang, Nacht.
# Taste T = naechstes Wetter. Alle Werte laufen in ~2,8 s weich von einem Wetter ins naechste.
# Steuert: Sonne (Richtung, Farbe, Staerke, Schattenweichheit), Himmel-Shader, Dunst/Nebel, Farbkorrektur,
# globale Shader-Werte fuer Naesse (wx_wet), Regen (wx_rain), Nacht (wx_night), Sturm (wx_wind),
# Regenstreifen/Spritzer (weather_rain.gdshader) und Blitze (Gewitter).

const NAMES := ["Sonnig", "Bewölkt", "Regen", "Gewitter", "Nebel", "Sonnenuntergang", "Nacht"]
const DURATION := 2.8

# Grundwerte = klarer Sonnentag; die anderen Wetter ueberschreiben nur, was anders ist.
const CLEAR := {
	# Sonne (Elevation/Azimut in Grad, Azimut 45 = schraeg zum Strassenraster)
	"sun_elev": 40.0, "sun_az": 45.0, "sun_color": Color(1.0, 0.90, 0.76), "sun_energy": 2.0,
	"sun_angle": 0.2, "sun_blur": 0.8, "shadow_opacity": 1.0, "shadow_dist": 190.0, "fog_energy": 1.0,
	# Himmel
	"zenith": Color(0.13, 0.28, 0.58), "mid": Color(0.30, 0.49, 0.78), "horizon": Color(0.66, 0.78, 0.92),
	"ground": Color(0.50, 0.47, 0.42), "glow": Color(1.0, 0.80, 0.55), "glow_k": 1.0,
	"disk": 60.0, "disk_r": 0.0095, "cover": 0.52, "cloud_speed": 0.004,
	"cloud_shade": Color(0.50, 0.58, 0.72), "cloud_lit": Color(1.0, 0.99, 0.96),
	"deck": 0.0, "deck_col": Color(0.74, 0.76, 0.80), "deck_contrast": 0.35, "stars": 0.0,
	# Umgebung
	"ambient": 2.0, "exposure": 1.0, "fog_dens": 0.0007, "fog_col": Color(0.66, 0.77, 0.92), "fog_aerial": 0.55,
	"fog_scatter": 0.25, "vfog": 0.004, "vfog_alb": Color(0.9, 0.93, 1.0), "vfog_aniso": 0.65, "vfog_len": 140.0,
	"glow_int": 0.55, "sat": 1.12, "contrast": 1.08, "sdfgi": 1.4,
	# Nässe, Regen, Wind, Nacht, Gewitter
	"wet": 0.0, "rain": 0.0, "wind": 0.0, "night": 0.0, "storm": 0.0, "rain_col": Color(0.75, 0.8, 0.88),
}

var presets: Array = []

var env: Environment
var sky_mat: ShaderMaterial
var sun: DirectionalLight3D
var index := 0

var _cur := {}
var _from := {}
var _to := {}
var _t := 1.0
var _wet := 0.0
var _flash := 0.0
var _strike_t := 99.0
var _pulses: Array = []
var _next_strike := 5.0
var _bolt_life := 0.0

var _rain_root: Node3D
var _rain_mats: Array = []
var _bolt: MeshInstance3D
var _bolt_mat: ShaderMaterial
var _bolt_light: DirectionalLight3D
var _label: Label
var _hint: Label
var _label_t := 0.0

static var _globals := false

const SKY_MAP := {
	"zenith": "zenith_color", "mid": "mid_color", "horizon": "horizon_color", "ground": "ground_color",
	"glow": "sun_glow_color", "glow_k": "glow_k", "disk": "sun_energy", "disk_r": "sun_radius",
	"cover": "cloud_cover", "cloud_speed": "cloud_speed", "cloud_shade": "cloud_shade", "cloud_lit": "cloud_lit",
	"deck": "deck_amount", "deck_col": "deck_color", "deck_contrast": "deck_contrast", "stars": "star_amount",
}


# Globale Shader-Werte (muessen vor dem ersten Stadt-Shader da sein, siehe city_env.gd _static_init)
static func ensure_globals() -> void:
	if _globals:
		return
	_globals = true
	for n in ["wx_wet", "wx_rain", "wx_night", "wx_wind"]:
		RenderingServer.global_shader_parameter_add(n, RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)


static func make_presets() -> Array:
	var out: Array = []
	for i in range(NAMES.size()):
		out.append(CLEAR.duplicate())
	# 1 Bewoelkt: Sonne hinter geschlossener Decke, sehr weiche Schatten
	out[1].merge({
		"sun_elev": 52.0, "sun_color": Color(0.95, 0.95, 1.0), "sun_energy": 0.55, "sun_angle": 0.2, "sun_blur": 3.0,
		"shadow_opacity": 0.5, "shadow_dist": 130.0,
		"zenith": Color(0.40, 0.45, 0.53), "mid": Color(0.52, 0.56, 0.63), "horizon": Color(0.70, 0.73, 0.78),
		"ground": Color(0.45, 0.46, 0.47), "glow_k": 0.4, "cover": 0.9, "cloud_speed": 0.006,
		"cloud_shade": Color(0.50, 0.53, 0.60), "cloud_lit": Color(0.82, 0.84, 0.88),
		"deck": 0.95, "deck_col": Color(0.66, 0.68, 0.72), "deck_contrast": 0.45,
		"ambient": 2.6, "fog_dens": 0.0012, "fog_col": Color(0.68, 0.71, 0.76), "fog_aerial": 0.6,
		"vfog": 0.003, "vfog_alb": Color(0.85, 0.88, 0.92), "sat": 0.9, "contrast": 1.04, "sdfgi": 1.5,
		"rain_col": Color(0.7, 0.74, 0.8),
	}, true)
	# 2 Regen: dunkler Himmel, nasse Strassen, Dunst, Regenstreifen
	out[2].merge({
		"sun_elev": 50.0, "sun_color": Color(0.85, 0.90, 1.0), "sun_energy": 0.35, "sun_angle": 0.5, "sun_blur": 3.0,
		"shadow_opacity": 0.0, "shadow_dist": 100.0,
		"zenith": Color(0.20, 0.23, 0.28), "mid": Color(0.30, 0.33, 0.38), "horizon": Color(0.43, 0.46, 0.51),
		"ground": Color(0.30, 0.31, 0.33), "glow_k": 0.15, "cover": 1.0, "cloud_speed": 0.008,
		"cloud_shade": Color(0.30, 0.33, 0.38), "cloud_lit": Color(0.55, 0.58, 0.63),
		"deck": 1.0, "deck_col": Color(0.36, 0.38, 0.43), "deck_contrast": 0.55,
		"ambient": 2.4, "fog_dens": 0.0035, "fog_col": Color(0.45, 0.48, 0.53), "fog_aerial": 0.7,
		"vfog": 0.006, "vfog_alb": Color(0.7, 0.74, 0.8), "vfog_aniso": 0.4, "sat": 0.85, "contrast": 1.06, "sdfgi": 1.6,
		"wet": 1.0, "rain": 0.75, "wind": 0.15, "night": 0.4, "rain_col": Color(0.7, 0.75, 0.84),
	}, true)
	# 3 Gewitter: sehr dunkel, starker Regen, Sturm, Blitze
	out[3].merge({
		"sun_elev": 50.0, "sun_color": Color(0.75, 0.82, 1.0), "sun_energy": 0.15, "sun_angle": 0.5, "sun_blur": 3.0,
		"shadow_opacity": 0.0, "shadow_dist": 100.0,
		"zenith": Color(0.09, 0.10, 0.13), "mid": Color(0.15, 0.17, 0.21), "horizon": Color(0.26, 0.28, 0.33),
		"ground": Color(0.18, 0.19, 0.21), "glow_k": 0.05, "cover": 1.0, "cloud_speed": 0.014,
		"cloud_shade": Color(0.15, 0.17, 0.21), "cloud_lit": Color(0.35, 0.38, 0.45),
		"deck": 1.0, "deck_col": Color(0.19, 0.21, 0.26), "deck_contrast": 0.85,
		"ambient": 2.2, "exposure": 1.1, "fog_dens": 0.0045, "fog_col": Color(0.26, 0.29, 0.34), "fog_aerial": 0.75,
		"vfog": 0.008, "vfog_alb": Color(0.55, 0.6, 0.7), "vfog_aniso": 0.3, "sat": 0.75, "contrast": 1.08, "sdfgi": 1.6,
		"wet": 1.0, "rain": 1.0, "wind": 1.0, "storm": 1.0, "night": 0.7, "rain_col": Color(0.62, 0.68, 0.78),
	}, true)
	# 4 Nebel / Morgendunst: tiefe Sonne, dichter Dunst, Lichtstrahlen
	out[4].merge({
		"sun_elev": 17.0, "sun_az": 60.0, "sun_color": Color(1.0, 0.88, 0.70), "sun_energy": 1.5, "sun_angle": 0.3, "sun_blur": 2.0,
		"shadow_opacity": 0.8, "shadow_dist": 170.0, "fog_energy": 1.6,
		"zenith": Color(0.50, 0.58, 0.68), "mid": Color(0.66, 0.72, 0.79), "horizon": Color(0.80, 0.82, 0.83),
		"ground": Color(0.62, 0.63, 0.62), "glow_k": 1.8, "cover": 0.5, "deck": 0.55, "deck_col": Color(0.78, 0.8, 0.82), "deck_contrast": 0.2,
		"cloud_shade": Color(0.66, 0.70, 0.76), "cloud_lit": Color(1.0, 0.95, 0.88),
		"ambient": 2.3, "fog_dens": 0.009, "fog_col": Color(0.76, 0.79, 0.82), "fog_aerial": 0.4,
		"fog_scatter": 0.5, "vfog": 0.018, "vfog_alb": Color(0.92, 0.93, 0.95), "vfog_aniso": 0.72, "vfog_len": 220.0,
		"sat": 0.85, "contrast": 1.04, "wet": 0.35,
	}, true)
	# 5 Sonnenuntergang / Goldene Stunde: tiefe orange Sonne, lange Schatten, Lichtstrahlen
	out[5].merge({
		"sun_elev": 6.5, "sun_az": 165.0, "sun_color": Color(1.0, 0.55, 0.24), "sun_energy": 3.0, "sun_angle": 0.35, "sun_blur": 1.5,
		"shadow_dist": 260.0, "fog_energy": 1.8,
		"zenith": Color(0.12, 0.20, 0.44), "mid": Color(0.45, 0.40, 0.58), "horizon": Color(0.98, 0.58, 0.34),
		"ground": Color(0.38, 0.28, 0.24), "glow": Color(1.0, 0.46, 0.14), "glow_k": 4.5, "disk": 90.0, "disk_r": 0.012,
		"cover": 0.45, "cloud_shade": Color(0.40, 0.30, 0.45), "cloud_lit": Color(1.0, 0.62, 0.36),
		"ambient": 1.5, "fog_dens": 0.0009, "fog_col": Color(0.92, 0.66, 0.52), "fog_aerial": 0.4,
		"fog_scatter": 0.6, "vfog": 0.010, "vfog_alb": Color(1.0, 0.82, 0.62), "vfog_aniso": 0.82, "vfog_len": 190.0,
		"sat": 1.2, "contrast": 1.1, "wet": 0.0, "rain_col": Color(0.9, 0.8, 0.7),
	}, true)
	# 6 Nacht: Mond, Sterne, leuchtende Fenster und Lampen, feuchte Strassen
	out[6].merge({
		"sun_elev": 38.0, "sun_az": 215.0, "sun_color": Color(0.55, 0.66, 1.0), "sun_energy": 0.5, "sun_angle": 0.3, "sun_blur": 1.5,
		"shadow_opacity": 0.75, "shadow_dist": 150.0, "fog_energy": 0.8,
		"zenith": Color(0.012, 0.02, 0.055), "mid": Color(0.04, 0.06, 0.13), "horizon": Color(0.10, 0.12, 0.22),
		"ground": Color(0.04, 0.04, 0.06), "glow": Color(0.55, 0.65, 1.0), "glow_k": 0.4, "disk": 5.0, "disk_r": 0.03,
		"cover": 0.3, "cloud_shade": Color(0.04, 0.05, 0.09), "cloud_lit": Color(0.22, 0.27, 0.40), "stars": 1.0,
		"ambient": 2.0, "exposure": 1.3, "fog_dens": 0.0012, "fog_col": Color(0.07, 0.09, 0.16), "fog_aerial": 0.5,
		"vfog": 0.005, "vfog_alb": Color(0.5, 0.6, 0.9), "glow_int": 0.9, "sat": 1.0, "contrast": 1.08, "sdfgi": 1.0,
		"night": 1.0, "wet": 0.55, "rain_col": Color(0.5, 0.55, 0.65),
	}, true)
	return out


func setup(p_env: Environment, p_sky: ShaderMaterial, p_sun: DirectionalLight3D) -> void:
	ensure_globals()
	env = p_env
	sky_mat = p_sky
	sun = p_sun
	presets = make_presets()
	_build_rain()
	_build_lightning()
	_build_lamps()
	_build_hud()
	index = 0
	_cur = presets[0].duplicate()
	_from = _cur.duplicate()
	_to = _cur.duplicate()
	_wet = _cur["wet"]
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	var ke := event as InputEventKey
	if ke and ke.pressed and not ke.echo and ke.physical_keycode == KEY_T:
		next_weather()


func next_weather() -> void:
	set_weather((index + 1) % NAMES.size())


# Wetter wechseln; instant = sofort (ohne Uebergang)
func set_weather(i: int, instant := false) -> void:
	index = clampi(i, 0, NAMES.size() - 1)
	_from = _cur.duplicate()
	_to = presets[index].duplicate()
	if instant:
		_cur = _to.duplicate()
		_wet = _cur["wet"]
		_t = 1.0
		_apply()
	else:
		_t = 0.0
	_label_t = 4.0
	if _label:
		_label.text = "Wetter: " + NAMES[index]
		_hint.text = "T: Wetter (%s)" % NAMES[index]


func weather_name() -> String:
	return NAMES[index]


func _mix(a, b, e: float, key: String):
	if typeof(a) == TYPE_COLOR:
		return (a as Color).lerp(b, e)
	if key == "sun_az":
		return rad_to_deg(lerp_angle(deg_to_rad(a), deg_to_rad(b), e))
	return lerpf(a, b, e)


func _process(delta: float) -> void:
	var dirty := false
	if _t < 1.0:
		_t = minf(1.0, _t + delta / DURATION)
		var e := _t * _t * (3.0 - 2.0 * _t)
		for k in _to:
			if k != "wet":
				_cur[k] = _mix(_from[k], _to[k], e, k)
		dirty = true
	# Naesse: Strassen werden schnell nass und trocknen langsam
	var wt: float = _to["wet"]
	if not is_equal_approx(_wet, wt):
		var rate := delta / 2.5 if wt > _wet else delta / 9.0
		_wet = move_toward(_wet, wt, rate)
		dirty = true
	_update_lightning(delta)
	_update_lamps(get_viewport().get_camera_3d())
	_update_car_lights()
	var cam := get_viewport().get_camera_3d()
	if cam:
		_rain_root.global_position = cam.global_position
	_rain_root.visible = _cur["rain"] > 0.02
	if dirty or _flash > 0.001 or _bolt_life > 0.0:
		_apply()
	# HUD
	_label_t = maxf(0.0, _label_t - delta)
	_label.modulate.a = clampf(_label_t, 0.0, 1.0) * 0.9
	_hint.modulate.a = 0.55 if _label_t <= 0.0 else 0.0


func _apply() -> void:
	var v := _cur
	# Sonne
	var el := deg_to_rad(v["sun_elev"])
	var az := deg_to_rad(v["sun_az"])
	var dir := Vector3(cos(el) * sin(az), sin(el), cos(el) * cos(az))
	sun.basis = Basis.looking_at(-dir, Vector3.UP)
	sun.light_color = v["sun_color"]
	sun.light_energy = v["sun_energy"]
	sun.light_angular_distance = v["sun_angle"]
	sun.shadow_blur = v["sun_blur"]
	sun.shadow_opacity = v["shadow_opacity"]
	sun.shadow_enabled = v["shadow_opacity"] > 0.03
	sun.directional_shadow_max_distance = v["shadow_dist"]
	sun.light_volumetric_fog_energy = v["fog_energy"]
	# Himmel
	for k in SKY_MAP:
		sky_mat.set_shader_parameter(SKY_MAP[k], v[k])
	sky_mat.set_shader_parameter("flash", _flash)
	# Umgebung
	env.ambient_light_energy = v["ambient"] + _flash * 0.9
	env.tonemap_exposure = v["exposure"]
	env.fog_density = v["fog_dens"]
	env.fog_light_color = v["fog_col"]
	env.fog_aerial_perspective = v["fog_aerial"]
	env.fog_sun_scatter = v["fog_scatter"]
	env.volumetric_fog_density = v["vfog"]
	env.volumetric_fog_albedo = v["vfog_alb"]
	env.volumetric_fog_anisotropy = v["vfog_aniso"]
	env.volumetric_fog_length = v["vfog_len"]
	env.glow_intensity = v["glow_int"]
	env.adjustment_saturation = v["sat"]
	env.adjustment_contrast = v["contrast"]
	env.sdfgi_energy = v["sdfgi"]
	# Shader-Globals (Naesse, Regen, Nacht, Sturm)
	RenderingServer.global_shader_parameter_set("wx_wet", _wet)
	RenderingServer.global_shader_parameter_set("wx_rain", v["rain"])
	RenderingServer.global_shader_parameter_set("wx_night", v["night"])
	RenderingServer.global_shader_parameter_set("wx_wind", v["wind"])
	for m in _rain_mats:
		m.set_shader_parameter("rain_col", v["rain_col"])
	# Blitzlicht
	_bolt_light.light_energy = _flash * 2.2
	_bolt_light.visible = _flash > 0.01


# ---------------------------------------------------------------- Regen

func _quad_mesh() -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(0.5, 1, 0), Vector3(-0.5, 1, 0)])
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


func _rain_layer(node_name: String, kind: int, count: int, params: Dictionary) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _quad_mesh()
	mm.instance_count = count
	for i in range(count):
		mm.set_instance_transform(i, Transform3D.IDENTITY)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/weather_rain.gdshader")
	mat.set_shader_parameter("kind", kind)
	for k in params:
		mat.set_shader_parameter(k, params[k])
	_rain_mats.append(mat)
	var mi := MultiMeshInstance3D.new()
	mi.name = node_name
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-150, -150, -150), Vector3(300, 300, 300))
	_rain_root.add_child(mi)


func _build_rain() -> void:
	_rain_root = Node3D.new()
	_rain_root.name = "Rain"
	_rain_root.top_level = true
	add_child(_rain_root)
	# nahe Streifen, ferne dichte Streifen (Regenvorhang), Spritzringe und Spritzer am Boden
	_rain_layer("Near", 0, 4200, {"box": Vector3(28, 20, 28), "streak_len": 0.55, "streak_width": 0.007, "base_alpha": 0.42})
	_rain_layer("Far", 0, 3000, {"box": Vector3(110, 46, 110), "fall_speed": 16.0, "streak_len": 1.7, "streak_width": 0.02, "base_alpha": 0.2})
	_rain_layer("Rings", 1, 1500, {"box": Vector3(24, 1, 24), "base_alpha": 0.32, "splash_rate": 2.4})
	_rain_layer("Splash", 2, 600, {"box": Vector3(13, 1, 13), "base_alpha": 0.55, "splash_rate": 2.0})
	_rain_root.visible = false


# ---------------------------------------------------------------- Blitze

func _build_lightning() -> void:
	_bolt_light = DirectionalLight3D.new()
	_bolt_light.name = "LightningLight"
	_bolt_light.light_color = Color(0.72, 0.82, 1.0)
	_bolt_light.light_energy = 0.0
	_bolt_light.shadow_enabled = false
	_bolt_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	_bolt_light.visible = false
	add_child(_bolt_light)
	_bolt_mat = ShaderMaterial.new()
	_bolt_mat.shader = load("res://scripts/weather_bolt.gdshader")
	_bolt = MeshInstance3D.new()
	_bolt.name = "Bolt"
	_bolt.top_level = true
	_bolt.material_override = _bolt_mat
	_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bolt.extra_cull_margin = 500.0
	_bolt.visible = false
	add_child(_bolt)


func _update_lightning(delta: float) -> void:
	var storm: float = _cur["storm"]
	if storm > 0.6 and _t >= 0.5:
		_next_strike -= delta
		if _next_strike <= 0.0:
			_strike()
			_next_strike = randf_range(4.0, 11.0)
	if _strike_t < 3.0:
		_strike_t += delta
		var f := 0.0
		for p in _pulses:
			var dt: float = _strike_t - p.x
			if dt >= 0.0:
				f = maxf(f, p.y * exp(-dt * 6.5) * minf(1.0, dt * 40.0))
		_flash = f
		_bolt_life = maxf(0.0, _bolt_life - delta)
		_bolt.visible = _bolt_life > 0.0 and fmod(_strike_t, 0.09) < 0.065
		_bolt_mat.set_shader_parameter("intensity", 5.0 + 6.0 * _flash)
	elif _flash != 0.0 or _bolt.visible:
		_flash = 0.0
		_bolt.visible = false


func _strike() -> void:
	_strike_t = 0.0
	_pulses = [Vector2(0.0, 1.0)]
	var n := randi_range(1, 3)
	var t := 0.0
	for i in range(n):
		t += randf_range(0.1, 0.22)
		_pulses.append(Vector2(t, randf_range(0.45, 0.85)))
	_bolt_light.basis = Basis.looking_at(Vector3(randf_range(-0.5, 0.5), -1.0, randf_range(-0.5, 0.5)).normalized(), Vector3.FORWARD)
	var cam := get_viewport().get_camera_3d()
	if cam:
		_make_bolt(cam)
		_bolt_life = 0.45


func _jag(a: Vector3, b: Vector3, n: int, amp: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	pts.append(a)
	for i in range(1, n):
		var p := a.lerp(b, float(i) / n)
		p += Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * amp
		pts.append(p)
	pts.append(b)
	return pts


func _add_ribbon(pts: PackedVector3Array, width: float, cp: Vector3, verts: PackedVector3Array, uvs: PackedVector2Array, idx: PackedInt32Array) -> void:
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var side := (b - a).cross(cp - a).normalized() * width
		var k := verts.size()
		verts.append(a - side)
		verts.append(a + side)
		verts.append(b + side)
		verts.append(b - side)
		uvs.append(Vector2(0, 0))
		uvs.append(Vector2(1, 0))
		uvs.append(Vector2(1, 1))
		uvs.append(Vector2(0, 1))
		idx.append_array(PackedInt32Array([k, k + 1, k + 2, k, k + 2, k + 3]))


func _make_bolt(cam: Camera3D) -> void:
	var cp := cam.global_position
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var dist := randf_range(140.0, 420.0)
	var dir := fwd.rotated(Vector3.UP, randf_range(-0.75, 0.75))
	var base := Vector3(cp.x, 0.0, cp.z) + dir * dist
	var top := base + Vector3(randf_range(-50, 50), randf_range(250.0, 340.0), randf_range(-50, 50))
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var w := maxf(0.5, dist * 0.0042)
	var main := _jag(top, base, 18, 15.0)
	_add_ribbon(main, w, cp, verts, uvs, idx)
	for b in range(3):
		var s := main[randi_range(3, 13)]
		var e := s + Vector3(randf_range(-80, 80), -randf_range(70.0, 160.0), randf_range(-80, 80))
		e.y = maxf(e.y, 5.0)
		_add_ribbon(_jag(s, e, 6, 7.0), w * 0.5, cp, verts, uvs, idx)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_bolt.mesh = m
	_bolt.global_transform = Transform3D.IDENTITY


# ---------------------------------------------------------------- HUD

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	_label = Label.new()
	_hint = Label.new()
	for l in [_label, _hint]:
		l.anchor_left = 1.0
		l.anchor_right = 1.0
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.offset_left = -460.0
		l.offset_right = -18.0
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("outline_size", 5)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(l)
	_label.offset_top = 14.0
	_label.add_theme_font_size_override("font_size", 30)
	_label.text = "Wetter: " + NAMES[0]
	_label.modulate.a = 0.0
	_hint.offset_top = 14.0
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.text = "T: Wetter (%s)" % NAMES[0]
	_hint.modulate.a = 0.55


# ---------------------------------------------------------------- Lampen und Scheinwerfer (nachts/bei Unwetter)

const LAMP_COUNT := 8
const STEP := 72.0
# Seiten eines Blocks: [Richtung nach aussen, Richtung entlang des Bordsteins] (wie city_props.gd)
const LAMP_SIDES := [
	[Vector3(0, 0, 1), Vector3(1, 0, 0)],
	[Vector3(0, 0, -1), Vector3(-1, 0, 0)],
	[Vector3(1, 0, 0), Vector3(0, 0, -1)],
	[Vector3(-1, 0, 0), Vector3(0, 0, 1)],
]

var _lamps: Array = []
var _lamp_pos := Vector3(1e9, 0, 1e9)
var _car_lights: Array = []


func _build_lamps() -> void:
	for i in range(LAMP_COUNT):
		var l := SpotLight3D.new()
		l.name = "LampLight%d" % i
		l.top_level = true
		l.light_color = Color(1.0, 0.78, 0.5)
		l.light_energy = 0.0
		l.spot_range = 28.0
		l.spot_angle = 78.0
		l.spot_angle_attenuation = 0.7
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		l.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), Vector3(0, -100, 0))
		_lamps.append(l)


# Die naechsten Strassenlaternen bekommen echtes Licht (Laternenpositionen wie in city_props.gd)
func _update_lamps(cam: Camera3D) -> void:
	var night: float = _cur["night"]
	var e := night * 1.8
	var on := night > 0.2
	for l in _lamps:
		l.visible = on
		l.light_energy = e
	if not on or cam == null:
		return
	var cp := cam.global_position
	if Vector2(cp.x - _lamp_pos.x, cp.z - _lamp_pos.z).length() < 4.0:
		return
	_lamp_pos = cp
	var cands: Array = []
	var bx := roundi(cp.x / STEP)
	var bz := roundi(cp.z / STEP)
	for ix in range(bx - 1, bx + 2):
		for iz in range(bz - 1, bz + 2):
			for s in LAMP_SIDES:
				var n: Vector3 = s[0]
				var t: Vector3 = s[1]
				for tt in [-18.0, -6.0, 6.0, 18.0]:
					var p: Vector3 = Vector3(ix * STEP, 8.7, iz * STEP) + t * tt + n * 31.3
					cands.append([Vector2(p.x - cp.x, p.z - cp.z).length(), p])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	for i in range(mini(LAMP_COUNT, cands.size())):
		var l: SpotLight3D = _lamps[i]
		l.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), cands[i][1])


# Scheinwerfer am Spieler-Auto (leuchten nachts und im Gewitter)
func _update_car_lights() -> void:
	var main := get_parent()
	var car = main.get("vehicle") if main else null
	if car == null:
		return
	if _car_lights.is_empty():
		for x in [-0.6, 0.6]:
			var l := SpotLight3D.new()
			l.light_color = Color(1.0, 0.95, 0.85)
			l.spot_range = 45.0
			l.spot_angle = 32.0
			l.spot_angle_attenuation = 0.6
			l.shadow_enabled = false
			l.position = Vector3(x, 0.7, -2.1)
			l.rotation_degrees = Vector3(-4.0, 0.0, 0.0)
			l.visible = false
			car.add_child(l)
			_car_lights.append(l)
	var night: float = _cur["night"]
	for l in _car_lights:
		l.visible = night > 0.3
		l.light_energy = night * 3.0
