extends RefCounted
# Hilfsfunktionen: Materialien, einfache Formen und geladene Assets (ohne Instanz nutzbar).

static var _index := {}


static func mat(c: Color, rough: float = 0.6, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


static func glow(c: Color, energy: float = 2.5) -> StandardMaterial3D:
	var m := mat(c, 0.3)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


static func box(parent: Node3D, size: Vector3, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


static func sphere(parent: Node3D, r: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


static func cyl(parent: Node3D, r: float, h: float, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


# Sucht eine Datei (z. B. "building-a.glb") rekursiv im Ordner res://Assets.
static func find_asset(file: String) -> String:
	if _index.is_empty():
		_index_dir("res://Assets")
		_index["_done"] = true
	return _index.get(file, "")


static func _index_dir(dir: String) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		return
	da.list_dir_begin()
	var name := da.get_next()
	while name != "":
		var path := dir.path_join(name)
		if da.current_is_dir():
			if not name.begins_with("."):
				_index_dir(path)
		elif not name.ends_with(".import") and not _index.has(name):
			_index[name] = path
		name = da.get_next()
	da.list_dir_end()


# Lädt ein Modell aus den Assets. Gibt null zurück, wenn es fehlt.
static func load_model(file: String) -> Node3D:
	var path := find_asset(file)
	if path == "":
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	return scene.instantiate() as Node3D


# Begrenzungsbox eines Modells, in Koordinaten des Modells selbst.
static func model_aabb(node: Node3D, xform: Transform3D = Transform3D.IDENTITY) -> AABB:
	var out := AABB()
	var has := false
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		out = xform * (node as MeshInstance3D).mesh.get_aabb()
		has = true
	for c in node.get_children():
		if c is Node3D:
			var sub := model_aabb(c, xform * (c as Node3D).transform)
			if sub.size != Vector3.ZERO:
				out = out.merge(sub) if has else sub
				has = true
	return out
