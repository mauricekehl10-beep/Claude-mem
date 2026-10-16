extends Node3D
# Fahrender Verkehr: Autos fahren auf den Fahrspuren (Rechtsverkehr), halten an roten Ampeln, halten Abstand,
# biegen an Kreuzungen ab oder fahren geradeaus. Gezeichnet per MultiMesh (Karosserie und Raeder), Kollision per AnimatableBody3D.
# Die Ampelphasen (signal_state) gelten auch fuer die Lampen an den Masten (city_signal.gdshader, Uhr = sig_clock).

const CM = preload("res://scripts/car_model.gd")
const CityCars = preload("res://scripts/city_cars.gd")

const STEP := 72.0
const LANE := 1.9
const WRAP := 230.0
const STOP := 8.8  # Haltelinie vor der Kreuzungsmitte
const LIM := 180.0  # Kreuzungen gibt es fuer |Koordinate| <= 180
const CYCLE := 24.0

static var clock := 0.0
static var _globals := false

var cars := []  # Dictionary je Auto
var groups := {}  # Typ -> {cars, body, wheels}
var rng := RandomNumberGenerator.new()
var main_ref
var tick := 0
var lanes_map := {}
var obs := []


static func ensure_globals() -> void:
	if not _globals:
		_globals = true
		RenderingServer.global_shader_parameter_add("sig_clock", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)


# 0 = gruen, 1 = gelb, 2 = rot fuer Verkehr entlang axis (0 = x, 1 = z) an Kreuzung (a, b) = Indexe der Strassenlinien
static func signal_state(axis: int, a: int, b: int, clk: float) -> int:
	var p := posmod(a + b + 1, 2)
	var zc := fposmod(clk + 12.0 * p, CYCLE)
	var c := zc if axis == 1 else fposmod(zc + 12.0, CYCLE)
	if c < 9.0:
		return 0
	if c < 11.0:
		return 1
	return 2


func _lane_list() -> Array:
	var lanes := []
	for k in range(-3, 3):
		var line := 36.0 + STEP * k
		for d in [-1, 1]:
			lanes.append([0, line, d])
			if absf(line - 36.0) > 1.0:  # Startstrasse bleibt frei
				lanes.append([1, line, d])
	return lanes


func setup(count: int, seed_value: int) -> void:
	ensure_globals()
	rng.seed = seed_value
	var lanes := _lane_list()
	for i in range(count):
		var type := CM.pick_type(rng, true)
		var inf := CM.info(type)
		var size: Vector3 = inf["size"]
		var body := AnimatableBody3D.new()
		body.sync_to_physics = true
		body.name = "Traffic%d" % i
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(size.x * 0.97, size.y * 0.9, size.z * 0.98)
		cs.shape = bs
		cs.position = Vector3(0, size.y * 0.45, 0)
		body.add_child(cs)
		add_child(body)
		var lane: Array = lanes[rng.randi() % lanes.size()]
		var s := 0.0
		for tries in range(12):
			s = rng.randf_range(-WRAP, WRAP)
			var ok := true
			for o in cars:
				if o["axis"] == lane[0] and o["line"] == lane[1] and o["dir"] == lane[2] and absf(o["s"] - s) < 16.0:
					ok = false
			if ok:
				break
		var c := {
			"type": type, "paint": CM.pick_paint(rng, type), "size": size, "len": size.z, "R": inf["R"], "wheels": inf["wheels"],
			"wb": inf["wheelbase"], "body": body, "shape": cs, "active": true, "respawn": 0.0,
			"mode": 0, "axis": lane[0], "line": lane[1], "dir": lane[2], "s": s,
			"v": rng.randf_range(5.0, 9.0), "vmax": rng.randf_range(9.5, 13.5), "plan_c": -9999.0, "plan": 0, "turn": {},
			"pos": Vector3.ZERO, "h": Vector2(1, 0), "yaw": 0.0, "spin": 0.0, "steer": 0.0, "braking": false,
			"yield_t": 0.0, "stuck": 0.0, "ignore": 0.0, "idx": 0,
		}
		cars.append(c)
		_pose(c)
		body.global_transform = Transform3D(Basis(Vector3.UP, c["yaw"]), c["pos"])
		if not groups.has(type):
			groups[type] = {"cars": []}
		c["idx"] = groups[type]["cars"].size()
		groups[type]["cars"].append(c)
	for type in groups:
		var g: Dictionary = groups[type]
		var n: int = g["cars"].size()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = CM.mesh(type, 0, false)
		mm.instance_count = n
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.name = "TrafficBodies_" + type
		mi.custom_aabb = AABB(Vector3(-600, -2, -600), Vector3(1200, 12, 1200))
		add_child(mi)
		var wm := MultiMesh.new()
		wm.transform_format = MultiMesh.TRANSFORM_3D
		wm.mesh = CM.wheel_mesh(type, 14)
		wm.instance_count = n * 4
		var wi := MultiMeshInstance3D.new()
		wi.multimesh = wm
		wi.name = "TrafficWheels_" + type
		wi.custom_aabb = mi.custom_aabb
		add_child(wi)
		g["body"] = mm
		g["wheels"] = wm
	_write()


# Lage (pos, h, yaw) aus der Spurposition
func _pose(c: Dictionary) -> void:
	var d: int = c["dir"]
	var s: float = c["s"]
	var line: float = c["line"]
	if c["axis"] == 0:
		c["pos"] = Vector3(s, 0.0, line + LANE * d)
		c["h"] = Vector2(d, 0)
	else:
		c["pos"] = Vector3(line - LANE * d, 0.0, s)
		c["h"] = Vector2(0, d)
	var h: Vector2 = c["h"]
	c["yaw"] = atan2(-h.x, -h.y)


func _lane_key(axis: int, line: float, d: int) -> int:
	return axis * 100000 + int(line + 1000.0) * 10 + (1 if d > 0 else 0)


func _next_center(s: float, d: int) -> float:
	if d > 0:
		return 36.0 + STEP * ceilf((s - 36.0) / STEP - 0.0001)
	return 36.0 + STEP * floorf((s - 36.0) / STEP + 0.0001)


func _state_for(c: Dictionary, cen: float) -> int:
	var line: float = c["line"]
	var a := roundi(((cen if c["axis"] == 0 else line) - 36.0) / STEP)
	var b := roundi(((line if c["axis"] == 0 else cen) - 36.0) / STEP)
	return signal_state(c["axis"], a, b, clock)


func _physics_process(delta: float) -> void:
	clock += delta
	RenderingServer.global_shader_parameter_set("sig_clock", clock)
	tick += 1
	lanes_map.clear()
	for c in cars:
		if c["active"] and c["mode"] == 0:
			var key := _lane_key(c["axis"], c["line"], c["dir"])
			if not lanes_map.has(key):
				lanes_map[key] = []
			lanes_map[key].append(c)
	_collect_obstacles()
	for c in cars:
		if c["active"]:
			_step(c, delta)
		else:
			c["respawn"] -= delta
			if c["respawn"] <= 0.0:
				_respawn(c)
	_write()


# Hindernisse ausser Verkehr: Spieler-Auto, abgestellte Autos, Spieler zu Fuss
func _collect_obstacles() -> void:
	obs.clear()
	if main_ref == null:
		return
	var veh = main_ref.vehicle
	if veh != null and is_instance_valid(veh):
		var f: Vector3 = -veh.global_transform.basis.z
		obs.append([Vector2(veh.global_position.x, veh.global_position.z), Vector2(f.x, f.z).normalized(), veh.size.z * 0.5, veh.size.x * 0.5])
	var cc = main_ref.city_cars
	if cc != null:
		for r in cc.dynamics:
			var xf: Transform3D = r["xf"]
			var f2: Vector3 = -xf.basis.z
			obs.append([Vector2(xf.origin.x, xf.origin.z), Vector2(f2.x, f2.z).normalized(), r["size"].z * 0.5, r["size"].x * 0.5])
	var pl = main_ref.player
	if pl != null and pl.active:
		obs.append([Vector2(pl.global_position.x, pl.global_position.z), Vector2(0, 1), 0.5, 0.5])


func _obstacle_limit(c: Dictionary) -> float:
	var lim := 99.0
	var p := Vector2(c["pos"].x, c["pos"].z)
	var h: Vector2 = c["h"]
	var right := Vector2(-h.y, h.x)
	for o in obs:
		var rel: Vector2 = o[0] - p
		var f := rel.dot(h)
		if f < 0.3 or f > 30.0:
			continue
		if absf(rel.dot(right)) > 1.25 + o[3]:
			continue
		var gap: float = f - c["len"] * 0.5 - o[2]
		lim = minf(lim, maxf(gap - 2.0, 0.0) * 0.9)
	return lim


func _step(c: Dictionary, delta: float) -> void:
	var limit: float = c["vmax"]
	c["ignore"] = maxf(c["ignore"] - delta, 0.0)
	if c["mode"] == 0:
		var v: float = c["v"]
		var d: int = c["dir"]
		var s: float = c["s"]
		var cen := _next_center(s, d)
		var dist_c := (cen - s) * d
		var front_dist: float = dist_c - STOP - float(c["len"]) * 0.5
		var has_x := absf(cen) <= LIM
		# Abbiegeplan fuer die naechste Kreuzung (einmal pro Kreuzung)
		if c["plan_c"] != cen and dist_c < 60.0:
			c["plan_c"] = cen
			c["plan"] = 0
			c["turn"] = {}
			if has_x:
				var r := rng.randf()
				if r < 0.2:
					_plan_turn(c, cen, 1)
				elif r < 0.36:
					_plan_turn(c, cen, 2)
		# Ampel
		if has_x and dist_c < 70.0 and front_dist > -1.0:
			var st := _state_for(c, cen)
			var stop := false
			if st == 2:
				stop = not (v * v / 16.0 > front_dist + 1.0 and front_dist < 4.0)
			elif st == 1:
				stop = v * v / 8.0 < front_dist + 2.0
			if stop:
				limit = minf(limit, sqrt(2.0 * 4.5 * maxf(front_dist - 0.4, 0.0)))
				if front_dist < 0.6:
					limit = 0.0
		# Abbiegen: vorher langsamer, links erst bei freiem Gegenverkehr
		var plan: int = c["plan"]
		if plan != 0 and dist_c < 40.0:
			limit = minf(limit, 8.5)
			if plan == 2 and front_dist < 4.0 and front_dist > -1.0 and c["yield_t"] < 6.0:
				if _oncoming(c, cen):
					limit = 0.0 if front_dist < 1.5 else minf(limit, 2.0)
					c["yield_t"] += delta
		# Vordermann in der Spur
		for o in lanes_map.get(_lane_key(c["axis"], c["line"], d), []):
			if o == c:
				continue
			var gap: float = (o["s"] - s) * d - (o["len"] + c["len"]) * 0.5
			if gap > -1.0 and gap < 30.0:
				var lim_l: float
				if gap < 3.0:
					lim_l = maxf(minf(o["v"], gap - 1.0), 0.0)
				else:
					lim_l = o["v"] + (gap - 3.0) * 0.8
				limit = minf(limit, lim_l)
		if c["ignore"] <= 0.0:
			limit = minf(limit, _obstacle_limit(c))
		_accel(c, limit, delta)
		s += d * c["v"] * delta
		if s > WRAP:
			s -= 2.0 * WRAP
		elif s < -WRAP:
			s += 2.0 * WRAP
		c["s"] = s
		c["steer"] = 0.0
		_pose(c)
		if plan != 0 and not c["turn"].is_empty():
			var t: Dictionary = c["turn"]
			if (t["e"] - s) * d <= 0.0:
				_start_turn(c, t)
	else:
		var t: Dictionary = c["turn"]
		limit = minf(limit, 6.0 if t["sgn"] > 0 else 7.0)
		if c["ignore"] <= 0.0:
			limit = minf(limit, _obstacle_limit(c))
		_accel(c, limit, delta)
		t["u"] += c["v"] * delta
		var phi: float = minf(t["u"] / t["r"], PI * 0.5)
		var h0: Vector2 = t["h0"]
		var sg: float = t["sgn"]  # +1 rechts, -1 links
		var h := h0 * cos(phi) + Vector2(-h0.y, h0.x) * sg * sin(phi)
		var inner := Vector2(-h.y, h.x) * sg
		var p2: Vector2 = t["o"] - inner * t["r"]
		c["pos"] = Vector3(p2.x, 0.0, p2.y)
		c["h"] = h
		c["yaw"] = atan2(-h.x, -h.y)
		c["steer"] = -sg * atan(c["wb"] / t["r"])
		if phi >= PI * 0.5 - 0.0001:
			c["mode"] = 0
			c["axis"] = t["axis2"]
			c["dir"] = t["d2"]
			c["line"] = t["cen"]
			c["s"] = p2.y if t["axis2"] == 1 else p2.x
			c["plan"] = 0
			c["plan_c"] = -9999.0
			c["turn"] = {}
			c["yield_t"] = 0.0
			_pose(c)
	# Festgefahren? Dann kurz Hindernisse ignorieren
	if c["v"] < 0.3:
		c["stuck"] += delta
		if c["stuck"] > 18.0:
			c["ignore"] = 4.0
			c["stuck"] = 0.0
			c["yield_t"] = 99.0
	else:
		c["stuck"] = 0.0
	c["spin"] -= c["v"] / c["R"] * delta
	# Kollisionskoerper nachfuehren (nahe Autos jeden Tick, ferne seltener)
	var cam := get_viewport().get_camera_3d()
	var near := cam == null or cam.global_position.distance_squared_to(c["pos"]) < 80.0 * 80.0
	if near or (tick + c["idx"]) % 12 == 0:
		(c["body"] as AnimatableBody3D).global_transform = Transform3D(Basis(Vector3.UP, c["yaw"]), c["pos"])


func _accel(c: Dictionary, limit: float, delta: float) -> void:
	var v: float = c["v"]
	if v < limit:
		v = minf(v + 2.8 * delta, limit)
		c["braking"] = false
	else:
		v = maxf(v - 8.0 * delta, maxf(limit, 0.0))
		c["braking"] = v > limit + 0.2 or v < 0.8
	c["v"] = v


func _oncoming(c: Dictionary, cen: float) -> bool:
	var od: int = -int(c["dir"])
	for o in lanes_map.get(_lane_key(c["axis"], c["line"], od), []):
		var dd: float = (cen - o["s"]) * od
		if dd > -6.0 and dd < 28.0 and o["v"] > 0.8:
			return true
	return false


# Abbiegeweg planen: pl 1 = rechts, 2 = links
func _plan_turn(c: Dictionary, cen: float, pl: int) -> void:
	var d: int = c["dir"]
	var axis: int = c["axis"]
	var d2 := 0
	if axis == 0:
		d2 = d if pl == 1 else -d
	else:
		d2 = -d if pl == 1 else d
	var axis2 := 1 - axis
	if axis2 == 1 and absf(cen - 36.0) < 1.0:
		return  # nicht in die Startstrasse
	var r := 3.6 if pl == 1 else 6.8
	var line: float = c["line"]
	var k := Vector2.ZERO  # Ecke der beiden Spuren
	var h0 := Vector2.ZERO
	var e_along := 0.0
	if axis == 0:
		k = Vector2(cen - LANE * d2, line + LANE * d)
		h0 = Vector2(d, 0)
		e_along = k.x - d * r
	else:
		k = Vector2(line - LANE * d, cen + LANE * d2)
		h0 = Vector2(0, d)
		e_along = k.y - d * r
	c["plan"] = pl
	c["turn"] = {"r": r, "sgn": 1.0 if pl == 1 else -1.0, "e": e_along, "k": k, "h0": h0, "u": 0.0, "axis2": axis2, "d2": d2, "cen": cen, "o": Vector2.ZERO}


func _start_turn(c: Dictionary, t: Dictionary) -> void:
	var h0: Vector2 = t["h0"]
	var k: Vector2 = t["k"]
	var e: Vector2 = k - h0 * t["r"]
	t["o"] = e + Vector2(-h0.y, h0.x) * t["sgn"] * t["r"]
	t["u"] = 0.0
	c["mode"] = 1


func take(c: Dictionary) -> void:
	c["active"] = false
	c["respawn"] = 15.0
	(c["shape"] as CollisionShape3D).disabled = true
	(c["body"] as AnimatableBody3D).global_position = Vector3(0, -100, 0)


func _respawn(c: Dictionary) -> void:
	var lanes := _lane_list()
	var lane: Array = lanes[rng.randi() % lanes.size()]
	c["axis"] = lane[0]
	c["line"] = lane[1]
	c["dir"] = lane[2]
	c["s"] = -WRAP * lane[2] + lane[2] * 4.0
	c["mode"] = 0
	c["v"] = 6.0
	c["plan_c"] = -9999.0
	c["plan"] = 0
	c["turn"] = {}
	c["active"] = true
	(c["shape"] as CollisionShape3D).disabled = false
	_pose(c)


func find_near(p: Vector3, max_d: float) -> Dictionary:
	var best := {}
	var bd := max_d
	for c in cars:
		if not c["active"]:
			continue
		var xf := Transform3D(Basis(Vector3.UP, c["yaw"]), c["pos"])
		var dd := CityCars.box_dist(p, xf, c["size"])
		if dd < bd:
			bd = dd
			best = c
	if best.is_empty():
		return best
	return {"car": best, "dist": bd}


func _write() -> void:
	for type in groups:
		var g: Dictionary = groups[type]
		var mm: MultiMesh = g["body"]
		var wm: MultiMesh = g["wheels"]
		var list: Array = g["cars"]
		for i in range(list.size()):
			var c: Dictionary = list[i]
			if not c["active"]:
				var z := Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -100, 0))
				mm.set_instance_transform(i, z)
				for k in range(4):
					wm.set_instance_transform(i * 4 + k, z)
				continue
			var xf := Transform3D(Basis(Vector3.UP, c["yaw"]), c["pos"])
			mm.set_instance_transform(i, xf)
			var p: Color = c["paint"]
			mm.set_instance_custom_data(i, Color(p.r, p.g, p.b, 1.0 if c["braking"] else 0.0))
			var wl: Array = c["wheels"]
			for k in range(4):
				var wp: Vector3 = wl[k]
				var b := Basis.IDENTITY
				if k < 2:
					b = Basis(Vector3.UP, c["steer"])
				b = b * Basis(Vector3.RIGHT, c["spin"])
				if wp.x < 0.0:
					b = b * Basis(Vector3.UP, PI)
				wm.set_instance_transform(i * 4 + k, xf * Transform3D(b, wp))
