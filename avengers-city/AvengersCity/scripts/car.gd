extends CharacterBody3D
# Auto zum Fahren (jedes Auto der Stadt kann es werden): Gas/Bremse/Rueckwaerts, Lenkung nimmt mit dem Tempo ab,
# Handbremse-Drift (Leertaste), Nick/Wank, Abprallen an Waenden, Rammen von Gegnern, weiche Verfolgerkamera.

const CM = preload("res://scripts/car_model.gd")
const VFX = preload("res://scripts/vfx.gd")

const MAX_SPEED := 38.0
const RAM_SPEED := 8.0

var active := false
var speed := 0.0  # Tempo nach vorn (m/s, negativ = rueckwaerts)
var cam: Camera3D
var type := "sedan"
var paint := Color(0.72, 0.08, 0.10)
var size := Vector3(1.84, 1.45, 4.8)
var vel := Vector3.ZERO  # waagerechte Geschwindigkeit in der Welt
var vis: Node3D
var mat: ShaderMaterial
var col: CollisionShape3D
var col_low: CollisionShape3D  # schmale untere Box: nur sie beruehrt Boden und Bordsteinrampen
var wheels := []  # Dictionary: pivot (lenkt), spin, front
var wheel_r := 0.33
var wheelbase := 2.85
var steer_now := 0.0
var spin_angle := 0.0
var tilt_p := 0.0
var tilt_r := 0.0
var prev_f := 0.0
var braking := false
var shake := 0.0
var spark_cd := 0.0
var cam_yaw := 0.0
var cam_pos := Vector3.ZERO
var hit_cd := {}  # Gegner -> Restzeit (Kollisions-Ausnahme)
var drift := 0.0


func _ready() -> void:
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(50.0)
	col = CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	add_child(col)
	col_low = CollisionShape3D.new()
	col_low.shape = BoxShape3D.new()
	add_child(col_low)
	cam = Camera3D.new()
	cam.top_level = true
	cam.fov = 66.0
	add_child(cam)
	setup(type, paint)


# Modell und Lack festlegen (das Auto uebernimmt das Aussehen eines Stadtautos)
func setup(t: String, c: Color) -> void:
	type = t
	paint = c
	var inf := CM.info(t)
	size = inf["size"]
	wheel_r = inf["R"]
	wheelbase = inf["wheelbase"]
	if vis != null:
		remove_child(vis)
		vis.free()
	vis = Node3D.new()
	add_child(vis)
	var body := MeshInstance3D.new()
	body.mesh = CM.mesh(t, 0, false)
	mat = CM.single_material(t, c)
	body.set_surface_override_material(0, mat)
	vis.add_child(body)
	wheels.clear()
	var wl: Array = inf["wheels"]
	for i in range(wl.size()):
		var wp: Vector3 = wl[i]
		var piv := Node3D.new()
		piv.position = wp
		vis.add_child(piv)
		var sp := Node3D.new()
		piv.add_child(sp)
		var mi := MeshInstance3D.new()
		mi.mesh = CM.wheel_mesh(t, 20)
		if wp.x < 0.0:
			mi.rotation.y = PI
		sp.add_child(mi)
		wheels.append({"pivot": piv, "spin": sp, "front": i < 2})
	var bs := col.shape as BoxShape3D
	var top := size.y * 0.9
	bs.size = Vector3(size.x * 0.97, top - 0.32, size.z * 0.98)
	var bl := col_low.shape as BoxShape3D
	bl.size = Vector3(size.x * 0.6, 0.4, size.z * 0.9)
	col_low.position = Vector3(0, 0.2, 0)
	col.position = Vector3(0, 0.32 + (top - 0.32) * 0.5, 0)
	tilt_p = 0.0
	tilt_r = 0.0
	steer_now = 0.0
	vis.transform = Transform3D.IDENTITY


func enter(start_speed: float = 0.0) -> void:
	active = true
	vel = _fwd() * start_speed
	speed = start_speed
	prev_f = speed
	cam_yaw = rotation.y
	cam_pos = _cam_want()
	cam.global_position = cam_pos
	cam.current = true
	_aim_cam(0.0)
	hit_cd.clear()


func leave() -> void:
	active = false


func _fwd() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0.0
	return f.normalized()


func _physics_process(delta: float) -> void:
	spark_cd = maxf(spark_cd - delta, 0.0)
	var throttle := 0.0
	var steer := 0.0
	var hand := false
	if active:
		throttle = Input.get_axis("move_back", "move_forward")
		steer = Input.get_axis("move_right", "move_left")
		hand = Input.is_action_pressed("jump")
	var fwd := _fwd()
	var f_v := vel.dot(fwd)
	var sp := absf(f_v)
	# Lenkung: nimmt mit dem Tempo ab; bei Handbremse rutscht das Heck
	var max_steer := lerpf(0.62, 0.08, pow(clampf(sp / MAX_SPEED, 0.0, 1.0), 0.65))
	steer_now = move_toward(steer_now, steer * max_steer, (4.5 if steer != 0.0 else 6.0) * delta)
	var yaw_rate := f_v / wheelbase * tan(steer_now)
	if hand and sp > 4.0:
		yaw_rate *= 1.3
	# Querbeschleunigung begrenzen: bei hohem Tempo keine Kurven mit Vollausschlag (Handbremse erlaubt mehr Drehung)
	var yaw_cap := (24.0 if hand else 13.0) / maxf(sp, 3.0)
	yaw_rate = clampf(yaw_rate, -yaw_cap, yaw_cap)
	rotation.y += yaw_rate * delta
	fwd = _fwd()
	var right := fwd.cross(Vector3.UP)
	f_v = vel.dot(fwd)
	var l_v := vel.dot(right)
	# Laengs: Gas, Bremse, Rueckwaerts, Ausrollen
	braking = false
	if active:
		if throttle > 0.0:
			if f_v < -0.5:
				f_v = move_toward(f_v, 0.0, 16.0 * delta)
				braking = true
			else:
				f_v += (11.0 * (1.0 - clampf(f_v / MAX_SPEED, 0.0, 1.0)) + 1.5) * delta
		elif throttle < 0.0:
			if f_v > 0.5:
				f_v = move_toward(f_v, 0.0, 18.0 * delta)
				braking = true
			else:
				f_v -= 6.5 * (1.0 - clampf(-f_v / 9.0, 0.0, 1.0)) * delta
		else:
			f_v = move_toward(f_v, 0.0, 2.2 * delta)
	else:
		f_v = move_toward(f_v, 0.0, 9.0 * delta)
	if hand:
		f_v = move_toward(f_v, 0.0, 7.0 * delta)
		braking = true
	f_v -= f_v * absf(f_v) * 0.003 * delta
	f_v = clampf(f_v, -9.0, MAX_SPEED)
	# Seitenhaftung: Drift bei Handbremse oder hartem Lenken im Tempo
	var grip := 10.0
	if hand:
		grip = 1.3
	elif sp > 20.0 and absf(steer) > 0.6:
		grip = 6.5
	if not active:
		grip = 12.0
	l_v *= exp(-grip * delta)
	f_v -= signf(f_v) * minf(absf(l_v) * 0.25 * delta, absf(f_v))
	vel = fwd * f_v + right * l_v
	var vel_before := vel
	if active and vel.length() >= RAM_SPEED:
		_ram(delta)
	_update_exceptions(delta)
	velocity.x = vel.x
	velocity.z = vel.z
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= 26.0 * delta
	move_and_slide()
	vel = Vector3(velocity.x, 0.0, velocity.z)
	# Wandkontakt: abprallen, Tempo verlieren, Funken (Boden und Rampen zaehlen nicht)
	for i in range(get_slide_collision_count()):
		var c := get_slide_collision(i)
		var n := c.get_normal()
		if n.y > 0.6:
			continue
		var other := c.get_collider()
		if other != null and other.is_in_group("enemies"):
			continue
		n.y = 0.0
		if n.length() < 0.01:
			continue
		n = n.normalized()
		var vn := vel_before.dot(n)
		if vn < -1.2:
			var impact := -vn
			vel += n * impact * 0.30
			vel *= 0.93
			if impact > 3.0:
				shake = maxf(shake, clampf(impact * 0.025, 0.0, 0.5))
				rotation.y += clampf(signf(fwd.cross(n).y) * impact * 0.004, -0.08, 0.08)
				if spark_cd <= 0.0 and get_parent() != null:
					spark_cd = 0.25
					VFX.impact(get_parent(), c.get_position() + Vector3(0, 0.3, 0), n)
		break
	speed = vel.dot(_fwd())
	_visuals(delta, speed, steer_now, yaw_rate)
	prev_f = speed


func _visuals(delta: float, f_v: float, steer: float, yaw_rate: float) -> void:
	var a_long := (f_v - prev_f) / maxf(delta, 0.001)
	var a_lat := yaw_rate * f_v
	var tp := clampf(a_long * 0.0042, -0.06, 0.05)
	var tr := clampf(-a_lat * 0.0038, -0.075, 0.075)
	var k := 1.0 - exp(-7.0 * delta)
	tilt_p = lerpf(tilt_p, tp, k)
	tilt_r = lerpf(tilt_r, tr, k)
	var b := Basis.from_euler(Vector3(tilt_p, 0.0, tilt_r))
	var pivot := Vector3(0, 0.5, 0)
	vis.transform = Transform3D(b, pivot - b * pivot)
	spin_angle -= f_v / wheel_r * delta
	for w in wheels:
		(w["spin"] as Node3D).rotation.x = spin_angle
		if w["front"]:
			(w["pivot"] as Node3D).rotation.y = steer
	mat.set_shader_parameter("brake", 1.0 if braking else 0.0)


# Ab ~8 m/s verletzt das Auto Gegner (einmal pro Beruehrung, mit Rueckstoss in Fahrtrichtung)
func _ram(delta: float) -> void:
	var hx := size.x * 0.5 + 0.4
	var front := size.z * 0.5 + 0.6 + vel.length() * delta * 2.0
	var inv := global_transform.affine_inverse()
	for en in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(en) or hit_cd.has(en) or not en.has_method("hit"):
			continue
		var l: Vector3 = inv * en.global_position
		if absf(l.x) < hx and l.z < size.z * 0.5 and l.z > -front and absf(l.y) < 2.5:
			var dmg := clampf(30.0 + (vel.length() - RAM_SPEED) * 0.6, 30.0, 42.0)
			en.hit(dmg, en.global_position - vel.normalized() * 2.0)
			hit_cd[en] = 1.2
			add_collision_exception_with(en)
			if en is PhysicsBody3D:
				(en as PhysicsBody3D).add_collision_exception_with(self)
			shake = maxf(shake, 0.25)


func _update_exceptions(delta: float) -> void:
	for en in hit_cd.keys():
		hit_cd[en] -= delta
		if hit_cd[en] <= 0.0 or not is_instance_valid(en):
			if is_instance_valid(en):
				remove_collision_exception_with(en)
				if en is PhysicsBody3D:
					(en as PhysicsBody3D).remove_collision_exception_with(self)
			hit_cd.erase(en)


# ---------- Kamera ----------

func _cam_want() -> Vector3:
	var sp := absf(speed)
	var dist := 6.4 + sp * 0.085
	var height := 2.3 + sp * 0.022
	var back := Basis(Vector3.UP, cam_yaw) * Vector3(0, 0, 1)
	var look := global_position + Vector3(0, 1.25, 0)
	var want := global_position + back * dist + Vector3(0, height, 0)
	var q := PhysicsRayQueryParameters3D.create(look, want, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		want = hit["position"] + hit["normal"] * 0.35
	return want


func _aim_cam(delta: float) -> void:
	var sp := absf(speed)
	var look := global_position + Vector3(0, 1.2, 0) + _fwd() * minf(sp * 0.07, 1.8)
	var off := Vector3.ZERO
	if shake > 0.001:
		off = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.12
	cam.global_position = cam_pos + off
	cam.look_at(look, Vector3.UP)
	cam.fov = lerpf(cam.fov, 66.0 + clampf(sp / MAX_SPEED, 0.0, 1.0) * 18.0, 1.0 - exp(-3.0 * delta))


func _process(delta: float) -> void:
	if not active:
		return
	shake = maxf(shake - delta * 1.6, 0.0)
	var target_yaw := rotation.y
	if Vector2(vel.x, vel.z).length() > 5.0 and speed > 0.0:
		target_yaw = lerp_angle(rotation.y, atan2(-vel.x, -vel.z), 0.35)
	cam_yaw = lerp_angle(cam_yaw, target_yaw, 1.0 - exp(-4.0 * delta))
	cam_pos = cam_pos.lerp(_cam_want(), 1.0 - exp(-9.0 * delta))
	_aim_cam(delta)
