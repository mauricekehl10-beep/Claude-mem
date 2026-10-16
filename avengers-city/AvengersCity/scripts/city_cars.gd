extends RefCounted
# Geparkte Autos entlang der Bordsteine (Kenney-Modelle, zu je einem Mesh zusammengefasst, per MultiMesh gezeichnet, Lack umgefaerbt).

const U = preload("res://scripts/util.gd")

const CAR_SCALE := Vector3(1.25, 1.3, 1.45)

# Modell, Gewicht, Grundfarbton des Lacks (0..1), Laenge (m, nach Skalierung ca.)
const MODELS := [
	["sedan.glb", 5.0, 0.02, true],
	["sedan-sports.glb", 2.0, 0.03, true],
	["hatchback-sports.glb", 2.5, 0.44, true],
	["suv.glb", 4.0, 0.43, true],
	["suv-luxury.glb", 2.0, 0.10, true],
	["van.glb", 2.0, 0.64, true],
	["truck.glb", 1.0, 0.40, true],
	["taxi.glb", 2.0, 0.10, false],
	["delivery.glb", 0.7, 0.0, false],
	["police.glb", 0.3, 0.0, false],
	["ambulance.glb", 0.1, 0.0, false],
]

# Farbvarianten: Zielton (-1 = unbunt), Saettigung, Helligkeit, Gewicht
const PAINTS := [
	[-1.0, 0.0, 1.2, 24.0], [-1.0, 0.0, 0.2, 13.0], [-1.0, 0.0, 0.78, 14.0], [-1.0, 0.0, 0.42, 8.0],
	[0.6, 0.85, 0.9, 7.0], [0.0, 1.0, 1.0, 7.0], [0.62, 0.8, 0.5, 5.0], [0.38, 0.7, 0.55, 3.0],
	[0.12, 0.9, 1.0, 2.0], [0.07, 0.95, 1.0, 2.0], [0.5, 0.7, 0.8, 2.0], [0.07, 0.6, 0.42, 3.0], [0.96, 0.85, 0.7, 2.0],
]

static var _cache := {}
var inst := {}  # Modell -> Array von [Transform3D, Color]
var rng := RandomNumberGenerator.new()


# Alle Teile eines Modells zu einem Mesh zusammenfassen (mit Skalierung und Bodenanpassung)
static func merged(file: String) -> Array:
	if _cache.has(file):
		return _cache[file]
	var model := U.load_model(file)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var tex: Texture2D = null
	_collect(model, Transform3D.IDENTITY, verts, norms, uvs, idx, [tex])
	var tex_holder := [null]
	_find_tex(model, tex_holder)
	var aabb := AABB(verts[0], Vector3.ZERO)
	for v in verts:
		aabb = aabb.expand(v)
	var shift := Vector3(-(aabb.position.x + aabb.size.x * 0.5), -aabb.position.y, -(aabb.position.z + aabb.size.z * 0.5))
	for i in range(verts.size()):
		verts[i] = (verts[i] + shift) * CAR_SCALE
		norms[i] = Vector3(norms[i].x / CAR_SCALE.x, norms[i].y / CAR_SCALE.y, norms[i].z / CAR_SCALE.z).normalized()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/city_car.gdshader")
	m.set_shader_parameter("palette", tex_holder[0])
	mesh.surface_set_material(0, m)
	var out := [mesh, aabb.size * CAR_SCALE, m]
	model.free()
	_cache[file] = out
	return out


static func _find_tex(n: Node, holder: Array) -> void:
	var mi := n as MeshInstance3D
	if mi and mi.mesh and holder[0] == null:
		var bm := mi.get_active_material(0) as BaseMaterial3D
		if bm:
			holder[0] = bm.albedo_texture
	for c in n.get_children():
		_find_tex(c, holder)


static func _collect(n: Node, xf: Transform3D, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, idx: PackedInt32Array, _t: Array) -> void:
	var cur := xf
	if n is Node3D:
		cur = xf * (n as Node3D).transform
	var mi := n as MeshInstance3D
	if mi and mi.mesh and mi.mesh.get_surface_count() > 0:
		var a := mi.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var nn: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
		var ii: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var base := verts.size()
		for i in range(v.size()):
			verts.append(cur * v[i])
			norms.append((cur.basis * nn[i]).normalized())
			uvs.append(uv[i] if i < uv.size() else Vector2.ZERO)
		if ii.is_empty():
			for i in range(v.size()):
				idx.append(base + i)
		else:
			for i in ii:
				idx.append(base + i)
	for c in n.get_children():
		_collect(c, cur, verts, norms, uvs, idx, _t)


func pick_model() -> Array:
	var total := 0.0
	for m in MODELS:
		total += m[1]
	var r := rng.randf() * total
	for m in MODELS:
		r -= m[1]
		if r <= 0.0:
			return m
	return MODELS[0]


func pick_paint(base_hue: float, recolor: bool) -> Color:
	if not recolor:
		return Color(0.0, 1.0, 1.0, 0.0)
	var total := 0.0
	for p in PAINTS:
		total += p[3]
	var r := rng.randf() * total
	for p in PAINTS:
		r -= p[3]
		if r <= 0.0:
			if p[0] < 0.0:
				return Color(0.0, p[1], p[2], 0.0)
			return Color(fposmod(p[0] - base_hue, 1.0), p[1], p[2], 0.0)
	return Color(0.0, 0.0, 1.2, 0.0)


# Autos am Bordstein eines Blocks. Positionen block-lokal, cx/cz = Blockmitte.
func park_block(parent: Node3D, cx: float, cz: float, fill: float, ix: int, iz: int) -> void:
	rng.seed = hash(Vector2i(ix, iz)) + 4711
	var body := StaticBody3D.new()
	body.name = "ParkedCars"
	body.position = Vector3(cx, 0, cz)
	var any := false
	var sides := [
		[Vector3(0, 0, 1), Vector3(1, 0, 0), -PI * 0.5],
		[Vector3(0, 0, -1), Vector3(-1, 0, 0), PI * 0.5],
		[Vector3(1, 0, 0), Vector3(0, 0, -1), 0.0],
		[Vector3(-1, 0, 0), Vector3(0, 0, 1), PI],
	]
	for s in sides:
		var n: Vector3 = s[0]
		var t: Vector3 = s[1]
		var yaw: float = s[2]
		for k in range(8):
			if rng.randf() > fill:
				continue
			var md := pick_model()
			var info := merged(md[0])
			var size: Vector3 = info[1]
			var tt := -22.75 + 6.5 * k + rng.randf_range(-0.35, 0.35)
			var lp := t * tt + n * (31.2 + rng.randf_range(-0.12, 0.12))
			var ang := yaw + rng.randf_range(-0.025, 0.025)
			var basis := Basis(Vector3.UP, ang)
			var xf := Transform3D(basis, Vector3(cx + lp.x, 0.0, cz + lp.z))
			if not inst.has(md[0]):
				inst[md[0]] = []
			inst[md[0]].append([xf, pick_paint(md[2], md[3])])
			# Kollision
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(size.x, size.y * 0.9, size.z)
			cs.shape = bs
			cs.transform = Transform3D(basis, Vector3(lp.x, size.y * 0.45, lp.z))
			body.add_child(cs)
			any = true
	if any:
		parent.add_child(body)
	else:
		body.free()


func commit(parent: Node3D) -> void:
	for f in inst:
		var list: Array = inst[f]
		var info := merged(f)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = info[0]
		mm.instance_count = list.size()
		for i in range(list.size()):
			mm.set_instance_transform(i, list[i][0])
			mm.set_instance_custom_data(i, list[i][1])
		var mi := MultiMeshInstance3D.new()
		mi.name = "Cars_" + f.get_basename()
		mi.multimesh = mm
		parent.add_child(mi)
