extends RefCounted
# Held aus der Mixamo-Figur "Y Bot": Anzug per Shader (hero_suit.gdshader), Zusatzteile in hero_parts.gd, Mixamo-Animationen.

const U = preload("res://scripts/util.gd")
const AnimCut = preload("res://scripts/anim_cut.gd")
const DIR := "res://Assets/Mixamo/"
const ANIMS := {
	"idle": "Breathing Idle", "walk": "Walking", "run": "Running", "jump": "Jump", "land": "Jump",
	"punch": "Cross Punch", "hammer": "Standing Melee Attack Horizontal",
	"hard": "Jumping Down",
}
const LOOPS := ["idle", "walk", "run"]

# Ausschnitte aus den Clips (Sekunden im Original): [von, bis, am Ende halten].
# jump: Hocke -> Absprung -> Luft -> Füße bereit zur Landung (danach bleibt die Pose stehen)
# land: Aufsetzen und Aufrichten. hard: harte Landung (Hocke). punch/hammer: nur Ausholen, Schlag, Zurück.
const CUTS := {
	"jump": [0.50, 1.32, 8.0], "land": [1.32, 1.80, 0.0], "hard": [1.60, 2.30, 0.0],
	"punch": [0.67, 1.60, 0.0], "hammer": [0.40, 1.60, 0.0],
}
# Wichtige Zeitpunkte, gemessen ab dem Start des jeweiligen Ausschnitts (Clip-Sekunden):
# jump: Absprung (letzter Fuß hebt ab), Luft-Ende (Füße setzen auf), Start der Fallpose
# punch/hammer: Treffer-Bild (Faust bzw. Hammer ist ganz vorn)
const JUMP_TAKEOFF := 0.28
const JUMP_TOUCH := 0.82
const JUMP_FALL := 0.60
const HITS := {"punch": 0.40, "hammer": 0.52}
# Natürliche Geschwindigkeit der Lauf-Clips (m/s), gemessen an den stehenden Füßen
const WALK_SPEED := 1.73
const RUN_SPEED := 5.55

const SKIN := Color(0.93, 0.72, 0.58)
const GOLD := Color(0.96, 0.74, 0.24)
const DARK := Color(0.12, 0.13, 0.16)
const SUIT = preload("res://scripts/hero_suit.gdshader")
const Parts = preload("res://scripts/hero_parts.gd")
const Face = preload("res://scripts/hero_face.gd")

static var _cache := {}  # fertig gebaute Netze pro Held


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
		_strip_hips_drift(an)
		if CUTS.has(key):
			an = AnimCut.cut(an, CUTS[key][0], CUTS[key][1], CUTS[key][2])
		an.loop_mode = Animation.LOOP_LINEAR if key in LOOPS else Animation.LOOP_NONE
		lib.add_animation(key, an)
	ap.add_animation_library("h", lib)

	for c in skel.get_children():
		var mi := c as MeshInstance3D
		if mi != null:
			_paint(mi, hero)

	var parts := {
		"anim": ap, "skel": skel,
		"lhand": _attach(skel, "mixamorig_LeftHand"),
		"rhand": _attach(skel, "mixamorig_RightHand"),
		"head": _attach(skel, "mixamorig_Head"),
		"spine": _attach(skel, "mixamorig_Spine2"),
	}
	_details(hero, h, parts)
	return parts


# Zusatzteile (Schilde, Haare, Umhang, Hammer ...) stehen in hero_parts.gd.
static func _details(hero: int, _h: Dictionary, p: Dictionary) -> void:
	var skel: Skeleton3D = p["skel"]
	if hero == 0:
		Parts.cap(skel)
	elif hero == 1:
		Parts.iron(skel)
	else:
		Parts.thor(skel)
		Parts.mjolnir(skel)
		Parts.cape(skel)


# Schild für Captain America am linken Arm (Kind der linken Hand). Gibt den Schild-Knoten zurück.
static func arm_shield(parts: Dictionary) -> Node3D:
	return Parts.arm_shield(parts)


# Schild als Kind von parent (für das fliegende Schild). Gleiches Aussehen wie am Arm.
static func flat_shield(parent: Node3D) -> Node3D:
	return Parts.shield(parent)


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


# Färben und Formen: Das Netz bekommt in CUSTOM0 seine Ruhepose-Position, der Shader malt danach
# (Sterne, Streifen, Platten, Leuchten). Dazu werden Brust, Arme, Stiefel usw. etwas dicker gemacht.
static func _paint(mi: MeshInstance3D, hero: int) -> void:
	var key := "%d%s" % [hero, mi.name]
	if not _cache.has(key):
		_cache[key] = _bake(mi.mesh, hero, "Surface" in mi.name)
	mi.mesh = _cache[key]
	var m := ShaderMaterial.new()
	m.shader = SUIT
	m.set_shader_parameter("hero", hero)
	m.set_shader_parameter("joint", "Joints" in mi.name)
	mi.material_override = m


static func _bake(src: Mesh, hero: int, face: bool = false) -> Mesh:
	var arrays := src.surface_get_arrays(0)
	if face:
		arrays = Face.refine(arrays)  # Gesichtszone fein unterteilen (hero_face.gd)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var n := verts.size()
	if n == 0:
		return src  # kein Netz (z. B. ohne Grafik): so lassen
	var per: int = (arrays[Mesh.ARRAY_BONES] as PackedInt32Array).size() / n
	# Punkte an gleicher Stelle (Kanten, Nähte) bekommen dieselbe Schieberichtung, sonst reisst das Netz auf
	var acc := {}
	for i in range(n):
		var k := Vector3i((verts[i] * 2000.0).round())
		acc[k] = acc.get(k, Vector3.ZERO) + norms[i]
	var cust := PackedFloat32Array()
	cust.resize(n * 4)
	for i in range(n):
		var p := verts[i]
		cust[i * 4] = p.x
		cust[i * 4 + 1] = p.y
		cust[i * 4 + 2] = p.z
		var dir: Vector3 = acc[Vector3i((p * 2000.0).round())]
		var fh := Face.height(hero, p) if face else 0.0
		cust[i * 4 + 3] = fh
		if fh != 0.0 or (face and p.y > 1.53 and p.z > -0.02):
			norms[i] = Face.normal(hero, p, norms[i])
		verts[i] = p + dir.normalized() * (_bulk(hero, p) + fh)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_CUSTOM0] = cust
	var flags: int = Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	if per > 4:
		flags |= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	var nm := ArrayMesh.new()
	nm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	return nm


# 1 zwischen a und b (mit weichem Rand r), sonst 0
static func _band(x: float, a: float, b: float, r: float) -> float:
	return smoothstep(a - r, a + r, x) * (1.0 - smoothstep(b - r, b + r, x))


# Wie viel Meter ein Punkt (Ruhepose) nach aussen geschoben wird.
static func _bulk(hero: int, p: Vector3) -> float:
	var ax := absf(p.x)
	var y := p.y
	var arm := smoothstep(0.17, 0.23, ax) * smoothstep(1.28, 1.34, y)
	var leg := 1.0 - smoothstep(0.96, 1.04, y)
	var trunk := (1.0 - arm) * (1.0 - leg)
	var sole := smoothstep(0.0, 0.05, y)  # Sohle bleibt auf dem Boden
	var d := 0.0
	if hero == 0:
		d += 0.012 * trunk * _band(y, 1.25, 1.46, 0.05)
		d -= 0.008 * trunk * _band(y, 1.1, 1.24, 0.04)
		d += 0.008 * arm * _band(ax, 0.2, 0.44, 0.05)
		d += 0.008 * arm * smoothstep(0.69, 0.71, ax)
		d += 0.014 * sole * (1.0 - smoothstep(0.24, 0.34, y))
		d += 0.006 * leg * _band(y, 0.55, 0.95, 0.1)
	elif hero == 1:
		d += 0.02 * trunk * _band(y, 1.22, 1.46, 0.05)
		d += 0.01 * trunk * _band(y, 1.1, 1.22, 0.03)
		d += 0.03 * arm * _band(ax, 0.17, 0.33, 0.04) * smoothstep(1.38, 1.44, y)
		d += 0.012 * arm * _band(ax, 0.33, 0.46, 0.04)
		d += 0.018 * arm * _band(ax, 0.5, 0.72, 0.02)
		d += 0.008 * arm * smoothstep(0.72, 0.74, ax)
		d += 0.012 * leg * _band(y, 0.6, 0.95, 0.08)
		d += 0.016 * leg * _band(y, 0.46, 0.6, 0.03)
		d += 0.022 * sole * leg * _band(y, 0.14, 0.45, 0.03)
		d += 0.018 * sole * (1.0 - smoothstep(0.1, 0.14, y))
		d += 0.012 * smoothstep(1.55, 1.58, y) * (1.0 - arm)
	else:
		d += 0.018 * trunk * _band(y, 1.2, 1.46, 0.05)
		d += 0.016 * arm * _band(ax, 0.2, 0.46, 0.05)
		d += 0.012 * arm * _band(ax, 0.5, 0.72, 0.02)
		d += 0.016 * sole * (1.0 - smoothstep(0.26, 0.36, y))
		d += 0.01 * leg * _band(y, 0.55, 0.95, 0.1)
	return d
