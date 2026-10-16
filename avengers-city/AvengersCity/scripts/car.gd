extends CharacterBody3D
# Auto zum Fahren: W/S Gas und Bremse, A/D lenken. Modell aus einfachen Formen.

const U = preload("res://scripts/util.gd")
const CityCars = preload("res://scripts/city_cars.gd")

var active := false
var speed := 0.0
var cam: Camera3D


func _ready() -> void:
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.9, 1.2, 3.9)
	col.shape = bs
	col.position = Vector3(0, 0.6, 0)
	add_child(col)
	build_visual(self, Color(0.82, 0.12, 0.14))
	cam = Camera3D.new()
	cam.position = Vector3(0, 2.6, 7.0)
	cam.rotation_degrees = Vector3(-12, 0, 0)
	add_child(cam)


static func build_visual(parent: Node3D, c: Color) -> void:
	# Modell wie die geparkten Autos (gemeinsamer Lack-Shader), Farbe aus c
	if U.find_asset("sedan.glb") != "":
		var info := CityCars.merged("sedan.glb")
		var mi := MeshInstance3D.new()
		mi.mesh = info[0]
		var mat := (info[2] as ShaderMaterial).duplicate() as ShaderMaterial
		mat.set_shader_parameter("use_instance", false)
		mat.set_shader_parameter("tune", Vector4(fposmod(c.h - 0.02, 1.0), 1.0, 1.0, 0.0))
		mi.material_override = mat
		mi.rotation.y = PI  # Modellfront (+Z) nach vorn (-Z)
		parent.add_child(mi)
		return
	var paint := U.mat(c, 0.25, 0.45)
	var glass := U.mat(Color(0.08, 0.12, 0.18), 0.08, 0.6)
	var dark := U.mat(Color(0.05, 0.05, 0.06), 0.9)
	var head_light := U.glow(Color(1.0, 0.95, 0.8), 3.0)
	var tail_light := U.glow(Color(1.0, 0.12, 0.1), 2.0)
	U.box(parent, Vector3(1.9, 0.7, 4.2), Vector3(0, 0.6, 0), paint)
	U.box(parent, Vector3(1.7, 0.6, 2.2), Vector3(0, 1.25, -0.2), glass)
	for z in [-1.35, 1.35]:
		for x in [-0.98, 0.98]:
			U.cyl(parent, 0.34, 0.26, Vector3(x, 0.34, z), dark, Vector3(0, 0, 90))
	for x in [-0.6, 0.6]:
		U.box(parent, Vector3(0.4, 0.14, 0.05), Vector3(x, 0.75, -2.12), head_light)
		U.box(parent, Vector3(0.4, 0.14, 0.05), Vector3(x, 0.75, 2.12), tail_light)


static func fit_car(parent: Node3D, car: Node3D) -> void:
	# Auf 4.2 Meter Länge skalieren, Boden auf Höhe 0 setzen, Längsachse nach Z drehen.
	var box := U.model_aabb(car)
	var s := 4.2 / maxf(maxf(box.size.x, box.size.z), 0.01)
	car.scale = Vector3.ONE * s
	car.position = Vector3(-box.get_center().x * s, -box.position.y * s, -box.get_center().z * s)
	var holder := Node3D.new()
	if box.size.x > box.size.z:
		holder.rotation.y = PI * 0.5
	holder.add_child(car)
	parent.add_child(holder)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 26.0 * delta
	else:
		velocity.y = 0.0
	if active:
		var throttle := Input.get_axis("move_back", "move_forward")
		var steer := Input.get_axis("move_right", "move_left")
		if throttle > 0.0:
			speed += 16.0 * delta
		elif throttle < 0.0:
			speed -= 12.0 * delta
		else:
			speed = move_toward(speed, 0.0, 5.0 * delta)
		speed = clamp(speed, -8.0, 30.0)
		var turn: float = steer * clamp(abs(speed) / 8.0, 0.0, 1.0) * 1.7 * delta
		rotation.y += turn * (1.0 if speed >= 0.0 else -1.0)
		var fwd := -global_transform.basis.z
		velocity.x = fwd.x * speed
		velocity.z = fwd.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		speed = move_toward(speed, 0.0, 10.0 * delta)
	move_and_slide()
	# Nur echte Hindernisse (Waende, Autos) bremsen, nicht der Boden oder flache Bordsteinrampen
	for i in range(get_slide_collision_count()):
		if get_slide_collision(i).get_normal().y < 0.6:
			speed *= 0.5
			break
