extends RefCounted
# Gemeinsame Hilfen für die Stormbreaker-Posen (fly_pose_storm.gd, storm_attack.gd):
# Knochen setzen, Arm per Zwei-Knochen-IK zu einem Punkt, Hand um den Axtgriff legen, Finger krümmen.
# Alle Richtungen und Punkte stehen im Skelettraum: +X = links der Figur, +Y = oben, +Z = vorn.

const GRIP_TILT := 0.62  # Griffwinkel: der Stiel zeigt etwas zum Ellbogen hin (Radiant), der Kopf steht dann nach vorn-oben
const GRIP_POINT := Vector3(0.0, 0.075, 0.012)  # Mitte der Faust im Handknochen (+Y Finger, +Z Handfläche)
const FINGERS := ["Index", "Middle", "Ring", "Pinky"]
const CURL := [1.25, 1.35, 1.35, 1.3]  # Krümmung der Finger im Griff (Radiant, Gelenk 1..3 zusammen)

var skel: Skeleton3D
var bone := {}  # Name ohne Präfix -> Index
var len1 := 0.274  # Oberarm
var len2 := 0.276  # Unterarm
var fingers := {}  # "Right" -> [[Index der Knochen je Finger], ...]


func _init(s: Skeleton3D) -> void:
	skel = s
	for n in ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
			"RightShoulder", "RightArm", "RightForeArm", "RightHand", "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase",
			"RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"]:
		bone[n] = s.find_bone("mixamorig_" + n)
	var a := s.get_bone_global_rest(bone["RightArm"]).origin
	var f := s.get_bone_global_rest(bone["RightForeArm"]).origin
	var h := s.get_bone_global_rest(bone["RightHand"]).origin
	len1 = a.distance_to(f)
	len2 = f.distance_to(h)
	for side in ["Left", "Right"]:
		var all := []
		for fn in FINGERS:
			var ch := []
			for k in range(1, 4):
				ch.append(s.find_bone("mixamorig_%sHand%s%d" % [side, fn, k]))
			all.append(ch)
		var th := []
		for k in range(1, 4):
			th.append(s.find_bone("mixamorig_%sHandThumb%d" % [side, k]))
		all.append(th)
		fingers[side] = all


func valid() -> bool:
	return is_instance_valid(skel) and bone["RightHand"] >= 0 and bone["Spine2"] >= 0


# ---------------------------------------------------------------- Knochen

func gp(n: String) -> Transform3D:
	return skel.get_bone_global_pose(bone[n])


# Globale Drehung eines Knochens setzen (rechnet auf die Drehung relativ zum Elternknochen um)
func set_global(b: int, nb: Basis, w: float = 1.0) -> void:
	var p := skel.get_bone_parent(b)
	var pb := skel.get_bone_global_pose(p).basis.orthonormalized() if p >= 0 else Basis.IDENTITY
	var q := (pb.inverse() * nb.orthonormalized()).orthonormalized().get_rotation_quaternion()
	if w < 0.999:
		q = skel.get_bone_pose_rotation(b).slerp(q, w)
	skel.set_bone_pose_rotation(b, q)


# Knochen n so drehen, dass er (zum Kindknochen c gesehen) in Richtung dir zeigt
func aim(n: String, c: String, dir: Vector3, w: float = 1.0) -> void:
	var b: int = bone[n]
	var g := skel.get_bone_global_pose(b)
	var cur := (skel.get_bone_global_pose(bone[c]).origin - g.origin).normalized()
	set_global(b, Basis(Quaternion(cur, dir.normalized())) * g.basis.orthonormalized(), w)


# Rotation um eine Achse im Skelettraum (vor die bestehende Drehung gesetzt)
func turn(n: String, r: Basis, w: float = 1.0) -> void:
	var b: int = bone[n]
	set_global(b, r * skel.get_bone_global_pose(b).basis.orthonormalized(), w)


# Oberkörper: Drehung um die Hochachse (yaw, + = nach links), Beugen (pitch, + = nach vorn), Neigen zur Seite (roll, + = nach links), auf drei Wirbel verteilt
func spine(yaw: float, pitch: float, roll: float, w: float = 1.0) -> void:
	var cum := {"Spine": 0.3, "Spine1": 0.35, "Spine2": 0.35}
	for n in cum:
		var c: float = cum[n]
		var r := Basis(Vector3.UP, yaw * c) * Basis(Vector3.RIGHT, pitch * c) * Basis(Vector3(0, 0, 1), roll * c)
		turn(n, r, w)


# Zwei-Knochen-IK: gibt [Ellbogen, Handgelenk] zurück (Pole: Richtung, in die der Ellbogen ausweicht)
func ik2(root: Vector3, tgt: Vector3, pole: Vector3) -> Array:
	var to := tgt - root
	var dist := clampf(to.length(), 0.12, len1 + len2 - 0.004)
	var dir := to.normalized()
	var ca := clampf((len1 * len1 + dist * dist - len2 * len2) / (2.0 * len1 * dist), -1.0, 1.0)
	var sa := sqrt(1.0 - ca * ca)
	var pv := pole - dir * pole.dot(dir)
	pv = pv.normalized() if pv.length() > 0.001 else Vector3(0, 0, 1)
	return [root + dir * (len1 * ca) + pv * (len1 * sa), root + dir * dist]


# Arm so beugen, dass das Handgelenk am Punkt tgt (Skelettraum) liegt. Gibt das tatsächliche Handgelenk zurück.
func arm_to(side: String, tgt: Vector3, pole: Vector3, w: float = 1.0) -> Vector3:
	var s: Vector3 = skel.get_bone_global_pose(bone[side + "Arm"]).origin
	var r := ik2(s, tgt, pole)
	aim(side + "Arm", side + "ForeArm", (r[0] - s), w)
	aim(side + "ForeArm", side + "Hand", (r[1] - r[0]), w)
	return r[1]


# Arm aus zwei Richtungen (Oberarm, Unterarm)
func arm_dirs(side: String, d1: Vector3, d2: Vector3, w: float = 1.0) -> void:
	aim(side + "Arm", side + "ForeArm", d1, w)
	aim(side + "ForeArm", side + "Hand", d2, w)


# Hand um den Griff legen: der Stiel zeigt in Richtung D (Skelettraum). Das Handgelenk knickt so wenig wie möglich.
# Handknochen: +Y = Finger, +Z = Handfläche, +X = Daumenseite; der Stiel liegt zwischen Daumen und Ellbogen-Richtung (-Y).
func grip(side: String, D: Vector3, w: float = 1.0, tilt: float = GRIP_TILT) -> void:
	var h: int = bone[side + "Hand"]
	var fa := (skel.get_bone_global_pose(h).origin - skel.get_bone_global_pose(bone[side + "ForeArm"]).origin).normalized()
	D = D.normalized()
	var sa := sin(tilt)
	var ca := cos(tilt)
	# Fingerrichtung F: Winkel zu D so, dass D = ca*X - sa*F gilt; am nächsten zur Unterarmrichtung
	var wv := fa - D * fa.dot(D)
	if wv.length() < 0.01:
		wv = D.cross(Vector3.UP)
		if wv.length() < 0.01:
			wv = D.cross(Vector3.RIGHT)
	wv = wv.normalized()
	var F := (D * (-sa) + wv * ca).normalized()
	var X := ((D + F * sa) / ca).normalized()
	var Z := X.cross(F).normalized()
	X = F.cross(Z).normalized()
	set_global(h, Basis(X, F, Z), w)


# Finger um den Griff schliessen (0 = Animation, 1 = Faust). Wird auf die aktuelle Finger-Pose aufgesetzt.
func curl_hand(side: String, amount: float) -> void:
	if amount < 0.001:
		return
	var all: Array = fingers[side]
	for i in range(all.size()):
		var ch: Array = all[i]
		if i < 4:
			var tot: float = CURL[i] * amount
			var wts := [0.30, 0.38, 0.32]
			for k in range(3):
				var b: int = ch[k]
				if b < 0:
					continue
				var q := skel.get_bone_pose_rotation(b)
				skel.set_bone_pose_rotation(b, q * Quaternion(Vector3.RIGHT, tot * wts[k]))
		else:
			# Daumen: legt sich quer über die Finger
			for k in range(3):
				var b2: int = ch[k]
				if b2 < 0:
					continue
				var q2 := skel.get_bone_pose_rotation(b2)
				var ang: float = [0.35, 0.45, 0.35][k] * amount
				skel.set_bone_pose_rotation(b2, q2 * Quaternion(Vector3.RIGHT, ang))


# Handgelenk-Punkt, wenn die Faust am Punkt "fist" liegen soll (Faust sitzt ~8 cm vor dem Handgelenk)
func wrist(side: String, fist: Vector3) -> Vector3:
	var sh: Vector3 = gp(side + "Arm").origin
	return fist - (fist - sh).normalized() * 0.08
