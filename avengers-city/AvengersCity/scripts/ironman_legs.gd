extends RefCounted
# Beine der Rüstung: Oberschenkel (Silber/Gold mit Facetten), Knie mit Gummiringen, Schienbein, Stiefel mit Zehenkappe und Düse.
# Winkel um die Beinachse: 0 = vorn (+Z), 90 = aussen (+X links), 180 = hinten, 270 = innen.

const K = preload("res://scripts/ironman_kit.gd")


# ---------------------------------------------------------------- Oberschenkel (Knochen: UpLeg)

static func thigh(b) -> void:
	var L := K.Loft.new(Vector3(0.093, 0.955, 0.0), Vector3(0.093, 0.522, -0.005), K.X, K.Z, [
		[0.00, 0.105, 0.120, 2.7, 0.0, 0.0], [0.30, 0.110, 0.124, 2.7, 0.0, 0.0], [0.70, 0.096, 0.102, 2.7, 0.0, 0.0], [1.00, 0.086, 0.090, 2.7, 0.0, 0.0],
	])
	var f := L.f()
	var ref := Vector3(0.093, 0.74, -0.003)
	b.shell(L.grid(0.0, 1.0, -180, 180, 12, 36, -0.002), K.RED, ref, 0, 0.0)
	# goldener Rahmen und Silberplatte (Facetten), goldener Steg oben
	b.panel(f, [[0.05, -52], [0.88, -42], [0.88, 42], [0.05, 52]], 0.009, 0.004, K.GOLD, ref, 2, 6, 7, 0.3)
	b.panel(f, [[0.09, -40], [0.80, -32], [0.80, 32], [0.09, 40]], 0.024, 0.006, K.GUN, ref, 0, 4, 4, 0.9, 0.0012, false, true)
	b.panel(f, [[0.10, -6], [0.30, -6], [0.30, 6], [0.10, 6]], 0.022, 0.002, K.GOLD, ref, 0, 4, 2, 0.1)
	# rote Seitenplatten aussen und innen, hinten
	b.panel(f, [[0.06, 56], [0.90, 46], [0.90, 130], [0.06, 140]], 0.011, 0.004, K.RED, ref, 2, 6, 5, 0.3)
	b.panel(f, [[0.06, -56], [0.90, -46], [0.90, -130], [0.06, -140]], 0.011, 0.004, K.RED, ref, 2, 6, 5, 0.3)
	b.panel(f, [[0.06, 144], [0.90, 134], [0.90, 226], [0.06, 216]], 0.011, 0.004, K.RED, ref, 2, 6, 7, 0.3)
	# Schrauben
	for q in [[0.14, -46.0], [0.14, 46.0], [0.72, -38.0], [0.72, 38.0]]:
		b.rivet(f, q[0], q[1], 0.0045, 0.0035, K.METAL, 0.020)
	# Gummiring am Knie (oben am Schienbein ergänzt)
	K.tube(b, Vector3(0.093, 0.540, -0.004), Vector3(0.093, 0.520, -0.005), K.X, K.Z,
		[[0.0, 0.092, 0.097, -180, 180, 2.5, 0, 0], [1.0, 0.090, 0.095, -180, 180, 2.5, 0, 0]], K.RUBBER, 0, 3, 28, 0.0)


# ---------------------------------------------------------------- Knie und Schienbein (Knochen: Leg)

static func shin(b) -> void:
	var L := K.Loft.new(Vector3(0.0937, 0.525, -0.017), Vector3(0.0912, 0.140, -0.037), K.X, K.Z, [
		[0.00, 0.086, 0.094, 2.7, 0.0, 0.0], [0.14, 0.094, 0.108, 2.7, 0.0, 0.002], [0.45, 0.086, 0.104, 2.7, 0.0, -0.006],
		[0.80, 0.070, 0.082, 2.7, 0.0, -0.004], [1.00, 0.064, 0.074, 2.7, 0.0, 0.0],
	])
	var f := L.f()
	var ref := Vector3(0.093, 0.33, -0.027)
	b.shell(L.grid(0.0, 1.0, -180, 180, 12, 36, -0.002), K.RED, ref, 0, 0.0)
	# Gummiringe oben (Kniegelenk)
	for k in range(3):
		var t0 := 0.0 + 0.028 * k
		b.panel(f, [[t0, -180], [t0 + 0.020, -180], [t0 + 0.020, 180], [t0, 180]], 0.005, 0.002, K.RUBBER, ref, 0, 2, 28, 0.0, 0.0012, true)
	# Kniescheibe: rote Kappe mit goldenem Rand, darüber Schutzplatte
	b.panel(f, [[0.09, -48], [0.24, -52], [0.24, 52], [0.09, 48]], 0.022, 0.005, K.RED, ref, 1, 3, 4, 0.9, 0.0012, false, true)
	b.panel(f, [[0.01, -38], [0.10, -44], [0.10, 44], [0.01, 38]], 0.014, 0.004, K.GOLD, ref, 2, 3, 6, 0.4)
	# Schienbeinkante (Silber/Gold-Facette) und rote Seitenflügel
	b.panel(f, [[0.28, -30], [0.88, -22], [0.88, 22], [0.28, 30]], 0.020, 0.005, K.GUN, ref, 0, 5, 3, 0.9, 0.0012, false, true)
	b.panel(f, [[0.28, -6], [0.84, -4], [0.84, 4], [0.28, 6]], 0.020, 0.002, K.GOLD, ref, 0, 5, 2, 0.1)
	b.panel(f, [[0.26, 34], [0.90, 26], [0.90, 100], [0.26, 108]], 0.012, 0.004, K.RED, ref, 2, 5, 5, 0.3)
	b.panel(f, [[0.26, -34], [0.90, -26], [0.90, -100], [0.26, -108]], 0.012, 0.004, K.RED, ref, 2, 5, 5, 0.3)
	# Wadenplatte hinten (Rot) mit dunklem Spalt (Mechanik)
	b.panel(f, [[0.14, 110], [0.60, 112], [0.60, 250], [0.14, 252]], 0.012, 0.004, K.RED, ref, 2, 5, 8, 0.4)
	b.panel(f, [[0.62, 120], [0.92, 124], [0.92, 236], [0.62, 240]], 0.007, 0.003, K.GUN, ref, 2, 4, 6, 0.2)
	# Knöchelring (Gold)
	b.panel(f, [[0.90, -180], [0.985, -180], [0.985, 180], [0.90, 180]], 0.007, 0.003, K.GOLD, ref, 0, 3, 24, 0.0, 0.0012, true)
	for q in [[0.56, -40.0], [0.56, 40.0], [0.40, -22.0], [0.40, 22.0]]:
		b.rivet(f, q[0], q[1], 0.0045, 0.0035, K.METAL, 0.012)


# ---------------------------------------------------------------- Stiefel (Knochen: Foot)

# Querschnitt des Stiefels bei z: [Mitte y, Halbhöhe, Halbbreite]
static func _sec(z: float, grow: float) -> Array:
	var top := 0.092
	var hw := 0.066
	if z > 0.0:
		top = lerpf(0.092, 0.05, smoothstep(0.0, 0.2, z))
		hw = lerpf(0.066, 0.056, smoothstep(0.0, 0.2, z))
	if z > 0.2:
		top = lerpf(top, 0.022, (z - 0.2) / 0.05)
		hw = lerpf(hw, 0.022, (z - 0.2) / 0.05)
	return [top * 0.5, maxf(top * 0.5 + grow, 0.004), hw + grow]


static func boot(b) -> void:
	var keys := []
	var z0 := -0.112
	var z1 := 0.258
	for i in range(14):
		var t := i / 13.0
		var z := lerpf(z0, z1, t)
		var s := _sec(z, 0.007)
		keys.append([t, s[2], s[1], 2.8, 0.0, s[0] - 0.003])
	# Heckkappe vorn schliessen
	var L := K.Loft.new(Vector3(0.093, 0.0, z0), Vector3(0.093, 0.0, z1), K.X, K.Y, keys)
	var f := L.f()
	var ref := Vector3(0.093, 0.04, 0.05)
	b.shell(L.grid(0.0, 1.0, -180, 180, 16, 32, 0.0), K.RED, ref, 1, 0.0)
	# goldene Zehenkappe, rote Spannplatten, Seitenflügel
	b.panel(f, [[0.70, -62], [0.97, -34], [0.97, 34], [0.70, 62]], 0.010, 0.004, K.GOLD, ref, 2, 4, 6, 0.35)
	b.panel(f, [[0.40, -54], [0.68, -60], [0.68, 60], [0.40, 54]], 0.010, 0.004, K.RED, ref, 2, 4, 6, 0.35)
	b.panel(f, [[0.16, -50], [0.38, -54], [0.38, 54], [0.16, 50]], 0.013, 0.004, K.RED, ref, 2, 4, 6, 0.4)
	b.panel(f, [[0.10, 64], [0.65, 72], [0.65, 118], [0.10, 112]], 0.008, 0.004, K.RED, ref, 2, 5, 4, 0.2)
	b.panel(f, [[0.10, -64], [0.65, -72], [0.65, -118], [0.10, -112]], 0.008, 0.004, K.RED, ref, 2, 5, 4, 0.2)
	# Ferse: goldene Kappe hinten
	b.panel(f, [[0.00, -60], [0.14, -64], [0.14, 64], [0.00, 60]], 0.006, 0.003, K.GOLD, ref, 0, 3, 5, 0.2)
	# Sohle (dunkel) mit Düsenring
	b.panel(f, [[0.02, 118], [0.96, 122], [0.96, 238], [0.02, 242]], 0.004, 0.003, K.DARK, ref, 0, 5, 5, 0.0)
	var rc := Vector3(0.093, 0.004, 0.050)
	K.lathe(b, rc, Vector3(0, -1, 0), [[0.040, -0.002], [0.040, 0.003], [0.034, 0.0055], [0.026, 0.0050], [0.022, 0.0030]], K.METAL, 0, 24)
	K.lathe(b, rc, Vector3(0, -1, 0), [[0.022, 0.0030], [0.012, 0.0034], [0.0, 0.0036]], K.DARK, 0, 24)
