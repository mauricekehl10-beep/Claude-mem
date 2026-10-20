extends RefCounted
# Rad: Reifen mit Seitenwand und Profil (Art 4), Felge mit echten Speichen (Art 5), Bremsscheibe (Art 12). Achse = X, aussen +X.
# seg >= 24: volle Geometrie; darunter eine flache Felgenscheibe (Speichen zeichnet der Shader).

const LF = preload("res://scripts/car_loft.gd")


static func _kc(kind: int, col: Color = Color.WHITE) -> Color:
	return Color(col.r, col.g, col.b, kind / 15.0)


static func wheel(b: LF.Buf, xf: Transform3D, sp: Dictionary, seg: int) -> void:
	var R: float = sp["R"]
	var ww: float = sp["ww"]
	var h := ww * 0.5
	var Rr := R * float(sp.get("rim_r", 0.66))  # Felgenradius
	var full := seg >= 24
	# Reifenprofil (axial, radial): Wulst, Seitenwand, Schulter, Lauffleaeche
	var prof := [
		Vector2(-h * 0.80, Rr + 0.006), Vector2(-h * 0.97, Rr + (R - Rr) * 0.22), Vector2(-h * 1.0, Rr + (R - Rr) * 0.55),
		Vector2(-h * 0.95, R * 0.965), Vector2(-h * 0.80, R * 0.992), Vector2(-h * 0.5, R), Vector2(h * 0.5, R),
		Vector2(h * 0.80, R * 0.992), Vector2(h * 0.95, R * 0.965), Vector2(h * 1.0, Rr + (R - Rr) * 0.55),
		Vector2(h * 0.97, Rr + (R - Rr) * 0.22), Vector2(h * 0.80, Rr + 0.006),
	]
	var np := prof.size()
	var nrm2 := []
	for p in range(np):
		var p0: Vector2 = prof[maxi(p - 1, 0)]
		var p1: Vector2 = prof[mini(p + 1, np - 1)]
		var t := (p1 - p0).normalized()
		nrm2.append(Vector2(-t.y, t.x))
	var tire := _kc(4, Color(0.05, 0.05, 0.05))
	var base := b.v.size()
	for k in range(seg + 1):
		var a := TAU * float(k) / seg
		var ca := cos(a)
		var sa := sin(a)
		for p in range(np):
			var pr: Vector2 = prof[p]
			var nn: Vector2 = nrm2[p]
			var pos := xf * Vector3(pr.x, pr.y * ca, pr.y * sa)
			var nv := (xf.basis * Vector3(nn.x, nn.y * ca, nn.y * sa)).normalized()
			b.vert(pos, nv, tire, Vector2(float(k) / seg, float(p) / (np - 1)))
	for k in range(seg):
		for p in range(np - 1):
			var a0 := base + k * np + p
			var a1 := base + (k + 1) * np + p
			b.quad(a0, a1, a1 + 1, a0 + 1)
	var rim: Color = sp.get("rim_col", Color(0.74, 0.76, 0.80))
	var rc := _kc(5, rim)
	var cn := (xf.basis * Vector3.RIGHT).normalized()
	var style: String = sp.get("rim", "alloy")
	if not full:
		# flache Scheibe: Speichen im Shader
		var ci := b.vert(xf * Vector3(h * 0.72, 0, 0), cn, rc, Vector2(0.5, 0.5))
		var rb := b.v.size()
		for k in range(seg):
			var a := TAU * float(k) / seg
			b.vert(xf * Vector3(h * 0.86, Rr * cos(a), Rr * sin(a)), cn, rc, Vector2(0.5 + 0.5 * cos(a), 0.5 + 0.5 * sin(a)))
		for k in range(seg):
			b.tri(ci, rb + k, rb + (k + 1) % seg)
		return
	# Felgenbett innen (dunkel) und aeusseres Horn
	var dark := _kc(10)
	LF.tube(b, xf * Vector3(-h * 0.85, 0, 0), xf * Vector3(h * 0.70, 0, 0), Rr * 0.985, Rr * 0.985, dark, seg, false)
	var lip := _kc(5, rim)
	var lip_ring := []
	for k in range(2):
		pass
	# Horn: Ring aussen (Viertelprofil)
	var hp := [Vector2(h * 0.70, Rr * 0.985), Vector2(h * 0.84, Rr * 1.0), Vector2(h * 0.90, Rr * 0.965), Vector2(h * 0.86, Rr * 0.90)]
	var P := []
	for pp in hp:
		var ring := PackedVector3Array()
		for k in range(seg):
			var a := -TAU * float(k) / seg
			ring.append(xf * Vector3(pp.x, pp.y * cos(a), pp.y * sin(a)))
		P.append(ring)
	var fc := PackedColorArray()
	fc.resize((P.size() - 1) * seg)
	fc.fill(lip)
	LF.grid(b, P, true, fc, 70.0)
	# Bremsscheibe hinter den Speichen: Ring mit Topf
	var disc := _kc(12, Color(0.32, 0.30, 0.29))
	var x_d := h * 0.20
	var r0 := Rr * 0.34
	var r1 := Rr * 0.88
	var di := b.v.size()
	for k in range(seg + 1):
		var a := TAU * float(k) / seg
		b.vert(xf * Vector3(x_d, r0 * cos(a), r0 * sin(a)), cn, disc, Vector2(float(k) / seg, 0.0))
		b.vert(xf * Vector3(x_d, r1 * cos(a), r1 * sin(a)), cn, disc, Vector2(float(k) / seg, 1.0))
	for k in range(seg):
		var q := di + k * 2
		b.quad(q, q + 1, q + 3, q + 2)
	LF.tube(b, xf * Vector3(x_d, 0, 0), xf * Vector3(x_d + h * 0.25, 0, 0), Rr * 0.34, Rr * 0.30, disc, seg, true)
	# Speichen
	var n_sp: int = int(sp.get("spokes", 5))
	if style == "steel":
		# Stahlfelge mit Radblende: dished Scheibe + Kappe
		var cx := xf * Vector3(h * 0.62, 0, 0)
		var ci2 := b.vert(cx, cn, rc, Vector2(0.5, 0.5))
		var rb2 := b.v.size()
		for k in range(seg):
			var a := TAU * float(k) / seg
			b.vert(xf * Vector3(h * 0.80, Rr * 0.97 * cos(a), Rr * 0.97 * sin(a)), cn, _kc(5, Color(0.55, 0.57, 0.60)), Vector2(0.5 + 0.5 * cos(a), 0.5 + 0.5 * sin(a)))
		for k in range(seg):
			b.tri(ci2, rb2 + k, rb2 + (k + 1) % seg)
		return
	var hub_r := Rr * 0.20
	LF.tube(b, xf * Vector3(h * 0.56, 0, 0), xf * Vector3(h * 0.80, 0, 0), hub_r, hub_r * 0.85, _kc(3), seg, true)
	for s in range(n_sp):
		var a0 := TAU * float(s) / n_sp
		var dir := Vector3(0, cos(a0), sin(a0))
		var side := Vector3(0, -sin(a0), cos(a0))
		var P2 := []
		var stations := 5
		for q in range(stations):
			var f := float(q) / (stations - 1)
			var rad := lerpf(hub_r * 0.8, Rr * 0.97, f)
			var wd := lerpf(0.040, 0.030, f) * (Rr / 0.22) * (1.0 + 0.5 * sin(f * PI))
			var xs := lerpf(h * 0.62, h * 0.80, pow(f, 1.5))
			var th := 0.016
			var c := Vector3(xs, 0, 0) + dir * rad
			var ring := PackedVector3Array()
			# Querschnitt: aussen (+x) schmaler, innen breiter
			ring.append(xf * (c + side * wd * 0.35 + Vector3(th * 0.5, 0, 0)))
			ring.append(xf * (c - side * wd * 0.35 + Vector3(th * 0.5, 0, 0)))
			ring.append(xf * (c - side * wd * 0.5 - Vector3(th * 0.5, 0, 0)))
			ring.append(xf * (c + side * wd * 0.5 - Vector3(th * 0.5, 0, 0)))
			P2.append(ring)
		var fc2 := PackedColorArray()
		fc2.resize((P2.size() - 1) * 4)
		fc2.fill(rc)
		LF.grid(b, P2, true, fc2, 50.0, true)
