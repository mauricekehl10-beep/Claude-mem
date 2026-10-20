extends CanvasLayer
# Bildschirm-Effekte für den Iron-Man-Flug: Windlinien am Bildrand und eine kleine Tempo-/Höhenanzeige.
# iron_flight.gd ruft show_state() jedes Bild auf. Die Ebene liegt hinter dem normalen HUD (layer -1).

var rect: ColorRect
var mat: ShaderMaterial
var label: Label
var inten := 0.0  # geglättete Stärke der Windlinien
var t := 0.0
var shift := Vector2.ZERO


func _init() -> void:
	layer = -1
	rect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	mat = ShaderMaterial.new()
	mat.shader = load("res://scripts/iron_wind.gdshader")
	rect.material = mat
	rect.color = Color(1, 1, 1, 1)
	add_child(rect)
	label = Label.new()
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0, 0.85))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	visible = false


# speed in m/s, alt = Höhe über dem Boden, boost 0..1, dir = Flugrichtung im Bild (-1..1), on = fliegt gerade
func show_state(delta: float, on: bool, speed: float, alt: float, boost: float, dir: Vector2) -> void:
	var want := 0.0
	if on:
		want = smoothstep(20.0, 58.0, speed) * 0.85 + boost * 0.35
	inten = lerpf(inten, want, 1.0 - exp(-(4.0 if want > inten else 2.5) * delta))
	var show_it := on or inten > 0.01
	if visible != show_it:
		visible = show_it
	if not show_it:
		return
	t += delta
	shift = shift.lerp(dir * 0.06, 1.0 - exp(-5.0 * delta))
	mat.set_shader_parameter("inten", clampf(inten, 0.0, 1.0))
	mat.set_shader_parameter("tm", t)
	mat.set_shader_parameter("shift", shift)
	var vs := get_viewport().get_visible_rect().size
	mat.set_shader_parameter("asp", Vector2(vs.x / maxf(vs.y, 1.0), 1.0))
	rect.visible = inten > 0.01
	label.visible = on
	if on:
		label.text = "%d km/h   Höhe %d m%s" % [int(speed * 3.6), int(alt), "   NACHBRENNER" if boost > 0.5 else ""]
		label.position = Vector2(0, 14)
		label.size = Vector2(vs.x, 30)
