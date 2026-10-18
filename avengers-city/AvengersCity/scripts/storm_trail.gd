extends MeshInstance3D
# Blauer Schweif der Axt: ein Band zwischen zwei Punkten der Klinge (Mitte und Schneide), das die Schwungbahn nachzeichnet.
# Solange "active" gesetzt ist, kommen neue Bildpunkte dazu; sie verblassen in "life" Sekunden.

const SHADER_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform float energy = 2.4;
void fragment() {
	ALBEDO = COLOR.rgb * energy;
	ALPHA = COLOR.a;
}
"""
static var _shader: Shader

var a: Node3D  # innerer Punkt (Klingenwurzel)
var b: Node3D  # äusserer Punkt (Schneide)
var active := false
var life := 0.28
var color := Color(0.45, 0.75, 1.0)
var pa: Array[Vector3] = []
var pb: Array[Vector3] = []
var ages: Array[float] = []
var im := ImmediateMesh.new()


func _ready() -> void:
	top_level = true
	mesh = im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 100.0
	global_transform = Transform3D.IDENTITY
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	var m := ShaderMaterial.new()
	m.shader = _shader
	material_override = m


func _process(delta: float) -> void:
	if active and is_instance_valid(a) and is_instance_valid(b) and a.is_inside_tree():
		var p0 := a.global_position
		var p1 := b.global_position
		if pa.is_empty() or p0.distance_squared_to(pa[0]) + p1.distance_squared_to(pb[0]) > 0.0004:
			pa.push_front(p0)
			pb.push_front(p1)
			ages.push_front(0.0)
	for i in range(ages.size()):
		ages[i] += delta
	while not ages.is_empty() and ages[ages.size() - 1] > life:
		ages.pop_back()
		pa.pop_back()
		pb.pop_back()
	im.clear_surfaces()
	if pa.size() < 2:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(pa.size()):
		var f := ages[i] / life
		var fa := 1.0 - f
		# Innenseite fast durchsichtig, Schneide hell; hinten klingt alles aus
		im.surface_set_color(Color(color.r, color.g, color.b, 0.05 * fa * fa))
		im.surface_add_vertex(pa[i])
		im.surface_set_color(Color(0.55, 0.8, 1.0, 0.8 * fa * fa))
		im.surface_add_vertex(pb[i])
	im.surface_end()
