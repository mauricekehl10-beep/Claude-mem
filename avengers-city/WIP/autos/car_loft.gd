extends RefCounted
# Mesh-Werkzeuge fuer die Autos: Puffer, Kurven mit Ausrundungen, Gitter mit glatten Normalen (Kanten ab einem Knickwinkel
# bleiben scharf), Rohre, Boxen. Alle Teile eines Autos landen in einem Buf (Art des Teils in COLOR.a, siehe car_model.gd).


# Kurve y(u) aus Stuetzpunkten [u, y, Radius]; Ecken mit Radius > 0 werden ausgerundet. Danach dicht abgetastet.
class Crv:
	var us := PackedFloat32Array()
	var ys := PackedFloat32Array()
	var u0 := 0.0
	var u1 := 1.0
	const STEP := 0.004

	func _init(pts: Array) -> void:
		var poly := PackedVector2Array()
		var n := pts.size()
		poly.append(Vector2(pts[0][0], pts[0][1]))
		for i in range(1, n - 1):
			var a := Vector2(pts[i - 1][0], pts[i - 1][1])
			var b := Vector2(pts[i][0], pts[i][1])
			var c := Vector2(pts[i + 1][0], pts[i + 1][1])
			var r: float = pts[i][2] if pts[i].size() > 2 else 0.0
			if r <= 0.0:
				poly.append(b)
				continue
			var d1 := (a - b)
			var d2 := (c - b)
			var l1 := d1.length()
			var l2 := d2.length()
			var ang := d1.normalized().angle_to(d2.normalized())
			var t := absf(r / tan(maxf(absf(ang) * 0.5, 0.02)))
			t = minf(t, minf(l1, l2) * 0.49)
			var p0 := b + d1.normalized() * t
			var p1 := b + d2.normalized() * t
			for k in range(9):
				var s := float(k) / 8.0
				poly.append(p0 * (1.0 - s) * (1.0 - s) + b * (2.0 * s * (1.0 - s)) + p1 * s * s)
		poly.append(Vector2(pts[n - 1][0], pts[n - 1][1]))
		u0 = poly[0].x
		u1 = poly[poly.size() - 1].x
		var cnt := int((u1 - u0) / STEP) + 2
		var k2 := 0
		for i in range(cnt):
			var u := minf(u0 + i * STEP, u1)
			while k2 < poly.size() - 2 and poly[k2 + 1].x < u:
				k2 += 1
			var p := poly[k2]
			var q := poly[k2 + 1]
			var f := 0.0 if q.x - p.x < 1e-6 else clampf((u - p.x) / (q.x - p.x), 0.0, 1.0)
			us.append(u)
			ys.append(lerpf(p.y, q.y, f))

	func at(u: float) -> float:
		var f := (u - u0) / STEP
		if f <= 0.0:
			return ys[0]
		var i := int(f)
		if i >= ys.size() - 1:
			return ys[ys.size() - 1]
		return lerpf(ys[i], ys[i + 1], f - i)


class Buf:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()

	func vert(p: Vector3, nn: Vector3, col: Color, u: Vector2 = Vector2.ZERO) -> int:
		v.append(p)
		n.append(nn)
		c.append(col)
		uv.append(u)
		return v.size() - 1

	# Dreieck mit Umlaufsinn nach den Normalen (Godot: Vorderseite im Uhrzeigersinn von aussen)
	func tri(a: int, b: int, d: int) -> void:
		var cr := (v[b] - v[a]).cross(v[d] - v[a])
		if cr.dot(n[a] + n[b] + n[d]) > 0.0:
			idx.append(a)
			idx.append(d)
			idx.append(b)
		else:
			idx.append(a)
			idx.append(b)
			idx.append(d)

	func quad(a: int, b: int, d: int, e: int) -> void:
		tri(a, b, d)
		tri(a, d, e)

	func arrays() -> Array:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_INDEX] = idx
		return arr

	func append_buf(o: Buf, xf: Transform3D = Transform3D.IDENTITY) -> void:
		var base := v.size()
		var nb := xf.basis
		for i in range(o.v.size()):
			v.append(xf * o.v[i])
			n.append((nb * o.n[i]).normalized())
		c.append_array(o.c)
		uv.append_array(o.uv)
		for i in range(o.idx.size()):
			idx.append(o.idx[i] + base)

	func tri_count() -> int:
		return idx.size() / 3


# Gitter: P = Reihen (Array aus PackedVector3Array gleicher Laenge). closed = Spalten schliessen sich zum Ring.
# fc = Farbe je Flaeche (Reihe-Major, (rows-1) * nseg), eine leere Farbe (a < 0) laesst die Flaeche aus.
# Normalen: Mittel der Nachbarflaechen, deren Knick kleiner als crease_deg ist. Umlaufrichtung: dr x dz zeigt nach aussen.
static func grid(b: Buf, P: Array, closed: bool, fc: PackedColorArray, crease_deg: float = 48.0, flip: bool = false, uvf: Callable = Callable()) -> void:
	var rows := P.size()
	var cols: int = P[0].size()
	var nseg := cols if closed else cols - 1
	var nf := (rows - 1) * nseg
	var fn := PackedVector3Array()
	fn.resize(nf)
	var ok := PackedByteArray()
	ok.resize(nf)
	for i in range(rows - 1):
		var r0: PackedVector3Array = P[i]
		var r1: PackedVector3Array = P[i + 1]
		for j in range(nseg):
			var j1 := (j + 1) % cols
			var a := r0[j]
			var bb := r0[j1]
			var d := r1[j]
			var cc := r1[j1]
			var nn := ((bb - a) + (cc - d)).cross((d - a) + (cc - bb))
			var k := i * nseg + j
			if fc[k].a < 0.0 or nn.length_squared() < 1e-14:
				ok[k] = 0
				fn[k] = Vector3.ZERO
			else:
				ok[k] = 1
				fn[k] = nn.normalized() * (-1.0 if flip else 1.0)
	var cs := cos(deg_to_rad(crease_deg))
	for i in range(rows - 1):
		var r0: PackedVector3Array = P[i]
		var r1: PackedVector3Array = P[i + 1]
		for j in range(nseg):
			var k := i * nseg + j
			if ok[k] == 0:
				continue
			var j1 := (j + 1) % cols
			var me := fn[k]
			var ids := [0, 0, 0, 0]
			# vier Ecken: (i,j) (i,j1) (i+1,j1) (i+1,j)
			var corners := [[i, j], [i, j1], [i + 1, j1], [i + 1, j]]
			for q in range(4):
				var ci: int = corners[q][0]
				var cj: int = corners[q][1]
				var sum := Vector3.ZERO
				for di in range(2):
					var fi := ci - 1 + di
					if fi < 0 or fi >= rows - 1:
						continue
					for dj in range(2):
						var fj := cj - 1 + dj
						if closed:
							fj = (fj + cols) % cols
						elif fj < 0 or fj >= nseg:
							continue
						var kk := fi * nseg + fj
						if ok[kk] == 1 and fn[kk].dot(me) >= cs:
							sum += fn[kk]
				var nrm := me if sum.length_squared() < 1e-12 else sum.normalized()
				var pos: Vector3 = (r0 if ci == i else r1)[cj]
				var u2 := Vector2.ZERO
				if uvf.is_valid():
					u2 = uvf.call(ci, cj)
				ids[q] = b.vert(pos, nrm, fc[k], u2)
			b.quad(ids[0], ids[1], ids[2], ids[3])


# Endkappe: Faecher um den Schwerpunkt
static func cap(b: Buf, ring: PackedVector3Array, n: Vector3, col: Color) -> void:
	var c := Vector3.ZERO
	for p in ring:
		c += p
	c /= ring.size()
	var ci := b.vert(c, n, col)
	var ids := []
	for p in ring:
		ids.append(b.vert(p, n, col))
	for j in range(ids.size() - 1):
		b.tri(ci, ids[j], ids[j + 1])
	b.tri(ci, ids[ids.size() - 1], ids[0])


static func box(b: Buf, c: Vector3, s: Vector3, col: Color) -> void:
	var h := s * 0.5
	var faces := [
		[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
		[Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)],
		[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
		[Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)],
		[Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(1, 0, 0)],
		[Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(-1, 0, 0)],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var o := Vector3(n.x * h.x, n.y * h.y, n.z * h.z)
		var uu := Vector3(u.x * h.x, u.y * h.y, u.z * h.z)
		var vv := Vector3(v.x * h.x, v.y * h.y, v.z * h.z)
		var a := b.vert(c + o - uu - vv, n, col, Vector2(0, 1))
		var b1 := b.vert(c + o + uu - vv, n, col, Vector2(0, 0))
		var c1 := b.vert(c + o + uu + vv, n, col, Vector2(1, 0))
		var d := b.vert(c + o - uu + vv, n, col, Vector2(1, 1))
		b.quad(a, b1, c1, d)


# Abgerundete Box (Seiten glatt): Querschnitt als Rechteck mit Radius r, Laenge entlang z, Enden ebenfalls abgerundet
static func rbox(b: Buf, c: Vector3, s: Vector3, r: float, col: Color, seg: int = 3, xf: Transform3D = Transform3D.IDENTITY) -> void:
	var h := s * 0.5
	r = minf(r, minf(h.x, minf(h.y, h.z)) * 0.98)
	var rows := []
	var K := seg
	# Reihen entlang z: Viertelkreis-Enden
	var zs := []
	for k in range(K + 1):
		var a := float(k) / K * PI * 0.5
		zs.append([-h.z + r * (1.0 - cos(a)), r * sin(a)])
	for k in range(K, -1, -1):
		var a := float(k) / K * PI * 0.5
		zs.append([h.z - r * (1.0 - cos(a)), r * sin(a)])
	for zq in zs:
		var inset: float = r - zq[1]
		var hx: float = maxf(h.x - inset, 0.001)
		var hy: float = maxf(h.y - inset, 0.001)
		var rr := maxf(r - inset, 0.0005)
		var ring := PackedVector3Array()
		# Rechteck mit Eckradius rr, im Uhrzeigersinn ab oben Mitte nach rechts (Ring: Richtung wie bei Karosserie nicht noetig, Normalen per flip)
		var corners := [[hx - rr, hy - rr, 0.0], [-hx + rr, hy - rr, PI * 0.5], [-hx + rr, -hy + rr, PI], [hx - rr, -hy + rr, PI * 1.5]]
		for q in corners:
			for k in range(K + 1):
				var a: float = q[2] + float(k) / K * (PI * 0.5)
				ring.append(Vector3(q[0] + rr * cos(a), q[1] + rr * sin(a), zq[0]))
		rows.append(ring)
	# Ring umlaeuft x/y im Uhrzeigersinn (von +z gesehen, wenn Winkel faellt); Normale (dr x dz) zeigt nach aussen
	var nseg: int = rows[0].size()
	var fc := PackedColorArray()
	fc.resize((rows.size() - 1) * nseg)
	fc.fill(col)
	var P := []
	for ring in rows:
		var rg := PackedVector3Array()
		for p in ring:
			rg.append(xf * (p + c))
		P.append(rg)
	grid(b, P, true, fc, 60.0, false)
	# Endkappen
	var r0: PackedVector3Array = P[0]
	var r1: PackedVector3Array = P[P.size() - 1]
	cap(b, r0, xf.basis * Vector3(0, 0, -1), col)
	cap(b, r1, xf.basis * Vector3(0, 0, 1), col)


# Kegelstumpf / Zylinder von p0 nach p1 mit Radien r0, r1 (glatte Seiten, offene Enden oder mit Kappen)
static func tube(b: Buf, p0: Vector3, p1: Vector3, r0: float, r1: float, col: Color, seg: int = 8, caps: bool = true) -> void:
	var ax := (p1 - p0)
	var ln := ax.length()
	if ln < 1e-6:
		return
	var d := ax / ln
	var t := Vector3.UP.cross(d)
	if t.length() < 0.01:
		t = Vector3.RIGHT.cross(d)
	t = t.normalized()
	var bt := d.cross(t)
	var slope := (r0 - r1) / ln
	var ring0 := PackedVector3Array()
	var ring1 := PackedVector3Array()
	var nr0 := []
	for k in range(seg):
		var a := TAU * float(k) / seg
		var dir := t * cos(a) + bt * sin(a)
		ring0.append(p0 + dir * r0)
		ring1.append(p1 + dir * r1)
		nr0.append((dir + d * slope).normalized())
	for k in range(seg):
		var k1 := (k + 1) % seg
		var a0 := b.vert(ring0[k], nr0[k], col, Vector2(float(k) / seg, 0))
		var a1 := b.vert(ring0[k1], nr0[k1], col, Vector2(float(k + 1) / seg, 0))
		var b1 := b.vert(ring1[k1], nr0[k1], col, Vector2(float(k + 1) / seg, 1))
		var b0 := b.vert(ring1[k], nr0[k], col, Vector2(float(k) / seg, 1))
		b.quad(a0, a1, b1, b0)
	if caps:
		cap(b, ring0, -d, col)
		cap(b, ring1, d, col)
