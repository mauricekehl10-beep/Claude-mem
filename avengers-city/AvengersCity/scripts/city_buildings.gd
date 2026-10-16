extends RefCounted
# Gebaeude der Stadt: Parzellen, Hoehen, Stile, Gesimse, Dachaufbauten, Feuertreppen, Vordaecher.
# Alles pro Block zu EINEM Mesh zusammengefasst (wenige Draw-Calls), Kollision aus Quadern (Dacher begehbar).

const MB = preload("res://scripts/city_mesh.gd")
const M = preload("res://scripts/city_mats.gd")

const HALF := 26.0  # bebaubarer Bereich je Block: -26 .. +26

# Stile: kind 0 Ziegel, 1 Naturstein, 2 Beton-Fensterband, 3 Glas-Vorhangfassade, 4 Putz, 5 Laden, 6 Parkhaus
const STYLES := {
	"brick_red": {"kind": 0, "wall": Color(0.56, 0.25, 0.19), "trim": Color(0.76, 0.72, 0.66), "frame": Color(0.88, 0.88, 0.84), "glass": Color(0.07, 0.10, 0.15), "win": Vector2(1.1, 1.7), "sill": 0.95, "gm": 0.12, "fh": 3.3, "cw": 2.7, "shop": "shop_dark", "cat": "brick"},
	"brick_brown": {"kind": 0, "wall": Color(0.38, 0.23, 0.17), "trim": Color(0.62, 0.58, 0.52), "frame": Color(0.13, 0.17, 0.15), "glass": Color(0.06, 0.09, 0.12), "win": Vector2(1.05, 1.85), "sill": 0.85, "gm": 0.12, "fh": 3.4, "cw": 2.6, "shop": "shop_stone", "cat": "brick"},
	"brick_tan": {"kind": 0, "wall": Color(0.68, 0.50, 0.34), "trim": Color(0.82, 0.78, 0.70), "frame": Color(0.9, 0.9, 0.86), "glass": Color(0.07, 0.10, 0.15), "win": Vector2(1.15, 1.7), "sill": 0.95, "gm": 0.12, "fh": 3.2, "cw": 2.9, "shop": "shop_brick", "cat": "brick"},
	"brick_dark": {"kind": 0, "wall": Color(0.31, 0.19, 0.16), "trim": Color(0.55, 0.50, 0.45), "frame": Color(0.78, 0.74, 0.62), "glass": Color(0.06, 0.08, 0.12), "win": Vector2(1.1, 1.75), "sill": 0.9, "gm": 0.12, "fh": 3.3, "cw": 2.7, "shop": "shop_dark", "cat": "brick"},
	"stone_lime": {"kind": 1, "wall": Color(0.77, 0.71, 0.59), "trim": Color(0.85, 0.81, 0.71), "frame": Color(0.2, 0.18, 0.16), "glass": Color(0.07, 0.10, 0.15), "win": Vector2(1.3, 2.2), "sill": 0.8, "gm": 0.2, "fh": 3.8, "cw": 3.4, "shop": "shop_stone", "cat": "stone"},
	"stone_grey": {"kind": 1, "wall": Color(0.62, 0.62, 0.60), "trim": Color(0.74, 0.74, 0.72), "frame": Color(0.15, 0.16, 0.18), "glass": Color(0.07, 0.10, 0.15), "win": Vector2(1.25, 2.1), "sill": 0.85, "gm": 0.2, "fh": 3.7, "cw": 3.3, "shop": "shop_dark", "cat": "stone"},
	"stone_rose": {"kind": 1, "wall": Color(0.72, 0.58, 0.50), "trim": Color(0.84, 0.78, 0.70), "frame": Color(0.22, 0.17, 0.14), "glass": Color(0.07, 0.10, 0.15), "win": Vector2(1.25, 2.15), "sill": 0.8, "gm": 0.2, "fh": 3.7, "cw": 3.3, "shop": "shop_brick", "cat": "stone"},
	"concrete_a": {"kind": 2, "wall": Color(0.68, 0.67, 0.64), "trim": Color(0.55, 0.55, 0.55), "frame": Color(0.12, 0.13, 0.15), "glass": Color(0.10, 0.17, 0.22), "win": Vector2(0.0, 1.5), "sill": 1.0, "gm": 0.45, "fh": 3.6, "cw": 3.6, "shop": "shop_dark", "cat": "concrete"},
	"concrete_b": {"kind": 2, "wall": Color(0.52, 0.52, 0.54), "trim": Color(0.62, 0.62, 0.62), "frame": Color(0.22, 0.19, 0.16), "glass": Color(0.12, 0.17, 0.18), "win": Vector2(0.0, 1.55), "sill": 0.95, "gm": 0.45, "fh": 3.6, "cw": 3.6, "shop": "shop_stone", "cat": "concrete"},
	"glass_blue": {"kind": 3, "wall": Color(0.14, 0.20, 0.27), "trim": Color(0.5, 0.5, 0.52), "frame": Color(0.62, 0.64, 0.66), "glass": Color(0.30, 0.46, 0.60), "win": Vector2(1.0, 1.0), "sill": 0.95, "gm": 0.9, "gr": 0.05, "fh": 3.9, "cw": 1.8, "shop": "shop_glass", "cat": "glass"},
	"glass_green": {"kind": 3, "wall": Color(0.10, 0.20, 0.19), "trim": Color(0.5, 0.5, 0.52), "frame": Color(0.55, 0.58, 0.58), "glass": Color(0.30, 0.52, 0.48), "win": Vector2(1.0, 1.0), "sill": 0.95, "gm": 0.9, "gr": 0.05, "fh": 3.9, "cw": 1.8, "shop": "shop_glass", "cat": "glass"},
	"glass_dark": {"kind": 3, "wall": Color(0.10, 0.11, 0.13), "trim": Color(0.3, 0.3, 0.3), "frame": Color(0.22, 0.20, 0.19), "glass": Color(0.16, 0.22, 0.30), "win": Vector2(1.0, 1.0), "sill": 0.95, "gm": 0.9, "gr": 0.05, "fh": 3.9, "cw": 1.8, "shop": "shop_glass", "cat": "glass"},
	"stucco_cream": {"kind": 4, "wall": Color(0.88, 0.82, 0.68), "trim": Color(0.95, 0.94, 0.9), "frame": Color(0.92, 0.92, 0.9), "glass": Color(0.07, 0.10, 0.15), "win": Vector2(1.25, 1.6), "sill": 1.0, "gm": 0.12, "fh": 3.3, "cw": 3.3, "shop": "shop_brick", "cat": "stucco"},
	"stucco_blue": {"kind": 4, "wall": Color(0.58, 0.70, 0.80), "trim": Color(0.95, 0.95, 0.93), "frame": Color(0.94, 0.94, 0.92), "glass": Color(0.07, 0.10, 0.15), "win": Vector2(1.25, 1.6), "sill": 1.0, "gm": 0.12, "fh": 3.3, "cw": 3.3, "shop": "shop_dark", "cat": "stucco"},
	"stucco_terra": {"kind": 4, "wall": Color(0.80, 0.50, 0.36), "trim": Color(0.95, 0.92, 0.85), "frame": Color(0.2, 0.2, 0.2), "glass": Color(0.07, 0.10, 0.15), "win": Vector2(1.2, 1.6), "sill": 1.0, "gm": 0.12, "fh": 3.3, "cw": 3.2, "shop": "shop_stone", "cat": "stucco"},
	"stucco_grey": {"kind": 4, "wall": Color(0.74, 0.74, 0.72), "trim": Color(0.95, 0.95, 0.93), "frame": Color(0.14, 0.15, 0.17), "glass": Color(0.07, 0.10, 0.15), "win": Vector2(1.3, 1.65), "sill": 1.0, "gm": 0.12, "fh": 3.3, "cw": 3.4, "shop": "shop_dark", "cat": "stucco"},
	"garage": {"kind": 6, "wall": Color(0.66, 0.65, 0.62), "trim": Color(0.55, 0.55, 0.55), "frame": Color(0.2, 0.2, 0.2), "glass": Color(0.05, 0.05, 0.06), "win": Vector2(1.0, 1.0), "sill": 1.0, "gm": 0.0, "fh": 3.0, "cw": 5.0, "shop": "shop_dark", "cat": "garage"},
	"shop_dark": {"kind": 5, "wall": Color(0.22, 0.20, 0.19), "trim": Color(0.5, 0.5, 0.5), "frame": Color(0.12, 0.12, 0.13), "glass": Color(0.08, 0.11, 0.15), "gm": 0.3},
	"shop_stone": {"kind": 5, "wall": Color(0.62, 0.58, 0.50), "trim": Color(0.5, 0.5, 0.5), "frame": Color(0.14, 0.13, 0.12), "glass": Color(0.08, 0.11, 0.15), "gm": 0.3},
	"shop_brick": {"kind": 5, "wall": Color(0.42, 0.21, 0.16), "trim": Color(0.5, 0.5, 0.5), "frame": Color(0.1, 0.1, 0.1), "glass": Color(0.08, 0.11, 0.15), "gm": 0.3},
	"shop_glass": {"kind": 5, "wall": Color(0.45, 0.46, 0.48), "trim": Color(0.5, 0.5, 0.5), "frame": Color(0.5, 0.52, 0.54), "glass": Color(0.20, 0.30, 0.38), "gm": 0.5},
}

const TINTS_BRICK := [Color(1, 1, 1), Color(1.1, 0.98, 0.92), Color(0.92, 0.95, 1.0), Color(1.15, 1.05, 0.95), Color(0.9, 0.9, 0.9)]
const TINTS_LIGHT := [Color(1, 1, 1), Color(1.04, 1.0, 0.94), Color(0.96, 0.98, 1.02), Color(1.0, 0.97, 0.93)]

var rng := RandomNumberGenerator.new()
var detail := true
var force_street := false


func _init(seed_value: int = 1234) -> void:
	rng.seed = seed_value


func pick(a: Array):
	return a[rng.randi() % a.size()]


func mat_of(name: String) -> ShaderMaterial:
	return M.facade(name, STYLES[name])


# ------------------------------------------------------------------------------------------------
# Block-Aufteilung in Parzellen
# ------------------------------------------------------------------------------------------------

func split_lots(x0: float, z0: float, x1: float, z1: float, open: Array, depth: int, out: Array, max_size: float, min_size: float) -> void:
	var w := x1 - x0
	var d := z1 - z0
	var can_x := w >= min_size * 2.0 + 0.5
	var can_z := d >= min_size * 2.0 + 0.5
	var want_split := (maxf(w, d) > max_size) or (depth < 2 and rng.randf() < 0.55)
	if depth >= 3 or not want_split or (not can_x and not can_z):
		out.append({"x0": x0, "z0": z0, "x1": x1, "z1": z1, "o": open})
		return
	var split_x := can_x and (w >= d or not can_z)
	if can_x and can_z and absf(w - d) < 6.0:
		split_x = rng.randf() < 0.5
	var gap := 0.0
	if rng.randf() < 0.22:
		gap = pick([3.0, 4.0])
	if split_x:
		var lo := x0 + min_size
		var hi := x1 - min_size
		var xs := snappedf(rng.randf_range(lo + gap, hi - gap), 1.0)
		var oa: Array = [open[0], open[1], gap > 0.0, open[3]]
		var ob: Array = [open[0], open[1], open[2], gap > 0.0]
		split_lots(x0, z0, xs - gap * 0.5, z1, oa, depth + 1, out, max_size, min_size)
		split_lots(xs + gap * 0.5, z0, x1, z1, ob, depth + 1, out, max_size, min_size)
	else:
		var lo := z0 + min_size
		var hi := z1 - min_size
		var zs := snappedf(rng.randf_range(lo + gap, hi - gap), 1.0)
		# +z = Seite z1, -z = Seite z0
		var oa: Array = [gap > 0.0, open[1], open[2], open[3]]
		var ob: Array = [open[0], gap > 0.0, open[2], open[3]]
		split_lots(x0, z0, x1, zs - gap * 0.5, oa, depth + 1, out, max_size, min_size)
		split_lots(x0, zs + gap * 0.5, x1, z1, ob, depth + 1, out, max_size, min_size)


# ------------------------------------------------------------------------------------------------
# Block bauen
# ------------------------------------------------------------------------------------------------

# zone: 0 = Zentrum, 1 = Innenring, 2 = mittlerer Ring, 3+ = Aussenring
func build_block(parent: Node3D, cx: float, cz: float, zone: int, is_core: bool) -> Node3D:
	detail = is_core
	var mb := MB.new()
	var shapes := []
	var lots := []
	split_lots(-HALF, -HALF, HALF, HALF, [true, true, true, true], 0, lots, 30.0, 13.0)
	for lot in lots:
		build_lot(mb, shapes, lot, zone)
	var node := Node3D.new()
	node.position = Vector3(cx, 0, cz)
	node.name = "Block_%d_%d" % [int(cx), int(cz)]
	parent.add_child(node)
	mb.instance(node, "Buildings")
	add_collision(node, shapes)
	return node



# Wahrzeichen im Zentrum: gestaffelter Glasturm mit leuchtendem "A", Antenne und Positionslichtern
func build_landmark(parent: Node3D, cx: float, cz: float) -> Node3D:
	detail = true
	force_street = true
	var mb := MB.new()
	var shapes := []
	var all_open := [true, true, true, true]
	var tint := Color(1, 1, 1)
	var tiers := [
		["glass_dark", 19.0, 0.0, 16.0, 4],
		["glass_blue", 14.0, 16.0, 86.0, 18],
		["glass_blue", 11.0, 86.0, 134.0, 12],
		["glass_dark", 7.5, 134.0, 158.0, 6],
	]
	var idx := 0
	for t in tiers:
		var hs: float = t[1]
		build_tier(mb, STYLES[t[0]], t[0], -hs, -hs, hs, hs, t[2], t[3], tint, 0.5 + idx * 0.1, all_open, idx == 0, idx == tiers.size() - 1, t[4])
		shapes.append([-hs, t[2], -hs, hs, t[3], hs])
		idx += 1
	force_street = false
	var solid := M.solid()
	# Leuchtendes "A" auf allen vier Seiten der dritten Stufe
	var faces := [[Vector3(0, 0, 1), Vector3(1, 0, 0)], [Vector3(0, 0, -1), Vector3(-1, 0, 0)], [Vector3(1, 0, 0), Vector3(0, 0, -1)], [Vector3(-1, 0, 0), Vector3(0, 0, 1)]]
	for f in faces:
		var n: Vector3 = f[0]
		var r: Vector3 = f[1]
		var o := n * 11.3
		var y0 := 100.0
		var polys := [
			[[-6.0, 0.0], [-3.8, 0.0], [1.1, 15.0], [-1.1, 15.0]],
			[[3.8, 0.0], [6.0, 0.0], [1.1, 15.0], [-1.1, 15.0]],
			[[-3.4, 4.2], [3.4, 4.2], [3.4, 5.9], [-3.4, 5.9]],
		]
		for poly in polys:
			var pts := []
			for p in poly:
				pts.append(o + r * p[0] + Vector3(0, y0 + p[1], 0))
			mb.sq(solid, pts[0], pts[1], pts[2], pts[3], Color(0.75, 0.9, 1.0), 0.3, 0.0, 3.0)
	# Antenne und rote Positionslichter
	mb.tube(solid, Vector3(0, 158, 0), Vector3(0, 190, 0), 0.5, 0.08, 8, Color(0.7, 0.72, 0.75), 0.4, 0.7)
	mb.sbox(solid, -0.25, 190.0, -0.25, 0.25, 190.6, 0.25, Color(1.0, 0.1, 0.05), 0.3, 0.0, 8.0)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			mb.sbox(solid, sx * 7.3 - 0.2, 158.0, sz * 7.3 - 0.2, sx * 7.3 + 0.2, 158.4, sz * 7.3 + 0.2, Color(1.0, 0.1, 0.05), 0.3, 0.0, 6.0)
	var node := Node3D.new()
	node.position = Vector3(cx, 0, cz)
	node.name = "Landmark"
	parent.add_child(node)
	mb.instance(node, "Tower")
	add_collision(node, shapes)
	return node

func add_collision(node: Node3D, shapes: Array) -> void:
	var body := StaticBody3D.new()
	body.name = "Collision"
	node.add_child(body)
	for s in shapes:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(s[3] - s[0], s[4] - s[1], s[5] - s[2])
		cs.shape = bs
		cs.position = Vector3((s[0] + s[3]) * 0.5, (s[1] + s[4]) * 0.5, (s[2] + s[5]) * 0.5)
		body.add_child(cs)


func choose_style(zone: int, floors: int) -> String:
	var r := rng.randf()
	if floors <= 3:
		return pick(["stucco_cream", "stucco_blue", "stucco_terra", "stucco_grey", "brick_red", "brick_tan", "brick_brown"])
	if floors <= 8:
		if r < 0.42:
			return pick(["brick_red", "brick_brown", "brick_tan", "brick_dark", "brick_red"])
		if r < 0.62:
			return pick(["stone_lime", "stone_grey", "stone_rose"])
		if r < 0.78:
			return pick(["stucco_cream", "stucco_grey", "stucco_terra", "stucco_blue"])
		if r < 0.9:
			return pick(["concrete_a", "concrete_b"])
		return "garage" if rng.randf() < 0.5 else "glass_blue"
	if floors <= 16:
		if r < 0.30:
			return pick(["stone_lime", "stone_grey", "stone_rose"])
		if r < 0.55:
			return pick(["concrete_a", "concrete_b"])
		if r < 0.68:
			return pick(["brick_red", "brick_brown", "brick_dark"])
		if r < 0.75:
			return "garage"
		return pick(["glass_blue", "glass_green", "glass_dark"])
	if r < 0.5:
		return pick(["glass_blue", "glass_green", "glass_dark"])
	if r < 0.75:
		return pick(["stone_lime", "stone_grey"])
	return pick(["concrete_a", "concrete_b"])


func floors_for(zone: int) -> int:
	var f := 4
	match zone:
		0:
			f = rng.randi_range(14, 28)
		1:
			f = rng.randi_range(6, 16)
			if rng.randf() < 0.2:
				f = rng.randi_range(4, 6)
		2:
			f = rng.randi_range(3, 10)
			if rng.randf() < 0.08:
				f = rng.randi_range(10, 14)
		_:
			f = rng.randi_range(2, 6)
			if rng.randf() < 0.06:
				f = rng.randi_range(8, 12)
	return f


func build_lot(mb, shapes: Array, lot: Dictionary, zone: int) -> void:
	var x0: float = lot["x0"]
	var z0: float = lot["z0"]
	var x1: float = lot["x1"]
	var z1: float = lot["z1"]
	var open: Array = lot["o"]
	var w := x1 - x0
	var d := z1 - z0
	# Ab und zu bleibt eine Parzelle frei (Hof, Parkplatz) - nur wenn sie klein genug ist
	if rng.randf() < 0.05 and zone >= 2 and w * d < 500.0:
		return
	var floors := floors_for(zone)
	var sname := choose_style(zone, floors)
	var st: Dictionary = STYLES[sname]
	var fh: float = st["fh"]
	var gh := 4.4
	if st["cat"] == "garage":
		gh = 0.0
	if floors <= 3:
		gh = 3.6
	# Schmale Parzellen duerfen nicht zu hoch sein (Proportionen)
	var max_fl := int(maxf(3.0, minf(w, d) * 1.6 / fh * 3.2))
	floors = mini(floors, maxi(max_fl, 3))
	var total_h := gh + floors * fh
	var tint: Color = pick(TINTS_BRICK) if st["cat"] == "brick" else pick(TINTS_LIGHT)
	var bseed := rng.randf_range(0.06, 0.96)

	# Stufen (Rueckspruenge) bei hohen Gebaeuden
	var tiers := []
	var cur := [x0, z0, x1, z1]
	var y_base := 0.0
	var remaining := total_h
	if floors >= 12 and w > 18.0 and d > 18.0 and rng.randf() < 0.7:
		var h1 := gh + int(floors * rng.randf_range(0.45, 0.65)) * fh
		tiers.append([cur.duplicate(), 0.0, h1])
		var ins := Vector4(rng.randf_range(2.5, 5.5), rng.randf_range(2.5, 5.5), rng.randf_range(2.5, 5.5), rng.randf_range(2.5, 5.5))
		# nur an Seiten ohne Nachbarn zurueckspringen, sonst bleibt die Wand buendig
		var n := [cur[0] + (ins.x if open[3] else 0.0), cur[1] + (ins.y if open[1] else 0.0), cur[2] - (ins.z if open[2] else 0.0), cur[3] - (ins.w if open[0] else 0.0)]
		if n[2] - n[0] < 10.0 or n[3] - n[1] < 10.0:
			n = [cur[0] + 3.0, cur[1] + 3.0, cur[2] - 3.0, cur[3] - 3.0]
		var h2 := total_h
		if floors >= 22 and rng.randf() < 0.6:
			var h2a := h1 + int((total_h - h1) / fh * 0.55) * fh
			tiers.append([n.duplicate(), h1, h2a])
			var n2 := [n[0] + 2.5, n[1] + 2.5, n[2] - 2.5, n[3] - 2.5]
			if n2[2] - n2[0] > 9.0 and n2[3] - n2[1] > 9.0:
				tiers.append([n2, h2a, h2])
			else:
				tiers.append([n.duplicate(), h2a, h2])
		else:
			tiers.append([n, h1, h2])
	else:
		tiers.append([cur.duplicate(), 0.0, total_h])

	var idx := 0
	for t in tiers:
		var r: Array = t[0]
		var ya: float = t[1]
		var yb: float = t[2]
		var is_base := idx == 0
		var is_top := idx == tiers.size() - 1
		build_tier(mb, st, sname, r[0], r[1], r[2], r[3], ya, yb, tint, bseed, open if is_base else [true, true, true, true], is_base, is_top, floors)
		shapes.append([r[0], ya, r[1], r[2], yb, r[3]])
		idx += 1


# Eine Stufe (Quader) mit Fassaden, Gesims, Dach
func build_tier(mb, st: Dictionary, sname: String, x0: float, z0: float, x1: float, z1: float, y0: float, y1: float, tint: Color, bseed: float, open: Array, is_base: bool, is_top: bool, floors: int) -> void:
	var cat: String = st["cat"]
	var mat_up := mat_of(sname)
	var mat_shop := mat_of(st["shop"])
	var fh: float = st["fh"]
	var cw: float = st["cw"]
	var gh := 4.4 if cat != "garage" else 0.0
	if floors <= 3 and cat != "garage":
		gh = 3.6
	var solid := M.solid()
	# Seitenbeschreibung: [Basis, Richtung, Normale, Breite, offen?, Strassenseite?]
	var sides := [
		[Vector3(x0, 0, z1), Vector3.RIGHT, Vector3.BACK, x1 - x0, open[0]],
		[Vector3(x1, 0, z0), Vector3.LEFT, Vector3.FORWARD, x1 - x0, open[1]],
		[Vector3(x1, 0, z1), Vector3(0, 0, -1), Vector3.RIGHT, z1 - z0, open[2]],
		[Vector3(x0, 0, z0), Vector3(0, 0, 1), Vector3.LEFT, z1 - z0, open[3]],
	]
	var street_side := [absf(z1 - HALF) < 0.01, absf(z0 + HALF) < 0.01, absf(x1 - HALF) < 0.01, absf(x0 + HALF) < 0.01]
	if force_street:
		street_side = [true, true, true, true]
	var shop_y := 0.0
	var has_shop := is_base and cat != "garage" and cat != "glass" or (is_base and cat == "glass")
	if is_base:
		shop_y = gh
	var y_up0 := y0
	if is_base and has_shop:
		y_up0 = shop_y
	var nfl := maxf(1.0, roundf((y1 - y_up0) / fh))
	var fh_eff := (y1 - y_up0) / nfl
	for i in range(4):
		var s: Array = sides[i]
		var base: Vector3 = s[0]
		var dir: Vector3 = s[1]
		var n: Vector3 = s[2]
		var w: float = s[3]
		var is_open: bool = s[4]
		var is_street: bool = street_side[i] if is_base else true
		var col := Color(tint.r, tint.g, tint.b, bseed if is_open else 0.0)
		var ncol := maxf(1.0, roundf(w / cw))
		var cwe := w / ncol
		if is_base and has_shop:
			# Ladenzone nur auf Strassenseiten, sonst glatte Wand im Stil des Hauses
			if is_street:
				var ncs := maxf(1.0, roundf(w / 4.2))
				mb.wall(mat_shop, base, dir, w, 0.0, shop_y, n, 0.0, ncs, 0.0, 1.0, Vector2(w / ncs, shop_y), Color(tint.r, tint.g, tint.b, bseed))
			else:
				var blankc := Color(tint.r, tint.g, tint.b, 0.0)
				mb.wall(mat_up, base, dir, w, 0.0, shop_y, n, 0.0, ncol, 0.0, shop_y / fh, Vector2(cwe, fh), blankc if not is_open else col)
		mb.wall(mat_up, base, dir, w, y_up0, y1, n, 0.0, ncol, 0.0, nfl, Vector2(cwe, fh_eff), col)

	# Gesims / Dachkante
	var roof_y := y1
	var trim_col: Color = st["trim"]
	if cat in ["brick", "stone", "stucco"]:
		# Kranzgesims: Ring AUSSEN um die Waende (ueberdeckt die Dachflaeche nicht)
		var co := 0.30
		var cc := trim_col.darkened(0.05)
		mb.sbox(solid, x0 - co, y1 - 0.6, z1, x1 + co, y1 + 0.08, z1 + co, cc, 0.85)
		mb.sbox(solid, x0 - co, y1 - 0.6, z0 - co, x1 + co, y1 + 0.08, z0, cc, 0.85)
		mb.sbox(solid, x1, y1 - 0.6, z0, x1 + co, y1 + 0.08, z1, cc, 0.85)
		mb.sbox(solid, x0 - co, y1 - 0.6, z0, x0, y1 + 0.08, z1, cc, 0.85)
		parapet(mb, solid, x0, z0, x1, z1, y1, 0.9, 0.25, trim_col.darkened(0.12))
	else:
		var pa := 0.5 if cat != "garage" else 1.0
		var pc: Color = st["trim"] if cat != "glass" else Color(0.45, 0.47, 0.5)
		parapet(mb, solid, x0, z0, x1, z1, y1, pa, 0.3, pc)

	# Gesimsband ueber der Ladenzone (Schriftbandabschluss)
	if is_base and has_shop and cat != "glass":
		var sc := trim_col.darkened(0.25)
		var gx := 0.12
		mb.sbox(solid, x0 - gx, shop_y - 0.14, z0 - gx, x1 + gx, shop_y + 0.1, z1 + gx, sc, 0.8)
	# Sockel
	if is_base:
		mb.sbox(solid, x0 - 0.06, 0.0, z0 - 0.06, x1 + 0.06, 0.45, z1 + 0.06, Color(0.28, 0.27, 0.26), 0.85)

	# Dachflaeche
	var rc := Color(1, 1, 1)
	mb.top(M.roof(), x0, z0, x1, z1, roof_y, 1.0, Vector2.ONE, rc)

	if is_top:
		roof_props(mb, solid, x0 + 0.5, z0 + 0.5, x1 - 0.5, z1 - 0.5, roof_y, cat, floors)

	# Details nur im Kernbereich
	if detail and is_base:
		for i in range(4):
			var s: Array = sides[i]
			if not street_side[i]:
				continue
			var base: Vector3 = s[0]
			var dir: Vector3 = s[1]
			var n: Vector3 = s[2]
			var w: float = s[3]
			if has_shop and cat != "glass" and cat != "garage":
				shop_awnings(mb, solid, base, dir, n, w, shop_y)
			if cat == "brick" and rng.randf() < 0.55 and y1 > 9.0:
				fire_escape(mb, base, dir, n, w, shop_y, y1 - 0.6, fh_eff, cw)
			if cat == "glass":
				entrance_canopy(mb, solid, base, dir, n, w)


func parapet(mb, solid, x0: float, z0: float, x1: float, z1: float, y: float, h: float, t: float, col: Color) -> void:
	mb.sbox(solid, x0, y, z0, x1, y + h, z0 + t, col, 0.85)
	mb.sbox(solid, x0, y, z1 - t, x1, y + h, z1, col, 0.85)
	mb.sbox(solid, x0, y, z0 + t, x0 + t, y + h, z1 - t, col, 0.85)
	mb.sbox(solid, x1 - t, y, z0 + t, x1, y + h, z1 - t, col, 0.85)


# ------------------------------------------------------------------------------------------------
# Dachaufbauten
# ------------------------------------------------------------------------------------------------

func roof_props(mb, solid, x0: float, z0: float, x1: float, z1: float, y: float, cat: String, floors: int) -> void:
	var w := x1 - x0
	var d := z1 - z0
	if w < 4.0 or d < 4.0:
		return
	var grey := Color(0.62, 0.64, 0.66)
	# Treppenhaus / Fahrstuhlaufbau
	if floors > 4 and rng.randf() < 0.8:
		var bw := rng.randf_range(3.0, 5.0)
		var bd := rng.randf_range(3.0, 4.5)
		var bx := rng.randf_range(x0 + 1.0, x1 - bw - 1.0)
		var bz := rng.randf_range(z0 + 1.0, z1 - bd - 1.0)
		var bh := rng.randf_range(2.6, 3.4)
		var bc := Color(0.66, 0.64, 0.6) if cat != "glass" else Color(0.5, 0.52, 0.55)
		mb.sbox(solid, bx, y, bz, bx + bw, y + bh, bz + bd, bc, 0.85)
		mb.sbox(solid, bx - 0.15, y + bh, bz - 0.15, bx + bw + 0.15, y + bh + 0.2, bz + bd + 0.15, bc.darkened(0.1), 0.8)
		mb.sbox(solid, bx + bw * 0.4, y, bz + bd, bx + bw * 0.4 + 1.0, y + 2.1, bz + bd + 0.05, Color(0.3, 0.32, 0.3), 0.6, 0.3)
	# Klimaanlagen
	var n_ac := rng.randi_range(1, 5)
	for i in range(n_ac):
		var aw := rng.randf_range(1.6, 3.2)
		var ad := rng.randf_range(1.2, 2.2)
		var ah := rng.randf_range(0.9, 1.6)
		var ax := rng.randf_range(x0 + 0.5, x1 - aw - 0.5)
		var az := rng.randf_range(z0 + 0.5, z1 - ad - 0.5)
		mb.sbox(solid, ax, y, az, ax + aw, y + ah, az + ad, grey.darkened(rng.randf_range(0.0, 0.2)), 0.55, 0.5)
		# Ventilator
		var fr := minf(aw, ad) * 0.38
		mb.scyl(solid, Vector3(ax + aw * 0.5, y + ah, az + ad * 0.5), fr, fr, 0.05, Color(0.1, 0.1, 0.11), 10, 0.5, 0.4)
	# Wassertank (typisch New York) auf Ziegel-/Steinhaeusern
	if (cat == "brick" or cat == "stone") and rng.randf() < 0.45 and w > 7.0 and d > 7.0:
		var tx := rng.randf_range(x0 + 2.5, x1 - 2.5)
		var tz := rng.randf_range(z0 + 2.5, z1 - 2.5)
		var tr := rng.randf_range(1.2, 1.7)
		var th := rng.randf_range(2.4, 3.2)
		var legs := 2.2
		var steel := Color(0.12, 0.12, 0.13)
		for lx in [-1.0, 1.0]:
			for lz in [-1.0, 1.0]:
				mb.sbox(solid, tx + lx * tr * 0.75 - 0.1, y, tz + lz * tr * 0.75 - 0.1, tx + lx * tr * 0.75 + 0.1, y + legs, tz + lz * tr * 0.75 + 0.1, steel, 0.6, 0.6)
		mb.scyl(solid, Vector3(tx, y + legs, tz), tr, tr, th, Color(0.36, 0.25, 0.15), 14, 0.9)
		mb.scyl(solid, Vector3(tx, y + legs + th, tz), tr * 1.08, 0.2, 0.9, Color(0.24, 0.17, 0.11), 14, 0.9)
		for k in range(3):
			mb.scyl(solid, Vector3(tx, y + legs + 0.5 + k * th * 0.32, tz), tr * 1.02, tr * 1.02, 0.06, steel, 14, 0.6, 0.7, 0.0, false)
	# Schornsteine / Lueftungsrohre
	if rng.randf() < 0.5:
		for i in range(rng.randi_range(1, 3)):
			var px := rng.randf_range(x0 + 0.5, x1 - 0.5)
			var pz := rng.randf_range(z0 + 0.5, z1 - 0.5)
			var pr := rng.randf_range(0.2, 0.4)
			mb.scyl(solid, Vector3(px, y, pz), pr, pr, rng.randf_range(1.2, 2.5), Color(0.55, 0.55, 0.57), 8, 0.5, 0.6)
	# Antenne / Funkmast auf hohen Haeusern
	if floors > 10 and rng.randf() < 0.7:
		var mx := rng.randf_range(x0 + 1.0, x1 - 1.0)
		var mz := rng.randf_range(z0 + 1.0, z1 - 1.0)
		var mh := rng.randf_range(6.0, 14.0)
		mb.scyl(solid, Vector3(mx, y, mz), 0.12, 0.05, mh, Color(0.5, 0.5, 0.52), 6, 0.5, 0.7)
		mb.scyl(solid, Vector3(mx, y + mh, mz), 0.1, 0.1, 0.2, Color(1.0, 0.1, 0.05), 6, 0.3, 0.0, 6.0)
	# Solarpaneele
	if cat in ["concrete", "glass", "garage"] and rng.randf() < 0.35 and w > 9.0:
		var sx := rng.randf_range(x0 + 1.0, x1 - 6.0)
		var sz := rng.randf_range(z0 + 1.0, z1 - 3.0)
		for k in range(3):
			var zz := sz + k * 1.6
			mb.sq(solid, Vector3(sx, y + 0.3, zz + 1.2), Vector3(sx + 5.0, y + 0.3, zz + 1.2), Vector3(sx + 5.0, y + 1.0, zz), Vector3(sx, y + 1.0, zz), Color(0.08, 0.11, 0.2), 0.25, 0.5)
	# Dachterrasse / Kiesflaeche mit Geländer - Ersatz: Dachluke
	if rng.randf() < 0.4:
		var lx := rng.randf_range(x0 + 1.0, x1 - 2.5)
		var lz := rng.randf_range(z0 + 1.0, z1 - 2.5)
		mb.sbox(solid, lx, y, lz, lx + 1.6, y + 0.5, lz + 1.6, Color(0.5, 0.52, 0.55), 0.5, 0.4)
		mb.sbox(solid, lx + 0.1, y + 0.5, lz + 0.1, lx + 1.5, y + 0.58, lz + 1.5, Color(0.2, 0.3, 0.38), 0.1, 0.1)


# ------------------------------------------------------------------------------------------------
# Strassen-Details an der Fassade
# ------------------------------------------------------------------------------------------------

# Markisen ueber Ladenfenstern (gestreift)
func shop_awnings(mb, solid, base: Vector3, dir: Vector3, n: Vector3, w: float, y_shop: float) -> void:
	var ncs := maxf(1.0, roundf(w / 4.2))
	var bw := w / ncs
	var palette := [Color(0.62, 0.1, 0.1), Color(0.1, 0.25, 0.5), Color(0.1, 0.4, 0.22), Color(0.15, 0.14, 0.13), Color(0.85, 0.7, 0.12), Color(0.55, 0.12, 0.35)]
	var c1: Color = pick(palette)
	var c2 := Color(0.9, 0.88, 0.82) if rng.randf() < 0.7 else c1.darkened(0.35)
	for k in range(int(ncs)):
		if rng.randf() < 0.45:
			continue
		var center := base + dir * (bw * (k + 0.5))
		var half := bw * 0.5 - 0.25
		var strips := int(half * 2.0 / 0.4)
		var proj := 1.35
		var y_hi := 3.35
		var y_lo := 2.85
		var sw := half * 2.0 / strips
		for s in range(strips):
			var cc := c1 if s % 2 == 0 else c2
			var a := center + dir * (-half + s * sw)
			var b := a + dir * sw
			var p0 := Vector3(a.x, y_lo, a.z) + n * proj
			var p1 := Vector3(b.x, y_lo, b.z) + n * proj
			var p2 := Vector3(b.x, y_hi, b.z) + n * 0.05
			var p3 := Vector3(a.x, y_hi, a.z) + n * 0.05
			# Oberseite (zeigt nach oben/aussen)
			mb.sq(solid, p0, p1, p2, p3, cc, 0.9)
			# Unterseite (dunkel), damit man von unten nicht hindurchsieht
			mb.sq(solid, p1, p0, p3, p2, cc.darkened(0.45), 0.95)
			# Volant (senkrechter Streifen vorne)
			var v0 := Vector3(a.x, y_lo - 0.28, a.z) + n * proj
			var v1 := Vector3(b.x, y_lo - 0.28, b.z) + n * proj
			mb.sq(solid, v0, v1, p1, p0, cc, 0.9)


# Feuertreppe aus Eisengittern: Plattformen, Gelaender, Treppen
func fire_escape(mb, base: Vector3, dir: Vector3, n: Vector3, w: float, y_start: float, y_end: float, fh: float, cw: float) -> void:
	var iron_g := M.iron(0)
	var iron_r := M.iron(1)
	var depth := 1.05
	var width := 2.1
	var ncol := maxf(1.0, roundf(w / cw))
	var col_idx := rng.randi_range(1, maxi(1, int(ncol) - 2))
	var cwe := w / ncol
	var cen := base + dir * (cwe * (col_idx + 0.5))
	var a := cen - dir * (width * 0.5)
	var b := cen + dir * (width * 0.5)
	var nfloors := int((y_end - y_start) / fh)
	for f in range(1, nfloors + 1):
		var yy := y_start + f * fh - 0.9
		if yy > y_end:
			break
		# Plattform (Oberseite)
		var p0 := Vector3(a.x, yy, a.z) + n * depth
		var p1 := Vector3(b.x, yy, b.z) + n * depth
		var p2 := Vector3(b.x, yy, b.z) + n * 0.03
		var p3 := Vector3(a.x, yy, a.z) + n * 0.03
		mb.quad(iron_g, p0, p1, p2, p3, Vector3.UP, 0.0, width, 0.0, depth)
		# Gelaender vorne und seitlich
		var q0 := Vector3(a.x, yy, a.z) + n * depth
		var q1 := Vector3(b.x, yy, b.z) + n * depth
		mb.quad(iron_r, q0, q1, q1 + Vector3.UP, q0 + Vector3.UP, n, 0.0, width, 0.0, 1.0)
		var sa := Vector3(a.x, yy, a.z)
		mb.quad(iron_r, sa + n * 0.03, sa + n * depth, sa + n * depth + Vector3.UP, sa + n * 0.03 + Vector3.UP, -dir, 0.0, depth, 0.0, 1.0)
		var sb := Vector3(b.x, yy, b.z)
		mb.quad(iron_r, sb + n * depth, sb + n * 0.03, sb + n * 0.03 + Vector3.UP, sb + n * depth + Vector3.UP, dir, 0.0, depth, 0.0, 1.0)
		# Treppe zum naechsten Geschoss (abwechselnd links/rechts)
		if f < nfloors:
			var side := 1.0 if f % 2 == 0 else -1.0
			var sx := cen + dir * (side * width * 0.25)
			var t0 := Vector3(sx.x, yy, sx.z) + n * 0.08
			var t1 := Vector3(sx.x, yy + fh, sx.z) + n * (depth - 0.02)
			var tw := dir * 0.45
			mb.quad(iron_g, t0 - tw, t0 + tw, t1 + tw, t1 - tw, Vector3.UP, 0.0, 0.9, 0.0, (t1 - t0).length())


func entrance_canopy(mb, solid, base: Vector3, dir: Vector3, n: Vector3, w: float) -> void:
	var c := base + dir * (w * 0.5)
	var half := minf(w * 0.5 - 1.0, 5.0)
	var p0 := Vector3(c.x - dir.x * half, 4.4, c.z - dir.z * half) + n * 3.5
	var p1 := Vector3(c.x + dir.x * half, 4.4, c.z + dir.z * half) + n * 3.5
	var p2 := Vector3(c.x + dir.x * half, 4.55, c.z + dir.z * half)
	var p3 := Vector3(c.x - dir.x * half, 4.55, c.z - dir.z * half)
	mb.sq(solid, p0, p1, p2, p3, Color(0.2, 0.21, 0.23), 0.4, 0.6)
	mb.sq(solid, p1, p0, p3, p2, Color(0.12, 0.12, 0.13), 0.5, 0.6)
	for k in [-1.0, 1.0]:
		var pc: Vector3 = c + dir * (k * (half - 0.2)) + n * 3.3
		mb.scyl(solid, Vector3(pc.x, 0.0, pc.z), 0.1, 0.1, 4.45, Color(0.6, 0.62, 0.64), 8, 0.35, 0.8)
