extends RefCounted
# Baeume, Straeucher, Gras und Blumen als MultiMesh.
# Nah: Laubkarten (viele kleine Quads mit gemalter Blatt-Textur, Alpha-Test, Licht durch die Blaetter) und Staemme mit Rinde und Aesten.
# Weit: wenige verformte Kugeln (Laub-Shader city_foliage_far). Die Baeume sind in Kacheln (CHUNK) sortiert, damit die
# Sichtweiten (visibility_range) pro Kachel zwischen Karten-Baum und Fern-Baum umschalten.

const Tex = preload("res://scripts/city_tex.gd")

const CHUNK := 144.0
const NEAR_RANGE := 120.0  # bis hierher Laubkarten, danach Fernbaum
const GRASS_RANGE := 55.0

static var _mats := {}
static var _meshes := {}
static var _atlas := {}

# gesammelte Instanzen je Typ: Array von [Transform3D, Color]
var inst := {"round": [], "maple": [], "birch": [], "oval": [], "conifer": [], "bush": [], "tuft": [], "flowers": [], "round_far": [], "conifer_far": []}


# ---------------------------------------------------------------- Texturen

static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


# Ein Blatt: Wurzel bei (cx,cy), Richtung ang, Laenge ln, halbe Breite wd (Pixel). shape 0 eiförmig, 1 spitz (Birke)
static func _leaf(img: Image, cx: float, cy: float, ang: float, ln: float, wd: float, shade: float, shape: int) -> void:
	var ca := cos(ang)
	var sa := sin(ang)
	var r := int(ln) + 2
	for y in range(int(cy) - r, int(cy) + r + 1):
		for x in range(int(cx) - r, int(cx) + r + 1):
			var dx := x - cx
			var dy := y - cy
			var u := (dx * ca + dy * sa) / ln
			if u < 0.0 or u > 1.0:
				continue
			var v := (-dx * sa + dy * ca) / wd
			var prof := sin(PI * pow(u, 0.75 if shape == 0 else 1.1))
			if absf(v) > prof:
				continue
			var k := shade * (0.88 + 0.22 * (1.0 - absf(v) / maxf(prof, 0.01)))
			if absf(v) * wd < 0.7:
				k *= 1.22
			_px(img, x, y, Color(k * 1.04, k, k * 0.90, 1.0))


# Ahornblatt: fuenf Lappen um den Mittelpunkt
static func _maple(img: Image, cx: float, cy: float, ang: float, size: float, shade: float) -> void:
	var r := int(size) + 2
	for y in range(int(cy) - r, int(cy) + r + 1):
		for x in range(int(cx) - r, int(cx) + r + 1):
			var dx := x - cx
			var dy := y - cy
			var d := sqrt(dx * dx + dy * dy) / size
			if d > 1.0:
				continue
			var th := atan2(dy, dx) - ang
			var lobes := pow(absf(cos(th * 2.5)), 0.9)
			if d > 0.30 + 0.70 * lobes:
				continue
			var k := shade * (0.9 + 0.2 * (1.0 - d))
			if absf(sin(th * 2.5)) * d * size < 0.7:
				k *= 1.2
			_px(img, x, y, Color(k * 1.04, k, k * 0.90, 1.0))


# Nadelzweig: Mittelachse mit vielen kurzen Nadeln
static func _needles(img: Image, ox: float, oy: float, rng: RandomNumberGenerator, cell: int) -> void:
	var cx := ox + cell * 0.5
	for i in range(34):
		var t := float(i) / 33.0
		var y := oy + cell * (0.96 - 0.90 * t)
		var span := cell * 0.46 * sin(PI * (0.12 + 0.85 * t) * 0.95) * (0.9 + 0.2 * rng.randf())
		for sgn in [-1.0, 1.0]:
			var k := rng.randf_range(0.5, 1.0)
			var n_len := span * rng.randf_range(0.8, 1.05)
			var steps := int(n_len)
			for s in range(steps + 1):
				var f := float(s) / maxf(steps, 1)
				var x: float = cx + sgn * f * n_len
				var yy := y - f * cell * 0.09 + (1.0 - t) * f * 2.0
				for w in range(2):
					_px(img, int(x), int(yy) + w, Color(k * 0.95, k, k * 0.88, 1.0))
	for yy in range(int(oy + cell * 0.04), int(oy + cell * 0.98)):
		for w in range(-1, 2):
			_px(img, int(cx) + w, yy, Color(0.42, 0.36, 0.30, 1.0))


# Grasbueschel: Halme als schmale, gebogene Spitzen
static func _blades(img: Image, ox: float, oy: float, rng: RandomNumberGenerator, cell: int, n: int) -> void:
	for i in range(n):
		var bx := ox + cell * rng.randf_range(0.08, 0.92)
		var h := cell * rng.randf_range(0.45, 0.98)
		var lean := rng.randf_range(-0.35, 0.35) * h
		var w0 := rng.randf_range(2.0, 4.0)
		var k := rng.randf_range(0.55, 1.0)
		for s in range(int(h)):
			var f := float(s) / h
			var x := bx + lean * f * f
			var half := w0 * (1.0 - f) * 0.5 + 0.4
			for xx in range(int(x - half), int(x + half) + 1):
				_px(img, xx, int(oy + cell - 1 - s), Color(k * (0.75 + 0.35 * f), k, k * 0.8, 1.0))


# Bluetenstaengel mit kleinen Blueten (hell, wird mit der Instanzfarbe getoent)
static func _blossoms(img: Image, ox: float, oy: float, rng: RandomNumberGenerator, cell: int) -> void:
	for i in range(7):
		var bx := ox + cell * rng.randf_range(0.12, 0.88)
		var top := oy + cell * rng.randf_range(0.15, 0.55)
		for yy in range(int(top), int(oy + cell)):
			_px(img, int(bx), yy, Color(0.22, 0.45, 0.18, 1.0))
		var pr := rng.randf_range(3.5, 6.5)
		for yy in range(int(top - pr) - 1, int(top + pr) + 2):
			for xx in range(int(bx - pr) - 1, int(bx + pr) + 2):
				var d := Vector2(xx - bx, yy - top).length()
				if d <= pr:
					var pet := 0.85 + 0.15 * sin(atan2(yy - top, xx - bx) * 5.0)
					var c := 1.0 if d > pr * 0.35 else 0.55
					_px(img, xx, yy, Color(c * pet, c * pet, c * pet * 0.95, 1.0))


# Atlas 512x512 aus vier 256er-Zellen
static func atlas(kind: String) -> ImageTexture:
	if _atlas.has(kind):
		return _atlas[kind]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var img := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.6, 0.6, 0.55, 0.0))
	for cell_i in range(4):
		var ox := (cell_i % 2) * 256
		var oy := (cell_i / 2) * 256
		match kind:
			"oak":
				for i in range(46):
					_leaf(img, ox + rng.randf_range(20, 236), oy + rng.randf_range(20, 236), rng.randf() * TAU, rng.randf_range(34, 50), rng.randf_range(14, 21), rng.randf_range(0.55, 1.0), 0)
			"maple":
				for i in range(24):
					_maple(img, ox + rng.randf_range(24, 232), oy + rng.randf_range(24, 232), rng.randf() * TAU, rng.randf_range(24, 36), rng.randf_range(0.55, 1.0))
			"birch":
				for i in range(54):
					_leaf(img, ox + rng.randf_range(20, 236), oy + rng.randf_range(20, 236), rng.randf() * TAU, rng.randf_range(26, 38), rng.randf_range(11, 15), rng.randf_range(0.6, 1.0), 1)
			"needle":
				_needles(img, ox, oy, rng, 256)
			"grass":
				_blades(img, ox, oy, rng, 256, 34)
			"flowers":
				_blades(img, ox, oy, rng, 256, 14)
				_blossoms(img, ox, oy, rng, 256)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_atlas[kind] = tex
	return tex


# ---------------------------------------------------------------- Materialien

static func card_material(kind: String, cut: float = 0.5, trans: float = 0.55, wind: float = 1.0) -> ShaderMaterial:
	var key := "card_%s_%.2f_%.2f_%.2f" % [kind, cut, trans, wind]
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://scripts/city_foliage.gdshader")
		m.set_shader_parameter("leaf_tex", atlas(kind))
		m.set_shader_parameter("alpha_cut", cut)
		m.set_shader_parameter("trans", trans)
		m.set_shader_parameter("wind", wind)
		_mats[key] = m
	return _mats[key]


# Fern-Laub (Kugel-Krone)
static func foliage_material() -> ShaderMaterial:
	if not _mats.has("far"):
		var m := ShaderMaterial.new()
		m.shader = load("res://scripts/city_foliage_far.gdshader")
		m.set_shader_parameter("n_leaf", Tex.noise("leaf"))
		m.set_shader_parameter("n_blotch", Tex.noise("blotch"))
		_mats["far"] = m
	return _mats["far"]


static func bark_material(birch: bool = false) -> ShaderMaterial:
	var key := "bark_%s" % birch
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://scripts/city_bark.gdshader")
		m.set_shader_parameter("n_grain", Tex.noise("grain"))
		m.set_shader_parameter("n_blotch", Tex.noise("blotch"))
		m.set_shader_parameter("birch", birch)
		_mats[key] = m
	return _mats[key]


# ---------------------------------------------------------------- Netze: Karten

class Cards:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()


# Karte um center, Normale nrm (grob), Breite sw / Hoehe sh, Drehung roll; soft_n = weiche Beleuchtungs-Normale
static func add_card(a: Cards, center: Vector3, nrm: Vector3, sw: float, sh: float, roll: float, cell: int, flip: bool, soft_n: Vector3, col: Color) -> void:
	var up := Vector3.UP if absf(nrm.y) < 0.95 else Vector3.RIGHT
	var t1 := up.cross(nrm).normalized()
	var t2 := nrm.cross(t1).normalized()
	var cr := cos(roll)
	var sr := sin(roll)
	var e1 := (t1 * cr + t2 * sr) * sw * 0.5
	var e2 := (-t1 * sr + t2 * cr) * sh * 0.5
	var b := a.v.size()
	a.v.append(center - e1 - e2)
	a.v.append(center + e1 - e2)
	a.v.append(center + e1 + e2)
	a.v.append(center - e1 + e2)
	var ox := (cell % 2) * 0.5
	var oy := (cell / 2) * 0.5
	var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for i in range(4):
		var q: Vector2 = uvs[(i + 1) % 4] if flip else uvs[i]
		a.uv.append(Vector2(ox + q.x * 0.5, oy + q.y * 0.5))
		a.n.append(soft_n)
		a.c.append(col)
	a.idx.append_array(PackedInt32Array([b, b + 1, b + 2, b, b + 2, b + 3]))


# Karten auf und in Ellipsoiden. lobes = [[Mitte, Radien], ...]
static func cards_crown(a: Cards, lobes: Array, count: int, size: Vector2, seed_v: int, crown_c: Vector3, crown_r: float, droop: float = 0.0, tint_var: float = 0.08) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var vol := 0.0
	for l in lobes:
		var r: Vector3 = l[1]
		vol += r.x * r.y * r.z
	for i in range(count):
		var pick := rng.randf() * vol
		var lobe: Array = lobes[0]
		for l in lobes:
			var r: Vector3 = l[1]
			pick -= r.x * r.y * r.z
			if pick <= 0.0:
				lobe = l
				break
		var d := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		var rr := 0.55 + 0.45 * sqrt(rng.randf())
		var rad: Vector3 = lobe[1]
		var p: Vector3 = lobe[0] + d * rad * rr
		var soft := (p - crown_c).normalized()
		var nrm := (soft * 0.75 + Vector3(rng.randfn(), rng.randfn(), rng.randfn()) * 0.28 + Vector3(0, droop, 0)).normalized()
		var dist := clampf((p - crown_c).length() / crown_r, 0.0, 1.3)
		var ao := lerpf(0.42, 1.0, smoothstep(0.25, 1.05, dist)) * lerpf(0.72, 1.0, clampf(soft.y * 0.5 + 0.6, 0.0, 1.0))
		var hue := rng.randf_range(-tint_var, tint_var)
		var col := Color(ao * (1.0 + hue * 1.6), ao * (1.0 + hue * 0.3), ao * (1.0 - hue * 1.4), 1.0)
		var sz := rng.randf_range(size.x, size.y)
		add_card(a, p, nrm, sz, sz * rng.randf_range(0.85, 1.15), rng.randf() * TAU, rng.randi() % 4, rng.randf() < 0.5, (soft * 0.85 + nrm * 0.15).normalized(), col)


# Nadelbaum: Etagen mit nach aussen und unten haengenden Zweigen
static func cards_conifer(a: Cards, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var tiers := 9
	for t in range(tiers):
		var f := float(t) / float(tiers - 1)
		var y := 1.7 + 6.4 * f
		var reach := 2.05 * pow(1.0 - f, 0.85) + 0.22
		var cnt := 10 - int(f * 5.0)
		for i in range(cnt):
			var ang := TAU * (float(i) + rng.randf() * 0.7) / cnt + t * 0.6
			var dir := Vector3(cos(ang), 0, sin(ang))
			var ln := reach * rng.randf_range(0.8, 1.15) + 0.5
			var droop := 0.55 - 0.25 * f
			var cen := dir * ln * 0.5 + Vector3(0, y - ln * 0.5 * droop * 0.6, 0)
			var nrm := (Vector3.UP + dir * droop).normalized()
			var ao := lerpf(0.45, 1.0, f * 0.6 + 0.4 * rng.randf()) * 0.95
			var col := Color(ao, ao, ao, 1.0)
			var soft := (Vector3(dir.x, 0.35, dir.z) + Vector3(rng.randfn(), 0, rng.randfn()) * 0.15).normalized()
			var along := (dir - nrm * dir.dot(nrm)).normalized()
			var side := nrm.cross(along).normalized()
			var b := a.v.size()
			var hw := ln * 0.42 + 0.35
			a.v.append(cen - side * hw * 0.5 - along * ln * 0.5)
			a.v.append(cen + side * hw * 0.5 - along * ln * 0.5)
			a.v.append(cen + side * hw * 0.5 + along * ln * 0.5)
			a.v.append(cen - side * hw * 0.5 + along * ln * 0.5)
			var cell := rng.randi() % 4
			var ox := (cell % 2) * 0.5
			var oy := (cell / 2) * 0.5
			a.uv.append(Vector2(ox, oy + 0.5))
			a.uv.append(Vector2(ox + 0.5, oy + 0.5))
			a.uv.append(Vector2(ox + 0.5, oy))
			a.uv.append(Vector2(ox, oy))
			for k in range(4):
				a.n.append(soft)
				a.c.append(col)
			a.idx.append_array(PackedInt32Array([b, b + 1, b + 2, b, b + 2, b + 3]))
	for i in range(3):
		var ang := TAU * i / 3.0
		add_card(a, Vector3(0, 8.4, 0), Vector3(cos(ang), 0.0, sin(ang)), 0.7, 1.8, 0.0, i, false, Vector3.UP, Color(0.9, 0.9, 0.9, 1.0))


# ---------------------------------------------------------------- Netze: Staemme und Aeste

# Verjuengte Roehre p0 -> p1 mit Radius r0 -> r1, UV: u rund (Umfang in Metern), v lang (Meter)
static func add_tube(a: Cards, p0: Vector3, p1: Vector3, r0: float, r1: float, seg: int, col: Color, bend: Vector3 = Vector3.ZERO) -> void:
	var dir := p1 - p0
	var ln := dir.length()
	var y := dir / maxf(ln, 0.0001)
	var x := (Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD).cross(y).normalized()
	var z := y.cross(x)
	var b := a.v.size()
	var steps := 3
	for s in range(steps + 1):
		var f := float(s) / steps
		var cen := p0 + dir * f + bend * sin(PI * f)
		var r := lerpf(r0, r1, f)
		for i in range(seg + 1):
			var ang := TAU * float(i) / seg
			var o := x * cos(ang) + z * sin(ang)
			a.v.append(cen + o * r)
			a.n.append(o)
			a.uv.append(Vector2(float(i) / seg * TAU * maxf(r0, 0.05), f * ln))
			a.c.append(col)
	for s in range(steps):
		for i in range(seg):
			var k := b + s * (seg + 1) + i
			a.idx.append_array(PackedInt32Array([k, k + 1, k + seg + 1, k + 1, k + seg + 2, k + seg + 1]))


static func to_mesh(a: Cards, mat: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if a.idx.is_empty():
		return mesh
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = a.v
	arr[Mesh.ARRAY_NORMAL] = a.n
	arr[Mesh.ARRAY_TEX_UV] = a.uv
	arr[Mesh.ARRAY_COLOR] = a.c
	arr[Mesh.ARRAY_INDEX] = a.idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, mat)
	return mesh


# Aeste: Hauptast steigt auf, Seitenzweige gabeln ab
static func branch(a: Cards, rng: RandomNumberGenerator, p0: Vector3, dir: Vector3, length: float, r0: float, depth: int, col: Color) -> void:
	var p1 := p0 + dir * length
	var r1 := r0 * 0.55
	var bend := Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(0.0, 0.25), rng.randf_range(-0.25, 0.25)) * length * 0.4
	add_tube(a, p0, p1, r0, r1, 6, col, bend)
	if depth > 0:
		for k in range(2):
			var f := rng.randf_range(0.45, 0.85)
			var q := p0.lerp(p1, f)
			var nd := (dir + Vector3(rng.randfn(), rng.randf_range(0.0, 0.6), rng.randfn()) * 0.8).normalized()
			branch(a, rng, q, nd, length * rng.randf_range(0.45, 0.65), r1 * 0.7, depth - 1, col)


static func trunk(kind: String) -> ArrayMesh:
	var key := "trunk_" + kind
	if _meshes.has(key):
		return _meshes[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var a := Cards.new()
	var bark := Color(0.34, 0.26, 0.18)
	match kind:
		"round":
			add_tube(a, Vector3(0, -0.1, 0), Vector3(0.05, 2.0, 0.0), 0.34, 0.20, 10, bark)
			add_tube(a, Vector3(0.05, 2.0, 0), Vector3(0.0, 4.0, 0.05), 0.20, 0.14, 8, bark)
			for i in range(5):
				var ang := TAU * i / 5.0 + 0.4
				branch(a, rng, Vector3(0, 3.1 + 0.25 * i, 0), Vector3(cos(ang) * 0.75, 0.8, sin(ang) * 0.75).normalized(), 2.6 - 0.2 * i, 0.11, 2, bark)
			for i in range(4):
				var ang := TAU * i / 4.0 + 0.9
				add_tube(a, Vector3(cos(ang) * 0.42, 0.0, sin(ang) * 0.42), Vector3(cos(ang) * 0.14, 0.45, sin(ang) * 0.14), 0.07, 0.12, 5, bark)
		"maple":
			bark = Color(0.40, 0.32, 0.26)
			add_tube(a, Vector3(0, -0.1, 0), Vector3(0, 3.0, 0.0), 0.25, 0.13, 9, bark)
			for i in range(5):
				var ang := TAU * i / 5.0 + 0.2
				branch(a, rng, Vector3(0, 2.4 + 0.2 * i, 0), Vector3(cos(ang) * 0.7, 0.9, sin(ang) * 0.7).normalized(), 2.4 - 0.15 * i, 0.09, 2, bark)
		"birch":
			bark = Color(0.9, 0.9, 0.86)
			add_tube(a, Vector3(0, -0.1, 0), Vector3(0.12, 3.0, 0.0), 0.15, 0.10, 8, bark)
			add_tube(a, Vector3(0.12, 3.0, 0), Vector3(0.0, 5.8, 0.15), 0.10, 0.05, 7, bark)
			for i in range(6):
				var ang := TAU * i / 6.0
				branch(a, rng, Vector3(0.06, 3.2 + 0.45 * i, 0.05), Vector3(cos(ang) * 0.6, 1.0, sin(ang) * 0.6).normalized(), 1.7, 0.045, 1, bark)
		"oval":
			add_tube(a, Vector3(0, -0.1, 0), Vector3(0, 4.4, 0.0), 0.26, 0.11, 9, bark)
			for i in range(4):
				var ang := TAU * i / 4.0 + 0.5
				branch(a, rng, Vector3(0, 3.8 + 0.35 * i, 0), Vector3(cos(ang) * 0.35, 1.0, sin(ang) * 0.35).normalized(), 2.2, 0.07, 1, bark)
		"conifer":
			bark = Color(0.26, 0.18, 0.12)
			add_tube(a, Vector3(0, -0.1, 0), Vector3(0, 8.5, 0.0), 0.24, 0.03, 8, bark)
	var m := to_mesh(a, bark_material(kind == "birch"))
	_meshes[key] = m
	return m


static func far_trunk(kind: String) -> ArrayMesh:
	var key := "ftrunk_" + kind
	if _meshes.has(key):
		return _meshes[key]
	var a := Cards.new()
	var con := kind.begins_with("conifer")
	add_tube(a, Vector3(0, -0.1, 0), Vector3(0, 8.0 if con else 4.4, 0), 0.26, 0.08, 5, Color(0.2, 0.14, 0.1) if con else Color(0.30, 0.22, 0.16))
	var m := to_mesh(a, bark_material(false))
	_meshes[key] = m
	return m


# ---------------------------------------------------------------- Netze: Kronen

static func crown(kind: String) -> ArrayMesh:
	var key := "crown_" + kind
	var far := kind.ends_with("_far")
	if far:
		kind = kind.trim_suffix("_far")
	if _meshes.has(key):
		return _meshes[key]
	if far:
		var fm := _far_crown(kind)
		_meshes[key] = fm
		return fm
	var a := Cards.new()
	var mat: ShaderMaterial
	match kind:
		"round":
			var lobes := [[Vector3(0, 6.4, 0), Vector3(2.4, 2.1, 2.4)], [Vector3(1.7, 5.7, 0.6), Vector3(1.8, 1.5, 1.8)], [Vector3(-1.6, 5.8, -0.5), Vector3(1.8, 1.5, 1.8)],
				[Vector3(0.4, 5.6, -1.7), Vector3(1.7, 1.4, 1.7)], [Vector3(-0.3, 5.8, 1.8), Vector3(1.7, 1.4, 1.7)], [Vector3(0.6, 7.7, 0.3), Vector3(1.6, 1.3, 1.6)],
				[Vector3(-1.0, 7.3, -0.8), Vector3(1.4, 1.2, 1.4)], [Vector3(1.9, 6.9, -0.7), Vector3(1.3, 1.1, 1.3)]]
			cards_crown(a, lobes, 440, Vector2(0.95, 1.5), 7, Vector3(0, 6.2, 0), 3.3)
			mat = card_material("oak")
		"maple":
			var lobes := [[Vector3(0, 5.8, 0), Vector3(2.1, 1.9, 2.1)], [Vector3(1.3, 5.2, 0.5), Vector3(1.5, 1.3, 1.5)], [Vector3(-1.2, 5.3, -0.5), Vector3(1.5, 1.3, 1.5)],
				[Vector3(0.3, 7.0, 0.2), Vector3(1.4, 1.2, 1.4)], [Vector3(0.1, 5.1, -1.3), Vector3(1.3, 1.1, 1.3)], [Vector3(-0.2, 5.2, 1.3), Vector3(1.3, 1.1, 1.3)]]
			cards_crown(a, lobes, 360, Vector2(0.9, 1.4), 9, Vector3(0, 5.8, 0), 2.9)
			mat = card_material("maple")
		"birch":
			var lobes := [[Vector3(0, 6.9, 0), Vector3(1.3, 2.5, 1.3)], [Vector3(0.5, 5.4, 0.3), Vector3(1.4, 1.5, 1.4)], [Vector3(-0.5, 8.4, -0.2), Vector3(0.9, 1.3, 0.9)],
				[Vector3(-0.6, 5.0, -0.4), Vector3(1.3, 1.2, 1.3)]]
			cards_crown(a, lobes, 270, Vector2(0.8, 1.2), 13, Vector3(0, 6.6, 0), 3.0, -0.35, 0.05)
			mat = card_material("birch", 0.5, 0.7)
		"oval":
			var lobes := [[Vector3(0, 6.2, 0), Vector3(1.9, 2.4, 1.9)], [Vector3(0.9, 8.0, 0.3), Vector3(1.5, 1.8, 1.5)], [Vector3(-0.8, 7.6, -0.5), Vector3(1.5, 1.7, 1.5)],
				[Vector3(0.7, 4.9, -0.6), Vector3(1.5, 1.4, 1.5)], [Vector3(-0.8, 5.2, 0.7), Vector3(1.4, 1.3, 1.4)], [Vector3(0, 9.4, 0), Vector3(1.0, 1.2, 1.0)]]
			cards_crown(a, lobes, 340, Vector2(0.9, 1.4), 17, Vector3(0, 6.8, 0), 3.4)
			mat = card_material("oak")
		"conifer":
			cards_conifer(a, 21)
			mat = card_material("needle", 0.5, 0.25, 0.6)
		"bush":
			var lobes := [[Vector3(0, 0.55, 0), Vector3(0.8, 0.6, 0.8)], [Vector3(0.6, 0.45, 0.3), Vector3(0.55, 0.5, 0.55)], [Vector3(-0.5, 0.45, -0.3), Vector3(0.55, 0.5, 0.55)]]
			cards_crown(a, lobes, 70, Vector2(0.38, 0.62), 23, Vector3(0, 0.55, 0), 0.95)
			mat = card_material("oak", 0.5, 0.5, 0.5)
	var m := to_mesh(a, mat)
	_meshes[key] = m
	return m


# ---------------------------------------------------------------- Fern-Kronen (verformte Kugeln)

static func add_puff(arr: Dictionary, center: Vector3, r: Vector3, crown_center: Vector3, rng: RandomNumberGenerator, seg: int = 9, rings: int = 6, soft: float = 0.6) -> void:
	var v: PackedVector3Array = arr["v"]
	var n: PackedVector3Array = arr["n"]
	var c: PackedColorArray = arr["c"]
	var idx: PackedInt32Array = arr["i"]
	var base := v.size()
	var ph := rng.randf() * 10.0
	for i in range(rings + 1):
		var th := PI * float(i) / rings
		for j in range(seg):
			var ph2 := TAU * float(j) / seg
			var d := Vector3(sin(th) * cos(ph2), cos(th), sin(th) * sin(ph2))
			var jit := 1.0 + 0.16 * sin(ph + d.x * 3.1 + d.z * 2.3) + 0.1 * sin(ph * 1.7 + d.y * 4.3)
			var p := center + Vector3(d.x * r.x, d.y * r.y, d.z * r.z) * jit
			v.append(p)
			var radial := (p - crown_center).normalized()
			n.append(d.lerp(radial, soft).normalized())
			var ao := lerpf(0.5, 1.0, clampf(radial.y * 0.5 + 0.55, 0.0, 1.0))
			c.append(Color(ao, ao, ao, 1.0))
	for i in range(rings):
		for j in range(seg):
			var a := base + i * seg + j
			var b := base + i * seg + (j + 1) % seg
			var cc := base + (i + 1) * seg + j
			var dd := base + (i + 1) * seg + (j + 1) % seg
			idx.append(a)
			idx.append(cc)
			idx.append(b)
			idx.append(b)
			idx.append(cc)
			idx.append(dd)


static func _far_crown(kind: String) -> ArrayMesh:
	var puffs := []
	var cc := Vector3.ZERO
	match kind:
		"oval":
			cc = Vector3(0, 6.8, 0)
			puffs = [[Vector3(0, 6.2, 0), Vector3(1.9, 2.4, 1.9)], [Vector3(0.9, 8.0, 0.3), Vector3(1.5, 1.8, 1.5)], [Vector3(-0.8, 7.6, -0.5), Vector3(1.5, 1.7, 1.5)],
				[Vector3(0.7, 4.9, -0.6), Vector3(1.5, 1.4, 1.5)], [Vector3(-0.8, 5.2, 0.7), Vector3(1.4, 1.3, 1.4)], [Vector3(0, 9.4, 0), Vector3(1.0, 1.2, 1.0)]]
		"conifer":
			cc = Vector3(0, 5.0, 0)
			puffs = [[Vector3(0, 2.2, 0), Vector3(2.0, 1.2, 2.0)], [Vector3(0, 3.6, 0), Vector3(1.7, 1.2, 1.7)], [Vector3(0, 5.0, 0), Vector3(1.4, 1.2, 1.4)],
				[Vector3(0, 6.3, 0), Vector3(1.05, 1.1, 1.05)], [Vector3(0, 7.4, 0), Vector3(0.7, 1.0, 0.7)], [Vector3(0, 8.3, 0), Vector3(0.4, 0.8, 0.4)]]
		_:
			cc = Vector3(0, 6.2, 0)
			puffs = [[Vector3(0, 6.4, 0), Vector3(2.4, 2.1, 2.4)], [Vector3(1.7, 5.7, 0.6), Vector3(1.8, 1.5, 1.8)], [Vector3(-1.6, 5.8, -0.5), Vector3(1.8, 1.5, 1.8)],
				[Vector3(0.4, 5.6, -1.7), Vector3(1.7, 1.4, 1.7)], [Vector3(-0.3, 5.8, 1.8), Vector3(1.7, 1.4, 1.7)], [Vector3(0.6, 7.7, 0.3), Vector3(1.6, 1.3, 1.6)],
				[Vector3(-1.0, 7.3, -0.8), Vector3(1.4, 1.2, 1.4)], [Vector3(1.9, 6.9, -0.7), Vector3(1.3, 1.1, 1.3)]]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var arr := {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "i": PackedInt32Array()}
	for p in puffs:
		add_puff(arr, p[0], p[1], cc, rng, 6, 3)
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = arr["v"]
	a[Mesh.ARRAY_NORMAL] = arr["n"]
	a[Mesh.ARRAY_COLOR] = arr["c"]
	a[Mesh.ARRAY_INDEX] = arr["i"]
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	m.surface_set_material(0, foliage_material())
	return m


# ---------------------------------------------------------------- Gras und Blumen

static func tuft_mesh(kind: String) -> ArrayMesh:
	var key := "tuft_" + kind
	if _meshes.has(key):
		return _meshes[key]
	var a := Cards.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var s := 0.38 if kind == "tuft" else 0.38
	for i in range(3):
		var ang := PI * i / 3.0 + rng.randf() * 0.3
		var dir := Vector3(cos(ang), 0, sin(ang))
		var b := a.v.size()
		a.v.append(-dir * s * 0.5)
		a.v.append(dir * s * 0.5)
		a.v.append(dir * s * 0.5 + Vector3(0, s, 0))
		a.v.append(-dir * s * 0.5 + Vector3(0, s, 0))
		var cell := i % 4
		var ox := (cell % 2) * 0.5
		var oy := (cell / 2) * 0.5
		a.uv.append(Vector2(ox, oy + 0.5))
		a.uv.append(Vector2(ox + 0.5, oy + 0.5))
		a.uv.append(Vector2(ox + 0.5, oy))
		a.uv.append(Vector2(ox, oy))
		for k in range(4):
			a.n.append(Vector3.UP)
			a.c.append(Color(0.6, 0.6, 0.6, 1.0) if k < 2 else Color(1, 1, 1, 1))
		a.idx.append_array(PackedInt32Array([b, b + 1, b + 2, b, b + 2, b + 3]))
	var m := to_mesh(a, card_material("grass" if kind == "tuft" else "flowers", 0.5, 0.35, 0.7))
	_meshes[key] = m
	return m


# ---------------------------------------------------------------- Eintragen und Bauen

# Baum eintragen. kind: round / oval / conifer / bush / tuft / flowers (round wird teils Ahorn oder Birke)
func add(kind: String, pos: Vector3, rng: RandomNumberGenerator, scale_mul: float = 1.0) -> void:
	if kind == "round":
		var sp := rng.randf()
		if sp < 0.28:
			kind = "maple"
		elif sp < 0.42:
			kind = "birch"
	var s := rng.randf_range(0.8, 1.2) * scale_mul
	if kind == "tuft" or kind == "flowers":
		s = scale_mul
	var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s)), pos)
	var col: Color
	var r := rng.randf()
	if kind.begins_with("conifer"):
		col = Color(0.07, 0.2, 0.1)
		col = col.lerp(Color(0.1, 0.26, 0.14), rng.randf())
		col = col.lerp(Color(0.08, 0.2, 0.16), rng.randf() * 0.4)
	elif kind == "tuft":
		col = Color(0.28, 0.45, 0.12).lerp(Color(0.42, 0.52, 0.16), rng.randf())
		if rng.randf() < 0.12:
			col = Color(0.5, 0.45, 0.16)
	elif kind == "flowers":
		var pal := [Color(0.95, 0.25, 0.25), Color(1.0, 0.82, 0.2), Color(0.95, 0.95, 0.98), Color(0.8, 0.35, 0.85), Color(1.0, 0.55, 0.7), Color(0.4, 0.5, 1.0)]
		col = pal[rng.randi() % pal.size()]
	elif kind == "birch":
		col = Color(0.42, 0.62, 0.18).lerp(Color(0.55, 0.65, 0.2), rng.randf())
		if r < 0.15:
			col = Color(0.75, 0.62, 0.18)
	elif kind == "maple":
		if r < 0.45:
			col = Color(0.22, 0.46, 0.12).lerp(Color(0.3, 0.5, 0.12), rng.randf())
		elif r < 0.62:
			col = Color(0.78, 0.58, 0.12)
		elif r < 0.85:
			col = Color(0.78, 0.3, 0.08)
		else:
			col = Color(0.62, 0.12, 0.1)
	elif r < 0.62:
		col = Color(0.2, 0.42, 0.1).lerp(Color(0.12, 0.34, 0.1), rng.randf())
	elif r < 0.84:
		col = Color(0.36, 0.5, 0.12).lerp(Color(0.28, 0.46, 0.1), rng.randf())
	elif r < 0.94:
		col = Color(0.62, 0.46, 0.1).lerp(Color(0.56, 0.5, 0.1), rng.randf())
	else:
		col = Color(0.52, 0.2, 0.1)
	inst[kind].append([xf, col])


func _multimesh(mesh: Mesh, list: Array, use_color: bool) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = use_color
	mm.mesh = mesh
	mm.instance_count = list.size()
	for i in range(list.size()):
		mm.set_instance_transform(i, list[i][0])
		if use_color:
			mm.set_instance_color(i, list[i][1])
	return mm


func _instance(parent: Node3D, node_name: String, mm: MultiMesh, shadow: bool, vr_begin: float, vr_end: float) -> void:
	var mi := MultiMeshInstance3D.new()
	mi.name = node_name
	mi.multimesh = mm
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_begin = vr_begin
	mi.visibility_range_end = vr_end
	parent.add_child(mi)


func commit(parent: Node3D) -> void:
	for kind in inst:
		var list: Array = inst[kind]
		if list.is_empty():
			continue
		if kind.ends_with("_far"):
			# Wald am Rand: ein Block pro Typ, ohne Schatten
			_instance(parent, "Crowns_" + kind, _multimesh(crown(kind), list, true), false, 0.0, 0.0)
			_instance(parent, "Trunks_" + kind, _multimesh(far_trunk(kind), list, false), false, 0.0, 0.0)
			continue
		# Kacheln: Stadtbaeume nach Lage sortieren, je Kachel Nah- und Fernversion
		var chunks := {}
		for e in list:
			var p: Vector3 = (e[0] as Transform3D).origin
			var k := Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))
			if not chunks.has(k):
				chunks[k] = []
			chunks[k].append(e)
		for k in chunks:
			var cl: Array = chunks[k]
			var tag := "%s_%d_%d" % [kind, k.x, k.y]
			if kind == "tuft" or kind == "flowers":
				_instance(parent, "Grass_" + tag, _multimesh(tuft_mesh(kind), cl, true), false, 0.0, GRASS_RANGE)
				continue
			_instance(parent, "Crowns_" + tag, _multimesh(crown(kind), cl, true), true, 0.0, NEAR_RANGE)
			if kind != "bush":
				_instance(parent, "Trunks_" + tag, _multimesh(trunk(kind), cl, false), true, 0.0, NEAR_RANGE)
				var fk := "conifer_far" if kind == "conifer" else ("oval_far" if kind == "oval" else "round_far")
				_instance(parent, "FarCrowns_" + tag, _multimesh(crown(fk), cl, true), false, NEAR_RANGE, 0.0)
				_instance(parent, "FarTrunks_" + tag, _multimesh(far_trunk(fk), cl, false), false, NEAR_RANGE, 0.0)
