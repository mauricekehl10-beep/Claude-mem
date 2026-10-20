extends RefCounted
# Haar und Bart als einzelne Strähnen (schmale, gebogene Bänder). Das Kopfhaar besteht aus Locken: mehrere Strähnen folgen
# demselben welligen Weg, spreizen sich zu den Spitzen und trennen sich dort. Dazu Flechtzöpfe an den Schläfen und feine Härchen.
# Sie wachsen von der Kopfhaut, liegen am Schädel an, fallen nach hinten und unten.
# Koordinaten: Ruhepose der Mixamo-Figur (Meter, +Z vorn, +X links), Mesh sitzt am Kopfknochen.

const C := Vector3(0.0, 1.69, 0.0)   # Schädelmitte
const R := Vector3(0.083, 0.116, 0.123)


# Schiebt einen Punkt aus Schädel und Nacken heraus (off = Abstand zur Haut)
static func push(pos: Vector3, off: float) -> Vector3:
	var rr := R + Vector3.ONE * off
	var q := (pos - C) / rr
	var l := q.length()
	if l < 1.0 and pos.y > C.y - 0.04:
		pos = C + q / maxf(l, 0.0001) * rr
	if pos.y < C.y:
		var rx := 0.079 + off
		var rz := 0.100 + off
		var cx := pos.x / rx
		var cz := (pos.z + 0.024) / rz
		var lc := sqrt(cx * cx + cz * cz)
		if lc < 1.0:
			if lc < 0.001:
				cx = 1.0
				lc = 1.0
			pos.x = cx / lc * rx
			pos.z = cz / lc * rz - 0.024
	return pos


# Fläche des Gesichts vorn (grob): z an (|x|, y)
static func face_z(ax: float, y: float) -> float:
	var zc := 0.110 + clampf((y - 1.56) * 0.9, 0.0, 0.02)
	return zc - maxf(ax - 0.02, 0.0) * 1.5


# Eine Strähne als Band entlang pts (Wurzel .. Spitze). w0 = Breite, col = Farbe, out_c = feste Aussenrichtung (oder 0)
static func ribbon(am: Dictionary, pts: PackedVector3Array, w0: float, col: Color, out_c: Vector3, taper: float = 0.78) -> void:
	var v: PackedVector3Array = am["v"]
	var n: PackedVector3Array = am["n"]
	var c: PackedColorArray = am["c"]
	var uv: PackedVector2Array = am["uv"]
	var idx: PackedInt32Array = am["i"]
	var tg: PackedFloat32Array = am["t"]
	var base := v.size()
	var cnt := pts.size()
	for i in range(cnt):
		var s := float(i) / float(cnt - 1)
		var d := (pts[mini(i + 1, cnt - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var out := (pts[i] - Vector3(0.0, clampf(pts[i].y, 1.52, 1.70), -0.015)).normalized()
		if out_c != Vector3.ZERO:
			out = out_c
		var side := d.cross(out).normalized()
		var wd := w0 * (1.0 - taper * pow(s, 1.6)) * (0.55 + 0.45 * smoothstep(0.0, 0.12, s))
		for k in range(2):
			v.append(pts[i] + side * wd * (0.5 if k == 1 else -0.5))
			n.append((out + side * (0.35 if k == 1 else -0.35)).normalized())
			c.append(Color(col.r, col.g, col.b, s))
			uv.append(Vector2(float(k), s))
			tg.append_array(PackedFloat32Array([d.x, d.y, d.z, 1.0]))
	for i in range(cnt - 1):
		var a := base + i * 2
		idx.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	am["v"] = v
	am["n"] = n
	am["c"] = c
	am["uv"] = uv
	am["i"] = idx
	am["t"] = tg


static func tint(base: Color, rng: RandomNumberGenerator, var_amt: float) -> Color:
	var k := 1.0 + rng.randf_range(-var_amt, var_amt)
	return Color(clampf(base.r * k, 0.0, 1.0), clampf(base.g * k * (1.0 + rng.randf_range(-0.03, 0.03)), 0.0, 1.0), clampf(base.b * k * (1.0 + rng.randf_range(-0.12, 0.08)), 0.0, 1.0))


# Kopfhaar: Locken (count = ungefähre Zahl der Strähnen insgesamt). Lang, nach hinten gekämmt, wellig, bis zu den Schultern.
static func hair(am: Dictionary, count: int, seed_v: int, base: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var nl := maxi(count / 3, 12)
	var made := 0
	var tries := 0
	while made < nl and tries < nl * 12:
		tries += 1
		# Wurzel auf der Schädeldecke: Winkel von vorn (az) und von oben (po)
		var az := rng.randf_range(-PI, PI)
		var po := rng.randf_range(0.05, 1.95)
		var dir := Vector3(sin(po) * sin(az), cos(po), sin(po) * cos(az))
		var rp := C + dir * R
		# Gesichtszone frei lassen: Stirn (Haaransatz) und Schläfen
		var hairline := 1.722 + 0.010 * smoothstep(0.02, 0.055, absf(rp.x))
		if rp.z > 0.01 and (rp.y < hairline or absf(rp.x) < 0.062 and rp.y < 1.745):
			continue
		if rp.y < 1.595 or (rp.z > 0.03 and rp.y < 1.68 and absf(rp.x) > 0.06 and rng.randf() < 0.8):
			continue
		_lock(am, rng, rp, dir, base, Vector3.ZERO)
		made += 1
	# Haaransatz: Locken von der Stirn und den Schläfen nach hinten (sonst bleibt der Schädel vorn sichtbar)
	for i in range(46):
		var f := float(i) / 45.0 * 2.0 - 1.0
		var x := f * 0.074
		var y := 1.7225 + 0.0105 * smoothstep(0.02, 0.055, absf(x)) + rng.randf_range(0.0, 0.01) + 0.012 * pow(absf(f), 3.0)
		var qy := (y - C.y) / R.y
		var qx := x / R.x
		var z := R.z * sqrt(maxf(0.0, 1.0 - qx * qx - qy * qy))
		var rp3 := Vector3(x, y, z)
		var fl := Vector3(f * 0.9, -0.12 - 0.5 * absf(f), -1.0).normalized()
		_lock(am, rng, rp3, (rp3 - C).normalized(), base, fl)
	# feine abstehende Härchen (Haarkranz am Rand, einzelne Flusen)
	for i in range(22):
		var az2 := rng.randf_range(-PI, PI)
		var po2 := rng.randf_range(0.9, 1.9)
		var dir2 := Vector3(sin(po2) * sin(az2), cos(po2), sin(po2) * cos(az2))
		var rp2 := C + dir2 * R
		if rp2.z > 0.0 and rp2.y < 1.74:
			continue
		var p2 := push(rp2, 0.012)
		var d2 := Vector3(rng.randf_range(-0.2, 0.2), -0.7, -0.7).normalized() + dir2 * 0.15
		d2 = d2.normalized()
		var pts := PackedVector3Array([p2])
		for k in range(14):
			d2 = (d2 + Vector3(rng.randf_range(-0.12, 0.12), -0.11, rng.randf_range(-0.08, 0.08))).normalized()
			p2 = push(p2 + d2 * 0.014, 0.014 + 0.0009 * k)
			pts.append(p2)
		ribbon(am, pts, rng.randf_range(0.006, 0.010), tint(base, rng, 0.14), Vector3.ZERO, 0.9)


# Eine Locke: ein welliger Mittelweg, darum mehrere Strähnen, die sich zur Spitze hin auffächern.
# rp = Wurzel auf dem Schädel, dir = Richtung vom Schädelmittelpunkt, flow_o = feste Strömung (oder ZERO)
static func _lock(am: Dictionary, rng: RandomNumberGenerator, rp: Vector3, dir: Vector3, base: Color, flow_o: Vector3) -> void:
	var layer := rng.randi() % 3
	var off := 0.0035 + layer * 0.0048 + rng.randf() * 0.0016
	var pos := push(rp, off)
	var nrm := ((pos - C) / (R * R)).normalized()
	# Strömung: von der Stirn nach hinten, seitlich leicht nach unten; Schläfen- und Seitenlocken fallen hinter dem Ohr
	var flow := Vector3(signf(rp.x) * 0.25 * absf(dir.x), -0.32, -1.0).normalized()
	if flow_o != Vector3.ZERO:
		flow = flow_o
	var d := (flow - nrm * flow.dot(nrm)).normalized()
	var length := rng.randf_range(0.32, 0.47) if rp.y < 1.775 or absf(rp.x) > 0.04 else rng.randf_range(0.20, 0.33)
	var y_end := rng.randf_range(1.45, 1.53)
	var ph := rng.randf() * 6.28
	var wamp := rng.randf_range(0.035, 0.06)
	var wfreq := rng.randf_range(0.22, 0.34)
	var path := PackedVector3Array([pos])
	var step := 0.014
	var steps := int(length / step) + 20  # der Weg über den Schädel zählt zusätzlich zur freien Länge
	for k in range(steps):
		var wob := Vector3(cos(ph + k * wfreq), 0.0, sin(ph + k * wfreq)) * wamp
		d = (d + Vector3(0, -1, 0) * 0.10 + wob).normalized()
		var flare := 0.013 * pow(float(k) / float(steps), 1.6) * (0.4 + 0.6 * float(layer))
		var np := push(pos + d * step, off + flare)
		# am Schädel anliegen: Haar liegt über dem Kopf auf der Kopfhaut, erst darunter fällt es frei
		var rr := R + Vector3.ONE * (off + flare)
		var qn := (np - C) / rr
		var ql := qn.length()
		if np.y > 1.60 and ql > 1.0 and ql < 1.4:
			np = C + qn / ql * rr
		d = (d * 0.4 + (np - pos).normalized() * 0.6).normalized()
		pos = np
		path.append(pos)
		if pos.y < y_end:
			break
	if path.size() < 5:
		return
	var lock_col := tint(base, rng, 0.14)
	if rng.randf() < 0.22:
		lock_col = lock_col.lerp(Color(0.95, 0.80, 0.50), 0.35)  # helle, von der Sonne gebleichte Strähnen
	var spread := rng.randf_range(0.014, 0.026)
	var ns := rng.randi_range(4, 7)
	for q in range(ns):
		var lat := rng.randf_range(-1.0, 1.0)
		var cnt := maxi(int(path.size() * rng.randf_range(0.80, 1.0)), 5)
		var sp := PackedVector3Array()
		for k in range(cnt):
			var tt := float(k) / float(path.size() - 1)
			var tgv := (path[mini(k + 1, path.size() - 1)] - path[maxi(k - 1, 0)]).normalized()
			var nout := ((path[k] - C) / (R * R)).normalized()
			var side := tgv.cross(nout).normalized()
			var pk := path[k] + side * lat * spread * (0.7 + 0.8 * tt) + nout * lat * lat * 0.0016
			sp.append(push(pk, off + 0.002))
		ribbon(am, sp, rng.randf_range(0.020, 0.034), tint(lock_col, rng, 0.07), Vector3.ZERO, 0.8)


# Geflochtener Zopf: Seil aus drei gedrehten Strängen entlang pts, Radius r0 .. r1, Farbe col. Am Ende ein Lederband.
static func braid(am: Dictionary, pts: PackedVector3Array, r0: float, r1: float, col: Color, tie: Color) -> void:
	# Mittellinie gleichmässig unterteilen (alle 2,5 mm)
	var line := PackedVector3Array()
	var tot := 0.0
	for i in range(pts.size() - 1):
		tot += pts[i].distance_to(pts[i + 1])
	var nv := maxi(int(tot / 0.0025), 4)
	var acc := 0.0
	var seg := 0
	for k in range(nv + 1):
		var f := float(k) / float(nv) * tot
		while seg < pts.size() - 2 and f > acc + pts[seg].distance_to(pts[seg + 1]):
			acc += pts[seg].distance_to(pts[seg + 1])
			seg += 1
		var sl := maxf(pts[seg].distance_to(pts[seg + 1]), 1e-6)
		line.append(pts[seg].lerp(pts[seg + 1], clampf((f - acc) / sl, 0.0, 1.0)))
	var rows := line.size()
	var ring := 12
	var P := PackedVector3Array()
	var Nn := PackedVector3Array()
	var Cc := PackedColorArray()
	var Uu := PackedVector2Array()
	var Tt := PackedFloat32Array()
	for i in range(rows):
		var s := float(i) / float(rows - 1)
		var tgv := (line[mini(i + 1, rows - 1)] - line[maxi(i - 1, 0)]).normalized()
		var ref := (line[i] - Vector3(0.0, line[i].y, 0.0)).normalized()
		if ref.length() < 0.1:
			ref = Vector3(1, 0, 0)
		var ex := tgv.cross(ref).normalized()
		var ey := ex.cross(tgv).normalized()
		var r := lerpf(r0, r1, pow(s, 1.2))
		var arc := float(i) * 0.0025
		for j in range(ring):
			var a := TAU * float(j) / float(ring)
			var lobe := 1.0 + 0.30 * cos(3.0 * a - arc * 330.0)
			var dirv := ex * cos(a) + ey * sin(a)
			P.append(line[i] + dirv * r * lobe)
			Nn.append(dirv)
			var shade := 0.82 + 0.28 * (0.5 + 0.5 * cos(3.0 * a - arc * 330.0))
			Cc.append(Color(col.r * shade, col.g * shade, col.b * shade, 0.3))
			Uu.append(Vector2(0.5, 0.3))
			Tt.append_array(PackedFloat32Array([tgv.x, tgv.y, tgv.z, 1.0]))
	var base := (am["v"] as PackedVector3Array).size()
	var v: PackedVector3Array = am["v"]
	var n: PackedVector3Array = am["n"]
	var c: PackedColorArray = am["c"]
	var uv: PackedVector2Array = am["uv"]
	var idx: PackedInt32Array = am["i"]
	var tg: PackedFloat32Array = am["t"]
	for i in range(rows):
		for j in range(ring):
			var ia := i * ring + j
			var du := P[i * ring + (j + 1) % ring] - P[i * ring + (j + ring - 1) % ring]
			var dv := P[mini(i + 1, rows - 1) * ring + j] - P[maxi(i - 1, 0) * ring + j]
			var nn := du.cross(dv).normalized()
			if nn.dot(Nn[ia]) < 0.0:
				nn = -nn
			v.append(P[ia])
			n.append(nn)
			c.append(Cc[ia])
			uv.append(Uu[ia])
	tg.append_array(Tt)
	for i in range(rows - 1):
		for j in range(ring):
			var j2 := (j + 1) % ring
			var a0 := base + i * ring + j
			var a1 := base + i * ring + j2
			var b0 := base + (i + 1) * ring + j
			var b1 := base + (i + 1) * ring + j2
			idx.append_array(PackedInt32Array([a0, b0, a1, a1, b0, b1]))
	am["v"] = v
	am["n"] = n
	am["c"] = c
	am["uv"] = uv
	am["i"] = idx
	am["t"] = tg
	# Lederband am Ende und kleine Haarquaste darunter
	var e := line[rows - 1]
	var eb := line[maxi(rows - 5, 0)]
	var et := (e - eb).normalized()
	var tie_pts := PackedVector3Array([eb + et * 0.002, e + et * 0.004])
	braid_tie(am, tie_pts, r1 * 1.55, tie)


# Lederband (kurzes dickeres Rohr)
static func braid_tie(am: Dictionary, pts: PackedVector3Array, r: float, col: Color) -> void:
	var v: PackedVector3Array = am["v"]
	var n: PackedVector3Array = am["n"]
	var c: PackedColorArray = am["c"]
	var uv: PackedVector2Array = am["uv"]
	var idx: PackedInt32Array = am["i"]
	var tg: PackedFloat32Array = am["t"]
	var a := pts[0]
	var b := pts[1]
	var ax := (b - a).normalized()
	var ref := Vector3(1, 0, 0) if absf(ax.x) < 0.9 else Vector3(0, 0, 1)
	var ex := ax.cross(ref).normalized()
	var ey := ex.cross(ax).normalized()
	var base := v.size()
	var ring := 10
	for k in range(2):
		for j in range(ring):
			var ang := TAU * float(j) / float(ring)
			var dirv := ex * cos(ang) + ey * sin(ang)
			v.append((a if k == 0 else b) + dirv * r)
			n.append(dirv)
			c.append(Color(col.r, col.g, col.b, 0.3))
			uv.append(Vector2(0.5, 0.3))
			tg.append_array(PackedFloat32Array([ax.x, ax.y, ax.z, 1.0]))
	for j in range(ring):
		var j2 := (j + 1) % ring
		idx.append_array(PackedInt32Array([base + j, base + ring + j, base + j2, base + j2, base + ring + j, base + ring + j2]))
	am["v"] = v
	am["n"] = n
	am["c"] = c
	am["uv"] = uv
	am["i"] = idx
	am["t"] = tg


# Zöpfchen an den Schläfen (wie im Film): vom Haaransatz über dem Ohr nach hinten, am Hinterkopf mit Lederband, Ende hängt herab
static func braids(am: Dictionary, seed_v: int, base: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for s in [-1.0, 1.0]:
		var ctrl := [
			Vector3(s * 0.070, 1.700, 0.048), Vector3(s * 0.082, 1.694, 0.016), Vector3(s * 0.083, 1.682, -0.020),
			Vector3(s * 0.074, 1.668, -0.062), Vector3(s * 0.058, 1.650, -0.100), Vector3(s * 0.046, 1.620, -0.122),
			Vector3(s * 0.040, 1.580, -0.130), Vector3(s * 0.036, 1.545, -0.128),
		]
		var pts := PackedVector3Array()
		# Catmull-Rom durch die Stützpunkte
		for i in range(ctrl.size() - 1):
			var p0: Vector3 = ctrl[maxi(i - 1, 0)]
			var p1: Vector3 = ctrl[i]
			var p2: Vector3 = ctrl[i + 1]
			var p3: Vector3 = ctrl[mini(i + 2, ctrl.size() - 1)]
			for k in range(8):
				var t := float(k) / 8.0
				var t2 := t * t
				var t3 := t2 * t
				var pp := 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
				pts.append(push(pp, 0.0085))
		braid(am, pts, 0.0058, 0.0042, tint(base, rng, 0.05), Color(0.10, 0.06, 0.04))


# Vollbart: Strähnen von Wangen, Kinn und Oberlippe nach unten und vorn
static func beard(am: Dictionary, count: int, seed_v: int, base: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var made := 0
	var tries := 0
	while made < count and tries < count * 8:
		tries += 1
		var ax := rng.randf_range(0.0, 0.060)
		var y := rng.randf_range(1.545, 1.640)
		var jt := 1.606 + 0.034 * smoothstep(0.030, 0.060, ax)
		if y > jt:
			continue
		var in_lips := ax < 0.026 and y > 1.5835 and y < 1.607
		if in_lips:
			continue
		var must := ax < 0.026 and y > 1.6075 and y < 1.62
		if y > 1.607 and not must and ax < 0.03:
			continue
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var z := face_z(ax, y) - 0.002
		var rp := Vector3(side * ax, y, z)
		var out := Vector3(side * clampf(ax * 6.0, 0.0, 1.0) * 0.8, -0.1, 1.0).normalized()
		var goatee := ax < 0.03 and y < 1.58
		var length := rng.randf_range(0.016, 0.034) if goatee else (rng.randf_range(0.008, 0.017) if not must else rng.randf_range(0.008, 0.014))
		var d: Vector3 = (out * 0.55 + Vector3(side * 0.12 * (1.0 if must else 0.0), -1.0, 0.0) * (0.55 if not must else 0.2)).normalized()
		if must:
			d = Vector3(side * 0.5, -0.45, 0.55).normalized()
		var pts := PackedVector3Array([rp])
		var pos := rp
		var step := 0.006
		var steps := maxi(int(length / step), 3)
		for k in range(steps):
			d = (d + Vector3(0, -1, 0) * (0.10 if not must else 0.05) + Vector3(rng.randf_range(-0.05, 0.05), 0, rng.randf_range(-0.03, 0.03))).normalized()
			pos += d * step
			# nicht in den Kopf zurück
			pos.z = maxf(pos.z, face_z(absf(pos.x), pos.y) + 0.001 * k)
			pts.append(pos)
		var col := tint(base, rng, 0.2)
		ribbon(am, pts, rng.randf_range(0.006, 0.010), col, Vector3(side * clampf(ax * 5.0, 0.0, 0.9), 0.0, 1.0).normalized())
		made += 1


static func mesh(am: Dictionary) -> ArrayMesh:
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = am["v"]
	a[Mesh.ARRAY_NORMAL] = am["n"]
	a[Mesh.ARRAY_COLOR] = am["c"]
	a[Mesh.ARRAY_TEX_UV] = am["uv"]
	a[Mesh.ARRAY_INDEX] = am["i"]
	if (am["t"] as PackedFloat32Array).size() == (am["v"] as PackedVector3Array).size() * 4:
		a[Mesh.ARRAY_TANGENT] = am["t"]
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m


static func empty() -> Dictionary:
	return {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "uv": PackedVector2Array(), "i": PackedInt32Array(), "t": PackedFloat32Array()}
