extends RefCounted
# Arme der Rüstung: Schulterpanzer (am Schlüsselbein), Oberarm (Gold), Ellbogen, Unterarm mit Flosse, Hand mit Fingern.
# Ruhepose: Arm-Achse entlang +X bei y=1.436, z=-0.062; Handfläche zeigt nach unten (-Y), Daumen nach vorn (+Z).
# Winkel um die Armachse: 0 = vorn (+Z), 90 = oben (+Y), 180 = hinten (-Z), 270 = unten (-Y).

const K = preload("res://scripts/ironman_kit.gd")
const AC := Vector3(0, 1.436, -0.062)


static func _l(a: Vector3, e: Vector3, keys: Array) -> K.Loft:
	return K.Loft.new(a, e, K.Y, K.Z, keys)


# ---------------------------------------------------------------- Schulter (Knochen: Schlüsselbein)

static func shoulder(b) -> void:
	# Panzerkappe über dem Schultergelenk: Kuppel mit Stufenplatte, Rolle, goldene Kante, Boss
	var L := _l(Vector3(0.095, 1.478, AC.z), Vector3(0.366, 1.462, AC.z), [
		[0.00, 0.088, 0.100, 2.8, 0.0, 0.0], [0.22, 0.104, 0.116, 2.8, 0.0, 0.0], [0.60, 0.108, 0.120, 2.9, 0.0, 0.0],
		[0.85, 0.096, 0.106, 2.9, 0.0, 0.0], [0.94, 0.074, 0.082, 2.8, 0.0, 0.0], [0.985, 0.036, 0.040, 2.4, 0.0, 0.0], [1.00, 0.008, 0.009, 2.2, 0.0, 0.0],
	])
	var f := L.f()
	var ref := Vector3(0.22, 1.40, AC.z)
	b.shell(L.grid(0.0, 1.0, -48, 228, 14, 40, -0.002), K.RED, ref, 0, 0.004)
	# Rolle über dem Scheitel
	b.panel(f, [[0.06, 72], [0.94, 72], [0.94, 108], [0.06, 108]], 0.010, 0.004, K.RED, ref, 1, 6, 4, 0.5)
	# Stufenplatte aussen (zweite Lage)
	b.panel(f, [[0.50, -44], [0.98, -34], [0.98, 214], [0.50, 224]], 0.018, 0.005, K.RED, ref, 1, 5, 12, 0.35)
	# vordere und hintere Lamelle am unteren Rand
	b.panel(f, [[0.08, -46], [0.55, -46], [0.52, -8], [0.12, -2]], 0.010, 0.004, K.RED, ref, 2, 4, 4, 0.2)
	b.panel(f, [[0.08, 226], [0.55, 226], [0.52, 188], [0.12, 182]], 0.010, 0.004, K.RED, ref, 2, 4, 4, 0.2)
	# goldene Randleiste vorn und hinten
	b.panel(f, [[0.12, -48], [0.90, -48], [0.90, -43], [0.12, -43]], 0.006, 0.002, K.GOLD, ref, 0, 5, 2)
	b.panel(f, [[0.12, 223], [0.90, 223], [0.90, 228], [0.12, 228]], 0.006, 0.002, K.GOLD, ref, 0, 5, 2)
	# Boss mit Schrauben (vorn aussen)
	for q in [[0.66, 18.0], [0.66, 162.0]]:
		var c: Vector3 = L.pt(q[0], q[1], 0.020)
		var nn: Vector3 = ((L.pt(q[0], q[1], 0.040)) - c).normalized()
		K.lathe(b, c, nn, [[0.030, -0.004], [0.029, 0.002], [0.025, 0.005], [0.018, 0.0055], [0.017, 0.0035], [0.012, 0.0030], [0.0, 0.0030]], K.METAL, 0, 20)
		b.dome(c + nn * 0.003, nn, 0.007, 0.004, K.DARK)
	# Nietreihe an der Stufenkante
	for k in range(6):
		b.rivet(f, 0.56 + 0.07 * k, 16.0, 0.0045, 0.0035, K.METAL, 0.019)
		b.rivet(f, 0.56 + 0.07 * k, 164.0, 0.0045, 0.0035, K.METAL, 0.019)


# ---------------------------------------------------------------- Oberarm (Knochen: Arm)

static func upper(b) -> void:
	var L := _l(Vector3(0.190, AC.y, AC.z), Vector3(0.466, AC.y, AC.z), [
		[0.00, 0.084, 0.090, 2.8, 0.0, 0.0], [0.40, 0.092, 0.098, 2.8, 0.0, 0.0], [0.85, 0.084, 0.090, 2.8, 0.0, 0.0], [1.00, 0.078, 0.084, 2.8, 0.0, 0.0],
	])
	var f := L.f()
	var ref := Vector3(0.33, AC.y, AC.z)
	b.shell(L.grid(0.0, 1.0, -180, 180, 10, 36, -0.002), K.RED, ref, 0, 0.0)
	# goldener Bizepsschild vorn (Trapez), darunter rote Seitenplatten oben und unten
	b.panel(f, [[0.16, -62], [0.84, -46], [0.84, 46], [0.16, 62]], 0.012, 0.004, K.GOLD, ref, 2, 6, 7, 0.35)
	b.panel(f, [[0.12, 66], [0.88, 54], [0.88, 126], [0.12, 134]], 0.009, 0.004, K.RED, ref, 2, 5, 5, 0.3)
	b.panel(f, [[0.12, -66], [0.88, -54], [0.88, -126], [0.12, -134]], 0.009, 0.004, K.RED, ref, 2, 5, 5, 0.3)
	# Rückenplatte
	b.panel(f, [[0.14, 138], [0.86, 130], [0.86, 230], [0.14, 222]], 0.008, 0.004, K.RED, ref, 2, 5, 6, 0.3)
	# Fugen-Schrauben am Bizepsschild
	for q in [[0.22, -50.0], [0.22, 50.0], [0.78, -36.0], [0.78, 36.0]]:
		b.rivet(f, q[0], q[1], 0.0045, 0.0035, K.METAL, 0.011)
	# dunkler Gummiring am Ellbogen
	K.tube(b, Vector3(0.452, AC.y, AC.z), Vector3(0.468, AC.y, AC.z), K.Y, K.Z,
		[[0.0, 0.070, 0.074, -180, 180, 2.4, 0, 0], [1.0, 0.072, 0.076, -180, 180, 2.4, 0, 0]], K.RUBBER, 0, 3, 24, 0.0)


# ---------------------------------------------------------------- Unterarm (Knochen: ForeArm)

static func forearm(b) -> void:
	var L := _l(Vector3(0.462, AC.y, AC.z), Vector3(0.742, AC.y, AC.z), [
		[0.00, 0.074, 0.078, 2.8, 0.0, -0.004], [0.10, 0.078, 0.082, 2.8, 0.0, -0.008], [0.30, 0.080, 0.084, 2.8, 0.0, -0.002],
		[0.70, 0.080, 0.084, 2.9, 0.0, 0.0], [0.92, 0.073, 0.077, 2.8, 0.0, 0.0], [1.00, 0.068, 0.072, 2.8, 0.0, 0.0],
	])
	var f := L.f()
	var ref := Vector3(0.60, AC.y, AC.z)
	b.shell(L.grid(0.0, 1.0, -180, 180, 12, 36, -0.002), K.RED, ref, 0, 0.0)
	# Ellbogenkappe (hinten, spitz) und goldene Manschette
	b.panel(f, [[0.02, 118], [0.20, 112], [0.20, 248], [0.02, 242]], 0.016, 0.005, K.RED, ref, 1, 4, 8, 0.45)
	b.panel(f, [[0.22, -180], [0.30, -180], [0.30, 180], [0.22, 180]], 0.007, 0.003, K.GOLD, ref, 0, 3, 24, 0.0, 0.0012, true)
	# Hauptpanzer: vorn, oben, unten (kantige Platten)
	b.panel(f, [[0.34, -56], [0.90, -46], [0.90, 46], [0.34, 56]], 0.011, 0.004, K.RED, ref, 2, 6, 7, 0.35)
	b.panel(f, [[0.34, 60], [0.90, 50], [0.90, 128], [0.34, 138]], 0.011, 0.004, K.RED, ref, 2, 6, 5, 0.3)
	b.panel(f, [[0.34, -60], [0.90, -50], [0.90, -128], [0.34, -138]], 0.011, 0.004, K.RED, ref, 2, 6, 5, 0.3)
	b.panel(f, [[0.34, 142], [0.90, 132], [0.90, 228], [0.34, 218]], 0.011, 0.004, K.RED, ref, 2, 6, 7, 0.3)
	# goldene Zierleisten
	b.panel(f, [[0.40, 56], [0.84, 47], [0.84, 51], [0.40, 60]], 0.014, 0.002, K.GOLD, ref, 0, 5, 2)
	b.panel(f, [[0.40, -60], [0.84, -51], [0.84, -47], [0.40, -56]], 0.014, 0.002, K.GOLD, ref, 0, 5, 2)
	# Handgelenkring (gold) und Gummi
	b.panel(f, [[0.92, -180], [0.985, -180], [0.985, 180], [0.92, 180]], 0.006, 0.003, K.GOLD, ref, 0, 3, 24, 0.0, 0.0012, true)
	# Stabilisator-Flosse auf der Hinterseite
	var r := Vector3(0, 0.62, -0.78).normalized()
	var root := Vector3(0.0, AC.y, AC.z) + r * 0.082
	var pts := []
	for i in range(6):
		pts.append(root + Vector3(0.505 + 0.044 * i, 0, 0) + r * 0.0)
	# Flosse: Mittellinie leicht nach aussen versetzt, Breite je Punkt
	var wd := [0.010, 0.026, 0.034, 0.034, 0.026, 0.010]
	var pts2 := []
	for i in range(6):
		pts2.append(Vector3(0.505 + 0.044 * i, 0, 0) + root * Vector3(0, 1, 1) + r * wd[i])
	K.blade(b, pts2, wd, r, 0.06, K.RED, 1, 4, 0.010)
	# Schrauben an der Flosse
	b.dome(Vector3(0.58, 0, 0) + root * Vector3(0, 1, 1) + r * 0.02, r, 0.004, 0.0035, K.METAL)
	b.dome(Vector3(0.68, 0, 0) + root * Vector3(0, 1, 1) + r * 0.02, r, 0.004, 0.0035, K.METAL)


# ---------------------------------------------------------------- Hand (Knochen: Hand + Fingerglieder)

# Finger: [Knochen, Anfang, Ende, Breite] je Glied; Positionen aus der Ruhepose
const FINGERS := {
	"Index": [Vector3(0.860, 1.433, -0.033), Vector3(0.899, 1.433, -0.033), Vector3(0.934, 1.433, -0.033), Vector3(0.968, 1.433, -0.033)],
	"Middle": [Vector3(0.866, 1.436, -0.062), Vector3(0.902, 1.436, -0.062), Vector3(0.936, 1.436, -0.062), Vector3(0.977, 1.436, -0.062)],
	"Ring": [Vector3(0.859, 1.436, -0.084), Vector3(0.895, 1.436, -0.084), Vector3(0.928, 1.436, -0.084), Vector3(0.969, 1.436, -0.084)],
	"Pinky": [Vector3(0.847, 1.433, -0.109), Vector3(0.888, 1.433, -0.109), Vector3(0.914, 1.433, -0.109), Vector3(0.947, 1.433, -0.109)],
	"Thumb": [Vector3(0.776, 1.414, -0.032), Vector3(0.812, 1.393, -0.010), Vector3(0.846, 1.373, 0.009), Vector3(0.876, 1.356, 0.026)],
}
const FWIDTH := {"Index": 0.0105, "Middle": 0.0110, "Ring": 0.0105, "Pinky": 0.0092, "Thumb": 0.0125}


static func hand(b) -> void:
	# Handrücken: Platte mit Knöchelleiste, Handfläche mit Repulsor
	var L := _l(Vector3(0.744, 1.434, -0.074), Vector3(0.868, 1.434, -0.074), [
		[0.00, 0.040, 0.050, 3.0, 0.0, 0.0], [0.45, 0.037, 0.058, 3.0, 0.0, 0.004], [1.00, 0.031, 0.056, 3.0, 0.0, 0.004],
	])
	var f := L.f()
	var ref := Vector3(0.80, 1.434, -0.074)
	b.panel(f, [[0.04, 38], [0.96, 42], [0.96, 138], [0.04, 142]], 0.007, 0.003, K.RED, ref, 2, 5, 6, 0.35)
	b.panel(f, [[0.62, 24], [0.99, 24], [0.99, 156], [0.62, 156]], 0.007, 0.003, K.RED, ref, 1, 3, 8, 0.4)
	# Knöchelschrauben
	for k in range(4):
		var a := 46.0 + k * 30.0
		b.rivet(f, 0.86, a, 0.0045, 0.0035, K.METAL, 0.014)
	# Handfläche
	b.panel(f, [[0.06, -40], [0.96, -44], [0.96, -140], [0.06, -138]], 0.004, 0.003, K.RED, ref, 0, 4, 5, 0.3)
	# Repulsor in der Handfläche (leuchtend)
	var rc := Vector3(0.803, 1.386, -0.062)
	var dn := Vector3(0, -1, 0)
	K.lathe(b, rc, dn, [[0.036, -0.002], [0.036, 0.003], [0.031, 0.0055], [0.027, 0.005], [0.026, 0.003]], K.METAL, 0, 24)
	K.lathe(b, rc, dn, [[0.026, 0.003], [0.021, 0.0035], [0.012, 0.0038], [0.0, 0.0040]], K.GLOW, 0, 24)


static func finger(b, name: String, k: int) -> void:
	# Fingerglied k (0..2) als kantige Kapsel; b = Builder des Fingerknochens
	var pts: Array = FINGERS[name]
	var a: Vector3 = pts[k]
	var e: Vector3 = pts[k + 1]
	var w: float = FWIDTH[name]
	var ax := (e - a).normalized()
	var ex := ax.cross(K.Z if absf(ax.dot(K.Z)) < 0.9 else K.Y).normalized()
	var ez := ex.cross(ax).normalized()
	# ex zeigt quer, ez nach oben/aussen; Glied etwas breiter als dick, vorn gerundet
	var tip := 1.0 if k == 2 else 0.0
	var keys := [
		[0.00, w * 0.82, w * 0.86, 3.2, 0.0, 0.0], [0.12, w * 0.98, w * 1.02, 3.2, 0.0, 0.0], [0.88, w * 0.94, w * 0.98, 3.2, 0.0, 0.0],
		[1.00 - 0.04 * tip, w * 0.80, w * 0.82, 3.0, 0.0, 0.0],
	]
	if k == 2:
		keys.append([1.0, w * 0.35, w * 0.35, 2.4, 0.0, 0.0])
	var L := K.Loft.new(a + ax * 0.0015, e - ax * 0.0015, ex, ez, keys)
	b.shell(L.grid(0.0, 1.0, -180, 180, 7, 12), K.RED if k != 1 else K.RED, (a + e) * 0.5, 1 if k == 0 else 0, 0.0)
