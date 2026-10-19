extends RefCounted
# Captain America (Avengers-Anzug): Zusatzteile (Helm-Klappen, Kinnriemen, Kragen, Schulterpolster, Gürtel mit
# Schnalle und Taschen, Stulpen, Stiefelschäfte mit Schienen) und die Form der Gesichtsöffnung der Haube.
# Alle Maße sind Ruhepose-Koordinaten der Mixamo-Figur (T-Pose, Meter, Füsse bei y=0, +Z vorn, +X links).
# Gemalt wird der Anzug in captain_suit.gdshaderinc; die Teile hier haben das Material captain_gear.gdshader.

const GEAR = preload("res://scripts/captain_gear.gdshader")

# ---------------------------------------------------------------- Gesichtsöffnung der Haube
# Gleiche Form wie cs_open() im Shader (captain_suit.gdshaderinc): Unterkante der Haube je Abstand von der Mitte
# plus zwei abgerundete Augenlöcher. Negativ = offen (Haut), positiv = Haube.
const YE_X := [0.0, 0.012, 0.030, 0.050, 0.068, 0.075, 0.095]
const YE_Y := [1.642, 1.642, 1.622, 1.613, 1.606, 1.600, 1.598]
const EYE_C := Vector2(0.0345, 1.6635)
const EYE_B := Vector2(0.0215, 0.0195)
const EYE_R := 0.011
const COWL := 0.0075  # Dicke der Haube über der Haut (m)


static func ye(ax: float) -> float:
	if ax <= YE_X[0]:
		return YE_Y[0]
	for i in range(YE_X.size() - 1):
		if ax <= YE_X[i + 1]:
			return lerpf(YE_Y[i], YE_Y[i + 1], (ax - YE_X[i]) / (YE_X[i + 1] - YE_X[i]))
	return YE_Y[YE_Y.size() - 1]


static func open_d(ax: float, y: float) -> float:
	var d_low := y - ye(ax)
	var q := Vector2(absf(ax - EYE_C.x), absf(y - EYE_C.y)) - (EYE_B - Vector2(EYE_R, EYE_R))
	var d_eye := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - EYE_R
	return minf(d_low, d_eye)


# ---------------------------------------------------------------- Bausteine

static func att(skel: Skeleton3D, bone: String) -> BoneAttachment3D:
	var n := "A_" + bone
	var ba := skel.get_node_or_null(n) as BoneAttachment3D
	if ba == null:
		ba = BoneAttachment3D.new()
		ba.name = n
		ba.bone_name = bone
		skel.add_child(ba)
	return ba


static func mat(kind: int, base: Color, worn: Color, wear: float = 0.5) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GEAR
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("base", base)
	m.set_shader_parameter("worn", worn)
	m.set_shader_parameter("wear", wear)
	return m


# Formen als Netz-Daten (ohne Render-Server, deshalb auch ohne Grafik nutzbar)
static func _arrays(v: PackedVector3Array, n: PackedVector3Array, idx: PackedInt32Array) -> Array:
	# Godot: Vorderseite = im Uhrzeigersinn. Dreiecke, die entgegen der Normale laufen, werden gedreht.
	for t in range(idx.size() / 3):
		var a0 := idx[t * 3]
		var a1 := idx[t * 3 + 1]
		var a2 := idx[t * 3 + 2]
		var c := (v[a1] - v[a0]).cross(v[a2] - v[a0])
		if c.dot(n[a0] + n[a1] + n[a2]) > 0.0:
			idx[t * 3 + 1] = a2
			idx[t * 3 + 2] = a1
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_NORMAL] = n
	a[Mesh.ARRAY_INDEX] = idx
	return a


static func box(s: Vector3) -> Array:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var idx := PackedInt32Array()
	var h := s * 0.5
	for f in range(6):
		var ax := f / 2
		var sg := 1.0 if f % 2 == 0 else -1.0
		var nrm := Vector3.ZERO
		nrm[ax] = sg
		var u := Vector3.ZERO
		u[(ax + 1) % 3] = 1.0
		var w := nrm.cross(u)
		var base := v.size()
		for c in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
			var p: Vector3 = nrm * h[ax] * 1.0 + u * c[0] * h[(ax + 1) % 3] + w * c[1] * h[(ax + 2) % 3] * sg
			v.append(p)
			n.append(nrm)
		if sg > 0.0:
			idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
		else:
			idx.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))
	return _arrays(v, n, idx)


# Kugel mit Radius 1 (rings x seg), hemi = nur obere Hälfte (+y)
static func sphere(seg: int = 20, hemi: bool = false) -> Array:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var idx := PackedInt32Array()
	var rings := seg / 2
	var top := rings / 2 if hemi else rings
	for r in range(top + 1):
		var a := PI * float(r) / float(rings)
		for s in range(seg + 1):
			var b := TAU * float(s) / float(seg)
			var p := Vector3(sin(a) * cos(b), cos(a), sin(a) * sin(b))
			v.append(p)
			n.append(p)
	for r in range(top):
		for s in range(seg):
			var i0 := r * (seg + 1) + s
			var i1 := i0 + 1
			var i2 := i0 + seg + 1
			var i3 := i2 + 1
			idx.append_array(PackedInt32Array([i0, i1, i2, i1, i3, i2]))
	return _arrays(v, n, idx)


static func dome(seg: int = 20) -> Array:
	return sphere(seg, true)


# Kegelstumpf (Achse = y, Mitte im Ursprung), offen oder mit Deckeln
static func tube(r_top: float, r_bot: float, h: float, seg: int = 24, caps: bool = true) -> Array:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var idx := PackedInt32Array()
	var slope := (r_bot - r_top) / h
	for s in range(seg + 1):
		var b := TAU * float(s) / float(seg)
		var d := Vector3(cos(b), 0.0, sin(b))
		var nn := Vector3(d.x, slope, d.z).normalized()
		v.append(d * r_top + Vector3(0, h * 0.5, 0))
		n.append(nn)
		v.append(d * r_bot - Vector3(0, h * 0.5, 0))
		n.append(nn)
	for s in range(seg):
		var i := s * 2
		idx.append_array(PackedInt32Array([i, i + 1, i + 2, i + 2, i + 1, i + 3]))
	if caps:
		for side in [1.0, -1.0]:
			var base := v.size()
			var rr := r_top if side > 0.0 else r_bot
			v.append(Vector3(0, side * h * 0.5, 0))
			n.append(Vector3(0, side, 0))
			for s in range(seg + 1):
				var b := TAU * float(s) / float(seg)
				v.append(Vector3(cos(b) * rr, side * h * 0.5, sin(b) * rr))
				n.append(Vector3(0, side, 0))
			for s in range(seg):
				if side > 0.0:
					idx.append_array(PackedInt32Array([base, base + s + 2, base + s + 1]))
				else:
					idx.append_array(PackedInt32Array([base, base + s + 1, base + s + 2]))
	return _arrays(v, n, idx)


# Gebogene Platte (Mantelstück eines Zylinders um die Achse y): Radius r, Länge h, Winkel a0..a1 (Bogenmass, 0 = +x),
# Dicke th, flare = Radiuszunahme über die Länge. Aussen- und Innenfläche, Kanten geschlossen.
static func shell(r: float, h: float, a0: float, a1: float, th: float, seg: int = 14, flare: float = 0.0) -> Array:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var idx := PackedInt32Array()
	var hh := h * 0.5
	for layer in range(4):
		# 0 aussen, 1 innen, 2 Kante oben, 3 Kante unten
		for i in range(seg + 1):
			var a := lerpf(a0, a1, float(i) / float(seg))
			var d := Vector3(cos(a), 0.0, sin(a))
			for j in range(2):
				var yy := -hh if j == 0 else hh
				var rr := r + flare * (yy / h)
				var p: Vector3
				var nn: Vector3
				if layer == 0:
					p = d * (rr + th) + Vector3(0, yy, 0)
					nn = d
				elif layer == 1:
					p = d * rr + Vector3(0, yy, 0)
					nn = -d
				elif layer == 2:
					p = d * (rr + th * (0.0 if j == 0 else 1.0)) + Vector3(0, hh, 0)
					nn = Vector3(0, 1, 0)
				else:
					p = d * (rr + th * (0.0 if j == 0 else 1.0)) + Vector3(0, -hh, 0)
					nn = Vector3(0, -1, 0)
				v.append(p)
				n.append(nn)
		var base := layer * (seg + 1) * 2
		for i in range(seg):
			var i0 := base + i * 2
			idx.append_array(PackedInt32Array([i0, i0 + 1, i0 + 2, i0 + 1, i0 + 3, i0 + 2]))
	# Seitenkanten (zwei Rechtecke an den Bogenenden)
	for e in range(2):
		var a := a0 if e == 0 else a1
		var d := Vector3(cos(a), 0.0, sin(a))
		var tn := Vector3(-d.z, 0.0, d.x) * (-1.0 if e == 0 else 1.0)
		var base := v.size()
		for k in [[0.0, -hh], [th, -hh], [th, hh], [0.0, hh]]:
			v.append(d * (r + k[0]) + Vector3(0, k[1], 0))
			n.append(tn)
		idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
	return _arrays(v, n, idx)


# Basis aus Achse (y) und grober zweiter Richtung (z)
static func frame(y: Vector3, z: Vector3) -> Basis:
	var by := y.normalized()
	var bx := by.cross(z).normalized()
	var bz := bx.cross(by).normalized()
	return Basis(bx, by, bz)


static func xf(pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot_deg * PI / 180.0) * Basis.from_scale(scl), pos)


# Band entlang einer Linie: pts = Mittellinie, up = Richtung "nach aussen" (Flächennormale) je Punkt,
# width = Breite, thick = Dicke. Gibt die Netz-Daten (Rechteckrohr) zurück.
static func ribbon(pts: Array, ups: Array, width: float, thick: float) -> Array:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var n := pts.size()
	var sec: Array = []
	for i in range(n):
		var t: Vector3 = ((pts[mini(i + 1, n - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		var u: Vector3 = (ups[i] as Vector3).normalized()
		var wv := u.cross(t).normalized()
		u = t.cross(wv).normalized()
		sec.append([pts[i], u, wv])
	# vier Flächen je Abschnitt: oben, unten, links, rechts (eigene Punkte für harte Kanten)
	for i in range(n):
		var c: Vector3 = sec[i][0]
		var u: Vector3 = sec[i][1]
		var wv: Vector3 = sec[i][2]
		var hw := wv * width * 0.5
		var hu := u * thick * 0.5
		var corners := [c - hw + hu, c + hw + hu, c + hw - hu, c - hw - hu]
		var nrm := [u, wv, -u, -wv]
		for f in range(4):
			var a: Vector3 = corners[f]
			var b: Vector3 = corners[(f + 1) % 4]
			verts.append(a)
			verts.append(b)
			norms.append(nrm[f])
			norms.append(nrm[f])
	for i in range(n - 1):
		for f in range(4):
			var a0 := i * 8 + f * 2
			var a1 := a0 + 1
			var b0 := (i + 1) * 8 + f * 2
			var b1 := b0 + 1
			idx.append_array(PackedInt32Array([a0, b0, a1, a1, b0, b1]))
	return _arrays(verts, norms, idx)


# Sammelt Teile je Knochen und Material in ein Netz (wenige Draw-Calls).
class Gear:
	var skel: Skeleton3D
	var groups := {}

	func _init(s: Skeleton3D) -> void:
		skel = s

	# part: Netz-Daten (box, tube, sphere, dome, ribbon)
	func add(bone: String, part: Array, m: Material, x: Transform3D) -> void:
		var key := bone + "|" + str(m.get_instance_id())
		if not groups.has(key):
			groups[key] = {"bone": bone, "mat": m, "v": PackedVector3Array(), "n": PackedVector3Array(), "i": PackedInt32Array()}
		var g: Dictionary = groups[key]
		var arrays: Array = part
		var t: Transform3D = skel.get_bone_global_rest(skel.find_bone(bone)).affine_inverse() * x
		var nb := t.basis.inverse().transposed()
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var gv: PackedVector3Array = g["v"]
		var gn: PackedVector3Array = g["n"]
		var gi: PackedInt32Array = g["i"]
		var base := gv.size()
		for k in range(v.size()):
			gv.append(t * v[k])
			gn.append((nb * n[k]).normalized())
		for k in idx:
			gi.append(base + k)
		g["v"] = gv
		g["n"] = gn
		g["i"] = gi

	func finish() -> void:
		if DisplayServer.get_name() == "headless":
			return  # ohne Grafik gibt es nichts zu zeigen
		for g in groups.values():
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = g["v"]
			arrays[Mesh.ARRAY_NORMAL] = g["n"]
			arrays[Mesh.ARRAY_INDEX] = g["i"]
			var am := ArrayMesh.new()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var mi := MeshInstance3D.new()
			mi.mesh = am
			mi.material_override = g["mat"]
			mi.name = "CapGear"
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # kleine Teile: Schatten wirft der Körper
			var n := "A_" + (g["bone"] as String)
			var ba := skel.get_node_or_null(n) as BoneAttachment3D
			if ba == null:
				ba = BoneAttachment3D.new()
				ba.name = n
				ba.bone_name = g["bone"]
				skel.add_child(ba)
			ba.add_child(mi)


# ---------------------------------------------------------------- Zusammenbau

static func build(skel: Skeleton3D) -> void:
	var g := Gear.new(skel)
	var leather := mat(0, Color(0.20, 0.12, 0.11), Color(0.38, 0.26, 0.22), 0.7)
	var leather2 := mat(0, Color(0.27, 0.19, 0.18), Color(0.42, 0.30, 0.26), 0.8)  # Taschen: etwas heller
	var strap_l := mat(0, Color(0.33, 0.21, 0.18), Color(0.46, 0.33, 0.28), 0.7)
	var black := mat(0, Color(0.10, 0.075, 0.07), Color(0.24, 0.19, 0.17), 0.6)
	var gun := mat(1, Color(0.24, 0.245, 0.26), Color(0.55, 0.56, 0.58), 0.8)
	var silver := mat(1, Color(0.58, 0.58, 0.57), Color(0.78, 0.78, 0.76), 0.6)
	var hood := mat(2, Color(0.26, 0.37, 0.53), Color(0.40, 0.50, 0.62), 0.5)
	var hood_hi := mat(4, Color(0.31, 0.42, 0.58), Color(0.46, 0.55, 0.66), 0.6)
	var collar := mat(2, Color(0.16, 0.25, 0.42), Color(0.30, 0.38, 0.52), 0.6)
	var pad := mat(4, Color(0.26, 0.27, 0.30), Color(0.44, 0.45, 0.48), 0.7)
	var pad2 := mat(4, Color(0.33, 0.34, 0.37), Color(0.50, 0.51, 0.54), 0.7)
	var grayband := mat(3, Color(0.50, 0.50, 0.52), Color(0.62, 0.62, 0.62), 0.5)
	var boot := mat(0, Color(0.22, 0.135, 0.095), Color(0.42, 0.30, 0.22), 0.9)
	var boot_hi := mat(0, Color(0.31, 0.19, 0.13), Color(0.48, 0.34, 0.25), 0.8)

	var H := "mixamorig_Head"
	var N := "mixamorig_Neck"
	var Hp := "mixamorig_Hips"
	var S2 := "mixamorig_Spine2"

	# --- Kopf: Ohrenklappen (Flügel) und Ringe für den Kinnriemen
	for s in [-1.0, 1.0]:
		var fl := Transform3D(Basis.from_euler(Vector3(0, 0, -s * 0.12)) * Basis.from_scale(Vector3(0.016, 0.050, 0.046)), Vector3(s * 0.085, 1.655, -0.004))
		g.add(H, sphere(18), hood_hi, fl)
		# drei flache Rippen nach hinten (Flügelform)
		for i in range(3):
			g.add(H, box(Vector3(0.006, 0.010, 0.040 - i * 0.008)), hood,
				xf(Vector3(s * 0.0985, 1.680 - i * 0.021, -0.024 - i * 0.004), Vector3(-6 - i * 4, 0, 0)))
		# Ring am unteren Rand
		g.add(H, tube(0.007, 0.007, 0.006, 12), silver, Transform3D(frame(Vector3(s, 0, 0), Vector3(0, 0, 1)), Vector3(s * 0.093, 1.612, 0.013)))
	# --- Kinnriemen: von beiden Ohrringen unter dem Kinn durch (Leder)
	var pts: Array = []
	var ups: Array = []
	var right := [Vector3(0.0, 1.538, 0.103), Vector3(0.022, 1.543, 0.095), Vector3(0.044, 1.556, 0.078), Vector3(0.062, 1.575, 0.052),
		Vector3(0.074, 1.595, 0.026), Vector3(0.082, 1.613, 0.012)]
	for i in range(right.size() - 1, 0, -1):
		var q: Vector3 = right[i]
		pts.append(Vector3(-q.x, q.y, q.z))
	for i in range(right.size()):
		pts.append(right[i])
	for q in pts:
		var c := Vector3(0, 1.585, -0.01)
		var o: Vector3 = (q as Vector3) - c
		ups.append(o)
	g.add(H, ribbon(pts, ups, 0.021, 0.006), strap_l, Transform3D.IDENTITY)
	# Schnalle seitlich am Kinnriemen
	for s in [-1.0, 1.0]:
		g.add(H, box(Vector3(0.007, 0.016, 0.013)), silver, Transform3D(Basis.from_euler(Vector3(0, 0, -s * 0.15)), Vector3(s * 0.0765, 1.588, 0.0345)))

	# --- Kragen (Stehkragen am Hals) mit Falz oben
	var tilt := Basis.from_euler(Vector3(-0.22, 0, 0))
	g.add(N, tube(0.056, 0.082, 0.062, 28, false), collar, Transform3D(tilt * Basis.from_scale(Vector3(1.0, 1.0, 0.96)), Vector3(0, 1.522, -0.036)))
	g.add(N, tube(0.0585, 0.0585, 0.012, 28, false), hood_hi, Transform3D(tilt * Basis.from_scale(Vector3(1.0, 1.0, 0.96)), Vector3(0, 1.557, -0.026)))

	# --- Schulterpanzer: vier überlappende, gerippte Lamellen auf dem Deltamuskel (aussen/oben), Nieten, Gurtband
	for s in [-1.0, 1.0]:
		var b := "mixamorig_LeftArm" if s > 0.0 else "mixamorig_RightArm"
		var bas := Basis(Vector3(0, 1, 0), Vector3(s, 0, 0), Vector3(0, 0, -s))
		var lam := [[0.246, 0.090, 0.062], [0.294, 0.082, 0.058], [0.340, 0.074, 0.054], [0.384, 0.069, 0.050]]
		for i in range(4):
			var L: Array = lam[i]
			var c := Vector3(s * (L[0] as float), 1.436, -0.062)
			g.add(b, shell(L[1], L[2], -1.78, 1.78, 0.0075, 18, 0.004), pad2 if i % 2 == 0 else pad, Transform3D(bas, c))
			# Nietenköpfe am Rand jeder Lamelle (zum Ellbogen hin)
			for k in [-0.8, 0.0, 0.8]:
				var off := Vector3(0, cos(float(k)), sin(float(k))) * ((L[1] as float) + 0.0085)
				g.add(b, sphere(8), silver, Transform3D(Basis.from_scale(Vector3(0.0030, 0.0030, 0.0030)), c + off + Vector3(s * ((L[2] as float) * 0.5 - 0.008), 0, 0)))
		# Gurt über der Schulter: Lederband quer um den Oberarm bei der zweiten Lamelle
		g.add(b, shell(0.0905, 0.012, -1.78, 1.78, 0.0035, 18), strap_l, Transform3D(bas, Vector3(s * 0.318, 1.436, -0.062)))

	# --- Stulpen (Handschuh-Schäfte) am Unterarm
	for s in [-1.0, 1.0]:
		var b := "mixamorig_LeftForeArm" if s > 0.0 else "mixamorig_RightForeArm"
		var ba := frame(Vector3(s, 0, 0), Vector3(0, 0, 1))
		var c := Vector3(0, 1.436, -0.062)
		# Manschette am Ellbogen
		g.add(b, tube(0.060, 0.057, 0.090, 24, false), leather2, Transform3D(ba, c + Vector3(s * 0.545, 0, 0)))
		g.add(b, tube(0.063, 0.063, 0.012, 24, false), strap_l, Transform3D(ba, c + Vector3(s * 0.505, 0, 0)))
		# graues Band
		g.add(b, tube(0.052, 0.052, 0.026, 24, true), grayband, Transform3D(ba, c + Vector3(s * 0.607, 0, 0)))
		# Schaft des Handschuhs
		g.add(b, tube(0.052, 0.046, 0.120, 24, true), black, Transform3D(ba, c + Vector3(s * 0.672, 0, 0)))
		for ax in [0.640, 0.695]:
			g.add(b, tube(0.0545, 0.0525, 0.016, 24, false), strap_l, Transform3D(ba, c + Vector3(s * ax, 0, 0)))
			g.add(b, box(Vector3(0.012, 0.012, 0.016)), silver, Transform3D(ba, c + Vector3(s * ax, 0.054, 0.0)))
		# Rand am Handgelenk
		g.add(b, tube(0.050, 0.050, 0.010, 24, false), leather2, Transform3D(ba, c + Vector3(s * 0.728, 0, 0)))

	# --- Gürtel: breiter Lederriemen mit Schnalle, zwei Taschen vorn, eine hinten
	g.add(Hp, tube(1.0, 1.0, 0.056, 40, false), leather, Transform3D(Basis.from_scale(Vector3(0.186, 1.0, 0.158)), Vector3(0, 1.072, -0.006)))
	g.add(Hp, tube(1.0, 1.0, 0.010, 40, false), strap_l, Transform3D(Basis.from_scale(Vector3(0.1875, 1.0, 0.1595)), Vector3(0, 1.0975, -0.006)))
	g.add(Hp, tube(1.0, 1.0, 0.010, 40, false), strap_l, Transform3D(Basis.from_scale(Vector3(0.1875, 1.0, 0.1595)), Vector3(0, 1.0465, -0.006)))
	# Schnalle: Rahmen mit zwei dunklen Fenstern
	g.add(Hp, box(Vector3(0.088, 0.054, 0.012)), gun, xf(Vector3(0, 1.072, 0.1625)))
	for s in [-1.0, 1.0]:
		g.add(Hp, box(Vector3(0.028, 0.032, 0.006)), black, xf(Vector3(s * 0.0225, 1.072, 0.168)))
	g.add(Hp, box(Vector3(0.010, 0.054, 0.016)), silver, xf(Vector3(0, 1.072, 0.1635)))
	# Taschen vorn
	for s in [-1.0, 1.0]:
		var rot := Basis.from_euler(Vector3(0, s * 0.62, 0))
		var o := Vector3(s * 0.138, 1.082, 0.082)
		g.add(Hp, box(Vector3(0.076, 0.098, 0.044)), leather2, Transform3D(rot, o))
		g.add(Hp, box(Vector3(0.080, 0.036, 0.050)), leather, Transform3D(rot, o + Vector3(0, 0.040, 0.002) * 1.0))
		g.add(Hp, box(Vector3(0.012, 0.086, 0.052)), strap_l, Transform3D(rot, o + rot * Vector3(-s * 0.016, 0.0, 0.002)))
		g.add(Hp, box(Vector3(0.012, 0.086, 0.052)), strap_l, Transform3D(rot, o + rot * Vector3(s * 0.016, 0.0, 0.002)))
		g.add(Hp, box(Vector3(0.016, 0.014, 0.056)), silver, Transform3D(rot, o + rot * Vector3(-s * 0.016, -0.020, 0.002)))
		g.add(Hp, box(Vector3(0.016, 0.014, 0.056)), silver, Transform3D(rot, o + rot * Vector3(s * 0.016, -0.020, 0.002)))
	# Tasche hinten
	g.add(Hp, box(Vector3(0.115, 0.074, 0.040)), leather2, xf(Vector3(0, 1.078, -0.162)))
	g.add(Hp, box(Vector3(0.120, 0.030, 0.046)), leather, xf(Vector3(0, 1.098, -0.162)))
	g.add(Hp, box(Vector3(0.016, 0.070, 0.048)), strap_l, xf(Vector3(0, 1.078, -0.162)))

	# --- Rückengurte: Ring in der Kreuzung (Spine2)
	g.add(S2, tube(0.024, 0.024, 0.008, 20), gun, Transform3D(frame(Vector3(0, 0, -1), Vector3(0, 1, 0)), Vector3(0, 1.262, -0.140)))
	g.add(S2, tube(0.012, 0.012, 0.010, 16), silver, Transform3D(frame(Vector3(0, 0, -1), Vector3(0, 1, 0)), Vector3(0, 1.262, -0.142)))

	# --- Stiefel: Schaft, Rand, Riemen, Schnallen und seitliche Schienen
	for s in [-1.0, 1.0]:
		var b := "mixamorig_LeftLeg" if s > 0.0 else "mixamorig_RightLeg"
		var cx: float = s * 0.092
		g.add(b, tube(0.071, 0.060, 0.265, 24, true), boot, Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 1.07)), Vector3(cx, 0.235, -0.040)))
		g.add(b, tube(0.077, 0.075, 0.020, 24, false), boot_hi, Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 1.07)), Vector3(cx, 0.372, -0.040)))
		for yy in [0.285, 0.335]:
			g.add(b, tube(0.0735, 0.0715, 0.016, 24, false), strap_l, Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 1.07)), Vector3(cx, yy, -0.040)))
			g.add(b, box(Vector3(0.008, 0.016, 0.016)), silver, Transform3D(Basis.IDENTITY, Vector3(cx + s * 0.0745, yy, -0.040)))
		# Schienen aussen und innen
		g.add(b, box(Vector3(0.010, 0.250, 0.016)), gun, Transform3D(Basis.IDENTITY, Vector3(cx + s * 0.066, 0.235, -0.040)))
		g.add(b, box(Vector3(0.010, 0.250, 0.016)), gun, Transform3D(Basis.IDENTITY, Vector3(cx - s * 0.066, 0.235, -0.040)))
		# Schnürung vorn: Zunge, Ösen beidseits, überkreuzte Schnürsenkel
		g.add(b, box(Vector3(0.046, 0.215, 0.004)), black, Transform3D(Basis.from_euler(Vector3(-0.09, 0, 0)), Vector3(cx, 0.255, 0.0365)))
		for k in range(8):
			var yy := 0.152 + 0.027 * k
			var zz := 0.0405 - 0.0026 * (yy - 0.152)
			for e in [-1.0, 1.0]:
				g.add(b, tube(0.0042, 0.0042, 0.003, 10, false), silver, Transform3D(frame(Vector3(0, 0, 1), Vector3(0, 1, 0)), Vector3(cx + e * 0.0185, yy, zz)))
			if k < 7:
				for dd in [-1.0, 1.0]:
					g.add(b, box(Vector3(0.0420, 0.0026, 0.0032)), strap_l, Transform3D(Basis.from_euler(Vector3(-0.09, 0, dd * 0.60)), Vector3(cx, yy + 0.0135, zz + 0.0012)))

	# --- Details: Druckknöpfe an den Taschen, Nieten am Gürtel, Nieten und Rand an den Ohrenklappen
	for s in [-1.0, 1.0]:
		var rot := Basis.from_euler(Vector3(0, s * 0.62, 0))
		var o := Vector3(s * 0.138, 1.082, 0.082)
		for yy in [0.040, -0.034]:
			g.add(Hp, sphere(10), silver, Transform3D(rot * Basis.from_scale(Vector3(0.0045, 0.0045, 0.0030)), o + rot * Vector3(0, yy, 0.0255)))
		# Laschen der Tasche (Riemen mit Naht) und Gürtelnieten
		for k in range(4):
			var a := 0.30 + 0.17 * k
			var q := Vector3(sin(a) * 0.1865 * s, 1.0715, cos(a) * 0.158 - 0.006)
			g.add(Hp, sphere(8), silver, Transform3D(Basis.from_scale(Vector3(0.0032, 0.0032, 0.0022)), q * Vector3(1.0, 1.0, 1.0) + Vector3(0, 0.0, 0.0)))
		# Ohrenklappe: Nietenreihe und Randwulst
		for k in [20.0, 60.0, 100.0, 140.0, 180.0]:
			var ar := deg_to_rad(k)
			g.add(H, sphere(8), silver, Transform3D(Basis.from_scale(Vector3(0.0028, 0.0028, 0.0028)),
				Vector3(s * 0.1010, 1.655 + 0.037 * sin(ar), -0.004 + 0.031 * cos(ar) * -1.0)))
		g.add(H, tube(0.0475, 0.0475, 0.004, 24, false), hood, Transform3D(frame(Vector3(s, 0, 0), Vector3(0, 0, 1)) * Basis.from_scale(Vector3(0.95, 1.0, 1.08)), Vector3(s * 0.1005, 1.655, -0.004)))
	g.finish()
