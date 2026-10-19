extends RefCounted
# Effekte: Funken, Blitze, Staub, Schockringe ...
# Jeder Aufruf = EIN Effekt, der sich nach seiner Lebensdauer selbst löscht.
# Shader, Texturen und Meshes werden nur einmal angelegt und geteilt (static _cache).
# Bei zu vielen Effekten gleichzeitig (MAX_FX) werden kleine Effekte übersprungen, damit die Bildrate stabil bleibt.
#
# Benutzung (alle Funktionen sind static):
#   const VFX = preload("res://scripts/vfx.gd")
#   VFX.impact(get_parent(), punkt, normale)
#   var b = VFX.repulsor_shot(get_parent())   # Geschoss; Aufrufer bewegt es und ruft am Ende b.queue_free()

const MAX_FX := 40      # so viele Effekte dürfen gleichzeitig leben
const MAX_LIGHTS := 3   # Lichtblitze nur sehr sparsam

static var _live := 0
static var _lights := 0
static var _cache := {}

# Sprite/Streifen für Partikel. #SOFT# macht Ränder am Boden/an Wänden weich.
const SPRITE_SHADER := """
shader_type spatial;
render_mode unshaded, %BLEND%, depth_draw_never, cull_disabled, fog_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float energy = 1.0;
uniform float billboard = 1.0;
uniform float soft_dist = 0.6;
%DEPTH%

void vertex() {
	if (billboard > 0.5) {
		float sx = length(MODEL_MATRIX[0].xyz);
		float sy = length(MODEL_MATRIX[1].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sx, INV_VIEW_MATRIX[1] * sy, INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	}
}

void fragment() {
	vec4 c = COLOR * texture(tex, UV);
	float a = c.a;
	%SOFT%
	ALBEDO = c.rgb * energy;
	ALPHA = a;
}
"""
const DEPTH_DECL := "uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;"
const SOFT_CODE := """
	float d = texture(depth_tex, SCREEN_UV).x;
	vec4 ndc = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	float scene_z = -ndc.z / ndc.w;
	a *= clamp((scene_z + VERTEX.z) / soft_dist, 0.0, 1.0);
"""

# Leuchtfleck / Strahlenstern / Ring, gezeichnet im Shader (t = Zeit 0..1 pro Effekt)
const FLARE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.5, 1.0);
uniform float energy = 3.0;
uniform float core = 1.0;
uniform float star = 0.0;
uniform float ring = 0.0;
uniform float billboard = 1.0;
instance uniform float t = 0.0;

void vertex() {
	if (billboard > 0.5) {
		float sx = length(MODEL_MATRIX[0].xyz);
		float sy = length(MODEL_MATRIX[1].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sx, INV_VIEW_MATRIX[1] * sy, INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	}
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float life = 1.0 - t;
	float g = pow(max(1.0 - r, 0.0), 3.0) * core * life * life;
	float s = (exp(-abs(p.x) * 24.0) * exp(-abs(p.y) * 2.2) + exp(-abs(p.y) * 24.0) * exp(-abs(p.x) * 2.2)) * star * life;
	float rr = 0.12 + t * 0.85;
	float w = 0.035 + 0.07 * t;
	float rg = exp(-pow((r - rr) / w, 2.0)) * ring * life;
	float v = (g + s + rg) * smoothstep(1.0, 0.8, r);
	ALBEDO = tint.rgb * energy;
	ALPHA = clamp(v, 0.0, 1.0);
}
"""

# Band, das sich zur Kamera dreht (Blitze, Schweife). NORMAL = Richtung, UV.x = Seite (-1/1), UV.y = halbe Breite
const RIBBON_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform float energy = 4.0;
uniform float width_mul = 1.0;
uniform vec3 tint = vec3(1.0);
instance uniform float fade = 1.0;

void vertex() {
	vec3 c = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 tg = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 to_cam = INV_VIEW_MATRIX[3].xyz - c;
	vec3 side = normalize(cross(tg, to_cam));
	vec3 pos = c + side * UV.x * UV.y * width_mul * (0.35 + 0.65 * fade);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(pos, 1.0);
}

void fragment() {
	float g = pow(max(1.0 - abs(UV.x), 0.0), 1.6);
	ALBEDO = COLOR.rgb * tint * energy * fade;
	ALPHA = clamp(g * COLOR.a * fade, 0.0, 1.0);
}
"""

const SOLID_SHADER := """
shader_type spatial;
render_mode unshaded, fog_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform float energy = 4.0;
void fragment() {
	ALBEDO = tint.rgb * energy;
}
"""


# --- Einmal anlegen, überall teilen --------------------------------------

static func _mat(key: String) -> Material:
	if _cache.has(key):
		return _cache[key]
	var m: Material
	match key:
		"spark":  # Funkenstreifen
			m = _sprite_mat(true, false, null, 1.0, 0.0)
		"glow":  # weiches Leuchten
			m = _sprite_mat(true, true, _tex_glow(), 1.0, 0.0)
		"smoke":  # Staub/Rauch
			m = _sprite_mat(false, true, _tex_puff(), 1.0, 0.7)
		"debris":
			var sm := StandardMaterial3D.new()
			sm.albedo_color = Color(0.2, 0.19, 0.18)
			sm.roughness = 1.0
			m = sm
		"bolt_core":
			m = _ribbon_mat(7.0, 1.0, Vector3(0.85, 0.93, 1.0))
		"bolt_glow":
			m = _ribbon_mat(1.6, 7.0, Vector3(0.25, 0.5, 1.0))
		"trail":
			m = _ribbon_mat(1.5, 1.0, Vector3(1, 1, 1))
		"core_blue":
			m = _solid_mat(Color(0.6, 0.9, 1.0), 6.0)
		"flare_hit":
			m = _flare_mat(Color(1.0, 0.85, 0.55), 3.0, 1.0, 0.7, 0.0, 1.0)
		"flare_star":  # Metallfunke
			m = _flare_mat(Color(0.9, 0.95, 1.0), 2.2, 0.35, 1.0, 0.0, 1.0)
		"ring_blue":  # Schockring zur Kamera
			m = _flare_mat(Color(0.8, 0.9, 1.0), 1.6, 0.0, 0.0, 1.0, 1.0)
		"ring_flat":  # Schockring am Boden
			m = _flare_mat(Color(1.0, 0.9, 0.65), 2.5, 0.0, 0.0, 1.0, 0.0)
		"ring_dust":
			m = _flare_mat(Color(0.75, 0.7, 0.62), 0.7, 0.0, 0.0, 1.0, 0.0)
		"ring_flat_blue":
			m = _flare_mat(Color(0.6, 0.8, 1.0), 3.5, 0.3, 0.0, 1.0, 0.0)
		"flash_blue":
			m = _flare_mat(Color(0.65, 0.8, 1.0), 4.0, 1.0, 0.6, 0.0, 1.0)
		"shot_halo":
			m = _flare_mat(Color(0.45, 0.8, 1.0), 2.2, 1.0, 0.0, 0.0, 1.0)
		"shot_star":
			m = _flare_mat(Color(0.8, 0.95, 1.0), 2.5, 0.5, 1.0, 0.0, 1.0)
		"charge_glow":
			m = _flare_mat(Color(0.5, 0.85, 1.0), 3.5, 1.0, 0.4, 0.0, 1.0)
		"scorch":
			var st := StandardMaterial3D.new()
			st.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			st.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			st.albedo_texture = _tex_glow()
			st.albedo_color = Color(0.02, 0.02, 0.025, 0.85)
			m = st
	_cache[key] = m
	return m


static func _sprite_mat(additive: bool, billboard: bool, tex: Texture2D, energy: float, soft: float) -> ShaderMaterial:
	var key := "sh_sprite_%s_%s" % [additive, soft > 0.0]
	var sh: Shader
	if _cache.has(key):
		sh = _cache[key]
	else:
		sh = Shader.new()
		var code := SPRITE_SHADER.replace("%BLEND%", "blend_add" if additive else "blend_mix")
		code = code.replace("%DEPTH%", DEPTH_DECL if soft > 0.0 else "")
		code = code.replace("%SOFT%", SOFT_CODE if soft > 0.0 else "")
		sh.code = code
		_cache[key] = sh
	var m := ShaderMaterial.new()
	m.shader = sh
	if tex:
		m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("billboard", 1.0 if billboard else 0.0)
	if soft > 0.0:
		m.set_shader_parameter("soft_dist", soft)
	return m


static func _flare_mat(tint: Color, energy: float, core: float, star: float, ring: float, billboard: float) -> ShaderMaterial:
	var sh: Shader = _shader("sh_flare", FLARE_SHADER)
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("core", core)
	m.set_shader_parameter("star", star)
	m.set_shader_parameter("ring", ring)
	m.set_shader_parameter("billboard", billboard)
	return m


static func _ribbon_mat(energy: float, width_mul: float, tint: Vector3) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("sh_ribbon", RIBBON_SHADER)
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("width_mul", width_mul)
	m.set_shader_parameter("tint", tint)
	return m


static func _solid_mat(c: Color, energy: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("sh_solid", SOLID_SHADER)
	m.set_shader_parameter("tint", c)
	m.set_shader_parameter("energy", energy)
	return m


static func _shader(key: String, code: String) -> Shader:
	if _cache.has(key):
		return _cache[key]
	var sh := Shader.new()
	sh.code = code
	_cache[key] = sh
	return sh


static func _quad() -> QuadMesh:
	if not _cache.has("quad"):
		var q := QuadMesh.new()
		q.size = Vector2(1, 1)
		_cache["quad"] = q
	return _cache["quad"]


# Funkenstreifen: zwei gekreuzte Spindeln, vorn hell, hinten durchsichtig (Y-Achse = Flugrichtung)
static func _streak() -> ArrayMesh:
	if _cache.has("streak"):
		return _cache["streak"]
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	for axis in range(2):
		var s := Vector3.RIGHT if axis == 0 else Vector3.BACK
		var b := v.size()
		v.append(Vector3(0, -0.5, 0))
		v.append(s * -0.09 + Vector3(0, 0.15, 0))
		v.append(s * 0.09 + Vector3(0, 0.15, 0))
		v.append(Vector3(0, 0.5, 0))
		c.append(Color(1, 1, 1, 0.0))
		c.append(Color(1, 1, 1, 0.8))
		c.append(Color(1, 1, 1, 0.8))
		c.append(Color(1, 1, 1, 1.0))
		idx.append_array(PackedInt32Array([b, b + 1, b + 2, b + 1, b + 3, b + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cache["streak"] = m
	return m


static func _tex_glow() -> ImageTexture:
	if _cache.has("tex_glow"):
		return _cache["tex_glow"]
	var sz := 64
	var img := Image.create(sz, sz, true, Image.FORMAT_RGBA8)
	for y in range(sz):
		for x in range(sz):
			var dx := (x + 0.5) / sz * 2.0 - 1.0
			var dy := (y + 0.5) / sz * 2.0 - 1.0
			var a := pow(clampf(1.0 - sqrt(dx * dx + dy * dy), 0.0, 1.0), 2.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache["tex_glow"] = t
	return t


# Weicher, wolkiger Fleck für Staub und Rauch
static func _tex_puff() -> ImageTexture:
	if _cache.has("tex_puff"):
		return _cache["tex_puff"]
	var sz := 64
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = 7
	noise.frequency = 0.05
	noise.fractal_octaves = 3
	var img := Image.create(sz, sz, true, Image.FORMAT_RGBA8)
	for y in range(sz):
		for x in range(sz):
			var dx := (x + 0.5) / sz * 2.0 - 1.0
			var dy := (y + 0.5) / sz * 2.0 - 1.0
			var r := sqrt(dx * dx + dy * dy)
			var mask := pow(clampf(1.0 - r, 0.0, 1.0), 0.8)
			var n := 0.5 + 0.5 * noise.get_noise_2d(x * 1.0, y * 1.0)
			var a := clampf(mask * (0.35 + 0.9 * n) * 1.1, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache["tex_puff"] = t
	return t


# Größe über die Lebenszeit eines Partikels: "shrink" 1 -> 0, "grow" 0.4 -> 1, "pop" 0 -> 1 -> 0
static func _curve(key: String) -> Curve:
	var ck := "curve_" + key
	if _cache.has(ck):
		return _cache[ck]
	var c := Curve.new()
	match key:
		"shrink":
			c.add_point(Vector2(0, 1))
			c.add_point(Vector2(1, 0))
		"grow":
			c.add_point(Vector2(0, 0.35))
			c.add_point(Vector2(1, 1))
		"pop":
			c.add_point(Vector2(0, 0))
			c.add_point(Vector2(0.15, 1))
			c.add_point(Vector2(1, 0))
	_cache[ck] = c
	return c


# Farbverlauf über die Lebenszeit (wird mit der Partikelfarbe multipliziert)
static func _ramp(key: String) -> Gradient:
	var ck := "ramp_" + key
	if _cache.has(ck):
		return _cache[ck]
	var g := Gradient.new()
	match key:
		"spark":  # weiß -> orange -> aus
			g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
			g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 0.6, 0.35, 0.8), Color(0.8, 0.2, 0.1, 0)])
		"fade":
			g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
			g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		"fade_out":
			g.offsets = PackedFloat32Array([0.0, 1.0])
			g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		"cool":  # weiß -> blau -> aus (Blitzfunken)
			g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
			g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.5, 0.7, 1, 0.8), Color(0.2, 0.3, 1, 0)])
	_cache[ck] = g
	return g


# --- Hilfen --------------------------------------------------------------

# Legt einen Effekt-Behälter an "parent" und löscht ihn nach "life" Sekunden. Gibt null zurück, wenn es nicht geht.
# world = true: unabhängig von der Position des Elternknotens (Weltposition "at").
static func _spawn(parent: Node, life: float, at: Vector3 = Vector3.ZERO, world: bool = true) -> Node3D:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var fx := Node3D.new()
	fx.top_level = world
	parent.add_child(fx)
	if world:
		fx.global_position = at
	_live += 1
	parent.get_tree().create_timer(life).timeout.connect(_free_fx.bind(fx))
	return fx


static func _free_fx(fx: Node) -> void:
	_live -= 1
	if is_instance_valid(fx):
		fx.queue_free()


static func _busy() -> bool:
	return _live >= MAX_FX


# Partikel-Gruppe, die einmal ausbricht. Aufrufer stellt noch ein und ruft dann _go().
static func _burst(mesh: Mesh, mat: Material, amount: int, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.mesh = mesh
	p.material_override = mat
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = false
	return p


static func _go(fx: Node3D, p: CPUParticles3D) -> void:
	fx.add_child(p)
	p.emitting = true


# Funken: Streifen, die vom Punkt wegfliegen
static func _sparks(fx: Node3D, dir: Vector3, spread: float, amount: int, life: float, vmin: float, vmax: float, color: Color, grav: float = -14.0, size: float = 1.0) -> void:
	var p := _burst(_streak(), _mat("spark"), amount, life)
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = Vector3(0, grav, 0)
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.lifetime_randomness = 0.5
	p.particle_flag_align_y = true
	p.scale_amount_min = 0.13 * size
	p.scale_amount_max = 0.3 * size
	p.scale_amount_curve = _curve("shrink")
	p.color = Color(color.r * 1.7, color.g * 1.7, color.b * 1.7, 1.0)
	p.color_ramp = _ramp("cool" if color.b > color.r else "spark")
	_go(fx, p)


# Staubwolke
static func _dust(fx: Node3D, dir: Vector3, spread: float, amount: int, life: float, vmin: float, vmax: float, size: float, color: Color) -> void:
	var p := _burst(_quad(), _mat("smoke"), amount, life)
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = Vector3(0, 0.5, 0)
	p.damping_min = 1.5
	p.damping_max = 3.5
	p.lifetime_randomness = 0.4
	p.scale_amount_min = size * 0.7
	p.scale_amount_max = size * 1.3
	p.scale_amount_curve = _curve("grow")
	p.color = color
	p.color_ramp = _ramp("fade")
	_go(fx, p)


# Leuchtfleck/Ring mit eigener Zeit (t läuft von 0 bis 1 in "life" Sekunden)
static func _flare(fx: Node3D, mat_key: String, size: float, life: float, pos: Vector3 = Vector3.ZERO, flat: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _quad()
	mi.material_override = _mat(mat_key)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(size, size, size)
	mi.position = pos
	if flat:
		mi.rotation_degrees = Vector3(-90, 0, 0)
	fx.add_child(mi)
	mi.set_instance_shader_parameter("t", 0.0)
	var tw := fx.create_tween()
	tw.tween_method(func(v: float): mi.set_instance_shader_parameter("t", v), 0.0, 1.0, life)
	return mi


# Kurzer Lichtblitz (höchstens MAX_LIGHTS gleichzeitig)
static func _light(fx: Node3D, pos: Vector3, color: Color, energy: float, rng: float, life: float) -> void:
	if _lights >= MAX_LIGHTS:
		return
	_lights += 1
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	l.position = pos
	fx.add_child(l)
	l.tree_exited.connect(_light_gone)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func _light_gone() -> void:
	_lights -= 1


# Boden unter einem Punkt (für Brandflecken); {pos, normal}
static func _ground(parent: Node, pos: Vector3) -> Dictionary:
	var out := {"pos": pos, "normal": Vector3.UP}
	var w: World3D = (parent as Node3D).get_world_3d() if parent is Node3D else null
	if w == null:
		return out
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 1.0, 0), pos + Vector3(0, -3.0, 0))
	var r := w.direct_space_state.intersect_ray(q)
	if r and r["collider"] is StaticBody3D:
		out["pos"] = r["position"]
		out["normal"] = r["normal"]
	return out


# Dunkler Brandfleck auf dem Boden, der langsam verblasst
static func _scorch(parent: Node, pos: Vector3, radius: float, life: float) -> void:
	var g := _ground(parent, pos)
	var fx := _spawn(parent, life, g["pos"] + Vector3(0, 0.035, 0))
	if fx == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = _quad()
	mi.material_override = _mat("scorch")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(radius * 2.0, radius * 2.0, radius * 2.0)
	mi.rotation_degrees = Vector3(-90, randf() * 360.0, 0)
	mi.transparency = 0.2
	fx.add_child(mi)
	var tw := fx.create_tween()
	tw.tween_interval(life * 0.4)
	tw.tween_property(mi, "transparency", 1.0, life * 0.55)


# --- Die Effekte ---------------------------------------------------------

# Funken und Staub bei einem Treffer. normal = wohin die Funken spritzen, color = Funkenfarbe.
static func impact(parent: Node, pos: Vector3, normal: Vector3 = Vector3.UP, color: Color = Color(1, 0.8, 0.4)) -> void:
	if _busy():
		return
	var fx := _spawn(parent, 0.8, pos)
	if fx == null:
		return
	var n := normal.normalized() if normal.length() > 0.01 else Vector3.UP
	var low := _live > MAX_FX * 0.6
	_sparks(fx, n, 50.0, 7 if low else 15, 0.4, 3.0, 9.0, color)
	# kurzer heller Blitz am Treffpunkt
	var fl := _burst(_quad(), _mat("glow"), 1, 0.1)
	fl.initial_velocity_max = 0.0
	fl.gravity = Vector3.ZERO
	fl.scale_amount_min = 0.5
	fl.scale_amount_max = 0.5
	fl.scale_amount_curve = _curve("shrink")
	fl.color = Color(color.r * 1.6, color.g * 1.6, color.b * 1.6, 1.0)
	_go(fx, fl)
	if not low:
		_dust(fx, n, 60.0, 4, 0.55, 0.4, 1.4, 0.35, Color(0.62, 0.57, 0.52, 0.4))


# Farben des Repulsor-Schusses (warm, passend zu den roten Düsenflammen und zur warmen Handflächen-Linse)
static func _rep_mat(key: String) -> Material:
	var k := "rep_" + key
	if _cache.has(k):
		return _cache[k]
	var m: Material
	match key:
		"core":
			m = _solid_mat(Color(1.0, 0.92, 0.7), 6.0)
		"halo":
			m = _flare_mat(Color(1.0, 0.5, 0.16), 2.0, 1.0, 0.0, 0.0, 1.0)
		"star":
			m = _flare_mat(Color(1.0, 0.8, 0.5), 2.2, 0.5, 1.0, 0.0, 1.0)
		"charge":
			m = _flare_mat(Color(1.0, 0.62, 0.25), 3.0, 1.0, 0.4, 0.0, 1.0)
	_cache[k] = m
	return m


# Geschoss von Iron Man: leuchtender Kern, Glühen, Schweif. Das Geschoss hängt schon an "parent";
# der Aufrufer setzt global_position und löscht es mit queue_free() (der Schweif klingt von selbst aus).
static func repulsor_shot(parent: Node) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.075
	sm.height = 0.15
	sm.radial_segments = 12
	sm.rings = 6
	core.mesh = sm
	core.material_override = _rep_mat("core")
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(core)
	for k in [["halo", 0.40], ["star", 0.55]]:
		var mi := MeshInstance3D.new()
		mi.mesh = _quad()
		mi.material_override = _rep_mat(k[0])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.scale = Vector3.ONE * k[1]
		root.add_child(mi)
	_trail(parent, root, 0.045, 0.22, Color(1.0, 0.58, 0.2), false)
	return root


# Kurzes Aufleuchten an der Hand: Licht zieht sich zusammen und blitzt. Hängt an "parent" und folgt ihm.
static func repulsor_charge(parent: Node3D) -> void:
	var fx := _spawn(parent, 0.5, Vector3.ZERO, false)
	if fx == null:
		return
	_flare(fx, "charge_glow", 0.65, 0.35).material_override = _rep_mat("charge")
	var p := _burst(_quad(), _mat("glow"), 14, 0.28)
	p.local_coords = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = 0.3
	p.initial_velocity_max = 0.0
	p.gravity = Vector3.ZERO
	p.radial_accel_min = -9.0
	p.radial_accel_max = -5.0
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.09
	p.scale_amount_curve = _curve("pop")
	p.color = Color(1.0, 0.6, 0.25, 1.0) * 2.5
	_go(fx, p)


# Thors Blitz: gezackt und verzweigt aus 40 m Höhe auf "target" (Weltposition), ca. 0.3 s
static func lightning_bolt(parent: Node, target: Vector3) -> void:
	var fx := _spawn(parent, 0.9, target)
	if fx == null:
		return
	var top := Vector3(randf_range(-2.5, 2.5), 40.0, randf_range(-2.5, 2.5))
	var main := _zigzag(top, Vector3.ZERO, 6, 0.2)
	var polys: Array = [{"pts": main, "w": 0.2}]
	for i in range(6):
		var k := randi_range(10, main.size() - 8)
		var s := main[k]
		var dir := Vector3(randf_range(-1, 1), -randf_range(0.3, 1.0), randf_range(-1, 1)).normalized()
		var sub := _zigzag(s, s + dir * randf_range(4.0, 12.0), 4, 0.25)
		polys.append({"pts": sub, "w": 0.08})
		if randf() < 0.5:
			var j := randi_range(3, sub.size() - 3)
			var dir2 := Vector3(randf_range(-1, 1), -randf_range(0.2, 0.8), randf_range(-1, 1)).normalized()
			polys.append({"pts": _zigzag(sub[j], sub[j] + dir2 * randf_range(2.0, 5.0), 3, 0.25), "w": 0.05})
	var mesh := _ribbon_mesh(polys)
	var layers: Array = []
	for key in ["bolt_glow", "bolt_core"]:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _mat(key)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 5.0
		fx.add_child(mi)
		mi.set_instance_shader_parameter("fade", 0.0)
		layers.append(mi)
	# Flackern: hell, kurz dunkler, wieder hell, ausklingen (~0.35 s)
	var tw := fx.create_tween()
	var prev := 0.0
	for st in [[1.0, 0.03], [0.3, 0.05], [1.0, 0.05], [0.55, 0.04], [0.85, 0.05], [0.0, 0.16]]:
		tw.tween_method(func(v: float):
			for mi2 in layers:
				mi2.set_instance_shader_parameter("fade", v), prev, st[0], st[1])
		prev = st[0]
	# Einschlag
	_sparks(fx, Vector3.UP, 75.0, 10 if _busy() else 30, 0.5, 5.0, 16.0, Color(0.65, 0.8, 1.0), -20.0, 2.2)
	_flare(fx, "flash_blue", 4.0, 0.3, Vector3(0, 0.8, 0))
	_flare(fx, "ring_flat_blue", 9.0, 0.4, Vector3(0, 0.08, 0), true)
	_dust(fx, Vector3.UP, 85.0, 6, 0.9, 1.5, 4.0, 1.0, Color(0.55, 0.55, 0.6, 0.35))
	_light(fx, Vector3(0, 3.0, 0), Color(0.65, 0.8, 1.0), 14.0, 24.0, 0.3)
	_scorch(parent, target, 1.3, 4.0)


# Schimmer-Schweif hinter dem fliegenden Schild (folgt dem Schild und klingt aus, wenn er weg ist)
static func shield_trail(shield: Node3D) -> void:
	if shield == null or not shield.is_inside_tree():
		return
	_trail(shield.get_parent(), shield, 0.11, 0.4, Color(0.75, 0.88, 1.0), true)


# Metallischer Funke: Strahlenstern, Schockring, Funkenregen
static func shield_impact(parent: Node, pos: Vector3) -> void:
	if _busy():
		return
	var fx := _spawn(parent, 0.7, pos)
	if fx == null:
		return
	_flare(fx, "flare_star", 1.1, 0.2)
	_flare(fx, "ring_blue", 1.7, 0.28)
	_sparks(fx, Vector3.UP, 180.0, 10 if _live > MAX_FX * 0.6 else 22, 0.4, 4.0, 11.0, Color(0.9, 0.95, 1.0), -7.0, 1.3)
	_sparks(fx, Vector3.UP, 180.0, 6, 0.35, 3.0, 8.0, Color(1.0, 0.8, 0.45), -7.0, 1.3)


# Hammerschlag: Staubwolke, Schockring am Boden, Funken, Brocken, Lichtblitz
static func hammer_impact(parent: Node, pos: Vector3) -> void:
	var fx := _spawn(parent, 1.4, pos)
	if fx == null:
		return
	_flare(fx, "ring_flat", 5.5, 0.4, Vector3(0, 0.1, 0), true)
	_flare(fx, "flare_hit", 3.2, 0.2, Vector3(0, 0.5, 0))
	_dust(fx, Vector3.UP, 90.0, 12, 1.0, 2.5, 5.5, 1.0, Color(0.6, 0.56, 0.5, 0.45))
	_sparks(fx, Vector3.UP, 70.0, 12 if _busy() else 26, 0.55, 4.0, 12.0, Color(1.0, 0.85, 0.5), -18.0, 1.6)
	_sparks(fx, Vector3.UP, 80.0, 8, 0.5, 4.0, 11.0, Color(0.6, 0.8, 1.0), -18.0, 1.6)
	var ch := _burst(_cube(), _mat("debris"), 9, 0.9)
	ch.direction = Vector3.UP
	ch.spread = 60.0
	ch.initial_velocity_min = 3.0
	ch.initial_velocity_max = 7.0
	ch.gravity = Vector3(0, -22, 0)
	ch.lifetime_randomness = 0.3
	ch.scale_amount_min = 0.5
	ch.scale_amount_max = 1.5
	ch.scale_amount_curve = _curve("shrink")
	ch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_go(fx, ch)
	_light(fx, Vector3(0, 1.2, 0), Color(1.0, 0.85, 0.6), 4.0, 10.0, 0.2)
	_scorch(parent, pos, 1.1, 4.0)


# Kleine Staub-/Rauchwolke, wenn ein Gegner fällt
static func death_puff(parent: Node, pos: Vector3) -> void:
	if _busy():
		return
	var fx := _spawn(parent, 1.4, pos + Vector3(0, 0.1, 0))
	if fx == null:
		return
	var p := _burst(_quad(), _mat("smoke"), 10, 1.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.45
	p.direction = Vector3.UP
	p.spread = 90.0
	p.flatness = 0.7
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, 0.4, 0)
	p.damping_min = 1.5
	p.damping_max = 3.0
	p.lifetime_randomness = 0.4
	p.scale_amount_min = 0.65
	p.scale_amount_max = 1.2
	p.scale_amount_curve = _curve("grow")
	p.color = Color(0.62, 0.57, 0.5, 0.5)
	p.color_ramp = _ramp("fade")
	_go(fx, p)
	_flare(fx, "ring_dust", 3.0, 0.5, Vector3(0, 0.02, 0), true)


# --- Blitz- und Schweif-Geometrie ----------------------------------------

static func _cube() -> BoxMesh:
	if not _cache.has("cube"):
		var b := BoxMesh.new()
		b.size = Vector3(0.07, 0.05, 0.06)
		_cache["cube"] = b
	return _cache["cube"]


# Zickzack-Linie von a nach b: immer wieder Mittelpunkte seitlich versetzen
static func _zigzag(a: Vector3, b: Vector3, depth: int, amp: float) -> PackedVector3Array:
	var pts := PackedVector3Array([a, b])
	for _d in range(depth):
		var np := PackedVector3Array()
		for i in range(pts.size() - 1):
			var p := pts[i]
			var q := pts[i + 1]
			var seg := q - p
			var dir := seg.normalized()
			var rnd := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
			var off := rnd - dir * rnd.dot(dir)
			var mid := (p + q) * 0.5
			if off.length() > 0.001:
				mid += off.normalized() * seg.length() * amp * randf_range(0.25, 1.0)
			np.append(p)
			np.append(mid)
		np.append(pts[pts.size() - 1])
		pts = np
	return pts


# Alle Linien als Bänder (zwei Eckpunkte pro Linienpunkt; der Shader dreht sie zur Kamera)
static func _ribbon_mesh(polys: Array) -> ArrayMesh:
	var v := PackedVector3Array()
	var nrm := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	for poly in polys:
		var pts: PackedVector3Array = poly["pts"]
		var n := pts.size()
		var base := v.size()
		for i in range(n):
			var tg := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
			var w: float = poly["w"] * randf_range(0.8, 1.2)
			# zum Ende der Äste hin dünner
			if poly["w"] < 0.15:
				w *= 1.0 - 0.8 * float(i) / float(n)
			for side in [-1.0, 1.0]:
				v.append(pts[i])
				nrm.append(tg)
				uv.append(Vector2(side, w))
				col.append(Color(1, 1, 1, 1))
		for i in range(n - 1):
			var a := base + i * 2
			idx.append_array(PackedInt32Array([a, a + 1, a + 2, a + 1, a + 3, a + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = col
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


# Schweif, der einem Knoten folgt (Geschoss, Schild). Er löscht sich selbst, wenn der Knoten weg ist.
static func _trail(parent: Node, target: Node3D, width: float, life: float, color: Color, sparkle: bool) -> void:
	var t := Trail.new()
	t.target = target
	t.width = width
	t.life = life
	t.color = color
	t.material_override = _mat("trail")
	if sparkle:
		var p := CPUParticles3D.new()
		p.amount = 14
		p.lifetime = 0.5
		p.local_coords = false
		p.mesh = _quad()
		p.material_override = _mat("glow")
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.initial_velocity_max = 0.6
		p.gravity = Vector3.ZERO
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.3
		p.direction = Vector3.UP
		p.spread = 180.0
		p.scale_amount_min = 0.04
		p.scale_amount_max = 0.1
		p.scale_amount_curve = _curve("pop")
		p.color = Color(color.r * 2.5, color.g * 2.5, color.b * 2.5, 1.0)
		t.sparkle = p
	parent.add_child(t)


class Trail extends MeshInstance3D:
	var target: Node3D
	var width := 0.2
	var life := 0.3
	var color := Color(0.6, 0.85, 1.0)
	var sparkle: CPUParticles3D
	var pts: Array[Vector3] = []
	var ages: Array[float] = []
	var im := ImmediateMesh.new()

	func _ready() -> void:
		mesh = im
		top_level = true
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		extra_cull_margin = 100.0
		global_transform = Transform3D.IDENTITY
		if sparkle:
			add_child(sparkle)
			sparkle.emitting = true

	func _process(delta: float) -> void:
		var alive := target != null and is_instance_valid(target) and target.is_inside_tree() and not target.is_queued_for_deletion()
		if alive:
			var p := target.global_position
			if pts.is_empty() or p.distance_squared_to(pts[0]) > 0.0004:
				pts.push_front(p)
				ages.push_front(0.0)
			if sparkle:
				sparkle.global_position = p
		elif sparkle and sparkle.emitting:
			sparkle.emitting = false
		for i in range(ages.size()):
			ages[i] += delta
		while not ages.is_empty() and ages[ages.size() - 1] > life:
			ages.pop_back()
			pts.pop_back()
		im.clear_surfaces()
		if pts.size() >= 2:
			im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
			var n := pts.size()
			for i in range(n):
				var tg := pts[maxi(i - 1, 0)] - pts[mini(i + 1, n - 1)]
				if tg.length() < 0.0001:
					tg = Vector3.UP
				tg = tg.normalized()
				var f := ages[i] / life
				var w := width * pow(maxf(1.0 - f, 0.0), 0.7) * minf(0.25 + f * 8.0, 1.0)
				var c := Color(color.r, color.g, color.b, 1.0 - f)
				for side in [-1.0, 1.0]:
					im.surface_set_normal(tg)
					im.surface_set_uv(Vector2(side, w))
					im.surface_set_color(c)
					im.surface_add_vertex(pts[i])
			im.surface_end()
		if not alive and pts.is_empty():
			queue_free()
