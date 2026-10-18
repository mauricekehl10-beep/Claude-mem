extends RefCounted
# Flughaltung von Iron Man nach dem Film (Avengers, New York): Schweben, Reiseflug, Boost, Bremsen, Start, Landung.
# Gleiche Schnittstelle wie fly_pose.gd (skel, weight, fast, t, apply()). Dazu kommt update_body(): Neigung, Rollen, Drehung der Figur.
# apply() läuft direkt nach dem Animations-Update (Signal mixer_applied) und ersetzt Rumpf, Kopf, Arme und Beine (kein Mixamo-Clip, nichts wedelt).
# Richtungen stehen im Körperraum des Skeletts (+X links, +Y Kopf, +Z vorn) als (aussen, oben, vorn).

var skel: Skeleton3D
var hero := 1
var weight := 0.0  # 0 = Animation, 1 = Flugpose
var fast := 0.0  # wie bei fly_pose.gd (zeigt hier das geglättete Tempo)
var t := 0.0

# Geglättete Mischwerte (0..1)
var s_f := 0.0  # Reiseflug (Körper liegt)
var s_b := 0.0  # Boost
var s_br := 0.0  # Bremsen: Körper richtet sich auf, Arme nach vorn
var s_rise := 0.0  # Start, Steigen: Arme unten, Beine zusammen
var s_flare := 0.0  # Landeanflug: Arme weit, aufrecht
var s_flat := 0.0  # Füsse flach (kurz vor dem Boden)
var s_stand := 0.0  # am Boden: stehende Haltung
var s_bank := 0.0  # -1..1, Rollen: Arme wie Tragflächen
var lam := 0.0  # Neigung des Körpers nach vorn (Radiant, 0 = aufrecht, PI/2 = waagerecht)
var gd := 99.0  # Abstand zum Boden
var ground_pt := Vector3.ZERO

# Start
var launching := false
var launch_t := 9.0
# Landung: land_t < 0 = keine Landung
var land_t := -1.0
var land_len := 0.0
var land_hero := false
var land_power := 0.0  # Wucht der Landung (m/s), für die Effekte
var touch_event := false  # wird einmal beim Aufsetzen true (iron_fx.gd holt es ab)
var c_soft := 0.0  # Tiefe der sanften Landung
var c_hero := 0.0  # Tiefe der Superhelden-Landung
var plant := 0.0  # Faust am Boden

var prev_vel := Vector3.ZERO
var hips := -1
var trunk: Array = []  # Spine, Spine1, Spine2, Neck, Head
var limbs: Array = []  # je Seite: Knochen
var all_bones: Array = []
var anim_rot := {}  # Knochen -> Drehung aus der Animation (zum Zurückblenden)
var K := {}  # Haltungen

const ARCH := [-0.10, -0.14, -0.18, -0.42, -0.56]  # Rücken und Kopf biegen sich zurück, damit der Blick nach vorn geht
const FLAT := Vector3(0.0, -0.46, 0.89)  # Fuss flach auf dem Boden
const POINT := Vector3(0.0, -0.84, 0.46)  # Fussspitzen gestreckt (Düse)


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
		L["ToeEnd"] = s.find_bone("mixamorig_%sToe_End" % side)
		limbs.append(L)
	_keys()


# ---------------------------------------------------------------- Haltungen

# Arm: ua/fa = Oberarm/Unterarm (Richtung), pd = Richtung der Handfläche, pw = wie stark die Hand dorthin gedreht wird
static func _a(ua: Vector3, fa: Vector3, pd := Vector3.DOWN, pw := 1.0) -> Dictionary:
	return {"ua": ua.normalized(), "fa": fa.normalized(), "pd": pd.normalized(), "pw": pw}


# Bein: ul/ll/ft = Oberschenkel/Unterschenkel/Fuss
static func _l(ul: Vector3, ll: Vector3, ft: Vector3) -> Dictionary:
	return {"ul": ul.normalized(), "ll": ll.normalized(), "ft": ft.normalized()}


# Haltung aus Seite links/rechts, Rumpfbiegung (Spine..Head, + = nach vorn) und Beckenkippen
static func _key(l: Dictionary, r: Dictionary, tr := [0.0, 0.0, 0.0, 0.0, 0.0], hip := 0.0) -> Dictionary:
	return {"L": l, "R": r, "tr": tr, "hip": hip}


static func _sym(arm: Dictionary, leg: Dictionary, tr := [0.0, 0.0, 0.0, 0.0, 0.0], hip := 0.0) -> Dictionary:
	var d := arm.duplicate()
	d.merge(leg)
	return _key(d, d.duplicate(), tr, hip)


func _keys() -> void:
	# Schweben (Film: Arme leicht seitlich, Ellbogen gebeugt, Handflächen nach unten, Beine gestreckt, Füsse als Düsen)
	K["hover"] = _sym(_a(Vector3(0.70, -0.70, 0.08), Vector3(0.92, -0.34, 0.24)), _l(Vector3(0.09, -1, 0.0), Vector3(0.05, -1, -0.07), POINT))
	# Reiseflug: Arme nach hinten angelegt, leicht nach aussen (wie Tragflächen), Handflächen nach hinten
	K["cruise"] = _sym(_a(Vector3(0.30, -0.94, -0.12), Vector3(0.22, -0.94, -0.26)), _l(Vector3(0.05, -1, -0.03), Vector3(0.03, -1, -0.12), POINT), [0.0, 0.0, 0.0, 0.0, 0.0])
	# Boost: Arme eng am Körper nach hinten, Beine zusammen, Körper wie ein Pfeil
	K["boost"] = _sym(_a(Vector3(0.15, -0.98, -0.14), Vector3(0.06, -0.99, -0.14)), _l(Vector3(0.02, -1, -0.04), Vector3(0.01, -1, -0.15), POINT))
	# Bremsen: Arme nach vorn und aussen, Handflächen gegen die Flugrichtung, Beine etwas nach vorn
	K["brake"] = _sym(_a(Vector3(0.52, -0.40, 0.76), Vector3(0.66, -0.12, 0.74), Vector3(0, -0.35, 0.94)), _l(Vector3(0.12, -1, 0.20), Vector3(0.06, -1, 0.0), Vector3(0, -0.70, 0.71)), [0.0, 0.0, 0.0, 0.10, 0.14])
	# Start und Steigen: Arme unten, Handflächen schieben nach unten, Beine zusammen
	K["rise"] = _sym(_a(Vector3(0.40, -0.90, -0.14), Vector3(0.46, -0.87, -0.14)), _l(Vector3(0.03, -1, 0.0), Vector3(0.02, -1, -0.05), POINT))
	# Landeanflug: Arme weit zum Ausbalancieren, Handflächen nach unten
	K["flare"] = _sym(_a(Vector3(0.78, -0.62, 0.10), Vector3(0.94, -0.34, 0.16)), _l(Vector3(0.13, -1, 0.05), Vector3(0.07, -1, -0.03), POINT))
	# am Boden stehen (Übergang zur Idle-Animation)
	K["stand"] = _sym(_a(Vector3(0.20, -0.97, 0.03), Vector3(0.14, -0.96, 0.18), Vector3.DOWN, 0.0), _l(Vector3(0.04, -1, 0.0), Vector3(0.03, -1, -0.02), FLAT))
	# sanfte Landung: Knie beugen, Oberkörper etwas nach vorn, Arme locker nach vorn-aussen
	K["soft"] = _sym(_a(Vector3(0.48, -0.78, 0.40), Vector3(0.52, -0.52, 0.68), Vector3.DOWN, 0.0), _l(Vector3(0.12, -0.80, 0.59), Vector3(0.06, -0.93, -0.37), FLAT), [0.16, 0.14, 0.10, -0.10, -0.14], 0.16)
	# Superhelden-Landung: linker Fuss vorn, rechtes Knie unten, rechte Faust am Boden, linker Arm zur Seite
	K["hero"] = _key(
		{"ua": Vector3(0.80, -0.15, -0.58).normalized(), "fa": Vector3(0.88, -0.10, -0.46).normalized(), "pd": Vector3.DOWN, "pw": 0.0,
			"ul": Vector3(0.10, -0.12, 0.99).normalized(), "ll": Vector3(0.0, -0.97, -0.24).normalized(), "ft": FLAT},
		{"ua": Vector3(0.20, -0.85, 0.50).normalized(), "fa": Vector3(0.10, -0.90, 0.42).normalized(), "pd": Vector3.DOWN, "pw": 0.0,
			"ul": Vector3(0.02, -0.97, -0.24).normalized(), "ll": Vector3(0.0, -0.20, -0.98).normalized(), "ft": Vector3(0, -0.55, -0.83).normalized()},
		[0.42, 0.40, 0.34, -0.40, -0.52], 0.30)


# Mischt zwei Haltungen (w = 0..1). Richtungen kugelförmig, Zahlen linear, Listen und Unterlisten Eintrag für Eintrag.
func _mix(a: Dictionary, b: Dictionary, w: float) -> Dictionary:
	if w < 0.001:
		return a
	if w > 0.999:
		return b
	var out := {}
	for k in a:
		var va = a[k]
		var vb = b[k]
		if va is Dictionary:
			out[k] = _mix(va, vb, w)
		elif va is Array:
			var arr := []
			for i in range(va.size()):
				arr.append(lerpf(va[i], vb[i], w))
			out[k] = arr
		elif va is Vector3:
			out[k] = _slerp(va, vb, w)
		else:
			out[k] = lerpf(va, vb, w)
	return out


static func _slerp(a: Vector3, b: Vector3, f: float) -> Vector3:
	if a.dot(b) < -0.98:
		return a.lerp(b, f).normalized()
	return a.slerp(b, f)


# Die Haltung aus allen Mischwerten
func _build() -> Dictionary:
	var P: Dictionary = _mix(K["hover"], K["cruise"], smoothstep(0.0, 0.6, s_f))
	P = _mix(P, K["boost"], s_b * s_f)
	P = _mix(P, K["flare"], s_flare)
	P = _mix(P, K["rise"], s_rise)
	P = _mix(P, K["brake"], s_br)
	P = _mix(P, K["stand"], s_stand)
	P = _mix(P, K["soft"], c_soft)
	P = _mix(P, K["hero"], c_hero)
	return P


# ---------------------------------------------------------------- Anwenden

func apply() -> void:
	if not is_instance_valid(skel) or weight < 0.001:
		return
	var hip_anim := skel.get_bone_pose_position(hips)
	for b in all_bones:
		anim_rot[b] = skel.get_bone_pose_rotation(b)
		skel.set_bone_pose_rotation(b, skel.get_bone_rest(b).basis.get_rotation_quaternion())
	var P := _build()
	# Rumpf und Kopf: im schnellen Flug biegt sich der Rücken zurück, damit der Blick nach vorn geht (je steiler, desto weniger)
	var arch := s_f * pow(clampf(lam / (PI * 0.5), 0.0, 1.0), 0.6) * (1.0 - s_stand) * (1.0 - s_br)
	var tr: Array = P["tr"]
	_turn_x(hips, float(P["hip"]))
	for i in range(trunk.size()):
		_turn_x(trunk[i], float(tr[i]) + ARCH[i] * arch)
	# Beine
	for L in limbs:
		var s: float = L["sign"]
		var p: Dictionary = P["L"] if L["left"] else P["R"]
		var ph: float = 0.0 if L["left"] else 1.7
		var w2 := sin(t * 1.1 + ph + 1.3) * 0.02 * (1.0 - s_stand)
		var ft: Vector3 = _slerp(p["ft"], FLAT, s_flat)
		_aim(L["UpLeg"], L["Leg"], _dir(s, p["ul"], w2 * 0.6))
		_aim(L["Leg"], L["Foot"], _dir(s, p["ll"], w2 * 0.5))
		_aim(L["Foot"], L["ToeBase"], _dir(s, ft, 0.0))
	# Boden: Hüfte so tief, dass die Füsse (und das hintere Knie) genau auf dem Boden stehen
	var contact := smoothstep(0.0, 0.25, maxf(c_soft, c_hero))
	var shift := 0.0
	if contact > 0.001:
		shift = _ground_shift() * contact
	# Arme
	for L in limbs:
		var s: float = L["sign"]
		var p: Dictionary = P["L"] if L["left"] else P["R"]
		var ph: float = 0.0 if L["left"] else 1.7
		var w1 := sin(t * 1.3 + ph) * 0.02 * (1.0 - s_stand)
		var ua: Vector3 = p["ua"]
		var fa: Vector3 = p["fa"]
		# Rollen: der obere Flügel geht weiter nach aussen, der untere legt sich an
		ua.x += s_bank * s_f * 0.34
		fa.x += s_bank * s_f * 0.24
		_aim(L["Arm"], L["ForeArm"], _dir(s, ua.normalized(), w1))
		_aim(L["ForeArm"], L["Hand"], _dir(s, fa.normalized(), w1 * 0.7))
		if not L["left"] and plant > 0.001:
			_plant(L, shift)
		_hand(L, p)
	if absf(shift) > 0.0001:
		skel.set_bone_pose_position(hips, hip_anim + Vector3(0, shift * weight, 0))
	# Zurückblenden auf die Animation
	for b in all_bones:
		var q: Quaternion = anim_rot[b]
		skel.set_bone_pose_rotation(b, q.slerp(skel.get_bone_pose_rotation(b), weight))


# Richtung (aussen, oben, vorn) -> Skelettraum (+X links); "sway" schaukelt leicht nach vorn/hinten
func _dir(s: float, v: Vector3, sway: float) -> Vector3:
	return Vector3(s * v.x, v.y, v.z + sway).normalized()


# Wie weit muss die Hüfte nach oben (+) oder unten (-), damit der tiefste Auflagepunkt genau auf dem Boden liegt?
func _ground_shift() -> float:
	var lo := 1e9
	for L in limbs:
		for item in [["Foot", 0.085], ["ToeBase", 0.033], ["ToeEnd", 0.031], ["Leg", 0.09]]:
			var b: int = L[item[0]]
			if b >= 0:
				lo = minf(lo, skel.get_bone_global_pose(b).origin.y - float(item[1]))
	return -lo


# Rechte Faust auf den Boden (zwei-Knochen-Zielen mit Ellbogen nach hinten-aussen)
func _plant(L: Dictionary, shift: float) -> void:
	var arm: int = L["Arm"]
	var fore: int = L["ForeArm"]
	var hand: int = L["Hand"]
	var sp := skel.get_bone_global_pose(arm).origin
	var l1 := (skel.get_bone_global_pose(fore).origin - sp).length()
	var l2 := (skel.get_bone_global_pose(hand).origin - skel.get_bone_global_pose(fore).origin).length()
	var target := Vector3(-0.30, 0.07 - shift, sp.z + 0.18)
	var d := target - sp
	var dist := clampf(d.length(), 0.05, l1 + l2 - 0.004)
	var dn := d.normalized()
	var ca := clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0)
	var ang := acos(ca)
	var pole := Vector3(-0.55, 0.25, -0.8)
	var pl := (pole - dn * pole.dot(dn)).normalized()
	var ed := (dn * cos(ang) + pl * sin(ang)).normalized()
	var tip := sp + dn * dist
	var cur_u := (skel.get_bone_global_pose(fore).origin - sp).normalized()
	var qa := Quaternion(cur_u, ed)
	_set_global(arm, Basis(Quaternion.IDENTITY.slerp(qa, plant)) * skel.get_bone_global_pose(arm).basis)
	var fpos := skel.get_bone_global_pose(fore).origin
	var cur_f := (skel.get_bone_global_pose(hand).origin - fpos).normalized()
	var want_f := (tip - fpos).normalized()
	_set_global(fore, Basis(Quaternion.IDENTITY.slerp(Quaternion(cur_f, want_f), plant)) * skel.get_bone_global_pose(fore).basis)


# Hand: Handfläche in Richtung pd (Iron Man schwebt auf den Repulsoren), sonst bleibt sie so, wie der Unterarm sie mitnimmt
func _hand(L: Dictionary, p: Dictionary) -> void:
	var pw: float = p["pw"]
	if pw < 0.001:
		return
	var hand: int = L["Hand"]
	var g := skel.get_bone_global_pose(hand)
	var f := g.basis.y.normalized()  # Finger
	var n: Vector3 = p["pd"]
	var z := (n - f * n.dot(f))
	if z.length() < 0.05:
		return
	z = z.normalized()
	var want := Basis(f.cross(z), f, z).get_rotation_quaternion()
	var cur := g.basis.orthonormalized().get_rotation_quaternion()
	_set_global(hand, Basis(cur.slerp(want, pw)))


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


# ---------------------------------------------------------------- Zustand (vom Player aufgerufen)

func reset() -> void:
	s_f = 0.0
	s_b = 0.0
	s_br = 0.0
	s_rise = 0.0
	s_flare = 0.0
	s_flat = 0.0
	s_stand = 0.0
	s_bank = 0.0
	lam = 0.0
	launching = false
	launch_t = 9.0
	land_t = -1.0
	c_soft = 0.0
	c_hero = 0.0
	plant = 0.0
	prev_vel = Vector3.ZERO
	touch_event = false


# Start: vom Boden senkrecht hoch (Körper bleibt aufrecht), in der Luft nur zünden
func on_start(pl) -> void:
	land_t = -1.0
	c_soft = 0.0
	c_hero = 0.0
	plant = 0.0
	s_stand = 0.0
	launch_t = 0.0
	launching = pl.is_on_floor() or _ground_dist(pl) < 2.0
	prev_vel = pl.velocity


# Schub nach oben beim Start (m/s)
func launch_thrust() -> float:
	if not launching:
		return 0.0
	return 8.5 * (1.0 - smoothstep(0.35, 1.0, launch_t))


# Boden berührt (Aufruf von land_from_fly): kurze Landeanimation
func on_touch(pl) -> void:
	var hv := Vector2(pl.velocity.x, pl.velocity.z).length()
	var vy: float = absf(pl.last_vy)
	land_power = sqrt(hv * hv + vy * vy)
	land_hero = land_power > 7.5
	land_t = 0.0
	land_len = 1.05 if land_hero else 0.55
	launching = false
	touch_event = true
	weight = 1.0


static func _k(rate: float, delta: float) -> float:
	return 1.0 - exp(-rate * delta)


func _ground_dist(pl) -> float:
	var from: Vector3 = pl.global_position + Vector3(0, 0.3, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -60.0, 0))
	q.exclude = [pl.get_rid()]
	var r: Dictionary = pl.get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		ground_pt = Vector3(pl.global_position.x, -999.0, pl.global_position.z)
		return 99.0
	ground_pt = r["position"]
	return maxf(pl.global_position.y - float(r["position"].y), 0.0)


# Körperhaltung des Models: Neigung, Rollen, Drehung. Gibt true zurück, wenn Iron Man das selbst erledigt (Flug, Landung).
func update_body(pl, delta: float) -> bool:
	var fl: bool = pl.flying
	t = pl.hover_t
	var sc: float = pl.HEROES[pl.hero]["scale"]
	if not fl:
		# Landung am Boden: Haltung weiter selbst führen
		if land_t < 0.0:
			_relax(delta)
			return false
		_land(pl, delta)
		weight = 1.0
		fast = s_f
		pl.fly_fast = 0.0
		pl.elev = 0.0
		pl.tilt = 0.0
		pl.side_tilt = 0.0
		pl.bank = 0.0
		var rot := Basis(Vector3.UP, pl.body_yaw)
		pl.model.basis = rot * Basis.from_scale(Vector3.ONE * sc)
		pl.model.position = Vector3.ZERO
		return true

	# --- Flug
	var vel: Vector3 = pl.velocity
	var vh := Vector3(vel.x, 0.0, vel.z)
	var sp := vel.length()
	var by: float = pl.body_yaw
	var face := Vector3(-sin(by), 0.0, -cos(by))
	var rgt := Vector3(cos(by), 0.0, -sin(by))
	var fwd3: Vector3 = -pl.cam.global_transform.basis.z
	gd = _ground_dist(pl)
	# Start: erst aufrecht steigen, dann in den Flug kippen
	var rise_t := 0.0
	if launching:
		launch_t += delta
		rise_t = 1.0 - smoothstep(0.45, 1.15, launch_t)
		if launch_t > 1.2:
			launching = false
	# Bremsen: starke Verzögerung gegen die Flugrichtung
	var br_t := 0.0
	if delta > 0.0001 and sp > 4.0:
		var a_along := ((vel - prev_vel) / delta).dot(vel / sp)
		br_t = smoothstep(16.0, 46.0, -a_along) * smoothstep(5.0, 11.0, sp)
	prev_vel = vel
	# Landeanflug: sinkt dicht über dem Boden mit wenig Tempo
	var desc := smoothstep(0.8, 3.0, -vel.y)
	var near := 1.0 - smoothstep(1.5, 7.0, gd)
	var calm := 1.0 - smoothstep(5.0, 12.0, vh.length())
	var flare_t := desc * near * calm
	var flat_t := (1.0 - smoothstep(0.5, 2.2, gd)) * (1.0 if vel.y < 0.6 else 0.0)
	var climb := smoothstep(2.0, 8.0, vel.y)

	var fast_t := smoothstep(3.0, 13.0, maxf(vel.dot(fwd3), 0.0))
	if pl.atk == "swing" or pl.atk == "bolt":
		fast_t = minf(fast_t, 0.1)
	fast_t *= (1.0 - rise_t) * (1.0 - flare_t)
	var elev_t := 0.0
	if sp > 3.0:
		elev_t = asin(clampf(vel.y / sp, -1.0, 1.0))
	var tilt_t := clampf(vh.dot(face) / 12.0, -1.0, 1.0) * 0.32 * (1.0 - rise_t)
	var side_t := clampf(vh.dot(rgt) / 12.0, -1.0, 1.0) * 0.32 * (1.0 - rise_t)
	var err := angle_difference(by, pl.yaw)  # > 0: Kamera ist links vom Körper
	var bank_t := clampf(-err * 6.0 + Input.get_axis("move_left", "move_right") * 0.4, -0.95, 0.95) * (1.0 - rise_t)
	var lam_t := fast_t * (PI * 0.5 - elev_t) + tilt_t * (1.0 - fast_t)
	lam_t -= 0.34 * br_t + 0.14 * flare_t  # Bremsen und Abfangen: Körper kippt zurück, Füsse nach vorn

	var kk: float = _k(5.5, delta)
	lam = lerpf(lam, lam_t, kk)
	s_f = lerpf(s_f, fast_t, _k(4.5, delta))
	s_b = lerpf(s_b, pl.fly_boost, _k(6.0, delta))
	s_br = lerpf(s_br, br_t, _k(10.0 if br_t > s_br else 2.2, delta))
	s_rise = lerpf(s_rise, maxf(rise_t, climb * 0.7 * (1.0 - s_f)), _k(6.0, delta))
	s_flare = lerpf(s_flare, flare_t, _k(5.0, delta))
	s_flat = lerpf(s_flat, flat_t, _k(7.0, delta))
	s_stand = lerpf(s_stand, 0.0, _k(8.0, delta))
	s_bank = lerpf(s_bank, bank_t / 0.95, _k(5.0, delta))
	c_soft = move_toward(c_soft, 0.0, 6.0 * delta)
	c_hero = move_toward(c_hero, 0.0, 6.0 * delta)
	plant = move_toward(plant, 0.0, 8.0 * delta)
	land_t = -1.0
	# Werte für Kamera und Rest des Spiels (wie in player.gd)
	pl.fly_fast = s_f
	pl.elev = lerpf(pl.elev, elev_t, _k(5.0, delta))
	pl.tilt = lerpf(pl.tilt, tilt_t, _k(5.0, delta))
	pl.side_tilt = lerpf(pl.side_tilt, side_t, _k(5.0, delta))
	pl.bank = lerpf(pl.bank, bank_t * 0.8, _k(6.0, delta))
	weight = move_toward(weight, 1.0, 4.0 * delta)
	fast = s_f
	var hover := weight * (1.0 - s_f)
	var l2 := lam + sin(t * 1.1) * 0.02 * hover
	var rot := Basis(Vector3.UP, by) * Basis(Vector3.RIGHT, -l2)
	rot = rot * Basis(Vector3(0, 0, 1), -pl.side_tilt * (1.0 - s_f)) * Basis(Vector3.UP, pl.bank * s_f * 1.25)
	pl.model.basis = rot * Basis.from_scale(Vector3.ONE * sc)
	var pv := Vector3(0, sc, 0)
	pl.model.position = pv - rot * pv + Vector3(0, sin(t * 1.7) * 0.04 * hover, 0)
	return true


# Nach dem Flug ohne Landung (Absturz, Auto): Werte ausklingen lassen, damit der nächste Flug sauber startet
func _relax(delta: float) -> void:
	var k := 1.0 - exp(-6.0 * delta)
	s_f = lerpf(s_f, 0.0, k)
	s_b = lerpf(s_b, 0.0, k)
	s_br = lerpf(s_br, 0.0, k)
	s_rise = lerpf(s_rise, 0.0, k)
	s_flare = lerpf(s_flare, 0.0, k)
	s_flat = lerpf(s_flat, 0.0, k)
	s_bank = lerpf(s_bank, 0.0, k)
	s_stand = lerpf(s_stand, 1.0, k)
	lam = lerpf(lam, 0.0, k)
	launching = false
	c_soft = move_toward(c_soft, 0.0, 6.0 * delta)
	c_hero = move_toward(c_hero, 0.0, 6.0 * delta)
	plant = move_toward(plant, 0.0, 8.0 * delta)


# Landeanimation: runter in die Hocke, kurz halten, wieder aufrichten
func _land(pl, delta: float) -> void:
	land_t += delta
	var u := land_t
	var k := 1.0 - exp(-9.0 * delta)
	s_f = lerpf(s_f, 0.0, k)
	s_b = lerpf(s_b, 0.0, k)
	s_br = lerpf(s_br, 0.0, k)
	s_rise = lerpf(s_rise, 0.0, k)
	s_flare = lerpf(s_flare, 0.0, k)
	s_flat = lerpf(s_flat, 1.0, k)
	s_bank = lerpf(s_bank, 0.0, k)
	s_stand = lerpf(s_stand, 1.0, 1.0 - exp(-12.0 * delta))
	lam = lerpf(lam, 0.0, k)
	if land_hero:
		c_hero = smoothstep(0.0, 0.11, u) * (1.0 - smoothstep(0.62, 1.0, u))
		plant = smoothstep(0.05, 0.13, u) * (1.0 - smoothstep(0.58, 0.8, u))
	else:
		c_soft = smoothstep(0.0, 0.09, u) * (1.0 - smoothstep(0.14, 0.5, u))
	# wer gleich wieder losläuft: Landung kürzer
	if u > 0.22 and Vector2(pl.velocity.x, pl.velocity.z).length() > 4.0:
		land_t = maxf(land_t, land_len - 0.16)
	if land_t >= land_len:
		land_t = -1.0
		c_soft = 0.0
		c_hero = 0.0
		plant = 0.0
