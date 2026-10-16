extends RefCounted
# Boden der Stadt: Asphalt-Ebene (Strassenraster im Shader) und erhoehte Gehweg-Bloecke mit Bordstein.

const Tex = preload("res://scripts/city_tex.gd")
const MB = preload("res://scripts/city_mesh.gd")

const STEP := 72.0
const PAD_HALF := 30.0
const PAD_R := 3.5
const CURB_H := 0.15

static var _ground_mat: ShaderMaterial
static var _pad_mat: ShaderMaterial


static func ground_material() -> ShaderMaterial:
	if _ground_mat == null:
		var m := ShaderMaterial.new()
		m.shader = load("res://scripts/city_ground.gdshader")
		m.set_shader_parameter("n_blotch", Tex.noise("blotch"))
		m.set_shader_parameter("n_grain", Tex.noise("grain"))
		m.set_shader_parameter("n_crack", Tex.noise("crack"))
		_ground_mat = m
	return _ground_mat


static func pad_material() -> ShaderMaterial:
	if _pad_mat == null:
		var m := ShaderMaterial.new()
		m.shader = load("res://scripts/city_pad.gdshader")
		m.set_shader_parameter("n_blotch", Tex.noise("blotch"))
		m.set_shader_parameter("n_grain", Tex.noise("grain"))
		m.set_shader_parameter("n_crack", Tex.noise("crack"))
		_pad_mat = m
	return _pad_mat


# Umriss eines Blocks mit abgerundeten Ecken (im Uhrzeigersinn von oben gesehen, steigender Winkel)
static func outline(half: float, r: float, seg: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var c := half - r
	var centers := [Vector2(c, c), Vector2(-c, c), Vector2(-c, -c), Vector2(c, -c)]
	for k in range(4):
		for i in range(seg + 1):
			var a := deg_to_rad(k * 90.0 + 90.0 * i / seg)
			pts.append(centers[k] + Vector2(cos(a), sin(a)) * r)
	return pts


# ring = Anzahl Block-Ringe um das 5x5-Kernraster (nur Optik/Kollision der Gehwege)
static func build(parent: Node3D, core_half_blocks: int, ring: int) -> void:
	# Asphalt-Ebene (riesig, nur Empfaenger fuer Schatten)
	var gm := MeshInstance3D.new()
	gm.name = "Ground"
	var pm := PlaneMesh.new()
	pm.size = Vector2(7000, 7000)
	gm.mesh = pm
	gm.material_override = ground_material()
	gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(gm)

	# Gehweg-Bloecke
	var mb := MB.new()
	var mat := pad_material()
	var pts := outline(PAD_HALF, PAD_R, 8)
	var body := StaticBody3D.new()
	body.name = "PadCollision"
	parent.add_child(body)
	var hull_top := PackedVector3Array()
	var hull_all := PackedVector3Array()
	for p in pts:
		hull_all.append(Vector3(p.x, CURB_H, p.y))
	# Flanke: unten 0.35 m weiter aussen (flache Rampe, damit man den Bordstein hochlaufen kann)
	for p in pts:
		var cc := Vector2(signf(p.x), signf(p.y)) * (PAD_HALF - PAD_R)
		var dir := (p - cc).normalized()
		hull_all.append(Vector3(p.x + dir.x * 0.4, 0.0, p.y + dir.y * 0.4))
	var shape := ConvexPolygonShape3D.new()
	shape.points = hull_all
	var n := core_half_blocks + ring
	for ix in range(-n, n + 1):
		for iz in range(-n, n + 1):
			var cx := ix * STEP
			var cz := iz * STEP
			add_pad(mb, mat, pts, cx, cz)
			var cs := CollisionShape3D.new()
			cs.shape = shape
			cs.position = Vector3(cx, 0, cz)
			body.add_child(cs)
	mb.instance(parent, "Pads")


static func add_pad(mb, mat: Material, pts: PackedVector2Array, cx: float, cz: float) -> void:
	var h := CURB_H
	var center := Vector3(cx, h, cz)
	var cnt := pts.size()
	for i in range(cnt):
		var p0 := pts[i]
		var p1 := pts[(i + 1) % cnt]
		var a := Vector3(cx + p0.x, h, cz + p0.y)
		var b := Vector3(cx + p1.x, h, cz + p1.y)
		mb.tri(mat, center, b, a, Vector3.UP)
		var e := p1 - p0
		var nrm := Vector3(e.y, 0.0, -e.x).normalized()
		var bl := Vector3(b.x, -0.1, b.z)
		var br := Vector3(a.x, -0.1, a.z)
		mb.quad(mat, bl, br, a, b, nrm, 0.0, 1.0, 0.0, 1.0)


# Umland: Huegelkette am Horizont und Waldstuecke rund um die Stadt
static func outskirts(parent: Node3D, trees, city_half: float) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 31
	noise.frequency = 0.9
	noise.fractal_octaves = 4
	var seg := 160
	var rings := 6
	var r0 := 1000.0
	var r1 := 3200.0
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in range(rings + 1):
		var r := lerpf(r0, r1, float(i) / rings)
		for j in range(seg + 1):
			var a := TAU * float(j) / seg
			var hn := noise.get_noise_2d(cos(a) * 3.0, sin(a) * 3.0) * 0.5 + 0.5
			var ridge := noise.get_noise_2d(cos(a) * 9.0 + r * 0.0007, sin(a) * 9.0) * 0.5 + 0.5
			var t := smoothstep(0.0, 0.35, float(i) / rings)
			var h := t * (60.0 + 330.0 * hn * hn + 70.0 * ridge) * (1.0 - 0.35 * smoothstep(0.7, 1.0, float(i) / rings))
			verts.append(Vector3(cos(a) * r, h - 2.0 if i == 0 else h, sin(a) * r))
			var g := 0.25 + 0.15 * ridge
			cols.append(Color(g * 0.7, g + 0.1, g * 0.55))
			uv2.append(Vector2(1.0, 0.0))
	for i in range(rings):
		for j in range(seg):
			var a := i * (seg + 1) + j
			var b := a + 1
			var c := a + seg + 1
			var d := c + 1
			# Blick von oben, Uhrzeigersinn
			idx.append(a)
			idx.append(c)
			idx.append(b)
			idx.append(b)
			idx.append(c)
			idx.append(d)
	var norms := PackedVector3Array()
	norms.resize(verts.size())
	for i in range(norms.size()):
		norms[i] = Vector3.UP
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uv2
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	# Normalen aus der Geometrie glaetten
	var st := SurfaceTool.new()
	st.create_from(mesh, 0)
	st.generate_normals()
	var mesh2 := st.commit()
	mesh2.surface_set_material(0, load("res://scripts/city_mats.gd").solid())
	var mi := MeshInstance3D.new()
	mi.name = "Hills"
	mi.mesh = mesh2
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	# Waldstuecke
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var fn := FastNoiseLite.new()
	fn.seed = 5
	fn.frequency = 0.004
	var placed := 0
	var tries := 0
	while placed < 1400 and tries < 12000:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(city_half + 25.0, 1000.0)
		var p := Vector2(cos(a), sin(a)) * r
		var dens := fn.get_noise_2d(p.x, p.y) * 0.5 + 0.5
		if rng.randf() > dens * 1.3:
			continue
		var kind := "conifer" if rng.randf() < 0.45 else "round"
		trees.add(kind + "_far", Vector3(p.x, 0.0, p.y), rng, rng.randf_range(1.4, 2.4))
		placed += 1
