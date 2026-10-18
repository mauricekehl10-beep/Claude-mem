extends RefCounted
# Haar und Bart als einzelne Strähnen (schmale, gebogene Bänder): Sie wachsen von der Kopfhaut, liegen am Schädel an,
# fallen nach hinten und unten. Koordinaten: Ruhepose der Mixamo-Figur (Meter, +Z vorn, +X links), Mesh sitzt am Kopfknochen.

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


static func ribbon(am: Dictionary, pts: PackedVector3Array, w0: float, col: Color, out_c: Vector3) -> void:
	var v: PackedVector3Array = am["v"]
	var n: PackedVector3Array = am["n"]
	var c: PackedColorArray = am["c"]
	var uv: PackedVector2Array = am["uv"]
	var idx: PackedInt32Array = am["i"]
	var base := v.size()
	var cnt := pts.size()
	for i in range(cnt):
		var s := float(i) / float(cnt - 1)
		var d := (pts[mini(i + 1, cnt - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var out := (pts[i] - Vector3(0.0, clampf(pts[i].y, 1.52, 1.70), -0.015)).normalized()
		if out_c != Vector3.ZERO:
			out = out_c
		var side := d.cross(out).normalized()
		var wd := w0 * (1.0 - 0.78 * pow(s, 1.6)) * (0.55 + 0.45 * smoothstep(0.0, 0.12, s))
		for k in range(2):
			v.append(pts[i] + side * wd * (0.5 if k == 1 else -0.5))
			n.append((out + side * (0.35 if k == 1 else -0.35)).normalized())
			c.append(Color(col.r, col.g, col.b, s))
			uv.append(Vector2(float(k), s))
	for i in range(cnt - 1):
		var a := base + i * 2
		idx.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	am["v"] = v
	am["n"] = n
	am["c"] = c
	am["uv"] = uv
	am["i"] = idx


static func tint(base: Color, rng: RandomNumberGenerator, var_amt: float) -> Color:
	var k := 1.0 + rng.randf_range(-var_amt, var_amt)
	return Color(clampf(base.r * k, 0.0, 1.0), clampf(base.g * k * (1.0 + rng.randf_range(-0.03, 0.03)), 0.0, 1.0), clampf(base.b * k * (1.0 + rng.randf_range(-0.12, 0.08)), 0.0, 1.0))


# Kopfhaar (lang, nach hinten gekämmt, bis zu den Schultern)
static func hair(am: Dictionary, count: int, seed_v: int, base: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var made := 0
	var tries := 0
	while made < count and tries < count * 6:
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
		if rp.y < 1.595 or (rp.z > 0.03 and rp.y < 1.68 and absf(rp.x) > 0.06 and rng.randf() < 0.75):
			continue
		var layer := rng.randi() % 3
		var off := 0.0035 + layer * 0.0034 + rng.randf() * 0.0016
		var pos := push(rp, off)
		var nrm := ((pos - C) / (R * R)).normalized()
		var flow := Vector3(signf(rp.x) * 0.22 * absf(dir.x), -0.30, -1.0).normalized()
		var d := (flow - nrm * flow.dot(nrm)).normalized()
		var length := rng.randf_range(0.26, 0.40) if rp.y < 1.775 or absf(rp.x) > 0.04 else rng.randf_range(0.18, 0.30)
		var y_end := rng.randf_range(1.47, 1.55)
		var ph := rng.randf() * 6.28
		var pts := PackedVector3Array([pos])
		var step := 0.014
		var total := 0.0
		var steps := int(length / step)
		for k in range(steps):
			var wob := Vector3(cos(ph + k * 0.28), 0.0, sin(ph + k * 0.28)) * 0.03
			d = (d + Vector3(0, -1, 0) * 0.10 + wob).normalized()
			var flare := 0.007 * pow(float(k) / float(steps), 2.0) * (0.5 + 0.5 * float(layer))
			var np := push(pos + d * step, off + flare)
			d = (d * 0.4 + (np - pos).normalized() * 0.6).normalized()
			pos = np
			total += step
			pts.append(pos)
			if pos.y < y_end:
				break
		if pts.size() < 4:
			continue
		var col := tint(base, rng, 0.16)
		ribbon(am, pts, rng.randf_range(0.030, 0.050), col, Vector3.ZERO)
		made += 1


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
		ribbon(am, pts, rng.randf_range(0.007, 0.012), col, Vector3(side * clampf(ax * 5.0, 0.0, 0.9), 0.0, 1.0).normalized())
		made += 1


static func mesh(am: Dictionary) -> ArrayMesh:
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = am["v"]
	a[Mesh.ARRAY_NORMAL] = am["n"]
	a[Mesh.ARRAY_COLOR] = am["c"]
	a[Mesh.ARRAY_TEX_UV] = am["uv"]
	a[Mesh.ARRAY_INDEX] = am["i"]
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m


static func empty() -> Dictionary:
	return {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "uv": PackedVector2Array(), "i": PackedInt32Array()}
