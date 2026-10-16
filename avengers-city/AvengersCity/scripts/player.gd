extends CharacterBody3D
# Spielfigur: laufen, sprinten, springen, Heldenwechsel. Die Figuren bestehen aus einfachen Formen.

const U = preload("res://scripts/util.gd")
const VFX = preload("res://scripts/vfx.gd")
const HeroModel = preload("res://scripts/hero_model.gd")
const MixamoModel = preload("res://scripts/mixamo_model.gd")
const ArmPose = preload("res://scripts/arm_pose.gd")

var HEROES := [
	{"name": "Captain America", "suit": Color(0.10, 0.26, 0.72), "accent": Color(0.80, 0.10, 0.14), "trim": Color(0.95, 0.95, 0.95), "scale": 1.0},
	{"name": "Iron Man", "suit": Color(0.66, 0.08, 0.10), "accent": Color(0.90, 0.70, 0.22), "trim": Color(0.95, 0.80, 0.30), "scale": 1.02},
	{"name": "Thor", "suit": Color(0.26, 0.28, 0.34), "accent": Color(0.55, 0.38, 0.20), "trim": Color(0.72, 0.74, 0.80), "scale": 1.10},
]

const USE_REAL_BODY := false
const USE_MIXAMO := true

const JUMP_V := 8.5  # Absprunggeschwindigkeit (m/s)
const GRAVITY := 26.0
const JUMP_ANTIC := 2.4  # Tempo des Hockens vor dem Absprung
const JUMP_WAIT := 0.12  # so lange dauert das Hocken (Notfall-Zeit, falls die Animation nicht läuft)
const AIR_DEBOUNCE := 0.08  # so lange in der Luft, bevor die Luft-Animation startet
const HARD_FALL := 15.0  # ab dieser Fallgeschwindigkeit: harte Landung
const GROUND_ACCEL := 60.0

# Angriffe: Mit "clip" läuft ein Mixamo-Ausschnitt (Treffer-Bild und Dauer kommen aus dem Clip, "speed" = Tempo).
# Ohne "clip" zeigt ein Arm per Code (arm_pose.gd). hit/len (Sekunden) gelten für diese Code-Angriffe und für die Würfel-Figur.
const ATK := {
	"punch": {"clip": "punch", "speed": 2.2, "dmg": 15.0, "reach": 2.4, "arc": 0.3, "hit": 0.05, "len": 0.45},
	"hammer": {"clip": "hammer", "speed": 2.2, "dmg": 20.0, "reach": 3.2, "arc": 0.0, "hit": 0.05, "len": 0.45},
	"swing": {"dmg": 20.0, "reach": 3.2, "arc": 0.0, "hit": 0.17, "len": 0.5},
	"throw": {"hit": 0.22, "len": 0.5},
	"bolt": {"hit": 0.30, "len": 0.62},
}

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
var punch_t := 0.0  # nur für die Würfel-Figur
var arm_shield: Node3D
var shield: Node3D
var shield_state := 0  # 0 = am Arm, 1 = fliegt weg, 2 = kommt zurück
var shield_t := 0.0
var shield_dir := Vector3.ZERO
var shield_hit: Array = []
var shots: Array = []
var shoot_cd := 0.0
var shoot_hold := 0.0  # Iron Man: so lange bleibt der Arm nach dem letzten Schuss oben
var bolt_cd := 0.0
var fly_lock := false
var flying := false
var mx: Dictionary = {}
var mx_anim: AnimationPlayer
var mx_cur := ""
var aim: ArmPose  # Arm, der per Code gepostet wird (Captain: links, sonst rechts)
var rep_mat: StandardMaterial3D  # Iron Man: Repulsor in der Handfläche
var rep_light: OmniLight3D
var flash := 0.0
# Angriff und Sprung
var atk := ""  # läuft gerade: punch, hammer, swing, throw, bolt
var atk_t := 0.0
var atk_hit := false
var atk_next := ""  # zweiter Klick während des Angriffs: kommt direkt danach
var jump_t := -1.0  # >= 0: Hocken vor dem Absprung läuft
var air_t := 0.0
var air_spd := 1.0
var land_t := 0.0
var hard_t := 0.0
var was_floor := true
var last_vy := 0.0


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
	reset_states()


# Angriff, Sprung und Landung abbrechen (Heldenwechsel, Auto, Neustart)
func reset_states() -> void:
	atk = ""
	atk_next = ""
	jump_t = -1.0
	land_t = 0.0
	hard_t = 0.0
	air_t = 0.0
	air_spd = 1.0
	shoot_hold = 0.0
	punch_t = 0.0
	was_floor = true


func build_model() -> void:
	if model:
		model.queue_free()
	model = Node3D.new()
	add_child(model)
	var h: Dictionary = HEROES[hero]
	model.scale = Vector3.ONE * float(h["scale"])
	legs.clear()
	arms.clear()
	mx = {}
	mx_anim = null
	mx_cur = ""
	aim = null
	rep_mat = null
	rep_light = null
	reset_states()

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

	if USE_MIXAMO and MixamoModel.available():
		build_mixamo(h)
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
		U.cyl(arm_shield, 0.3, 0.05, Vector3(-0.05, -0.5, -0.2), accent, Vector3(90, 0, 0))
		U.cyl(arm_shield, 0.27, 0.06, Vector3(-0.05, -0.5, -0.22), trim, Vector3(90, 0, 0))
		U.cyl(arm_shield, 0.17, 0.07, Vector3(-0.05, -0.5, -0.24), suit, Vector3(90, 0, 0))


func face_camera() -> void:
	model.rotation.y = yaw


# Iron Man schießt aus der Hand (Zielpose: Arm zeigt zum Fadenkreuz-Punkt)
func shoot() -> void:
	shoot_cd = 0.25
	flash = 1.0
	if mx_anim == null:
		face_camera()
		punch_t = 0.35
	# Zielpunkt aus der Bildmitte (Fadenkreuz)
	var cam_fwd: Vector3 = -cam.global_transform.basis.z
	var target := aim_target()
	var origin := global_position + Vector3(0, 1.5, 0)
	if aim:
		origin = aim.hand_pos()
	var dir := (target - origin).normalized()
	if dir.dot(cam_fwd) < 0.5:
		dir = cam_fwd  # Ziel ist hinter oder neben der Hand: einfach geradeaus
	origin += dir * 0.2
	var b: Node3D = VFX.repulsor_shot(get_parent())
	b.global_position = origin
	shots.append({"node": b, "dir": dir, "t": 0.0, "fresh": true})


# Der Punkt, auf den das Fadenkreuz zeigt
func aim_target() -> Vector3:
	var cam_fwd: Vector3 = -cam.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + cam_fwd * 200.0)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if hit else cam.global_position + cam_fwd * 200.0


func update_shots(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	for s in shots.duplicate():
		if s["fresh"]:
			s["fresh"] = false  # im ersten Bild bleibt der Schuss in der Hand
			continue
		var b: Node3D = s["node"]
		var from := b.global_position
		var to: Vector3 = from + s["dir"] * 45.0 * delta
		s["t"] += delta
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.exclude = [get_rid()]
		var r := space.intersect_ray(q)
		if r:
			VFX.impact(get_parent(), r["position"], r["normal"])
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


# ---------- Angriffe ----------

# Läuft gerade ein Angriff als Mixamo-Clip (Ganzkörper)?
func clip_attack() -> bool:
	return mx_anim != null and atk != "" and ATK[atk].has("clip")


func can_attack(kind: String) -> bool:
	if kind == "throw":
		return shield_state == 0
	if kind == "bolt":
		return bolt_cd <= 0.0
	return true


func read_attack_input() -> void:
	var want := ""
	if hero == 0:
		if Input.is_action_just_pressed("attack"):
			want = "punch"
		elif Input.is_action_just_pressed("throw"):
			want = "throw"
	elif hero == 2:
		if Input.is_action_just_pressed("attack"):
			want = "swing" if flying else "hammer"
		elif Input.is_action_just_pressed("throw"):
			want = "bolt"
	if want == "" or not can_attack(want):
		return
	if atk == "":
		start_attack(want)
	elif atk_hit:
		atk_next = want  # zweiter Klick nach dem Treffer: kommt gleich danach (vorher wird er ignoriert)


func atk_hit_t(kind: String) -> float:
	var a: Dictionary = ATK[kind]
	if mx_anim and a.has("clip"):
		return float(MixamoModel.HITS[a["clip"]]) / float(a["speed"])
	return a["hit"]


func atk_len(kind: String) -> float:
	var a: Dictionary = ATK[kind]
	if mx_anim and a.has("clip"):
		return mx_anim.get_animation("h/" + String(a["clip"])).length / float(a["speed"])
	return a["len"]


func start_attack(kind: String) -> void:
	var a: Dictionary = ATK[kind]
	atk = kind
	atk_t = 0.0
	atk_hit = false
	atk_next = ""
	punch_t = atk_len(kind)
	if kind == "bolt":
		bolt_cd = 1.5
	if mx_anim == null:
		face_camera()
	elif a.has("clip"):
		# Clip von vorn starten (auch wenn derselbe Clip eben erst lief)
		mx_anim.play("h/" + String(a["clip"]), 0.05)
		mx_anim.seek(0.0)
		mx_anim.speed_scale = a["speed"]
		mx_cur = a["clip"]


func update_attack(delta: float) -> void:
	if atk == "":
		return
	atk_t += delta
	var a: Dictionary = ATK[atk]
	if not atk_hit:
		var due := atk_t >= atk_hit_t(atk)
		if mx_anim and a.has("clip"):
			# Schaden genau im Treffer-Bild des Clips (Notfall: nach kurzer Zeit trotzdem)
			var in_clip := mx_anim.current_animation == "h/" + String(a["clip"])
			var pos := mx_anim.current_animation_position + 0.5 * mx_anim.speed_scale * delta  # halber Schritt Vorlauf: näher am Treffer-Bild
			due = (in_clip and pos >= float(MixamoModel.HITS[a["clip"]])) or atk_t > atk_hit_t(atk) + 0.1
		if due:
			atk_hit = true
			attack_hit(atk)
	if atk_t >= atk_len(atk):
		var nxt := atk_next
		atk = ""
		atk_next = ""
		if nxt != "" and can_attack(nxt):
			start_attack(nxt)


func attack_hit(kind: String) -> void:
	var a: Dictionary = ATK[kind]
	if kind == "throw":
		throw_shield()
	elif kind == "bolt":
		lightning()
	else:
		hit_enemies(a["dmg"], a["reach"], a["arc"])


# Gegner vor dem Helden (in Blickrichtung der Kamera) bekommen Schaden
func hit_enemies(dmg: float, reach: float, arc: float) -> void:
	var fwd: Vector3 = -yaw_pivot.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	for e in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		if to.length() < reach and to.normalized().dot(fwd) > arc:
			e.hit(dmg, global_position)
			if hero == 2:
				VFX.hammer_impact(get_parent(), e.global_position + Vector3(0, 1.0, 0))


# Thor: Blitz auf den Gegner, der am besten im Blickfeld liegt (oder auf einen Punkt vor ihm)
func lightning() -> void:
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
	VFX.lightning_bolt(get_parent(), spot)


func throw_shield() -> void:
	shield_state = 1
	shield_t = 0.0
	shield_hit.clear()
	shield_dir = -yaw_pivot.global_transform.basis.z
	shield_dir.y = 0.0
	shield_dir = shield_dir.normalized()
	if arm_shield:
		arm_shield.visible = false
	shield = Node3D.new()
	MixamoModel.flat_shield(shield)  # gleiches Aussehen wie am Arm
	get_parent().add_child(shield)
	# Der Schild startet in der Hand, die ihn wirft
	var from := global_position + Vector3(0, 1.3, 0) + shield_dir
	if aim:
		from = aim.hand_pos() + shield_dir * 0.3
	shield.global_position = from
	VFX.shield_trail(shield)


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
			VFX.shield_impact(get_parent(), shield.global_position)


func _unhandled_input(event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if active and mm and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= mm.relative.x * 0.0025
		pitch = clamp(pitch - mm.relative.y * 0.0025, -1.1, 0.5)


# Körper dreht sich: beim Angriff (und beim Zielen im Stehen) zur Kamera, sonst in Laufrichtung
func turn_model(delta: float, dir: Vector3) -> void:
	var slow := Vector2(velocity.x, velocity.z).length() < 1.5
	var to_cam := atk != "" or (hero == 1 and shoot_hold > 0.0 and (flying or slow))
	if to_cam:
		model.rotation.y = lerp_angle(model.rotation.y, yaw, clampf(25.0 * delta, 0.0, 1.0))
	elif dir.length() > 0.05:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-dir.x, -dir.z), clampf(12.0 * delta, 0.0, 1.0))


func launch() -> void:
	velocity.y = JUMP_V
	jump_t = -1.0
	air_t = AIR_DEBOUNCE
	# Die Luftphase des Clips (Absprung bis Aufsetzen) dauert genau so lange wie der Flug
	var pos: float = MixamoModel.JUMP_TAKEOFF
	if mx_anim and mx_cur == "jump":
		pos = mx_anim.current_animation_position
	air_spd = clampf((MixamoModel.JUMP_TOUCH - pos) / (2.0 * JUMP_V / GRAVITY), 0.3, 2.0)


func landed(impact: float) -> void:
	if air_t < 0.2:
		return
	if impact < -HARD_FALL:
		hard_t = 0.4
	elif Vector2(velocity.x, velocity.z).length() < 3.0:
		land_t = 0.24


func _physics_process(delta: float) -> void:
	yaw_pivot.rotation.y = yaw
	pitch_pivot.rotation.x = pitch
	if not active:
		return
	punch_t = maxf(punch_t - delta, 0.0)
	land_t = maxf(land_t - delta, 0.0)
	hard_t = maxf(hard_t - delta, 0.0)
	shoot_hold = maxf(shoot_hold - delta, 0.0)
	flash = maxf(flash - delta * 6.0, 0.0)
	if global_position.y < -20.0:
		respawn()

	# Aufsetzen erkennen (mit der Fallgeschwindigkeit aus dem letzten Schritt)
	var on_floor := is_on_floor()
	if on_floor and not was_floor:
		landed(last_vy)
	was_floor = on_floor
	if on_floor:
		air_t = 0.0
		air_spd = 1.0
	else:
		air_t += delta

	read_attack_input()
	update_attack(delta)
	if hero == 2:
		bolt_cd = maxf(bolt_cd - delta, 0.0)
	if shield_state != 0:
		update_shield(delta)
	shoot_cd = maxf(shoot_cd - delta, 0.0)
	if hero == 1 and Input.is_action_pressed("attack") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		shoot_hold = 0.5
		# Erst schießen, wenn der Arm oben ist
		if shoot_cd <= 0.0 and (aim == null or aim.weight >= 0.85):
			shoot()
	if not shots.is_empty():
		update_shots(delta)

	# Iron Man: Leertaste in der Luft = schweben, WASD fliegt in Blickrichtung.
	# Nach der Landung (Boden, Dach) muss die Leertaste erst losgelassen werden.
	if is_on_floor() or not Input.is_action_pressed("jump"):
		fly_lock = is_on_floor() and Input.is_action_pressed("jump")
	flying = (hero == 1 or hero == 2) and not is_on_floor() and not fly_lock and Input.is_action_pressed("jump")
	if flying:
		jump_t = -1.0
		var fi := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var fdir: Vector3 = cam.global_transform.basis * Vector3(fi.x, 0.0, fi.y)
		var fspd := 24.0 if Input.is_action_pressed("sprint") else 14.0
		var want := fdir.normalized() * fspd if fi.length() > 0.05 else Vector3.ZERO
		if Input.is_action_pressed("descend"):
			want.y = -8.0
		velocity = velocity.move_toward(want, 50.0 * delta)
		if fi.length() > 0.05:
			turn_model(delta, fdir)
		else:
			turn_model(delta, Vector3.ZERO)
		last_vy = velocity.y
		move_and_slide()
		animate(delta)
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir: Vector3 = yaw_pivot.global_transform.basis * Vector3(inp.x, 0.0, inp.y)
	dir.y = 0.0
	var spd := 10.0 if Input.is_action_pressed("sprint") else 6.0
	# Schlag-Clips und harte Landungen bremsen am Boden
	if is_on_floor() and (hard_t > 0.0 or clip_attack()):
		spd *= 0.3
	if dir.length() > 0.05:
		dir = dir.normalized()
		var wantv := Vector2(dir.x, dir.z) * spd
		if is_on_floor():
			# am Boden Gas geben statt sofort Vollgas, damit die Laufanimation mitkommt
			var hv := Vector2(velocity.x, velocity.z).move_toward(wantv, GROUND_ACCEL * delta)
			velocity.x = hv.x
			velocity.z = hv.y
		else:
			velocity.x = wantv.x
			velocity.z = wantv.y
	else:
		velocity.x = move_toward(velocity.x, 0.0, 60.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 60.0 * delta)
	turn_model(delta, dir)

	# Sprung: erst kurz in die Hocke (Animation), Absprung genau im Absprung-Bild des Clips
	if is_on_floor() and Input.is_action_just_pressed("jump") and jump_t < 0.0:
		if mx_anim == null or clip_attack():
			launch()
		else:
			jump_t = 0.0
			mx_cur = ""  # Sprung-Clip immer von vorn starten
	if jump_t >= 0.0:
		jump_t += delta
		var ready := clip_attack() or jump_t > JUMP_WAIT + 0.1
		if mx_anim and mx_cur == "jump" and mx_anim.current_animation_position >= MixamoModel.JUMP_TAKEOFF:
			ready = true
		if not is_on_floor():
			jump_t = -1.0
		elif ready:
			launch()
	last_vy = velocity.y
	move_and_slide()
	animate(delta)


func animate(delta: float) -> void:
	update_arm(delta)
	# Flugpose: nach vorne gelehnt, Arme nach vorn, Beine gestreckt
	var lean := 0.0
	if flying and mx_anim:
		# Der Flug-Clip liegt schon waagerecht: nur beim Steigen/Sinken leicht neigen
		lean = clampf(velocity.y / 14.0, -1.0, 1.0) * 0.5
	elif flying:
		lean = (-1.2 if hero == 1 else -0.9) * clampf(velocity.length() / 14.0, 0.0, 1.0)
	model.rotation.x = lerpf(model.rotation.x, lean, clampf(8.0 * delta, 0.0, 1.0))
	# Drehpunkt in Hüfthöhe statt an den Füßen
	var c := Vector3(0, 1.0, 0)
	model.position = Basis(Vector3.UP, model.rotation.y) * (c - Basis(Vector3.RIGHT, model.rotation.x) * c)
	if mx_anim:
		animate_mx(delta)
		return
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


# Mixamo-Figur: Körper, Schild und Hammer. Die Animationen steuert animate_mx().
func build_mixamo(h: Dictionary) -> void:
	mx = MixamoModel.build(hero, h, model)
	mx_anim = mx["anim"]
	mx_anim.play("h/idle")
	mx_cur = "idle"
	mx_anim.advance(0.0)  # gleich die Idle-Pose zeigen (nicht ein Bild lang die T-Pose)
	aim = ArmPose.new(mx["skel"], "Left" if hero == 0 else "Right")
	mx_anim.mixer_applied.connect(aim.apply)  # Arm-Posing läuft direkt nach der Animation
	if hero == 0:
		arm_shield = MixamoModel.arm_shield(mx)  # Schild-Aussehen: hero_parts.gd
		arm_shield.visible = shield_state == 0
	elif hero == 1:
		# Repulsor in der Handfläche (Knochen: +Y zu den Fingern, +Z aus der Handfläche)
		rep_mat = U.glow(Color(0.6, 0.95, 1.0), 1.0)
		U.sphere(mx["rhand"], 0.05, Vector3(0, 0.08, 0.035), rep_mat)
		rep_light = OmniLight3D.new()
		rep_light.light_color = Color(0.6, 0.95, 1.0)
		rep_light.omni_range = 4.0
		rep_light.light_energy = 0.0
		rep_light.position = Vector3(0, 0.1, 0.1)
		mx["rhand"].add_child(rep_light)


# Arm und Oberkörper per Code (nach der Animation): Iron Man zielt, Captain wirft, Thor ruft den Blitz
func update_arm(delta: float) -> void:
	if aim == null:
		return
	var w := 0.0
	var tw := 0.0
	aim.palm = false
	if hero == 1:
		var want := 1.0 if shoot_hold > 0.0 else 0.0
		w = move_toward(aim.weight, want, (12.0 if want > 0.0 else 7.0) * delta)
		if w > 0.0:
			aim.point = aim_target()
			aim.palm = true
		var glow := flash + w * 0.4
		if rep_mat:
			rep_mat.emission_energy_multiplier = 0.6 + glow * 3.0
		if rep_light:
			rep_light.light_energy = glow * 0.8
	elif atk == "throw" or atk == "bolt" or atk == "swing":
		var pose := arm_timeline(atk, atk_t)
		w = pose["w"]
		tw = pose["twist"] * w
		var d: Vector3 = (model.global_transform.basis * (pose["dir"] as Vector3)).normalized()
		aim.point = aim.shoulder_pos() + d * 5.0
	aim.weight = w
	aim.twist = tw


# Arm-Bewegung der Code-Angriffe. Richtungen im Modellraum (vorn = -Z, rechts = +X).
# Gibt Gewicht (0..1), Zielrichtung und Oberkörper-Drehung zur Zeit u (Sekunden) zurück.
func arm_timeline(kind: String, u: float) -> Dictionary:
	var w := 0.0
	var dir := Vector3.FORWARD
	var twist := 0.0
	if kind == "throw":
		# links ausholen (Arm nach hinten, Oberkörper dreht mit), dann nach vorn schleudern
		var back := Vector3(-0.75, 0.25, 0.6).normalized()
		var front := Vector3(-0.1, 0.12, -1.0).normalized()
		var t := smoothstep(0.10, 0.22, u)
		dir = back.slerp(front, t)
		twist = lerpf(0.5, -0.3, t)
		w = minf(clampf(u / 0.12, 0.0, 1.0), clampf((ATK[kind]["len"] - u) / 0.16, 0.0, 1.0))
	elif kind == "bolt":
		# Hammer nach oben reißen, Blitz, dann nach vorn herunter
		var fwd := Vector3(0.3, 0.2, -1.0).normalized()
		var up := Vector3(0.15, 1.0, -0.2).normalized()
		var down := Vector3(0.1, 0.35, -1.0).normalized()
		if u < 0.3:
			dir = fwd.slerp(up, smoothstep(0.0, 0.2, u))
		else:
			dir = up.slerp(down, smoothstep(0.3, 0.42, u))
		w = minf(clampf(u / 0.18, 0.0, 1.0), clampf((ATK[kind]["len"] - u) / 0.16, 0.0, 1.0))
	else:
		# Hammerschlag im Flug: von hinten oben nach vorn unten
		var up_back := Vector3(0.5, 0.9, 0.4).normalized()
		var strike := Vector3(-0.25, -0.3, -1.0).normalized()
		dir = up_back.slerp(strike, smoothstep(0.0, 0.17, u))
		w = minf(clampf(u / 0.06, 0.0, 1.0), clampf((ATK[kind]["len"] - u) / 0.15, 0.0, 1.0))
	return {"w": w, "dir": dir, "twist": twist}


# Wählt die Animation. Reihenfolge: Angriff, Fliegen, Absprung, Luft, Landung, Laufen.
func animate_mx(delta: float) -> void:
	var sp := Vector2(velocity.x, velocity.z).length()
	var want := ""
	var spd := 1.0
	var blend := 0.15
	var from := 0.0
	var loco := false
	if atk != "" and ATK[atk].has("clip"):
		want = ATK[atk]["clip"]
		spd = ATK[atk]["speed"]
		blend = 0.05
	elif flying:
		# Hysterese: schnell fliegen ab 4,5 m/s, zurück zum Schweben unter 2,5 m/s
		want = "fly" if sp > (2.5 if mx_cur == "fly" else 4.5) else "float"
		blend = 0.3
	elif jump_t >= 0.0:
		want = "jump"
		spd = JUMP_ANTIC
		from = 0.16 if sp > 4.0 else 0.0  # beim Anlauf-Sprung die Hocke fast überspringen
		blend = 0.08
	elif air_t >= AIR_DEBOUNCE:
		want = "jump"
		spd = air_spd
		from = MixamoModel.JUMP_FALL  # ohne Absprung (Sturz): gleich die Fallpose
		blend = 0.2
	elif hard_t > 0.0:
		want = "hard"
		spd = 1.8
		blend = 0.05
	elif land_t > 0.0:
		want = "land"
		spd = 2.0
		blend = 0.05
		if sp > 3.0 and land_t < 0.16:
			land_t = 0.0  # losgelaufen: Landung nicht zu Ende spielen
	if want == "":
		loco = true
		var cur := mx_cur
		if sp < (0.3 if cur == "walk" or cur == "run" else 0.6):
			want = "idle"
		elif sp > (3.0 if cur == "run" else 3.4):
			want = "run"
			spd = clampf(sp / MixamoModel.RUN_SPEED, 0.5, 2.2)
			from = 0.17  # nach der Landung zuerst der linke Fuß (er setzt im Sprung-Clip zuerst auf)
		else:
			want = "walk"
			spd = clampf(sp / MixamoModel.WALK_SPEED, 0.5, 2.2)
			from = 0.30
	play_mx(want, blend, spd, from, loco, delta)


# Spielt einen Clip (weicher Übergang). Läuft schon derselbe Clip, bleibt er einfach an.
func play_mx(want: String, blend: float, spd: float, from: float, loco: bool, delta: float) -> void:
	var looped := want in MixamoModel.LOOPS
	if mx_cur != want or (not mx_anim.is_playing() and (looped or want == "jump")):
		var old_pos := mx_anim.current_animation_position
		var old_len := 1.0
		if mx_anim.current_animation != "":
			old_len = mx_anim.current_animation_length
		var was_step := mx_cur == "walk" or mx_cur == "run"
		mx_anim.play("h/" + want, blend)
		if (want == "walk" or want == "run") and was_step:
			# Laufschritt nahtlos weiterführen: gleiche Stelle im Schrittzyklus
			mx_anim.seek(fposmod(old_pos / old_len, 1.0) * mx_anim.current_animation_length)
		elif from > 0.0:
			mx_anim.seek(from)
		mx_cur = want
		mx_anim.speed_scale = spd
	elif loco:
		mx_anim.speed_scale = lerpf(mx_anim.speed_scale, spd, clampf(14.0 * delta, 0.0, 1.0))
	else:
		mx_anim.speed_scale = spd
