extends RefCounted
# Iron-Man-Rüstung (Mark III / Avengers-Look): Panzerplatten als Netze an den Knochen.
# Alle Maße sind Ruhepose-Koordinaten der Mixamo-Figur (T-Pose, Meter, Füsse bei y=0, +Z vorn, +X links).
# Gebaut wird für die linke Seite (x > 0), die rechte entsteht durch Spiegeln (Builder.sx).
# Stoffe (id): 0 roter Lack, 1 Gold, 2 Silber, 3 dunkles Metall, 4 helles Metall, 5 Leuchten, 6 Wabengitter, 7 Gesichtsplatte, 8 Helmschale
# Das Aussehen (Lack, Abnutzung, Kratzer) malt ironman_part.gdshader.

const PART_SHADER = preload("res://scripts/ironman_part.gdshader")
const RED := 0
const GOLD := 1
const SILVER := 2
const DARK := 3
const METAL := 4
const GLOW := 5
const HEX := 6
const FACE := 7
const HELM := 8

static var _mat: ShaderMaterial


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
		# Längen für Kantenabstand
		var su: Array = []
		for i in range(m):
			var l := 0.0
			for j in range(n - 1):
				l += ((P[i * n + j + 1] as Vector3) - (P[i * n + j] as Vector3)).length()
			su.append(l)
		var sv: Array = []
		for j in range(n):
			var l := 0.0
			for i in range(m - 1):
				l += ((P[(i + 1) * n + j] as Vector3) - (P[i * n + j] as Vector3)).length()
			sv.append(l)
		var cw := float(mat + 100 * trim)
		var base := vs.size()
		if not flat:
			for i in range(m):
				for j in range(n):
					vs.append(P[i * n + j])
					ns.append(N[i * n + j])
					uvs.append(Vector2(j / float(n - 1), i / float(m - 1)))
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
						uvs.append(Vector2(jj / float(n - 1), ii / float(m - 1)))
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
					uvs.append(Vector2(j / float(n - 1), i / float(m - 1)))
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
					_rim(pa, pb, pa - (N[ia] as Vector3) * thick, pb - (N[ib] as Vector3) * thick, outv, ia, ib, su, sv, n, cw)

	func _rim(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, outv: Vector3, ia: int, ib: int, su: Array, sv: Array, n: int, cw: float) -> void:
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


# ---------------------------------------------------------------- Anbringen

static func _att(skel: Skeleton3D, bone: String) -> BoneAttachment3D:
	var n := "A_" + bone
	var ba := skel.get_node_or_null(n) as BoneAttachment3D
	if ba == null:
		ba = BoneAttachment3D.new()
		ba.name = n
		ba.bone_name = bone
		skel.add_child(ba)
	return ba


static func _put(skel: Skeleton3D, bone: String, mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material()
	mi.transform = skel.get_bone_global_rest(skel.find_bone(bone)).affine_inverse()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_att(skel, bone).add_child(mi)
	return mi


static func _material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = PART_SHADER
	return _mat


# ---------------------------------------------------------------- Zusammenbau

const X := Vector3(1, 0, 0)
const Y := Vector3(0, 1, 0)
const Z := Vector3(0, 0, 1)
const AC := Vector3(0, 1.436, -0.062)  # Achse der Arme in der T-Pose

# Helm: [y, rx, rz, zc] (Halbachsen und Mitte des Querschnitts)
const HELM_KEYS := [
	[1.540, 0.054, 0.066, 0.040], [1.560, 0.070, 0.092, 0.020], [1.590, 0.083, 0.116, 0.010], [1.630, 0.090, 0.130, 0.006],
	[1.680, 0.093, 0.136, 0.004], [1.730, 0.090, 0.130, 0.004], [1.765, 0.078, 0.114, 0.006], [1.790, 0.052, 0.082, 0.008],
	[1.806, 0.020, 0.036, 0.008], [1.812, 0.001, 0.002, 0.008],
]
# Gesichtsplatte: halbe Breite je Höhe
const FACE_W := [
	[1.548, 0.016], [1.560, 0.034], [1.575, 0.043], [1.600, 0.054], [1.630, 0.063], [1.660, 0.071], [1.690, 0.076],
	[1.720, 0.074], [1.750, 0.068], [1.783, 0.056],
]


static func build(skel: Skeleton3D) -> void:
	var bs := {}  # Knochen -> Builder
	for bone in ["Head", "Neck", "Spine2", "Spine1", "Spine", "Hips", "LeftArm", "RightArm", "LeftForeArm", "RightForeArm",
			"LeftHand", "RightHand", "LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg", "LeftFoot", "RightFoot"]:
		var b := Builder.new()
		b.seed = float(bs.size()) * 13.7 + 1.0
		bs["mixamorig_" + bone] = b
	_helmet(bs["mixamorig_Head"])
	_neck(bs["mixamorig_Neck"])
	_chest(bs["mixamorig_Spine2"])
	_back(bs["mixamorig_Spine2"])
	_collar(bs["mixamorig_Spine2"])
	_abs(bs["mixamorig_Spine1"])
	_pelvis(bs["mixamorig_Hips"])
	for s in [1.0, -1.0]:
		var side := "Left" if s > 0.0 else "Right"
		for part in ["Arm", "ForeArm", "Hand", "UpLeg", "Leg", "Foot"]:
			(bs["mixamorig_" + side + part] as Builder).sx = s
		_shoulder(bs["mixamorig_" + side + "Arm"])
		_forearm(bs["mixamorig_" + side + "ForeArm"])
		_hand(bs["mixamorig_" + side + "Hand"])
		_thigh(bs["mixamorig_" + side + "UpLeg"])
		_shin(bs["mixamorig_" + side + "Leg"])
		_boot(bs["mixamorig_" + side + "Foot"])
		(bs["mixamorig_Spine2"] as Builder).sx = s
		_wing(bs["mixamorig_Spine2"])
		(bs["mixamorig_Spine2"] as Builder).sx = 1.0
	for bone in bs:
		var b: Builder = bs[bone]
		if b.vs.size() > 0:
			_put(skel, bone, b.mesh())


static func _g(x: float, s: float) -> float:
	return exp(-x * x / (2.0 * s * s))


# ---------------------------------------------------------------- Helm

static func _helmet(b: Builder) -> void:
	# Helmschale (rot)
	var R := []
	for i in range(30):
		var y := lerpf(1.540, 1.812, i / 29.0)
		var k := kf(HELM_KEYS, y)
		R.append(ring(Vector3(0, y, k[3]), X, Z, k[1], k[2], -180, 180, 40, 2.3))
	b.shell(R, HELM, Vector3(0, 1.66, 0.0), 0, 0.0)
	# Gesichtsplatte (gold) mit Relief: Brauen, Nase, Wangen, Mundplatte, Kinn
	var F := []
	var nr := 48
	var nc := 41
	for i in range(nr):
		var y := lerpf(1.548, 1.783, i / float(nr - 1))
		var k := kf(HELM_KEYS, y)
		var fw: float = kf(FACE_W, y)[1]
		var rx: float = k[1] + 0.007
		var rz: float = k[2] + 0.007
		var row := []
		for j in range(nc):
			var x := lerpf(-fw, fw, j / float(nc - 1))
			var ax := absf(x)
			var q := pow(clampf(ax / rx, 0.0, 0.985), 2.3)
			var z: float = float(k[3]) + rz * pow(1.0 - q, 1.0 / 2.3) + _face_relief(ax, y)
			row.append(Vector3(x, y, z))
		F.append(row)
	b.shell(F, FACE, Vector3(0, 1.66, 0.0), 0, 0.004)
	# Ohrscheiben
	for s in [1.0, -1.0]:
		b.sx = s
		lathe(b, Vector3(0.088, 1.665, 0.0), X, [[0.034, -0.006], [0.032, 0.002], [0.028, 0.006], [0.020, 0.0065], [0.010, 0.006]], RED, 1)
		b.sx = 1.0


static func _face_relief(ax: float, y: float) -> float:
	var h := 0.0
	# Nasenrücken
	h += 0.011 * _g(ax, 0.0075) * smoothstep(1.595, 1.625, y) * (1.0 - smoothstep(1.680, 1.700, y))
	# Brauenwulst und Augenfuge
	h += 0.006 * _g(y - (1.6935 + ax * 0.14), 0.0065) * (1.0 - smoothstep(0.055, 0.075, ax))
	h -= 0.0035 * _g(y - (1.6655 + ax * 0.30), 0.0055) * smoothstep(0.008, 0.014, ax) * (1.0 - smoothstep(0.050, 0.064, ax))
	# Wangen
	h += 0.004 * _g(ax - 0.046, 0.016) * _g(y - 1.630, 0.018)
	# Mundplatte steht vor, Kinn
	h += 0.0035 * (1.0 - smoothstep(1.590, 1.598, y))
	h += 0.005 * _g(y - 1.557, 0.010) * _g(ax, 0.02)
	# Stirn zurück, Kamm tiefer
	h -= 0.004 * smoothstep(1.72, 1.78, y)
	h -= 0.003 * (1.0 - smoothstep(0.016, 0.020, ax)) * smoothstep(1.708, 1.716, y)
	return h


static func _neck(b: Builder) -> void:
	tube(b, Vector3(0, 1.488, -0.03), Vector3(0, 1.552, -0.03), X, Z,
		[[0.0, 0.066, 0.070, -180, 180, 2.2, 0, 0], [0.5, 0.058, 0.062, -180, 180, 2.2, 0, 0], [1.0, 0.062, 0.066, -180, 180, 2.2, 0, 0]], DARK, 0, 6, 24, 0.0)


# ---------------------------------------------------------------- Rumpf

static func _chest(c: Builder) -> void:
	# Brustplatte: je Seite eine Hälfte (Mittelnaht), oben Kragen, unten V-förmig
	var ys := [1.480, 1.455, 1.425, 1.395, 1.365, 1.335, 1.305, 1.275, 1.245, 1.215, 1.190]
	for s in [1.0, -1.0]:
		c.sx = s
		var R := []
		for y in ys:
			var rx := remap(y, 1.19, 1.48, 0.150, 0.190)
			var rz := remap(y, 1.19, 1.48, 0.140, 0.122)
			rz = lerpf(rz, 0.168, smoothstep(1.48, 1.37, y) * smoothstep(1.19, 1.30, y))
			var half := lerpf(4.0, 104.0, smoothstep(1.19, 1.36, y))
			R.append(ring(Vector3(0, y, 0.01), X, Z, rx, rz, 0.0, half, 12, 2.6))
		c.shell(R, RED, Vector3(0.0, 1.3, -0.1), 4, 0.008)
	c.sx = 1.0
	# Arc-Reaktor: Ring, dunkle Fassung, leuchtende Mitte
	var rc := Vector3(0, 1.322, 0.178)
	lathe(c, rc, Z, [[0.070, -0.006], [0.066, 0.006], [0.058, 0.013], [0.050, 0.012], [0.046, 0.007]], METAL)
	lathe(c, rc, Z, [[0.046, 0.007], [0.044, 0.004], [0.040, 0.003]], DARK)
	lathe(c, rc, Z, [[0.040, 0.003], [0.035, 0.0035], [0.030, 0.004], [0.025, 0.0045], [0.020, 0.005], [0.015, 0.0055], [0.010, 0.006], [0.005, 0.0063], [0.0, 0.0065]], GLOW)


static func _back(c: Builder) -> void:
	# Rückenplatte (rot), Wabenfeld, goldene V-Platte
	var Rb := []
	for y in [1.46, 1.42, 1.38, 1.34, 1.30, 1.26, 1.22, 1.18]:
		Rb.append(ring(Vector3(0, y, -0.01), X, Z, 0.17, 0.125, 118, 242, 14, 2.6))
	c.shell(Rb, RED, Vector3(0, 1.3, 0.1), 2, 0.008)
	var Hx := []
	for y in [1.425, 1.39, 1.355, 1.32, 1.285]:
		var row := []
		for j in range(9):
			var x := lerpf(-0.075, 0.075, j / 8.0)
			row.append(Vector3(x, y, -0.148))
		Hx.append(row)
	c.shell(Hx, HEX, Vector3(0, 1.3, 0.0), 3, 0.006)
	var Gv := []
	for y in [1.30, 1.27, 1.24, 1.21, 1.185]:
		var w := remap(y, 1.185, 1.30, 0.030, 0.125)
		var da := rad_to_deg(asin(clampf(w / 0.171, 0.0, 1.0)))
		Gv.append(ring(Vector3(0, y, -0.01), X, Z, 0.171, 0.126, 180.0 - da, 180.0 + da, 10, 2.6))
	c.shell(Gv, GOLD, Vector3(0, 1.3, 0.1), 2, 0.008)


static func _wing(c: Builder) -> void:
	var pts := [Vector3(0.075, 1.350, -0.150), Vector3(0.100, 1.405, -0.172), Vector3(0.135, 1.468, -0.182), Vector3(0.178, 1.528, -0.178),
		Vector3(0.225, 1.580, -0.166)]
	blade(c, pts, [0.036, 0.034, 0.029, 0.021, 0.005], Vector3(1, -0.5, 0), 0.38, RED, 1, 7, 0.010)


static func _pelvis(h: Builder) -> void:
	# Gürtelring
	tube(h, Vector3(0, 1.04, -0.01), Vector3(0, 0.985, -0.01), X, Z,
		[[0.0, 0.178, 0.150, -180, 180, 2.6, 0, 0], [1.0, 0.184, 0.156, -180, 180, 2.6, 0, 0]], RED, 1, 4, 30, 0.006)
	# vordere V-Platte
	for s in [1.0, -1.0]:
		h.sx = s
		var R := []
		for y in [0.985, 0.960, 0.935, 0.910, 0.890]:
			var half := remap(y, 0.89, 0.985, 6.0, 48.0)
			R.append(ring(Vector3(0, y, 0.0), X, Z, 0.170, 0.155 - (0.985 - y) * 0.15, 0.0, half, 8, 2.6))
		h.shell(R, RED, Vector3(0, 0.95, -0.2), 2, 0.006)
	h.sx = 1.0


# ---------------------------------------------------------------- Arme

static func _shoulder(b: Builder) -> void:
	# Schulterkappe (rot) mit goldener Kantenlinie, darunter eine Lamelle
	var keys := [
		[0.00, 0.074, 0.094, -10, 190, 2.8, 0.012, 0.0],
		[0.25, 0.090, 0.106, -15, 195, 2.8, 0.012, 0.0],
		[0.55, 0.090, 0.104, -20, 200, 2.8, 0.0, 0.0],
		[0.85, 0.080, 0.094, -25, 205, 2.8, -0.008, 0.0],
		[1.00, 0.074, 0.088, -30, 210, 2.8, -0.012, 0.0],
	]
	tube(b, Vector3(0.10, AC.y, AC.z), Vector3(0.33, AC.y, AC.z), Y, Z, keys, RED, 1, 12, 20, 0.008)
	tube(b, Vector3(0.25, AC.y, AC.z), Vector3(0.355, AC.y, AC.z), Y, Z,
		[[0.0, 0.080, 0.092, -20, 200, 2.8, -0.006, 0], [1.0, 0.072, 0.082, -20, 200, 2.8, -0.006, 0]], RED, 1, 5, 16, 0.006)
	# Oberarm: goldene Platte
	tube(b, Vector3(0.345, AC.y, AC.z), Vector3(0.458, AC.y, AC.z), Y, Z,
		[[0.0, 0.070, 0.070, -60, 240, 2.8, 0, 0], [0.5, 0.076, 0.076, -60, 240, 2.8, 0, 0], [1.0, 0.068, 0.068, -60, 240, 2.8, 0, 0]], GOLD, 2, 7, 18, 0.006)


static func _forearm(b: Builder) -> void:
	# Ellbogenring, Unterarm-Panzer (rot, dicker zum Handgelenk), goldene Manschette
	tube(b, Vector3(0.452, AC.y, AC.z), Vector3(0.50, AC.y, AC.z), Y, Z,
		[[0.0, 0.068, 0.070, -180, 180, 2.6, 0, 0], [0.5, 0.074, 0.076, -180, 180, 2.6, 0, 0], [1.0, 0.070, 0.072, -180, 180, 2.6, 0, 0]], RED, 3, 5, 22, 0.006)
	var keys := [
		[0.00, 0.068, 0.070, -180, 180, 2.6, 0, 0],
		[0.35, 0.078, 0.082, -180, 180, 2.6, 0, 0],
		[0.60, 0.084, 0.088, -180, 180, 2.6, 0, 0],
		[0.90, 0.076, 0.076, -180, 180, 2.6, 0, 0],
		[1.00, 0.070, 0.070, -180, 180, 2.6, 0, 0],
	]
	tube(b, Vector3(0.495, AC.y, AC.z), Vector3(0.695, AC.y, AC.z), Y, Z, keys, RED, 1, 10, 22, 0.006)
	tube(b, Vector3(0.690, AC.y, AC.z), Vector3(0.738, AC.y, AC.z), Y, Z,
		[[0.0, 0.074, 0.074, -180, 180, 2.6, 0, 0], [0.5, 0.072, 0.072, -180, 180, 2.6, 0, 0], [1.0, 0.066, 0.066, -180, 180, 2.6, 0, 0]], GOLD, 2, 5, 22, 0.006)


static func _hand(b: Builder) -> void:
	# Handrücken-Platte
	tube(b, Vector3(0.745, AC.y + 0.01, AC.z), Vector3(0.84, AC.y + 0.01, AC.z), Y, Z,
		[[0.0, 0.040, 0.056, -20, 200, 2.6, 0, 0], [1.0, 0.030, 0.052, -20, 200, 2.6, 0, 0]], RED, 1, 6, 12, 0.005)


# ---------------------------------------------------------------- Beine

static func _thigh(b: Builder) -> void:
	var a := Vector3(0.093, 0.95, 0.0)
	var e := Vector3(0.093, 0.52, -0.005)
	tube(b, a, e, X, Z, [[0.0, 0.098, 0.112, -180, 180, 2.6, 0, 0], [0.3, 0.100, 0.114, -180, 180, 2.6, 0, 0],
		[0.7, 0.088, 0.094, -180, 180, 2.6, 0, 0], [1.0, 0.078, 0.082, -180, 180, 2.6, 0, 0]], RED, 0, 10, 24, 0.006)
	# Silber-Platte vorn, goldener Streifen in der Mitte
	tube(b, a.lerp(e, 0.08), a.lerp(e, 0.86), X, Z, [[0.0, 0.106, 0.122, -46, 46, 2.6, 0, 0], [1.0, 0.088, 0.096, -38, 38, 2.6, 0, 0]], SILVER, 1, 8, 12, 0.006)
	tube(b, a.lerp(e, 0.10), a.lerp(e, 0.80), X, Z, [[0.0, 0.110, 0.130, -8, 8, 2.6, 0, 0], [1.0, 0.091, 0.104, -8, 8, 2.6, 0, 0]], GOLD, 0, 8, 4, 0.004)


static func _shin(b: Builder) -> void:
	var a := Vector3(0.0937, 0.52, -0.017)
	var e := Vector3(0.0912, 0.14, -0.037)
	tube(b, a, e, X, Z, [[0.0, 0.074, 0.084, -180, 180, 2.6, 0, 0], [0.4, 0.074, 0.090, -180, 180, 2.6, 0, 0],
		[1.0, 0.060, 0.070, -180, 180, 2.6, 0, 0]], RED, 0, 10, 24, 0.006)
	# Kniescheibe: rot mit goldenem Rand
	tube(b, Vector3(0.0937, 0.600, -0.012), Vector3(0.0937, 0.480, -0.019), X, Z,
		[[0.0, 0.062, 0.074, -70, 70, 2.6, 0, 0], [0.5, 0.082, 0.102, -78, 78, 2.6, 0, 0], [1.0, 0.064, 0.078, -66, 66, 2.6, 0, 0]], RED, 1, 8, 12, 0.008)
	# Schienbeinplatte (silber)
	tube(b, a.lerp(e, 0.22), a.lerp(e, 0.78), X, Z, [[0.0, 0.080, 0.096, -44, 44, 2.6, 0, 0], [1.0, 0.066, 0.080, -36, 36, 2.6, 0, 0]], SILVER, 1, 8, 12, 0.006)
	# goldener Knöchelring
	tube(b, a.lerp(e, 0.86), a.lerp(e, 0.98), X, Z, [[0.0, 0.066, 0.076, -180, 180, 2.6, 0, 0], [1.0, 0.062, 0.072, -180, 180, 2.6, 0, 0]], GOLD, 2, 4, 20, 0.005)


# Querschnitt des Stiefels bei z (Ringe in der XY-Ebene): [Mitte y, Halbhöhe, Halbbreite]
static func _boot_sec(z: float, grow: float) -> Array:
	var top := 0.092
	var hw := 0.066
	if z > 0.0:
		top = lerpf(0.092, 0.05, smoothstep(0.0, 0.2, z))
		hw = lerpf(0.066, 0.056, smoothstep(0.0, 0.2, z))
	if z > 0.2:
		top = lerpf(top, 0.022, (z - 0.2) / 0.05)
		hw = lerpf(hw, 0.022, (z - 0.2) / 0.05)
	return [top * 0.5, maxf(top * 0.5 + grow, 0.004), hw + grow]


static func _boot(b: Builder) -> void:
	# Stiefel: Reihen von hinten (Ferse) nach vorn (Zehen), vorn eine goldene Kappe
	var R := []
	for z in [-0.108, -0.095, -0.06, -0.02, 0.03, 0.08, 0.13, 0.17]:
		var s := _boot_sec(z, 0.0)
		R.append(ring(Vector3(0.093, s[0], z), X, Y, s[2], s[1], 0, 360, 20, 2.6))
	b.shell(R, RED, Vector3(0.093, 0.04, 0.0), 1, 0.0)
	var C := []
	for z in [0.165, 0.185, 0.205, 0.225, 0.24, 0.252, 0.258]:
		var s := _boot_sec(z, 0.004)
		C.append(ring(Vector3(0.093, s[0], z), X, Y, s[2], s[1], 0, 360, 20, 2.6))
	b.shell(C, GOLD, Vector3(0.093, 0.04, 0.0), 0, 0.0)
	# Ferse: goldener Streifen hinten
	var H := []
	for y in [0.025, 0.045, 0.065, 0.085]:
		H.append(ring(Vector3(0.093, y, -0.015), X, Z, 0.070, 0.098, 160, 200, 5, 2.6))
	b.shell(H, GOLD, Vector3(0.093, 0.05, 0.0), 2, 0.005)


# Kopf der Figur weglassen (der Helm ersetzt ihn): Dreiecke, die ganz über y_min liegen (Ruhepose)
static func cut_head(arrays: Array, y_min: float = 1.55) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var out := PackedInt32Array()
	for t in range(idx.size() / 3):
		var a := idx[t * 3]
		var b := idx[t * 3 + 1]
		var c := idx[t * 3 + 2]
		if minf(verts[a].y, minf(verts[b].y, verts[c].y)) > y_min:
			continue
		out.append(a)
		out.append(b)
		out.append(c)
	arrays[Mesh.ARRAY_INDEX] = out
	return arrays


# Kragenplatten (silber) beidseits des Halses
static func _collar(c: Builder) -> void:
	for s in [1.0, -1.0]:
		c.sx = s
		var R := []
		for i in range(5):
			var x := lerpf(0.058, 0.128, i / 4.0)
			var row := []
			for j in range(7):
				var z := lerpf(-0.095, 0.045, j / 6.0)
				var bump := 0.010 * (1.0 - pow((z + 0.025) / 0.07, 2.0))
				row.append(Vector3(x, 1.534 - (x - 0.058) * 0.34 + bump, z))
			R.append(row)
		c.shell(R, SILVER, Vector3(0.09, 1.40, -0.03), 2, 0.008)
	c.sx = 1.0


# Bauchplatten: vier gewölbte Bänder, an den Seiten goldene Stücke
static func _abs(a: Builder) -> void:
	var tops := [1.190, 1.150, 1.110, 1.070]
	for k in range(tops.size()):
		var y0: float = tops[k]
		var y1 := y0 - 0.042
		var rz := lerpf(0.152, 0.158, k / 3.0)
		var rx := 0.146
		for part in range(2):
			var a0 := 0.0 if part == 0 else 58.0
			var a1 := 54.0 if part == 0 else 92.0
			var R := []
			for i in range(3):
				var y := lerpf(y0, y1, i / 2.0)
				var bulge := 0.004 * (1.0 - pow((i - 1.0), 2.0))
				var row := []
				for s in [1.0, -1.0]:
					pass
				R.append(ring(Vector3(0, y, 0.0), X, Z, rx + bulge, rz + bulge, a0, a1, 6, 2.4))
			for s in [1.0, -1.0]:
				a.sx = s
				a.shell(R, RED if part == 0 else GOLD, Vector3(0, y0, -0.1), 2 if part == 0 else 0, 0.005)
	a.sx = 1.0
