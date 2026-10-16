extends MeshInstance3D
# Umhang von Thor: hängt an den Schultern, weht bei Tempo, Flug und Fall mit dem Fahrtwind.
# Das Teil sitzt am Rücken-Knochen. Seine Koordinaten sind Ruhepose-Koordinaten der Figur
# (+Z vorn, Rücken bei -Z); die Form wird jedes Bild neu berechnet.

const ROWS := 12
const COLS := 8
const LEN := 1.05

var skel: Skeleton3D
var player: CharacterBody3D
var wind := Vector3.DOWN  # geglätteter Fahrtwind (Welt), zeigt in Richtung des Umhangs
var flare := 0.0
var t := 0.0
var last := Vector3.ZERO
var mat: StandardMaterial3D


func _ready() -> void:
	mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.05, 0.07)
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.65
	mat.metallic = 0.1
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh = ArrayMesh.new()
	var n := get_parent()
	while n != null and not (n is CharacterBody3D):
		n = n.get_parent()
	player = n as CharacterBody3D
	last = global_position
	_rebuild(Vector3.DOWN)


func _process(delta: float) -> void:
	if not is_visible_in_tree() or delta <= 0.0:
		return
	t += delta
	var v := Vector3.ZERO
	if player != null:
		v = player.velocity
	else:
		v = (global_position - last) / delta
		last = global_position
	# Fahrtwind: gegen die Bewegung, dazu etwas Schwerkraft
	var target := (-v + Vector3.DOWN * 4.0).normalized()
	wind = wind.lerp(target, 1.0 - exp(-6.0 * delta)).normalized()
	var fl_t := clampf(v.length() / 10.0, 0.0, 1.0)
	if player != null and bool(player.get("flying")):
		fl_t = maxf(fl_t, 0.3)  # Schweben: der Umhang weht leicht
	flare = lerpf(flare, fl_t, 1.0 - exp(-5.0 * delta))
	_rebuild((global_transform.basis.inverse() * wind).normalized())


# wl = Windrichtung in den Koordinaten des Umhangs
func _rebuild(wl: Vector3) -> void:
	var pos := PackedVector3Array()
	var col := PackedColorArray()
	pos.resize(ROWS * COLS)
	col.resize(ROWS * COLS)
	var p := Vector3(0, 1.47, -0.175)  # Oberkante, Mitte
	var seg := LEN / float(ROWS - 1)
	for i in range(ROWS):
		var s := float(i) / float(ROWS - 1)
		if i > 0:
			# Ruhelage: entlang des Rückens, leicht nach hinten abstehend
			var a := 0.03 + 0.016 * i
			var base := Vector3(0, -cos(a), -sin(a))
			# Fahrtwind: unten stärker als an den Schultern
			var m := clampf(flare * (0.2 + 0.8 * s) * 1.1, 0.0, 1.0)
			var d := base.lerp(wl, m).normalized()
			d += Vector3(0.0, 0.0, -0.03) * sin(t * 2.2 + i * 0.7) * (0.4 + flare)
			p += d.normalized() * seg
		var wd := lerpf(0.34, 0.5, s) * (1.0 + flare * 0.25 * s)
		for c in range(COLS):
			var u := float(c) / float(COLS - 1) - 0.5
			var x := u * wd
			var fold := sin(u * 11.0 + s * 1.5 + t * (0.6 + flare * 5.0) * 0.5 * s)
			var z := 0.9 * x * x + fold * (0.012 + 0.03 * flare) * s
			pos[i * COLS + c] = p + Vector3(x, 0, z)
			var sh := 0.88 + 0.12 * fold
			if i >= ROWS - 1 or c == 0 or c == COLS - 1:
				sh *= 0.8
			col[i * COLS + c] = Color(sh, sh * 0.9, sh * 0.9)
	var nrm := PackedVector3Array()
	nrm.resize(ROWS * COLS)
	for i in range(ROWS):
		for c in range(COLS):
			var a2 := pos[mini(i + 1, ROWS - 1) * COLS + c] - pos[maxi(i - 1, 0) * COLS + c]
			var b2 := pos[i * COLS + mini(c + 1, COLS - 1)] - pos[i * COLS + maxi(c - 1, 0)]
			nrm[i * COLS + c] = b2.cross(a2).normalized()
	var idx := PackedInt32Array()
	for i in range(ROWS - 1):
		for c in range(COLS - 1):
			var k := i * COLS + c
			idx.append_array([k, k + COLS, k + 1, k + 1, k + COLS, k + COLS + 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_INDEX] = idx
	var am := mesh as ArrayMesh
	am.clear_surfaces()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	am.surface_set_material(0, mat)
