extends RefCounted
# Gebaeude der Stadt: Parzellen, Hoehen, Stile, Gesimse, Dachaufbauten, Feuertreppen, Vordaecher, Wolkenkratzer, Times Square.
# Pro Block: Huelle (mb, wirft Schatten), Details (md, nur in der Naehe sichtbar), Reklame (ms). Kollision aus Quadern (Daecher begehbar).

const MB = preload("res://scripts/city_mesh.gd")
const M = preload("res://scripts/city_mats.gd")
const Signs = preload("res://scripts/city_signs.gd")
const Rows = preload("res://scripts/city_rows.gd")
const Towers = preload("res://scripts/city_towers.gd")
const Plan = preload("res://scripts/city_plan.gd")
const Street = preload("res://scripts/city_street.gd")

const HALF := 26.0  # bebaubarer Bereich je Block: -26 .. +26
const DETAIL_RANGE := 240.0

# Stile: kind 0 Ziegel, 1 Naturstein, 2 Beton-Fensterband, 3 Glas-Vorhangfassade, 4 Putz, 5 Laden, 6 Parkhaus, 7 Art-Deco-Pfeiler
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
	"glass_mirror": {"kind": 3, "wall": Color(0.20, 0.25, 0.30), "trim": Color(0.55, 0.57, 0.6), "frame": Color(0.7, 0.72, 0.74), "glass": Color(0.42, 0.58, 0.72), "win": Vector2(1.0, 1.0), "sill": 0.95, "gm": 1.0, "gr": 0.03, "fh": 3.9, "cw": 1.7, "shop": "shop_glass", "cat": "glass"},
	"glass_bronze": {"kind": 3, "wall": Color(0.16, 0.13, 0.10), "trim": Color(0.4, 0.36, 0.3), "frame": Color(0.3, 0.26, 0.2), "glass": Color(0.34, 0.30, 0.22), "win": Vector2(1.0, 1.0), "sill": 0.95, "gm": 0.85, "gr": 0.05, "fh": 3.9, "cw": 1.8, "shop": "shop_glass", "cat": "glass"},
	"stucco_cream": {"kind": 4, "wall": Color(0.84, 0.78, 0.66), "trim": Color(0.95, 0.94, 0.9), "frame": Color(0.92, 0.92, 0.9), "glass": Color(0.07, 0.10, 0.15), "win": Vector2(1.25, 1.6), "sill": 1.0, "gm": 0.12, "fh": 3.3, "cw": 3.3, "shop": "shop_brick", "cat": "stucco"},
	"stucco_blue": {"kind": 4, "wall": Color(0.62, 0.69, 0.75), "trim": Color(0.95, 0.95, 0.93), "frame": Color(0.94, 0.94, 0.92), "glass": Color(0.07, 0.10, 0.15), "win": Vector2(1.25, 1.6), "sill": 1.0, "gm": 0.12, "fh": 3.3, "cw": 3.3, "shop": "shop_dark", "cat": "stucco"},
	"stucco_terra": {"kind": 4, "wall": Color(0.74, 0.50, 0.40), "trim": Color(0.95, 0.92, 0.85), "frame": Color(0.2, 0.2, 0.2), "glass": Color(0.07, 0.10, 0.15), "win": Vector2(1.2, 1.6), "sill": 1.0, "gm": 0.12, "fh": 3.3, "cw": 3.2, "shop": "shop_stone", "cat": "stucco"},
	"stucco_grey": {"kind": 4, "wall": Color(0.72, 0.72, 0.70), "trim": Color(0.95, 0.95, 0.93), "frame": Color(0.14, 0.15, 0.17), "glass": Color(0.07, 0.10, 0.15), "win": Vector2(1.3, 1.65), "sill": 1.0, "gm": 0.12, "fh": 3.3, "cw": 3.4, "shop": "shop_dark", "cat": "stucco"},
	"deco_lime": {"kind": 7, "wall": Color(0.78, 0.73, 0.62), "trim": Color(0.25, 0.28, 0.30), "frame": Color(0.55, 0.58, 0.60), "glass": Color(0.07, 0.10, 0.15), "win": Vector2(1.0, 1.0), "sill": 1.0, "gm": 0.35, "fh": 3.9, "cw": 3.1, "shop": "shop_stone", "cat": "deco"},
	"deco_buff": {"kind": 7, "wall": Color(0.70, 0.58, 0.41), "trim": Color(0.33, 0.28, 0.21), "frame": Color(0.50, 0.44, 0.34), "glass": Color(0.07, 0.10, 0.15), "win": Vector2(1.0, 1.0), "sill": 1.0, "gm": 0.35, "fh": 3.9, "cw": 3.1, "shop": "shop_stone", "cat": "deco"},
	"deco_grey": {"kind": 7, "wall": Color(0.60, 0.61, 0.62), "trim": Color(0.16, 0.18, 0.20), "frame": Color(0.50, 0.52, 0.55), "glass": Color(0.08, 0.11, 0.16), "win": Vector2(1.0, 1.0), "sill": 1.0, "gm": 0.35, "fh": 3.8, "cw": 3.0, "shop": "shop_dark", "cat": "deco"},
	"deco_red": {"kind": 7, "wall": Color(0.50, 0.26, 0.20), "trim": Color(0.20, 0.17, 0.15), "frame": Color(0.45, 0.40, 0.34), "glass": Color(0.07, 0.10, 0.15), "win": Vector2(1.0, 1.0), "sill": 1.0, "gm": 0.3, "fh": 3.8, "cw": 3.0, "shop": "shop_brick", "cat": "deco"},
	"garage": {"kind": 6, "wall": Color(0.66, 0.65, 0.62), "trim": Color(0.55, 0.55, 0.55), "frame": Color(0.2, 0.2, 0.2), "glass": Color(0.05, 0.05, 0.06), "win": Vector2(1.0, 1.0), "sill": 1.0, "gm": 0.0, "fh": 3.0, "cw": 5.0, "shop": "shop_dark", "cat": "garage"},
	"shop_dark": {"kind": 5, "wall": Color(0.22, 0.20, 0.19), "trim": Color(0.5, 0.5, 0.5), "frame": Color(0.12, 0.12, 0.13), "glass": Color(0.08, 0.11, 0.15), "gm": 0.3},
	"shop_stone": {"kind": 5, "wall": Color(0.62, 0.58, 0.50), "trim": Color(0.5, 0.5, 0.5), "frame": Color(0.14, 0.13, 0.12), "glass": Color(0.08, 0.11, 0.15), "gm": 0.3},
	"shop_brick": {"kind": 5, "wall": Color(0.42, 0.21, 0.16), "trim": Color(0.5, 0.5, 0.5), "frame": Color(0.1, 0.1, 0.1), "glass": Color(0.08, 0.11, 0.15), "gm": 0.3},
	"shop_glass": {"kind": 5, "wall": Color(0.45, 0.46, 0.48), "trim": Color(0.5, 0.5, 0.5), "frame": Color(0.5, 0.52, 0.54), "glass": Color(0.20, 0.30, 0.38), "gm": 0.5},
}

const DECO_STYLES := ["deco_lime", "deco_buff", "deco_grey", "deco_red", "deco_lime"]
const TINTS_BRICK := [Color(1, 1, 1), Color(1.1, 0.98, 0.92), Color(0.92, 0.95, 1.0), Color(1.15, 1.05, 0.95), Color(0.9, 0.9, 0.9)]
const TINTS_LIGHT := [Color(1, 1, 1), Color(1.04, 1.0, 0.94), Color(0.96, 0.98, 1.02), Color(1.0, 0.97, 0.93)]

var rng := RandomNumberGenerator.new()
var seed_base := 1234
var detail := true
var force_street := false
var mb  # Huelle
var md  # Details
var ms  # Reklame (leuchtend)
var shapes := []
var hulls := []
var props  # CityProps (Baeume)
var bcx := 0.0
var bcz := 0.0
var bix := 0
var biz := 0


func _init(seed_value: int = 1234) -> void:
	seed_base = seed_value
	rng.seed = seed_value


func pick(a: Array):
	return a[rng.randi() % a.size()]


# Dachfarbe als Farbton-Faktor fuer den Dach-Shader: dunkle Teerpappe, helle Beschichtung, Gruendach, rostrot
func roof_col() -> Color:
	var r := rng.randf()
	if r < 0.55:
		return Color(1, 1, 1)
	if r < 0.70:
		return Color(2.3, 2.3, 2.2)
	if r < 0.78:
		return Color(0.7, 1.7, 0.6)
	if r < 0.88:
		return Color(1.5, 1.15, 0.9)
	return Color(1.7, 1.0, 0.8)


func mat_of(name: String) -> ShaderMaterial:
	return M.facade(name, STYLES[name])


# ------------------------------------------------------------------------------------------------
# Block-Aufteilung in Parzellen
# ------------------------------------------------------------------------------------------------

func split_lots(x0: float, z0: float, x1: float, z1: float, open: Array, depth: int, out: Array, max_size: float, min_size: float, p_split: float = 0.55) -> void:
	var w := x1 - x0
	var d := z1 - z0
	var can_x := w >= min_size * 2.0 + 0.5
	var can_z := d >= min_size * 2.0 + 0.5
	var want_split := (maxf(w, d) > max_size) or (depth < 2 and rng.randf() < p_split)
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
		split_lots(x0, z0, xs - gap * 0.5, z1, oa, depth + 1, out, max_size, min_size, p_split)
		split_lots(xs + gap * 0.5, z0, x1, z1, ob, depth + 1, out, max_size, min_size, p_split)
	else:
		var lo := z0 + min_size
		var hi := z1 - min_size
		var zs := snappedf(rng.randf_range(lo + gap, hi - gap), 1.0)
		# +z = Seite z1, -z = Seite z0
		var oa: Array = [gap > 0.0, open[1], open[2], open[3]]
		var ob: Array = [open[0], gap > 0.0, open[2], open[3]]
		split_lots(x0, z0, x1, zs - gap * 0.5, oa, depth + 1, out, max_size, min_size, p_split)
		split_lots(x0, zs + gap * 0.5, x1, z1, ob, depth + 1, out, max_size, min_size, p_split)


# ------------------------------------------------------------------------------------------------
# Block bauen
# ------------------------------------------------------------------------------------------------

func begin(cx: float, cz: float, ix: int, iz: int, zone: int) -> void:
	bcx = cx
	bcz = cz
	bix = ix
	biz = iz
	rng.seed = seed_base + ix * 7919 + iz * 104729
	detail = zone <= 3
	mb = MB.new()
	md = MB.new()
	ms = MB.new()
	shapes = []
	hulls = []


func finish(parent: Node3D, node_name: String) -> Node3D:
	var node := Node3D.new()
	node.position = Vector3(bcx, 0, bcz)
	node.name = node_name
	parent.add_child(node)
	mb.instance(node, "Buildings")
	if not md.order.is_empty():
		var mi: MeshInstance3D = md.instance(node, "Detail", false)
		mi.visibility_range_end = DETAIL_RANGE
		mi.visibility_range_end_margin = 20.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	if not ms.order.is_empty():
		ms.instance(node, "Signs", false)
	add_collision(node, shapes, hulls)
	return node


# zone: 0 = Zentrum, 1 = Innenring, 2 = mittlerer Ring, 3+ = Aussenring
func build_block(parent: Node3D, cx: float, cz: float, zone: int, is_core: bool, ix: int = 0, iz: int = 0) -> Node3D:
	begin(cx, cz, ix, iz, zone)
	var kind := Plan.kind(ix, iz)
	var lots := []
	match kind:
		"times":
			build_times(zone)
		"wedge":
			build_wedge()
		"rows":
			Rows.build(self, zone)
		"tower":
			split_lots(-HALF, -HALF, HALF, HALF, [true, true, true, true], 0, lots, 56.0, 20.0, 0.4)
		_:
			split_lots(-HALF, -HALF, HALF, HALF, [true, true, true, true], 0, lots, 30.0, 13.0)
	for lot in lots:
		build_lot(lot, zone, kind)
	return finish(parent, "Block_%d_%d" % [int(cx), int(cz)])


# Wahrzeichen im Zentrum: gestaffelter Glasturm mit leuchtendem "A", Antenne und Positionslichtern
func build_landmark(parent: Node3D, cx: float, cz: float) -> Node3D:
	begin(cx, cz, 0, 0, 0)
	detail = true
	force_street = true
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
			ms.sq(solid, pts[0], pts[1], pts[2], pts[3], Color(0.75, 0.9, 1.0), 0.3, 0.0, 3.0)
	# Antenne und rote Positionslichter
	mb.tube(solid, Vector3(0, 158, 0), Vector3(0, 190, 0), 0.5, 0.08, 8, Color(0.7, 0.72, 0.75), 0.4, 0.7)
	mb.sbox(solid, -0.25, 190.0, -0.25, 0.25, 190.6, 0.25, Color(1.0, 0.1, 0.05), 0.3, 0.0, 8.0)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			mb.sbox(solid, sx * 7.3 - 0.2, 158.0, sz * 7.3 - 0.2, sx * 7.3 + 0.2, 158.4, sz * 7.3 + 0.2, Color(1.0, 0.1, 0.05), 0.3, 0.0, 6.0)
	return finish(parent, "Landmark")


func add_collision(node: Node3D, shp: Array, hl: Array = []) -> void:
	var body := StaticBody3D.new()
	body.name = "Collision"
	node.add_child(body)
	for s in shp:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(s[3] - s[0], s[4] - s[1], s[5] - s[2])
		cs.shape = bs
		cs.position = Vector3((s[0] + s[3]) * 0.5, (s[1] + s[4]) * 0.5, (s[2] + s[5]) * 0.5)
		body.add_child(cs)
	for pts in hl:
		var cs := CollisionShape3D.new()
		var sh := ConvexPolygonShape3D.new()
		sh.points = pts
		cs.shape = sh
		body.add_child(cs)


# ------------------------------------------------------------------------------------------------
# Stil- und Hoehenwahl
# ------------------------------------------------------------------------------------------------

func choose_style(zone: int, floors: int) -> String:
	var r := rng.randf()
	if floors <= 3:
		return pick(["stucco_cream", "stucco_grey", "stucco_terra", "brick_red", "brick_tan", "brick_brown", "brick_dark"])
	if floors <= 8:
		if r < 0.46:
			return pick(["brick_red", "brick_brown", "brick_tan", "brick_dark", "brick_red"])
		if r < 0.66:
			return pick(["stone_lime", "stone_grey", "stone_rose"])
		if r < 0.78:
			return pick(["stucco_cream", "stucco_grey", "stucco_terra", "stucco_blue"])
		if r < 0.9:
			return pick(["concrete_a", "concrete_b"])
		return "garage" if rng.randf() < 0.5 else "glass_blue"
	if floors <= 16:
		if r < 0.28:
			return pick(["stone_lime", "stone_grey", "stone_rose"])
		if r < 0.45:
			return pick(["concrete_a", "concrete_b"])
		if r < 0.60:
			return pick(["brick_red", "brick_brown", "brick_dark"])
		if r < 0.70:
			return pick(DECO_STYLES)
		if r < 0.75:
			return "garage"
		return pick(["glass_blue", "glass_green", "glass_dark", "glass_mirror", "glass_bronze"])
	if r < 0.45:
		return pick(["glass_blue", "glass_green", "glass_dark", "glass_mirror", "glass_bronze"])
	if r < 0.72:
		return pick(DECO_STYLES)
	if r < 0.88:
		return pick(["stone_lime", "stone_grey"])
	return pick(["concrete_a", "concrete_b"])


func floors_for(zone: int, kind: String) -> int:
	var f := 4
	if kind == "tower":
		match zone:
			0, 1:
				f = rng.randi_range(26, 46)
			2:
				f = rng.randi_range(18, 36)
			_:
				f = rng.randi_range(14, 24)
		return f
	match zone:
		0:
			f = rng.randi_range(14, 28)
		1:
			f = rng.randi_range(10, 20)
			if rng.randf() < 0.15:
				f = rng.randi_range(4, 6)
		2:
			f = rng.randi_range(6, 14)
			if rng.randf() < 0.1:
				f = rng.randi_range(14, 20)
		_:
			f = rng.randi_range(3, 8)
			if rng.randf() < 0.07:
				f = rng.randi_range(9, 14)
	return f


func build_lot(lot: Dictionary, zone: int, kind: String) -> void:
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
	var floors := floors_for(zone, kind)
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
	var tint: Color = pick(TINTS_BRICK) if st["cat"] == "brick" else pick(TINTS_LIGHT)
	var bseed := rng.randf_range(0.06, 0.96)
	# Hohe Parzellen: Art-Deco-Turm mit Rueckspruengen und Krone
	if floors >= 18 and w >= 20.0 and d >= 20.0 and rng.randf() < 0.62:
		deco_tower(x0, z0, x1, z1, floors, open, pick(DECO_STYLES), tint, bseed)
		return
	var total_h := gh + floors * fh

	# Stufen (Rueckspruenge) bei hohen Gebaeuden
	var tiers := []
	var cur := [x0, z0, x1, z1]
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
	# Hohe Glas-/Betonturme bekommen oft eine Krone oder Reklame
	if floors >= 20 and detail:
		var tt: Array = tiers[tiers.size() - 1]
		var rr: Array = tt[0]
		if rr[2] - rr[0] >= 12.0 and rng.randf() < 0.5:
			Towers.crown(md, rng, rr[0], rr[1], rr[2], rr[3], tt[2], st["trim"], pick([2, 3]))


# Wolkenkratzer mit 3-4 Rueckspruengen (Art Deco) und Krone
func deco_tower(x0: float, z0: float, x1: float, z1: float, floors: int, open: Array, sname: String, tint: Color, bseed: float, crown_style: int = -1) -> void:
	var st: Dictionary = STYLES[sname]
	var fh: float = st["fh"]
	var gh := 4.4
	var w := x1 - x0
	var d := z1 - z0
	var ntier := 4 if minf(w, d) >= 26.0 else 3
	var fr := [0.34, 0.58, 0.80, 1.0]
	if ntier == 3:
		fr = [0.45, 0.75, 1.0]
	var cur := [x0, z0, x1, z1]
	var y := 0.0
	var fl_prev := 0
	for t in range(ntier):
		var fl_end := maxi(fl_prev + 2, int(floors * fr[t]))
		var yb := gh + fl_end * fh
		var is_base := t == 0
		var is_top := t == ntier - 1
		var all_open := [true, true, true, true]
		build_tier(mb, st, sname, cur[0], cur[1], cur[2], cur[3], y, yb, tint, bseed, open if is_base else all_open, is_base, false, floors)
		shapes.append([cur[0], y, cur[1], cur[2], yb, cur[3]])
		y = yb
		fl_prev = fl_end
		if not is_top:
			var ins := rng.randf_range(2.6, 4.2)
			var n := [cur[0] + ins, cur[1] + ins, cur[2] - ins, cur[3] - ins]
			if n[2] - n[0] < 9.0 or n[3] - n[1] < 9.0:
				n = [cur[0] + 1.5, cur[1] + 1.5, cur[2] - 1.5, cur[3] - 1.5]
			cur = n
	# Dach der obersten Stufe + Krone
	var solid := M.solid()
	var trim: Color = st["wall"]
	mb.top(M.roof(), cur[0], cur[1], cur[2], cur[3], y, 1.0, Vector2.ONE, roof_col())
	parapet(mb, solid, cur[0], cur[1], cur[2], cur[3], y, 0.8, 0.3, trim.darkened(0.1))
	var cs := crown_style if crown_style >= 0 else rng.randi() % 3
	Towers.crown(mb, rng, cur[0] + 0.3, cur[1] + 0.3, cur[2] - 0.3, cur[3] - 0.3, y, trim, cs)
	# Kronen-Kollision: unterster Block der Krone
	shapes.append([cur[0] + 1.2, y, cur[1] + 1.2, cur[2] - 1.2, y + 3.0, cur[3] - 1.2])


# Eine Stufe (Quader) mit Fassaden, Gesims, Dach
func build_tier(mbx, st: Dictionary, sname: String, x0: float, z0: float, x1: float, z1: float, y0: float, y1: float, tint: Color, bseed: float, open: Array, is_base: bool, is_top: bool, floors: int) -> void:
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
	var has_shop := is_base and cat != "garage"
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
				mbx.wall(mat_shop, base, dir, w, 0.0, shop_y, n, 0.0, ncs, 0.0, 1.0, Vector2(w / ncs, shop_y), Color(tint.r, tint.g, tint.b, bseed))
			else:
				var blankc := Color(tint.r, tint.g, tint.b, 0.0)
				mbx.wall(mat_up, base, dir, w, 0.0, shop_y, n, 0.0, ncol, 0.0, shop_y / fh, Vector2(cwe, fh), blankc if not is_open else col)
		mbx.wall(mat_up, base, dir, w, y_up0, y1, n, 0.0, ncol, 0.0, nfl, Vector2(cwe, fh_eff), col)

	# Gesims / Dachkante
	var roof_y := y1
	var trim_col: Color = st["trim"]
	if cat in ["brick", "stone", "stucco"]:
		# Kranzgesims: Ring AUSSEN um die Waende (ueberdeckt die Dachflaeche nicht)
		var co := 0.30
		var cc := trim_col.darkened(0.05)
		mbx.sbox(solid, x0 - co, y1 - 0.6, z1, x1 + co, y1 + 0.08, z1 + co, cc, 0.85)
		mbx.sbox(solid, x0 - co, y1 - 0.6, z0 - co, x1 + co, y1 + 0.08, z0, cc, 0.85)
		mbx.sbox(solid, x1, y1 - 0.6, z0, x1 + co, y1 + 0.08, z1, cc, 0.85)
		mbx.sbox(solid, x0 - co, y1 - 0.6, z0, x0, y1 + 0.08, z1, cc, 0.85)
		parapet(mbx, solid, x0, z0, x1, z1, y1, 0.9, 0.25, trim_col.darkened(0.12))
	elif cat == "deco":
		var co2 := 0.4
		var wc: Color = st["wall"]
		mbx.sbox(solid, x0 - co2, y1 - 0.9, z1, x1 + co2, y1 + 0.1, z1 + co2, wc.darkened(0.05), 0.85)
		mbx.sbox(solid, x0 - co2, y1 - 0.9, z0 - co2, x1 + co2, y1 + 0.1, z0, wc.darkened(0.05), 0.85)
		mbx.sbox(solid, x1, y1 - 0.9, z0, x1 + co2, y1 + 0.1, z1, wc.darkened(0.05), 0.85)
		mbx.sbox(solid, x0 - co2, y1 - 0.9, z0, x0, y1 + 0.1, z1, wc.darkened(0.05), 0.85)
		parapet(mbx, solid, x0, z0, x1, z1, y1, 0.8, 0.3, wc.darkened(0.1))
	else:
		var pa := 0.5 if cat != "garage" else 1.0
		var pc: Color = st["trim"] if cat != "glass" else Color(0.45, 0.47, 0.5)
		parapet(mbx, solid, x0, z0, x1, z1, y1, pa, 0.3, pc)

	# Gesimsband ueber der Ladenzone (Schriftbandabschluss)
	if is_base and has_shop and cat != "glass":
		var sc := trim_col.darkened(0.25)
		var gx := 0.12
		mbx.sbox(solid, x0 - gx, shop_y - 0.14, z0 - gx, x1 + gx, shop_y + 0.1, z1 + gx, sc, 0.8)
	# Gurtgesimse bei Stein- und Deco-Tuermen
	if (cat == "stone" or cat == "deco") and (y1 - y_up0) > 22.0:
		var wcol: Color = st["wall"]
		var k := 6
		while y_up0 + k * fh_eff < y1 - 3.0:
			var yy := y_up0 + k * fh_eff - 0.2
			var gx2 := 0.16
			mbx.sbox(solid, x0 - gx2, yy, z0 - gx2, x1 + gx2, yy + 0.4, z1 + gx2, wcol.darkened(0.08), 0.85)
			k += 6
	# Sockel
	if is_base:
		mbx.sbox(solid, x0 - 0.06, 0.0, z0 - 0.06, x1 + 0.06, 0.45, z1 + 0.06, Color(0.28, 0.27, 0.26), 0.85)

	# Dachflaeche
	if not (cat == "deco" and not is_top):
		mbx.top(M.roof(), x0, z0, x1, z1, roof_y, 1.0, Vector2.ONE, roof_col())

	if is_top and cat != "deco":
		roof_props(md if detail else null, solid, x0 + 0.5, z0 + 0.5, x1 - 0.5, z1 - 0.5, roof_y, cat, floors)

	# Details nur im Nahbereich
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
				shop_awnings(md, solid, base, dir, n, w, shop_y)
			if has_shop and cat != "garage":
				shop_signs(md, base, dir, n, w, shop_y)
			if cat == "brick" and rng.randf() < 0.55 and y1 > 9.0:
				fire_escape(md, base, dir, n, w, shop_y, y1 - 0.6, fh_eff, cw)
			elif cat in ["brick", "stone", "stucco", "concrete"] and w > 16.0 and y1 > 14.0 and rng.randf() < 0.22:
				var sw := minf(w - 6.0, rng.randf_range(10.0, 18.0))
				var sx := rng.randf_range(2.0, w - sw - 2.0)
				var sh := minf(y1 - shop_y - 2.0, rng.randf_range(14.0, 30.0))
				Street.scaffold(md, base + dir * sx + Vector3.UP * 3.7, dir, n, sw, sh, Color(0.2, 0.4, 0.9, 1.0 if rng.randf() < 0.5 else 0.0))
			if cat == "glass":
				entrance_canopy(md, solid, base, dir, n, w)


func parapet(mbx, solid, x0: float, z0: float, x1: float, z1: float, y: float, h: float, t: float, col: Color) -> void:
	mbx.sbox(solid, x0, y, z0, x1, y + h, z0 + t, col, 0.85)
	mbx.sbox(solid, x0, y, z1 - t, x1, y + h, z1, col, 0.85)
	mbx.sbox(solid, x0, y, z0 + t, x0 + t, y + h, z1 - t, col, 0.85)
	mbx.sbox(solid, x1 - t, y, z0 + t, x1, y + h, z1 - t, col, 0.85)


# ------------------------------------------------------------------------------------------------
# Dachaufbauten
# ------------------------------------------------------------------------------------------------

func water_tank(mbx, solid, tx: float, tz: float, y: float, tr: float, th: float) -> void:
	var legs := 2.2
	var steel := Color(0.12, 0.12, 0.13)
	for lx in [-1.0, 1.0]:
		for lz in [-1.0, 1.0]:
			mbx.sbox(solid, tx + lx * tr * 0.75 - 0.1, y, tz + lz * tr * 0.75 - 0.1, tx + lx * tr * 0.75 + 0.1, y + legs, tz + lz * tr * 0.75 + 0.1, steel, 0.6, 0.6)
	# Querverstrebung
	mbx.sbox(solid, tx - tr * 0.8, y + 0.8, tz - 0.03, tx + tr * 0.8, y + 0.9, tz + 0.03, steel, 0.6, 0.6)
	mbx.sbox(solid, tx - 0.03, y + 0.8, tz - tr * 0.8, tx + 0.03, y + 0.9, tz + tr * 0.8, steel, 0.6, 0.6)
	mbx.scyl(solid, Vector3(tx, y + legs, tz), tr, tr, th, Color(0.36, 0.25, 0.15), 14, 0.9)
	mbx.scyl(solid, Vector3(tx, y + legs + th, tz), tr * 1.08, 0.2, 0.9, Color(0.24, 0.17, 0.11), 14, 0.9)
	for k in range(3):
		mbx.scyl(solid, Vector3(tx, y + legs + 0.5 + k * th * 0.32, tz), tr * 1.02, tr * 1.02, 0.06, steel, 14, 0.6, 0.7, 0.0, false)


func mini_roof(x0: float, z0: float, x1: float, z1: float, y: float) -> void:
	if not detail:
		return
	var solid := M.solid()
	var w := x1 - x0
	var d := z1 - z0
	if w < 2.5 or d < 2.5:
		return
	if rng.randf() < 0.65:
		var bx := rng.randf_range(x0, x1 - 1.8)
		var bz := rng.randf_range(z0, z1 - 1.8)
		md.sbox(solid, bx, y, bz, bx + 1.8, y + 2.3, bz + 1.6, Color(0.62, 0.6, 0.57), 0.85)
		md.sbox(solid, bx - 0.1, y + 2.3, bz - 0.1, bx + 1.9, y + 2.45, bz + 1.7, Color(0.5, 0.48, 0.45), 0.8)
		md.sbox(solid, bx + 0.5, y, bz + 1.6, bx + 1.4, y + 1.9, bz + 1.64, Color(0.25, 0.27, 0.26), 0.6, 0.3)
	if rng.randf() < 0.5:
		var ax := rng.randf_range(x0, x1 - 1.4)
		var az := rng.randf_range(z0, z1 - 1.2)
		md.sbox(solid, ax, y, az, ax + 1.4, y + 0.9, az + 1.2, Color(0.64, 0.66, 0.68), 0.55, 0.5)
		md.scyl(solid, Vector3(ax + 0.7, y + 0.9, az + 0.6), 0.45, 0.45, 0.05, Color(0.1, 0.1, 0.11), 10, 0.5, 0.4)
	if rng.randf() < 0.28 and w > 4.0 and d > 4.0:
		water_tank(md, solid, rng.randf_range(x0 + 1.6, x1 - 1.6), rng.randf_range(z0 + 1.6, z1 - 1.6), y, rng.randf_range(1.1, 1.4), rng.randf_range(2.2, 2.7))
	if rng.randf() < 0.35:
		var px := rng.randf_range(x0 + 0.3, x1 - 0.3)
		var pz := rng.randf_range(z0 + 0.3, z1 - 0.3)
		md.scyl(solid, Vector3(px, y, pz), 0.25, 0.25, rng.randf_range(1.5, 2.8), Color(0.55, 0.55, 0.57), 8, 0.5, 0.6)


func roof_props(mbx, solid, x0: float, z0: float, x1: float, z1: float, y: float, cat: String, floors: int) -> void:
	if mbx == null:
		return
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
		mbx.sbox(solid, bx, y, bz, bx + bw, y + bh, bz + bd, bc, 0.85)
		mbx.sbox(solid, bx - 0.15, y + bh, bz - 0.15, bx + bw + 0.15, y + bh + 0.2, bz + bd + 0.15, bc.darkened(0.1), 0.8)
		mbx.sbox(solid, bx + bw * 0.4, y, bz + bd, bx + bw * 0.4 + 1.0, y + 2.1, bz + bd + 0.05, Color(0.3, 0.32, 0.3), 0.6, 0.3)
	# Klimaanlagen
	var n_ac := rng.randi_range(1, 5)
	for i in range(n_ac):
		var aw := rng.randf_range(1.6, 3.2)
		var ad := rng.randf_range(1.2, 2.2)
		var ah := rng.randf_range(0.9, 1.6)
		var ax := rng.randf_range(x0 + 0.5, x1 - aw - 0.5)
		var az := rng.randf_range(z0 + 0.5, z1 - ad - 0.5)
		mbx.sbox(solid, ax, y, az, ax + aw, y + ah, az + ad, grey.darkened(rng.randf_range(0.0, 0.2)), 0.55, 0.5)
		var fr := minf(aw, ad) * 0.38
		mbx.scyl(solid, Vector3(ax + aw * 0.5, y + ah, az + ad * 0.5), fr, fr, 0.05, Color(0.1, 0.1, 0.11), 10, 0.5, 0.4)
	# Wassertank (typisch New York)
	if (cat == "brick" or cat == "stone" or cat == "stucco" or cat == "concrete") and floors < 22 and rng.randf() < 0.6 and w > 7.0 and d > 7.0:
		for k in range(1 + int(rng.randf() < 0.3)):
			water_tank(mbx, solid, rng.randf_range(x0 + 2.5, x1 - 2.5), rng.randf_range(z0 + 2.5, z1 - 2.5), y, rng.randf_range(1.2, 1.7), rng.randf_range(2.4, 3.2))
	# Kuehlturm (Zylinder mit Luefter)
	if (cat == "concrete" or cat == "glass" or cat == "stone") and rng.randf() < 0.35 and w > 8.0 and d > 8.0:
		var kx := rng.randf_range(x0 + 2.5, x1 - 2.5)
		var kz := rng.randf_range(z0 + 2.5, z1 - 2.5)
		var kr := rng.randf_range(1.4, 2.0)
		mbx.scyl(solid, Vector3(kx, y, kz), kr, kr, 2.6, Color(0.55, 0.58, 0.6), 14, 0.6, 0.5)
		for k in range(4):
			mbx.scyl(solid, Vector3(kx, y + 0.4 + k * 0.6, kz), kr * 1.02, kr * 1.02, 0.08, Color(0.35, 0.38, 0.4), 14, 0.6, 0.5, 0.0, false)
		mbx.scyl(solid, Vector3(kx, y + 2.6, kz), kr * 0.9, kr * 0.9, 0.3, Color(0.2, 0.22, 0.24), 14, 0.5, 0.5)
	# Schornsteine / Lueftungsrohre
	if rng.randf() < 0.5:
		for i in range(rng.randi_range(1, 3)):
			var px := rng.randf_range(x0 + 0.5, x1 - 0.5)
			var pz := rng.randf_range(z0 + 0.5, z1 - 0.5)
			var pr := rng.randf_range(0.2, 0.4)
			mbx.scyl(solid, Vector3(px, y, pz), pr, pr, rng.randf_range(1.2, 2.5), Color(0.55, 0.55, 0.57), 8, 0.5, 0.6)
	# Antenne / Funkmast auf hohen Haeusern
	if floors > 10 and rng.randf() < 0.7:
		var mx := rng.randf_range(x0 + 1.0, x1 - 1.0)
		var mz := rng.randf_range(z0 + 1.0, z1 - 1.0)
		var mh := rng.randf_range(6.0, 14.0)
		mbx.scyl(solid, Vector3(mx, y, mz), 0.12, 0.05, mh, Color(0.5, 0.5, 0.52), 6, 0.5, 0.7)
		mbx.scyl(solid, Vector3(mx, y + mh, mz), 0.1, 0.1, 0.2, Color(1.0, 0.1, 0.05), 6, 0.3, 0.0, 6.0)
	# Solarpaneele
	if cat in ["concrete", "glass", "garage"] and rng.randf() < 0.35 and w > 9.0:
		var sx := rng.randf_range(x0 + 1.0, x1 - 6.0)
		var sz := rng.randf_range(z0 + 1.0, z1 - 3.0)
		for k in range(3):
			var zz := sz + k * 1.6
			mbx.sq(solid, Vector3(sx, y + 0.3, zz + 1.2), Vector3(sx + 5.0, y + 0.3, zz + 1.2), Vector3(sx + 5.0, y + 1.0, zz), Vector3(sx, y + 1.0, zz), Color(0.08, 0.11, 0.2), 0.25, 0.5)
	# Dachluke
	if rng.randf() < 0.4:
		var lx := rng.randf_range(x0 + 1.0, x1 - 2.5)
		var lz := rng.randf_range(z0 + 1.0, z1 - 2.5)
		mbx.sbox(solid, lx, y, lz, lx + 1.6, y + 0.5, lz + 1.6, Color(0.5, 0.52, 0.55), 0.5, 0.4)
		mbx.sbox(solid, lx + 0.1, y + 0.5, lz + 0.1, lx + 1.5, y + 0.58, lz + 1.5, Color(0.2, 0.3, 0.38), 0.1, 0.1)


# ------------------------------------------------------------------------------------------------
# Strassen-Details an der Fassade
# ------------------------------------------------------------------------------------------------

# Markisen ueber Ladenfenstern (gestreift)
func shop_awnings(mbx, solid, base: Vector3, dir: Vector3, n: Vector3, w: float, y_shop: float) -> void:
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
			mbx.sq(solid, p0, p1, p2, p3, cc, 0.9)
			# Unterseite (dunkel), damit man von unten nicht hindurchsieht
			mbx.sq(solid, p1, p0, p3, p2, cc.darkened(0.45), 0.95)
			# Volant (senkrechter Streifen vorne)
			var v0 := Vector3(a.x, y_lo - 0.28, a.z) + n * proj
			var v1 := Vector3(b.x, y_lo - 0.28, b.z) + n * proj
			mbx.sq(solid, v0, v1, p1, p0, cc, 0.9)


# Ausleger- und Leuchtschilder an Laeden
func shop_signs(mbx, base: Vector3, dir: Vector3, n: Vector3, w: float, y_shop: float) -> void:
	if w < 8.0:
		return
	if rng.randf() < 0.55:
		var s := Signs.word(rng)
		var x := rng.randf_range(1.0, w - 1.0)
		var colr: Color = Signs.NEON[rng.randi() % Signs.NEON.size()]
		Signs.blade(mbx, base + dir * x + Vector3.UP * (y_shop - 1.35), dir, n, s, colr, 0.45)
	if rng.randf() < 0.45:
		var s2 := Signs.word(rng)
		var tw := 0.5 * 6.0 * s2.length() / 7.0
		if tw < w - 3.0:
			var x2 := rng.randf_range(1.0, w - tw - 1.0)
			Signs.neon_text(mbx, base + dir * x2 + Vector3.UP * (y_shop - 0.95), dir, n, s2, 0.5, Signs.NEON[rng.randi() % Signs.NEON.size()])


# Feuertreppe aus Eisengittern: Plattformen, Gelaender, Treppen
func fire_escape(mbx, base: Vector3, dir: Vector3, n: Vector3, w: float, y_start: float, y_end: float, fh: float, cw: float) -> void:
	var iron_g := M.iron(0)
	var iron_r := M.iron(1)
	var depth := 1.05
	var width := 2.1
	var ncol := maxf(1.0, roundf(w / cw))
	var col_idx := rng.randi_range(0, maxi(0, int(ncol) - 1))
	if ncol >= 3:
		col_idx = rng.randi_range(1, int(ncol) - 2)
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
		mbx.quad(iron_g, p0, p1, p2, p3, Vector3.UP, 0.0, width, 0.0, depth)
		# Gelaender vorne und seitlich
		var q0 := Vector3(a.x, yy, a.z) + n * depth
		var q1 := Vector3(b.x, yy, b.z) + n * depth
		mbx.quad(iron_r, q0, q1, q1 + Vector3.UP, q0 + Vector3.UP, n, 0.0, width, 0.0, 1.0)
		var sa := Vector3(a.x, yy, a.z)
		mbx.quad(iron_r, sa + n * 0.03, sa + n * depth, sa + n * depth + Vector3.UP, sa + n * 0.03 + Vector3.UP, -dir, 0.0, depth, 0.0, 1.0)
		var sb := Vector3(b.x, yy, b.z)
		mbx.quad(iron_r, sb + n * depth, sb + n * 0.03, sb + n * 0.03 + Vector3.UP, sb + n * depth + Vector3.UP, dir, 0.0, depth, 0.0, 1.0)
		# Treppe zum naechsten Geschoss (abwechselnd links/rechts)
		if f < nfloors:
			var side := 1.0 if f % 2 == 0 else -1.0
			var sx := cen + dir * (side * width * 0.25)
			var t0 := Vector3(sx.x, yy, sx.z) + n * 0.08
			var t1 := Vector3(sx.x, yy + fh, sx.z) + n * (depth - 0.02)
			var tw := dir * 0.45
			mbx.quad(iron_g, t0 - tw, t0 + tw, t1 + tw, t1 - tw, Vector3.UP, 0.0, 0.9, 0.0, (t1 - t0).length())


func entrance_canopy(mbx, solid, base: Vector3, dir: Vector3, n: Vector3, w: float) -> void:
	var c := base + dir * (w * 0.5)
	var half := minf(w * 0.5 - 1.0, 5.0)
	var p0 := Vector3(c.x - dir.x * half, 4.4, c.z - dir.z * half) + n * 3.5
	var p1 := Vector3(c.x + dir.x * half, 4.4, c.z + dir.z * half) + n * 3.5
	var p2 := Vector3(c.x + dir.x * half, 4.55, c.z + dir.z * half)
	var p3 := Vector3(c.x - dir.x * half, 4.55, c.z - dir.z * half)
	mbx.sq(solid, p0, p1, p2, p3, Color(0.2, 0.21, 0.23), 0.4, 0.6)
	mbx.sq(solid, p1, p0, p3, p2, Color(0.12, 0.12, 0.13), 0.5, 0.6)
	for k in [-1.0, 1.0]:
		var pc: Vector3 = c + dir * (k * (half - 0.2)) + n * 3.3
		mbx.scyl(solid, Vector3(pc.x, 0.0, pc.z), 0.1, 0.1, 4.45, Color(0.6, 0.62, 0.64), 8, 0.35, 0.8)


# ------------------------------------------------------------------------------------------------
# Times Square: Hochhaeuser rund um die Kreuzung, ueber und ueber mit LED-Flaechen und Neon
# ------------------------------------------------------------------------------------------------

func side_of(x0: float, z0: float, x1: float, z1: float, i: int) -> Array:
	var sides := [
		[Vector3(x0, 0, z1), Vector3.RIGHT, Vector3.BACK, x1 - x0],
		[Vector3(x1, 0, z0), Vector3.LEFT, Vector3.FORWARD, x1 - x0],
		[Vector3(x1, 0, z1), Vector3(0, 0, -1), Vector3.RIGHT, z1 - z0],
		[Vector3(x0, 0, z0), Vector3(0, 0, 1), Vector3.LEFT, z1 - z0],
	]
	return sides[i]


func build_times(zone: int) -> void:
	var sx := signf(Plan.TIMES_X - bcx)
	var sz := signf(Plan.TIMES_Z - bcz)
	var cwid := 34.0
	var cx0 := HALF - cwid if sx > 0 else -HALF
	var cx1 := HALF if sx > 0 else -HALF + cwid
	var cz0 := HALF - cwid if sz > 0 else -HALF
	var cz1 := HALF if sz > 0 else -HALF + cwid
	var lots := [
		{"x0": cx0, "z0": cz0, "x1": cx1, "z1": cz1, "corner": true},
		{"x0": (-HALF if sx > 0 else -HALF + cwid), "z0": -HALF, "x1": (HALF - cwid if sx > 0 else HALF), "z1": HALF, "corner": false},
		{"x0": cx0, "z0": (-HALF if sz > 0 else -HALF + cwid), "x1": cx1, "z1": (HALF - cwid if sz > 0 else HALF), "corner": false},
	]
	# Die beiden Strassenseiten, die zur Kreuzung zeigen: Seitenindex (+x = 2, -x = 3, +z = 0, -z = 1)
	var side_x := 2 if sx > 0 else 3
	var side_z := 0 if sz > 0 else 1
	var lot_i := 0
	for lot in lots:
		var x0: float = lot["x0"]
		var z0: float = lot["z0"]
		var x1: float = lot["x1"]
		var z1: float = lot["z1"]
		var open := [absf(z1 - HALF) < 0.01, absf(z0 + HALF) < 0.01, absf(x1 - HALF) < 0.01, absf(x0 + HALF) < 0.01]
		var corner: bool = lot["corner"]
		var floors := rng.randi_range(30, 40) if corner else rng.randi_range(12, 22)
		var sname: String = pick(["glass_dark", "concrete_b", "deco_grey"]) if corner else pick(["concrete_a", "stone_grey", "brick_dark", "deco_lime"])
		var st: Dictionary = STYLES[sname]
		var fh: float = st["fh"]
		var tint := Color(1, 1, 1)
		var bseed := rng.randf_range(0.1, 0.95)
		var total_h := 4.4 + floors * fh
		if corner:
			# zwei Stufen: Sockel voll, Turm leicht zurueckgesetzt
			var h1 := 4.4 + int(floors * 0.6) * fh
			build_tier(mb, st, sname, x0, z0, x1, z1, 0.0, h1, tint, bseed, open, true, false, floors)
			shapes.append([x0, 0.0, z0, x1, h1, z1])
			var ins := 3.0
			var n2 := [x0 + (0.0 if open[3] and sx < 0 else ins), z0 + (0.0 if open[1] and sz < 0 else ins), x1 - (0.0 if open[2] and sx > 0 else ins), z1 - (0.0 if open[0] and sz > 0 else ins)]
			build_tier(mb, st, sname, n2[0], n2[1], n2[2], n2[3], h1, total_h, tint, bseed, [true, true, true, true], false, true, floors)
			shapes.append([n2[0], h1, n2[1], n2[2], total_h, n2[3]])
			Signs.roof_board(ms, Vector3(n2[0] + 2.0, total_h + 0.5, (n2[3] - 0.5)), Vector3.RIGHT, Vector3.BACK, n2[2] - n2[0] - 4.0, 7.0, rng)
		else:
			build_tier(mb, st, sname, x0, z0, x1, z1, 0.0, total_h, tint, bseed, open, true, true, floors)
			shapes.append([x0, 0.0, z0, x1, total_h, z1])
			var rs := side_x if open[side_x] else side_z
			var sd: Array = side_of(x0, z0, x1, z1, rs)
			Signs.roof_board(ms, Vector3(sd[0].x, total_h + 0.5, sd[0].z) + (sd[2] as Vector3) * 0.5, sd[1], sd[2], sd[3] - 0.5, 6.0, rng)
		# LED-Flaechen auf den zur Kreuzung zeigenden Strassenseiten
		for si in [side_x, side_z]:
			if not open[si]:
				continue
			var sd2: Array = side_of(x0, z0, x1, z1, si)
			var top_y := minf(total_h * 0.75, 44.0) if corner else minf(total_h - 3.0, 22.0)
			Signs.facade_screens(ms, sd2[0], sd2[1], sd2[2], sd2[3], 5.6, top_y, rng, 0.85 if corner else 0.7)
		lot_i += 1


# ------------------------------------------------------------------------------------------------


# ------------------------------------------------------------------------------------------------
# Keilbau (Flatiron-Art): dreieckiger Turm auf der halben Blockflaeche, dahinter ein dreieckiger Platz
# ------------------------------------------------------------------------------------------------

func build_wedge() -> void:
	var sname := "stone_lime"
	var st: Dictionary = STYLES[sname]
	var fh: float = st["fh"]
	var cw: float = st["cw"]
	var floors := 22
	var gh := 4.4
	var top := gh + floors * fh
	var solid := M.solid()
	var mat_up := mat_of(sname)
	var mat_shop := mat_of(st["shop"])
	var a := 24.0
	var s2 := 0.70710678
	var tint := Color(1, 1, 1)
	var bseed := 0.55
	# Waende: [Basis, Richtung, Normale, Breite]
	var walls := [
		[Vector3(-a, 0, -a), Vector3(0, 0, 1), Vector3.LEFT, 2.0 * a],
		[Vector3(-a, 0, a), Vector3.RIGHT, Vector3.BACK, 2.0 * a],
		[Vector3(a, 0, a), Vector3(-s2, 0, -s2), Vector3(s2, 0, -s2), 2.0 * a * 1.41421356],
	]
	var nfl := float(floors)
	for wl in walls:
		var base: Vector3 = wl[0]
		var dir: Vector3 = wl[1]
		var n: Vector3 = wl[2]
		var w: float = wl[3]
		var ncs := maxf(1.0, roundf(w / 4.2))
		mb.wall(mat_shop, base, dir, w, 0.0, gh, n, 0.0, ncs, 0.0, 1.0, Vector2(w / ncs, gh), Color(tint.r, tint.g, tint.b, bseed))
		var ncol := maxf(1.0, roundf(w / cw))
		mb.wall(mat_up, base, dir, w, gh, top, n, 0.0, ncol, 0.0, nfl, Vector2(w / ncol, fh), Color(tint.r, tint.g, tint.b, bseed))
		# Kranzgesims, Bruestung, Gurtgesims ueber dem Laden
		Signs.obox(mb, solid, base + Vector3.UP * (top - 0.9) - n * 0.0, dir, n, w, 0.9, 0.5, (st["trim"] as Color).darkened(0.05), 0.85)
		Signs.obox(mb, solid, base + Vector3.UP * top - n * 0.25, dir, n, w, 0.9, 0.25, (st["trim"] as Color).darkened(0.12), 0.85)
		Signs.obox(mb, solid, base + Vector3.UP * (gh - 0.15), dir, n, w, 0.25, 0.14, (st["trim"] as Color).darkened(0.25), 0.8)
		if detail:
			shop_awnings(md, solid, base, dir, n, w, gh)
			shop_signs(md, base, dir, n, w, gh)
	# Dach
	var pa := Vector3(-a, top, a)
	var pb := Vector3(a, top, a)
	var pc := Vector3(-a, top, -a)
	mb.tri(M.roof(), pa, pb, pc, Vector3.UP, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ONE, roof_col())
	roof_props(md if detail else null, solid, -a + 2.0, 4.0, -4.0, a - 2.0, top, "stone", floors)
	# Sockel
	for wl in walls:
		Signs.obox(mb, solid, (wl[0] as Vector3), wl[1], wl[2], wl[3], 0.45, 0.06, Color(0.28, 0.27, 0.26), 0.85)
	# Kollision: dreieckiges Prisma
	var pts := PackedVector3Array()
	for p in [Vector3(-a, 0, a), Vector3(a, 0, a), Vector3(-a, 0, -a)]:
		pts.append(p)
		pts.append(p + Vector3(0, top, 0))
	hulls.append(pts)
	# Platz auf der anderen Haelfte: Baeume, Baenke, Poller
	if props != null:
		for p in [Vector2(14, -6), Vector2(6, -16), Vector2(18, 8), Vector2(-4, -14), Vector2(20, -14), Vector2(10, 2)]:
			props.trees.add("round" if rng.randf() < 0.7 else "oval", Vector3(bcx + p.x, 0.15, bcz + p.y), rng, rng.randf_range(0.9, 1.2))
	if detail:
		for k in range(10):
			var t := -22.0 + k * 4.4
			md.scyl(solid, Vector3(t + 1.8, 0.15, t - 1.8), 0.11, 0.11, 0.95, Color(0.12, 0.12, 0.13), 8, 0.4, 0.6)
