extends RefCounted
# Grosser Park (Central-Park-Art) aus sechs Bloecken: Teich mit Steinbruecke, Great Lawn, Waldstueck, Felsen (Manhattan-Schiefer),
# Brunnen-Promenade, Karussell. Rasen mit Wegen (Shader), Mauer mit Eingaengen, Baeume, Baenke, Laternen.

const MB = preload("res://scripts/city_mesh.gd")
const M = preload("res://scripts/city_mats.gd")
const Tex = preload("res://scripts/city_tex.gd")

static var _lawn: Array = []


static func lawn_material(variant: int) -> ShaderMaterial:
	while _lawn.size() <= variant:
		_lawn.append(null)
	if _lawn[variant] == null:
		var m := ShaderMaterial.new()
		m.shader = load("res://scripts/city_lawn.gdshader")
		m.set_shader_parameter("n_blotch", Tex.noise("blotch"))
		m.set_shader_parameter("n_grain", Tex.noise("grain"))
		m.set_shader_parameter("variant", variant)
		_lawn[variant] = m
	return _lawn[variant]


# Art des Parkblocks: pond, woods, lawn, rambles, carousel, mall
static func profile(ix: int, iz: int) -> String:
	if ix == -1 and iz == 0:
		return "pond"
	if ix == -2 and iz == -1:
		return "woods"
	if ix == -1 and iz == -1:
		return "lawn"
	if ix == -2 and iz == 0:
		return "rambles"
	if ix == -2 and iz == 1:
		return "carousel"
	return "mall"


func build(parent: Node3D, cx: float, cz: float, ix: int, iz: int, props) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(ix, iz)) + 77
	var prof := profile(ix, iz)
	var node := Node3D.new()
	node.name = "Park_%d_%d" % [ix, iz]
	node.position = Vector3(cx, 0, cz)
	parent.add_child(node)
	var variant := 0
	match prof:
		"woods", "mall":
			variant = 1
		"rambles":
			variant = 2
	var mb := MB.new()
	var solid := M.solid()
	var y := 0.17
	var h := 26.0
	# Rasenflaeche (UV = lokale Meter)
	mb.quad(lawn_material(variant), Vector3(-h, y, h), Vector3(h, y, h), Vector3(h, y, -h), Vector3(-h, y, -h), Vector3.UP, -h, h, h, -h)
	var body := StaticBody3D.new()
	node.add_child(body)
	walls(mb, solid, body, variant)
	var pond_pts := PackedVector2Array()
	if prof == "pond":
		pond_pts = pond(mb, solid, body, rng)
		bridge(mb, solid, body)
		for i in range(pond_pts.size()):
			if i % 3 == 0 and rng.randf() < 0.85:
				var p: Vector2 = pond_pts[i] * 1.03
				rock(mb, solid, Vector3(p.x, 0.1, p.y), Vector3(rng.randf_range(0.7, 1.6), rng.randf_range(0.5, 1.0), rng.randf_range(0.7, 1.6)), rng)
	elif prof == "mall":
		fountain(mb, solid)
	elif prof == "carousel":
		carousel(mb, solid, body)
	# Felsen (Schiefer) als Gruppen
	var nrock := 8 if prof == "rambles" else (5 if prof == "woods" else 2)
	for g in range(nrock):
		var gc := Vector2(rng.randf_range(-21, 21), rng.randf_range(-21, 21))
		if gc.length() < 12.0 or on_path(gc, variant, 3.0) or pond_hit(pond_pts, gc, 3.0):
			continue
		for k in range(rng.randi_range(1, 4)):
			var q := gc + Vector2(rng.randfn(), rng.randfn()) * 1.5
			var sc := Vector3(rng.randf_range(0.9, 2.6), rng.randf_range(0.7, 1.9), rng.randf_range(0.9, 2.4))
			rock(mb, solid, Vector3(q.x, 0.15, q.y), sc, rng)
			if sc.x > 1.8:
				var cs := CollisionShape3D.new()
				var sp := SphereShape3D.new()
				sp.radius = sc.x * 0.8
				cs.shape = sp
				cs.position = Vector3(q.x, 0.15 + sc.y * 0.2, q.y)
				body.add_child(cs)
	# Laternen an den Wegen und Baenke
	for a in range(4):
		var ang := a * PI * 0.5 + (PI * 0.25 if variant == 1 else 0.0)
		var d := Vector3(cos(ang), 0, sin(ang))
		var side := Vector3(-d.z, 0, d.x)
		var pp := d * 11.5 + side * 2.3
		if not pond_hit(pond_pts, Vector2(pp.x, pp.z), 2.0):
			props.park_lamp(mb, solid, pp)
		var bp := d * 14.5 - side * 2.6
		if not pond_hit(pond_pts, Vector2(bp.x, bp.z), 2.0):
			props.bench(mb, solid, bp, side if rng.randf() < 0.5 else -side)
			props.bench(mb, solid, d * 14.5 + side * 2.6, -side)
	mb.instance(node, "ParkMesh")
	# Baeume: nicht auf Wegen und nicht im Brunnenplatz
	var count := 0
	var tries := 0
	var want := 22
	match prof:
		"woods":
			want = 70
		"rambles":
			want = 46
		"lawn":
			want = 14
		"pond":
			want = 30
		"carousel":
			want = 26
		"mall":
			want = 30
	while count < want and tries < 600:
		tries += 1
		var p := Vector2(rng.randf_range(-24.0, 24.0), rng.randf_range(-24.0, 24.0))
		if p.length() < 8.0 and prof != "woods":
			continue
		if on_path(p, variant, 0.8) or pond_hit(pond_pts, p, 1.5):
			continue
		if prof == "lawn" and p.length() < 17.0:
			continue  # offene Wiese in der Mitte
		if prof == "carousel" and p.length() < 9.0:
			continue
		var kind := "round"
		var r := rng.randf()
		if r < 0.2:
			kind = "conifer"
		elif r < 0.4:
			kind = "oval"
		elif r < 0.55:
			kind = "maple"
		elif r < 0.65:
			kind = "birch"
		props.trees.add(kind, Vector3(cx + p.x, 0.17, cz + p.y), rng, rng.randf_range(1.0, 1.45))
		count += 1
	# Straeucher
	for i in range(14):
		var p := Vector2(rng.randf_range(-22, 22), rng.randf_range(-22, 22))
		if p.length() < 9.0 or on_path(p, variant, 0.8) or pond_hit(pond_pts, p, 1.2):
			continue
		props.trees.add("bush", Vector3(cx + p.x, 0.17, cz + p.y), rng, rng.randf_range(0.9, 1.6))
	# Gras-Buescheln auf dem Rasen (nicht auf den Wegen)
	var ntuft := 900 if prof != "woods" else 500
	for i in range(ntuft):
		var p := Vector2(rng.randf_range(-24.5, 24.5), rng.randf_range(-24.5, 24.5))
		if p.length() < 6.0 or on_path(p, variant, 0.5) or pond_hit(pond_pts, p, 0.6):
			continue
		props.trees.add("tuft", Vector3(cx + p.x, 0.17, cz + p.y), rng, rng.randf_range(0.7, 1.3))
	for g in range(7):
		var gc := Vector2(rng.randf_range(-21, 21), rng.randf_range(-21, 21))
		if gc.length() < 10.0 or on_path(gc, variant, 2.5) or pond_hit(pond_pts, gc, 3.0):
			continue
		for i in range(12):
			var p := gc + Vector2(rng.randfn(), rng.randfn()) * 1.3
			if not on_path(p, variant, 0.5):
				props.trees.add("flowers", Vector3(cx + p.x, 0.17, cz + p.y), rng, rng.randf_range(0.8, 1.3))
	# Kollision: flache Rasenflaeche (begehbar), Brunnenbecken
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(52, 0.2, 52)
	cs.shape = bs
	cs.position = Vector3(0, 0.07, 0)
	body.add_child(cs)
	if prof == "mall":
		var fc := CollisionShape3D.new()
		var fs := CylinderShape3D.new()
		fs.radius = 4.4
		fs.height = 0.8
		fc.shape = fs
		fc.position = Vector3(0, 0.5, 0)
		body.add_child(fc)


# Liegt p (Meter, Blockmitte = 0) auf einem Weg oder Platz? (wie im Rasen-Shader, mit Rand m)
static func on_path(p: Vector2, variant: int, m: float) -> bool:
	var d := p.length() - 8.5
	if variant == 0:
		d = minf(minf(absf(p.x), absf(p.y)) - 1.6, d)
	elif variant == 1:
		d = minf(minf(absf(p.x - p.y), absf(p.x + p.y)) * 0.7071 - 1.6, d)
	else:
		d = minf(minf(absf(p.length() - 15.0) - 1.5, minf(absf(p.x), absf(p.y)) - 1.2), d)
	return d < m


# Teich: unregelmaessige Ellipse, Wasserflaeche knapp ueber dem Rasen, Randstein. Gibt den Umriss zurueck.
func pond(mb, solid, body: StaticBody3D, rng: RandomNumberGenerator) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 28
	var ph1 := rng.randf() * TAU
	var ph2 := rng.randf() * TAU
	for i in range(n):
		var a := TAU * i / n
		var rr := 1.0 + 0.10 * sin(a * 3.0 + ph1) + 0.06 * sin(a * 5.0 + ph2)
		pts.append(Vector2(cos(a) * 11.0 * rr, sin(a) * 12.5 * rr))
	var wm := M.water()
	var c := Vector3(0, 0.21, 0)
	var stone := Color(0.45, 0.43, 0.38)
	for i in range(n):
		var p0: Vector2 = pts[i]
		var p1: Vector2 = pts[(i + 1) % n]
		mb.tri(wm, c, Vector3(p1.x, 0.21, p1.y), Vector3(p0.x, 0.21, p0.y), Vector3.UP)
		mb.tube(solid, Vector3(p0.x, 0.2, p0.y), Vector3(p1.x, 0.2, p1.y), 0.3, 0.3, 6, stone, 0.9)
	# Kollisions-Prisma (man kann nicht ins Wasser laufen)
	var hull := PackedVector3Array()
	for p in pts:
		hull.append(Vector3(p.x, 0.0, p.y))
		hull.append(Vector3(p.x, 1.2, p.y))
	var cs := CollisionShape3D.new()
	var sh := ConvexPolygonShape3D.new()
	sh.points = hull
	cs.shape = sh
	body.add_child(cs)
	return pts


static func pond_hit(pts: PackedVector2Array, p: Vector2, margin: float) -> bool:
	if pts.is_empty():
		return false
	if Geometry2D.is_point_in_polygon(p, pts):
		return true
	for q in pts:
		if q.distance_to(p) < margin + 1.0:
			return true
	return false


# Steinbruecke ueber den Teich (Weg in z-Richtung bei x = 0): flach gewoelbt, mit Bruestung
func bridge(mb, solid, body: StaticBody3D) -> void:
	var stone := Color(0.52, 0.49, 0.44)
	var w := 3.2
	var n := 8
	var z0 := -14.0
	var z1 := 14.0
	for i in range(n):
		var za := lerpf(z0, z1, float(i) / n)
		var zb := lerpf(z0, z1, float(i + 1) / n)
		var ya := 0.25 + 1.1 * sin(PI * float(i) / n)
		var yb := 0.25 + 1.1 * sin(PI * float(i + 1) / n)
		var ym := (ya + yb) * 0.5
		mb.quad(solid, Vector3(-w * 0.5, yb, zb), Vector3(w * 0.5, yb, zb), Vector3(w * 0.5, ya, za), Vector3(-w * 0.5, ya, za), Vector3.UP, 0.0, 0.0, 0.0, 0.0, Vector2(0.85, 0.0), stone.lightened(0.05))
		mb.sbox(solid, -w * 0.5, minf(ya, yb) - 0.4, za, w * 0.5, minf(ya, yb), zb, stone.darkened(0.25), 0.9)
		for sx in [-1.0, 1.0]:
			var xo: float = sx * (w * 0.5 - 0.2)
			mb.sbox(solid, xo - 0.2, minf(ya, yb), za, xo + 0.2, maxf(ya, yb) + 0.8, zb, stone.darkened(0.05), 0.85)
		# Kollision des Deckstuecks (schraeger Block) und der Bruestungen
		var hull := PackedVector3Array()
		for sx in [-1.0, 1.0]:
			hull.append(Vector3(sx * w * 0.5, ya - 0.4, za))
			hull.append(Vector3(sx * w * 0.5, ya, za))
			hull.append(Vector3(sx * w * 0.5, yb - 0.4, zb))
			hull.append(Vector3(sx * w * 0.5, yb, zb))
		var cs := CollisionShape3D.new()
		var sh := ConvexPolygonShape3D.new()
		sh.points = hull
		cs.shape = sh
		body.add_child(cs)
		for sx in [-1.0, 1.0]:
			var cs2 := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(0.4, 1.0, zb - za)
			cs2.shape = bs
			cs2.position = Vector3(sx * (w * 0.5 - 0.2), ym + 0.9, (za + zb) * 0.5)
			body.add_child(cs2)
	# Pfeiler unter der Bruecke
	mb.sbox(solid, -w * 0.5, 0.1, -9.0, w * 0.5, 0.9, -7.6, stone.darkened(0.2), 0.9)
	mb.sbox(solid, -w * 0.5, 0.1, 7.6, w * 0.5, 0.9, 9.0, stone.darkened(0.2), 0.9)


# Felsbrocken (verformter Ikosaeder, flach schattiert)
static func rock(mb, mat: Material, c: Vector3, size: Vector3, rng: RandomNumberGenerator) -> void:
	var t := (1.0 + sqrt(5.0)) * 0.5
	var v := [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var f := [0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8, 3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, 4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1]
	var pts := []
	for i in range(v.size()):
		var p: Vector3 = (v[i] as Vector3).normalized()
		p *= rng.randf_range(0.82, 1.15)
		pts.append(Vector3(p.x * size.x, p.y * size.y, p.z * size.z) + c)
	var gv := rng.randf_range(0.8, 1.15)
	var base_col := Color(0.40, 0.40, 0.38).lerp(Color(0.34, 0.38, 0.30), rng.randf() * 0.5)
	var cen := Vector3.ZERO
	for p in pts:
		cen += p
	cen /= pts.size()
	for i in range(0, f.size(), 3):
		var a: Vector3 = pts[f[i]]
		var b: Vector3 = pts[f[i + 1]]
		var d: Vector3 = pts[f[i + 2]]
		var n := (b - a).cross(d - a).normalized()
		var fc := (a + b + d) / 3.0
		if n.dot(fc - cen) < 0.0:
			var tmp := b
			b = d
			d = tmp
			n = -n
		var shade := (0.85 + 0.25 * maxf(0.0, n.y) + rng.randf_range(-0.05, 0.05)) * gv
		mb.tri(mat, a, b, d, n, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2(0.95, 0.0), Color(base_col.r * shade, base_col.g * shade, base_col.b * shade))


# Niedrige Parkmauer mit Eingaengen (4 Seiten)
func walls(mb, solid, body: StaticBody3D, variant: int) -> void:
	var stone := Color(0.50, 0.47, 0.42)
	for s in range(4):
		var segs := [[-25.6, -2.4], [2.4, 25.6]]
		if variant == 1:
			segs = [[-21.5, 21.5]]  # diagonale Wege: Eingaenge an den Ecken
		for sg in segs:
			var u0: float = sg[0]
			var u1: float = sg[1]
			var a := _w2(s, u0, 25.5)
			var b := _w2(s, u1, 26.0)
			mb.sbox(solid, minf(a.x, b.x), 0.1, minf(a.z, b.z), maxf(a.x, b.x), 0.95, maxf(a.z, b.z), stone, 0.9)
			var a2 := _w2(s, u0 - 0.1, 25.3)
			var b2 := _w2(s, u1 + 0.1, 26.2)
			mb.sbox(solid, minf(a2.x, b2.x), 0.95, minf(a2.z, b2.z), maxf(a2.x, b2.x), 1.07, maxf(a2.z, b2.z), stone.lightened(0.1), 0.85)
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(maxf(absf(a.x - b.x), 0.5), 0.95, maxf(absf(a.z - b.z), 0.5))
			cs.shape = bs
			var mid := (a + b) * 0.5
			cs.position = Vector3(mid.x, 0.55, mid.z)
			body.add_child(cs)


static func _w2(side: int, u: float, v: float) -> Vector3:
	match side:
		0:
			return Vector3(u, 0, v)
		1:
			return Vector3(-u, 0, -v)
		2:
			return Vector3(v, 0, -u)
	return Vector3(-v, 0, u)


func carousel(mb, solid, body: StaticBody3D) -> void:
	var r := 4.2
	mb.scyl(solid, Vector3(0, 0.17, 0), r + 0.6, r + 0.6, 0.25, Color(0.55, 0.53, 0.5), 24, 0.8)
	mb.scyl(solid, Vector3(0, 0.42, 0), r, r, 0.1, Color(0.35, 0.2, 0.12), 24, 0.7)
	mb.scyl(solid, Vector3(0, 0.5, 0), 0.4, 0.3, 4.2, Color(0.8, 0.7, 0.3), 10, 0.4, 0.5)
	for k in range(8):
		var a := TAU * k / 8.0
		var px := cos(a) * (r - 0.4)
		var pz := sin(a) * (r - 0.4)
		mb.scyl(solid, Vector3(px, 0.5, pz), 0.06, 0.06, 3.6, Color(0.85, 0.75, 0.3), 6, 0.3, 0.7)
		mb.sbox(solid, px - 0.35, 1.0 + (k % 2) * 0.4, pz - 0.35, px + 0.35, 1.5 + (k % 2) * 0.4, pz + 0.35, Color.from_hsv(k / 8.0, 0.4, 0.95), 0.5)
	# gestreiftes Dach
	var top := Vector3(0, 5.8, 0)
	for k in range(12):
		var a0 := TAU * k / 12.0
		var a1 := TAU * (k + 1) / 12.0
		var col := Color(0.85, 0.15, 0.15) if k % 2 == 0 else Color(0.95, 0.92, 0.85)
		var p0 := Vector3(cos(a0) * (r + 0.5), 4.2, sin(a0) * (r + 0.5))
		var p1 := Vector3(cos(a1) * (r + 0.5), 4.2, sin(a1) * (r + 0.5))
		mb.tri(solid, p1, p0, top, (p0 - p1).cross(top - p1).normalized(), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2(0.7, 0.0), col)
	mb.scyl(solid, Vector3(0, 5.8, 0), 0.08, 0.02, 1.0, Color(0.9, 0.8, 0.3), 6, 0.3, 0.7)
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r + 0.6
	sh.height = 0.6
	cs.shape = sh
	cs.position = Vector3(0, 0.4, 0)
	body.add_child(cs)


func fountain(mb, solid) -> void:
	var stone := Color(0.62, 0.6, 0.56)
	mb.scyl(solid, Vector3(0, 0.17, 0), 4.5, 4.4, 0.75, stone, 28, 0.8)
	mb.scyl(solid, Vector3(0, 0.92, 0), 4.5, 4.5, 0.12, stone.lightened(0.1), 28, 0.7, 0.0, 0.0, false)
	mb.scyl(solid, Vector3(0, 0.80, 0), 3.9, 3.9, 0.04, Color(0.12, 0.3, 0.38), 28, 0.04, 0.1)
	mb.scyl(solid, Vector3(0, 0.84, 0), 0.5, 0.35, 2.0, stone, 12, 0.8)
	mb.scyl(solid, Vector3(0, 2.4, 0), 1.6, 0.4, 0.5, stone, 16, 0.8)
	mb.scyl(solid, Vector3(0, 2.85, 0), 0.25, 0.1, 1.2, Color(0.7, 0.85, 0.95), 8, 0.1, 0.0, 0.4)
