extends Node
# Thors Waffen: Mjolnir und Stormbreaker. Taste Q wechselt (kurze Animation, Blitz, Bifrost-Strahl bei Stormbreaker).
# Dieser Knoten hängt am Modell von Thor (player.gd baut ihn in build_mixamo) und macht:
#  - Waffe in der Hand zeigen/verstecken (Mjolnir-Meshes: Kinder von A_mixamorig_RightHand oder Gruppe "mjolnir"; Axt: A_Storm)
#  - Stormbreaker: Flugpose (fly_pose_storm.gd), Angriffs-Posen (storm_attack.gd), Axtschlag, Axtwurf mit Rückkehr, Effekte
#  - Bifrost-Strahl (bifrost.gd) beim Wechsel zu Stormbreaker, beim Start und bei der Landung nach dem Flug
#  - die HUD-Zeile mit der aktuellen Waffe
# player.gd ruft nur kleine Haken auf (map_attack, can_throw, attack_hit, lean_scale, on_fly_start, on_land, reset).

const VFX = preload("res://scripts/vfx.gd")
const Rig = preload("res://scripts/storm_rig.gd")
const Stormbreaker = preload("res://scripts/stormbreaker.gd")
const FlyPoseStorm = preload("res://scripts/fly_pose_storm.gd")
const StormAttack = preload("res://scripts/storm_attack.gd")
const StormFx = preload("res://scripts/storm_fx.gd")
const StormTrail = preload("res://scripts/storm_trail.gd")
const Bifrost = preload("res://scripts/bifrost.gd")

const THROW_SPEED := 62.0
const THROW_RANGE := 36.0
const BACK_SPEED := 26.0  # Anfangstempo der Rückkehr, wächst auf BACK_MAX
const BACK_MAX := 78.0
const AXE_DMG := 30.0
const AXE_REACH := 3.8
const THROW_DMG := 38.0
const SWITCH_SWAP := 0.20  # so früh im Wechsel tauscht die Waffe in der Hand

static var weapon := "mjolnir"  # bleibt beim Heldenwechsel erhalten

var pl  # player.gd
var skel: Skeleton3D
var rig
var axe  # Stormbreaker in der rechten Hand
var mjolnir: Array = []  # Mjolnir-Teile
var fps  # Flugpose Stormbreaker
var atk_layer  # Angriffs-Pose
var fx  # Energie-Effekte (storm_fx.gd)
var trail  # Schweif der Axt in der Hand
var grip_w := 0.0  # Finger schliessen sich um den Stiel
var carry_w := 0.0  # Hand hält die Axt in der Ruhehaltung (nicht im Flug, nicht im Angriff)
var label: Label
# Wechsel
var sw_t := -1.0
var sw_to := ""
var sw_swapped := false
var arrive_t := -1.0  # Ankunftspose nach der Landung im Bifrost
# Wurf: 0 = Axt in der Hand, 1 = fliegt hinaus, 2 = kommt zurück
var th_state := 0
var th_t := 0.0
var th_pause := 0.0
var th_pos := Vector3.ZERO
var th_dir := Vector3.FORWARD
var th_travel := 0.0
var th_hits: Array = []
var th_spin := 0.0
var thrown: Node3D
var th_trail
var glow_goal := 1.0


func setup(player, parts: Dictionary) -> void:
	pl = player
	skel = parts["skel"]
	rig = Rig.new(skel)
	# Mjolnir-Teile merken (vor dem Einhängen der Axt)
	var att := skel.get_node_or_null("A_mixamorig_RightHand")
	if att:
		for c in att.get_children():
			mjolnir.append(c)
	for n in skel.find_children("*", "Node3D", true, false):
		if n.is_in_group("mjolnir") and not mjolnir.has(n):
			mjolnir.append(n)
	_mount()
	fps = FlyPoseStorm.new(rig)
	atk_layer = StormAttack.new(rig)
	fx = StormFx.new()
	add_child(fx)
	fx.setup(pl, skel)
	trail = StormTrail.new()
	trail.a = axe.root_pt
	trail.b = axe.edge_pt
	add_child(trail)
	(parts["anim"] as AnimationPlayer).mixer_applied.connect(apply_layers)
	_hud()
	_show_weapon()
	_sync_var()


# Axt an die rechte Hand: Stiel quer durch die Faust, Kopf nach vorn-oben (Handknochen: +X Daumen, +Y Finger, +Z Handfläche)
func _mount() -> void:
	var ba := BoneAttachment3D.new()
	ba.name = "A_Storm"
	ba.bone_name = "mixamorig_RightHand"
	skel.add_child(ba)
	axe = Stormbreaker.new()
	ba.add_child(axe)
	var ca := cos(Rig.GRIP_TILT)
	var sa := sin(Rig.GRIP_TILT)
	axe.transform = Transform3D(Basis(Vector3(0, 0, 1), Vector3(ca, -sa, 0), Vector3(sa, ca, 0)), Rig.GRIP_POINT)


func _hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	label = Label.new()
	label.position = Vector2(18, 46)
	label.add_theme_font_size_override("font_size", 21)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 5)
	layer.add_child(label)


func storm() -> bool:
	return weapon == "stormbreaker"


# Anzeigename der Waffe (HUD)
func weapon_name() -> String:
	return "Stormbreaker" if storm() else "Mjolnir"


# Teilt die Waffe anderen Skripten mit (Mjolnir-Flugpose in fly_pose.gd: thor_weapon), falls sie die Variable haben
func _sync_var() -> void:
	for o in [pl, pl.fp if pl else null]:
		if o != null and "thor_weapon" in o:
			o.set("thor_weapon", weapon)


func _show_weapon() -> void:
	var s := storm()
	for n in mjolnir:
		if is_instance_valid(n):
			n.visible = not s
	axe.visible = s and th_state == 0
	axe.fade = 1.0
	_sync_var()


func busy() -> bool:
	return sw_t >= 0.0


# ---------------------------------------------------------------- Posen

func apply_layers() -> void:
	if skel == null or not is_instance_valid(skel) or not rig.valid():
		return
	fps.apply()
	# Ruhehaltung: die Hand dreht den Axtkopf nach vorn-oben (Animation liefert nur Arm und Hand grob)
	var kw: float = carry_w * (1.0 - fps.weight)
	if kw > 0.01:
		rig.grip("Right", StormAttack.CARRY_D, kw)
	if atk_layer.kind != "":
		atk_layer.apply()
	if grip_w > 0.001:
		rig.curl_hand("Right", grip_w)
	var lw: float = fps.weight * smoothstep(0.3, 0.8, fps.fast)
	if lw > 0.001:
		rig.curl_hand("Left", lw)


# Welcher Angriff (aus player.gd) läuft, als Pose
func _layer_state() -> void:
	var k := ""
	var tm := 0.0
	if sw_t >= 0.0:
		k = "arrive" if sw_to == "stormbreaker" else "summon"
		tm = sw_t
	elif arrive_t >= 0.0:
		k = "arrive"
		tm = arrive_t
	elif storm():
		if pl.atk == "axe" or pl.atk == "axe_air":
			k = "axe"
			tm = pl.atk_t
		elif pl.atk == "axe_throw":
			k = "throw"
			tm = pl.atk_t
	atk_layer.set_state(k, tm)


func _process(delta: float) -> void:
	if pl == null:
		return
	var s := storm()
	_switch_step(delta)
	if arrive_t >= 0.0:
		arrive_t += delta
		if arrive_t > StormAttack.length("arrive"):
			arrive_t = -1.0
	_layer_state()
	fps.weight = move_toward(fps.weight, 1.0 if (s and pl.flying) else 0.0, 4.0 * delta)
	fps.fast = pl.fly_fast
	fps.t = pl.hover_t
	var held: bool = s and axe.visible
	grip_w = move_toward(grip_w, 1.0 if held else 0.0, 8.0 * delta)
	var in_atk: bool = atk_layer.kind != ""
	carry_w = move_toward(carry_w, 1.0 if (held and not in_atk) else 0.0, 8.0 * delta)
	# Aufladung: Schein, Blitze, Augen
	var flying: bool = pl.flying
	var charge := 0.0
	glow_goal = 0.9
	if s:
		if flying:
			charge = 0.65 + 0.35 * pl.fly_fast
			glow_goal = 1.3 + 0.5 * pl.fly_fast
		if pl.atk.begins_with("axe") or th_state != 0:
			charge = 1.0
			glow_goal = 1.8
		if sw_t >= 0.0 or arrive_t >= 0.0:
			charge = 1.0
			glow_goal = 2.0
	fx.want = charge
	fx.trail_want = (0.55 + 0.45 * pl.fly_fast) if (s and flying) else 0.0
	axe.glow = lerpf(axe.glow, glow_goal, 1.0 - exp(-8.0 * delta))
	trail.active = s and pl.atk.begins_with("axe") and pl.atk_t > 0.08 and pl.atk_t < 0.5
	if label:
		label.visible = pl.active
		label.text = "Waffe: %s   (Q wechseln)" % weapon_name()
		label.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0) if s else Color(0.85, 0.88, 0.95))
	_throw_step(delta)


# ---------------------------------------------------------------- Wechsel (Q)

func _unhandled_input(event: InputEvent) -> void:
	var ke := event as InputEventKey
	if ke and ke.pressed and not ke.echo and ke.physical_keycode == KEY_Q and pl and pl.active:
		switch_weapon()


func switch_weapon() -> void:
	if sw_t >= 0.0 or th_state != 0 or pl.atk != "":
		return
	sw_to = "mjolnir" if storm() else "stormbreaker"
	sw_t = 0.0
	sw_swapped = false
	arrive_t = -1.0


func _switch_step(delta: float) -> void:
	if sw_t < 0.0:
		return
	sw_t += delta
	if not sw_swapped and sw_t >= SWITCH_SWAP:
		sw_swapped = true
		weapon = sw_to
		_show_weapon()
		var hand: Vector3 = axe.global_position
		if sw_to == "stormbreaker":
			# Mjolnir verschwindet im Blitz, der Strahl schlägt ein, die Axt entsteht in der Hand
			_flash(hand, Color(0.7, 0.85, 1.0))
			Bifrost.spawn(pl.get_parent(), pl.global_position, 1.7, 1.5)
			axe.fade = 0.0
			axe.create_tween().tween_property(axe, "fade", 1.0, 0.45).set_delay(0.12)
			axe.glow = 2.4
		else:
			# Stormbreaker löst sich auf, Mjolnir kommt mit einem Blitz
			_flash(hand, Color(0.8, 0.9, 1.0))
			VFX.lightning_bolt(pl.get_parent(), pl.global_position + Vector3(0.0, 0.0, 0.0))
	if sw_t >= StormAttack.length("arrive" if sw_to == "stormbreaker" else "summon"):
		sw_t = -1.0


# Blauer Lichtblitz mit Funken an einem Weltpunkt
func _flash(pos: Vector3, c: Color) -> void:
	var f := VFX._spawn(pl.get_parent(), 0.7, pos)
	if f == null:
		return
	VFX._flare(f, "flash_blue", 1.8, 0.25)
	VFX._flare(f, "ring_blue", 2.4, 0.35)
	VFX._sparks(f, Vector3.UP, 180.0, 26, 0.5, 2.0, 8.0, c, -5.0, 1.0)


# ---------------------------------------------------------------- Angriffe (Haken aus player.gd)

# Stärke der Rumpfneigung im Flug (Stormbreaker: aufrechter als Mjolnir)
func lean_scale() -> float:
	return lerpf(1.0, 0.55, fps.weight)


# Welcher Angriff gehört zum Klick? Mjolnir: unverändert. Stormbreaker: Axtschlag, Axtschlag im Flug, Axtwurf.
func map_attack(want: String) -> String:
	if busy():
		return ""
	if not storm():
		return want
	match want:
		"hammer":
			return "axe"
		"swing":
			return "axe_air"
		"bolt":
			return "axe_throw"
	return want


func can_throw() -> bool:
	return th_state == 0 and not busy()


# Wird im Treffer-Bild des Angriffs gerufen. true = erledigt (player.gd macht dann nichts mehr)
func attack_hit(kind: String) -> bool:
	if kind == "axe" or kind == "axe_air":
		_axe_hit()
		return true
	if kind == "axe_throw":
		throw_axe()
		return true
	return false


func _axe_hit() -> void:
	var fwd: Vector3 = -pl.yaw_pivot.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var any := false
	for e in pl.get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = e.global_position - pl.global_position
		to.y = 0.0
		if to.length() < AXE_REACH and to.normalized().dot(fwd) > 0.0:
			e.hit(AXE_DMG, pl.global_position)
			_blue_impact(e.global_position + Vector3(0, 1.0, 0))
			any = true
	# Funken an der Schneide, auch wenn nichts getroffen wurde
	var tip: Vector3 = axe.edge_pt.global_position
	_blue_impact(tip if not any else tip + fwd * 0.2, 0.6)
	if pl.is_on_floor():
		var f := VFX._spawn(pl.get_parent(), 0.8, pl.global_position + fwd * 2.2)
		if f:
			VFX._flare(f, "ring_flat_blue", 4.2, 0.35, Vector3(0, 0.1, 0), true)
			VFX._sparks(f, Vector3.UP, 70.0, 14, 0.45, 3.0, 9.0, Color(0.65, 0.82, 1.0), -16.0, 1.3)


# Blauer Einschlag: Lichtblitz, Funkenstern, Funken (scale 1 = gross)
func _blue_impact(pos: Vector3, k: float = 1.0) -> void:
	var f := VFX._spawn(pl.get_parent(), 0.7, pos)
	if f == null:
		return
	VFX._flare(f, "flash_blue", 2.0 * k, 0.2)
	VFX._flare(f, "flare_star", 1.6 * k, 0.2)
	VFX._sparks(f, Vector3.UP, 120.0, int(18 * k) + 4, 0.45, 3.0, 11.0, Color(0.6, 0.8, 1.0), -14.0, 1.4 * k)


# ---------------------------------------------------------------- Axtwurf mit Rückkehr

func throw_axe() -> void:
	if th_state != 0:
		return
	var parent: Node = pl.get_parent()
	var hand: Vector3 = axe.global_position
	var cam_fwd: Vector3 = -pl.cam.global_transform.basis.z
	var dir: Vector3 = (pl.aim_target() - hand).normalized()
	if dir.dot(cam_fwd) < 0.5:
		dir = cam_fwd
	# leichtes Auto-Zielen: Gegner nahe der Zielrichtung
	var best := 0.16
	for e in pl.get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = (e.global_position + Vector3(0, 1.1, 0)) - hand
		if to.length() < THROW_RANGE + 6.0 and to.length() > 1.0:
			var a := dir.angle_to(to)
			if a < best:
				best = a
				dir = to.normalized()
	axe.visible = false
	thrown = Stormbreaker.new()
	parent.add_child(thrown)
	thrown.top_level = true
	thrown.glow = 2.0
	th_pos = hand
	th_dir = dir
	th_state = 1
	th_t = 0.0
	th_travel = 0.0
	th_hits.clear()
	th_spin = 0.0
	thrown.global_transform = Transform3D(_spin_basis(), th_pos)
	VFX._trail(parent, thrown, 0.2, 0.32, Color(0.5, 0.8, 1.0), true)
	th_trail = StormTrail.new()
	th_trail.a = thrown.root_pt
	th_trail.b = thrown.edge_pt
	th_trail.life = 0.22
	th_trail.active = true
	parent.add_child(th_trail)


# Lage der fliegenden Axt: Stiel dreht sich in der Ebene aus Flugrichtung und "oben" (wie ein Tomahawk)
func _spin_basis() -> Basis:
	var d := th_dir
	var side := d.cross(Vector3.UP)
	if side.length() < 0.05:
		side = d.cross(Vector3.RIGHT)
	side = side.normalized()
	var up2 := side.cross(d).normalized()
	var handle := d * cos(th_spin) + up2 * sin(th_spin)
	var y := handle.normalized()
	var x := side
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


func _throw_step(delta: float) -> void:
	if th_state == 0:
		return
	if thrown == null or not is_instance_valid(thrown):
		_catch(false)
		return
	th_t += delta
	th_spin += delta * (20.0 if th_state == 1 else 26.0)
	var hand: Vector3 = axe.global_position
	if th_pause > 0.0:
		th_pause -= delta
		thrown.global_transform = Transform3D(_spin_basis(), th_pos)
		if th_pause <= 0.0:
			th_state = 2
			th_t = 0.0
			th_hits.clear()
		return
	var step := 0.0
	if th_state == 1:
		step = THROW_SPEED * delta
		var to := th_pos + th_dir * step
		var q := PhysicsRayQueryParameters3D.create(th_pos, to)
		q.exclude = [pl.get_rid()]
		var r: Dictionary = pl.get_world_3d().direct_space_state.intersect_ray(q)
		if r:
			th_pos = r["position"]
			_throw_hit(r["position"], r["normal"], r["collider"])
		else:
			th_pos = to
			th_travel += step
			if th_travel >= THROW_RANGE:
				th_state = 2
				th_t = 0.0
				th_hits.clear()
	else:
		var sp := minf(BACK_SPEED + th_t * 90.0, BACK_MAX)
		var to2 := hand - th_pos
		var dist := to2.length()
		step = sp * delta
		if dist <= step + 0.9 or th_t > 3.5:
			_catch(true)
			return
		th_dir = to2 / dist
		th_pos += th_dir * step
		# Gegner auf dem Rückweg werden mitgenommen
		for e in pl.get_tree().get_nodes_in_group("enemies"):
			if not th_hits.has(e) and e.global_position.distance_to(th_pos - Vector3(0, 1.0, 0)) < 1.7:
				th_hits.append(e)
				e.hit(THROW_DMG * 0.6, th_pos)
				_blue_impact(th_pos, 0.8)
	thrown.global_transform = Transform3D(_spin_basis(), th_pos)


# Axt trifft: Schaden, Blitz vom Himmel, Funken; sie bleibt kurz stecken, dann kehrt sie zurück
func _throw_hit(pos: Vector3, normal: Vector3, col) -> void:
	var parent: Node = pl.get_parent()
	for e in pl.get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(pos) < 3.6 or e == col:
			e.hit(THROW_DMG, pos)
	_blue_impact(pos, 1.4)
	VFX.shield_impact(parent, pos)
	VFX.lightning_bolt(parent, pos - normal * 0.1)
	var f := VFX._spawn(parent, 0.9, pos)
	if f:
		VFX._flare(f, "ring_blue", 4.5, 0.4)
	th_pause = 0.16
	th_hits.clear()


func _catch(ok: bool) -> void:
	if is_instance_valid(thrown):
		thrown.queue_free()
	thrown = null
	if is_instance_valid(th_trail):
		th_trail.active = false
		th_trail.get_tree().create_timer(0.5).timeout.connect(th_trail.queue_free)
	th_trail = null
	var was := th_state
	th_state = 0
	th_pause = 0.0
	if storm():
		axe.visible = true
		axe.fade = 1.0
		axe.glow = 2.4
		if ok and was == 2:
			_blue_impact(axe.global_position, 0.9)


# ---------------------------------------------------------------- Haken: Flug, Landung, Neustart

func on_fly_start() -> void:
	if not storm():
		return
	# Start nahe am Boden (der erste Leertasten-Tipp springt schon): Bifrost-Strahl vom Boden
	var from: Vector3 = pl.global_position + Vector3(0, 0.3, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -6.0, 0))
	q.exclude = [pl.get_rid()]
	var r: Dictionary = pl.get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		Bifrost.spawn(pl.get_parent(), r["position"], 1.2, 1.0)


# Landung nach dem Flug mit Stormbreaker: Bifrost-Strahl und Ankunftspose
func on_land() -> void:
	if storm() and pl.fly_t > 1.2 and pl.atk == "":
		Bifrost.spawn(pl.get_parent(), pl.global_position, 1.7, 1.6)
		arrive_t = 0.0


# Alles abbrechen (Heldenwechsel, Auto, Neustart): Axt zurück in die Hand
func reset() -> void:
	sw_t = -1.0
	arrive_t = -1.0
	if th_state != 0:
		_catch(false)


func _exit_tree() -> void:
	if is_instance_valid(thrown):
		thrown.queue_free()
	if is_instance_valid(th_trail):
		th_trail.queue_free()
