extends RefCounted
# Baut die Körper der drei Helden aus einfachen, runden Formen mit Details.

const U = preload("res://scripts/util.gd")


static func ell(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := U.sphere(parent, 0.5, pos, m)
	mi.scale = size
	return mi


static func capsule(parent: Node3D, r: float, h: float, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = h
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


# Füllt legs und arms (zum Animieren) und gibt {"torso", "head"} zurück.
static func build(hero: int, h: Dictionary, model: Node3D, legs: Array, arms: Array) -> Dictionary:
	var suit := U.mat(h["suit"], 0.5, 0.1)
	var accent := U.mat(h["accent"], 0.4, 0.3)
	var trim := U.mat(h["trim"], 0.25, 0.7)
	var skin := U.mat(Color(0.93, 0.72, 0.58), 0.7)
	var dark := U.mat(Color(0.14, 0.1, 0.08), 0.6)
	var gold := U.mat(Color(0.96, 0.74, 0.24), 0.22, 0.9)
	var glow_blue := U.glow(Color(0.6, 0.95, 1.0), 3.5)

	var hips := Node3D.new()
	hips.position = Vector3(0, 1.0, 0)
	model.add_child(hips)
	for s in [-1.0, 1.0]:
		var lp := Node3D.new()
		lp.position = Vector3(s * 0.2, 0.0, 0.0)
		hips.add_child(lp)
		capsule(lp, 0.15, 0.95, Vector3(0, -0.47, 0), suit)
		U.box(lp, Vector3(0.31, 0.34, 0.42), Vector3(0, -0.78, -0.04), accent)
		ell(lp, Vector3(0.31, 0.16, 0.2), Vector3(0, -0.92, -0.2), accent)
		if hero == 1:
			U.sphere(lp, 0.1, Vector3(0, -0.5, -0.1), gold)  # Knieschoner
		legs.append(lp)

	var torso := Node3D.new()
	torso.position = Vector3(0, 1.5, 0)
	model.add_child(torso)
	ell(torso, Vector3(0.84, 0.68, 0.5), Vector3(0, 0.3, 0), suit)
	ell(torso, Vector3(0.58, 0.55, 0.4), Vector3(0, -0.1, 0), suit)
	ell(torso, Vector3(0.58, 0.3, 0.42), Vector3(0, -0.38, 0), suit)
	U.box(torso, Vector3(0.6, 0.1, 0.43), Vector3(0, -0.3, 0), dark if hero != 1 else gold)
	U.sphere(torso, 0.05, Vector3(0, -0.3, -0.22), gold)  # Gürtelschnalle
	U.cyl(torso, 0.09, 0.2, Vector3(0, 0.74, 0), skin if hero != 1 else suit)  # Hals

	for s in [-1.0, 1.0]:
		var ap := Node3D.new()
		ap.position = Vector3(s * 0.54, 0.46, 0)
		torso.add_child(ap)
		U.sphere(ap, 0.17, Vector3.ZERO, gold if hero == 1 else (trim if hero == 2 else suit))
		capsule(ap, 0.1, 0.7, Vector3(0, -0.36, 0), suit)
		U.sphere(ap, 0.12, Vector3(0, -0.74, 0), gold if hero == 1 else accent)  # Handschuh
		if hero != 0:
			capsule(ap, 0.115, 0.3, Vector3(0, -0.56, 0), gold if hero == 1 else trim)  # Armschiene
		if hero == 1:
			U.sphere(ap, 0.045, Vector3(0, -0.8, -0.1), glow_blue)  # Repulsor
		arms.append(ap)

	var head := Node3D.new()
	head.position = Vector3(0, 0.98, 0)
	torso.add_child(head)

	if hero == 0:
		# Captain America: blaue Kappe, Gesicht, weisses A und Flügel, Stern, Streifen
		ell(head, Vector3(0.54, 0.58, 0.56), Vector3(0, 0.06, 0), suit)
		ell(head, Vector3(0.38, 0.38, 0.3), Vector3(0, -0.02, -0.14), skin)
		U.box(head, Vector3(0.1, 0.07, 0.02), Vector3(0, 0.22, -0.26), trim)
		for s in [-1.0, 1.0]:
			U.box(head, Vector3(0.03, 0.12, 0.16), Vector3(s * 0.27, 0.14, -0.02), trim, Vector3(0, 0, s * 20.0))
			U.box(head, Vector3(0.06, 0.025, 0.02), Vector3(s * 0.08, 0.04, -0.3), dark)
		U.cyl(torso, 0.16, 0.02, Vector3(0, 0.38, -0.24), trim, Vector3(90, 0, 0))
		for i in range(3):
			U.box(torso, Vector3(0.5 - i * 0.02, 0.04, 0.02), Vector3(0, 0.02 - i * 0.09, -0.2), accent if i % 2 == 0 else trim)
	elif hero == 1:
		# Iron Man: roter Helm, goldene Maske mit leuchtenden Augen, Arc-Reaktor
		ell(head, Vector3(0.54, 0.6, 0.56), Vector3(0, 0.06, 0), suit)
		U.box(head, Vector3(0.3, 0.36, 0.08), Vector3(0, 0.0, -0.25), gold)
		for s in [-1.0, 1.0]:
			U.box(head, Vector3(0.09, 0.03, 0.02), Vector3(s * 0.08, 0.06, -0.3), glow_blue)
		U.box(head, Vector3(0.1, 0.04, 0.02), Vector3(0, -0.12, -0.3), dark)
		ell(torso, Vector3(0.62, 0.44, 0.1), Vector3(0, 0.46, -0.2), gold)  # goldene Brustplatte
		U.sphere(torso, 0.1, Vector3(0, 0.38, -0.27), glow_blue)  # Arc-Reaktor
	else:
		# Thor: lange blonde Haare, Bart, Rüstung mit Scheiben, roter Umhang, Hammer
		var hair := U.mat(Color(0.88, 0.7, 0.32), 0.7)
		ell(head, Vector3(0.5, 0.52, 0.48), Vector3(0, 0.04, -0.02), skin)
		ell(head, Vector3(0.56, 0.4, 0.56), Vector3(0, 0.2, 0.04), hair)
		U.box(head, Vector3(0.46, 0.55, 0.14), Vector3(0, -0.02, 0.24), hair)
		U.box(head, Vector3(0.22, 0.12, 0.05), Vector3(0, -0.15, -0.23), hair)
		for s in [-1.0, 1.0]:
			U.box(head, Vector3(0.06, 0.025, 0.02), Vector3(s * 0.08, 0.05, -0.245), dark)
		ell(torso, Vector3(0.7, 0.5, 0.1), Vector3(0, 0.4, -0.2), trim)  # Brustpanzer
		for s in [-1.0, 1.0]:
			for i in range(2):
				U.cyl(torso, 0.06, 0.02, Vector3(s * 0.18, 0.5 - i * 0.18, -0.26), gold, Vector3(90, 0, 0))
		U.box(torso, Vector3(0.74, 1.25, 0.05), Vector3(0, 0.0, 0.27), U.mat(Color(0.7, 0.08, 0.08), 0.7))  # Umhang
		U.box(torso, Vector3(0.9, 0.12, 0.2), Vector3(0, 0.68, 0.1), U.mat(Color(0.7, 0.08, 0.08), 0.7))  # Umhang-Kragen
		# Mjolnir in der rechten Hand
		U.cyl(arms[1], 0.04, 0.75, Vector3(0, -0.8, -0.05), U.mat(Color(0.35, 0.22, 0.12), 0.8))
		U.box(arms[1], Vector3(0.44, 0.22, 0.22), Vector3(0, -1.2, -0.05), trim)

	return {"torso": torso, "head": head}
