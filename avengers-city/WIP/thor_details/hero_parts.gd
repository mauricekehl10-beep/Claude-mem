extends RefCounted
# Zusatzteile der Helden (Schild, Hammer, Haare, Schulterpanzer, Umhang ...).
# Alle Positionen sind Ruhepose-Koordinaten der Mixamo-Figur (T-Pose, Meter, Füsse bei y=0,
# +Z vorn, +X links). part() rechnet sie in den Knochen um, so wandern die Teile mit der Animation.

const U = preload("res://scripts/util.gd")
const SHIELD_SHADER = preload("res://scripts/shield.gdshader")
const HAIR_SHADER = preload("res://scripts/hair.gdshader")
const Cape = preload("res://scripts/cape.gd")
const Hair = preload("res://scripts/hero_hair.gd")
const IronFx = preload("res://scripts/iron_fx.gd")
const ThorSuit = preload("res://scripts/thor_suit.gd")
const ThorSurf = preload("res://scripts/thor_surf.gd")
const ThorPlates = preload("res://scripts/thor_plates.gd")
const IronSuit = preload("res://scripts/ironman_suit.gd")
const CapSuit = preload("res://scripts/captain_suit.gd")

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
	# Helm-Klappen, Kinnriemen, Kragen, Polster, Gürtel mit Taschen, Stulpen, Stiefel: captain_suit.gd
	CapSuit.build(skel)


# ---------------------------------------------------------------- Iron Man

static func iron(skel: Skeleton3D) -> void:
	# Rüstung: Helm, Brust mit Arc-Reaktor, Schultern, Arme, Beine, Stiefel (ironman_suit.gd)
	IronSuit.build(skel)
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
	var H := "mixamorig_Head"
	# Haar und Bart: einzelne Strähnen (hero_hair.gd), Material hair.gdshader
	var am := Hair.empty()
	Hair.hair(am, 520, 11, Color(0.80, 0.62, 0.36))
	Hair.beard(am, 520, 12, Color(0.58, 0.43, 0.24))
	Hair.braids(am, 13, Color(0.72, 0.55, 0.30))  # Zöpfchen an den Schläfen
	var hm := ShaderMaterial.new()
	hm.shader = HAIR_SHADER
	put(skel, H, Hair.mesh(am), hm, Transform3D.IDENTITY)
	# Rüstung: Scheiben, Platten, Armschienen, Stiefel, Gürtel, Schulterumhang (thor_suit.gd)
	ThorSuit.build(skel)
	# Brust-, Bauch- und Rückenplatten, die dem Körper folgen (thor_plates.gd)
	ThorPlates.build(skel)


# ---------------------------------------------------------------- Schild

# Schild als Kind von parent. Flache Seite unten, Wölbung (Gesicht) nach +Y, Sternspitze nach -Z.
static func shield(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var sm := ShaderMaterial.new()
	sm.shader = SHIELD_SHADER  # Ringe, Stern, Abnutzung: shield.gdshader
	var dome := MeshInstance3D.new()
	dome.mesh = m_half(SHIELD_R)
	dome.scale = Vector3(1.0, 0.2, 1.0)
	dome.material_override = sm
	root.add_child(dome)
	var steel := CapSuit.mat(4, Color(0.36, 0.37, 0.40), Color(0.60, 0.61, 0.63), 0.8)
	var edge := metal(Color(0.62, 0.63, 0.66), 0.36, 0.9)
	var leather := CapSuit.mat(0, Color(0.22, 0.13, 0.11), Color(0.40, 0.28, 0.23), 0.8)
	var back := MeshInstance3D.new()
	back.mesh = m_cyl(SHIELD_R, SHIELD_R, 0.012)
	back.position = Vector3(0, -0.006, 0)
	back.material_override = steel
	root.add_child(back)
	# Rand: Ring aus blankem, abgenutztem Metall
	var rim := MeshInstance3D.new()
	rim.mesh = m_torus(SHIELD_R - 0.012, SHIELD_R + 0.008)
	rim.scale = Vector3(1, 0.9, 1)
	rim.material_override = edge
	root.add_child(rim)
	# Rückseite: Nabe, breiter Armriemen (Ellbogenseite) und Griff (Handseite); Armachse = lokales z
	var boss := MeshInstance3D.new()
	boss.mesh = m_half(0.05)
	boss.scale = Vector3(1, 0.4, 1)
	boss.rotation.x = PI
	boss.position = Vector3(0, -0.012, 0)
	boss.material_override = steel
	boss.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(boss)
	for part in [[Vector3(0.15, 0.012, 0.052), Vector3(0, -0.022, -0.105)], [Vector3(0.15, 0.010, 0.026), Vector3(0, -0.020, -0.045)]]:
		var sp := MeshInstance3D.new()
		sp.mesh = m_box(part[0])
		sp.position = part[1]
		sp.material_override = leather
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(sp)
	for sx in [-1.0, 1.0]:
		var bk := MeshInstance3D.new()  # Schnalle am Armriemen
		bk.mesh = m_box(Vector3(0.012, 0.018, 0.04))
		bk.position = Vector3(sx * 0.072, -0.022, -0.105)
		bk.material_override = edge
		bk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(bk)
		var br := MeshInstance3D.new()  # Halter des Griffs
		br.mesh = m_box(Vector3(0.016, 0.034, 0.020))
		br.position = Vector3(sx * 0.052, -0.026, 0.075)
		br.material_override = steel
		br.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(br)
	var grip := MeshInstance3D.new()
	grip.mesh = m_cyl(0.013, 0.013, 0.12)
	grip.rotation.z = PI / 2
	grip.position = Vector3(0, -0.032, 0.075)
	grip.material_override = leather
	grip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(grip)
	return root


# Schild am linken Unterarm (als Kind der Hand), Gesicht nach aussen, Stern zur Schulter.
static func arm_shield(p: Dictionary) -> Node3D:
	var hand: Node3D = p["lhand"]
	var skel: Skeleton3D = p["skel"]
	var s := shield(hand)
	var w := Transform3D(Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)), Vector3(0.64, 1.51, -0.06))
	s.transform = skel.get_bone_global_rest(skel.find_bone("mixamorig_LeftHand")).affine_inverse() * w
	return s


# ---------------------------------------------------------------- Mjolnir

static func mjolnir(skel: Skeleton3D) -> void:
	ThorSuit.mjolnir(skel)  # Aussehen: thor_suit.gd (Metall mit Gravur, Griff mit Geflecht, Schlaufe)


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
