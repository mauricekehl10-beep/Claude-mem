extends Node3D
# Avengers City - Phase 1: offene Stadt, zu Fuss und im Auto, Heldenwechsel.

const U = preload("res://scripts/util.gd")
const PlayerScript = preload("res://scripts/player.gd")
const CarScript = preload("res://scripts/car.gd")
const EnemyScript = preload("res://scripts/enemy.gd")

const BLOCK := 56.0
const STREET := 16.0
const GRID := 5
const STEP := BLOCK + STREET

var player
var vehicle
var in_car := false
var hud: Label
var prompt: Label
var help: Label


func _ready() -> void:
	setup_input()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	build_environment()
	build_world()
	player = PlayerScript.new()
	add_child(player)
	player.global_position = Vector3(36, 0, -20)
	player.start_pos = player.global_position
	for pos in [Vector3(34, 1, -45), Vector3(39, 1, -60), Vector3(34, 1, -80), Vector3(39, 1, -100), Vector3(36, 1, 60)]:
		var en = EnemyScript.new()
		add_child(en)
		en.global_position = pos
	vehicle = CarScript.new()
	add_child(vehicle)
	vehicle.global_position = Vector3(36, 0, 0)
	build_hud()


func setup_input() -> void:
	var actions := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
		"sprint": [KEY_SHIFT],
		"interact": [KEY_G],
		"switch_hero": [KEY_TAB],
		"descend": [KEY_CTRL, KEY_C],
	}
	for act in actions:
		if not InputMap.has_action(act):
			InputMap.add_action(act)
		InputMap.action_erase_events(act)
		for code in actions[act]:
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(act, ev)
	for act in ["attack", "throw"]:
		if not InputMap.has_action(act):
			InputMap.add_action(act)
		InputMap.action_erase_events(act)
		var mev := InputEventMouseButton.new()
		mev.button_index = MOUSE_BUTTON_LEFT if act == "attack" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(act, mev)


func _unhandled_input(event: InputEvent) -> void:
	var ke := event as InputEventKey
	if ke and ke.pressed and not ke.echo and ke.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func block_centers() -> Array:
	var out := []
	for i in range(GRID):
		out.append((i - (GRID - 1) * 0.5) * STEP)
	return out


func street_lines() -> Array:
	var out := []
	for k in range(-1, GRID):
		out.append((k + 0.5 - (GRID - 1) * 0.5) * STEP)
	return out


func build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.05, 0.07, 0.18)
	psm.sky_horizon_color = Color(0.45, 0.36, 0.6)
	psm.ground_horizon_color = Color(0.25, 0.2, 0.3)
	psm.ground_bottom_color = Color(0.05, 0.05, 0.07)
	var hdr := U.find_asset("quarry_01_puresky_2k.hdr")
	if hdr != "":
		var pano := PanoramaSkyMaterial.new()
		pano.panorama = load(hdr)
		sky.sky_material = pano
	else:
		sky.sky_material = psm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.1
	env.fog_enabled = true
	env.fog_sky_affect = 0.0
	env.fog_light_color = Color(0.35, 0.3, 0.5)
	env.fog_density = 0.003
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 1.6
	sun.light_color = Color(1.0, 0.9, 0.75)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 200.0
	add_child(sun)


func make_window_texture() -> ImageTexture:
	var img := Image.create(64, 128, false, Image.FORMAT_RGB8)
	img.fill(Color(0.12, 0.14, 0.24))
	for y in range(8, 120, 14):
		for x in range(6, 58, 12):
			var lit := randf() < 0.45
			var col := Color(1.0, 0.85, 0.5) if lit else Color(0.12, 0.14, 0.24)
			img.fill_rect(Rect2i(x, y, 7, 9), col)
	return ImageTexture.create_from_image(img)


func build_world() -> void:
	var ground := StaticBody3D.new()
	add_child(ground)
	var gcol := CollisionShape3D.new()
	var gbs := BoxShape3D.new()
	gbs.size = Vector3(2400, 1, 2400)
	gcol.shape = gbs
	gcol.position = Vector3(0, -0.5, 0)
	ground.add_child(gcol)
	U.box(ground, Vector3(2400, 1, 2400), Vector3(0, -0.5, 0), U.mat(Color(0.13, 0.13, 0.15), 0.95))

	var tex := make_window_texture()
	var centers := block_centers()
	for ix in range(GRID):
		for iz in range(GRID):
			var cx: float = centers[ix]
			var cz: float = centers[iz]
			U.box(self, Vector3(BLOCK, 0.05, BLOCK), Vector3(cx, 0.025, cz), U.mat(Color(0.42, 0.42, 0.45), 0.9))
			var is_center := ix == 2 and iz == 2
			if (ix + 2 * iz) % 5 == 1 and not is_center:
				build_park(cx, cz)
			else:
				build_block(cx, cz, tex)
	build_roads()
	build_lamps()
	build_parked_cars()


func build_block(cx: float, cz: float, tex: Texture2D) -> void:
	var tall: bool = abs(cx) < 0.1 and abs(cz) < 0.1
	var h: float = 70.0 if tall else randf_range(16.0, 52.0)
	add_building(cx + randf_range(-3, 3), cz + randf_range(-3, 3), randf_range(24.0, 36.0), randf_range(24.0, 36.0), h, tex)


func add_building(cx: float, cz: float, fw: float, fd: float, h: float, tex: Texture2D) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(randf_range(0.6, 1.0), randf_range(0.6, 1.0), randf_range(0.7, 1.0))
	m.albedo_texture = tex
	m.uv1_scale = Vector3(fw / 10.0, h / 12.0, 1.0)
	m.emission_enabled = true
	m.emission_texture = tex
	m.emission_energy_multiplier = 0.9
	m.roughness = 0.55
	var body := StaticBody3D.new()
	body.position = Vector3(cx, 0.05, cz)
	add_child(body)
	var model := U.load_model("building-%s.glb" % char(97 + randi() % 14))
	if model:
		var box := U.model_aabb(model)
		var s := h / maxf(box.size.y, 0.01)
		model.scale = Vector3.ONE * s
		model.position = Vector3(-box.get_center().x * s, -box.position.y * s, -box.get_center().z * s)
		body.add_child(model)
	else:
		U.box(body, Vector3(fw, h, fd), Vector3(0, h * 0.5, 0), m)
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(fw, h, fd)
	col.shape = bs
	col.position = Vector3(0, h * 0.5, 0)
	body.add_child(col)
	if not model:
		if randf() < 0.5:
			U.box(body, Vector3(fw * 0.4, 4.0, fd * 0.4), Vector3(0, h + 2.0, 0), U.mat(Color(0.25, 0.27, 0.32), 0.7, 0.2))
		if h > 40.0:
			U.cyl(body, 0.12, 8.0, Vector3(0, h + 4.0, 0), U.glow(Color(1, 0.2, 0.2), 3.0))


func build_park(cx: float, cz: float) -> void:
	U.box(self, Vector3(BLOCK - 2, 0.08, BLOCK - 2), Vector3(cx, 0.06, cz), U.mat(Color(0.16, 0.4, 0.18), 0.95))
	for dx in [-14.0, 14.0]:
		for dz in [-14.0, 14.0]:
			var tx: float = cx + dx + randf_range(-2, 2)
			var tz: float = cz + dz + randf_range(-2, 2)
			U.cyl(self, 0.35, 3.0, Vector3(tx, 1.5, tz), U.mat(Color(0.3, 0.2, 0.12), 0.9))
			U.sphere(self, 2.3, Vector3(tx, 4.3, tz), U.mat(Color(0.14, 0.42, 0.16), 0.9))
	U.box(self, Vector3(2.0, 0.15, 0.6), Vector3(cx, 0.5, cz + 6), U.mat(Color(0.35, 0.22, 0.12), 0.8))


func multimesh(transforms: Array, mesh: Mesh, m: Material) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	add_child(mmi)


func build_roads() -> void:
	var half := GRID * STEP * 0.5
	var dash_mesh := BoxMesh.new()
	dash_mesh.size = Vector3(0.35, 0.02, 3.0)
	var transforms := []
	for bx in street_lines():
		var z: float = -half + 4.0
		while z < half:
			transforms.append(Transform3D(Basis(), Vector3(bx, 0.04, z)))
			z += 9.0
	for bz in street_lines():
		var x: float = -half + 4.0
		while x < half:
			transforms.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x, 0.04, bz)))
			x += 9.0
	multimesh(transforms, dash_mesh, U.mat(Color(0.95, 0.85, 0.3), 0.7))


func build_lamps() -> void:
	var centers := block_centers()
	var poles := []
	var heads := []
	for bx in street_lines():
		for cz in centers:
			poles.append(Transform3D(Basis(), Vector3(bx + 6.0, 3.5, cz)))
			heads.append(Transform3D(Basis(), Vector3(bx + 6.0, 7.1, cz)))
	for bz in street_lines():
		for cx in centers:
			poles.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(cx, 3.5, bz + 6.0)))
			heads.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(cx, 7.1, bz + 6.0)))
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.12
	pole_mesh.bottom_radius = 0.14
	pole_mesh.height = 7.0
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.4
	head_mesh.height = 0.8
	multimesh(poles, pole_mesh, U.mat(Color(0.1, 0.1, 0.12), 0.5, 0.6))
	multimesh(heads, head_mesh, U.glow(Color(1.0, 0.85, 0.55), 4.0))

	var lines := street_lines()
	for i in range(8):
		var l := OmniLight3D.new()
		l.position = Vector3(lines[randi() % lines.size()], 8.0, lines[randi() % lines.size()])
		l.light_color = Color(1.0, 0.8, 0.5)
		l.light_energy = 2.0
		l.omni_range = 28.0
		add_child(l)


func build_parked_cars() -> void:
	var colors := [Color(0.85, 0.85, 0.9), Color(0.1, 0.25, 0.5), Color(0.2, 0.2, 0.22), Color(0.6, 0.45, 0.1)]
	for bx in street_lines():
		for i in range(4):
			var z := randf_range(-150.0, 150.0)
			if abs(z) < 12.0:
				continue
			var body := StaticBody3D.new()
			body.position = Vector3(bx - 5.0, 0, z)
			body.rotation.y = 0.0 if randf() < 0.5 else PI
			add_child(body)
			var col := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(1.9, 1.2, 4.2)
			col.shape = bs
			col.position = Vector3(0, 0.6, 0)
			body.add_child(col)
			CarScript.build_visual(body, colors[randi() % colors.size()])


func build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(18, 14)
	hud.add_theme_font_size_override("font_size", 24)
	layer.add_child(hud)
	prompt = Label.new()
	prompt.position = Vector2(520, 560)
	prompt.add_theme_font_size_override("font_size", 26)
	layer.add_child(prompt)
	help = Label.new()
	help.position = Vector2(18, 670)
	help.text = "WASD laufen · Maus umsehen · Shift sprinten · Leertaste springen · Tab Held wechseln · G ins Auto · ESC Maus frei\nCaptain: Linksklick schlagen · Rechtsklick Schild werfen   |   Iron Man: in der Luft Leertaste halten = fliegen · Linksklick schießen · Strg sinken (oder Leertaste loslassen = landen)"
	layer.add_child(help)


func _process(_delta: float) -> void:
	var near: bool = (not in_car) and player.global_position.distance_to(vehicle.global_position) < 4.5
	if Input.is_action_just_pressed("interact"):
		if in_car:
			exit_car()
		elif near:
			enter_car()
	if Input.is_action_just_pressed("switch_hero") and not in_car:
		player.next_hero()
	prompt.text = "G: Einsteigen" if near else ""
	if in_car:
		hud.text = "Auto · %d km/h" % int(abs(vehicle.speed) * 3.6)
	else:
		hud.text = "%s · zu Fuss" % player.hero_name()


func enter_car() -> void:
	in_car = true
	vehicle.active = true
	vehicle.cam.current = true
	player.set_active(false)


func exit_car() -> void:
	in_car = false
	vehicle.active = false
	vehicle.speed = 0.0
	player.global_position = vehicle.global_position + vehicle.global_transform.basis.x * 2.2 + Vector3(0, 0.2, 0)
	player.set_active(true)
