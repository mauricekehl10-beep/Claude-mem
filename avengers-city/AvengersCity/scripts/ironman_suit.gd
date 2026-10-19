extends RefCounted
# Iron-Man-Rüstung (Mark III / Avengers-Look): Panzerplatten als Netze an den Knochen.
# Alle Maße sind Ruhepose-Koordinaten der Mixamo-Figur (T-Pose, Meter, Füsse bei y=0, +Z vorn, +X links).
# Gebaut wird für die linke Seite (x > 0), die rechte entsteht durch Spiegeln (Builder.sx).
# Baukasten: ironman_kit.gd. Teile: ironman_head.gd (Helm), ironman_torso.gd (Brust, Rücken, Bauch, Hüfte),
# ironman_arms.gd (Schulter, Arme, Hände mit Fingern), ironman_legs.gd (Beine, Stiefel).
# Stoffe (id): 0 roter Lack, 1 Gold, 2 Silber, 3 dunkles Metall, 4 helles Metall, 5 Leuchten, 6 Wabengitter, 7 Gesichtsplatte, 8 Helmschale,
# 9 Gummi, 10 Gunmetal. Das Aussehen (Lack, Abnutzung, Kratzer) malt ironman_part.gdshader.

const K = preload("res://scripts/ironman_kit.gd")
const Head = preload("res://scripts/ironman_head.gd")
const Torso = preload("res://scripts/ironman_torso.gd")
const Arms = preload("res://scripts/ironman_arms.gd")
const Legs = preload("res://scripts/ironman_legs.gd")
const PART_SHADER = preload("res://scripts/ironman_part.gdshader")

static var _mat: ShaderMaterial
static var _meshes := {}  # Knochen -> fertiges Netz (gleiche Figur, einmal bauen)


# ---------------------------------------------------------------- Anbringen

static func _att(skel: Skeleton3D, bone: String) -> BoneAttachment3D:
	var n := "A_" + bone
	var ba := skel.get_node_or_null(n) as BoneAttachment3D
	if ba == null:
		ba = BoneAttachment3D.new()
		ba.name = n
		ba.bone_name = bone
		skel.add_child(ba)
	return ba


static func _put(skel: Skeleton3D, bone: String, mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material()
	mi.transform = skel.get_bone_global_rest(skel.find_bone(bone)).affine_inverse()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_att(skel, bone).add_child(mi)
	return mi


static func _material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = PART_SHADER
	return _mat


# ---------------------------------------------------------------- Zusammenbau

const FINGER_BONES := ["Index", "Middle", "Ring", "Pinky", "Thumb"]


static func build(skel: Skeleton3D) -> void:
	if _meshes.is_empty():
		_build_meshes()
	for bone in _meshes:
		if skel.find_bone(bone) >= 0:
			_put(skel, bone, _meshes[bone])


static func _build_meshes() -> void:
	var bs := {}  # Knochen -> Builder
	var names := ["Head", "Neck", "Spine2", "Spine1", "Spine", "Hips"]
	for side in ["Left", "Right"]:
		for part in ["Shoulder", "Arm", "ForeArm", "Hand", "UpLeg", "Leg", "Foot"]:
			names.append(side + part)
		for fg in FINGER_BONES:
			for k in range(1, 4):
				names.append("%sHand%s%d" % [side, fg, k])
	for bone in names:
		var b := K.Builder.new()
		b.seed = float(bs.size()) * 13.7 + 1.0
		bs["mixamorig_" + bone] = b
	Head.build(bs["mixamorig_Head"], bs["mixamorig_Neck"])
	Torso.chest(bs["mixamorig_Spine2"])
	Torso.back(bs["mixamorig_Spine2"])
	Torso.collar(bs["mixamorig_Spine2"])
	Torso.belly(bs["mixamorig_Spine1"])
	Torso.pelvis(bs["mixamorig_Hips"])
	for s in [1.0, -1.0]:
		var side := "Left" if s > 0.0 else "Right"
		for bone in bs:
			if String(bone).begins_with("mixamorig_" + side):
				(bs[bone] as K.Builder).sx = s
		(bs["mixamorig_Spine2"] as K.Builder).sx = s
		Torso.wings(bs["mixamorig_Spine2"])
		(bs["mixamorig_Spine2"] as K.Builder).sx = 1.0
		Arms.shoulder(bs["mixamorig_" + side + "Shoulder"])
		Arms.upper(bs["mixamorig_" + side + "Arm"])
		Arms.forearm(bs["mixamorig_" + side + "ForeArm"])
		Arms.hand(bs["mixamorig_" + side + "Hand"])
		for fg in FINGER_BONES:
			for k in range(3):
				Arms.finger(bs["mixamorig_%sHand%s%d" % [side, fg, k + 1]], fg, k)
		Legs.thigh(bs["mixamorig_" + side + "UpLeg"])
		Legs.shin(bs["mixamorig_" + side + "Leg"])
		Legs.boot(bs["mixamorig_" + side + "Foot"])
	for bone in bs:
		var b: K.Builder = bs[bone]
		if b.vs.size() > 0:
			_meshes[bone] = b.mesh()


# Kopf der Figur weglassen (der Helm ersetzt ihn): Dreiecke, die ganz über y_min liegen (Ruhepose)
static func cut_head(arrays: Array, y_min: float = 1.55) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var out := PackedInt32Array()
	for t in range(idx.size() / 3):
		var a := idx[t * 3]
		var b := idx[t * 3 + 1]
		var c := idx[t * 3 + 2]
		if minf(verts[a].y, minf(verts[b].y, verts[c].y)) > y_min:
			continue
		out.append(a)
		out.append(b)
		out.append(c)
	arrays[Mesh.ARRAY_INDEX] = out
	return arrays
