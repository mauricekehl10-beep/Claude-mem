extends RefCounted
# Strassenleben: Dampfschlote und Gullydampf, Zeitungsstand, Hot-Dog-Wagen, U-Bahn-Eingang, Absperrgitter, Muellsaecke,
# Poller, Baustellenhuetchen, Gehsteig-Schutzdach (Sidewalk Shed). Alles in block-lokalen Koordinaten (Gehweg y = 0.15).

const M = preload("res://scripts/city_mats.gd")
const Signs = preload("res://scripts/city_signs.gd")

const Y := 0.15  # Gehwegoberkante

static var steam_pts := []  # [Weltposition, Hoehe, Groesse]


static func reset() -> void:
	steam_pts.clear()


# Quader aus zwei Eckpunkten (achsenparallel)
static func abox(mb, mat: Material, a: Vector3, b: Vector3, col: Color, rough: float = 0.7, metal: float = 0.0, emis: float = 0.0) -> void:
	mb.sbox(mat, minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z), maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z), col, rough, metal, emis)


# Dampf an Weltposition vormerken (wird spaeter zu einem MultiMesh)
static func add_steam(world: Vector3, height: float, size: float) -> void:
	steam_pts.append([world, height, size])


static func cone(mb, mat: Material, p: Vector3) -> void:
	mb.scyl(mat, p, 0.2, 0.2, 0.04, Color(0.05, 0.05, 0.06), 8, 0.7, 0.0, 0.0, true)
	mb.scyl(mat, p + Vector3(0, 0.04, 0), 0.17, 0.03, 0.62, Color(1.0, 0.4, 0.05), 8, 0.5, 0.0)
	mb.scyl(mat, p + Vector3(0, 0.3, 0), 0.105, 0.085, 0.1, Color(0.95, 0.95, 0.92), 8, 0.4, 0.0, 0.0, false)


# Orange-weisser Dampfschlot (Con-Edison-Art) mit Dampf obendrauf
static func stack(mb, mat: Material, p: Vector3, world: Vector3) -> void:
	var orange := Color(0.95, 0.38, 0.06)
	mb.scyl(mat, p, 0.36, 0.30, 1.9, orange, 12, 0.5, 0.3)
	for k in range(3):
		mb.scyl(mat, p + Vector3(0, 0.3 + k * 0.55, 0), 0.325 - k * 0.012, 0.325 - k * 0.012, 0.16, Color(0.95, 0.95, 0.93), 12, 0.5, 0.2, 0.0, false)
	mb.scyl(mat, p + Vector3(0, 1.9, 0), 0.30, 0.46, 0.5, orange, 12, 0.5, 0.3)
	mb.scyl(mat, p + Vector3(0, 2.4, 0), 0.46, 0.46, 0.05, Color(0.1, 0.1, 0.1), 12, 0.6, 0.3)
	mb.scyl(mat, p, 0.5, 0.5, 0.06, Color(0.25, 0.25, 0.26), 12, 0.7, 0.2)
	add_steam(world + Vector3(0, 2.5, 0), 7.5, 1.5)


# Gullydeckel mit Dampf (in der Fahrbahn, Deckel liegt knapp ueber dem Asphalt)
static func manhole(mb, mat: Material, p: Vector3, world: Vector3) -> void:
	mb.scyl(mat, Vector3(p.x, 0.012, p.z), 0.5, 0.5, 0.012, Color(0.1, 0.1, 0.11), 16, 0.4, 0.7)
	mb.scyl(mat, Vector3(p.x, 0.024, p.z), 0.34, 0.34, 0.006, Color(0.04, 0.04, 0.045), 16, 0.5, 0.6)
	add_steam(world + Vector3(0, 0.1, 0), 5.0, 1.15)


static func bags(mb, mat: Material, p: Vector3, rng: RandomNumberGenerator) -> void:
	var cnt := rng.randi_range(2, 6)
	for i in range(cnt):
		var o := Vector3(rng.randf_range(-0.6, 0.6), 0.0, rng.randf_range(-0.35, 0.35))
		var r := rng.randf_range(0.28, 0.42)
		var col := Color(0.03, 0.03, 0.035) if rng.randf() < 0.8 else Color(0.08, 0.1, 0.35)
		mb.scyl(mat, p + o, r, r * 0.75, r * 1.5, col, 7, 0.25, 0.1)
		mb.scyl(mat, p + o + Vector3(0, r * 1.5, 0), r * 0.75, r * 0.15, r * 0.55, col, 7, 0.25, 0.1)


static func bollard(mb, mat: Material, p: Vector3) -> void:
	mb.scyl(mat, p, 0.11, 0.11, 0.95, Color(0.12, 0.12, 0.13), 10, 0.4, 0.6)
	mb.scyl(mat, p + Vector3(0, 0.95, 0), 0.11, 0.07, 0.07, Color(0.2, 0.2, 0.22), 10, 0.4, 0.6)
	mb.scyl(mat, p + Vector3(0, 0.7, 0), 0.115, 0.115, 0.1, Color(1.0, 0.82, 0.1), 10, 0.4, 0.2, 0.0, false)


# Polizei-Absperrgitter (2 m), t = Richtung entlang des Gitters
static func barricade(mb, mat: Material, p: Vector3, t: Vector3) -> void:
	var iron_f := M.iron(2, Color(0.55, 0.57, 0.6))
	var a := p - t * 1.0
	var b := p + t * 1.0
	mb.quad(iron_f, a + Vector3(0, 0.1, 0), b + Vector3(0, 0.1, 0), b + Vector3(0, 1.1, 0), a + Vector3(0, 1.1, 0), t.cross(Vector3.UP), 0.0, 2.0, 0.0, 1.0)
	abox(mb, mat, a - Vector3(0.03, 0, 0.03) * 1.0 + Vector3(0, 0.0, 0), a + Vector3(0.03, 1.1, 0.03), Color(0.5, 0.52, 0.55), 0.4, 0.7)
	abox(mb, mat, b - Vector3(0.03, 0, 0.03), b + Vector3(0.03, 1.1, 0.03), Color(0.5, 0.52, 0.55), 0.4, 0.7)
	abox(mb, mat, a + Vector3(-0.03, 1.05, -0.03), b + Vector3(0.03, 1.12, 0.03), Color(0.5, 0.52, 0.55), 0.4, 0.7)
	# Fuesse quer
	var nrm := t.cross(Vector3.UP)
	abox(mb, mat, a - nrm * 0.35 + Vector3(0, 0, 0), a + nrm * 0.35 + Vector3(0, 0.05, 0) + t * 0.05, Color(0.5, 0.52, 0.55), 0.4, 0.7)
	abox(mb, mat, b - nrm * 0.35 - t * 0.05, b + nrm * 0.35 + Vector3(0, 0.05, 0), Color(0.5, 0.52, 0.55), 0.4, 0.7)


# Zeitungsstand: Kiosk mit Dach, Zeitschriften-Regal, Schild. n = Richtung zur Strasse
static func newsstand(mb, mat: Material, p: Vector3, n: Vector3, t: Vector3, col: Color, rng: RandomNumberGenerator) -> void:
	var hx := absf(t.x) * 1.1 + absf(n.x) * 0.8
	var hz := absf(t.z) * 1.1 + absf(n.z) * 0.8
	abox(mb, mat, p + Vector3(-hx, 0.0, -hz), p + Vector3(hx, 0.25, hz), Color(0.1, 0.1, 0.11), 0.6, 0.3)
	abox(mb, mat, p + Vector3(-hx + 0.05, 0.25, -hz + 0.05), p + Vector3(hx - 0.05, 2.1, hz - 0.05), col, 0.45, 0.3)
	abox(mb, mat, p + Vector3(-hx - 0.12, 2.1, -hz - 0.12), p + Vector3(hx + 0.12, 2.28, hz + 0.12), col.darkened(0.3), 0.5, 0.3)
	# Auslage zur Strasse: bunte Zeitschriften
	var front := p + n * (absf(n.x) * hx + absf(n.z) * hz)
	var mags := 6
	for k in range(mags):
		var tc := Color.from_hsv(rng.randf(), rng.randf_range(0.5, 0.9), rng.randf_range(0.7, 1.0))
		var off := t * (-0.85 + k * 0.34)
		abox(mb, mat, front + off - t * 0.14 + Vector3(0, 0.9, 0) + n * 0.0, front + off + t * 0.14 + Vector3(0, 1.45, 0) + n * 0.05, tc, 0.5)
	for k in range(5):
		var tc2 := Color.from_hsv(rng.randf(), rng.randf_range(0.3, 0.8), rng.randf_range(0.7, 1.0))
		var off2 := t * (-0.7 + k * 0.34)
		abox(mb, mat, front + off2 - t * 0.14 + Vector3(0, 1.5, 0), front + off2 + t * 0.14 + Vector3(0, 1.95, 0) + n * 0.05, tc2, 0.5)
	# Leuchtkasten oben
	abox(mb, mat, front - t * 0.9 + Vector3(0, 2.3, 0) - n * 0.1, front + t * 0.9 + Vector3(0, 2.7, 0) + n * 0.1, Color(1.0, 0.85, 0.3), 0.3, 0.0, 1.4)


# Hot-Dog-Wagen mit Sonnenschirm
static func hotdog(mb, mat: Material, p: Vector3, n: Vector3, t: Vector3, rng: RandomNumberGenerator) -> void:
	var hx := absf(t.x) * 0.9 + absf(n.x) * 0.5
	var hz := absf(t.z) * 0.9 + absf(n.z) * 0.5
	abox(mb, mat, p + Vector3(-hx, 0.35, -hz), p + Vector3(hx, 1.0, hz), Color(0.8, 0.8, 0.82), 0.3, 0.7)
	abox(mb, mat, p + Vector3(-hx - 0.04, 1.0, -hz - 0.04), p + Vector3(hx + 0.04, 1.06, hz + 0.04), Color(0.7, 0.7, 0.72), 0.3, 0.8)
	abox(mb, mat, p + Vector3(-hx + 0.1, 1.06, -hz + 0.1), p + Vector3(-hx + 0.45 + absf(t.x) * 0.0, 1.35, hz - 0.1), Color(0.75, 0.75, 0.78), 0.3, 0.8)
	var wc := Color(0.08, 0.08, 0.09)
	for sx in [-1.0, 1.0]:
		mb.scyl(mat, p + t * (sx * hx * 0.75) + Vector3(0, 0.0, 0) + n * 0.0, 0.3, 0.3, 0.08, wc, 10, 0.6, 0.0, 0.0, true)
	# Mast und Schirm
	var top := p + Vector3(0, 1.06, 0)
	mb.scyl(mat, top, 0.03, 0.03, 1.5, Color(0.7, 0.7, 0.72), 6, 0.4, 0.7)
	var c1 := Color(1.0, 0.85, 0.1) if rng.randf() < 0.5 else Color(0.1, 0.3, 0.8)
	mb.scyl(mat, top + Vector3(0, 1.45, 0), 1.35, 0.12, 0.45, c1, 12, 0.7)
	mb.scyl(mat, top + Vector3(0, 1.4, 0), 1.37, 1.37, 0.06, Color(0.9, 0.9, 0.9), 12, 0.7, 0.0, 0.0, false)


# U-Bahn-Eingang: gruene Gelaender, dunkle Treppe, Kugelleuchten. n = zur Strasse, t = entlang
static func subway(mb, mat: Material, p: Vector3, n: Vector3, t: Vector3) -> void:
	var green := Color(0.04, 0.22, 0.12)
	var hw := 0.75
	var hl := 1.2
	var iron := M.iron(1, green)
	# Treppenschacht: dunkle Flaeche mit hellen Stufen
	abox(mb, mat, p + t * -hw * 0.9 - n * hl * 0.95 + Vector3(0, 0.0, 0), p + t * hw * 0.9 + n * hl * 0.95 + Vector3(0, 0.03, 0), Color(0.02, 0.02, 0.025), 0.8)
	for k in range(5):
		var o := -hl * 0.8 + k * hl * 0.4
		abox(mb, mat, p + t * -hw * 0.85 + n * o + Vector3(0, 0.03, 0), p + t * hw * 0.85 + n * (o + 0.12) + Vector3(0, 0.05, 0), Color(0.2, 0.2, 0.22), 0.8)
	# Gelaender an drei Seiten (zur Strasse offen)
	var a1 := p - t * hw - n * hl
	var a2 := p + t * hw - n * hl
	var b1 := p - t * hw + n * hl
	var b2 := p + t * hw + n * hl
	var nl := t.cross(Vector3.UP)
	mb.quad(iron, a1, a2, a2 + Vector3(0, 1.1, 0), a1 + Vector3(0, 1.1, 0), -n, 0.0, 2.0 * hw, 0.0, 1.0)
	mb.quad(iron, a1, b1, b1 + Vector3(0, 1.1, 0), a1 + Vector3(0, 1.1, 0), -t, 0.0, 2.0 * hl, 0.0, 1.0)
	mb.quad(iron, a2, b2, b2 + Vector3(0, 1.1, 0), a2 + Vector3(0, 1.1, 0), t, 0.0, 2.0 * hl, 0.0, 1.0)
	for c in [a1, a2, b1, b2]:
		abox(mb, mat, c - Vector3(0.05, 0, 0.05), c + Vector3(0.05, 1.2, 0.05), green, 0.4, 0.4)
	# Leuchtkugeln auf hohen Pfosten (gruen/weiss)
	for c in [b1, b2]:
		abox(mb, mat, c - Vector3(0.04, 0, 0.04), c + Vector3(0.04, 2.4, 0.04), green, 0.4, 0.4)
		mb.scyl(mat, c + Vector3(0, 2.4, 0), 0.16, 0.16, 0.3, Color(0.4, 1.0, 0.5), 10, 0.2, 0.0, 1.6)


# Gehsteig-Schutzdach (Baustelle): gruenes Dach ueber dem Gehweg, Pfosten am Bordstein. Gibt Pfostenpositionen zurueck.
static func shed(mb, mat: Material, t: Vector3, n: Vector3, t0: float, t1: float, rng: RandomNumberGenerator) -> Array:
	var posts := []
	var lat0 := 26.1
	var lat1 := 29.5
	var green := Color(0.09, 0.30, 0.20) if rng.randf() < 0.6 else Color(0.08, 0.2, 0.36)
	var hgt := 3.4
	# Dachplatte
	var a := t * t0 + n * lat0
	var b := t * t1 + n * lat0
	var c := t * t1 + n * lat1
	var d := t * t0 + n * lat1
	abox(mb, mat, a + Vector3(0, Y + hgt, 0), c + Vector3(0, Y + hgt + 0.18, 0), green.lightened(0.05), 0.8)
	abox(mb, mat, d + Vector3(0, Y + hgt - 0.5, 0) - n * 0.03 - t * 0.03, c + Vector3(0, Y + hgt + 0.25, 0) + n * 0.05 + t * 0.03, green, 0.7)
	abox(mb, mat, a + Vector3(0, Y + hgt - 0.5, 0) - t * 0.05, d + Vector3(0, Y + hgt + 0.0, 0) + t * 0.0 + t * 0.03, green.darkened(0.1), 0.7)
	abox(mb, mat, b + Vector3(0, Y + hgt - 0.5, 0) - t * 0.03, c + Vector3(0, Y + hgt, 0) + t * 0.05, green.darkened(0.1), 0.7)
	# Pfosten (unten weiss/gruen), Querstreben und Leuchten
	var nposts := maxi(2, int((t1 - t0) / 3.2) + 1)
	for k in range(nposts):
		var tt := t0 + 0.2 + (t1 - t0 - 0.4) * float(k) / (nposts - 1)
		var pp := t * tt + n * (lat1 - 0.15)
		abox(mb, mat, pp - Vector3(0.07, 0, 0.07) + Vector3(0, Y, 0), pp + Vector3(0.07, 0, 0.07) + Vector3(0, Y + hgt, 0), Color(0.12, 0.3, 0.2).lightened(0.1), 0.7)
		abox(mb, mat, pp - Vector3(0.075, 0, 0.075) + Vector3(0, Y + 0.4, 0), pp + Vector3(0.075, 0, 0.075) + Vector3(0, Y + 0.75, 0), Color(0.9, 0.9, 0.88), 0.7)
		posts.append(pp)
		# Streben zur Wand
		abox(mb, mat, t * tt + n * lat0 + Vector3(-0.04, Y + hgt - 0.3, -0.04), t * tt + n * (lat1 - 0.1) + Vector3(0.04, Y + hgt - 0.2, 0.04), Color(0.3, 0.3, 0.32), 0.6, 0.5)
		# Lampe unter dem Dach
		var lp := t * (tt + (t1 - t0) / nposts * 0.5) + n * (lat0 + 1.6)
		abox(mb, mat, lp - Vector3(0.12, 0, 0.12) + Vector3(0, Y + hgt - 0.12, 0), lp + Vector3(0.12, 0, 0.12) + Vector3(0, Y + hgt - 0.02, 0), Color(1.0, 0.9, 0.7), 0.3, 0.0, 2.0)
	return posts


# Alle vorgemerkten Dampfwolken als ein MultiMesh (Billboard-Puffs, im Shader animiert)
static func commit_steam(parent: Node3D) -> void:
	if steam_pts.is_empty():
		return
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	quad.material = M.steam()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	var per := 7
	mm.instance_count = steam_pts.size() * per
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var i := 0
	for sp in steam_pts:
		for k in range(per):
			mm.set_instance_transform(i, Transform3D(Basis(), sp[0]))
			mm.set_instance_custom_data(i, Color((k + rng.randf() * 0.6) / per, rng.randf_range(0.8, 1.2), float(sp[2]) * rng.randf_range(0.8, 1.15), float(sp[1])))
			i += 1
	mm.custom_aabb = AABB(Vector3(-700, -2, -700), Vector3(1400, 24, 1400))
	var mi := MultiMeshInstance3D.new()
	mi.name = "Steam"
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


# Fassadengeruest mit Netz: Rohre, Querstangen, Bohlen. o = linke untere Ecke des Abschnitts an der Wand (y = Starthoehe),
# r = Richtung (nach rechts), n = Aussennormale, w = Breite, h = Hoehe
static func scaffold(mb, o: Vector3, r: Vector3, n: Vector3, w: float, h: float, col: Color) -> void:
	var solid := M.solid()
	var pipe := Color(0.62, 0.64, 0.66)
	var out := 1.0
	var npole := int(w / 2.4) + 1
	var step := w / maxf(1.0, npole - 1.0)
	for i in range(npole):
		var base := o + r * (i * step) + n * out
		mb.tube(solid, base, base + Vector3(0, h, 0), 0.045, 0.045, 5, pipe, 0.4, 0.7)
		# Anker zur Wand alle 4 m
		var y := 2.0
		while y < h:
			mb.tube(solid, base + Vector3(0, y, 0), base + Vector3(0, y, 0) - n * out, 0.03, 0.03, 4, pipe, 0.4, 0.7)
			y += 4.0
	# Laengsstangen alle 2 m und Bohlenbelag alle 4 m
	var y2 := 0.0
	while y2 <= h:
		mb.tube(solid, o + Vector3(0, y2, 0) + n * out, o + r * w + Vector3(0, y2, 0) + n * out, 0.04, 0.04, 5, pipe, 0.4, 0.7)
		if int(y2 / 2.0) % 2 == 0:
			var p0 := o + Vector3(0, y2 + 0.03, 0)
			Signs.obox(mb, solid, p0 + n * 0.1, r, n, w, 0.05, out - 0.05, Color(0.42, 0.3, 0.18), 0.9)
		y2 += 2.0
	# Netz / Plane an der Aussenseite (abwechselnd gruenes Netz und blaue Plane)
	var mesh_col := Color(0.22, 0.36, 0.24)
	var q := o + n * (out + 0.06) + Vector3(0, 1.0, 0)
	mb.quad(M.iron(3, mesh_col), q, q + r * w, q + r * w + Vector3(0, h - 1.0, 0), q + Vector3(0, h - 1.0, 0), n, 0.0, w, 0.0, h - 1.0)
	if col.a > 0.5:
		var q2 := o + n * (out + 0.05) + Vector3(0, h * 0.35, 0)
		mb.sq(solid, q2, q2 + r * (w * 0.4), q2 + r * (w * 0.4) + Vector3(0, h * 0.4, 0), q2 + Vector3(0, h * 0.4, 0), Color(col.r, col.g, col.b), 0.6)
