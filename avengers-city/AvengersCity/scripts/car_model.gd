extends RefCounted
# Auto-Modelle (prozedural): Karosserie als Querschnitts-Loft mit glatten Kanten, Scheiben extra, Raeder getrennt.
# Details (Lampen, Grill, Tuerfugen, Felgen) zeichnet der Shader city_car.gdshader nach Position/Art.
# Front zeigt nach -Z, Ursprung = Mitte der Bodenflaeche. Art des Teils steckt in COLOR.a (Art / 15).

const K_PAINT := 0
const K_FIXED := 1
const K_TRIM := 2
const K_CHROME := 3
const K_TIRE := 4
const K_RIM := 5
const K_INT := 6
const K_EMIT := 8
const K_BAR := 9
const K_UNDER := 10
const K_PLATE := 11

# Typ, Gewicht (parken), Gewicht (Verkehr)
const LIST := [
	["sedan", 5.0, 5.0], ["hatch", 2.5, 2.5], ["suv", 4.0, 4.0], ["pickup", 1.3, 1.0],
	["van", 1.2, 1.3], ["taxi", 1.6, 3.0], ["police", 0.35, 0.8], ["bus", 0.0, 0.9],
]

const BASE := {
	"L": 4.80, "W": 1.84, "R": 0.33, "ww": 0.225, "axle": [1.0, 3.85],
	"deck": [[0, 0.78], [0.25, 0.82], [1.45, 0.94], [1.7, 0.955], [3.9, 0.965], [4.6, 0.985], [4.8, 0.95]],
	"yb": [[0, 0.30], [0.35, 0.20], [0.9, 0.15], [3.8, 0.15], [4.5, 0.20], [4.8, 0.28]],
	"roof": [[1.42, 0.0], [2.32, 1.44], [3.42, 1.44], [4.02, 0.0]],
	"ws": [1.42, 2.32], "rw": [3.42, 4.02],
	"tb": 0.90, "tr": 0.75, "rp": [0.55, 0.50], "rv": [0.13, 0.10],
	"glass": [[1.78, 2.56], [2.64, 3.34], [3.42, 3.80]],
	"doors": [1.62, 2.60, 3.47, -99.0], "belt": 0.95,
	"hl": [0.52, 1.2, 0.58, 0.72], "tl": [0.52, 1.2, 0.74, 0.90], "gr": [0.42, 0.50, 0.66],
	"seats": [2.65, 3.45], "dash": 1.95, "mirror": 1.82, "plate_y": [0.51, 0.66],
	"bed": [], "flags": [], "dark": 0.35,
}

static var _spec := {}
static var _meshes := {}
static var _mats := {}
static var _glass: ShaderMaterial
static var _wheels := {}


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

	func mesh_arrays() -> Array:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_INDEX] = idx
		return arr


static func kc(kind: int, col: Color = Color.WHITE) -> Color:
	return Color(col.r, col.g, col.b, kind / 15.0)


# ---------- Typen ----------

static func spec(type: String) -> Dictionary:
	if _spec.is_empty():
		var s: Dictionary = BASE.duplicate(true)
		_spec["sedan"] = s
		var taxi := _derive(s, {"flags": ["taxi"]})
		_spec["taxi"] = taxi
		_spec["police"] = _derive(s, {"flags": ["police"]})
		_spec["hatch"] = _derive(s, {
			"L": 4.05, "W": 1.78, "R": 0.31, "ww": 0.205, "axle": [0.85, 3.2],
			"deck": [[0, 0.74], [0.2, 0.78], [1.15, 0.89], [1.4, 0.91], [3.7, 0.96], [4.05, 0.93]],
			"yb": [[0, 0.28], [0.3, 0.19], [0.8, 0.15], [3.3, 0.15], [3.85, 0.20], [4.05, 0.27]],
			"roof": [[1.18, 0.0], [1.95, 1.46], [3.5, 1.47], [4.0, 0.0]], "ws": [1.18, 1.95], "rw": [3.5, 4.0],
			"glass": [[1.55, 2.3], [2.36, 3.0], [3.06, 3.55]], "doors": [1.4, 2.25, 3.05, -99.0],
			"seats": [2.2, 2.95], "dash": 1.6, "mirror": 1.55, "rp": [0.5, 0.4],
		})
		_spec["suv"] = _derive(s, {
			"L": 4.85, "W": 1.95, "R": 0.38, "ww": 0.25, "axle": [1.0, 3.9],
			"deck": [[0, 0.90], [0.25, 0.98], [1.45, 1.07], [1.7, 1.11], [4.4, 1.13], [4.85, 1.09]],
			"yb": [[0, 0.38], [0.35, 0.27], [0.9, 0.22], [4.0, 0.22], [4.55, 0.26], [4.85, 0.36]],
			"roof": [[1.48, 0.0], [2.3, 1.75], [4.35, 1.76], [4.83, 0.0]], "ws": [1.48, 2.3], "rw": [4.35, 4.83],
			"glass": [[1.85, 2.65], [2.72, 3.55], [3.62, 4.4]], "doors": [1.7, 2.68, 3.6, -99.0],
			"tb": 0.92, "tr": 0.82, "rp": [0.55, 0.40], "rv": [0.15, 0.10], "belt": 1.1,
			"hl": [0.55, 1.3, 0.70, 0.84], "tl": [0.62, 1.3, 0.86, 1.04], "gr": [0.5, 0.60, 0.80], "plate_y": [0.58, 0.76],
			"seats": [2.7, 3.55], "dash": 1.95, "mirror": 1.85, "dark": 0.55,
		})
		_spec["pickup"] = _derive(s, {
			"L": 5.45, "W": 2.0, "R": 0.38, "ww": 0.25, "axle": [1.05, 4.25],
			"deck": [[0, 0.92], [0.25, 1.0], [1.5, 1.09], [1.75, 1.12], [5.45, 1.13]],
			"yb": [[0, 0.40], [0.35, 0.28], [0.9, 0.24], [4.8, 0.24], [5.45, 0.36]],
			"roof": [[1.55, 0.0], [2.35, 1.82], [3.55, 1.82], [3.72, 0.0]], "ws": [1.55, 2.35], "rw": [3.55, 3.72],
			"glass": [[1.9, 2.65], [2.73, 3.5]], "doors": [1.7, 2.7, 3.6, -99.0],
			"tb": 0.92, "tr": 0.82, "rp": [0.55, 0.15], "rv": [0.15, 0.08], "belt": 1.12,
			"bed": [3.74, 5.45, 0.34], "tl": [0.8, 1.3, 0.80, 1.02], "hl": [0.55, 1.3, 0.72, 0.86], "gr": [0.5, 0.62, 0.84], "plate_y": [0.58, 0.8],
			"seats": [2.7, 3.35], "dash": 1.95, "mirror": 1.85, "dark": 0.55,
		})
		_spec["van"] = _derive(s, {
			"L": 5.7, "W": 2.0, "R": 0.36, "ww": 0.235, "axle": [1.15, 4.5],
			"deck": [[0, 0.84], [0.2, 0.9], [1.1, 1.0], [1.3, 1.03], [5.7, 1.03]],
			"yb": [[0, 0.36], [0.3, 0.26], [0.9, 0.22], [5.2, 0.22], [5.7, 0.32]],
			"roof": [[1.2, 0.0], [1.62, 2.35], [2.1, 2.45], [5.55, 2.55], [5.7, 2.45]], "ws": [1.2, 1.62], "rw": [],
			"glass": [[1.3, 2.1]], "doors": [1.32, 2.15, -99.0, -99.0],
			"tb": 0.97, "tr": 0.94, "rp": [0.5, 0.12], "rv": [0.13, 0.06], "belt": 1.1,
			"hl": [0.55, 1.3, 0.66, 0.82], "tl": [0.82, 1.3, 0.80, 1.22], "gr": [0.5, 0.58, 0.78], "plate_y": [0.56, 0.74],
			"seats": [1.85], "dash": 1.4, "mirror": 1.35, "dark": 0.2,
		})
		_spec["bus"] = _derive(s, {
			"L": 11.0, "W": 2.55, "R": 0.48, "ww": 0.3, "axle": [2.3, 8.2],
			"deck": [[0, 1.12], [0.3, 1.16], [1.0, 1.2], [11, 1.2]],
			"yb": [[0, 0.46], [0.35, 0.34], [0.9, 0.30], [10.5, 0.30], [11, 0.40]],
			"roof": [[0.15, 0.0], [0.6, 3.05], [1.2, 3.15], [10.8, 3.2], [11.0, 3.0]], "ws": [0.15, 0.6], "rw": [],
			"glass": [[1.0, 2.9], [3.1, 5.0], [5.2, 7.1], [7.3, 9.2], [9.4, 10.6]], "doors": [-99.0, -99.0, -99.0, -99.0],
			"tb": 0.985, "tr": 0.955, "rp": [0.4, 0.3], "rv": [0.15, 0.1], "belt": 1.2,
			"hl": [0.7, 1.4, 0.62, 0.8], "tl": [0.8, 1.4, 0.8, 1.1], "gr": [0.5, 0.6, 0.9], "plate_y": [0.62, 0.8],
			"seats": [], "dash": 0.9, "mirror": 0.9, "dark": 0.45,
		})
	return _spec[type]


static func _derive(base: Dictionary, over: Dictionary) -> Dictionary:
	var d: Dictionary = base.duplicate(true)
	for k in over:
		d[k] = over[k]
	return d


static func info(type: String) -> Dictionary:
	var sp := spec(type)
	var L: float = sp["L"]
	var W: float = sp["W"]
	var R: float = sp["R"]
	var roof_h := 0.0
	for p in sp["roof"]:
		roof_h = maxf(roof_h, p[1])
	var wx: float = W * 0.5 - 0.14
	var ax: Array = sp["axle"]
	var wheels := [
		Vector3(wx, R, -L * 0.5 + ax[0]), Vector3(-wx, R, -L * 0.5 + ax[0]),
		Vector3(wx, R, -L * 0.5 + ax[1]), Vector3(-wx, R, -L * 0.5 + ax[1]),
	]
	return {"size": Vector3(W, roof_h, L), "R": R, "wheels": wheels, "wheelbase": ax[1] - ax[0]}


static func pick_type(rng: RandomNumberGenerator, traffic: bool) -> String:
	var total := 0.0
	var wi := 2 if traffic else 1
	for e in LIST:
		total += e[wi]
	var r := rng.randf() * total
	for e in LIST:
		r -= e[wi]
		if r <= 0.0 and e[wi] > 0.0:
			return e[0]
	return "sedan"


const PAINTS := [
	[Color(0.90, 0.90, 0.92), 22.0], [Color(0.035, 0.035, 0.04), 15.0], [Color(0.60, 0.62, 0.65), 16.0], [Color(0.26, 0.28, 0.31), 12.0],
	[Color(0.68, 0.06, 0.07), 8.0], [Color(0.10, 0.24, 0.60), 8.0], [Color(0.05, 0.10, 0.28), 4.0], [Color(0.07, 0.34, 0.20), 3.0],
	[Color(0.78, 0.30, 0.05), 1.5], [Color(0.85, 0.66, 0.06), 1.0], [Color(0.24, 0.14, 0.08), 3.0], [Color(0.70, 0.63, 0.50), 3.0],
]


static func pick_paint(rng: RandomNumberGenerator, type: String) -> Color:
	if type == "taxi":
		return Color(0.97, 0.78, 0.03)
	if type == "police":
		return Color(0.02, 0.02, 0.025)
	if type == "bus":
		return [Color(0.08, 0.28, 0.55), Color(0.75, 0.08, 0.08), Color(0.9, 0.9, 0.92)][rng.randi() % 3]
	var total := 0.0
	for p in PAINTS:
		total += p[1]
	var r := rng.randf() * total
	for p in PAINTS:
		r -= p[1]
		if r <= 0.0:
			return p[0]
	return PAINTS[0][0]


# ---------- Materialien ----------

static func glass_material() -> ShaderMaterial:
	if _glass == null:
		_glass = ShaderMaterial.new()
		_glass.shader = load("res://scripts/city_car_glass.gdshader")
	return _glass


# Gemeinsames Material fuer MultiMesh (Lack und Bremslicht aus Instanzdaten)
static func material(type: String) -> ShaderMaterial:
	if not _mats.has(type):
		var m := ShaderMaterial.new()
		m.shader = load("res://scripts/city_car.gdshader")
		var sp := spec(type)
		var L: float = sp["L"]
		var hw: float = sp["W"] * 0.5
		var ax: Array = sp["axle"]
		m.set_shader_parameter("body", Vector4(hw, L, sp["belt"], 0.30))
		m.set_shader_parameter("wheelp", Vector4(-L * 0.5 + ax[0], -L * 0.5 + ax[1], sp["R"], hw - 0.14))
		var hl: Array = sp["hl"]
		m.set_shader_parameter("hl", Vector4(hl[0], hl[1], hl[2], hl[3]))
		var tl: Array = sp["tl"]
		m.set_shader_parameter("tl", Vector4(tl[0], tl[1], tl[2], tl[3]))
		var gr: Array = sp["gr"]
		m.set_shader_parameter("gr", Vector4(gr[0], gr[1], gr[2], 0.0))
		var d: Array = sp["doors"]
		m.set_shader_parameter("doors", Vector4(d[0] - L * 0.5, d[1] - L * 0.5, d[2] - L * 0.5, d[3] - L * 0.5 if d[3] > -50.0 else -99.0))
		var dd := Vector4(-99.0, -99.0, -99.0, -99.0)
		for i in range(4):
			if d[i] > -50.0:
				dd[i] = d[i] - L * 0.5
		m.set_shader_parameter("doors", dd)
		if "police" in sp["flags"]:
			m.set_shader_parameter("accent_col", Color(0.95, 0.95, 0.95, 1.0))
			m.set_shader_parameter("accent_box", Vector4(d[0] - L * 0.5 - 0.0, d[2] - L * 0.5 + 0.1, 0.30, sp["belt"] - 0.02))
		m.set_shader_parameter("use_instance", true)
		_mats[type] = m
	return _mats[type]


# Einzelnes Auto: eigenes Material mit fester Lackfarbe
static func single_material(type: String, paint: Color) -> ShaderMaterial:
	var m := material(type).duplicate() as ShaderMaterial
	m.set_shader_parameter("use_instance", false)
	m.set_shader_parameter("paint_col", paint)
	m.set_shader_parameter("brake", 0.0)
	return m


# ---------- Mesh ----------

# lod 0..2; merged = Raeder fest mit eingebaut (geparkte Autos)
static func mesh(type: String, lod: int, merged: bool) -> ArrayMesh:
	var key := "%s_%d_%d" % [type, lod, 1 if merged else 0]
	if _meshes.has(key):
		return _meshes[key]
	var m := _build(type, lod, merged)
	_meshes[key] = m
	return m


static func wheel_mesh(type: String, seg: int = 18) -> ArrayMesh:
	var key := "%s_%d" % [type, seg]
	if not _wheels.has(key):
		var sp := spec(type)
		var b := Buf.new()
		_wheel(b, Transform3D.IDENTITY, sp["R"], sp["ww"], seg, Color(0.72, 0.74, 0.78))
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, b.mesh_arrays())
		am.surface_set_material(0, material(type))
		_wheels[key] = am
	return _wheels[key]


static func _rnd(d: float, r: float) -> float:
	if d >= r or r <= 0.0:
		return 0.0
	return r - sqrt(maxf(r * r - (r - d) * (r - d), 0.0))


static func _curve(pts: Array, f: float) -> float:
	if f <= pts[0][0]:
		return pts[0][1]
	for i in range(1, pts.size()):
		if f <= pts[i][0]:
			var a: Array = pts[i - 1]
			var b: Array = pts[i]
			var t: float = (f - a[0]) / maxf(b[0] - a[0], 0.0001)
			return lerpf(a[1], b[1], t)
	return pts[pts.size() - 1][1]


static func _stations(sp: Dictionary, lod: int) -> PackedFloat32Array:
	var L: float = sp["L"]
	var K: int = [7, 4, 2][lod]
	var step: float = [0.16, 0.5, 1.2][lod]
	var rp: Array = sp["rp"]
	var list := []
	for k in range(K + 1):
		var a := float(k) / K * PI * 0.5
		list.append(rp[0] * (1.0 - cos(a)))
		list.append(L - rp[1] * (1.0 - cos(a)))
	var f: float = rp[0]
	while f < L - rp[1]:
		list.append(f)
		f += step
	for p in sp["roof"]:
		list.append(p[0])
	if sp["bed"].size() > 0:
		var b: Array = sp["bed"]
		list.append_array([b[0] - 0.02, b[0], b[0] + 0.03, b[0] + 0.07, b[1] - 0.1, b[1] - 0.05, b[1] - 0.015])
	list.sort()
	var out := PackedFloat32Array()
	var last := -1.0
	for x in list:
		if x < 0.0 or x > L:
			continue
		if x - last > 0.012 or last < 0.0:
			out.append(x)
			last = x
	if out[out.size() - 1] < L - 0.001:
		out.append(L)
	return out


static func _chaikin(pts: PackedVector2Array, us: PackedFloat32Array, iters: int) -> Array:
	var p := pts
	var u := us
	for it in range(iters):
		var np := PackedVector2Array()
		var nu := PackedFloat32Array()
		np.append(p[0])
		nu.append(u[0])
		for i in range(p.size() - 1):
			np.append(p[i] * 0.75 + p[i + 1] * 0.25)
			nu.append(u[i] * 0.75 + u[i + 1] * 0.25)
			np.append(p[i] * 0.25 + p[i + 1] * 0.75)
			nu.append(u[i] * 0.25 + u[i + 1] * 0.75)
		np.append(p[p.size() - 1])
		nu.append(u[u.size() - 1])
		p = np
		u = nu
	return [p, u]


# Glatte Normalen aus dem Gitter (Reihen = Stationen, Spalten = Ring)
static func _grid_normals(P: Array, closed: bool) -> Array:
	var rows := P.size()
	var cols: int = P[0].size()
	var N := []
	for i in range(rows):
		var nr := PackedVector3Array()
		nr.resize(cols)
		var i0 := maxi(i - 1, 0)
		var i1 := mini(i + 1, rows - 1)
		for j in range(cols):
			var j0 := j - 1
			var j1 := j + 1
			if closed:
				j0 = (j + cols - 1) % cols
				j1 = (j + 1) % cols
			else:
				j0 = maxi(j0, 0)
				j1 = mini(j1, cols - 1)
			var dz: Vector3 = P[i1][j] - P[i0][j]
			var dr: Vector3 = P[i][j1] - P[i][j0]
			var nn := dr.cross(dz)
			if nn.length_squared() < 1e-12:
				nn = Vector3(0, 1, 0)
			nr[j] = nn.normalized()
		N.append(nr)
	return N


static func _build(type: String, lod: int, merged: bool) -> ArrayMesh:
	var sp := spec(type)
	var L: float = sp["L"]
	var hw: float = sp["W"] * 0.5
	var fs := _stations(sp, lod)
	var ns := fs.size()
	var rp: Array = sp["rp"]
	var rv: Array = sp["rv"]
	var iters: int = [1, 0, 0][lod]
	var bed: Array = sp["bed"]
	var ob := Buf.new()
	var gb := Buf.new()
	var kpaint := kc(K_PAINT)
	var ktrim := kc(K_TRIM, Color(0.03, 0.03, 0.035))

	# Dachkurve: absolute Hoehe, Endpunkte liegen auf der Decklinie
	var roofp: Array = []
	for p in sp["roof"]:
		var h: float = p[1]
		if h <= 0.0:
			h = _curve(sp["deck"], p[0])
		roofp.append([p[0], h])
	var deck := PackedFloat32Array()
	var yb := PackedFloat32Array()
	var hh := PackedFloat32Array()
	for i in range(ns):
		var f := fs[i]
		var dk: float = _curve(sp["deck"], f)
		deck.append(dk)
		yb.append(_curve(sp["yb"], f))
		var h := 0.0
		if f > roofp[0][0] and f < roofp[roofp.size() - 1][0]:
			h = maxf(_curve(roofp, f) - dk, 0.0)
		hh.append(h)
	for pass_i in range(2):
		var sm := hh.duplicate()
		for i in range(1, ns - 1):
			sm[i] = (hh[i - 1] + 2.0 * hh[i] + hh[i + 1]) * 0.25
		hh = sm
	var hwi := PackedFloat32Array()
	for i in range(ns):
		var f := fs[i]
		var inset := _rnd(f, rp[0]) + _rnd(L - f, rp[1])
		hwi.append(hw - inset)
		var vr := _rnd(f, rv[0]) + _rnd(L - f, rv[1])
		deck[i] = deck[i] - vr
		yb[i] = minf(yb[i] + 0.7 * (_rnd(f, 0.08) + _rnd(L - f, 0.08)), deck[i] - 0.1)
		if hh[i] > 0.0:
			hh[i] = maxf(hh[i] - 0.0, 0.0)

	# --- Unterbau ---
	var P := []
	var kinds := []  # je Reihe/Spalte: Art
	var us: PackedFloat32Array
	var m_half := 0
	var bfac := PackedFloat32Array()
	for i in range(ns):
		var f := fs[i]
		var b := 0.0
		if bed.size() > 0:
			b = smoothstep(bed[0], bed[0] + 0.06, f) * (1.0 - smoothstep(bed[1] - 0.09, bed[1] - 0.02, f))
		bfac.append(b)
		var w := hwi[i]
		var y0 := yb[i]
		var dk := deck[i]
		var depth: float = bed[2] if bed.size() > 0 else 0.0
		var cp := PackedVector2Array([
			Vector2(0, y0), Vector2(w * 0.78, y0), Vector2(w * 0.96, y0 + 0.05), Vector2(w * 1.0, y0 + 0.16),
			Vector2(w * 1.008, (y0 + dk) * 0.5), Vector2(w * 0.995, dk - 0.17), Vector2(w * 0.955, dk - 0.05),
			Vector2(w * (0.80 + 0.14 * b), dk + 0.012 * (1.0 - b)),
			Vector2(w * (0.52 + 0.36 * b), dk + 0.018 * (1.0 - b)),
			Vector2(w * (0.30 + 0.58 * b), dk - depth * b + 0.02 * (1.0 - b)),
			Vector2(w * (0.15 + 0.30 * b), dk - depth * b + 0.021 * (1.0 - b)),
			Vector2(0, dk - depth * b + 0.022 * (1.0 - b)),
		])
		var cu := PackedFloat32Array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11])
		var r := _chaikin(cp, cu, iters)
		var hp: PackedVector2Array = r[0]
		us = r[1]
		m_half = hp.size()
		var ring := PackedVector3Array()
		var z := -L * 0.5 + f
		for j in range(m_half):
			ring.append(Vector3(hp[j].x, hp[j].y, z))
		for j in range(m_half - 2, 0, -1):
			ring.append(Vector3(-hp[j].x, hp[j].y, z))
		P.append(ring)
	var N := _grid_normals(P, true)
	var cols: int = P[0].size()
	for i in range(ns - 1):
		var bm := (bfac[i] + bfac[i + 1]) * 0.5
		for j in range(cols):
			var j1 := (j + 1) % cols
			# Kante der Halbringe: fuer die linke Seite spiegeln
			var jj := j if j < m_half - 1 else (cols - j - 1)
			var uu := (us[jj] + us[mini(jj + 1, m_half - 1)]) * 0.5
			var col := kpaint
			if bm > 0.5 and uu >= 8.0:
				col = ktrim
			var a := ob.vert(P[i][j], N[i][j], col)
			var b2 := ob.vert(P[i][j1], N[i][j1], col)
			var c2 := ob.vert(P[i + 1][j1], N[i + 1][j1], col)
			var d2 := ob.vert(P[i + 1][j], N[i + 1][j], col)
			ob.quad(a, b2, c2, d2)
	_cap(ob, P[0], Vector3(0, 0, -1), kpaint)
	_cap(ob, P[ns - 1], Vector3(0, 0, 1), kpaint)

	# --- Aufbau (Kabine) ---
	var first := -1
	var last := -1
	for i in range(ns):
		if hh[i] > 0.004:
			if first < 0:
				first = i
			last = i
	if first >= 0:
		first = maxi(first - 1, 0)
		last = mini(last + 1, ns - 1)
		var CP := []
		var cus: PackedFloat32Array
		var cm := 0
		for i in range(first, last + 1):
			var w := hwi[i]
			var hb: float = w * sp["tb"]
			var hr: float = w * sp["tr"]
			var y0 := deck[i] + 0.004
			var yr := deck[i] + hh[i]
			var gy := maxf(y0, yr - 0.12)
			var g := 0.0 if yr - y0 < 0.001 else (gy - y0) / (yr - y0)
			var gx := lerpf(hb, hr, g)
			var cp := PackedVector2Array([
				Vector2(hb, y0), Vector2(gx, gy), Vector2(hr + 0.012, maxf(yr - 0.03, y0)), Vector2(hr - 0.11, yr), Vector2(0, yr + 0.02 * minf(hh[i] * 4.0, 1.0)),
			])
			var cu := PackedFloat32Array([0, 1, 2, 3, 4])
			var r := _chaikin(cp, cu, iters)
			var hp: PackedVector2Array = r[0]
			cus = r[1]
			cm = hp.size()
			var ring := PackedVector3Array()
			var z := -L * 0.5 + fs[i]
			for j in range(cm):
				ring.append(Vector3(hp[j].x, hp[j].y, z))
			for j in range(cm - 2, -1, -1):
				ring.append(Vector3(-hp[j].x, hp[j].y, z))
			CP.append(ring)
		var CN := _grid_normals(CP, false)
		var ccols: int = CP[0].size()
		var ws: Array = sp["ws"]
		var rw: Array = sp["rw"]
		var glass: Array = sp["glass"]
		var g0: float = glass[0][0] - 0.22 if glass.size() > 0 else 0.0
		var g1: float = glass[glass.size() - 1][1] + 0.22 if glass.size() > 0 else 0.0
		var dark: float = sp["dark"]
		for i in range(first, last):
			var ri := i - first
			var fm := (fs[i] + fs[i + 1]) * 0.5
			var in_ws: bool = fm >= ws[0] and fm <= ws[1]
			var in_rw: bool = rw.size() > 0 and fm >= rw[0] and fm <= rw[1]
			var in_glass := false
			for gr in glass:
				if fm >= gr[0] and fm <= gr[1]:
					in_glass = true
			for j in range(ccols - 1):
				var jj := j if j < cm - 1 else (ccols - 2 - j)
				var e := int(floor((cus[jj] + cus[mini(jj + 1, cm - 1)]) * 0.5))
				var is_glass := false
				var col := kpaint
				if e == 0:
					if in_glass:
						is_glass = true
					elif fm >= g0 and fm <= g1:
						col = ktrim
				elif e == 1 or e == 2:
					if in_ws or in_rw:
						col = ktrim
				else:
					if in_ws or in_rw:
						is_glass = true
				var buf := gb if is_glass else ob
				var cc := Color(dark if (in_rw or e == 0) else 0.0, 0, 0, 1) if is_glass else col
				var a := buf.vert(CP[ri][j], CN[ri][j], cc)
				var b2 := buf.vert(CP[ri][j + 1], CN[ri][j + 1], cc)
				var c2 := buf.vert(CP[ri + 1][j + 1], CN[ri + 1][j + 1], cc)
				var d2 := buf.vert(CP[ri + 1][j], CN[ri + 1][j], cc)
				buf.quad(a, b2, c2, d2)
		if hh[first] > 0.05:
			_cap(ob, CP[0], Vector3(0, 0, -1), kpaint)
		if hh[last] > 0.05:
			_cap(ob, CP[CP.size() - 1], Vector3(0, 0, 1), kpaint)

	# --- Anbauten ---
	if lod <= 1:
		_addons(ob, sp, lod)
	if lod == 0:
		_interior(ob, sp)
	if merged:
		var segs: int = [14, 10, 8][lod]
		for wp in info(type)["wheels"]:
			var left: bool = wp.x < 0.0
			var xf := Transform3D(Basis(Vector3.UP, PI if left else 0.0), wp)
			_wheel(ob, xf, sp["R"], sp["ww"], segs, Color(0.72, 0.74, 0.78))
	else:
		pass
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ob.mesh_arrays())
	am.surface_set_material(0, material(type))
	if gb.idx.size() > 0:
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, gb.mesh_arrays())
		am.surface_set_material(1, glass_material())
	return am


# Endkappe: Faecher um den Schwerpunkt
static func _cap(b: Buf, ring: PackedVector3Array, n: Vector3, col: Color) -> void:
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


static func _box(b: Buf, c: Vector3, s: Vector3, col: Color, plate: bool = false) -> void:
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


static func _addons(b: Buf, sp: Dictionary, lod: int) -> void:
	var L: float = sp["L"]
	var hw: float = sp["W"] * 0.5
	var paint := kc(K_PAINT)
	var dark := kc(K_TRIM, Color(0.025, 0.025, 0.03))
	var plate := kc(K_PLATE)
	var flags: Array = sp["flags"]
	var py: Array = sp["plate_y"]
	# Kennzeichen vorn und hinten
	_box(b, Vector3(0, py[0], -L * 0.5 - 0.008), Vector3(0.52, 0.12, 0.02), plate)
	_box(b, Vector3(0, py[1], L * 0.5 + 0.008), Vector3(0.52, 0.12, 0.02), plate)
	if lod > 0:
		return
	# Spiegel
	var mz: float = -L * 0.5 + sp["mirror"]
	var roof_h := 0.0
	for p in sp["roof"]:
		roof_h = maxf(roof_h, p[1])
	var my: float = _curve(sp["deck"], sp["mirror"]) + 0.2
	var mx: float = hw * sp["tb"] + 0.09
	for s in [-1.0, 1.0]:
		_box(b, Vector3(s * mx, my, mz), Vector3(0.16, 0.11, 0.2), paint)
		_box(b, Vector3(s * (mx - 0.1), my - 0.07, mz + 0.03), Vector3(0.06, 0.05, 0.08), dark)
	# Auspuff
	var chrome := kc(K_CHROME)
	if "police" not in flags and sp["bed"].size() == 0:
		_box(b, Vector3(hw * 0.62, 0.26, L * 0.5 + 0.02), Vector3(0.1, 0.07, 0.07), chrome)
	# Taxi-Schild, Polizei-Lichtbalken
	if "taxi" in flags:
		_box(b, Vector3(0, roof_h + 0.09, -L * 0.5 + 2.85), Vector3(0.58, 0.16, 0.24), kc(K_EMIT, Color(1.0, 0.85, 0.5)))
		_box(b, Vector3(0, roof_h + 0.015, -L * 0.5 + 2.85), Vector3(0.5, 0.03, 0.2), dark)
	if "police" in flags:
		_box(b, Vector3(0, roof_h + 0.07, -L * 0.5 + 2.7), Vector3(1.15, 0.1, 0.3), kc(K_BAR))
		_box(b, Vector3(0, roof_h + 0.01, -L * 0.5 + 2.7), Vector3(1.0, 0.03, 0.26), dark)
	# Radhaus-Verkleidung (dunkle Halbschale hinter den Raedern)
	var R: float = sp["R"]
	var ax: Array = sp["axle"]
	var wx: float = hw - 0.14
	for fz in ax:
		for s in [-1.0, 1.0]:
			_liner(b, Vector3(s * wx, R, -L * 0.5 + fz), R + 0.075, 0.30, s)


static func _liner(b: Buf, c: Vector3, r: float, w: float, side: float) -> void:
	var col := kc(K_UNDER)
	var seg := 8
	var prev := []
	for k in range(seg + 1):
		var a := PI * 0.02 + (PI * 0.96) * float(k) / seg
		var dy := sin(a) * r
		var dz := cos(a) * r
		var nn := Vector3(0, -sin(a), -cos(a))
		var i0 := b.vert(c + Vector3(-side * w * 0.5 + side * 0.04, dy, dz), nn, col)
		var i1 := b.vert(c + Vector3(side * w * 0.5 + side * 0.04, dy, dz), nn, col)
		if k > 0:
			b.quad(prev[0], prev[1], i1, i0)
		prev = [i0, i1]


static func _interior(b: Buf, sp: Dictionary) -> void:
	var L: float = sp["L"]
	var hw: float = sp["W"] * 0.5
	var seat_col := kc(K_INT, Color(0.11, 0.105, 0.10))
	var dk := kc(K_INT, Color(0.05, 0.05, 0.055))
	var dk_y: float = _curve(sp["deck"], sp["dash"])
	var sw: float = hw * sp["tb"] - 0.12
	# Armaturenbrett, Lenkrad
	_box(b, Vector3(0, dk_y - 0.06, -L * 0.5 + sp["dash"]), Vector3(sw * 2.0, 0.22, 0.4), dk)
	_box(b, Vector3(-sw * 0.5, dk_y - 0.02, -L * 0.5 + sp["dash"] + 0.4), Vector3(0.36, 0.34, 0.04), dk)
	var sy: float = _curve(sp["deck"], 2.5) - 0.37
	for sf in sp["seats"]:
		for s in [-1.0, 1.0]:
			var sz: float = -L * 0.5 + sf
			var x: float = s * sw * 0.5
			_box(b, Vector3(x, sy, sz), Vector3(sw * 0.8, 0.14, 0.5), seat_col)
			_box(b, Vector3(x, sy + 0.32, sz + 0.26), Vector3(sw * 0.8, 0.55, 0.1), seat_col)


# Rad: Reifen (Art 4) und Felge (Art 5), Achse = X, aussen +X
static func _wheel(b: Buf, xf: Transform3D, R: float, ww: float, seg: int, rim: Color) -> void:
	var h := ww * 0.5
	var Rr := R * 0.64
	var prof := [
		Vector2(-h * 0.88, Rr + 0.012), Vector2(-h * 1.0, Rr + (R - Rr) * 0.3), Vector2(-h * 0.99, Rr + (R - Rr) * 0.7),
		Vector2(-h * 0.84, R * 0.985), Vector2(-h * 0.55, R), Vector2(h * 0.55, R), Vector2(h * 0.84, R * 0.985),
		Vector2(h * 0.99, Rr + (R - Rr) * 0.7), Vector2(h * 1.0, Rr + (R - Rr) * 0.3), Vector2(h * 0.88, Rr + 0.012),
	]
	var np := prof.size()
	var nrm2 := []
	for p in range(np):
		var p0: Vector2 = prof[maxi(p - 1, 0)]
		var p1: Vector2 = prof[mini(p + 1, np - 1)]
		var t := (p1 - p0).normalized()
		nrm2.append(Vector2(-t.y, t.x))
	var tire := kc(K_TIRE, Color(0.05, 0.05, 0.05))
	var base := b.v.size()
	for k in range(seg + 1):
		var a := TAU * float(k) / seg
		var ca := cos(a)
		var sa := sin(a)
		for p in range(np):
			var pr: Vector2 = prof[p]
			var nn: Vector2 = nrm2[p]
			var pos := xf * Vector3(pr.x, pr.y * ca, pr.y * sa)
			var nv := (xf.basis * Vector3(nn.x, nn.y * ca, nn.y * sa)).normalized()
			b.vert(pos, nv, tire, Vector2(float(k) / seg, float(p) / (np - 1)))
	for k in range(seg):
		for p in range(np - 1):
			var a0 := base + k * np + p
			var a1 := base + (k + 1) * np + p
			b.quad(a0, a1, a1 + 1, a0 + 1)
	# Felgenflaeche (Scheibe, aussen) und dunkle Innenseite
	var rc := kc(K_RIM, rim)
	var cn := (xf.basis * Vector3.RIGHT).normalized()
	var ci := b.vert(xf * Vector3(h * 0.7, 0, 0), cn, rc, Vector2(0.5, 0.5))
	var rb := b.v.size()
	for k in range(seg):
		var a := TAU * float(k) / seg
		b.vert(xf * Vector3(h * 0.9, Rr * cos(a), Rr * sin(a)), cn, rc, Vector2(0.5 + 0.5 * cos(a), 0.5 + 0.5 * sin(a)))
	for k in range(seg):
		b.tri(ci, rb + k, rb + (k + 1) % seg)
	var ui := b.vert(xf * Vector3(-h * 0.9, 0, 0), -cn, kc(K_UNDER))
	var ub := b.v.size()
	for k in range(seg):
		var a := TAU * float(k) / seg
		b.vert(xf * Vector3(-h * 0.88, (Rr + 0.012) * cos(a), (Rr + 0.012) * sin(a)), -cn, kc(K_UNDER))
	for k in range(seg):
		b.tri(ui, ub + k, ub + (k + 1) % seg)
