extends Node
# Schildwurf von Captain America (nur Code, keine Mixamo-Animation):
#  - Wurf-Pose: Oberkörper dreht ein, der Schild-Arm holt aus, schnellt vor, schwingt nach; die Beine machen einen Schritt
#  - Das Schild löst sich genau im Release-Bild von der Hand und fliegt zum Fadenkreuz-Punkt (oder zum nächsten Gegner)
#  - Abpraller von Gegner zu Gegner (bis 3, ~12 m), Funken an Wänden, Rückkehr auf einem Bogen
#  - Fangen: Arm streckt sich, kleiner Ruck, das Schild rastet am Unterarm ein
# apply() läuft direkt nach dem Animations-Update (Signal mixer_applied) und überlagert die Pose (wie arm_pose.gd).
# Achsen im Skelettraum: +X = links der Figur, +Y = oben, +Z = vorn.

const VFX = preload("res://scripts/vfx.gd")
const MixamoModel = preload("res://scripts/mixamo_model.gd")

const T_REL := 0.32  # Release: so viele Sekunden nach dem Klick verlässt das Schild die Hand
const T_END := 0.95  # danach ist die Wurf-Pose ganz ausgeblendet
const RANGE := 26.0  # weiteste Entfernung des Wurfs
const SPEED_OUT := 34.0
const SPEED_BACK := 31.0
const BOUNCE_R := 12.0  # so weit springt das Schild zum nächsten Gegner
const MAX_HITS := 3
const DMG := 25.0
const HIT_R := 0.62
const AIM_CONE := 0.19  # Auto-Zielen: Gegner bis ~11 Grad neben dem Fadenkreuz
const BONES := ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
	"RightShoulder", "RightArm", "RightForeArm", "RightHand", "LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot"]

# Schlüsselbilder [Zeit, Wert] (weich verbunden). Brustrichtung: X links, Y oben, Z vorn.
# Brust: Drehung (+ = linke Schulter nach hinten, relativ zum Ziel), Beugen (+ = vor), Neigen (+ = nach rechts)
const PSI := [[0.0, 0.0], [0.09, 0.40], [0.19, 0.95], [0.25, 0.60], [0.32, -0.10], [0.40, -0.42], [0.50, -0.55], [0.65, -0.46], [0.95, -0.25]]
const PIT := [[0.0, 0.0], [0.19, -0.14], [0.32, 0.12], [0.48, 0.24], [0.75, 0.10], [0.95, 0.0]]
const ROL := [[0.0, 0.0], [0.19, -0.12], [0.32, 0.10], [0.50, 0.16], [0.95, 0.05]]
# linker Arm: Oberarm, Unterarm, Hand (Richtungen in der Brust-Ebene)
const L1 := [[0.0, Vector3(1.0, -0.20, 0.05)], [0.19, Vector3(1.0, -0.20, 0.05)], [0.25, Vector3(0.85, -0.10, 0.45)], [0.32, Vector3(0.40, 0.04, 0.92)],
	[0.40, Vector3(0.0, -0.08, 1.0)], [0.50, Vector3(-0.38, -0.30, 0.88)], [0.95, Vector3(-0.38, -0.30, 0.88)]]
const L2 := [[0.0, Vector3(0.45, -0.10, 0.85)], [0.20, Vector3(0.45, -0.10, 0.85)], [0.27, Vector3(0.50, -0.05, 0.85)], [0.335, Vector3(0.30, 0.05, 0.95)],
	[0.43, Vector3(-0.30, -0.05, 0.95)], [0.52, Vector3(-0.80, -0.10, 0.60)], [0.95, Vector3(-0.80, -0.10, 0.60)]]
const L3 := [[0.0, Vector3(0.40, -0.25, 0.88)], [0.20, Vector3(0.40, -0.25, 0.88)], [0.28, Vector3(0.45, -0.15, 0.88)], [0.34, Vector3(0.20, 0.0, 0.98)],
	[0.44, Vector3(-0.40, -0.10, 0.92)], [0.53, Vector3(-0.85, -0.20, 0.50)], [0.95, Vector3(-0.85, -0.20, 0.50)]]
# rechter Arm: Gegengewicht
const R1 := [[0.0, Vector3(-0.45, -0.55, 0.70)], [0.19, Vector3(-0.45, -0.55, 0.70)], [0.32, Vector3(-0.35, -0.85, -0.40)], [0.50, Vector3(-0.30, -0.90, 0.20)], [0.95, Vector3(-0.30, -0.90, 0.20)]]
const R2 := [[0.0, Vector3(-0.10, 0.20, 0.95)], [0.19, Vector3(-0.10, 0.20, 0.95)], [0.32, Vector3(0.10, 0.60, 0.50)], [0.50, Vector3(0.0, 0.30, 0.90)], [0.95, Vector3(0.0, 0.30, 0.90)]]
# Hüfte (Skelettraum, Meter): Absenken, Vorschub zum Ziel, Verlagerung zur Seite
const HDROP := [[0.0, 0.0], [0.19, -0.07], [0.32, -0.05], [0.50, -0.05], [0.80, -0.02], [0.95, 0.0]]
const HFWD := [[0.0, 0.0], [0.19, -0.05], [0.32, 0.10], [0.50, 0.10], [0.95, 0.0]]
const HSIDE := [[0.0, 0.0], [0.19, 0.04], [0.32, -0.02], [0.50, -0.03], [0.95, 0.0]]

var pl  # Spieler (player.gd)
var skel: Skeleton3D
var mount: Node3D  # Schild am Arm
var bi := {}  # Knochenname -> Index
var rest := {}  # Knochenname -> globale Ruhe-Drehung
var b0 := {}  # Knochenname -> globale Pose direkt nach der Animation
# Wurf-Pose
var throw_on := false
var released := false
var t := 0.0
var kill := 1.0  # sinkt auf 0, wenn ein anderer Angriff die Pose ablöst
var ks := 1.0  # 1 = Figur steht, 0 = läuft oder ist in der Luft
var aim_yaw := 0.0  # Ziel gegenüber der Körpervorderseite (links +)
var aim_pitch := 0.0
# Flug
var fly := 0  # 0 = am Arm, 1 = fliegt hinaus (auch Abpraller), 2 = kommt zurück
var shield: Node3D
var pos := Vector3.ZERO
var prev := Vector3.ZERO
var heading := Vector3.FORWARD
var fly_t := 0.0
var ret_t := 0.0
var pause := 0.0
var spin := 0.0
var bank := 0.0
var turn_rate := 0.0
var seg_p0 := Vector3.ZERO
var seg_tgt := Vector3.ZERO
var seg_en: Node3D
var seg_s := 0.0
var seg_bulge := Vector3.ZERO
var seg_h0 := Vector3.FORWARD
var hit_list: Array = []
var chain := 0
var wall_n := 0
var ret_n := 0
var eta := 9.0
# Fangen
var catch_t := -1.0  # >= 0: Schild ist gefangen, Zeit seit dem Fang
var catch_loc := Vector3(0.3, -0.1, 0.9)  # Richtung zum Schild in Brustkoordinaten
var catch_dir := Vector3.FORWARD  # Flugrichtung beim Fang (für den Ruck)


func setup(player, skeleton: Skeleton3D, arm_shield: Node3D) -> void:
	pl = player
	skel = skeleton
	mount = arm_shield
	if skel == null:
		return
	for n in BONES:
		var i := skel.find_bone("mixamorig_" + n)
		if i < 0:
			skel = null
			return
		bi[n] = i
		rest[n] = skel.get_bone_global_rest(i).basis.orthonormalized()


# Kann ein neuer Wurf starten?
func ready() -> bool:
	return fly == 0 and not throw_on and (catch_t < 0.0 or catch_t > 0.3)


# Alles abbrechen (Heldenwechsel, Auto, Neustart): Schild wieder an den Arm
func cancel() -> void:
	throw_on = false
	released = false
	fly = 0
	catch_t = -1.0
	if is_instance_valid(shield):
		shield.queue_free()
	shield = null
	if pl:
		pl.shield_state = 0
		pl.shield = null
	if is_instance_valid(mount):
		mount.visible = true


func _exit_tree() -> void:
	cancel()


# Notfall-Auslöser aus player.gd (falls das Bild-Update ausfällt)
func force_release() -> void:
	if throw_on and not released:
		release()


func _process(delta: float) -> void:
	if not is_instance_valid(pl):
		return
	delta = minf(delta, 0.05)
	if not pl.active:
		if throw_on or fly != 0 or catch_t >= 0.0:
			cancel()
		return
	if not throw_on and fly == 0 and pl.atk == "throw" and ready():
		begin()
	elif throw_on and not released and pl.atk != "throw":
		throw_on = false  # Wurf vor dem Release abgebrochen
	var hv := Vector2(pl.velocity.x, pl.velocity.z).length()
	var want_ks := (1.0 - smoothstep(0.8, 2.5, hv)) if pl.is_on_floor() else 0.0
	ks = move_toward(ks, want_ks, 6.0 * delta)
	if throw_on:
		t += delta
		if pl.atk != "" and pl.atk != "throw":
			kill = move_toward(kill, 0.0, delta / 0.1)  # Schlag unterbricht die Wurf-Pose schnell
		if not released:
			update_aim(delta)
			if t >= T_REL + 0.06:
				release()  # Notfall: apply() hat nicht ausgelöst
		if t >= T_END:
			throw_on = false
	if fly != 0:
		step_flight(delta)
	if catch_t >= 0.0:
		catch_t += delta
		if catch_t > 1.0:
			catch_t = -1.0


func begin() -> void:
	throw_on = true
	released = false
	t = 0.0
	kill = 1.0
	update_aim(1.0)


# Weich: Pose-Gewicht 0..1 über die Zeit
func env() -> float:
	if not throw_on:
		return 0.0
	return smoothstep(0.0, 0.14, t) * (1.0 - smoothstep(0.56, T_END - 0.03, t)) * kill


# Gewicht der Fang-Pose (Anflug und Nachwippen)
func catch_weight() -> float:
	if catch_t >= 0.0:
		return 1.0 - smoothstep(0.12, 0.60, catch_t)
	if fly == 2:
		return 1.0 - smoothstep(0.06, 0.34, eta)
	return 0.0


# ---------------------------------------------------------------- Ziel

func excl() -> Array[RID]:
	var ex: Array[RID] = [pl.get_rid()]
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is CollisionObject3D:
			ex.append(e.get_rid())
	return ex


# Strahl durch die Welt (ohne Spieler und Gegner)
func ray(a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.exclude = excl()
	return pl.get_world_3d().direct_space_state.intersect_ray(q)


func chest(e: Node3D) -> Vector3:
	return e.global_position + Vector3(0, 1.15, 0)


# Wohin geht der Wurf? Gegner nahe am Fadenkreuz werden angepeilt, sonst der Fadenkreuz-Punkt (höchstens RANGE weit).
func find_target(from: Vector3) -> Dictionary:
	var cam: Camera3D = pl.cam
	var cp := cam.global_position
	var cf: Vector3 = -cam.global_transform.basis.z
	var best: Node3D = null
	var best_a := AIM_CONE
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var c := chest(e)
		var to := c - cp
		var d := to.length()
		if d < 1.5 or from.distance_to(c) > RANGE:
			continue
		var a := cf.angle_to(to)
		if a < best_a and ray(from, c).is_empty():
			best_a = a
			best = e
	if best:
		return {"pos": chest(best), "enemy": best}
	var tp: Vector3 = pl.aim_target()
	var dv := tp - from
	if dv.length() < 1.5 or dv.normalized().dot(cf) < 0.35:
		tp = from + cf * RANGE
	elif dv.length() > RANGE:
		tp = from + dv.normalized() * RANGE
	return {"pos": tp, "enemy": null}


func chest_pos() -> Vector3:
	if skel:
		return skel.global_transform * gp("Spine2").origin
	return pl.global_position + Vector3(0, 1.35, 0)


# Gier und Neigung des Ziels gegenüber der Figur (für die Wurf-Pose)
func update_aim(delta: float) -> void:
	if skel == null:
		return
	var tg := find_target(chest_pos())
	var v: Vector3 = skel.global_transform.basis.inverse() * (tg["pos"] - chest_pos()).normalized()
	v = v.normalized()
	var wy := clampf(atan2(v.x, v.z), -1.6, 1.6)
	var wp := asin(clampf(v.y, -1.0, 1.0))
	var k := 1.0 if delta >= 1.0 else clampf(16.0 * delta, 0.0, 1.0)
	aim_yaw = lerp_angle(aim_yaw, wy, k)
	aim_pitch = lerpf(aim_pitch, wp, k)


# ---------------------------------------------------------------- Pose

static func hermite(k: Array, x: float) -> Variant:
	var n := k.size()
	if x <= k[0][0]:
		return k[0][1]
	if x >= k[n - 1][0]:
		return k[n - 1][1]
	var i := 1
	while k[i][0] < x:
		i += 1
	var a: Array = k[i - 1]
	var b: Array = k[i]
	var h: float = b[0] - a[0]
	var s: float = (x - a[0]) / h
	var ma = _tan(k, i - 1)
	var mb = _tan(k, i)
	var s2 := s * s
	var s3 := s2 * s
	return a[1] * (2.0 * s3 - 3.0 * s2 + 1.0) + ma * (h * (s3 - 2.0 * s2 + s)) + b[1] * (-2.0 * s3 + 3.0 * s2) + mb * (h * (s3 - s2))


static func _tan(k: Array, i: int) -> Variant:
	var p: Array = k[maxi(i - 1, 0)]
	var q: Array = k[mini(i + 1, k.size() - 1)]
	return (q[1] - p[1]) / maxf(q[0] - p[0], 0.0001)


static func kf(k: Array, x: float) -> float:
	return hermite(k, x)


static func kv(k: Array, x: float) -> Vector3:
	return (hermite(k, x) as Vector3).normalized()


# Drehung mit Knochenrichtung d und Handrücken zu hint (Ruhepose: Richtung +X, Handrücken +Y)
static func frame(d: Vector3, hint: Vector3) -> Basis:
	d = d.normalized()
	var u := hint - d * d.dot(hint)
	if u.length() < 0.05:
		u = Vector3(0, 0, 1) - d * d.z
		if u.length() < 0.05:
			u = Vector3(1, 0, 0) - d * d.x
	u = u.normalized()
	return Basis(d, u, d.cross(u))


func gp(n: String) -> Transform3D:
	return skel.get_bone_global_pose(bi[n])


# Setzt die globale Drehung eines Knochens (Gewicht w gegen die aktuelle Pose)
func put(n: String, nb: Basis, w: float = 1.0) -> void:
	var i: int = bi[n]
	var p := skel.get_bone_parent(i)
	var pb := skel.get_bone_global_pose(p).basis.orthonormalized() if p >= 0 else Basis.IDENTITY
	var q := (pb.inverse() * nb.orthonormalized()).orthonormalized().get_rotation_quaternion()
	if w < 0.999:
		q = skel.get_bone_pose_rotation(i).slerp(q, w)
	skel.set_bone_pose_rotation(i, q)


# Dreht den Knochen so, dass er zum Kindknochen in Richtung dir zeigt
func aim_bone(n: String, child: String, dir: Vector3) -> void:
	var g := gp(n)
	var cur := (gp(child).origin - g.origin).normalized()
	put(n, Basis(Quaternion(cur, dir.normalized())) * g.basis.orthonormalized())


# Brust-Drehung gegenüber der Ruhepose (für die Arme)
func chest_rot() -> Basis:
	return gp("Spine2").basis.orthonormalized() * (rest["Spine2"] as Basis).inverse()


# Obere Wirbelsäule: Gier / Beugen / Neigen verteilt auf drei Wirbel
func put_spine(yaw: float, pit: float, rol: float, w: float) -> void:
	var cum := {"Spine": 0.25, "Spine1": 0.6, "Spine2": 1.0}
	for n in cum:
		var c: float = cum[n]
		var rot := Basis(Vector3.UP, yaw * c) * Basis(Vector3.RIGHT, pit * c) * Basis(Vector3(0, 0, 1), rol * c)
		put(n, rot * (b0[n] as Transform3D).basis, w)


func put_clav(side: String, M: Basis, d1: Vector3, w: float) -> void:
	var r: Basis = rest[side + "Shoulder"]
	var rd := r.y
	var cd := (rd * 0.65 + d1.normalized() * 0.35).normalized()
	put(side + "Shoulder", M * Basis(Quaternion(rd, cd)) * r, w)


# Arm aus Richtungen (Brustkoordinaten): Oberarm d1, Unterarm d2, Hand d3, Handrücken zu hint
func put_arm(side: String, M: Basis, d1: Vector3, d2: Vector3, d3: Vector3, hint: Vector3, w: float) -> void:
	var fl := Basis.IDENTITY if side == "Left" else Basis(Vector3.UP, PI)
	put(side + "Arm", M * frame(d1, hint) * fl * (rest[side + "Arm"] as Basis), w)
	put(side + "ForeArm", M * frame(d2, hint) * fl * (rest[side + "ForeArm"] as Basis), w)
	put(side + "Hand", M * frame(d3, hint) * fl * (rest[side + "Hand"] as Basis), w)


# Zwei-Knochen-IK: Ellbogen (bzw. Knie) und Handgelenk (Knöchel) zu einem Zielpunkt
func ik2(root: Vector3, tgt: Vector3, l1: float, l2: float, pole: Vector3) -> Array:
	var to := tgt - root
	var dist := clampf(to.length(), 0.2, l1 + l2 - 0.003)
	var dir := to.normalized()
	var ca := clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0)
	var sa := sqrt(1.0 - ca * ca)
	var pv := pole - dir * pole.dot(dir)
	pv = pv.normalized() if pv.length() > 0.001 else Vector3(0, 0, 1)
	return [root + dir * (l1 * ca) + pv * (l1 * sa), root + dir * dist]


func snapshot() -> void:
	for n in BONES:
		b0[n] = gp(n)


# Wird nach jedem Animations-Update aufgerufen
func apply() -> void:
	if skel == null or not is_instance_valid(skel):
		return
	var w := env()
	var wc := catch_weight()
	var due := throw_on and not released and t >= T_REL
	if w < 0.002 and wc < 0.002 and not due:
		return
	snapshot()
	if wc > 0.002:
		pose_catch(wc)
	if w > 0.002:
		pose_throw(w)
	if due:
		release()


func pose_throw(w: float) -> void:
	var u := t
	var psi := kf(PSI, u)
	var pit := kf(PIT, u)
	var rol := kf(ROL, u)
	var kst := w * ks
	# Hüfte: Absenken, Vorschub, Verlagerung; dreht etwas vor der Brust
	var step_dir := Basis(Vector3.UP, aim_yaw) * Vector3(0, 0, 1)
	var side_dir := Basis(Vector3.UP, aim_yaw) * Vector3(1, 0, 0)
	var hoff := Vector3(0, kf(HDROP, u), 0) + step_dir * kf(HFWD, u) + side_dir * kf(HSIDE, u)
	var hips: Transform3D = b0["Hips"]
	skel.set_bone_pose_position(bi["Hips"], hips.origin + hoff * kst)
	put("Hips", Basis(Vector3.UP, 0.32 * kf(PSI, u + 0.03)) * hips.basis, w)
	# Wirbelsäule, Hals, Kopf (der Kopf schaut zum Ziel)
	put_spine(aim_yaw + psi, pit, rol, w)
	var hy := aim_yaw + 0.30 * psi
	put("Neck", Basis(Vector3.UP, hy * 0.5) * (b0["Neck"] as Transform3D).basis, w)
	put("Head", Basis(Vector3.UP, hy) * Basis(Vector3.RIGHT, -pit * 0.4) * (b0["Head"] as Transform3D).basis, w)
	# Arme
	var M := chest_rot()
	var hint := M.inverse() * Vector3.UP
	var pk := smoothstep(0.2, 0.32, u) * (1.0 - smoothstep(0.5, 0.75, u))
	var lift := Basis(Vector3.RIGHT, -aim_pitch * pk)
	var l1 := lift * kv(L1, u)
	put_clav("Left", M, l1, w)
	put_arm("Left", M, l1, lift * kv(L2, u), lift * kv(L3, u), hint, w)
	var r1 := kv(R1, u)
	put_clav("Right", M, r1, w)
	put_arm("Right", M, r1, kv(R2, u), kv(R2, u), hint, w)
	pose_legs(w, kst, u, step_dir)


# Beine: Schritt mit dem rechten Fuß zum Ziel, linker Fuß bleibt hinten (Ferse hoch). Nur im Stand (IK), sonst bleiben die Beine wie animiert.
func pose_legs(w: float, kst: float, u: float, step_dir: Vector3) -> void:
	if kst < 0.02:
		for n in ["LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot"]:
			put(n, (b0[n] as Transform3D).basis)
		return
	var fwd := smoothstep(0.07, 0.30, u)
	var back := smoothstep(0.62, 0.88, u)
	var sf := fwd - back
	var lf := sin(PI * fwd) * 0.11 + sin(PI * back) * 0.09
	var off_r := step_dir * (0.34 * sf) + Vector3(-0.05 * sf, lf, 0.0)
	var load_l := smoothstep(0.0, 0.2, u) * (1.0 - smoothstep(0.62, 0.9, u))
	var heel := smoothstep(0.24, 0.34, u) * (1.0 - smoothstep(0.5, 0.75, u))
	var off_l := -step_dir * (0.06 * load_l) + Vector3(0, 0.085 * heel, 0) + step_dir * (0.03 * heel)
	leg_ik("Left", (b0["LeftFoot"] as Transform3D).origin + off_l * kst, Basis(Vector3.RIGHT, 0.6 * heel * kst) * (b0["LeftFoot"] as Transform3D).basis)
	leg_ik("Right", (b0["RightFoot"] as Transform3D).origin + off_r * kst, (b0["RightFoot"] as Transform3D).basis)


func leg_ik(side: String, tgt: Vector3, fbasis: Basis) -> void:
	var up := side + "UpLeg"
	var kn := side + "Leg"
	var ft := side + "Foot"
	var hip := gp(up).origin
	var l1: float = (b0[kn] as Transform3D).origin.distance_to((b0[up] as Transform3D).origin)
	var l2: float = (b0[ft] as Transform3D).origin.distance_to((b0[kn] as Transform3D).origin)
	# Knierichtung wie in der Animation
	var ax0: Vector3 = ((b0[ft] as Transform3D).origin - (b0[up] as Transform3D).origin).normalized()
	var pole: Vector3 = (b0[kn] as Transform3D).origin - (b0[up] as Transform3D).origin
	pole = pole - ax0 * pole.dot(ax0)
	var r := ik2(hip, tgt, l1, l2, pole)
	aim_bone(up, kn, (r[0] as Vector3) - hip)
	aim_bone(kn, ft, (r[1] as Vector3) - (r[0] as Vector3))
	put(ft, fbasis)


# Fang-Pose: der linke Arm streckt sich zum Schild, beim Fang ein kleiner Ruck, dann zurück
func pose_catch(w: float) -> void:
	var sk_inv := skel.global_transform.affine_inverse()
	var k := 0.0
	if catch_t >= 0.0:
		k = exp(-7.0 * catch_t) * cos(28.0 * catch_t)
	# Oberkörper dreht leicht zum Schild und ruckt beim Fang
	var yaw_s := 0.0
	var dir_guess := (sk_inv * pos - (b0["LeftArm"] as Transform3D).origin).normalized() if catch_t < 0.0 else catch_loc
	yaw_s = clampf(atan2(dir_guess.x, dir_guess.z), -0.5, 0.5) * 0.4
	put_spine(yaw_s * w, 0.07 * k * w, 0.05 * k * w, w)
	var M := chest_rot()
	var hint := M.inverse() * Vector3.UP
	var fwd := M * Vector3(0, 0, 1)
	var dir: Vector3
	if catch_t < 0.0:
		dir = (sk_inv * pos - (b0["LeftArm"] as Transform3D).origin).normalized()
		var ang0 := fwd.angle_to(dir)
		if ang0 > 1.9:
			dir = fwd.slerp(dir, 1.9 / ang0)
		catch_loc = M.inverse() * dir
	else:
		dir = M * catch_loc
	put_clav("Left", M, M.inverse() * dir, w)
	var sh := gp("LeftArm").origin
	var wt := sh + dir * (0.5 * (1.0 - 0.25 * k)) + Vector3(0, -0.06 * k, 0)
	var l1: float = (b0["LeftForeArm"] as Transform3D).origin.distance_to((b0["LeftArm"] as Transform3D).origin)
	var l2: float = (b0["LeftHand"] as Transform3D).origin.distance_to((b0["LeftForeArm"] as Transform3D).origin)
	var r := ik2(sh, wt, l1, l2, M * Vector3(0.4, -1.0, -0.1))
	var inv := M.inverse()
	var d1: Vector3 = inv * ((r[0] as Vector3) - sh)
	var d2: Vector3 = inv * ((r[1] as Vector3) - (r[0] as Vector3))
	put_arm("Left", M, d1, d2, d2, hint, w)


# ---------------------------------------------------------------- Release und Flug

# Schild am Arm in Weltkoordinaten (aus dem Skelett gerechnet, damit es im selben Bild stimmt)
func mount_xf() -> Transform3D:
	if skel and is_instance_valid(mount):
		var x: Transform3D = skel.global_transform * gp("LeftHand") * mount.transform
		x.basis = x.basis.orthonormalized()
		return x
	return Transform3D(Basis.IDENTITY, pl.global_position + Vector3(0, 1.3, 0) + pl.facing() * 0.6)


func release() -> void:
	if released:
		return
	released = true
	var xf := mount_xf()
	var par: Node = pl.get_parent()
	shield = Node3D.new()
	MixamoModel.flat_shield(shield)
	par.add_child(shield)
	shield.global_transform = xf
	if is_instance_valid(mount):
		mount.visible = false
	pos = xf.origin
	prev = pos
	pl.shield = shield
	pl.shield_state = 1
	fly = 1
	fly_t = 0.0
	pause = 0.0
	spin = 0.0
	bank = 0.0
	chain = 0
	wall_n = 0
	ret_n = 0
	hit_list.clear()
	VFX.shield_trail(shield)
	var tg := find_target(pos)
	heading = ((tg["pos"] as Vector3) - pos).normalized()
	seg_begin(tg["pos"], tg["enemy"], 0.07)


# Linke Seite der Figur (waagrecht)
func left_dir() -> Vector3:
	var l: Vector3 = -pl.model.global_transform.basis.x
	l.y = 0.0
	return l.normalized()


# Seitliche Ausbuchtung der Bahn von a nach b (bevorzugt links, nur wenn frei)
func pick_bulge(a: Vector3, b: Vector3, amp: float) -> Vector3:
	var d := b - a
	var lat := Vector3.UP.cross(d)
	if lat.length() < 0.05:
		return Vector3.ZERO
	lat = lat.normalized()
	if lat.dot(left_dir()) < 0.0:
		lat = -lat
	var mid := a + d * 0.5
	for sg in [1.0, -1.0]:
		var off: Vector3 = lat * (sg * amp)
		if ray(a, mid + off).is_empty() and ray(mid + off, b).is_empty():
			return off
	return Vector3.ZERO


# Neues Teilstück: von der aktuellen Position zu einem Ziel (Gegner oder Punkt)
func seg_begin(tgt: Vector3, en: Node3D, bulge: float) -> void:
	fly = 1
	pl.shield_state = 1
	seg_p0 = pos
	seg_tgt = tgt
	seg_en = en
	seg_s = 0.0
	var d := tgt - pos
	seg_bulge = pick_bulge(pos, tgt, minf(d.length() * bulge, 1.6))


func start_return(h0: Vector3, fresh: bool = true) -> void:
	fly = 2
	pl.shield_state = 2
	if fresh:
		hit_list.clear()  # auf dem Rückweg darf jeder noch einmal getroffen werden
	seg_p0 = pos
	seg_s = 0.0
	seg_en = null
	ret_t = 0.0
	seg_h0 = h0.normalized() if h0.length() > 0.01 else heading
	var b := mount_xf().origin
	seg_bulge = pick_bulge(pos, b, minf(maxf(pos.distance_to(b), 2.0) * 0.26, 3.2))


func out_pts() -> Array:
	var a := seg_p0
	var d := seg_tgt - a
	return [a, a + d * 0.33 + seg_bulge, a + d * 0.66 + seg_bulge, seg_tgt]


func ret_pts() -> Array:
	var a := seg_p0
	var b := mount_xf().origin
	var d := b - a
	var ln := maxf(d.length(), 1.0)
	return [a, a + seg_h0 * (ln * 0.32) + seg_bulge, b - d.normalized() * (ln * 0.28) + seg_bulge * 0.6, b]


static func bez(p: Array, s: float) -> Vector3:
	var q := 1.0 - s
	return p[0] * (q * q * q) + p[1] * (3.0 * q * q * s) + p[2] * (3.0 * q * s * s) + p[3] * (s * s * s)


static func bez_d(p: Array, s: float) -> Vector3:
	var q := 1.0 - s
	return ((p[1] - p[0]) * (q * q) + (p[2] - p[1]) * (2.0 * q * s) + (p[3] - p[2]) * (s * s)) * 3.0


func step_flight(delta: float) -> void:
	if not is_instance_valid(shield):
		cancel()
		return
	fly_t += delta
	if fly_t > 5.0:
		snap_home()
		return
	if fly == 2:
		ret_t += delta
		if ret_t > 2.6:
			snap_home()
			return
		eta = pos.distance_to(mount_xf().origin) / SPEED_BACK
	else:
		eta = 9.0
	if pause > 0.0:
		pause -= delta
		orient(delta)
		return
	prev = pos
	if fly == 1 and is_instance_valid(seg_en) and seg_en.is_in_group("enemies"):
		seg_tgt = chest(seg_en)
	var pts := out_pts() if fly == 1 else ret_pts()
	var since := fly_t if fly == 1 else ret_t
	var v := (SPEED_OUT if fly == 1 else SPEED_BACK) * (0.55 + 0.45 * smoothstep(0.0, 0.09, since))
	var dd := maxf(bez_d(pts, seg_s).length(), 0.1)
	seg_s = minf(seg_s + v * delta / dd, 1.0)
	pos = bez(pts, seg_s)
	var mv := pos - prev
	if mv.length() > 0.001:
		var h_old := Vector3(heading.x, 0, heading.z)
		heading = mv.normalized()
		var h_new := Vector3(heading.x, 0, heading.z)
		turn_rate = h_old.cross(h_new).y / maxf(delta, 0.001) if h_old.length() > 0.1 and h_new.length() > 0.1 else 0.0
	if not sweep(prev, pos):
		if fly == 1 and seg_s >= 1.0:
			if is_instance_valid(seg_en) and seg_en.is_in_group("enemies"):
				hit_enemy(seg_en, pos)
			else:
				start_return(heading)
		elif fly == 2 and (seg_s >= 1.0 or pos.distance_to(mount_xf().origin) < 0.25):
			do_catch()
			return
	shield.global_position = pos
	orient(delta)


# Schild dreht sich wie ein Frisbee, kippt in die Kurve und taumelt leicht
func orient(delta: float) -> void:
	var b := shield.global_transform.basis.orthonormalized()
	var hh := Vector3(heading.x, 0, heading.z)
	hh = hh.normalized() if hh.length() > 0.05 else Vector3.FORWARD
	bank = lerpf(bank, clampf(-turn_rate * 0.06, -0.55, 0.55), clampf(6.0 * delta, 0.0, 1.0))
	var n_t := Basis(hh, bank + 0.08 * sin(fly_t * 13.0)) * Vector3.UP
	var n_now := b.y.normalized()
	var n_new := n_now.slerp(n_t, clampf(delta * 9.0, 0.0, 1.0)).normalized()
	if n_now.dot(n_new) < 0.99999:
		b = Basis(Quaternion(n_now, n_new)) * b
	var close := 1.0 - smoothstep(0.06, 0.30, eta) if fly == 2 else 0.0
	spin = 24.0 * smoothstep(0.0, 0.12, fly_t) * (1.0 - close)
	b = b * Basis(Vector3.UP, spin * delta)
	if close > 0.0 and is_instance_valid(mount):
		# kurz vor dem Fang: Ausrichtung des Schilds am Arm übernehmen
		var q := b.get_rotation_quaternion().slerp(mount_xf().basis.get_rotation_quaternion(), close * close)
		b = Basis(q)
	shield.global_transform = Transform3D(b, pos)


# Schild fliegt von a nach b: trifft es etwas? Gibt true zurück, wenn ein Treffer verarbeitet wurde.
func sweep(a: Vector3, b: Vector3) -> bool:
	var seg := b - a
	var ln := seg.length()
	if ln < 0.0001:
		return false
	var best := 2.0
	var kind := 0
	var he: Node3D = null
	var wh: Dictionary = {}
	var r := ray(a, b + seg / ln * 0.2)
	if not r.is_empty():
		best = a.distance_to(r["position"]) / ln
		kind = 2
		wh = r
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e in hit_list:
			continue
		var s := enemy_param(a, b, e)
		if s >= 0.0 and s < best:
			best = s
			kind = 1
			he = e
	if kind == 1:
		hit_enemy(he, a.lerp(b, best))
	elif kind == 2:
		hit_wall(wh)
	return kind != 0


# Ab welchem Anteil der Strecke a-b berührt das Schild den Gegner? (-1 = gar nicht)
func enemy_param(a: Vector3, b: Vector3, e: Node3D) -> float:
	var n := maxi(int(a.distance_to(b) / 0.25), 1)
	for i in range(n + 1):
		var p := a.lerp(b, float(i) / float(n))
		var rel := p - e.global_position
		var dy := rel.y - clampf(rel.y, 0.45, 1.45)
		if sqrt(rel.x * rel.x + rel.z * rel.z + dy * dy) < HIT_R:
			return float(i) / float(n)
	return -1.0


# Nächster Gegner (noch nicht getroffen) in Reichweite des Abprallers und in Sichtlinie
func next_enemy() -> Node3D:
	var best: Node3D = null
	var bd := BOUNCE_R
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e in hit_list:
			continue
		var c := chest(e)
		var d := pos.distance_to(c)
		if d < bd and d > 0.8 and ray(pos, c).is_empty():
			bd = d
			best = e
	return best


func hit_enemy(e: Node3D, at: Vector3) -> void:
	hit_list.append(e)
	pos = at
	e.hit(DMG, e.global_position - heading)  # Stoß in Flugrichtung
	VFX.shield_impact(pl.get_parent(), at)
	pause = 0.05
	if fly != 1:
		return  # auf dem Rückweg: Schaden, aber keine Ablenkung
	chain += 1
	var nxt: Node3D = next_enemy() if chain < MAX_HITS else null
	if nxt:
		seg_begin(chest(nxt), nxt, 0.05)
	else:
		start_return(-heading + left_dir() * 0.6)
		hit_list = [e]  # den eben getroffenen nicht gleich noch einmal


func hit_wall(r: Dictionary) -> void:
	var n: Vector3 = r["normal"]
	var at: Vector3 = r["position"]
	pos = at + n * 0.22
	VFX.impact(pl.get_parent(), at, n, Color(1.0, 0.85, 0.5))
	VFX.shield_impact(pl.get_parent(), at + n * 0.05)
	pause = 0.04
	var refl := heading.bounce(n)
	if fly == 1:
		wall_n += 1
		var nxt: Node3D = next_enemy() if (chain < MAX_HITS and wall_n <= 3) else null
		if nxt:
			seg_begin(chest(nxt), nxt, 0.05)
		else:
			start_return(refl)
	else:
		ret_n += 1
		if ret_n > 3:
			snap_home()
		else:
			start_return(refl, false)


# Kommt das Schild nicht mehr zurück: mit Effekt zur Hand springen
func snap_home() -> void:
	if is_instance_valid(shield):
		VFX.shield_impact(pl.get_parent(), pos)
	pos = mount_xf().origin
	do_catch()


func do_catch() -> void:
	var xf := mount_xf()
	catch_dir = heading
	catch_t = 0.0
	fly = 0
	pl.shield_state = 0
	pl.shield = null
	if is_instance_valid(shield):
		shield.queue_free()
	shield = null
	if is_instance_valid(mount):
		mount.visible = true
	VFX.impact(pl.get_parent(), xf.origin, Vector3.UP + catch_dir * -0.5, Color(0.8, 0.9, 1.0))  # kleiner Funke beim Einrasten
