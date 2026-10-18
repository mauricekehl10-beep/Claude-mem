extends Node
# Energie-Effekte um Thor, solange er Stormbreaker führt und aufgeladen ist (Flug, Angriff, Wechsel):
#  - Blitzbögen um den Oberkörper, blaues Licht auf der Figur
#  - weiss leuchtende Augen
#  - lange Blitze, die beim Schweben nach unten hängen und im Flug hinter Thor herziehen (wie im Clip)
# power (0..1) legt fest, wie stark alles ist; es wird weich nachgeführt.

const VFX = preload("res://scripts/vfx.gd")
const Arcs = preload("res://scripts/storm_arcs.gd")

var pl
var skel: Skeleton3D
var body_arcs
var trail_arcs
var light: OmniLight3D
var eye_mats: Array = []
var eyes: Array = []
var power := 0.0
var want := 0.0
var trail_want := 0.0
var trail_p := 0.0
var _dir := Vector3.DOWN


func setup(player, skeleton: Skeleton3D) -> void:
	pl = player
	skel = skeleton
	var chest := BoneAttachment3D.new()
	chest.name = "A_StormFx"
	chest.bone_name = "mixamorig_Spine2"
	skel.add_child(chest)
	body_arcs = Arcs.new()
	body_arcs.position = Vector3(0, 0.1, 0.02)
	body_arcs.count = 4
	body_arcs.radius = 0.42
	body_arcs.seg_len = 0.55
	body_arcs.width = 0.011
	body_arcs.rate = 16.0
	body_arcs.intensity = 0.0
	chest.add_child(body_arcs)
	light = OmniLight3D.new()
	light.light_color = Color(0.5, 0.72, 1.0)
	light.omni_range = 6.0
	light.light_energy = 0.0
	light.shadow_enabled = false
	light.position = Vector3(0, 0.1, 0.25)
	chest.add_child(light)
	# Augen: zwei Leuchtflecke vor dem Gesicht (Kopfknochen: Ursprung bei y=1.6008, Augen bei x=±0.0315, y=1.6635)
	var head := BoneAttachment3D.new()
	head.name = "A_StormEyes"
	head.bone_name = "mixamorig_Head"
	skel.add_child(head)
	for s in [-1.0, 1.0]:
		var m := VFX._flare_mat(Color(0.82, 0.94, 1.0), 4.0, 1.0, 0.0, 0.0, 1.0)
		var mi := MeshInstance3D.new()
		mi.mesh = VFX._quad()
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.scale = Vector3.ONE * 0.05
		mi.position = Vector3(s * 0.0315, 0.0627, 0.112)
		mi.visible = false
		head.add_child(mi)
		eyes.append(mi)
		eye_mats.append(m)
	# lange Blitze: hängen in der Welt-Ausrichtung am Körper
	trail_arcs = Arcs.new()
	trail_arcs.top_level = true
	trail_arcs.shape = "dir"
	trail_arcs.count = 3
	trail_arcs.radius = 0.35
	trail_arcs.seg_len = 4.0
	trail_arcs.width = 0.015
	trail_arcs.amp = 0.28
	trail_arcs.spread = 0.16
	trail_arcs.rate = 11.0
	trail_arcs.intensity = 0.0
	add_child(trail_arcs)


func _process(delta: float) -> void:
	if pl == null or not is_instance_valid(skel):
		return
	power = lerpf(power, want, 1.0 - exp(-6.0 * delta))
	trail_p = lerpf(trail_p, trail_want, 1.0 - exp(-5.0 * delta))
	body_arcs.intensity = clampf(power * 1.15 - 0.1, 0.0, 1.0)
	light.light_energy = 1.6 * power
	var on: bool = power > 0.25
	for i in range(eyes.size()):
		eyes[i].visible = on
		if on:
			eye_mats[i].set_shader_parameter("energy", 1.0 + 3.5 * smoothstep(0.25, 0.9, power))
	# Blitze im Schweif: Richtung entgegen der Flugrichtung, beim Schweben nach unten
	var v: Vector3 = pl.velocity
	var sp := v.length()
	var tgt := Vector3.DOWN
	if sp > 2.0:
		tgt = Vector3.DOWN.lerp(-v / sp, smoothstep(2.0, 9.0, sp)).normalized()
	_dir = _dir.lerp(tgt, 1.0 - exp(-6.0 * delta)).normalized()
	trail_arcs.dir = _dir
	trail_arcs.seg_len = lerpf(4.5, 8.0, smoothstep(2.0, 14.0, sp))
	trail_arcs.intensity = clampf(trail_p, 0.0, 1.0)
	var hips: Vector3 = skel.global_transform * skel.get_bone_global_pose(skel.find_bone("mixamorig_Hips")).origin
	trail_arcs.global_transform = Transform3D(Basis.IDENTITY, hips + Vector3(0, 0.25, 0))
