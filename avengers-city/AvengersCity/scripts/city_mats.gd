extends RefCounted
# Material-Fabrik der Stadt (alles gecacht, damit Meshes sich Materialien teilen).

const Tex = preload("res://scripts/city_tex.gd")

static var _c := {}
static var _sh := {}


static func shader(path: String) -> Shader:
	if not _sh.has(path):
		_sh[path] = load(path)
	return _sh[path]


static func _noise(m: ShaderMaterial, names: Array) -> void:
	for n in names:
		m.set_shader_parameter("n_" + n, Tex.noise(n))


# Fassadenmaterial aus einem Stil-Dictionary
static func facade(key: String, st: Dictionary) -> ShaderMaterial:
	if _c.has(key):
		return _c[key]
	var m := ShaderMaterial.new()
	m.shader = shader("res://scripts/city_facade.gdshader")
	m.set_shader_parameter("kind", int(st.get("kind", 0)))
	m.set_shader_parameter("wall_col", st.get("wall", Color(0.5, 0.25, 0.2)))
	m.set_shader_parameter("trim_col", st.get("trim", Color(0.7, 0.66, 0.6)))
	m.set_shader_parameter("frame_col", st.get("frame", Color(0.85, 0.85, 0.82)))
	m.set_shader_parameter("glass_col", st.get("glass", Color(0.05, 0.09, 0.14)))
	m.set_shader_parameter("win_size", st.get("win", Vector2(1.15, 1.75)))
	m.set_shader_parameter("sill_h", float(st.get("sill", 0.95)))
	m.set_shader_parameter("glass_metal", float(st.get("gm", 0.15)))
	m.set_shader_parameter("glass_rough", float(st.get("gr", 0.06)))
	m.set_shader_parameter("grime", float(st.get("grime", 0.6)))
	m.set_shader_parameter("arch_top", float(st.get("arch", 0.0)))
	_noise(m, ["blotch", "grain"])
	_c[key] = m
	return m


static func solid() -> ShaderMaterial:
	if not _c.has("solid"):
		var m := ShaderMaterial.new()
		m.shader = shader("res://scripts/city_solid.gdshader")
		_noise(m, ["blotch", "grain"])
		_c["solid"] = m
	return _c["solid"]


static func roof() -> ShaderMaterial:
	if not _c.has("roof"):
		var m := ShaderMaterial.new()
		m.shader = shader("res://scripts/city_roof.gdshader")
		_noise(m, ["blotch", "grain", "crack"])
		_c["roof"] = m
	return _c["roof"]


# LED-Werbeflaeche (animiert)
static func screen() -> ShaderMaterial:
	if not _c.has("screen"):
		var m := ShaderMaterial.new()
		m.shader = shader("res://scripts/city_screen.gdshader")
		_c["screen"] = m
	return _c["screen"]


# Dampfpuffs (Billboard-MultiMesh)
static func steam() -> ShaderMaterial:
	if not _c.has("steam"):
		var m := ShaderMaterial.new()
		m.shader = shader("res://scripts/city_steam.gdshader")
		_noise(m, ["blotch"])
		m.render_priority = 2
		_c["steam"] = m
	return _c["steam"]


# Wasser (Fluss/Teich)
static func water() -> ShaderMaterial:
	if not _c.has("water"):
		var m := ShaderMaterial.new()
		m.shader = shader("res://scripts/city_water.gdshader")
		_noise(m, ["blotch", "grain"])
		_c["water"] = m
	return _c["water"]


# Eisengitter: 0 Rost, 1 Gelaender, 2 Zaunstaebe, 3 Netz
static func iron(kind: int, col: Color = Color(0.045, 0.05, 0.05)) -> ShaderMaterial:
	var key := "iron%d_%s" % [kind, col.to_html()]
	if not _c.has(key):
		var m := ShaderMaterial.new()
		m.shader = shader("res://scripts/city_iron.gdshader")
		m.set_shader_parameter("kind", kind)
		m.set_shader_parameter("iron_col", col)
		_c[key] = m
	return _c[key]
