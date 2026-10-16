extends RefCounted
# Park: Rasen mit Wegen, Brunnen, Baeume, Hecken, Baenke, Laternen.

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


func build(parent: Node3D, cx: float, cz: float, ix: int, iz: int, props) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(ix, iz)) + 77
	var node := Node3D.new()
	node.name = "Park_%d_%d" % [ix, iz]
	node.position = Vector3(cx, 0, cz)
	parent.add_child(node)
	var variant := rng.randi() % 3
	var mb := MB.new()
	var solid := M.solid()
	var y := 0.17
	var h := 26.0
	# Rasenflaeche (UV = lokale Meter)
	mb.quad(lawn_material(variant), Vector3(-h, y, h), Vector3(h, y, h), Vector3(h, y, -h), Vector3(-h, y, -h), Vector3.UP, -h, h, h, -h)
	# Rasenkante aus Stein
	var edge_c := Color(0.55, 0.53, 0.5)
	mb.sbox(solid, -h - 0.15, 0.1, h, h + 0.15, 0.2, h + 0.15, edge_c, 0.8)
	mb.sbox(solid, -h - 0.15, 0.1, -h - 0.15, h + 0.15, 0.2, -h, edge_c, 0.8)
	mb.sbox(solid, h, 0.1, -h, h + 0.15, 0.2, h, edge_c, 0.8)
	mb.sbox(solid, -h - 0.15, 0.1, -h, -h, 0.2, h, edge_c, 0.8)
	# Brunnen in der Mitte
	fountain(mb, solid)
	# Laternen an den Wegen und Baenke
	for a in range(4):
		var ang := a * PI * 0.5 + (PI * 0.25 if variant == 1 else 0.0)
		var d := Vector3(cos(ang), 0, sin(ang))
		var side := Vector3(-d.z, 0, d.x)
		var pp := d * 11.5 + side * 2.3
		props.park_lamp(mb, solid, pp)
		var bp := d * 14.5 - side * 2.6
		props.bench(mb, solid, bp, side if rng.randf() < 0.5 else -side)
		props.bench(mb, solid, d * 14.5 + side * 2.6, -side)
	mb.instance(node, "ParkMesh")
	# Baeume: nicht auf Wegen und nicht im Brunnenplatz
	var tries := 0
	var count := 0
	while count < 22 and tries < 200:
		tries += 1
		var p := Vector2(rng.randf_range(-23.5, 23.5), rng.randf_range(-23.5, 23.5))
		if p.length() < 14.0:
			continue
		if variant == 0 and (absf(p.x) < 3.2 or absf(p.y) < 3.2):
			continue
		if variant == 1 and (absf(p.x - p.y) * 0.7071 < 3.2 or absf(p.x + p.y) * 0.7071 < 3.2):
			continue
		if variant == 2 and (absf(p.length() - 15.0) < 3.5 or absf(p.x) < 3.0 or absf(p.y) < 3.0):
			continue
		var kind := "round"
		var r := rng.randf()
		if r < 0.28:
			kind = "conifer"
		elif r < 0.5:
			kind = "oval"
		props.trees.add(kind, Vector3(cx + p.x, 0.17, cz + p.y), rng, rng.randf_range(0.95, 1.35))
		count += 1
	# Hecke entlang des Gehwegs
	for k in range(-24, 25, 2):
		for s in [-25.3, 25.3]:
			if rng.randf() < 0.8:
				props.trees.add("bush", Vector3(cx + k + rng.randf_range(-0.3, 0.3), 0.17, cz + s), rng, rng.randf_range(0.8, 1.2))
			if rng.randf() < 0.8:
				props.trees.add("bush", Vector3(cx + s, 0.17, cz + k + rng.randf_range(-0.3, 0.3)), rng, rng.randf_range(0.8, 1.2))
	# Straeucher an den Wegen
	for i in range(18):
		var p := Vector2(rng.randf_range(-22, 22), rng.randf_range(-22, 22))
		if p.length() < 13.5:
			continue
		props.trees.add("bush", Vector3(cx + p.x, 0.17, cz + p.y), rng, rng.randf_range(0.9, 1.6))
	# Gras-Buescheln auf dem Rasen (nicht auf den Wegen), Blumenbeet um den Brunnenplatz und Blumengruppen
	for i in range(1500):
		var p := Vector2(rng.randf_range(-24.5, 24.5), rng.randf_range(-24.5, 24.5))
		if p.length() < 9.6 or on_path(p, variant, 0.5):
			continue
		props.trees.add("tuft", Vector3(cx + p.x, 0.17, cz + p.y), rng, rng.randf_range(0.7, 1.3))
	for i in range(170):
		var a := rng.randf() * TAU
		var rr := rng.randf_range(9.8, 13.6)
		var p := Vector2(cos(a), sin(a)) * rr
		if on_path(p, variant, 0.2):
			continue
		props.trees.add("flowers", Vector3(cx + p.x, 0.17, cz + p.y), rng, rng.randf_range(0.8, 1.3))
	for g in range(9):
		var gc := Vector2(rng.randf_range(-21, 21), rng.randf_range(-21, 21))
		if gc.length() < 14.0 or on_path(gc, variant, 2.5):
			continue
		for i in range(14):
			var p := gc + Vector2(rng.randfn(), rng.randfn()) * 1.3
			if not on_path(p, variant, 0.5):
				props.trees.add("flowers", Vector3(cx + p.x, 0.17, cz + p.y), rng, rng.randf_range(0.8, 1.3))
	# Kollision: nur die flache Rasenflaeche (begehbar), Brunnenbecken
	var body := StaticBody3D.new()
	node.add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(52, 0.2, 52)
	cs.shape = bs
	cs.position = Vector3(0, 0.07, 0)
	body.add_child(cs)
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


func fountain(mb, solid) -> void:
	var stone := Color(0.62, 0.6, 0.56)
	mb.scyl(solid, Vector3(0, 0.17, 0), 4.5, 4.4, 0.75, stone, 28, 0.8)
	mb.scyl(solid, Vector3(0, 0.92, 0), 4.5, 4.5, 0.12, stone.lightened(0.1), 28, 0.7, 0.0, 0.0, false)
	mb.scyl(solid, Vector3(0, 0.80, 0), 3.9, 3.9, 0.04, Color(0.12, 0.3, 0.38), 28, 0.04, 0.1)
	mb.scyl(solid, Vector3(0, 0.84, 0), 0.5, 0.35, 2.0, stone, 12, 0.8)
	mb.scyl(solid, Vector3(0, 2.4, 0), 1.6, 0.4, 0.5, stone, 16, 0.8)
	mb.scyl(solid, Vector3(0, 2.85, 0), 0.25, 0.1, 1.2, Color(0.7, 0.85, 0.95), 8, 0.1, 0.0, 0.4)
