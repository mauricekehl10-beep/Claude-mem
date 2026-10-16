extends RefCounted
# Geparkte Autos entlang der Bordsteine. Pro Strassenabschnitt und Typ ein MultiMesh (3 Detailstufen per Sichtweite),
# Kollision als Boxen. Jedes Auto ist einsteigbar: find_near() sucht, take() nimmt es aus der Welt, add_dynamic() stellt abgestellte Autos wieder hin.

const CM = preload("res://scripts/car_model.gd")

const CELL := 24.0  # Kantenlaenge der Gitterzellen fuer Sichtweite und Suche
const LOD_RANGES := [[0.0, 62.0], [58.0, 150.0], [145.0, 330.0]]

var rng := RandomNumberGenerator.new()
var recs := []  # alle Autos: Dictionary type, xf, paint, alive, shape, slots, cell
var cells := {}  # Vector2i -> Array von recs (fuer die Suche)
var dynamics := []  # abgestellte Autos des Spielers (eigene Knoten)
var parent_node: Node3D


# Autos am Bordstein eines Blocks. Positionen block-lokal, cx/cz = Blockmitte.
func park_block(parent: Node3D, cx: float, cz: float, fill: float, ix: int, iz: int) -> void:
	parent_node = parent
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
			var type := CM.pick_type(rng, false)
			var paint := CM.pick_paint(rng, type)
			var inf := CM.info(type)
			var size: Vector3 = inf["size"]
			var tt := -22.75 + 6.5 * k + rng.randf_range(-0.35, 0.35)
			var lp := t * tt + n * (31.2 + rng.randf_range(-0.12, 0.12))
			var ang := yaw + PI + rng.randf_range(-0.025, 0.025)  # Modellfront ist -Z
			var basis := Basis(Vector3.UP, ang)
			var xf := Transform3D(basis, Vector3(cx + lp.x, 0.0, cz + lp.z))
			var cs := _shape(size)
			cs.transform = Transform3D(basis, Vector3(lp.x, size.y * 0.45, lp.z))
			body.add_child(cs)
			var r := {"type": type, "xf": xf, "paint": paint, "alive": true, "shape": cs, "slots": [], "size": size, "node": null}
			recs.append(r)
			var cell := Vector2i(floori(xf.origin.x / CELL), floori(xf.origin.z / CELL))
			r["cell"] = cell
			if not cells.has(cell):
				cells[cell] = []
			cells[cell].append(r)
			any = true
	if any:
		parent.add_child(body)
	else:
		body.free()


func _shape(size: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x * 0.97, size.y * 0.9, size.z * 0.98)
	cs.shape = bs
	return cs


# MultiMeshes anlegen: je Zelle und Typ und Detailstufe
func commit(parent: Node3D) -> void:
	parent_node = parent
	for cell in cells:
		var by_type := {}
		for r in cells[cell]:
			if not by_type.has(r["type"]):
				by_type[r["type"]] = []
			by_type[r["type"]].append(r)
		for type in by_type:
			var list: Array = by_type[type]
			for lod in range(3):
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.use_custom_data = true
				mm.mesh = CM.mesh(type, lod, true)
				mm.instance_count = list.size()
				for i in range(list.size()):
					var r: Dictionary = list[i]
					mm.set_instance_transform(i, r["xf"])
					var p: Color = r["paint"]
					mm.set_instance_custom_data(i, Color(p.r, p.g, p.b, 0.0))
					r["slots"].append([mm, i])
				var mi := MultiMeshInstance3D.new()
				mi.name = "Cars_%s_%d_%d_%d" % [type, lod, cell.x, cell.y]
				mi.multimesh = mm
				mi.visibility_range_begin = LOD_RANGES[lod][0]
				mi.visibility_range_end = LOD_RANGES[lod][1]
				mi.visibility_range_begin_margin = 6.0
				mi.visibility_range_end_margin = 6.0
				mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
				if lod == 2:
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				parent.add_child(mi)


# Oriented-Box-Abstand von p (Weltpunkt) zu einem Auto (Aussenflaeche)
static func box_dist(p: Vector3, xf: Transform3D, size: Vector3) -> float:
	var l := xf.affine_inverse() * p
	var dx := maxf(absf(l.x) - size.x * 0.5, 0.0)
	var dz := maxf(absf(l.z) - size.z * 0.5, 0.0)
	return sqrt(dx * dx + dz * dz)


# Naechstes einsteigbares Auto (geparkt oder abgestellt), leeres Dictionary wenn keins in max_d
func find_near(p: Vector3, max_d: float) -> Dictionary:
	var best := {}
	var bd := max_d
	var c := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var key := Vector2i(c.x + dx, c.y + dz)
			if not cells.has(key):
				continue
			for r in cells[key]:
				if not r["alive"]:
					continue
				var d := box_dist(p, r["xf"], r["size"])
				if d < bd:
					bd = d
					best = r
	for r in dynamics:
		if not r["alive"]:
			continue
		var d := box_dist(p, r["xf"], r["size"])
		if d < bd:
			bd = d
			best = r
	if not best.is_empty():
		return {"rec": best, "dist": bd}
	return {}


# Auto aus der Welt nehmen (Original-Eintrag per Referenz suchen)
func take(r: Dictionary) -> void:
	if r.is_empty() or not r["alive"]:
		return
	r["alive"] = false
	for s in r["slots"]:
		var mm: MultiMesh = s[0]
		mm.set_instance_transform(s[1], Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -50, 0)))
	var cs: CollisionShape3D = r["shape"]
	if cs != null and is_instance_valid(cs):
		cs.get_parent().remove_child(cs)
		cs.free()
		r["shape"] = null
	var node: Node = r["node"]
	if node != null and is_instance_valid(node):
		node.queue_free()
		r["node"] = null
		dynamics.erase(r)



# Abgestelltes Auto des Spielers: bleibt stehen, ist spaeter wieder einsteigbar
func add_dynamic(type: String, xf: Transform3D, paint: Color) -> Dictionary:
	var size: Vector3 = CM.info(type)["size"]
	var body := StaticBody3D.new()
	body.name = "DroppedCar"
	body.transform = xf
	var cs := _shape(size)
	cs.position = Vector3(0, size.y * 0.45, 0)
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = CM.mesh(type, 0, true)
	mi.set_surface_override_material(0, CM.single_material(type, paint))
	body.add_child(mi)
	parent_node.add_child(body)
	var r := {"type": type, "xf": xf, "paint": paint, "alive": true, "shape": cs, "slots": [], "size": size, "node": body}
	dynamics.append(r)
	recs.append(r)
	return r
