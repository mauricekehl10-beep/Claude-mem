extends RefCounted
# Kronen und Aufbauten fuer Wolkenkratzer: gestufte Art-Deco-Spitzen, Bogenkrone (Chrysler-Art), Glaslaterne, Funkmast.

const M = preload("res://scripts/city_mats.gd")

const STEEL := Color(0.80, 0.82, 0.87)


# Dach der obersten Stufe: x0..x1, z0..z1 (innen), y = Dachhoehe. style: 0 gestuft+Mast, 1 Bogenkrone, 2 Laterne, 3 Terrassen+Mast
static func crown(mb, rng: RandomNumberGenerator, x0: float, z0: float, x1: float, z1: float, y: float, stone: Color, style: int) -> float:
	var solid := M.solid()
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	var w := x1 - x0
	var d := z1 - z0
	var top := y
	match style:
		0:
			# Gestufte Spitze: drei Kaesten, Kegel, Mast
			var a := x0
			var b := z0
			var c := x1
			var e := z1
			var hs := [6.0, 5.0, 4.0]
			for k in range(3):
				var ins := 2.0 if k > 0 else 1.2
				a += ins
				b += ins
				c -= ins
				e -= ins
				if c - a < 3.0 or e - b < 3.0:
					break
				mb.sbox(solid, a, top, b, c, top + hs[k], e, stone, 0.8)
				# Fensterschlitze (dunkel, leuchtend) auf den vier Seiten
				for sx in [-1.0, 1.0]:
					mb.sbox(solid, cx + sx * (c - cx) - 0.03 - (0.0 if sx < 0 else 0.0), top + 1.0, cz - 0.7, cx + sx * (c - cx) + 0.03, top + hs[k] - 1.0, cz + 0.7, Color(1.0, 0.85, 0.55), 0.3, 0.0, 1.0)
				top += hs[k]
			var r := minf(c - a, e - b) * 0.5
			mb.scyl(solid, Vector3(cx, top, cz), r, r * 0.3, 7.0, stone.lightened(0.05), 8, 0.7)
			top += 7.0
			mb.tube(solid, Vector3(cx, top, cz), Vector3(cx, top + 22.0, cz), 0.45, 0.06, 8, STEEL, 0.3, 0.9)
			mb.sbox(solid, cx - 0.2, top + 22.0, cz - 0.2, cx + 0.2, top + 22.6, cz + 0.2, Color(1.0, 0.1, 0.05), 0.3, 0.0, 8.0)
			top += 22.6
		1:
			# Bogenkrone aus Stahl, sich verjuengende Ringe
			var r := minf(w, d) * 0.5 - 0.3
			var c := Vector3(cx, top, cz)
			mb.scyl(solid, c, r, r * 0.95, 2.6, stone, 24, 0.8)
			top += 2.6
			var rr := r * 0.92
			for k in range(6):
				var hh := 3.4 - k * 0.25
				mb.scyl(solid, Vector3(cx, top, cz), rr, rr * 0.9, hh, STEEL, 24, 0.22, 0.95)
				# dunkles Fensterband mit Dreiecks-Andeutung
				mb.scyl(solid, Vector3(cx, top + hh * 0.35, cz), rr * 0.93, rr * 0.93, 0.35, Color(0.05, 0.06, 0.09), 24, 0.4, 0.4, 0.0, false)
				top += hh
				rr *= 0.8
			mb.tube(solid, Vector3(cx, top, cz), Vector3(cx, top + 20.0, cz), 0.6, 0.05, 8, STEEL, 0.2, 0.95)
			top += 20.0
			# Adler an den Ecken
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					mb.sbox(solid, cx + sx * (w * 0.5 - 0.9) - 0.4, y - 0.3, cz + sz * (d * 0.5 - 0.9) - 0.4, cx + sx * (w * 0.5 - 0.9) + 0.4, y + 1.4, cz + sz * (d * 0.5 - 0.9) + 0.4, STEEL, 0.3, 0.9)
		2:
			# Glaslaterne mit warm leuchtendem Band
			var a := x0 + 1.5
			var b := z0 + 1.5
			var c := x1 - 1.5
			var e := z1 - 1.5
			mb.sbox(solid, a, top, b, c, top + 3.0, e, Color(0.18, 0.2, 0.23), 0.4, 0.6)
			top += 3.0
			mb.sbox(solid, a + 0.6, top, b + 0.6, c - 0.6, top + 5.0, e - 0.6, Color(1.0, 0.86, 0.55), 0.3, 0.0, 0.55)
			top += 5.0
			mb.sbox(solid, a, top, b, c, top + 0.6, e, Color(0.18, 0.2, 0.23), 0.4, 0.6)
			top += 0.6
			mb.tube(solid, Vector3(cx, top, cz), Vector3(cx, top + 14.0, cz), 0.35, 0.05, 8, STEEL, 0.3, 0.9)
			mb.sbox(solid, cx - 0.2, top + 14.0, cz - 0.2, cx + 0.2, top + 14.6, cz + 0.2, Color(1.0, 0.1, 0.05), 0.3, 0.0, 8.0)
			top += 14.6
		_:
			# Maschinenaufbau mit Mast
			mb.sbox(solid, x0 + 2.0, top, z0 + 2.0, x1 - 2.0, top + 4.0, z1 - 2.0, stone.darkened(0.1), 0.8)
			mb.sbox(solid, x0 + 2.0, top + 4.0, z0 + 2.0, x1 - 2.0, top + 4.3, z1 - 2.0, Color(0.5, 0.5, 0.52), 0.5, 0.4)
			mb.tube(solid, Vector3(cx, top + 4.3, cz), Vector3(cx, top + 4.3 + 18.0, cz), 0.3, 0.05, 6, STEEL, 0.4, 0.8)
			mb.sbox(solid, cx - 0.15, top + 22.3, cz - 0.15, cx + 0.15, top + 22.7, cz + 0.15, Color(1.0, 0.1, 0.05), 0.3, 0.0, 8.0)
			top += 22.7
	return top
