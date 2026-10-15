extends CharacterBody3D
# Hydra-Soldat: läuft auf den Spieler zu, schlägt zu, hat einen Lebensbalken.

const U = preload("res://scripts/util.gd")

const MAX_HP := 60.0
const SPEED := 4.0
const SEE_RANGE := 30.0

var hp := MAX_HP
var model: Node3D
var arm_r: Node3D
var bar: Label3D
var cooldown := 0.0
var swing := 0.0
var phase := 0.0
var flash := 0.0


func _ready() -> void:
	add_to_group("enemies")
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	col.shape = cap
	col.position = Vector3(0, 0.9, 0)
	add_child(col)

	model = Node3D.new()
	add_child(model)
	var suit := U.mat(Color(0.12, 0.14, 0.12), 0.6, 0.1)
	var red := U.mat(Color(0.75, 0.08, 0.08), 0.5, 0.2)
	U.box(model, Vector3(0.26, 0.9, 0.28), Vector3(-0.2, 0.45, 0), suit)
	U.box(model, Vector3(0.26, 0.9, 0.28), Vector3(0.2, 0.45, 0), suit)
	U.box(model, Vector3(0.72, 0.8, 0.42), Vector3(0, 1.4, 0), suit)
	U.box(model, Vector3(0.3, 0.3, 0.05), Vector3(0, 1.5, -0.22), red)
	U.box(model, Vector3(0.22, 0.7, 0.22), Vector3(-0.52, 1.35, 0), suit)
	arm_r = Node3D.new()
	arm_r.position = Vector3(0.52, 1.75, 0)
	model.add_child(arm_r)
	U.box(arm_r, Vector3(0.22, 0.7, 0.22), Vector3(0, -0.35, 0), suit)
	U.sphere(model, 0.27, Vector3(0, 2.0, 0), U.mat(Color(0.2, 0.2, 0.2), 0.5))
	U.box(model, Vector3(0.4, 0.1, 0.05), Vector3(0, 2.02, -0.24), red)

	bar = Label3D.new()
	bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bar.no_depth_test = true
	bar.font_size = 48
	bar.pixel_size = 0.006
	bar.position = Vector3(0, 2.6, 0)
	add_child(bar)
	update_bar()


func update_bar() -> void:
	var n := int(ceil(hp / MAX_HP * 10.0))
	bar.text = "█".repeat(n) + "░".repeat(10 - n)
	bar.modulate = Color(0.9, 0.15, 0.15)


func hit(dmg: float, from: Vector3) -> void:
	hp -= dmg
	var away := global_position - from
	away.y = 0.0
	if away.length() > 0.01:
		velocity += away.normalized() * 7.0
	flash = 0.15
	if hp <= 0.0:
		queue_free()
		return
	update_bar()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 26.0 * delta
	cooldown = maxf(cooldown - delta, 0.0)
	swing = maxf(swing - delta, 0.0)
	flash = maxf(flash - delta, 0.0)
	bar.modulate = Color(1, 1, 1) if flash > 0.0 else Color(0.9, 0.15, 0.15)

	var target: Node3D = null
	for p in get_tree().get_nodes_in_group("player"):
		if p.active:
			target = p
	var move := Vector3.ZERO
	if target:
		var to: Vector3 = target.global_position - global_position
		var flat := Vector3(to.x, 0.0, to.z)
		var dist := flat.length()
		if dist < SEE_RANGE and dist > 0.01:
			model.rotation.y = lerp_angle(model.rotation.y, atan2(-flat.x, -flat.z), clamp(10.0 * delta, 0.0, 1.0))
			if dist > 1.6:
				move = flat.normalized() * SPEED
			elif cooldown <= 0.0 and absf(to.y) < 2.5:
				cooldown = 1.2
				swing = 0.3
				target.hurt()
	velocity.x = move_toward(velocity.x, move.x, 40.0 * delta)
	velocity.z = move_toward(velocity.z, move.z, 40.0 * delta)
	move_and_slide()

	phase += delta * move.length() * 2.0
	arm_r.rotation.x = 1.8 if swing > 0.0 else sin(phase) * 0.5
