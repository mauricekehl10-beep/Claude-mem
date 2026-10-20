extends RefCounted
# Auto-Modelle (prozedural): Karosserie als Querschnitts-Loft (Unterbau mit Radhaeusern, Kabine mit Scheiben), Raeder getrennt.
# Front zeigt nach -Z, Ursprung = Mitte der Bodenflaeche. Art des Teils steckt in COLOR.a (Art / 15), siehe city_car.gdshader.
# Mesh-Werkzeuge in car_loft.gd, Raeder in car_wheel.gd, Anbauten (Spiegel, Innenraum ...) in car_parts.gd.

const LF = preload("res://scripts/car_loft.gd")
const CW = preload("res://scripts/car_wheel.gd")
const CP = preload("res://scripts/car_parts.gd")

const K_PAINT := 0
const K_FIXED := 1
const K_TRIM := 2
const K_CHROME := 3
const K_TIRE := 4
const K_RIM := 5
const K_INT := 6
const K_EMIT2 := 7
const K_EMIT := 8
const K_BAR := 9
const K_UNDER := 10
const K_PLATE := 11
const K_DISC := 12
const K_GLOSS := 13

# Typ, Gewicht (parken), Gewicht (Verkehr)
const LIST := [
	["sedan", 5.0, 5.0], ["hatch", 2.5, 2.5], ["suv", 4.0, 4.0], ["pickup", 1.3, 1.0],
	["van", 1.2, 1.3], ["taxi", 1.6, 3.0], ["police", 0.35, 0.8], ["bus", 0.0, 0.9],
]

static var _spec := {}
static var _bodies := {}
static var _meshes := {}
static var _mats := {}
static var _glass: ShaderMaterial
static var _wheels := {}


static func kc(kind: int, col: Color = Color.WHITE) -> Color:
	return Color(col.r, col.g, col.b, kind / 15.0)


# ---------- Typen ----------
# Laengen u laufen von der Front (0) nach hinten (L). top = Dachlinie in der Mitte (Haube, Scheibe, Dach, Heckscheibe, Kofferraum),
# belt = Guertellinie (Oberkante der Tueren), yb = Unterseite, ws/rw = Frontscheibe/Heckscheibe von-bis, glass = Seitenfenster.

static func spec(type: String) -> Dictionary:
	if _spec.is_empty():
		var s := {
			"L": 4.86, "W": 1.84, "R": 0.335, "ww": 0.225, "axle": [0.97, 3.80],
			"top": [[0.0, 0.50], [0.035, 0.665, 0.04], [0.16, 0.775, 0.12], [0.80, 0.855], [1.78, 0.985, 0.5], [2.66, 1.425, 0.35],
				[3.10, 1.46, 0.9], [3.72, 1.40, 0.5], [4.36, 1.00, 0.35], [4.62, 0.985], [4.80, 0.975, 0.12], [4.86, 0.90]],
			"belt": [[0.0, 0.80], [1.78, 0.935], [2.6, 0.945], [3.4, 0.975], [4.36, 0.985], [4.86, 0.97]],
			"yb": [[0.0, 0.36], [0.06, 0.30, 0.05], [0.25, 0.22], [0.7, 0.17], [1.2, 0.155], [3.6, 0.155], [4.2, 0.19], [4.6, 0.24], [4.78, 0.30], [4.86, 0.38]],
			"ws": [1.78, 2.66], "rw": [3.72, 4.36],
			"glass": [[1.92, 3.04], [3.16, 3.95]],
			"rp": [0.58, 0.50], "rn": 2.4, "crown": [0.045, 0.03],
			"roof_w": 0.76, "doors": [1.72, 3.10, 4.28], "flags": [], "clad": 0, "bed": [],
			"cfr": [0.0, 0.025, 0.07, 0.5, 0.84, 0.93, 0.975, 0.99, 0.998, 1.0],
			"hl": [0.52, 1.2, 0.60, 0.74], "tl": [0.50, 1.2, 0.70, 0.86], "gr": [0.44, 0.44, 0.64],
			"seats": [2.3, 3.3], "rim": "alloy", "spokes": 5, "mirror_dz": 0.22,
		}
		_spec["sedan"] = _prep(s)
		_spec["taxi"] = _prep(_derive(s, {"flags": ["taxi"], "rim": "steel"}))
		_spec["police"] = _prep(_derive(s, {"flags": ["police"], "rim": "steel"}))
		_spec["hatch"] = _prep(_derive(s, {
			"L": 4.26, "W": 1.79, "R": 0.315, "ww": 0.205, "axle": [0.84, 3.40],
			"top": [[0.0, 0.48], [0.035, 0.64, 0.04], [0.14, 0.75, 0.1], [0.7, 0.83], [1.52, 0.955, 0.5], [2.3, 1.43, 0.4], [2.8, 1.47, 0.9], [3.7, 1.43, 0.5], [4.20, 0.98, 0.25], [4.26, 0.90]],
			"belt": [[0.0, 0.78], [1.52, 0.91], [2.4, 0.93], [3.3, 0.96], [4.2, 0.97], [4.26, 0.96]],
			"yb": [[0.0, 0.34], [0.06, 0.28, 0.05], [0.25, 0.20], [0.6, 0.16], [1.0, 0.15], [3.3, 0.15], [3.9, 0.20], [4.2, 0.30], [4.26, 0.36]],
			"ws": [1.52, 2.3], "rw": [3.7, 4.2], "glass": [[1.66, 2.68], [2.78, 3.62]], "rp": [0.52, 0.40], "crown": [0.04, 0.0],
			"doors": [1.48, 2.72, 3.9], "roof_w": 0.78, "seats": [2.1, 2.95], "spokes": 5,
		}))
		_spec["suv"] = _prep(_derive(s, {
			"L": 4.80, "W": 1.92, "R": 0.375, "ww": 0.235, "axle": [0.98, 3.82],
			"top": [[0.0, 0.58], [0.04, 0.78, 0.05], [0.2, 0.93, 0.12], [0.9, 1.03], [1.72, 1.12, 0.5], [2.5, 1.62, 0.4], [2.9, 1.745, 0.9], [4.25, 1.74, 0.5], [4.76, 1.30, 0.3], [4.80, 1.20]],
			"belt": [[0.0, 0.95], [1.72, 1.07], [2.6, 1.10], [4.76, 1.15], [4.80, 1.14]],
			"yb": [[0.0, 0.46], [0.06, 0.37, 0.05], [0.3, 0.27], [0.9, 0.22], [3.9, 0.22], [4.5, 0.27], [4.8, 0.38]],
			"ws": [1.72, 2.5], "rw": [4.25, 4.76], "glass": [[1.86, 3.04], [3.14, 4.0], [4.06, 4.40]], "rp": [0.56, 0.36], "crown": [0.045, 0.02],
			"doors": [1.7, 3.08, 4.18], "roof_w": 0.80, "clad": 1, "flags": ["rails"], "seats": [2.55, 3.45], "spokes": 5,
			"hl": [0.56, 1.3, 0.76, 0.90], "tl": [0.56, 1.3, 0.92, 1.08], "gr": [0.50, 0.58, 0.82],
		}))
		_spec["pickup"] = _prep(_derive(s, {
			"L": 5.6, "W": 2.0, "R": 0.385, "ww": 0.25, "axle": [1.0, 4.25],
			"top": [[0.0, 0.64], [0.04, 0.84, 0.05], [0.2, 1.02, 0.12], [0.9, 1.11], [1.75, 1.17, 0.5], [2.5, 1.78, 0.35], [2.9, 1.86, 0.9], [3.3, 1.84, 0.4], [3.62, 1.40, 0.2], [3.70, 1.17], [5.6, 1.17]],
			"belt": [[0.0, 1.0], [1.75, 1.12], [2.6, 1.16], [3.70, 1.17], [5.6, 1.17]],
			"yb": [[0.0, 0.47], [0.06, 0.39, 0.05], [0.3, 0.28], [0.9, 0.24], [4.9, 0.24], [5.35, 0.30], [5.6, 0.40]],
			"ws": [1.75, 2.5], "rw": [3.3, 3.7], "glass": [[1.9, 3.0], [3.1, 3.5]], "rp": [0.55, 0.30], "crown": [0.045, 0.0],
			"doors": [1.72, 3.08, 3.68], "roof_w": 0.82, "clad": 1, "bed": [3.76, 5.6, 0.46], "seats": [2.55, 3.25], "spokes": 6,
			"hl": [0.58, 1.3, 0.80, 0.94], "tl": [0.76, 1.3, 0.92, 1.08], "gr": [0.50, 0.62, 0.86],
		}))
		_spec["van"] = _prep(_derive(s, {
			"L": 5.9, "W": 2.0, "R": 0.355, "ww": 0.225, "axle": [1.2, 4.55],
			"top": [[0.0, 0.70], [0.04, 0.92, 0.05], [0.2, 1.08, 0.15], [0.7, 1.18], [1.45, 1.30, 0.35], [2.1, 2.25, 0.5], [2.5, 2.42, 1.0], [5.7, 2.50, 0.3], [5.9, 2.28]],
			"belt": [[0.0, 1.0], [1.45, 1.2], [2.1, 1.22], [5.9, 1.2]],
			"yb": [[0.0, 0.42], [0.06, 0.34, 0.05], [0.3, 0.25], [0.9, 0.22], [5.2, 0.22], [5.9, 0.34]],
			"ws": [1.45, 2.1], "rw": [], "glass": [[1.62, 2.45]], "rp": [0.50, 0.14], "crown": [0.04, 0.0],
			"doors": [1.5, 2.9, -99.0], "roof_w": 0.92, "clad": 1, "seats": [2.05], "spokes": 5, "rim": "steel",
			"cfr": [0.0, 0.012, 0.03, 0.2, 0.40, 0.95, 0.985, 0.99, 0.998, 1.0],
			"hl": [0.55, 1.3, 0.66, 0.82], "tl": [0.82, 1.3, 0.80, 1.22], "gr": [0.50, 0.58, 0.78],
		}))
		_spec["bus"] = _prep(_derive(s, {
			"L": 11.6, "W": 2.55, "R": 0.50, "ww": 0.30, "axle": [2.5, 8.5],
			"top": [[0.0, 1.30], [0.03, 1.7, 0.05], [0.14, 2.9, 0.2], [0.5, 3.12, 0.3], [1.2, 3.2], [11.4, 3.2, 0.3], [11.6, 3.0]],
			"belt": [[0.0, 1.1], [11.6, 1.15]],
			"yb": [[0.0, 0.45], [0.08, 0.35, 0.05], [0.4, 0.30], [1.0, 0.28], [11.0, 0.28], [11.6, 0.45]],
			"ws": [0.0, 0.5], "rw": [], "glass": [[0.8, 2.5], [2.7, 4.35], [4.55, 6.2], [6.4, 8.0], [8.2, 9.7], [9.9, 11.3]],
			"rp": [0.40, 0.30], "crown": [0.0, 0.0], "doors": [-99.0, -99.0, -99.0], "roof_w": 0.96, "clad": 1,
			"cfr": [0.0, 0.01, 0.04, 0.32, 0.62, 0.9, 0.97, 0.99, 0.998, 1.0], "seats": [], "spokes": 5, "rim": "steel", "mirror_dz": 0.1,
			"hl": [0.70, 1.4, 0.62, 0.80], "tl": [0.80, 1.4, 0.80, 1.10], "gr": [0.50, 0.6, 0.9],
		}))
	return _spec[type]


static func _derive(base: Dictionary, over: Dictionary) -> Dictionary:
	var d: Dictionary = base.duplicate(true)
	for k in over:
		d[k] = over[k]
	return d


static func _prep(s: Dictionary) -> Dictionary:
	s["c_top"] = LF.Crv.new(s["top"])
	s["c_belt"] = LF.Crv.new(s["belt"])
	s["c_yb"] = LF.Crv.new(s["yb"])
	return s


static func info(type: String) -> Dictionary:
	var sp := spec(type)
	var L: float = sp["L"]
	var W: float = sp["W"]
	var R: float = sp["R"]
	var roof_h := 0.0
	for p in sp["top"]:
		roof_h = maxf(roof_h, p[1])
	var wx: float = _wheel_x(sp)
	var ax: Array = sp["axle"]
	var wheels := [
		Vector3(wx, R, -L * 0.5 + ax[0]), Vector3(-wx, R, -L * 0.5 + ax[0]),
		Vector3(wx, R, -L * 0.5 + ax[1]), Vector3(-wx, R, -L * 0.5 + ax[1]),
	]
	return {"size": Vector3(W, roof_h, L), "R": R, "wheels": wheels, "wheelbase": ax[1] - ax[0]}


static func _wheel_x(sp: Dictionary) -> float:
	return sp["W"] * 0.5 - sp["ww"] * 0.5 - 0.028


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
		var belt: LF.Crv = sp["c_belt"]
		var ax: Array = sp["axle"]
		m.set_shader_parameter("body", Vector4(sp["W"] * 0.5, L, belt.at(2.4), 0.30))
		m.set_shader_parameter("wheelp", Vector4(-L * 0.5 + ax[0], -L * 0.5 + ax[1], sp["R"], _wheel_x(sp)))
		var hl: Array = sp["hl"]
		m.set_shader_parameter("hl", Vector4(hl[0], hl[1], hl[2], hl[3]))
		var tl: Array = sp["tl"]
		m.set_shader_parameter("tl", Vector4(tl[0], tl[1], tl[2], tl[3]))
		var gr: Array = sp["gr"]
		var rh := 0.0
		for p in sp["top"]:
			rh = maxf(rh, p[1])
		m.set_shader_parameter("gr", Vector4(gr[0], gr[1], gr[2], rh + 0.095))
		var d: Array = sp["doors"]
		var dd := Vector4(-99.0, -99.0, -99.0, -99.0)
		for i in range(mini(d.size(), 4)):
			if d[i] > -50.0:
				dd[i] = d[i] - L * 0.5
		m.set_shader_parameter("doors", dd)
		var fl: Array = sp["flags"]
		m.set_shader_parameter("flags", Vector4(1.0 if "taxi" in fl else 0.0, 1.0 if "police" in fl else 0.0, 1.0 if type == "bus" else 0.0, 1.0 if type == "van" else 0.0))
		m.set_shader_parameter("clad", float(sp["clad"]))
		m.set_shader_parameter("use_instance", true)
		_mats[type] = m
	return _mats[type]


# Einzelnes Auto: eigenes Material mit fester Lackfarbe
static func single_material(type: String, paint: Color) -> ShaderMaterial:
	var m := material(type).duplicate() as ShaderMaterial
	m.set_shader_parameter("use_instance", false)
	m.set_shader_parameter("paint_col", Vector4(paint.r, paint.g, paint.b, 1.0))
	m.set_shader_parameter("brake", 0.0)
	return m


# ---------- Mesh ----------

# lod 0..2; merged = Raeder fest mit eingebaut (geparkte Autos)
static func mesh(type: String, lod: int, merged: bool) -> ArrayMesh:
	var key := "%s_%d_%d" % [type, lod, 1 if merged else 0]
	if _meshes.has(key):
		return _meshes[key]
	var m := _assemble(type, lod, merged)
	_meshes[key] = m
	return m


static func wheel_mesh(type: String, seg: int = 18) -> ArrayMesh:
	var key := "%s_%d" % [type, seg]
	if not _wheels.has(key):
		var sp := spec(type)
		var b := LF.Buf.new()
		CW.wheel(b, Transform3D.IDENTITY, sp, seg)
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, b.arrays())
		am.surface_set_material(0, material(type))
		_wheels[key] = am
	return _wheels[key]


static func _assemble(type: String, lod: int, merged: bool) -> ArrayMesh:
	var sp := spec(type)
	var bk := "%s_%d" % [type, lod]
	if not _bodies.has(bk):
		_bodies[bk] = _build_body(sp, lod)
	var body: Array = _bodies[bk]
	var ob: LF.Buf = body[0]
	var gb: LF.Buf = body[1]
	var o2 := LF.Buf.new()
	o2.append_buf(ob)
	if merged:
		var segs: int = [28, 16, 10][lod]
		for wp in info(type)["wheels"]:
			var left: bool = wp.x < 0.0
			var xf := Transform3D(Basis(Vector3.UP, PI if left else 0.0), wp)
			CW.wheel(o2, xf, sp, segs)
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, o2.arrays())
	am.surface_set_material(0, material(type))
	if gb.idx.size() > 0:
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, gb.arrays())
		am.surface_set_material(1, glass_material())
	return am


# Plan-Ausrundung am Ende: Viertel-Superellipse, Radius r, Exponent n
static func _inset(d: float, r: float, n: float) -> float:
	if d >= r or r <= 0.0:
		return 0.0
	var t := (r - d) / r
	return r * (1.0 - pow(maxf(1.0 - pow(t, n), 0.0), 1.0 / n))


static func _stations(sp: Dictionary, lod: int) -> PackedFloat32Array:
	var L: float = sp["L"]
	var rp: Array = sp["rp"]
	var K: int = [9, 5, 3][lod]
	var step: float = [0.11, 0.34, 0.9][lod]
	var list := []
	for k in range(K + 1):
		var a := float(k) / K * PI * 0.5
		list.append(rp[0] * (1.0 - cos(a)))
		list.append(L - rp[1] * (1.0 - cos(a)))
	var f: float = rp[0]
	while f < L - rp[1]:
		list.append(f)
		f += step
	for p in sp["top"]:
		list.append(p[0])
	list.append(sp["ws"][0])
	list.append(sp["ws"][1])
	if sp["rw"].size() > 0:
		list.append(sp["rw"][0])
		list.append(sp["rw"][1])
	for g in sp["glass"]:
		list.append(g[0])
		list.append(g[1])
	if lod <= 1:
		var R: float = sp["R"]
		var ra := R + 0.055
		var dmax := sqrt(maxf(ra * ra - pow(0.20 - R, 2.0), 0.0))
		var Ka: int = [13, 6][lod]
		for ua in sp["axle"]:
			for k in range(Ka + 1):
				var th := acos(dmax / ra) + float(k) / Ka * (PI - 2.0 * acos(dmax / ra))
				list.append(ua + ra * cos(th))
			list.append(ua - dmax - 0.004)
			list.append(ua + dmax + 0.004)
	if sp["bed"].size() > 0:
		var b: Array = sp["bed"]
		list.append_array([b[0] - 0.02, b[0], b[0] + 0.03, b[0] + 0.07, b[1] - 0.1, b[1] - 0.05, b[1] - 0.015])
	list.sort()
	var out := PackedFloat32Array()
	var last := -1.0
	for x in list:
		if x < 0.0 or x > L:
			continue
		if x - last > 0.006 or last < 0.0:
			out.append(x)
			last = x
	if out[out.size() - 1] < L - 0.001:
		out.append(L)
	return out


# Halbprofil (rechte Seite) des Unterbaus: Index -> Punkt. Punkte: 0 Mitte unten, 1-2 Radhaus innen, 3 Decke/Boden aussen,
# 4 Schwellerkante, 5 unten, 6 breiteste Stelle, 7 obere Tuer, 8 Schulter, 9 Guertel aussen, 10-13 Deck (Haube/Kofferraum) nach innen.
static func _lower_half(sp: Dictionary, hwu: float, yb: float, ya: float, de: float, dc: float, xi: float, bf: float, bed_depth: float, lod: int) -> PackedVector2Array:
	var tl := hwu - 0.04
	var ysn := yb + 0.045
	var h := maxf(de - ysn, 0.05)
	var ts := [0.10, 0.30, 0.70, 0.93, 1.0]
	var offs := [0.075, 0.115, 0.16, 0.19, 0.20]
	var xs := [hwu - 0.012, hwu, hwu - 0.004, hwu - 0.03, hwu - 0.055]
	var pts := PackedVector2Array()
	pts.append(Vector2(0.0, yb))
	pts.append(Vector2(minf(xi, tl - 0.06), yb))
	pts.append(Vector2(minf(xi, tl - 0.06), ya))
	pts.append(Vector2(tl - 0.02, ya))
	pts.append(Vector2(tl, ya + 0.03))
	var prev := ya + 0.03
	for k in range(5):
		var y: float = maxf(ysn + ts[k] * h, ya + offs[k])
		y = clampf(y, prev + 0.0005, maxf(de, prev + 0.0005))
		prev = y
		pts.append(Vector2(xs[k], y))
	var hx: float = xs[4]
	var cr := dc - de
	var fr := [0.86, 0.62, 0.34, 0.0]
	var bx := [hx - 0.03, hx - 0.075, hx * 0.55, 0.0]
	var by := [-0.01, -bed_depth + 0.03, -bed_depth, -bed_depth]
	for k in range(4):
		var x: float = hx * fr[k]
		var y: float = de + cr * (1.0 - fr[k] * fr[k])
		if bf > 0.0:
			# Ladeflaeche (Pritsche): nach innen und unten
			x = lerpf(x, bx[k], bf)
			y = lerpf(y, de + by[k], bf)
		pts.append(Vector2(x, y))
	return pts


static func _build_body(sp: Dictionary, lod: int) -> Array:
	var L: float = sp["L"]
	var hw0: float = sp["W"] * 0.5
	var R: float = sp["R"]
	var top: LF.Crv = sp["c_top"]
	var belt: LF.Crv = sp["c_belt"]
	var ybc: LF.Crv = sp["c_yb"]
	var rp: Array = sp["rp"]
	var rn: float = sp["rn"]
	var crown: Array = sp["crown"]
	var ws: Array = sp["ws"]
	var rw: Array = sp["rw"]
	var cz0: float = ws[0]
	var cz1: float = rw[1] if rw.size() > 0 else L
	var fs := _stations(sp, lod)
	var ns := fs.size()
	var ax: Array = sp["axle"]
	var wx := _wheel_x(sp)
	var xi: float = wx - sp["ww"] * 0.5 - 0.075
	var ra := R + 0.055
	var ob := LF.Buf.new()
	var gb := LF.Buf.new()
	var kpaint := kc(K_PAINT)
	var ktrim := kc(K_TRIM, Color(0.03, 0.03, 0.035))
	var kunder := kc(K_UNDER)
	var arch_on: bool = lod <= 1
	# ---------- Unterbau ----------
	var ids: Array = [[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13], [0, 3, 4, 6, 8, 9, 11, 13], [0, 4, 6, 9, 13]][lod]
	var P := []
	var bed: Array = sp["bed"]
	var bfs := PackedFloat32Array()
	for i in range(ns):
		var u := fs[i]
		var inset := _inset(u, rp[0], rn) + _inset(L - u, rp[1], rn)
		var hwu: float = hw0 - inset
		var in_cab := u >= cz0 and u <= cz1
		var cr_h: float = crown[0] if u < cz1 - 0.01 or rw.size() == 0 else crown[1]
		if rw.size() > 0 and u > rw[0]:
			cr_h = crown[1]
		var tp := top.at(u)
		var de := tp - cr_h
		var dc := tp
		if in_cab:
			de = belt.at(u)
			dc = de + crown[0] * 0.5
		var yb := ybc.at(u)
		var ya := yb
		if arch_on:
			for ua in ax:
				var du: float = u - ua
				if absf(du) < ra:
					var cy: float = R + sqrt(maxf(ra * ra - du * du, 0.0))
					if cy >= yb + 0.045 and absf(du) <= sqrt(ra * ra - pow(0.20 - R, 2.0)) + 0.0001:
						ya = maxf(ya, cy)
		var bf := 0.0
		var bdepth := 0.0
		if bed.size() > 0:
			bf = smoothstep(bed[0], bed[0] + 0.06, u) * (1.0 - smoothstep(bed[1] - 0.09, bed[1] - 0.02, u))
			bdepth = bed[2]
		bfs.append(bf)
		var hp := _lower_half(sp, hwu, yb, ya, de, dc, xi, bf, bdepth, lod)
		var ring := PackedVector3Array()
		var z := -L * 0.5 + u
		var sel := PackedVector2Array()
		for id in ids:
			sel.append(hp[id])
		for j in range(sel.size()):
			ring.append(Vector3(sel[j].x, sel[j].y, z))
		for j in range(sel.size() - 2, 0, -1):
			ring.append(Vector3(-sel[j].x, sel[j].y, z))
		P.append(ring)
	var cols: int = P[0].size()
	var mh := ids.size()
	var fc := PackedColorArray()
	for i in range(ns - 1):
		for j in range(cols):
			var jj := j if j < mh - 1 else (cols - j - 1)
			var sid: int = ids[jj]
			var col := kpaint
			if sid <= 3:
				col = kunder
			elif sid == 4 or (sid == 5 and sp["clad"] > 0):
				col = ktrim
			elif sid >= 9 and (bfs[i] + bfs[i + 1]) > 1.0:
				col = ktrim
			fc.append(col)
	LF.grid(ob, P, true, fc, [48.0, 55.0, 70.0][lod])
	LF.cap(ob, P[0], Vector3(0, 0, -1), kpaint)
	LF.cap(ob, P[ns - 1], Vector3(0, 0, 1), kpaint)
	# ---------- Kabine ----------
	var CPR := []
	var cstart := -1
	var cend := -1
	for i in range(ns):
		if fs[i] >= cz0 - 0.0001 and fs[i] <= cz1 + 0.0001:
			if cstart < 0:
				cstart = i
			cend = i
	var cids: Array = [[0, 1, 2, 3, 4, 5, 6, 7, 8, 9], [0, 2, 4, 5, 7, 9], [0, 4, 6, 9]][lod]
	var rwf: float = sp["roof_w"]
	if cstart >= 0:
		for i in range(cstart, cend + 1):
			var u := fs[i]
			var inset := _inset(u, rp[0], rn) + _inset(L - u, rp[1], rn)
			var hwu: float = hw0 - inset
			var bl := belt.at(u)
			var hc: float = maxf(top.at(u) - bl, 0.0)
			var xb := hwu - 0.055
			var f := minf(hc / 0.45, 1.0)
			var xr: float = xb - (xb - hwu * rwf) * pow(f, 0.6)
			var xg0: float = xb - 0.04 - 0.03 * f
			var xg2: float = xr + 0.02 * f
			var fr: Array = sp["cfr"]
			var xx := [xb, xb - 0.022, xg0, lerpf(xg0, xg2, 0.5) + 0.012 * f, xg2, xr + 0.004, xr - 0.014, xr - 0.085, (xr - 0.085) * 0.5, 0.0]
			var hp2 := PackedVector2Array()
			for id in cids:
				hp2.append(Vector2(maxf(xx[id], 0.0), bl + hc * fr[id]))
			var ring := PackedVector3Array()
			var z := -L * 0.5 + u
			for j in range(hp2.size()):
				ring.append(Vector3(hp2[j].x, hp2[j].y + 0.003, z))
			for j in range(hp2.size() - 2, -1, -1):
				ring.append(Vector3(-hp2[j].x, hp2[j].y + 0.003, z))
			CPR.append(ring)
		var ccols: int = CPR[0].size()
		var cm := cids.size()
		var glass: Array = sp["glass"]
		var dark_default := 0.0
		var fco := PackedColorArray()
		var fcg := PackedColorArray()
		var none := Color(0, 0, 0, -1)
		for i in range(cstart, cend):
			var fm := (fs[i] + fs[i + 1]) * 0.5
			var in_ws: bool = fm >= ws[0] and fm <= ws[1]
			var in_rw: bool = rw.size() > 0 and fm >= rw[0] and fm <= rw[1]
			var in_win := false
			for g in glass:
				if fm >= g[0] and fm <= g[1]:
					in_win = true
			for j in range(ccols - 1):
				var jj := j if j < cm - 1 else (ccols - 2 - j)
				var sid: int = cids[jj]
				var col := kpaint
				var is_glass := false
				if sid == 0:
					col = kpaint
				elif sid == 1:
					col = ktrim
				elif sid <= 3:
					if in_win:
						is_glass = true
					else:
						col = ktrim if fm < sp["doors"][1] + 0.2 else kpaint
				elif sid == 4:
					col = ktrim if in_win else kpaint
				elif sid <= 6:
					col = kpaint
				else:
					if in_ws or in_rw:
						is_glass = true
				if is_glass:
					fco.append(none)
					var dk := 0.0
					if sid >= 7 and not in_ws:
						dk = 1.0
					fcg.append(Color(dk, 0, 0, 1))
				else:
					fco.append(col)
					fcg.append(none)
		LF.grid(ob, CPR, false, fco, [48.0, 55.0, 70.0][lod])
		LF.grid(gb, CPR, false, fcg, 80.0)
		if top.at(fs[cstart]) - belt.at(fs[cstart]) > 0.06:
			LF.cap(ob, CPR[0], Vector3(0, 0, -1), kpaint)
		if top.at(fs[cend]) - belt.at(fs[cend]) > 0.06:
			LF.cap(ob, CPR[CPR.size() - 1], Vector3(0, 0, 1), kpaint)
	if lod <= 1:
		CP.addons(ob, sp, lod)
	return [ob, gb]
