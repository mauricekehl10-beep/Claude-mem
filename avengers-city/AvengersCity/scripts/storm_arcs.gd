extends Node3D
# Blitzbögen: kurze, flackernde Blitze (Bänder wie in vfx.gd, leuchten blau-weiss).
# Alle Bögen eines Knotens sind EIN Netz, das alle ~0.07 s neu gewürfelt wird (billig, sieht lebendig aus).
# Formen: "ball" = Bögen springen um den Ursprung herum (Axtkopf, Körper), "dir" = lange Blitze in Richtung dir (Schweif).

const VFX = preload("res://scripts/vfx.gd")

var count := 3
var rate := 14.0  # neue Formen pro Sekunde
var radius := 0.2  # "ball": Abstand der Bogenenden zum Ursprung
var seg_len := 0.3  # Länge eines Bogens (Meter)
var width := 0.012  # Breite des Kerns (der Schein ist 7x so breit)
var amp := 0.28  # Ausschlag des Zickzacks
var intensity := 1.0  # 0..1: so viele Bögen sind gerade sichtbar
var shape := "ball"
var dir := Vector3.DOWN  # nur "dir"
var spread := 0.5  # "dir": Streuung der Richtung (0 = gerade, 1 = breit)
var branches := true

var _t := 0.0
var _mi: Array = []
var _fade := 1.0
var _mesh := ArrayMesh.new()


func _init() -> void:
	for key in ["bolt_glow", "bolt_core"]:
		var mi := MeshInstance3D.new()
		mi.material_override = VFX._mat(key)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 20.0
		mi.mesh = _mesh
		mi.visible = false
		add_child(mi)
		_mi.append(mi)


func _process(delta: float) -> void:
	if intensity < 0.02:
		for mi in _mi:
			mi.visible = false
		return
	_t -= delta
	if _t <= 0.0:
		_t = 1.0 / rate * randf_range(0.6, 1.4)
		_regen()
		_fade = randf_range(0.6, 1.0)
	var on: bool = _mesh.get_surface_count() > 0
	for mi in _mi:
		mi.visible = on
		if on:
			mi.set_instance_shader_parameter("fade", _fade * minf(intensity * 1.4, 1.0))


func _regen() -> void:
	var polys: Array = []
	for i in range(count):
		if randf() > intensity:
			continue
		var a: Vector3
		var b: Vector3
		if shape == "ball":
			var v := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
			a = v * radius * randf_range(0.2, 1.0)
			var w := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
			b = a + w * seg_len * randf_range(0.5, 1.0)
		else:
			var r := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
			var dd := (dir.normalized() + r * spread).normalized()
			a = Vector3(randf_range(-1, 1), randf_range(-0.3, 0.3), randf_range(-1, 1)) * radius
			b = a + dd * seg_len * randf_range(0.5, 1.0)
		var main := VFX._zigzag(a, b, 3, amp)
		polys.append({"pts": main, "w": width})
		if branches and main.size() > 8 and randf() < 0.6:
			var k := randi_range(3, main.size() - 4)
			var s := main[k]
			var w2 := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
			polys.append({"pts": VFX._zigzag(s, s + w2 * seg_len * 0.45, 2, amp), "w": width * 0.6})
	_mesh.clear_surfaces()
	if polys.is_empty():
		return
	var fresh := VFX._ribbon_mesh(polys)
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, fresh.surface_get_arrays(0))
