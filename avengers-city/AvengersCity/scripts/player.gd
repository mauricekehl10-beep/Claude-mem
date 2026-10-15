extends CharacterBody3D
# Spielfigur: laufen, sprinten, springen, Heldenwechsel. Die Figuren bestehen aus einfachen Formen.

const U = preload("res://scripts/util.gd")
const HeroModel = preload("res://scripts/hero_model.gd")

var HEROES := [
	{"name": "Captain America", "suit": Color(0.10, 0.26, 0.72), "accent": Color(0.80, 0.10, 0.14), "trim": Color(0.95, 0.95, 0.95), "scale": 1.0},
	{"name": "Iron Man", "suit": Color(0.66, 0.08, 0.10), "accent": Color(0.90, 0.70, 0.22), "trim": Color(0.95, 0.80, 0.30), "scale": 1.02},
	{"name": "Thor", "suit": Color(0.26, 0.28, 0.34), "accent": Color(0.55, 0.38, 0.20), "trim": Color(0.72, 0.74, 0.80), "scale": 1.10},
]

const USE_REAL_BODY := false

var hero := 0
var active := true
var model: Node3D
var legs: Array = []
var arms: Array = []
var phase := 0.0
var yaw := 0.0
var pitch := -0.25
var yaw_pivot: Node3D
var pitch_pivot: Node3D
var cam: Camera3D
var col: CollisionShape3D
var start_pos := Vector3.ZERO
var hits := 0
var punch_cd := 0.0
var punch_t := 0.0
var arm_shield: Node3D
var shield: Node3D
var shield_state := 0  # 0 = am Arm, 1 = fliegt weg, 2 = kommt zurück
var shield_t := 0.0
var shield_dir := Vector3.ZERO
var shield_hit: Array = []
var shots: Array = []
var shoot_cd := 0.0
var bolt_cd := 0.0
var fly_lock := false
var flying := false


func _ready() -> void:
	add_to_group("player")
	start_pos = global_position
	col = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	col.shape = cap
	col.position = Vector3(0, 0.9, 0)
	add_child(col)

	yaw_pivot = Node3D.new()
	yaw_pivot.position = Vector3(0, 1.5, 0)
	add_child(yaw_pivot)
	pitch_pivot = Node3D.new()
	yaw_pivot.add_child(pitch_pivot)
	cam = Camera3D.new()
	cam.position = Vector3(0.6, 0.3, 5.0)
	pitch_pivot.add_child(cam)
	cam.current = true
	build_model()


func hero_name() -> String:
	return HEROES[hero]["name"]


func next_hero() -> void:
	hero = (hero + 1) % HEROES.size()
	build_model()


func set_active(on: bool) -> void:
	active = on
	visible = on
	cam.current = on
	col.set_deferred("disabled", not on)
	velocity = Vector3.ZERO


func build_model() -> void:
	if model:
		model.queue_free()
	model = Node3D.new()
	add_child(model)
	var h: Dictionary = HEROES[hero]
	model.scale = Vector3.ONE * float(h["scale"])
	legs.clear()
	arms.clear()

	# Captain America nutzt das geladene Modell, wenn es vorhanden ist.
	# Das Quaternius-Modell ist nackt (ohne Anzug). Bis es einen Anzug gibt, bleibt die Würfel-Figur.
	var real: Node3D = U.load_model("Superhero_Male_FullBody.gltf") if (hero == 0 and USE_REAL_BODY) else null
	if real:
		var box := U.model_aabb(real)
		var s := 1.85 / maxf(box.size.y, 0.01)
		real.scale = Vector3.ONE * s
		real.position = Vector3(-box.get_center().x * s, -box.position.y * s, -box.get_center().z * s)
		real.rotation.y = PI
		model.add_child(real)
		return

	var parts := HeroModel.build(hero, h, model, legs, arms)
	var accent := U.mat(h["accent"], 0.4, 0.3)
	var trim := U.mat(h["trim"], 0.25, 0.7)
	var suit := U.mat(h["suit"], 0.5, 0.1)
	if hero == 0:
		# Schild am linken Arm: rot, weiss, blau
		arm_shield = Node3D.new()
		arms[0].add_child(arm_shield)
		arm_shield.visible = shield_state == 0
		U.cyl(arm_shield, 0.36, 0.05, Vector3(-0.05, -0.5, -0.2), accent, Vector3(90, 0, 0))
		U.cyl(arm_shield, 0.27, 0.06, Vector3(-0.05, -0.5, -0.22), trim, Vector3(90, 0, 0))
		U.cyl(arm_shield, 0.17, 0.07, Vector3(-0.05, -0.5, -0.24), suit, Vector3(90, 0, 0))


func face_camera() -> void:
	var look: Vector3 = -yaw_pivot.global_transform.basis.z
	model.rotation.y = atan2(-look.x, -look.z)


func shoot() -> void:
	face_camera()
	shoot_cd = 0.25
	punch_t = 0.15
	# Zielpunkt aus der Bildmitte (Fadenkreuz), Schuss startet an der Brust
	var cam_fwd: Vector3 = -cam.global_transform.basis.z
	var origin := global_position + Vector3(0, 1.5, 0)
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + cam_fwd * 200.0)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var target: Vector3 = hit["position"] if hit else cam.global_position + cam_fwd * 200.0
	var dir := (target - origin).normalized()
	var b := U.sphere(self, 0.14, Vector3.ZERO, U.glow(Color(0.6, 0.95, 1.0), 4.0))
	b.reparent(get_parent())
	b.global_position = origin + dir * 1.0
	shots.append({"node": b, "dir": dir, "t": 0.0})


func update_shots(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	for s in shots.duplicate():
		var b: Node3D = s["node"]
		var from := b.global_position
		var to: Vector3 = from + s["dir"] * 45.0 * delta
		s["t"] += delta
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.exclude = [get_rid()]
		var r := space.intersect_ray(q)
		if r:
			if r["collider"].is_in_group("enemies"):
				r["collider"].hit(12.0, from)
			b.queue_free()
			shots.erase(s)
		elif s["t"] > 2.0:
			b.queue_free()
			shots.erase(s)
		else:
			b.global_position = to


func facing() -> Vector3:
	return -model.global_transform.basis.z


func hurt() -> void:
	hits += 1
	if hits >= 5:
		respawn()


func respawn() -> void:
	hits = 0
	global_position = start_pos
	velocity = Vector3.ZERO


func do_punch(dmg: float = 15.0, reach: float = 2.4) -> void:
	face_camera()
	punch_cd = 0.4
	punch_t = 0.2
	for e in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		if to.length() < reach and to.normalized().dot(facing()) > 0.3:
			e.hit(dmg, global_position)


# Thor: Blitz auf den Gegner, der am besten im Blickfeld liegt (oder auf einen Punkt vor ihm)
func lightning() -> void:
	face_camera()
	bolt_cd = 1.5
	var look: Vector3 = -cam.global_transform.basis.z
	look.y = 0.0
	look = look.normalized()
	var best: Node3D = null
	var best_dot := 0.6
	for e in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		if to.length() < 35.0 and to.normalized().dot(look) > best_dot:
			best_dot = to.normalized().dot(look)
			best = e
	var spot: Vector3 = best.global_position if best else global_position + look * 12.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(spot) < 3.5:
			e.hit(35.0, spot)
	var b := U.cyl(self, 0.18, 40.0, Vector3.ZERO, U.glow(Color(0.7, 0.85, 1.0), 6.0))
	b.reparent(get_parent())
	b.global_position = spot + Vector3(0, 20, 0)
	get_tree().create_timer(0.25).timeout.connect(b.queue_free)


func throw_shield() -> void:
	face_camera()
	shield_state = 1
	shield_t = 0.0
	shield_hit.clear()
	shield_dir = -yaw_pivot.global_transform.basis.z
	shield_dir.y = 0.0
	shield_dir = shield_dir.normalized()
	if arm_shield:
		arm_shield.visible = false
	shield = Node3D.new()
	U.cyl(shield, 0.36, 0.05, Vector3.ZERO, U.mat(Color(0.8, 0.1, 0.14), 0.4, 0.3))
	U.cyl(shield, 0.27, 0.06, Vector3(0, 0.005, 0), U.mat(Color(0.95, 0.95, 0.95), 0.25, 0.7))
	U.cyl(shield, 0.17, 0.07, Vector3(0, 0.01, 0), U.mat(Color(0.1, 0.26, 0.72), 0.5, 0.1))
	get_parent().add_child(shield)
	shield.global_position = global_position + Vector3(0, 1.3, 0) + shield_dir


func update_shield(delta: float) -> void:
	shield_t += delta
	var chest := global_position + Vector3(0, 1.3, 0)
	if shield_state == 1:
		shield.global_position += shield_dir * 22.0 * delta
		if shield_t > 0.6:
			shield_state = 2
			shield_hit.clear()
	else:
		var to := chest - shield.global_position
		if to.length() < 1.0:
			shield.queue_free()
			shield_state = 0
			if arm_shield:
				arm_shield.visible = true
			return
		shield.global_position += to.normalized() * 26.0 * delta
	shield.rotate_y(18.0 * delta)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e in shield_hit:
			continue
		if (e.global_position + Vector3(0, 1.0, 0)).distance_to(shield.global_position) < 1.5:
			shield_hit.append(e)
			e.hit(25.0, shield.global_position)


func _unhandled_input(event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if active and mm and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= mm.relative.x * 0.0025
		pitch = clamp(pitch - mm.relative.y * 0.0025, -1.1, 0.5)


func _physics_process(delta: float) -> void:
	yaw_pivot.rotation.y = yaw
	pitch_pivot.rotation.x = pitch
	if not active:
		return
	punch_cd = maxf(punch_cd - delta, 0.0)
	punch_t = maxf(punch_t - delta, 0.0)
	if global_position.y < -20.0:
		respawn()
	if hero == 0:
		if Input.is_action_just_pressed("attack") and punch_cd <= 0.0:
			do_punch()
		if Input.is_action_just_pressed("throw") and shield_state == 0:
			throw_shield()
	if hero == 2:
		bolt_cd = maxf(bolt_cd - delta, 0.0)
		if Input.is_action_just_pressed("attack") and punch_cd <= 0.0:
			do_punch(20.0, 3.2)
		if Input.is_action_just_pressed("throw") and bolt_cd <= 0.0:
			lightning()
	if shield_state != 0:
		update_shield(delta)
	shoot_cd = maxf(shoot_cd - delta, 0.0)
	if hero == 1 and Input.is_action_pressed("attack") and shoot_cd <= 0.0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		shoot()
	if not shots.is_empty():
		update_shots(delta)

	# Iron Man: Leertaste in der Luft = schweben, WASD fliegt in Blickrichtung.
	# Nach der Landung (Boden, Dach) muss die Leertaste erst losgelassen werden.
	if is_on_floor() or not Input.is_action_pressed("jump"):
		fly_lock = is_on_floor() and Input.is_action_pressed("jump")
	flying = (hero == 1 or hero == 2) and not is_on_floor() and not fly_lock and Input.is_action_pressed("jump")
	if flying:
		var fi := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var fdir: Vector3 = cam.global_transform.basis * Vector3(fi.x, 0.0, fi.y)
		var fspd := 24.0 if Input.is_action_pressed("sprint") else 14.0
		var want := fdir.normalized() * fspd if fi.length() > 0.05 else Vector3.ZERO
		if Input.is_action_pressed("descend"):
			want.y = -8.0
		velocity = velocity.move_toward(want, 50.0 * delta)
		if fi.length() > 0.05:
			model.rotation.y = lerp_angle(model.rotation.y, atan2(-fdir.x, -fdir.z), clamp(12.0 * delta, 0.0, 1.0))
		move_and_slide()
		animate(delta)
		return
	if not is_on_floor():
		velocity.y -= 26.0 * delta

	var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir: Vector3 = yaw_pivot.global_transform.basis * Vector3(inp.x, 0.0, inp.y)
	dir.y = 0.0
	var spd := 10.0 if Input.is_action_pressed("sprint") else 6.0
	if dir.length() > 0.05:
		dir = dir.normalized()
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-dir.x, -dir.z), clamp(12.0 * delta, 0.0, 1.0))
	else:
		velocity.x = move_toward(velocity.x, 0.0, 60.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 60.0 * delta)

	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = 8.5
	move_and_slide()
	animate(delta)


func animate(delta: float) -> void:
	# Flugpose: nach vorne gelehnt, Arme nach vorn, Beine gestreckt
	var lean := 0.0
	if flying:
		lean = (-1.2 if hero == 1 else -0.9) * clampf(velocity.length() / 14.0, 0.0, 1.0)
	model.rotation.x = lerpf(model.rotation.x, lean, clampf(8.0 * delta, 0.0, 1.0))
	# Drehpunkt in Hüfthöhe statt an den Füßen
	var c := Vector3(0, 1.0, 0)
	model.position = Basis(Vector3.UP, model.rotation.y) * (c - Basis(Vector3.RIGHT, model.rotation.x) * c)
	if legs.is_empty():
		return
	if flying:
		legs[0].rotation.x = -0.2
		legs[1].rotation.x = -0.2
		var fast := lean < -0.3
		if hero == 2:
			# Thor: ein Arm mit Mjolnir nach vorn, der andere locker zur Seite
			arms[1].rotation.x = 3.0 if fast else 0.7
			arms[0].rotation.x = -0.7
		else:
			var arm_up := 3.0 if fast else 0.35
			arms[0].rotation.x = arm_up
			arms[1].rotation.x = arm_up
		if punch_t > 0.0:
			arms[1].rotation.x = 1.6
		return
	var sp := Vector2(velocity.x, velocity.z).length()
	var k: float = clamp(sp / 6.0, 0.0, 1.0) if is_on_floor() else 0.0
	phase += delta * sp * 1.3
	var sw := sin(phase) * 0.75 * k
	legs[0].rotation.x = sw
	legs[1].rotation.x = -sw
	arms[0].rotation.x = -sw * 0.7
	arms[1].rotation.x = sw * 0.7
	if not is_on_floor():
		legs[0].rotation.x = -0.5
		legs[1].rotation.x = 0.2
		arms[0].rotation.x = -2.2
		arms[1].rotation.x = -2.2
	if punch_t > 0.0:
		arms[1].rotation.x = 1.6
