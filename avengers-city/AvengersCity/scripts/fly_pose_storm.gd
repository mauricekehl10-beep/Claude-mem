extends RefCounted
# Flugpose für Thor mit Stormbreaker (Clip "Mjolnir vs. Stormbreaker"):
#  - Mjolnir: Hammer wird geworfen, Thor liegt waagerecht und wird hinterhergezogen, ein Arm nach vorn.
#  - Stormbreaker: Thor wird von Bifrost/der Axt getragen: er schwebt AUFRECHT, Beine gestreckt und zusammen, die Axt hängt
#    in der rechten Hand schräg nach vorn-oben, der linke Arm locker. Im schnellen Flug lehnt er sich nur schräg nach vorn
#    (nicht waagerecht) und hält die Axt mit beiden Händen vor der Brust wie eine Lanze, der Axtkopf zeigt voraus.
# apply() läuft nach dem Animations-Update (Signal mixer_applied), nach der Mjolnir-Pose, und überschreibt Rumpf, Kopf, Arme, Beine.
# Punkte und Richtungen im Skelettraum der Figur: +X = links, +Y = oben, +Z = vorn (rechts ist also -X).

const Rig = preload("res://scripts/storm_rig.gd")

var rig: Rig
var weight := 0.0  # 0 = Animation/Mjolnir-Pose, 1 = Stormbreaker-Flugpose
var fast := 0.0  # 0 = Schweben, 1 = schneller Flug
var t := 0.0  # Zeit für das sanfte Schaukeln
var all_bones: Array = []
var anim_rot := {}

# [Schweben, schneller Flug]: Faust rechts, Stielrichtung, Ellbogen-Pol; Faust links (Griff am Stiel oder locker), Pol
const PR := [Vector3(-0.30, 1.02, 0.20), Vector3(-0.05, 1.55, 0.34)]
const DR := [Vector3(-0.22, 0.80, 0.55), Vector3(0.0, 0.80, 0.55)]
const POLE_R := [Vector3(-0.5, -0.7, -0.6), Vector3(-0.8, -0.5, -0.3)]
const PL := [Vector3(0.34, 1.00, 0.10), Vector3(0.0, 1.0, 0.0)]  # schnell: PR + D * LGAP
const POLE_L := [Vector3(0.5, -0.7, -0.6), Vector3(0.8, -0.4, -0.2)]
const LGAP := 0.15  # Abstand der linken Hand vom Griff der rechten (am Stiel)
# Beine: [Schweben, schnell] je (aussen, oben, vorn) für Oberschenkel, Unterschenkel, Fuss
const UL := [Vector3(0.03, -1.0, 0.03), Vector3(0.05, -1.0, -0.10)]
const LL := [Vector3(0.02, -1.0, -0.07), Vector3(0.03, -1.0, -0.30)]
const FT := [Vector3(0.0, -0.9, 0.42), Vector3(0.0, -0.8, 0.60)]


func _init(r: Rig) -> void:
	rig = r
	for n in ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
			"RightShoulder", "RightArm", "RightForeArm", "RightHand", "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase",
			"RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"]:
		all_bones.append(r.bone[n])




func apply() -> void:
	if weight < 0.001 or not rig.valid():
		return
	var skel := rig.skel
	for b in all_bones:
		anim_rot[b] = skel.get_bone_pose_rotation(b)
		skel.set_bone_pose_rotation(b, skel.get_bone_rest(b).basis.get_rotation_quaternion())
	var f := clampf(fast, 0.0, 1.0)
	var e := smoothstep(0.05, 0.85, f)
	var bob := sin(t * 1.3)
	# Rumpf und Kopf: im schnellen Flug biegt sich der Rücken leicht zurück, der Kopf blickt nach vorn
	var arch := [-0.06, -0.08, -0.08, -0.30, -0.42]
	var names := ["Spine", "Spine1", "Spine2", "Neck", "Head"]
	for i in range(names.size()):
		rig.turn(names[i], Basis(Vector3.RIGHT, arch[i] * e))
	# Beine: gestreckt und zusammen, die Füsse zeigen nach unten
	for side in ["Left", "Right"]:
		var s := 1.0 if side == "Left" else -1.0
		var sway := sin(t * 1.1 + (0.0 if side == "Left" else 1.7)) * 0.03 * (1.0 - e * 0.6)
		rig.aim(side + "UpLeg", side + "Leg", _dir(s, UL, e, sway * 0.6))
		rig.aim(side + "Leg", side + "Foot", _dir(s, LL, e, sway))
		rig.aim(side + "Foot", side + "ToeBase", _dir(s, FT, e, 0.0))
	# Rechter Arm mit der Axt
	var D: Vector3 = DR[0].lerp(DR[1], e).normalized()
	var fist: Vector3 = PR[0].lerp(PR[1], e) + Vector3(0, bob * 0.012, 0)
	rig.arm_to("Right", rig.wrist("Right", fist), POLE_R[0].lerp(POLE_R[1], e))
	rig.grip("Right", D)
	# Linker Arm: locker (Schweben) oder am Stiel (schneller Flug)
	var fl: Vector3 = PL[0] + Vector3(0, -bob * 0.012, 0)
	var two: Vector3 = fist + D * LGAP
	rig.arm_to("Left", rig.wrist("Left", fl.lerp(two, e)), POLE_L[0].lerp(POLE_L[1], e))
	var gw := smoothstep(0.3, 0.8, f)
	if gw > 0.01:
		rig.grip("Left", D, gw)
	# Zurückblenden auf die Animation
	for b in all_bones:
		var q: Quaternion = anim_rot[b]
		skel.set_bone_pose_rotation(b, q.slerp(skel.get_bone_pose_rotation(b), weight))


# Richtung aus [Schweben, schnell] mischen, (aussen, oben, vorn) -> Skelettraum
func _dir(s: float, k: Array, e: float, sway: float) -> Vector3:
	var v: Vector3 = (k[0] as Vector3).lerp(k[1], e)
	return Vector3(s * v.x, v.y, v.z + sway).normalized()
