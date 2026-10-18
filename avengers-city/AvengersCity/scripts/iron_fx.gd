extends Node3D
# Düsen von Iron Man: Flammen an Füssen und Handflächen, nur sichtbar, solange die Figur fliegt (und kurz beim Aufsetzen).
# Die Ankerpunkte (flames) hängen an den Knochen (hero_parts.gd legt sie an: Fuss links, Hand links, Fuss rechts, Hand rechts).
# Pro Düse: Flamme (Kegel mit Shader), Leuchtfleck, Wärmeflimmern, Funken und Dampfspur.
# Schub, Länge und Richtung folgen der Flugphase aus iron_pose.gd: Schweben, Start, Reiseflug, Boost, Bremsen, Landung.
# Dazu: Staub am Boden beim Start und bei der Landung und ein warmes Licht.

const FLAME_SH = preload("res://scripts/iron_flame.gdshader")
const GLOW_SH = preload("res://scripts/iron_glow.gdshader")
const HEAT_SH = preload("res://scripts/iron_heat.gdshader")
const PUFF_SH = preload("res://scripts/iron_puff.gdshader")

var flames: Array = []  # Ankerpunkte (Node3D) an Füssen und Händen
var player: Node
var lvl := 0.0  # Düsen an/aus (geglättet)
var t := 0.0
var power := 0.0  # geglättete Tempo-Stärke 0..1
var jets: Array = []
var built := false
var light: OmniLight3D
var dust: CPUParticles3D  # Staub am Boden unter den Füssen
var burst: CPUParticles3D  # einmaliger Stoss beim Aufsetzen
var burst_ring: MeshInstance3D
var ring_t := 9.0
var cone: CylinderMesh
var quad: QuadMesh
var down := Vector3.DOWN  # geglättete Schubrichtung der Füsse (Welt)
var cam_pos := Vector3.ZERO
var burn := 0.0  # Nachbrennen nach dem Aufsetzen (Düsen sterben schnell ab)


class Jet:
	var anchor: Node3D
	var hand := false
	var side := 1.0
	var flame: MeshInstance3D
	var fmat: ShaderMaterial
	var plume: MeshInstance3D
	var pmat: ShaderMaterial
	var heat: MeshInstance3D
	var hmat: ShaderMaterial
	var glow: MeshInstance3D
	var gmat: ShaderMaterial
	var sparks: CPUParticles3D
	var smoke: CPUParticles3D
	var thr := 0.0  # Schub (geglättet)
	var dir := Vector3.DOWN


func _ready() -> void:
	for f in flames:
		f.visible = false


# ---------------------------------------------------------------- Aufbau

func _build() -> void:
	built = true
	cone = CylinderMesh.new()
	cone.top_radius = 1.0
	cone.bottom_radius = 1.0
	cone.cap_top = false
	cone.cap_bottom = false
	cone.height = 1.0
	cone.radial_segments = 14
	cone.rings = 10
	quad = QuadMesh.new()
	quad.size = Vector2(1, 1)
	var i := 0
	for f in flames:
		for c in f.get_children():
			c.queue_free()  # die alten Kegel aus hero_parts.gd
		var j := Jet.new()
		j.anchor = f
		var bone: String = str((f.get_parent() as BoneAttachment3D).bone_name) if f.get_parent() is BoneAttachment3D else ""
		j.hand = bone.ends_with("Hand")
		j.side = -1.0 if bone.begins_with("mixamorig_Right") else 1.0
		_make_jet(j, i)
		jets.append(j)
		i += 1
	light = OmniLight3D.new()
	light.top_level = true
	light.light_color = Color(1.0, 0.72, 0.42)
	light.light_energy = 0.0
	light.omni_range = 8.0
	light.omni_attenuation = 1.6
	light.shadow_enabled = false
	add_child(light)
	_make_dust()


func _top(n: Node3D) -> void:
	n.top_level = true
	add_child(n)


func _make_jet(j: Jet, i: int) -> void:
	var seed := float(i) * 1.9
	# Flamme
	j.fmat = ShaderMaterial.new()
	j.fmat.shader = FLAME_SH
	j.fmat.set_shader_parameter("seed", seed)
	# Füsse: weisser Kern, warmer Rand (Düsenflamme im Film), Hände: blau-weisser Repulsor
	if j.hand:
		j.fmat.set_shader_parameter("core_col", Color(0.97, 0.99, 1.0))
		j.fmat.set_shader_parameter("mid_col", Color(0.72, 0.88, 1.0))
		j.fmat.set_shader_parameter("edge_col", Color(0.35, 0.62, 1.0))
	else:
		j.fmat.set_shader_parameter("core_col", Color(1.0, 0.98, 0.92))
		j.fmat.set_shader_parameter("mid_col", Color(1.0, 0.84, 0.52))
		j.fmat.set_shader_parameter("edge_col", Color(1.0, 0.48, 0.16))
	j.flame = MeshInstance3D.new()
	j.flame.mesh = cone
	j.flame.material_override = j.fmat
	j.flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	j.flame.visible = false
	_top(j.flame)
	j.pmat = j.fmat.duplicate()
	j.pmat.set_shader_parameter("grow", 1.0)
	j.pmat.set_shader_parameter("alpha_mul", 0.32)
	j.pmat.set_shader_parameter("mid_col", Color(0.62, 0.8, 1.0) if j.hand else Color(1.0, 0.7, 0.36))
	j.pmat.set_shader_parameter("edge_col", Color(0.4, 0.65, 1.0) if j.hand else Color(1.0, 0.45, 0.14))
	j.plume = MeshInstance3D.new()
	j.plume.mesh = cone
	j.plume.material_override = j.pmat
	j.plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	j.plume.visible = false
	_top(j.plume)
	# Wärmeflimmern
	j.hmat = ShaderMaterial.new()
	j.hmat.shader = HEAT_SH
	j.hmat.set_shader_parameter("seed", seed)
	j.heat = MeshInstance3D.new()
	j.heat.mesh = cone
	j.heat.material_override = j.hmat
	j.heat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	j.heat.visible = false
	_top(j.heat)
	# Leuchtfleck
	j.gmat = ShaderMaterial.new()
	j.gmat.shader = GLOW_SH
	j.gmat.set_shader_parameter("seed", seed)
	j.gmat.set_shader_parameter("tint", Color(0.7, 0.85, 1.0) if j.hand else Color(1.0, 0.86, 0.62))
	j.glow = MeshInstance3D.new()
	j.glow.mesh = quad
	j.glow.material_override = j.gmat
	j.glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	j.glow.visible = false
	_top(j.glow)
	# Funken (nur Füsse und beim Start auch Hände)
	j.sparks = _particles(6, 0.16 if not j.hand else 0.1, 0.8, Color(1.0, 0.86, 0.55, 0.9), false)
	j.sparks.direction = Vector3(0, -1, 0)
	j.sparks.spread = 22.0
	j.sparks.initial_velocity_min = 4.0
	j.sparks.initial_velocity_max = 9.0
	j.sparks.gravity = Vector3(0, -7.0, 0)
	j.sparks.amount = 22 if not j.hand else 10
	j.sparks.scale_amount_min = 0.03
	j.sparks.scale_amount_max = 0.03
	j.sparks.emitting = false
	_top(j.sparks)
	# Dampfspur (Kondensstreifen)
	j.smoke = _particles(1, 1.0, 2.4, Color(0.95, 0.96, 0.98, 0.34), false)
	j.smoke.direction = Vector3(0, -1, 0)
	j.smoke.spread = 8.0
	j.smoke.initial_velocity_min = 0.2
	j.smoke.initial_velocity_max = 0.9
	j.smoke.gravity = Vector3.ZERO
	j.smoke.amount = 44
	j.smoke.scale_amount_curve = _grow(0.5, 2.6)
	j.smoke.scale_amount_min = 0.4
	j.smoke.scale_amount_max = 0.4
	j.smoke.emitting = false
	_top(j.smoke)


# Teilchen in Weltkoordinaten. kind 6 = Funken (hell, klein), 1 = weicher Dampf
func _particles(kind: int, _size: float, life: float, col: Color, additive: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.local_coords = false
	p.lifetime = life
	p.one_shot = false
	p.explosiveness = 0.0
	p.randomness = 0.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINT
	var m := ShaderMaterial.new()
	m.shader = PUFF_SH
	m.set_shader_parameter("add", 1.0 if additive else 0.0)
	m.set_shader_parameter("energy", 2.0 if additive else 1.0)
	m.set_shader_parameter("hard", 0.6 if additive else 0.0)
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	p.mesh = q
	p.material_override = m
	p.color = col
	# Ausblenden über die Lebenszeit (Alpha-Verlauf als Teilchenfarbe)
	var cr := Gradient.new()
	cr.set_color(0, Color(1, 1, 1, 0.0))
	cr.set_color(1, Color(1, 1, 1, 0.0))
	cr.add_point(0.12, Color(1, 1, 1, 1.0))
	cr.add_point(0.55, Color(1, 1, 1, 0.7))
	p.color_ramp = cr
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _grow(from: float, to: float) -> Curve:
	var c := Curve.new()
	c.min_value = 0.0
	c.max_value = 4.0
	c.add_point(Vector2(0.0, from))
	c.add_point(Vector2(1.0, to))
	return c


func _make_dust() -> void:
	dust = _particles(1, 1.0, 0.8, Color(0.78, 0.74, 0.68, 0.3), false)
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = 0.35
	dust.direction = Vector3(0, 0.15, 0)
	dust.spread = 85.0
	dust.initial_velocity_min = 2.0
	dust.initial_velocity_max = 5.5
	dust.gravity = Vector3(0, -0.3, 0)
	dust.damping_min = 1.5
	dust.damping_max = 3.0
	dust.amount = 28
	dust.scale_amount_curve = _grow(0.5, 2.4)
	dust.scale_amount_min = 0.7
	dust.scale_amount_max = 0.7
	dust.emitting = false
	_top(dust)
	burst = _particles(1, 1.0, 0.9, Color(0.8, 0.76, 0.7, 0.22), false)
	burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 0.3
	burst.direction = Vector3(0, 0.1, 0)
	burst.spread = 88.0
	burst.initial_velocity_min = 3.0
	burst.initial_velocity_max = 8.0
	burst.gravity = Vector3(0, -0.4, 0)
	burst.damping_min = 2.0
	burst.damping_max = 4.0
	burst.amount = 40
	burst.scale_amount_curve = _grow(0.5, 2.4)
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.scale_amount_min = 1.4
	burst.scale_amount_max = 1.4
	burst.emitting = false
	_top(burst)


# ---------------------------------------------------------------- Bild für Bild

func _process(delta: float) -> void:
	if player == null:
		var n := get_parent()
		while n != null and not (n is CharacterBody3D):
			n = n.get_parent()
		player = n
	if not built and flames.size() >= 4:
		_build()
	if not built:
		return
	t += delta
	var vc := get_viewport().get_camera_3d()
	if vc != null:
		cam_pos = vc.global_position
	var on := false
	var v := Vector3.ZERO
	var boost := 0.0
	var fp = null
	if player != null and player.get("flying") != null:
		on = bool(player.get("flying"))
		v = player.velocity
		boost = float(player.get("fly_boost"))
		fp = player.get("fp")
	# Zustand der Flugpose (iron_pose.gd)
	var s_f := 0.0
	var s_rise := 0.0
	var s_flare := 0.0
	var s_br := 0.0
	var gd := 99.0
	var gpt := Vector3.ZERO
	if fp != null and fp.get("s_f") != null:
		s_f = fp.s_f
		s_rise = fp.s_rise
		s_flare = fp.s_flare
		s_br = fp.s_br
		gd = fp.gd
		gpt = fp.ground_pt
		if fp.touch_event:
			fp.touch_event = false
			_touchdown(fp.land_power, fp.land_hero)
	if on:
		burn = 1.0
	else:
		burn = move_toward(burn, 0.0, delta * 6.0)  # nach dem Aufsetzen sterben die Düsen schnell ab
	var active := on or burn > 0.0
	lvl = move_toward(lvl, 1.0 if active else 0.0, delta * (6.0 if active else 7.0))
	var sp := v.length()
	power = lerpf(power, clampf(sp / 22.0, 0.0, 1.0), 1.0 - exp(-4.0 * delta))
	if lvl < 0.01:
		for j in jets:
			_hide(j)
		light.light_energy = 0.0
		dust.emitting = false
		return
	# Schubrichtung der Füsse: entlang der Körperachse (Kopf -> Füsse), im Flug etwas gegen die Flugrichtung
	var skel_basis: Basis = (get_parent() as Node3D).global_transform.basis.orthonormalized()
	var body_down: Vector3 = -skel_basis.y
	var want := body_down
	if sp > 4.0:
		want = (body_down * 0.65 + (-v / sp) * 0.35 * smoothstep(4.0, 12.0, sp)).normalized()
	down = down.lerp(want, 1.0 - exp(-12.0 * delta)).normalized()
	# Schub je Phase (1 = Schweben)
	var thr_foot := (0.55 + 0.55 * s_rise + 0.30 * s_f + 0.20 * s_flare) * (1.0 - 0.45 * s_br)
	thr_foot += 1.35 * boost
	var thr_hand := 0.30 + 0.30 * s_rise + 0.20 * s_flare + 0.85 * s_br - 0.2 * s_f + 0.1 * boost
	var k := 1.0 - exp(-10.0 * delta)
	var mid := Vector3.ZERO
	var nfeet := 0
	for j in jets:
		var a: Node3D = j.anchor
		var tgt: float = (thr_hand if j.hand else thr_foot) * lvl
		if not on:
			tgt = 0.0
		j.thr = lerpf(j.thr, tgt, k)
		var origin: Vector3 = a.global_position
		var gs: float = a.global_transform.basis.get_scale().x
		var dir: Vector3 = down
		if j.hand:
			# Handfläche zeigt, wohin der Strahl geht (Boden beim Schweben, nach hinten im Flug, nach vorn beim Bremsen)
			var pn: Vector3 = (a.global_transform.basis.orthonormalized() * Vector3.DOWN).normalized()
			dir = pn
		else:
			mid += origin
			nfeet += 1
		j.dir = j.dir.lerp(dir, 1.0 - exp(-14.0 * delta)).normalized()
		_place(j, origin, gs, sp, boost, s_rise)
	if nfeet > 0:
		mid /= float(nfeet)
		# warmes Licht am Boden unter den Füssen (stärker, je näher der Boden)
		light.global_position = mid + down * 0.9
		var near := 1.0 - smoothstep(0.0, 8.0, gd)
		light.light_energy = (0.25 + 0.7 * near + 0.3 * boost) * clampf(thr_foot, 0.0, 1.6) * lvl
	# Staub am Boden: Düsen blasen den Boden an
	var blow := on and gd < 7.0 and thr_foot * lvl > 0.45 and v.y < 4.0 or (on and gd < 4.0 and s_rise > 0.2)
	dust.emitting = blow
	if blow:
		var near2 := 1.0 - smoothstep(0.0, 7.0, gd)
		dust.global_position = gpt + Vector3(0, 0.08, 0)
		dust.initial_velocity_max = 2.0 + 5.0 * near2
		dust.color = Color(0.78, 0.74, 0.68, 0.06 + 0.2 * near2)
	if ring_t < 1.0:
		_ring(delta)


# Eine Düse ausrichten und einstellen
func _place(j: Jet, origin: Vector3, gs: float, sp: float, boost: float, s_rise: float) -> void:
	var th: float = j.thr
	var show: bool = th > 0.03
	j.flame.visible = show
	j.plume.visible = show and th > 0.2
	j.heat.visible = show and th > 0.3
	j.glow.visible = show
	if not show:
		j.sparks.emitting = false
		j.smoke.emitting = false
		return
	# Grösse: Länge in Metern, Radius an der Düse
	var ln: float
	var rad: float
	if j.hand:
		ln = 0.22 + 0.40 * th
		rad = 0.050 + 0.014 * th
	else:
		ln = minf(0.55 + 0.80 * th + 0.35 * th * th, 3.0)
		rad = 0.075 + 0.016 * minf(th, 1.6)
	ln *= 1.0 + 0.2 * boost
	var y := -j.dir  # lokale +Y der Flamme zeigt zur Düse, die Spitze (-Y) zeigt in Schubrichtung
	var xa := y.cross(Vector3.UP)
	if xa.length() < 0.05:
		xa = y.cross(Vector3.FORWARD)
	xa = xa.normalized()
	var za := xa.cross(y).normalized()
	# Kamera dicht an der Flamme (Blick von hinten): ausblenden, damit das Bild nicht weiss wird
	var cf := smoothstep(0.9, 3.4, cam_pos.distance_to(origin + j.dir * ln * gs * 0.6))
	var b := Basis(xa * rad * gs, y * ln * gs, za * rad * gs)
	j.flame.global_transform = Transform3D(b, origin)
	j.fmat.set_shader_parameter("energy", (1.4 + 0.8 * minf(th, 1.6)) * cf)
	j.plume.global_transform = Transform3D(Basis(xa * rad * gs * 1.1, y * minf(ln * 1.25, 2.4) * gs, za * rad * gs * 1.1), origin)
	j.pmat.set_shader_parameter("energy", (0.9 + 0.5 * minf(th, 1.6)) * cf)
	# Wärmeflimmern: breiter und länger als die Flamme
	if j.heat.visible:
		var hb := Basis(xa * rad * gs * 2.6, y * ln * gs * 2.0, za * rad * gs * 2.6)
		j.heat.global_transform = Transform3D(hb, origin)
		j.hmat.set_shader_parameter("amount", clampf((th - 0.3) * 1.2, 0.0, 1.0) * cf)
	# Leuchtfleck
	var gsz := (0.20 if not j.hand else 0.12) * gs * (0.7 + 0.3 * minf(th, 1.8))
	j.glow.global_transform = Transform3D(Basis.from_scale(Vector3(gsz, gsz, gsz)), origin + j.dir * 0.03)
	j.gmat.set_shader_parameter("energy", ((0.9 + 0.3 * minf(th, 1.6)) if j.hand else (1.0 + 0.4 * minf(th, 1.6))) * clampf(cf, 0.1, 1.0))
	# Funken: bei kräftigem Schub (Start, Boost) an den Füssen, Hände nur beim Start
	var spark_on := (th > 0.9 and not j.hand) or (s_rise > 0.4 and th > 0.45) or boost > 0.4 and not j.hand
	j.sparks.emitting = spark_on
	if spark_on:
		j.sparks.global_transform = Transform3D(Basis(xa, y, za), origin + j.dir * 0.1)
		j.sparks.initial_velocity_max = 5.0 + 5.0 * minf(th, 1.5) + sp * 0.2
	# Dampfspur bei Tempo (Kondensstreifen) und beim Start
	var smoke_on := (sp > 9.0 or s_rise > 0.35) and th > 0.35 and (not j.hand or boost > 0.5)
	j.smoke.emitting = smoke_on
	if smoke_on:
		var dd := j.dir
		j.smoke.global_transform = Transform3D(Basis(xa, y, za), origin + dd * (ln * gs * 0.55))
		j.smoke.initial_velocity_max = 0.5 + 0.12 * sp
		j.smoke.scale_amount_min = 0.4 + 0.5 * boost
		j.smoke.scale_amount_max = j.smoke.scale_amount_min


func _hide(j: Jet) -> void:
	j.plume.visible = false
	j.flame.visible = false
	j.heat.visible = false
	j.glow.visible = false
	j.sparks.emitting = false
	j.smoke.emitting = false
	j.thr = 0.0


# Aufsetzen: Staubstoss (bei der Superhelden-Landung stärker) und Funken
func _touchdown(power_v: float, hero: bool) -> void:
	if not built or player == null:
		return
	var fp = player.get("fp")
	var pt: Vector3 = player.global_position + Vector3(0, 0.05, 0)
	burst.global_position = pt
	burst.amount = 30 if hero else 14
	burst.initial_velocity_max = 5.0 + minf(power_v, 18.0) * 0.5 if hero else 4.0
	burst.scale_amount_min = 1.2 if hero else 0.8
	burst.scale_amount_max = burst.scale_amount_min
	burst.restart()
	burst.emitting = true
	ring_t = 0.0
	if burst_ring == null:
		burst_ring = MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.9
		ring.outer_radius = 1.0
		ring.rings = 24
		ring.ring_segments = 6
		burst_ring.mesh = ring
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.9, 0.86, 0.8, 0.5)
		burst_ring.material_override = m
		burst_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_top(burst_ring)
	burst_ring.global_position = pt
	burst_ring.scale = Vector3(0.3, 0.05, 0.3)
	burst_ring.visible = true
	burst_ring.set_meta("hero", hero)
	if fp != null:
		pass


# Staubring, der sich flach über den Boden ausbreitet und verblasst
func _ring(delta: float) -> void:
	ring_t += delta
	var hero: bool = burst_ring.get_meta("hero", false)
	var u := ring_t / (0.55 if hero else 0.35)
	if u >= 1.0:
		burst_ring.visible = false
		ring_t = 9.0
		return
	var r := (0.4 + (5.5 if hero else 2.2) * (1.0 - pow(1.0 - u, 2.5)))
	burst_ring.scale = Vector3(r, 0.04 + 0.12 * (1.0 - u), r)
	var m := burst_ring.material_override as StandardMaterial3D
	m.albedo_color.a = (0.5 if hero else 0.3) * (1.0 - u) * (1.0 - u)
