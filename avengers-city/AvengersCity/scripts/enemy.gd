extends CharacterBody3D
# Hydra-Soldat: läuft auf den Spieler zu, schlägt zu (Treffer erst im richtigen Animations-Frame),
# zuckt bei Treffern zusammen und fällt beim Tod um. Die Figur ist der animierte "Y Bot" (siehe hydra_model.gd).

const HM = preload("res://scripts/hydra_model.gd")
const VFX = preload("res://scripts/vfx.gd")

const MAX_HP := 60.0
const RUN_SPEED := 4.2
const WALK_SPEED := 2.0
const SEE_RANGE := 30.0
const RUN_RANGE := 22.0     # näher als das: rennen, weiter weg: gehen
const ATTACK_RANGE := 1.3   # ab hier holt er aus
const STOP_DIST := 1.0      # so nah geht er heran
const HIT_REACH := 1.8      # so nah muss der Spieler im Treffer-Frame noch sein
const ATTACK_SPEED := {"punch": 1.6, "melee": 1.5}  # Abspielgeschwindigkeit der Schlag-Animationen

enum {IDLE, CHASE, ATTACK, STAGGER, DEAD}

# Lebensbalken: dünne Kapsel mit Rahmen, dreht sich zur Kamera, ein Material für alle Gegner
const BAR_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
instance uniform float frac = 1.0;
instance uniform float trail = 1.0;
instance uniform float alpha = 0.0;
instance uniform float flash = 0.0;
uniform vec2 size = vec2(0.62, 0.075);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

float capsule(vec2 p, vec2 h) {
	vec2 q = abs(p) - h + h.y;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - h.y;
}

void fragment() {
	vec2 h = size * 0.5;
	vec2 p = (UV - 0.5) * size;
	float d = capsule(p, h);
	float aa = fwidth(d) * 1.2;
	float outer = 1.0 - smoothstep(-aa, aa, d);
	if (outer <= 0.0) {
		discard;
	}
	float border = 0.012;
	float inside = 1.0 - smoothstep(-aa, aa, d + border);
	float x = clamp((p.x + h.x - border) / (size.x - 2.0 * border), 0.0, 1.0);
	float v = UV.y;
	vec3 red = mix(vec3(1.0, 0.42, 0.3), vec3(0.6, 0.04, 0.05), smoothstep(0.0, 0.9, v));
	vec3 c = vec3(0.05, 0.012, 0.012);
	float in_fill = step(x, frac);
	float in_trail = step(x, trail) * (1.0 - in_fill);
	c = mix(c, vec3(1.0, 0.8, 0.5), in_trail * 0.85);
	c = mix(c, red, in_fill);
	c += vec3(1.0) * flash * in_fill * 0.6;
	c += 0.1 * (1.0 - smoothstep(0.0, 0.3, v)) * (in_fill + in_trail);
	vec3 frame = mix(vec3(0.015, 0.015, 0.02), vec3(0.5, 0.5, 0.55), 0.35 * (1.0 - smoothstep(0.0, 0.25, v)));
	ALBEDO = mix(frame, c, inside);
	ALPHA = outer * alpha * mix(0.82, 1.0, inside * in_fill);
}
"""

# Knochen, die beim Treffer-Zucken mitmachen: [Name, Anteil]
const FLINCH_BONES := [["mixamorig_Spine", 0.2], ["mixamorig_Spine1", 0.2], ["mixamorig_Spine2", 0.16],
	["mixamorig_Neck", 0.1], ["mixamorig_Head", 0.12]]
# Knochen, die beim Tod umgekippt werden (Eltern vor Kindern!)
const DEATH_BONES := ["mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2", "mixamorig_Neck", "mixamorig_Head",
	"mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_RightArm", "mixamorig_RightForeArm",
	"mixamorig_LeftUpLeg", "mixamorig_LeftLeg", "mixamorig_RightUpLeg", "mixamorig_RightLeg"]

static var spawned := 0
static var shape: CapsuleShape3D
static var bar_mesh: QuadMesh
static var bar_mat: ShaderMaterial

var hp := MAX_HP
var max_hp := MAX_HP
var officer := false
var state := IDLE
var model: Node3D     # dreht sich in Blickrichtung
var pivot: Node3D     # kippt beim Tod
var skel: Skeleton3D
var body: MeshInstance3D
var ap: AnimationPlayer
var bar: MeshInstance3D
var target: Node3D
var cur := ""
var cooldown := 0.5
var react := -1.0
var attack_t := 0.0
var attack_clip := "punch"
var attack_hit := false
var stun := 0.0
var stun_cd := 0.0
var hit_t := 99.0
var hit_amp := 0.0
var push := Vector3.ZERO
var death_t := -1.0
var puffed := false
var run_speed := RUN_SPEED
var walk_speed := WALK_SPEED
var flash := 0.0
var bar_alpha := 0.0
var bar_show := 0.0
var bar_trail := 1.0
var trail_wait := 0.0
var anim_acc := 0.0
var snap := {}
var leg_k := [1.0, 1.0]
var arm_k := [1.0, 1.0]
var scale_k := 1.0


func _ready() -> void:
	add_to_group("enemies")
	spawned += 1
	officer = spawned % 4 == 0
	max_hp = MAX_HP * (1.4 if officer else 1.0)
	hp = max_hp
	scale_k = randf_range(0.95, 1.05) * (1.03 if officer else 1.0)
	run_speed = RUN_SPEED * randf_range(0.9, 1.1)
	walk_speed = WALK_SPEED * randf_range(0.9, 1.15)
	cooldown = randf_range(0.3, 1.0)
	leg_k = [randf_range(0.5, 1.2), randf_range(0.5, 1.2)]
	arm_k = [randf_range(0.4, 1.0), randf_range(0.4, 1.0)]

	if shape == null:
		shape = CapsuleShape3D.new()
		shape.radius = 0.4
		shape.height = 1.8
		bar_mesh = QuadMesh.new()
		bar_mesh.size = Vector2(0.62, 0.075)
		var sh := Shader.new()
		sh.code = BAR_SHADER
		bar_mat = ShaderMaterial.new()
		bar_mat.shader = sh
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0, 0.9, 0)
	add_child(col)

	pivot = Node3D.new()
	add_child(pivot)
	model = Node3D.new()
	model.scale = Vector3.ONE * scale_k
	model.rotation.y = randf() * TAU
	pivot.add_child(model)
	var d := HM.spawn(model, officer)
	skel = d["skel"]
	ap = d["ap"]
	body = d["mesh"]
	ap.play("h/idle")
	ap.advance(randf() * 8.0)  # nicht alle im Gleichtakt atmen
	cur = "idle"
	# leichte Farbvariation
	var k := randf_range(0.8, 1.25)
	body.set_instance_shader_parameter("tint", Vector3(k * randf_range(0.93, 1.07), k, k * randf_range(0.93, 1.07)))

	bar = MeshInstance3D.new()
	bar.mesh = bar_mesh
	bar.material_override = bar_mat
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bar.position = Vector3(0, 2.2 * scale_k, 0)
	bar.visible = false
	add_child(bar)
	bar.set_instance_shader_parameter("alpha", 0.0)


# Treffer vom Spieler (Schlag, Schuss, Schild, Blitz ...). "from" ist die Position des Angreifers.
func hit(dmg: float, from: Vector3) -> void:
	if state == DEAD:
		return
	hp -= dmg
	var away := global_position - from
	away.y = 0.0
	if away.length() > 0.05:
		push = away.normalized()
	else:
		push = (model.global_transform.basis.z).normalized()
	velocity += push * (6.0 if hp > 0.0 else 9.0)
	hit_t = 0.0
	hit_amp = clampf(dmg / 25.0, 0.6, 1.2)
	flash = 1.0
	bar_show = 4.0
	trail_wait = 0.35
	# Funken an der Brust, sie spritzen zum Angreifer zurück
	VFX.impact(get_parent(), global_position + Vector3(0, 1.25, 0) - push * 0.2, -push + Vector3(0, 0.3, 0))
	_set_bar()
	if hp <= 0.0:
		_die()
		return
	if stun_cd <= 0.0:  # nicht in Dauer-Betäubung halten
		stun = clampf(dmg / 60.0, 0.22, 0.4)
		stun_cd = 0.9
		state = STAGGER
		attack_hit = true


func _set_bar() -> void:
	bar.set_instance_shader_parameter("frac", clampf(hp / max_hp, 0.0, 1.0))


func _find_target() -> Node3D:
	var t: Node3D = null
	for p in get_tree().get_nodes_in_group("player"):
		if p.active:
			t = p
	return t


func _physics_process(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)
	stun_cd = maxf(stun_cd - delta, 0.0)
	if not is_on_floor():
		velocity.y -= 26.0 * delta
	if state == DEAD:
		# nach dem Tod noch ein Stück rutschen
		velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
		if velocity.length() > 0.05 or not is_on_floor():
			move_and_slide()
		return

	target = _find_target()
	var move := Vector3.ZERO
	var flat := Vector3.ZERO
	var dist := INF
	var dy := 0.0
	if target:
		var to: Vector3 = target.global_position - global_position
		dy = to.y
		flat = Vector3(to.x, 0.0, to.z)
		dist = flat.length()
	var seen := target != null and dist < SEE_RANGE and dist > 0.01

	match state:
		STAGGER:
			stun -= delta
			if stun <= 0.0:
				state = IDLE
				react = 0.0
		ATTACK:
			if seen and not attack_hit:
				_turn(flat, 5.0, delta)  # beim Ausholen noch leicht nachzielen
			attack_t += delta * ATTACK_SPEED[attack_clip]
			if not attack_hit and attack_t >= HM.HIT_TIME[attack_clip]:
				attack_hit = true
				_strike(flat, dist, dy)
			if attack_t >= ap.get_animation("h/" + attack_clip).length - 0.12:
				state = IDLE
				react = 0.0
		_:
			if seen:
				_turn(flat, 9.0, delta)
				if state == IDLE:
					if react < 0.0:
						react = randf_range(0.2, 0.8)  # kurze Schrecksekunde, bevor er losläuft
					react -= delta
					if react <= 0.0:
						state = CHASE
				if state == CHASE:
					if dist <= ATTACK_RANGE and cooldown <= 0.0 and absf(dy) < 2.5:
						_start_attack()
					elif dist > STOP_DIST:
						move = flat.normalized() * (run_speed if dist < RUN_RANGE else walk_speed)
			else:
				state = IDLE
				react = -1.0
	velocity.x = move_toward(velocity.x, move.x, 24.0 * delta)
	velocity.z = move_toward(velocity.z, move.z, 24.0 * delta)
	move_and_slide()


func _turn(flat: Vector3, rate: float, delta: float) -> void:
	if flat.length() > 0.01:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-flat.x, -flat.z), clampf(rate * delta, 0.0, 1.0))


func _start_attack() -> void:
	state = ATTACK
	attack_t = 0.0
	attack_hit = false
	cooldown = randf_range(1.5, 2.1)
	attack_clip = "melee" if randf() < (0.5 if officer else 0.25) else "punch"


# Der Schlag trifft (genau im Treffer-Frame der Animation)
func _strike(flat: Vector3, dist: float, dy: float) -> void:
	if target == null or not target.active:
		return
	var fwd := -model.global_transform.basis.z
	if dist <= HIT_REACH and absf(dy) < 2.5 and (dist < 0.3 or fwd.dot(flat.normalized()) > 0.35):
		target.hurt()
		var n := -flat.normalized() if dist > 0.01 else Vector3.UP
		VFX.impact(get_parent(), target.global_position + Vector3(0, 1.3, 0) + n * 0.2, n + Vector3(0, 0.3, 0), Color(1.0, 0.55, 0.3))


func _die() -> void:
	state = DEAD
	remove_from_group("enemies")  # Spieler zielt und trifft ihn nicht mehr
	collision_layer = 0
	death_t = 0.0
	hp = 0.0
	bar.visible = false
	for nm in DEATH_BONES:
		var i := skel.find_bone(nm)
		snap[i] = skel.get_bone_pose_rotation(i)


# --- Animation (jedes Bild) ---------------------------------------------

func _process(delta: float) -> void:
	if state == DEAD:
		_process_death(delta)
		return
	flash = maxf(flash - delta * 7.0, 0.0)
	body.set_instance_shader_parameter("flash", flash)
	hit_t += delta
	_update_bar(delta)

	# Weit weg: Animation seltener berechnen (spart Zeit bei vielen Gegnern)
	var step := 1
	var cam := get_viewport().get_camera_3d()
	if cam:
		var d2 := global_position.distance_squared_to(cam.global_position)
		if d2 > 4900.0:
			step = 4
		elif d2 > 1225.0:
			step = 2
	anim_acc += delta
	if step > 1 and (Engine.get_process_frames() + get_instance_id()) % step != 0:
		return
	var dt := anim_acc
	anim_acc = 0.0

	var hv := Vector2(velocity.x, velocity.z).length()
	var want := "idle"
	var spd := 1.0
	if state == ATTACK:
		want = attack_clip
		spd = ATTACK_SPEED[attack_clip]
	elif state != STAGGER and hv > 0.6:
		want = "run" if hv > 3.0 else "walk"
		spd = clampf(hv / (HM.RUN_REF if want == "run" else HM.WALK_REF), 0.5, 1.6)
	if want != cur:
		cur = want
		ap.play("h/" + want, 0.15 if state == ATTACK else 0.25)
	ap.speed_scale = spd
	ap.advance(dt)
	if hit_t < 0.5:
		_flinch()


func _update_bar(delta: float) -> void:
	bar_show = maxf(bar_show - delta, 0.0)
	var near := target != null and global_position.distance_squared_to(target.global_position) < 196.0
	var want := 1.0 if bar_show > 0.0 else (0.55 if near else 0.0)
	var a := move_toward(bar_alpha, want, delta * 4.0)
	if a != bar_alpha:
		bar_alpha = a
		bar.set_instance_shader_parameter("alpha", a)
		bar.visible = a > 0.01
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	if bar_trail != frac:
		trail_wait -= delta
		if trail_wait <= 0.0:
			bar_trail = maxf(frac, bar_trail - delta * 0.7)
		bar.set_instance_shader_parameter("trail", bar_trail)
	if flash > 0.0 or bar_alpha > 0.0:
		bar.set_instance_shader_parameter("flash", flash)


# Dreht einen Knochen um eine Achse im Skelettraum (nach der Animation), "base" = Ausgangsdrehung des Knochens
func _bend(bone: int, axis: Vector3, ang: float, base: Quaternion) -> void:
	var par := skel.get_bone_parent(bone)
	var pg: Basis = skel.get_bone_global_pose(par).basis if par >= 0 else Basis.IDENTITY
	var g := Basis(axis, ang) * (pg * Basis(base))
	skel.set_bone_pose_rotation(bone, (pg.inverse() * g).get_rotation_quaternion())


# Treffer-Zucken: Oberkörper und Kopf schnappen vom Treffer weg und federn zurück
func _flinch() -> void:
	var a: float
	if hit_t < 0.06:
		a = hit_t / 0.06
	else:
		a = exp(-(hit_t - 0.06) * 6.0)
	a *= hit_amp
	if a < 0.01:
		return
	var d: Vector3 = (skel.global_transform.basis.inverse() * push).normalized()
	var axis := Vector3.UP.cross(d)
	if axis.length() < 0.01:
		return
	axis = axis.normalized()
	for fb in FLINCH_BONES:
		var i := skel.find_bone(fb[0])
		_bend(i, axis, a * fb[1] * 2.0, skel.get_bone_pose_rotation(i))
	pivot.position = Vector3(0, -0.04 * a, 0) + push * 0.03 * a


# --- Tod: umfallen wie eine Gummipuppe (ohne Physik, nur Drehungen) -------

func _process_death(delta: float) -> void:
	death_t += delta
	var t := death_t
	var u := clampf(t / 0.8, 0.0, 1.0)
	var ang := 1.5 * u * u
	if t > 0.8:
		ang -= 0.06 * exp(-(t - 0.8) * 12.0) * absf(sin((t - 0.8) * 22.0))  # kurzes Nachfedern am Boden
	var axis := Vector3.UP.cross(push).normalized()
	pivot.basis = Basis(axis, ang)
	var sink := smoothstep(2.4, 3.2, t) * 0.45
	pivot.position = Vector3(0, 0.15 * sin(ang) - sink, 0) + push * (0.45 * u)
	if t > 0.78 and not puffed:
		puffed = true
		VFX.death_puff(get_parent(), global_position + push * 1.0)
	if t > 3.2:
		queue_free()
		return
	if t > 1.3:
		return  # liegt still, nichts mehr zu rechnen
	var d: Vector3 = (skel.global_transform.basis.inverse() * push).normalized()
	var ax := Vector3.UP.cross(d).normalized()
	var a_hit := smoothstep(0.0, 0.2, t)
	var a_knee := smoothstep(0.05, 0.55, t)
	var a_arm := smoothstep(0.15, 0.8, t)
	var a_flat := smoothstep(0.55, 1.0, t)
	# Wirbelsäule: erst nach hinten durchgebogen, dann locker
	var arch := 0.55 * a_hit * (1.0 - 0.75 * a_flat)
	var names := DEATH_BONES
	for n in range(names.size()):
		var i := skel.find_bone(names[n])
		var base: Quaternion = snap[i]
		var nm: String = names[n]
		if nm.ends_with("Spine") or nm.ends_with("Spine1") or nm.ends_with("Spine2"):
			_bend(i, ax, arch * 0.4, base)
		elif nm.ends_with("Neck") or nm.ends_with("Head"):
			_bend(i, ax, (0.25 * a_hit + 0.2 * a_flat) , base)
		elif "Arm" in nm:
			var side := 0 if "Left" in nm else 1
			var rest: Quaternion = skel.get_bone_rest(i).basis.get_rotation_quaternion()
			skel.set_bone_pose_rotation(i, base.slerp(rest, a_arm * arm_k[side]))
		elif nm.ends_with("UpLeg"):
			var side2 := 0 if "Left" in nm else 1
			_bend(i, Vector3.RIGHT, -0.5 * a_knee * leg_k[side2], base)
		elif nm.ends_with("Leg"):
			var side3 := 0 if "Left" in nm else 1
			_bend(i, Vector3.RIGHT, 0.95 * a_knee * leg_k[side3], base)
