extends Node
# Thor fliegt mit Mjolnir, wie im Film: Er wirft den Hammer, hält die Schlaufe, und der Hammer zieht ihn hinterher.
# - Abheben: Thor geht in die Hocke, der Hammer kreist an der Schlaufe, dann Absprung. Der Körper schwingt in die
#   Zugrichtung und dreht sich dabei einmal um die Längsachse.
# - Reiseflug: ein Arm streckt sich mit dem Hammer vorn in Flugrichtung, der Körper hängt gestreckt hinterher,
#   der andere Arm und die Beine folgen locker, der Umhang weht nach hinten (cape.gd).
# - Kurven: der Körper rollt in die Kurve, die Beine schwingen nach aussen.
# - Landung: der Hammer bremst, Thor richtet sich auf und geht in die Landehocke mit einer Hand am Boden.
# Läuft als Thor-Zweig von fly_pose.gd (thor_weapon == "mjolnir"): apply() setzt die Knochen direkt nach der Animation,
# update() kommt jeden Physik-Schritt aus player.update_body(). Richtungen: (aussen, oben, vorn) im Körperraum des Skeletts.

const Fx = preload("res://scripts/mjolnir_fx.gd")
const VFX = preload("res://scripts/vfx.gd")

const WIND_T := 0.45  # Anlauf am Boden: so lange kreist der Hammer, bevor Thor abhebt
const WIND_AIR := 0.3  # Anlauf in der Luft (nach dem Hochsprung)
const LAND_T := 1.05  # Landung: Dauer von Aufsetzen bis Aufstehen
const ARCH := [-0.10, -0.14, -0.18, -0.42, -0.56]  # Rücken und Kopf biegen sich zurück, damit der Blick nach vorn geht

var player: CharacterBody3D
var fp  # FlyPose (Skelett, Knochenlisten)
var skel: Skeleton3D
var fx  # Effekte (mjolnir_fx.gd)
var pivot: Node3D  # Hammer-Drehpunkt (alle Hammerteile hängen daran)
var cord: MeshInstance3D  # Lederschlaufe zwischen Faust und Hammer
var hips := -1
var l1 := 0.4  # Länge Oberschenkel
var l2 := 0.4  # Länge Unterschenkel
var a1 := 0.27  # Länge Oberarm
var a2 := 0.27  # Länge Unterarm
var grip := Vector3.ZERO  # Griffpunkt in Handkoordinaten
var ax := Vector3.UP  # Hammerachse in Handkoordinaten (vom Griff zum Kopf)
var anim_rot := {}
var anim_hips := Vector3.ZERO

# Zustand
var wind := 0.0  # Anlauf-Zeit (0 = aus)
var wind_len := WIND_T  # Dauer des laufenden Anlaufs
var go := false  # Anlauf ist vorbei: start_fly() darf jetzt wirklich starten
var launch_t := 9.0  # Zeit seit dem Absprung
var land_t := 9.0  # Zeit seit dem Aufsetzen
var roll := 0.0  # Drehung um die Körperachse (Radiant), nutzt player.update_body()
var turn := 0.0  # geglättete Kurve -1..1 (+ = rechts)
var flare := 0.0  # 0..1: Anflug auf den Boden, Thor richtet sich auf
var ground := 99.0  # Abstand zum Boden unter Thor
var crouch := 0.0  # 0..1: Landehocke
var hd := Vector3(0.5, 0.866, 0.0)  # Hammerrichtung (geglättet) in Handkoordinaten
var slide := 0.0  # Hammer gleitet an der Schlaufe nach vorn (Meter)
var spin_a := 0.0  # Kreiswinkel des Hammers beim Anlauf
var spin_w := 0.0  # 0..1: Hammer kreist
var level := 0.0  # Leuchten des Hammers (geglättet)
var t := 0.0
var landed_fx := false


# Baut Hammer-Drehpunkt und Effekte (nach dem Bauen der Figur aufrufen)
func setup(pl: CharacterBody3D, fpose, model: Node3D) -> void:
	player = pl
	fp = fpose
	skel = fpose.skel
	hips = skel.find_bone("mixamorig_Hips")
	var ul := skel.find_bone("mixamorig_RightUpLeg")
	var lg := skel.find_bone("mixamorig_RightLeg")
	var ft := skel.find_bone("mixamorig_RightFoot")
	l1 = skel.get_bone_global_rest(lg).origin.distance_to(skel.get_bone_global_rest(ul).origin)
	l2 = skel.get_bone_global_rest(ft).origin.distance_to(skel.get_bone_global_rest(lg).origin)
	var ar := skel.find_bone("mixamorig_RightArm")
	var fa := skel.find_bone("mixamorig_RightForeArm")
	var hd_b := skel.find_bone("mixamorig_RightHand")
	a1 = skel.get_bone_global_rest(fa).origin.distance_to(skel.get_bone_global_rest(ar).origin)
	a2 = skel.get_bone_global_rest(hd_b).origin.distance_to(skel.get_bone_global_rest(fa).origin)
	# Hammerteile an einen Drehpunkt hängen
	var att := skel.get_node_or_null("A_mixamorig_RightHand")
	if att == null:
		return
	pivot = Node3D.new()
	pivot.name = "MjolnirPivot"
	var parts: Array = att.get_children()
	att.add_child(pivot)
	var head_xf := Transform3D.IDENTITY
	var found := false
	for c in parts:
		att.remove_child(c)
		pivot.add_child(c)
		var mi := c as MeshInstance3D
		if mi == null:
			continue
		if mi.mesh is CylinderMesh and (mi.mesh as CylinderMesh).height > 0.3:
			ax = mi.transform.basis.y.normalized()
			grip = mi.transform.origin - ax * 0.06  # der Griff sitzt 6 cm über dem Handmittelpunkt
		elif mi.mesh is BoxMesh and not found and (mi.mesh as BoxMesh).size.z > 0.15:
			head_xf = mi.transform
			found = true
	hd = ax
	# Lederschlaufe: dünner Zylinder von der Faust zum Griffende, wird jedes Bild ausgerichtet
	var cm := CylinderMesh.new()
	cm.top_radius = 0.011
	cm.bottom_radius = 0.011
	cm.height = 1.0
	cm.radial_segments = 8
	cord = MeshInstance3D.new()
	cord.mesh = cm
	cord.material_override = _leather()
	cord.visible = false
	att.add_child(cord)
	fx = Fx.new()
	fx.setup(pivot, head_xf, player, model)


static func _leather() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.20, 0.11, 0.06)
	m.roughness = 0.7
	return m


# ---------------------------------------------------------------- Schnittstelle zum Spieler

# Doppeltipp Leertaste: Vom Boden aus erst Anlauf (Hammer kreist). Gibt true zurück, wenn gewartet werden soll.
func begin(on_floor: bool) -> bool:
	if go:
		go = false
		launch_t = 0.0
		return false
	if wind <= 0.0:
		wind = 0.0001
		wind_len = WIND_T if on_floor else WIND_AIR
		return true
	wind = 0.0  # zweiter Doppeltipp im Anlauf: sofort los
	launch_t = 0.0
	return false


func winding() -> bool:
	return wind > 0.0


# Anlauf läuft (Boden-Steuerung ruht). Danach startet start_fly() wirklich.
func windup(delta: float) -> void:
	wind += delta
	if wind >= wind_len:
		wind = 0.0
		go = true
		player.start_fly()


# Aufgesetzt: Landehocke mit Staub und Funken
func touchdown(_speed: float) -> void:
	land_t = 0.0
	landed_fx = false


# Alles zurücksetzen (Heldenwechsel, Neustart)
func reset() -> void:
	wind = 0.0
	go = false
	launch_t = 9.0
	land_t = 9.0
	flare = 0.0
	crouch = 0.0
	roll = 0.0
	turn = 0.0


# Absprung: der Hammer reisst Thor nach oben und (mit W) nach vorn in Blickrichtung
func launch_kick() -> Vector3:
	var k := Vector3(0.0, 2.0, 0.0)
	if Input.is_action_pressed("move_forward") or Input.is_action_pressed("sprint"):
		k += -player.cam.global_transform.basis.z * 6.0
	return k


# Tempo am Boden nach der Landung: erst Hocke (fast stehend), dann wieder frei
func ground_speed() -> float:
	if land_t >= LAND_T:
		return 1.0
	return lerpf(0.05, 1.0, smoothstep(0.3, 0.75, land_t))


# Läuft die Pose noch (Anlauf oder Landung)? Dann bleibt das Gewicht bei 1.
func pose_on() -> bool:
	return wind > 0.0 or land_t < LAND_T * 0.62


# Beim Anflug auf den Boden richtet sich Thor auf (weniger "schnell")
func fast_limit(f: float) -> float:
	return f * (1.0 - flare)


# Jeden Physik-Schritt (aus player.update_body)
func update(delta: float) -> void:
	t += delta
	var flying: bool = player.flying
	var vel: Vector3 = player.velocity
	var f: float = player.fly_fast
	if flying:
		launch_t += delta
		land_t = 9.0
	else:
		launch_t = 9.0
		land_t += delta
	# Körperdrehung beim Abheben: einmal um die Längsachse
	var ru := clampf((launch_t - 0.04) / 0.72, 0.0, 1.0)
	roll = TAU * (ru * ru * (3.0 - 2.0 * ru)) if ru < 1.0 else 0.0
	# Kurve
	var tt := clampf(player.bank / 0.75, -1.0, 1.0) * f if flying else 0.0
	turn = lerpf(turn, tt, 1.0 - exp(-6.0 * delta))
	# Abstand zum Boden: nur beim Sinkflug nötig (Strahl nach unten)
	var want_flare := 0.0
	if flying and vel.y < -1.2:
		var q := PhysicsRayQueryParameters3D.create(player.global_position + Vector3(0, 0.5, 0), player.global_position + Vector3(0, -9.0, 0))
		q.exclude = [player.get_rid()]
		var r := player.get_world_3d().direct_space_state.intersect_ray(q)
		ground = (player.global_position.y - float(r["position"].y)) if r else 99.0
		want_flare = (1.0 - smoothstep(1.4, 6.5, ground)) * smoothstep(1.2, 3.0, -vel.y)
	else:
		ground = 99.0
	flare = lerpf(flare, want_flare, 1.0 - exp(-7.0 * delta))
	# Landehocke: schnell hinein, halten, langsam wieder hoch
	var ct := 0.0
	if land_t < LAND_T:
		ct = smoothstep(0.0, 0.12, land_t) * (1.0 - smoothstep(0.42, 0.95, land_t) * 0.75)
	crouch = ct
	# Leuchten: stark im Flug und beim Anlauf, schwächer bei der Landung
	var lv := 0.0
	if flying:
		lv = 0.45 + 0.55 * clampf(maxf(f, player.fly_boost), 0.0, 1.0)
	elif wind > 0.0:
		lv = 0.35 + 0.65 * clampf(wind / wind_len, 0.0, 1.0)
	elif land_t < LAND_T:
		lv = 0.9 * (1.0 - smoothstep(0.1, 0.9, land_t))
	if player.atk != "":
		lv = maxf(lv, 0.5)
	level = lerpf(level, lv, 1.0 - exp(-9.0 * delta))
	if fx:
		fx.level = level
		fx.spin = spin_w
	# Aufprall-Effekt am Boden
	if not flying and land_t < 0.1 and not landed_fx:
		landed_fx = true
		VFX.hammer_impact(player.get_parent(), player.global_position + Vector3(0, 0.05, 0))


# ---------------------------------------------------------------- Hammer

# Jedes Bild: Hammer am Drehpunkt ausrichten (Zugrichtung = Flugrichtung), Schlaufe, Kreisen beim Anlauf
func _process(delta: float) -> void:
	if pivot == null or not is_instance_valid(pivot):
		return
	if player.thor_weapon != "mjolnir":
		# anderer Waffenzweig: Mjolnir ruht (normaler Griff, kein Leuchten)
		fx.level = 0.0
		pivot.transform = Transform3D.IDENTITY
		cord.visible = false
		return
	var f: float = fp.fast if fp else 0.0
	var flying: bool = player.flying
	var hang := 1.0 - smoothstep(0.35, 1.0, launch_t) if flying else 0.0
	var pull := clampf(maxf(f, hang * 0.9), 0.0, 1.0) * (1.0 - flare)
	var atk: bool = player.atk != ""
	# Zielrichtung: normaler Griff, im Flug in Zugrichtung (Hammer liegt in einer Linie mit dem Arm)
	var want := ax.slerp(Vector3(0.0, 1.0, 0.0), pull)
	var sl := 0.33 * pull
	if atk:
		want = ax
		sl = 0.0
	hd = hd.slerp(want, 1.0 - exp(-10.0 * delta))
	# Anlauf: Hammer kreist senkrecht zum Arm an der Schlaufe
	var ww := clampf(wind / wind_len, 0.0, 1.0)
	var sw := 0.0
	if wind > 0.0:
		sw = smoothstep(0.0, 0.25, ww)
		spin_a += delta * lerpf(9.0, 26.0, ww)
	else:
		spin_a += delta * 20.0
	spin_w = lerpf(spin_w, sw, 1.0 - exp(-14.0 * delta))
	var dirv := hd
	if spin_w > 0.01:
		var circ := Vector3(cos(spin_a), 0.15, sin(spin_a)).normalized()
		dirv = hd.slerp(circ, spin_w)
		sl = lerpf(sl, 0.14, spin_w)
	# Leichtes Pendeln im Schwebeflug (Hammer hängt an der Schlaufe)
	var calm := (1.0 - pull) * (1.0 if flying else 0.0)
	dirv = (dirv + Vector3(0.05, 0.0, 0.04) * sin(t * 1.3) * calm + Vector3(0.03, 0.0, 0.05) * sin(t * 9.0) * pull).normalized()
	var q := Quaternion(ax, dirv)
	var bs := Basis(q)
	pivot.transform = Transform3D(bs, grip - bs * grip + dirv * sl)
	# Schlaufe von der Faust zum Griffende des Hammers
	var tail := pivot.transform * (grip - ax * 0.165)
	var gap := tail - grip
	var gl := gap.length()
	cord.visible = gl > 0.03
	if cord.visible:
		var up := gap / gl
		var side := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
		var bx := up.cross(side).normalized()
		var bz := bx.cross(up).normalized()
		cord.transform = Transform3D(Basis(bx, up * gl, bz), grip + gap * 0.5)


# ---------------------------------------------------------------- Pose

# Eine Haltung für eine Seite: ua/fa = Oberarm/Unterarm, ul/ll/ft = Oberschenkel/Unterschenkel/Fuss, lift = Schulter anheben
static func _k(ua: Vector3, fa: Vector3, ul: Vector3, ll: Vector3, ft: Vector3, lift := 0.0) -> Dictionary:
	return {"ua": ua.normalized(), "fa": fa.normalized(), "ul": ul.normalized(), "ll": ll.normalized(), "ft": ft.normalized(), "lift": lift}


# Ganze Haltung: "R" (Hammerarm, rechts), "L", dazu Rumpf: arch (Rücken zurück), fwd (Rumpf vor), twist, lean, drop/shift (Hüfte)
static func _body(r: Dictionary, l: Dictionary, arch := 0.0, fwd := 0.0, twist := 0.0, lean := 0.0, drop := 0.0, shift := 0.0, headlook := 0.0) -> Dictionary:
	return {"R": r, "L": l, "arch": arch, "fwd": fwd, "twist": twist, "lean": lean, "drop": drop, "shift": shift, "head": headlook}


func _mix(a, b, f: float):
	if f <= 0.0:
		return a
	if f >= 1.0:
		return b
	if a is Dictionary:
		var o := {}
		for k in a:
			o[k] = _mix(a[k], b[k], f)
		return o
	if a is Vector3:
		return fp._slerp(a, b, f)
	return lerpf(a, b, f)


const FOOT := Vector3(0.0, -0.84, 0.46)  # Fussspitzen gestreckt (im Flug)
const FLAT := Vector3(0.0, -0.45, 0.89)  # Fuss flach (am Boden)


# Schweben: ruhig, aufrecht, Arme locker, Hammer hängt an der Hand
func _hover() -> Dictionary:
	return _body(
		_k(Vector3(0.20, -0.98, 0.04), Vector3(0.10, -0.85, 0.52), Vector3(0.05, -1, 0.05), Vector3(0.03, -1, -0.10), FOOT),
		_k(Vector3(0.22, -0.97, -0.04), Vector3(0.14, -0.93, 0.34), Vector3(0.07, -1, -0.06), Vector3(0.03, -0.96, -0.30), Vector3(0.0, -0.95, 0.2)))


# Reiseflug: Hammerarm (rechts) ganz nach vorn gestreckt, Körper gestreckt, linker Arm angelegt, Beine locker nachgezogen
func _cruise() -> Dictionary:
	return _body(
		_k(Vector3(0.10, 0.99, 0.08), Vector3(0.04, 1.0, 0.12), Vector3(0.04, -1, -0.06), Vector3(0.02, -0.97, -0.24), FOOT, 0.30),
		_k(Vector3(0.50, -0.85, 0.06), Vector3(0.42, -0.88, 0.12), Vector3(0.10, -0.99, 0.0), Vector3(0.05, -0.90, -0.42), FOOT),
		1.0, 0.0, 0.20)


# Anflug zur Landung: der Hammer bremst (Arm nach unten/vorn), linker Arm seitlich zum Ausbalancieren, Beine strecken sich zum Boden
func _flare_p() -> Dictionary:
	return _body(
		_k(Vector3(0.25, -0.75, 0.62), Vector3(0.12, -0.7, 0.7), Vector3(0.08, -0.96, 0.26), Vector3(0.04, -0.96, -0.28), FOOT),
		_k(Vector3(0.88, -0.45, 0.12), Vector3(0.9, -0.38, 0.2), Vector3(0.10, -0.97, 0.20), Vector3(0.05, -0.95, -0.30), FOOT),
		0.0, 0.12, -0.05)


# Anlauf: Hammerarm seitlich nach hinten gestreckt (der Hammer kreist), linker Arm angewinkelt nach vorn, Oberkörper gedreht, geduckt
func _wind_p() -> Dictionary:
	return _body(
		_k(Vector3(0.96, -0.22, -0.12), Vector3(0.98, -0.10, -0.12), Vector3(0.1, -1, 0.1), Vector3(0.03, -1, -0.2), FLAT),
		_k(Vector3(0.45, -0.70, 0.55), Vector3(0.25, 0.20, 0.95), Vector3(0.1, -1, 0.1), Vector3(0.03, -1, -0.2), FLAT),
		0.0, 0.28, -0.55, 0.0, 0.17, 0.04, 0.2)


# Landehocke: Hammerarm seitlich weg, Hand am Boden (per IK in apply), tief geduckt, Blick nach vorn
func _land_p() -> Dictionary:
	return _body(
		_k(Vector3(0.90, -0.40, -0.22), Vector3(0.88, -0.15, -0.35), Vector3(0.1, -1, 0.1), Vector3(0.03, -1, -0.2), FLAT),
		_k(Vector3(0.25, -0.85, 0.45), Vector3(0.15, -0.80, 0.55), Vector3(0.1, -1, 0.1), Vector3(0.03, -1, -0.2), FLAT),
		0.0, 1.15, -0.12, 0.0, 0.57, 0.30, 0.4)


# Richtung (aussen, oben, vorn) -> Skelettraum (+X links)
static func _d(s: float, v: Vector3) -> Vector3:
	return Vector3(s * v.x, v.y, v.z).normalized()


func apply() -> void:
	var w: float = fp.weight
	if not is_instance_valid(skel) or w < 0.001:
		return
	for b in fp.all_bones:
		anim_rot[b] = skel.get_bone_pose_rotation(b)
		skel.set_bone_pose_rotation(b, skel.get_bone_rest(b).basis.get_rotation_quaternion())
	anim_hips = skel.get_bone_pose_position(hips)

	var f := clampf(fp.fast, 0.0, 1.0)
	var flying: bool = player.flying
	var hang := 1.0 - smoothstep(0.35, 1.0, launch_t) if flying else 0.0
	var fc := clampf(maxf(f, hang * 0.9), 0.0, 1.0)
	var wd := smoothstep(0.0, 0.3, wind / wind_len) if wind > 0.0 else 0.0
	var cr := crouch
	var fl := flare
	var ph: float = fp.t
	# Haltung mischen: Schweben -> Reiseflug -> Anflug -> Anlauf -> Landehocke
	var p: Dictionary = _mix(_hover(), _cruise(), fc)
	p = _mix(p, _flare_p(), fl)
	p = _mix(p, _wind_p(), wd)
	p = _mix(p, _land_p(), cr)
	var ik_w := maxf(wd, cr)  # Beine per IK am Boden (Hocke)
	var calm := 1.0 - fc * 0.55

	# Hüfte tiefer / nach vorn (Hocke)
	var drop: float = p["drop"] * w
	var shift: float = p["shift"] * w
	skel.set_bone_pose_position(hips, anim_hips + Vector3(0.0, -drop, shift))

	# Rumpf: Verdrehung und seitliche Neigung (Kurve), Vorbeuge (Hocke), Rücken zurück (Flug)
	var trunk: Array = fp.trunk
	var tw: float = p["twist"] + turn * 0.12
	var ln: float = p["lean"] + turn * 0.22
	var fw: float = p["fwd"]
	var arch: float = p["arch"]
	var twist_w := [0.35, 0.40, 0.25, 0.0, 0.0]
	var fwd_w := [0.35, 0.35, 0.30, -0.45, -0.55]  # Kopf gleicht die Vorbeuge aus
	for i in range(trunk.size()):
		var b: int = trunk[i]
		if absf(tw * twist_w[i]) > 0.0001:
			fp._turn(b, Basis(Vector3.UP, tw * twist_w[i]))
		if absf(ln) > 0.0001 and i < 4:
			fp._turn(b, Basis(Vector3(0, 0, 1), ln * (0.25 if i < 3 else 0.2)))
		var a: float = ARCH[i] * arch + fw * fwd_w[i]
		a -= float(p["head"]) * [0.0, 0.0, 0.0, 0.4, 0.6][i]  # Blick nach oben
		if i == 1:
			a += 0.05 * arch
		if absf(a) > 0.0001:
			fp._turn(b, Basis(Vector3.RIGHT, a))
	# Drehung der Brust (für die Arme: sie folgen der Verdrehung)
	var tb := Basis(Vector3.UP, tw * 0.9) * Basis(Vector3(0, 0, 1), ln * 0.5)

	# Glieder
	var ik_t := _stance(cr / maxf(wd + cr, 0.001))
	for L in fp.limbs:
		var s: float = L["sign"]
		var left: bool = L["left"]
		var k: Dictionary = p["L"] if left else p["R"]
		var ph2 := 0.0 if left else 1.7
		var w1 := sin(ph * 1.3 + ph2) * 0.03 * calm
		var w2 := sin(ph * 1.1 + ph2 + 1.3) * 0.025 * calm
		if k["lift"] != 0.0:
			fp._turn(L["Shoulder"], Basis(Vector3(0, 0, 1), s * k["lift"]))
		var ua: Vector3 = tb * _d(s, k["ua"])
		var fa: Vector3 = tb * _d(s, k["fa"])
		ua = (ua + Vector3(0, 0, w1)).normalized()
		fa = (fa + Vector3(0, 0, w2)).normalized()
		# Hand am Boden (Landehocke, linke Hand)
		var arm_ik := 0.0
		if left and cr > 0.01:
			arm_ik = cr
		fp._aim(L["Arm"], L["ForeArm"], ua)
		fp._aim(L["ForeArm"], L["Hand"], fa)
		if arm_ik > 0.01:
			_arm_ik(L, arm_ik, Vector3(0.30, 0.02, 0.50), ua, fa)
		# Beine
		var ul := _d(s, k["ul"])
		var ll := _d(s, k["ll"])
		# Kurve: Beine schwingen nach aussen (zur Seite der Kurve weg)
		ul = (ul + Vector3(turn * 0.20 * f, 0, 0)).normalized()
		ll = (ll + Vector3(turn * 0.35 * f, 0, 0)).normalized()
		ul = (ul + Vector3(0, 0, w2 * 0.6)).normalized()
		ll = (ll + Vector3(0, 0, w1 * 0.6)).normalized()
		if ik_w > 0.01:
			var hip: Vector3 = skel.get_bone_global_pose(L["UpLeg"]).origin
			var tgt: Vector3 = ik_t["L" if left else "R"]
			var d2 := _leg_dirs(hip, tgt)
			ul = fp._slerp(ul, d2[0], ik_w)
			ll = fp._slerp(ll, d2[1], ik_w)
		fp._aim(L["UpLeg"], L["Leg"], ul)
		fp._aim(L["Leg"], L["Foot"], ll)
		fp._aim(L["Foot"], L["ToeBase"], _d(s, k["ft"]))
	# Zurückblenden auf die Animation
	for b in fp.all_bones:
		var q: Quaternion = anim_rot[b]
		skel.set_bone_pose_rotation(b, q.slerp(skel.get_bone_pose_rotation(b), w))


# Zielpunkte der Knöchel (Skelettraum) für Anlauf-Hocke (m = 0) und Landehocke (m = 1)
func _stance(m: float) -> Dictionary:
	var wr := Vector3(-0.15, 0.105, 0.0)
	var wl := Vector3(0.15, 0.105, 0.10)
	var lr := Vector3(-0.15, 0.17, -0.40)
	var ll := Vector3(0.17, 0.105, 0.26)
	return {"R": wr.lerp(lr, m), "L": wl.lerp(ll, m)}


# Zwei-Gelenk-IK für ein Bein: Richtungen von Oberschenkel und Unterschenkel, Knie zeigt nach vorn
func _leg_dirs(hip: Vector3, ankle: Vector3) -> Array:
	var to := ankle - hip
	var d := clampf(to.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.003)
	var dir := to.normalized()
	var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - a * a, 0.0))
	var pole := Vector3(0, -0.15, 1.0)
	var pp := pole - dir * pole.dot(dir)
	if pp.length() < 0.001:
		pp = Vector3(0, 0, 1)
	var knee := hip + dir * a + pp.normalized() * h
	return [(knee - hip).normalized(), (hip + dir * d - knee).normalized()]


# Arm per IK zum Zielpunkt (linke Hand am Boden), Mischung mit der vorhandenen Haltung
func _arm_ik(L: Dictionary, wt: float, target: Vector3, ua: Vector3, fa: Vector3) -> void:
	var sh: Vector3 = skel.get_bone_global_pose(L["Arm"]).origin
	var to := target - sh
	var d := clampf(to.length(), absf(a1 - a2) + 0.01, a1 + a2 - 0.003)
	var dir := to.normalized()
	var a := (a1 * a1 - a2 * a2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(a1 * a1 - a * a, 0.0))
	var pole := Vector3(0.5, 0.2, -0.8)  # Ellbogen zeigt nach aussen/hinten
	var pp := pole - dir * pole.dot(dir)
	var el := sh + dir * a + pp.normalized() * h
	var d1: Vector3 = fp._slerp(ua, (el - sh).normalized(), wt)
	fp._aim(L["Arm"], L["ForeArm"], d1)
	var el2: Vector3 = skel.get_bone_global_pose(L["ForeArm"]).origin
	var d2: Vector3 = fp._slerp(fa, ((sh + dir * d) - el2).normalized(), wt)
	fp._aim(L["ForeArm"], L["Hand"], d2)
