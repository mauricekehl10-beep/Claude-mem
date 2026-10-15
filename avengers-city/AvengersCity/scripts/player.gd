extends CharacterBody3D
# Spielfigur: laufen, sprinten, springen, Heldenwechsel. Die Figuren bestehen aus einfachen Formen.

const U = preload("res://scripts/util.gd")

var HEROES := [
	{"name": "Captain America", "suit": Color(0.10, 0.26, 0.72), "accent": Color(0.80, 0.10, 0.14), "trim": Color(0.95, 0.95, 0.95), "scale": 1.0},
	{"name": "Iron Man", "suit": Color(0.66, 0.08, 0.10), "accent": Color(0.90, 0.70, 0.22), "trim": Color(0.95, 0.80, 0.30), "scale": 1.02},
	{"name": "Thor", "suit": Color(0.26, 0.28, 0.34), "accent": Color(0.55, 0.38, 0.20), "trim": Color(0.72, 0.74, 0.80), "scale": 1.10},
]

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


func _ready() -> void:
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
	var real: Node3D = U.load_model("Superhero_Male_FullBody.gltf") if hero == 0 else null
	if real:
		var box := U.model_aabb(real)
		var s := 1.85 / maxf(box.size.y, 0.01)
		real.scale = Vector3.ONE * s
		real.position = Vector3(-box.get_center().x * s, -box.position.y * s, -box.get_center().z * s)
		real.rotation.y = PI
		model.add_child(real)
		return

	var suit := U.mat(h["suit"], 0.5, 0.1)
	var accent := U.mat(h["accent"], 0.4, 0.3)
	var trim := U.mat(h["trim"], 0.25, 0.7)

	var hips := Node3D.new()
	hips.position = Vector3(0, 1.0, 0)
	model.add_child(hips)
	for s in [-1.0, 1.0]:
		var lp := Node3D.new()
		lp.position = Vector3(s * 0.2, 0.0, 0.0)
		hips.add_child(lp)
		U.box(lp, Vector3(0.26, 0.9, 0.28), Vector3(0, -0.45, 0), suit)
		U.box(lp, Vector3(0.3, 0.16, 0.36), Vector3(0, -0.94, -0.04), accent)
		legs.append(lp)

	var torso := Node3D.new()
	torso.position = Vector3(0, 1.5, 0)
	model.add_child(torso)
	U.box(torso, Vector3(0.72, 0.8, 0.42), Vector3(0, 0.15, 0), suit)
	U.box(torso, Vector3(0.74, 0.12, 0.44), Vector3(0, -0.22, 0), trim)
	for s in [-1.0, 1.0]:
		var ap := Node3D.new()
		ap.position = Vector3(s * 0.52, 0.42, 0)
		torso.add_child(ap)
		U.box(ap, Vector3(0.22, 0.72, 0.22), Vector3(0, -0.34, 0), suit)
		U.sphere(ap, 0.13, Vector3(0, -0.74, 0), accent)
		arms.append(ap)

	var head := Node3D.new()
	head.position = Vector3(0, 0.98, 0)
	torso.add_child(head)
	U.sphere(head, 0.27, Vector3(0, 0.06, 0), suit)
	U.box(head, Vector3(0.36, 0.08, 0.05), Vector3(0, 0.02, -0.24), accent)

	# Heldenspezifische Details
	if hero == 0:
		# Schild am linken Arm: rot, weiss, blau
		U.cyl(arms[0], 0.36, 0.05, Vector3(-0.05, -0.5, -0.2), accent, Vector3(90, 0, 0))
		U.cyl(arms[0], 0.27, 0.06, Vector3(-0.05, -0.5, -0.22), trim, Vector3(90, 0, 0))
		U.cyl(arms[0], 0.17, 0.07, Vector3(-0.05, -0.5, -0.24), suit, Vector3(90, 0, 0))
	elif hero == 1:
		# Arc-Reaktor und Glas-Augen
		U.sphere(torso, 0.12, Vector3(0, 0.22, -0.22), U.glow(Color(0.5, 0.9, 1.0), 3.0))
		U.box(head, Vector3(0.2, 0.03, 0.04), Vector3(0, 0.03, -0.26), U.glow(Color(0.6, 0.95, 1.0), 2.0))
	elif hero == 2:
		# Hammer in der rechten Hand, roter Umhang
		U.cyl(arms[1], 0.035, 0.6, Vector3(0, -0.75, -0.05), U.mat(Color(0.35, 0.22, 0.12), 0.8))
		U.box(arms[1], Vector3(0.2, 0.2, 0.3), Vector3(0, -1.1, -0.05), trim)
		U.box(torso, Vector3(0.7, 1.2, 0.04), Vector3(0, 0.1, 0.24), U.mat(Color(0.7, 0.08, 0.08), 0.7))


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
	if legs.is_empty():
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
