extends RefCounted
# Rumpf der Rüstung: Brust (Joch, Brustplatten, Rippen, Arc-Reaktor), Kragen, Rücken (Wabenfeld, Flügel), Bauch, Hüfte.
# Alle Teile sind Platten mit Fase auf einer gemeinsamen Hülle (Loft). Winkel: 0 = vorn, 90 = links, 180 = hinten.

const K = preload("res://scripts/ironman_kit.gd")

const CY0 := 1.18
const CY1 := 1.52
# Brust: [y, rx, rz, oz, n]
const CHEST := [
	[1.180, 0.156, 0.148, 0.004, 2.7], [1.230, 0.172, 0.156, 0.006, 2.7], [1.280, 0.198, 0.170, 0.008, 2.6],
	[1.330, 0.216, 0.182, 0.010, 2.6], [1.390, 0.226, 0.182, 0.008, 2.6], [1.440, 0.214, 0.162, 0.002, 2.5],
	[1.480, 0.174, 0.130, -0.004, 2.4], [1.505, 0.114, 0.100, -0.014, 2.3], [1.520, 0.078, 0.082, -0.020, 2.2],
]
const AY0 := 1.03
const AY1 := 1.20
# Bauch: [y, rx, rz, oz, n]
const ABS := [
	[1.030, 0.166, 0.158, -0.002, 2.6], [1.080, 0.158, 0.154, 0.000, 2.6], [1.130, 0.152, 0.152, 0.002, 2.6], [1.200, 0.158, 0.150, 0.004, 2.7],
]


static func _loft(keys: Array, y0: float, y1: float) -> K.Loft:
	var kk := []
	for k in keys:
		kk.append([(float(k[0]) - y0) / (y1 - y0), k[1], k[2], k[4], 0.0, k[3]])
	return K.Loft.new(Vector3(0, y0, 0), Vector3(0, y1, 0), K.X, K.Z, kk)


static func chest_loft() -> K.Loft:
	return _loft(CHEST, CY0, CY1)


static func ct(y: float) -> float:
	return (y - CY0) / (CY1 - CY0)


static func at(y: float) -> float:
	return (y - AY0) / (AY1 - AY0)


# ---------------------------------------------------------------- Brust

static func chest(b) -> void:
	var L := chest_loft()
	var f := L.f()
	var ref := Vector3(0, 1.34, 0.0)
	# Kern: ganze Hülle (dunkelrot), darauf die Platten
	b.shell(L.grid(0.0, 1.0, -180, 180, 20, 60, -0.002), K.RED, ref, 0, 0.0)
	for s in [1.0, -1.0]:
		b.sx = s
		# Joch: V-Platte von den Schultern zum Reaktor (liegt über den Brustplatten)
		b.panel(f, [[ct(1.312), 5], [ct(1.482), 5], [ct(1.482), 66], [ct(1.398), 84]], 0.017, 0.005, K.RED, ref, 2, 7, 9, 0.3)
		# innere Brustplatte und seitliche Platte (getrennt durch eine Fuge)
		b.panel(f, [[ct(1.236), 5], [ct(1.309), 5], [ct(1.366), 58], [ct(1.236), 60]], 0.012, 0.005, K.RED, ref, 2, 6, 7, 0.5)
		b.panel(f, [[ct(1.236), 63], [ct(1.372), 62], [ct(1.394), 90], [ct(1.236), 102]], 0.014, 0.005, K.RED, ref, 2, 6, 6, 0.5)
		# goldene Rippenstücke an der Brustkante
		for k in range(3):
			var y0 := 1.250 + 0.033 * k
			b.panel(f, [[ct(y0 - 0.010), 66.0 + 5.0 * k], [ct(y0 + 0.014), 66.0 + 5.0 * k], [ct(y0 + 0.024), 99.0], [ct(y0 + 0.001), 99.0]],
				0.019, 0.004, K.GOLD, ref, 0, 3, 4, 0.2)
		# Rippenplatten unter der Brust (Fassreifen)
		b.panel(f, [[ct(1.208), 5], [ct(1.240), 5], [ct(1.240), 104], [ct(1.208), 104]], 0.008, 0.003, K.RED, ref, 2, 3, 10, 0.3)
		b.panel(f, [[ct(1.180), 5], [ct(1.212), 5], [ct(1.212), 104], [ct(1.180), 104]], 0.006, 0.003, K.RED, ref, 2, 3, 10, 0.3)
		# Schrauben am Joch (oben)
		for q in [[1.455, 24.0], [1.445, 50.0]]:
			b.rivet(f, ct(q[0]), q[1], 0.0055, 0.004, K.METAL, 0.010)
	b.sx = 1.0
	_reactor(b, L)


static func _rs(prof: Array, sc: float) -> Array:
	var out := []
	for q in prof:
		out.append([float(q[0]) * sc, q[1]])
	return out


static func _reactor(b, L: K.Loft) -> void:
	var rc: Vector3 = L.pt(ct(1.318), 0.0, 0.011)
	var nz := Vector3(0, 0.04, 1.0).normalized()
	var sc := 0.82
	# Fassung (dunkel), heller Ring, Leuchtfläche
	K.lathe(b, rc, nz, _rs([[0.088, -0.004], [0.086, 0.004], [0.080, 0.008], [0.074, 0.010], [0.070, 0.0095]], sc), K.DARK, 0, 40)
	K.lathe(b, rc, nz, _rs([[0.074, 0.010], [0.073, 0.019], [0.066, 0.023], [0.058, 0.022], [0.054, 0.018], [0.052, 0.012]], sc), K.METAL, 0, 40)
	K.lathe(b, rc, nz, _rs([[0.052, 0.012], [0.049, 0.009], [0.047, 0.006]], sc), K.DARK, 0, 40)
	K.lathe(b, rc, nz, _rs([[0.047, 0.006], [0.042, 0.0075], [0.036, 0.0085], [0.028, 0.0092], [0.020, 0.0098], [0.010, 0.0102], [0.0, 0.0105]], sc), K.GLOW, 0, 40)
	for i in range(8):
		var a := TAU * (i + 0.5) / 8.0
		var d := Vector3(cos(a), sin(a), 0.0)
		b.dome(rc + d * 0.081 * sc + nz * 0.004, nz, 0.0040, 0.004, K.METAL)


# ---------------------------------------------------------------- Kragen (Schulterplatten am Hals)

static func collar(b) -> void:
	var L := chest_loft()
	var f := L.f()
	var ref := Vector3(0, 1.34, 0.0)
	for s in [1.0, -1.0]:
		b.sx = s
		# Trapezplatten (Gunmetal): zwei Lagen
		b.panel(f, [[ct(1.505), 38], [ct(1.505), 142], [ct(1.462), 150], [ct(1.462), 30]], 0.011, 0.005, K.GUN, ref, 2, 4, 9, 0.35)
		b.panel(f, [[ct(1.462), 22], [ct(1.462), 158], [ct(1.425), 160], [ct(1.425), 14]], 0.008, 0.004, K.GUN, ref, 2, 4, 9, 0.3)
		# rotes Fenster (Bogen) in der oberen Platte
		b.panel(f, [[ct(1.498), 66], [ct(1.498), 116], [ct(1.474), 118], [ct(1.474), 64]], 0.014, 0.003, K.RED, ref, 0, 3, 4, 0.2)
		b.rivet(f, ct(1.480), 90.0, 0.005, 0.004, K.METAL, 0.012)
	b.sx = 1.0
	# Halsring (rot) und Nackenwulst
	K.tube(b, Vector3(0, 1.505, -0.040), Vector3(0, 1.538, -0.040), K.X, K.Z,
		[[0.0, 0.085, 0.088, -180, 180, 2.4, 0, 0], [0.5, 0.080, 0.084, -180, 180, 2.4, 0, 0], [1.0, 0.074, 0.078, -180, 180, 2.4, 0, 0]], K.RED, 2, 4, 28, 0.0)


# ---------------------------------------------------------------- Rücken

static func back(b) -> void:
	var L := chest_loft()
	var f := L.f()
	var ref := Vector3(0, 1.34, 0.0)
	for s in [1.0, -1.0]:
		b.sx = s
		# obere Rückenplatte (Schulterblätter)
		b.panel(f, [[ct(1.405), 176], [ct(1.482), 176], [ct(1.482), 112], [ct(1.405), 98]], 0.010, 0.004, K.RED, ref, 2, 5, 7, 0.3)
		# Wabenfeld (Lüftung)
		b.panel(f, [[ct(1.300), 176], [ct(1.412), 176], [ct(1.412), 112], [ct(1.300), 138]], 0.003, 0.003, K.HEX, ref, 0, 5, 6, 0.0, 0.0015)
		# goldene V-Platte darunter
		b.panel(f, [[ct(1.205), 176], [ct(1.296), 176], [ct(1.296), 112], [ct(1.250), 116]], 0.011, 0.003, K.GOLD, ref, 3, 4, 7, 0.3)
		# Seitenplatte (Rot) am unteren Rücken
		b.panel(f, [[ct(1.185), 172], [ct(1.255), 120], [ct(1.405), 98], [ct(1.255), 98]], 0.008, 0.004, K.RED, ref, 2, 4, 6, 0.3)
		# Lüftungsschlitze oben am Rücken
		for k in range(3):
			var a := 118.0 + 9.0 * k
			b.panel(f, [[ct(1.440), a], [ct(1.470), a], [ct(1.470), a + 4.0], [ct(1.440), a + 4.0]], 0.003, 0.0015, K.DARK, ref, 0, 2, 2)
	b.sx = 1.0
	# Rückenmitte: schmale Platte entlang der Wirbelsäule mit Querrippen
	b.panel(f, [[ct(1.200), 173], [ct(1.470), 173], [ct(1.470), 187], [ct(1.200), 187]], 0.013, 0.004, K.RED, ref, 2, 8, 4, 0.5)


static func wings(b) -> void:
	# Stabilisator-Flügel: gebogene Klinge von der Schulterblatt-Mitte nach oben aussen
	var pts := [Vector3(0.070, 1.340, -0.165), Vector3(0.096, 1.390, -0.185), Vector3(0.130, 1.440, -0.198), Vector3(0.172, 1.490, -0.198),
		Vector3(0.218, 1.535, -0.186)]
	K.blade(b, pts, [0.036, 0.036, 0.030, 0.022, 0.005], Vector3(1, -0.5, 0), 0.40, K.RED, 1, 7, 0.010)
	# Rippen / Schlitze im Flügel: dunkle Lage darunter
	var pts2 := [Vector3(0.082, 1.350, -0.170), Vector3(0.110, 1.410, -0.194), Vector3(0.148, 1.478, -0.208), Vector3(0.196, 1.546, -0.208)]
	K.blade(b, pts2, [0.020, 0.020, 0.016, 0.008], Vector3(1, -0.5, 0), 0.20, K.DARK, 0, 5, 0.004)


# ---------------------------------------------------------------- Bauch (Spine1)

static func belly(a) -> void:
	var L := _loft(ABS, AY0, AY1)
	var f := L.f()
	var ref := Vector3(0, 1.1, 0.0)
	a.shell(L.grid(0.0, 1.0, -180, 180, 8, 48, -0.002), K.RED, ref, 0, 0.0)
	var tops := [1.200, 1.158, 1.116, 1.074]
	for k in range(tops.size()):
		var y0: float = tops[k]
		var y1 := y0 - 0.046
		# Mittelband (ganz herum) und goldene Seitenstücke
		for s in [1.0, -1.0]:
			a.sx = s
			a.panel(f, [[at(y1), 4], [at(y0), 4], [at(y0), 70], [at(y1), 70]], 0.007 + 0.001 * k, 0.003, K.RED, ref, 2, 3, 5, 0.3)
			a.panel(f, [[at(y1) - 0.01, 70], [at(y0) - 0.02, 70], [at(y0) + 0.025, 100], [at(y1) + 0.03, 100]], 0.009, 0.003, K.GOLD, ref, 0, 3, 3, 0.25)
			a.panel(f, [[at(y1), 100], [at(y0), 100], [at(y0), 176], [at(y1), 176]], 0.006, 0.003, K.RED, ref, 2, 3, 6, 0.2)
		a.sx = 1.0


# ---------------------------------------------------------------- Hüfte (Hips)

static func pelvis(h) -> void:
	# Gürtelring
	K.tube(h, Vector3(0, 1.052, -0.01), Vector3(0, 0.985, -0.01), K.X, K.Z,
		[[0.0, 0.182, 0.158, -180, 180, 2.6, 0, 0], [1.0, 0.190, 0.164, -180, 180, 2.6, 0, 0]], K.RED, 1, 4, 36, 0.006)
	# vordere V-Platte
	for s in [1.0, -1.0]:
		h.sx = s
		var R := []
		for y in [0.985, 0.960, 0.935, 0.910, 0.890]:
			var half := remap(y, 0.89, 0.985, 6.0, 48.0)
			R.append(K.ring(Vector3(0, y, 0.0), K.X, K.Z, 0.170, 0.155 - (0.985 - y) * 0.15, 0.0, half, 8, 2.6))
		h.shell(R, K.RED, Vector3(0, 0.95, -0.2), 2, 0.006)
	h.sx = 1.0
