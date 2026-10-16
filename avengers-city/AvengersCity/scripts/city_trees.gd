extends RefCounted
# Baeume und Straeucher: Stamm + Laubkrone aus verformten Kugeln (Laub-Shader), als MultiMesh gesammelt.

const Tex = preload("res://scripts/city_tex.gd")
const M = preload("res://scripts/city_mats.gd")
const MB = preload("res://scripts/city_mesh.gd")

static var _foliage: ShaderMaterial
static var _meshes := {}

# gesammelte Instanzen je Typ: Array von [Transform3D, Color]
var inst := {"round": [], "oval": [], "conifer": [], "bush": [], "round_far": [], "conifer_far": []}


static func foliage_material() -> ShaderMaterial:
	if _foliage == null:
		_foliage = ShaderMaterial.new()
		_foliage.shader = load("res://scripts/city_foliage.gdshader")
		_foliage.set_shader_parameter("n_leaf", Tex.noise("leaf"))
		_foliage.set_shader_parameter("n_blotch", Tex.noise("blotch"))
	return _foliage


# Verformte Kugel (Laubbuschel) an das Array-Paket anhaengen
static func add_puff(arr: Dictionary, center: Vector3, r: Vector3, crown_center: Vector3, rng: RandomNumberGenerator, seg: int = 9, rings: int = 6, soft: float = 0.6) -> void:
	var v: PackedVector3Array = arr["v"]
	var n: PackedVector3Array = arr["n"]
	var c: PackedColorArray = arr["c"]
	var idx: PackedInt32Array = arr["i"]
	var base := v.size()
	var ph := rng.randf() * 10.0
	for i in range(rings + 1):
		var th := PI * float(i) / rings
		for j in range(seg):
			var ph2 := TAU * float(j) / seg
			var d := Vector3(sin(th) * cos(ph2), cos(th), sin(th) * sin(ph2))
			var jit := 1.0 + 0.16 * sin(ph + d.x * 3.1 + d.z * 2.3) + 0.1 * sin(ph * 1.7 + d.y * 4.3)
			var p := center + Vector3(d.x * r.x, d.y * r.y, d.z * r.z) * jit
			v.append(p)
			var radial := (p - crown_center).normalized()
			n.append(d.lerp(radial, soft).normalized())
			var ao := lerpf(0.5, 1.0, clampf(radial.y * 0.5 + 0.55, 0.0, 1.0))
			c.append(Color(ao, ao, ao, 1.0))
	for i in range(rings):
		for j in range(seg):
			var a := base + i * seg + j
			var b := base + i * seg + (j + 1) % seg
			var cc := base + (i + 1) * seg + j
			var dd := base + (i + 1) * seg + (j + 1) % seg
			idx.append(a)
			idx.append(cc)
			idx.append(b)
			idx.append(b)
			idx.append(cc)
			idx.append(dd)


static func _crown_mesh(puffs: Array, crown_center: Vector3, seed_v: int, seg: int = 9, rings: int = 6) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var arr := {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "i": PackedInt32Array()}
	for p in puffs:
		add_puff(arr, p[0], p[1], crown_center, rng, seg, rings)
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = arr["v"]
	a[Mesh.ARRAY_NORMAL] = arr["n"]
	a[Mesh.ARRAY_COLOR] = arr["c"]
	a[Mesh.ARRAY_INDEX] = arr["i"]
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	m.surface_set_material(0, foliage_material())
	return m


static func crown(kind: String) -> ArrayMesh:
	var key := "crown_" + kind
	var far := kind.ends_with("_far")
	if far:
		kind = kind.trim_suffix("_far")
	if _meshes.has(key):
		return _meshes[key]
	var puffs := []
	var cc := Vector3.ZERO
	match kind:
		"round":
			cc = Vector3(0, 6.2, 0)
			puffs = [[Vector3(0, 6.4, 0), Vector3(2.4, 2.1, 2.4)], [Vector3(1.7, 5.7, 0.6), Vector3(1.8, 1.5, 1.8)], [Vector3(-1.6, 5.8, -0.5), Vector3(1.8, 1.5, 1.8)],
				[Vector3(0.4, 5.6, -1.7), Vector3(1.7, 1.4, 1.7)], [Vector3(-0.3, 5.8, 1.8), Vector3(1.7, 1.4, 1.7)], [Vector3(0.6, 7.7, 0.3), Vector3(1.6, 1.3, 1.6)],
				[Vector3(-1.0, 7.3, -0.8), Vector3(1.4, 1.2, 1.4)], [Vector3(1.9, 6.9, -0.7), Vector3(1.3, 1.1, 1.3)]]
		"oval":
			cc = Vector3(0, 6.8, 0)
			puffs = [[Vector3(0, 6.2, 0), Vector3(1.9, 2.4, 1.9)], [Vector3(0.9, 8.0, 0.3), Vector3(1.5, 1.8, 1.5)], [Vector3(-0.8, 7.6, -0.5), Vector3(1.5, 1.7, 1.5)],
				[Vector3(0.7, 4.9, -0.6), Vector3(1.5, 1.4, 1.5)], [Vector3(-0.8, 5.2, 0.7), Vector3(1.4, 1.3, 1.4)], [Vector3(0, 9.4, 0), Vector3(1.0, 1.2, 1.0)]]
		"conifer":
			cc = Vector3(0, 5.0, 0)
			puffs = [[Vector3(0, 2.2, 0), Vector3(2.0, 1.2, 2.0)], [Vector3(0, 3.6, 0), Vector3(1.7, 1.2, 1.7)], [Vector3(0, 5.0, 0), Vector3(1.4, 1.2, 1.4)],
				[Vector3(0, 6.3, 0), Vector3(1.05, 1.1, 1.05)], [Vector3(0, 7.4, 0), Vector3(0.7, 1.0, 0.7)], [Vector3(0, 8.3, 0), Vector3(0.4, 0.8, 0.4)]]
		"bush":
			cc = Vector3(0, 0.6, 0)
			puffs = [[Vector3(0, 0.55, 0), Vector3(0.8, 0.6, 0.8)], [Vector3(0.6, 0.45, 0.3), Vector3(0.55, 0.5, 0.55)], [Vector3(-0.5, 0.45, -0.3), Vector3(0.55, 0.5, 0.55)]]
	var m := _crown_mesh(puffs, cc, hash(kind), 6 if far else 9, 3 if far else 6)
	_meshes[key] = m
	return m


static func trunk(kind: String) -> ArrayMesh:
	var key := "trunk_" + kind
	kind = kind.trim_suffix("_far")
	if _meshes.has(key):
		return _meshes[key]
	var mb := MB.new()
	var solid := M.solid()
	var bark := Color(0.36, 0.27, 0.19)
	match kind:
		"round":
			mb.scyl(solid, Vector3.ZERO, 0.24, 0.14, 4.2, bark, 8, 0.95)
			mb.tube(solid, Vector3(0, 3.6, 0), Vector3(1.0, 5.6, 0.3), 0.1, 0.05, 5, bark, 0.95)
			mb.tube(solid, Vector3(0, 3.8, 0), Vector3(-0.9, 5.6, -0.4), 0.1, 0.05, 5, bark, 0.95)
			mb.tube(solid, Vector3(0, 4.0, 0), Vector3(0.1, 6.4, 0.9), 0.09, 0.05, 5, bark, 0.95)
		"oval":
			mb.scyl(solid, Vector3.ZERO, 0.2, 0.1, 5.0, bark, 8, 0.95)
			mb.tube(solid, Vector3(0, 4.0, 0), Vector3(0.7, 6.2, 0.2), 0.08, 0.04, 5, bark, 0.95)
			mb.tube(solid, Vector3(0, 4.4, 0), Vector3(-0.6, 6.6, -0.3), 0.08, 0.04, 5, bark, 0.95)
		"conifer":
			mb.scyl(solid, Vector3.ZERO, 0.22, 0.1, 2.6, Color(0.2, 0.14, 0.1), 8, 0.95)
		"bush":
			pass
	var m := mb.build()
	_meshes[key] = m
	return m


# Baum eintragen. kind: round / oval / conifer / bush
func add(kind: String, pos: Vector3, rng: RandomNumberGenerator, scale_mul: float = 1.0) -> void:
	var s := rng.randf_range(0.8, 1.2) * scale_mul
	var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s)), pos)
	var col: Color
	var r := rng.randf()
	if kind.begins_with("conifer"):
		col = Color(0.07, 0.2, 0.1)
		col = col.lerp(Color(0.1, 0.26, 0.14), rng.randf())
	elif r < 0.62:
		col = Color(0.2, 0.42, 0.1).lerp(Color(0.12, 0.34, 0.1), rng.randf())
	elif r < 0.84:
		col = Color(0.36, 0.5, 0.12).lerp(Color(0.28, 0.46, 0.1), rng.randf())
	elif r < 0.94:
		col = Color(0.52, 0.36, 0.1).lerp(Color(0.46, 0.4, 0.08), rng.randf())
	else:
		col = Color(0.42, 0.14, 0.1)
	inst[kind].append([xf, col])


func commit(parent: Node3D) -> void:
	for kind in inst:
		var list: Array = inst[kind]
		if list.is_empty():
			continue
		# Krone
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = crown(kind)
		mm.instance_count = list.size()
		for i in range(list.size()):
			mm.set_instance_transform(i, list[i][0])
			mm.set_instance_color(i, list[i][1])
		var mi := MultiMeshInstance3D.new()
		mi.name = "Crowns_" + kind
		mi.multimesh = mm
		parent.add_child(mi)
		# Stamm
		if kind != "bush":
			var mm2 := MultiMesh.new()
			mm2.transform_format = MultiMesh.TRANSFORM_3D
			mm2.mesh = trunk(kind)
			mm2.instance_count = list.size()
			for i in range(list.size()):
				mm2.set_instance_transform(i, list[i][0])
			var mi2 := MultiMeshInstance3D.new()
			mi2.name = "Trunks_" + kind
			mi2.multimesh = mm2
			parent.add_child(mi2)
