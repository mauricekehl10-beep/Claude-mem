extends RefCounted
# Iron-Man-Helm (Mark III): eckige Schale, Gesichtsplatte aus Facetten, Wangen- und Kinnplatten, Ohrscheiben, Nackenring.
# Maße in Ruhepose-Koordinaten (Meter). Aufbau: Schale (rot) -> Gesichtsplatte (gold, Facetten) -> Anbauteile.

const K = preload("res://scripts/ironman_kit.gd")

# Schale: [t, rx, rz, n, ox, oz]; t = (y - Y0) / (Y1 - Y0)
const Y0 := 1.540
const Y1 := 1.822
const SKULL := [
	[0.00, 0.046, 0.062, 3.2, 0.0, 0.040],
	[0.06, 0.064, 0.094, 3.3, 0.0, 0.026],
	[0.16, 0.082, 0.120, 3.4, 0.0, 0.012],
	[0.30, 0.093, 0.134, 3.5, 0.0, 0.006],
	[0.48, 0.096, 0.139, 3.5, 0.0, 0.003],
	[0.66, 0.094, 0.137, 3.5, 0.0, 0.003],
	[0.82, 0.084, 0.124, 3.5, 0.0, 0.004],
	[0.93, 0.062, 0.096, 3.5, 0.0, 0.005],
	[0.98, 0.034, 0.056, 3.0, 0.0, 0.005],
	[1.00, 0.004, 0.008, 2.4, 0.0, 0.005],
]
# Gesichtsplatte je Höhe: [y, halbe Breite, z vorn, Nasenhöhe]
const FACE_KEYS := [
	[1.543, 0.018, 0.112, 0.000],
	[1.575, 0.047, 0.137, 0.002],
	[1.602, 0.062, 0.141, 0.006],
	[1.648, 0.081, 0.153, 0.012],
	[1.690, 0.087, 0.158, 0.008],
	[1.745, 0.074, 0.140, 0.002],
	[1.800, 0.052, 0.100, 0.000],
]


static func skull() -> K.Loft:
	return K.Loft.new(Vector3(0, Y0, 0), Vector3(0, Y1, 0), K.X, K.Z, SKULL)


# z der Schale an (x, y), nur vorn (Gesichtsseite)
static func skull_z(x: float, y: float) -> float:
	var k := skull().key((y - Y0) / (Y1 - Y0))
	var q := pow(clampf(absf(x) / float(k[1]), 0.0, 0.999), float(k[3]))
	return float(k[5]) + float(k[2]) * pow(1.0 - q, 1.0 / float(k[3]))


static func build(b, nb) -> void:
	var L := skull()
	var f := L.f()
	var ref := Vector3(0, 1.68, 0.0)
	# Schale (rot): eine Hülle, darauf Platten mit Fuge
	var R := []
	for i in range(34):
		var t := i / 33.0
		var k := L.key(t)
		var y := lerpf(Y0, Y1, t)
		R.append(K.ring(Vector3(0, y, float(k[5])), K.X, K.Z, k[1], k[2], -180, 180, 48, k[3]))
	b.shell(R, K.HELM, ref, 0, 0.0)
	_face(b)
	_side(b, L, f, ref)
	_top(b, L, f, ref)
	_back(b, L, f, ref)
	_neck(nb)
	# Helm etwas größer (Proportion zu Schultern)
	var c := Vector3(0, 1.545, 0.01)
	for i in range(b.vs.size()):
		b.vs[i] = c + (b.vs[i] - c) * 1.08


# Gesichtsplatte aus Facetten (flach schattiert): Nasenrücken, Gesichtsfläche, Wangenkante
static func _face(b) -> void:
	var F := []
	var ys: Array = []
	for r in FACE_KEYS:
		ys.append(r[0])
	for y in ys:
		var k := K.kf(FACE_KEYS, y)
		var w: float = k[1]
		var zf: float = k[2]
		var ns: float = k[3]
		var c1 := minf(0.020, w * 0.4)
		var c2 := minf(0.050, w * 0.75)
		var wa := c2 + (w - c2) * 0.5
		var xs := [-w, -wa, -c2, -c1, 0.0, c1, c2, wa, w]
		var row := []
		for x in xs:
			var ax := absf(x)
			var z := zf
			if ax <= 0.0001:
				z += ns
			elif ax <= c1 + 0.0001:
				z += ns * 0.35
			elif ax <= c2 + 0.0001:
				z -= 0.010
			else:
				z -= 0.010 + (ax - c2) / maxf(w - c2, 0.001) * (0.050 + 0.02 * (y - 1.543) * 4.0)
			z = maxf(z, skull_z(x, y) + 0.009)
			row.append(Vector3(x, y, z))
		F.append(row)
	b.shell(F, K.FACE, Vector3(0, 1.66, 0.0), 0, 0.004, true)


static func _side(b, L, f: Callable, ref: Vector3) -> void:
	for s in [1.0, -1.0]:
		b.sx = s
		# Ohrscheibe: Ring, Mulde, Mitte, Schrauben
		var c := Vector3(0.098, 1.668, 0.004)
		K.lathe(b, c, K.X, [[0.040, -0.004], [0.039, 0.001], [0.036, 0.0045], [0.030, 0.0055], [0.026, 0.0035], [0.022, 0.0015]], K.RED, 1, 24)
		K.lathe(b, c, K.X, [[0.022, 0.0015], [0.019, 0.0030], [0.012, 0.0036], [0.006, 0.0040], [0.0, 0.0040]], K.METAL, 0, 16)
		b.dome(c + Vector3(0.004, 0.026, 0.0), K.X, 0.0035, 0.0035, K.METAL)
		b.dome(c + Vector3(0.004, -0.026, 0.0), K.X, 0.0035, 0.0035, K.METAL)
		# Wangen- und Kieferplatte (rot, kantig) hinter der Gesichtsplatte
		b.panel(f, [[0.08, 66], [0.40, 60], [0.38, 102], [0.06, 112]], 0.007, 0.005, K.RED, ref, 2, 4, 4, 0.5)
		b.panel(f, [[0.00, 76], [0.10, 68], [0.08, 116], [0.00, 124]], 0.005, 0.004, K.DARK, ref, 0, 3, 3, 0.3)
		b.sx = 1.0


static func _top(b, L, f: Callable, ref: Vector3) -> void:
	# Mittelkamm (Rot, goldener Rand) über den Scheitel
	b.panel(f, [[0.91, -9.0], [0.99, -5.0], [0.99, 5.0], [0.91, 9.0]], 0.004, 0.003, K.RED, ref, 1, 3, 3, 0.2, 0.002)


static func _back(b, L, f: Callable, ref: Vector3) -> void:
	# Hinterkopf: Mittelrippe und seitliche Lüftungsschlitze
	b.panel(f, [[0.10, 174], [0.88, 176], [0.88, 184], [0.10, 186]], 0.006, 0.002, K.RED, ref, 0, 5, 2, 0.4)
	for s in [1.0, -1.0]:
		b.sx = s
		for k in range(4):
			var t0 := 0.20 + 0.08 * k
			b.panel(f, [[t0, 140], [t0 + 0.035, 140], [t0 + 0.035, 166], [t0, 166]], 0.003, 0.0015, K.DARK, ref, 0, 2, 3, 0.0)
		b.panel(f, [[0.08, 126], [0.50, 124], [0.50, 170], [0.08, 172]], 0.006, 0.004, K.RED, ref, 2, 4, 4, 0.4)
	b.sx = 1.0


static func _neck(nb) -> void:
	# Halsring: dunkle Gummiringe, oben ein heller Metallring
	K.tube(nb, Vector3(0, 1.486, -0.03), Vector3(0, 1.552, -0.03), K.X, K.Z,
		[[0.0, 0.070, 0.074, -180, 180, 2.2, 0, 0], [0.5, 0.062, 0.066, -180, 180, 2.2, 0, 0], [1.0, 0.064, 0.068, -180, 180, 2.2, 0, 0]], K.DARK, 0, 6, 24, 0.0)
