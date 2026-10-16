extends Node3D
# Düsen von Iron Man: Flammen an Füssen und Handflächen, nur sichtbar, solange die Figur fliegt.
# Die Flammen hängen an den Knochen (Kegel, Spitze zeigt von der Sohle/Handfläche weg).
# Beim Schweben zeigen sie nach unten, im Flug nach hinten (gegen die Flugrichtung), im Boost werden sie länger.

var flames: Array = []  # Node3D-Drehpunkte (Skalierung in y = Länge)
var player: Node
var lvl := 0.0
var t := 0.0
var dir := Vector3.DOWN  # geglättete Schubrichtung (Welt)
var power := 0.0  # geglättete Tempo-Stärke 0..1


func _ready() -> void:
	for f in flames:
		f.visible = false


func _process(delta: float) -> void:
	if player == null:
		var n := get_parent()
		while n != null and not (n is CharacterBody3D):
			n = n.get_parent()
		player = n
	var on := false
	var v := Vector3.ZERO
	var boost := 0.0
	if player != null and player.get("flying") != null:
		on = bool(player.get("flying"))
		v = player.velocity
		boost = float(player.get("fly_boost"))
	lvl = move_toward(lvl, 1.0 if on else 0.0, delta * 5.0)
	t += delta
	# Schubrichtung: Schweben = nach unten, Flug = gegen die Flugrichtung
	var sp := v.length()
	var want := Vector3.DOWN
	if sp > 0.1:
		want = Vector3.DOWN.lerp(-v / sp, smoothstep(2.0, 9.0, sp)).normalized()
	dir = dir.lerp(want, 1.0 - exp(-8.0 * delta)).normalized()
	power = lerpf(power, clampf(sp / 20.0, 0.0, 1.0), 1.0 - exp(-4.0 * delta))
	var longer := 1.0 + 0.7 * power + 0.8 * boost
	var up_hint := Vector3.UP if absf(dir.y) < 0.9 else Vector3(0, 0, -1)
	var fb := Basis.looking_at(dir, up_hint) * Basis(Vector3.RIGHT, PI / 2.0)  # lokale -Y-Achse zeigt in Schubrichtung
	for i in range(flames.size()):
		var f: Node3D = flames[i]
		f.visible = lvl > 0.02
		if f.visible:
			var k := 0.85 + 0.3 * sin(t * 47.0 + i * 1.7) * sin(t * 31.0 + i)
			var gs: float = f.get_parent().global_transform.basis.get_scale().x
			f.global_transform = Transform3D(fb * Basis.from_scale(Vector3(gs, gs * lvl * k * longer, gs)), f.global_position)
