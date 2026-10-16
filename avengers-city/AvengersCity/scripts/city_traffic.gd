extends Node3D
# Fahrender Verkehr: einige Autos rollen geradeaus auf den Fahrspuren der Strassen (Rechtsverkehr) und tauchen am Stadtrand wieder auf.

const CityCars = preload("res://scripts/city_cars.gd")

const STEP := 72.0
const LANE := 1.9
const WRAP := 300.0

var cars := []  # Dictionary: node, axis (0 = x, 1 = z), line, dir, speed, s


func setup(count: int, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var picker = CityCars.new()
	picker.rng = rng
	var lanes := []
	for k in range(-3, 3):
		var line := 36.0 + STEP * k
		for d in [-1, 1]:
			lanes.append([0, line, d])
			if absf(line - 36.0) > 1.0:  # Startstrasse bleibt frei
				lanes.append([1, line, d])
	for i in range(count):
		var lane: Array = lanes[rng.randi() % lanes.size()]
		var md := picker.pick_model()
		var info := CityCars.merged(md[0])
		var body := AnimatableBody3D.new()
		body.sync_to_physics = true
		body.name = "Traffic%d" % i
		var mi := MeshInstance3D.new()
		mi.mesh = info[0]
		var mat := (info[2] as ShaderMaterial).duplicate() as ShaderMaterial
		mat.set_shader_parameter("use_instance", false)
		var pc := picker.pick_paint(md[2], md[3])
		mat.set_shader_parameter("tune", Vector4(pc.r, pc.g, pc.b, 0.0))
		mi.material_override = mat
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		var size: Vector3 = info[1]
		bs.size = Vector3(size.x, size.y * 0.9, size.z)
		cs.shape = bs
		cs.position = Vector3(0, size.y * 0.45, 0)
		body.add_child(cs)
		add_child(body)
		var c := {"node": body, "axis": lane[0], "line": lane[1], "dir": lane[2], "speed": rng.randf_range(6.0, 10.5), "s": rng.randf_range(-WRAP, WRAP)}
		cars.append(c)
		place(c)


func place(c: Dictionary) -> void:
	var node: AnimatableBody3D = c["node"]
	var d: int = c["dir"]
	var s: float = c["s"]
	var line: float = c["line"]
	if c["axis"] == 0:
		# Strasse entlang x: Rechtsverkehr, +x faehrt auf z = Mitte + LANE
		node.position = Vector3(s, 0.0, line + LANE * d)
		node.rotation.y = PI * 0.5 * d
	else:
		node.position = Vector3(line - LANE * d, 0.0, s)
		node.rotation.y = 0.0 if d > 0 else PI


func _physics_process(delta: float) -> void:
	for c in cars:
		var d: int = c["dir"]
		var s: float = c["s"] + d * c["speed"] * delta
		if s > WRAP:
			s -= 2.0 * WRAP
		elif s < -WRAP:
			s += 2.0 * WRAP
		c["s"] = s
		place(c)
