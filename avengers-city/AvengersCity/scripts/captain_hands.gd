extends RefCounted
# Captain America: Hände und Unterarme im Detail (Lederhandschuhe mit Knöchelschutz, Fingergliedern, Daumen,
# Handgelenkriemen mit Schnalle; Stulpe aus Lamellen mit Nieten). Alle Maße sind Ruhepose-Koordinaten
# (T-Pose, Meter, +X links); die Teile hängen an den Hand-, Finger- und Unterarmknochen und biegen sich mit.

const CapSuit = preload("res://scripts/captain_suit.gd")

const FINGERS := ["Index", "Middle", "Ring", "Pinky"]
const FR := [0.0112, 0.0116, 0.0108, 0.0098]  # Ring-Radius je Finger


static func rest(skel: Skeleton3D, bone: String) -> Vector3:
	return skel.get_bone_global_rest(skel.find_bone(bone)).origin


# Baut alle Teile als eigene Gruppe (Aufruf aus hero_parts.gd nach CapSuit.build)
static func build(skel: Skeleton3D) -> void:
	var g = CapSuit.Gear.new(skel)
	var m := {
		"leather": CapSuit.mat(0, Color(0.21, 0.13, 0.115), Color(0.38, 0.27, 0.23), 0.7),
		"leather_hi": CapSuit.mat(0, Color(0.30, 0.19, 0.16), Color(0.46, 0.33, 0.27), 0.7),
		"black": CapSuit.mat(0, Color(0.10, 0.075, 0.07), Color(0.24, 0.19, 0.17), 0.6),
		"silver": CapSuit.mat(1, Color(0.58, 0.58, 0.57), Color(0.78, 0.78, 0.76), 0.6),
		"strap": CapSuit.mat(0, Color(0.33, 0.21, 0.18), Color(0.46, 0.33, 0.28), 0.7),
	}
	add(g, skel, m)
	g.finish()


# m: Materialien {"leather","leather_hi","black","silver","strap"}
static func add(g, skel: Skeleton3D, m: Dictionary) -> void:
	for s in [-1.0, 1.0]:
		var side := "Left" if s > 0.0 else "Right"
		var hb := "mixamorig_%sHand" % side
		var fb := "mixamorig_%sForeArm" % side
		var bas := Basis(Vector3(0, 1, 0), Vector3(s, 0, 0), Vector3(0, 0, -s))
		var ba := CapSuit.frame(Vector3(s, 0, 0), Vector3(0, 0, 1))
		# --- Stulpe: vier Lamellen aus schwarzem Leder auf der Oberseite des Unterarms, mit Nieten
		for i in range(4):
			var cx := 0.585 + 0.042 * i
			var r := 0.0545 - 0.0015 * i
			g.add(fb, CapSuit.shell(r, 0.045, -1.45, 1.45, 0.0055, 16, 0.002), m["black"] if i % 2 == 0 else m["leather"],
				Transform3D(bas, Vector3(s * cx, 1.436, -0.064)))
			for k in [-0.95, 0.95]:
				var off := Vector3(0, cos(float(k)), sin(float(k))) * (r + 0.0065)
				g.add(fb, CapSuit.sphere(8), m["silver"], Transform3D(Basis.from_scale(Vector3(0.0027, 0.0027, 0.0027)),
					Vector3(s * (cx + 0.016), 1.436, -0.064) + off))
		# Lederriemen längs der Stulpe mit Schnalle
		g.add(fb, CapSuit.box(Vector3(0.150, 0.004, 0.016)), m["strap"], Transform3D(Basis.IDENTITY, Vector3(s * 0.650, 1.436 + 0.0595, -0.064)))
		g.add(fb, CapSuit.box(Vector3(0.014, 0.007, 0.024)), m["silver"], Transform3D(Basis.IDENTITY, Vector3(s * 0.690, 1.436 + 0.0625, -0.064)))
		# --- Handgelenkriemen (Hand-Knochen) mit Schnalle
		g.add(hb, CapSuit.shell(0.047, 0.017, 0.0, TAU, 0.0035, 22), m["strap"], Transform3D(bas * Basis.from_scale(Vector3(0.80, 1.0, 1.0)), Vector3(s * 0.757, 1.434, -0.064)))
		g.add(hb, CapSuit.box(Vector3(0.012, 0.005, 0.017)), m["silver"], Transform3D(Basis.IDENTITY, Vector3(s * 0.757, 1.434 + 0.0405, -0.064)))
		# --- Handrücken: gewölbte Knöchelplatte aus dunklem Leder mit Steppung und Metallkappen
		var plate := Transform3D(bas * Basis.from_scale(Vector3(0.62, 1.0, 1.0)), Vector3(s * 0.806, 1.436, -0.066))
		g.add(hb, CapSuit.shell(0.047, 0.066, -1.15, 1.15, 0.004, 16), m["black"], plate)
		g.add(hb, CapSuit.shell(0.047, 0.006, -1.15, 1.15, 0.0055, 16), m["leather_hi"], Transform3D(bas * Basis.from_scale(Vector3(0.62, 1.0, 1.0)), Vector3(s * 0.774, 1.436, -0.066)))
		# --- Knöchel: je Finger eine Kuppe; Fingerglieder: Ringe an den Gelenken
		for fi in range(FINGERS.size()):
			var f: String = FINGERS[fi]
			var o1 := rest(skel, "mixamorig_%sHand%s1" % [side, f])
			var kn := Basis.from_scale(Vector3(0.0092, 0.0074, 0.0092))
			g.add(hb, CapSuit.sphere(10), m["leather_hi"], Transform3D(kn, o1 + Vector3(s * 0.004, 0.0055, 0.0)))
			for j in [2, 3]:
				var bn := "mixamorig_%sHand%s%d" % [side, f, j]
				var o := rest(skel, bn)
				g.add(bn, CapSuit.tube(float(FR[fi]), float(FR[fi]), 0.0034, 12, false), m["leather_hi"], Transform3D(ba, o))
			# Fingerkuppe: kleine Lederkappe an der Spitze
			var o4 := rest(skel, "mixamorig_%sHand%s4" % [side, f])
			g.add("mixamorig_%sHand%s3" % [side, f], CapSuit.sphere(10), m["leather"],
				Transform3D(Basis.from_scale(Vector3(0.0105, 0.0090, 0.0090)), o4 + Vector3(s * -0.004, 0.0, 0.0)))
		# --- Daumen: Ringe an den Gelenken (Achse = Daumenrichtung)
		var t2 := rest(skel, "mixamorig_%sHandThumb2" % side)
		var t3 := rest(skel, "mixamorig_%sHandThumb3" % side)
		var td := (t3 - t2).normalized()
		var tb := CapSuit.frame(td, Vector3(0, 0, 1))
		g.add("mixamorig_%sHandThumb2" % side, CapSuit.tube(0.0125, 0.0125, 0.0034, 12, false), m["leather_hi"], Transform3D(tb, t2))
		g.add("mixamorig_%sHandThumb3" % side, CapSuit.tube(0.0112, 0.0112, 0.0034, 12, false), m["leather_hi"], Transform3D(tb, t3))
		g.add("mixamorig_%sHandThumb3" % side, CapSuit.sphere(10), m["leather"], Transform3D(Basis.from_scale(Vector3(0.0105, 0.0105, 0.0105)), rest(skel, "mixamorig_%sHandThumb4" % side) - td * 0.002))
