extends MeshInstance3D
# Umhang von Thor: hängt an den Schultern, weht bei Tempo, Flug und Fall mit dem Fahrtwind.
# Das Teil sitzt am Rücken-Knochen. Seine Koordinaten sind Ruhepose-Koordinaten der Figur
# (+Z vorn, Rücken bei -Z); die Form wird jedes Bild neu berechnet.

const ROWS := 16
const COLS := 14
const LEN := 1.36
const CAPE_SHADER = preload("res://scripts/thor_cape.gdshader")

var skel: Skeleton3D
var player: CharacterBody3D
var wind := Vector3.DOWN  # geglätteter Fahrtwind (Welt), zeigt in Richtung des Umhangs
var flare := 0.0
var fly := 0.0  # geglätteter schneller Flug (0..1): der Umhang streckt sich und flattert breit nach hinten
var t := 0.0
var last := Vector3.ZERO
var mat: ShaderMaterial


func _ready() -> void:
	mat = ShaderMaterial.new()  # Aussehen: thor_cape.gdshader (Samt, Futter, Saum)
	mat.shader = CAPE_SHADER
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
	var target := (-v + Vector3.DOWN * lerpf(4.0, 1.0, fly)).normalized()
	wind = wind.lerp(target, 1.0 - exp(-6.0 * delta)).normalized()
	var fl_t := clampf(v.length() / 10.0, 0.0, 1.0)
	if player != null and bool(player.get("flying")):
		fl_t = maxf(fl_t, 0.3)  # Schweben: der Umhang weht leicht
	flare = lerpf(flare, fl_t, 1.0 - exp(-5.0 * delta))
	var ff := 0.0
	if player != null and bool(player.get("flying")) and player.get("fly_fast") != null:
		ff = float(player.get("fly_fast"))
	fly = lerpf(fly, ff, 1.0 - exp(-5.0 * delta))
	_rebuild((global_transform.basis.inverse() * wind).normalized())


# wl = Windrichtung in den Koordinaten des Umhangs
func _rebuild(wl: Vector3) -> void:
	var pos := PackedVector3Array()
	var col := PackedColorArray()
	pos.resize(ROWS * COLS)
	col.resize(ROWS * COLS)
	var uvs := PackedVector2Array()
	uvs.resize(ROWS * COLS)
	var p := Vector3(0, 1.47, -0.175)  # Oberkante, Mitte
	var seg := LEN * (1.0 + 0.3 * fly) / float(ROWS - 1)
	for i in range(ROWS):
		var s := float(i) / float(ROWS - 1)
		if i > 0:
			# Ruhelage: entlang des Rückens, leicht nach hinten abstehend
			var a := 0.03 + 0.016 * i
			var base := Vector3(0, -cos(a), -sin(a))
			# Fahrtwind: unten stärker als an den Schultern
			var m := clampf(flare * (0.2 + 0.8 * s) * 1.1 + fly * 0.5 * (1.0 - s), 0.0, 1.0)
			m = maxf(m, clampf((1.0 - base.dot(wl)) * 1.4, 0.0, 1.0) * (0.25 + 0.75 * s) * (1.0 - flare))  # Oberkörper geneigt (Hocke): der Umhang hängt nach unten
			var d := base.lerp(wl, m).normalized()
			d += Vector3(0.0, 0.0, -1.0) * fly * 0.34 * sin(PI * minf(s * 1.15, 1.0))  # im Flug hebt sich der Umhang vom Rücken ab
			d += Vector3(0.0, 0.0, -0.03) * sin(t * 2.2 + i * 0.7) * (0.4 + flare)
			p += d.normalized() * seg
		var wd := lerpf(0.42, 1.0, pow(s, 0.85)) * (1.0 + flare * 0.25 * s + fly * 0.6 * s)
		for c in range(COLS):
			var u := float(c) / float(COLS - 1) - 0.5
			var x := u * wd + sin(t * 9.0 + s * 6.0 + u * 2.0) * 0.045 * fly * s * s
			var fold := sin(u * 19.0 + s * 2.2 + sin(u * 7.0 + s * 3.0) * 0.8 + t * (0.6 + flare * 5.0) * 0.5 * s)
			var z := 0.35 * x * x + fold * (0.022 + 0.03 * flare + 0.05 * fly) * s + sin(s * 8.0 - t * 13.0 + u * 3.0) * 0.07 * fly * s
			pos[i * COLS + c] = p + Vector3(x, 0, z)
			var sh := 0.88 + 0.12 * fold
			if i >= ROWS - 1 or c == 0 or c == COLS - 1:
				sh *= 0.8
			col[i * COLS + c] = Color(sh, sh * 0.9, sh * 0.9)
			uvs[i * COLS + c] = Vector2(float(c) / float(COLS - 1), s)
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
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var am := mesh as ArrayMesh
	am.clear_surfaces()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	am.surface_set_material(0, mat)
