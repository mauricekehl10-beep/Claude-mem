extends RefCounted
# Kleine, nahtlose Rauschtexturen fuer Himmel, Asphalt, Beton, Laub usw. (einmal erzeugt, dann zwischengespeichert).

static var _cache := {}


static func noise(kind: String) -> ImageTexture:
	if _cache.has(kind):
		return _cache[kind]
	var n := FastNoiseLite.new()
	var size := 512
	match kind:
		"cloud":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			n.seed = 7
			n.frequency = 0.008
			n.fractal_type = FastNoiseLite.FRACTAL_FBM
			n.fractal_octaves = 5
			n.fractal_gain = 0.55
		"blotch":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			n.seed = 11
			n.frequency = 0.012
			n.fractal_type = FastNoiseLite.FRACTAL_FBM
			n.fractal_octaves = 4
		"grain":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			n.seed = 23
			n.frequency = 0.22
			n.fractal_type = FastNoiseLite.FRACTAL_FBM
			n.fractal_octaves = 3
			n.fractal_gain = 0.6
		"crack":
			n.noise_type = FastNoiseLite.TYPE_CELLULAR
			n.seed = 5
			n.frequency = 0.018
			n.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
			n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
			n.cellular_jitter = 1.0
		"leaf":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			n.seed = 41
			n.frequency = 0.07
			n.fractal_type = FastNoiseLite.FRACTAL_FBM
			n.fractal_octaves = 3
		_:
			n.seed = 1
	var img := n.get_seamless_image(size, size, false, false, 0.15, true)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[kind] = tex
	return tex
