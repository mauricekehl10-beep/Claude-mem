extends RefCounted
# Körperform von Captain America: Der glatte Y-Bot-Körper wird im Netz-Aufbau (mixamo_model.gd, _bake) zu einem
# kräftigen Supersoldaten verformt: breite Brust und Schultern, V-Form, Oberarme, Unterarme, Oberschenkel, Waden.
# Alle Maße sind Ruhepose-Koordinaten (T-Pose, Meter, Füsse bei y=0, +Z vorn, +X links). Die Verformung ist ein
# glattes Feld über alle Punkte (keine Risse); der Shader malt weiter nach der ursprünglichen Ruhepose-Position.

const ARM_Y := 1.436   # Armachse (T-Pose)
const ARM_Z := -0.062
const LEG_X := 0.092
const LEG_Z := -0.004

# Radius-Faktor des Arms je Abstand von der Mitte (ax): Schulter, Deltamuskel, Bizeps, Ellbogen, Unterarm, Handgelenk, Hand
const ARM_X := [0.18, 0.24, 0.30, 0.37, 0.43, 0.47, 0.53, 0.60, 0.68, 0.73, 0.78, 0.84, 0.88, 1.00]
const ARM_F := [1.00, 1.14, 1.27, 1.38, 1.28, 1.10, 1.25, 1.22, 1.08, 1.00, 1.12, 1.05, 1.00, 1.00]
# Faktor des Beins je Höhe: Wade, Knie, Oberschenkel, Hüfte
const LEG_Y := [0.20, 0.30, 0.42, 0.50, 0.55, 0.62, 0.74, 0.86, 0.96, 1.04]
const LEG_F := [1.00, 1.05, 1.12, 1.04, 1.03, 1.10, 1.20, 1.18, 1.08, 1.0]


# Weiche Kurve durch Stützpunkte (xs aufsteigend)
static func prof(x: float, xs: Array, ys: Array) -> float:
	if x <= xs[0]:
		return ys[0]
	for i in range(xs.size() - 1):
		if x <= xs[i + 1]:
			var t: float = (x - xs[i]) / (xs[i + 1] - xs[i])
			t = t * t * (3.0 - 2.0 * t)
			return lerpf(ys[i], ys[i + 1], t)
	return ys[ys.size() - 1]


# 1 zwischen a und b (mit weichem Rand r), sonst 0
static func band(x: float, a: float, b: float, r: float) -> float:
	return smoothstep(a - r, a + r, x) * (1.0 - smoothstep(b - r, b + r, x))


# Verformte Lage eines Punktes der Ruhepose
static func shape(p: Vector3) -> Vector3:
	var ax := absf(p.x)
	var sx := 1.0 if p.x >= 0.0 else -1.0
	var y := p.y
	var q := p
	# --- Arme: Radius um die Armachse wächst (Deltamuskel, Bizeps/Trizeps, Unterarm)
	var armw := smoothstep(0.17, 0.25, ax) * smoothstep(1.26, 1.32, y)
	var f := 1.0
	if armw > 0.0:
		f = 1.0 + armw * (prof(ax, ARM_X, ARM_F) - 1.0)
		# Bizeps/Brust nach vorn etwas mehr als nach hinten
		var fz := f * (1.0 + 0.06 * smoothstep(0.0, 0.05, p.z - ARM_Z) * band(ax, 0.26, 0.46, 0.04))
		q.y = ARM_Y + (y - ARM_Y) * f
		q.z = ARM_Z + (p.z - ARM_Z) * fz
	var tw := 1.0 - armw
	# --- Rumpf: V-Form. Schultern/Brust seitlich breiter, Taille bleibt, Brust und Latissimus tiefer
	var chest := band(y, 1.24, 1.47, 0.06)
	var lat := band(y, 1.16, 1.40, 0.06)
	var dx := 0.034 * chest * smoothstep(0.02, 0.13, ax) * (1.0 - smoothstep(0.19, 0.30, ax)) * tw
	dx += 0.012 * lat * smoothstep(0.08, 0.14, ax) * tw  # Latissimus unter den Achseln
	dx += 0.012 * band(y, 1.46, 1.54, 0.03) * smoothstep(0.05, 0.12, ax) * (1.0 - smoothstep(0.17, 0.26, ax))  # Trapezius
	q.x += sx * dx
	var front := smoothstep(0.0, 0.09, p.z)
	var back := smoothstep(-0.05, -0.10, p.z)
	var pec := band(y, 1.28, 1.46, 0.08) * (1.0 - smoothstep(0.12, 0.22, ax))
	q.z += 0.016 * pec * front * tw
	q.z += 0.014 * band(y, 1.14, 1.30, 0.05) * front * (1.0 - smoothstep(0.10, 0.17, ax)) * tw  # Bauchmuskeln
	q.z -= 0.020 * lat * back * tw
	q.z -= 0.012 * band(y, 1.34, 1.50, 0.04) * back * tw  # Schulterblätter / Rücken
	# Trapezius: Masse am Hals, die Schulterlinie fällt zur Schulter ab
	q.y += 0.014 * band(y, 1.47, 1.56, 0.03) * smoothstep(0.03, 0.07, ax) * (1.0 - smoothstep(0.08, 0.12, ax))
	q.y -= 0.028 * smoothstep(0.09, 0.17, ax) * (1.0 - smoothstep(0.20, 0.27, ax)) * smoothstep(1.44, 1.49, y)
	var nk := band(y, 1.50, 1.575, 0.02) * (1.0 - smoothstep(0.075, 0.10, ax))
	q.x *= 1.0 + 0.20 * nk
	q.z = lerpf(q.z, -0.022 + (q.z + 0.022) * 1.14, nk)
	# --- Beine: Oberschenkel, Waden; Gesäss
	var legw := 1.0 - smoothstep(0.96, 1.04, y)
	if legw > 0.0 or y < 1.04:
		var lf := prof(y, LEG_Y, LEG_F)
		var cx := sx * LEG_X
		var nx := cx + (p.x - cx) * lf
		# nicht über die Mitte hinaus (die Beine würden sich durchdringen)
		nx = sx * maxf(sx * nx, 0.012)
		q.x = lerpf(q.x, nx, legw)
		var lz := lf
		if p.z < LEG_Z:  # Wade und Gesäss hinten etwas stärker
			lz *= 1.0 + 0.10 * band(y, 0.30, 0.50, 0.06) + 0.08 * band(y, 0.84, 1.02, 0.05)
		q.z = lerpf(q.z, LEG_Z + (p.z - LEG_Z) * lz, legw)
	# Hüfte und Gesäss unter dem Gürtel
	q.x += sx * 0.006 * band(y, 0.98, 1.10, 0.04) * smoothstep(0.08, 0.16, ax)
	return q


# Kleine zusätzliche Verdickung in Metern entlang der Normale (Stoffdicke), ausser Hände und Gesicht
static func bulk(p: Vector3) -> float:
	var ax := absf(p.x)
	var y := p.y
	var arm := smoothstep(0.17, 0.23, ax) * smoothstep(1.28, 1.34, y)
	var sole := smoothstep(0.0, 0.05, y)  # Sohle bleibt auf dem Boden
	var d := 0.0
	d += 0.004 * (1.0 - arm) * band(y, 1.0, 1.5, 0.05)
	d += 0.004 * arm * (1.0 - smoothstep(0.70, 0.74, ax))
	d += 0.012 * sole * (1.0 - smoothstep(0.24, 0.34, y))  # Stiefel kräftiger
	d += 0.004 * (1.0 - smoothstep(0.96, 1.04, y)) * sole
	d += 0.0025 * smoothstep(0.738, 0.76, ax) * smoothstep(1.30, 1.34, y)  # Handschuh: Finger etwas kräftiger
	# Haube etwas grösser als der Kopf (Rücken und Seiten; vorn macht das hero_face.gd)
	d += 0.008 * smoothstep(1.575, 1.63, y) * (1.0 - smoothstep(0.0, 0.07, p.z))
	d += 0.007 * smoothstep(1.55, 1.575, y) * (1.0 - smoothstep(1.60, 1.63, y)) * smoothstep(0.0, 0.06, p.z)  # kräftiger Kiefer
	return d


# Verdeckung (1 = frei, kleiner = dunkler) je Punkt der Ruhepose mit Normale n: Innenseiten der Arme und Beine,
# Achseln, Schritt, Kinn, Handfläche, Sohlen. Die Pose ist egal (die Figur steht meist mit hängenden Armen).
static func occlusion(p: Vector3, n: Vector3) -> float:
	var ax := absf(p.x)
	var sx := 1.0 if p.x >= 0.0 else -1.0
	var y := p.y
	var nx := n.x * sx
	var a := 1.0
	var arm := smoothstep(0.18, 0.24, ax) * smoothstep(1.26, 1.32, y)
	# Arm hängt am Körper: die Unterseite (Ruhepose) liegt innen am Rumpf an
	a -= 0.34 * arm * smoothstep(0.05, 0.8, -n.y) * (1.0 - smoothstep(0.50, 0.66, ax))
	a -= 0.30 * band(ax, 0.17, 0.23, 0.03) * band(y, 1.25, 1.38, 0.03)  # Achselhöhle
	# Rumpfflanke unter dem hängenden Arm
	a -= 0.22 * (1.0 - arm) * smoothstep(0.3, 0.9, nx) * band(y, 1.12, 1.40, 0.04)
	# Beine: Innenseite der Schenkel, Schritt
	var leg := (1.0 - smoothstep(0.98, 1.04, y)) * smoothstep(0.12, 0.2, y)
	a -= 0.36 * leg * smoothstep(0.1, 0.8, -nx)
	a -= 0.35 * (1.0 - smoothstep(0.0, 0.05, ax)) * band(y, 0.78, 1.0, 0.05)
	# Sohlen und Boden
	a -= 0.45 * (1.0 - smoothstep(0.0, 0.045, y))
	# Kinn und Hals
	a -= 0.35 * band(y, 1.49, 1.575, 0.02) * smoothstep(0.0, 0.6, -n.y)
	# Handfläche (Hand schliesst sich): unten dunkler
	a -= 0.16 * smoothstep(0.738, 0.76, ax) * smoothstep(0.3, 0.9, -n.y)
	return clampf(a, 0.3, 1.0)


# Gesichtsrelief (Meter) für Captain: ax = Abstand von der Mitte, y = Höhe (Ruhepose). Feiner als hero_face.gd human():
# schmalere Lippen und Nasenflügel, markante Wangenknochen und Kiefer, Kinn mit leichter Furche.
static func gau(x: float, s: float) -> float:
	return exp(-x * x / (2.0 * s * s))


static func face(ax: float, y: float) -> float:
	var h := 0.0
	# Nase: Rücken, Spitze, Flügel
	var t := clampf((1.692 - y) / (1.692 - 1.628), 0.0, 1.0)
	var ts := t * t * (3.0 - 2.0 * t)
	var top := 1.0 - smoothstep(1.690, 1.704, y)
	var bot := smoothstep(1.612, 1.624, y)
	h += (0.0028 + 0.0160 * ts) * gau(ax, lerpf(0.0050, 0.0080, t)) * top * bot
	h += 0.0036 * gau(ax, 0.0066) * gau(y - 1.631, 0.0055)
	h += 0.0056 * gau(ax - 0.0120, 0.0050) * gau(y - 1.6295, 0.0050)
	# Nasenlöcher und Philtrum
	h -= 0.0045 * gau(ax - 0.0085, 0.0032) * gau(y - 1.6205, 0.0025)
	h -= 0.0024 * gau(ax, 0.0050) * gau(y - 1.610, 0.0045)
	# Brauenwulst, Augenhöhlen, Wangenknochen, Wangenhöhle, Kiefermuskel
	h += 0.0084 * gau(y - (1.6915 + ax * 0.045), 0.0058) * (1.0 - smoothstep(0.036, 0.064, ax))
	h -= 0.0056 * gau(ax - 0.0315, 0.0125) * gau(y - 1.6635, 0.0078)
	h += 0.0066 * gau(ax - 0.052, 0.0150) * gau(y - 1.637, 0.0135)
	h -= 0.0042 * gau(ax - 0.044, 0.0150) * gau(y - 1.598, 0.0100)
	h += 0.0030 * gau(ax - 0.066, 0.0110) * gau(y - 1.578, 0.0130)
	# Schläfe
	h -= 0.0018 * gau(ax - 0.068, 0.012) * gau(y - 1.68, 0.016)
	# Lippen, Mundspalt, Kinnfurche, Kinn mit Grübchen
	var mw := 1.0 - smoothstep(0.013, 0.025, ax)
	h += 0.0034 * gau(y - 1.6015, 0.0034) * mw
	h += 0.0040 * gau(y - 1.5915, 0.0038) * mw
	h -= 0.0034 * gau(y - 1.5963, 0.0012) * (1.0 - smoothstep(0.018, 0.025, ax))
	h -= 0.0040 * gau(y - 1.5800, 0.0032) * gau(ax, 0.0140)
	h += 0.0078 * gau(y - 1.5545, 0.0105) * gau(ax, 0.0200)
	h -= 0.0016 * gau(y - 1.5565, 0.0050) * gau(ax, 0.0040)
	return h
