extends RefCounted
# Mesh-Sammler: viele Flaechen (Quads, Boxen, Zylinder) pro Material sammeln und zu EINEM Mesh zusammenfassen.
# Wenig Draw-Calls, volle Kontrolle ueber UVs und Farben.

class Surf:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()

var surfs := {}
var order := []


func surf(mat: Material) -> Surf:
	var s = surfs.get(mat)
	if s == null:
		s = Surf.new()
		surfs[mat] = s
		order.append(mat)
	return s


# Rechteck. p0 unten links, p1 unten rechts, p2 oben rechts, p3 oben links, gesehen von aussen (gegen den Uhrzeigersinn).
func quad(mat: Material, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: Vector3, u0: float, u1: float, v0: float, v1: float, uv2: Vector2 = Vector2.ONE, col: Color = Color.WHITE) -> void:
	var s := surf(mat)
	var b := s.v.size()
	s.v.append(p0)
	s.v.append(p1)
	s.v.append(p2)
	s.v.append(p3)
	s.n.append(n)
	s.n.append(n)
	s.n.append(n)
	s.n.append(n)
	s.uv.append(Vector2(u0, v0))
	s.uv.append(Vector2(u1, v0))
	s.uv.append(Vector2(u1, v1))
	s.uv.append(Vector2(u0, v1))
	s.uv2.append(uv2)
	s.uv2.append(uv2)
	s.uv2.append(uv2)
	s.uv2.append(uv2)
	s.c.append(col)
	s.c.append(col)
	s.c.append(col)
	s.c.append(col)
	s.idx.append(b)
	s.idx.append(b + 2)
	s.idx.append(b + 1)
	s.idx.append(b)
	s.idx.append(b + 3)
	s.idx.append(b + 2)


# Senkrechte Wand: base = linke untere Ecke (von aussen gesehen), dir = Einheitsvektor nach rechts (horizontal),
# n = Aussennormale. Breite w, von y0 bis y1.
func wall(mat: Material, base: Vector3, dir: Vector3, w: float, y0: float, y1: float, n: Vector3, u0: float, u1: float, v0: float, v1: float, uv2: Vector2 = Vector2.ONE, col: Color = Color.WHITE) -> void:
	var a := Vector3(base.x, y0, base.z)
	var b := a + dir * w
	quad(mat, a, b, Vector3(b.x, y1, b.z), Vector3(a.x, y1, a.z), n, u0, u1, v0, v1, uv2, col)


# Waagerechte Flaeche nach oben (y = h), von (x0,z0) bis (x1,z1). UV in Metern.
func top(mat: Material, x0: float, z0: float, x1: float, z1: float, h: float, uv_scale: float = 1.0, uv2: Vector2 = Vector2.ONE, col: Color = Color.WHITE) -> void:
	# Blick von oben (+Y): gegen den Uhrzeigersinn = (x0,z1) -> (x1,z1) -> (x1,z0) -> (x0,z0)
	quad(mat, Vector3(x0, h, z1), Vector3(x1, h, z1), Vector3(x1, h, z0), Vector3(x0, h, z0), Vector3.UP, x0 * uv_scale, x1 * uv_scale, z1 * uv_scale, z0 * uv_scale, uv2, col)


# Waagerechte Flaeche nach unten (Unterseite von Vordaechern usw.)
func bottom(mat: Material, x0: float, z0: float, x1: float, z1: float, h: float, uv_scale: float = 1.0, uv2: Vector2 = Vector2.ONE, col: Color = Color.WHITE) -> void:
	quad(mat, Vector3(x0, h, z0), Vector3(x1, h, z0), Vector3(x1, h, z1), Vector3(x0, h, z1), Vector3.DOWN, x0 * uv_scale, x1 * uv_scale, z0 * uv_scale, z1 * uv_scale, uv2, col)


# Achsenparallele Box (alle 6 Seiten). Seiten mit mat_side, oben mat_top. Seiten-UV in Metern / (cw, fh) Zellen.
func box(mat_side: Material, mat_top: Material, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, cw: float = 3.0, fh: float = 3.4, col: Color = Color.WHITE, bottom_face: bool = false) -> void:
	var u2 := Vector2(cw, fh)
	var wx := x1 - x0
	var wz := z1 - z0
	var nx := maxf(1.0, roundf(wx / cw))
	var nz := maxf(1.0, roundf(wz / cw))
	var nf := maxf(1.0, (y1 - y0) / fh)
	var cx := wx / nx
	var cz := wz / nz
	var u2x := Vector2(cx, fh)
	var u2z := Vector2(cz, fh)
	# +Z (Sueden): von x0 nach x1
	wall(mat_side, Vector3(x0, 0, z1), Vector3.RIGHT, wx, y0, y1, Vector3.BACK, 0.0, nx, 0.0, nf, u2x, col)
	# -Z (Norden): von x1 nach x0
	wall(mat_side, Vector3(x1, 0, z0), Vector3.LEFT, wx, y0, y1, Vector3.FORWARD, 0.0, nx, 0.0, nf, u2x, col)
	# +X (Osten): von z1 nach z0? Von aussen (bei +x) nach rechts = -z? up x n = (0,1,0)x(1,0,0) = (0,0,-1)
	wall(mat_side, Vector3(x1, 0, z1), Vector3(0, 0, -1), wz, y0, y1, Vector3.RIGHT, 0.0, nz, 0.0, nf, u2z, col)
	# -X (Westen): rechts = up x n = (0,1,0)x(-1,0,0) = (0,0,1)
	wall(mat_side, Vector3(x0, 0, z0), Vector3(0, 0, 1), wz, y0, y1, Vector3.LEFT, 0.0, nz, 0.0, nf, u2z, col)
	if mat_top != null:
		top(mat_top, x0, z0, x1, z1, y1, 1.0, Vector2.ONE, col)
	if bottom_face:
		bottom(mat_side, x0, z0, x1, z1, y0, 1.0, Vector2.ONE, col)


# Beliebiger Zylinder/Kegel (senkrecht), seg Segmente, Mantel glatt schattiert. uv: u = Winkel*r, v = Hoehe.
func cylinder(mat: Material, c: Vector3, r0: float, r1: float, h: float, seg: int = 12, col: Color = Color.WHITE, caps: bool = true, uv2: Vector2 = Vector2.ONE, emis: float = -1.0) -> void:
	var s := surf(mat)
	var base := s.v.size()
	var slope := (r0 - r1) / maxf(h, 0.0001)
	for i in range(seg + 1):
		var a := TAU * float(i) / seg
		var dx := cos(a)
		var dz := sin(a)
		var nn := Vector3(dx, slope, dz).normalized()
		s.v.append(c + Vector3(dx * r0, 0, dz * r0))
		s.v.append(c + Vector3(dx * r1, h, dz * r1))
		s.n.append(nn)
		s.n.append(nn)
		var uu := float(i) / seg * TAU * maxf(r0, 0.01)
		s.uv.append(Vector2(uu if emis < 0.0 else emis, 0.0))
		s.uv.append(Vector2(uu if emis < 0.0 else emis, h if emis < 0.0 else 0.0))
		s.uv2.append(uv2)
		s.uv2.append(uv2)
		s.c.append(col)
		s.c.append(col)
	for i in range(seg):
		var k := base + i * 2
		# Dreiecke im Uhrzeigersinn von aussen (Godot Frontface)
		s.idx.append(k)
		s.idx.append(k + 2)
		s.idx.append(k + 1)
		s.idx.append(k + 1)
		s.idx.append(k + 2)
		s.idx.append(k + 3)
	if caps and r1 > 0.001:
		cap_disc(mat, c + Vector3(0, h, 0), r1, seg, Vector3.UP, col, uv2, emis)
	if caps and r0 > 0.001:
		cap_disc(mat, c, r0, seg, Vector3.DOWN, col, uv2, emis)


func cap_disc(mat: Material, c: Vector3, r: float, seg: int, n: Vector3, col: Color, uv2: Vector2 = Vector2.ONE, emis: float = -1.0) -> void:
	var s := surf(mat)
	var base := s.v.size()
	s.v.append(c)
	s.n.append(n)
	s.uv.append(Vector2(0.5 if emis < 0.0 else emis, 0.5 if emis < 0.0 else 0.0))
	s.uv2.append(uv2)
	s.c.append(col)
	for i in range(seg):
		var a := TAU * float(i) / seg
		s.v.append(c + Vector3(cos(a) * r, 0, sin(a) * r))
		s.n.append(n)
		s.uv.append(Vector2(0.5 + cos(a) * 0.5 if emis < 0.0 else emis, 0.5 + sin(a) * 0.5 if emis < 0.0 else 0.0))
		s.uv2.append(uv2)
		s.c.append(col)
	for i in range(seg):
		var a0 := base + 1 + i
		var a1 := base + 1 + (i + 1) % seg
		if n.y > 0.0:
			s.idx.append(base)
			s.idx.append(a0)
			s.idx.append(a1)
		else:
			s.idx.append(base)
			s.idx.append(a1)
			s.idx.append(a0)


# Zusammenfassen: ein ArrayMesh mit einer Surface pro Material
func build() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for mat in order:
		var s: Surf = surfs[mat]
		if s.idx.is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = s.v
		arr[Mesh.ARRAY_NORMAL] = s.n
		arr[Mesh.ARRAY_TEX_UV] = s.uv
		arr[Mesh.ARRAY_TEX_UV2] = s.uv2
		arr[Mesh.ARRAY_COLOR] = s.c
		arr[Mesh.ARRAY_INDEX] = s.idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	return mesh


func instance(parent: Node3D, node_name: String = "Mesh", cast_shadow: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = build()
	if not cast_shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# Einzelnes Dreieck, Punkte gegen den Uhrzeigersinn von aussen gesehen (wie quad)
func tri(mat: Material, a: Vector3, b: Vector3, c: Vector3, n: Vector3, uva: Vector2 = Vector2.ZERO, uvb: Vector2 = Vector2.ZERO, uvc: Vector2 = Vector2.ZERO, uv2: Vector2 = Vector2.ONE, col: Color = Color.WHITE) -> void:
	var s := surf(mat)
	var base := s.v.size()
	s.v.append(a)
	s.v.append(b)
	s.v.append(c)
	for i in range(3):
		s.n.append(n)
		s.uv2.append(uv2)
		s.c.append(col)
	s.uv.append(uva)
	s.uv.append(uvb)
	s.uv.append(uvc)
	s.idx.append(base)
	s.idx.append(base + 2)
	s.idx.append(base + 1)


# ---------- Hilfen fuer den Allzweck-Shader (city_solid): Farbe, Rauheit, Metall, Leuchten ----------

# Achsenparallele Box mit einer Farbe. Unterseite weglassen (bottom=false), wenn sie verdeckt ist.
func sbox(mat: Material, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, col: Color, rough: float = 0.8, metal: float = 0.0, emis: float = 0.0, bottom_face: bool = false) -> void:
	var u2 := Vector2(rough, metal)
	var e := emis
	quad(mat, Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3.BACK, e, e, 0.0, 0.0, u2, col)
	quad(mat, Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3.FORWARD, e, e, 0.0, 0.0, u2, col)
	quad(mat, Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3.RIGHT, e, e, 0.0, 0.0, u2, col)
	quad(mat, Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), Vector3.LEFT, e, e, 0.0, 0.0, u2, col)
	quad(mat, Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x0, y1, z0), Vector3.UP, e, e, 0.0, 0.0, u2, col)
	if bottom_face:
		quad(mat, Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector3.DOWN, e, e, 0.0, 0.0, u2, col)


# Box um einen Mittelpunkt
func sbox_c(mat: Material, c: Vector3, size: Vector3, col: Color, rough: float = 0.8, metal: float = 0.0, emis: float = 0.0) -> void:
	sbox(mat, c.x - size.x * 0.5, c.y - size.y * 0.5, c.z - size.z * 0.5, c.x + size.x * 0.5, c.y + size.y * 0.5, c.z + size.z * 0.5, col, rough, metal, emis)


# Zylinder / Kegelstumpf fuer den Allzweck-Shader (c = Mittelpunkt der Grundflaeche)
func scyl(mat: Material, c: Vector3, r0: float, r1: float, h: float, col: Color, seg: int = 10, rough: float = 0.8, metal: float = 0.0, emis: float = 0.0, caps: bool = true) -> void:
	cylinder(mat, c, r0, r1, h, seg, col, caps, Vector2(rough, metal), emis)


# Beliebiges Viereck (p0..p3 gegen den Uhrzeigersinn von aussen) mit fester Farbe
func sq(mat: Material, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, col: Color, rough: float = 0.8, metal: float = 0.0, emis: float = 0.0) -> void:
	var n := (p1 - p0).cross(p3 - p0).normalized()
	quad(mat, p0, p1, p2, p3, n, emis, emis, 0.0, 0.0, Vector2(rough, metal), col)


# Dachform (Satteldach/Zeltdach) ueber Rechteck: Firsthoehe hh
func sgable(mat: Material, x0: float, z0: float, x1: float, z1: float, y: float, hh: float, col: Color, rough: float = 0.8, metal: float = 0.0) -> void:
	var cx := (x0 + x1) * 0.5
	# Firstrichtung entlang der laengeren Seite (Zeltdach bei fast quadratischer Grundflaeche)
	var u2 := Vector2(rough, metal)
	if (x1 - x0) >= (z1 - z0):
		var n1 := Vector3(0, (z1 - z0) * 0.5, hh).normalized()
		var n2 := Vector3(0, (z1 - z0) * 0.5, -hh).normalized()
		var zm := (z0 + z1) * 0.5
		quad(mat, Vector3(x0, y, z1), Vector3(x1, y, z1), Vector3(x1, y + hh, zm), Vector3(x0, y + hh, zm), n1, 0, 0, 0, 0, u2, col)
		quad(mat, Vector3(x1, y, z0), Vector3(x0, y, z0), Vector3(x0, y + hh, zm), Vector3(x1, y + hh, zm), n2, 0, 0, 0, 0, u2, col)
		tri(mat, Vector3(x1, y, z1), Vector3(x1, y, z0), Vector3(x1, y + hh, zm), Vector3.RIGHT, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, u2, col)
		tri(mat, Vector3(x0, y, z0), Vector3(x0, y, z1), Vector3(x0, y + hh, zm), Vector3.LEFT, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, u2, col)
	else:
		var zc := (z0 + z1) * 0.5
		var n1 := Vector3(hh, (x1 - x0) * 0.5, 0).normalized()
		var n2 := Vector3(-hh, (x1 - x0) * 0.5, 0).normalized()
		quad(mat, Vector3(x1, y, z1), Vector3(x1, y, z0), Vector3(cx, y + hh, z0), Vector3(cx, y + hh, z1), n1, 0, 0, 0, 0, u2, col)
		quad(mat, Vector3(x0, y, z0), Vector3(x0, y, z1), Vector3(cx, y + hh, z1), Vector3(cx, y + hh, z0), n2, 0, 0, 0, 0, u2, col)
		tri(mat, Vector3(x0, y, z1), Vector3(x1, y, z1), Vector3(cx, y + hh, zc), Vector3.BACK, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, u2, col)
		tri(mat, Vector3(x1, y, z0), Vector3(x0, y, z0), Vector3(cx, y + hh, zc), Vector3.FORWARD, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, u2, col)


# Beliebig gerichteter Kegelstumpf von p0 nach p1 (offene Enden), glatte Normalen. Fuer Aeste, Rohre, Stangen.
func tube(mat: Material, p0: Vector3, p1: Vector3, r0: float, r1: float, seg: int, col: Color, rough: float = 0.8, metal: float = 0.0, emis: float = 0.0) -> void:
	var axis := p1 - p0
	var len := axis.length()
	if len < 0.0001:
		return
	var a := axis / len
	var ref := Vector3.UP if absf(a.y) < 0.95 else Vector3.RIGHT
	var u := a.cross(ref).normalized()
	var v := a.cross(u).normalized()
	var s := surf(mat)
	var base := s.v.size()
	var slope := (r0 - r1) / len
	for i in range(seg + 1):
		var ang := TAU * float(i) / seg
		var d := u * cos(ang) + v * sin(ang)
		var nn := (d + a * slope).normalized()
		s.v.append(p0 + d * r0)
		s.v.append(p1 + d * r1)
		s.n.append(nn)
		s.n.append(nn)
		s.uv.append(Vector2(emis, 0.0))
		s.uv.append(Vector2(emis, 0.0))
		s.uv2.append(Vector2(rough, metal))
		s.uv2.append(Vector2(rough, metal))
		s.c.append(col)
		s.c.append(col)
	for i in range(seg):
		var k := base + i * 2
		# Orientierung: u x v = a (u cross v), d dreht sich von u nach v, Blick von aussen: Uhrzeigersinn
		s.idx.append(k)
		s.idx.append(k + 1)
		s.idx.append(k + 2)
		s.idx.append(k + 1)
		s.idx.append(k + 3)
		s.idx.append(k + 2)
