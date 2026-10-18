extends RefCounted
# Stadtplan: was steht auf welchem Block (Wahrzeichen, Times Square, Park, Hochhaus-, Wohn-, Reihenhausblock) und Strassennamen.

const STEP := 72.0
# Times Square: die Kreuzung der Startstrasse (x = 36) mit der Querstrasse z = -108
const TIMES_X := 36.0
const TIMES_Z := -108.0
const TIMES := [Vector2i(0, -1), Vector2i(1, -1), Vector2i(0, -2), Vector2i(1, -2)]
# Grosser Park (Central-Park-Art) westlich des Turms
const PARK_X0 := -2
const PARK_X1 := -1
const PARK_Z0 := -1
const PARK_Z1 := 1


static func is_park(ix: int, iz: int) -> bool:
	return ix >= PARK_X0 and ix <= PARK_X1 and iz >= PARK_Z0 and iz <= PARK_Z1


# "landmark", "times", "park", "wedge" oder Block-Art "tower", "mid", "rows"
static func kind(ix: int, iz: int) -> String:
	if ix == 0 and iz == 0:
		return "landmark"
	if Vector2i(ix, iz) in TIMES:
		return "times"
	if is_park(ix, iz):
		return "park"
	if ix == 2 and iz == -1:
		return "wedge"
	var zone := maxi(absi(ix), absi(iz))
	var h := absi(hash(Vector2i(ix * 31 + 7, iz * 17 + 3))) % 100
	if zone <= 1:
		return "tower" if h < 62 else "mid"
	if zone == 2:
		if h < 30:
			return "tower"
		return "mid" if h < 66 else "rows"
	if h < 8:
		return "tower"
	return "mid" if h < 44 else "rows"


# Strassenname einer Linie: axis 0 = Querstrasse (z = const), axis 1 = Avenue (x = const); v = Weltkoordinate der Strassenmitte
static func street_name(axis: int, v: float) -> String:
	var idx := int(roundf((v - 36.0) / STEP))
	if axis == 0:
		return "W %d ST" % (40 - idx)
	match idx:
		-2:
			return "PARK AVE"
		-1:
			return "5 AVE"
		0:
			return "BROADWAY"
		1:
			return "MADISON AVE"
	return "%d AVE" % (maxi(1, 6 + idx))
