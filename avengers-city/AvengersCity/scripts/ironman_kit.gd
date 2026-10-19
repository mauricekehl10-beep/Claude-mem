extends RefCounted
# Baukasten der Iron-Man-Rüstung: Netz-Builder (Platten mit Fuge, Fase, Nieten), Flächen (Loft), Formen.
# Alle Maße sind Ruhepose-Koordinaten der Mixamo-Figur (T-Pose, Meter, Füsse bei y=0, +Z vorn, +X links).
# Gebaut wird für die linke Seite (x > 0), die rechte entsteht durch Spiegeln (Builder.sx = -1).
# Stoffe (id): 0 roter Lack, 1 Gold, 2 Silber, 3 dunkles Metall, 4 helles Metall, 5 Leuchten, 6 Wabengitter, 7 Gesichtsplatte, 8 Helmschale,
# 9 Gummi/Gewebe (schwarz), 10 Gunmetal (Silber-violett, verwittert)

const RED := 0
const GOLD := 1
const SILVER := 2
const DARK := 3
const METAL := 4
const GLOW := 5
const HEX := 6
const FACE := 7
const HELM := 8
const RUBBER := 9
const GUN := 10

const X := Vector3(1, 0, 0)
const Y := Vector3(0, 1, 0)
const Z := Vector3(0, 0, 1)


# ---------------------------------------------------------------- Netz-Baukasten

class Builder:
	extends RefCounted
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cs := PackedFloat32Array()
	var idx := PackedInt32Array()
	var sx := 1.0  # -1 = Spiegelung nach rechts
	var seed := 1.0

	# Platte aus einem Punktegitter: rows[i][j] (i = Reihe, j = Spalte). ref = Punkt "innen" (bestimmt die Außenseite).
	# UV = Bogenlänge-Anteil in Reihe/Spalte, CUSTOM0 = (Länge der Reihe, Länge der Spalte, Stoff + 100 * Zierlinie, Zufallsstart)
	func shell(rows: Array, mat: int, ref: Vector3, trim: int = 0, thick: float = 0.006, flat: bool = false, both: bool = false) -> void:
		var m: int = rows.size()
		var n: int = (rows[0] as Array).size()
		var P: Array = []
		for r in rows:
			for q in r:
				P.append(Vector3(q.x * sx, q.y, q.z))
		var rf := Vector3(ref.x * sx, ref.y, ref.z)
		var closed: bool = ((P[0] as Vector3) - (P[n - 1] as Vector3)).length() < 0.0005
		var N: Array = []
		N.resize(m * n)
		for i in range(m):
			var i0 := maxi(i - 1, 0)
			var i1 := mini(i + 1, m - 1)
			for j in range(n):
				var j0 := maxi(j - 1, 0)
				var j1 := mini(j + 1, n - 1)
				if closed:
					if j == 0:
						j0 = n - 2
					if j == n - 1:
						j1 = 1
				var du: Vector3 = P[i * n + j1] - P[i * n + j0]
				var dv: Vector3 = P[i1 * n + j] - P[i0 * n + j]
				var c := du.cross(dv)
				if c.length() < 1e-9:
					N[i * n + j] = ((P[i * n + j] as Vector3) - rf).normalized()
				else:
					N[i * n + j] = c.normalized()
		# Außenseite bestimmen (Mitte der Platte zeigt weg von ref)
		var mi := m / 2
		var mj := n / 2
		var flip := false
		var ctr: Vector3 = P[mi * n + mj]
		if (N[mi * n + mj] as Vector3).dot(ctr - rf) < 0.0:
			flip = true
		if flip:
			for k in range(N.size()):
				N[k] = -(N[k] as Vector3)
		# Bogenlängen: je Reihe (su, Anteil fu) und je Spalte (sv, Anteil fv)
		var su: Array = []
		var fu: Array = []
		fu.resize(m * n)
		for i in range(m):
			var l := 0.0
			fu[i * n] = 0.0
			for j in range(n - 1):
				l += ((P[i * n + j + 1] as Vector3) - (P[i * n + j] as Vector3)).length()
				fu[i * n + j + 1] = l
			su.append(l)
			for j in range(n):
				fu[i * n + j] = fu[i * n + j] / maxf(l, 1e-6)
		var sv: Array = []
		var fv: Array = []
		fv.resize(m * n)
		for j in range(n):
			var l := 0.0
			fv[j] = 0.0
			for i in range(m - 1):
				l += ((P[(i + 1) * n + j] as Vector3) - (P[i * n + j] as Vector3)).length()
				fv[(i + 1) * n + j] = l
			sv.append(l)
			for i in range(m):
				fv[i * n + j] = fv[i * n + j] / maxf(l, 1e-6)
		var cw := float(mat + 100 * trim)
		var base := vs.size()
		if not flat:
			for i in range(m):
				for j in range(n):
					vs.append(P[i * n + j])
					ns.append(N[i * n + j])
					uvs.append(Vector2(fu[i * n + j], fv[i * n + j]))
					cs.append_array(PackedFloat32Array([su[i], sv[j], cw, seed]))
			for i in range(m - 1):
				for j in range(n - 1):
					var a := base + i * n + j
					var b := base + (i + 1) * n + j
					var c2 := base + i * n + j + 1
					var d := base + (i + 1) * n + j + 1
					if flip:
						idx.append_array(PackedInt32Array([a, c2, b, c2, d, b]))
					else:
						idx.append_array(PackedInt32Array([a, b, c2, c2, b, d]))
		else:
			for i in range(m - 1):
				for j in range(n - 1):
					var q := [i * n + j, (i + 1) * n + j, i * n + j + 1, (i + 1) * n + j + 1]
					var fnv: Vector3 = ((P[q[3]] as Vector3) - (P[q[0]] as Vector3)).cross((P[q[2]] as Vector3) - (P[q[1]] as Vector3))
					if fnv.length() < 1e-12:
						fnv = N[q[0]]
					fnv = fnv.normalized()
					if flip:
						fnv = -fnv
					if fnv.dot(N[q[0]]) < 0.0:
						fnv = -fnv
					var b0 := vs.size()
					for k in range(4):
						var ii: int = q[k] / n
						var jj: int = q[k] % n
						vs.append(P[q[k]])
						ns.append(fnv)
						uvs.append(Vector2(fu[q[k]], fv[q[k]]))
						cs.append_array(PackedFloat32Array([su[ii], sv[jj], cw, seed]))
					if flip:
						idx.append_array(PackedInt32Array([b0, b0 + 2, b0 + 1, b0 + 2, b0 + 3, b0 + 1]))
					else:
						idx.append_array(PackedInt32Array([b0, b0 + 1, b0 + 2, b0 + 2, b0 + 1, b0 + 3]))
		# Rückseite (für dünne Teile, die man von beiden Seiten sieht)
		if both:
			var b1 := vs.size()
			var off := maxf(thick, 0.004)
			for i in range(m):
				for j in range(n):
					vs.append((P[i * n + j] as Vector3) - (N[i * n + j] as Vector3) * off)
					ns.append(-(N[i * n + j] as Vector3))
					uvs.append(Vector2(fu[i * n + j], fv[i * n + j]))
					cs.append_array(PackedFloat32Array([su[i], sv[j], cw, seed]))
			for i in range(m - 1):
				for j in range(n - 1):
					var a := b1 + i * n + j
					var b := b1 + (i + 1) * n + j
					var c2 := b1 + i * n + j + 1
					var d := b1 + (i + 1) * n + j + 1
					if flip:
						idx.append_array(PackedInt32Array([a, b, c2, c2, b, d]))
					else:
						idx.append_array(PackedInt32Array([a, c2, b, c2, d, b]))
		# Rand mit Dicke (sonst sieht man Papier)
		if thick > 0.0:
			for side in range(4):
				if closed and side >= 2:
					continue
				var cnt := n if side < 2 else m
				for k in range(cnt - 1):
					var ia: int
					var ib: int
					var inner_a: int
					var inner_b: int
					if side == 0:  # erste Reihe
						ia = k
						ib = k + 1
						inner_a = n + k
						inner_b = n + k + 1
					elif side == 1:  # letzte Reihe
						ia = (m - 1) * n + k
						ib = (m - 1) * n + k + 1
						inner_a = (m - 2) * n + k
						inner_b = (m - 2) * n + k + 1
					elif side == 2:  # erste Spalte
						ia = k * n
						ib = (k + 1) * n
						inner_a = k * n + 1
						inner_b = (k + 1) * n + 1
					else:  # letzte Spalte
						ia = k * n + n - 1
						ib = (k + 1) * n + n - 1
						inner_a = k * n + n - 2
						inner_b = (k + 1) * n + n - 2
					var pa: Vector3 = P[ia]
					var pb: Vector3 = P[ib]
					var outv: Vector3 = ((pa - (P[inner_a] as Vector3)) + (pb - (P[inner_b] as Vector3))).normalized()
					_rim(pa, pb, pa - (N[ia] as Vector3) * thick, pb - (N[ib] as Vector3) * thick, outv, cw)

	func _rim(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, outv: Vector3, cw: float) -> void:
		# Viereck p0, p1 (außen) und p3, p2 (innen); Normale zeigt nach outv
		var nn := (p1 - p0).cross(p3 - p0)
		if nn.length() < 1e-12:
			return
		nn = nn.normalized()
		if nn.dot(outv) < 0.0:
			nn = -nn
		var b0 := vs.size()
		for p in [p0, p1, p2, p3]:
			vs.append(p)
			ns.append(nn)
			uvs.append(Vector2(0.5, 0.0))
			cs.append_array(PackedFloat32Array([0.01, 0.01, cw, seed]))
		var c0 := (p1 - p0).cross(p2 - p0)
		if c0.dot(nn) < 0.0:
			idx.append_array(PackedInt32Array([b0, b0 + 1, b0 + 2, b0, b0 + 2, b0 + 3]))
		else:
			idx.append_array(PackedInt32Array([b0, b0 + 2, b0 + 1, b0, b0 + 3, b0 + 2]))

	# Erhabene Platte mit Fase auf einer Fläche f(u, v, off) -> Punkt (off = Abstand nach aussen).
	# c = vier Ecken im (u,v)-Raum: [[u,v] 00, 10, 11, 01]. h = Höhe der Platte, bev = Breite der Fase (Meter),
	# dome = Wölbung der Oberseite (0 flach, 1 stark), o0 = Abstand der Kante zur Fläche, wrap = Ring (v rund herum, keine Fase an v)
	func panel(f: Callable, c: Array, h: float, bev: float, mat: int, ref: Vector3, trim: int = 0, nu: int = 3, nv: int = 3,
			dome: float = 0.0, o0: float = 0.0012, wrap: bool = false, flat: bool = false, thick: float = 0.0) -> void:
		var c00: Vector2 = Vector2(c[0][0], c[0][1])
		var c10: Vector2 = Vector2(c[1][0], c[1][1])
		var c11: Vector2 = Vector2(c[2][0], c[2][1])
		var c01: Vector2 = Vector2(c[3][0], c[3][1])
		var ls: float = ((f.call(c10.x, c10.y, 0.0) as Vector3) - (f.call(c00.x, c00.y, 0.0) as Vector3)).length() * 0.5 \
			+ ((f.call(c11.x, c11.y, 0.0) as Vector3) - (f.call(c01.x, c01.y, 0.0) as Vector3)).length() * 0.5
		var lt: float = ((f.call(c01.x, c01.y, 0.0) as Vector3) - (f.call(c00.x, c00.y, 0.0) as Vector3)).length() * 0.5 \
			+ ((f.call(c11.x, c11.y, 0.0) as Vector3) - (f.call(c10.x, c10.y, 0.0) as Vector3)).length() * 0.5
		var bs := clampf(bev / maxf(ls, 0.001), 0.0, 0.3)
		var bt := 0.0 if wrap else clampf(bev / maxf(lt, 0.001), 0.0, 0.3)
		var S: Array = [0.0, bs]
		for k in range(1, nu - 1):
			S.append(bs + (1.0 - 2.0 * bs) * k / float(nu - 1))
		S.append(1.0 - bs)
		S.append(1.0)
		var T: Array = []
		if wrap:
			for k in range(nv + 1):
				T.append(k / float(nv))
		else:
			T = [0.0, bt]
			for k in range(1, nv - 1):
				T.append(bt + (1.0 - 2.0 * bt) * k / float(nv - 1))
			T.append(1.0 - bt)
			T.append(1.0)
		var R: Array = []
		for si in range(S.size()):
			var s: float = S[si]
			var row: Array = []
			for ti in range(T.size()):
				var t: float = T[ti]
				var q := c00.lerp(c10, s).lerp(c01.lerp(c11, s), t)
				var edge := si == 0 or si == S.size() - 1 or ((ti == 0 or ti == T.size() - 1) and not wrap)
				var off := o0
				if not edge:
					var d := ((2.0 * s - 1.0) * (2.0 * s - 1.0) + (2.0 * t - 1.0) * (2.0 * t - 1.0)) * 0.5
					off = o0 + h * (1.0 - dome * d)
				row.append(f.call(q.x, q.y, off))
			R.append(row)
		shell(R, mat, ref, trim, thick, flat)

	# Niete / Schraube: kleine Kuppel an der Stelle (u,v) der Fläche f
	func rivet(f: Callable, u: float, v: float, r: float, h: float, mat: int = 4, off: float = 0.0) -> void:
		var p0: Vector3 = f.call(u, v, off)
		var nn: Vector3 = ((f.call(u, v, off + 0.01) as Vector3) - p0).normalized()
		dome(p0, nn, r, h, mat)

	func dome(p0: Vector3, nn: Vector3, r: float, h: float, mat: int = 4, seg: int = 8) -> void:
		var up := Vector3.UP if absf(nn.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
		var ex := nn.cross(up).normalized()
		var ez := ex.cross(nn).normalized()
		var prof := [[r, -0.0006], [r * 0.96, h * 0.35], [r * 0.72, h * 0.8], [r * 0.3, h * 0.98], [0.0, h]]
		var R: Array = []
		for q in prof:
			var row: Array = []
			for j in range(seg + 1):
				var a := TAU * j / float(seg)
				row.append(p0 + nn * float(q[1]) + (ex * cos(a) + ez * sin(a)) * float(q[0]))
			R.append(row)
		shell(R, mat, p0 - nn * 0.05, 0, 0.0)

	func mesh() -> ArrayMesh:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = vs
		arr[Mesh.ARRAY_NORMAL] = ns
		arr[Mesh.ARRAY_TEX_UV] = uvs
		arr[Mesh.ARRAY_CUSTOM0] = cs
		arr[Mesh.ARRAY_INDEX] = idx
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		return am


# ---------------------------------------------------------------- Flächen

# Gewölbte Hülle um eine Achse a -> e (Querschnitt = Superellipse). keys = [t, rx, rz, n, ox, oz]:
# Halbachsen rx (entlang ex) und rz (entlang ez), Formexponent n (2 = rund, 4+ = kantig), Mittelpunkt-Verschiebung ox/oz.
# Winkel in Grad: 0 = +ez, 90 = +ex, 180 = -ez, 270 = -ex. Fläche f(t, winkel, off) für Builder.panel.
class Loft:
	extends RefCounted
	var a: Vector3
	var e: Vector3
	var ex: Vector3
	var ez: Vector3
	var keys: Array = []

	func _init(a_: Vector3, e_: Vector3, ex_: Vector3, ez_: Vector3, keys_: Array) -> void:
		a = a_
		e = e_
		ex = ex_
		ez = ez_
		for k in keys_:
			var kk: Array = (k as Array).duplicate()
			while kk.size() < 6:
				kk.append([0.0, 0.05, 0.05, 2.6, 0.0, 0.0][kk.size()])
			keys.append(kk)

	func key(t: float) -> Array:
		if t <= keys[0][0]:
			return keys[0]
		for i in range(keys.size() - 1):
			var p: Array = keys[i]
			var q: Array = keys[i + 1]
			if t <= q[0]:
				var u := clampf((t - p[0]) / maxf(q[0] - p[0], 0.00001), 0.0, 1.0)
				var out := []
				for k in range(p.size()):
					out.append(lerpf(p[k], q[k], u))
				return out
		return keys[keys.size() - 1]

	func base(t: float, ang: float) -> Vector3:
		var k := key(t)
		var c := a.lerp(e, t) + ex * float(k[4]) + ez * float(k[5])
		var r := deg_to_rad(ang)
		var s := sin(r)
		var co := cos(r)
		var n: float = k[3]
		var px := signf(s) * pow(absf(s), 2.0 / n)
		var pz := signf(co) * pow(absf(co), 2.0 / n)
		return c + ex * (float(k[1]) * px) + ez * (float(k[2]) * pz)

	# Punkt auf der Fläche, off Meter nach aussen (Normale aus Nachbarpunkten)
	func pt(t: float, ang: float, off: float = 0.0) -> Vector3:
		var k := key(t)
		var c := a.lerp(e, t) + ex * float(k[4]) + ez * float(k[5])
		var r := deg_to_rad(ang)
		var s := sin(r)
		var co := cos(r)
		var n: float = k[3]
		var px := signf(s) * pow(absf(s), 2.0 / n)
		var pz := signf(co) * pow(absf(co), 2.0 / n)
		var p := c + ex * (float(k[1]) * px) + ez * (float(k[2]) * pz)
		if off == 0.0:
			return p
		# Normale der Superellipse (Verlauf der Hülle entlang der Achse spielt bei Millimeter-Abständen keine Rolle)
		var gx := signf(px) * pow(absf(px), n - 1.0) / float(k[1])
		var gz := signf(pz) * pow(absf(pz), n - 1.0) / float(k[2])
		return p + (ex * gx + ez * gz).normalized() * off

	func f() -> Callable:
		return Callable(self, "pt")

	# Punktegitter der Hülle (Reihen = t, Spalten = Winkel) für Builder.shell
	func grid(t0: float, t1: float, a0: float, a1: float, nt: int, na: int, off: float = 0.0) -> Array:
		var R := []
		for i in range(nt):
			var t := lerpf(t0, t1, i / float(nt - 1))
			var row := []
			for j in range(na):
				row.append(pt(t, lerpf(a0, a1, j / float(na - 1)), off))
			R.append(row)
		return R


# ---------------------------------------------------------------- Formen

# Zwischenwert aus Stützstellen [t, a, b, ...] (linear)
static func kf(keys: Array, t: float) -> Array:
	if t <= keys[0][0]:
		return keys[0]
	for i in range(keys.size() - 1):
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if t <= b[0]:
			var u := clampf((t - a[0]) / maxf(b[0] - a[0], 0.00001), 0.0, 1.0)
			var out := []
			for k in range(a.size()):
				out.append(lerpf(a[k], b[k], u))
			return out
	return keys[keys.size() - 1]


# Punkte auf einem Superellipsen-Ring um c. Winkel in Grad: 0 = +ez, 90 = +ex
static func ring(c: Vector3, ex: Vector3, ez: Vector3, rx: float, rz: float, a0: float, a1: float, m: int, n: float = 2.0) -> Array:
	var out := []
	for i in range(m):
		var a := deg_to_rad(lerpf(a0, a1, i / float(m - 1)))
		var s := sin(a)
		var co := cos(a)
		var px := signf(s) * pow(absf(s), 2.0 / n)
		var pz := signf(co) * pow(absf(co), 2.0 / n)
		out.append(c + ex * (rx * px) + ez * (rz * pz))
	return out


# Hülle um eine Achse a -> e. keys = [t, rx, rz, a0, a1, n, ox, oz] (ox/oz verschieben den Ring entlang ex/ez)
static func tube(b: Builder, a: Vector3, e: Vector3, ex: Vector3, ez: Vector3, keys: Array, mat: int, trim: int = 0,
		rows: int = 10, cols: int = 16, thick: float = 0.006, flat: bool = false) -> void:
	var R := []
	for i in range(rows):
		var t := i / float(rows - 1)
		var k := kf(keys, t)
		var c := a.lerp(e, t) + ex * float(k[6]) + ez * float(k[7])
		R.append(ring(c, ex, ez, k[1], k[2], k[3], k[4], cols, k[5]))
	b.shell(R, mat, a.lerp(e, 0.5), trim, thick, flat)


# Drehkörper um eine Achse: prof = [[r, h], ...] (Radius, Höhe entlang nrm), von innen nach außen oder umgekehrt
static func lathe(b: Builder, c: Vector3, nrm: Vector3, prof: Array, mat: int, trim: int = 0, seg: int = 28) -> void:
	var up := Vector3.UP if absf(nrm.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var ex := nrm.cross(up).normalized()
	var ez := ex.cross(nrm).normalized()
	var R := []
	for q in prof:
		var row := []
		for j in range(seg + 1):
			var a := TAU * j / float(seg)
			row.append(c + nrm * float(q[1]) + (ex * cos(a) + ez * sin(a)) * float(q[0]))
		R.append(row)
	b.shell(R, mat, c - nrm * 0.05, trim, 0.0)


# Gebogene Klinge (Flügel, Flossen): Mittellinie pts mit Breite wd[i] (quer, Richtung side) und Wölbung cam
static func blade(b: Builder, pts: Array, wd: Array, side: Vector3, cam: float, mat: int, trim: int = 0, cols: int = 7, thick: float = 0.012) -> void:
	var R := []
	var m: int = pts.size()
	for i in range(m):
		var t: Vector3 = (pts[mini(i + 1, m - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)
		t = t.normalized()
		var s := (side - t * side.dot(t)).normalized()
		var nrm := t.cross(s).normalized()
		var row := []
		for j in range(cols):
			var u := j / float(cols - 1) * 2.0 - 1.0
			row.append((pts[i] as Vector3) + s * (u * float(wd[i])) + nrm * (cam * (1.0 - u * u) * float(wd[i])))
		R.append(row)
	var tm: Vector3 = (pts[mini(m / 2 + 1, m - 1)] as Vector3) - (pts[maxi(m / 2 - 1, 0)] as Vector3)
	var sm := (side - tm.normalized() * side.dot(tm.normalized())).normalized()
	var nm := tm.normalized().cross(sm).normalized()
	b.shell(R, mat, (pts[m / 2] as Vector3) - nm * 0.5, trim, thick, false, true)


static func g(x: float, s: float) -> float:
	return exp(-x * x / (2.0 * s * s))
