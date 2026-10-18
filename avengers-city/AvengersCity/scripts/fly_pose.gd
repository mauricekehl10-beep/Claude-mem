extends RefCounted
# Flugpose per Code für Iron Man und Thor: schweben, langsam und schnell fliegen (Körper liegt waagerecht).
# apply() läuft direkt nach dem Animations-Update (Signal mixer_applied) und ersetzt Rumpf, Kopf, Arme und Beine.
# Die Haltung entsteht aus der Ruhepose (T-Pose): kein Mixamo-Clip, deshalb wedelt hier nichts.
# Richtungen stehen im Körperraum des Skeletts (+X links, +Y Kopf, +Z vorn) als (aussen, oben, vorn).

var skel: Skeleton3D
var hero := 1  # 1 = Iron Man, 2 = Thor
var weight := 0.0  # 0 = Animation, 1 = Flugpose
var fast := 0.0  # 0 = Schweben, 0.5 = langsamer Flug, 1 = schneller Flug (waagerecht)
var t := 0.0  # Zeit für das sanfte Schaukeln
var hips := -1
var trunk: Array = []  # Spine, Spine1, Spine2, Neck, Head
var limbs: Array = []  # je Seite: Knochen und Vorzeichen
var all_bones: Array = []
var anim_rot := {}  # Knochen -> Drehung aus der Animation (zum Zurückblenden)
var ARCH := [-0.10, -0.14, -0.18, -0.42, -0.56]  # Rücken und Kopf biegen sich zurück, damit der Blick nach vorn geht
var thor_weapon := "mjolnir"  # Thor: "mjolnir" oder "stormbreaker" (das Flugverhalten ist pro Waffe austauschbar)
var thor  # Thor mit Mjolnir: Flugpose, Abheben, Landung, Effekte (thor_mjolnir.gd)


func _init(s: Skeleton3D, h: int) -> void:
	skel = s
	hero = h
	hips = s.find_bone("mixamorig_Hips")
	all_bones.append(hips)
	for n in ["Spine", "Spine1", "Spine2", "Neck", "Head"]:
		var b := s.find_bone("mixamorig_" + n)
		trunk.append(b)
		all_bones.append(b)
	for side in ["Left", "Right"]:
		var L := {"left": side == "Left", "sign": 1.0 if side == "Left" else -1.0}
		for n in ["Shoulder", "Arm", "ForeArm", "Hand", "UpLeg", "Leg", "Foot", "ToeBase"]:
			var b := s.find_bone("mixamorig_%s%s" % [side, n])
			L[n] = b
			all_bones.append(b)
		limbs.append(L)


# ---------------------------------------------------------------- Posen

# Eine Haltung: ua/fa = Oberarm/Unterarm, ul/ll/ft = Oberschenkel/Unterschenkel/Fuss (Richtung, die das Glied zeigt),
# lift = Schulter anheben, palm = Handfläche nach unten (0..1), roll = Hand um die Fingerachse drehen, bend = Handgelenk knicken
static func _k(ua: Vector3, fa: Vector3, ul: Vector3, ll: Vector3, ft: Vector3, lift := 0.0, palm := 0.0, roll := 0.0, bend := 0.0) -> Dictionary:
	return {"ua": ua.normalized(), "fa": fa.normalized(), "ul": ul.normalized(), "ll": ll.normalized(), "ft": ft.normalized(), "lift": lift, "palm": palm, "roll": roll, "bend": bend}


# [Schweben, Mitte (oder null), schneller Flug] je Held und Seite
func _keys(left: bool) -> Array:
	var foot := Vector3(0.0, -0.84, 0.46)  # Fussspitzen gestreckt
	if hero == 1:
		# Iron Man: Arme leicht seitlich, Handflächen nach unten; im Flug Arme angelegt nach hinten
		return [
			_k(Vector3(0.62, -0.78, 0.04), Vector3(0.82, -0.46, 0.34), Vector3(0.07, -1, 0.0), Vector3(0.03, -1, -0.10), foot, 0.0, 1.0),
			null,
			_k(Vector3(0.22, -0.97, -0.07), Vector3(0.10, -0.99, -0.10), Vector3(0.04, -1, -0.03), Vector3(0.02, -1, -0.12), foot, 0.0, 0.0),
		]
	# Thor: schwebt aufrecht mit lockeren Armen; im Flug rechter Arm (Mjolnir) nach vorn, linker Arm locker zurück
	if not left:
		return [
			_k(Vector3(0.14, -0.98, -0.02), Vector3(0.10, -0.96, 0.26), Vector3(0.05, -1, 0.07), Vector3(0.03, -1, -0.08), foot),
			_k(Vector3(0.16, 0.64, 0.76), Vector3(0.08, 0.66, 0.75), Vector3(0.05, -1, -0.02), Vector3(0.03, -1, -0.10), foot, 0.18, 0.0, 0.0),
			_k(Vector3(0.10, 0.99, 0.06), Vector3(0.05, 1.0, 0.10), Vector3(0.04, -1, -0.05), Vector3(0.02, -1, -0.12), foot, 0.30, 0.0, 0.0, 0.52),
		]
	return [
		_k(Vector3(0.20, -0.97, -0.04), Vector3(0.14, -0.96, 0.24), Vector3(0.07, -1, -0.06), Vector3(0.03, -0.96, -0.30), Vector3(0.0, -0.95, 0.20)),
		null,
		_k(Vector3(0.30, -0.94, -0.18), Vector3(0.20, -0.97, -0.16), Vector3(0.05, -1, -0.04), Vector3(0.02, -1, -0.12), foot),
	]


# Zwischen den Haltungen mischen (f = 0..1). Ohne Mitte geht es direkt, sonst über die Mitte.
func _pose(left: bool, f: float) -> Dictionary:
	var ks := _keys(left)
	var a: Dictionary = ks[0]
	var b: Dictionary = ks[2]
	var out := {}
	for k in a:
		var va = a[k]
		var vb = b[k]
		var vm = null if ks[1] == null else ks[1][k]
		if va is Vector3:
			var u: Vector3
			if vm == null:
				u = _slerp(va, vb, f)
			elif f < 0.5:
				u = _slerp(va, vm, f * 2.0)
			else:
				u = _slerp(vm, vb, (f - 0.5) * 2.0)
			out[k] = u
		else:
			var v := 0.0
			if vm == null:
				v = lerpf(va, vb, f)
			elif f < 0.5:
				v = lerpf(va, vm, f * 2.0)
			else:
				v = lerpf(vm, vb, (f - 0.5) * 2.0)
			out[k] = v
	return out


static func _slerp(a: Vector3, b: Vector3, f: float) -> Vector3:
	if a.dot(b) < -0.98:
		return a.lerp(b, f).normalized()
	return a.slerp(b, f)


# ---------------------------------------------------------------- Anwenden

func apply() -> void:
	if not is_instance_valid(skel) or weight < 0.001:
		return
	if hero == 2 and thor_weapon == "mjolnir" and thor != null:
		thor.apply()  # Thor mit Mjolnir: eigene Haltungen (thor_mjolnir.gd)
		return
	for b in all_bones:
		anim_rot[b] = skel.get_bone_pose_rotation(b)
		skel.set_bone_pose_rotation(b, skel.get_bone_rest(b).basis.get_rotation_quaternion())
	var f := clampf(fast, 0.0, 1.0)
	var calm := 1.0 - f * 0.6
	# Rumpf und Kopf: im schnellen Flug biegt sich der Rücken leicht zurück, der Kopf blickt nach vorn
	for i in range(trunk.size()):
		var a: float = ARCH[i] * f
		if hero == 2 and i == 1:
			a += 0.05 * f  # Thor: Brust etwas weniger hohl
		_turn_x(trunk[i], a)
	# Glieder
	for L in limbs:
		var s: float = L["sign"]
		var p := _pose(L["left"], f)
		var ph: float = 0.0 if L["left"] else 1.7
		var w1 := sin(t * 1.3 + ph) * 0.035 * calm
		var w2 := sin(t * 1.1 + ph + 1.3) * 0.03 * calm
		if p["lift"] != 0.0:
			_turn(L["Shoulder"], Basis(Vector3(0, 0, 1), s * p["lift"]))
		_aim(L["Arm"], L["ForeArm"], _dir(s, p["ua"], w1))
		_aim(L["ForeArm"], L["Hand"], _dir(s, p["fa"], w2))
		_hand(L, s, p)
		_aim(L["UpLeg"], L["Leg"], _dir(s, p["ul"], w2 * 0.6))
		_aim(L["Leg"], L["Foot"], _dir(s, p["ll"], w1 * 0.6))
		_aim(L["Foot"], L["ToeBase"], _dir(s, p["ft"], 0.0))
	# Zurückblenden auf die Animation
	for b in all_bones:
		var q: Quaternion = anim_rot[b]
		skel.set_bone_pose_rotation(b, q.slerp(skel.get_bone_pose_rotation(b), weight))


# Richtung (aussen, oben, vorn) -> Skelettraum (+X links); "sway" schaukelt leicht nach vorn/hinten
func _dir(s: float, v: Vector3, sway: float) -> Vector3:
	return Vector3(s * v.x, v.y, v.z + sway).normalized()


# Hand: Handfläche nach unten (Iron Man schwebt auf den Repulsoren), sonst bleibt sie so, wie der Unterarm sie mitnimmt
func _hand(L: Dictionary, s: float, p: Dictionary) -> void:
	var hand: int = L["Hand"]
	var g := skel.get_bone_global_pose(hand)
	var f := g.basis.y.normalized()  # Finger
	if p["palm"] > 0.001:
		var n := Vector3(0, -1, 0)
		var z := (n - f * n.dot(f)).normalized()
		var want := Basis(f.cross(z), f, z).get_rotation_quaternion()
		var cur := g.basis.orthonormalized().get_rotation_quaternion()
		_set_global(hand, Basis(cur.slerp(want, p["palm"])))
		g = skel.get_bone_global_pose(hand)
	if p["roll"] != 0.0:
		_set_global(hand, Basis(f, p["roll"]) * g.basis)
		g = skel.get_bone_global_pose(hand)
	if p["bend"] != 0.0:
		# Handgelenk knicken (Drehung um die Handflächen-Normale): Mjolnir liegt dann in einer Linie mit dem Arm
		_set_global(hand, Basis(g.basis.z.normalized(), p["bend"]) * g.basis)


# Dreht den Knochen um seinen Ursprung (Rotation im Skelettraum)
func _turn(b: int, r: Basis) -> void:
	_set_global(b, r * skel.get_bone_global_pose(b).basis)


# Biegt um die Querachse: negativ = nach hinten
func _turn_x(b: int, ang: float) -> void:
	if absf(ang) > 0.0001:
		_turn(b, Basis(Vector3.RIGHT, ang))


# Dreht den Knochen so, dass er (zum Kindknochen gesehen) in Richtung "dir" zeigt
func _aim(b: int, c: int, dir: Vector3) -> void:
	var g := skel.get_bone_global_pose(b)
	var cur := (skel.get_bone_global_pose(c).origin - g.origin).normalized()
	_set_global(b, Basis(Quaternion(cur, dir)) * g.basis)


func _set_global(b: int, nb: Basis) -> void:
	var p := skel.get_bone_parent(b)
	var pb := skel.get_bone_global_pose(p).basis if p >= 0 else Basis.IDENTITY
	skel.set_bone_pose_rotation(b, (pb.inverse() * nb).orthonormalized().get_rotation_quaternion())
