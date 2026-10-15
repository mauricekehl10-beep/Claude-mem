extends RefCounted
# Held aus der Mixamo-Figur "Y Bot": eingefärbt nach Körperteil, mit Mixamo-Animationen.

const U = preload("res://scripts/util.gd")
const DIR := "res://Assets/Mixamo/"
const ANIMS := {
	"idle": "Breathing Idle", "walk": "Walking", "run": "Running", "jump": "Jump",
	"punch": "Cross Punch", "hammer": "Standing Melee Attack Horizontal",
	"float": "Floating", "fly": "Flying",
}
const LOOPS := ["idle", "walk", "run", "float", "fly"]

const SKIN := Color(0.93, 0.72, 0.58)
const GOLD := Color(0.96, 0.74, 0.24)
const DARK := Color(0.12, 0.13, 0.16)


static func available() -> bool:
	if not ResourceLoader.exists(DIR + "Y Bot.fbx"):
		return false
	for f in ANIMS.values():
		if not ResourceLoader.exists(DIR + f + ".fbx"):
			return false
	return true


# Baut die Figur unter "model". Gibt {"anim", "skel", "lhand", "rhand", "head", "spine"} zurück.
static func build(hero: int, h: Dictionary, model: Node3D) -> Dictionary:
	var root := (load(DIR + "Y Bot.fbx") as PackedScene).instantiate() as Node3D
	root.rotation.y = PI  # Mixamo schaut nach +Z, das Spiel nach -Z
	model.add_child(root)
	var skel: Skeleton3D = root.get_node("Skeleton3D")
	var ap: AnimationPlayer = root.get_node("AnimationPlayer")

	var lib := AnimationLibrary.new()
	for key in ANIMS:
		var inst := (load(DIR + ANIMS[key] + ".fbx") as PackedScene).instantiate()
		var an: Animation = (inst.get_node("AnimationPlayer") as AnimationPlayer).get_animation("mixamo_com").duplicate()
		inst.free()
		an.loop_mode = Animation.LOOP_LINEAR if key in LOOPS else Animation.LOOP_NONE
		_strip_hips_drift(an)
		lib.add_animation(key, an)
	ap.add_animation_library("h", lib)

	var palette := {}
	for g in ["head", "hand", "forearm", "uparm", "thigh", "foot", "shin", "hips", "torso"]:
		palette[g] = _color(hero, g, h).srgb_to_linear()
	for c in skel.get_children():
		var mi := c as MeshInstance3D
		if mi == null:
			continue
		if "Joints" in mi.name:
			mi.material_override = U.mat(_joint_color(hero), 0.6, 0.3)
		else:
			_colorize(mi, skel, hero, palette)

	var parts := {
		"anim": ap, "skel": skel,
		"lhand": _attach(skel, "mixamorig_LeftHand"),
		"rhand": _attach(skel, "mixamorig_RightHand"),
		"head": _attach(skel, "mixamorig_Head"),
		"spine": _attach(skel, "mixamorig_Spine2"),
	}
	_details(hero, h, parts)
	return parts


# Gesicht, Helm, Haare, Umhang, Hammer. Kopf- und Brustknochen: +Z vorn, +Y oben, +X links.
# Handknochen: +Y zeigt die Hand entlang nach unten.
static func _details(hero: int, h: Dictionary, p: Dictionary) -> void:
	var head: Node3D = p["head"]
	var spine: Node3D = p["spine"]
	var skin := U.mat(SKIN, 0.7)
	var white := U.mat(Color(0.95, 0.95, 0.95), 0.4)
	var dark := U.mat(Color(0.08, 0.06, 0.05), 0.6)
	var gold := U.mat(GOLD, 0.2, 0.9)
	var glow := U.glow(Color(0.6, 0.95, 1.0), 4.0)
	if hero == 0:
		_ell(head, Vector3(0.18, 0.17, 0.1), Vector3(0, 0.1, 0.07), skin)
		U.box(head, Vector3(0.045, 0.03, 0.01), Vector3(0, 0.215, 0.085), white)
		for s in [-1.0, 1.0]:
			U.box(head, Vector3(0.02, 0.07, 0.07), Vector3(s * 0.105, 0.15, -0.02), white, Vector3(0, 0, s * 20.0))
			U.box(head, Vector3(0.03, 0.01, 0.01), Vector3(s * 0.035, 0.125, 0.115), dark)
		U.cyl(spine, 0.05, 0.01, Vector3(0, 0.0, 0.13), white, Vector3(90, 0, 0))  # Stern
	elif hero == 1:
		U.box(head, Vector3(0.14, 0.17, 0.04), Vector3(0, 0.1, 0.09), gold)
		for s in [-1.0, 1.0]:
			U.box(head, Vector3(0.045, 0.014, 0.01), Vector3(s * 0.035, 0.13, 0.112), glow)
		_ell(spine, Vector3(0.3, 0.18, 0.08), Vector3(0, 0.02, 0.12), gold)
		U.sphere(spine, 0.035, Vector3(0, 0.0, 0.16), glow)  # Arc-Reaktor
	else:
		var hair := U.mat(Color(0.88, 0.7, 0.32), 0.7)
		_ell(head, Vector3(0.22, 0.17, 0.23), Vector3(0, 0.19, -0.015), hair)
		U.box(head, Vector3(0.18, 0.26, 0.06), Vector3(0, 0.06, -0.11), hair)
		U.box(head, Vector3(0.07, 0.04, 0.02), Vector3(0, 0.03, 0.09), hair)  # Bart
		for s in [-1.0, 1.0]:
			U.box(head, Vector3(0.03, 0.01, 0.01), Vector3(s * 0.035, 0.125, 0.092), dark)
		_ell(spine, Vector3(0.3, 0.2, 0.08), Vector3(0, 0.0, 0.12), U.mat(h["trim"], 0.25, 0.7))  # Brustpanzer
		for s in [-1.0, 1.0]:
			U.cyl(spine, 0.022, 0.01, Vector3(s * 0.06, 0.02, 0.16), gold, Vector3(90, 0, 0))
		U.box(spine, Vector3(0.36, 0.8, 0.02), Vector3(0, -0.28, -0.14), U.mat(Color(0.7, 0.08, 0.08), 0.7))  # Umhang
		var rh: Node3D = p["rhand"]
		U.cyl(rh, 0.018, 0.42, Vector3(0, 0.12, 0), U.mat(Color(0.35, 0.22, 0.12), 0.8))
		U.box(rh, Vector3(0.24, 0.11, 0.11), Vector3(0, 0.36, 0), U.mat(h["trim"], 0.25, 0.7))  # Mjolnir


static func _ell(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> void:
	var mi := U.sphere(parent, 0.5, pos, m)
	mi.scale = size


static func _attach(skel: Skeleton3D, bone: String) -> BoneAttachment3D:
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skel.add_child(ba)
	return ba


# Die Hüfte soll in der Animation nicht nach vorn wandern (das macht das Spiel selbst).
static func _strip_hips_drift(an: Animation) -> void:
	for t in range(an.get_track_count()):
		if an.track_get_type(t) == Animation.TYPE_POSITION_3D and String(an.track_get_path(t)).ends_with("Hips"):
			var first: Vector3 = an.track_get_key_value(t, 0)
			for k in range(an.track_get_key_count(t)):
				var v: Vector3 = an.track_get_key_value(t, k)
				an.track_set_key_value(t, k, Vector3(first.x, v.y, first.z))


static func _group(b: String) -> String:
	if "Head" in b or "Neck" in b:
		return "head"
	if "Hand" in b:
		return "hand"
	if "ForeArm" in b:
		return "forearm"
	if "Arm" in b:
		return "uparm"
	if "UpLeg" in b:
		return "thigh"
	if "Foot" in b or "Toe" in b:
		return "foot"
	if "Leg" in b:
		return "shin"
	if "Hips" in b:
		return "hips"
	return "torso"


static func _joint_color(hero: int) -> Color:
	return [Color(0.05, 0.08, 0.25), Color(0.45, 0.35, 0.12), Color(0.2, 0.2, 0.24)][hero]


static func _color(hero: int, g: String, h: Dictionary) -> Color:
	var suit: Color = h["suit"]
	var accent: Color = h["accent"]
	var trim: Color = h["trim"]
	if hero == 0:  # Captain America: blauer Anzug, rote Handschuhe und Stiefel
		if g == "hand" or g == "foot":
			return accent
		return suit
	if hero == 1:  # Iron Man: rot mit Gold an Unterarmen, Unterschenkeln, Händen, Füssen
		if g in ["hand", "forearm", "shin", "foot"]:
			return GOLD
		return suit
	# Thor: dunkler Anzug, nackte Oberarme und Kopf, Armschienen aus Silber, braune Stiefel
	match g:
		"head", "uparm":
			return SKIN
		"forearm":
			return trim
		"hand", "foot":
			return accent
	return DARK


# Färbt jeden Punkt der Figur nach dem Knochen, der ihn am stärksten bewegt.
static func _colorize(mi: MeshInstance3D, skel: Skeleton3D, hero: int, palette: Dictionary) -> void:
	var arrays := mi.mesh.surface_get_arrays(0)
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var n: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var per: int = bones.size() / n
	var names := {}
	var cols := PackedColorArray()
	cols.resize(n)
	for v in range(n):
		var best := 0
		var bw := -1.0
		for k in range(per):
			if weights[v * per + k] > bw:
				bw = weights[v * per + k]
				best = bones[v * per + k]
		if not names.has(best):
			names[best] = _group(_bone_name(mi, skel, best))
		cols[v] = palette[names[best]]
	arrays[Mesh.ARRAY_COLOR] = cols
	var nm := ArrayMesh.new()
	var flags := 0
	if per > 4:
		flags = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	nm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	mi.mesh = nm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.45
	m.metallic = 0.25 if hero != 2 else 0.1
	mi.material_override = m


static func _bone_name(mi: MeshInstance3D, skel: Skeleton3D, idx: int) -> String:
	var skin := mi.skin
	if skin and idx < skin.get_bind_count():
		var bn := String(skin.get_bind_name(idx))
		if bn != "":
			return bn
		return skel.get_bone_name(skin.get_bind_bone(idx))
	return skel.get_bone_name(idx)
