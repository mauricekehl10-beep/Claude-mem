extends RefCounted
# Anbauten der Autos: Spiegel, Kennzeichen, Auspuff, Antenne, Dachreling, Taxischild, Lichtbalken, Innenraum.

const LF = preload("res://scripts/car_loft.gd")


static func _kc(kind: int, col: Color = Color.WHITE) -> Color:
	return Color(col.r, col.g, col.b, kind / 15.0)


static func _roof_h(sp: Dictionary) -> float:
	var h := 0.0
	for p in sp["top"]:
		h = maxf(h, p[1])
	return h


static func addons(b: LF.Buf, sp: Dictionary, lod: int) -> void:
	var L: float = sp["L"]
	var hw: float = sp["W"] * 0.5
	var paint := _kc(0)
	var dark := _kc(2, Color(0.025, 0.025, 0.03))
	var gloss := _kc(13, Color(0.01, 0.01, 0.012))
	var chrome := _kc(3)
	var flags: Array = sp["flags"]
	var plate := _kc(11)
	var belt: LF.Crv = sp["c_belt"]
	var top: LF.Crv = sp["c_top"]
	var yb: LF.Crv = sp["c_yb"]
	var ws: Array = sp["ws"]
	var rw: Array = sp["rw"]
	# Kennzeichen (US-Format 30 x 15 cm) vorn und hinten
	var fy := (yb.at(0.0) + top.at(0.0)) * 0.5 - 0.02
	var ry := (yb.at(L) + top.at(L)) * 0.5 - 0.03
	LF.box(b, Vector3(0, fy, -L * 0.5 - 0.004), Vector3(0.305, 0.152, 0.012), plate)
	LF.box(b, Vector3(0, ry, L * 0.5 + 0.004), Vector3(0.305, 0.152, 0.012), plate)
	var roof_h := _roof_h(sp)
	# Taxi-Schild, Polizei-Lichtbalken
	var zr: float = -L * 0.5 + (ws[1] + (rw[0] if rw.size() > 0 else ws[1] + 0.8)) * 0.5
	if "taxi" in flags:
		LF.rbox(b, Vector3(0, roof_h + 0.095, zr), Vector3(0.62, 0.17, 0.26), 0.045, _kc(7, Color(1.0, 0.85, 0.5)), 3)
		LF.box(b, Vector3(0, roof_h + 0.008, zr), Vector3(0.5, 0.03, 0.18), dark)
	if "police" in flags:
		LF.rbox(b, Vector3(0, roof_h + 0.065, zr), Vector3(1.18, 0.10, 0.30), 0.04, _kc(9), 3)
		LF.box(b, Vector3(0, roof_h + 0.008, zr), Vector3(1.0, 0.03, 0.24), dark)
		# Seitenscheinwerfer an der A-Saeule und Frontstossstange (Rammschutz)
		LF.tube(b, Vector3(-0.5, 0.30, -L * 0.5 + 0.03), Vector3(0.5, 0.30, -L * 0.5 + 0.03), 0.018, 0.018, dark, 6, true)
		LF.tube(b, Vector3(-0.5, 0.52, -L * 0.5 + 0.03), Vector3(0.5, 0.52, -L * 0.5 + 0.03), 0.018, 0.018, dark, 6, true)
		for s in [-1.0, 1.0]:
			LF.tube(b, Vector3(s * 0.5, 0.30, -L * 0.5 + 0.03), Vector3(s * 0.5, 0.52, -L * 0.5 + 0.03), 0.018, 0.018, dark, 6, true)
	if lod > 0:
		return
	# Spiegel
	var mu: float = ws[0] + float(sp.get("mirror_dz", 0.22))
	var mz: float = -L * 0.5 + mu
	var my: float = belt.at(mu) + 0.13
	for s in [-1.0, 1.0]:
		LF.rbox(b, Vector3(s * (hw + 0.075), my, mz + 0.03), Vector3(0.17, 0.115, 0.11), 0.04, paint, 3)
		LF.box(b, Vector3(s * (hw + 0.075 - 0.002), my, mz + 0.088), Vector3(0.15, 0.095, 0.006), gloss)
		LF.tube(b, Vector3(s * (hw - 0.04), my - 0.065, mz + 0.02), Vector3(s * (hw + 0.04), my - 0.04, mz + 0.03), 0.012, 0.012, dark, 6, true)
	# Auspuff (zwei Endrohre)
	if sp["bed"].size() == 0 and "police" not in flags and "bus" not in flags:
		for s in [-1.0, 1.0]:
			LF.tube(b, Vector3(s * hw * 0.55, 0.22, L * 0.5 - 0.30), Vector3(s * hw * 0.55, 0.22, L * 0.5 + 0.02), 0.042, 0.042, chrome, 10, true)
	# Antenne
	var au: float = (rw[0] if rw.size() > 0 else L - 0.6) - 0.5
	LF.tube(b, Vector3(0.0, top.at(au) + 0.01, -L * 0.5 + au), Vector3(0.0, top.at(au) + 0.40, -L * 0.5 + au + 0.1), 0.006, 0.003, dark, 5, true)
	# Dachreling (SUV)
	if "rails" in flags:
		var u0: float = ws[1] + 0.05
		var u1: float = (rw[0] if rw.size() > 0 else L - 0.3) - 0.05
		var xr: float = hw * sp["roof_w"] - 0.03
		for s in [-1.0, 1.0]:
			var y0 := top.at(u0) - 0.03
			LF.tube(b, Vector3(s * xr, y0 + 0.045, -L * 0.5 + u0), Vector3(s * xr, top.at(u1) + 0.03, -L * 0.5 + u1), 0.016, 0.016, _kc(3, Color(0.6, 0.6, 0.62)), 6, true)
	_interior(b, sp)


static func _interior(b: LF.Buf, sp: Dictionary) -> void:
	var L: float = sp["L"]
	var hw: float = sp["W"] * 0.5
	var belt: LF.Crv = sp["c_belt"]
	var ws: Array = sp["ws"]
	var seat := _kc(6, Color(0.13, 0.12, 0.11))
	var dk := _kc(6, Color(0.045, 0.045, 0.05))
	var sw: float = hw * 0.62
	var du: float = ws[0] + 0.12
	var dz := -L * 0.5 + du
	var dy: float = belt.at(du) - 0.04
	# Armaturenbrett mit Kombiinstrument und Mittelkonsole
	LF.rbox(b, Vector3(0, dy - 0.07, dz + 0.16), Vector3(sw * 2.0, 0.20, 0.42), 0.05, dk, 3)
	LF.rbox(b, Vector3(-sw * 0.5, dy + 0.045, dz + 0.20), Vector3(0.30, 0.12, 0.14), 0.04, dk, 3)
	LF.rbox(b, Vector3(0, dy - 0.28, dz + 0.50), Vector3(0.22, 0.26, 0.7), 0.04, dk, 3)
	# Lenkrad (Ring) und Lenksaeule
	var cx := -sw * 0.5
	var cy := dy - 0.02
	var cz := dz + 0.38
	var tilt := Vector3(0, 0.6, 0.8).normalized()
	var u_ax := Vector3(1, 0, 0)
	var v_ax := tilt.cross(u_ax).normalized()
	var prev := Vector3.ZERO
	for k in range(13):
		var a := TAU * float(k) / 12.0
		var p := Vector3(cx, cy, cz) + (u_ax * cos(a) + v_ax * sin(a)) * 0.19
		if k > 0:
			LF.tube(b, prev, p, 0.014, 0.014, dk, 5, false)
		prev = p
	LF.tube(b, Vector3(cx, cy, cz), Vector3(cx, cy - 0.12, cz - 0.20), 0.03, 0.03, dk, 6, true)
	# Sitze: Sitzflaeche, Lehne, Kopfstuetze
	var floor_y := 0.34
	var sy := floor_y + 0.12
	var rows: Array = sp.get("seats", [2.3, 3.3])
	for sf in rows:
		var sz: float = -L * 0.5 + sf
		var xs := [-sw * 0.5, sw * 0.5] if sf < rows[rows.size() - 1] or rows.size() == 1 else [-sw * 0.5, sw * 0.5]
		for x in xs:
			LF.rbox(b, Vector3(x, sy, sz), Vector3(sw * 0.82, 0.14, 0.52), 0.05, seat, 3)
			LF.rbox(b, Vector3(x, sy + 0.30, sz + 0.27), Vector3(sw * 0.8, 0.60, 0.11), 0.05, seat, 3)
			LF.rbox(b, Vector3(x, sy + 0.66, sz + 0.28), Vector3(0.20, 0.17, 0.09), 0.04, seat, 3)
	# Boden
	LF.box(b, Vector3(0, floor_y - 0.05, -L * 0.5 + (ws[0] + sp["ws"][1] + 1.2) * 0.5), Vector3(hw * 1.5, 0.04, 2.6), dk)
