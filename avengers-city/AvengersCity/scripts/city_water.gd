extends RefCounted
# Fluesse (Hudson im Westen, East River im Osten, Hafen im Sueden): Wasserflaeche, Kaimauer, Piers, Haengebruecke (Brooklyn-Art)
# und ferne Ufer mit Skyline. Die Stadt ist eine Insel: Strassenraster bis x/z = +-475.

const MB = preload("res://scripts/city_mesh.gd")
const M = preload("res://scripts/city_mats.gd")
const Ground = preload("res://scripts/city_ground.gd")

const WATER_Y := -1.2
const EDGE := 475.0
const FAR := 1060.0  # Abstand des gegenueberliegenden Ufers vom Stadtmittelpunkt
const BRIDGE_Z := -108.0
const DECK_H := 26.0

# Piers: [Seite, z-Mitte, Laenge]
const PIERS := [["w", 110.0, 95.0], ["w", -250.0, 70.0], ["s", -180.0, 80.0]]


static func build(parent: Node3D, gen) -> void:
	var solid := M.solid()
	# Wasser (riesig, liegt unter dem Land und schaut an den Ufern heraus)
	var wm := MeshInstance3D.new()
	wm.name = "Water"
	var pm := PlaneMesh.new()
	pm.size = Vector2(9000, 9000)
	wm.mesh = pm
	wm.position = Vector3(0, WATER_Y, 0)
	wm.material_override = M.water()
	wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(wm)
	# Kollision des Flussbetts (flach, damit man nicht ins Nichts faellt)
	var bed := StaticBody3D.new()
	bed.name = "RiverBed"
	parent.add_child(bed)
	var bcs := CollisionShape3D.new()
	var bbs := BoxShape3D.new()
	bbs.size = Vector3(9000, 1, 9000)
	bcs.shape = bbs
	bcs.position = Vector3(0, WATER_Y - 0.5 - 0.3, 0)
	bed.add_child(bcs)

	var mb := MB.new()
	quay(mb, solid, bed)
	for p in PIERS:
		pier(mb, solid, p[0], p[1], p[2])
		# Kollision des Pierdecks (begehbar)
		var pc := CollisionShape3D.new()
		var pbx := BoxShape3D.new()
		var plen: float = p[2] + 1.0
		if p[0] == "w":
			pbx.size = Vector3(plen, 0.5, 14.0)
			pc.position = Vector3(-EDGE - plen * 0.5 + 1.0, -0.15, p[1])
		else:
			pbx.size = Vector3(14.0, 0.5, plen)
			pc.position = Vector3(p[1], -0.15, EDGE + plen * 0.5 - 1.0)
		pc.shape = pbx
		bed.add_child(pc)
	var node := Node3D.new()
	node.name = "Waterfront"
	parent.add_child(node)
	mb.instance(node, "Quay")
	bridge(node)
	far_shores(parent, gen)


# Kaimauer um die Insel (W, O, S) mit Gelaender und Pollern; Luecken fuer Piers
static func quay(mb, solid: Material, body: StaticBody3D) -> void:
	var concrete := Color(0.46, 0.45, 0.43)
	var e := EDGE
	# Mauer und Abdeckplatte
	mb.sbox(solid, -e - 1.0, -2.2, -1500.0, -e, 0.0, e + 1.0, concrete.darkened(0.15), 0.9)
	mb.sbox(solid, e, -2.2, -1500.0, e + 1.0, 0.0, e + 1.0, concrete.darkened(0.15), 0.9)
	mb.sbox(solid, -e - 1.0, -2.2, e, e + 1.0, 0.0, e + 1.0, concrete.darkened(0.15), 0.9)
	mb.sbox(solid, -e - 0.3, 0.0, -1500.0, -e + 0.9, 0.12, e + 0.3, concrete, 0.8)
	mb.sbox(solid, e - 0.9, 0.0, -1500.0, e + 0.3, 0.12, e + 0.3, concrete, 0.8)
	mb.sbox(solid, -e - 0.3, 0.0, e - 0.9, e + 0.3, 0.12, e + 0.3, concrete, 0.8)
	# Poller und Gelaenderpfosten
	var steel := Color(0.16, 0.17, 0.18)
	var iron := M.iron(1, Color(0.10, 0.11, 0.12))
	for k in range(-38, 39):
		var v := k * 12.0
		for side in range(3):
			var p: Vector3
			if side == 0:
				p = Vector3(-e + 0.5, 0.12, v)
			elif side == 1:
				p = Vector3(e - 0.5, 0.12, v)
			else:
				p = Vector3(v, 0.12, e - 0.5)
			if absf(v) > e - 3.0:
				continue
			if pier_gap(side, v, 6.0):
				continue
			mb.scyl(solid, p, 0.22, 0.2, 0.55, Color(0.08, 0.08, 0.09), 8, 0.5, 0.6)
			mb.scyl(solid, p + Vector3(0, 0.55, 0), 0.2, 0.14, 0.1, Color(0.9, 0.7, 0.1), 8, 0.5, 0.3)
	# Gelaender als Bahnen (iron kind 1) in Abschnitten
	var seg := 24.0
	for side in range(3):
		var k := -e + 6.0
		while k < e - 6.0:
			var k1 := minf(k + seg, e - 6.0)
			if not pier_gap(side, (k + k1) * 0.5, seg * 0.5 + 6.0):
				var a: Vector3
				var b: Vector3
				var nrm: Vector3
				if side == 0:
					a = Vector3(-e + 0.2, 0.12, k)
					b = Vector3(-e + 0.2, 0.12, k1)
					nrm = Vector3.LEFT
				elif side == 1:
					a = Vector3(e - 0.2, 0.12, k1)
					b = Vector3(e - 0.2, 0.12, k)
					nrm = Vector3.RIGHT
				else:
					a = Vector3(k1, 0.12, e - 0.2)
					b = Vector3(k, 0.12, e - 0.2)
					nrm = Vector3.BACK
				mb.quad(iron, a, b, b + Vector3(0, 1.1, 0), a + Vector3(0, 1.1, 0), nrm, 0.0, (b - a).length(), 0.0, 1.0)
				# Kollision des Gelaenders
				var cs := CollisionShape3D.new()
				var bs := BoxShape3D.new()
				var mid := (a + b) * 0.5
				bs.size = Vector3(0.3, 1.2, (b - a).length()) if side < 2 else Vector3((b - a).length(), 1.2, 0.3)
				cs.shape = bs
				cs.position = mid + Vector3(0, 0.6, 0)
				body.add_child(cs)
			k = k1


static func pier_gap(side: int, v: float, margin: float) -> bool:
	for p in PIERS:
		var sidx: int = 0 if p[0] == "w" else 2
		if sidx == side and absf(v - float(p[1])) < 8.0 + margin:
			return true
	return false


# Pier: Holzdeck auf Pfaehlen mit Schuppen und Pollern
static func pier(mb, solid: Material, side: String, c: float, length: float) -> void:
	var wood := Color(0.30, 0.22, 0.15)
	var w := 14.0
	var e := EDGE
	# Koordinaten in "Pier-Raum": u = Abstand vom Ufer nach draussen, v = quer
	var to_world := func(u: float, v: float) -> Vector3:
		if side == "w":
			return Vector3(-e - u, 0.0, c + v)
		return Vector3(c + v, 0.0, e + u)
	var a: Vector3 = to_world.call(-1.0, -w * 0.5)
	var b: Vector3 = to_world.call(length, w * 0.5)
	mb.sbox(solid, minf(a.x, b.x), -0.35, minf(a.z, b.z), maxf(a.x, b.x), 0.1, maxf(a.z, b.z), wood, 0.9)
	mb.sbox(solid, minf(a.x, b.x) - 0.1, -0.5, minf(a.z, b.z) - 0.1, maxf(a.x, b.x) + 0.1, -0.3, maxf(a.z, b.z) + 0.1, wood.darkened(0.3), 0.9)
	# Pfaehle
	var k := 4.0
	while k < length:
		for sv in [-1.0, 1.0]:
			var p: Vector3 = to_world.call(k, sv * (w * 0.5 - 0.3))
			mb.scyl(solid, Vector3(p.x, WATER_Y - 1.0, p.z), 0.22, 0.2, 1.4, wood.darkened(0.5), 6, 0.9)
		k += 8.0
	# Schuppen auf dem Pier
	var s0: Vector3 = to_world.call(10.0, -w * 0.5 + 1.5)
	var s1: Vector3 = to_world.call(length * 0.55, w * 0.5 - 1.5)
	var sx0 := minf(s0.x, s1.x)
	var sx1 := maxf(s0.x, s1.x)
	var sz0 := minf(s0.z, s1.z)
	var sz1 := maxf(s0.z, s1.z)
	mb.sbox(solid, sx0, 0.1, sz0, sx1, 6.0, sz1, Color(0.42, 0.46, 0.44), 0.7, 0.3)
	mb.sbox(solid, sx0 - 0.3, 6.0, sz0 - 0.3, sx1 + 0.3, 6.35, sz1 + 0.3, Color(0.3, 0.32, 0.31), 0.7, 0.3)
	# Poller am Rand
	var kk := 6.0
	while kk < length:
		for sv in [-1.0, 1.0]:
			var p2: Vector3 = to_world.call(kk, sv * (w * 0.5 - 0.5))
			mb.scyl(solid, Vector3(p2.x, 0.1, p2.z), 0.25, 0.2, 0.5, Color(0.08, 0.08, 0.09), 8, 0.5, 0.6)
		kk += 10.0


# ------------------------------------------------------------------------------------------------
# Haengebruecke (Brooklyn-Art): Steinpfeiler mit Spitzbogen, Seile, Haenger, Fahrbahn
# ------------------------------------------------------------------------------------------------

static func bridge(parent: Node3D) -> void:
	var mb := MB.new()
	var solid := M.solid()
	var stone := Color(0.50, 0.46, 0.40)
	var steel := Color(0.14, 0.15, 0.16)
	var zc := BRIDGE_Z
	var xa := EDGE + 1.0  # Verankerung Stadtseite
	var xt1 := 640.0
	var xt2 := 900.0
	var xb := FAR - 8.0  # Verankerung Gegenseite
	var half := 12.0  # halbe Fahrbahnbreite
	var tower_top := 96.0
	# Verankerungsbloecke
	for xx in [xa, xb - 34.0]:
		mb.sbox(solid, xx, -1.5, zc - 18.0, xx + 34.0, DECK_H + 8.0, zc + 18.0, stone, 0.9)
		mb.sbox(solid, xx - 1.0, DECK_H + 8.0, zc - 19.0, xx + 35.0, DECK_H + 9.2, zc + 19.0, stone.lightened(0.1), 0.85)
		# Spitzbogen-Nischen und Gesimsbaender an der Stadtseite
		if xx == xa:
			for sz in [-1.0, 0.0, 1.0]:
				mb.sbox(solid, xa - 0.15, 3.0, zc + sz * 11.0 - 3.2, xa + 0.1, 16.0, zc + sz * 11.0 + 3.2, Color(0.10, 0.09, 0.08), 0.9)
				mb.sbox(solid, xa - 0.15, 16.0, zc + sz * 11.0 - 2.0, xa + 0.1, 19.0, zc + sz * 11.0 + 2.0, Color(0.10, 0.09, 0.08), 0.9)
			for yb in [2.0, 20.0, 26.0]:
				mb.sbox(solid, xa - 0.5, yb, zc - 18.5, xa + 34.5, yb + 0.6, zc + 18.5, stone.lightened(0.15), 0.85)
	# Tuerme: zwei Beine, Quertraeger, Spitzbogen-Portale
	for xt in [xt1, xt2]:
		for sz in [-1.0, 1.0]:
			var zl: float = zc + sz * 13.0
			mb.sbox(solid, xt - 5.0, -3.0, zl - 4.5, xt + 5.0, tower_top, zl + 4.5, stone, 0.9)
			mb.sbox(solid, xt - 5.4, 62.0, zl - 4.9, xt + 5.4, 63.2, zl + 4.9, stone.lightened(0.1), 0.85)
			mb.sbox(solid, xt - 5.4, tower_top, zl - 4.9, xt + 5.4, tower_top + 1.2, zl + 4.9, stone.lightened(0.1), 0.85)
			# Spitzbogenblende (dunkel) an den Seiten
			for sx in [-1.0, 1.0]:
				mb.sbox(solid, xt + sx * 5.0 - 0.1 + (0.1 if sx > 0 else 0.0), 30.0, zl - 2.0, xt + sx * 5.0 + 0.1 + (0.1 if sx > 0 else 0.0), 58.0, zl + 2.0, Color(0.16, 0.14, 0.12), 0.9)
		# Quertraeger (zwei) mit Spitzbogenoeffnung darunter
		mb.sbox(solid, xt - 5.0, 56.0, zc - 9.0, xt + 5.0, 66.0, zc + 9.0, stone, 0.9)
		mb.sbox(solid, xt - 5.0, 82.0, zc - 9.0, xt + 5.0, tower_top - 6.0, zc + 9.0, stone, 0.9)
		mb.sbox(solid, xt - 3.0, 66.0, zc - 9.0, xt + 3.0, 72.0, zc - 7.0, stone, 0.9)
		mb.sbox(solid, xt - 3.0, 66.0, zc + 7.0, xt + 3.0, 72.0, zc + 9.0, stone, 0.9)
		# Sattel fuer die Seile
		for sz in [-1.0, 1.0]:
			mb.sbox(solid, xt - 1.5, tower_top + 1.2, zc + sz * 13.0 - 1.5, xt + 1.5, tower_top + 2.4, zc + sz * 13.0 + 1.5, steel, 0.5, 0.6)
	# Fahrbahn und Versteifungstraeger
	mb.sbox(solid, xa + 34.0, DECK_H - 1.4, zc - half, xb - 34.0, DECK_H, zc + half, Color(0.26, 0.26, 0.28), 0.8)
	mb.sbox(solid, xa + 34.0, DECK_H, zc - half - 0.4, xb - 34.0, DECK_H + 3.2, zc - half + 0.2, steel, 0.5, 0.5)
	mb.sbox(solid, xa + 34.0, DECK_H, zc + half - 0.2, xb - 34.0, DECK_H + 3.2, zc + half + 0.4, steel, 0.5, 0.5)
	mb.sbox(solid, xa + 34.0, DECK_H - 3.2, zc - 1.0, xb - 34.0, DECK_H - 1.4, zc + 1.0, steel, 0.5, 0.5)
	# Hauptseile (zwei) als Parabeln zwischen Verankerung - Turm - Turm - Verankerung
	var pts_x := [xa + 17.0, xt1, xt2, xb - 17.0]
	var pts_y := [DECK_H + 10.0, tower_top + 2.4, tower_top + 2.4, DECK_H + 10.0]
	for sz in [-1.0, 1.0]:
		var zz: float = zc + sz * 13.0
		for s in range(3):
			var x0: float = pts_x[s]
			var x1: float = pts_x[s + 1]
			var y0: float = pts_y[s]
			var y1: float = pts_y[s + 1]
			var sag := 52.0 if s == 1 else 24.0
			var nseg := int((x1 - x0) / 10.0)
			var prev := Vector3(x0, y0, zz)
			for i in range(1, nseg + 1):
				var u := float(i) / nseg
				var xx := lerpf(x0, x1, u)
				var yy := lerpf(y0, y1, u) - sag * 4.0 * u * (1.0 - u)
				var cur := Vector3(xx, yy, zz)
				mb.tube(solid, prev, cur, 0.55, 0.55, 6, Color(0.1, 0.1, 0.11), 0.5, 0.5)
				# Haenger zur Fahrbahn
				if xx > xa + 36.0 and xx < xb - 36.0 and absf(xx - xt1) > 6.0 and absf(xx - xt2) > 6.0 and i % 1 == 0:
					mb.tube(solid, Vector3(xx, yy, zz), Vector3(xx, DECK_H + 3.0, zz), 0.07, 0.07, 4, Color(0.2, 0.2, 0.22), 0.5, 0.5)
				prev = cur
	# Diagonalseile (Strahlen vom Turm), wie bei der Brooklyn Bridge
	for xt in [xt1, xt2]:
		for sgn in [-1.0, 1.0]:
			for k in range(1, 9):
				var xe: float = xt + sgn * k * 14.0
				if xe < xa + 36.0 or xe > xb - 36.0:
					continue
				if (xe > xt1 and xe < xt2) and absf(xe - xt) > 60.0:
					continue
				for sz in [-1.0, 1.0]:
					mb.tube(solid, Vector3(xt, tower_top - 2.0, zc + sz * 13.0), Vector3(xe, DECK_H + 2.5, zc + sz * 12.0), 0.06, 0.06, 4, Color(0.2, 0.2, 0.22), 0.5, 0.5)
	# Lampen auf der Fahrbahn
	var xl := xa + 40.0
	while xl < xb - 40.0:
		mb.scyl(solid, Vector3(xl, DECK_H, zc - half + 0.2), 0.1, 0.07, 6.0, Color(0.2, 0.2, 0.22), 6, 0.5, 0.6)
		mb.scyl(solid, Vector3(xl, DECK_H, zc + half - 0.2), 0.1, 0.07, 6.0, Color(0.2, 0.2, 0.22), 6, 0.5, 0.6)
		xl += 30.0
	var mi: MeshInstance3D = mb.instance(parent, "Bridge")
	# Kollision: begehbare Fahrbahn und Pfeiler
	var body := StaticBody3D.new()
	body.name = "BridgeCollision"
	parent.add_child(body)
	var boxes := [
		[xa, -1.5, zc - 18.0, xa + 34.0, DECK_H + 8.0, zc + 18.0],
		[xb - 34.0, -1.5, zc - 18.0, xb, DECK_H + 8.0, zc + 18.0],
		[xa + 34.0, DECK_H - 1.4, zc - half, xb - 34.0, DECK_H, zc + half],
	]
	for xt in [xt1, xt2]:
		for sz in [-1.0, 1.0]:
			boxes.append([xt - 5.0, -3.0, zc + sz * 13.0 - 4.5, xt + 5.0, tower_top, zc + sz * 13.0 + 4.5])
	for s in boxes:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(s[3] - s[0], s[4] - s[1], s[5] - s[2])
		cs.shape = bs
		cs.position = Vector3((s[0] + s[3]) * 0.5, (s[1] + s[4]) * 0.5, (s[2] + s[5]) * 0.5)
		body.add_child(cs)


# ------------------------------------------------------------------------------------------------
# Ferne Ufer mit Haeusern (liegen im Dunst, reichen als Kulisse)
# ------------------------------------------------------------------------------------------------

static func far_shores(parent: Node3D, gen) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	# Land am anderen Ufer (gleiches Boden-Material wie das Umland)
	var gm := Ground.ground_material()
	for q in [[Vector2(2400.0, 7000.0), Vector3(FAR + 1200.0, 0, 0)], [Vector2(2400.0, 7000.0), Vector3(-FAR - 1200.0, 0, 0)], [Vector2(2.0 * FAR, 2400.0), Vector3(0, 0, FAR + 1200.0)]]:
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = q[0]
		mi.mesh = pm
		mi.position = q[1]
		mi.material_override = gm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
	# Skyline-Streifen: Ost, West, Sued; in Abschnitten (Culling)
	var chunk := 400.0
	for shore in range(3):
		var n := 7 if shore < 2 else 5
		for ci in range(n):
			var c0 := -float(n) * chunk * 0.5 + ci * chunk
			var cx: float
			var cz: float
			if shore == 0:
				cx = FAR + 20.0
				cz = c0 + chunk * 0.5
			elif shore == 1:
				cx = -FAR - 20.0
				cz = c0 + chunk * 0.5
			else:
				cx = c0 + chunk * 0.5
				cz = FAR + 20.0
			gen.begin(cx, cz, 300 + shore * 20 + ci, 700, 3)
			gen.detail = false
			var y_cells := 3
			var cell := 38.0
			for i in range(int(chunk / cell)):
				for j in range(y_cells):
					if rng.randf() < 0.18:
						continue
					var along := -chunk * 0.5 + i * cell
					var dep := j * cell + rng.randf_range(0.0, 6.0)
					var w := rng.randf_range(24.0, 34.0)
					var d := rng.randf_range(24.0, 34.0)
					var lot: Dictionary
					if shore == 0:
						lot = {"x0": dep, "z0": along, "x1": dep + w, "z1": along + d, "o": [true, true, true, true]}
					elif shore == 1:
						lot = {"x0": -dep - w, "z0": along, "x1": -dep, "z1": along + d, "o": [true, true, true, true]}
					else:
						lot = {"x0": along, "z0": dep, "x1": along + w, "z1": dep + d, "o": [true, true, true, true]}
					var tall := rng.randf() < (0.22 if j == 0 else 0.07)
					gen.build_lot(lot, 1 if tall else 3, "tower" if tall else "mid")
			var node := Node3D.new()
			node.name = "FarShore_%d_%d" % [shore, ci]
			node.position = Vector3(cx, 0, cz)
			parent.add_child(node)
			var mi2: MeshInstance3D = gen.mb.instance(node, "Far")
			mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
