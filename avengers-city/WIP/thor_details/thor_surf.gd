extends RefCounted
# Körperoberfläche von Thor in der Ruhepose (nach dem Verdicken in mixamo_model.gd). Damit lassen sich Rüstungsplatten bauen,
# die dem Körper genau folgen: die Körperfläche vorn/hinten wird aus den Netzpunkten bestimmt, die Platte sitzt darüber.
# Koordinaten: Ruhepose (T-Pose, Meter, Füsse y=0, +Z vorn, +X links).

const T = preload("res://scripts/thor_suit.gd")

const CELL := 0.016
const OX := 0.36   # Gitter-Ursprung (x + OX)
const SIGMA := 0.0095
const ZMID := -0.02  # Rumpfmitte: davor = Brust, dahinter = Rücken

static var _verts := PackedVector3Array()
static var _cells := {}
static var _src: Mesh


# Körpernetz aus dem Skelett holen: Punkte des Rumpfs in ein grobes Gitter sortieren (einmal pro Netz, dann zwischengespeichert)
static func setup(skel: Skeleton3D) -> bool:
	var mi := skel.get_node_or_null("Alpha_Surface") as MeshInstance3D
	if mi == null or mi.mesh == null:
		return false
	if _src == mi.mesh and not _cells.is_empty():
		return true
	_src = mi.mesh
	_cells = {}
	var arr := mi.mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	_verts = vs
	for i in range(vs.size()):
		var v := vs[i]
		if absf(v.x) > 0.34 or v.y < 0.55 or v.y > 1.65:
			continue
		var k := _key(int(floor((v.x + OX) / CELL)), int(floor(v.y / CELL)))
		var a: PackedInt32Array = _cells.get(k, PackedInt32Array())
		a.append(i)
		_cells[k] = a
	return not _cells.is_empty()


static func release() -> void:
	pass


static func _key(ix: int, iy: int) -> int:
	return ix * 4096 + iy


# Oberfläche vorn (back = false) oder hinten bei (x, y): [Punkt, Normale]. Das Netz hat innen Teile (Gelenke, Rippen):
# nur die äusserste Schicht zählt (nächste Punkte bis 1,5 cm hinter dem äussersten), durch sie wird eine Ebene gelegt.
static func at(x: float, y: float, back: bool = false) -> Array:
	var ix := int(floor((x + OX) / CELL))
	var iy := int(floor(y / CELL))
	var lim := (SIGMA * 2.4) * (SIGMA * 2.4)
	var sgn := -1.0 if back else 1.0
	var zout := -9.0
	var near: Array = []
	for cx in range(ix - 1, ix + 2):
		for cy in range(iy - 1, iy + 2):
			var a: PackedInt32Array = _cells.get(_key(cx, cy), PackedInt32Array())
			for i in a:
				var v := _verts[i]
				var dx := v.x - x
				var dy := v.y - y
				if dx * dx + dy * dy > lim:
					continue
				near.append(v)
				zout = maxf(zout, v.z * sgn)
	var dz := -1.0 if back else 1.0
	if near.is_empty():
		return [Vector3(x, y, 0.0), Vector3(0, 0, dz)]
	var sw := 0.0
	var sx := 0.0
	var sy := 0.0
	var sxx := 0.0
	var sxy := 0.0
	var syy := 0.0
	var sz := 0.0
	var sxz := 0.0
	var syz := 0.0
	var k2 := -1.0 / (2.0 * SIGMA * SIGMA)
	for v in near:
		if v.z * sgn < zout - 0.015:
			continue
		var dx: float = v.x - x
		var dy: float = v.y - y
		var w := exp((dx * dx + dy * dy) * k2)
		sw += w
		sx += w * dx
		sy += w * dy
		sxx += w * dx * dx
		sxy += w * dx * dy
		syy += w * dy * dy
		sz += w * v.z
		sxz += w * dx * v.z
		syz += w * dy * v.z
	# Ebene z = a + b*dx + c*dy (gewichtete kleinste Quadrate)
	var det := sw * (sxx * syy - sxy * sxy) - sx * (sx * syy - sxy * sy) + sy * (sx * sxy - sxx * sy)
	var za := sz / sw
	var gb := 0.0
	var gc := 0.0
	if absf(det) > 1e-13 * sw:
		var d1 := sz * (sxx * syy - sxy * sxy) - sx * (sxz * syy - sxy * syz) + sy * (sxz * sxy - sxx * syz)
		var d2 := sw * (sxz * syy - sxy * syz) - sz * (sx * syy - sxy * sy) + sy * (sx * syz - sxz * sy)
		var d3 := sw * (sxx * syz - sxz * sxy) - sx * (sx * syz - sxz * sy) + sz * (sx * sxy - sxx * sy)
		za = d1 / det
		gb = clampf(d2 / det, -1.5, 1.5)
		gc = clampf(d3 / det, -1.5, 1.5)
	var n := Vector3(-gb, -gc, 1.0)
	if back:
		n = Vector3(gb, gc, -1.0)
	return [Vector3(x, y, za), n.normalized()]


# Gitter von Punkten (rows x cols) mit Normalen aus den Nachbarn in ein Netz schreiben.
# P = Punkte, Nn = Anhaltsnormalen (zeigen nach aussen), wear = Kantenabnutzung je Punkt, closed = Spalten laufen im Kreis
static func grid(mb: T.MB, P: PackedVector3Array, Nn: PackedVector3Array, W: PackedFloat32Array, rows: int, cols: int, closed: bool = false, U: PackedVector2Array = PackedVector2Array()) -> void:
	var base := mb.v.size()
	for i in range(rows):
		for j in range(cols):
			var ia := i * cols + j
			var jl := j - 1
			var jr := j + 1
			if closed:
				jl = (j - 1 + cols) % cols
				jr = (j + 1) % cols
			else:
				jl = maxi(j - 1, 0)
				jr = mini(j + 1, cols - 1)
			var du := P[i * cols + jr] - P[i * cols + jl]
			var dv := P[mini(i + 1, rows - 1) * cols + j] - P[maxi(i - 1, 0) * cols + j]
			var nn := du.cross(dv)
			if nn.length() < 1e-9:
				nn = Nn[ia]
			nn = nn.normalized()
			if nn.dot(Nn[ia]) < 0.0:
				nn = -nn
			mb.vert(P[ia], nn, W[ia], U[ia] if U.size() > 0 else Vector2(float(j) / float(maxi(cols - 1, 1)), float(i) / float(maxi(rows - 1, 1))))
	var nj := cols if closed else cols - 1
	for i in range(rows - 1):
		for j in range(nj):
			var j2 := (j + 1) % cols
			mb.quad(base + i * cols + j, base + i * cols + j2, base + (i + 1) * cols + j2, base + (i + 1) * cols + j)


# Profil über die Breite einer Platte: c = -1..1 quer. bev = Anteil der Breite für die Abschrägung.
static func prof(c: float, bev: float) -> float:
	var e := 1.0 - absf(c)
	var k := clampf(e / maxf(bev, 0.001), 0.0, 1.0)
	return sqrt(1.0 - (1.0 - k) * (1.0 - k))


# Band auf der Körperoberfläche entlang der Linie pts (Vorderansicht (x, y)), Halbbreite hw(s), Dicke t.
# lift = Abstand zur Haut, bev = Abschrägung (Anteil der Breite), ends = Enden spitz zulaufen lassen (Anteil der Länge)
static func band(mb: T.MB, pts: PackedVector2Array, hw: Callable, t: float, lift: float = 0.002, bev: float = 0.3, back: bool = false, ends: float = 0.0, nu: int = 8, wear_k: float = 0.7) -> void:
	# Linie gleichmässig unterteilen
	var line := PackedVector2Array()
	var total := 0.0
	for i in range(pts.size() - 1):
		total += pts[i].distance_to(pts[i + 1])
	var nv := maxi(int(total / 0.008), 2)
	for k in range(nv + 1):
		var f := float(k) / float(nv) * total
		var acc := 0.0
		var placed := false
		for i in range(pts.size() - 1):
			var sl := pts[i].distance_to(pts[i + 1])
			if f <= acc + sl or i == pts.size() - 2:
				line.append(pts[i].lerp(pts[i + 1], clampf((f - acc) / maxf(sl, 1e-6), 0.0, 1.0)))
				placed = true
				break
			acc += sl
		if not placed:
			line.append(pts[pts.size() - 1])
	var P := PackedVector3Array()
	var Nn := PackedVector3Array()
	var W := PackedFloat32Array()
	for i in range(line.size()):
		var s := float(i) / float(line.size() - 1)
		var tg := (line[mini(i + 1, line.size() - 1)] - line[maxi(i - 1, 0)]).normalized()
		var nr := Vector2(-tg.y, tg.x)
		var w: float = hw.call(s)
		for j in range(nu + 1):
			var c := float(j) / float(nu) * 2.0 - 1.0
			var p2 := line[i] + nr * (w * c)
			var sv := at(p2.x, p2.y, back)
			var along := 1.0
			if ends > 0.0:
				var ee := minf(s, 1.0 - s) / ends
				along = sqrt(1.0 - (1.0 - ee) * (1.0 - ee)) if ee < 1.0 else 1.0
			var h := lift + (t * along) * prof(c, bev)
			P.append((sv[0] as Vector3) + (sv[1] as Vector3) * h)
			Nn.append(sv[1])
			W.append(wear_k * (1.0 - prof(c, bev)))
	grid(mb, P, Nn, W, line.size(), nu + 1)
