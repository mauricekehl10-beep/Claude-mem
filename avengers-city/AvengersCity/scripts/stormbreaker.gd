extends Node3D
# Stormbreaker, die Axt aus Uru (Thors Waffe aus Infinity War), nur aus Meshes und Shader (stormbreaker.gdshader).
# Lokale Koordinaten: Ursprung = Faust (Griffmitte), +Y = zum Axtkopf, Klinge zeigt nach +Z, Seitenflächen sind ±X.
#  - langer Holzstiel mit Lederwickel (Faust), Metallringen, Endkappe mit Schlaufe
#  - Kopf: breiter Block mit Rillen, grosse geschwungene Klinge nach vorn, Rückenblock mit zwei Dornen, Krone
#  - blau-weisse Energie: Adern im Metall, leuchtende Schneide, Kern-Schlitz, Schein, Funken-Wolken, Blitzbögen
# glow: 0 = dunkel, 1 = normal, 2 = voll aufgeladen (Angriff, Flug).

const VFX = preload("res://scripts/vfx.gd")
const SHADER = preload("res://scripts/stormbreaker.gdshader")
const Arcs = preload("res://scripts/storm_arcs.gd")

const HEAD_Y := 0.98  # Mitte des Kopfs über der Faust
const BLUE := Color(0.42, 0.70, 1.0)

static var _meshes := {}

var glow := 1.0: set = set_glow
var mats: Array = []
var light: OmniLight3D
var halo: MeshInstance3D
var halo_mat: ShaderMaterial
var arcs: Node3D
var wisps: CPUParticles3D
var edge_pt: Node3D  # Mitte der Schneide (Schweif)
var root_pt: Node3D  # Klingenwurzel am Block (Schweif)
var fade := 1.0: set = set_fade


func _init() -> void:
	name = "Stormbreaker"
	_build()


# ---------------------------------------------------------------- Meshes (einmal gebaut, geteilt)

static func _mesh(key: String) -> ArrayMesh:
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match key:
		"wood":
			_cyl(st, 0.0205, 0.0235, 0.98, Vector3(0, 0.30, 0))
		"leather":
			for i in range(14):
				_tor(st, 0.0195, 0.0300, Vector3(0, -0.04 + i * 0.0172, 0))
			for i in range(5):
				_tor(st, 0.0195, 0.0290, Vector3(0, 0.665 + i * 0.0172, 0))
		"metal":
			_metal(st)
		"core":
			_box(st, Vector3(0.124, 0.014, 0.150), Vector3(0, HEAD_Y, 0.0))
		"blade":
			_blade(st)
	var m: ArrayMesh
	if key == "blade":
		st.generate_normals()
	m = st.commit()
	_meshes[key] = m
	return m


static func _cyl(st: SurfaceTool, rt: float, rb: float, h: float, pos: Vector3, rot := Basis.IDENTITY, seg := 18) -> void:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	st.append_from(c, 0, Transform3D(rot, pos))


static func _box(st: SurfaceTool, size: Vector3, pos: Vector3, rot := Basis.IDENTITY) -> void:
	var b := BoxMesh.new()
	b.size = size
	st.append_from(b, 0, Transform3D(rot, pos))


static func _tor(st: SurfaceTool, inner: float, outer: float, pos: Vector3, rot := Basis.IDENTITY) -> void:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 18
	t.ring_segments = 6
	st.append_from(t, 0, Transform3D(rot, pos))


# Metallteile: Endkappe, Ringe, Hülse, Block mit Rillen, Rückenblock mit Dornen, Krone
static func _metal(st: SurfaceTool) -> void:
	var rx_back := Basis(Vector3.RIGHT, -PI / 2.0)  # Kegelspitze (+Y) nach -Z
	var rx_front := Basis(Vector3.RIGHT, PI / 2.0)  # Kegelspitze nach +Z
	# Griffende: Kappe, Schlaufe
	_cyl(st, 0.027, 0.034, 0.045, Vector3(0, -0.195, 0))
	_cyl(st, 0.036, 0.036, 0.012, Vector3(0, -0.222, 0))
	_tor(st, 0.020, 0.036, Vector3(0, -0.262, 0), Basis(Vector3.RIGHT, PI / 2.0))
	# Ringe am Stiel: Ende des Wickels, Mitte, vor dem Kopf
	for y in [0.215, 0.232, 0.40, 0.65]:
		_cyl(st, 0.029, 0.029, 0.012, Vector3(0, y, 0))
	# Hülse unter dem Kopf
	_cyl(st, 0.046, 0.032, 0.11, Vector3(0, 0.835, 0), Basis.IDENTITY, 20)
	_cyl(st, 0.050, 0.050, 0.014, Vector3(0, 0.785, 0), Basis.IDENTITY, 20)
	_cyl(st, 0.050, 0.050, 0.014, Vector3(0, 0.892, 0), Basis.IDENTITY, 20)
	# Kopfblock
	_box(st, Vector3(0.106, 0.180, 0.190), Vector3(0, HEAD_Y, 0.0))
	for i in range(5):
		_box(st, Vector3(0.118, 0.0085, 0.198), Vector3(0, HEAD_Y - 0.056 + i * 0.028, 0.0))
	_box(st, Vector3(0.112, 0.022, 0.206), Vector3(0, HEAD_Y + 0.101, 0.0))
	_box(st, Vector3(0.112, 0.022, 0.206), Vector3(0, HEAD_Y - 0.101, 0.0))
	# Krone oben und kleiner Dorn unten
	_cyl(st, 0.0, 0.034, 0.15, Vector3(0, HEAD_Y + 0.185, 0.0))
	_cyl(st, 0.0, 0.026, 0.07, Vector3(0, HEAD_Y - 0.145, 0.0), Basis(Vector3.RIGHT, PI))
	# Rücken: Block und zwei Dornen
	_box(st, Vector3(0.096, 0.150, 0.060), Vector3(0, HEAD_Y, -0.125))
	_box(st, Vector3(0.102, 0.168, 0.012), Vector3(0, HEAD_Y, -0.158))
	_cyl(st, 0.0, 0.024, 0.13, Vector3(0, HEAD_Y + 0.045, -0.225), rx_back)
	_cyl(st, 0.0, 0.024, 0.13, Vector3(0, HEAD_Y - 0.045, -0.225), rx_back)


# Klinge: geschwungene Sichel in der Y-Z-Ebene, nach aussen hin keilförmig dünn (COLOR.r = Nähe zur Schneide)
static func _bp(i: int, j: int, ns: int, nu: int, side: float) -> Vector3:
	var s := lerpf(-1.0, 1.0, float(i) / ns)
	var u := float(j) / nu
	var y := HEAD_Y + 0.17 * s
	var zo := 0.335 - 0.145 * s * s
	var zi := 0.09 + 0.093 * smoothstep(0.3, 1.0, absf(s))
	var th := 0.027 * pow(1.0 - u, 1.25) * (1.0 - 0.45 * s * s)
	return Vector3(side * th, y, lerpf(zi, zo, u))


static func _blade(st: SurfaceTool) -> void:
	var ns := 36
	var nu := 8
	for side in [1.0, -1.0]:
		for i in range(ns):
			for j in range(nu):
				var q := [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]
				var order := [0, 1, 2, 0, 2, 3] if side > 0.0 else [0, 2, 1, 0, 3, 2]
				for k in order:
					var ij: Array = q[k]
					st.set_color(Color(float(ij[1]) / nu, 0, 0, 1))
					st.add_vertex(_bp(ij[0], ij[1], ns, nu, side))


# ---------------------------------------------------------------- Aufbau

func _mat(kind: int, edge := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("edge_mode", edge)
	mats.append(m)
	return m


func _add(key: String, kind: int, edge := 0.0) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(key)
	mi.material_override = _mat(kind, edge)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build() -> void:
	_add("wood", 1)
	_add("leather", 2)
	_add("metal", 0)
	_add("blade", 0, 1.0)
	_add("core", 3)
	edge_pt = Node3D.new()
	edge_pt.position = Vector3(0, HEAD_Y, 0.40)
	add_child(edge_pt)
	root_pt = Node3D.new()
	root_pt.position = Vector3(0, HEAD_Y, 0.04)
	add_child(root_pt)
	# Schein um den Kopf
	halo_mat = VFX._flare_mat(BLUE, 1.6, 1.0, 0.5, 0.0, 1.0)
	halo = MeshInstance3D.new()
	halo.mesh = VFX._quad()
	halo.material_override = halo_mat
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.scale = Vector3.ONE * 0.6
	halo.position = Vector3(0, HEAD_Y, 0.12)
	add_child(halo)
	light = OmniLight3D.new()
	light.light_color = Color(0.45, 0.70, 1.0)
	light.omni_range = 5.0
	light.shadow_enabled = false
	light.position = Vector3(0, HEAD_Y, 0.15)
	add_child(light)
	# Blitzbögen am Kopf
	var a := Arcs.new()
	a.position = Vector3(0, HEAD_Y, 0.12)
	a.count = 3
	a.radius = 0.16
	a.seg_len = 0.34
	a.width = 0.010
	arcs = a
	add_child(a)
	# Funken-Wolken, die der Kopf hinter sich lässt
	var p := CPUParticles3D.new()
	p.amount = 16
	p.lifetime = 0.6
	p.local_coords = false
	p.mesh = VFX._quad()
	p.material_override = VFX._mat("glow")
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.14
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.6
	p.gravity = Vector3(0, 0.7, 0)
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.11
	p.scale_amount_curve = VFX._curve("pop")
	p.color = Color(0.40, 0.70, 1.0, 1.0) * 0.9
	p.position = Vector3(0, HEAD_Y, 0.15)
	wisps = p
	add_child(p)
	set_glow(glow)


func set_glow(v: float) -> void:
	glow = v
	for m in mats:
		m.set_shader_parameter("glow", v)
	if light:
		light.light_energy = 0.5 * v
	if halo_mat:
		halo_mat.set_shader_parameter("energy", 0.25 + 0.45 * v)
	if arcs:
		arcs.intensity = clampf(v - 0.45, 0.0, 1.0)
	if wisps:
		wisps.emitting = v > 0.2


# Auflösen/Erscheinen (0 = weg, 1 = ganz da)
func set_fade(v: float) -> void:
	fade = v
	for m in mats:
		m.set_shader_parameter("fade", v)
	if halo:
		halo.visible = v > 0.05
