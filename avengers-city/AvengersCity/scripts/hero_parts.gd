extends RefCounted
# Zusatzteile der Helden (Schild, Hammer, Haare, Schulterpanzer, Umhang ...).
# Alle Positionen sind Ruhepose-Koordinaten der Mixamo-Figur (T-Pose, Meter, Füsse bei y=0,
# +Z vorn, +X links). part() rechnet sie in den Knochen um, so wandern die Teile mit der Animation.

const U = preload("res://scripts/util.gd")
const SHIELD_SHADER = preload("res://scripts/shield.gdshader")
const HAIR_SHADER = preload("res://scripts/hair.gdshader")
const Cape = preload("res://scripts/cape.gd")
const IronFx = preload("res://scripts/iron_fx.gd")

const GOLD := Color(0.88, 0.58, 0.14)
const RED := Color(0.66, 0.035, 0.05)
const SKIN := Color(0.88, 0.66, 0.52)
const SHIELD_R := 0.31


# ---------------------------------------------------------------- Bausteine

static func att(skel: Skeleton3D, bone: String) -> BoneAttachment3D:
	var n := "A_" + bone
	var ba := skel.get_node_or_null(n) as BoneAttachment3D
	if ba == null:
		ba = BoneAttachment3D.new()
		ba.name = n
		ba.bone_name = bone
		skel.add_child(ba)
	return ba


# Hängt ein Mesh an einen Knochen. xf = Lage in Ruhepose-Koordinaten.
static func put(skel: Skeleton3D, bone: String, mesh: Mesh, mat: Material, xf: Transform3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = skel.get_bone_global_rest(skel.find_bone(bone)).affine_inverse() * xf
	att(skel, bone).add_child(mi)
	return mi


static func xf(pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot_deg * PI / 180.0) * Basis.from_scale(scl), pos)


static func m_sphere(r: float = 1.0) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 24
	m.rings = 12
	return m


static func m_half(r: float = 1.0) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r
	m.is_hemisphere = true
	m.radial_segments = 24
	m.rings = 8
	return m


static func m_box(s: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = s
	return m


static func m_cyl(rt: float, rb: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = rt
	m.bottom_radius = rb
	m.height = h
	m.radial_segments = 24
	return m


static func m_torus(inner: float, outer: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 24
	m.ring_segments = 12
	return m


static func metal(c: Color, rough: float = 0.28, met: float = 0.9) -> StandardMaterial3D:
	return U.mat(c, rough, met)


# Basis aus zwei Richtungen: y = Achse, z = grobe zweite Achse
static func frame(y: Vector3, z: Vector3) -> Basis:
	var by := y.normalized()
	var bx := by.cross(z).normalized()
	var bz := bx.cross(by).normalized()
	return Basis(bx, by, bz)


# ---------------------------------------------------------------- Captain America

static func cap(skel: Skeleton3D) -> void:
	var white := U.mat(Color(0.95, 0.95, 0.96), 0.35, 0.2)
	var skin := U.mat(SKIN, 0.65)
	var brown := U.mat(Color(0.30, 0.16, 0.08), 0.65)
	var silver := metal(Color(0.72, 0.72, 0.68), 0.3, 0.9)
	var H := "mixamorig_Head"
	# Nase
	put(skel, H, m_sphere(), skin, xf(Vector3(0, 1.645, 0.128), Vector3.ZERO, Vector3(0.010, 0.014, 0.013)))
	# weisse Flügel seitlich an der Haube
	for s in [-1.0, 1.0]:
		for i in range(4):
			var fl := 0.07 - i * 0.012
			put(skel, H, m_box(Vector3(0.005, fl, 0.03)), white,
				xf(Vector3(s * 0.087, 1.715 + i * 0.01, 0.02 - i * 0.03), Vector3(-30.0 - i * 14.0, 0, -s * 8.0)))
	# Gürteltaschen (vorn links/rechts, hinten Mitte)
	var Hp := "mixamorig_Hips"
	for s in [-1.0, 1.0]:
		put(skel, Hp, m_box(Vector3(0.05, 0.06, 0.035)), brown, xf(Vector3(s * 0.1, 1.035, 0.152), Vector3(0, s * -14.0, 0)))
		put(skel, Hp, m_cyl(0.007, 0.007, 0.006), silver, xf(Vector3(s * 0.1, 1.045, 0.172), Vector3(90, 0, 0)))
	put(skel, Hp, m_box(Vector3(0.09, 0.06, 0.035)), brown, xf(Vector3(0, 1.03, -0.185)))


# ---------------------------------------------------------------- Iron Man

static func iron(skel: Skeleton3D) -> void:
	var red := metal(RED, 0.26, 0.85)
	var gold := metal(GOLD, 0.22, 0.95)
	var cyan := U.glow(Color(0.65, 0.95, 1.0), 2.2)
	var H := "mixamorig_Head"
	# Schulterpanzer
	for s in [-1.0, 1.0]:
		var b := "mixamorig_LeftArm" if s > 0.0 else "mixamorig_RightArm"
		put(skel, b, m_half(0.1), red, xf(Vector3(s * 0.235, 1.455, -0.045), Vector3(0, 0, -s * 25.0), Vector3(1.0, 0.8, 1.2)))
		put(skel, b, m_cyl(0.104, 0.104, 0.012), gold, xf(Vector3(s * 0.235, 1.455, -0.045), Vector3(0, 0, -s * 25.0), Vector3(1.0, 1.0, 1.2)))
	# Helm: Ohrscheiben
	for s in [-1.0, 1.0]:
		put(skel, H, m_cyl(0.026, 0.026, 0.012), gold, xf(Vector3(s * 0.088, 1.67, 0.0), Vector3(0, 0, 90)))
	# Arc-Reaktor
	var S := "mixamorig_Spine2"
	put(skel, S, m_torus(0.03, 0.05), gold, xf(Vector3(0, 1.322, 0.176), Vector3(90, 0, 0)))
	put(skel, S, m_cyl(0.034, 0.034, 0.008), cyan, xf(Vector3(0, 1.322, 0.178), Vector3(90, 0, 0)))
	# Düsen: Flammen an Sohlen und Handflächen (nur beim Fliegen sichtbar)
	var fx := IronFx.new()
	skel.add_child(fx)
	for s in [-1.0, 1.0]:
		var side := "Left" if s > 0.0 else "Right"
		fx.flames.append(flame(skel, "mixamorig_%sFoot" % side, Vector3(s * 0.092, 0.005, 0.045), 0.08, 0.5))
		fx.flames.append(flame(skel, "mixamorig_%sHand" % side, Vector3(s * 0.815, 1.385, -0.06), 0.06, 0.3))


# ---------------------------------------------------------------- Thor

static func hair_mat(c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = HAIR_SHADER
	m.set_shader_parameter("base", c)
	return m


static func thor(skel: Skeleton3D) -> void:
	var gold := hair_mat(Color(0.82, 0.62, 0.24))
	var light := hair_mat(Color(0.9, 0.73, 0.36))
	var dark := hair_mat(Color(0.68, 0.5, 0.19))
	var H := "mixamorig_Head"
	# Haarkappe, Mähne am Hinterkopf, Strähnen an den Schläfen
	put(skel, H, m_sphere(), gold, xf(Vector3(0, 1.705, -0.02), Vector3(-4, 0, 0), Vector3(0.092, 0.116, 0.126)))
	put(skel, H, m_sphere(), gold, xf(Vector3(0, 1.60, -0.118), Vector3(-6, 0, 0), Vector3(0.092, 0.17, 0.058)))
	put(skel, H, m_sphere(), dark, xf(Vector3(0, 1.50, -0.138), Vector3(-10, 0, 0), Vector3(0.078, 0.13, 0.045)))
	for s in [-1.0, 1.0]:
		put(skel, H, m_sphere(), light, xf(Vector3(s * 0.088, 1.64, -0.02), Vector3(0, 0, s * 4.0), Vector3(0.024, 0.1, 0.07)))
		put(skel, H, m_sphere(), dark, xf(Vector3(s * 0.075, 1.57, -0.062), Vector3(-8, 0, s * 8.0), Vector3(0.026, 0.075, 0.05)))
	# Bart
	put(skel, H, m_sphere(), hair_mat(Color(0.66, 0.48, 0.18)), xf(Vector3(0, 1.584, 0.094), Vector3(10, 0, 0), Vector3(0.04, 0.026, 0.03)))
	# Umhang-Schliesse an den Schultern
	var S := "mixamorig_Spine2"
	var silver := metal(Color(0.74, 0.76, 0.80), 0.3, 0.9)
	for s in [-1.0, 1.0]:
		put(skel, S, m_cyl(0.026, 0.026, 0.012), silver, xf(Vector3(s * 0.15, 1.455, 0.04), Vector3(90, 0, 0)))


# ---------------------------------------------------------------- Schild

# Schild als Kind von parent. Flache Seite unten, Wölbung (Gesicht) nach +Y, Sternspitze nach -Z.
static func shield(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var sm := ShaderMaterial.new()
	sm.shader = SHIELD_SHADER
	var dome := MeshInstance3D.new()
	dome.mesh = m_half(SHIELD_R)
	dome.scale = Vector3(1.0, 0.2, 1.0)
	dome.position = Vector3(0, 0.0, 0)
	dome.material_override = sm
	root.add_child(dome)
	var steel := metal(Color(0.26, 0.27, 0.30), 0.55, 0.3)
	var back := MeshInstance3D.new()
	back.mesh = m_cyl(SHIELD_R, SHIELD_R, 0.012)
	back.position = Vector3(0, -0.006, 0)
	back.material_override = steel
	root.add_child(back)
	# Rückseite: Lederriemen quer über die Mitte und ein Griff
	var leather := U.mat(Color(0.25, 0.14, 0.07), 0.7)
	for part in [[Vector3(0.07, 0.01, 0.38), Vector3(0, -0.017, 0)], [Vector3(0.05, 0.03, 0.1), Vector3(0, -0.03, 0.07)]]:
		var sp := MeshInstance3D.new()
		sp.mesh = m_box(part[0])
		sp.position = part[1]
		sp.material_override = leather
		root.add_child(sp)
	var rim := MeshInstance3D.new()
	rim.mesh = m_torus(SHIELD_R - 0.012, SHIELD_R + 0.008)
	rim.scale = Vector3(1, 0.9, 1)
	rim.material_override = metal(Color(0.80, 0.82, 0.86), 0.25, 0.95)
	root.add_child(rim)
	return root


# Schild am linken Unterarm (als Kind der Hand), Gesicht nach aussen, Stern zur Schulter.
static func arm_shield(p: Dictionary) -> Node3D:
	var hand: Node3D = p["lhand"]
	var skel: Skeleton3D = p["skel"]
	var s := shield(hand)
	var w := Transform3D(Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)), Vector3(0.64, 1.52, -0.06))
	s.transform = skel.get_bone_global_rest(skel.find_bone("mixamorig_LeftHand")).affine_inverse() * w
	return s


# ---------------------------------------------------------------- Mjolnir

static func mjolnir(skel: Skeleton3D) -> void:
	var gun := metal(Color(0.22, 0.23, 0.27), 0.38, 0.8)
	var silver := metal(Color(0.66, 0.68, 0.72), 0.3, 0.9)
	var leather := U.mat(Color(0.20, 0.11, 0.06), 0.7)
	var d := Vector3(-0.87, 0.0, 0.5)
	var b := frame(d, Vector3(0.5, 0.0, 0.87))
	var o := Vector3(-0.82, 1.425, -0.065)
	var B := "mixamorig_RightHand"
	# Griff
	put(skel, B, m_cyl(0.017, 0.017, 0.38), leather, Transform3D(b, o + b.y * 0.06))
	put(skel, B, m_cyl(0.021, 0.021, 0.012), silver, Transform3D(b, o + b.y * -0.125))
	# Schlaufe am Griffende
	put(skel, B, m_torus(0.034, 0.042), leather, Transform3D(b * Basis.from_euler(Vector3(0, 0, PI / 2)), o + b.y * -0.165))
	# Kopf: Block mit silbernen Endkappen
	var hc := o + b.y * 0.285
	put(skel, B, m_box(Vector3(0.11, 0.1, 0.2)), gun, Transform3D(b, hc))
	for s in [-1.0, 1.0]:
		put(skel, B, m_box(Vector3(0.118, 0.108, 0.04)), silver, Transform3D(b, hc + b.z * s * 0.11))
	put(skel, B, m_box(Vector3(0.116, 0.106, 0.016)), silver, Transform3D(b, hc))
	put(skel, B, m_box(Vector3(0.112, 0.02, 0.2)), silver, Transform3D(b, hc - b.y * 0.056))


# ---------------------------------------------------------------- Umhang

static func cape(skel: Skeleton3D) -> void:
	var c := Cape.new()
	c.skel = skel
	var S := "mixamorig_Spine2"
	var a := att(skel, S)
	c.transform = skel.get_bone_global_rest(skel.find_bone(S)).affine_inverse()
	a.add_child(c)


# Flamme: Kegel mit Spitze nach -Y, Wurzel am Drehpunkt (Ruhepose-Position pos der Sohle/Handfläche)
static func flame(skel: Skeleton3D, bone: String, pos: Vector3, r: float, h: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.transform = skel.get_bone_global_rest(skel.find_bone(bone)).affine_inverse() * Transform3D(Basis.IDENTITY, pos)
	att(skel, bone).add_child(pivot)
	for layer in [[1.0, Color(0.2, 0.6, 1.0, 0.35), 1.0], [0.6, Color(0.6, 0.9, 1.0, 0.6), 0.7], [0.3, Color(1.0, 1.0, 1.0, 0.9), 0.4]]:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = layer[1]
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = r * layer[0]
		cm.bottom_radius = 0.0
		cm.height = h * layer[2]
		cm.radial_segments = 12
		mi.mesh = cm
		mi.material_override = m
		mi.position = Vector3(0, -h * layer[2] * 0.5, 0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(mi)
	return pivot
