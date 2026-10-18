extends Node3D
# Passanten: wenige animierte Mixamo-Figuren (Y Bot, Clip "Walking"), die auf den Gehwegen um die Bloecke laufen.
# Nur nahe an der Kamera aktiv: wer zu weit weg ist, wird ausserhalb des Blickfelds neu gesetzt. Mehr Leute am Times Square.

const DIR := "res://Assets/Mixamo/"
const COUNT := 30
const RADIUS := 105.0
const STEP := 72.0
const WALK_SPEED := 1.73  # natuerliche Geschwindigkeit des Clips (m/s)
const SHIRTS := [Color(0.75, 0.1, 0.1), Color(0.1, 0.3, 0.7), Color(0.9, 0.8, 0.2), Color(0.15, 0.5, 0.3), Color(0.9, 0.9, 0.9), Color(0.1, 0.1, 0.12), Color(0.8, 0.4, 0.1), Color(0.55, 0.2, 0.6), Color(0.45, 0.45, 0.5)]
const PANTS := [Color(0.08, 0.1, 0.2), Color(0.12, 0.12, 0.13), Color(0.35, 0.27, 0.18), Color(0.2, 0.25, 0.4), Color(0.5, 0.5, 0.52)]
const SKINS := [Color(0.93, 0.72, 0.58), Color(0.75, 0.55, 0.4), Color(0.5, 0.33, 0.23), Color(0.35, 0.22, 0.15), Color(0.85, 0.65, 0.5)]

var peds := []
var rng := RandomNumberGenerator.new()
var walk_anim: Animation
var shader: Shader
var ped_scene: PackedScene
var ready_ok := false
var respawn_i := 0


func _ready() -> void:
	rng.seed = 321
	if not ResourceLoader.exists(DIR + "Y Bot.fbx") or not ResourceLoader.exists(DIR + "Walking.fbx"):
		return
	ped_scene = load(DIR + "Y Bot.fbx") as PackedScene
	var inst := (load(DIR + "Walking.fbx") as PackedScene).instantiate()
	walk_anim = (inst.get_node("AnimationPlayer") as AnimationPlayer).get_animation("mixamo_com").duplicate()
	inst.free()
	# Die Huefte bleibt auf der Stelle, das Laufen macht das Skript
	for t in range(walk_anim.get_track_count()):
		if walk_anim.track_get_type(t) == Animation.TYPE_POSITION_3D and String(walk_anim.track_get_path(t)).ends_with("Hips"):
			var first: Vector3 = walk_anim.track_get_key_value(t, 0)
			for k in range(walk_anim.track_get_key_count(t)):
				var v: Vector3 = walk_anim.track_get_key_value(t, k)
				walk_anim.track_set_key_value(t, k, Vector3(first.x, v.y, first.z))
	walk_anim.loop_mode = Animation.LOOP_LINEAR
	shader = load("res://scripts/city_ped.gdshader")
	ready_ok = true
	for i in range(COUNT):
		peds.append(make_ped())


func make_ped() -> Dictionary:
	var node := Node3D.new()
	add_child(node)
	var root := ped_scene.instantiate() as Node3D
	root.rotation.y = PI
	node.add_child(root)
	var skel: Skeleton3D = root.get_node("Skeleton3D")
	var ap: AnimationPlayer = root.get_node("AnimationPlayer")
	var lib := AnimationLibrary.new()
	lib.add_animation("walk", walk_anim)
	ap.add_animation_library("p", lib)
	var aabb := AABB()
	var first := true
	for c in skel.get_children():
		var mi := c as MeshInstance3D
		if mi and mi.mesh:
			aabb = mi.mesh.get_aabb() if first else aabb.merge(mi.mesh.get_aabb())
			first = false
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("base_y", aabb.position.y)
	m.set_shader_parameter("body_h", maxf(aabb.size.y, 0.01))
	m.set_shader_parameter("shirt", SHIRTS[rng.randi() % SHIRTS.size()])
	m.set_shader_parameter("pants", PANTS[rng.randi() % PANTS.size()])
	m.set_shader_parameter("skin", SKINS[rng.randi() % SKINS.size()])
	for c in skel.get_children():
		var mi2 := c as MeshInstance3D
		if mi2:
			mi2.material_override = m
	node.scale = Vector3.ONE * rng.randf_range(0.92, 1.04)
	ap.play("p/walk")
	ap.seek(rng.randf() * 1.0, true)
	ap.speed_scale = 1.0
	return {"node": node, "ap": ap, "bx": 0.0, "bz": 0.0, "side": 0, "u": 0.0, "dirn": 1.0, "lat": 27.3, "speed": 1.4, "active": false}


func cam_pos() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam:
		return cam.global_position
	return Vector3.ZERO


# Ort auf dem Gehweg-Ring eines Blocks: side 0..3 (+z, -z, +x, -x), u = Strecke entlang der Seite
static func ring_pos(bx: float, bz: float, side: int, u: float, lat: float) -> Vector3:
	match side:
		0:
			return Vector3(bx + u, 0.15, bz + lat)
		1:
			return Vector3(bx - u, 0.15, bz - lat)
		2:
			return Vector3(bx + lat, 0.15, bz - u)
	return Vector3(bx - lat, 0.15, bz + u)


func place(p: Dictionary, cp: Vector3, forced_far: bool) -> void:
	# Block in der Naehe der Kamera waehlen (Times-Square-Bloecke bevorzugt, wenn nah)
	var cands := []
	var cx0 := int(roundf(cp.x / STEP))
	var cz0 := int(roundf(cp.z / STEP))
	for ix in range(cx0 - 2, cx0 + 3):
		for iz in range(cz0 - 2, cz0 + 3):
			if absi(ix) > 6 or absi(iz) > 6:
				continue
			var w := 1
			if (ix == 0 or ix == 1) and (iz == -1 or iz == -2):
				w = 3
			for k in range(w):
				cands.append(Vector2i(ix, iz))
	if cands.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	for attempt in range(8):
		var b: Vector2i = cands[rng.randi() % cands.size()]
		var side := rng.randi() % 4
		var u := rng.randf_range(-24.0, 24.0)
		var lat := rng.randf_range(26.9, 28.4)
		var pos := ring_pos(b.x * STEP, b.y * STEP, side, u, lat)
		var d := Vector2(pos.x - cp.x, pos.z - cp.z).length()
		if d > RADIUS * 0.9 or d < 6.0:
			continue
		if forced_far and d < 30.0 and cam and cam.is_position_in_frustum(pos + Vector3(0, 1, 0)):
			continue
		p["bx"] = b.x * STEP
		p["bz"] = b.y * STEP
		p["side"] = side
		p["u"] = u
		p["lat"] = lat
		p["dirn"] = 1.0 if rng.randf() < 0.5 else -1.0
		p["speed"] = rng.randf_range(1.15, 1.6)
		(p["ap"] as AnimationPlayer).speed_scale = float(p["speed"]) / WALK_SPEED
		p["active"] = true
		(p["node"] as Node3D).visible = true
		update_pose(p)
		return


func update_pose(p: Dictionary) -> void:
	var pos := ring_pos(p["bx"], p["bz"], p["side"], p["u"], p["lat"])
	var ahead := ring_pos(p["bx"], p["bz"], p["side"], p["u"] + 1.0 * p["dirn"], p["lat"])
	var d := (ahead - pos)
	var n: Node3D = p["node"]
	n.global_position = pos
	n.rotation.y = atan2(-d.x, -d.z)


func _process(delta: float) -> void:
	if not ready_ok:
		return
	var cp := cam_pos()
	var moved := 0
	for p in peds:
		if not p["active"]:
			if respawn_i % 2 == 0:
				place(p, cp, false)
			respawn_i += 1
			continue
		p["u"] += p["dirn"] * p["speed"] * delta
		# an der Blockecke auf die naechste Seite abbiegen (Ringfolge vorwaerts: +z -> +x -> -z -> -x -> +z)
		var lim: float = p["lat"]
		if p["u"] > lim and p["dirn"] > 0.0:
			p["side"] = [2, 3, 1, 0][p["side"]]
			p["u"] = -lim
		elif p["u"] < -lim and p["dirn"] < 0.0:
			p["side"] = [3, 2, 0, 1][p["side"]]
			p["u"] = lim
		update_pose(p)
		var np: Vector3 = (p["node"] as Node3D).global_position
		if Vector2(np.x - cp.x, np.z - cp.z).length() > RADIUS:
			p["active"] = false
			(p["node"] as Node3D).visible = false
