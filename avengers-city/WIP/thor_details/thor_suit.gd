extends RefCounted
# Thor: Rüstung und Aussehen als Zusatzteile (Scheiben, Hüftplatten, Knieschützer, Stiefelschäfte, Armschienen,
# Gürtel, Schulterumhang, Haare, Mjolnir). Maße in Ruhepose-Koordinaten der Mixamo-Figur (T-Pose, Meter,
# Füsse bei y=0, +Z vorn, +X links). Die Teile werden direkt in diesen Koordinaten gebaut und hängen an Knochen.
# Material: thor_armor.gdshader. Den Stoff darunter (Kettenhemd, Brustplatte, Leder) malt thor_suit.gdshaderinc.

const Hair = preload("res://scripts/hero_hair.gd")
const ARMOR = preload("res://scripts/thor_armor.gdshader")
const HAIR_SHADER = preload("res://scripts/hair.gdshader")

const SILVER := Color(0.72, 0.74, 0.78)
const GUN := Color(0.26, 0.27, 0.30)
const PLATE := Color(0.38, 0.39, 0.42)
const LEATHER := Color(0.17, 0.165, 0.18)
const BROWN := Color(0.20, 0.11, 0.06)
const RED := Color(0.50, 0.03, 0.04)
const BOOT := Color(0.17, 0.185, 0.22)


# ---------------------------------------------------------------- Netz-Baukasten

class MB:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()

	func vert(p: Vector3, nn: Vector3, wear: float = 0.0, u: Vector2 = Vector2.ZERO) -> int:
		v.append(p)
		n.append(nn.normalized())
		c.append(Color(1, 1, 1, wear))
		uv.append(u)
		return v.size() - 1

	# Dreieck so drehen, dass es zur Normale passt (Vorderseite = im Uhrzeigersinn)
	func tri(a: int, b: int, d: int) -> void:
		var gn := (v[b] - v[a]).cross(v[d] - v[a])
		if gn.dot(n[a] + n[b] + n[d]) > 0.0:
			idx.append_array(PackedInt32Array([a, d, b]))
		else:
			idx.append_array(PackedInt32Array([a, b, d]))

	func quad(a: int, b: int, d: int, e: int) -> void:
		tri(a, b, d)
		tri(a, d, e)

	func mesh() -> ArrayMesh:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_INDEX] = idx
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m


static func mat(kind: int, c: Color, metal: float, rough: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ARMOR
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("base", c)
	m.set_shader_parameter("metal", metal)
	m.set_shader_parameter("rough", rough)
	return m


static func att(skel: Skeleton3D, bone: String) -> BoneAttachment3D:
	var nm := "A_" + bone
	var ba := skel.get_node_or_null(nm) as BoneAttachment3D
	if ba == null:
		ba = BoneAttachment3D.new()
		ba.name = nm
		ba.bone_name = bone
		skel.add_child(ba)
	return ba


# Hängt ein Netz (Koordinaten wie Ruhepose, oder mit xf verschoben) an einen Knochen.
static func put(skel: Skeleton3D, bone: String, mesh: Mesh, m: Material, xf: Transform3D = Transform3D.IDENTITY) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.transform = skel.get_bone_global_rest(skel.find_bone(bone)).affine_inverse() * xf
	att(skel, bone).add_child(mi)
	return mi


# Basis aus zwei Richtungen: y = Achse, z = grobe zweite Achse
static func frame(y: Vector3, z: Vector3) -> Basis:
	var by := y.normalized()
	var bx := by.cross(z).normalized()
	var bz := bx.cross(by).normalized()
	return Basis(bx, by, bz)


# Drehkörper: prof = Punkte (Radius, Höhe) von aussen unten nach oben zur Mitte. Achse = bs.y, Mitte = org.
static func lathe(mb: MB, prof: Array, bs: Basis, org: Vector3, segs: int, wear: float = 0.0) -> void:
	var nt := bs.inverse().transposed()
	var m := prof.size()
	var sn := []
	for i in range(m - 1):
		var t: Vector2 = prof[i + 1] - prof[i]
		sn.append(Vector2(t.y, -t.x).normalized())
	for i in range(m - 1):
		var na: Vector2 = sn[i]
		var nb: Vector2 = sn[i]
		if i > 0 and (sn[i - 1] as Vector2).dot(sn[i]) > 0.6:
			na = (sn[i - 1] + sn[i]).normalized()
		if i < m - 2 and (sn[i + 1] as Vector2).dot(sn[i]) > 0.6:
			nb = (sn[i + 1] + sn[i]).normalized()
		var rows := []
		for k in range(2):
			var pr: Vector2 = prof[i + k]
			var nn: Vector2 = na if k == 0 else nb
			var row := []
			for j in range(segs + 1):
				var a := TAU * float(j) / float(segs)
				var ca := cos(a)
				var sa := sin(a)
				var pos := org + bs * Vector3(ca * pr.x, pr.y, sa * pr.x)
				var nrm := nt * Vector3(ca * nn.x, nn.y, sa * nn.x)
				row.append(mb.vert(pos, nrm, wear if pr.x > 0.0 else 0.0))
			rows.append(row)
		for j in range(segs):
			mb.quad(rows[0][j], rows[0][j + 1], rows[1][j + 1], rows[1][j])


# Kuppel (Scheibe): Radius r, Höhe h, Rand rh hoch, Tiefe der Rille am Rand
static func dome(mb: MB, bs: Basis, org: Vector3, r: float, h: float, rh: float = 0.003, wear: float = 0.5) -> void:
	var prof := [Vector2(r, 0.0), Vector2(r, rh)]
	for k in range(1, 7):
		var f := float(k) / 6.0
		var ang := f * PI * 0.5
		prof.append(Vector2(r * cos(ang) * (1.0 - 0.02 * f), rh + h * sin(ang)))
	lathe(mb, prof, bs, org, 28, wear)


# Gebogene Platte auf einem elliptischen Zylinder (Stiefel, Armschienen, Hüftplatten ...).
# d: o (Ursprung), ax (Achse, Länge v), e1 (Richtung bei Winkel 0), e2 (bei 90 Grad), v0, v1 (Länge von/bis),
# rad: Callable(v) -> Vector2(rx, rz), span: Callable(s 0..1) -> Vector2(Winkel von, bis) oder ring=true,
# t: Dicke, bev: Abschrägung am Rand (m), ridge: Wulst in der Mitte, nv/nu: Teilung
static func patch(mb: MB, d: Dictionary) -> void:
	var o: Vector3 = d["o"]
	var ax: Vector3 = d["ax"]
	var e1: Vector3 = d["e1"]
	var e2: Vector3 = d["e2"]
	var v0: float = d["v0"]
	var v1: float = d["v1"]
	var nv: int = d.get("nv", 8)
	var nu: int = d.get("nu", 10)
	var rad: Callable = d["rad"]
	var ring: bool = d.get("ring", false)
	var span: Callable = d.get("span", Callable())
	var T: float = d.get("t", 0.01)
	var bev: float = d.get("bev", 0.006)
	var ridge: float = d.get("ridge", 0.0)
	var wear_k: float = d.get("wear", 0.6)
	var cols := nu if ring else nu + 1
	var P := PackedVector3Array()
	var Bs := PackedVector3Array()
	var W := PackedFloat32Array()
	var Uv := PackedVector2Array()
	var len := absf(v1 - v0)
	for i in range(nv + 1):
		var s := float(i) / float(nv)
		var v := lerpf(v0, v1, s)
		var r: Vector2 = rad.call(v)
		var sp := Vector2(0.0, TAU)
		if not ring:
			sp = span.call(s)
		for j in range(cols):
			var u := float(j) / float(nu)
			var a := lerpf(sp.x, sp.y, u)
			var dir := e1 * (cos(a) * r.x) + e2 * (sin(a) * r.y)
			var dist := minf(s, 1.0 - s) * len
			if not ring:
				var arc := absf(sp.y - sp.x) * 0.5 * (r.x + r.y)
				dist = minf(dist, minf(u, 1.0 - u) * arc)
			var k := smoothstep(0.0, bev, dist)
			var th := T * (0.35 + 0.65 * k) + ridge * (1.0 - absf(2.0 * u - 1.0)) * k
			var base := o + ax * v + dir
			P.append(base + dir.normalized() * th)
			Bs.append(base)
			W.append(wear_k * (1.0 - k))
			Uv.append(Vector2(u, s))
	# Normalen aus dem Gitter
	var ids := PackedInt32Array()
	for i in range(nv + 1):
		for j in range(cols):
			var ia := i * cols + j
			var jl := j - 1
			var jr := j + 1
			if ring:
				jl = (j - 1 + cols) % cols
				jr = (j + 1) % cols
			else:
				jl = maxi(j - 1, 0)
				jr = mini(j + 1, cols - 1)
			var du := P[i * cols + jr] - P[i * cols + jl]
			var dv := P[mini(i + 1, nv) * cols + j] - P[maxi(i - 1, 0) * cols + j]
			var nn := du.cross(dv).normalized()
			var out := (P[ia] - Bs[ia]).normalized()
			if nn.dot(out) < 0.0:
				nn = -nn
			ids.append(mb.vert(P[ia], nn, W[ia], Uv[ia]))
	var nj := cols if ring else cols - 1
	for i in range(nv):
		for j in range(nj):
			var j2 := (j + 1) % cols
			mb.quad(ids[i * cols + j], ids[i * cols + j2], ids[(i + 1) * cols + j2], ids[(i + 1) * cols + j])
	# Randwände (Dicke sichtbar machen); bei Ringen nur oben und unten
	var cen := P[(nv / 2) * cols + cols / 2]
	var dirv := ax * signf(v1 - v0)
	for side in range(4):
		if ring and side < 2:
			continue
		var loop := []
		for q in range(nv + 1 if side < 2 else (cols + 1 if ring else cols)):
			var i := q
			var j := 0
			if side == 1:
				j = cols - 1
			elif side == 2:
				i = 0
				j = q % cols
			elif side == 3:
				i = nv
				j = q % cols
			loop.append(i * cols + j)
		for q in range(loop.size() - 1):
			var a: int = loop[q]
			var b: int = loop[q + 1]
			var edge := P[b] - P[a]
			var nn := edge.cross(P[a] - Bs[a]).normalized()
			var hint := (P[a] + P[b]) * 0.5 - cen
			if ring:
				hint = dirv * (-1.0 if side == 2 else 1.0)
			if nn.dot(hint) < 0.0:
				nn = -nn
			var w0 := mb.vert(P[a], nn, 0.0)
			var w1 := mb.vert(P[b], nn, 0.0)
			var w2 := mb.vert(Bs[b], nn, 0.0)
			var w3 := mb.vert(Bs[a], nn, 0.0)
			mb.quad(w0, w1, w2, w3)


# Quader mit abgeschrägten Kanten (Mjolnir-Kopf, Schnallen). Mitte org, Achsen bs, Grösse size, Fase ch.
static func cbox(mb: MB, bs: Basis, org: Vector3, size: Vector3, ch: float, wear: float = 0.5) -> void:
	var h := size * 0.5
	var nt := bs.inverse().transposed()
	var sg := [-1.0, 1.0]
	for ai in range(3):
		var aj := (ai + 1) % 3
		var ak := (ai + 2) % 3
		for si in sg:
			# Hauptfläche
			var ids := []
			for sj in sg:
				for sk in sg:
					var lp := Vector3.ZERO
					lp[ai] = si * h[ai]
					lp[aj] = sj * (h[aj] - ch)
					lp[ak] = sk * (h[ak] - ch)
					var nl := Vector3.ZERO
					nl[ai] = si
					ids.append(mb.vert(org + bs * lp, nt * nl, 0.0))
			mb.quad(ids[0], ids[1], ids[3], ids[2])
			# Fase zur Nachbarfläche in Richtung aj
			for sj in sg:
				var e := []
				for sk in sg:
					var p1 := Vector3.ZERO
					p1[ai] = si * h[ai]
					p1[aj] = sj * (h[aj] - ch)
					p1[ak] = sk * (h[ak] - ch)
					var p2 := Vector3.ZERO
					p2[ai] = si * (h[ai] - ch)
					p2[aj] = sj * h[aj]
					p2[ak] = sk * (h[ak] - ch)
					var nl := Vector3.ZERO
					nl[ai] = si
					nl[aj] = sj
					var nn := nt * nl
					e.append(mb.vert(org + bs * p1, nn, wear))
					e.append(mb.vert(org + bs * p2, nn, wear))
				mb.quad(e[0], e[1], e[3], e[2])
	# Ecken: je ein Dreieck
	for si in sg:
		for sj in sg:
			for sk in sg:
				var sv := Vector3(si, sj, sk)
				var cn := []
				for axis in range(3):
					var pp := Vector3(sv.x * (h.x - ch), sv.y * (h.y - ch), sv.z * (h.z - ch))
					pp[axis] = sv[axis] * h[axis]
					cn.append(mb.vert(org + bs * pp, nt * sv, wear))
				mb.tri(cn[0], cn[1], cn[2])


# ---------------------------------------------------------------- Teile

# Lage für Teile auf einer Fläche: y = Normale, x waagrecht, z nach unten
static func sframe(n: Vector3) -> Basis:
	var by := n.normalized()
	var bx := Vector3.UP.cross(by).normalized()
	var bz := bx.cross(by).normalized()
	return Basis(bx, by, bz)


static func build(skel: Skeleton3D) -> void:
	# discs(skel): jetzt thor_plates.gd
	belt(skel)
	faulds(skel)
	legs(skel)
	arms(skel)
	mantle(skel)


# Silberne Kuppelscheiben auf Brust und Bauch, mit dunklem Rand
static func discs(skel: Skeleton3D) -> void:
	var silver := mat(0, SILVER, 0.92, 0.33)
	var gun := mat(1, GUN, 0.45, 0.45)
	var ms := MB.new()
	var mg := MB.new()
	for s in [-1.0, 1.0]:
		# [Mitte, Normale, Radius, Höhe, Rand-Radius]
		var list := [
			[Vector3(s * 0.118, 1.432, 0.112), Vector3(s * 0.17, 0.45, 0.88), 0.052, 0.024, 0.062],
			[Vector3(s * 0.100, 1.268, 0.158), Vector3(s * 0.15, 0.04, 1.0), 0.031, 0.014, 0.041],
			[Vector3(s * 0.094, 1.122, 0.124), Vector3(s * 0.35, -0.05, 1.0), 0.034, 0.016, 0.043],
		]
		for d in list:
			var bs := sframe(d[1])
			dome(ms, bs, d[0], d[2], d[3])
			lathe(mg, [Vector2(d[4], -0.004), Vector2(d[4], 0.006), Vector2(d[4] - 0.007, 0.011), Vector2(d[2] - 0.002, 0.012)], bs, d[0], 28, 0.7)
		# dunkle Tropfenplatte unter der unteren Scheibe
		var bs2 := sframe(Vector3(s * 0.33, -0.02, 1.0)) * Basis.from_scale(Vector3(1.0, 1.0, 1.55))
		lathe(mg, [Vector2(0.056, -0.006), Vector2(0.056, 0.004), Vector2(0.049, 0.010), Vector2(0.0, 0.011)], bs2, Vector3(s * 0.094, 1.116, 0.119), 28, 0.7)
	put(skel, "mixamorig_Spine2", ms.mesh(), silver)
	put(skel, "mixamorig_Spine2", mg.mesh(), gun)


# Gürtel mit Schnalle
static func belt(skel: Skeleton3D) -> void:
	var lea := mat(2, Color(0.085, 0.072, 0.065), 0.0, 0.55)
	var silver := mat(0, SILVER, 0.92, 0.33)
	var gun := mat(1, GUN, 0.45, 0.45)
	var mb := MB.new()
	patch(mb, {"o": Vector3(0, 1.077, -0.008), "ax": Vector3.DOWN, "e1": Vector3(1, 0, 0), "e2": Vector3(0, 0, 1), "v0": 0.0, "v1": 0.064,
		"nv": 2, "nu": 48, "ring": true, "rad": func(_v): return Vector2(0.178, 0.157), "t": 0.011, "bev": 0.004})
	put(skel, "mixamorig_Hips", mb.mesh(), lea)
	var mk := MB.new()
	cbox(mk, Basis.IDENTITY, Vector3(0, 1.047, 0.168), Vector3(0.064, 0.050, 0.014), 0.004)
	put(skel, "mixamorig_Hips", mk.mesh(), silver)
	var mi := MB.new()
	cbox(mi, Basis.IDENTITY, Vector3(0, 1.047, 0.172), Vector3(0.038, 0.028, 0.012), 0.003)
	put(skel, "mixamorig_Hips", mi.mesh(), gun)


# Hüftplatten (Rock aus Platten): Mitte vorn und hinten am Becken, seitliche Platten am Oberschenkel
static func faulds(skel: Skeleton3D) -> void:
	var m := mat(1, PLATE, 0.5, 0.45)
	var rad := func(v: float) -> Vector2: return Vector2(0.186 - 0.04 * v, 0.153 - 0.13 * v)
	var o := Vector3(0, 1.016, -0.008)
	var base := {"o": o, "ax": Vector3.DOWN, "e1": Vector3(1, 0, 0), "e2": Vector3(0, 0, 1), "v0": 0.0, "nv": 9, "nu": 8, "rad": rad,
		"t": 0.011, "bev": 0.007, "ridge": 0.007}
	# Mitte vorn und hinten
	var mf := MB.new()
	var d1 := base.duplicate()
	d1["v1"] = 0.175
	d1["span"] = func(s: float) -> Vector2:
		var h := deg_to_rad(22.0) * (1.0 - 0.95 * smoothstep(0.45, 1.0, s))
		return Vector2(PI * 0.5 - h, PI * 0.5 + h)
	patch(mf, d1)
	var d2 := base.duplicate()
	d2["v1"] = 0.13
	d2["span"] = func(s: float) -> Vector2:
		var h := deg_to_rad(32.0) * (1.0 - 0.9 * smoothstep(0.5, 1.0, s))
		return Vector2(PI * 1.5 - h, PI * 1.5 + h)
	patch(mf, d2)
	put(skel, "mixamorig_Hips", mf.mesh(), m)
	# Seitenplatten an den Oberschenkeln
	for s in [-1.0, 1.0]:
		var ms := MB.new()
		var bone := "mixamorig_LeftUpLeg" if s > 0.0 else "mixamorig_RightUpLeg"
		for pl in [[39.0, 0.255, 13.5], [66.0, 0.215, 13.5]]:
			var dd := base.duplicate()
			dd["v1"] = pl[1]
			var ac := deg_to_rad(90.0 - s * float(pl[0]))
			var hw := deg_to_rad(float(pl[2]))
			dd["span"] = func(sv: float) -> Vector2:
				var h := hw * (1.0 - 0.45 * smoothstep(0.6, 1.0, sv))
				return Vector2(ac - h, ac + h)
			patch(ms, dd)
		put(skel, bone, ms.mesh(), m)


# Knieschützer, Stiefelschäfte
static func legs(skel: Skeleton3D) -> void:
	var plate := mat(1, PLATE, 0.5, 0.45)
	var boot := mat(2, BOOT, 0.0, 0.45)
	var cuffm := mat(2, Color(0.12, 0.115, 0.135), 0.0, 0.5)
	var strapm := mat(2, Color(0.06, 0.055, 0.06), 0.0, 0.55)
	var silver := mat(0, SILVER, 0.92, 0.33)
	for s in [-1.0, 1.0]:
		var side := "Left" if s > 0.0 else "Right"
		var bone := "mixamorig_%sLeg" % side
		var kp := Vector3(s * 0.0937, 0.5254, -0.0057)
		var fp := Vector3(s * 0.0912, 0.1049, -0.0263)
		var ax := (fp - kp).normalized()
		var e1 := Vector3(s, 0, 0)
		var e2 := (Vector3(0, 0, 1) - ax * ax.z).normalized()
		# Knieschutz: Spitzbogen-Platte über dem Knie
		var mk := MB.new()
		patch(mk, {"o": kp, "ax": ax, "e1": e1, "e2": e2, "v0": -0.09, "v1": 0.135, "nv": 12, "nu": 10,
			"rad": func(v: float) -> Vector2: return Vector2(0.072, 0.092 + (0.16 * v if v < 0.0 else -0.17 * v)),
			"span": func(sv: float) -> Vector2:
				var h := deg_to_rad(46.0) * (1.0 - 0.93 * smoothstep(0.50, 1.0, sv))
				return Vector2(PI * 0.5 - h, PI * 0.5 + h),
			"t": 0.012, "bev": 0.008, "ridge": 0.010})
		put(skel, bone, mk.mesh(), plate)
		# Stiefelschaft
		var o2 := kp + Vector3(0, 0, -0.010)
		var shaft := func(v: float) -> Vector2:
			var r := lerpf(0.079, 0.058, smoothstep(0.03, 0.38, v)) + 0.009 * (1.0 - smoothstep(0.035, 0.10, v))
			return Vector2(r, r * 1.08)
		var grown := func(v: float) -> Vector2:
			var r: Vector2 = shaft.call(v)
			return r + Vector2(0.004, 0.004)
		var mbt := MB.new()
		patch(mbt, {"o": o2, "ax": ax, "e1": e1, "e2": e2, "v0": 0.04, "v1": 0.385, "nv": 14, "nu": 28, "ring": true, "rad": shaft, "t": 0.008, "bev": 0.004})
		put(skel, bone, mbt.mesh(), boot)
		# Umschlag oben
		var mc := MB.new()
		patch(mc, {"o": o2, "ax": ax, "e1": e1, "e2": e2, "v0": 0.03, "v1": 0.092, "nv": 4, "nu": 28, "ring": true, "rad": grown, "t": 0.011, "bev": 0.006})
		put(skel, bone, mc.mesh(), cuffm)
		# Riemen mit Schnallen
		var mr := MB.new()
		var msil := MB.new()
		for pv in [0.16, 0.255]:
			patch(mr, {"o": o2, "ax": ax, "e1": e1, "e2": e2, "v0": pv, "v1": pv + 0.022, "nv": 2, "nu": 28, "ring": true, "rad": grown, "t": 0.008, "bev": 0.003})
			var ang := deg_to_rad(40.0 if s > 0.0 else 140.0)
			var rr: Vector2 = shaft.call(pv + 0.011)
			var pos: Vector3 = o2 + ax * (pv + 0.011) + e1 * (cos(ang) * (rr.x + 0.017)) + e2 * (sin(ang) * (rr.y + 0.017))
			var outv := (e1 * cos(ang) + e2 * sin(ang)).normalized()
			cbox(msil, frame(ax, outv), pos, Vector3(0.030, 0.030, 0.008), 0.0025)
		put(skel, bone, mr.mesh(), strapm)
		put(skel, bone, msil.mesh(), silver)
		# silberne Leiste aussen am Schaft
		var ml := MB.new()
		patch(ml, {"o": o2, "ax": ax, "e1": e1, "e2": e2, "v0": 0.09, "v1": 0.33, "nv": 12, "nu": 3, "rad": grown,
			"span": func(_sv: float) -> Vector2: return Vector2(-0.07, 0.07),
			"t": 0.006, "bev": 0.003})
		put(skel, bone, ml.mesh(), silver)


# Armschienen mit Silberkanten und rotem Ärmelrand
static func arms(skel: Skeleton3D) -> void:
	var plate := mat(1, PLATE, 0.5, 0.45)
	var lea := mat(2, LEATHER, 0.0, 0.5)
	var silver := mat(0, SILVER, 0.92, 0.33)
	var red := mat(3, RED, 0.0, 0.9)
	for s in [-1.0, 1.0]:
		var side := "Left" if s > 0.0 else "Right"
		var bone := "mixamorig_%sForeArm" % side
		var o := Vector3(s * 0.4616, 1.4357, -0.0617)
		var ax := Vector3(s, 0, 0)
		var e1 := Vector3(0, 1, 0)
		var e2 := Vector3(0, 0, 1)
		var rad := func(v: float) -> Vector2:
			var f := clampf((v - 0.06) / 0.21, 0.0, 1.0)
			return Vector2(lerpf(0.054, 0.040, f), lerpf(0.057, 0.043, f))
		var grown := func(v: float) -> Vector2:
			var r: Vector2 = rad.call(v)
			return r + Vector2(0.004, 0.004)
		# Lederhülse
		var ml := MB.new()
		patch(ml, {"o": o, "ax": ax, "e1": e1, "e2": e2, "rad": rad, "v0": 0.058, "v1": 0.262, "nv": 6, "nu": 24, "ring": true, "t": 0.007, "bev": 0.004})
		put(skel, bone, ml.mesh(), lea)
		# Plattenschale (Aussenseite = oben in der T-Pose)
		var mp := MB.new()
		patch(mp, {"o": o, "ax": ax, "e1": e1, "e2": e2, "rad": grown, "v0": 0.072, "v1": 0.250, "nv": 8, "nu": 10, "t": 0.008, "bev": 0.006, "ridge": 0.004,
			"span": func(sv: float) -> Vector2:
				var h := deg_to_rad(lerpf(72.0, 50.0, sv))
				return Vector2(-h, h)})
		put(skel, bone, mp.mesh(), plate)
		# Silberkanten: Ringe an den Enden, Leisten an den Seiten
		var ms := MB.new()
		for rv in [[0.062, 0.080], [0.236, 0.256]]:
			patch(ms, {"o": o, "ax": ax, "e1": e1, "e2": e2, "rad": grown, "v0": rv[0], "v1": rv[1], "nv": 3, "nu": 24, "ring": true, "t": 0.010, "bev": 0.003})
		for sgn in [-1.0, 1.0]:
			patch(ms, {"o": o, "ax": ax, "e1": e1, "e2": e2, "rad": grown, "v0": 0.075, "v1": 0.248, "nv": 8, "nu": 2, "t": 0.012, "bev": 0.003,
				"span": func(sv: float) -> Vector2:
					var h := deg_to_rad(lerpf(72.0, 50.0, sv)) * float(sgn)
					return Vector2(h - deg_to_rad(5.5) * float(sgn), h)})
		put(skel, bone, ms.mesh(), silver)
		# roter Ärmelrand am Handgelenk
		var mr := MB.new()
		patch(mr, {"o": o, "ax": ax, "e1": e1, "e2": e2, "rad": func(_v): return Vector2(0.040, 0.043), "v0": 0.254, "v1": 0.280, "nv": 3, "nu": 24, "ring": true, "t": 0.008, "bev": 0.004})
		put(skel, bone, mr.mesh(), red)


# Umhang-Schulterstücke: dicker roter Stoff über den Schultern, wie im Film
static func mantle(skel: Skeleton3D) -> void:
	var red := mat(3, RED, 0.0, 0.9)
	var mb := MB.new()
	for s in [-1.0, 1.0]:
		var ax := Vector3(s, -0.16, 0).normalized()
		var e1 := Vector3(0.16 * s, 1, 0).normalized()
		patch(mb, {"o": Vector3(s * 0.04, 1.438, -0.058), "ax": ax, "e1": e1, "e2": Vector3(0, 0, 1), "v0": 0.015, "v1": 0.262, "nv": 12, "nu": 16,
			"rad": func(v: float) -> Vector2:
				var f := (v - 0.015) / 0.247
				var cap := sqrt(maxf(0.0, 1.0 - pow(maxf(f - 0.80, 0.0) / 0.20, 2.0)))
				return Vector2(0.090, 0.116) * cap,
			"span": func(_sv: float) -> Vector2: return Vector2(deg_to_rad(-112.0), deg_to_rad(74.0)),
			"t": 0.012, "bev": 0.010, "wear": 0.0})
	put(skel, "mixamorig_Spine2", mb.mesh(), red)


# ---------------------------------------------------------------- Mjolnir

# Hammer in der rechten Hand: Lage wie bisher (Griff entlang d, Kopf quer dazu), dunkelsilbernes Metall mit Gravur,
# Griff aus Leder mit Silberdraht-Geflecht, Lederschlaufe am Ende.
static func mjolnir(skel: Skeleton3D) -> void:
	var d := Vector3(-0.87, 0.0, 0.5)
	var b := frame(d, Vector3(0.5, 0.0, 0.87))
	var o := Vector3(-0.82, 1.425, -0.065)
	var B := "mixamorig_RightHand"
	var hm := mat(4, Color(0.50, 0.52, 0.57), 0.9, 0.36)
	var hm2 := mat(4, Color(0.62, 0.64, 0.69), 0.9, 0.30)
	var gr := mat(5, Color(0.1, 0.1, 0.1), 0.2, 0.6)
	var lea := mat(2, Color(0.05, 0.045, 0.045), 0.0, 0.6)
	var sil := mat(0, SILVER, 0.9, 0.3)
	# Kopf (Koordinaten: Mitte des Kopfes, y = Griffachse, z = lang)
	var hc := o + b.y * 0.285
	var mh := MB.new()
	cbox(mh, Basis.IDENTITY, Vector3.ZERO, Vector3(0.115, 0.105, 0.172), 0.010)
	put(skel, B, mh.mesh(), hm, Transform3D(b, hc))
	var me := MB.new()
	for s in [-1.0, 1.0]:
		cbox(me, Basis.IDENTITY, Vector3(0, 0, s * 0.0935), Vector3(0.124, 0.114, 0.034), 0.009)
	cbox(me, Basis.IDENTITY, Vector3(0, -0.0585, 0), Vector3(0.090, 0.014, 0.090), 0.004)
	put(skel, B, me.mesh(), hm2, Transform3D(b, hc))
	# Griff (Koordinaten: Mitte des Griffs, y = Länge)
	var mg := MB.new()
	lathe(mg, [Vector2(0.0, -0.19), Vector2(0.0165, -0.19), Vector2(0.0165, 0.15), Vector2(0.0, 0.15)], Basis.IDENTITY, Vector3.ZERO, 20)
	put(skel, B, mg.mesh(), gr, Transform3D(b, o + b.y * 0.06))
	# Knauf und Ringe
	var mk := MB.new()
	lathe(mk, [Vector2(0.0, -0.002), Vector2(0.023, -0.002), Vector2(0.023, 0.010), Vector2(0.0185, 0.014), Vector2(0.0, 0.014)], Basis.IDENTITY, Vector3.ZERO, 20, 0.5)
	put(skel, B, mk.mesh(), sil, Transform3D(b, o + b.y * -0.133))
	var mr := MB.new()
	lathe(mr, [Vector2(0.0, 0.0), Vector2(0.021, 0.0), Vector2(0.021, 0.006), Vector2(0.0, 0.006)], Basis.IDENTITY, Vector3.ZERO, 20, 0.5)
	put(skel, B, mr.mesh(), sil, Transform3D(b, o + b.y * 0.13))
	# Schlaufe am Griffende
	var tm := TorusMesh.new()
	tm.inner_radius = 0.032
	tm.outer_radius = 0.041
	tm.rings = 20
	tm.ring_segments = 8
	put(skel, B, tm, lea, Transform3D(b * Basis.from_euler(Vector3(0, 0, PI / 2)), o + b.y * -0.165))
