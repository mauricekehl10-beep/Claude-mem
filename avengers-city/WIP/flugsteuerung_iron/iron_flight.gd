extends Node
# Flugsteuerung Iron Man (Schub statt "Tempo setzen"). Thor fliegt weiter mit player.gd (fly_move).
#
# Prinzip:
#  - Die Maus gibt die Flugrichtung frei im Raum vor (Kamera-Blick). Die Figur ("heading") dreht sich mit begrenzter Drehrate dorthin,
#    je schneller, desto träger. Die Kurve gibt Rollen (Kurvenneigung), die Bewegungsrichtung folgt der Blickrichtung mit "Griff".
#  - W / Shift = Schub entlang der Blickrichtung (Beschleunigung, nähert sich dem Höchsttempo), Shift = Nachbrenner mit Anlauf.
#  - Ohne Schub gleitet er aus und stabilisiert sich per Repulsoren (Schweben). S = Luftbremse, dann Rückwärtsschub. Strg+W = Luftbremse.
#  - A/D = seitlich, Leertaste/Strg = senkrecht. Alt oder A/D doppelt tippen = Ausweich-Dash (mit Rolle).
#  - Langsam und sinkend nahe am Boden: automatische Landung (Animation in iron_pose.gd). Wände: Abprallen und Entlanggleiten.
# Der Player ruft move() jeden Physik-Schritt auf, camera() statt seiner Kamera und update_pose() kommt aus iron_pose.gd.

const Wind = preload("res://scripts/iron_wind.gd")
const VFX = preload("res://scripts/vfx.gd")

const V_CRUISE := 30.0  # Reisetempo (m/s)
const V_BOOST := 62.0  # Höchsttempo mit Nachbrenner
const A_THRUST := 28.0  # Schub (m/s²)
const A_BOOST := 66.0
const BOOST_UP := 0.85  # so lange dauert der Anlauf des Nachbrenners (s)
const BOOST_DOWN := 0.9
const V_SIDE := 13.0  # seitliches Ausweichen
const A_SIDE := 42.0
const V_VERT := 14.0  # Steigen/Sinken mit Leertaste/Strg
const A_VERT := 36.0
const V_REV := 9.0  # Rückwärtsflug
const A_REV := 16.0
const DASH_V := 34.0
const DASH_K := 5.5  # so schnell verklingt der Dash
const DASH_T := 0.55  # Dauer der Rolle
const DASH_CD := 1.1  # Wartezeit zwischen Dashes
const TAP_DASH := 0.26  # Doppeltipp A/D
const HOLD_START := 0.38  # Leertaste so lange halten = Raketenstart
const CAM_Z := 5.0

var pl  # Spielfigur (player.gd)
var fp  # Flugpose (iron_pose.gd)
var wind  # Windlinien und Anzeige (iron_wind.gd)

var heading := Vector3(0, 0, -1)  # Blickrichtung der Figur (weich zur Kamera gedreht)
var v_main := Vector3.ZERO  # Schwung (folgt der Blickrichtung)
var side := 0.0  # seitlicher Schub (m/s, entlang rechts der Kamera)
var lift := 0.0  # senkrechter Schub (m/s)
var dash_v := Vector3.ZERO
var boost := 0.0  # 0..1, Nachbrenner (mit Anlauf)
var gd := 99.0  # Höhe über dem Boden
var yaw_rate := 0.0  # Drehrate der Blickrichtung um die Hochachse (+ = nach links)
var az_prev := 0.0
var az_ok := false
var bank := 0.0  # Kurvenneigung (Radiant, + = nach rechts rollen)
var bank_v := 0.0
var dash_t := -1.0
var dash_dir := 0.0
var dash_barrel := false
var dash_cd := 0.0
var tap_l := 9.0
var tap_r := 9.0
var land_amt := 0.0  # Landeanflug 0..1
var brake_amt := 0.0
var hov_w := 0.0  # Schweben: Korrekturschwankungen
var floor_vy := 0.0  # Tempo beim Aufprall am Boden
var shake := 0.0
var fov_kick := 0.0
var cam_w := 0.0  # 0..1: Flugkamera aktiv
var fx_cd := 0.0
var hold := 0.0
var hold_used := false
var shifted := Vector3.ZERO  # Glättung der Darstellung (siehe _process)
var up_in := 0.0
var last_by_t := 0.0


func setup(p, f) -> void:
	pl = p
	fp = f
	process_priority = -100
	if not InputMap.has_action("dash"):
		InputMap.add_action("dash")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_ALT
		InputMap.action_add_event("dash", ev)
	if not OS.has_environment("NOWIND"):
		wind = Wind.new()
	if wind:
		add_child(wind)
	reset()


func _exit_tree() -> void:
	unshift()


func reset() -> void:
	unshift()
	v_main = Vector3.ZERO
	side = 0.0
	lift = 0.0
	dash_v = Vector3.ZERO
	boost = 0.0
	bank = 0.0
	bank_v = 0.0
	yaw_rate = 0.0
	az_ok = false
	dash_t = -1.0
	dash_cd = 0.0
	land_amt = 0.0
	brake_amt = 0.0
	hov_w = 0.0
	shake = 0.0
	fov_kick = 0.0
	hold = 0.0
	hold_used = false
	if wind:
		wind.show_state(0.0, false, 0.0, 0.0, 0.0, Vector2.ZERO)


# Flug beginnt (Doppeltipp, Raketenstart, Heldenwechsel in der Luft)
func begin(p) -> void:
	pl = p
	unshift()
	v_main = pl.velocity
	side = 0.0
	lift = 0.0
	dash_v = Vector3.ZERO
	boost = 0.0
	bank = 0.0
	bank_v = 0.0
	land_amt = 0.0
	dash_t = -1.0
	az_ok = false
	heading = _aim_dir()


# Darf der Held jetzt stehen bleiben (Landung)? Aufruf von player.gd, wenn der Boden berührt wird.
func may_land() -> bool:
	if Input.is_action_pressed("jump") and land_amt < 0.25:
		return false
	return land_amt > 0.25 or floor_vy < -12.0 or pl.velocity.length() < 4.0


# Doppeltipp Leertaste beendet den Flug nur bei geringem Tempo (kein versehentliches Abstürzen im Flug)
func can_stop() -> bool:
	return pl.velocity.length() < 12.0


# Leertaste halten (am Boden oder im Sprung): Raketenstart. Gibt true zurück, wenn gestartet werden soll.
func hold_launch(delta: float) -> bool:
	if Input.is_action_pressed("jump"):
		hold += delta
		if hold > HOLD_START and not hold_used:
			hold_used = true
			return true
	else:
		hold = 0.0
		hold_used = false
	return false


func _aim_dir() -> Vector3:
	return (-pl.pitch_pivot.global_transform.basis.z).normalized()


# ---------------------------------------------------------------- Darstellung zwischen zwei Physik-Schritten

# Die Physik läuft mit 60 Hz, das Bild oft schneller: bei 60 m/s würde die Figur ruckeln. Darum schiebt _process die Figur
# zwischen den Physik-Schritten ein Stück weiter (Vorausschau). Am Anfang des nächsten Schritts nimmt unshift() es zurück.
func _process(delta: float) -> void:
	if pl == null or not is_instance_valid(pl):
		return
	var on: bool = pl.flying and pl.active
	var off := Vector3.ZERO
	if on:
		off = (pl.velocity * (Engine.get_physics_interpolation_fraction() / float(Engine.physics_ticks_per_second)))
	if off != shifted and not OS.has_environment("NOSHIFT"):
		pl.global_position += off - shifted
		shifted = off
	if wind:
		var cb: Basis = pl.cam.global_transform.basis
		var lv: Vector3 = cb.inverse() * pl.velocity
		var d2 := Vector2.ZERO
		if lv.length() > 1.0:
			d2 = Vector2(lv.x, -lv.y) / lv.length()
		wind.show_state(delta, on, pl.velocity.length(), pl.global_position.y, boost, d2)


func unshift() -> void:
	if pl and is_instance_valid(pl) and shifted != Vector3.ZERO:
		pl.global_position -= shifted
	shifted = Vector3.ZERO


# ---------------------------------------------------------------- Flugphysik (jeder Physik-Schritt)

func move(delta: float) -> void:
	pl.jump_t = -1.0
	var t: float = pl.hover_t
	var fi: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var key_w := fi.y < -0.3
	var key_s := fi.y > 0.3
	var ctrl := Input.is_action_pressed("descend")
	var space := Input.is_action_pressed("jump")
	var shift := Input.is_action_pressed("sprint")
	var brake := key_s or (ctrl and key_w)
	var launching: bool = fp != null and fp.launching
	var lock: bool = launching and fp.launch_t < 0.55  # beim Start erst senkrecht hoch
	var thrust := (key_w or shift) and not brake and not lock
	gd = fp._ground_dist(pl) if fp else 99.0

	# Nachbrenner: Anlauf über ~1 s
	var was_boost := boost
	var boost_goal := 1.0 if (shift and not brake and not lock) else 0.0
	boost = move_toward(boost, boost_goal, delta / (BOOST_UP if boost_goal > boost else BOOST_DOWN))
	if boost_goal > 0.5 and was_boost < 0.05:
		fov_kick = 7.0
	pl.fly_boost = boost

	# Blickrichtung: Kamera, mit Drehrate (je schneller, desto träger)
	var sp := v_main.length()
	var sfs := clampf(sp / V_BOOST, 0.0, 1.0)
	var want_h := _aim_dir()
	var ang := heading.angle_to(want_h)
	if ang > 0.0005:
		var cap := lerpf(8.0, 2.4, sfs)
		var kf := lerpf(11.0, 5.0, sfs)
		var step := minf(ang * (1.0 - exp(-kf * delta)), cap * delta)
		heading = heading.slerp(want_h, step / ang).normalized()
	var hxz := Vector2(heading.x, heading.z)
	var yr := 0.0
	if hxz.length() > 0.25:
		var az := atan2(-heading.x, -heading.z)
		if az_ok:
			yr = angle_difference(az_prev, az) / delta
		az_prev = az
		az_ok = true
		last_by_t = az
	else:
		az_ok = false
		last_by_t = pl.yaw
	yaw_rate = lerpf(yaw_rate, yr, 1.0 - exp(-14.0 * delta))
	pl.body_yaw = lerp_angle(pl.body_yaw, last_by_t, 1.0 - exp(-18.0 * delta))

	# Kurvenneigung (Rollen) als Feder: leichtes Überschwingen
	var bank_t := clampf(-yaw_rate * 0.36, -1.1, 1.1) * smoothstep(6.0, 20.0, sp)
	bank_v += ((bank_t - bank) * 80.0 - bank_v * 11.0) * delta
	bank += bank_v * delta

	# Ausweich-Dash
	_dash(fi, key_s, delta)

	# Schwung
	var fwd_speed := v_main.dot(heading)
	var vmax := lerpf(V_CRUISE, V_BOOST, boost)
	var acc := lerpf(A_THRUST, A_BOOST, boost)
	var dirv := v_main / sp if sp > 0.01 else heading
	var hsp := Vector2(v_main.x, v_main.z).length()
	var vy_total := v_main.y + lift
	var dive := thrust and heading.y < -0.45 and sp > 22.0
	var want_land := gd < 4.5 and hsp < 12.0 and boost < 0.25 and not thrust and not space and not launching and (ctrl or vy_total < -0.7)
	brake_amt = 0.0
	if thrust:
		var fs := clampf(fwd_speed, 0.0, vmax)
		var a := acc * (1.0 - fs * fs / (vmax * vmax))
		if fwd_speed < 0.0:
			a = acc * 1.3  # Wende: voller Schub gegen die alte Richtung
		v_main += heading * a * delta
		sp = v_main.length()
		if sp > vmax * 1.01:
			v_main -= (v_main / sp) * ((sp - vmax) * 0.55 + 2.0) * delta  # zu schnell (Nachbrenner aus): sanft abbauen
		_grip(delta, lerpf(5.5, 3.4, boost))
	elif brake:
		brake_amt = 1.0
		var dec := 46.0 + sp * 0.5
		sp = maxf(sp - dec * delta, 0.0)
		v_main = dirv * sp
		if key_s and not (ctrl and key_w) and sp < 6.0:
			v_main -= heading * A_REV * delta  # danach Rückwärtsschub
			var back := -heading
			var bs := v_main.dot(back)
			if bs > V_REV:
				v_main -= back * (bs - V_REV)
	else:
		# Ausgleiten, Repulsoren stabilisieren: je langsamer, desto fester
		var dec := sp * 0.8 + 3.0
		if sp < 5.0:
			dec += 6.0
		sp = maxf(sp - dec * delta, 0.0)
		v_main = dirv * sp
		_grip(delta, 1.2 * smoothstep(8.0, 20.0, sp))
	if want_land:
		# Landeanflug: weich sinken, waagerecht stehen bleiben
		var vt := -(0.9 + gd * 1.2)
		v_main.y = move_toward(v_main.y, vt, 18.0 * delta)
		v_main.x *= exp(-1.8 * delta)
		v_main.z *= exp(-1.8 * delta)
		v_main.y += lift  # Sinken per Strg geht nahtlos in den Landeanflug über
		lift = 0.0
	land_amt = move_toward(land_amt, 1.0 if want_land else 0.0, 3.5 * delta)

	# Seitlich und senkrecht (Repulsoren)
	var cam_right := Vector3(cos(pl.yaw), 0.0, -sin(pl.yaw))
	var side_t := fi.x * V_SIDE
	side = move_toward(side, side_t, (A_SIDE if absf(fi.x) > 0.1 else A_SIDE * 0.7) * delta)
	up_in = (1.0 if space else 0.0) - (1.0 if (ctrl and not key_w) else 0.0)
	if not want_land:
		var lift_t := up_in * V_VERT
		lift = move_toward(lift, lift_t, (A_VERT if absf(up_in) > 0.1 else A_VERT * 0.65) * delta)
	if launching:
		# Raketenstart: kräftig senkrecht hoch
		var lt: float = fp.launch_t
		var tgt := (7.0 + 14.0 * smoothstep(0.0, 0.5, lt)) * (1.0 - 0.35 * smoothstep(0.7, 1.2, lt))
		if lift < tgt:
			lift = move_toward(lift, tgt, 46.0 * delta)
	# Bodennähe: die Repulsoren fangen ihn ab (Bodeneffekt: je näher am Boden, desto langsamer darf er sinken),
	# ausser beim Landeanflug und beim gewollten Sturzflug
	if not want_land and not dive and gd < 14.0:
		var min_vy := minf(-(gd - 0.6) * 1.1, 3.0)
		var vyt := v_main.y + lift
		if vyt < min_vy:
			var need := min_vy - vyt
			var from_lift := minf(need, maxf(-lift, 0.0))  # erst das Sinken per Strg zurücknehmen
			lift += from_lift
			v_main.y += need - from_lift
	dash_v *= exp(-DASH_K * delta)
	if dash_v.length() < 0.4:
		dash_v = Vector3.ZERO

	# Schweben: kleine Korrekturschwankungen
	var calm := not thrust and not brake and absf(fi.x) < 0.1 and absf(up_in) < 0.1 and sp < 3.0 and not want_land
	hov_w = move_toward(hov_w, 1.0 if calm else 0.0, 2.0 * delta)
	var jit := Vector3(sin(t * 1.7 + 0.3) * 0.34 + sin(t * 3.1) * 0.10, sin(t * 2.3 + 1.0) * 0.26, cos(t * 1.3 + 2.0) * 0.32 + sin(t * 2.7) * 0.08) * hov_w

	# Spielfeldgrenzen: nicht ins Weltall, nicht von der Karte
	var gp: Vector3 = pl.global_position
	if gp.y > 420.0 and v_main.y > 0.0:
		v_main.y = 0.0
		lift = minf(lift, 0.0)
	if absf(gp.x) > 1100.0 and signf(v_main.x) == signf(gp.x):
		v_main.x = 0.0
	if absf(gp.z) > 1100.0 and signf(v_main.z) == signf(gp.z):
		v_main.z = 0.0

	var vel := v_main + cam_right * side + Vector3.UP * lift + dash_v + jit
	pl.velocity = vel
	pl.last_vy = vel.y
	pl.move_and_slide()
	_collide(vel, delta)
	pl.update_camera(delta)
	pl.animate(delta)


# Bewegungsrichtung dreht zur Blickrichtung (Tempo bleibt, nur in engen Kurven geht etwas verloren)
func _grip(delta: float, rate: float) -> void:
	var sp := v_main.length()
	if sp < 0.5 or rate < 0.01:
		return
	var d := v_main / sp
	var ang := d.angle_to(heading)
	if ang < 0.001 or ang > 2.8:
		return
	var step := ang * (1.0 - exp(-rate * delta))
	v_main = d.slerp(heading, step / ang).normalized() * sp * (1.0 - 0.08 * step)


func _clip(v: Vector3, n: Vector3) -> Vector3:
	return v - n * minf(v.dot(n), 0.0)


# Wand, Dach, Boden: Anteil in die Wand weg, kleines Abprallen bei hartem Aufprall, sonst Entlanggleiten
func _collide(pre: Vector3, delta: float) -> void:
	fx_cd = maxf(fx_cd - delta, 0.0)
	floor_vy = pre.y if pl.is_on_floor() else 0.0
	var cnt: int = pl.get_slide_collision_count()
	if cnt == 0:
		return
	var cam_right := Vector3(cos(pl.yaw), 0.0, -sin(pl.yaw))
	var impact := 0.0
	var hit_n := Vector3.UP
	var hit_p := Vector3.ZERO
	for i in range(cnt):
		var c = pl.get_slide_collision(i)
		var n: Vector3 = c.get_normal()
		var into := -pre.dot(n)
		if into > impact:
			impact = into
			hit_n = n
			hit_p = c.get_position()
		v_main = _clip(v_main, n)
		dash_v = _clip(dash_v, n)
		side = _clip(cam_right * side, n).dot(cam_right)
		lift = _clip(Vector3.UP * lift, n).y
	if impact > 8.0 and hit_n.y < 0.7:
		v_main += hit_n * minf(impact * 0.2, 5.0)  # kleines Abprallen von der Wand
	elif impact < 4.0:
		v_main *= exp(-0.6 * delta)  # Entlangschleifen kostet etwas Tempo
	if impact > 10.0:
		shake = maxf(shake, clampf(impact / 45.0, 0.2, 1.0))
		boost = maxf(boost - impact / 40.0, 0.0)
		if fx_cd <= 0.0 and impact > 14.0:
			fx_cd = 0.25
			VFX.impact(pl.get_parent(), hit_p, hit_n)


# ---------------------------------------------------------------- Ausweich-Dash

func _dash(fi: Vector2, key_s: bool, delta: float) -> void:
	dash_cd = maxf(dash_cd - delta, 0.0)
	tap_l += delta
	tap_r += delta
	var dir := 0.0
	var kind := ""
	if Input.is_action_just_pressed("move_left"):
		if tap_l < TAP_DASH:
			dir = -1.0
			kind = "side"
			tap_l = 9.0
		else:
			tap_l = 0.0
	if Input.is_action_just_pressed("move_right"):
		if tap_r < TAP_DASH:
			dir = 1.0
			kind = "side"
			tap_r = 9.0
		else:
			tap_r = 0.0
	if Input.is_action_just_pressed("dash"):
		if absf(fi.x) > 0.3:
			dir = signf(fi.x)
			kind = "side"
		elif key_s:
			kind = "back"
		else:
			kind = "fwd"
	if kind != "" and dash_cd <= 0.0 and dash_t < 0.0:
		dash_cd = DASH_CD
		fov_kick = 6.0
		var cam_right := Vector3(cos(pl.yaw), 0.0, -sin(pl.yaw))
		if kind == "side":
			dash_v = cam_right * dir * DASH_V
			dash_dir = dir
			dash_t = 0.0
			dash_barrel = fp != null and fp.s_f > 0.5
		elif kind == "back":
			dash_v = -heading * 26.0
			fov_kick = 2.0
		else:
			dash_v = heading * 26.0
	if dash_t >= 0.0:
		dash_t += delta
		if dash_t >= DASH_T:
			dash_t = -1.0


# Fortschritt des Dashs 0..1 (-1 = kein Dash)
func dash_p() -> float:
	return dash_t / DASH_T if dash_t >= 0.0 else -1.0


# ---------------------------------------------------------------- Kamera

# Tempoabhängiger Abstand und Sichtfeld, weiches Nachziehen, leichtes Wackeln. Bleibt waagerecht (kein Rollen).
# Gibt false zurück, wenn der Player seine normale Kamera nehmen soll (kein Flug mehr).
func camera(delta: float) -> bool:
	var on: bool = pl.flying
	cam_w = move_toward(cam_w, 1.0 if on else 0.0, delta * (5.0 if on else 3.0))
	if cam_w < 0.002:
		return false
	var cam: Camera3D = pl.cam
	var w := cam_w
	var vel: Vector3 = pl.velocity
	var sk := clampf((vel.length() - 4.0) / 56.0, 0.0, 1.0)
	fov_kick = maxf(fov_kick - 22.0 * delta, 0.0)
	var fov_t: float = 75.0 + (20.0 * sk + 5.0 * boost + fov_kick) * w
	cam.fov = lerpf(cam.fov, fov_t, 1.0 - exp(-5.0 * delta))
	pl.cam_vel = pl.cam_vel.lerp(vel, 1.0 - exp(-3.5 * delta))
	var lag_w: Vector3 = ((pl.cam_vel - vel) * 0.075 * w).limit_length(1.7)
	var lag: Vector3 = pl.pitch_pivot.global_transform.basis.inverse() * lag_w
	pl.cam_lag = pl.cam_lag.lerp(lag, 1.0 - exp(-10.0 * delta))
	var want: Vector3 = Vector3(0.6, 0.3 + 0.15 * sk * w, CAM_Z * (1.0 + (0.16 * sk + 0.08 * boost) * w)) + pl.cam_lag
	# Wand zwischen Kopf und Kamera: Kamera rückt heran (schnell), danach wieder zurück (langsam)
	var origin: Vector3 = pl.pitch_pivot.global_position
	var target_w: Vector3 = pl.pitch_pivot.global_transform * want
	var ex: Array = [pl.get_rid()]
	for e in pl.get_tree().get_nodes_in_group("enemies"):
		ex.append(e.get_rid())
	var q := PhysicsRayQueryParameters3D.create(origin, target_w)
	q.exclude = ex
	var hit: Dictionary = pl.get_world_3d().direct_space_state.intersect_ray(q)
	var ratio := 1.0
	if not hit.is_empty():
		ratio = clampf((origin.distance_to(hit["position"]) - 0.4) / maxf(origin.distance_to(target_w), 0.01), 0.1, 1.0)
	pl.cam_dist = ratio if ratio < pl.cam_dist else lerpf(pl.cam_dist, ratio, 1.0 - exp(-2.5 * delta))
	cam.position = want * pl.cam_dist
	shake = maxf(shake - 2.6 * delta, 0.0)
	var sh := (0.03 * boost * (0.4 + 0.6 * sk) + 0.09 * shake * shake) * w
	var tt: float = pl.hover_t
	cam.h_offset = (sin(tt * 37.0) + 0.6 * sin(tt * 23.0 + 1.0)) * sh
	cam.v_offset = sin(tt * 31.0 + 2.0) * sh
	return true


# ---------------------------------------------------------------- Körperhaltung (aus iron_pose.update_body)

func update_pose(delta: float) -> void:
	var sc: float = pl.HEROES[1]["scale"]
	var vel: Vector3 = pl.velocity
	var vh := Vector3(vel.x, 0.0, vel.z)
	var sp := vel.length()
	var by: float = pl.body_yaw
	var face := Vector3(-sin(by), 0.0, -cos(by))
	var rgt := Vector3(cos(by), 0.0, -sin(by))
	var t: float = pl.hover_t
	fp.t = t
	fp.gd = gd
	# Start: erst aufrecht steigen, dann in den Flug kippen
	var rise_t := 0.0
	if fp.launching:
		fp.launch_t += delta
		rise_t = 1.0 - smoothstep(0.45, 1.15, fp.launch_t)
		if fp.launch_t > 1.2:
			fp.launching = false
	var br_t := brake_amt * smoothstep(4.0, 10.0, sp)
	var flare_t := land_amt * (1.0 - smoothstep(2.5, 4.5, gd))
	var flat_t := (1.0 - smoothstep(0.5, 2.2, gd)) * (1.0 if vel.y < 0.6 else 0.0)
	var climb := smoothstep(2.0, 8.0, vel.y)
	var fwd_v := maxf(v_main.dot(heading), 0.0)
	var fast_t := smoothstep(5.0, 19.0, fwd_v) * (1.0 - rise_t) * (1.0 - flare_t) * (1.0 - 0.7 * br_t)
	var elev_t := asin(clampf(heading.y, -1.0, 1.0))
	var tilt_t := clampf(vh.dot(face) / 14.0, -1.0, 1.0) * 0.34 * (1.0 - rise_t)
	var side_t := clampf(vh.dot(rgt) / 12.0, -1.0, 1.0) * 0.32 * (1.0 - rise_t)
	var dp := dash_p()
	if dp >= 0.0 and not dash_barrel:
		side_t += dash_dir * 0.5 * sin(PI * dp)  # aus dem Schweben: seitlich wegkippen
	var lam_t := fast_t * (PI * 0.5 - elev_t) + tilt_t * (1.0 - fast_t)
	lam_t -= 0.34 * br_t + 0.14 * flare_t  # Bremsen und Abfangen: Körper kippt zurück, Füsse nach vorn
	var kk := 1.0 - exp(-5.5 * delta)
	fp.lam = lerpf(fp.lam, lam_t, kk)
	fp.s_f = lerpf(fp.s_f, fast_t, 1.0 - exp(-4.5 * delta))
	fp.s_b = lerpf(fp.s_b, boost, 1.0 - exp(-6.0 * delta))
	fp.s_br = lerpf(fp.s_br, br_t, 1.0 - exp(-(10.0 if br_t > fp.s_br else 2.2) * delta))
	fp.s_rise = lerpf(fp.s_rise, maxf(rise_t, climb * 0.7 * (1.0 - fp.s_f)), 1.0 - exp(-6.0 * delta))
	fp.s_flare = lerpf(fp.s_flare, flare_t, 1.0 - exp(-5.0 * delta))
	fp.s_flat = lerpf(fp.s_flat, flat_t, 1.0 - exp(-7.0 * delta))
	fp.s_stand = lerpf(fp.s_stand, 0.0, 1.0 - exp(-8.0 * delta))
	fp.s_bank = lerpf(fp.s_bank, clampf(bank / 0.95, -1.0, 1.0), 1.0 - exp(-5.0 * delta))
	fp.c_soft = move_toward(fp.c_soft, 0.0, 6.0 * delta)
	fp.c_hero = move_toward(fp.c_hero, 0.0, 6.0 * delta)
	fp.plant = move_toward(fp.plant, 0.0, 8.0 * delta)
	fp.land_t = -1.0
	fp.weight = move_toward(fp.weight, 1.0, 4.0 * delta)
	fp.fast = fp.s_f
	# Werte für den Rest des Spiels (Kamera, Effekte)
	pl.fly_fast = fp.s_f
	pl.elev = lerpf(pl.elev, elev_t, 1.0 - exp(-5.0 * delta))
	pl.tilt = lerpf(pl.tilt, tilt_t, 1.0 - exp(-5.0 * delta))
	pl.side_tilt = lerpf(pl.side_tilt, side_t, 1.0 - exp(-5.0 * delta))
	pl.bank = bank
	var hover: float = fp.weight * (1.0 - fp.s_f)
	var l2: float = fp.lam + sin(t * 1.1) * 0.02 * hover
	var roll: float = bank * fp.s_f
	if dp >= 0.0 and dash_barrel:
		roll += dash_dir * TAU * smoothstep(0.0, 1.0, dp)  # Fassrolle
	var rot := Basis(Vector3.UP, by) * Basis(Vector3.RIGHT, -l2)
	rot = rot * Basis(Vector3(0, 0, 1), -pl.side_tilt * (1.0 - fp.s_f)) * Basis(Vector3.UP, roll)
	pl.model.basis = rot * Basis.from_scale(Vector3.ONE * sc)
	var pv := Vector3(0, sc, 0)
	pl.model.position = pv - rot * pv + Vector3(0, sin(t * 1.7) * 0.04 * hover, 0)
