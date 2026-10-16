extends RefCounted
# Baut den Hydra-Soldaten aus der Mixamo-Figur "Y Bot".
# Das Teure (Mesh mit Farben und Ausrüstung, Animationen, Material) wird nur EINMAL angelegt,
# alle Soldaten teilen es. Pro Soldat gibt es nur ein Skelett, einen AnimationPlayer und ein MeshInstance3D.

const DIR := "res://Assets/Mixamo/"
# Animationen: Name -> [Datei, Anfang, Ende (-1 = ganz), Schleife]
const CLIPS := {
	"idle": ["Breathing Idle", 0.0, -1.0, true],
	"walk": ["Walking", 0.0, -1.0, true],
	"run": ["Running", 0.0, -1.0, true],
	"punch": ["Cross Punch", 0.3, 1.65, false],
	"melee": ["Standing Melee Attack Horizontal", 0.0, 1.9, false],
}
# Sekunden in der (zugeschnittenen) Animation, in denen der Schlag den Gegner trifft
const HIT_TIME := {"punch": 0.8, "melee": 0.85}
const WALK_REF := 1.5  # so schnell (m/s) läuft die Geh-Animation bei Tempo 1
const RUN_REF := 5.3

# Farben (sRGB). Die Alpha-Zahl im Vertex steht für das Material:
# 1.0 Stoff, 0.75 Leder/Gummi, 0.5 Metall, 0.0 leuchtend
const TUNIC := Color(0.125, 0.15, 0.13)
const TUNIC_DARK := Color(0.09, 0.11, 0.095)
const PANTS := Color(0.06, 0.07, 0.065)
const BLACK := Color(0.035, 0.035, 0.04)
const GUNMETAL := Color(0.15, 0.16, 0.175)
const HELMET := Color(0.12, 0.145, 0.13)
const LEATHER := Color(0.13, 0.095, 0.065)
const STRAP := Color(0.055, 0.05, 0.045)
const RED := Color(0.8, 0.05, 0.04)
const BRASS := Color(0.55, 0.42, 0.18)
const OLIVE := Color(0.13, 0.145, 0.095)

const SHADER := """
shader_type spatial;
uniform sampler2D emblem : source_color, filter_linear_mipmap, repeat_disable;
instance uniform vec3 tint = vec3(1.0);
instance uniform float flash = 0.0;

void fragment() {
	float id = COLOR.a;
	vec3 col = pow(COLOR.rgb, vec3(2.2)) * tint;
	float rough = 0.9;
	float metal = 0.0;
	if (id < 0.9 && id >= 0.6) {
		rough = 0.5;
	} else if (id < 0.6 && id >= 0.3) {
		rough = 0.5;
		metal = 0.6;
	}
	vec3 emit = vec3(0.0);
	if (UV.x >= 0.0) {
		vec4 e = texture(emblem, UV);
		col = mix(col, e.rgb, e.a);
		emit = e.rgb * e.a * 0.45;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	RIM = 0.15;
	RIM_TINT = 0.4;
	emit += vec3(1.0, 0.55, 0.4) * flash * 0.2;
	if (id < 0.1) {
		ALBEDO = vec3(0.0);
		emit = pow(COLOR.rgb, vec3(2.2)) * 0.9;
	}
	EMISSION = emit;
}
"""

static var loaded := false
static var scene: PackedScene
static var lib: AnimationLibrary
static var meshes := {}
static var material: ShaderMaterial
static var bone_ids := {}


# Alles einmal vorbereiten (wird von spawn() automatisch aufgerufen)
static func prepare() -> void:
	if loaded:
		return
	loaded = true
	scene = load(DIR + "Y Bot.fbx") as PackedScene

	# Animationen aus den FBX-Dateien in eine gemeinsame Bibliothek
	lib = AnimationLibrary.new()
	for key in CLIPS:
		var c: Array = CLIPS[key]
		var inst := (load(DIR + c[0] + ".fbx") as PackedScene).instantiate()
		var src: Animation = (inst.get_node("AnimationPlayer") as AnimationPlayer).get_animation("mixamo_com")
		var t1: float = c[2] if c[2] > 0.0 else src.length
		var an: Animation = _trim(src, c[1], t1) if (c[1] > 0.0 or t1 < src.length - 0.01) else src.duplicate()
		inst.free()
		an.loop_mode = Animation.LOOP_LINEAR if c[3] else Animation.LOOP_NONE
		lib.add_animation(key, an)

	# Mesh: Körper + Gelenke + Ausrüstung in einer Fläche, eingefärbt nach Knochen
	var root := scene.instantiate() as Node3D
	var skel: Skeleton3D = root.get_node("Skeleton3D")
	for i in range(skel.get_bone_count()):
		bone_ids[skel.get_bone_name(i)] = i
	var body := skel.get_node("Alpha_Surface") as MeshInstance3D
	var joints := skel.get_node("Alpha_Joints") as MeshInstance3D
	var skin: Skin = body.skin
	var bind := {}
	var names: Array = []
	for i in range(skin.get_bind_count()):
		bind[String(skin.get_bind_name(i))] = i
		names.append(String(skin.get_bind_name(i)))
	var base := _base(body, joints, names)
	var common := Gear.new()
	common.bind = bind
	_gear_common(common)
	var officer := Gear.new()
	officer.bind = bind
	_gear_officer(officer)
	meshes["grunt"] = _assemble(base, [common])
	meshes["officer"] = _assemble(base, [common, officer])
	root.free()

	material = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	material.shader = sh
	material.set_shader_parameter("emblem", _emblem_texture())


# Erzeugt einen Soldaten unter "parent". Die Figur ist um PI gedreht (Mixamo schaut nach +Z, das Spiel nach -Z).
# Gibt {"root", "skel", "ap", "mesh"} zurück.
static func spawn(parent: Node3D, officer: bool) -> Dictionary:
	prepare()
	var root := scene.instantiate() as Node3D
	root.rotation.y = PI
	var skel := root.get_node("Skeleton3D") as Skeleton3D
	skel.get_node("Alpha_Joints").free()  # steckt schon im Körper-Mesh
	var mi := skel.get_node("Alpha_Surface") as MeshInstance3D
	mi.mesh = meshes["officer" if officer else "grunt"]
	mi.material_override = material
	mi.custom_aabb = AABB(Vector3(-1.1, -0.3, -1.1), Vector3(2.2, 2.8, 2.2))
	mi.visibility_range_end = 140.0
	var ap := root.get_node("AnimationPlayer") as AnimationPlayer
	ap.add_animation_library("h", lib)
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	parent.add_child(root)
	return {"root": root, "skel": skel, "ap": ap, "mesh": mi}


# --- Animationen ---------------------------------------------------------

# Schneidet ein Stück aus einer Animation (Anfang bis Ende), ab da zählt die Zeit wieder ab 0
static func _trim(src: Animation, t0: float, t1: float) -> Animation:
	var an := Animation.new()
	an.length = t1 - t0
	for t in range(src.get_track_count()):
		var type := src.track_get_type(t)
		if type != Animation.TYPE_POSITION_3D and type != Animation.TYPE_ROTATION_3D and type != Animation.TYPE_SCALE_3D:
			continue
		var tt := an.add_track(type)
		an.track_set_path(tt, src.track_get_path(t))
		an.track_set_interpolation_type(tt, src.track_get_interpolation_type(t))
		var times: Array = [0.0]
		for k in range(src.track_get_key_count(t)):
			var kt := src.track_get_key_time(t, k)
			if kt > t0 + 0.005 and kt < t1 - 0.005:
				times.append(kt - t0)
		times.append(t1 - t0)
		for ft in times:
			var at: float = ft + t0
			var val: Variant
			if type == Animation.TYPE_POSITION_3D:
				val = src.position_track_interpolate(t, at)
			elif type == Animation.TYPE_ROTATION_3D:
				val = src.rotation_track_interpolate(t, at)
			else:
				val = src.scale_track_interpolate(t, at)
			an.track_insert_key(tt, ft, val)
	return an


# --- Mesh ----------------------------------------------------------------

# Farbe nach Knochen (Stoff, Hose, Handschuhe, Stiefel ...)
static func _bone_color(b: String) -> Color:
	if "Head" in b or "Neck" in b:
		return BLACK
	if "Hand" in b:
		return BLACK
	if "ForeArm" in b:
		return TUNIC_DARK
	if "Arm" in b or "Shoulder" in b:
		return TUNIC
	if "UpLeg" in b or "Leg" in b:
		return PANTS
	if "Foot" in b or "Toe" in b:
		return BLACK
	if "Hips" in b:
		return PANTS
	return TUNIC


static func _bone_mat(b: String) -> float:
	if "Hand" in b or "Foot" in b or "Toe" in b:
		return 0.75
	return 1.0


# Körper und Gelenke zusammen: Arrays mit Farben (Weich überblendet nach Knochengewicht)
static func _base(body: MeshInstance3D, joints: MeshInstance3D, names: Array) -> Dictionary:
	var out := {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(),
		"b": PackedInt32Array(), "w": PackedFloat32Array(), "i": PackedInt32Array()}
	var tab := PackedColorArray()
	var tab_j := PackedColorArray()
	for nm in names:
		var col := _bone_color(nm)
		col.a = _bone_mat(nm)
		tab.append(col)
		var dark := Color(col.r * 0.75, col.g * 0.75, col.b * 0.75, 0.75)
		tab_j.append(dark)
	var offset := 0
	for part in [body, joints]:
		var a: Array = (part as MeshInstance3D).mesh.surface_get_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var n := v.size()
		var per: int = bones.size() / n
		var t: PackedColorArray = tab if part == body else tab_j
		var cols := PackedColorArray()
		cols.resize(n)
		var b4 := PackedInt32Array()
		var w4 := PackedFloat32Array()
		b4.resize(n * 4)
		w4.resize(n * 4)
		for i in range(n):
			var c := Color(0, 0, 0, 0)
			var wsum := 0.0
			for k in range(4):
				var w: float = weights[i * per + k]
				b4[i * 4 + k] = bones[i * per + k]
				w4[i * 4 + k] = w
				if w > 0.0:
					c += t[bones[i * per + k]] * w
					wsum += w
			if wsum > 0.0:
				c = c / wsum
			cols[i] = c
		out["v"].append_array(v)
		out["n"].append_array(a[Mesh.ARRAY_NORMAL])
		out["c"].append_array(cols)
		out["b"].append_array(b4)
		out["w"].append_array(w4)
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		if offset == 0:
			out["i"].append_array(idx)
		else:
			for ix in idx:
				out["i"].append(ix + offset)
		offset += n
	return out


static func _assemble(base: Dictionary, gears: Array) -> ArrayMesh:
	var v: PackedVector3Array = base["v"].duplicate()
	var n: PackedVector3Array = base["n"].duplicate()
	var c: PackedColorArray = base["c"].duplicate()
	var b: PackedInt32Array = base["b"].duplicate()
	var w: PackedFloat32Array = base["w"].duplicate()
	var idx: PackedInt32Array = base["i"].duplicate()
	var uv := PackedVector2Array()
	uv.resize(v.size())
	uv.fill(Vector2(-1, -1))
	for g in gears:
		var off := v.size()
		v.append_array(g.v)
		n.append_array(g.n)
		c.append_array(g.c)
		b.append_array(g.b)
		w.append_array(g.w)
		uv.append_array(g.uv)
		for ix in g.idx:
			idx.append(ix + off)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_BONES] = b
	arrays[Mesh.ARRAY_WEIGHTS] = w
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


# Sammelt Ausrüstungsteile (Boxen, Ellipsoide, Zylinder), jedes fest an einen Knochen geklebt.
# Alle Koordinaten im Skelettraum der T-Pose: +Y oben, +Z vorn, +X links der Figur.
class Gear:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var b := PackedInt32Array()
	var w := PackedFloat32Array()
	var idx := PackedInt32Array()
	var bind := {}

	func add(m: PrimitiveMesh, xf: Transform3D, col: Color, mat: float, bone: String) -> void:
		var a := m.get_mesh_arrays()
		var pv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var pn: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var pi: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var base := v.size()
		var nb := xf.basis.inverse().transposed()
		var bi: int = bind["mixamorig_" + bone]
		var cc := Color(col.r, col.g, col.b, mat)
		for i in range(pv.size()):
			v.append(xf * pv[i])
			n.append((nb * pn[i]).normalized())
			c.append(cc)
			uv.append(Vector2(-1, -1))
			b.append(bi)
			b.append(0)
			b.append(0)
			b.append(0)
			w.append(1.0)
			w.append(0.0)
			w.append(0.0)
			w.append(0.0)
		for i in pi:
			idx.append(i + base)

	func xf(size: Vector3, pos: Vector3, rot: Vector3) -> Transform3D:
		return Transform3D(Basis.from_euler(rot * (PI / 180.0)) * Basis.from_scale(size), pos)

	func box(size: Vector3, pos: Vector3, rot: Vector3, col: Color, mat: float, bone: String) -> void:
		var m := BoxMesh.new()
		add(m, xf(size, pos, rot), col, mat, bone)

	func ell(radii: Vector3, pos: Vector3, rot: Vector3, col: Color, mat: float, bone: String) -> void:
		var m := SphereMesh.new()
		m.radius = 1.0
		m.height = 2.0
		m.radial_segments = 14
		m.rings = 8
		add(m, xf(radii, pos, rot), col, mat, bone)

	# Zylinder mit Achse nach oben (Y); rx/rz = Radien, h = Länge
	func cyl(rx: float, rz: float, h: float, pos: Vector3, rot: Vector3, col: Color, mat: float, bone: String) -> void:
		var m := CylinderMesh.new()
		m.top_radius = 1.0
		m.bottom_radius = 1.0
		m.height = 1.0
		m.radial_segments = 16
		m.rings = 1
		add(m, xf(Vector3(rx, h, rz), pos, rot), col, mat, bone)

	# Aufgeklebtes Abzeichen (Textur) auf einem Ellipsoid, damit es der Brust folgt
	func patch(center: Vector2, size: Vector2, ec: Vector3, er: Vector3, lift: float, col: Color, bone: String) -> void:
		var base := v.size()
		var bi: int = bind["mixamorig_" + bone]
		var seg := 6
		for j in range(seg + 1):
			for i in range(seg + 1):
				var fx := float(i) / seg
				var fy := float(j) / seg
				var x := center.x + (fx - 0.5) * size.x
				var y := center.y + (fy - 0.5) * size.y
				var dx := (x - ec.x) / er.x
				var dy := (y - ec.y) / er.y
				var zz := sqrt(maxf(1.0 - dx * dx - dy * dy, 0.0))
				var nrm := Vector3(dx / er.x, dy / er.y, zz / er.z).normalized()
				v.append(Vector3(x, y, ec.z + zz * er.z) + nrm * lift)
				n.append(nrm)
				c.append(Color(col.r, col.g, col.b, 1.0))
				uv.append(Vector2(fx, 1.0 - fy))
				b.append(bi)
				b.append(0)
				b.append(0)
				b.append(0)
				w.append(1.0)
				w.append(0.0)
				w.append(0.0)
				w.append(0.0)
		for j in range(seg):
			for i in range(seg):
				var bl := base + j * (seg + 1) + i
				var br := bl + 1
				var tl := bl + seg + 1
				var tr := tl + 1
				idx.append(tl)
				idx.append(tr)
				idx.append(br)
				idx.append(tl)
				idx.append(br)
				idx.append(bl)


# Ausrüstung, die jeder Hydra-Soldat trägt
static func _gear_common(g: Gear) -> void:
	# Kopf: Helm, Maske mit Sichtschlitz, Atemfilter
	g.ell(Vector3(0.094, 0.098, 0.14), Vector3(0, 1.714, -0.012), Vector3.ZERO, HELMET, 0.75, "Head")
	g.ell(Vector3(0.088, 0.042, 0.07), Vector3(0, 1.628, -0.085), Vector3.ZERO, HELMET, 0.75, "Head")  # Nackenschutz
	g.ell(Vector3(0.092, 0.032, 0.142), Vector3(0, 1.672, 0.0), Vector3.ZERO, BLACK, 0.75, "Head")  # Visierband
	g.ell(Vector3(0.094, 0.007, 0.1455), Vector3(0, 1.673, 0.0), Vector3.ZERO, Color(0.95, 0.03, 0.02), 0.0, "Head")  # Sichtschlitz (leuchtet)
	g.ell(Vector3(0.056, 0.046, 0.052), Vector3(0, 1.598, 0.08), Vector3.ZERO, BLACK, 0.75, "Head")  # Atemmaske
	g.cyl(0.02, 0.02, 0.04, Vector3(0, 1.594, 0.128), Vector3(90, 0, 0), GUNMETAL, 0.5, "Head")  # Filter
	g.box(Vector3(0.014, 0.026, 0.2), Vector3(0, 1.81, -0.012), Vector3.ZERO, GUNMETAL, 0.5, "Head")  # Helmgrat
	for s in [-1.0, 1.0]:
		g.cyl(0.034, 0.034, 0.025, Vector3(s * 0.09, 1.668, -0.01), Vector3(0, 0, 90), GUNMETAL, 0.5, "Head")  # Ohrenschutz
	g.cyl(0.062, 0.075, 0.07, Vector3(0, 1.545, -0.01), Vector3.ZERO, BLACK, 1.0, "Neck")  # Kragen

	# Rumpf: Weste mit Abzeichen, Taschen, Gurte
	var ec := Vector3(0, 1.22, 0.012)
	var er := Vector3(0.158, 0.17, 0.14)
	g.ell(er, ec, Vector3.ZERO, TUNIC_DARK, 1.0, "Spine2")
	g.patch(Vector2(0, 1.265), Vector2(0.16, 0.16), ec, er, 0.004, TUNIC_DARK, "Spine2")
	g.ell(Vector3(0.175, 0.05, 0.12), Vector3(0, 1.395, -0.005), Vector3.ZERO, TUNIC_DARK, 1.0, "Spine2")  # Schulterpartie
	for s in [-1.0, 1.0]:
		g.box(Vector3(0.03, 0.3, 0.012), Vector3(s * 0.112, 1.235, 0.108), Vector3(0, s * 40.0, 0), STRAP, 0.75, "Spine2")  # Gurt
		g.box(Vector3(0.055, 0.075, 0.035), Vector3(s * 0.065, 1.1, 0.138), Vector3(0, s * 12.0, 0), STRAP, 0.75, "Spine1")  # Magazintasche
	# Gürtel
	g.cyl(0.155, 0.137, 0.058, Vector3(0, 1.052, 0.012), Vector3.ZERO, STRAP, 0.75, "Hips")
	g.box(Vector3(0.05, 0.044, 0.016), Vector3(0, 1.052, 0.15), Vector3.ZERO, BRASS, 0.5, "Hips")  # Schnalle
	for s in [-1.0, 1.0]:
		g.box(Vector3(0.07, 0.075, 0.045), Vector3(s * 0.105, 1.05, 0.118), Vector3(0, s * 30.0, 0), LEATHER, 0.75, "Hips")
		g.cyl(0.032, 0.032, 0.1, Vector3(s * 0.16, 1.045, -0.04), Vector3(0, 0, 0), OLIVE, 0.75, "Hips")  # Wasserflasche
	# Rucksack mit Schlafrolle
	g.box(Vector3(0.2, 0.22, 0.095), Vector3(0, 1.21, -0.172), Vector3.ZERO, OLIVE, 1.0, "Spine1")
	g.cyl(0.042, 0.042, 0.22, Vector3(0, 1.345, -0.175), Vector3(0, 0, 90), LEATHER, 0.75, "Spine1")
	for s in [-1.0, 1.0]:
		g.box(Vector3(0.03, 0.2, 0.02), Vector3(s * 0.09, 1.3, -0.1), Vector3.ZERO, STRAP, 0.75, "Spine2")  # Rückengurt

	# Arme: Schulterpanzer, Ellbogenschutz, Unterarmschienen, Handschuhstulpen
	for s in [-1.0, 1.0]:
		var side := "Left" if s > 0 else "Right"
		g.ell(Vector3(0.068, 0.036, 0.085), Vector3(s * 0.22, 1.482, -0.06), Vector3(0, 0, -s * 14.0), GUNMETAL, 0.5, side + "Arm")
		g.ell(Vector3(0.046, 0.054, 0.056), Vector3(s * 0.462, 1.44, -0.085), Vector3.ZERO, LEATHER, 0.75, side + "ForeArm")
		g.cyl(0.059, 0.059, 0.17, Vector3(s * 0.61, 1.436, -0.062), Vector3(0, 0, 90), LEATHER, 0.75, side + "ForeArm")
		g.cyl(0.055, 0.055, 0.05, Vector3(s * 0.7, 1.436, -0.062), Vector3(0, 0, 90), BLACK, 0.75, side + "ForeArm")

	# Beine: Knieschützer, Schienbeinschutz, Taschen, Holster, Stiefelschäfte, Sohlen
	for s in [-1.0, 1.0]:
		var side := "Left" if s > 0 else "Right"
		g.ell(Vector3(0.052, 0.06, 0.034), Vector3(s * 0.094, 0.525, 0.078), Vector3.ZERO, GUNMETAL, 0.5, side + "Leg")
		g.box(Vector3(0.07, 0.19, 0.028), Vector3(s * 0.093, 0.31, 0.04), Vector3.ZERO, GUNMETAL, 0.5, side + "Leg")
		g.cyl(0.058, 0.074, 0.095, Vector3(s * 0.092, 0.215, -0.035), Vector3.ZERO, BLACK, 0.75, side + "Leg")
		g.ell(Vector3(0.062, 0.034, 0.16), Vector3(s * 0.093, 0.034, 0.045), Vector3.ZERO, Color(0.015, 0.015, 0.015), 1.0, side + "Foot")
	g.box(Vector3(0.046, 0.12, 0.092), Vector3(0.208, 0.74, -0.01), Vector3.ZERO, OLIVE, 1.0, "LeftUpLeg")  # Oberschenkeltasche
	g.box(Vector3(0.056, 0.17, 0.09), Vector3(-0.205, 0.8, 0.0), Vector3.ZERO, LEATHER, 0.75, "RightUpLeg")  # Holster
	g.box(Vector3(0.04, 0.05, 0.03), Vector3(-0.205, 0.9, 0.0), Vector3.ZERO, GUNMETAL, 0.5, "RightUpLeg")  # Pistolengriff


# Zusatz für den Offizier: rote Abzeichen, roter Helmkamm, Schulterstücke
static func _gear_officer(g: Gear) -> void:
	g.box(Vector3(0.022, 0.034, 0.2), Vector3(0, 1.818, -0.012), Vector3.ZERO, RED, 1.0, "Head")  # Helmkamm
	g.ell(Vector3(0.1, 0.006, 0.139), Vector3(0, 1.742, -0.012), Vector3.ZERO, RED, 1.0, "Head")  # roter Streifen
	for s in [-1.0, 1.0]:
		var side := "Left" if s > 0 else "Right"
		g.cyl(0.06, 0.06, 0.05, Vector3(s * 0.34, 1.436, -0.062), Vector3(0, 0, 90), RED, 1.0, side + "Arm")  # Armbinde
		g.box(Vector3(0.07, 0.008, 0.06), Vector3(s * 0.215, 1.505, -0.06), Vector3(0, 0, -s * 14.0), BRASS, 0.5, side + "Arm")  # Schulterstück
		g.box(Vector3(0.03, 0.01, 0.03), Vector3(s * 0.215, 1.51, -0.06), Vector3(0, 0, -s * 14.0), RED, 1.0, side + "Arm")
	g.box(Vector3(0.3, 0.035, 0.012), Vector3(0, 1.065, 0.152), Vector3.ZERO, RED, 1.0, "Hips")  # roter Gürtelstreifen


# --- Abzeichen -----------------------------------------------------------

# Hydra-Zeichen: roter Totenkopf mit Tentakeln auf schwarzem Grund (einmal gezeichnet)
static func _emblem_texture() -> ImageTexture:
	var sz := 128
	var img := Image.create(sz, sz, true, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var red := Color(0.85, 0.06, 0.05, 1.0)
	var black := Color(0.025, 0.025, 0.03, 1.0)
	# schwarze Scheibe mit rotem Rand
	_disc(img, 0.5, 0.5, 0.49, red)
	_disc(img, 0.5, 0.5, 0.45, black)
	# Tentakel unter dem Schädel
	for k in range(7):
		var a := lerpf(-1.15, 1.15, k / 6.0)
		var phase := float(k) * 1.7
		for s in range(0, 31):
			var f := s / 30.0
			var dirv := Vector2(sin(a), cos(a))
			var perp := Vector2(dirv.y, -dirv.x)
			var p := Vector2(0.5, 0.56) + dirv * (0.08 + f * 0.3) + perp * sin(f * 9.0 + phase) * 0.03 * f
			if p.distance_to(Vector2(0.5, 0.5)) < 0.42:
				_disc(img, p.x, p.y, lerpf(0.028, 0.008, f), red)
	# Schädel
	_ellipse(img, 0.5, 0.37, 0.19, 0.17, red)
	_ellipse(img, 0.5, 0.5, 0.115, 0.075, red)
	_ellipse(img, 0.43, 0.38, 0.05, 0.055, black)
	_ellipse(img, 0.57, 0.38, 0.05, 0.055, black)
	_ellipse(img, 0.5, 0.47, 0.016, 0.026, black)
	for tx in [0.46, 0.5, 0.54]:
		_ellipse(img, tx, 0.535, 0.006, 0.026, black)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _disc(img: Image, cx: float, cy: float, r: float, col: Color) -> void:
	_ellipse(img, cx, cy, r, r, col)


static func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	var sz := img.get_width()
	var x0 := maxi(int((cx - rx) * sz) - 1, 0)
	var x1 := mini(int((cx + rx) * sz) + 1, sz - 1)
	var y0 := maxi(int((cy - ry) * sz) - 1, 0)
	var y1 := mini(int((cy + ry) * sz) + 1, sz - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := ((x + 0.5) / sz - cx) / rx
			var dy := ((y + 0.5) / sz - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, col)
