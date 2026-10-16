extends RefCounted
# Strassenmoebel: Laternen, Ampeln, Hydranten, Muelleimer, Baenke, Parkuhren, Bushaltestellen, Baeume am Strassenrand.

const MB = preload("res://scripts/city_mesh.gd")
const M = preload("res://scripts/city_mats.gd")
const Trees = preload("res://scripts/city_trees.gd")

var trees := Trees.new()
var rng := RandomNumberGenerator.new()

const SIDES := [
	[Vector3(0, 0, 1), Vector3(1, 0, 0)],
	[Vector3(0, 0, -1), Vector3(-1, 0, 0)],
	[Vector3(1, 0, 0), Vector3(0, 0, -1)],
	[Vector3(-1, 0, 0), Vector3(0, 0, 1)],
]

const POLE := Color(0.30, 0.34, 0.33)
const SIDEWALK_Y := 0.15


func block_props(parent: Node3D, cx: float, cz: float, zone: int, ix: int, iz: int, solid_mat: Material) -> void:
	rng.seed = hash(Vector2i(ix, iz)) + 991
	var mb := MB.new()
	var near := zone <= 2
	var blockers := []
	for si in range(4):
		var n: Vector3 = SIDES[si][0]
		var t: Vector3 = SIDES[si][1]
		# Laternen und Baeume im Wechsel entlang des Bordsteins
		for k in range(7):
			var tt := -18.0 + 6.0 * k
			var base_pos := t * tt
			if k % 2 == 0:
				lamp(mb, solid_mat, base_pos + n * 29.0, n)
				var lpos := base_pos + n * 29.0
				blockers.append([lpos, 0.18])
			else:
				var kind := "round" if rng.randf() < 0.7 else "oval"
				var tp := base_pos + n * 28.5
				trees.add(kind, Vector3(cx + tp.x, SIDEWALK_Y, cz + tp.z), rng)
				blockers.append([tp, 0.3])
				mb.sbox(solid_mat, tp.x - 0.6, SIDEWALK_Y, tp.z - 0.6, tp.x + 0.6, SIDEWALK_Y + 0.025, tp.z + 0.6, Color(0.12, 0.09, 0.07), 0.95)
		if not near:
			continue
		# Parkuhren
		for k in range(8):
			if rng.randf() < 0.3:
				continue
			var tt := -22.75 + 6.5 * k + 0.0
			var pp := t * tt + n * 29.55
			meter(mb, solid_mat, pp)
		# Hydranten, Muelleimer, Baenke, Briefkasten
		if rng.randf() < 0.55:
			hydrant(mb, solid_mat, t * rng.randf_range(-25.0, -21.0) + n * 29.3, rng.randf() < 0.3)
		if rng.randf() < 0.6:
			trash(mb, solid_mat, t * rng.randf_range(20.0, 24.0) + n * 29.2)
		if rng.randf() < 0.3:
			bench(mb, solid_mat, t * rng.randf_range(-9.0, 9.0) + n * 26.9, n)
		if rng.randf() < 0.2:
			mailbox(mb, solid_mat, t * rng.randf_range(-24.0, -20.0) + n * 28.6, n)
		if rng.randf() < 0.07:
			bus_stop(mb, solid_mat, t * 3.0 + n * 27.6, n, t)
	# Ampeln an den vier Ecken
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var wx: float = cx + sx * 36.0
			var wz: float = cz + sz * 36.0
			var phase := int(floor(wx / 72.0 + wz / 72.0 + 100.0)) % 2 == 0
			signal_corner(mb, solid_mat, Vector3(sx * 27.7, 0, sz * 27.7), sx, sz, phase)
			blockers.append([Vector3(sx * 27.7, 0, sz * 27.7), 0.16])
	var node := MeshInstance3D.new()
	node.name = "Props"
	node.mesh = mb.build()
	node.position = Vector3(cx, 0, cz)
	parent.add_child(node)
	# Kollision fuer Masten und Staemme (der Spieler laeuft nicht hindurch)
	var body := StaticBody3D.new()
	body.name = "PropCollision"
	node.add_child(body)
	for b in blockers:
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = b[1]
		sh.height = 3.0
		cs.shape = sh
		cs.position = Vector3(b[0].x, 0.15 + 1.5, b[0].z)
		body.add_child(cs)


# Cobra-head-Laterne: Mast, Ausleger zur Fahrbahn, Leuchtkopf
func lamp(mb, mat: Material, pos: Vector3, n: Vector3) -> void:
	var p := Vector3(pos.x, 0.0, pos.z)
	var l := Vector3(p.x, SIDEWALK_Y, p.z)
	mb.scyl(mat, l, 0.2, 0.2, 0.55, POLE.darkened(0.1), 10, 0.55, 0.5)
	mb.scyl(mat, l + Vector3(0, 0.55, 0), 0.13, 0.08, 8.0, POLE, 10, 0.5, 0.6)
	var top := l + Vector3(0, 8.4, 0)
	mb.tube(mat, top - Vector3(0, 0.5, 0), top + n * 0.6 + Vector3(0, 0.45, 0), 0.07, 0.06, 6, POLE, 0.5, 0.6)
	var arm_end := top + n * 2.3 + Vector3(0, 0.45, 0)
	mb.tube(mat, top + n * 0.6 + Vector3(0, 0.45, 0), arm_end, 0.06, 0.05, 6, POLE, 0.5, 0.6)
	var hx := absf(n.x) * 0.5 + absf(n.z) * 0.22
	var hz := absf(n.z) * 0.5 + absf(n.x) * 0.22
	var hc := arm_end + n * 0.15
	mb.sbox(mat, hc.x - hx * 1.2, hc.y - 0.2, hc.z - hz * 1.2, hc.x + hx * 1.2, hc.y + 0.05, hc.z + hz * 1.2, Color(0.35, 0.37, 0.38), 0.5, 0.5)
	mb.sbox(mat, hc.x - hx * 1.0, hc.y - 0.22, hc.z - hz * 1.0, hc.x + hx * 1.0, hc.y - 0.19, hc.z + hz * 1.0, Color(1.0, 0.85, 0.55), 0.3, 0.0, 0.6)


func meter(mb, mat: Material, pos: Vector3) -> void:
	var l := Vector3(pos.x, SIDEWALK_Y, pos.z)
	mb.scyl(mat, l, 0.035, 0.035, 1.15, Color(0.55, 0.57, 0.58), 6, 0.4, 0.7)
	mb.sbox(mat, l.x - 0.1, l.y + 1.15, l.z - 0.07, l.x + 0.1, l.y + 1.45, l.z + 0.07, Color(0.5, 0.52, 0.54), 0.4, 0.6)
	mb.sbox(mat, l.x - 0.07, l.y + 1.28, l.z - 0.075, l.x + 0.07, l.y + 1.4, l.z + 0.075, Color(0.1, 0.12, 0.15), 0.2, 0.1)


func hydrant(mb, mat: Material, pos: Vector3, yellow: bool) -> void:
	var l := Vector3(pos.x, SIDEWALK_Y, pos.z)
	var c := Color(0.72, 0.08, 0.06) if not yellow else Color(0.85, 0.65, 0.08)
	mb.scyl(mat, l, 0.17, 0.15, 0.62, c, 10, 0.4, 0.3)
	mb.scyl(mat, l + Vector3(0, 0.62, 0), 0.17, 0.08, 0.14, c, 10, 0.4, 0.3)
	mb.scyl(mat, l + Vector3(0, 0.76, 0), 0.05, 0.05, 0.08, c, 8, 0.4, 0.3)
	mb.sbox(mat, l.x - 0.27, l.y + 0.32, l.z - 0.06, l.x + 0.27, l.y + 0.44, l.z + 0.06, c, 0.4, 0.3)
	mb.sbox(mat, l.x - 0.06, l.y + 0.34, l.z - 0.15, l.x + 0.06, l.y + 0.42, l.z + 0.15, c.darkened(0.1), 0.4, 0.3)


func trash(mb, mat: Material, pos: Vector3) -> void:
	var l := Vector3(pos.x, SIDEWALK_Y, pos.z)
	mb.scyl(mat, l, 0.3, 0.32, 0.85, Color(0.1, 0.28, 0.17), 12, 0.6, 0.3)
	mb.scyl(mat, l + Vector3(0, 0.85, 0), 0.33, 0.33, 0.07, Color(0.06, 0.06, 0.07), 12, 0.5, 0.3)
	for k in range(3):
		mb.scyl(mat, l + Vector3(0, 0.15 + k * 0.28, 0), 0.325, 0.325, 0.03, Color(0.06, 0.06, 0.07), 12, 0.5, 0.5, 0.0, false)


func bench(mb, mat: Material, pos: Vector3, n: Vector3) -> void:
	var l := Vector3(pos.x, SIDEWALK_Y, pos.z)
	var along := Vector3(absf(n.z), 0, absf(n.x))
	var hw := 0.9
	var wood := Color(0.42, 0.26, 0.13)
	var sx := absf(along.x) * hw + absf(n.x) * 0.25
	var sz := absf(along.z) * hw + absf(n.z) * 0.25
	for k in range(3):
		var o: Vector3 = n * (0.2 - k * 0.14)
		mb.sbox(mat, l.x + o.x - sx, l.y + 0.43, l.z + o.z - sz, l.x + o.x + sx, l.y + 0.47, l.z + o.z + sz, wood, 0.8)
	var back := n * 0.3
	for k in range(2):
		var yy := l.y + 0.62 + k * 0.14
		mb.sbox(mat, l.x + back.x - (absf(along.x) * hw + absf(n.x) * 0.02), yy, l.z + back.z - (absf(along.z) * hw + absf(n.z) * 0.02), l.x + back.x + (absf(along.x) * hw + absf(n.x) * 0.02), yy + 0.1, l.z + back.z + (absf(along.z) * hw + absf(n.z) * 0.02), wood, 0.8)
	for sgn in [-1.0, 1.0]:
		var o: Vector3 = along * (sgn * (hw - 0.1))
		mb.sbox(mat, l.x + o.x - 0.04 - absf(n.x) * 0.2, l.y, l.z + o.z - 0.04 - absf(n.z) * 0.2, l.x + o.x + 0.04 + absf(n.x) * 0.2, l.y + 0.45, l.z + o.z + 0.04 + absf(n.z) * 0.2, Color(0.1, 0.1, 0.11), 0.5, 0.6)


func mailbox(mb, mat: Material, pos: Vector3, n: Vector3) -> void:
	var l := Vector3(pos.x, SIDEWALK_Y, pos.z)
	mb.sbox(mat, l.x - 0.3, l.y + 0.0, l.z - 0.3, l.x + 0.3, l.y + 1.0, l.z + 0.3, Color(0.07, 0.17, 0.5), 0.35, 0.4)
	mb.scyl(mat, l + Vector3(0, 1.0, 0), 0.3, 0.2, 0.18, Color(0.07, 0.17, 0.5), 10, 0.35, 0.4)
	mb.sbox(mat, l.x - 0.15 + n.x * 0.29, l.y + 0.75, l.z - 0.15 + n.z * 0.29, l.x + 0.15 + n.x * 0.31, l.y + 0.82, l.z + 0.15 + n.z * 0.31, Color(0.03, 0.03, 0.04), 0.3)


# Bushaltestelle: Glasdach, Rueckwand, Bank, Werbetafel
func bus_stop(mb, mat: Material, pos: Vector3, n: Vector3, t: Vector3) -> void:
	var l := Vector3(pos.x, SIDEWALK_Y, pos.z)
	var hw := 1.8
	var ax := absf(t.x)
	var az := absf(t.z)
	var bx := absf(n.x)
	var bz := absf(n.z)
	var steel := Color(0.3, 0.32, 0.34)
	# Dach
	mb.sbox(mat, l.x - ax * hw - bx * 1.0, l.y + 2.5, l.z - az * hw - bz * 1.0, l.x + ax * hw + bx * 1.0, l.y + 2.62, l.z + az * hw + bz * 1.0, steel, 0.4, 0.6)
	# Rueckwand (Glas) und Werbetafel
	var back := -n * 0.9
	mb.sbox(mat, l.x + back.x - ax * hw - bx * 0.03, l.y + 0.3, l.z + back.z - az * hw - bz * 0.03, l.x + back.x + ax * hw + bx * 0.03, l.y + 2.5, l.z + back.z + az * hw + bz * 0.03, Color(0.15, 0.22, 0.26), 0.05, 0.4)
	var ad_c := Color(0.9, 0.9, 0.95)
	mb.sbox(mat, l.x + back.x + n.x * 0.04 - ax * 0.6 - bx * 0.02, l.y + 0.6, l.z + back.z + n.z * 0.04 - az * 0.6 - bz * 0.02, l.x + back.x + n.x * 0.04 + ax * 0.6 + bx * 0.02, l.y + 2.2, l.z + back.z + n.z * 0.04 + az * 0.6 + bz * 0.02, ad_c.lerp(Color(0.9, 0.3, 0.2), rng.randf()), 0.3, 0.0, 0.6)
	# Pfosten
	for s in [-1.0, 1.0]:
		var o: Vector3 = t * (s * hw)
		mb.sbox(mat, l.x + o.x + back.x - 0.05, l.y, l.z + o.z + back.z - 0.05, l.x + o.x + back.x + 0.05, l.y + 2.5, l.z + o.z + back.z + 0.05, steel, 0.4, 0.6)
	# Bank
	mb.sbox(mat, l.x + back.x * 0.55 - ax * 1.4 - bx * 0.2, l.y + 0.45, l.z + back.z * 0.55 - az * 1.4 - bz * 0.2, l.x + back.x * 0.55 + ax * 1.4 + bx * 0.2, l.y + 0.5, l.z + back.z * 0.55 + az * 1.4 + bz * 0.2, Color(0.25, 0.27, 0.3), 0.5, 0.6)


# Ampelmast an einer Blockecke mit zwei Auslegern
func signal_corner(mb, mat: Material, p: Vector3, sx: float, sz: float, phase: bool) -> void:
	var l := Vector3(p.x, SIDEWALK_Y, p.z)
	mb.scyl(mat, l, 0.14, 0.14, 0.4, POLE.darkened(0.1), 10, 0.5, 0.5)
	mb.scyl(mat, l + Vector3(0, 0.4, 0), 0.11, 0.08, 5.4, POLE, 10, 0.5, 0.6)
	var top := l + Vector3(0, 5.5, 0)
	# Ausleger entlang x (ueber die z-Strasse) und entlang z (ueber die x-Strasse)
	var ax_end := top + Vector3(sx * 6.2, 0.2, 0)
	var az_end := top + Vector3(0, 0.2, sz * 6.2)
	mb.tube(mat, top, ax_end, 0.07, 0.05, 6, POLE, 0.5, 0.6)
	mb.tube(mat, top, az_end, 0.07, 0.05, 6, POLE, 0.5, 0.6)
	# Koepfe: z-Strassenverkehr schaut gegen -sz, x-Strassenverkehr gegen -sx
	signal_head(mb, mat, top + Vector3(sx * 5.4, -0.2, 0), Vector3(0, 0, -sz), phase)
	signal_head(mb, mat, top + Vector3(0, -0.2, sz * 5.4), Vector3(-sx, 0, 0), not phase)
	# Strassenschild
	mb.sbox(mat, top.x - 0.65 - 0.0, top.y + 0.55, top.z - 0.02, top.x + 0.65, top.y + 0.8, top.z + 0.02, Color(0.05, 0.4, 0.2), 0.4, 0.2)
	mb.sbox(mat, top.x - 0.02, top.y + 0.55, top.z - 0.65, top.x + 0.02, top.y + 0.8, top.z + 0.65, Color(0.05, 0.4, 0.2), 0.4, 0.2)
	# Fussgaengerampel am Mast
	mb.sbox(mat, l.x - 0.14, l.y + 2.3, l.z - 0.14, l.x + 0.14, l.y + 2.75, l.z + 0.14, Color(0.08, 0.08, 0.09), 0.5, 0.3)
	mb.sbox(mat, l.x + sx * 0.14, l.y + 2.45, l.z - 0.08, l.x + sx * 0.16, l.y + 2.65, l.z + 0.08, Color(1.0, 0.45, 0.1) if phase else Color(0.9, 0.9, 0.95), 0.3, 0.0, 2.0)


# Ampelkopf: facing = Blickrichtung der Linsen (zum ankommenden Verkehr). green = gruen an
func signal_head(mb, mat: Material, c: Vector3, facing: Vector3, green: bool) -> void:
	var fx := absf(facing.x)
	var fz := absf(facing.z)
	var wx := 0.17 * fz + 0.2 * fx
	var wz := 0.17 * fx + 0.2 * fz
	var dark := Color(0.06, 0.06, 0.065)
	mb.sbox(mat, c.x - wx, c.y - 0.7, c.z - wz, c.x + wx, c.y + 0.0, c.z + wz, dark, 0.5, 0.3)
	# Blende
	var cols := [Color(1.0, 0.1, 0.05), Color(1.0, 0.7, 0.05), Color(0.1, 1.0, 0.3)]
	for k in range(3):
		var lit := (k == 2 and green) or (k == 0 and not green)
		var cy := c.y - 0.12 - k * 0.22
		var lc: Color = cols[k]
		var e := 4.0 if lit else 0.0
		var cc: Color = lc if lit else lc.darkened(0.8)
		var o: Vector3 = facing * 0.2
		mb.sbox(mat, c.x + o.x - 0.1 * fz - 0.01 * fx, cy - 0.08, c.z + o.z - 0.1 * fx - 0.01 * fz, c.x + o.x + 0.1 * fz + 0.03 * fx, cy + 0.08, c.z + o.z + 0.1 * fx + 0.03 * fz, cc, 0.3, 0.0, e)


# Parklaterne: niedriger Mast mit Laterne
func park_lamp(mb, mat: Material, pos: Vector3) -> void:
	var l := Vector3(pos.x, 0.17, pos.z)
	mb.scyl(mat, l, 0.17, 0.15, 0.45, POLE.darkened(0.1), 10, 0.5, 0.5)
	mb.scyl(mat, l + Vector3(0, 0.45, 0), 0.08, 0.06, 3.5, POLE, 10, 0.5, 0.6)
	mb.sbox(mat, l.x - 0.22, l.y + 3.95, l.z - 0.22, l.x + 0.22, l.y + 4.45, l.z + 0.22, Color(0.95, 0.9, 0.75), 0.2, 0.0, 0.5)
	mb.sbox(mat, l.x - 0.3, l.y + 4.45, l.z - 0.3, l.x + 0.3, l.y + 4.55, l.z + 0.3, POLE, 0.5, 0.5)
	mb.sbox(mat, l.x - 0.3, l.y + 3.85, l.z - 0.3, l.x + 0.3, l.y + 3.95, l.z + 0.3, POLE, 0.5, 0.5)
