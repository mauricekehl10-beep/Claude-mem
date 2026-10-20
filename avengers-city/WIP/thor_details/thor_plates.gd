extends RefCounted
# Thors Brust-, Bauch- und Rückenrüstung als Platten, die dem Körper folgen (thor_surf.gd):
# Schmetterlingsplatte, Scheiben mit Rahmen und Nieten, Bauchlamellen, Lederriemen mit Schnallen, Rückenplatte.
# Material: thor_armor.gdshader (siehe thor_suit.gd: mat). Alle Maße: Ruhepose, Meter.

const T = preload("res://scripts/thor_suit.gd")
const S = preload("res://scripts/thor_surf.gd")

const SPINE := "mixamorig_Spine2"
const HIPS := "mixamorig_Hips"

static var _cache := {}


static func v2(x: float, y: float) -> Vector2:
	return Vector2(x, y)


# Netz an einen Knochen hängen (leere Netze werden übersprungen)
static func put(skel: Skeleton3D, bone: String, mb: T.MB, m: Material) -> void:
	if mb.v.size() < 3:
		return
	T.put(skel, bone, mb.mesh(), m)


# Kleine Niete (Halbkugel) auf der Oberfläche
static func rivet(mb: T.MB, pos: Vector3, n: Vector3, r: float = 0.0034) -> void:
	var bs := T.sframe(n)
	T.lathe(mb, [Vector2(r, 0.0), Vector2(r * 0.97, r * 0.35), Vector2(r * 0.72, r * 0.80), Vector2(r * 0.3, r * 1.0), Vector2(0.0, r * 1.02)], bs, pos, 10, 0.4)


# Niete in der Mitte des Bandes bei (x, y) auf der Oberfläche
static func rivet_at(mb: T.MB, x: float, y: float, lift: float, back: bool = false, r: float = 0.0034) -> void:
	var sv := S.at(x, y, back)
	rivet(mb, (sv[0] as Vector3) + (sv[1] as Vector3) * lift, sv[1], r)


static func build(skel: Skeleton3D) -> void:
	if not S.setup(skel):
		return
	chest(skel)
	abdomen(skel)
	back(skel)
	S.release()


# ---------------------------------------------------------------- Brust

static func chest(skel: Skeleton3D) -> void:
	var silver := T.mat(0, T.SILVER, 0.85, 0.36)
	var gun := T.mat(1, T.GUN, 0.55, 0.42)
	var plate := T.mat(1, T.PLATE, 0.55, 0.42)
	var lea := T.mat(2, Color(0.075, 0.068, 0.07), 0.0, 0.55)
	var ms := T.MB.new()  # Silber
	var mg := T.MB.new()  # dunkles Metall
	var mp := T.MB.new()  # Platten
	var ml := T.MB.new()  # Leder
	for s in [-1.0, 1.0]:
		# Schmetterling: oberer Flügel (zu den grossen Scheiben), unterer Flügel
		S.band(ms, PackedVector2Array([v2(s * 0.012, 1.318), v2(s * 0.050, 1.357), v2(s * 0.094, 1.396)]), func(f: float): return lerpf(0.0165, 0.021, f), 0.0085, 0.003, 0.35, false, 0.06, 8)
		S.band(ms, PackedVector2Array([v2(s * 0.012, 1.322), v2(s * 0.044, 1.282), v2(s * 0.076, 1.236)]), func(f: float): return lerpf(0.0155, 0.0195, f), 0.0085, 0.003, 0.35, false, 0.06, 8)
		# Rahmen: dunkle Zwischenstücke seitlich der Flügel
		S.band(mg, PackedVector2Array([v2(s * 0.112, 1.372), v2(s * 0.132, 1.30), v2(s * 0.138, 1.20)]), func(f: float): return lerpf(0.020, 0.026, f), 0.0065, 0.0015, 0.35, false, 0.08, 6)
	# Mittelsäule mit Schlitz
	S.band(ms, PackedVector2Array([v2(0.0, 1.345), v2(0.0, 1.162)]), func(_f): return 0.0215, 0.0105, 0.0035, 0.28, false, 0.05, 8)
	S.band(mg, PackedVector2Array([v2(0.0, 1.290), v2(0.0, 1.222)]), func(_f): return 0.0034, 0.0004, 0.0148, 0.5, false, 0.2, 4)
	# Schultergurt-Platten: von den grossen Scheiben zum Hals (dunkles Metall)
	for s in [-1.0, 1.0]:
		S.band(mp, PackedVector2Array([v2(s * 0.112, 1.428), v2(s * 0.082, 1.470), v2(s * 0.062, 1.500)]), func(f: float): return lerpf(0.030, 0.018, f), 0.006, 0.0015, 0.30, false, 0.1, 6)
	# Scheiben: [Mitte x, y, Radius, Höhe, Rahmenradius]
	var discs := [[0.112, 1.432, 0.052, 0.026, 0.064], [0.100, 1.266, 0.031, 0.015, 0.042], [0.094, 1.124, 0.034, 0.017, 0.044]]
	for s in [-1.0, 1.0]:
		for d in discs:
			var sv := S.at(s * float(d[0]), float(d[1]))
			var pos: Vector3 = sv[0]
			var n: Vector3 = sv[1]
			var bs := T.sframe(n)
			var r: float = d[2]
			var fr: float = d[4]
			T.dome(ms, bs, pos + n * 0.0035, r, d[3])
			# Rahmen: Ring mit Fase und Nietenkranz
			T.lathe(mg, [Vector2(fr + 0.003, -0.002), Vector2(fr + 0.003, 0.003), Vector2(fr, 0.0075), Vector2(fr - 0.006, 0.0095), Vector2(r + 0.001, 0.0085), Vector2(r - 0.001, 0.0035)], bs, pos + n * 0.0005, 32, 0.8)
			var nr := 10 if r > 0.04 else 7
			for k in range(nr):
				var a := TAU * (float(k) + 0.5) / float(nr)
				var pk := pos + n * 0.0005 + bs * Vector3(cos(a) * (fr - 0.0045), 0.0098, sin(a) * (fr - 0.0045))
				rivet(ms, pk, n, 0.0026)
		# dunkle Tropfenplatte um die untere Scheibe
		var sv2 := S.at(s * 0.094, 1.12)
		var n2: Vector3 = sv2[1]
		var bs2 := T.sframe(n2) * Basis.from_scale(Vector3(1.0, 1.0, 1.5))
		T.lathe(mp, [Vector2(0.060, -0.003), Vector2(0.060, 0.004), Vector2(0.052, 0.0085), Vector2(0.040, 0.0095)], bs2, (sv2[0] as Vector3) - n2 * 0.0005, 32, 0.8)
		# Lederband unter dem Arm (Seitenriemen) mit Nieten
		S.band(ml, PackedVector2Array([v2(s * 0.146, 1.392), v2(s * 0.160, 1.30), v2(s * 0.150, 1.18)]), func(_f): return 0.011, 0.0045, 0.002, 0.3, false, 0.04, 4)
		for yy in [1.35, 1.285, 1.22]:
			rivet_at(ml, s * (0.146 + 0.0 * float(yy)), float(yy), 0.0085, false, 0.0028)
	put(skel, SPINE, ms, silver)
	put(skel, SPINE, mg, gun)
	put(skel, SPINE, mp, plate)
	put(skel, SPINE, ml, lea)


# ---------------------------------------------------------------- Bauch

static func abdomen(skel: Skeleton3D) -> void:
	var plate := T.mat(1, T.PLATE, 0.55, 0.42)
	var gun := T.mat(1, T.GUN, 0.55, 0.42)
	var silver := T.mat(0, T.SILVER, 0.85, 0.36)
	var mp := T.MB.new()
	var mg := T.MB.new()
	var ms := T.MB.new()
	# drei überlappende Lamellen quer über den Bauch
	var ys := [1.200, 1.162, 1.126]
	for i in range(ys.size()):
		var y: float = ys[i]
		S.band(mp, PackedVector2Array([v2(-0.150, y + 0.004), v2(-0.07, y), v2(0.0, y - 0.0015), v2(0.07, y), v2(0.150, y + 0.004)]), func(_f): return 0.0185, 0.0055, 0.0015, 0.22, false, 0.0, 6, 0.8)
		# Silberkante an der Unterseite der Lamelle
		S.band(ms, PackedVector2Array([v2(-0.128, y - 0.0155), v2(0.0, y - 0.0195), v2(0.128, y - 0.0155)]), func(_f): return 0.0016, 0.0035, 0.0055, 0.5, false, 0.08, 3, 0.8)
	# kleines Silberstück in der Mitte unter der Säule
	S.band(ms, PackedVector2Array([v2(-0.030, 1.092), v2(0.030, 1.092)]), func(_f): return 0.0105, 0.006, 0.0025, 0.35, false, 0.2, 5)
	put(skel, SPINE, mp, plate)
	put(skel, SPINE, ms, silver)
	put(skel, SPINE, mg, gun)


# ---------------------------------------------------------------- Rücken

static func back(skel: Skeleton3D) -> void:
	var plate := T.mat(1, T.PLATE, 0.55, 0.42)
	var gun := T.mat(1, T.GUN, 0.55, 0.42)
	var silver := T.mat(0, T.SILVER, 0.85, 0.36)
	var lea := T.mat(2, Color(0.085, 0.075, 0.07), 0.0, 0.55)
	var mp := T.MB.new()
	var mg := T.MB.new()
	var ms := T.MB.new()
	var ml := T.MB.new()
	# Rückenplatte: breites dunkles Metallschild, darunter Lamellen
	S.band(mp, PackedVector2Array([v2(0.0, 1.425), v2(0.0, 1.20)]), func(f: float): return lerpf(0.120, 0.095, f), 0.007, 0.002, 0.18, true, 0.0, 12, 0.8)
	for y in [1.172, 1.140, 1.108]:
		S.band(mg, PackedVector2Array([v2(-0.125, y + 0.004), v2(0.0, y - 0.002), v2(0.125, y + 0.004)]), func(_f): return 0.0170, 0.0055, 0.0015, 0.22, true, 0.0, 6, 0.8)
	# gekreuzte Lederriemen über die Schultern
	for s in [-1.0, 1.0]:
		S.band(ml, PackedVector2Array([v2(s * 0.115, 1.462), v2(s * 0.060, 1.350), v2(-s * 0.012, 1.215), v2(-s * 0.052, 1.108)]), func(_f): return 0.0135, 0.0042, 0.0095, 0.25, true, 0.0, 5)
		for yy in [1.40, 1.33, 1.26]:
			var t := (1.462 - float(yy)) / 0.254
			rivet_at(ml, s * lerpf(0.115, 0.008, t) * (1.0 if t < 0.6 else 0.5), float(yy), 0.0165, true, 0.0027)
	# Schnallenplatte, wo sich die Riemen kreuzen
	var sv := S.at(0.0, 1.282, true)
	var n: Vector3 = sv[1]
	T.cbox(ms, T.frame(Vector3(0, 1, 0), n), (sv[0] as Vector3) + n * 0.0185, Vector3(0.050, 0.050, 0.009), 0.003)
	T.cbox(mg, T.frame(Vector3(0, 1, 0), n), (sv[0] as Vector3) + n * 0.0215, Vector3(0.030, 0.030, 0.006), 0.002)
	put(skel, SPINE, mp, plate)
	put(skel, SPINE, mg, gun)
	put(skel, SPINE, ms, silver)
	put(skel, SPINE, ml, lea)
