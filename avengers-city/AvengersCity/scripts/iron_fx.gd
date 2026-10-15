extends Node3D
# Düsen von Iron Man: Flammen an Füssen und Handflächen, nur sichtbar, solange die Figur fliegt.
# Die Flammen hängen an den Knochen (Kegel, Spitze zeigt von der Sohle/Handfläche weg).

var flames: Array = []  # Node3D-Drehpunkte (Skalierung in y = Länge)
var player: Node
var lvl := 0.0
var t := 0.0


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
	if player != null and player.get("flying") != null:
		on = bool(player.get("flying"))
	lvl = move_toward(lvl, 1.0 if on else 0.0, delta * 5.0)
	t += delta
	for i in range(flames.size()):
		var f: Node3D = flames[i]
		f.visible = lvl > 0.02
		if f.visible:
			var k := 0.85 + 0.3 * sin(t * 47.0 + i * 1.7) * sin(t * 31.0 + i)
			f.scale = Vector3(1.0, lvl * k, 1.0)
