extends RefCounted
# Gesichter der Helden: Das Kopfnetz der Mixamo-Figur wird im Gesicht fein unterteilt und modelliert
# (Nase, Brauenwulst, Lippen, Kinn, Maske, Kapuze). Maße in Ruhepose-Koordinaten (Meter, +Z vorn, +X links).
# Augen, Brauen, Mund usw. malt danach hero_suit.gdshader; hier entsteht nur das Relief.

const EDGE := 0.0052  # Zielkantenlänge im Gesicht (Meter)
const CapSuit = preload("res://scripts/captain_suit.gd")


static func g(x: float, s: float) -> float:
	return exp(-x * x / (2.0 * s * s))


# Gesichtszone: Vorderseite des Kopfes
static func in_zone(m: Vector3) -> bool:
	return m.y > 1.535 and m.y < 1.785 and m.z > -0.01 and absf(m.x) < 0.1


# Teilt Kanten in der Gesichtszone, bis sie kürzer als EDGE sind (ohne Risse: Entscheidung hängt nur an der Kante).
static func refine(arrays: Array) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var wts: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var per: int = bones.size() / verts.size()
	var has_uv := uvs.size() == verts.size()
	var tans: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
	var has_t := tans.size() == verts.size() * 4
	for _it in range(3):
		var mids := {}
		var out := PackedInt32Array()
		var changed := false
		for t in range(idx.size() / 3):
			var tri := [idx[t * 3], idx[t * 3 + 1], idx[t * 3 + 2]]
			var m := [-1, -1, -1]
			var cnt := 0
			for k in range(3):
				var a: int = tri[k]
				var b: int = tri[(k + 1) % 3]
				var pa := verts[a]
				var pb := verts[b]
				if (pa - pb).length() <= EDGE * 1.4 or not in_zone((pa + pb) * 0.5):
					continue
				var key: int = mini(a, b) * 4000037 + maxi(a, b)
				if not mids.has(key):
					var n := verts.size()
					verts.append((pa + pb) * 0.5)
					norms.append((norms[a] + norms[b]).normalized())
					if has_uv:
						uvs.append((uvs[a] + uvs[b]) * 0.5)
					if has_t:
						var ta := Vector3(tans[a * 4], tans[a * 4 + 1], tans[a * 4 + 2])
						var tb := Vector3(tans[b * 4], tans[b * 4 + 1], tans[b * 4 + 2])
						var tm := (ta + tb).normalized()
						tans.append_array(PackedFloat32Array([tm.x, tm.y, tm.z, tans[a * 4 + 3]]))
					var same := true
					for j in range(per):
						bones.append(bones[a * per + j])
						if bones[a * per + j] != bones[b * per + j]:
							same = false
					for j in range(per):
						wts.append((wts[a * per + j] + wts[b * per + j]) * 0.5 if same else wts[a * per + j])
					mids[key] = n
				m[k] = mids[key]
				cnt += 1
			if cnt == 0:
				out.append_array(PackedInt32Array(tri))
				continue
			changed = true
			# Muster so drehen, dass die geteilten Kanten vorn stehen
			var a0: int = tri[0]
			var b0: int = tri[1]
			var c0: int = tri[2]
			var ab: int = m[0]
			var bc: int = m[1]
			var ca: int = m[2]
			if cnt == 1:
				# unterteilte Kante nach ab drehen
				if bc >= 0:
					a0 = tri[1]; b0 = tri[2]; c0 = tri[0]; ab = bc
				elif ca >= 0:
					a0 = tri[2]; b0 = tri[0]; c0 = tri[1]; ab = ca
				out.append_array(PackedInt32Array([a0, ab, c0, ab, b0, c0]))
			elif cnt == 2:
				# ungeteilte Kante nach ca drehen
				if ab < 0:
					a0 = tri[1]; b0 = tri[2]; c0 = tri[0]; ab = m[1]; bc = m[2]
				elif bc < 0:
					a0 = tri[2]; b0 = tri[0]; c0 = tri[1]; ab = m[2]; bc = m[0]
				else:
					ab = m[0]; bc = m[1]
				out.append_array(PackedInt32Array([ab, b0, bc, a0, ab, bc, a0, bc, c0]))
			else:
				out.append_array(PackedInt32Array([a0, ab, ca, ab, b0, bc, ca, bc, c0, ab, bc, ca]))
		idx = out
		if not changed:
			break
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	if has_uv:
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	if has_t:
		arrays[Mesh.ARRAY_TANGENT] = tans
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = wts
	arrays[Mesh.ARRAY_INDEX] = idx
	return arrays


# ---------------------------------------------------------------- Formen

# Stückweise lineare Breite entlang y: pts = [y0, w0, y1, w1, ...]
static func prof(y: float, pts: Array) -> float:
	if y <= pts[0]:
		return 0.0
	for i in range(0, pts.size() - 2, 2):
		if y <= pts[i + 2]:
			return lerpf(pts[i + 1], pts[i + 3], (y - pts[i]) / (pts[i + 2] - pts[i]))
	return 0.0


# Öffnung der Haube (Captain): Breite je Höhe
const OPEN := [1.545, 0.0, 1.551, 0.030, 1.566, 0.048, 1.600, 0.057, 1.640, 0.059, 1.680, 0.057, 1.706, 0.049, 1.719, 0.034, 1.727, 0.0]
# Gesichtsplatte (Iron Man)
const MASK := [1.543, 0.0, 1.548, 0.013, 1.565, 0.026, 1.585, 0.039, 1.610, 0.047, 1.640, 0.053, 1.668, 0.052, 1.695, 0.047, 1.714, 0.036, 1.722, 0.0]


static func open_d(ax: float, y: float, pts: Array) -> float:
	var w := prof(y, pts)
	if w <= 0.0:
		return 1.0
	return ax - w  # < 0 innen (grob, in Metern)


# Menschliches Gesicht (Captain, Thor)
static func human(ax: float, y: float, strong: float) -> float:
	var h := 0.0
	# Nase: Rücken, Spitze, Flügel
	var t := clampf((1.692 - y) / (1.692 - 1.628), 0.0, 1.0)
	var ts := t * t * (3.0 - 2.0 * t)
	var top := 1.0 - smoothstep(1.690, 1.704, y)
	var bot := smoothstep(1.612, 1.624, y)
	h += (0.0028 + 0.0172 * ts) * g(ax, lerpf(0.0052, 0.0088, t)) * top * bot
	h += 0.0042 * g(ax, 0.0072) * g(y - 1.631, 0.0058)
	h += 0.0068 * g(ax - 0.0125, 0.0055) * g(y - 1.6295, 0.0052)
	# Nasenlöcher und Philtrum
	h -= 0.0045 * g(ax - 0.0085, 0.0034) * g(y - 1.6205, 0.0026)
	h -= 0.0022 * g(ax, 0.0055) * g(y - 1.610, 0.0045)
	# Brauenwulst, Augenhöhlen, Wangenknochen
	h += (0.0068 + 0.0016 * strong) * g(y - (1.6915 + ax * 0.045), 0.0058) * (1.0 - smoothstep(0.036, 0.064, ax))
	h -= 0.0052 * g(ax - 0.0315, 0.0125) * g(y - 1.6635, 0.0078)
	h += 0.0058 * g(ax - 0.050, 0.0155) * g(y - 1.636, 0.0140)
	h -= (0.0030 + 0.0012 * strong) * g(ax - 0.042, 0.0150) * g(y - 1.598, 0.0100)
	# Schläfe
	h -= 0.0018 * g(ax - 0.068, 0.012) * g(y - 1.68, 0.016)
	# Lippen, Mundspalt, Kinnfurche, Kinn
	var mw := 1.0 - smoothstep(0.014, 0.027, ax)
	h += 0.0042 * g(y - 1.6015, 0.0038) * mw
	h += 0.0050 * g(y - 1.5915, 0.0042) * mw
	h -= 0.0036 * g(y - 1.5963, 0.0013) * (1.0 - smoothstep(0.019, 0.026, ax))
	h -= 0.0036 * g(y - 1.5800, 0.0034) * g(ax, 0.0150)
	h += (0.0058 + 0.0020 * strong) * g(y - 1.5545, 0.0110) * g(ax, 0.0200)
	return h


# Höhe der Oberfläche (Meter, entlang der Normale) an der Ruhepose-Stelle p
static func height(hero: int, p: Vector3) -> float:
	var ax := absf(p.x)
	var y := p.y
	if y < 1.535 or p.z < -0.02 or ax > 0.11:
		return 0.0
	var front := smoothstep(-0.02, 0.05, p.z)
	if hero == 0:
		# Haube (captain_suit.gd): dicker als die Haut, wulstiger Rand um Gesicht und Augenlöcher
		var d := CapSuit.open_d(ax, y)
		var cowl := smoothstep(-0.0015, 0.0035, d)
		var h := human(ax, y, 1.0) * (1.0 - cowl) + CapSuit.COWL * cowl
		h += 0.0016 * g(d - 0.0030, 0.0020)
		return h * front if y > 1.54 else 0.0
	elif hero == 1:
		# Helm mit Gesichtsplatte
		var w := prof(y, MASK)
		var inside := 1.0 - smoothstep(-0.0018, 0.0018, ax - w) if w > 0.0 else 0.0
		var h := 0.0032 + 0.0052 * inside
		# Augenschlitze (schräg), Brauenplatte, Nasenrücken, Mundspalt, Wangenlinien, Kinnplatte
		var ex := ax - 0.0275
		var ey := y - (1.6665 + (ax - 0.0275) * 0.30)
		h -= 0.0048 * g(ey, 0.0030) * (1.0 - smoothstep(0.0145, 0.0175, absf(ex))) * inside
		h += 0.0034 * g(y - (1.6835 + ax * 0.12), 0.0045) * (1.0 - smoothstep(0.040, 0.050, ax)) * inside
		var t := clampf((1.690 - y) / (1.690 - 1.60), 0.0, 1.0)
		h += 0.0105 * g(ax, lerpf(0.0042, 0.0075, t)) * (1.0 - smoothstep(1.690, 1.70, y)) * smoothstep(1.592, 1.612, y) * inside
		h -= 0.0036 * g(y - 1.5935, 0.0013) * (1.0 - smoothstep(0.013, 0.019, ax)) * inside
		h -= 0.0020 * g(ax - (0.012 + (1.628 - y) * 0.45), 0.0016) * smoothstep(1.575, 1.600, y) * (1.0 - smoothstep(1.628, 1.640, y)) * inside
		h -= 0.0020 * g(y - 1.567, 0.0014) * inside
		h += 0.0040 * g(y - 1.5565, 0.008) * g(ax, 0.011) * inside
		return h * front if y > 1.54 else 0.0
	else:
		return human(ax, y, 1.6) * front if y > 1.54 else 0.0


# Neue Normale: n minus Gefälle der Höhe (Tangentialteil)
static func normal(hero: int, p: Vector3, n: Vector3) -> Vector3:
	var e := 0.0007
	var gx := (height(hero, p + Vector3(e, 0, 0)) - height(hero, p - Vector3(e, 0, 0))) / (2.0 * e)
	var gy := (height(hero, p + Vector3(0, e, 0)) - height(hero, p - Vector3(0, e, 0))) / (2.0 * e)
	var gv := Vector3(gx, gy, 0.0)
	gv -= n * gv.dot(n)
	return (n - gv).normalized()
