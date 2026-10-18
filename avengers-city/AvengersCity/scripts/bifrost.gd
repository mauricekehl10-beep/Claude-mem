extends RefCounted
# Bifrost: Regenbogenstrahl vom Himmel (wie bei Thors Ankunft in Infinity War). Ein Aufruf = ein Strahl, der sich selbst löscht.
#   Bifrost.spawn(get_parent(), bodenpunkt, radius, dauer)
# Strahl schlägt von oben ein (0.15 s), steht (flackernd), klingt aus. Am Boden: Glühen, Schockring, aufsteigende Funken, Licht.

const VFX = preload("res://scripts/vfx.gd")
const SHADER = preload("res://scripts/bifrost.gdshader")
const HEIGHT := 170.0

static var _cyl: CylinderMesh
static var _live := 0


static func _beam_mesh() -> CylinderMesh:
	if _cyl == null:
		_cyl = CylinderMesh.new()
		_cyl.top_radius = 1.0
		_cyl.bottom_radius = 1.0
		_cyl.height = HEIGHT
		_cyl.radial_segments = 40
		_cyl.rings = 1
		_cyl.cap_top = false
		_cyl.cap_bottom = false
	return _cyl


static func _beam_mat(whiten: float, energy: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("height", HEIGHT)
	m.set_shader_parameter("whiten", whiten)
	m.set_shader_parameter("energy", energy)
	return m


# Strahl am Boden-Punkt pos. radius in Metern, dauer = Zeit bis alles weg ist (Sekunden).
static func spawn(parent: Node, pos: Vector3, radius: float = 1.6, dur: float = 1.8) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree() or _live >= 2:
		return
	_live += 1
	var fx := Node3D.new()
	fx.top_level = true
	parent.add_child(fx)
	fx.global_position = pos
	var mats: Array = []
	# äusserer Strahl (bunt) und innerer Kern (weiss, schmaler)
	for k in [[1.0, 0.0, 0.75], [0.4, 1.0, 0.7]]:
		var mi := MeshInstance3D.new()
		mi.mesh = _beam_mesh()
		var m := _beam_mat(k[1], k[2])
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.scale = Vector3(radius * k[0], 1.0, radius * k[0])
		mi.position = Vector3(0, HEIGHT * 0.5, 0)
		mi.extra_cull_margin = 200.0
		fx.add_child(mi)
		mats.append(m)
	# Boden: Glühen und Ring
	var disc := _flat(fx, VFX._flare_mat(Color(1.0, 0.82, 0.95), 1.2, 1.0, 0.0, 0.0, 0.0), radius * 4.0, Vector3(0, 0.06, 0))
	var ring := _flat(fx, VFX._flare_mat(Color(0.9, 0.85, 1.0), 1.6, 0.0, 0.0, 1.0, 0.0), radius * 8.0, Vector3(0, 0.08, 0))
	var tw0 := fx.create_tween()
	tw0.tween_method(func(v: float): ring.set_instance_shader_parameter("t", v), 0.0, 1.0, 0.7)
	var tw1 := fx.create_tween()
	tw1.tween_interval(maxf(dur - 1.0, 0.2))
	tw1.tween_method(func(v: float): disc.set_instance_shader_parameter("t", v), 0.0, 1.0, 0.9)
	# Licht
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.86, 0.96)
	light.light_energy = 0.0
	light.omni_range = 26.0
	light.shadow_enabled = false
	light.position = Vector3(0, 2.5, 0)
	fx.add_child(light)
	# aufsteigende Funken (rosa-weiss und cyan-weiss)
	for c in [Color(1.0, 0.75, 0.95), Color(0.7, 1.0, 1.0)]:
		var p := CPUParticles3D.new()
		p.amount = 46
		p.lifetime = 1.3
		p.mesh = VFX._quad()
		p.material_override = VFX._mat("glow")
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = radius * 0.9
		p.direction = Vector3.UP
		p.spread = 12.0
		p.initial_velocity_min = 2.5
		p.initial_velocity_max = 9.0
		p.gravity = Vector3(0, 0.5, 0)
		p.scale_amount_min = 0.06
		p.scale_amount_max = 0.16
		p.scale_amount_curve = VFX._curve("pop")
		p.color = c * 2.0
		p.local_coords = false
		fx.add_child(p)
	# Ablauf: einschlagen, stehen, ausklingen
	var tw := fx.create_tween().set_parallel(true)
	for m in mats:
		tw.tween_method(func(v: float): m.set_shader_parameter("reveal", v), 0.0, 1.0, 0.16)
	var t_out := maxf(dur - 0.7, 0.3)
	for m in mats:
		tw.tween_method(func(v: float): m.set_shader_parameter("fade", v), 1.0, 0.0, 0.7).set_delay(t_out)
	tw.tween_property(light, "light_energy", 3.0, 0.12).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(light, "light_energy", 0.0, 0.7).set_delay(t_out)
	parent.get_tree().create_timer(dur + 0.1).timeout.connect(_done.bind(fx))


static func _done(fx: Node) -> void:
	_live -= 1
	if is_instance_valid(fx):
		fx.queue_free()


static func _flat(fx: Node3D, mat: Material, size: float, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = VFX._quad()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(size, size, size)
	mi.position = pos
	mi.rotation_degrees = Vector3(-90, 0, 0)
	fx.add_child(mi)
	mi.set_instance_shader_parameter("t", 0.0)
	return mi
