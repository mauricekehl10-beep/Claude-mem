extends Node3D
# Mjolnir-Effekte: blau-weisses Leuchten, Blitzbögen um den Hammer, Lichtschweif und Windlinien.
# Der Knoten sitzt im Hammerkopf (Kind des Hammer-Drehpunkts "pivot", siehe thor_mjolnir.gd).
# level (0..1) stellt die Stärke ein: 0 = Hammer dunkel (Thor läuft), 1 = voller Flug.

const VFX = preload("res://scripts/vfx.gd")

const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;
uniform vec3 tint = vec3(0.55, 0.82, 1.0);
uniform float energy = 1.0;
void fragment() {
	float fr = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 1.5);
	ALBEDO = tint * energy * (0.5 + fr * 2.4);
	ALPHA = clamp(energy * (0.28 + fr), 0.0, 1.0);
}
"""

const LINE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a;
}
"""

const ARC_RATE := 0.055  # so oft entstehen neue Blitzbögen (Sekunden)

var level := 0.0  # Stärke 0..1 (von aussen gesetzt)
var spin := 0.0  # 0..1: Hammer wirbelt (stärkerer Schweif)
var pivot: Node3D  # Hammer-Drehpunkt (alle Hammerteile hängen daran)
var shells: Array = []  # Leucht-Hüllen um den Hammerkopf
var glow_mat: ShaderMaterial
var metal_mats: Array = []  # Materialien des Hammers (leuchten von innen)
var light: OmniLight3D
var flare: MeshInstance3D
var arcs: Array = []  # zwei Lagen (Glühen, Kern)
var arc_t := 0.0
var trail: MeshInstance3D
var wind: CPUParticles3D
var player: Node3D
var t := 0.0
var speed := 0.0


# Baut die Effekte. pivot = Hammer-Drehpunkt, head = Lage des Hammerkopfs im Drehpunkt (Mitte, Achsen des Hammers)
func setup(pv: Node3D, head: Transform3D, pl: Node3D, trail_parent: Node) -> void:
	pivot = pv
	player = pl
	transform = head
	pv.add_child(self)
	# Leucht-Hüllen: Kopien der Kopfteile (Quader), etwas grösser, additiv mit hellem Rand
	var sh := Shader.new()
	sh.code = GLOW_SHADER
	glow_mat = ShaderMaterial.new()
	glow_mat.shader = sh
	for c in pv.get_children():
		var mi := c as MeshInstance3D
		if mi == null or not (mi.mesh is BoxMesh):
			continue
		var m := mi.material_override as StandardMaterial3D
		if m != null and not metal_mats.has(m):
			metal_mats.append(m)
		var s := MeshInstance3D.new()
		s.mesh = mi.mesh
		s.transform = mi.transform * Transform3D(Basis.from_scale(Vector3(1.16, 1.16, 1.1)), Vector3.ZERO)
		s.material_override = glow_mat
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pv.add_child(s)
		shells.append(s)
	# Leuchtfleck zur Kamera
	flare = MeshInstance3D.new()
	flare.mesh = VFX._quad()
	flare.material_override = VFX._mat("flash_blue")
	flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flare)
	# Licht (färbt Thor und die Umgebung blau)
	light = OmniLight3D.new()
	light.light_color = Color(0.6, 0.82, 1.0)
	light.omni_range = 6.0
	light.light_energy = 0.0
	light.shadow_enabled = false
	add_child(light)
	# Blitzbögen: Glühen (breit, blau) und Kern (dünn, weiss)
	for key in ["bolt_glow", "bolt_core"]:
		var mi2 := MeshInstance3D.new()
		mi2.material_override = VFX._mat(key)
		mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi2.extra_cull_margin = 3.0
		add_child(mi2)
		mi2.set_instance_shader_parameter("fade", 1.0)
		arcs.append(mi2)
	# Lichtschweif hinter dem Hammerkopf (folgt dem Kopf in der Welt)
	VFX._trail(trail_parent, self, 0.11, 0.22, Color(0.62, 0.86, 1.0), false)
	trail = trail_parent.get_child(trail_parent.get_child_count() - 1) as MeshInstance3D
	trail.visible = false
	_make_wind(trail_parent)


# Windlinien: dünne helle Streifen, die um Thor herum gegen die Flugrichtung vorbeiziehen
func _make_wind(host: Node) -> void:
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	for axis in range(2):
		var s := Vector3.RIGHT if axis == 0 else Vector3.BACK
		var b := v.size()
		v.append(s * -0.006 + Vector3(0, -0.5, 0))
		v.append(s * 0.006 + Vector3(0, -0.5, 0))
		v.append(s * 0.006 + Vector3(0, 0.5, 0))
		v.append(s * -0.006 + Vector3(0, 0.5, 0))
		c.append(Color(1, 1, 1, 0.0))
		c.append(Color(1, 1, 1, 0.0))
		c.append(Color(1, 1, 1, 0.9))
		c.append(Color(1, 1, 1, 0.9))
		idx.append_array(PackedInt32Array([b, b + 1, b + 2, b, b + 2, b + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var sh := Shader.new()
	sh.code = LINE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	wind = CPUParticles3D.new()
	wind.amount = 22
	wind.lifetime = 0.45
	wind.local_coords = false
	wind.mesh = mesh
	wind.material_override = mat
	wind.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wind.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	wind.emission_sphere_radius = 3.2
	wind.gravity = Vector3.ZERO
	wind.particle_flag_align_y = true
	wind.spread = 4.0
	wind.scale_amount_min = 1.2
	wind.scale_amount_max = 3.2
	wind.scale_amount_curve = VFX._curve("pop")
	wind.color = Color(0.9, 0.96, 1.0, 0.45)
	wind.lifetime_randomness = 0.4
	wind.emitting = false
	wind.visibility_aabb = AABB(Vector3(-80, -80, -80), Vector3(160, 160, 160))
	host.add_child(wind)
	wind.top_level = true


func _process(delta: float) -> void:
	t += delta
	var on := level > 0.02
	# Hammerkopf: Hüllen und Leuchten
	for s in shells:
		s.visible = on
	glow_mat.set_shader_parameter("energy", 0.25 + 0.95 * level)
	for m in metal_mats:
		m.emission_enabled = on
		m.emission = Color(0.55, 0.8, 1.0)
		m.emission_energy_multiplier = level * 1.1
	light.visible = on
	light.light_energy = level * (1.6 + 0.4 * sin(t * 41.0) * sin(t * 23.0))
	flare.visible = on
	var fs := 0.22 + 0.22 * level + 0.04 * sin(t * 33.0)
	flare.scale = Vector3(fs, fs, fs)
	if trail != null and is_instance_valid(trail):
		trail.visible = level > 0.35 or spin > 0.2
	# Blitzbögen: alle ARC_RATE Sekunden neu würfeln
	arc_t -= delta
	for a in arcs:
		a.visible = on
	if on and arc_t <= 0.0:
		arc_t = ARC_RATE * randf_range(0.7, 1.4)
		_new_arcs()
	_wind(delta)


# Neue Blitzbögen um den Hammerkopf (Koordinaten: Hammerkopf, +Y = Griffrichtung vom Kopf weg zur Hand... siehe unten)
func _new_arcs() -> void:
	var polys: Array = []
	var n := 2 + int(round(3.0 * level))
	for i in range(n):
		var dir := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var a := dir * 0.1
		var b := dir * randf_range(0.3, 0.55) + Vector3(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1), randf_range(-0.1, 0.1))
		polys.append({"pts": VFX._zigzag(a, b, 3, 0.3), "w": 0.018 * (0.6 + level * 0.6)})
		if randf() < 0.45:
			var pts: PackedVector3Array = polys[polys.size() - 1]["pts"]
			var k := randi_range(2, maxi(pts.size() - 3, 3))
			var d2 := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
			polys.append({"pts": VFX._zigzag(pts[k], pts[k] + d2 * 0.2, 2, 0.3), "w": 0.01})
	# ein langer Bogen den Griff entlang zur Hand (-Y = Richtung Hand im Hammer-Achsensystem)
	polys.append({"pts": VFX._zigzag(Vector3(0.04, -0.1, 0.03), Vector3(randf_range(-0.12, 0.12), -0.62, randf_range(-0.12, 0.12)), 3, 0.18), "w": 0.014})
	if level > 0.6 and randf() < 0.6:
		# langer Bogen nach hinten (zum Körper)
		polys.append({"pts": VFX._zigzag(Vector3(0, -0.5, 0), Vector3(randf_range(-0.3, 0.3), -1.5, randf_range(-0.3, 0.3)), 4, 0.22), "w": 0.012})
	var mesh := VFX._ribbon_mesh(polys)
	for a in arcs:
		a.mesh = mesh


# Windlinien: nur bei Tempo, sie entstehen in einer Kugel um Thor leicht vor ihm und treiben gegen die Flugrichtung davon
func _wind(delta: float) -> void:
	if wind == null or player == null:
		return
	var v: Vector3 = player.get("velocity") if player.get("velocity") != null else Vector3.ZERO
	speed = lerpf(speed, v.length(), 1.0 - exp(-6.0 * delta))
	var on := bool(player.get("flying")) and speed > 7.0 and level > 0.3
	wind.emitting = on
	if speed > 1.0:
		var d := v.normalized()
		wind.direction = -d
		wind.initial_velocity_min = speed * 0.55
		wind.initial_velocity_max = speed * 0.9
		wind.global_position = player.global_position + Vector3(0, 1.2, 0) + d * 3.0
