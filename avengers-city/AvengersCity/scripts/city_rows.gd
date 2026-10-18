extends RefCounted
# Reihenhaus-Block (Brownstones): Ring aus schmalen Haeusern um einen Hof, mit Freitreppen, Eisengelaendern,
# Vorgartenzaeunen, Gesims und Dachaufbauten. Zeichnet in g.mb (Huelle) und g.md (Details).

const M = preload("res://scripts/city_mats.gd")
const Signs = preload("res://scripts/city_signs.gd")

const LINE := 23.0  # Baulinie (3 m hinter dem Gehweg)
const YARD := 8.0  # Innenkante des Hausrings
const BASE_H := 1.9  # Sockelgeschoss / Hochparterre-Schwelle
const FH := 3.5

const PALETTE := [
	{"wall": Color(0.40, 0.24, 0.18), "kind": 1, "trim": Color(0.60, 0.52, 0.44), "frame": Color(0.88, 0.88, 0.84)},
	{"wall": Color(0.47, 0.28, 0.20), "kind": 1, "trim": Color(0.62, 0.54, 0.46), "frame": Color(0.14, 0.15, 0.14)},
	{"wall": Color(0.55, 0.25, 0.19), "kind": 0, "trim": Color(0.74, 0.70, 0.64), "frame": Color(0.9, 0.9, 0.86)},
	{"wall": Color(0.66, 0.50, 0.36), "kind": 0, "trim": Color(0.80, 0.76, 0.68), "frame": Color(0.88, 0.88, 0.84)},
	{"wall": Color(0.64, 0.62, 0.57), "kind": 1, "trim": Color(0.76, 0.74, 0.70), "frame": Color(0.16, 0.16, 0.18)},
	{"wall": Color(0.36, 0.22, 0.17), "kind": 0, "trim": Color(0.58, 0.54, 0.48), "frame": Color(0.9, 0.9, 0.86)},
	{"wall": Color(0.60, 0.33, 0.22), "kind": 0, "trim": Color(0.76, 0.72, 0.64), "frame": Color(0.16, 0.18, 0.17)},
]
const DOORS := [Color(0.05, 0.05, 0.06), Color(0.05, 0.22, 0.12), Color(0.45, 0.06, 0.06), Color(0.06, 0.12, 0.30), Color(0.30, 0.18, 0.08)]


static func wall_mat(i: int) -> ShaderMaterial:
	var p: Dictionary = PALETTE[i]
	var d := {"kind": p["kind"], "wall": p["wall"], "trim": p["trim"], "frame": p["frame"], "glass": Color(0.07, 0.10, 0.15), "win": Vector2(1.05, 2.0), "sill": 0.7, "gm": 0.12, "grime": 0.7}
	return M.facade("row%d" % i, d)


static func base_mat(i: int) -> ShaderMaterial:
	var p: Dictionary = PALETTE[i]
	var d := {"kind": 10, "wall": (p["wall"] as Color).darkened(0.12), "trim": p["trim"], "frame": p["frame"], "glass": Color(0.07, 0.10, 0.15), "win": Vector2(0.8, 0.9), "sill": 0.5, "gm": 0.2, "grime": 0.9}
	return M.facade("row%db" % i, d)


# Reihen planen: Liste von Haeusern {x0,z0,x1,z1,front,floors,col}
static func plan(rng: RandomNumberGenerator, zone: int) -> Array:
	var houses := []
	var lo := -LINE
	var hi := LINE
	# Nord- und Suedreihe in voller Laenge, West- und Ostreihe dazwischen
	for side in range(4):
		var a: float
		var b: float
		if side < 2:
			a = lo
			b = hi
		else:
			a = -YARD
			b = YARD
		var n := int(round((b - a) / rng.randf_range(5.8, 7.2)))
		n = maxi(n, 2)
		var ws := []
		var tot := 0.0
		for k in range(n):
			var w := rng.randf_range(0.85, 1.2)
			ws.append(w)
			tot += w
		var pos := a
		var rcol := rng.randi() % PALETTE.size()
		for k in range(n):
			var w: float = ws[k] / tot * (b - a)
			var h := {"floors": 0, "col": rcol if rng.randf() < 0.55 else rng.randi() % PALETTE.size()}
			var fl := rng.randi_range(4, 5)
			if rng.randf() < 0.12:
				fl = 6
			h["floors"] = fl
			match side:
				0:  # Suedreihe (+z), Front zeigt +z
					h["x0"] = pos
					h["x1"] = pos + w
					h["z0"] = YARD
					h["z1"] = LINE
					h["front"] = 0
				1:  # Nordreihe, Front zeigt -z
					h["x0"] = pos
					h["x1"] = pos + w
					h["z0"] = -LINE
					h["z1"] = -YARD
					h["front"] = 1
				2:  # Ostreihe, Front zeigt +x
					h["z0"] = pos
					h["z1"] = pos + w
					h["x0"] = YARD
					h["x1"] = LINE
					h["front"] = 2
				_:  # Westreihe, Front zeigt -x
					h["z0"] = pos
					h["z1"] = pos + w
					h["x0"] = -LINE
					h["x1"] = -YARD
					h["front"] = 3
			houses.append(h)
			pos += w
	return houses


# Hoehe der Oberkante eines Hauses
static func top_of(h: Dictionary) -> float:
	return BASE_H + (int(h["floors"]) - 1) * FH + 0.0


# Nachbar-Oberkante an Seite s des Hauses h (-1 = kein Nachbar). s: 0 +z, 1 -z, 2 +x, 3 -x
static func neighbor_top(houses: Array, h: Dictionary, s: int) -> float:
	var best := -1.0
	for o in houses:
		if o == h:
			continue
		var touch := false
		if s == 0:
			touch = absf(h["z1"] - o["z0"]) < 0.02 and minf(h["x1"], o["x1"]) - maxf(h["x0"], o["x0"]) > 0.1
		elif s == 1:
			touch = absf(h["z0"] - o["z1"]) < 0.02 and minf(h["x1"], o["x1"]) - maxf(h["x0"], o["x0"]) > 0.1
		elif s == 2:
			touch = absf(h["x1"] - o["x0"]) < 0.02 and minf(h["z1"], o["z1"]) - maxf(h["z0"], o["z0"]) > 0.1
		else:
			touch = absf(h["x0"] - o["x1"]) < 0.02 and minf(h["z1"], o["z1"]) - maxf(h["z0"], o["z0"]) > 0.1
		if touch:
			best = maxf(best, top_of(o))
	return best


static func build(g, zone: int) -> void:
	var rng: RandomNumberGenerator = g.rng
	var houses := plan(rng, zone)
	var solid := M.solid()
	for h in houses:
		house(g, houses, h, zone)
	# Hof: Boden bleibt Gehwegplatte, ein paar Baeume und Huetten
	if g.props != null:
		for k in range(rng.randi_range(2, 4)):
			var p := Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(-6.0, 6.0))
			var kind := "round" if rng.randf() < 0.6 else "oval"
			g.props.trees.add(kind, Vector3(g.bcx + p.x, 0.15, g.bcz + p.y), rng, rng.randf_range(0.8, 1.2))
	if g.detail:
		for k in range(rng.randi_range(1, 3)):
			var sx := rng.randf_range(-6.0, 4.0)
			var sz := rng.randf_range(-6.0, 4.0)
			g.md.sbox(solid, sx, 0.15, sz, sx + 1.8, 2.3, sz + 1.6, Color(0.5, 0.52, 0.5).darkened(rng.randf_range(0.0, 0.4)), 0.8)


static func house(g, houses: Array, h: Dictionary, zone: int) -> void:
	var rng: RandomNumberGenerator = g.rng
	var mb = g.mb
	var md = g.md
	var solid := M.solid()
	var x0: float = h["x0"]
	var z0: float = h["z0"]
	var x1: float = h["x1"]
	var z1: float = h["z1"]
	var front: int = h["front"]
	var top := top_of(h)
	var ci: int = h["col"]
	var mw := wall_mat(ci)
	var mbase := base_mat(ci)
	var pal: Dictionary = PALETTE[ci]
	var trim: Color = pal["trim"]
	var bseed := rng.randf_range(0.08, 0.95)
	var tint := Color(1, 1, 1)
	var sides := [
		[Vector3(x0, 0, z1), Vector3.RIGHT, Vector3.BACK, x1 - x0],
		[Vector3(x1, 0, z0), Vector3.LEFT, Vector3.FORWARD, x1 - x0],
		[Vector3(x1, 0, z1), Vector3(0, 0, -1), Vector3.RIGHT, z1 - z0],
		[Vector3(x0, 0, z0), Vector3(0, 0, 1), Vector3.LEFT, z1 - z0],
	]
	var outer := [absf(z1 - LINE) < 0.02, absf(z0 + LINE) < 0.02, absf(x1 - LINE) < 0.02, absf(x0 + LINE) < 0.02]
	for i in range(4):
		var s: Array = sides[i]
		var base: Vector3 = s[0]
		var dir: Vector3 = s[1]
		var n: Vector3 = s[2]
		var w: float = s[3]
		var nb := neighbor_top(houses, h, i)
		if nb >= top - 0.01:
			continue
		var open := nb < 0.0
		var col := Color(tint.r, tint.g, tint.b, bseed if open else 0.0)
		var ncol := maxf(1.0, roundf(w / 3.0))
		var cwe := w / ncol
		var y_from := 0.0 if open else nb
		if open and outer[i]:
			# Sockelgeschoss (Souterrain)
			mb.wall(mbase, base, dir, w, 0.0, BASE_H, n, 0.0, ncol, 0.0, 1.0, Vector2(cwe, BASE_H), col)
			y_from = BASE_H
		var nfl := float(int(h["floors"]) - 1) if (open and outer[i]) else (top - y_from) / FH
		var v0 := 0.0
		if not (open and outer[i]):
			v0 = y_from / FH
			nfl = top / FH
		mb.wall(mw, base, dir, w, y_from, top, n, 0.0, ncol, v0, nfl, Vector2(cwe, FH), col)
	# Dach und Gesims
	mb.top(M.roof(), x0, z0, x1, z1, top, 1.0, Vector2.ONE, g.roof_col())
	var sd: Array = sides[front]
	var fb: Vector3 = sd[0]
	var fdir: Vector3 = sd[1]
	var fn: Vector3 = sd[2]
	var fw: float = sd[3]
	Signs.obox(mb, solid, fb + Vector3.UP * (top - 0.85) - fdir * 0.0, fdir, fn, fw, 0.85, 0.42, trim.darkened(0.05), 0.85)
	Signs.obox(mb, solid, fb + Vector3.UP * (top - 0.15) - fn * 0.0, fdir, fn, fw, 0.15, 0.55, trim.darkened(0.12), 0.85)
	g.parapet(mb, solid, x0, z0, x1, z1, top, 0.55, 0.18, trim.darkened(0.15))
	# Fenstergesims-Band ueber dem Sockel
	Signs.obox(mb, solid, fb + Vector3.UP * (BASE_H - 0.12), fdir, fn, fw, 0.16, 0.1, trim.darkened(0.08), 0.85)
	g.shapes.append([x0, 0.0, z0, x1, top, z1])
	# Dachaufbauten
	g.mini_roof(x0 + 0.4, z0 + 0.4, x1 - 0.4, z1 - 0.4, top)
	if not g.detail:
		return
	# Freitreppe mit Tuer, Gelaender, Zaun
	stoop(g, h, fb, fdir, fn, fw, trim, rng)
	if int(h["floors"]) >= 4 and pal["kind"] == 0 and rng.randf() < 0.3:
		g.fire_escape(md, fb, fdir, fn, fw, BASE_H + 0.5, top - 0.6, FH, 3.0)


static func stoop(g, h: Dictionary, base: Vector3, dir: Vector3, n: Vector3, w: float, trim: Color, rng: RandomNumberGenerator) -> void:
	var md = g.md
	var solid := M.solid()
	var iron_r := M.iron(1)
	var iron_f := M.iron(2)
	var ncol := maxf(1.0, roundf(w / 3.0))
	var cwe := w / ncol
	var col_i := 0 if rng.randf() < 0.5 else int(ncol) - 1
	var dx := cwe * (col_i + 0.5)
	var ws := 2.0
	var xl := dx - ws * 0.5
	var stone := trim.darkened(0.12)
	var ld := 0.85
	var run := 0.265
	var nsteps := 8
	var rise := (BASE_H - 0.15) / (nsteps + 1)
	# Tuer: Rahmen, Blatt, Oberlicht
	var door_col: Color = DOORS[rng.randi() % DOORS.size()]
	Signs.obox(md, solid, base + dir * (dx - 0.8) + Vector3.UP * BASE_H, dir, n, 1.6, 2.75, 0.14, trim.lightened(0.05), 0.8)
	Signs.obox(md, solid, base + dir * (dx - 0.58) + Vector3.UP * (BASE_H + 0.04) + n * 0.14, dir, n, 1.16, 2.2, 0.06, door_col, 0.45)
	Signs.obox(md, solid, base + dir * (dx - 0.5) + Vector3.UP * (BASE_H + 2.3) + n * 0.14, dir, n, 1.0, 0.36, 0.05, Color(1.0, 0.85, 0.5), 0.3, 0.0, 1.2)
	# Podest und Stufen
	Signs.obox(md, solid, base + dir * xl + Vector3.UP * 0.15, dir, n, ws, BASE_H - 0.15, ld, stone, 0.85)
	for j in range(nsteps):
		var yt := BASE_H - (j + 1) * rise
		Signs.obox(md, solid, base + dir * xl + Vector3.UP * 0.15 + n * (ld + j * run), dir, n, ws, yt - 0.15, run, stone, 0.85)
	var out_end := ld + nsteps * run
	# Gelaender beidseitig (schraeg) und Pfosten
	for sx in [xl, xl + ws]:
		var bs: Vector3 = base + dir * sx
		var pa := bs + n * ld + Vector3.UP * BASE_H
		var pb := bs + n * out_end + Vector3.UP * (BASE_H - (nsteps) * rise)
		var pc := bs + Vector3.UP * BASE_H
		var side_n: Vector3 = dir if sx > xl else -dir
		var len1 := (pb - pa).length()
		md.quad(iron_r, pa, pb, pb + Vector3.UP * 0.95, pa + Vector3.UP * 0.95, side_n, 0.0, len1, 0.0, 0.95)
		md.quad(iron_r, pc, pa, pa + Vector3.UP * 0.95, pc + Vector3.UP * 0.95, side_n, 0.0, ld, 0.0, 0.95)
		Signs.obox(md, solid, pb - dir * 0.05 - n * 0.05, dir, n, 0.12, 1.1, 0.12, Color(0.04, 0.04, 0.05), 0.5, 0.5)
	# Vorgartenzaun an der Grundstuecksgrenze mit Lucke fuer die Treppe
	var fo := 3.02
	var f0 := base + n * fo
	var gap0 := maxf(0.0, xl - 0.1)
	var gap1 := minf(w, xl + ws + 0.1)
	if gap0 > 0.3:
		md.quad(iron_f, f0, f0 + dir * gap0, f0 + dir * gap0 + Vector3.UP * 1.0, f0 + Vector3.UP * 1.0, n, 0.0, gap0, 0.0, 1.0)
	if w - gap1 > 0.3:
		var q := f0 + dir * gap1
		md.quad(iron_f, q, q + dir * (w - gap1), q + dir * (w - gap1) + Vector3.UP * 1.0, q + Vector3.UP * 1.0, n, 0.0, w - gap1, 0.0, 1.0)
	# Kollision der Treppe: Rampe (begehbar)
	var pts := PackedVector3Array()
	var half := ws * 0.5
	for sgn in [-1.0, 1.0]:
		var o: Vector3 = base + dir * dx + dir * (sgn * half)
		pts.append(o + Vector3.UP * 0.1)
		pts.append(o + Vector3.UP * BASE_H)
		pts.append(o + n * ld + Vector3.UP * BASE_H)
		pts.append(o + n * (out_end + 0.1) + Vector3.UP * 0.1)
		pts.append(o + n * (out_end + 0.1) + Vector3.UP * 0.25)
	g.hulls.append(pts)
