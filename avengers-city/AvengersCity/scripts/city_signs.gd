extends RefCounted
# Schilder und Reklame: Leuchtschriften, LED-Wandflaechen (Times Square), Auslegerschilder, Strassennamen, Dachtafeln.
# Alle Funktionen zeichnen in einen Mesh-Sammler (city_mesh.gd). Ebene: o = untere linke Ecke, r = Einheitsvektor nach rechts,
# n = Aussennormale (r x hoch = n), w/h = Breite/Hoehe.

const M = preload("res://scripts/city_mats.gd")
const GFont = preload("res://scripts/city_font.gd")

const NEON := [Color(1.0, 0.12, 0.35), Color(0.1, 0.8, 1.0), Color(1.0, 0.75, 0.1), Color(0.3, 1.0, 0.4), Color(1.0, 0.4, 0.9), Color(1.0, 0.25, 0.1)]
const WORDS := ["PIZZA", "DELI", "HOTEL", "BAR", "CAFE", "BANK", "24 HR", "DINER", "NYC", "BAGELS", "SHOES", "THEATER", "GRILL", "PHARMACY", "OPEN", "TAXI", "BOOKS", "NOODLES", "CINEMA", "LIQUOR", "TICKETS", "SUSHI", "DONUTS"]


# Orientierter Quader: Rueckseite liegt in der Ebene o, Ausdehnung nach rechts w, nach oben h, nach aussen d.
static func obox(mb, mat: Material, o: Vector3, r: Vector3, n: Vector3, w: float, h: float, d: float, col: Color, rough: float = 0.6, metal: float = 0.0, emis: float = 0.0) -> void:
	var up := Vector3.UP
	var p := func(x: float, y: float, z: float) -> Vector3:
		return o + r * x + up * y + n * z
	mb.sq(mat, p.call(0, 0, d), p.call(w, 0, d), p.call(w, h, d), p.call(0, h, d), col, rough, metal, emis)
	mb.sq(mat, p.call(0, h, d), p.call(w, h, d), p.call(w, h, 0), p.call(0, h, 0), col, rough, metal, emis)
	mb.sq(mat, p.call(w, 0, d), p.call(w, 0, 0), p.call(w, h, 0), p.call(w, h, d), col, rough, metal, emis)
	mb.sq(mat, p.call(0, 0, 0), p.call(0, 0, d), p.call(0, h, d), p.call(0, h, 0), col, rough, metal, emis)
	mb.sq(mat, p.call(0, 0, 0), p.call(w, 0, 0), p.call(w, 0, d), p.call(0, 0, d), col, rough, metal, 0.0)


# Animierte LED-Flaeche mit Rahmen. seed 0..1 waehlt Muster und Farbe.
static func screen(mb, o: Vector3, r: Vector3, n: Vector3, w: float, h: float, seed_v: float, hue: Color, frame: bool = true) -> void:
	var up := Vector3.UP
	var solid := M.solid()
	var depth := 0.45
	if frame:
		# Kasten dahinter (Rueckseite/Seiten) und Rahmen
		obox(mb, solid, o, r, n, w, h, depth * 0.6, Color(0.07, 0.07, 0.08), 0.6, 0.4)
		var f := 0.22
		obox(mb, solid, o + n * (depth * 0.6) , r, n, w, f, 0.16, Color(0.10, 0.10, 0.11), 0.5, 0.6)
		obox(mb, solid, o + n * (depth * 0.6) + up * (h - f), r, n, w, f, 0.16, Color(0.10, 0.10, 0.11), 0.5, 0.6)
		obox(mb, solid, o + n * (depth * 0.6), r, n, f, h, 0.16, Color(0.10, 0.10, 0.11), 0.5, 0.6)
		obox(mb, solid, o + n * (depth * 0.6) + r * (w - f), r, n, f, h, 0.16, Color(0.10, 0.10, 0.11), 0.5, 0.6)
	var z := depth * 0.6 + 0.04
	var c := Color(hue.r, hue.g, hue.b, seed_v)
	var a := o + n * z + r * (0.22 if frame else 0.0) + up * (0.22 if frame else 0.0)
	var ww := w - (0.44 if frame else 0.0)
	var hh := h - (0.44 if frame else 0.0)
	mb.quad(M.screen(), a, a + r * ww, a + r * ww + up * hh, a + up * hh, n, 0.0, 1.0, 0.0, 1.0, Vector2(ww, hh), c)


# Leuchtschrift mit Tafel dahinter (z. B. "PIZZA" ueber dem Laden)
static func neon_text(mb, o: Vector3, r: Vector3, n: Vector3, s: String, h: float, col: Color, back: bool = true) -> float:
	var solid := M.solid()
	var tw := GFont.width(s, h)
	if back:
		obox(mb, solid, o - r * 0.15 - Vector3.UP * 0.12, r, n, tw + 0.3, h + 0.24, 0.12, Color(0.05, 0.05, 0.06), 0.6, 0.2)
	GFont.text(mb, solid, o + n * 0.15, r, Vector3.UP, s, h, col, 3.0, 0.3)
	return tw


# Auslegerschild senkrecht zur Fassade (Leuchtkasten mit Schrift auf beiden Seiten)
static func blade(mb, o: Vector3, r: Vector3, n: Vector3, s: String, col: Color, size: float = 0.55) -> void:
	var solid := M.solid()
	var t := GFont.width(s, size)
	var bw := t + 0.5
	var bh := size + 0.45
	# Arm an der Wand
	obox(mb, solid, o + Vector3.UP * (bh * 0.5 - 0.04), r, n, 0.08, 0.08, 0.9, Color(0.12, 0.12, 0.13), 0.5, 0.6)
	# Kasten, quer zur Wand (Breitseite zeigt entlang der Strasse = Richtung r)
	var c := o + n * 0.9
	obox(mb, solid, c - r * (0.1), r, n, 0.2, bh, bw, Color(0.07, 0.07, 0.08), 0.6, 0.3)
	# Schrift senkrecht: Leserichtung von vorn nach hinten (n), also Ebene (n, up) mit Normale +r bzw. -r
	var lift := Vector3.UP * 0.22
	GFont.text(mb, solid, c + r * 0.11 + n * (0.25 + t) + lift, -n, Vector3.UP, s, size, col, 3.0, 0.3)
	GFont.text(mb, solid, c - r * 0.11 + n * 0.25 + lift, n, Vector3.UP, s, size, col, 3.0, 0.3)


# Strassenschild (gruen-weiss) mit Namen, nach aussen in Richtung n gerichtet.
static func street_sign(mb, c: Vector3, r: Vector3, n: Vector3, s: String) -> void:
	var solid := M.solid()
	var h := 0.2
	var tw := GFont.width(s, h)
	var w := tw + 0.3
	obox(mb, solid, c - r * (w * 0.5), r, n, w, h + 0.16, 0.04, Color(0.04, 0.32, 0.17), 0.4, 0.3)
	GFont.text(mb, solid, c - r * (tw * 0.5) + n * 0.045 + Vector3.UP * 0.08, r, Vector3.UP, s, h, Color(0.95, 0.95, 0.92), 0.0, 0.4, 0.2)


# Zufaellige LED-Flaechen ueber eine Fassadenseite verteilen (Times Square). y0..y1 = Hoehenbereich
static func facade_screens(mb, base: Vector3, dir: Vector3, n: Vector3, w: float, y0: float, y1: float, rng: RandomNumberGenerator, fill: float = 0.8) -> void:
	var ncol := maxi(1, int(w / 8.5))
	var gap := 0.5
	var cwid := (w - gap * (ncol + 1)) / ncol
	for c in range(ncol):
		var x := gap + c * (cwid + gap)
		var y := y0 + rng.randf_range(0.0, 3.0)
		while y < y1 - 3.5:
			var hh := rng.randf_range(3.5, 11.0)
			if y + hh > y1:
				hh = y1 - y
			if hh < 3.0:
				break
			if rng.randf() < fill:
				var hue: Color = NEON[rng.randi() % NEON.size()]
				screen(mb, base + dir * x + Vector3.UP * y, dir, n, cwid, hh, rng.randf(), hue)
			y += hh + rng.randf_range(0.5, 2.5)


# Dachtafel: grosse beleuchtete Reklame auf einem Gestell, zeigt nach n (und rueckwaertig dunkel)
static func roof_board(mb, o: Vector3, r: Vector3, n: Vector3, w: float, h: float, rng: RandomNumberGenerator) -> void:
	var solid := M.solid()
	var leg := 3.0
	var steel := Color(0.14, 0.14, 0.15)
	obox(mb, solid, o + r * 0.8, r, n, 0.35, leg, 0.35, steel, 0.6, 0.5)
	obox(mb, solid, o + r * (w - 1.15), r, n, 0.35, leg, 0.35, steel, 0.6, 0.5)
	obox(mb, solid, o + Vector3.UP * (leg * 0.5), r, n, w, 0.25, 0.3, steel, 0.6, 0.5)
	screen(mb, o + Vector3.UP * leg + n * 0.0, r, n, w, h, rng.randf(), NEON[rng.randi() % NEON.size()])
	# Scheinwerfer oben
	for k in range(int(w / 5.0)):
		obox(mb, solid, o + Vector3.UP * (leg + h + 0.1) + r * (1.5 + k * 5.0) + n * 0.5, r, n, 0.35, 0.25, 0.4, Color(0.1, 0.1, 0.11), 0.5, 0.5)
		obox(mb, solid, o + Vector3.UP * (leg + h + 0.25) + r * (1.55 + k * 5.0) + n * 0.8, r, n, 0.25, 0.1, 0.12, Color(1.0, 0.95, 0.8), 0.2, 0.0, 2.0)


# Zufallswort
static func word(rng: RandomNumberGenerator) -> String:
	return WORDS[rng.randi() % WORDS.size()]
