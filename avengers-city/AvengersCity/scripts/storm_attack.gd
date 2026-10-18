extends RefCounted
# Posen für die Stormbreaker-Angriffe (nur Code, keine Mixamo-Clips). Läuft nach dem Animations-Update (Signal mixer_applied)
# und überlagert die Pose von Rumpf und Armen; Beine bleiben bei der Animation (Laufen geht also weiter).
#  "axe"    = Axtschlag von oben nach schräg vorn unten (Ausholen über der rechten Schulter, Rumpf dreht ein, Schwung, Nachschwung)
#  "throw"  = Axtwurf: Axt hinter die Schulter, dann der Arm schnellt vor (die Axt löst sich im Release-Bild)
#  "arrive" = Ankunft im Bifrost-Strahl: Arme weit auseinander, Brust raus, Axt in der rechten Hand nach oben
#  "summon" = Wechsel zu Mjolnir: rechter Arm reisst nach oben
# Punkte (Faust) und Richtungen (Axtstiel) im Skelettraum: +X = links, +Y = oben, +Z = vorn.

const Rig = preload("res://scripts/storm_rig.gd")

# Ruhehaltung (Axt locker getragen), mit der jede Bewegung beginnt und endet
const CARRY_R := Vector3(-0.29, 0.98, 0.22)
const CARRY_D := Vector3(-0.12, 0.62, 0.78)
const CARRY_L := Vector3(0.28, 0.92, 0.08)
const POLE_R := Vector3(-0.6, -0.6, -0.5)
const POLE_L := Vector3(0.6, -0.6, -0.5)

# Schlüsselbilder: t, yaw (+ = Oberkörper nach links), pitch (+ = nach vorn), roll, pr (Faust rechts), dr (Stielrichtung), pl (Faust links)
const KEYS := {
	"axe": [
		{"t": 0.00, "yaw": 0.0, "pitch": 0.0, "roll": 0.0, "pr": CARRY_R, "dr": CARRY_D, "pl": CARRY_L},
		{"t": 0.15, "yaw": -0.60, "pitch": -0.22, "roll": -0.08, "pr": Vector3(-0.30, 1.80, -0.14), "dr": Vector3(-0.15, 0.80, -0.58), "pl": Vector3(0.42, 1.42, 0.28)},
		{"t": 0.27, "yaw": 0.38, "pitch": 0.36, "roll": 0.06, "pr": Vector3(-0.12, 1.22, 0.56), "dr": Vector3(0.10, -0.25, 0.96), "pl": Vector3(0.22, 1.08, -0.06)},
		{"t": 0.40, "yaw": 0.55, "pitch": 0.46, "roll": 0.08, "pr": Vector3(0.02, 1.02, 0.52), "dr": Vector3(0.22, -0.70, 0.68), "pl": Vector3(0.24, 1.0, -0.10)},
		{"t": 0.66, "yaw": 0.0, "pitch": 0.0, "roll": 0.0, "pr": CARRY_R, "dr": CARRY_D, "pl": CARRY_L},
	],
	"throw": [
		{"t": 0.00, "yaw": 0.0, "pitch": 0.0, "roll": 0.0, "pr": CARRY_R, "dr": CARRY_D, "pl": CARRY_L},
		{"t": 0.16, "yaw": -0.75, "pitch": -0.15, "roll": -0.05, "pr": Vector3(-0.36, 1.55, -0.26), "dr": Vector3(-0.20, 0.60, -0.77), "pl": Vector3(0.46, 1.50, 0.36)},
		{"t": 0.27, "yaw": 0.28, "pitch": 0.22, "roll": 0.05, "pr": Vector3(-0.20, 1.50, 0.56), "dr": Vector3(0.0, 0.20, 0.98), "pl": Vector3(0.24, 1.15, -0.04)},
		{"t": 0.46, "yaw": 0.30, "pitch": 0.20, "roll": 0.04, "pr": Vector3(-0.16, 1.46, 0.62), "dr": Vector3(0.0, 0.10, 1.0), "pl": Vector3(0.26, 1.1, -0.04)},
		{"t": 0.70, "yaw": 0.0, "pitch": 0.0, "roll": 0.0, "pr": CARRY_R, "dr": CARRY_D, "pl": CARRY_L},
	],
	"arrive": [
		{"t": 0.00, "yaw": 0.0, "pitch": 0.0, "roll": 0.0, "pr": CARRY_R, "dr": CARRY_D, "pl": CARRY_L},
		{"t": 0.22, "yaw": 0.0, "pitch": -0.14, "roll": 0.0, "pr": Vector3(-0.72, 1.40, 0.04), "dr": Vector3(-0.30, 0.92, 0.22), "pl": Vector3(0.72, 1.40, 0.04)},
		{"t": 0.55, "yaw": 0.0, "pitch": -0.12, "roll": 0.0, "pr": Vector3(-0.70, 1.42, 0.05), "dr": Vector3(-0.28, 0.93, 0.22), "pl": Vector3(0.70, 1.42, 0.05)},
		{"t": 0.85, "yaw": 0.0, "pitch": 0.0, "roll": 0.0, "pr": CARRY_R, "dr": CARRY_D, "pl": CARRY_L},
	],
	"summon": [
		{"t": 0.00, "yaw": 0.0, "pitch": 0.0, "roll": 0.0, "pr": CARRY_R, "dr": CARRY_D, "pl": CARRY_L},
		{"t": 0.15, "yaw": 0.0, "pitch": -0.10, "roll": 0.0, "pr": Vector3(-0.20, 1.85, 0.10), "dr": Vector3(-0.05, 1.0, 0.15), "pl": Vector3(0.40, 1.30, 0.20)},
		{"t": 0.30, "yaw": 0.0, "pitch": -0.08, "roll": 0.0, "pr": Vector3(-0.20, 1.85, 0.10), "dr": Vector3(-0.05, 1.0, 0.15), "pl": Vector3(0.40, 1.30, 0.20)},
		{"t": 0.55, "yaw": 0.0, "pitch": 0.0, "roll": 0.0, "pr": CARRY_R, "dr": CARRY_D, "pl": CARRY_L},
	],
}

var rig: Rig
var kind := ""  # läuft gerade: axe, throw, arrive, summon (leer = nichts)
var t := 0.0
var hold_axe := true  # Axt liegt in der Hand (Griff um den Stiel); sonst bleibt die Hand offen
var env := 0.0  # Stärke 0..1 (für andere Teile, z. B. Fingerkrümmung)


func _init(r: Rig) -> void:
	rig = r


func set_state(k: String, time: float) -> void:
	kind = k
	t = time


static func length(k: String) -> float:
	return KEYS[k][KEYS[k].size() - 1]["t"]


# Weiche Kurve durch die Schlüsselbilder (Catmull-Rom, Anfang und Ende laufen sanft an)
static func sample(keys: Array, time: float) -> Dictionary:
	var n := keys.size()
	if time <= keys[0]["t"]:
		return keys[0]
	if time >= keys[n - 1]["t"]:
		return keys[n - 1]
	var i := 0
	while keys[i + 1]["t"] < time:
		i += 1
	var a: Dictionary = keys[i]
	var b: Dictionary = keys[i + 1]
	var h: float = b["t"] - a["t"]
	var k: float = (time - a["t"]) / h
	var k2 := k * k
	var k3 := k2 * k
	var out := {}
	for f in a:
		if f == "t":
			continue
		var va = a[f]
		var vb = b[f]
		var ma
		var mb
		if i == 0:
			ma = va * 0.0
		else:
			var pa = keys[i - 1]
			ma = (vb - pa[f]) / (b["t"] - pa["t"])
		if i + 2 >= n:
			mb = vb * 0.0
		else:
			var nb = keys[i + 2]
			mb = (nb[f] - va) / (nb["t"] - a["t"])
		out[f] = va * (2.0 * k3 - 3.0 * k2 + 1.0) + ma * h * (k3 - 2.0 * k2 + k) + vb * (-2.0 * k3 + 3.0 * k2) + mb * h * (k3 - k2)
	return out


func apply() -> void:
	env = 0.0
	if kind == "" or not rig.valid() or not KEYS.has(kind):
		return
	var ln := length(kind)
	env = smoothstep(0.0, 0.07, t) * (1.0 - smoothstep(ln - 0.14, ln, t))
	if env < 0.002:
		return
	var k := sample(KEYS[kind], t)
	rig.spine(k["yaw"], k["pitch"], k["roll"], env)
	var D: Vector3 = (k["dr"] as Vector3).normalized()
	rig.arm_to("Right", rig.wrist("Right", k["pr"]), POLE_R, env)
	if kind != "summon":
		rig.grip("Right", D, env)  # beim Wechsel zu Mjolnir hält die Hand die Axt nicht mehr
	rig.arm_to("Left", rig.wrist("Left", k["pl"]), POLE_L, env)
