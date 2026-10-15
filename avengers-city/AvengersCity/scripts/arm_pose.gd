extends RefCounted
# Prozedurales Posing: ein Arm zeigt zu einem Punkt, der Oberkörper dreht sich.
# apply() läuft direkt nach dem Animations-Update (Signal mixer_applied) und überschreibt die Knochen.
# "weight" blendet weich zwischen Animation (0) und Zielpose (1).

var skel: Skeleton3D
var spine := -1
var arm := -1
var fore := -1
var hand := -1
var weight := 0.0
var twist := 0.0  # Drehung des Oberkörpers um die Hochachse (Radiant, + = nach links)
var point := Vector3.ZERO  # Weltpunkt, auf den der Arm zeigt
var palm := false  # true: Handfläche zeigt zum Punkt (Repulsor), Finger nach oben
var limit := 1.9  # größter Winkel zwischen Körper-vorn und Zielrichtung


func _init(s: Skeleton3D, side: String) -> void:
	skel = s
	spine = s.find_bone("mixamorig_Spine1")
	arm = s.find_bone("mixamorig_%sArm" % side)
	fore = s.find_bone("mixamorig_%sForeArm" % side)
	hand = s.find_bone("mixamorig_%sHand" % side)


# Hand (Handgelenk) und Schulter in Weltkoordinaten
func hand_pos() -> Vector3:
	return skel.global_transform * skel.get_bone_global_pose(hand).origin


func shoulder_pos() -> Vector3:
	return skel.global_transform * skel.get_bone_global_pose(arm).origin


func apply() -> void:
	if not is_instance_valid(skel) or (weight < 0.001 and absf(twist) < 0.001):
		return
	if absf(twist) > 0.001:
		_set_global(spine, Basis(Vector3.UP, twist) * skel.get_bone_global_pose(spine).basis)
	if weight < 0.001:
		return
	var target := skel.global_transform.affine_inverse() * point
	var dir := _limit((target - skel.get_bone_global_pose(arm).origin).normalized())
	_aim(arm, fore, dir)
	_aim(fore, hand, dir)
	if palm:
		_palm(dir)


# Zielrichtung darf nicht weiter als "limit" von der Blickrichtung des Körpers (Mixamo: +Z) abweichen
func _limit(dir: Vector3) -> Vector3:
	var fwd := Vector3(0, 0, 1)
	var a := fwd.angle_to(dir)
	if a <= limit:
		return dir
	var axis := fwd.cross(dir)
	if axis.length() < 0.001:
		axis = Vector3.UP
	return fwd.rotated(axis.normalized(), limit)


# Dreht den Knochen so, dass er (zum Kindknochen gesehen) in Richtung "dir" zeigt
func _aim(b: int, c: int, dir: Vector3) -> void:
	var g := skel.get_bone_global_pose(b)
	var cur := (skel.get_bone_global_pose(c).origin - g.origin).normalized()
	var q := Quaternion.IDENTITY.slerp(Quaternion(cur, dir), weight)
	_set_global(b, Basis(q) * g.basis)


# Handfläche (Knochen +Z) zeigt in Richtung "dir", die Finger (Knochen +Y) nach oben
func _palm(dir: Vector3) -> void:
	var up := Vector3.UP
	if absf(up.dot(dir)) > 0.95:
		up = Vector3(0, 0, 1)
	var y := (up - dir * up.dot(dir)).normalized()
	var want := Basis(y.cross(dir), y, dir).get_rotation_quaternion()
	var cur := skel.get_bone_global_pose(hand).basis.orthonormalized().get_rotation_quaternion()
	_set_global(hand, Basis(cur.slerp(want, weight)))


# Setzt die Drehung eines Knochens im Skelettraum (rechnet auf die Drehung relativ zum Elternknochen um)
func _set_global(b: int, nb: Basis) -> void:
	var p := skel.get_bone_parent(b)
	var pb := skel.get_bone_global_pose(p).basis if p >= 0 else Basis.IDENTITY
	skel.set_bone_pose_rotation(b, (pb.inverse() * nb).orthonormalized().get_rotation_quaternion())
