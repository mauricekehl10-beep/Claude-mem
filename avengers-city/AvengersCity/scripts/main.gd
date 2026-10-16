extends Node3D
# Avengers City - Phase 1: offene Stadt, zu Fuss und im Auto, Heldenwechsel.

const U = preload("res://scripts/util.gd")
const PlayerScript = preload("res://scripts/player.gd")
const CarScript = preload("res://scripts/car.gd")
const EnemyScript = preload("res://scripts/enemy.gd")

const CityEnv = preload("res://scripts/city_env.gd")
const CityGround = preload("res://scripts/city_ground.gd")
const CityBuildings = preload("res://scripts/city_buildings.gd")
const CityProps = preload("res://scripts/city_props.gd")
const CityCars = preload("res://scripts/city_cars.gd")
const CityPark = preload("res://scripts/city_park.gd")
const CityTraffic = preload("res://scripts/city_traffic.gd")
const CityMats = preload("res://scripts/city_mats.gd")
const BLOCK := 56.0
const STREET := 16.0
const GRID := 5
const RING := 4  # Block-Ringe um das 5x5-Kernraster (Kulisse)
const STEP := BLOCK + STREET

var player
var vehicle
var in_car := false
var hud: Label
var prompt: Label
var help: Label
var crosshair: Control
var city_gen
var city_props
var city_cars
var city_park
var U_SOLID: Material = CityMats.solid()


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
	CityEnv.build(self)


func build_world() -> void:
	# Kollision des Bodens (sichtbar ist die Asphalt-Ebene aus city_ground)
	var ground := StaticBody3D.new()
	ground.name = "GroundCollision"
	add_child(ground)
	var gcol := CollisionShape3D.new()
	var gbs := BoxShape3D.new()
	gbs.size = Vector3(2400, 1, 2400)
	gcol.shape = gbs
	gcol.position = Vector3(0, -0.5, 0)
	ground.add_child(gcol)
	CityGround.build(self, 2, RING)

	city_gen = CityBuildings.new(20250611)
	city_props = CityProps.new()
	city_cars = CityCars.new()
	city_park = CityPark.new()
	for ix in range(-2 - RING, 3 + RING):
		for iz in range(-2 - RING, 3 + RING):
			var core := absi(ix) <= 2 and absi(iz) <= 2
			var cx: float = ix * STEP
			var cz: float = iz * STEP
			var zone := maxi(absi(ix), absi(iz))
			if core and zone != 0 and ((ix + 2) + 2 * (iz + 2)) % 5 == 1:
				city_park.build(self, cx, cz, ix, iz, city_props)
			else:
				var node: Node3D = build_block(cx, cz, city_gen, zone, core)
				if zone == 0:
					# Platz um den Turm: Baeume
					for p in [Vector2(-22.5, 0), Vector2(22.5, 0), Vector2(0, -22.5), Vector2(0, 22.5), Vector2(-22.5, -22.5), Vector2(22.5, 22.5), Vector2(-22.5, 22.5), Vector2(22.5, -22.5)]:
						city_props.trees.add("round", Vector3(cx + p.x, 0.15, cz + p.y), city_props.rng)
			if zone <= 3:
				city_props.block_props(self, cx, cz, zone, ix, iz, U_SOLID)
			if zone <= 3:
				city_cars.park_block(self, cx, cz, 0.62 if zone <= 2 else 0.3, ix, iz)
	build_roads()
	build_lamps()
	build_parked_cars()
	# Fahrender Verkehr
	var traffic := CityTraffic.new()
	traffic.name = "Traffic"
	add_child(traffic)
	traffic.setup(26, 77)


func build_block(cx: float, cz: float, gen, zone: int, core: bool) -> Node3D:
	if zone == 0:
		return gen.build_landmark(self, cx, cz)
	return gen.build_block(self, cx, cz, zone, core)


func build_park(_cx: float, _cz: float) -> void:
	pass  # Parks entstehen in build_world (city_park.gd)


func build_roads() -> void:
	pass  # Fahrbahnen und Markierungen zeichnet der Boden-Shader (city_ground.gdshader)


func build_lamps() -> void:
	pass  # Laternen entstehen pro Block in city_props.gd


func build_parked_cars() -> void:
	city_cars.commit(self)
	CityGround.outskirts(self, city_props.trees, 470.0)
	city_props.trees.commit(self)


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
	crosshair = Control.new()
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(crosshair)
	for r in [Rect2(-14, -1, 9, 2), Rect2(5, -1, 9, 2), Rect2(-1, -14, 2, 9), Rect2(-1, 5, 2, 9), Rect2(-1.5, -1.5, 3, 3)]:
		var shadow := ColorRect.new()
		shadow.position = r.position - Vector2(1, 1)
		shadow.size = r.size + Vector2(2, 2)
		shadow.color = Color(0, 0, 0, 0.6)
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crosshair.add_child(shadow)
		var bar := ColorRect.new()
		bar.position = r.position
		bar.size = r.size
		bar.color = Color(1, 1, 1, 0.9)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crosshair.add_child(bar)
	help = Label.new()
	help.position = Vector2(18, 670)
	help.text = "WASD laufen · Maus umsehen · Shift sprinten · Leertaste springen · Tab Held wechseln · G ins Auto · ESC Maus frei\nCaptain: Linksklick schlagen · Rechtsklick Schild werfen   |   Iron Man: in der Luft Leertaste halten = fliegen · Linksklick schießen · Strg sinken (oder Leertaste loslassen = landen)   |   Thor: Linksklick Hammer · Rechtsklick Blitz"
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
	crosshair.visible = not in_car
	crosshair.position = (get_viewport().get_visible_rect().size * 0.5).floor()
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
